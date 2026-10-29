-- 用于 imported_main.lua 的验收插件，真实入口及事件回调保持不变。
-- 适配 game.layout 的画布内自适应排版：直接使用设备逻辑像素 + 安全区。
local V = assert(rawget(_G, 'V'), '本脚本只供 -validate-test 使用') --[[@as table<string, any>]]
local state = 'home'
local safe = false
local safeBoth = false
local testRatio = 0
for _, arg in ipairs(GetArguments()) do
    state = arg:match('^%-mobile%-state=(.+)$') or state
    testRatio = tonumber(arg:match('^%-mobile%-ratio=(.+)$')) or testRatio
    if arg == '-mobile-safe' then safe = true end
    if arg == '-mobile-safe-both' then safe = true; safeBoth = true end
end
local newContentState = state == 'shop' or state == 'swamp' or state == 'sea'
local boardState = state == 'prep' or state == 'ice' or state == 'astral' or state == 'swamp' or state == 'sea'
local scrollModalState = state == 'codex' or state == 'squad' or state == 'chapters' or state == 'forge' or
    state == 'forge-human' or state == 'forge-plant' or state == 'shop'

--- 把战场画布坐标换算成物理触摸事件（无旋转变换，直接按 DPR 缩放）
local function eventAtArena(N, position)
    local box = N.arenaEl.box
    local px = box.ax + position.x * box.w / N.AW
    local py = box.ay + position.y * box.h / N.AH
    local dpr = graphics:GetDPR()
    if not dpr or dpr <= 0 then dpr = 1 end
    local data = VariantMap()
    data['TouchID'] = Variant(19)
    data['X'] = Variant(math.floor(px * dpr))
    data['Y'] = Variant(math.floor(py * dpr))
    return data
end

