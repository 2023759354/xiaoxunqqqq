-- ============================================================================
-- 新兵种的技能与机制（古树卫士 / 雷鹰 / 发条机兵）
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local T = js.T
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, max, min, atan, sin, cos = math.floor, js.max, math.min, math.atan, math.sin, math.cos
local of = js.of

local function byHpFrac(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end
local function near(B, e, x, y, r) return foesOf(B, e):filter(function(o) return hypot(o.x - x, o.y - y) <= r end) end
local function taunt(B, e, r) for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= r then o.target = e end end end
local function root(o, d) if not o.dead and not o.ccImmune then o.root = max(o.root or 0, o.big and d * 0.5 or d) end end
local function stunT(o, d) if not o.dead then o.stun = max(o.stun, o.big and d * 0.5 or d) end end

EXT_SKILLS = {}
local X = EXT_SKILLS
-- —— 古树卫士 ——
X.rootguard = function(B, e, t)
    taunt(B, e, 60)
    e.shield = min(e.maxHp, (e.shield or 0) + e.maxHp * 0.25)
    e.hot = { t = 4, tick = 1, pct = 0.04 }
    FX.ring(e.x, e.y, 26, '#6fbf5a'); FX.particle(e.x, e.y + 6, '#4fbf4a', 14, 40, 60, 0.6)
end
X.barkskin = function(B, e, t)
    e.guard = { t = 5, dr = 0.4 }; e.thornAura = { t = 5, v = 0.3 }
    FX.ring(e.x, e.y, 14, '#9b6a3c'); FX.particle(e.x, e.y, '#c9955a', 12, 40, 20, 0.5)
end
X.brambleburst = function(B, e, t)
    for o in of(near(B, e, e.x, e.y, 28)) do hit(e, o, e.atk * 1.2, { noLeech = true }); root(o, 1.5) end
    FX.ring(e.x, e.y, 26, '#4fbf4a'); FX.thorns(e.x + 10, e.y); FX.thorns(e.x - 8, e.y + 4)
end
X.mossheal = function(B, e, t)
    for o in of(alliesOf(B, e)) do
        if hypot(o.x - e.x, o.y - e.y) <= 44 then healAmt(o, o.maxHp * 0.15); o.hot = { t = 4, tick = 1, pct = 0.04 }; FX.ring(o.x, o.y, 8, '#9be36b') end
    end
end
X.timberslam = function(B, e, t)
    strikeAt(e)
    for o in of(foesOf(B, e)) do
        local dx, dy = o.x - e.x, o.y - e.y
        if hypot(dx, dy) <= 36 and dx * e.face >= -4 then hit(e, o, e.atk * 2.2, { noLeech = true, melee = true }); stunT(o, 1) end
    end
    FX.ring(e.x + e.face * 14, e.y, 20, '#c9b08a'); FX.particle(e.x + e.face * 14, e.y + 6, '#8a6a4a', 18, 60, 110, 0.5); G.shake = max(G.shake --[[@as number]], 0.25)
end
X.rootnet = function(B, e, t)
    for o in of(near(B, e, e.x, e.y, 50)) do hit(e, o, e.atk * 0.6, { noLeech = true }); root(o, 2.5); o.target = e end
    FX.ring(e.x, e.y, 46, '#2f7a34'); FX.ring(e.x, e.y, 30, '#4fbf4a')
end
X.lifegrove = function(B, e, t)
    B.fields:push({ kind = 'grove', x = e.x, y = e.y, r = 44, t = 6, max = 6, tick = 1, src = e })
    FX.ring(e.x, e.y, 40, '#bff0c8')
end
X.uproot = function(B, e, t)
    strikeAt(e)
    for o in of(near(B, e, e.x, e.y, 36)) do
        hit(e, o, e.atk * 2, { noLeech = true, melee = true })
        if not o.dead then stunT(o, 1); if not o.big then o.x = clamp(o.x + ((o.x >= e.x) and 14 or -14), 6, AW - 6) end end
    end
    healAmt(e, e.maxHp * 0.15)
    FX.ring(e.x, e.y, 34, '#ffd84a'); FX.quake(e.x, e.y); G.shake = max(G.shake --[[@as number]], 0.3)
end
X.bloodgrove = function(B, e, t)
    for o in of(foesOf(B, e)) do
        hit(e, o, e.atk * 2); root(o, 2); if not o.dead then applyBleed(o, e, 4, e.atk * 0.5) end
        FX.thorns(o.x, o.y)
    end
    for o in of(alliesOf(B, e)) do o.shield = min(o.maxHp, (o.shield or 0) + o.maxHp * 0.25); FX.ring(o.x, o.y, 9, '#ff3434') end
    B.tint = { t = 0.4, max = 0.4, rgb = '150,10,40' }; G.shake = max(G.shake --[[@as number]], 0.3)
end
-- —— 雷鹰 ——
local function stormField(B, e, x, y, dur, r, mul)
    B.fields:push({ kind = 'storm', x = x, y = y, r = r or 22, t = dur, max = dur, tick = 0.5, src = e, mul = mul or 0.4 })
end
X.thunderstorm = function(B, e, t) stormField(B, e, t.x, t.y, 4); Sound.play('zap') end
X.galestrike = function(B, e, t)
    local foes = foesOf(B, e)
    for i = 0, 3 do shoot(B, e, pick(foes), 'zap', { delay = i * 0.08, mul = 0.9, stunChance = 0.3 }) end
end
X.divebomb = function(B, e, t)
    local tgt = foesOf(B, e):filter(function(o) return not o.immune end):sort(byHpFrac)[0] or t
    shoot(B, e, tgt, 'zap', { speed = 360, mul = 3.2, killRefund = 50, big = true })
end
X.tailwind = function(B, e, t)
    for o in of(alliesOf(B, e)) do o.haste = max(o.haste or 0, 3); o.dodgeT = 3; FX.ring(o.x, o.y, 8, '#bff4ff') end
end
X.ballstorm = function(B, e, t)
    local foes = foesOf(B, e)
    for i = 0, 2 do
        local o = foes[i % max(1, #foes)] or t
        shoot(B, e, o, 'ball', { delay = i * 0.15, speed = 70, area = true, splash = 20, mul = 1.4, stunHit = 0.5 })
    end
end
X.featherstorm = function(B, e, t)
    foesOf(B, e):forEach(function(o, i)
        shoot(B, e, o, 'feather', { x = o.x + rand(-10, 10), y = -6, speed = 200, delay = i * 0.05, mul = 1, bleedP = true })
    end)
end
X.skyfury = function(B, e, t)
    local foes = foesOf(B, e)
    for i = 0, 5 do
        local o = pick(foes)
        if o and not o.dead then
            hit(e, o, e.atk * 2); stunT(o, 0.6); FX.bolt(o.x + rand(-6, 6), 0, o.x, o.y - 3)
        end
    end
    Sound.play('zap'); B.tint = { t = 0.35, max = 0.35, rgb = '255,240,140' }; G.shake = max(G.shake --[[@as number]], 0.25)
end
X.flameraid = function(B, e, t)
    local dx, dy = t.x - e.x, (t.y - 3) - (e.y - 3)
    local d = hypot(dx, dy); if d == 0 then d = 1 end
    shoot(B, e, nil, 'fireline', { pierce = true, vx = dx / d, vy = dy / d, ang = atan(dy, dx), speed = 260, mul = 3, hitSet = js.Set(), burn = { t = 3, dps = e.atk * 0.4 } })
end
X.crimsonstorm = function(B, e, t)
    local foes = foesOf(B, e)
    local cx, cy, n = 0, 0, 0
    for o in of(foes) do hit(e, o, e.atk * 2.5); stunT(o, 1); FX.bolt(o.x, 0, o.x, o.y - 3); cx = cx + o.x; cy = cy + o.y; n = n + 1 end
    if n > 0 then stormField(B, e, cx / n, cy / n, 5, 30, 0.5) end
    B.tint = { t = 0.5, max = 0.5, rgb = '200,20,40' }; G.shake = max(G.shake --[[@as number]], 0.35); Sound.play('zap')
end
-- —— 发条机兵 ——
local function overloadOn(o, d) o.overT = max(o.overT or 0, d); FX.ring(o.x, o.y, 8, '#ffb04a') end
X.overload = function(B, e, t)
    overloadOn(e, 4); e.overSelf = true
    for o in of(alliesOf(B, e)) do if o ~= e and hypot(o.x - e.x, o.y - e.y) <= 34 then overloadOn(o, 4) end end
    FX.particle(e.x, e.y - 4, '#ffe14a', 12, 50, 20, 0.5)
end
X.gearshot = function(B, e, t)
    local foes = foesOf(B, e):sort(function(a, b) return hypot(a.x - e.x, a.y - e.y) - hypot(b.x - e.x, b.y - e.y) end)
    for i = 0, 4 do local o = foes[i % max(1, #foes)]; if o then shoot(B, e, o, 'gear', { delay = i * 0.07, mul = 0.8 }) end end
end
X.steamburst = function(B, e, t)
    for o in of(near(B, e, e.x, e.y, 28)) do
        hit(e, o, e.atk * 1.5, { noLeech = true }); applySlow(o, 3, 0.4)
        if not o.big and not o.dead then local dx, dy = o.x - e.x, o.y - e.y; local d = max(1, hypot(dx, dy)); o.x = clamp(o.x + dx / d * 16, 6, AW - 6); o.y = clamp(o.y + dy / d * 10, 14, FIELD_H - 10) end
    end
    e.shield = min(e.maxHp, (e.shield or 0) + e.maxHp * 0.2)
    FX.ring(e.x, e.y, 26, '#e6edf7'); FX.particle(e.x, e.y, '#ffffff', 22, 70, -20, 0.6)
end
X.repair = function(B, e, t)
    alliesOf(B, e):filter(function(o) return o.hp < o.maxHp end):sort(byHpFrac):slice(0, 2):forEach(function(o) healAmt(o, o.maxHp * 0.3); o.stun = 0; FX.ring(o.x, o.y, 9, '#8fe07a') end)
end
X.artillery = function(B, e, t)
    for i = 0, 2 do
        local px = clamp(t.x + rand(-14, 14), 6, AW - 6)
        local py = clamp(t.y + rand(-12, 12), 14, FIELD_H - 10)
        shoot(B, e, nil, 'shell', { x = e.x, y = e.y - 8, tx = px, ty = py, speed = 120, delay = i * 0.2, area = true, splash = 20, mul = 1.8 })
    end
end
X.magnetpulse = function(B, e, t)
    for o in of(near(B, e, t.x, t.y, 50)) do
        if not o.big then local dx, dy = t.x - o.x, t.y - o.y; local d = max(1, hypot(dx, dy)); local k = min(d - 4, 18); o.x = o.x + dx / d * max(0, k); o.y = o.y + dy / d * max(0, k) end
        o.shield = 0; hit(e, o, e.atk * 1.2)
    end
    FX.ring(t.x, t.y, 40, '#6ef0ff'); FX.ring(t.x, t.y, 20, '#ffffff')
end
X.missilebarrage = function(B, e, t)
    local foes = foesOf(B, e)
    for i = 0, 9 do shoot(B, e, pick(foes), 'missile', { delay = i * 0.06, speed = 170, mul = 1.2, splash = 10, splashMul = 0.5 }) end
end
X.rewind = function(B, e, t)
    for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.25); if o ~= e and o.skill then gainEnergy(o, 40) end; FX.ring(o.x, o.y, 8, '#e0b0ff') end
    B.tint = { t = 0.4, max = 0.4, rgb = '180,140,240' }
end
X.redprotocol = function(B, e, t)
    local mine = minionsOf(B, e)
    if #mine < 2 then
        for i = #mine, 1 do
            local m = spawnMinion(B, { x = e.x - 10, y = e.y + ((i % 2 ~= 0) and 18 or -18), owner = e, maxHp = round(e.maxHp * 0.7), atk = round(e.atk * 0.6), cd = 0.35,
                crit = e.crit, range = 90, speed = 0, proj = 'gear', anchor = true, mspr = 'turret', mpal = { b = '#7a1f2b', B = '#ff3434', h = '#a8102a' }, mkey = 'redturret' })
            FX.particle(m.x, m.y, '#ff3434', 14, 50, 60, 0.5)
        end
    else mine:forEach(function(o) o.hp = o.maxHp; FX.ring(o.x, o.y, 8, '#ff3434') end) end
    for o in of(alliesOf(B, e)) do overloadOn(o, 4) end
    B.tint = { t = 0.3, max = 0.3, rgb = '200,20,40' }
end

local _castSkill = castSkill
function castSkill(B, e, t)
    local f = EXT_SKILLS[e.skill]
    if not f then return _castSkill(B, e, t) end
    FX.skill(e, SKILLS[e.skill].name)
    f(B, e, t)
end

-- ---------------------------------------------------------------------------
-- 机制：机械免疫 DoT、控制时间 +50%；过载；电场；林地
-- ---------------------------------------------------------------------------
local _applyBurn, _applyBleed, _addPoison = applyBurn, applyBleed, addPoison
function applyBurn(t, ...) if t.mech then return end return _applyBurn(t, ...) end
function applyBleed(t, ...) if t.mech then return end return _applyBleed(t, ...) end
function addPoison(t, ...) if t.mech then return end return _addPoison(t, ...) end

addHook('step', function(B, dt, alive)
    for e in of(alive) do
        if (e.overT or 0) > 0 then
            e.overT = e.overT - dt
            if e.overT <= 0 and e.overSelf then e.overSelf = false; e.stun = max(e.stun, 1) end -- 过载结束：自身眩晕 1 秒
        end
        if (e.dodgeT or 0) > 0 then e.dodgeT = e.dodgeT - dt end
        if e.mech and e.stun > 0 and not e.ccImmune then e.stun = e.stun + dt / 3 end -- 机械：控制时间 +50%
    end
end)
-- 攻速倍率：logic.stepBattle 读取过载状态。
OVERLOAD_SPD = 1.6

local _stepHazard = stepHazard
function stepHazard(B, f, dt)
    if f.kind == 'storm' then
        f.t = f.t - dt; f.tick = f.tick - dt
        if f.tick <= 0 then
            f.tick = f.tick + 0.5
            for o in of(foesOf(B, f.src)) do
                if hypot(o.x - f.x, (o.y - f.y) * 1.4) <= f.r then
                    hit(f.src, o, f.src.atk * f.mul, { noLeech = true, noCrit = true })
                    if not o.dead and js.random() < 0.25 then o.stun = max(o.stun, 0.3) end
                end
            end
            local a = js.random() * 6.283
            FX.bolt(f.x, f.y - 20, f.x + cos(a) * f.r * 0.6, f.y + sin(a) * f.r * 0.4)
        end
        if f.t <= 0 then f.done = true end
        return
    end
    if f.kind == 'grove' then
        f.t = f.t - dt; f.tick = f.tick - dt
        if f.tick <= 0 then
            f.tick = f.tick + 1
            for o in of(B.ents) do
                if not o.dead and hypot(o.x - f.x, (o.y - f.y) * 1.4) <= f.r then
                    if o.side == f.src.side then healAmt(o, o.maxHp * 0.04) else applySlow(o, 1.2, 0.3) end
                end
            end
        end
        if f.t <= 0 then f.done = true end
        return
    end
    return _stepHazard(B, f, dt)
end

-- 投射物的附加效果：麻痹几率、流血
local _procHit = procHit
function procHit(p, o)
    _procHit(p, o)
    if o.dead then return end
    if T(p.stunChance) and js.random() < p.stunChance then o.stun = max(o.stun, 0.3) end
    if p.bleedP then applyBleed(o, p.src, 3, p.src.atk * 0.45) end
    if p.basic and T(p.src.bleedHitR) and js.random() < p.src.bleedHitR then applyBleed(o, p.src, 3, p.src.atk * 0.45) end
end

-- 新投射物的画法：沿用现有 Canvas/NanoVG 桥接，不创建额外上下文。
local function line(p, c, s, n, cols)
    for i = 0, n - 1 do actx.fillStyle = cols(i); actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1) end
end
PROJ_DRAW.zap = function(p, c, s)
    line(p, c, s, p.big and 7 or 4, function(i) return (i == 0) and '#ffffff' or ((i % 2 == 0) and '#ffe14a' or '#78a8f2') end)
    if js.random() < 0.4 then FX.parts:push({ x = p.x + rand(-1, 1), y = p.y + rand(-1, 1), vx = 0, vy = 0, g = 0, life = 0.2, max = 0.2, color = '#ffe14a', size = 1 }) end
end
PROJ_DRAW.gear = function(p, c, s)
    local x, y = round(p.x), round(p.y)
    actx.fillStyle = '#9a6f1c'; actx:fillRect(x - 1, y - 1, 3, 3)
    actx.fillStyle = (floor(G.time * 16) % 2 == 0) and '#ffe27a' or '#e2b33c'; actx:fillRect(x - 2, y, 1, 1); actx:fillRect(x + 2, y, 1, 1); actx:fillRect(x, y - 2, 1, 1); actx:fillRect(x, y + 2, 1, 1)
end
PROJ_DRAW.ball = function(p, c, s)
    local x, y = round(p.x), round(p.y)
    actx.fillStyle = '#78a8f2'; actx:fillRect(x - 2, y - 1, 5, 3); actx:fillRect(x - 1, y - 2, 3, 5)
    actx.fillStyle = '#ffffff'; actx:fillRect(x, y, 1, 1)
    if js.random() < 0.5 then FX.bolt(p.x, p.y, p.x + rand(-6, 6), p.y + rand(-6, 6)) end
end
PROJ_DRAW.feather = function(p, c, s) line(p, c, s, 5, function(i) return (i == 0) and '#ffffff' or ((i < 3) and '#ff8a7a' or '#d8433a') end) end
PROJ_DRAW.fireline = function(p, c, s)
    line(p, c, s, 12, function(i) return (i < 2) and '#ffffff' or ((i < 6) and '#ffe14a' or '#ff8a2a') end)
    if js.random() < 0.7 then FX.parts:push({ x = p.x - c * rand(2, 10), y = p.y + rand(-2, 2), vx = rand(-6, 6), vy = -10, g = 0, life = 0.35, max = 0.35, color = '#ff5a2a', size = 1 }) end
end
PROJ_DRAW.shell = function(p, c, s)
    local x, y = round(p.x), round(p.y)
    actx.fillStyle = '#3a2d52'; actx:fillRect(x - 1, y - 1, 3, 3); actx.fillStyle = '#ff8a2a'; actx:fillRect(x, y, 1, 1)
end
PROJ_DRAW.missile = function(p, c, s)
    line(p, c, s, 4, function(i) return (i == 0) and '#d8433a' or ((i == 1) and '#e6edf7' or '#ffb04a') end)
    if js.random() < 0.6 then FX.parts:push({ x = p.x - c * 4, y = p.y - s * 4, vx = 0, vy = 0, g = 0, life = 0.25, max = 0.25, color = '#8d9ab2', size = 1 }) end
end
FIELD_DRAW.storm = function(f)
    local a = clamp(f.t / 0.5, 0, 1)
    actx.globalAlpha = a * 0.8
    for i = 0, 15 do
        local ang = i / 16 * 6.283 + G.time * 2
        actx.fillStyle = (i % 3 == 0) and '#ffffff' or '#ffe14a'
        actx:fillRect(round(f.x + cos(ang) * f.r), round(f.y + sin(ang) * f.r / 1.4), 1, 1)
    end
    actx.fillStyle = 'rgba(120,168,242,0.15)'
    for dy = -floor(f.r / 1.4), floor(f.r / 1.4), 2 do local w = round(f.r * math.sqrt(max(0, 1 - (dy * 1.4 / f.r) ^ 2))); actx:fillRect(round(f.x - w), round(f.y + dy), w * 2, 1) end
    actx.globalAlpha = 1
end
FIELD_DRAW.grove = function(f)
    local a = clamp(f.t / 0.5, 0, 1)
    actx.globalAlpha = a * 0.7
    for i = 0, 19 do
        local ang = i * 2.4
        local rr = f.r * ((i * 7) % 10) / 10
        actx.fillStyle = (i % 4 == 0) and '#ffd0e6' or '#6fbf5a'
        actx:fillRect(round(f.x + cos(ang) * rr), round(f.y + sin(ang) * rr / 1.4), 1, (i % 3 == 0) and 2 or 1)
    end
    actx.globalAlpha = 1
end

return true
