-- ============================================================================
-- 技能特效（更新）：所有技能——我方、敌方、首领机制——都有专属的像素动画
--  * 施法法阵：施法者脚下展开一个旋转法阵（我方六芒，敌方三角棘刺，首领更大）
--  * 招牌特效：每个技能按主题组合冲击环、光柱、天雷、刀光、旋涡、潮浪、日月等动画
--  * 逐目标反馈：技能结算前后对比所有单位的状态，被打中的、被治疗的、加护盾的、加速的、
--    眩晕 / 中毒 / 灼烧 / 流血 / 诅咒 / 减速 / 魅惑 / 复活 / 召唤的单位各自出现对应的小特效，
--    所以每个技能（包括以后新增的）都会自动带上准确的命中反馈
--  * 技能弹道：技能射出的投射物带光晕拖尾，落点有主题色的爆点
-- 动画都画在战场像素画布上（整数坐标、1 像素点阵），和原有画风一致；数量有上限，不会拖慢帧率
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, sin, cos, sqrt = math.floor, math.ceil, math.max, math.min, math.abs, math.sin, math.cos, math.sqrt
local PI, TAU = math.pi, math.pi * 2
local of = js.of

-- ---------------------------------------------------------------------------
-- 像素字体补几个字母（MISS / PHOENIX / EXP 之前画不出来）
-- ---------------------------------------------------------------------------
FONT.M = A('101', '111', '111', '101', '101'); FONT.I = A('111', '010', '010', '010', '111')
FONT.S = A('111', '100', '111', '001', '111'); FONT.P = A('111', '101', '111', '100', '100')
FONT.H = A('101', '101', '111', '101', '101'); FONT.O = A('111', '101', '101', '101', '111')
FONT.N = A('111', '101', '101', '101', '101'); FONT.E = A('111', '100', '111', '100', '111')
FONT.X = A('101', '101', '010', '101', '101'); FONT['/'] = A('001', '001', '010', '100', '100')
FONT.L = A('100', '100', '100', '100', '111'); FONT.V = A('101', '101', '101', '101', '010')
FONT.U = A('101', '101', '101', '101', '111'); FONT.A = A('010', '101', '111', '101', '101')
FONT.K = A('101', '110', '100', '110', '101'); FONT.R = A('110', '101', '110', '101', '101')
FONT.T = A('111', '010', '010', '010', '010'); FONT.G = A('111', '100', '101', '101', '111')
FONT.D = A('110', '101', '101', '101', '110'); FONT.C = A('111', '100', '100', '100', '111')
FONT.B = A('110', '101', '110', '101', '110'); FONT.F = A('111', '100', '110', '100', '100')
FONT.W = A('101', '101', '111', '111', '101'); FONT.Y = A('101', '101', '010', '010', '010')
FONT['%'] = A('101', '001', '010', '100', '101'); FONT['.'] = A('000', '000', '000', '000', '010')
FONT['*'] = A('000', '101', '010', '101', '000'); FONT[':'] = A('000', '010', '000', '010', '000')

-- ---------------------------------------------------------------------------
-- 动画队列
-- ---------------------------------------------------------------------------
FX.anims = {}
FX.MAX_ANIMS = 110
local function add(a)
    local L = FX.anims
    if #L >= FX.MAX_ANIMS then table.remove(L, 1) end
    a.t = 0; a.dur = a.dur or 0.5; a.delay = a.delay or 0; a.layer = a.layer or 1
    L[#L + 1] = a
    return a
end
FX.addAnim = add
function FX.updateAnims(dt)
    local L, w = FX.anims, 0
    for i = 1, #L do
        local a = L[i]
        a.t = a.t + dt
        if a.t < a.dur + a.delay then w = w + 1; L[w] = a end
    end
    for i = w + 1, #L do L[i] = nil end
end
local _reset = FX.reset
function FX.reset() _reset(); FX.anims = {} end

-- ---------------------------------------------------------------------------
-- 像素绘图小工具（画在战场画布 actx 上）
-- ---------------------------------------------------------------------------
-- 护栏：绘图循环的次数由半径/坐标决定，一旦上游算出 inf/nan 就会把循环撑到几十亿次而卡死。
-- 这里统一钳制输入，并在循环次数超限时截断 + 报警一次（定位用），保证不会整帧卡死。
local GUARD_MAX = 4000
local guardHit = false
local function guardN(tag, n)
    if not (n == n) then return 0 end -- nan
    if n > GUARD_MAX then
        if not guardHit then guardHit = true; print('[拉杆军团] 绘图护栏触发：' .. tag .. ' n=' .. tostring(n)) end
        return GUARD_MAX
    end
    if n < 0 then return 0 end
    return n
end
local function guardV(v) if not (v == v) then return 0 end; if v > 1e6 then return 1e6 elseif v < -1e6 then return -1e6 end return v end
local function dot(x, y, c) actx.fillStyle = c; actx:fillRect(round(x), round(y), 1, 1) end
local function ring(x, y, r, ry, c, dash, phase)
    if not (r == r) or r < 0.5 then dot(x, y, c); return end
    local n = guardN('ring', max(10, floor(TAU * r * (1 + ry) * 0.55)))
    actx.fillStyle = c
    local lx, ly = nil, nil
    for i = 0, n - 1 do
        if not dash or ((i + (phase or 0)) % 4) < 2 then
            local a = i / n * TAU
            local X, Y = round(x + cos(a) * r), round(y + sin(a) * r * ry)
            if X ~= lx or Y ~= ly then actx:fillRect(X, Y, 1, 1); lx, ly = X, Y end
        end
    end
end
--- 实心环带：按行画左右两段（矩形数和粗细无关，比逐点画省一大半）
local function band(x, y, R, th, ry, c)
    if not (R == R) or R < 1 then dot(x, y, c); return end
    actx.fillStyle = c
    local Ry = max(1, R * ry)
    local ri = R - th
    local riy = ri * ry
    local h = guardN('band', floor(Ry + 0.5))
    local X, Y = round(x), round(y)
    for dy = -h, h do
        local t = dy / Ry
        local wo = R * sqrt(max(0, 1 - t * t))
        local wi = 0
        if ri > 0 and abs(dy) < riy then local u = dy / riy; wi = ri * sqrt(max(0, 1 - u * u)) end
        local a0, a1 = round(wo), round(wi)
        if a0 <= a1 then a1 = a0 - 1 end
        if a1 < 0 then actx:fillRect(X - a0, Y + dy, a0 * 2 + 1, 1)
        else
            actx:fillRect(X - a0, Y + dy, a0 - a1, 1)
            actx:fillRect(X + a1 + 1, Y + dy, a0 - a1, 1)
        end
    end
end
local function disk(x, y, r, ry, c)
    if not (r == r) or not (ry == ry) or r <= 0 or ry <= 0 then return end
    actx.fillStyle = c
    local h = guardN('disk', max(1, floor(r * ry)))
    for dy = -h, h do
        local w = round(r * sqrt(max(0, 1 - (dy / (r * ry)) ^ 2)))
        if w > 0 then actx:fillRect(round(x - w), round(y + dy), w * 2, 1) end
    end
end
--- 像素直线：同一行（或同一列）上相邻的点合成一段矩形，长线也只要几十个矩形
local function line(x0, y0, x1, y1, c)
    x0, y0, x1, y1 = guardV(x0), guardV(y0), guardV(x1), guardV(y1)
    local n = guardN('line', max(1, round(max(abs(x1 - x0), abs(y1 - y0)))))
    actx.fillStyle = c
    local horiz = abs(x1 - x0) >= abs(y1 - y0)
    local sx, sy, len = nil, nil, 0
    local px, py = nil, nil
    for i = 0, n do
        local X, Y = round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)
        if X ~= px or Y ~= py then
            if sx and ((horiz and Y == sy and X == px + ((x1 >= x0) and 1 or -1)) or (not horiz and X == sx and Y == py + ((y1 >= y0) and 1 or -1))) then
                len = len + 1
            else
                if sx then
                    if horiz then actx:fillRect(min(sx, px), sy, len, 1) else actx:fillRect(sx, min(sy, py), 1, len) end
                end
                sx, sy, len = X, Y, 1
            end
            px, py = X, Y
        end
    end
    if sx then
        if horiz then actx:fillRect(min(sx, px), sy, len, 1) else actx:fillRect(sx, min(sy, py), 1, len) end
    end
end
local function ease(k) return 1 - (1 - k) * (1 - k) end
local function posOf(a)
    if a.ent then return a.ent.x + (a.dx or 0), a.ent.y + (a.dy or 0) end
    return a.x, a.y
end
local function alphaOf(a, k) -- 淡入 15%，淡出最后 35%
    local fin = min(1, k / 0.15)
    local fout = (k > 0.65) and (1 - (k - 0.65) / 0.35) or 1
    return max(0, min(fin, fout)) * (a.alpha or 1)
end

local D = {} -- 各种动画的画法：D[kind](a, k, x, y)
-- 扩散冲击环
D.ring = function(a, k, x, y)
    local e = ease(k)
    local r = a.r0 + (a.r1 - a.r0) * e
    local al = (1 - k) * (a.alpha or 1)
    actx.globalAlpha = al
    if a.dash then ring(x, y, r, a.ry or 0.55, a.col, true, floor(G.time * 12)); return end
    local th = a.thick or 1
    band(x, y, r, 1, a.ry or 0.55, a.col)
    if th >= 2 and r > 2 then actx.globalAlpha = al * ((th >= 3) and 0.7 or 1); band(x, y, r - 1, th - 1, a.ry or 0.55, a.col2 or a.col) end
end
-- 地面光斑
D.disk = function(a, k, x, y)
    local r = a.r0 + ((a.r1 or a.r0) - a.r0) * ease(k)
    actx.globalAlpha = alphaOf(a, k) * (a.alpha or 0.35)
    disk(x, y, r, a.ry or 0.55, a.col)
