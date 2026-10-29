-- ============================================================================
-- 战场规则与出征限制；新增章节由章节模块登记 CH_RULES[5] / CH_RULES[6]。
-- 共用现有逻辑、DOM 和像素画布，不替换旧冰原 / 神殿的战斗机制。
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S = js.A, js.T, js.S
local round, clamp = js.round, js.clamp
local floor, max, abs, sin, cos = math.floor, math.max, math.abs, math.sin, math.cos
local of = js.of
---@type table<string, any>
local UI = UI

CELL_KINDS = {
    seal = { name = '封印格', short = '封', color = '#5a4a6a', desc = '不能放置单位' },
    high = { name = '高地格', short = '高', color = '#c9b08a', desc = '站在这里开战的远程单位射程 +15' },
    swamp = { name = '沼泽格', short = '沼', color = '#4f8a3a', desc = '单位在格子里移动速度 -30%' },
    altar = { name = '祭坛格', short = '祭', color = '#6ef0ff', desc = '站在这里开战的单位技能能量获取 +25%' },
}
CELL_ORDER = A('seal', 'high', 'swamp', 'altar')
CH_RULES = {
    [0] = { text = A('第一章是教学章节，没有特殊规则。'), ban = 'mage' },
    [1] = { hazard = 'fissure', text = A('<b>地裂</b>每 12 秒在战场上预警两条熔岩地裂，1 秒后喷发，敌我都会受伤。'), ban = 'archer' },
    [2] = { hazard = 'erosion', text = A('<b>虚空侵蚀</b>每波随机一格被侵蚀，站在里面的单位每秒流失 10 点技能能量。'), ban = 'sunflower' },
    [3] = { short = '冰原：寒霜、冰墓与暴风雪', text = A('敌人的<b>寒霜</b>会减速并冻结单位；冰霜女皇可召唤冰墓与暴风雪。留意新敌人说明。'), ban = 'tiger' },
    [4] = { short = '神殿：格挡、圣辉光环与星陨', text = A('敌人拥有<b>格挡与圣辉光环</b>，星陨会先在落点预警；星穹神王还有阶段机制。留意新敌人说明。'), ban = 'bear' },
}
function chRules(c) return CH_RULES[c == nil and G.ch or c] or { text = A(), ban = 'mage' } end

