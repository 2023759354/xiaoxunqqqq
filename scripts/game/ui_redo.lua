-- ============================================================================
-- 第十次更新：选关、组建军团、商店三个界面重新设计
--  * 选关：「返回主页」移到标题栏右上角，离难度卡最远；横屏左边一列章节、右边 4 个难度，
--    竖屏章节 4 列、难度四行；每个难度写清波数 / 命数 / 通关状态
--  * 组建军团：13 个兵种只显示头像和名字，点一下选中 / 取消，详情区显示属性和技能；
--    已选的 3 个、「随机」「出征」固定在底部
--  * 商店：右上角关闭；货架横屏一排放下；刷新和金币兑换合成一条工具栏；持有物品三栏
-- 本工程适配：10 章、13 兵种、秘银商店（第九次更新）、装备暂无可装备单位时的提示。
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local CONTENT = require("ui.content")
local A, T, S = js.A, js.T, js.S
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local function _id(id) return PAGE.doc.getElementById(id) end
local function focusEl(el) if el then PAGE:focus(el, 'script') end end
local function str(b) return b and 'true' or 'false' end

-- ---------------------------------------------------------------------------
-- 弹窗：每次打开都清掉本模块加的版式类；右上角返回按钮
-- ---------------------------------------------------------------------------
local REDO_CLS = { 'rd', 'rd-pk', 'rd-sq', 'rd-sh' }
local _modal = UI.modal
function UI.modal(title, body, btn, onClick)
    local m = UI.els.mTitle.parent
    m:removeClass(table.unpack(REDO_CLS))
    UI._rdBackBound = nil -- 右上角返回按钮每个弹窗只绑一次
    -- 上一个弹窗的「返回」按钮挂在弹窗本体上，不会随 mBody 重绘消失，这里手动清掉
    local old = _id('mBack')
    if old then old:remove() end
    UI.els.mBack = nil
    UI._rdBackLabel = nil
    return _modal(title, body, btn, onClick)
end
-- 右上角的「返回」按钮：挂在弹窗本体（mTitle.parent）上，不放进 mBody。
-- 弹窗内容超长时滚动的是 mBody，按钮如果留在里面会跟着滚出视野。
local function backChip(label)
    UI._rdBackLabel = label or ''
    return ''
end
local function bindBack(fn)
    local m = UI.els.mTitle.parent
    local b = _id('mBack')
    if not b then
        b = PAGE.doc.createElement('button')
        b:setAttribute('class', 'chip m-back')
        b:setAttribute('id', 'mBack')
        m:appendChild(b)
    end
    b:setText(UI._rdBackLabel or '返回')
    UI.els.mBack = b
    if not UI._rdBackBound then
        UI._rdBackBound = true
        b:addEventListener('click', function() Sound.init(); UI._rdBackBound = nil; fn() end)
    end
end

-- ---------------------------------------------------------------------------
-- 选章节与难度
-- ---------------------------------------------------------------------------
-- 本工程 10 章：索引 0..9 → 显示 1..10（第八～十章本身带 num 字段）
local CH_NUM = { [0] = '1', '2', '3', '4', '5', '6', '7', '8', '9', '10' }
local function chNum(K, i) return K.num or CH_NUM[i] or S(i + 1) end

function UI.pickerHTML()
    local c = UI.pickCh
    local C, Sv = CHAPTERS[c], SAVE[c]
    local chs = '<div class="pk-chs">' .. CHAPTERS:map(function(K, i)
        local open = chOpen(i)
        local pips = K.diffs:map(function(Dd, d) return '<i class="' .. (((SAVE[i].cleared & (1 << d)) ~= 0) and 'on' or '') .. '" style="--dc:' .. Dd.color .. '"></i>' end):join('')
        return '<button class="pk-ch' .. (i == c and ' on' or '') .. '" data-c="' .. S(i) .. '" aria-pressed="' .. str(i == c) .. '" style="--cc:' .. K.color .. '"' .. (open and '' or ' disabled') .. '>' ..
            '<b>' .. chNum(K, i) .. '</b><span class="nm">' .. K.title .. '</span>' ..
            (open and ('<span class="pips">' .. pips .. '</span>') or '<small>未解锁</small>') .. '</button>'
    end):join('') .. '</div>'
    local head = '<div class="pk-head" style="--cc:' .. C.color .. '"><b>' .. C.name .. '「' .. C.title .. '」</b><span>' .. C.desc .. '</span></div>'
    local diffs = '<div class="pk-diffs">' .. C.diffs:map(function(Dd, i)
        local locked = i > Sv.unlock
        local status, st
        if locked then status, st = '通关「' .. C.diffs[i - 1].name .. '」后解锁', 'lock'
        elseif (Sv.cleared & (1 << i)) ~= 0 then status, st = '已通关 ✓', 'done'
        elseif T(Sv.best[i]) then status, st = '最佳 ' .. S(Sv.best[i]) .. '/' .. S(Dd.waves) .. ' 波', 'tried'
        else status, st = '未挑战', 'new' end
        local short = Dd.desc:gsub('^共 %d+ 波。', '')
        return '<button class="pk-diff ' .. st .. '" data-d="' .. S(i) .. '" style="--dc:' .. Dd.color .. '"' .. (locked and ' disabled' or '') .. '>' ..
            '<span class="dh"><b>' .. Dd.name .. '</b><em>' .. S(Dd.waves) .. ' 波 · ' .. S(Dd.lives) .. ' 命</em><small>' .. status .. '</small></span>' ..
            '<span class="dd">' .. short .. '</span></button>'
    end):join('') .. '</div>'
    return '<div class="pk">' .. chs .. '<div class="pk-main">' .. head .. diffs .. '</div></div>'
