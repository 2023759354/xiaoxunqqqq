-- 完整移植原版 HTML 数据，所有数字数组索引从 1 开始。
-- 像素字符串与配色逐字保留，不执行浏览器或 DOM 代码。
---@class LegionData
---@field CLASSES table<string, table>
---@field BRANCHES table<string, table>
---@field ENEMIES table<string, table>
---@field SKILLS table<string, table>
---@field CHAPTERS table[]
---@field DIFFS table[]
---@field CLASS_BRANCHES table<string, table>
---@field SPR table<string, string[]>
---@field PAL table<string, string>
---@field BRPAL table<string, table>
---@field SUP_PAL table<string, string>
---@field TIER_PAL table<string, table>
---@field QUAL table[]
---@field AFFIXES table[]
---@field UPG table[]
---@field DIFFS1 table[]
---@field SOUL_CH number[]
---@field SOUL_DIFF number[]
---@field STAR_MULT number[]
---@field CHEAP_EVERY number[]
local Data = {}

-- 原版完整数据
Data.AW, Data.AH, Data.FIELD_H = 256, 176, 142
Data.FORM_N, Data.BENCH_N = 12, 8
Data.SPIN_COST, Data.START_GOLD, Data.START_LIVES = 3, 12, 3
Data.STAR_MULT, Data.STAR_PTS = { 1, 2.1, 4.6 }, { 0, 4, 16 }
Data.STAR_COLOR = { "#d8d2c4", "#cfe3ff", "#ffd84a" }
Data.SQUAD_N, Data.SQUAD_SUM = 3, 77
Data.DEFAULT_SQUAD = { "warrior", "archer", "mage" }
Data.CLASS_KEYS = { "warrior", "archer", "mage", "tiger", "bear", "flytrap", "sunflower" }
Data.KIND_NAME = { human = "人类", animal = "动物", plant = "植物" }
Data.SYM_CLASS = { W = "warrior", A = "archer", M = "mage", T = "tiger", B = "bear", F = "flytrap", U = "sunflower" }
Data.SYM_SPRITE = { W = "sym_sword", A = "sym_bow", M = "sym_staff", T = "sym_tiger", B = "sym_bear", F = "sym_flytrap", U = "sym_sunflower", S = "sym_star" }
Data.SYM_COLOR = { W = "#8fb8ff", A = "#8fe07a", M = "#d2a6ff", T = "#ffa53a", B = "#c9955a", F = "#ff7a8a", U = "#ffe14a", S = "#ffffff" }
Data.CLASS_COLOR = { warrior = "#8fb8ff", archer = "#8fe07a", mage = "#d2a6ff", tiger = "#ffa53a", bear = "#c9955a", flytrap = "#ff7a8a", sunflower = "#ffe14a" }
Data.SYM_WEIGHT = { W = 28, A = 26, M = 23, T = 26, B = 26, F = 24, U = 24, S = 10 }
Data.LUCK_BONUS = 6
Data.LINES = { {1,2,3}, {4,5,6}, {7,8,9}, {1,4,7}, {2,5,8}, {3,6,9}, {1,5,9}, {3,5,7} }
Data.Q_MAX, Data.Q_SUP = 4, 5
Data.Q_ODDS = { 68, 24, 7, 1 }
Data.ELITE_HP, Data.ELITE_ATK = 1.6, 1.3
Data.CLASS_SKILL = { warrior = "bash", archer = "triple", mage = "arcane", tiger = "pounce", bear = "roar", flytrap = "spore", sunflower = "sunburst" }
Data.CLASSES = {
    warrior = { name = "战士", sprite = "warrior", hp = 120, atk = 11, cd = 0.9, range = 8, speed = 24, r = 5, kind = "human", note = "均衡的近战，技能眩晕" },
    archer = { name = "射手", sprite = "archer", hp = 62, atk = 10, cd = 0.8, range = 70, speed = 20, r = 5, proj = "arrow", kind = "human", note = "远程单体输出" },
    mage = { name = "法师", sprite = "mage", hp = 56, atk = 13, cd = 1.5, range = 60, speed = 18, r = 5, proj = "orb", splash = 16, kind = "human", note = "远程范围伤害" },
    tiger = { name = "猛虎", sprite = "tiger", kind = "animal", note = "速度很快的近战刺客", hp = 88, atk = 13, cd = 0.85, range = 8, speed = 30, r = 5 },
    bear = { name = "巨熊", sprite = "bear", kind = "animal", note = "血最厚的近战坦克", hp = 150, atk = 9, cd = 1.2, range = 8, speed = 17, r = 6 },
    flytrap = { name = "食人花", sprite = "flytrap", kind = "plant", note = "普攻附带剧毒", hp = 60, atk = 9, cd = 1, range = 56, speed = 12, r = 5, proj = "parrow", fx = { poisonHit = 1 } },
    sunflower = { name = "向日葵", sprite = "sunflower", kind = "plant", note = "普攻治疗生命最低的队友", hp = 54, atk = 8, cd = 1.3, range = 62, speed = 12, r = 5, proj = "holy", fx = { healHit = 0.5 } },
}
Data.CLASS_BRANCHES = {
    warrior = { { "berserker" }, { "banner", "avenger", "paladin" }, { "undying", "conqueror", "dragoon" }, { "titan", "seraph", "blademaster" } },
    archer = { { "ranger" }, { "venom", "hunter", "windrunner" }, { "arbalist", "engineer", "beastmaster" }, { "starfall", "shadow", "sniper" } },
    mage = { { "pyro" }, { "cleric", "hexer", "necro" }, { "chrono", "voidcaller", "frost" }, { "archmage", "lich", "storm" } },
    tiger = { { "claw" }, { "bloodfang", "shadowcat" }, { "whitetiger", "hungrytiger" }, { "tigerspirit", "sabre" } },
    bear = { { "brute" }, { "ironback", "frenzybear" }, { "hibernator", "mountain" }, { "polarking", "bearking" } },
    flytrap = { { "vine" }, { "strangler", "plaguebloom" }, { "corroder", "mother" }, { "pandemic", "devourer" } },
    sunflower = { { "sunny" }, { "photosyn", "rose" }, { "moonbloom", "lifebloom" }, { "sungod", "solar" } },
}
Data.SUPER_OF = { warrior = "sup_warrior", archer = "sup_archer", mage = "sup_mage", tiger = "sup_tiger", bear = "sup_bear", flytrap = "sup_flytrap", sunflower = "sup_sunflower" }
Data.QUAL = {
    { name = "普通", color = "#d8d2c4", base = 1, awaken = 1.3, affix = 0, call = "" },
    { name = "稀有", color = "#5fb4ff", base = 1.15, awaken = 1.45, affix = 0.2, call = "稀有召唤" },
    { name = "史诗", color = "#c77dff", base = 1.3, awaken = 1.6, affix = 0.45, call = "史诗召唤" },
    { name = "传说", color = "#ffa53a", base = 1.5, awaken = 1.8, affix = 0.7, call = "传说降临" },
    { name = "超凡", color = "#ff3b3b", base = 1.75, awaken = 2.1, affix = 0.85, call = "超凡降世" },
}
Data.AFFIXES = {
    { id = "atk", name = "强攻", min = 10, max = 35 },
    { id = "hp", name = "坚韧", min = 15, max = 45 },
    { id = "spd", name = "迅捷", min = 10, max = 30 },
    { id = "crit", name = "致命", min = 10, max = 30 },
    { id = "leech", name = "嗜血", min = 8, max = 20 },
}
Data.AFFIX_GRADE = { {name="下品",color="#d8d2c4"}, {name="中品",color="#8fe07a"}, {name="上品",color="#7cc0ff"}, {name="极品",color="#e09cff"} }
Data.TIER_PAL = {
    warrior = { {a="#3b6fd1",A="#78a8f2"}, {a="#2a56c9",A="#e4f2ff"}, {a="#c8900f",A="#ffe680"} },
    archer = { {a="#3f9a46",A="#7fd36a"}, {a="#2c8a3c",A="#e6ffd6"}, {a="#c8900f",A="#ffe680"} },
    mage = { {a="#7b45c8",A="#b48cf0"}, {a="#6a33c9",A="#f3e2ff"}, {a="#c8900f",A="#ffe680"} },
    tiger = { {a="#d9742a",A="#f2a65a"}, {a="#c65a1a",A="#ffe2b8"}, {a="#c8900f",A="#ffe680"} },
    bear = { {b="#6b4527",B="#9b6a3c"}, {b="#5a3a22",B="#e8cfae"}, {b="#c8900f",B="#ffe680"} },
    flytrap = { {a="#c4405a",A="#ff7f9a"}, {a="#a82a6a",A="#ffc0e0"}, {a="#c8900f",A="#ffe680"} },
    sunflower = { {a="#e0a82a",A="#ffe14a"}, {a="#f08a1a",A="#fff08a"}, {a="#c8900f",A="#ffe680"} },
}
Data.BRANCHES = {
    berserker = { cls = "warrior", name = "狂战士", skill = "whirlwind", aura = "#ff6a4a", passive = "攻速 +30%；生命低于一半时额外吸血 20%", mods = { spd = 0.3, berserk = true }, role = "吸血群攻", q = 1 },
    paladin = { cls = "warrior", name = "圣骑士", skill = "aegis", aura = "#fff3b0", passive = "生命 +40%，受到的伤害 -15%，攻击 -15%", mods = { hp = 0.4, atk = -0.15, dr = 0.15 }, role = "护盾坦克", q = 2 },
    sniper = { cls = "archer", name = "神射手", skill = "snipe", aura = "#6ef0ff", passive = "射程 +40，暴击率 +20%，攻击 +20%；开战时能量全满，第一枪就是致命狙击", mods = { range = 40, crit = 0.2, atk = 0.2, fullEnergy = true }, role = "远程狙杀", q = 4 },
    ranger = { cls = "archer", name = "游侠", skill = "volley", aura = "#9be36b", passive = "攻速 +20%；普攻有 30% 几率多射一箭", mods = { spd = 0.2, extra = 0.3 }, role = "高速连射", q = 1 },
    pyro = { cls = "mage", name = "炎术师", skill = "meteor", aura = "#ff8a2a", passive = "普攻附带灼烧，2 秒内额外造成 50% 伤害", mods = { burn = true }, role = "灼烧范围", q = 1 },
    necro = { cls = "mage", name = "暗魔导", skill = "raise", aura = "#c06bff", passive = "吸血 15%，生命 +20%", mods = { leech = 0.15, hp = 0.2 }, role = "召唤亡骨", q = 2 },
    dragoon = { cls = "warrior", name = "龙骑士", role = "突袭后排", skill = "leap", aura = "#7fe0c0", passive = "生命 +25%，移动速度 +50%；开战时能量全满，第一时间跃向后排", mods = { hp = 0.25, move = 0.5, fullEnergy = true }, q = 3 },
    blademaster = { cls = "warrior", name = "剑圣", role = "单体爆发", skill = "issen", aura = "#ffffff", passive = "暴击率 +30%，攻速 +15%，暴击伤害从 200% 提高到 250%；闪避 20% 的攻击", mods = { crit = 0.3, spd = 0.15, critMul = 2.5 }, fx = { dodge = 0.2 }, q = 4 },
    windrunner = { cls = "archer", name = "风行者", role = "直线穿透", skill = "pierce", aura = "#9ff6ff", passive = "射程 +20，攻速 +15%", mods = { range = 20, spd = 0.15 }, q = 2 },
    beastmaster = { cls = "archer", name = "驯兽师", role = "召唤战狼", skill = "wolf", aura = "#c9cbd6", passive = "生命 +20%，攻击 +10%；开战时能量全满，第一箭就召唤战狼", mods = { hp = 0.2, atk = 0.1, fullEnergy = true }, q = 3 },
    frost = { cls = "mage", name = "冰霜术士", role = "冻结控制", skill = "frostnova", aura = "#bff4ff", proj = "frost", passive = "普攻使目标减速 35%，持续 2 秒", mods = { slowHit = 0.35 }, q = 3 },
    storm = { cls = "mage", name = "雷术士", role = "弹射群伤", skill = "chain", aura = "#ffe14a", proj = "spark", passive = "生命 +25%，攻击 +20%；普攻有 50% 几率弹射闪电，对附近另一个敌人造成 60% 伤害", mods = { hp = 0.25, atk = 0.2, chainHit = 0.5 }, q = 4 },
    banner = { cls = "warrior", name = "战旗手", role = "全队增益", skill = "warcry", aura = "#ffb04a", sprite = "warrior", passive = "生命 +20%；开战时全队狂热 2 秒（攻速翻倍）", mods = { hp = 0.2 }, fx = { openHaste = 2 }, q = 2 },
    avenger = { cls = "warrior", name = "复仇者", role = "反伤坦克", skill = "vengeance", aura = "#c06bff", sprite = "berserker", passive = "生命 +40%；被近战攻击时反弹 50% 伤害", mods = { hp = 0.4 }, fx = { thorns = 0.5 }, q = 2 },
    undying = { cls = "warrior", name = "不灭战魂", role = "死而复生", skill = "shockwave", aura = "#6ef0ff", sprite = "blademaster", passive = "生命 +30%；每场一次：受到致命伤害时不倒，回复 50% 生命并无敌 2.5 秒", mods = { hp = 0.3 }, fx = { undying = true }, q = 3 },
    conqueror = { cls = "warrior", name = "征服者", role = "越杀越强", skill = "behead", aura = "#ff4a3a", sprite = "dragoon", passive = "生命 +25%，攻击 +15%；每击杀一个敌人，本场攻击 +15%、攻速 +10% 并回复 15% 生命，最多叠 8 层", mods = { hp = 0.25, atk = 0.15 }, fx = { killStack = true }, q = 3 },
    titan = { cls = "warrior", name = "泰坦", role = "巨人化身", skill = "giant", aura = "#ffa53a", sprite = "titan", passive = "生命 +40%，受到的伤害 -15%", mods = { hp = 0.4, dr = 0.15 }, q = 4 },
    seraph = { cls = "warrior", name = "炽天使", role = "复活守护", skill = "sanctuary", aura = "#fff3b0", sprite = "seraph", passive = "生命 +25%；光环：全队受到的伤害 -12%", mods = { hp = 0.25 }, fx = { drAura = 0.12 }, q = 4 },
    venom = { cls = "archer", name = "毒箭手", role = "叠毒", skill = "venomburst", aura = "#9be36b", sprite = "archer", proj = "parrow", passive = "普攻附加 1 层剧毒：每层每秒造成 15% 攻击，持续 4 秒，最多 8 层", mods = {}, fx = { poisonHit = 1 }, q = 2 },
    hunter = { cls = "archer", name = "猎魔人", role = "斩杀残血", skill = "hunt", aura = "#ff8a5a", sprite = "sniper", passive = "攻击 +15%；对生命低于 50% 的敌人伤害 +70%", mods = { atk = 0.15 }, fx = { execBonus = 0.7 }, q = 2 },
    arbalist = { cls = "archer", name = "连弩手", role = "弹射连射", skill = "barrage", aura = "#c9cbd6", sprite = "ranger", passive = "攻速 +15%；每支箭命中后弹射到附近另一个敌人，造成 60% 伤害", mods = { spd = 0.15 }, fx = { ricochet = 0.6 }, q = 3 },
    engineer = { cls = "archer", name = "机关师", role = "布置炮塔", skill = "turret", aura = "#ffb04a", sprite = "archer", passive = "生命 +20%；开战时立刻部署 1 座弩炮塔", mods = { hp = 0.2 }, fx = { openTurret = true }, q = 3 },
    starfall = { cls = "archer", name = "星辰射手", role = "全场打击", skill = "starfall", aura = "#ffe680", sprite = "windrunner", passive = "暴击率 +20%；每次暴击回复 5 能量", mods = { crit = 0.2 }, fx = { critEnergy = 5 }, q = 4 },
    shadow = { cls = "archer", name = "影舞者", role = "分身闪避", skill = "shadowclone", aura = "#c06bff", sprite = "sniper", passive = "闪避 35% 的攻击；攻击 +15%，攻速 +15%", mods = { atk = 0.15, spd = 0.15 }, fx = { dodge = 0.35 }, q = 4 },
    cleric = { cls = "mage", name = "圣疗师", role = "治疗", skill = "heal", aura = "#fff3b0", sprite = "mage", proj = "holy", passive = "生命 +20%；普攻同时治疗生命比例最低的队友，治疗量为伤害的 90%", mods = { hp = 0.2 }, fx = { healHit = 0.9 }, q = 2 },
    hexer = { cls = "mage", name = "咒术师", role = "诅咒削弱", skill = "hex", aura = "#9be36b", sprite = "necro", proj = "dark", passive = "普攻使目标受到的伤害 +12%，持续 3 秒", mods = {}, fx = { curseHit = 0.12 }, q = 2 },
    chrono = { cls = "mage", name = "时空法师", role = "时间控制", skill = "timestop", aura = "#6ef0c0", sprite = "frost", passive = "技能能量获取 +25%", mods = {}, fx = { chargeMul = 1.25 }, q = 3 },
    voidcaller = { cls = "mage", name = "虚空术士", role = "黑洞聚怪", skill = "blackhole", aura = "#8f4bc4", sprite = "storm", proj = "dark", passive = "攻击 +10%，射程 +10", mods = { atk = 0.1, range = 10 }, q = 3 },
    archmage = { cls = "mage", name = "大魔导师", role = "元素轮转", skill = "elements", aura = "#ffd84a", sprite = "pyro", proj = "prism", passive = "生命 +40%，攻击 +25%；普攻随机附带灼烧、减速或弹射闪电", mods = { hp = 0.4, atk = 0.25 }, fx = { elemHit = true }, q = 4 },
    lich = { cls = "mage", name = "巫妖王", role = "亡者大军", skill = "legion", aura = "#6ef0ff", sprite = "necro", proj = "frost", passive = "生命 +40%；敌人阵亡时有 50% 几率复生为你的亡骨仆从（最多 5 个）", mods = { hp = 0.4 }, fx = { deathRaise = 0.5 }, q = 4 },
    claw = { cls = "tiger", name = "利爪", role = "撕裂流血", skill = "rend", aura = "#ffa53a", sprite = "tiger", passive = "攻速 +15%；普攻 25% 几率使目标流血 3 秒", mods = { spd = 0.15 }, fx = { bleedHit = 0.25 }, q = 1 },
    bloodfang = { cls = "tiger", name = "血牙", role = "嗜血猛攻", skill = "pounce", aura = "#ff4a3a", sprite = "tiger", passive = "攻击 +10%，吸血 18%", mods = { atk = 0.1, leech = 0.18 }, q = 2 },
    shadowcat = { cls = "tiger", name = "影豹", role = "闪避突袭", skill = "rend", aura = "#c06bff", sprite = "tiger", passive = "闪避 25% 的攻击；攻速 +10%，移动速度 +30%", mods = { spd = 0.1, move = 0.3 }, fx = { dodge = 0.25 }, q = 2 },
    whitetiger = { cls = "tiger", name = "白虎", role = "暴击刺杀", skill = "ambush", aura = "#ffffff", sprite = "tiger", passive = "暴击率 +25%，暴击伤害从 200% 提高到 250%", mods = { crit = 0.25, critMul = 2.5 }, q = 3 },
    hungrytiger = { cls = "tiger", name = "饿虎", role = "斩杀回血", skill = "pounce", aura = "#ff8a2a", sprite = "tiger", passive = "攻击 +10%；对生命低于 50% 的敌人伤害 +60%；击杀敌人回复 20% 生命", mods = { atk = 0.1 }, fx = { execBonus = 0.6, killHeal = 0.2 }, q = 3 },
    tigerspirit = { cls = "tiger", name = "虎魄", role = "狂化连击", skill = "tigerroar", aura = "#6ef0c0", sprite = "tiger", passive = "攻击 +25%，暴击率 +15%", mods = { atk = 0.25, crit = 0.15 }, q = 4 },
    sabre = { cls = "tiger", name = "剑齿王", role = "流血斩首", skill = "behead", aura = "#ffd84a", sprite = "tiger", passive = "生命 +30%，攻击 +15%；普攻 30% 几率使目标流血 3 秒", mods = { hp = 0.3, atk = 0.15 }, fx = { bleedHit = 0.3 }, q = 4 },
    brute = { cls = "bear", name = "蛮熊", role = "近战坦克", skill = "quake", aura = "#c08a5a", sprite = "bear", passive = "生命 +25%，受到的伤害 -10%", mods = { hp = 0.25, dr = 0.1 }, q = 1 },
    ironback = { cls = "bear", name = "铁背熊", role = "嘲讽坦克", skill = "roar", aura = "#8d9ab2", sprite = "bear", passive = "生命 +40%，受到的伤害 -20%，攻击 -20%", mods = { hp = 0.4, dr = 0.2, atk = -0.2 }, q = 2 },
    frenzybear = { cls = "bear", name = "狂爪熊", role = "越战越勇", skill = "quake", aura = "#ff6a4a", sprite = "bear", passive = "攻击 +20%，攻速 +15%；生命低于一半时额外吸血 20%", mods = { atk = 0.2, spd = 0.15, berserk = true }, q = 2 },
    hibernator = { cls = "bear", name = "冬眠熊", role = "护盾回血", skill = "hibernate", aura = "#6a8ad8", sprite = "bear", passive = "生命 +40%；每秒回复 1.5% 最大生命", mods = { hp = 0.4 }, fx = { regen = 0.015 }, q = 3 },
    mountain = { cls = "bear", name = "山岳熊", role = "反伤震退", skill = "shockwave", aura = "#c9b08a", sprite = "bear", passive = "生命 +30%；被近战攻击时反弹 30% 伤害", mods = { hp = 0.3 }, fx = { thorns = 0.3 }, q = 3 },
    polarking = { cls = "bear", name = "极北霸熊", role = "冰霜控场", skill = "frostroar", aura = "#bff4ff", sprite = "bear", passive = "生命 +45%，受到的伤害 -15%", mods = { hp = 0.45, dr = 0.15 }, q = 4 },
    bearking = { cls = "bear", name = "熊王", role = "单挑压制", skill = "bearhug", aura = "#ffd84a", sprite = "bear", passive = "生命 +40%，攻击 +25%", mods = { hp = 0.4, atk = 0.25 }, q = 4 },
    vine = { cls = "flytrap", name = "毒藤", role = "叠毒连射", skill = "venomburst", aura = "#9be36b", sprite = "flytrap", passive = "攻速 +20%，射程 +10；普攻叠加 2 层剧毒", mods = { spd = 0.2, range = 10 }, fx = { poisonHit = 2 }, q = 1 },
    strangler = { cls = "flytrap", name = "绞杀藤", role = "缠绕控场", skill = "entangle", aura = "#4fbf4a", sprite = "flytrap", passive = "生命 +25%；普攻附加 1 层剧毒，并使目标减速 25%", mods = { hp = 0.25, slowHit = 0.25 }, q = 2 },
    plaguebloom = { cls = "flytrap", name = "瘟疫花", role = "毒云扩散", skill = "spore", aura = "#c06bff", sprite = "flytrap", passive = "攻击 +15%；普攻叠加 2 层剧毒", mods = { atk = 0.15 }, fx = { poisonHit = 2 }, q = 2 },
    corroder = { cls = "flytrap", name = "腐蚀花", role = "毒爆引爆", skill = "virulence", aura = "#e6ff6a", sprite = "flytrap", passive = "攻速 +15%；普攻叠加 2 层剧毒", mods = { spd = 0.15 }, fx = { poisonHit = 2 }, q = 3 },
    mother = { cls = "flytrap", name = "荆棘母株", role = "播种花苗", skill = "seedling", aura = "#ff7f9a", sprite = "flytrap", passive = "生命 +30%；开战时立刻种下 1 株毒花苗", mods = { hp = 0.3 }, fx = { openSprout = true }, q = 3 },
    pandemic = { cls = "flytrap", name = "万毒之王", role = "全场剧毒", skill = "plague", aura = "#9a5ae0", sprite = "flytrap", passive = "攻击 +20%；普攻叠加 3 层剧毒", mods = { atk = 0.2 }, fx = { poisonHit = 3 }, q = 4 },
    devourer = { cls = "flytrap", name = "噬魂花", role = "吞噬斩杀", skill = "devour", aura = "#ff4a3a", sprite = "flytrap", passive = "生命 +40%，攻击 +20%", mods = { hp = 0.4, atk = 0.2 }, q = 4 },
    sunny = { cls = "sunflower", name = "向阳花", role = "稳定治疗", skill = "heal", aura = "#ffe14a", sprite = "sunflower", passive = "生命 +20%；普攻治疗量提高到伤害的 80%", mods = { hp = 0.2 }, fx = { healHit = 0.8 }, q = 1 },
    photosyn = { cls = "sunflower", name = "光合花", role = "自愈光环", skill = "sunburst", aura = "#9be36b", sprite = "sunflower", passive = "生命 +25%；每秒回复 2% 最大生命；光环：全队受到的伤害 -6%", mods = { hp = 0.25 }, fx = { regen = 0.02, drAura = 0.06 }, q = 2 },
    rose = { cls = "sunflower", name = "荆棘玫瑰", role = "反伤诅咒", skill = "hex", aura = "#ff6a8a", sprite = "sunflower", passive = "生命 +20%；被近战攻击时反弹 40% 伤害；普攻使目标受到的伤害 +10%，持续 3 秒", mods = { hp = 0.2 }, fx = { thorns = 0.4, curseHit = 0.1 }, q = 2 },
    moonbloom = { cls = "sunflower", name = "月光花", role = "群体沉睡", skill = "moonlight", aura = "#e4f2ff", sprite = "sunflower", passive = "生命 +25%；技能能量获取 +25%", mods = { hp = 0.25 }, fx = { chargeMul = 1.25 }, q = 3 },
    lifebloom = { cls = "sunflower", name = "生命之花", role = "持续治疗", skill = "bloom", aura = "#ffd0e6", sprite = "sunflower", passive = "生命 +30%；普攻治疗量提高到伤害的 100%", mods = { hp = 0.3 }, fx = { healHit = 1 }, q = 3 },
    sungod = { cls = "sunflower", name = "太阳花神", role = "复活守护", skill = "sanctuary", aura = "#ffb04a", sprite = "sunflower", passive = "生命 +25%；每秒回复 1.5% 最大生命；光环：全队受到的伤害 -10%", mods = { hp = 0.25 }, fx = { regen = 0.015, drAura = 0.1 }, q = 4 },
    solar = { cls = "sunflower", name = "炎阳花", role = "日耀灼烧", skill = "solarflare", aura = "#ff4a2a", sprite = "sunflower", passive = "攻击 +35%，射程 +10", mods = { atk = 0.35, range = 10 }, q = 4 },
    sup_warrior = { cls = "warrior", sup = true, name = "赤魇剑皇", role = "血刃斩灭", skill = "crimsonmoon", aura = "#ff3b3b", sprite = "sup_warrior", passive = "生命 +40%，攻击 +30%，吸血 15%；超凡之躯：免疫眩晕和魅惑", mods = { hp = 0.4, atk = 0.3, leech = 0.15 }, fx = { ccImmune = true }, q = 5 },
    sup_archer = { cls = "archer", sup = true, name = "赤月弓神", role = "贯穿血矢", skill = "bloodarrow", aura = "#ff3b3b", sprite = "sup_archer", proj = "rarrow", passive = "攻击 +30%，暴击率 +25%，射程 +20；每支箭命中后弹射到附近另一个敌人，造成 60% 伤害；超凡之躯：免疫眩晕和魅惑", mods = { atk = 0.3, crit = 0.25, range = 20 }, fx = { ricochet = 0.6, ccImmune = true }, q = 5 },
    sup_mage = { cls = "mage", sup = true, name = "血月魔尊", role = "血月审判", skill = "bloodmoon", aura = "#ff3b3b", sprite = "sup_mage", proj = "bloodorb", passive = "生命 +35%，攻击 +35%；普攻附带灼烧，2 秒内额外造成 50% 伤害；超凡之躯：免疫眩晕和魅惑", mods = { hp = 0.35, atk = 0.35, burn = true }, fx = { ccImmune = true }, q = 5 },
    sup_tiger = { cls = "tiger", sup = true, name = "血煞魔虎", role = "连环猎杀", skill = "bloodrush", aura = "#ff3b3b", sprite = "sup_tiger", passive = "攻击 +25%，攻速 +20%，暴击率 +20%；击杀敌人回复 15% 生命；超凡之躯：免疫眩晕和魅惑", mods = { atk = 0.25, spd = 0.2, crit = 0.2 }, fx = { killHeal = 0.15, ccImmune = true }, q = 5 },
    sup_bear = { cls = "bear", sup = true, name = "赤铠熊魔", role = "末日践踏", skill = "doomstomp", aura = "#ff3b3b", sprite = "sup_bear", passive = "生命 +60%，受到的伤害 -25%；被近战攻击时反弹 30% 伤害；超凡之躯：免疫眩晕和魅惑", mods = { hp = 0.6, dr = 0.25 }, fx = { thorns = 0.3, ccImmune = true }, q = 5 },
    sup_flytrap = { cls = "flytrap", sup = true, name = "噬魂血棘", role = "血棘之海", skill = "bloodthorn", aura = "#ff3b3b", sprite = "sup_flytrap", proj = "bloodorb", passive = "生命 +30%，攻击 +30%；普攻叠加 3 层剧毒；超凡之躯：免疫眩晕和魅惑", mods = { hp = 0.3, atk = 0.3 }, fx = { poisonHit = 3, ccImmune = true }, q = 5 },
    sup_sunflower = { cls = "sunflower", sup = true, name = "赤阳神葵", role = "涅槃复生", skill = "rebirth", aura = "#ff3b3b", sprite = "sup_sunflower", proj = "sunfire", passive = "生命 +35%；每秒回复 2% 最大生命；光环：全队受到的伤害 -12%；超凡之躯：免疫眩晕和魅惑", mods = { hp = 0.35 }, fx = { regen = 0.02, drAura = 0.12, ccImmune = true }, q = 5 },
}
Data.BRANCH_ROLE = { berserker="吸血群攻",paladin="护盾坦克",sniper="远程狙杀",ranger="高速连射",pyro="灼烧范围",necro="召唤亡骨" }
Data.SUP_COL, Data.SUP_TAIL = "#ff3b3b", "；超凡之躯：免疫眩晕和魅惑"


