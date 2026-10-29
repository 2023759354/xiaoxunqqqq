-- ============================================================================
-- 局内道具与商店（更新方案第四节）
--  * 圣物 18 件（全局被动，8 槽；第十五次更新 5 → 8）、装备 8 件特色 + 词条装备（每单位 1 件）、消耗品 10 件（3 槽）
--  * 商店：第 2 波起每场战斗后开放，5 格货架、刷新逐次加价、每波免费锁定 1 格、可出售
--  * 精英波胜利后免费三选一
-- ============================================================================
-- 此模块沿用共享 _ENV，由 game.core 统一装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs = math.floor, math.ceil, js.max, math.min, math.abs
local of = js.of

RELIC_SLOTS, CONS_SLOTS = 8, 3 -- 第十五次更新：圣物 5 → 8 格
SHOP_PRICE = A(6, 10, 16, 24)   -- 普通 / 稀有 / 史诗 / 传说
GRADE_ADD = A(0, 2, 4, 8)       -- 词条装备按品级加价：下品 / 中品 / 上品 / 极品
SHOP_SPECIAL = 0.7              -- 特价格
SELL_RATE = 0.5
LEGEND_CAP = 2                  -- 每局最多出现的传说道具
KIND_NAME_ITEM = { relic = '圣物', equip = '装备', cons = '消耗品' }
-- 第九次更新：商店改用「秘银」结算（买、卖、刷新都是秘银；金币只用来拉杆，也可以兑换成秘银）
function gems() return (G and G.gems) or 0 end
function addGems(n) G.gems = max(0, gems() + n) end