end

function UI.showStart(intro, title)
    if UI.pickCh == nil or not chOpen(UI.pickCh) then UI.pickCh = G and G.ch or 0 end
    UI.modal(title or '拉杆军团', backChip('返回主页') .. (intro or '') ..
        '<h3 class="pickh">选择章节与难度</h3><div id="pick">' .. UI.pickerHTML() .. '</div>', nil)
    local m = UI.els.mTitle.parent
    m:addClass('wide', 'rd', 'rd-pk')
    bindBack(function() UI.showHome() end)
    local pick = _id('pick')
    local bind
    bind = function()
        for _, b in ipairs(pick:querySelectorAll('.pk-ch')) do
            b:addEventListener('click', function()
                if b:isDisabled() then return end
                Sound.init(); UI.pickCh = tonumber(b:data('c')); pick:setHTML(UI.pickerHTML()); bind()
                local f = pick:querySelector('.pk-ch.on'); if f then focusEl(f) end
            end)
        end
        for _, btn in ipairs(pick:querySelectorAll('.pk-diff')) do
            btn:addEventListener('click', function()
                if btn:isDisabled() then return end
                Sound.init(); UI.showSquad(UI.pickCh, tonumber(btn:data('d')))
            end)
        end
    end
    bind()
    -- 焦点落在当前章节的第一个可选难度上（键盘回车直接进入），而不是返回按钮
    setTimeout(function() focusEl(pick:querySelector('.pk-diff:not(:disabled)')) end, 40)
end

-- ---------------------------------------------------------------------------
-- 组建军团
-- ---------------------------------------------------------------------------
local function classIcon(c) local C = CLASSES[c]; return iconURL(C.sprite, TIER_PAL[c][1], c .. '1') end