end
-- 施法法阵：外圈 + 内圈虚线 + 旋转符文；敌方是三角棘刺
D.rune = function(a, k, x, y)
    local s = 0.55 + 0.45 * ease(min(1, k * 3))
    local r = a.r * s
    local ry = 0.5
    local al = alphaOf(a, k)
    local rot = G.time * (a.enemy and -3 or 2.4)
    actx.globalAlpha = al * 0.22
    disk(x, y, r, ry, a.col)
    actx.globalAlpha = al
    band(x, y, r, 1, ry, a.col)
    ring(x, y, r * 0.7, ry, a.col2 or a.col, true, floor(G.time * 10))
    local n = a.enemy and 3 or 6
    local pts = {}
    for i = 0, n - 1 do
        local an = rot + i / n * TAU
        pts[i] = { x + cos(an) * r * 0.7, y + sin(an) * r * 0.7 * ry }
        -- 外圈上的符文刻度
        local cx, cy = x + cos(an) * r, y + sin(an) * r * ry
        dot(cx, cy, '#ffffff'); dot(cx + 1, cy, a.col2 or a.col); dot(cx - 1, cy, a.col2 or a.col)
    end
    actx.globalAlpha = al * 0.8
    if a.enemy then
        for i = 0, n - 1 do local p, q = pts[i], pts[(i + 1) % n]; line(p[1], p[2], q[1], q[2], a.col2 or a.col) end
        for i = 0, n - 1 do -- 往外的棘刺
            local an = rot + i / n * TAU
            line(x + cos(an) * r, y + sin(an) * r * ry, x + cos(an) * (r + 4), y + sin(an) * (r + 4) * ry, a.col)
        end
    else
        for i = 0, n - 1 do local p, q = pts[i], pts[(i + 2) % n]; line(p[1], p[2], q[1], q[2], a.col2 or a.col) end
    end
end
-- 光柱
D.pillar = function(a, k, x, y)
    local w0 = a.w or 6
    local wk = (k < 0.18) and (k / 0.18) or (1 - (k - 0.18) / 0.82)
    local w = max(1, round(w0 * wk))
    local top = y - (a.h or 40)
    local al = alphaOf(a, k)
    local segs = 5
    local hh = (y + 2 - top) / segs
    for i = 0, segs - 1 do
        local yy = round(top + i * hh)
        local fade = (i + 1) / segs
        actx.globalAlpha = al * 0.35 * fade; actx.fillStyle = a.col
        actx:fillRect(round(x - w / 2), yy, w, ceil(hh))
        actx.globalAlpha = al * 0.7 * fade; actx.fillStyle = a.col2 or a.col
        actx:fillRect(round(x - max(1, w * 0.5) / 2), yy, max(1, round(w * 0.5)), ceil(hh))
    end
    actx.globalAlpha = al * 0.9; actx.fillStyle = '#ffffff'
    actx:fillRect(round(x), top + round(hh), 1, round(y + 2 - top - hh))
end
-- 天雷：从画面顶端劈下来的折线
D.skybolt = function(a, k, x, y)
    if not a.pts then
        a.pts = {}
        local n = 6
        for i = 0, n do
            local f = i / n
            a.pts[i] = { x + ((i > 0 and i < n) and rand(-4, 4) or 0), (a.y0 or 0) + (y - 3 - (a.y0 or 0)) * f }
        end
    end
    if k > 0.4 and floor(k * 20) % 2 == 1 then return end
    local al = 1 - k * 0.7
    for i = 1, #a.pts do
        local p, q = a.pts[i - 1], a.pts[i]
        actx.globalAlpha = al * 0.6; line(p[1] + 1, p[2], q[1] + 1, q[2], a.col)
        actx.globalAlpha = al; line(p[1], p[2], q[1], q[2], (k < 0.15) and '#ffffff' or (a.col2 or '#ffffff'))
    end
    actx.globalAlpha = al * 0.4; disk(x, y + 2, 7 * (1 - k * 0.5), 0.5, a.col)
end
-- 护盾罩
D.shield = function(a, k, x, y)
    local al = alphaOf(a, k) * ((floor(G.time * 16) % 3 == 0) and 0.6 or 1)
    local r = (a.r or 9) * (0.8 + 0.2 * ease(min(1, k * 4)))
    local cy = y - 5
    actx.globalAlpha = al * 0.18; disk(x, cy, r, 1.15, a.col)
    actx.globalAlpha = al
    actx.fillStyle = a.col
    local n = guardN('shield', floor(TAU * r * 1.1))
    for i = 0, n - 1 do
        local an = i / n * TAU
        if sin(an) < 0.6 then actx:fillRect(round(x + cos(an) * r), round(cy + sin(an) * r * 1.15), 1, 1) end
    end
    for i = 0, 2 do -- 罩子上流动的高光
        local an = G.time * 4 + i * 2.1
        if sin(an) < 0.5 then dot(x + cos(an) * r, cy + sin(an) * r * 1.15, '#ffffff') end
    end
end
-- 上升箭头（增益）/ 下落箭头（减益）
local function chevron(x, y, dir, c)
    actx.fillStyle = c
    actx:fillRect(x, y, 1, 1)
    actx:fillRect(x - 1, y + dir, 1, 1); actx:fillRect(x + 1, y + dir, 1, 1)
    actx:fillRect(x - 2, y + 2 * dir, 1, 1); actx:fillRect(x + 2, y + 2 * dir, 1, 1)
end
D.arrows = function(a, k, x, y)
    local dir = a.dir or 1 -- 1 向上
    actx.globalAlpha = alphaOf(a, k)
    for i = 0, 2 do
        local ph = (k * 1.3 + i * 0.33) % 1
        local yy = (dir > 0) and round(y - 2 - ph * 16) or round(y - 18 + ph * 14)
        chevron(round(x + (i - 1) * 6), yy, dir > 0 and 1 or -1, (i == 1) and (a.col2 or a.col) or a.col)
    end
end
-- 治疗十字
D.cross = function(a, k, x, y)
    actx.globalAlpha = alphaOf(a, k)
    for i = 0, 2 do
        local ph = (k + i * 0.3) % 1
        local cx, cy = round(x + (i - 1) * 5 + sin(i * 2 + k * 6)), round(y - 4 - ph * 14)
        actx.fillStyle = (i == 1) and '#ffffff' or a.col
        actx:fillRect(cx - 1, cy, 3, 1); actx:fillRect(cx, cy - 1, 1, 3)
    end
end
-- 刀光（复用攻击动画的月牙）
D.arc = function(a, k, x, y)
    local A0, A1 = a.a0 or -2.1, a.a1 or 1.0
    local head = A0 + (A1 - A0) * ease(min(1, k / 0.45))
    local u = clamp((k - 0.3) / 0.7, 0, 1)
    local tail = max(A0 + (A1 - A0) * u, head - 2.8)
    actx.globalAlpha = 1 - u * 0.6
    drawArc(x, y, a.r, a.f or 1, tail, head, a.col, true, a.ys or 0.85)
    if a.r > 8 then drawArc(x, y, a.r - 3, a.f or 1, tail, head, a.col2 or a.col, false, a.ys or 0.85) end
end
-- 十字星爆点
D.star = function(a, k, x, y)
    local L = (a.s or 6) * ((k < 0.3) and (k / 0.3) or (1 - (k - 0.3) / 0.7))
    local X, Y = round(x), round(y)
    actx.globalAlpha = 1
    actx.fillStyle = a.col
    actx:fillRect(round(X - L), Y, round(L * 2) + 1, 1); actx:fillRect(X, round(Y - L), 1, round(L * 2) + 1)
    local d = guardN('cross', round(L * 0.45))
    for i = 1, d do dot(X + i, Y + i, a.col2 or a.col); dot(X - i, Y + i, a.col2 or a.col); dot(X + i, Y - i, a.col2 or a.col); dot(X - i, Y - i, a.col2 or a.col) end
    actx.fillStyle = '#ffffff'; actx:fillRect(X - 1, Y, 3, 1); actx:fillRect(X, Y - 1, 1, 3)
end
-- X 形斩击
D.xslash = function(a, k, x, y)
    local L = (a.s or 7) * ease(min(1, k / 0.35))
    actx.globalAlpha = 1 - max(0, k - 0.5) * 2
    line(x - L, y - L, x + L, y + L, (k < 0.2) and '#ffffff' or a.col)
    if k > 0.12 then line(x + L, y - L, x - L, y + L, (k < 0.32) and '#ffffff' or (a.col2 or a.col)) end
end
-- 放射光线
D.rays = function(a, k, x, y)
    local e = ease(k)
    actx.globalAlpha = 1 - k
    local n = guardN('rays', a.n or 8)
    for i = 0, n - 1 do
        local an = i / n * TAU + (a.rot or 0)
        local r0, r1 = (a.r or 14) * e * 0.45, (a.r or 14) * e
        line(x + cos(an) * r0, y + sin(an) * r0 * (a.ry or 0.8), x + cos(an) * r1, y + sin(an) * r1 * (a.ry or 0.8), (i % 2 == 0) and a.col or (a.col2 or a.col))
    end
end
-- 光束（直线）
D.beam = function(a, k, x, y)
    local w = max(1, round((a.w or 3) * (1 - k)))
    local dx, dy = a.x2 - a.x1, a.y2 - a.y1
    local d = max(1, hypot(dx, dy))
    local nx, ny = -dy / d, dx / d
    actx.globalAlpha = 1 - k * 0.8
    for o = -floor(w / 2), floor(w / 2) do
        line(a.x1 + nx * o, a.y1 + ny * o, a.x2 + nx * o, a.y2 + ny * o, (o == 0) and '#ffffff' or a.col)
    end
end
-- 旋涡
D.vortex = function(a, k, x, y)
    actx.globalAlpha = alphaOf(a, k)
    local r = a.r * (a.inward and (1 - k * 0.6) or (0.4 + 0.6 * ease(k)))
    for arm = 0, 2 do
        for j = 0, 11 do
            local an = arm * TAU / 3 + j * 0.4 + G.time * 9 * (a.dir or 1)
            local rr = r * (j + 1) / 12
            dot(x + cos(an) * rr, y + sin(an) * rr * (a.ry or 0.55), (j > 8) and '#ffffff' or ((j % 2 == 0) and a.col or (a.col2 or a.col)))
        end
    end
