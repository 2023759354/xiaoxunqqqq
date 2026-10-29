-- ============================================================================
-- 第九次更新：战斗统计（DPS 面板）
--  * 记录每个我方单位本场的「输出」（对敌人造成的伤害）、「承伤」（受到的伤害，含护盾吸收）、
--    「治疗」（给自己和队友恢复的生命：治疗技能、吸血、每秒回血、复活都算）
--  * 只在战斗中出现，放在战场旁边的信息栏里（替换原来的血条小头像），不压在战场上
--  * 三个页签切换排序（输出 / 承伤 / 治疗），每行显示总量和每秒；顶部是全队三项合计
--  * 召唤物（骷髅、炮塔、影分身……）的输出和治疗算在召唤者头上
-- 样式在 game/mithril.lua 的额外样式表里。
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local T, S = js.T, js.S
local floor, max, min = math.floor, math.max, math.min
local of = js.of

METER_STORE = 'reel-legion-meter'
METER_TABS = { { 'd', '输出', '#ff8a5a' }, { 't', '承伤', '#6ec8ff' }, { 'h', '治疗', '#8fe07a' } }
local FIELD = { d = 'mD', t = 'mT', h = 'mH' }

local function credit(e) -- 召唤物记在召唤者头上
    if e and e.minion and e.owner then return e.owner end
    return e
end
local function add(e, k, v)
    if not e or v <= 0 then return end
    e[k] = (e[k] or 0) + v
end

-- ---------------------------------------------------------------------------
-- 记录：伤害（hit / execute）、治疗（healAmt + 每帧对账，把吸血、回血、复活也算进去）
-- 这些包装必须在其他模块（equip2 / skills_ext2 / chapters2）的 hit 包装之后加载。
-- ---------------------------------------------------------------------------
local _hit = hit
function hit(src, t, base, o)
    local hp0, sh0 = t.hp, t.shield or 0
    local r = _hit(src, t, base, o)
    if r and r > 0 and G.battle then
        local dealt = min(r, max(0, hp0) + sh0)
        if t.side == 'p' then add(t, 'mT', dealt) end
        if src and src.side == 'p' and t.side ~= 'p' then add(credit(src), 'mD', dealt) end
        if t.side == 'p' then t.mLoss = (t.mLoss or 0) + max(0, hp0 - t.hp) end
    end
    return r
end
local _execute = execute
function execute(src, t)
    local hp0, dead0 = t.hp, t.dead
    _execute(src, t)
    if not dead0 and t.dead and G.battle then
        if t.side == 'p' then add(t, 'mT', hp0); t.mLoss = (t.mLoss or 0) + hp0 end
        if src and src.side == 'p' and t.side ~= 'p' then add(credit(src), 'mD', hp0) end
    end
end
-- 正在出手的单位：这期间的治疗记在它头上（技能群疗、圣疗师等）
local ACTOR = nil
local _tryAttack = tryAttack
function tryAttack(B, e, t)
    local prev = ACTOR
    ACTOR = e
    local ok, err = pcall(_tryAttack, B, e, t)
    ACTOR = prev
    if not ok then error(err, 0) end
end
local _healAmt = healAmt
function healAmt(t, amt)
    local got = _healAmt(t, amt)
    if got and got > 0 and G.battle and t.side == 'p' then
        local who = (ACTOR and ACTOR.side == t.side and not ACTOR.dead) and credit(ACTOR) or t
        add(who, 'mH', got)
        t.mHin = (t.mHin or 0) + got
    end
    return got
end
--- 每帧对账：生命比上一帧多出来、又不是 healAmt 给的部分（吸血、每秒回血、引导回血、复活）记为自己的治疗
local function reconcile(B)
    for e in of(B.ents) do
        if e.side == 'p' then
            if e.mLast ~= nil then
                local d = e.hp - e.mLast + (e.mLoss or 0) - (e.mHin or 0)
                if d > 0.01 then add(credit(e), 'mH', d) end
            end
            e.mLast, e.mLoss, e.mHin = e.hp, 0, 0
        end
    end
end
addHook('step', function(B) reconcile(B) end)

-- ---------------------------------------------------------------------------
-- 界面：信息栏里的统计面板（替换战斗中的血条小头像，0.4 秒刷新一次）
-- ---------------------------------------------------------------------------
function meterMode()
    if not UI.meterMode then
        local m = store and store.get and store.get(METER_STORE)
        UI.meterMode = (m == 't' or m == 'h') and m or 'd'
    end
    return UI.meterMode
end
--- 12345 → 1.2万；1234 → 1234
function meterNum(v)
    v = v or 0
    if v >= 100000 then return S(floor(v / 10000 + 0.5)) .. '万' end
    if v >= 10000 then return js.toFixed(v / 10000, 1) .. '万' end
    return S(floor(v + 0.5))
