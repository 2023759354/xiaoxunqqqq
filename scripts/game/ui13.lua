-- ============================================================================
-- 第十三次更新
--  * 背景音乐按界面切换：选英雄（选关 / 组建军团 / 结算）、拉杆布阵、商店各一首（曲目选择见 ui.lua 的 frame）
--    这里负责给弹窗打上「属于哪个界面」的标记 UI.musicScreen；从商店里打开的二级弹窗（选单位、换装）沿用商店的曲子
--  * 通关 / 覆灭结算界面重做：标题 + 一行概要、数据方块、军魂奖励、解锁列表、底部按钮，不再和选关界面挤在一起
--  * 精英战利品：可以锁定 1 件，刷新只换另外两件；第一次刷新免费，之后用秘银刷新（2 起，每次 +1）
--    波次越高，送的和刷出来的道具品质越高（lootOdds）
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local CONTENT = require("ui.content")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local floor, max, min = math.floor, math.max, math.min
local function _id(id) return PAGE.doc.getElementById(id) end
local function focusEl(el) if el then PAGE:focus(el, 'script') end end
local function str(b) return b and 'true' or 'false' end

-- ---------------------------------------------------------------------------
-- 音乐：弹窗属于哪个界面
-- ---------------------------------------------------------------------------
-- 从「没有弹窗」打开一个新弹窗时清掉标记；弹窗里换内容（二级弹窗）时沿用上一层的标记
UI.musicScreen = nil
local _modal = UI.modal
function UI.modal(...)
    if UI.els.overlay:isHidden() then UI.musicScreen = nil end
    return _modal(...)
end
local function tagScreen(name, scr)
    local f = UI[name]
    if not f then return end
    UI[name] = function(...)
        local r = table.pack(f(...))
        if not UI.els.overlay:isHidden() then UI.musicScreen = scr end
        return table.unpack(r, 1, r.n)
    end
end
tagScreen('showStart', 'select')
tagScreen('showSquad', 'select')
tagScreen('showShop', 'shop')
tagScreen('showShopAgain', 'shop')
tagScreen('showEquipOverview', 'shop')

-- ---------------------------------------------------------------------------
-- 结算界面（通关 / 覆灭）
-- ---------------------------------------------------------------------------
local function tile(label, value, color)
    return '<div class="rs-t"><b' .. (color and (' style="color:' .. color .. '"') or '') .. '>' .. value .. '</b><span>' .. label .. '</span></div>'
