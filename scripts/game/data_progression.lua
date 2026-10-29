-- 路线索引、波次、强化与渲染配置；机械拆自 data.lua，表内容保持原样。
local A = require("game.compat").A

---@param D table<string, any>
return function(D)
D.CLASS_BRANCHES = {
  warrior = A(A("berserker"), A("banner", "avenger", "paladin"), A("undying", "conqueror", "dragoon"), A("titan", "seraph", "blademaster")),
  archer = A(A("ranger"), A("venom", "hunter", "windrunner"), A("arbalist", "engineer", "beastmaster"), A("starfall", "shadow", "sniper")),
  mage = A(A("pyro"), A("cleric", "hexer", "necro"), A("chrono", "voidcaller", "frost"), A("archmage", "lich", "storm")),
  tiger = A(A("claw"), A("bloodfang", "shadowcat"), A("whitetiger", "hungrytiger"), A("tigerspirit", "sabre")),
  bear = A(A("brute"), A("ironback", "frenzybear"), A("hibernator", "mountain"), A("polarking", "bearking")),
  flytrap = A(A("vine"), A("strangler", "plaguebloom"), A("corroder", "mother"), A("pandemic", "devourer")),
  sunflower = A(A("sunny"), A("photosyn", "rose"), A("moonbloom", "lifebloom"), A("sungod", "solar"))
}

D.SUPER_OF = {
  warrior = "sup_warrior",
  archer = "sup_archer",
  mage = "sup_mage",
  tiger = "sup_tiger",
  bear = "sup_bear",
  flytrap = "sup_flytrap",
  sunflower = "sup_sunflower"
}

D.WAVES = A(
  A("slime", "slime", "slime"),
  A("slime", "slime", "slime", "skeleton"),
  A("skeleton", "skeleton", "slime", "slime", "skelarcher"),
  A("skeleton", "skeleton", "skeleton", "skelarcher", "skelarcher"),
  A("orc", "skeleton", "skeleton", "skelarcher", "skelarcher"),
  A("skeleton", "skeleton", "skeleton", "skeleton", "skelarcher", "skelarcher", "darkmage"),
  A("orc", "orc", "skeleton", "skeleton", "skelarcher", "darkmage"),
  A("orc", "orc", "orc", "skelarcher", "skelarcher", "darkmage", "darkmage"),
  A("orc", "orc", "orc", "skeleton", "skeleton", "skelarcher", "skelarcher", "darkmage", "darkmage"),
  A("orc", "orc", "orc", "skeleton", "skeleton", "skelarcher", "skelarcher", "darkmage", "darkmage", "lichpriest"),
  A("orcwar", "orc", "orc", "skeleton", "skeleton", "skelarcher", "skelarcher", "darkmage", "lichpriest"),
  A("orcwar", "orc", "orc", "orc", "skelarcher", "skelarcher", "skelarcher", "darkmage", "darkmage", "lichpriest"),
  A("orcwar", "orcwar", "orc", "orc", "skeleton", "skelarcher", "skelarcher", "darkmage", "lichpriest", "lichpriest"),
  A("orcwar", "orcwar", "orc", "orc", "orc", "skelarcher", "skelarcher", "darkmage", "darkmage", "lichpriest"),
  A("orcwar", "orcwar", "orcwar", "orc", "skelarcher", "skelarcher", "darkmage", "darkmage", "lichpriest", "lichpriest")
)

