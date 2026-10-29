-- ============================================================================
-- 第六次更新：新兵种的技能与机制（吟游诗人 / 幼龙 / 冰霜元素）
--  * 通用增益：攻击 / 攻速 / 减伤 / 吸血，限时、取较大值刷新（不会无限叠加）
--  * 冻结：眩晕 + 冰块外观；沉睡：眩晕 + 下一次受到的伤害 +50%
--  * 龙族：龙鳞减伤；元素：免疫减速和根植，阵亡时冰爆
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, atan, sin, cos = math.floor, math.ceil, math.max, math.min, math.abs, math.atan, math.sin, math.cos
local of = js.of

local function byHpFrac(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end
local function byAtk(a, b) return b.atk - a.atk end
local function near(B, e, x, y, r) return foesOf(B, e):filter(function(o) return hypot(o.x - x, o.y - y) <= r end) end
local function targetable(o) return not o.dead and not o.immune and not o.untargetable end

-- ---------------------------------------------------------------------------
-- 通用增益（限时，取较大值）
-- ---------------------------------------------------------------------------
local BUFF_KEYS = { atk = 'bAtk', spd = 'bSpd', dr = 'bDr', leech = 'bLeech' }
function addBuff(o, dur, mods)
    if o.dead then return end
    for k, f in pairs(BUFF_KEYS) do
        local v = mods[k]
        if v then
            local c = o[f]
            o[f] = { t = max(dur, c and c.t or 0), v = max(v, c and c.v or 0) }
        end
    end
end
local function bv(o, f) local b = o[f]; return (b and b.t > 0) and b.v or 0 end
function buffAtk(o) return bv(o, 'bAtk') end

--- 冻结：眩晕 + 冰块外观（首领减半）
function freeze(o, d)
    if o.dead or o.immune or o.ccImmune then return end
    local dd = o.big and d * 0.5 or d
    o.stun = max(o.stun, dd); o.frozenT = max(o.frozenT or 0, dd)
end
--- 沉睡：眩晕，下一次受到的伤害 +50%
local function sleep(o, d)
    if o.dead or o.immune or o.ccImmune then return end
    local dd = o.big and d * 0.5 or d
    o.stun = max(o.stun, dd); o.sleepT = max(o.sleepT or 0, dd); o.sleepVuln = 0.5
end
local function shieldPct(o, p) if not o.dead then o.shield = min(o.maxHp, (o.shield or 0) + o.maxHp * p) end end
local function burnOf(e, t) return { t = t or 3, dps = e.atk * 0.4 } end
--- 扇形：前方 range 以内、和朝向夹角不超过 half 的敌人
local function cone(B, e, range, half)
    local out = A()
    for o in of(foesOf(B, e)) do
        local dx, dy = o.x - e.x, o.y - e.y
        local d = hypot(dx, dy)
        if d <= range + o.r and (d < 6 or abs(atan(dy, dx * e.face)) <= half) then out:push(o) end
    end
    return out
end
CONE = cone
local function centroid(list)
    local x, y, n = 0, 0, 0
    for o in of(list) do x = x + o.x; y = y + o.y; n = n + 1 end
    if n == 0 then return nil end
    return x / n, y / n
end

EXT_SKILLS2 = {}
local X = EXT_SKILLS2
-- —— 吟游诗人 ——
X.battlesong = function(B, e, t)
    for o in of(alliesOf(B, e)) do addBuff(o, 5, { atk = 0.2, spd = 0.25 }) end
end
X.encore = function(B, e, t)
    for o in of(alliesOf(B, e)) do if o ~= e and o.skill then gainEnergy(o, 20) end end
    e.haste = max(e.haste or 0, 3)
end
X.warhymn = function(B, e, t)
    for o in of(alliesOf(B, e)) do
        addBuff(o, 6, { atk = 0.3 })
        if hypot(o.x - e.x, o.y - e.y) <= 40 then healAmt(o, o.maxHp * 0.08) end
    end
end
X.lullaby = function(B, e, t)
    local list = foesOf(B, e):filter(targetable):sort(byAtk):slice(0, 3)
    for o in of(list) do sleep(o, 2.5) end
end
X.saga = function(B, e, t)
    for o in of(alliesOf(B, e)) do shieldPct(o, 0.2); addBuff(o, 5, { spd = 0.3 }) end
end
X.dissonance = function(B, e, t)
    for o in of(foesOf(B, e)) do
        hit(e, o, e.atk * 1.2, { noLeech = true })
        if not o.dead then
            if o.skill then o.energy = max(0, (o.energy or 0) - 50) end
            applyCurse(o, 4, 0, 0.25)
        end
    end
end
X.symphony = function(B, e, t)
    for o in of(alliesOf(B, e)) do
        addBuff(o, 6, { atk = 0.35, spd = 0.35 })
        if o ~= e and o.skill then gainEnergy(o, 30) end
    end
end
X.requiem = function(B, e, t)
    for o in of(foesOf(B, e)) do
        hit(e, o, e.atk * 2.2, { noLeech = true })
        if not o.dead and not o.big and not o.anchor and o.hp < o.maxHp * 0.25 then execute(e, o) end
    end
    for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.15) end
