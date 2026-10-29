-- 广告与云存档的验收插件（只供 -validate-test 使用）
-- 用假的 sdk / clientCloud 驱动真实流程，覆盖「完整观看」「提前关闭」「请求未受理」三条路径
local V = assert(rawget(_G, 'V'), '本脚本只供 -validate-test 使用') --[[@as table<string, any>]]

-- sdk:ShowRewardVideoAd 是冒号调用，第一个参数是 sdk 自身
local AD_OK = function(_, cb) cb({ success = true, msg = 'embed success' }); return true end
local AD_CLOSE = function(_, cb) cb({ success = false, msg = 'embed manual close' }); return true end
local AD_REJECT = function() return false end

local function setAd(fn) rawset(_G, 'sdk', { ShowRewardVideoAd = fn }) end

-- 测试环境是 PC，没有真广告；强制走手机端分支，才能验到确认框和播放流程
local function forceMobile() require('game.env').Ads.available = function() return true end end

local function click(id)
    local el = require('game.env').PAGE.doc.getElementById(id)
    if el and el.onclick then el.onclick() end
    return el ~= nil
end

V.atFrame(10, function()
    local N = require('game.env')
    N.store.persist = function() end
    forceMobile()
    V.assert(N.PAGE ~= nil, '真实入口已初始化页面')
    if not N.PAGE then V.finish(); return end
    N.TUT.stop()
    N.UI.els.home:setHidden(true)
    N.UI.els.overlay:setHidden(true)
end)

-- 1) 完整观看：广告拉杆真的多拉一次（免费拉杆会立刻被这次拉杆用掉）
V.atFrame(30, function()
    local N = require('game.env')
    N.G.adSpins, N.G.freeSpins, N.G.phase = 0, 0, 'prep'
    local spins = N.G.stats.spins
    setAd(AD_OK)
    N.adSpin()
    V.assert(click('adGo'), '额外拉杆弹窗有「看广告」按钮')
    V.assert(N.G.adSpins == 1, '完整观看后计入已用次数')
    V.assert(N.G.stats.spins == spins + 1, '完整观看后真的多拉了一次')
    V.assert(N.G.freeSpins == 0, '送的免费拉杆被这次拉杆用掉')
    N.G.phase = 'prep'
end)

-- 2) 提前关闭：不发奖，次数不消耗
V.atFrame(50, function()
    local N = require('game.env')
    N.G.adSpins, N.G.freeSpins, N.G.phase = 0, 0, 'prep'
    local spins = N.G.stats.spins
    setAd(AD_CLOSE)
    N.adSpin()
    click('adGo')
    V.assert(N.G.stats.spins == spins, '提前关闭不会多拉一次')
    V.assert(N.G.adSpins == 0, '提前关闭不消耗次数')
end)

-- 3) 请求未被受理且回调不触发：不发奖，按钮可再次点击
V.atFrame(70, function()
    local N = require('game.env')
    N.G.adSpins, N.G.freeSpins, N.G.phase = 0, 0, 'prep'
    local spins = N.G.stats.spins
    setAd(AD_REJECT)
    N.adSpin()
    click('adGo')
    V.assert(N.G.stats.spins == spins, '请求未受理不会多拉一次')
    V.assert(N.Ads.busy == false, '失败后广告锁已释放')
end)

-- 4) 次数上限：用完 3 次后按钮禁用，且不再弹窗
V.atFrame(90, function()
    local N = require('game.env')
    setAd(AD_OK)
    N.G.adSpins, N.G.freeSpins = 0, 0
    local spins = N.G.stats.spins
    for _ = 1, 3 do
        N.G.phase = 'prep' -- 每次拉杆都会进入 spinning，测试里手动复位
        N.adSpin(); click('adGo')
    end
    V.assert(N.G.stats.spins == spins + 3, '三次额外拉杆都到账')
    V.assert(N.G.adSpins == 3, '三次都用满')
    N.G.phase = 'prep'
    N.UI.update()
    V.assert(N.UI.els.adSpin:isDisabled(), '用满 3 次后拉杆广告按钮禁用')
    N.adSpin()
    V.assert(N.G.adSpins == 3, '用满后不再消耗')
    V.assert(N.G.stats.spins == spins + 3, '用满后不再多拉')
end)

