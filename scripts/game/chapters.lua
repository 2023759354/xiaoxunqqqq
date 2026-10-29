-- ============================================================================
-- 第六章「蚀骨沼泽」/ 第七章「沉没海渊」：更新包的增量章节。
-- 在 UI / render / rules / skills_ext 装配后加载；不覆盖第四五章的任何表。
-- A() 是 JS 兼容零基数组，CHAPTERS / CH_RULES 的新索引为 5 / 6。
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S = js.A, js.T, js.S
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, sin, sqrt = math.floor, math.ceil, js.max, math.min, math.sin, math.sqrt
local of = js.of

-- ---------- 敌人：以现有第五章为基准提高基础属性和难度，不能沿用更新包第四五章的低数值 ----------
local E = ENEMIES
E.corpsetoad = { ch = 5, name = '腐尸蟾', sprite = 'corpsetoad', hp = 125, atk = 15, cd = 1, range = 7, speed = 18, r = 5, fx = { deathPool = true },
    desc = '死后在原地留下 4 秒的毒池，站在里面会持续叠加剧毒并减速；别让近战在它尸体上恋战' }
E.sporesac = { ch = 5, name = '孢子囊', sprite = 'sporesac', hp = 300, atk = 1, cd = 99, range = 0, speed = 0, r = 5, proj = 'spore', fx = { anchor = true, inert = true, sporeAura = true },
    desc = '不会移动也不攻击；每 4 秒给周围的敌人 3 秒「孢子护体」（受到的伤害 -30%），优先打掉' }
E.bogwitch = { ch = 5, name = '沼泽女巫', sprite = 'charmer', hp = 115, atk = 16, cd = 1.6, range = 60, speed = 14, r = 5, proj = 'dark',
    pal = { p = '#2f5a24', P = '#6fbf5a', r = '#9be36b', e = '#ffe14a', b = '#4a2f1b' }, fx = { witherHit = 4 },
    desc = '普攻让目标「枯萎」4 秒：枯萎期间无法被治疗' }
E.creeper = { ch = 5, name = '蔓生者', sprite = 'creeper', hp = 240, atk = 18, cd = 1.2, range = 8, speed = 16, r = 5, fx = { rootHit = 1.2 },
    desc = '普攻把目标「根植」1.2 秒：根植期间不能移动（仍然可以攻击和放技能）' }
E.plaguedoc = { ch = 5, name = '疫医', sprite = 'darkmage', hp = 145, atk = 12, cd = 1.6, range = 62, speed = 14, r = 5, proj = 'dark', skill = 'plaguecure',
    pal = { d = '#3a2a1a', p = '#6b4527', P = '#c9b08a', e = '#9be36b' },
    desc = '技能「黑死复苏」：复活一个阵亡的敌人（50% 生命，每个疫医最多 2 次）；没人可救时治疗受伤最重的敌人' }
E.rotmother = { ch = 5, name = '腐母', sprite = 'rotmother', hp = 4800, atk = 34, cd = 1.5, range = 10, speed = 11, r = 10, splash = 18, big = true, skill = 'acidspit',
    fx = { rphases = true },
    desc = '技能「酸液喷吐」：在目标处留下毒池。60% 生命时吞噬场上所有小怪，每吞一个回复 8% 生命并变大变强，要尽快清场；30% 生命时感染你的全体单位，8 秒后感染者爆炸并波及身边的队友，逼你分散站位（净化可以解除感染）' }
E.murloc = { ch = 6, name = '鱼人', sprite = 'murloc', hp = 90, atk = 14, cd = 0.8, range = 7, speed = 28, r = 4,
    desc = '成群结队、跑得很快的小怪，范围伤害清得最快' }
E.jelly = { ch = 6, name = '水母', sprite = 'jelly', hp = 180, atk = 16, cd = 1.1, range = 7, speed = 14, r = 5, fx = { shock = 0.6 },
    desc = '被近战攻击时放电：攻击者受到 60% 攻击的伤害，30% 几率麻痹 0.4 秒；交给远程处理' }
