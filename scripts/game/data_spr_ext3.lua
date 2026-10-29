-- 自动生成（tools/sprites/build7.py）：第十次更新——全部转职路线的新形象（18×18）
-- 每条路线一张独立的图（键名 pr_路线），自带调色板；武器 / 弓弦骨架和图一起登记
local js = require("game.compat")
local A = js.A
local S, PALS, RIG, BOW = {}, {}, {}, {}
S.pr_berserker = A(
  "...k......k.kkkkk.",
  "..kck....kckHHbHHk",
  "..kcckkkkcckHhbhHk",
  "...kcHHHHckkHhbhHk",
  "...kHhhhhHkkHHbHHk",
  "...ksessesk.kHbHk.",
  "...kffkkffk..kbk..",
  "..kBBffffBBk.kbk..",
  ".kBBsrssrsBskkbk..",
  ".kBssrssrssssssbk.",
  ".ksksrrrrskkkkbk..",
  ".kskbbgbbbk..kbk..",
  "..kkBBBBBBk..kbk..",
  "...kmmkkmmk..kbk..",
  "...kmmkkmmk..kbk..",
  "...kbbkkbbk..kbk..",
  "..kbbbkkbbbk.kbk..",
  "...kkk..kkk...k..."
)
PALS.berserker = { B = "#9b6a3c", H = "#e6edf7", b = "#6b4527", c = "#e9e2cf", e = "#ff3b3b", f = "#ff8a2a", g = "#e2b33c", h = "#8d9ab2", k = "#1b1530", m = "#7a1f2b", r = "#d8433a", s = "#f2c29a" }
RIG.pr_berserker = { k = "heavy", p = A(14.5, 9.5), t = A(14.5, 1.5), m = "0:12-16 1:12-17 2:12-17 3:12-17 4:12-17 5:12-16 6:13-15 7:13-15 8:12-15 9:12-16 10:12-15 11:13-15 12:13-15 13:13-15 14:13-15 15:13-15 16:13-15 17:14" }
S.pr_banner = A(
  ".....k............",
  ".kkkkgk....kk.....",
  "krrrrbk.kkkrrk.k..",
  "krrrrbkkHHHHHkkHk.",
  "krrGrbkkHhhhHkkHk.",
  "krGGGbkkskskskkHk.",
  "krrGrbkkssssskkHk.",
  "krrrrbkkkssskkkHk.",
  "krrrrbkaaaaaaakHk.",
  "krkrkbaaAAgAAagggk",
  ".k.kkbkaAAgAAassbk",
  "....kbsaaagaakkkk.",
  ".....kskbbgbbk....",
  "......kkaaaaak....",
  ".......kaakaak....",
  ".......khhkhhk....",
  "......khhhkhhhk...",
  ".......kkk.kkk...."
)
PALS.banner = { A = "#ff8a6a", G = "#ffd84a", H = "#e6edf7", a = "#b8302a", b = "#6b4527", g = "#e2b33c", h = "#8d9ab2", k = "#1b1530", r = "#d8433a", s = "#f2c29a" }
RIG.pr_banner = { k = "blade", p = A(15.5, 10.5), t = A(15.5, 2.5), m = "2:15 3:14-16 4:14-16 5:14-16 6:14-16 7:14-16 8:14-16 9:14-17 10:15-17" }
S.pr_avenger = A(
  "..................",
  "..............k...",
  ".....kkkkkk..kqk..",
  "....kaaaaaakkPPk..",
  "...kaAAAAAAakkPPk.",
  "...kAAAAAAAAkPPk..",
  ".k.kaqqaaqqakkPPk.",
  "kpkkaaaaaaaakPPk..",
  "kppkpaaaaaapkkPPk.",
  ".kppPpaAAapPpkggk.",
  "kpPPPpkaAakppssk..",
  "pPPqPPpaaaakkkbk..",
  "kpPPPpkbbbbk..k...",
  ".kpppkkaaaak......",
  "kpkkpkkaakaak.....",
  ".k..k.kaakaak.....",
  ".....kiiikiiik....",
  "......kkk.kkk....."
)
PALS.avenger = { A = "#6a5a8a", P = "#8f4bc4", a = "#3a2d52", b = "#6b4527", g = "#c06bff", i = "#2b2340", k = "#1b1530", p = "#5a2a7a", q = "#e0a0ff", s = "#f2c29a" }
RIG.pr_avenger = { k = "blade", p = A(13.5, 10.5), t = A(14, 2.5), m = "1:14 2:13-15 3:12-15 4:12-16 5:12-15 6:12-16 7:12-15 8:12-16 9:13-16 10:13-15 11:12-15" }
S.pr_paladin = A(
  ".......kk.........",
  "......kGGk........",
  ".....kHHHHk....k..",
  "....kHHHHHHk..kHk.",
  "....kHkkgkHk..kHk.",
  "....kHhhghHk..kHk.",
  ".kkkkHhhghHk..kHk.",
  "kwwwwkhhhhkk..kHk.",
  "wwgwwHaaaaaHkkgggk",
  "wgggwHaagaaHHsskk.",
  "wwgwwhagggakkkk...",
  "wwgwwhaagaak......",
  "wwgwwkgaaagk......",
  "kwwwkkHHgHHk......",
  ".kkk.kHHkHHk......",
  ".....kHHkHHk......",
  "....khhhkhhhk.....",
  ".....kkk.kkk......"
)
PALS.paladin = { G = "#ffe680", H = "#e6edf7", a = "#2f5fb8", g = "#e2b33c", h = "#8d9ab2", k = "#1b1530", s = "#f2c29a", w = "#f4f8ff" }
RIG.pr_paladin = { k = "blade", p = A(14.5, 9.5), t = A(15, 2.5), m = "2:15 3:14-16 4:14-16 5:14-16 6:14-16 7:14-16 8:14-17 9:15-16" }
S.pr_undying = A(
  ".......kkkk.......",
  "......kcccck...k..",
  ".....kcCccCck.kOk.",
  "....kcCkkCcck.kok.",
  "....kcceOceOk.kok.",
  ".....kccccck..kok.",
  "....kkkccckkk.kok.",
  "...kaaaaaaaaakkok.",
  "..kaAAaaaaaAAkuuuk",
  "..kaAkaAAAakAassk.",
  "..kaakaaaaakkskk..",
  "...kkkuaaauk.k....",
  ".....kuuaauk......",
  "......kuuuuok.....",
  ".......kuuook.....",
  "........koook.....",
  ".........kook.....",
  "..........kk......"
)
PALS.undying = { A = "#4f9aa8", C = "#7fbfcc", O = "#ffffff", a = "#2a5a6a", c = "#cfeff5", e = "#6ef0ff", k = "#1b1530", o = "#6ef0ff", s = "#bfe0e8", u = "#2a8a9a" }
RIG.pr_undying = { k = "blade", p = A(14.5, 9.5), t = A(15, 1.5), m = "1:15 2:14-16 3:14-16 4:14-16 5:14-16 6:14-16 7:14-16 8:14-17 9:15-16" }
S.pr_conqueror = A(
  ".........kk.......",
  "...k.k.kkrrk......",
  "..kgkgkgrrk.....k.",
  "..kgggggggk....kGk",
  "...kgHHHHgk....kgk",
  "...kHhhhhHk....khk",
  "...kskskskk....khk",
  "..kkssssskkk...khk",
  ".krrhgggggghkkkhhk",
  "krrrhgnggnghksssk.",
  "krrrhggnngghkkhk..",
  "krrkhgggggghkkhk..",
  "krrkkbbgbbbk.khk..",
  "krrkkgggkggk.khk..",
  "krrkkhhhkhhk.khk..",
  ".kk..khhkhhk.khk..",
  "....kHHHkHHHk.k...",
  ".....kkk.kkk......"
)
PALS.conqueror = { G = "#ffffff", H = "#e6edf7", b = "#6b4527", g = "#e2b33c", h = "#8d9ab2", k = "#1b1530", n = "#ff6a4a", r = "#8e2420", s = "#f2c29a" }
RIG.pr_conqueror = { k = "spear", p = A(14.5, 9.5), t = A(16, 2.5), m = "2:16 3:15-17 4:15-17 5:15-17 6:15-17 7:15-17 8:14-17 9:15-16 10:14-15 11:14-15 12:14-15 13:14-15 14:14-15 15:14-15 16:14" }
S.pr_dragoon = A(
  ".kck..k........k..",
  ".kcckkck......kHk.",
  "..kcAAAck.....kHk.",
  ".kAAaaaAykk...khk.",
  ".kAaaaaaaAAk..khk.",
  ".kAaaaaaaaaAk.khk.",
  "..kAkskswwAk..khk.",
  "..kAsssssAk...khk.",
  "..kkasssakkk..khk.",
  ".kaAaaaaaaAakkkhk.",
  "kaAAaAAAAaAAasssk.",
  "kaAkaaAAAaakkkkhk.",
  "kaakaaaaaaak..khk.",
  ".kk.kbbgbbk...khk.",
  "....kaakaak...khk.",
  "....khhkhhk....k..",
  "...khhhkhhhk......",
  "....kkk.kkk......."
)
PALS.dragoon = { A = "#7fe0c0", H = "#e6edf7", a = "#2f8f7a", b = "#6b4527", c = "#f1ece0", g = "#e2b33c", h = "#8d9ab2", k = "#1b1530", s = "#f2c29a", w = "#dfe7f2", y = "#ffd84a" }
RIG.pr_dragoon = { k = "spear", p = A(15.5, 9.5), t = A(15.5, 1.5), m = "0:15 1:14-16 2:14-16 3:14-16 4:14-16 5:14-16 6:14-16 7:14-16 8:14-16 9:15-16 10:14-16 11:14-16 12:14-16 13:14-16 14:14-16 15:15" }
S.pr_titan = A(
  ".............kkkk.",
  "............khHHhk",
  "....kkkkkk..khHHhk",
  "...kaaaaaak.khHHhk",
  "..kaAAAAAAak.kbbk.",
  "..kaAkfAkfAkkkbbk.",
  ".kaaAAAAAAAaakbbk.",
  "kaAAaaffaaaAAabbk.",
  "aAAAaAAAAAAaAAssk.",
  "aAAaAAAfAAAAaassk.",
  "aAAaAAffAAAAakbbk.",
  "kaakaAAAfAAAakbbk.",
  "kaakaaaAAaaaakbbk.",
  "kffkkaaaaaaakkbbk.",
  ".kkkaaaakaaaakkk..",
  "...kaAAakaAAak....",
  "..kaaaaakaaaaak...",
  "...kkkkk.kkkkk...."
)
PALS.titan = { A = "#a89070", H = "#8d9ab2", a = "#6b5a4a", b = "#4a3a2a", f = "#ff9f2e", h = "#5a5f6a", k = "#1b1530", s = "#f2c29a" }
RIG.pr_titan = { k = "heavy", p = A(14.5, 9.5), t = A(15, 1.5), m = "1:13-17 2:13-17 3:13-17 4:13-16 5:13-16 6:13-16 7:13-16 8:13-16 9:14-16 10:14-16 11:13-16 12:13-16 13:13-16 14:13-15" }
S.pr_seraph = A(
  ".....kkkkk........",
  "kk..kGGGGGk.kk..k.",
  "OOk..kkkkk.kOOkkFk",
  "OwOkkHHHHHkkOwOFfk",
  "OwwOkHsssHkOwwOfk.",
  "kOwwOsksksOwwOkfk.",
  "kOwwwOsssOwwwOkfk.",
  "kkOwwwOOOwwwOkkfk.",
  "OOwwwHaaaaHwwOOggk",
  "kOOwwHaagaHwOkssk.",
  ".kOOwhaggahOk.kk..",
  "..kkOHaagaHk......",
  "....kHGGGGHk......",
  "....kHHHHHHk......",
  "....kHHkkHHk......",
  "....kGGkkGGk......",
  "...kGGGkkGGGk.....",
  "....kkk..kkk......"
)
PALS.seraph = { F = "#ffe680", G = "#ffd84a", H = "#fff3b0", O = "#ffffff", a = "#f4f8ff", f = "#ff8a2a", g = "#e2b33c", h = "#d4a640", k = "#1b1530", s = "#f2c29a", w = "#cfe3ff" }
RIG.pr_seraph = { k = "blade", p = A(15.5, 9.5), t = A(15.5, 2.5), m = "2:15-17 3:15-17 4:15-16 5:15-16 6:15-16 7:15-16 8:15-17 9:15-16" }
S.pr_blademaster = A(
  "...............k..",
  "..............kHk.",
  ".......kk.....kHk.",
  ".....kkbbkk...kHk.",
  "...kkbBBBBbkk.kHk.",
  "..kbBBBBBBBBbkkHk.",
  "...kkksssskkk.kHk.",
  "....ksksskSk..kHk.",
  "....kkssssk...krk.",
  "...kaawwwaakkksrk.",
  "..kaaaawaaaasssk..",
  "..kaakaawaakkkk...",
  "..ksskrrrrrk......",
  "...kkkaaaaak......",
  "....kaaakaaak.....",
  "....kaak.kaak.....",
  "...kcck...kcck....",
  "....kk.....kk....."
)
PALS.blademaster = { B = "#e2c27a", H = "#e6edf7", S = "#c98c68", a = "#2e2a5a", b = "#b88a4a", c = "#bdb3a0", k = "#1b1530", r = "#b8302a", s = "#f2c29a", w = "#f1ece0" }
RIG.pr_blademaster = { k = "blade", p = A(15.5, 9.5), t = A(15.5, 1.5), m = "1:14-16 2:14-16 3:14-16 4:14-16 5:14-16 6:14-16 7:14-16 8:14-16 9:15-16" }
S.pr_ranger = A(
  "..kk..............",
  ".ktrk.kkkk........",
  ".ktrkkaaaak...k...",
  ".kbbaaAAAAak.kBk..",
  ".kbbaAAsssak.ktBk.",
  ".kbbaAsksksk.kt.Bk",
  ".kbbaasssssk.kt.Bk",
  ".kbbkaaBBBakkkt.Bk",
  "..kaaaBBBBBsskt.Bk",
  ".ksaaaBBBBBkkkt.Bk",
  ".kskaaBBBBBk.kt.Bk",
  "..kkabbbgbbk.kt.Bk",
  "...kaBBBBBBk.ktBk.",
  "....kBBkkBBk.kBk..",
  "....kbbkkbbk..k...",
  "....kbbkkbbk......",
  "...kbbbkkbbbk.....",
  "....kkk..kkk......"
)
PALS.ranger = { A = "#6fa85a", B = "#9b6a3c", a = "#3f7a3a", b = "#6b4527", g = "#e2b33c", k = "#1b1530", r = "#d8433a", s = "#f2c29a", t = "#f1e3c2" }
BOW.pr_ranger = { a = A(14, 3), b = A(14, 13), n = A(14, 8), m = "4:13-14 5:13-14 6:13-14 7:13-14 8:11-14 9:13-14 10:13-14 11:13-14 12:13-14", hd = "8:11-12", pull = 4, len = 8 }
S.pr_venom = A(
  ".....kkkk.........",
  "....kppppk....k...",
  "...kpPPPPpk..kzk..",
  "..kpPPPPPPpk.ktzk.",
  "..kpPhhhhhpk.kt.zk",
  "..kpPhZhhZhk.kt.zk",
  "..kpPhhLLhhk.kt.zk",
  "...kpkhLLhkkkkt.zk",
  "..kppPPPPPPsskt.zk",
  ".ksppPPPPPPkkkt.zk",
  ".kskpPPPPPPk.kt.zk",
  "..kkpbZbZbbk.kt.zk",
  "...kpPPPPPPk.ktzk.",
  "....kPPkkPPk.kzk..",
  "....kxxkkxxk..k...",
  "....kxxkkxxk......",
  "...kxxxkkxxxk.....",
  "....kkk..kkk......"
)
PALS.venom = { L = "#5a6478", P = "#6a4a8a", Z = "#9be36b", b = "#3a2a1a", h = "#8d9ab2", k = "#1b1530", p = "#3a2a4a", s = "#f2c29a", t = "#f1e3c2", x = "#2a3a2a", z = "#4fbf4a" }
BOW.pr_venom = { a = A(14, 3), b = A(14, 13), n = A(14, 8), m = "4:13-14 5:13-14 6:13-14 7:13-14 8:11-14 9:13-14 10:13-14 11:13-14 12:13-14", hd = "8:11-12", pull = 4, len = 8 }
S.pr_hunter = A(
  "......kkkk........",
  ".....kmmmmk...k...",
  "..kkkmmmmmmkkkHk..",
  ".kmmmmmgmmmmmktHk.",
  "..kkkssssskkkkt.Hk",
  "....kkskksk..kt.Hk",
  "...krssssrk..kt.Hk",
  "...krrsssrrkkkt.Hk",
  "..kmrrmmmrrsskt.Hk",
  ".ksmrmmgmmrkkkt.Hk",
  ".kskmmmmmmmk.kt.Hk",
  "..kkmmbgbmmk.kt.Hk",
  "..kmmmmmmmmmkktHk.",
  "..kmmkmmkmmk.kHk..",
  "...kkkiikiik..k...",
  ".....kiikiik......",
  "....kiiikiiik.....",
  ".....kkk.kkk......"
)
PALS.hunter = { H = "#c9cbd6", b = "#5a3a2a", g = "#c9cbd6", i = "#3a2a2a", k = "#1b1530", m = "#2b1a2a", r = "#8e2420", s = "#f2c29a", t = "#f1e3c2" }
BOW.pr_hunter = { a = A(14, 3), b = A(14, 13), n = A(14, 8), m = "4:13-14 5:13-14 6:13-14 7:13-14 8:11-14 9:13-14 10:13-14 11:13-14 12:13-14", hd = "8:11-12", pull = 4, len = 8 }
S.pr_windrunner = A(
  ".......kkkk.......",
  ".kk..kkAAAAk..k...",
  "kAAkkAAAAAAAkkBk..",
  ".kAAAAAAsssAkktBk.",
  "kAAAAAAskskskkt.Bk",
  ".kkAAAAssssskst.Bk",
  ".kAAkAAAsssk.kt.Bk",
  "..kkAAuuuuukkkt.Bk",
  "....kuuOuuusskt.Bk",
  "...ksuuOuuukkkt.Bk",
  "...kskuuOuuk.kt.Bk",
  "....kkubgbbk.kt.Bk",
  ".....kuuuuuk.ktBk.",
  ".....kuukuuk.kBk..",
  ".....kuukuuk..k...",
  ".....kbbkbbk......",
  "....kbbbkbbbk.....",
  ".....kkk.kkk......"
)
PALS.windrunner = { A = "#7ff0c8", B = "#bff0ff", O = "#bff0ff", b = "#3a5a4a", g = "#e2b33c", k = "#1b1530", s = "#f2c29a", t = "#f1e3c2", u = "#25807c" }
BOW.pr_windrunner = { a = A(14, 3), b = A(14, 13), n = A(14, 8), m = "4:13-14 5:13-14 6:13-14 7:13-14 8:11-14 9:13-14 10:13-14 11:13-14 12:13-14", hd = "8:11-12", pull = 4, len = 8 }
S.pr_arbalist = A(
  "..................",
  ".....kkkkk........",
  "....khhhhhk.......",
  "...khHHHHHhk......",
  "...khkkkkkhk......",
  "...khHhhhHhk......",
  "....ksssssk.kkkk..",
  "...kaaaaaaakbbbbk.",
  "..kaAAaaaAaabhhbk.",
  "..kaAAaaaAaHHHHHHk",
  ".ksaaaaaaaasskBbk.",
  ".kskabbgbbakkBkk..",
  "..kkaaaaaaakBk....",
  "....kaakaak.k.....",
  "....khhkhhk.......",
  "....khhkhhk.......",
  "...khhhkhhhk......",
  "....kkk.kkk......."
)
PALS.arbalist = { A = "#9aaabb", B = "#8a5a3a", H = "#c9cbd6", a = "#4a5a6a", b = "#5a3a22", g = "#e2b33c", h = "#6b6f80", k = "#1b1530", s = "#f2c29a" }
S.pr_engineer = A(
  "..................",
  ".....kkkk.....k...",
  "..kkkaaaak...kLk..",
  ".kggkaaaaak..ktLk.",
  "kgkgUoaUoak..kt.Lk",
  ".kggksssssk..kt.gk",
  ".kLLksssssk..kt.Gk",
  ".kLLkkssskkkkkt.gk",
  ".kLLaaaaaaasskt.Lk",
  ".kLsaaAAaaakkkt.Lk",
  "..kksaaAaaak.kt.Lk",
  "...kabLLbbak.kt.Lk",
  "...kaaaaaaak.ktLk.",
  "....kaakaak..kLk..",
  "....kLLkLLk...k...",
  "....kLLkLLk.......",
  "...kLLLkLLLk......",
  "....kkk.kkk......."
)
PALS.engineer = { A = "#e2b33c", G = "#fff3b0", L = "#6b6f80", U = "#6ef0ff", a = "#c8701a", b = "#5a3a22", g = "#e2b33c", k = "#1b1530", o = "#8d9ab2", s = "#f2c29a", t = "#f1e3c2" }
BOW.pr_engineer = { a = A(14, 3), b = A(14, 13), n = A(14, 8), m = "4:13-14 5:13-14 6:13-14 7:13-14 8:11-14 9:13-14 10:13-14 11:13-14 12:13-14", hd = "8:11-12", pull = 4, len = 8 }
S.pr_beastmaster = A(
  "..kwk..kwk........",
  "..kwwkkwwk....k...",
  "..kwwwwwwwk..kck..",
  ".kwwkwwwkwkk.ktck.",
  ".kwwwwwwwwwkkkt.ck",
  "..kwssssswkk.kt.ck",
  "..kwskskssk..kt.ck",
  "..kwwssswwkkkkt.ck",
  ".kwwwbbbbwwsskt.ck",
  ".kswwbBBbbwkkkt.ck",
  ".kskbbBBbbk..kt.ck",
  "..kkbbbgbbk..kt.ck",
  "...kbBBBBBk..ktck.",
  "....kbbkbbk..kck..",
  "....kbbkbbk...k...",
  "....kbbkbbk.......",
  "...kbbbkbbbk......",
  "....kkk.kkk......."
)
PALS.beastmaster = { B = "#8a5a3a", b = "#5a3a22", c = "#e9e2cf", g = "#e2b33c", k = "#1b1530", s = "#f2c29a", t = "#f1e3c2", w = "#8d8fa0" }
BOW.pr_beastmaster = { a = A(14, 3), b = A(14, 13), n = A(14, 8), m = "4:13-14 5:13-14 6:13-14 7:13-14 8:11-14 9:13-14 10:13-14 11:13-14 12:13-14", hd = "8:11-12", pull = 4, len = 8 }
S.pr_starfall = A(
  ".....kkykk....k...",
  "....kykykyk..kGk..",
  ".....kyyyk..kktGk.",
  "....kaaaaakkykt.Gk",
  "...kaAsssAk.kkt.Gk",
  "...kasksksk..kt.Gk",
  "...kaasssak..kt.Gk",
  "...kkaaaakkkkkt.Gk",
  "..kaaayaaaasskt.Gk",
  ".ksaaaaaayakkkt.Gk",
  ".kskaayaaaak.kt.Gk",
  "..kaaaaaaaakkkt.Gk",
  "..kaaayaaayaaktGk.",
  ".kaaaaaaaaaaakGk..",
  "..kkkaakaakkk.k...",
  "....kyykyyk.......",
  "...kyyykyyyk......",
  "....kkk.kkk......."
)
PALS.starfall = { A = "#5b6fd8", G = "#ffe14a", a = "#1f2a6a", k = "#1b1530", s = "#f2c29a", t = "#fff6b0", y = "#ffe680" }
BOW.pr_starfall = { a = A(14, 3), b = A(14, 13), n = A(14, 8), m = "4:13-14 5:13-14 6:13-14 7:13-14 8:11-14 9:13-14 10:13-14 11:13-14 12:13-14", hd = "8:11-12", pull = 4, len = 8 }
S.pr_shadow = A(
  "..................",
  ".....kkkkk........",
  "....kaaaaak...k...",
  "...kaaaaaaak.kBk..",
  "...kaqqkqqak.ktBk.",
  ".kkkaaaaaaak.kt.Bk",
  "krrrrrrrrrak.kt.Bk",
  "rrkkraaaaakkkkt.Bk",
  "rk.kaaaaaaasskt.Bk",
  "k.ksaaAaaakkkkt.Bk",
  "..kskaaAaak..kt.Bk",
  "...kkarrrak..kt.Bk",
  "....kaaaaak..ktBk.",
  "....kaakaak..kBk..",
  "....kaakaak...k...",
  "....kaakaak.......",
  "...kaak.kaak......",
  "....kk...kk......."
)
PALS.shadow = { A = "#6a5a8a", B = "#c06bff", a = "#3a2f58", k = "#1b1530", q = "#c06bff", r = "#8f4bc4", s = "#f2c29a", t = "#e0b0ff" }
BOW.pr_shadow = { a = A(14, 3), b = A(14, 13), n = A(14, 8), m = "4:13-14 5:13-14 6:13-14 7:13-14 8:11-14 9:13-14 10:13-14 11:13-14 12:13-14", hd = "8:11-12", pull = 4, len = 8 }
S.pr_sniper = A(
  ".....kkkk....kBk..",
  "....kxxxxk...ktBk.",
  "...kxXXXXxk..kt.Bk",
  "..kxXXxXXXxk.kt.Bk",
  "..kxXsssXXk..kt.Bk",
  "..kxXkerXsk..kt.Bk",
  "..kxXsssssk..kt.Bk",
  "..kxxksskkkkkkt.Bk",
  ".kxxXxxxxxxsskt.Bk",
  ".kxXxxXXxxxkkkt.Bk",
  ".kxxkxxXxxxk.kt.Bk",
  ".kxkkbbgbbbk.kt.Bk",
  "..k.kxxxxxxk.kt.Bk",
  "....kxxkkxxk.kt.Bk",
  "....kbbkkbbk.ktBk.",
  "....kbbkkbbk.kBk..",
  "...kbbbkkbbbk.k...",
  "....kkk..kkk......"
)
PALS.sniper = { B = "#d4a640", X = "#6a7a3a", b = "#4a3a2a", e = "#ff3434", g = "#e2b33c", k = "#1b1530", r = "#e2b33c", s = "#f2c29a", t = "#f1e3c2", x = "#3a4a2a" }
BOW.pr_sniper = { a = A(14, 0), b = A(14, 15), n = A(14, 8), m = "1:13-14 2:13-14 3:13-14 4:13-14 5:13-14 6:13-14 7:13-14 8:11-14 9:13-14 10:13-14 11:13-14 12:13-14 13:13-14 14:13-14", hd = "8:11-12", pull = 4, len = 8 }
S.pr_pyro = A(
  ".......k.......k..",
  "......kFk.....kFk.",
  ".....kFfk....kFfFk",
  ".....kffk...kfFFfk",
  "....krrrfk..kfFFfk",
  "...krrRrrrk..kffk.",
  "..krrRRrrrrk..kbk.",
  "...ksksskrk...kbk.",
  "...ksssssrk...kbk.",
  "..krrssssrrkkkkbk.",
  ".krRrrrrrrrrrsbsk.",
  ".krRrrRRrrrrkkkbk.",
  ".krRrrRRrrrrk.kbk.",
  ".krrrrrrrrrrk.kbk.",
  ".krrrfrrrfrrk.kbk.",
  ".krfFfrfFfrrk.kbk.",
  ".kfFFfffFFffk..k..",
  "..kkkkkkkkkk......"
)
PALS.pyro = { F = "#ffe14a", R = "#ff8a2a", b = "#5a2a1a", f = "#ff8a2a", k = "#1b1530", r = "#b8302a", s = "#f2c29a" }
RIG.pr_pyro = { k = "staff", p = A(15.5, 10.5), t = A(15.5, 2.5), m = "1:14-16 2:14-17 3:14-17 4:14-17 5:14-16 6:14-16 7:14-16 8:14-16 9:15-16 10:15-16 11:15-16 12:14-16 13:14-16 14:14-16 15:14-16 16:15" }
S.pr_cleric = A(
  "..............k...",
  ".............kZk..",
  "......kkkk..kZgZk.",
  ".....kwwwwk.kgGgk.",
  "....kwOOOOwk.kgk..",
  "...kwOwwwwOwkZgZk.",
  "...kwOsssswOkkbk..",
  "...kwsksskwk.kbk..",
  "...kwwsssswk.kbk..",
  "..kwgwwwwwgwkkbk..",
  ".kwwgOwwwwgwsbsk..",
  ".kwOkgOwwgwwwkbk..",
  ".kwOkwgggwwwkkbk..",
  ".kwwkwwgwwwwkkbk..",
  "..kwwwwgwwwwkkbk..",
  "..kwgwwgwwgwkkbk..",
  ".kwwggggggggwkk...",
  "..kkkkkkkkkkk....."
)
PALS.cleric = { G = "#fff3b0", O = "#ffffff", Z = "#9be36b", b = "#c8900f", g = "#e2b33c", k = "#1b1530", s = "#f2c29a", w = "#d8d0bc" }
RIG.pr_cleric = { k = "staff", p = A(14.5, 10.5), t = A(14.5, 1.5), m = "1:13-15 2:13-16 3:13-16 4:13-15 5:13-16 6:13-15 7:13-15 8:13-15 9:14-15 10:14-15 11:13-15 12:13-15 13:13-15 14:13-15 15:13-15 16:13-14" }
S.pr_hexer = A(
  "...k.k.k..........",
  "..krkykrk.....kk..",
  "..krykyrk....kcck.",
  "...kryrkk...kcccck",
  "....kBBBBk..kckckk",
  "...kBBBBBBk..kcck.",
  "...kBZBBZBk...kbk.",
  "...kBBkkBBk...kbk.",
  "...kBBBBBBk...kbk.",
  "..kxxBBBBxxk..kbk.",
  ".kxXxxxxxxxxkksbsk",
  ".kxXkxXXxxxk..kbk.",
  ".kxxkxxXxxxk..kbk.",
  ".kxxxxxxxxxk..kbk.",
  ".kxxkxxxkxxk..kbk.",
  ".kxkkxxkkxkxk.kbk.",
  "kxxkkxkkxk.kxk.k..",
  ".kk..k..k...k....."
)
PALS.hexer = { B = "#8a5a2b", X = "#5fae4a", Z = "#9be36b", b = "#4a3a2a", c = "#e9e2cf", k = "#1b1530", r = "#d8433a", s = "#f2c29a", x = "#2a5a30", y = "#ffd84a" }
RIG.pr_hexer = { k = "staff", p = A(15.5, 10.5), t = A(15.5, 2.5), m = "1:14-15 2:14-16 3:14-17 4:14-17 5:14-16 6:14-16 7:14-16 8:14-16 9:15-16 10:15-17 11:15-16 12:14-16 13:14-16 14:14-16 15:14-16 16:15" }
S.pr_necro = A(
  "..................",
  ".............kkkk.",
  "......kkkk..kPPPPk",
  ".....kjjjjkkPkkpbk",
  "....kjjjjjjkk..kbk",
  "...kjjjjjjjjk..kbk",
  "...kjjccccjjk..kbk",
  "...kjjckckjjk..kbk",
  "...kjjjcccjjk..kbk",
  "..kjjpjjjjpjjkkkbk",
  ".kjppPppppPppjjsbs",
  ".kjppkppPppppkkkbk",
  ".kjppkppPppppk.kbk",
  ".kjppppPPPppppkkbk",
  ".kjpppppPppppk.kbk",
  ".kjppPppppPppk.kbk",
  ".kjPpPpPpPpPppk.k.",
  "..kkkkkkkkkkkk...."
)
PALS.necro = { P = "#8f4bc4", b = "#4a3a5a", c = "#e9e2cf", j = "#1b1530", k = "#1b1530", p = "#3a2350", s = "#f2c29a" }
RIG.pr_necro = { k = "staff", p = A(16.5, 10.5), t = A(15, 2.5), m = "1:13-16 2:12-17 3:12-17 4:12 4:15-17 5:12 5:15-17 6:12 6:15-17 7:12 7:15-17 8:12 8:15-17 9:12-17 10:16-17 11:12-17 12:12-13 12:15-17 13:12-17 14:12-13 14:15-17 15:12-13 15:15-17 16:12-14 16:16 17:12-13" }
S.pr_chrono = A(
  "......kkkk.....k..",
  ".....kggggk...kgk.",
  "......kcck...kgGgk",
  ".....kggggk.kgGkGg",
  "....kaaaaaakkgGGGg",
  "...kaAAAAAAakkgGgk",
  "...kaAssssAak.kbk.",
  "...kasksskAak.kbk.",
  "...kaassssAak.kbk.",
  "..kaaAAaaAAaakkbk.",
  ".kaaagggggaaasbsk.",
  ".kaAgGGkGGgaakkbk.",
  ".kaAgGGkkGgaakkbk.",
  ".kaAagGGGgaaakkbk.",
  ".kaaaagggaaaakkbk.",
  ".kaAaaaaaaaAakkbk.",
  ".kgggggggggggk.k..",
  "..kkkkkkkkkkk....."
)
PALS.chrono = { A = "#3a8a8a", G = "#fff3b0", a = "#1f5a5a", b = "#8a6a2a", c = "#ffe680", g = "#e2b33c", k = "#1b1530", s = "#f2c29a" }
RIG.pr_chrono = { k = "staff", p = A(15.5, 10.5), t = A(15.5, 2.5), m = "1:14-16 2:14-17 3:14-17 4:14-17 5:14-17 6:14-16 7:14-16 8:14-16 9:15-16 10:15-16 11:15-16 12:14-16 13:14-16 14:14-16 15:14-16 16:15" }
S.pr_voidcaller = A(
  "..............kk..",
  ".............kPPk.",
  "......kkkk..kPjjPk",
  ".....kppppk.kPjjPk",
  "....kpPPPPpk.kPPk.",
  "...kpPjjjjPpk.kbk.",
  "...kpjqjjqjpk.kbk.",
  "...kpjjjOjjpk.kbk.",
  "...kppjjjjppk.kbk.",
  "..kppPpppppPpkkbk.",
  ".kpPPpjjjjpPppsbsk",
  ".kpPkpjjjjppkkkbk.",
  ".kpPkpPppPppk.kbk.",
  ".kppppPppPpppkkbk.",
  ".kppkppkppkppkkbk.",
  ".kpkkpkkpkkpk.kbk.",
  "kpkkpkkpkkpk...k..",
  ".k..k..k..k......."
)
PALS.voidcaller = { O = "#ffffff", P = "#7a43d9", b = "#3a2d52", j = "#0d0818", k = "#1b1530", p = "#33245a", q = "#c06bff", s = "#f2c29a" }
RIG.pr_voidcaller = { k = "staff", p = A(15.5, 10.5), t = A(15.5, 2.5), m = "1:14-16 2:14-17 3:14-17 4:14-16 5:14-16 6:14-16 7:14-16 8:14-16 9:15-16 10:15-17 11:15-16 12:14-16 13:14-16 14:14-16 15:14-16 16:15" }
S.pr_frost = A(
  ".....k.k.k....k...",
  "....kUkUkUk..kUk..",
  "....kUoUoUk.kUoUk.",
  "....kUUUUUkkUoOoUk",
  "...kaaaaaaakkUoUk.",
  "...kaAsssAak.kUk..",
  "...kasksksak.kbk..",
  "...kaassssak.kbk..",
  "...kOaassaOk.kbk..",
  "..kOOaaaaaOOkkbk..",
  ".kOaaAAaaaaaOsbsk.",
  ".kOakaAAaaaaakbk..",
  ".kOakaaAAaaaakbk..",
  ".kaaaaaaAAaaakbk..",
  ".kaaaaaaaaaaakbk..",
  ".kaAaaaaaaaAakbk..",
  ".kOOOOOOOOOOOkk...",
  "..kkkkkkkkkkk....."
)
PALS.frost = { A = "#9fdcff", O = "#f4f8ff", U = "#d8f4ff", a = "#3d7fc8", b = "#6a8ab0", k = "#1b1530", o = "#6ef0ff", s = "#f2c29a" }
RIG.pr_frost = { k = "staff", p = A(14.5, 10.5), t = A(14.5, 2.5), m = "1:13-15 2:12-16 3:12-17 4:12-16 5:13-15 6:13-15 7:13-15 8:13-15 9:12-15 10:14-16 11:12-15 12:12-15 13:12-15 14:12-15 15:12-15 16:12-14 17:12" }
S.pr_archmage = A(
  ".......k..........",
  "......kak.....k...",
  ".....kaak....kfk..",
  ".....kaayk..kfOFk.",
  "....kaaaak..koOFk.",
  "...kaaayaak..kbk..",
  "..kaaaaaaaak.kbk..",
  "...kksksksk..kbk..",
  "....kwwwwwk..kbk..",
  "...krwwwwwrk.kbk..",
  "..krrwwwwwrrkkbk..",
  ".krrrrwwwrrrrsbsk.",
  ".krgrrrwrrrgrkbk..",
  ".krgrrrrrrrgrkbk..",
  ".krgrrrrrrrgrkbk..",
  ".krgggggggggrkbk..",
  ".krrrrrrrrrrrkk...",
  "..kkkkkkkkkkk....."
)
PALS.archmage = { F = "#6ef0ff", O = "#ffffff", a = "#2a3a8a", b = "#8a5a2b", f = "#ff8a2a", g = "#ffd84a", k = "#1b1530", o = "#ffe14a", r = "#8e1f2b", s = "#f2c29a", w = "#f4f8ff", y = "#ffd84a" }
RIG.pr_archmage = { k = "staff", p = A(14.5, 11.5), t = A(14.5, 2.5), m = "1:14 2:13-15 3:12-16 4:12-16 5:13-15 6:13-15 7:13-15 8:13-15 9:13-15 10:12-15 11:14-16 12:12-15 13:12-15 14:12-15 15:12-15 16:12-14 17:12" }
S.pr_lich = A(
  ".....k.k.k........",
  "....kokokok....k..",
  "....koooook...kok.",
  "...kcccccck..koUok",
  "..kccccccck.koUOUo",
  "..kcckkckkck.koUok",
  "..kckoockook..kbk.",
  "..kcccccccck..kbk.",
  "..kdcckkkcdkk.kbk.",
  ".kdddcccccdddkkbk.",
  ".kdAdddddddAdsbsk.",
  ".kdAkddAdddAdkkbk.",
  ".kddkddAddddk.kbk.",
  ".kdddddAddddk.kbk.",
  ".kddddoAodddk.kbk.",
  ".kdAddddddAdk.kbk.",
  ".kddddddddddk..k..",
  "..kkkkkkkkkk......"
)
PALS.lich = { A = "#2f6a8a", O = "#ffffff", U = "#bff4ff", b = "#2a4a5a", c = "#d6f2ff", d = "#16324a", k = "#1b1530", o = "#6ef0ff", s = "#f2c29a" }
RIG.pr_lich = { k = "staff", p = A(15.5, 10.5), t = A(15.5, 2.5), m = "1:15 2:14-16 3:14-17 4:14-17 5:14-17 6:14-16 7:14-16 8:14-16 9:15-16 10:15-16 11:15-16 12:14-16 13:14-16 14:14-16 15:14-16 16:15" }
S.pr_storm = A(
  "....k...k.....k.k.",
  "...kyk.kykk..kFkFk",
  "...kyykyykyk.kFFFk",
  "..kyWWWWWyyk..kFk.",
  ".kyWWWWWWWyk..kbk.",
  "..kWWsssssWk..kbk.",
  "..kWWskskkk...kbk.",
  "...kWsssssk...kbk.",
  "....kassskk...kbk.",
  "...kaaaaaaak..kbk.",
  "..kaaaAAaaaakksbsk",
  ".kaaAaaFaaAak.kbk.",
  ".kaakaaFFaaak.kbk.",
  ".kaakaaaFaaak.kbk.",
  ".kaaaaaaaaaak.kbk.",
  ".kaAaaaaaaAak.kbk.",
  ".kaaaaaaaaaak..k..",
  "..kkkkkkkkkk......"
)
PALS.storm = { A = "#5b6fd8", F = "#ffe14a", W = "#e6edf7", a = "#283a7c", b = "#8d9ab2", k = "#1b1530", s = "#f2c29a", y = "#ffe14a" }
RIG.pr_storm = { k = "staff", p = A(15.5, 10.5), t = A(15.5, 1.5), m = "1:14-17 2:14-17 3:14-16 4:14-16 5:14-16 6:14-16 7:14-16 8:14-16 9:15-16 10:15-17 11:15-16 12:14-16 13:14-16 14:14-16 15:14-16 16:15" }
S.pr_claw = A(
  "..kk.......kk.....",
  ".kaak.....kaak....",
  ".kaAakkkkkaAak....",
  ".kaaaaaaaaaaak....",
  ".kaajaajaajaak....",
  ".kaaaaaaaaaaak....",
  ".kaaFkaaaFkaak....",
  ".kaAAAAkAAAAak....",
  "..kAAAkrkAAAk.....",
  "k..kAAAAAAAk..k.k.",
  "Ok.kaaaaaaak.kOkOk",
  "kOkaajaAajaakOkOk.",
  "OOaakaAAAakaaOOOk.",
  "kaakkajajakkaaak..",
  ".kk.kaaaaak.kkk...",
  "....kaakaak.......",
  "...kaaakaaak......",
  "....kkk.kkk......."
)
PALS.claw = { A = "#ffe2b8", F = "#ffd84a", O = "#ffffff", a = "#d9742a", j = "#5a2a1a", k = "#1b1530", r = "#ff5a5a" }
RIG.pr_claw = { k = "paw", p = A(12.5, 11.5), t = A(15, 12), m = "9:14 9:16 10:13-17 11:12-16 12:12-16 13:12-15" }
S.pr_bloodfang = A(
  "..kk.......kk.....",
  ".kaak.....kaak....",
  ".kaAakkkkkaAak....",
  ".kaaaaaaaaaaak....",
  ".kaajaajaajaak....",
  ".kaaaaaaacaaak....",
  ".kaaekaaaecaak....",
  ".kaAAAAkAAcAak....",
  ".kAmmmmmmmmAk.....",
  ".kAOmRRRRmOAk.....",
  "..kAmmmmmmAk......",
  ".kkkaaaaaaakkkk...",
  "kaaaajaajaaaaaOk..",
  "kaakkaajaakkaaORk.",
  ".kk.kaaaaak.kaRk..",
  "....kaakaak..kk...",
  "...kaaakaaak......",
  "....kkk.kkk......."
)
PALS.bloodfang = { A = "#e8a090", O = "#ffffff", R = "#ff3434", a = "#a8302a", c = "#ff8a7a", e = "#ffe14a", j = "#3a1010", k = "#1b1530", m = "#4a0a10" }
RIG.pr_bloodfang = { k = "paw", p = A(12.5, 12.5), t = A(15, 13), m = "11:12-14 12:12-15 13:12-16 14:12-15" }
S.pr_shadowcat = A(
  "..k.........k.....",
  ".kak.......kak....",
  ".kaakkkkkkkaak....",
  ".kaaaaaaaaaaak....",
  ".kaaaaaaaaaaak....",
  ".kaaaaaaaaaaak....",
  ".kaaqqaaaqqaak....",
  ".kaaaaaAaaaaak....",
  "..kPPPPPPPPPPk....",
  "..kPPPPPPPPPPPk...",
  "...kaaaaaaakPPk...",
  "..kaaaaaaaaakk....",
  ".kaakaaaaakaak....",
  ".kaakaaaaakkaak...",
  "..kkkaaaaak.kk....",
  "....kaakaak.......",
  "...qaaaqaaaq......",
  "....kkk.kkk......."
)
PALS.shadowcat = { A = "#5a4a7a", P = "#6a33c9", a = "#2b2340", k = "#1b1530", q = "#c06bff" }
RIG.pr_shadowcat = { k = "paw", p = A(11.5, 12.5), t = A(14, 13), m = "11:11-13 12:11-13 13:11-14 14:12-13" }
S.pr_whitetiger = A(
  "..kk.......kk.....",
  ".kwwk.....kwwk....",
  ".kwHwkkkkkwHwk....",
  ".kwwwwkkkwwwwk....",
  ".kwkwwwkwwwkwk....",
  ".kwwwwkkkwwwwk....",
  ".kwwokwwwokwwk....",
  ".kwHHHHkHHHHwk....",
  ".kkHHHkrkHHHk.....",
  "kokkHHHHHHHk......",
  "oOokwwwwwwwk......",
  "kokwwkwHwkwwk.....",
  ".kwwkwwHwwkwwk....",
  ".kwwkwkwkwkkwwk...",
  "..kkkwwwwwk.kk....",
  "....kwwkwwk.......",
  "...kwwwkwwwk......",
  "....kkk.kkk......."
)
PALS.whitetiger = { H = "#ffffff", O = "#ffffff", k = "#1b1530", o = "#6ef0ff", r = "#ff8aa8", w = "#e6edf7" }
RIG.pr_whitetiger = { k = "paw", p = A(11.5, 12.5), t = A(14, 13), m = "11:11-12 12:11-13 13:11-14 14:12-13" }
S.pr_hungrytiger = A(
  "...kk.......kk....",
  "..kaak.....kaak...",
  "..kaAakkkkkaAak...",
  "..kaaaaaaaaaaak...",
  "..kaajaajaajaak...",
  "..kaaFkaaaFkaak...",
  "..kaAAAAkAAAAak...",
  "..kAmmmmmmmmmAk...",
  "..kAOmmmmmmmOAk...",
  "...kAAmmmmmAAk....",
  "....kAAAZAAAk.....",
  "..kkkaaaZaakk.....",
  ".kaaaAjAjAaaak....",
  ".kakkAjAjAakaak...",
  "..k.kaaaaaakkk....",
  "....kakakkak......",
  "...kaakakkaak.....",
  "....kk.k..kk......"
)
PALS.hungrytiger = { A = "#d8a070", F = "#ffe14a", O = "#ffffff", Z = "#bff4ff", a = "#8e3a1a", j = "#4a1a0a", k = "#1b1530", m = "#3a0a10" }
RIG.pr_hungrytiger = { k = "paw", p = A(11.5, 12.5), t = A(14, 13), m = "11:11-12 12:11-13 13:11-14 14:11-13" }
S.pr_rendtiger = A(
  "..kk.......kk.....",
  ".kaakkkkkkkaak....",
  ".kahhhhhhhhhak....",
  ".khHHHHHHHHHhk....",
  ".kaajaajaajaak....",
  ".kaaaaaaaaaaak....",
  ".kaaFkaaaFkaak....",
  ".kaAAAAkAAAAak....",
  "..kAAAkrkAAAk.....",
  "..kkAAAAAAAkk..k..",
  ".khhhaaaaahhhkkHk.",
  "khHHhjaAajhHhhHkHk",
  "khhhkaAAAakhhhHHk.",
  "kHHHkajajakkhhhk..",
  ".kkkkaaaaak.kkk...",
  "....kaakaak.......",
  "...kaaakaaak......",
  "....kkk.kkk......."
)
PALS.rendtiger = { A = "#ffd8a8", F = "#ffd84a", H = "#e6edf7", a = "#b8402a", h = "#8d9ab2", j = "#4a1a0a", k = "#1b1530", r = "#ff5a5a" }
RIG.pr_rendtiger = { k = "paw", p = A(12.5, 11.5), t = A(15, 12), m = "9:12 9:15 10:12-16 11:12-17 12:12-16 13:12-15" }
S.pr_tigerspirit = A(
  "..kk.......kk.....",
  ".kaak.....kaak....",
  ".kaAakkkkkaAak....",
  ".kaaaaaaaaaaak....",
  ".kaaOaaOaaOaak....",
  ".kaaaaaaaaaaak....",
  ".kaaOkaaaOkaak....",
  ".kaAAAAkAAAAak....",
  "..kAAAOkOAAAk.....",
  "...kAAAAAAAk......",
  "..kaaaaaaaaakk....",
  ".kaakaaOaakaaak...",
  "kaakkaaaaakkaaak..",
  ".kk..kaaaak.kkk...",
  "......kaaako......",
  "....o..kaak.......",
  "........kak.......",
  ".........k........"
)
PALS.tigerspirit = { A = "#d8fff0", O = "#ffffff", a = "#3ac090", k = "#1b1530", o = "#6ef0c0" }
RIG.pr_tigerspirit = { k = "paw", p = A(11.5, 11.5), t = A(14, 12), m = "10:11-13 11:11-14 12:11-15 13:12-14" }
S.pr_sabre = A(
  "....kgkgkgk.......",
  ".kkkkgggggkk......",
  "kMMMMMMMMMMMk.....",
  "MMaaaaaaaaaMMk....",
  "MMaajaajaajMMk....",
  "MMaaaaaaaaaMMk....",
  "MMaFkaaaFkaMMk....",
  "MMAAAAkAAAAMMk....",
  "kMAAOkrkOAAMk.....",
  "kMMAOAAAOAMMk.....",
  ".kMMOMMMOMMk......",
  ".kkaaaaaaaakk.....",
  "kaaaajaajaaaakk...",
  "kaakkaAAAakkaaak..",
  ".kk.kaaaaak.kkk...",
  "....kaakaak.......",
  "...kaaakaaak......",
  "....kkk.kkk......."
)
PALS.sabre = { A = "#ffe8a0", F = "#ff4a3a", M = "#7a3a1a", O = "#ffffff", a = "#c8900f", g = "#ffd84a", j = "#5a3a0a", k = "#1b1530", r = "#ff8a7a" }
RIG.pr_sabre = { k = "paw", p = A(12.5, 12.5), t = A(15, 13), m = "11:12 12:12-14 13:12-15 14:12-14" }
S.pr_brute = A(
  "..kk........kk....",
  ".kbbk......kbbk...",
  "kbBBbkkkkkkbBBbk..",
  "kbbbbbbbbbbbbbbk..",
  ".kbbbbbbbbbbbbk...",
  ".kbbekbbbbekbbk...",
  ".kbbbbBBBBbbbbk...",
  "..kbBBBkkBBBbk....",
  "..kbBmmmmmmBbk....",
  ".kkbBOmmmmOBbkkk..",
  "kbbbbbBBBBbbbbOOk.",
  "bbbbbBBBBBBbbbbOk.",
  "bObkbBBBBBBbkbbbk.",
  "kOkkbbBBBBbbkkkk..",
  ".k.kbbbbbbbbk.....",
  "...kbbbkkbbbk.....",
  "..kbbbbkkbbbbk....",
  "...kkkk..kkkk....."
)
PALS.brute = { B = "#b8875a", O = "#ffffff", b = "#6b4527", e = "#ffd84a", k = "#1b1530", m = "#3a0a10" }
RIG.pr_brute = { k = "paw", p = A(13.5, 10.5), t = A(16, 11), m = "9:13-15 10:13-16 11:13-16 12:13-16 13:13-15" }
S.pr_ironback = A(
  "..kk........kk....",
  ".khhkkkkkkkkhhk...",
  "khHHhhhhhhhhHHhk..",
  "khHHHHHHHHHHHHhk..",
  ".khhhhhhhhhhhhk...",
  ".kbbbbbHHbbbbbk...",
  ".kbbekbHHbekbbk...",
  ".kbbbbBHHBbbbbk...",
  "..kbBBBkkBBBbk....",
  ".kkkbBBBBBBbkkk...",
  "khhhhhhhhhhhhhhk..",
  "hHHHhHHHHHHhHHHhk.",
  "hhhhkhhhhhhhkbbbbk",
  "kbbkkhhHHhhhkkbbbk",
  ".kkkbbbbbbbbk.kkk.",
  "...kbbbkkbbbk.....",
  "..khhhhkkhhhhk....",
  "...kkkk..kkkk....."
)
PALS.ironback = { B = "#a8805a", H = "#b4bccc", b = "#5a4030", e = "#ffd84a", h = "#5a6478", k = "#1b1530" }
RIG.pr_ironback = { k = "paw", p = A(13.5, 12.5), t = A(16, 13), m = "11:13-16 12:13-17 13:13-17 14:14-16" }
S.pr_frenzybear = A(
  ".krk..k..k..kkrk..",
  ".kbbkkbkkbkkbbk...",
  "kbBBbbbbbbbbBBbk..",
  "kbbbbbbbbbbbbbbk..",
  ".kbkkbbbbbbkkbk...",
  ".kbbekbbbbekbbk...",
  ".kbbbbBBBBbbbbk...",
  "..kbBBBkkBBBbk....",
  "..kbBmmmmmmBbkk.k.",
  ".kkbBOmOOmOBbkOkOk",
  "kbbbbbOBBObbbbOOOk",
  "bbbbbBBBBBBbbbbbk.",
  "bObkbBBBBBBbkbbbk.",
  "OOkkbbBBBBbbkkkk..",
  "Ok.kbbbbbbbbk.....",
  "k..kbbbkkbbbk.....",
  "..kbbbbkkbbbbk....",
  "...kkkk..kkkk....."
)
PALS.frenzybear = { B = "#d8735a", O = "#ffffff", b = "#8e2420", e = "#ff3434", k = "#1b1530", m = "#3a0a10", r = "#ff4a3a" }
RIG.pr_frenzybear = { k = "paw", p = A(13.5, 9.5), t = A(16, 10), m = "8:13-14 8:16 9:13-17 10:13-17 11:13-16 12:13-16" }
S.pr_guardbear = A(
  "..kk........kk....",
  ".kbbk......kbbk...",
  "kbBBbkkkkkkbBBbk..",
  "kbbbbbbbbbbbbbbk..",
  ".kbbbbbbbbbbbbk...",
  ".kbbekbbbbekbbk...",
  ".kbbbbBBBBbbbbk...",
  "..kbBBBkkBBBbk....",
  "..kbbBBBBBBbbk....",
  ".khhhkbbbbbbkkkk..",
  "khgaahkaaaaabbbbk.",
  "hgaaaghaaaaaabbbbk",
  "hgaGaghaagaaakbbbk",
  "hgaaaghaaaaak.kkk.",
  "khgaahkaaaaak.....",
  ".khhhkbbbkbbbk....",
  "..kkkbbbbkbbbbk...",
  ".....kkkk.kkkk...."
)
PALS.guardbear = { B = "#a8805a", G = "#ffe680", a = "#2a56a8", b = "#4a3a2a", e = "#ffd84a", g = "#e2b33c", h = "#8d9ab2", k = "#1b1530" }
RIG.pr_guardbear = { k = "paw", p = A(13.5, 10.5), t = A(16, 11), m = "9:13-15 10:13-16 11:13-17 12:13-17" }
S.pr_hibernator = A(
  ".......kkkkwwk....",
  ".....kkaaaawwk....",
  "..kkkaaaaaaakk....",
  ".kbbaaAaaaaabbk...",
  "kbBBbkkkkkkbBBbk..",
  "kbbbbbbbbbbbbbbk..",
  ".kbbbbbbbbbbbbk...",
  ".kbbkkbbbbkkbbkk..",
  ".kbbbbBBBBbbbbUUk.",
  "..kbBBBkkBBBbUOUk.",
  "..kkbBBBBBBbkkUUk.",
  ".kbbwwwwwwwwbbkk..",
  "kbbbwAwwwwAwbbbk..",
  "kbbkwwwwwwwwbbbk..",
  ".kkkbbbbbbbbkkk...",
  "...kbbbkkbbbk.....",
  "..kbbbbkkbbbbk....",
  "...kkkk..kkkk....."
)
PALS.hibernator = { A = "#9fb4e8", B = "#8aa0d8", O = "#ffffff", U = "#bff4ff", a = "#5a7ad8", b = "#3a4a8a", k = "#1b1530", w = "#f4f8ff" }
RIG.pr_hibernator = { k = "paw", p = A(12.5, 11.5), t = A(15, 12), m = "10:12-16 11:12-15 12:12-15 13:12-15" }
S.pr_mountain = A(
  "..kkkhhhk...kk....",
  ".kbbhHHhhk.kbbk...",
  "kbBBhhhhhkkbBBbk..",
  "kbbbbbbbbbbbbbbk..",
  ".kbbbbbbbbbbbbk...",
  ".kbbekbbbbekbbk...",
  ".kbbbbBBBBbbbbkk..",
  "khhkbBBkkBBbkhhhk.",
  "hHHhzbBBBBbzhHHhk.",
  "hhhhhzbbbbzhhhhhhk",
  "kbbbbbBBBBbbbbbbbk",
  "bbbbbBBBBBBbbbbbk.",
  "bbbkbBBBBBBbkbbk..",
  "kkkkbbBBBBbbkkk...",
  "...kbbbbbbbbk.....",
  "...kbbbkkbbbk.....",
  "..khhhhkkhhhhk....",
  "...kkkk..kkkk....."
)
PALS.mountain = { B = "#a89878", H = "#a8acb8", b = "#5a4a38", e = "#ffd84a", h = "#6b6f80", k = "#1b1530", z = "#5a9a3a" }
RIG.pr_mountain = { k = "paw", p = A(13.5, 10.5), t = A(16, 11), m = "9:13-17 10:13-17 11:13-16 12:13-15" }
S.pr_polarking = A(
  "....kUkkUkkUk.....",
  "..kkkUUUUUUUkkk...",
  ".kwwkUoUoUoUkwwk..",
  "kwWWwUUUUUUUwWWwk.",
  "kwwwwwwwwwwwwwwwk.",
  ".kwwkkwwwwwkkwwk..",
  ".kwwwwWWWWWwwwwk..",
  "..kwWWWkkWWWwwk...",
  "k.kwwWWWWWWwwk.k..",
  "UkkaaaaaaaaaaakUk.",
  "UUaaAaaaaaaAaUUk..",
  "wwwwaAwwwwwwwwwwk.",
  "wwwkwwwWWwwwwkwwwk",
  "kkkkwwWWWWwwk.kkk.",
  "...kwwwwwwwwk.....",
  "...kwwwkkwwwk.....",
  "..kwwwwkkwwwwk....",
  "...kkkk..kkkk....."
)
PALS.polarking = { A = "#78a8f2", U = "#bff4ff", W = "#ffffff", a = "#2a56c9", k = "#1b1530", o = "#6ef0ff", w = "#dfe7f2" }
RIG.pr_polarking = { k = "paw", p = A(13.5, 11.5), t = A(16, 12), m = "10:13-15 11:13-16 12:13-17 13:14-16" }
S.pr_bearking = A(
  "...kgkgkgkgk......",
  "..kkgggggggkk.....",
  ".kbbgGgGgGgbbk....",
  "kbBBbbbbbbbBBbk...",
  "kbbbbbbbbbbbbbbk..",
  ".kbbekbbbbekbbk...",
  ".kbbbbBBBBbbbbk...",
  "..kbBBBkkBBBbk....",
  ".krwbBBBBBBbwrk...",
  "krrwgbbbbbbgwrrkk.",
  "rrrwbgggggbbwbbbbk",
  "rrrwbbBgBBbbwrbbbk",
  "rrrwbbBBBBbbwrkkk.",
  "rrrwbbBBBBbbwrrk..",
  "rrrwbbbbbbbbwrrrk.",
  "rrrwbbbkkbbbwrrrk.",
  "kkwwbbbkkbbbbwkk..",
  "..kkkkk..kkkkk...."
)
PALS.bearking = { B = "#ffe680", G = "#ff4a5a", b = "#c8900f", e = "#8a2a1a", g = "#ffd84a", k = "#1b1530", r = "#b8302a", w = "#f4f8ff" }
RIG.pr_bearking = { k = "paw", p = A(13.5, 10.5), t = A(16, 11), m = "9:13-16 10:13-17 11:13-17 12:13-16" }
S.pr_vine = A(
  ".......kkkk.......",
  "......kaaaak......",
  ".....kaAAAAak.....",
  "....kaOaOaOak.....",
  "....krrrrrrrk.....",
  "....kaOaOaOak.....",
  ".....kaAAAAk......",
  "...kk.kzzkk.......",
  "..kxxk.kzzk.......",
  ".kxZZxk.kzzkkk....",
  "..kxxk.kzzkkxxk...",
  "..kkk.kzzkkxZZxk..",
  ".kZk.kzzk..kxxk...",
  "..o...kzzk..kk....",
  "......kkzzkk..o...",
  ".....kxxzzxxk.....",
  "....kxxxxxxxxk....",
  ".....kkkkkkkk....."
)
PALS.vine = { A = "#9be36b", O = "#ffffff", Z = "#9be36b", a = "#3f9a46", k = "#1b1530", o = "#c4f05a", r = "#7a1f2b", x = "#3f9a46", z = "#2f7a34" }
S.pr_strangler = A(
  ".......kkkkk......",
  "..k...kaaaaak...k.",
  ".kzk.kaAAAAAak.kzk",
  "kzkzkaOaOaOaOakzk.",
  "kzkkzrrrrrrrrrzk..",
  ".kzkkaOaOaOaOak...",
  "..k..kaAAAAAak....",
  ".....kkkxxkkk.....",
  "....kxxxXxxk......",
  "...kxXkkkkXxk.....",
  "...kxXkkkxXxk.....",
  "....kxxxxXxk......",
  "....kkkxXkk.......",
  "...kxxxXxk........",
  "..kxXkkkkkkkk.....",
  "..kxxxxxxxxxxk....",
  "...kxxxxxxxxk.....",
  "....kkkkkkkk......"
)
PALS.strangler = { A = "#5a9a3a", O = "#ffffff", X = "#5a9a3a", a = "#2a5a2a", k = "#1b1530", r = "#4a0a1a", x = "#2a5a2a", z = "#3f7a34" }
S.pr_plaguebloom = A(
  "..Z.........Z.....",
  ".ZZZ..kkkkZZZ.....",
  "..Z..kaaaak.Z.....",
  "....kaAaAAak......",
  "...kaAAaaAAak..Z..",
  "...kaayaaayaakZZZ.",
  "..kaaaaaaaaaak.Z..",
  "..kayaaaaaayak....",
  "..kaakOkOkOkak....",
  "...karrrrrrrak....",
  "....kaaaaaaak.....",
  "..kk.kkzzkkkkk....",
  ".kzzkkkzzkkkzzk...",
  "..kzzzkzzkzzzk....",
  "...kkzzzzzzkk.....",
  "....kxxxxxxk......",
  "...kxxxxxxxxk.....",
  "....kkkkkkkk......"
)
PALS.plaguebloom = { A = "#a86ad8", O = "#ffffff", Z = "#b4e86a", a = "#5a2a7a", k = "#1b1530", r = "#2a0a2a", x = "#2f7a34", y = "#e2e24a", z = "#3f9a46" }
S.pr_corroder = A(
  ".......kkkkk......",
  ".....kkyyyyykk....",
  "....kyyAAAAAyyk...",
  "....kyfFoFoFfyk...",
  "....kyaFFFFFayk...",
  ".....kaaaaaaak....",
  ".....kaAaaaAak....",
  ".....kaaAaaaakF...",
  ".....kaAaaAaak....",
  "...F.kaaaaAaak....",
  ".....kaaAaaaak.F..",
  "...kk.kaaaaakkk...",
  "..kzzkkkzzkkkzzk..",
  "...kzzzkzzkzzzk...",
  "....kkzzzzzzkk....",
  "....kxxxxxxxxk....",
  "...kxxxxxxxxxxk...",
  "....kkkkkkkkkk...."
)
PALS.corroder = { A = "#d8e86a", F = "#e8ff6a", a = "#8a9a2a", f = "#c4f05a", k = "#1b1530", o = "#ffffff", x = "#2f7a34", y = "#a8c42a", z = "#3f9a46" }
S.pr_mother = A(
  ".......kkkk.......",
  ".....kkaaaakk.....",
  "....kaaAAAAaak....",
  "...kaAAaaaaAAak...",
  "..kyaAaOaOaAayk...",
  "..kaarrrrrrrraak..",
  ".kkyaAaOaOaAaykk..",
  "kakkaaAAAAAAakkak.",
  "aOakkaaaaaaakkaOak",
  "rrrkykkzzzkkykrrrk",
  "aOakk..kzzk.kkaOak",
  "kzzkk.kzzzk.kkzzk.",
  ".kzzzkyzzkykzzzk..",
  "..kkzzzzzzzzzkk...",
  "....kkzzzzzkk.....",
  "....kxxxxxxxk.....",
  "...kxxxxxxxxxk....",
  "....kkkkkkkkk....."
)
PALS.mother = { A = "#ff7fb0", O = "#ffffff", a = "#a82a6a", k = "#1b1530", r = "#4a0a1a", x = "#2f7a34", y = "#ffd84a", z = "#3f9a46" }
S.pr_parasite = A(
  "......kkkkk.......",
  "....kkaaaaakk.....",
  "...kaaAAAAAaak....",
  "..kaAAaAAaAAAak...",
  ".kaAaAAOOOAAaAak..",
  ".kaaaAOOkkOAaaak..",
  ".kaAaaAOOOAaaAak..",
  "..krrrrrrrrrrrk...",
  "...kkZZZZZZZkk....",
  "....kZZzZZZZk.....",
  "..k..kZZzZZk..k...",
  ".kzk.kZZzZZk.kzk..",
  "..kzkZZzZZZZkzk...",
  "...kzZZZZZZZzk....",
  "..kzzzZZZZZzzzk...",
  ".kzkkxxxxxxxkkzk..",
  "..kkxxxxxxxxxkk...",
  "....kkkkkkkkk....."
)
PALS.parasite = { A = "#c4f05a", O = "#ffe14a", Z = "#d8e8a0", a = "#6a8a1a", k = "#1b1530", r = "#3a5a1a", x = "#3a5a1a", z = "#8aa84a" }
S.pr_pandemic = A(
  "......kgkgkgk.....",
  "..kkk.kgggggk.kkk.",
  ".kaaakkaaaaakkaaak",
  "kaAAAaaAAAAAaaAAAa",
  "kaOaOaaOaOaOaaOaOa",
  "krrrrrarrrrrarrrrr",
  "kaOaOaaOaOaOaaOaOa",
  ".kaaakkaAAAakkaaak",
  "..kzk..kzzzk..kzk.",
  "..kzzk.kzzk..kzzk.",
  "...kzzkkzzkkkzzk..",
  "....kzzzzzzzzzk...",
  ".....kkzzzzkkk....",
  ".....kzzzzzzk.....",
  "....kzzzZZzzzk....",
  "...kxxxxxxxxxxk...",
  "..kxxxxxxxxxxxxk..",
  "...kkkkkkkkkkkk..."
)
PALS.pandemic = { A = "#c06bff", O = "#ffffff", Z = "#9be36b", a = "#5a2a7a", g = "#ffd84a", k = "#1b1530", r = "#1b0a2a", x = "#2a4a2a", z = "#3a7a2a" }
S.pr_devourer = A(
  "....o.......o.....",
  "...oOokkkkkoOo....",
  "....okaaaaako.....",
  "...kaaAAAAAaak....",
  "..kaAOaOaOaOAak...",
  ".kaAOrrrrrrrOAak..",
  ".kaOrrrooorrrOak..",
  ".kaOrrrrrrrrrOak..",
  ".kaAOrrrrrrrOAak..",
  "..kaAOaOaOaOAak...",
  "...kaaAAAAAaak....",
  "...okkaazaakk.o...",
  "..oOo.kzzzk..oOo..",
  "...o.kzzzzzk..o...",
  "....kzzzzzzzk.....",
  "...kxxxxxxxxxk....",
  "..kxxxxxxxxxxxk...",
  "...kkkkkkkkkkk...."
)
PALS.devourer = { A = "#a8203a", O = "#ffffff", a = "#4a0a2a", k = "#1b1530", o = "#6ef0ff", r = "#12040c", x = "#2a1a3a", z = "#3a2a4a" }
S.pr_sunny = A(
  ".....kykykyk......",
  "....kyyyyyyyk.....",
  "...kyyAAAAAyyk....",
  "..kyyAbbbbbAyyk...",
  ".kyyAbkbbkbbAyyk..",
  "..kyAbbbbbbbAyk...",
  ".kyyAbkbbbkbAyyk..",
  "..kyAbbkkkbbAyk...",
  ".kkkyyAbbbAyykkk..",
  "kzzkkyyyyyyykkzzk.",
  "kzZzkkkyzykkkzZzk.",
  ".kzZzk.kzk.kzZzk..",
  "..kzzzkkzkkzzzk...",
  "...kkzzzzzzzkk....",
  ".....kkzzzkk......",
  ".....kxxxxxk......",
  "....kxxxxxxxk.....",
  ".....kkkkkkk......"
)
PALS.sunny = { A = "#ffe680", Z = "#9be36b", b = "#7a4a1a", k = "#1b1530", x = "#3a7a2a", y = "#ffd84a", z = "#4fbf4a" }
S.pr_photosyn = A(
  ".F.....kFk........",
  "FOF..kkOOOkk..F...",
  ".F..kOOZZZOOkFOF..",
  "...kOZZbbbZZOkF...",
  "...kOZbkbkbZOk....",
  "...kOZZbbbZZOk....",
  "....kOOZZZOOk.....",
  ".kk..kkOOOkk..kk..",
  "kuukk..kzk..kkuuk.",
  "uUUuuk.kzk.kuuUUuk",
  "uUuUUukkzkkuUUuUuk",
  "kuUUuUuuzuuUuUUuk.",
  ".kuuuUUuzuUUuuuk..",
  "..kkkuuuzuuukkk...",
  ".....kkkzkkk......",
  ".....kxxxxxk......",
  "....kxxxxxxxk.....",
  ".....kkkkkkk......"
)
PALS.photosyn = { F = "#ffe14a", O = "#f4fff0", U = "#6fe08a", Z = "#bff07a", b = "#3f7a3a", k = "#1b1530", u = "#2f8a4a", x = "#2f7a34", z = "#3f9a46" }
S.pr_rose = A(
  "......kkkk........",
  "....kkrrrrkk......",
  "...krrRRRRrrk.....",
  "..krRRrrrrRRrk....",
  "..krRrRRRRrRrk....",
  "..krRrRrrRrRrk....",
  "..krrRrRRrRrrk....",
  "...krrRRRRrrk.....",
  "...kkrrrrrrk......",
  "..kzzkkzzkk.......",
  ".kzZZzkzzOk.......",
  "..kzzkOzzk.kk.....",
  "...kk.kzzkkzzk....",
  "......kzzOzZZzk...",
  "......kzzkkzzk....",
  ".....kxxxxxxk.....",
  "....kxxxxxxxxk....",
  ".....kkkkkkkk....."
)
PALS.rose = { O = "#f4f8ff", R = "#ff4a5a", Z = "#6fbf5a", k = "#1b1530", r = "#a8102a", x = "#3a5a2a", z = "#2f7a34" }
S.pr_purebloom = A(
  "..................",
  "........o.........",
  ".......oOo........",
  "....o...o...o.....",
  "......kkwkk.......",
  "...k.kwwwwwk.k....",
  "..kwkkwOOOwkkwk...",
  ".kwOwkwOyOwkwOwk..",
  ".kwOOwwOyOwwOOwk..",
  "..kwOOwOOOwOOwk...",
  "...kwwOOOOOwwk....",
  "..kkkwwwwwwwkkk...",
  ".kzzzzzzzzzzzzzk..",
  "kzZZZzzZZZzzZZZzk.",
  ".kzzzzzzzzzzzzzk..",
  ".kuuukkuuuukkuuuk.",
  "..kuuuuuuuuuuuuk..",
  "...kkkkkkkkkkkk..."
)
PALS.purebloom = { O = "#ffffff", Z = "#9be36b", k = "#1b1530", o = "#6ef0ff", u = "#3aa6c8", w = "#bcd8ee", y = "#ffe680", z = "#3f9a46" }
S.pr_moonbloom = A(
  ".kyyyk............",
  "kyykk.............",
  "kyk....kkkkko.....",
  "kyykk.kzzzzzk.....",
  ".kyyykzkkkkkzk....",
  "..kkkzkk....kzk...",
  "..kaaaaak...kzk...",
  ".kaAAAAAak..kzk...",
  "kaAAAAAAAak.kzk...",
  "kaAqkAqkAak.kzk...",
  "kaAAAAAAAakkzZzk..",
  "kaaaaaaaaakkzZzk..",
  "kqkqkkkqkqk.kzk...",
  ".k.kkqkk.k..kzk...",
  ".....k....kkzzzk..",
  ".........kxxxxxxk.",
  "........kxxxxxxxxk",
  ".........kkkkkkkk."
)
PALS.moonbloom = { A = "#8a7ae8", Z = "#7fc8a0", a = "#4a3a9a", k = "#1b1530", o = "#ffffff", q = "#e0d8ff", x = "#2a4a4a", y = "#fff3b0", z = "#3f7a5a" }
S.pr_lifebloom = A(
  ".r............r...",
  "rRr...kkk....rRr..",
  ".r...kaaak....r...",
  ".kk.kaAAAak.kkk...",
  "kaakkaAyAakkaaak..",
  "aAAakaAAAakaAAAak.",
  "aAyAkkaaakkaAyAak.",
  "aAAak.kzk.kaAAAak.",
  "kaak..kzk..kaaak..",
  ".kzzk.kzk.kzzzk...",
  "..kzzkkzkkzzkk....",
  "...kzzkzkzzkzzk...",
  "....kzzzzzkkzZzk..",
  ".....kzzzk..kzk...",
  "......kzkkk..k....",
  ".....kxxxxxk......",
  "....kxxxxxxxk.....",
  ".....kkkkkkk......"
)
PALS.lifebloom = { A = "#ffc0e0", R = "#ff9ab8", Z = "#9be36b", a = "#e05a9a", k = "#1b1530", r = "#ff4a7a", x = "#3a7a2a", y = "#ffe14a", z = "#4fbf4a" }
S.pr_sungod = A(
  "...kyk.kgk.kyk....",
  "..k.kykgggkyk.k...",
  ".kykkkyyyyykkkyk..",
  "..kyyyGGGGGyyyk...",
  "kk.kyGFFFFFGyk.kk.",
  "yykyGFkFFFkFGykyyk",
  "kkkyGFFFFFFFGykkk.",
  "kkkyGFFrFrFFGykkk.",
  "yykyGFFFrFFFGykyyk",
  "kk.kyGFFFFFGyk.kk.",
  "..kyyyGGGGGyyyk...",
  ".kykkkyyyyykkkyk..",
  "..k.kykkzkkyk.k...",
  "...kykkzzzkkyk....",
  "....kkzzzzzkk.....",
  "....kxxxxxxxk.....",
  "...kxxxxxxxxxk....",
  "....kkkkkkkkk....."
)
PALS.sungod = { F = "#fff3b0", G = "#ffb03a", g = "#ffe680", k = "#1b1530", r = "#e2902c", x = "#3a7a2a", y = "#ffd84a", z = "#4fbf4a" }
S.pr_solar = A(
  "..k.kFk.kFk.k.....",
  ".kFkFfFkFfFkFk....",
  ".kfFfrfFfrfFfFk...",
  ".kfrrrrrrrrrrfk...",
  "kfFrrRRRRRrrFfkk..",
  ".kfrRbbbbbRrfkkFk.",
  "kFfrRbkbkbRrfFkk..",
  ".kfrRbbbbbRrfk....",
  "kFfrRbkkkbRrfFk...",
  ".kfrrRRRRRrrfk.k..",
  "..kfFrrrrrFfk.kFk.",
  "...kfFkzkFfk...k..",
  "..kFkkkzkkkFk.....",
  "...kkzzzzzkk......",
  ".....kkzkkk.......",
  ".....kxxxxxk......",
  "....kxxxxxxxk.....",
  ".....kkkkkkk......"
)
PALS.solar = { F = "#ffe14a", R = "#ff6a3a", b = "#5a1a0a", f = "#ff8a2a", k = "#1b1530", r = "#d8432a", x = "#3a5a2a", z = "#4f9a3a" }
S.pr_oakguard = A(
  ".........kgGk.....",
  "........kgGk......",
  "......kkkCkk......",
  ".....kCcCcCCk.....",
  "....kCcCcCcCCk....",
  "...kdDdDdDdDdDk...",
  "....kffffffffk....",
  "....kFeeFFeeFk....",
  "....kFFFbbFFFkkk..",
  "..kkkkBBBBBBGkGgk.",
  ".kRRRRkBLBBLBkBLBk",
  "kRssssRkLBBLBkBLBk",
  "kRsrrsRkBGBLBkLBBk",
  "kRsrrsRkGgGBBkBLBk",
  "kRssssRkbbbbbkbbk.",
  ".kRRRRkbkbBBk.kk..",
  "..kkkkbbkbbbk.....",
  "......kk.kkk......"
)
PALS.oakguard = { B = "#7a5030", C = "#9a6a34", D = "#7a5228", F = "#e0bf8a", G = "#5f9e3e", L = "#a87a48", R = "#6b4527", b = "#4a2e1a", c = "#c89a52", d = "#5a3a1a", e = "#ffd84a", f = "#b8925e", g = "#a8e070", k = "#1b1530", r = "#b08048", s = "#e8cf9a" }
RIG.pr_oakguard = { k = "limb", p = A(14.5, 9.5), t = A(15.5, 14.5), m = "8:14-15 9:14-16 10:14-17 11:14-17 12:14-17 13:14-17 14:14-16 15:14-15" }
S.pr_thornoak = A(
  ".....k..k..k......",
  "....kckkckkck.....",
  "....kckyckkck.....",
  "....kAyYyAcAk.....",
  "....kaAyaaAak.....",
  "....kWeWaWeWk.....",
  "....kaaaaaaak.....",
  "....kaWcWcWak.....",
  "..kk.kaaaaak..kk..",
  ".kaakAaaaaaAkkAak.",
  "kcaAaAVaaaAaakaVck",
  ".kaVaaaVVaaaAkVak.",
  ".kVaaAaayVVaakaVck",
  "kcVaaaaaaaVVakcVak",
  ".kckkaAaaaayakkVyk",
  "..k.kaaakaaak..kk.",
  "....kaak.kaak.....",
  ".....kk...kk......"
)
PALS.thornoak = { A = "#7a5634", V = "#4f9a3a", W = "#1f140c", Y = "#ffb0c0", a = "#4a3220", c = "#efe6cf", e = "#ff3b3b", k = "#1b1530", y = "#ff4a6a" }
RIG.pr_thornoak = { k = "limb", p = A(14.5, 9.5), t = A(15.5, 14.5), m = "8:14-15 9:13-16 10:14-17 11:14-16 12:14-17 13:14-17 14:14-17 15:15-16" }
S.pr_mossheart = A(
  ".....k....k.......",
  "....krk..krk......",
  "...krOrkkrOrk.....",
  "...krrrkkrrrk.....",
  "....kbkkkkbk......",
  "...kZZZZZZZZk.....",
  "..kZZzZZZZzZZk....",
  "..kZzkZZZZkzZk....",
  "..kZZZZkkZZZZk....",
  ".kZZzZZZZZZzZZk...",
  "kzZZZZoooZZZZZzk..",
  "kzZzZoOOOoZzZZzk..",
  "kzZZZZoooZZZZZzk..",
  ".kzZZzZZZZZzZzk...",
  "..kZZZZZZZZZZk....",
  "...kbbbkkbbbk.....",
  "..kbbbbkkbbbbk....",
  "...kkkk..kkkk....."
)
PALS.mossheart = { O = "#d8ffe0", Z = "#7fc85a", b = "#5a3a1a", k = "#1b1530", o = "#3aff8a", r = "#d8433a", z = "#4a8a3a" }
S.pr_ironwood = A(
  "....k.k..k.k......",
  "...kzkzkkzkzk.....",
  "..kzZzZzzZzZzk....",
  "..kaaaaaaaaaak....",
  ".kaAaaaaaaaAaak...",
  ".khhhhhhhhhhhhk...",
  ".kaaffaaaaffaak...",
  ".kaaaaakkaaaaak...",
  "kkaAaaaaaaaaAakk..",
  "hhhhhhhhhhhhhhhhk.",
  "hHaahHaHaaHhaaHhk.",
  "hHaahHaaaaHhaaHhk.",
  "hhhhhhhhhhhhhhhhk.",
  "kkkaaaaaaaaaakkk..",
  "..kaAaakkaaAak....",
  "..khhhhkkhhhhk....",
  ".khhhhhkkhhhhhk...",
  "..kkkkk..kkkkk...."
)
PALS.ironwood = { A = "#8a847a", H = "#c9cbd6", Z = "#6a9a5a", a = "#5a5450", f = "#ffb04a", h = "#3a4048", k = "#1b1530", z = "#3a6a3a" }
S.pr_rootweaver = A(
  "......kzZzk.......",
  ".....kzZzZzk......",
  "....kzZzZzZzk.....",
  "....kzWWWWWzk.....",
  "....kzWeWeWzk.....",
  "....kzWWWWWzk.....",
  ".....kzWWWzk..kk..",
  "..kkkaAzzzAakkAak.",
  ".kaAaAaaaaaAakaAk.",
  ".kAaaaAaaaAaakkaAk",
  ".kakaaaAeAaaakkAak",
  ".kekaaAaaaAaak.kek",
  "..kkaAaaaaaAak..k.",
  "..kaaaaaaaaaaak...",
  ".kaAakaAaAakaAak..",
  "kaAekkakakakkeAak.",
  "kaak.kekkkek.kaak.",
  ".kk...k...k...kk.."
)
PALS.rootweaver = { A = "#7a5233", W = "#14200e", Z = "#5aa040", a = "#4a2f1b", e = "#9bff6a", k = "#1b1530", z = "#2f6a2a" }
RIG.pr_rootweaver = { k = "limb", p = A(14.5, 7.5), t = A(16.5, 11.5), m = "6:14-15 7:13-16 8:14-16 9:14-17 10:14-17 11:15-17 12:16" }
S.pr_worldtree = A(
  "...kkzzZZZZzzkk...",
  "..kzZZgZZZZZZzzk..",
  ".kzZgggZZZZgZZZzk.",
  "kzZZgZZZyZggZZZZzk",
  "kzZZZZZZZZZZZyZZzk",
  "kzZyZZzZZZZZzZZZzk",
  ".kzZZZzzZyZzzZZzk.",
  "..kzzzZZzzzZZzzk..",
  "...kkzzAzzAzzkk...",
  "...kkkaWaaWakkk...",
  "..kaaaaOaaOakaak..",
  "...kkaaaaaaakkaak.",
  "...kzkaAaGaakkgzk.",
  "....kkaaAaAakkzZk.",
  "....kkaAaaaakkkk..",
  "...kaAaaaaaaAak...",
  "..kaakaakkaakaak..",
  ".kaak.kk..kk.kaak."
)
PALS.worldtree = { A = "#d2b896", G = "#ffe14a", O = "#e6fff4", W = "#5a4030", Z = "#46b46a", a = "#9a7a58", g = "#c6f5cf", k = "#1b1530", y = "#ffe14a", z = "#24704a" }
RIG.pr_worldtree = { k = "limb", p = A(13.5, 10.5), t = A(15.5, 13.5), m = "9:13-14 10:13-15 11:13-16 12:13-16 13:13-16 14:14-15" }
S.pr_elderent = A(
  "....kfFkkFfk......",
  "...kfFFfFFFfk.....",
  "..kfFrFFfFrFfk....",
  "...kfAaaaaAfk.....",
  "...kAaAaaAaAk.....",
  "...kWWWaaWWWk.....",
  "...kaeWaaWeak.....",
  "...kaaaAAaaakkk...",
  "..kkamMmmMmakAak..",
  ".kaaAaMmmMaAkaAak.",
  ".kAaaAaMMaAakkaAk.",
  ".kakaaAaaAaakkAak.",
  ".kakaAaaaaAakkaAak",
  "..kkaaaAaaaakaaaAk",
  "...kaAakkaAakMakma",
  "...kaaakkaaakkk.kk",
  "...kaak..kaak.....",
  "....kk....kk......"
)
PALS.elderent = { A = "#a8885a", F = "#ffb03a", M = "#9cc47a", W = "#2a1a10", a = "#5e4630", e = "#ffd84a", f = "#d8641a", k = "#1b1530", m = "#5f8a4a", r = "#c0281a" }
RIG.pr_elderent = { k = "limb", p = A(13.5, 8.5), t = A(15.5, 14.5), m = "7:13-14 8:13-15 9:13-16 10:13-16 11:13-16 12:13-17 13:13-17 14:13-17 15:13-14 15:16-17" }
S.pr_stormhawk = A(
  "..................",
  "..................",
  ".k................",
  "kak...............",
  "kaak.......kkk....",
  "kaAak.....kaaak...",
  ".kaAak...kaAAkak..",
  ".kayAak..kaAAAyyk.",
  "..kaAyak.kaAAAyk..",
  "..kayAyakkaAAak...",
  "...kaayAaaAAAak...",
  "....kaaAaAAAAak...",
  ".....kaaAAAAAak...",
  "......kaaAAAak....",
  ".......kaaaak.....",
  ".......kakkak.....",
  "......kyykyyk.....",
  ".......kk.kk......"
)
PALS.stormhawk = { A = "#b4c4dc", a = "#3a4a6a", k = "#1b1530", y = "#ffe14a" }
S.pr_skyhunter = A(
  "..................",
  "..................",
  "..................",
  ".kk...............",
  "kaakk.............",
  "kaAaakk.....kkk...",
  ".kaAAaakk..kaaak..",
  "..kaAAAaakkaGGoak.",
  "...kaAAAAaaaGGGyyk",
  "....kaaAAAaaaaayyk",
  ".....kaaaaaaaaakk.",
  "......kaaAAAaak...",
  ".......kaAAAak....",
  "........kaaaak....",
  ".......kaakaak....",
  "......kyykkyyk....",
  ".....kykykykyk....",
  "......k.k.k.k....."
)
PALS.skyhunter = { A = "#e2b33c", G = "#6b6f80", a = "#8a5a1a", k = "#1b1530", o = "#6ef0ff", y = "#ffd84a" }
S.pr_galewing = A(
  "..................",
  "..................",
  "..................",
  "..................",
  "..................",
  "..................",
  ".......kk.........",
  "......kaak........",
  "......kaAak..kkk..",
  "..O....kaAakkaaak.",
  ".....kkaaAAaaaakyk",
  "..O.kaaaaaaaaaaak.",
  ".kk..kaaawwwwwwk..",
  "kaakkaaaawwwwwk...",
  "aakaaakkkkwwwk....",
  "ak.kkk....kkO.....",
  "k..O..............",
  ".................."
)
PALS.galewing = { A = "#73d8c8", O = "#bff4ff", a = "#1f3a7a", k = "#1b1530", w = "#f4f8ff", y = "#ffd84a" }
S.pr_thunderbird = A(
  "..................",
  ".......k..k.......",
  "......kykkyk......",
  "......kyyyyk......",
  ".....kayyyyak.....",
  "....kakyyyykak....",
  "kk..kayyrryyak..kk",
  "aakk.kaayyaak.kkaa",
  "ayaakkayyyyakkaaya",
  "ayyyakayFFyakayyya",
  "aakyyaayFyyaayykaa",
  "kayyyyayyFyayyyyak",
  ".kaakyyyFyyyykaak.",
  "..kkaayyyyyyaakk..",
  "....kkayyyyakk....",
  "....kaykyykyak....",
  "....kakkaakkak....",
  ".....k..kk..k....."
)
PALS.thunderbird = { F = "#ffffff", a = "#1b1530", k = "#1b1530", r = "#d8433a", y = "#e2b33c" }
S.pr_bladewing = A(
  "..................",
  "..................",
  "..................",
  "..k...............",
  ".kHk........kkk...",
  ".kHHk......kaaak..",
  "..kHHk....kaaAkak.",
  "..khHHk...kaAAAyyk",
  ".kHkhHHkkkaaAAayk.",
  ".kHHkhHHaaaaaAak..",
  "..kHHkhHHaaaaAak..",
  "...kHHhhHHaaAAak..",
  "....kHHhhHaAAAak..",
  ".....kHHhaaAAak...",
  "......kkkaaaak....",
  "........kakkak....",
  ".......kyykyyk....",
  "........kk.kk....."
)
PALS.bladewing = { A = "#ff8a7a", H = "#e6edf7", a = "#a8202a", h = "#8d9ab2", k = "#1b1530", y = "#ffd84a" }
S.pr_rocking = A(
  "..................",
  ".......k.k.k......",
  "......kykykyk.....",
  ".......kyyyk......",
  "......kaaaaak.....",
  "kkk...kaAkAayk..kk",
  "aaakk.kaAAAyyykkaa",
  "aAAaakkaaAAakkaaAa",
  "aAOAAaaaAAAaaaAOAa",
  "kaAOAAaAAAAAaAAOAk",
  "kaaAOAAaAAAaAAOAak",
  ".kaaAAAaaAaaAAAak.",
  "..kkaaAaAAAaAaak..",
  "....kkaaAAAaakk...",
  "......kaaaaak.....",
  "......kykkkyk.....",
  ".....kyyk.kyyk....",
  "......kk...kk....."
)
PALS.rocking = { A = "#78a8f2", O = "#ffe14a", a = "#1f3a8a", k = "#1b1530", y = "#ffd84a" }
S.pr_phoenixhawk = A(
  "..................",
  "..................",
  "..k...............",
  ".kFk........kkk...",
  "kFfFk......kaaak..",
  "kfFfFk....kaaAkak.",
  ".kfrfFk...kaAAAyyk",
  "..kfrfFkkkaaAAAyk.",
  "...kfrfFFaaaAAak..",
  "....kfrrfaaaaAak..",
  ".....kfrraaAAAak..",
  "......kfraaAAak...",
  "......kFaaaaaFk...",
  ".....kFfkakakfFk..",
  "....kFfkffkffkfFk.",
  "...kFkkFkFkFkFkkFk",
  "....kkFk.kFk.kFkk.",
  "......k...k...k..."
)
PALS.phoenixhawk = { A = "#ffb04a", F = "#ffe14a", a = "#d8432a", f = "#ff8a2a", k = "#1b1530", r = "#ff4a2a", y = "#fff3b0" }
S.pr_gearsoldier = A(
  ".....krrrrk.......",
  ".....krggrk.......",
  ".....krrrrk.......",
  ".....krrrrk.......",
  "....khhhhhhk......",
  "....khoHHohk......",
  ".k..khHHHHhk......",
  "kgk.khhhhhhk......",
  "gGgkaaaaaaaakkkkk.",
  "kgkaagaagaaahhhhhk",
  "kgkkagaagaakhHHhhk",
  ".k.kaaaaaaakkkkkk.",
  "....krrrrrk.......",
  "....kaakaak.......",
  "....kaakaak.......",
  "....khhkhhk.......",
  "...khhhkhhhk......",
  "....kkk.kkk......."
)
PALS.gearsoldier = { G = "#ffe680", H = "#e6edf7", a = "#2a56a8", g = "#e2b33c", h = "#8d9ab2", k = "#1b1530", o = "#ff8a5a", r = "#c8302a" }
S.pr_steamknight = A(
  "..................",
  ".ww...............",
  "w..w....kkkk......",
  ".ww....kggggk.....",
  ".kbk..kgGGGGgk....",
  ".kbk.kgGkkkkGgk...",
  ".kbk.kgGGGGGGgk...",
  "kbbbkkgGkGkGGgk...",
  "kbbbgggggggggk....",
  "kbbgGGGGhhhGGgk...",
  ".kbgGGGhHkHhGggk..",
  "..kgGGGhHHHhGgGgk.",
  "..kgGGGGhhhGGggk..",
  "...kgggggggggkk...",
  "....kggkkkggk.....",
  "....khhk.khhk.....",
  "...khhhk.khhhk....",
  "....kkk...kkk....."
)
PALS.steamknight = { G = "#e2b33c", H = "#ffffff", b = "#4a4a52", g = "#a8701a", h = "#8d9ab2", k = "#1b1530", w = "#e6edf7" }
S.pr_repairbot = A(
  "..................",
  "..................",
  ".......k..........",
  "......kzk.........",
  ".....kzzzk........",
  "......kzk.........",
  "....kkhhhkk.......",
  "...khhHHHhhk..kk..",
  "..khHHooHHHhkkhhk.",
  "..khHoOOoHHhkhkkhk",
  "..khHHooHHHhkkhhk.",
  "..khhhhhhhhhhhhk..",
  "..khHHHHHHHhkkk...",
  "..khhhhhhhhhk.....",
  ".kLLLLLLLLLLLk....",
  "kLlLlLlLlLlLlLk...",
  ".kLLLLLLLLLLLk....",
  "..kkkkkkkkkkk....."
)
PALS.repairbot = { H = "#8fe07a", L = "#4a4a52", O = "#ffffff", h = "#3a8a5a", k = "#1b1530", l = "#8d9ab2", o = "#6ef0ff", z = "#5aff6a" }
S.pr_cannonmech = A(
  "..................",
  "..................",
  "..................",
  "..................",
  "....kkkkk.........",
  "...khhhhhk........",
  "..khHHHHHhk.......",
  "..khHfHfHhkkkkkkk.",
  "..khhhhhhhhhhhhhhk",
  ".kaaaaaaaHHHHHHHhk",
  ".kaAAAAaaHhhhhhhhk",
  ".kaAAAAaahhhhhhhk.",
  ".kaaaaaaaakkkkkk..",
  "..kkhhhhhk........",
  "..khkkhkkhk.......",
  ".khk.khk.khk......",
  "khhkkhhhkkhhk.....",
  ".kk..kkk..kk......"
)
PALS.cannonmech = { A = "#e2b33c", H = "#a8acb8", a = "#c8701a", f = "#ff8a2a", h = "#5a5f6a", k = "#1b1530" }
S.pr_magnetron = A(
  "..................",
  "...o..k..o........",
  "....okgko.........",
  ".....kgk..........",
  "....kgggk.........",
  "....kkgkkk........",
  "...khhhhhhk.......",
  "...khoHHohk.......",
  ".kkkhhhhhhkkk.....",
  "krrkaaaaaakrrk....",
  "rHHraAooAarHHrk...",
  "rkkraAooAarkkrk...",
  "rkkraaaaaarkkrk...",
  "HHkkaaaaaakkHHk...",
  "kk.khhkkhhk.kk....",
  "...khhkkhhk.......",
  "..khhhkkhhhk......",
  "...kkk..kkk......."
)
PALS.magnetron = { A = "#6ab4d8", H = "#e6edf7", a = "#2a6a8a", g = "#e2b33c", h = "#5a6478", k = "#1b1530", o = "#6ef0ff", r = "#d8433a" }
S.pr_titanmech = A(
  ".......k.k.k......",
  "......krkrkrk.....",
  "......kghghgk.....",
  "...kkkkghghgk.....",
  "..kggggggggggk....",
  ".kgGGGGGGGGGGgk...",
  ".kgGfffffffGGgk...",
  ".kgGGGGGGGGGGgkk..",
  "kgggggggggggggggk.",
  "gGGgaaaaaaaaagGGgk",
  "gGGgaAAAAAAAagGGgk",
  "ggggakaaaaakaggggk",
  "kggkaaaaaaaaakggk.",
  ".kkkaaakkkaaakkk..",
  "...kgggk.kgggk....",
  "..kgGGgk.kgGGgk...",
  "..kggggk.kggggk...",
  "...kkkk...kkkk...."
)
PALS.titanmech = { A = "#ff6a4a", G = "#ffd84a", a = "#8e2420", f = "#6ef0ff", g = "#a8701a", h = "#5a5f6a", k = "#1b1530", r = "#ff3434" }
S.pr_chronoclock = A(
  "....kgkgkgk.......",
  "....kgggggk.......",
  "...kgpppppgk......",
  "...kgpOpOpgk......",
  "..kkgpppppgkk.....",
  ".kgggggggggggk....",
  "kgGGGGGGGGGGGgk...",
  "kgGGGGGkGGGGGgk...",
  "kgGkGGGkGGGkGgk...",
  "kgGGGGGkkkkGGgk...",
  "kgGGGGGGGGGGGgk...",
  "kgGGGGGkGGGGGgk...",
  ".kgggggggggggk....",
  "..kkkkkgkkkkk.....",
  ".....kgggk........",
  ".....kgpgk........",
  "......kgk.........",
  ".......k.........."
)
PALS.chronoclock = { G = "#f3e2ff", O = "#ffe680", g = "#8f4bc4", k = "#1b1530", p = "#3a2350" }
S.pr_troubadour = A(
  "........kyyk......",
  "....kkkkyyk.......",
  "...kaaaayk........",
  "..kaaAAAAak.......",
  "...ksssssk........",
  "...ksksksk........",
  "...ksssssk........",
  "..krrksssk..kk....",
  ".krraaaaaakkBBk...",
  ".krkaAaaaaBBbBk...",
  ".krkaAaaBBbbBk....",
  "..kkaAaBbkbBsk....",
  "...kaaaBbbBkk.....",
  "...kbbbgBBbk......",
  "....kaakaak.......",
  "....kbbkbbk.......",
  "...kbbbkbbbk......",
  "....kkk.kkk......."
)
PALS.troubadour = { A = "#7fd36a", B = "#c8803a", a = "#2f7a34", b = "#7a4a1a", g = "#e2b33c", k = "#1b1530", r = "#c8302a", s = "#f2c29a", y = "#ffd84a" }
S.pr_warbard = A(
  ".kck......kck.....",
  ".kcckkkkkkkcck....",
  "..kcchhhhhcck.....",
  "...khhHHHhhk......",
  "...ksssssssk......",
  "...kskssksfk......",
  "...kfffffffk......",
  "..k.kfffffk.k.....",
  ".kskaaaaaaaksk....",
  "ktksaaaaaaasktk...",
  ".k.khhhhhhhk.k....",
  "..khwwwwwwwhk.....",
  "..khrwrwrwrhk.....",
  "..khwwwwwwwhk.....",
  "...khhhhhhhk......",
  "....kaakaak.......",
  "...kbbbkbbbk......",
  "....kkk.kkk......."
)
PALS.warbard = { H = "#c8903a", a = "#a8102a", b = "#4a2a1a", c = "#e9e2cf", f = "#d86a1a", h = "#8a5a2a", k = "#1b1530", r = "#d8433a", s = "#f2c29a", t = "#e9e2cf", w = "#f1e3c2" }
S.pr_lullabard = A(
  ".........k........",
  ".....kkkkyk.......",
  "....kaaaayk.O.....",
  "...kaaaakk.....O..",
  "..kaaAaak.........",
  "..kaAAAAak........",
  "...ksssssk........",
  "...kskkskk........",
  "...ksssssk..kk....",
  "..kaaaaaaakkggk...",
  ".kaAaaaaagggtgk...",
  ".kaAaaaaagtgtgk...",
  ".kskaaaagttgtgk...",
  "..kaaaaasgttggk...",
  "..kaaaaaagggggk...",
  "..kaaaaaaakkkk....",
  "...kwwkkwwk.......",
  "....kk..kk........"
)
PALS.lullabard = { A = "#8a7ae8", O = "#e4f2ff", a = "#4a3a8a", g = "#e2b33c", k = "#1b1530", s = "#f2c29a", t = "#fff3b0", w = "#e4f2ff", y = "#fff3b0" }
S.pr_skald = A(
  "..................",
  ".k.kkkkk.k........",
  "kwkhhhhhkwk.......",
  "kwwhHHHhwwk.......",
  ".kwhHHHHwk........",
  "..ksssssssk.......",
  "..ksksskskkk......",
  "..kyyyyyyccck.....",
  "..kyyyyyccCcck....",
  ".kBByyyByykcCck...",
  "kBBBaayaaaakcck...",
  "kBBkaayaaaskkk....",
  ".kkkaykyaaak......",
  "...kaaaaaaak......",
  "...kbbbgbbbk......",
  "....kaakaak.......",
  "...kbbbkbbbk......",
  "....kkk.kkk......."
)
PALS.skald = { B = "#8a6a4a", C = "#a89f8a", H = "#c9cbd6", a = "#3a5a7a", b = "#4a3a2a", c = "#e9e2cf", g = "#e2b33c", h = "#6b6f80", k = "#1b1530", s = "#f2c29a", w = "#f4f8ff", y = "#ffd84a" }
S.pr_dissonant = A(
  ".....kqk..........",
  "....kqQqk.........",
  "....kkqQqk........",
  "...kssssssk.......",
  "...kkkkkksk.......",
  "...kssssssk.......",
  "...kkssssk....k...",
  "..kpppppppk..krk..",
  ".kpHpppppHpkkrrk..",
  ".kpkppppppkrrrk...",
  ".kskppppprrrsk....",
  "..kkppprrrrkk.....",
  "...kpprrrrk.......",
  "...krrrrrk........",
  "...krrkpppk.......",
  "...kppkpppk.......",
  "..kbbbkbbbk.......",
  "...kkk.kkk........"
)
PALS.dissonant = { H = "#c9cbd6", Q = "#6ef0ff", b = "#1b1530", k = "#1b1530", p = "#3a2d52", q = "#ff4aff", r = "#c06bff", s = "#f2c29a" }
S.pr_maestro = A(
  "...........k......",
  "...kkkkk..kOk...y.",
  "..kwwwwwkkkOk..yy.",
  ".kwwwwwwwwkOk..y..",
  "kwwwssssswkOk.yy..",
  ".kwwskskwkksk.....",
  "..kwssssskssk.....",
  "...kkssskssk......",
  "...kaaraaak.......",
  "..kaaOrOaak.......",
  ".kaaaOOOaak.......",
  ".kakaaOaaak.......",
  ".kskaaOaaak.......",
  "..kaaaaaaak.......",
  "..kaakaaaak.......",
  "...kkaakaak.......",
  "...kbbbkbbbk......",
  "....kkk.kkk......."
)
PALS.maestro = { O = "#ffffff", a = "#1b1530", b = "#3a2a2a", k = "#1b1530", r = "#d8433a", s = "#f2c29a", w = "#f4f8ff", y = "#ffe680" }
S.pr_requiembard = A(
  "..................",
  "......kkkk........",
  ".....kwwwwk.......",
  "....kwOOOOwk......",
  "...kwOwwwwOwk.....",
  "...kwOkkkkOwk.k...",
  "...kwwkUkUkwkkFk..",
  "...kwwkkkkwwkkfk..",
  "...kwwwwwwwwkkck..",
  "..kwwwwwwwwwwkck..",
  ".kwOwwgwwwwwwsck..",
  ".kwOkwgwwwwwkkk...",
  ".ksskgggwwwwk.....",
  ".khHkwwwwwwwk.....",
  ".khHkwwwwwwwk.....",
  ".khkkwOwwwOwk.....",
  "..kkwwwwwwwwwk....",
  "....kkkkkkkkk....."
)
PALS.requiembard = { F = "#ffe680", H = "#e6edf7", O = "#ffffff", U = "#78a8f2", c = "#f1e3c2", f = "#ff8a2a", g = "#78a8f2", h = "#8d9ab2", k = "#1b1530", s = "#f2c29a", w = "#c9d2e0" }
S.pr_firedrake = A(
  "..................",
  "..................",
  "..................",
  "..................",
  "..................",
  "..................",
  ".k................",
  "kFk...............",
  "FfFk.......k.k....",
  "kfk.......kakak...",
  "kak..k.k.kaaaaak..",
  "kakkkakakaaaakaak.",
  ".kaaaaaaaaaaaaAAkk",
  "..kaAAAAAAAaaaAAk.",
  "..kaaaaaaaaaaakfk.",
  "..kaakaakkaakaaFk.",
  ".kaakkaakkaakkaak.",
  "..kk..kk..kk..kk.."
)
PALS.firedrake = { A = "#ffd84a", F = "#ffe14a", a = "#c84a1a", f = "#ff8a2a", k = "#1b1530" }
S.pr_emberwing = A(
  "..................",
  "..................",
  "..kk..............",
  ".kaak........kk...",
  ".kaAak......kaak..",
  ".kaAAak....kaAak..",
  ".kaAfAak..kaAAak..",
  ".kaAAfAakkaAfAak..",
  ".kaAAAAAaaAAAAak..",
  "..kaAfAAAaAfAAaak.",
  "...kaaAAaaaaakaak.",
  ".k..kaaaaaAAaaAyyk",
  "kak.kaaAAAAAaakkk.",
  "kaakaaaAAAAAak....",
  ".kaaaakaaAAak.....",
  "..kkkkkaakaak.....",
  ".....kyykkyyk.....",
  "......kk..kk......"
)
PALS.emberwing = { A = "#d86a1a", a = "#5a1a0a", f = "#ffe680", k = "#1b1530", y = "#ffd84a" }
S.pr_jadedrake = A(
  "..................",
  "..........k..k....",
  ".........kykkyk...",
  ".........kyykyyk..",
  ".........kzzzzzk..",
  "........kzzzzkzzk.",
  "...k....kzZZZZZZyk",
  "..krkk..kzzzrkkyk.",
  ".krzzzkkzzzZrk.k..",
  "krzZZZzzzZzrk.....",
  "kzZrkkzZZZzk......",
  "kzrk..kyzyzk......",
  "kzk....kykyk......",
  ".k......k.k.......",
  "..................",
  "..................",
  "..................",
  ".................."
)
PALS.jadedrake = { Z = "#6fdc8a", k = "#1b1530", r = "#d8433a", y = "#ffe14a", z = "#2c8a5c" }
S.pr_frostwyrmling = A(
  "..................",
  "..................",
  "..................",
  "..........k.k.....",
  ".........kUkUk....",
  "........kaaaaakkk.",
  "...k...kaaaaakaUOk",
  "..kUk.kaaaaAAAUOUk",
  ".kUaUkkaaAAAkkkOk.",
  "..kaUkaaaAak...k..",
  "...kaUaaAAAak.....",
  "..kUkaaaAAAAak....",
  ".kUaaaaaAAAAak....",
  "..kaaaaaaAAAak....",
  ".kaaaaaaaAAak.....",
  "kaakaaakaaaak.....",
  "kakkUUUkkUUUk.....",
  ".k..kkk..kkk......"
)
PALS.frostwyrmling = { A = "#d8f4ff", O = "#ffffff", U = "#bff4ff", a = "#3a8ad8", k = "#1b1530" }
S.pr_shadowdrake = A(
  "..................",
  "..................",
  "..................",
  ".k......k.........",
  "kak....kak..k..k..",
  "kaak..kaak.kckkck.",
  "kaPakkaPak.kaaaak.",
  "kaPPaaPPakkaaqaaak",
  ".kaPPPPak.kaaaaaPP",
  ".kakaPPaakaaakkkkk",
  "..kakaaaaaaPak....",
  "..kk.kaaaaPPPak...",
  ".kakkaaaaPPPPak...",
  "kaakaaaaaPPPak....",
  "kakkaakaaakaak....",
  ".kq.qq.qqk.qq.....",
  "...q..q..q..q.....",
  ".................."
)
PALS.shadowdrake = { P = "#6a33c9", a = "#2b1a3a", c = "#c9c3d6", k = "#1b1530", q = "#c06bff" }
S.pr_elderdragon = A(
  "...........k...k..",
  "..........kck.kck.",
  "..........kcckcck.",
  ".kk......kaaaaaak.",
  "kaak....kaaaaeaaak",
  "kaAak...kaaaaaaAyy",
  "kaAAak.kaaaAAAAAkk",
  "kaAAAakaaaAkkkkk..",
  "kaAAAAaaagaakkk...",
  ".kaAAaagggaak.....",
  "..kaaaaggggaak....",
  "..kkaaagggggaak...",
  ".kakaaagggggaak...",
  "kaakaaaaggggaak...",
  "kakkaaakkkaaak....",
  "kakkaaak.kaaak....",
  ".kaaccck.kccck....",
  "..kkkkk...kkk....."
)
PALS.elderdragon = { A = "#d8433a", a = "#7a1f2b", c = "#e9e2cf", e = "#ffd84a", g = "#ffb04a", k = "#1b1530", y = "#ff8a2a" }
S.pr_goldendragon = A(
  "..................",
  "..................",
  "..........kkkk....",
  ".kk......kyyyyk...",
  "kOOk.....kckkck...",
  "OwwOk...kaaaaak...",
  "OwwwOk.kaaaaakak..",
  "kOwwwOkkaaaAAAAAk.",
  "kOwwwwOkaaAAAAkk..",
  ".kOwwwwOaaAAak....",
  "..kOwwwOaaAAAak...",
  "...kOOOaaaAAAak...",
  "..k.kkaaaaAAAak...",
  ".kakkaaaaaAAak....",
  "kaakaakaaaaaak....",
  ".kaaakkaakkaak....",
  "..kkk.kcckkcck....",
  ".......kk..kk....."
)
PALS.goldendragon = { A = "#fff3b0", O = "#ffffff", a = "#c8900f", c = "#ffffff", k = "#1b1530", w = "#e6edf7", y = "#ffe680" }
S.pr_icesprite = A(
  "..................",
  "..k...............",
  ".kUk.....kkk......",
  "kUoUkk..kAAAk.....",
  ".kUkUUkkAAAAAk....",
  "..kUooUkAsksAk....",
  "..kUoooUAsssAk....",
  "...kUoooUsssk.....",
  "..kUooooUaaak.....",
  "...kUUUUkaAask....",
  "..kUoooUkaaak.....",
  "...kUUUkkaAak.....",
  "....kkk.kaaak.....",
  "...k.....kak......",
  "..kUk.....k.......",
  ".kUoUk...kUk......",
  "..kUk.....k.......",
  "...k.............."
)
PALS.icesprite = { A = "#9fdcff", U = "#bff4ff", a = "#4a9ad8", k = "#1b1530", o = "#6ef0ff", s = "#f2c29a" }
S.pr_glacierheart = A(
  "..................",
  "..................",
  ".....kkkkkk.......",
  "....kUUUUUUk......",
  "...kUAAAAAAUk.....",
  "...kUAkAAkAUk.....",
  "..kkUAAAAAAUkk....",
  ".kUUUUUUUUUUUUk...",
  "kUAAUAAAAAAUAAUk..",
  "kUAAUAAooAAUAAUk..",
  "kUAAUAoOOoAUAAUk..",
  "kUAAUAAooAAUAAUk..",
  "kUUUUAAAAAAUUUUk..",
  ".kkkkUUUUUUkkkk...",
  "...kUAAUkUAAUk....",
  "...kUAAUkUAAUk....",
  "...kUUUUkUUUUk....",
  "....kkkk.kkkk....."
)
PALS.glacierheart = { A = "#7fb0e0", O = "#ffffff", U = "#2a5a8a", k = "#1b1530", o = "#6ef0ff" }
S.pr_snowdancer = A(
  "..................",
  "..Ok.......kO.....",
  "..ksk.kkk.ksk.....",
  "...kskAAAksk......",
  "....ksAAAAsk......",
  ".....ksksAkk......",
  ".....kssskkrk.....",
  "....krrrrrrrkk....",
  ".....kaAaakkkrk...",
  "....kaAAaaak.k....",
  "...kaAAAaaaak.....",
  "..kaAAAAaaaaak....",
  ".kaAAaAAaAaaaak...",
  ".kaaaaaaaaaaaak...",
  "..kkkkskkskkkk....",
  ".O...kskksk...O...",
  "....ksskkssk......",
  ".....kk..kk......."
)
PALS.snowdancer = { A = "#ffffff", O = "#e8f8ff", a = "#cfe3ff", k = "#1b1530", r = "#ff8ac8", s = "#f2c29a" }
S.pr_frostgiant = A(
  "..............k...",
  "....kkkkkk...kUk..",
  "...kwwwwwwk.kUoUk.",
  "..kwwwwwwwwkkUoUk.",
  "..kwbbbbbbwkkUoUk.",
  "..kwbkbbkbwk.kUk..",
  "..kwwbbbbwwk.khk..",
  "..kwwwwwwwwk.khk..",
  ".kbbwwwwwwbbkkhk..",
  "kbbbbwwwwbbbbbhk..",
  "kbbkbbbbbbbkbbhk..",
  "kbbkbbbbbbbkkkhk..",
  "kwwkffffffffkkhk..",
  ".kkkfFfFfFffk.k...",
  "...kbbbkkbbbk.....",
  "...kbbbkkbbbk.....",
  "..kwwwwkkwwwwk....",
  "...kkkk..kkkk....."
)
PALS.frostgiant = { F = "#c4a070", U = "#bff4ff", b = "#4a7ac8", f = "#8a6a4a", h = "#8aa8c8", k = "#1b1530", o = "#6ef0ff", w = "#e8f8ff" }
S.pr_crystalmage = A(
  ".......k..........",
  "....k.kqk.k.......",
  "...kqkkqQkqk......",
  "...kqQkqQqQk......",
  "....kqQqQQk.......",
  ".....kqQqkk....k..",
  "....kaaaaaak..kqk.",
  "....kaOaaOak.kqQk.",
  "....kaaaaaak..kqk.",
  ".k.kaaaaaaaak..k..",
  "kqkaaAAaaAAaak....",
  "qQkaaaAaaAaaask...",
  "kqkaaaaAAaaaak....",
  ".kkaaaaAAaaaak....",
  "..kaaaaaaaaaak....",
  ".kaAaaaaaaaaAak...",
  ".kaaaaaaaaaaaak...",
  "..kkkkkkkkkkkk...."
)
PALS.crystalmage = { A = "#8a6ad8", O = "#e0b0ff", Q = "#e0b0ff", a = "#3a2a6a", k = "#1b1530", q = "#6a33c9", s = "#f2c29a" }
S.pr_wintersovereign = A(
  "..................",
  "....k..k..k.......",
  "...kUkkUkkUk...k..",
  "...kUUkUUkUUk.kOk.",
  "...kUUUUUUUUkkOoOk",
  "...kUoUUoUUUk.kOk.",
  "....kssssssk..khk.",
  "....kskskskk..khk.",
  "...kksssssskk.khk.",
  "..kwwaaaaaawwkkhk.",
  ".kwwaaAaaAaawwkhk.",
  ".kwaaaAAAAaaasshhk",
  ".kwaaaaAAaaaawkhk.",
  ".kwaaaaAAaaaawkk..",
  ".kwaaaaAAaaaawk...",
  ".kwaaaaAAaaaawk...",
  ".kwwwwwwwwwwwwk...",
  "..kkkkkkkkkkkk...."
)
PALS.wintersovereign = { A = "#c9e4ff", O = "#ffffff", U = "#d8f4ff", a = "#5a8ad8", h = "#c9d2e0", k = "#1b1530", o = "#3b6fd1", s = "#f2c29a", w = "#ffffff" }
S.pr_auroraspirit = A(
  "......kkkkk.......",
  ".....kaaaaak......",
  "....kaAAAAAak.....",
  "....kaOAAOAak.k...",
  "..k.kaAAAAAakkrk..",
  ".kzk.kaAAAakkrRk..",
  "kzZkkzzzzzzzrRk...",
  ".kZzzZZZZZZzRk....",
  "..kkaZZAAZZaak....",
  "..krraAAAAAaak....",
  ".krRRRRRAAAak.....",
  ".kRrkaAArrrrrk....",
  "..kkkaAArRRRRrk...",
  ".....kaAakkkRrk...",
  "......kaak..kk....",
  ".......kak........",
  "........k.........",
  ".................."
)
PALS.auroraspirit = { A = "#8affc8", O = "#ffffff", R = "#ff8ac8", Z = "#8affc8", a = "#2c8a6c", k = "#1b1530", r = "#c84a9a", z = "#2cc88a" }
return { SPR = S, PAL = PALS, RIG = RIG, BOW = BOW }
