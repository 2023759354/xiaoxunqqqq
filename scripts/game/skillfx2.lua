-- ============================================================================
-- 第三次更新：技能特效「实体化」
-- 以前很多技能只有光圈 / 法阵。这里新增一批会真正「长出来、落下来、咬上去」的像素动画，
-- 并把全部兵种（10 个基础兵种 + 全部转职路线 + 超凡）的技能逐个重新搭配：
--  * 树根 / 藤蔓：古树卫士「生根」是粗壮的树根从脚下破土而出、藤蔓缠身；根网、血木降临从每个敌人脚下钻出
--  * 地刺：荆棘、冰刺、岩刺、骨刺从地面刺出（荆棘领域、冰封、裂地、末日践踏、亡骨召唤……）
--  * 落体：箭雨、陨石、巨石、星光、羽刃、巨剑（斩首）、整棵古木（倒木重击）
--  * 近身：三道爪痕、上下颚咬合、一闪的长刀光、旋风斩的回旋刀光
--  * 其他：圣光羽翼、齿轮与蒸汽、毒泡、花瓣、树叶、火焰、连锁闪电
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, sin, cos, sqrt = math.floor, math.ceil, math.max, math.min, math.abs, math.sin, math.cos, math.sqrt
local PI, TAU = math.pi, math.pi * 2
local of = js.of

local SIG, D, H = FX.SIG, FX.D, FX.H
local dot, line, disk, band, ease, alphaOf, add = H.dot, H.line, H.disk, H.band, H.ease, H.alphaOf, H.add
local P = FX.P
-- 护栏：与 skillfx.lua 同一套。这里的动画循环次数由 n / h / r 等参数决定，
-- 上游一旦算出 inf/nan，循环会撑到几十亿次而整帧卡死。
local guardN, guardV = H.guardN, H.guardV

--- 生长曲线：前 grow 段长出来，最后 25% 缩回去
local function growK(k, delay, grow)
    local g = clamp((k - (delay or 0)) / (grow or 0.3), 0, 1)
    local r = (k > 0.75) and max(0, 1 - (k - 0.75) / 0.25) or 1
    return ease(g) * r, g
end
local function px(x, y, w, h, c) actx.fillStyle = c; actx:fillRect(round(guardV(x)), round(guardV(y)), w, h) end

--- 动画首次生成 list 时的元素个数：钳制到合理范围，避免 inf/nan 把循环撑爆。
--- 注意这里上限要远小于 guardN 的 GUARD_MAX：list 元素个数会与外层循环相乘
--- （如 flames 是 n × h），两者都用 4000 会得到 1600 万次绘制而卡死。
local CNT_MAX = 64
local function cnt(n, fallback) return min(CNT_MAX, guardN('fx2', n or fallback or 1)) end

--- 单个元素内部的行数（高度方向逐像素绘制）：上限更小，因为它会乘上 list 的元素个数
local ROW_MAX = 128
local function rowN(n) return min(ROW_MAX, guardN('fx2', n)) end

-- ---------------------------------------------------------------------------
-- 新动画
-- ---------------------------------------------------------------------------
-- 树根破土：几条粗根从地面弯曲着长出来，根尖带嫩芽，根部有土堆和裂缝
D.groundroots = function(a, k, x, y)
    if not a.roots then
        a.roots = {}
        local n = cnt(a.n, 5)
        for i = 1, n do
            local f = (n == 1) and 0 or ((i - 1) / (n - 1) * 2 - 1)
            a.roots[i] = { dx = f * (a.r or 10) + rand(-1.5, 1.5), dy = rand(-2, 2), h = rand((a.h or 14) * 0.65, a.h or 14), bend = rand(-5, 5), delay = rand(0, 0.12), twig = js.random() < 0.6 }
        end
    end
    local base = y + 6
    local al = (k > 0.85) and (1 - (k - 0.85) / 0.15) or 1
    actx.globalAlpha = al * 0.5
    disk(x, base + 1, (a.r or 10) + 4, 0.35, '#2a1a12')
    for _, R in ipairs(a.roots) do
        local L, g = growK(k, R.delay, 0.28)
        local h = R.h * L
        local bx, by = x + R.dx, base + R.dy
        actx.globalAlpha = al
        px(bx - 2, by - 1, 5, 2, a.soil or '#4a2f1b') -- 土堆
        local thick = R.h * 0.5
        for j = 0, rowN(floor(h)) do
            local t = j / max(1, R.h)
            local X = bx + R.bend * sin(t * 2.4) * t
            local Y = by - j
            if j < thick then px(X - 1, Y, 1, 1, a.col); px(X, Y, 1, 1, a.col2); px(X + 1, Y, 1, 1, a.col)
            else px(X, Y, 1, 1, a.col2) end
            if R.twig and abs(j - floor(R.h * 0.55)) < 0.5 and h > R.h * 0.6 then -- 侧枝
                local s = (R.bend >= 0) and -1 or 1
                px(X + s, Y - 1, 1, 1, a.col2); px(X + s * 2, Y - 2, 1, 1, a.col2)
            end
        end
        if g >= 1 and L > 0.5 and a.leaf then -- 根尖的嫩芽
            local t = 1
            local X = bx + R.bend * sin(t * 2.4) * t
            px(X - 1, by - h - 1, 1, 1, a.leaf); px(X + 1, by - h - 1, 1, 1, a.leaf); px(X, by - h - 2, 1, 1, a.leaf)
        end
    end
end
-- 藤蔓缠身：螺旋绕着单位往上爬，带叶子
D.vinewrap = function(a, k, x, y)
    local L = growK(k, 0, 0.35)
    local al = (k > 0.85) and (1 - (k - 0.85) / 0.15) or 1
    actx.globalAlpha = al
    local hgt = a.h or 16
    local n = rowN(floor(40 * L))
    for i = 0, n do
        local t = i / 40
        local an = t * TAU * 2.2 + (a.ph or 0)
        local X = x + cos(an) * (a.w or 6)
        local Y = y + 6 - t * hgt
        local front = sin(an) > 0
        px(X, Y, 1, 1, front and a.col2 or a.col)
        if i % 9 == 4 then px(X + (front and 1 or -1), Y - 1, 2, 1, a.leaf or a.col2) end
    end