end
X.bloodopera = function(B, e, t)
    for o in of(foesOf(B, e)) do hit(e, o, e.atk * 1.5, { noLeech = true }) end
    for o in of(alliesOf(B, e)) do o.haste = max(o.haste or 0, 5); addBuff(o, 5, { atk = 0.3, leech = 0.25 }) end
    B.tint = { t = 0.45, max = 0.45, rgb = '170,10,50' }; G.shake = max(G.shake, 0.25)
end
-- —— 幼龙 ——
X.dragonbreath = function(B, e, t)
    for o in of(cone(B, e, 52, 0.62)) do hit(e, o, e.atk * 1.6, { noLeech = true }); applyBurn(o, e, 3, e.atk * 0.4) end
end
X.flamespit = function(B, e, t)
    local foes = foesOf(B, e):filter(targetable):sort(function(a, b) return hypot(a.x - e.x, a.y - e.y) - hypot(b.x - e.x, b.y - e.y) end)
    for i = 0, 2 do
        local o = foes[i % max(1, #foes)] or t
        if o then shoot(B, e, o, 'flame', { delay = i * 0.1, area = true, splash = 12, mul = 1.3, burn = burnOf(e, 3), big = true }) end
    end
end
X.emberrain = function(B, e, t)
    local foes = foesOf(B, e)
    for i = 0, 5 do
        local o = pick(foes) or t
        local px = clamp(o.x + rand(-12, 12), 6, AW - 6)
        local py = clamp(o.y + rand(-10, 10), 14, FIELD_H - 10)
        shoot(B, e, nil, 'ember', { x = px + rand(-20, 20), y = -6, tx = px, ty = py, speed = 150, delay = i * 0.09, area = true, splash = 16, mul = 0.9, burn = burnOf(e, 3) })
    end
end
X.jadescale = function(B, e, t)
    local al = alliesOf(B, e):filter(function(o) return o ~= e end):sort(function(a, b) return hypot(a.x - e.x, a.y - e.y) - hypot(b.x - e.x, b.y - e.y) end):slice(0, 2)
    al:unshift(e)
    for o in of(al) do shieldPct(o, 0.3); o.ccShield = max(o.ccShield or 0, 3); o.stun = 0 end
end
X.frostbreath = function(B, e, t)
    for o in of(cone(B, e, 52, 0.62)) do hit(e, o, e.atk * 1.7, { noLeech = true }); freeze(o, 1.5) end
end
X.shadowflame = function(B, e, t)
    local list = foesOf(B, e):filter(targetable):sort(byHpFrac):slice(0, 3)
    for o in of(list) do hit(e, o, e.atk * 2.0, { noLeech = true }); applyCurse(o, 4, 0.25, 0) end
end
X.dragonfall = function(B, e, t)
    local foes = foesOf(B, e)
    local cx, cy = centroid(foes)
    if not cx then cx, cy = t.x, t.y end
    for o in of(foes) do
        if hypot(o.x - cx, o.y - cy) <= 32 + o.r then
            hit(e, o, e.atk * 3.0, { noLeech = true })
            if not o.dead then o.stun = max(o.stun, o.big and 0.75 or 1.5) end
        end
    end
    B.fields:push({ kind = 'firesea', x = cx, y = cy, r = 30, t = 5, max = 5, tick = 0.5, src = e, mul = 0.3 })
    G.shake = max(G.shake, 0.4)
    DRAGONFALL_AT = { x = cx, y = cy }
end
X.goldenbreath = function(B, e, t)
    local dx, dy = t.x - e.x, (t.y - 3) - (e.y - 3)
    local d = hypot(dx, dy); if d == 0 then d = 1 end
    shoot(B, e, nil, 'goldfire', { pierce = true, vx = dx / d, vy = dy / d, ang = atan(dy, dx), speed = 280, mul = 2.8, hitSet = js.Set() })
    for o in of(alliesOf(B, e)) do shieldPct(o, 0.2) end
end
X.apocalypse = function(B, e, t)
    for o in of(foesOf(B, e)) do
        hit(e, o, e.atk * 2.5, { noLeech = true })
        if not o.dead then applyBurn(o, e, 5, e.atk * 0.5); applyCurse(o, 4, 0, 0.3) end
    end
    B.tint = { t = 0.5, max = 0.5, rgb = '220,40,20' }; G.shake = max(G.shake, 0.4)
end
-- —— 冰霜元素 ——
X.icenova = function(B, e, t)
    for o in of(near(B, e, e.x, e.y, 38)) do hit(e, o, e.atk * 1.3, { noLeech = true }); freeze(o, 1.2) end
end
X.iceshard = function(B, e, t)
    local foes = foesOf(B, e):filter(targetable):sort(function(a, b) return hypot(a.x - e.x, a.y - e.y) - hypot(b.x - e.x, b.y - e.y) end)
    for i = 0, 3 do
        local o = foes[i % max(1, #foes)] or t
        if o then shoot(B, e, o, 'icicle', { delay = i * 0.07, mul = 1.0, slow = { t = 2, amt = 0.4 }, big = true }) end
    end
end
X.iceblock = function(B, e, t)
    e.inv = max(e.inv or 0, 2); e.iceBlockT = 2; e.stun = max(e.stun, 2); e.frozenT = 2
end
X.blizzardcall = function(B, e, t)
    B.fields:push({ kind = 'blizzard', x = t.x, y = t.y, r = 28, t = 5, max = 5, tick = 0.5, src = e, mul = 0.35 })
end
X.glacialslam = function(B, e, t)
    hit(e, t, e.atk * 2.6, { noLeech = true })
    for o in of(near(B, e, t.x, t.y, 28)) do freeze(o, 1.5) end
    G.shake = max(G.shake, 0.25)
end
X.crystalprison = function(B, e, t)
    local list = foesOf(B, e):filter(targetable):sort(byAtk):slice(0, 2)
    for o in of(list) do
        local d = o.big and 1.5 or 3
        if not o.ccImmune then o.stun = max(o.stun, d) end
        o.prisonT = d; o.prisonSrc = e
    end
end
X.absolutezero = function(B, e, t)
    for o in of(foesOf(B, e)) do
        local chilled = o.slow or o.stun > 0
        hit(e, o, e.atk * 1.5 * (chilled and 2 or 1), { noLeech = true })
        freeze(o, 2)
    end
    B.tint = { t = 0.5, max = 0.5, rgb = '170,220,255' }; G.shake = max(G.shake, 0.3)
end
X.aurora = function(B, e, t)
    for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.2); cleanse(o); addBuff(o, 4, { dr = 0.25 }) end
end
X.crimsonfrost = function(B, e, t)
    for o in of(foesOf(B, e)) do
        freeze(o, 2.5); hit(e, o, e.atk * 2.6, { noLeech = true })
        if not o.dead then applyBleed(o, e, 4, e.atk * 0.5) end
    end
    for o in of(alliesOf(B, e)) do shieldPct(o, 0.2) end
    B.tint = { t = 0.5, max = 0.5, rgb = '160,10,40' }; G.shake = max(G.shake, 0.35)
end

local _castSkill = castSkill
function castSkill(B, e, t)
    local f = EXT_SKILLS2[e.skill]
    if not f then return _castSkill(B, e, t) end
    FX.skill(e, SKILLS[e.skill].name)
    f(B, e, t)
end

-- ---------------------------------------------------------------------------
-- 机制
-- ---------------------------------------------------------------------------
-- 开战：龙鳞减伤、溅射加成、能量光环
addHook('pent', function(ent, u)
    if T(ent.dragonScale) then ent.dr = (ent.dr or 0) + ent.dragonScale end
    if T(ent.splashPlus) then ent.splash = (ent.splash or 0) + ent.splashPlus end
end)
addHook('start', function(B)
    local aura = 0
    for e in of(B.ents) do if e.side == 'p' and T(e.chargeAura) then aura = max(aura, e.chargeAura) end end
    if aura > 0 then
        for e in of(B.ents) do if e.side == 'p' then e.chargeMul = min(1.7, (e.chargeMul or 1) + aura) end end
    end
end)

-- 元素：免疫减速
local _applySlow = applySlow
function applySlow(t, ...) if t.elem then return end return _applySlow(t, ...) end

addHook('step', function(B, dt, alive)
    for e in of(alive) do
        -- 限时增益
        for _, f in pairs(BUFF_KEYS) do local b = e[f]; if b then b.t = b.t - dt; if b.t <= 0 then e[f] = nil end end end
        local sp = bv(e, 'bSpd')
        if sp > 0 and e.stun <= 0 and not B.over then e.cdLeft = e.cdLeft - dt * sp end
        if (e.frozenT or 0) > 0 then e.frozenT = e.frozenT - dt; if e.stun <= 0 then e.frozenT = 0 end end
        if (e.sleepT or 0) > 0 then e.sleepT = e.sleepT - dt; if e.stun <= 0 then e.sleepT = 0 end; if e.sleepT <= 0 then e.sleepVuln = nil end end
        if e.elem then e.root = 0; e.slow = nil end
        if e.iceBlockT then -- 寒冰屏障：破冰
            e.iceBlockT = e.iceBlockT - dt
            if e.iceBlockT <= 0 then
                e.iceBlockT = nil; e.stun = 0; e.frozenT = 0
                for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 50 then o.target = e end end
                healAmt(e, e.maxHp * 0.25)
                FX.ring(e.x, e.y, 30, '#bff4ff'); FX.particle(e.x, e.y - 4, '#e8f8ff', 18, 60, 30, 0.6)
                if FX.iceShatter then FX.iceShatter(e.x, e.y, e.big) end
            end
        end
        if e.prisonT then -- 晶石牢笼：碎裂时造成伤害
            e.prisonT = e.prisonT - dt
            if e.prisonT <= 0 then
                local s = e.prisonSrc
                e.prisonT = nil; e.prisonSrc = nil
                if s and not s.dead then hit(s, e, s.atk * 2, { noLeech = true }) end
                FX.particle(e.x, e.y - 4, '#e0b0ff', 16, 60, 40, 0.5)
                if FX.iceShatter then FX.iceShatter(e.x, e.y, e.big, '#e0b0ff') end
            end
        end
    end
end)

-- 伤害：攻击增益、减伤增益、沉睡易伤、吸血增益、噪音术士抽能
local _hit = hit
function hit(src, t, base, o)
    local dot = o and T(o.dot)
    if src and not dot then
        local a = bv(src, 'bAtk')
        if a > 0 then base = base * (1 + a) end
    end
    local d = bv(t, 'bDr')
    if d > 0 then base = base * (1 - min(0.5, d)) end
    if t.sleepVuln and not dot then base = base * (1 + t.sleepVuln); t.sleepVuln = nil end
    local dmg = _hit(src, t, base, o)
    if src and not dot and not src.dead and dmg and dmg > 0 then
        local l = bv(src, 'bLeech')
        if l > 0 and not (o and o.noLeech) then src.hp = min(src.maxHp, src.hp + dmg * l) end
    end
    return dmg
end
local _procHit = procHit
function procHit(p, o)
    _procHit(p, o)
    if o.dead then return end
    if p.freeze then freeze(o, p.freeze) end
    if p.basic and T(p.src.drainHitR) and o.skill and js.random() < p.src.drainHitR then
        o.energy = max(0, (o.energy or 0) - 10); FX.particle(o.x, o.y - 6, '#c06bff', 5, 30, -10, 0.4)
    end
end

-- 元素阵亡：冰爆冻结周围敌人
addHook('death', function(t, src, B)
    if not t.elem or t.minion then return end
    for o in of(foesOf(B, t)) do
        if hypot(o.x - t.x, o.y - t.y) <= 26 then hit(t, o, t.atk * 0.8, { noLeech = true, noCrit = true }); freeze(o, 1) end
    end
    FX.ring(t.x, t.y, 24, '#bff4ff'); FX.particle(t.x, t.y, '#e8f8ff', 20, 70, 30, 0.6)
    if FX.iceShatter then FX.iceShatter(t.x, t.y, false) end
end)

-- 场地：暴风雪、火海
local _stepHazard = stepHazard
function stepHazard(B, f, dt)
    if f.kind == 'blizzard' or f.kind == 'firesea' then
        f.t = f.t - dt; f.tick = f.tick - dt
        if f.tick <= 0 then
            f.tick = f.tick + 0.5
            for o in of(foesOf(B, f.src)) do
                if hypot(o.x - f.x, (o.y - f.y) * 1.4) <= f.r then
                    hit(f.src, o, f.src.atk * f.mul, { noLeech = true, noCrit = true })
                    if not o.dead then
                        if f.kind == 'blizzard' then applySlow(o, 1, 0.5) else applyBurn(o, f.src, 2, f.src.atk * 0.3) end
                    end
                end
            end
        end
        if f.t <= 0 then f.done = true end
        return
    end
    return _stepHazard(B, f, dt)
end
FIELD_DRAW.blizzard = function(f)
    local a = clamp(f.t / 0.5, 0, 1) * clamp((f.max - f.t) / 0.3, 0, 1)
    actx.globalAlpha = a * 0.22
    actx.fillStyle = '#bff4ff'
    for dy = -floor(f.r / 1.4), floor(f.r / 1.4), 2 do local w = round(f.r * math.sqrt(max(0, 1 - (dy * 1.4 / f.r) ^ 2))); actx:fillRect(round(f.x - w), round(f.y + dy), w * 2, 1) end
    actx.globalAlpha = a
    for i = 0, 23 do -- 斜飘的雪花
        local ph = (G.time * (0.8 + (i % 5) * 0.12) + i * 0.37) % 1
        local ox = ((i * 37) % (f.r * 2)) - f.r
        local x = f.x + ox + ph * 10 - 5
        local y = f.y - f.r / 1.4 - 6 + ph * (f.r * 1.45 + 6)
        actx.fillStyle = (i % 3 == 0) and '#ffffff' or '#bff4ff'
        actx:fillRect(round(x), round(y), 1, 1)
        if i % 4 == 0 then actx:fillRect(round(x) - 1, round(y), 3, 1); actx:fillRect(round(x), round(y) - 1, 1, 3) end
    end
    actx.globalAlpha = 1
end
FIELD_DRAW.firesea = function(f)
    local a = clamp(f.t / 0.6, 0, 1)
    actx.globalAlpha = a * 0.25
    actx.fillStyle = '#ff5a2a'
    for dy = -floor(f.r / 1.4), floor(f.r / 1.4), 2 do local w = round(f.r * math.sqrt(max(0, 1 - (dy * 1.4 / f.r) ^ 2))); actx:fillRect(round(f.x - w), round(f.y + dy), w * 2, 1) end
    actx.globalAlpha = a
    for i = 0, 17 do -- 跳动的火苗
        local ang = i * 2.39996
        local rr = f.r * (((i * 7) % 10) / 10)
        local x = f.x + cos(ang) * rr
        local y = f.y + sin(ang) * rr / 1.4
        local h = 2 + floor((sin(G.time * 9 + i) + 1) * 1.5)
        actx.fillStyle = '#d8433a'; actx:fillRect(round(x), round(y) - h + 1, 1, h)
        actx.fillStyle = (i % 2 == 0) and '#ffb04a' or '#ffe14a'; actx:fillRect(round(x), round(y) - h, 1, 1)
    end
    actx.globalAlpha = 1
end

-- 新投射物
local function line(p, c, s, n, cols)
    for i = 0, n - 1 do actx.fillStyle = cols(i); actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1) end
end
PROJ_DRAW.note = function(p, c, s) -- 音符：小黑点 + 符干 + 符尾，飘着走
    local x, y = round(p.x), round(p.y + sin(G.time * 18 + (p.seed or 0)) * 1.2)
    local col = p.big and '#ffe680' or '#ff8ac8'
    actx.fillStyle = '#1b1530'; actx:fillRect(x - 1, y, 3, 2)
    actx.fillStyle = col; actx:fillRect(x - 1, y, 2, 2); actx:fillRect(x + 1, y - 4, 1, 5); actx:fillRect(x + 2, y - 4, 1, 1); actx:fillRect(x + 3, y - 3, 1, 1)
    if js.random() < 0.3 then FX.parts:push({ x = p.x - c * 3, y = p.y - s * 3, vx = 0, vy = -6, g = 0, life = 0.3, max = 0.3, color = col, size = 1 }) end
end
PROJ_DRAW.flame = function(p, c, s) -- 火球
    local x, y = round(p.x), round(p.y)
    local r = p.big and 2 or 1
    actx.fillStyle = '#d8433a'; actx:fillRect(x - r - 1, y - r, 2 * r + 2, 2 * r + 1)
    actx.fillStyle = '#ff8a2a'; actx:fillRect(x - r, y - r, 2 * r + 1, 2 * r)
    actx.fillStyle = '#ffe14a'; actx:fillRect(x, y - 1, 1, 1)
    if js.random() < 0.7 then FX.parts:push({ x = p.x - c * 3 + rand(-1, 1), y = p.y - s * 3 + rand(-1, 1), vx = rand(-4, 4), vy = -8, g = 0, life = 0.3, max = 0.3, color = (js.random() < 0.5) and '#ff5a2a' or '#ffb04a', size = 1 }) end
end
PROJ_DRAW.ember = function(p, c, s)
    line(p, c, s, 6, function(i) return (i == 0) and '#ffffff' or ((i < 3) and '#ffe14a' or '#ff8a2a') end)
    if js.random() < 0.6 then FX.parts:push({ x = p.x, y = p.y, vx = rand(-6, 6), vy = -6, g = 0, life = 0.3, max = 0.3, color = '#ff5a2a', size = 1 }) end
end
PROJ_DRAW.icicle = function(p, c, s) -- 冰棱：尖头白、尾部淡蓝
    line(p, c, s, p.big and 6 or 4, function(i) return (i == 0) and '#ffffff' or ((i < 3) and '#bff4ff' or '#6ec8ff') end)
    if js.random() < 0.3 then FX.parts:push({ x = p.x, y = p.y, vx = 0, vy = 4, g = 0, life = 0.25, max = 0.25, color = '#e8f8ff', size = 1 }) end
end
PROJ_DRAW.goldfire = function(p, c, s)
    line(p, c, s, 14, function(i) return (i < 2) and '#ffffff' or ((i < 7) and '#ffe680' or '#e2b33c') end)
    for k = -1, 1, 2 do actx.fillStyle = '#ffd84a'; actx:fillRect(round(p.x - c * 4 + s * k * 2), round(p.y - s * 4 - c * k * 2), 1, 1) end
    if js.random() < 0.8 then FX.parts:push({ x = p.x - c * rand(2, 12), y = p.y + rand(-3, 3), vx = rand(-6, 6), vy = -10, g = 0, life = 0.4, max = 0.4, color = (js.random() < 0.5) and '#ffe680' or '#ffffff', size = 1 }) end
end
SLOW_PROJ = SLOW_PROJ or js.Set()

return true
