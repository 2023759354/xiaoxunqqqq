-- ============================================================================
-- 第十五次更新：圣物栏满了以后的处理 + 仓库放圣物
--  * 圣物栏 5 → 8 格，仓库 6 → 10 格（常量在 items.lua）
--  * 圣物栏满了：精英战利品 / 商店里的圣物照样能拿，拿的时候选「放进仓库」或「换下一件已装备的圣物」
--    （换下的放进仓库；仓库也满了就按出售价折成秘银）。以前按钮直接灰掉，满了的圣物也卖不掉，只能放弃
--  * 仓库里的圣物不生效，修整阶段可以在「商店 → 装备管理」里拖到圣物栏装上 / 互换，或者在商店「持有」里装上
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local CONTENT = require("ui.content")
local S = js.S

-- ---------------------------------------------------------------------------
-- 逻辑（圣物栏下标 r 从 0 起，和 G.relics 一致；仓库下标 k 从 1 起，和 stashOf() 一致）
-- ---------------------------------------------------------------------------
--- 仓库第 k 件圣物装上（圣物栏要有空位）
function relicEquipFromStash(k)
    local st = stashOf()
    local it = st[k]
    if not isRelic(it) or relicBarFull() then return false end
    table.remove(st, k)
    G.relics:push(it)
    recalcRelics()
    return true
end
--- 圣物栏第 r 件和仓库第 k 件圣物互换；返回 ok, 换下来的那件
function relicSwapStash(r, k)
    local st = stashOf()
    local it, old = st[k], G.relics[r]
    if not isRelic(it) or not old then return false end
    G.relics[r] = it
    st[k] = old
    recalcRelics()
    return true, old
end
--- 圣物栏第 r 件收进仓库（仓库满了返回 false）
function relicToStash(r)
    local it = G.relics[r]
    if not it or stashFull() then return false end
    G.relics:splice(r, 1)
    stashPut(it)
    recalcRelics()
    return true
end
--- 圣物栏里调换顺序
function relicReorder(a, b)
    if a == b or not G.relics[a] or not G.relics[b] then return false end
    G.relics[a], G.relics[b] = G.relics[b], G.relics[a]
    return true
end
--- 新拿到、还没进圣物栏的圣物。how = 'stash'：放进仓库；how = 'replace'：换下圣物栏第 r 件
--- 返回去向：'stash'（放进了仓库）/ 'equip'（装上了；第二个值是换下的那件，第三个值是它的去向 'stash' / 'sold'）/ nil（失败）
function placeNewRelic(it, how, r)
    if how == 'stash' then return stashPut(it) and 'stash' or nil end
    if not relicBarFull() then
        G.relics:push(it); recalcRelics()
        return 'equip'
    end
    local old = G.relics[r]
    if not old then return nil end
    G.relics[r] = it
    recalcRelics()
    return 'equip', old, stashOrSell(old)
end

-- ---------------------------------------------------------------------------
-- 界面：圣物栏已满时的选择
-- ---------------------------------------------------------------------------
local function shortDesc(it) return (itemDesc(it):gsub('<br>.*', '')) end