-- 5) 复活：最后一滴血战败给一次机会，复活后回到 1 点生命、本波重打
V.atFrame(110, function()
    local N = require('game.env')
    N.G.lives = 1
    N.G.adRevives = 0
    N.G.battle = { result = 'lose' }
    local res = N.finishBattle(true)
    V.assert(res.revivable == true, '最后一滴血战败时给出复活机会')
    V.assert(N.G.phase == 'gameover', '此时停在 gameover')
    V.assert(res.soul == nil, '复活机会期间先不结算军魂')
    N.adRevive(true)
    V.assert(N.G.lives == 1, '复活后回到 1 点生命')
    V.assert(N.G.phase == 'prep', '复活后回到布阵阶段')
    V.assert(N.G.adRevives == 1, '复活次数已记录')
    V.assert(N.G.settled == false, '复活后这一局还能继续结算')
end)

-- 6) 复活次数用完后，同样的战败正常结算
V.atFrame(130, function()
    local N = require('game.env')
    N.G.lives = 1
    N.G.battle = { result = 'lose' }
    local res = N.finishBattle(true)
    V.assert(res.revivable ~= true, '复活次数用完后不再给机会')
    V.assert(N.G.phase == 'gameover', '正常进入 gameover')
    V.assert(res.soul ~= nil, '正常结算军魂')
    V.assert(N.G.settled == true, '一局只结算一次')
end)

-- 7) 军魂翻倍：每局一次，军魂真的翻倍
V.atFrame(150, function()
    local N = require('game.env')
    local before = N.META.s
    local s = { total = 10, waves = 2, base = 10, bonus = 0, first = 0 }
    N.adDouble(s)
    V.assert(s.total == 20, '军魂翻倍后总额 ×2')
    V.assert(N.META.s == before + 10, '翻倍的部分真的进了军魂余额')
    V.assert(s.doubled == true, '标记已翻倍')
    N.adDouble(s)
    V.assert(s.total == 20, '每局只翻倍一次')
    V.assert(N.META.s == before + 10, '重复调用不再加军魂')
end)

-- 8) 云存档合并：逐项取进度更高的一边
V.atFrame(170, function()
    local N = require('game.env')
    N.META.s = 100
    N.META.l.gold = 1
    N.store.set('reel-legion-best', 3)
    N.store.set('reel-legion-cleared', 1)
    N.Cloud.merge({
        ['reel-legion-meta'] = '{"s":250,"l":{"gold":3,"hp":2},"v":2}',
        ['reel-legion-best'] = 7,
        ['reel-legion-cleared'] = 5,
        ['reel-legion-unlock'] = 2,
    })
    V.assert(N.META.s == 250, '军魂取云端更高的值')
    V.assert(N.upgLv('gold') == 3, '已升级的强化取更高的等级')
    V.assert(N.upgLv('hp') == 2, '本地没有的强化也合并进来')
    V.assert(tonumber(N.store.get('reel-legion-best')) == 7, '最佳纪录取更高的')
    V.assert(tonumber(N.store.get('reel-legion-cleared')) == 5, '通关标记取更大的')
    V.assert(tonumber(N.store.get('reel-legion-unlock')) == 2, '解锁进度取更大的')
end)

-- 9) 云存档合并只升不降：本地更高时保持本地
V.atFrame(190, function()
    local N = require('game.env')
    N.META.s = 900
    N.store.set('reel-legion-best', 12)
    N.Cloud.merge({ ['reel-legion-meta'] = '{"s":50,"l":{},"v":2}', ['reel-legion-best'] = 1 })
    V.assert(N.META.s == 900, '云端更低时不覆盖本地军魂')
    V.assert(tonumber(N.store.get('reel-legion-best')) == 12, '云端更低时不覆盖本地纪录')
end)

V.atFrame(210, function() end)
