-- ============================================================================
-- 第十二次更新：十三个超凡角色的新技能、专属特效和主题光效
-- 以前的超凡技能大多是「全场血色伤害 + 一个附加状态」，招式和特效都差不多（全是红光、血月、血棘）。
-- 现在每个超凡角色的技能都按本兵种的玩法重新设计，并配一套只属于它的像素特效：
--   战士  赤魇剑皇「皇剑轮舞」  6 柄幻剑环绕自身斩击，结束时依次射出；嘲讽 + 减伤（前排）
--   射手  赤月弓神「赤月连珠」  跃上半空，扇形射出 3 支贯穿巨箭并留下月痕（远程精准）
--   法师  血月魔尊「血月坠落」  血月从天而降砸进敌群，再碎成 5 块追击（范围法术）
--   猛虎  血煞魔虎「血煞猎杀」  猎杀状态，扑杀残血，击杀后立刻扑向下一个（刺客连杀）
--   巨熊  赤铠熊魔「熔铠反噬」  嘲讽全场、熔铠减伤并积蓄热量，到时爆裂反噬（坦克反打）
--   食人花 噬魂血棘「噬魂」      抽出全场敌人的魂魄回血，再一口吞掉残血（剧毒 + 吞噬）
--   向日葵 赤阳神葵「日冕天轮」  头顶升起赤阳，每秒治疗全队并灼射敌人；被动「涅槃」复活（治疗）
--   古树  血根古神「古神汲根」  根须连上全场敌人，根植并持续汲取生命（根植 + 自愈）
--   雷鹰  赤雷天鹰「赤雷天翔」  冲上高空盘旋，召下 12 道弹射赤雷（空中远程）
--   机兵  赤钢天机「天机轨道炮」 蓄能后轰出贯穿全场的光束，击碎护盾、击退，蒸汽过载友军（机械火力）
--   诗人  血咏魔音「血咏终章」  四拍音浪：前三拍叠攻击和能量，第四拍高潮震慑（辅助）
--   幼龙  血焰魔龙「炼狱龙息」  腾空纵向掠过敌阵喷火，身后留下一路炼狱火（龙族）
--   冰元素 血霜魔灵「霜狱碎魂」  全场封进冰棺，再从最近的敌人开始连锁碎裂（冻结控场）
-- 光效：超凡的描边、脚下光圈、余烬、降世特效、施法光柱都换成各自的主题色（SUP_THEME），
-- 外圈仍保留一道暗红作为「超凡」的标识
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, atan, sin, cos, sqrt = math.floor, math.ceil, math.max, math.min, math.abs, math.atan, math.sin, math.cos, math.sqrt
local PI, TAU = math.pi, math.pi * 2
local of = js.of

local SIG, D, H, P, R = FX.SIG, FX.D, FX.H, FX.P, FX.R
local add, ease, alphaOf, line, disk, band, ring = H.add, H.ease, H.alphaOf, H.line, H.disk, H.band, H.ring
local X = EXT_SKILLS