E.coral = { ch = 6, name = '珊瑚卫士', sprite = 'obsidian', hp = 360, atk = 21, cd = 1.4, range = 9, speed = 12, r = 6,
    pal = { d = '#a83a5a', P = '#ff8ab8', e = '#ffe2b8' }, fx = { dr = 0.45 },
    desc = '珊瑚甲：受到的伤害 -45%，不会碎裂；用诅咒、破甲锥或持续伤害对付' }
E.octo = { ch = 6, name = '章鱼炮手', sprite = 'octo', hp = 140, atk = 20, cd = 1.8, range = 64, speed = 13, r = 5, proj = 'ink', splash = 18,
    desc = '远程墨汁炮，落点有大范围溅射' }
E.tidepriest = { ch = 6, name = '潮汐祭司', sprite = 'forgepriest', hp = 160, atk = 14, cd = 1.6, range = 62, speed = 14, r = 5, proj = 'frost', skill = 'tidepush',
    pal = { b = '#1f3a6a', f = '#3aa6c8', F = '#bff4ff', e = '#6ef0ff', s = '#9fc8e8' },
    desc = '技能「潮涌」：把你的所有单位往回推开并减速 2 秒，打乱站位，同时治疗敌人 8% 生命' }
E.tentacle = { ch = 6, name = '利维坦触手', sprite = 'tentacle', hp = 440, atk = 21, cd = 1.2, range = 26, speed = 0, r = 5, fx = { anchor = true },
    desc = '利维坦潜水时伸出的触手，不会移动；全部打断后利维坦提前浮出' }
E.leviathan = { ch = 6, name = '深渊利维坦', sprite = 'leviathan', hp = 5600, atk = 38, cd = 1.7, range = 74, speed = 8, r = 10, proj = 'ink', splash = 16, big = true, skill = 'tidalwave',
    fx = { levCycle = true },
    desc = '技能「海啸」：沿直线掀起巨浪并减速。每隔一段时间潜入深海（无法选中），伸出 3 条触手；打断全部触手或潜水 7 秒后浮出，浮出后 4 秒内受到的伤害 +30%，爆发流的机会；半血时召唤鱼人援军' }
for _, k in ipairs({ 'corpsetoad', 'sporesac', 'bogwitch', 'creeper', 'plaguedoc', 'rotmother', 'murloc', 'jelly', 'coral', 'octo', 'tidepriest', 'tentacle', 'leviathan' }) do ENEMY_KEYS:push(k) end
ATK_STYLE_EN.corpsetoad = 'bounce'; ATK_STYLE_EN.sporesac = 'pulse'; ATK_STYLE_EN.bogwitch = 'cast'; ATK_STYLE_EN.creeper = 'claw'; ATK_STYLE_EN.plaguedoc = 'cast'; ATK_STYLE_EN.rotmother = 'maul'
ATK_STYLE_EN.murloc = 'claw'; ATK_STYLE_EN.jelly = 'bounce'; ATK_STYLE_EN.coral = 'maul'; ATK_STYLE_EN.octo = 'cast'; ATK_STYLE_EN.tidepriest = 'cast'; ATK_STYLE_EN.tentacle = 'slash'; ATK_STYLE_EN.leviathan = 'cast'
ATK_EN_COL.corpsetoad = '#9be36b'; ATK_EN_COL.creeper = '#4fbf4a'; ATK_EN_COL.rotmother = '#9be36b'; ATK_EN_COL.murloc = '#78a8f2'; ATK_EN_COL.jelly = '#6ef0ff'; ATK_EN_COL.coral = '#ff8ab8'; ATK_EN_COL.tentacle = '#8f4bc4'
PROJ_BURST.ink = '#5a2a7a'; PROJ_BURST.spore = '#8f4bc4'
SKILLS.plaguecure = { name = '黑死复苏', charge = 30, desc = '复活一个阵亡的敌人（50% 生命），没人可救时治疗受伤最重的敌人' }
SKILLS.acidspit = { name = '酸液喷吐', charge = 30, desc = '在目标处留下持续 4 秒的毒池' }
SKILLS.tidepush = { name = '潮涌', charge = 30, desc = '把对面的单位全部往回推开并减速，治疗己方 8% 生命' }
SKILLS.tidalwave = { name = '海啸', charge = 34, desc = '预警后沿直线掀起巨浪，造成 180% 伤害并减速' }