D.WAVES2 = A(
  A("magmaslime", "magmaslime"),
  A("magmaslime", "magmaslime", "bomber"),
  A("obsidian", "magmaslime", "magmaslime", "bomber"),
  A("obsidian", "magmaslime", "bomber", "bomber", "pyromancer"),
  A("obsidian", "obsidian", "ashblade", "pyromancer", "pyromancer"),
  A("obsidian", "magmaslime", "magmaslime", "ashblade", "ashblade", "pyromancer", "forgepriest"),
  A("obsidian", "obsidian", "bomber", "bomber", "ashblade", "pyromancer", "forgepriest"),
  A("obsidian", "obsidian", "magmaslime", "magmaslime", "ashblade", "pyromancer", "pyromancer", "forgepriest"),
  A("obsidian", "obsidian", "obsidian", "bomber", "bomber", "ashblade", "pyromancer", "pyromancer", "forgepriest"),
  A("obsidian", "obsidian", "magmaslime", "magmaslime", "ashblade", "ashblade", "pyromancer", "pyromancer", "forgepriest", "forgepriest"),
  A("obsidian", "obsidian", "obsidian", "bomber", "bomber", "ashblade", "ashblade", "pyromancer", "pyromancer", "forgepriest"),
  A("obsidian", "obsidian", "obsidian", "magmaslime", "magmaslime", "ashblade", "ashblade", "pyromancer", "forgepriest", "forgepriest"),
  A("obsidian", "obsidian", "obsidian", "obsidian", "bomber", "bomber", "ashblade", "ashblade", "pyromancer", "forgepriest"),
  A("obsidian", "obsidian", "obsidian", "magmaslime", "magmaslime", "bomber", "ashblade", "ashblade", "pyromancer", "forgepriest"),
  A("obsidian", "obsidian", "obsidian", "obsidian", "bomber", "bomber", "ashblade", "ashblade", "pyromancer", "forgepriest")
)

D.WAVES3 = A(
  A("cultist", "cultist"),
  A("cultist", "cultist", "voidleech"),
  A("mirrorguard", "cultist", "voidleech"),
  A("mirrorguard", "cultist", "hooker", "voidleech"),
  A("mirrorguard", "mirrorguard", "phaser", "hooker", "charmer"),
  A("mirrorguard", "cultist", "cultist", "phaser", "voidleech", "voidleech", "charmer"),
  A("mirrorguard", "mirrorguard", "phaser", "phaser", "hooker", "voidleech", "charmer"),
  A("mirrorguard", "mirrorguard", "cultist", "cultist", "phaser", "hooker", "hooker", "charmer"),
  A("mirrorguard", "mirrorguard", "mirrorguard", "phaser", "phaser", "voidleech", "voidleech", "hooker", "charmer"),
  A("mirrorguard", "mirrorguard", "cultist", "cultist", "phaser", "phaser", "hooker", "hooker", "charmer", "charmer"),
  A("mirrorguard", "mirrorguard", "mirrorguard", "phaser", "phaser", "voidleech", "voidleech", "hooker", "charmer", "charmer"),
  A("mirrorguard", "mirrorguard", "mirrorguard", "cultist", "cultist", "phaser", "phaser", "hooker", "hooker", "charmer"),
  A("mirrorguard", "mirrorguard", "mirrorguard", "mirrorguard", "phaser", "phaser", "voidleech", "hooker", "charmer", "charmer"),
  A("mirrorguard", "mirrorguard", "mirrorguard", "cultist", "cultist", "phaser", "phaser", "hooker", "charmer", "charmer"),
  A("mirrorguard", "mirrorguard", "mirrorguard", "mirrorguard", "phaser", "phaser", "hooker", "hooker", "charmer", "charmer")
)

D.DIFFS1 = A(
  { name = "普通", color = "#8fe07a", mult = 1, extra = 0, elite = 0, lives = 3, adds = 0, gold = 0, waves = 10, desc = "共 10 波。标准难度，适合熟悉各条转职路线" },
  {
    name = "困难",
    color = "#ffd84a",
    mult = 1.5,
    extra = 1,
    elite = 0,
    lives = 3,
    adds = 0,
    gold = 0,
    waves = 12,
    desc = "共 12 波。敌人逐波增强，最高 +50%；第 3 波起每波多 1 个敌人；后期出现兽人督军和死灵祭司"
  },
  {
    name = "噩梦",
    color = "#ff9b8c",
    mult = 1.85,
    extra = 1,
    elite = 0.25,
    lives = 3,
    adds = 2,
    gold = 3,
    waves = 14,
    desc = "共 14 波。敌人最高 +85%，出现精英敌人；魔王半血时召唤 2 个亡灵；开局多 3 金币"
  },
  {
    name = "炼狱",
    color = "#e09cff",
    mult = 2.15,
    extra = 2,
    elite = 0.35,
    lives = 2,
    adds = 3,
    gold = 8,
    waves = 16,
    desc = "共 16 波。敌人最高 +115%，每波最多多 2 个敌人，精英更多；魔王召唤 3 个亡灵；只有 2 点生命，开局多 8 金币"
  }
)

