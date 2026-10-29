-- ============================================================================
-- 第四章「霜狱冰原」/ 第五章「星陨神殿」：首领波、敌人机制、首领阶段
-- 由 logic.lua / skills.lua 在对应位置调用（钩子都以 c45 前缀命名）
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs = math.floor, math.ceil, js.max, math.min, math.abs
local of = js.of
-- A() 是兼容层的零起始数组；普通 Lua table 仍按原有约定使用。

-- ---------- 首领波 ----------
CHAPTERS[3].boss = function(n)
    if n >= 16 then return A('frostqueen', 'icegolem', 'icegolem', 'yeti', 'revenant', 'frostshaman', 'frostwisp') end
    if n >= 14 then return A('frostqueen', 'icegolem', 'yeti', 'revenant', 'frostshaman', 'frostwisp') end
    return A('frostqueen', 'icegolem', 'yeti', 'frostwisp', 'frostshaman')
end
CHAPTERS[4].boss = function(n)
    if n >= 16 then return A('astralking', 'sentinel', 'sentinel', 'zealot', 'arbiter', 'oracle', 'arbiter') end
    if n >= 14 then return A('astralking', 'sentinel', 'sentinel', 'zealot', 'arbiter', 'oracle') end
    return A('astralking', 'sentinel', 'zealot', 'arbiter', 'oracle')
end
CHAPTERS[3].bossWarn = function(Df)
    return '冰霜女皇会带着护卫出场。她 70% 生命时把你攻击最高的 ' .. S(c45PrisonN(Df.adds)) .. ' 个单位关进冰牢，8 秒内打碎冰牢才能救出来，否则里面的单位受到重创；35% 生命时召来永冬风暴，全场减速直到她倒下。'
end
CHAPTERS[4].bossWarn = function(Df)
    return '星穹神王会带着护卫出场。60% 生命时立起 ' .. S(max(2, Df.adds)) .. ' 座圣辉方尖碑（碑在时神王持续回血、减伤，先拆碑）；30% 生命时复活本波阵亡的敌人并进入狂热。'
end
function c45PrisonN(adds) return clamp(adds or 2, 1, 3) end

-- ---------- 生成时的初始化 ----------
---@param ent table
function c45InitEnemy(ent)
    if T(ent.holyShield) then ent.blocks = ent.holyShield; ent.blockT = 0 end
    if T(ent.fury) then ent.baseAtk = ent.atk; ent.furyN = 0 end
    if ent.judge then ent.judgeT = 0 end
end

-- ---------- 寒霜：叠满 3 层冻结 ----------
---@param t table
function c45AddChill(t, n)
    if t.dead then return end
    if (t.chillImm or 0) > 0 then return end
    local c = t.chill --[[@as table?]]
    if not c then c = { n = 0, t = 0 }; t.chill = c end
    c.n = c.n + n; c.t = 4
    applySlow(t, 2, min(0.45, 0.12 * c.n))
    if c.n >= 3 then
        t.chill = nil; t.chillImm = 2.5
        if not t.ccImmune then t.stun = max(t.stun, 1.2) end
        FX.ring(t.x, t.y, 9, '#bfe8ff'); FX.particle(t.x, t.y - 4, '#bfe8ff', 10, 40, 10, 0.5); FX.float(t.x, t.y - 16, '*', '#bfe8ff')
    end
end

-- ---------- 受击时的额外判定（在 hit() 里调用） ----------
-- 返回 true 表示这一下被完全挡住
---@param src table
---@param t table
---@param o table
function c45Block(src, t, o)
    if T(t.blocks) and not T(o.dot) and not o.reflect then
        t.blocks = t.blocks - 1
        FX.burst(t.x, t.y - 6, '#ffd84a', 4)
        if t.blocks == 0 then FX.float(t.x, t.y - 16, '0', '#ffd84a'); FX.particle(t.x, t.y - 6, '#ffd84a', 10, 50, 20, 0.5) end
        return true
    end
    return false
end
---@param B table?
---@param t table
function c45AuraDr(B, t) -- 圣辉方尖碑：附近的其他敌人减伤
    if not B or not B.eaura or t.side ~= 'e' or T(t.charmed) then return 0 end
    for ob in of(B.eaura) do
        if ob ~= t and not ob.dead and hypot(ob.x - t.x, ob.y - t.y) <= 60 then return ob.auraDr end
    end
    return 0
end
---@param src table
---@param t table
---@param o table
function c45DmgMul(src, t, o)
    local m = 1
    if src.judge and not T(o.dot) and t.hp < t.maxHp * 0.4 then m = m * 2 end -- 审判官
    return m
