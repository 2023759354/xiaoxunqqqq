-- 自动生成（tools/sprites/build8.py）：第十二次更新——十三个超凡角色的新形象（20×20）
-- 赤月弓神、血根古神两张图后来手工重绘过（含弓弦 / 根爪骨架），重新跑生成脚本前先把这两张同步过去
-- 每个超凡角色一张按名字重新设计的图（键名 sx_兵种），自带调色板；武器 / 弓弦骨架和图一起登记
local js = require("game.compat")
local A = js.A
local S, PALS, RIG, BOW = {}, {}, {}, {}
S.sx_warrior = A(
  "..kRk.k.k.k.kRk.kRk.",
  "..krrkgkGkgkrrkkrOrk",
  "...krgggGgggrk.krOrk",
  "....kaAHHHAak..krOrk",
  "....kaDRORDak..krOrk",
  "..kkkaAaRaAakkkkrOrk",
  ".kAHAkagmgakAHAkrOrk",
  "kaAHAaaaRaaAHAakrOrk",
  "kggggaagRgaagggkrOrk",
  "rmAakaAagaAakaAakrOr",
  "rmAakaaagaaakkaAkrOr",
  "rmAAkgggGgggkkaggGgg",
  "rmkkkaAmRmAakkaAAkkk",
  "rrmkkaamRmaak.kkkmk.",
  "rrmkkaAmRmAak...kgk.",
  "rrrmkaAkmkAak....k..",
  "rrmmkaAkkkAak.......",
  "rkrmaHak.kaHak......",
  "k.kkaaak.kaaak......",
  "....kkk...kkk......."
)
PALS.sup_warrior = { A = "#676088", D = "#120e1c", G = "#ffe680", H = "#b4aed4", O = "#fff2ea", R = "#ff3b3b", a = "#3a3352", g = "#d9a730", k = "#1b1530", m = "#5e0b18", r = "#b3142a" }
RIG.sx_warrior = { k = "heavy", p = A(17.5, 12.5), t = A(17.5, 0.5), m = "0:16-18 1:15-19 2:15-19 3:15-19 4:15-19 5:15-19 6:15-19 7:15-19 8:15-19 9:15-19 10:15-19 11:16-19 12:17-19 13:15-18 14:16-18" }
-- 赤月弓神（重绘）：赤发月冠的女猎神，暗紫斗篷配血色内衬，背负箭囊，手持新月形血月长弓
S.sx_archer = A(
  ".k.k.....kk...kk....",
  "kFkFk...kMMk..kWk...",
  "kFkFk.kkmMMnk.ktBk..",
  ".kgk.kmnnnNnk.ktkBk.",
  ".kQkkmnnNnnsk.ktkWBk",
  ".kQkmnnnnsOsk.ktkWBk",
  ".kgkmnnnnsRsk.ktkWBk",
  ".kQkmnnmnSssk.ktkWBk",
  ".kvmnmmkkkkk..ktkWBk",
  "kvVmnmkaHHHk..ktkHHk",
  "kvrkmkaAHeHAAsstkHHk",
  "kvrvkkaAAHAk..ktkBbk",
  "kvrvkaaAaaak..ktkBbk",
  "kvrvkHHgHHHk..ktkBbk",
  "kvvrkaAaaAak..ktkBbk",
  ".kvrkaAkkAak..ktkBbk",
  ".kvvkaak.kak..ktkBk.",
  "..kkkHak.kHk..ktBk..",
  "....kbbk.kbbk.kWk...",
  "....kkkk.kkkk.kk...."
)
PALS.sup_archer = { A = "#4b3f7d", B = "#ff3b3b", C = "#d8203a", F = "#ffe0ec", H = "#c9c3e6", M = "#f4ecff", N = "#ff5a64", O = "#ffffff", Q = "#7a3a2a", R = "#ff3b3b", S = "#d9a48a", V = "#4a2a5e", W = "#ffd6e0", a = "#2a2346", b = "#a8102a", c = "#8a0e22", e = "#ff3b3b", g = "#e2b33c", k = "#1b1530", m = "#6e0a1e", n = "#c0182e", q = "#5a2a3a", r = "#d8203a", s = "#f6d2bc", t = "#ffe0ec", v = "#2a1838" }
BOW.sx_archer = { a = A(15, 1), b = A(15, 18), n = A(15, 10), m = "2:14-15 3:14-15 4:14-15 5:14-15 6:14-15 7:14-15 8:14-15 9:14-15 10:14-15 11:14-15 12:14-15 13:14-15 14:14-15 15:14-15 16:14-15 17:14-15 10:13-14", hd = "10:13-14", pull = 5, len = 10 }
S.sx_mage = A(
  ".k.............kkk..",
  "kck.........k.krRrk.",
  "kcCkkkkkkkkkCkmREOrk",
  ".kcCCppRppCCckmmRERk",
  "..kcChhhhhCckkmRRRrk",
  "...kPhRhRhPk..krRrk.",
  "..kPrhhmhhrPk.kgagk.",
  ".kPrrphhhprrPk.kak..",
  ".kPqPppgppPqPk.kak..",
  "kPPpPprRrpPpPqkkak..",
  "kPpkPprRrpPkkPqhak..",
  "khpkPpprppPk.kkkak..",
  ".kPpPppqppPpk..kak..",
  ".kPppPppqppPpk.kak..",
  "kPpppPppqpppPpkkak..",
  "kPpprPppqppprPkkak..",
  "kPprrPpqqpprrPkkak..",
  "krRrkrRrrRrkrRrkak..",
  ".krk.krkkrk.krkkgk..",
  "..k...k..k...k..k..."
)
PALS.sup_mage = { C = "#a8987e", E = "#ff8e6a", O = "#fff2ea", P = "#53307a", R = "#ff3b3b", a = "#4a3a5e", c = "#e8dfcf", g = "#d9a730", h = "#c4b4d8", k = "#1b1530", m = "#5e0b18", p = "#2c1c42", q = "#9466c8", r = "#b3142a" }
RIG.sx_mage = { k = "staff", p = A(16.5, 10.5), t = A(16.5, 1.5), m = "1:14-18 2:14-19 3:14-19 4:14-19 5:14-18 6:14-18 7:15-17 8:15-17 9:15-17 10:16-17 11:15-17 12:15-17 13:15-17 14:15-17 15:15-17 16:15-17 17:15-17 18:15-17" }
S.sx_tiger = A(
  "......k..k..k.......",
  ".....kRkkFkkRk......",
  "...kkfRfFFFfRfkk....",
  "..kaaffRfFfRffaak...",
  "..karaaRaRaRaarak...",
  "..kaaaaaRaRaaaaak...",
  ".kaAaFFmaaamFFaAak..",
  ".karaaawwmwwaaarak..",
  "kkaArawwwwwwwarAakk.",
  "FkkkawOmRRRmOwakkaOk",
  "fk.kaawOmmmOwaakaAOk",
  "akkfkawwwwwwwakaAOk.",
  "akfRaaaawwwaaaaakk..",
  "kaffaRaawwwaaRaak...",
  ".kaaaaRawwwaRaaak...",
  "..kaaRaaawaaaRaak...",
  "..kaaaakaaakaaaak...",
  "..kaakaakkkaakaak...",
  "..kaOkaOk.kaOkaOk...",
  "...kk.kk...kk.kk...."
)
PALS.sup_tiger = { A = "#64587a", F = "#ffd84a", O = "#ffffff", R = "#ff3b3b", a = "#3a3046", f = "#ff6a2a", k = "#1b1530", m = "#4a0a14", r = "#c0182e", w = "#ddd4e2" }
RIG.sx_tiger = { k = "paw", p = A(16.5, 10.5), t = A(19, 9.5), m = "9:15-19 10:15-19 11:15-18 12:15-17" }
S.sx_bear = A(
  "...k...........k....",
  "..kHk....k....kHk...",
  "..kaHkkkkrkkkkHak...",
  "...kaarrRRRrraak....",
  "...karRRRRRRRrak....",
  "..kamrrrmmmrrrmak...",
  "..karbbFbbbFbbrak...",
  ".kkarbbBBDBBbbrakk..",
  "kHkkrmbBOmOBbmrkkHk.",
  "kaHakmrrmmmrrmkaHak.",
  "arRRrarrfFfrrarRRrak",
  "amrrmaRrrfrrRamrrmak",
  "abBbkarRrFrRrakaAAHk",
  "bBbkkarrfrfrrakaAHOk",
  "OOk.kAAAHFHAAAkaaAOk",
  "kk..kmrrmmmrrmkkkkk.",
  "...kabbbkkkbbbak....",
  "...karrak.karrak....",
  "..kaAAAak.kaAAAak...",
  "...kkkkk...kkkkk...."
)
PALS.sup_bear = { A = "#6a6a7e", B = "#a8784a", D = "#1b1530", F = "#ffd84a", H = "#b4b4c8", O = "#ffffff", R = "#e8404a", a = "#3a3a4a", b = "#6b4527", f = "#ff6a2a", k = "#1b1530", m = "#5a0a18", r = "#a8142a" }
RIG.sx_bear = { k = "paw", p = A(15.5, 13.5), t = A(18.5, 14), m = "12:15-19 13:15-19 14:15-19 15:15-18" }
S.sx_flytrap = A(
  "....................",
  ".u..kkkkkkkkkkkku...",
  "...kaAAAAAAAAAAak...",
  "..kaAAqAAAAAqAAAak..",
  "..kaAAAAAAAAAAAAak..",
  "..kaOmOmOmOmOmOmak..",
  "..kammmmoUUommmmak..",
  "..kammmoUOUommmmaku.",
  "..kamOmOmOmOmOmOak..",
  "..kaAAAAAAAAAAAAak..",
  "u..kaAqAAAAAAqAak...",
  "....kaaAAAAAAaak....",
  ".kkkkkkRxXxRkkkkkk..",
  "kzZZzkkkXxXkkkzZZzk.",
  "kzZZZxRkxXxkRxZZZzk.",
  ".kzzkkRxkXxXkxRkkzzk",
  "..kkkkxxxXxxxkk..kk.",
  "...kRxxXxxXxxRkk....",
  "..kxxRkxxkxxkRxxk...",
  "...kkk.kk.kk.kkk...."
)
PALS.sup_flytrap = { A = "#9a2252", O = "#ffffff", R = "#ff3b3b", U = "#d8fff8", X = "#6a3a5e", Z = "#4f8a4a", a = "#5a1238", k = "#1b1530", m = "#26061a", o = "#5ad8d0", q = "#e0588a", u = "#9af0e8", x = "#3a2238", z = "#2a5a3a" }
S.sx_sunflower = A(
  ".....k...kk...k.....",
  "....kRk.kRRk.kRk....",
  "...kRfRkffffkRfRk...",
  "..kkffffFFFFffffkk..",
  ".kRfFFggGGGGggFFfRk.",
  "kRfFFgGGGGGGGGgFFfRk",
  "kRfFgGGnnGGnnGGgFfRk",
  "kfFFgGRGGGGGGRGgFFfk",
  "kRfFgGGGGrrGGGGgFfRk",
  "kRffFgGGGGGGGGgFffRk",
  ".kRfFFggGGGGggFFfRk.",
  "..kfffFFFFFFFFfffk..",
  "...kRfRkfzzfkRfRk...",
  ".kkkkRk.kzzk.kRkkkk.",
  "kFZZzzkkkzZkkkzzZZFk",
  ".kZZZzzxkzZkxzzZZZk.",
  "..kkZZzxxzZxxzZZkk..",
  "....kkkkkzZkkkkk....",
  "......kxxzZxxk......",
  ".......kkkkkk......."
)
PALS.sup_sunflower = { F = "#ffd84a", G = "#ffe680", R = "#ff3b3b", Z = "#8fd36a", f = "#ff6a2a", g = "#d9a730", k = "#1b1530", n = "#a8701a", r = "#c0182e", x = "#2a5a2a", z = "#4a8a3a" }
-- 血根古神（第十五次重绘，不持武器）：鹿角枝冠挂着血叶，树皮面孔上三只血瞳，肋状树皮裂开露出搏动的血心，
-- 下半身是滴血的根须；右臂是一只巨大的根爪（单独登记骨架，普攻时高举抓下）
S.sx_treant = A(
  ".kRRk..k..k..kRRk...",
  ".kRBRkkRkkRkkRBRk...",
  "..kbBkkBkkBkkBbk....",
  "...kbBbbBBbbBbk.....",
  "....kkBbBBbBkk......",
  "....kBbBReBbBk......",
  "...kBxxxRrxxxBk.....",
  "...kBxEExxEExBk.....",
  "...kBbxxxxxxbBk.....",
  "....kBbxrrxbBk.kk...",
  "...kkkBbxrbBk.kBbk..",
  "..kbBZBcBBcBZkkbBBk.",
  ".kBbzBcRRRRcBzkkBbBk",
  ".kBkBbcReERcbBkkbBbk",
  "kBrkBbcRRRRcbBkXBbXk",
  "kXkkkBbcrrcbBkkXkXXk",
  ".kkbBbBBrBBbBbkk.kk.",
  ".kbBbkbBrBbkbBbkk...",
  "kbBkkkbkrkkbkkkBbk..",
  "kXk..kXkkXkkXk.kXk.."
)
PALS.sup_treant = { B = "#6b4527", E = "#ff3b3b", R = "#ff3b3b", X = "#d8203a", Z = "#6fae4a", b = "#43281a", c = "#c9a27a", e = "#ffd0c0", k = "#1b1530", r = "#9a1024", x = "#1a0a0a", z = "#356a34" }
RIG.sx_treant = { k = "rootclaw", p = A(15.5, 10.5), t = A(17.0, 15.5), m = "9:15-16 10:14-17 11:14-18 12:15-19 13:15-19 14:15-19 15:14-19 16:15 16:17-18" }
S.sx_hawk = A(
  "....................",
  ".k................k.",
  "kak..............kak",
  "kaAk............kAak",
  "kaFAk....kk....kAFak",
  "kaAFrk..kFFk..krFAak",
  "kaaAFrkkOOOOkkrFAaak",
  ".kaAAFrHOOROgrFAAak.",
  "kaaaAAFrHOOgrFAAaaak",
  "kakaAArrHHHHrrAAakak",
  ".kakaArRarraRrAakak.",
  "..kakaAaaFaaaAakak..",
  "...k.kkaaaFaakk.k...",
  "......kaaFaaak......",
  "......kaAaFaAk......",
  "......kkaaaakk......",
  ".....kgkaRRakgk.....",
  "....kggkaRRakggk....",
  ".....kkkrRRrkkk.....",
  "........kkkk........"
)
PALS.sup_hawk = { A = "#4e4466", F = "#ffe14a", H = "#d8dcec", O = "#ffffff", R = "#ff3b3b", a = "#2a2438", g = "#e2b33c", k = "#1b1530", r = "#b3142a" }
S.sx_clockwork = A(
  "......k.kkkk.k......",
  "....kkgkgGGgkgkk....",
  "...kggkGkkkkGkggk...",
  "..kgkkkGrRRrGkkkgk..",
  ".kgk..kwoooowk..kgk.",
  ".kgkkkkaRwwRakkkkgk.",
  ".kRRRwkkaaaakwRRAAok",
  ".kRrRkwwRooRwwkRrRk.",
  ".kaAakwRoUUoRwkaAak.",
  ".krRrkwwRooRwwkrRrk.",
  ".kaAakkaRRRRakkaAak.",
  ".kwOwkkggggggkkwOwk.",
  "..kak.kaaaaaak.kak..",
  "...k..kwRkkRwk..k...",
  ".....kwRRkkRRwk.....",
  ".....kaAakkaAak.....",
  ".....krRrkkrRrk.....",
  "....krRRrkkrRRrk....",
  "....kaaaakkaaaak....",
  ".....kkkk..kkkk....."
)
PALS.sup_clockwork = { A = "#7a7a92", G = "#ffe680", O = "#ffffff", R = "#ff3b3b", U = "#e0ffff", a = "#3a3a4e", g = "#d9a730", k = "#1b1530", o = "#6ef0ff", r = "#b3142a", w = "#dfe4ee" }
S.sx_bard = A(
  ".......kkkk.........",
  "......krRRrkk.......",
  ".....karRRRrak......",
  "....krRRRRRRrk.k....",
  "....krRrssssRkkyk...",
  "...krRRsmssmRkyk.k..",
  "...krRRsssrskykkkBk.",
  "..krRRrkssskybbbbBk.",
  ".krRRraaaBRyBkkskk..",
  ".krRraaaaRyRRBkk....",
  ".krRaaarayBRRBk.....",
  ".krraaaryakBBk......",
  "..kraarysaark.......",
  "..krrayaaarrk.......",
  "..kaRaaaaaaRak......",
  ".kaRraaaaaarRak.....",
  ".kaRaaaRaaaaRak.....",
  "krRrRrRrRrRrRrRk....",
  ".kkkaakkaakkkkk.....",
  "....kk..kk.........."
)
PALS.sup_bard = { B = "#c8601a", R = "#ff3b3b", a = "#241a30", b = "#4a2a1a", k = "#1b1530", m = "#5a2a3a", r = "#b3142a", s = "#f6d2bc", y = "#fff3c8" }
S.sx_whelp = A(
  "..k.......kk........",
  ".kak.....kaak.......",
  "kaPak...kaPPak.k..k.",
  "kaPPak.kaPPPakkckkck",
  "kapPPakaPPpPakCckcCk",
  "kapPpPakaPpParrRrrk.",
  "kapPpPPakaPPrRryrRrk",
  "kapPpPpPakkarrrrrOEk",
  ".kapPpPpPakrrmmrmEFk",
  "..kaPpPpakrRrrrkEFk.",
  "...kaPpakrRffrrkFEk.",
  "....kaakrRfFFfrRkk..",
  ".....kkrRrfFFfrRrk..",
  ".....kcrkrfFFfrkrck.",
  "..k...kkrrffffrrkk..",
  ".kEk..krrRffffRrrk..",
  "kEFrkkrRrrkrrRrkk...",
  ".krrrrRrkkkrRrk.....",
  "..kkkkccrkkrcck.....",
  "......kkk..kkk......"
)
PALS.sup_whelp = { C = "#a8987e", E = "#ff8e6a", F = "#ffd84a", O = "#ffffff", P = "#6a2a4a", R = "#e8404a", a = "#2a1a22", c = "#e8dfcf", f = "#ff8a2a", k = "#1b1530", m = "#4a0a14", p = "#3a1a2e", r = "#b3142a", y = "#ffe14a" }
S.sx_frostling = A(
  "......k..kk..k......",
  ".....kUkkRRkkUk.....",
  "....kUAkUAAUkAUk....",
  "....kuAAuAAuAAuk....",
  "...kuAUUUUUUUUAuk...",
  "...kuURRUUUURRUuk...",
  "...kuUUUUvvUUUUuk...",
  "....kuUUUUUUUUuk....",
  "..okkkvuuAAuuvkkko..",
  ".kAUuvuAREERAuvuUAk.",
  "kAUkvuuARrrRAuuvkUAk",
  "kUk.kvuuARRAuuvk.kUk",
  ".k...kvuuAAuuvk...k.",
  "......kvuAAuvk......",
  "...o...kvAAvk...o...",
  ".......kvuuvk.......",
  "........kvuk........",
  ".......kukkvk.......",
  "......kvk..kuk......",
  ".......k....k......."
)
PALS.sup_frostling = { A = "#9fd4ff", E = "#ff8e6a", R = "#ff3b3b", U = "#e0f6ff", k = "#1b1530", o = "#bff4ff", r = "#c0182e", u = "#4a8ad8", v = "#1f4a8a" }
return { SPR = S, PAL = PALS, RIG = RIG, BOW = BOW }
