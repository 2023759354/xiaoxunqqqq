-- ============================================================================
-- 第十次更新：技能和描述对齐
--  * 通用「飞行」动作：施法者真的离开地面、飞到目标、落地才结算（飞行中不能被选中、不受伤害）
--    - 幼龙传说「巨龙降临」：升空 → 飞到敌群上方 → 砸进敌群中心
--    - 雷鹰「俯冲」：扑到生命比例最低的敌人身上抓一下，再飞回原位
--    - 雷鹰传说「炎羽突袭」：本体化作火羽沿直线冲到场边再飞回
--    - 赤铠熊魔「末日践踏」：先跳起，落地时才结算
--  * 古树卫士「树皮甲」：只反弹近战伤害
--  * 几个技能的说明按代码补上漏写的数值
-- 本工程适配：EXT_SKILLS / EXT_SKILLS2 的两级分发表、末日践踏在 skills.lua 基础表里。
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S = js.A, js.T, js.S
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, max, min, abs, sin, cos, atan = math.floor, math.max, math.min, math.abs, math.sin, math.cos, math.atan
local TAU = math.pi * 2
local of = js.of

local SIG, P, R = FX.SIG, FX.P, FX.R

-- ---------------------------------------------------------------------------
-- 飞行
--  keys：{ { dur, to = {x, y} 或 function(B, e) -> x, y, z = 离地高度, fn = 到达时调用 }, ... }
--  离地高度画成往上抬（2.5D 俯视里「飞起来」）；落地点每段开始时才计算，跟得上移动中的目标
-- ---------------------------------------------------------------------------
local function easeIO(k) return k * k * (3 - 2 * k) end
function startFlight(B, e, keys)
    if e.flight then return false end
    e.flight = { keys = keys, i = 1, t = 0, sx = e.x, sy = e.y, sz = 0, speed = e.speed }
    e.speed = 0; e.immune = true; e.untargetable = true; e.flying = true
    e.cdLeft = max(e.cdLeft, 0.3)
    for o in of(B.ents) do if o.target == e then o.target = nil end end
    return true
end
local function endFlight(e)
    local F = e.flight
    if not F then return end
    e.flight = nil
    e.speed = F.speed; e.immune = false; e.untargetable = false; e.flying = nil; e.flyZ = nil
    e.x, e.y = clamp(F.sx, 6, AW - 6), clamp(F.sy, e.big and 22 or 14, FIELD_H - 10)
    e.cdLeft = max(e.cdLeft, 0.2)
end
local function stepFlight(B, e, dt)
    local F = e.flight
    F.t = F.t + dt
    local gx, gy, z = F.sx, F.sy, F.sz
    while true do
        local k = F.keys[F.i]
        if not k then endFlight(e); return end
        if not F.kx then
            local x, y
            if type(k.to) == 'function' then x, y = k.to(B, e) elseif k.to then x, y = k.to[1], k.to[2] end
            F.kx = clamp(x or F.sx, 6, AW - 6); F.ky = clamp(y or F.sy, 14, FIELD_H - 10)
        end
        local q = easeIO(min(1, F.t / max(0.01, k.dur)))
        gx = F.sx + (F.kx - F.sx) * q; gy = F.sy + (F.ky - F.sy) * q; z = F.sz + ((k.z or 0) - F.sz) * q
        if F.t < k.dur then break end
        F.t = F.t - k.dur
        F.sx, F.sy, F.sz = F.kx, F.ky, k.z or 0
        F.kx, F.ky = nil, nil
        F.i = F.i + 1
        e.x, e.y = F.sx, F.sy
        if k.fn then k.fn(B, e) end
        if not e.flight then return end
        if F.i > #F.keys then endFlight(e); return end
    end
    if gx < e.x - 0.5 then e.face = -1 elseif gx > e.x + 0.5 then e.face = 1 end
    e.x = gx; e.y = gy - z
    e.flyZ = z
    e.cdLeft = max(e.cdLeft, 0.2); e.moving = true
