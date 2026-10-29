-- ============================================================================
-- 界面（逐行移植自原版的 UI / HOME / TUT / 拖拽 / 主循环）
-- 生成的 HTML 字符串与原版完全相同，交给 ui/page 排版绘制
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
require("game.timers")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, sin = math.floor, math.ceil, math.max, math.min, math.abs, math.sin

-- 由 main 注入
PAGE = nil -- ui.page 实例
local function doc() return PAGE.doc end
function _G_id(id) return PAGE.doc.getElementById(id) end
local _id = _G_id

--- el.focus({ preventScroll: true })
local function focusEl(el) if el then PAGE:focus(el, 'script') end end
--- void el.offsetWidth：强制重算样式（用来重启 CSS 动画）
local function reflow() PAGE:update() end
local function str(b) return b and 'true' or 'false' end
local function join(parts) return table.concat(parts) end

-- ---------------------------------------------------------------------------
-- 拖拽与选择
-- ---------------------------------------------------------------------------
drag = nil
--- 指针位置（页面 CSS 像素）→ 战场画布坐标
function toArena(px, py)
    local b = arenaEl and arenaEl.box
    if not b or b.w <= 0 or b.h <= 0 then return { x = 0, y = 0 } end
    local y = b.ay + (b.stickyDY or 0)
    local parent = b.parent
    local guard = 0
    while parent do
        y = y + (parent.stickyDY or 0) - (parent.scrollTop or 0)
        if parent.pos == 'fixed' then break end
        parent = parent.parent
        guard = guard + 1
        if guard > 64 then break end -- 防 DOM 环引用导致死循环
    end
    local x, y = (px - b.ax) * AW / b.w, (py - y) * AH / b.h
    return { x = x, y = y }
end
function hitSlot(p)
    for i = 0, FORM_N - 1 do local q = fPos(i); if abs(p.x - q.x) <= 14 and abs(p.y - q.y) <= 19 then return { t = 'f', i = i } end end
    if p.y >= FIELD_H then
        for i = 0, BENCH_N - 1 do local q = bPos(i); if abs(p.x - q.x) <= 15.5 then return { t = 'b', i = i } end end
    end
    return nil
end
local function battleUnitAt(p)
    ---@type table<string, any>?
    local B = G.battle
    if not B then return nil end
    local best, bestDist
    B.ents:forEach(function(e)
        if e.side == 'p' and e.unit and not e.dead and findSlot(e.unit) then
            local halfW = max(10, (e.r or 5) + 5)
            local top = e.y - ((e.tall or e.big) and 18 or 14)
            local bottom = e.y + 10
            if p.x >= e.x - halfW and p.x <= e.x + halfW and p.y >= top and p.y <= bottom then
                local dx, dy = p.x - e.x, p.y - (top + bottom) / 2
                local dist = dx * dx + dy * dy
                if not bestDist or dist < bestDist then best, bestDist = e.unit, dist end
            end
        end
    end)
    return best
end
local function sameSlot(a, b) return a and b and a.t == b.t and a.i == b.i end
function dropAt(u, from, to)
    ---@type table<string, any>
    local UI = UI
    if not to or sameSlot(from, to) then return end
    local tu = getSlot(to)
    if not tu then setSlot(to, u); setSlot(from, nil); Sound.play('drop'); G.sel = u; return end
    if canAbsorb(u, tu) then
        -- 高星喂低星会损失星级，先弹确认，确认后再吞
        if needsAbsorbConfirm(u, tu) then
            UI.confirmAbsorb(u, tu, function() absorb(u, tu); G.sel = tu end)
        else absorb(u, tu); G.sel = tu end
        return
    end
    setSlot(to, u); setSlot(from, tu); Sound.play('drop'); G.sel = u
end
--- 战场画布上的指针事件（main 的输入层调用）
Arena = {}
function Arena.down(px, py, isTouch)
    Sound.init()
    local p = toArena(px, py)
    local s = hitSlot(p)
    local u = s and getSlot(s)
    if G.phase == 'prep' and u then
        drag = { u = u, from = s, sx = p.x, sy = p.y, x = p.x, y = p.y, moved = false, over = s, touch = isTouch }
        return true -- 预备阶段捕获指针，用于拖放
    end
    if G.phase == 'prep' then
        G.sel = nil
        return false
    end
    if G.phase == 'battle' then
        G.sel = battleUnitAt(p)
        return false
    end
    return false
end
function Arena.move(px, py)
    if not drag then return end
    local p = toArena(px, py)
    if not drag.moved and hypot(p.x - drag.sx, p.y - drag.sy) > 3 then drag.moved = true end
    drag.x = p.x; drag.y = p.y
    drag.over = hitSlot({ x = p.x, y = p.y - (drag.touch and 10 or 0) })
end
function Arena.up(px, py)
    if not drag then return end
    local d = drag
    if d.moved then
        local p = toArena(px, py)
        d.x, d.y = p.x, p.y
        d.over = hitSlot({ x = p.x, y = p.y - (d.touch and 10 or 0) })
    end
    drag = nil
    if G.phase ~= 'prep' then return end
    if d.moved then dropAt(d.u, d.from, d.over)
    else G.sel = d.u end
end
function Arena.cancel() drag = nil end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
UI = { els = {}, pickCh = nil } --[[@as table<string, any>]]
---@type table<string, any>
local UI = UI
local cacheMT = {}
UI.cache = { map = {} }
function UI.cache:get(k) return self.map[k] end
function UI.cache:set(k, v) self.map[k] = v end
function UI.cache:clear() self.map = {} end

function UI.init()
    local self = UI
    local ids = { 'waveNum', 'waveTag', 'hearts', 'goldNum', 'goldBox', 'nextWave', 'info', 'banner', 'toast', 'lever', 'costLbl',
        'fight', 'luck', 'cabinet', 'nextLbl', 'skillLayer', 'overlay', 'mTitle', 'mBody', 'mBtn', 'soundBtn', 'helpBtn', 'codexBtn', 'coinIcon', 'unitCount', 'diffNum', 'home', 'homeBtn',
        'adSpin', 'adSpinNum', 'itemBar', 'ruleBar' }
    for _, id in ipairs(ids) do self.els[id] = _id(id) end
    local E = self.els
    E.coinIcon:setAttribute('src', iconURL('sym_coin'))
    E.lever:addEventListener('click', function() Sound.init(); startSpin() end)
    E.adSpin:addEventListener('click', function() Sound.init(); adSpin() end)
    E.fight:addEventListener('click', function() Sound.init(); self.onFight() end)
    E.soundBtn:addEventListener('click', function()
        Sound.on = not Sound.on; Sound.init()
        self.syncSound()
    end)
    E.helpBtn:addEventListener('click', function() self.showHelp(false) end)
    E.codexBtn:addEventListener('click', function() Sound.init(); self.showCodex() end)
    E.homeBtn:addEventListener('click', function() Sound.init(); self.confirmHome() end)
    _id('hPlay'):addEventListener('click', function() Sound.init(); E.home:setHidden(true); self.showStart('', '开始游戏') end)
    _id('hTut'):addEventListener('click', function() Sound.init(); TUT.start() end)
    _id('hCodex'):addEventListener('click', function() Sound.init(); self.showCodex() end)
    _id('hForge'):addEventListener('click', function() Sound.init(); self.showForge('eco', 'home') end)
    _id('hHelp'):addEventListener('click', function() Sound.init(); self.showHelp(false) end)
    _id('hSound'):addEventListener('click', function() PAGE:click(E.soundBtn) end)
    _id('coachNext'):addEventListener('click', function() Sound.init(); TUT.next() end)
    _id('coachSkip'):addEventListener('click', function() TUT.skip() end)
    PAGE:addWindowListener('keydown', function(e)
        if not E.overlay:isHidden() or not E.home:isHidden() then return end
        local tag = (e.target and e.target.tag) or ''
        if e.code == 'Space' and tag ~= 'button' then e.preventDefault(); Sound.init(); startSpin() end
        if e.code == 'Enter' and tag ~= 'button' then e.preventDefault(); Sound.init(); self.onFight() end
    end)
end

function UI.syncSound(persist)
    local button, homeButton = UI.els.soundBtn, _id('hSound')
    button:setAttribute('aria-pressed', str(Sound.on))
    button:setText(Sound.on and '声音 开' or '声音 关')
    homeButton:setText(button:getText()); homeButton:setAttribute('aria-pressed', str(Sound.on))
    if persist ~= false then store.set('lever-legion-sound', Sound.on and '1' or '0') end
end

function UI.onFight()
    if G.phase == 'prep' then
        if not G.form:some(function(x) return x end) then Sound.play('deny'); UI.banner('阵地上还没有单位', 'red'); return end
        startBattle(); Sound.play('fight')
        UI.banner('第 ' .. S(G.wave) .. ' 波 开战', 'red')
    elseif G.phase == 'battle' then G.speed = (G.speed == 1) and 2 or 1 end
end

function UI.set(el, key, val, html)
    if UI.cache:get(key) == val then return end
    UI.cache:set(key, val)
    -- 第十五次更新（卡顿）：按差异更新，没变的节点不重算样式、不重新排版（见 ui/dom.lua 的 morphHTML）。
    -- 用 UI.set 写 HTML 的容器（信息栏、生命、下一波、幸运）子节点上都没有单独绑定事件，可以安全保留旧节点
    if html then el:morphHTML(val) else el:setText(val) end
end