end
-- 地刺：三角形的刺从地面刺出（荆棘 / 冰 / 岩石 / 骨）
D.spikes = function(a, k, x, y)
    if not a.list then
        a.list = {}
        local n = cnt(a.n, 6)
        for i = 1, n do
            local dx, dy
            if a.line then dx = a.line * (i - 1) * (a.step or 7); dy = rand(-3, 3)
            elseif a.ringR then local an = (i - 1) / n * TAU + rand(-0.2, 0.2); dx = cos(an) * a.ringR; dy = sin(an) * a.ringR * 0.5
            else dx = rand(-(a.r or 10), a.r or 10); dy = rand(-(a.r or 10) * 0.4, (a.r or 10) * 0.4) end
            a.list[i] = { dx = dx, dy = dy, h = rand((a.h or 10) * 0.6, a.h or 10), w = a.w or 4, delay = (a.line and (i - 1) * 0.05) or rand(0, 0.1) }
        end
    end
    local al = (k > 0.85) and (1 - (k - 0.85) / 0.15) or 1
    actx.globalAlpha = al
    for _, s in ipairs(a.list) do
        local L = growK(k, s.delay, 0.18)
        local hh = rowN(floor(s.h * L))
        local bx, by = round(x + s.dx), round(y + 6 + s.dy)
        if hh > 0 then
            for r = 0, hh - 1 do
                local w = max(1, round(s.w * (1 - r / max(1, s.h))))
                local x0 = bx - floor(w / 2)
                local hw = max(1, floor(w / 2))
                px(x0, by - r, hw, 1, a.col)
                if w - hw > 0 then px(x0 + hw, by - r, w - hw, 1, a.col2) end
            end
            px(bx, by - hh, 1, 1, a.tip or '#ffffff')
            actx.globalAlpha = al * 0.5; px(bx - 2, by + 1, 5, 1, '#1b1530'); actx.globalAlpha = al
        end
    end
end
-- 落体：箭雨 / 星光 / 羽刃（a.style = 'arrow' | 'star' | 'feather' | 'blood'）
D.rain = function(a, k, x, y)
    if not a.list then
        a.list = {}
        local pts = a.pts
        if pts then for i, p in ipairs(pts) do a.list[i] = { x = p[1] + rand(-2, 2), y = p[2], delay = (i - 1) * (a.stagger or 0.04) } end
        else for i = 1, cnt(a.n, 8) do a.list[i] = { x = x + rand(-(a.r or 14), a.r or 14), y = y + rand(-(a.r or 14) * 0.45, (a.r or 14) * 0.45), delay = rand(0, 0.35) } end end
    end
    local fall = a.fall or 0.28
    for _, d in ipairs(a.list) do
        local p = (k - d.delay) / fall
        if p > 0 then
            local ax = d.x - (1 - min(1, p)) * (a.slant or 6)
            local ay = d.y + 2 - (1 - min(1, p)) * 60
            if p < 1 then
                actx.globalAlpha = 1
                if a.style == 'star' then
                    px(ax - 1, ay, 3, 1, a.col2 or '#ffffff'); px(ax, ay - 1, 1, 3, a.col2 or '#ffffff'); px(ax, ay, 1, 1, '#ffffff')
                    actx.globalAlpha = 0.5; line(ax, ay - 2, ax + (a.slant or 6) * 0.15, ay - 10, a.col)
                elseif a.style == 'feather' then
                    line(ax - 2, ay - 3, ax + 1, ay, a.col); px(ax - 2, ay - 2, 1, 1, a.col2); px(ax, ay - 3, 1, 1, a.col2)
                elseif a.style == 'blood' then
                    px(ax, ay - 3, 1, 4, a.col); px(ax - 1, ay, 3, 2, a.col2 or a.col)
                else -- 箭
                    line(ax - 1, ay - 7, ax, ay, a.col); px(ax - 2, ay - 7, 1, 1, a.col2 or '#ffffff'); px(ax, ay - 8, 1, 1, a.col2 or '#ffffff'); px(ax, ay, 1, 1, '#ffffff')
                end
            elseif k < 0.92 then
                local q = min(1, (p - 1) * fall / 0.15)
                actx.globalAlpha = 1 - q * 0.6
                if a.style == 'arrow' or a.style == nil then line(d.x - 1, d.y - 2, d.x, d.y + 2, a.col); px(d.x - 2, d.y - 2, 1, 1, a.col2 or '#ffffff')
                else band(d.x, d.y + 2, 1 + q * 5, 1, 0.5, a.col2 or a.col) end
            end
        end
    end
end
-- 陨石 / 巨石：从天上斜着砸下来，带火焰（或尘土）拖尾
D.meteor = function(a, k, x, y)
    local fall = 0.5
    if k > fall then return end
    local p = ease(k / fall)
    local sx, sy = x - (a.dx or 40), y - 80
    local X, Y = sx + (x - sx) * p, sy + (y - sy) * p
    local r = a.r or 4
    for i = 1, 8 do -- 拖尾
        local q = max(0, p - i * 0.03)
        local tx, ty = sx + (x - sx) * q, sy + (y - sy) * q
        actx.globalAlpha = (1 - i / 9) * 0.8
        disk(tx, ty, max(1, r - i * 0.4), 1, (i < 3) and (a.col2 or '#ffe14a') or a.col)
    end
    actx.globalAlpha = 1
    disk(X, Y, r, 1, a.rock or '#5a3a2a'); disk(X - 1, Y - 1, max(1, r - 2), 1, a.col)
    if a.fire ~= false then px(X - 1, Y - 1, 2, 2, '#ffe14a') end
end
-- 火焰：一片跳动的火舌
D.flames = function(a, k, x, y)
    if not a.list then a.list = {}; for i = 1, cnt(a.n, 6) do a.list[i] = { dx = rand(-(a.r or 10), a.r or 10), dy = rand(-3, 3), ph = rand(0, 6), h = rand(4, a.h or 9) } end end
    local al = alphaOf(a, k)
    for _, f in ipairs(a.list) do
        local h = f.h * (0.6 + 0.4 * sin(G.time * 18 + f.ph)) * growK(k, 0, 0.2)
        local bx, by = x + f.dx, y + 6 + f.dy
        actx.globalAlpha = al
        for r = 0, rowN(floor(h)) do
            local t = r / max(1, h)
            local w = (t < 0.4) and 3 or ((t < 0.75) and 2 or 1)
            local c = (t < 0.35) and '#d8433a' or ((t < 0.7) and '#ff8a2a' or '#ffe14a')
            px(bx - floor(w / 2) + round(sin(G.time * 12 + f.ph + r) * 0.6), by - r, w, 1, c)
        end
    end