D.DIFFS2 = A(
  {
    name = "普通",
    color = "#8fe07a",
    mult = 1.15,
    extra = 0,
    elite = 0,
    lives = 3,
    adds = 2,
    gold = 2,
    waves = 10,
    desc = "共 10 波。全新的熔岩敌人，各有机制，整体比第一章同难度更强；开局多 2 金币"
  },
  {
    name = "困难",
    color = "#ffd84a",
    mult = 1.55,
    extra = 1,
    elite = 0.1,
    lives = 3,
    adds = 2,
    gold = 4,
    waves = 12,
    desc = "共 12 波。敌人最高 +55%，第 3 波起每波多 1 个敌人，开始出现精英；开局多 4 金币"
  },
  {
    name = "噩梦",
    color = "#ff9b8c",
    mult = 1.9,
    extra = 1,
    elite = 0.25,
    lives = 3,
    adds = 3,
    gold = 6,
    waves = 14,
    desc = "共 14 波。敌人最高 +90%，精英更多；巨像暴走时召唤 3 个援军；开局多 6 金币"
  },
  {
    name = "炼狱",
    color = "#e09cff",
    mult = 2.3,
    extra = 2,
    elite = 0.35,
    lives = 2,
    adds = 4,
    gold = 10,
    waves = 16,
    desc = "共 16 波。敌人最高 +130%，每波最多多 2 个敌人；巨像召唤 4 个援军；只有 2 点生命，开局多 10 金币"
  }
)

D.DIFFS3 = A(
  {
    name = "普通",
    color = "#8fe07a",
    mult = 1.4,
    extra = 0,
    elite = 0,
    lives = 3,
    adds = 2,
    gold = 3,
    waves = 10,
    desc = "共 10 波。全新的虚空敌人，整体比第二章同难度更强；开局多 3 金币"
  },
  {
    name = "困难",
    color = "#ffd84a",
    mult = 1.9,
    extra = 1,
    elite = 0.1,
    lives = 3,
    adds = 2,
    gold = 5,
    waves = 12,
    desc = "共 12 波。敌人最高 +90%，第 3 波起每波多 1 个敌人，开始出现精英；开局多 5 金币"
  },
  {
    name = "噩梦",
    color = "#ff9b8c",
    mult = 2.3,
    extra = 1,
    elite = 0.25,
    lives = 3,
    adds = 3,
    gold = 8,
    waves = 14,
    desc = "共 14 波。敌人最高 +130%，精英更多；虚空之主复制你 3 个单位；开局多 8 金币"
  },
  {
    name = "炼狱",
    color = "#e09cff",
    mult = 2.75,
    extra = 2,
    elite = 0.35,
    lives = 2,
    adds = 4,
    gold = 12,
    waves = 16,
    desc = "共 16 波。敌人最高 +175%，每波最多多 2 个敌人；虚空之主复制你 4 个单位；只有 2 点生命，开局多 12 金币"
  }
)

D.AFFIXES = A(
  { id = "atk", name = "强攻", min = 10, max = 35 },
  { id = "hp", name = "坚韧", min = 15, max = 45 },
  { id = "spd", name = "迅捷", min = 10, max = 30 },
  { id = "crit", name = "致命", min = 10, max = 30 },
  { id = "leech", name = "嗜血", min = 8, max = 20 }
)

D.AFFIX_GRADE = A(
  { name = "下品", color = "#d8d2c4" },
  { name = "中品", color = "#8fe07a" },
  { name = "上品", color = "#7cc0ff" },
  { name = "极品", color = "#e09cff" }
)