-- ---------- 波次与难度：独立命名，不能覆盖 WAVES4/5、DIFFS4/5 ----------
local function W(str)
    local map = { T = 'corpsetoad', S = 'sporesac', W = 'bogwitch', C = 'creeper', D = 'plaguedoc', M = 'murloc', J = 'jelly', K = 'coral', O = 'octo', P = 'tidepriest' }
    local out = A()
    for ch in str:gmatch('%a') do out:push(map[ch]) end
    return out
end
WAVES6 = A(W 'TTW', W 'CTTW', W 'CTTWS', W 'CCTW', W 'CCTSWD', W 'CTTTSWD', W 'CCTTWWD', W 'CCCTSWWD', W 'CCCTTSWWD', W 'CCCTTSWWDD',
    W 'CCCCTTSWWD', W 'CCCTTTSSWWD', W 'CCCCTTSWWWD', W 'CCCCTTSSWWDD', W 'CCCCCTTSSWWD', W 'CCCCCTTTSSWWDD', W 'CCCCCTTTSSWWWDD')
WAVES7 = A(W 'MMMMJ', W 'KMMMJ', W 'KJMMMO', W 'KKMMJO', W 'KJMMOP', W 'KKMMJOP', W 'KJJMMMOO', W 'KKJMMOOP', W 'KKJJMMOOP', W 'KKJMMMOOPP',
    W 'KKKJJMMOOP', W 'KKJJMMMOOOP', W 'KKKJJMMOOPP', W 'KKKJJJMMOOP', W 'KKKKJJMMOOPP', W 'KKKKJJMMMOOOPP', W 'KKKKJJJMMMOOOPP')
local function bossWave6(n)
    if n >= 16 then return A('rotmother', 'creeper', 'creeper', 'corpsetoad', 'sporesac', 'bogwitch', 'plaguedoc') end
    if n >= 14 then return A('rotmother', 'creeper', 'creeper', 'sporesac', 'bogwitch', 'plaguedoc') end
    return A('rotmother', 'creeper', 'corpsetoad', 'bogwitch', 'plaguedoc')
end
local function bossWave7(n)
    if n >= 16 then return A('leviathan', 'coral', 'coral', 'jelly', 'octo', 'octo', 'tidepriest') end
    if n >= 14 then return A('leviathan', 'coral', 'coral', 'jelly', 'octo', 'tidepriest') end
    return A('leviathan', 'coral', 'jelly', 'octo', 'tidepriest')
end
local function diffs(base, hard, night, hell, gold)
    -- gold 是普通 Lua table（一基），返回值才是兼容零基数组。
    return A(
        { name = '普通', color = '#8fe07a', mult = base, extra = 0, elite = 0.12, lives = 3, adds = 2, gold = gold[1], waves = 12, desc = '共 12 波。全新的敌人和战场规则，整体比上一章同难度更强；开局多 ' .. gold[1] .. ' 金币' },
        { name = '困难', color = '#ffd84a', mult = hard, extra = 1, elite = 0.22, lives = 3, adds = 2, gold = gold[2], waves = 14, desc = '共 14 波。敌人最高 +' .. round((hard - 1) * 100) .. '%，第 3 波起每波多 1 个敌人，精英更多；开局多 ' .. gold[2] .. ' 金币' },
        { name = '噩梦', color = '#ff9b8c', mult = night, extra = 1, elite = 0.32, lives = 3, adds = 3, gold = gold[3], waves = 16, desc = '共 16 波。敌人最高 +' .. round((night - 1) * 100) .. '%，精英更多；首领召唤 3 个援军；开局多 ' .. gold[3] .. ' 金币' },
        { name = '炼狱', color = '#e09cff', mult = hell, extra = 2, elite = 0.42, lives = 2, adds = 4, gold = gold[4], waves = 18, desc = '共 18 波。敌人最高 +' .. round((hell - 1) * 100) .. '%，每波最多多 2 个敌人；首领召唤 4 个援军；只有 2 点生命，开局多 ' .. gold[4] .. ' 金币' })
