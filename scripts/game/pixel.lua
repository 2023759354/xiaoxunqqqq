-- ============================================================================
-- 像素画布：模拟原版 <canvas> 2D 上下文里用到的那一小部分接口
-- （fillStyle / globalAlpha / fillRect / drawImage / save / restore / translate / clip）
-- 原版的所有绘制都是整数坐标的矩形和最近邻缩放的贴图，这里把它们记录成「矩形列表」，
-- 显示时再按 image-rendering: pixelated 的方式整块放大到界面上（见 PixelCanvas.drawNVG）
-- ============================================================================
local js = require("game.compat")
local floor, max, min = math.floor, math.max, math.min
local parseColor = js.parseColor

local M = {}

-- ---------------------------------------------------------------------------
-- 像素图（相当于原版离屏 canvas）：data[y * w + x] = 颜色字符串
-- ---------------------------------------------------------------------------
local Img = {}
Img.__index = Img
M.Img = Img

function M.newImage(w, h)
    return setmetatable({ width = w, height = h, data = {}, runs = nil }, Img)
end
function Img:set(x, y, color)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then return end
    self.data[y * self.width + x] = color
    self.runs = nil; self.rects = nil; self.groups = nil; self.gorder = nil; self.gcols = nil; self.crops = nil
end
function Img:get(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then return nil end
    return self.data[y * self.width + x]
end
--- 在图上画实心矩形（离屏 canvas 的 fillRect，颜色不透明）
function Img:fill(x, y, w, h, color)
    for yy = y, y + h - 1 do
        for xx = x, x + w - 1 do self:set(xx, yy, color) end
    end
end
--- 整张图合并后的矩形（缓存）：{ x, y, w, h, color, ... }
--- 先按行切成横向色段，再把上下相邻、位置宽度颜色都相同的色段合并成一个高矩形（像素图的矩形数一般能少一半）
function Img:getRects()
    if self.rects then return self.rects end
    local runs = self:getRuns()
    local out, n = {}, 0
    local open = {} -- key x|w|color → 上一行可以继续往下延伸的矩形下标
    local curY, nextOpen = -1, {}
    for i = 1, #runs, 4 do
        local x, y, w, c = runs[i], runs[i + 1], runs[i + 2], runs[i + 3]
        if y ~= curY then
            if y == curY + 1 then open = nextOpen else open = {} end
            nextOpen = {}; curY = y
        end
        local key = x * 4096 + w
        local ok = open[key]
        if ok and out[ok + 4] == c then
            out[ok + 3] = out[ok + 3] + 1
            nextOpen[key] = ok
        else
            out[n + 1] = x; out[n + 2] = y; out[n + 3] = w; out[n + 4] = 1; out[n + 5] = c
            nextOpen[key] = n + 1
            n = n + 5
        end
    end
    self.rects = out
    return out
end
--- 整张图的横向色段（缓存）：{ x, y, w, color, ... }
function Img:getRuns()
    if self.runs then return self.runs end
    local runs, n = {}, 0
    local w, h, d = self.width, self.height, self.data
    for y = 0, h - 1 do
        local x = 0
        while x < w do
            local c = d[y * w + x]
            if c then
                local x0 = x
                x = x + 1
                while x < w and d[y * w + x] == c do x = x + 1 end
                runs[n + 1] = x0; runs[n + 2] = y; runs[n + 3] = x - x0; runs[n + 4] = c
                n = n + 4
            else
                x = x + 1
            end
        end
    end
    self.runs = runs
    return runs
end

-- ---------------------------------------------------------------------------
-- 画布记录器
-- ---------------------------------------------------------------------------
local C = {}
C.__index = C
M.Canvas = C

function M.newCanvas(w, h)
    local c = setmetatable({ width = w, height = h }, C)
    c:clear()
    return c
end

-- 性能：每帧记录几千个矩形。矩形表和图元表都放进对象池循环使用，不再每帧新建（以前每帧产生约 700KB 垃圾，
-- 每隔几十帧触发一次垃圾回收，手机上表现为周期性卡顿）
local function takeItem(self, r, g, b, a)
    local pool, k = self.pool, self.npool
    local it
    if k > 0 then it = pool[k]; pool[k] = nil; self.npool = k - 1; it.n = 0
    else it = { rects = {}, n = 0 } end
    it.r, it.g, it.b, it.a, it.nosplit = r, g, b, a, nil
    return it
end

function C:clear()
    -- 原版 canvas 每帧不清屏：震屏平移时露出的边缘保留着之前的画面。
    -- 这里只记住最近一帧未平移时的背景贴图，震屏时垫在下面
    local items = self.items
    if items then
        if not self.shifted and items[1] and items[1].tex then self.lastBase = items[1] end
        local pool, k = self.pool, self.npool
        local ip, ik = self.ipool, self.nipool
        local big = 0
        for i = 1, #items do
            local it = items[i]
            if it.img then
                -- 整图引用的图元单独回收（不能混进矩形池）；震屏垫底用的背景（lastBase）不会是这种
                if ik < 1500 then it.img = nil; ik = ik + 1; ip[ik] = it end
            elseif not it.tex and k < 1500 then
                -- 大数组只留几十个循环用；其余丢掉（否则池子里每个数组都会慢慢涨到最大，占几十 MB）
                if it.n > 160 then big = big + 1; if big > 32 then it.rects = {} end end
                k = k + 1; pool[k] = it
            end
            items[i] = nil
        end
        self.npool = k
        self.nipool = ik
    else
        self.pool, self.npool = {}, 0
        self.ipool, self.nipool = {}, 0
        self.items = {}
        self.single = { self.items }
        self.bpool = { order = {}, map = {}, no = 0 }
        self.stack = {}
    end
    self.shifted = false
    self.fillStyle = '#000000'
    self.globalAlpha = 1
    self.tx, self.ty = 0, 0
    self.clip = nil
    for i = #self.stack, 1, -1 do self.stack[i] = nil end
    self.batch = nil
    self.batchDepth = 0
    self.quantize = false
end

function C:save()
    self.stack[#self.stack + 1] = { self.fillStyle, self.globalAlpha, self.tx, self.ty, self.clip }
end
function C:restore()
    local s = table.remove(self.stack)
    if s then self.fillStyle, self.globalAlpha, self.tx, self.ty, self.clip = s[1], s[2], s[3], s[4], s[5] end
end
function C:translate(x, y)
    self.tx = self.tx + x; self.ty = self.ty + y
    if x ~= 0 or y ~= 0 then self.shifted = true end
end
--- 本帧要画的全部图层（震屏时先垫上未平移的背景）
function C:layers()
    if self.shifted and self.lastBase then
        self.shakeLayers = self.shakeLayers or { {}, nil }
        self.shakeLayers[1][1] = self.lastBase; self.shakeLayers[2] = self.items
        return self.shakeLayers
    end
    return self.single
end
--- beginPath + rect + clip
function C:clipRect(x, y, w, h)
    local x0, y0, x1, y1 = x + self.tx, y + self.ty, x + w + self.tx, y + h + self.ty
    local c = self.clip
    if c then
        x0 = max(x0, c[1]); y0 = max(y0, c[2]); x1 = min(x1, c[3]); y1 = min(y1, c[4])
    end
    self.clip = { x0, y0, x1, y1 }
end

--- 批量区段：区段内互不重叠（或顺序不影响观感）的矩形按颜色合并成一次填充
function C:beginBatch(quantize)
    if self.batchDepth == 0 then
        local b = self.bpool
        for i = b.no, 1, -1 do b.order[i] = nil end
        b.no = 0
        -- 只清上一批用到的颜色（以前每次都遍历出现过的所有颜色，越玩越慢）
        local used = b.used
        if used then for i = #used, 1, -1 do local bc = used[i]; for k in pairs(bc) do bc[k] = nil end; used[i] = nil end
        else b.used = {} end
        self.batch = b; self.quantize = quantize or false
    end
    self.batchDepth = self.batchDepth + 1
end
function C:endBatch()
    self.batchDepth = self.batchDepth - 1
    if self.batchDepth > 0 then return end
    local b = self.batch
    self.batch = nil
    self.quantize = false
    local items = self.items
    local n = #items
    for i = 1, b.no do items[n + i] = b.order[i] end
end

local function addRect(self, x, y, w, h, color, alphaMul)
    -- NaN/Inf 防护：坐标异常时（如弹道 x/y 变 NaN）会把 NaN 传到引擎原生层，
    -- 那里可能直接崩溃。这里直接丢弃，保证渲染数据始终是有限数。
    if not (x == x) or not (y == y) or not (w == w) or not (h == h) then return end
    if x == math.huge or x == -math.huge or y == math.huge or y == -math.huge then return end
    if w < 0 then x = x + w; w = -w end
    if h < 0 then y = y + h; h = -h end
    if w == 0 or h == 0 then return end
    x = x + self.tx; y = y + self.ty
    local c = self.clip
    if c then
        local x1, y1 = min(x + w, c[3]), min(y + h, c[4])
        if x < c[1] then x = c[1] end
        if y < c[2] then y = c[2] end
        w = x1 - x; h = y1 - y
        if w <= 0 or h <= 0 then return end
    end
    local r, g, b, a = parseColor(color)
    a = a * alphaMul
    if a <= 0 then return end
    if a > 1 then a = 1 end
    local items = self.items
    local it
    local bt = self.batch
    if bt then
        if self.quantize then a = floor(a * 64 + 0.5) / 64; if a <= 0 then return end end
        local byColor = bt.map[color]
        if not byColor then byColor = {}; bt.map[color] = byColor end
        it = byColor[a]
        if not it then
            if next(byColor) == nil then bt.used[#bt.used + 1] = byColor end
            it = takeItem(self, r, g, b, a); it.nosplit = true
            byColor[a] = it
            bt.no = bt.no + 1; bt.order[bt.no] = it
        end
    else
        it = items[#items]
        if not (it and not it.tex and it.r == r and it.g == g and it.b == b and it.a == a) then
            it = takeItem(self, r, g, b, a)
            items[#items + 1] = it
        end
    end
    local rs, n = it.rects, it.n
    rs[n + 1] = x; rs[n + 2] = y; rs[n + 3] = w; rs[n + 4] = h
    it.n = n + 4
end

function C:fillRect(x, y, w, h)
    addRect(self, x, y, w, h, self.fillStyle, self.globalAlpha)
end

--- 裁剪 / 缩放取样：返回相对目标左上角的矩形列表 { x, y, w, h, color, ... }（和逐像素取样逐个 addRect 的结果、顺序完全一致）
--- 浏览器（Skia）的最近邻：取中心落点 (X+0.5)*sw/dw，正好落在两格交界时取左/上那一格
--- 即 ceil((2X+1)*sw / 2dw) - 1，用整数算避免浮点误差
local function cropRects(img, sx, sy, sw, sh, dw, dh)
    local out, n = {}, 0
    local w, d = img.width, img.data
    local sw2, sh2, dw2, dh2 = sw, sh, 2 * dw, 2 * dh
    for Y = 0, dh - 1 do
        local syy = sy + ((2 * Y + 1) * sh2 - 1) // dh2
        if syy >= 0 and syy < img.height then
            local rowBase = syy * w
            local X = 0
            while X < dw do
                local sxx = sx + ((2 * X + 1) * sw2 - 1) // dw2
                local c = (sxx >= 0 and sxx < w) and d[rowBase + sxx] or nil
                if c then
                    local X0 = X
                    X = X + 1
                    while X < dw do
                        local s2 = sx + ((2 * X + 1) * sw2 - 1) // dw2
                        if s2 < 0 or s2 >= w or d[rowBase + s2] ~= c then break end
                        X = X + 1
                    end
                    out[n + 1] = X0; out[n + 2] = Y; out[n + 3] = X - X0; out[n + 4] = 1; out[n + 5] = c
                    n = n + 5
                else
                    X = X + 1
                end
            end
        end
    end
    return out
end
--- 缓存键：全是不太大的非负整数时拼成一个数（不分配字符串）；否则不缓存
local function cropKey(sx, sy, sw, sh, dw, dh)
    if sx % 1 ~= 0 or sy % 1 ~= 0 or sw % 1 ~= 0 or sh % 1 ~= 0 or dw % 1 ~= 0 or dh % 1 ~= 0 then return nil end
    if sx < 0 or sy < 0 or sx >= 256 or sy >= 256 or sw > 256 or sh > 256 or dw > 1024 or dh > 1024 then return nil end
    return ((((sx * 256 + sy) * 257 + sw) * 257 + sh) * 1025 + dw) * 1025 + dh
end

--- drawImage(img, dx, dy) / (img, dx, dy, dw, dh) / (img, sx, sy, sw, sh, dx, dy, dw, dh)
--- 关闭平滑（最近邻）采样：目标像素中心映射回源图取整
function C:drawImage(img, a1, a2, a3, a4, a5, a6, a7, a8)
    local sx, sy, sw, sh, dx, dy, dw, dh
    if a5 then
        sx, sy, sw, sh, dx, dy, dw, dh = a1, a2, a3, a4, a5, a6, a7, a8
    elseif a3 then
        sx, sy, sw, sh, dx, dy, dw, dh = 0, 0, img.width, img.height, a1, a2, a3, a4
    else
        sx, sy, sw, sh, dx, dy, dw, dh = 0, 0, img.width, img.height, a1, a2, img.width, img.height
    end
    if dw <= 0 or dh <= 0 or sw <= 0 or sh <= 0 then return end
    local ga = self.globalAlpha
    if img.tex and M.textureHook and ga >= 1 and not self.clip and not self.batch
        and sx == 0 and sy == 0 and sw == img.width and sh == img.height and dw == sw and dh == sh then
        self.items[#self.items + 1] = { tex = img.tex, x = dx + self.tx, y = dy + self.ty, w = dw, h = dh }
        return
    end
    -- 第八次更新（卡顿）：整张图、原尺寸、整数位置、没有裁剪时，直接记一条「引用这张图」的图元，
    -- 显示时按图里缓存好的颜色分组画。以前要把图拆成几十个矩形逐个 addRect（每个都要解析颜色、查批量表），
    -- 战斗里每帧几百个精灵，这一步占了游戏帧一大半时间。画出来的像素完全一样
    if ga > 0 and not self.clip and not self.batch and sx == 0 and sy == 0 and sw == img.width and sh == img.height
        and dw == sw and dh == sh then
        local X, Y = dx + self.tx, dy + self.ty
        if X % 1 == 0 and Y % 1 == 0 then
            local ip, k = self.ipool, self.nipool
            local it
            if k > 0 then it = ip[k]; ip[k] = nil; self.nipool = k - 1 else it = {} end
            it.img, it.x, it.y, it.a = img, X, Y, (ga > 1) and 1 or ga
            self.items[#self.items + 1] = it
            return
        end
    end
    self:beginBatch()
    if sx == 0 and sy == 0 and sw == img.width and sh == img.height and dw == sw and dh == sh then
        local rs = img:getRects()
        for i = 1, #rs, 5 do
            addRect(self, dx + rs[i], dy + rs[i + 1], rs[i + 2], rs[i + 3], rs[i + 4], ga)
        end
    else
        -- 第十五次更新（卡顿）：裁剪 / 缩放取样的结果按（源矩形, 目标尺寸）缓存在图上。
        -- 攻击时身体前倾是逐行裁剪绘制（每个出手的单位每帧十几次），以前每次都逐像素重新取样
        local key = cropKey(sx, sy, sw, sh, dw, dh)
        local crops = img.crops
        local list = key and crops and crops[key]
        if not list then
            list = cropRects(img, sx, sy, sw, sh, dw, dh)
            if key then
                if not crops or img.ncrops >= 192 then crops = {}; img.crops = crops; img.ncrops = 0 end
                crops[key] = list; img.ncrops = img.ncrops + 1
            end
        end
        for i = 1, #list, 5 do
            addRect(self, dx + list[i], dy + list[i + 1], list[i + 2], list[i + 3], list[i + 4], ga)
        end
    end
    self:endBatch()
end

-- ---------------------------------------------------------------------------
-- 显示：把记录下的矩形按最近邻放大画到 NanoVG（坐标对齐到物理像素，和 pixelated 一样整齐）
-- x, y, w, h 是逻辑像素（CSS 像素），dpr 为设备像素比
-- ---------------------------------------------------------------------------
--- 源图第 k 条像素边界在目标上的位置（物理像素）：
--- Chromium 先把内容框对齐到物理像素（宽 W），再按像素中心最近邻取样：
--- 按像素中心最近邻取样
local function edge(k, W, src)
    -- Skia：目标像素 X 取源像素 ceil((X + 0.5) * src / W) - 1，边界 k 落在 floor(k * W / src - 0.5) + 1
    return (2 * k * W - src) // (2 * src) + 1
end
M.edge = edge
--- 整张图的边界表（按 W、src 缓存）：tbl[k] = edge(k, W, src)，k 可以超出 0..src
local edgeCache = {}
local function edgeTable(W, src)
    local key = W * 65536 + src
    local t = edgeCache[key]
    if not t then
        t = setmetatable({}, { __index = function(tt, k)
            local v = (2 * k * W - src) // (2 * src) + 1
            rawset(tt, k, v)
            return v
        end })
        edgeCache[key] = t
    end
    return t
end

--- NanoVG 颜色对象缓存：同一种颜色每帧会用到很多次，不必每次都新建（减少垃圾回收）
local rgbaCache, rgbaN = {}, 0
function M.rgba(r, g, b, a)
    local k = ((r * 256 + g) * 256 + b) * 256 + a
    local c = rgbaCache[k]
    if c then return c end
    rgbaN = rgbaN + 1
    if rgbaN > 3000 then rgbaCache = {}; rgbaN = 0 end
    c = nvgRGBA(r, g, b, a)
    rgbaCache[k] = c
    return c
end

local function boxOf(x, y, w, h, dpr)
    -- NaN/Inf 防护：这些值会传给 NanoVG 原生层
    if not (x == x) or not (y == y) or not (w == w) or not (h == h) then return 0, 0, 1, 1 end
    if x == math.huge or x == -math.huge or y == math.huge or y == -math.huge
        or w == math.huge or w == -math.huge or h == math.huge or h == -math.huge then return 0, 0, 1, 1 end
    local X0, Y0 = floor(x * dpr + 0.5), floor(y * dpr + 0.5)
    local X1, Y1 = floor((x + w) * dpr + 0.5), floor((y + h) * dpr + 0.5)
    return X0, Y0, X1 - X0, Y1 - Y0
end

--- 半透明的同色矩形互相重叠时，浏览器每个 fillRect 各混合一次（重叠处更深）；
--- NanoVG 一条路径只填一次，所以把它们分成互不重叠的若干层，每层单独填充
local function splitLayers(rs, n)
    if n <= 4 then return nil end
    local depth = {}
    local layerOf = {}
    local maxL = 1
    local overlap = false
    for i = 1, n, 4 do
        local x0, y0 = floor(rs[i]), floor(rs[i + 1])
        local x1, y1 = x0 + max(1, floor(rs[i + 2] + 0.5)) - 1, y0 + max(1, floor(rs[i + 3] + 0.5)) - 1
        -- 护栏：矩形尺寸异常时双层循环会跑几十亿次。超限直接放弃分层（退回普通绘制），不卡死。
        if not (x1 >= x0 and y1 >= y0) or (x1 - x0) > 8192 or (y1 - y0) > 8192 then return nil end
        local L = 0
        for yy = y0, y1 do
            local row = yy * 4096
            for xx = x0, x1 do local d = depth[row + xx]; if d and d > L then L = d end end
        end
        L = L + 1
        if L > 1 then overlap = true end
        if L > maxL then maxL = L end
        for yy = y0, y1 do
            local row = yy * 4096
            for xx = x0, x1 do depth[row + xx] = L end
        end
        layerOf[i] = L
    end
    if not overlap then return nil end
    return layerOf, maxL
end

local function colorGroups(img)
    local groups, order = img.groups, img.gorder
    if not groups then
        local runs = img:getRects()
        groups, order = {}, {}
        for i = 1, #runs, 5 do
            local c = runs[i + 4]
            local g = groups[c]
            if not g then g = {}; groups[c] = g; order[#order + 1] = c end
            g[#g + 1] = i
        end
        img.groups, img.gorder = groups, order
    end
    local cols = img.gcols
    if not cols then
        cols = {}
        for _, c in ipairs(order) do local r, g, b, a = parseColor(c); cols[c] = { r, g, b, a } end
        img.gcols = cols
    end
    return groups, order, cols
end
M.colorGroups = colorGroups

function C:drawNVG(vg, x, y, w, h, dpr, alphaMul, colorFn)
    -- 第十五次更新（卡顿）：每帧几千次调用的 NanoVG 函数先取成局部变量（省掉每次查全局表）
    local nvgRect, nvgBeginPath, nvgFill, nvgFillColor = nvgRect, nvgBeginPath, nvgFill, nvgFillColor
    local ox, oy, W, H = boxOf(x, y, w, h, dpr)
    local sw, sh = self.width, self.height
    local EX, EY = edgeTable(W, sw), edgeTable(H, sh)
    local inv = 1 / dpr
    alphaMul = alphaMul or 1
    nvgSave(vg)
    nvgShapeAntiAlias(vg, 0) -- 像素块边缘不能有抗锯齿的过渡
    for _, layer in ipairs(self:layers()) do for _, it in ipairs(layer) do
      if it.img then
        -- 整图引用：每种颜色一次填充（和以前 drawImage 的批量合并结果相同）
        local img, bx, by = it.img, it.x, it.y
        local runs = img:getRects()
        local groups, order, cols = colorGroups(img)
        local am = it.a * alphaMul
        for oi = 1, #order do
            local c = order[oi]
            local cc = cols[c]
            local r, g, b, a = cc[1], cc[2], cc[3], cc[4] * am
            if a > 1 then a = 1 end
            if colorFn then r, g, b, a = colorFn(r, g, b, a) end
            if a > 0 then
                nvgBeginPath(vg)
                local gl = groups[c]
                for j = 1, #gl do
                    local i = gl[j]
                    local rx, ry = bx + runs[i], by + runs[i + 1]
                    local X0, Y0 = ox + EX[rx], oy + EY[ry]
                    local X1, Y1 = ox + EX[rx + runs[i + 2]], oy + EY[ry + runs[i + 3]]
                    if X1 > X0 and Y1 > Y0 then
                        nvgRect(vg, X0 * inv, Y0 * inv, (X1 - X0) * inv, (Y1 - Y0) * inv)
                    end
                end
                nvgFillColor(vg, M.rgba(floor(r + 0.5), floor(g + 0.5), floor(b + 0.5), floor(a * 255 + 0.5)))
                nvgFill(vg)
            end
        end
      elseif it.tex then
        -- 纹理（整数位置、整张图）：边界同样按最近邻规则对齐；纹理加载失败时退回逐块绘制
        local tx0, ty0 = ox + EX[it.x], oy + EY[it.y]
        local tx1, ty1 = ox + EX[it.x + it.w], oy + EY[it.y + it.h]
        local ok = M.textureHook and M.textureHook(vg, it.tex, tx0 * inv, ty0 * inv, (tx1 - tx0) * inv, (ty1 - ty0) * inv, alphaMul, colorFn)
        if not ok then M.textureHook = nil end
      else
        local rs, nr = it.rects, it.n
        local r, g, b, a = it.r, it.g, it.b, it.a * alphaMul
        if colorFn then r, g, b, a = colorFn(r, g, b, a) end
        local col = M.rgba(floor(r + 0.5), floor(g + 0.5), floor(b + 0.5), floor(a * 255 + 0.5))
        -- 半透明矩形互相重叠时浏览器会叠深；矩形不多时逐个填充来还原，多了就合成一次填充（不分配临时表）
        local each = it.a < 1 and not it.nosplit and nr <= 96
        local i0, step = 1, nr
        if not each then step = nr + 1 end
        while i0 <= nr do
            nvgBeginPath(vg)
            local iEnd = each and i0 or nr
            for i = i0, iEnd, 4 do
                do
                    local rx, ry = rs[i], rs[i + 1]
                    local X0, X1, Y0, Y1
                    if rx % 1 == 0 and ry % 1 == 0 and rs[i + 2] % 1 == 0 and rs[i + 3] % 1 == 0 then
                        X0 = ox + EX[rx]; Y0 = oy + EY[ry]
                        X1 = ox + EX[rx + rs[i + 2]]; Y1 = oy + EY[ry + rs[i + 3]]
                    else
                        X0 = ox + edge(rx, W, sw); Y0 = oy + edge(ry, H, sh)
                        X1 = ox + edge(rx + rs[i + 2], W, sw); Y1 = oy + edge(ry + rs[i + 3], H, sh)
                    end
                    if X1 > X0 and Y1 > Y0 then
                        nvgRect(vg, X0 * inv, Y0 * inv, (X1 - X0) * inv, (Y1 - Y0) * inv)
                    end
                end
            end
            nvgFillColor(vg, col)
            nvgFill(vg)
            i0 = each and (i0 + 4) or (nr + 1)
        end
      end
    end end
    nvgRestore(vg)
end

--- 同样的放大规则，直接画一张像素图（界面里的 <img>）
function M.drawImageNVG(vg, img, x, y, w, h, dpr, alphaMul, colorFn)
    local nvgRect, nvgBeginPath, nvgFill, nvgFillColor = nvgRect, nvgBeginPath, nvgFill, nvgFillColor
    local ox, oy, W, H = boxOf(x, y, w, h, dpr)
    local sw, sh = img.width, img.height
    local inv = 1 / dpr
    alphaMul = alphaMul or 1
    local runs = img:getRects()
    nvgSave(vg)
    nvgShapeAntiAlias(vg, 0)
    -- 按颜色分组：同一张图里的矩形互不重叠
    -- 第十五次更新（卡顿）：界面图标每帧都画；颜色解析和边界换算改用缓存（和 drawNVG 共用），结果完全一样
    local groups, order, cols = colorGroups(img)
    local EX, EY = edgeTable(W, sw), edgeTable(H, sh)
    for _, c in ipairs(order) do
        local cc = cols[c]
        local r, g, b, a = cc[1], cc[2], cc[3], cc[4]
        nvgBeginPath(vg)
        local gl = groups[c]
        for j = 1, #gl do
            local i = gl[j]
            local rx, ry = runs[i], runs[i + 1]
            local X0 = ox + EX[rx]
            local Y0 = oy + EY[ry]
            local X1 = ox + EX[rx + runs[i + 2]]
            local Y1 = oy + EY[ry + runs[i + 3]]
            if X1 > X0 and Y1 > Y0 then nvgRect(vg, X0 * inv, Y0 * inv, (X1 - X0) * inv, (Y1 - Y0) * inv) end
        end
        a = a * alphaMul
        if colorFn then r, g, b, a = colorFn(r, g, b, a) end
        nvgFillColor(vg, M.rgba(floor(r + 0.5), floor(g + 0.5), floor(b + 0.5), floor(a * 255 + 0.5)))
        nvgFill(vg)
    end
    nvgRestore(vg)
end

-- ---------------------------------------------------------------------------
-- 软件光栅化（只用于本地测试：与浏览器 canvas 的像素逐一对比）
-- ---------------------------------------------------------------------------
function C:rasterize(bg)
    local W, H = self.width, self.height
    local buf = {}
    local br, bgc, bb = bg and bg[1] or 0, bg and bg[2] or 0, bg and bg[3] or 0
    for i = 0, W * H - 1 do buf[i * 3] = br; buf[i * 3 + 1] = bgc; buf[i * 3 + 2] = bb end
    for _, layer in ipairs(self:layers()) do for _, it in ipairs(layer) do
        local rs, a = it.rects, it.a
        for i = 1, (it.n or 0), 4 do
            local x0, y0 = max(0, rs[i]), max(0, rs[i + 1])
            local x1, y1 = min(W, rs[i] + rs[i + 2]), min(H, rs[i + 1] + rs[i + 3])
            for y = y0, y1 - 1 do
                for x = x0, x1 - 1 do
                    local k = (y * W + x) * 3
                    buf[k] = buf[k] * (1 - a) + it.r * a
                    buf[k + 1] = buf[k + 1] * (1 - a) + it.g * a
                    buf[k + 2] = buf[k + 2] * (1 - a) + it.b * a
                end
            end
        end
    end end
    return buf
end

return M
