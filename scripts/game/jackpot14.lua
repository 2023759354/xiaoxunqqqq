-- ============================================================================
-- 第十四次更新：提高九格大奖几率的圣物（拉杆类）
--  九格大奖 = 九个格子是同一种图标（★ 可以替代任何图标）。默认每次拉杆约 0.11%（幸运满时约 0.8%）。
--   * 宿命骰盅（稀有）：指定一个出征兵种，它的图标权重 +60%
--   * 磁石轮轴（稀有）：转出 8 格同种（★ 算任意）时，剩下那一格有 35% 几率被吸成同一种
--   * 四角明镜（史诗）：四个角里 3 个同种时，第 4 个角也变成同种
--   * 九宫彩券（传说）：没中九格大奖的拉杆各积 1 点，攒满 40 点下一次必中（全 ★）
--  实测几率见更新说明「第十四次更新」。效果都在 afterRollGrid / rollSymbol 里处理，
--  所以手动拉杆（slot.lua）和自动对局（instantSpin）完全一致；教程预设的结果不受影响。
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local floor, max, min = math.floor, math.max, math.min

-- ---------------------------------------------------------------------------
-- 图标（16×16，调色板 ICON_PAL：k 描边，1~3 银灰，4~6 金，7~9 红，a~d 蓝，h~j 紫，l~n 棕）
-- ---------------------------------------------------------------------------
SPR.n_magnet = A(
    "................",
    "....kkkkkkkk....",
    "...k77777777k...",
    "..k7888888887k..",
    ".k788kkkkkk887k.",
    ".k78k......k87k.",
    ".k78k......k87k.",
    ".k78k......k87k.",
    ".k78k......k87k.",
    ".k99k......k99k.",
    ".k12k......k12k.",
    ".k12k.a..a.k12k.",
    ".k23k..aa..k23k.",
    ".kkkk.a..a.kkkk.",
    "................",
    "................"
)
SPR.n_dicecup = A(
    "..kkkkkkkkkk....",
    ".kmmmmmmmmmmk...",
    ".knnnnnnnnnnk...",
    "..kmmmmmmmmk....",
    "..kmllmmllmk....",
    "..kmmmmmmmmk....",
    "...kmmmmmmk.....",
    "...knnnnnnk.....",
    "....kkkkkk......",
    "........kkkkkkk.",
    "........k11111k.",
    "........k1k111k.",
    "........k11k11k.",
    "........k111k1k.",
    "........k11111k.",
    "........kkkkkkk."
)
SPR.n_mirror4 = A(
    "kkkk........kkkk",
    "k44k........k44k",
    "k45kkkkkkkkkk54k",
    "kkk5aaaaaaaa5kkk",
    "..k5abbaaaaa5k..",
    "..k5abaaaaaa5k..",
    "..k5aaaaaaaa5k..",
    "..k5aaaaaaaa5k..",
    "..k5aaaaaaba5k..",
    "..k5aaaaabba5k..",
    "..k5aaaaaaaa5k..",
    "..k5aaaaaaaa5k..",
    "kkk5aaaaaaaa5kkk",
    "k45kkkkkkkkkk54k",
    "k44k........k44k",
    "kkkk........kkkk"
)
SPR.n_lottery = A(
    "................",
    ".kkkkkkkkkkkkkk.",
    ".k444444444444k.",
    ".k4kkkkkkkkkk4k.",
    ".k4k5k5k5k5kk4k.",
    "k44kk4kk4kk4k44k",
    "k4kk555555555k4k",
    "..k4k5k5k5k5k4..",
    "..k4kk4kk4kk4k..",
    "k4kk555555555k4k",
    "k44kk5k5k5k5k44k",
    ".k4kk4kk4kk4k4k.",
    ".k4kkkkkkkkkk4k.",
    ".k444444444444k.",
    ".kkkkkkkkkkkkkk.",
    "................"
)

-- ---------------------------------------------------------------------------
-- 道具
-- ---------------------------------------------------------------------------
JP_PITY = 40         -- 九宫彩券：攒满多少点必中
JP_MAGNET_AT = 8     -- 磁石轮轴：至少几格已经同种才会吸
JP_MAGNET_P = 0.35   -- 磁石轮轴：每个没对上的格子被吸过来的几率
JP_FATE_W = 0.6      -- 宿命骰盅：指定兵种的图标权重 +60%
local NEW = {
    fatecup = { kind = 'relic', rar = 1, name = '宿命骰盅', icon = 'n_dicecup', grp = '拉杆', desc = '指定一个出征兵种：它的图标出现权重 +60%，更容易转出满盘', fx = { fateCup = true } },
    magnetaxle = { kind = 'relic', rar = 1, name = '磁石轮轴', icon = 'n_magnet', grp = '拉杆', desc = '转出 8 格同种图标（★ 算任意）时，剩下那一格有 35% 几率被吸成同一种，直接凑成九格大奖', fx = { magnet = JP_MAGNET_P } },
    cornermirror = { kind = 'relic', rar = 2, name = '四角明镜', icon = 'n_mirror4', grp = '拉杆', desc = '转轴四个角里有 3 个是同一种图标（★ 算任意）时，第 4 个角也变成这一种', fx = { cornerMirror = true } },
    ninelottery = { kind = 'relic', rar = 3, name = '九宫彩券', icon = 'n_lottery', grp = '拉杆', desc = '每次没中九格大奖的拉杆积 1 点，攒满 ' .. JP_PITY .. ' 点后下一次拉杆必中九格大奖（全 ★）', fx = { pity = JP_PITY } },
}
for k, v in pairs(NEW) do v.pal = ICON_PAL; ITEMS[k] = v end
do
    local at = ITEM_KEYS:indexOf('alchemy') + 1
    for i, k in ipairs({ 'fatecup', 'magnetaxle', 'cornermirror', 'ninelottery' }) do ITEM_KEYS:splice(at + i - 1, 0, k) end