---@type table<string, string>
Data.PAL = { k = "#1b1530", s = "#f2c29a", S = "#c98c68", h = "#8d9ab2", H = "#e6edf7", w = "#dfe7f2", g = "#e2b33c", b = "#6b4527", B = "#9b6a3c", r = "#d8433a", a = "#3b6fd1", A = "#78a8f2", t = "#f1e3c2", o = "#6ef0ff", O = "#ffffff", e = "#ff3b3b", z = "#4fbf4a", Z = "#9be36b", x = "#2f7a34", c = "#e9e2cf", C = "#a89f8a", p = "#5a2a7a", P = "#8f4bc4", d = "#3a2d52", y = "#ffd84a", m = "#7a1f2b", f = "#ff8a2a", F = "#ffe14a", u = "#3aa6c8", R = "#ff3434", E = "#ff8e6a", D = "#22101a" }
---@type table<string, string[]>
Data.SPR = {
    ["warrior"] = { "................", "......rrr.......", ".....kkkkkk.....", "....kHHHHHhk....", "....kHhhhhhk....", "....khkkkkhk....", "....khskskhk....", "....khhsshhk..kk", ".....kkkkkk..kwk", "..kkkaAAAak.kwk.", ".kAAkaAAAakkwk..", ".kAgkaaaaakgk...", ".kAAkaaaaakkk...", "..kkkkbbbbk.....", "....kaak.kaak...", "....kkkk.kkkk..." },
    ["archer"] = { "................", ".....kkkk.......", "....kaAAAk...k..", "...kaAAAAak.kBk.", "...kaakssk..k.Bk", "...kakskskk.kt.B", "...kaksssk..kt.B", "....kkssk..kktkB", "...kaaakkkssktkB", "..kbkaAAaakkkt.B", "..kbkaAAAak.kt.B", "..kbkaaaaak.k.Bk", "...kkkbgbbk.kBk.", "....kbbkbbk..k..", "....kbbkkbbk....", "....kkkk.kkk...." },
    ["mage"] = { ".......k........", "......kAk.......", ".....kaAak......", "....kaaAAak.....", "...kaaaaaaak.ko.", "..kkkkkkkkkkkoOo", "....ksksskk..kok", "....kssssk...kbk", "...kaaaaaak.kbk.", "..kaAAaaaaakkbk.", "..kaAkaaassskbk.", "..kaAkaaaakkkbk.", "..kaAAaaaaak.bk.", "..kaAAAaaaak.bk.", "..kkkkkkkkkk.kk.", "................" },
    ["slime"] = { "................", "................", "................", "................", "................", "......kkkk......", "....kkZZzzkk....", "...kZZOZzzzzk...", "..kZZOZzzzzzzk..", "..kZzzzzzzzzzk..", "..kzzkOzzkOzzk..", ".kzzzkkzzkkzzzk.", ".kzzzzzzzzzzzxk.", ".kxzzzzzzzzzxxk.", "..kkxxxxxxxxkk..", "....kkkkkkkk...." },
    ["skeleton"] = { "................", ".....kkkkk......", "....kcccccck....", "....kcckckck....", "....kcceceek....", "....kcccccck....", ".....kkCkCk..k..", "......kckk..kwk.", "...kkkcccck.kwk.", "..kcckkCkCkkkwk.", "..kck.kcck.kgk..", "..kk..kCkk.kk...", "......kccck.....", ".....kck.kck....", ".....kck.kck....", ".....kkk.kkk...." },
    ["skelarcher"] = { "................", ".....kkkkk......", "....kmmmmmk..k..", "....kmcckck.kBk.", "....kcceceek.kBk", "....kcccccck.ktB", ".....kkCkCk.kt.B", "......kckk..kt.B", "...kkkcccckkcckB", "..kcckkCkCk.kt.B", "..kck.kcck..kt.B", "..kk..kCkk..ktBk", "......kccck.kBk.", ".....kck.kck.k..", ".....kck.kck....", ".....kkk.kkk...." },
    ["orc"] = { "................", "....kkkkkk......", "...kzzzzzzk.....", "..kzzZZzzzzk.kk.", "..kzkekzkekk.kHk", "..kzzzzzzzzk.kHk", "..kzOkzzkOzk.kHk", ".kkkzzzzzzkkkkhk", "kzzkmmmmmmkzzkbk", "kzzkmbbbbmkzzkbk", "kZzkmmmmmmkzkkbk", ".kkkmmmmmmkkk.bk", "...kbbkkbbk...kk", "...kzzk.kzzk....", "..kbbbk.kbbbk...", "..kkkkk.kkkkk..." },
    ["darkmage"] = { "................", "......kkkk......", ".....kddddk.....", "....kddpddk.....", "...kddkkkkdk.k..", "...kdkeekekdkek.", "...kdkkkkkdkkek.", "....kddddddk.kk.", "...kdpPPddddkbk.", "..kdpPPdddddkbk.", "..kdpkddddkkkbk.", "..kdpkdddddk.bk.", "..kdpPddddddkbk.", "..kddddddddddkk.", "..kkkkkkkkkkkk..", "................" },
    ["boss"] = { "........................", "..kk................kk..", "..kck..............kck..", "...kck....kkkk....kck...", "...kcck.kkmmmmkk.kcck...", "....kcckmmrrrrmmkcck....", ".....kkmrrrrrrrrmkk.....", "......kmrrkkrrkkrmk.....", "......kmrkeekkeekrmk....", "......kmrrkkrrkkrrmk....", ".......kmrrrkkrrrmk.....", "....kkkkkmrOOOOrmkkkkk..", "...kpppPkkmrrrrmkkPpppk.", "..kppPPPpkkmmmmkkpPPPppk", "..kpPkkpppppppppppkkPpk.", "..kpk.kpgpppppppgpk.kpk.", "..kpk.kpggpppppggpk.kpk.", "..kgk.kppgggggggppk.kgk.", "..kk..kpppppppppppk..kk.", "......kmmmkk.kkmmmk.....", ".....kmmmk.....kmmmk....", ".....kmmk.......kmmk....", "....kkkkk.......kkkkk...", "........................" },
    ["sym_sword"] = { "................", "............kkk.", "...........kwHk.", "..........kwHk..", ".........kwHk...", "........kwHk....", ".......kwHk.....", "..kk..kwHk......", "..kgkkwHk.......", "...kgkHk........", "....kgkk........", "...kbkgk........", "..kbkkkgk.......", ".kbk...kk.......", ".kk.............", "................" },
    ["sym_bow"] = { "................", "....kkkk........", "...kBBBBk.......", "..kBkkkkbkk.....", "..kBk...kbk.....", ".kBk.....kbk....", ".kBk......kbk...", ".kgktttttttktk..", ".kBk......kbk...", ".kBk.....kbk....", "..kBk...kbk.....", "..kBkkkkbkk.....", "...kBBBBk.......", "....kkkk........", "................", "................" },
    ["sym_staff"] = { "................", "..........kkk...", ".........koOok..", "........koOooxk.", "........kooooxk.", ".........kooxk..", "........kgkkk...", ".......kbgk.....", "......kbbk......", ".....kbbk.......", "....kbbk........", "...kbbk.........", "..kbbk..........", "..kbk...........", "..kk............", "................" },
    ["sym_coin"] = { "................", ".....kkkkkk.....", "...kkyyyyyykk...", "..kyyOyyyyyyyk..", "..kyOyygggyyyk..", ".kyyyygkkgyyyyk.", ".kyyyygkyyyyyyk.", ".kyyyyygggyyyyk.", ".kyyyyyyykgyyyk.", ".kyyyygkkgyyyyk.", ".kyyyyygggyyygk.", "..kyyyyyyyyyggk.", "..kgyyyyyyyggk..", "...kkggggggkk...", ".....kkkkkk.....", "................" },
    ["sym_star"] = { "................", ".......kk.......", "......kyyk......", "......kyyk......", ".....kyOyyk.....", "kkkkkyyOyyykkkkk", "kyyyyyyyyyyyyyyk", ".kyyyyyyyyyyyyk.", "..kyyyyyyyyyyk..", "...kyyyyyyyyk...", "...kyyyyyyyyk...", "..kyyyyyyyyyyk..", "..kyyyykkyyyyk..", ".kyyykk..kkyyyk.", ".kykk......kkyk.", ".kk..........kk." },
    ["berserker"] = { "................", "..kk.....kk..kk.", "..kck...kck.kHHk", "...kckkkkck.kHHk", "...khhhhhhk.kHHk", "...kekkkekk..kbk", "...kssssssk..kbk", "....kssssk...kbk", "..kkkrrrrkkk.kbk", ".kssksmmsksskbk.", ".kssksmmsksssbk.", "..kkkbbbbkkkkbk.", "....kmmkkmmk.kbk", "....kmmk.kmmk.kk", "....kbbk.kbbk...", "....kkkk.kkkk..." },
    ["paladin"] = { "......ggg.......", ".....kkkkkk.....", "....kHHHHHHk....", "....kHggggHk....", "....kHkkkkHk..k.", "....kHsksskk.kwk", "kkkkk.kkkkkk.kwk", "kHgHk.kHHHHkkwk.", "kgggkkaHHHakwk..", "kHgHkkaaHaakgk..", "kHgHkkaaaaakk...", ".kHk.kggggk.....", "..k..kHHkHHk....", ".....kHHkHHk....", ".....khhkhhk....", ".....kkkkkkk...." },
    ["sniper"] = { "................", ".....kkkk.......", "....kaAAAk...k..", "...kaAAAAak.kBk.", "...kaakesk..k.Bk", "...kakrrrkk.kt.B", "...kakrrrk..kt.B", "....kkssk..kktkB", "...kaaakkkssktkB", "..kbkaAAaakkkt.B", "..kbkaAAAak.kt.B", "..kbkaaaaak.k.Bk", "...kkkbgbbk.kBk.", "....kbbkbbk..k..", "....kbbkkbbk....", "....kkkk.kkk...." },
    ["ranger"] = { "........rr......", ".....kkkkrk.....", "...kkzZZZzkk.k..", "..kkkkkkkkkk.kBk", "...kaakssk..k.Bk", "...kakskskk.kt.B", "...kaksssk..kt.B", "....kkssk..kktkB", "...kaaakkkssktkB", "..kbkaAAaakkkt.B", "..kbkaAAAak.kt.B", "..kbkaaaaak.k.Bk", "...kkkbgbbk.kBk.", "....kbbkbbk..k..", "....kbbkkbbk....", "....kkkk.kkk...." },
    ["pyro"] = { ".......k........", "......kAk.......", ".....kaAak...F..", "....kaaAAak..f..", "...kaaaaaaak.ko.", "..kkkkkkkkkkkoOo", "....ksksskk..kok", "....kssssk...kbk", "...kaaaaaak.kbk.", "..kaAAaaaaakkbk.", "..kaAkaaassskbk.", "..kaAkaaaakkkbk.", "..kaAAaaaaak.bk.", "..kaAAAaaaak.bk.", "..kkkkkkkkkk.kk.", "................" },
    ["necro"] = { ".......k........", "......kAk.......", ".....kaAak......", "....kaaAAak..P..", "...kaaaaaaak.kc.", "..kkkkkkkkkkkcec", "....kdPdPkk..kck", "....kddddk...kbk", "...kaaaaaak.kbk.", "..kaAAaaaaakkbk.", "..kaAkaaadddkbk.", "..kaAkaaaakkkbk.", "..kaAAaaaaak.bk.", "..kaAAAaaaak.bk.", "..kkkkkkkkkk.kk.", "................" },
    ["crown"] = { ".k.k.k.", "kykykyk", "kyyyyyk", "kyryryk", "kkkkkkk" },
    ["heart"] = { ".kk.kk.", "krrkrrk", "krOrrrk", "krrrrrk", ".krrrk.", "..krk..", "...k..." },
    ["dragoon"] = { "..k.........k.k.", "..kck......kckwk", "...kckkkkkkckkwk", "....kHHHHHhk.kHk", "....kHhhhhhk.kbk", "....khkkkkhk.kbk", "....khskskhk.kbk", "....khhsshhk.kbk", ".....kkkkkk.kkbk", "..kkkaAAAakksbk.", ".kAAkaAAAakkskbk", ".kAgkaaaaak.kkbk", ".kAAkaaaaak..kbk", "..kkkkbbbbk..kbk", "....kaak.kaak.kk", "....kkkk.kkkk..." },
    ["blademaster"] = { "..............k.", ".....kkkkkk..kwk", "....kddddddk.kwk", "...krrrrrrrrkkwk", ".kmmkdssssdk.kwk", ".km.kskssksk.kwk", ".k...kssssk..kwk", "....kkkkkkkk.kwk", "..kkccsscckk.kwk", ".kcckccsccckkkwk", ".kcckcCccCckkggg", ".ksskmmmmmmkssmk", "..kkkaaaaaak.kmk", "....kaaaaaak..k.", "....kaak.kaak...", "....kkkk.kkkk..." },
    ["windrunner"] = { "................", ".....kkkk.......", "....kaAAAk...k..", "...kaAAAAak.kBk.", "...kaakssk..k.Bk", "...kakskskk.kt.B", ".kokaksssk..kt.B", "kookkkssk..kktkB", ".kkkaaakkkssktkB", "..kbkaAAaakkkt.B", "..kbkaAAAak.kt.B", "..kbkaaaaak.k.Bk", "...kkkbgbbk.kBk.", "....kbbkbbk..k..", "....kbbkkbbk....", "....kkkk.kkk...." },
    ["beastmaster"] = { "....k..k........", "...kAkkAk...k...", "...kaAAAak..kBk.", "...kaAAAAak.k.Bk", "...kawkwak..kt.B", "...kakskskk.kt.B", "...kaksssk..kt.B", "....kkssk..kktkB", "...kaaakkkssktkB", "..kbkaAAaakkkt.B", "..kbkaAAAak.kt.B", "..kbkaaaaak.k.Bk", "...kkkbgbbk.kBk.", "....kbbkbbk..k..", "....kbbkkbbk....", "....kkkk.kkk...." },
    ["frost"] = { ".......k........", "......kAk.......", ".....kaAak...k..", "....kaaAAak.kok.", "...kaaaaaaakkoOk", "..kkkkkkkkkkkOok", "....ksksskk..kok", "....kccccc...kbk", "...kakcccak.kbk.", "..kaAAkcaaakkbk.", "..kaAkaaassskbk.", "..kaAkaaaakkkbk.", "..kaAAaaaaak.bk.", "..kaAAAaaaak.bk.", "..kkkkkkkkkk.kk.", "................" },
    ["storm"] = { ".......k........", "......kAk....k..", ".....kaAak..kFk.", "....kaaAAak.kFk.", "...kaaaaaaakkFFk", "..kkkkkkkkkkkkFk", "....ksksskk..kFk", "....kssssk...kbk", "...kaaaaaak.kbk.", "..kaAAaaaaakkbk.", "..kaAkaaassskbk.", "..kaAkaaaakkkbk.", "..kaAAaaaaak.bk.", "..kaAAAaaaak.bk.", "..kkkkkkkkkk.kk.", "................" },
    ["wolf"] = { "................", "................", "................", "..........k.k...", ".........khkhk..", ".k.......khhhhk.", "khk......khkhhhk", "khk.....kkhhhHHk", ".khkkkkkkhhhhkkk", "..khhhhhhhhhhk..", "..khhhhhhhhhhk..", "..khHHHHHHhhhk..", "..khkkkkkkkhhk..", "..khk.....khk...", "..kHk.....kHk...", "..kkk.....kkk..." },
    ["seraph"] = { ".....yyyyyy.....", ".....kkkkkk.....", "....kHHHHHHk....", "....kHggggHk....", "kk..kHkkkkHk..k.", "kOk.kHsksskk.kwk", "kOOkkkkkkkkk.kwk", "kOwOk.kHHHHkkwk.", ".kOwOkaHHHakwk..", ".kOOwkaaHaakgk..", "..kOOkaaaaakk...", "...kkkggggk.....", ".....kHHkHHk....", ".....kHHkHHk....", ".....khhkhhk....", ".....kkkkkkk...." },
    ["turret"] = { "................", "................", "....kk..........", "....kBk.........", ".....kBk........", "..kkkkkBkkkkkk..", ".kbbbbbbbbbbwOk.", "..kkkkkBkkkkkk..", ".....kBk........", "....kBkk........", "....kkbk........", ".....kbk........", "....kbbbk.......", "...kbkkkbk......", "..kbk...kbk.....", "..kk.....kk....." },
    ["titan"] = { "................", "..kkk.kkkkkk....", ".kHHkkHHHHHHk...", ".kHHHkHggggHk...", "..kHkkHkkkkHk...", "...kkkHkeekHk...", "..kHHkHkkkkHk...", ".kHHHHkkkkkkkkk.", "kHHkkHHHHHHHHkk.", "kHk.kaHHHHHHakk.", "kgk.kaaaaaaaak..", "kHk.kaaggggaak..", ".k..kkkkkkkkkk..", "....kHHk.kHHk...", "...kHHHk.kHHHk..", "...kkkkk.kkkkk.." },
    ["obsidian"] = { "................", ".....kkkkkk.....", "....kdddddPk....", "...kdddddddPk...", "...kdkkkkkkdk...", "...kdkeeeekdk...", "...kddkkkkddk...", "..kkkddddddkkkk.", ".kdPkdPddddkdddk", ".kddkddddddkdPdk", ".kddkdddPddkdddk", "..kkkddddddkdddk", "....kdddddkkdddk", "....kddkddk.kkk.", "....kddkddk.....", "....kkkkkkk....." },
    ["ashblade"] = { "................", "......kkkk......", ".....kCCCCk.....", "....kCCCCCCk....", "....kCkkkkCk....", "....kkekkekk....", "....kCkkkkCk..k.", "...kkCCCCCCkkwk.", "..kCkcCCCCckwk..", ".kwkkCCCCCCkk...", "kwk.kCmmmmCk....", "kk..kCCCCCCk....", "....kCCkCCCk....", "....kCk.kCCk....", "...kkCk.kCkk....", "...kkkk.kkkk...." },
    ["keg"] = { "........F.......", ".......kyk......", "........b.......", "........b.......", ".....kkkbkkk....", "....kBBBbBBBk...", "...khhhhhhhhhk..", "...kBBBBBBBBBk..", "...kBkkBBBkkBk..", "...kBBeBBBeBBk..", "...kBBBkkkBBBk..", "...khhhhhhhhhk..", "....kBBBBBBBk...", ".....kkkkkkk....", ".....kbk.kbk....", ".....kkk.kkk...." },
    ["magmaslime"] = { "................", "................", "................", ".......kk.......", "......kFfk......", "....kkkffkkk....", "...kmmffffmmk...", "..kmfFffffffmk..", "..kfFffffffffk..", ".kmfkkfffkkffmk.", ".kffkkfffkkfffk.", ".kmfffffffffffk.", ".kmmfffmmfffmmk.", "..kmmmmmmmmmmk..", "...kkkkkkkkkk...", "................" },
    ["magmalet"] = { "....kk....", "...kFfk...", "..kmffmk..", ".kfkffkfk.", ".kffffffk.", ".kmmmmmmk.", "..kkkkkk..", ".........." },
    ["pyromancer"] = { "................", "..k.......k.....", "..kmk...kmk.....", "...kmkkkkmk.....", "...krrrrrrk.....", "..krrkkkkrrk....", "..krkekkekrk..F.", "..krrkkkkrrk.fFf", "...kkrrrrkk..kFk", "..krrrrrrrrkssk.", "..krmrrrrmrk....", "..krrmmmmrrk....", ".krrrrffrrrrk...", ".krrrfFFfrrrk...", ".kkkkkkkkkkkk...", "................" },
    ["forgepriest"] = { "................", "....kkkk........", "...kbbbbk...kkk.", "..kbbbbbbk.khhhk", "..kbkkkkbk.khhhk", "..kbkekekk..kbk.", "..kbkkkkbk..kbk.", ".kkbbbbbbkk.kbk.", "kbbkfffffkbbkbk.", "kbbkbfFfbkbsskk.", ".kkkbbfbbkkkkbk.", "...kbbfbbk...bk.", "...kbbbbbk...kk.", "..kbbbbbbbk.....", "..kkkkkkkkk.....", "................" },
    ["pillar"] = { ".......k........", "......kdk.......", ".....kdPdk......", ".....kdfdk......", "....kddfPdk.....", "....kdfFfdk.....", "....kdfFfdk.....", "....kdPfddk.....", "....kddfdPk.....", "....kdfFfdk.....", "...kkddfddkk....", "..kmmkdddkmmk...", "..kmmmkkkmmmk...", ".kmmmmmmmmmmmk..", ".kkkkkkkkkkkkk..", "................" },
    ["colossus"] = { "........................", "..........kkkk..........", ".........kHHHHk.........", "........kHhhhhhk........", "........khekkehk........", "........khhkkhhk........", "...kkkk.kkhffhkk.kkkk...", "..kHHHHkkhhhhhhkkHHHHk..", ".kHhhhhkhHhhhhHhkhhhhhk.", ".khhfhhkHhhffhhHkhhfhhk.", ".khhhfkhhhfFFfhhhkfhhhk.", ".kkhhhkhhfFOOFfhhkhhhkk.", "..khhkkhhfFOOFfhhkkhhk..", "..khhk.khhfFFfhhk.khhk..", "..kHHk.khhhffhhhk.kHHk..", ".khhhhkkhhhhhhhhkkhhhhk.", ".khFhhk.khhhhhhk.khhFhk.", ".kkkkkk.khhhhhhk.kkkkkk.", ".......khhk..khhk.......", ".......khhk..khhk.......", ".......khfk..kfhk.......", "......kHhhk..khhHk......", "......kkkkk..kkkkk......", "........................" },
    ["mirrorguard"] = { "......kkk.......", ".....kAOAk......", "....kkHHHkk.....", "...kHHHHHHHk....", "...kHkkkkkHk....", "...kHkoookHk....", "...kHHkkkHHk....", "..kkhHHHHHhkkk..", ".khHkhHHHHhkOwk.", ".khhkhHHHHhkwAAk", ".khhkhhHHhhkAOAk", "..kkkhhHHhhkAAak", "....khhhhhkkaak.", "....khhkhhk.kk..", "....khhkhhk.....", "....kkkkkkk....." },
    ["hooker"] = { "................", "....kkkkk.......", "...kdddddk......", "..kdddddddk.kkk.", "..kdkkkkkdk.kwwk", "..kdkekekdk..kwk", "..kdkkkkkdk.k.wk", ".kkdddddddkkhkwk", "kddkdPdPdkhk.kk.", "kddkdddddkh.....", ".kkkdPdPdkh.....", "...kdddddkh.....", "...kddddddkh....", "..kddddddddk....", "..kdkkddkkdk....", "..kkk.kk.kkk...." },
    ["charmer"] = { ".......k........", "......kpk.......", ".....kppk.......", "....kpppPk......", "..kkkkkkkkkk....", "....kssssk..krrk", "...kksesesk.krrk", "...kpksssskk.kk.", "..kppkkkkkpk.kbk", "..kpPppppPpkskbk", "..kpPpppppPkk.bk", ".kppPpppppPpk.k.", ".kpPpprrppPpk...", "kppPppppppPppk..", "kkkkkkkkkkkkkk..", "................" },
    ["phaser"] = { "................", "......kkkk......", ".....kdddok.....", ".....kdkook.....", ".....kddddk.....", "......kddk......", "....kkdoodkk....", "...kdkddddkdk...", "..kdk.kdok.kdk..", "..kok.kddk.kok..", "...k..kodk..k...", "......kddk......", ".....kdkkdk.....", ".....kdkkdk.....", ".....kokkok.....", ".....kkkkkk....." },
    ["cultist"] = { "................", ".....kkkkk......", "....kpppppk.....", "...kppppppPk....", "...kpkccckpk....", "...kpkekekpk....", "...kpkccckpk....", "...kppkkkppk....", "..kpPppppppPk...", "..kpPpPZPpPpk...", ".kcpPppZppPpck..", ".kkpPppppppPkk..", "..kpPppppppPk...", ".kpPpppppppPpk..", ".kkkkkkkkkkkkk..", "................" },
    ["voidlord"] = { "........................", "..........kkkk..........", ".........kddddk.........", "........kdgygdgk........", ".......kddddddddk.......", ".......kdkkkkkkdk.......", ".......kdkkOOkkdk.......", ".......kdkoOOokdk.......", ".......kdkkookkdk.......", "......kddkkkkkkddk......", ".....kdPddddddddPdk.....", "....kdPPdddPPdddPPdk....", "...kdPkPdddPPdddPkPdk...", "..kdPk.kdddPPdddk.kPdk..", "..kdk..kddddddddk..kdk..", "..kok..kdPddddPdk..kok..", "..kOk..kddPddPddk..kOk..", "...k...kdddddddk...k....", "........kdkddkdk........", ".......kdk.kdk.kdk......", ".......kPk.kPk.kPk......", "........k...k...k.......", "........................", "........................" },
    ["voidleech"] = { "................", "................", ".....kkkkkk.....", "....kAAAAAAk....", "...kAoAAAAAAk...", "...kAAkAAkAAk...", "...kAAAAAAAAk...", "...kaAaAAaAak...", "...kkakkakkakk..", "....kA.kA.kA....", "....kA..kA.kA...", ".....kA.kA..kA..", ".....kA..kA.kA..", "......k...k..k..", "................", "................" },
    ["m_soul"] = { "......kOk.......", "......kook......", ".....kkOukk.....", "....kOOooouk....", "...kOoooooouk...", "..kOoooooooouk..", "..kOoooooooouk..", "..kOokkookkouk..", "..kOokkookkouk..", "..kOokkookkouk..", "..kooooooooouk..", "..kooooooooouk..", "..kuoouuoouuuk..", "...kuukkuukkuk..", "....kk..kk..k...", "................" },
    ["m_lever"] = { "................", "........kkkk....", ".......krrrrk...", ".......krOrrk...", ".......krrrrk...", "........kkkk....", ".......kHk......", "......kHk.......", ".....kHk........", "....khk.........", "..kkkkkkkkkkk...", ".kBBBBBBBBBBBk..", ".kbBBBBBBBBBbk..", ".kbbbbbbbbbbbk..", "..kkkkkkkkkkk...", "................" },
    ["m_stack"] = { "................", "................", "................", "....kkkkkk......", "...kyyyyyyk.....", "...kgggggyk.....", "....kkkkkk......", "..kkkkkkkkk.....", ".kyyyyyyyyyk....", ".kgggggggggk....", "..kkkkkkkkkkkk..", "...kyyyyyyyyyyk.", "...kgggggggggyk.", "....kkkkkkkkkk..", "................", "................" },
    ["m_ticket"] = { "................", "................", "................", ".kkkkkkkkkkkkkk.", "kyyyyyyyyyyyyygk", "kyOOygyyyyyyyygk", "kyyyyyyyyfyyyygk", ".kkyygyyfFfyykk.", ".kyyyyyyyfyyyyk.", "kyyyygyyfyfyyygk", "kyyyyyyyyyyyyygk", "kggggggggggggggk", ".kkkkkkkkkkkkkk.", "................", "................", "................" },
    ["m_gem"] = { "................", "................", "....kkkkkkkk....", "...kOOPPPPPPk...", "..kOPPPPPPPPpk..", ".kOPPkPPPPkPPpk.", ".kkkkkkkkkkkkkk.", "..kPPPkPPkPPpk..", "...kPPPkkPPpk...", "....kPPPPPpk....", ".....kPPPpk.....", "......kPpk......", ".......kk.......", "................", "................", "................" },
    ["m_luck"] = { "................", "................", "....kkk..kkkk...", "...kZZzkkZZZzk..", "..kZOZZZZOZZzk..", "..kZZZZZZZZZZzk.", "..kzZZZZZZZZZzk.", "...kZZZZZZZZzk..", "...kZZZZZZZzk...", "..kZOZZZZOZZzk..", "..kZZZZZZZZZZzk.", "..kZZZZZxZZZZzk.", "..kzzZZzxzZZzk..", "...kkzzkxxzzk...", ".....kkkxkxk....", "........k.k....." },
    ["tiger"] = { "................", "....kk....kk....", "...kaAk..kAak...", "...kaaaaaaaak...", "...kakaaaakak...", "...kaFkaakFak...", "...kAAAOOAAAk...", "....kAAeeAAk....", ".....kkkkkk.....", "..kk.kakaak.kk..", ".kwakkaAAakkawk.", ".kwak.kAAAk.kawk", "..kk..kaAak..kk.", "....kkkaakkk....", "....kaak.kaak...", "....kkkk.kkkk..." },
    ["bear"] = { "................", "...kkk....kkk...", "..kbBbkkkkbBbk..", "..kbbbbbbbbbbk..", "..kbbbbbbbbbbk..", "..kbbkkbbkkbbk..", "..kbbBBBBBBbbk..", "...kbBBkkBBbk...", "....kBBeeBBk....", ".kkkkkbbbbkkkkk.", "kbbbkbbBBbbkbbbk", "kbwbkbBBBBbkbwbk", "kbbbkbbBBbbkbbbk", ".kkkkbbbbbbkkkk.", "....kbbk.kbbk...", "....kkkk.kkkk..." },
    ["flytrap"] = { "................", "....kkkkkkk.....", "...kaaaaaaak....", "..kaAaaaaaAak...", ".kaaakOkOkaaak..", ".kaaakOkOkaaak..", ".krOrOrOrOrOrk..", "..kkkkkkkkkkk...", ".....kzzk.......", "...kk.kzk.kk....", "..kZzkkzkkzZk...", "..kZzzkzkzzZk...", "...kkkkzkkkk....", ".....kkzk.......", "....kzzzzzk.....", "....kkkkkkk....." },
    ["sunflower"] = { ".....kkaAkk.....", "....kaaaAAAk....", "...kAaaaAAAak...", "..kAAAbbbbaaak..", "..kAAbkbbkbaak..", ".kAAAbbbbbbaaak.", ".kaaabkbbkbAAAk.", "..kaabbkkbbAAk..", "..kaaAAbbaaAAk..", "...kAAAAaaaak...", "...kkkAAaakk....", "..kzkkkzzk..k...", "...kZZZzzZkkZk..", "....kzzzzkzzk...", ".....kkzzkkk....", "......kzzk......" },
    ["sprout"] = { "................", "................", "................", ".....kk.kk......", "....kaakaak.....", "....kaAkAak.....", ".....kkkkk......", "......kzk.......", "...kk.kzk.kk....", "..kZzkkzkkzZk...", "...kZzzzzzZk....", "....kkkzkkk.....", ".....kzzzk......", ".....kkkkk......", "................", "................" },
    ["sym_tiger"] = { "................", "................", "..kk........kk..", ".kffkkk..kkkffk.", ".kfFfffkkfffFfk.", "..kffkfkkfkffk..", ".kffffffffffffk.", ".kfffkffffkfffk.", ".kfkfFffffFfkfk.", ".kffkffffffkffk.", ".kffffOkkOffffk.", ".kfffOOOOOOfffk.", "..kffOOkkOOffk..", "...kffOOOOffk...", "....kkffffkk....", "......kkkk......" },
    ["sym_bear"] = { "...kk......kk...", "..kbbk....kbbk..", ".kbbbbk..kbbbbk.", "kbbBbbbkkbbbBbbk", "kbbBBbbbbbbBBbbk", ".kbbbbbbbbbbbbk.", "..kbbbbbbbbbbk..", ".kbbbkbbbbkbbbk.", ".kbbbbbbbbbbbbk.", ".kbbbbbbbbbbbbk.", ".kbbbbBkkBbbbbk.", ".kbbbBBkkBBbbbk.", "..kbbBkBBkBbbk..", "...kbbBkkBbbk...", "....kbbbbbbk....", ".....kkkkkk....." },
    ["sym_flytrap"] = { "................", ".....kkkkkk.....", "...kkrrrrrrkk...", "..krrAArrAArrk..", ".krrrrrrrrrrrrk.", ".krrrrrrrrrrrrk.", ".krOrOrOrOrOrrk.", "..kkkkkkkkkkkk..", ".krOrOrOrOrOrrk.", "..krrrrrrrrrrk..", "...kkrrrrrrkk...", "....kkkzzkkk....", "...kZkkzzkkZk...", "....kZkzzkZk....", ".....kkzzkk.....", "......kzzk......" },
    ["sym_sunflower"] = { ".....kkkkkk.....", "....kyyyFFFk....", "...kFyyyFFFyk...", "..kFFyyyFFFyyk..", ".kFFFFybbFyyyyk.", "kyyyFbbbbbbyFFFk", "kyyyybkbbkbFFFFk", "kyyybbbbbbbbFFFk", "kFFFbbbbbbbbyyyk", "kFFFFbkbbkbyyyyk", "kFFFybbkkbbFyyyk", ".kyyyyFbbyFFFFk.", "..kyyFFFyyyFFk..", "...kyFFFyyyFk...", "....kFFFyyyk....", ".....kkkkkk....." },
    ["sup_warrior"] = { ".k...........k..k...", "kRk.........kRkkRk..", ".kHk.......kHk.kROk.", ".khk.kkkkk.khk.kROk.", "..khkhhhhhkhk..kROk.", "...kdhHHHhdk...kROk.", "...kddddddddk..kROk.", "...kdRRkRRkdk..kROk.", "...kkddddddkk..kROk.", ".kkkhkkddkkhkk.kROk.", "krrkHhhkRkhhHkkzzzzk", "krkhhhkROEkhhhkdddk.", "krrkhddkRkddhk.kzk..", "krrkkdddkdddkk..k...", "krrrkddddddddk......", ".krrkkZzkkzZkk......", ".krrrkddk.kddk......", "..krrkddk.kddk......", "..krkkhhk.khhk......", "...k.kkkk.kkkk......" },
    ["sup_archer"] = { "...............k....", "..............kRk...", "......kkkkkk..ktRk..", ".....khhhhhHk.kt.Rk.", "....khhhhhhhHkkt.Rk.", "...khhhhkkkkhkkt..Rk", "..khhhhkDRDRkkkt..Rk", ".khhkhhkDDDDk.kt..Rk", "khkkkhhkkkkkk.kt..Rk", "kk.krrhhhhhhk.kt..Rk", "..krrkhhRhhkHHkt..Ek", ".krrkdhhhhdkk.kt..Ek", "krrkkddhhhddk.kt..Rk", "krrrkdddddddk.kt..Rk", ".krrkkZzZzZkk.kt.Rk.", "..kk..kdddddk.kt.Rk.", "......kddkddk.ktRk..", "......kddkddk.kRk...", "......khhkhhk..k....", "......kkkkkkk......." },
    ["sup_mage"] = { "................k...", ".....k.k.k.....kRk..", "....kRkRkRk...kROEk.", "....khhhhhk...zkRkz.", "...khHHHHHhk..kzkzk.", "...kdkkkkkdk...kzk..", "..kddkRDRDkdk..kzk..", "..kddkDDDDkdk..kzk..", ".kkhdkkkkkkhkk.kzk..", "khhkhhhRhhhkhhkkzk..", "krkdhhkROEkhHHHkzHk.", "kRkdhhhkRkhhkkkHHk..", ".kkddhhhhhhdk..kzk..", "..kddhhRhhhddk.kzk..", "..kdhhhrhhhhdk.kzk..", ".kdhhhrrrhhhdk.kzk..", ".kdhhrrRrrhhdk.kzk..", "kddrrRkkkRrrdk.kzk..", "krrRkkk.kkkRrk..k...", "kkkk.......kkk......" },
    ["sup_tiger"] = { "....................", "...kk..........kk...", "..kRdk........kdRk..", "..kdddkkkkkkkkdddk..", "..kdRddRRddRRddRdk..", ".kddkkkddRRddkkkddk.", ".kRdkROkddddkORkdRk.", "kRddkkkkwwwwkkkkddRk", "kddRddwwwkkwwwddRddk", ".kddRdwwkRRkwwdRddk.", "..kdddkwOkkOwkdddk..", "...kkddkkkkkkddkk...", "..kk.kddRRRRddk.kk..", ".kwdkkdRddddRdkkdwk.", ".kwdk.kdRddRdk.kdwk.", "..kk..kddRRddk..kk..", "....kkkddddddkkk....", "....kdhk....khdk....", "....kddk....kddk....", "....kkkk....kkkk...." },
    ["sup_bear"] = { "....................", "...kkk........kkk...", "..kdRdkkkkkkkkdRdk..", "..kdddhhhhhhhhdddk..", "..kddhHHHHHHHHhddk..", "..kdddkkhhhhkkdddk..", "..kddkROkddkORkddk..", "..kdddkkddddkkdddk..", "...kddddhhhhddddk...", "....kddhkRRkhddk....", "....kkdwwkkwwdkk....", ".kkkkkkddddddkkkkkk.", "kdddkhhdRRRRdhhkdddk", "kdwdkhdRROORRdhkdwdk", "kdddkhdddRRdddhkdddk", ".kkkkhddddddddhkkkk.", "....khhddddddhhk....", "....kddk....kddk....", "....kddk....kddk....", "....kkkk....kkkk...." },
    ["sup_flytrap"] = { "......k..k..k.......", ".....kRkkRkkRk......", "....kkdddddddkk.....", "...kdddRdddRdddk....", "..kddddddddddddk....", "..kdkOkOkOkOkOkdk...", "..kRRRRRREERRRRRk...", "..kREEEEEEEEEEERk...", "..kdkOkOkOkOkOkdk...", "...kdddddddddddk....", "....kkkkdddkkkk.....", "..kk....khk....kk...", ".krRk..kkhk..kkRrk..", ".krrRkkhkhkkhkRrrk..", "..kkrrrkkhkkrrrkk...", "....kkkk.khk.kk.....", ".........khk........", "....kkkkkhhkkkk.....", "...kdhhhhhhhhhdk....", "...kkkkkkkkkkkkk...." },
    ["sup_sunflower"] = { ".....k...kk...k.....", "....kEk.kEEk.kEk....", "..kkkRRkREERkRRkkk..", ".kEEkkkkkkkkkkkkEEk.", ".kRRkkhhhhhhhhkkRRk.", "..kkkhhrrrrrrhhkkk..", ".kERkhrkOrrOkrhkREk.", "kEERkhrrrrrrrrhkREEk", ".kERkhrrRrrRrrhkREk.", "..kkkhhrrRRrrhhkkk..", ".kRRkkhhhhhhhhkkRRk.", ".kEEkkkkkkkkkkkkEEk.", "..kkkRRkREERkRRkkk..", "....kEk.kzzk.kEk....", ".....k..kzzk..k.....", "..kkk...kzzk...kkk..", ".kRrrkk.kzzk.kkrrRk.", "..kkrrrkkzzkkrrrkk..", "....kkkkkzzkkkkk....", "........kkkk........" },
    ["supbadge"] = { "k.kkk.k", "kRkRkRk", "kROOERk", ".kRRRk.", "..kkk.." },
}