function UI.showSquad(ch, diff)
    local E = UI.els
    local C0 = CHAPTERS[ch]
    local D0 = C0.diffs[diff]
    local sel = loadSquad():slice()
    sel = sel:filter(function(c) return classOpen(c) end)
    local lim = {}
    local focus = sel[#sel - 1] or CLASS_KEYS[0]
    local hell = diff == #C0.diffs - 1

    local function tile(c)
        local C, on, open = CLASSES[c], sel:includes(c), classOpen(c)
        return '<button class="sq-t' .. (on and ' on' or '') .. (c == focus and ' cur' or '') .. (open and '' or ' locked') .. '" data-c="' .. c .. '" aria-pressed="' .. str(on) .. '" style="--qc:' .. CLASS_COLOR[c] .. '">' ..
            '<img src="' .. classIcon(c) .. '" alt=""><b>' .. C.name .. '</b><small>' .. (open and ((C.proj and '远程' or '近战')) or '未解锁') .. '</small><i class="tick">✓</i></button>'
    end
    local function detail(c)
        local C, sk, open = CLASSES[c], SKILLS[CLASS_SKILL[c]], classOpen(c)
        return '<div class="sq-d" style="--qc:' .. CLASS_COLOR[c] .. '"><img src="' .. classIcon(c) .. '" alt="">' ..
            '<div class="sq-dt"><p class="nm"><b>' .. C.name .. '</b><span>' .. KIND_NAME[C.kind] .. ' · ' .. (C.proj and '远程' or '近战') .. ' · ' .. C.note .. '</span></p>' ..
            '<p class="st">生命 <b>' .. S(C.hp) .. '</b>　攻击 <b>' .. S(C.atk) .. '</b>　射程 <b>' .. S(C.range) .. '</b></p>' ..
            '<p class="sk">' .. (open and '' or ('<span class="warn">' .. classLockText(c) .. '。</span>')) .. '技能「' .. sk.name .. '」：' .. sk.desc .. '</p></div></div>'
    end
    local function foot()
        local slots = {}
        for i = 0, SQUAD_N - 1 do
            local c = sel[i]
            slots[#slots + 1] = c and ('<span class="sq-s" style="--qc:' .. CLASS_COLOR[c] .. '"><img src="' .. classIcon(c) .. '" alt=""><b>' .. CLASSES[c].name .. '</b></span>')
                or '<span class="sq-s empty"><i></i><b>待选</b></span>'
        end
        local ok, why = limitsOK(sel, lim, ch)
        local msg = (#sel < SQUAD_N) and ('还差 ' .. S(SQUAD_N - #sel) .. ' 个') or ((not ok) and why or '')
        return '<div class="sq-slots">' .. table.concat(slots) .. '</div>' ..
            '<span class="sq-msg">' .. msg .. '</span>' ..
            '<button class="chip" id="sqRand">随机</button>' ..
            '<button class="go-btn" id="sqGo"' .. ((#sel == SQUAD_N and ok) and '' or ' disabled') .. '>出征</button>'
    end

    local limHTML = ''
    if hell then
        limHTML = '<div class="sq-lim"><span>炼狱词缀（可选，军魂 ×' .. S(AFFIX_SOUL) .. '）</span>' ..
            '<button class="chip" id="limBan" aria-pressed="false">' .. AFFIX_LIMITS.ban.desc(ch) .. '</button>' ..
            '<button class="chip" id="limOne" aria-pressed="false">' .. AFFIX_LIMITS.oneRanged.desc(ch) .. '</button></div>'
    end
    UI.modal('组建军团', backChip('‹ 难度') ..
        '<p class="sq-sub" style="--cc:' .. C0.color .. '"><b>' .. C0.name .. '「' .. C0.title .. '」' .. D0.name .. '</b>选 ' .. S(SQUAD_N) .. ' 个兵种：老虎机只出这 ' .. S(SQUAD_N) .. ' 种图标，★ 可替代任何一种。</p>' ..
        rulesHTML(ch) .. limHTML ..
        '<div class="sq-body"><div class="sq-grid2" id="sqGrid">' .. CLASS_KEYS:map(tile):join('') .. '</div>' ..
        '<div id="sqDetail">' .. detail(focus) .. '</div></div>' ..
        '<div class="sq-foot" id="sqFoot">' .. foot() .. '</div>', nil)
    E.mTitle.parent:addClass('wide', 'rd', 'rd-sq')
    bindBack(function() UI.showStart('', '开始游戏') end)

    local bindFoot
    local function refresh()
        for _, b in ipairs(_id('sqGrid'):querySelectorAll('.sq-t')) do
            local c = b:data('c')
            local on = sel:includes(c)
            b:toggleClass('on', on); b:toggleClass('cur', c == focus); b:setAttribute('aria-pressed', str(on))
        end
        _id('sqDetail'):setHTML(detail(focus))
        _id('sqFoot'):setHTML(foot()); bindFoot()
        for _, pair in ipairs({ { 'limBan', 'ban' }, { 'limOne', 'oneRanged' } }) do
            local b = _id(pair[1]); if b then b:toggleClass('on', not not lim[pair[2]]); b:setAttribute('aria-pressed', str(not not lim[pair[2]])) end
        end
    end
    bindFoot = function()
        _id('sqRand'):addEventListener('click', function()
            Sound.init()
            for _ = 1, 30 do
                sel = CLASS_KEYS:filter(function(c) return classOpen(c) end):sort(function() return js.random() - 0.5 end):slice(0, SQUAD_N)
                if limitsOK(sel, lim, ch) then break end
            end
            focus = sel[#sel - 1] or focus
            refresh()
        end)
        _id('sqGo'):addEventListener('click', function()
            if _id('sqGo'):isDisabled() then return end
            Sound.init(); E.overlay:setHidden(true)
            sel = validSquad(sel); saveSquad(sel); PENDING_LIMITS = (lim.ban or lim.oneRanged) and lim or nil; restart(ch, diff, sel)
        end)
    end
    for _, b in ipairs(_id('sqGrid'):querySelectorAll('.sq-t')) do
        b:addEventListener('click', function()
            Sound.init()
            local c = b:data('c')
            focus = c
            if classOpen(c) then
                if sel:includes(c) then sel = sel:filter(function(x) return x ~= c end)
                else sel:push(c); if #sel > SQUAD_N then sel:shift() end end
            end
            refresh()
        end)
    end
    for _, pair in ipairs({ { 'limBan', 'ban' }, { 'limOne', 'oneRanged' } }) do
        local b = _id(pair[1])
        if b then b:addEventListener('click', function() Sound.init(); lim[pair[2]] = not lim[pair[2]]; refresh() end) end
    end
    refresh()
    setTimeout(function() focusEl(_id('sqGo')) end, 40)
end

-- 商店卡片的最小可读宽度：低于这个值时名字和说明会挤成一段段两三个字。
-- 8 个货位（强化 + 藏宝图）在窄屏上就按这个宽度折成两行。
SHOP_CARD_MIN = 132

-- ---------------------------------------------------------------------------
-- 商店
-- ---------------------------------------------------------------------------
local function gem() return '<img class="gem-ic" src="' .. gemIcon() .. '" alt="秘银">' end
local function coin() return '<img class="coin-ic" src="' .. iconURL('sym_coin') .. '" alt="金币">' end
local function rarTag(it)
    local Q, I = QUAL[it.rar], ITEMS[it.id]
    -- 卡面很窄：只用「品质 · 类型」，分组（拉杆 / 经济…）留给道具详情，不再占一行
    return '<span style="color:' .. Q.color .. '">' .. Q.name .. '</span> · ' .. KIND_NAME_ITEM[I.kind]
end
local function closeShop() UI.els.overlay:setHidden(true); UI.cache:set('itembar', nil) end

function UI.shopTabsHTML(active)
    local function tab(id, txt) return '<button class="chip' .. (active == id and ' on' or '') .. '" data-shtab="' .. id .. '" aria-pressed="' .. (active == id and 'true' or 'false') .. '">' .. txt .. '</button>' end
    return backChip(UI.backLabel()) .. '<div class="sh-tabs">' .. tab('shop', '道具商店') .. tab('equip', '装备管理') ..
        '<span class="sh-wallet"><span>' .. gem() .. '<b class="gemv">' .. S(gems()) .. '</b></span><span>' .. coin() .. '<b class="goldv">' .. S(G.gold) .. '</b></span></span></div>'
end
local _bindTabs = UI.bindShopTabs
function UI.bindShopTabs()
    _bindTabs()
    UI.els.mTitle.parent:addClass('rd', 'rd-sh')
    UI.els.mBtn:setHidden(true)
    bindBack(closeShop)
end

function UI.shopCard(s, i)
    local it = s.item
    local Q = QUAL[it.rar]
    local cls = 'sh-card' .. (s.special and ' special' or '') .. (s.locked and ' locked' or '') .. (s.sold and ' sold' or '')
    local inBattle = G.phase ~= 'prep'
    local full = not s.sold and slotFull(it)
    local poor = not s.sold and gems() < s.price
    -- 本工程：装备类道具如果没有任何可装备的单位，也不能买
    local noUnit = not s.sold and ITEMS[it.id].kind == 'equip' and #equipCandidates(it) == 0
    local flags = ''
    if s.special then flags = flags .. '<em class="fl sp">特价</em>' end
    if s.kept then flags = flags .. '<em class="fl kp">保留</em>' end
    local btns
    if s.sold then btns = '<button class="chip buy" disabled>已售出</button>'
    else
        local label = full and '槽位已满' or (noUnit and '无可用单位' or ('买 ' .. gem() .. '<b>' .. S(s.price) .. '</b>'))
        btns = '<button class="chip go buy" data-buy="' .. S(i) .. '"' .. ((poor or full or noUnit or inBattle) and ' disabled' or '') .. '>' .. label .. '</button>' ..
            '<button class="chip lk' .. (s.locked and ' on' or '') .. '" data-lock="' .. S(i) .. '" aria-pressed="' .. str(s.locked) .. '" aria-label="' .. (s.locked and '取消锁定' or '锁定到下一波') .. '"' ..
            (((not s.locked and G.shop.lockUsed) or inBattle) and ' disabled' or '') .. '>' .. (s.locked and '已锁' or '锁') .. '</button>'
    end
    return '<div class="' .. cls .. '" style="--qc:' .. Q.color .. '">' ..
        '<div class="hd"><img src="' .. itemIcon(it) .. '" alt=""><span class="tt"><b>' .. itemName(it) .. '</b><small>' .. rarTag(it) .. '</small></span></div>' ..
        flags .. '<p>' .. itemDesc(it) .. '</p><div class="btns">' .. btns .. '</div></div>'
end

function UI.invHTML(selling)
    local function group(list, kind, cap)
        local title = (kind == 'stash') and '仓库' or KIND_NAME_ITEM[kind]
        local sfull = stashFull()
        local items = list:map(function(it, i)
            local Q = QUAL[it.rar]
            -- 第十五次更新：圣物可以收进仓库；仓库里的圣物可以装上（圣物栏满了就选一件互换）
            local extra = ''
            if selling and kind == 'relic' then
                extra = '<button class="chip" data-rst="' .. S(i) .. '"' .. (sfull and ' disabled' or '') .. '>收起</button>'
            elseif selling and kind == 'stash' and isRelic(it) then
                extra = '<button class="chip go" data-rup="' .. S(i + 1) .. '">' .. (relicBarFull() and '换上' or '装上') .. '</button>'
            end
            local tag = (kind == 'stash' and isRelic(it)) and '<small class="iv-tag">圣物</small>' or ''
            return '<span class="inv-item" style="--qc:' .. Q.color .. '"><img src="' .. itemIcon(it) .. '" alt=""><span class="iv">' .. itemName(it) .. tag .. '</span>' .. extra ..
                (selling and ('<button class="chip" data-sell="' .. kind .. ':' .. S(i) .. '">卖 ' .. gem() .. S(sellPrice(it)) .. '</button>') or '') .. '</span>'
        end):join('')
        if #list == 0 then items = '<span class="inv-empty">空</span>' end
        return '<div class="inv-g"><p class="ig">' .. title .. ' <span>' .. S(#list) .. '/' .. S(cap) .. '</span></p><div class="inv">' .. items .. '</div></div>'
    end
    return '<div class="inv3">' .. group(G.relics, 'relic', RELIC_SLOTS) .. group(G.cons, 'cons', CONS_SLOTS) .. group(A(table.unpack(stashOf())), 'stash', STASH_SLOTS) .. '</div>'
end

function UI.shopBody()
    local Sh = G.shop
    local rc = refreshCost()
    local inBattle = G.phase ~= 'prep'
    local R = GEM_RATE
    local packs = floor(G.gold / R.gold)
    local function ex(n, label)
        return '<button class="chip" data-ex="' .. n .. '"' .. ((inBattle or packs < (tonumber(n) or 1)) and ' disabled' or '') .. '>' .. label .. '</button>'
    end
    local allN = packs * R.gem
    local nSlots = max(1, #Sh.slots)
    -- 列数：保证每张卡至少 SHOP_CARD_MIN 宽；货位多时折行，并把各行排匀（8 个位 4+4，不是 7+1）。
    -- 基准用「弹窗宽度」：mBody 的宽度取决于上一次渲染的内容，第一次打开时还没定下来，
    -- 用它会让首次打开算出错误的列数。弹窗宽 = min(800px, 视口宽)，内容区再减边框 8 / 内边距 44。
    local modal = UI.els.mTitle and UI.els.mTitle.parent.box
    local avail = (modal and modal.w or 800) - 52
    local fit = max(1, floor((avail + 6) / (SHOP_CARD_MIN + 6)))
    -- 按行数均分，避免出现「5 + 1」这种末行只剩一张的排法：6 个位 → 3+3，8 个位 → 4+4。
    -- 上限 5 列：再宽的话卡面会拉得过长（6 个位均分成 3+3 时每张 250px 太胖）
    local rows = ceil(nSlots / max(1, min(fit, 5)))
    local cols = ceil(nSlots / rows)
    return UI.shopTabsHTML('shop') ..
        (inBattle and '<p class="warn sh-warn">战斗中只能查看，这一波打完再买卖。</p>' or '') ..
        '<div class="sh-grid" style="--n:' .. S(cols) .. '">' .. Sh.slots:map(function(s, i) return UI.shopCard(s, i) end):join('') .. '</div>' ..
        '<div class="sh-tools">' ..
        '<div class="sh-rf"><button class="chip" id="shRefresh"' .. ((gems() < rc or inBattle) and ' disabled' or '') .. '>刷新货架 ' .. ((rc == 0) and '<b>免费</b>' or (gem() .. '<b>' .. S(rc) .. '</b>')) .. '</button>' ..
        ((Sh.free > 0) and ('<small>还有 ' .. S(Sh.free) .. ' 次免费</small>') or '<small>每次 +1，每波重置</small>') .. '</div>' ..
        '<div class="sh-ex"><span class="exl">' .. coin() .. '→' .. gem() .. ' ' .. S(R.gold) .. ':' .. S(R.gem) .. '</span>' ..
        ex('1', S(R.gold) .. '→' .. S(R.gem)) .. ex('5', S(R.gold * 5) .. '→' .. S(R.gem * 5)) ..
        '<button class="chip" data-ex="all"' .. ((inBattle or packs < 1) and ' disabled' or '') .. '>全部' .. ((packs >= 1) and ('→' .. S(allN)) or '') .. '</button></div>' ..
        '</div>' ..
        '<p class="sh-note">每波战后发秘银、换一批货。锁定的一件留到下一波（每波 1 件）。' .. ((Sh.n < 5) and '上一波失守，少 1 个特价格。' or '') .. '金币还要拉杆，利息按剩下的算。</p>' ..
        '<h3 class="sh-h">持有</h3>' .. UI.invHTML(not inBattle)
end

local function openShopModal()
    if not G.shop then openShop(nil) end
    UI.modal('商店', '<div id="shop">' .. UI.shopBody() .. '</div>', nil)
    UI.els.mTitle.parent:addClass('wide')
    UI.shopBind()
end
function UI.showShop()
    if not G.shop then openShop(nil) end
    G.shop.fresh = false
    openShopModal()
    Sound.play('shop')
end
function UI.showShopAgain() openShopModal() end

-- 装备管理页签：同样的标题栏（右上角关闭）
local _eqOv = UI.showEquipOverview
function UI.showEquipOverview()
    _eqOv()
    UI.els.mBtn:setHidden(true)
    UI.els.mTitle.parent:addClass('rd', 'rd-sh')
end

-- ---------------------------------------------------------------------------
-- 样式
-- ---------------------------------------------------------------------------
CONTENT.css = CONTENT.css .. [==[
/* ===== 第十次更新：选关 / 组建军团 / 商店 ===== */

/* 自适应窄屏：弹窗所在的 overlay 是 grid 但没定义轨道，单条 auto 轨道会被内容的
   max-content 撑大（货架一排 5 张卡时尤其明显），于是弹窗里 min(800px, 100%) 的
   百分比按被撑大的轨道解析，弹窗比视口还宽，右边一列被裁掉。
   固定成 minmax(0, 1fr) 后轨道恒等于可用宽度，弹窗才能正确收缩。 */
.overlay { grid-template-columns: minmax(0, 1fr); }

/* 第十一次更新：内容超长时滚动的是 mBody，而不是整个弹窗。
   以前 .modal 自己 overflow:auto，absolute 定位的「返回」按钮会跟着内容一起滚走 ——
   滚到下面时右上角就空了，用户以为「点了没反应」。现在按钮挂在弹窗本体上，永远不动。 */
.modal.rd { position: relative; max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
@media (max-width: 640px) { .modal.rd { max-height: calc(100vh - 16px); } }
:root[data-short] .modal.rd { max-height: calc(100vh - 12px); }
.modal.rd #mBody { flex: 1 1 auto; min-height: 0; overflow-y: auto; overflow-x: hidden; }
.modal.rd #mBtn { flex: none; }
.modal.rd h2 { padding-right: 104px; flex: none; }
.modal .m-back { position: absolute; top: 14px; right: 14px; z-index: 3; padding: 5px 12px; font-size: 13px; color: var(--ink-dim); background: var(--night); border: 2px solid var(--panel-hi); }
.modal .m-back:active { transform: translate(1px, 1px); }
:root[data-short] .modal .m-back { top: 8px; right: 10px; padding: 3px 10px; }
@media (max-width: 640px) { .modal .m-back { top: 10px; right: 10px; } }

/* 选关 */
.rd-pk h3.pickh { margin: 2px 0 8px; }
.pk { display: grid; grid-template-columns: 1fr; gap: 8px; }
.pk-chs { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 5px; }
.pk-ch { display: flex; flex-direction: column; align-items: center; gap: 1px; min-width: 0; padding: 5px 2px 4px; cursor: pointer; font: inherit; color: var(--ink); background: var(--night);
  border: 2px solid var(--panel-hi); border-top: 4px solid var(--cc); }
.pk-ch b { font-size: 16px; line-height: 1.15; color: var(--cc); }
.pk-ch .nm { font-size: 12px; line-height: 1.3; white-space: nowrap; }
.pk-ch small { font-size: 12px; color: var(--ink-dim); }
.pk-ch .pips { display: inline-flex; gap: 2px; }
.pk-ch .pips i { width: 7px; height: 7px; border: 1px solid var(--dc); }
.pk-ch .pips i.on { background: var(--dc); }
.pk-ch.on { background: #2f2450; border-color: var(--brass); border-top-color: var(--cc); }
.pk-ch:disabled { cursor: default; opacity: 0.4; filter: grayscale(0.8); }
.pk-ch:focus-visible, .pk-diff:focus-visible, .sq-t:focus-visible { outline: 3px solid var(--ink); outline-offset: 2px; }
.pk-main { display: flex; flex-direction: column; gap: 8px; min-width: 0; }
.pk-head { display: flex; flex-direction: column; gap: 1px; padding: 6px 10px; background: var(--night); border-left: 5px solid var(--cc); }
.pk-head b { font-size: 15px; color: var(--cc); letter-spacing: 0.04em; }
.pk-head span { font-size: 12px; line-height: 1.5; color: var(--ink-dim); }
.pk-diffs { display: grid; grid-template-columns: 1fr; gap: 6px; }
.pk-diff { display: flex; flex-direction: column; gap: 2px; min-width: 0; padding: 8px 10px; cursor: pointer; font: inherit; text-align: left; color: var(--ink); background: var(--night);
  border: 2px solid var(--panel-hi); border-left: 8px solid var(--dc); box-shadow: 2px 2px 0 rgba(0, 0, 0, 0.5); }
.pk-diff .dh { display: flex; align-items: baseline; gap: 8px; }
.pk-diff b { font-size: 17px; letter-spacing: 0.06em; color: var(--dc); }
.pk-diff em { font-style: normal; font-size: 12px; color: var(--ink-dim); white-space: nowrap; }
.pk-diff small { margin-left: auto; font-size: 12px; white-space: nowrap; color: var(--ink-dim); }
.pk-diff.done small { color: var(--moss); }
.pk-diff.tried small { color: var(--brass-hi); }
.pk-diff .dd { font-size: 12px; line-height: 1.5; color: var(--ink-dim); }
.pk-diff:hover:not(:disabled) { border-color: var(--brass); border-left-color: var(--dc); }
.pk-diff:active:not(:disabled) { transform: translate(2px, 2px); box-shadow: none; }
.pk-diff:disabled { cursor: default; opacity: 0.45; filter: grayscale(0.8); }
/* 横屏：左边一列章节，右边难度 2×2 */
:root:not([data-lay="P"]) .pk { grid-template-columns: 168px minmax(0, 1fr); align-items: start; }
:root:not([data-lay="P"]) .pk-chs { grid-template-columns: 1fr; gap: 3px; }
:root:not([data-lay="P"]) .pk-ch { flex-direction: row; gap: 6px; padding: 3px 8px; border-top-width: 2px; border-left: 4px solid var(--cc); }
:root:not([data-lay="P"]) .pk-ch.on { border-top-color: var(--brass); border-left-color: var(--cc); }
:root:not([data-lay="P"]) .pk-ch b { width: 20px; flex: none; text-align: right; font-size: 14px; }
:root:not([data-lay="P"]) .pk-ch .nm { flex: 1 1 0; text-align: left; }
:root:not([data-lay="P"]) .pk-diffs { grid-template-columns: 1fr 1fr; }
:root:not([data-lay="P"]) .pk-diff { padding: 7px 10px; }
:root[data-short] .rd-pk h3.pickh { display: none; }
:root[data-short] .pk-diff .dd { display: block; }

/* 组建军团 */
.rd-sq .sq-sub { margin: 0 0 8px; font-size: 13px; line-height: 1.55; color: var(--ink-dim); max-width: none; }
.rd-sq .sq-sub b { font-size: 14px; color: var(--cc); margin-right: 10px; }
.sq-body { display: grid; grid-template-columns: 1fr; gap: 8px; }
:root:not([data-lay="P"]) .sq-body { grid-template-columns: minmax(0, 1fr) 250px; align-items: stretch; }
:root:not([data-lay="P"]) #sqDetail { margin-top: 0; }
:root:not([data-lay="P"]) .sq-d { height: 100%; grid-template-columns: 1fr; gap: 4px; }
:root:not([data-lay="P"]) .sq-d img { display: none; }
:root:not([data-lay="P"]) .sq-t { padding: 3px 1px 2px; }
:root:not([data-lay="P"]) .sq-t img { width: 28px; height: 28px; }
:root:not([data-lay="P"]) .sq-t b { font-size: 12px; }
.rd-sq .rules { margin-bottom: 8px; }
.sq-lim { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin: 0 0 8px; font-size: 12px; color: var(--ink-dim); }
.sq-lim span { margin-right: auto; }
.sq-grid2 { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 5px; }
.sq-t { position: relative; display: flex; flex-direction: column; align-items: center; gap: 0; min-width: 0; padding: 5px 2px 4px; cursor: pointer; font: inherit; color: var(--ink);
  background: var(--night); border: 2px solid var(--panel-hi); border-bottom: 4px solid var(--panel-hi); }
.sq-t img { width: 32px; height: 32px; image-rendering: pixelated; }
.sq-t b { font-size: 13px; line-height: 1.3; white-space: nowrap; color: var(--qc); }
.sq-t small { font-size: 12px; line-height: 1.2; color: var(--ink-dim); }
.sq-t .tick { position: absolute; right: 2px; top: 2px; width: 15px; height: 15px; display: none; place-items: center; font-style: normal; font-size: 11px; line-height: 1; color: var(--night); background: var(--qc); }
.sq-t.on { background: #2f2450; border-color: var(--qc); border-bottom-color: var(--qc); }
.sq-t.on .tick { display: grid; }
.sq-t.cur { box-shadow: 0 0 0 2px var(--brass-hi); }
.sq-t.locked { opacity: 0.45; }
.sq-t.locked img { filter: grayscale(1); }
.sq-t:active { transform: translate(1px, 1px); }
#sqDetail { margin-top: 0; }
.sq-d { display: grid; grid-template-columns: 40px minmax(0, 1fr); gap: 10px; align-items: start; padding: 8px 10px; background: var(--night); border-left: 5px solid var(--qc); min-height: 74px; }
.sq-d img { width: 40px; height: 40px; image-rendering: pixelated; }
.modal .sq-d p { margin: 0; max-width: none; font-size: 12px; line-height: 1.55; }
.modal .sq-d p.nm b { font-size: 15px; color: var(--qc); margin-right: 8px; }
.modal .sq-d p.nm span, .modal .sq-d p.st { color: var(--ink-dim); }
.modal .sq-d p.st b { color: var(--ink); }
.modal .sq-d p.sk { color: var(--ink); margin-top: 2px; }
.sq-foot { position: sticky; bottom: -20px; z-index: 2; display: flex; align-items: center; gap: 8px; margin: 8px -22px -20px; padding: 8px 22px 10px; background: var(--panel); border-top: 3px solid var(--night); }
.sq-slots { display: flex; gap: 4px; flex: none; }
.sq-s { display: flex; align-items: center; gap: 3px; padding: 2px 6px 2px 2px; background: var(--night); border-left: 3px solid var(--qc); }
.sq-s img { width: 24px; height: 24px; image-rendering: pixelated; }
.sq-s b { font-size: 12px; white-space: nowrap; color: var(--qc); }
.sq-s.empty { border-left-color: #4a3a66; }
.sq-s.empty i { width: 24px; height: 24px; border: 2px dashed #6a5a8e; }
.sq-s.empty b { color: var(--ink-dim); }
.sq-msg { flex: 1 1 0; min-width: 0; font-size: 12px; color: #ff9b8c; }
.go-btn { flex: none; padding: 8px 26px; cursor: pointer; font: inherit; font-size: 16px; font-weight: 900; letter-spacing: 0.12em; color: var(--night); background: var(--brass); border: 3px solid var(--night);
  box-shadow: inset 3px 3px 0 var(--brass-hi), inset -3px -3px 0 var(--brass-dk), 2px 2px 0 var(--night); }
.go-btn:active:not(:disabled) { transform: translate(2px, 2px); }
.go-btn:disabled { cursor: default; opacity: 0.5; filter: grayscale(0.8); }
.go-btn:focus-visible { outline: 3px solid var(--ink); outline-offset: 2px; }
:root[data-short] .sq-foot { bottom: -10px; margin: 6px -14px -10px; padding: 6px 14px 8px; }
:root[data-short] .rd-sq .rules p { display: inline; }
:root[data-short] .rd-sq .rules p + p::before { content: '　'; }
:root[data-lay="P"] .sq-grid2 { grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 4px; }
:root[data-lay="P"] .sq-t img { width: 28px; height: 28px; }
:root[data-lay="P"] .sq-t b { font-size: 12px; }
:root[data-lay="P"] .sq-foot { flex-wrap: wrap; }
:root[data-lay="P"] .sq-slots { flex: 1 1 100%; }
:root[data-lay="P"] .sq-s { flex: 1 1 0; min-width: 0; }
:root[data-lay="P"] .go-btn { padding: 8px 20px; }
@media (max-width: 640px) { .sq-foot { bottom: -12px; margin: 8px -14px -12px; padding: 8px 14px 10px; } }

/* 商店 */
.rd-sh .sh-tabs { padding-right: 0; margin-bottom: 8px; }
.rd-sh h2 { margin-bottom: 6px; }
.sh-warn { margin-bottom: 6px; }
/* 货架：列数由 shopBody 按「可用宽度 ÷ 卡片最小宽度」算好写进 --n（货位多时折行）。
   不能只写 repeat(var(--n)) 让它硬塞——8 个货位时每张卡只剩 87px，名字和说明全被挤断。 */
.sh-grid { display: grid; grid-template-columns: repeat(var(--n, 5), minmax(0, 1fr)); gap: 6px; }
.sh-card { position: relative; display: flex; flex-direction: column; gap: 3px; min-width: 0; max-width: 210px; padding: 6px; background: var(--night); border: 2px solid var(--panel-hi); border-top: 4px solid var(--qc); }
.sh-card .hd { display: flex; align-items: center; gap: 6px; min-width: 0; }
.sh-card .hd img { flex: none; width: 30px; height: 30px; image-rendering: pixelated; }
.sh-card .tt { display: flex; flex-direction: column; min-width: 0; }
.sh-card .tt b { font-size: 14px; line-height: 1.25; color: var(--qc); overflow-wrap: anywhere; }
.sh-card .tt small { font-size: 12px; line-height: 1.3; color: var(--ink-dim); white-space: nowrap; }
.sh-card .fl { position: absolute; top: -4px; right: -2px; padding: 0 4px; font-style: normal; font-size: 12px; line-height: 1.5; color: var(--night); background: var(--brass-hi); }
.sh-card .fl.kp { right: auto; left: -2px; background: #9fe6ff; }
.modal .sh-card p { flex: 1 1 auto; margin: 0; font-size: 12px; line-height: 1.55; color: var(--ink); }
.modal .sh-card p .cost { color: #ff9b8c; }
.sh-card .btns { display: flex; gap: 4px; }
.sh-card .buy { flex: 1 1 0; display: inline-flex; align-items: center; justify-content: center; gap: 2px; padding: 3px 2px; white-space: nowrap; }
.sh-card .buy b { font-size: 14px; }
.sh-card .lk { flex: none; padding: 3px 5px; }
.sh-card.special { border-color: var(--brass); border-top-color: var(--qc); }
.sh-card.locked { border-color: #9fe6ff; border-top-color: var(--qc); background: #1f2240; }
.sh-card.sold { opacity: 0.4; filter: grayscale(0.8); }
.sh-tools { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 14px; margin-top: 8px; padding: 6px 8px; background: var(--night); }
.sh-rf { display: flex; align-items: center; gap: 8px; }
.sh-rf .chip b { color: var(--brass-hi); }
.sh-rf small { font-size: 12px; color: var(--ink-dim); }
.sh-ex { display: flex; flex-wrap: wrap; align-items: center; gap: 4px; margin-left: auto; }
.sh-ex .exl { display: inline-flex; align-items: center; gap: 2px; margin-right: 4px; font-size: 12px; color: var(--ink-dim); white-space: nowrap; }
.sh-ex .chip { padding: 4px 8px; }
.modal .sh-note { margin: 6px 0 0; font-size: 12px; line-height: 1.55; color: var(--ink-dim); max-width: none; }
.rd-sh h3.sh-h { margin: 10px 0 6px; }
.inv3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
.inv-g { min-width: 0; padding: 6px; background: rgba(27, 21, 48, 0.55); }
.modal .inv-g p.ig { margin: 0 0 4px; font-size: 12px; line-height: 1.4; color: var(--ink-dim); }
.modal .inv-g p.ig span { color: var(--ink); }
.inv3 .inv { gap: 4px; }
.inv3 .inv-item { padding: 2px 4px 2px 2px; font-size: 12px; }
.inv3 .inv-item img { width: 20px; height: 20px; }
.inv3 .inv-item .chip { padding: 1px 5px; }
.inv-item .iv-tag { margin-left: 4px; padding: 0 3px; font-size: 11px; color: var(--night); background: var(--brass-hi); }
img.coin-ic { width: 14px; height: 14px; image-rendering: pixelated; vertical-align: -2px; }
.sh-wallet img.coin-ic { width: 18px; height: 18px; }
/* 竖屏不再单独写死 2 列：--n 已经按对话框实际宽度算过，竖屏窄面板自然只会算出 1~2 列 */
/* 矮横屏（如 1067×507 的自适应窗口）：卡面说明压到 3 行、工具栏和说明更紧，
   让货架 + 工具栏 + 持有物品尽量一屏放下，不用滚动 */
:root[data-short] .rd-sh h2 { font-size: 20px; margin-bottom: 4px; }
:root[data-short] .rd-sh .sh-tabs { margin-bottom: 5px; }
:root[data-short] .sh-grid { gap: 4px; }
:root[data-short] .sh-card { gap: 2px; padding: 5px; }
:root[data-short] .sh-card .hd img { width: 24px; height: 24px; }
:root[data-short] .sh-card .tt b { font-size: 13px; }
:root[data-short] .sh-card .tt small { font-size: 11px; }
:root[data-short] .modal .sh-card p { font-size: 11px; line-height: 1.45; }
:root[data-short] .sh-card .buy, :root[data-short] .sh-card .lk { padding: 3px 4px; }
:root[data-short] .sh-tools { margin-top: 5px; padding: 4px 6px; gap: 4px 10px; }
:root[data-short] .modal .sh-note { margin-top: 4px; font-size: 11px; line-height: 1.45; }
:root[data-short] .rd-sh h3.sh-h { margin: 4px 0 3px; font-size: 14px; }
:root[data-short] .inv-g { padding: 4px; }
:root[data-short] .modal .inv-g p.ig { margin-bottom: 2px; }
:root[data-lay="P"] .sh-ex { margin-left: 0; }
:root[data-lay="P"] .inv3 { grid-template-columns: 1fr; gap: 4px; }
:root[data-lay="P"] .inv-g { display: flex; align-items: center; gap: 8px; }
:root[data-lay="P"] .modal .inv-g p.ig { flex: none; width: 7.5em; margin: 0; }
:root[data-lay="P"] .rd-sh .sh-tabs { padding-right: 0; }
]==]

return true