end
-- 飘落 / 盘旋的小东西：花瓣、树叶、雪花
D.flutter = function(a, k, x, y)
    if not a.list then a.list = {}; for i = 1, cnt(a.n, 10) do a.list[i] = { x = x + rand(-(a.r or 18), a.r or 18), y = y - rand(10, 30), ph = rand(0, 6), c = (i % 3 == 0) and (a.col2 or a.col) or a.col } end end
    local al = alphaOf(a, k)
    actx.globalAlpha = al
    for _, f in ipairs(a.list) do
        local X = f.x + sin(G.time * 3 + f.ph) * 4 + (a.drift or 0) * k
        local Y = f.y + k * (a.fall or 26)
        if floor(G.time * 6 + f.ph) % 2 == 0 then px(X, Y, 2, 1, f.c) else px(X, Y, 1, 2, f.c) end
    end
end
-- 三道爪痕
D.claws = function(a, k, x, y)
    for i = 0, 2 do
        local kk = clamp((k - i * 0.08) / 0.25, 0, 1)
        if kk > 0 then
            local fade = (k > 0.6) and (1 - (k - 0.6) / 0.4) or 1
            actx.globalAlpha = fade
            local o = (i - 1) * 4
            local L = 12 * ease(kk)
            local f = a.f or 1
            local x0, y0 = x - 6 * f + o, y - 12
            line(x0, y0, x0 + L * 0.6 * f, y0 + L, (kk < 0.5) and '#ffffff' or a.col)
            line(x0 + 1, y0, x0 + 1 + L * 0.6 * f, y0 + L, a.col2 or a.col)
        end
    end
end
-- 上下颚咬合（饮血、裂喉、吞噬）
D.bite = function(a, k, x, y)
    local c = ease(min(1, k / 0.3))
    local open = 9 * (1 - c)
    local fade = (k > 0.6) and (1 - (k - 0.6) / 0.4) or 1
    actx.globalAlpha = fade
    local w = min(ROW_MAX, guardN('bite', a.w or 7))
    local cy = y - 5
    for i = -w, w do
        local tooth = (i % 3 == 0) and 3 or 1
        px(x + i, cy - open - 2, 1, 2, a.col); px(x + i, cy - open, 1, tooth, '#ffffff')
        px(x + i, cy + open + 1, 1, 2, a.col); px(x + i, cy + open + 1 - tooth, 1, tooth, '#ffffff')
    end
end
-- 连锁闪电：在一串点之间来回闪的折线
D.chainbolt = function(a, k, x, y)
    if floor(G.time * 24) % 3 == 0 and k > 0.3 then return end
    actx.globalAlpha = 1 - k * 0.6
    local pts = a.pts
    for i = 2, #pts do
        local p, q = pts[i - 1], pts[i]
        local lx, ly = p[1], p[2]
        for s = 1, 4 do
            local f = s / 4
            local nx = p[1] + (q[1] - p[1]) * f + ((s < 4) and rand(-3, 3) or 0)
            local ny = p[2] + (q[2] - p[2]) * f + ((s < 4) and rand(-3, 3) or 0)
            line(lx, ly, nx, ny, (k < 0.2) and '#ffffff' or a.col); line(lx + 1, ly, nx + 1, ny, a.col2 or a.col)
            lx, ly = nx, ny
        end
    end
end
-- 圣光羽翼：在单位身后展开
D.wings = function(a, k, x, y)
    local s = ease(min(1, k / 0.35))
    local al = alphaOf(a, k)
    for side = -1, 1, 2 do
        for i = 0, 5 do
            local len = (6 + i * 2.2) * s
            local an = -0.25 - i * 0.22
            local x0, y0 = x + side * 2, y - 8
            actx.globalAlpha = al * (1 - i * 0.08)
            line(x0, y0, x0 + side * cos(an) * len, y0 + sin(an) * len * 1.1 - i * 0.6, (i % 2 == 0) and a.col or (a.col2 or '#ffffff'))
        end
    end
end
-- 从天而降的巨剑（斩首）
D.bigsword = function(a, k, x, y)
    local fall = 0.3
    local p = min(1, k / fall)
    local tip = y - 2 - (1 - ease(p)) * 60
    local fade = (k > 0.7) and (1 - (k - 0.7) / 0.3) or 1
    actx.globalAlpha = fade
    local top = tip - 20
    px(x - 1, top, 3, 20, '#c9d2e0'); px(x, top, 1, 20, '#ffffff')
    px(x - 4, top - 1, 9, 2, a.col or '#ffd84a'); px(x - 1, top - 6, 3, 5, '#6b4527'); px(x - 1, top - 7, 3, 1, a.col or '#ffd84a')
    if p >= 1 and k < 0.55 then actx.globalAlpha = 1 - (k - fall) / 0.25; band(x, y + 2, 4 + (k - fall) * 40, 1, 0.5, '#ffffff') end
end
-- 倒下的整棵古木（倒木重击）
D.timber = function(a, k, x, y)
    local f = a.f or 1
    local p = ease(min(1, k / 0.32))
    local an = -PI / 2 + p * PI / 2 * 0.98 -- 从竖直倒向前方
    local L = 34
    local fade = (k > 0.7) and (1 - (k - 0.7) / 0.3) or 1
    actx.globalAlpha = fade
    local ex, ey = x + f * cos(an) * L, y + 4 + sin(an) * L
    for o = -1, 1 do line(x + o, y + 4, ex + o, ey, (o == 1) and '#9b6a3c' or '#6b4527') end
    disk(ex, ey - 2, 6, 0.8, '#2f7a34'); disk(ex - f * 2, ey - 3, 4, 0.8, '#4fbf4a'); dot(ex + f, ey - 4, '#9be36b')
end
-- 齿轮：两个互相咬合转动的齿轮
local function gear(x, y, r, rot, c, c2)
    for i = 0, 7 do
        local an = rot + i / 8 * TAU
        px(x + cos(an) * (r + 1), y + sin(an) * (r + 1), 2, 2, c)
    end
    actx.fillStyle = c; band(x, y, r, 2, 1, c)
    px(x - 1, y - 1, 2, 2, c2)
end
D.gears = function(a, k, x, y)
    actx.globalAlpha = alphaOf(a, k)
    local s = 0.6 + 0.4 * ease(min(1, k * 3))
    gear(x - 4, y - 14, 4 * s, G.time * 6, a.col, a.col2)
    gear(x + 4, y - 18, 3 * s, -G.time * 8, a.col2, a.col)
end
-- 冒泡：毒泡往上飘、破掉
D.bubbles = function(a, k, x, y)
    if not a.list then a.list = {}; for i = 1, cnt(a.n, 7) do a.list[i] = { dx = rand(-(a.r or 8), a.r or 8), ph = rand(0, 1), s = (js.random() < 0.4) and 2 or 1 } end end
    actx.globalAlpha = alphaOf(a, k)
    for _, b in ipairs(a.list) do
        local t = (k * 1.6 + b.ph) % 1
        local X, Y = x + b.dx + sin(t * 9) * 1, y + 4 - t * (a.h or 18)
        if t > 0.85 then px(X - 1, Y, 1, 1, a.col2 or '#ffffff'); px(X + 1, Y, 1, 1, a.col2 or '#ffffff')
        elseif b.s == 2 then px(X - 1, Y - 1, 3, 1, a.col); px(X - 1, Y + 1, 3, 1, a.col); px(X - 1, Y, 1, 1, a.col); px(X + 1, Y, 1, 1, a.col); px(X, Y - 1, 1, 1, '#ffffff')
        else px(X, Y, 1, 1, a.col) end
    end
