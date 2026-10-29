-- ============================================================================
-- 存档（每个难度的最佳纪录、已通关难度、已解锁难度）与局外成长（军魂 / 军团强化）
-- 存档键与原版 localStorage 完全一致，统一保存在 save.json 里
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp = js.round, js.clamp
local floor, max, min = math.floor, math.max, math.min

-- ---------------------------------------------------------------------------
-- 极简 JSON（数组解析为 0 起始的 A()，与原版 JSON.parse 的结果一一对应）
-- ---------------------------------------------------------------------------
local function encodeStr(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == '\\' then return '\\\\'
        elseif c == '\n' then return '\\n' elseif c == '\r' then return '\\r' elseif c == '\t' then return '\\t' end
        return string.format('\\u%04x', c:byte())
    end) .. '"'
end
function jsonEncode(v, keyOrder)
    local t = type(v)
    if v == nil then return 'null' end
    if t == 'boolean' then return v and 'true' or 'false' end
    if t == 'number' then return js.numStr(v) end
    if t == 'string' then return encodeStr(v) end
    if js.isArr(v) then
        local parts = {}
        for i = 0, #v - 1 do parts[#parts + 1] = jsonEncode(v[i]) end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    local keys = keyOrder or {}
    if not keyOrder then
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    end
    local parts = {}
    for _, k in ipairs(keys) do
        if v[k] ~= nil then parts[#parts + 1] = encodeStr(tostring(k)) .. ':' .. jsonEncode(v[k]) end
    end
    return '{' .. table.concat(parts, ',') .. '}'
end
function jsonDecode(s)
    local pos = 1
    local function ws() pos = s:find('[^ \t\r\n]', pos) or (#s + 1) end
    local val
    local function str()
        pos = pos + 1
        local out = {}
        while true do
            local c = s:sub(pos, pos)
            if c == '' then error('bad json string') end
            if c == '"' then pos = pos + 1; break end
            if c == '\\' then
                local e = s:sub(pos + 1, pos + 1)
                if e == 'u' then
                    local cp = tonumber(s:sub(pos + 2, pos + 5), 16)
                    out[#out + 1] = utf8.char(cp); pos = pos + 6
                else
                    local map = { n = '\n', r = '\r', t = '\t', b = '\b', f = '\f' }
                    out[#out + 1] = map[e] or e; pos = pos + 2
                end
            else out[#out + 1] = c; pos = pos + 1 end
        end
        return table.concat(out)
    end
    val = function()
        ws()
        local c = s:sub(pos, pos)
        if c == '{' then
            pos = pos + 1; local o = {}
            ws()
            if s:sub(pos, pos) == '}' then pos = pos + 1; return o end
            while true do
                ws(); local k = str(); ws()
                if s:sub(pos, pos) ~= ':' then error('bad json object') end
                pos = pos + 1
                o[k] = val(); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == '}' then break elseif d ~= ',' then error('bad json object') end
            end
            return o
        elseif c == '[' then
            pos = pos + 1; local a = A()
            ws()
            if s:sub(pos, pos) == ']' then pos = pos + 1; return a end
            while true do
                a:push(val()); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == ']' then break elseif d ~= ',' then error('bad json array') end
            end
            return a
        elseif c == '"' then return str()
        elseif s:sub(pos, pos + 3) == 'true' then pos = pos + 4; return true
        elseif s:sub(pos, pos + 4) == 'false' then pos = pos + 5; return false
        elseif s:sub(pos, pos + 3) == 'null' then pos = pos + 4; return nil
        else
            local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', pos)
            if not num or num == '' then error('bad json value') end
            pos = pos + #num
            return tonumber(num)
        end
    end
    local v = val()
    ws()
    if pos <= #s then error('trailing json') end
    return v
end

-- ---------------------------------------------------------------------------
-- 本地存储（对应 localStorage）。后端由 main.lua 注入：读写 save.json
-- ---------------------------------------------------------------------------
store = {
    data = {},
    persist = nil, -- function(dataTable)
}
function store.get(k)
    local v = store.data[k]
    if v == nil then return nil end
    return v
end
function store.set(k, v)
    store.data[k] = js.S(v)
    if store.persist then pcall(store.persist, store.data) end
    if Cloud then Cloud.markDirty() end
end

-- 第一章沿用旧存档的键名，老玩家的进度不会丢
function bestKey(c, d)
    if c ~= 0 then return CHAPTERS[c].key .. '-best-' .. S(d) end
    if d ~= 0 then return 'reel-legion-best-' .. S(d) end
    return 'reel-legion-best'
end
local function parseIntOr0(s)
    if s == nil then return 0 end
    local n = tostring(s):match('^%s*([-+]?%d+)')
    return n and math.tointeger(tonumber(n)) or 0
end
function buildSave()
    SAVE = CHAPTERS:map(function(C, c)
        local best = C.diffs:map(function(_, d) return parseIntOr0(store.get(bestKey(c, d)) or '0') end)
        local cleared = parseIntOr0(store.get(C.key .. '-cleared') or '0')
        local unlock = parseIntOr0(store.get(C.key .. '-unlock') or '0')
        C.diffs:forEach(function(Df, d) if best[d] >= Df.waves then cleared = cleared | (1 << d) end end) -- 兼容旧存档
        C.diffs:forEach(function(_, d) if (cleared & (1 << d)) ~= 0 then unlock = max(unlock, d + 1) end end)
        return { best = best, cleared = cleared, unlock = clamp(unlock, 0, #C.diffs - 1) }
    end)
end
function chOpen(c) return c == 0 or (SAVE[c - 1].cleared & 1) ~= 0 end -- 通关上一章的第一个难度即可进入下一章
function saveBest(c, d, n)
    local Sv = SAVE[c]
    if n > Sv.best[d] then Sv.best[d] = n; store.set(bestKey(c, d), n) end
end
function clearDiff(c, d) -- 返回这次新解锁的 [{ c, d }]
    local Sv, C, news = SAVE[c], CHAPTERS[c], A()
    local nextWasOpen = c + 1 < #CHAPTERS and chOpen(c + 1)
    Sv.cleared = Sv.cleared | (1 << d); store.set(C.key .. '-cleared', Sv.cleared)
    if d + 1 < #C.diffs and Sv.unlock < d + 1 then Sv.unlock = d + 1; store.set(C.key .. '-unlock', Sv.unlock); news:push({ c = c, d = d + 1 }) end
    if c + 1 < #CHAPTERS and not nextWasOpen and chOpen(c + 1) then news:push({ c = c + 1, d = 0 }) end
    return news
end

-- =========================================================
-- 局外成长：军魂与军团强化（存档键 reel-legion-meta，不动原有存档）
-- =========================================================
META_KEY = 'reel-legion-meta'
-- 每日看广告的总上限（自适应、额外拉杆、复活、军魂翻倍合并计一次额度）
AD_DAILY_MAX = 10
-- 每守住 1 波的军魂 = 3 × 章节系数 × 难度系数；失败也照算，所以收入只和「守住了几波」有关
SOUL_BASE = 3
SOUL_CLEAR = 0.5   -- 通关奖励：整局基础收入的 50%
SOUL_FIRST = 1     -- 首次通关某章某难度的一次性奖励：整局基础收入的 100%（填 0 即关闭）
SOUL_ABANDON = 0.5 -- 中途回主页放弃时，已守住波数按这个比例结算
function soulPerWave(c, d) return max(1, round(SOUL_BASE * SOUL_CH[c] * SOUL_DIFF[d])) end

function symTotal() return SQUAD_SUM + SYM_WEIGHT.S end
function starRate(n) return (SYM_WEIGHT.S + n) / (symTotal() + n) end
function rarePct(l) return round((100 - (Q_ODDS[0] + Q_SHIFT[0] * l)) * 10) / 10 end

UPG[0].txt = function(l) return '开局 +' .. S(l) .. ' 金币' end
UPG[1].txt = function(l) return T(l) and ('每付费拉杆 ' .. S(CHEAP_EVERY[l]) .. ' 次，送 1 次免费拉杆') or '还没有集点' end
UPG[2].txt = function(l) return '战后利息最多 ' .. S(3 + l) .. ' 金币' end
UPG[3].txt = function(l) return T(l) and '每局送 1 次免费拉杆' or '没有免费拉杆' end
UPG[4].txt = function(l) return '每格出现 ★ 的概率 ' .. js.toFixed(starRate(l) * 100, 1) .. '%' end
UPG[5].txt = function(l) return '召唤出稀有及以上的占比 ' .. S(rarePct(l)) .. '%' end
UPG[6].txt = function(l) return '幸运最多积累 ' .. S(3 + l) .. ' 点' end
UPG[7].txt = function(l) return '全员生命 +' .. S(l * 2) .. '%' end
UPG[8].txt = function(l) return '全员攻击 +' .. S(l * 2) .. '%' end
UPG:forEach(function(u)
    if u.cls then
        local name = CLASSES[u.cls].name
        u.txt = function(l) return name .. (u.stat == 'hp' and '生命' or '攻击') .. ' +' .. S(l) .. '%' end
    end
end)

function backfillSouls() -- 老存档：按已有进度一次性补发
    local t = 0
    CHAPTERS:forEach(function(C, c)
        C.diffs:forEach(function(Df, d)
            local per = soulPerWave(c, d)
            local cleared = (SAVE[c].cleared & (1 << d)) ~= 0
            t = t + (cleared and Df.waves or min(SAVE[c].best[d] or 0, Df.waves)) * per
            if cleared then t = t + round(per * Df.waves * (SOUL_CLEAR + SOUL_FIRST)) end
        end)
    end)
    return t
end
local function toNum(v)
    local n = type(v) == 'number' and v or (type(v) == 'string' and tonumber(v) or (v == true and 1 or 0))
    if not n or n ~= n or n == math.huge or n == -math.huge then return 0 end
    return n
end
local function metaJson()
    local l = {}
    local order = {}
    UPG:forEach(function(u) l[u.id] = META.l[u.id]; order[#order + 1] = u.id end)
    return '{"s":' .. js.numStr(META.s) .. ',"l":' .. jsonEncode(l, order) .. ',"v":3,"cheapSpent":' .. js.numStr(META.cheapSpent or 0)
        .. ',"adDay":' .. jsonEncode(tostring(META.adDay or '')) .. ',"adN":' .. js.numStr(META.adN or 0) .. '}'
end

-- 本地和云端共用迁移：先统一到 v3，再比较余额与等级，不能把旧集点等级灌回新版。
function normalizeMeta(m)
    m.s = max(0, floor(toNum(m.s)))
    m.l = (type(m.l) == 'table' and not js.isArr(m.l)) and m.l or {}
    UPG:forEach(function(u) m.l[u.id] = clamp(floor(toNum(m.l[u.id])), 0, u.max) end)
    -- 每日广告计数：旧档没有这两个字段，按「今天还没看」处理
    m.adDay = type(m.adDay) == 'string' and m.adDay or ''
    m.adN = clamp(floor(toNum(m.adN)), 0, AD_DAILY_MAX)
    local version, refund = toNum(m.v), 0
    if version < 2 and m.l.cheap >= 1 then
        m.l.cheap = 1
        refund = 150
    end
    if version < 3 and m.l.cheap >= 1 then
        refund = refund + (m.l.cheap >= 2 and 650 or 250)
        m.l.cheap = 0
    end
    m.s = m.s + refund
    -- v3 旧档二级按原价 450+900 计；已购买等级不降级，也不因涨价多退军魂。
    local level = m.l.cheap
    local legacySpent = level == 2 and 1350 or (level == 1 and 450 or 0)
    local maxSpent = level == 2 and 1450 or (level == 1 and 450 or 0)
    m.cheapSpent = m.cheapSpent == nil and legacySpent or clamp(floor(toNum(m.cheapSpent)), 0, maxSpent)
    m.v = 3
    return m, refund
end

function loadMeta()
    ---@type table?
    local m = nil
    local raw = store.get(META_KEY)
    if raw then
        local ok, v = pcall(jsonDecode, raw)
        if ok and type(v) == 'table' then m = v --[[@as table]] end
    end
    local fresh = (m == nil) or type(m) ~= 'table' or js.isArr(m)
    if fresh then m = { s = backfillSouls(), l = {}, v = 3 } end
    local normalized, refund = normalizeMeta(m)
    m = normalized
    m.notice = fresh and m.s or 0 -- 只有第一次创建存档时提示一次，不写进存档
    m.refund = refund
    m.refundKind = refund > 0 and 'cheap3' or nil
    META = m
    store.set(META_KEY, metaJson())
    return m
end
function saveMeta() store.set(META_KEY, metaJson()) end

-- ---------------------------------------------------------------------------
-- 每日广告额度：所有广告位共用 AD_DAILY_MAX 次/天，跨天自动清零
-- 时间优先用 common.get_server_time()（权威源，改设备时间无效），
-- 拿不到就退回 os.time()，两者都不可用时按「今天未用」放行，避免误锁玩家。
-- ---------------------------------------------------------------------------
local function adToday()
    local ok, sec = pcall(function()
        local common = rawget(_G, 'common')
        if common and type(common.get_server_time) == 'function' then return common.get_server_time() end
        return nil
    end)
    if not (ok and type(sec) == 'number' and sec > 0) then
        local ok2, t = pcall(os.time)
        sec = (ok2 and type(t) == 'number') and t or nil
    end
    if not sec then return nil end
    local ok3, d = pcall(os.date, '!%Y-%m-%d', sec)
    if ok3 and type(d) == 'string' then return d end
    return nil
end

--- 今天还剩几次广告额度（跨天时自动重置）
function adLeftToday()
    local day = adToday()
    if not day then return AD_DAILY_MAX end -- 拿不到时间就不限制
    if META.adDay ~= day then return AD_DAILY_MAX end
    return max(0, AD_DAILY_MAX - (META.adN or 0))
end

--- 消耗一次广告额度。返回 false 表示今天已用完。
function adTakeSlot()
    local day = adToday()
    if not day then return true end -- 拿不到时间：放行，不写计数
    if META.adDay ~= day then META.adDay, META.adN = day, 0 end
    if (META.adN or 0) >= AD_DAILY_MAX then return false end
    META.adN = (META.adN or 0) + 1
    saveMeta()
    print('[拉杆军团] 今日广告额度已用 ' .. META.adN .. '/' .. AD_DAILY_MAX)
    return true
end

function upgLv(id) return META.l[id] or 0 end
function upgCan(u) return upgLv(u.id) < u.max and META.s >= u.cost[upgLv(u.id)] end
function canBuyAny() return UPG:some(upgCan) end
function spentSouls()
    return UPG:reduce(function(t, u)
        if u.id == 'cheap' then return t + (META.cheapSpent or 0) end
        return t + u.cost:slice(0, upgLv(u.id)):reduce(function(a, b) return a + b end, 0)
    end, 0)
end
function buyUpg(id)
    local u = UPG:find(function(x) return x.id == id end)
    if not u or not upgCan(u) then return false end
    local cost = u.cost[upgLv(id)]
    META.s = META.s - cost
    if id == 'cheap' then META.cheapSpent = (META.cheapSpent or 0) + cost end
    META.l[id] = upgLv(id) + 1
    saveMeta()
    print('[拉杆军团] 强化购买：' .. id .. '，等级=' .. upgLv(id) .. '，消耗=' .. cost)
    return true
end
function resetUpgs()
    META.s = META.s + spentSouls()
    META.l, META.cheapSpent = {}, 0
    UPG:forEach(function(u) META.l[u.id] = 0 end)
    saveMeta()
end
function metaFx() -- 当前强化折算成一局内用的数值
    local m = js.assign({}, MX_NONE)
    UPG:forEach(function(u) m[u.id] = upgLv(u.id) * (u.scale or 1) end)
    return m
end
function spinCost() return SPIN_COST end -- 拉杆不再打折，改为集点送免费拉杆
function stampGoal() return CHEAP_EVERY[(G and G.mx and (G.mx --[[@as table<string, number>]]).cheap) or 0] or 0 end
function paySpin() -- 扣一次拉杆的费用；集满点数时返回 true
    if G.freeSpins > 0 then G.freeSpins = G.freeSpins - 1; return false end
    G.gold = G.gold - spinCost()
    local n = stampGoal()
    if T(n) then
        G.paidSpins = G.paidSpins + 1
        if G.paidSpins >= n then G.paidSpins = 0; G.freeSpins = G.freeSpins + 1; return true end
    end
    return false
end
function interestCap() return 3 + ((G and G.mx and (G.mx --[[@as table<string, number>]]).interest) or 0) end
function qOdds()
    local l = (G and G.mx and (G.mx --[[@as table<string, number>]]).qual) or 0
    return Q_ODDS:map(function(v, i) return v + Q_SHIFT[i] * l end)
end
function settleRun(kind, first) -- kind: 'win' 通关 | 'lose' 全军覆没 | 'abandon' 中途放弃；每局只结算一次
    if G.tutorial or G.settled then return nil end
    G.settled = true
    local per, base = soulPerWave(G.ch, G.diff), G.soulPend
    local r = { kind = kind, waves = G.soulWaves, per = per, base = base, bonus = 0, first = 0, total = base }
    if kind == 'win' then
        r.bonus = round(per * G.maxWave * SOUL_CLEAR)
        r.first = first and round(per * G.maxWave * SOUL_FIRST) or 0
        r.total = base + r.bonus + r.first
    elseif kind == 'abandon' then r.total = floor(base * SOUL_ABANDON) end
    if r.total > 0 then META.s = META.s + r.total; saveMeta() end
    return r
end

return true