-- ---------------------------------------------------------------------------
-- 小工具
-- ---------------------------------------------------------------------------
local function px(x, y, w, h, c) actx.fillStyle = c; actx:fillRect(round(x), round(y), w or 1, h or 1) end
local function anim(kind, x, y, o) o = o or {}; o.kind = kind; o.x = x; o.y = y; o.layer = o.layer or 1; return add(o) end
local function targetable(o) return not o.dead and not o.immune and not o.untargetable end
local function byHpFrac(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end
local function stunT(o, d) if o.dead or o.ccImmune then return end; o.stun = max(o.stun, o.big and d * 0.5 or d) end
local function shieldPct(o, p) if not o.dead then o.shield = min(o.maxHp, (o.shield or 0) + o.maxHp * p) end end
local function centroid(list)
    local x, y, n = 0, 0, 0
    for o in of(list) do x = x + o.x; y = y + o.y; n = n + 1 end
    if n == 0 then return nil end
    return x / n, y / n
end
local function ownField(B, e, kind) for f in of(B.fields) do if f.kind == kind and f.src == e and not f.done then return f end end end
local function fade(k, fin, fout) -- 0→1 淡入 fin、最后 fout 淡出
    local a = 1
    if fin and k < fin then a = k / fin end
    if fout and k > 1 - fout then a = min(a, (1 - k) / fout) end
    return clamp(a, 0, 1)
end
local function spark(x, y, vx, vy, life, color, size, g)
    FX.parts:push({ x = x, y = y, vx = vx, vy = vy, g = g or 0, life = life, max = life, color = color, size = size or 1 })
end

-- ===========================================================================
-- 战士 · 赤魇剑皇「皇剑轮舞」 + 被动「皇者剑意」（每第 3 次普攻挥出剑气）
-- ===========================================================================
X.emperorblades = function(B, e, t)
    strikeAt(e)
    for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 64 then o.target = e end end
    e.guard = { t = 5, dr = 0.3 }
    local old = ownField(B, e, 'bladering')
    if old then old.done = true; old.noLaunch = true end
    local f = { kind = 'bladering', src = e, x = e.x, y = e.y, r = 22, t = 5, max = 5, tick = 0.5, rot = 0 }
    B.fields:push(f)
    if not REDUCED then add({ kind = 'sx_blades', ent = e, f = f, dur = 5.3, layer = 1 }) end
end
local function stepBladering(B, f, dt)
    local e = f.src
    if e.dead or B.over then f.done = true; return end
    f.x, f.y = e.x, e.y
    f.t = f.t - dt; f.tick = f.tick - dt; f.rot = f.rot + dt * 4.2
    if f.tick <= 0 then
        f.tick = f.tick + 0.5
        for o in of(foesOf(B, e)) do
            if hypot(o.x - f.x, (o.y - f.y) * 1.3) <= f.r + o.r then
                hit(e, o, e.atk * 0.45)
                FX.burst(o.x, o.y - 4, '#ff3b3b', 3)
            end
        end
    end
    if f.t <= 0 then
        f.done = true
        if f.noLaunch then return end
        local tg = foesOf(B, e):filter(targetable):sort(function(a, b) return b.hp - a.hp end)
        if #tg > 0 then
            for i = 0, 5 do
                local o = tg[i % #tg]
                local a = f.rot + i / 6 * TAU
                shoot(B, e, o, 'phantomsword', { x = f.x + cos(a) * 16, y = f.y - 7 + sin(a) * 6, speed = 230, delay = i * 0.07, mul = 1.3,
                    stunHit = o.big and 0.25 or 0.5 })
            end
            FX.sound('shoot')
            if not REDUCED then P.ring(f.x, f.y, 4, 26, '#ffd84a', { thick = 2, dur = 0.4 }) end
        end
    end
end
-- 剑气：普攻计数，第 3 下多挥一道贯穿剑气
local _attack = attack
function attack(B, e, t)
    _attack(B, e, t)
    if T(e.swordWave) and not e.proj and not e.dead and t then
        e.swN = (e.swN or 0) + 1
        if e.swN % 3 == 0 then
            local dx, dy = t.x - e.x, t.y - e.y
            local d = hypot(dx, dy)
            if d < 0.01 then dx, dy, d = e.face, 0, 1 end
            shoot(B, e, nil, 'swordwave', { pierce = true, x = e.x + e.face * 4, y = e.y - 4, vx = dx / d, vy = dy / d, ang = atan(dy, dx),
                speed = 190, mul = e.swordWave, hitSet = js.Set() })
        end
    end
end
PIERCE_BURST.swordwave = '#ff3b3b'

-- 环绕的幻剑：竖立的小剑绕着剑皇转，后半圈画淡一点
local function drawUprightSword(x, y, al)
    actx.globalAlpha = al
    px(x, y - 6, 1, 1, '#fff2ea')
    px(x, y - 5, 1, 4, '#ff3b3b'); px(x - 1, y - 4, 1, 3, '#b3142a'); px(x + 1, y - 4, 1, 3, '#ff8e6a')
    px(x - 1, y - 1, 3, 1, '#ffd84a')
    px(x, y, 1, 1, '#5e0b18')
end
D.sx_blades = function(a, k, x, y)
    local f = a.f
    if f.done then return end
    local grow = clamp(a.t / 0.35, 0, 1)
    local R0 = 16 * ease(grow)
    local list = {}
    for i = 0, 5 do
        local an = f.rot + i / 6 * TAU
        list[#list + 1] = { an = an, s = sin(an) }
    end
    table.sort(list, function(p, q) return p.s < q.s end)
    for _, it in ipairs(list) do
        local sx, sy = x + cos(it.an) * R0, y - 3 + sin(it.an) * R0 * 0.4
        local al = (it.s < 0) and 0.55 or 1
        if js.random() < 0.08 then spark(sx, sy - 3, 0, -8, 0.3, '#ff3b3b') end
        drawUprightSword(sx, sy, al * grow)
    end
    actx.globalAlpha = 1
end
FIELD_DRAW.bladering = function(f)
    if f.done then return end
    local a = clamp((f.max - f.t) / 0.3, 0, 1) * clamp(f.t / 0.4, 0, 1)
    actx.globalAlpha = a * 0.45
    ring(f.x, f.y + 6, 18, 0.42, '#ffd84a', true, floor(G.time * 12))
    actx.globalAlpha = a * 0.25
    ring(f.x, f.y + 6, 21, 0.42, '#ff3b3b', false)
    actx.globalAlpha = 1
end
PROJ_DRAW.phantomsword = function(p, c, s)
    local function at(i, col) px(p.x - c * i, p.y - s * i, 1, 1, col) end
    at(0, '#ffffff'); at(1, '#fff2ea'); at(2, '#ff3b3b'); at(3, '#ff3b3b'); at(4, '#b3142a')
    px(p.x - c * 5 - s, p.y - s * 5 + c, 1, 1, '#ffd84a'); at(5, '#ffd84a'); px(p.x - c * 5 + s, p.y - s * 5 - c, 1, 1, '#ffd84a')
    at(6, '#5e0b18')
    if js.random() < 0.6 then spark(p.x - c * 3, p.y - s * 3, rand(-4, 4), rand(-4, 4), 0.25, (js.random() < 0.5) and '#ff3b3b' or '#ffd84a') end
end
PROJ_DRAW.swordwave = function(p, c, s)
    -- 和飞行方向垂直的月牙：中间亮、两端暗
    for j = -3, 3 do
        local back = j * j / 4
        local col = (j == 0) and '#ffffff' or ((abs(j) == 1) and '#fff2ea' or ((abs(j) == 2) and '#ff3b3b' or '#b3142a'))
        px(p.x - c * back - s * j, p.y - s * back + c * j, 1, 1, col)
        if abs(j) <= 2 then px(p.x - c * (back + 1) - s * j, p.y - s * (back + 1) + c * j, 1, 1, '#ff3b3b') end
    end
    if js.random() < 0.5 then spark(p.x - c * 3, p.y - s * 3 + rand(-3, 3), 0, 0, 0.25, '#ff8e6a') end
end
SIG.emperorblades = { '#ffd84a', '#ff3b3b', function(B, e, t, c)
    P.pillar(e.x, e.y, '#ff3b3b', '#ffe680', 46, 10, 0.5)
    P.ring(e.x, e.y, 4, 64, '#ffd84a', { thick = 2, dur = 0.5 })
    P.converge(e.x, e.y - 6, '#ff3b3b', 18, 24)
    for o in of(c.foes) do if hypot(o.x - e.x, o.y - e.y) <= 64 then P.beam(o.x, o.y - 4, e.x, e.y - 4, '#ffd84a', 1, 0.25) end end
end }

-- ===========================================================================
-- 射手 · 赤月弓神「赤月连珠」：跃上半空，扇形射出 3 支贯穿巨箭
-- ===========================================================================
X.lunarvolley = function(B, e, t)
    local ox, oy = e.x, e.y
    local aim = t
    local function fire(B2, e2)
        local tg = (aim and targetable(aim)) and aim or foesOf(B2, e2):filter(targetable)[0]
        local sx, sy = e2.x + e2.face * 5, e2.y - 4
        local tx, ty = tg and tg.x or (sx + e2.face * 60), tg and (tg.y - 3) or sy
        if tg then e2.face = (tg.x >= e2.x) and 1 or -1 end
        local base = atan(ty - sy, tx - sx)
        for i = -1, 1 do
            local an = base + i * 0.2
            shoot(B2, e2, nil, 'moonarrow', { pierce = true, x = sx, y = sy, vx = cos(an), vy = sin(an), ang = an, speed = 330, mul = 2.2,
                hitSet = js.Set(), curse = { t = 5, vuln = 0.25, weak = 0 }, delay = (i == 0) and 0 or 0.05 })
        end
        FX.sound('shoot')
        if not REDUCED then
            P.ring(sx, sy - 6, 2, 14, '#ffe0ec', { thick = 2, dur = 0.3, oy = 0, ry = 1, layer = 1 })
            P.rays(sx, sy, '#ff3b3b', '#ffe0ec', 14, 10, 0.3)
        end
    end
    local ok = startFlight(B, e, {
        { dur = 0.22, to = { ox, oy }, z = 20 },
        { dur = 0.16, to = { ox, oy }, z = 22, fn = fire },
        { dur = 0.30, to = { ox, oy }, z = 18 },
        { dur = 0.16, to = { ox, oy }, z = 0 },
    })
    if not ok then fire(B, e) end
    if not REDUCED then add({ kind = 'sx_moonback', ent = e, dur = 0.9, layer = 0 }) end
end
PIERCE_BURST.moonarrow = '#ff8e6a'
D.sx_moonback = function(a, k, x, y)
    local e = a.ent
    local al = fade(k, 0.2, 0.35)
    local cx, cy = x - e.face * 3, y - 12
    actx.globalAlpha = al * 0.25; disk(cx, cy, 10, 1, '#ff3b3b')
    actx.globalAlpha = al * 0.85; disk(cx, cy, 7, 1, '#b3142a')
    actx.globalAlpha = al; disk(cx + 1, cy - 1, 5, 1, '#ff3b3b'); disk(cx + 2, cy - 2, 2, 1, '#ff8e6a')
    actx.globalAlpha = al * 0.9; ring(cx, cy, 7, 1, '#ffe0ec', true, floor(G.time * 10))
    actx.globalAlpha = 1
end
D.sx_moonmark = function(a, k, x, y)
    local e = a.ent
    if e.dead then return end
    local al = fade(k, 0.05, 0.2)
    local mx, my = x + 4, y - (e.big and 26 or 18)
    actx.globalAlpha = al
    px(mx, my, 2, 1, '#ffe0ec'); px(mx - 1, my + 1, 1, 2, '#ff8e6a'); px(mx, my + 3, 2, 1, '#ffe0ec')
    actx.globalAlpha = 1
end
PROJ_DRAW.moonarrow = function(p, c, s)
    local function at(i, col) px(p.x - c * i, p.y - s * i, 1, 1, col) end
    actx.globalAlpha = 0.35
    for i = 0, 8 do px(p.x - c * i - s, p.y - s * i + c, 1, 1, '#ff3b3b'); px(p.x - c * i + s, p.y - s * i - c, 1, 1, '#ff3b3b') end
    actx.globalAlpha = 1
    at(0, '#ffffff'); at(1, '#ffe0ec'); at(2, '#ffe0ec')
    for i = 3, 8 do at(i, '#ff3b3b') end
    for i = 9, 10 do px(p.x - c * i - s, p.y - s * i + c, 1, 1, '#ffe0ec'); px(p.x - c * i + s, p.y - s * i - c, 1, 1, '#ffe0ec') end
    if js.random() < 0.7 then spark(p.x - c * rand(2, 10), p.y - s * rand(2, 10), 0, 0, 0.3, (js.random() < 0.5) and '#ffe0ec' or '#ff8e6a') end
end
SIG.lunarvolley = { '#ff3b3b', '#ffe0ec', function(B, e, t, c)
    P.ring(e.x, e.y, 3, 20, '#ffe0ec', { thick = 2, dur = 0.4 })
    FX.particle(e.x, e.y + 6, '#c9b08a', 10, 40, 60, 0.4)
end }

-- ===========================================================================
-- 法师 · 血月魔尊「血月坠落」
-- ===========================================================================
X.moonfall = function(B, e, t)
    local cx, cy = centroid(foesOf(B, e):filter(targetable))
    if not cx then cx, cy = t.x, t.y end
    local f = { kind = 'moonfall', src = e, x = cx, y = cy, r = 40, t = 0.9, max = 0.9 }
    B.fields:push(f)
    if not REDUCED then anim('sx_moon', cx, cy, { dur = 0.92, f = f }) end
    B.tint = { t = 1.1, max = 1.1, rgb = '90,10,50' }
end
local function moonImpact(B, f)
    local src = f.src
    for o in of(foesOf(B, src)) do
        if hypot(o.x - f.x, (o.y - f.y) * 1.3) <= f.r + o.r then
            hit(src, o, src.atk * 3.2, { noLeech = true })
            stunT(o, 1)
        end
    end
    local tg = foesOf(B, src):filter(targetable)
    for i = 0, 4 do
        local o = pick(tg)
        if o then shoot(B, src, o, 'moonshard', { x = f.x + rand(-4, 4), y = f.y - 8, speed = 150, delay = 0.08 + i * 0.05, mul = 0.8, burn = { t = 3, dps = src.atk * 0.4 } }) end
    end
    G.shake = max(G.shake, 0.5); FX.sound('die')
    FX.particle(f.x, f.y, '#ff3b3b', 30, 100, 40, 0.7); FX.particle(f.x, f.y + 4, '#5e0b18', 16, 70, 100, 0.6)
    if not REDUCED then
        P.ring(f.x, f.y, 6, 50, '#ff3b3b', { thick = 3, dur = 0.6 })
        P.ring(f.x, f.y, 4, 34, '#c06bff', { thick = 2, dur = 0.5, delay = 0.08 })
        P.disk(f.x, f.y, 6, 30, '#2a0a14', 1.2, 0.45)
        for i = 0, 7 do local an = i / 8 * TAU; P.beam(f.x, f.y + 2, f.x + cos(an) * 40, f.y + 2 + sin(an) * 20, '#ff8e6a', 1, 0.4) end
        P.star(f.x, f.y - 6, '#ffffff', '#ff3b3b', 16, 0.4)
    end
end
local function stepMoonfall(B, f, dt)
    f.t = f.t - dt
    if f.t <= 0 then f.done = true; moonImpact(B, f) end
end
D.sx_moon = function(a, k, x, y)
    local q = k * k -- 越落越快
    local my = -14 + (y - 10 + 14) * q
    local r = 6 + 4 * k
    if js.random() < 0.8 then spark(x + rand(-r, r), my - r + rand(0, 3), rand(-6, 6), -rand(20, 50), 0.35, (js.random() < 0.5) and '#ff3b3b' or '#c06bff') end
    actx.globalAlpha = 0.25; disk(x, my, r + 3, 1, '#ff3b3b')
    actx.globalAlpha = 1
    disk(x, my, r, 1, '#b3142a')
    disk(x + 1, my - 1, r - 1.5, 1, '#ff3b3b')
    disk(x + r * 0.35, my - r * 0.35, r * 0.35, 1, '#ffb0a0')
    disk(x - r * 0.55, my + r * 0.1, r * 0.55, 1, '#5e0b18') -- 月面暗影
    px(x - 2, my + 2, 1, 1, '#7a1f2b'); px(x + 2, my + 1, 2, 1, '#7a1f2b')
    actx.globalAlpha = 1
end
FIELD_DRAW.moonfall = function(f)
    local k = 1 - f.t / f.max
    actx.globalAlpha = 0.12 + 0.3 * k
    disk(f.x, f.y + 4, f.r * (0.4 + 0.6 * k), 0.5, '#2a0a14')
    actx.globalAlpha = 0.6 + 0.4 * k
    ring(f.x, f.y + 4, f.r, 0.5, '#ff3b3b', true, floor(G.time * 14))
    actx.globalAlpha = 0.4 * k
    ring(f.x, f.y + 4, f.r * 0.6, 0.5, '#c06bff', true, floor(-G.time * 10))
    actx.globalAlpha = 1
end
PROJ_DRAW.moonshard = function(p, c, s)
    local x, y = round(p.x), round(p.y)
    px(x - 1, y, 3, 1, '#b3142a'); px(x, y - 1, 1, 3, '#ff3b3b'); px(x, y, 1, 1, '#ffe0ec')
    if js.random() < 0.7 then spark(p.x - c * 3, p.y - s * 3, rand(-3, 3), rand(-3, 3), 0.3, (js.random() < 0.5) and '#ff3b3b' or '#c06bff') end
end
SIG.moonfall = { '#ff3b3b', '#c06bff', function(B, e, t, c)
    P.vortex(e.x, e.y - 10, 14, '#c06bff', '#ff3b3b', 1, true, 0.6)
    P.beam(e.x + e.face * 6, e.y - 12, e.x + e.face * 6, 0, '#ff3b3b', 2, 0.35)
end }

-- ===========================================================================
-- 猛虎 · 血煞魔虎「血煞猎杀」：扑杀 → 击杀后立刻扑向下一个
-- ===========================================================================
local function huntTarget(B, e) return foesOf(B, e):filter(targetable):sort(byHpFrac)[0] end
local function pounce(B, e, tgt, mul)
    if not tgt then return false end
    local ox, oy = e.x, e.y
    local function beside() local dir = (tgt.x >= e.x) and 1 or -1; return tgt.x - dir * (tgt.r + e.r + 1), tgt.y end
    return startFlight(B, e, {
        { dur = 0.1, to = { ox, oy }, z = 3 },
        { dur = 0.22, to = beside, z = 16 },
        { dur = 0.07, to = beside, z = 0, fn = function(B2, e2)
            e2.face = (tgt.x >= e2.x) and 1 or -1; e2.target = tgt
            strikeAt(e2)
            if not tgt.dead then
                hit(e2, tgt, e2.atk * mul, { melee = true, forceCrit = true })
                if not tgt.dead then applyBleed(tgt, e2, 4, e2.atk * 0.6) end
            end
            FX.trail(ox, oy - 4, e2.x, e2.y - 4, '#ff3434')
            FX.burst(tgt.x, tgt.y - 4, '#ff3434', 10)
            if not REDUCED then
                R.claws(tgt.x, tgt.y, e2.face, '#ff3434', '#ffffff')
                R.claws(tgt.x + e2.face * 2, tgt.y - 2, e2.face, '#ffd84a', '#ffffff', 0.06)
                P.ring(tgt.x, tgt.y, 2, 16, '#ff3434', { thick = 2, dur = 0.3 })
            end
            G.shake = max(G.shake, 0.2)
        end },
    })
end
X.bloodhunt = function(B, e, t)
    e.haste = max(e.haste or 0, 6); e.huntT = 6; e.huntN = 3; e.huntQ = false
    if not REDUCED then add({ kind = 'sx_huntaura', ent = e, dur = 6, layer = 0 }) end
    if not pounce(B, e, huntTarget(B, e) or t, 2.6) then hit(e, t, e.atk * 2.6, { melee = true, forceCrit = true }) end
end
addHook('death', function(t, src, B)
    if src and not src.dead and (src.huntT or 0) > 0 and (src.huntN or 0) > 0 and t.side ~= src.side then src.huntQ = true end
end)
D.sx_huntaura = function(a, k, x, y)
    local e = a.ent
    if e.dead or (e.huntT or 0) <= 0 then return end
    local gy = y + (e.flyZ or 0)
    local al = (e.huntT < 0.6) and (e.huntT / 0.6) or 1
    actx.globalAlpha = al * (0.35 + 0.15 * sin(G.time * 12))
    band(x, gy + 7, 9, 2, 0.4, '#ff3434')
    actx.globalAlpha = 1
    if js.random() < 0.6 then spark(x + rand(-6, 6), y + rand(-4, 6), rand(-3, 3), -rand(18, 34), 0.45, pick(A('#ff3434', '#ff8a2a', '#ffd84a'))) end
end
SIG.bloodhunt = { '#ff3434', '#ffd84a', function(B, e, t, c)
    P.ring(e.x, e.y, 4, 30, '#ff3434', { thick = 3, dur = 0.4 })
    P.ring(e.x, e.y, 2, 18, '#ffd84a', { thick = 1, dur = 0.35, delay = 0.08 })
    local tg = c.foes:filter(targetable):sort(byHpFrac)[0]
    if tg then add({ kind = 'ring', ent = tg, dy = -3, r0 = 14, r1 = 3, ry = 1, col = '#ff3434', thick = 1, dur = 0.4, layer = 1 }) end
end }

-- ===========================================================================
-- 巨熊 · 赤铠熊魔「熔铠反噬」
-- ===========================================================================
X.moltenarmor = function(B, e, t)
    strikeAt(e)
    for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 72 then o.target = e end end
    e.guard = { t = 5, dr = 0.5 }
    e.heatT = 5; e.heat = 0
    G.shake = max(G.shake, 0.2)
    if not REDUCED then add({ kind = 'sx_molten', ent = e, dur = 5.1, layer = 1 }) end
end
local function meltBurst(B, e)
    local heat = min(e.heat or 0, e.maxHp * 1.2)
    local dmg = e.atk * 1.5 + heat * 0.5
    for o in of(foesOf(B, e)) do
        if hypot(o.x - e.x, (o.y - e.y) * 1.2) <= 44 + o.r then hit(e, o, dmg, { noLeech = true }); stunT(o, 1.5) end
    end
    B.fields:push({ kind = 'lava', x = e.x, y = e.y + 2, r = 24, t = 3, max = 3, tick = 0.5, src = e, mul = 0.3 })
    e.heat = 0
    FX.skill(e, '熔铠爆裂')
    FX.particle(e.x, e.y - 4, '#ff6a2a', 34, 110, 60, 0.7); FX.particle(e.x, e.y - 4, '#ffd84a', 16, 80, 40, 0.5)
    G.shake = max(G.shake, 0.55); FX.sound('die')
    if not REDUCED then
        P.ring(e.x, e.y, 6, 52, '#ff6a2a', { thick = 3, dur = 0.55 })
        P.ring(e.x, e.y, 4, 36, '#ffd84a', { thick = 2, dur = 0.45, delay = 0.06 })
        R.flames(e.x, e.y, { n = 12, r = 26, h = 11, dur = 1.2 })
        R.spikes(e.x, e.y, { n = 10, ringR = 24, h = 10, col = '#3a3a4a', col2 = '#a8142a', tip = '#ffd84a' })
        P.pillar(e.x, e.y, '#ff6a2a', '#ffd84a', 50, 16, 0.5)
    end
end
D.sx_molten = function(a, k, x, y)
    local e = a.ent
    if e.dead or (e.heatT or 0) <= 0 then return end
    local pulse = 0.5 + 0.5 * sin(G.time * 10)
    -- 熔岩裂纹：身上闪烁的橙色像素
    actx.globalAlpha = 0.55 + 0.35 * pulse
    local cracks = { { -3, -9 }, { -2, -8 }, { 0, -6 }, { 1, -7 }, { 3, -5 }, { -4, -4 }, { -1, -3 }, { 2, -2 }, { 4, -9 }, { 0, -11 } }
    for i, c in ipairs(cracks) do px(x + c[1], y + c[2], 1, 1, (i % 3 == 0) and '#ffd84a' or '#ff6a2a') end
    actx.globalAlpha = 0.3 + 0.2 * pulse
    band(x, y + 7, 11, 2, 0.4, '#ff6a2a')
    -- 头顶的热量条（5 格）
    local fill = clamp((e.heat or 0) / (e.maxHp * 0.6), 0, 1)
    local n = floor(fill * 5 + 0.5)
    local bx, by = round(x - 7), round(y - 27)
    actx.globalAlpha = 1
    px(bx - 1, by - 1, 16, 4, '#1b1530')
    for i = 0, 4 do px(bx + i * 3, by, 2, 2, (i < n) and ((i >= 3) and '#ffd84a' or '#ff6a2a') or '#4a2a2a') end
    if js.random() < 0.5 then spark(x + rand(-7, 7), y + rand(-12, 2), rand(-4, 4), -rand(16, 30), 0.45, (js.random() < 0.6) and '#ff6a2a' or '#ffd84a') end
    actx.globalAlpha = 1
end
SIG.moltenarmor = { '#ff6a2a', '#ffd84a', function(B, e, t, c)
    P.ring(e.x, e.y, 4, 72, '#ff6a2a', { thick = 3, dur = 0.5 })
    P.ring(e.x, e.y, 2, 40, '#ffd84a', { thick = 1, dash = true, dur = 0.5, delay = 0.1 })
    P.shield(e, '#ff6a2a', 14)
    for o in of(c.foes) do if hypot(o.x - e.x, o.y - e.y) <= 72 then P.beam(o.x, o.y - 4, e.x, e.y - 6, '#ff6a2a', 1, 0.3) end end
end }

-- ===========================================================================
-- 食人花 · 噬魂血棘「噬魂」
-- ===========================================================================
X.souldevour = function(B, e, t)
    local dealt, i = 0, 0
    for o in of(foesOf(B, e)) do
        local pois = o.poison and o.poison.n > 0
        dealt = dealt + hit(e, o, e.atk * (pois and 1.8 or 1.2), { noLeech = true })
        if not o.dead then addPoison(o, e, 2) end
        if not REDUCED and i < 12 then add({ kind = 'sx_soul', x = o.x, y = o.y - 6, tgt = e, dur = 0.65, delay = i * 0.04, layer = 1, bend = rand(-18, 18) }); i = i + 1 end
    end
    local al = alliesOf(B, e)
    if #al > 0 and dealt > 0 then
        local each = dealt * 0.3 / #al
        for o in of(al) do healAmt(o, each) end
    end
    local prey = foesOf(B, e):filter(function(o) return targetable(o) and not o.big and o.hp < o.maxHp * 0.35 end):sort(byHpFrac)[0]
    local victim = prey or foesOf(B, e):filter(targetable):sort(byHpFrac)[0]
    if victim then
        if prey then execute(e, prey) else hit(e, victim, e.atk * 2.5, { noLeech = true }) end
        if not REDUCED then
            R.bite(victim.x, victim.y - 4, '#5a1238', victim.big and 12 or 9, 0.15)
            P.vortex(victim.x, victim.y - 4, 14, '#7af0e0', '#e0588a', -1, true, 0.5)
        end
        FX.particle(victim.x, victim.y - 4, '#7af0e0', 12, 50, 10, 0.5)
    end
end
D.sx_soul = function(a, k, x, y)
    local e = a.tgt
    local tx, ty = e.x, e.y - 8
    local q = ease(k)
    local cx, cy = (x + tx) / 2 + a.bend * 0.3, min(y, ty) - 14 + a.bend * 0.2
    local u = 1 - q
    local X0 = u * u * x + 2 * u * q * cx + q * q * tx
    local Y0 = u * u * y + 2 * u * q * cy + q * q * ty
    local al = fade(k, 0.1, 0.15)
    actx.globalAlpha = al * 0.5
    px(X0 - 1, Y0 + 2, 1, 1, '#5ad8d0'); px(X0 + 1, Y0 + 3, 1, 1, '#5ad8d0')
    actx.globalAlpha = al
    px(X0 - 1, Y0 - 1, 3, 3, '#9af0e8'); px(X0, Y0 - 2, 1, 1, '#9af0e8'); px(X0, Y0, 1, 1, '#ffffff')
    px(X0 - 1, Y0 + 2, 1, 1, '#9af0e8'); px(X0 + 1, Y0 + 2, 1, 1, '#9af0e8')
    if js.random() < 0.3 then spark(X0, Y0 + 2, 0, 6, 0.25, '#5ad8d0') end
    actx.globalAlpha = 1
end
PROJ_DRAW.soulorb = function(p, c, s)
    local x, y = round(p.x), round(p.y + sin(G.time * 16) * 0.8)
    px(x - 1, y - 1, 3, 3, '#5a1238'); px(x, y - 1, 1, 1, '#e0588a'); px(x - 1, y, 1, 1, '#e0588a')
    px(x, y, 1, 1, '#9af0e8')
    if js.random() < 0.5 then spark(p.x - c * 3, p.y - s * 3, 0, -4, 0.3, (js.random() < 0.5) and '#9af0e8' or '#e0588a') end
end
SLOW_PROJ:add('soulorb')
PROJ_BURST.soulorb = '#7af0e0'
SIG.souldevour = { '#7af0e0', '#e0588a', function(B, e, t, c)
    P.vortex(e.x, e.y - 6, 26, '#7af0e0', '#d8fff8', -1, true, 0.8)
    R.bite(e.x + e.face * 3, e.y - 6, '#5a1238', 10)
    P.ring(e.x, e.y, 60, 6, '#7af0e0', { thick = 2, dur = 0.6 })
end }

-- ===========================================================================
-- 向日葵 · 赤阳神葵「日冕天轮」 + 被动「涅槃」
-- ===========================================================================
X.solarcrown = function(B, e, t)
    for o in of(alliesOf(B, e)) do o.stun = 0 end
    local old = ownField(B, e, 'sunwheel')
    if old then old.done = true end
    local f = { kind = 'sunwheel', src = e, x = e.x, y = e.y, t = 6, max = 6, tick = 0.3 }
    B.fields:push(f)
    if not REDUCED then add({ kind = 'sx_sun', ent = e, f = f, dy = -27, dur = 6.4, layer = 1 }) end
end
local function stepSunwheel(B, f, dt)
    local e = f.src
    if e.dead or B.over then f.done = true; return end
    f.x, f.y = e.x, e.y
    f.t = f.t - dt; f.tick = f.tick - dt
    if f.tick <= 0 then
        f.tick = f.tick + 1
        for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.05) end
        local tg = foesOf(B, e):filter(targetable)
        for _ = 1, 2 do
            local o = pick(tg)
            if o and not o.dead then
                hit(e, o, e.atk * 1.1, { noLeech = true })
                if not o.dead then applyBurn(o, e, 2, e.atk * 0.4) end
                if not REDUCED then
                    P.beam(e.x, e.y - 27, o.x, o.y - 4, '#ffd84a', 2, 0.3)
                    P.star(o.x, o.y - 4, '#ffd84a', '#ffffff', 8)
                    R.flames(o.x, o.y, { n = 3, r = 4, h = 7, dur = 0.7 })
                end
            end
        end
        if not REDUCED then P.ring(e.x, e.y - 21, 3, 12, '#ffe680', { thick = 1, dur = 0.35, oy = 0, ry = 1, layer = 1 }) end
    end
    if f.t <= 0 then
        f.done = true
        for o in of(alliesOf(B, e)) do shieldPct(o, 0.15) end
        if not REDUCED then P.pillar(e.x, e.y, '#ff6a2a', '#ffe680', 36, 8, 0.5) end
    end
end
D.sx_sun = function(a, k, x, y)
    local f = a.f
    if f.done then return end
    local e = a.ent
    local rise = clamp(a.t / 0.4, 0, 1)
    local sy = y + (1 - ease(rise)) * 14
    local rot = G.time * 1.6
    local r0 = 4
    for i = 0, 11 do
        local an = rot + i / 12 * TAU
        local L = (i % 2 == 0) and 6 or 4
        L = L + sin(G.time * 8 + i) * 0.8
        for d = r0 + 1, r0 + L do
            px(x + cos(an) * d, sy + sin(an) * d, 1, 1, (d > r0 + L - 1.5) and '#ff3b3b' or ((i % 2 == 0) and '#ffd84a' or '#ff8a2a'))
        end
    end
    actx.globalAlpha = 0.3; disk(x, sy, r0 + 3, 1, '#ff8a2a')
    actx.globalAlpha = 1
    disk(x, sy, r0, 1, '#ff6a2a'); disk(x, sy, r0 - 1, 1, '#ffd84a'); disk(x - 1, sy - 1, 1.5, 1, '#fff6b0')
    if js.random() < 0.4 then spark(x + rand(-4, 4), sy + rand(-4, 4), rand(-8, 8), rand(4, 14), 0.5, '#ffe680') end
    actx.globalAlpha = 0.12 + 0.06 * sin(G.time * 6) -- 洒下的光
    for dy = 6, 26, 2 do px(x - dy * 0.35, sy + dy, max(1, round(dy * 0.7)), 1, '#ffe680') end
    actx.globalAlpha = 1
end
SIG.solarcrown = { '#ffd84a', '#ff6a2a', function(B, e, t, c)
    P.pillar(e.x, e.y, '#ff6a2a', '#ffe680', 44, 10, 0.5)
    P.rays(e.x, e.y - 27, '#ffd84a', '#ffffff', 18, 12, 0.5)
    P.ring(e.x, e.y, 4, 34, '#ffd84a', { thick = 2 })
end }
-- 涅槃：每场战斗第一个阵亡的队友 2 秒后浴火重生
addHook('death', function(t, src, B)
    if t.side ~= 'p' or t.minion or B.phoenixUsed then return end
    local sun = nil
    for o in of(B.ents) do
        if T(o.phoenix) and o.side == 'p' and (not o.dead or o == t) then sun = o; break end
    end
    if not sun then return end
    B.phoenixUsed = true
    B.phoenixQ = { ent = t, t = 2, frac = sun.phoenix }
    if not REDUCED then anim('sx_phoenixegg', t.x, t.y, { dur = 2.05, layer = 1 }) end
end)
local function stepPhoenix(B, dt)
    local q = B.phoenixQ
    if not q then return end
    q.t = q.t - dt
    if q.t > 0 then return end
    B.phoenixQ = nil
    local o = q.ent
    if not o.dead or B.over then return end
    revive(o, q.frac)
    FX.skill(o, '涅槃')
    FX.particle(o.x, o.y, '#ff6a2a', 30, 80, 20, 0.8); FX.particle(o.x, o.y, '#ffd84a', 16, 60, 10, 0.6)
    if not REDUCED then
        R.wings(o, '#ff6a2a', '#ffd84a', 1.3)
        P.pillar(o.x, o.y, '#ff6a2a', '#ffe680', 70, 14, 0.8)
        R.flames(o.x, o.y, { n = 8, r = 10, h = 10, dur = 1.0 })
    end
end
D.sx_phoenixegg = function(a, k, x, y)
    local pulse = 0.5 + 0.5 * sin(G.time * (8 + k * 14))
    actx.globalAlpha = 0.35 + 0.4 * pulse
    disk(x, y - 3, 3 + k * 2, 1.3, '#ff6a2a')
    actx.globalAlpha = 0.6 + 0.3 * pulse
    disk(x, y - 3, 1.5 + k, 1.3, '#ffd84a')
    actx.globalAlpha = 1
    if js.random() < 0.6 then spark(x + rand(-4, 4), y + rand(-2, 4), rand(-3, 3), -rand(14, 30), 0.5, (js.random() < 0.5) and '#ff6a2a' or '#ffd84a') end
end

-- ===========================================================================
-- 古树 · 血根古神「古神汲根」
-- ===========================================================================
X.rootsiphon = function(B, e, t)
    local list = foesOf(B, e):filter(targetable)
    for o in of(list) do
        if not o.ccImmune then o.root = max(o.root or 0, o.big and 1.5 or 3) end
        if not REDUCED then R.roots(o.x, o.y, { n = 4, r = 6, h = 10, col = '#4a2f1f', col2 = '#b3142a', leaf = '#ff3b3b', dur = 1.4 }) end
    end
    shieldPct(e, 0.2)
    local old = ownField(B, e, 'siphon')
    if old then old.done = true end
    local L = {}
    for o in of(list) do L[#L + 1] = o end
    B.fields:push({ kind = 'siphon', src = e, list = L, x = e.x, y = e.y, t = 3, max = 3, tick = 0.5 })
end
local function stepSiphon(B, f, dt)
    local e = f.src
    if e.dead or B.over then f.done = true; return end
    f.x, f.y = e.x, e.y
    f.t = f.t - dt; f.tick = f.tick - dt
    if f.tick <= 0 then
        f.tick = f.tick + 0.5
        local tot = 0
        for _, o in ipairs(f.list) do
            if not o.dead and o.side ~= e.side then
                tot = tot + hit(e, o, e.atk * 0.35, { noLeech = true, noCrit = true })
                FX.particle(o.x, o.y - 2, '#ff3b3b', 3, 20, -10, 0.4)
            end
        end
        if tot > 0 then
            local heal = tot * 0.5
            if e.hp < e.maxHp - 1 then healAmt(e, heal) else healLowest(B, e, heal) end
        end
    end
    if f.t <= 0 then f.done = true end
end
FIELD_DRAW.siphon = function(f)
    local e = f.src
    if f.done or e.dead then return end
    local grow = clamp((f.max - f.t) / 0.3, 0, 1)
    local al = clamp(f.t / 0.4, 0, 1)
    local n = 0
    for i, o in ipairs(f.list) do
        if not o.dead and n < 12 then
            n = n + 1
            local x0, y0, x1, y1 = e.x, e.y + 5, o.x, o.y + 5
            local L = hypot(x1 - x0, y1 - y0)
            local steps = max(2, floor(L / 2))
            local nx, ny = -(y1 - y0) / max(1, L), (x1 - x0) / max(1, L)
            local upto = floor(steps * grow)
            actx.globalAlpha = al
            for s = 0, upto do
                local q = s / steps
                local w = sin(q * PI * 3 + i) * 2 * sin(q * PI)
                local X0, Y0 = x0 + (x1 - x0) * q + nx * w, y0 + (y1 - y0) * q + ny * w
                px(X0, Y0, 1, 1, (s % 3 == 0) and '#7a5233' or '#4a2f1f')
            end
            -- 树液：顺着根往古神身上流的红点
            if grow >= 1 then
                for j = 0, 2 do
                    local q = 1 - ((G.time * 1.4 + j / 3 + i * 0.13) % 1)
                    local w = sin(q * PI * 3 + i) * 2 * sin(q * PI)
                    px(x0 + (x1 - x0) * q + nx * w, y0 + (y1 - y0) * q + ny * w - 1, 1, 1, (j == 0) and '#ff8e6a' or '#ff3b3b')
                end
            end
        end
    end
    actx.globalAlpha = 1
end
SIG.rootsiphon = { '#ff3b3b', '#7a5233', function(B, e, t, c)
    R.roots(e.x, e.y, { n = 7, r = 12, h = 14, col = '#4a2f1f', col2 = '#7a5233', leaf = '#ff3b3b' })
    P.ring(e.x, e.y, 4, 44, '#b3142a', { thick = 2, dur = 0.5 })
    P.shield(e, '#ff8e6a', 13)
end }

-- ===========================================================================
-- 雷鹰 · 赤雷天鹰「赤雷天翔」
-- ===========================================================================
local function redBolt(B, e)
    local tg = foesOf(B, e):filter(targetable)
    local o = pick(tg)
    if not o then return end
    hit(e, o, e.atk * 0.9, { noLeech = true })
    if not o.dead and js.random() < 0.3 then stunT(o, 0.5) end
    local o2 = nearestOther(B, e, o.x, o.y, 46, js.Set(A(o)))
    if o2 then
        hit(e, o2, e.atk * 0.45, { noLeech = true })
        if not REDUCED then R.chain({ { o.x, o.y - 4 }, { o2.x, o2.y - 4 } }, '#ff3b3b', '#ffe14a') end
    end
    FX.burst(o.x, o.y - 4, '#ffe14a', 5)
    if not REDUCED then P.bolt(o.x, o.y, '#ff3b3b', '#ffe14a'); P.ring(o.x, o.y, 2, 10, '#ffe14a', { thick = 1, dur = 0.25 }) end
    FX.sound('zap')
end
X.thunderwing = function(B, e, t)
    local ox, oy = e.x, e.y
    local cx, cy = centroid(foesOf(B, e):filter(targetable))
    if not cx then cx, cy = t.x, t.y end
    local hx, hy = clamp((ox + cx) / 2, 30, AW - 30), clamp(cy, 56, FIELD_H - 20)
    local keys = { { dur = 0.32, to = { hx, hy }, z = 40 } }
    for i = 1, 12 do keys[#keys + 1] = { dur = 0.2, to = { hx + sin(i * 1.3) * 6, hy + cos(i * 1.7) * 3 }, z = 40 + sin(i) * 2, fn = redBolt } end
    keys[#keys + 1] = { dur = 0.36, to = { ox, oy }, z = 12 }
    keys[#keys + 1] = { dur = 0.1, to = { ox, oy }, z = 0 }
    if startFlight(B, e, keys) then
        if not REDUCED then anim('sx_stormcloud', hx, 10, { dur = 3.0, layer = 1 }) end
        B.tint = { t = 2.6, max = 2.6, rgb = '40,20,60' }
    else
        for _ = 1, 6 do redBolt(B, e) end
    end
end
D.sx_stormcloud = function(a, k, x, y)
    local al = fade(k, 0.12, 0.2)
    local W = 70
    for i = 0, 13 do
        local cx = x - W / 2 + (i % 7) * (W / 6) + sin(G.time * 1.5 + i) * 3
        local cy = y + floor(i / 7) * 5 + sin(G.time * 2 + i * 0.7) * 1.5
        actx.globalAlpha = al * 0.75
        disk(cx, cy, 6 + (i % 3), 0.55, (i % 2 == 0) and '#2a2438' or '#3a2d52')
    end
    if js.random() < 0.25 then -- 云里的赤色闪光
        actx.globalAlpha = al
        local fx, fy = x + rand(-W / 2, W / 2), y + rand(0, 8)
        px(fx, fy, 1, 3, '#ff3b3b'); px(fx + 1, fy + 2, 1, 2, '#ffe14a')
    end
    actx.globalAlpha = 1
end
SIG.thunderwing = { '#ffe14a', '#ff3b3b', function(B, e, t, c)
    R.wings(e, '#2a2438', '#ffe14a', 0.6)
    P.ring(e.x, e.y, 3, 22, '#ffe14a', { thick = 2, dur = 0.4 })
    FX.particle(e.x, e.y + 6, '#c9b08a', 12, 50, 60, 0.4)
end }

-- ===========================================================================
-- 机兵 · 赤钢天机「天机轨道炮」
-- ===========================================================================
X.railcannon = function(B, e, t)
    if e.rail then return end
    e.rail = { t = 0.8, tgt = t, tx = t.x, ty = t.y, speed = e.speed }
    e.speed = 0
    if not REDUCED then add({ kind = 'sx_railcharge', ent = e, dur = 0.85, layer = 1 }) end
end
local function fireRail(B, e, tx, ty)
    local sx, sy = e.x + e.face * 7, e.y - 5
    local dx, dy = tx - sx, (ty - 3) - sy
    local d = hypot(dx, dy)
    if d < 1 then dx, dy, d = e.face, 0, 1 end
    local vx, vy = dx / d, dy / d
    local L = 320
    local ex, ey = sx + vx * L, sy + vy * L
    for o in of(foesOf(B, e)) do
        if segDist(o.x, o.y - 3, sx, sy, ex, ey) <= 7 + o.r then
            o.shield = 0
            hit(e, o, e.atk * 4, { noLeech = true })
            if not o.dead and not o.big and not o.anchor then
                o.x = clamp(o.x + vx * 10, 6, AW - 6); o.y = clamp(o.y + vy * 10, 14, FIELD_H - 10)
            end
        end
    end
    for o in of(alliesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 44 then o.overT = max(o.overT or 0, 3) end end
    G.shake = max(G.shake, 0.45); FX.sound('zap')
    FX.particle(sx, sy, '#6ef0ff', 16, 80, 20, 0.4)
    if not REDUCED then
        anim('sx_railbeam', sx, sy, { x1 = ex, y1 = ey, dur = 0.55 })
        R.steam(e.x - e.face * 4, e.y - 4, 22, '#ffd6d6')
        P.ring(sx, sy, 2, 12, '#ffffff', { thick = 2, dur = 0.3, oy = 0, ry = 1, layer = 1 })
    end
end
D.sx_railcharge = function(a, k, x, y)
    local e = a.ent
    local r = e.rail
    if e.dead or not r then return end
    local mx, my = x + e.face * 7, y - 5
    local rr = 1 + 2.5 * k
    -- 瞄准线
    actx.globalAlpha = 0.35 + 0.3 * ((floor(G.time * 20) % 2 == 0) and 1 or 0)
    local dx, dy = r.tx - mx, (r.ty - 3) - my
    local d = max(1, hypot(dx, dy))
    for s = 4, 220, 3 do px(mx + dx / d * s, my + dy / d * s, 1, 1, '#ff3b3b') end
    -- 聚能光球
    actx.globalAlpha = 0.4; disk(mx, my, rr + 2, 1, '#6ef0ff')
    actx.globalAlpha = 1; disk(mx, my, rr, 1, '#e0ffff'); px(mx, my, 1, 1, '#ffffff')
    if js.random() < 0.9 then
        local an = js.random() * TAU
        local dd = 10 + js.random() * 6
        spark(mx + cos(an) * dd, my + sin(an) * dd, -cos(an) * dd / 0.18, -sin(an) * dd / 0.18, 0.18, (js.random() < 0.5) and '#6ef0ff' or '#ff3b3b')
    end
    actx.globalAlpha = 1
end
D.sx_railbeam = function(a, k, x, y)
    local w = (1 - k)
    local L = hypot(a.x1 - x, a.y1 - y)
    local nx, ny = -(a.y1 - y) / max(1, L), (a.x1 - x) / max(1, L)
    local function strip(off, col, al)
        actx.globalAlpha = al
        line(x + nx * off, y + ny * off, a.x1 + nx * off, a.y1 + ny * off, col)
    end
    local half = max(0, round(3 * w))
    for off = -half - 1, half + 1 do strip(off, '#b3142a', 0.35 * w) end
    for off = -half, half do strip(off, '#ff3b3b', 0.9 * w) end
    if half >= 1 then strip(0, '#ffffff', 1) end
    if k < 0.5 then strip(-1, '#6ef0ff', 0.6); strip(1, '#6ef0ff', 0.6) end
    actx.globalAlpha = 1
    if js.random() < 0.8 then
        local q = js.random()
        spark(x + (a.x1 - x) * q, y + (a.y1 - y) * q, rand(-10, 10), rand(-20, -4), 0.35, (js.random() < 0.5) and '#ffffff' or '#ff8e6a')
    end
end
SIG.railcannon = { '#6ef0ff', '#ff3b3b', function(B, e, t, c)
    R.gears(e, '#d9a730', '#ffe680')
    P.rune(e.x, e.y, 18, '#6ef0ff', '#ff3b3b', false, 0.9)
end }

-- ===========================================================================
-- 吟游诗人 · 血咏魔音「血咏终章」
-- ===========================================================================
X.crimsonaria = function(B, e, t)
    local old = ownField(B, e, 'aria')
    if old then old.done = true end
    B.fields:push({ kind = 'aria', src = e, x = e.x, y = e.y, t = 2.4, max = 2.4, beat = 0, next = 0 })
end
local function stepAria(B, f, dt)
    local e = f.src
    if e.dead or B.over then f.done = true; return end
    f.x, f.y = e.x, e.y
    f.t = f.t - dt; f.next = f.next - dt
    if f.next <= 0 and f.beat < 4 then
        f.beat = f.beat + 1; f.next = f.next + 0.6
        if f.beat < 4 then
            for o in of(foesOf(B, e)) do if hypot(o.x - e.x, (o.y - e.y) * 1.2) <= 70 then hit(e, o, e.atk * 0.6, { noLeech = true }) end end
            for o in of(alliesOf(B, e)) do
                if hypot(o.x - e.x, (o.y - e.y) * 1.2) <= 70 then
                    local n = min(3, ((o.bAtk and o.ariaN) or 0) + 1)
                    o.ariaN = n
                    addBuff(o, 6, { atk = 0.1 * n })
                    if o.skill then gainEnergy(o, 8) end
                end
            end
            FX.sound('hit')
            if not REDUCED then anim('sx_soundwave', e.x, e.y, { R = 70, beat = f.beat, dur = 0.5, layer = 0 }) end
        else
            for o in of(foesOf(B, e)) do
                if hypot(o.x - e.x, (o.y - e.y) * 1.2) <= 90 then hit(e, o, e.atk * 1.8, { noLeech = true }); stunT(o, 1) end
            end
            for o in of(alliesOf(B, e)) do o.haste = max(o.haste or 0, 3) end
            G.shake = max(G.shake, 0.35); FX.sound('ult')
            if not REDUCED then
                anim('sx_soundwave', e.x, e.y, { R = 90, beat = 4, dur = 0.7, layer = 0 })
                P.ring(e.x, e.y, 6, 90, '#ff3b3b', { thick = 3, dur = 0.6 })
                P.rays(e.x, e.y - 8, '#ff6ad5', '#ffffff', 22, 14, 0.5)
                B.tint = { t = 0.4, max = 0.4, rgb = '170,20,90' }
            end
            f.done = true
        end
    end
    if f.t <= 0 then f.done = true end
end
local function noteAt(x, y, col)
    px(x - 1, y, 2, 2, col); px(x + 1, y - 4, 1, 5, col); px(x + 2, y - 4, 1, 1, col); px(x + 3, y - 3, 1, 1, col)
end
D.sx_soundwave = function(a, k, x, y)
    local r = 8 + (a.R - 8) * ease(k)
    local al = fade(k, 0.05, 0.4)
    local big = a.beat == 4
    actx.globalAlpha = al
    ring(x, y + 6, r, 0.5, big and '#ff3b3b' or '#ff6ad5', false)
    actx.globalAlpha = al * 0.6
    ring(x, y + 6, r - 3, 0.5, big and '#ffe0f4' or '#ff3b3b', true, floor(G.time * 16))
    local n = big and 8 or 5
    for i = 0, n - 1 do
        local an = i / n * TAU + a.beat * 0.6 + k * 0.8
        actx.globalAlpha = al
        noteAt(x + cos(an) * r, y + 4 + sin(an) * r * 0.5, (i % 2 == 0) and '#ff6ad5' or '#ffe0f4')
    end
    actx.globalAlpha = 1
end
SIG.crimsonaria = { '#ff6ad5', '#ff3b3b', function(B, e, t, c)
    for i = 0, 5 do
        local an = i / 6 * TAU
        anim('sx_note', e.x + cos(an) * 8, e.y - 8 + sin(an) * 4, { vx = cos(an) * 18, vy = -14, col = (i % 2 == 0) and '#ff6ad5' or '#ff3b3b', dur = 0.9, layer = 1 })
    end
    P.ring(e.x, e.y, 3, 20, '#ff6ad5', { thick = 2, dur = 0.4 })
end }
D.sx_note = function(a, k, x, y)
    actx.globalAlpha = fade(k, 0.1, 0.3)
    noteAt(x + a.vx * k, y + a.vy * k + sin(k * 12) * 1.5, a.col)
    actx.globalAlpha = 1
end

-- ===========================================================================
-- 幼龙 · 血焰魔龙「炼狱龙息」
-- ===========================================================================
X.infernosweep = function(B, e, t)
    local foes = foesOf(B, e):filter(targetable)
    local cx = centroid(foes)
    local x0 = 1e9
    for o in of(foes) do x0 = min(x0, o.x) end
    if x0 > 1e8 then x0 = t.x; cx = t.x end
    local dir = (cx >= e.x) and 1 or -1
    if dir < 0 then x0 = -1e9; for o in of(foes) do x0 = max(x0, o.x) end end
    local px0 = clamp(x0 - dir * 26, 10, AW - 10)
    local ox, oy = e.x, e.y
    e.face = dir
    local ok = startFlight(B, e, {
        { dur = 0.32, to = { px0, 28 }, z = 22, fn = function(B2, e2) e2.face = dir; e2.sweep = { tick = 0, drop = 0.1, dir = dir } end },
        { dur = 1.25, to = { px0, FIELD_H - 12 }, z = 20, fn = function(B2, e2) e2.sweep = nil end },
        { dur = 0.42, to = { ox, oy }, z = 12 },
        { dur = 0.1, to = { ox, oy }, z = 0 },
    })
    if not ok then -- 飞不起来（极少见）：原地朝前喷一口
        for o in of(foesOf(B, e)) do
            local dx = (o.x - e.x) * e.face
            if dx >= 0 and dx <= 76 and abs(o.y - e.y) <= 10 + dx * 0.35 then hit(e, o, e.atk * 1.6, { noLeech = true }); applyBurn(o, e, 3, e.atk * 0.4) end
        end
    end
end
local function stepSweep(B, e, dt)
    local s = e.sweep
    if not e.flight or e.dead then e.sweep = nil; return end
    e.face = s.dir
    local gx, gy = e.x, e.y + (e.flyZ or 0)
    s.tick = s.tick - dt; s.drop = s.drop - dt
    if s.tick <= 0 then
        s.tick = s.tick + 0.15
        for o in of(foesOf(B, e)) do
            local dx = (o.x - gx) * s.dir
            if dx >= -4 and dx <= 76 and abs(o.y - gy) <= 10 + dx * 0.35 then
                hit(e, o, e.atk * 0.4, { noLeech = true, noCrit = true })
                if not o.dead then applyBurn(o, e, 3, e.atk * 0.4) end
            end
        end
    end
    if s.drop <= 0 then
        s.drop = s.drop + 0.25
        for _, dd in ipairs({ 24, 52 }) do
            B.fields:push({ kind = 'hellfire', x = clamp(gx + s.dir * dd + rand(-3, 3), 6, AW - 6), y = clamp(gy + rand(-3, 3), 14, FIELD_H - 8), r = 12, t = 4, max = 4, tick = 0.5, src = e, mul = 0.25 })
        end
    end
    -- 龙焰：从嘴里往前下方喷出的火粒
    if not REDUCED then
        local mx, my = e.x + s.dir * 8, e.y - 4
        for _ = 1, 4 do
            local life = rand(0.25, 0.4)
            local dist = rand(20, 76)
            local tyy = gy + rand(-8, 8) * (dist / 76 + 0.3)
            spark(mx, my, s.dir * dist / life, (tyy - my) / life, life, pick(A('#ff6a2a', '#ffb03a', '#ffd84a', '#ff3b3b')), (js.random() < 0.3) and 2 or 1)
        end
    end
end
local function stepHellfire(B, f, dt)
    f.t = f.t - dt; f.tick = f.tick - dt
    if f.tick <= 0 then
        f.tick = f.tick + 0.5
        for o in of(foesOf(B, f.src)) do
            if hypot(o.x - f.x, (o.y - f.y) * 1.4) <= f.r then
                hit(f.src, o, f.src.atk * f.mul, { noLeech = true, noCrit = true, dot = true })
                if not o.dead then applyBurn(o, f.src, 2, f.src.atk * 0.3) end
            end
        end
    end
    if f.t <= 0 then f.done = true end
end
FIELD_DRAW.hellfire = function(f)
    local a = clamp(f.t / 0.6, 0, 1) * clamp((f.max - f.t) / 0.15, 0, 1)
    actx.globalAlpha = a * 0.3
    disk(f.x, f.y, f.r, 0.5, '#5e0b18')
    actx.globalAlpha = a
    for i = 0, 6 do
        local an = i * 2.39996 + f.x
        local rr = f.r * 0.8 * (((i * 7) % 10) / 10)
        local x = f.x + cos(an) * rr
        local y = f.y + sin(an) * rr * 0.5
        local h = 2 + floor((sin(G.time * 11 + i + f.y) + 1) * 1.6)
        px(x, y - h + 1, 1, h, '#b3142a')
        px(x, y - h, 1, 1, (i % 2 == 0) and '#ff6a2a' or '#ffd84a')
    end
    actx.globalAlpha = 1
end
SIG.infernosweep = { '#ff6a2a', '#ffd84a', function(B, e, t, c)
    R.wings(e, '#3a1a2e', '#ff6a2a', 0.6)
    FX.particle(e.x, e.y + 6, '#c9b08a', 12, 50, 60, 0.4)
    P.ring(e.x, e.y, 3, 22, '#ff6a2a', { thick = 2, dur = 0.4 })
end }

-- ===========================================================================
-- 冰霜元素 · 血霜魔灵「霜狱碎魂」
-- ===========================================================================
X.frostcoffin = function(B, e, t)
    local list = foesOf(B, e):filter(targetable)
    local L = {}
    for o in of(list) do
        freeze(o, SUP_COFFIN_FREEZE or 1.8) -- 第十四次更新：数值可在 balance14 调整
        o.coffinT = 3
        L[#L + 1] = o
        if not REDUCED then add({ kind = 'sx_coffin', ent = o, dur = 3, layer = 1 }) end
    end
    for o in of(alliesOf(B, e)) do shieldPct(o, 0.15) end
    B.fields:push({ kind = 'coffins', src = e, list = L, x = e.x, y = e.y, t = 1.2, max = 1.2 })
    B.tint = { t = 0.6, max = 0.6, rgb = '170,220,255' }
end
local function stepCoffins(B, f, dt)
    f.t = f.t - dt
    if f.t > 0 then return end
    if not f.order then
        local left = {}
        for _, o in ipairs(f.list) do if not o.dead then left[#left + 1] = o end end
        local order, cx, cy = {}, f.x, f.y
        while #left > 0 do
            local bi, bd = 1, 1e9
            for i, o in ipairs(left) do local d = hypot(o.x - cx, o.y - cy); if d < bd then bd = d; bi = i end end
            local o = table.remove(left, bi)
            order[#order + 1] = o; cx, cy = o.x, o.y
        end
        f.order, f.i, f.ct, f.px, f.py = order, 1, 0, f.x, f.y - 6
    end
    f.ct = f.ct - dt
    while f.ct <= 0 and f.i <= #f.order do
        local o = f.order[f.i]
        f.i = f.i + 1; f.ct = f.ct + 0.1
        o.coffinT = 0
        if not o.dead then
            local src = f.src
            hit(src, o, src.atk * (SUP_COFFIN_MUL or 2.2) * ((o.hp < o.maxHp * 0.5) and 1.5 or 1), { noLeech = true })
            if not o.dead then applySlow(o, 3, 0.4) end
            FX.particle(o.x, o.y - 4, '#e8f8ff', 14, 70, 40, 0.5); FX.particle(o.x, o.y - 4, '#ff3b3b', 6, 50, 40, 0.4)
            if not REDUCED then
                FX.iceShatter(o.x, o.y, o.big, '#ff8e9a')
                P.beam(f.px, f.py, o.x, o.y - 4, '#bff4ff', 1, 0.35)
                P.star(o.x, o.y - 6, '#ffffff', '#ff3b3b', o.big and 12 or 8, 0.3)
            end
            f.px, f.py = o.x, o.y - 4
            FX.sound('hit')
        end
    end
    if f.i > #f.order then f.done = true; G.shake = max(G.shake, 0.3) end
end
D.sx_coffin = function(a, k, x, y)
    local e = a.ent
    if e.dead or (e.coffinT or 0) <= 0 then return end
    local big = e.big
    local w, h = big and 20 or 13, big and 26 or (e.tall and 22 or (e.mid and 20 or 18))
    local x0, y0 = round(x - w / 2), round(y + 8 - h)
    local grow = clamp(a.t / 0.2, 0, 1)
    local top = y0 + round((1 - grow) * h)
    actx.globalAlpha = 0.28
    px(x0 + 1, top, w - 2, y0 + h - top, '#9fd4ff')
    actx.globalAlpha = 0.95
    px(x0 + 1, top, w - 2, 1, '#e0f6ff'); px(x0, top + 1, 1, y0 + h - top - 1, '#bff4ff'); px(x0 + w - 1, top + 1, 1, y0 + h - top - 1, '#bff4ff')
    px(x0 + 1, y0 + h - 1, w - 2, 1, '#bff4ff')
    if grow >= 1 then
        px(x0 + 2, y0 + 2, 1, 4, '#ffffff'); px(x0 + 3, y0 + 2, 2, 1, '#ffffff')
        -- 冰里的血丝
        actx.globalAlpha = 0.85
        px(x0 + w - 4, y0 + 4, 1, 3, '#ff3b3b'); px(x0 + w - 5, y0 + 7, 1, 2, '#c0182e'); px(x0 + 3, y0 + h - 6, 2, 1, '#ff3b3b')
        if js.random() < 0.08 then spark(x0 + rand(1, w - 1), y0 + rand(1, h - 1), 0, 0, 0.3, '#ffffff') end
    end
    actx.globalAlpha = 1
end
SIG.frostcoffin = { '#bff4ff', '#ff3b3b', function(B, e, t, c)
    P.ring(e.x, e.y, 6, 120, '#bff4ff', { thick = 2, dur = 0.7 })
    P.ring(e.x, e.y, 4, 80, '#ff3b3b', { thick = 1, dash = true, dur = 0.6, delay = 0.1 })
    P.wave(e.x, (e.face > 0) and (AW + 8) or -8, '#bff4ff', '#ffffff', 0.6)
end }

-- ---------------------------------------------------------------------------
-- 场地 / 每帧机制
-- ---------------------------------------------------------------------------
local FIELD_STEP = { bladering = stepBladering, moonfall = stepMoonfall, sunwheel = stepSunwheel, siphon = stepSiphon,
    aria = stepAria, hellfire = stepHellfire, coffins = stepCoffins }
local _stepHazard = stepHazard
function stepHazard(B, f, dt)
    local fn = FIELD_STEP[f.kind]
    if fn then
        if not f.done then fn(B, f, dt) end
        return
    end
    return _stepHazard(B, f, dt)
end
-- 没有地面画法的场地：什么都不画（否则会落到黑洞的画法）
for _, k in ipairs({ 'sunwheel', 'aria', 'coffins' }) do FIELD_DRAW[k] = function() end end

addHook('step', function(B, dt, alive)
    stepPhoenix(B, dt)
    for e in of(alive) do
        if (e.huntT or 0) > 0 then -- 血煞猎杀：击杀后连扑
            e.huntT = e.huntT - dt
            if e.huntQ and not e.flight and not B.over then
                e.huntQ = false
                local tg = huntTarget(B, e)
                if tg and pounce(B, e, tg, 2.0) then e.huntN = e.huntN - 1 end
            end
            if e.huntT <= 0 then e.huntQ = false end
        end
        if (e.heatT or 0) > 0 then -- 熔铠反噬
            e.heatT = e.heatT - dt
            if e.heatT <= 0 and not B.over then meltBurst(B, e) end
        end
        if e.rail then -- 轨道炮蓄能：不动、不普攻
            local r = e.rail
            e.cdLeft = max(e.cdLeft, 0.25)
            if r.tgt and not r.tgt.dead then r.tx, r.ty = r.tgt.x, r.tgt.y end
            if abs(r.tx - e.x) > 1 then e.face = (r.tx > e.x) and 1 or -1 end
            r.t = r.t - dt
            if r.t <= 0 or B.over then
                e.rail = nil; e.speed = r.speed
                if not B.over then fireRail(B, e, r.tx, r.ty) end
            end
        end
        if e.sweep then stepSweep(B, e, dt) end
        if (e.coffinT or 0) > 0 then e.coffinT = e.coffinT - dt end
    end
end)
-- 熔铠：积蓄受到的伤害
local _hit = hit
function hit(src, t, base, o)
    local dmg = _hit(src, t, base, o)
    if (t.heatT or 0) > 0 and dmg and dmg > 0 then t.heat = (t.heat or 0) + dmg end
    return dmg
end
-- 月痕：被赤月巨箭射中的敌人头上挂一枚小月牙
local _procHit = procHit
function procHit(p, o)
    _procHit(p, o)
    if p.kind == 'moonarrow' and not o.dead and not REDUCED then
        local m = o.sxMark
        if m and m.t < m.dur then m.t = 0 else o.sxMark = add({ kind = 'sx_moonmark', ent = o, dur = 5, layer = 1 }) end
    end
end

-- ---------------------------------------------------------------------------
-- 主题光效：描边、脚下光圈、余烬、降世
-- ---------------------------------------------------------------------------
local SPR_THEME = {}
for cls, b in pairs(SUPER_OF) do SPR_THEME['sx_' .. cls] = SUP_THEME[b] end
local IMG_TH = setmetatable({}, { __mode = 'k' })
local _spr = spr
function spr(name, over, flash, flip, overKey, part)
    local c = _spr(name, over, flash, flip, overKey, part)
    if IMG_TH[c] == nil then IMG_TH[c] = SPR_THEME[name] or false end
    return c
end
local DEF_GLOW, DEF_HALO = SUP_GLOW, SUP_HALO
local _drawQGlow = drawQGlow
function drawQGlow(img, ...)
    local th = IMG_TH[img]
    if th then SUP_GLOW, SUP_HALO = th.glow, th.halo else SUP_GLOW, SUP_HALO = DEF_GLOW, DEF_HALO end
    return _drawQGlow(img, ...)
end
local CUR = nil -- 正在画的超凡单位的主题（poseOf / drawUnitPrep 时记下）
local _poseOf = poseOf
function poseOf(e)
    CUR = e.sup and SUP_THEME[e.branch] or nil
    return _poseOf(e)
end
local _prep = drawUnitPrep
function drawUnitPrep(u, ...)
    CUR = isSup(u) and SUP_THEME[u.branch] or nil
    return _prep(u, ...)
end
local _light = drawSupLight
function drawSupLight(x, y)
    local th = CUR
    if not th then return _light(x, y) end
    local k, X0, Y0 = supPulse(), round(x), round(y)
    actx.fillStyle = th.halo
    actx.globalAlpha = 0.25 + 0.15 * k; actx:fillRect(X0 - 10, Y0 + 7, 20, 1); actx:fillRect(X0 - 8, Y0 + 6, 16, 1); actx:fillRect(X0 - 8, Y0 + 8, 16, 1)
    actx.fillStyle = th.glow
    actx.globalAlpha = 0.4 + 0.3 * k; actx:fillRect(X0 - 6, Y0 + 7, 12, 1)
    actx.fillStyle = th.c2; actx.globalAlpha = 0.5 + 0.4 * k; actx:fillRect(X0 - 3, Y0 + 7, 6, 1)
    actx.globalAlpha = 1
end
local _embers = supEmbers
function supEmbers(x, y)
    local th = CUR
    if not th then return _embers(x, y) end
    if REDUCED or js.random() > 0.35 then return end
    local cols = th.embers
    local col = cols[floor(js.random() * #cols) + 1]
    local st = th.ember
    if st == 'fall' then -- 落叶
        spark(x + rand(-8, 8), y - rand(14, 20), rand(-6, 6), rand(8, 16), 0.9, col, (js.random() < 0.3) and 2 or 1)
    elseif st == 'snow' then
        spark(x + rand(-9, 9), y - rand(10, 20), rand(-4, 4), rand(5, 12), 1.0, col)
    elseif st == 'spark' then -- 闪烁的火花 / 电光
        spark(x + rand(-8, 8), y + rand(-14, 4), rand(-10, 10), rand(-10, 4), 0.3, col)
    elseif st == 'note' then
        spark(x + rand(-7, 7), y + rand(-10, 2), rand(-4, 4), -rand(8, 14), 0.9, col, (js.random() < 0.25) and 2 or 1)
    else
        spark(x + rand(-7, 7), y + rand(-8, 6), rand(-3, 3), -rand(12, 24), 0.7, col, (js.random() < 0.2) and 2 or 1)
    end
end
function FX.superSummon(u, s) -- 超凡降世：光柱、冲击环、全场闪光，颜色随角色
    local th = SUP_THEME[u.branch] or SUP_THEME.sup_warrior
    local p = slotPos(s)
    local cols = A(th.c1, th.c2, th.glow, '#fff2ea', th.halo)
    for _ = 0, 45 do
        local life = rand(0.4, 1)
        FX.parts:push({ x = p.x + rand(-5, 5), y = p.y + 8 - rand(0, 70), vx = rand(-3, 3), vy = -rand(20, 70), g = 0, life = life, max = 1,
            color = pick(cols), size = (js.random() < 0.3) and 2 or 1 })
    end
    FX.ring(p.x, p.y, 30, th.glow); FX.ring(p.x, p.y, 16, '#fff2ea')
    FX.particle(p.x, p.y, th.c1, 50, 110, 30, 1.0)
    if not REDUCED then
        P.pillar(p.x, p.y, th.c1, th.c2, 70, 14, 0.9)
        P.ring(p.x, p.y, 4, 40, th.glow, { thick = 3, dur = 0.7 })
        P.ring(p.x, p.y, 2, 26, th.halo, { thick = 2, dur = 0.6, delay = 0.12 })
    end
    u.pop = 0.5; G.shake = max(G.shake, 0.6)
    UI.supFlash(p.x, p.y)
    Sound.play('q4')
end

return true
