-- ============================================================================
-- 第六次更新：三个新兵种（吟游诗人、幼龙、冰霜元素）及其路线、技能文案
-- 新类别：「龙族」（龙鳞：受到的伤害 -10%）、「元素」（免疫减速和根植，阵亡时冰爆）
-- 由 logic.lua 在合并原版数据表之后调用（紧跟在 data_ext 之后）
-- ============================================================================
local js = require("game.compat")
local A = js.A

return function(N)
    local SUP = N.SUP_PAL
    N.KIND_NAME.dragon = '龙族'
    N.KIND_NAME.element = '元素'

    -- ---------- 兵种 ----------
    -- unlock 是零起始前置章节索引：本工程 7 章体系下，吟游诗人=通关第七章「沉没海渊」普通，
    -- 幼龙=第八章「霜寒冰原」普通，冰霜元素=第九章「天空浮城」普通。
    N.CLASSES.bard = { name = '吟游诗人', sprite = 'bard', kind = 'human', note = '远程辅助：音符普攻，战歌给全队加攻击和攻速', hp = 70, atk = 9, cd = 1.0, range = 62, speed = 20, r = 5, proj = 'note',
        unlock = 6 }
    N.CLASSES.whelp = { name = '幼龙', sprite = 'whelp', kind = 'dragon', note = '新类别「龙族」：龙鳞让受到的伤害 -10%，普攻是带小范围溅射的火球', hp = 96, atk = 12, cd = 1.2, range = 46, speed = 20, r = 6, proj = 'flame', splash = 10,
        fx = { dragonScale = 0.1 }, unlock = 7 }
    N.CLASSES.frostling = { name = '冰霜元素', sprite = 'frostling', kind = 'element', note = '新类别「元素」：免疫减速和根植，阵亡时冰爆冻结周围敌人；技能以冻结控场为主', hp = 108, atk = 10, cd = 1.1, range = 34, speed = 18, r = 5, proj = 'icicle',
        fx = { elem = true }, unlock = 8 }
    N.CLASS_KEYS:push('bard', 'whelp', 'frostling')
    N.SYM_CLASS.L = 'bard'; N.SYM_CLASS.D = 'whelp'; N.SYM_CLASS.I = 'frostling'
    N.SYM_SPRITE.L = 'sym_bard'; N.SYM_SPRITE.D = 'sym_whelp'; N.SYM_SPRITE.I = 'sym_frost'
    N.SYM_COLOR.L = '#ff8ac8'; N.SYM_COLOR.D = '#ff8a3a'; N.SYM_COLOR.I = '#9fdcff'
    N.CLASS_COLOR.bard = '#ff8ac8'; N.CLASS_COLOR.whelp = '#ff8a3a'; N.CLASS_COLOR.frostling = '#9fdcff'
    N.SYM_WEIGHT.L = 24; N.SYM_WEIGHT.D = 24; N.SYM_WEIGHT.I = 24
    N.CLASS_SKILL.bard = 'battlesong'; N.CLASS_SKILL.whelp = 'dragonbreath'; N.CLASS_SKILL.frostling = 'icenova'
    N.ATK_STYLE_CLS.bard = 'cast'; N.ATK_STYLE_CLS.whelp = 'cast'; N.ATK_STYLE_CLS.frostling = 'cast'
    N.TIER_PAL.bard = A(nil, { a = '#c44a8a', A = '#ff8ac8' }, { a = '#8a3ac4', A = '#f0c8ff' }, { a = '#c8900f', A = '#ffe680' })
    N.TIER_PAL.whelp = A(nil, { a = '#d8532a', A = '#ff9a4a' }, { a = '#b02a3a', A = '#ffb0a0' }, { a = '#c8900f', A = '#ffe680' })
    N.TIER_PAL.frostling = A(nil, { a = '#3a8ad8', A = '#9fdcff' }, { a = '#2a5ac9', A = '#e8f8ff' }, { a = '#c8900f', A = '#ffe680' })
    N.PROJ_BURST.note = '#ff8ac8'; N.PROJ_BURST.flame = '#ff8a2a'; N.PROJ_BURST.icicle = '#bff4ff'

    -- ---------- 技能 ----------
    local SK = {
        -- 吟游诗人
        battlesong = { '激昂战歌', 28, '全队攻击 +20%、攻速 +25%，持续 5 秒' },
        encore = { '再来一曲', 26, '全队技能能量 +20（不含自己），自身攻速翻倍 3 秒' },
        warhymn = { '战争赞歌', 28, '全队攻击 +30%，持续 6 秒；身边队友再回复 8% 最大生命' },
        lullaby = { '摇篮曲', 30, '让攻击最高的 3 个敌人沉睡 2.5 秒（首领减半），沉睡的敌人受到的下一次伤害 +50%' },
        saga = { '英雄史诗', 30, '全队获得 20% 最大生命的护盾，并攻速 +30%，持续 5 秒' },
        dissonance = { '不谐和音', 30, '刺耳的音浪扫过全场：对每个敌人造成 120% 伤害，抽走 50 点技能能量，4 秒内攻击 -25%' },
        symphony = { '命运交响曲', 34, '全队攻击 +35%、攻速 +35%，持续 6 秒，并各获得 30 点技能能量（不含自己）' },
        requiem = { '安魂曲', 32, '对全部敌人造成 220% 伤害，生命低于 25% 的非首领敌人直接被斩杀；我方全队回复 15% 最大生命' },
        bloodopera = { '血色歌剧', 32, '对全部敌人造成 150% 伤害；全队狂热 5 秒（攻速翻倍）、攻击 +30%、吸血 +25%' },
        -- 幼龙
        dragonbreath = { '龙息', 28, '向前方扇形喷火：造成 160% 伤害并灼烧 3 秒' },
        flamespit = { '连珠火弹', 26, '向 3 个敌人各喷出一枚火弹：每枚 130% 小范围伤害并灼烧' },
        emberrain = { '余烬之雨', 28, '余烬落向 6 个随机位置：每处造成 90% 范围伤害并灼烧 3 秒' },
        jadescale = { '翠玉龙鳞', 28, '自身和最近的 2 个队友获得 30% 最大生命的护盾，3 秒内免疫控制' },
        frostbreath = { '冰霜吐息', 28, '向前方扇形喷出寒气：造成 170% 伤害并冻结 1.5 秒（首领减半）' },
        shadowflame = { '暗影烈焰', 30, '对生命比例最低的 3 个敌人各造成 200% 伤害，并诅咒 4 秒（受到的伤害 +25%）' },
        dragonfall = { '巨龙降临', 34, '飞上天空后砸向敌群中心：造成 300% 范围伤害、眩晕 1.5 秒，留下持续 5 秒的火海' },
        goldenbreath = { '黄金吐息', 32, '喷出贯穿全场的金色龙炎，造成 280% 伤害；全队获得 20% 最大生命的护盾' },
        apocalypse = { '末日龙炎', 34, '血焰席卷全场：对每个敌人造成 250% 伤害并灼烧 5 秒，4 秒内敌人攻击 -30%' },
        -- 冰霜元素
        icenova = { '冰晶新星', 28, '周围的敌人受到 130% 伤害并冻结 1.2 秒（首领减半）' },
        iceshard = { '冰棱齐射', 25, '向 4 个敌人射出冰棱：每道 100% 伤害并减速 40%，持续 2 秒' },
        iceblock = { '寒冰屏障', 30, '把自己冻进冰块 2 秒（无敌），破冰时嘲讽周围的敌人并回复 25% 最大生命' },
        blizzardcall = { '暴风雪', 30, '在目标处召来持续 5 秒的暴风雪：每 0.5 秒造成 35% 伤害并减速 50%' },
        glacialslam = { '冰川重击', 28, '对目标造成 260% 伤害，并冻结它周围的敌人 1.5 秒' },
        crystalprison = { '晶石牢笼', 30, '把攻击最高的 2 个敌人封进水晶 3 秒（首领 1.5 秒）；牢笼碎裂时造成 200% 伤害' },
        absolutezero = { '绝对零度', 34, '全场敌人冻结 2 秒并受到 150% 伤害，原本就被减速或冻结的敌人伤害翻倍' },
        aurora = { '极光帷幕', 32, '全队回复 20% 最大生命并解除负面状态，4 秒内受到的伤害 -25%' },
        crimsonfrost = { '血色冰狱', 34, '全场敌人冻结 2.5 秒，冰刺造成 260% 伤害并流血 4 秒；我方全队获得 20% 最大生命的护盾' },
    }
    for k, v in pairs(SK) do N.SKILLS[k] = { name = v[1], charge = v[2], desc = v[3] } end

    -- ---------- 路线 ----------
    local function br(k, cls, q, name, role, skill, aura, passive, mods, fx, extra)
        local b = { cls = cls, q = q, name = name, role = role, skill = skill, aura = aura, passive = passive, mods = mods or {}, fx = fx, sprite = N.CLASSES[cls].sprite }
        if extra then for kk, vv in pairs(extra) do b[kk] = vv end end
        N.BRANCHES[k] = b
    end
    -- 吟游诗人
    br('troubadour', 'bard', 0, '行吟歌手', '能量循环', 'encore', '#ff8ac8', '攻击 +10%，攻速 +10%', { atk = 0.1, spd = 0.1 })
    br('warbard', 'bard', 1, '战歌手', '全队增伤', 'warhymn', '#ff6a4a', '攻击 +15%，生命 +15%', { atk = 0.15, hp = 0.15 })
    br('lullabard', 'bard', 1, '安眠诗人', '催眠控场', 'lullaby', '#b48cf0', '生命 +20%；技能能量获取 +15%', { hp = 0.2 }, { chargeMul = 1.15 })
    br('skald', 'bard', 2, '北地史诗吟唱者', '护盾加速', 'saga', '#9fdcff', '生命 +30%，攻击 +15%', { hp = 0.3, atk = 0.15 })
    br('dissonant', 'bard', 2, '噪音术士', '抽能削弱', 'dissonance', '#c06bff', '攻击 +20%；普攻 25% 几率抽走目标 10 点技能能量', { atk = 0.2 }, { drainHitR = 0.25 })
    br('maestro', 'bard', 3, '交响指挥家', '命运交响', 'symphony', '#ffe680', '生命 +35%，攻击 +25%；光环：全队技能能量获取 +12%', { hp = 0.35, atk = 0.25 }, { chargeAura = 0.12 })
    br('requiembard', 'bard', 3, '安魂咏者', '群伤斩杀', 'requiem', '#e4f2ff', '生命 +30%，攻击 +35%', { hp = 0.3, atk = 0.35 })
    br('sup_bard', 'bard', 4, '血咏魔音', '血色歌剧', 'bloodopera', '#ff3b3b', '生命 +50%，攻击 +40%；光环：全队技能能量获取 +12%；超凡之躯：免疫眩晕和魅惑', { hp = 0.5, atk = 0.4 }, { chargeAura = 0.12, ccImmune = true }, { sup = true, sprite = 'sup_bard' })
    -- 幼龙
    br('firedrake', 'whelp', 0, '火蜥幼龙', '连珠火弹', 'flamespit', '#ff8a2a', '攻击 +10%，生命 +10%', { atk = 0.1, hp = 0.1 }, { dragonScale = 0.1 })
    br('emberwing', 'whelp', 1, '余烬飞龙', '火雨灼烧', 'emberrain', '#ffb04a', '攻击 +15%；普攻附带灼烧', { atk = 0.15, burn = true }, { dragonScale = 0.1 })
    br('jadedrake', 'whelp', 1, '翡翠龙', '龙鳞护盾', 'jadescale', '#6fdc8a', '生命 +30%；龙鳞减伤提高到 18%', { hp = 0.3 }, { dragonScale = 0.18 })
    br('frostwyrmling', 'whelp', 2, '霜龙', '冰息冻结', 'frostbreath', '#9fdcff', '生命 +20%，攻击 +15%；普攻减速 25%', { hp = 0.2, atk = 0.15, slowHit = 0.25 }, { dragonScale = 0.1 })
    br('shadowdrake', 'whelp', 2, '暗影龙', '诅咒点杀', 'shadowflame', '#c06bff', '攻击 +20%，暴击率 +15%', { atk = 0.2, crit = 0.15 }, { dragonScale = 0.1 })
    br('elderdragon', 'whelp', 3, '远古巨龙', '巨龙降临', 'dragonfall', '#ff6a3a', '生命 +40%，攻击 +30%；普攻溅射范围 +6', { hp = 0.4, atk = 0.3 }, { dragonScale = 0.12, splashPlus = 6 })
    br('goldendragon', 'whelp', 3, '黄金圣龙', '圣炎护佑', 'goldenbreath', '#ffe680', '生命 +40%，攻击 +20%；光环：全队受到的伤害 -6%', { hp = 0.4, atk = 0.2 }, { dragonScale = 0.12, drAura = 0.06 })
    br('sup_whelp', 'whelp', 4, '血焰魔龙', '末日龙炎', 'apocalypse', '#ff3b3b', '生命 +55%，攻击 +40%；普攻附带灼烧；龙鳞减伤 20%；超凡之躯：免疫眩晕和魅惑', { hp = 0.55, atk = 0.4, burn = true }, { dragonScale = 0.2, ccImmune = true }, { sup = true, sprite = 'sup_whelp' })
    -- 冰霜元素
    br('icesprite', 'frostling', 0, '冰精灵', '冰棱齐射', 'iceshard', '#bff4ff', '攻速 +15%，生命 +10%', { spd = 0.15, hp = 0.1 }, { elem = true })
    br('glacierheart', 'frostling', 1, '冰川之心', '冰块坦克', 'iceblock', '#7fb0e0', '生命 +35%，受到的伤害 -10%', { hp = 0.35, dr = 0.1 }, { elem = true })
    br('snowdancer', 'frostling', 1, '雪舞者', '暴风雪', 'blizzardcall', '#e8f8ff', '射程 +20，攻击 +10%', { range = 20, atk = 0.1 }, { elem = true })
    br('frostgiant', 'frostling', 2, '寒冰巨人', '冰川重击', 'glacialslam', '#6ec8ff', '生命 +40%，攻击 +15%', { hp = 0.4, atk = 0.15 }, { elem = true })
    br('crystalmage', 'frostling', 2, '晶石术士', '水晶牢笼', 'crystalprison', '#e0b0ff', '攻击 +20%，暴击率 +15%', { atk = 0.2, crit = 0.15 }, { elem = true })
    br('wintersovereign', 'frostling', 3, '凛冬君主', '绝对零度', 'absolutezero', '#ffffff', '生命 +40%，攻击 +25%；普攻减速 30%', { hp = 0.4, atk = 0.25, slowHit = 0.3 }, { elem = true })
    br('auroraspirit', 'frostling', 3, '极光之灵', '极光帷幕', 'aurora', '#8affc8', '生命 +40%；光环：全队被控时间 -30%', { hp = 0.4 }, { elem = true, ccAura = 0.3 })
    br('sup_frost', 'frostling', 4, '血霜魔灵', '血色冰狱', 'crimsonfrost', '#ff3b3b', '生命 +55%，攻击 +40%；普攻减速 30%；超凡之躯：免疫眩晕和魅惑', { hp = 0.55, atk = 0.4, slowHit = 0.3 }, { elem = true, ccImmune = true }, { sup = true, sprite = 'sup_frost' })

    N.CLASS_BRANCHES.bard = A(A('troubadour'), A('warbard', 'lullabard'), A('skald', 'dissonant'), A('maestro', 'requiembard'))
    N.CLASS_BRANCHES.whelp = A(A('firedrake'), A('emberwing', 'jadedrake'), A('frostwyrmling', 'shadowdrake'), A('elderdragon', 'goldendragon'))
    N.CLASS_BRANCHES.frostling = A(A('icesprite'), A('glacierheart', 'snowdancer'), A('frostgiant', 'crystalmage'), A('wintersovereign', 'auroraspirit'))
    N.SUPER_OF.bard = 'sup_bard'; N.SUPER_OF.whelp = 'sup_whelp'; N.SUPER_OF.frostling = 'sup_frost'

    -- 路线换色
    local P = N.BRPAL
    P.troubadour = { a = '#2f7a34', A = '#7fd36a', r = '#ffd84a' }
    P.warbard = { a = '#a8102a', A = '#ff6a4a', r = '#ffe14a' }
    P.lullabard = { a = '#4a3a8a', A = '#b48cf0', r = '#e4f2ff' }
    P.skald = { a = '#5a6a7a', A = '#9fdcff', r = '#ffffff', b = '#8a6a3a' }
    P.dissonant = { a = '#3a2d52', A = '#c06bff', r = '#6ef0ff' }
    P.maestro = { a = '#1b1530', A = '#5a4a86', r = '#ffe680', y = '#ffffff' }
    P.requiembard = { a = '#c9d2e0', A = '#ffffff', r = '#78a8f2' }
    P.firedrake = { a = '#c84a1a', A = '#ff8a2a' }
    P.emberwing = { a = '#d86a1a', A = '#ffc04a', y = '#ffe680' }
    P.jadedrake = { a = '#2c8a5c', A = '#6fdc8a', y = '#e6ffd6' }
    P.frostwyrmling = { a = '#3a8ad8', A = '#bff4ff', y = '#ffffff' }
    P.shadowdrake = { a = '#3a2d52', A = '#8f4bc4', y = '#c06bff', O = '#ff3b3b' }
    P.elderdragon = { a = '#7a1f2b', A = '#d8433a', y = '#ffb04a' }
    P.goldendragon = { a = '#c8900f', A = '#ffe680', y = '#ffffff' }
    P.icesprite = { a = '#4a9ad8', A = '#d8f4ff' }
    P.glacierheart = { a = '#2a5a8a', A = '#7fb0e0', o = '#bff4ff' }
    P.snowdancer = { a = '#9fc8e8', A = '#ffffff', o = '#ff8ac8' }
    P.frostgiant = { a = '#1f3a6a', A = '#6ec8ff', o = '#ffffff' }
    P.crystalmage = { a = '#6a33c9', A = '#e0b0ff', o = '#ffffff' }
    P.wintersovereign = { a = '#c9d2e0', A = '#ffffff', o = '#6ef0ff', O = '#3b6fd1' }
    P.auroraspirit = { a = '#2c8a6c', A = '#8affc8', o = '#ff8ac8' }
    for _, k in ipairs({ 'sup_bard', 'sup_whelp', 'sup_frost' }) do P[k] = SUP end

    -- 军团强化：新兵种各自的生命 / 攻击强化，以及两个新类别标签页（龙族 / 元素）
    N.UPG_TABS:push(A('dragon', '龙族', 'sym_whelp'), A('element', '元素', 'sym_frost'))
    for _, entry in ipairs({ { 'bard', 'human' }, { 'whelp', 'dragon' }, { 'frostling', 'element' } }) do
        local cls, tab = entry[1], entry[2]
        for _, stat in ipairs({ 'hp', 'atk' }) do
            local label = stat == 'hp' and '生命' or '攻击'
            N.UPG:push({ id = stat .. '_' .. cls, tab = tab, cls = cls, stat = stat, name = N.CLASSES[cls].name .. label, icon = cls,
                max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01,
                note = '只强化' .. N.CLASSES[cls].name .. '（含它的所有转职、晋升与超凡形态）的' .. label .. '，每级 +1%' })
        end
    end
end
