-- ============================================================================
-- 第六次更新：第八章「霜寒冰原」、第九章「天空浮城」、第十章「终焉王座」
--  * 接在第五章之后（内部编号 5 / 6 / 7，界面显示第八、九、十章）
--  * 每章 5 种新敌人 + 首领（各有专属阶段机制）、战场规则、背景、环境粒子、BGM
--  * 新格子：冰面格；新全局规则：暴风雪、狂风、混沌（每波随机前几章的一条规则）
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, sin, cos, sqrt, atan = math.floor, math.ceil, math.max, math.min, math.abs, math.sin, math.cos, math.sqrt, math.atan
local of = js.of

-- ---------------------------------------------------------------------------
-- 敌人
-- ---------------------------------------------------------------------------
local E = ENEMIES
-- 第八章：霜寒冰原（ch = 7）
E.frostwolf = { ch = 7, name = '雪狼', sprite = 'frostwolf', hp = 58, atk = 9, cd = 0.8, range = 7, speed = 30, r = 4, fx = { packFrenzy = true },
    desc = '成群出没、跑得很快；同伴阵亡时，其余雪狼狂暴 3 秒（攻速翻倍），范围伤害一口气清掉最好' }
E.frosttroll = { ch = 7, name = '冰霜巨魔', sprite = 'frosttroll', hp = 210, atk = 13, cd = 1.3, range = 8, speed = 13, r = 6, fx = { trollRegen = 0.03 },
    desc = '每秒回复 3% 生命；身上有灼烧时无法回复——带火的单位克制它' }
E.icemage = { ch = 7, name = '冰晶术士', sprite = 'darkmage', hp = 76, atk = 10, cd = 1.6, range = 62, speed = 14, r = 5, proj = 'frost', skill = 'frostbind',
    pal = { d = '#1f3a6a', p = '#3a8ad8', P = '#9fdcff', e = '#ffffff', b = '#c9d2e0' },
    desc = '技能「冰缚」：冻结你攻击最高的单位 2 秒（超凡免疫）' }
E.snowthrower = { ch = 7, name = '雪人投手', sprite = 'snowthrower', hp = 112, atk = 12, cd = 1.7, range = 66, speed = 12, r = 5, proj = 'snowball', splash = 14, fx = { slowHit = 0.3 },
    desc = '远程雪球带小范围溅射，命中减速 30%' }
E.glacier = { ch = 7, name = '冰甲兽', sprite = 'glacier', hp = 240, atk = 13, cd = 1.3, range = 9, speed = 12, r = 6, pal = { A = '#bff4ff', a = '#3a8ad8' }, fx = { iceArmor = 0.5 },
    desc = '冰甲：受到的伤害 -50%；被灼烧或生命低于一半时冰甲碎裂' }
E.frostwyrm = { ch = 7, name = '凛冬巨龙', sprite = 'frostwyrm', hp = 3400, atk = 30, cd = 1.6, range = 70, speed = 8, r = 10, proj = 'frost', splash = 16, big = true, skill = 'wyrmbreath',
    pal = { A = '#8fd0ff', o = '#e8f8ff' }, fx = { wphases = true },
    desc = '技能「冰龙吐息」：向前方扇形喷出寒气，造成 150% 伤害并冻结 1.2 秒。60% 生命时「凛冬降临」：冻结你的全体单位 1.5 秒并召唤雪狼；30% 生命时「霜龙之怒」：靠近它的单位每秒叠一层寒意（每层攻速 -10%，最多 5 层），身上有灼烧的单位会融掉寒意' }
-- 第九章：天空浮城（ch = 8）
E.windsprite = { ch = 8, name = '风灵', sprite = 'windsprite', hp = 50, atk = 9, cd = 0.9, range = 58, speed = 22, r = 4, proj = 'windblade', fx = { dodge = 0.3 },
    desc = '30% 闪避的远程小怪；持续伤害不会被闪避，用灼烧、中毒、流血对付' }
E.griffin = { ch = 8, name = '狮鹫骑士', sprite = 'griffin', hp = 125, atk = 12, cd = 1.1, range = 8, speed = 30, r = 6, fx = { dive = true, leapT = 1.6 },
    desc = '开战后飞越战线直扑你最后排的单位，之后一直盯着后排打；后排放个肉盾或者先手集火它' }
E.thundercloud = { ch = 8, name = '雷云', sprite = 'thundercloud', hp = 96, atk = 10, cd = 1.5, range = 60, speed = 14, r = 5, proj = 'zap', skill = 'chainstorm',
    desc = '技能「连锁雷暴」：闪电在你的单位之间弹射 4 次，每次 100% 伤害并麻痹 0.3 秒；站位别挤成一团' }
E.skypriest = { ch = 8, name = '天空神官', sprite = 'forgepriest', hp = 88, atk = 8, cd = 1.6, range = 62, speed = 14, r = 5, proj = 'windblade', skill = 'windward',
    pal = { b = '#c9d2e0', f = '#ffe680', F = '#ffffff', e = '#6ef0ff', h = '#ffd84a', H = '#fff6b0', s = '#e2b33c' },
    desc = '技能「风之庇护」：全体敌人获得 15% 最大生命的护盾，3 秒内闪避 +20%' }
E.aethergolem = { ch = 8, name = '以太魔像', sprite = 'aethergolem', hp = 250, atk = 14, cd = 1.4, range = 9, speed = 12, r = 6, fx = { antiRanged = 0.4 },
    desc = '以太护壁：受到远程单位的伤害 -40%；交给近战处理' }
E.stormtotem = { ch = 8, name = '风暴图腾', sprite = 'stormtotem', hp = 300, atk = 10, cd = 1.2, range = 200, speed = 0, r = 5, proj = 'zap', fx = { anchor = true },
    desc = '风暴之主召唤的图腾，不会移动；只要还有图腾，风暴之主受到的伤害 -50%' }
E.stormlord = { ch = 8, name = '风暴之主', sprite = 'stormlord', hp = 2800, atk = 27, cd = 1.5, range = 72, speed = 9, r = 10, proj = 'zap', splash = 14, big = true, skill = 'thunderclap',
    fx = { sphases = true },
    desc = '技能「雷霆万钧」：预警后在你 3 个单位脚下劈下落雷，造成 160% 伤害并麻痹，看到黄圈赶紧走位。65% 生命时召唤 3 根风暴图腾（图腾存活时它受到的伤害 -50%）；30% 生命时开启「风暴之眼」，每 6 秒把你的单位卷到身边并造成伤害' }
-- 第十章：终焉王座（ch = 9）
E.deathknight = { ch = 9, name = '堕落骑士', sprite = 'deathknight', hp = 220, atk = 15, cd = 1.3, range = 9, speed = 15, r = 6, fx = { leech = 0.25, dr = 0.15 },
    desc = '吸血 25%，受到的伤害 -15%；用枯萎、诅咒和爆发压住它' }
E.shade = { ch = 9, name = '暗影刺客', sprite = 'shade', hp = 82, atk = 15, cd = 1.0, range = 7, speed = 34, r = 4, fx = { stealthStart = 3 },
    desc = '开战隐身 3 秒（不会被选中，范围伤害能打到），摸到你生命比例最低的单位身后，出手双倍伤害；每次击杀后重新隐身 2 秒' }
E.chaosmage = { ch = 9, name = '混沌术士', sprite = 'darkmage', hp = 80, atk = 11, cd = 1.6, range = 62, speed = 14, r = 5, proj = 'dark', skill = 'doomhex',
    pal = { d = '#4c1b2f', p = '#a8102a', P = '#ff3434', e = '#ffe14a', b = '#22101a' },
    desc = '技能「厄运诅咒」：诅咒你攻击最高的 3 个单位 5 秒：受到的伤害 +25%、攻击 -20%（净化可以解除）' }