end
-- 蒸汽团：一团团往外扩散的白气
D.steam = function(a, k, x, y)
    if not a.list then a.list = {}; for i = 1, cnt(a.n, 8) do local an = i / cnt(a.n, 8) * TAU + rand(-0.3, 0.3); a.list[i] = { c = cos(an), s = sin(an) } end end
    local e = ease(k)
    for _, p in ipairs(a.list) do
        actx.globalAlpha = (1 - k) * 0.7
        disk(x + p.c * (a.r or 22) * e, y + p.s * (a.r or 22) * 0.5 * e, 2 + 3 * e, 0.8, a.col or '#e6edf7')
    end
end
-- 长刀光（一闪）：一条横贯的细线，先白后淡
D.flashcut = function(a, k, x, y)
    local L = (a.L or 36) * ease(min(1, k / 0.15))
    local fade = (k > 0.3) and (1 - (k - 0.3) / 0.7) or 1
    actx.globalAlpha = fade
    local f = a.f or 1
    line(x - f * L * 0.5, y + 2, x + f * L * 0.5, y - 2, '#ffffff')
    actx.globalAlpha = fade * 0.6
    line(x - f * L * 0.5, y + 3, x + f * L * 0.5, y - 1, a.col)
end

-- ---------------------------------------------------------------------------
-- 组合函数
-- ---------------------------------------------------------------------------
local function anim(kind, x, y, o)
    o = o or {}
    o.kind = kind; o.x = x; o.y = y; o.layer = o.layer or 1
    return add(o)
end
local R = {}
function R.roots(x, y, o) o = o or {}; return anim('groundroots', x, y, { n = o.n or 5, r = o.r or 9, h = o.h or 14, col = o.col or '#4a2f1b', col2 = o.col2 or '#9b6a3c', leaf = o.leaf == nil and '#7fd36a' or o.leaf, soil = o.soil, dur = o.dur or 1.3, delay = o.delay }) end
function R.vine(ent, o) o = o or {}; return add({ kind = 'vinewrap', ent = ent, col = o.col or '#2f7a34', col2 = o.col2 or '#7fd36a', leaf = o.leaf or '#9be36b', h = o.h or 16, w = o.w or (ent.big and 9 or 6), ph = rand(0, 6), dur = o.dur or 1.2, layer = 1 }) end
function R.spikes(x, y, o) o = o or {}; return anim('spikes', x, y, { n = o.n or 6, r = o.r, ringR = o.ringR, line = o.line, step = o.step, h = o.h or 10, w = o.w or 4, col = o.col, col2 = o.col2, tip = o.tip, dur = o.dur or 0.9, delay = o.delay }) end
function R.rain(x, y, o) o = o or {}; return anim('rain', x, y, { n = o.n, r = o.r, pts = o.pts, style = o.style, col = o.col, col2 = o.col2, slant = o.slant, fall = o.fall, stagger = o.stagger, dur = o.dur or 0.9 }) end
function R.meteor(x, y, o) o = o or {}; anim('meteor', x, y, { r = o.r or 4, col = o.col or '#ff8a2a', col2 = o.col2 or '#ffe14a', rock = o.rock, fire = o.fire, dx = o.dx, dur = o.dur or 0.7, delay = o.delay }) end
function R.flames(x, y, o) o = o or {}; return anim('flames', x, y, { n = o.n or 6, r = o.r or 10, h = o.h or 9, dur = o.dur or 1.0, delay = o.delay }) end
function R.flutter(x, y, col, col2, o) o = o or {}; return anim('flutter', x, y, { n = o.n or 10, r = o.r or 18, col = col, col2 = col2, fall = o.fall, drift = o.drift, dur = o.dur or 1.1 }) end
function R.claws(x, y, f, col, col2, delay) return anim('claws', x, y, { f = f or 1, col = col or '#ff4a3a', col2 = col2 or '#ffffff', dur = 0.45, delay = delay }) end
function R.bite(x, y, col, w, delay) return anim('bite', x, y, { col = col or '#7a1f2b', w = w or 7, dur = 0.45, delay = delay }) end
function R.chain(pts, col, col2) if #pts >= 2 then anim('chainbolt', pts[1][1], pts[1][2], { pts = pts, col = col, col2 = col2, dur = 0.45 }) end end
function R.wings(ent, col, col2, dur) add({ kind = 'wings', ent = ent, col = col, col2 = col2, dur = dur or 1.0, layer = 0 }) end
function R.gears(ent, col, col2) add({ kind = 'gears', ent = ent, col = col or '#e2b33c', col2 = col2 or '#ffe27a', dur = 0.9, layer = 1 }) end
function R.bubbles(x, y, col, col2, o) o = o or {}; return anim('bubbles', x, y, { n = o.n or 7, r = o.r or 8, h = o.h, col = col, col2 = col2, dur = o.dur or 1.0 }) end
function R.steam(x, y, r, col) return anim('steam', x, y, { r = r or 22, col = col, dur = 0.7 }) end
FX.R = R

-- 常用目标集合
local function foesNear(c, x, y, rad, cap)
    local out = {}
    for o in of(c.foes) do if hypot(o.x - x, o.y - y) <= rad and #out < (cap or 10) then out[#out + 1] = o end end
    return out
end
local function eachFoe(c, cap, f) local i = 0; for o in of(c.foes) do if i < (cap or 10) then i = i + 1; f(o, i) end end end
local function both(...) local fs = { ... }; return function(...) for _, f in ipairs(fs) do f(...) end end end
local function add2(key, f) local old = SIG[key]; SIG[key] = { old and old[1] or '#ffe680', old and old[2] or '#ffffff', old and both(old[3], f) or f } end
local function set(key, c1, c2, f) SIG[key] = { c1, c2, f } end

-- 地刺的配色
local THORN = { col = '#2f7a34', col2 = '#4fbf4a', tip = '#ff6a8a' }
local ICE = { col = '#7fd0ff', col2 = '#bff4ff', tip = '#ffffff' }
local ROCK = { col = '#5a4a38', col2 = '#a89878', tip = '#c9b08a' }
local BONE = { col = '#a89f8a', col2 = '#e9e2cf', tip = '#ffffff' }
local BLOODT = { col = '#7a1f2b', col2 = '#d8433a', tip = '#ff8e6a' }
local function sp(base, o) local r = {}; for k, v in pairs(base) do r[k] = v end; for k, v in pairs(o or {}) do r[k] = v end; return r end

