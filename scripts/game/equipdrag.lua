-- ============================================================================
-- 第十四次更新：装备管理改成拖放
--  以前每件装备后面跟着「转移 / 卸下 / 卖」三个按钮，一行只放得下一个单位，转移还要再开一层弹窗选人。
--  现在：
--   * 左边一栏是仓库（第十五次更新：10 格，也能放圣物）、圣物栏（8 格）和「出售」区，下面是选中装备的说明；右边是所有角色的卡片（头像 + 3 个装备格）
--   * 直接拖：装备拖到别的角色身上 = 转给他（拖到他已有装备的那一格 = 互换）；拖进仓库 = 卸下；
--     仓库里的拖到角色身上 = 装上；拖到「出售」= 卖掉换秘银
--   * 不想拖也行：点一下装备选中它，再点目标（角色卡、装备格、仓库、出售）
--   * 拖动时能放的地方亮绿框，不能放的（远程专属、兵种限定、栏位满）亮红框，图标跟着手指走
--   * 战斗中只能查看（点装备看说明）
--  手势：鼠标按下拖动即可；触摸按住约 0.2 秒拿起（直接滑动仍然是滚动列表），见 ui/input.lua
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local CONTENT = require("ui.content")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local floor, max, min = math.floor, math.max, math.min
local function _id(id) return PAGE.doc.getElementById(id) end

-- ---------------------------------------------------------------------------
-- 逻辑：一次移动。src = { k = 'u', u, i } | { k = 's', i } | { k = 'r', i }；dst = { k = 'u', u, i? } | { k = 's', i? } | { k = 'r', i? } | { k = 'sell' }
-- 第十五次更新：k = 'r' 是圣物栏（i 从 1 起，对应 G.relics[i - 1]）。圣物只能在圣物栏和仓库之间移动
-- 返回 ok, 说明文字（失败时是原因），声音名
-- ---------------------------------------------------------------------------
local function itemAt(src)
    if src.k == 'u' then return equipsOf(src.u)[src.i] end
    if src.k == 's' then return stashOf()[src.i] end
    if src.k == 'r' then return src.i and G.relics[src.i - 1] end
    return nil
end
EQM = {}
EQM.itemAt = itemAt

local function why(it, u)
    local I = ITEMS[it.id]
    if I.kind == 'relic' then return '是圣物，只能放进圣物栏' end
    if I.cls and u.cls ~= I.cls then return CLASSES[I.cls].name .. '专属' end
    if I.ranged then return '仅远程兵种' end
    return '不能装备'
end

--- 能不能放到 dst（拖动时用来亮绿框 / 红框）
--- 圣物的移动（来源是圣物栏，或者仓库里的圣物）
local function checkRelic(src, it, dst)
    local st = stashOf()
    if dst.k == 'u' then return false, '圣物不能装给角色，拖到「圣物栏」' end
    if dst.k == 's' then
        if src.k == 's' then return dst.i ~= nil and dst.i ~= src.i and st[dst.i] ~= nil, '整理仓库' end
        local other = dst.i and st[dst.i]
        if other then
            if not isRelic(other) then return false, '那一格是装备，换一格' end
            return true, '和仓库里的 ' .. itemName(other) .. ' 互换'
        end
        if stashFull() then return false, '仓库已满' end
        return true, '收进仓库（不再生效）'
    end
    -- 放进圣物栏
    if src.k == 'r' then
        if dst.i and dst.i ~= src.i and G.relics[dst.i - 1] then return true, '调换顺序' end
        return false, ''
    end
    local old = dst.i and G.relics[dst.i - 1]
    if old then return true, '换下 ' .. itemName(old) .. '（放回仓库）' end
    if relicBarFull() then return false, '圣物栏已满，拖到要换下的那一格上' end
    return true, '装上（立即生效）'
end

