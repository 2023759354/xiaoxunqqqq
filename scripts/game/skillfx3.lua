-- ============================================================================
-- 第六次更新：新兵种、新敌人、新首领、兵种限定装备的特效
-- 新动画：音符、声波、五线谱、龙息（扇形火焰 / 寒气）、巨龙俯冲、冰块破碎、极光、
--        暴风雪、侧风、风暴之眼、残影召唤、王座结界、装备触发的闪光
-- 每个新技能都有专属组合，命中反馈（伤害、冻结、护盾、治疗……）由 skillfx 自动叠加
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, sin, cos, sqrt, atan = math.floor, math.ceil, math.max, math.min, math.abs, math.sin, math.cos, math.sqrt, math.atan
local PI, TAU = math.pi, math.pi * 2
local of = js.of

local SIG, D, H = FX.SIG, FX.D, FX.H
local dot, line, disk, band, ring, ease, alphaOf, add = H.dot, H.line, H.disk, H.band, H.ring, H.ease, H.alphaOf, H.add
local nova, blast, shot, zone, heal, roar, quake, summon, curseAt = H.nova, H.blast, H.shot, H.zone, H.heal, H.roar, H.quake, H.summon, H.curseAt
local P, R = FX.P, FX.R
local function px(x, y, w, h, c) actx.fillStyle = c; actx:fillRect(round(x), round(y), w, h) end
local function both(...) local fs = { ... }; return function(...) for _, f in ipairs(fs) do f(...) end end end
local function set(key, c1, c2, f) SIG[key] = { c1, c2, f } end
local function anim(kind, x, y, o) o = o or {}; o.kind = kind; o.x = x; o.y = y; o.layer = o.layer or 1; return add(o) end
local ICE = { col = '#7fd0ff', col2 = '#bff4ff', tip = '#ffffff' }
local CRYSTAL = { col = '#8f4bc4', col2 = '#e0b0ff', tip = '#ffffff' }

-- ---------------------------------------------------------------------------
-- 新动画
-- ---------------------------------------------------------------------------
-- 音符：一个个 ♪ 从施法者身边盘旋升起
local function noteGlyph(x, y, c, big)
    px(x - 1, y, 2, 2, c); px(x + 1, y - 4, 1, 5, c); px(x + 2, y - 4, 1, 1, c); px(x + 3, y - 3, 1, 1, c)
    if big then px(x + 4, y, 2, 2, c); px(x + 5, y - 4, 1, 5, c); px(x + 2, y - 4, 4, 1, c) end
end
D.notes = function(a, k, x, y)
    if not a.list then
        a.list = {}
        for i = 1, a.n or 8 do a.list[i] = { an = (i - 1) / (a.n or 8) * TAU + rand(-0.3, 0.3), r = rand(6, a.r or 16), d = rand(0, 0.25), big = js.random() < 0.3, c = (i % 2 == 0) and (a.col2 or a.col) or a.col } end
    end
    for _, n in ipairs(a.list) do
        local kk = clamp((k - n.d) / (1 - n.d), 0, 1)
        if kk > 0 then
            actx.globalAlpha = alphaOf(a, kk)
            local an = n.an + kk * 2.2
            local rr = n.r * (0.4 + 0.6 * ease(kk))
            noteGlyph(x + cos(an) * rr, y - 6 + sin(an) * rr * 0.45 - kk * (a.rise or 18), n.c, n.big)
        end
    end
end
-- 声波：一圈圈正弦抖动的弧线从施法者向外扩散
D.soundwave = function(a, k, x, y)
    for i = 0, (a.n or 3) - 1 do
        local kk = clamp((k - i * 0.12) / 0.75, 0, 1)
        if kk > 0 then
            actx.globalAlpha = (1 - kk) * 0.9
            local r = 4 + (a.r or 40) * ease(kk)
            local m = max(16, floor(r * 2.2))
            local a0, a1 = a.a0 or -PI, a.a1 or PI
            for j = 0, m do
                local an = a0 + (a1 - a0) * j / m
                local rr = r + sin(an * 6 + G.time * 20) * 1.2
                local f = a.f or 1
                dot(x + cos(an) * rr * f, y - 4 + sin(an) * rr * 0.6, (j % 3 == 0) and (a.col2 or '#ffffff') or a.col)
            end
        end
    end
end
-- 五线谱：一条横贯战场的波浪五线谱，上面跑着音符
D.staff = function(a, k, x, y)
    local al = alphaOf(a, k)
    local W = AW
    local head = W * min(1, k / 0.4)
    for l = 0, 4 do
        actx.globalAlpha = al * 0.7
        for X = 0, floor(head), 2 do dot(X, y + l * 3 + sin(X / 14 + G.time * 4) * 4, a.col) end
    end
    actx.globalAlpha = al
    for i = 0, 7 do
        local X = (i * 37 + k * 140) % W
        if X < head then noteGlyph(X, y + 6 + sin(X / 14 + G.time * 4) * 4 - (i % 3) * 3, (i % 2 == 0) and a.col2 or '#ffffff', i % 3 == 0) end
    end
