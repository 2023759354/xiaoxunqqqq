-- ============================================================================
-- 第十次更新：点地块、点敌人查看具体效果和数值
--  * 布阵阶段：点空的特殊格子（封印 / 高地 / 沼泽 / 祭坛 / 冰面）→ 格子的效果和数值；
--    点战场右边的敌人 → 按这一波的实际倍率算出的生命、攻击、攻速、射程、移速、减伤和机制说明
--  * 战斗中：点任意单位（敌我都行）→ 信息栏顶部出现实时卡片，统计面板留在下面
--  * 选中站在特殊格子上的我方单位：单位卡片里多一行，写这个格子对它是否生效
--  * 只读数据、不调用会消耗随机数的函数，战斗结果不受影响；新手教程里不启用
-- 本工程适配：10 章、虚空侵蚀格、寒意（chill 是 { n, t } 表）、晶体牢笼（prisonT）。
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local CONTENT = require("ui.content")
local A, T, S = js.A, js.T, js.S
local round, hypot = js.round, js.hypot
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local of = js.of

UI.insp = nil -- { kind = 'cell', i } | { kind = 'foe', e（阵容条目） } | { kind = 'ent', ent }
local function pct(v) return S(round(v * 100)) end
local function num(v) return js.toFixed(v, 2):gsub('0+$', ''):gsub('%.$', '') end

-- ---------------------------------------------------------------------------
-- 命中测试
-- ---------------------------------------------------------------------------
local function erosionCell() return (chRules().hazard == 'erosion') and G.erosion or nil end
local function cellKindAt(i) return cellAt(i) or ((erosionCell() == i) and 'erosion' or nil) end

local function nearLineup(p)
    local best, bd = nil, 1e9
    currentLineup():forEach(function(e)
        local E = ENEMIES[e.type]
        local hw, hh = E.big and 15 or 9, E.big and 24 or 15
        local dx, dy = p.x - e.x, p.y - (e.y - hh / 2 + 3)
        if abs(dx) <= hw and abs(dy) <= hh / 2 + 3 then
            local d = hypot(dx, dy)
            if d < bd then best, bd = e, d end
        end
    end)
    return best
end
local function nearEnt(p)
    local B = G.battle
    if not B then return nil end
    local best, bd = nil, 1e9
    for e in of(B.ents) do
        if not e.dead and not e.envSrc and (e.side == 'p' or e.side == 'e') then
            local big = e.big or e.sup or ((e.giant or 0) > 0)
            local hw, hh = big and 15 or 9, big and 24 or 15
            local dx, dy = p.x - e.x, p.y - (e.y - hh / 2 + 3)
            if abs(dx) <= hw and abs(dy) <= hh / 2 + 3 then
                local d = hypot(dx, dy) - ((e.side == 'e') and 2 or 0) -- 重叠时优先敌人
                if d < bd then best, bd = e, d end
            end
        end
    end
    return best
end

local function setInsp(v)
    UI.insp = v
    UI.inspT = -1
    if v then Sound.play('tick') end
    UI.cache:set('info', nil)
end
local function sameInsp(v)
    local o = UI.insp
    if not o or not v or o.kind ~= v.kind then return false end
    if v.kind == 'cell' then return o.i == v.i end
    if v.kind == 'foe' then return o.e == v.e end
    return o.ent == v.ent
end

local _down = Arena.down
function Arena.down(px, py, isTouch)
    local p = toArena(px, py)
    if G.phase == 'battle' and G.battle and not G.tutorial then
        local e = nearEnt(p)
        local v = e and { kind = 'ent', ent = e } or nil
        if v and sameInsp(v) then setInsp(nil) elseif v then setInsp(v) end
        return _down(px, py, isTouch)
    end
    if G.phase == 'prep' and not G.tutorial then
        local s = hitSlot(p)
        local u = s and getSlot(s)
        if not u then
            local v = nil
            local f = nearLineup(p)
            if f then v = { kind = 'foe', e = f }
            elseif s and s.t == 'f' and cellKindAt(s.i) then v = { kind = 'cell', i = s.i } end
            if v then
                G.sel = nil
                if sameInsp(v) then setInsp(nil) else setInsp(v) end
                return false
            end
        end
        if UI.insp then setInsp(nil) end
    end
    return _down(px, py, isTouch)