end
DIFFS6 = diffs(2.25, 2.85, 3.45, 4.05, { 6, 9, 12, 16 })
DIFFS7 = diffs(2.55, 3.2, 3.85, 4.5, { 7, 10, 13, 17 })
SOUL_CH:push(2.8, 3.2)
CHAPTERS:push({ name = '第六章', title = '蚀骨沼泽', key = 'reel-legion-c6', color = '#9be36b', bg = 'swamp', bossName = '腐母',
    desc = '毒池、孢子、枯萎、根植的沼泽生物，毒雾让治疗变弱；尽头是会吞噬同伴、感染军团的腐母',
    rage = A('corpsetoad', 'creeper'), waves = WAVES6, diffs = DIFFS6, boss = bossWave6,
    bossWarn = function(Df) return '腐母会带着护卫出场。60% 生命时吞噬场上所有小怪回血变大，先清小怪；30% 生命时感染你的全体单位，8 秒后爆炸并波及身边队友，分散站位或用净化解除' .. (T(Df.adds) and ('；半血时召唤 ' .. S(Df.adds) .. ' 个援军') or '') .. '。' end })
CHAPTERS:push({ name = '第七章', title = '沉没海渊', key = 'reel-legion-c7', color = '#6ec8ff', bg = 'sea', bossName = '深渊利维坦',
    desc = '成群的鱼人、放电水母、珊瑚卫士和推人的潮汐祭司，潮汐轮流限制远程和近战；尽头是潜水浮出的深渊利维坦',
    rage = A('murloc', 'murloc'), waves = WAVES7, diffs = DIFFS7, boss = bossWave7,
    bossWarn = function(Df) return '深渊利维坦会带着护卫出场。它会潜入深海无法选中，同时伸出 3 条触手，打断触手它就提前浮出；浮出后 4 秒内受到的伤害 +30%，留好技能爆发' .. (T(Df.adds) and ('；半血时召唤 ' .. S(Df.adds) .. ' 个鱼人') or '') .. '。' end })
CH_RULES[5] = { cells = { swamp = 2, altar = 1 }, healMul = 0.75, burnMul = 1.3, ban = 'sunflower', short = '毒雾：治疗 -25%、灼烧 +30%',
    text = A('<b>毒雾</b>整场生效：所有治疗效果 -25%，灼烧伤害 +30%。') }
CH_RULES[6] = { cells = { seal = 2, high = 1 }, global = 'tide', ban = 'archer', short = '潮汐每 20 秒涨落',
    text = A('<b>潮汐</b>每 20 秒涨落一次：涨潮时远程射程 -25%，退潮时近战移动速度 -30%，两边轮流受限。', '两个格子被海水淹没（封印格），只剩 10 个格子可以布阵。') }

-- ---------- 机制 ----------
local function quietKill(o)
    o.hp = 0; o.dead = true; o.deadT = 0
