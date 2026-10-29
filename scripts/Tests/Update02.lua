-- docs/02 七章增量验收。只供真实入口 -validate-test=Tests/Update02.lua。
-- 所有存档/云端/广告均为隔离内存桩；玩法、道具、规则、技能和UI仍走真实模块。
local V = assert(rawget(_G, 'V'), '本脚本只供 -validate-test 使用') --[[@as table<string, any>]]
local N = require('game.env') --[[@as table<string, any>]]
local js = require('game.compat')
local A = js.A
local validation = false
for _, arg in ipairs(GetArguments()) do
    if arg:match('^%-validate%-test=') then validation = true end
end
assert(validation, '禁止在玩家真实运行环境执行验收')

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end
local function restore(t, saved)
    for k in pairs(t) do t[k] = nil end
    for k, v in pairs(saved) do t[k] = v end
end
local function near(a, b, label)
    V.assert(type(a) == 'number' and math.abs(a - b) < 1e-7, label .. '，实际=' .. tostring(a) .. '，期望=' .. tostring(b))
end
local function reset(ch, diff, squad)
    N.newGame(ch or 0, diff or 0, squad)
end
local function unit(cls, star, q)
    local u = N.summon(cls or 'warrior', star or 1, q or 0).nu
    u.affix = { id = 'atk', v = 0, q = 0 }
    return u
end
local function relic(id, cls)
    local it = N.newItem(id)
    if cls then it.cls = cls end
    V.assert(N.gainItem(it) == 'ok', '获得圣物：' .. id)
    return it
end
local function click(id)
    local el = N.PAGE.doc.getElementById(id)
    V.assert(el and not el:isDisabled(), '可点击按钮：' .. id)
    if el and not el:isDisabled() then N.PAGE:click(el) end
    return el