function UI.update()
    local self, E = UI, UI.els
    local D, dk = curDiff(), S(G.ch) .. ':' .. S(G.diff) .. (G.tutorial and ':t' or '')
    if self.cache:get('diff') ~= dk then
        self.cache:set('diff', dk)
        E.diffNum:setText(G.tutorial and '新手教程' or (curCh().name .. '·' .. D.name))
        E.diffNum:setStyle('color', D.color)
    end
    self.set(E.waveNum, 'wave', S(G.wave) .. '/' .. S(G.maxWave))
    self.set(E.waveTag, 'wtag', G.tutorial and '' or waveTag(G.wave))
    local heartFull, heartEmpty = iconURL('heart'), iconURL('heart', { r = '#4a3a66', O = '#4a3a66' }, 'empty')
    local hp = {}
    for i = 0, G.maxLives - 1 do hp[#hp + 1] = '<img src="' .. (i < G.lives and heartFull or heartEmpty) .. '" alt="">' end
    self.set(E.hearts, 'lives', table.concat(hp) .. '<span class="sr">剩余生命 ' .. S(G.lives) .. '</span>', true)
    self.set(E.goldNum, 'gold', S(G.gold))
    local units = #allUnits()
    self.set(E.unitCount, 'units', '阵地 ' .. S(#G.form:filter(function(x) return x end)) .. '/' .. S(FORM_N) .. '，备战席 ' .. S(#G.bench:filter(function(x) return x end)) .. '/' .. S(BENCH_N))
    local counts, order = {}, {}
    local lineup = currentLineup()
    local elites = #lineup:filter(function(e) return e.elite end)
    lineup:forEach(function(e) if not counts[e.type] then order[#order + 1] = e.type end; counts[e.type] = (counts[e.type] or 0) + 1 end)
    self.set(E.nextLbl, 'nextLbl', G.phase == 'battle' and '本波敌人' or '下一波敌人')
    local parts = {}
    -- 第四次更新：敌人带头像，一眼看出是谁
    for _, t in ipairs(order) do local EN = ENEMIES[t]; parts[#parts + 1] = '<span class="nw"><img src="' .. iconURL(EN.sprite, EN.pal or nil, 'foe:' .. t) .. '" alt="">' .. EN.name .. ' ×' .. S(counts[t]) .. '</span>' end
    self.set(E.nextWave, 'next', table.concat(parts) .. (T(elites) and ('<span class="nw">（其中精英 ' .. S(elites) .. '）</span>') or ''), true)
    local prep = G.phase == 'prep'
    E.lever:setDisabled(not prep)
    local freeSp = G.freeSpins > 0
    local poor = not freeSp and G.gold < spinCost()
    self.set(E.costLbl, 'cost', freeSp and ('免费 ×' .. S(G.freeSpins)) or (poor and '金币不够' or (S(spinCost()) .. ' 金币')))
    E.lever:toggleClass('poor', poor)
    local fightLbl = G.phase == 'battle' and ((G.speed == 1) and '加速 ×2' or '恢复 ×1') or '开战'
    self.set(E.fight, 'fight', fightLbl)
    E.fight:setDisabled(not (prep or G.phase == 'battle'))
    E.fight:toggleClass('alt', G.phase == 'battle')
    local lm = OR(G.luckMax, 3)
    local pips = {}
    for i = 0, lm - 1 do pips[#pips + 1] = '<i class="' .. (i < G.luck and 'on' or '') .. '"></i>' end
    local luck = '<span>幸运</span>' .. table.concat(pips) .. (T(G.luck) and ('<em class="lkv">★+' .. S(G.luck * LUCK_BONUS) .. '</em>') or '') .. '<small>' .. (T(G.luck) and ('★ 出现率提升 ' .. S(G.luck * LUCK_BONUS)) or '空转一次积累 1 点，提高 ★ 出现率') .. '</small>'
    -- 拉杆集点：一直显示在幸运下面（更新）；还没解锁时提示去哪里解锁
    local sg = stampGoal()
    -- 护栏：集点目标来自圣物/强化效果，异常值会让下面的 for 循环跑海量次。正常上限个位数。
    if T(sg) and sg > 64 then print('[拉杆军团] 集点护栏触发：stampGoal=' .. tostring(sg)); sg = 64 end
    if T(sg) then
        local sp = {}
        for i = 0, sg - 1 do sp[#sp + 1] = '<i class="' .. (i < G.paidSpins and 'on' or '') .. '"></i>' end
        luck = luck .. '<span class="stamps"><span>集点</span>' .. table.concat(sp) .. '<small>' .. S(G.paidSpins) .. '/' .. S(sg) .. '<span class="lx">，集满送 1 次免费拉杆</span>' .. (T(G.freeSpins) and ('（免费 ×' .. S(G.freeSpins) .. '）') or '') .. '</small></span>'
    elseif not G.tutorial then
        luck = luck .. '<span class="stamps off"><span>集点</span><small>未解锁<span class="lx">：主页「军团强化」或商店「集点卡」</span></small></span>'
    end
    self.set(E.luck, 'luck', luck, true)
    -- 本局额度限制仍然有效；今日广告额度用完不再锁按钮，改成点一下直接发奖
    local adLeft = AD_SPIN_MAX - G.adSpins
    E.adSpin:setDisabled(not prep or adLeft <= 0)
    local adFree = Ads.available() and adLeftToday() <= 0
    self.set(E.adSpinNum, 'adSpinNum', (adLeft <= 0) and '本局已用完' or (adFree and '今日免费' or ('剩 ' .. S(math.max(0, adLeft)) .. ' 次')))
    self.set(E.info, 'info', self.infoHTML(units), true)
    if UI.updateItemBar then UI.updateItemBar() end
    if UI.updateRuleBar then UI.updateRuleBar() end
end

function UI.infoHTML(units)
    local battlefield = (G.phase == 'battle') and G.battle or nil
    if battlefield and G.sel then
        local selectedEnt = nil
        battlefield.ents:forEach(function(e)
            if e.side == 'p' and e.unit == G.sel and not e.dead then selectedEnt = e end
        end)
        if selectedEnt then
            local remaining = #battlefield.ents:filter(function(e) return not e.dead and e.side == 'e' end)
            return UI.unitInfoHTML(G.sel) .. '<br><span class="detail-state">战斗中 · 敌方剩余 ' .. S(remaining) .. '</span>'
        end
    elseif G.phase == 'prep' and G.sel and findSlot(G.sel) and not (drag and drag.moved) then
        return UI.unitInfoHTML(G.sel)
    end
    if G.phase == 'battle' and battlefield then
        local p = #battlefield.ents:filter(function(e) return not e.dead and e.side == 'p' end)
        local e = #battlefield.ents:filter(function(e) return not e.dead and e.side == 'e' end)
        return '战斗中：我方剩余 <b>' .. S(p) .. '</b>，敌方剩余 <b>' .. S(e) .. '</b>；点击我方角色查看详情' .. (UI.rosterHTML and UI.rosterHTML(battlefield, p, e) or '')
    end
    if G.phase == 'spinning' or G.phase == 'resolving' then return '转轴转动中……' end
    if drag and drag.moved then
        local t = drag.over and getSlot(drag.over)
        if t and t ~= drag.u then
            if canAbsorb(drag.u, t) then
                local g = absorbGain(drag.u, t)
                local pv = previewAbsorb(t, g)
                local half = '' -- 异职业吸收不再减半，保留高星 / 品质损失提示。
                local tail = pv.awaken and ('，<b class="up">升到 ' .. starStr(3) .. '，可以' .. (canPromote(t) and '转职或晋升' or '转职') .. '！</b>')
                    or (pv.star > t.star and ('，<b class="up">升到 ' .. starStr(pv.star) .. '</b>') or '')
                local lose = (drag.u.q or 0) > (t.q or 0) and ('<br><span style="color:#ff9b8c">注意：' .. QUAL[drag.u.q].name .. '品质会随它一起消失，吸收者保持' .. QUAL[t.q or 0].name .. '品质</span>') or ''
                local starLose = needsAbsorbConfirm(drag.u, t) and ('<br><span style="color:#ff9b8c">注意：' .. starStr(drag.u.star) .. ' 喂给 ' .. starStr(t.star) .. '，多出的星级会损失，松手后需要确认</span>') or ''
                return '松手：' .. qSpan(drag.u) .. ' 被 <b>' .. qSpan(t) .. '</b> 吸收，经验 +' .. S(g) .. half .. tail .. lose .. starLose
            end
            return '松手：与 ' .. qSpan(t) .. ' 交换位置（' .. starStr(3) .. ' 和已转职的单位不能再吸收）'
        end
        return drag.over and '松手：移动到这个格子' or '拖到格子里放置；拖到其他单位身上，它会被吸收'
    end
    local tip = G.phase == 'battle'
        and (#(G.battle and G.battle.ents:filter(function(e) return not e.dead and e.side == 'p' end) or A()) .. ' 名我方单位在战斗；点击我方角色查看详情')
        or (T(units) and '点选单位查看属性；把一个单位拖到另一个单位身上，它会被吸收并转化为经验'
            or '先拉杆召唤单位：横、竖、斜任意一条线连成 3 个相同图标即可召唤')
    local fresh = js.uniq(currentLineup():map(function(e) return e.type end)):filter(function(t) return ENEMIES[t].desc and not G.seen:has(t) end)
    if #fresh > 0 then
        -- foe-desc：窄信息栏（超宽比手机）时截断到 2 行，避免长说明挤占战场
        return tip .. fresh:map(function(t) return '<br><span class="foe-desc"><b class="foe">新敌人 ' .. ENEMIES[t].name .. '</b>：' .. ENEMIES[t].desc .. '</span>' end):join('')
    end
    return tip
end

function UI.unitInfoHTML(u)
        local st = unitStats(u)
        local Af = AFFIXES:find(function(a) return a.id == u.affix.id end)
        local Q = AFFIX_GRADE[u.affix.q]
        local SK = SKILLS[st.skill]
        if isSup(u) then
            local SQ = QUAL[Q_SUP]
            local where = findSlot(u).t == 'b' and '（备战席，不参战）' or ''
            return '<b>' .. qSpan(u) .. '</b>' .. where .. ' 生命 ' .. S(st.hp) .. '，攻击 ' .. S(st.atk) .. '，每秒攻击 ' .. js.toFixed(1 / st.cd, 2) .. ' 次，<b class="supline">超凡角色，不用转职</b>' ..
                '<br>词条 <span style="color:' .. Q.color .. '">' .. Af.name .. '（' .. Q.name .. '）：' .. Af.fmt(u.affix.v) .. '</span>；技能「' .. SK.name .. '」' .. SK.desc .. '<br>被动 ' .. BRANCHES[u.branch].passive ..
                '<br>品质 <span style="color:' .. SQ.color .. '">' .. SQ.name .. '</span>：基础属性 +' .. S(pct(SQ.base)) .. '%，超凡之力全属性 +' .. S(pct(SQ.awaken)) .. '%；每个兵种同时只能有一个，不能被吸收' .. UI.equipLine(u)
        end
        local q = u.q or 0
        local UQ, NQ, up = QUAL[q], QUAL[q + 1], canPromote(u)
        local qName = '品质 <span style="color:' .. UQ.color .. '">' .. UQ.name .. '</span>：' .. (T(q) and ('基础属性 +' .. S(pct(UQ.base)) .. '%；') or '')
        local promo = up and ('，或不转职晋升为 <span style="color:' .. NQ.color .. '">' .. NQ.name .. '</span> ' .. starStr(PROMOTE_STAR)) or ''
        local qline
        if not u.branch then qline = '<br>' .. qName .. '升到 ' .. starStr(3) .. ' 可转职为 ' .. routeNames(u.cls, q) .. '（全属性 +' .. S(pct(UQ.awaken)) .. '%）' .. promo
        elseif T(q) then qline = '<br>' .. qName .. '转职全属性 +' .. S(pct(UQ.awaken)) .. '%'
        else qline = '' end
        local exp
        if u.branch then exp = '已转职'
        elseif u.awakenReady or u.star >= 3 then exp = '<b class="up">' .. (up and '可以转职或晋升' or '可以转职') .. '</b>'
        else exp = '经验 ' .. S(u.pts) .. '/' .. S(STAR_PTS[u.star + 1]) .. '，到 ' .. starStr(3) .. ' 即可' .. (up and '转职或晋升' or '转职') end
        local where = findSlot(u).t == 'b' and '（备战席，不参战）' or ''
        local br = u.branch and ('<br>被动 ' .. BRANCHES[u.branch].passive) or ''
        return '<b>' .. qSpan(u) .. '</b>' .. where .. ' 生命 ' .. S(st.hp) .. '，攻击 ' .. S(st.atk) .. '，每秒攻击 ' .. js.toFixed(1 / st.cd, 2) .. ' 次，' .. exp ..
            '<br>词条 <span style="color:' .. Q.color .. '">' .. Af.name .. '（' .. Q.name .. '）：' .. Af.fmt(u.affix.v) .. '</span>；技能「' .. SK.name .. '」' .. SK.desc .. br .. qline .. UI.equipLine(u)
    end

UI.bannerT = nil
function UI.banner(text, tone)
    local b = UI.els.banner; if not b then return end
    b:setText(text); b:setClassName('banner show ' .. (tone or ''))
    clearTimeout(UI.bannerT)
    UI.bannerT = setTimeout(function() b:setClassName('banner ' .. (tone or '')) end, 1300)
end
UI.toastT = nil
function UI.toast(text)
    local t = UI.els.toast; if not t then return end
    t:setText(text); t:addClass('show')
    clearTimeout(UI.toastT)
    UI.toastT = setTimeout(function() t:removeClass('show') end, 1600)
end
function UI.pullLever() local l = UI.els.lever; l:removeClass('pulled'); reflow(); l:addClass('pulled') end
function UI.supFlash(x, y)
    if REDUCED then return end
    local f = doc().body:querySelector('.field-frame'); if not f then return end
    f:setStyle('--fx', js.toFixed(x / AW * 100, 1) .. '%'); f:setStyle('--fy', js.toFixed(y / AH * 100, 1) .. '%')
    f:removeClass('supflash'); reflow(); f:addClass('supflash')
end
function UI.shakeCabinet() if REDUCED then return end local c = UI.els.cabinet; c:removeClass('jackpot'); reflow(); c:addClass('jackpot') end
function UI.bumpGold() local g = UI.els.goldBox; g:removeClass('bump'); reflow(); g:addClass('bump') end
--- FX.skill 的界面部分：技能名气泡
function UI.skillPop(e, name)
    local layer = UI.els and UI.els.skillLayer
    if not layer or layer:childElementCount() > 6 then return end
    local DOM = require("ui.dom")
    local d = DOM.newElement('span')
    d:setClassName('skill-pop ' .. e.side .. (e.sup and ' sup' or ''))
    d:setText(name)
    d:setStyle('left', S(e.x / AW * 100) .. '%')
    d:setStyle('top', S((e.y - 17) / AH * 100) .. '%')
    layer:appendChild(d)
    setTimeout(function() d:remove() end, 950)
end

function UI.modal(title, body, btn, onClick)
    local E = UI.els
    E.mTitle:setText(title); E.mBody:setHTML(body)
    E.mTitle.parent:removeClass('wide', 'stk')
    E.mBtn:setHidden(not btn); E.mBtn:setDisabled(false)
    local clicked = false
    if btn then
        E.mBtn:setText(btn)
        E.mBtn.onclick = function()
            if clicked then return end
            clicked = true
            Sound.init(); E.overlay:setHidden(true); if onClick then onClick() end
        end
    end
    E.overlay:setHidden(false)
    setTimeout(function()
        local f = btn and E.mBtn or E.mBody:querySelector('button:not(:disabled)')
        if f then focusEl(f) end
    end, 30)
end

--- 带两个按钮的确认弹窗：body 里自带按钮时用这个（如吞噬高星单位）
---@param yesId string
---@param noId string
---@param onYes fun()
---@param onNo? fun()
function UI.confirm2(title, body, yesId, yesText, noId, noText, onYes, onNo)
    local E = UI.els
    E.mTitle:setText(title); E.mBody:setHTML(body)
    E.mTitle.parent:removeClass('wide', 'stk')
    E.mBtn:setHidden(true)
    E.overlay:setHidden(false)
    local yes, no = _id(yesId), _id(noId)
    -- 一个确认框只认一次点击：手机上好几次点击会挤在同一帧里到达，
    -- 不加锁会让 onYes 跑两遍（广告被请求两次、奖励发两次）。
    local chosen = false
    local function once(fn)
        return function()
            if chosen then return end
            chosen = true
            Sound.init(); E.overlay:setHidden(true)
            if fn then fn() end
        end
    end
    if yes then yes:setText(yesText); yes.onclick = once(onYes) end
    if no then no:setText(noText); no.onclick = once(onNo) end
    setTimeout(function() if yes then focusEl(yes) end end, 30)
end

-- ---------- 激励视频广告 ----------
--- 看广告前的确认框：点「看广告」才真正播放
--- 非手机宿主上没有真广告，这里直接发奖，方便在 PC / Web 上试玩
---@param title string
---@param body string
---@param note? string 附加说明（如本局已用次数）
---@param grant fun(): boolean 发奖，返回 false 表示不发
---@param after? fun() 发奖后的界面动作
---@param onCancel? fun() 玩家放弃时的收尾
function UI.showAdConfirm(title, body, note, grant, after, onCancel)
    local run = G
    local done = false
    local function reward()
        if done or G ~= run then return end
        done = true
        if grant() and after then after() end
    end
    local function giveUp()
        if done or G ~= run then return end
        done = true
        if onCancel then onCancel() else UI.modal('没拿到奖励', '<p>广告暂时不可用，请稍后再试。</p>', '知道了', nil) end
    end
    -- 今天的广告额度已用完：不再播广告，直接发放奖励（当天剩余次数内都免费）
    if Ads.available() and adLeftToday() <= 0 then
        print('[拉杆军团] 今日广告额度已用完，直接发放奖励：' .. tostring(title))
        UI.modal(title, '<p>' .. body .. '</p><p class="dim">今日广告次数已用完，直接领取奖励。</p>', '领取', reward)
        return
    end
    if not Ads.available() then
        UI.modal(title, '<p>' .. body .. '</p><p class="dim">当前不是手机环境，直接发放奖励。</p>', '领取', reward)
        return
    end
    -- 播广告会占用一次当日额度；真正播放前扣，防止确认框停留期间被别的广告用完
    local function playAndReward()
        if done or G ~= run then return end
        if not adTakeSlot() then
            -- 期间额度被别人用完：改成直接发奖
            reward()
            return
        end
        UI.playAd(reward, giveUp)
    end
    UI.confirm2(title,
        '<p>' .. body .. '</p>' .. (note and ('<p class="dim">' .. note .. '</p>') or '') ..
        '<p class="warn">只有完整看完广告才能拿到奖励，中途关闭不会发放。</p>' ..
        '<div class="confirm"><button class="btn" id="adGo">看广告</button><button class="btn alt" id="adNo">暂不</button></div>',
        'adGo', '看广告', 'adNo', '暂不',
        playAndReward,
        giveUp)
end

--- 播放广告并显示进度；成功时静默收起，失败时提示原因
---@param onOk fun()
---@param onFail? fun()
function UI.playAd(onOk, onFail)
    local E, run = UI.els, G
    -- 已经有一个广告在播（真机上重复点击会走到这里）：直接忽略，不要再开一个「播放中」框
    if Ads.busy then return end
    E.mTitle:setText('广告')
    E.mBody:setHTML('<p>广告播放中……完整看完即可领取奖励。</p>')
    E.mBtn:setHidden(true)
    E.overlay:setHidden(false)
    Ads.show(function(ok, msg)
        if G ~= run then return end
        E.overlay:setHidden(true)
        E.mBody:setHTML('')
        if ok then onOk(); return end
        print('[拉杆军团] 广告未完成：' .. tostring(msg))
        if onFail then onFail(); return end
        local why
        if msg == 'manual close' or msg == 'embed manual close' then why = '需要完整看完广告才能领取奖励。'
        elseif msg == 'busy' then why = '上一段广告还没结束，请稍等几秒再点。'
        elseif msg == 'timeout' then why = '广告加载超时了，请稍后再试。'
        else why = '广告暂时不可用，请稍后再试。' end
        UI.modal('没拿到奖励', '<p>' .. why .. '</p>', '知道了', nil)
    end)
end

--- 最后一滴血战败：先给一次看广告复活的机会，放弃或广告失败才正常结算
---@param res table finishBattle 的结果
function UI.showRevive(res)
    local run = G
    local function giveUp() if G == run then UI.leaveRevive(res); UI.showResult(res) end end
    local free = Ads.available() and adLeftToday() <= 0
    UI.showAdConfirm('复活机会',
        free and '军团覆灭。今日广告次数已用完，<b>直接复活</b>：回到 <b>1 点生命</b>，这一波重打。'
            or '军团覆灭。看一段广告就能复活：回到 <b>1 点生命</b>，这一波重打。',
        '本局复活广告 ' .. S(G.adRevives) .. '/' .. S(AD_REVIVE_MAX) .. ' 次',
        function() return G == run and G.phase == 'gameover' and not G.settled and G.adRevives < AD_REVIVE_MAX end,
        function() adRevive(true) end,
        giveUp)
end

--- 高星单位喂给低星吸收者：星级会永久损失，先确认
function UI.confirmAbsorb(src, dst, apply)
    local gain = absorbGain(src, dst)
    local pv = previewAbsorb(dst, gain)
    local tail = pv.awaken and ('，<b class="up">升到 ' .. starStr(3) .. '，可以' .. (canPromote(dst) and '转职或晋升' or '转职') .. '！</b>')
        or (pv.star > dst.star and ('，<b class="up">升到 ' .. starStr(pv.star) .. '</b>') or '')
    UI.confirm2('要用高星单位当经验吗？',
        '<p><b>' .. qSpan(src) .. '</b> 会被 <b>' .. qSpan(dst) .. '</b> 吞噬，经验 +' .. S(gain) .. tail .. '。</p>' ..
        '<p class="warn">被吞噬的是 ' .. starStr(src.star) .. ' 单位，吸收者只有 ' .. starStr(dst.star) .. '：多出来的星级会直接损失，不能退回。</p>' ..
        '<div class="confirm"><button class="btn" id="cfYes">确认吞噬</button><button class="btn alt" id="cfNo">取消</button></div>',
        'cfYes', '确认吞噬', 'cfNo', '取消', apply)
end

function UI.showAwaken(u)
    local E = UI.els
    local q = u.q or 0
    local Q, C, up, routes = QUAL[q], CLASSES[u.cls], canPromote(u), CLASS_BRANCHES[u.cls][q]
    local function card(b)
        local B, Sk = BRANCHES[b], SKILLS[BRANCHES[b].skill]
        return '<button class="choice" data-b="' .. b .. '"' .. (T(q) and (' style="border-color:' .. Q.color .. '"') or '') .. '><img class="big" src="' .. iconURL(B.sprite or b, BRPAL[b], 'br:' .. b) .. '" alt=""><b>' .. B.name .. '</b>' ..
            '<span class="tag">' .. (T(q) and ('<span style="color:' .. Q.color .. '">' .. Q.name .. '专属</span> · ') or '基础路线 · ') .. B.role .. '</span><span class="pass">被动：' .. B.passive .. '</span><span class="sk">技能「' .. Sk.name .. '」：' .. Sk.desc .. '</span></button>'
    end
    local promo = ''
    if up then
        local NQ = QUAL[q + 1]
        local cur = unitStats(u)
        local preview = js.assign({}, u, { q = q + 1, star = PROMOTE_STAR, pts = STAR_PTS[PROMOTE_STAR], awakenReady = false })
        -- upgradeAffix 含随机数，预览不可消耗本局 RNG；按晋升保底计算。
        local Af = AFFIXES:find(function(a) return a.id == u.affix.id end)
        local span = Af.max - Af.min
        local oldRatio = (span ~= 0) and (u.affix.v - Af.min) / span or 1
        local ratio = max(oldRatio, NQ.affix)
        preview.affix = { id = u.affix.id, v = round(Af.min + ratio * span), q = (ratio < 0.4) and 0 or (ratio < 0.7) and 1 or (ratio < 0.9) and 2 or 3 }
        local nxt = unitStats(preview)
        local more = (q + 1 < Q_MAX) and '，或者继续晋升' or ''
        promo = '<div class="or"><span>或者不转职</span></div><div class="choices solo">' ..
            '<button class="choice promote" data-promote="1" style="--qc:' .. NQ.color .. '"><img class="big" src="' .. qIconURL(u.cls, PROMOTE_STAR, q + 1) .. '" alt="">' ..
            '<b>晋升为' .. NQ.name .. C.name .. ' ' .. starStr(PROMOTE_STAR) .. '</b>' ..
            '<span class="tag">品质 +1 · 星级回到 ' .. starStr(PROMOTE_STAR) .. '，再吸收 ' .. S(STAR_PTS[3] - STAR_PTS[PROMOTE_STAR]) .. ' 点经验回到 ' .. starStr(3) .. '</span>' ..
            '<span class="pass">基础属性 +' .. S(pct(Q.base)) .. '% → +' .. S(pct(NQ.base)) .. '%，转职加成 +' .. S(pct(Q.awaken)) .. '% → +' .. S(pct(NQ.awaken)) .. '%，词条数值按' .. NQ.name .. '品质提升。再升到 ' .. starStr(3) .. ' 可转职为 <span style="color:' .. NQ.color .. '">' .. routeNames(u.cls, q + 1) .. '</span>' .. more .. '。</span>' ..
            '<span class="cost">晋升保底预览（词条可能更高）：生命 ' .. S(cur.hp) .. ' → ' .. S(nxt.hp) .. '，攻击 ' .. S(cur.atk) .. ' → ' .. S(nxt.atk) .. '</span></button></div>'
    end
    local intro = up
        and ('<p>二选一，选定后不能更改。转职：技能换成专属技能，星星变成王冠。晋升：品质升一级，从 ' .. starStr(PROMOTE_STAR) .. ' 重新练起，换来更强的品质路线。</p>')
        or ('<p>选择一条转职路线：技能换成专属技能，头顶的星星会变成王冠。选定后不能更改。' .. ((q == Q_MAX) and (Q.name .. '是晋升能到的最高品质，不能再晋升。') or '') .. '</p>')
    local qline = '<p class="qline" style="--qc:' .. Q.color .. '"><b>' .. Q.name .. '品质路线</b>：转职后全属性 +' .. S(pct(Q.awaken)) .. '%</p>'
    UI.modal((T(q) and Q.name or '') .. C.name .. starStr(3) .. ' ' .. (up and '转职或晋升' or '可以转职'),
        (G.tutorial and ('<p class="tut-note">教程：两种都可以试。<b>转职</b>立刻换上专属技能、全属性提升；<b>晋升</b>把品质升一级，但要从 ' .. starStr(PROMOTE_STAR) .. ' 重新练起，适合长期培养。</p>') or '') ..
        intro .. qline .. '<div class="choices n' .. S(#routes) .. '">' .. routes:map(card):join('') .. '</div>' .. promo, nil)
    E.mTitle.parent:addClass('wide')
    for _, btn in ipairs(E.mBody:querySelectorAll('.choice')) do
        btn:addEventListener('click', function()
            Sound.init(); E.overlay:setHidden(true)
            if btn:data('promote') then promote(u) else awaken(u, btn:data('b')) end
            G.sel = u
        end)
    end
end
function UI.backLabel() return UI.els.home:isHidden() and '回到战场' or '返回主页' end

-- ---------- 开局选兵种 ----------
function UI.showSquad(ch, diff)
    local E, C0 = UI.els, CHAPTERS[ch]
    local D0, sel, lim = C0.diffs[diff], loadSquad():filter(function(c) return classOpen(c) end), {}
    local function card(c)
        local C, sk, on = CLASSES[c], SKILLS[CLASS_SKILL[c]], sel:includes(c)
        local open = classOpen(c)
        return '<button class="sq-card' .. (on and ' on' or '') .. '" data-c="' .. c .. '" aria-pressed="' .. str(on) .. '" style="--qc:' .. CLASS_COLOR[c] .. '"' .. (open and '' or ' disabled') .. '>' ..
            '<img src="' .. iconURL(C.sprite, TIER_PAL[c][1], c .. '1') .. '" alt=""><b>' .. C.name .. '</b>' ..
            '<span class="tag">' .. KIND_NAME[C.kind] .. ' · ' .. (C.proj and '远程' or '近战') .. ' · ' .. C.note .. '</span>' ..
            '<span class="st">生命 ' .. S(C.hp) .. '　攻击 ' .. S(C.atk) .. '　射程 ' .. S(C.range) .. '</span>' ..
            '<span class="sk">' .. (open and '' or ('<span style="color:#ff9b8c">' .. classLockText(c) .. '。</span>')) .. '技能「' .. sk.name .. '」：' .. sk.desc .. '</span><i class="tick">✓</i></button>'
    end
    local function refresh()
        for _, b in ipairs(_id('sqGrid'):querySelectorAll('.sq-card')) do
            local on = sel:includes(b:data('c')); b:toggleClass('on', on); b:setAttribute('aria-pressed', str(on))
        end
        local ok, why = limitsOK(sel, lim, ch)
        _id('sqCount'):setText('已选 ' .. S(#sel) .. '/' .. S(SQUAD_N) .. ((#sel == SQUAD_N and not ok) and ('（' .. why .. '）') or ''))
        E.mBtn:setDisabled(#sel ~= SQUAD_N or not ok)
        for _, pair in ipairs({ { 'limBan', 'ban' }, { 'limOne', 'oneRanged' } }) do
            local b = _id(pair[1]); if b then b:toggleClass('on', not not lim[pair[2]]); b:setAttribute('aria-pressed', str(not not lim[pair[2]])) end
        end
    end
    local limHTML = ''
    if diff == #C0.diffs - 1 then
        limHTML = '<div class="sq-bar"><span>炼狱词缀（可选，每个军魂 ×' .. S(AFFIX_SOUL) .. '）</span><span>' ..
            '<button class="chip" id="limBan" aria-pressed="false">' .. AFFIX_LIMITS.ban.desc(ch) .. '</button> ' ..
            '<button class="chip" id="limOne" aria-pressed="false">' .. AFFIX_LIMITS.oneRanged.desc(ch) .. '</button></span></div>'
    end
    UI.modal('组建军团',
        '<p>' .. C0.name .. '「' .. D0.name .. '」。选 ' .. S(SQUAD_N) .. ' 个兵种出征：这一局的老虎机里<b>只会出现这 ' .. S(SQUAD_N) .. ' 种图标</b>，★ 依然可以替代任何一种。</p>' ..
        rulesHTML(ch) .. limHTML ..
        '<div class="sq-bar"><span id="sqCount"></span><span><button class="chip" id="sqRand">随机 ' .. S(SQUAD_N) .. ' 个</button> <button class="chip" id="sqBack">重选难度</button></span></div>' ..
        '<div class="sq-grid" id="sqGrid">' .. CLASS_KEYS:map(card):join('') .. '</div>', '出征',
        function()
            if #sel ~= SQUAD_N or not limitsOK(sel, lim, ch) then return end
            sel = validSquad(sel); saveSquad(sel)
            PENDING_LIMITS = (lim.ban or lim.oneRanged) and lim or nil
            restart(ch, diff, sel)
        end)
    E.mTitle.parent:addClass('wide', 'stk')
    for _, b in ipairs(_id('sqGrid'):querySelectorAll('.sq-card')) do
        b:addEventListener('click', function()
            if b:isDisabled() then return end
            Sound.init()
            local c = b:data('c')
            if sel:includes(c) then sel = sel:filter(function(x) return x ~= c end)
            else sel:push(c); if #sel > SQUAD_N then sel:shift() end end
            refresh()
        end)
    end
    _id('sqRand'):addEventListener('click', function()
        Sound.init()
        local pool = CLASS_KEYS:filter(function(c) return classOpen(c) and not (lim.ban and c == chRules(ch).ban) end)
        pool = pool:sort(function() return js.random() - 0.5 end)
        local ranged = 0
        sel = A()
        pool:forEach(function(c)
            local isRanged = not not CLASSES[c].proj
            if #sel < SQUAD_N and (not lim.oneRanged or not isRanged or ranged == 0) then
                sel:push(c); if isRanged then ranged = ranged + 1 end
            end
        end)
        refresh()
    end)
    for _, pair in ipairs({ { 'limBan', 'ban' }, { 'limOne', 'oneRanged' } }) do
        local b = _id(pair[1])
        if b then b:addEventListener('click', function() Sound.init(); lim[pair[2]] = not lim[pair[2]]; refresh() end) end
    end
    _id('sqBack'):addEventListener('click', function() Sound.init(); UI.showStart('', '开始游戏') end)
    refresh()
end

-- ---------- 局外成长：军团强化 ----------
UI.forgeTab = 'eco'
--- 收起复活弹窗、放行到正常结算（复活机会只有一次）
function UI.leaveRevive(res)
    UI.els.overlay:setHidden(true)
    if res and res.revivable then
        res.revivable = false
        if not G.tutorial and not G.settled then
            saveBest(G.ch, G.diff, res.wave - 1)
            res.soul = settleRun('lose')
        end
    end
end

function UI.soulLine(s)
    if not s or not T(s.total) then return '' end
    local parts = A('守住 ' .. S(s.waves) .. ' 波 ' .. S(s.base))
    if T(s.bonus) then parts:push('通关奖励 ' .. S(s.bonus)) end
    if T(s.first) then parts:push('首次通关 ' .. S(s.first)) end
    local doubled = s.doubled and '<span class="dbl">已翻倍</span>' or ''
    -- 今日广告额度用完时按钮仍在，文案改成「免费」直接领取
    local adFree = Ads.available() and adLeftToday() <= 0
    local adDoubleHtml = ((not s.doubled and G.adDouble < AD_DOUBLE_MAX) and
        ('<p class="adline"><button class="chip ad" id="adDouble">' .. (adFree and '免费 · 军魂翻倍' or '看广告 · 军魂翻倍') ..
        '</button><span>再拿 <b>' .. S(s.total) .. '</b> 军魂（每局 1 次）</span></p>') or '')
    return '<p class="soulline"><img src="' .. iconURL('m_soul') .. '" alt=""><span>本局获得 <b>' .. S(s.total) .. ' 军魂</b>' .. doubled .. '（' .. parts:join('，') .. '）</span><button class="chip go" id="goForge">去强化</button></p>' ..
        adDoubleHtml
end
function UI.bindForge()
    local b = _id('goForge')
    if b then b:addEventListener('click', function() Sound.init(); UI.showForge('eco', 'run') end) end
end
function UI.bindAdDouble(res)
    local s, run = res.soul, G
    local b = _id('adDouble')
    if not b or not s then return end
    b:addEventListener('click', function()
        Sound.init()
        if G ~= run or G.adDouble >= AD_DOUBLE_MAX or s.doubled then return end
        UI.showAdConfirm('军魂翻倍', '看一段广告，本局结算的 <b>' .. S(s.total) .. ' 军魂</b>翻倍。', '每局 1 次',
            function() return G == run and G.adDouble < AD_DOUBLE_MAX and not s.doubled end,
            function() adDouble(s); UI.showResult(res) end,
            function() if G == run then UI.showResult(res) end end)
    end)
end
function UI.homeForge()
    local b = _id('hForge'); if not b then return end
    _id('hSoul'):setHTML('<img src="' .. iconURL('m_soul') .. '" alt="">' .. S(META.s))
    b:toggleClass('dot', canBuyAny())
end
function UI.forgeRow(u)
    local l = upgLv(u.id)
    local mx = l >= u.max
    local cost = mx and 0 or u.cost[l]
    local can = not mx and META.s >= cost
    local pips = {}
    for i = 0, u.max - 1 do pips[#pips + 1] = '<i class="' .. (i < l and 'on' or '') .. '"></i>' end
    local btn = mx and '<button class="mu-buy" disabled>已满级</button>'
        or ('<button class="mu-buy" data-u="' .. u.id .. '"' .. (can and '' or ' disabled') .. '>' .. (can and '升级' or '军魂不足') .. '<small><img src="' .. iconURL('m_soul') .. '" alt="">' .. S(cost) .. '</small></button>')
    local ico = u.cls and iconURL(CLASSES[u.cls].sprite, TIER_PAL[u.cls][1], u.cls .. '1') or iconURL(u.icon)
    return '<div class="mu-row' .. (mx and ' max' or '') .. '"><img class="mu-ico" src="' .. ico .. '" alt=""><div class="mu-main">' ..
        '<div class="mu-head"><b>' .. u.name .. '</b><span class="mu-pips" role="img" aria-label="等级 ' .. S(l) .. '/' .. S(u.max) .. '">' .. table.concat(pips) .. '</span><span class="mu-lv">Lv ' .. S(l) .. '/' .. S(u.max) .. '</span></div>' ..
        '<p>' .. u.note .. '</p><p class="now">当前：' .. u.txt(l) .. '</p>' .. (mx and '' or ('<p class="next">下一级：<b>' .. u.txt(l + 1) .. '</b></p>')) .. '</div>' .. btn .. '</div>'
end
function UI.forgeBody()
    local tabs = UPG_TABS:map(function(t)
        local k, n, ic = t[0], t[1], t[2]
        return '<button class="cx-tab" role="tab" data-t="' .. k .. '" aria-selected="' .. str(k == UI.forgeTab) .. '"><img src="' .. iconURL(ic) .. '" alt="">' .. n .. '</button>'
    end):join('')
    local spent = spentSouls()
    return '<div class="mu-bank"><img src="' .. iconURL('m_soul') .. '" alt=""><div><span class="num">' .. S(META.s) .. '</span><small>军魂</small></div>' ..
        '<p>每守住 1 波获得军魂，失败了也照算；通关和首次通关有额外奖励。</p></div>' ..
        '<div class="cx-tabs" role="tablist">' .. tabs .. '</div>' ..
        '<div class="mu-list">' .. UPG:filter(function(u) return u.tab == UI.forgeTab end):map(function(u) return UI.forgeRow(u) end):join('') .. '</div>' ..
        '<div class="mu-foot"><span>已投入 ' .. S(spent) .. ' 军魂，重置会全额返还</span><button class="chip" id="muReset"' .. (T(spent) and '' or ' disabled') .. '>重置并返还</button></div>'
end
function UI.showForge(tab, from)
    if tab then UI.forgeTab = tab end
    UI.modal('军团强化', '<div id="fg">' .. UI.forgeBody() .. '</div>', from == 'run' and '继续选关' or '返回主页',
        function() if from == 'run' then UI.showStart('', '开始游戏') else UI.homeForge() end end)
    UI.els.mTitle.parent:addClass('wide')
    UI.forgeBind()
end
function UI.forgeRefresh(focus)
    local fg = _id('fg'); if not fg then return end
    fg:setHTML(UI.forgeBody()); UI.forgeBind()
    local f = (focus and fg:querySelector('.mu-buy[data-u="' .. focus .. '"]:not(:disabled)')) or fg:querySelector('.cx-tab[aria-selected="true"]')
    if f then focusEl(f) end
end
function UI.forgeBind()
    local fg = _id('fg')
    for _, b in ipairs(fg:querySelectorAll('.cx-tab')) do
        b:addEventListener('click', function()
            Sound.init(); UI.forgeTab = b:data('t'); UI.forgeRefresh(); PAGE:setScrollTop(UI.els.mTitle.parent, 0)
        end)
    end
    for _, b in ipairs(fg:querySelectorAll('.mu-buy[data-u]')) do
        b:addEventListener('click', function()
            Sound.init()
            if buyUpg(b:data('u')) then Sound.play('star') else Sound.play('deny') end
            UI.forgeRefresh(b:data('u'))
        end)
    end
    local rs = _id('muReset')
    if rs then
        rs:addEventListener('click', function() -- 两步确认，3 秒内再点一次才重置
            Sound.init()
            if not rs:data('arm') then
                rs:setData('arm', '1'); rs:setText('再点一次确认重置')
                setTimeout(function() if rs:isConnected() then rs:setData('arm', nil); rs:setText('重置并返还') end end, 3000)
            else resetUpgs(); Sound.play('absorb'); UI.forgeRefresh() end
        end)
    end
end

function UI.homeProg()
    return CHAPTERS:map(function(C, c)
        local Sv, open = SAVE[c], chOpen(c)
        local n = #C.diffs:filter(function(_, d) return (Sv.cleared & (1 << d)) ~= 0 end)
        local P = CHAPTERS[c - 1]
        local pips = C.diffs:map(function(Dd, d) return '<i class="' .. (((Sv.cleared & (1 << d)) ~= 0) and 'on' or '') .. '" style="--dc:' .. Dd.color .. '" title="' .. Dd.name .. '"></i>' end):join('')
        return '<div class="hp-row' .. (open and '' or ' locked') .. '" style="--cc:' .. C.color .. '"><b>' .. C.name .. '</b><span>' .. C.title .. '</span>' ..
            (open and ('<span class="pips" role="img" aria-label="已通关 ' .. S(n) .. '/' .. S(#C.diffs) .. ' 个难度">' .. pips .. '</span>') or ('<small>通关' .. P.name .. '「' .. P.diffs[0].name .. '」后解锁</small>')) .. '</div>'
    end):join('')
end
HOME_TRACKS = A('home_a', 'home_b', 'home_c')
UI.homeIdx = -1
function UI.showHome()
    local E = UI.els
    -- 每次回到主页换下一首主页曲（第一次随机）
    if UI.homeIdx < 0 then UI.homeIdx = floor(js.random() * #HOME_TRACKS) else UI.homeIdx = (UI.homeIdx + 1) % #HOME_TRACKS end
    UI.homeTrack = HOME_TRACKS[UI.homeIdx]
    TUT.stop(); E.overlay:setHidden(true); drag = nil; G.sel = nil
    _id('hProg'):setHTML(UI.homeProg())
    UI.homeForge()
    local fresh = store.get(TUT_KEY) ~= '1'
    _id('hTut'):toggleClass('rec', fresh)
    E.home:setHidden(false)
    setTimeout(function() focusEl(_id(fresh and 'hTut' or 'hPlay')) end, 30)
    if T(META.notice) then
        local n = META.notice; META.notice = 0
        UI.modal('军团强化 开启', '<p class="soulline"><img src="' .. iconURL('m_soul') .. '" alt=""><span>按你已有的进度补发了 <b>' .. S(n) .. ' 军魂</b></span></p>' ..
            '<p>之后每守住一波都会获得军魂，失败了也照算。主页的「军团强化」里可以把军魂换成永久加成。</p>', '知道了')
    elseif T(META.refund) and META.refundKind == 'cheap3' then
        local n = META.refund; META.refund = 0; META.refundKind = nil
        UI.modal('拉杆集点 已调整', '<p class="soulline"><img src="' .. iconURL('m_soul') .. '" alt=""><span>退还了 <b>' .. S(n) .. ' 军魂</b></span></p>' ..
            '<p>拉杆集点改为：Lv 1 每付费拉杆 ' .. S(CHEAP_EVERY[1]) .. ' 次送 1 次免费拉杆，Lv 2 每 ' .. S(CHEAP_EVERY[2]) .. ' 次送 1 次，价格上调。你之前买的等级已按原价全额退还，可以在「军团强化」里重新购买。</p>' ..
            '<p>天赋树新增「人类 / 动物 / 植物」三页：每个兵种可以单独强化生命和攻击，每级 +1%，最高 +5%。</p>', '知道了')
    elseif T(META.refund) then
        local n = META.refund; META.refund = 0
        UI.modal('拉杆折扣 已改为 拉杆集点', '<p class="soulline"><img src="' .. iconURL('m_soul') .. '" alt=""><span>退还了 <b>' .. S(n) .. ' 军魂</b></span></p>' ..
            '<p>每付费拉杆 ' .. S(CHEAP_EVERY[1]) .. ' 次送 1 次免费拉杆（Lv 2：每 ' .. S(CHEAP_EVERY[2]) .. ' 次）。你之前买的折扣已经换成集点 Lv 1，差价退回。</p>', '知道了')
    end
end
function UI.confirmHome()
    local busy = not TUT.on and (G.wave > 1 or G.stats.spins > 0) and G.phase ~= 'victory' and G.phase ~= 'gameover'
    if not busy then return UI.showHome() end
    local half = floor(G.soulPend * SOUL_ABANDON)
    UI.modal('回到主页？', '<p>这一局的进度不会保存：现在是' .. curCh().name .. '「' .. curDiff().name .. '」第 ' .. S(G.wave) .. ' 波。</p>' ..
        (T(G.soulWaves) and ('<p class="soulline"><img src="' .. iconURL('m_soul') .. '" alt=""><span>已守住 ' .. S(G.soulWaves) .. ' 波。现在回主页只能拿 <b>' .. S(half) .. ' 军魂</b>，打完这一局能拿全额。</span></p>') or '') ..
        '<div class="confirm"><button class="btn" id="cfYes">回到主页</button><button class="btn alt" id="cfNo">继续这局</button></div>', nil)
    _id('cfYes').onclick = function() Sound.init(); settleRun('abandon'); UI.showHome() end
    _id('cfNo').onclick = function() UI.els.overlay:setHidden(true) end
end

-- ---------- 图鉴 ----------
UI.cxTab = 'warrior'
function UI.codexHTML(tab)
    local tabs = CLASS_KEYS:map(function(c) return A(c, CLASSES[c].name, iconURL(CLASSES[c].sprite, TIER_PAL[c][1], c .. '1')) end)
    tabs:push(A('foes', '敌人', iconURL('boss')))
    tabs:push(A('items', '道具', iconURL('i_bag')))
    return '<div class="cx-tabs" role="tablist">' .. tabs:map(function(t)
        local k, n, ic = t[0], t[1], t[2]
        return '<button class="cx-tab" role="tab" data-t="' .. k .. '" aria-selected="' .. str(k == tab) .. '"><img src="' .. ic .. '" alt="">' .. n .. '</button>'
    end):join('') .. '</div>' .. '<div id="cx">' .. UI.codexBody(tab) .. '</div>'
end
function UI.codexBody(tab)
    if tab == 'foes' then return UI.codexFoes() end
    if tab == 'items' then return UI.codexItems() end
    local C = CLASSES[tab]
    local function skill(Sk) return '<p class="sk">技能「' .. Sk.name .. '」：' .. Sk.desc .. '<i>（约 ' .. S(ceil(100 / Sk.charge)) .. ' 次攻击蓄满）</i></p>' end
    local base = '<div class="cx-q" style="--qc:' .. CLASS_COLOR[tab] .. '"><b>基础职业</b>召唤出来的形态，★★ 属性 ×' .. S(STAR_MULT[2]) .. '，★★★ 属性 ×' .. S(STAR_MULT[3]) .. '；每吞噬 1 点经验属性都会往下一星涨一截</div>' ..
        '<div class="cx-grid"><div class="cx-card" style="--qc:' .. CLASS_COLOR[tab] .. '"><img src="' .. iconURL(C.sprite, TIER_PAL[tab][1], tab .. '1') .. '" alt=""><b>' .. C.name .. '</b>' ..
        '<span class="tag">' .. KIND_NAME[C.kind] .. ' · ' .. (C.proj and '远程' or '近战') .. (C.splash and '，攻击带溅射' or '') .. ' · ' .. C.note .. (classOpen(tab) and '' or ('<br><span style="color:#ff9b8c">' .. classLockText(tab) .. '</span>')) .. '</span>' ..
        '<p>生命 ' .. S(C.hp) .. '，攻击 ' .. S(C.atk) .. '，每秒攻击 ' .. js.toFixed(1 / C.cd, 2) .. ' 次，射程 ' .. S(C.range) .. '</p>' .. skill(SKILLS[CLASS_SKILL[tab]]) .. '</div></div>'
    local quals = QUAL:slice(0, Q_MAX + 1):map(function(Q, q)
        local list = CLASS_BRANCHES[tab][q]
        local head = '<div class="cx-q" style="--qc:' .. Q.color .. '"><b>' .. Q.name .. '</b>' .. (T(q) and ('基础属性 +' .. S(pct(Q.base)) .. '%，') or '') .. '转职后全属性 +' .. S(pct(Q.awaken)) .. '%，' .. S(#list) .. ' 条' .. (T(q) and '专属' or '基础') .. '路线' .. ((q == Q_MAX) and '（晋升到此为止）' or '') .. '</div>'
        return head .. '<div class="cx-grid">' .. list:map(function(b)
            local B = BRANCHES[b]
            return '<div class="cx-card" style="--qc:' .. Q.color .. '"><img src="' .. iconURL(B.sprite or b, BRPAL[b], 'br:' .. b) .. '" alt=""><b>' .. B.name .. '</b><span class="tag">' .. B.role .. '</span>' ..
                '<p>被动：' .. B.passive .. '</p>' .. skill(SKILLS[B.skill]) .. '</div>'
        end):join('') .. '</div>'
    end):join('')
    local sk = SUPER_OF[tab]
    local SB, SQ = BRANCHES[sk], QUAL[Q_SUP]
    local sup = '<div class="cx-q sup" style="--qc:' .. SQ.color .. '"><b>' .. SQ.name .. '</b>只能从九格大奖获得，不用转职：基础属性 +' .. S(pct(SQ.base)) .. '%，超凡之力全属性 +' .. S(pct(SQ.awaken)) .. '%；免疫眩晕和魅惑；每个兵种同时只能有一个</div>' ..
        '<div class="cx-grid"><div class="cx-card sup" style="--qc:' .. SQ.color .. '"><img src="' .. iconURL(SB.sprite, BRPAL[sk], 'br:' .. sk) .. '" alt=""><b>' .. SB.name .. '</b><span class="tag">' .. SB.role .. '</span>' ..
        '<p>被动：' .. SB.passive .. '</p>' .. skill(SKILLS[SB.skill]) .. '</div></div>'
    return '<p class="dim">单位升到 ' .. starStr(3) .. ' 后，按自己的品质选一条转职路线；也可以不转职，晋升到下一品质再走更强的路线。九格大奖则直接降下这个兵种的超凡角色。</p>' .. base .. quals .. sup
end
function UI.codexFoes()
    local NOTE = { slime = '基础近战小怪', skeleton = '基础近战小怪', skelarcher = '躲在后排放箭的远程小怪', orc = '血厚攻高的近战',
        darkmage = '远程法术，落点有溅射', magmalet = '熔岩史莱姆分裂出来的小怪，跑得更快',
        pillar = '巨像护盾阶段召唤的固定炮台；三根全碎，巨像才会解除无敌' }
    return '<p class="dim">这里是基础数值，实战中会随波次和难度成长。</p>' .. CHAPTERS:map(function(K, c)
        local head = '<div class="cx-q" style="--qc:' .. K.color .. '"><b>' .. K.name .. '</b>' .. K.title .. '</div>'
        if not chOpen(c) then return head .. '<p class="dim">通关' .. CHAPTERS[c - 1].name .. '「' .. CHAPTERS[c - 1].diffs[0].name .. '」后解锁这一章的敌人图鉴。</p>' end
        return head .. '<div class="cx-grid">' .. ENEMY_KEYS:filter(function(t) return ENEMIES[t].ch == c end):map(function(t)
            local E = ENEMIES[t]
            local note = E.desc or NOTE[t] or ''
            return '<div class="cx-card" style="--qc:' .. (E.big and '#ff5a4a' or K.color) .. '"><img src="' .. iconURL(E.sprite, E.pal or nil, 'foe:' .. t) .. '" alt=""><b>' .. E.name .. '</b>' ..
                '<span class="tag">' .. (E.big and '首领，' or '') .. (E.proj and '远程' or (T(E.speed) and '近战' or '固定不动')) .. '</span><p>生命 ' .. S(E.hp) .. '，攻击 ' .. S(E.atk) .. '</p>' .. (note ~= '' and ('<p class="sk">' .. note .. '</p>') or '') .. '</div>'
        end):join('') .. '</div>'
    end):join('')
end
function UI.codexItems()
    local groups = A(A('relic', '圣物', '全局被动，最多 ' .. S(RELIC_SLOTS) .. ' 件，战斗外可以卖掉替换'), A('equip', '装备', '每个单位 3 个装备栏；另有按词条生成的词条装备（强攻、坚韧、迅捷、致命、嗜血），按品级加价'), A('cons', '消耗品', '最多 ' .. S(CONS_SLOTS) .. ' 件，在右侧道具栏点击使用；同一种每场限 1 次'))
    local head = '<p class="dim">道具在顶栏「商店」用秘银购买（每波战后发秘银、换新货，金币也能兑换），精英波（第 5、10、15 波）胜利后还能免费三选一，不满意可以免费刷新 1 次。价格：' ..
        QUAL:slice(0, 4):map(function(Q, q) return '<span style="color:' .. Q.color .. '">' .. Q.name .. '</span> ' .. S(SHOP_PRICE[q]) end):join('、') .. ' 秘银；出售返还一半。</p>'
    return head .. groups:map(function(g)
        return '<div class="cx-q" style="--qc:#e2b33c"><b>' .. g[1] .. '</b>' .. g[2] .. '</div><div class="cx-grid">' .. ITEM_KEYS:filter(function(k) return ITEMS[k].kind == g[0] end):map(function(k)
            local it = { id = k, rar = ITEMS[k].rar }
            local Q = QUAL[it.rar]
            return '<div class="cx-card" style="--qc:' .. Q.color .. '"><img src="' .. ((k == 'gear') and iconURL(ITEMS[k].icon) or itemIcon(it)) .. '" alt=""><b>' .. ITEMS[k].name .. '</b><span class="tag">' .. Q.name .. (ITEMS[k].grp and (' · ' .. ITEMS[k].grp) or '') .. '</span><p>' .. ((k == 'gear') and '额外词条：强攻、坚韧、迅捷、致命或嗜血；数值随词条品级生成，价格按品级 +0 / +2 / +4 / +8 秘银。' or itemDesc(it)) .. '</p></div>'
        end):join('') .. '</div>'
    end):join('')
end
function UI.showCodex(tab)
    local E = UI.els
    if tab then UI.cxTab = tab end
    UI.modal('图鉴', UI.codexHTML(UI.cxTab), UI.backLabel())
    local Mo = E.mTitle.parent; Mo:addClass('wide')
    local box, tabs = _id('cx'), E.mBody:querySelectorAll('.cx-tab')
    for _, btn in ipairs(tabs) do
        btn:addEventListener('click', function()
            UI.cxTab = btn:data('t')
            for _, x in ipairs(tabs) do x:setAttribute('aria-selected', str(x == btn)) end
            box:setHTML(UI.codexBody(UI.cxTab)); PAGE:setScrollTop(Mo, 0)
        end)
    end
    setTimeout(function() local f = E.mBody:querySelector('.cx-tab[aria-selected="true"]'); if f then focusEl(f) end end, 40)
end

-- ---------- 玩法说明 ----------
function UI.showHelp(first)
    local QN, SQ = QUAL:slice(0, Q_MAX + 1), QUAL[Q_SUP]
    local function sym(n) return '<img class="ico" src="' .. iconURL(n) .. '" alt="">' end
    local function hero(c) return '<img class="ico" src="' .. iconURL(CLASSES[c].sprite, TIER_PAL[c][1], c .. '1') .. '" alt="">' end
    local function qtags(list) return list:map(function(Q) return '<span class="qtag" style="color:' .. Q.color .. '">' .. Q.name .. '</span>' end):join(' → ') end
    local body = '\n      <div class="legend">\n        ' ..
        G.squad:map(function(c) return '<span>' .. sym(SYM_SPRITE[CLASS_SYM[c]]) .. '召唤' .. hero(c) .. CLASSES[c].name .. '</span>' end):join('') ..
        '\n        <span>' .. sym('sym_star') .. '可替代任何图标</span>\n      </div>\n' ..
        '      <p><b>兵种</b>：每局出征前，从 ' .. S(#CLASS_KEYS) .. ' 个兵种（人类、动物、植物、机械、龙族、元素）里选 ' .. S(SQUAD_N) .. ' 个。这一局的老虎机里只会出现你选的 ' .. S(SQUAD_N) .. ' 种图标，★ 仍然可以替代任何一种。选法不同，玩法完全不同。</p>\n' ..
        '      <p><b>拉杆</b>花 ' .. S(spinCost()) .. ' 金币。横、竖、斜共 8 条线，任意一条连成 3 个相同图标就召唤一个单位；三个 ★ 连线召唤 ★★ 单位，而且至少是稀有品质。没中奖会积累幸运，让 ★ 更容易出现。</p>\n' ..
        '      <p><b>品质</b>：每个召唤出的单位都有品质，' .. qtags(QN) .. '，身上的描边颜色就是品质。品质越高基础属性越高（' ..
        QN:slice(1):map(function(Q) return '<span class="qtag" style="color:' .. Q.color .. '">' .. Q.name .. '</span> +' .. S(pct(Q.base)) .. '%' end):join('，') ..
        '），转职时的全属性加成也越大（' .. QN:map(function(Q) return Q.name .. ' +' .. S(pct(Q.awaken)) .. '%' end):join('，') .. '）。</p>\n' ..
        '      <p><b>九格大奖</b>：九个格子全是同一种图标（★ 照样可以替代），这个兵种的<span class="qtag sup" style="color:' .. SQ.color .. '">' .. SQ.name .. '</span>角色直接降世：全新形象，自带强力技能，不用转职，免疫眩晕和魅惑，基础属性 +' .. S(pct(SQ.base)) .. '%、超凡之力全属性 +' .. S(pct(SQ.awaken)) .. '%。每个兵种同时只能有一个超凡角色：已经有了就改为本局另一个兵种，三个兵种都有了则召唤一个<span class="qtag" style="color:' .. QUAL[Q_MAX].color .. '">' .. QUAL[Q_MAX].name .. '</span> ★★★ 单位。超凡角色不能被当成经验吸收。</p>\n' ..
        '      <p><b>吸收</b>：把一个单位拖到另一个单位身上，它会被吸收成经验。<b>每吞噬一次属性都会上涨</b>（按经验进度往下一星的属性靠拢），同职业 3 个合成 ★★，9 个合成 ★★★；不同职业也能吸收，经验不再减半。吸收者保留自己的品质，被吸收的品质会消失，所以让高品质单位当吸收者。每个单位还带一条随机词条，品质越高词条数值越好。</p>\n' ..
        '      <p><b>转职</b>：单位升到 ★★★ 立刻就能转职。<b>每种品质的转职路线都不一样</b>：普通只有 1 条基础路线，稀有、史诗、传说各有 2~3 条专属路线，机制完全不同（治疗、剧毒、反伤、炮塔、黑洞、时间静止、复活、巨人化……）。所有路线的被动和技能都可以在右上角「图鉴」里查看。</p>\n' ..
        '      <p><b>晋升</b>：升到 ★★★ 时也可以不转职，改为晋升品质：' .. qtags(QN) .. '。比如普通战士 ★★★ 晋升后变成稀有战士 ★★，再吸收 ' .. S(STAR_PTS[3] - STAR_PTS[PROMOTE_STAR]) .. ' 点经验回到 ★★★，但之后能走更强的品质路线。' .. QUAL[Q_MAX].name .. '是晋升能到的最高品质，只能转职。</p>\n' ..
        '      <div class="legend routes">' .. CLASS_KEYS:map(function(c)
            return '<span><b>' .. CLASSES[c].name .. '</b>' .. QN:map(function(Q, i) return '<span style="color:' .. Q.color .. '">' .. Q.name .. '</span> ' .. routeNames(c, i) end):join('；') .. '</span>'
        end):join('') .. '</div>\n' ..
        '      <p><b>技能</b>：战斗中每次攻击和受伤都会积攒能量（血条下方的蓝条），蓄满后自动释放技能。战士盾击眩晕，射手三连射，法师奥术爆裂；转职后换成专属技能。</p>\n' ..
        '      <p><b>开战</b>：只有阵地上的单位会参战，备战席上的不会。战士放前排，射手和法师放后排。撑过所有波次获胜，最后一波是首领波，生命耗尽则失败。</p>\n' ..
        '      <p><b>章节与难度</b>：每章 4 个难度，通关一个解锁下一个：' .. DIFFS1:map(function(d) return d.name .. '（' .. S(d.waves) .. ' 波）' end):join(' → ') ..
        '。通关一章的「' .. DIFFS1[0].name .. '」就解锁下一章：' .. CHAPTERS:map(function(C) return C.name .. '「' .. C.title .. '」' end):join(' → ') .. '，每章都是全新的敌人和首领。高难度会出现头顶红色感叹号的精英敌人。</p>\n' ..
        '      <p><b>战场规则</b>：从第二章起每章都有自己的规则——地裂、虚空侵蚀、毒雾、潮汐、暴风雪、狂风，以及封印格、高地格、沼泽格、祭坛格、冰面格等阵地格子，规则在组建军团时就会列出来，战场下方也有提示。炼狱难度还可以选「出征限制」词缀，每个词缀军魂 ×' .. S(AFFIX_SOUL) .. '。</p>\n' ..
        '      <p><b>新兵种</b>：古树卫士（植物坦克）、雷鹰（动物远程）、发条机兵（新类别「机械」）分别在通关第二、三、四章「普通」后解锁；吟游诗人（远程辅助）、幼龙（新类别「龙族」）、冰霜元素（新类别「元素」）在通关第七、八、九章「普通」后解锁。机械免疫流血、中毒和灼烧，但眩晕与冻结持续时间 +50%；龙族龙鳞减伤 10%；元素免疫减速和根植，阵亡时冰爆冻结周围敌人。</p>\n' ..
        '      <p><b>商店与秘银</b>：顶栏「商店」随时打开（不会自动弹出），用<b>秘银</b>买道具，和「装备管理」是同一个界面的两个页签。每波战后发秘银（赢了 3 + 波数/3，精英波 +3，无阵亡 +1，输了也有 2），货架同时换一批新货，有新货时「商店」按钮会亮起来；金币也可以按 ' .. S(GEM_RATE.gold) .. ' : ' .. S(GEM_RATE.gem) .. ' 兑换成秘银，但金币不能反过来换。货架 5 格：2 件圣物、1 件装备、1 件消耗品和 1 件打 7 折的特价商品；输掉的波次少 1 格。刷新从 2 秘银起每次 +1，每波可以免费锁定 1 件留到下一波，每波送 1 次免费刷新，无阵亡或打赢精英波再送 1 次。<b>圣物</b>是全局被动（' .. S(RELIC_SLOTS) .. ' 槽），<b>装备</b>每个单位 3 个装备栏（「商店 → 装备管理」查看谁带了什么），<b>消耗品</b>（' .. S(CONS_SLOTS) .. ' 槽）在右侧道具栏点击使用。锁轴手套、幸运骰在准备阶段使用，其余主动消耗品在战斗中使用，同种每场限 1 次，凤凰羽被动触发。出售返还 50% 秘银（当铺老板 75%）。完整道具见「图鉴 → 道具」。</p>\n' ..
        '      <p><b>军魂与军团强化</b>：每守住 1 波获得军魂，失败了也照算；通关再多拿一份，首次通关某个难度还有额外奖励。军魂在主页的「军团强化」里换成永久加成：起始金币、利息、拉杆集点、★ 与高品质的出现率、全员生命和攻击。中途回主页放弃，只按 ' .. S(round(SOUL_ABANDON * 100)) .. '% 结算；新手教程不产出军魂。</p>\n' ..
        '      <h3>' .. curCh().name .. '「' .. curCh().title .. '」的敌人</h3>\n' ..
        '      <div class="legend foes">' .. ENEMY_KEYS:filter(function(t) return ENEMIES[t].desc and ENEMIES[t].ch == G.ch end):map(function(t)
            return '<span><img class="ico" src="' .. iconURL(ENEMIES[t].sprite, ENEMIES[t].pal or nil, 'foe:' .. t) .. '" alt=""><b>' .. ENEMIES[t].name .. '</b>' .. ENEMIES[t].desc .. '</span>'
        end):join('') .. '</div>\n' ..
        '      <p class="keys">键盘：空格拉杆，回车开战。</p>'
    if first then UI.showStart(body)
    else UI.modal('玩法说明', body, UI.backLabel()) end
end

-- ---------- 选章节与难度 ----------
local CH_NUM = { [0] = '1', '2', '3', '4', '5', '6', '7', '8', '9', '10' }
function UI.pickerHTML()
    -- 选关（更新）：章节改成一排紧凑的页签，难度 2×2 小卡片；说明文字缩小，手机上一屏放得下
    local c = UI.pickCh
    local C, Sv = CHAPTERS[c], SAVE[c]
    local tabs = '<div class="chapters2">' .. CHAPTERS:map(function(K, i)
        local open = chOpen(i)
        local pips = K.diffs:map(function(Dd, d) return '<i class="' .. (((SAVE[i].cleared & (1 << d)) ~= 0) and 'on' or '') .. '" style="--dc:' .. Dd.color .. '"></i>' end):join('')
        return '<button class="chap2' .. (i == c and ' on' or '') .. '" data-c="' .. S(i) .. '" aria-pressed="' .. str(i == c) .. '" style="--cc:' .. K.color .. '"' .. (open and '' or ' disabled') .. '>' ..
            '<b>' .. (K.num or CH_NUM[i] or S(i + 1)) .. '</b><span>' .. K.title .. '</span>' .. (open and ('<span class="pips">' .. pips .. '</span>') or '<small>未解锁</small>') .. '</button>'
    end):join('') .. '</div>'
    local head = '<div class="chhead" style="--cc:' .. C.color .. '"><b>' .. C.name .. '「' .. C.title .. '」</b><span>' .. C.desc .. '</span></div>'
    local diffs = '<div class="diffs2">' .. C.diffs:map(function(Dd, i)
        local locked = i > Sv.unlock
        local status
        if locked then status = '通关「' .. C.diffs[i - 1].name .. '」后解锁'
        elseif (Sv.cleared & (1 << i)) ~= 0 then status = '已通关 ✓'
        elseif T(Sv.best[i]) then status = '最佳 ' .. S(Sv.best[i]) .. '/' .. S(Dd.waves) .. ' 波'
        else status = '尚未挑战' end
        local short = Dd.desc:gsub('^共 %d+ 波。', '')
        return '<button class="diff2" data-d="' .. S(i) .. '" style="--dc:' .. Dd.color .. '"' .. (locked and ' disabled' or '') .. '>' ..
            '<span class="dh"><b>' .. Dd.name .. '</b><em>' .. S(Dd.waves) .. ' 波 · ' .. S(Dd.lives) .. ' 命</em></span><span class="dd">' .. short .. '</span><small>' .. status .. '</small></button>'
    end):join('') .. '</div>'
    return tabs .. head .. diffs
end
function UI.showStart(intro, title)
    if UI.pickCh == nil or not chOpen(UI.pickCh) then UI.pickCh = G and G.ch or 0 end
    UI.modal(title or '拉杆军团', (intro or '') .. '<h3 class="pickh">选择章节与难度</h3><div id="pick">' .. UI.pickerHTML() .. '</div>', '返回主页', function() UI.showHome() end)
    local pick = _id('pick')
    local bind
    bind = function()
        for _, b in ipairs(pick:querySelectorAll('.chap2')) do
            b:addEventListener('click', function()
                if b:isDisabled() then return end
                Sound.init(); UI.pickCh = tonumber(b:data('c')); pick:setHTML(UI.pickerHTML()); bind()
                local f = pick:querySelector('.chap2.on'); if f then focusEl(f) end
            end)
        end
        for _, btn in ipairs(pick:querySelectorAll('.diff2')) do
            btn:addEventListener('click', function()
                if btn:isDisabled() then return end
                Sound.init(); UI.showSquad(UI.pickCh, tonumber(btn:data('d')))
            end)
        end
    end
    bind()
end

function UI.showResult(res)
    if G.tutorial and G.phase == 'victory' then return TUT.finish() end
    if res and res.revivable then return UI.showRevive(res) end
    local Dd, C = curDiff(), curCh()
    if G.phase == 'victory' then
        local tail = ''
        OR(res.news, A()):forEach(function(n)
            local NC = CHAPTERS[n.c]
            local Nd = NC.diffs[n.d]
            if n.c ~= G.ch then
                tail = tail .. '<p class="newly">新章节已解锁：<b style="color:' .. NC.color .. '">' .. NC.name .. '「' .. NC.title .. '」</b> —— ' .. NC.desc .. '</p>'; UI.pickCh = n.c
                CLASS_KEYS:forEach(function(k)
                    if CLASSES[k].unlock == n.c - 1 then tail = tail .. '<p class="newly">新兵种已解锁：<b style="color:' .. CLASS_COLOR[k] .. '">' .. CLASSES[k].name .. '</b> —— ' .. CLASSES[k].note .. '</p>' end
                end)
            else tail = tail .. '<p class="newly">新难度已解锁：<b style="color:' .. Nd.color .. '">' .. Nd.name .. '</b> —— ' .. Nd.desc .. '</p>' end
        end)
        if tail ~= '' then setTimeout(function() Sound.play('unlock') end, 700)
        elseif G.diff == #C.diffs - 1 then tail = '<p class="newly">你已通关' .. C.name .. '的最高难度「' .. Dd.name .. '」！</p>' end
        local st = G.stats
        UI.showStart('<p>你在' .. C.name .. '「' .. Dd.name .. '」难度守住了全部 ' .. S(G.maxWave) .. ' 波。</p><p>拉杆 ' .. S(st.spins) .. ' 次，召唤 ' .. S(st.summoned) .. ' 个单位，最高 ' .. starStr(st.maxStar) ..
            '，最高品质 <span class="qtag" style="color:' .. QUAL[st.maxQ].color .. '">' .. QUAL[st.maxQ].name .. '</span>' .. (T(st.jackpots) and ('，九格大奖 ' .. S(st.jackpots) .. ' 次') or '') ..
            '，转职 ' .. S(st.awakened) .. ' 次' .. (T(st.promoted) and ('，晋升 ' .. S(st.promoted) .. ' 次') or '') .. '，剩余生命 ' .. S(G.lives) .. '。</p>' .. UI.soulLine(res.soul) .. tail, C.bossName .. '倒下了')
        UI.bindForge(); UI.bindAdDouble(res)
    elseif G.phase == 'gameover' then
        UI.showStart('<p>在' .. C.name .. '「' .. Dd.name .. '」难度止步第 ' .. S(res.wave) .. ' 波。最佳纪录：守住 ' .. S(SAVE[G.ch].best[G.diff]) .. ' 波。</p>' .. UI.soulLine(res.soul) .. '<p class="dim">提示：同职业单位互相吸收，升到 ' .. starStr(3) .. ' 就能转职或晋升，比堆数量更有效。</p>', '军团覆灭')
        UI.bindForge(); UI.bindAdDouble(res)
    elseif res.win then
        local tail = T(res.interest) and ('，利息 +' .. S(res.interest)) or ''
        UI.modal('第 ' .. S(res.wave) .. ' 波 胜利', '<p>奖励 +' .. S(res.base) .. ' 金币' .. tail .. (T(res.gems) and ('，秘银 +' .. S(res.gems)) or '') .. '。</p>' .. (T(res.gems) and '<p class="dim">顶栏「商店」已经换了一批新货。</p>' or '<p class="dim">每存 10 金币，战后多得 1 金币利息，最多 ' .. S(interestCap()) .. '。</p>') ..
            (T(res.soulGain) and ('<p class="soulline"><img src="' .. iconURL('m_soul') .. '" alt=""><span>军魂 <b>+' .. S(res.soulGain) .. '</b>，本局累计 ' .. S(G.soulPend) .. '（打完这一局一并结算）</span></p>') or '') ..
            (G.wave == G.maxWave and ('<p class="warn">下一波是首领波：' .. C.bossWarn(Dd) .. '</p>') or ''),
            (res.elite and not G.tutorial) and '领取精英战利品' or ('准备第 ' .. S(G.wave) .. ' 波'), function() UI.afterBattle(res) end)
    else
        local tail = T(res.interest) and ('，利息 +' .. S(res.interest)) or ''
        UI.modal('防线失守', '<p>失去 1 点生命，还剩 ' .. S(G.lives) .. '。这一波会重新开始。</p><p>补给 +' .. S(res.base) .. ' 金币' .. tail .. (T(res.gems) and ('，秘银 +' .. S(res.gems)) or '') .. '。</p>', '重新布阵', function() UI.afterBattle(res) end)
    end
end

-- ---------------------------------------------------------------------------
-- 新手教程
-- ---------------------------------------------------------------------------
TUT_KEY = 'reel-legion-tut'
local function ic(n) return '<img class="ico" src="' .. iconURL(n) .. '" alt="">' end
TUT = {
    on = false, i = 0,
    steps = A(
        { text = function() return '欢迎来到拉杆军团！跟着提示走一遍：<b>召唤</b>、<b>吸收升星</b>、<b>转职</b>、<b>开战</b>，大约一分钟。' end, btn = '开始' },
        { target = '#lever', text = function() return '<b>拉杆召唤</b>：每次花 3 金币转动老虎机。点一下拉杆，或者按空格键。' end,
            done = function() return G.stats.spins >= 1 and G.phase == 'prep' end },
        { target = '#arena', text = function() return '横、竖、斜任意一条线连成 3 个相同图标，就召唤对应职业：' .. ic('sym_sword') .. '战士、' .. ic('sym_bow') .. '射手、' .. ic('sym_staff') .. '法师，' .. ic('sym_star') .. '可以当任何图标。新单位出现在左边的阵地上。' end, btn = '知道了' },
        { target = '#lever', text = function() return '再拉一次，召唤第二个战士。' end, done = function() return G.stats.spins >= 2 and G.phase == 'prep' end },
        { target = '#arena', text = function() return '<b>吸收升星</b>：按住一个战士，<b>拖到</b>另一个战士身上。被拖的那个会被吸收，变成经验；经验攒够就升星，属性大涨。' end,
            done = function() return allUnits():some(function(u) return u.star >= 2 or u.pts > STAR_PTS[u.star] end) end },
        { text = function() return '做得好！升到 ' .. starStr(3) .. ' 的单位可以<b>转职</b>，换上专属技能。教程直接送你一个 ' .. starStr(3) .. ' 射手试试看。' end, btn = '领取',
            act = function() summon('archer', 3, 0) end },
        { hide = true, done = function() return #G.pendingAwaken == 0 and not allUnits():some(function(u) return u.awakenReady end) end },
        { id = 'fight', target = '#fight', text = function() return '<b>开战</b>：阵地上的单位会自动战斗，右边是这一波的敌人。底部备战席的单位不参战。' end,
            done = function() return G.phase == 'battle' end },
        { target = '#arena', nodim = true, text = function() return '战斗全自动，能量满了会自动放技能。再点一次右下角的按钮可以 2 倍速。' end,
            done = function() return G.phase ~= 'battle' end }
    ),
}
function TUT.start()
    restart(0, 0, DEFAULT_SQUAD)
    G.tutorial = true; G.maxWave = 1; G.gold = 12; G.mx = js.assign({}, MX_NONE); G.freeSpins = 0; G.luckMax = 3
    G.lineup = { wave = 1, list = A({ type = 'slime', x = 160, y = 52 }, { type = 'slime', x = 160, y = 92 }) }
    G.rig = A(A('A', 'M', 'A', 'W', 'W', 'W', 'M', 'A', 'M'), A('W', 'W', 'W', 'A', 'M', 'A', 'M', 'A', 'M'))
    UI.els.home:setHidden(true); UI.els.overlay:setHidden(true); UI.cache:clear()
    TUT.on = true; TUT.go(0)
end
function TUT.go(i)
    TUT.i = i
    ---@type any
    local st = TUT.steps[i]
    if not st then return end
    _id('coachText'):setHTML(st.text and (st.text() or '') or '')
    local nx = _id('coachNext'); nx:setHidden(not st.btn); if st.btn then nx:setText(st.btn) end
    _id('coachStep'):setText(S(i + 1) .. '/' .. S(#TUT.steps))
    TUT.tick()
    if st.btn then setTimeout(function() focusEl(nx) end, 30) end
end
function TUT.next() local st = TUT.steps[TUT.i]; if not st or not st.btn then return end; if st.act then st.act() end; TUT.go(TUT.i + 1) end
function TUT.skip() store.set(TUT_KEY, '1'); UI.showHome() end
function TUT.stop() TUT.on = false; _id('coach'):setHidden(true); if G then G.tutorial = false; G.rig = nil end end
function TUT.finish()
    TUT.on = false; _id('coach'):setHidden(true); store.set(TUT_KEY, '1')
    UI.modal('教程完成！', '<p>基本操作都会了：拉杆召唤 → 同职业互相吸收升星 → ' .. starStr(3) .. ' 转职或晋升 → 开战。</p>' ..
        '<p>每章 4 个难度，通关「普通」就解锁下一章。每守住一波还会获得<b>军魂</b>，在主页的「军团强化」里换成永久加成。忘了规则时，右上角有「玩法」和「图鉴」。</p>' ..
        '<div class="confirm"><button class="btn" id="cfYes">开始游戏</button><button class="btn alt" id="cfNo">回到主页</button></div>', nil)
    _id('cfYes').onclick = function() Sound.init(); G.tutorial = false; UI.showStart('', '开始游戏') end
    _id('cfNo').onclick = function() Sound.init(); UI.showHome() end
    Sound.play('unlock')
end
function TUT.tick()
    if not TUT.on then return end
    local c, st = _id('coach'), TUT.steps[TUT.i]
    if not st then
        if G.phase == 'prep' then TUT.go(TUT.steps:findIndex(function(s) return s.id == 'fight' end)) else c:setHidden(true) end
        return
    end
    if st.done and st.done() then TUT.go(TUT.i + 1); return end
    local blocked = not UI.els.overlay:isHidden() or not UI.els.home:isHidden() or not not st.hide
    c:setHidden(blocked); if blocked then return end
    c:toggleClass('nodim', not not st.nodim)
    -- 读取尺寸前先排版（浏览器读 offsetWidth 时会强制排版）
    PAGE:update()
    local hole, tip = _id('coachHole'), _id('coachTip')
    local vw, vh = PAGE.env.vw, PAGE.env.vh
    local env = PAGE.env.envVars
    local left = (env['safe-area-inset-left'] or 0) + 12
    local right = vw - (env['safe-area-inset-right'] or 0) - 12
    local top = max(env['safe-area-inset-top'] or 0, env['native-overlay-top'] or 0) + 12
    local bottom = vh - (env['safe-area-inset-bottom'] or 0) - 12
    local tw, th = tip.box and tip.box.w or 0, tip.box and tip.box.h or 0
    local el = st.target and doc().body:querySelector(st.target)
    local tx, ty
    if el and el.box then
        local b = el.box
        local targetY = b.ay + (b.stickyDY or 0)
        local parent = b.parent
        local guard = 0
        while parent do
            targetY = targetY + (parent.stickyDY or 0) - (parent.scrollTop or 0)
            if parent.pos == 'fixed' then break end
            parent = parent.parent
            guard = guard + 1
            if guard > 64 then break end -- 防 DOM 环引用导致死循环
        end
        local r = { left = b.ax, top = targetY, width = b.w, height = b.h }
        r.bottom = r.top + r.height
        local pad = 6
        hole:removeClass('center')
        hole:setStyle('left', S(r.left - pad) .. 'px'); hole:setStyle('top', S(r.top - pad) .. 'px')
        hole:setStyle('width', S(r.width + pad * 2) .. 'px'); hole:setStyle('height', S(r.height + pad * 2) .. 'px')
        tx = clamp(r.left + r.width / 2 - tw / 2, left, max(left, right - tw))
        if r.bottom + pad + 12 + th < bottom then ty = r.bottom + pad + 12
        elseif r.top - pad - 12 - th > top then ty = r.top - pad - 12 - th
        else
            local before, after = r.left - left - 12, right - r.left - r.width - 12
            if before >= tw then tx = r.left - tw - 12; ty = r.top
            elseif after >= tw then tx = r.left + r.width + 12; ty = r.top
            else ty = bottom - th end
        end
    else
        hole:removeAttribute('style'); hole:addClass('center')
        tx = (left + right - tw) / 2; ty = (top + bottom - th) / 2
    end
    tx = clamp(tx, left, max(left, right - tw))
    ty = clamp(ty, top, max(top, bottom - th))
    tip:setStyle('left', S(round(tx)) .. 'px'); tip:setStyle('top', S(round(ty)) .. 'px')
end

function restart(c, d, squad)
    newGame(c == nil and G.ch or c, d == nil and G.diff or d, squad)
    drag = nil; UI.cache:clear(); UI.update()
end

-- ---------------------------------------------------------------------------
-- 主循环（每帧由 main 调用；now 为毫秒）
-- ---------------------------------------------------------------------------
local lastT = nil
-- 帧内阶段探针：卡死是"某一帧永远跑不完"，帧首看门狗抓不到。
-- 用毫秒时钟测每个阶段耗时，只有异常（>250ms）才打印——平时不刷屏。
-- 卡死时最后一条日志的"阶段名"就是卡住的那段代码。
local function nowMs()
    local ok, t = pcall(function() return GetTime():GetTimeSinceEpochMs() end)
    return (ok and t) or 0
end
local stageMark, stageName = nil, nil
local stageTick = 0
local function stage(name)
    if stageMark then
        local d = nowMs() - stageMark
        if d > 250 then print('[拉杆军团] 帧阶段慢：' .. tostring(stageName) .. ' 耗时 ' .. d .. 'ms') end
    end
    stageMark, stageName = nowMs(), name
    _G.CRASH_STAGE = name -- 同步给崩溃痕迹文件（main 里的 writeTrace 读它；显式 _G 避免落到 N 表）
end
-- 心跳：每约 2 秒打印一次「当前帧进行到哪个阶段」。
-- 卡死是单帧永不结束，阶段切换探针没机会触发；心跳能留下最后进入的阶段名。
local function heartbeat()
    stageTick = stageTick + 1
    if stageTick >= 120 then
        stageTick = 0
        print('[拉杆军团] 心跳：帧进行到 ' .. tostring(stageName))
    end
end
-- 供 logic.lua 的 stepBattle 内部分段打点（跨模块用全局桥接）
FRAME_STAGE_PROBE = stage

function frame(now)
    local dt = lastT and min(0.05, (now - lastT) / 1000) or 0
    if dt ~= dt then dt = 0 end
    lastT = now
    G.time = G.time + dt
    G.shake = max(0, G.shake - dt)
    stage('units')
    allUnits():forEach(function(u) if u.pop > 0 then u.pop = max(0, u.pop - dt) end end)
    stage('slot')
    updateSlot(dt)
    if G.phase == 'battle' and G.battle and UI.els.overlay:isHidden() and UI.els.home:isHidden() then
        stage('battle')
        local steps = G.speed
        for _ = 1, steps do stepBattle(dt) end
        if G.battle.over and G.battle.endT > 1.1 then UI.showResult(finishBattle(true)) end
    end
    stage('fx')
    FX.update(dt)
    if G.phase == 'prep' and UI.els.overlay and UI.els.overlay:isHidden() and UI.els.home:isHidden() then
        G.pendingAwaken = G.pendingAwaken:filter(function(u) return u.awakenReady and findSlot(u) end)
        if #G.pendingAwaken > 0 then drag = nil; UI.showAwaken(G.pendingAwaken[0]) end
    end
    local SL = G.slot.show
    if #SL > 0 and G.phase == 'prep' and G.time - SL[#SL - 1].t > 6 then G.slot.show = A() end
    stage('renderArena')
    renderArena()
    stage('renderSlot')
    renderSlot()
    stage('ui')
    UI.update()
    if not UI.els.home:isHidden() then renderHome() end
    stage('tut')
    TUT.tick()
    stage('end')
    heartbeat()
end
function frameReset(now) lastT = now end

return UI