E.bonedragon = { ch = 9, name = '骨龙', sprite = 'bonedragon', hp = 150, atk = 14, cd = 1.7, range = 66, speed = 14, r = 6, proj = 'bonefire', splash = 16, fx = { burnOnHit = true },
    desc = '远程骨焰带溅射，命中附带灼烧' }
E.throneguard = { ch = 9, name = '王座守卫', sprite = 'obsidian', hp = 320, atk = 15, cd = 1.4, range = 9, speed = 11, r = 6, fx = { guardShare = 0.35 },
    pal = { d = '#5a3a12', P = '#ffd84a', e = '#ff3434', k = '#22101a' },
    desc = '护主：替身边的友军承受 35% 伤害；不先打掉它，后面的敌人很难死' }
E.doompillar = { ch = 9, name = '终焉之柱', sprite = 'pillar', hp = 360, atk = 12, cd = 2.0, range = 220, speed = 0, r = 5, proj = 'dark', fx = { anchor = true },
    pal = { d = '#22101a', P = '#a8102a', f = '#ff3434', F = '#ffe14a', m = '#4c1b2f' },
    desc = '「王座结界」召唤的结界柱，不会移动，会远程射击；全部打碎才能破开结界，拖太久会崩塌重创全军' }
-- 历代残影（终焉之王召唤，不进图鉴）
local SHADOW = { k = '#0e0a1a', c = '#5a4a86', C = '#3a2d52', m = '#3a2d52', r = '#8f4bc4', e = '#ff3434', O = '#e0b0ff', p = '#2b2546', P = '#5a4a86', g = '#8f7bc4',
    H = '#8f7bc4', h = '#5a4a86', f = '#c06bff', F = '#e0b0ff', d = '#1c1832', o = '#c06bff', z = '#3a2d52', Z = '#5a4a86', x = '#2b2546', u = '#2b2546', A = '#5a4a86', w = '#e0b0ff', y = '#c06bff' }
local ECHO_DESC = '终焉之王召唤的历代首领残影：只会普攻，没有原来的机制'
E.echo_boss = { ch = 99, name = '魔王残影', sprite = 'boss', hp = 620, atk = 22, cd = 1.3, range = 10, speed = 14, r = 9, big = true, pal = SHADOW, fx = { rage = 0, echo = true }, desc = ECHO_DESC }
E.echo_colossus = { ch = 99, name = '巨像残影', sprite = 'colossus', hp = 760, atk = 20, cd = 1.6, range = 12, speed = 10, r = 9, big = true, pal = SHADOW, fx = { rage = 0, echo = true }, desc = ECHO_DESC }
E.echo_void = { ch = 99, name = '虚空残影', sprite = 'voidlord', hp = 560, atk = 20, cd = 1.6, range = 64, speed = 10, r = 9, proj = 'dark', splash = 14, big = true, pal = SHADOW, fx = { rage = 0, echo = true }, desc = ECHO_DESC }
E.echo_rot = { ch = 99, name = '腐母残影', sprite = 'rotmother', hp = 700, atk = 20, cd = 1.5, range = 10, speed = 11, r = 9, splash = 14, big = true, pal = SHADOW, fx = { rage = 0, echo = true }, desc = ECHO_DESC }
E.echo_lev = { ch = 99, name = '利维坦残影', sprite = 'leviathan', hp = 560, atk = 20, cd = 1.7, range = 70, speed = 8, r = 9, proj = 'ink', splash = 14, big = true, pal = SHADOW, fx = { rage = 0, echo = true }, desc = ECHO_DESC }
local ECHOES = A('echo_boss', 'echo_colossus', 'echo_void', 'echo_rot', 'echo_lev')
E.doomking = { ch = 9, name = '终焉之王', sprite = 'doomking', hp = 3800, atk = 30, cd = 1.4, range = 12, speed = 10, r = 10, splash = 14, big = true, skill = 'doomslash',
    fx = { dphases = true, rage = 0 },
    desc = '技能「终焉斩」：向前方横扫，造成 200% 伤害并让命中的单位易伤 3 秒。75% 生命时召唤历代首领的残影；45% 生命时退回王座展开「王座结界」（无敌），召唤 4 根终焉之柱，14 秒内全部打碎就能让它眩晕并易伤，否则结界崩塌重创全军；20% 生命时「终焉审判」：攻击 +30%、攻速 +40%、吸血 20%' }

for _, k in ipairs({ 'frostwolf', 'frosttroll', 'icemage', 'snowthrower', 'glacier', 'frostwyrm',
    'windsprite', 'griffin', 'thundercloud', 'skypriest', 'aethergolem', 'stormtotem', 'stormlord',
    'deathknight', 'shade', 'chaosmage', 'bonedragon', 'throneguard', 'doompillar', 'doomking',
    'echo_boss', 'echo_colossus', 'echo_void', 'echo_rot', 'echo_lev' }) do ENEMY_KEYS:push(k) end
local AS, AC = ATK_STYLE_EN, ATK_EN_COL
AS.frostwolf = 'claw'; AS.frosttroll = 'maul'; AS.icemage = 'cast'; AS.snowthrower = 'cast'; AS.glacier = 'maul'; AS.frostwyrm = 'cast'
AS.windsprite = 'cast'; AS.griffin = 'claw'; AS.thundercloud = 'pulse'; AS.skypriest = 'cast'; AS.aethergolem = 'maul'; AS.stormtotem = 'pulse'; AS.stormlord = 'cast'
AS.deathknight = 'slash'; AS.shade = 'slash'; AS.chaosmage = 'cast'; AS.bonedragon = 'cast'; AS.throneguard = 'maul'; AS.doompillar = 'pulse'; AS.doomking = 'slash'
for _, k in ipairs({ 'echo_boss', 'echo_colossus', 'echo_rot' }) do AS[k] = 'maul' end
AS.echo_void = 'cast'; AS.echo_lev = 'cast'
AC.frostwolf = '#e8f8ff'; AC.frosttroll = '#6ec8ff'; AC.glacier = '#bff4ff'; AC.griffin = '#ffe680'; AC.aethergolem = '#6ef0ff'
AC.deathknight = '#ff3434'; AC.shade = '#c06bff'; AC.throneguard = '#ffd84a'; AC.doomking = '#ff3434'
PROJ_BURST.snowball = '#e8f8ff'; PROJ_BURST.windblade = '#bff4ff'; PROJ_BURST.bonefire = '#9be36b'

SKILLS.frostbind = { name = '冰缚', charge = 30, desc = '冻结攻击最高的敌人 2 秒' }
SKILLS.wyrmbreath = { name = '冰龙吐息', charge = 32, desc = '向前方扇形喷出寒气，造成 150% 伤害并冻结 1.2 秒' }
SKILLS.chainstorm = { name = '连锁雷暴', charge = 30, desc = '闪电在敌人之间弹射 4 次，每次 100% 伤害并麻痹 0.3 秒' }
SKILLS.windward = { name = '风之庇护', charge = 30, desc = '全体友军获得 15% 最大生命的护盾，3 秒内闪避 +20%' }
SKILLS.thunderclap = { name = '雷霆万钧', charge = 30, desc = '预警后在 3 个敌人脚下劈下落雷，造成 160% 伤害并麻痹 0.6 秒' }
SKILLS.doomhex = { name = '厄运诅咒', charge = 30, desc = '诅咒攻击最高的 3 个敌人 5 秒：受到的伤害 +25%、攻击 -20%' }
SKILLS.doomslash = { name = '终焉斩', charge = 30, desc = '向前方横扫，造成 200% 伤害并让命中的单位易伤 3 秒' }

-- ---------------------------------------------------------------------------
-- 波次与难度
-- ---------------------------------------------------------------------------
local function W(map) return function(str)
    local out = A()
    for ch in str:gmatch('%a') do out:push(map[ch]) end
    return out