end
-- 横扫全场的潮浪
D.wave = function(a, k, x, y)
    local fx = a.x0 + (a.x1 - a.x0) * ease(k)
    actx.globalAlpha = 1 - k * 0.5
    for yy = 10, FIELD_H - 4, 2 do
        local off = round(sin(yy * 0.35 + G.time * 10) * 2)
        local X = round(fx + off)
        actx.fillStyle = a.col; actx:fillRect(X - (a.dir or 1) * 3, yy, 3, 2)
        actx.fillStyle = '#ffffff'; actx:fillRect(X, yy, 1, 1)
        if (yy % 6) == 0 then actx.fillStyle = a.col2 or a.col; actx:fillRect(X - (a.dir or 1) * 7, yy + 1, 2, 1) end
    end
end
-- 爱心（魅惑）
D.hearts = function(a, k, x, y)
    actx.globalAlpha = alphaOf(a, k)
    for i = 0, 1 do
        local cx, cy = round(x - 3 + i * 6), round(y - 14 - ((k + i * 0.4) % 1) * 10)
        actx.fillStyle = a.col
        actx:fillRect(cx - 1, cy, 1, 1); actx:fillRect(cx + 1, cy, 1, 1); actx:fillRect(cx - 1, cy + 1, 3, 1); actx:fillRect(cx, cy + 2, 1, 1)
    end
end
-- 召唤门
D.portal = function(a, k, x, y)
    local al = alphaOf(a, k)
    local r = (a.r or 9) * (0.3 + 0.7 * ease(min(1, k * 2.5)))
    actx.globalAlpha = al * 0.5; disk(x, y + 6, r, 0.4, '#120d22')
    actx.globalAlpha = al; ring(x, y + 6, r, 0.4, a.col, true, floor(G.time * 14))
    for i = 0, 3 do
        local px = x + (i - 1.5) * r * 0.5
        local h = (6 + (i % 2) * 4) * (1 - k)
        actx.globalAlpha = al * 0.7; line(px, y + 6, px, y + 6 - h, a.col2 or a.col)
    end
end
-- 天上的日 / 月
D.sky = function(a, k, x, y)
    local al = alphaOf(a, k)
    local r = a.r or 8
    if a.moon then
        actx.globalAlpha = al * 0.25; disk(x, y, r + 4, 1, a.col)
        actx.globalAlpha = al; disk(x, y, r, 1, a.col)
        actx.globalAlpha = al; disk(x + 4, y - 2, r - 1, 1, '#1b1530')
        actx.globalAlpha = al * 0.35
        for i = 0, 4 do local bx = x - 40 + i * 20; line(bx, y + r, bx - 10, FIELD_H - 6, a.col2 or a.col) end
    else
        actx.globalAlpha = al * 0.25; disk(x, y, r + 5, 1, a.col)
        actx.globalAlpha = al; disk(x, y, r, 1, a.col); disk(x - 1, y - 1, r - 3, 1, a.col2 or '#ffffff')
        for i = 0, 11 do
            local an = i / 12 * TAU + G.time * 1.5
            local r0, r1 = r + 3, r + ((i % 2 == 0) and 9 or 6)
            line(x + cos(an) * r0, y + sin(an) * r0, x + cos(an) * r1, y + sin(an) * r1, a.col)
        end
    end
end
-- 时钟（时间静止）
D.clock = function(a, k, x, y)
    local al = alphaOf(a, k)
    local r = a.r or 30
    actx.globalAlpha = al * 0.15; disk(x, y, r, 0.6, a.col)
    actx.globalAlpha = al; ring(x, y, r, 0.6, a.col); ring(x, y, r - 3, 0.6, a.col2 or a.col, true, 0)
    for i = 0, 11 do
        local an = i / 12 * TAU
        line(x + cos(an) * (r - 6), y + sin(an) * (r - 6) * 0.6, x + cos(an) * (r - 2), y + sin(an) * (r - 2) * 0.6, '#ffffff')
    end
    local an = -PI / 2 + min(1, k * 1.4) * TAU * 1.5
    line(x, y, x + cos(an) * (r - 6), y + sin(an) * (r - 6) * 0.6, '#ffffff')
    line(x, y, x + cos(an * 0.2 - PI / 2) * (r - 12), y + sin(an * 0.2 - PI / 2) * (r - 12) * 0.6, a.col)
end
-- 残影
D.ghost = function(a, k, x, y)
    actx.globalAlpha = (1 - k) * (a.alpha or 0.5)
    drawImg(a.img, x, y)
end
-- 根须（缠绕 / 根植）
D.roots = function(a, k, x, y)
    actx.globalAlpha = alphaOf(a, k)
    local g = ease(min(1, k * 3))
    for i = -2, 2 do
        local h = round((4 + abs(i) % 2 * 2) * g)
        local bx = round(x + i * 3)
        actx.fillStyle = a.col; actx:fillRect(bx, round(y + 7 - h), 1, h)
        if h > 2 then dot(bx + ((i < 0) and -1 or 1), y + 7 - h + 1, a.col2 or a.col) end
    end
end
-- 眩晕星星
D.stunstars = function(a, k, x, y)
    actx.globalAlpha = alphaOf(a, k)
    for i = 0, 2 do
        local an = G.time * 7 + i * TAU / 3
        local cx, cy = round(x + cos(an) * 6), round(y - 17 + sin(an) * 2)
        actx.fillStyle = '#ffe14a'; actx:fillRect(cx - 1, cy, 3, 1); actx:fillRect(cx, cy - 1, 1, 3)
    end
end
-- 吸收经验条（老虎机吸收时显示获得的经验和到 ★★★ 转职的进度）
D.expbar = function(a, k, x, y)
    local u = a.unit
    if u then local s = findSlot(u); if s then local p = slotPos(s); x, y = p.x, p.y end end
    local al = alphaOf(a, k)
    local W = 26
    local bx, by = round(x - W / 2), round(y - 27)
    local fill = min(1, k / 0.35)
    local cur = a.from + (a.to - a.from) * ease(fill)
    actx.globalAlpha = al
    actx.fillStyle = PAL.k; actx:fillRect(bx - 1, by - 1, W + 2, 5)
    actx.fillStyle = '#2d2245'; actx:fillRect(bx, by, W, 3)
    actx.fillStyle = '#8fe07a'; actx:fillRect(bx, by, round(W * a.from / a.max), 3)
    actx.fillStyle = (floor(G.time * 12) % 2 == 0) and '#ffffff' or '#ffe680'
    local x0 = bx + round(W * a.from / a.max)
    actx:fillRect(x0, by, max(0, round(W * cur / a.max) - round(W * a.from / a.max)), 3)
    for _, m in ipairs(a.marks) do -- ★★ 的门槛刻度
        actx.fillStyle = PAL.k; actx:fillRect(bx + round(W * m / a.max), by, 1, 3)
    end
    pixText(actx, '+' .. S(a.gain), x, by - 8, '#8fe07a')
    if a.label then pixText(actx, a.label, x, by + 5, a.labelCol or '#ffe680') end
end

-- 每帧：按图层画出所有动画（0 = 地面层，画在单位下面；1 = 上层）
function drawAnims(layer)
    local L = FX.anims
    if #L == 0 then return end
    local prevA = actx.globalAlpha
    for i = 1, #L do
        local a = L[i]
        if a.layer == layer and a.t >= a.delay then
            local k = clamp((a.t - a.delay) / a.dur, 0, 0.999)
            local x, y = posOf(a)
            local f = D[a.kind]
            if f and x then f(a, k, x, y) end
        end
    end
    actx.globalAlpha = prevA
end

-- ---------------------------------------------------------------------------
-- 组合特效（技能的招牌动画由这些拼起来）
-- ---------------------------------------------------------------------------
local P = {}
FX.P = P
function P.rune(x, y, r, col, col2, enemy, dur) add({ kind = 'rune', x = x, y = y + 6, r = r, col = col, col2 = col2, enemy = enemy, dur = dur or 0.7, layer = 0 }) end
function P.ring(x, y, r0, r1, col, o)
    o = o or {}
    add({ kind = 'ring', x = x, y = y + (o.oy or 6), r0 = r0, r1 = r1, ry = o.ry or 0.55, col = col, col2 = o.col2, thick = o.thick or 2, dash = o.dash, dur = o.dur or 0.45, delay = o.delay, layer = o.layer or 0, alpha = o.alpha })