end

-- 宿命骰盅像兵种徽记一样，获得时随机指定一个出征兵种
local _newItem = newItem
function newItem(id, rar)
    local it = _newItem(id, rar)
    if id == 'fatecup' and G and G.squad then it.cls = pick(G.squad) end
    return it
end
local _itemName = itemName
function itemName(it)
    if it.id == 'fatecup' and it.cls then return '宿命骰盅·' .. CLASSES[it.cls].name end
    return _itemName(it)
end
local _itemDesc = itemDesc
function itemDesc(it)
    if it.id == 'fatecup' and it.cls then
        return '<b>' .. CLASSES[it.cls].name .. '</b>的图标出现权重 +60%，更容易转出满盘（九格大奖），' .. CLASSES[it.cls].name .. '的连线也会变多'
    end
    local d = _itemDesc(it)
    if it.id == 'ninelottery' and G and G.relics and G.relics:some(function(r) return r == it end) then
        d = d .. '<br><span style="color:#ffe680">当前进度 ' .. S(min(JP_PITY, G.jpPity or 0)) .. '/' .. S(JP_PITY) .. '</span>'
    end
    return d
end

-- ---------------------------------------------------------------------------
-- 效果
-- ---------------------------------------------------------------------------
local function fateBoost()
    if not (G and G.relics) then return nil end
    local add = nil
    for it in js.of(G.relics) do
        if it.id == 'fatecup' and it.cls then
            local sym = CLASS_SYM[it.cls]
            if sym and G.symW[sym] then add = add or {}; add[sym] = (add[sym] or 0) + JP_FATE_W end
        end
    end
    return add
end
local _rollSymbol = rollSymbol
function rollSymbol()
    local add = fateBoost()
    if not add then return _rollSymbol() end
    local keep = {}
    for sym, f in pairs(add) do keep[sym] = G.symW[sym]; G.symW[sym] = G.symW[sym] * (1 + f) end
    local s = _rollSymbol()
    for sym, v in pairs(keep) do G.symW[sym] = v end
    return s
end

--- 盘面上最多的非 ★ 图标（★ 算任意）：返回图标和对上的格数
local function bestSym(g)
    local cnt, star = {}, 0
    for i = 0, 8 do
        local s = g[i]
        if s == 'S' then star = star + 1 else cnt[s] = (cnt[s] or 0) + 1 end
    end
    local best, bn = nil, -1
    for s, n in pairs(cnt) do if n > bn or (n == bn and s < best) then best, bn = s, n end end
    if not best then return 'S', 9 end
    return best, bn + star
end
JP_bestSym = bestSym

local _afterRollGrid = afterRollGrid
function afterRollGrid(grid)
    local g = _afterRollGrid(grid)
    local r = RX()
    G.jpNote = nil
    -- 九宫彩券：攒满了直接出全 ★
    if T(r.pity) and (G.jpPity or 0) >= r.pity then
        for i = 0, 8 do g[i] = 'S' end
        G.jpPity = 0
        G.jpNote = '九宫彩券兑奖：九格大奖！'
        return g
    end
    -- 四角明镜：四个角里有 3 个对得上（★ 算任意），剩下那个角也变成同一种
    if r.cornerMirror then
        local cs = { g[0], g[2], g[6], g[8] }
        local cnt, star = {}, 0
        for _, s in ipairs(cs) do if s == 'S' then star = star + 1 else cnt[s] = (cnt[s] or 0) + 1 end end
        local best, bn = nil, 0
        for s, n in pairs(cnt) do if n > bn or (n == bn and s < best) then best, bn = s, n end end
        if best and bn + star == 3 then
            for _, i in ipairs({ 0, 2, 6, 8 }) do if g[i] ~= best and g[i] ~= 'S' then g[i] = best end end
        end
    end
    -- 磁石轮轴：差一点的盘面把剩下的格子吸过来
    if T(r.magnet) and not jackpotSym(g) then
        local sym, n = bestSym(g)
        if n >= JP_MAGNET_AT and n < 9 then
            local pulled = 0
            for i = 0, 8 do
                if g[i] ~= sym and g[i] ~= 'S' and js.random() < r.magnet then g[i] = sym; pulled = pulled + 1 end
            end
            if pulled > 0 then G.jpNote = '磁石轮轴吸住了 ' .. S(pulled) .. ' 格' .. (jackpotSym(g) and '：九格大奖！' or '') end
        end
    end
    if T(r.pity) then
        if jackpotSym(g) then G.jpPity = 0 else G.jpPity = (G.jpPity or 0) + 1 end
    end
    return g
end

-- 转轴停下时提示圣物生效（大奖本身的横幅照常）
local _updateSlot = updateSlot
function updateSlot(dt)
    local was = G.slot.spinning
    _updateSlot(dt)
    if was and not G.slot.spinning and G.jpNote then
        local note = G.jpNote
        G.jpNote = nil
        setTimeout(function() UI.toast(note) end, 900)
    end
end

-- 换局清零
local _newGame = newGame
function newGame(...)
    local r = table.pack(_newGame(...))
    if G then G.jpPity = 0; G.jpNote = nil end
    return table.unpack(r, 1, r.n)
end

return true