end
local function at(frame, name, test)
    V.atFrame(frame, function()
        local env = copy(N)
        local saved = {}
        for _, key in ipairs({ 'store', 'Cloud', 'Timers', 'Ads', 'UI', 'FX', 'TUT', 'Sound' }) do saved[key] = copy(N[key]) end
        local sdk, api = rawget(_G, 'sdk'), rawget(_G, 'clientCloud')
        local writes = {}
        N.store.data = {}
        N.store.persist = function(data) writes[#writes + 1] = copy(data) end
        N.Cloud.active, N.Cloud.onSynced = false, nil
        N.Timers.list = {}
        rawset(_G, 'sdk', {})
        rawset(_G, 'clientCloud', {})
        local ok, err = xpcall(function()
            N.Ads.cancel()
            N.store.data[N.META_KEY] = N.jsonEncode({ s = 100000, l = {}, v = 3 })
            N.buildSave(); N.loadMeta(); reset()
            N.TUT.stop()
            N.UI.els.home:setHidden(true)
            N.UI.els.overlay:setHidden(true)
            test(writes)
        end, function(e) return tostring(e) end)
        N.Ads.cancel()
        for key, value in pairs(saved) do restore(N[key], value) end
        restore(N, env)
        rawset(_G, 'sdk', sdk)
        rawset(_G, 'clientCloud', api)
        N.UI.els.overlay:setHidden(true)
        N.UI.update()
        print('[Update02Test] ' .. name .. (ok and ' 完成' or (' 异常：' .. tostring(err))))
        V.assert(ok, name .. ' 无异常：' .. tostring(err))
    end)
end

at(15, '七章旧档键与新增进度隔离', function(writes)
    V.assert(#N.CHAPTERS == 10 and #N.CLASS_KEYS == 13 and #N.UPG == 36, '十章/十三兵种/36强化')
    local keys = {}
    N.CHAPTERS:forEach(function(c, i)
        V.assert(not keys[c.key], '七章存档key唯一：' .. c.key)
        keys[c.key] = true
        if i > 0 then V.assert(c.key == 'reel-legion-c' .. (i + 1), '章节key顺序稳定') end
    end)
    V.assert(N.CHAPTERS[3].title == '霜狱冰原' and N.CHAPTERS[4].title == '星陨神殿', '原4冰原/5神殿位置保留')
    V.assert(N.CHAPTERS[5].title == '蚀骨沼泽' and N.CHAPTERS[6].title == '沉没海渊', '新增章节追加为6/7')
    N.store.set('reel-legion-c4-cleared', 5)
    N.store.set('reel-legion-c4-unlock', 3)
    N.store.set('reel-legion-c4-best-0', 12)
    N.store.set('reel-legion-c5-cleared', 2)
    N.store.set('reel-legion-c5-best-1', 14)
    N.buildSave()
    V.assert(N.SAVE[3].cleared == 5 and N.SAVE[3].best[0] == 12, '旧冰原位图/最佳记录不变')
    V.assert(N.SAVE[4].cleared == 2 and N.SAVE[4].best[1] == 14, '旧神殿位图/最佳记录不变')
    V.assert(N.SAVE[5].cleared == 0 and N.SAVE[6].cleared == 0 and not N.chOpen(5), '旧神殿非普通不解锁6，旧进度不复制到6/7')
    local old4, old5 = N.store.get('reel-legion-c4-cleared'), N.store.get('reel-legion-c5-cleared')
    N.clearDiff(5, 0); N.saveBest(5, 0, 6)
    N.Cloud.merge({ ['reel-legion-c6-cleared'] = 4, ['reel-legion-c7-best-0'] = 3 })
    N.buildSave()
    V.assert(N.SAVE[5].cleared == 5 and N.SAVE[5].best[0] == 6 and N.SAVE[6].best[0] == 3, 'c6位或和c7最佳独立合并')
    V.assert(N.store.get('reel-legion-c4-cleared') == old4 and N.store.get('reel-legion-c5-cleared') == old5,
        '新章本地/云合并不污染c4/c5')
    N.loadMeta(); N.saveMeta()
    V.assert(N.jsonDecode(N.store.get(N.META_KEY)).v == 3 and #writes > 0, '沿用v3并仅写隔离内存persist')
end)

at(20, '新兵种普通解锁与八级全员强化', function()
    for _, spec in ipairs({ { 'treant', 1 }, { 'hawk', 2 }, { 'clockwork', 3 } }) do
        local cls, ch = spec[1], spec[2]
        V.assert(N.CLASSES[cls].unlock == ch and not N.classOpen(cls), '新兵种解锁索引：' .. cls)
        N.clearDiff(ch, 1)
        V.assert(not N.classOpen(cls), '只通高难度不解锁兵种：' .. cls)
        N.clearDiff(ch, 0)
        V.assert(N.classOpen(cls), '通关第' .. (ch + 1) .. '章普通解锁：' .. cls)
        N.buildSave()
        V.assert(N.classOpen(cls), '重建存档后仍解锁：' .. cls)
    end
    reset(0, 0, A('treant', 'hawk', 'clockwork'))
    V.assert(N.G.squad:join(',') == 'treant,hawk,clockwork', '已解锁新兵种可组成独立阵容')
    local u = unit('treant')
    local hp, atk = N.unitStats(u).hp, N.unitStats(u).atk
    local spent = 0
    for _, stat in ipairs({ 'hp', 'atk' }) do
        local upg = N.UPG:find(function(x) return x.id == stat end)
        V.assert(upg.max == 8 and #upg.cost == 8, '全员' .. stat .. '八级费用完整')
        for level = 1, 8 do
            local before = N.META.s
            V.assert(N.buyUpg(stat) and N.upgLv(stat) == level and N.META.s == before - upg.cost[level - 1], '全员' .. stat .. '升到' .. level)
            spent = spent + upg.cost[level - 1]
        end
        V.assert(not N.buyUpg(stat), '全员' .. stat .. '满八级不可再买')
    end
    V.assert(N.unitStats(u).hp == hp and N.unitStats(u).atk == atk, '局外购买不追改本局快照')
    reset()
    near(N.G.mx.hp, 0.16, '八级全员生命16%'); near(N.G.mx.atk, 0.16, '八级全员攻击16%')
    V.assert(N.unitStats(u).hp == js.round(hp * 1.16) and N.unitStats(u).atk == js.round(atk * 1.16), '八级新局属性生效')
    N.loadMeta()
    V.assert(N.upgLv('hp') == 8 and N.upgLv('atk') == 8, 'v3存档保留新增5至8级')
    N.resetUpgs(); N.resetUpgs()
    V.assert(N.META.s == 100000 and N.spentSouls() == 0 and spent > 0, '八级退款准确且不可重复领取')
    local p = unit('warrior', 3)
    N.promote(p)
    V.assert(N.PROMOTE_STAR == 2 and p.star == 2 and p.q == 1 and p.pts == N.STAR_PTS[2] and not p.awakenReady,
        '晋升品质+1且从二星起步')
    V.assert(N.STAR_PTS[3] - p.pts == 12, '晋升后再吸收12点经验回三星')
end)

at(25, '圣物装备属性与钩子', function()
    local w, a = unit('warrior'), unit('archer')
    local baseW, baseA = N.unitStats(w), N.unitStats(a)
    relic('warbanner'); relic('amulet'); relic('gambler'); relic('classbadge', 'warrior')
    local st, other = N.unitStats(w), N.unitStats(a)
    V.assert(st.hp == js.round(baseW.hp * 1.15) and st.atk == js.round(baseW.atk * 1.4), '圣物攻击与兵种徽记相加后统一取整')
    V.assert(other.hp == js.round(baseA.hp * 0.95) and other.atk == js.round(baseA.atk * 1.2), '徽记对另两个出战兵种-5%')
    near(st.leech, baseW.leech + 0.06, '血旗吸血'); near(st.dr, baseW.dr + 0.06, '护符减伤')
    V.assert(N.spinCost() == N.SPIN_COST + 1, '赌徒戒指额外拉杆费用')
    reset(); w = unit('warrior'); a = unit('archer')
    local lens = N.newItem('lens')
    V.assert(not N.equipCandidates(lens):includes(w) and N.equipCandidates(lens):includes(a), '远视镜只允许远程装备')
    local eqBase = N.unitStats(a)
    N.equipItem(lens, a)
    near(N.unitStats(a).range, eqBase.range + 15, '远视镜射程')
    N.equipItem(N.newItem('boots'), a)
    near(N.unitStats(a).speed, eqBase.speed * 1.3, '疾风靴速度')
    for _, stat in ipairs({ 'atk', 'hp', 'spd', 'crit', 'leech' }) do
        local gear = N.newItem('gear', 1)
        gear.affix = { id = stat, v = 20, q = 1 }
        N.equipItem(gear, a)
        local got = N.unitStats(a)
        if stat == 'hp' or stat == 'atk' then V.assert(got[stat] == js.round(eqBase[stat] * 1.2), '装备词条：' .. stat)
        elseif stat == 'spd' then near(got.cd, eqBase.cd / 1.2, '装备攻速词条')
        else near(got[stat], eqBase[stat] + 0.2, '装备百分比词条：' .. stat) end
    end
    for _, spec in ipairs({ { 'thornmail', 'thorns', 0.25 }, { 'cross', 'reviveOnce', 0.5 },
        { 'soulblade', 'killEnergy', 10 }, { 'zealbadge', 'skillHaste', 2 }, { 'gauntlet', 'vsShield', 0.3 }, { 'soulgem', 'killAtk', 0.05 } }) do
        N.equipItem(N.newItem(spec[1]), a)
        near(N.playerEnt(a, 0)[spec[2]], spec[3], '装备实体钩子：' .. spec[1])
    end
    reset()
    local chargeBranch, chargeCls = '', ''
    for id, b in pairs(N.BRANCHES) do
        if b.fx and b.fx.chargeMul == 1.25 then chargeBranch, chargeCls = id, b.cls; break end
    end
    V.assert(chargeBranch ~= '', '存在能量获取+25%路线')
    local c = unit(chargeCls, 3, N.BRANCHES[chargeBranch].q)
    N.awaken(c, chargeBranch)
    relic('crystal')
    N.G.cells[0] = 'altar'
    local ent = N.playerEnt(c, 0)
    V.assert(ent.chargeMul <= 1.4, '路线/水晶/祭坛叠加后能量获取上限+40%')
    near(ent.chargeMul, 1.4, '最终实体能量倍率封顶')
    relic('horn'); relic('bloodpact'); relic('purse')
    N.startBattle()
    local b = N.G.battle
    local caster = b.ents:find(function(e) return e.unit == c end)
    V.assert(caster.haste >= 2 and caster.hp == js.round(caster.maxHp * 0.85), '开战钩子：号角与血契')
    b.result = 'win'
    local res = N.finishBattle(false)
    V.assert(res.base == 5 + res.wave + 2, '战后钱袋+2通过finish钩子结算')
end)

at(30, '装备吸收转移换装与出售', function()
    local src, dst = unit('archer'), unit('warrior')
    local boots, lens = N.newItem('boots'), N.newItem('lens')
    N.equipItem(boots, src)
    local before = N.G.gold
    N.absorb(src, dst)
    V.assert(N.findSlot(src) == nil and #N.equipsOf(src) == 0 and N.equipsOf(dst)[1] == boots and N.G.gold == before, '吸收装备转交，不额外出售')
    local src2 = unit('archer')
    N.equipItem(lens, src2)
    local price = N.sellPrice(lens)
    N.absorb(src2, dst)
    V.assert(N.equipsOf(dst)[1] == boots and N.equipsOf(dst)[2] == lens and #N.equipsOf(src2) == 0, '吸收者装备栏未满，来源装备直接转交')
    local replace = N.newItem('thornmail')
    before = N.G.gold
    local slots = N.equipsOf(dst)
    while #slots < N.EQUIP_SLOTS do N.equipItem(N.newItem('whetstone'), dst) end
    -- 第七次更新：换下的装备先进装备仓库（不再直接折金币）；仓库满了才折价卖出
    local stashBefore = #N.stashOf()
    local replaced, fate = N.equipItem(replace, dst, 1)
    V.assert(replaced == boots and N.equipsOf(dst)[1] == replace and N.G.gold == before
        and fate == 'stash' and #N.stashOf() == stashBefore + 1, '装备栏满时换下第 1 件放进仓库，不折金币')
    relic('pawn')
    near(N.sellPrice(replace), math.floor(N.itemBasePrice(replace) * 0.75), '当铺售价75%')
    local merchant = relic('merchant')
    local discount = N.RX().shopDisc
    V.assert(discount == 0.15 and N.hasRelic('merchant'), '商人折扣生效')
    local i = N.G.relics:indexOf(merchant)
    local gemBefore = N.gems()
    local sold = N.sellItem('relic', i)
    V.assert(sold > 0 and N.gems() == gemBefore + sold and not N.hasRelic('merchant') and N.RX().shopDisc == 0, '出售圣物重算效果并准确加秘银')
    V.assert(N.sellItem('relic', 99) == 0, '无效出售不发秘银')
    relic('recycle')
    N.G.form, N.G.bench = js.filled(N.FORM_N, nil), js.filled(N.BENCH_N, nil)
    local v = { cls = 'warrior', star = 1, q = 0, pts = 0, equips = { N.newItem('boots') } }
    local eqPrice = N.sellPrice(v.equips[1])
    local gem0 = N.gems()
    before = N.G.gold
    local result = N.feedAway(v)
    V.assert(result.sold and result.coins == 4 and #N.equipsOf(v) == 0 and N.G.gold == before + 4
        and N.gems() == gem0 + eqPrice, '无法吸收时回收炉4金、装备折成秘银且不重复结算')
end)

at(35, '商店货架锁定刷新购买边界', function()
    unit('warrior'); unit('archer')
    N.G.wave, N.G.gold, N.G.gems = 3, 100, 100
    relic('purse')
    N.openShop({ win = true, flawless = true })
    -- items2 的 openShop 包装每波再送 1 次免费刷新，所以无阵亡胜利共有 2 次
    V.assert(#N.G.shop.slots == 5 and N.G.shop.free == 2 and N.refreshCost() == 0, '胜利五格货架，无阵亡共送两次免费刷新')
    local seen = {}
    N.G.shop.slots:forEach(function(s)
        if s.item.id ~= 'gear' then V.assert(not seen[s.item.id], '同次刷新非随机词条装备ID不重复'); seen[s.item.id] = true end
        V.assert(s.item.id ~= 'purse', '已持有圣物不再出现')
    end)
    local locked = N.G.shop.slots[0]
    V.assert(N.toggleLock(0) and not N.toggleLock(1), '每波最多免费锁定一件')
    local gold = N.gems()
    V.assert(N.refreshShop() and N.gems() == gold and N.G.shop.slots[0] == locked and locked.locked, '免费刷新保留锁定对象')
    V.assert(N.refreshShop() and N.gems() == gold and N.refreshCost() == 2, '第二次免费刷新仍然免费，之后开始计费')
    V.assert(N.refreshShop() and N.gems() == gold - 2 and N.refreshCost() == 3, '付费刷新每次+1（秘银）')
    N.G.wave = 4
    N.openShop({ win = false })
    V.assert(#N.G.shop.slots == 4 and N.G.shop.slots:includes(locked) and locked.kept and not locked.locked,
        '失守四格且跨波保留锁定商品，下一波释放锁')
    -- 每波 openShop 都会送免费刷新（items2 包装 +1），所以新一波刷新价仍是 0
    V.assert(N.G.shop.free == 1 and N.refreshCost() == 0 and not N.G.shop.lockUsed, '下一波免费刷新与锁额度重置')
    local it = N.newItem('amulet')
    N.G.shop.slots = A({ item = it, price = 6 })
    N.G.gems = 5
    V.assert(N.buySlot(0) == 'poor' and N.gems() == 5 and not N.G.shop.slots[0].sold, '秘银不足不扣款不售出')
    N.G.gems = 6
    V.assert(N.buySlot(0) == 'ok' and N.gems() == 0 and N.hasRelic('amulet'), '刚好足额购买成功')
    V.assert(N.buySlot(0) == 'gone' and N.gems() == 0 and N.buySlot(99) == 'gone', '重复/无效购买不扣款不重复给道具')
    while #N.G.relics < N.RELIC_SLOTS do N.G.relics:push(N.newItem('bank')) end
    N.G.shop.slots = A({ item = N.newItem('awl'), price = 10 })
    N.G.gems = 50
    -- 第十五次更新：圣物栏满了也能买，付款后由界面选「放进仓库」或「换下一件」
    local rf, rit = N.buySlot(0)
    V.assert(rf == 'relicfull' and rit and rit.id == 'awl' and N.gems() == 40 and N.G.shop.slots[0].sold and #N.G.relics == N.RELIC_SLOTS, '圣物栏满购买返回 relicfull 且不超出栏位')
    V.assert(N.placeNewRelic(rit, 'stash') == 'stash' and N.ownsRelic('awl') and not N.hasRelic('awl'), '满栏圣物可以放进仓库（不生效）')
    N.G.gems = 50
    N.G.relics = A(); N.recalcRelics()
    N.G.form, N.G.bench = js.filled(N.FORM_N, nil), js.filled(N.BENCH_N, nil)
    N.G.shop.slots = A({ item = N.newItem('lens'), price = 10 })
    V.assert(N.buySlot(0) == 'nounit' and N.gems() == 50, '无可装备单位不扣款')
    local ranged = unit('archer')
    local result, eq = N.buySlot(0)
    V.assert(result == 'equip' and eq.id == 'lens' and N.gems() == 40 and N.G.shop.slots[0].sold, '装备购买返回选择对象且只扣一次')
    N.equipItem(eq, ranged)
    V.assert(N.equipsOf(ranged)[1] == eq, '购买装备可交付真实单位')
    N.G.gems, N.G.shop.free = 0, 0
    V.assert(not N.refreshShop() and N.gems() == 0, '刷新不足不产生负秘银')
    V.assert(N.shopOdds(3)[3] == 0 and N.shopOdds(10)[2] > 0, '前期无传说、10波起史诗')
    N.G.legends = N.LEGEND_CAP
    V.assert(N.shopOdds(N.G.maxWave - 1)[3] == 0, '达到本局传说上限不再出传说')
    reset()
    N.G.wave = N.G.maxWave - 1
    local special = { item = N.newItem('healpotion'), special = true, locked = true, price = 4 }
    N.G.shop = { slots = A(special) }
    N.openShop({ win = false, wave = N.G.wave })
    V.assert(#N.G.shop.slots == 4 and N.G.shop.slots:includes(special), '战败四格先为锁定特价保留位置')
    local shown = N.G.shop.slots:filter(function(s) return s.item.rar >= 3 end)
    V.assert(N.legendCount() == #shown and N.legendCount() <= 2, '传说按实际出现计数，不计生成后丢弃的商品')
end)

at(40, '凤凰羽与消耗品每场限制', function()
    local u, ally = unit('warrior'), unit('archer')
    N.G.cons:push(N.newItem('phoenix'), N.newItem('healpotion'), N.newItem('healpotion'))
    V.assert(not N.canUseCons(N.G.cons[0]) and not N.useCons(0) and #N.G.cons == 3, '凤凰羽不能手动消费')
    N.startBattle()
    local b = N.G.battle
    local ps = b.ents:filter(function(e) return e.side == 'p' end)
    ps:forEach(function(e) e.hp = e.maxHp * 0.1 end)
    V.assert(N.useCons(1) and #N.G.cons == 2 and b.usedCons.healpotion, '战斗药剂消费一次且标记已使用')
    local health = ps[0].hp
    V.assert(not N.useCons(1) and #N.G.cons == 2 and ps[0].hp == health, '同种药剂每场只用一次')
    ps:forEach(function(e) e.dead = true; e.hp = 0 end)
    local lives, wave = N.G.lives, N.G.wave
    N.stepBattle(0)
    V.assert(not b.over and N.G.lives == lives and N.G.wave == wave and #N.G.cons == 1, '全军覆没凤凰羽自动消费，不扣生命不跳波')
    ps:forEach(function(e) V.assert(not e.dead and e.hp == js.round(e.maxHp * 0.4), '凤凰羽全员40%生命复活') end)
    V.assert(u ~= ally and not N.G.cons:some(function(it) return it.id == 'phoenix' end), '凤凰羽触发后移除')
    ps:forEach(function(e) e.dead = true; e.hp = 0 end)
    N.stepBattle(0)
    V.assert(b.over and b.result == 'lose', '再次覆灭不会无羽复活')
    N.finishBattle(false)
    V.assert(N.G.lives == lives - 1, '真正失守才扣一生命')
end)

at(45, '封印格放置拖拽顶替与召唤哨', function()
    N.G.cells = { [5] = 'seal', [6] = 'seal' }
    local u = unit('archer')
    local from = N.findSlot(u)
    V.assert(from and not N.isSealed(from.i), '自动布阵跳过封印格')
    N.dropAt(u, from, { t = 'f', i = 5 })
    V.assert(N.getSlot(from) == u and N.G.form[5] == nil, '拖放封印格不移走源单位')
    for i = 0, N.FORM_N - 1 do
        if not N.isSealed(i) and not N.G.form[i] then unit('warrior', 3, 0) end
    end
    while #N.G.bench:compact() < N.BENCH_N do unit('warrior', 3, 0) end
    local summoned = N.summon('mage', 1, 1)
    V.assert(summoned ~= nil and N.G.form[5] == nil and N.G.form[6] == nil, '满员高品质召唤不顶替进封印格')
    N.summonSuper('warrior')
    V.assert(N.G.form[5] == nil and N.G.form[6] == nil, '超凡顶替也不占封印格')
    reset()
    for i = 0, N.FORM_N - 1 do N.G.cells[i] = 'seal' end
    local benched = unit('warrior')
    V.assert(N.findSlot(benched).t == 'b', '全封印时自动布阵退到备战席')
    N.startBattle()
    V.assert(N.freeFormSlot(N.G.battle) == nil, '全封印时召唤哨没有可用阵地格')
    local whistle = N.newItem('whistle')
    N.G.cons:push(whistle)
    V.assert(not N.canUseCons(whistle) and not N.useCons(0) and #N.G.cons == 1, '无空位召唤哨不消费')
    N.G.cells[0] = nil
    V.assert(N.freeFormSlot(N.G.battle) == 0 and N.useCons(0), '开放一格后召唤哨可用')
    V.assert(N.G.battle.whistleSlots[0] and N.G.form[0] == nil, '临时单位只占本场哨格，不污染永久阵型')
    local guest = N.G.battle.ents:find(function(e) return e.side == 'p' and e.temp end)
    local p = N.fPos(0)
    V.assert(guest and guest.x == p.x and guest.y == p.y and not N.isSealed(0), '召唤哨实际实体落在唯一未封印格')
end)

at(50, '七章规则与边界', function()
    reset(0, 3)
    local baseSoul = N.soulPerWave(0, 3)
    local otherSoul = N.soulPerWave(1, 0)
    N.G.soulMul = N.AFFIX_SOUL
    V.assert(N.soulPerWave(0, 3) == js.round(baseSoul * N.AFFIX_SOUL), '炼狱限制只加成本局军魂')
    V.assert(N.soulPerWave(1, 0) == otherSoul, '其他章节军魂与旧档回填不继承当前局限制倍率')
    for c = 0, 6 do
        reset(c)
        V.assert(type(N.rulesHTML(c, true)) == 'string', '七章规则可渲染：' .. c)
        if c == 3 or c == 4 then V.assert(N.curCh().key == 'reel-legion-c' .. (c + 1), '旧4/5不套新沼泽海渊规则') end
    end
    reset(1)
    unit('warrior'); N.startBattle()
    N.G.battle.hazT = 0.01
    N.stepBattle(0.02)
    V.assert(#N.G.battle.fields:filter(function(f) return f.kind == 'fissure' and f.both end) == 2, '熔火12秒周期地裂通过step钩子生成两条')
    reset(2)
    unit('mage'); N.startBattle()
    local b = N.G.battle
    local f = b.fields:find(function(field) return field.kind == 'erosion' end)
    V.assert(f ~= nil, '虚空每波生成侵蚀格')
    local e = b.ents:find(function(ent) return ent.side == 'p' end)
    e.x, e.y, e.energy = f.x + 13, f.y + 16, 50
    N.stepHazard(b, f, 0.5)
    near(e.energy, 45, '侵蚀包含格子矩形边界每秒10能量')
    e.x, e.energy = f.x + 13.01, 50
    N.stepHazard(b, f, 0.5)
    near(e.energy, 50, '侵蚀边界外不吸能')
    reset(5)
    local counts = {}
    for _, kind in pairs(N.G.cells) do counts[kind] = (counts[kind] or 0) + 1 end
    V.assert(counts.swamp == 2 and counts.altar == 1, '新增第六章两沼泽一祭坛')
    unit('warrior'); N.startBattle()
    near(N.G.battle.healMul, 0.75, '新六章毒雾治疗-25%')
    near(N.G.battle.burnMul, 1.3, '新六章灼烧+30%')
    reset(6)
    counts = {}
    for _, kind in pairs(N.G.cells) do counts[kind] = (counts[kind] or 0) + 1 end
    V.assert(counts.seal == 2 and counts.high == 1, '新增第七章两封印一高地')
    local ranged = unit('archer')
    N.startBattle()
    b = N.G.battle
    local ent = b.ents:find(function(o) return o.unit == ranged end)
    V.assert(b.tide and b.tide.high, '第七章开战涨潮')
    local baseRange = ent.baseRange
    near(ent.range, js.round(baseRange * 0.75), '涨潮射程-25%')
    b.tide.t = 0.01
    N.stepBattle(0.02)
    V.assert(not b.tide.high and ent.range == baseRange, '潮汐换相恢复原射程不累乘')
end)

-- 每个兵种的基础、全部转职及超凡，均从真实castSkill入口执行；
-- 不以“存在技能表”代替施法验证，也不重载任何产品模块。
for index, cls in ipairs({ 'warrior', 'archer', 'mage', 'tiger', 'bear', 'flytrap', 'sunflower', 'treant', 'hawk', 'clockwork' }) do
    at(55 + index * 2, '十兵种全技能 ' .. cls, function()
        local routes = { { q = 0 } }
        N.CLASS_BRANCHES[cls]:forEach(function(list, q)
            list:forEach(function(branch) routes[#routes + 1] = { q = q, branch = branch } end)
        end)
        routes[#routes + 1] = { q = N.Q_SUP, branch = N.SUPER_OF[cls], sup = true }
        local casts = 0
        for _, route in ipairs(routes) do
            reset()
            local u = route.sup and N.summonSuper(cls).nu or unit(cls, route.branch and 3 or 1, route.q)
            if route.branch and not route.sup then N.awaken(u, route.branch) end
            unit('warrior'); unit('archer')
            N.startBattle()
            local b = N.G.battle
            local caster = b.ents:find(function(e) return e.unit == u end)
            local target = b.ents:find(function(e) return e.side == 'e' end)
            local expected = route.branch and N.BRANCHES[route.branch].skill or N.CLASS_SKILL[cls]
            V.assert(caster.skill == expected and N.SKILLS[expected] ~= nil, '实体携带正确技能：' .. (route.branch or cls))
            b.ents:forEach(function(e)
                e.cdLeft, e.energy, e.crit = 999, 0, 0
                e.x, e.y = e.side == 'p' and 90 or 110, 72
                e.hp = e.maxHp * 0.5
                if e.side == 'e' then e.hp, e.maxHp = 100000, 100000 end
            end)
            local original, seen = N.FX.skill, 0
            N.FX.skill = function(e, name)
                if e == caster and (expected == 'elements' or name == N.SKILLS[expected].name) then seen = seen + 1 end
                return original(e, name)
            end
            local ok, err = pcall(N.castSkill, b, caster, target)
            N.FX.skill = original
            V.assert(ok and seen > 0, '真实技能入口施法并显示技能名：' .. expected .. ' ' .. tostring(err))
            if ok then
                for _ = 1, 3 do N.stepBattle(0.02) end
                V.assert(N.G.battle == b and b.t > 0, '施法后投射物/场地/step链继续推进：' .. expected)
                casts = casts + 1
            end
        end
        V.assert(casts == #routes and casts >= 9, cls .. '基础+七转职+超凡全部调用成功')
    end)
end

at(80, '新兵种机制可观察效果', function()
    local treant, hawk, mech = unit('treant'), unit('hawk'), unit('clockwork')
    N.startBattle()
    local b = N.G.battle
    local t = b.ents:find(function(e) return e.unit == treant end)
    local h = b.ents:find(function(e) return e.unit == hawk end)
    local m = b.ents:find(function(e) return e.unit == mech end)
    local foe = b.ents:find(function(e) return e.side == 'e' end)
    t.x, t.y, h.x, h.y, m.x, m.y, foe.x, foe.y = 90, 72, 95, 72, 100, 72, 110, 72
    N.castSkill(b, t, foe)
    V.assert(t.shield == t.maxHp * 0.25 and t.hot and foe.target == t, '古树生根：25%盾+持续回血+嘲讽')
    N.castSkill(b, h, foe)
    local storm = b.fields:find(function(f) return f.kind == 'storm' and f.src == h end)
    V.assert(storm and storm.t == 4, '雷鹰雷暴生成4秒电场')
    foe.hp, foe.maxHp = 100000, 100000
    local hp = foe.hp
    N.stepHazard(b, storm, 0.51)
    V.assert(foe.hp < hp, '雷鹰电场通过真实hazard产生伤害')
    N.castSkill(b, m, foe)
    V.assert(m.mech and m.overSelf and m.overT == 4 and t.overT == 4 and N.OVERLOAD_SPD == 1.6, '机兵过载给自身与邻友+60%攻速')
    N.applyBurn(m, foe, 3, 10); N.applyBleed(m, foe, 3, 10); N.addPoison(m, foe, 1)
    V.assert(not m.burn and not m.bleed and not m.poison, '机械免疫灼烧/流血/中毒')
    m.overT = 0.01
    N.stepBattle(0.02)
    V.assert(not m.overSelf and m.stun > 0, '过载结束自身眩晕')
end)

at(85, '七章真实首领波含旧首领', function()
    local old = { [0] = 'boss', [1] = 'colossus', [2] = 'voidlord', [3] = 'frostqueen', [4] = 'astralking' }
    local newTypes = {}
    for c = 0, 6 do
        reset(c)
        local u = N.summonSuper('warrior').nu
        N.G.wave = N.G.maxWave
        local lineup = N.currentLineup()
        V.assert(lineup:some(function(e) return N.ENEMIES[e.type].big end), '第' .. (c + 1) .. '章最终波有首领')
        N.startBattle()
        local b = N.G.battle
        local boss = b.ents:find(function(e) return e.big end)
        local target = b.ents:find(function(e) return e.unit == u end)
        V.assert(boss and boss.side == 'e' and N.G.phase == 'battle', '第' .. (c + 1) .. '章真实生成首领')
        if c <= 4 then V.assert(boss.type == old[c], '旧五章首领不被增量替换：' .. old[c])
        else newTypes[#newTypes + 1] = boss.type end
        target.maxHp, target.hp, target.atk, target.cdLeft = 100000, 100000, 1, 999
        if boss.skill then N.castSkill(b, boss, target) end
        for _ = 1, 10 do N.stepBattle(0.05) end
        V.assert(b.t >= 0.49 and target.hp > 0, '第' .. (c + 1) .. '章首领施法后step链正常')
        if c == 5 then
            V.assert(boss.type == 'rotmother' and boss.rphases, '六章腐母独立阶段机制')
            boss.hp = boss.maxHp * 0.59
            N.stepBattle(0)
            V.assert(boss.ph1 and boss.grown, '腐母60%吞噬阶段真实触发')
            boss.hp = boss.maxHp * 0.29
            N.stepBattle(0)
            V.assert(boss.ph2 and target.infect and target.infect.t == 8, '腐母30%感染全员阶段真实触发')
        elseif c == 6 then
            V.assert(boss.type == 'leviathan' and boss.levCycle, '七章利维坦独立潜浮机制')
            boss.levT = 0
            N.stepBattle(0)
            V.assert(boss.levState == 'down' and boss.immune and boss.untargetable and #boss.tents == 3,
                '利维坦潜水无法选中并生成三触手')
            local x, y, energy = boss.x, boss.y, boss.energy
            boss.cdLeft = 0
            N.stepBattle(0.1)
            V.assert(not boss.moving and not boss.ready and boss.x == x and boss.y == y and boss.energy == energy,
                '利维坦潜水期间不移动、不攻击或积蓄普攻能量')
            boss.tents:forEach(function(t) t.hp = 0; t.dead = true end)
            N.stepBattle(0)
            V.assert(boss.levState == 'up' and not boss.immune and not boss.untargetable and boss.surfaceT == 4,
                '打断三触手提前浮出，4秒易伤窗口')
        end
        b.result = 'win'
        local result = N.finishBattle(false)
        V.assert(result.win and N.G.phase == 'victory' and N.G.battle == nil and (N.SAVE[c].cleared & 1) ~= 0,
            '第' .. (c + 1) .. '章首领胜利完整结算并独立通关')
    end
    V.assert(#newTypes == 2 and newTypes[1] ~= newTypes[2], '新6/7拥有不同独立首领')
end)

at(90, '结果继续后精英奖励到商店仅一次', function()
    unit('warrior')
    N.G.wave = 5
    N.startBattle()
    N.G.battle.result = 'win'
    local res = N.finishBattle(false)
    V.assert(res.elite and N.G.phase == 'prep', '真实第5波胜利标记精英')
    local calls, continuation = { loot = 0, shop = 0, open = 0 }, {}
    local showLoot, showShop, openShop = N.UI.showLoot, N.UI.showShop, N.openShop
    N.UI.showLoot = function(after) calls.loot = calls.loot + 1; continuation.after = after end
    N.UI.showShop = function() calls.shop = calls.shop + 1 end
    N.openShop = function(r) calls.open = calls.open + 1; return openShop(r) end
    N.UI.showResult(res)
    V.assert(calls.loot == 0 and calls.shop == 0, '展示结果不提前打开精英/商店')
    local button = click('mBtn')
    V.assert(calls.loot == 1, '只点击继续后进入精英三选一')
    N.UI.afterBattle(res)
    if button and button.onclick then button.onclick() end
    V.assert(calls.loot == 1, '重复继续/afterBattle不重复精英奖励')
    V.assert(calls.shop == 0, '精英战利品不再自动弹商店')
    N.UI.showLoot, N.UI.showShop, N.openShop = showLoot, showShop, openShop
    -- 第九次更新：商店开局就有货架，战后只换货不弹窗
    reset(); unit('warrior'); N.G.wave = 1
    local shelf = N.G.shop and N.G.shop.slots
    N.startBattle(); N.G.battle.result = 'win'
    local first = N.finishBattle(false)
    N.UI.afterBattle(first)
    V.assert(N.G.shop ~= nil and N.G.shop.slots ~= shelf and N.G.shop.fresh, '战后自动换货并标记有新货，不弹商店')
    N.G.wave, N.G.lives = 2, 1
    N.startBattle(); N.G.battle.result = 'lose'
    local revive = N.finishBattle(true)
    local revShelf = N.G.shop and N.G.shop.slots
    N.UI.afterBattle(revive)
    V.assert(revive.revivable and N.G.shop and N.G.shop.slots == revShelf, '待广告复活结果不再换货/不打开商店')
end)

V.atFrame(100, function() V.finish() end)