local waveData = require("Legion.WaveData")
Data.WAVES, Data.WAVES2, Data.WAVES3 = waveData.WAVES, waveData.WAVES2, waveData.WAVES3
Data.DIFFS1, Data.DIFFS2, Data.DIFFS3 = waveData.DIFFS1, waveData.DIFFS2, waveData.DIFFS3
Data.CHAPTERS = waveData.CHAPTERS

Data.SOUL_BASE, Data.SOUL_CH, Data.SOUL_DIFF = 3, {1,1.3,1.6}, {1,1.5,2,2.5}
Data.SOUL_CLEAR, Data.SOUL_FIRST, Data.SOUL_ABANDON = 0.5, 1, 0.5
Data.Q_SHIFT, Data.CHEAP_EVERY = {-3,2,0.75,0.25}, {0,5,3}
Data.MX_NONE = {gold=0,cheap=0,interest=0,free=0,star=0,qual=0,luck=0,hp=0,atk=0}
Data.UPG_TABS = { {"eco","经济","sym_coin"}, {"sum","召唤","sym_star"}, {"pow","战力","sym_sword"} }
Data.UPG = {
    {id="gold",tab="eco",name="起始金币",icon="sym_coin",max=5,cost={20,35,55,80,110},note="每局开局多拿金币，能多拉几次杆"},
    {id="cheap",tab="eco",name="拉杆集点",icon="m_lever",max=2,cost={250,400},note="付费拉杆攒够次数，送 1 次免费拉杆；免费的那次不计入集点"},
    {id="interest",tab="eco",name="利息上限",icon="m_stack",max=2,cost={80,160},note="每存 10 金币，战后多得 1 金币；这里提高上限"},
    {id="free",tab="eco",name="开局免费拉杆",icon="m_ticket",max=1,cost={40},note="每局第一次拉杆不花金币"},
    {id="star",tab="sum",name="★ 出现率",icon="sym_star",max=4,cost={30,55,85,125},note="★ 可以替代任何图标，出现得越多越容易连线"},
    {id="qual",tab="sum",name="高品质召唤",icon="m_gem",max=3,cost={50,100,170},note="普通连线召唤出稀有、史诗、传说单位的概率更高"},
    {id="luck",tab="sum",name="幸运积累",icon="m_luck",max=2,cost={60,130},note="没中奖会积累幸运，幸运越多 ★ 越容易出现；这里提高幸运上限"},
    {id="hp",tab="pow",name="全员生命",icon="heart",max=4,cost={50,90,150,240},scale=0.02,note="所有参战单位的生命提高"},
    {id="atk",tab="pow",name="全员攻击",icon="sym_sword",max=4,cost={50,90,150,240},scale=0.02,note="所有参战单位的攻击提高"},
}
Data.SUP_PAL = { D="#22101a",d="#4c1b2f",h="#7a2d42",H="#b5566c",r="#a8102a",R="#ff3434",E="#ff8e6a",O="#fff2ea",w="#d8c6c6",z="#4e4658",Z="#958aa3",t="#ffc8bc",s="#e8b896" }
Data.BRPAL = {
    berserker={}, paladin={a="#2f5fb8"}, sniper={a="#2e2448",A="#5b4a86",B="#d4a640",b="#4a3a2a"}, ranger={a="#8a5a2b",A="#c08a4a"},
    pyro={a="#b8302a",A="#ff8a2a",o="#ff8a2a",O="#ffe680"}, necro={a="#2b2340",A="#6a33c9"}, minion={c="#cdbbff",C="#8f7bc4",e="#6ef0ff",w="#b9a6ff",g="#8f4bc4"},
    dragoon={a="#2f8f7a",A="#7fe0c0"}, blademaster={a="#2e2a5a",c="#f1ece0",C="#bdb3a0"}, windrunner={a="#25807c",A="#73d8c8",B="#bff0ff",o="#ffe14a",O="#fff6b0"},
    beastmaster={a="#6b6f80",A="#b4b8c6",w="#f1ece0"}, frost={a="#3d7fc8",A="#d8f4ff",o="#bff4ff",c="#f4f8ff"}, storm={a="#283a7c",A="#ffe14a"}, wolf={h="#7d7f8f",H="#c9cbd6"},
    banner={a="#b8302a",A="#ff8a6a",r="#ffd84a",H="#ffe9a0",h="#d4a640",w="#ffd84a"}, avenger={r="#5a2a7a",m="#2b1a3a",s="#b9a6c9",h="#4a3a5a",H="#9a8ab0",c="#c9c3d6",e="#c06bff"},
    undying={a="#2a5a6a",c="#cfeff5",C="#7fbfcc",d="#1f3a48",r="#6ef0ff",m="#2a8a9a",s="#bfe0e8",g="#6ef0ff"}, conqueror={a="#8e2420",A="#ff6a4a",H="#ffd84a",h="#c8900f",c="#ffd84a",s="#f2c29a"},
    titan={H="#c9b89a",h="#8a7a62",a="#6b5a4a",A="#a89070",g="#ff9f2e",e="#ffb04a"}, seraph={H="#fff3b0",h="#d4a640",a="#f4f8ff",A="#ffffff",w="#cfe3ff",O="#ffffff"},
    venom={a="#3a7a2a",A="#9be36b",B="#7a5a9a",b="#3a2a4a",t="#9be36b"}, hunter={a="#5a2a1a",A="#a85a3a",B="#c9c3d6",b="#3a2a1a",r="#ffd84a"}, arbalist={a="#4a5a6a",A="#9aaabb",r="#c9cbd6",z="#6b6f80",Z="#b4b8c6",B="#8a8a9a"},
    engineer={a="#9a5a1c",A="#e2b33c",B="#8d9ab2",b="#5a3a22"}, starfall={a="#1f2a6a",A="#5b6fd8",B="#ffe680",o="#ffffff",O="#ffe14a",t="#ffe680"}, shadow={a="#1b1530",A="#5a2a7a",r="#c06bff",B="#8f4bc4",b="#2b1a3a",s="#b9a6c9",t="#c06bff"},
    cleric={a="#d8d0bc",A="#ffffff",o="#fff3b0",O="#ffffff",b="#c8900f"}, hexer={a="#1f3a24",A="#4fbf4a",P="#9be36b",d="#2a3a2a",c="#9be36b",e="#ffe14a"}, chrono={a="#1f5a5a",A="#e2b33c",o="#ffe680",O="#ffffff",c="#ffe680"},
    voidcaller={a="#241a3a",A="#6a33c9",F="#c06bff"}, archmage={a="#8e1f2b",A="#ffd84a",o="#ff8a2a",O="#bff4ff",F="#6ef0ff",f="#ffe14a"}, lich={a="#16324a",A="#6ef0ff",P="#bff4ff",d="#0f2233",c="#e6f6ff",e="#6ef0ff"}, lichbone={c="#d6f2ff",C="#7fb8d8",e="#6ef0ff",w="#bff4ff",g="#6ef0ff"},
    claw={a="#d9742a",A="#f2a65a"}, bloodfang={a="#b8302a",A="#e8685a",F="#ff4a3a"}, shadowcat={a="#3a3a5a",A="#6a6a9a",F="#c06bff"}, whitetiger={a="#dfe7f2",A="#ffffff",F="#6ef0ff"}, hungrytiger={a="#8e3a1a",A="#c8602a",F="#ff4a3a"}, tigerspirit={a="#6ef0c0",A="#d8fff0",F="#ffffff"}, sabre={a="#c8900f",A="#ffe680",F="#ff4a3a"},
    brute={}, ironback={b="#5a5f6a",B="#8d9ab2"}, frenzybear={b="#8e2420",B="#d8433a"}, hibernator={b="#3a4a8a",B="#6a8ad8"}, mountain={b="#5a4a38",B="#a89878"}, polarking={b="#dfe7f2",B="#ffffff"}, bearking={b="#c8900f",B="#ffe680"},
    vine={a="#3f9a46",A="#9be36b"}, strangler={a="#2f7a34",A="#6fbf5a",r="#4a2a1a"}, plaguebloom={a="#8f4bc4",A="#c06bff"}, corroder={a="#9bc42a",A="#e6ff6a",r="#4a7a1a"}, mother={a="#c4405a",A="#ff7f9a"}, pandemic={a="#5a2a7a",A="#9a5ae0",z="#6b3f8a",Z="#b58ad6"}, devourer={a="#d8433a",A="#ff8a7a",r="#7a1f2b"},
    sunny={a="#e0a82a",A="#ffe14a"}, photosyn={a="#7fd36a",A="#d6ff9a"}, rose={a="#c4405a",A="#ff8a9a"}, moonbloom={a="#8aa8ff",A="#e4f2ff"}, lifebloom={a="#ff8ab8",A="#ffd0e6"}, sungod={a="#ff8a2a",A="#ffe14a"}, solar={a="#ff4a2a",A="#ffb04a"},
}