end
---@param src table
---@param t table
---@param o table
function c45AfterHit(src, t, o)
    if T(t.fury) and not T(o.dot) and not t.dead and t.furyN < 10 then -- 雪原巨猿
        t.furyN = t.furyN + 1; t.atk = round(t.baseAtk * (1 + t.fury * t.furyN))
    end
    if t.frostShell and not t.shellUsed and t.hp <= 0 then t.hp = 1 end -- 冰壳一定会触发
    if t.qphases then
        if not t.ph1 and t.hp < t.maxHp * 0.7 then t.hp = floor(t.maxHp * 0.7)
        elseif not t.ph2 and t.hp < t.maxHp * 0.35 then t.hp = floor(t.maxHp * 0.35) end
    end
    if t.aphases then
        if not t.ph1 and t.hp < t.maxHp * 0.6 then t.hp = floor(t.maxHp * 0.6)
        elseif not t.ph2 and t.hp < t.maxHp * 0.3 then t.hp = floor(t.maxHp * 0.3) end
    end
end

-- ---------- 阵亡时 ----------
---@param B table
---@param t table
---@param src table?
function c45OnDeath(B, t, src)
    -- 冰棺消失（被打碎，或到期）后，亡魂不该再生成新冰棺——否则「冰棺被打碎 → 亡魂被复生圣光
    -- 复活 → 亡魂再死 → 又生成冰棺」会无限循环，实体数爆炸（分离循环是 O(n²)，会卡死）。
    if t.tombOf then
        t.tombOf.tombUsed = true; t.tombOf.tombPending = false
    end
    if t.tomb and not t.tombUsed and not t.tombPending then -- 冰封亡魂：化作冰棺
        t.tombPending = true
        -- 硬上限：场上未碎的冰棺不超过 8 个，兜底防止任何标记失效导致实体爆炸。
        local tombs = 0
        for i = 0, B.ents.n - 1 do
            local o = B.ents[i]
            if o and o.type == 'icetomb' and not o.dead then tombs = tombs + 1 end
        end
        if tombs >= 8 then
            print('[拉杆军团] 冰棺已达上限，跳过生成（tombs=' .. tombs .. '）')
        else
            local tb = spawnEnemy(B, 'icetomb', t.x, t.y, 9)
            tb.maxHp = max(1, round(t.maxHp * 0.35)); tb.hp = tb.maxHp; tb.tombT = 4; tb.tombOf = t
            FX.particle(t.x, t.y, '#bfe8ff', 14, 40, 20, 0.5); FX.skill(tb, '冰棺')
        end
    end
    if t.martyr then -- 狂信者：殉道
        for o in of(alliesOf(B, t)) do healAmt(o, o.maxHp * 0.15); o.haste = max(o.haste or 0, 3) end
        FX.ring(t.x, t.y, 20, '#fff6d0'); FX.particle(t.x, t.y - 4, '#ffd84a', 16, 50, -10, 0.6); FX.skill(t, '殉道')
    end
end