end

-- ---------------------------------------------------------------------------
-- 卡片内容
-- ---------------------------------------------------------------------------
local CELL_FX = {
    seal = function() return '不能放置单位；拖过去会被拒绝。' end,
    high = function(u)
        local s = '远程单位站在这里开战：射程 <b>+15</b>（近战没有效果）。'
        if u then
            local st = unitStats(u)
            if st.proj then s = s .. '<br>现在站着 ' .. qSpan(u) .. '：射程 ' .. S(st.range) .. ' → <b class="up">' .. S(st.range + 15) .. '</b>'
            else s = s .. '<br>现在站着 ' .. qSpan(u) .. '：<span class="warn">近战，不生效</span>' end
        end
        return s
    end,
    swamp = function() return '任何单位（敌我都算）走进这个格子：移动速度 <b>-30%</b>。只减移动，不影响攻击。' end,
    altar = function(u)
        local s = '站在这里开战的单位：技能能量获取 <b>+25%</b>，技能放得更勤。'
        if u then s = s .. '<br>现在站着 ' .. qSpan(u) .. '：<b class="up">生效</b>' end
        return s
    end,
    ice = function() return '任何单位（敌我都算）走进这个格子：移动速度 <b>+30%</b>；在格子里被眩晕或冻结时，持续时间 <b>+50%</b>。' end,
    erosion = function() return '本波被虚空侵蚀：我方站在里面的单位每秒流失 <b>10</b> 点技能能量（满能量 100），每波换一个位置。' end,
}
local function cellName(k)
    if k == 'erosion' then return '虚空侵蚀格', '#c06bff' end
    local K = CELL_KINDS[k]
    return K.name, K.color
end
local function cellLine(i)
    return '第 ' .. S(floor(i / 4) + 1) .. ' 行第 ' .. S(i % 4 + 1) .. ' 列'
end

function UI.cellCardHTML(i)
    local k = cellKindAt(i)
    if not k then return nil end
    local nm, col = cellName(k)
    local u = G.form[i]
    local extra = ''
    if k ~= 'erosion' and erosionCell() == i then extra = '<span class="ins-tx">' .. CELL_FX.erosion() .. '</span>' end
    return '<span class="ins" style="--qc:' .. col .. '"><span class="ins-h"><i class="ins-cell"></i><span class="ins-nm"><b>' .. nm .. '</b><small>' .. cellLine(i) .. ' · 阵地格子</small></span>' ..
        '<button class="chip ins-x" data-insp-x="1" aria-label="关闭">×</button></span>' ..
        '<span class="ins-tx">' .. CELL_FX[k](u) .. '</span>' .. extra .. '</span>'
end

--- 敌人在某一波的数值（和 enemyEnt 同样的算法，但不建实体、不用随机数）
function foeStats(type, elite, w)
    local E, Df = ENEMIES[type], curDiff()
    local m = waveMult(w) * diffMult(Df, w)
    local hm, am = elite and ELITE_HP or 1, elite and ELITE_ATK or 1
    local fx = E.fx or {}
    return { hp = round(E.hp * m * hm), atk = round(E.atk * m * am), cd = E.cd, range = E.range, speed = E.speed, proj = E.proj, splash = E.splash or 0,
        dr = (fx.dr or 0) + (fx.armor or 0) + (fx.iceArmor or 0), dodge = fx.dodge or 0, leech = fx.leech or 0, antiR = fx.antiRanged, mirror = fx.mirrorArmor, mult = m }