Data.ENEMIES = {
    slime = { name = "史莱姆", sprite = "slime", hp = 48, atk = 6, cd = 1, range = 7, speed = 18, r = 5, ch = 1 },
    skeleton = { name = "骷髅兵", sprite = "skeleton", hp = 78, atk = 9, cd = 1, range = 8, speed = 20, r = 5, ch = 1 },
    skelarcher = { name = "骷髅弓手", sprite = "skelarcher", hp = 50, atk = 8, cd = 1.1, range = 66, speed = 16, r = 5, proj = "earrow", ch = 1 },
    orc = { name = "兽人", sprite = "orc", hp = 240, atk = 17, cd = 1.3, range = 9, speed = 16, r = 6, ch = 1 },
    darkmage = { name = "暗巫", sprite = "darkmage", hp = 62, atk = 12, cd = 1.8, range = 58, speed = 15, r = 5, proj = "dark", splash = 14, ch = 1 },
    boss = { name = "深渊魔王", sprite = "boss", hp = 1500, atk = 30, cd = 1.5, range = 10, speed = 13, r = 10, splash = 18, big = true, skill = "stomp", desc = "技能「地狱践踏」：震晕周围的单位；噩梦及以上难度半血时召唤亡灵", ch = 1 },
    orcwar = { name = "兽人督军", sprite = "orc", hp = 420, atk = 22, cd = 1.2, range = 9, speed = 16, r = 6, skill = "rally", pal = { z = "#a83a2a", Z = "#e86a4a", m = "#3a2a2a", H = "#ffd84a", h = "#c8900f" }, desc = "技能「督战」：让所有敌人狂热 3 秒（攻速翻倍）", ch = 1 },
    lichpriest = { name = "死灵祭司", sprite = "darkmage", hp = 88, atk = 9, cd = 1.6, range = 62, speed = 14, r = 5, proj = "dark", skill = "mend", pal = { d = "#1f3a24", p = "#2f7a34", P = "#9be36b", e = "#9be36b" }, desc = "技能「死灵治愈」：治疗受伤最重的敌人 30% 生命，其他敌人回复 8%", ch = 1 },
    magmaslime = { ch = 2, name = "熔岩史莱姆", sprite = "magmaslime", hp = 56, atk = 6, cd = 1, range = 7, speed = 18, r = 5, pal = { m = "#5a2a26", f = "#ff7a2a", F = "#ffd84a" }, fx = { split = "magmalet" }, desc = "死亡时分裂成 2 个小熔岩，范围伤害清得最快" },
    magmalet = { ch = 2, name = "小熔岩", sprite = "magmalet", hp = 20, atk = 4, cd = 0.8, range = 6, speed = 26, r = 3, pal = { m = "#5a2a26", f = "#ff7a2a", F = "#ffd84a" } },
    bomber = { ch = 2, name = "火药桶怪", sprite = "keg", hp = 40, atk = 10, cd = 0.4, range = 5, speed = 34, r = 4, pal = { B = "#b34a2a", b = "#5a2a1a", e = "#ffe14a" }, fx = { dive = true, bomb = 3 }, desc = "绕过前排冲向最后排，贴身后自爆，对周围造成 300% 伤害；半路击杀就不会爆炸" },
    obsidian = { ch = 2, name = "黑曜卫士", sprite = "obsidian", hp = 200, atk = 13, cd = 1.3, range = 9, speed = 14, r = 6, pal = { d = "#2b2340", P = "#9a6ad8", e = "#ff8a2a" }, palBroken = { d = "#5a4a5e", P = "#3a2d40", e = "#ffd27a" }, fx = { armor = 0.5 }, desc = "黑曜甲：受到的伤害 -50%；被眩晕或冻结一次，护甲就永久碎裂" },
    ashblade = { ch = 2, name = "灰烬刺客", sprite = "ashblade", hp = 68, atk = 14, cd = 0.9, range = 7, speed = 26, r = 5, pal = { C = "#5a5560", c = "#8a8590", e = "#ff5a2a", m = "#a8452a", w = "#e6edf7" }, fx = { blink = true }, desc = "开战后闪现到生命上限最低的单位身后，第一击双倍伤害；每 8 秒闪现一次" },
    pyromancer = { ch = 2, name = "炎魔术士", sprite = "pyromancer", hp = 60, atk = 11, cd = 1.7, range = 60, speed = 15, r = 5, proj = "fireball", skill = "lavapool", pal = { r = "#8e2420", m = "#3a1a1a", e = "#ffe14a", s = "#c98c68" }, fx = { burnOnHit = true }, desc = "普攻附带灼烧；技能「熔岩池」在目标处留下持续 4 秒的灼烧地面" },
    forgepriest = { ch = 2, name = "熔炉祭司", sprite = "forgepriest", hp = 86, atk = 8, cd = 1.6, range = 62, speed = 14, r = 5, proj = "fireball", skill = "forge", pal = { b = "#4a3028", f = "#ff8a2a", F = "#ffe14a", e = "#ffb04a", s = "#c98c68" }, desc = "技能「熔铸护盾」：给所有敌人加上 25% 最大生命的护盾，最多叠到 50%" },
    pillar = { ch = 2, name = "熔岩晶柱", sprite = "pillar", hp = 240, atk = 10, cd = 2, range = 96, speed = 0, r = 5, proj = "fireball", pal = { d = "#2b2340", P = "#9a6ad8", f = "#ff7a2a", F = "#ffe680", m = "#3a2a30" }, fx = { anchor = true } },
    colossus = { ch = 2, name = "熔核巨像", sprite = "colossus", hp = 2400, atk = 30, cd = 1.6, range = 10, speed = 12, r = 10, splash = 18, big = true, skill = "fissure", pal = { h = "#5a4a48", H = "#8a7468", f = "#ff6a2a", F = "#ffd84a", O = "#ffffff", e = "#ffe14a" }, fx = { phases = true }, desc = "技能「地裂」：闪烁预警后沿直线喷发熔岩并灼烧。60% 生命时退回熔炉，召唤 3 根熔岩晶柱并进入无敌，晶柱全碎后核心过载（眩晕 3 秒，受到的伤害 +50%）；30% 生命时暴走，攻速翻倍并召唤援军" },
    voidleech = { ch = 3, name = "噬能幽影", sprite = "voidleech", hp = 60, atk = 9, cd = 0.8, range = 6, speed = 30, r = 4, pal = { A = "#7fe0e8", a = "#2a8a9a", o = "#ffffff" }, fx = { drain = 35 }, desc = "每次攻击吸走目标 35 点技能能量，被它缠上的单位几乎放不出技能" },
    mirrorguard = { ch = 3, name = "镜甲守卫", sprite = "mirrorguard", hp = 220, atk = 14, cd = 1.3, range = 9, speed = 14, r = 6, pal = { H = "#d6e2f2", h = "#8a9ab8", o = "#6ef0ff", O = "#ffffff", A = "#9ff6ff", a = "#4ab8c8", w = "#ffffff" }, fx = { mirrorArmor = 0.3 }, desc = "镜甲：受到远程和法术伤害时，把 30% 反弹给攻击者（单次最多为攻击者 8% 生命）；近战打它不会反弹" },
    hooker = { ch = 3, name = "锁魂钩手", sprite = "hooker", hp = 110, atk = 13, cd = 1.2, range = 9, speed = 16, r = 5, pal = { d = "#4a3870", P = "#8f4bc4", e = "#c06bff", h = "#8d9ab2", w = "#e6edf7" }, fx = { hook = true }, desc = "开战后用锁链把你最后排的单位拽到身前并眩晕 0.6 秒；每 9 秒一次" },
    charmer = { ch = 3, name = "幻惑女巫", sprite = "charmer", hp = 70, atk = 10, cd = 1.7, range = 62, speed = 14, r = 5, proj = "dark", skill = "charm", pal = { p = "#6a2a7a", P = "#c04ab8", r = "#ff6ad5", e = "#ff6ad5", b = "#e2b33c" }, desc = "技能「魅惑」：每隔约 10 秒，让你攻击最高的单位倒戈 3 秒，替敌人作战（倒戈期间不会放技能）" },
    phaser = { ch = 3, name = "相位行者", sprite = "phaser", hp = 90, atk = 15, cd = 1, range = 7, speed = 22, r = 5, pal = { d = "#2e3f6e", o = "#6ef0ff" }, fx = { shift = true }, desc = "每 4 秒相位隐身 1.5 秒，隐身时免疫一切伤害；持续输出比爆发更稳" },
    cultist = { ch = 3, name = "凋零信徒", sprite = "cultist", hp = 70, atk = 9, cd = 1.1, range = 8, speed = 18, r = 5, pal = { p = "#4a2a4a", P = "#7a4a8a", c = "#d6d0b8", e = "#9be36b", Z = "#9be36b" }, fx = { deathCurse = true }, desc = "死亡时爆出瘴气：附近的单位 5 秒内受到的伤害 +30%，造成的伤害 -30%" },
    voidlord = { ch = 3, name = "虚空之主", sprite = "voidlord", hp = 2800, atk = 24, cd = 1.4, range = 72, speed = 10, r = 10, proj = "dark", splash = 16, big = true, skill = "rift", pal = { d = "#3e2c66", P = "#9a5ae0", g = "#e2b33c", y = "#ff6ad5", O = "#ffffff", o = "#c06bff" }, fx = { vphases = true }, desc = "远程虚空弹带溅射。技能「虚空新星」：标记 3 个单位，1.2 秒后在脚下爆炸。66% 生命时复制你攻击最高的几个单位（虚影只会普攻）；33% 生命时吟唱 6 秒「虚空坍缩」并套上护盾，倒计时结束前打破护盾即可打断它并眩晕 3 秒，否则全场受到 45% 最大生命的伤害" },
}
Data.SKILLS = {
    bash = { name = "盾击", charge = 25, desc = "造成 160% 伤害并眩晕目标 1 秒" },
    triple = { name = "三连射", charge = 25, desc = "向目标连射 3 箭，每箭 80% 伤害" },
    arcane = { name = "奥术爆裂", charge = 34, desc = "在目标处爆炸，对范围内所有敌人造成 150% 伤害" },
    whirlwind = { name = "旋风斩", charge = 25, desc = "劈砍身边所有敌人，造成 140% 伤害，并回复造成伤害的 30%" },
    aegis = { name = "圣光庇护", charge = 22, desc = "给自己和血量最低的两名队友加上 30% 最大生命的护盾，并嘲讽附近敌人" },
    snipe = { name = "致命狙击", charge = 25, desc = "无视距离，狙击当前生命最高的敌人，造成 400% 伤害" },
    volley = { name = "箭雨", charge = 25, desc = "向目标区域连降 6 支箭，每支对小范围造成 80% 伤害" },
    meteor = { name = "陨火", charge = 34, desc = "召下陨石，对大范围造成 220% 伤害并灼烧 3 秒" },
    stomp = { name = "地狱践踏", charge = 34, desc = "震击周围，造成 120% 伤害并眩晕 1 秒" },
    raise = { name = "亡骨召唤", charge = 34, desc = "召唤 1 个亡骨仆从助战，最多 2 个；满员时改为治疗仆从" },
    leap = { name = "龙跃", charge = 30, desc = "跃向最远的敌人（通常是后排），落地对周围造成 200% 伤害并眩晕 0.8 秒" },
    issen = { name = "一闪", charge = 30, desc = "对目标造成 280% 伤害且必定暴击；击杀目标时返还一半能量" },
    pierce = { name = "贯穿之箭", charge = 28, desc = "射出一支贯穿箭，对直线上所有敌人造成 220% 伤害" },
    wolf = { name = "召唤战狼", charge = 30, desc = "召唤 1 头战狼助战；战狼在场时改为让它回满生命并狂暴 4 秒（攻速翻倍）" },
    frostnova = { name = "冰封领域", charge = 34, desc = "在目标处爆发寒冰，对范围内敌人造成 130% 伤害，冻结 1.5 秒并减速" },
    chain = { name = "连锁闪电", charge = 30, desc = "闪电击中目标后最多弹射 4 次，首击 160% 伤害，每次弹射递减 15%" },
    warcry = { name = "战吼", charge = 25, desc = "全队狂热 3 秒（攻速翻倍），并回复 12% 最大生命" },
    vengeance = { name = "以血还血", charge = 25, desc = "对目标造成 180% 攻击 + 60% 已损失生命的伤害，并眩晕 0.8 秒" },
    venomburst = { name = "毒雾箭", charge = 25, desc = "毒雾在目标处炸开，对范围内敌人造成 100% 伤害并叠加 3 层剧毒" },
    hunt = { name = "猎杀", charge = 25, desc = "射击生命比例最低的敌人，造成 350% 伤害；击杀则返还 60 能量" },
    heal = { name = "治愈之光", charge = 30, desc = "全队回复 28% 最大生命，并解除眩晕" },
    hex = { name = "虚弱诅咒", charge = 30, desc = "诅咒目标周围的敌人 6 秒：受到的伤害 +30%，造成的伤害 -30%；同时造成 80% 伤害" },
    shockwave = { name = "战魂震荡", charge = 28, desc = "对前方扇形内的敌人造成 180% 伤害，把它们击退并眩晕 0.6 秒" },
    behead = { name = "斩首", charge = 30, desc = "造成 280% 伤害；目标生命低于 35% 时直接斩杀（首领改为 500% 伤害）" },
    barrage = { name = "乱射", charge = 28, desc = "向随机敌人连射 8 箭，每箭 100% 伤害，同样会弹射" },
    turret = { name = "部署炮塔", charge = 30, desc = "部署一座不会移动的弩炮塔（射程远，每秒 2.5 发，每发 50% 攻击），最多 2 座；满了改为修好炮塔并让它们狂热 4 秒" },
    timestop = { name = "时间静止", charge = 30, desc = "所有敌人静止 1.6 秒（首领 0.8 秒），全队狂热 2.5 秒" },
    blackhole = { name = "黑洞", charge = 34, desc = "在目标处制造持续 3 秒的黑洞，把周围敌人吸向中心，每 0.5 秒造成 50% 伤害，结束时爆炸造成 150% 伤害" },
    giant = { name = "泰坦化身", charge = 25, desc = "变成巨人 6 秒并回复 15% 生命：体型翻倍，受到的伤害再 -20%，攻击 +30%，攻速 -13%；每一击都震地，对周围造成伤害并眩晕 0.4 秒" },
    sanctuary = { name = "圣域降临", charge = 30, desc = "复活一名阵亡的队友（60% 生命），并给全队加上 35% 最大生命的护盾" },
    starfall = { name = "星落", charge = 34, desc = "给每个敌人各降下一道星光，造成 150% 伤害并眩晕 0.4 秒" },
    shadowclone = { name = "影分身", charge = 30, desc = "召唤 2 个影分身（75% 攻击、50% 生命、同样会闪避，持续 12 秒）；分身还在时改为让自己和分身狂热 4 秒" },
    elements = { name = "元素风暴", charge = 30, desc = "依次轮流释放：陨火（320% 并灼烧）→ 冰封（200%，冻结 2 秒）→ 雷链（首击 260%，弹射 6 次）" },
    legion = { name = "亡者狂潮", charge = 34, desc = "召唤 2 个亡骨仆从（最多 5 个），并让所有仆从回满生命、狂热 5 秒" },
    rally = { name = "督战", charge = 34, desc = "所有敌人狂热 3 秒" },
    mend = { name = "死灵治愈", charge = 30, desc = "治疗生命比例最低的敌人 30% 最大生命，其他敌人回复 8%" },
    lavapool = { name = "熔岩池", charge = 30, desc = "掷出熔岩弹，在落点留下持续 4 秒的灼烧地面" },
    forge = { name = "熔铸护盾", charge = 30, desc = "所有敌人获得 25% 最大生命的护盾" },
    fissure = { name = "地裂", charge = 34, desc = "预警后沿直线喷发熔岩，造成 180% 伤害并灼烧" },
    charm = { name = "魅惑", charge = 20, desc = "让攻击最高的敌方单位倒戈 3 秒" },
    rift = { name = "虚空新星", charge = 30, desc = "标记 3 个单位，1.2 秒后在脚下爆炸，造成 160% 伤害" },
    pounce = { name = "扑杀", charge = 25, desc = "跃向生命比例最低的敌人，造成 220% 伤害；击杀则返还 50 能量" },
    rend = { name = "撕裂", charge = 25, desc = "向目标连抓 3 次，每次 80% 伤害，并使其流血 3 秒" },
    ambush = { name = "伏击", charge = 28, desc = "闪现到生命最低的敌人身后，造成 300% 伤害且必定暴击" },
    tigerroar = { name = "虎啸", charge = 30, desc = "自身狂热 6 秒（攻速翻倍）并回复 20% 生命，附近敌人眩晕 0.8 秒" },
    roar = { name = "熊吼", charge = 24, desc = "嘲讽附近的敌人，自身 4 秒内受到的伤害 -35%，并回复 10% 生命" },
    quake = { name = "裂地", charge = 30, desc = "震击周围，造成 130% 伤害并眩晕 0.8 秒" },
    hibernate = { name = "冬眠", charge = 30, desc = "给自己加上 40% 最大生命的护盾并回复 25% 生命，5 秒内受到的伤害 -40%" },
    frostroar = { name = "寒息怒吼", charge = 34, desc = "横扫周围敌人：造成 100% 伤害，减速 50% 持续 4 秒并眩晕 0.6 秒，同时嘲讽它们" },
    bearhug = { name = "熊抱", charge = 30, desc = "冲向攻击最高的敌人，造成 250% 伤害并眩晕 2 秒（首领 0.8 秒），回复 20% 生命" },
    spore = { name = "孢子云", charge = 28, desc = "孢子在目标处炸开：范围内的敌人受到 70% 伤害、叠加 2 层剧毒，并减速 30% 持续 3 秒" },
    entangle = { name = "缠绕", charge = 28, desc = "藤蔓缠住目标周围的敌人：造成 70% 伤害并眩晕 1.2 秒（首领 0.6 秒）" },
    virulence = { name = "毒爆", charge = 30, desc = "引爆所有中毒的敌人：每层剧毒造成 70% 攻击的伤害并清空毒层；没有人中毒时先给目标叠 3 层" },
    seedling = { name = "播种", charge = 30, desc = "种下 1 株毒花苗（不会移动，会喷射毒液），最多 3 株；满了改为治疗花苗并让它们狂热 4 秒" },
    plague = { name = "瘟疫", charge = 34, desc = "对全场敌人叠加 4 层剧毒，并使其受到的伤害 +20%，持续 6 秒" },
    devour = { name = "吞噬", charge = 30, desc = "吞噬生命最低的敌人：造成 300% 伤害；非首领且生命低于 40% 则直接吞掉，全队回复 12% 生命" },
    sunburst = { name = "阳光普照", charge = 30, desc = "全队回复 15% 最大生命，解除眩晕并狂热 2 秒" },
    moonlight = { name = "月华", charge = 32, desc = "所有敌人沉睡眩晕 1.5 秒（首领 0.7 秒），我方全队回复 12% 生命" },
    bloom = { name = "繁花", charge = 30, desc = "给全队种下花种：5 秒内每秒回复 6% 最大生命" },
    solarflare = { name = "日耀", charge = 34, desc = "日光灼烧全场：对每个敌人造成 110% 伤害并灼烧 3 秒，我方全队回复 8% 生命" },
    crimsonmoon = { name = "血月斩", charge = 28, desc = "向前方挥出巨大的血色月牙：对前方大范围内的所有敌人造成 320% 伤害并流血 4 秒，回复造成伤害的 25%" },
    bloodarrow = { name = "赤月天罚", charge = 30, desc = "拉满长弓射出血月巨箭：贯穿直线上的所有敌人，造成 450% 伤害，并让它们 6 秒内受到的伤害 +35%" },
    bloodmoon = { name = "血月降临", charge = 32, desc = "血月当空：每个敌人头上各落下一道血光，造成 240% 伤害并灼烧 4 秒；我方全队狂热 3 秒（攻速翻倍）" },
    bloodrush = { name = "百裂血爪", charge = 28, desc = "化作血影连扑 5 次：每次扑向生命比例最低的敌人，造成 220% 伤害且必定暴击" },
    doomstomp = { name = "末日践踏", charge = 30, desc = "跃起砸地：对周围大范围内的敌人造成 260% 伤害、眩晕 2 秒（首领 1 秒）并嘲讽它们，自身获得 40% 最大生命的护盾" },
    bloodthorn = { name = "血棘之海", charge = 32, desc = "血色荆棘从每个敌人脚下穿出：造成 180% 伤害，叠加 4 层剧毒并缠绕 1.5 秒（首领 0.6 秒）；造成伤害的 30% 平分给全队回复" },
    rebirth = { name = "赤阳涅槃", charge = 34, desc = "全队回复 30% 生命并狂热 4 秒，烈日灼烧所有敌人，造成 120% 伤害；每场战斗第一次释放时，还会复活所有阵亡的队友（50% 生命）" },
}