-- icon：精灵名；pal：调色板替换（同一张图标换色复用）
ITEMS = {
    -- —— 圣物 · 经济 ——
    bank = { kind = 'relic', rar = 1, name = '利息存折', icon = 'i_book', grp = '经济', desc = '战后利息上限 +3', fx = { interest = 3 } },
    recycle = { kind = 'relic', rar = 0, name = '回收炉', icon = 'i_furnace', grp = '经济', desc = '满员时溢出的单位折算的金币 2 → 4', fx = { recycle = 4 } },
    purse = { kind = 'relic', rar = 0, name = '钱袋', icon = 'i_bag', grp = '经济', desc = '每场战斗结算 +2 金币', fx = { battleGold = 2 } },
    merchant = { kind = 'relic', rar = 1, name = '商人徽章', icon = 'i_badge', grp = '经济', desc = '商店全部商品价格 -15%，刷新价 -1（最低 1）；买得越早越赚', fx = { shopDisc = 0.15, refreshDisc = 1 } },
    pawn = { kind = 'relic', rar = 0, name = '当铺老板', icon = 'i_bag', pal = { b = '#4a4a5a', B = '#8d9ab2', g = '#c9cbd6', y = '#ffffff' }, grp = '经济', desc = '出售返还从 50% 提高到 75%，适合换装流', fx = { sellRate = 0.75 } },
    -- —— 圣物 · 拉杆 ——
    luckycoin = { kind = 'relic', rar = 0, name = '幸运硬币', icon = 'sym_coin', grp = '拉杆', desc = '幸运上限 +2，★ 出现权重 +4', fx = { luckMax = 2, starW = 4 } },
    stampcard = { kind = 'relic', rar = 1, name = '集点卡', icon = 'm_ticket', grp = '拉杆', desc = '拉杆集点所需的付费拉杆次数 -1（每 5 次 → 每 4 次，每 3 次 → 每 2 次），和局外「拉杆集点」叠加；没有局外集点时按每 4 次', fx = { stamp = 4 } },
    compass = { kind = 'relic', rar = 2, name = '高品质罗盘', icon = 'i_compass', grp = '拉杆', desc = '普通连线召唤出稀有及以上单位的概率 +10%', fx = { qualBoost = 0.1 } },
    alchemy = { kind = 'relic', rar = 2, name = '炼金台', icon = 'i_flask', grp = '拉杆', desc = '不同职业互相吸收时经验不再减半', fx = { fullCross = true } },
    -- —— 圣物 · 战力 ——
    warbanner = { kind = 'relic', rar = 0, name = '血色战旗', icon = 'i_flag', grp = '战力', desc = '全队吸血 +6%', fx = { leech = 0.06 } },
    awl = { kind = 'relic', rar = 1, name = '破甲锥', icon = 'i_spike', grp = '战力', desc = '对精英和首领造成的伤害 +20%', fx = { vsBig = 0.2 } },
    amulet = { kind = 'relic', rar = 0, name = '钢铁护符', icon = 'i_amulet', grp = '战力', desc = '全队受到的伤害 -6%', fx = { dr = 0.06 } },
    horn = { kind = 'relic', rar = 1, name = '先手号角', icon = 'i_horn', grp = '战力', desc = '开战时全队狂热 2 秒（攻速翻倍）；和战旗手的开战狂热取较长者，不叠加', fx = { openHaste = 2 } },
    crystal = { kind = 'relic', rar = 1, name = '能量水晶', icon = 'm_gem', grp = '战力', desc = '全队技能能量获取 +15%（和时空法师、月光花的 +25% 相加，最多 +40%）', fx = { charge = 0.15 } },
    classbadge = { kind = 'relic', rar = 1, name = '兵种徽记', icon = 'i_badge', pal = { r = '#3b6fd1', g = '#8d9ab2', y = '#cfe3ff', F = '#ffffff' }, grp = '战力', desc = '指定兵种的攻击和生命 +15%，另外两个兵种 -5%', fx = { classBuff = true } },
    oath = { kind = 'relic', rar = 2, name = '同族之誓', icon = 'i_badge', pal = { r = '#2f7a34', g = '#4fbf4a', y = '#9be36b', F = '#e6ffd6' }, grp = '战力', desc = '出战的三个兵种同属一个类别（人类 / 动物 / 植物）时，全队攻击 +15%、生命 +15%', fx = { kindOath = true } },
    -- —— 圣物 · 诅咒（强力，有代价） ——
    gambler = { kind = 'relic', rar = 2, name = '赌徒之戒', icon = 'i_ring', grp = '诅咒', desc = '全员攻击 +25%', cost = '每次拉杆多花 1 金币', fx = { atk = 0.25, spinExtra = 1 } },
    bloodpact = { kind = 'relic', rar = 3, name = '血契', icon = 'heart', pal = { r = '#7a1f2b', O = '#ff3434' }, grp = '诅咒', desc = '全员攻击 +30%，吸血 +10%', cost = '每场战斗开始时全员损失 15% 当前生命', fx = { atk = 0.3, leech = 0.1, bloodPact = 0.15 } },

    -- —— 装备（每个单位 1 件） ——
    boots = { kind = 'equip', rar = 0, name = '疾风靴', icon = 'i_boots', desc = '移动速度 +30%', fx = { move = 0.3 } },
    lens = { kind = 'equip', rar = 1, name = '远视镜', icon = 'i_lens', desc = '射程 +15', limit = '仅远程兵种', ranged = true, fx = { range = 15 } },
    thornmail = { kind = 'equip', rar = 1, name = '荆棘甲', icon = 'i_armor', desc = '被近战攻击时反弹 25% 伤害（远程普攻反弹一半）', fx = { thorns = 0.25 } },
    cross = { kind = 'equip', rar = 2, name = '复活十字', icon = 'i_cross', desc = '阵亡时以 50% 生命复活，每场一次', fx = { reviveOnce = 0.5 } },
    soulblade = { kind = 'equip', rar = 1, name = '吸魂刃', icon = 'i_blade', desc = '击杀敌人回复 10% 生命并获得 10 点能量', fx = { killHeal = 0.1, killEnergy = 10 } },
    zealbadge = { kind = 'equip', rar = 1, name = '狂热徽章', icon = 'i_badge', pal = { r = '#ff6a4a', g = '#d8433a', y = '#ff8a6a', F = '#ffe14a' }, desc = '释放技能后狂热 2 秒（攻速翻倍）', fx = { skillHaste = 2 } },
    gauntlet = { kind = 'equip', rar = 0, name = '破盾拳套', icon = 'i_glove', desc = '对带护盾的敌人伤害 +30%', fx = { vsShield = 0.3 } },
    soulgem = { kind = 'equip', rar = 3, name = '噬魂宝石', icon = 'm_gem', pal = { a = '#a8102a', A = '#ff3434', o = '#ff8e6a', O = '#ffffff', u = '#7a1f2b' }, desc = '攻击 +20%；本场每击杀一个敌人攻击再 +5%，最多 5 层（与征服者叠层分开计算）', fx = { atk = 0.2, killAtk = 0.05 } },
    gear = { kind = 'equip', rar = 0, name = '词条装备', icon = 'i_blade', desc = '附带一条额外词条', gear = true },

    -- —— 消耗品（每件只能用一次；同一种每场限 1 次） ——
    lockglove = { kind = 'cons', rar = 0, name = '锁轴手套', icon = 'i_glove', pal = { h = '#c8900f', H = '#ffe680' }, use = 'prep', desc = '下一次拉杆保留中间一列不动' },
    dice = { kind = 'cons', rar = 0, name = '幸运骰', icon = 'i_dice', use = 'prep', desc = '下一次拉杆 ★ 的出现权重翻倍' },
    frostscroll = { kind = 'cons', rar = 1, name = '冰霜卷轴', icon = 'i_scroll', pal = { a = '#3aa6c8', A = '#bff4ff', t = '#e4f4ff' }, use = 'battle', desc = '全体敌人冻结 1.5 秒（首领 0.7 秒）' },
    healpotion = { kind = 'cons', rar = 0, name = '治疗药剂', icon = 'i_potion', pal = { r = '#2f7a34', R = '#4fbf4a' }, use = 'battle', desc = '全队回复 25% 最大生命' },
    ragepotion = { kind = 'cons', rar = 0, name = '狂暴药剂', icon = 'i_potion', use = 'battle', desc = '全队狂热 4 秒（攻速翻倍）' },
    shieldscroll = { kind = 'cons', rar = 1, name = '护盾卷轴', icon = 'i_scroll', pal = { a = '#c8900f', A = '#ffe680' }, use = 'battle', desc = '全队获得 30% 最大生命的护盾' },
    thunder = { kind = 'cons', rar = 1, name = '闪电符', icon = 'i_scroll', pal = { a = '#5a2a7a', A = '#ffe14a', t = '#fff6b0' }, use = 'battle', desc = '对全体敌人造成相当于全队平均攻击 200% 的伤害' },
    dew = { kind = 'cons', rar = 0, name = '净化露', icon = 'i_potion', pal = { r = '#3aa6c8', R = '#bff4ff' }, use = 'battle', desc = '解除我方全员的眩晕、中毒、灼烧、流血等负面状态' },
    whistle = { kind = 'cons', rar = 2, name = '召唤哨', icon = 'i_whistle', use = 'battle', desc = '在阵地空位召唤一个出战兵种的 ★ 单位助战（只在本场有效），需要有空格' },
    phoenix = { kind = 'cons', rar = 3, name = '凤凰羽', icon = 'i_feather', use = 'passive', desc = '被动：本场全军覆没时全员以 40% 生命复活，这一波不扣生命；用后消失' },
}
ITEM_KEYS = A('bank', 'recycle', 'purse', 'merchant', 'pawn', 'luckycoin', 'stampcard', 'compass', 'alchemy', 'warbanner', 'awl', 'amulet', 'horn', 'crystal', 'classbadge', 'oath', 'gambler', 'bloodpact',
    'boots', 'lens', 'thornmail', 'cross', 'soulblade', 'zealbadge', 'gauntlet', 'soulgem',
    'lockglove', 'dice', 'frostscroll', 'healpotion', 'ragepotion', 'shieldscroll', 'thunder', 'dew', 'whistle', 'phoenix')