end
addHook('ent', function(ent)
    if ent.sporeAura then ent.sporeT = 2 + js.random() end
    if ent.rphases then
        ent.onHurt = function(t)
            if not t.ph1 and t.hp < t.maxHp * 0.6 then t.hp = floor(t.maxHp * 0.6)
            elseif not t.ph2 and t.hp < t.maxHp * 0.3 then t.hp = floor(t.maxHp * 0.3) end
        end
    end
    if ent.levCycle then ent.levT = 9; ent.levState = 'up' end
end)
function stepInfect(B, e, dt)
    local I = e.infect
    I.t = I.t - dt
    if js.random() < 0.25 then FX.parts:push({ x = e.x + rand(-4, 4), y = e.y - 8, vx = 0, vy = -8, g = 0, life = 0.4, max = 0.4, color = '#c4f05a', size = 1 }) end
    if I.t > 0 then return end
    e.infect = nil
    local src = (I.src and not I.src.dead) and I.src or envSource(B)
    hit(src, e, e.maxHp * 0.25, { noCrit = true, noLeech = true, dot = true })
    -- 感染碰撞范围（像素）：感染者中心 o----24----|，含等于边界；只波及同阵营。
    -- 自身25%最大生命，24像素内队友20%；阵亡、敌方及感染者自己不重复命中。
    for o in of(B.ents) do
        if not o.dead and o ~= e and o.side == e.side and hypot(o.x - e.x, o.y - e.y) <= 24 then hit(src, o, e.maxHp * 0.2, { noCrit = true, noLeech = true, dot = true }) end
    end
    FX.ring(e.x, e.y, 22, '#c4f05a'); FX.particle(e.x, e.y, '#9be36b', 20, 70, 30, 0.6); G.shake = max(G.shake, 0.25); Sound.play('die')