-- 原版的函数字段在下方手工移植。
---@param n number
---@return string[]
function Data.BossWave(n)
    if n >= 14 then return { "boss", "orcwar", "orc", "skelarcher", "darkmage", "lichpriest" } end
    if n >= 12 then return { "boss", "orc", "orc", "skelarcher", "darkmage", "lichpriest" } end
    return { "boss", "orc", "orc", "skelarcher", "darkmage" }
end

---@param n number
---@return string[]
function Data.BossWave2(n)
    if n >= 14 then return { "colossus", "obsidian", "obsidian", "ashblade", "pyromancer", "forgepriest" } end
    if n >= 12 then return { "colossus", "obsidian", "ashblade", "pyromancer", "forgepriest" } end
    return { "colossus", "obsidian", "magmaslime", "pyromancer" }
end

---@param n number
---@return string[]
function Data.BossWave3(n)
    if n >= 14 then return { "voidlord", "mirrorguard", "mirrorguard", "phaser", "hooker", "charmer" } end
    if n >= 12 then return { "voidlord", "mirrorguard", "phaser", "hooker", "charmer" } end
    return { "voidlord", "mirrorguard", "cultist", "charmer" }
end

Data.CHAPTERS[1].boss = Data.BossWave
Data.CHAPTERS[2].boss = Data.BossWave2
Data.CHAPTERS[3].boss = Data.BossWave3
Data.CHAPTERS[1].bossWarn = function(d)
    return "深渊魔王会带着护卫出场。" .. ((d.adds or 0) > 0 and ("魔王生命过半时会召唤 " .. d.adds .. " 个亡灵。") or "")
