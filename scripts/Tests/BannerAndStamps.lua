-- 真实入口的召唤描边与集点二级展示验收，不写玩家存档。
local V = assert(rawget(_G, 'V'), '本脚本只供 -validate-test 使用') --[[@as table<string, any>]]
local N = require('game.env') --[[@as table<string, any>]]
local App = require('game.app')
local Paint = require('ui.paint')
local mode = 'banner'
for _, arg in ipairs(GetArguments()) do mode = arg:match('^%-visual%-state=(.+)$') or mode end

V.atFrame(10, function()
    N.TUT.stop()
    N.UI.els.home:setHidden(true)
    N.UI.els.overlay:setHidden(true)
    if mode == 'forge' then
        N.META.s = 1000
        N.META.l.cheap, N.META.cheapSpent = 1, 450
        N.UI.showForge('eco', 'home')
    else
        N.restart(3, 0, N.DEFAULT_SQUAD)
        N.UI.els.overlay:setHidden(true)
        N.summon('archer', 1, 2)
        N.UI.banner('史诗召唤：射手★', 'q2')
        N.clearTimeout(N.UI.bannerT)
        N.UI.bannerT = nil
        N.UI.els.banner:setStyle('transition', 'none')
    end
    N.PAGE:update()
end)

V.atFrame(100, function()
    if mode ~= 'forge' then return end
    local row = N.PAGE.doc.body:querySelector('.mu-buy[data-u="cheap"]').parent
    local modal = N.UI.els.mTitle.parent
    N.PAGE:setScrollTop(modal, row.box.ay - modal.box.ay - 12)
end)

V.atFrame(110, function()
    local cheap = N.UPG:find(function(u) return u.id == 'cheap' end)
    local old = N.META.l.cheap
    N.META.l.cheap = 1
    local html = N.UI.forgeRow(cheap)
    V.assert(html:find('1000', 1, true) ~= nil, '集点二级展示1000军魂')
    V.assert(html:find('每付费拉杆 4 次', 1, true) ~= nil, '集点二级展示4次送1次')
    N.META.l.cheap = old
    if mode == 'forge' then
        local buy = N.PAGE.doc.body:querySelector('.mu-buy[data-u="cheap"]')
        V.assert(buy ~= nil and not buy:isDisabled(), '1000军魂时二级购买按钮可用')
        local box = buy and buy.box
        V.assert(box ~= nil and box.ax >= 0 and box.ax + box.w <= N.PAGE.env.vw, '升级按钮完整位于横屏画布内')
    else
        local banner = N.UI.els.banner
        V.assert(banner:getText() == '史诗召唤：射手★', '保持截图中的中文与星号组合')
        local style = banner.box.cs
        local shadows = Paint.splitTop(style.raw['text-shadow'], ',')
        V.assert(#shadows == 8, '召唤文字使用八方向细描边')
        V.assert(not style.raw['text-shadow']:find('3px', 1, true) and
            not style.raw['text-shadow']:find('4px', 1, true), '移除稀疏粗黑影及不对称右下重影')
        V.assert(banner.box.ax >= 0 and banner.box.ax + banner.box.w <= N.PAGE.env.vw, '召唤提示完整位于横屏画布内')
        V.assert(App.anim ~= nil, '仍由真实页面动画与绘制链渲染')
    end
    V.finish()
end)
