-- imported_main 真实入口验收；仅供 -validate-test=Tests/Expansion.lua 使用。
-- 不重载模块、不写文件；SDK/云 API 用桩，业务逻辑仍走真实函数。
local V = assert(rawget(_G, 'V'), '本脚本只供 -validate-test 使用') --[[@as table<string, any>]]
local N = require('game.env') --[[@as table<string, any>]]
local js = require('game.compat')
local validation = false
for _, arg in ipairs(GetArguments()) do
    if arg:match('^%-validate%-test=') then validation = true end
end
assert(validation, '必须通过 -validate-test 启动，禁止接触玩家真实档')

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end
local function restore(t, saved)
    for k in pairs(t) do t[k] = nil end
    for k, v in pairs(saved) do t[k] = v end
end
local function click(id)
    local el = N.PAGE.doc.getElementById(id)
    local usable = el ~= nil and not el:isDisabled()
    V.assert(usable, '可点击按钮：' .. id)
    if usable then N.PAGE:click(el) end
    return el
end
local function setAd(fn) rawset(_G, 'sdk', { ShowRewardVideoAd = fn }) end
local function seed(meta)
    N.store.data = { [N.META_KEY] = N.jsonEncode(meta) }
    N.buildSave()
    N.loadMeta()
    N.newGame()
end
local function storedMeta() return N.jsonDecode(N.store.get(N.META_KEY)) end