end
Data.CHAPTERS[2].bossWarn = function(d)
    return "熔核巨像会带着护卫出场。它 60% 生命时退回熔炉，召唤 3 根熔岩晶柱并进入无敌，先打碎晶柱；30% 生命时暴走" .. ((d.adds or 0) > 0 and ("，召唤 " .. d.adds .. " 个援军") or "") .. "。"
end
Data.CHAPTERS[3].bossWarn = function(d)
    return "虚空之主会带着护卫出场。它 66% 生命时复制你攻击最高的 " .. (d.adds or 0) .. " 个单位；33% 生命时开始 6 秒「虚空坍缩」吟唱并套上护盾，倒计时结束前打破护盾就能打断，否则全场受到重创。"
end

Data.DIFFS = { Data.DIFFS1, Data.DIFFS2, Data.DIFFS3 }
Data.CLASS_SYM = {}
for sym, cls in pairs(Data.SYM_CLASS) do Data.CLASS_SYM[cls] = sym end
for i, chapter in ipairs(Data.CHAPTERS) do
    chapter.waves = i == 1 and Data.WAVES or (i == 2 and Data.WAVES2 or Data.WAVES3)
    chapter.diffs = Data.DIFFS[i]
    chapter.enemies = Data.ENEMIES
end
for _, branch in pairs(Data.SUPER_OF) do Data.BRPAL[branch] = Data.SUP_PAL end