D.QUAL = A(
  { name = "普通", color = "#d8d2c4", base = 1, awaken = 1.3, affix = 0, call = "" },
  { name = "稀有", color = "#5fb4ff", base = 1.15, awaken = 1.45, affix = 0.2, call = "稀有召唤" },
  { name = "史诗", color = "#c77dff", base = 1.3, awaken = 1.6, affix = 0.45, call = "史诗召唤" },
  { name = "传说", color = "#ffa53a", base = 1.5, awaken = 1.8, affix = 0.7, call = "传说降临" },
  { name = "超凡", color = "#ff3b3b", base = 1.75, awaken = 2.1, affix = 0.85, call = "超凡降世" }
)

D.Q_ODDS = A(68, 24, 7, 1)

D.Q_SHIFT = A(-3, 2, 0.75, 0.25)

D.CHEAP_EVERY = A(0, 5, 4)

D.MX_NONE = { gold = 0, cheap = 0, interest = 0, free = 0, star = 0, qual = 0, luck = 0, hp = 0, atk = 0 }

D.UPG_TABS = A(A("eco", "经济", "sym_coin"), A("sum", "召唤", "sym_star"), A("pow", "战力", "sym_sword"), A("human", "人类", "sym_staff"), A("animal", "动物", "sym_tiger"), A("plant", "植物", "sym_flytrap"))

