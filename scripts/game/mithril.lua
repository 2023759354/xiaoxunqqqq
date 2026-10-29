-- ============================================================================
-- 第九次更新：秘银 + 独立商店
--  * 新货币「秘银」（一块泛蓝光的银锭）：只在商店买 / 卖 / 刷新道具时使用
--  * 每波战后自动发秘银：赢了 3 + 波数/3（向下取整），精英波 +3，无阵亡 +1；输了也有 2
--  * 金币可以兑换秘银（GEM_RATE：3 金币 → 2 秘银），反过来不行
--  * 商店不再每波战后自动弹出：顶栏「商店」随时打开，每波战后自动换货，有新货时按钮亮起
--  * 精英战利品保留（战后弹出），并可以免费刷新 1 次
-- 界面部分（顶栏钱包、页签、统计面板、兑换条）全部在游戏侧注入 DOM / 样式，
-- 不改动 scripts/ui 下的界面运行时。
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S = js.A, js.T, js.S
local floor, max, min = math.floor, math.max, math.min
local function _id(id) return PAGE.doc.getElementById(id) end

GEM_NAME = '秘银'
GEM_RATE = { gold = 3, gem = 2 } -- 3 金币 → 2 秘银

-- 16×16 像素图标：一块秘银锭（亮面 + 侧面 + 一点闪光），配色用道具图标的公共调色板
SPR.cur_mithril = A(
    "................",
    "................",
    "............w...",
    "...........waw..",
    "....kkkkkkkkwk..",
    "...k1w11a11a1k..",
    "..k1aaaaaaaaa1k.",
    ".kkkkkkkkkkkkkk.",
    ".kbwbbbbbbbbbck.",
    "kbabbbbbbbbbbbck",
    "kbbbbbbbbbbbbbck",
    "kcbbbbbbbbbbbcck",
    "kcccccccccccccdk",
    ".kkkkkkkkkkkkkk.",
    "................",
    "................"
)
function gemIcon() return iconURL('cur_mithril', ICON_PAL, 'cur') end

-- ---------------------------------------------------------------------------
-- 收入 / 兑换
-- ---------------------------------------------------------------------------
function gemIncomeWin(wave) return 3 + floor((wave or 1) / 3) end
function gemIncome(res)
    if not res.win then return 2 end
    local n = gemIncomeWin(res.wave)
    if res.elite then n = n + 3 end
    if res.flawless then n = n + 1 end
    return n
end
--- 用金币换秘银：packs 份（每份 GEM_RATE.gold 金币 → GEM_RATE.gem 秘银）；nil = 能换多少换多少
function exchangeGold(packs)
    if G.phase ~= 'prep' then return 0 end
    local most = floor(G.gold / GEM_RATE.gold)
    local p = packs and min(packs, most) or most
    if p <= 0 then return 0 end
    G.gold = G.gold - p * GEM_RATE.gold
    addGems(p * GEM_RATE.gem)
    return p * GEM_RATE.gem
end

-- 每波战后：发秘银 + 商店换货（不弹出，顶栏按钮亮起）
addHook('finish', function(res)
    if G.tutorial then return end
    local n = gemIncome(res)
    if n > 0 then addGems(n); res.gems = n end
    if G.phase == 'prep' then openShop(res); G.shop.fresh = true end
end)

-- ---------------------------------------------------------------------------
-- 顶栏：秘银数量 + 「商店」按钮（原来的「装备」按钮）
-- ---------------------------------------------------------------------------
function UI.bumpGems()
    local g = _id('gemBox'); if not g then return end
    g:removeClass('bump'); PAGE:update(); g:addClass('bump')
end