GEAR_NAME = { atk = '强攻之刃', hp = '坚韧之甲', spd = '迅捷手环', crit = '致命匕首', leech = '嗜血獠牙' }
GEAR_ICON = { atk = 'i_blade', hp = 'i_armor', spd = 'i_boots', crit = 'i_spike', leech = 'i_ring' }

-- ---------------------------------------------------------------------------
-- 道具实例
-- ---------------------------------------------------------------------------
function itemDef(it) return ITEMS[it.id] end
function itemName(it)
    if it.id == 'gear' then return GEAR_NAME[it.affix.id] end
    if it.id == 'classbadge' and it.cls then return '兵种徽记·' .. CLASSES[it.cls].name end
    return ITEMS[it.id].name
end
function itemIcon(it)
    local I = ITEMS[it.id]
    if it.id == 'gear' then return iconURL(GEAR_ICON[it.affix.id]) end
    return iconURL(I.icon, I.pal, I.pal and ('it:' .. it.id) or nil)
end
function itemDesc(it)
    local I = ITEMS[it.id]
    if it.id == 'gear' then
        local Af = AFFIXES:find(function(a) return a.id == it.affix.id end)
        return '额外词条 <span style="color:' .. AFFIX_GRADE[it.affix.q].color .. '">' .. Af.name .. '（' .. AFFIX_GRADE[it.affix.q].name .. '）：' .. Af.fmt(it.affix.v) .. '</span>'
    end
    local d = I.desc
    if it.id == 'classbadge' and it.cls then d = CLASSES[it.cls].name .. '的攻击和生命 +15%，另外两个兵种 -5%' end
    if I.cost then d = d .. '<br><span class="cost">代价：' .. I.cost .. '</span>' end
    if I.limit then d = d .. '（' .. I.limit .. '）' end
    return d
end
function newItem(id, rar)
    local it = { id = id, rar = rar or ITEMS[id].rar, uid = G.nextItem or 1 }
    G.nextItem = (G.nextItem or 1) + 1
    if it.rar >= 3 then G.legends = (G.legends or 0) + 1 end -- 上限按出现次数，而非买下数量
    if id == 'gear' then it.affix = rollAffix(it.rar) end
    if id == 'classbadge' then it.cls = pick(G.squad) end
    return it
end
function itemBasePrice(it)
    local p = SHOP_PRICE[it.rar]
    if it.id == 'gear' then p = p + GRADE_ADD[it.affix.q] end
    return p
end
function itemPrice(it, special)
    local p = itemBasePrice(it)
    if special then p = p * SHOP_SPECIAL end
    p = p * (1 - (RX().shopDisc or 0))
    return max(1, round(p))
end
function sellPrice(it) return max(1, floor(itemBasePrice(it) * (RX().sellRate or SELL_RATE))) end

-- ---------------------------------------------------------------------------
-- 圣物效果汇总（G.rx）
-- ---------------------------------------------------------------------------
local RX_NONE = { recycle = 2, sellRate = SELL_RATE }
function RX() return (G and G.rx) or RX_NONE end
function recalcRelics()
    local r = { interest = 0, recycle = 2, battleGold = 0, shopDisc = 0, refreshDisc = 0, sellRate = SELL_RATE, luckMax = 0, starW = 0, stamp = 0,
        qualBoost = 0, fullCross = false, leech = 0, vsBig = 0, dr = 0, openHaste = 0, charge = 0, badges = A(), kindOath = false, atk = 0, spinExtra = 0, bloodPact = 0 }
    for it in of(G.relics) do
        local f = ITEMS[it.id].fx or {}
        for k, v in pairs(f) do
            if k == 'recycle' then r.recycle = max(r.recycle, v)
            elseif k == 'sellRate' then r.sellRate = max(r.sellRate, v)
            elseif k == 'classBuff' then r.badges:push(it.cls)
            elseif type(v) == 'boolean' then r[k] = r[k] or v
            else r[k] = (r[k] or 0) + v end
        end
    end
    G.rx = r
    G.dmgVsBig = r.vsBig
    G.luckMax = 3 + ((G.mx and G.mx.luck) or 0) + r.luckMax
