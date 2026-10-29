-- ============================================================================
-- 商店、精英三选一、装备选择与道具栏；沿用现有 NanoVG DOM。
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local S = js.S
---@type table<string, any>
local UI = UI
local floor, min = math.floor, math.min
local function _id(id) return PAGE.doc.getElementById(id) end
local function rarTag(it)
    local Q, I = QUAL[it.rar], ITEMS[it.id]
    return '<span style="color:' .. Q.color .. '">' .. Q.name .. '</span> · ' .. KIND_NAME_ITEM[I.kind] .. (I.grp and (' · ' .. I.grp) or '')
end
local function once(fn)
    local called, run = false, G
    return function(...)
        if called or G ~= run then return end
        called = true
        if fn then return fn(...) end
    end
end
function unitIconURL(u)
    if u.branch then local B = BRANCHES[u.branch]; return iconURL(B.sprite or u.branch, BRPAL[u.branch], 'br:' .. u.branch) end
    return iconURL(CLASSES[u.cls].sprite, TIER_PAL[u.cls][u.star], u.cls .. S(u.star))
end
local function coin() return '<img src="' .. iconURL('sym_coin') .. '" alt="">' end
local function gem() return '<img class="gem-ic" src="' .. gemIcon() .. '" alt="秘银">' end

-- 第九次更新：商店和装备管理是同一个界面的两个页签（顶栏「商店」）
function UI.shopTabsHTML(active)
    local function tab(id, txt)
        return '<button class="chip' .. (active == id and ' on' or '') .. '" data-shtab="' .. id .. '" aria-pressed="' .. (active == id and 'true' or 'false') .. '">' .. txt .. '</button>'
    end
    return '<div class="sh-tabs">' .. tab('shop', '道具商店') .. tab('equip', '装备管理') ..
        '<span class="sh-wallet"><span>' .. gem() .. '<b class="gemv">' .. S(gems()) .. '</b></span><span>' .. coin() .. '<b class="goldv">' .. S(G.gold) .. '</b></span></span></div>'
end
function UI.bindShopTabs()
    for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-shtab]')) do
        b:addEventListener('click', function()
            Sound.init()
            if b:data('shtab') == 'equip' then UI.showEquipOverview() else UI.showShopAgain() end
        end)
    end
end

function UI.itemBarKey()
    local B = G.battle
    local ph = (G.phase == 'battle' and B and not B.over) and 'b' or ((G.phase == 'prep') and 'p' or 'x')
    local k = ph .. '|' .. G.relics:map(function(it) return it.id .. (it.cls or '') end):join(',') .. '|' .. G.cons:map(function(it) return it.id end):join(',')
    if B and B.usedCons then for id in pairs(B.usedCons) do k = k .. '!' .. id end end
    for id in pairs(G.usedPrepCons or {}) do k = k .. '!p:' .. id end
    k = k .. (G.slot.spinning and '|spin' or '')
    return k .. (G.lockNext and 'L' or '') .. (G.diceNext and 'D' or '') .. (G.tutorial and 'T' or '')
