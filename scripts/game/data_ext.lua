-- 更新包的增量数据：旧兵种技能差异化、第三路线，以及三个新兵种。
-- 由 game.data 在基础表与 chapter_data 初始化后调用一次；不进入共享 _ENV。
local js = require("game.compat")
local A = js.A

---@param N table
return function(N)
    local SUP = N.SUP_PAL
    N.KIND_NAME.machine = '机械'

    -- 保留旧兵种 / 路线 ID，更新其独有技能与被动，不影响既有单位存档。
    N.CLASSES.tiger.atk = 12
    N.SKILLS.pierce.desc = '射出一支贯穿箭，对直线上所有敌人造成 220% 伤害；飞到场边后折返一次，折返伤害 50%'
    N.SKILLS.blackhole.desc = '在目标处制造持续 4 秒的黑洞，把周围敌人吸向中心，圈内敌人受到的伤害 +15%；每 0.5 秒造成 50% 伤害，结束时爆炸造成 150% 伤害'
    N.SKILLS.moonlight.desc = '月光笼罩全场：所有敌人 6 秒内造成的伤害 -40%（首领 -20%），我方全队回复 12% 生命'
    local SK = {
        venomrush = { '藤毒狂涌', 25, '自身狂热 5 秒（攻速翻倍），期间普攻额外叠加 1 层剧毒' },
        thornfield = { '荆棘领域', 28, '在身边展开 5 秒的荆棘领域：对范围内敌人造成 80% 伤害；领域里的敌人攻击你的单位时，受到所造成伤害 60% 的反伤' },
        shadowstrike = { '影袭', 26, '闪到最远的敌人身边，造成 220% 伤害，并在 1 秒内闪避一切攻击' },
        drinkblood = { '饮血', 25, '连咬目标 2 次，每次 150% 伤害，回复造成伤害的 50%；自身生命低于 50% 时回复翻倍' },
        huntchain = { '追杀', 25, '扑向生命比例最低的敌人，造成 220% 伤害；击杀后立刻再扑一次，最多 3 连' },
        frenzy = { '狂乱', 28, '狂热 4 秒（攻速 +100%），期间吸血 30%' },
        purify = { '圣愈净化', 30, '治疗生命比例最低的队友 60% 最大生命，并解除全队的眩晕、中毒、灼烧、流血、诅咒和减速' },
        sunshield = { '烈阳庇佑', 30, '全队获得 30% 最大生命的护盾，并获得 6 秒反伤光环：被攻击时反弹 30% 伤害' },
        landslide = { '山崩', 30, '在目标周围落下 4 块巨石，每块对小范围造成 160% 伤害，并减速 40% 持续 3 秒' },
        throatrip = { '裂喉', 30, '造成 280% 伤害并流血 5 秒；目标已经在流血时，伤害再 +60%' },
        ironwall = { '铁壁', 24, '嘲讽附近的敌人，自身 4 秒内受到的伤害 -35%，全队 4 秒内受到的伤害 -20%' },
        poisoncloud = { '毒云', 28, '在目标处留下持续 4 秒的毒云：范围内的敌人每 0.5 秒叠加 1 层剧毒，并减速 25%' },
        sunward = { '日光结界', 30, '全队 4 秒内受到的伤害 -30%，并回复 10% 最大生命' },
        clawstorm = { '裂空爪', 28, '撕裂身边所有敌人，造成 130% 伤害并流血 3 秒' },
        bulwark = { '守护誓言', 28, '嘲讽附近的敌人；自身获得 30% 最大生命的护盾，身边的队友各获得 20% 最大生命的护盾' },
        infest = { '寄生爆发', 30, '对目标造成 100% 伤害并叠加 3 层剧毒，再把目标身上的剧毒层数复制给它周围的所有敌人' },
        cleanse = { '净化之光', 30, '解除全队所有负面状态（眩晕、中毒、灼烧、流血、诅咒、减速、枯萎、根植），3 秒内免疫控制，并回复 8% 最大生命' },
        rootguard = { '生根', 26, '扎根嘲讽附近的敌人，获得 25% 最大生命的护盾，4 秒内每秒回复 4% 最大生命' },
        barkskin = { '树皮甲', 26, '5 秒内受到的伤害 -40%，并反弹所受近战伤害的 30%' },
        brambleburst = { '荆棘爆发', 28, '荆棘从脚下炸开：对周围敌人造成 120% 伤害并根植 1.5 秒（不能移动）' },
        mossheal = { '苔藓滋养', 30, '身边队友回复 15% 最大生命，并在 4 秒内每秒回复 4%' },
        timberslam = { '倒木重击', 28, '向前方砸下整棵古木：对前方扇形内的敌人造成 220% 伤害并眩晕 1 秒' },
        rootnet = { '根网', 30, '根须铺满周围：附近的敌人受到 60% 伤害、根植 2.5 秒，并被嘲讽' },
        lifegrove = { '生命林地', 32, '在身边长出持续 6 秒的林地：我方在林地里每秒回复 4% 最大生命，敌人减速 30%' },
        uproot = { '拔根横扫', 30, '拔起树根横扫周围：造成 200% 伤害、击退并眩晕 1 秒，自身回复 15% 生命' },
        bloodgrove = { '血木降临', 32, '血色根须从每个敌人脚下穿出：造成 200% 伤害、根植 2 秒并流血 4 秒；我方全队获得 25% 最大生命的护盾' },
        thunderstorm = { '雷暴', 28, '在目标处召来持续 4 秒的电场：每 0.5 秒对范围内敌人造成 40% 伤害，有几率麻痹 0.3 秒' },
        galestrike = { '疾风连击', 25, '向随机敌人连射 4 道雷羽，每道 90% 伤害，30% 几率麻痹 0.3 秒' },
        divebomb = { '俯冲', 28, '俯冲生命比例最低的敌人，造成 320% 伤害；击杀则返还 50 能量' },
        tailwind = { '顺风', 30, '全队狂热 3 秒（攻速翻倍），3 秒内闪避 20% 的攻击' },
        ballstorm = { '球状闪电', 30, '放出 3 颗缓慢的球状闪电，各自在落点爆炸，造成 140% 范围伤害并麻痹 0.5 秒' },
        featherstorm = { '羽刃风暴', 30, '羽刃落向每个敌人：造成 100% 伤害并流血 3 秒' },
        skyfury = { '九天雷霆', 34, '从天上劈下 6 道雷霆，每道对随机敌人造成 200% 伤害并麻痹 0.6 秒' },
        flameraid = { '炎羽突袭', 30, '化作火羽贯穿直线上的所有敌人，造成 300% 伤害并灼烧 3 秒' },
        crimsonstorm = { '赤雷天罚', 32, '赤红雷暴覆盖全场：对每个敌人造成 250% 伤害并麻痹 1 秒，在敌群中心留下 5 秒电场' },
        overload = { '过载', 28, '自身和身边队友攻速 +60%，持续 4 秒；结束后自身眩晕 1 秒' },
        gearshot = { '齿轮弹幕', 25, '向附近的敌人射出 5 枚齿轮，每枚 80% 伤害' },
        steamburst = { '蒸汽爆发', 28, '喷出高压蒸汽：周围敌人受到 150% 伤害、被推开并减速 40%，自身获得 20% 最大生命的护盾' },
        repair = { '紧急维修', 30, '修复生命比例最低的两个队友各 30% 最大生命，并解除它们的眩晕' },
        artillery = { '重炮轰击', 30, '向目标区域连发 3 枚炮弹，每枚造成 180% 范围伤害' },
        magnetpulse = { '磁暴脉冲', 30, '把附近的敌人吸向目标，造成 120% 伤害并击碎它们的护盾' },
        missilebarrage = { '导弹齐射', 32, '向随机敌人发射 10 枚导弹，每枚 120% 伤害并带小范围溅射' },
        rewind = { '时间回溯', 32, '全队回复 25% 最大生命，并各获得 40 点技能能量（不含自己）' },
        redprotocol = { '赤钢协议', 32, '部署 2 座赤钢炮台（最多 2 座，满了改为修好炮台），全队过载 4 秒（攻速 +60%）' },
    }
    for k, v in pairs(SK) do N.SKILLS[k] = { name = v[1], charge = v[2], desc = v[3] } end

    local changes = {
        windrunner = { fx = { pierceReturn = true }, passive = '射程 +20，攻速 +15%；技能「贯穿之箭」飞到场边后会折返一次' },
        avenger = { passive = '生命 +40%；被近战攻击时反弹 50% 伤害，被远程普攻命中时反弹一半（25%）' },
        cleric = { role = '单体治疗', skill = 'purify' },
        voidcaller = { fx = { holeVuln = 0.15 }, passive = '攻击 +10%，射程 +10；黑洞持续 4 秒，圈内敌人受到的伤害 +15%' },
        bloodfang = { skill = 'drinkblood' },
        shadowcat = { role = '影袭后排', skill = 'shadowstrike' },
        hungrytiger = { role = '连环追杀', skill = 'huntchain' },
        sabre = { role = '流血裂喉', skill = 'throatrip' },
        ironback = { role = '带队减伤', skill = 'ironwall' },
        frenzybear = { fx = { rageSpd = true }, role = '狂乱吸血', skill = 'frenzy', passive = '攻击 +20%，攻速 +15%；生命每损失 10%，攻速再 +4%（最多 +20%）', mods = { atk = 0.2, spd = 0.15 } },
        mountain = { role = '落石减速', skill = 'landslide', passive = '生命 +30%；被近战攻击时反弹 30% 伤害，被远程普攻命中时反弹一半（15%）' },
        vine = { role = '狂热叠毒', skill = 'venomrush' },
        plaguebloom = { role = '毒云封路', skill = 'poisoncloud' },
        photosyn = { role = '限时减伤', skill = 'sunward' },
        rose = { role = '荆棘反伤', skill = 'thornfield', passive = '生命 +20%；被近战攻击时反弹 40% 伤害，被远程普攻命中时反弹一半（20%）；普攻使目标受到的伤害 +10%，持续 3 秒' },
        moonbloom = { role = '全场削弱' },
        sungod = { role = '护盾反伤', skill = 'sunshield' },
        sup_bear = { passive = '生命 +60%，受到的伤害 -25%；被近战攻击时反弹 30% 伤害，被远程普攻命中时反弹 15%；超凡之躯：免疫眩晕和魅惑' },
    }
    for k, fields in pairs(changes) do
        for field, value in pairs(fields) do N.BRANCHES[k][field] = value end
    end

    -- ---------- 新兵种 ----------
    N.CLASSES.treant = { name = '古树卫士', sprite = 'treant', kind = 'plant', note = '植物里的坦克，嘲讽后靠护盾和回血硬扛', hp = 140, atk = 7, cd = 1.3, range = 8, speed = 14, r = 6,
        fx = { regen = 0.008 }, unlock = 1 }
    N.CLASSES.hawk = { name = '雷鹰', sprite = 'hawk', kind = 'animal', note = '动物里的远程，25% 闪避，技能留下电场', hp = 58, atk = 11, cd = 0.9, range = 64, speed = 26, r = 5, proj = 'zap',
        fx = { dodge = 0.25 }, unlock = 2 }
    -- unlock 是零起始前置章节索引：3 仍指现有第四章「霜狱冰原」普通。
    N.CLASSES.clockwork = { name = '发条机兵', sprite = 'clockwork', kind = 'machine', note = '新类别「机械」：免疫流血、中毒、灼烧，但被冻结或眩晕的时间 +50%', hp = 105, atk = 10, cd = 1.0, range = 36, speed = 16, r = 5, proj = 'gear',
        fx = { mech = true }, unlock = 3 }
    N.CLASS_KEYS:push('treant', 'hawk', 'clockwork')
    N.SYM_CLASS.R = 'treant'; N.SYM_CLASS.H = 'hawk'; N.SYM_CLASS.K = 'clockwork'
    N.SYM_SPRITE.R = 'sym_treant'; N.SYM_SPRITE.H = 'sym_hawk'; N.SYM_SPRITE.K = 'sym_clock'
    N.SYM_COLOR.R = '#6fbf5a'; N.SYM_COLOR.H = '#78a8f2'; N.SYM_COLOR.K = '#e2b33c'
    N.CLASS_COLOR.treant = '#6fbf5a'; N.CLASS_COLOR.hawk = '#78a8f2'; N.CLASS_COLOR.clockwork = '#e2b33c'
    N.SYM_WEIGHT.R = 24; N.SYM_WEIGHT.H = 24; N.SYM_WEIGHT.K = 24
    N.CLASS_SKILL.treant = 'rootguard'; N.CLASS_SKILL.hawk = 'thunderstorm'; N.CLASS_SKILL.clockwork = 'overload'
    N.ATK_STYLE_CLS.treant = 'maul'; N.ATK_STYLE_CLS.hawk = 'cast'; N.ATK_STYLE_CLS.clockwork = 'recoil'
    N.TIER_PAL.treant = A(nil, { z = '#3f9a46', Z = '#7fd36a' }, { z = '#2c8a5c', Z = '#bff0c8' }, { z = '#c8900f', Z = '#ffe680' })
    N.TIER_PAL.hawk = A(nil, { a = '#3b6fd1', A = '#78a8f2' }, { a = '#2a56c9', A = '#d8ecff' }, { a = '#c8900f', A = '#ffe680' })
    N.TIER_PAL.clockwork = A(nil, { a = '#3aa6c8', A = '#6ef0ff' }, { a = '#8f4bc4', A = '#e0b0ff' }, { a = '#c8900f', A = '#ffe680', h = '#a8803a', H = '#ffe0a0' })
    N.PROJ_BURST.zap = '#ffe14a'; N.PROJ_BURST.gear = '#e2b33c'

    -- ---------- 路线 ----------
    local function br(k, cls, q, name, role, skill, aura, passive, mods, fx, extra)
        local b = { cls = cls, q = q, name = name, role = role, skill = skill, aura = aura, passive = passive, mods = mods or {}, fx = fx, sprite = N.CLASSES[cls].sprite }
        if extra then for kk, vv in pairs(extra) do b[kk] = vv end end
        N.BRANCHES[k] = b
    end
    -- 旧兵种的第三选择；不替换旧路线表中的任何已有 ID。
    br('rendtiger', 'tiger', 2, '裂爪虎', '溅射群伤', 'clawstorm', '#ff7a3a', '攻击 +10%，生命 +15%；普攻对目标周围的敌人造成 50% 溅射伤害', { atk = 0.1, hp = 0.15 }, { splash = 14 })
    br('guardbear', 'bear', 1, '守护熊', '分担伤害', 'bulwark', '#7fb0e0', '生命 +50%，受到的伤害 -10%；身边队友受到的伤害有 30% 转由守护熊承担', { hp = 0.5, dr = 0.1 }, { guardShare = 0.3 })
    br('parasite', 'flytrap', 2, '寄生花', '传染爆发', 'infest', '#b0e05a', '攻击 +10%；普攻叠加 2 层剧毒；中毒的敌人死亡时，把身上的剧毒传染给附近的敌人', { atk = 0.1 }, { poisonHit = 2, contagion = true })
    br('purebloom', 'sunflower', 1, '净化花', '净化免控', 'cleanse', '#cfefff', '生命 +20%；光环：全队被眩晕、冻结的时间 -40%', { hp = 0.2 }, { ccAura = 0.4 })
    N.CLASS_BRANCHES.tiger[2]:push('rendtiger'); N.CLASS_BRANCHES.bear[1]:push('guardbear')
    N.CLASS_BRANCHES.flytrap[2]:push('parasite'); N.CLASS_BRANCHES.sunflower[1]:push('purebloom')

    br('oakguard', 'treant', 0, '橡木卫士', '坚守前排', 'barkskin', '#9be36b', '生命 +25%，受到的伤害 -10%', { hp = 0.25, dr = 0.1 })
    br('thornoak', 'treant', 1, '荆棘古木', '根植反伤', 'brambleburst', '#4fbf4a', '生命 +30%；被近战攻击时反弹 25% 伤害，被远程普攻命中时反弹一半', { hp = 0.3 }, { thorns = 0.25 })
    br('mossheart', 'treant', 1, '苔心树人', '自愈奶坦', 'mossheal', '#7fd36a', '生命 +30%；每秒回复 2% 最大生命', { hp = 0.3 }, { regen = 0.02 })
    br('ironwood', 'treant', 2, '铁木巨人', '重击控制', 'timberslam', '#c9b08a', '生命 +40%，受到的伤害 -15%', { hp = 0.4, dr = 0.15 })
    br('rootweaver', 'treant', 2, '盘根者', '群体根植', 'rootnet', '#2f7a34', '生命 +35%；每秒回复 1.5% 最大生命', { hp = 0.35 }, { regen = 0.015 })
    br('worldtree', 'treant', 3, '世界树', '林地光环', 'lifegrove', '#bff0c8', '生命 +50%；光环：全队受到的伤害 -8%', { hp = 0.5 }, { drAura = 0.08 })
    br('elderent', 'treant', 3, '远古树人', '横扫压制', 'uproot', '#ffd84a', '生命 +45%，攻击 +25%', { hp = 0.45, atk = 0.25 })
    br('sup_treant', 'treant', 4, '血根古神', '血木降临', 'bloodgrove', '#ff3b3b', '生命 +60%，受到的伤害 -20%；每秒回复 2% 最大生命；超凡之躯：免疫眩晕和魅惑', { hp = 0.6, dr = 0.2 }, { regen = 0.02, ccImmune = true }, { sup = true, sprite = 'sup_treant' })
    br('stormhawk', 'hawk', 0, '风暴鹰', '连击麻痹', 'galestrike', '#9ff6ff', '攻速 +20%', { spd = 0.2 }, { dodge = 0.25 })
    br('skyhunter', 'hawk', 1, '天空猎手', '俯冲斩杀', 'divebomb', '#ffe680', '暴击率 +20%，射程 +10', { crit = 0.2, range = 10 }, { dodge = 0.25 })
    br('galewing', 'hawk', 1, '疾风之翼', '全队顺风', 'tailwind', '#bff4ff', '移动速度 +30%；闪避提高到 35%', { move = 0.3 }, { dodge = 0.35 })
    br('thunderbird', 'hawk', 2, '雷鸟', '球状闪电', 'ballstorm', '#ffe14a', '攻击 +15%；普攻有 30% 几率弹射闪电', { atk = 0.15, chainHit = 0.3 }, { dodge = 0.25 })
    br('bladewing', 'hawk', 2, '刃羽鹰', '羽刃流血', 'featherstorm', '#ff8a7a', '攻击 +15%；普攻 20% 几率使目标流血 3 秒', { atk = 0.15 }, { dodge = 0.25, bleedHitR = 0.2 })
    br('rocking', 'hawk', 3, '雷霆鹏王', '九天雷霆', 'skyfury', '#fff6b0', '攻击 +30%，生命 +20%；普攻有 40% 几率弹射闪电', { atk = 0.3, hp = 0.2, chainHit = 0.4 }, { dodge = 0.25 })
    br('phoenixhawk', 'hawk', 3, '炎羽隼', '贯穿灼烧', 'flameraid', '#ff8a2a', '攻击 +25%；普攻附带灼烧', { atk = 0.25, burn = true }, { dodge = 0.25 })
    br('sup_hawk', 'hawk', 4, '赤雷天鹰', '赤雷天罚', 'crimsonstorm', '#ff3b3b', '攻击 +35%，暴击率 +20%；闪避 30%；超凡之躯：免疫眩晕和魅惑', { atk = 0.35, crit = 0.2 }, { dodge = 0.3, ccImmune = true }, { sup = true, sprite = 'sup_hawk' })
    br('gearsoldier', 'clockwork', 0, '齿轮士兵', '齿轮弹幕', 'gearshot', '#e2b33c', '攻击 +10%，生命 +15%', { atk = 0.1, hp = 0.15 }, { mech = true })
    br('steamknight', 'clockwork', 1, '蒸汽骑士', '推人护盾', 'steamburst', '#c9cbd6', '生命 +35%，受到的伤害 -10%', { hp = 0.35, dr = 0.1 }, { mech = true })
    br('repairbot', 'clockwork', 1, '维修机兵', '修复队友', 'repair', '#8fe07a', '生命 +20%；普攻同时修复生命比例最低的队友，修复量为伤害的 50%', { hp = 0.2 }, { mech = true, healHit = 0.5 })
    br('cannonmech', 'clockwork', 2, '炮台机兵', '远程重炮', 'artillery', '#ff8a2a', '射程 +30，攻击 +15%', { range = 30, atk = 0.15 }, { mech = true })
    br('magnetron', 'clockwork', 2, '磁暴机兵', '聚怪破盾', 'magnetpulse', '#6ef0ff', '生命 +25%；对带护盾的敌人伤害 +50%', { hp = 0.25 }, { mech = true, vsShield = 0.5 })
    br('titanmech', 'clockwork', 3, '泰坦机甲', '导弹齐射', 'missilebarrage', '#ffd84a', '生命 +40%，攻击 +25%', { hp = 0.4, atk = 0.25 }, { mech = true })
    br('chronoclock', 'clockwork', 3, '时轮主宰', '时间回溯', 'rewind', '#e0b0ff', '生命 +30%；技能能量获取 +25%', { hp = 0.3 }, { mech = true, chargeMul = 1.25 })
    br('sup_clock', 'clockwork', 4, '赤钢天机', '赤钢协议', 'redprotocol', '#ff3b3b', '生命 +50%，攻击 +35%；机械之躯免疫流血、中毒、灼烧；超凡之躯：免疫眩晕和魅惑', { hp = 0.5, atk = 0.35 }, { mech = true, ccImmune = true }, { sup = true, sprite = 'sup_clock' })

    N.CLASS_BRANCHES.treant = A(A('oakguard'), A('thornoak', 'mossheart'), A('ironwood', 'rootweaver'), A('worldtree', 'elderent'))
    N.CLASS_BRANCHES.hawk = A(A('stormhawk'), A('skyhunter', 'galewing'), A('thunderbird', 'bladewing'), A('rocking', 'phoenixhawk'))
    N.CLASS_BRANCHES.clockwork = A(A('gearsoldier'), A('steamknight', 'repairbot'), A('cannonmech', 'magnetron'), A('titanmech', 'chronoclock'))
    N.SUPER_OF.treant = 'sup_treant'; N.SUPER_OF.hawk = 'sup_hawk'; N.SUPER_OF.clockwork = 'sup_clock'

    local P = N.BRPAL
    P.rendtiger = { a = '#b8402a', A = '#ff9a5a', w = '#ffe2b8' }
    P.guardbear = { b = '#3a5a7a', B = '#8ab4dc' }
    P.parasite = { a = '#6a8a1a', A = '#c4f05a', r = '#3a5a1a', z = '#5a7a2a', Z = '#a8d86a' }
    P.purebloom = { a = '#bcd8ee', A = '#ffffff', b = '#7ab0d8' }
    P.oakguard = { z = '#5a8a2a', Z = '#9bc45a' }
    P.thornoak = { z = '#2f7a34', Z = '#4fbf4a', y = '#ff6a8a' }
    P.mossheart = { z = '#6fbf5a', Z = '#c4f0a0', b = '#5a6a3a', B = '#8a9a5a' }
    P.ironwood = { z = '#8a7a62', Z = '#c9b08a', b = '#4a4a5a', B = '#8d9ab2' }
    P.rootweaver = { z = '#2a5a2a', Z = '#3f9a46', b = '#4a2f1b', B = '#7a5233' }
    P.worldtree = { z = '#7fe0c0', Z = '#e6fff4', y = '#ffe14a' }
    P.elderent = { z = '#c8900f', Z = '#ffe680', b = '#5a3a22', B = '#8a5a3a' }
    P.stormhawk = { a = '#25807c', A = '#73d8c8' }
    P.skyhunter = { a = '#8a5a2b', A = '#e2b33c', O = '#ffe14a' }
    P.galewing = { a = '#9fc8e8', A = '#ffffff' }
    P.thunderbird = { a = '#c8900f', A = '#ffe14a', g = '#ffffff' }
    P.bladewing = { a = '#7a1f2b', A = '#d8433a' }
    P.rocking = { a = '#283a7c', A = '#ffe14a', O = '#6ef0ff' }
    P.phoenixhawk = { a = '#d8433a', A = '#ff8a2a', g = '#ffe14a' }
    P.gearsoldier = { g = '#c8900f', y = '#ffe680' }
    P.steamknight = { h = '#5a6a7a', H = '#c9d2e0', a = '#ff8a2a', A = '#ffe14a' }
    P.repairbot = { h = '#3f7a4a', H = '#9be36b', a = '#ffffff', A = '#8fe07a' }
    P.cannonmech = { h = '#6b4527', H = '#c08a5a', a = '#ff5a2a', A = '#ffb04a' }
    P.magnetron = { h = '#2a5a6a', H = '#7fd0e0', a = '#6ef0ff', A = '#ffffff' }
    P.titanmech = { h = '#8a6a1a', H = '#ffd84a', a = '#d8433a', A = '#ff8a6a' }
    P.chronoclock = { h = '#4a3a7a', H = '#b48cf0', a = '#6ef0c0', A = '#ffffff' }
    for _, k in ipairs({ 'sup_treant', 'sup_hawk', 'sup_clock' }) do P[k] = SUP end

    -- 所有旧强化项原序保留，仅追加三个新兵种各自的生命 / 攻击强化。
    N.UPG_TABS:push(A('machine', '机械', 'sym_clock'))
    for _, entry in ipairs({ { 'treant', 'plant' }, { 'hawk', 'animal' }, { 'clockwork', 'machine' } }) do
        local cls, tab = entry[1], entry[2]
        for _, stat in ipairs({ 'hp', 'atk' }) do
            local label = stat == 'hp' and '生命' or '攻击'
            N.UPG:push({ id = stat .. '_' .. cls, tab = tab, cls = cls, stat = stat, name = N.CLASSES[cls].name .. label, icon = cls,
                max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01,
                note = '只强化' .. N.CLASSES[cls].name .. '（含它的所有转职、晋升与超凡形态）的' .. label .. '，每级 +1%' })
        end
    end
end
