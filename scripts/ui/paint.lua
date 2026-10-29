-- ============================================================================
-- 绘制：把排好版的盒树用 NanoVG 画出来（按 CSS 的层叠与绘制顺序）
--  * 背景（纯色 / 线性渐变 / 径向渐变 / 平铺图片）、四边独立的实线边框、外阴影 / 内阴影（含模糊）、
--    文字（逐字定位，与排版结果一致）、文字阴影、轮廓线、<img> / <canvas>
--  * 层叠上下文、z-index、overflow 裁剪与滚动、粘性定位、transform
--  * opacity / filter: grayscale 组：背后是纯色时用等价的颜色变换精确合成，否则退回逐图元透明度
-- 坐标单位是 CSS 像素；dpr 用来把盒子边缘对齐到物理像素（和 Chromium 一样）
-- ============================================================================
local CSS = require("ui.css")
local LAY = require("ui.layout")

local M = {}
local floor, ceil, max, min, abs, huge = math.floor, math.ceil, math.max, math.min, math.abs, math.huge

local parseColor = CSS.parseColor

-- ---------------------------------------------------------------------------
-- 绘制状态
-- ---------------------------------------------------------------------------
local vg, dpr, page, host
local ct = nil          -- 颜色变换：{ alpha, gray, bg = {r,g,b} | nil, parent }
local xf = { sx = 1, sy = 1, tx = 0, ty = 0 } -- 当前变换（只有平移和缩放），用于命中测试和背景记录
local clipRect = nil    -- 当前裁剪（页面坐标）{x0,y0,x1,y1}
local log = {}          -- 本帧画过的图元（页面坐标）：{ x0, y0, x1, y1, solid = {r,g,b} | nil }
local hits = {}         -- 命中测试列表（按绘制顺序）
local logPool, hitPool = {}, {} -- 复用每帧的记录表（减少垃圾回收）
local hitMax, logMax = 0, 0 -- 上一帧用到的条目数（多出来的旧条目要清掉引用）
local aaOn = true
local forceAA = false   -- 合成层（动画中的变换）里一律抗锯齿

local function snap(v) return floor(v * dpr + 0.5) / dpr end

-- 第八次更新（卡顿）：变换栈、裁剪矩形都用池子里的表循环使用（以前每帧新建几百个小表，是周期性 GC 卡顿的来源之一）
local xfPool, xfDepth = {}, 0
local clipPool, clipN = {}, 0
local function pushXf()
    xfDepth = xfDepth + 1
    local e = xfPool[xfDepth]
    if not e then e = {}; xfPool[xfDepth] = e end
    e[1], e[2], e[3], e[4], e[5], e[6], e[7] = xf.sx, xf.sy, xf.tx, xf.ty, clipRect, ct, forceAA
    nvgSave(vg)
end
local function popXf()
    local s = xfPool[xfDepth]
    xfDepth = xfDepth - 1
    xf.sx, xf.sy, xf.tx, xf.ty, clipRect, ct, forceAA = s[1], s[2], s[3], s[4], s[5], s[6], s[7]
    s[5], s[6] = nil, nil
    nvgRestore(vg)
    aaOn = nil -- 状态已恢复，未知
end
local function translate(x, y)
    if x == 0 and y == 0 then return end
    nvgTranslate(vg, x, y)
    xf.tx = xf.tx + x * xf.sx; xf.ty = xf.ty + y * xf.sy
end
local function scale(sx, sy)
    nvgScale(vg, sx, sy)
    xf.sx = xf.sx * sx; xf.sy = xf.sy * sy
end
--- 局部坐标 → 页面坐标
local function toPage(x, y) return x * xf.sx + xf.tx, y * xf.sy + xf.ty end

local function clip(x, y, w, h)
    nvgIntersectScissor(vg, x, y, w, h)
    local x0, y0 = toPage(x, y)
    local x1, y1 = toPage(x + w, y + h)
    if x1 < x0 then x0, x1 = x1, x0 end
    if y1 < y0 then y0, y1 = y1, y0 end
    if clipRect then
        x0 = max(x0, clipRect[1]); y0 = max(y0, clipRect[2]); x1 = min(x1, clipRect[3]); y1 = min(y1, clipRect[4])
    end
    -- 栈里保存的是旧矩形的引用，所以每次取池子里的新表（一帧内不复用），下一帧从头再用
    clipN = clipN + 1
    local r = clipPool[clipN]
    if not r then r = {}; clipPool[clipN] = r end
    r[1], r[2], r[3], r[4] = x0, y0, x1, y1
    clipRect = r
end

local function setAA(on)
    if forceAA then on = true end
    if aaOn ~= on then nvgShapeAntiAlias(vg, on and 1 or 0); aaOn = on end
end

-- ---------------------------------------------------------------------------
-- 颜色：经过 opacity / grayscale 组的变换
-- ---------------------------------------------------------------------------
local function grayM(r, g, b, amt)
    local s = 1 - amt
    return (0.2126 + 0.7874 * s) * r + (0.7152 - 0.7152 * s) * g + (0.0722 - 0.0722 * s) * b,
        (0.2126 - 0.2126 * s) * r + (0.7152 + 0.2848 * s) * g + (0.0722 - 0.0722 * s) * b,
        (0.2126 - 0.2126 * s) * r + (0.7152 - 0.7152 * s) * g + (0.0722 + 0.9278 * s) * b
end
--- 变换一个颜色（0~255，a 为 0~1），返回变换后的 r, g, b, a
local function xc(r, g, b, a)
    local t = ct
    while t do
        if t.gray and t.gray > 0 then r, g, b = grayM(r, g, b, t.gray) end
        if t.alpha < 1 then
            if t.bg then
                local al = t.alpha
                r = al * r + (1 - al) * t.bg[1]; g = al * g + (1 - al) * t.bg[2]; b = al * b + (1 - al) * t.bg[3]
            else
                a = a * t.alpha
            end
        end
        t = t.parent
    end
    return r, g, b, a
end
M.transformColor = function(r, g, b, a) return xc(r, g, b, a) end

local function clamp255(v) v = floor(v + 0.5); if v < 0 then return 0 elseif v > 255 then return 255 end return v end
local rgbaCache, rgbaN = {}, 0
local function rgba(r, g, b, a) -- NanoVG 颜色对象缓存（减少每帧的垃圾）
    local k = ((r * 256 + g) * 256 + b) * 256 + a
    local c = rgbaCache[k]
    if c then return c end
    rgbaN = rgbaN + 1
    if rgbaN > 3000 then rgbaCache = {}; rgbaN = 0 end
    c = nvgRGBA(r, g, b, a); rgbaCache[k] = c
    return c
end
local function nvgCol(r, g, b, a)
    r, g, b, a = xc(r, g, b, a)
    return rgba(clamp255(r), clamp255(g), clamp255(b), clamp255(a * 255))
end
local function colOf(c) return nvgCol(c[1], c[2], c[3], c[4]) end

