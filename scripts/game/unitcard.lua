-- ============================================================================
-- 第三次更新：点选单位 / 装备管理 / 圣物栏 / 紧凑菜单
--  * 点选单位：战场上它头顶常驻经验（吞噬）进度条；信息栏改成卡片——头像、属性、经验条、3 个装备栏（带图标）
--  * 战场上单位身边的装备不再是白色小方块，而是缩小的装备图标（外框颜色 = 品质）
--  * 修整阶段（布阵 / 商店）可以把装备转给别的单位；对方装备栏满了就和它的一件互换
--  * 圣物栏：图标放大、带品质边框，点一下弹出全部圣物的说明（手机上没有悬停提示）
--  * 矮横屏 / 窄侧栏：顶栏的主页、音效、图鉴、玩法收进「菜单」，不再挤掉老虎机和开战按钮
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local floor, max, min = math.floor, math.max, math.min
local round = js.round
local PX = require("game.pixel")
local function _id(id) return PAGE.doc.getElementById(id) end

local function inPrep() return G and (G.phase == 'prep') end
--- 装备说明只取第一行（去掉「代价」之类的第二行）
local function shortDesc(it) return (itemDesc(it):gsub('<br>.*', '')) end

-- ---------------------------------------------------------------------------
-- 缩小的装备图标（战场上用）：16×16 → 8×8，每 2×2 取出现最多的非描边颜色
-- ---------------------------------------------------------------------------
local miniCache = {}
function miniIcon(key)
    local c = miniCache[key]
    if c ~= nil then return c or nil end
    local src = ICONS[key]
    if not src then miniCache[key] = false; return nil end
    local img = PX.newImage(8, 8)
    local sw, sh = src.width, src.height
    local K = PAL.k
    for by = 0, 7 do
        for bx = 0, 7 do
            local x0, x1 = floor(bx * sw / 8), max(floor(bx * sw / 8), floor((bx + 1) * sw / 8) - 1)
            local y0, y1 = floor(by * sh / 8), max(floor(by * sh / 8), floor((by + 1) * sh / 8) - 1)
            local cnt, best, bn, nk, tot = {}, nil, 0, 0, 0
            for yy = y0, y1 do for xx = x0, x1 do
                local col = src:get(xx, yy)
                if col then
                    tot = tot + 1
                    if col == K then nk = nk + 1
                    else
                        cnt[col] = (cnt[col] or 0) + 1
                        if cnt[col] > bn then best, bn = col, cnt[col] end
                    end
                end
            end end
            local area = (x1 - x0 + 1) * (y1 - y0 + 1)
            if best and (bn >= nk or nk < area * 0.75) then img:set(bx, by, best)
            elseif nk > 0 then img:set(bx, by, K) end
        end
    end
    miniCache[key] = img
    return img
end

-- ---------------------------------------------------------------------------
-- 战场：装备图标 + 选中单位的经验条
-- ---------------------------------------------------------------------------
local function expActive(u)
    for _, a in ipairs(FX.anims or {}) do if a.kind == 'expbar' and a.unit == u then return true end end
    return false
end
--- 经验进度：返回 当前, 满值, 是否已满
function expOf(u)
    local full = STAR_PTS[3]
    if u.awakenReady or u.star >= 3 then return full, full, true end
    return min(u.pts or 0, full), full, false
end
local function drawSelExp(u, p)
    if isSup(u) or u.branch or expActive(u) then return end
    local cur, full, done = expOf(u)
    local W = 28
    local bx, by = round(p.x - W / 2), round(p.y - 24)
    actx.globalAlpha = 1
    actx.fillStyle = PAL.k; actx:fillRect(bx - 1, by - 1, W + 2, 5)
    actx.fillStyle = '#2d2245'; actx:fillRect(bx, by, W, 3)
    actx.fillStyle = done and '#ffd84a' or '#8fe07a'; actx:fillRect(bx, by, round(W * cur / full), 3)
    actx.fillStyle = PAL.k; actx:fillRect(bx + round(W * STAR_PTS[2] / full), by, 1, 3) -- ★★ 门槛
    pixText(actx, done and 'MAX' or (S(cur) .. '/' .. S(full)), p.x, by - 7, done and '#ffd84a' or '#e6ffd6')
