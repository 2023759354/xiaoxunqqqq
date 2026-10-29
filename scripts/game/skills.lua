-- ============================================================================
-- 技能：castSkill（逐条移植自原版）
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, atan = math.floor, math.ceil, js.max, math.min, math.abs, math.atan
local of = js.of

function castMeteor(B, e, t, mul)
    shoot(B, e, t, 'meteor', { x = t.x - 26, y = t.y - 70, speed = 130, area = true, splash = 24, mul = mul, burn = { t = 3, dps = e.atk * 0.4 } })
end
function castFrost(B, e, t, mul, freeze)
    shoot(B, e, t, 'frostbig', { area = true, splash = 26, mul = mul, stunHit = freeze, slow = { t = 3, amt = 0.35 } })
end
function castChain(B, e, t, mul, n)
    local cur, px, py = t, e.x + e.face * 5, e.y - 4
    local done = js.Set()
    local i = 0
    while i < n and cur do
        done:add(cur)
        FX.bolt(px, py, cur.x, cur.y - 3)
        hit(e, cur, e.atk * mul)
        mul = mul * 0.85; px = cur.x; py = cur.y - 3
        cur = nearestOther(B, e, cur.x, cur.y, 46, done)
        i = i + 1
    end
    Sound.play('zap')
end
ELEM_NAMES = A('陨火', '冰封', '雷链')