end
local function statTiles(st, extra)
    local h = {}
    for _, x in ipairs(extra or {}) do h[#h + 1] = x end
    h[#h + 1] = tile('拉杆', S(st.spins))
    h[#h + 1] = tile('召唤', S(st.summoned))
    h[#h + 1] = tile('最高星级', starStr(max(1, st.maxStar or 1)), '#ffd84a')
    h[#h + 1] = tile('最高品质', QUAL[st.maxQ or 0].name, QUAL[st.maxQ or 0].color)
    h[#h + 1] = tile('转职', S(st.awakened))
    if T(st.promoted) then h[#h + 1] = tile('晋升', S(st.promoted)) end
    if T(st.jackpots) then h[#h + 1] = tile('九格大奖', S(st.jackpots), '#ffe27a') end
    return '<div class="rs-stats">' .. table.concat(h) .. '</div>'
end
local function soulCard(s)
    if not s or not T(s.total) then return '' end
    local parts = A('守住 ' .. S(s.waves) .. ' 波 +' .. S(s.base))
    if T(s.bonus) then parts:push('通关 +' .. S(s.bonus)) end
    if T(s.first) then parts:push('首次通关 +' .. S(s.first)) end
    -- 看广告把本局军魂翻倍（每局 1 次）；已翻倍则显示标记。
    -- 今日广告额度用完时按钮仍在，文案改成「免费」直接领取。
    local dbl
    if s.doubled then
        dbl = '<em class="rs-dbl">已翻倍</em>'
    elseif G.adDouble < AD_DOUBLE_MAX then
        local adFree = Ads.available() and adLeftToday() <= 0
        dbl = '<button class="chip ad rs-ad" id="rsAdDouble">' ..
            (adFree and '免费 · 军魂翻倍' or '看广告 · 军魂翻倍') .. '</button>'
    else
        dbl = ''
    end
    return '<div class="rs-soul"><img src="' .. iconURL('m_soul') .. '" alt=""><div><b>+' .. S(s.total) .. '</b><span>军魂</span></div>' ..
        '<small>' .. parts:join(' · ') .. '</small>' .. dbl .. '</div>'
end
local function newsRow(tag, name, color, note)
    return '<li><em>' .. tag .. '</em><b style="color:' .. color .. '">' .. name .. '</b>' .. (note and ('<span>' .. note .. '</span>') or '') .. '</li>'
end

local _showResult = UI.showResult
function UI.showResult(res)
    if G.tutorial or (G.phase ~= 'victory' and G.phase ~= 'gameover') then return _showResult(res) end
    local Dd, C = curDiff(), curCh()
    local st = G.stats
    local win = G.phase == 'victory'
    local news, nextCh = {}, nil
    if win then
        OR(res.news, A()):forEach(function(n)
            local NC = CHAPTERS[n.c]
            local Nd = NC.diffs[n.d]
            if n.c ~= G.ch then
                news[#news + 1] = newsRow('新章节', NC.name .. '「' .. NC.title .. '」', NC.color)
                UI.pickCh = n.c; nextCh = NC
                CLASS_KEYS:forEach(function(k)
                    if CLASSES[k].unlock == n.c - 1 then news[#news + 1] = newsRow('新兵种', CLASSES[k].name, CLASS_COLOR[k], CLASSES[k].note) end
                end)
            else news[#news + 1] = newsRow('新难度', Nd.name, Nd.color, S(Nd.waves) .. ' 波 · ' .. S(Nd.lives) .. ' 命') end
        end)
        if #news > 0 then setTimeout(function() Sound.play('unlock') end, 700)
        elseif G.diff == #C.diffs - 1 then news[#news + 1] = newsRow('成就', '通关' .. C.name .. '最高难度「' .. Dd.name .. '」', Dd.color) end
    end
    local sub = '<span style="color:' .. C.color .. '">' .. C.name .. '「' .. C.title .. '」</span><span style="color:' .. Dd.color .. '">' .. Dd.name .. '</span>' ..
        (win and ('<span>守住全部 ' .. S(G.maxWave) .. ' 波</span><span>剩余生命 ' .. S(G.lives) .. '</span>')
            or ('<span>止步第 ' .. S(res.wave) .. ' 波</span><span>最佳 ' .. S(SAVE[G.ch].best[G.diff]) .. ' 波</span>'))
    local extra = win and {} or { tile('到达波次', S(res.wave) .. '/' .. S(G.maxWave), '#ff9b8c') }
    local side
    if #news > 0 then side = '<ul class="rs-news">' .. table.concat(news) .. '</ul>'
    elseif not win then side = '<p class="rs-tip">同职业互相吸收升到 ' .. starStr(3) .. ' 就能转职或晋升，比堆数量更有效。</p>'
    else side = '' end
    local primary = win and (nextCh and ('挑战' .. nextCh.name) or '继续选关') or '再战一次'
    local body = '<p class="rs-sub">' .. sub .. '</p>' .. statTiles(st, extra) ..
        '<div class="rs-mid' .. (side == '' and ' solo' or '') .. '">' .. soulCard(res.soul) .. side .. '</div>' ..
        '<div class="rs-foot"><button class="chip" id="rsHome">返回主页</button><button class="chip" id="rsForge">军团强化</button>' ..
        (win and '' or '<button class="chip" id="rsPick">选关</button>') ..
        '<button class="go-btn" id="rsGo">' .. primary .. '</button></div>'
    UI.modal(win and (C.bossName .. '倒下了') or '军团覆灭', body, nil)
    local m = UI.els.mTitle.parent
    m:addClass('wide', 'rs-m', win and 'rs-win' or 'rs-lose')
    UI.musicScreen = 'select'
    local ch, diff = G.ch, G.diff
    local function on(id, fn) local b = _id(id); if b then b:addEventListener('click', function() Sound.init(); fn() end) end end
    on('rsHome', function() UI.showHome() end)
    on('rsForge', function() UI.showForge('eco', 'run') end)
    on('rsPick', function() UI.pickCh = ch; UI.showStart('', '开始游戏') end)
    on('rsGo', function()
        if win then UI.showStart('', '开始游戏')
        else UI.pickCh = ch; UI.showSquad(ch, diff) end
    end)
    -- 军魂翻倍广告（第十三次更新后的结算界面也要有，沿用 ui.lua 里原来的确认流程）
    local adBtn = _id('rsAdDouble')
    if adBtn and res.soul then
        local s, run = res.soul, G
        adBtn:addEventListener('click', function()
            Sound.init()
            if G ~= run or G.adDouble >= AD_DOUBLE_MAX or s.doubled then return end
            UI.showAdConfirm('军魂翻倍', '看一段广告，本局结算的 <b>' .. S(s.total) .. ' 军魂</b>翻倍。', '每局 1 次',
                function() return G == run and G.adDouble < AD_DOUBLE_MAX and not s.doubled end,
                function() adDouble(s); UI.showResult(res) end,
                function() if G == run then UI.showResult(res) end end)
        end)
    end
    setTimeout(function() focusEl(_id('rsGo')) end, 40)
end
-- 结算弹窗用了自己的版式类，下一个弹窗要清掉
local _modal2 = UI.modal
function UI.modal(...)
    UI.els.mTitle.parent:removeClass('rs-m', 'rs-win', 'rs-lose', 'lt-m')
    return _modal2(...)
end

-- ---------------------------------------------------------------------------
-- 精英战利品：锁定 1 件 + 刷新（首次免费，之后秘银）+ 品质随波次提高
-- ---------------------------------------------------------------------------
LOOT_RE_BASE = 2 -- 付费刷新：2 秘银起，每次 +1
-- 品质概率（普通 / 稀有 / 史诗 / 传说），按波次在锚点之间线性插值；比同一波的商店高得多
local LOOT_ANCHORS = {
    { 5, { 20, 55, 25, 0 } },
    { 10, { 0, 45, 45, 10 } },
    { 15, { 0, 20, 55, 25 } },
    { 20, { 0, 5, 55, 40 } },
}
function lootOdds(w)
    w = w or 5
    local lo, hi = LOOT_ANCHORS[1], LOOT_ANCHORS[#LOOT_ANCHORS]
    if w <= lo[1] then return A(table.unpack(lo[2])) end
    if w >= hi[1] then return A(table.unpack(hi[2])) end
    for i = 1, #LOOT_ANCHORS - 1 do
        local a, b = LOOT_ANCHORS[i], LOOT_ANCHORS[i + 1]
        if w >= a[1] and w <= b[1] then
            local k = (w - a[1]) / (b[1] - a[1])
            local o = {}
            for q = 1, 4 do o[q] = a[2][q] + (b[2][q] - a[2][q]) * k end
            return A(table.unpack(o))
        end
    end
    return A(table.unpack(hi[2]))
end
local LOOT_KINDS = { 'relic', 'equip', 'cons' }
--- 一组战利品：{ kind, item, locked }（某类抽空时那一格不出现）
function rollLoot(wave)
    local odds = lootOdds(wave or G.wave)
    local ex = {}
    local out = A()
    for _, kind in ipairs(LOOT_KINDS) do
        local it = rollItem(kind, odds, ex)
        if it then out:push(it) end
    end
    return out
end

UI.lootWave = nil
local _afterBattle = UI.afterBattle
function UI.afterBattle(res)
    if res and res.wave then UI.lootWave = res.wave end
    return _afterBattle(res)
end

local function gem() return '<img class="gem-ic" src="' .. gemIcon() .. '" alt="秘银">' end
local function rarTag(it)
    local Q = QUAL[it.rar]
    return '<span style="color:' .. Q.color .. '">' .. Q.name .. '</span> · ' .. KIND_NAME_ITEM[ITEMS[it.id].kind]
end
local function oddsLine(odds)
    local tot = odds:reduce(function(a, b) return a + b end, 0)
    local parts = {}
    for q = 0, 3 do
        local p = odds[q]
        if p > 0 then parts[#parts + 1] = '<span style="color:' .. QUAL[q].color .. '">' .. QUAL[q].name .. ' ' .. S(js.round(p / tot * 100)) .. '%</span>' end
    end
    return table.concat(parts, ' · ')
end

-- 本地（第九次更新）调用约定是 showLoot(after, res)：第二个参数带本波结果。
-- 这里兼容两种写法：showLoot(after) / showLoot(after, res)，并用 res.wave 校正波次。
function UI.showLoot(after, res)
    if res and res.wave then UI.lootWave = res.wave end
    local wave = UI.lootWave or max(1, G.wave - 1)
    local odds = lootOdds(wave)
    local slots = rollLoot(wave):map(function(it) return { item = it, locked = false } end)
    local freeLeft, paid = 1, 0
    local function cost() return (freeLeft > 0) and 0 or (LOOT_RE_BASE + paid) end
    local render
    local function reroll()
        local c = cost()
        if gems() < c then Sound.play('deny'); UI.toast('秘银不足（可以在商店用金币兑换）'); return end
        local ex = {}
        slots:forEach(function(s) if s.locked then ex[s.item.id] = true end end)
        local changed = false
        slots = slots:map(function(s)
            if s.locked then return s end
            local it = rollItem(ITEMS[s.item.id].kind, odds, ex)
            if not it then return s end
            changed = true
            return { item = it, locked = false }
        end)
        if not changed then Sound.play('deny'); UI.toast('没有可以换的了'); return end
        if freeLeft > 0 then freeLeft = freeLeft - 1 else addGems(-c); paid = paid + 1; UI.bumpGems() end
        Sound.play('refresh')
        render()
    end
    render = function()
        local nLocked = #slots:filter(function(s) return s.locked end)
        local cards = slots:map(function(s, i)
            local it = s.item
            local Q = QUAL[it.rar]
            local full = slotFull(it)
            -- 第十五次更新：圣物栏满了照样能选，选的时候决定放仓库还是换下一件
            local relicFull = ITEMS[it.id].kind == 'relic' and relicBarFull()
            return '<div class="sh-card' .. (s.locked and ' locked' or '') .. '" style="--qc:' .. Q.color .. '">' ..
                '<div class="hd"><img src="' .. itemIcon(it) .. '" alt=""><span class="tt"><b>' .. itemName(it) .. '</b><small>' .. rarTag(it) .. '</small></span></div>' ..
                (s.locked and '<em class="fl">已锁定</em>' or '') ..
                '<p>' .. itemDesc(it) .. '</p><div class="btns">' ..
                '<button class="chip go buy" data-take="' .. S(i) .. '"' .. (full and ' disabled' or '') .. '>' .. (full and '槽位已满' or (relicFull and '就要（栏满）' or '就要这件')) .. '</button>' ..
                '<button class="chip lk' .. (s.locked and ' on' or '') .. '" data-lk="' .. S(i) .. '" aria-pressed="' .. str(s.locked) .. '" aria-label="' .. (s.locked and '取消锁定' or '锁定：刷新时保留') .. '">' .. (s.locked and '已锁' or '锁') .. '</button>' ..
                '</div></div>'
        end):join('')
        local c = cost()
        local canRe = nLocked < #slots and gems() >= c
        local body = '<p class="lt-sub">第 ' .. S(wave) .. ' 波精英战利品：<b>免费</b>挑一件。<b>锁定</b>一件后刷新，只换另外两件。</p>' ..
            '<p class="lt-odds">本波品质：' .. oddsLine(odds) .. '<span class="lt-hint">波次越高，品质越好</span></p>' ..
            '<div class="sh-grid lt-grid" style="--n:' .. S(max(1, #slots)) .. '">' .. cards .. '</div>' ..
            '<div class="sh-tools lt-tools"><div class="sh-rf"><button class="chip" id="lootRe"' .. (canRe and '' or ' disabled') .. '>刷新 ' ..
            ((c == 0) and '<b>免费</b>' or (gem() .. '<b>' .. S(c) .. '</b>')) .. '</button>' ..
            '<small>' .. ((freeLeft > 0) and '第一次免费，之后用秘银' or ('之后每次 +1 秘银')) .. '</small></div>' ..
            '<span class="sh-wallet lt-wallet"><span>' .. gem() .. '<b class="gemv">' .. S(gems()) .. '</b></span></span>' ..
            '<button class="chip" id="lootSkip">放弃</button></div>'
        UI.modal('精英战利品', body, nil)
        UI.els.mTitle.parent:addClass('wide', 'lt-m')
        local sk = _id('lootSkip')
        if sk then sk:addEventListener('click', function()
            Sound.init(); UI.els.overlay:setHidden(true); if after then after() end
        end) end
        local re = _id('lootRe')
        if re then re:addEventListener('click', function()
            if re:isDisabled() then return end
            Sound.init(); reroll()
        end) end
        for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-lk]')) do
            b:addEventListener('click', function()
                Sound.init()
                local s = slots[tonumber(b:data('lk'))]
                if s.locked then s.locked = false; Sound.play('unlockslot')
                else
                    slots:forEach(function(o) o.locked = false end) -- 只能锁 1 件：锁别的就把原来那件解开
                    s.locked = true; Sound.play('lock')
                end
                render()
                local f = UI.els.mBody:querySelector('[data-lk="' .. b:data('lk') .. '"]'); if f then focusEl(f) end
            end)
        end
        for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-take]')) do
            b:addEventListener('click', function()
                if b:isDisabled() then return end
                Sound.init()
                local it = slots[tonumber(b:data('take'))].item
                -- 第十五次更新：圣物栏满了 → 选「放进仓库」或「换下一件」；「返回」回到战利品界面
                if ITEMS[it.id].kind == 'relic' and relicBarFull() then
                    UI.relicFullPick(it, { back = function() render() end, done = function() if after then after() end end })
                    return
                end
                UI.els.overlay:setHidden(true)
                local r = gainItem(it)
                Sound.play('unlock')
                if r == 'equip' then
                    if #equipCandidates(it) > 0 or not stashFull() then UI.showEquipPick(it, after)
                    else addGems(sellPrice(it)); UI.toast('没有能装备它的单位，仓库也满了：折成 ' .. S(sellPrice(it)) .. ' 秘银'); if after then after() end end
                else UI.toast('获得 ' .. itemName(it)); if after then after() end end
            end)
        end
    end
    render()
end

-- ---------------------------------------------------------------------------
-- 样式
-- ---------------------------------------------------------------------------
CONTENT.css = CONTENT.css .. [==[
/* ===== 第十三次更新：结算界面 ===== */
.modal.rs-m { width: min(720px, 100%); }
.modal.rs-m h2 { margin-bottom: 4px; }
.modal.rs-lose h2 { color: #ff9b8c; }
.modal p.rs-sub { display: flex; flex-wrap: wrap; gap: 4px 0; margin: 0 0 12px; max-width: none; font-size: 14px; line-height: 1.5; color: var(--ink-dim); }
.modal p.rs-sub span + span::before { content: '·'; margin: 0 8px; color: var(--panel-hi); }
.rs-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(76px, 1fr)); gap: 6px; }
.rs-t { display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 7px 4px 6px; background: var(--night); border-bottom: 3px solid var(--panel-hi); }
.rs-t b { font-size: 18px; line-height: 1.2; color: var(--ink); white-space: nowrap; }
.rs-t span { font-size: 12px; line-height: 1.3; color: var(--ink-dim); white-space: nowrap; }
.rs-mid { display: grid; grid-template-columns: minmax(0, 220px) minmax(0, 1fr); gap: 8px; margin-top: 10px; align-items: stretch; }
.rs-mid.solo { grid-template-columns: 1fr; }
.rs-soul { display: grid; grid-template-columns: auto 1fr; align-items: center; gap: 4px 10px; padding: 8px 12px; background: var(--night); border-left: 5px solid var(--soul); }
.rs-soul img { width: 28px; height: 28px; image-rendering: pixelated; }
.rs-soul div { display: flex; align-items: baseline; gap: 6px; }
.rs-soul div b { font-size: 24px; line-height: 1.1; color: var(--soul); }
.rs-soul div span { font-size: 13px; color: var(--ink); }
.rs-soul small { grid-column: 1 / -1; font-size: 12px; line-height: 1.5; color: var(--ink-dim); }
.rs-soul .rs-ad { grid-column: 1 / -1; justify-self: start; margin-top: 2px; }
.rs-soul .rs-dbl { grid-column: 1 / -1; justify-self: start; padding: 1px 6px; font-style: normal; font-size: 12px; color: var(--night); background: var(--soul); }
.rs-news { display: flex; flex-direction: column; gap: 4px; margin: 0; padding: 0; list-style: none; }
.rs-news li { display: flex; align-items: baseline; gap: 8px; min-width: 0; padding: 6px 10px; background: var(--night); border-left: 5px solid var(--brass); }
.rs-news em { flex: none; padding: 0 5px; font-style: normal; font-size: 12px; line-height: 1.6; color: var(--night); background: var(--brass-hi); }
.rs-news b { flex: none; font-size: 14px; }
.rs-news span { min-width: 0; font-size: 12px; line-height: 1.5; color: var(--ink-dim); }
.modal p.rs-tip { margin: 0; padding: 8px 12px; max-width: none; font-size: 13px; line-height: 1.6; color: var(--ink-dim); background: var(--night); border-left: 5px solid var(--panel-hi); }
.rs-foot { display: flex; align-items: center; gap: 8px; margin-top: 12px; }
.rs-foot .go-btn { margin-left: auto; }
:root[data-lay="P"] .rs-mid { grid-template-columns: 1fr; }
:root[data-lay="P"] .rs-stats { grid-template-columns: repeat(4, minmax(0, 1fr)); }
:root[data-lay="P"] .rs-foot { flex-wrap: wrap; }
:root[data-lay="P"] .rs-foot .go-btn { flex: 1 1 100%; margin-left: 0; }
:root[data-short] .modal.rs-m h2 { font-size: 24px; }
:root[data-short] .rs-t { padding: 4px 4px 3px; }
:root[data-short] .rs-t b { font-size: 16px; }
:root[data-short] .rs-mid, :root[data-short] .rs-foot { margin-top: 8px; }

/* ===== 第十三次更新：精英战利品 ===== */
.modal p.lt-sub { margin: 0 0 4px; max-width: none; font-size: 14px; line-height: 1.6; }
.modal p.lt-odds { display: flex; flex-wrap: wrap; align-items: baseline; gap: 2px 8px; margin: 0 0 8px; max-width: none; font-size: 12px; line-height: 1.5; color: var(--ink-dim); }
.lt-odds .lt-hint { margin-left: auto; color: var(--ink-dim); }
.lt-tools .lt-wallet { margin-left: auto; display: inline-flex; align-items: center; gap: 4px; font-size: 14px; }
.lt-tools .lt-wallet span { display: inline-flex; align-items: center; gap: 3px; }
:root[data-lay="P"] .lt-grid { grid-template-columns: 1fr; }
]==]

return true