-- 每组独立内存档和时钟；无论断言/业务抛错，都先撤销桩再报告。
local function at(frame, name, test)
    V.atFrame(frame, function()
        V.assert(N.PAGE ~= nil, '真实入口已初始化页面')
        if not N.PAGE then V.finish(); return end
        local data, persist = N.store.data, N.store.persist
        local meta, save, game = N.META, N.SAVE, N.G
        local cloud, timers, ads = copy(N.Cloud), copy(N.Timers), copy(N.Ads)
        local ui, fx, tut = copy(N.UI), copy(N.FX), copy(N.TUT)
        local sdk, api, c45Cast = rawget(_G, 'sdk'), rawget(_G, 'clientCloud'), N.c45Cast
        local writes = {}
        N.store.data = {}
        N.store.persist = function(values) writes[#writes + 1] = copy(values) end
        N.Cloud.active, N.Cloud.onSynced = false, nil
        rawset(_G, 'clientCloud', {}) -- 即使测试误开云端，也不会接触真实 API。
        N.Timers.list = {}
        local ok, err = xpcall(function()
            V.assert(not N.Ads.busy, '组间没有遗留广告锁')
            N.Ads.cancel()
            N.Ads.available = function() return true end
            seed({ s = 0, l = {}, v = 3 })
            N.TUT.stop()
            N.UI.els.home:setHidden(true)
            N.UI.els.overlay:setHidden(true)
            test(writes)
        end, function(e) return tostring(e) end)
        N.Ads.cancel()
        restore(N.Ads, ads)
        restore(N.Cloud, cloud)
        restore(N.Timers, timers)
        restore(N.UI, ui)
        restore(N.FX, fx)
        restore(N.TUT, tut)
        N.c45Cast = c45Cast
        N.META, N.SAVE, N.G = meta, save, game
        N.store.data, N.store.persist = data, persist
        rawset(_G, 'sdk', sdk)
        rawset(_G, 'clientCloud', api)
        N.UI.els.overlay:setHidden(true)
        N.UI.update()
        print('[ExpansionTest] ' .. name .. (ok and ' 完成' or (' 异常：' .. tostring(err))))
        V.assert(ok, name .. ' 无异常：' .. tostring(err))
    end)
end

at(10, '十章与强化表', function()
    V.assert(#N.CHAPTERS == 10, '真实入口加载十章（含第六次更新新增 8/9/10 章）')
    V.assert(#N.UPG == 36, '真实入口加载 36 项强化')
    V.assert(#N.CLASS_KEYS == 13, '加载十三兵种')
    local ids, count = {}, 0
    N.UPG:forEach(function(u)
        V.assert(not ids[u.id], '强化 ID 唯一：' .. u.id)
        ids[u.id] = true
        if u.cls then
            count = count + 1
            V.assert(u.id == u.stat .. '_' .. u.cls and u.max == 5 and u.scale == 0.01,
                u.id .. ' 每级 1%，上限五级')
            V.assert(u.cost:join(',') == '60,100,150,220,300', u.id .. ' 五级费用')
        end
    end)
    V.assert(count == 26 and #N.UPG - count == 10, '十三兵种各有生命、攻击强化，十项通用不重复')
    for _, stat in ipairs({ 'hp', 'atk' }) do
        local u = N.UPG:find(function(x) return x.id == stat end)
        V.assert(u and u.max == 8 and #u.cost == 8 and u.scale == 0.02, stat .. ' 全员强化八级，每级2%')
    end
    local cheap = N.UPG:find(function(u) return u.id == 'cheap' end)
    V.assert(cheap.cost:join(',') == '450,1000', '集点价格为 450/1000')
    V.assert(N.CHEAP_EVERY[1] == 5 and N.CHEAP_EVERY[2] == 4, '新版集点门槛 5/4')
    for c = 3, 4 do -- 游戏兼容数组为零起始，不是原生 Lua 序列。
        local chapter = N.CHAPTERS[c]
        V.assert(chapter.diffs:map(function(d) return d.waves end):join(',') == '12,14,16,18',
            chapter.name .. ' 四难度波数')
        V.assert(type(chapter.boss) == 'function', chapter.name .. ' 已装配首领钩子')
    end
    V.assert(N.SOUL_CH[3] == 2 and N.SOUL_CH[4] == 2.4, '新章节军魂系数 2/2.4')
    -- 第六次更新新增三章：军魂系数延续本工程递增曲线
    V.assert(N.SOUL_CH[7] == 3.6 and N.SOUL_CH[8] == 4.0 and N.SOUL_CH[9] == 4.4, '第八～十章军魂系数 3.6/4.0/4.4')
end)

at(20, '章节解锁与位或', function()
    V.assert(N.chOpen(0) and not N.chOpen(1) and not N.chOpen(4), '新档只开放第一章')
    N.clearDiff(0, 1)
    V.assert(not N.chOpen(1), '只通更高难度不能代替普通解锁下一章')
    for c = 0, #N.CHAPTERS - 2 do
        V.assert(not N.chOpen(c + 1), '通关前下一章锁定：' .. (c + 2))
        local news = N.clearDiff(c, 0)
        V.assert(N.chOpen(c + 1), '普通通关解锁下一章：' .. (c + 2))
        V.assert(news:some(function(n) return n.c == c + 1 and n.d == 0 end), '返回新章节解锁信息')
        V.assert(N.SAVE[c].unlock >= 1, '同时解锁本章下一难度')
    end
    N.buildSave()
    V.assert(N.chOpen(4) and N.chOpen(6), '重读后第五、七章仍开放')
    N.CHAPTERS:forEach(function(chapter)
        N.store.set(chapter.key .. '-cleared', 3)
        N.Cloud.merge({ [chapter.key .. '-cleared'] = 5 })
        V.assert(tonumber(N.store.get(chapter.key .. '-cleared')) == 7, chapter.name .. ' cleared 3 | 5 = 7')
    end)
    N.buildSave()
    V.assert(N.SAVE:every(function(s) return s.cleared == 7 and s.unlock == 3 end), '位或后重建全部难度解锁')
end)

at(25, '集点二级1000与免费拉杆', function()
    seed({ s = 1450, l = {}, v = 3 })
    V.assert(N.buyUpg('cheap') and N.META.s == 1000, '一级消耗450，门槛5次')
    N.newGame()
    V.assert(N.stampGoal() == 5, '一级新局使用5次集点')
    N.META.s = 999
    V.assert(not N.buyUpg('cheap') and N.upgLv('cheap') == 1 and N.META.s == 999, '二级不足1000不扣款不升级')
    N.META.s = 1000
    V.assert(N.buyUpg('cheap') and N.META.s == 0 and N.upgLv('cheap') == 2, '二级恰好消耗1000')
    V.assert(N.stampGoal() == 5, '购买不修改进行中一局的强化快照')
    N.newGame()
    V.assert(N.stampGoal() == 4, '二级新局每4次付费送1次')
    N.G.gold, N.G.freeSpins, N.G.paidSpins = 1000, 0, 0
    local gold = N.G.gold
    for i = 1, 3 do
        V.assert(not N.paySpin() and N.G.paidSpins == i and N.G.freeSpins == 0, '前3次只累计付费集点')
    end
    V.assert(N.paySpin() and N.G.freeSpins == 1 and N.G.paidSpins == 0, '第4次送1次免费并清零集点')
    V.assert(N.G.gold == gold - 4 * N.spinCost(), '4次付费拉杆正确扣金币')
    local before = N.G.gold
    V.assert(not N.paySpin() and N.G.gold == before and N.G.freeSpins == 0 and N.G.paidSpins == 0,
        '赠送拉杆不扣金币也不重复集点')
    V.assert(N.META.cheapSpent == 1450 and N.spentSouls() == 1450, '新购买记录实际投入1450')
    N.loadMeta()
    V.assert(N.upgLv('cheap') == 2 and N.META.cheapSpent == 1450, '保存重读保留二级与实际投入')
    N.resetUpgs(); N.resetUpgs()
    V.assert(N.META.s == 1450 and N.upgLv('cheap') == 0, '新档重置只退实际投入一次')
    seed({ s = 10, l = { cheap = 2 }, v = 3 })
    V.assert(N.upgLv('cheap') == 2 and N.META.cheapSpent == 1350, '原价二级老档保留等级，投入按450+900')
    N.resetUpgs()
    V.assert(N.META.s == 1360, '老档重置不因涨价额外获利100')
    seed({ s = 0, l = {}, v = 3 })
    N.Cloud.merge({ [N.META_KEY] = N.jsonEncode({ s = 0, l = { cheap = 2 }, cheapSpent = 1450, v = 3 }) })
    V.assert(N.upgLv('cheap') == 2 and N.META.cheapSpent == 1450, '云端高等级携带实际购买投入')
    N.resetUpgs()
    V.assert(N.META.s == 1450, '云端新版二级按实际投入退款')
end)

for level, refund in ipairs({ 250, 650 }) do
    at(20 + level * 10, '本地 v2 集点退款 ' .. level, function(writes)
        seed({ s = 100, l = { cheap = level, gold = 2, hp = 1 }, v = 2 })
        V.assert(N.META.s == 100 + refund and N.upgLv('cheap') == 0, '旧集点退款并清零：' .. refund)
        V.assert(N.META.refund == refund and N.upgLv('gold') == 2 and N.upgLv('hp') == 1, '退款数正确且保留其他强化')
        local saved = storedMeta()
        V.assert(saved.v == 3 and saved.l.cheap == 0 and saved.s == 100 + refund, '迁移持久化为 v3')
        V.assert(#writes > 0 and writes[#writes][N.META_KEY] == N.store.get(N.META_KEY), 'persist 收到隔离档的 v3 内容')
        N.loadMeta(); N.loadMeta()
        V.assert(N.META.s == 100 + refund and N.META.refund == 0, '重复 load 不再退款')
        N.Cloud.merge({ [N.META_KEY] = N.jsonEncode({ s = 100, l = { cheap = level, atk = 2 }, v = 2 }) })
        N.Cloud.merge({ [N.META_KEY] = N.jsonEncode({ s = 100, l = { cheap = level }, v = 2 }) })
        V.assert(N.META.s == 100 + refund and N.upgLv('cheap') == 0, '本地及同一云旧档合并只退款一次、不灌回集点')
        V.assert(N.upgLv('atk') == 2, '云端其他强化照常合并')
        N.loadMeta()
        V.assert(N.META.s == 100 + refund and storedMeta().v == 3, '合并后再 load 仍不重复退款')
    end)
end

at(50, '云旧档独立迁移', function()
    for level, refund in ipairs({ 250, 650 }) do
        seed({ s = 0, l = {}, v = 3 })
        local remote = { [N.META_KEY] = N.jsonEncode({ s = 100, l = { cheap = level, gold = 3 }, v = 2 }) }
        N.Cloud.merge(remote)
        V.assert(N.META.s == 100 + refund and N.upgLv('cheap') == 0, '只有云端旧档也退款并清零')
        V.assert(storedMeta().v == 3 and storedMeta().s == 100 + refund, '云端迁移结果持久化 v3')
        N.Cloud.merge(remote); N.loadMeta(); N.Cloud.merge(remote)
        V.assert(N.META.s == 100 + refund and N.upgLv('cheap') == 0, '重复云合并及 load 只退款一次')
        -- 新版重新购买的等级不能被旧档清零，也不能从旧档恢复到更高等级。
        N.META.s = 2000
        V.assert(N.buyUpg('cheap'), '允许按新版价格重买集点')
        N.Cloud.merge(remote)
        V.assert(N.upgLv('cheap') == 1 and N.META.s == 1550, '旧云档不覆盖新版重买等级或增加退款')
    end
end)

-- 从真实召唤/晋升/转职单位算未取整基础值，避免用已取整属性反推百分比。
local function expected(u, stat, bonus)
    local c, q = N.CLASSES[u.cls], N.QUAL[u.q]
    local b = u.branch and N.BRANCHES[u.branch]
    local multiplier = N.STAR_MULT[u.star] * q.base * (b and q.awaken or 1)
    local raw = c[stat] * multiplier * (1 + (b and b.mods and b.mods[stat] or 0))
    if u.affix.id == stat then raw = raw * (1 + u.affix.v / 100) end
    return js.round(raw * (1 + bonus))
end

for index, cls in ipairs({ 'warrior', 'archer', 'mage', 'tiger', 'bear', 'flytrap', 'sunflower', 'treant', 'hawk', 'clockwork' }) do
    local frame = index <= 7 and (50 + index * 10) or (120 + (index - 7) * 3)
    at(frame, '兵种加成 ' .. cls, function()
        seed({ s = 10000, l = { hp = 2, atk = 2 }, v = 3 })
        local units = { N.summon(cls, 1, 0).nu }
        local promoted = N.summon(cls, 3, 0).nu
        N.promote(promoted)
        units[#units + 1] = promoted
        N.CLASS_BRANCHES[cls]:forEach(function(routes, q)
            routes:forEach(function(branch)
                local u = N.summon(cls, 3, q).nu
                N.awaken(u, branch)
                units[#units + 1] = u
            end)
        end)
        units[#units + 1] = N.summonSuper(cls).nu
        local other = N.summon(N.CLASS_KEYS[index % #N.CLASS_KEYS], 1, 0).nu
        local before = N.unitStats(other)
        for _ = 1, 5 do V.assert(N.buyUpg('hp_' .. cls), 'hp_' .. cls .. ' 购买升级') end
        V.assert(not N.buyUpg('hp_' .. cls), 'hp_' .. cls .. ' 满级不能再买')
        V.assert((N.G.mx['hp_' .. cls] or 0) == 0, '局内快照不被局外购买追改')
        N.newGame()
        for _, u in ipairs(units) do
            local st = N.unitStats(u)
            V.assert(st.hp == expected(u, 'hp', 0.09) and st.atk == expected(u, 'atk', 0.04),
                (u.branch or cls) .. ' 生命强化不串到攻击')
        end
        for _ = 1, 5 do V.assert(N.buyUpg('atk_' .. cls), 'atk_' .. cls .. ' 购买升级') end
        V.assert(not N.buyUpg('atk_' .. cls), 'atk_' .. cls .. ' 满级不能再买')
        V.assert(N.META.s == 8340, '两项五级强化共扣 1660 军魂')
        V.assert((N.G.mx['atk_' .. cls] or 0) == 0, '本局攻击快照不随购买改变')
        N.newGame()
        V.assert(math.abs(N.G.mx['hp_' .. cls] - 0.05) < 1e-9 and
            math.abs(N.G.mx['atk_' .. cls] - 0.05) < 1e-9, '新局应用兵种生命/攻击 5%')
        for _, u in ipairs(units) do
            local st = N.unitStats(u)
            V.assert(st.hp == expected(u, 'hp', 0.09) and st.atk == expected(u, 'atk', 0.09),
                (u.branch or (cls .. ' 品质' .. u.q)) .. ' 全员4%与兵种5%相加')
        end
        local after = N.unitStats(other)
        V.assert(after.hp == before.hp and after.atk == before.atk, '兵种专属强化不影响其他兵种')
    end)
end

at(130, '广告重复回调及同步返回', function()
    for _, accepted in ipairs({ true, false }) do
        local calls, wins = 0, 0
        setAd(function(_, cb)
            cb({ success = true }); cb({ success = true }); cb({ success = false })
            return accepted
        end)
        N.Ads.show(function(ok) calls = calls + 1; if ok then wins = wins + 1 end end)
        V.assert(calls == 1 and wins == 1, '同步成功优先，重复回调只发一次：' .. tostring(accepted))
        V.assert(not N.Ads.busy and #N.Timers.list == 0, '同步结束释放锁且不留超时器')
    end
end)

at(140, '广告异步、拒绝与迟到', function()
    local pending, calls, wins = {}, 0, 0
    setAd(function(_, cb) pending.cb = cb; return false end)
    N.Ads.show(function(ok) calls = calls + 1; if ok then wins = wins + 1 end end)
    V.assert(calls == 1 and wins == 0 and not N.Ads.busy, '拒绝立即失败释放锁')
    N.setTimeout(function() pending.cb({ success = true }) end, 1)
    N.Timers.advance(N.Timers.now + 1) -- 点调用，参数是绝对毫秒，不是 dt。
    V.assert(calls == 1 and wins == 0, '拒绝后的迟到成功不发奖')
    setAd(function(_, cb) pending.cb = cb; return true end)
    N.Ads.show(function(ok) calls = calls + 1; if ok then wins = wins + 1 end end)
    V.assert(N.Ads.busy, '异步请求持锁')
    N.Ads.show(function(ok, msg) V.assert(not ok and msg == 'busy', '并发请求被拒绝') end)
    V.assert(N.Ads.busy, '并发拒绝不释放原请求锁')
    N.setTimeout(function() pending.cb({ success = true }); pending.cb({ success = true }) end, 1)
    N.Timers.advance(N.Timers.now + 1)
    V.assert(calls == 2 and wins == 1 and not N.Ads.busy, '异步重复成功只发奖一次并解锁')
    V.assert(#N.Timers.list == 0, '异步结束撤销兜底超时器')
end)

at(150, '广告超时、异常与取消', function()
    local pending, result = {}, { calls = 0 }
    setAd(function(_, cb) pending.cb = cb; return true end)
    N.Ads.show(function(ok, msg) result.calls = result.calls + 1; result.ok, result.msg = ok, msg end)
    local deadline = N.Timers.now + N.Ads.TIMEOUT
    N.Timers.advance(deadline - 1)
    V.assert(N.Ads.busy and result.calls == 0, '超时前一毫秒仍等待')
    N.Timers.advance(deadline)
    V.assert(not N.Ads.busy and result.calls == 1 and result.ok == false and result.msg == 'timeout', '到期只失败一次并释放锁')
    pending.cb({ success = true })
    V.assert(result.calls == 1, '超时后迟到成功无效')
    setAd(function() error('验收用 SDK 异常') end)
    N.Ads.show(function(ok, msg) V.assert(not ok and msg == 'exception', 'SDK 异常按失败收敛') end)
    V.assert(not N.Ads.busy and #N.Timers.list == 0, 'SDK 异常不留锁或定时器')
    setAd(function(_, cb) pending.cb = cb; return true end)
    N.Ads.show(function() result.calls = result.calls + 1 end)
    local late = pending.cb
    N.Ads.cancel()
    V.assert(not N.Ads.busy and #N.Timers.list == 0, '取消在途请求释放锁和超时器')
    N.Ads.show(function() result.calls = result.calls + 1 end)
    late({ success = true })
    V.assert(result.calls == 1 and N.Ads.busy, '旧请求迟到不能给新请求发奖或解锁')
    pending.cb({ success = true })
    V.assert(result.calls == 2 and not N.Ads.busy, '取消后新请求仍可正常结束')
end)

-- 赢两波积累真实非零军魂，再在第三波失去最后生命；不伪造完整战斗状态。
local function reviveResult()
    N.summon('warrior', 1, 0)
    for _ = 1, 2 do
        N.startBattle()
        N.G.battle.result = 'win' -- 只指定战斗结果，结算仍走真实 finishBattle。
        N.finishBattle(false)
    end
    N.G.lives = 1
    N.startBattle()
    N.G.battle.result = 'lose'
    return N.finishBattle(true)
end

at(160, '复活取消非零结算与翻倍上下文', function()
    local res = reviveResult()
    local before, earned = N.META.s, N.G.soulPend
    V.assert(res.revivable and not res.soul and earned > 0 and not N.G.settled, '复活机会暂缓非零军魂结算')
    N.UI.showResult(res)
    local no = click('adNo')
    V.assert(N.G.settled and res.revivable == false and res.soul and res.soul.total == earned, '取消复活正常结算非零军魂')
    V.assert(N.META.s == before + earned and N.SAVE[0].best[0] == 2, '余额与最佳守住两波落档')
    if no then no.onclick() end
    N.UI.leaveRevive(res)
    V.assert(N.META.s == before + earned and res.soul.total == earned, '重复取消/离开复活不重复结算')
    local showResult, seen = N.UI.showResult, {}
    N.UI.showResult = function(value) seen[#seen + 1] = value; return showResult(value) end
    local wave, win, base, interest = res.wave, res.win, res.base, res.interest
    setAd(function(_, cb) cb({ success = true }); cb({ success = true }); return false end)
    click('adDouble'); click('adGo')
    V.assert(seen[#seen] == res, '翻倍后仍将完整 res 传回真实结果 UI')
    V.assert(res.wave == wave and res.win == win and res.base == base and res.interest == interest,
        '翻倍保留波次、胜负、金币和利息上下文')
    V.assert(res.soul.total == earned * 2 and res.soul.doubled and N.G.adDouble == 1, '广告翻倍且只记一次')
    V.assert(N.META.s == before + earned * 2, '重复 SDK 回调没有多发军魂')
    V.assert(N.UI.els.mBody:getText():find('止步第 ' .. wave .. ' 波', 1, true) ~= nil, '翻倍后的真实 UI 仍显示原失败波次')
    N.adDouble(res.soul)
    V.assert(N.META.s == before + earned * 2, '重复翻倍不再发奖')
end)

at(170, '复活广告关闭后迟到', function()
    local res = reviveResult()
    local pending, before, earned = {}, N.META.s, N.G.soulPend
    setAd(function(_, cb) pending.cb = cb; cb({ success = false, msg = 'manual close' }); return true end)
    N.UI.showResult(res); click('adGo')
    V.assert(N.G.settled and res.soul and res.soul.total == earned and earned > 0, '提前关闭复活广告也结算非零军魂')
    pending.cb({ success = true })
    V.assert(N.G.phase == 'gameover' and N.G.adRevives == 0 and N.META.s == before + earned,
        '关闭后迟到成功不能复活或重复结算')
end)

at(180, '云读取门禁与保存失败', function()
    local pending, counts, uploaded = {}, { fetch = 0, save = 0 }, {}
    rawset(_G, 'clientCloud', {
        BatchGet = function()
            return {
                Key = function(self) return self end,
                Fetch = function(_, events) counts.fetch = counts.fetch + 1; pending.get = events end,
            }
        end,
        BatchSet = function()
            return {
                Set = function(self, key, value) uploaded[key] = value; return self end,
                Save = function(_, _, events) counts.save = counts.save + 1; pending.set = events end,
            }
        end,
    })
    local cloud = N.Cloud
    cloud.active, cloud.ready, cloud.fetching, cloud.pushing = true, false, false, false
    cloud.now, cloud.retryAt, cloud.pushedAt = 0, 0, -1e9
    cloud.markDirty()
    cloud.tick(0)
    V.assert(counts.fetch == 1 and cloud.fetching and not cloud.ready, '首次先读云档，不抢先 ready')
    local first = pending.get
    first.error('test', '验收用读取失败')
    first.ok({})
    cloud.push(); cloud.tick(1)
    V.assert(not cloud.ready and not cloud.fetching and counts.save == 0 and cloud.dirty, '读取失败及迟到成功不 ready、不上传')
    cloud.tick(cloud.retryAt)
    V.assert(counts.fetch == 2, '达到重试时钟才重新读取')
    pending.get.ok({ [N.META_KEY] = '{"s":100,"l":{"cheap":2},"v":2}' })
    V.assert(cloud.ready and N.META.s == 750 and N.upgLv('cheap') == 0, '真实 sync 成功经过 v2 迁移')
    cloud.push()
    V.assert(counts.save == 1 and cloud.pushing, '读取成功后才允许保存')
    local sent = N.jsonDecode(uploaded[N.META_KEY])
    V.assert(sent.v == 3 and sent.l.cheap == 0 and sent.s == 750, '真实 push 上传迁移后的 v3')
    pending.set.error('test', '验收用保存失败')
    V.assert(cloud.dirty and not cloud.pushing, '保存失败释放 pushing 且保留 dirty')
    cloud.push()
    V.assert(counts.save == 2 and cloud.pushing, '失败后允许重新保存')
    pending.set.ok()
    V.assert(not cloud.pushing and not cloud.dirty, '有效成功回执才清除 dirty')
end)

at(190, '新首领真实施法与旧技能', function()
    local original, routed = N.c45Cast, {}
    N.c45Cast = function(battle, caster, target, skill)
        routed[#routed + 1] = { caster = caster, skill = skill }
        return original(battle, caster, target, skill)
    end
    for _, spec in ipairs({ { 3, 'frostqueen' }, { 4, 'astralking' } }) do
        local chapter, kind = spec[1], spec[2]
        N.newGame(chapter, 0)
        N.summonSuper('warrior')
        N.G.wave = N.G.maxWave
        N.startBattle()
        local b = N.G.battle
        local boss = b.ents:find(function(e) return e.type == kind end)
        local target = b.ents:find(function(e) return e.side == 'p' end)
        V.assert(boss ~= nil and boss.skill == N.ENEMIES[kind].skill, '真实首领波生成并采用敌人技能：' .. kind)
        local calls, projs, fields = #routed, #b.projs, #b.fields
        N.castSkill(b, boss, target)
        V.assert(#routed == calls + 1 and routed[#routed].caster == boss, '首领真实 castSkill 进入 c45Cast：' .. kind)
        V.assert(#b.projs == projs, '首领未误入旧玩家投射物技能：' .. kind)
        if kind == 'frostqueen' then
            V.assert(target.chill ~= nil and target.chill.n == 2, '女皇新星施加两层寒霜')
            local shaman = N.spawnEnemy(b, 'frostshaman', 180, 72)
            N.castSkill(b, shaman, target)
            V.assert(#b.fields == fields + 1 and b.fields[fields].kind == 'blizzard' and b.fields[fields].src == shaman,
                '真实霜语萨满 cast 新增暴风雪场地')
        else
            V.assert(#b.fields == fields + 1 and b.fields[fields].kind == 'star' and b.fields[fields].src == boss,
                '神王真实 cast 新增星陨预警场地')
        end
        local field = b.fields[fields]
        local life = field.t
        N.stepBattle(0.01)
        V.assert(field.t < life, '真实 stepBattle 推进新增场地：' .. kind)
        -- 大伤害经真实 hit 的阶段保护卡线，再用零步长触发阶段，避免依赖帧速。
        N.hit(target, boss, boss.maxHp * 10, { noCrit = true, noLeech = true })
        N.stepBattle(0)
        V.assert(boss.ph1 == true, '真实受击触发首领第一阶段：' .. kind)
        if kind == 'frostqueen' then
            V.assert(target.jailed ~= nil and target.jailed.type == 'iceprison', '女皇 70% 生成冰牢并囚禁单位')
        else
            V.assert(boss.tether ~= nil and #boss.tether >= 2 and boss.tether[0].type == 'obelisk',
                '神王 60% 生成方尖碑并绑定')
        end
        local fallen = b.ents:find(function(e) return e.type == 'sentinel' end)
        if fallen then N.hit(target, fallen, fallen.maxHp * 10, { noCrit = true, noLeech = true, dot = true }) end
        N.hit(target, boss, boss.maxHp * 10, { noCrit = true, noLeech = true })
        N.stepBattle(0)
        V.assert(boss.ph2 == true and boss.frenzy == true, '真实受击触发首领第二阶段：' .. kind)
        if kind == 'frostqueen' then
            V.assert(b.fields:some(function(f) return f.kind == 'blizzard' and f.perm and f.src == boss end),
                '女皇 35% 新增永冬风暴场地')
        else
            V.assert(fallen ~= nil and not fallen.dead and fallen.hp > 0, '神王 30% 复活本波阵亡哨卫')
            N.stepBattle(1.01); N.stepBattle(0.01)
            V.assert(field.fired == true, '神王星陨场地经过预警后真实落下')
        end
        N.G.phase = 'prep' -- 本组不依赖主循环推进战斗。
    end
    for _, spec in ipairs({ { 'mage', 2, 'frost', 'frostbig' }, { 'archer', 3, 'starfall', 'star' } }) do
        N.newGame()
        local u = N.summon(spec[1], 3, spec[2]).nu
        N.awaken(u, spec[3])
        N.startBattle()
        local b = N.G.battle
        local caster = b.ents:find(function(e) return e.unit == u end)
        local target = b.ents:find(function(e) return e.side == 'e' end)
        local calls, projs = #routed, #b.projs
        N.castSkill(b, caster, target)
        V.assert(#routed == calls and #b.fields == 0 and #b.projs > projs, '旧玩家同名技能仍走原投射物逻辑：' .. caster.skill)
        V.assert(b.projs[projs].kind == spec[4], '旧玩家技能投射物类型保留：' .. spec[4])
        N.G.phase = 'prep'
    end
end)

V.atFrame(200, function() V.finish() end)
