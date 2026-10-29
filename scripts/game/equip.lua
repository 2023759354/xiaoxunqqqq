-- ============================================================================
-- 装备（更新）
--  * 第七次更新：仓库（换下 / 卸下的装备不再直接折成秘银，放进仓库以后再装给别人）
--  * 每个单位 3 个装备栏（EQUIP_SLOTS，逻辑见 items.lua）；装满后再装会让你选换下哪一件
--  * 新增 12 件装备
--  * 布阵阶段战场上每个单位脚边显示装备小方块（颜色 = 装备品质），一眼看出谁带了装备；战斗中不显示
--  * 顶栏「装备」：所有单位的装备一览，可以卖出
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local floor, max, min = math.floor, math.max, math.min
local round = js.round
local function _id(id) return PAGE.doc.getElementById(id) end
local function focusEl(el) if el then PAGE:focus(el, 'script') end end

-- ---------------------------------------------------------------------------
-- 新装备
-- ---------------------------------------------------------------------------
local NEW = {
    whetstone = { kind = 'equip', rar = 0, name = '磨刀石', icon = 'i_spike', pal = { h = '#8d9ab2', H = '#c9d2e0', O = '#ffffff' }, desc = '攻击 +10%', fx = { atk = 0.1 } },
    warhelm = { kind = 'equip', rar = 0, name = '铁盔', icon = 'i_armor', pal = { h = '#8d9ab2', H = '#c9d2e0', z = '#5a6a7a', Z = '#e6edf7' }, desc = '生命 +15%', fx = { hp = 0.15 } },
    frostcharm = { kind = 'equip', rar = 1, name = '霜冻护符', icon = 'i_amulet', pal = { h = '#3aa6c8', H = '#bff4ff', a = '#7fd0ff', A = '#ffffff' }, desc = '普攻让目标减速 25%，持续 2 秒', fx = { slowHit = 0.25 } },
    emberblade = { kind = 'equip', rar = 1, name = '余烬之刃', icon = 'i_blade', pal = { P = '#ffe14a', o = '#ff8a2a', g = '#d8433a' }, desc = '普攻附带灼烧', fx = { burn = true } },
    vampfang = { kind = 'equip', rar = 1, name = '吸血獠牙', icon = 'i_spike', pal = { h = '#a8102a', H = '#ff3434', O = '#ffd0d0' }, desc = '吸血 +12%', fx = { leech = 0.12 } },
    hawkeye = { kind = 'equip', rar = 1, name = '鹰眼单片镜', icon = 'i_lens', pal = { o = '#ffe680', O = '#ffffff', g = '#c8900f' }, desc = '暴击率 +15%', fx = { crit = 0.15 } },
    quiver = { kind = 'equip', rar = 1, name = '疾风箭袋', icon = 'i_feather', desc = '攻速 +20%', limit = '仅远程兵种', ranged = true, fx = { spd = 0.2 } },
    manaorb = { kind = 'equip', rar = 1, name = '法力宝珠', icon = 'm_gem', pal = { a = '#2a56c9', A = '#78a8f2', o = '#bff4ff', O = '#ffffff', u = '#1f3a6a' }, desc = '开战时技能能量 +40', fx = { startEnergy = 40 } },
    aegisplate = { kind = 'equip', rar = 2, name = '守护板甲', icon = 'i_armor', pal = { h = '#c8900f', H = '#ffe680', z = '#8a5a2b', Z = '#ffffff' }, desc = '受到的伤害 -15%', fx = { dr = 0.15 } },
    stormring = { kind = 'equip', rar = 2, name = '雷霆指环', icon = 'i_ring', pal = { g = '#3b6fd1', y = '#78a8f2', e = '#ffe14a', O = '#ffffff' }, desc = '普攻有 25% 几率弹射一道闪电', fx = { chainHit = 0.25 } },
    chronogear = { kind = 'equip', rar = 2, name = '时之齿轮', icon = 'i_compass', pal = nil, desc = '技能能量获取 +20%', fx = { charge = 0.2 } },
    lifebloom = { kind = 'equip', rar = 2, name = '生命之花', icon = 'i_flask', pal = nil, desc = '每秒回复 2% 最大生命', fx = { regen = 0.02 } },
    titanbelt = { kind = 'equip', rar = 3, name = '泰坦腰带', icon = 'i_glove', pal = { h = '#c8900f', H = '#ffe680', g = '#7a1f2b' }, desc = '生命 +35%，攻击 +12%', fx = { hp = 0.35, atk = 0.12 } },
}
local ORDER = { 'whetstone', 'warhelm', 'frostcharm', 'emberblade', 'vampfang', 'hawkeye', 'quiver', 'manaorb', 'aegisplate', 'stormring', 'chronogear', 'lifebloom', 'titanbelt' }
-- 插到原有装备的后面（图鉴按这个顺序列出）
local at = ITEM_KEYS:indexOf('soulgem') + 1
for i, k in ipairs(ORDER) do ITEMS[k] = NEW[k]; ITEM_KEYS:splice(at + i - 1, 0, k) end
-- 原有装备的说明里「每个单位 1 件」改成 3 件
ITEMS.gear.desc = '附带一条额外词条'