end
function P.disk(x, y, r0, r1, col, dur, alpha, ry) add({ kind = 'disk', x = x, y = y + 6, r0 = r0, r1 = r1, col = col, dur = dur or 0.5, alpha = alpha or 0.35, ry = ry, layer = 0 }) end
function P.pillar(x, y, col, col2, h, w, dur, delay) add({ kind = 'pillar', x = x, y = y + 6, col = col, col2 = col2, h = h or 44, w = w or 7, dur = dur or 0.55, delay = delay, layer = 1 }) end
function P.star(x, y, col, col2, s, dur, delay) add({ kind = 'star', x = x, y = y, col = col, col2 = col2, s = s or 6, dur = dur or 0.3, delay = delay, layer = 1 }) end
function P.xslash(x, y, col, col2, s) add({ kind = 'xslash', x = x, y = y - 4, col = col, col2 = col2, s = s or 7, dur = 0.32, layer = 1 }) end
function P.rays(x, y, col, col2, r, n, dur) add({ kind = 'rays', x = x, y = y, col = col, col2 = col2, r = r or 14, n = n or 8, rot = js.random() * 0.5, dur = dur or 0.32, layer = 1 }) end
function P.beam(x1, y1, x2, y2, col, w, dur) add({ kind = 'beam', x = x1, y = y1, x1 = x1, y1 = y1, x2 = x2, y2 = y2, col = col, w = w or 3, dur = dur or 0.3, layer = 1 }) end
function P.bolt(x, y, col, col2, delay) add({ kind = 'skybolt', x = x, y = y, y0 = 0, col = col, col2 = col2, dur = 0.32, delay = delay, layer = 1 }) end
function P.vortex(x, y, r, col, col2, dir, inward, dur) add({ kind = 'vortex', x = x, y = y, r = r, col = col, col2 = col2, dir = dir, inward = inward, dur = dur or 0.5, layer = 1 }) end
function P.arc(x, y, f, r, col, col2, dur, a0, a1) add({ kind = 'arc', x = x, y = y, f = f, r = r, col = col, col2 = col2, dur = dur or 0.3, a0 = a0, a1 = a1, layer = 1 }) end
function P.portal(x, y, col, col2, r) add({ kind = 'portal', x = x, y = y, col = col, col2 = col2, r = r or 9, dur = 0.7, layer = 0 }) end
function P.wave(x0, x1, col, col2, dur) add({ kind = 'wave', x = 0, y = 0, x0 = x0, x1 = x1, dir = (x1 > x0) and 1 or -1, col = col, col2 = col2, dur = dur or 0.7, layer = 1 }) end
function P.sky(x, y, col, col2, moon, r, dur) add({ kind = 'sky', x = x, y = y, col = col, col2 = col2, moon = moon, r = r or 8, dur = dur or 1.1, layer = 1 }) end
function P.clock(x, y, col, col2, r) add({ kind = 'clock', x = x, y = y, col = col, col2 = col2, r = r or 34, dur = 1.0, layer = 1 }) end
-- 跟随单位的
function P.shield(ent, col, r) add({ kind = 'shield', ent = ent, col = col, r = r or (ent.big and 14 or 9), dur = 0.8, layer = 1 }) end
function P.arrows(ent, col, col2, dir) add({ kind = 'arrows', ent = ent, col = col, col2 = col2, dir = dir or 1, dur = 0.8, layer = 1 }) end
function P.cross(ent, col) add({ kind = 'cross', ent = ent, col = col, dur = 0.85, layer = 1 }) end
function P.hearts(ent, col) add({ kind = 'hearts', ent = ent, col = col or '#ff6ad5', dur = 0.9, layer = 1 }) end
function P.roots(ent, col, col2) add({ kind = 'roots', ent = ent, col = col or '#2f7a34', col2 = col2 or '#7fd36a', dur = 0.9, layer = 1 }) end
function P.stun(ent) add({ kind = 'stunstars', ent = ent, dur = 0.7, layer = 1 }) end
function P.ghosts(img, x0, y0, x1, y1, n)
    n = n or 3
    for i = 1, n do
        local f = i / (n + 1)
        add({ kind = 'ghost', img = img, x = x0 + (x1 - x0) * f, y = y0 + (y1 - y0) * f, dur = 0.25 + f * 0.2, alpha = 0.25 + f * 0.35, layer = 1 })
    end
end
-- 吸入式聚能（粒子往中心收）
function P.converge(x, y, col, n, r)
    n = n or 14; r = r or 16
    for i = 0, n - 1 do
        local an = js.random() * TAU
        local d = r * (0.7 + js.random() * 0.5)
        local life = 0.22 + js.random() * 0.1
        FX.parts:push({ x = x + cos(an) * d, y = y + sin(an) * d * 0.7, vx = -cos(an) * d / life, vy = -sin(an) * d * 0.7 / life, g = 0, life = life, max = life, color = (i % 3 == 0) and '#ffffff' or col, size = 1 })
    end
end
-- 上升火花
function P.sparks(x, y, col, n, spread)
    for i = 1, n or 10 do
        local px = x + rand(-(spread or 6), spread or 6)
        FX.parts:push({ x = px, y = y + rand(-3, 6), vx = rand(-4, 4), vy = -rand(20, 45), g = 10, life = rand(0.35, 0.7), max = 0.7, color = (i % 3 == 0) and '#ffffff' or col, size = (i % 5 == 0) and 2 or 1 })
    end
end

-- ---------------------------------------------------------------------------
-- 技能主题：颜色 + 招牌特效
-- sig 函数参数：(B, e 施法者, t 目标, c 上下文{ col, col2, ox, oy 施法前位置, tx, ty 目标位置, foes, allies })
-- ---------------------------------------------------------------------------
local SIG = {}
local function center(list)
    local x, y, n = 0, 0, 0
    for o in of(list) do x = x + o.x; y = y + o.y; n = n + 1 end
    if n == 0 then return 128, 80 end
    return x / n, y / n
end
-- 常用组合
local function nova(R, rays) return function(B, e, t, c)
    P.ring(e.x, e.y, 4, R, c.col, { col2 = c.col2, thick = 3 })
    P.ring(e.x, e.y, 2, R * 0.7, c.col2 or c.col, { delay = 0.12, thick = 1, dash = true })
    P.disk(e.x, e.y, R * 0.4, R, c.col, 0.45, 0.25)
    if rays ~= false then P.rays(e.x, e.y - 4, c.col, c.col2, R * 0.6, 10) end
end end
local function blast(R, at) return function(B, e, t, c)
    local x, y = c.tx, c.ty
    P.ring(x, y, 3, R, c.col, { col2 = c.col2, thick = 3, delay = at })
    P.disk(x, y, R * 0.3, R, c.col, 0.4, 0.3)
    P.star(x, y - 3, c.col, c.col2, 7, 0.32, at)
end end
local function slash(big) return function(B, e, t, c)
    P.arc(e.x + e.face * 2, e.y - 4, e.face, big and 16 or 12, c.col, c.col2, 0.3)
    if t then P.xslash(t.x, t.y, c.col, c.col2, big and 9 or 7); P.star(t.x, t.y - 4, '#ffffff', c.col, big and 8 or 6) end
end end
local function shot(B, e, t, c) -- 射击类：枪口闪光 + 指向目标的瞄准线
    local mx, my = e.x + e.face * 6, e.y - 4
    P.star(mx, my, c.col, c.col2, 6)
    P.rays(mx, my, c.col, c.col2, 9, 6, 0.22)
    if t then P.beam(mx, my, t.x, t.y - 3, c.col, 1, 0.18) end
end
local function zone(R, onSelf) return function(B, e, t, c)
    local x, y = onSelf and e.x or c.tx, onSelf and e.y or c.ty
    add({ kind = 'rune', x = x, y = y + 6, r = R, col = c.col, col2 = c.col2, dur = 1.0, layer = 0 })
    P.ring(x, y, R * 0.3, R, c.col, { thick = 2, dur = 0.6 })
    P.converge(x, y - 4, c.col, 12, R)
end end
local function heal(B, e, t, c)
    P.pillar(e.x, e.y, c.col, c.col2, 46, 9, 0.6)
    P.ring(e.x, e.y, 4, 30, c.col, { thick = 2, dash = true, dur = 0.6 })
    P.sparks(e.x, e.y, c.col, 10)
end
local function roar(R) return function(B, e, t, c)
    for i = 0, 2 do P.ring(e.x, e.y - 6, 4, R, (i == 1) and (c.col2 or c.col) or c.col, { oy = 0, ry = 0.75, thick = 1, delay = i * 0.12, dur = 0.5, layer = 1 }) end
    P.ring(e.x, e.y, 6, R, c.col, { thick = 2, dur = 0.5 })
end end
local function dash(B, e, t, c)
    if t then P.xslash(t.x, t.y, c.col, c.col2, 8); P.ring(t.x, t.y, 2, 14, c.col, { thick = 2, dur = 0.3 }) end
end
local function quake(R) return function(B, e, t, c)
    FX.quake(e.x, e.y)
    P.ring(e.x, e.y, 4, R, c.col, { col2 = c.col2, thick = 3, dur = 0.5 })
    P.ring(e.x, e.y, 4, R * 0.65, c.col2 or c.col, { thick = 1, delay = 0.1, dur = 0.45 })
    P.disk(e.x, e.y, 6, R * 0.8, '#3a2a1a', 0.6, 0.4)
end end
local function skyAll(col2) return function(B, e, t, c)
    local i = 0
    for o in of(c.foes) do if i < 8 then P.bolt(o.x, o.y, c.col, col2 or c.col2, i * 0.05); i = i + 1 end end
end end
local function summon(B, e, t, c) P.rune(e.x, e.y, 16, c.col, c.col2, e.side == 'e', 0.8); P.converge(e.x, e.y - 4, c.col, 16, 18) end
local function curseAt(R) return function(B, e, t, c)
    P.disk(c.tx, c.ty, 4, R, '#2a1a3a', 0.7, 0.5)
    P.ring(c.tx, c.ty, R, 4, c.col, { thick = 2, dur = 0.5 }) -- 向内收缩
    P.vortex(c.tx, c.ty - 2, R * 0.6, c.col, c.col2, -1, true, 0.5)
end end
local function both(f, g) return function(...) f(...); g(...) end end