end
local function callAdds(B, e)
    -- rphases / levCycle 不走前三章的 bossRage；各自在半血时只召援一次。
    if e.newAdds or e.hp > e.maxHp * 0.5 then return end
    e.newAdds = true
    local pool = curCh().rage
    for i = 0, (e.adds or 0) - 1 do
        spawnEnemy(B, pool[i % #pool], clamp(e.x + rand(-8, 12), 12, AW - 12), clamp(e.y + rand(-28, 28), 14, FIELD_H - 10), 0.8)
    end
end
local function rotPhase(B, e)
    local f = e.hp / e.maxHp
    if not e.ph1 and f <= 0.6 then
        e.ph1 = true
        local n = 0
        for o in of(B.ents) do
            if not o.dead and o.side == e.side and o ~= e and not o.big then
                FX.trail(o.x, o.y - 4, e.x, e.y - 4, '#9be36b'); FX.particle(o.x, o.y, '#4fbf4a', 10, 40, 20, 0.5)
                quietKill(o); n = n + 1
            end
        end
        healAmt(e, e.maxHp * 0.08 * n)
        e.r = 12; e.atk = round(e.atk * (1 + 0.08 * n + 0.1)); e.grown = true
        FX.skill(e, '吞噬'); FX.ring(e.x, e.y, 26, '#9be36b'); G.shake = max(G.shake, 0.35)
    end
    if not e.ph2 and f <= 0.3 then
        e.ph2 = true
        for o in of(foesOf(B, e)) do if not o.minion then o.infect = { t = 8, src = e } end end
        FX.skill(e, '腐疫感染'); B.tint = { t = 0.6, max = 0.6, rgb = '120,180,40' }; G.shake = max(G.shake, 0.3)
    end
    callAdds(B, e)
end
local function levPhase(B, e, dt)
    callAdds(B, e)
    if e.levState == 'up' then
        e.levT = e.levT - dt
        if e.levT <= 0 then
            e.levState = 'down'; e.levT = 7; e.immune = true; e.untargetable = true; e.shifted = true; e.stun = 0
            FX.skill(e, '潜入深海'); FX.particle(e.x, e.y, '#6ec8ff', 24, 60, 30, 0.7)
            for o in of(B.ents) do if o.target == e then o.target = nil end end
            e.tents = A(A(170, 30), A(150, 72), A(170, 114)):map(function(p) return spawnEnemy(B, 'tentacle', p[0] + rand(-6, 6), p[1], 0.8) end)
        end
    elseif e.levState == 'down' then
        e.levT = e.levT - dt
        local cut = e.tents:every(function(t) return t.dead end)
        if cut or e.levT <= 0 then
            e.levState = 'up'; e.levT = 10; e.immune = false; e.untargetable = false; e.shifted = false; e.surfaceT = 4
            for t in of(e.tents) do if not t.dead then quietKill(t) end end
            FX.skill(e, cut and '触手被打断' or '浮出水面'); FX.ring(e.x, e.y, 24, '#6ec8ff'); G.shake = max(G.shake, 0.3)
            if cut then e.stun = max(e.stun, 1.5) end
        end
    end
end
addHook('step', function(B, dt, alive)
    if B.over then return end
    for e in of(alive) do
        if not e.dead then
            if e.sporeAura then
                e.sporeT = e.sporeT - dt
                if e.sporeT <= 0 then
                    e.sporeT = 4
                    for o in of(B.ents) do
                        if not o.dead and o.side == e.side and o ~= e and hypot(o.x - e.x, o.y - e.y) <= 44 then
                            if not (o.guard and o.guard.dr > 0.3) then o.guard = { t = 3, dr = 0.3 } end
                            FX.particle(o.x, o.y - 4, '#c06bff', 4, 20, -10, 0.4)
                        end
                    end
                    FX.ring(e.x, e.y, 40, '#8f4bc4')
                end
            end
            if e.rphases then rotPhase(B, e) end
            if e.levCycle then levPhase(B, e, dt) end
        end
    end
end)

-- ---------- 敌方技能：包装已装配的 skills / skills_ext，不绕过旧章节技能 ----------
local _castSkill = castSkill
function castSkill(B, e, t)
    local sk = e.skill
    if sk == 'plaguecure' then
        FX.skill(e, SKILLS[sk].name)
        e.revives = e.revives or 0
        local fallen = (e.revives < 2) and B.ents:filter(function(o) return o.dead and o.side == e.side and not o.big and not o.exploded and o.type and o.type ~= 'tentacle' and o.deadT < 20 end)[0] or nil
        if fallen then
            e.revives = e.revives + 1
            revive(fallen, 0.5); fallen.splitDone = true
            FX.ring(fallen.x, fallen.y, 12, '#9be36b')
        else
            local al = alliesOf(B, e)
            local low = al:slice():sort(function(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end)[0]
            if low then healAmt(low, low.maxHp * 0.25) end
            al:forEach(function(o) if o ~= low then healAmt(o, o.maxHp * 0.06) end end)
        end
        return
    elseif sk == 'acidspit' then
        FX.skill(e, SKILLS[sk].name)
        hit(e, t, e.atk)
        B.fields:push({ kind = 'cloud', x = t.x, y = t.y, r = 22, t = 4, max = 4, tick = 0.5, src = e, foe = true })
        return
    elseif sk == 'tidepush' then
        FX.skill(e, SKILLS[sk].name)
        for o in of(foesOf(B, e)) do
            if not o.big and not o.anchor then o.x = clamp(o.x - 18, 6, AW - 6) end
            applySlow(o, 2, 0.3); o.target = nil
            FX.particle(o.x, o.y, '#6ec8ff', 4, 30, 10, 0.4)
        end
        for o in of(alliesOf(B, e)) do healAmt(o, o.maxHp * 0.08) end
        B.tint = { t = 0.4, max = 0.4, rgb = '60,140,220' }
        return
    elseif sk == 'tidalwave' then
        FX.skill(e, SKILLS[sk].name)
        local dx, dy = t.x - e.x, t.y - e.y
        local d = hypot(dx, dy); if d == 0 then d = 1 end
        B.fields:push({ kind = 'wave', x = e.x, y = e.y + 4, x2 = e.x + dx / d * 240, y2 = e.y + 4 + dy / d * 240, w = 9, warn = 1, t = 1.5, max = 1.5, src = e, mul = 1.8, fired = false })
        return
    end
    return _castSkill(B, e, t)
end
local _stepHazard = stepHazard
function stepHazard(B, f, dt)
    if f.kind == 'wave' then
        f.t = f.t - dt
        -- 海啸命中区域：线段 A================B，半宽9 + 单位半径r。
        -- segDist 同时处理起终点与零长线；擦边（等于宽度）命中，每道浪只结算一次。
        if not f.fired and f.t <= f.max - f.warn then
            f.fired = true
            for o in of(foesOf(B, f.src)) do
                if segDist(o.x, o.y, f.x, f.y, f.x2, f.y2) <= f.w + o.r then
                    hit(f.src, o, f.src.atk * f.mul, { noLeech = true }); applySlow(o, 3, 0.4)
                    if not o.big and not o.anchor then o.x = clamp(o.x - 8, 6, AW - 6) end
                end
            end
            G.shake = max(G.shake, 0.3)
        end
        if f.t <= 0 then f.done = true end
        return
    end
    return _stepHazard(B, f, dt)
end
FIELD_DRAW.wave = function(f)
    local n = max(1, round(hypot(f.x2 - f.x, f.y2 - f.y) / 3))
    if not f.fired then
        if floor(G.time * 10) % 2 ~= 0 then return end
        actx.fillStyle = '#6ec8ff'
        for i = 2, n, 2 do local k = i / n; actx:fillRect(round(f.x + (f.x2 - f.x) * k), round(f.y + (f.y2 - f.y) * k), 2, 1) end
        return
    end
    actx.globalAlpha = clamp(f.t / 0.5, 0, 1)
    for i = 1, n do
        local k = i / n
        local x, y = round(f.x + (f.x2 - f.x) * k), round(f.y + (f.y2 - f.y) * k)
        actx.fillStyle = '#1f3a6a'; actx:fillRect(x - 1, y - 1, 3, 3)
        actx.fillStyle = (i % 2 ~= 0) and '#6ec8ff' or '#ffffff'; actx:fillRect(x, y - 1 - (i % 3), 1, 2)
    end
    actx.globalAlpha = 1
end
PROJ_DRAW.ink = function(p)
    local x, y = round(p.x), round(p.y)
    actx.fillStyle = '#2b1a3a'; actx:fillRect(x - 2, y - 1, 5, 3); actx:fillRect(x - 1, y - 2, 3, 5)
    actx.fillStyle = '#8f4bc4'; actx:fillRect(x - 1, y - 1, 2, 2)
    if js.random() < 0.4 then FX.parts:push({ x = p.x, y = p.y, vx = 0, vy = 6, g = 0, life = 0.3, max = 0.3, color = '#5a2a7a', size = 1 }) end
end
local _drawHp = drawHp
function drawHp(e)
    _drawHp(e)
    if e.infect and not e.dead then pixText(actx, S(ceil(e.infect.t)), e.x, e.y - 24, '#c4f05a') end
    if (e.surfaceT or 0) > 0 and not e.dead and floor(G.time * 6) % 2 == 0 then pixText(actx, '!', e.x + 12, e.y - 24, '#ffe14a') end
end

-- ---------- 程序化背景：不替换现有冰原 / 神殿背景 ----------
BG_PAINT.swamp = function(x, rnd)
    x:fill(0, 0, AW, FIELD_H, '#2f3b26')
    local mud = { [0] = '#2a3522', '#36442b', '#263020', '#3b4a2e' }
    for _ = 0, 1499 do local c = mud[floor(rnd() * 4)]; x:fill(floor(rnd() * AW), floor(rnd() * FIELD_H), 1, 1, c) end
    for _ = 0, 8 do
        local cx, cy = 10 + rnd() * (AW - 20), 16 + rnd() * (FIELD_H - 28)
        local rw, rh = 8 + floor(rnd() * 12), 3 + floor(rnd() * 3)
        for dy = -rh, rh do
            local w = floor(rw * sqrt(max(0, 1 - (dy / rh) ^ 2)))
            x:fill(floor(cx - w), floor(cy + dy), w * 2, 1, (dy == -rh) and '#1c2418' or '#3a5a4a')
        end
        x:fill(floor(cx - rw * 0.4), floor(cy - 1), floor(rw * 0.5), 1, '#5a8a6a')
    end
    for _ = 0, 59 do
        local px, py = floor(rnd() * AW), 12 + floor(rnd() * (FIELD_H - 14))
        local h = 2 + floor(rnd() * 3)
        x:fill(px, py - h, 1, h, '#5a7a3a'); if rnd() < 0.4 then x:fill(px, py - h - 1, 1, 1, '#8a6a3a') end
    end
    for _ = 0, 17 do local c = (rnd() < 0.5) and '#9be36b' or '#c4f05a'; x:fill(floor(rnd() * AW), 10 + floor(rnd() * (FIELD_H - 12)), 1, 1, c) end
    x:fill(0, 0, AW, 7, '#1a2214')
    for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#1a2214') end
    for i = 0, AW - 1, 7 do local py = 2 + floor(rnd() * 3); x:fill(i + floor(rnd() * 3), py, 1, 3, '#3a4a2a') end
end
BG_PAINT.sea = function(x, rnd)
    x:fill(0, 0, AW, FIELD_H, '#16324e')
    local sea = { [0] = '#14304a', '#1a3a58', '#12283f', '#1d4062' }
    for _ = 0, 1499 do local c = sea[floor(rnd() * 4)]; x:fill(floor(rnd() * AW), floor(rnd() * FIELD_H), 1, 1, c) end
    for gy = 30, FIELD_H - 4, 22 do
        for gx = 0, AW - 1 do
            local yy = gy + floor(2 * sin(gx / 9 + gy))
            if (gx + gy) % 3 ~= 0 then x:fill(gx, yy, 1, 1, '#24507a') end
        end
    end
    for _ = 0, 11 do
        local px, py = 6 + floor(rnd() * (AW - 12)), 16 + floor(rnd() * (FIELD_H - 22))
        local col = (rnd() < 0.5) and '#ff8ab8' or '#ff8a6a'
        x:fill(px, py - 3, 1, 4, col); x:fill(px - 2, py - 2, 1, 2, col); x:fill(px + 2, py - 4, 1, 3, col); x:fill(px - 1, py, 4, 1, '#a83a5a')
    end
    for _ = 0, 27 do local c = (rnd() < 0.5) and '#9fdcff' or '#6ec8ff'; x:fill(floor(rnd() * AW), 10 + floor(rnd() * (FIELD_H - 12)), 1, 1, c) end
    x:fill(0, 0, AW, 7, '#0c1a2c')
    for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#0c1a2c') end
    for i = 0, AW - 1, 11 do x:fill(i + floor(rnd() * 5), 3 + floor(rnd() * 2), 2, 1, '#2a6a9a') end
end
local _renderArena = renderArena
function renderArena()
    local bg = curCh().bg
    if not REDUCED and G.phase ~= nil then
        if bg == 'swamp' and js.random() < 0.15 then
            FX.parts:push({ x = rand(0, AW), y = rand(14, FIELD_H - 4), vx = rand(-2, 2), vy = -rand(2, 6), g = 0, life = 1.4, max = 1.4, color = (js.random() < 0.6) and '#9be36b' or '#c4f05a', size = 1 })
        elseif bg == 'sea' and js.random() < 0.25 then
            FX.parts:push({ x = rand(0, AW), y = rand(20, FIELD_H - 2), vx = rand(-1, 1), vy = -rand(8, 16), g = 0, life = 1.2, max = 1.2, color = (js.random() < 0.6) and '#9fdcff' or '#ffffff', size = 1 })
        end
    end
    _renderArena()
end
return true