-- ---------------------------------------------------------------------------
-- 背景记录（判断 opacity 组背后是否是一整块纯色）
-- ---------------------------------------------------------------------------
-- 第十五次更新（卡顿）：纯色直接记三个数（以前每个纯色矩形都新建一个 {r,g,b} 表，每帧几百个）。
-- 条目里 [5] 是「纯色」标记，[6][7][8] 是颜色；backdropColor 返回条目里预留的颜色表（本帧内有效）
local function logPrim(x0, y0, x1, y1, solid, sr, sg, sb)
    local px0, py0 = toPage(x0, y0)
    local px1, py1 = toPage(x1, y1)
    if px1 < px0 then px0, px1 = px1, px0 end
    if py1 < py0 then py0, py1 = py1, py0 end
    if clipRect then
        px0 = max(px0, clipRect[1]); py0 = max(py0, clipRect[2]); px1 = min(px1, clipRect[3]); py1 = min(py1, clipRect[4])
        if px1 <= px0 or py1 <= py0 then return end
    end
    local n = #log + 1
    local e = logPool[n]
    if not e then e = {}; logPool[n] = e end
    e[1], e[2], e[3], e[4] = px0, py0, px1, py1
    if solid == true then
        local c = e.col
        if not c then c = {}; e.col = c end
        c[1], c[2], c[3] = sr, sg, sb
        e[5] = c
    else
        e[5] = solid
    end
    log[n] = e
end
--- 区域背后的纯色（页面坐标）；不是纯色返回 nil
local function backdropColor(x0, y0, x1, y1)
    for i = #log, 1, -1 do
        local p = log[i]
        if p[3] > x0 and p[1] < x1 and p[4] > y0 and p[2] < y1 then
            if p[5] and p[1] <= x0 + 0.01 and p[2] <= y0 + 0.01 and p[3] >= x1 - 0.01 and p[4] >= y1 - 0.01 then
                return p[5]
            end
            return nil
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- 基本图元
-- ---------------------------------------------------------------------------
--- 实心矩形（对齐物理像素，不抗锯齿）
local function fillRect(x, y, w, h, c)
    if not c or c[4] <= 0 or w <= 0 or h <= 0 then return end
    local x0, y0, x1, y1 = snap(x), snap(y), snap(x + w), snap(y + h)
    if x1 <= x0 or y1 <= y0 then return end
    setAA(false)
    nvgBeginPath(vg)
    nvgRect(vg, x0, y0, x1 - x0, y1 - y0)
    nvgFillColor(vg, colOf(c))
    nvgFill(vg)
    local r, g, b, a = xc(c[1], c[2], c[3], c[4])
    if a >= 0.999 then logPrim(x0, y0, x1, y1, true, r, g, b) else logPrim(x0, y0, x1, y1, nil) end
end

--- 矩形环（外框减去内框）
local function fillRing(ox, oy, ow, oh, ix, iy, iw, ih, c)
    if not c or c[4] <= 0 then return end
    setAA(false)
    nvgBeginPath(vg)
    nvgRect(vg, ox, oy, ow, oh)
    if iw > 0 and ih > 0 then
        nvgRect(vg, ix, iy, iw, ih)
        nvgPathWinding(vg, NVG_HOLE)
    end
    nvgFillColor(vg, colOf(c))
    nvgFill(vg)
    logPrim(ox, oy, ox + ow, oy + oh, nil)
end