function cellAt(i) return G and G.cells and G.cells[i] or nil end
function isSealed(i) return cellAt(i) == 'seal' end
function rollCells(c)
    local R, cells = chRules(c), {}
    if not R.cells then return cells end
    local free = js.from(FORM_N, function(i) return i end)
    for kind in of(CELL_ORDER) do
        for _ = 1, (R.cells[kind] or 0) do
            if #free == 0 then break end
            local k = floor(js.random() * #free)
            cells[free[k]] = kind
            free:splice(k, 1)
        end
    end
    return cells
end
function rollErosion()
    local open = js.from(FORM_N, function(i) return i end):filter(function(i) return not isSealed(i) end)
    if #open == 0 then return nil end
    return open[floor(js.random() * #open)]
end
local _autoPlace = autoPlace
function autoPlace(u)
    if not G.cells or not next(G.cells) then return _autoPlace(u) end
    local cols = CLASSES[u.cls].proj and { 1, 0, 2, 3 } or { 3, 2, 1, 0 }
    for _, c in ipairs(cols) do
        for _, r in ipairs({ 1, 0, 2 }) do
            local i = r * 4 + c
            if not G.form[i] and not isSealed(i) then G.form[i] = u; return { t = 'f', i = i } end
        end
    end
    for i = 0, BENCH_N - 1 do if not G.bench[i] then G.bench[i] = u; return { t = 'b', i = i } end end
    return nil
end
local _dropAt = dropAt
function dropAt(u, from, to)
    if to and to.t == 'f' and isSealed(to.i) then Sound.play('deny'); UI.toast('封印格不能放置单位'); return end
    return _dropAt(u, from, to)
end

-- 区域设计（像素画布坐标，非物理碰撞）：
-- 格心 fPos(i)        地裂线段 (x,y) ---------------- (x2,y2)
-- +---- ±13 ----+     命中：到线段距离 <= w + 单位半径。
-- |    ±16     |     沼泽 / 侵蚀：含矩形边界，不扩大到相邻格中心。
-- +------------+     封印：自动落位、拖放和逻辑顶替均应跳过（isSealed）。
addHook('pent', function(ent, u, i)
    local k = cellAt(i)
    ent.cell = k
    if k == 'high' and ent.proj then ent.range = ent.range + 15 end
    if k == 'altar' then ent.chargeMul = (ent.chargeMul or 1) + 0.25 end
end)
function envSource(B)
    if not B.env then
        local m = waveMult(G.wave) * diffMult(curDiff(), G.wave)
        B.env = makeEnt('e', { x = 230, y = 72, maxHp = 1, atk = round(10 * m), cd = 1, crit = 0, leech = 0, range = 0, speed = 0, r = 0, type = 'env' })
        B.env.envSrc = true
    end
    return B.env
end
addHook('start', function(B)
    if G.tutorial then return end
    local R = chRules()
    B.healMul, B.burnMul = R.healMul, R.burnMul
    B.hazT = 12
    if R.hazard == 'erosion' then
        local i = G.erosion or rollErosion()
        if i ~= nil then
            G.erosion = i
            local p = fPos(i)
            B.fields:push({ kind = 'erosion', x = p.x, y = p.y, r = 14, t = 999, max = 999, src = envSource(B), drain = 10 })
        end
    end
    if R.global == 'tide' then B.tide = { t = 20, high = true }; applyTide(B) end
    if R.onStart then R.onStart(B) end
end)
addHook('step', function(B, dt, alive)
    if G.tutorial then return end
    local R = chRules()
    if R.hazard == 'fissure' and not B.over then
        B.hazT = B.hazT - dt
        if B.hazT <= 0 then
            B.hazT = 12
            for _ = 1, 2 do
                local y = 24 + js.random() * (FIELD_H - 44)
                local y2 = clamp(y + rand(-30, 30), 18, FIELD_H - 12)
                B.fields:push({ kind = 'fissure', x = 8, y = y, x2 = AW - 8, y2 = y2, w = 6, warn = 1.0, t = 1.5, max = 1.5, src = envSource(B), mul = 1.6, fired = false, both = true })
            end
            Sound.play('skill')
        end
    end
    if R.global == 'tide' and B.tide and not B.over then
        B.tide.t = B.tide.t - dt
        if B.tide.t <= 0 then B.tide.t = 20; B.tide.high = not B.tide.high; applyTide(B); UI.banner(B.tide.high and '涨潮：远程射程 -25%' or '退潮：近战移速 -30%', 'gold') end
    end
    local swamps = {}
    for i, k in pairs(G.cells or {}) do if k == 'swamp' then swamps[#swamps + 1] = fPos(i) end end
    for e in of(alive) do
        local spd = 1
        for _, p in ipairs(swamps) do if abs(e.x - p.x) <= 13 and abs(e.y - p.y) <= 16 then spd = 0.7 end end
        if B.tide and not B.tide.high and isMeleeEnt(e) and e.speed > 0 then spd = spd * 0.7 end
        e.unitRule = (spd < 1) and { spd = spd } or nil
    end
    if R.onStep then R.onStep(B, dt, alive) end
end)
function applyTide(B)
    for e in of(B.ents) do
        if e.proj then
            e.baseRange = e.baseRange or e.range
            e.range = B.tide.high and round(e.baseRange * 0.75) or e.baseRange
        end
    end
end
local _stepHazard = stepHazard
function stepHazard(B, f, dt)
    if f.kind == 'erosion' then
        f.t = f.t - dt
        for o in of(B.ents) do
            if not o.dead and o.side == 'p' and o.skill and abs(o.x - f.x) <= 13 and abs(o.y - f.y) <= 16 then
                o.energy = max(0, o.energy - f.drain * dt)
                if js.random() < 0.15 then FX.parts:push({ x = o.x + rand(-4, 4), y = o.y - 4, vx = 0, vy = 10, g = 0, life = 0.4, max = 0.4, color = '#6ef0ff', size = 1 }) end
            end
        end
        if f.t <= 0 then f.done = true end
        return
    end
    -- 与原 hazard 的减时相同帧检查，确保敌我地裂同时爆发且只命中一次。
    if f.both and f.kind == 'fissure' and not f.fired and f.t - dt <= f.max - f.warn then
        for o in of(B.ents) do
            if not o.dead and o.side == 'e' and not o.immune and segDist(o.x, o.y, f.x, f.y, f.x2, f.y2) <= f.w + o.r then
                local dmg = round(f.src.atk * f.mul * 0.6)
                o.hp = o.hp - dmg; o.flash = 0.1; FX.damage(o, dmg, false, false, true)
                if o.hp <= 0 then o.hp = 0; o.dead = true; o.deadT = 0; FX.death(o); onDeath(o, f.src) end
            end
        end
    end
    return _stepHazard(B, f, dt)
end

AFFIX_LIMITS = {
    ban = { name = '禁兵', desc = function(c) return '本章禁用' .. CLASSES[chRules(c).ban or 'mage'].name end },
    oneRanged = { name = '孤弓', desc = function() return '最多带 1 个远程兵种' end },
}
AFFIX_SOUL = 1.25
PENDING_LIMITS = nil
function limitsOK(sq, lim, c)
    if not lim then return true end
    local banned = chRules(c).ban or 'mage'
    if lim.ban and sq:includes(banned) then return false, '本章禁用' .. CLASSES[banned].name end
    if lim.oneRanged and #sq:filter(function(k) return CLASSES[k].proj end) > 1 then return false, '最多带 1 个远程兵种' end
    return true
end
local _newGame = newGame
function newGame(ch, diff, squad)
    _newGame(ch, diff, squad)
    G.cells = rollCells(G.ch)
    G.erosion = nil
    G.limits = (G.diff == #curCh().diffs - 1) and PENDING_LIMITS or nil
    PENDING_LIMITS = nil
    local n = 0
    if G.limits then for _, v in pairs(G.limits) do if v then n = n + 1 end end end
    G.soulMul = AFFIX_SOUL ^ n
end
local _soulPerWave = soulPerWave
function soulPerWave(c, d)
    local mul = (G and G.ch == c and G.diff == d) and G.soulMul or 1
    return max(1, round(_soulPerWave(c, d) * (mul or 1)))
end
local _currentLineup = currentLineup
function currentLineup()
    local fresh = not G.lineup or G.lineup.wave ~= G.wave
    local l = _currentLineup()
    if fresh and chRules().hazard == 'erosion' then G.erosion = rollErosion() end
    return l
end

function rulesHTML(c)
    local R, C = chRules(c), CHAPTERS[c]
    local parts = A()
    for t in of(R.text or A()) do parts:push('<p>' .. t .. '</p>') end
    if R.cells then
        local cl = CELL_ORDER:filter(function(k) return R.cells[k] end):map(function(k) return '<b style="color:' .. CELL_KINDS[k].color .. '">' .. CELL_KINDS[k].name .. ' ×' .. S(R.cells[k]) .. '</b>' .. CELL_KINDS[k].desc end)
        parts:push('<p>阵地格子（每局随机位置）：' .. cl:join('；') .. '</p>')
    end
    return '<div class="rules" style="--qc:' .. C.color .. '"><b>' .. C.name .. '战场规则</b>' .. parts:join('') .. '</div>'
end
function ruleBarText()
    if G.tutorial then return nil end
    local R, parts = chRules(), A()
    if R.short then parts:push(R.short) end
    if R.hazard == 'fissure' then parts:push('地裂每 12 秒，预警后敌我均受伤') end
    if R.hazard == 'erosion' then parts:push('虚空侵蚀：' .. ((G.erosion ~= nil) and ('第 ' .. S(floor(G.erosion / 4) + 1) .. ' 行第 ' .. S(G.erosion % 4 + 1) .. ' 列') or '每波随机一格') .. '吸能') end
    if G.cells and next(G.cells) then
        local cnt = {}
        for _, k in pairs(G.cells) do cnt[k] = (cnt[k] or 0) + 1 end
        CELL_ORDER:forEach(function(k) if cnt[k] then parts:push(CELL_KINDS[k].name .. ' ×' .. S(cnt[k])) end end)
    end
    if G.limits then
        if G.limits.ban then parts:push(AFFIX_LIMITS.ban.desc(G.ch)) end
        if G.limits.oneRanged then parts:push('最多 1 个远程') end
    end
    if #parts == 0 then return nil end
    return '<b>战场规则</b>' .. parts:join('　')
end
function UI.updateRuleBar()
    local el = UI.els.ruleBar
    if not el then return end
    local t = ruleBarText()
    if UI.cache:get('rulebar') == (t or '') then return end
    UI.cache:set('rulebar', t or '')
    el:setHidden(not t)
    if t then el:setHTML(t) end
end
function drawCells(ctx, battle)
    for i, k in pairs(G.cells or {}) do
        local r, K = cellRect({ t = 'f', i = i }), CELL_KINDS[k]
        if K then
            local cr, cg, cb = js.parseColor(K.color)
            local rgb = S(cr) .. ',' .. S(cg) .. ',' .. S(cb)
            if k == 'seal' then
                ctx.fillStyle = 'rgba(20,14,34,0.55)'; ctx:fillRect(r.x + 1, r.y + 1, r.w - 2, r.h - 2)
                ctx.fillStyle = K.color
                for d = 0, r.w - 3, 3 do ctx:fillRect(r.x + 1 + d, r.y + 1 + floor(d * (r.h - 2) / (r.w - 2)), 2, 1); ctx:fillRect(r.x + r.w - 2 - d, r.y + 1 + floor(d * (r.h - 2) / (r.w - 2)), 2, 1) end
            else
                ctx.fillStyle = 'rgba(' .. rgb .. ',' .. (battle and 0.12 or 0.2) .. ')'; ctx:fillRect(r.x + 1, r.y + 1, r.w - 2, r.h - 2)
                frameRect(ctx, r.x, r.y, r.w, r.h, 'rgba(' .. rgb .. ',0.6)')
                ctx.fillStyle = K.color
                if k == 'swamp' then for j = 0, 4 do ctx:fillRect(r.x + 3 + j * 5, r.y + r.h - 4 - (j % 2) * 3, 3, 1) end
                elseif k == 'high' then ctx:fillRect(r.x + 3, r.y + r.h - 4, r.w - 6, 1); ctx:fillRect(r.x + 6, r.y + r.h - 6, r.w - 12, 1)
                elseif k == 'altar' then local cx, cy = r.x + r.w / 2, r.y + r.h - 5; ctx:fillRect(cx - 3, cy, 7, 1); ctx:fillRect(cx, cy - 3, 1, 7) end
            end
        end
    end
end
FIELD_DRAW.erosion = function(f)
    for i = 0, 13 do
        local a = i / 14 * 6.283 + G.time * 1.5
        local rr = 10 + 2 * sin(G.time * 3 + i)
        actx.fillStyle = (i % 2 == 0) and '#8f4bc4' or '#6ef0ff'
        actx:fillRect(round(f.x + cos(a) * rr), round(f.y + sin(a) * rr * 0.8), 1, 1)
    end
    actx.fillStyle = 'rgba(90,40,160,0.18)'; actx:fillRect(round(f.x) - 12, round(f.y) - 15, 25, 27)
end
return true