local function byHpFrac(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end

function castSkill(B, e, t)
    FX.skill(e, (e.skill == 'elements') and ('元素·' .. ELEM_NAMES[(e.elemIdx or 0) % 3]) or SKILLS[e.skill].name)
    local sk = e.skill
    if sk == 'bash' then
        strikeAt(e); hit(e, t, e.atk * 1.6)
        if not t.dead then t.stun = max(t.stun, 1) end
        FX.burst(t.x, t.y - 4, '#ffd84a', 8)
    elseif sk == 'triple' then
        for i = 0, 2 do shoot(B, e, t, 'arrow', { delay = i * 0.1, mul = 0.8 }) end
    elseif sk == 'arcane' then
        shoot(B, e, t, 'arcane', { area = true, splash = 22, mul = 1.5 })
    elseif sk == 'whirlwind' then
        strikeAt(e)
        local dealt = 0
        for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 24 then dealt = dealt + hit(e, o, e.atk * 1.4, { noLeech = true }) end end
        e.hp = min(e.maxHp, e.hp + dealt * 0.3)
        FX.ring(e.x, e.y, 22, '#ff9a7a')
    elseif sk == 'aegis' then
        local amt = e.maxHp * 0.3
        local al = alliesOf(B, e):filter(function(o) return o ~= e end):sort(byHpFrac):slice(0, 2)
        A(e):concat(al):forEach(function(o) o.shield = min(o.maxHp, (o.shield or 0) + amt); FX.ring(o.x, o.y, 9, '#fff3b0') end)
        for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 60 then o.target = e end end
    elseif sk == 'snipe' then
        local tgt = foesOf(B, e):sort(function(a, b) return b.hp - a.hp end)[0] or t
        shoot(B, e, tgt, 'snipe', { speed = 420, mul = 4 })
    elseif sk == 'volley' then
        for i = 0, 5 do
            local px = clamp(t.x + rand(-14, 14), 6, AW - 6)
            local py = clamp(t.y + rand(-12, 12), 14, FIELD_H - 10)
            shoot(B, e, nil, 'rain', { x = px, y = py - 46, tx = px, ty = py, speed = 170, delay = 0.12 + i * 0.11, area = true, splash = 10, mul = 0.8 })
        end
    elseif sk == 'meteor' then castMeteor(B, e, t, 2.2)
    elseif sk == 'stomp' then
        for o in of(foesOf(B, e)) do
            if hypot(o.x - e.x, o.y - e.y) <= 30 then hit(e, o, e.atk * 1.2, { noLeech = true }); if not o.dead then o.stun = max(o.stun, 1) end end
        end
        FX.ring(e.x, e.y, 28, '#ff5a3a'); FX.particle(e.x, e.y + 6, '#8a5a3a', 20, 60, 120, 0.5); G.shake = max(G.shake --[[@as number]], 0.3)
    elseif sk == 'raise' then
        local mine = B.ents:filter(function(o) return not o.dead and o.owner == e end)
        if #mine < 2 then
            local mx = clamp(e.x + e.face * 10, 6, AW - 6)
            local my = clamp(e.y + rand(-8, 8), 14, FIELD_H - 10)
            local m = makeEnt('p', { x = mx, y = my,
                maxHp = round(e.maxHp * 0.6), atk = round(e.atk * 0.55), cd = 1.0, crit = 0.05, leech = 0, range = 8,
                speed = 22, r = 5, proj = nil, splash = 0, sprite = 'skeleton', minion = true, owner = e, star = 0 })
            m.cdLeft = 0.4
            B.ents:push(m)
            FX.particle(m.x, m.y, '#c06bff', 16, 50, 40, 0.6)
        else mine:forEach(function(o) o.hp = o.maxHp; FX.ring(o.x, o.y, 8, '#c06bff') end) end
    elseif sk == 'leap' then
        local foes = foesOf(B, e)
        if #foes > 0 then
            local TT = foes:reduce(function(a, b) return (abs(b.x - e.x) > abs(a.x - e.x)) and b or a end)
            local dir, ox, oy = (TT.x >= e.x) and 1 or -1, e.x, e.y
            e.x = clamp(TT.x - dir * (TT.r + e.r + 2), 6, AW - 6); e.y = landY(TT.y)
            e.face = dir; e.target = TT; strikeAt(e)
            FX.trail(ox, oy - 4, e.x, e.y - 4, '#7fe0c0')
            for o in of(foesOf(B, e)) do
                if hypot(o.x - e.x, o.y - e.y) <= 22 then hit(e, o, e.atk * 2, { noLeech = true }); if not o.dead then o.stun = max(o.stun, 0.8) end end
            end
            FX.ring(e.x, e.y, 20, '#7fe0c0'); G.shake = max(G.shake --[[@as number]], 0.2)
        end
    elseif sk == 'issen' then
        strikeAt(e)
        hit(e, t, e.atk * 2.8, { forceCrit = true })
        FX.slash(t.x, t.y)
        if t.dead then e.energy = 50 end
    elseif sk == 'pierce' then
        local dx, dy = t.x - e.x, (t.y - 3) - (e.y - 3)
        local d = hypot(dx, dy)
        if d == 0 then d = 1 end
        shoot(B, e, nil, 'pierce', { pierce = true, vx = dx / d, vy = dy / d, ang = atan(dy, dx), speed = 240, mul = 2.2, hitSet = js.Set(), ret = not not e.pierceReturn })
    elseif sk == 'wolf' then
        local pet = B.ents:find(function(o) return not o.dead and o.owner == e end)
        if not pet then
            local mx = clamp(e.x + e.face * 10, 6, AW - 6)
            local my = clamp(e.y + rand(-6, 6), 14, FIELD_H - 10)
            local m = makeEnt('p', { x = mx, y = my,
                maxHp = round(e.maxHp * 1.2), atk = round(e.atk * 0.75), cd = 0.75, crit = 0.1, leech = 0, range = 8,
                speed = 34, r = 5, proj = nil, splash = 0, sprite = 'wolf', minion = true, msprite = 'wolf', owner = e, star = 0 })
            m.cdLeft = 0.3
            B.ents:push(m)
            FX.particle(m.x, m.y, '#c9cbd6', 16, 50, 40, 0.6)
        else pet.hp = pet.maxHp; pet.haste = 4; FX.ring(pet.x, pet.y, 9, '#ff6a4a') end
    elseif sk == 'frostnova' then castFrost(B, e, t, 1.3, 1.5)
    elseif sk == 'chain' then castChain(B, e, t, 1.6, 5)

    -- —— 稀有路线 ——
    elseif sk == 'warcry' then
        for o in of(alliesOf(B, e)) do o.haste = max(o.haste or 0, 3); healAmt(o, o.maxHp * 0.12); FX.ring(o.x, o.y, 8, '#ffb04a') end
        FX.ring(e.x, e.y, 26, '#ff6a4a')
    elseif sk == 'vengeance' then
        strikeAt(e)
        hit(e, t, e.atk * 1.8 + (e.maxHp - e.hp) * 0.6)
        if not t.dead then t.stun = max(t.stun, 0.8) end
        FX.slash(t.x, t.y); FX.burst(t.x, t.y - 4, '#c06bff', 10)
    elseif sk == 'venomburst' then
        shoot(B, e, t, 'parrow', { area = true, splash = 20, mul = 1, poison = 3 })
    elseif sk == 'hunt' then
        local tgt = foesOf(B, e):sort(byHpFrac)[0] or t
        shoot(B, e, tgt, 'snipe', { speed = 380, mul = 3.5, killRefund = 60 })
    elseif sk == 'heal' then
        for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.28); o.stun = 0; FX.ring(o.x, o.y, 8, '#fff3b0') end
    elseif sk == 'hex' then
        for o in of(foesOf(B, e)) do
            if hypot(o.x - t.x, o.y - t.y) <= 30 then applyCurse(o, 6, 0.3, 0.3); hit(e, o, e.atk * 0.8) end
        end
        FX.ring(t.x, t.y, 28, '#9be36b'); FX.particle(t.x, t.y, '#4fbf4a', 16, 40, -20, 0.8)

    -- —— 史诗路线 ——
    elseif sk == 'shockwave' then
        strikeAt(e)
        for o in of(foesOf(B, e)) do
            local dx, dy = o.x - e.x, o.y - e.y
            if not (hypot(dx, dy) > 34 or dx * e.face < -4) then
                hit(e, o, e.atk * 1.8, { noLeech = true })
                if not o.dead then o.stun = max(o.stun, 0.6); if not o.big then o.x = clamp(o.x + e.face * 20, 6, AW - 6) end end
            end
        end
        FX.ring(e.x + e.face * 12, e.y, 22, '#6ef0ff'); FX.particle(e.x + e.face * 10, e.y, '#bff4ff', 14, 70, 0, 0.4)
        G.shake = max(G.shake --[[@as number]], 0.2)
    elseif sk == 'behead' then
        strikeAt(e)
        hit(e, t, e.atk * (t.big and 5 or 2.8))
        if not t.dead and not t.big and t.hp < t.maxHp * 0.35 then execute(e, t) end
        FX.slash(t.x, t.y)
    elseif sk == 'barrage' then
        local foes = foesOf(B, e)
        for i = 0, 7 do shoot(B, e, pick(foes), 'arrow', { delay = i * 0.07, mul = 1, ricochet = e.ricochet or 0 }) end
    elseif sk == 'turret' then
        local mine = minionsOf(B, e)
        if #mine < 2 then deployTurret(B, e)
        else mine:forEach(function(o) o.hp = o.maxHp; o.haste = 4; FX.ring(o.x, o.y, 8, '#ffb04a') end) end
    elseif sk == 'timestop' then
        for o in of(foesOf(B, e)) do o.stun = max(o.stun, o.big and 0.8 or 1.6) end
        for o in of(alliesOf(B, e)) do o.haste = max(o.haste or 0, 2.5) end
        B.tint = { t = 0.7, max = 0.7, rgb = '191,244,255' }
        G.shake = max(G.shake --[[@as number]], 0.15)
    elseif sk == 'blackhole' then
        B.fields:push({ x = t.x, y = t.y, t = 4, tick = 0.5, r = 40, src = e, mul = 0.5, boom = 1.5, vuln = e.holeVuln or 0.15 })

    -- —— 传说路线 ——
    elseif sk == 'giant' then
        if not ((e.giant or 0) > 0) then e.big = true; e.r = 9 end
        e.giant = 6
        healAmt(e, e.maxHp * 0.15)
        FX.ring(e.x, e.y, 24, '#ffa53a'); FX.particle(e.x, e.y, '#ffd27a', 24, 80, 40, 0.7)
        G.shake = max(G.shake --[[@as number]], 0.35)
    elseif sk == 'sanctuary' then
        local fallen = B.ents:filter(function(o) return o.dead and o.side == e.side and not o.minion and o ~= e end):sort(function(a, b) return b.atk - a.atk end)[0]
        if fallen then revive(fallen, 0.6) end
        for o in of(alliesOf(B, e)) do o.shield = min(o.maxHp, (o.shield or 0) + o.maxHp * 0.35); FX.ring(o.x, o.y, 9, '#fff3b0') end
        B.tint = { t = 0.5, max = 0.5, rgb = '255,243,176' }
    elseif sk == 'starfall' then
        foesOf(B, e):forEach(function(o, i)
            local sx = o.x + rand(-12, 12)
            shoot(B, e, o, 'star', { x = sx, y = -6, speed = 220, delay = i * 0.06, mul = 1.5, stunHit = 0.4 })
        end)
        B.tint = { t = 0.5, max = 0.5, rgb = '40,50,120' }
    elseif sk == 'shadowclone' then
        local mine = minionsOf(B, e)
        if #mine < 2 then for i = #mine, 1 do spawnClone(B, e, i) end
        else A(e):concat(mine):forEach(function(o) o.haste = max(o.haste or 0, 4); FX.ring(o.x, o.y, 8, '#c06bff') end) end
    elseif sk == 'elements' then
        local k = (e.elemIdx or 0) % 3
        e.elemIdx = k + 1
        if k == 0 then castMeteor(B, e, t, 3.2)
        elseif k == 1 then castFrost(B, e, t, 2.0, 2)
        else castChain(B, e, t, 2.6, 7) end
    elseif sk == 'legion' then
        local room = 5 - #minionsOf(B, e)
        for i = 0, min(2, room) - 1 do spawnBone(B, e, e.x + e.face * 10, e.y + ((i ~= 0) and 10 or -10)) end
        minionsOf(B, e):forEach(function(o) o.hp = o.maxHp; o.haste = max(o.haste or 0, 5); FX.ring(o.x, o.y, 8, '#6ef0ff') end)

    -- —— 新兵种：猛虎 ——
    elseif sk == 'pounce' then
        local foes = foesOf(B, e):filter(function(o) return not o.immune end)
        if #foes > 0 then
            local TT = foes:slice():sort(byHpFrac)[0]
            local dir, ox, oy = (TT.x >= e.x) and 1 or -1, e.x, e.y
            e.x = clamp(TT.x - dir * (TT.r + e.r + 2), 6, AW - 6); e.y = landY(TT.y)
            e.face = dir; e.target = TT; strikeAt(e)
            FX.trail(ox, oy - 4, e.x, e.y - 4, '#ffa53a')
            hit(e, TT, e.atk * 2.2, { melee = true }); FX.slash(TT.x, TT.y)
            if TT.dead then e.energy = 50 end
        end
    elseif sk == 'rend' then
        strikeAt(e)
        local i = 0
        while i < 3 and not t.dead do hit(e, t, e.atk * 0.8, { melee = true }); i = i + 1 end
        if not t.dead then applyBleed(t, e, 3, e.atk * 0.5) end
        FX.slash(t.x, t.y); FX.burst(t.x, t.y - 4, '#ff4a3a', 8)
    elseif sk == 'ambush' then
        local foes = foesOf(B, e):filter(function(o) return not o.immune end)
        if #foes > 0 then
            local TT = foes:slice():sort(function(a, b) return a.hp - b.hp end)[0]
            local ox, oy, dir = e.x, e.y, (TT.x >= e.x) and 1 or -1
            e.x = clamp(TT.x + dir * (TT.r + e.r + 2), 6, AW - 6); e.y = landY(TT.y)
            e.face = -dir; e.target = TT; strikeAt(e)
            FX.trail(ox, oy - 4, e.x, e.y - 4, '#ffffff')
            hit(e, TT, e.atk * 3, { melee = true, forceCrit = true }); FX.slash(TT.x, TT.y)
        end
    elseif sk == 'tigerroar' then
        e.haste = max(e.haste or 0, 6); healAmt(e, e.maxHp * 0.2)
        for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 36 then o.stun = max(o.stun, o.big and 0.4 or 0.8) end end
        FX.ring(e.x, e.y, 30, '#ffa53a'); FX.particle(e.x, e.y, '#ffd27a', 20, 70, 20, 0.6); G.shake = max(G.shake --[[@as number]], 0.2)

    -- —— 新兵种：巨熊 ——
    elseif sk == 'roar' then
        for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 60 then o.target = e end end
        e.guard = { t = 4, dr = 0.35 }; healAmt(e, e.maxHp * 0.1)
        FX.ring(e.x, e.y, 28, '#c08a5a'); FX.particle(e.x, e.y, '#c9955a', 14, 50, 20, 0.5)
    elseif sk == 'quake' then
        strikeAt(e)
        for o in of(foesOf(B, e)) do
            if hypot(o.x - e.x, o.y - e.y) <= 26 then hit(e, o, e.atk * 1.3, { noLeech = true }); if not o.dead then o.stun = max(o.stun, o.big and 0.4 or 0.8) end end
        end
        FX.ring(e.x, e.y, 26, '#c08a5a'); FX.particle(e.x, e.y + 6, '#8a6a4a', 16, 60, 110, 0.5); G.shake = max(G.shake --[[@as number]], 0.2)
    elseif sk == 'hibernate' then
        e.shield = min(e.maxHp, (e.shield or 0) + e.maxHp * 0.4); healAmt(e, e.maxHp * 0.25)
        e.guard = { t = 5, dr = 0.4 }
        FX.ring(e.x, e.y, 22, '#6a8ad8'); FX.particle(e.x, e.y, '#bcd0ff', 14, 40, -10, 0.8)
    elseif sk == 'frostroar' then
        for o in of(foesOf(B, e)) do
            if hypot(o.x - e.x, o.y - e.y) <= 56 then
                hit(e, o, e.atk * 1.0, { noLeech = true })
                if not o.dead then applySlow(o, 4, 0.5); o.stun = max(o.stun, o.big and 0.3 or 0.6); o.target = e end
            end
        end
        FX.ring(e.x, e.y, 34, '#bff4ff'); FX.particle(e.x, e.y, '#e4f4ff', 22, 70, 10, 0.7); G.shake = max(G.shake --[[@as number]], 0.2)
    elseif sk == 'bearhug' then
        local TT = foesOf(B, e):filter(function(o) return not o.immune end):sort(function(a, b) return b.atk - a.atk end)[0] or t
        local dir, ox, oy = (TT.x >= e.x) and 1 or -1, e.x, e.y
        e.x = clamp(TT.x - dir * (TT.r + e.r + 2), 6, AW - 6); e.y = landY(TT.y)
        e.face = dir; e.target = TT; strikeAt(e)
        FX.trail(ox, oy - 4, e.x, e.y - 4, '#c9955a')
        hit(e, TT, e.atk * 2.5, { melee = true })
        if not TT.dead then TT.stun = max(TT.stun, TT.big and 0.8 or 2) end
        healAmt(e, e.maxHp * 0.2); FX.ring(TT.x, TT.y, 14, '#ffd84a'); G.shake = max(G.shake --[[@as number]], 0.15)

    -- —— 新兵种：食人花 ——
    elseif sk == 'spore' then
        for o in of(foesOf(B, e)) do
            if hypot(o.x - t.x, o.y - t.y) <= 24 then hit(e, o, e.atk * 0.7); addPoison(o, e, 2); applySlow(o, 3, 0.3) end
        end
        FX.ring(t.x, t.y, 24, '#9be36b'); FX.particle(t.x, t.y, '#7fd36a', 18, 40, -10, 0.8)
    elseif sk == 'entangle' then
        for o in of(foesOf(B, e)) do
            if hypot(o.x - t.x, o.y - t.y) <= 26 then hit(e, o, e.atk * 0.7); if not o.dead then o.stun = max(o.stun, o.big and 0.6 or 1.2) end end
        end
        FX.ring(t.x, t.y, 22, '#2f7a34'); FX.particle(t.x, t.y, '#4fbf4a', 16, 40, 20, 0.7)
    elseif sk == 'virulence' then
        local sick = foesOf(B, e):filter(function(o) return o.poison end)
        if #sick == 0 then addPoison(t, e, 3); FX.ring(t.x, t.y, 14, '#9be36b')
        else
            for o in of(sick) do
                local n = o.poison and o.poison.n or 0
                o.poison = nil
                hit(e, o, e.atk * 0.7 * n, { noCrit = true })
                FX.ring(o.x, o.y, 14, '#e6ff6a'); FX.particle(o.x, o.y, '#9be36b', 12, 50, 10, 0.5)
            end
        end
    elseif sk == 'seedling' then
        local mine = minionsOf(B, e)
        if #mine < 3 then deploySprout(B, e)
        else mine:forEach(function(o) o.hp = o.maxHp; o.haste = 4; FX.ring(o.x, o.y, 8, '#9be36b') end) end
    elseif sk == 'plague' then
        for o in of(foesOf(B, e)) do addPoison(o, e, 4); applyCurse(o, 6, 0.2, 0) end
        B.tint = { t = 0.5, max = 0.5, rgb = '110,50,150' }; FX.ring(e.x, e.y, 34, '#9a5ae0')
    elseif sk == 'devour' then
        local TT = foesOf(B, e):filter(function(o) return not o.immune end):sort(function(a, b) return a.hp - b.hp end)[0] or t
        hit(e, TT, e.atk * 3)
        if not TT.dead and not TT.big and TT.hp < TT.maxHp * 0.4 then execute(e, TT) end
        if TT.dead then for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.12) end end
        FX.ring(TT.x, TT.y, 14, '#ff4a3a'); FX.burst(TT.x, TT.y - 4, '#9be36b', 10)

    -- —— 新兵种：向日葵 ——
    elseif sk == 'sunburst' then
        for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.15); o.stun = 0; o.haste = max(o.haste or 0, 2); FX.ring(o.x, o.y, 8, '#ffe14a') end
        FX.ring(e.x, e.y, 26, '#ffe14a')
    elseif sk == 'moonlight' then -- 月华：改为全场削弱（控制交给时空法师）
        for o in of(foesOf(B, e)) do applyCurse(o, 6, 0, o.big and 0.2 or 0.4); FX.particle(o.x, o.y - 6, '#e4f2ff', 4, 20, -10, 0.5) end
        for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.12); FX.ring(o.x, o.y, 8, '#e4f2ff') end
        B.tint = { t = 0.6, max = 0.6, rgb = '120,150,255' }
    elseif sk == 'bloom' then
        for o in of(alliesOf(B, e)) do o.hot = { t = 5, tick = 1 }; FX.ring(o.x, o.y, 8, '#ff8ab8') end
    elseif sk == 'solarflare' then
        for o in of(foesOf(B, e)) do hit(e, o, e.atk * 1.1); applyBurn(o, e, 3, e.atk * 0.4) end
        for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.08) end
        B.tint = { t = 0.5, max = 0.5, rgb = '255,200,80' }; G.shake = max(G.shake --[[@as number]], 0.2)

    -- —— 技能去重后的新技能 ——
    elseif sk == 'venomrush' then -- 毒藤：藤毒狂涌
        e.haste = max(e.haste or 0, 5); e.venomT = 5
        FX.ring(e.x, e.y, 12, '#9be36b'); FX.particle(e.x, e.y, '#4fbf4a', 12, 40, -10, 0.6)
    elseif sk == 'thornfield' then -- 荆棘玫瑰：荆棘领域
        for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 40 then hit(e, o, e.atk * 0.8) end end
        B.fields:push({ kind = 'thornzone', x = e.x, y = e.y, r = 40, t = 5, max = 5, src = e, mul = 0.6 })
        FX.ring(e.x, e.y, 36, '#ff6a8a')
    elseif sk == 'shadowstrike' then -- 影豹：影袭
        local foes = foesOf(B, e):filter(function(o) return not o.immune end)
        if #foes > 0 then
            local TT = foes:reduce(function(a, b) return (abs(b.x - e.x) > abs(a.x - e.x)) and b or a end)
            local dir, ox, oy = (TT.x >= e.x) and 1 or -1, e.x, e.y
            e.x = clamp(TT.x - dir * (TT.r + e.r + 2), 6, AW - 6); e.y = landY(TT.y)
            e.face = dir; e.target = TT; strikeAt(e)
            FX.trail(ox, oy - 4, e.x, e.y - 4, '#c06bff')
            hit(e, TT, e.atk * 2.2, { melee = true }); FX.slash(TT.x, TT.y)
            e.evadeT = 1
        end
    elseif sk == 'drinkblood' then -- 血牙：饮血
        strikeAt(e)
        local dealt = 0
        for i = 0, 1 do if not t.dead then dealt = dealt + hit(e, t, e.atk * 1.5, { melee = true, noLeech = true }) end end
        healAmt(e, dealt * 0.5 * ((e.hp < e.maxHp * 0.5) and 2 or 1))
        FX.slash(t.x, t.y); FX.burst(t.x, t.y - 4, '#ff4a3a', 10)
    elseif sk == 'huntchain' then -- 饿虎：追杀
        for n = 0, 2 do
            local foes = foesOf(B, e):filter(function(o) return not o.immune end)
            if #foes == 0 then break end
            local TT = foes:slice():sort(byHpFrac)[0]
            local dir, ox, oy = (TT.x >= e.x) and 1 or -1, e.x, e.y
            e.x = clamp(TT.x - dir * (TT.r + e.r + 2), 6, AW - 6); e.y = landY(TT.y)
            e.face = dir; e.target = TT; strikeAt(e)
            FX.trail(ox, oy - 4, e.x, e.y - 4, '#ff8a2a')
            hit(e, TT, e.atk * 2.2, { melee = true }); FX.slash(TT.x, TT.y)
            if not TT.dead then break end
            if n > 0 then FX.float(e.x, e.y - 18, S(n + 1) .. '+', '#ff8a2a') end
        end
    elseif sk == 'frenzy' then -- 狂爪熊：狂乱
        e.haste = max(e.haste or 0, 4); e.frenzyT = 4
        FX.ring(e.x, e.y, 14, '#ff6a4a'); FX.particle(e.x, e.y, '#ff4a3a', 14, 50, 20, 0.5)
    elseif sk == 'purify' then -- 圣疗师：圣愈净化
        local al = alliesOf(B, e)
        local low = al:slice():sort(byHpFrac)[0]
        if low then healAmt(low, low.maxHp * 0.6); FX.ring(low.x, low.y, 12, '#ffffff') end
        al:forEach(function(o) cleanse(o, false) end)
    elseif sk == 'sunshield' then -- 太阳花神：烈阳庇佑
        for o in of(alliesOf(B, e)) do o.shield = min(o.maxHp, (o.shield or 0) + o.maxHp * 0.3); o.thornAura = { t = 6, v = 0.3 }; FX.ring(o.x, o.y, 9, '#ffb04a') end
        B.tint = { t = 0.4, max = 0.4, rgb = '255,200,80' }
    elseif sk == 'landslide' then -- 山岳熊：山崩
        for i = 0, 3 do
            local px = clamp(t.x + rand(-16, 16), 6, AW - 6)
            local py = clamp(t.y + rand(-14, 14), 14, FIELD_H - 10)
            shoot(B, e, nil, 'rock', { x = px + 6, y = py - 60, tx = px, ty = py, speed = 160, delay = i * 0.12, area = true, splash = 14, mul = 1.6, slow = { t = 3, amt = 0.4 } })
        end
        G.shake = max(G.shake --[[@as number]], 0.2)
    elseif sk == 'throatrip' then -- 剑齿王：裂喉
        strikeAt(e)
        local bonus = t.bleed and 1.6 or 1
        hit(e, t, e.atk * 2.8 * bonus, { melee = true })
        if not t.dead then applyBleed(t, e, 5, e.atk * 0.5) end
        FX.slash(t.x, t.y); FX.burst(t.x, t.y - 4, '#d8433a', 12)
    elseif sk == 'ironwall' then -- 铁背熊：铁壁
        for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 60 then o.target = e end end
        e.guard = { t = 4, dr = 0.35 }
        for o in of(alliesOf(B, e)) do if o ~= e and not (o.guard and o.guard.dr > 0.2) then o.guard = { t = 4, dr = 0.2 }; FX.ring(o.x, o.y, 8, '#8d9ab2') end end
        FX.ring(e.x, e.y, 28, '#8d9ab2'); FX.particle(e.x, e.y, '#c9d2e0', 14, 50, 20, 0.5)
    elseif sk == 'poisoncloud' then -- 瘟疫花：毒云
        B.fields:push({ kind = 'cloud', x = t.x, y = t.y, r = 22, t = 4, max = 4, tick = 0.5, src = e })
        FX.ring(t.x, t.y, 20, '#c06bff')
    elseif sk == 'sunward' then -- 光合花：日光结界
        for o in of(alliesOf(B, e)) do
            if not (o.guard and o.guard.dr > 0.3) then o.guard = { t = 4, dr = 0.3 } end
            healAmt(o, o.maxHp * 0.1); FX.ring(o.x, o.y, 9, '#9be36b')
        end
        B.tint = { t = 0.4, max = 0.4, rgb = '190,255,140' }
    elseif sk == 'clawstorm' then -- 裂爪虎：裂空爪
        strikeAt(e)
        for o in of(foesOf(B, e)) do
            if hypot(o.x - e.x, o.y - e.y) <= 26 then hit(e, o, e.atk * 1.3, { melee = true, noLeech = true }); if not o.dead then applyBleed(o, e, 3, e.atk * 0.45) end end
        end
        FX.ring(e.x, e.y, 24, '#ff7a3a'); FX.particle(e.x, e.y, '#ffb04a', 14, 60, 30, 0.4)
    elseif sk == 'bulwark' then -- 守护熊：守护誓言
        for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 60 then o.target = e end end
        e.shield = min(e.maxHp, (e.shield or 0) + e.maxHp * 0.3)
        for o in of(alliesOf(B, e)) do
            if o ~= e and hypot(o.x - e.x, o.y - e.y) <= 40 then o.shield = min(o.maxHp, (o.shield or 0) + o.maxHp * 0.2); FX.ring(o.x, o.y, 8, '#8ab4dc') end
        end
        FX.ring(e.x, e.y, 30, '#7fb0e0')
    elseif sk == 'infest' then -- 寄生花：寄生爆发
        hit(e, t, e.atk * 1.0); addPoison(t, e, 3)
        local n = t.poison and t.poison.n or 3
        for o in of(foesOf(B, e)) do
            if o ~= t and hypot(o.x - t.x, o.y - t.y) <= 30 then addPoison(o, e, n); FX.particle(o.x, o.y, '#b0e05a', 6, 30, -10, 0.5) end
        end
        FX.ring(t.x, t.y, 28, '#b0e05a')
    elseif sk == 'cleanse' then -- 净化花：净化之光
        for o in of(alliesOf(B, e)) do cleanse(o, true); o.ccShield = 3; healAmt(o, o.maxHp * 0.08) end
        B.tint = { t = 0.4, max = 0.4, rgb = '220,240,255' }

    -- —— 超凡 ——
    elseif sk == 'crimsonmoon' then -- 赤魇剑皇：血月斩
        strikeAt(e)
        local dealt = 0
        for o in of(foesOf(B, e)) do
            local dx, dy = o.x - e.x, o.y - e.y
            if not (hypot(dx, dy * 1.2) > 64 or dx * e.face < -8) then
                dealt = dealt + hit(e, o, e.atk * 3.2, { noLeech = true })
                if not o.dead then applyBleed(o, e, 4, e.atk * 0.6) end
            end
        end
        healAmt(e, dealt * 0.25)
        FX.crescent(e.x + e.face * 8, e.y - 4, e.face, 30)
        B.tint = { t = 0.35, max = 0.35, rgb = '200,20,40' }; G.shake = max(G.shake --[[@as number]], 0.35)
    elseif sk == 'bloodarrow' then -- 赤月弓神：赤月天罚
        local dx, dy = t.x - e.x, (t.y - 3) - (e.y - 3)
        local d = hypot(dx, dy)
        if d == 0 then d = 1 end
        shoot(B, e, nil, 'bloodpierce', { pierce = true, vx = dx / d, vy = dy / d, ang = atan(dy, dx), speed = 300, mul = 4.5, hitSet = js.Set(),
            curse = { t = 6, vuln = 0.35, weak = 0 } })
        B.tint = { t = 0.3, max = 0.3, rgb = '200,20,40' }; G.shake = max(G.shake --[[@as number]], 0.25)
    elseif sk == 'bloodmoon' then -- 血月魔尊：血月降临
        foesOf(B, e):forEach(function(o, i)
            local sx = o.x + rand(-10, 10)
            shoot(B, e, o, 'bloodstar', { x = sx, y = -8, speed = 240, delay = 0.2 + i * 0.05, mul = 2.4,
                burn = { t = 4, dps = e.atk * 0.4 } })
        end)
        for o in of(alliesOf(B, e)) do o.haste = max(o.haste or 0, 3); FX.ring(o.x, o.y, 8, '#ff3434') end
        B.moon = { t = 1.6, max = 1.6 }; B.tint = { t = 1.2, max = 1.2, rgb = '120,0,20' }; G.shake = max(G.shake --[[@as number]], 0.2)
    elseif sk == 'bloodrush' then -- 血煞魔虎：百裂血爪
        local px, py = e.x, e.y
        for i = 0, 4 do
            local foes = foesOf(B, e):filter(function(o) return not o.immune end)
            if #foes == 0 then break end
            local TT = foes:sort(byHpFrac)[0]
            local dir = (TT.x >= px) and 1 or -1
            local nx, ny = clamp(TT.x - dir * (TT.r + e.r + 2), 6, AW - 6), landY(TT.y)
            FX.trail(px, py - 4, nx, ny - 4, '#ff3434')
            px = nx; py = ny; e.face = dir; e.target = TT
            hit(e, TT, e.atk * 2.2, { melee = true, forceCrit = true }); FX.slash(TT.x, TT.y); FX.burst(TT.x, TT.y - 4, '#ff3434', 8)
        end
        e.x = px; e.y = py; strikeAt(e)
        G.shake = max(G.shake --[[@as number]], 0.3)
    elseif sk == 'doomstomp' then -- 赤铠熊魔：末日践踏
        strikeAt(e)
        for o in of(foesOf(B, e)) do
            if hypot(o.x - e.x, o.y - e.y) <= 52 then
                hit(e, o, e.atk * 2.6, { noLeech = true })
                if not o.dead then o.stun = max(o.stun, o.big and 1 or 2); o.target = e end
            end
        end
        e.shield = min(e.maxHp, (e.shield or 0) + e.maxHp * 0.4)
        FX.ring(e.x, e.y, 46, '#ff3434'); FX.ring(e.x, e.y, 28, '#ff8e6a'); FX.quake(e.x, e.y)
        FX.particle(e.x, e.y + 6, '#7a2d42', 30, 80, 120, 0.6)
        B.tint = { t = 0.3, max = 0.3, rgb = '200,20,40' }; G.shake = max(G.shake --[[@as number]], 0.5)
    elseif sk == 'bloodthorn' then -- 噬魂血棘：血棘之海
        local dealt = 0
        for o in of(foesOf(B, e)) do
            dealt = dealt + hit(e, o, e.atk * 1.8)
            if not o.dead then addPoison(o, e, 4); o.stun = max(o.stun, o.big and 0.6 or 1.5) end
            FX.thorns(o.x, o.y)
        end
        local al = alliesOf(B, e)
        if #al > 0 then al:forEach(function(o) healAmt(o, dealt * 0.3 / #al) end) end
        B.tint = { t = 0.4, max = 0.4, rgb = '150,10,40' }; G.shake = max(G.shake --[[@as number]], 0.25)
    elseif sk == 'rebirth' then -- 赤阳神葵：赤阳涅槃
        if not e.rebirthUsed then
            e.rebirthUsed = true
            B.ents:filter(function(o) return o.dead and o.side == e.side and not o.minion and o ~= e end):forEach(function(o) revive(o, 0.5) end)
        end
        for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.3); o.haste = max(o.haste or 0, 4); FX.ring(o.x, o.y, 9, '#ff8e6a') end
        for o in of(foesOf(B, e)) do hit(e, o, e.atk * 1.2); applyBurn(o, e, 3, e.atk * 0.4) end
        FX.ring(e.x, e.y, 34, '#ff3434'); B.tint = { t = 0.6, max = 0.6, rgb = '255,80,40' }; G.shake = max(G.shake --[[@as number]], 0.25)

    -- —— 敌方 ——
    elseif c45Cast(B, e, t, sk) then -- 第四、五章：暴风雪、冰霜新星、神谕沉默、星陨
    elseif sk == 'rally' then
        for o in of(alliesOf(B, e)) do o.haste = max(o.haste or 0, 3); FX.ring(o.x, o.y, 8, '#ff6a4a') end
    elseif sk == 'mend' then
        local al = alliesOf(B, e)
        local low = al:slice():sort(byHpFrac)[0]
        if low then healAmt(low, low.maxHp * 0.3) end
        al:forEach(function(o) if o ~= low then healAmt(o, o.maxHp * 0.08) end end)
        FX.ring(e.x, e.y, 20, '#9be36b')
    elseif sk == 'lavapool' then
        shoot(B, e, t, 'lavaball', { area = true, splash = 14, mul = 0.8, pool = true, speed = 90 })
    elseif sk == 'forge' then
        for o in of(alliesOf(B, e)) do o.shield = min(o.maxHp * 0.5, (o.shield or 0) + o.maxHp * 0.25); FX.ring(o.x, o.y, 9, '#ffb04a') end
        FX.ring(e.x, e.y, 20, '#ffb04a')
    elseif sk == 'fissure' then
        local dx, dy = t.x - e.x, t.y - e.y
        local d = hypot(dx, dy)
        if d == 0 then d = 1 end
        local L = 230
        B.fields:push({ kind = 'fissure', x = e.x, y = e.y + 4, x2 = e.x + dx / d * L, y2 = e.y + 4 + dy / d * L, w = 7,
            warn = 0.9, t = 1.4, max = 1.4, src = e, mul = 1.8, fired = false })
    elseif sk == 'charm' then charm(B, e, 3)
    elseif sk == 'rift' then
        local fs = foesOf(B, e)
        local main = fs:filter(function(o) return not o.minion end)
        local pool = (#main > 0) and main or fs
        pool:slice():sort(function() return js.random() - 0.5 end):slice(0, 3)
            :forEach(function(o) B.fields:push({ kind = 'rift', x = o.x, y = o.y + 3, r = 15, warn = 1.2, t = 1.25, max = 1.25, src = e, mul = 1.6, fired = false }) end)
    end
end

return true