end end
local W8 = W({ W = 'frostwolf', T = 'frosttroll', M = 'icemage', Y = 'snowthrower', G = 'glacier' })
local W9 = W({ S = 'windsprite', G = 'griffin', C = 'thundercloud', P = 'skypriest', A = 'aethergolem' })
local W10 = W({ K = 'deathknight', H = 'shade', X = 'chaosmage', B = 'bonedragon', G = 'throneguard' })
WAVES8 = A(W8 'WWW', W8 'WWWY', W8 'TWWY', W8 'TWWYM', W8 'GTWWYM', W8 'GTWWWYM', W8 'GTWWWYYM', W8 'GGTWWYYM', W8 'GTTWWWYYM', W8 'GGTTWWYYM',
    W8 'GGTWWWYYMM', W8 'GGTTWWWYYM', W8 'GGTTWWWYYMM', W8 'GGGTTWWYYMM', W8 'GGGTTWWWYYMM')
WAVES9 = A(W9 'SSS', W9 'SSSG', W9 'SSGC', W9 'SSSGC', W9 'SSSGCP', W9 'ASSGCP', W9 'AGSSSCP', W9 'AGGSSCCP', W9 'AASGSSCCP', W9 'AAGGSSCCP',
    W9 'AAGGSSCCPP', W9 'AAAGGSSSCCP', W9 'AAAGGSSCCPP', W9 'AAAGGGSSCCPP', W9 'AAAAGGSSSCCPP')
WAVES10 = A(W10 'HH', W10 'KHH', W10 'KHB', W10 'KHHBX', W10 'GKHBX', W10 'GKKHBX', W10 'GKHHBBX', W10 'GGKKHBBX', W10 'GGKHHBBX', W10 'GGKKHHBBX',
    W10 'GGKKHHBBXX', W10 'GGGKKHBBXX', W10 'GGKKKHHBBXX', W10 'GGGKKHHBBXX', W10 'GGGKKKHHBBXX')
local function bossWave8(n)
    if n >= 14 then return A('frostwyrm', 'glacier', 'glacier', 'frosttroll', 'snowthrower', 'icemage') end
    if n >= 12 then return A('frostwyrm', 'glacier', 'frosttroll', 'snowthrower', 'icemage') end
    return A('frostwyrm', 'glacier', 'frostwolf', 'snowthrower')
end
local function bossWave9(n)
    if n >= 14 then return A('stormlord', 'aethergolem', 'aethergolem', 'griffin', 'thundercloud', 'skypriest') end
    if n >= 12 then return A('stormlord', 'aethergolem', 'griffin', 'thundercloud', 'skypriest') end
    return A('stormlord', 'aethergolem', 'windsprite', 'thundercloud')
end
local function bossWave10(n)
    if n >= 14 then return A('doomking', 'throneguard', 'throneguard', 'deathknight', 'bonedragon', 'chaosmage') end
    if n >= 12 then return A('doomking', 'throneguard', 'deathknight', 'bonedragon', 'chaosmage') end
    return A('doomking', 'throneguard', 'shade', 'bonedragon')
end
local function diffs(base, hard, night, hell, gold)
    return A(
        { name = '普通', color = '#8fe07a', mult = base, extra = 0, elite = 0, lives = 3, adds = 2, gold = gold[1], waves = 10, desc = '共 10 波。全新的敌人和战场规则，整体比上一章同难度更强；开局多 ' .. gold[1] .. ' 金币' },
        { name = '困难', color = '#ffd84a', mult = hard, extra = 1, elite = 0.1, lives = 3, adds = 2, gold = gold[2], waves = 12, desc = '共 12 波。敌人最高 +' .. round((hard - 1) * 100) .. '%，第 3 波起每波多 1 个敌人，开始出现精英；开局多 ' .. gold[2] .. ' 金币' },
        { name = '噩梦', color = '#ff9b8c', mult = night, extra = 1, elite = 0.25, lives = 3, adds = 3, gold = gold[3], waves = 14, desc = '共 14 波。敌人最高 +' .. round((night - 1) * 100) .. '%，精英更多；首领的召唤更多；开局多 ' .. gold[3] .. ' 金币' },
        { name = '炼狱', color = '#e09cff', mult = hell, extra = 2, elite = 0.35, lives = 2, adds = 4, gold = gold[4], waves = 16, desc = '共 16 波。敌人最高 +' .. round((hell - 1) * 100) .. '%，每波最多多 2 个敌人；首领的召唤最多；只有 2 点生命，开局多 ' .. gold[4] .. ' 金币' })
end
-- 难度系数接在第七章「沉没海渊」（2.55 / 3.2 / 3.85 / 4.5）之后；第九、十章的敌人本身更难缠，系数只略高，
-- 按自动对局的胜率曲线校准（见 数值验证.txt）；开局金币逐章增加
DIFFS8 = diffs(2.75, 3.5, 4.1, 4.25, { 7, 9, 12, 24 })
DIFFS9 = diffs(2.65, 3.4, 4.05, 4.2, { 8, 10, 13, 26 })
DIFFS10 = diffs(2.75, 3.5, 4.15, 4.3, { 9, 11, 14, 28 })
SOUL_CH:push(3.6, 4.0, 4.4)

CHAPTERS:push({ name = '第八章', title = '霜寒冰原', key = 'reel-legion-c8', color = '#bfe8ff', bg = 'tundra', bossName = '凛冬巨龙', music = 'bgm_c8', bossMusic = 'bgm_boss8', num = '8',
    desc = '成群的雪狼、回血的冰霜巨魔、会冻人的冰晶术士和披冰甲的冰甲兽，暴风雪一阵阵拖慢攻势——带火的单位格外吃香；尽头是冻结军团的凛冬巨龙',
    rage = A('frostwolf', 'frostwolf'), waves = WAVES8, diffs = DIFFS8, boss = bossWave8,
    bossWarn = function(Df) return '凛冬巨龙会带着护卫出场。它的吐息会冻结前方的单位，别把整排人堆在它正面；60% 生命时冻结你的全体单位并召唤雪狼；30% 生命时靠近它的单位会不断叠寒意变慢，灼烧可以融掉寒意' .. (T(Df.adds) and ('；半血时再召唤 ' .. S(Df.adds) .. ' 只雪狼') or '') .. '。' end })
CHAPTERS:push({ name = '第九章', title = '天空浮城', key = 'reel-legion-c9', color = '#ffe680', bg = 'sky', bossName = '风暴之主', music = 'bgm_c9', bossMusic = 'bgm_boss9', num = '9',
    desc = '高闪避的风灵、直扑后排的狮鹫骑士、连锁闪电的雷云和不怕远程的以太魔像，狂风把战线吹得东倒西歪；尽头是召唤图腾、卷起风暴之眼的风暴之主',
    rage = A('windsprite', 'griffin'), waves = WAVES9, diffs = DIFFS9, boss = bossWave9,
    bossWarn = function(Df) return '风暴之主会带着护卫出场。落雷前地上会出现黄圈，离开黄圈；65% 生命时召唤 3 根风暴图腾，图腾存活时它受到的伤害 -50%，先拆图腾；30% 生命后每 6 秒卷起风暴之眼，把你的单位拉到身边' .. (T(Df.adds) and ('；半血时召唤 ' .. S(Df.adds) .. ' 个援军') or '') .. '。' end })
CHAPTERS:push({ name = '第十章', title = '终焉王座', key = 'reel-legion-c10', color = '#ff6a8a', bg = 'throne', bossName = '终焉之王', music = 'bgm_c10', bossMusic = 'bgm_boss10', num = '10',
    desc = '吸血的堕落骑士、隐身背刺的暗影刺客、诅咒军团的混沌术士、喷骨焰的骨龙和替人挡刀的王座守卫，每一波的战场规则都在变；王座上坐着召唤历代首领残影的终焉之王',
    rage = A('shade', 'deathknight'), waves = WAVES10, diffs = DIFFS10, boss = bossWave10,
    bossWarn = function(Df) return '终焉之王会带着护卫出场。75% 生命时召唤 ' .. S(min(3, max(2, Df.adds or 2))) .. ' 个历代首领的残影；45% 生命时退回王座展开无敌结界，14 秒内打碎 4 根终焉之柱，否则结界崩塌重创全军；20% 生命时进入终焉审判，攻击和攻速大增，留好爆发。' end })

