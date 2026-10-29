-- ============================================================================
-- 第三次更新：道具
--  * 每件道具一张独立图标（以前很多道具共用一张图换颜色）
--  * 新增装备 5 件、圣物 4 件、消耗品 5 件
--  * 商店：每波结束后免费刷新 1 次（本波无阵亡 / 打赢精英波再送 1 次）
--  * 军团强化新增「商店装备位」：每升 1 级，货架多 1 件可购买的装备
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local floor, max, min = math.floor, math.max, math.min
local round = js.round
local of = js.of

local ICO = require("game.data_spr_icons")
ICON_PAL = ICO.ICON_PAL
for k, v in pairs(ICO) do if k ~= 'ICON_PAL' then SPR[k] = v end end

-- ---------------------------------------------------------------------------
-- 图标：原来共用图标的道具换成各自的新图
-- ---------------------------------------------------------------------------
local NEW_ICON = {
    pawn = 'n_pawn', classbadge = 'n_crest', oath = 'n_laurel', zealbadge = 'n_flame', soulgem = 'n_soulgem',
    whetstone = 'n_whet', warhelm = 'n_helm', frostcharm = 'n_snow', emberblade = 'n_firesword', vampfang = 'n_fang',
    hawkeye = 'n_monocle', quiver = 'n_quiver', manaorb = 'n_orb', aegisplate = 'n_tower', stormring = 'n_boltring',
    chronogear = 'n_cog', lifebloom = 'n_flower', titanbelt = 'n_belt', lockglove = 'n_lock', shieldscroll = 'n_ward',
    thunder = 'n_talisman', ragepotion = 'n_ragebottle', dew = 'n_drop',
}
for id, ic in pairs(NEW_ICON) do ITEMS[id].icon = ic; ITEMS[id].pal = ICON_PAL end
GEAR_ICON = { atk = 'n_gsword', hp = 'n_chain', spd = 'n_bracer', crit = 'n_dagger', leech = 'n_chalice' }
function itemIcon(it)
    local I = ITEMS[it.id]
    if it.id == 'gear' then return iconURL(GEAR_ICON[it.affix.id], ICON_PAL, 'gear:' .. it.affix.id) end
    return iconURL(I.icon, I.pal, I.pal and ('it:' .. it.id) or nil)
end

-- ---------------------------------------------------------------------------
-- 新道具
-- ---------------------------------------------------------------------------
local NEW = {
    -- 圣物
    goldbell = { kind = 'relic', rar = 0, name = '招财铃', icon = 'n_bell', grp = '经济', desc = '商店每波再多 1 次免费刷新', fx = { freeRefresh = 1 } },
    drillbook = { kind = 'relic', rar = 1, name = '操练手册', icon = 'n_drill', grp = '拉杆', desc = '每次吸收，吸收者额外获得 1 点经验', fx = { absorbPlus = 1 } },
    lifeseed = { kind = 'relic', rar = 1, name = '生命种子', icon = 'n_seed', grp = '战力', desc = '全队每秒回复 1% 最大生命', fx = { teamRegen = 0.01 } },
    treasuremap = { kind = 'relic', rar = 2, name = '藏宝图', icon = 'n_map', grp = '经济', desc = '商店货架多 1 件装备', fx = { shopEq = 1 } },
    -- 装备
    waraxe = { kind = 'equip', rar = 1, name = '战斧', icon = 'n_axe', desc = '攻击 +12%，暴击率 +8%', fx = { atk = 0.12, crit = 0.08 } },
    roundshield = { kind = 'equip', rar = 1, name = '鳞纹圆盾', icon = 'n_roundshield', desc = '生命 +20%，受到的伤害 -6%', fx = { hp = 0.2, dr = 0.06 } },
    warcrown = { kind = 'equip', rar = 2, name = '统帅之冠', icon = 'n_crown', desc = '攻击 +10%，生命 +10%，技能能量获取 +10%', fx = { atk = 0.1, hp = 0.1, charge = 0.1 } },
    shadowcloak = { kind = 'equip', rar = 2, name = '暗影斗篷', icon = 'n_cloak', desc = '闪避 +15%，移动速度 +15%', fx = { dodge = 0.15, move = 0.15 } },
    dragonheart = { kind = 'equip', rar = 3, name = '龙心', icon = 'n_dragonheart', desc = '生命 +25%，攻击 +10%，每秒回复 1.5% 最大生命', fx = { hp = 0.25, atk = 0.1, regen = 0.015 } },
    -- 消耗品
    bomb = { kind = 'cons', rar = 0, name = '火药弹', icon = 'n_bomb', use = 'battle', desc = '对生命最多的 3 个敌人造成全队平均攻击 300% 的伤害并点燃' },
    smoke = { kind = 'cons', rar = 1, name = '烟幕弹', icon = 'n_smoke', use = 'battle', desc = '全体敌人减速 50%，我方全员闪避 +20%，持续 4 秒' },
    elixir = { kind = 'cons', rar = 1, name = '灵能药剂', icon = 'n_elixir', use = 'battle', desc = '全队技能能量 +50' },
    coinbag = { kind = 'cons', rar = 0, name = '金币袋', icon = 'n_coinbag', use = 'prep', desc = '立刻获得 10 金币（拉杆阶段使用；金币可在商店兑换成秘银）' },
    expbook = { kind = 'cons', rar = 2, name = '经验之书', icon = 'n_expbook', use = 'prep', desc = '选中的单位经验 +6（没有选中时给经验最多、还没满的单位）' },
}
for k, v in pairs(NEW) do v.pal = ICON_PAL; ITEMS[k] = v end
local function insertAfter(after, keys)
    local at = ITEM_KEYS:indexOf(after) + 1
    for i, k in ipairs(keys) do ITEM_KEYS:splice(at + i - 1, 0, k) end