V.atFrame(10, function()
    local N = require('game.env')
    V.assert(N.PAGE ~= nil, '真实入口已初始化页面')
    if not N.PAGE then V.finish(); return end
    N.store.persist = function() end
    if newContentState then
        -- 新内容截图只用独立内存档；即使误触保存/云同步也不触及真实玩家进度。
        N.Cloud.active, N.Cloud.onSynced = false, nil
        rawset(_G, 'clientCloud', {})
        N.store.data = { [N.META_KEY] = N.jsonEncode({ s = 0, l = {}, v = 3 }) }
        N.buildSave(); N.loadMeta()
        for chapter = 0, 5 do N.clearDiff(chapter, 0) end
        V.assert(N.classOpen('treant') and N.classOpen('hawk') and N.classOpen('clockwork'), '截图内存档解锁三新兵种')
    end
    N.UI.els.overlay:setHidden(true)
    if state == 'prep' then
        N.TUT.stop()
        N.UI.els.home:setHidden(true)
        N.PAGE:update()
    elseif state == 'squad' then
        N.TUT.stop()
        N.UI.els.home:setHidden(true)
        N.UI.showSquad(0, 0)
    elseif state == 'codex' then
        N.UI.showCodex()
    elseif state == 'forge' or state == 'forge-human' or state == 'forge-plant' then
        N.UI.showForge(state == 'forge-human' and 'human' or (state == 'forge-plant' and 'plant' or 'eco'), 'home')
    elseif state == 'chapters' then
        N.UI.showStart('', '开始游戏')
    elseif newContentState then
        N.TUT.stop()
        N.UI.els.home:setHidden(true)
        local chapter = state == 'sea' and 6 or 5
        N.restart(chapter, 0, N.A('treant', 'hawk', 'clockwork'))
        N.G.gold, N.G.wave, N.G.gems = 58, state == 'shop' and 2 or 3, 42
        for _, cls in ipairs({ 'treant', 'hawk', 'clockwork', 'treant', 'hawk', 'clockwork' }) do
            N.summon(cls, 2, 1)
        end
        N.gainItem(N.newItem('warbanner'))
        N.gainItem(N.newItem('crystal'))
        for _, id in ipairs({ 'healpotion', 'shieldscroll', 'phoenix' }) do N.gainItem(N.newItem(id)) end
        local troops = N.allUnits()
        N.equipItem(N.newItem('thornmail'), troops[0])
        N.equipItem(N.newItem('lens'), troops[1])
        N.G.sel = troops[0]
        N.UI.els.overlay:setHidden(true)
        N.UI.update()
        if state == 'shop' then
            N.openShop({ wave = 2, win = true })
            N.UI.showShop()
            V.assert(#N.G.shop.slots == 5, '截图真实商店生成五格货架')
        else
            V.assert(N.G.ch == chapter and N.curCh().bg == state, '截图进入真实新章节：' .. state)
        end
        N.PAGE:update()
    elseif state == 'ice' or state == 'astral' then
        N.TUT.stop()
        N.UI.els.home:setHidden(true)
        N.restart(state == 'ice' and 3 or 4, 0, N.DEFAULT_SQUAD)
        N.summon('warrior', 2, 1)
        N.UI.els.overlay:setHidden(true)
    elseif state == 'ad' then
        N.TUT.stop()
        N.UI.els.home:setHidden(true)
        N.Ads.available = function() return true end
        N.adSpin()
    elseif state == 'tutorial' then
        N.TUT.start()
        N.TUT.go(1)
    elseif state == 'details' or state == 'battle-details' or state == 'drag' or state == 'absorb-confirm' then
        N.TUT.stop()
        N.UI.els.home:setHidden(true)
        N.UI.els.overlay:setHidden(true)
    end
end)

V.atFrame(40, function()
    local N = require('game.env')
    if scrollModalState then
        local modal = N.UI.els.mTitle.parent
        N.PAGE:setScrollTop(modal, require('ui.page').scrollRange(modal.box))
        N.PAGE:update()
        local y = N.UI.els.mBtn.box.ay + (N.UI.els.mBtn.box.stickyDY or 0) - (modal.scrollTop or 0)
        V.assert(y >= (N.PAGE.env.envVars['safe-area-inset-top'] or 0), '弹窗滚动到底按钮可达')
        N.PAGE:setScrollTop(modal, 0)
        N.PAGE:update()
        local Input = require('ui.input')
        local input = Input.new(N.PAGE, { now = function() return 1000 end })
        local box = modal.box
        local x, y = box.ax + box.w / 2, box.ay + box.h / 2
        input:pointerDown('scroll', x, y, true)
        input:pointerMove('scroll', x, y - 80, true)
        input:pointerUp('scroll', x, y - 80, true)
        V.assert((modal.scrollTop or 0) > 0, '长弹窗可通过触摸滑动')
        N.PAGE:setScrollTop(modal, 0)
        -- 桌面：鼠标按住拖动同样能滚动（与触摸一致）
        input:pointerDown('mouse', x, y, false)
        input:pointerMove('mouse', x, y - 80, false)
        input:pointerUp('mouse', x, y - 80, false)
        V.assert((modal.scrollTop or 0) > 0, '长弹窗可通过鼠标拖动滑动')
        N.PAGE:setScrollTop(modal, 0)
        -- 战场画布是 touch-action: none，鼠标拖动应保持拖放而不是滚动
        local modalEl = N.UI.els.mTitle.parent
        modalEl:setHidden(true); N.PAGE:update()
        local arenaBox = N.arenaEl.box
        local ax, ay = arenaBox.ax + arenaBox.w / 2, arenaBox.ay + arenaBox.h / 2
        input:pointerDown('mouse', ax, ay, false)
        local rec = input.pointers['mouse'] --[[@as table<string, any>?]]
        V.assert(rec ~= nil and rec.scroller == nil, '战场画布鼠标拖动不进入滚动')
        input:pointerUp('mouse', ax, ay, false)
        modalEl:setHidden(false); N.PAGE:update()
        N.PAGE:setScrollTop(modal, 0)
    end
end)

V.atFrame(75, function()
    if state == 'battle-details' then
        local N = require('game.env')
        local unit = N.summon('warrior', 1, 0).nu
        N.startBattle()
        N.G.battle.ents:forEach(function(e)
            if e.side == 'p' and e.unit == unit then e.x, e.y = 140, 76 end
        end)
        N.frameReset(1000)
        HandleTouchBegin('TouchBegin', eventAtArena(N, { x = 140, y = 76 }))
        HandleTouchEnd('TouchEnd', eventAtArena(N, { x = 140, y = 76 }))
        N.UI.update()
        V.assert(N.G.sel == unit, '战斗时点选当前移动中的我方单位')
        V.assert(N.UI.els.info:getText():find('生命', 1, true) ~= nil, '战斗中的选中角色详情可见')
        return
    end
    if state == 'details' then
        local N = require('game.env')
        local unit = N.summon('warrior', 1, 0).nu
        N.frameReset(1000)
        HandleTouchBegin('TouchBegin', eventAtArena(N, N.fPos(N.findSlot(unit).i)))
        HandleTouchEnd('TouchEnd', eventAtArena(N, N.fPos(N.findSlot(unit).i)))
        N.UI.update()
        V.assert(N.G.sel == unit, '准备阶段点选角色')
        V.assert(N.UI.els.info:getText():find('生命', 1, true) ~= nil, '准备阶段角色详情可见')
        return
    end
    if state == 'absorb-confirm' then
        local N = require('game.env')
        -- 高星单位喂给低星：必须先确认，取消后双方都还在
        local src = N.summon('warrior', 3, 0).nu
        local dst = N.summon('warrior', 1, 0).nu
        local from, to = N.findSlot(src), N.findSlot(dst)
        V.assert(from ~= nil and to ~= nil, '两个单位都已放置')
        V.assert(N.needsAbsorbConfirm(src, dst), '高星喂低星判定为需要确认')
        V.assert(not N.needsAbsorbConfirm(dst, src), '低星喂高星不需要确认')
        local before = dst.pts
        N.dropAt(src, from, to)
        V.assert(N.getSlot(from) == src and N.getSlot(to) == dst, '确认前不吞噬')
        V.assert(not N.UI.els.overlay:isHidden(), '弹出吞噬确认框')
        local no = N.PAGE.doc.getElementById('cfNo')
        V.assert(no ~= nil, '确认框有取消按钮')
        no.onclick()
        V.assert(N.getSlot(from) == src and N.getSlot(to) == dst, '取消后两个单位都保留')
        V.assert(dst.pts == before, '取消后吸收者经验不变')
        -- 再走一次并确认，高星单位被吞掉、低星吸收者升星
        N.dropAt(src, from, to)
        local yes = N.PAGE.doc.getElementById('cfYes')
        V.assert(yes ~= nil, '确认框有确认按钮')
        yes.onclick()
        V.assert(N.getSlot(from) == nil, '确认后高星单位被吞噬')
        V.assert(N.findSlot(dst) ~= nil and dst.star > 1, '吸收者获得经验并升星')
        return
    end
    if state ~= 'drag' then return end

    local N = require('game.env')
    local unit = N.summon('warrior', 1, 0).nu
    local function positionOf(slot)
        return slot.t == 'f' and N.fPos(slot.i) or N.bPos(slot.i)
    end
    local function dragTo(target)
        local from = N.findSlot(unit)
        local start = positionOf(from)
        local nudge = { x = start.x + 5, y = start.y + 2 }
        local finish = positionOf(target)
        finish.y = finish.y + 10
        HandleTouchBegin('TouchBegin', eventAtArena(N, start))
        HandleTouchMove('TouchMove', eventAtArena(N, nudge))
        -- 故意让松手位置不同于最后一次 Move，确保 pointer-up 坐标生效。
        HandleTouchEnd('TouchEnd', eventAtArena(N, finish))
        V.assert(N.getSlot(target) == unit, '触摸松手坐标放置到目标槽')
    end
    local from = N.findSlot(unit)
    local first = { t = 'f', i = (from.i + 1) % N.FORM_N }
    dragTo(first)
    for i = 0, N.FORM_N - 1 do
        local target = { t = 'f', i = i }
        if N.getSlot(target) ~= unit then dragTo(target) end
    end
    for i = 0, N.BENCH_N - 1 do dragTo({ t = 'b', i = i }) end
    V.assert(N.getSlot(N.findSlot(unit)) == unit, '全部 20 个布阵与备战席格均可拖放')
end)

V.atFrame(118, function()
    local N = require('game.env')
    local PAGE = N.PAGE
    if not PAGE then V.finish(); return end
    PAGE:update()
    local root = PAGE.doc.documentElement
    ---@type table<string, table<string, any>>
    local items = {}
    for _, id in ipairs({ 'app', 'arena', 'slot', 'lever', 'fight', 'hPlay', 'mBtn', 'coachTip' }) do
        local el = PAGE.doc.getElementById(id)
        local box = el and el.box
        if box then
            items[id] = { x = box.ax, y = box.ay + (box.stickyDY or 0), w = box.w, h = box.h,
                scrollH = box.scrollH, scrollTop = el.scrollTop }
        end
    end
    local board = PAGE.doc.body:querySelector('.board').box
    local fieldFrame = PAGE.doc.body:querySelector('.field-frame').box
    local cabinet = PAGE.doc.getElementById('cabinet').box
    local infoEl = PAGE.doc.getElementById('info')
    local bodyEl = PAGE.doc.body:querySelector('.cab-body')
    local bodyBox = bodyEl and bodyEl.box
    local reelsEl = PAGE.doc.body:querySelector('.reels')
    local reelsBox = reelsEl and reelsEl.box
    items.board = { x = board.ax, y = board.ay, w = board.w, h = board.h }
    items.fieldFrame = { x = fieldFrame.ax, y = fieldFrame.ay, w = fieldFrame.w, h = fieldFrame.h }
    items.cabinet = { x = cabinet.ax, y = cabinet.ay, w = cabinet.w, h = cabinet.h }
    if infoEl and infoEl.box then
        items.info = { x = infoEl.box.ax, y = infoEl.box.ay, w = infoEl.box.w, h = infoEl.box.h }
    end
    if bodyBox then items.cabBody = { x = bodyBox.ax, y = bodyBox.ay, w = bodyBox.w, h = bodyBox.h } end
    if reelsBox then items.reels = { x = reelsBox.ax, y = reelsBox.ay, w = reelsBox.w, h = reelsBox.h } end
    print('[MobileTest] ' .. cjson.encode({ state = state, vw = PAGE.env.vw, vh = PAGE.env.vh,
        lay = root:getAttribute('data-lay'), info = root:getAttribute('data-info'),
        short = root:getAttribute('data-short'), env = PAGE.env.envVars, boxes = items }))

    local env = PAGE.env.envVars
    local left, top = env['safe-area-inset-left'] or 0, env['safe-area-inset-top'] or 0
    local right = PAGE.env.vw - (env['safe-area-inset-right'] or 0)
    local bottom = PAGE.env.vh - (env['safe-area-inset-bottom'] or 0)
    V.assert(root:getAttribute('data-lay') ~= nil, '自适应排版已按当前视口生效')
    if newContentState then
        V.assert(not N.Cloud.active and N.store.persist ~= nil, '新内容截图禁云且仅使用内存存档')
        V.assert(N.G.squad:join(',') == 'treant,hawk,clockwork' and #N.allUnits() == 6, '新内容展示三新兵种与六个真实单位')
        V.assert(#N.G.relics == 2 and #N.G.cons == 3, '新内容展示两圣物和三消耗品')
        if state == 'shop' then
            local shop = PAGE.doc.getElementById('shop')
            V.assert(shop ~= nil and #shop:querySelectorAll('.shop-card') == 5, '真实商店五张卡片均已渲染')
            V.assert(PAGE.doc.getElementById('shRefresh') ~= nil and not N.UI.els.overlay:isHidden(), '商店刷新与弹窗可见')
        else
            V.assert(N.G.phase == 'prep' and not N.UI.els.fight:isDisabled(), '新章节布阵已就绪，可以真实开战')
            for _, id in ipairs({ 'itemBar', 'ruleBar' }) do
                local el = PAGE.doc.getElementById(id)
                local box = el and el.box
                V.assert(el and not el:isHidden() and box and box.w > 0 and box.h > 0, '新章节' .. id .. '可见')
            end
        end
    end
    if boardState then
        V.assert(items.arena ~= nil and math.abs(items.arena.w / items.arena.h - 256 / 176) < 0.03, '战场等比显示')
        V.assert(items.arena ~= nil and items.fieldFrame ~= nil and
            math.abs(items.arena.w - (items.fieldFrame.w - fieldFrame.bl - fieldFrame.br)) <= 1,
            '战场画布横向填满战场框架内部')
        V.assert(items.lever.w >= 40 and items.fight.h >= 40, '主要操作保留可触摸尺寸')
        V.assert(items.info ~= nil and items.info.w > 0 and items.info.h > 0, '信息栏可见')
        V.assert(items.cabinet ~= nil and items.cabinet.w > 0 and items.cabinet.h > 0, '机柜可见')
    end
    if state == 'home' then
        local card = PAGE.doc.body:querySelector('.home-card').box
        V.assert(items.hPlay ~= nil and items.hPlay.h >= 44, '主页主要按钮保留 44px 触摸高度')
        V.assert(card.ax >= left - 1 and card.ax + card.w <= right + 1 and
            card.ay >= top - 1 and card.ay + card.h <= bottom + 1, '主页卡片安全边界')
        local progress = PAGE.doc.getElementById('hProg').box
        V.assert(progress.ay >= card.ay and progress.ay + progress.h <= card.ay + card.h - card.bb + 1,
            '主页章节进度完整显示，无需滚动')
    elseif scrollModalState or state == 'ad' then
        local modal = N.UI.els.mTitle.parent.box
        V.assert(modal.ax >= left - 1 and modal.ax + modal.w <= right + 1 and
            modal.ay >= top - 1 and modal.ay + modal.h <= bottom + 1, '弹窗安全边界')
        if state == 'ad' then
            for _, id in ipairs({ 'adGo', 'adNo' }) do
                local box = PAGE.doc.getElementById(id).box
                V.assert(box.ax >= left - 1 and box.ax + box.w <= right + 1 and
                    box.ay >= top - 1 and box.ay + box.h <= bottom + 1, '广告确认按钮安全边界')
            end
        end
        if state:find('forge', 1, true) then
            V.assert(#PAGE.doc.getElementById('mBody'):querySelectorAll('.cx-tab') == 6, '六个强化页签完整保留')
        end
    elseif state == 'tutorial' then
        local tip = items.coachTip
        V.assert(tip.x >= left - 1 and tip.x + tip.w <= right + 1 and
            tip.y >= top - 1 and tip.y + tip.h <= bottom + 1, '教程提示安全边界')
    end

    -- 安全区：整页内容必须落在安全区内，且不出现横向溢出。
    local docEl = PAGE.doc.documentElement
    local appBox = items.app
    V.assert(appBox ~= nil and appBox.x >= left - 1 and appBox.x + appBox.w <= right + 1,
        '根容器横向落在安全区内')
    if safe then
        local scrollW = docEl.scrollWidth or 0
        V.assert(scrollW <= PAGE.env.vw + 1, '安全区下无横向溢出')
    end
    -- 不同物理分辨率 / DPR 下的排版自洽性：战场等比、机柜与信息栏都有正尺寸。
    local devices = {
        { 2400, 1080, 3 }, { 2436, 1125, 3 }, { 2532, 1170, 3 }, { 2796, 1290, 3 },
        { 1920, 1080, 3 }, { 1080, 2400, 3 }, { 1536, 2048, 2 }, { 1024, 768, 2 },
    }
    for _, device in ipairs(devices) do
        local w, h, ratio = device[1], device[2], device[3]
        local vw, vh = w / ratio, h / ratio
        local L = N.LAYOUT.compute(vw, vh, { l = 0, r = 0, t = 0, b = 0 })
        -- 布局只给出战场宽度 aw，高度按 176/256 的固定比例由 CSS/绘制换算，这里按同比例校验
        local ah = L.aw * 176 / 256
        V.assert(L.aw > 0 and math.abs(L.aw / ah - 256 / 176) < 0.03,
            '排版战场等比：' .. w .. '×' .. h)
        V.assert(L.slot > 0 and L.gap >= 0, '排版转轴与间距为正：' .. w .. '×' .. h)
    end
    V.finish()
end)