end
-- 龙息：扇形里一团团往前喷的火焰（或寒气），前锋推进，后面翻滚
D.breath = function(a, k, x, y)
    if not a.list then
        a.list = {}
        for i = 1, a.n or 40 do a.list[i] = { an = rand(-a.half, a.half), d = rand(0, 0.35), sp = rand(0.7, 1.1), s = (js.random() < 0.35) and 2 or 1 } end
    end
    local f = a.f or 1
    for _, p in ipairs(a.list) do
        local kk = clamp((k - p.d) / 0.55, 0, 1)
        if kk > 0 and kk < 1 then
            local dist = a.L * ease(kk) * p.sp
            local X = x + f * cos(p.an) * dist
            local Y = y - 4 + sin(p.an) * dist * 0.7
            actx.globalAlpha = (1 - kk) * 0.95
            local c = (kk < 0.25) and (a.col3 or '#ffffff') or ((kk < 0.6) and a.col2 or a.col)
            local s = p.s + floor(kk * 2)
            px(X - floor(s / 2), Y - floor(s / 2), s, s, c)
        end
    end
    -- 口部的亮光
    if k < 0.5 then actx.globalAlpha = 1 - k * 2; px(x + f * 2 - 1, y - 5, 3, 3, a.col3 or '#ffffff') end
end
-- 巨龙俯冲：地上的影子越来越大，龙的剪影从天上扑下来
local DRAGON = { '....kk......kk....', '...kRRk....kRRk...', '..kRRRRk..kRRRRk..', '.kRRRRRRkkRRRRRRk.', 'kRRRRRRRRRRRRRRRRk', '.kkkRRRRRRRRRRkkk.', '....kRRRRRRRRk....', '.....kRROORRk.....', '......kRRRRk......', '.......kRRk.......', '........kk........' }
D.dragondive = function(a, k, x, y)
    local fall = 0.45
    local p = ease(min(1, k / fall))
    if k < fall + 0.05 then
        actx.globalAlpha = 0.35 * p
        disk(x, y + 4, 6 + 16 * p, 0.4, '#1b1530')
        local sc = 1
        local X, Y = x - 9 - (1 - p) * 60, y - 14 - (1 - p) * 90
        actx.globalAlpha = 1
        for r, row in ipairs(DRAGON) do
            for c = 1, #row do
                local ch = row:sub(c, c)
                if ch ~= '.' then px(X + (c - 1) * sc, Y + (r - 1) * sc, sc, sc, (ch == 'k') and '#1b1530' or ((ch == 'O') and '#ffe14a' or a.col)) end
            end
        end
    else
        local q = (k - fall) / (1 - fall)
        actx.globalAlpha = (1 - q) * 0.8
        band(x, y + 4, 6 + q * 36, 2, 0.5, a.col2)
        band(x, y + 4, 4 + q * 24, 1, 0.5, '#ffffff')
    end
end
-- 冰块碎裂：一片片冰晶往外飞
D.shatter = function(a, k, x, y)
    if not a.list then a.list = {}; for i = 1, a.n or 12 do local an = rand(0, TAU); a.list[i] = { c = cos(an), s = sin(an), v = rand(10, a.v or 26), l = (js.random() < 0.5) and 2 or 1 } end end
    for _, s in ipairs(a.list) do
        actx.globalAlpha = 1 - k
        local X, Y = x + s.c * s.v * ease(k), y - 6 + s.s * s.v * 0.7 * ease(k) + k * k * 10
        px(X, Y, s.l, 1, a.col); px(X, Y - 1, 1, 1, '#ffffff')
    end
end
-- 极光：天上一道道彩色帷幕摇曳
D.aurora = function(a, k, x, y)
    local al = alphaOf(a, k)
    local cols = { '#8affc8', '#6ef0ff', '#b48cf0', '#ff8ac8' }
    for X = 0, AW - 1, 2 do
        local h = 10 + 8 * sin(X / 17 + G.time * 2) + 4 * sin(X / 7 - G.time * 3)
        local c = cols[(floor(X / 24 + G.time) % 4) + 1]
        actx.globalAlpha = al * 0.45
        px(X, 8, 2, max(1, round(h)), c)
        actx.globalAlpha = al * 0.8
        px(X, 8 + round(h), 2, 1, '#ffffff')
    end
