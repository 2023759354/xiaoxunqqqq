-- ============================================================================
-- 第十二次更新：十三个超凡角色重做（形象 + 技能 + 被动 + 专属光效配色）
--  * 形象：按名字重新设计的 20×20 新图（data_spr_ext4.lua，键名 sx_兵种），不再是同一套血色换皮
--  * 技能：每个超凡角色一个贴合本兵种玩法的新技能（剑阵嘲讽、空中扇射、血月坠击、连扑猎杀……）
--  * 光效：超凡的描边、脚下光圈、余烬、降世特效改用各自的主题色，外圈保留一道暗红作为超凡标识
-- 技能和机制的实现在 skills_sup.lua；由 logic.lua 在合并完前几次更新的数据之后调用
-- ============================================================================
return function(N)
    local X = require("game.data_spr_ext4")
    for k, v in pairs(X.SPR) do N.SPR[k] = v end
    for k, r in pairs(X.RIG) do N.WEAPON_RIG[k] = r end
    for k, r in pairs(X.BOW) do N.BOW_RIG[k] = r end
    -- 血根古神的根须巨槌（旧图，保留定义以兼容）：先高举过头，再朝前下方砸地
    N.WEAPON_MOVE.rootmaul = { w = -110, h = 70 }
    -- 第十五次更新：古树卫士各转职的树枝手臂 / 血根古神的根爪（不持武器）
    -- limb：手臂抡到头顶后方，再朝前方砸出；rootclaw：根爪高举过头，再朝前下方抓地
    N.WEAPON_MOVE.limb = { w = -100, h = 25 }
    N.WEAPON_MOVE.rootclaw = { w = -115, h = 30 }

    -- ---------- 新技能 ----------
    local SK = {
        emperorblades = { '皇剑轮舞', 30, '召出 6 柄赤魇幻剑环绕自身 5 秒，并嘲讽附近的敌人，期间受到的伤害 -30%；幻剑每 0.5 秒斩击身边的敌人（45% 伤害），结束时依次射向敌人，每柄 130% 伤害并眩晕 0.5 秒（首领减半）' },
        lunarvolley = { '赤月连珠', 30, '跃上半空拉满月弓，向前方扇形射出 3 支赤月巨箭：每支贯穿直线上的所有敌人，造成 220% 伤害并留下月痕（5 秒内受到的伤害 +25%）；跃起期间不会被攻击' },
        moonfall = { '血月坠落', 34, '召唤血月砸向敌群中心（0.9 秒后落地）：范围内的敌人受到 320% 伤害并眩晕 1 秒（首领减半）；血月碎成 5 块飞向敌人，每块 80% 伤害并灼烧 3 秒' },
        bloodhunt = { '血煞猎杀', 28, '进入 6 秒猎杀状态（攻速翻倍），立刻扑向生命比例最低的敌人：造成 260% 伤害、必定暴击并流血 4 秒；猎杀状态下每击杀一个敌人，就立刻扑向下一个（200% 必暴，每次释放最多连扑 3 次）' },
        moltenarmor = { '熔铠反噬', 30, '捶胸怒吼，嘲讽附近所有敌人，熔铠灼烧 5 秒：期间受到的伤害 -50%，并把受到的伤害积蓄成热量；结束时熔铠爆裂，对周围敌人造成 150% 攻击 + 50% 积蓄伤害，眩晕 1.5 秒（首领减半），并留下 3 秒熔岩地面' },
        souldevour = { '噬魂', 32, '张开巨口抽取全场敌人的魂魄：每个敌人受到 120% 伤害（中毒的敌人 180%）并叠加 2 层剧毒，魂魄飞回为全队回复造成伤害的 30%；随后一口吞掉生命低于 35% 的非首领敌人，没有的话改为咬住生命比例最低的敌人，造成 250% 伤害' },
        solarcrown = { '日冕天轮', 32, '解除全队眩晕，在头顶升起一轮赤阳，持续 6 秒：每秒为全队回复 5% 最大生命，并降下 2 道日光灼射随机敌人（110% 伤害并灼烧 2 秒）；赤阳落下时全队获得 15% 最大生命的护盾' },
        rootsiphon = { '古神汲根', 32, '血色根须钻向全场敌人，根植 3 秒（首领减半）并连上根脉：3 秒内每 0.5 秒抽取每个敌人 35% 伤害的生命，汲取量的 50% 回复给自己（满血时转给生命最低的队友）；释放时自身获得 20% 最大生命的护盾' },
        thunderwing = { '赤雷天翔', 32, '振翅冲上高空盘旋 2.4 秒（不会被攻击），召下 12 道赤雷劈向随机敌人：每道 90% 伤害并弹射到附近另一个敌人（50%），30% 几率麻痹 0.5 秒' },
        railcannon = { '天机轨道炮', 32, '架起轨道炮蓄能 0.8 秒，然后朝目标方向轰出贯穿全场的赤色光束：直线上的敌人受到 400% 伤害、护盾被击碎并被击退；散热的蒸汽让身边的队友过载 3 秒（攻速 +60%）' },
        crimsonaria = { '血咏终章', 32, '拉响魔琴奏出四拍终章：前三拍每拍对周围敌人造成 60% 伤害，并让范围内的队友攻击 +10%（可叠 3 层，持续 6 秒）、技能能量 +8；第四拍高潮对周围敌人造成 180% 伤害并震慑 1 秒（首领减半），全队狂热 3 秒' },
        infernosweep = { '炼狱龙息', 34, '腾空掠过敌阵，沿途向下喷吐炼狱龙焰：每 0.15 秒对身下的敌人造成 40% 伤害并灼烧，身后留下一路持续 4 秒的炼狱火（每 0.5 秒 25% 伤害）；飞行中不会被攻击' },
        frostcoffin = { '霜狱碎魂', 34, '把全场敌人封进血霜冰棺（冻结 1.8 秒，首领减半），我方全队获得 15% 最大生命的护盾；1.2 秒后冰棺从最近的敌人开始依次连锁碎裂：每次碎裂造成 220% 伤害（生命低于 50% 的敌人 +50%）并减速 40%' },
    }
    for k, v in pairs(SK) do N.SKILLS[k] = { name = v[1], charge = v[2], desc = v[3] } end

    -- ---------- 主题色：描边 glow、外圈 halo（统一暗红，超凡标识）、脚下光圈、余烬 ----------
    -- ember：rise 往上飘 / fall 往下落 / snow 飘雪 / spark 闪烁 / note 音符
    local HALO = '#b80f28'
    N.SUP_THEME = {
        sup_warrior = { glow = '#ffd84a', halo = HALO, c1 = '#ff3b3b', c2 = '#ffe680', embers = { '#ffd84a', '#ff3b3b', '#fff2ea' }, ember = 'rise' },
        sup_archer = { glow = '#ffe0ec', halo = HALO, c1 = '#ff3b3b', c2 = '#ffe0ec', embers = { '#ffe0ec', '#ff8e6a', '#ffffff' }, ember = 'spark' },
        sup_mage = { glow = '#c06bff', halo = HALO, c1 = '#8f4bc4', c2 = '#ff3b3b', embers = { '#c06bff', '#ff3b3b', '#5a2a7a' }, ember = 'rise' },
        sup_tiger = { glow = '#ff3434', halo = '#7a0a1a', c1 = '#ff3434', c2 = '#ff8a2a', embers = { '#ff3434', '#ff8a2a', '#ffd84a' }, ember = 'rise' },
        sup_bear = { glow = '#ff6a2a', halo = HALO, c1 = '#ff6a2a', c2 = '#ffd84a', embers = { '#ff6a2a', '#ffd84a', '#ffffff' }, ember = 'spark' },
        sup_flytrap = { glow = '#7af0e0', halo = HALO, c1 = '#7af0e0', c2 = '#e0588a', embers = { '#9af0e8', '#d8fff8', '#e0588a' }, ember = 'rise' },
        sup_sunflower = { glow = '#ff9a3a', halo = HALO, c1 = '#ffd84a', c2 = '#ff6a2a', embers = { '#ffe680', '#ffd84a', '#ff8a2a' }, ember = 'rise' },
        sup_treant = { glow = '#9be36b', halo = HALO, c1 = '#ff3b3b', c2 = '#9be36b', embers = { '#ff3b3b', '#b3142a', '#9be36b' }, ember = 'fall' },
        sup_hawk = { glow = '#fff07a', halo = HALO, c1 = '#ffe14a', c2 = '#ff3b3b', embers = { '#ffe14a', '#ffffff', '#ff3b3b' }, ember = 'spark' },
        sup_clock = { glow = '#6ef0ff', halo = HALO, c1 = '#6ef0ff', c2 = '#ffe680', embers = { '#6ef0ff', '#ffe680', '#ffffff' }, ember = 'spark' },
        sup_bard = { glow = '#ff6ad5', halo = HALO, c1 = '#ff6ad5', c2 = '#ff3b3b', embers = { '#ff6ad5', '#ff3b3b', '#ffe0f4' }, ember = 'note' },
        sup_whelp = { glow = '#ffb03a', halo = HALO, c1 = '#ff6a2a', c2 = '#ffd84a', embers = { '#ff6a2a', '#ffb03a', '#ffd84a' }, ember = 'rise' },
        sup_frost = { glow = '#bff4ff', halo = HALO, c1 = '#bff4ff', c2 = '#ff3b3b', embers = { '#ffffff', '#bff4ff', '#ff6a7a' }, ember = 'snow' },
    }

    -- ---------- 超凡路线：形象、调色板、技能、被动 ----------
    local SUP = {
        warrior = { role = '剑阵嘲讽', skill = 'emperorblades',
            passive = '生命 +40%，攻击 +30%，吸血 10%；每第 3 次普攻挥出一道血色剑气，贯穿前方直线上的敌人（80% 伤害）；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.4, atk = 0.3, leech = 0.1 }, fx = { swordWave = 0.8, ccImmune = true } },
        archer = { role = '月弓贯射', skill = 'lunarvolley',
            passive = '攻击 +30%，暴击率 +25%，射程 +20；每支箭命中后弹射到附近另一个敌人，造成 60% 伤害；超凡之躯：免疫眩晕和魅惑',
            mods = { atk = 0.3, crit = 0.25, range = 20 }, fx = { ricochet = 0.6, ccImmune = true } },
        mage = { role = '血月坠击', skill = 'moonfall',
            passive = '生命 +35%，攻击 +35%；普攻附带灼烧，2 秒内额外造成 50% 伤害；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.35, atk = 0.35, burn = true }, fx = { ccImmune = true } },
        tiger = { role = '连扑猎杀', skill = 'bloodhunt',
            passive = '攻击 +25%，攻速 +20%，暴击率 +20%；普攻 40% 几率使目标流血 3 秒；击杀敌人回复 15% 生命；超凡之躯：免疫眩晕和魅惑',
            mods = { atk = 0.25, spd = 0.2, crit = 0.2 }, fx = { killHeal = 0.15, bleedHit = 0.4, ccImmune = true } },
        bear = { role = '熔铠反噬', skill = 'moltenarmor',
            passive = '生命 +60%，受到的伤害 -25%；被近战攻击时反弹 30% 伤害，被远程普攻命中时反弹 15%；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.6, dr = 0.25 }, fx = { thorns = 0.3, ccImmune = true } },
        flytrap = { role = '噬魂吞杀', skill = 'souldevour', proj = 'soulorb',
            passive = '生命 +30%，攻击 +30%；普攻叠加 3 层剧毒；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.3, atk = 0.3 }, fx = { poisonHit = 3, ccImmune = true } },
        sunflower = { role = '赤阳天轮', skill = 'solarcrown',
            passive = '生命 +35%；每秒回复 2% 最大生命；光环：全队受到的伤害 -12%；涅槃：每场战斗第一个阵亡的队友（包括自己）2 秒后浴火重生，恢复 50% 生命；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.35 }, fx = { regen = 0.02, drAura = 0.12, phoenix = 0.5, ccImmune = true } },
        treant = { role = '根脉汲取', skill = 'rootsiphon',
            passive = '生命 +60%，受到的伤害 -20%；每秒回复 2% 最大生命；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.6, dr = 0.2 }, fx = { regen = 0.02, ccImmune = true } },
        hawk = { role = '高空雷击', skill = 'thunderwing',
            passive = '攻击 +35%，暴击率 +20%；闪避 30%；普攻 40% 几率弹射闪电；超凡之躯：免疫眩晕和魅惑',
            mods = { atk = 0.35, crit = 0.2, chainHit = 0.4 }, fx = { dodge = 0.3, ccImmune = true } },
        clockwork = { role = '轨道光炮', skill = 'railcannon',
            passive = '生命 +50%，攻击 +35%；机械之躯免疫流血、中毒、灼烧；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.5, atk = 0.35 }, fx = { mech = true, ccImmune = true } },
        bard = { role = '魔音四拍', skill = 'crimsonaria',
            passive = '生命 +50%，攻击 +40%；光环：全队技能能量获取 +12%；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.5, atk = 0.4 }, fx = { chargeAura = 0.12, ccImmune = true } },
        whelp = { role = '掠空炼狱', skill = 'infernosweep',
            passive = '生命 +55%，攻击 +40%；普攻附带灼烧；龙鳞减伤 20%；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.55, atk = 0.4, burn = true }, fx = { dragonScale = 0.2, ccImmune = true } },
        frostling = { role = '冰棺连碎', skill = 'frostcoffin',
            passive = '生命 +55%，攻击 +40%；普攻减速 30%；超凡之躯：免疫眩晕和魅惑',
            mods = { hp = 0.55, atk = 0.4, slowHit = 0.3 }, fx = { elem = true, ccImmune = true } },
    }
    for cls, d in pairs(SUP) do
        local b = N.SUPER_OF[cls]
        local B = N.BRANCHES[b]
        if B then
            B.sprite = 'sx_' .. cls
            N.BRPAL[b] = X.PAL['sup_' .. cls]
            B.role, B.skill, B.passive, B.mods, B.fx = d.role, d.skill, d.passive, d.mods, d.fx
            if d.proj then B.proj = d.proj end
            B.aura = N.SUP_THEME[b].glow -- 出手特效、技能弹道的主题色
        end
    end
end