---@param w number
---@return number
function Data.WaveMult(w)
    return 1 + 0.24 * (math.min(w, 10) - 1) + 0.18 * math.max(0, w - 10)
end

---@param d table
---@param w number
---@return number
function Data.DiffMult(d, w)
    return 1 + (d.mult - 1) * (0.5 + 0.5 * (w - 1) / (d.waves - 1))
end

---@param ch number
---@param diff number
---@return number
function Data.SoulPerWave(ch, diff)
    return math.max(1, math.floor(Data.SOUL_BASE * (Data.SOUL_CH --[[@as number[] ]])[ch] * (Data.SOUL_DIFF --[[@as number[] ]])[diff] + 0.5))
end

---@param s table|nil
---@return string[]
function Data.ValidSquad(s)
    local selected, out = {}, {}
    if type(s) == "table" then
        for _, cls in ipairs(s) do if Data.CLASSES[cls] then selected[cls] = true end end
        for _, cls in ipairs(Data.CLASS_KEYS) do if selected[cls] then out[#out + 1] = cls end end
    end
    if #out ~= Data.SQUAD_N then return { "warrior", "archer", "mage" } end
    return out
end

---@param squad string[]
---@return table<string, number>
function Data.SquadWeights(squad)
    ---@type table<string, number>
    local weights = {}
    local sum = 0
    for _, cls in ipairs(squad) do sum = sum + Data.SYM_WEIGHT[Data.CLASS_SYM[cls]] end
    for _, cls in ipairs(squad) do
        local sym = Data.CLASS_SYM[cls]
        weights[sym] = Data.SYM_WEIGHT[sym] * Data.SQUAD_SUM / sum
    end
    weights.S = Data.SYM_WEIGHT.S
    return weights
end

---@param squad string[]
---@return string[]
function Data.SquadGrid(squad)
    local a, b, c = Data.CLASS_SYM[squad[1]], Data.CLASS_SYM[squad[2]], Data.CLASS_SYM[squad[3]]
    return { a, b, c, c, "S", a, b, a, c }
end

---@param u table|false|nil
---@return boolean
function Data.IsSup(u)
    return not not (u and u.branch and Data.BRANCHES[u.branch] and Data.BRANCHES[u.branch].sup)
end

---@param u table
---@return string
function Data.UnitName(u)
    return u.branch and Data.BRANCHES[u.branch].name or (Data.CLASSES[u.cls].name .. string.rep("★", u.star))
end

---@param u table
---@return string
function Data.FullName(u)
    return ((u.q or 1) > 1 and Data.QUAL[u.q].name or "") .. Data.UnitName(u)
end

---@param cls string
---@param q number
---@return string
function Data.RouteNames(cls, q)
    local names = {}
    for _, key in ipairs(Data.CLASS_BRANCHES[cls][q] or {}) do names[#names + 1] = Data.BRANCHES[key].name end
    return table.concat(names, "、")
end

Data.AFFIXES[1].fmt = function(v) return "攻击 +" .. v .. "%" end
Data.AFFIXES[2].fmt = function(v) return "生命 +" .. v .. "%" end
Data.AFFIXES[3].fmt = function(v) return "攻速 +" .. v .. "%" end
Data.AFFIXES[4].fmt = function(v) return "暴击率 +" .. v .. "%" end
Data.AFFIXES[5].fmt = function(v) return "吸血 " .. v .. "%" end

-- 强化等级是从 0 开始的数量，费用、概率和列表索引均从 1 开始。
Data.UPG[1].txt = function(l) return "开局 +" .. l .. " 金币" end
Data.UPG[2].txt = function(l) return l > 0 and ("每付费拉杆 " .. Data.CHEAP_EVERY[l + 1] .. " 次，送 1 次免费拉杆") or "还没有集点" end
Data.UPG[3].txt = function(l) return "战后利息最多 " .. (3 + l) .. " 金币" end
Data.UPG[4].txt = function(l) return l > 0 and "每局送 1 次免费拉杆" or "没有免费拉杆" end
Data.UPG[5].txt = function(l) return string.format("每格出现 ★ 的概率 %.1f%%", (Data.SYM_WEIGHT.S + l) / (Data.SQUAD_SUM + Data.SYM_WEIGHT.S + l) * 100) end
Data.UPG[6].txt = function(l) return string.format("召唤出稀有及以上的占比 %g%%", math.floor((100 - Data.Q_ODDS[1] - Data.Q_SHIFT[1] * l) * 10 + 0.5) / 10) end
Data.UPG[7].txt = function(l) return "幸运最多积累 " .. (3 + l) .. " 点" end
Data.UPG[8].txt = function(l) return "全员生命 +" .. (l * 2) .. "%" end
Data.UPG[9].txt = function(l) return "全员攻击 +" .. (l * 2) .. "%" end

return Data