-- ---------------------------------------------------------------------------
-- 战场规则
-- ---------------------------------------------------------------------------
CELL_KINDS.ice = { name = '冰面格', short = '冰', color = '#bfe8ff', desc = '单位在格子里移动速度 +30%，但被冻结 / 眩晕的时间 +50%' }
CELL_ORDER:push('ice')

local CH8, CH9, CH10 = 7, 8, 9
CH_RULES[CH8] = { cells = { ice = 2, high = 1 }, global = 'blizzard', ban = 'flytrap', short = '暴风雪每 18 秒一次',
    text = A('<b>暴风雪</b>每 18 秒刮起一场 4 秒的暴风雪：所有单位（敌我都算）攻速 -30%、移动速度 -20%；<b>身上有灼烧的单位不受影响</b>。') }
CH_RULES[CH9] = { cells = { high = 2, seal = 1 }, global = 'gale', ban = 'hawk', short = '狂风每 16 秒一阵',
    text = A('<b>狂风</b>每 16 秒刮一阵 4 秒的侧风（方向随机）：所有非首领单位被往风向吹；顺风那一方的远程射程 +15，逆风那一方 -15。') }
CH_RULES[CH10] = { cells = { seal = 1, altar = 2 }, global = 'chaos', ban = 'treant', short = '混沌：每波随机规则',
    text = A('<b>混沌</b>每一波随机抽一条前几章的战场规则：毒雾、潮汐、地裂、暴风雪或狂风（战场下方的规则条会提前写出这一波是哪条）。') }

local CHAOS = A('fog', 'tide', 'fissure', 'blizzard', 'gale')
local CHAOS_NAME = { fog = '毒雾（治疗 -25%、灼烧 +30%）', tide = '潮汐（每 20 秒涨落）', fissure = '地裂（每 12 秒）', blizzard = '暴风雪（每 18 秒）', gale = '狂风（每 16 秒）' }
local function activeGlobal()
    local R = chRules()
    if R.global == 'chaos' then return G.chaosRule end
    return R.global
end

-- 混沌：每波换一条规则（在阵容生成时就定下，准备阶段能看到）
local _currentLineup = currentLineup
function currentLineup()
    local fresh = not G.lineup or G.lineup.wave ~= G.wave
    local l = _currentLineup()
    if fresh and chRules().global == 'chaos' then G.chaosRule = pick(CHAOS) end
    return l
end
local _ruleBarText = ruleBarText
function ruleBarText()
    local t = _ruleBarText()
    if t and not G.tutorial and chRules().global == 'chaos' and G.chaosRule then
        t = t .. '　本波：' .. CHAOS_NAME[G.chaosRule]
    end
    return t
end

