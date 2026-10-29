-- ============================================================================
-- 自适应排版（第四次更新：设计分辨率 + 三栏布局 + 安全区）
--
-- 设计分辨率：以「短边 400 设计像素」为基准（main.lua 的 uiZoom）。手机 1 设计像素 = 1 dp / pt，
-- 平板、电脑按短边放大，所以所有设备看到的比例接近，字号不会变得很小。
--
-- 横屏按屏幕比例自动在三种排法里选「战场最大」的一种，然后把剩下的空间分给老虎机和信息：
--   A 三栏：信息栏 | 战场 | 老虎机          （手机横屏 19.5:9、20:9，带鱼屏 21:9）
--   B 两栏：战场 + 下方信息 | 老虎机         （16:9 电脑、16:10 / 4:3 平板、老式 16:9 手机）
--   P 竖排：顶栏 / 战场 / 信息 / 老虎机       （竖屏手机、竖放平板、接近正方形的折叠屏内屏）
-- 战场永远不被界面遮挡（取消了以前浮在战场上的信息层）；所有界面都在安全区以内，
-- 刘海、灵动岛、挖孔摄像头、圆角和底部横条的位置只铺背景。
--
-- 估算出的高度会在排版后用实际测量值校正（LAYOUT.fix），保证不裁切、不留空。
-- 尺寸写进 CSS 变量（--aw 战场宽、--dw 信息栏宽、--sw 老虎机栏宽、--slot 转轴边长……），样式见 content.lua 末尾
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local floor, max, min = math.floor, math.max, math.min
local function _id(id) return PAGE.doc.getElementById(id) end
local clamp = js.clamp

LAYOUT = { key = nil, mode = nil, meas = {} }
local FRAME = 6 -- 战场边框（左右各 3px）
local ASP = 176 / 256
local MIN_FIELD_W = 40 -- 战场宽度下限：再小就没有可玩性，且负/零尺寸会产出非法绘制参数
local MIN_VIEW = 60 -- 排版可用视口下限（W/H）：容器报出 0 或负数时按这个值排版
-- 横屏灵动岛胶囊的高度（dp）。胶囊垂直居中，只挡住屏幕中间这一段：
-- 上下没有遮挡的面板可以铺到屏幕最边缘，只有与胶囊重叠的那一段才需要让位。
local ISLAND_CAP_H = 96
-- 面板与胶囊纵向重叠超过这个高度（dp）才认为「被压住」需要让位。
-- 只擦到几像素的不让：那样整块缩进会白扔掉左边一大条空白。
local CAP_MIN_OVERLAP = 12
-- 战场宽↔高换算。两侧都必须托底到 FRAME：高度小于边框时 (h-FRAME) 为负，
-- 除以 ASP(0.6875) 会被放大 1.45 倍，得到一个很大的负数（矮屏实测 bOfH(-6) = -11.5，
-- 极端视口能算出 -145 万），这个负数会一路写进 CSS 变量和绘制尺寸，
-- 在 WebGPU 上表现为 device lost。调用点仍会各自 clamp，这里先兜一层。
local function bhOf(b) return (max(b or 0, FRAME) - FRAME) * ASP + FRAME end -- 战场宽 → 高
local function bOfH(h) return (max(h or 0, FRAME) - FRAME) / ASP + FRAME end -- 战场高 → 宽

local function px(v) return tostring(floor(v + 0.5)) .. 'px' end

--- 判断 a 是否在 b 的祖先链上（含 b 自身）
local function isAncestorOf(a, b)
    local p, guard = b, 0
    while p do
        if p == a then return true end
        p = p.parent
        guard = guard + 1
        if guard > 64 then return true end -- 已有环：当作祖先处理，避免继续
    end
    return false
end

