-- 更新包像素精灵：道具图标、新兵种与六七章敌人；A() 保持 JS 零基数组。
local A = require("game.compat").A
local S = {}
S.i_book = A(
  "................", "................", "...kkkkkkkkkk...", "..kaaaaaaaaaak..",
  "..kaAAAAAAAAak..", "..kaAkkkkkkAak..", "..kaAkgyyykAak..", "..kaAkgFFykAak..",
  "..kaAkgyyykAak..", "..kaAkkkkkkAak..", "..kaAAAAAAAAak..", "..kaaaaaaaaaak..",
  "..kccccccccccck.", "..kCCCCCCCCCCCk.", "...kkkkkkkkkkk..", "................"
)
S.i_furnace = A(
  "................", "......kkkk......", "......khhk......", ".....kkhhkk.....",
  "...kkhhhhhhkk...", "..khhHhhhhhhhk..", "..khkkkkkkkkhk..", "..khkFffffFkhk..",
  "..khkfFFFFfkhk..", "..khkfrFFrfkhk..", "..khkkkkkkkkhk..", "..khhhhhhhhhhk..",
  "..khgkhhhhkghk..", "..kkkkkkkkkkkk..", "................", "................"
)
S.i_bag = A(
  "................", "................", "......kkkk......", ".....kbBBbk.....",
  "......kggk......", ".....kbBBbk.....", "....kbBBBBbk....", "...kbBBggBBbk...",
  "..kbBBgyygBBbk..", "..kbBBgyygBBbk..", "..kbBBBggBBBbk..", "..kbBBBBBBBBbk..",
  "...kbBBBBBBbk...", "....kkkkkkkk....", "................", "................"
)
S.i_badge = A(
  "................", "....kkk..kkk....", "....krk..krk....", "....krrkkrrk....",
  ".....krrrrk.....", "....kkkkkkkk....", "...kggggggggk...", "..kgyyyyyyyygk..",
  "..kgyyyFFyyygk..", "..kgyyFFFFyygk..", "..kgyyyFFyyygk..", "..kgyyFyyFyygk..",
  "...kgyyyyyygk...", "....kggggggk....", ".....kkkkkk.....", "................"
)
S.i_compass = A(
  "................", ".......kk.......", "......kggk......", ".....kkkkkk.....",
  "....kgggggggk...", "...kgkccccckgk..", "..kgkcccecccckgk", "..kgccccekcccgk.",
  "..kgcccekkcccgk.", "..kgccckOkcccgk.", "..kgcccokcccgk..", "..kgkccocccckgk.",
  "...kgkccccckgk..", "....kgggggggk...", ".....kkkkkkk....", "................"
)
S.i_flask = A(
  "................", "......kkkk......", "......kcck......", "......kcck......",
  "......kcck......", ".....kccock.....", "....kcccooOk....", "...kccccoooOk...",
  "...kPPPPPPPPk...", "..kPPpPPPPpPPk..", "..kPPPPoPPPPPk..", "..kPpPPPPPPpPk..",
  "..kPPPPPPoPPPk..", "...kPPPPPPPPk...", "....kkkkkkkk....", "................"
)
S.i_flag = A(
  "................", "...kk...........", "...kgkkkkkkkk...", "...kgkrrrrrrrk..",
  "...kgkrRRRRRrrk.", "...kgkrRyyRRrk..", "...kgkrRyyRRrrk.", "...kgkrRRRRRrk..",
  "...kgkrrrrrrrrk.", "...kgkkkkkkkkk..", "...kgk..........", "...kgk..........",
  "...kgk..........", "..kgggk.........", "..kkkkk.........", "................"
)
S.i_spike = A(
  "................", ".............kk.", "............kOk.", "...........kOhk.",
  "..........kOhk..", ".........kOhk...", "........kOhk....", ".......kHhk.....",
  "......kHhk......", "..kk.kHhk.......", "..kbkkhk........", "...kbbk.........",
  "...kBbbk........", "..kBbkkbk.......", "..kkk..kk.......", "................"
)
S.i_amulet = A(
  "................", "....kk....kk....", "...khk....khk...", "...khk....khk...",
  "....khk..khk....", ".....khkkhk.....", "......kkkk......", ".....khhhhk.....",
  "....khHHHHhk....", "...khHkkkkHhk...", "...khHkaAkHhk...", "...khHkAakHhk...",
  "...khHkkkkHhk...", "....khHHHHhk....", ".....kkkkkk.....", "................"
)
S.i_horn = A(
  "................", "................", "............kk..", "...........kgk..",
  "..........kggk..", ".........kgygk..", "..kk....kgyygk..", ".kcck..kgyyggk..",
  ".kccckkgyyggk...", ".kcCcggyyggk....", "..kCcgyyggk.....", "..kkkgyggkk.....",
  "....kkggkk......", "......kk........", "................", "................"
)
S.i_ring = A(
  "................", "................", ".......kk.......", "......keek......",
  ".....keOeek.....", "......keek......", "....kkkkkkkk....", "...kggyyyyggk...",
  "..kgykkkkkkygk..", "..kgyk....kygk..", "..kgyk....kygk..", "..kgyk....kygk..",
  "..kggykkkkyggk..", "...kggyyyyggk...", "....kkkkkkkk....", "................"
)
S.i_boots = A(
  "................", "................", "....kkkkk.......", "....kbBBk.......",
  "...kHHHHHk......", "....kbBBk.......", "....kbBBk.......", "....kbBBk.......",
  "....kbBBbk......", "...kbBBBBbkk....", "...kbBBBBBBbk.oo", "...kbBBBBBBBbk..",
  "..ookkkkkkkkkk.o", "................", "....o.o.........", "................"
)
S.i_lens = A(
  "................", "................", "....kkkkk.......", "...kgggggk......",
  "..kgkooOkgk.....", "..kgoooOOgk.....", "..kgooooogk.....", "..kgkooookgk....",
  "...kgggggkk.....", "....kkkkkbbk....", "........kbBbk...", ".........kbBbk..",
  "..........kbBbk.", "...........kbbk.", "............kk..", "................"
)
S.i_armor = A(
  "................", "................", "..kkk.kkkk.kkk..", ".khhhkHHHHkhhhk.",
  ".khHhkkkkkkhHhk.", ".kkhhhhzhhhhhkk.", "..kkhhzZzhhhkk..", "...khzZZZzhhk...",
  "...khhzZzhhhk...", "...khzhzhzhhk...", "...khhhzhhhhk...", "...khhhhhhhhk...",
  "....khhhhhhk....", ".....kkkkkk.....", "................", "................"
)
S.i_cross = A(
  "................", "......kkkk......", "......kyyk......", "......kyFk......",
  "......kyFk......", "..kkkkkyFkkkkk..", "..kyyyyyFyyyyk..", "..kFFFFFOFFFFk..",
  "..kkkkkyFkkkkk..", "......kyFk......", "......kyFk......", "......kyFk......",
  "......kyFk......", "......kkkk......", "................", "................"
)
S.i_blade = A(
  "................", ".............kk.", "............kPk.", "...........kPok.",
  "..........kPok..", ".........kPok...", "........kPok....", ".......kPok.....",
  "..kk..kPok......", "..kgkkPok.......", "...kggok........", "...kbggk........",
  "..kbbkkgk.......", ".kbbk..kk.......", ".kkk............", "................"
)
S.i_glove = A(
  "................", "................", "...kk.kk.kk.....", "..khhkhhkhhk....",
  "..khhkhhkhhkkk..", "..khhkhhkhhkhhk.", "..khhhhhhhhkhhk.", "..khHhhhhhhhhhk.",
  "..khHhhhhhhhhk..", "..khHHhhhhhhhk..", "...khhhhhhhhk...", "...kkkkkkkkkk...",
  "...kggggggggk...", "...kkkkkkkkkk...", "................", "................"
)
S.i_dice = A(
  "................", "................", "....kkkkkkkk....", "...kOOOOOOOOk...",
  "..kOOOOOOOOcck..", "..kkkkkkkkkcck..", "..kOOOOOOOkcck..", "..kOkOOOkOkcck..",
  "..kOOOOOOOkcck..", "..kOOOkOOOkcck..", "..kOOOOOOOkcck..", "..kOkOOOkOkck...",
  "..kOOOOOOOkk....", "..kkkkkkkkk.....", "................", "................"
)
S.i_scroll = A(
  "................", "................", "..kkkkkkkkkkk...", ".kccccccccccck..",
  ".kcCkkkkkkkCck..", "..kcttttttttk...", "..kctaaAattck...", "..kcttttttttk...",
  "..kctaAaAatck...", "..kcttttttttk...", "..kctaaAattck...", "..kcttttttttk...",
  ".kcCkkkkkkkCck..", ".kccccccccccck..", "..kkkkkkkkkkk...", "................"
)
S.i_potion = A(
  "................", "......kkkk......", "......kbBk......", "......kkkk......",
  ".......kck......", ".......kck......", ".....kkccckk....", "....krrrrrOrk...",
  "...krrRRRrOrrk..", "...krRRRRRrrrk..", "...krRRRRRRrrk..", "...krrRRRRRrrk..",
  "...krrrrrrrrrk..", "....krrrrrrrk...", ".....kkkkkkk....", "................"
)
S.i_whistle = A(
  "................", "................", "................", "..........kk....",
  ".........kgyk...", "..kkkkkkkkgyk...", ".khhhhhhhhkk....", ".khHHHHHHhhkkk..",
  ".khhhhhhhhkhhhk.", ".kkkkkkkkhhkhhk.", "........khhhhhk.", "........khHHhk..",
  ".........kkkk...", "................", "................", "................"
)
S.i_feather = A(
  "................", "...........kk...", "..........kFFk..", ".........kFfFk..",
  "........kFffFk..", ".......kFfrfFk..", "......kFfrffk...", ".....kFfrffFk...",
  "....kFfrffFk....", "....kFrffFk.....", "...kFrffFk......", "...kfrFkk.......",
  "..kkrkk.........", ".kgk............", "kgk.............", "kk.............."
)
S.treant = A(
  "....kkk.kkk.....", "...kZZZkZZZk....", "..kZzZZZZzZZk...", ".kZzzZzZZzzZzk..",
  ".kzZzzzzZzzzzk..", "..kkzzkzzkzzk...", "...kbbbbbbbbk...", "...kbkybbkybk...",
  "...kbbbbbbbbk...", "..kkbBbkkbBbkk..", ".kzkbBbbbbBbkzk.", ".kzkbBbBBbBbkzk.",
  "..kkbBbbbbBbkk..", "...kbbbkkbbbk...", "..kbBbk..kbBbk..", "..kkkkk..kkkkk.."
)
S.hawk = A(
  "................", ".....kkkk.......", "....kaaaak......", "...kaAAkaak.....",
  "...kaOkAaagk....", "....kaaaakggk...", "kk...kAAak.kk...", "kakk.kAAak....kk",
  "kaAakkAAAakkkaak", ".kaAAaAAAaaAAak.", "..kaAaAAAaaAak..", "...kkaAAAAakk...",
  ".....kaaaak.....", ".....kkgkgk.....", "....kgk.kgk.....", "....kk...kk....."
)
S.clockwork = A(
  "...........kk...", "....kkkkk.kggk..", "...khhhhhkkgk...", "..khHHHHHhkkk...",
  "..khkkkkkhk.....", "..khkaAakhk.....", "..khkkkkkhk.....", "...khhhhhk......",
  ".kkkkhhhkkkkk...", "khgkhHHHhkghk...", "khhkhgygdkhhk...", "khhkhgggdkhhk...",
  ".kkkhhhhhkkk....", "...khhkhhk......", "...khk.khk......", "..kkkk.kkkk....."
)
S.sym_treant = A(
  "................", "....kkk.kkk.....", "...kZZZkZZZk....", "..kZzZZZZZzZk...",
  ".kZzzZZzZZzzZk..", ".kzzzzzzzzzzzk..", "..kkzzzzzzzkk...", "....kkbbbkk.....",
  ".....kbBbk......", ".....kbBbk......", "....kbbBbbk.....", "...kbbkBkbbk....",
  "..kbbk.k.kbbk...", "..kkk.....kkk...", "................", "................"
)
S.sym_hawk = A(
  "................", "................", ".kk..........kk.", ".kak...kk...kak.",
  ".kaAk.kaak.kAak.", "..kaAkaOgakAak..", "..kaAAkaaakAak..", "...kaAAAAAAak...",
  "....kaAAAAak....", ".....kaAAak.....", ".....kAaaAk.....", "....kAk..kAk....",
  "....kk....kk....", "................", "................", "................"
)
S.sym_clock = A(
  "................", "......kkkk......", "...kk.kggk.kk...", "..kggkkggkkggk..",
  "..kgyyyyyyyygk..", "...kyykkkkyyk...", ".kkgykOOOOkygkk.", ".kggykOkOOkyggk.",
  ".kggykOkkkkyggk.", ".kkgykOOOOkygkk.", "...kyykkkkyyk...", "..kgyyyyyyyygk..",
  "..kggkkggkkggk..", "...kk.kggk.kk...", "......kkkk......", "................"
)
S.sup_treant = A(
  "...kkk......kkk.....", "..kRRRk.kk.kRRRk....", ".kRhRRRkhhkRRRhRk...", ".kRhhRRRhhRRRhhRk...",
  "..kkRhhRRRRhhRkk....", "...kkdddddddddkk....", "...kddkRkddkRkdk....", "...kdddddddddddk....",
  "...kkdhhkkkhhdkk....", "..kRkdhhddddhhdkRk..", ".kRRkdhhhhhhhhdkRRk.", ".kRkkdhRRddRRhdkkRk.",
  "..k.kdhRROORRhdk.k..", "....kdhhRRRRhhdk....", "....kddhhhhhhddk....", "...kdddk....kdddk...",
  "..kdhdk......kdhdk..", "..kddk........kddk..", "..kRk..........kRk..", "..kk............kk.."
)
S.sup_hawk = A(
  "....................", ".......kkkkk........", "......kdddddk.......", ".....kdhhkdddk......",
  ".....kdOkRhddEk.....", "......kdddddkEEk....", "kkk....khhhdk.kk....", "kRRkk..khRRhk.....kk",
  "kRhhRkkhRRRRhkkkkRRk", ".kRhhhRhRRRRhhhhhRk.", "..kRhhhhRRRRhhhhRk..", "...kkRhhRRRRhhRkk...",
  ".....kkhRRRRhkk.....", ".......khhhhk.......", ".......kdddk........", "......kkEkEkk.......",
  ".....kEk...kEk......", ".....kk.....kk......", "....................", "...................."
)
S.sup_clock = A(
  "..............kk....", ".....kkkkkkk.kRRk...", "....khhhhhhhkkRk....", "...khHHHHHHHhkkk....",
  "...khkkkkkkkhk......", "...khkROORkkhk......", "...khkkkkkkkhk......", "....khhhhhhhk.......",
  ".kkkkkhhhhhkkkkk....", "khRkkhHHHHHhkkRhk...", "khhkkhRRRRRhkkhhk...", "khhkkhRROORhdkhhk...",
  "khRkkhRRRRRhdkRhk...", ".kkkkhhhhhhhkkkk....", "....khhhkhhhk.......", "....khhk.khhk.......",
  "....khhk.khhk.......", "...kkhhk.khhkk......", "...kRRRk.kRRRk......", "...kkkkk.kkkkk......"
)
S.corpsetoad = A(
  "................", "................", "................", "....kk....kk....",
  "...kZZk..kZZk...", "...kZek..keZk...", "..kkZZkkkkZZkk..", ".kZzzzzzzzzzzZk.",
  "kZzzPzzzzzPzzzZk", "kzzzzzzzzzzzzzzk", "kzzkkkkkkkkkkzzk", ".kzZccccccccZzk.",
  "..kzzzzzzzzzzk..", ".kzzkkzzzzkkzzk.", ".kkkk.kkkk.kkkk.", "................"
)
S.sporesac = A(
  "................", "......kkkk......", "....kkPPPPkk....", "...kPPpPPpPPk...",
  "..kPpPPPPPPpPk..", "..kPPPkPPkPPPk..", "..kPpPPPPPPPpk..", "...kPPpPPpPPk...",
  "....kkPPPPkk....", ".....kkzzkk.....", "......kzzk......", ".....kzZzzk.....",
  "....kzzZzZzk....", "...kxxzzzzxxk...", "...kkkkkkkkkk...", "................"
)
S.creeper = A(
  "................", ".....kkkkk......", "....kzzzzzk.....", "...kzZzzZzzk....",
  "...kzkekekzk....", "...kzzzzzzzk....", "....kkzzzkk.k...", "..kk.kzZzk.kzk..",
  ".kzZkkzZzkkzZk..", ".kzzZzzZzzZzk...", "..kkkzzZzzkk....", "....kzzzzzk.....",
  "...kzxkzkxzk....", "..kzxk.k.kxzk...", "..kxk.....kxk...", "..kk.......kk..."
)
S.murloc = A(
  "................", "................", ".......k.k......", "......kakak.....",
  ".....kaAAAak....", "....kaAAOkAak...", "....kAAAkkAAk...", "....kAAcccAAk...",
  ".....kkcwckk....", "...kk.kaaak.kk..", "..kaAkkaAAkkAak.", "...kkkaAAAak.kk.",
  "......kaAak.....", ".....kakkak.....", ".....kk..kk.....", "................"
)
S.jelly = A(
  "................", ".....kkkkkk.....", "....kooooOOk....", "...koOooooOOk...",
  "...koooooooOk...", "...kokkookkok...", "...koooooooOk...", "...kkokokokkk...",
  "....kokokok.....", "....kokokok.....", "...kok.ok.ok....", "...kok.ko.kok...",
  "....k..ok..k....", ".......kk.......", "................", "................"
)
S.octo = A(
  "................", "......kkkk......", "....kkPPPPkk....", "...kPPPPPPPPk...",
  "...kPOkPPOkPk...", "...kPkkPPkkPk...", "...kPPPPPPPPk...", "....kPPkkPPk..kk",
  "..kkkPPPPPPkkkdk", ".kPkPkPPPPkPkkdk", ".kPkPkPkkPkPkkk.", "..kkPkPkkPkPk...",
  "...kPk.kk.kPk...", "...kk.kPk..kk...", "......kk........", "................"
)
S.tentacle = A(
  "................", "......kk........", ".....kPPk.......", "....kPPpk.......",
  "....kPpk........", "...kPPk.........", "...kPpk.........", "...kPPk.........",
  "....kPPk........", "....kpPPk.......", ".....kPPk.......", ".....kPpPk......",
  "....kPPpPk......", "...kkPPPPkk.....", "..kddddddddk....", "..kkkkkkkkkk...."
)
S.rotmother = A(
  "........................", "........kkkkkkkk........", "......kkZZzzzzZZkk......", ".....kZzzPzzzzPzzZk.....",
  "....kZzzzzzzzzzzzzZk....", "....kzzkkkzzzzkkkzzk....", "...kzzkeeekzzkeeekzzk...", "...kzzzkkkzzzzkkkzzzk...",
  "...kzzzzzzzzzzzzzzzzk...", "..kkzzkkkkkkkkkkkkzzkk..", ".kZkzkcmcmcmcmcmcmkzkZk.", ".kzkzkmcmcmcmcmcmckzkzk.",
  ".kzkzzkkkkkkkkkkkkzzkzk.", "kzzkzzzzzPzzzzPzzzzzkzzk", "kzzkzzPzzzzzzzzzzPzzkzzk", "kzzkzzzzzzPPPPzzzzzzkzzk",
  ".kkkzzzzzPPppPPzzzzzkkk.", "...kzzzzzPPppPPzzzzzk...", "...kzzzzzzPPPPzzzzzzk...", "....kzzzzzzzzzzzzzzk....",
  "....kxzzkkkzzkkkzzxk....", "...kxxzk..kzzk..kzxxk...", "...kkkkk..kkkk..kkkkk...", "........................"
)
S.leviathan = A(
  "........................", "........................", ".........kkkk...........", "........kuuuuk..........",
  ".......kuAAAAukk........", "......kuAAAAAAuuk.......", ".....kuAAAAAAAAAuk......", "....kuAAAAAAAkkAAuk.....",
  "....kuAAAAAAkeOkAuk.....", "...kuAAAAAAAAkkkAAuk....", "...kuAAAAAAAAAAAAAuk....", "...kuAAAAAAAAcccccuuk...",
  "...kuuAAAAAAckwkwkcuk...", "....kuAAAAAAAcccccuuk...", "....kuuAAAAAAAAAAuuk....", "..kk.kuuuAAAAAAuukk.....",
  ".kuuk.kkuuuuuuukk.......", "..kuuk..kuuAuuk.....kk..", "...kuuk.kuAAAuuk...kuuk.", "....kuukkuuAAAuukkkuuk..",
  "....kkuuuuuAAAAuuuukk...", "......kkkuuuuuuukkk.....", ".........kkkkkkk........", "........................"
)
return S