--- it：新圣物；opts.back：「返回」回到哪里（精英战利品可以反悔；商店已经付过钱，没有返回）；opts.done：选完之后
function UI.relicFullPick(it, opts)
    opts = opts or {}
    local Q = QUAL[it.rar]
    local sfull = stashFull()
    local rows = {}
    rows[#rows + 1] = '<button class="pick-unit rf-st" data-rf="stash"' .. (sfull and ' disabled' or '') .. '><img src="' .. itemIcon(it) .. '" alt=""><span>放进仓库 <em>' ..
        S(#stashOf()) .. '/' .. S(STASH_SLOTS) .. '</em></span><small>' .. (sfull and '仓库已满' or '暂不生效，以后再换上') .. '</small></button>'
    G.relics:forEach(function(old, r)
        local q = QUAL[old.rar]
        rows[#rows + 1] = '<button class="pick-unit" data-rf="' .. S(r) .. '"><img src="' .. itemIcon(old) .. '" alt=""><span>换下 <b style="color:' .. q.color .. '">' .. itemName(old) .. '</b></span><small>' ..
            (sfull and ('折 ' .. S(sellPrice(old)) .. ' 秘银 · ') or '') .. shortDesc(old) .. '</small></button>'
    end)
    local body = '<p class="rf-new">新的 <b style="color:' .. Q.color .. '">' .. itemName(it) .. '</b>：' .. itemDesc(it) .. '</p>' ..
        '<p class="dim rf-tip">圣物栏 ' .. S(#G.relics) .. '/' .. S(RELIC_SLOTS) .. ' 已满：放进仓库（暂不生效），或者换下一件正在生效的圣物，' ..
        (sfull and '<b>仓库已满，换下的按出售价折成秘银</b>。' or '换下的放进仓库。') .. '</p>' ..
        '<div class="pick-list rf-list">' .. table.concat(rows) .. '</div>'
    UI.modal('圣物栏已满', body, opts.back and '返回' or nil, function() if opts.back then opts.back() end end)
    UI.els.mTitle.parent:addClass('wide')
    local run = G
    for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-rf]')) do
        b:addEventListener('click', function()
            if b:isDisabled() or G ~= run then return end
            Sound.init()
            local v = b:data('rf')
            local fate, old, oldFate
            if v == 'stash' then fate = placeNewRelic(it, 'stash')
            else fate, old, oldFate = placeNewRelic(it, 'replace', tonumber(v)) end
            if not fate then Sound.play('deny'); return end
            UI.els.overlay:setHidden(true)
            UI.cache:set('itembar', nil); UI.cache:set('info', nil)
            if fate == 'stash' then
                Sound.play('unequip')
                UI.toast(itemName(it) .. ' 放进了仓库（' .. S(#stashOf()) .. '/' .. S(STASH_SLOTS) .. '）')
            else
                Sound.play('equip')
                local tail = ''
                if old then
                    tail = (oldFate == 'sold') and ('，换下的 ' .. itemName(old) .. ' 折成 ' .. S(sellPrice(old)) .. ' 秘银')
                        or ('，换下的 ' .. itemName(old) .. ' 放进了仓库')
                    if oldFate == 'sold' then UI.bumpGems() end
                end
                UI.toast('装上 ' .. itemName(it) .. tail)
            end
            if opts.done then opts.done() end
        end)
    end
end

--- 仓库第 k 件圣物：圣物栏有空位直接装上，满了选一件互换
function UI.relicFromStashPick(k, done)
    local it = stashOf()[k]
    if not isRelic(it) then return end
    if not relicBarFull() then
        if relicEquipFromStash(k) then
            Sound.play('equip'); UI.toast('装上 ' .. itemName(it))
            UI.cache:set('itembar', nil)
        end
        if done then done() end
        return
    end
    local rows = {}
    G.relics:forEach(function(old, r)
        local q = QUAL[old.rar]
        rows[#rows + 1] = '<button class="pick-unit" data-rs="' .. S(r) .. '"><img src="' .. itemIcon(old) .. '" alt=""><span>换下 <b style="color:' .. q.color .. '">' .. itemName(old) .. '</b></span><small>' .. shortDesc(old) .. '</small></button>'
    end)
    UI.modal('换上 ' .. itemName(it), '<p class="rf-new">圣物栏已满，换下哪一件来装 <b style="color:' .. QUAL[it.rar].color .. '">' .. itemName(it) .. '</b>？换下的放回仓库（不花钱）。</p>' ..
        '<div class="pick-list rf-list">' .. table.concat(rows) .. '</div>', '返回', function() if done then done() end end)
    UI.els.mTitle.parent:addClass('wide')
    local run = G
    for _, b in ipairs(UI.els.mBody:querySelectorAll('[data-rs]')) do
        b:addEventListener('click', function()
            if G ~= run then return end
            Sound.init()
            local ok, old = relicSwapStash(tonumber(b:data('rs')), k)
            if not ok then Sound.play('deny'); return end
            Sound.play('equip')
            UI.toast('装上 ' .. itemName(it) .. '，换下的 ' .. itemName(old) .. ' 放回仓库')
            UI.cache:set('itembar', nil)
            UI.els.overlay:setHidden(true)
            if done then done() end
        end)
    end
end

-- 圣物与消耗品说明弹窗：提一句仓库里还有几件圣物
local _showRelics = UI.showRelics
function UI.showRelics(...)
    local r = _showRelics(...)
    local n = 0
    for _, it in ipairs(stashOf()) do if isRelic(it) then n = n + 1 end end
    if n > 0 and UI.els.mBody then
        local p = UI.els.mBody:querySelector('p.dim')
        if p then
            local DOM = require("ui.dom")
            local note = DOM.newElement('p')
            note:setClassName('dim')
            note:setHTML('仓库里还有 <b>' .. S(n) .. '</b> 件圣物（不生效），修整阶段在「商店 → 装备管理」里可以换上。')
            UI.els.mBody:appendChild(note)
        end
    end
    return r
end

CONTENT.css = CONTENT.css .. [==[
/* ===== 第十五次更新：圣物栏已满 ===== */
.pick-unit.rf-st { border-color: var(--brass); }
.pick-unit.rf-st em { font-style: normal; font-size: 12px; color: var(--ink-dim); }
.modal p.rf-new { margin: 0 0 4px; max-width: none; font-size: 14px; line-height: 1.55; }
.modal p.rf-tip { margin: 0 0 8px; max-width: none; font-size: 12px; line-height: 1.5; }
.rf-list { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
.rf-list .pick-unit { padding: 4px 6px; column-gap: 6px; grid-template-columns: 28px minmax(0, 1fr); }
.rf-list .pick-unit img { width: 28px; height: 28px; }
.rf-list .pick-unit > span { min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.rf-list .pick-unit small { min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
:root[data-lay="P"] .rf-list { grid-template-columns: repeat(2, minmax(0, 1fr)); }
@media (max-width: 520px) { .rf-list { grid-template-columns: 1fr; } }
.pick-unit:disabled { cursor: default; opacity: 0.45; }
.inv-item .chip.go { color: var(--night); }
/* 竖排的老虎机柜里道具栏不能折行：窄屏（手机竖屏）圣物 8 格时缩小图标、去掉文字标签，一行放下 */
@media (max-width: 560px) {
  :root[data-lay="P"] .cabinet > .itembar .lbl { display: none; }
  :root[data-lay="P"] .cabinet > .itembar { gap: 2px; }
  :root[data-lay="P"] .cabinet > .itembar .rel img { width: 16px; height: 16px; }
  :root[data-lay="P"] .cabinet > .itembar .rel0 { width: 18px; height: 18px; }
  :root[data-lay="P"] .cabinet > .itembar .cons img { width: 18px; height: 18px; }
  :root[data-lay="P"] .cabinet > .itembar .slot0 { width: 20px; height: 20px; }
}
]==]

return true
