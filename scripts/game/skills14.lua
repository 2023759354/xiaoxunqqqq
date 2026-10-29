-- ============================================================================
-- 第十四次更新：雷同技能重做（机制 + 专属特效）
-- 对全部技能按「打法」归类后，下面这些和别的技能几乎一样（同一个兵种里重复的优先改）：
--   铁背熊「铁壁」       ≈ 巨熊基础「熊吼」（嘲讽 + 自身减伤 35% 4 秒）       → 「铁壁冲阵」冲进敌群最密处，一路撞开再嘲讽
--   守护熊「守护誓言」   ≈ 圣骑士「圣光庇护」≈ 翡翠龙「翠玉龙鳞」（给自己和两名队友套护盾） → 「守护誓约」锁链连住两名残血队友，替他们挨打
--   翡翠龙「翠玉龙鳞」   （同上）                                               → 「翠玉鳞刃」鳞甲减伤，挨打就把龙鳞射回去
--   疾风之翼「顺风」     ≈ 战旗手「战吼」（全队狂热 3 秒）                       → 「风之回廊」放出龙卷风横扫敌阵，卷走小怪
--   战歌手「战争赞歌」   ≈ 吟游诗人基础「激昂战歌」（全队攻击 / 攻速）           → 「英雄赞歌」把增益集中给攻击最高的一名队友
--   极光之灵「极光帷幕」 ≈ 光合花「日光结界」+ 净化（全队回血 + 减伤）            → 「极光驱散」驱散敌人身上的护盾和增益并冻结
--   刃羽鹰「羽刃风暴」   ≈ 星辰射手「星落」（每个敌人头上落一道）                 → 「回旋羽刃」两枚羽刃画着弧线飞出再飞回
--   炎羽隼「炎羽突袭」   ≈ 风行者「贯穿之箭」（直线贯穿、到场边折返）             → 「炎环收束」火环圈住敌群、慢慢收紧后爆燃
--   天空猎手「俯冲」     ≈ 猛虎「扑杀」≈ 猎魔人「猎杀」（打残血、击杀返能量）     → 「夺声俯冲」专打会放技能的敌人，打断并沉默
--   白虎「伏击」         ≈ 猛虎「扑杀」/ 饿虎「追杀」（同兵种三个都扑残血）       → 「虎影」三道虎影扑向生命最高的敌人并撕开破绽
--   雪舞者「暴风雪」     ≈ 风暴鹰「雷暴」（圆形持续伤害场地）                     → 「冰径」铺一条冰路，减速、让敌人滑倒
-- 机制放在 EXT_SKILLS2（技能分派里优先级最高），施法特效放在 FX.SIG（覆盖旧特效），
-- 命中反馈（伤害数字、冻结、护盾……）仍由 skillfx 的 diffFx 自动叠加
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, atan, sin, cos, sqrt = math.floor, math.ceil, math.max, math.min, math.abs, math.atan, math.sin, math.cos, math.sqrt
local PI, TAU = math.pi, math.pi * 2
local of = js.of

local SIG, D, H, P = FX.SIG, FX.D, FX.H, FX.P
local add, ease, alphaOf, line, disk, band, ring = H.add, H.ease, H.alphaOf, H.line, H.disk, H.band, H.ring
local X = EXT_SKILLS2