-- ---------- 每帧（在 stepBattle 的单位循环里调用）。返回 true 表示本帧不再行动 ----------
---@param B table
---@param e table
---@param dt number
function c45Step(B, e, dt)
    if (e.chillImm or 0) > 0 then e.chillImm = e.chillImm - dt end
    if e.chill then e.chill.t = e.chill.t - dt; if e.chill.t <= 0 then e.chill = nil end end
    if (e.silenced or 0) > 0 then e.silenced = e.silenced - dt; e.energy = 0 end
    if T(e.holyShield) and e.blocks < e.holyShield then
        e.blockT = e.blockT + dt
        if e.blockT >= 8 then e.blockT = 0; e.blocks = e.holyShield; FX.ring(e.x, e.y, 9, '#ffd84a') end
    end
    -- 冰牢里的单位：冰牢碎了才放出来
    if e.jailed then
        if e.jailed.dead then e.jailed = nil; e.stun = 0; FX.particle(e.x, e.y, '#bfe8ff', 12, 50, 20, 0.5)
        else e.moving = false; return true end
    end
    -- 冰棺 / 冰牢 / 方尖碑：不会移动和攻击
    if e.inert then
        e.moving = false
        if e.tombT then
            e.tombT = e.tombT - dt
            if e.tombT <= 0 then
                e.hp = 0; e.dead = true; e.deadT = 0
                local r = e.tombOf --[[@as table?]]
                -- 关键：无论亡魂是否还"死着"，都要标记 tombUsed，否则亡魂被别的机制复活后再死
                -- 会再次生成冰棺，形成「亡魂死→冰棺→复活→再死→又冰棺」的无限循环（实体数爆炸）。
                if r then
                    r.tombUsed = true; r.tombPending = false
                    if r.dead then
                        r.x = e.x; r.y = e.y
                        revive(r, 0.6); FX.skill(r, '复苏'); FX.ring(r.x, r.y, 10, '#7cc0ff')
                    end
                end
            end
        elseif e.jailT then
            e.jailT = e.jailT - dt
            if e.jailT <= 0 then
                e.hp = 0; e.dead = true; e.deadT = 0
                local u = e.jailOf --[[@as table?]]
                if u and not u.dead then
                    u.jailed = nil; u.stun = 0
                    hit(e.jailBy or e, u, u.maxHp * 0.5, { noCrit = true, noLeech = true })
                    FX.ring(u.x, u.y, 12, '#3a6ea8'); FX.particle(u.x, u.y, '#7cc0ff', 18, 60, 30, 0.6); G.shake = max(G.shake --[[@as number]], 0.25)
                end
            end
        end
        return true
    end
    -- 寒冰傀儡：冰壳
    if e.frostShell and not e.shellUsed and e.hp < e.maxHp * 0.5 then
        e.shellUsed = true; e.immune = true; e.shellT = 2.5; e.stun = 0
        for o in of(B.ents) do if o.target == e then o.target = nil end end
        for o in of(foesOf(B, e)) do if hypot(o.x - e.x, o.y - e.y) <= 26 then applySlow(o, 3, 0.4) end end
        FX.skill(e, '冰壳'); FX.ring(e.x, e.y, 14, '#bfe8ff'); FX.particle(e.x, e.y, '#bfe8ff', 16, 50, 20, 0.6)
    end
    if (e.shellT or 0) > 0 then
        e.moving = false; e.shellT = e.shellT - dt
        e.hp = min(e.maxHp, e.hp + e.maxHp * 0.1 * dt)
        if e.shellT <= 0 then e.immune = false; FX.particle(e.x, e.y, '#ffffff', 12, 50, 30, 0.5) end
        return true
    end
    -- 审判官：每秒重新瞄准生命比例最低的单位
    if e.judge and not T(e.charmed) then
        e.judgeT = e.judgeT - dt
        if e.judgeT <= 0 then
            e.judgeT = 1
            local t = foesOf(B, e):filter(function(o) return not o.immune end):sort(function(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end)[0]
            if t then e.target = t end
        end
    end
    if e.qphases then c45QueenPhase(B, e, dt) end
    if e.aphases then c45KingPhase(B, e, dt) end
    if e.tether then -- 方尖碑在时，神王持续回血
        local any = false
        for p in of(e.tether) do if not p.dead then any = true end end
        if any then e.hp = min(e.maxHp, e.hp + e.maxHp * 0.015 * dt) else e.tether = nil; FX.skill(e, '碑毁') end
    end
    return false
end

-- ---------- 冰霜女皇 ----------
---@param B table
---@param e table
---@param dt number
function c45QueenPhase(B, e, dt)
    local f = e.hp / e.maxHp
    if not e.ph1 and f <= 0.7 then -- 冰封王座
        e.ph1 = true
        FX.skill(e, '冰封王座'); FX.ring(e.x, e.y, 22, '#bfe8ff'); G.shake = max(G.shake --[[@as number]], 0.3)
        local n = c45PrisonN(e.adds)
        local list = foesOf(B, e):filter(function(o) return o.side == 'p' and not o.minion and not T(o.charmed) and not o.jailed end)
            :sort(function(a, b) return b.atk - a.atk end):slice(0, n)
        list:forEach(function(u)
            local pr = spawnEnemy(B, 'iceprison', u.x + 2, u.y, 9)
            pr.maxHp = max(1, round(e.maxHp * 0.045)); pr.hp = pr.maxHp; pr.jailT = 8; pr.jailOf = u; pr.jailBy = e
            u.jailed = pr; u.stun = 0; u.target = nil
            FX.particle(u.x, u.y, '#bfe8ff', 14, 50, 20, 0.6)
        end)
    end
    if not e.ph2 and f <= 0.35 then -- 永冬风暴
        e.ph2 = true; e.frenzy = true
        FX.skill(e, '永冬风暴'); FX.ring(e.x, e.y, 26, '#ffffff'); B.tint = { t = 0.8, max = 0.8, rgb = '190,230,255' }; G.shake = max(G.shake --[[@as number]], 0.35)
        B.fields:push({ kind = 'blizzard', x = 64, y = 76, r = 400, t = 999, max = 999, tick = 0.5, src = e, mul = 0.1, slow = 0.25, drain = 3, perm = true })
    end
    if e.frenzy then e.haste = max(e.haste or 0, 0.1) end
end

-- ---------- 星穹神王 ----------
---@param B table
---@param e table
---@param dt number
function c45KingPhase(B, e, dt)
    local f = e.hp / e.maxHp
    if not e.ph1 and f <= 0.6 then -- 圣辉方尖碑
        e.ph1 = true
        FX.skill(e, '圣辉方尖'); FX.ring(e.x, e.y, 22, '#ffd84a'); G.shake = max(G.shake --[[@as number]], 0.3)
        local spots = A(A(e.x + 14, e.y - 34), A(e.x + 14, e.y + 34), A(e.x + 30, e.y))
        e.tether = A()
        for i = 0, max(2, min(3, e.adds)) - 1 do
            local p = spots[i]
            e.tether:push(spawnEnemy(B, 'obelisk', p[0], p[1], 9))
        end
    end
    if not e.ph2 and f <= 0.3 then -- 复生圣光
        e.ph2 = true; e.frenzy = true
        FX.skill(e, '复生圣光'); B.tint = { t = 0.8, max = 0.8, rgb = '255,230,140' }; G.shake = max(G.shake --[[@as number]], 0.4)
        local dead = B.ents:filter(function(o) return o.dead and o.side == 'e' and not o.inert and not o.big and not o.vcopy and not o.minion and not o.exploded end)
        dead:slice(0, 6):forEach(function(o) o.tombPending = false; revive(o, 0.4); o.haste = 3 end)
    end
    if e.frenzy then e.haste = max(e.haste or 0, 0.1) end
end

-- ---------- 技能 ----------
---@param B table
---@param e table
---@param t table
---@param sk string
function c45Cast(B, e, t, sk)
    if sk == 'blizzard' then
        B.fields:push({ kind = 'blizzard', x = t.x, y = t.y, r = 24, t = 4, max = 4, tick = 0.5, src = e, mul = 0.25, slow = 0.35, drain = 5 })
        return true
    elseif sk == 'frostnova45' then
        for o in of(foesOf(B, e)) do
            if hypot(o.x - t.x, (o.y - t.y) * 1.3) <= 28 then hit(e, o, e.atk * 1.0, { noLeech = true }); c45AddChill(o, 2) end
        end
        FX.ring(t.x, t.y, 26, '#bfe8ff'); FX.particle(t.x, t.y, '#ffffff', 20, 70, 20, 0.6); G.shake = max(G.shake --[[@as number]], 0.2)
        return true
    elseif sk == 'silence' then
        foesOf(B, e):filter(function(o) return o.skill and not o.minion end):sort(function(a, b) return b.energy - a.energy end):slice(0, 3)
            :forEach(function(o) o.silenced = 4; o.energy = 0; FX.float(o.x, o.y - 18, '...', '#b9aacb'); FX.ring(o.x, o.y, 8, '#8f7bc4') end)
        return true
    elseif sk == 'starfall45' then
        local fs = foesOf(B, e)
        local main = fs:filter(function(o) return not o.minion end)
        local pool = (#main > 0) and main or fs
        pool:slice():sort(function() return js.random() - 0.5 end):slice(0, 5)
            :forEach(function(o) B.fields:push({ kind = 'star', x = o.x, y = o.y + 3, r = 13, warn = 1.0, t = 1.05, max = 1.05, src = e, mul = 1.5, fired = false }) end)
        return true
    end
    return false
end

-- ---------- 场地效果（暴风雪 / 星陨） ----------
---@param B table
---@param f table
---@param dt number
function c45Hazard(B, f, dt)
    if f.kind == 'blizzard' then
        if f.src.dead then f.done = true; return true end
        f.t = f.t - dt; f.tick = f.tick - dt
        if f.tick <= 0 then
            f.tick = f.tick + 0.5
            for o in of(foesOf(B, f.src)) do
                if hypot(o.x - f.x, (o.y - f.y) * 1.4) <= f.r then
                    applySlow(o, 0.7, f.slow)
                    if T(f.mul) then hit(f.src, o, f.src.atk * f.mul, { noCrit = true, noLeech = true, dot = true }) end
                    if o.skill then o.energy = max(0, o.energy - f.drain) end
                end
            end
        end
        if f.t <= 0 then f.done = true end
        return true
    elseif f.kind == 'star' then
        if not f.fired and f.t <= f.max - f.warn then
            f.fired = true
            for o in of(foesOf(B, f.src)) do
                if hypot(o.x - f.x, (o.y - f.y) * 1.3) <= f.r + o.r then hit(f.src, o, f.src.atk * f.mul, { noLeech = true }) end
            end
            FX.ring(f.x, f.y, f.r, '#ffd84a'); FX.particle(f.x, f.y, '#fff6d0', 16, 70, 20, 0.5); G.shake = max(G.shake --[[@as number]], 0.15)
        end
        f.t = f.t - dt
        if f.t <= 0 then f.done = true end
        return true
    end
    return false
end

return true