end
-- 侧风：一条条横向的风线扫过全场
D.gust = function(a, k, x, y)
    if not a.list then a.list = {}; for i = 1, 18 do a.list[i] = { y = rand(14, FIELD_H - 6), ph = rand(0, 1), L = rand(8, 22), sp = rand(0.8, 1.4) } end end
    local al = alphaOf(a, k)
    for _, w in ipairs(a.list) do
        local t = (k * 4 * w.sp + w.ph) % 1
        local X = (a.dir > 0) and (-30 + t * (AW + 60)) or (AW + 30 - t * (AW + 60))
        actx.globalAlpha = al * 0.7
        for i = 0, w.L - 1, 1 do
            local xx = X - a.dir * i
            dot(xx, w.y + sin((xx + G.time * 60) / 9) * 1.5, (i < 3) and '#ffffff' or '#cfe8ff')
        end
    end
end
-- 召唤残影：紫色的烟柱 + 眼睛一亮
D.echo = function(a, k, x, y)
    local al = alphaOf(a, k)
    for i = 0, 9 do
        local t = (k * 1.4 + i / 10) % 1
        actx.globalAlpha = al * (1 - t)
        px(x - 6 + (i * 5) % 13, y + 4 - t * 30, 2, 2, (i % 2 == 0) and '#5a4a86' or '#c06bff')
    end
    if k > 0.3 and k < 0.7 then actx.globalAlpha = 1; px(x - 3, y - 12, 2, 1, '#ff3434'); px(x + 2, y - 12, 2, 1, '#ff3434') end
end
-- 王座结界：一个旋转的血色六边形罩子
D.barrier = function(a, k, x, y)
    local e = a.ent
    if not e or e.dead or not e.barrier then return end
    local r = 18 + sin(G.time * 4) * 1.5
    actx.globalAlpha = 0.85
    for i = 0, 5 do
        local a0 = i / 6 * TAU + G.time * 0.8
        local a1 = (i + 1) / 6 * TAU + G.time * 0.8
        line(x + cos(a0) * r, y - 8 + sin(a0) * r * 0.8, x + cos(a1) * r, y - 8 + sin(a1) * r * 0.8, (i % 2 == 0) and '#ff3434' or '#ffe14a')
    end
    actx.globalAlpha = 0.12; disk(x, y - 8, r, 0.8, '#ff3434')
    -- 柱子到首领的连线
    actx.globalAlpha = 0.5
    if e.pillars then for p in of(e.pillars) do if not p.dead and floor(G.time * 10 + p.x) % 3 ~= 0 then line(p.x, p.y - 8, x, y - 8, '#a8102a') end end end
end
-- 装备触发：一圈小星星绕身旋转后上升
D.proc = function(a, k, x, y)
    actx.globalAlpha = alphaOf(a, k)
    for i = 0, 5 do
        local an = i / 6 * TAU + k * 5
        local rr = 9 * (1 - k * 0.4)
        local X, Y = x + cos(an) * rr, y - 6 + sin(an) * rr * 0.5 - k * 10
        px(X, Y, 1, 1, (i % 2 == 0) and a.col or a.col2)
        if i % 3 == 0 then px(X - 1, Y, 3, 1, a.col2); px(X, Y - 1, 1, 3, a.col2) end
    end
end
-- 寒意凝结：冰晶在单位身上一圈圈结出
D.frostbite = function(a, k, x, y)
    actx.globalAlpha = alphaOf(a, k)
    for i = 0, 7 do
        local an = i / 8 * TAU
        local rr = 7 * ease(min(1, k * 2))
        local X, Y = x + cos(an) * rr, y - 6 + sin(an) * rr * 0.8
        px(X, Y, 1, 1, '#ffffff'); if i % 2 == 0 then px(X - 1, Y, 3, 1, '#bff4ff') end
    end
end

-- ---------------------------------------------------------------------------
-- 供逻辑层调用的特效
-- ---------------------------------------------------------------------------
function FX.iceShatter(x, y, big, col)
    if REDUCED then return end
    anim('shatter', x, y, { col = col or '#bff4ff', n = big and 18 or 12, v = big and 34 or 24, dur = 0.6 })
    R.spikes(x, y, { n = big and 8 or 5, ringR = big and 12 or 8, h = 8, w = 3, col = (col and CRYSTAL.col) or ICE.col, col2 = (col and CRYSTAL.col2) or ICE.col2, tip = '#ffffff', dur = 0.6 })
end
function FX.blizzard(dur)
    if REDUCED then return end
    R.flutter(128, 30, '#ffffff', '#bff4ff', { n = 40, r = 130, fall = 90, drift = 40, dur = dur or 4 })
    anim('gust', 0, 0, { dir = 1, dur = dur or 4, layer = 1 })