D.UPG = A(
  { id = "gold", tab = "eco", name = "起始金币", icon = "sym_coin", max = 5, cost = A(20, 35, 55, 80, 110), note = "每局开局多拿金币，能多拉几次杆" },
  { id = "cheap", tab = "eco", name = "拉杆集点", icon = "m_lever", max = 2, cost = A(450, 1000), note = "Lv 1：450 军魂，每付费拉杆 5 次送 1 次；Lv 2：1000 军魂，每付费拉杆 4 次送 1 次。免费拉杆不计入集点" },
  { id = "interest", tab = "eco", name = "利息上限", icon = "m_stack", max = 2, cost = A(80, 160), note = "每存 10 金币，战后多得 1 金币；这里提高上限" },
  { id = "free", tab = "eco", name = "开局免费拉杆", icon = "m_ticket", max = 1, cost = A(40), note = "每局第一次拉杆不花金币" },
  { id = "star", tab = "sum", name = "★ 出现率", icon = "sym_star", max = 4, cost = A(30, 55, 85, 125), note = "★ 可以替代任何图标，出现得越多越容易连线" },
  { id = "qual", tab = "sum", name = "高品质召唤", icon = "m_gem", max = 3, cost = A(50, 100, 170), note = "普通连线召唤出稀有、史诗、传说单位的概率更高" },
  { id = "luck", tab = "sum", name = "幸运积累", icon = "m_luck", max = 2, cost = A(60, 130), note = "没中奖会积累幸运，幸运越多 ★ 越容易出现；这里提高幸运上限" },
  { id = "hp", tab = "pow", name = "全员生命", icon = "heart", max = 8, cost = A(50, 90, 150, 240, 330, 440, 570, 720), scale = 0.02, note = "所有参战单位的生命提高，每级 +2%，最高 +16%" },
  { id = "atk", tab = "pow", name = "全员攻击", icon = "sym_sword", max = 8, cost = A(50, 90, 150, 240, 330, 440, 570, 720), scale = 0.02, note = "所有参战单位的攻击提高，每级 +2%，最高 +16%" },
  { id = "hp_warrior", tab = "human", cls = "warrior", stat = "hp", name = "战士生命", icon = "warrior", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化战士（含它的所有转职、晋升与超凡形态）的生命，每级 +1%" },
  { id = "atk_warrior", tab = "human", cls = "warrior", stat = "atk", name = "战士攻击", icon = "warrior", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化战士（含它的所有转职、晋升与超凡形态）的攻击，每级 +1%" },
  { id = "hp_archer", tab = "human", cls = "archer", stat = "hp", name = "射手生命", icon = "archer", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化射手（含它的所有转职、晋升与超凡形态）的生命，每级 +1%" },
  { id = "atk_archer", tab = "human", cls = "archer", stat = "atk", name = "射手攻击", icon = "archer", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化射手（含它的所有转职、晋升与超凡形态）的攻击，每级 +1%" },
  { id = "hp_mage", tab = "human", cls = "mage", stat = "hp", name = "法师生命", icon = "mage", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化法师（含它的所有转职、晋升与超凡形态）的生命，每级 +1%" },
  { id = "atk_mage", tab = "human", cls = "mage", stat = "atk", name = "法师攻击", icon = "mage", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化法师（含它的所有转职、晋升与超凡形态）的攻击，每级 +1%" },
  { id = "hp_tiger", tab = "animal", cls = "tiger", stat = "hp", name = "猛虎生命", icon = "tiger", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化猛虎（含它的所有转职、晋升与超凡形态）的生命，每级 +1%" },
  { id = "atk_tiger", tab = "animal", cls = "tiger", stat = "atk", name = "猛虎攻击", icon = "tiger", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化猛虎（含它的所有转职、晋升与超凡形态）的攻击，每级 +1%" },
  { id = "hp_bear", tab = "animal", cls = "bear", stat = "hp", name = "巨熊生命", icon = "bear", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化巨熊（含它的所有转职、晋升与超凡形态）的生命，每级 +1%" },
  { id = "atk_bear", tab = "animal", cls = "bear", stat = "atk", name = "巨熊攻击", icon = "bear", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化巨熊（含它的所有转职、晋升与超凡形态）的攻击，每级 +1%" },
  { id = "hp_flytrap", tab = "plant", cls = "flytrap", stat = "hp", name = "食人花生命", icon = "flytrap", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化食人花（含它的所有转职、晋升与超凡形态）的生命，每级 +1%" },
  { id = "atk_flytrap", tab = "plant", cls = "flytrap", stat = "atk", name = "食人花攻击", icon = "flytrap", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化食人花（含它的所有转职、晋升与超凡形态）的攻击，每级 +1%" },
  { id = "hp_sunflower", tab = "plant", cls = "sunflower", stat = "hp", name = "向日葵生命", icon = "sunflower", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化向日葵（含它的所有转职、晋升与超凡形态）的生命，每级 +1%" },
  { id = "atk_sunflower", tab = "plant", cls = "sunflower", stat = "atk", name = "向日葵攻击", icon = "sunflower", max = 5, cost = A(60, 100, 150, 220, 300), scale = 0.01, note = "只强化向日葵（含它的所有转职、晋升与超凡形态）的攻击，每级 +1%" }
)

D.SOUL_CH = A(1, 1.3, 1.6, 2, 2.4)

D.SOUL_DIFF = A(1, 1.5, 2, 2.5)

D.FONT = {
  ["0"] = A("111", "101", "101", "101", "111"),
  ["1"] = A("010", "110", "010", "010", "111"),
  ["2"] = A("111", "001", "111", "100", "111"),
  ["3"] = A("111", "001", "111", "001", "111"),
  ["4"] = A("101", "101", "111", "001", "001"),
  ["5"] = A("111", "100", "111", "001", "111"),
  ["6"] = A("111", "100", "111", "101", "111"),
  ["7"] = A("111", "001", "010", "010", "010"),
  ["8"] = A("111", "101", "111", "101", "111"),
  ["9"] = A("111", "101", "111", "001", "111"),
  ["+"] = A("000", "010", "111", "010", "000"),
  ["-"] = A("000", "000", "111", "000", "000"),
  ["!"] = A("010", "010", "010", "000", "010"),
  M = A("101", "111", "111", "101", "101"),
  I = A("111", "010", "010", "010", "111"),
  S = A("111", "100", "111", "001", "111"),
  ["^"] = A("010", "111", "111", "010", "010")
}

D.ATK_STYLE_CLS = { warrior = "slash", archer = "bow", mage = "cast", tiger = "claw", bear = "maul", flytrap = "spit", sunflower = "bloom" }

D.ATK_STYLE_BR = { dragoon = "thrust", conqueror = "thrust", titan = "maul" }

D.ATK_STYLE_EN = {
  slime = "bounce",
  skeleton = "slash",
  skelarcher = "bow",
  orc = "maul",
  darkmage = "cast",
  boss = "maul",
  orcwar = "maul",
  lichpriest = "cast",
  magmaslime = "bounce",
  magmalet = "bounce",
  bomber = "bounce",
  obsidian = "maul",
  ashblade = "slash",
  pyromancer = "cast",
  forgepriest = "cast",
  pillar = "pulse",
  colossus = "maul",
  voidleech = "bounce",
  mirrorguard = "slash",
  hooker = "slash",
  charmer = "cast",
  phaser = "claw",
  cultist = "claw",
  voidlord = "cast"
}

D.BOW_RIG = {
  archer = { a = A(13, 4), b = A(13, 11), n = A(13, 8), m = "5:12-13 6:12-13 7:12-13 8:10-13 9:12-13 10:12-13", hd = "8:10-11", pull = 4, len = 8 },
  sniper = { a = A(13, 4), b = A(13, 11), n = A(13, 8), m = "5:12-13 6:12-13 7:12-13 8:10-13 9:12-13 10:12-13", hd = "8:10-11", pull = 4, len = 8 },
  ranger = { a = A(13, 4), b = A(13, 11), n = A(13, 8), m = "5:12-13 6:12-13 7:12-13 8:10-13 9:12-13 10:12-13", hd = "8:10-11", pull = 4, len = 8 },
  windrunner = { a = A(13, 4), b = A(13, 11), n = A(13, 8), m = "5:12-13 6:12-13 7:12-13 8:10-13 9:12-13 10:12-13", hd = "8:10-11", pull = 4, len = 8 },
  beastmaster = {
    a = A(13, 3),
    b = A(13, 11),
    n = A(13, 8),
    m = "4:12-13 5:12-13 6:12-13 7:12-13 8:10-13 9:12-13 10:12-13",
    hd = "8:10-11",
    pull = 4,
    len = 8
  },
  skelarcher = {
    a = A(14, 4),
    b = A(13, 12),
    n = A(13, 8),
    m = "5:13-14 6:12-13 7:12-13 8:12-13 9:12-13 10:12-13 11:12-13",
    hd = "8:12-13",
    pull = 4,
    len = 8
  },
  sup_archer = {
    a = A(15, 1),
    b = A(15, 17),
    n = A(15, 10),
    hd = "10:12-13",
    pull = 5,
    len = 11,
    m = "2:14-15 3:14-15 4:14-15 5:14-15 6:14-15 7:14-15 8:14-15 9:14-15 10:14-15 11:14-15 12:14-15 13:14-15 14:14-15 15:14-15 16:14-15 10:12-13"
  }
}

D.ATK_POSE = {
  slash = { w = { x = -1, lean = -2 }, h = { x = 2, lean = 3 } },
  thrust = { w = { x = -2, lean = -1 }, h = { x = 4, lean = 1 } },
  maul = { w = { x = -1, lean = -2, sy = 1.12 }, h = { x = 2, lean = 3, sx = 1.1, sy = 0.88 } },
  claw = { w = { x = -1, sx = 1.12, sy = 0.82 }, h = { x = 4, lean = 2, hop = 3 } },
  bounce = { w = { sx = 1.2, sy = 0.75 }, h = { x = 3, sx = 0.88, sy = 1.18, hop = 2 } },
  bow = { w = { x = -1, lean = -1 }, h = { x = -2, lean = -1 } },
  recoil = { w = {}, h = { x = -2 } },
  cast = { w = { y = -1, lean = -1, sy = 1.07 }, h = { x = 1, lean = 2 } },
  spit = { w = { x = -1, lean = -2, sx = 0.88 }, h = { x = 2, lean = 3, sx = 1.12 } },
  bloom = { w = { sx = 1.1, sy = 0.88 }, h = { y = -1, sx = 0.92, sy = 1.12 } },
  pulse = { w = { sx = 1.06, sy = 0.92 }, h = { sx = 0.96, sy = 1.08 } }
}

D.WEAPON_RIG = {
  warrior = { k = "blade", p = A(11.5, 11.5), t = A(15, 7.5), m = "7:14-15 8:13-15 9:12-14 10:11-13 11:11-12 12:11-12" },
  paladin = { k = "blade", p = A(12.5, 9.5), t = A(14.5, 4.5), m = "4:14 5:13-15 6:13-15 7:12-14 8:12-13 9:12-13 10:12" },
  seraph = { k = "blade", p = A(12.5, 9.5), t = A(14.5, 4.5), m = "4:14 5:13-15 6:13-15 7:12-14 8:12-13 9:12-13 10:12" },
  berserker = {
    k = "heavy",
    p = A(13.5, 10.5),
    t = A(14, 2.5),
    m = "1:13-14 2:12-15 3:12-15 4:12-15 5:13-15 6:13-15 7:13-15 8:13-15 9:13-14 10:13-14 11:13-14 12:13-15 13:14-15"
  },
  blademaster = {
    k = "blade",
    p = A(14.5, 11.5),
    t = A(14.5, 0.5),
    m = "0:14 1:13-15 2:13-15 3:13-15 4:13-15 5:13-15 6:13-15 7:13-15 8:13-15 9:13-15 10:13-15 11:14-15 12:13-15 13:14"
  },
  dragoon = {
    k = "spear",
    p = A(13.5, 9.5),
    t = A(14.5, 0.5),
    m = "0:14 1:14-15 2:13-15 3:13-15 4:13-15 5:13-15 6:13-15 7:13-15 8:13-15 9:13-14 10:13-15 11:13-15 12:13-15 13:13-15 14:14-15"
  },
  skeleton = { k = "blade", p = A(12.5, 10.5), t = A(13.5, 6.5), m = "6:13 7:12-14 8:12-14 9:12-14 10:11-13 11:11-12" },
  orc = { k = "heavy", p = A(14.5, 9.5), t = A(14, 4.5), m = "3:13-14 4:13-15 5:13-15 6:13-15 7:14-15 8:14-15 9:14-15 10:14-15 11:14-15 12:14-15" },
  ashblade = { k = "blade", p = A(12.5, 8.5), t = A(14, 6.5), m = "6:14 7:12-14 8:12-13" },
  hooker = { k = "blade", p = A(12.5, 7.5), t = A(14, 4.5), m = "3:12-14 4:12-15 5:13-15 6:12 6:14-15 7:12-15 8:13-14" },
  mage = {
    k = "staff",
    p = A(13.5, 10.5),
    t = A(14.5, 5.5),
    m = "4:13-14 5:13-15 6:13-15 7:13-15 8:12-14 9:12-14 10:13-14 11:13-14 12:13-14 13:13-14 14:13-14"
  },
  pyro = {
    k = "staff",
    p = A(13.5, 10.5),
    t = A(14.5, 5.5),
    m = "2:13 3:13 4:13-14 5:13-15 6:13-15 7:13-15 8:12-14 9:12-14 10:13-14 11:13-14 12:13-14 13:13-14 14:13-14"
  },
  necro = {
    k = "staff",
    p = A(13.5, 10.5),
    t = A(14.5, 5.5),
    m = "3:13 4:13-14 5:13-15 6:13-15 7:13-15 8:12-14 9:12-14 10:13-14 11:13-14 12:13-14 13:13-14 14:13-14"
  },
  frost = {
    k = "staff",
    p = A(13.5, 10.5),
    t = A(14, 4.5),
    m = "2:13 3:12-14 4:12-15 5:13-15 6:13-15 7:13-15 8:12-14 9:12-14 10:13-14 11:13-14 12:13-14 13:13-14 14:13-14"
  },
  storm = {
    k = "staff",
    p = A(13.5, 10.5),
    t = A(14, 3.5),
    m = "1:13 2:12-14 3:12-14 4:12-15 5:13-15 6:13-15 7:13-15 8:12-14 9:12-14 10:13-14 11:13-14 12:13-14 13:13-14 14:13-14"
  },
  darkmage = { k = "staff", p = A(13.5, 10.5), t = A(13.5, 5.5), m = "4:13 5:13-14 6:13-14 7:13-14 8:13-14 9:13-14 10:13-14 11:13-14 12:13-14 13:14" },
  forgepriest = {
    k = "staff",
    p = A(13.5, 9.5),
    t = A(13.5, 3.5),
    m = "2:12-14 3:11-15 4:11-15 5:12-14 6:12-14 7:12-14 8:13-14 9:13-14 10:13-14 11:13-14 12:13-14"
  },
  charmer = { k = "staff", p = A(13.5, 9.5), t = A(13.5, 5.5), m = "5:12-15 6:12-15 7:13-14 8:13-15 9:13-15 10:14-15 11:14" },
  tiger = { k = "paw", p = A(11.5, 10.5), t = A(14.5, 11), m = "9:12-13 10:12-14 11:12-15 12:13-14" },
  bear = { k = "paw", p = A(11.5, 10.5), t = A(14, 11.5), m = "9:12-14 10:12-15 11:12-15 12:12-15 13:12-14" },
  sup_warrior = {
    k = "heavy",
    p = A(16.5, 11.5),
    t = A(16.5, 0.5),
    m = "0:16 1:15-17 2:15-18 3:15-18 4:15-18 5:15-18 6:15-18 7:15-18 8:15-18 9:15-18 10:14-19 11:15-18 12:15-17 13:16"
  },
  sup_mage = {
    k = "staff",
    p = A(16.5, 10.5),
    t = A(16.5, 2.5),
    m = "0:16 1:15-17 2:14-18 3:14-18 4:14-18 5:15-17 6:15-17 7:15-17 8:15-17 9:14-17 10:14-18 11:14-17 12:15-17 13:15-17 14:15-17 15:15-17 16:15-17 17:15-17 18:16"
  },
  sup_tiger = { k = "paw", p = A(15, 13.5), t = A(18.5, 14), m = "12:16-17 13:15-18 14:15-18 15:16-17" },
  sup_bear = { k = "paw", p = A(16, 13.5), t = A(19.5, 13.5), m = "11:16-18 12:16-19 13:16-19 14:16-19 15:16-18" }
}

D.WEAPON_MOVE = {
  blade = { w = -120, h = 35 },
  heavy = { w = -140, h = 60 },
  spear = { w = -8, h = 0, pw = -3, ph = 5 },
  staff = { w = -112, h = -40 },
  paw = { w = -75, h = 45 }
}

D.ATK_EN_COL = {
  slime = "#7bd36a",
  magmaslime = "#ff8a2a",
  magmalet = "#ff8a2a",
  bomber = "#ffb03a",
  voidleech = "#7fe0e8",
  mirrorguard = "#9ff6ff",
  ashblade = "#ff5a2a",
  hooker = "#c06bff",
  phaser = "#6ef0ff",
  cultist = "#9be36b",
  obsidian = "#c9a6ff",
  colossus = "#ff8a2a",
  boss = "#ff5a3a",
  orcwar = "#ff9a7a"
}

D.PROJ_COL = { arrow = "#e8d2a8", earrow = "#e8d2a8", parrow = "#9be36b", lavaball = "#ff8a2a", rarrow = "#ff3434" }

D.PROJ_BURST = {
  orb = "#6ef0ff",
  dark = "#c06bff",
  frost = "#bff4ff",
  spark = "#ffe14a",
  holy = "#fff3b0",
  prism = "#ffffff",
  fireball = "#ff8a2a",
  bloodorb = "#ff3434",
  sunfire = "#ff8e6a"
}

D.ELEM_NAMES = A("陨火", "冰封", "雷链")

D.STAR_MULT = A(0, 1, 2.1, 4.6)

D.STAR_PTS = A(0, 0, 4, 16)

end