end
local function foeIcon(type) local E = ENEMIES[type]; return iconURL(E.sprite, E.pal or nil, 'foe:' .. type) end
local function statRow(st, live)
    local parts = {}
    local function p(lbl, v) parts[#parts + 1] = '<span>' .. lbl .. ' <b>' .. v .. '</b></span>' end
    if not live then p('生命', S(st.hp)) end
    p('攻击', S(st.atk))
    p('每秒', num(1 / st.cd) .. ' 次')
    p('射程', S(st.range) .. (st.proj and '（远程）' or '（近战）'))
    if T(st.speed) then p('移速', S(round(st.speed))) else p('移速', '不移动') end
    if (st.splash or 0) > 0 then p('溅射', S(st.splash)) end
    if (st.dr or 0) > 0 then p('减伤', pct(min(0.8, st.dr)) .. '%') end
    if (st.dodge or 0) > 0 then p('闪避', pct(st.dodge) .. '%') end
    if (st.leech or 0) > 0 then p('吸血', pct(st.leech) .. '%') end
    if T(st.antiR) then p('远程伤害', '-' .. pct(st.antiR) .. '%') end
    if T(st.mirror) then p('反弹', pct(st.mirror) .. '%') end
    return '<span class="ins-st">' .. table.concat(parts) .. '</span>'
end
local function foeText(type)
    local E = ENEMIES[type]
    if E.desc then return E.desc end
    if E.proj then return '普通远程敌人，没有特殊机制。' end
    return '普通近战敌人，没有特殊机制。'
end

function UI.foeCardHTML(e)
    local E = ENEMIES[e.type]
    local st = foeStats(e.type, e.elite, G.wave)
    local tag = (E.big and '首领' or (e.elite and '精英' or '敌人')) .. ' · 第 ' .. S(G.wave) .. ' 波数值'
    local elite = e.elite and ('<span class="ins-tx foe">精英：生命 ×' .. num(ELITE_HP) .. '、攻击 ×' .. num(ELITE_ATK) .. '</span>') or ''
    return '<span class="ins" style="--qc:' .. (e.elite and '#ff5a4a' or (E.big and '#ffb03a' or '#ff9b8c')) .. '"><span class="ins-h"><img src="' .. foeIcon(e.type) .. '" alt=""><span class="ins-nm"><b>' .. E.name .. '</b><small>' .. tag .. '</small></span>' ..
        '<button class="chip ins-x" data-insp-x="1" aria-label="关闭">×</button></span>' ..
        statRow(st, false) .. elite .. '<span class="ins-tx">' .. foeText(e.type) .. '</span></span>'
end

--- 战斗中实体身上的状态（寒意在本工程是 { n, t } 表）
local function statusList(e)
    local s = {}
    local function add(t, cls) s[#s + 1] = '<em class="' .. (cls or '') .. '">' .. t .. '</em>' end
    if (e.inv or 0) > 0 or e.immune then add('无敌', 'g') end
    if e.untargetable or e.shifted then add('隐身', 'g') end
    if e.stun > 0 then add(((e.frozenT or 0) > 0 and '冻结 ' or '眩晕 ') .. num(e.stun) .. ' 秒', 'b') end
    if (e.prisonT or 0) > 0 then add('晶石牢笼 ' .. num(e.prisonT) .. ' 秒', 'b') end
    if T(e.charmed) then add('倒戈', 'b') end
    if e.burn then add('灼烧', 'b') end
    if e.poison then add('中毒', 'b') end
    if e.bleed then add('流血', 'b') end
    if e.slow then add('减速 ' .. pct(e.slow.amt or 0) .. '%', 'b') end
    if (e.root or 0) > 0 then add('根植', 'b') end
    if (e.wither or 0) > 0 then add('枯萎（无法治疗）', 'b') end
    if e.curse then add('诅咒：易伤 +' .. pct(e.curse.vuln or 0) .. '%', 'b') end
    if e.chill then add('寒意 ×' .. S(e.chill.n or 0), 'b') end
    if e.infect then add('感染', 'b') end
    if (e.haste or 0) > 0 then add('狂热（攻速翻倍）', 'g') end
    if (e.overT or 0) > 0 then add('过载', 'g') end
    if e.shield > 0 then add('护盾 ' .. S(round(e.shield)), 'g') end
    if e.guard then add('守护', 'g') end
    if #s == 0 then return '' end
    return '<span class="ins-fx">' .. table.concat(s) .. '</span>'
end

function UI.entCardHTML(ent)
    local hpPct = max(0, min(100, floor(ent.hp / ent.maxHp * 100 + 0.5)))
    local shPct = min(100 - hpPct, floor((ent.shield or 0) / ent.maxHp * 100 + 0.5))
    local bar = '<span class="ins-hp"><i style="width:' .. S(hpPct) .. '%"></i>' .. ((shPct > 0) and ('<u style="left:' .. S(hpPct) .. '%;width:' .. S(shPct) .. '%"></u>') or '') ..
        '<b>' .. (ent.dead and '已被击败' or (S(max(0, round(ent.hp))) .. ' / ' .. S(ent.maxHp))) .. '</b></span>'
    local st = { atk = ent.atk, cd = ent.cd, range = ent.range, speed = ent.speed, proj = ent.proj, splash = ent.splash or 0,
        dr = (ent.dr or 0) + (ent.armor or 0), dodge = ent.dodge or 0, leech = ent.leech or 0, antiR = ent.antiR, mirror = ent.mirrorArmor }
    local close = '<button class="chip ins-x" data-insp-x="1" aria-label="关闭">×</button>'
    if ent.side == 'e' and ENEMIES[ent.type] then
        local E = ENEMIES[ent.type]
        local tag = E.big and '首领' or (ent.elite and '精英' or (ent.minion and '召唤物' or '敌人'))
        return '<span class="ins" style="--qc:' .. (ent.elite and '#ff5a4a' or (E.big and '#ffb03a' or '#ff9b8c')) .. '"><span class="ins-h"><img src="' .. foeIcon(ent.type) .. '" alt=""><span class="ins-nm"><b>' .. E.name .. '</b><small>' .. tag .. '</small></span>' .. close .. '</span>' ..
            bar .. statRow(st, true) .. statusList(ent) .. '<span class="ins-tx">' .. foeText(ent.type) .. '</span></span>'
    end
    -- 我方单位（或被魅惑倒戈的单位）
    local u = ent.unit
    local name = u and qSpan(u) or ((CLASSES[ent.cls] and CLASSES[ent.cls].name) or '召唤物')
    local icon = u and unitIconURL(u) or iconURL((CLASSES[ent.cls] and CLASSES[ent.cls].sprite) or 'sym_star')
    local SK = ent.skill and SKILLS[ent.skill]
    local en = SK and ('<span class="ins-tx">技能「' .. SK.name .. '」能量 <b>' .. S(floor(ent.energy or 0)) .. '</b>/100' .. (ent.chargeMul and ent.chargeMul > 1 and ('（能量获取 +' .. pct(ent.chargeMul - 1) .. '%）') or '') .. '：' .. SK.desc .. '</span>') or ''
    local cell = ent.cell and CELL_KINDS[ent.cell] and ('<span class="ins-tx">开战格子：<b style="color:' .. CELL_KINDS[ent.cell].color .. '">' .. CELL_KINDS[ent.cell].name .. '</b></span>') or ''
    return '<span class="ins" style="--qc:' .. (u and QUAL[u.q or 0].color or '#8fe07a') .. '"><span class="ins-h"><img src="' .. icon .. '" alt=""><span class="ins-nm"><b>' .. name .. '</b><small>' .. (ent.side == 'e' and '倒戈中' or (ent.minion and '召唤物' or '我方')) .. '</small></span>' .. close .. '</span>' ..
        bar .. statRow(st, true) .. statusList(ent) .. en .. cell .. '</span>'
end

-- ---------------------------------------------------------------------------
-- 信息栏
-- ---------------------------------------------------------------------------
local lastSel = nil
local function inspValid()
    local v = UI.insp
    if not v then return false end
    if G.tutorial then return false end
    if v.kind == 'ent' then
        if G.phase ~= 'battle' or not G.battle then return false end
        if v.ent.dead and (v.ent.deadT or 0) > 1.5 then return false end
        return true
    end
    if G.phase == 'battle' and v.kind == 'foe' and G.battle then
        -- 布阵时看的敌人：开战后换成对应的实体，接着看实时数值
        local best, bd = nil, 1e9
        for e in of(G.battle.ents) do
            if e.side == 'e' and e.type == v.e.type and not e.minion then
                local d = hypot(e.x - v.e.x, e.y - v.e.y)
                if d < bd then best, bd = e, d end
            end
        end
        if best and bd < 40 then UI.insp = { kind = 'ent', ent = best }; return true end
        return false
    end
    if G.phase ~= 'prep' then return false end
    if v.kind == 'cell' then return cellKindAt(v.i) ~= nil end
    if v.kind == 'foe' then
        return currentLineup():includes(v.e)
    end
    return false
end
function UI.inspectHTML()
    local v = UI.insp
    if v.kind == 'cell' then return UI.cellCardHTML(v.i) end
    if v.kind == 'foe' then return UI.foeCardHTML(v.e) end
    return UI.entCardHTML(v.ent)
end

local _infoHTML = UI.infoHTML
function UI.infoHTML(units)
    if G.sel ~= lastSel then lastSel = G.sel; if G.sel then UI.insp = nil end end
    if UI.insp and not inspValid() then UI.insp = nil end
    if UI.insp and not (drag and drag.moved) then
        if G.phase == 'battle' then
            -- 实时卡片每 0.25 秒刷新一次（和统计面板一样不每帧重排）
            if not UI.inspCache or G.time - (UI.inspT or -1) >= 0.25 or G.time < (UI.inspT or 0) then
                UI.inspT = G.time; UI.inspCache = UI.inspectHTML()
            end
            return UI.inspCache .. _infoHTML(units)
        end
        local h = UI.inspectHTML()
        if h then return h end
    end
    return _infoHTML(units)
end

-- 选中的我方单位站在特殊格子上：单位卡片里写清楚
local _card = UI.unitCardHTML
function UI.unitCardHTML(u)
    local h = _card(u)
    local s = findSlot(u)
    if not s or s.t ~= 'f' then return h end
    local k = cellKindAt(s.i)
    if not k then return h end
    local nm, col = cellName(k)
    local line
    if k == 'high' then
        local st = unitStats(u)
        line = st.proj and ('射程 ' .. S(st.range) .. ' → <b class="up">' .. S(st.range + 15) .. '</b>') or '<span class="warn">近战，不生效</span>'
    elseif k == 'altar' then line = '技能能量获取 <b class="up">+25%</b>'
    elseif k == 'swamp' then line = '在格子里移动速度 -30%'
    elseif k == 'ice' then line = '在格子里移动速度 +30%，被控时间 +50%'
    elseif k == 'erosion' then line = '<span class="warn">每秒流失 10 点技能能量</span>'
    else line = '' end
    local add = '<span class="uc-cell" style="--qc:' .. col .. '"><b>' .. nm .. '</b>' .. line .. '</span>'
    if h:sub(-7) == '</span>' then return h:sub(1, -8) .. add .. '</span>' end
    return h .. add
end

local _init = UI.init
function UI.init()
    _init()
    UI.els.info:addEventListener('click', function(ev)
        local n = ev.target
        while n and n ~= UI.els.info do
            if n.attrs and n.attrs['data-insp-x'] then Sound.init(); setInsp(nil); return end
            n = n.parent
        end
    end)
end

-- 换波、开新局时清掉
addHook('finish', function() UI.insp = nil end)
local _newGame = newGame
function newGame(...) UI.insp = nil; return _newGame(...) end

-- ---------------------------------------------------------------------------
-- 战场高亮
-- ---------------------------------------------------------------------------
local _render = renderArena
function renderArena()
    _render()
    local v = UI.insp
    if not v or G.tutorial then return end
    local ctx = actx
    local blink = floor(G.time * 4) % 2 == 0
    if v.kind == 'cell' and G.phase == 'prep' then
        local r = cellRect({ t = 'f', i = v.i })
        corners(ctx, r.x - 1, r.y - 1, r.w + 2, r.h + 2, blink and '#ffffff' or '#6ef0ff', 5)
    elseif v.kind == 'foe' and G.phase == 'prep' then
        local big = ENEMIES[v.e.type].big
        local w, h = big and 30 or 18, big and 30 or 22
        corners(ctx, round(v.e.x - w / 2), round(v.e.y - h + 5), w, h, blink and '#ffffff' or '#ff5a4a', 4)
    elseif v.kind == 'ent' and G.battle and not v.ent.dead then
        local e = v.ent
        local big = e.big or e.sup or ((e.giant or 0) > 0)
        local w, h = big and 30 or 18, big and 30 or 22
        corners(ctx, round(e.x - w / 2), round(e.y - h + 5), w, h, blink and '#ffffff' or ((e.side == 'e') and '#ff5a4a' or '#8fe07a'), 4)
    end
end

-- ---------------------------------------------------------------------------
-- 样式
-- ---------------------------------------------------------------------------
CONTENT.css = CONTENT.css .. [==[
/* ===== 第十次更新：点选查看格子 / 敌人 ===== */
.ins { display: flex; flex-direction: column; gap: 3px; margin-bottom: 4px; padding: 5px 7px; background: rgba(27, 21, 48, 0.85); border-left: 4px solid var(--qc); }
.ins-h { display: flex; align-items: center; gap: 6px; min-width: 0; }
.ins-h img { flex: none; width: 24px; height: 24px; image-rendering: pixelated; }
.ins-h .ins-cell { flex: none; width: 20px; height: 20px; border: 2px solid var(--qc); background: rgba(255, 255, 255, 0.08); }
.ins-nm { display: flex; flex-direction: column; flex: 1 1 0; min-width: 0; line-height: 1.3; }
.ins-nm b { font-size: 14px; color: var(--qc); }
.ins-nm small { font-size: 12px; color: var(--ink-dim); }
.ins .ins-x { flex: none; padding: 0 7px; font-size: 14px; line-height: 1.4; }
.ins-hp { position: relative; display: block; height: 13px; background: #2d2245; }
.ins-hp i { position: absolute; left: 0; top: 0; display: block; height: 13px; background: #d8433a; }
.ins-hp u { position: absolute; top: 0; display: block; height: 13px; background: #9fe6ff; }
.ins-hp b { position: absolute; left: 0; right: 0; top: 0; text-align: center; font-size: 11px; line-height: 13px; color: #fff; text-shadow: 1px 1px 0 #1b1530; }
.ins-st { display: flex; flex-wrap: wrap; gap: 0 10px; font-size: 12px; line-height: 1.55; color: var(--ink-dim); }
.ins-st span { white-space: nowrap; }
.ins-st b { color: var(--ink); }
.ins-fx { display: flex; flex-wrap: wrap; gap: 3px; }
.ins-fx em { font-style: normal; font-size: 12px; line-height: 1.4; padding: 0 4px; color: var(--night); background: #ff9b8c; }
.ins-fx em.g { background: #8fe07a; }
.ins-tx { font-size: 12px; line-height: 1.55; color: var(--ink); }
.ins-tx.foe { color: #ff9b8c; }
.ins-tx b { color: var(--brass-hi); }
.ins .warn { color: #ff9b8c; }
.ins .up { color: #8fe07a; }
.uc-cell { display: block; margin-top: 3px; padding: 2px 6px; font-size: 12px; line-height: 1.5; background: rgba(27, 21, 48, 0.6); border-left: 3px solid var(--qc); }
.uc-cell b { color: var(--qc); margin-right: 6px; }
.uc-cell .warn { color: #ff9b8c; }
]==]

return true