end
insertAfter('bloodpact', { 'goldbell', 'drillbook', 'lifeseed', 'treasuremap' })
insertAfter('titanbelt', { 'waraxe', 'roundshield', 'warcrown', 'shadowcloak', 'dragonheart' })
for _, k in ipairs({ 'bomb', 'smoke', 'elixir', 'coinbag', 'expbook' }) do ITEM_KEYS:push(k) end

-- 新装备 / 圣物的效果（属性部分 atk / hp / crit / dr / move 已在 items.lua 的 stats 钩子里通用处理）
addHook('pent', function(ent, u)
    for _, eq in ipairs(equipsOf(u)) do
        local f = ITEMS[eq.id].fx or {}
        if f.dodge then ent.dodge = (ent.dodge or 0) + f.dodge end
    end
    if G.rx and T(G.rx.teamRegen) then ent.regen = (ent.regen or 0) + G.rx.teamRegen end
end)
local _absorbGain = absorbGain
function absorbGain(src, dst) return _absorbGain(src, dst) + (RX().absorbPlus or 0) end

-- ---------------------------------------------------------------------------
-- 新消耗品
-- ---------------------------------------------------------------------------
--- 直接给单位加经验（经验之书）：和吸收一样升星、满 ★★★ 后可以转职
function giveExp(u, n)
    local before, star0 = u.pts, u.star
    u.pts = u.pts + n
    while u.star < 3 and u.pts >= STAR_PTS[u.star + 1] do u.star = u.star + 1 end
    if u.star == 3 then
        u.pts = STAR_PTS[3]
        if not u.awakenReady and not u.branch then u.awakenReady = true; G.pendingAwaken:push(u) end
    end
    G.stats.maxStar = max(G.stats.maxStar, u.star)
    if u.star > star0 then u.pop = 0.4; Sound.play('star') end
    if FX.addAnim then
        local full = STAR_PTS[3]
        local done = u.star >= 3
        FX.addAnim({ kind = 'expbar', unit = u, x = 0, y = 0, from = min(before, full), to = min(u.pts, full), max = full, marks = { STAR_PTS[2] }, gain = n,
            label = done and 'MAX' or (S(min(u.pts, full)) .. '/' .. S(full)), labelCol = done and '#ffd84a' or '#ffe680', dur = 2.2, layer = 1 })
    end
end
local function expTarget()
    local ok = function(u) return u and findSlot(u) and not isSup(u) and not u.branch and not u.awakenReady and u.star < 3 end
    if ok(G.sel) then return G.sel end
    local best
    for u in of(allUnits()) do if ok(u) and (not best or u.pts > best.pts) then best = u end end
    return best