local function iceCells()
    local out = nil
    if G.cells then for i, k in pairs(G.cells) do if k == 'ice' then out = out or {}; out[#out + 1] = fPos(i) end end end
    return out
end

local function blizzardStart(B) B.bliz = { t = 12, on = false } end
local function galeStart(B) B.gale = { t = 10, on = false, dir = 1 } end
local function galeRanges(B, on)
    for e in of(B.ents) do
        if e.proj and not e.dead then
            if on then
                local down = (e.side == 'p') == (B.gale.dir > 0) -- 风往右吹时我方（在左边）是顺风
                e.galeD = down and 15 or -15
                e.range = max(10, e.range + e.galeD)
            elseif e.galeD then
                e.range = e.range - e.galeD; e.galeD = nil
            end
        end
    end
end

local function chStart(B)
    local g = activeGlobal()
    if g == 'blizzard' then blizzardStart(B) end
    if g == 'gale' then galeStart(B) end
    if chRules().global == 'chaos' then
        if g == 'fog' then B.healMul, B.burnMul = 0.75, 1.3 end
        if g == 'tide' then B.tide = { t = 20, high = true }; applyTide(B) end
        if g == 'fissure' then B.hazT = 5 end
    end
end
local function chStep(B, dt, alive)
    if B.over then return end
    local g = activeGlobal()
    -- 冰面格：移速 +30%，控制时间 +50%
    local ice = iceCells()
    if ice then
        for e in of(alive) do
            for _, p in ipairs(ice) do
                if abs(e.x - p.x) <= 13 and abs(e.y - p.y) <= 16 then
                    if e.unitRule then e.unitRule.spd = e.unitRule.spd * 1.3 else e.unitRule = { spd = 1.3 } end
                    if e.stun > 0 and not e.ccImmune then e.stun = e.stun + dt / 3 end
                    break
                end
            end
        end
    end
    -- 暴风雪
    if B.bliz then
        local Z = B.bliz
        Z.t = Z.t - dt
        if Z.t <= 0 then
            Z.on = not Z.on; Z.t = Z.on and 4 or 18
            if Z.on then UI.banner('暴风雪：攻速 -30%（灼烧中的单位不受影响）', 'gold'); B.tint = { t = 0.5, max = 0.5, rgb = '190,230,255' }; if FX.blizzard then FX.blizzard(4) end end
        end
        if Z.on then
            for e in of(alive) do
                if not e.burn and e.stun <= 0 then
                    e.cdLeft = e.cdLeft + dt * 0.3
                    if e.unitRule then e.unitRule.spd = e.unitRule.spd * 0.8 else e.unitRule = { spd = 0.8 } end
                end
            end
        end
    end
    -- 狂风
    if B.gale then
        local Gl = B.gale
        Gl.t = Gl.t - dt
        if Gl.t <= 0 then
            Gl.on = not Gl.on; Gl.t = Gl.on and 4 or 16
            if Gl.on then
                Gl.dir = (js.random() < 0.5) and -1 or 1
                galeRanges(B, true)
                UI.banner((Gl.dir > 0) and '狂风向右吹：我方顺风，远程射程 +15' or '狂风向左吹：敌方顺风，我方远程射程 -15', 'gold')
                if FX.gust then FX.gust(Gl.dir, 4) end
            else galeRanges(B, false) end
        end
        if Gl.on then
            for e in of(alive) do
                if not e.big and not e.anchor and e.speed > 0 then e.x = clamp(e.x + Gl.dir * 9 * dt, 6, AW - 6) end
            end
        end
    end
    if chRules().global == 'chaos' then
        if g == 'tide' and B.tide then
            B.tide.t = B.tide.t - dt
            if B.tide.t <= 0 then B.tide.t = 20; B.tide.high = not B.tide.high; applyTide(B); UI.banner(B.tide.high and '涨潮：远程射程 -25%' or '退潮：近战移速 -30%', 'gold') end
        end
        if g == 'tide' and B.tide and not B.tide.high then
            for e in of(alive) do if isMeleeEnt(e) and e.speed > 0 then if e.unitRule then e.unitRule.spd = e.unitRule.spd * 0.7 else e.unitRule = { spd = 0.7 } end end end
        end
        if g == 'fissure' then
            B.hazT = (B.hazT or 5) - dt
            if B.hazT <= 0 then
                B.hazT = 12
                for k = 0, 1 do
                    local y = 24 + js.random() * (FIELD_H - 44)
                    local y2 = clamp(y + rand(-30, 30), 18, FIELD_H - 12)
                    B.fields:push({ kind = 'fissure', x = 8, y = y, x2 = AW - 8, y2 = y2, w = 6, warn = 1.0, t = 1.5, max = 1.5, src = envSource(B), mul = 1.6, fired = false, both = true })
                end
                Sound.play('skill')
            end
        end
    end
end
for _, c in ipairs({ CH8, CH9, CH10 }) do CH_RULES[c].onStart = chStart; CH_RULES[c].onStep = chStep end

-- 冰面格的标记
local _drawCells = drawCells
function drawCells(ctx, battle)
    _drawCells(ctx, battle)
    if not G.cells then return end
    for i, k in pairs(G.cells) do
        if k == 'ice' then
            local r = cellRect({ t = 'f', i = i })
            ctx.fillStyle = '#e8f8ff'
            ctx:fillRect(r.x + 3, r.y + r.h - 5, 5, 1); ctx:fillRect(r.x + 5, r.y + r.h - 7, 1, 5)
            ctx:fillRect(r.x + r.w - 8, r.y + 4, 3, 1); ctx:fillRect(r.x + r.w - 7, r.y + 3, 1, 3)
            ctx.fillStyle = '#9fdcff'; ctx:fillRect(r.x + 9, r.y + r.h - 3, r.w - 14, 1)
        end
    end
end

-- ---------------------------------------------------------------------------
-- 敌人机制
-- ---------------------------------------------------------------------------
local function quietKill(o) o.hp = 0; o.dead = true; o.deadT = 0 end
local function freezeP(o, d) -- 冻结我方单位（超凡免疫，大体型减半）
    if o.dead or o.ccImmune or (o.ccShield or 0) > 0 then return end
    local dd = o.big and d * 0.5 or d
    o.stun = max(o.stun, dd); o.frozenT = max(o.frozenT or 0, dd)
end

addHook('ent', function(ent, e)
    if ent.iceArmor then ent.dr = (ent.dr or 0) + ent.iceArmor; ent.iceOn = true end
    if ent.leapT then ent.leapLeft = ent.leapT end
    if ent.stealthStart then ent.stealthT = ent.stealthStart; ent.untargetable = true; ent.shifted = true end
    if ent.antiRanged then ent.antiR = ent.antiRanged end
    local onHurt = nil
    if ent.wphases then ent.wT = 0; onHurt = { 0.6, 0.3 } end
    if ent.sphases then onHurt = { 0.65, 0.3 } end
    if ent.dphases then onHurt = { 0.75, 0.45, 0.2 } end
    if onHurt then
        ent.onHurt = function(t) -- 阶段不会被一口气跳过
            for i, f in ipairs(onHurt) do
                if not t['ph' .. i] and t.hp < t.maxHp * f then t.hp = floor(t.maxHp * f); return end
            end
        end
    end
end)

-- 远程伤害减免（以太魔像）、图腾护佑（风暴之主）
local _hit = hit
function hit(src, t, base, o)
    if T(t.antiR) and src and src.proj and not (o and (o.melee or T(o.dot))) then base = base * (1 - t.antiR) end
    if t.totemGuard and t.tents2 and t.tents2:some(function(x) return not x.dead end) then base = base * 0.5 end
    return _hit(src, t, base, o)
end

-- 狼群狂暴、暗影刺客重新隐身
addHook('death', function(t, src, B)
    if t.packFrenzy then
        for o in of(B.ents) do if not o.dead and o.packFrenzy and o ~= t then o.haste = max(o.haste or 0, 3); FX.particle(o.x, o.y - 4, '#ff6a4a', 4, 30, -10, 0.4) end end
    end
    if src and src.stealthStart and not src.dead and src.side ~= t.side then
        src.stealthT = 2; src.untargetable = true; src.shifted = true
        for o in of(B.ents) do if o.target == src then o.target = nil end end
    end
end)

local function lowestFoe(B, e)
    local fs = foesOf(B, e):filter(function(o) return not o.minion end)
    if #fs == 0 then fs = foesOf(B, e) end
    return fs:slice():sort(function(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end)[0]
end

-- 首领阶段 ----------------------------------------------------------------
local function wyrmPhase(B, e, dt)
    local f = e.hp / e.maxHp
    if not e.ph1 and f <= 0.6 then -- 凛冬降临
        e.ph1 = true
        for o in of(foesOf(B, e)) do freezeP(o, 1.5) end
        local n = 2 + max(0, (e.adds or 2) - 2)
        for i = 0, n - 1 do spawnEnemy(B, 'frostwolf', e.x - 18 + rand(-6, 6), e.y + (i - (n - 1) / 2) * 16, 0.6) end
        FX.skill(e, '凛冬降临'); B.tint = { t = 0.7, max = 0.7, rgb = '200,240,255' }; G.shake = max(G.shake, 0.4)
    end
    if not e.ph2 and f <= 0.3 then -- 霜龙之怒
        e.ph2 = true; e.frostAura = true; e.atk = round(e.atk * 1.2)
        FX.skill(e, '霜龙之怒'); G.shake = max(G.shake, 0.3)
    end
    if e.frostAura then
        e.wT = e.wT - dt
        if e.wT <= 0 then
            e.wT = 1
            for o in of(foesOf(B, e)) do
                if hypot(o.x - e.x, o.y - e.y) <= 60 then
                    if o.burn then o.frostStack = 0 else o.frostStack = min(5, (o.frostStack or 0) + 1) end
                end
            end
        end
    end
end
local function stormPhase(B, e, dt)
    local f = e.hp / e.maxHp
    if not e.ph1 and f <= 0.65 then -- 风暴图腾
        e.ph1 = true; e.totemGuard = true
        e.tents2 = A(A(196, 26), A(170, 72), A(196, 118)):map(function(p) return spawnEnemy(B, 'stormtotem', p[0] + rand(-4, 4), p[1], 0.8) end)
        FX.skill(e, '风暴图腾'); G.shake = max(G.shake, 0.3)
    end
    if not e.ph2 and f <= 0.3 then -- 风暴之眼
        e.ph2 = true; e.eyeT = 1.5
        FX.skill(e, '风暴之眼')
    end
    if e.eyeT then
        e.eyeT = e.eyeT - dt
        if e.eyeT <= 0 then
            e.eyeT = 6
            for o in of(foesOf(B, e)) do
                if not o.big and not o.anchor then
                    local dx, dy = e.x - o.x, e.y - o.y
                    local d = max(1, hypot(dx, dy))
                    local k = max(0, min(d - 22, 40))
                    o.x = clamp(o.x + dx / d * k, 6, AW - 6); o.y = clamp(o.y + dy / d * k * 0.6, 14, FIELD_H - 10)
                end
                hit(e, o, e.atk * 0.6, { noLeech = true })
            end
            if FX.stormEye then FX.stormEye(e.x, e.y) end
            B.tint = { t = 0.35, max = 0.35, rgb = '200,220,255' }; G.shake = max(G.shake, 0.3); Sound.play('zap')
        end
    end
end
local function doomPhase(B, e, dt)
    local f = e.hp / e.maxHp
    if not e.ph1 and f <= 0.75 then -- 历代残影
        e.ph1 = true
        local n = min(3, max(2, e.adds or 2))
        local pool = ECHOES:slice()
        for i = 0, n - 1 do
            local k = floor(js.random() * #pool)
            local t = pool[k]; pool:splice(k, 1)
            local s = spawnEnemy(B, t, e.x - 26 + rand(-4, 4), clamp(e.y + (i - (n - 1) / 2) * 34, 26, FIELD_H - 14), 0.8)
            s.ghost = true
            FX.ring(s.x, s.y, 14, '#c06bff')
        end
        FX.skill(e, '历代残影'); G.shake = max(G.shake, 0.35)
    end
    if not e.ph2 and f <= 0.45 then -- 王座结界
        e.ph2 = true; e.immune = true; e.cast = 14; e.stun = 0; e.energy = 0; e.barrier = true
        FX.particle(e.x, e.y, '#ff3434', 20, 60, 30, 0.6)
        e.x = 222; e.y = 72
        e.pillars = A(A(186, 28), A(186, 116), A(160, 72), A(246, 40)):map(function(p) return spawnEnemy(B, 'doompillar', p[0], p[1], 0.8) end)
        for o in of(B.ents) do if o.target == e then o.target = nil end end
        FX.skill(e, '王座结界'); G.shake = max(G.shake, 0.35)
    end
    if e.barrier then
        e.cast = e.cast - dt
        local broken = e.pillars:every(function(p) return p.dead end)
        if broken then -- 结界破碎：眩晕 + 易伤
            e.barrier = false; e.cast = 0; e.immune = false; e.stun = max(e.stun, 3)
            applyCurse(e, 5, 0.3, 0)
            FX.skill(e, '结界破碎'); G.shake = max(G.shake, 0.4)
        elseif e.cast <= 0 then -- 结界崩塌：重创全军
            e.barrier = false; e.cast = 0; e.immune = false
            for p in of(e.pillars) do if not p.dead then quietKill(p); FX.particle(p.x, p.y, '#ff3434', 12, 50, 30, 0.5) end end
            for o in of(foesOf(B, e)) do hit(e, o, o.maxHp * 0.3, { noLeech = true, noCrit = true, dot = true }) end
            FX.skill(e, '结界崩塌'); B.tint = { t = 0.8, max = 0.8, rgb = '200,0,40' }; G.shake = max(G.shake, 0.5); Sound.play('die')
        end
    end
    if not e.ph3 and f <= 0.2 and not e.barrier then -- 终焉审判
        e.ph3 = true; e.atk = round(e.atk * 1.3); e.cd = e.cd / 1.4; e.leech = (e.leech or 0) + 0.2
        FX.skill(e, '终焉审判'); B.tint = { t = 0.6, max = 0.6, rgb = '255,60,60' }; G.shake = max(G.shake, 0.4)
        UI.banner('终焉审判：终焉之王狂暴了', 'gold')
    end
end

addHook('step', function(B, dt, alive)
    for e in of(alive) do
        -- 冰霜巨魔：没有灼烧时回血
        if T(e.trollRegen) and not e.burn and e.hp < e.maxHp then e.hp = min(e.maxHp, e.hp + e.maxHp * e.trollRegen * dt) end
        -- 冰甲兽：灼烧或半血时冰甲碎裂
        if e.iceOn and (e.burn or e.hp < e.maxHp * 0.5) then
            e.iceOn = false; e.dr = max(0, (e.dr or 0) - (e.iceArmor or 0)); e.pal = { A = '#6a8ab0', a = '#2a4a6a' }; e.pkey = e.type .. ':melt'
            FX.particle(e.x, e.y - 4, '#bff4ff', 16, 60, 40, 0.6); FX.ring(e.x, e.y, 10, '#e8f8ff'); FX.skill(e, '冰甲碎裂')
        end
        -- 狮鹫骑士：开战后飞越战线
        if e.leapLeft and not B.over and e.stun <= 0 then
            e.leapLeft = e.leapLeft - dt
            if e.leapLeft <= 0 then
                e.leapLeft = nil
                local prey = backmost(B, e)
                if prey then
                    local x0, y0 = e.x, e.y
                    e.x = clamp(prey.x + 12, 6, AW - 6); e.y = prey.y; e.target = prey; e.cdLeft = min(e.cdLeft, 0.3)
                    if FX.leap then FX.leap(x0, y0, e.x, e.y, '#ffe680') end
                    FX.skill(e, '俯冲')
                end
            end
        end
        -- 暗影刺客：隐身摸后排
        if e.stealthT then
            e.stealthT = e.stealthT - dt
            if not B.over then local prey = lowestFoe(B, e); if prey then e.target = prey end end
            if e.stealthT <= 0 then
                e.stealthT = nil; e.untargetable = false; e.shifted = false; e.backstab = true
                FX.particle(e.x, e.y, '#c06bff', 12, 40, 20, 0.5)
            end
        end
        -- 寒意：每层攻速 -10%
        if T(e.frostStack) and e.stun <= 0 then
            if e.burn then e.frostStack = 0 else e.cdLeft = e.cdLeft + dt * 0.1 * e.frostStack end
        end
        if e.wphases then wyrmPhase(B, e, dt) end
        if e.sphases then stormPhase(B, e, dt) end
        if e.dphases then doomPhase(B, e, dt) end
    end
end)

-- 敌方技能 ----------------------------------------------------------------
local _castSkill = castSkill
function castSkill(B, e, t)
    local sk = e.skill
    if sk == 'frostbind' then
        FX.skill(e, SKILLS[sk].name)
        local tgt = foesOf(B, e):filter(function(o) return not o.untargetable end):sort(function(a, b) return b.atk - a.atk end)[0]
        if tgt then freezeP(tgt, 2); FX.trail(e.x, e.y - 4, tgt.x, tgt.y - 4, '#bff4ff') end
        return
    elseif sk == 'wyrmbreath' then
        FX.skill(e, SKILLS[sk].name)
        for o in of(foesOf(B, e)) do
            local dx, dy = o.x - e.x, o.y - e.y
            local d = hypot(dx, dy)
            if d <= 96 + o.r and (d < 8 or abs(atan(dy, dx * e.face)) <= 0.55) then hit(e, o, e.atk * 1.5, { noLeech = true }); freezeP(o, 1.2) end
        end
        if FX.breath then FX.breath(e, e.face, 96, 0.55, '#bff4ff', '#ffffff') end
        return
    elseif sk == 'chainstorm' then
        FX.skill(e, SKILLS[sk].name)
        local cur, seen, pts = t, js.Set(), A(A(e.x, e.y - 6))
        for i = 1, 4 do
            if not cur or cur.dead then break end
            seen:add(cur); pts:push(A(cur.x, cur.y - 4))
            hit(e, cur, e.atk * 1.0, { noLeech = true })
            if not cur.dead and not cur.ccImmune then cur.stun = max(cur.stun, 0.3) end
            local nx = nil
            local bd = 60
            for o in of(foesOf(B, e)) do
                if not seen:has(o) then local d = hypot(o.x - cur.x, o.y - cur.y); if d < bd then bd = d; nx = o end end
            end
            cur = nx
        end
        if FX.chainPts then FX.chainPts(pts, '#ffe14a', '#ffffff') end
        Sound.play('zap')
        return
    elseif sk == 'windward' then
        FX.skill(e, SKILLS[sk].name)
        for o in of(alliesOf(B, e)) do o.shield = min(o.maxHp, (o.shield or 0) + o.maxHp * 0.15); o.dodgeT = 3 end
        return
    elseif sk == 'thunderclap' then
        FX.skill(e, SKILLS[sk].name)
        local foes = foesOf(B, e)
        for i = 0, 2 do
            local o = foes[floor(js.random() * #foes)]
            if o then B.fields:push({ kind = 'strike', x = o.x, y = o.y, r = 16, warn = 1.0, t = 1.4, max = 1.4, src = e, mul = 1.6, fired = false }) end
        end
        return
    elseif sk == 'doomhex' then
        FX.skill(e, SKILLS[sk].name)
        local list = foesOf(B, e):sort(function(a, b) return b.atk - a.atk end):slice(0, 3)
        for o in of(list) do applyCurse(o, 5, 0.25, 0.2); FX.trail(e.x, e.y - 4, o.x, o.y - 4, '#ff3434') end
        return
    elseif sk == 'doomslash' then
        FX.skill(e, SKILLS[sk].name)
        strikeAt(e)
        for o in of(foesOf(B, e)) do
            local dx, dy = o.x - e.x, o.y - e.y
            if hypot(dx, dy) <= 44 and dx * e.face >= -6 then hit(e, o, e.atk * 2, { noLeech = true, melee = true }); applyCurse(o, 3, 0.2, 0) end
        end
        G.shake = max(G.shake, 0.3)
        return
    end
    return _castSkill(B, e, t)
end

local _stepHazard = stepHazard
function stepHazard(B, f, dt)
    if f.kind == 'strike' then
        f.t = f.t - dt
        if not f.fired and f.t <= f.max - f.warn then
            f.fired = true
            for o in of(foesOf(B, f.src)) do
                if hypot(o.x - f.x, (o.y - f.y) * 1.3) <= f.r + o.r then
                    hit(f.src, o, f.src.atk * f.mul, { noLeech = true })
                    if not o.dead and not o.ccImmune then o.stun = max(o.stun, 0.6) end
                end
            end
            FX.bolt(f.x + rand(-4, 4), 0, f.x, f.y - 2); FX.bolt(f.x, 0, f.x + rand(-6, 6), f.y)
            FX.ring(f.x, f.y, f.r, '#ffe14a'); FX.particle(f.x, f.y, '#ffe14a', 14, 60, 30, 0.5)
            G.shake = max(G.shake, 0.25); Sound.play('zap')
        end
        if f.t <= 0 then f.done = true end
        return
    end
    return _stepHazard(B, f, dt)
end
FIELD_DRAW.strike = function(f)
    if f.fired then return end
    local k = 1 - (f.t - (f.max - f.warn)) / f.warn -- 0 → 1
    local blink = floor(G.time * 12) % 2 == 0
    local n = 18
    for i = 0, n - 1 do
        local a = i / n * 6.283
        actx.fillStyle = blink and '#ffe14a' or '#fff6b0'
        actx:fillRect(round(f.x + cos(a) * f.r), round(f.y + sin(a) * f.r / 1.3), 1, 1)
    end
    local rr = f.r * k
    actx.globalAlpha = 0.25; actx.fillStyle = '#ffe14a'
    for dy = -floor(rr / 1.3), floor(rr / 1.3) do local w = round(rr * sqrt(max(0, 1 - (dy * 1.3 / max(1, rr)) ^ 2))); actx:fillRect(round(f.x - w), round(f.y + dy), w * 2, 1) end
    actx.globalAlpha = 1
end

-- 新投射物
PROJ_DRAW.snowball = function(p, c, s)
    local x, y = round(p.x), round(p.y)
    actx.fillStyle = '#9fc8e8'; actx:fillRect(x - 2, y - 1, 5, 3); actx:fillRect(x - 1, y - 2, 3, 5)
    actx.fillStyle = '#ffffff'; actx:fillRect(x - 1, y - 1, 3, 2); actx:fillRect(x, y - 2, 1, 1)
    if js.random() < 0.3 then FX.parts:push({ x = p.x, y = p.y, vx = rand(-4, 4), vy = 4, g = 0, life = 0.3, max = 0.3, color = '#ffffff', size = 1 }) end
end
PROJ_DRAW.windblade = function(p, c, s) -- 月牙形风刃
    local x, y = round(p.x), round(p.y)
    actx.fillStyle = '#e8f8ff'
    actx:fillRect(x, y - 2, 1, 1); actx:fillRect(x + 1, y - 1, 1, 3); actx:fillRect(x, y + 2, 1, 1)
    actx.fillStyle = '#9fdcff'; actx:fillRect(x - 1, y - 1, 1, 1); actx:fillRect(x - 1, y + 1, 1, 1)
    for i = 2, 4 do if js.random() < 0.6 then actx.fillStyle = '#bff4ff'; actx:fillRect(round(p.x - c * i * 2), round(p.y - s * i * 2 + rand(-1, 1)), 1, 1) end end
end
PROJ_DRAW.bonefire = function(p, c, s)
    local x, y = round(p.x), round(p.y)
    actx.fillStyle = '#2f7a34'; actx:fillRect(x - 2, y - 1, 4, 3)
    actx.fillStyle = '#9be36b'; actx:fillRect(x - 1, y - 1, 3, 2)
    actx.fillStyle = '#e9e2cf'; actx:fillRect(x, y, 1, 1)
    if js.random() < 0.6 then FX.parts:push({ x = p.x - c * 3, y = p.y - s * 3, vx = rand(-4, 4), vy = -8, g = 0, life = 0.35, max = 0.35, color = (js.random() < 0.5) and '#9be36b' or '#c4f05a', size = 1 }) end
end

-- 寒意 / 冰甲的视觉
local _drawHp = drawHp
function drawHp(e)
    _drawHp(e)
    if e.dead then return end
    if T(e.frostStack) then pixText(actx, '*' .. S(e.frostStack), e.x - 8, e.y - (e.big and 30 or 22), '#bff4ff') end
    if e.iceOn and floor(G.time * 3 + e.x) % 5 == 0 then
        actx.fillStyle = '#ffffff'; actx:fillRect(round(e.x + rand(-5, 5)), round(e.y - rand(2, 10)), 1, 1)
    end
end

-- ---------------------------------------------------------------------------
-- 背景
-- ---------------------------------------------------------------------------
BG_PAINT.tundra = function(x, rnd) -- 第八章：雪原、冰裂、雪堆和枯松
    x:fill(0, 0, AW, FIELD_H, '#c9dcec')
    local snow = { [0] = '#c2d6e8', '#d4e4f2', '#bccfe2', '#dbe9f5' }
    for i = 0, 1599 do local c = snow[floor(rnd() * 4)]; x:fill(floor(rnd() * AW), floor(rnd() * FIELD_H), 1, 1, c) end
    for c = 0, 7 do -- 冰面裂纹
        local px, py = rnd() * AW, 16 + rnd() * (FIELD_H - 26)
        local len = 10 + floor(rnd() * 20)
        for i = 0, len - 1 do
            x:fill(js.trunc(px), js.trunc(py), 1, 1, '#8fb4d4')
            px = px + ((rnd() < 0.5) and 1 or -1) * ((rnd() < 0.7) and 1 or 0); py = py + ((rnd() < 0.5) and 1 or 0)
            if rnd() < 0.15 then x:fill(js.trunc(px) + 1, js.trunc(py), 1, 1, '#ffffff') end
        end
    end
    for p = 0, 5 do -- 结冰的水洼
        local cx, cy = 12 + rnd() * (AW - 24), 18 + rnd() * (FIELD_H - 30)
        local rw, rh = 7 + floor(rnd() * 10), 2 + floor(rnd() * 3)
        for dy = -rh, rh do
            local w = floor(rw * sqrt(max(0, 1 - (dy / rh) ^ 2)))
            x:fill(floor(cx - w), floor(cy + dy), w * 2, 1, (dy == rh) and '#7fa6c8' or '#a8cce6')
        end
        x:fill(floor(cx - rw * 0.4), floor(cy - 1), 2, 1, '#ffffff'); x:fill(floor(cx - rw * 0.4) + 3, floor(cy - 1), 1, 1, '#ffffff')
    end
    for i = 0, 39 do -- 雪堆的影子
        local px, py = floor(rnd() * AW), 12 + floor(rnd() * (FIELD_H - 14))
        x:fill(px, py, 3, 1, '#ffffff'); x:fill(px, py + 1, 3, 1, '#a6c0d8')
    end
    for i = 0, 9 do -- 枯松（只画在边缘）
        local px = (rnd() < 0.5) and floor(rnd() * 22) or (AW - 22 + floor(rnd() * 20))
        local py = 18 + floor(rnd() * (FIELD_H - 30))
        x:fill(px, py - 1, 1, 3, '#5a4a3a')
        x:fill(px - 1, py - 4, 3, 1, '#2f5a4a'); x:fill(px - 2, py - 3, 5, 1, '#2f5a4a'); x:fill(px, py - 6, 1, 2, '#2f5a4a')
        x:fill(px - 1, py - 5, 1, 1, '#ffffff'); x:fill(px + 1, py - 3, 1, 1, '#ffffff')
    end
    x:fill(0, 0, AW, 7, '#6a86a8')
    for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#6a86a8') end
    for i = 0, AW - 1, 5 do local py = 1 + floor(rnd() * 4); x:fill(i + floor(rnd() * 3), py, 2, 1, '#e8f4ff') end -- 远处冰山
    for i = 0, AW - 1, 13 do x:fill(i + floor(rnd() * 7), 5, 1, 1, '#ffffff') end
end
BG_PAINT.sky = function(x, rnd) -- 第九章：悬浮石台、云海、金色符文
    x:fill(0, 0, AW, FIELD_H, '#8fc4ec')
    for gy = 0, FIELD_H - 1 do -- 远处的云海（横向条纹）
        if gy % 6 == 0 then for gx = 0, AW - 1, 3 do if rnd() < 0.5 then x:fill(gx, gy, 3, 1, '#a8d4f2') end end end
    end
    -- 石台：大块浅色石板，中间留几道缝露出天空
    x:fill(4, 12, AW - 8, FIELD_H - 16, '#d8d2c4')
    local stone = { [0] = '#cfc8b8', '#e2dccf', '#c8c0ae', '#ddd6c6' }
    for i = 0, 1399 do local c = stone[floor(rnd() * 4)]; x:fill(4 + floor(rnd() * (AW - 8)), 12 + floor(rnd() * (FIELD_H - 16)), 1, 1, c) end
    for gx = 4, AW - 5, 36 do x:fill(gx, 12, 1, FIELD_H - 16, '#b8b0a0') end
    for gy = 12, FIELD_H - 5, 26 do x:fill(4, gy, AW - 8, 1, '#b8b0a0') end
    for c = 0, 3 do -- 石缝
        local px = 40 + floor(rnd() * (AW - 80))
        local py = 20 + floor(rnd() * (FIELD_H - 40))
        for i = 0, 14 do x:fill(px + i, py + floor(sin(i * 0.7) * 1.5), 1, 2, '#8fc4ec') end
    end
    for i = 0, 11 do -- 金色符文
        local px, py = 12 + floor(rnd() * (AW - 24)), 18 + floor(rnd() * (FIELD_H - 30))
        x:fill(px - 1, py, 3, 1, '#e2b33c'); x:fill(px, py - 1, 1, 3, '#e2b33c'); x:fill(px, py, 1, 1, '#fff6b0')
    end
    -- 边缘云朵
    for i = 0, 17 do
        local px = floor(rnd() * AW)
        local py = (rnd() < 0.5) and (FIELD_H - 6 + floor(rnd() * 4)) or (8 + floor(rnd() * 5))
        x:fill(px, py, 7, 2, '#ffffff'); x:fill(px + 2, py - 1, 3, 1, '#ffffff'); x:fill(px + 1, py + 2, 5, 1, '#e4f2ff')
    end
    x:fill(0, 0, AW, 7, '#5a96c8')
    for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#5a96c8') end
    for i = 0, AW - 1, 9 do x:fill(i + floor(rnd() * 5), 2 + floor(rnd() * 3), 4, 1, '#bfe0f8') end
end
BG_PAINT.throne = function(x, rnd) -- 第十章：黑曜石地砖、血色地毯、金边、烛火
    x:fill(0, 0, AW, FIELD_H, '#241a2a')
    for gy = 8, FIELD_H - 1, 16 do
        for gx = 0, AW - 1, 16 do
            local c = ((floor(gx / 16) + floor(gy / 16)) % 2 == 0) and '#2b2034' or '#1f1626'
            x:fill(gx, gy, 16, 16, c)
        end
    end
    local st = { [0] = '#30243a', '#1a1220', '#352840', '#22182a' }
    for i = 0, 999 do local c = st[floor(rnd() * 4)]; x:fill(floor(rnd() * AW), 8 + floor(rnd() * (FIELD_H - 8)), 1, 1, c) end
    -- 血色地毯（横贯战场中线）
    local cy = 72
    x:fill(0, cy - 9, AW, 19, '#5a0f1f')
    x:fill(0, cy - 10, AW, 1, '#c8900f'); x:fill(0, cy + 10, AW, 1, '#c8900f')
    for gx = 0, AW - 1, 8 do x:fill(gx + 3, cy - 1, 2, 2, '#7a1f2b'); x:fill(gx + 3, cy - 7, 1, 1, '#a8102a'); x:fill(gx + 3, cy + 6, 1, 1, '#a8102a') end
    for gx = 0, AW - 1, 4 do if rnd() < 0.5 then x:fill(gx, cy - 9 + floor(rnd() * 18), 1, 1, '#4a0c18') end end
    -- 烛台
    for i = 0, 7 do
        local px = 12 + i * 33 + floor(rnd() * 5)
        for _, py in ipairs({ 24, FIELD_H - 12 }) do
            x:fill(px, py - 3, 1, 4, '#c8900f'); x:fill(px - 1, py + 1, 3, 1, '#a8701c')
            x:fill(px, py - 5, 1, 2, '#ffe14a'); x:fill(px, py - 6, 1, 1, '#ffffff')
        end
    end
    -- 裂缝里的暗红光
    for c = 0, 5 do
        local px, py = rnd() * AW, 16 + rnd() * (FIELD_H - 26)
        for i = 0, 8 + floor(rnd() * 12) do
            x:fill(js.trunc(px), js.trunc(py), 1, 1, (rnd() < 0.25) and '#ff3434' or '#7a1f2b')
            px = px + ((rnd() < 0.5) and 1 or -1); if rnd() < 0.4 then py = py + ((rnd() < 0.5) and -1 or 1) end
        end
    end
    x:fill(0, 0, AW, 7, '#120c18')
    for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#120c18') end
    for i = 0, AW - 1, 16 do x:fill(i + 6, 1, 3, 5, '#5a0f1f'); x:fill(i + 7, 2, 1, 3, '#c8900f') end -- 王旗
end

-- 环境粒子
local _renderArena = renderArena
function renderArena()
    local bg = curCh().bg
    if not REDUCED and G.phase ~= nil then
        if bg == 'tundra' then
            local B = G.battle
            local heavy = B and B.bliz and B.bliz.on
            local n = heavy and 3 or ((js.random() < 0.35) and 1 or 0)
            for _ = 1, n do
                FX.parts:push({ x = rand(-20, AW), y = rand(-4, FIELD_H - 20), vx = heavy and rand(30, 50) or rand(4, 10), vy = rand(10, 18), g = 0, life = 1.6, max = 1.6, color = (js.random() < 0.7) and '#ffffff' or '#dfefff', size = 1 })
            end
        elseif bg == 'sky' then
            local B = G.battle
            if B and B.gale and B.gale.on then
                for _ = 1, 2 do FX.parts:push({ x = (B.gale.dir > 0) and rand(-10, 40) or rand(AW - 40, AW + 10), y = rand(14, FIELD_H - 6), vx = B.gale.dir * rand(90, 140), vy = rand(-3, 3), g = 0, life = 1.4, max = 1.4, color = (js.random() < 0.5) and '#ffffff' or '#e4f2ff', size = 1 }) end
            elseif js.random() < 0.12 then
                FX.parts:push({ x = rand(0, AW), y = rand(14, FIELD_H - 6), vx = rand(-3, 3), vy = -rand(3, 6), g = 0, life = 1.5, max = 1.5, color = (js.random() < 0.5) and '#fff6b0' or '#ffffff', size = 1 })
            end
        elseif bg == 'throne' and js.random() < 0.2 then
            FX.parts:push({ x = rand(0, AW), y = rand(20, FIELD_H - 4), vx = rand(-2, 2), vy = -rand(6, 12), g = 0, life = 1.3, max = 1.3, color = (js.random() < 0.6) and '#ff5a3a' or '#ffb04a', size = 1 })
        end
    end
    _renderArena()
end

return true