end
local function rowsOf(B)
    local out = {}
    for e in of(B.ents) do
        if e.side == 'p' and not e.minion and (e.unit or e.temp) then out[#out + 1] = e; e.mIdx = e.mIdx or #out end
    end
    return out
end
local function entIcon(e)
    if e.unit then return unitIconURL(e.unit) end
    return iconURL(CLASSES[e.cls] and CLASSES[e.cls].sprite or 'sym_star')
end
function UI.meterHTML(B, np, ne)
    local mode = meterMode()
    local key = FIELD[mode]
    local rows = rowsOf(B)
    local secs = max(1, B.t or 0)
    local tot = { mD = 0, mT = 0, mH = 0 }
    for _, e in ipairs(rows) do for k in pairs(tot) do tot[k] = tot[k] + (e[k] or 0) end end
    table.sort(rows, function(a, b)
        local va, vb = a[key] or 0, b[key] or 0
        if va ~= vb then return va > vb end
        return (a.mIdx or 0) < (b.mIdx or 0)
    end)
    local top = 0
    for _, e in ipairs(rows) do top = max(top, e[key] or 0) end
    local col = '#ff8a5a'
    local tabs = {}
    for _, t in ipairs(METER_TABS) do
        if t[1] == mode then col = t[3] end
        tabs[#tabs + 1] = '<button class="dm-tab' .. (t[1] == mode and ' on' or '') .. '" data-dm="' .. t[1] .. '" style="--mc:' .. t[3] .. '">' .. t[2] .. '</button>'
    end
    local parts = {
        '<span class="dmeter" style="--mc:' .. col .. '">',
        '<span class="dm-head"><span class="dm-tabs">' .. table.concat(tabs) .. '</span><small>' .. (np and ('我方 <b>' .. S(np) .. '</b> · 敌方 <b class="foe">' .. S(ne) .. '</b> · ') or '') .. S(floor(B.t or 0)) .. ' 秒</small></span>',
        '<span class="dm-sum"><span style="color:#ff8a5a">输出 <b>' .. meterNum(tot.mD) .. '</b></span><span style="color:#6ec8ff">承伤 <b>' .. meterNum(tot.mT) .. '</b></span><span style="color:#8fe07a">治疗 <b>' .. meterNum(tot.mH) .. '</b></span>' ..
            '<span class="dm-dps">全队每秒 <b>' .. meterNum(tot[key] / secs) .. '</b></span></span>',
        '<span class="dm-list">',
    }
    for _, e in ipairs(rows) do
        local v = e[key] or 0
        local w = (top > 0) and floor(v / top * 100 + 0.5) or 0
        local hp = e.dead and 0 or floor(e.hp / e.maxHp * 10 + 0.5) * 10
        local q = e.unit and QUAL[e.unit.q or 0].color or '#9a8ab0'
        parts[#parts + 1] = '<span class="dm-row' .. (e.dead and ' dead' or '') .. '" style="--qc:' .. q .. '"><img src="' .. entIcon(e) .. '" alt="">' ..
            '<span class="dm-main"><span class="dm-bar"><i style="width:' .. S(w) .. '%"></i><b>' .. meterNum(v) .. '</b><em>' .. meterNum(v / secs) .. '/秒</em></span>' ..
            '<span class="dm-hp"><i style="width:' .. S(hp) .. '%"></i></span></span></span>'
    end
    parts[#parts + 1] = '</span></span>'
    return table.concat(parts)
end

-- 战斗中的信息栏：原来的血条小头像换成统计面板（血条保留在每一行下面）
-- layout.lua 已经定义了 UI.rosterHTML(B)（0.4 秒缓存），这里换成带双方人数的版本。
local meterT, meterCache = -1, ''
function UI.rosterHTML(B, np, ne)
    if G.time - meterT < 0.4 and G.time >= meterT then return meterCache end
    meterT = G.time
    meterCache = UI.meterHTML(B, np, ne)
    return meterCache
end
function UI.meterRefresh() meterT = -1; UI.cache:set('info', nil) end

local _init = UI.init
function UI.init()
    _init()
    -- 页签：事件委托（信息栏每次重绘都不用重新绑定）
    UI.els.info:addEventListener('click', function(ev)
        local n = ev.target
        while n and n ~= UI.els.info do
            local m = n.attrs and n.attrs['data-dm']
            if m then
                Sound.init()
                UI.meterMode = m
                if store and store.set then pcall(store.set, METER_STORE, m) end
                UI.meterRefresh()
                return
            end
            n = n.parent
        end
    end)
end

return true