-- ---------------------------------------------------------------------------
-- 小工具
-- ---------------------------------------------------------------------------
local function px(x, y, w, h, c) actx.fillStyle = c; actx:fillRect(round(x), round(y), w or 1, h or 1) end
local function anim(kind, x, y, o) o = o or {}; o.kind = kind; o.x = x; o.y = y; o.layer = o.layer or 1; return add(o) end
local function targetable(o) return not o.dead and not o.immune and not o.untargetable end
local function byHpFrac(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end
local function stunT(o, d) if o.dead or o.immune or o.ccImmune then return end; o.stun = max(o.stun, o.big and d * 0.5 or d) end
local function shieldPct(o, p) if not o.dead then o.shield = min(o.maxHp, (o.shield or 0) + o.maxHp * p) end end
local function centroid(list)
    local x, y, n = 0, 0, 0
    for o in of(list) do x = x + o.x; y = y + o.y; n = n + 1 end
    if n == 0 then return nil end
    return x / n, y / n
end
local function spark(x, y, vx, vy, life, color, size, g)
    if REDUCED then return end
    FX.parts:push({ x = x, y = y, vx = vx, vy = vy, g = g or 0, life = life, max = life, color = color, size = size or 1 })
end
local function fade(k, fin, fout)
    local a = 1
    if fin and k < fin then a = k / fin end
    if fout and k > 1 - fout then a = min(a, (1 - k) / fout) end
    return clamp(a, 0, 1)
end
local function set(key, c1, c2, f) SIG[key] = { c1, c2, f } end
local FIELD_STEP = {}

-- ===========================================================================
-- 1. 铁背熊「铁壁冲阵」
-- ===========================================================================
SKILLS.ironwall.name = '铁壁冲阵'
SKILLS.ironwall.desc = '举起铁背冲向附近敌人最密集的地方（最远 70）：路上的敌人受到 120% 伤害、被撞开并眩晕 0.6 秒；落地后嘲讽周围的敌人，自身 4 秒内受到的伤害 -35%'
X.ironwall = function(B, e, t)
    local foes = foesOf(B, e):filter(targetable)
    local near = foes:filter(function(o) return hypot(o.x - t.x, o.y - t.y) <= 40 end)
    local cx, cy = centroid(near)
    if not cx then cx, cy = t.x, t.y end
    local dx, dy = cx - e.x, cy - e.y
    local d = hypot(dx, dy)
    if d < 1 then dx, dy, d = e.face, 0, 1 end
    local L = min(70, max(0, d - 6))
    local ux, uy = dx / d, dy / d
    local ox, oy = e.x, e.y
    local ex, ey = clamp(ox + ux * L, 6, AW - 6), clamp(oy + uy * L, 14, FIELD_H - 10)
    for o in of(foes) do
        if segDist(o.x, o.y, ox, oy, ex, ey) <= 9 + o.r then
            hit(e, o, e.atk * 1.2, { melee = true, noLeech = true })
            if not o.dead then
                stunT(o, 0.6)
                if not o.big and not o.anchor then -- 往两边撞开
                    local side = ((o.x - ox) * -uy + (o.y - oy) * ux >= 0) and 1 or -1
                    o.x = clamp(o.x + ux * 6 - uy * side * 12, 6, AW - 6)
                    o.y = clamp(o.y + uy * 6 + ux * side * 12, 14, FIELD_H - 10)
                end
            end
        end
    end
    e.x, e.y = ex, ey
    if abs(ux) > 0.05 then e.face = (ux > 0) and 1 or -1 end
    strikeAt(e)
    for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 44 then o.target = e end end
    addBuff(e, 4, { dr = 0.35 })
    G.shake = max(G.shake, 0.25)
    e.s14charge = { ox = ox, oy = oy, ex = ex, ey = ey }
end
-- 冲锋：铁灰色的楔形盾印沿路推进，身后拖着速度线，落地扬尘 + 嘲讽声浪
D.s14_charge = function(a, k, x, y)
    local al = 1 - k
    local L = hypot(a.ex - a.ox, a.ey - a.oy)
    if L < 1 then return end
    local ux, uy = (a.ex - a.ox) / L, (a.ey - a.oy) / L
    local head = min(1, k / 0.25)
    -- 速度线
    for i = 0, 6 do
        local off = (i - 3) * 2.2
        local s0 = (0.1 + (i % 3) * 0.12) * L
        local s1 = L * head
        actx.globalAlpha = al * 0.7
        local c = (i % 2 == 0) and '#c9d2e0' or '#8d9ab2'
        for s = s0, s1, 2 do px(a.ox + ux * s - uy * off, a.oy - 4 + uy * s + ux * off * 0.6, 1, 1, c) end
    end
    -- 楔形盾印
    if k < 0.6 then
        actx.globalAlpha = fade(k, 0.05, 0.4)
        local hx, hy = a.ox + ux * L * head, a.oy - 4 + uy * L * head
        local f = (ux >= 0) and 1 or -1
        for r = 0, 6 do
            local w = 7 - r
            px(hx + f * (r - 2), hy - w, 1, w * 2 + 1, (r < 2) and '#ffffff' or '#c9d2e0')
        end
        px(hx - f * 3, hy - 1, 2, 3, '#5a6478')
    end
    actx.globalAlpha = 1
end
set('ironwall', '#c9d2e0', '#8d9ab2', function(B, e, t, c)
    local ch = e.s14charge
    if not ch then return end
    e.s14charge = nil
    anim('s14_charge', 0, 0, { ox = ch.ox, oy = ch.oy, ex = ch.ex, ey = ch.ey, dur = 0.55 })
    P.ring(ch.ex, ch.ey, 4, 30, '#c9d2e0', { thick = 2, dur = 0.45 })
    P.ring(ch.ex, ch.ey, 6, 44, '#8d9ab2', { thick = 1, dur = 0.6 })
    for i = 1, 14 do local an = rand(0, TAU); spark(ch.ex, ch.ey + 4, cos(an) * rand(20, 50), sin(an) * rand(6, 18) - 10, 0.5, (i % 2 == 0) and '#a89878' or '#8d9ab2', 1, 60) end
    P.shield(e, '#c9d2e0', 11)
end)

-- ===========================================================================
-- 2. 守护熊「守护誓约」
-- ===========================================================================
SKILLS.bulwark.name = '守护誓约'
SKILLS.bulwark.desc = '用锁链连住生命比例最低的 2 名队友 6 秒：他们受到的直接伤害全部转由守护熊承担；期间守护熊受到的伤害 -30%，并获得 15% 最大生命的护盾'
X.bulwark = function(B, e, t)
    local al = alliesOf(B, e):filter(function(o) return o ~= e and not o.minion end):sort(byHpFrac):slice(0, 2)
    for o in of(al) do
        o.oath = { by = e, t = 6 }
        if not REDUCED then add({ kind = 's14_chain', a = e, b = o, dur = 6.2, layer = 1 }) end
    end
    addBuff(e, 6, { dr = 0.3 })
    shieldPct(e, 0.15)
    e.s14oath = #al
end
-- 锁链：从守护熊到队友的一串金色链环，轻轻下垂、缓缓流动；队友头上一枚小盾
D.s14_chain = function(a, k, x, y)
    local A0, B0 = a.a, a.b
    local L = B0.oath
    if A0.dead or B0.dead or not L or L.by ~= A0 or L.t <= 0 then return end
    local al = fade(k, 0.04, 0.06)
    local x0, y0, x1, y1 = A0.x, A0.y - 5, B0.x, B0.y - 5
    local d = hypot(x1 - x0, y1 - y0)
    local n = max(2, floor(d / 4))
    local sag = min(8, d * 0.12)
    for i = 0, n do
        local u = i / n
        local X = x0 + (x1 - x0) * u
        local Y = y0 + (y1 - y0) * u + sin(u * PI) * sag
        local lit = ((i + floor(G.time * 10)) % 4 == 0)
        actx.globalAlpha = al * (lit and 1 or 0.75)
        if i % 2 == 0 then px(X - 1, Y, 2, 1, lit and '#ffffff' or '#ffd84a') else px(X, Y - 1, 1, 2, '#c8900f') end
    end
    -- 小盾
    actx.globalAlpha = al
    local sx, sy = x1, B0.y - (B0.tall and 23 or (B0.mid and 19 or 17))
    px(sx - 2, sy, 5, 3, '#ffd84a'); px(sx - 1, sy + 3, 3, 1, '#ffd84a'); px(sx, sy + 4, 1, 1, '#ffd84a'); px(sx, sy + 1, 1, 2, '#ffffff')
    actx.globalAlpha = 1
end
set('bulwark', '#ffd84a', '#c8900f', function(B, e, t, c)
    P.ring(e.x, e.y, 4, 26, '#ffd84a', { thick = 2, dur = 0.5 })
    P.shield(e, '#ffd84a', 11)
    for o in of(alliesOf(B, e)) do
        if o.oath and o.oath.by == e then
            P.shield(o, '#ffe680', 8)
            P.converge(o.x, o.y - 4, '#ffd84a', 8, 12)
        end
    end
end)

-- ===========================================================================
-- 3. 翡翠龙「翠玉鳞刃」
-- ===========================================================================
SKILLS.jadescale.name = '翠玉鳞刃'
SKILLS.jadescale.desc = '张开翠玉鳞甲 5 秒：自身受到的伤害 -40%，每次被敌人攻击就射出一片龙鳞反击（70% 伤害，每秒最多 3 片）；鳞甲收起时，身边的队友各获得 15% 最大生命的护盾'
X.jadescale = function(B, e, t)
    addBuff(e, 5, { dr = 0.4 })
    e.jadeT = 5; e.jadeCd = 0
    if not REDUCED then add({ kind = 's14_jade', ent = e, dur = 5.1, layer = 1 }) end
end
PROJ_DRAW.jadeshard = function(p, c, s)
    local x, y = round(p.x), round(p.y)
    actx.fillStyle = '#2f7a34'; actx:fillRect(x - 2, y - 1, 5, 3); actx:fillRect(x - 1, y - 2, 3, 5)
    actx.fillStyle = '#6fdc8a'; actx:fillRect(x - 1, y - 1, 3, 3)
    actx.fillStyle = '#e6ffd6'; actx:fillRect(x, y - 1, 1, 1)
    if js.random() < 0.5 then spark(p.x - c * 3, p.y - s * 3, rand(-3, 3), rand(-3, 3), 0.25, '#6fdc8a') end
end
-- 鳞甲：一圈六角形翠玉鳞片贴着身体缓缓转动，偶尔闪光
D.s14_jade = function(a, k, x, y)
    local e = a.ent
    if e.dead or (e.jadeT or 0) <= 0 then return end
    local al = fade(k, 0.06, 0.06)
    local R = e.r + 5
    for i = 0, 7 do
        local an = G.time * 1.6 + i / 8 * TAU
        local sx, sy = e.x + cos(an) * R, e.y - 4 + sin(an) * R * 0.45
        local back = sin(an) < 0
        actx.globalAlpha = al * (back and 0.45 or 0.95)
        px(sx - 1, sy - 1, 3, 3, '#2f7a34'); px(sx, sy - 2, 1, 1, '#2f7a34'); px(sx, sy + 2, 1, 1, '#2f7a34')
        px(sx, sy - 1, 1, 2, ((i + floor(G.time * 6)) % 8 == 0) and '#ffffff' or '#6fdc8a')
    end
    actx.globalAlpha = 1
end
set('jadescale', '#6fdc8a', '#e6ffd6', function(B, e, t, c)
    P.ring(e.x, e.y, 3, 18, '#6fdc8a', { thick = 2, dur = 0.45 })
    P.shield(e, '#6fdc8a', 12)
    for i = 1, 10 do local an = i / 10 * TAU; spark(e.x + cos(an) * 12, e.y - 4 + sin(an) * 5, -cos(an) * 20, -sin(an) * 8, 0.35, '#6fdc8a') end
end)

-- ===========================================================================
-- 4. 疾风之翼「风之回廊」
-- ===========================================================================
SKILLS.tailwind.name = '风之回廊'
SKILLS.tailwind.desc = '放出一道龙卷风横穿敌阵（约 3 秒）：卷进去的非首领敌人被一路裹挟向后推，每 0.5 秒受到 40% 伤害并减速 60%；我方全队 3 秒内闪避 +20%'
X.tailwind = function(B, e, t)
    local dir = (t and t.x < e.x) and -1 or 1
    local y = clamp(t and t.y or e.y, 18, FIELD_H - 14)
    B.fields:push({ kind = 's14_tornado', src = e, x = e.x + dir * 10, y = y, vx = dir * 58, r = 13, t = 3.2, max = 3.2, tick = 0.25, spin = 0 })
    for o in of(alliesOf(B, e)) do o.dodgeT = max(o.dodgeT or 0, 3) end
end
FIELD_STEP.s14_tornado = function(B, f, dt)
    local e = f.src
    f.t = f.t - dt; f.tick = f.tick - dt; f.spin = f.spin + dt * 14
    f.x = f.x + f.vx * dt
    f.y = f.y + sin(f.t * 3) * 6 * dt
    local doHit = f.tick <= 0
    if doHit then f.tick = f.tick + 0.5 end
    for o in of(foesOf(B, e)) do
        local d = hypot(o.x - f.x, (o.y - f.y) * 1.2)
        if d <= f.r + o.r then
            if not o.big and not o.anchor and not o.immune then -- 裹挟
                o.x = clamp(o.x + (f.x - o.x) * min(1, dt * 7) + f.vx * dt * 0.6, 6, AW - 6)
                o.y = clamp(o.y + (f.y - o.y) * min(1, dt * 4), 14, FIELD_H - 10)
            end
            if doHit and not e.dead then
                hit(e, o, e.atk * 0.4, { noLeech = true })
                if not o.dead then applySlow(o, 1, 0.6) end
            end
        end
    end
    if f.t <= 0 or f.x < -6 or f.x > AW + 6 then f.done = true end
end
FIELD_DRAW.s14_tornado = function(f)
    if f.done then return end
    local al = clamp((f.max - f.t) / 0.25, 0, 1) * clamp(f.t / 0.4, 0, 1)
    -- 一层层椭圆，越往上越宽，旋转的点
    for l = 0, 9 do
        local h = l * 2.6
        local rx = 3 + l * 1.25
        local yy = f.y + 4 - h
        local n = 6 + l
        for j = 0, n - 1 do
            local an = f.spin * (1 + l * 0.05) + j / n * TAU + l * 0.6
            local front = sin(an) > 0
            actx.globalAlpha = al * (front and 0.95 or 0.4)
            px(f.x + cos(an) * rx + sin(l + G.time * 5) * 1.5, yy + sin(an) * rx * 0.25, 1, 1, front and ((j % 3 == 0) and '#ffffff' or '#d8eef8') or '#8fb8c8')
        end
    end
    actx.globalAlpha = al * 0.3
    disk(f.x, f.y + 5, 9, 0.35, '#bff4ff')
    actx.globalAlpha = 1
    if js.random() < 0.6 then -- 卷起的草叶和尘土
        local an = rand(0, TAU)
        spark(f.x + cos(an) * 8, f.y + 2 - rand(0, 20), -sin(an) * 30, -rand(4, 16), 0.4, (js.random() < 0.5) and '#9be36b' or '#c9b88a')
    end
end
set('tailwind', '#d8eef8', '#bff4ff', function(B, e, t, c)
    for o in of(alliesOf(B, e)) do P.ring(o.x, o.y, 2, 10, '#bff4ff', { thick = 1, dur = 0.4 }) end
    for i = 1, 8 do spark(e.x, e.y - 4, e.face * rand(30, 70), rand(-14, 6), 0.4, '#e8f8ff') end
end)

-- ===========================================================================
-- 5. 战歌手「英雄赞歌」
-- ===========================================================================
SKILLS.warhymn.name = '英雄赞歌'
SKILLS.warhymn.desc = '为攻击最高的一名队友高唱赞歌 6 秒：它攻击 +60%、攻速 +40%、受到的伤害 -20%；其他队友攻击 +12%'
X.warhymn = function(B, e, t)
    local al = alliesOf(B, e):filter(function(o) return not o.minion end)
    local others = al:filter(function(o) return o ~= e end)
    local pool = (#others > 0) and others or al
    local hero = pool:slice():sort(function(a, b) return b.atk - a.atk end)[0]
    if not hero then return end
    addBuff(hero, 6, { atk = 0.6, spd = 0.4, dr = 0.2 })
    for o in of(al) do if o ~= hero then addBuff(o, 6, { atk = 0.12 }) end end
    e.s14hero = hero
end
-- 桂冠：英雄头顶一圈金色月桂叶，音符绕着它转
D.s14_laurel = function(a, k, x, y)
    local o = a.ent
    if o.dead then return end
    local al = fade(k, 0.05, 0.1)
    local top = o.y - (o.tall and 22 or (o.mid and 18 or 16))
    for i = 0, 9 do
        local an = PI + i / 9 * PI
        local X, Y = o.x + cos(an) * 6, top + sin(an) * 2.5
        actx.globalAlpha = al
        px(X, Y, 1, 1, (i % 2 == 0) and '#ffd84a' or '#7fd36a')
    end
    for i = 0, 2 do
        local an = G.time * 2.4 + i / 3 * TAU
        local X, Y = o.x + cos(an) * 9, o.y - 6 + sin(an) * 4
        actx.globalAlpha = al * (sin(an) > 0 and 1 or 0.5)
        px(X - 1, Y, 2, 2, '#ffe680'); px(X + 1, Y - 4, 1, 5, '#ffe680')
    end
    actx.globalAlpha = 1
end
set('warhymn', '#ffd84a', '#ff6a4a', function(B, e, t, c)
    local hero = e.s14hero
    e.s14hero = nil
    if not hero then return end
    P.pillar(hero.x, hero.y, '#ffd84a', '#fff6b0', 46, 9, 0.7)
    P.ring(hero.x, hero.y, 3, 20, '#ffd84a', { thick = 2, dur = 0.5 })
    if not REDUCED then add({ kind = 's14_laurel', ent = hero, dur = 6, layer = 1 }) end
    anim('notes', e.x, e.y, { col = '#ffd84a', col2 = '#ff6a4a', n = 6, r = 12, dur = 0.9 })
    -- 一串音符从诗人飞到英雄
    local n = 6
    for i = 1, n do
        local u = i / n
        spark(e.x + (hero.x - e.x) * u, e.y - 8 + (hero.y - e.y) * u - sin(u * PI) * 8, 0, -6, 0.5 + u * 0.3, (i % 2 == 0) and '#ffe680' or '#ff8a6a', 2)
    end
end)

-- ===========================================================================
-- 6. 极光之灵「极光驱散」
-- ===========================================================================
SKILLS.aurora.name = '极光驱散'
SKILLS.aurora.desc = '极光扫过全场：驱散每个敌人身上的护盾、狂热和增益，并冻结 1 秒（首领减半）；我方全队解除负面状态、回复 12% 最大生命，3 秒内免疫控制'
X.aurora = function(B, e, t)
    local purged = A()
    for o in of(foesOf(B, e)) do
        local had = (o.shield or 0) > 0 or (o.haste or 0) > 0 or o.bAtk or o.bSpd or o.bDr or o.bLeech or (o.dodgeT or 0) > 0
        o.shield = 0; o.haste = 0; o.bAtk = nil; o.bSpd = nil; o.bDr = nil; o.bLeech = nil; o.dodgeT = 0
        if o.guard and not o.big then o.guard = nil; had = true end
        freeze(o, 1)
        if had then purged:push(o) end
    end
    for o in of(alliesOf(B, e)) do cleanse(o, true); healAmt(o, o.maxHp * 0.12); o.ccShield = max(o.ccShield or 0, 3) end
    e.s14purged = purged
end
-- 极光扫掠：一条竖直的彩色光带从施法者一侧扫到另一侧
D.s14_prism = function(a, k, x, y)
    local cols = { '#ff8ac8', '#b48cf0', '#6ef0ff', '#8affc8', '#fff6b0' }
    local X = a.x0 + (a.x1 - a.x0) * ease(k)
    local al = fade(k, 0.08, 0.25)
    for i, c in ipairs(cols) do
        local off = (i - 3) * 2 * a.dir
        for Y = 0, FIELD_H, 2 do
            actx.globalAlpha = al * (0.55 + 0.45 * sin(Y * 0.15 + G.time * 9 + i))
            px(X - off + sin(Y * 0.08 + G.time * 4) * 3, Y, 2, 2, c)
        end
    end
    actx.globalAlpha = 1
end
set('aurora', '#8affc8', '#ff8ac8', function(B, e, t, c)
    local dir = (e.side == 'p') and 1 or -1
    anim('s14_prism', 0, 0, { x0 = (dir > 0) and 0 or AW, x1 = (dir > 0) and AW or 0, dir = dir, dur = 0.8 })
    local purged = e.s14purged or A()
    e.s14purged = nil
    for o in of(purged) do
        anim('shatter', o.x, o.y, { col = '#ff8ac8', n = 10, v = 18, dur = 0.5 })
        P.ring(o.x, o.y, 2, 12, '#b48cf0', { thick = 1, dur = 0.35 })
    end
    for o in of(alliesOf(B, e)) do P.ring(o.x, o.y, 2, 9, '#8affc8', { thick = 1, dur = 0.4 }) end
end)

-- ===========================================================================
-- 7. 刃羽鹰「回旋羽刃」
-- ===========================================================================
SKILLS.featherstorm.name = '回旋羽刃'
SKILLS.featherstorm.desc = '掷出两枚回旋羽刃，分别从上下两侧画弧飞出再飞回：沿途的敌人每被划过一次受到 110% 伤害并流血 3 秒（飞出、飞回各算一次）'
X.featherstorm = function(B, e, t)
    local dir = (t and t.x < e.x) and -1 or 1
    local far = 0
    for o in of(foesOf(B, e)) do far = max(far, (o.x - e.x) * dir) end
    local L = clamp(far + 8, 60, 120)
    for _, side in ipairs({ -1, 1 }) do
        B.fields:push({ kind = 's14_boomer', src = e, dir = dir, side = side, L = L, W = 22, k = 0, dur = 1.3, x = e.x, y = e.y - 4, out = js.Set(), back = js.Set(), spin = 0 })
    end
end
FIELD_STEP.s14_boomer = function(B, f, dt)
    local e = f.src
    if e.dead then f.done = true; return end
    f.k = f.k + dt / f.dur
    f.spin = f.spin + dt * 20
    local k = min(1, f.k)
    f.x = e.x + f.dir * f.L * (1 - cos(TAU * k)) / 2
    f.y = e.y - 4 + f.side * f.W * sin(TAU * k)
    local hs = (k < 0.5) and f.out or f.back
    for o in of(foesOf(B, e)) do
        if not hs:has(o) and hypot(o.x - f.x, (o.y - 3) - f.y) <= 6 + o.r then
            hs:add(o)
            hit(e, o, e.atk * 1.1, { noLeech = true })
            if not o.dead then applyBleed(o, e, 3, e.atk * 0.45) end
            spark(o.x, o.y - 4, rand(-20, 20), rand(-20, 0), 0.3, '#ff3434')
        end
    end
    if f.k >= 1 then f.done = true end
end
FIELD_DRAW.s14_boomer = function(f)
    if f.done then return end
    -- 四片羽刃组成的旋转飞镖 + 银色拖尾
    for i = 1, 4 do
        local u = i * 0.02
        local k = max(0, f.k - u)
        local e = f.src
        local X = e.x + f.dir * f.L * (1 - cos(TAU * k)) / 2
        local Y = e.y - 4 + f.side * f.W * sin(TAU * k)
        actx.globalAlpha = 0.5 - i * 0.1
        px(X, Y, 1, 1, '#c9d2e0')
    end
    actx.globalAlpha = 1
    for j = 0, 3 do
        local an = f.spin + j / 4 * TAU
        local c, s = cos(an), sin(an)
        for r = 1, 4 do px(f.x + c * r, f.y + s * r * 0.8, 1, 1, (r >= 3) and '#ffffff' or '#9aa6c0') end
        px(f.x + c * 4 - s, f.y + s * 3.2 + c * 0.8, 1, 1, '#d8433a')
    end
    px(f.x, f.y, 1, 1, '#ffd84a')
end
set('featherstorm', '#c9d2e0', '#d8433a', function(B, e, t, c)
    P.arc(e.x, e.y, e.face, 12, '#c9d2e0', '#ffffff', 0.25)
    for i = 1, 6 do spark(e.x, e.y - 5, e.face * rand(10, 30), rand(-20, 20), 0.35, (i % 2 == 0) and '#c9d2e0' or '#ffffff') end
end)

-- ===========================================================================
-- 8. 炎羽隼「炎环收束」
-- ===========================================================================
SKILLS.flameraid.name = '炎环收束'
SKILLS.flameraid.desc = '在生命最高的敌人周围燃起一圈火环，2 秒内慢慢收紧：碰到火圈的敌人每 0.5 秒受到 35% 伤害并灼烧，圈里的小怪被逼向中心；收到最小时爆燃，中心的敌人受到 280% 伤害并灼烧 4 秒'
X.flameraid = function(B, e, t)
    local foes = foesOf(B, e):filter(targetable)
    local tgt = foes:slice():sort(function(a, b) return b.hp - a.hp end)[0] or t
    local near = foes:filter(function(o) return hypot(o.x - tgt.x, o.y - tgt.y) <= 30 end)
    local cx, cy = centroid(near)
    if not cx then cx, cy = tgt.x, tgt.y end
    B.fields:push({ kind = 's14_flamering', src = e, x = cx, y = cy, R0 = 40, R1 = 14, r = 40, t = 2, max = 2, tick = 0.5 })
end
FIELD_STEP.s14_flamering = function(B, f, dt)
    local e = f.src
    f.t = f.t - dt; f.tick = f.tick - dt
    local k = 1 - max(0, f.t) / f.max
    f.r = f.R0 + (f.R1 - f.R0) * ease(k)
    local doHit = f.tick <= 0
    if doHit then f.tick = f.tick + 0.5 end
    for o in of(foesOf(B, e)) do
        local dx, dy = o.x - f.x, (o.y - f.y) * 1.6
        local d = hypot(dx, dy)
        if d <= f.r + 4 and d >= f.r - 6 - o.r and doHit and not e.dead then
            hit(e, o, e.atk * 0.35, { noLeech = true, noCrit = true })
            if not o.dead then applyBurn(o, e, 2, e.atk * 0.4) end
        end
        if d < f.r + 2 and d > f.r - 5 and not o.big and not o.anchor and not o.immune and d > 0.1 then -- 往圈里赶
            local nd = f.r - 5
            o.x = clamp(f.x + dx / d * nd, 6, AW - 6)
            o.y = clamp(f.y + dy / d * nd / 1.6, 14, FIELD_H - 10)
        end
    end
    if f.t <= 0 then
        f.done = true
        if e.dead then return end
        for o in of(foesOf(B, e)) do
            if hypot(o.x - f.x, (o.y - f.y) * 1.6) <= f.R1 + 6 + o.r then
                hit(e, o, e.atk * 2.8, { noLeech = true })
                if not o.dead then applyBurn(o, e, 4, e.atk * 0.5) end
            end
        end
        G.shake = max(G.shake, 0.3)
        if not REDUCED then
            P.ring(f.x, f.y, 3, 30, '#ffb04a', { thick = 3, dur = 0.45 })
            P.disk(f.x, f.y, 4, 22, '#ff6a2a', 0.4, 0.5)
            P.pillar(f.x, f.y, '#ff6a2a', '#ffe14a', 40, 10, 0.5)
            for i = 1, 22 do local an = rand(0, TAU); spark(f.x, f.y, cos(an) * rand(20, 60), sin(an) * rand(10, 30) - 20, 0.6, (i % 3 == 0) and '#ffe14a' or '#ff8a2a', 1, 40) end
            FX.sound('hit')
        end
    end
end
FIELD_DRAW.s14_flamering = function(f)
    if f.done then return end
    local al = clamp((f.max - f.t) / 0.2, 0, 1)
    local n = max(24, floor(f.r * 2.2))
    for j = 0, n - 1 do
        local an = j / n * TAU
        local X, Y = f.x + cos(an) * f.r, f.y + 4 + sin(an) * f.r / 1.6
        local h = 2 + floor((sin(an * 5 + G.time * 18) + 1) * 1.5)
        actx.globalAlpha = al * ((sin(an) < 0) and 0.7 or 1)
        px(X, Y - h, 1, h, '#ff6a2a'); px(X, Y - h, 1, 1, '#ffe14a')
        if j % 3 == 0 then px(X, Y, 1, 1, '#ffffff') end
    end
    actx.globalAlpha = al * 0.18
    disk(f.x, f.y + 4, f.r, 1 / 1.6, '#ff8a2a')
    actx.globalAlpha = 1
    if js.random() < 0.5 then local an = rand(0, TAU); spark(f.x + cos(an) * f.r, f.y + 3 + sin(an) * f.r / 1.6, 0, -rand(10, 24), 0.4, '#ffb04a') end
end
set('flameraid', '#ff8a2a', '#ffe14a', function(B, e, t, c)
    -- 火羽从炎羽隼飞向火环中心
    for f in of(B.fields) do
        if f.kind == 's14_flamering' and f.src == e and f.t >= f.max - 0.01 then
            for i = 1, 10 do local u = i / 10; spark(e.x + (f.x - e.x) * u, e.y - 6 + (f.y - e.y) * u - sin(u * PI) * 14, 0, -4, 0.3 + u * 0.3, (i % 2 == 0) and '#ffe14a' or '#ff6a2a', 2) end
            P.ring(f.x, f.y, f.R0 - 6, f.R0 + 2, '#ffb04a', { thick = 1, dur = 0.4 })
        end
    end
end)

-- ===========================================================================
-- 9. 天空猎手「夺声俯冲」
-- ===========================================================================
SKILLS.divebomb.name = '夺声俯冲'
SKILLS.divebomb.desc = '俯冲攻击最高、会放技能的敌人（优先施法者）：造成 280% 伤害，打断它正在积蓄的技能（能量清零），并沉默 3 秒（首领 1.5 秒）不能积蓄能量'
X.divebomb = function(B, e, t)
    local foes = foesOf(B, e):filter(targetable)
    local tgt = foes:slice():sort(function(a, b)
        local sa, sb = a.skill and 1 or 0, b.skill and 1 or 0
        if sa ~= sb then return sb - sa end
        return b.atk - a.atk
    end)[0] or t
    if not tgt then return end
    local ox, oy = e.x, e.y
    local function beside()
        local dir = (tgt.x >= ox) and 1 or -1
        return tgt.x - dir * (tgt.r + e.r + 1), tgt.y
    end
    local function strike(B2, e2)
        e2.face = (tgt.x >= e2.x) and 1 or -1
        if tgt.dead then return end
        hit(e2, tgt, e2.atk * 2.8, { melee = true, noLeech = true })
        if not tgt.dead then
            if tgt.skill then tgt.energy = 0 end
            tgt.silT = max(tgt.silT or 0, tgt.big and 1.5 or 3)
            if not REDUCED then add({ kind = 's14_silence', ent = tgt, dur = tgt.silT, layer = 1 }) end
        end
        if not REDUCED then
            P.xslash(tgt.x, tgt.y, '#ffe680', '#ffffff', 8)
            P.ring(tgt.x, tgt.y, 2, 16, '#e6edf7', { thick = 1, dur = 0.35 })
            for i = 1, 8 do spark(tgt.x, tgt.y - 4, rand(-30, 30), rand(-30, 0), 0.5, (i % 2 == 0) and '#e6edf7' or '#c9b88a', 1, 30) end
        end
        FX.burst(tgt.x, tgt.y - 4, '#ffe14a', 6); Sound.play('zap')
    end
    e.s14dive = { x = tgt.x, y = tgt.y }
    startFlight(B, e, {
        { dur = 0.18, to = { ox, oy }, z = 28 },
        { dur = 0.2, to = beside, z = 6 },
        { dur = 0.06, to = beside, z = 0, fn = strike },
        { dur = 0.3, to = { ox, oy }, z = 18 },
        { dur = 0.1, to = { ox, oy }, z = 0 },
    })
end
local _gainEnergy = gainEnergy
function gainEnergy(e, n)
    if (e.silT or 0) > 0 then return end
    return _gainEnergy(e, n)
end
-- 沉默：头顶一个划掉的音符
D.s14_silence = function(a, k, x, y)
    local o = a.ent
    if o.dead or (o.silT or 0) <= 0 then return end
    local X, Y = o.x + 5, o.y - (o.big and 26 or 16) + sin(G.time * 4) * 1
    actx.globalAlpha = fade(k, 0.05, 0.1)
    px(X - 1, Y + 2, 2, 2, '#e6edf7'); px(X + 1, Y - 2, 1, 5, '#e6edf7'); px(X + 2, Y - 2, 1, 1, '#e6edf7')
    for i = -3, 3 do px(X + i, Y + i * 0.6 + 0.5, 1, 1, '#ff4a3a') end
    actx.globalAlpha = 1
end
-- 俯冲轨迹：从高空划下的一道弧光，羽毛散落
D.s14_dive = function(a, k, x, y)
    local al = 1 - k
    local n = 18
    for i = 0, n do
        local u = i / n
        if u <= min(1, k * 3) then
            local X = a.x0 + (a.x1 - a.x0) * u
            local Y = a.y0 - 40 * (1 - u) * (1 - u) + (a.y1 - a.y0) * u
            actx.globalAlpha = al * (0.4 + 0.6 * u)
            px(X, Y, (u > 0.8) and 2 or 1, 1, (u > 0.8) and '#ffffff' or '#ffe680')
        end
    end
    actx.globalAlpha = 1
end
set('divebomb', '#ffe680', '#ffffff', function(B, e, t, c)
    local d = e.s14dive
    e.s14dive = nil
    if not d then return end
    P.ring(e.x, e.y, 3, 14, '#ffe680', { thick = 2, dur = 0.3 })
    anim('s14_dive', 0, 0, { x0 = e.x, y0 = e.y - 10, x1 = d.x, y1 = d.y - 4, dur = 0.45 })
    P.ring(d.x, d.y, 14, 3, '#e6edf7', { thick = 1, dur = 0.45 })
end)

-- ===========================================================================
-- 10. 白虎「虎影」
-- ===========================================================================
SKILLS.ambush.name = '虎影'
SKILLS.ambush.desc = '化出 3 道白色虎影，各扑向一个不同的敌人（优先生命最高的）：每道 160% 伤害且必定暴击，被扑中的敌人 4 秒内受到的伤害 +20%'
X.ambush = function(B, e, t)
    local foes = foesOf(B, e):filter(targetable):sort(function(a, b) return b.hp - a.hp end)
    local list = foes:slice(0, 3)
    if #list == 0 and t then list = A(t) end
    strikeAt(e)
    e.s14tigers = list
    for o in of(list) do
        hit(e, o, e.atk * 1.6, { melee = true, forceCrit = true })
        if not o.dead then applyCurse(o, 4, 0.2, 0) end
    end
end
-- 虎影：白色半透明的扑击残影，带三道爪痕
D.s14_tigerghost = function(a, k, x, y)
    local u = min(1, k / 0.45)
    local X = a.x0 + (a.x1 - a.x0) * ease(u)
    local Y = a.y0 + (a.y1 - a.y0) * ease(u) - sin(u * PI) * 10
    local f = (a.x1 >= a.x0) and 1 or -1
    if k < 0.55 then
        for i = 0, 3 do -- 拖尾
            local uu = max(0, u - i * 0.08)
            local XX = a.x0 + (a.x1 - a.x0) * ease(uu)
            local YY = a.y0 + (a.y1 - a.y0) * ease(uu) - sin(uu * PI) * 10
            actx.globalAlpha = (0.6 - i * 0.14)
            px(XX - 4, YY - 6, 8, 4, '#e6edf7')
        end
        actx.globalAlpha = 0.9
        -- 虎身：白底黑纹
        px(X - 5, Y - 7, 10, 5, '#ffffff'); px(X + f * 4, Y - 9, 3, 4, '#ffffff')
        px(X - 3, Y - 7, 1, 4, '#1b1530'); px(X, Y - 7, 1, 4, '#1b1530'); px(X + 3 * f, Y - 7, 1, 3, '#1b1530')
        px(X + f * 5, Y - 8, 1, 1, '#6ef0ff')
    else
        local q = (k - 0.55) / 0.45
        actx.globalAlpha = 1 - q
        for i = -1, 1 do
            for j = 0, 6 do px(a.x1 - 3 + j + i * 3, a.y1 - 9 + j + i, 1, 1, (j > 1 and j < 5) and '#ffffff' or '#cfe3ff') end
        end
    end
    actx.globalAlpha = 1
end
set('ambush', '#ffffff', '#6ef0ff', function(B, e, t, c)
    local list = e.s14tigers
    e.s14tigers = nil
    if not list then return end
    for i, o in ipairs({ list[0], list[1], list[2] }) do
        if o then anim('s14_tigerghost', 0, 0, { x0 = e.x, y0 = e.y, x1 = o.x, y1 = o.y, dur = 0.6, delay = (i - 1) * 0.08 }) end
    end
    P.ring(e.x, e.y, 2, 14, '#ffffff', { thick = 1, dur = 0.3 })
end)

-- ===========================================================================
-- 11. 雪舞者「冰径」
-- ===========================================================================
SKILLS.blizzardcall.name = '冰径'
SKILLS.blizzardcall.desc = '朝目标方向铺出一条长长的冰路（持续 5 秒）：冰面上的敌人减速 60%，每 0.5 秒受到 30% 伤害，并有 20% 几率滑倒（眩晕 0.6 秒，首领不会滑倒）'
X.blizzardcall = function(B, e, t)
    local dx, dy = (t and t.x or e.x + e.face) - e.x, (t and t.y or e.y) - e.y
    local d = hypot(dx, dy)
    if d < 1 then dx, dy, d = e.face, 0, 1 end
    local ux, uy = dx / d, dy / d
    local x1, y1 = e.x + ux * 10, e.y + uy * 10
    local x2, y2 = clamp(e.x + ux * 140, 2, AW - 2), clamp(e.y + uy * 140, 12, FIELD_H - 6)
    B.fields:push({ kind = 's14_icepath', src = e, x = (x1 + x2) / 2, y = (y1 + y2) / 2, x1 = x1, y1 = y1, x2 = x2, y2 = y2, w = 8, t = 5, max = 5, tick = 0.5 })
end
FIELD_STEP.s14_icepath = function(B, f, dt)
    local e = f.src
    f.t = f.t - dt; f.tick = f.tick - dt
    if f.tick <= 0 then
        f.tick = f.tick + 0.5
        for o in of(foesOf(B, e)) do
            if segDist(o.x, o.y, f.x1, f.y1, f.x2, f.y2) <= f.w + o.r then
                if not e.dead then hit(e, o, e.atk * 0.3, { noLeech = true, noCrit = true }) end
                if not o.dead then
                    applySlow(o, 1, 0.6)
                    if not o.big and not o.anchor and js.random() < 0.2 then
                        stunT(o, 0.6)
                        if not REDUCED then FX.float(o.x, o.y - 14, '滑倒', '#bff4ff') end
                    end
                end
            end
        end
    end
    if f.t <= 0 then f.done = true end
end
FIELD_DRAW.s14_icepath = function(f)
    if f.done then return end
    local al = clamp((f.max - f.t) / 0.3, 0, 1) * clamp(f.t / 0.5, 0, 1)
    local L = hypot(f.x2 - f.x1, f.y2 - f.y1)
    if L < 1 then return end
    local ux, uy = (f.x2 - f.x1) / L, (f.y2 - f.y1) / L
    local grow = clamp((f.max - f.t) / 0.35, 0, 1)
    for s = 0, L * grow, 2 do
        for w = -f.w, f.w, 2 do
            local X = f.x1 + ux * s - uy * w * 0.5
            local Y = f.y1 + 5 + uy * s + ux * w * 0.5
            local edge = abs(w) >= f.w - 1
            local glint = ((floor(s / 2) + floor(G.time * 12)) % 17 == floor((w + f.w) / 2) % 17)
            actx.globalAlpha = al * (edge and 0.85 or 0.45)
            px(X, Y, 2, 1, glint and '#ffffff' or (edge and '#7fd0ff' or '#bff4ff'))
        end
    end
    actx.globalAlpha = 1
    if js.random() < 0.3 then
        local s = rand(0, L)
        spark(f.x1 + ux * s, f.y1 + 4 + uy * s, 0, -rand(4, 10), 0.4, '#ffffff')
    end
end
set('blizzardcall', '#bff4ff', '#7fd0ff', function(B, e, t, c)
    P.ring(e.x, e.y, 2, 12, '#bff4ff', { thick = 1, dur = 0.35 })
    for i = 1, 8 do spark(e.x, e.y - 4, rand(-20, 20), rand(-20, 0), 0.4, '#ffffff') end
end)

-- ---------------------------------------------------------------------------
-- 机制：伤害转移（守护誓约）、鳞刃反击（翠玉鳞刃）、计时
-- ---------------------------------------------------------------------------
local _hit = hit
function hit(src, t, base, o)
    local L = t.oath
    if L and L.t > 0 and not t.dead and src and src.side ~= t.side and not (o and (o.dot or o.shared or o.reflect)) then
        local g = L.by
        if g and not g.dead and g ~= t then
            o = o or {}
            if not REDUCED and js.random() < 0.35 then spark(t.x, t.y - 6, (g.x - t.x) * 2, (g.y - t.y) * 2, 0.3, '#ffd84a') end
            return _hit(src, g, base, { noCrit = o.noCrit, forceCrit = o.forceCrit, noLeech = o.noLeech, melee = o.melee, ranged = o.ranged, shared = true })
        end
    end
    local dmg = _hit(src, t, base, o)
    if (t.jadeT or 0) > 0 and dmg and dmg > 0 and not t.dead and src and src ~= t and src.side ~= t.side and not src.dead
        and not (o and (o.dot or o.reflect)) and (t.jadeCd or 0) <= 0 and G.battle then
        t.jadeCd = 0.33
        shoot(G.battle, t, src, 'jadeshard', { speed = 230, mul = 0.7, big = true })
    end
    return dmg
end
addHook('step', function(B, dt, alive)
    for e in of(alive) do
        if e.oath then
            e.oath.t = e.oath.t - dt
            if e.oath.t <= 0 or e.oath.by.dead then e.oath = nil end
        end
        if (e.jadeT or 0) > 0 then
            e.jadeT = e.jadeT - dt; e.jadeCd = (e.jadeCd or 0) - dt
            if e.jadeT <= 0 and not B.over then -- 鳞甲收起：身边队友护盾
                for o in of(alliesOf(B, e)) do
                    if o ~= e and hypot(o.x - e.x, o.y - e.y) <= 40 then
                        shieldPct(o, 0.15)
                        if not REDUCED then P.shield(o, '#6fdc8a', 8) end
                    end
                end
                if not REDUCED then for i = 1, 10 do local an = rand(0, TAU); spark(e.x, e.y - 4, cos(an) * 30, sin(an) * 14, 0.5, '#6fdc8a') end end
            end
        end
        if (e.silT or 0) > 0 then e.silT = e.silT - dt end
    end
end)

-- 场地：步进与画法登记
local _stepHazard = stepHazard
function stepHazard(B, f, dt)
    local fn = FIELD_STEP[f.kind]
    if fn then
        if not f.done then fn(B, f, dt) end
        return
    end
    return _stepHazard(B, f, dt)
end

-- 路线的定位说明跟着技能改
if BRANCHES.guardbear then BRANCHES.guardbear.role = '替队友挨打' end
if BRANCHES.ironback then BRANCHES.ironback.role = '冲阵嘲讽' end
if BRANCHES.galewing then BRANCHES.galewing.role = '龙卷控场' end
if BRANCHES.warbard then BRANCHES.warbard.role = '单体强化' end
if BRANCHES.auroraspirit then BRANCHES.auroraspirit.role = '驱散控场' end
if BRANCHES.skyhunter then BRANCHES.skyhunter.role = '打断施法' end
if BRANCHES.whitetiger then BRANCHES.whitetiger.role = '多目标暴击' end
if BRANCHES.snowdancer then BRANCHES.snowdancer.role = '冰路控场' end

SKILLS14_REWORKED = { 'ironwall', 'bulwark', 'jadescale', 'tailwind', 'warhymn', 'aurora', 'featherstorm', 'flameraid', 'divebomb', 'ambush', 'blizzardcall' }

return true