end
local _canUseCons = canUseCons
function canUseCons(it)
    if it.id == 'expbook' and G.phase == 'prep' and not expTarget() then return false, '没有可以加经验的单位（★★★ 和已转职的不行）' end
    return _canUseCons(it)
end
local _useCons = useCons
function useCons(idx)
    local it = G.cons[idx]
    if not it or not NEW[it.id] then return _useCons(idx) end
    local ok, why = canUseCons(it)
    if not ok then UI.toast(why); Sound.play('deny'); return false end
    local id, B = it.id, G.battle
    if id == 'coinbag' then
        G.gold = G.gold + 10; UI.bumpGold(); UI.toast('获得 10 金币')
    elseif id == 'expbook' then
        local u = expTarget()
        giveExp(u, 6); UI.toast(unitName(u) .. ' 经验 +6')
    else
        B.usedCons[id] = true
        local ps, es = alliesOfSide(B, 'p'), alliesOfSide(B, 'e')
        local main = ps:filter(function(o) return not o.minion end)
        local avg = (#main > 0) and (main:reduce(function(a, o) return a + o.atk end, 0) / #main) or 10
        local src = main[0] or ps[0]
        if id == 'bomb' then
            local list = es:slice():sort(function(a, b) return b.hp - a.hp end)
            for i = 0, min(2, #list - 1) do
                local o = list[i]
                if src then hit(src, o, avg * 3, { noCrit = true, noLeech = true }) end
                if not o.dead then applyBurn(o, src, 3, avg * 0.3) end
                if FX.P then FX.P.ring(o.x, o.y, 3, 18, '#ff8a2a', { col2 = '#ffe14a', thick = 3 }); FX.P.star(o.x, o.y - 4, '#ffe14a', '#ffffff', 10) end
                FX.burst(o.x, o.y, '#ff8a2a', 14)
            end
            G.shake = max(G.shake, 0.3); Sound.play('die')
        elseif id == 'smoke' then
            for o in of(es) do applySlow(o, 4, 0.5) end
            for o in of(ps) do o.dodgeT = max(o.dodgeT or 0, 4) end
            B.tint = { t = 0.6, max = 0.6, rgb = '200,200,210' }
        elseif id == 'elixir' then
            for o in of(ps) do if o.skill then o.energy = min(100, (o.energy or 0) + 50) end; FX.ring(o.x, o.y, 8, '#c06bff') end
        end
    end
    G.cons:splice(idx, 1)
    Sound.play('item')
    UI.cache:set('itembar', nil)
    return true
end

-- ---------------------------------------------------------------------------
-- 商店：每波免费刷新 1 次；「商店装备位」强化 / 藏宝图：货架多几件装备
-- ---------------------------------------------------------------------------
local _openShop = openShop
function openShop(res)
    _openShop(res)
    G.shop.free = G.shop.free + 1 + (RX().freeRefresh or 0)
end
function shopExtraEquip() return ((G.mx and G.mx.shopeq) or 0) + (RX().shopEq or 0) end
local _rollShelf = rollShelf
function rollShelf(n)
    local slots = _rollShelf(n)
    local extra = shopExtraEquip()
    if extra > 0 then
        local ex = {}
        slots:forEach(function(s) ex[s.item.id] = true end)
        local odds = shopOdds(G.wave)
        for _ = 1, extra do
            local it = rollItem('equip', odds, ex)
            if it then slots:push({ item = it, price = itemPrice(it, false) }) end
        end
    end
    return slots
end

-- 军团强化：商店装备位
UPG:push({ id = 'shopeq', tab = 'eco', name = '商店装备位', icon = 'n_quiver', max = 3, cost = A(60, 120, 200), note = '每升 1 级，商店货架多 1 件可购买的装备' })
UPG[#UPG - 1].txt = function(l) return T(l) and ('商店货架多 ' .. S(l) .. ' 件装备') or '商店货架只有 1 件装备' end
MX_NONE.shopeq = 0
-- 强化页的图标不带调色板：把这张图标的调色板直接给 spr 用
do
    local _iconURL = iconURL
    function iconURL(name, over, key)
        if over == nil and ICO[name] and name:sub(1, 2) == 'n_' then return _iconURL(name, ICON_PAL, 'ico') end
        return _iconURL(name, over, key)
    end
end

return true