end
function UI.updateItemBar()
    local bar = UI.els.itemBar
    if not bar or not G.relics or not G.cons then return end
    local key = UI.itemBarKey()
    if UI.cache:get('itembar') == key then return end
    UI.cache:set('itembar', key)
    if G.tutorial then bar:setHidden(true); return end
    bar:setHidden(false)
    local parts = { '<span class="lbl">圣物</span>' }
    if #G.relics == 0 then parts[#parts + 1] = '<span class="lbl">无</span>' end
    G.relics:forEach(function(it, i)
        parts[#parts + 1] = '<button class="rel" data-rel="' .. S(i) .. '" aria-label="查看 ' .. itemName(it) .. '"><img src="' .. itemIcon(it) .. '" alt=""></button>'
    end)
    parts[#parts + 1] = '<span class="sep"></span><span class="lbl">消耗品</span>'
    for i = 0, CONS_SLOTS - 1 do
        local it = G.cons[i]
        if it then
            local ok = canUseCons(it)
            parts[#parts + 1] = '<button class="cons" data-i="' .. S(i) .. '" aria-label="使用 ' .. itemName(it) .. '" title="' .. itemName(it) .. '"' .. (ok and '' or ' disabled') .. '><img src="' .. itemIcon(it) .. '" alt=""></button>'
        else parts[#parts + 1] = '<span class="slot0"></span>' end
    end
    if G.lockNext or G.diceNext then parts[#parts + 1] = '<span class="lbl">已生效：' .. (G.lockNext and '锁轴 ' or '') .. (G.diceNext and '幸运骰' or '') .. '</span>' end
    bar:setHTML(table.concat(parts))
    for _, b in ipairs(bar:querySelectorAll('[data-rel]')) do
        b:addEventListener('click', function()
            local it = G.relics[tonumber(b:data('rel'))]
            if not it then return end
            Sound.init(); UI.modal(itemName(it), '<p>' .. itemDesc(it) .. '</p>', '返回战场')
        end)
    end
    for _, b in ipairs(bar:querySelectorAll('.cons')) do
        b:addEventListener('click', function()
            if not UI.els.overlay:isHidden() or not UI.els.home:isHidden() then return end
            Sound.init()
            local i = tonumber(b:data('i'))
            local it = G.cons[i]
            if it and useCons(i) then UI.toast('使用 ' .. itemName(it)); UI.cache:set('itembar', nil) end
        end)
    end
end
-- UI.equipLine / UI.showEquipPick 由 game.equip 覆盖为 3 装备栏版本，这里不再重复定义。

function UI.shopCard(s, i)
    local it, Q = s.item, QUAL[s.item.rar]
    local cls = 'shop-card' .. (s.special and ' special' or '') .. (s.locked and ' locked' or '') .. (s.sold and ' sold' or '')
    local inBattle = G.phase ~= 'prep'
    local full, poor = not s.sold and slotFull(it), not s.sold and gems() < s.price
    local noUnit = ITEMS[it.id].kind == 'equip' and #equipCandidates(it) == 0
    local buy
    if s.sold then buy = '<button class="chip" disabled>已售出</button>'
    else
        buy = '<button class="chip go" data-buy="' .. S(i) .. '"' .. ((poor or full or noUnit or inBattle) and ' disabled' or '') .. '>' .. (full and '槽位已满' or (noUnit and '暂无可装备单位' or ('购买 ' .. gem() .. S(s.price)))) .. '</button>' ..
            '<button class="chip' .. (s.locked and ' on' or '') .. '" data-lock="' .. S(i) .. '"' .. (((not s.locked and G.shop.lockUsed) or inBattle) and ' disabled' or '') .. '>' .. (s.locked and '已锁定' or '锁定') .. '</button>'
    end
    return '<div class="' .. cls .. '" style="--qc:' .. Q.color .. '"><img src="' .. itemIcon(it) .. '" alt=""><b>' .. itemName(it) .. '</b>' ..
        '<span class="tag">' .. (s.special and '<span style="color:#ffe27a">特价 ×0.7</span> · ' or '') .. (s.kept and '保留 · ' or '') .. rarTag(it) .. '</span>' ..
        '<p>' .. itemDesc(it) .. '</p><div class="btns">' .. buy .. '</div></div>'
end
function UI.invHTML(selling)
    local function row(list, kind, cap)
        local title = (kind == 'stash') and '仓库' or KIND_NAME_ITEM[kind]
        local items = list:map(function(it, i)
            return '<span class="inv-item" style="--qc:' .. QUAL[it.rar].color .. '"><img src="' .. itemIcon(it) .. '" alt="">' .. itemName(it) ..
                (selling and ('<button class="chip" data-sell="' .. kind .. ':' .. S(i) .. '">卖 ' .. gem() .. S(sellPrice(it)) .. '</button>') or '') .. '</span>'
        end):join('')
        return '<p class="dim">' .. title .. ' ' .. S(#list) .. '/' .. S(cap) .. '</p><div class="inv">' .. ((#list == 0) and '<span class="inv-empty">空</span>' or items) .. '</div>'
    end
    return row(G.relics, 'relic', RELIC_SLOTS) .. row(G.cons, 'cons', CONS_SLOTS) .. row(A(table.unpack(stashOf())), 'stash', STASH_SLOTS) ..
        '<p class="dim">单位身上的装备在「装备管理」页签里查看、卸下、转移和卖出。</p>'
end
function UI.shopBody()
    local Sh, rc = G.shop, refreshCost()
    local inBattle = G.phase ~= 'prep'
    local R = GEM_RATE
    local packs = floor(G.gold / R.gold)
    local function ex(n, label)
        return '<button class="chip" data-ex="' .. n .. '"' .. ((inBattle or packs < (tonumber(n) or 1)) and ' disabled' or '') .. '>' .. label .. '</button>'
    end
    local allN = packs * R.gem
    return UI.shopTabsHTML('shop') ..
        (inBattle and '<p class="warn">战斗中只能查看货架，打完这一波再买。</p>' or '') ..
        '<div class="shop-bar"><span>下次刷新 ' .. ((rc == 0) and '<b>免费</b>' or (gem() .. S(rc))) .. ((Sh.free > 0) and ('（免费 ' .. S(Sh.free) .. ' 次）') or '') .. '</span>' ..
        '<span><button class="chip" id="shRefresh"' .. ((gems() < rc or inBattle) and ' disabled' or '') .. '>刷新货架</button></span></div>' ..
        '<div class="shop-ex"><span class="exl">' .. coin() .. ' 金币兑换 ' .. gem() .. ' 秘银（' .. S(R.gold) .. ' : ' .. S(R.gem) .. '）</span><span class="exb">' ..
        ex('1', S(R.gold) .. ' → ' .. S(R.gem)) .. ex('5', S(R.gold * 5) .. ' → ' .. S(R.gem * 5)) ..
        '<button class="chip" data-ex="all"' .. ((inBattle or packs < 1) and ' disabled' or '') .. '>全部' .. ((packs >= 1) and (' → ' .. S(allN)) or '') .. '</button></span></div>' ..
        ((Sh.n < 5) and '<p class="dim">这一波失守，少 1 个特价格。</p>' or '') ..
        '<div class="shop-grid">' .. Sh.slots:map(function(s, i) return UI.shopCard(s, i) end):join('') .. '</div>' ..
        '<p class="dim">每波战后发 ' .. gem() .. ' 秘银（赢了 ' .. S(gemIncomeWin(G.wave)) .. ' 起，精英波和无阵亡另有奖励），货架也会换一批新货。每波可以免费锁定 1 件留到下一波；刷新从 2 秘银起，每次 +1，每波重置，每波送 1 次免费刷新。金币还要拉杆，兑换前想清楚（利息按剩下的金币算）。</p>' ..
        '<h3>持有</h3>' .. UI.invHTML(not inBattle)
end
function UI.showShopAgain()
    if not G.shop then openShop(nil) end
    UI.modal('商店', '<div id="shop">' .. UI.shopBody() .. '</div>', UI.backLabel(), function() UI.cache:set('itembar', nil) end)
    UI.els.mTitle.parent:addClass('wide')
    UI.shopBind()
end
function UI.showShop()
    UI.showShopAgain()
    Sound.play('shop')
end
function UI.shopRefresh()
    local box = _id('shop'); if not box then return end
    UI.cache:set('itembar', nil)
    box:setHTML(UI.shopBody()); UI.shopBind()
end
function UI.shopBind()
    local box = _id('shop'); if not box then return end
    local run, shelf = G, G.shop
    local function live() return G == run and G.shop == shelf end
    UI.bindShopTabs()
    local rf = _id('shRefresh')
    if rf then rf:addEventListener('click', function()
        if not live() then return end
        Sound.init()
        if refreshShop() then Sound.play('refresh') else Sound.play('deny') end
        UI.shopRefresh()
    end) end
    for _, b in ipairs(box:querySelectorAll('[data-ex]')) do
        b:addEventListener('click', function()
            if not live() or b:isDisabled() then return end
            Sound.init()
            local k = b:data('ex')
            local got = exchangeGold(k ~= 'all' and tonumber(k) or nil)
            if got > 0 then Sound.play('exchange'); UI.toast('兑换 ' .. S(got) .. ' 秘银'); UI.bumpGems() else Sound.play('deny'); UI.toast('金币不够') end
            UI.shopRefresh()
        end)
    end
    for _, b in ipairs(box:querySelectorAll('[data-buy]')) do
        b:addEventListener('click', function()
            if not live() or b:isDisabled() then return end
            Sound.init()
            local r, it = buySlot(tonumber(b:data('buy')))
            if r == 'ok' then Sound.play('purchase'); UI.shopRefresh()
            elseif r == 'equip' then Sound.play('purchase'); UI.showEquipPick(it, function() UI.showShopAgain() end)
            elseif r == 'relicfull' then -- 第十五次更新：圣物栏满了，已经付款：选放进仓库或换下一件（没有「返回」）
                Sound.play('purchase'); UI.relicFullPick(it, { done = function() UI.showShopAgain() end })
            else Sound.play('deny'); UI.toast(({ poor = '秘银不足（可以用金币兑换）', full = '槽位已满，先卖掉一件', nounit = '没有能装备它的单位，仓库也满了', gone = '已经售出', battle = '战斗中不能购买' })[r] or '买不了') end
        end)
    end
    for _, b in ipairs(box:querySelectorAll('[data-lock]')) do
        b:addEventListener('click', function()
            if not live() or b:isDisabled() then return end
            Sound.init()
            local i = tonumber(b:data('lock'))
            if toggleLock(i) then Sound.play((G.shop.slots[i] and G.shop.slots[i].locked) and 'lock' or 'unlockslot') else Sound.play('deny'); UI.toast('每波只能锁定 1 件') end
            UI.shopRefresh()
        end)
    end
    for _, b in ipairs(box:querySelectorAll('[data-sell]')) do
        b:addEventListener('click', function()
            if not live() then return end
            Sound.init()
            local kind, i = b:data('sell'):match('^(%a+):(%d+)$')
            local p = sellItem(kind, tonumber(i))
            if p > 0 then Sound.play('sell'); UI.toast('卖出，+' .. S(p) .. ' 秘银'); UI.bumpGems() end
            UI.shopRefresh()
        end)
    end
    -- 第十五次更新：圣物收进仓库 / 仓库里的圣物装上（满了选一件互换）
    for _, b in ipairs(box:querySelectorAll('[data-rst]')) do
        b:addEventListener('click', function()
            if not live() or b:isDisabled() or G.phase ~= 'prep' then return end
            Sound.init()
            local r = tonumber(b:data('rst'))
            local it = G.relics[r]
            if it and relicToStash(r) then Sound.play('unequip'); UI.toast(itemName(it) .. ' 收进了仓库（不再生效）')
            else Sound.play('deny'); UI.toast('仓库已满') end
            UI.shopRefresh()
        end)
    end
    for _, b in ipairs(box:querySelectorAll('[data-rup]')) do
        b:addEventListener('click', function()
            if not live() or b:isDisabled() or G.phase ~= 'prep' then return end
            Sound.init()
            local k = tonumber(b:data('rup'))
            if relicBarFull() then UI.relicFromStashPick(k, function() UI.showShopAgain() end)
            else UI.relicFromStashPick(k); UI.shopRefresh() end
        end)
    end
    for _, b in ipairs(box:querySelectorAll('[data-eqsell]')) do
        b:addEventListener('click', function()
            if not live() then return end
            local uid, i = b:data('eqsell'):match('^(%d+):(%d+)$')
            local u = allUnits():find(function(v) return v.id == tonumber(uid) end)
            if not u or #equipsOf(u) == 0 then return end
            Sound.init()
            local p = unequipSell(u, tonumber(i))
            if p > 0 then Sound.play('sell'); UI.toast('卖出，+' .. S(p) .. ' 秘银'); UI.bumpGems(); UI.shopRefresh() end
        end)
    end
end
-- UI.showEquipPick 由 game.equip 覆盖（3 装备栏版本）。

-- 精英战利品界面改由 ui13.lua 提供（第十三次更新：锁定 + 秘银刷新 + 品质随波次）

-- 第九次更新：商店不再每波自动弹出（每波战后自动换货、发秘银，见 mithril.lua），
-- 只有精英波弹出战利品。finishBattle(true) 可能先等广告复活，不能在 finishBattle 里提前处理。
function UI.afterBattle(res)
    UI.cache:set('itembar', nil)
    if G.tutorial or G.phase ~= 'prep' then return end
    if res and res.elite and not res._uiAfterBattle then
        res._uiAfterBattle = true
        UI.showLoot(nil, res)
    end
end
return true
