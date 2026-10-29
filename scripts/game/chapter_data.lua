-- 第四、五章的增量数据；由 game.data 在基础表初始化完成后调用。
-- 通过参数扩展数据，不进入共享 _ENV，也不反向 require game.data，避免循环依赖。
local A = require("game.compat").A

---@param D table
return function(D)
  -- ---------- 第四章「霜狱冰原」/ 第五章「星陨神殿」的像素精灵 ----------
  D.PAL.i = "#bfe8ff"; D.PAL.I = "#7cc0ff"; D.PAL.j = "#3a6ea8"; D.PAL.n = "#fff6d0"; D.PAL.N = "#b8892a"; D.PAL.q = "#5a4a9a"
  D.SPR.frostwisp = A(
    "................",
    ".......kk.......",
    "......kiik......",
    ".....kiOiIk.....",
    "....kiOiiiIk....",
    "...kiiiiiiiIk...",
    "...kikoiikoIk...",
    "...kiikkiikIk...",
    "...kIiiiiiiIjk..",
    "....kIiiiiIjk...",
    "....kjIiIijk....",
    ".....kjIjIk.....",
    "......kjkjk.....",
    ".......k.jk.....",
    "..........k.....",
    "................"
  )
  D.SPR.icegolem = A(
    "................",
    "....kkkkkkkk....",
    "...kiiiIIIIjk...",
    "...kiOiIIIIjk...",
    "...kiikoIIkoIk..",
    "...kIIIkkIIjk...",
    ".kkkjjjjjjjjkkk.",
    "kiiIkIIiiIIkIIjk",
    "kiIIkIiOiiIkIjjk",
    "kIIjkIIiiIIkjjjk",
    ".kkkkjIIIIjkkkk.",
    "....kjjIIjjk....",
    "...kiIjkkjIik...",
    "...kIIjk.kjIIk..",
    "...kkkkk.kkkkk..",
    "................"
  )
  D.SPR.yeti = A(
    "................",
    ".....kkkkkk.....",
    "....kHHHHHHk....",
    "...kHwwwwwwHk...",
    "...kHkokwokHk...",
    "...kHwwwwwwHk...",
    "..kkHwkeeekwHkk.",
    ".kHHkHHHHHHkHHk.",
    "kHHwkHwwwwHkwHHk",
    "kHwHkHwwwwHkHwHk",
    "khHkkHwwwwHkkHhk",
    ".kk.kHHHHHHk.kk.",
    "....khHHHHhk....",
    "...khHk..kHhk...",
    "...kkkk..kkkk...",
    "................"
  )
  D.SPR.frostshaman = A(
    "......k.........",
    ".....kik....kk..",
    "....kjIjk..kiik.",
    "...kjjjjjk.kIok.",
    "..kkkkkkkkk.kik.",
    "...kssssk...kjk.",
    "..kksosoks..kjk.",
    "..kjkssssk..kjk.",
    ".kjjkkkkkjk.kjk.",
    ".kjIjjjjjIjkkjk.",
    ".kjIjiijjIjk.jk.",
    "kjjIjjiijjIjkjk.",
    "kjIjjjjjjjjIjk..",
    "kjjjjjjjjjjjjk..",
    "kkkkkkkkkkkkkk..",
    "................"
  )
  D.SPR.revenant = A(
    "................",
    ".....kkkkk......",
    "....kiiiiik.....",
    "....kickcik.....",
    "....kcckokk.k...",
    "....kiiiiik.kik.",
    ".....kkCkCk.kik.",
    "......kckk..kik.",
    "...kkkcccck.kik.",
    "..kcckkCkCkkkjk.",
    "..kck.kcck.kNk..",
    "..kk..kCkk.kk...",
    "......kiiik.....",
    ".....kik.kik....",
    ".....kjk.kjk....",
    ".....kkk.kkk...."
  )
  D.SPR.icetomb = A(
    "................",
    "................",
    ".....kkkkkk.....",
    "....kiOiiIIk....",
    "...kiOiiiiIjk...",
    "...kiiicckIjk...",
    "...kiicekcIjk...",
    "...kIicckcIjk...",
    "...kIiickcIjk...",
    "...kIiiiiiIjk...",
    "...kIIiiiIIjk...",
    "...kjIIIIIIjk...",
    "..kkjjjjjjjjkk..",
    ".kiiIIIIIIIIjjk.",
    ".kkkkkkkkkkkkkk.",
    "................"
  )
  D.SPR.iceprison = A(
    "......kkkk......",
    ".....kiOIIk.....",
    "....kiOiiIIk....",
    "...kiOiiiiIjk...",
    "...kiiiiiiIjk...",
    "..kiiiiiiiiIjk..",
    "..kiiiiiiiiIjk..",
    "..kIiiiiiiiIjk..",
    "..kIiiiiiiIIjk..",
    "..kIIiiiiIIjjk..",
    "..kjIIiiIIIjjk..",
    "..kjjIIIIIjjjk..",
    "...kjjjjjjjjk...",
    "..kiIIIIIIIIjk..",
    "..kkkkkkkkkkkk..",
    "................"
  )
  D.SPR.sentinel = A(
    "......kkk.......",
    ".....kNyNk......",
    "....kkgggkk.....",
    "...kgggggggk....",
    "...kgkkkkkgk....",
    "...kgknnnkgk.k..",
    "...kggkkkggkkOk.",
    "..kkNgggggNkkOk.",
    ".kNgkNggggNkkOk.",
    "kgygkNgggNkkkOk.",
    "kgnygkNgggNkkOk.",
    "kgygkkNggNk.kgk.",
    ".kNk.kNNNNk.kNk.",
    "....kNNkNNk.kkk.",
    "....kNNkNNk.....",
    "....kkkkkkk....."
  )
  D.SPR.zealot = A(
    "................",
    ".....kkkkk......",
    "....knnnnnk.....",
    "...knnnnnnyk....",
    "...knkssskyk....",
    "...knksesesk....",
    "...knksssskk..k.",
    "...knnkkknnk.kOk",
    "..knynnnnnnykkOk",
    "..knyrrynnnykOk.",
    ".ksnynnynnnykk..",
    ".kknynnynnnyk...",
    "..knyyynyyyyk...",
    ".knnnnnnnnnnnk..",
    ".kkkkkkkkkkkkk..",
    "................"
  )
  D.SPR.arbiter = A(
    "......kkkk......",
    ".....kyyyyk.....",
    "....kygnngyk....",
    "...kkkkkkkkkk...",
    "....kgkkkkgk....",
    "....kgkeekgk....",
    "....kgkkkkgk....",
    "...kkggggggkk...",
    "..knkgnnnngknk..",
    ".knnkgnyynkgnnk.",
    ".kkkkgnyyngkkkk.",
    "....kgnnnngk....",
    "...kgngnngngk...",
    "...kgnnnnnngk...",
    "...kkkkkkkkkk...",
    "................"
  )
  D.SPR.oracle = A(
    "................",
    "......kkkk......",
    ".....kqqqqk.....",
    "....kqqyyqqk....",
    "...kqqkkkkqqk...",
    "...kqkOOOOkqk...",
    "...kqkkOokkqk...",
    "...kqqkkkkqqk..k",
    "..kqPqqqqqqPqkkO",
    "..kqPqqyyqqPqkyk",
    "..kqPqyOOyqPqk..",
    "..kqPqqyyqqPqk..",
    ".kqqPqqqqqqPqqk.",
    ".kqPPqqqqqqPPqk.",
    ".kkkkkkkkkkkkkk.",
    "................"
  )
  D.SPR.obelisk = A(
    ".......kk.......",
    "......kOyk......",
    "......knyk......",
    ".....knnyNk.....",
    ".....kngyNk.....",
    ".....knyyNk.....",
    ".....kngyNk.....",
    ".....knOyNk.....",
    ".....knyyNk.....",
    ".....kngyNk.....",
    "....kknyyNkk....",
    "...kNnnnyNNNk...",
    "..kNNNNNNNNNNk..",
    "..knnnnnnnnnNk..",
    "..kkkkkkkkkkkk..",
    "................"
  )
  D.SPR.frostqueen = A(
    "........................",
    "..........k..k..........",
    ".........kik.kik........",
    "........kiOkkkiOk.......",
    ".......kIiiiOiiiIk......",
    "......kkkkkkkkkkkkk.....",
    ".......kHwwwwwwHk.......",
    ".......kHkokkokHk.......",
    ".......kHwwwwwwHk.......",
    "......kjkHwkkwHkjk......",
    ".....kjIjkHHHHkjIjk.....",
    "....kjIiIjkkkkjIiIjk....",
    "...kjIiiIIjiijIIiiIjk...",
    "..kiIjkjIIiOOiIIjkjIik..",
    "..kik.kjIiiOOiiIjk.kik..",
    "..kok.kjIiiiiiiIjk.kok..",
    "..kik.kjIIiiiiIIjk.kik..",
    "...k.kjjIIIiiIIIjjk.k...",
    ".....kjIIIIIIIIIIjk.....",
    "....kjIiIIIIIIIIiIjk....",
    "....kjiIjIIjjIIjIijk....",
    "...kjIiIjjIIIIjjIiIjk...",
    "...kkkkkkkkkkkkkkkkkk...",
    "........................"
  )
  D.SPR.astralking = A(
    "........................",
    "......k..k..k..k........",
    ".....kyk.kyk.kyk.k......",
    ".....kykkkykkkykkyk.....",
    "......kyyyyyyyyyyk......",
    "......kNNNNNNNNNNk......",
    ".......kssssssssk.......",
    ".......kskeskeskk.......",
    ".......kssssssssk.......",
    "........kkssssk.........",
    "...kkkkkknnnnnnkkkkkk...",
    "..knnnnyknyyyynkynnnnk..",
    "..knyynkknOOOOnkknyynk..",
    "..knynk.kynOOnyk.knynk..",
    "..kyyk..knyyyynk..kyyk..",
    "..kssk..knnnnnnk..kssk..",
    "...kk..kNnnnnnnNk..kk...",
    ".......kNnyyyynNk.......",
    "......kNnnnnnnnnNk......",
    "......kNnNnnnnNnNk......",
    ".....kNnnNnnnnNnnNk.....",
    ".....kNNNNkkkkNNNNk.....",
    ".....kkkkk....kkkkk.....",
    "........................"
  )

  -- =========================================================
  -- 第四章「霜狱冰原」与第五章「星陨神殿」：敌人、波次、难度
  -- =========================================================
  ---@type table<string, table>
  local E = D.ENEMIES
  E.frostwisp = { ch = 3, name = "冰魄幽灵", sprite = "frostwisp", hp = 64, atk = 9, cd = 1.3, range = 62, speed = 16, r = 5, proj = "frost",
    fx = { chillHit = 1 }, desc = "普攻叠加寒霜，同一个单位叠满 3 层就被冻结 1.2 秒（之后 2.5 秒内不会再被冻）" }
  E.icegolem = { ch = 3, name = "寒冰傀儡", sprite = "icegolem", hp = 280, atk = 15, cd = 1.4, range = 9, speed = 13, r = 6,
    fx = { frostShell = true }, desc = "冰壳：第一次跌破 50% 生命时封进冰壳 2.5 秒，期间无敌、每秒回复 10% 生命，并让身边的单位减速" }
  E.yeti = { ch = 3, name = "雪原巨猿", sprite = "yeti", hp = 170, atk = 13, cd = 1, range = 8, speed = 22, r = 6,
    fx = { fury = 0.06 }, desc = "越打越怒：每次受击狂怒 +1 层（最多 10 层），每层攻击 +6%。要么集火秒掉，要么别慢慢磨" }
  E.frostshaman = { ch = 3, name = "霜语萨满", sprite = "frostshaman", hp = 88, atk = 9, cd = 1.6, range = 62, speed = 14, r = 5, proj = "frost",
    skill = "blizzard", desc = "技能「暴风雪」：在你的阵中降下 4 秒暴风雪，范围内的单位减速 35%、持续受伤并流失技能能量" }
  E.revenant = { ch = 3, name = "冰封亡魂", sprite = "revenant", hp = 100, atk = 14, cd = 1, range = 7, speed = 22, r = 5,
    fx = { tomb = true }, desc = "第一次被击杀时化作冰棺；4 秒内不打碎冰棺，它就以 60% 生命复活" }
  E.icetomb = { ch = 3, name = "冰棺", sprite = "icetomb", hp = 40, atk = 0, cd = 9, range = 0, speed = 0, r = 5,
    fx = { anchor = true, inert = true }, desc = "冰封亡魂留下的冰棺：不会攻击，4 秒内不打碎就会复活亡魂" }
  E.iceprison = { ch = 3, name = "冰牢", sprite = "iceprison", hp = 60, atk = 0, cd = 9, range = 0, speed = 0, r = 6,
    fx = { anchor = true, inert = true }, desc = "冰霜女皇的冰牢：困住你的单位，8 秒内不打碎，里面的单位受到 50% 最大生命的伤害" }
  E.frostqueen = { ch = 3, name = "冰霜女皇", sprite = "frostqueen", hp = 3400, atk = 26, cd = 1.6, range = 70, speed = 10, r = 10, proj = "frost", splash = 14,
    big = true, skill = "frostnova45", fx = { qphases = true, chillHit = 1 },
    desc = "远程冰弹带溅射并叠加寒霜。技能「冰霜新星」：在目标处爆开，伤害并叠 2 层寒霜。70% 生命时「冰封王座」：把你攻击最高的几个单位关进冰牢，8 秒内打碎冰牢才能救出来；35% 生命时「永冬风暴」：攻速翻倍，全场持续暴风雪直到她倒下" }

  E.sentinel = { ch = 4, name = "神殿哨卫", sprite = "sentinel", hp = 230, atk = 16, cd = 1.2, range = 9, speed = 15, r = 6,
    fx = { holyShield = 3 }, desc = "圣盾：完全挡下接下来的 3 次攻击（持续伤害不算），8 秒后圣盾充满。攻速快、多段攻击的单位克制它" }
  E.zealot = { ch = 4, name = "狂信者", sprite = "zealot", hp = 120, atk = 15, cd = 0.95, range = 7, speed = 24, r = 5,
    fx = { martyr = true }, desc = "殉道：死亡时其余敌人回复 15% 生命并狂热 3 秒（攻速翻倍）" }
  E.arbiter = { ch = 4, name = "审判官", sprite = "arbiter", hp = 78, atk = 14, cd = 1.5, range = 72, speed = 14, r = 5, proj = "holy",
    fx = { judge = true }, desc = "审判：总是瞄准生命比例最低的单位，对 40% 生命以下的目标伤害翻倍" }
  E.oracle = { ch = 4, name = "神谕先知", sprite = "oracle", hp = 92, atk = 9, cd = 1.7, range = 64, speed = 13, r = 5, proj = "prism",
    skill = "silence", desc = "技能「神谕沉默」：沉默你能量最高的 3 个单位 4 秒，清空能量且期间无法积攒" }
  E.obelisk = { ch = 4, name = "圣辉方尖碑", sprite = "obelisk", hp = 320, atk = 0, cd = 9, range = 0, speed = 0, r = 6,
    fx = { anchor = true, inert = true, auraDr = 0.35 }, desc = "本身不攻击；周围 60 像素内的其他敌人受到的伤害 -35%。先拆掉它" }
  E.astralking = { ch = 4, name = "星穹神王", sprite = "astralking", hp = 4000, atk = 30, cd = 1.5, range = 10, speed = 12, r = 10, splash = 18,
    big = true, skill = "starfall45", fx = { aphases = true },
    desc = "技能「星陨」：在你的 5 个单位脚下标记星光，1 秒后坠落。60% 生命时立起圣辉方尖碑，碑在时神王每秒回复 1.5% 生命并减伤；30% 生命时「复生圣光」：复活本波阵亡的敌人（最多 6 个，40% 生命）并进入狂热" }

  for _, k in ipairs({ "frostwisp", "icegolem", "yeti", "frostshaman", "revenant", "icetomb", "iceprison", "frostqueen",
    "sentinel", "zealot", "arbiter", "oracle", "obelisk", "astralking" }) do D.ENEMY_KEYS:push(k) end

  D.SKILLS.blizzard = { name = "暴风雪", charge = 30, desc = "在目标处降下 4 秒暴风雪" }
  -- 首领使用独立技能键，不能覆写玩家冰封领域 / 星落的详情与蓄能参数。
  D.SKILLS.frostnova45 = { name = "冰霜新星", charge = 30, desc = "在目标处爆开冰霜" }
  D.SKILLS.silence = { name = "神谕沉默", charge = 30, desc = "沉默能量最高的 3 个单位" }
  D.SKILLS.starfall45 = { name = "星陨", charge = 30, desc = "星光坠落" }

  ---@type table<string, string>
  local ST = D.ATK_STYLE_EN
  ---@type table<string, string>
  local EC = D.ATK_EN_COL
  ST.frostwisp = "cast"; ST.icegolem = "maul"; ST.yeti = "claw"; ST.frostshaman = "cast"; ST.revenant = "slash"; ST.icetomb = "pulse"; ST.iceprison = "pulse"; ST.frostqueen = "cast"
  ST.sentinel = "slash"; ST.zealot = "claw"; ST.arbiter = "cast"; ST.oracle = "cast"; ST.obelisk = "pulse"; ST.astralking = "maul"
  EC.icegolem = "#bfe8ff"; EC.yeti = "#e6edf7"; EC.revenant = "#7cc0ff"; EC.sentinel = "#ffd84a"; EC.zealot = "#fff6d0"; EC.astralking = "#ffd84a"

  ---@param s string
  local function W(s) local a = A(); for t in s:gmatch("%S+") do local k, n = t:match("^(%a+)%*?(%d*)$"); for _ = 1, tonumber(n ~= '' and n or '1') do a:push(k) end end; return a end
  D.WAVES4 = A(
    W("frostwisp revenant"),
    W("revenant*2 frostwisp"),
    W("icegolem revenant frostwisp"),
    W("icegolem yeti frostwisp*2"),
    W("icegolem yeti revenant frostwisp frostshaman"),
    W("icegolem*2 yeti revenant frostwisp frostshaman"),
    W("icegolem yeti*2 revenant*2 frostwisp frostshaman"),
    W("icegolem*2 yeti revenant frostwisp*2 frostshaman"),
    W("icegolem*2 yeti*2 revenant frostwisp*2 frostshaman"),
    W("icegolem*2 yeti*2 revenant*2 frostwisp frostshaman*2"),
    W("icegolem*3 yeti revenant*2 frostwisp*2 frostshaman"),
    W("icegolem*2 yeti*2 revenant*2 frostwisp*2 frostshaman*2"),
    W("icegolem*3 yeti*2 revenant frostwisp*2 frostshaman*2"),
    W("icegolem*3 yeti*2 revenant*2 frostwisp*2 frostshaman"),
    W("icegolem*3 yeti*2 revenant*2 frostwisp frostshaman*2"),
    W("icegolem*4 yeti*2 revenant frostwisp*2 frostshaman"),
    W("icegolem*3 yeti*3 revenant*2 frostwisp frostshaman")
  )
  D.WAVES5 = A(
    W("zealot*2 arbiter"),
    W("sentinel zealot arbiter"),
    W("sentinel zealot*2 arbiter obelisk"),
    W("sentinel*2 zealot arbiter oracle"),
    W("sentinel zealot*2 arbiter*2 obelisk"),
    W("sentinel*2 zealot*2 arbiter oracle obelisk"),
    W("sentinel*2 zealot*2 arbiter*2 oracle"),
    W("sentinel*2 zealot*2 arbiter*2 oracle obelisk"),
    W("sentinel*3 zealot*2 arbiter oracle obelisk"),
    W("sentinel*2 zealot*3 arbiter*2 oracle obelisk"),
    W("sentinel*3 zealot*2 arbiter*2 oracle*2"),
    W("sentinel*3 zealot*2 arbiter*2 oracle obelisk"),
    W("sentinel*3 zealot*3 arbiter*2 oracle obelisk"),
    W("sentinel*3 zealot*2 arbiter*2 oracle*2 obelisk"),
    W("sentinel*4 zealot*2 arbiter*2 oracle obelisk"),
    W("sentinel*3 zealot*3 arbiter*2 oracle obelisk"),
    W("sentinel*4 zealot*2 arbiter*2 oracle*2 obelisk")
  )

  D.DIFFS4 = A(
    { name = "普通", color = "#8fe07a", mult = 1.7, extra = 0, elite = 0.05, lives = 3, adds = 2, gold = 4, waves = 12,
      desc = "共 12 波。全新的冰原敌人：寒霜冻结、冰壳、冰棺复活，整体比第三章同难度更强；开局多 4 金币" },
    { name = "困难", color = "#ffd84a", mult = 2.15, extra = 1, elite = 0.15, lives = 3, adds = 2, gold = 6, waves = 14,
      desc = "共 14 波。敌人最高 +115%，第 3 波起每波多 1 个敌人，精英更常见；开局多 6 金币" },
    { name = "噩梦", color = "#ff9b8c", mult = 2.6, extra = 1, elite = 0.3, lives = 3, adds = 3, gold = 9, waves = 16,
      desc = "共 16 波。敌人最高 +160%；冰霜女皇一次冰封你 3 个单位；开局多 9 金币" },
    { name = "炼狱", color = "#e09cff", mult = 3.05, extra = 2, elite = 0.4, lives = 2, adds = 3, gold = 13, waves = 18,
      desc = "共 18 波。敌人最高 +205%，每波最多多 2 个敌人；只有 2 点生命，开局多 13 金币" }
  )
  D.DIFFS5 = A(
    { name = "普通", color = "#8fe07a", mult = 2, extra = 0, elite = 0.1, lives = 3, adds = 2, gold = 5, waves = 12,
      desc = "共 12 波。神殿敌人：圣盾格挡、殉道、专挑残血、沉默、减伤光环，是最难的一章；开局多 5 金币" },
    { name = "困难", color = "#ffd84a", mult = 2.5, extra = 1, elite = 0.2, lives = 3, adds = 2, gold = 8, waves = 14,
      desc = "共 14 波。敌人最高 +150%，第 3 波起每波多 1 个敌人；开局多 8 金币" },
    { name = "噩梦", color = "#ff9b8c", mult = 3, extra = 1, elite = 0.3, lives = 3, adds = 3, gold = 11, waves = 16,
      desc = "共 16 波。敌人最高 +200%；星穹神王立起 3 座方尖碑；开局多 11 金币" },
    { name = "炼狱", color = "#e09cff", mult = 3.5, extra = 2, elite = 0.4, lives = 2, adds = 3, gold = 15, waves = 18,
      desc = "共 18 波。敌人最高 +250%，每波最多多 2 个敌人；只有 2 点生命，开局多 15 金币" }
  )

  D.CHAPTERS:push({ name = "第四章", title = "霜狱冰原", key = "reel-legion-c4", color = "#7cc0ff", bg = "ice", bossName = "冰霜女皇",
    desc = "会冻结、结壳、化作冰棺复活的冰原怪物，尽头是能把你的主力关进冰牢的冰霜女皇",
    rage = A("revenant", "frostwisp"), waves = D.WAVES4, diffs = D.DIFFS4 })
  D.CHAPTERS:push({ name = "第五章", title = "星陨神殿", key = "reel-legion-c5", color = "#ffd84a", bg = "astral", bossName = "星穹神王",
    desc = "格挡、殉道、处决残血、沉默、减伤光环的神殿守军，尽头是能让全军复生的星穹神王",
    rage = A("zealot", "sentinel"), waves = D.WAVES5, diffs = D.DIFFS5 })
end