end
-- 飞行中的单位跳过常规行动（移动 / 普攻）：logic 的单位循环里有 `e.flight` 判定
local _stepBattle = stepBattle
function stepBattle(dt)
    _stepBattle(dt)
    local B = G.battle
    if not B then return end
    for e in of(B.ents) do
        if e.flight then
            if e.dead or B.over then endFlight(e) else stepFlight(B, e, dt) end
        end
    end
end
-- 飞行中的地面影子（离地越高越小越淡）
local _render = renderArena
function renderArena()
    _render()
    local B = G.battle
    if not B or G.phase ~= 'battle' then return end
    for e in of(B.ents) do
        if e.flight and not e.dead and (e.flyZ or 0) > 1 then
            local gy = e.y + e.flyZ
            local w = max(3, round(7 - e.flyZ / 10))
            actx.globalAlpha = clamp(0.5 - e.flyZ / 120, 0.15, 0.5)
            actx.fillStyle = '#1b1530'
            actx:fillRect(round(e.x - w), round(gy + 3), w * 2, 2); actx:fillRect(round(e.x - w + 1), round(gy + 2), w * 2 - 2, 1)
            actx.globalAlpha = 1
        end
    end
end

local function centroid(list)
    local x, y, n = 0, 0, 0
    for o in of(list) do x = x + o.x; y = y + o.y; n = n + 1 end
    if n == 0 then return nil end
    return x / n, y / n