-- ---------------------------------------------------------------------------
-- 逐个兵种的技能
-- ---------------------------------------------------------------------------
-- —— 古树卫士 ——（基础「生根」：粗根从脚下破土，藤蔓缠身，再罩上树皮护盾）
set('rootguard', '#6fbf5a', '#bff0c8', function(B, e, t, c)
    R.roots(e.x, e.y, { n = 7, r = 13, h = 20, dur = 1.6 })
    R.roots(e.x, e.y + 3, { n = 4, r = 7, h = 9, col = '#6b4527', col2 = '#c9955a', dur = 1.6, delay = 0.08 })
    R.vine(e, { h = 18, dur = 1.6 })
    P.shield(e, '#9be36b', e.big and 16 or 11)
    for _, o in ipairs(foesNear(c, e.x, e.y, 40, 6)) do P.beam(e.x, e.y - 4, o.x, o.y - 4, '#6fbf5a', 1, 0.3) end -- 嘲讽连线
    FX.particle(e.x, e.y + 6, '#6b4527', 10, 40, 80, 0.5)
end)
set('rootnet', '#2f7a34', '#4fbf4a', function(B, e, t, c)
    R.roots(e.x, e.y, { n = 6, r = 14, h = 12 })
    for _, o in ipairs(foesNear(c, e.x, e.y, 56, 8)) do
        R.roots(o.x, o.y, { n = 3, r = 4, h = 10, dur = 1.4 }); R.vine(o, { dur = 1.4 })
    end
end)
set('bloodgrove', '#ff3434', '#7a1f2b', function(B, e, t, c)
    P.ring(e.x, e.y, 6, 60, '#ff3434', { thick = 2, dur = 0.6 })
    eachFoe(c, 10, function(o) R.roots(o.x, o.y, { n = 4, r = 5, h = 14, col = '#4c1b2f', col2 = '#d8433a', leaf = '#ff8e6a', soil = '#2a0f18', dur = 1.3 }) end)
    R.wings(e, '#ff3434', '#ffb0a0', 1.0)
end)
set('brambleburst', '#4fbf4a', '#ff6a8a', function(B, e, t, c)
    R.spikes(e.x, e.y, sp(THORN, { n = 10, ringR = 16, h = 11 }))
    R.spikes(e.x, e.y, sp(THORN, { n = 6, ringR = 8, h = 8, delay = 0.08 }))
    R.roots(e.x, e.y, { n = 3, r = 5, h = 8 })
    for _, o in ipairs(foesNear(c, e.x, e.y, 34, 6)) do R.vine(o, { dur = 1.0 }) end
end)
set('lifegrove', '#bff0c8', '#6fbf5a', function(B, e, t, c)
    H.zone(44, true)(B, e, t, c)
    R.roots(e.x, e.y, { n = 6, r = 26, h = 10, dur = 1.8 })
    R.flutter(e.x, e.y, '#7fd36a', '#ff8ab8', { n = 16, r = 34, dur = 1.8 })
    for o in of(c.allies) do if hypot(o.x - e.x, o.y - e.y) < 46 then P.cross(o, '#8fe07a') end end
end)
set('barkskin', '#9b6a3c', '#c9955a', function(B, e, t, c)
    R.vine(e, { col = '#6b4527', col2 = '#c9955a', leaf = '#9b6a3c', h = 18, w = e.big and 9 or 6, dur = 1.4 })
    R.vine(e, { col = '#4a2f1b', col2 = '#9b6a3c', leaf = '#7fd36a', h = 14, dur = 1.4 })
    P.shield(e, '#c9955a', 12)
    R.spikes(e.x, e.y, sp(ROCK, { n = 5, ringR = 10, h = 5, w = 3, col = '#6b4527', col2 = '#9b6a3c', tip = '#c9955a' }))
end)
set('mossheal', '#9be36b', '#c4f0a0', function(B, e, t, c)
    H.heal(B, e, t, c)
    R.flutter(e.x, e.y, '#9be36b', '#4fbf4a', { n = 14, r = 24 })
    R.roots(e.x, e.y, { n = 4, r = 10, h = 7, leaf = '#c4f0a0' })
end)
set('uproot', '#ffd84a', '#c9b08a', function(B, e, t, c)
    H.quake(36)(B, e, t, c)
    R.roots(e.x, e.y, { n = 8, r = 18, h = 18, dur = 1.0 })
    P.arc(e.x, e.y - 3, e.face, 22, '#9b6a3c', '#c9b08a', 0.35, -2.8, 2.8)
    FX.particle(e.x, e.y + 4, '#6b4527', 16, 70, 120, 0.6)
end)
set('timberslam', '#c9b08a', '#8a6a4a', function(B, e, t, c)
    add({ kind = 'timber', x = e.x + e.face * 3, y = e.y, f = e.face, dur = 0.9, layer = 1 })
    P.ring(e.x + e.face * 30, e.y, 4, 22, '#c9b08a', { thick = 3, dur = 0.45, delay = 0.28 })
    FX.particle(e.x + e.face * 30, e.y + 4, '#8a6a4a', 14, 60, 120, 0.6)
end)
-- —— 战士 ——
add2('bash', function(B, e, t, c) if t then R.spikes(t.x, t.y, sp(ROCK, { n = 4, r = 6, h = 5, w = 3 })) end end)
set('issen', '#ffffff', '#c9d2e0', function(B, e, t, c)
    local x = t and t.x or c.tx
    local y = t and (t.y - 4) or c.ty
    anim('flashcut', x, y, { f = e.face, L = 46, col = '#c9d2e0', dur = 0.5 })
    P.ghosts(entImg(e, false, e.face < 0), c.ox, c.oy, e.x, e.y, 4)
    if t then P.star(t.x, t.y - 4, '#ffffff', '#c9d2e0', 10, 0.35, 0.08) end
end)
set('leap', '#ffa53a', '#ffe680', function(B, e, t, c)
    P.ghosts(entImg(e, false, e.face < 0), c.ox, c.oy - 10, e.x, e.y, 4)
    H.quake(26)(B, e, t, c)
    R.spikes(e.x, e.y, sp(ROCK, { n = 8, ringR = 14, h = 7 }))
    R.wings(e, '#ffa53a', '#ffe680', 0.7)
end)
add2('shockwave', function(B, e, t, c) R.spikes(e.x + e.face * 8, e.y, sp(ROCK, { n = 6, line = e.face, step = 6, h = 9 })) end)
add2('aegis', function(B, e, t, c) R.wings(e, '#fff3b0', '#ffffff', 1.1) end)
add2('vengeance', function(B, e, t, c) if t then R.rain(t.x, t.y, { n = 6, r = 6, style = 'blood', col = '#d8433a', col2 = '#7a1f2b', dur = 0.7 }) end end)
add2('behead', function(B, e, t, c) if t then anim('bigsword', t.x, t.y, { col = '#ffd84a', dur = 0.8 }) end end)
add2('warcry', function(B, e, t, c) P.arrows(e, '#ff6a4a', '#ffe14a', 1); for o in of(c.allies) do P.arrows(o, '#ff8a4a', '#ffe14a', 1) end end)
add2('giant', function(B, e, t, c) R.spikes(e.x, e.y, sp(ROCK, { n = 10, ringR = 22, h = 9 })) end)
add2('sanctuary', function(B, e, t, c) R.wings(e, '#fff3b0', '#ffffff', 1.3); R.rain(e.x, e.y, { n = 12, r = 40, style = 'star', col = '#fff3b0', col2 = '#ffffff' }) end)
add2('whirlwind', function(B, e, t, c)
    for i = 0, 3 do P.arc(e.x, e.y - 3, (i % 2 == 0) and 1 or -1, 16, '#ff9a7a', '#ffffff', 0.3, -3.0 + i * 0.4, 0.6 + i * 0.4) end
    FX.particle(e.x, e.y + 4, '#c9b08a', 10, 50, 40, 0.4)
end)
add2('crimsonmoon', function(B, e, t, c) eachFoe(c, 8, function(o) if (o.x - e.x) * e.face > 0 then R.rain(o.x, o.y, { n = 3, r = 4, style = 'blood', col = '#ff3434', col2 = '#7a1f2b', dur = 0.7 }) end end) end)
-- —— 射手 ——
add2('volley', function(B, e, t, c) R.rain(c.tx, c.ty, { n = 12, r = 16, style = 'arrow', col = '#c99a5b', col2 = '#ffe680', dur = 1.0 }) end)
add2('triple', function(B, e, t, c) if t then R.rain(t.x, t.y, { pts = { { t.x - 3, t.y }, { t.x, t.y }, { t.x + 3, t.y } }, style = 'arrow', col = '#c99a5b', col2 = '#ffe680', fall = 0.18, stagger = 0.08, dur = 0.6 }) end end)
add2('starfall', function(B, e, t, c) local pts = {}; eachFoe(c, 12, function(o) pts[#pts + 1] = { o.x, o.y } end); R.rain(0, 0, { pts = pts, style = 'star', col = '#ffe680', col2 = '#ffffff', slant = -8, dur = 0.9 }) end)
add2('venomburst', function(B, e, t, c) R.bubbles(c.tx, c.ty, '#9be36b', '#e6ff6a', { n = 12, r = 14 }) end)
add2('barrage', function(B, e, t, c) local pts = {}; eachFoe(c, 8, function(o) pts[#pts + 1] = { o.x, o.y } end); R.rain(0, 0, { pts = pts, style = 'arrow', col = '#c99a5b', col2 = '#ffe680', slant = 10, stagger = 0.06, dur = 0.9 }) end)
add2('turret', function(B, e, t, c) R.gears(e, '#ffb04a', '#ffe14a') end)
add2('shadowclone', function(B, e, t, c) R.steam(e.x, e.y - 2, 14, '#8f4bc4') end)
add2('wolf', function(B, e, t, c) R.flutter(e.x, e.y, '#c9cbd6', '#ffffff', { n = 8, r = 14, fall = 10 }) end)
add2('bloodarrow', function(B, e, t, c) R.wings(e, '#ff3434', '#ff8e6a', 0.8) end)
-- —— 法师 ——
add2('arcane', function(B, e, t, c) R.rain(c.tx, c.ty, { n = 8, r = 18, style = 'star', col = '#c06bff', col2 = '#6ef0ff', dur = 0.8 }) end)
add2('frostnova', function(B, e, t, c) R.spikes(c.tx, c.ty, sp(ICE, { n = 12, r = 22, h = 12 })); R.flutter(c.tx, c.ty, '#ffffff', '#bff4ff', { n = 12, r = 24 }) end)
add2('hex', function(B, e, t, c) R.bubbles(c.tx, c.ty, '#9a5ae0', '#c06bff', { n = 10, r = 18 }) end)
add2('purify', function(B, e, t, c) R.wings(e, '#ffffff', '#fff3b0', 0.9) end)
add2('legion', function(B, e, t, c) R.spikes(e.x, e.y, sp(BONE, { n = 8, ringR = 18, h = 9 })) end)
add2('raise', function(B, e, t, c) R.spikes(e.x + e.face * 10, e.y, sp(BONE, { n = 5, r = 8, h = 8 })) end)
set('meteor', '#ff8a2a', '#ffe14a', function(B, e, t, c)
    H.shot(B, e, t, c)
    R.meteor(c.tx, c.ty, { r = 6, dur = 0.8 })
    P.ring(c.tx, c.ty, 22, 22, '#ff5a2a', { thick = 1, dash = true, dur = 0.5 })
    P.ring(c.tx, c.ty, 3, 26, '#ff8a2a', { col2 = '#ffe14a', thick = 3, dur = 0.45, delay = 0.38 })
    R.flames(c.tx, c.ty, { n = 9, r = 18, dur = 1.2 }).delay = 0.35
end)
add2('chain', function(B, e, t, c)
    local pts, last = { { e.x + e.face * 5, e.y - 6 } }, t
    local used = {}
    if t then pts[#pts + 1] = { t.x, t.y - 4 }; used[t] = true end
    for _ = 1, 4 do
        if not last then break end
        local best, bd = nil, 1e9
        for o in of(c.foes) do if not used[o] then local d = hypot(o.x - last.x, o.y - last.y); if d < bd and d < 60 then best, bd = o, d end end end
        if not best then break end
        used[best] = true; pts[#pts + 1] = { best.x, best.y - 4 }; last = best
    end
    R.chain(pts, '#ffe14a', '#78a8f2')
end)
add2('bloodmoon', function(B, e, t, c) eachFoe(c, 10, function(o, i) P.bolt(o.x, o.y, '#ff3434', '#ff8e6a', i * 0.04) end) end)
SIG.elements[3] = function(B, e, t, c)
    local k = ((e.elemIdx or 1) - 1) % 3
    local cols = { [0] = { '#ff8a2a', '#ffe14a' }, { '#bff4ff', '#7fd0ff' }, { '#ffe14a', '#78a8f2' } }
    c.col, c.col2 = cols[k][1], cols[k][2]
    H.shot(B, e, t, c); P.rune(e.x, e.y, 16, c.col, c.col2)
    if k == 0 then R.meteor(c.tx, c.ty, { r = 6 }); R.flames(c.tx, c.ty, { n = 8, r = 14 }).delay = 0.35
    elseif k == 1 then R.spikes(c.tx, c.ty, sp(ICE, { n = 10, r = 18, h = 12 }))
    else
        local pts = { { e.x, e.y - 6 } }
        for _, o in ipairs(foesNear(c, c.tx, c.ty, 70, 4)) do pts[#pts + 1] = { o.x, o.y - 4 } end
        R.chain(pts, '#ffe14a', '#78a8f2')
    end
end
-- —— 猛虎 ——
local function clawAt(col) return function(B, e, t, c) if t then R.claws(t.x, t.y, e.face, col or '#ff4a3a', '#ffffff') end end end
add2('pounce', clawAt('#ffa53a'))
SIG.rend[3] = function(B, e, t, c) if t then for i = 0, 2 do R.claws(t.x + (i - 1) * 2, t.y, (i % 2 == 0) and e.face or -e.face, '#ff4a3a', '#ffffff', i * 0.1) end; R.rain(t.x, t.y, { n = 4, r = 4, style = 'blood', col = '#d8433a', dur = 0.7 }) end end
add2('ambush', clawAt('#c06bff'))
add2('shadowstrike', both(clawAt('#c06bff'), function(B, e, t, c) R.steam(c.ox, c.oy - 2, 10, '#5a2a7a') end))
add2('huntchain', clawAt('#ff8a2a'))
add2('bloodrush', clawAt('#ff3434'))
add2('throatrip', function(B, e, t, c) if t then R.bite(t.x, t.y, '#7a1f2b', 7); R.rain(t.x, t.y, { n = 6, r = 5, style = 'blood', col = '#d8433a', col2 = '#7a1f2b', dur = 0.8 }) end end)
add2('drinkblood', function(B, e, t, c) if t then R.bite(t.x, t.y, '#7a1f2b', 6); R.bite(t.x, t.y, '#7a1f2b', 6, 0.2) end end)
add2('clawstorm', function(B, e, t, c) for _, o in ipairs(foesNear(c, e.x, e.y, 30, 6)) do R.claws(o.x, o.y, (o.x > e.x) and 1 or -1, '#ff7a3a', '#ffffff', rand(0, 0.15)) end end)
add2('tigerroar', function(B, e, t, c) P.rays(e.x, e.y - 6, '#ffa53a', '#ffd27a', 28, 14, 0.45); FX.particle(e.x, e.y + 5, '#c9b08a', 12, 60, 60, 0.4) end)
-- —— 巨熊 ——
add2('quake', function(B, e, t, c) R.spikes(e.x, e.y, sp(ROCK, { n = 10, ringR = 18, h = 8 })) end)
add2('doomstomp', function(B, e, t, c) R.spikes(e.x, e.y, sp(ROCK, { n = 14, ringR = 30, h = 12, col = '#4a2a1a', col2 = '#ff5a3a', tip = '#ffb03a' })); R.spikes(e.x, e.y, sp(ROCK, { n = 8, ringR = 16, h = 9, delay = 0.1 })) end)
add2('frostroar', function(B, e, t, c) R.spikes(e.x, e.y, sp(ICE, { n = 12, ringR = 26, h = 11 })); R.flutter(e.x, e.y, '#ffffff', '#bff4ff', { n = 18, r = 40, drift = 12 }) end)
add2('hibernate', function(B, e, t, c) R.flutter(e.x, e.y, '#ffffff', '#bcd0ff', { n = 14, r = 18, fall = 16 }) end)
SIG.landslide[3] = function(B, e, t, c)
    for i = 0, 3 do
        local x, y = c.tx + rand(-14, 14), c.ty + rand(-8, 8)
        R.meteor(x, y, { r = 4, col = '#a89878', col2 = '#c9b08a', rock = '#5a4a38', fire = false, dx = -10, delay = i * 0.1 })
        P.ring(x, y, 2, 12, '#a89878', { thick = 2, dur = 0.35, delay = 0.38 + i * 0.1 })
    end
    P.disk(c.tx, c.ty, 16, 16, '#3a2a1a', 0.9, 0.3); FX.quake(c.tx, c.ty)
end
add2('bearhug', function(B, e, t, c) if t then R.claws(t.x, t.y, e.face, '#c9955a', '#ffffff'); R.claws(t.x, t.y, -e.face, '#c9955a', '#ffffff', 0.1) end end)
add2('frenzy', function(B, e, t, c) R.flames(e.x, e.y, { n = 5, r = 6, h = 7, dur = 1.0 }) end)
add2('ironwall', function(B, e, t, c) R.spikes(e.x, e.y, { n = 6, ringR = 11, h = 7, w = 3, col = '#5a6478', col2 = '#c9d2e0', tip = '#ffffff' }) end)
add2('bulwark', function(B, e, t, c) R.wings(e, '#8ab4dc', '#ffffff', 0.9) end)
-- —— 食人花 ——
add2('spore', function(B, e, t, c) R.bubbles(c.tx, c.ty, '#9be36b', '#c4f05a', { n = 10, r = 14 }) end)
add2('plague', function(B, e, t, c) eachFoe(c, 10, function(o) R.bubbles(o.x, o.y, '#9a5ae0', '#9be36b', { n = 4, r = 4 }) end) end)
SIG.devour[3] = function(B, e, t, c)
    local x, y = c.tx, c.ty
    R.bite(x, y, '#2f7a34', 9); R.roots(x, y, { n = 3, r = 5, h = 8, col = '#2f7a34', col2 = '#4fbf4a', leaf = '#ff4a3a' })
    P.star(x, y - 4, '#ff4a3a', '#9be36b', 8, 0.3, 0.25)
end
add2('bloodthorn', function(B, e, t, c) eachFoe(c, 10, function(o) R.spikes(o.x, o.y, sp(BLOODT, { n = 4, r = 5, h = 12 })); R.vine(o, { col = '#4c1b2f', col2 = '#d8433a', leaf = '#ff8e6a' }) end) end)
add2('infest', function(B, e, t, c) for _, o in ipairs(foesNear(c, c.tx, c.ty, 30, 6)) do R.bubbles(o.x, o.y, '#b0e05a', '#ffffff', { n = 4, r = 4 }) end end)
add2('venomrush', function(B, e, t, c) R.vine(e, { col = '#2f7a34', col2 = '#9be36b', leaf = '#e6ff6a', dur = 1.2 }) end)
add2('poisoncloud', function(B, e, t, c) R.bubbles(c.tx, c.ty, '#c06bff', '#9be36b', { n = 14, r = 18, dur = 1.4 }); R.steam(c.tx, c.ty, 16, '#7a5a9e') end)
add2('entangle', function(B, e, t, c)
    R.roots(c.tx, c.ty, { n = 5, r = 14, h = 10, col = '#2f7a34', col2 = '#4fbf4a' })
    for _, o in ipairs(foesNear(c, c.tx, c.ty, 30, 6)) do R.vine(o, { dur = 1.3 }) end
end)
add2('virulence', function(B, e, t, c) for o in of(c.foes) do if o.poison or o == t then R.bubbles(o.x, o.y, '#e6ff6a', '#ffffff', { n = 5, r = 5, dur = 0.6 }) end end end)
add2('seedling', function(B, e, t, c) R.roots(e.x + e.face * 12, e.y, { n = 3, r = 4, h = 8, col = '#2f7a34', col2 = '#4fbf4a', leaf = '#ff6a8a' }); R.flutter(e.x, e.y, '#9be36b', '#4fbf4a', { n = 8, r = 12 }) end)
-- —— 向日葵 ——
add2('sunburst', function(B, e, t, c) R.flutter(e.x, e.y, '#ffe14a', '#fff6b0', { n = 12, r = 30 }) end)
add2('heal', function(B, e, t, c) R.rain(e.x, e.y, { n = 10, r = 40, style = 'star', col = '#fff3b0', col2 = '#ffffff', slant = 0 }) end)
add2('bloom', function(B, e, t, c) R.flutter(e.x, e.y, '#ff8ab8', '#ffd0e6', { n = 24, r = 60, fall = 30, dur = 1.6 }) end)
add2('cleanse', function(B, e, t, c) R.wings(e, '#dcf0ff', '#ffffff', 0.9) end)
add2('sunward', function(B, e, t, c) for o in of(c.allies) do P.shield(o, '#fff6b0', o.big and 14 or 9) end end)
add2('sunshield', function(B, e, t, c) for o in of(c.allies) do R.flutter(o.x, o.y, '#ffb04a', '#ffe14a', { n = 3, r = 6, fall = 10 }) end end)
add2('solarflare', function(B, e, t, c) eachFoe(c, 8, function(o) R.flames(o.x, o.y, { n = 3, r = 4, h = 7, dur = 0.9 }) end) end)
add2('thornfield', function(B, e, t, c) R.spikes(e.x, e.y, sp(THORN, { n = 12, ringR = 24, h = 10 })); R.spikes(e.x, e.y, sp(THORN, { n = 7, ringR = 12, h = 8, delay = 0.1 })) end)
add2('moonlight', function(B, e, t, c) R.flutter(128, 60, '#e4f2ff', '#78a0ff', { n = 24, r = 110, fall = 50, dur = 1.4 }) end)
add2('rebirth', function(B, e, t, c) R.wings(e, '#ff8e6a', '#ffe14a', 1.3); eachFoe(c, 8, function(o) R.flames(o.x, o.y, { n = 3, r = 4, h = 7, dur = 0.9 }) end) end)
-- —— 雷鹰 ——
add2('thunderstorm', function(B, e, t, c) for i = 0, 3 do P.bolt(c.tx + rand(-14, 14), c.ty + rand(-6, 6), '#78a8f2', '#ffffff', 0.15 + i * 0.12) end end)
add2('featherstorm', function(B, e, t, c) local pts = {}; eachFoe(c, 10, function(o) pts[#pts + 1] = { o.x, o.y } end); R.rain(0, 0, { pts = pts, style = 'feather', col = '#ff8a7a', col2 = '#ffffff', slant = 12, dur = 0.8 }) end)
add2('divebomb', function(B, e, t, c) if t then R.claws(t.x, t.y, e.face, '#ffe680', '#ffffff'); R.rain(t.x, t.y, { n = 4, r = 6, style = 'feather', col = '#ffe680', col2 = '#ffffff' }) end end)
add2('flameraid', function(B, e, t, c) if t then local dx, dy = t.x - e.x, t.y - e.y; local d = max(1, hypot(dx, dy)); for i = 1, 5 do R.flames(e.x + dx / d * i * 22, e.y + dy / d * i * 22, { n = 2, r = 3, h = 7, dur = 0.9 }).delay = i * 0.04 end end end)
add2('tailwind', function(B, e, t, c) R.flutter(e.x, e.y, '#bff4ff', '#ffffff', { n = 16, r = 50, fall = 4, drift = 30 }) end)
add2('crimsonstorm', function(B, e, t, c) eachFoe(c, 10, function(o, i) P.bolt(o.x, o.y, '#ff3434', '#ffe14a', i * 0.05) end) end)
add2('skyfury', function(B, e, t, c) local i = 0; for o in of(c.foes) do if i < 6 then P.bolt(o.x, o.y, '#ffe14a', '#ffffff', i * 0.08); i = i + 1 end end end)
add2('galestrike', function(B, e, t, c) if t then R.rain(t.x, t.y, { n = 4, r = 6, style = 'feather', col = '#9ff6ff', col2 = '#ffe14a', fall = 0.2 }) end end)
-- —— 发条机兵 ——
add2('overload', function(B, e, t, c) R.gears(e); R.steam(e.x, e.y - 4, 16) end)
add2('steamburst', function(B, e, t, c) R.steam(e.x, e.y - 2, 30); R.steam(e.x, e.y - 2, 18) end)
add2('repair', function(B, e, t, c) R.gears(e, '#8fe07a', '#ffe14a'); for o in of(c.allies) do if o.hp < o.maxHp * 0.9 then R.gears(o, '#8fe07a', '#ffffff') end end end)
add2('gearshot', function(B, e, t, c) R.gears(e) end)
add2('artillery', function(B, e, t, c) for i = 0, 2 do R.meteor(c.tx + rand(-12, 12), c.ty + rand(-6, 6), { r = 3, col = '#3a2d52', col2 = '#ff8a2a', rock = '#1b1530', dx = -30, delay = i * 0.12 }) end end)
add2('missilebarrage', function(B, e, t, c) R.steam(e.x, e.y - 6, 12); R.gears(e, '#ffb04a', '#d8433a') end)
add2('magnetpulse', function(B, e, t, c) R.gears(e, '#6ef0ff', '#ffffff') end)
add2('redprotocol', function(B, e, t, c) R.gears(e, '#ff3434', '#ffb04a'); R.steam(e.x, e.y - 4, 20, '#ff8e6a') end)

return true