function EQM.check(src, dst)
    local it = itemAt(src)
    if not it then return false, '' end
    if dst.k == 'sell' then return true, '卖出 +' .. S(sellPrice(it)) .. ' 秘银' end
    if isRelic(it) then return checkRelic(src, it, dst) end
    if dst.k == 'r' then return false, '装备不能放进圣物栏' end
    if dst.k == 's' then
        if src.k == 's' then return dst.i ~= nil and dst.i ~= src.i and stashOf()[dst.i] ~= nil, '整理仓库' end
        local other = dst.i and stashOf()[dst.i]
        if other then
            if isRelic(other) then return false, '那一格放着圣物，换一格' end
            if not canEquipItem(other, src.u) then return false, itemName(other) .. ' ' .. why(other, src.u) end
            return true, '和仓库里的 ' .. itemName(other) .. ' 互换'
        end
        if stashFull() then return false, '仓库已满' end
        return true, '卸下放进仓库'
    end
    -- 放到角色身上
    local v = dst.u
    if src.k == 'u' and src.u == v then
        if dst.i and dst.i ~= src.i and equipsOf(v)[dst.i] then return true, '调换顺序' end
        return false, ''
    end
    if not canEquipItem(it, v) then return false, why(it, v) end
    local l = equipsOf(v)
    local old = dst.i and l[dst.i]
    if old then
        if src.k == 'u' and not canEquipItem(old, src.u) then
            if stashFull() then return false, itemName(old) .. ' 不能给 ' .. unitName(src.u) .. '，仓库也满了' end
            return true, '换下 ' .. itemName(old) .. '（放进仓库）'
        end
        return true, '和 ' .. itemName(old) .. ' 互换'
    end
    if #l >= EQUIP_SLOTS then return false, '装备栏已满，拖到要换掉的那一格上' end
    return true, '装上'
end