end
function hasRelic(id) return G.relics:some(function(it) return it.id == id end) end
--- 第十五次更新：仓库里也能放圣物（不生效）。抽货 / 战利品排除「已拥有」时要连仓库一起算，免得抽到重复的
function ownsRelic(id)
    if hasRelic(id) then return true end
    for _, it in ipairs((G and G.stash) or {}) do if it.id == id then return true end end
    return false
end
function isRelic(it) return it ~= nil and ITEMS[it.id] ~= nil and ITEMS[it.id].kind == 'relic' end
function relicBarFull() return #G.relics >= RELIC_SLOTS end
function sameKindSquad()
    local k = CLASSES[G.squad[0]].kind
    return G.squad:every(function(c) return CLASSES[c].kind == k end)
end

-- 单位属性：圣物 + 装备
addHook('stats', function(u, st)
    if not G or not G.rx then return end
    local r = G.rx
    local atk, hp = r.atk, 0
    for c in of(r.badges) do if c == u.cls then atk = atk + 0.15; hp = hp + 0.15 elseif G.squad:includes(u.cls) then atk = atk - 0.05; hp = hp - 0.05 end end
    if r.kindOath and sameKindSquad() then atk = atk + 0.15; hp = hp + 0.15 end
    for _, eq in ipairs(equipsOf(u)) do -- 每个单位最多 EQUIP_SLOTS 件装备（更新）
        local f = ITEMS[eq.id].fx or {}
        atk = atk + (f.atk or 0); hp = hp + (f.hp or 0)
        if f.move then st.speed = st.speed * (1 + f.move) end
        if f.range and st.proj then st.range = st.range + f.range end
        if f.spd then st.cd = st.cd / (1 + f.spd) end
        if f.crit then st.crit = st.crit + f.crit end
        if f.leech then st.leech = st.leech + f.leech end
        if f.dr then st.dr = st.dr + f.dr end
        if f.burn then st.burnOnHit = true end
        if f.slowHit then st.slowHit = max(st.slowHit or 0, f.slowHit) end
        if f.chainHit then st.chainHit = max(st.chainHit or 0, f.chainHit) end
        if eq.id == 'gear' then
            local a = eq.affix
            if a.id == 'atk' then atk = atk + a.v / 100 elseif a.id == 'hp' then hp = hp + a.v / 100
            elseif a.id == 'spd' then st.cd = st.cd / (1 + a.v / 100) elseif a.id == 'crit' then st.crit = st.crit + a.v / 100
            elseif a.id == 'leech' then st.leech = st.leech + a.v / 100 end
        end
    end
    st.atk = st.atk * (1 + atk); st.hp = st.hp * (1 + hp)
    st.leech = st.leech + r.leech
    st.dr = st.dr + r.dr
end)
addHook('pent', function(ent, u)
    if G.rx and T(G.rx.charge) then ent.chargeMul = min(1.4, (ent.chargeMul or 1) + G.rx.charge) end
    for _, eq in ipairs(equipsOf(u)) do
        if eq.id ~= 'gear' then
            local f = ITEMS[eq.id].fx or {}
            if f.thorns then ent.thorns = max(ent.thorns or 0, f.thorns) end
            if f.reviveOnce then ent.reviveOnce = max(ent.reviveOnce or 0, f.reviveOnce) end
            if f.killHeal then ent.killHeal = (ent.killHeal or 0) + f.killHeal end
            if f.killEnergy then ent.killEnergy = (ent.killEnergy or 0) + f.killEnergy end
            if f.skillHaste then ent.skillHaste = max(ent.skillHaste or 0, f.skillHaste) end
            if f.vsShield then ent.vsShield = (ent.vsShield or 0) + f.vsShield end
            if f.killAtk then ent.killAtk = f.killAtk; ent.gemBase = ent.atk; ent.gemN = 0 end
            if f.startEnergy and ent.skill then ent.energy = min(100, (ent.energy or 0) + f.startEnergy) end
            if f.charge then ent.chargeMul = min(1.6, (ent.chargeMul or 1) + f.charge) end
            if f.regen then ent.regen = (ent.regen or 0) + f.regen end
        end
    end
end)
addHook('death', function(t, src, B)
    if not src or src.dead or src.side == t.side then return end
    if T(src.killEnergy) then gainEnergy(src, src.killEnergy) end
    if T(src.killAtk) and src.gemN < 5 then src.gemN = src.gemN + 1; src.atk = src.atk + round(src.gemBase * src.killAtk) end
end)
addHook('start', function(B)
    if not G.rx then return end
    local ps = B.ents:filter(function(e) return e.side == 'p' end)
    if T(G.rx.openHaste) then ps:forEach(function(e) e.haste = max(e.haste or 0, G.rx.openHaste) end) end
    if T(G.rx.bloodPact) then ps:forEach(function(e) e.hp = max(1, round(e.hp * (1 - G.rx.bloodPact))) end) end
    B.usedCons = {}
end)
addHook('finish', function(res)
    G.usedPrepCons = {}
    if G.rx and T(G.rx.battleGold) then G.gold = G.gold + G.rx.battleGold; res.base = res.base + G.rx.battleGold end
end)
-- 凤凰羽：全军覆没时全员复活
addHook('lose', function(B)
    ---@type table<string, any>
    local UI = UI
    local i = G.cons:findIndex(function(it) return it.id == 'phoenix' end)
    if i < 0 then return false end
    local n = #B.ents:filter(function(e) return e.dead and e.side == 'p' and not e.minion end)
    if n == 0 then return false end
    G.cons:splice(i, 1)
    for e in of(B.ents) do if e.dead and e.side == 'p' and not e.minion then
        revive(e, 0.4); e.wither = 0; e.root = 0; e.infect = nil; e.silenced = 0; e.chill = nil
    end end
    FX.float(128, 40, 'PHOENIX', '#ff8a2a'); B.tint = { t = 0.8, max = 0.8, rgb = '255,140,40' }
    UI.banner('凤凰羽：全员复活', 'gold'); Sound.play('awaken')
    return true
end)