-- ---------------------------------------------------------------------------
-- CSS 值解析（按样式对象缓存）
-- ---------------------------------------------------------------------------
local function splitTop(s, sep)
    local out, depth, start = {}, 0, 1
    for i = 1, #s do
        local c = s:sub(i, i)
        if c == '(' then depth = depth + 1
        elseif c == ')' then depth = depth - 1
        elseif depth == 0 and ((sep == ' ' and c:match('%s')) or c == sep) then
            local part = s:sub(start, i - 1):match('^%s*(.-)%s*$')
            if part ~= '' then out[#out + 1] = part end
            start = i + 1
        end
    end
    local part = s:sub(start):match('^%s*(.-)%s*$')
    if part ~= '' then out[#out + 1] = part end
    return out
end
M.splitTop = splitTop

local function lenPx(v, cs, basis)
    if not v then return nil end
    if v == '0' then return 0 end
    local e = CSS.Expr.parse(v)
    if not e then return nil end
    return CSS.Expr.eval(e, { em = cs.fontSize, vw = LAY.ENV.vw, vh = LAY.ENV.vh, pct = basis, env = LAY.ENV.envVars })
end

local function isLength(t) return t:match('^%-?[%d%.]') ~= nil or t:match('^calc%(') ~= nil end

--- box-shadow / text-shadow：{ { inset, ox, oy, blur, spread, color } ... }
local function parseShadows(s, cs, isText)
    if not s or s == 'none' then return nil end
    local list = {}
    for _, part in ipairs(splitTop(s, ',')) do
        local toks = splitTop(part, ' ')
        local sh = { inset = false, nums = {} }
        for _, t in ipairs(toks) do
            if t == 'inset' then sh.inset = true
            elseif isLength(t) then sh.nums[#sh.nums + 1] = lenPx(t, cs) or 0
            else sh.color = parseColor(t == 'currentcolor' and cs.raw.color or t) end
        end
        sh.ox, sh.oy, sh.blur, sh.spread = sh.nums[1] or 0, sh.nums[2] or 0, sh.nums[3] or 0, (not isText) and (sh.nums[4] or 0) or 0
        sh.color = sh.color or cs.color
        list[#list + 1] = sh
    end
    return list
end

local function cached(cs, key, fn)
    local pc = cs.paintCache
    if not pc then pc = {}; cs.paintCache = pc end
    local v = pc[key]
    if v == nil then v = fn() or false; pc[key] = v end
    return v or nil
end

-- 第十五次更新（卡顿）：先查缓存再建闭包（以前每个盒子每帧都新建一个闭包，是绘制阶段最大的垃圾来源）
local function boxShadows(cs)
    local pc = cs.paintCache
    local v = pc and pc.bs
    if v ~= nil then return v or nil end
    return cached(cs, 'bs', function() return parseShadows(cs.raw['box-shadow'], cs, false) end)
end
local function textShadows(cs)
    local pc = cs.paintCache
    local v = pc and pc.ts
    if v ~= nil then return v or nil end
    return cached(cs, 'ts', function() return parseShadows(cs.raw['text-shadow'], cs, true) end)
end

local curBox = nil -- 正在画边框的盒子（动画可能覆盖它的边框颜色）
local function borderColor(cs, side)
    if curBox and host and host.colorOverride then
        local c = host.colorOverride(curBox, 'border-' .. side .. '-color')
        if c then return c end
    end
    local v = cs.raw['border-' .. side .. '-color']
    if not v or v == 'currentcolor' then return cs.color end
    return parseColor(v)
end

--- 渐变色标：{ { color, pos(0~1 或 nil) } ... }，按 CSS 规则补全位置
local function parseStops(parts, cs, lenBasis)
    local stops = {}
    for _, p in ipairs(parts) do
        local toks = splitTop(p, ' ')
        local col = parseColor(toks[1])
        local poss = {}
        for i = 2, #toks do
            local t = toks[i]
            if t:sub(-1) == '%' then poss[#poss + 1] = tonumber(t:sub(1, -2)) / 100
            else poss[#poss + 1] = (lenPx(t, cs) or 0) / lenBasis end
        end
        if #poss == 0 then stops[#stops + 1] = { col, nil }
        else for _, ps in ipairs(poss) do stops[#stops + 1] = { col, ps } end end
    end
    -- 补全：首尾默认 0 / 1；位置单调不减；中间缺的均分
    if stops[1][2] == nil then stops[1][2] = 0 end
    if stops[#stops][2] == nil then stops[#stops][2] = 1 end
    local last = 0
    for _, st in ipairs(stops) do if st[2] then if st[2] < last then st[2] = last end; last = st[2] end end
    local i = 1
    while i <= #stops do
        if stops[i][2] == nil then
            local j = i
            while stops[j][2] == nil do j = j + 1 end
            local a, b = stops[i - 1][2], stops[j][2]
            for k = i, j - 1 do stops[k][2] = a + (b - a) * (k - i + 1) / (j - i + 1) end
            i = j
        end
        i = i + 1
    end
    return stops
end

-- ---------------------------------------------------------------------------
-- 背景
-- ---------------------------------------------------------------------------
--- 颜色插值（预乘空间，与 CSS 一致）
local function mixPremul(c1, c2, t)
    local a = c1[4] + (c2[4] - c1[4]) * t
    if a <= 0 then return { 0, 0, 0, 0 } end
    local function ch(i) return (c1[i] * c1[4] + (c2[i] * c2[4] - c1[i] * c1[4]) * t) / a end
    return { ch(1), ch(2), ch(3), a }
end

local function paintLinear(x, y, w, h, spec, cs)
    local args = splitTop(spec, ',')
    local angle = 180
    local first = args[1]
    if first:match('deg$') then angle = tonumber(first:sub(1, -4)); table.remove(args, 1)
    elseif first:match('^to ') then
        local d = first:sub(4)
        angle = ({ top = 0, right = 90, bottom = 180, left = 270 })[d] or 180
        table.remove(args, 1)
    end
    -- 本游戏只用到水平 / 垂直方向
    local horiz = (angle % 180 == 90)
    local len = horiz and w or h
    local stops = parseStops(args, cs, len)
    local rev = (angle == 270 or angle == 0)
    setAA(false)
    for i = 1, #stops - 1 do
        local s0, s1 = stops[i], stops[i + 1]
        local p0, p1 = s0[2], s1[2]
        if p1 > p0 then
            local a0, a1 = p0 * len, p1 * len
            if rev then a0, a1 = len - a1, len - a0 end
            local rx, ry, rw, rh
            if horiz then rx, ry, rw, rh = x + a0, y, a1 - a0, h else rx, ry, rw, rh = x, y + a0, w, a1 - a0 end
            local c0, c1 = s0[1], s1[1]
            if rev then c0, c1 = c1, c0 end
            nvgBeginPath(vg)
            nvgRect(vg, rx, ry, rw, rh)
            if c0[1] == c1[1] and c0[2] == c1[2] and c0[3] == c1[3] and c0[4] == c1[4] then
                nvgFillColor(vg, colOf(c0))
            else
                local ex, ey = horiz and (rx + rw) or rx, horiz and ry or (ry + rh)
                nvgFillPaint(vg, nvgLinearGradient(vg, rx, ry, ex, ey, colOf(c0), colOf(c1)))
            end
            nvgFill(vg)
        end
    end
    -- 首尾色标之外的部分
    local sF, sL = stops[1], stops[#stops]
    local function edge(p0, p1, c)
        if p1 <= p0 then return end
        local a0, a1 = p0 * len, p1 * len
        if rev then a0, a1 = len - a1, len - a0 end
        nvgBeginPath(vg)
        if horiz then nvgRect(vg, x + a0, y, a1 - a0, h) else nvgRect(vg, x, y + a0, w, a1 - a0) end
        nvgFillColor(vg, colOf(c))
        nvgFill(vg)
    end
    edge(0, sF[2], sF[1])
    edge(sL[2], 1, sL[1])
    logPrim(x, y, x + w, y + h, nil)
end

local function paintRadial(x, y, w, h, spec, cs)
    local args = splitTop(spec, ',')
    local cx, cy = x + w / 2, y + h / 2
    local shape = args[1]
    if not parseColor(splitTop(shape, ' ')[1]) then
        table.remove(args, 1)
        local at = shape:match('at%s+(.*)$')
        if at then
            local ps = splitTop(at, ' ')
            local function pos(t, basis, origin)
                if t == 'center' then return origin + basis / 2 end
                if t == 'left' or t == 'top' then return origin end
                if t == 'right' or t == 'bottom' then return origin + basis end
                if t:sub(-1) == '%' then return origin + tonumber(t:sub(1, -2)) / 100 * basis end
                return origin + (lenPx(t, cs, basis) or 0)
            end
            cx = pos(ps[1] or 'center', w, x)
            cy = pos(ps[2] or 'center', h, y)
        end
    end
    -- circle farthest-corner
    local dx = max(abs(cx - x), abs(x + w - cx))
    local dy = max(abs(cy - y), abs(y + h - cy))
    local R = math.sqrt(dx * dx + dy * dy)
    local stops = parseStops(args, cs, R)
    nvgSave(vg)
    nvgIntersectScissor(vg, x, y, w, h)
    setAA(true)
    -- 由外向内：最外色标之外先铺满，再一圈圈画
    local sL = stops[#stops]
    nvgBeginPath(vg)
    nvgRect(vg, x, y, w, h)
    if sL[2] * R > 0 then nvgCircle(vg, cx, cy, sL[2] * R); nvgPathWinding(vg, NVG_HOLE) end
    nvgFillColor(vg, colOf(sL[1]))
    nvgFill(vg)
    for i = #stops - 1, 1, -1 do
        local s0, s1 = stops[i], stops[i + 1]
        local r0, r1 = s0[2] * R, s1[2] * R
        if r1 > r0 then
            nvgBeginPath(vg)
            nvgCircle(vg, cx, cy, r1)
            if r0 > 0 then nvgCircle(vg, cx, cy, r0); nvgPathWinding(vg, NVG_HOLE) end
            nvgFillPaint(vg, nvgRadialGradient(vg, cx, cy, r0, r1, colOf(s0[1]), colOf(s1[1])))
            nvgFill(vg)
        end
    end
    local sF = stops[1]
    if sF[2] > 0 then
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, sF[2] * R)
        nvgFillColor(vg, colOf(sF[1]))
        nvgFill(vg)
    end
    nvgRestore(vg)
    aaOn = nil
    logPrim(x, y, x + w, y + h, nil)
end

local function paintBgImage(b, img, x, y, w, h, cs, ox, oy)
    for _, layer in ipairs(splitTop(img, ',')) do
        if layer:match('^linear%-gradient') then
            paintLinear(x, y, w, h, layer:match('^linear%-gradient%((.*)%)$'), cs)
        elseif layer:match('^radial%-gradient') then
            paintRadial(x, y, w, h, layer:match('^radial%-gradient%((.*)%)$'), cs)
        elseif layer:match('^url%(') then
            local src = layer:match('^url%(%s*[\'"]?(.-)[\'"]?%s*%)$')
            local size = splitTop(cs.raw['background-size'] or 'auto', ' ')
            local tw = lenPx(size[1], cs, w)
            local th = size[2] and lenPx(size[2], cs, h) or tw
            if host and host.drawPattern then
                host.drawPattern(vg, src, x, y, w, h, ox or x, oy or y, tw, th, dpr, ct and M.transformColor or nil)
            end
            logPrim(x, y, x + w, y + h, nil)
        end
    end
end

-- ---------------------------------------------------------------------------
-- 盒子装饰：外阴影 → 背景 → 边框 → 内阴影
-- ---------------------------------------------------------------------------
local function borderBox(b)
    return b.ax, b.ay, b.w, b.h
end

local function paintOuterShadows(b, cs, x, y, w, h)
    local list = boxShadows(cs)
    if not list then return end
    local X0, Y0, X1, Y1 = snap(x), snap(y), snap(x + w), snap(y + h)
    for i = #list, 1, -1 do
        local sh = list[i]
        if not sh.inset and sh.color and sh.color[4] > 0 then
            local sx0, sy0 = X0 + sh.ox - sh.spread, Y0 + sh.oy - sh.spread
            local sx1, sy1 = X1 + sh.ox + sh.spread, Y1 + sh.oy + sh.spread
            if sh.blur <= 0 then
                -- 硬阴影：只画在边框盒外面
                setAA(false)
                nvgBeginPath(vg)
                nvgRect(vg, sx0, sy0, sx1 - sx0, sy1 - sy0)
                nvgRect(vg, X0, Y0, X1 - X0, Y1 - Y0)
                nvgPathWinding(vg, NVG_HOLE)
                nvgFillColor(vg, colOf(sh.color))
                nvgFill(vg)
            else
                local B = sh.blur
                setAA(true)
                nvgBeginPath(vg)
                nvgRect(vg, sx0 - B * 1.5, sy0 - B * 1.5, sx1 - sx0 + B * 3, sy1 - sy0 + B * 3)
                nvgRect(vg, X0, Y0, X1 - X0, Y1 - Y0)
                nvgPathWinding(vg, NVG_HOLE)
                nvgFillPaint(vg, nvgBoxGradientGaussian(vg, sx0, sy0, sx1 - sx0, sy1 - sy0, 0, B, colOf(sh.color), nvgCol(sh.color[1], sh.color[2], sh.color[3], 0)))
                nvgFill(vg)
            end
            logPrim(min(sx0, X0) - sh.blur * 1.5, min(sy0, Y0) - sh.blur * 1.5, max(sx1, X1) + sh.blur * 1.5, max(sy1, Y1) + sh.blur * 1.5, nil)
        end
    end
end

local function paintInsetShadows(b, cs, x, y, w, h)
    local list = boxShadows(cs)
    if not list then return end
    -- 内边距盒
    local px0, py0 = snap(x + b.bl), snap(y + b.bt)
    local px1, py1 = snap(x + w - b.br), snap(y + h - b.bb)
    for i = #list, 1, -1 do
        local sh = list[i]
        if sh.inset and sh.color and sh.color[4] > 0 then
            local hx0, hy0 = px0 + sh.ox + sh.spread, py0 + sh.oy + sh.spread
            local hx1, hy1 = px1 + sh.ox - sh.spread, py1 + sh.oy - sh.spread
            nvgSave(vg)
            nvgIntersectScissor(vg, px0, py0, px1 - px0, py1 - py0)
            if sh.blur <= 0 then
                setAA(false)
                nvgBeginPath(vg)
                nvgRect(vg, px0 - 1, py0 - 1, px1 - px0 + 2, py1 - py0 + 2)
                if hx1 > hx0 and hy1 > hy0 then
                    nvgRect(vg, hx0, hy0, hx1 - hx0, hy1 - hy0)
                    nvgPathWinding(vg, NVG_HOLE)
                end
                nvgFillColor(vg, colOf(sh.color))
                nvgFill(vg)
            else
                setAA(true)
                nvgBeginPath(vg)
                nvgRect(vg, px0, py0, px1 - px0, py1 - py0)
                nvgFillPaint(vg, nvgBoxGradientGaussian(vg, hx0, hy0, hx1 - hx0, hy1 - hy0, 0, sh.blur, nvgCol(sh.color[1], sh.color[2], sh.color[3], 0), colOf(sh.color)))
                nvgFill(vg)
            end
            nvgRestore(vg)
            aaOn = nil
            logPrim(px0, py0, px1, py1, nil)
        end
    end
end

local function sameCol(a, c) return a and c and a[1] == c[1] and a[2] == c[2] and a[3] == c[3] and a[4] == c[4] end
local function borderQuad(c, ax, ay, bx, by, cx, cy, dx, dy, width)
    if width <= 0 or not c or c[4] <= 0 then return end
    nvgBeginPath(vg)
    nvgMoveTo(vg, ax, ay); nvgLineTo(vg, bx, by); nvgLineTo(vg, cx, cy); nvgLineTo(vg, dx, dy)
    nvgClosePath(vg)
    nvgFillColor(vg, colOf(c))
    nvgFill(vg)
end
local function paintBorders(b, cs, x, y, w, h)
    local bt, br, bb, bl = b.bt, b.br, b.bb, b.bl
    if bt == 0 and br == 0 and bb == 0 and bl == 0 then return end
    curBox = b
    local X0, Y0, X1, Y1 = snap(x), snap(y), snap(x + w), snap(y + h)
    local I0, J0, I1, J1 = snap(x + bl), snap(y + bt), snap(x + w - br), snap(y + h - bb)
    local ct_, cr, cb, cl = borderColor(cs, 'top'), borderColor(cs, 'right'), borderColor(cs, 'bottom'), borderColor(cs, 'left')
    local same = sameCol
    local allSame = (bt == 0 or same(ct_, cl) or bl == 0) and same(ct_, cr) and same(ct_, cb) and same(ct_, cl)
    curBox = nil
    if allSame then
        fillRing(X0, Y0, X1 - X0, Y1 - Y0, I0, J0, I1 - I0, J1 - J0, ct_)
        return
    end
    -- 各边颜色不同：梯形，角上斜接（抗锯齿）
    local quad = borderQuad
    setAA(true)
    quad(ct_, X0, Y0, X1, Y0, I1, J0, I0, J0, bt)
    quad(cr, X1, Y0, X1, Y1, I1, J1, I1, J0, br)
    quad(cb, X1, Y1, X0, Y1, I0, J1, I1, J1, bb)
    quad(cl, X0, Y1, X0, Y0, I0, J0, I0, J1, bl)
    logPrim(X0, Y0, X1, Y1, nil)
    curBox = nil
end

local function paintDecorations(b, cs, skipBg)
    local x, y, w, h = borderBox(b)
    paintOuterShadows(b, cs, x, y, w, h)
    if not skipBg then
        local bgc = parseColor(cs.raw['background-color'])
        if bgc and bgc[4] > 0 then fillRect(x, y, w, h, bgc) end
        local img = cs.raw['background-image']
        if img and img ~= 'none' then
            paintBgImage(b, img, x + b.bl, y + b.bt, w - b.bl - b.br, h - b.bt - b.bb, cs)
        end
    end
    paintBorders(b, cs, x, y, w, h)
    paintInsetShadows(b, cs, x, y, w, h)
end

local function paintOutline(b, cs)
    local st = cs.raw['outline-style']
    if not st or st == 'none' then return end
    local ow = lenPx(cs.raw['outline-width'], cs) or 3
    if cs.raw['outline-width'] == 'medium' then ow = 3 elseif cs.raw['outline-width'] == 'thin' then ow = 1 end
    local off = lenPx(cs.raw['outline-offset'], cs) or 0
    local c = parseColor(cs.raw['outline-color'] == 'currentcolor' and cs.raw.color or cs.raw['outline-color']) or cs.color
    local x, y, w, h = borderBox(b)
    local X0, Y0, X1, Y1 = snap(x - off), snap(y - off), snap(x + w + off), snap(y + h + off)
    local o = snap(ow)
    fillRing(X0 - o, Y0 - o, X1 - X0 + 2 * o, Y1 - Y0 + 2 * o, X0, Y0, X1 - X0, Y1 - Y0, c)
end

-- ---------------------------------------------------------------------------
-- 文字
-- ---------------------------------------------------------------------------
local function fontFace(cs)
    return (cs.fontWeight >= 600) and (host and host.fontBold or 'sil-b') or (host and host.fontRegular or 'sil')
end

--- 码点 → 单字字符串（缓存，减少每帧新建字符串）
local charOf = setmetatable({}, { __index = function(t, cp) local c = utf8.char(cp); rawset(t, cp, c); return c end })
--- 一个文本片段：逐字放到排版给出的位置
local function drawFragGlyphs(fr, x0, baseline)
    local it = fr.it
    local a16, dx = fr.a16 or it.a16, fr.dx
    local cps = it.cps
    local x16 = 0
    for i = fr.i0, fr.i1 do
        local cp = cps[i]
        if cp ~= 32 then
            local gx = x0 + x16 / 65536 + ((dx and dx[i]) or 0)
            nvgText(vg, gx, baseline, charOf[cp])
        end
        x16 = x16 + a16[i]
    end
end

local function paintTextFrag(fr, x0, baseline)
    local cs = fr.cs
    local col = cs.color
    nvgFontFace(vg, fontFace(cs))
    nvgFontSize(vg, cs.fontSize)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_BASELINE)
    local shadows = textShadows(cs)
    if shadows then
        -- 第一个阴影在最上面：倒序画
        for i = #shadows, 1, -1 do
            local sh = shadows[i]
            if sh.color and sh.color[4] > 0 then
                -- Chromium 的模糊半径 B 对应高斯 sigma = B/2；fontstash 的 blur 参数约为 sigma / 0.577
                nvgFontBlur(vg, sh.blur > 0 and (sh.blur / 2 / 0.57735) or 0)
                nvgFillColor(vg, colOf(sh.color))
                drawFragGlyphs(fr, x0 + sh.ox, baseline + sh.oy)
            end
        end
        nvgFontBlur(vg, 0)
    end
    if col and col[4] > 0 then
        nvgFillColor(vg, colOf(col))
        drawFragGlyphs(fr, x0, baseline)
    end
    local asc = cs.fontSize * 1.03
    logPrim(x0, baseline - asc, x0 + (fr.w or 0), baseline + cs.fontSize * 0.25, nil)
end

-- ---------------------------------------------------------------------------
-- 层叠上下文
-- ---------------------------------------------------------------------------
local function isPositioned(b) return b.pos and b.pos ~= 'static' end
local function zOf(b)
    local z = b.cs.raw['z-index']
    if z == 'auto' or z == nil then return nil end
    return tonumber(z)
end
local function createsSC(b)
    if not b.cs or b.kind == 'text' then return false end
    local raw = b.cs.raw
    if (raw.opacity and tonumber(raw.opacity) and tonumber(raw.opacity) < 1) then return true end
    if raw.transform and raw.transform ~= 'none' then return true end
    if raw.filter and raw.filter ~= 'none' then return true end
    if b.pos == 'fixed' or b.pos == 'sticky' then return true end
    if host and host.isAnimating and host.isAnimating(b) then return true end
    if zOf(b) and (isPositioned(b) or b.isItem) then return true end
    return false
end
local function hiddenByClip(b)
    local c = b.cs and b.cs.raw.clip
    return c and c ~= 'auto' and (b.pos == 'absolute' or b.pos == 'fixed') and c:match('rect%(%s*0[%s,]+0[%s,]+0[%s,]+0')
end
local function clipsContent(b)
    local raw = b.cs and b.cs.raw
    if not raw then return false end
    local ox, oy = raw['overflow-x'], raw['overflow-y']
    return (ox and ox ~= 'visible') or (oy and oy ~= 'visible')
end

--- 子盒（按文档顺序，含 ::before / ::after），跳过文本
local function elemChildren(b) return b.children end

local paintSC, paintLayer, paintAtomic, paintBlockBg, paintContent

--- 收集层叠上下文 sc 里的定位后代与子层叠上下文。
--- 每项记下：盒子、需要先套上的祖先裁剪 / 滚动（从 sc 往下）
local EMPTY_CHAIN = {} -- 只读：没有裁剪祖先时共用
-- 第十五次更新（卡顿）：层叠上下文的条目和三个列表都从池子里取（每帧几百个小表）
local entryPool, entryN, entryMax = {}, 0, 0
local function newEntry(k, chain, z)
    entryN = entryN + 1
    local e = entryPool[entryN]
    if not e then e = {}; entryPool[entryN] = e end
    e.box, e.chain, e.z, e.order = k, chain, z, nil
    return e
end
local listPool, scDepth = {}, 0
local function byZ(a, b) if a.z ~= b.z then return a.z < b.z end return a.order < b.order end
local cNeg, cZero, cPos
local function collectWalk(b, chain)
    for _, k in ipairs(elemChildren(b)) do
        if k.kind ~= 'text' and k.ax and not hiddenByClip(k) then
            local entryChain = chain
            if k.pos == 'fixed' then entryChain = EMPTY_CHAIN end
            if createsSC(k) then
                local z = zOf(k) or 0
                local e = newEntry(k, entryChain, z)
                if z < 0 then cNeg[#cNeg + 1] = e elseif z == 0 then cZero[#cZero + 1] = e else cPos[#cPos + 1] = e end
            else
                if isPositioned(k) then cZero[#cZero + 1] = newEntry(k, entryChain, 0) end
                local sub = entryChain
                if clipsContent(k) then
                    sub = { table.unpack(entryChain) }
                    sub[#sub + 1] = k
                end
                collectWalk(k, sub)
            end
        end
    end
end
local function collect(sc, depth)
    local L = listPool[depth]
    if not L then L = { {}, {}, {} }; listPool[depth] = L end
    local neg, zero, pos = L[1], L[2], L[3]
    for i = #neg, 1, -1 do neg[i] = nil end
    for i = #zero, 1, -1 do zero[i] = nil end
    for i = #pos, 1, -1 do pos[i] = nil end
    local sn, sz, sp = cNeg, cZero, cPos
    cNeg, cZero, cPos = neg, zero, pos
    collectWalk(sc, EMPTY_CHAIN)
    cNeg, cZero, cPos = sn, sz, sp
    for i, e in ipairs(neg) do e.order = i end
    for i, e in ipairs(pos) do e.order = i end
    if #neg > 1 then table.sort(neg, byZ) end
    if #pos > 1 then table.sort(pos, byZ) end
    return neg, zero, pos
end

--- 套上裁剪 / 滚动祖先（粘性定位的偏移也在这里加上）
local function applyClipBox(b)
    -- 内边距盒裁剪 + 滚动
    local x0, y0 = snap(b.ax + b.bl), snap(b.ay + b.bt)
    local x1, y1 = snap(b.ax + b.w - b.br), snap(b.ay + b.h - b.bb)
    clip(x0, y0, x1 - x0, y1 - y0)
    local st = b.scrollTop
    if st and st ~= 0 then translate(0, -snap(st)) end
end

--- 粘性偏移。Chromium 把吸附住的粘性元素放在合成层上，总位置按「四舍五入、恰好一半时向下」对齐；
--- 盒子本身的装饰按普通规则对齐，所以平移量 = 合成层位置 − 普通对齐位置
local function stickyOffset(b)
    local dy = b.stickyDY
    if dy and dy ~= 0 then
        local Y = ceil((b.ay + dy) * dpr - 0.5)
        local Y0 = floor(b.ay * dpr + 0.5)
        translate(0, (Y - Y0) / dpr)
    end
end

--- 记录命中区域
local function addHit(b, x, y, w, h)
    if not b.el or b.cs.raw['pointer-events'] == 'none' then return end
    local x0, y0 = toPage(x, y)
    local x1, y1 = toPage(x + w, y + h)
    if x1 < x0 then x0, x1 = x1, x0 end
    if y1 < y0 then y0, y1 = y1, y0 end
    if clipRect then
        x0 = max(x0, clipRect[1]); y0 = max(y0, clipRect[2]); x1 = min(x1, clipRect[3]); y1 = min(y1, clipRect[4])
        if x1 <= x0 or y1 <= y0 then return end
    end
    local n = #hits + 1
    local e = hitPool[n]
    if e then e[1], e[2], e[3], e[4], e[5], e[6] = b.el, x0, y0, x1, y1, b
    else e = { b.el, x0, y0, x1, y1, b }; hitPool[n] = e end
    hits[n] = e
end

-- ---------------------------------------------------------------------------
-- transform（translate / scale / scaleX / scaleY），transform-origin
-- ---------------------------------------------------------------------------
local function parseTransform(cs, w, h)
    local t = cs.raw.transform
    if not t or t == 'none' then return nil end
    local ops = {}
    for name, args in t:gmatch('([%w]+)%(([^)]*)%)') do
        local a = splitTop(args, ',')
        if name == 'translate' then
            ops[#ops + 1] = { 't', lenPx(a[1], cs, w) or 0, a[2] and (lenPx(a[2], cs, h) or 0) or 0 }
        elseif name == 'translateX' then ops[#ops + 1] = { 't', lenPx(a[1], cs, w) or 0, 0 }
        elseif name == 'translateY' then ops[#ops + 1] = { 't', 0, lenPx(a[1], cs, h) or 0 }
        elseif name == 'scale' then
            local sx = tonumber(a[1]) or 1
            ops[#ops + 1] = { 's', sx, a[2] and tonumber(a[2]) or sx }
        elseif name == 'scaleX' then ops[#ops + 1] = { 's', tonumber(a[1]) or 1, 1 }
        elseif name == 'scaleY' then ops[#ops + 1] = { 's', 1, tonumber(a[1]) or 1 }
        end
    end
    return ops
end
local function originOf(cs, w, h)
    local o = cs.raw['transform-origin'] or '50% 50%'
    local ps = splitTop(o, ' ')
    local function pos(t, basis, horiz)
        if t == 'center' then return basis / 2 end
        if t == 'left' or t == 'top' then return 0 end
        if t == 'right' or t == 'bottom' then return basis end
        if t:sub(-1) == '%' then return tonumber(t:sub(1, -2)) / 100 * basis end
        return lenPx(t, cs, basis) or 0
    end
    local a, b = ps[1] or 'center', ps[2] or 'center'
    -- 'bottom center' 这种写法：关键字顺序可以颠倒
    if a == 'top' or a == 'bottom' then a, b = b, a end
    return pos(a, w, true), pos(b, h, false)
end

local function applyTransform(b)
    local cs = b.cs
    local animated = false
    local ops = host and host.transformOverride and host.transformOverride(b)
    if ops then animated = true else ops = parseTransform(cs, b.w, b.h) end
    if not ops or #ops == 0 then return end
    -- 动画中的元素在 Chromium 里是合成层：按小数位置双线性合成，边缘会混色；
    -- 这里不对齐，并在层内打开抗锯齿，效果最接近
    if animated then forceAA = true end
    local ox, oy = originOf(cs, b.w, b.h)
    translate(b.ax + ox, b.ay + oy)
    for _, op in ipairs(ops) do
        if op[1] == 't' then translate(op[2], op[3]) else scale(op[2], op[3]) end
    end
    translate(-(b.ax + ox), -(b.ay + oy))
end

--- 有效不透明度（考虑动画覆盖）
local function opacityOf(b)
    if host and host.opacityOverride then
        local o = host.opacityOverride(b)
        if o then return o end
    end
    return tonumber(b.cs.raw.opacity) or 1
end
local function grayOf(cs)
    local f = cs.raw.filter
    if not f or f == 'none' then return 0 end
    local v = f:match('grayscale%(%s*([%d%.]+)%s*%)')
    return v and tonumber(v) or 0
end

--- 组（opacity / filter）的绘制范围（页面坐标，粗略：子树的边框盒 + 阴影）
local function groupBounds(b)
    local x0, y0, x1, y1 = huge, huge, -huge, -huge
    local function add(bx)
        if bx.ax and bx.kind ~= 'text' then
            local ext = 0
            local list = bx.cs and boxShadows(bx.cs)
            if list then for _, sh in ipairs(list) do if not sh.inset then ext = max(ext, abs(sh.ox) + abs(sh.oy) + sh.spread + sh.blur * 1.5) end end end
            local ow = (bx.cs and bx.cs.raw['outline-style'] ~= 'none') and 8 or 0
            ext = max(ext, ow)
            local ax0, ay0 = toPage(bx.ax - ext, bx.ay - ext)
            local ax1, ay1 = toPage(bx.ax + bx.w + ext, bx.ay + bx.h + ext)
            x0 = min(x0, ax0); y0 = min(y0, ay0); x1 = max(x1, ax1); y1 = max(y1, ay1)
        end
        for _, c in ipairs(bx.children) do add(c) end
    end
    add(b)
    return x0, y0, x1, y1
end

-- ---------------------------------------------------------------------------
-- 块级背景阶段（层叠上下文内，非原子的块级后代的装饰按文档顺序）
-- ---------------------------------------------------------------------------
local function isAtomic(b)
    return b.inlineLevel or b.isItem or b.kind == 'replaced' or b.inLine
end

paintBlockBg = function(b)
    for _, k in ipairs(elemChildren(b)) do
        if k.kind ~= 'text' and k.kind ~= 'inline' and k.kind ~= 'br' and k.ax and not isPositioned(k) and not createsSC(k) and not isAtomic(k) and not hiddenByClip(k) then
            paintDecorations(k, k.cs, k.bgPropagated)
            addHit(k, k.ax, k.ay, k.w, k.h)
            if clipsContent(k) then
                pushXf(); applyClipBox(k)
                paintBlockBg(k)
                popXf()
            else
                paintBlockBg(k)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- 内容阶段：行内内容（文字、行内元素装饰、原子盒）、弹性 / 网格项目、块级子元素的内容
-- ---------------------------------------------------------------------------
local function paintInlineBoxDecor(ib)
    local o = ib.ifrOwner
    if not o or not ib.ifr then return end
    local cs = ib.cs
    local bgc = parseColor(cs.raw['background-color'])
    local hasBg = bgc and bgc[4] > 0
    local hasBorder = ib.bt > 0 or ib.bb > 0 or ib.bl > 0 or ib.br > 0
    for _, f in ipairs(ib.ifr) do
        local x, y = o.ax + o.lineOX + f.x, o.ay + o.lineOY + f.y
        if hasBg then fillRect(x, y, f.w, f.h, bgc) end
        if hasBorder then
            local c = borderColor(cs, 'top')
            if ib.bt > 0 then fillRect(x, y, f.w, ib.bt, c) end
            if ib.bb > 0 then fillRect(x, y + f.h - ib.bb, f.w, ib.bb, borderColor(cs, 'bottom')) end
            if f.first and ib.bl > 0 then fillRect(x, y, ib.bl, f.h, borderColor(cs, 'left')) end
            if f.last and ib.br > 0 then fillRect(x + f.w - ib.br, y, ib.br, f.h, borderColor(cs, 'right')) end
        end
        addHit(ib, x, y, f.w, f.h)
    end
end

local function chainShift(chain)
    local s = 0
    while chain do s = s + (chain[1].vaShift or 0); chain = chain.up end
    return s
end

local seenPool, seenDepth = {}, 0 -- paintLines 会经由原子盒递归：按深度复用 seen 表
local function paintLines(b)
    local lines = b.lines
    if not lines then return end
    local cx = b.ax + (b.lineOX or (b.bl + b.pl))
    local cy = b.ay + (b.lineOY or (b.bt + b.pt))
    -- 行内元素的装饰（背景、边框）先画
    seenDepth = seenDepth + 1
    local seen = seenPool[seenDepth]
    if not seen then seen = {}; seenPool[seenDepth] = seen end
    for _, ln in ipairs(lines) do
        for _, fr in ipairs(ln.frags) do
            if fr.t == 'open' then
                local ib = fr.box
                if not seen[ib] then seen[ib] = true; paintInlineBoxDecor(ib) end
            end
            local ch = fr.chain
            while ch do
                local ib = ch[1]
                if not seen[ib] then seen[ib] = true; paintInlineBoxDecor(ib) end
                ch = ch.up
            end
        end
    end
    for k in pairs(seen) do seen[k] = nil end
    seenDepth = seenDepth - 1
    for _, ln in ipairs(lines) do
        for _, fr in ipairs(ln.frags) do
            if fr.t == 'text' then
                paintTextFrag(fr, cx + ln.x + fr.x, cy + ln.baseline - chainShift(fr.chain))
            elseif fr.t == 'atom' then
                local k = fr.box
                if not isPositioned(k) and not createsSC(k) and not hiddenByClip(k) then paintAtomic(k) end
            end
        end
    end
end

local function paintReplaced(b)
    local x = b.ax + b.bl + b.pl
    local y = b.ay + b.bt + b.pt
    local w = b.w - b.bl - b.br - b.pl - b.pr
    local h = b.h - b.bt - b.bb - b.pt - b.pb
    local el = b.el
    if el.tag == 'img' then
        local src = el.attrs.src
        if src and host and host.drawImage then
            host.drawImage(vg, src, snap(x), snap(y), snap(x + w) - snap(x), snap(y + h) - snap(y), dpr, ct and M.transformColor or nil)
        end
    elseif el.tag == 'canvas' then
        if host and host.drawCanvas then
            host.drawCanvas(vg, el, x, y, w, h, dpr, ct and M.transformColor or nil)
        end
    end
    logPrim(x, y, x + w, y + h, nil)
end

paintContent = function(b)
    if b.kind == 'replaced' then paintReplaced(b); return end
    if b.lines then paintLines(b) end
    if b.kind == 'flex' or b.kind == 'grid' then
        local items = (b.kind == 'flex') and b.flexItemsList or b.gridItemsList
        if items then
            -- order 修改后的文档顺序。第十五次更新（卡顿）：按项目列表缓存排序结果，
            -- 没有 order 时直接用原列表（以前每个弹性容器每帧都新建列表并排序）
            local ordered = items
            if b.paintOrderSrc == items then ordered = b.paintOrder or items
            else
                local any = false
                for _, it in ipairs(items) do if (tonumber(it.cs and it.cs.raw.order) or 0) ~= 0 then any = true; break end end
                if any then
                    local list = {}
                    for i, it in ipairs(items) do list[#list + 1] = { it, tonumber(it.cs and it.cs.raw.order) or 0, i } end
                    table.sort(list, function(a, c) if a[2] ~= c[2] then return a[2] < c[2] end return a[3] < c[3] end)
                    ordered = {}
                    for i, e in ipairs(list) do ordered[i] = e[1] end
                end
                b.paintOrderSrc, b.paintOrder = items, (ordered ~= items) and ordered or nil
            end
            for _, it in ipairs(ordered) do
                if it.anon then
                    if it.lines then paintLines(it) end
                elseif not isPositioned(it) and not createsSC(it) and not hiddenByClip(it) then
                    paintAtomic(it)
                end
            end
        end
        return
    end
    if b.flow then
        for _, k in ipairs(b.flow) do
            if k.anon then
                if k.lines then paintLines(k) end
            elseif k.kind ~= 'text' and k.ax and not isPositioned(k) and not createsSC(k) and not hiddenByClip(k) then
                if isAtomic(k) then
                    paintAtomic(k)
                elseif clipsContent(k) then
                    pushXf(); applyClipBox(k)
                    paintContent(k)
                    popXf()
                    paintOutline(k, k.cs)
                else
                    paintContent(k)
                    paintOutline(k, k.cs)
                end
            end
        end
    end
end

--- 原子盒：像独立的层一样一次画完（但定位后代仍归外层的层叠上下文）
paintAtomic = function(b)
    paintDecorations(b, b.cs)
    addHit(b, b.ax, b.ay, b.w, b.h)
    if clipsContent(b) then
        pushXf(); applyClipBox(b)
        paintBlockBg(b)
        paintContent(b)
        popXf()
    else
        paintBlockBg(b)
        paintContent(b)
    end
    paintOutline(b, b.cs)
end

--- 定位但不形成层叠上下文的盒子（伪层叠上下文）：只画它自己和非定位后代
paintLayer = function(b)
    stickyOffset(b)
    paintAtomic(b)
end

--- 开始一个 opacity / filter 组
local function beginGroup(b)
    local op = opacityOf(b)
    local g = grayOf(b.cs)
    if op >= 1 and g <= 0 then return false end
    if op <= 0 then return 'skip' end
    local t = { alpha = op, gray = g, parent = ct }
    if op < 1 then
        local x0, y0, x1, y1 = groupBounds(b)
        local bg = backdropColor(x0, y0, x1, y1)
        if bg then t.bg = { bg[1], bg[2], bg[3] } else nvgGlobalAlpha(vg, op); t.globalAlpha = true; t.alpha = 1 end
    end
    ct = t
    return true
end

paintSC = function(b, isRoot)
    pushXf()
    stickyOffset(b)
    if host and host.offsetY then
        local oy = host.offsetY(b)
        if oy ~= 0 then translate(0, oy) end
    end
    applyTransform(b)
    local g = beginGroup(b)
    if g == 'skip' then popXf(); return end
    scDepth = scDepth + 1
    local neg, zero, pos = collect(b, scDepth)
    if not isRoot then
        paintDecorations(b, b.cs)
        addHit(b, b.ax, b.ay, b.w, b.h)
    end
    local clipped = clipsContent(b)
    if clipped then pushXf(); applyClipBox(b) end
    -- 第十五次更新（卡顿）：不再为每个条目新建闭包
    for _, e in ipairs(neg) do
        pushXf(); for _, a in ipairs(e.chain) do applyClipBox(a) end
        paintSC(e.box)
        popXf()
    end
    paintBlockBg(b)
    paintContent(b)
    for _, e in ipairs(zero) do
        pushXf(); for _, a in ipairs(e.chain) do applyClipBox(a) end
        local k = e.box
        if createsSC(k) then paintSC(k) else paintLayer(k) end
        popXf()
    end
    for _, e in ipairs(pos) do
        pushXf(); for _, a in ipairs(e.chain) do applyClipBox(a) end
        paintSC(e.box)
        popXf()
    end
    if clipped then popXf() end
    if not isRoot then paintOutline(b, b.cs) end
    scDepth = scDepth - 1
    popXf()
end

-- ---------------------------------------------------------------------------
-- 入口
-- ---------------------------------------------------------------------------
--- 画整页。hostApi：{ drawImage(vg, src, x, y, w, h, dpr, colorFn), drawCanvas(vg, el, x, y, w, h, dpr, colorFn),
---   drawPattern(vg, src, x, y, w, h, ox, oy, tw, th, dpr, colorFn), fontRegular, fontBold,
---   transformOverride(box) -> ops | nil, opacityOverride(box) -> number | nil }
function M.paint(pg, ctx, devicePixelRatio, hostApi)
    page, vg, dpr, host = pg, ctx, devicePixelRatio or 1, hostApi
    ct = nil
    xf.sx, xf.sy, xf.tx, xf.ty = 1, 1, 0, 0
    xfDepth, clipN = 0, 0
    entryN, scDepth = 0, 0
    clipRect = nil
    for i = #log, 1, -1 do log[i] = nil end
    for i = #hits, 1, -1 do hits[i] = nil end
    aaOn = nil
    forceAA = false
    local root = pg.root
    if not root then return end
    local vw, vh = LAY.ENV.vw, LAY.ENV.vh
    -- 画布背景：html 没有背景时用 body 的（背景传播）
    local htmlCs = root.cs
    local bodyBox = nil
    for _, k in ipairs(root.children) do if k.el and k.el.tag == 'body' then bodyBox = k end end
    local src = htmlCs
    local function hasBg(cs) return (parseColor(cs.raw['background-color']) or { 0, 0, 0, 0 })[4] > 0 or (cs.raw['background-image'] and cs.raw['background-image'] ~= 'none') end
    if not hasBg(htmlCs) and bodyBox and hasBg(bodyBox.cs) then src = bodyBox.cs; bodyBox.bgPropagated = true end
    local bgc = parseColor(src.raw['background-color'])
    if bgc and bgc[4] > 0 then fillRect(0, 0, vw, vh, bgc) end
    local img = src.raw['background-image']
    if img and img ~= 'none' then paintBgImage(root, img, 0, 0, vw, vh, src, root.ax, root.ay) end
    -- body 的装饰（背景已传播时只画边框和阴影）
    paintSC(root, true)
    M.hits = hits
    -- 第八次更新（内存泄漏）：绘制记录 / 命中记录的对象池只增不减。某一帧条目变少时，
    -- 多出来的旧条目仍然引用着以前帧的元素和盒子；每次重排都会生成一棵新的盒子树，
    -- 这些旧条目就把一代代旧盒子树（连同 cs 样式对象）全部留在内存里（25000 帧后常驻 261MB）。
    -- 每帧画完把超出本帧数量的旧条目清空引用即可。
    local nh = #hits
    for i = nh + 1, hitMax do local e = hitPool[i]; if e then e[1] = nil; e[6] = nil end end
    hitMax = nh
    local nl = #log
    for i = nl + 1, logMax do local e = logPool[i]; if e then e[5] = nil end end
    logMax = nl
    -- 层叠条目池同理：多出来的旧条目清掉对盒子的引用
    for i = entryN + 1, entryMax do local e = entryPool[i]; if e then e.box = nil; e.chain = nil end end
    entryMax = entryN
    for _, L in pairs(listPool) do for j = 1, 3 do local t = L[j]; for i = #t, 1, -1 do t[i] = nil end end end
end

--- 命中测试：返回最上层的元素（页面坐标）
function M.hitTest(x, y)
    local hs = M.hits
    if not hs then return nil end
    for i = #hs, 1, -1 do
        local h = hs[i]
        if x >= h[2] and x < h[4] and y >= h[3] and y < h[5] then return h[1], h[6] end
    end
    return nil
end

return M