end
function FX.gust(dir, dur) if not REDUCED then anim('gust', 0, 0, { dir = dir, dur = dur or 4, layer = 1 }) end end
function FX.leap(x0, y0, x1, y1, col)
    if REDUCED then return end
    for i = 0, 4 do local k = i / 4; P.star(x0 + (x1 - x0) * k, y0 + (y1 - y0) * k - sin(k * PI) * 30, col, '#ffffff', 5, 0.3, i * 0.04) end
    P.ring(x1, y1, 2, 18, col, { thick = 2, dur = 0.4 }); R.flutter(x1, y1, '#ffe680', '#ffffff', { n = 8, r = 10, dur = 0.8 })
end
function FX.stormEye(x, y)
    if REDUCED then return end
    P.vortex(x, y - 6, 70, '#cfe8ff', '#ffffff', -1, true, 0.9)
    P.vortex(x, y - 6, 44, '#78a8f2', '#ffe14a', 1, true, 0.8)
    for i = 0, 4 do P.bolt(x + rand(-60, 20), y + rand(-30, 30), '#ffe14a', '#ffffff', i * 0.08) end
end
function FX.breath(e, f, L, half, col, col2, col3)
    if REDUCED then return end
    anim('breath', e.x + f * 6, e.y, { f = f, L = L, half = half, col = col, col2 = col2, col3 = col3, n = 72, dur = 0.9 })