-- —— 基础技能 ——
SIG.bash = { '#ffd84a', '#ffffff', both(slash(false), function(B, e, t, c) if t then P.ring(t.x, t.y, 2, 12, '#ffd84a', { thick = 2, dur = 0.3 }) end end) }
SIG.triple = { '#c99a5b', '#ffe680', shot }
SIG.arcane = { '#6ef0ff', '#c06bff', both(shot, blast(24, 0.25)) }
SIG.pounce = { '#ffa53a', '#ffffff', dash }
SIG.roar = { '#c08a5a', '#ffd27a', roar(34) }
SIG.spore = { '#9be36b', '#4fbf4a', both(blast(24), function(B, e, t, c) P.vortex(c.tx, c.ty - 2, 14, '#7fd36a', '#c4f05a', 1, false, 0.6) end) }
SIG.sunburst = { '#ffe14a', '#fff6b0', both(heal, function(B, e, t, c) P.sky(e.x, 18, '#ffe14a', '#ffffff', false, 6, 0.9) end) }
SIG.rootguard = { '#6fbf5a', '#bff0c8', both(roar(26), function(B, e, t, c) P.roots(e, '#4a2f1b', '#6fbf5a') end) }
SIG.thunderstorm = { '#ffe14a', '#78a8f2', both(shot, function(B, e, t, c) P.bolt(c.tx, c.ty, '#78a8f2', '#ffffff'); zone(22)(B, e, t, c) end) }
SIG.overload = { '#ffb04a', '#ffe14a', both(nova(26, true), function(B, e, t, c) P.pillar(e.x, e.y, '#ff8a2a', '#ffe14a', 30, 7, 0.45) end) }
-- —— 战士 ——
SIG.whirlwind = { '#ff9a7a', '#ffffff', both(nova(24), function(B, e, t, c) P.vortex(e.x, e.y - 3, 22, '#ff9a7a', '#ffffff', 1, false, 0.45) end) }
SIG.aegis = { '#fff3b0', '#ffe14a', both(roar(30), function(B, e, t, c) P.pillar(e.x, e.y, '#fff3b0', '#ffffff', 40, 9, 0.6) end) }
SIG.warcry = { '#ff6a4a', '#ffb04a', roar(40) }
SIG.vengeance = { '#c06bff', '#ff4a3a', slash(true) }
SIG.shockwave = { '#6ef0ff', '#bff4ff', function(B, e, t, c)
    for i = 0, 2 do P.arc(e.x + e.face * (6 + i * 7), e.y - 3, e.face, 10 + i * 4, '#6ef0ff', '#bff4ff', 0.35, -1.2, 1.2) end
    P.ring(e.x + e.face * 14, e.y, 4, 26, '#6ef0ff', { thick = 2, dur = 0.4 })
end }
SIG.behead = { '#ff3434', '#ffffff', both(slash(true), function(B, e, t, c) if t then P.beam(t.x - 14, t.y - 4, t.x + 14, t.y - 4, '#ff3434', 3, 0.3) end end) }
SIG.giant = { '#ffa53a', '#ffd27a', function(B, e, t, c)
    P.pillar(e.x, e.y, '#ffa53a', '#ffd27a', 70, 18, 0.7); P.ring(e.x, e.y, 6, 34, '#ffa53a', { thick = 3, dur = 0.6 }); P.sparks(e.x, e.y, '#ffd27a', 16, 10)
end }
SIG.titanstomp = SIG.giant
-- —— 射手 ——
SIG.snipe = { '#ffe680', '#ffffff', function(B, e, t, c)
    local tgt = c.foes:sort(function(a, b) return b.hp - a.hp end)[0] or t
    shot(B, e, tgt, c)
    if tgt then add({ kind = 'ring', ent = tgt, dy = -3, r0 = 12, r1 = 3, ry = 1, col = '#ff4a3a', thick = 1, dur = 0.4, layer = 1 }) end -- 准星
end }
SIG.volley = { '#c99a5b', '#ffe680', both(shot, function(B, e, t, c) P.ring(c.tx, c.ty, 16, 16, '#ffe680', { thick = 1, dash = true, dur = 0.9 }) end) }
SIG.pierce = { '#9ff6ff', '#ffffff', function(B, e, t, c)
    shot(B, e, t, c)
    if t then local dx, dy = t.x - e.x, t.y - e.y; local d = max(1, hypot(dx, dy)); P.beam(e.x + e.face * 6, e.y - 4, e.x + dx / d * 260, e.y - 4 + dy / d * 260, '#9ff6ff', 3, 0.25) end
end }
SIG.venomburst = { '#9be36b', '#4fbf4a', both(shot, blast(20, 0.25)) }
SIG.hunt = { '#ff8a2a', '#ffe680', function(B, e, t, c)
    local tgt = c.foes:slice():sort(function(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end)[0] or t
    shot(B, e, tgt, c)
    if tgt then add({ kind = 'ring', ent = tgt, dy = -3, r0 = 12, r1 = 3, ry = 1, col = '#ff8a2a', thick = 1, dur = 0.4, layer = 1 }) end
end }
SIG.barrage = { '#c99a5b', '#ffe680', both(shot, function(B, e, t, c) P.rays(e.x + e.face * 6, e.y - 4, '#ffe680', '#ffffff', 14, 12, 0.4) end) }
SIG.turret = { '#ffb04a', '#ffe14a', summon }
SIG.starfall = { '#ffe680', '#ffffff', function(B, e, t, c)
    P.sky(128, 16, '#ffe680', '#ffffff', false, 5, 0.9)
    for o in of(c.foes) do P.ring(o.x, o.y, 10, 10, '#ffe680', { thick = 1, dash = true, dur = 0.6 }) end
end }
SIG.shadowclone = { '#c06bff', '#8f4bc4', summon }
SIG.wolf = { '#c9cbd6', '#ffffff', summon }
-- —— 法师 ——
SIG.meteor = { '#ff8a2a', '#ffe14a', both(shot, function(B, e, t, c) P.ring(c.tx, c.ty, 22, 22, '#ff5a2a', { thick = 1, dash = true, dur = 0.6 }); P.disk(c.tx, c.ty, 18, 18, '#ff5a2a', 0.6, 0.18) end) }
SIG.stomp = { '#ff5a3a', '#ffb03a', quake(32) }
SIG.raise = { '#c06bff', '#6ef0ff', summon }
SIG.frostnova = { '#bff4ff', '#7fd0ff', both(shot, function(B, e, t, c) P.ring(c.tx, c.ty, 26, 26, '#bff4ff', { thick = 1, dash = true, dur = 0.5 }) end) }
SIG.chain = { '#ffe14a', '#78a8f2', both(shot, function(B, e, t, c) if t then P.star(t.x, t.y - 3, '#ffe14a', '#ffffff', 8) end end) }
SIG.heal = { '#fff3b0', '#ffffff', both(heal, function(B, e, t, c) P.sky(e.x, 14, '#fff3b0', '#ffffff', false, 5, 0.8) end) }
SIG.hex = { '#9be36b', '#4a2a4a', curseAt(30) }
SIG.timestop = { '#bff4ff', '#6ef0ff', function(B, e, t, c) P.clock(160, 80, '#bff4ff', '#6ef0ff', 40); P.rune(e.x, e.y, 18, '#bff4ff', '#6ef0ff') end }
SIG.blackhole = { '#8f4bc4', '#e0b0ff', both(shot, function(B, e, t, c) P.vortex(c.tx, c.ty, 36, '#8f4bc4', '#e0b0ff', -1, true, 0.8) end) }
SIG.sanctuary = { '#fff3b0', '#ffffff', function(B, e, t, c)
    P.sky(e.x, 14, '#fff3b0', '#ffffff', false, 7, 1.0)
    P.pillar(e.x, e.y, '#fff3b0', '#ffffff', 70, 14, 0.8)
    P.ring(e.x, e.y, 6, 48, '#fff3b0', { thick = 3, dur = 0.7 })
end }
SIG.elements = { '#ff8a2a', '#6ef0ff', function(B, e, t, c)
    local k = ((e.elemIdx or 1) - 1) % 3 -- castSkill 之后 elemIdx 已经 +1
    local cols = { [0] = { '#ff8a2a', '#ffe14a' }, { '#bff4ff', '#7fd0ff' }, { '#ffe14a', '#78a8f2' } }
    c.col, c.col2 = cols[k][1], cols[k][2]
    shot(B, e, t, c); P.rune(e.x, e.y, 16, c.col, c.col2)
end }
SIG.legion = { '#6ef0ff', '#c06bff', both(summon, roar(30)) }
-- —— 猛虎 ——
SIG.rend = { '#ff4a3a', '#ffffff', function(B, e, t, c)
    if t then for i = 0, 2 do add({ kind = 'xslash', x = t.x + (i - 1) * 3, y = t.y - 4, col = '#ff4a3a', col2 = '#ffffff', s = 6, dur = 0.28, delay = i * 0.08, layer = 1 }) end end
end }
SIG.ambush = { '#ffffff', '#c06bff', dash }
SIG.tigerroar = { '#ffa53a', '#ffd27a', roar(40) }
SIG.shadowstrike = { '#c06bff', '#ffffff', dash }
SIG.drinkblood = { '#ff4a3a', '#7a1f2b', both(slash(false), function(B, e, t, c) if t then P.beam(t.x, t.y - 4, e.x, e.y - 4, '#d8433a', 2, 0.35) end end) }
SIG.huntchain = { '#ff8a2a', '#ffffff', dash }
SIG.clawstorm = { '#ff7a3a', '#ffb04a', both(nova(26), function(B, e, t, c) for i = 0, 3 do add({ kind = 'xslash', x = e.x + rand(-12, 12), y = e.y - 4 + rand(-6, 6), col = '#ff7a3a', col2 = '#ffffff', s = 5, dur = 0.25, delay = i * 0.06, layer = 1 }) end end) }
SIG.bloodrush = { '#ff3434', '#fff2ea', both(dash, function(B, e, t, c) P.ring(e.x, e.y, 4, 30, '#ff3434', { thick = 2, dur = 0.5 }) end) }
-- —— 巨熊 ——
SIG.quake = { '#c08a5a', '#ffd27a', quake(28) }
SIG.hibernate = { '#6a8ad8', '#bcd0ff', function(B, e, t, c) P.shield(e, '#bcd0ff', e.big and 16 or 12); P.ring(e.x, e.y, 4, 22, '#6a8ad8', { thick = 2, dur = 0.6 }) end }
SIG.frostroar = { '#bff4ff', '#e4f4ff', both(roar(56), function(B, e, t, c) P.disk(e.x, e.y, 10, 50, '#bff4ff', 0.6, 0.25) end) }
SIG.bearhug = { '#c9955a', '#ffd84a', dash }
SIG.frenzy = { '#ff6a4a', '#ff4a3a', function(B, e, t, c) P.pillar(e.x, e.y, '#ff4a3a', '#ff8a6a', 30, 8, 0.5); P.vortex(e.x, e.y - 4, 12, '#ff4a3a', '#ffffff', 1, false, 0.5) end }
SIG.ironwall = { '#8d9ab2', '#c9d2e0', both(roar(36), function(B, e, t, c) P.shield(e, '#c9d2e0', 13) end) }
SIG.bulwark = { '#7fb0e0', '#ffffff', both(roar(34), function(B, e, t, c) P.shield(e, '#8ab4dc', 14) end) }
SIG.landslide = { '#a89878', '#5a4a38', function(B, e, t, c) P.ring(c.tx, c.ty, 22, 22, '#a89878', { thick = 1, dash = true, dur = 0.7 }); P.disk(c.tx, c.ty, 16, 16, '#3a2a1a', 0.7, 0.3); FX.quake(e.x, e.y) end }
SIG.throatrip = { '#d8433a', '#ffffff', slash(true) }
SIG.doomstomp = { '#ff3434', '#ff8e6a', both(quake(50), function(B, e, t, c) P.pillar(e.x, e.y, '#ff3434', '#ff8e6a', 40, 14, 0.5) end) }
-- —— 食人花 ——
SIG.entangle = { '#2f7a34', '#4fbf4a', both(blast(24), function(B, e, t, c) P.vortex(c.tx, c.ty, 18, '#2f7a34', '#7fd36a', 1, true, 0.6) end) }
SIG.virulence = { '#e6ff6a', '#9be36b', function(B, e, t, c) for o in of(c.foes) do if o.poison or o == t then P.star(o.x, o.y - 4, '#e6ff6a', '#9be36b', 7) end end end }
SIG.seedling = { '#9be36b', '#c4405a', summon }
SIG.plague = { '#9a5ae0', '#9be36b', both(nova(40), function(B, e, t, c) for o in of(c.foes) do P.disk(o.x, o.y, 3, 10, '#9a5ae0', 0.7, 0.3) end end) }
SIG.devour = { '#ff4a3a', '#9be36b', function(B, e, t, c)
    local x, y = c.tx, c.ty
    P.arc(x - 2, y - 4, 1, 10, '#9be36b', '#ff4a3a', 0.3, -2.4, -0.2); P.arc(x + 2, y - 4, -1, 10, '#9be36b', '#ff4a3a', 0.3, -2.4, -0.2)
    P.star(x, y - 4, '#ff4a3a', '#9be36b', 8)
end }
SIG.venomrush = { '#9be36b', '#4fbf4a', function(B, e, t, c) P.pillar(e.x, e.y, '#4fbf4a', '#9be36b', 28, 7, 0.45); P.vortex(e.x, e.y - 4, 10, '#4fbf4a', '#9be36b', 1, false, 0.45) end }
SIG.thornfield = { '#ff6a8a', '#2f7a34', both(nova(38, false), function(B, e, t, c) FX.thorns(e.x + 8, e.y); FX.thorns(e.x - 8, e.y + 3) end) }
SIG.poisoncloud = { '#c06bff', '#9be36b', both(shot, blast(22, 0)) }
SIG.infest = { '#b0e05a', '#9be36b', function(B, e, t, c)
    P.star(c.tx, c.ty - 4, '#b0e05a', '#ffffff', 8)
    for o in of(c.foes) do if o ~= t and hypot(o.x - c.tx, o.y - c.ty) <= 30 then P.beam(c.tx, c.ty - 4, o.x, o.y - 4, '#b0e05a', 1, 0.35) end end
end }
-- —— 向日葵 ——
SIG.moonlight = { '#e4f2ff', '#78a0ff', function(B, e, t, c) P.sky(128, 18, '#e4f2ff', '#78a0ff', true, 9, 1.2) end }
SIG.bloom = { '#ff8ab8', '#ffd0e6', both(heal, function(B, e, t, c) P.sparks(e.x, e.y, '#ff8ab8', 14, 12) end) }
SIG.solarflare = { '#ffc850', '#ffffff', function(B, e, t, c)
    P.sky(128, 16, '#ffc850', '#ffffff', false, 9, 1.0)
    local i = 0
    for o in of(c.foes) do if i < 10 then P.beam(128, 22, o.x, o.y - 3, '#ffc850', 1, 0.35); i = i + 1 end end
end }
SIG.purify = { '#ffffff', '#fff3b0', both(heal, function(B, e, t, c) P.rays(e.x, e.y - 6, '#ffffff', '#fff3b0', 22, 12, 0.4) end) }
SIG.sunshield = { '#ffb04a', '#ffe14a', both(heal, function(B, e, t, c) P.sky(e.x, 16, '#ffb04a', '#ffe14a', false, 6, 0.9) end) }
SIG.sunward = { '#9be36b', '#fff6b0', heal }
SIG.cleanse = { '#dcf0ff', '#ffffff', both(heal, function(B, e, t, c) P.rays(e.x, e.y - 6, '#ffffff', '#dcf0ff', 24, 14, 0.45) end) }
-- —— 超凡 ——
SIG.crimsonmoon = { '#ff3434', '#fff2ea', function(B, e, t, c)
    P.arc(e.x + e.face * 6, e.y - 6, e.face, 30, '#ff3434', '#fff2ea', 0.38, -1.5, 1.5)
    P.arc(e.x + e.face * 10, e.y - 6, e.face, 22, '#a8102a', '#ff8e6a', 0.38, -1.4, 1.4)
    P.sky(e.x + e.face * 40, 16, '#ff3434', '#ff8e6a', true, 7, 0.8)
end }
SIG.bloodarrow = { '#ff3434', '#fff2ea', function(B, e, t, c)
    shot(B, e, t, c); P.rune(e.x, e.y, 18, '#ff3434', '#ff8e6a')
    if t then local dx, dy = t.x - e.x, t.y - e.y; local d = max(1, hypot(dx, dy)); P.beam(e.x, e.y - 4, e.x + dx / d * 260, e.y - 4 + dy / d * 260, '#ff3434', 5, 0.3) end
end }
SIG.bloodmoon = { '#ff3434', '#a8102a', function(B, e, t, c) for o in of(c.foes) do P.ring(o.x, o.y, 10, 10, '#ff3434', { thick = 1, dash = true, dur = 0.7 }) end end }
SIG.bloodthorn = { '#ff3434', '#4c1b2f', function(B, e, t, c) P.ring(e.x, e.y, 6, 60, '#ff3434', { thick = 2, dur = 0.6 }); for o in of(c.foes) do P.disk(o.x, o.y, 2, 10, '#a8102a', 0.6, 0.4) end end }
SIG.rebirth = { '#ff8e6a', '#ffe14a', function(B, e, t, c)
    P.sky(e.x, 14, '#ff5a2a', '#ffe14a', false, 9, 1.1); P.pillar(e.x, e.y, '#ff5a2a', '#ffe14a', 80, 18, 0.8)
    P.ring(e.x, e.y, 6, 60, '#ff8e6a', { thick = 3, dur = 0.7 })
end }
SIG.bloodgrove = { '#ff3434', '#7a1f2b', function(B, e, t, c) P.ring(e.x, e.y, 6, 60, '#ff3434', { thick = 2, dur = 0.6 }) end }
SIG.crimsonstorm = { '#ff3434', '#ffe14a', function(B, e, t, c) P.sky(128, 12, '#7a1f2b', '#ff3434', true, 10, 0.9) end }
SIG.redprotocol = { '#ff3434', '#ffb04a', both(summon, nova(30)) }
-- —— 古树卫士 ——
SIG.barkskin = { '#9b6a3c', '#c9955a', function(B, e, t, c) P.shield(e, '#c9955a', 12); P.ring(e.x, e.y, 4, 18, '#9b6a3c', { thick = 2 }) end }
SIG.brambleburst = { '#4fbf4a', '#ff6a8a', nova(28) }
SIG.mossheal = { '#9be36b', '#c4f0a0', heal }
SIG.timberslam = { '#c9b08a', '#8a6a4a', function(B, e, t, c)
    P.arc(e.x + e.face * 4, e.y - 6, e.face, 20, '#c9b08a', '#ffe680', 0.35, -2.4, 0.9)
    P.ring(e.x + e.face * 14, e.y, 4, 22, '#c9b08a', { thick = 3, dur = 0.4, delay = 0.1 })
end }
SIG.rootnet = { '#2f7a34', '#4fbf4a', both(nova(50, false), function(B, e, t, c) P.vortex(e.x, e.y, 40, '#2f7a34', '#7fd36a', 1, true, 0.6) end) }
SIG.lifegrove = { '#bff0c8', '#6fbf5a', zone(44, true) }
SIG.uproot = { '#ffd84a', '#c9b08a', quake(36) }
-- —— 雷鹰 ——
SIG.galestrike = { '#9ff6ff', '#ffe14a', both(shot, function(B, e, t, c) P.vortex(e.x, e.y - 6, 10, '#9ff6ff', '#ffffff', 1, false, 0.35) end) }
SIG.divebomb = { '#ffe680', '#ffffff', function(B, e, t, c)
    local tgt = c.foes:filter(function(o) return not o.immune end):sort(function(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end)[0] or t
    shot(B, e, tgt, c)
    if tgt then add({ kind = 'ring', ent = tgt, dy = -3, r0 = 12, r1 = 3, ry = 1, col = '#ffe14a', thick = 1, dur = 0.4, layer = 1 }) end
end }
SIG.tailwind = { '#bff4ff', '#ffffff', both(roar(36), function(B, e, t, c) P.vortex(e.x, e.y - 4, 16, '#bff4ff', '#ffffff', 1, false, 0.5) end) }
SIG.ballstorm = { '#78a8f2', '#ffffff', both(shot, function(B, e, t, c) P.rune(e.x, e.y, 14, '#78a8f2', '#ffe14a') end) }
SIG.featherstorm = { '#ff8a7a', '#ffffff', function(B, e, t, c) P.vortex(e.x, e.y - 6, 16, '#ff8a7a', '#ffffff', 1, false, 0.5) end }
SIG.skyfury = { '#fff6b0', '#ffe14a', function(B, e, t, c) P.sky(128, 12, '#4a4a6a', '#ffe14a', true, 10, 0.8) end }
SIG.flameraid = { '#ff8a2a', '#ffe14a', function(B, e, t, c)
    if t then local dx, dy = t.x - e.x, t.y - e.y; local d = max(1, hypot(dx, dy)); P.beam(e.x, e.y - 4, e.x + dx / d * 260, e.y - 4 + dy / d * 260, '#ff8a2a', 4, 0.35) end
    shot(B, e, t, c)
end }
-- —— 发条机兵 ——
SIG.gearshot = { '#e2b33c', '#ffe27a', both(shot, function(B, e, t, c) P.rays(e.x + e.face * 6, e.y - 4, '#e2b33c', '#ffe27a', 12, 10, 0.3) end) }
SIG.steamburst = { '#e6edf7', '#ffffff', both(nova(30), function(B, e, t, c) P.disk(e.x, e.y, 8, 30, '#ffffff', 0.6, 0.35) end) }
SIG.repair = { '#8fe07a', '#ffe14a', function(B, e, t, c) P.rune(e.x, e.y, 14, '#8fe07a', '#ffe14a'); P.sparks(e.x, e.y, '#ffe14a', 8) end }
SIG.artillery = { '#ff8a2a', '#3a2d52', both(shot, function(B, e, t, c) P.ring(c.tx, c.ty, 20, 20, '#ff8a2a', { thick = 1, dash = true, dur = 0.8 }) end) }
SIG.magnetpulse = { '#6ef0ff', '#ffffff', both(curseAt(44), function(B, e, t, c) for o in of(c.foes) do if hypot(o.x - c.tx, o.y - c.ty) <= 50 then P.beam(o.x, o.y - 3, c.tx, c.ty - 3, '#6ef0ff', 1, 0.3) end end end) }
SIG.missilebarrage = { '#ffb04a', '#d8433a', both(shot, function(B, e, t, c) P.rune(e.x, e.y, 16, '#ffb04a', '#d8433a') end) }
SIG.rewind = { '#e0b0ff', '#b48cf0', function(B, e, t, c) P.clock(e.x, e.y - 8, '#e0b0ff', '#b48cf0', 22) end }

-- —— 敌方技能 ——
SIG.rally = { '#ff6a4a', '#ffb04a', roar(44) }
SIG.mend = { '#9be36b', '#4a2a4a', heal }
SIG.lavapool = { '#e2541f', '#ffb03a', shot }
SIG.forge = { '#ffb04a', '#ffe14a', both(roar(34), function(B, e, t, c) P.pillar(e.x, e.y, '#ff8a2a', '#ffb04a', 34, 9, 0.5) end) }
SIG.fissure = { '#ff4a3a', '#ffb03a', function(B, e, t, c) P.ring(e.x, e.y, 4, 20, '#ff4a3a', { thick = 3 }); FX.quake(e.x, e.y) end }
SIG.charm = { '#ff6ad5', '#ffd0f0', function(B, e, t, c) P.rays(e.x, e.y - 6, '#ff6ad5', '#ffd0f0', 16, 10, 0.4) end }
SIG.rift = { '#c06bff', '#ffffff', function(B, e, t, c) P.rune(e.x, e.y, 22, '#c06bff', '#8f4bc4', true, 0.9); P.vortex(e.x, e.y - 8, 18, '#c06bff', '#ffffff', -1, false, 0.6) end }
SIG.plaguecure = { '#9be36b', '#3a2a1a', heal }
SIG.acidspit = { '#9be36b', '#c4f05a', both(shot, blast(20, 0.05)) }
SIG.tidepush = { '#6ec8ff', '#ffffff', function(B, e, t, c) P.wave(AW + 4, -8, '#6ec8ff', '#1f3a6a', 0.75) end }
SIG.tidalwave = { '#6ec8ff', '#1f3a6a', function(B, e, t, c) P.rune(e.x, e.y, 24, '#6ec8ff', '#1f3a6a', true, 1.0); P.vortex(e.x, e.y - 6, 20, '#6ec8ff', '#ffffff', -1, false, 0.7) end }

-- 没在表里的技能：按施法方式给一个通用招牌特效
local DEFAULT_SIG = { '#ffe680', '#ffffff', function(B, e, t, c) nova(24)(B, e, t, c) end }

-- 首领 / 机制技能（FX.skill 直接给名字的那些）
local NAMED = {
    ['亡灵召唤'] = { '#c06bff', '#6ef0ff', function(e) P.rune(e.x, e.y, 24, '#c06bff', '#6ef0ff', true, 1.0); P.ring(e.x, e.y, 6, 40, '#c06bff', { thick = 2, dur = 0.6 }) end },
    ['碎甲'] = { '#c9a6ff', '#ffffff', function(e) P.star(e.x, e.y - 6, '#c9a6ff', '#ffffff', 10); P.rays(e.x, e.y - 6, '#9a6ad8', '#ffffff', 16, 12) end },
    ['闪现'] = { '#ff5a2a', '#ffb03a', function(e) P.ring(e.x, e.y, 2, 14, '#ff5a2a', { thick = 2, dur = 0.3 }); P.star(e.x, e.y - 6, '#ff5a2a', '#ffb03a', 6) end },
    ['熔核护盾'] = { '#ffb03a', '#ffe14a', function(e) P.shield(e, '#ffb03a', 18); P.pillar(e.x, e.y, '#ff8a2a', '#ffe14a', 50, 16, 0.7) end },
    ['核心过载'] = { '#ffffff', '#ffe14a', function(e) P.ring(e.x, e.y, 6, 44, '#ffffff', { thick = 3, dur = 0.6 }); P.rays(e.x, e.y - 8, '#ffe14a', '#ffffff', 26, 14, 0.5) end },
    ['熔核暴走'] = { '#ff4a3a', '#ff8a2a', function(e) P.pillar(e.x, e.y, '#ff4a3a', '#ff8a2a', 50, 16, 0.6); P.ring(e.x, e.y, 6, 40, '#ff4a3a', { thick = 3 }) end },
    ['锁魂钩'] = { '#8f4bc4', '#c06bff', function(e) if e.target then P.beam(e.x, e.y - 4, e.target.x, e.target.y - 4, '#8f4bc4', 2, 0.4) end end },
    ['倒戈'] = { '#ff6ad5', '#ffd0f0', function(e) P.hearts(e, '#ff6ad5'); P.ring(e.x, e.y, 2, 16, '#ff6ad5', { thick = 2, dur = 0.4 }) end },
    ['虚空镜像'] = { '#c06bff', '#ffffff', function(e) P.rune(e.x, e.y, 26, '#c06bff', '#ffffff', true, 1.0); P.vortex(e.x, e.y - 8, 24, '#c06bff', '#ffffff', 1, false, 0.7) end },
    ['虚空坍缩'] = { '#c06bff', '#5a2a7a', function(e) P.vortex(e.x, e.y - 8, 40, '#c06bff', '#5a2a7a', -1, true, 1.2); P.shield(e, '#c06bff', 18) end },
    ['吟唱打断'] = { '#ffffff', '#e0b0ff', function(e) P.star(e.x, e.y - 8, '#ffffff', '#e0b0ff', 14, 0.45); P.ring(e.x, e.y, 6, 40, '#e0b0ff', { thick = 3 }) end },
    ['坍缩'] = { '#5a2a7a', '#c06bff', function(e) P.ring(e.x, e.y, 10, 120, '#c06bff', { thick = 3, dur = 0.8 }); P.ring(e.x, e.y, 6, 80, '#ffffff', { thick = 1, dur = 0.7, delay = 0.1 }) end },
    ['吞噬'] = { '#9be36b', '#4fbf4a', function(e) P.vortex(e.x, e.y - 6, 40, '#9be36b', '#4fbf4a', -1, true, 0.9); P.ring(e.x, e.y, 40, 8, '#9be36b', { thick = 2, dur = 0.6 }) end },
    ['腐疫感染'] = { '#c4f05a', '#78b428', function(e) P.ring(e.x, e.y, 6, 140, '#c4f05a', { thick = 2, dur = 0.9 }); P.sky(128, 18, '#78b428', '#c4f05a', true, 9, 1.0) end },
    ['潜入深海'] = { '#6ec8ff', '#1f3a6a', function(e) P.vortex(e.x, e.y, 26, '#6ec8ff', '#ffffff', -1, true, 0.8); P.ring(e.x, e.y, 30, 4, '#6ec8ff', { thick = 2, dur = 0.6 }) end },
    ['浮出水面'] = { '#6ec8ff', '#ffffff', function(e) P.ring(e.x, e.y, 4, 40, '#6ec8ff', { thick = 3 }); P.sparks(e.x, e.y, '#9fdcff', 16, 14) end },
    ['触手被打断'] = { '#ffe14a', '#6ec8ff', function(e) P.star(e.x, e.y - 8, '#ffe14a', '#ffffff', 12, 0.5); P.ring(e.x, e.y, 4, 40, '#6ec8ff', { thick = 3 }) end },
    ['战魂不灭'] = { '#6ef0ff', '#ffffff', function(e) P.pillar(e.x, e.y, '#6ef0ff', '#ffffff', 50, 12, 0.7) end },
}

-- ---------------------------------------------------------------------------
-- 结算前后对比：逐目标反馈
-- ---------------------------------------------------------------------------
local function snapshot(B)
    local s = {}
    for e in of(B.ents) do
        s[e] = { hp = e.hp, sh = e.shield or 0, ha = e.haste or 0, st = e.stun or 0, dead = e.dead, x = e.x, y = e.y, side = e.side,
            gd = e.guard, po = e.poison and e.poison.n or 0, bu = e.burn, bl = e.bleed, cu = e.curse, sl = e.slow, ch = e.charmed or 0,
            ro = e.root or 0, hot = e.hot, ov = e.overT or 0, inv = e.inv or 0 }
    end
    return s
end
local function debuffed(s) return s.st > 0 or s.po > 0 or s.bu or s.bl or s.cu or s.sl end
local function diffFx(B, caster, before, c)
    local hits, heals, n = 0, 0, 0
    for e in of(B.ents) do
        local s = before[e]
        if not s then
            if not e.dead then P.portal(e.x, e.y, c.col, c.col2); P.sparks(e.x, e.y, c.col, 6) end -- 召唤出来的
        elseif n < 16 then
            local ally = (e.side == caster.side) and s.side == caster.side
            if s.dead and not e.dead then -- 复活
                P.pillar(e.x, e.y, '#fff3b0', '#ffffff', 60, 12, 0.8); P.ring(e.x, e.y, 4, 20, '#fff3b0'); n = n + 1
            elseif not s.dead then
                if not ally then
                    if e.hp < s.hp - 0.5 or (e.dead and not s.dead) then
                        hits = hits + 1; n = n + 1
                        if hits <= 10 then P.star(e.x + rand(-2, 2), e.y - 4 + rand(-2, 2), c.col, c.col2, e.big and 9 or 6, 0.28, hits * 0.02) end
                    end
                    if not e.dead then
                        if (e.stun or 0) > s.st + 0.2 then P.stun(e) end
                        if (e.root or 0) > s.ro + 0.2 then P.roots(e) end
                        if (e.poison and e.poison.n or 0) > s.po then P.arrows(e, '#9be36b', '#4fbf4a', -1) end
                        if e.burn and e.burn ~= s.bu then P.arrows(e, '#ff8a2a', '#ffe14a', -1) end
                        if e.bleed and e.bleed ~= s.bl then P.arrows(e, '#d8433a', '#ff8a7a', -1) end
                        if e.curse and e.curse ~= s.cu then P.arrows(e, '#9a5ae0', '#c06bff', -1) end
                        if e.slow and e.slow ~= s.sl then P.ring(e.x, e.y, 3, 10, '#bff4ff', { thick = 1, dur = 0.5 }) end
                        if T(e.charmed) and not T(s.ch) then P.hearts(e) end
                        if abs(e.x - s.x) > 5 and e ~= caster then P.disk(s.x, s.y, 3, 6, '#c9b08a', 0.35, 0.5) end -- 被推开 / 吸过来
                    end
                else
                    if e.hp > s.hp + 0.5 then heals = heals + 1; n = n + 1; if heals <= 12 then P.cross(e, '#8fe07a') end end
                    if (e.shield or 0) > s.sh + 0.5 then n = n + 1; P.shield(e, (c.col == '#ffffff') and '#d6f2ff' or c.col) end
                    if (e.haste or 0) > s.ha + 0.2 or (e.overT or 0) > s.ov + 0.2 then n = n + 1; P.arrows(e, '#ff8a4a', '#ffe14a', 1) end
                    if e.guard and e.guard ~= s.gd then n = n + 1; P.shield(e, '#c9d2e0') end
                    if e.hot and e.hot ~= s.hot then P.cross(e, '#ff8ab8') end
                    if debuffed(s) and not (e.poison or e.burn or e.bleed or e.curse or e.slow) and (e.stun or 0) <= 0 then P.rays(e.x, e.y - 6, '#ffffff', '#dcf0ff', 10, 8, 0.35) end
                    if e == caster and hypot(e.x - s.x, e.y - s.y) > 10 then -- 突进：残影 + 拖尾
                        P.ghosts(entImg(e, false, e.face < 0), s.x, s.y, e.x, e.y, 4)
                    end
                end
            end
        end
    end
end

local function sigOf(key) return SIG[key] or DEFAULT_SIG end
-- 新射出的技能弹道：标上主题色，落点特效用
local function tagProjs(B, n0, c)
    for i = n0, B.projs.n - 1 do local p = B.projs[i]; if p then p.sfx = c.col; p.sfx2 = c.col2 end end
end

local CASTING = false
local _castSkill = castSkill
function castSkill(B, e, t)
    if REDUCED then return _castSkill(B, e, t) end
    local key = e.skill
    local before = snapshot(B)
    local n0 = B.projs.n
    local foes0 = foesOf(B, e)
    local ox, oy = e.x, e.y
    local tx, ty = t and t.x or e.x, t and t.y or e.y
    CASTING = true
    local ok, err = pcall(_castSkill, B, e, t)
    CASTING = false
    if not ok then error(err, 0) end
    local S3 = sigOf(key)
    local c = { col = S3[1], col2 = S3[2], ox = ox, oy = oy, tx = tx, ty = ty, foes = foes0, allies = alliesOf(B, e) }
    -- 施法法阵（施法前的位置；首领更大）
    P.rune(ox, oy, e.big and 24 or (e.sup and 20 or 14), c.col, c.col2, e.side == 'e' and not T(e.charmed), e.big and 0.9 or 0.7)
    if e.sup then -- 超凡：施法光柱用各自的主题色（第十二次更新）
        local th = SUP_THEME and SUP_THEME[e.branch]
        P.pillar(ox, oy, th and th.c1 or '#ff2a2a', th and th.c2 or '#ff8e6a', 50, 10, 0.6)
    end
    local okS, errS = pcall(S3[3], B, e, t, c)
    if not okS then print('[skillfx] ' .. tostring(key) .. ': ' .. tostring(errS)) end
    diffFx(B, e, before, c)
    tagProjs(B, n0, c)
end

-- 机制技能：FX.skill(e, 名字) 不经过 castSkill 时也给特效
local _skill = FX.skill
function FX.skill(e, name)
    _skill(e, name)
    if CASTING or REDUCED then return end
    local nm = NAMED[name]
    if nm then
        P.rune(e.x, e.y, e.big and 26 or 14, nm[1], nm[2], e.side == 'e', 0.9)
        local ok, err = pcall(nm[3], e)
        if not ok then print('[skillfx] ' .. name .. ': ' .. tostring(err)) end
    else
        P.rune(e.x, e.y, e.big and 22 or 14, '#ffe680', '#ffffff', e.side == 'e', 0.7)
        P.ring(e.x, e.y, 4, 22, '#ffe680', { thick = 2 })
    end
end

-- 技能弹道：飞行时带光晕，命中时有主题色爆点
local _drawProj = drawProj
function drawProj(p)
    if p.sfx and not REDUCED then
        local x, y = round(p.x), round(p.y)
        local prev = actx.globalAlpha
        actx.globalAlpha = prev * 0.35; actx.fillStyle = p.sfx
        actx:fillRect(x - 2, y - 1, 5, 3); actx:fillRect(x - 1, y - 2, 3, 5)
        actx.globalAlpha = prev
        if js.random() < 0.5 then FX.parts:push({ x = p.x, y = p.y, vx = rand(-4, 4), vy = rand(-4, 4), g = 0, life = 0.3, max = 0.3, color = (js.random() < 0.5) and p.sfx or (p.sfx2 or '#ffffff'), size = 1 }) end
    end
    return _drawProj(p)
end
local _impact = FX.impact
function FX.impact(p)
    _impact(p)
    if p.sfx and not REDUCED then
        local r = max(10, p.splash or 10)
        P.ring(p.tx, p.ty, 3, r, p.sfx, { col2 = p.sfx2, thick = 3, dur = 0.4 })
        P.disk(p.tx, p.ty, r * 0.3, r, p.sfx, 0.4, 0.3)
        P.star(p.tx, p.ty, p.sfx, p.sfx2, 7)
        if p.kind == 'meteor' or p.kind == 'shell' or p.kind == 'rock' then P.disk(p.tx, p.ty, 4, r * 0.7, '#2a1a12', 1.0, 0.45) end -- 弹坑
        if p.kind == 'frostbig' then for i = 0, 5 do local an = i / 6 * TAU; P.beam(p.tx, p.ty, p.tx + cos(an) * r * 0.8, p.ty + sin(an) * r * 0.5, '#bff4ff', 1, 0.45) end end
    end
end
local _procHit = procHit
function procHit(p, o)
    _procHit(p, o)
    if p.sfx and not p.area and not REDUCED then
        P.star(o.x, o.y - 4, p.sfx, p.sfx2, (p.mul or 1) >= 2 and 9 or 5, 0.3)
        if (p.mul or 1) >= 2.5 then P.ring(o.x, o.y, 2, 14, p.sfx, { thick = 2, dur = 0.3 }) end
    end
end

-- ---------------------------------------------------------------------------
-- 吸收：在吸收者头上显示获得的经验，以及到 ★★★（可以转职 / 晋升）的经验进度条
-- ---------------------------------------------------------------------------
local _absorb = absorb
function absorb(src, dst)
    local before, star0 = dst.pts, dst.star
    local r = _absorb(src, dst)
    local full = STAR_PTS[3]
    local to = dst.pts
    local label, lcol
    if r.ready or dst.star >= 3 then label, lcol = 'MAX', '#ffd84a'
    else label, lcol = S(to) .. '/' .. S(full), '#ffe680' end
    -- 同一个单位连续吸收时只保留最新的一条
    for i = #FX.anims, 1, -1 do local a = FX.anims[i]; if a.kind == 'expbar' and a.unit == dst then table.remove(FX.anims, i) end end
    add({ kind = 'expbar', unit = dst, x = 0, y = 0, from = min(before, full), to = min(to, full), max = full, marks = { STAR_PTS[2] }, gain = r.gain,
        label = label, labelCol = lcol, dur = 2.2, layer = 1 })
    local need = full - min(to, full)
    local nm = unitName and unitName(dst) or CLASSES[dst.cls].name
    local tail
    if r.ready or dst.star >= 3 then tail = '已满 ' .. starStr(3) .. '，可以' .. ((canPromote and canPromote(dst)) and '转职或晋升' or '转职')
    else tail = '进度 ' .. S(to) .. '/' .. S(full) .. '，再 ' .. S(need) .. ' 点经验可以转职' end
    if UI and UI.toast then UI.toast(nm .. ' 经验 +' .. S(r.gain) .. '（' .. tail .. '）') end
    return r
end

-- 战场规则 / 消耗品也接上新特效
local _useCons = useCons
function useCons(idx)
    local it = G.cons[idx]
    local B = G.battle
    local before = B and snapshot(B)
    local ok = _useCons(idx)
    if ok and B and it and not REDUCED then
        local col = ({ frostscroll = '#bff4ff', healpotion = '#8fe07a', ragepotion = '#ff6a4a', shieldscroll = '#fff3b0', thunder = '#ffe14a', dew = '#dcf0ff', whistle = '#ffe14a' })[it.id] or '#ffe680'
        if it.id == 'thunder' then for o in of(alliesOfSide(B, 'e')) do P.bolt(o.x, o.y, '#ffe14a', '#ffffff') end end
        if it.id == 'frostscroll' then P.wave(-8, AW + 8, '#bff4ff', '#ffffff', 0.7) end
        diffFx(B, { side = 'p' }, before, { col = col, col2 = '#ffffff' })
    end
    return ok
end

-- 第三次更新：导出给 skillfx2.lua（更具体的技能特效）
FX.SIG, FX.D = SIG, D
FX.H = { dot = dot, ring = ring, band = band, disk = disk, line = line, ease = ease, alphaOf = alphaOf, add = add, center = center,
    nova = nova, blast = blast, slash = slash, shot = shot, zone = zone, heal = heal, roar = roar, dash = dash, quake = quake, summon = summon, curseAt = curseAt, both = both,
    -- 护栏：绘图循环的次数由半径/坐标/个数决定，上游一旦算出 inf/nan 就会把循环撑爆而卡死。
    -- skillfx2.lua 的实体化特效同样依赖它们。
    guardN = guardN, guardV = guardV }

return true