end
local function drawMarks(u, p)
    local l = u.equips
    if not l or #l == 0 then return end
    local x0 = round(p.x + 9)
    local y0 = round(p.y - 13)
    for i, it in ipairs(l) do
        local y = y0 + (i - 1) * 9
        actx.fillStyle = QUAL[it.rar].color; actx:fillRect(x0, y, 10, 10)
        actx.fillStyle = '#1b1530'; actx:fillRect(x0 + 1, y + 1, 8, 8)
        local m = miniIcon(itemIcon(it))
        if m then actx:drawImage(m, x0 + 1, y + 1) end
    end
end
function drawEquipMarks()
    if G.phase ~= 'prep' and G.phase ~= 'spinning' and G.phase ~= 'resolving' then return end
    local moving = drag and drag.moved
    G.form:forEach(function(u, i) if u and not (moving and drag.u == u) then drawMarks(u, fPos(i)) end end)
    G.bench:forEach(function(u, i) if u and not (moving and drag.u == u) then drawMarks(u, bPos(i)) end end)
    if G.sel and not moving then
        local s = findSlot(G.sel)
        if s then drawSelExp(G.sel, slotPos(s)) end
    end
end

-- ---------------------------------------------------------------------------
-- 信息栏：选中单位的卡片
-- ---------------------------------------------------------------------------
local function eqChips(u, clickable)
    local l = equipsOf(u)
    local out = {}
    -- 第七次更新：修整阶段仓库里有能装的，空栏变成「+」按钮，点一下从仓库装上
    local canAdd = clickable and inPrep() and #stashFor(u) > 0
    for i = 1, EQUIP_SLOTS do
        local it = l[i]
        if it then
            out[#out + 1] = '<button class="ueq" data-eq="' .. S(i) .. '" style="--qc:' .. QUAL[it.rar].color .. '"' .. (clickable and '' or ' disabled') .. '><img src="' .. itemIcon(it) .. '" alt=""><span>' .. itemName(it) .. '</span></button>'
        elseif canAdd then
            out[#out + 1] = '<button class="ueq empty add" data-eqadd="1" aria-label="从仓库装备"><i>+</i><span>仓库</span></button>'
        else
            out[#out + 1] = '<span class="ueq empty"><i></i><span>空</span></span>'
        end
    end
    return table.concat(out)
end
function UI.expBarHTML(u)
    if isSup(u) then return '<span class="uc-exp"><small class="supline">超凡角色，不用转职，不能被吸收</small></span>' end
    if u.branch then return '<span class="uc-exp"><small>已转职 · 不能再吸收经验</small></span>' end
    local cur, full, done = expOf(u)
    local up = canPromote(u)
    -- 第九次更新：吞噬即成长，显示比本星级基础高了多少
    local gb = absorbBonus and absorbBonus(u) or 0
    local grow = (not done and gb >= 0.005) and (' · <span style="color:#8fe07a">吞噬成长 +' .. S(round(gb * 100)) .. '%</span>') or ''
    local tail = done and ('<b class="up">已满 ' .. starStr(3) .. '，可以' .. (up and '转职或晋升' or '转职') .. '</b>')
        or ('经验 <b>' .. S(cur) .. '/' .. S(full) .. '</b> · 再 ' .. S(full - cur) .. ' 点可' .. (up and '转职/晋升' or '转职') .. grow)
    return '<span class="uc-exp"><span class="xbar"><i style="width:' .. S(round(cur / full * 100)) .. '%' .. (done and ';background:#ffd84a' or '') .. '"></i><em style="left:' .. S(round(STAR_PTS[2] / full * 100)) .. '%"></em></span><small>' .. tail .. '</small></span>'
end
function UI.unitCardHTML(u)
    local st = unitStats(u)
    local Af = AFFIXES:find(function(a) return a.id == u.affix.id end)
    local AQ = AFFIX_GRADE[u.affix.q]
    local SK = SKILLS[st.skill]
    local where = findSlot(u).t == 'b' and '<em class="uc-bench">备战席 · 不参战</em>' or ''
    local head = '<span class="uc-head"><img src="' .. unitIconURL(u) .. '" alt=""><span class="uc-nm"><b>' .. qSpan(u) .. '</b>' .. where ..
        '<small class="uc-st"><span class="st">生命 ' .. S(st.hp) .. '</span><span class="st">攻击 ' .. S(st.atk) .. '</span><span class="st">每秒 ' .. js.toFixed(1 / st.cd, 2) .. ' 次</span></small></span></span>'
    local eq = '<span class="uc-eq"><span class="lbl">装备 ' .. S(#equipsOf(u)) .. '/' .. S(EQUIP_SLOTS) .. '</span>' .. eqChips(u, true) .. '</span>'
    local lines = { '词条 <span style="color:' .. AQ.color .. '">' .. Af.name .. '（' .. AQ.name .. '）：' .. Af.fmt(u.affix.v) .. '</span>', '技能「' .. SK.name .. '」' .. SK.desc }
    if u.branch then lines[#lines + 1] = '被动 ' .. BRANCHES[u.branch].passive end
    local q = u.q or 0
    if isSup(u) then
        local SQ = QUAL[Q_SUP]
        lines[#lines + 1] = '品质 <span style="color:' .. SQ.color .. '">' .. SQ.name .. '</span>：基础属性 +' .. S(pct(SQ.base)) .. '%，超凡之力全属性 +' .. S(pct(SQ.awaken)) .. '%'
    elseif not u.branch then
        local UQ, NQ = QUAL[q], QUAL[q + 1]
        local promo = canPromote(u) and ('，或晋升为 <span style="color:' .. NQ.color .. '">' .. NQ.name .. '</span>') or ''
        lines[#lines + 1] = '品质 <span style="color:' .. UQ.color .. '">' .. UQ.name .. '</span>：' .. starStr(3) .. ' 可转职为 ' .. routeNames(u.cls, q) .. '（全属性 +' .. S(pct(UQ.awaken)) .. '%）' .. promo
    elseif T(q) then
        lines[#lines + 1] = '品质 <span style="color:' .. QUAL[q].color .. '">' .. QUAL[q].name .. '</span>：转职全属性 +' .. S(pct(QUAL[q].awaken)) .. '%'
    end
    return '<span class="ucard">' .. head .. UI.expBarHTML(u) .. eq .. '<span class="uc-txt">' .. table.concat(lines, '<br>') .. '</span></span>'
end
local _infoHTML = UI.infoHTML
function UI.infoHTML(units)
    if G.phase ~= 'battle' and G.phase ~= 'spinning' and G.phase ~= 'resolving' and not (drag and drag.moved) and G.sel and findSlot(G.sel) then
        return UI.unitCardHTML(G.sel)
    end
    local base = _infoHTML(units)
    -- 第四次更新：准备阶段没选单位时，信息栏下面列出全部单位（点一下就能选中），不留空
    if G.phase == 'prep' and not (drag and drag.moved) and T(units) then
        local parts = {}
        allUnits():forEach(function(u)
            local bench = findSlot(u) and findSlot(u).t == 'b'
            parts[#parts + 1] = '<button class="lu' .. (bench and ' bench' or '') .. '" data-uid="' .. S(u.id) .. '" style="--qc:' .. QUAL[u.q or 0].color .. '"><img src="' .. unitIconURL(u) .. '" alt=""><span>' .. qSpan(u) .. '</span></button>'
        end)
        base = base .. '<span class="lineup"><span class="lu-h">阵容 ' .. S(#G.form:filter(function(x) return x end)) .. '/' .. S(FORM_N) .. ' · 备战席 ' .. S(#G.bench:filter(function(x) return x end)) .. '/' .. S(BENCH_N) .. '</span>' .. table.concat(parts) .. '</span>'
    end
    return base
end
UI.equipLine = function(u) return '' end

-- ---------------------------------------------------------------------------
-- 装备管理：查看 / 转给别人 / 卖出
-- ---------------------------------------------------------------------------
local function unitById(id) return allUnits():find(function(x) return x.id == id end) end
local function afterChange(back)
    UI.cache:set('info', nil); UI.cache:set('itembar', nil)
    if back then back() else UI.els.overlay:setHidden(true) end
end
--- 把 u 的第 i 件装备转给 v；v 满了就和 v 的第 r 件互换
function transferEquip(u, i, v, r)
    local lu, lv = equipsOf(u), equipsOf(v)
    local it = lu[i]
    if not it or u == v then return false end
    if not canEquipItem(it, v) then return false end
    if #lv < EQUIP_SLOTS then
        table.remove(lu, i); lv[#lv + 1] = it
        return true
    end
    local old = lv[r or 1]
    if not canEquipItem(old, u) then return false end
    lv[r or 1] = it; lu[i] = old
    return true, old
end
local function flash(u, col)
    local s = findSlot(u)
    if s and FX.P then local p = slotPos(s); FX.P.ring(p.x, p.y, 2, 14, col, { thick = 2, dur = 0.5 }); FX.P.sparks(p.x, p.y, col, 10) end
end
function UI.showTransfer(u, i, back)
    local it = equipsOf(u)[i]
    if not it then return end
    local list = allUnits():filter(function(v) return v ~= u and canEquipItem(it, v) end)
    if #list == 0 then UI.toast('没有其他能装备它的单位'); Sound.play('deny'); return end
    local body = '<p>把 <b style="color:' .. QUAL[it.rar].color .. '">' .. itemName(it) .. '</b> 从 ' .. qSpan(u) .. ' 身上转给谁？对方装备栏满了，就和它的一件装备<b>互换</b>（不花钱）。</p><div class="pick-list">' ..
        list:map(function(v, k)
            local l = equipsOf(v)
            local ic = {}
            for n = 1, EQUIP_SLOTS do
                local e = l[n]
                ic[#ic + 1] = e and ('<img class="mini" src="' .. itemIcon(e) .. '" alt="" style="outline:1px solid ' .. QUAL[e.rar].color .. '">') or '<i class="mini0"></i>'
            end
            local where = (findSlot(v).t == 'b') and '备战席' or '阵地'
            return '<button class="pick-unit" data-t="' .. S(k) .. '"><img src="' .. unitIconURL(v) .. '" alt=""><span>' .. qSpan(v) .. ' <span class="minis">' .. table.concat(ic) .. '</span></span><small>' .. where ..
                ' · 装备 ' .. S(#l) .. '/' .. S(EQUIP_SLOTS) .. ((#l >= EQUIP_SLOTS) and '（已满，选一件互换）' or '') .. '</small></button>'
        end):join('') .. '</div>'
    UI.modal('转移装备', body, '取消', function() if back then back() end end)
    UI.els.mTitle.parent:addClass('wide')
    for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-t]')) do
        b:addEventListener('click', function()
            Sound.init()
            local v = list[tonumber(b:data('t'))]
            local function finish(r)
                local ok, old = transferEquip(u, i, v, r)
                if not ok then Sound.play('deny'); UI.toast('对方不能装备这件（远程专属或兵种限定）'); return end
                Sound.play('equip'); flash(v, QUAL[it.rar].color)
                UI.toast(itemName(it) .. ' 转给了 ' .. unitName(v) .. (old and ('，换回 ' .. itemName(old)) or ''))
                afterChange(back)
            end
            if #equipsOf(v) < EQUIP_SLOTS then finish(); return end
            local opts = {}
            for k, e in ipairs(equipsOf(v)) do
                local bad = not canEquipItem(e, u)
                opts[#opts + 1] = '<button class="pick-unit" data-r="' .. S(k) .. '"' .. (bad and ' disabled' or '') .. '><img src="' .. itemIcon(e) .. '" alt=""><span style="color:' .. QUAL[e.rar].color .. '">换回 ' .. itemName(e) .. '</span><small>' ..
                    (bad and ('远程专属或兵种限定，不能交给 ' .. unitName(u)) or shortDesc(e)) .. '</small></button>'
            end
            UI.modal(unitName(v) .. ' 的装备栏已满', '<p>用 <b>' .. itemName(it) .. '</b> 换回哪一件给 ' .. qSpan(u) .. '？</p><div class="pick-list">' .. table.concat(opts) .. '</div>', '取消', function() if back then back() end end)
            for _, rb in ipairs(UI.els.mBody:querySelectorAll('[data-r]')) do
                rb:addEventListener('click', function() Sound.init(); finish(tonumber(rb:data('r'))) end)
            end
        end)
    end
end
function UI.showEquipItem(u, i, back)
    local it = equipsOf(u)[i]
    if not it then return end
    local Q = QUAL[it.rar]
    local can = inPrep()
    local body = '<div class="eqd" style="--qc:' .. Q.color .. '"><img src="' .. itemIcon(it) .. '" alt=""><span><b>' .. itemName(it) .. '</b><small><span style="color:' .. Q.color .. '">' .. Q.name .. '</span> · 装备 · ' .. qSpan(u) .. ' 第 ' .. S(i) .. ' 栏</small></span></div>' ..
        '<p>' .. itemDesc(it) .. '</p>' ..
        (can and ('<div class="eqd-btns"><button class="chip go" id="eqMove">转给其他单位</button>' ..
            '<button class="chip" id="eqUn"' .. (stashFull() and ' disabled' or '') .. '>' .. (stashFull() and '仓库已满' or '卸下放进仓库') .. '</button>' ..
            ((#stashFor(u) > 0) and '<button class="chip" id="eqSw">和仓库里的换</button>' or '') ..
            '<button class="chip" id="eqSell">卖出 +' .. S(sellPrice(it)) .. ' 秘银</button></div>' ..
            '<p class="dim">仓库 ' .. S(#stashOf()) .. '/' .. S(STASH_SLOTS) .. '：卸下的装备放在仓库里，以后可以装给任何角色。</p>')
            or '<p class="dim">战斗中只能查看；修整（布阵）阶段可以转移、卸下、换装或卖出。</p>')
    UI.modal(itemName(it), body, '关闭', function() if back then back() end end)
    if can then
        _id('eqMove'):addEventListener('click', function() Sound.init(); UI.showTransfer(u, i, back) end)
        -- 第七次更新：卸下放进仓库、和仓库里的互换
        _id('eqUn'):addEventListener('click', function()
            if _id('eqUn'):isDisabled() then return end
            Sound.init()
            if unequipToStash(u, i) then Sound.play('unequip'); UI.toast(itemName(it) .. ' 卸下，放进了仓库') else Sound.play('deny'); UI.toast('仓库已满') end
            afterChange(back)
        end)
        local sw = _id('eqSw')
        if sw then sw:addEventListener('click', function() Sound.init(); UI.showStashFor(u, i, back) end) end
        _id('eqSell'):addEventListener('click', function()
            Sound.init()
            local p = unequipSell(u, i)
            if p > 0 then Sound.play('sell'); UI.toast('卖出 ' .. itemName(it) .. '，+' .. S(p) .. ' 秘银'); UI.bumpGems() end
            afterChange(back)
        end)
    end
end

-- ---------------------------------------------------------------------------
-- 圣物栏：放大、带品质框，点开看说明
-- ---------------------------------------------------------------------------
function UI.showRelics()
    local rows = G.relics:map(function(it)
        local Q = QUAL[it.rar]
        return '<div class="eqd" style="--qc:' .. Q.color .. '"><img src="' .. itemIcon(it) .. '" alt=""><span><b>' .. itemName(it) .. '</b><small><span style="color:' .. Q.color .. '">' .. Q.name .. '</span> · 圣物 · ' .. (ITEMS[it.id].grp or '') .. '</small><small class="d">' .. itemDesc(it) .. '</small></span></div>'
    end):join('')
    local cons = G.cons:map(function(it)
        local Q = QUAL[it.rar]
        return '<div class="eqd" style="--qc:' .. Q.color .. '"><img src="' .. itemIcon(it) .. '" alt=""><span><b>' .. itemName(it) .. '</b><small><span style="color:' .. Q.color .. '">' .. Q.name .. '</span> · 消耗品</small><small class="d">' .. itemDesc(it) .. '</small></span></div>'
    end):join('')
    UI.modal('圣物与消耗品', '<p class="dim">圣物 ' .. S(#G.relics) .. '/' .. S(RELIC_SLOTS) .. '：全队被动效果，一直生效。</p>' .. (rows ~= '' and rows or '<p class="dim">还没有圣物，顶栏「商店」和精英战利品里可以拿到。</p>') ..
        '<p class="dim">消耗品 ' .. S(#G.cons) .. '/' .. S(CONS_SLOTS) .. '：在右侧道具栏点击使用。</p>' .. cons, '关闭')
    UI.els.mTitle.parent:addClass('wide')
end
local _updateItemBar = UI.updateItemBar
function UI.updateItemBar()
    local bar = UI.els.itemBar
    if not bar then return end
    local key = UI.itemBarKey()
    if UI.cache:get('itembar') == key then return end
    UI.cache:set('itembar', key)
    if G.tutorial then bar:setHidden(true); return end
    bar:setHidden(false)
    local parts = { '<span class="lbl">圣物</span>' }
    G.relics:forEach(function(it, i)
        parts[#parts + 1] = '<button class="rel" data-rel="' .. S(i) .. '" style="--qc:' .. QUAL[it.rar].color .. '" aria-label="' .. itemName(it) .. '"><img src="' .. itemIcon(it) .. '" alt=""></button>'
    end)
    for _ = #G.relics, RELIC_SLOTS - 1 do parts[#parts + 1] = '<span class="rel0"></span>' end
    parts[#parts + 1] = '<span class="sep"></span><span class="lbl">消耗品</span>'
    for i = 0, CONS_SLOTS - 1 do
        local it = G.cons[i]
        if it then
            local ok = canUseCons(it)
            parts[#parts + 1] = '<button class="cons" data-i="' .. S(i) .. '" style="--qc:' .. QUAL[it.rar].color .. '" aria-label="使用 ' .. itemName(it) .. '"' .. (ok and '' or ' disabled') .. '><img src="' .. itemIcon(it) .. '" alt=""></button>'
        else parts[#parts + 1] = '<span class="slot0"></span>' end
    end
    local tip = ''
    if G.lockNext then tip = tip .. ' 锁轴' end
    if G.diceNext then tip = tip .. ' 骰子' end
    if tip ~= '' then parts[#parts + 1] = '<span class="lbl">已生效：' .. tip .. '</span>' end
    bar:setHTML(table.concat(parts))
    for _, b in ipairs(bar:querySelectorAll('.cons')) do
        b:addEventListener('click', function()
            Sound.init()
            local i = tonumber(b:data('i'))
            local it = G.cons[i]
            if it and useCons(i) then UI.toast('使用 ' .. itemName(it)); UI.cache:set('itembar', nil) end
        end)
    end
    for _, b in ipairs(bar:querySelectorAll('.rel')) do
        b:addEventListener('click', function() Sound.init(); UI.showRelics() end)
    end
end

-- ---------------------------------------------------------------------------
-- 「菜单」：窄屏时收起主页 / 音效 / 图鉴 / 玩法
-- ---------------------------------------------------------------------------
--- 第七次更新：iPhone 横屏时菜单里的「灵动岛位置」（自动识别不准时手动指定在哪一侧）
ISLAND_STORE = 'reel-legion-island'
function UI.islandLabel()
    local m = store.get(ISLAND_STORE)
    if m == 'L' then return '灵动岛 在左' end
    if m == 'R' then return '灵动岛 在右' end
    return '灵动岛 自动（' .. ((SAFE_INFO and SAFE_INFO.side == 'R') and '右' or '左') .. '）'
end
function UI.showMenu()
    local snd = Sound.on and '音效 开' or '音效 关'
    UI.modal('菜单', '<div class="menu-list"><button class="btn alt" data-m="equipBtn">商店 / 装备</button><button class="btn alt" data-m="codexBtn">图鉴</button><button class="btn alt" data-m="helpBtn">玩法说明</button>' ..
        '<button class="btn alt" data-m="soundBtn" id="mSnd">' .. snd .. '</button><button class="btn alt" data-m="homeBtn">回到主页</button>' ..
        ((SAFE_INFO and SAFE_INFO.island) and ('<button class="btn alt" data-m="island" id="mIsl">' .. UI.islandLabel() .. '</button>') or '') .. '</div>', '回到战场')
    for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-m]')) do
        b:addEventListener('click', function()
            local id = b:data('m')
            if id == 'soundBtn' then PAGE:click(UI.els.soundBtn); b:setText(Sound.on and '音效 开' or '音效 关'); return end
            if id == 'island' then -- 第七次更新：灵动岛位置 自动 → 左 → 右 → 自动
                Sound.init()
                local m = store.get(ISLAND_STORE)
                local nxt = (m == 'L') and 'R' or ((m == 'R') and '' or 'L')
                if nxt == '' then -- 回到自动：删掉存档里的设置
                    store.data[ISLAND_STORE] = nil
                    if store.persist then pcall(store.persist, store.data) end
                else store.set(ISLAND_STORE, nxt); SAFE_INFO.side = nxt end
                SAFE_INFO.manual = nxt ~= ''
                if SAFE_INFO.refresh then SAFE_INFO.refresh() end -- main.lua：下一帧重新读安全区并排版
                b:setText(UI.islandLabel())
                return
            end
            UI.els.overlay:setHidden(true)
            PAGE:click(_id(id))
        end)
    end
end

local _init = UI.init
function UI.init()
    _init()
    local mb = _id('menuBtn')
    if mb then mb:addEventListener('click', function() Sound.init(); UI.showMenu() end) end
    -- 信息栏卡片里的装备：点开查看 / 转移 / 卖出（事件委托，卡片每次重绘都不用重新绑定）
    UI.els.info:addEventListener('click', function(ev)
        local n = ev.target
        while n and n ~= UI.els.info do
            if n.attrs and n.attrs['data-uid'] then
                local id = n.attrs['data-uid']
                local u = allUnits():find(function(x) return S(x.id) == id end)
                if u and G.phase == 'prep' then Sound.init(); G.sel = u; UI.cache:set('info', nil) end
                return
            end
            if n.attrs and n.attrs['data-eqadd'] then
                local u = G.sel
                if u and findSlot(u) and inPrep() then Sound.init(); UI.showStashFor(u) end
                return
            end
            if n.attrs and n.attrs['data-eq'] then
                local u = G.sel
                if u and findSlot(u) then Sound.init(); UI.showEquipItem(u, tonumber(n.attrs['data-eq'])) end
                return
            end
            n = n.parent
        end
    end)
end

return true