-- ---------------------------------------------------------------------------
-- 获取 / 出售 / 装备
-- ---------------------------------------------------------------------------
function legendCount() return G.legends or 0 end
--- 把道具放进对应槽位；装备返回 'equip' 交给界面选单位
function gainItem(it)
    local I = ITEMS[it.id]
    -- 第十五次更新：圣物栏满了不再拒收，交给界面选「放进仓库」或「替换一件」（见 relic15.lua）
    if I.kind == 'relic' and relicBarFull() then return 'relicfull' end
    if I.kind == 'relic' then G.relics:push(it); recalcRelics()
    elseif I.kind == 'cons' then G.cons:push(it)
    else return 'equip' end
    return 'ok'
end
function slotFull(it)
    local k = ITEMS[it.id].kind
    if k == 'relic' then return false end -- 第十五次更新：圣物栏满时可以放仓库或替换，不算「满」
    if k == 'cons' then return #G.cons >= CONS_SLOTS end
    return false
end
EQUIP_SLOTS = 3
--- 单位身上的装备列表（旧存档 / 旧代码里的单件 u.equip 自动迁移）
function equipsOf(u)
    if not u then return {} end
    local l = u.equips
    if not l then l = {}; u.equips = l end
    if u.equip then table.insert(l, 1, u.equip); u.equip = nil end
    return l
end
--- 能不能装：远程专属装备不给近战；兵种限定装备只给对应兵种（第六次更新）
--- 第十五次更新：仓库里可能放着圣物，圣物不能装给角色
function canEquipItem(it, u)
    local I = ITEMS[it.id]
    if I.kind ~= 'equip' then return false end
    if I.ranged and not unitStats(u).proj then return false end
    if I.cls and u.cls ~= I.cls then return false end
    return true
end
function equipCandidates(it)
    return allUnits():filter(function(u) return canEquipItem(it, u) end)
end
-- ---------------------------------------------------------------------------
-- 第七次更新：装备仓库。换下 / 卸下的装备先放进仓库，以后随时装给别的角色；
-- 仓库满了才按出售价折回金币。仓库只在这一局里有效（和圣物、消耗品一样）
-- 第十五次更新：仓库 6 → 10 格，圣物也能放进来（放在仓库里的圣物不生效）
-- ---------------------------------------------------------------------------
STASH_SLOTS = 10
function stashOf()
    if not G.stash then G.stash = {} end
    return G.stash