--- 执行移动
function EQM.move(src, dst)
    local ok, msg = EQM.check(src, dst)
    if not ok then return false, msg end
    local it = itemAt(src)
    if dst.k == 'sell' then
        local p
        if src.k == 'u' then p = unequipSell(src.u, src.i)
        elseif src.k == 'r' then p = sellItem('relic', src.i - 1)
        else p = stashSell(src.i) end
        return true, '卖出 ' .. itemName(it) .. '，+' .. S(p) .. ' 秘银', 'sell'
    end
    if isRelic(it) then -- 第十五次更新：圣物在圣物栏 / 仓库之间移动
        local st = stashOf()
        if dst.k == 's' then
            if src.k == 's' then st[src.i], st[dst.i] = st[dst.i], st[src.i]; return true, nil, 'drop' end
            if dst.i and st[dst.i] then
                local other = st[dst.i]
                relicSwapStash(src.i - 1, dst.i)
                return true, itemName(it) .. ' 收进仓库，换上 ' .. itemName(other), 'equip'
            end
            relicToStash(src.i - 1)
            return true, itemName(it) .. ' 收进了仓库（不再生效）', 'unequip'
        end
        if src.k == 'r' then relicReorder(src.i - 1, dst.i - 1); return true, nil, 'drop' end
        local old = dst.i and G.relics[dst.i - 1]
        if old then
            relicSwapStash(dst.i - 1, src.i)
            return true, '装上 ' .. itemName(it) .. '，换下的 ' .. itemName(old) .. ' 放回仓库', 'equip'
        end
        relicEquipFromStash(src.i)
        return true, '装上 ' .. itemName(it) .. '（立即生效）', 'equip'
    end
    if dst.k == 's' then
        local st = stashOf()
        if src.k == 's' then st[src.i], st[dst.i] = st[dst.i], st[src.i]; return true, nil, 'drop' end
        local other = dst.i and st[dst.i]
        if other then
            equipsOf(src.u)[src.i] = other; st[dst.i] = it
            return true, itemName(it) .. ' 放进仓库，' .. unitName(src.u) .. ' 换上 ' .. itemName(other), 'equip'
        end
        unequipToStash(src.u, src.i)
        return true, itemName(it) .. ' 卸下，放进了仓库', 'unequip'
    end
    local v = dst.u
    local l = equipsOf(v)
    if src.k == 'u' and src.u == v then l[src.i], l[dst.i] = l[dst.i], l[src.i]; return true, nil, 'drop' end
    local old = dst.i and l[dst.i]
    if src.k == 's' then
        local st = stashOf()
        if old then l[dst.i] = it; st[src.i] = old
            return true, unitName(v) .. ' 装上 ' .. itemName(it) .. '，换下的 ' .. itemName(old) .. ' 放回仓库', 'equip' end
        table.remove(st, src.i); l[#l + 1] = it
        return true, unitName(v) .. ' 装上 ' .. itemName(it), 'equip'
    end
    local lu = equipsOf(src.u)
    if old then
        l[dst.i] = it
        if canEquipItem(old, src.u) then lu[src.i] = old
            return true, itemName(it) .. ' 转给 ' .. unitName(v) .. '，换回 ' .. itemName(old), 'equip' end
        table.remove(lu, src.i); stashPut(old)
        return true, itemName(it) .. ' 转给 ' .. unitName(v) .. '，换下的 ' .. itemName(old) .. ' 放进仓库', 'equip'
    end
    table.remove(lu, src.i); l[#l + 1] = it
    return true, itemName(it) .. ' 转给了 ' .. unitName(v), 'equip'
end

-- ---------------------------------------------------------------------------
-- 编码：data-drag / data-dz 属性 <-> src / dst
-- ---------------------------------------------------------------------------
local function unitById(id) return allUnits():find(function(x) return x.id == id end) end
local function decode(code)
    if not code then return nil end
    if code == 'sell' then return { k = 'sell' } end
    if code == 'stash' then return { k = 's' } end
    if code == 'relic' then return { k = 'r' } end
    local si = code:match('^s:(%d+)$')
    if si then return { k = 's', i = tonumber(si) } end
    local ri = code:match('^r:(%d+)$')
    if ri then return { k = 'r', i = tonumber(ri) } end
    local uid, i = code:match('^u:(%d+):?(%d*)$')
    if uid then
        local u = unitById(tonumber(uid))
        if not u then return nil end
        return { k = 'u', u = u, i = (i ~= '') and tonumber(i) or nil }
    end
    return nil
end
local function srcCode(src) return (src.k == 'u') and ('u:' .. S(src.u.id) .. ':' .. S(src.i)) or (src.k .. ':' .. S(src.i)) end
--- 指针下最近的放置区
local function zoneOf(el)
    local n = el
    while n and n.tag ~= '#document' do
        if n.attrs and n.attrs['data-dz'] ~= nil then return n end
        n = n.parent
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- 界面
-- ---------------------------------------------------------------------------
local SEL = nil -- 选中的装备（点选模式）：{ code = 'u:3:1' | 's:2' }
local function canEdit() return G.phase == 'prep' end
local function where(u) local s = findSlot(u); return (s and s.t == 'b') and '备战席' or '阵地' end

local function cellHTML(it, code, dz, extraCls)
    local sel = SEL and SEL.code == code
    if not it then
        return '<button class="eqm-c empty' .. (extraCls or '') .. '" data-dz="' .. dz .. '" aria-label="空装备格"><i></i></button>'
    end
    local Q = QUAL[it.rar]
    return '<button class="eqm-c' .. (sel and ' sel' or '') .. (extraCls or '') .. '" style="--qc:' .. Q.color .. '" data-dz="' .. dz .. '"' ..
        (canEdit() and (' data-drag="' .. code .. '"') or '') .. ' data-it="' .. code .. '" aria-label="' .. itemName(it) .. '">' ..
        '<img src="' .. itemIcon(it) .. '" alt=""></button>'
end

local function unitCard(u)
    local l = equipsOf(u)
    local cells = {}
    for i = 1, EQUIP_SLOTS do
        local code = 'u:' .. S(u.id) .. ':' .. S(i)
        cells[#cells + 1] = cellHTML(l[i], code, code)
    end
    return '<div class="eqm-u" data-dz="u:' .. S(u.id) .. '"><div class="eqm-who"><img src="' .. unitIconURL(u) .. '" alt="">' ..
        '<span class="nm">' .. qSpan(u) .. '<small>' .. where(u) .. ' · ' .. S(#l) .. '/' .. S(EQUIP_SLOTS) .. '</small></span></div>' ..
        '<div class="eqm-sl">' .. table.concat(cells) .. '</div></div>'
end

--- 选中装备的说明 / 操作提示
local function infoHTML()
    local src = SEL and decode(SEL.code)
    local it = src and itemAt(src)
    if not it then
        SEL = nil
        if not canEdit() then return '<p class="eqm-tip">战斗中只能查看：点一下装备看说明。</p>' end
        return '<p class="eqm-tip"><b>拖动装备</b>：拖给角色 = 转给他，拖到某一格 = <b>互换</b>，拖进仓库 = 卸下。<b>圣物</b>在圣物栏和仓库之间拖动（仓库里的不生效）。也可以先点、再点目标。</p>'
    end
    local Q = QUAL[it.rar]
    local relic = isRelic(it)
    local at = (src.k == 'u') and (unitName(src.u) .. ' 第 ' .. S(src.i) .. ' 格') or ((src.k == 'r') and ('圣物栏第 ' .. S(src.i) .. ' 格 · 生效中') or ('仓库第 ' .. S(src.i) .. ' 格' .. (relic and ' · 圣物（不生效）' or '')))
    local btns = ''
    if canEdit() then
        local first = ''
        if src.k == 'u' or src.k == 'r' then
            first = '<button class="chip" id="eqmUn"' .. (stashFull() and ' disabled' or '') .. '>' .. (stashFull() and '仓库满' or (src.k == 'r' and '收进仓库' or '卸下')) .. '</button>'
        elseif relic then
            first = '<button class="chip go" id="eqmUp">' .. (relicBarFull() and '换上…' or '装上') .. '</button>'
        end
        btns = '<div class="eqm-btns">' .. first ..
            '<button class="chip" id="eqmSell">卖 ' .. S(sellPrice(it)) .. ' 秘银</button>' ..
            '<button class="chip" id="eqmX">取消</button></div>'
    end
    return '<div class="eqm-d" style="--qc:' .. Q.color .. '"><img src="' .. itemIcon(it) .. '" alt=""><span><b>' .. itemName(it) .. '</b><small><span style="color:' .. Q.color .. '">' .. Q.name .. '</span> · ' .. at .. '</small></span></div>' ..
        '<p class="eqm-desc">' .. itemDesc(it) .. '</p>' .. btns ..
        (canEdit() and ('<p class="eqm-tip">' .. (relic and '再点圣物栏或仓库里的格子，把它放过去。' or '再点角色、装备格或仓库，把它放过去。') .. '</p>') or '')
end

function UI.equipOverviewHTML()
    local units = A()
    G.form:forEach(function(u) if u then units:push(u) end end)
    G.bench:forEach(function(u) if u then units:push(u) end end)
    local st = stashOf()
    local cells = {}
    for k = 1, STASH_SLOTS do cells[#cells + 1] = cellHTML(st[k], 's:' .. S(k), 's:' .. S(k), isRelic(st[k]) and ' rl' or nil) end
    local rcells = {}
    for k = 1, RELIC_SLOTS do rcells[#rcells + 1] = cellHTML(G.relics[k - 1], 'r:' .. S(k), 'r:' .. S(k)) end
    local edit = canEdit()
    local side = '<div class="eqm-side">' ..
        '<div class="eqm-box" data-dz="stash"><p class="eqm-h">仓库 <span>' .. S(#st) .. '/' .. S(STASH_SLOTS) .. ' · 装备和圣物</span></p><div class="eqm-st">' .. table.concat(cells) .. '</div></div>' ..
        (edit and '<div class="eqm-sell" data-dz="sell"><img class="gem-ic" src="' .. gemIcon() .. '" alt=""><span>拖到这里出售</span></div>' or '') ..
        '<div class="eqm-box eqm-rbox" data-dz="relic"><p class="eqm-h">圣物栏 <span>' .. S(#G.relics) .. '/' .. S(RELIC_SLOTS) .. ' · 全队生效</span></p><div class="eqm-rl">' .. table.concat(rcells) .. '</div></div>' ..
        '<div class="eqm-info" id="eqmInfo">' .. infoHTML() .. '</div></div>'
    local list
    if #units == 0 then list = '<p class="dim">还没有单位。先拉杆召唤吧。</p>'
    else list = '<div class="eqm-grid">' .. units:map(unitCard):join('') .. '</div>' end
    return (edit and '' or '<p class="warn sh-warn">战斗中只能查看，这一波打完再调整。</p>') ..
        '<div class="eqm">' .. side .. '<div class="eqm-main">' .. list .. '</div></div>'
end

-- ---------------------------------------------------------------------------
-- 拖动状态与高亮
-- ---------------------------------------------------------------------------
local DRAG = nil -- { src, code, icon, rar, x, y, touch, zone, ok }
local function flashUnit(u, col)
    if not FX.P then return end
    local s = findSlot(u)
    if s then local p = slotPos(s); FX.P.ring(p.x, p.y, 2, 14, col, { thick = 2, dur = 0.5 }); FX.P.sparks(p.x, p.y, col, 10) end
end
local function showMsg(msg, ok)
    local info = _id('eqmInfo')
    if not info or DRAG.shown == (msg or '') then return end
    DRAG.shown = msg or ''
    if not msg or msg == '' then info:setHTML('<p class="eqm-tip">拖到角色、装备格、仓库或「出售」上松开。</p>')
    else info:setHTML('<p class="eqm-drop ' .. (ok and 'ok' or 'no') .. '">' .. (ok and '松开：' or '不行：') .. msg .. '</p>') end
end
local function setZone(z, ok)
    if DRAG.zone == z and DRAG.ok == ok then return end
    if DRAG.zone then DRAG.zone:removeClass('dz-ok', 'dz-no') end
    DRAG.zone, DRAG.ok = z, ok
    if z then z:addClass(ok and 'dz-ok' or 'dz-no') end
end
local function markTargets(on)
    local root = _id('eqv')
    if not root then return end
    root:toggleClass('dragging', on)
    for _, c in ipairs(root:querySelectorAll('.eqm-u')) do
        if on then
            local dst = decode(c:data('dz'))
            local ok = dst and EQM.check(DRAG.src, dst)
            local fullOk = ok
            if dst and not ok then -- 卡片本身满了也可能还有能互换的格子
                for i = 1, EQUIP_SLOTS do if EQM.check(DRAG.src, { k = 'u', u = dst.u, i = i }) then fullOk = true; break end end
            end
            c:toggleClass('cant', not fullOk)
        else c:removeClass('cant') end
    end
end

local refresh -- 前置声明
local function apply(src, dst)
    local it = itemAt(src)
    local ok, msg, snd = EQM.move(src, dst)
    if not ok then
        Sound.play('deny')
        if msg and msg ~= '' then UI.toast(msg) end
        return false
    end
    Sound.play(snd or 'equip')
    if msg then UI.toast(msg) end
    if snd == 'sell' then UI.bumpGems() end
    if dst.k == 'u' and it then flashUnit(dst.u, QUAL[it.rar].color) end
    SEL = nil
    UI.cache:set('info', nil); UI.cache:set('itembar', nil)
    return true
end

-- 滚动容器：本工程（第十次更新）把装备管理弹窗改成「弹窗本体固定、#mBody 滚动」，
-- 上游是 .modal 自己滚动。这里统一取 #mBody，取不到再退回弹窗本体。
local function modalBox()
    local m = UI.els.mTitle.parent
    local body = UI.els.mBody
    if body and body.box then return body, body.box end
    return m, m.box
end

PAGE_DRAG = {
    start = function(el, x, y, touch)
        if not canEdit() or not _id('eqv') then return false end
        local code = el:data('drag')
        local src = decode(code)
        local it = src and itemAt(src)
        if not it then return false end
        Sound.init()
        DRAG = { src = src, code = code, icon = itemIcon(it), rar = it.rar, x = x, y = y, touch = touch }
        el:addClass('lifted')
        DRAG.el = el
        markTargets(true)
        Sound.play('tick')
        return true
    end,
    move = function(x, y, hitEl)
        if not DRAG then return end
        DRAG.x, DRAG.y = x, y
        local z = zoneOf(hitEl)
        if z then
            local dst = decode(z:data('dz'))
            local ok, msg = false, ''
            if dst then ok, msg = EQM.check(DRAG.src, dst) end
            -- 原地（拿起的那一格）不算目标
            if z == DRAG.el or (dst and dst.k == 'u' and DRAG.src.k == 'u' and dst.u == DRAG.src.u and not dst.i) then setZone(nil); showMsg(nil); return end
            setZone(z, ok); showMsg(msg, ok)
        else setZone(nil); showMsg(nil) end
    end,
    drop = function(x, y, hitEl)
        if not DRAG then return end
        local d = DRAG
        PAGE_DRAG.move(x, y, hitEl)
        local z = d.zone
        local dst = z and decode(z:data('dz'))
        if d.zone then d.zone:removeClass('dz-ok', 'dz-no') end
        if d.el then d.el:removeClass('lifted') end
        markTargets(false)
        DRAG = nil
        if dst then apply(d.src, dst) end
        refresh()
    end,
    cancel = function()
        if not DRAG then return end
        if DRAG.zone then DRAG.zone:removeClass('dz-ok', 'dz-no') end
        if DRAG.el then DRAG.el:removeClass('lifted') end
        markTargets(false)
        DRAG = nil
    end,
    -- 拖到弹窗上下边缘附近时自动滚动
    tick = function(x, y)
        if not DRAG then return end
        local m, b = modalBox()
        if not (b and b.ax) then return end
        local top, bot = b.ay, b.ay + b.h
        local edge = 36
        local v = 0
        if y < top + edge then v = -(top + edge - y) / edge * 9 elseif y > bot - edge then v = (y - (bot - edge)) / edge * 9 end
        if v ~= 0 then PAGE:setScrollTop(m, (m.scrollTop or 0) + v) end
    end,
}

--- 拖动中的图标（画在页面最上层）：跟着指针，触摸时往上挪一点免得被手指挡住
function paintOverlay(vg, dpr, host)
    if not DRAG or not DRAG.icon then return end
    local s = 34
    local x, y = DRAG.x - s / 2, DRAG.y - s / 2 - (DRAG.touch and 30 or 0)
    local c = QUAL[DRAG.rar].color
    local r, g, b = tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16)
    nvgBeginPath(vg); nvgRect(vg, x - 3, y - 3, s + 6, s + 6); nvgFillColor(vg, nvgRGBA(27, 21, 48, 230)); nvgFill(vg)
    nvgBeginPath(vg); nvgRect(vg, x - 3, y - 3, s + 6, s + 6); nvgRect(vg, x - 1, y - 1, s + 2, s + 2); nvgPathWinding(vg, NVG_HOLE)
    local okc = (DRAG.zone and (DRAG.ok and { 120, 230, 110 } or { 255, 110, 100 })) or { r, g, b }
    nvgFillColor(vg, nvgRGBA(okc[1], okc[2], okc[3], 255)); nvgFill(vg)
    host.drawImage(vg, DRAG.icon, x + 1, y + 1, s - 2, s - 2, dpr)
end

-- ---------------------------------------------------------------------------
-- 点选模式与绑定
-- ---------------------------------------------------------------------------
local function bindInfo()
    local un, sell, x, up = _id('eqmUn'), _id('eqmSell'), _id('eqmX'), _id('eqmUp')
    local src = SEL and decode(SEL.code)
    -- 第十五次更新：仓库里的圣物「装上」（圣物栏满了就选一件互换）
    if up then up:addEventListener('click', function()
        Sound.init()
        if not (src and src.k == 's') then return end
        local k = src.i
        SEL = nil
        if relicBarFull() then UI.relicFromStashPick(k, function() UI.showEquipOverview() end)
        else apply(src, { k = 'r' }); refresh() end
    end) end
    if un then un:addEventListener('click', function() if un:isDisabled() then return end; Sound.init(); if src then apply(src, { k = 's' }) end; refresh() end) end
    if sell then sell:addEventListener('click', function() Sound.init(); if src then apply(src, { k = 'sell' }) end; refresh() end) end
    if x then x:addEventListener('click', function() Sound.init(); SEL = nil; refresh() end) end
end

local function onZoneClick(z, ev)
    if DRAG then return end
    local code = z:data('dz')
    local itCode = z:data('it')
    if SEL and canEdit() then
        if itCode == SEL.code then SEL = nil; refresh(); return end -- 再点一次取消选中
        local src, dst = decode(SEL.code), decode(code)
        if src and dst then
            local ok = EQM.check(src, dst)
            if ok then apply(src, dst); refresh(); return end
            -- 点到另一件装备而且放不过去：改为选中那一件
            if itCode then SEL = { code = itCode }; Sound.play('tick'); refresh(); return end
            local _, msg = EQM.check(src, dst)
            Sound.play('deny'); if msg and msg ~= '' then UI.toast(msg) end
            return
        end
    end
    if itCode then SEL = { code = itCode }; Sound.play('tick'); refresh() end
end

function UI.bindEquipOverview()
    local root = _id('eqv')
    if not root then return end
    PAGE.drag = PAGE_DRAG
    for _, z in ipairs(root:querySelectorAll('[data-dz]')) do
        z:addEventListener('click', function(ev)
            if ev.handledDz then return end
            ev.handledDz = true -- 装备格在角色卡里面：只处理最里面那一层
            Sound.init()
            onZoneClick(z, ev)
        end)
    end
    bindInfo()
end

refresh = function()
    local root = _id('eqv')
    if not root then return end
    local m = UI.els.mTitle.parent
    -- 本工程滚动的是 #mBody（弹窗本体不滚），滚动位置也要从它上面取
    local sc = (UI.els.mBody and UI.els.mBody.box) and UI.els.mBody or m
    local keep = sc.scrollTop or 0
    root:setHTML(UI.equipOverviewHTML())
    UI.bindEquipOverview()
    -- 钱包数字
    for _, g in ipairs(m:querySelectorAll('.gemv')) do g:setText(S(gems())) end
    PAGE:update()
    PAGE:setScrollTop(sc, keep)
end
EQM.refresh = function() refresh() end
EQM.select = function(code) SEL = code and { code = code } or nil end
EQM.dragState = function() return DRAG end

-- 打开装备管理时清掉上次的选中；离开时清掉拖动回调
local _show = UI.showEquipOverview
function UI.showEquipOverview(...)
    SEL = nil; DRAG = nil
    return _show(...)
end
local _modal = UI.modal
function UI.modal(...)
    if DRAG then PAGE_DRAG.cancel() end
    PAGE.drag = nil
    return _modal(...)
end

-- ---------------------------------------------------------------------------
-- 样式
-- ---------------------------------------------------------------------------
CONTENT.css = CONTENT.css .. [==[
/* ===== 第十四次更新：装备管理（拖放） ===== */
.eqm { display: grid; grid-template-columns: 212px minmax(0, 1fr); gap: 8px; align-items: start; }
.eqm-side { position: sticky; top: 0; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
.eqm-box { padding: 6px; background: var(--night); border: 2px solid var(--panel-hi); }
.modal .eqm-h { margin: 0 0 5px; font-size: 13px; line-height: 1.3; color: var(--brass); }
.modal .eqm-h span { color: var(--ink-dim); }
.eqm-st { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 3px; }
/* 第十五次更新：仓库 10 格（5×2）、圣物栏 8 格（4×2） */
.eqm-rl { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 3px; }
.eqm-st .eqm-c, .eqm-rl .eqm-c { height: 36px; }
.eqm-st .eqm-c img, .eqm-rl .eqm-c img { width: 28px; height: 28px; }
.eqm-rbox { border-color: #6a5a8e; }
.eqm-c.rl { box-shadow: inset 0 -3px 0 rgba(0, 0, 0, 0.35), inset 0 0 0 2px var(--night); background: #33264f; }
.eqm-sell { display: flex; align-items: center; justify-content: center; gap: 6px; padding: 7px 4px; font-size: 13px; color: var(--ink-dim); background: rgba(27, 21, 48, 0.55); border: 2px dashed #6a5a8e; }
.eqm-sell img.gem-ic { width: 16px; height: 16px; }
.eqm-info { padding: 6px 7px; background: rgba(27, 21, 48, 0.55); }
.modal .eqm-tip { margin: 0; font-size: 12px; line-height: 1.6; color: var(--ink-dim); max-width: none; }
.modal .eqm-tip b { color: var(--ink); }
.eqm-d { display: flex; align-items: center; gap: 6px; }
.eqm-d img { flex: none; width: 28px; height: 28px; image-rendering: pixelated; }
.eqm-d > span { display: flex; flex-direction: column; min-width: 0; }
.eqm-d b { font-size: 14px; line-height: 1.3; color: var(--qc); }
.eqm-d small { font-size: 12px; line-height: 1.35; color: var(--ink-dim); }
.modal .eqm-desc { margin: 4px 0 5px; font-size: 12px; line-height: 1.55; max-width: none; }
.modal .eqm-drop { margin: 0; font-size: 13px; line-height: 1.55; max-width: none; }
.modal .eqm-drop.ok { color: #9be36b; }
.modal .eqm-drop.no { color: #ff9b8c; }
.eqm-btns { display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 4px; }
.eqm-btns .chip { padding: 3px 7px; font-size: 12px; }
.eqm-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(176px, 1fr)); gap: 6px; }
.eqm-u { display: flex; flex-direction: column; gap: 4px; min-width: 0; padding: 5px 6px 6px; background: var(--night); border: 2px solid var(--panel-hi); }
.eqm-who { display: flex; align-items: center; gap: 5px; min-width: 0; }
.eqm-who img { flex: none; width: 26px; height: 26px; image-rendering: pixelated; }
.eqm-who .nm { display: flex; flex-direction: column; min-width: 0; font-size: 13px; line-height: 1.25; white-space: nowrap; overflow: hidden; }
.eqm-who small { font-size: 12px; color: var(--ink-dim); }
.eqm-sl { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4px; }
.eqm-c { display: flex; align-items: center; justify-content: center; height: 40px; padding: 0; cursor: pointer; font: inherit; background: #2a2046; border: 2px solid var(--qc); box-shadow: inset 0 -3px 0 rgba(0, 0, 0, 0.35); }
.eqm-c img { width: 30px; height: 30px; image-rendering: pixelated; pointer-events: none; }
.eqm-c.empty { background: rgba(42, 32, 70, 0.5); border: 2px dashed #4a3a66; box-shadow: none; }
.eqm-c.empty i { width: 10px; height: 10px; border: 2px solid #4a3a66; }
.eqm-c.sel { background: #3d2f62; outline: 2px solid var(--brass-hi); outline-offset: 1px; }
.eqm-c.lifted { opacity: 0.35; }
.eqm-c:active { transform: translate(1px, 1px); }
.dragging .eqm-u.cant { opacity: 0.45; }
.dragging .eqm-c.empty { border-color: #6a5a8e; }
.dz-ok { outline: 3px solid #78e66e; outline-offset: -1px; }
.dz-no { outline: 3px solid #ff6e64; outline-offset: -1px; }
.eqm-c.dz-ok, .eqm-c.dz-no { outline-offset: 1px; }
.eqm-sell.dz-ok { color: var(--brass-hi); background: #3a2a16; border-color: var(--brass); outline: none; }
:root[data-short] .eqm-c { height: 36px; }
:root[data-short] .eqm-c img { width: 28px; height: 28px; }
:root[data-lay="P"] .eqm { grid-template-columns: 1fr; }
:root[data-lay="P"] .eqm-side { position: static; display: grid; grid-template-columns: minmax(0, 1fr) 84px; }
:root[data-lay="P"] .eqm-info { grid-column: 1 / -1; }
:root[data-lay="P"] .eqm-rbox { grid-column: 1 / -1; }
:root[data-lay="P"] .eqm-rl { grid-template-columns: repeat(8, minmax(0, 1fr)); }
:root[data-lay="P"] .eqm-sell { flex-direction: column; gap: 2px; padding: 4px; text-align: center; font-size: 12px; }
:root[data-lay="P"] .eqm-grid { grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); }
@media (max-width: 640px) { .eqm-grid { grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); } }
]==]

return true