--- 把元素挪到 parent 里 ref 之前（ref 为 nil 时放到最后）
local function moveBefore(el, parent, ref)
    if not el or not parent then return end
    -- 防自引用/环：把元素插进自己或自己的后代，会造出 DOM 环，后续 parent 链遍历会死循环
    if el == parent or el == ref or isAncestorOf(el, parent) then return end
    local kids = parent.children
    if el.parent == parent then
        local idx
        for i, c in ipairs(kids) do if c == el then idx = i end end
        if (ref == nil and idx == #kids) or (ref and kids[idx + 1] == ref) then return end
    end
    el:remove()
    el.parent = parent
    local pos = #kids + 1
    if ref then for i, c in ipairs(kids) do if c == ref then pos = i end end end
    table.insert(kids, pos, el)
    if parent.doc then require("ui.dom").adopt(el, parent.doc) end
    PAGE:invalidate(parent)
end
local function moveFirst(el, parent)
    if not el or not parent or parent.children[1] == el then return end
    if el == parent or isAncestorOf(el, parent) then return end
    moveBefore(el, parent, parent.children[1])
end

-- ---------------------------------------------------------------------------
-- 各块的高度估算（设计像素）；排版后由 LAYOUT.fix 用实测值覆盖
-- ---------------------------------------------------------------------------
local M = LAYOUT.meas
local function bucket(w) return floor(w / 8) end
local function measured(kind, w, est)
    local t = M[kind]
    local v = t and t[bucket(w)]
    return v or est
end
local HUGE = 1e6
local function hudBarH(w) return measured('hudbar', w, (w >= 330) and 44 or 60) end
local function hudSideH(w) return measured('hudside', w, (w >= 330) and 58 or 84) end
--- 「下一波敌人」框：内容再多也在框内滚动，所以高度按上限算（与 CSS --marqmax 一致）
local MARQ_MAX = 76
local function marqH(w) return measured('marq', w, MARQ_MAX) end
local function fbarMarqH(w) return measured('fmarq', 0, 34) end
local function luckH(w) return measured('luck', w, (w >= 300) and 36 or 50) end
--- 道具栏：圣物 8 格 + 消耗品 3 格（第十五次更新：圣物 5 → 8）。
--- 战场下方（itemsPos = 'C'）用紧凑样式（图标 18px、间距 3px），一行约 373px；
--- 右侧栏里维持常规尺寸，一行约 407px。取 380 作为「一行放得下」的门槛：
--- 下方道具栏在 380 以上仍是一行，右侧栏由 LAYOUT.fix 实测校正。
local ITEMS_ONE_ROW_W = 380
local function itemsH(w)
    if w < 176 then return HUGE end
    return measured('items', w, (w >= ITEMS_ONE_ROW_W) and 36 or ((w >= 290) and 64 or 94))
end
local FIGHT_H = 42
local CAB_CHROME = 24 -- 柜子边框 + 内边距（上下 / 左右合计）
local REEL_CHROME = 20 -- 转轴的金框 + 黑边
local LEVER_W = 56   -- 拉杆宽 + 间距
local LEVER_SLIM = 30 -- 第五次更新：窄栏的细拉杆（24 宽，只有杆和红球，花费写在下面的「抽取」按钮上）+ 间距
local slimW = LEVER_SLIM -- 求解时用：先按 0（第四次更新的排法）选出排法，再带上拉杆宽度在同一种排法里求尺寸
--- 转轴边长 → 老虎机栏宽。stack：转轴下面多一排「抽取 / 开战」按钮，旁边的拉杆变细
local function sideW(r, stack) return r + REEL_CHROME + CAB_CHROME + (stack and slimW or LEVER_W) end

--- 老虎机栏（竖排）里除转轴外的高度
local function cabFixed(s, gap, opt)
    local inner = s - CAB_CHROME
    local h, n = CAB_CHROME + REEL_CHROME + luckH(inner) + FIGHT_H, 3
    if opt.marq then h = h + marqH(inner); n = n + 1 end
    if opt.items then h = h + itemsH(inner); n = n + 1 end
    h = h + (n - 1) * 6
    if opt.hud then h = h + hudSideH(s) + gap end
    return h
end

-- ---------------------------------------------------------------------------
-- 求解：枚举排法和参数，取「战场面积 + 老虎机面积 − 空白」得分最高的一种
--  顶栏可以是整屏宽的一条（T），也可以放进某一栏的顶部（D / S）
--  「下一波敌人」和道具栏可以放在老虎机栏，也可以放进三栏时战场下方剩下的那条空间（C）
-- ---------------------------------------------------------------------------
local function solveLand(W, H, gap, big, want)
    local best = nil
    -- 三栏里「信息栏 + 老虎机栏」的宽度是固定开销。可用宽度窄时（超宽比手机被安全区
    -- 左右各挤掉 56dp，例如 iPhone 17 横屏，可用宽仅 ~710）两者会吃掉大半屏宽，
    -- 战场只剩约 40%。这里让两者的下限随可用宽度线性过渡，把宽度还给战场：
    --   W <= 690（很窄）→ rMin/iMin = 96/124；W >= 900（常规宽屏）→ 116/172（保持原值）
    -- 窄屏同时会走 data-dnarrow 精简样式（字号 12px、行距 1.42），信息栏压到 ~124px 仍可读。
    local narrow = clamp((W - 690) / 210, 0, 1)
    local rMin = big and 150 or floor(96 + (116 - 96) * narrow)
    local rMax = big and 300 or 220
    local iMin = big and 230 or floor(124 + (172 - 124) * narrow)
    local dMin = big and 140 or 90
    local infoMinH = big and 160 or 120
    local function consider(c)
        if want and (c.mode ~= want.mode or c.hudPos ~= want.hudPos or c.marqPos ~= want.marqPos or c.itemsPos ~= want.itemsPos or c.stack ~= want.stack) then return end
        -- 战场是主视图，权重高于老虎机；老虎机的转轴面积只作为次要项。
        -- 第七次更新：手机横屏战场优先——让出的宽度先给战场（转轴权重 0.2），
        -- 平板 / 电脑保持 0.35，避免求解器为了撑大转轴而牺牲战场宽度。
        c.score = c.aw * bhOf(c.aw) + (big and 0.35 or 0.2) * c.slot * c.slot - (c.blank or 0)
        if c.mode == 'A' then c.score = c.score * 1.03 end -- 同等大小时优先三栏（信息在战场另一侧）
        if not best or c.score > best.score then best = c end
    end
    local hudT = hudBarH(W)
    local function sideFit(s, Hc, opt)
        -- 老虎机栏：比较「拉杆在转轴旁边」和「拉杆在下面」两种，取转轴大的
        local bestR, bestStack, bestSpare = -1, false, 0
        for _, stack in ipairs({ false, true }) do
            local fixed = cabFixed(s, gap, opt)
            local rw = s - sideW(0, stack)
            local r = floor(min(rw, Hc - fixed, rMax))
            if r > bestR + 4 or (r >= bestR - 4 and not stack and bestStack) then
                bestR, bestStack, bestSpare = r, stack, Hc - fixed - r
            end
        end
        return bestR, bestStack, bestSpare
    end
    local sLo, sHi = sideW(rMin, true), floor(W * 0.42)
    -- A：信息栏 | 战场 | 老虎机
    for _, hudPos in ipairs({ 'T', 'D' }) do
        local Hc = (hudPos == 'T') and (H - hudT - gap) or H
        for _, marqPos in ipairs({ 'S', 'C' }) do
            for _, itemsPos in ipairs({ 'S', 'D', 'C' }) do
                local dNeed = infoMinH + (hudPos == 'D' and hudSideH(iMin) + gap or 0) + (itemsPos == 'D' and itemsH(iMin - 12) + gap or 0)
                local nC = (marqPos == 'C' and 1 or 0) + (itemsPos == 'C' and 1 or 0)
                if dNeed <= Hc then
                    for s = sLo, sHi, 4 do
                        local bw = W - iMin - s - gap * 2
                        if bw < 200 then break end
                        local mC = 0
                        if nC > 0 then mC = gap + ((marqPos == 'C') and fbarMarqH(bw) or 0) + ((itemsPos == 'C') and itemsH(bw - 12) or 0) + (nC == 2 and 4 or 0) end
                        local aw = floor(min(bw, bOfH(Hc - mC)))
                        if itemsPos == 'C' and aw < ITEMS_ONE_ROW_W then -- 战场窄时道具栏折成两行：按两行再算一次
                            mC = mC - itemsH(bw - 12) + itemsH(min(bw - 12, 380))
                            aw = floor(min(bw, bOfH(Hc - mC)))
                        end
                        local v = Hc - bhOf(aw) - (nC > 0 and gap or 0)
                        local r, stack, spareH = sideFit(s, Hc, { marq = marqPos == 'S', items = itemsPos == 'S' })
                        if r >= rMin and mC < HUGE then
                            local blank = 0
                            local cap = mC - gap + 14
                            if nC == 0 then blank = max(0, v - 3) * aw
                            elseif v > cap then blank = (v - cap) * aw * 1.0 end
                            local spareW = (s - sideW(0, stack)) - r
                            if spareW > 8 then blank = blank + spareW * Hc * 0.2 end
                            if spareH > 16 then blank = blank + (spareH - 16) * s * 0.35 end
                            consider({ mode = 'A', hudPos = hudPos, marqPos = marqPos, itemsPos = itemsPos, stack = stack, aw = aw, sw = s, dw = W - aw - s - gap * 2, slot = r, fbar = v, hc = Hc, blank = blank })
                        end
                    end
                end
            end
        end
    end
    -- B：战场 + 下方信息 | 老虎机（「下一波敌人」、道具栏可以放在战场和信息之间）
    for _, hudPos in ipairs({ 'T', 'S' }) do
        local Hc = (hudPos == 'T') and (H - hudT - gap) or H
        for _, marqPos in ipairs({ 'S', 'C' }) do
            for _, itemsPos in ipairs({ 'S', 'C' }) do
                for s = sLo, sHi, 4 do
                    local bw = W - s - gap
                    if bw < 200 then break end
                    local extra = 0
                    if marqPos == 'C' then extra = extra + fbarMarqH(bw) end
                    if itemsPos == 'C' then extra = extra + itemsH(bw - 12) end
                    if extra > 0 then extra = extra + gap + ((marqPos == 'C' and itemsPos == 'C') and 4 or 0) end
                    if extra >= HUGE then break end
                    local aw = floor(min(bw, bOfH(Hc - dMin - gap - extra)))
                    local sw = W - aw - gap -- 多出来的宽度给老虎机栏
                    local d = Hc - bhOf(aw) - gap - extra
                    local r, stack, spareH = sideFit(sw, Hc, { marq = marqPos == 'S', items = itemsPos == 'S', hud = hudPos == 'S' })
                    if r >= rMin then
                        local blank = 0
                        local spareW = (sw - sideW(0, stack)) - r
                        if spareW > 8 then blank = blank + spareW * Hc * 0.2 end
                        if spareH > 16 then blank = blank + (spareH - 16) * sw * 0.35 end
                        if d > 300 then blank = blank + (d - 300) * aw * 0.3 end
                        consider({ mode = 'B', hudPos = hudPos, marqPos = marqPos, itemsPos = itemsPos, stack = stack, aw = aw, sw = sw, dw = 0, slot = r, info = d, hc = Hc, blank = blank })
                    end
                end
            end
        end
    end
    return best
end

--- 竖排：顶栏 / 战场 / 信息 / 老虎机（横排柜子：转轴+拉杆 | 幸运·开战）
local function solvePort(W, H, gap, big)
    local hud = hudBarH(W)
    local infoMin = big and 140 or 110
    local sideMin = (W < 420) and 130 or 180
    local rMax = min(big and 300 or 240, W - CAB_CHROME - REEL_CHROME - LEVER_W - sideMin - 8)
    -- 柜子除转轴外的高度：跑马灯 + 道具栏 + 边框（实测值优先）
    local cabF = measured('pcab', W, CAB_CHROME + marqH(W - CAB_CHROME) + itemsH(W - CAB_CHROME) + REEL_CHROME + 12)
    local aw = floor(W)
    local r = floor(H - hud - bhOf(aw) - infoMin - cabF - gap * 3)
    if r < 100 then -- 矮屏：战场缩小，保证老虎机和信息栏完整
        r = 100
        -- 矮屏时可用高度可能还不够放下顶栏 + 信息 + 柜子（平板横屏短暂报过矮视口、
        -- 或容器刚转屏时闪过一帧异常尺寸），此时 inner 会是负数，
        -- bOfH 再放大成更大的负数 → aw 为负 → 写进 CSS/绘制尺寸 → WebGPU device lost。
        -- 兜底顺序：先按可用高度反推宽度；若高度已不够（inner 太小），
        -- 退化成按屏宽的一半铺战场——近正方形视口（平板 / 折叠屏内屏）常走到这里，
        -- 至少保证战场是个能看的矩形，而不是被压到 40px 的细条。
        local inner = H - hud - infoMin - cabF - r - gap * 3
        local byH = bOfH(max(inner, FRAME))
        aw = floor(min(W, byH))
        if aw < floor(W * 0.45) then aw = floor(max(W * 0.45, MIN_FIELD_W)) end
    end
    aw = max(MIN_FIELD_W, min(aw, floor(max(W, MIN_FIELD_W))))
    r = clamp(r, 80, max(80, rMax))
    -- 极矮视口下「顶栏 + 间距」可能超过总高，hc 会变负；它随后写进 --ih 并决定信息栏高度。
    return { mode = 'P', hudPos = 'T', marqPos = 'S', itemsPos = 'S', stack = false, aw = aw, sw = W, dw = 0, slot = r, hc = max(0, H - hud - gap), cabF = cabF,
        score = aw * bhOf(aw) + 0.35 * r * r }
end

function LAYOUT.compute(vw, vh, ins)
    local sl, sr, st, sb = ins.l or 0, ins.r or 0, ins.t or 0, ins.b or 0
    -- 横屏顶部兜底：超宽比屏幕横屏时顶部没有物理遮挡（灵动岛在左右、Home 条在底部）。
    -- 系统/容器报的 top 往往是平台浮层（测试横幅、右上角调试按钮组）占的空间，
    -- 实测能到 55~60pt，不夹掉整页会空出一大条。
    local landView = vh > 0 and (vw / vh >= 1.7)
    if landView and min(vw, vh) <= 620 then
        st = math.min(st, 4)
        -- 底部同理：容器把平台底栏也算进 bottom 时会空出一大条。
        -- 按需求直接贴到屏幕底边（横屏时 Home 指示条是叠加显示的，不挡内容）。
        sb = 0
    end
    -- 灵动岛分段避让（横屏手机）：系统左右安全区是一整条，但胶囊只占顶部一段。
    -- 这时排版按「内容可用宽度」求解（左右只留圆角边距），安全区只让顶栏那一条避开胶囊。
    local islandSeg = landView and min(vw, vh) <= 620 and (sl > 0 or sr > 0)
    local effL, effR = sl, sr
    if islandSeg then effL, effR = 0, 0 end
    local W0, H0 = vw - effL - effR, vh - st - sb
    -- 视口兜底：容器转屏、切后台回来、或被平台浮层挤压时，会短暂报出 0 / 负数 / 极小尺寸。
    -- 这些值会让 W、H 变负，进而产出负的战场宽高写进 CSS 和绘制参数，
    -- 在 WebGPU 上直接表现为 device lost。这里夹到一个能排版的最小值。
    W0, H0 = max(W0, MIN_VIEW + effL + effR), max(H0, MIN_VIEW + st + sb)
    local big = min(W0, H0) >= 470 -- 平板 / 电脑：留更多信息空间
    local pad = (min(W0, H0) < 500) and 4 or 8
    local gap = pad
    local W, H = max(W0 - pad * 2, MIN_VIEW), max(H0 - pad * 2, MIN_VIEW)
    local land = nil
    if W / max(1, H) >= 0.9 then
        -- 第五次更新：界面位置保持和第四次更新一样——先不算拉杆选出排法，再在这种排法里加上拉杆求尺寸
        slimW = 0
        local anchor = solveLand(W, H, gap, big)
        slimW = LEVER_SLIM
        land = anchor and solveLand(W, H, gap, big, anchor) or nil
        if not land then land = solveLand(W, H, gap, big) end
    end
    local port = solvePort(W, H, gap, big)
    local L = (land and land.score >= port.score) and land or port
    -- 诊断：真机布局异常时靠这行定位（安全区数值 + 选中的排法 + 关键尺寸）
    -- 同时写进 layout_trace.txt，真机拿不到控制台日志时可以直接取文件。
    local diag
    if land then
        diag = string.format('安全区 l=%.0f r=%.0f t=%.0f b=%.0f | 视口 %.0fx%.0f | mode=%s aw=%.0f sw=%.0f dw=%.0f slot=%.0f | land=%.0f port=%.0f',
            sl, sr, st, sb, vw, vh, tostring(L.mode), L.aw or 0, L.sw or 0, L.dw or 0, L.slot or 0, land.score or 0, port.score or 0)
    else
        diag = string.format('安全区 l=%.0f r=%.0f t=%.0f b=%.0f | 视口 %.0fx%.0f | mode=%s aw=%.0f（仅竖排）',
            sl, sr, st, sb, vw, vh, tostring(L.mode), L.aw or 0)
    end
    print('[拉杆军团] 排版：' .. diag)
    pcall(function()
        local f = File('layout_trace.txt', FILE_WRITE)
        if f and f:IsOpen() then f:WriteString(diag); f:Close() end
    end)
    L.vw, L.vh, L.gap, L.pad, L.W, L.H, L.big = vw, vh, gap, pad, W, H, big
    L.pt, L.pb, L.pl, L.pr = st + pad, sb + pad, sl + pad, sr + pad
    -- 横屏手机：底部贴边（sb 已夹 0，这里连 pad 也去掉，内容直达屏幕底边）
    if landView and min(vw, vh) <= 620 then L.pb = 0 end
    -- 分段避让：顶栏让完整安全区（--plh/--prh），其余内容只留圆角边距（--plc/--prc）
    L.island = islandSeg
    if islandSeg then
        -- 胶囊侧不再叠加 pad：sl 本身就是「胶囊外沿 + 余量」，再 +pad 会白空一条，
        -- 这正是横屏 iPhone 左栏看着偏空的原因。另一侧照常留 pad。
        L.plh = (sl > 0) and sl or pad
        L.prh = (sr > 0) and sr or pad
        L.plc, L.prc = pad, pad
        L.pl, L.pr = pad, pad   -- 内容边距（布局按内容可用宽度求解）
        -- 胶囊侧宽度，供 CSS 做凹槽（place() 从这里取，不能引用 compute 的局部变量）
        L.pisL = (sl > 0) and sl or 0
        L.pisR = (sr > 0) and sr or 0
        -- 胶囊在横屏时垂直居中，只挡住屏幕中间一段。胶囊上下没有遮挡，
        -- 那些面板可以直接铺到屏幕最边缘，把宽度全部用上（左列因此更宽、文字不再挤）。
        -- 这里按胶囊的实际尺寸估算它在设计像素里的上下边界，交给 CSS 做分段让位。
        if L.pisL > 0 or L.pisR > 0 then
            local capH = min(ISLAND_CAP_H, vh * 0.5)
            local capTop = (vh - capH) / 2
            L.capTop, L.capBot = capTop, capTop + capH
        else
            L.capTop, L.capBot = nil, nil
        end
    else
        L.plh, L.prh = L.pl, L.pr
        L.plc, L.prc = L.pl, L.pr
        L.pisL, L.pisR = 0, 0
        L.capTop, L.capBot = nil, nil
    end
    L.ih = L.hc
    L.wideS = (L.mode ~= 'P' and L.sw >= 300) or (L.mode == 'P' and L.W >= 560)
    -- 窄的顶栏：主页 / 音效 / 图鉴 / 玩法收进「菜单」
    local hudW = (L.hudPos == 'T') and W or ((L.hudPos == 'D') and L.dw or L.sw)
    L.hudW = hudW
    L.compact = hudW < 720
    L.short = L.mode ~= 'P' and H < 430
    -- 信息栏窄时收紧字号与行距（CSS data-dnarrow）；上限从 250 放宽到 200，
    -- 让被安全区挤压的超宽比手机也能走到精简样式。
    L.dnarrow = L.mode == 'A' and L.dw < 200
    -- 技能名气泡：随战场大小，10~13px
    L.popfs = clamp(floor(bhOf(L.aw) * 0.034), 10, 13)
    return L
end

-- ---------------------------------------------------------------------------
-- 应用：挪动元素、写 CSS 变量
-- ---------------------------------------------------------------------------
local function attr(root, k, on, v) if on then root:setAttribute(k, v or '1') else root:removeAttribute(k) end end

function LAYOUT.place(L)
    LAYOUT.cur = L
    local root = PAGE.doc.documentElement
    root:setAttribute('data-lay', L.mode)
    attr(root, 'data-hud', true, L.hudPos)
    attr(root, 'data-fbar', L.mode ~= 'P' and (L.marqPos == 'C' or L.itemsPos == 'C'))
    attr(root, 'data-dnarrow', L.dnarrow)
    attr(root, 'data-fbar2', L.mode ~= 'P' and L.aw < ITEMS_ONE_ROW_W) -- 战场下方的道具栏放不下一行：圣物、消耗品各一行
    attr(root, 'data-wide', L.wideS)
    attr(root, 'data-short', L.short)
    attr(root, 'data-narrow', L.hudW < 380)
    attr(root, 'data-hshort', L.mode ~= 'P' and L.H < 720) -- 横屏主页左右两栏，一屏放下
    attr(root, 'data-hsmall', L.mode == 'P' and L.H < 760)
    attr(root, 'data-compact', L.compact)
    attr(root, 'data-big', L.big)
    local app = _id('app')
    for k, v in pairs({ ['--aw'] = px(L.aw), ['--sw'] = px(L.sw), ['--dw'] = px(L.dw), ['--slot'] = px(L.slot), ['--gap'] = px(L.gap),
        ['--pt'] = px(L.pt), ['--pb'] = px(L.pb), ['--pl'] = px(L.pl), ['--pr'] = px(L.pr), ['--popfs'] = px(L.popfs), ['--ih'] = px(L.ih),
        ['--plh'] = px(L.plh or L.pl), ['--prh'] = px(L.prh or L.pr), ['--plc'] = px(L.plc or L.pl), ['--prc'] = px(L.prc or L.pr),
        ['--pisL'] = px(L.pisL or 0), ['--pisR'] = px(L.pisR or 0),
        -- 胶囊的上下边界（只有横屏灵动岛才有）：让 CSS 能判断哪些面板与胶囊垂直重叠
        ['--captop'] = px(L.capTop or 0), ['--capbot'] = px(L.capBot or 0),
        -- 「下一波敌人」的高度上限：敌人再多也只在框内滚动，不挤占下方幸运/开战
        ['--marqmax'] = px(L.mode == 'P' and 96 or MARQ_MAX) }) do app:setStyle(k, v) end
    attr(root, 'data-island', L.island)
    -- 胶囊在哪一侧（真机实测可能在右：手机倒过来横拿），供 CSS 决定收哪边的内边距
    attr(root, 'data-island-r', L.island and (L.pisR or 0) > (L.pisL or 0))
    local body = PAGE.doc.body
    local hud, field, side, det = body:querySelector('.hud'), body:querySelector('.field'), _id('sideCol'), _id('detailCol')
    local frame, cab = body:querySelector('.field-frame'), _id('cabinet')
    local marq, fbar, rule, info, bar = cab and cab:querySelector('.marquee') or body:querySelector('.marquee'), _id('fieldBar'), _id('ruleBar'), _id('info'), _id('itemBar')
    if not marq then marq = body:querySelector('.marquee') end
    -- 顶栏
    if L.hudPos == 'D' then moveFirst(hud, det)
    elseif L.hudPos == 'S' then moveFirst(hud, side)
    else moveFirst(hud, app) end
    -- 跑马灯「下一波敌人」：老虎机顶部，或者三栏时战场下方的条
    if L.mode ~= 'P' and L.marqPos == 'C' then moveFirst(marq, fbar)
    else moveFirst(marq, cab) end
    -- 信息栏、规则条
    if L.mode == 'A' then
        moveFirst(rule, det); if L.hudPos == 'D' then moveFirst(hud, det) end
        moveBefore(info, det, nil)
    else
        moveBefore(rule, field, nil); moveBefore(info, field, nil)
    end
    -- 道具栏
    local sideBox = cab:querySelector('.side')
    if L.mode == 'A' and L.itemsPos == 'D' then moveBefore(bar, det, info)
    elseif L.mode ~= 'P' and L.itemsPos == 'C' then moveBefore(bar, fbar, nil)
    elseif L.mode == 'P' then moveBefore(bar, cab, cab:querySelector('.cab-body'))
    else moveBefore(bar, sideBox, _id('fight')) end
    -- 拉杆永远在转轴旁边（第五次更新：拉回来了）；窄栏时转轴下面再放「抽取」按钮，和「开战」并排
    local lever, fight, act, cbody, spin = _id('lever'), _id('fight'), _id('actRow'), cab:querySelector('.cab-body'), _id('spinBtn')
    attr(root, 'data-stack', L.stack)
    moveBefore(lever, cbody, nil)
    if L.stack then moveBefore(spin, act, nil); moveBefore(fight, act, nil)
    else moveBefore(fight, sideBox, nil) end
    LAYOUT.mode = L.mode
    PAGE.full = true; PAGE.needs = true -- 根节点属性变了：整页重新匹配样式
end

function LAYOUT.apply(force)
    if not PAGE then return end
    local env = PAGE.env
    local ev = env.envVars or {}
    local ins = { l = ev['safe-area-inset-left'] or 0, r = ev['safe-area-inset-right'] or 0, t = ev['safe-area-inset-top'] or 0, b = ev['safe-area-inset-bottom'] or 0 }
    local key = env.vw .. 'x' .. env.vh .. ':' .. ins.l .. ',' .. ins.r .. ',' .. ins.t .. ',' .. ins.b
    if key == LAYOUT.key and not force then return end
    LAYOUT.key = key
    LAYOUT.ins = ins
    LAYOUT.fixN = 0
    LAYOUT.place(LAYOUT.compute(env.vw, env.vh, ins))
end

-- ---------------------------------------------------------------------------
-- 排版后校正：用实测高度替换估算值，重新求解（最多 3 次）；
-- 最后如果老虎机栏还是放不下，就把转轴缩小到正好放下
-- ---------------------------------------------------------------------------
-- 灵动岛分段让位：胶囊垂直居中，只挡住一段高度。列里与胶囊纵向重叠的面板
-- 打上 data-capover（CSS 让它们缩进胶囊宽度），其余面板直接铺到屏幕边缘。
-- 必须在排版之后再判断，所以放在 fix 里做（那时元素才有 box）。
-- ---------------------------------------------------------------------------
local function markCapOverlap(L)
    if not L.island or not L.capTop then return false end
    local det, side = _id('detailCol'), _id('sideCol')
    local cols = { { det, L.pisL > 0 }, { side, L.pisR > 0 } }
    local any = false
    for _, c in ipairs(cols) do
        local col, onCap = c[1], c[2]
        if col and col.box then
            for _, child in ipairs(col.children) do
                local b = child.box
                -- 只处理元素节点：文本节点没有 attrs / getAttribute，
                -- 混进来会每帧抛错，把整轮 UI 更新（包括顶栏秘银数字）一起带崩。
                if child.kind ~= 'text' and child.attrs ~= nil then
                    -- 只有「真的被胶囊压住一段」的面板才让位。仅仅顶部擦到胶囊圆角
                    -- 末端的不算：整块缩进 46px 会让窄栏里的文字被挤到换行/裁切，
                    -- 比角落擦到一下难看得多。判据是重叠高度既超过下限、又占到面板
                    -- 自身高度的一定比例。
                    local over = false
                    if onCap and b ~= nil and b.h > 0 then
                        local ov = min(b.ay + b.h, L.capBot) - max(b.ay, L.capTop)
                        over = ov > CAP_MIN_OVERLAP and ov >= b.h * 0.35
                    end
                    local want = over and '1' or nil
                    if child:getAttribute('data-capover') ~= want then
                        if want then child:setAttribute('data-capover', '1')
                        else child:removeAttribute('data-capover') end
                        any = true
                    end
                end
            end
        end
    end
    return any
end

-- ---------------------------------------------------------------------------
local function rec(kind, w, h)
    M[kind] = M[kind] or {}
    local b = bucket(w)
    local old = M[kind][b]
    M[kind][b] = h
    return old == nil or math.abs(old - h) > 1
end
function LAYOUT.fix()
    local L = LAYOUT.cur
    if not L or not PAGE then return end
    local body = PAGE.doc.body
    local hud, marq, luck, bar = body:querySelector('.hud'), body:querySelector('.marquee'), _id('luck'), _id('itemBar')
    if not (hud and hud.box and luck.box) then return end
    local changed = false
    local function hb(el) return el.box and el.box.h or 0 end
    if L.hudPos == 'T' then changed = rec('hudbar', hud.box.w, hb(hud)) or changed
    else changed = rec('hudside', hud.box.w, hb(hud)) or changed end
    if marq and marq.box and L.marqPos == 'S' then changed = rec('marq', marq.box.w, hb(marq)) or changed end
    if marq and marq.box and L.marqPos == 'C' then
        local nat = (marq.box.bt or 0) + (marq.box.bb or 0) + 8
        for _, c in ipairs(marq.box.children or {}) do if c.h then nat = nat + c.h end end
        changed = rec('fmarq', 0, nat) or changed
    end
    if L.mode == 'P' then
        local cab = _id('cabinet')
        if cab.box then changed = rec('pcab', L.W, hb(cab) - L.slot) or changed end
    end
    changed = rec('luck', luck.box.w, hb(luck)) or changed
    if bar and bar.box and bar.box.h > 0 then changed = rec('items', bar.box.w, hb(bar)) or changed end
    -- 灵动岛分段让位：标记与胶囊纵向重叠的面板（标记变了要重排一次）
    if markCapOverlap(L) then changed = true end
    LAYOUT.fixN = (LAYOUT.fixN or 0) + 1
    -- 上限 5：分段让位会先标记再重排，比纯高度校正多一轮
    if changed and LAYOUT.fixN <= 5 then
        LAYOUT.place(LAYOUT.compute(L.vw, L.vh, LAYOUT.ins))
        return true
    end
    -- 兜底：老虎机柜的内容超出柜子就缩小转轴
    local cab = _id('cabinet')
    local over = 0
    if cab and cab.box and cab.box.ay then
        local cb = cab.box
        local bottom = cb.ay + cb.h - (cb.bb or 0) - 4
        for _, c in ipairs(cb.children or {}) do
            if c.kind ~= 'text' and c.ay and c.h and c.h > 0 then over = max(over, c.ay + c.h - bottom) end
        end
    end
    if over > 0.5 and L.slot > 60 and (LAYOUT.fixN or 0) <= 6 then
        L.slot = floor(max(60, L.slot - over - 1))
        _id('app'):setStyle('--slot', px(L.slot))
        return true
    end
    return false
end

-- 每次界面更新：先确认排版，再按需要校正
local _update = UI.update
function UI.update()
    LAYOUT.apply()
    _update()
    if (LAYOUT.fixN or 0) <= 6 and LAYOUT.cur and not LAYOUT.cur.settled then
        PAGE:update()
        if not LAYOUT.fix() then LAYOUT.cur.settled = true end
    end
    local info = UI.els.info
    if info then info:removeClass('idle') end
    -- 「抽取」按钮和拉杆同步：能不能点、钱够不够、花费
    local lever, spin = UI.els.lever, UI.els.spinBtn
    if lever and spin then
        spin:setDisabled(lever:isDisabled())
        spin:toggleClass('poor', lever:hasClass('poor'))
        UI.set(UI.els.costLbl2, 'cost2', UI.els.costLbl:getText())
    end
end

-- 战斗中信息栏里的我方阵容：头像 + 血条 + 能量条（数值按 10% 取整，减少重排）
local rosterT, rosterHTML = -1, ''
function UI.rosterHTML(B)
    -- 每 0.4 秒刷新一次（每帧改信息栏会让整页重新排版）
    if G.time - rosterT < 0.4 and G.time >= rosterT then return rosterHTML end
    rosterT = G.time
    local parts = {}
    for e in js.of(B.ents) do
        if e.side == 'p' and e.unit and not e.minion then
            local u = e.unit
            local hp = e.dead and 0 or math.floor(e.hp / e.maxHp * 10 + 0.5) * 10
            local en = e.skill and math.floor((e.energy or 0) / 10) * 10 or 0
            parts[#parts + 1] = '<span class="ro' .. (e.dead and ' dead' or '') .. '" style="--qc:' .. QUAL[u.q or 0].color .. '"><img src="' .. unitIconURL(u) .. '" alt=""><span class="bars"><span class="hpb"><i style="width:' .. hp .. '%"></i></span><span class="enb"><i style="width:' .. en .. '%"></i></span></span></span>'
        end
    end
    rosterHTML = (#parts == 0) and '' or ('<span class="roster">' .. table.concat(parts) .. '</span>')
    return rosterHTML
end

-- 装备按钮（顶栏）
local _init = UI.init
function UI.init()
    _init()
    local b = _id('equipBtn')
    if b then b:addEventListener('click', function() Sound.init(); if UI.showEquipOverview then UI.showEquipOverview() end end) end
    UI.els.spinBtn, UI.els.costLbl2 = _id('spinBtn'), _id('costLbl2')
    if UI.els.spinBtn then UI.els.spinBtn:addEventListener('click', function() Sound.init(); startSpin() end) end
    LAYOUT.apply(true)
end

return true