end
local function liveFoes(B, e) return foesOf(B, e):filter(function(o) return not o.dead and not o.untargetable end) end
local function byHpFrac(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end

-- ---------------------------------------------------------------------------
-- 幼龙传说「巨龙降临」
-- ---------------------------------------------------------------------------
local function dragonImpact(B, e)
    local foes = foesOf(B, e)
    local cx, cy = e.x, e.y
    for o in of(foes) do
        if hypot(o.x - cx, o.y - cy) <= 32 + o.r then
            hit(e, o, e.atk * 3.0, { noLeech = true })
            if not o.dead then o.stun = max(o.stun, o.big and 0.75 or 1.5) end
        end
    end
    B.fields:push({ kind = 'firesea', x = cx, y = cy, r = 30, t = 5, max = 5, tick = 0.5, src = e, mul = 0.3 })
    G.shake = max(G.shake, 0.45); Sound.play('die')
    if not REDUCED then
        R.flames(cx, cy, { n = 12, r = 26, h = 12, dur = 1.6 })
        P.ring(cx, cy, 4, 40, '#ff8a2a', { thick = 3, dur = 0.5 })
        for i = 0, 5 do local an = i / 6 * TAU; P.beam(cx, cy, cx + cos(an) * 34, cy + sin(an) * 18, '#ffe14a', 1, 0.4) end
    end
    FX.ring(cx, cy, 30, '#ff6a3a'); FX.particle(cx, cy, '#ff8a2a', 26, 90, 40, 0.6); FX.particle(cx, cy + 4, '#5a3a2a', 14, 60, 100, 0.5)
end
EXT_SKILLS2.dragonfall = function(B, e, t)
    local ox, oy = e.x, e.y
    local function over(B2, e2)
        local x, y = centroid(liveFoes(B2, e2))
        if not x then x, y = t.x, t.y end
        return x, y
    end
    local land = nil
    startFlight(B, e, {
        { dur = 0.28, to = { ox, oy }, z = 30 },                                                    -- 升空
        { dur = 0.32, to = function(B2, e2) land = { over(B2, e2) }; return land[1], land[2] end, z = 42 }, -- 飞到敌群上方
        { dur = 0.14, to = function() return land[1], land[2] end, z = 0, fn = dragonImpact },      -- 砸下
    })
end
SIG.dragonfall = { '#ff6a3a', '#ffe14a', function(B, e, t, c)
    R.wings(e, '#d8433a', '#ffe14a', 0.8)
    P.ring(e.x, e.y, 4, 22, '#ff8a2a', { thick = 2, dur = 0.4 })
    FX.particle(e.x, e.y + 4, '#c9b08a', 12, 50, 60, 0.4)
end }

-- ---------------------------------------------------------------------------
-- 雷鹰「俯冲」
-- ---------------------------------------------------------------------------
EXT_SKILLS.divebomb = function(B, e, t)
    local tgt = foesOf(B, e):filter(function(o) return not o.immune and not o.untargetable end):sort(byHpFrac)[0] or t
    if not tgt then return end
    local ox, oy = e.x, e.y
    local function beside()
        local dir = (tgt.x >= ox) and 1 or -1
        return tgt.x - dir * (tgt.r + e.r + 1), tgt.y
    end
    startFlight(B, e, {
        { dur = 0.16, to = { ox, oy }, z = 24 },
        { dur = 0.22, to = beside, z = 6 },
        { dur = 0.06, to = beside, z = 0, fn = function(B2, e2)
            e2.face = (tgt.x >= e2.x) and 1 or -1
            if not tgt.dead then
                hit(e2, tgt, e2.atk * 3.2, { melee = true })
                if tgt.dead and not e2.dead then gainEnergy(e2, 50) end
            end
            if not REDUCED then R.claws(tgt.x, tgt.y, e2.face, '#ffe680', '#ffffff'); R.rain(tgt.x, tgt.y, { n = 4, r = 6, style = 'feather', col = '#ffe680', col2 = '#ffffff' }) end
            FX.burst(tgt.x, tgt.y - 4, '#ffe14a', 8); Sound.play('zap')
        end },
        { dur = 0.30, to = { ox, oy }, z = 18 },  -- 飞回原位
        { dur = 0.10, to = { ox, oy }, z = 0 },
    })
end
SIG.divebomb = { '#ffe680', '#ffffff', function(B, e, t, c)
    P.ring(e.x, e.y, 3, 14, '#ffe680', { thick = 2, dur = 0.3 })
    local tgt = c.foes:filter(function(o) return not o.immune end):sort(byHpFrac)[0] or t
    if tgt then P.ring(tgt.x, tgt.y, 12, 3, '#ffe14a', { thick = 1, dur = 0.4 }) end
end }

-- ---------------------------------------------------------------------------
-- 雷鹰传说「炎羽突袭」：本体化作火羽贯穿直线，再飞回
-- ---------------------------------------------------------------------------
EXT_SKILLS.flameraid = function(B, e, t)
    local ox, oy = e.x, e.y
    local dx, dy = t.x - e.x, (t.y - 3) - (e.y - 3)
    local d = hypot(dx, dy); if d == 0 then d = 1 end
    local vx, vy = dx / d, dy / d
    -- 冲到直线尽头（场边）
    local L = 260
    if vx > 0.01 then L = min(L, (AW - 8 - ox) / vx) elseif vx < -0.01 then L = min(L, (ox - 8) / -vx) end
    if vy > 0.01 then L = min(L, (FIELD_H - 12 - oy) / vy) elseif vy < -0.01 then L = min(L, (oy - 16) / -vy) end
    L = max(40, L)
    local ex, ey = ox + vx * L, oy + vy * L
    local speed = 260
    shoot(B, e, nil, 'fireline', { pierce = true, vx = vx, vy = vy, ang = atan(dy, dx), speed = speed, mul = 3, hitSet = js.Set(), burn = { t = 3, dps = e.atk * 0.4 } })
    startFlight(B, e, {
        { dur = L / speed, to = { ex, ey }, z = 4 },
        { dur = 0.45, to = { ox, oy }, z = 14 },
        { dur = 0.10, to = { ox, oy }, z = 0 },
    })
end

-- ---------------------------------------------------------------------------
-- 赤铠熊魔「末日践踏」：跳起，落地结算
-- ---------------------------------------------------------------------------
local function doomImpact(B, e)
    for o in of(foesOf(B, e)) do
        if hypot(o.x - e.x, o.y - e.y) <= 52 then
            hit(e, o, e.atk * 2.6, { noLeech = true })
            if not o.dead then o.stun = max(o.stun, o.big and 1 or 2); o.target = e end
        end
    end
    e.shield = min(e.maxHp, (e.shield or 0) + e.maxHp * 0.4)
    FX.ring(e.x, e.y, 46, '#ff3434'); FX.ring(e.x, e.y, 28, '#ff8e6a'); FX.quake(e.x, e.y)
    FX.particle(e.x, e.y + 6, '#7a2d42', 30, 80, 120, 0.6)
    if not REDUCED then
        R.spikes(e.x, e.y, { n = 14, ringR = 30, h = 12, col = '#4a2a1a', col2 = '#ff5a3a', tip = '#ffb03a' })
        P.pillar(e.x, e.y, '#ff3434', '#ff8e6a', 40, 14, 0.5)
    end
    B.tint = { t = 0.3, max = 0.3, rgb = '200,20,40' }; G.shake = max(G.shake, 0.5)
end
EXT_SKILLS.doomstomp = function(B, e, t)
    local ox, oy = e.x, e.y
    -- 超凡之躯免控，跳起期间无敌
    startFlight(B, e, {
        { dur = 0.22, to = { ox, oy }, z = 18 },
        { dur = 0.12, to = { ox, oy }, z = 0, fn = doomImpact },
    })
end
SIG.doomstomp = { '#ff3434', '#ff8e6a', function(B, e, t, c)
    P.ring(e.x, e.y, 3, 18, '#ff8e6a', { thick = 2, dur = 0.3 })
end }

-- ---------------------------------------------------------------------------
-- 古树卫士「树皮甲」：只反弹近战伤害
-- ---------------------------------------------------------------------------
EXT_SKILLS.barkskin = function(B, e, t)
    e.guard = { t = 5, dr = 0.4 }; e.thornAura = { t = 5, v = 0.3, melee = true }
    FX.ring(e.x, e.y, 14, '#9b6a3c'); FX.particle(e.x, e.y, '#c9955a', 12, 40, 20, 0.5)
end
-- hit() 里的反伤：thornAura.melee 时只认近战命中。做法：远程命中时临时摘掉近战反伤光环
local _hit = hit
function hit(src, t, base, o)
    local ta = t and t.thornAura
    if ta and ta.melee and not (o and o.melee) then
        t.thornAura = nil
        local r = _hit(src, t, base, o)
        if t.thornAura == nil then t.thornAura = ta end
        return r
    end
    return _hit(src, t, base, o)
end

-- ---------------------------------------------------------------------------
-- 说明补全（数值以代码为准）
-- ---------------------------------------------------------------------------
SKILLS.acidspit.desc = '对目标造成 100% 伤害，并在目标处留下持续 4 秒的毒池（每 0.5 秒叠 1 层剧毒并减速）'
SKILLS.plaguecure.desc = '复活一个阵亡的敌人（50% 生命，每个疫医最多 2 次）；没人可救时治疗受伤最重的敌人 25% 生命，其他敌人回复 6%'
SKILLS.doomslash.desc = '向前方横扫，造成 200% 伤害并让命中的单位易伤 3 秒（受到的伤害 +20%）'
SKILLS.divebomb.desc = '飞身俯冲生命比例最低的敌人，造成 320% 伤害后飞回原位；击杀则返还 50 能量'
SKILLS.flameraid.desc = '化作火羽沿直线冲到场边再飞回，贯穿路上所有敌人，造成 300% 伤害并灼烧 3 秒'
SKILLS.dragonfall.desc = '飞上天空后砸进敌群中心：造成 300% 范围伤害、眩晕 1.5 秒（首领减半），留下持续 5 秒的火海；飞行中不会被攻击'
SKILLS.doomstomp.desc = '跃起砸地：对周围大范围内的敌人造成 260% 伤害、眩晕 2 秒（首领 1 秒）并嘲讽它们，自身获得 40% 最大生命的护盾'
if ENEMIES.plaguedoc then ENEMIES.plaguedoc.desc = '技能「黑死复苏」：复活一个阵亡的敌人（50% 生命，每个疫医最多 2 次）；没人可救时治疗受伤最重的敌人 25%、其他敌人 6%' end
if ENEMIES.rotmother and ENEMIES.rotmother.desc then ENEMIES.rotmother.desc = ENEMIES.rotmother.desc:gsub('在目标处留下毒池', '造成 100%% 伤害并在目标处留下毒池') end

return true
