-- ============================================================================
-- 第八次更新：道具图标按品质加光圈
--  * 同一张图标（比如同一种词条装备）不同品质一眼能分出来
--  * 普通：不加光（只在四周留 1 像素，保证所有道具图标大小一致）
--  * 稀有：图标外沿一圈淡蓝色轮廓光
--  * 史诗：背后一圈紫色光环 + 轮廓光
--  * 传说：背后一圈橙金色光环 + 更亮的轮廓光 + 四角闪光
--  * 超凡（预留）：同传说，换成红色
-- 图标从 16×16 变成 18×18；界面里的道具图标都用 CSS 写死了显示尺寸，所以版面不变
-- 战场上单位头顶的小装备标记仍用原图（那里已经有品质色的小框）
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local PX = require("game.pixel")
local floor, sqrt = math.floor, math.sqrt

-- ---------------------------------------------------------------------------
-- 撞脸图标换新图（tools/icons/art.py 末尾）
--  破甲锥以前像一把剑 → 锥子；远视镜和鹰眼单片镜都是放大镜 → 望远镜；钱袋和金币袋都是布袋 → 口金包；
--  赌徒之戒 / 王者徽戒 都是金戒指配红宝石 → 骰子戒；血契和龙心都是红心 → 滴血契约；
--  龙晶之心和噬魂宝石都是红宝石 → 竖瞳龙晶；时之齿轮和永动核心都是齿轮 → 沙漏；
--  先手号角像一根羽毛 → 弯角号；利息存折像画框（和藏宝图撞）→ 绿色存折；风行靴改成青绿色（和疾风靴区分）
-- ---------------------------------------------------------------------------
local REICON = {
    awl = 'n_awl', lens = 'n_spyglass', purse = 'n_wallet', gambler = 'n_dicering', bloodpact = 'n_pact',
    dragoncrystal = 'n_dragoneye', chronogear = 'n_chrono', horn = 'n_warhorn', bank = 'n_passbook',
}
for id, ic in pairs(REICON) do
    if ITEMS[id] and SPR[ic] then ITEMS[id].icon = ic; ITEMS[id].pal = ICON_PAL end
end

local HALO = {
    [0] = nil,
    [1] = { glow = 0.55 },
    [2] = { glow = 0.8, ring = 0.42 },
    [3] = { glow = 1, ring = 0.55, spark = true },
    [4] = { glow = 1, ring = 0.6, spark = true },
}

local function rgbaStr(hex, a)
    local r, g, b = js.parseColor(hex)
    return string.format('rgba(%d,%d,%d,%.2f)', floor(r + 0.5), floor(g + 0.5), floor(b + 0.5), a)
end

local baseOf = {} -- 光圈图的键 → 原图的键

--- baseKey：ICONS 里的原图键；rar：品质 0~4。返回带光圈图的键
function haloIconURL(baseKey, rar)
    rar = rar or 0
    local k = 'halo' .. rar .. '|' .. baseKey
    if ICONS[k] then return k end
    local src = ICONS[baseKey]
    if not src then return baseKey end
    local w, h = src.width, src.height
    local W, H = w + 2, h + 2
    local c = PX.newImage(W, H)
    local sd = src.data
    local function solid(x, y) -- 新图坐标
        local sx, sy = x - 1, y - 1
        return sx >= 0 and sy >= 0 and sx < w and sy < h and sd[sy * w + sx] ~= nil
    end
    local H_ = HALO[rar]
    local Q = QUAL[rar]
    if H_ and Q then
        local col = Q.color
        -- 光环：以中心为圆心、半径约 8 的一圈（被图标挡住的部分自然看不见）
        if H_.ring then
            local ringC = rgbaStr(col, H_.ring)
            local ringSoft = rgbaStr(col, H_.ring * 0.45)
            local cx, cy = (W - 1) / 2, (H - 1) / 2
            local R = math.min(W, H) / 2 - 0.6
            for y = 0, H - 1 do for x = 0, W - 1 do
                local d = sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
                if d >= R - 0.75 and d <= R + 0.45 then c:set(x, y, ringC)
                elseif d >= R - 1.6 and d < R - 0.75 then c:set(x, y, ringSoft) end
            end end
        end
        -- 轮廓光：紧贴图标外沿一圈（上下左右相邻）
        local glowC = rgbaStr(col, H_.glow)
        for y = 0, H - 1 do for x = 0, W - 1 do
            if not solid(x, y) and (solid(x + 1, y) or solid(x - 1, y) or solid(x, y + 1) or solid(x, y - 1)) then
                c:set(x, y, glowC)
            end
        end end
        -- 四角闪光（传说及以上）
        if H_.spark then
            local s1, s2 = '#ffffff', rgbaStr(col, 0.9)
            local pts = { { 1, 1 }, { W - 2, 1 }, { 1, H - 2 }, { W - 2, H - 2 } }
            for _, p in ipairs(pts) do
                local x, y = p[1], p[2]
                if not solid(x, y) then
                    c:set(x, y, s1)
                    for _, dxy in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                        local X, Y = x + dxy[1], y + dxy[2]
                        if X >= 0 and Y >= 0 and X < W and Y < H and not solid(X, Y) then c:set(X, Y, s2) end
                    end
                end
            end
        end
    end
    -- 图标本体画在最上面
    for y = 0, h - 1 do for x = 0, w - 1 do
        local v = sd[y * w + x]
        if v then c:set(x + 1, y + 1, v) end
    end end
    ICONS[k] = c
    baseOf[k] = baseKey
    return k
end

--- 道具图标：带品质光圈
local _itemIcon = itemIcon
function itemIconBase(it) return _itemIcon(it) end
function itemIcon(it)
    local base = _itemIcon(it)
    local I = ITEMS[it.id]
    local rar = it.rar or (I and I.rar) or 0
    return haloIconURL(base, rar)
end

-- 战场上的小装备标记：用原图缩小（光圈缩到 8×8 会糊成一团，那里本来就有品质色小框）
local _miniIcon = miniIcon
if _miniIcon then
    function miniIcon(key) return _miniIcon(baseOf[key] or key) end
end

return true