end
function FX.chainPts(pts, col, col2)
    if REDUCED then return end
    local list = {}
    for p in of(pts) do list[#list + 1] = { p[0], p[1] } end
    R.chain(list, col, col2)
    for i = 2, #list do P.star(list[i][1], list[i][2], col, col2, 6, 0.3, i * 0.04) end
end
function FX.equipProc(e, col, col2)
    if REDUCED then return end
    add({ kind = 'proc', ent = e, col = col, col2 = col2 or '#ffffff', dur = 0.7, layer = 1 })
end

-- ---------------------------------------------------------------------------
-- 吟游诗人
-- ---------------------------------------------------------------------------
local function songAura(c1, c2, R0) return function(B, e, t, c)
    anim('notes', e.x, e.y, { n = 10, r = R0 or 18, col = c1, col2 = c2, dur = 1.1 })
    anim('soundwave', e.x, e.y, { r = R0 and R0 * 2 or 40, n = 3, col = c1, col2 = c2, dur = 0.8 })
    for o in of(c.allies) do if o ~= e then anim('notes', 0, 0, { ent = o, n = 3, r = 6, col = c1, col2 = c2, rise = 12, dur = 0.8 }) end end
end end
set('battlesong', '#ff8ac8', '#ffe680', both(songAura('#ff8ac8', '#ffe680'), function(B, e, t, c)
    for o in of(c.allies) do P.arrows(o, '#ff8ac8', '#ffe680', 1) end
end))
set('encore', '#7fd36a', '#ffd84a', both(songAura('#7fd36a', '#ffd84a', 14), function(B, e, t, c)
    for o in of(c.allies) do if o ~= e and o.skill then P.beam(e.x, e.y - 6, o.x, o.y - 6, '#ffd84a', 1, 0.3) end end
end))
set('warhymn', '#ff6a4a', '#ffe14a', both(songAura('#ff6a4a', '#ffe14a', 20), function(B, e, t, c)
    P.pillar(e.x, e.y, '#ff6a4a', '#ffe14a', 40, 9, 0.6)
    for o in of(c.allies) do R.flames(o.x, o.y, { n = 3, r = 4, h = 6, dur = 0.8 }) end
end))
set('lullaby', '#b48cf0', '#e4f2ff', function(B, e, t, c)
    anim('notes', e.x, e.y, { n = 8, r = 14, col = '#b48cf0', col2 = '#e4f2ff', dur = 1.2 })
    P.sky(e.x + 20, 18, '#e4f2ff', '#b48cf0', true, 7, 1.2)
    for o in of(c.foes) do if (o.sleepT or 0) > 0 then P.beam(e.x, e.y - 6, o.x, o.y - 6, '#b48cf0', 1, 0.5); anim('notes', 0, 0, { ent = o, n = 4, r = 6, col = '#e4f2ff', col2 = '#b48cf0', rise = 10, dur = 1.0 }) end end
end)
set('saga', '#9fdcff', '#ffffff', both(songAura('#9fdcff', '#ffffff', 20), function(B, e, t, c)
    R.wings(e, '#9fdcff', '#ffffff', 1.0)
    for o in of(c.allies) do P.shield(o, '#9fdcff') end
end))
set('dissonance', '#c06bff', '#6ef0ff', function(B, e, t, c)
    anim('soundwave', e.x, e.y, { r = 120, n = 4, col = '#c06bff', col2 = '#6ef0ff', dur = 0.9, a0 = -1.3, a1 = 1.3, f = e.face })
    for o in of(c.foes) do P.xslash(o.x, o.y, '#c06bff', '#6ef0ff', 5); P.converge(o.x, o.y - 4, '#6ef0ff', 5, 8) end
    B.tint = { t = 0.3, max = 0.3, rgb = '150,60,220' }
end)
set('symphony', '#ffe680', '#ffffff', function(B, e, t, c)
    anim('staff', 0, 22, { col = '#ffe680', col2 = '#ff8ac8', dur = 1.6 })
    songAura('#ffe680', '#ffffff', 22)(B, e, t, c)
    P.pillar(e.x, e.y, '#ffe680', '#ffffff', 60, 12, 0.8)
    for o in of(c.allies) do P.arrows(o, '#ffe680', '#ffffff', 1) end
end)
set('requiem', '#e4f2ff', '#78a8f2', function(B, e, t, c)
    anim('staff', 0, 18, { col = '#e4f2ff', col2 = '#78a8f2', dur = 1.4 })
    P.sky(128, 16, '#e4f2ff', '#78a8f2', true, 9, 1.2)
    local i = 0
    for o in of(c.foes) do if i < 10 then P.pillar(o.x, o.y, '#e4f2ff', '#78a8f2', 30, 5, 0.5, i * 0.04); i = i + 1 end end
end)
set('bloodopera', '#ff3434', '#ffe14a', function(B, e, t, c)
    anim('staff', 0, 20, { col = '#ff3434', col2 = '#ffe14a', dur = 1.5 })
    anim('soundwave', e.x, e.y, { r = 140, n = 4, col = '#ff3434', col2 = '#ff8e6a', dur = 1.0 })
    for o in of(c.foes) do P.xslash(o.x, o.y, '#ff3434', '#ffffff', 6) end
    for o in of(c.allies) do R.flames(o.x, o.y, { n = 3, r = 4, h = 7, dur = 0.8 }) end
end)

-- ---------------------------------------------------------------------------
-- 幼龙
-- ---------------------------------------------------------------------------
set('dragonbreath', '#ff8a2a', '#ffe14a', function(B, e, t, c)
    FX.breath(e, e.face, 54, 0.62, '#d8433a', '#ff8a2a', '#ffe14a')
    for o in of(c.foes) do if o.burn then R.flames(o.x, o.y, { n = 3, r = 4, h = 7, dur = 0.8 }) end end
end)
set('flamespit', '#ff8a2a', '#ffe14a', both(shot, function(B, e, t, c) P.rays(e.x + e.face * 6, e.y - 5, '#ff8a2a', '#ffe14a', 10, 8, 0.3) end))
set('emberrain', '#ffb04a', '#ffe680', function(B, e, t, c)
    P.sky(c.tx, 14, '#ff5a2a', '#ffe14a', false, 7, 0.9)
    R.flutter(c.tx, c.ty, '#ff8a2a', '#ffe14a', { n = 14, r = 30, fall = 40, dur = 1.0 })
end)
set('jadescale', '#6fdc8a', '#e6ffd6', function(B, e, t, c)
    for o in of(c.allies) do if (o.ccShield or 0) > 2 then P.shield(o, '#6fdc8a', o.big and 15 or 11); P.rays(o.x, o.y - 6, '#6fdc8a', '#e6ffd6', 10, 8, 0.4) end end
    P.ring(e.x, e.y, 4, 26, '#6fdc8a', { thick = 2, dur = 0.5 })
end)
set('frostbreath', '#bff4ff', '#ffffff', function(B, e, t, c)
    FX.breath(e, e.face, 54, 0.62, '#6ec8ff', '#bff4ff', '#ffffff')
    R.flutter(e.x + e.face * 28, e.y, '#ffffff', '#bff4ff', { n = 12, r = 22, fall = 20, dur = 1.0 })
end)
set('shadowflame', '#c06bff', '#ff3b3b', function(B, e, t, c)
    for o in of(c.foes) do
        if o.curse then
            R.flames(o.x, o.y, { n = 4, r = 5, h = 9, dur = 0.9 })
            P.beam(e.x, e.y - 6, o.x, o.y - 4, '#8f4bc4', 2, 0.35); P.vortex(o.x, o.y - 4, 8, '#8f4bc4', '#ff3b3b', -1, true, 0.5)
        end
    end
end)
set('dragonfall', '#ff6a3a', '#ffe14a', function(B, e, t, c)
    local at = DRAGONFALL_AT or { x = c.tx, y = c.ty }
    anim('dragondive', at.x, at.y, { col = '#d8433a', col2 = '#ff8a2a', dur = 1.0 })
    R.flames(at.x, at.y, { n = 12, r = 26, h = 12, dur = 1.6, delay = 0.45 })
    P.ring(at.x, at.y, 4, 40, '#ff8a2a', { thick = 3, dur = 0.5, delay = 0.45 })
    for i = 0, 5 do local an = i / 6 * TAU; P.beam(at.x, at.y, at.x + cos(an) * 34, at.y + sin(an) * 18, '#ffe14a', 1, 0.4) end
end)
set('goldenbreath', '#ffe680', '#ffffff', function(B, e, t, c)
    if t then local dx, dy = t.x - e.x, t.y - e.y; local d = max(1, hypot(dx, dy)); P.beam(e.x, e.y - 4, e.x + dx / d * 260, e.y - 4 + dy / d * 260, '#ffe680', 5, 0.4) end
    R.wings(e, '#ffe680', '#ffffff', 1.0)
    for o in of(c.allies) do P.shield(o, '#ffe680') end
end)
set('apocalypse', '#ff3434', '#ffb04a', function(B, e, t, c)
    P.sky(128, 14, '#7a1f2b', '#ff3434', false, 11, 1.2)
    local i = 0
    for o in of(c.foes) do
        if i < 12 then R.meteor(o.x, o.y, { r = 3, col = '#ff3434', col2 = '#ffb04a', dx = 30, delay = i * 0.05 }); R.flames(o.x, o.y, { n = 3, r = 5, h = 8, dur = 1.0, delay = 0.4 }); i = i + 1 end
    end
end)

-- ---------------------------------------------------------------------------
-- 冰霜元素
-- ---------------------------------------------------------------------------
set('icenova', '#bff4ff', '#ffffff', function(B, e, t, c)
    P.ring(e.x, e.y, 4, 38, '#bff4ff', { thick = 3, dur = 0.5 })
    R.spikes(e.x, e.y, { n = 10, ringR = 22, h = 10, w = 4, col = ICE.col, col2 = ICE.col2, tip = ICE.tip, dur = 1.0 })
    R.flutter(e.x, e.y, '#ffffff', '#bff4ff', { n = 12, r = 30, dur = 1.0 })
end)
set('iceshard', '#bff4ff', '#ffffff', both(shot, function(B, e, t, c) P.rays(e.x + e.face * 6, e.y - 4, '#bff4ff', '#ffffff', 10, 8, 0.3) end))
set('iceblock', '#7fb0e0', '#ffffff', function(B, e, t, c)
    R.spikes(e.x, e.y, { n = 7, ringR = 9, h = 12, w = 4, col = ICE.col, col2 = ICE.col2, tip = ICE.tip, dur = 2.0 })
    P.shield(e, '#bff4ff', 13)
end)
set('blizzardcall', '#e8f8ff', '#9fdcff', function(B, e, t, c)
    P.sky(c.tx, 14, '#c9d2e0', '#ffffff', true, 8, 1.0)
    R.flutter(c.tx, c.ty, '#ffffff', '#bff4ff', { n = 18, r = 28, fall = 40, drift = 12, dur = 1.4 })
end)
set('glacialslam', '#6ec8ff', '#ffffff', function(B, e, t, c)
    if t then
        R.meteor(t.x, t.y, { r = 5, col = '#9fdcff', col2 = '#ffffff', rock = '#3a8ad8', fire = false, dx = 20 })
        R.spikes(t.x, t.y, { n = 9, ringR = 16, h = 11, w = 4, col = ICE.col, col2 = ICE.col2, tip = ICE.tip, dur = 1.0, delay = 0.25 })
        P.ring(t.x, t.y, 4, 28, '#bff4ff', { thick = 3, dur = 0.5, delay = 0.25 })
    end
end)
set('crystalprison', '#e0b0ff', '#ffffff', function(B, e, t, c)
    for o in of(c.foes) do
        if (o.prisonT or 0) > 0 then
            R.spikes(o.x, o.y, { n = 6, ringR = 7, h = 14, w = 4, col = CRYSTAL.col, col2 = CRYSTAL.col2, tip = CRYSTAL.tip, dur = (o.prisonT or 2) })
            P.beam(e.x, e.y - 6, o.x, o.y - 6, '#e0b0ff', 1, 0.4)
        end
    end
end)
set('absolutezero', '#ffffff', '#6ef0ff', function(B, e, t, c)
    P.clock(128, 70, '#bff4ff', '#ffffff', 46)
    for o in of(c.foes) do R.spikes(o.x, o.y, { n = 4, r = 6, h = 9, w = 3, col = ICE.col, col2 = ICE.col2, tip = ICE.tip, dur = 1.2 }) end
    R.flutter(128, 60, '#ffffff', '#bff4ff', { n = 30, r = 120, fall = 60, dur = 1.6 })
end)
set('aurora', '#8affc8', '#ff8ac8', function(B, e, t, c)
    anim('aurora', 0, 0, { dur = 2.2 })
    for o in of(c.allies) do P.cross(o, '#8affc8') end
end)
set('crimsonfrost', '#ff3434', '#bff4ff', function(B, e, t, c)
    P.sky(128, 14, '#a8102a', '#bff4ff', true, 10, 1.2)
    for o in of(c.foes) do R.spikes(o.x, o.y, { n = 5, r = 7, h = 12, w = 4, col = '#a8102a', col2 = '#bff4ff', tip = '#ffffff', dur = 1.1 }) end
    for o in of(c.allies) do P.shield(o, '#ff8e6a') end
end)

-- ---------------------------------------------------------------------------
-- 新敌人技能
-- ---------------------------------------------------------------------------
set('frostbind', '#bff4ff', '#6ec8ff', function(B, e, t, c)
    local tgt = c.foes:filter(function(o) return (o.frozenT or 0) > 0 end)[0]
    if tgt then R.spikes(tgt.x, tgt.y, { n = 5, ringR = 6, h = 12, w = 4, col = ICE.col, col2 = ICE.col2, tip = ICE.tip, dur = 1.8 }); anim('frostbite', 0, 0, { ent = tgt, dur = 1.0 }) end
end)
set('wyrmbreath', '#bff4ff', '#ffffff', function(B, e, t, c)
    R.flutter(e.x + e.face * 46, e.y, '#ffffff', '#bff4ff', { n = 16, r = 34, fall = 20, dur = 1.0 })
end)
set('chainstorm', '#ffe14a', '#ffffff', function(B, e, t, c) P.sky(e.x, 12, '#5a6478', '#ffe14a', true, 7, 0.7) end)
set('windward', '#e8f8ff', '#ffe680', function(B, e, t, c)
    R.wings(e, '#ffffff', '#ffe680', 1.0)
    for o in of(c.allies) do P.shield(o, '#e8f8ff'); P.vortex(o.x, o.y - 4, 8, '#ffffff', '#bff4ff', 1, false, 0.5) end
end)
set('thunderclap', '#ffe14a', '#78a8f2', function(B, e, t, c) P.sky(128, 12, '#3a4a6a', '#ffe14a', true, 10, 1.2) end)
set('doomhex', '#ff3434', '#4c1b2f', function(B, e, t, c)
    for o in of(c.foes) do if o.curse then P.vortex(o.x, o.y - 4, 9, '#ff3434', '#4c1b2f', -1, true, 0.6); P.star(o.x, o.y - 12, '#ff3434', '#ffe14a', 5) end end
end)
set('doomslash', '#ff3434', '#ffffff', function(B, e, t, c)
    P.arc(e.x + e.face * 6, e.y - 6, e.face, 34, '#ff3434', '#ffffff', 0.38, -1.5, 1.5)
    P.arc(e.x + e.face * 10, e.y - 6, e.face, 26, '#a8102a', '#ff8e6a', 0.38, -1.4, 1.4)
    anim('flashcut', e.x + e.face * 22, e.y - 6, { f = e.face, L = 50, col = '#ff3434', dur = 0.4 })
end)

-- ---------------------------------------------------------------------------
-- 首领机制（FX.skill 给名字）
-- ---------------------------------------------------------------------------
local NAMED = FX.NAMED or {}
local _skill = FX.skill
local MECH = {
    ['凛冬降临'] = function(e)
        P.ring(e.x, e.y, 6, 150, '#bff4ff', { thick = 3, dur = 0.9 })
        R.flutter(128, 40, '#ffffff', '#bff4ff', { n = 40, r = 130, fall = 70, dur = 1.6 })
        for o in of(G.battle and foesOf(G.battle, e) or A()) do R.spikes(o.x, o.y, { n = 4, ringR = 6, h = 10, w = 3, col = ICE.col, col2 = ICE.col2, tip = ICE.tip, dur = 1.5 }) end
    end,
    ['霜龙之怒'] = function(e) P.ring(e.x, e.y, 6, 60, '#bff4ff', { thick = 2, dash = true, dur = 1.0 }); P.vortex(e.x, e.y - 8, 50, '#bff4ff', '#ffffff', -1, true, 1.0); P.pillar(e.x, e.y, '#9fdcff', '#ffffff', 60, 16, 0.8) end,
    ['风暴图腾'] = function(e) P.sky(128, 12, '#3a4a6a', '#ffe14a', true, 10, 1.0); if e.tents2 then for t in of(e.tents2) do P.bolt(t.x, t.y, '#ffe14a', '#ffffff'); P.ring(t.x, t.y, 2, 16, '#ffe14a', { thick = 2 }) end end end,
    ['风暴之眼'] = function(e) FX.stormEye(e.x, e.y); P.pillar(e.x, e.y, '#cfe8ff', '#ffffff', 70, 16, 0.9) end,
    ['俯冲'] = function(e) R.flutter(e.x, e.y, '#ffe680', '#ffffff', { n = 10, r = 12, dur = 0.8 }) end,
    ['冰甲碎裂'] = function(e) FX.iceShatter(e.x, e.y, false) end,
    ['历代残影'] = function(e)
        P.rune(e.x, e.y, 30, '#c06bff', '#ff3434', true, 1.2); P.vortex(e.x, e.y - 10, 30, '#5a4a86', '#c06bff', -1, false, 1.0)
        if G.battle then for o in of(G.battle.ents) do if o.echo and not o.dead then anim('echo', o.x, o.y, { dur = 1.2 }) end end end
    end,
    ['王座结界'] = function(e) add({ kind = 'barrier', ent = e, dur = 16, layer = 1 }); P.pillar(e.x, e.y, '#ff3434', '#ffe14a', 80, 18, 1.0); if e.pillars then for p in of(e.pillars) do P.pillar(p.x, p.y, '#a8102a', '#ff3434', 40, 7, 0.8) end end end,
    ['结界破碎'] = function(e) FX.iceShatter(e.x, e.y, true, '#ff6a8a'); P.star(e.x, e.y - 8, '#ffffff', '#ff3434', 16, 0.5); P.ring(e.x, e.y, 6, 50, '#ffe14a', { thick = 3 }) end,
    ['结界崩塌'] = function(e) P.ring(e.x, e.y, 10, 200, '#ff3434', { thick = 3, dur = 1.0 }); P.ring(e.x, e.y, 6, 140, '#ffe14a', { thick = 1, dur = 0.9, delay = 0.1 }); if G.battle then for o in of(foesOf(G.battle, e)) do P.pillar(o.x, o.y, '#a8102a', '#ff3434', 40, 7, 0.6) end end end,
    ['终焉审判'] = function(e) P.pillar(e.x, e.y, '#ff3434', '#ffe14a', 90, 20, 1.0); R.wings(e, '#ff3434', '#1b1530', 1.4); P.ring(e.x, e.y, 6, 60, '#ff3434', { thick = 3 }) end,
}
function FX.skill(e, name)
    _skill(e, name)
    if REDUCED then return end
    local f = MECH[name]
    if f then local ok, err = pcall(f, e); if not ok then print('[skillfx3] ' .. name .. ': ' .. tostring(err)) end end
end

-- ---------------------------------------------------------------------------
-- 状态外观：冻结 / 水晶牢笼 / 沉睡（画在单位之上）
-- ---------------------------------------------------------------------------
FONT.Z = FONT.Z or A('111', '001', '010', '100', '111')
local _drawHp = drawHp
function drawHp(e)
    _drawHp(e)
    if e.dead then return end
    local h = e.big and 22 or (e.tall and 18 or (e.mid and 15 or 13))
    local w = e.big and 18 or 11
    local x0, y0 = round(e.x - w / 2), round(e.y + 7 - h)
    if (e.frozenT or 0) > 0 or (e.prisonT or 0) > 0 then
        local prison = (e.prisonT or 0) > 0
        local edge, fill = prison and '#e0b0ff' or '#bff4ff', prison and 'rgba(180,120,255,0.28)' or 'rgba(170,225,255,0.3)'
        actx.fillStyle = fill; actx:fillRect(x0, y0, w, h)
        actx.fillStyle = edge
        actx:fillRect(x0, y0, w, 1); actx:fillRect(x0, y0 + h - 1, w, 1); actx:fillRect(x0, y0, 1, h); actx:fillRect(x0 + w - 1, y0, 1, h)
        actx.fillStyle = '#ffffff'; actx:fillRect(x0 + 2, y0 + 2, 1, 3); actx:fillRect(x0 + 3, y0 + 2, 2, 1)
        if prison then actx.fillStyle = edge; actx:fillRect(x0 + floor(w / 2), y0 - 3, 1, 3); actx:fillRect(x0 + 1, y0 - 2, 1, 2); actx:fillRect(x0 + w - 2, y0 - 2, 1, 2) end
    end
    if (e.sleepT or 0) > 0 then
        local k = (G.time * 1.2) % 1
        actx.globalAlpha = 1 - k
        pixText(actx, 'Z', e.x + 5 + k * 3, e.y - 18 - k * 6, '#e0b0ff')
        actx.globalAlpha = 1
    end
    -- 增益光点：攻击增益（红）、攻速增益（金）、减伤增益（蓝）
    if e.bAtk or e.bSpd or e.bDr then
        local ph = G.time * 4 + e.x
        local cols = {}
        if e.bAtk then cols[#cols + 1] = '#ff6a4a' end
        if e.bSpd then cols[#cols + 1] = '#ffe14a' end
        if e.bDr then cols[#cols + 1] = '#9fdcff' end
        for i, c in ipairs(cols) do
            local an = ph + i * 2.1
            actx.fillStyle = c; actx:fillRect(round(e.x + cos(an) * 6), round(e.y - 4 + sin(an) * 3), 1, 1)
        end
    end
end

return true