-- 只在游戏侧追加的样式（不修改 scripts/ui/content.lua）
local EXTRA_CSS = [====[
#gemBox img { width: 22px; height: 22px; image-rendering: pixelated; }
#gemBox b { color: #9fe6ff; min-width: 2ch; }
#gemBox.bump { animation: bump .35s steps(3); }
:root[data-lay] #gemBox img { width: 18px; height: 18px; }
:root[data-narrow] #gemBox img { width: 16px; height: 16px; }
img.gem-ic { width: 14px; height: 14px; image-rendering: pixelated; vertical-align: -2px; }
.shop-card .btns img.gem-ic, .inv-item img.gem-ic, .shop-ex img.gem-ic { width: 14px; height: 14px; }
.hud .chip.ping { color: #1b1530; background: #9fe6ff; border-color: #e6fbff; box-shadow: 0 0 0 2px #3b6fd1; }
.sh-tabs { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-bottom: 8px; }
.sh-tabs .chip.on { color: #1b1530; background: var(--brass-hi); border-color: var(--brass); }
.sh-wallet { display: flex; gap: 12px; margin-left: auto; font-size: 15px; }
.sh-wallet span { display: inline-flex; align-items: center; gap: 4px; white-space: nowrap; }
.sh-wallet img { width: 18px; height: 18px; image-rendering: pixelated; }
.sh-wallet .gemv { color: #9fe6ff; }
.sh-wallet .goldv { color: var(--brass-hi); }
.shop-ex { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 6px 10px; margin: 6px 0 10px; padding: 6px 10px; background: var(--night); border-left: 4px solid #6ec8ff; font-size: 13px; }
.shop-ex .exl { display: inline-flex; align-items: center; gap: 4px; color: var(--ink-dim); white-space: nowrap; }
.shop-ex .exl img { width: 16px; height: 16px; image-rendering: pixelated; }
.shop-ex .exb { display: flex; gap: 6px; flex-wrap: wrap; }
.loot-re { display: flex; justify-content: center; margin-top: 8px; }
.shop-card .btns .chip[data-buy] { white-space: nowrap; }
.dmeter { display: flex; flex-direction: column; gap: 3px; margin-top: 3px; }
.dm-head { display: flex; align-items: center; justify-content: space-between; gap: 4px 6px; flex-wrap: wrap; }
.dm-tabs { display: flex; gap: 3px; flex: none; }
.dm-tab { flex: none; white-space: nowrap; font: inherit; font-size: 12px; line-height: 1.25; padding: 1px 6px; color: var(--ink-dim); background: #2d2245; border: 2px solid var(--panel-hi); cursor: pointer; }
.dm-tab.on { color: #1b1530; background: var(--mc); border-color: var(--mc); font-weight: 700; }
.dm-tab:focus-visible { outline: 2px solid var(--ink); outline-offset: 1px; }
.dm-head small { font-size: 12px; color: var(--ink-dim); white-space: nowrap; }
.dm-sum { display: flex; flex-wrap: wrap; gap: 0 7px; font-size: 12px; line-height: 1.4; }
.dm-sum span { white-space: nowrap; }
.info .dm-sum b { color: inherit; font-weight: 700; }
.dm-dps { color: var(--ink-dim); }
.info .dm-dps b { color: var(--mc); }
.dm-list { display: flex; flex-wrap: wrap; gap: 2px 6px; }
.dm-row { display: flex; align-items: center; gap: 3px; flex: 1 1 140px; min-width: 0; padding: 1px 2px 1px 1px; background: rgba(58, 45, 82, 0.6); border-left: 3px solid var(--qc); }
.dm-row.dead { opacity: 0.4; filter: grayscale(1); }
.dm-row img { width: 18px; height: 18px; image-rendering: pixelated; flex: none; }
.dm-main { display: flex; flex-direction: column; gap: 1px; flex: 1 1 auto; min-width: 0; }
.dm-bar { position: relative; display: flex; align-items: center; justify-content: space-between; gap: 4px; height: 14px; padding: 0 3px; background: #2d2245; overflow: hidden; }
.dm-bar i { position: absolute; left: 0; top: 0; bottom: 0; background: var(--mc); opacity: 0.45; }
.dm-bar b, .dm-bar em { position: relative; font-size: 12px; line-height: 14px; white-space: nowrap; }
.info .dm-bar b { color: var(--ink); font-weight: 700; }
.dm-bar em { font-style: normal; color: var(--ink-dim); }
.dm-hp { display: block; height: 2px; background: #2d2245; }
.dm-hp i { display: block; height: 2px; background: #6be06b; }
/* 窄信息栏（超宽比手机：三栏挤压后只有 ~100px）：每行的「总量 / 每秒」挤在一行会
   溢出被裁掉，改成分两行——上面是带进度条的总量，下面是每秒。同时把三栏页签
   允许换行、合计区允许折行，避免整块被横向切掉。 */
:root[data-dnarrow] .dm-head { flex-wrap: wrap; row-gap: 2px; }
:root[data-dnarrow] .dm-tabs { flex-wrap: wrap; }
:root[data-dnarrow] .dm-sum { gap: 0 6px; font-size: 11px; line-height: 1.35; }
:root[data-dnarrow] .dm-head small { font-size: 11px; }
:root[data-dnarrow] .dm-tab { font-size: 11px; padding: 1px 4px; }
:root[data-dnarrow] .dm-row { flex-basis: 100%; }
:root[data-dnarrow] .dm-bar { height: auto; min-height: 14px; flex-wrap: wrap; row-gap: 1px; padding: 0 3px; overflow: visible; }
:root[data-dnarrow] .dm-bar b, :root[data-dnarrow] .dm-bar em { font-size: 11px; line-height: 13px; }
:root[data-dnarrow] .dm-bar em { flex-basis: 100%; }
]====]

local CSS = require("ui.css")

local function installStyles()
    if PAGE._mithrilCss then return end
    PAGE._mithrilCss = true
    -- origin 2：排在 content.lua（origin 1）之后，同名选择器优先
    table.insert(PAGE.sheets, CSS.parse(EXTRA_CSS, 2))
    PAGE:collectStateCompounds()
    PAGE.full = true
    PAGE.needs = true
end

local function installGemBox()
    local hud = _id('app') and _id('app'):querySelector('.hud')
    if not hud or _id('gemBox') then return end
    local box = PAGE.doc.createElement('div')
    box:setAttribute('class', 'stat')
    box:setAttribute('id', 'gemBox')
    box:setHTML('<img id="gemIcon" alt="秘银"><b id="gemNum">0</b>')
    hud:appendChild(box)
    -- 插到「生命」之后、按钮组之前（appendChild 保证 doc / id 注册，再调整顺序）
    local idx
    for i, c in ipairs(hud.children) do
        if c.classSet and c.classSet['hud-btns'] then idx = i break end
    end
    if idx then
        for i, c in ipairs(hud.children) do if c == box then table.remove(hud.children, i) break end end
        table.insert(hud.children, idx, box)
        PAGE:invalidate(hud)
    end
end

local _init = UI.init
function UI.init()
    _init()
    installStyles()
    installGemBox()
    local ic = _id('gemIcon')
    if ic then ic:setAttribute('src', gemIcon()) end
    UI.els.gemNum, UI.els.gemBox = _id('gemNum'), _id('gemBox')
    local b = _id('equipBtn')
    if b then
        b:setText('商店')
        b:setAttribute('aria-label', '商店（买道具、管理装备）')
        b.listeners = { click = { function() Sound.init(); UI.showShop() end } } -- 换掉原来「装备一览」的点击
    end
end

local _update = UI.update
function UI.update()
    _update()
    local E = UI.els
    if E.gemNum then UI.set(E.gemNum, 'gems', S(gems())) end
    local b = _id('equipBtn')
    if b then
        local ping = G.shop and G.shop.fresh and G.phase == 'prep' and not G.tutorial
        if (b:hasClass('ping')) ~= (not not ping) then b:toggleClass('ping', not not ping) end
    end
    -- 商店开着的时候，钱包数字跟着变
    local mb = UI.els.mBody
    if mb and not UI.els.overlay:isHidden() then
        local gv = mb:querySelector('.gemv')
        if gv then
            UI.set(gv, 'shopGems', S(gems()))
            local gd = mb:querySelector('.goldv')
            if gd then UI.set(gd, 'shopGold', S(G.gold)) end
        end
    end
end

return true