-- ---------------------------------------------------------------------------
-- 界面：选中单位时的装备说明
-- ---------------------------------------------------------------------------
function UI.equipLine(u)
    local l = equipsOf(u)
    if #l == 0 then return '<br>装备 <span style="color:#9a8ab0">空（' .. S(EQUIP_SLOTS) .. ' 个装备栏）</span>' end
    local parts = {}
    for _, it in ipairs(l) do parts[#parts + 1] = '<b style="color:' .. QUAL[it.rar].color .. '">' .. itemName(it) .. '</b>（' .. itemDesc(it):gsub('<br>.*', '') .. '）' end
    return '<br>装备 ' .. S(#l) .. '/' .. S(EQUIP_SLOTS) .. '：' .. table.concat(parts, '；')
end

local function slotsHTML(u, sellable)
    local l = equipsOf(u)
    local out = {}
    for i = 1, EQUIP_SLOTS do
        local it = l[i]
        if it then
            local Q = QUAL[it.rar]
            out[#out + 1] = '<span class="eqs" style="--qc:' .. Q.color .. '"><img src="' .. itemIcon(it) .. '" alt=""><span class="eqn"><b>' .. itemName(it) .. '</b><small>' .. itemDesc(it):gsub('<br>.*', '') .. '</small></span>' ..
                (sellable and ('<span class="eqb"><button class="chip go" data-mv="' .. S(u.id) .. ':' .. S(i) .. '">转移</button>' ..
                    '<button class="chip" data-un="' .. S(u.id) .. ':' .. S(i) .. '"' .. (stashFull() and ' disabled' or '') .. '>卸下</button>' ..
                    '<button class="chip" data-sell="' .. S(u.id) .. ':' .. S(i) .. '">卖 ' .. S(sellPrice(it)) .. ' 秘银</button></span>') or '') .. '</span>'
        else
            out[#out + 1] = '<span class="eqs empty"><i></i><span class="eqn"><small>空装备栏</small></span></span>'
        end
    end
    return table.concat(out)
end

-- ---------------------------------------------------------------------------
-- 买到装备：选一个单位；装备栏满了再选换下哪一件
-- 第七次更新：换下的装备放进「仓库」，不再直接折成秘银；也可以先整件放进仓库
-- ---------------------------------------------------------------------------
local function flashUnit(u, col)
    if not FX.P then return end
    local s = findSlot(u)
    if s then local p = slotPos(s); FX.P.ring(p.x, p.y, 2, 14, col, { thick = 2, dur = 0.5 }); FX.P.sparks(p.x, p.y, col, 10) end
end
local function minisOf(u)
    local l = equipsOf(u)
    local ic = {}
    for k = 1, EQUIP_SLOTS do
        local e = l[k]
        ic[#ic + 1] = e and ('<img class="mini" src="' .. itemIcon(e) .. '" alt="" style="outline:1px solid ' .. QUAL[e.rar].color .. '">') or '<i class="mini0"></i>'
    end
    return '<span class="minis">' .. table.concat(ic) .. '</span>'
end
local function stashCount() return S(#stashOf()) .. '/' .. S(STASH_SLOTS) end
--- 换下一件时，旧装备的去向说明
local function oldFate(old, fate)
    if not old then return '' end
    if fate == 'sold' then return '，仓库已满，换下的 ' .. itemName(old) .. ' 折成 ' .. S(sellPrice(old)) .. ' 秘银' end
    return '，换下的 ' .. itemName(old) .. ' 放进了仓库'
end
local function afterEquipChange()
    UI.cache:set('info', nil); UI.cache:set('itembar', nil)
end

function UI.showEquipPick(it, after)
    local list = equipCandidates(it)
    local sfull = stashFull()
    local body = '<p>把 <b>' .. itemName(it) .. '</b> 交给谁？' .. itemDesc(it) .. '</p><p class="dim">每个单位有 ' .. S(EQUIP_SLOTS) .. ' 个装备栏；装满的单位要换下一件，<b>换下的放进仓库</b>（' .. stashCount() .. '），以后可以再装给别人。也可以先放进仓库，在顶栏「商店 → 装备管理」里随时装上。</p>' ..
        '<div class="pick-list">' .. list:map(function(u, i)
            local st = unitStats(u)
            local where = (findSlot(u).t == 'b') and '备战席' or '阵地'
            local l = equipsOf(u)
            return '<button class="pick-unit" data-u="' .. S(i) .. '"><img src="' .. unitIconURL(u) .. '" alt="">' ..
                '<span>' .. qSpan(u) .. ' ' .. minisOf(u) .. '</span><small>' .. where .. ' · 生命 ' .. S(st.hp) .. ' 攻击 ' .. S(st.atk) .. ' · 装备 ' .. S(#l) .. '/' .. S(EQUIP_SLOTS) .. ((#l >= EQUIP_SLOTS) and '（已满，换下的进仓库）' or '') .. '</small></button>'
        end):join('') ..
        '<button class="pick-unit stash-pick" data-stash="1"' .. (sfull and ' disabled' or '') .. '><img src="' .. itemIcon(it) .. '" alt=""><span>放进仓库</span><small>' ..
        (sfull and '仓库已满' or '先不装，以后在「商店 → 装备管理」里装给角色') .. ' · 仓库 ' .. stashCount() .. '</small></button>' ..
        '</div>'
    UI.modal('装备 ' .. itemName(it), body, nil)
    UI.els.mTitle.parent:addClass('wide')
    local function done(u, old, fate)
        Sound.play('equip') -- 第十三次更新：装备 / 换装有专属音效
        UI.toast(unitName(u) .. ' 装备了 ' .. itemName(it) .. oldFate(old, fate))
        UI.els.overlay:setHidden(true)
        flashUnit(u, QUAL[it.rar].color) -- 装上时在单位身上闪一下
        afterEquipChange()
        if after then after() end
    end
    local sb = UI.els.mBody:querySelector('[data-stash]')
    if sb then sb:addEventListener('click', function()
        if sb:isDisabled() then return end
        Sound.init()
        if not stashPut(it) then Sound.play('deny'); return end
        Sound.play('unequip')
        UI.toast(itemName(it) .. ' 放进了仓库（' .. stashCount() .. '）')
        UI.els.overlay:setHidden(true)
        afterEquipChange()
        if after then after() end
    end) end
    for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-u]')) do
        b:addEventListener('click', function()
            Sound.init()
            local u = list[tonumber(b:data('u'))]
            if #equipsOf(u) < EQUIP_SLOTS then done(u, equipItem(it, u)); return end
            -- 已满：选要换下的那件（换下的进仓库）
            local full = stashFull()
            local opts = {}
            for k, e in ipairs(equipsOf(u)) do
                opts[#opts + 1] = '<button class="pick-unit" data-r="' .. S(k) .. '"><img src="' .. itemIcon(e) .. '" alt=""><span style="color:' .. QUAL[e.rar].color .. '">换下 ' .. itemName(e) .. '</span><small>' ..
                    (full and ('仓库已满，折成 ' .. S(sellPrice(e)) .. ' 秘银') or '放进仓库') .. ' · ' .. itemDesc(e):gsub('<br>.*', '') .. '</small></button>'
            end
            UI.modal(unitName(u) .. ' 的装备栏已满', '<p>换下哪一件来装 <b>' .. itemName(it) .. '</b>？换下的装备放进仓库（' .. stashCount() .. '），以后可以再装给别人。</p><div class="pick-list">' .. table.concat(opts) .. '</div>',
                '返回', function() UI.showEquipPick(it, after) end)
            for _, rb in ipairs(UI.els.mBody:querySelectorAll('[data-r]')) do
                rb:addEventListener('click', function() Sound.init(); done(u, equipItem(it, u, tonumber(rb:data('r')))) end)
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- 仓库：把仓库里的一件交给某个单位 / 给某个单位挑一件仓库里的
-- ---------------------------------------------------------------------------
--- 仓库第 k 件 → 选单位（对方满了选一件互换，换下的放回仓库）
function UI.pickUnitForStash(k, back)
    local it = stashOf()[k]
    if not it then return end
    local list = allUnits():filter(function(v) return canEquipItem(it, v) end)
    if #list == 0 then UI.toast('没有能装备它的单位（远程专属或兵种限定）'); Sound.play('deny'); return end
    local function finish(u, r)
        local ok, old
        if r then ok, old = stashSwap(k, u, r) else ok, old = stashEquip(k, u) end
        if not ok then Sound.play('deny'); return end
        Sound.play('equip'); flashUnit(u, QUAL[it.rar].color)
        UI.toast(unitName(u) .. ' 装备了 ' .. itemName(it) .. (old and ('，换下的 ' .. itemName(old) .. ' 放回仓库') or ''))
        afterEquipChange()
        if back then back() else UI.els.overlay:setHidden(true) end
    end
    local body = '<p>把仓库里的 <b style="color:' .. QUAL[it.rar].color .. '">' .. itemName(it) .. '</b> 交给谁？' .. itemDesc(it) .. '</p><p class="dim">对方装备栏满了，就选一件换下来放回仓库（不花钱）。</p><div class="pick-list">' ..
        list:map(function(v, i)
            local l = equipsOf(v)
            local where = (findSlot(v).t == 'b') and '备战席' or '阵地'
            return '<button class="pick-unit" data-t="' .. S(i) .. '"><img src="' .. unitIconURL(v) .. '" alt=""><span>' .. qSpan(v) .. ' ' .. minisOf(v) .. '</span><small>' .. where ..
                ' · 装备 ' .. S(#l) .. '/' .. S(EQUIP_SLOTS) .. ((#l >= EQUIP_SLOTS) and '（已满，选一件换回仓库）' or '') .. '</small></button>'
        end):join('') .. '</div>'
    UI.modal('从仓库装备', body, '返回', function() if back then back() end end)
    UI.els.mTitle.parent:addClass('wide')
    for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-t]')) do
        b:addEventListener('click', function()
            Sound.init()
            local v = list[tonumber(b:data('t'))]
            if #equipsOf(v) < EQUIP_SLOTS then finish(v); return end
            local opts = {}
            for r, e in ipairs(equipsOf(v)) do
                opts[#opts + 1] = '<button class="pick-unit" data-r="' .. S(r) .. '"><img src="' .. itemIcon(e) .. '" alt=""><span style="color:' .. QUAL[e.rar].color .. '">换下 ' .. itemName(e) .. '</span><small>放回仓库 · ' .. itemDesc(e):gsub('<br>.*', '') .. '</small></button>'
            end
            UI.modal(unitName(v) .. ' 的装备栏已满', '<p>换下哪一件来装 <b>' .. itemName(it) .. '</b>？换下的放回仓库。</p><div class="pick-list">' .. table.concat(opts) .. '</div>',
                '返回', function() UI.pickUnitForStash(k, back) end)
            for _, rb in ipairs(UI.els.mBody:querySelectorAll('[data-r]')) do
                rb:addEventListener('click', function() Sound.init(); finish(v, tonumber(rb:data('r'))) end)
            end
        end)
    end
end

--- 给单位 u 从仓库挑一件。slot 给了就和这一栏互换；没给时有空栏直接装，满了再选换下哪件
function UI.showStashFor(u, slot, back)
    local ks = stashFor(u)
    if #ks == 0 then UI.toast('仓库里没有 ' .. unitName(u) .. ' 能装备的装备'); Sound.play('deny'); return end
    local cur = slot and equipsOf(u)[slot]
    local function finish(k, r)
        local it = stashOf()[k]
        local ok, old
        if r then ok, old = stashSwap(k, u, r) else ok, old = stashEquip(k, u) end
        if not ok then Sound.play('deny'); return end
        Sound.play('equip'); flashUnit(u, QUAL[it.rar].color)
        UI.toast(unitName(u) .. ' 装备了 ' .. itemName(it) .. (old and ('，换下的 ' .. itemName(old) .. ' 放回仓库') or ''))
        afterEquipChange()
        if back then back() else UI.els.overlay:setHidden(true) end
    end
    local opts = {}
    for _, k in ipairs(ks) do
        local e = stashOf()[k]
        opts[#opts + 1] = '<button class="pick-unit" data-k="' .. S(k) .. '"><img src="' .. itemIcon(e) .. '" alt=""><span style="color:' .. QUAL[e.rar].color .. '">' .. itemName(e) .. '</span><small>' .. itemDesc(e):gsub('<br>.*', '') .. '</small></button>'
    end
    local head = cur and ('<p>用仓库里的哪一件换下 ' .. qSpan(u) .. ' 的 <b style="color:' .. QUAL[cur.rar].color .. '">' .. itemName(cur) .. '</b>？换下的放回仓库。</p>')
        or ('<p>给 ' .. qSpan(u) .. ' 装上仓库里的哪一件？（装备 ' .. S(#equipsOf(u)) .. '/' .. S(EQUIP_SLOTS) .. '）</p>')
    UI.modal('仓库 ' .. stashCount(), head .. '<div class="pick-list">' .. table.concat(opts) .. '</div>', back and '返回' or '关闭', function() if back then back() end end)
    UI.els.mTitle.parent:addClass('wide')
    for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-k]')) do
        b:addEventListener('click', function()
            Sound.init()
            local k = tonumber(b:data('k'))
            if slot then finish(k, slot); return end
            if #equipsOf(u) < EQUIP_SLOTS then finish(k); return end
            local it = stashOf()[k]
            local o2 = {}
            for r, e in ipairs(equipsOf(u)) do
                o2[#o2 + 1] = '<button class="pick-unit" data-r="' .. S(r) .. '"><img src="' .. itemIcon(e) .. '" alt=""><span style="color:' .. QUAL[e.rar].color .. '">换下 ' .. itemName(e) .. '</span><small>放回仓库 · ' .. itemDesc(e):gsub('<br>.*', '') .. '</small></button>'
            end
            UI.modal(unitName(u) .. ' 的装备栏已满', '<p>换下哪一件来装 <b>' .. itemName(it) .. '</b>？换下的放回仓库。</p><div class="pick-list">' .. table.concat(o2) .. '</div>',
                '返回', function() UI.showStashFor(u, slot, back) end)
            for _, rb in ipairs(UI.els.mBody:querySelectorAll('[data-r]')) do
                rb:addEventListener('click', function() Sound.init(); finish(k, tonumber(rb:data('r'))) end)
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- 顶栏「装备」：全部单位的装备一览（布阵阶段可以卖出）
-- ---------------------------------------------------------------------------
function UI.equipOverviewHTML()
    local canSell = G.phase == 'prep'
    local units = allUnits()
    if #units == 0 then return '<p class="dim">还没有单位。先拉杆召唤吧。</p>' end
    local rows = units:map(function(u)
        local where = (findSlot(u).t == 'b') and '备战席' or '阵地'
        return '<div class="eq-row"><div class="eq-who"><img src="' .. unitIconURL(u) .. '" alt=""><span>' .. qSpan(u) .. '<small>' .. where .. '</small></span></div><div class="eq-slots">' .. slotsHTML(u, canSell) .. '</div></div>'
    end):join('')
    -- 第七次更新：仓库放在最上面
    local st = stashOf()
    local cells = {}
    for k = 1, STASH_SLOTS do
        local it = st[k]
        if it then
            cells[#cells + 1] = '<span class="eqs" style="--qc:' .. QUAL[it.rar].color .. '"><img src="' .. itemIcon(it) .. '" alt=""><span class="eqn"><b>' .. itemName(it) .. '</b><small>' .. itemDesc(it):gsub('<br>.*', '') .. '</small></span>' ..
                (canSell and ('<span class="eqb"><button class="chip go" data-sq="' .. S(k) .. '">装备</button><button class="chip" data-ss="' .. S(k) .. '">卖 ' .. S(sellPrice(it)) .. ' 秘银</button></span>') or '') .. '</span>'
        else
            cells[#cells + 1] = '<span class="eqs empty"><i></i><span class="eqn"><small>空</small></span></span>'
        end
    end
    local stashRow = '<div class="eq-row eq-stash"><div class="eq-who"><span>仓库<small>' .. S(#st) .. '/' .. S(STASH_SLOTS) .. ' · 换下 / 卸下的装备放这里</small></span></div><div class="eq-slots">' .. table.concat(cells) .. '</div></div>'
    return '<p class="dim">每个单位 ' .. S(EQUIP_SLOTS) .. ' 个装备栏。装备在「道具商店」用秘银购买，精英波战利品也可能出装备；布阵时战场上单位身边的小图标就是它带的装备（外框颜色是品质）。' ..
        (canSell and '修整阶段可以「卸下」装备放进仓库、从仓库「装备」给任何角色、「转移」给别的单位（对方满了就互换），或者卖掉。' or '战斗中只能查看。') .. '</p><div class="eq-list">' .. stashRow .. rows .. '</div>'
end
function UI.showEquipOverview()
    -- 第九次更新：装备管理和道具商店是同一个界面的两个页签
    -- 第十四次更新：内容和交互改成拖放，见 equipdrag.lua（UI.equipOverviewHTML / UI.bindEquipOverview）
    UI.modal('商店', UI.shopTabsHTML('equip') .. '<div id="eqv">' .. UI.equipOverviewHTML() .. '</div>', UI.backLabel())
    UI.els.mTitle.parent:addClass('wide')
    UI.bindShopTabs()
    if UI.bindEquipOverview then UI.bindEquipOverview() end
end

-- ---------------------------------------------------------------------------
-- 战场上的装备标记（只在布阵阶段画）：单位脚边一排 2×2 的小方块，颜色是装备品质
-- ---------------------------------------------------------------------------
function drawEquipMarks()
    if G.phase ~= 'prep' and G.phase ~= 'spinning' and G.phase ~= 'resolving' then return end
    local function mark(u, p)
        local l = u.equips
        if not l or #l == 0 then return end
        local n = #l
        local x0 = round(p.x + 7)
        local y0 = round(p.y + 6 - (n - 1) * 3)
        for i = 1, n do
            local y = y0 + (i - 1) * 3
            actx.fillStyle = PAL.k; actx:fillRect(x0 - 1, y - 1, 4, 4)
            actx.fillStyle = QUAL[l[i].rar].color; actx:fillRect(x0, y, 2, 2)
        end
    end
    G.form:forEach(function(u, i) if u and not (drag and drag.moved and drag.u == u) then mark(u, fPos(i)) end end)
    G.bench:forEach(function(u, i) if u and not (drag and drag.moved and drag.u == u) then mark(u, bPos(i)) end end)
end

return true