end
function stashFull() return #stashOf() >= STASH_SLOTS end
--- 放进仓库；满了返回 false（调用方决定卖掉还是不动）
function stashPut(it)
    local st = stashOf()
    if #st >= STASH_SLOTS then return false end
    st[#st + 1] = it
    return true
end
--- 仓库里能交给 u 的装备（序号列表）
function stashFor(u)
    local out = {}
    for k, it in ipairs(stashOf()) do if canEquipItem(it, u) then out[#out + 1] = k end end
    return out
end
--- 从仓库拿第 k 件给 u：有空栏直接装上；满了和第 replace 件互换（换下的放回仓库原位）
function stashEquip(k, u, replace)
    local st = stashOf()
    local it = st[k]
    if not it or not canEquipItem(it, u) then return false end
    local l = equipsOf(u)
    if #l < EQUIP_SLOTS then
        table.remove(st, k); l[#l + 1] = it
        return true
    end
    local r = replace or 1
    local old = l[r]
    l[r] = it; st[k] = old
    return true, old
end
--- 仓库第 k 件和 u 的第 i 件互换（i 是空栏时就是直接装上）
function stashSwap(k, u, i)
    local st, l = stashOf(), equipsOf(u)
    local it = st[k]
    if not it or not canEquipItem(it, u) then return false end
    local old = l[i]
    if not old then return stashEquip(k, u) end
    l[i] = it; st[k] = old
    return true, old
end
--- 把 u 的第 i 件卸下放进仓库
function unequipToStash(u, i)
    local l = equipsOf(u)
    local it = l[i]
    if not it or stashFull() then return false end
    table.remove(l, i)
    stashPut(it)
    return true
end
function stashSell(k)
    local st = stashOf()
    local it = st[k]
    if not it then return 0 end
    table.remove(st, k)
    local p = sellPrice(it)
    addGems(p) -- 第九次更新：道具一律按秘银买卖
    return p
end
--- 换下来的旧装备：先进仓库，仓库满了才折回秘银。返回 'stash' / 'sold'
function stashOrSell(old)
    if stashPut(old) then return 'stash' end
    addGems(sellPrice(old))
    return 'sold'
end
--- 装备到单位：有空栏直接装上；满了换掉第 replace 件（默认最早那件）
--  第七次更新：换下的旧装备放进仓库（以前直接折成金币就没了），仓库满了才折回金币
--  返回：换下的旧装备、去向（'stash' / 'sold'）
function equipItem(it, u, replace)
    local l = equipsOf(u)
    if #l < EQUIP_SLOTS then l[#l + 1] = it; return nil end
    local i = replace or 1
    local old = l[i]
    l[i] = it
    if old then return old, stashOrSell(old) end
    return nil
end
function unequipSell(u, i)
    local l = equipsOf(u)
    local it = l[i]
    if not it then return 0 end
    table.remove(l, i)
    local p = sellPrice(it)
    addGems(p)
    return p
end
function sellItem(kind, idx)
    if kind == 'stash' then return stashSell(idx + 1) end -- 商店列表 0 起始，仓库 1 起始
    local list = (kind == 'relic') and G.relics or G.cons
    local it = list[idx]
    if not it then return 0 end
    list:splice(idx, 1)
    local p = sellPrice(it)
    addGems(p)
    if kind == 'relic' then recalcRelics() end
    return p
end
-- 吸收：被吸收单位的装备交给吸收者（吸收者装备栏满了则先进仓库，仓库满才折价卖出）
local _absorb = absorb
function absorb(src, dst)
    local eqs = equipsOf(src)
    src.equips = nil
    local r = _absorb(src, dst)
    local l = equipsOf(dst)
    for _, eq in ipairs(eqs) do
        if #l < EQUIP_SLOTS then l[#l + 1] = eq else stashOrSell(eq) end
    end
    return r
end
local _feedAway = feedAway
function feedAway(v)
    local before = G.gold
    local r = _feedAway(v)
    if r.sold then -- 回收炉：折算金币 2 → 4；装备折价卖出
        G.gold = before + RX().recycle
        for _, eq in ipairs(equipsOf(v)) do addGems(sellPrice(eq)) end
        v.equips = nil
        r.coins = RX().recycle
    end
    return r
end

-- ---------------------------------------------------------------------------
-- 经济 / 老虎机挂接
-- ---------------------------------------------------------------------------
local _interestCap = interestCap
function interestCap() return _interestCap() + (RX().interest or 0) end
local _spinCost = spinCost
function spinCost() return _spinCost() + (RX().spinExtra or 0) end
-- 第十次更新：集点卡和局外「拉杆集点」叠加——有局外集点时所需次数 -1（最少 2 次），没有时按卡面的每 4 次
STAMP_CARD_MIN = 2
local _stampGoal = stampGoal
function stampGoal()
    local m = _stampGoal()
    local c = RX().stamp or 0
    if not T(c) then return m end
    if m == 0 then return c end
    return max(STAMP_CARD_MIN, m - 1)
end
local _absorbGain = absorbGain
function absorbGain(src, dst)
    if RX().fullCross and src.cls ~= dst.cls then return 2 + src.pts end
    return _absorbGain(src, dst)
end
local _rollQuality = rollQuality
function rollQuality(mn)
    mn = mn or 0
    if mn == 0 and T(RX().qualBoost) and js.random() < RX().qualBoost then return _rollQuality(1) end
    return _rollQuality(mn)
end
local _rollSymbol = rollSymbol
function rollSymbol()
    local extra = (RX().starW or 0)
    if G.diceSpin then extra = extra + G.symW.S + G.luck * LUCK_BONUS + ((G.mx and G.mx.star) or 0) + (RX().starW or 0) end -- 幸运骰：★ 总权重翻倍
    if extra == 0 then return _rollSymbol() end
    local keep = G.symW.S
    G.symW.S = keep + extra
    local s = _rollSymbol()
    G.symW.S = keep
    return s
end
--- 拉杆前：锁轴手套 / 幸运骰
function beforeSpin()
    G.diceSpin = G.diceNext; G.diceNext = false
end
function afterRollGrid(grid)
    if G.lockNext then -- 锁轴手套：保留中间一列
        G.lockNext = false
        for _, i in ipairs({ 1, 4, 7 }) do grid[i] = G.slot.grid[i] end
    end
    G.diceSpin = false
    return grid
end

-- ---------------------------------------------------------------------------
-- 消耗品
-- ---------------------------------------------------------------------------
function canUseCons(it)
    local I = ITEMS[it.id]
    if I.use == 'passive' then return false, '战斗中全军覆没时自动触发' end
    if I.use == 'prep' then
        if G.phase ~= 'prep' or G.slot.spinning then return false, '只能在拉杆前使用' end
        if G.usedPrepCons[it.id] then return false, '同一种消耗品每场只能用一次' end
        if it.id == 'lockglove' and G.lockNext then return false, '下一次拉杆已经锁定中间一列' end
        if it.id == 'dice' and G.diceNext then return false, '下一次拉杆已经用了幸运骰' end
        return true
    end
    local B = G.battle
    if G.phase ~= 'battle' or not B or B.over then return false, '只能在战斗中使用' end
    if B.usedCons and B.usedCons[it.id] then return false, '同一种消耗品每场只能用一次' end
    if it.id == 'whistle' and not freeFormSlot(B) then return false, '阵地没有空位' end
    return true
end
function freeFormSlot(B)
    for _, i in ipairs({ 5, 6, 1, 2, 9, 10, 4, 7, 0, 3, 8, 11 }) do
        if not G.form[i] and not (isSealed and isSealed(i)) and not (B.whistleSlots and B.whistleSlots[i]) then return i end
    end
    return nil
end
function useCons(idx)
    ---@type table<string, any>
    local UI = UI
    local it = G.cons[idx]
    if not it then return false end
    local ok, why = canUseCons(it)
    if not ok then UI.toast(why); Sound.play('deny'); return false end
    local B = G.battle
    local id = it.id
    if id == 'lockglove' then G.usedPrepCons[id] = true; G.lockNext = true; UI.toast('下一次拉杆：中间一列保持不动')
    elseif id == 'dice' then G.usedPrepCons[id] = true; G.diceNext = true; UI.toast('下一次拉杆：★ 权重翻倍')
    else
        B.usedCons[id] = true
        local ps, es = alliesOfSide(B, 'p'), alliesOfSide(B, 'e')
        if id == 'frostscroll' then
            for o in of(es) do o.stun = max(o.stun, o.big and 0.7 or 1.5); applySlow(o, 2, 0.3) end
            B.tint = { t = 0.6, max = 0.6, rgb = '191,244,255' }
        elseif id == 'healpotion' then for o in of(ps) do healAmt(o, o.maxHp * 0.25); FX.ring(o.x, o.y, 8, '#8fe07a') end
        elseif id == 'ragepotion' then for o in of(ps) do o.haste = max(o.haste or 0, 4); FX.ring(o.x, o.y, 8, '#ff6a4a') end
        elseif id == 'shieldscroll' then for o in of(ps) do o.shield = min(o.maxHp, (o.shield or 0) + o.maxHp * 0.3); FX.ring(o.x, o.y, 9, '#fff3b0') end
        elseif id == 'thunder' then
            local main = ps:filter(function(o) return not o.minion end)
            local avg = (#main > 0) and (main:reduce(function(a, o) return a + o.atk end, 0) / #main) or 10
            local src = main[0] or ps[0]
            for o in of(es) do if src then hit(src, o, avg * 2, { noCrit = true, noLeech = true }) end; FX.bolt(o.x, 0, o.x, o.y - 3) end
            Sound.play('zap'); G.shake = max(G.shake, 0.3)
        elseif id == 'dew' then for o in of(ps) do cleanse(o, true) end
        elseif id == 'whistle' then
            local i = freeFormSlot(B)
            B.whistleSlots = B.whistleSlots or {}
            B.whistleSlots[i] = true
            local u = { id = -1, cls = pick(G.squad), star = 1, q = 0, pts = 0, affix = rollAffix(0), pop = 0 }
            local e = playerEnt(u, i)
            e.temp = true; e.unit = nil; e.cdLeft = 0.3
            B.ents:push(e)
            FX.particle(e.x, e.y, '#ffe14a', 16, 50, 40, 0.6); FX.ring(e.x, e.y, 10, '#ffe14a')
        end
    end
    G.cons:splice(idx, 1)
    Sound.play('item')
    return true
end
function alliesOfSide(B, side) return B.ents:filter(function(o) return not o.dead and o.side == side end) end

-- ---------------------------------------------------------------------------
-- 商店
-- ---------------------------------------------------------------------------
function shopOdds(w)
    if w >= G.maxWave - 2 and legendCount() < LEGEND_CAP then return A(45, 30, 17, 8) end -- 通关前三波：可能出现传说
    if w >= 10 then return A(50, 32, 18, 0) end
    if w >= 5 then return A(70, 30, 0, 0) end
    return A(85, 15, 0, 0)
end
local function rollRar(odds)
    local tot = odds:reduce(function(a, b) return a + b end, 0)
    local r = js.random() * tot
    for q = 0, 3 do r = r - odds[q]; if r < 0 then return q end end
    return 0
end
--- 按种类和品质抽一件；排除已持有的圣物和本次已出现的
function rollItem(kind, odds, exclude)
    local rar = rollRar(odds)
    local order = {}
    for q = rar, 0, -1 do if odds[q] > 0 and (q < 3 or legendCount() < LEGEND_CAP) then order[#order + 1] = q end end
    for q = rar + 1, 3 do if odds[q] > 0 and (q < 3 or legendCount() < LEGEND_CAP) then order[#order + 1] = q end end -- 仅在本波已开放的品质里兜底
    for _, q in ipairs(order) do
        local pool = ITEM_KEYS:filter(function(k)
            local I = ITEMS[k]
            return I.kind == kind and I.rar == q and not exclude[k] and not (I.kind == 'relic' and ownsRelic(k)) and not (q >= 3 and legendCount() >= LEGEND_CAP)
        end)
        if kind == 'equip' and js.random() < 0.5 then pool = A() end -- 一半是词条装备
        if #pool > 0 then local k = pick(pool); exclude[k] = true; return newItem(k, q) end
        if kind == 'equip' then return newItem('gear', q) end
    end
    if kind == 'equip' then return newItem('gear', 0) end
    return nil
end
function rollShelf(n, w)
    local odds = shopOdds(w or G.wave)
    local ex = {}
    local keep = A()
    if G.shop and G.shop.slots then
        G.shop.slots:forEach(function(s) if s.locked and not s.sold then s.locked = false; s.kept = true; keep:push(s); ex[s.item.id] = true end end)
    end
    local plan = A('relic', 'relic', 'equip', 'cons')
    local slots = A()
    -- 四格货架先为锁定特价留位，避免先生成再丢弃商品而误计传说出现次数。
    local reserveSpecial = n < 5 and keep:some(function(s) return s.special end)
    local normalN = reserveSpecial and (n - 1) or #plan
    for index = 0, normalN - 1 do
        local kind = plan[index]
        local i = keep:findIndex(function(s) return ITEMS[s.item.id].kind == kind and not s.special end)
        if i >= 0 then slots:push(keep[i]); keep:splice(i, 1)
        else local it = rollItem(kind, odds, ex); if it then slots:push({ item = it }) end end
    end
    if n >= 5 then -- 特价格：从四类里随机抽，价格 ×0.7
        local i = keep:findIndex(function(s) return s.special end)
        if i >= 0 then slots:push(keep[i]); keep:splice(i, 1)
        else
            local it = rollItem(pick(A('relic', 'relic', 'equip', 'cons')), odds, ex)
            if it then slots:push({ item = it, special = true }) end
        end
    end
    keep:forEach(function(s)
        if #slots < n then slots:push(s)
        elseif s.special then slots[#slots - 1] = s end -- 战败少一格时，仍保住上波锁定的特价商品
    end)
    slots:forEach(function(s) s.price = itemPrice(s.item, s.special) end)
    return slots
end
function shopOpenNow() return not G.tutorial and G.phase == 'prep' and G.shop ~= nil end
function openShop(res)
    local n = (res and not res.win) and 4 or 5 -- 输掉的波次货架少 1 格（没有特价格）
    G.shop = G.shop or {}
    G.shop.wave = (res and res.wave) or G.wave
    G.shop.slots = rollShelf(n, G.shop.wave)
    G.shop.n = n
    G.shop.refreshN = 0; G.shop.lockUsed = false
    G.shop.free = (res and (res.flawless or res.elite)) and 1 or 0
end
function refreshCost()
    if G.shop.free > 0 then return 0 end
    return max(1, 2 + G.shop.refreshN - (RX().refreshDisc or 0))
end
function refreshShop()
    if G.phase ~= 'prep' then return false end -- 第九次更新：战斗中只能看
    local c = refreshCost()
    if gems() < c then return false end
    addGems(-c)
    if G.shop.free > 0 then G.shop.free = G.shop.free - 1 else G.shop.refreshN = G.shop.refreshN + 1 end
    -- 刷新：重抽所有未锁定、未售出的格子
    local locked = G.shop.slots:filter(function(s) return s.locked and not s.sold end)
    local odds = shopOdds(G.shop.wave or G.wave)
    local ex = {}
    locked:forEach(function(s) ex[s.item.id] = true end)
    G.shop.slots = G.shop.slots:map(function(s)
        if s.locked and not s.sold then return s end
        local kind = s.special and pick(A('relic', 'relic', 'equip', 'cons')) or ITEMS[s.item.id].kind
        local it = rollItem(kind, odds, ex)
        if not it then return { item = s.item, special = s.special, sold = true, price = s.price } end
        local ns = { item = it, special = s.special }
        ns.price = itemPrice(it, s.special)
        return ns
    end)
    return true
end
function toggleLock(i)
    local s = G.shop.slots[i]
    if not s or s.sold then return false end
    if s.locked then s.locked = false; G.shop.lockUsed = false; return true end
    if G.shop.lockUsed then return false end
    s.locked = true; G.shop.lockUsed = true
    return true
end
function buySlot(i)
    local s = G.shop.slots[i]
    if not s or s.sold then return 'gone' end
    if G.phase ~= 'prep' then return 'battle' end
    if gems() < s.price then return 'poor' end
    if slotFull(s.item) then return 'full' end
    if ITEMS[s.item.id].kind == 'relic' and ownsRelic(s.item.id) then return 'gone' end
    if ITEMS[s.item.id].kind == 'equip' and #equipCandidates(s.item) == 0 then return 'nounit' end
    addGems(-s.price)
    s.sold = true
    if s.locked then s.locked = false; G.shop.lockUsed = false end
    return gainItem(s.item), s.item
end
--- 精英波战利品：免费三选一（品质比商店高一档）
function rollLoot(w)
    local odds = shopOdds(w or G.wave) --[[@as table<any, any>]]
    odds = A(odds[0] * 0.5, odds[1] + odds[0] * 0.3, odds[2] + odds[0] * 0.2 + 6, odds[3])
    local ex = {}
    local out = A()
    for kind in of(A('relic', 'equip', 'cons')) do local it = rollItem(kind, odds, ex); if it then out:push(it) end end
    return out
end

-- 新的一局：清空道具栏
local _newGame = newGame
function newGame(...)
    _newGame(...)
    G.relics, G.cons, G.shop, G.legends, G.nextItem = A(), A(), nil, 0, 1
    G.gems = 0 -- 第九次更新：秘银（买道具用的货币，见 mithril.lua）
    G.lockNext, G.diceNext, G.diceSpin = false, false, false
    G.usedPrepCons = {}
    recalcRelics()
    -- 第九次更新：开局就有货架（不再每波自动弹出，顶栏「商店」随时打开）
    openShop(nil)
    G.shop.fresh = false
end

return true
