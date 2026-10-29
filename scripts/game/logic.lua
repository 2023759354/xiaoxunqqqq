-- ============================================================================
-- 拉杆军团 —— 核心逻辑（逐行移植自原版 HTML 的 <script>）
-- 老虎机召唤 + 吸收升星 + 三星转职 / 晋升 + 三章 × 四难度
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local D = require("game.data")
for k, v in pairs(D) do N[k] = v end

local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, atan, sqrt = math.floor, math.ceil, js.max, math.min, math.abs, math.atan, math.sqrt
local of = js.of

N.js = js
N.A, N.T, N.S, N.OR = A, T, S, OR

-- ---------- 扩展钩子：道具、战场规则与新章节 ----------
FIELD_DRAW, PROJ_DRAW, BG_PAINT = {}, {}, {}
HOOKS = { start = {}, step = {}, lose = {}, pent = {}, stats = {}, death = {}, finish = {}, ent = {} }
function runHooks(name, ...) for _, f in ipairs(HOOKS[name]) do f(...) end end
function addHook(name, f) table.insert(HOOKS[name], f) end

-- ---------- 常量与数据 ----------
AW, AH, FIELD_H = 256, 176, 142
FORM_N, BENCH_N = 12, 8
SPIN_COST, START_GOLD, START_LIVES = 3, 12, 3

SQUAD_N, DEFAULT_SQUAD, SQUAD_SUM = 3, A('warrior', 'archer', 'mage'), 77
LUCK_BONUS = 6
CLASS_SYM = {}
for s, c in pairs(SYM_CLASS) do CLASS_SYM[c] = s end
SYM_ORDER = A('W', 'A', 'M', 'T', 'B', 'F', 'U', 'S') -- SYM_WEIGHT 的键顺序

function isBossT(t) return not not ENEMIES[t].big end
function isSup(u) return not not (u and u.branch and BRANCHES[u.branch] and BRANCHES[u.branch].sup) end

-- 最后一波永远是首领波；波次越多，魔王的护卫越强
local function bossWave(n)
    if n >= 14 then return A('boss', 'orcwar', 'orc', 'skelarcher', 'darkmage', 'lichpriest') end
    if n >= 12 then return A('boss', 'orc', 'orc', 'skelarcher', 'darkmage', 'lichpriest') end
    return A('boss', 'orc', 'orc', 'skelarcher', 'darkmage')
end
local function bossWave2(n)
    if n >= 14 then return A('colossus', 'obsidian', 'obsidian', 'ashblade', 'pyromancer', 'forgepriest') end
    if n >= 12 then return A('colossus', 'obsidian', 'ashblade', 'pyromancer', 'forgepriest') end
    return A('colossus', 'obsidian', 'magmaslime', 'pyromancer')
end
local function bossWave3(n)
    if n >= 14 then return A('voidlord', 'mirrorguard', 'mirrorguard', 'phaser', 'hooker', 'charmer') end
    if n >= 12 then return A('voidlord', 'mirrorguard', 'phaser', 'hooker', 'charmer') end
    return A('voidlord', 'mirrorguard', 'cultist', 'charmer')
end
CHAPTERS[0].boss = bossWave
CHAPTERS[1].boss = bossWave2
CHAPTERS[2].boss = bossWave3
CHAPTERS[0].bossWarn = function(Df)
    return '深渊魔王会带着护卫出场。' .. (T(Df.adds) and ('魔王生命过半时会召唤 ' .. S(Df.adds) .. ' 个亡灵。') or '')
end
CHAPTERS[1].bossWarn = function(Df)
    return '熔核巨像会带着护卫出场。它 60% 生命时退回熔炉，召唤 3 根熔岩晶柱并进入无敌，先打碎晶柱；30% 生命时暴走' ..
        (T(Df.adds) and ('，召唤 ' .. S(Df.adds) .. ' 个援军') or '') .. '。'
end
CHAPTERS[2].bossWarn = function(Df)
    return '虚空之主会带着护卫出场。它 66% 生命时复制你攻击最高的 ' .. S(Df.adds) .. ' 个单位；33% 生命时开始 6 秒「虚空坍缩」吟唱并套上护盾，倒计时结束前打破护盾就能打断，否则全场受到重创。'
end

function waveDef(w)
    if w >= G.maxWave then return curCh().boss(G.maxWave) end
    return curCh().waves[w - 1]
end
function waveTag(w)
    if w >= G.maxWave then return '首领波' end
    if w % 5 == 0 then return '精英波' end
    return ''
end
-- 前 10 波每波 +24%，之后每波 +18%
function waveMult(w) return 1 + 0.24 * (min(w, 10) - 1) + 0.18 * max(0, w - 10) end

function curCh() return CHAPTERS[G.ch] end
function curDiff() return CHAPTERS[G.ch].diffs[G.diff] end
ELITE_HP, ELITE_ATK = 1.6, 1.3
-- 难度加成随波次递增：第 1 波只有一半加成，最后一波吃满
function diffMult(Df, w) return 1 + (Df.mult - 1) * (0.5 + 0.5 * (w - 1) / (Df.waves - 1)) end

AFFIXES[0].fmt = function(v) return '攻击 +' .. S(v) .. '%' end
AFFIXES[1].fmt = function(v) return '生命 +' .. S(v) .. '%' end
AFFIXES[2].fmt = function(v) return '攻速 +' .. S(v) .. '%' end
AFFIXES[3].fmt = function(v) return '暴击率 +' .. S(v) .. '%' end
AFFIXES[4].fmt = function(v) return '吸血 ' .. S(v) .. '%' end

Q_MAX = 3 -- 晋升链的最高品质：传说
Q_SUP = 4 -- 超凡
function pct(v) return round((v - 1) * 100) end
function routeNames(cls, q) return CLASS_BRANCHES[cls][q]:map(function(b) return BRANCHES[b].name end):join('、') end
function canPromote(u) return not u.branch and (u.q or 0) < Q_MAX end -- 传说已是最高品质，只能转职

-- ---------- 工具 ----------
rand = js.rand
function pick(arr) return arr[floor(js.random() * #arr)] end
function starStr(n) return js.rep('★', n) end
function unitName(u)
    if u.branch then return BRANCHES[u.branch].name end
    return CLASSES[u.cls].name .. starStr(u.star)
end
function fullName(u) return (T(u.q) and QUAL[u.q].name or '') .. unitName(u) end
function qSpan(u)
    return '<span class="qtag' .. (((u.q or 0) >= Q_SUP) and ' sup' or '') .. '" style="color:' .. QUAL[u.q or 0].color .. '">' .. fullName(u) .. '</span>'
end
REDUCED = false

-- ---------- 状态 ----------
-- 状态由章节、道具和平台模块按生命周期扩展，字段值保持动态类型。
---@type table<string, any>?
G = nil --[[@as table<string, any>?]]
-- ---------- 开局选兵种：老虎机里只出现选中的 3 种图标 ----------
SQUAD_KEY = 'reel-legion-squad'
function classOpen(c)
    if not CLASSES[c] then return false end
    local u = CLASSES[c].unlock
    if u == nil then return true end
    return SAVE ~= nil and SAVE[u] ~= nil and (SAVE[u].cleared & 1) ~= 0
end
function classLockText(c)
    local u = CLASSES[c].unlock
    local C = CHAPTERS[u]
    return '通关' .. (C and C.name or ('第 ' .. S(u + 1) .. ' 章')) .. '「普通」后解锁'
end
function validSquad(s) -- 3 个互不相同的有效兵种，按图鉴顺序排列；不合法就用默认阵容
    if not js.isArr(s) then return DEFAULT_SQUAD:slice() end
    local u = js.uniq(s):filter(function(c) return CLASS_KEYS:includes(c) and classOpen(c) end)
    if #u == SQUAD_N then return CLASS_KEYS:filter(function(c) return u:includes(c) end) end
    return DEFAULT_SQUAD:slice()
end
function loadSquad()
    local raw = store.get(SQUAD_KEY)
    if not raw then return validSquad(nil) end
    local ok, v = pcall(jsonDecode, raw)
    if not ok then return DEFAULT_SQUAD:slice() end
    return validSquad(v)
end
function saveSquad(s) store.set(SQUAD_KEY, jsonEncode(s)) end

-- ---------- 广告奖励 ----------
AD_SPIN_MAX = 3    -- 每局最多看 3 次「额外拉杆」广告
AD_REVIVE_MAX = 1  -- 每局最多看 1 次复活广告
AD_DOUBLE_MAX = 1  -- 每局最多看 1 次「军魂翻倍」广告

--- 看广告换一次免费拉杆（每次 1 次，每局最多 AD_SPIN_MAX 次）
function adSpin()
    ---@type table<string, any>
    local UI = UI
    if G.phase ~= 'prep' then return end
    if G.adSpins >= AD_SPIN_MAX then Sound.play('deny'); UI.banner('本局额外拉杆次数已用完', 'red'); return end
    local run = G
    local free = Ads.available() and adLeftToday() <= 0
    UI.showAdConfirm('额外拉杆',
        free and '今日广告次数已用完，直接多 1 次免费拉杆。' or '看一段广告，本局立刻多 1 次免费拉杆。',
        '本局已用 ' .. S(G.adSpins) .. '/' .. S(AD_SPIN_MAX) .. ' 次',
        function()
            if G ~= run or G.phase ~= 'prep' or G.adSpins >= AD_SPIN_MAX then return false end
            G.adSpins = G.adSpins + 1; G.freeSpins = G.freeSpins + 1
            print('[拉杆军团] 广告奖励到账：免费拉杆 +1，本局已用=' .. G.adSpins)
            return true
        end,
        function() UI.banner('额外拉杆 +1', 'gold'); startSpin() end,
        function() end)
end

--- 复活：回到 1 点生命，这一波重打（每局最多 AD_REVIVE_MAX 次）
---@param rematch boolean 战败后复活时要重打这一波；否则保留阵型，玩家自己调整
function adRevive(rematch)
    ---@type table<string, any>
    local UI = UI
    if G.phase ~= 'gameover' or G.settled or G.adRevives >= AD_REVIVE_MAX then return end
    G.adRevives = G.adRevives + 1
    G.lives = 1
    G.phase = 'prep'
    G.settled = false -- 这一局还没结束，结算留给之后真正的胜负
    if rematch then
        G.lineup = nil -- 这一波的敌人重新排队（同一波阵容固定，等于重打）
    end
    print('[拉杆军团] 广告奖励到账：复活，生命=' .. G.lives .. '，本局已用=' .. G.adRevives)
    UI.toast('广告奖励：复活成功')
    UI.banner(rematch and '复活！这一波重打' or '复活！还剩 1 点生命', 'red')
    UI.modal('复活成功', '<p>回到 <b>1 点生命</b>' .. (rematch and '，这一波重打' or '') .. '。</p><p class="dim">调整阵型后点「开战」。</p>', '继续布阵', nil)
end

--- 看广告把本局军魂翻倍（每局最多 AD_DOUBLE_MAX 次，在结算界面点）
function adDouble(s)
    ---@type table<string, any>
    local UI = UI
    if not s or not T(s.total) or s.doubled or G.adDouble >= AD_DOUBLE_MAX then return end
    G.adDouble = G.adDouble + 1
    local extra = s.total
    s.total = s.total * 2
    s.doubled = true
    META.s = META.s + extra
    saveMeta()
    print('[拉杆军团] 广告奖励到账：军魂 +' .. extra .. '，余额=' .. META.s)
    UI.toast('广告奖励：军魂翻倍')
end
function squadSyms() return G.squad:map(function(c) return CLASS_SYM[c] end) end
function squadWeights(sq) -- 选中的 3 个兵种按原权重等比缩放，总和固定为 SQUAD_SUM；★ 单独加上
    local syms = sq:map(function(c) return CLASS_SYM[c] end)
    local base = syms:map(function(s) return SYM_WEIGHT[s] end)
    local sum = base:reduce(function(a, b) return a + b end, 0)
    local w = { keys = A() } -- keys 记录插入顺序（JS 对象键的遍历顺序）
    syms:forEach(function(s, i) w[s] = base[i] * SQUAD_SUM / sum; w.keys:push(s) end)
    w.S = SYM_WEIGHT.S; w.keys:push('S')
    return w
end
function squadGrid(sq) -- 开局转轴上的初始图案
    local m = { W = CLASS_SYM[sq[0]], A = CLASS_SYM[sq[1]], M = CLASS_SYM[sq[2]], S = 'S' }
    return A('W', 'A', 'M', 'M', 'S', 'W', 'A', 'W', 'M'):map(function(s) return m[s] end)
end
function newGame(ch, diff, squad)
    local c = clamp(js.trunc(ch or 0), 0, #CHAPTERS - 1)
    local DS = CHAPTERS[c].diffs
    local d = clamp(js.trunc(diff or 0), 0, #DS - 1)
    local mx = metaFx() -- 局外成长：开局时拍一张快照，整局不变
    local sq = validSquad(squad or (G and G.squad) or loadSquad()) -- 本局出征的 3 个兵种
    G = {
        ch = c, diff = d, maxLives = DS[d].lives, maxWave = DS[d].waves, lineup = nil, seen = js.Set(),
        wave = 1, lives = DS[d].lives, gold = START_GOLD + (DS[d].gold or 0) + mx.gold, luck = 0, luckMax = 3 + mx.luck, freeSpins = mx.free, paidSpins = 0, mx = mx,
        soulPend = 0, soulWaves = 0, settled = false,
        adSpins = 0, adRevives = 0, adDouble = 0, adUse = 0,
        form = js.filled(FORM_N, nil), bench = js.filled(BENCH_N, nil),
        squad = sq, symW = squadWeights(sq), nextId = 1, phase = 'prep', battle = nil, sel = nil, time = 0, speed = 1, shake = 0,
        stats = { spins = 0, summoned = 0, maxStar = 1, maxQ = 0, awakened = 0, promoted = 0, jackpots = 0 }, pendingAwaken = A(),
        slot = { grid = squadGrid(sq), jack = nil, strips = A(A(), A(), A()), off = A(0, 0, 0), stopped = A(true, true, true),
            dur = A(0.7, 0.95, 1.2), t = 0, spinning = false, next = nil, wins = A(), ri = 0, rt = 0, show = A() },
    } --[[@as table<string, any>]]
    SPAWN_COUNT = {}
    FX.reset()
end

-- ---------- 单位与槽位 ----------
function rollAffix(q) -- 品质越高，词条数值的下限越高
    local f, a = QUAL[q or 0].affix, pick(AFFIXES)
    local r = f + js.random() * (1 - f)
    return { id = a.id, v = round(a.min + r * (a.max - a.min)), q = (r < 0.4) and 0 or (r < 0.7) and 1 or (r < 0.9) and 2 or 3 }
end
--- 吞噬成长：当前比本星级的基础倍率高多少（0.27 = +27%）
-- 第九次更新：以前属性只在升 ★★ / ★★★ 的那一下大涨，中间吸收多少经验都不加属性；
-- 现在星级倍率按经验进度线性过渡，每吸收 1 点经验都涨一截，到 ★★ / ★★★ 时正好和原来的倍率一样
-- （满星强度不变）。ABSORB_GROW = 0 回到原来的算法。
ABSORB_GROW = 1
function starMult(u)
    local s = u.star
    local m = STAR_MULT[s]
    if s < 3 and not u.branch and T(ABSORB_GROW) then
        local p0, p1 = STAR_PTS[s], STAR_PTS[s + 1]
        local f = clamp(((u.pts or p0) - p0) / (p1 - p0), 0, 1)
        m = m + (STAR_MULT[s + 1] - m) * f * ABSORB_GROW
    end
    return m
end
function absorbBonus(u) return starMult(u) / STAR_MULT[u.star] - 1 end
function unitStats(u)
    local C, a = CLASSES[u.cls], u.affix
    local B = u.branch and BRANCHES[u.branch] or nil
    local M = B and B.mods or {}
    local Q = QUAL[u.q or 0]
    local m = starMult(u) * Q.base * (B and Q.awaken or 1)
    local hp, atk, cd = C.hp * m * (1 + (M.hp or 0)), C.atk * m * (1 + (M.atk or 0)), C.cd / (1 + (M.spd or 0))
    local crit, leech = 0.05 + (M.crit or 0), M.leech or 0
    if a.id == 'atk' then atk = atk * (1 + a.v / 100) end
    if a.id == 'hp' then hp = hp * (1 + a.v / 100) end
    if a.id == 'spd' then cd = cd / (1 + a.v / 100) end
    if a.id == 'crit' then crit = crit + a.v / 100 end
    if a.id == 'leech' then leech = leech + a.v / 100 end
    local mx = (G and G.mx) or MX_NONE
    hp = hp * (1 + mx.hp + (mx['hp_' .. u.cls] or 0)); atk = atk * (1 + mx.atk + (mx['atk_' .. u.cls] or 0)) -- 军团强化：全员 + 兵种单独的生命 / 攻击
    local fx = js.assign({}, C.fx or {}, (B and B.fx) or {})
    local st = { hp = hp, atk = atk, cd = cd, crit = crit, leech = leech, range = C.range + (M.range or 0),
        skill = B and B.skill or CLASS_SKILL[u.cls], dr = M.dr or 0, berserk = not not M.berserk, burnOnHit = not not M.burn, extra = M.extra or 0,
        speed = C.speed * (1 + (M.move or 0)), critMul = OR(M.critMul, 2), slowHit = M.slowHit or 0, chainHit = M.chainHit or 0,
        fullEnergy = not not M.fullEnergy, proj = (B and B.proj) or C.proj or nil, fx = fx }
    runHooks('stats', u, st)
    st.hp = round(st.hp); st.atk = round(st.atk)
    return st
end
function fPos(i) return { x = 20 + (i % 4) * 28, y = 34 + floor(i / 4) * 38 } end
function bPos(i) return { x = 18 + i * 31, y = 160 } end
function ePos(c, r) return { x = 152 + c * 28, y = 34 + r * 38 } end
function getSlot(s) if s.t == 'f' then return G.form[s.i] end return G.bench[s.i] end
function setSlot(s, u) if s.t == 'f' then G.form[s.i] = u else G.bench[s.i] = u end end
function findSlot(u)
    if u == nil then return nil end
    local i = G.form:indexOf(u); if i >= 0 then return { t = 'f', i = i } end
    i = G.bench:indexOf(u); if i >= 0 then return { t = 'b', i = i } end
    return nil
end
function slotPos(s) if s.t == 'f' then return fPos(s.i) end return bPos(s.i) end
function allUnits() return G.form:concat(G.bench):compact() end

function autoPlace(u)
    local ranged = not not CLASSES[u.cls].proj
    local cols = ranged and { 1, 0, 2, 3 } or { 3, 2, 1, 0 }
    for _, c in ipairs(cols) do
        for _, r in ipairs({ 1, 0, 2 }) do
            local i = r * 4 + c
            if not G.form[i] then G.form[i] = u; return { t = 'f', i = i } end
        end
    end
    for i = 0, BENCH_N - 1 do if not G.bench[i] then G.bench[i] = u; return { t = 'b', i = i } end end
    return nil
end
function absorbGain(src, dst)
    if src.cls == dst.cls then return 2 + src.pts end
    return ceil((2 + src.pts) / 2)
end
-- ★★★ 封顶：升到三星立即可以转职，不再需要额外经验
function canAbsorb(src, dst)
    return not not (src and dst and src ~= dst and not isSup(src) and not dst.branch and not dst.awakenReady and dst.star < 3)
end
function previewAbsorb(dst, gain)
    local s = dst.star
    local p = dst.pts + gain
    while s < 3 and p >= STAR_PTS[s + 1] do s = s + 1 end
    return { star = s, awaken = s == 3 }
end
-- 高星单位喂给低星吸收者会永久损失星级，需要玩家确认
function needsAbsorbConfirm(src, dst)
    return canAbsorb(src, dst) and (src.star or 1) > (dst.star or 1)
end
function absorb(src, dst)
    local from = findSlot(src)
    local fromPos = from and slotPos(from) or nil
    if from then setSlot(from, nil) end
    local gain, before = absorbGain(src, dst), dst.star
    dst.pts = dst.pts + gain
    while dst.star < 3 and dst.pts >= STAR_PTS[dst.star + 1] do dst.star = dst.star + 1 end
    local ready = false
    if dst.star == 3 then
        dst.pts = STAR_PTS[3]
        if not dst.awakenReady and not dst.branch then dst.awakenReady = true; ready = true; G.pendingAwaken:push(dst) end
    end
    G.stats.maxStar = max(G.stats.maxStar, dst.star)
    if G.sel == src then G.sel = dst end
    local up = dst.star > before
    FX.absorb(src, dst, fromPos, gain, up, ready)
    return { gain = gain, up = up, ready = ready }
end
function awaken(u, b)
    u.branch = b; u.awakenReady = false
    G.pendingAwaken = G.pendingAwaken:filter(function(x) return x ~= u end)
    G.stats.awakened = G.stats.awakened + 1
    FX.awaken(u)
end
-- 词条跟着品质提升：同一种词条，按新品质的下限重抽一次，取较好的那个
function upgradeAffix(a, q)
    local Af = AFFIXES:find(function(x) return x.id == a.id end)
    local span = Af.max - Af.min
    local f = QUAL[q].affix
    local rOld = (span ~= 0) and (a.v - Af.min) / span or 1
    local r = max(rOld, f + js.random() * (1 - f))
    return { id = a.id, v = round(Af.min + r * span), q = (r < 0.4) and 0 or (r < 0.7) and 1 or (r < 0.9) and 2 or 3 }
end
-- ★★★ 晋升后品质 +1，从 ★★ 起步，保留再次吸收升星的空间。
PROMOTE_STAR = 2
function promote(u)
    if not canPromote(u) then return end
    u.q = (u.q or 0) + 1; u.star = PROMOTE_STAR; u.pts = STAR_PTS[PROMOTE_STAR]; u.awakenReady = false
    u.affix = upgradeAffix(u.affix, u.q)
    G.pendingAwaken = G.pendingAwaken:filter(function(x) return x ~= u end)
    G.stats.promoted = G.stats.promoted + 1
    G.stats.maxQ = max(G.stats.maxQ, u.q)
    FX.promote(u)
end
function rollQuality(mn)
    mn = mn or 0
    local od = qOdds()
    local tot = 0
    for q = mn, Q_MAX do tot = tot + od[q] end
    local r = js.random() * tot
    for q = mn, Q_MAX do r = r - od[q]; if r < 0 then return q end end
    return mn
end
-- 把单位 v 当经验喂给最合适的吸收者（同职业、高品质优先）；没人能吸收就折算 2 金币
local function b2n(b) return b and 1 or 0 end
function feedAway(v)
    local cands = allUnits():filter(function(x) return canAbsorb(v, x) end)
    cands:sort(function(a, b)
        local r = b2n(b.cls == v.cls) - b2n(a.cls == v.cls)
        if r ~= 0 then return r end
        r = (b.q or 0) - (a.q or 0)
        if r ~= 0 then return r end
        return b.pts - a.pts
    end)
    if #cands > 0 then
        local into = cands[0]
        return js.assign({ into = into }, absorb(v, into))
    end
    G.gold = G.gold + 2
    return { sold = true }
end
function summon(cls, star, q)
    q = clamp(js.trunc(q or 0), 0, Q_MAX)
    local u = { id = G.nextId, cls = cls, star = star, q = q, pts = STAR_PTS[star], affix = rollAffix(q), pop = 0.5 }
    G.nextId = G.nextId + 1
    if star >= 3 then u.awakenReady = true; G.pendingAwaken:push(u) end
    G.stats.summoned = G.stats.summoned + 1
    G.stats.maxStar = max(G.stats.maxStar, star)
    G.stats.maxQ = max(G.stats.maxQ, q)
    local s = autoPlace(u)
    if s then FX.summon(u, s); return { nu = u } end
    -- 满员：新单位品质更高时，顶替一个品质更低、星级不高于它的未转职单位，被顶替的单位转成经验
    local victim = allUnits()
        :filter(function(x)
            local slot = findSlot(x)
            return not x.branch and not x.awakenReady and (x.q or 0) < q and (star >= 3 or x.star <= star)
                and not (slot and slot.t == 'f' and isSealed and isSealed(slot.i))
        end)
        :sort(function(a, b)
            local r = (a.q or 0) - (b.q or 0)
            if r ~= 0 then return r end
            return a.pts - b.pts
        end)[0]
    if victim then
        local vs = findSlot(victim)
        setSlot(vs, u); FX.summon(u, vs)
        return js.assign({ nu = u, displaced = victim }, feedAway(victim))
    end
    return js.assign({ nu = u }, feedAway(u))
end

-- ---------- 老虎机 ----------
function rollSymbol()
    local keys = G.symW.keys
    local w = {}
    for i = 0, #keys - 1 do w[keys[i]] = G.symW[keys[i]] end
    w.S = w.S + G.luck * LUCK_BONUS + ((G.mx and G.mx.star) or 0)
    local tot = 0
    for i = 0, #keys - 1 do tot = tot + w[keys[i]] end
    local r = js.random() * tot
    for i = 0, #keys - 1 do
        r = r - w[keys[i]]
        if r < 0 then return keys[i] end
    end
    return keys[0]
end
function rollGrid() return js.from(9, function() return rollSymbol() end) end
function evalGrid(g)
    local wins = A()
    LINES:forEach(function(L, li)
        local nw = L:map(function(i) return g[i] end):filter(function(x) return x ~= 'S' end)
        local sym = nil
        if #nw == 0 then sym = 'S'
        elseif nw:every(function(x) return x == nw[0] end) then sym = nw[0] end
        if sym then wins:push({ li = li, sym = sym }) end
    end)
    return wins
end
-- 九格大奖：九个格子是同一种图标（★ 照常可以替代），全是 ★ 也算
function jackpotSym(g)
    local nw = g:filter(function(x) return x ~= 'S' end)
    if #nw == 0 then return 'S' end
    if nw:every(function(x) return x == nw[0] end) then return nw[0] end
    return nil
end
function hasSuper(cls) return allUnits():some(function(u) return isSup(u) and u.cls == cls end) end
-- 召唤超凡角色：自带技能、不用转职；满员时顶掉价值最低的非超凡单位，被顶掉的转成经验
function summonSuper(cls)
    local u = { id = G.nextId, cls = cls, star = 3, q = Q_SUP, pts = STAR_PTS[3], affix = rollAffix(Q_SUP), pop = 0.5, branch = SUPER_OF[cls] }
    G.nextId = G.nextId + 1
    G.stats.summoned = G.stats.summoned + 1; G.stats.maxStar = 3; G.stats.maxQ = max(G.stats.maxQ, Q_SUP)
    local r = { nu = u }
    local s = autoPlace(u)
    if not s then
        local victim = allUnits():filter(function(x)
            local slot = findSlot(x)
            return not isSup(x) and not (slot and slot.t == 'f' and isSealed and isSealed(slot.i))
        end)
            :sort(function(a, b)
                local d = b2n(not not a.branch) - b2n(not not b.branch)
                if d ~= 0 then return d end
                d = (a.q or 0) - (b.q or 0)
                if d ~= 0 then return d end
                return a.pts - b.pts
            end)[0]
        -- 满员且没有可顶替的目标（例如剩下的单位都在封印格上）时，victim 为 nil。
        -- 与 summon 一致：兜底把新单位喂成经验，而不是对 nil 槽位调用 setSlot。
        if victim then
            s = findSlot(victim); setSlot(s, u)
            r.displaced = victim; js.assign(r, feedAway(victim))
        else
            -- 没有可顶替的槽位：直接喂成经验，跳过特效（slotPos 不接受 nil 槽位）
            js.assign(r, feedAway(u))
            return r
        end
    end
    FX.superSummon(u, s)
    return r
end
-- 九格大奖：召唤这个兵种的超凡角色。已经有了就改给本局另一个还没有的兵种；三个都有了，退回传说 ★★★
function applyJackpot(sym)
    G.stats.jackpots = G.stats.jackpots + 1
    local free = G.squad:filter(function(c) return not hasSuper(c) end)
    local want
    if sym == 'S' then want = (#free > 0) and pick(free) or pick(G.squad) else want = SYM_CLASS[sym] end
    if not hasSuper(want) then return summonSuper(want) end
    if #free > 0 then return js.assign(summonSuper(pick(free)), { redirect = want }) end
    return js.assign(summon(want, 3, Q_MAX), { fallback = true })
end
function applyWin(w)
    if w.sym == 'S' then return summon(pick(G.squad), 2, rollQuality(1)) end
    return summon(SYM_CLASS[w.sym], 1, rollQuality(0))
end
function afterSpin(hits)
    if T(hits) then G.luck = 0 else G.luck = min(OR(G.luckMax, 3), G.luck + 1) end
end
function instantSpin() -- 供测试/模拟使用
    paySpin()
    G.stats.spins = G.stats.spins + 1
    beforeSpin()
    local g = afterRollGrid(rollGrid())
    local jack = jackpotSym(g)
    if jack then applyJackpot(jack); afterSpin(1); return { jack = jack } end
    local wins = evalGrid(g)
    wins:forEach(function(w) applyWin(w) end); afterSpin(#wins)
    return { wins = wins }
end

-- ---------- 战斗 ----------
function makeEnt(side, o)
    local ent = { side = side, hp = o.maxHp, cdLeft = 0.15 + js.random() * o.cd * 0.6, target = nil, flash = 0,
        atkT = 9, ready = false, knock = 0, dead = false, deadT = 0, face = (side == 'p') and 1 or -1, moving = false, phase = js.random() * 6,
        energy = o.skill and ((side == 'e') and 40 or floor(js.random() * 30)) or 0, stun = 0, shield = 0, burn = nil, dr = 0, skill = nil }
    for k, v in pairs(o) do ent[k] = v end
    -- JS 中 o 显式给出 skill: null 时会覆盖默认值（这里默认值本来就是 nil）
    return ent
end
function playerEnt(u, i)
    local p, st, C = fPos(i), unitStats(u), CLASSES[u.cls]
    local ent = makeEnt('p', { x = p.x, y = p.y, maxHp = st.hp, atk = st.atk, cd = st.cd, crit = st.crit, leech = st.leech,
        range = st.range, speed = st.speed, r = C.r, proj = st.proj, splash = C.splash or 0, sprite = C.sprite,
        cls = u.cls, star = u.star, branch = u.branch or nil, skill = st.skill, dr = st.dr, berserk = st.berserk,
        burnOnHit = st.burnOnHit, extra = st.extra, critMul = st.critMul, slowHit = st.slowHit, chainHit = st.chainHit, unit = u,
        q = u.q or 0 })
    js.assign(ent, st.fx) -- 高品质路线的机制开关：反伤、剧毒、闪避、不灭……
    if isSup(u) then ent.sup = true; ent.tall = true -- 超凡：20 像素高的形象，血条和徽记往上挪
    elseif u.branch then ent.mid = true end -- 转职形象 18 像素高，血条和徽记往上挪 2 像素
    if ent.killStack then ent.baseAtk = ent.atk; ent.baseCd = ent.cd; ent.kills = 0 end
    if st.fullEnergy then ent.energy = 100 end
    runHooks('pent', ent, u, i)
    ent.chargeMul = min(1.4, ent.chargeMul or 1)
    return ent
end
function waveList(w)
    local list, Df = waveDef(w):slice(), curDiff()
    local n = (w >= 6) and Df.extra or ((w >= 3) and min(1, Df.extra) or 0) -- 第 3 波起加敌人，第 6 波起加满
    if T(n) then
        local pool = list:filter(function(t) return not isBossT(t) end)
        for i = 0, n - 1 do list:push(pool[i % #pool]) end
    end
    return list
end
function waveLineup(w)
    local list, out, used, Df = waveList(w), A(), js.Set(), curDiff()
    local function isRanged(t) return not not (ENEMIES[t].proj or (ENEMIES[t].fx and ENEMIES[t].fx.inert)) end
    local bt = list:find(isBossT)
    if bt then used:add('2,1'); used:add('3,1'); out:push({ type = bt, x = 222, y = 72 }) end
    local function place(t, cols)
        for _, c in ipairs(cols) do
            for _, r in ipairs({ 1, 0, 2 }) do
                local k = c .. ',' .. r
                if not used:has(k) then used:add(k); local p = ePos(c, r); out:push({ type = t, x = p.x, y = p.y }); return end
            end
        end
    end
    list:filter(function(t) return not isBossT(t) and not isRanged(t) end):forEach(function(t) place(t, { 0, 1, 2, 3 }) end)
    list:filter(function(t) return not isBossT(t) and isRanged(t) end):forEach(function(t) place(t, { 3, 2, 1, 0 }) end) -- 远程首领只放一次
    if T(Df.elite) and w >= 2 then
        out:forEach(function(e) if not isBossT(e.type) and js.random() < Df.elite then e.elite = true end end)
    end
    return out
end
-- 每一波的阵容（含精英）固定下来，预览与实战一致；输掉重打时阵容不变
function currentLineup()
    if not G.lineup or G.lineup.wave ~= G.wave then G.lineup = { wave = G.wave, list = waveLineup(G.wave) } end
    return G.lineup.list
end
function enemyEnt(e, w)
    local E, Df = ENEMIES[e.type], curDiff()
    local m = waveMult(w) * diffMult(Df, w)
    local hm, am = e.elite and ELITE_HP or 1, e.elite and ELITE_ATK or 1
    local ent = makeEnt('e', { x = e.x, y = e.y, maxHp = round(E.hp * m * hm), atk = round(E.atk * m * am), cd = E.cd,
        crit = 0.05, leech = 0, range = E.range, speed = E.speed, r = E.r, proj = E.proj or nil, splash = E.splash or 0,
        sprite = E.sprite, pal = E.pal or nil, type = e.type, big = not not E.big, skill = E.skill or nil, elite = not not e.elite,
        rage = (E.big and not (E.fx and (E.fx.phases or E.fx.vphases or E.fx.qphases or E.fx.aphases or E.fx.rphases or E.fx.levCycle))) and Df.adds or 0, adds = Df.adds or 0 })
    if E.fx then js.assign(ent, E.fx) end -- 第二章敌人的机制：分裂、自爆、披甲、闪现……
    if ent.blink then ent.blinkT = 1 + js.random() * 0.6 end
    if ent.hook then ent.hookT = 1.6 + js.random() * 0.5 end
    if ent.shift then ent.shiftT = 2 + js.random() * 2 end
    c45InitEnemy(ent) -- 第四、五章敌人的初始状态
    runHooks('ent', ent, e)
    return ent
end
function bossRage(B, e)
    FX.skill(e, '亡灵召唤')
    for i = 0, e.rage - 1 do
        local s = enemyEnt({ type = curCh().rage[i % 2], x = clamp(e.x - 16 + rand(-4, 4), 6, AW - 6),
            y = clamp(e.y + (i - (e.rage - 1) / 2) * 18, 14, FIELD_H - 10) }, G.wave)
        s.cdLeft = 0.6; B.ents:push(s)
        FX.particle(s.x, s.y, '#c06bff', 14, 50, 40, 0.6)
    end
    G.shake = max(G.shake, 0.3)
end
-- ---------- 第二章机制 ----------
function spawnEnemy(B, type, x, y, cd)
    -- 生成计数（定位用）：累计每种类型的生成次数，实体数异常时打印
    SPAWN_COUNT = SPAWN_COUNT or {}
    SPAWN_COUNT[type] = (SPAWN_COUNT[type] or 0) + 1
    local s = enemyEnt({ type = type, x = clamp(x, 6, AW - 6), y = clamp(y, 14, FIELD_H - 10) }, G.wave)
    if cd == nil then s.cdLeft = 0.6 else s.cdLeft = cd end
    B.ents:push(s)
    FX.particle(s.x, s.y, '#ff8a2a', 12, 45, 40, 0.5)
    return s
end
function backmost(B, e) -- 火药桶怪：盯住最后排
    local fs = foesOf(B, e)
    local main = fs:filter(function(o) return not o.minion end)
    return ((#main > 0) and main or fs):sort(function(a, b) return a.x - b.x end)[0] or nil
end
function explode(B, e) -- 火药桶怪自爆
    if e.dead then return end
    e.dead = true; e.hp = 0; e.deadT = 0; e.exploded = true
    for o in of(foesOf(B, e)) do
        if hypot(o.x - e.x, o.y - e.y) <= 20 + o.r then hit(e, o, e.atk * e.bomb, { noLeech = true, noCrit = true }) end
    end
    FX.ring(e.x, e.y, 18, '#ffb03a'); FX.particle(e.x, e.y, '#ff8a2a', 26, 90, 40, 0.6); FX.particle(e.x, e.y, '#ffe14a', 12, 60, 20, 0.5)
    G.shake = max(G.shake, 0.3); Sound.play('die')
end
function shatterArmor(e) -- 黑曜卫士：被控后碎甲
    e.armor = 0; e.pal = ENEMIES[e.type].palBroken; e.pkey = e.type .. ':broken'
    FX.particle(e.x, e.y, '#9a6ad8', 18, 60, 60, 0.6); FX.ring(e.x, e.y, 10, '#c9a6ff'); FX.skill(e, '碎甲')
end
function doBlink(B, e) -- 灰烬刺客：闪现到最脆的单位身后
    local fs = foesOf(B, e)
    local main = fs:filter(function(o) return not o.minion end)
    local prey = ((#main > 0) and main or fs):sort(function(a, b) return a.maxHp - b.maxHp end)[0]
    if not prey then e.blinkT = 2; return end
    FX.particle(e.x, e.y, '#8a8590', 12, 40, 20, 0.5)
    e.x = clamp(prey.x - 10, 6, AW - 6); e.y = prey.y; e.target = prey; e.face = 1; e.backstab = true
    e.cdLeft = min(e.cdLeft, 0.25); e.blinkT = 8
    FX.particle(e.x, e.y, '#ff5a2a', 12, 50, 20, 0.5); FX.skill(e, '闪现')
end
function bossPhase(B, e) -- 熔核巨像的三个阶段
    local f = e.hp / e.maxHp
    if not e.ph1 and f <= 0.6 then -- 熔核护盾：退回熔炉，晶柱存活时无敌
        e.ph1 = true; e.immune = true; e.channel = true; e.chT = 0; e.stun = 0; e.energy = 0
        FX.particle(e.x, e.y, '#ff8a2a', 20, 60, 30, 0.6)
        e.x = 214; e.y = 72
        FX.skill(e, '熔核护盾'); FX.ring(e.x, e.y, 22, '#ffb03a'); G.shake = max(G.shake, 0.35)
        e.pillars = A(A(182, 30), A(182, 114), A(244, 72)):map(function(p) return spawnEnemy(B, 'pillar', p[0], p[1], 0.8) end)
        for o in of(B.ents) do if o.target == e then o.target = nil end end
        return
    end
    if e.channel and e.pillars:every(function(p) return p.dead end) then -- 核心过载
        e.channel = false; e.immune = false; e.stun = max(e.stun, 3)
        applyCurse(e, 5, 0.5, 0)
        FX.skill(e, '核心过载'); FX.ring(e.x, e.y, 26, '#ffffff'); FX.particle(e.x, e.y, '#ffe14a', 30, 90, 40, 0.8)
        G.shake = max(G.shake, 0.4)
    end
    if not e.ph2 and not e.channel and f <= 0.3 then -- 熔核暴走
        e.ph2 = true; e.frenzy = true
        FX.skill(e, '熔核暴走'); FX.ring(e.x, e.y, 24, '#ff4a3a'); G.shake = max(G.shake, 0.3)
        for i = 0, e.adds - 1 do
            spawnEnemy(B, curCh().rage[i % 2], e.x - 16 + rand(-4, 4), e.y + (i - (e.adds - 1) / 2) * 16, 0.6)
        end
    end
    if e.frenzy then e.haste = max(e.haste or 0, 0.1) end
end
function segDist(px, py, x1, y1, x2, y2)
    local vx, vy = x2 - x1, y2 - y1
    local L = vx * vx + vy * vy
    if L == 0 then L = 1 end
    local k = clamp(((px - x1) * vx + (py - y1) * vy) / L, 0, 1)
    return hypot(px - x1 - vx * k, py - y1 - vy * k)
end
function stepHazard(B, f, dt) -- 熔岩池、地裂、毒云与荆棘领域
    f.t = f.t - dt
    if f.kind == 'cloud' then
        f.tick = f.tick - dt
        if f.tick <= 0 then
            f.tick = f.tick + 0.5
            for o in of(B.ents) do
                if not o.dead and o.side ~= f.src.side and hypot(o.x - f.x, (o.y - f.y) * 1.4) <= f.r then
                    addPoison(o, f.src, 1); applySlow(o, 0.6, 0.25)
                end
            end
        end
    end
    if f.kind == 'thornzone' and f.src.dead then f.t = 0 end
    if f.kind == 'lava' then
        f.tick = f.tick - dt
        if f.tick <= 0 then
            f.tick = f.tick + 0.5
            for o in of(foesOf(B, f.src)) do
                if hypot(o.x - f.x, (o.y - f.y) * 1.6) <= f.r then hit(f.src, o, f.src.atk * f.mul, { noCrit = true, noLeech = true, dot = true }) end
            end
        end
    elseif f.kind == 'fissure' and not f.fired and f.t <= f.max - f.warn then
        f.fired = true
        for o in of(foesOf(B, f.src)) do
            if segDist(o.x, o.y, f.x, f.y, f.x2, f.y2) <= f.w + o.r then
                hit(f.src, o, f.src.atk * f.mul, { noLeech = true })
                applyBurn(o, f.src, 3, f.src.atk * 0.3)
            end
        end
        local n = max(1, round(hypot(f.x2 - f.x, f.y2 - f.y) / 5))
        for i = 0, n do
            local k = i / n
            FX.particle(f.x + (f.x2 - f.x) * k, f.y + (f.y2 - f.y) * k, (js.random() < 0.5) and '#ff8a2a' or '#ffe14a', 2, 40, 60, 0.5)
        end
        G.shake = max(G.shake, 0.35); Sound.play('die')
    end
    if f.kind == 'rift' and not f.fired and f.t <= f.max - f.warn then -- 虚空新星
        f.fired = true
        for o in of(foesOf(B, f.src)) do
            if hypot(o.x - f.x, (o.y - f.y) * 1.3) <= f.r + o.r then hit(f.src, o, f.src.atk * f.mul, { noLeech = true }) end
        end
        FX.ring(f.x, f.y, f.r, '#c06bff'); FX.particle(f.x, f.y, '#8f4bc4', 18, 70, 20, 0.5); FX.particle(f.x, f.y, '#ffffff', 6, 40, 10, 0.4)
        G.shake = max(G.shake, 0.2)
    end
    if f.t <= 0 then f.done = true end
end
-- ---------- 第三章机制 ----------
function doHook(B, e) -- 锁魂钩手：把最后排拽到身前
    local prey = foesOf(B, e):filter(function(o) return not o.minion and not o.anchor end):sort(function(a, b) return a.x - b.x end)[0]
    if not prey or prey.x > e.x - 24 then e.hookT = 2; return end
    local n = max(2, round(hypot(prey.x - e.x, prey.y - e.y) / 4))
    for i = 0, n do
        local k = i / n
        FX.parts:push({ x = e.x + (prey.x - e.x) * k, y = e.y - 4 + (prey.y - e.y) * k, vx = 0, vy = 0, g = 0, life = 0.35, max = 0.35, color = (i % 2 ~= 0) and '#8d9ab2' or '#c06bff', size = 1 })
    end
    prey.x = clamp(e.x - (e.r + prey.r + 2), 6, AW - 6); prey.y = e.y; prey.stun = max(prey.stun, 0.6); prey.target = e
    e.target = prey; e.hookT = 9; FX.skill(e, '锁魂钩')
end
function charm(B, src, dur) -- 幻惑女巫：攻击最高的单位倒戈
    local t = foesOf(B, src):filter(function(o) return not o.minion and not T(o.charmed) and not o.ccImmune end):sort(function(a, b) return b.atk - a.atk end)[0]
    if not t then return end
    t.side = src.side; t.charmed = dur; t.target = nil
    for o in of(B.ents) do if o.target == t then o.target = nil end end
    FX.skill(t, '倒戈'); FX.ring(t.x, t.y, 10, '#ff6ad5'); FX.particle(t.x, t.y - 6, '#ff6ad5', 12, 40, -10, 0.6)
end
function uncharm(B, e)
    e.side = 'p'; e.charmed = 0; e.target = nil; e.cdLeft = max(e.cdLeft, 0.2)
    for o in of(B.ents) do if o.target == e then o.target = nil end end
    FX.particle(e.x, e.y - 6, '#ff6ad5', 8, 30, 10, 0.4)
end
function stepShift(e, dt) -- 相位行者：隐身 1.5 秒 / 现形 4 秒
    e.shiftT = e.shiftT - dt
    if e.shiftT > 0 then return end
    e.shifted = not e.shifted; e.immune = e.shifted; e.shiftT = e.shifted and 1.5 or 4
    FX.particle(e.x, e.y, '#6ef0ff', 10, 40, 10, 0.4)
end
function spawnMirror(B, boss, o, i, n) -- 虚空之主复制出的虚影：60% 属性，只会普攻
    local m = makeEnt('e', { x = clamp(boss.x - 20, 6, AW - 6), y = clamp(boss.y + (i - (n - 1) / 2) * 22, 14, FIELD_H - 10),
        maxHp = round(o.maxHp * 0.6), atk = round(o.atk * 0.6), cd = o.cd, crit = o.crit, leech = 0, range = o.range, speed = OR(o.speed, 20),
        r = o.r, proj = o.proj, splash = o.splash, sprite = o.sprite, cls = o.cls, star = o.star, branch = o.branch, critMul = o.critMul, tall = o.tall, mid = o.mid,
        type = 'voidmirror', vcopy = true, ghost = true })
    m.cdLeft = 0.6; B.ents:push(m)
    FX.particle(m.x, m.y, '#c06bff', 16, 50, 20, 0.6); FX.ring(m.x, m.y, 9, '#c06bff')
    return m
end
function voidPhase(B, e, dt) -- 虚空之主的阶段
    local f = e.hp / e.maxHp
    if not e.ph1 and f <= 0.66 then -- 虚空镜像
        e.ph1 = true
        FX.skill(e, '虚空镜像'); FX.ring(e.x, e.y, 22, '#c06bff'); G.shake = max(G.shake, 0.3)
        local list = foesOf(B, e):filter(function(o) return not o.minion and not T(o.charmed) end):sort(function(a, b) return b.atk - a.atk end):slice(0, max(1, e.adds))
        list:forEach(function(o, i, arr) spawnMirror(B, e, o, i, #arr) end)
    end
    if not e.ph2 and f <= 0.33 then -- 虚空坍缩：吟唱 6 秒，护盾被打破就中断
        e.ph2 = true; e.cast = 6; e.stun = 0; e.energy = 0; e.shield = round(e.maxHp * 0.2)
        FX.skill(e, '虚空坍缩'); FX.ring(e.x, e.y, 24, '#c06bff'); G.shake = max(G.shake, 0.3)
    end
    if (e.cast or 0) > 0 then
        if e.shield <= 0 then
            e.cast = 0; e.stun = 3; applyCurse(e, 5, 0.5, 0)
            FX.skill(e, '吟唱打断'); FX.ring(e.x, e.y, 26, '#ffffff'); FX.particle(e.x, e.y, '#e0b0ff', 30, 90, 40, 0.8); G.shake = max(G.shake, 0.4)
        else
            e.cast = e.cast - dt
            if e.cast <= 0 then
                e.cast = 0; e.shield = 0; e.stun = 0; e.frenzy = true
                for o in of(foesOf(B, e)) do
                    hit(e, o, o.maxHp * 0.45, { noCrit = true, noLeech = true })
                    if not o.dead then o.stun = max(o.stun, 1) end
                end
                FX.skill(e, '坍缩'); B.tint = { t = 0.8, max = 0.8, rgb = '90,40,160' }; G.shake = max(G.shake, 0.6)
            end
        end
    end
    if e.frenzy then e.haste = max(e.haste or 0, 0.1) end
end
function startBattle()
    local ents = A()
    G.form:forEach(function(u, i) if u then ents:push(playerEnt(u, i)) end end)
    currentLineup():forEach(function(e) ents:push(enemyEnt(e, G.wave)); G.seen:add(e.type) end)
    local B = { ents = ents, projs = A(), fields = A(), t = 0, over = false, result = nil, endT = 0, aura = 0, tint = nil }
    G.battle = B
    local ps = ents:filter(function(e) return e.side == 'p' end)
    local h = max(0, js.maxOf(ps:map(function(e) return e.openHaste or 0 end))) -- 战旗手：开战全队狂热
    if T(h) then ps:forEach(function(e) e.haste = max(e.haste or 0, h) end) end
    ps:forEach(function(e) if e.openTurret then deployTurret(B, e) end end) -- 机关师：开战先放一座炮塔
    ps:forEach(function(e) if e.openSprout then deploySprout(B, e) end end) -- 荆棘母株：开战先种一株花苗
    G.phase = 'battle'; G.sel = nil; G.slot.show = A()
    runHooks('start', B)
end
function isMeleeEnt(e) return not e.proj and e.range <= 12 end
function nearestFoe(e, alive)
    local best, bd = nil, 1e9
    local melee = isMeleeEnt(e)
    for o in of(alive) do
        if not (o.side == e.side or o.dead or o.untargetable) then
            local d = hypot(o.x - e.x, (o.y - e.y) * 1.3) + (o.immune and 400 or 0)
            if melee then d = d + 14 * min(4, o.nAtk or 0) end
            if d < bd then bd = d; best = o end
        end
    end
    if best and melee then best.nAtk = (best.nAtk or 0) + 1 end
    return best
end
function gainEnergy(e, n) if (e.silenced or 0) > 0 then return end if e.skill then e.energy = min(100, e.energy + n * min(1.4, OR(e.chargeMul, 1))) end end
function healAmt(t, amt)
    if t.dead or amt <= 0 or (t.wither or 0) > 0 then return 0 end
    local B = G.battle --[[@as table<string, any>?]]
    if B and B.healMul then amt = amt * B.healMul end
    if t.side == 'p' and G.healBonus then amt = amt * (1 + G.healBonus) end
    local before = t.hp
    t.hp = min(t.maxHp, t.hp + amt)
    local got = t.hp - before
    if got >= 1 then FX.heal(t, got) end
    return got
end
function healLowest(B, src, amt)
    local t = alliesOf(B, src):filter(function(o) return o.hp < o.maxHp end):sort(function(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end)[0]
    if t then healAmt(t, amt) end
end
function hit(src, t, base, o)
    if t.dead or t.untargetable then return 0 end
    o = o or {}
    if (t.inv or 0) > 0 then if not T(o.dot) then FX.burst(t.x, t.y - 4, '#fff3b0', 3) end return 0 end -- 不灭战魂的无敌
    if t.immune then if not T(o.dot) then FX.burst(t.x, t.y - 6, t.shifted and '#6ef0ff' or '#ffb03a', 3) end return 0 end -- 熔核护盾、相位隐身
    local dodge = (t.dodge or 0) + (((t.dodgeT or 0) > 0) and 0.2 or 0)
    if dodge > 0 and not T(o.dot) and not o.reflect and js.random() < dodge then FX.miss(t); return 0 end
    if (t.evadeT or 0) > 0 and not T(o.dot) and not o.reflect then FX.miss(t); return 0 end
    if c45Block(src, t, o) then return 0 end -- 神殿哨卫的圣盾
    local B0 = G.battle
    if B0 and not o.shared and not T(o.dot) and not t.guardShare and not t.minion then
        for g in of(B0.ents) do
            if not g.dead and g.side == t.side and T(g.guardShare) and g ~= t and hypot(g.x - t.x, g.y - t.y) <= 34 then
                hit(src, g, base * g.guardShare, { noCrit = true, noLeech = true, shared = true, reflect = true })
                base = base * (1 - g.guardShare)
                break
            end
        end
    end
    local crit = (not not o.forceCrit) or (not o.noCrit and js.random() < src.crit)
    local mul = crit and OR(src.critMul, 2) or 1
    if T(src.execBonus) and not T(o.dot) and t.hp < t.maxHp * 0.5 then mul = mul * (1 + src.execBonus) end -- 猎魔人
    if t.curse then mul = mul * (1 + t.curse.vuln) end -- 诅咒：易伤
    mul = mul * c45DmgMul(src, t, o) -- 审判官
    if T(src.vsShield) and t.shield > 0 then mul = mul * (1 + src.vsShield) end
    if (t.holeT or 0) > 0 then mul = mul * (1 + (t.holeVuln or 0)) end
    if (t.surfaceT or 0) > 0 then mul = mul * 1.3 end
    if B0 and B0.burnMul and o.dot == 'burn' then mul = mul * B0.burnMul end
    if src.side == 'p' and not src.minion and G.dmgVsBig and (t.big or t.elite) then mul = mul * (1 + G.dmgVsBig) end
    if src.curse and not T(o.dot) then mul = mul * (1 - src.curse.weak) end -- 诅咒：虚弱
    local B = G.battle --[[@as table<string, any>?]]
    local dr = min(0.8, (t.dr or 0) + (t.armor or 0) + (((t.giant or 0) > 0) and GIANT_DR or 0) + (t.guard and t.guard.dr or 0) + ((t.side == 'p' and B) and B.aura or 0) + c45AuraDr(B, t))
    local dmg = max(1, round(base * mul * (1 - dr)))
    local absorbed = 0
    if t.shield > 0 then absorbed = min(t.shield, dmg); t.shield = t.shield - absorbed end
    t.hp = t.hp - (dmg - absorbed); t.flash = 0.1
    if not T(o.dot) and not t.big and not t.anchor and src ~= t then t.knock = 0.08; t.knockDir = (t.x >= src.x) and 1 or -1 end -- 受击后仰
    if not o.noLeech and not src.dead then
        local L = (src.leech or 0) + ((src.berserk and src.hp < src.maxHp / 2) and 0.2 or 0) + (((src.frenzyT or 0) > 0) and 0.3 or 0)
        if T(L) then healAmt(src, dmg * L) end
    end
    if t.skill and t.side == 'p' and not T(o.dot) then gainEnergy(t, 6) end
    if T(src.drain) and o.melee and t.skill and not t.dead then -- 噬能幽影
        t.energy = max(0, t.energy - src.drain); FX.particle(t.x, t.y - 6, '#6ef0ff', 5, 30, -10, 0.4)
    end
    if crit and T(src.critEnergy) and not src.dead then gainEnergy(src, src.critEnergy) end -- 星辰射手
    if T(src.healHit) and not T(o.dot) and not src.dead and B then healLowest(B, src, dmg * src.healHit) end -- 圣疗师
    FX.damage(t, dmg, crit, absorbed >= dmg, o.dot)
    if t.phases and not t.ph1 and t.hp < t.maxHp * 0.6 then t.hp = floor(t.maxHp * 0.6) end -- 巨像一定会进入护盾阶段
    if t.vphases then -- 虚空之主的两个阶段都不会被跳过
        if not t.ph1 and t.hp < t.maxHp * 0.66 then t.hp = floor(t.maxHp * 0.66)
        elseif not t.ph2 and t.hp < t.maxHp * 0.33 then t.hp = floor(t.maxHp * 0.33) end
    end
    c45AfterHit(src, t, o) -- 巨猿狂怒、冰壳、首领阶段保护
    if t.onHurt then t.onHurt(t) end
    if t.hp <= 0 then
        if t.undying and not t.undyingUsed then -- 不灭战魂：每场一次
            t.undyingUsed = true; t.hp = round(t.maxHp * 0.5); t.inv = 2.5; t.stun = 0; FX.undying(t)
        elseif T(t.reviveOnce) and not t.reviveUsed then
            t.reviveUsed = true; t.hp = round(t.maxHp * t.reviveOnce); t.stun = 0; t.inv = 0.6; FX.undying(t)
        else
            if T(t.charmed) then t.side = 'p'; t.charmed = 0 end -- 倒戈中阵亡的单位仍算我方
            t.hp = 0; t.dead = true; t.deadT = 0; FX.death(t); onDeath(t, src)
        end
    end
    if o.melee and T(t.thorns) and not src.dead then hit(t, src, dmg * t.thorns, { noCrit = true, noLeech = true, reflect = true }) end -- 复仇者反伤
    if o.ranged and T(t.thorns) and not src.dead and src ~= t then hit(t, src, dmg * t.thorns * 0.5, { noCrit = true, noLeech = true, reflect = true }) end
    if t.thornAura and not T(o.dot) and not o.reflect and not src.dead and src ~= t then hit(t, src, dmg * t.thornAura.v, { noCrit = true, noLeech = true, reflect = true }) end
    if B0 and not T(o.dot) and not o.reflect and not src.dead and src.side ~= t.side then
        for f in of(B0.fields) do
            if f.kind == 'thornzone' and f.src.side == t.side and not f.src.dead and hypot(src.x - f.x, src.y - f.y) <= f.r then
                hit(f.src, src, dmg * f.mul, { noCrit = true, noLeech = true, reflect = true }); FX.burst(src.x, src.y - 4, '#ff6a8a', 3)
                break
            end
        end
    end
    if T(t.shock) and o.melee and not src.dead and src ~= t then
        hit(t, src, t.atk * t.shock, { noCrit = true, noLeech = true, reflect = true }); FX.bolt(t.x, t.y - 3, src.x, src.y - 3)
        if not src.dead and js.random() < 0.3 then src.stun = max(src.stun, 0.4) end
    end
    if T(t.mirrorArmor) and not o.melee and not T(o.dot) and not o.reflect and not src.dead and src ~= t then -- 镜甲守卫：反弹远程伤害
        hit(t, src, min(dmg * t.mirrorArmor, src.maxHp * 0.08), { noCrit = true, noLeech = true, reflect = true }); FX.burst(t.x, t.y - 6, '#9ff6ff', 3)
    end
    return dmg
end
function execute(src, t) -- 斩杀
    if t.dead then return end
    if T(t.charmed) then hit(src, t, src.atk * 2.8); return end -- 倒戈的自己人不会被斩杀
    t.hp = 0; t.dead = true; t.deadT = 0
    FX.float(t.x, t.y - 14, '!!', '#ff4a4a'); FX.slash(t.x, t.y); FX.death(t)
    onDeath(t, src)
end
function onDeath(t, src)
    local B = G.battle --[[@as table<string, any>?]]
    if not B then return end
    runHooks('death', t, src, B)
    if t.split and not t.splitDone then -- 熔岩史莱姆：分裂
        t.splitDone = true
        for i = 0, 1 do spawnEnemy(B, t.split, t.x + rand(-3, 3), t.y + ((i ~= 0) and 7 or -7), 0.5) end
    end
    c45OnDeath(B, t, src) -- 冰棺、殉道
    if t.poison and t.poison.src and t.poison.src.contagion and t.poison.n > 0 then
        local P = t.poison
        for o in of(B.ents) do
            if not o.dead and o ~= t and o.side == t.side and hypot(o.x - t.x, o.y - t.y) <= 30 then
                addPoison(o, P.src, P.n); FX.particle(o.x, o.y, '#b0e05a', 5, 30, -10, 0.5)
            end
        end
    end
    if t.deathPool then
        B.fields:push({ kind = 'cloud', x = t.x, y = t.y, r = 18, t = 4, max = 4, tick = 0.5, src = t, foe = true })
        FX.particle(t.x, t.y, '#9be36b', 14, 40, 20, 0.6)
    end
    if t.deathCurse then -- 凋零信徒：死亡瘴气
        for o in of(foesOf(B, t)) do if hypot(o.x - t.x, o.y - t.y) <= 26 then applyCurse(o, 5, 0.3, 0.3) end end
        FX.ring(t.x, t.y, 22, '#9be36b'); FX.particle(t.x, t.y, '#7a4a8a', 20, 50, 10, 0.8)
    end
    if src and src.killStack and not src.dead and src.side ~= t.side and src.kills < 8 then -- 征服者叠层
        src.kills = src.kills + 1
        src.atk = round(src.baseAtk * (1 + 0.15 * src.kills)) + (src.gemN and round(src.gemBase * src.killAtk) * src.gemN or 0)
        src.cd = src.baseCd / (1 + 0.1 * src.kills)
        src.hp = min(src.maxHp, src.hp + src.maxHp * 0.15)
        FX.particle(src.x, src.y - 4, '#ff4a3a', 8, 40, 30, 0.5)
    end
    if src and T(src.killHeal) and not src.dead and src.side ~= t.side then healAmt(src, src.maxHp * src.killHeal) end -- 饿虎：击杀回血
    if t.side == 'e' then
        for L in of(B.ents) do -- 巫妖王：亡者复生
            if not (L.dead or not T(L.deathRaise) or js.random() >= L.deathRaise or #minionsOf(B, L) >= 5) then
                spawnBone(B, L, t.x, t.y)
                break
            end
        end
    end
end
function applyBleed(t, src, dur, dps) if not t.dead then t.bleed = { t = dur, dps = dps, tick = 0.5, src = src } end end -- 流血：每 0.5 秒结算一次，不叠层，重新命中刷新时间
function applyBurn(t, src, dur, dps) if not t.dead then t.burn = { t = dur, dps = dps, tick = 0.5, src = src } end end
function applySlow(t, dur, amt)
    if t.dead then return end
    t.slow = { t = max(dur, t.slow and t.slow.t or 0), amt = max(amt, t.slow and t.slow.amt or 0) }
end
function addPoison(t, src, n)
    if t.dead then return end
    local P = t.poison
    if not P then P = { n = 0, t = 0, tick = 0.5, src = src, per = 0 }; t.poison = P end
    P.n = min(8, P.n + n); P.t = 4; P.src = src; P.per = max(P.per, src.atk * 0.15)
end
function applyCurse(t, dur, vuln, weak)
    if t.dead then return end
    local c = t.curse
    t.curse = { t = max(dur, c and c.t or 0), vuln = max(vuln, c and c.vuln or 0), weak = max(weak, c and c.weak or 0) }
end
function cleanse(o, full)
    if o.dead then return end
    o.stun = 0; o.poison = nil; o.burn = nil; o.bleed = nil; o.curse = nil; o.slow = nil
    if full then
        o.wither = 0; o.root = 0; o.infect = nil
        o.chill = nil; o.silenced = 0
        if T(o.charmed) and G.battle then uncharm(G.battle, o) end
    end
    FX.ring(o.x, o.y, 8, '#ffffff'); FX.particle(o.x, o.y - 4, '#e6f6ff', 5, 30, -10, 0.4)
end
function procHit(p, o) -- 投射物命中后的附加效果
    if o.dead then return end
    if p.burn then applyBurn(o, p.src, p.burn.t, p.burn.dps) end
    if p.slow then applySlow(o, p.slow.t, p.slow.amt) end
    if T(p.stunHit) then o.stun = max(o.stun, p.stunHit) end
    if T(p.poison) then addPoison(o, p.src, p.poison) end
    if p.curse then applyCurse(o, p.curse.t, p.curse.vuln, p.curse.weak) end
    if T(p.chill) then c45AddChill(o, p.chill) end -- 寒霜
end
function nearestOther(B, src, x, y, maxD, skip)
    local best, bd = nil, maxD
    for o in of(B.ents) do
        if not (o.dead or o.untargetable or o.side == src.side or (skip and skip:has(o))) then
            local d = hypot(o.x - x, o.y - y)
            if d < bd then bd = d; best = o end
        end
    end
    return best
end
function foesOf(B, e) return B.ents:filter(function(o) return not o.dead and not o.untargetable and o.side ~= e.side end) end
function alliesOf(B, e) return B.ents:filter(function(o) return not o.dead and o.side == e.side end) end
function minionsOf(B, e) return B.ents:filter(function(o) return not o.dead and o.owner == e end) end
SLOW_PROJ = js.Set(A('orb', 'dark', 'arcane', 'frost', 'frostbig', 'holy', 'prism', 'fireball', 'lavaball', 'bloodorb', 'sunfire'))
BASIC_HIT = { ranged = true }
PIERCE_BURST = {} -- 贯穿弹命中时的爆点颜色（按弹种，第十二次更新的剑气 / 月箭用）
function shoot(B, e, t, kind, extra)
    local bo = bowMuzzle(e)
    local p = { x = bo and bo.x or (e.x + e.face * 5), y = bo and bo.y or (e.y - 3), tgt = t, tx = t and t.x or 0, ty = t and (t.y - 3) or 0, kind = kind,
        speed = SLOW_PROJ:has(kind) and 95 or 150, src = e, mul = 1, splash = 0, splashMul = 0.6, area = false, burn = nil, delay = 0,
        done = false, ang = 0 }
    if extra then
        for k, v in pairs(extra) do p[k] = v end
        -- extra 里显式为 null 的字段（burn/slow/curse）在 Lua 里本来就是 nil
    end
    B.projs:push(p)
    return p
end
function splashDmg(B, src, x, y, rad, dmg, except)
    for o in of(B.ents) do
        if not o.dead and o.side ~= src.side and o ~= except and hypot(o.x - x, o.y - y) <= rad then hit(src, o, dmg) end
    end
end
function attack(B, e, t)
    if e.proj then
        local burn = e.burnOnHit and { t = 2, dps = e.atk * 0.25 } or nil
        local slow = T(e.slowHit) and { t = 2, amt = e.slowHit } or nil
        local chain = e.chainHit or 0
        if e.elemHit then -- 大魔导师：普攻随机元素
            local k = floor(js.random() * 3)
            if k == 0 then burn = { t = 2, dps = e.atk * 0.3 } elseif k == 1 then slow = { t = 2, amt = 0.35 } else chain = 1 end
        end
        shoot(B, e, t, e.proj, { basic = true, splash = e.splash, burn = burn, slow = slow, chain = chain, poison = (e.poisonHit or 0) + (((e.venomT or 0) > 0) and 1 or 0), ricochet = e.ricochet or 0,
            curse = T(e.curseHit) and { t = 3, vuln = e.curseHit, weak = 0 } or nil, chill = e.chillHit or 0 })
        if T(e.extra) and js.random() < e.extra then shoot(B, e, t, e.proj, { basic = true, delay = 0.1, mul = 0.7 }) end
        FX.sound('shoot')
    else
        if T(e.bomb) then explode(B, e); return end -- 火药桶怪：贴身就炸
        strikeAt(e)
        local giant, bs = (e.giant or 0) > 0, e.backstab and 2 or 1 -- 灰烬刺客：闪现后第一击双倍
        e.backstab = false
        hit(e, t, e.atk * (giant and GIANT_ATK or 1) * bs, { melee = true })
        if T(e.bleedHit) and not t.dead and js.random() < e.bleedHit then applyBleed(t, e, 3, e.atk * 0.45) end -- 猛虎：普攻流血
        if (e.venomT or 0) > 0 and not t.dead then addPoison(t, e, 1) end
        if T(e.witherHit) and not t.dead then t.wither = max(t.wither or 0, e.witherHit) end
        if T(e.rootHit) and not t.dead then t.root = max(t.root or 0, e.rootHit) end
        if giant then -- 泰坦化身：每一击震地
            for o in of(foesOf(B, e)) do if o ~= t and hypot(o.x - t.x, o.y - t.y) <= 22 then hit(e, o, e.atk * 0.8, { noLeech = true }) end end
            for o in of(foesOf(B, e)) do if hypot(o.x - t.x, o.y - t.y) <= 22 then o.stun = max(o.stun, 0.4) end end
            FX.ring(t.x, t.y, 18, '#ffa53a'); FX.particle(t.x, t.y + 6, '#8a7a62', 10, 50, 120, 0.4)
            G.shake = max(G.shake, 0.12)
        end
        if T(e.splash) then splashDmg(B, e, t.x, t.y, e.splash, e.atk * 0.5, t); FX.burst(t.x, t.y, '#ff7b5a', 8) end
    end
end
function tryAttack(B, e, t)
    e.atkT = 0; e.atkTx = t.x; e.atkTy = t.y
    if e.skill and e.energy >= 100 and not T(e.charmed) then
        e.energy = 0; e.atkBig = true; e.atkFx = false; castSkill(B, e, t)
        if T(e.skillHaste) then e.haste = max(e.haste or 0, e.skillHaste) end
        return
    end
    e.atkBig = false; e.atkFx = true
    attack(B, e, t)
    swingFx(e)
    if e.skill then gainEnergy(e, SKILLS[e.skill].charge) end
end
function strikeAt(e) e.atkT = 0; e.atkFx = true end -- 近战出手：播放挥砍 / 突刺 / 爪击的轨迹

-- ---------- 召唤物 ----------
function spawnMinion(B, o)
    local base = { crit = 0.05, leech = 0, splash = 0, proj = nil, r = 5, minion = true, star = 0 }
    for k, v in pairs(o) do base[k] = v end
    local m = makeEnt('p', base)
    m.x = clamp(m.x, 6, AW - 6); m.y = clamp(m.y, 14, FIELD_H - 10); m.cdLeft = 0.4
    B.ents:push(m)
    return m
end
function spawnBone(B, owner, x, y) -- 巫妖王的冰霜亡骨
    local m = spawnMinion(B, { x = x, y = y, owner = owner, maxHp = round(owner.maxHp * 0.8), atk = round(owner.atk * 0.75), cd = 0.9,
        range = 8, speed = 24, mspr = 'skeleton', mpal = BRPAL.lichbone, mkey = 'lichbone' })
    FX.particle(m.x, m.y, '#6ef0ff', 16, 50, 40, 0.6)
    return m
end
function deployTurret(B, e) -- 机关师的弩炮塔：不会移动
    local n = #minionsOf(B, e)
    local m = spawnMinion(B, { x = e.x - 10, y = e.y + ((n % 2 ~= 0) and 18 or -18), owner = e, maxHp = round(e.maxHp * 0.8),
        atk = round(e.atk * 0.5), cd = 0.4, crit = e.crit, range = 84, speed = 0, proj = 'arrow', anchor = true,
        mspr = 'turret', mpal = nil, mkey = 'turret' })
    FX.particle(m.x, m.y, '#ffb04a', 14, 50, 60, 0.5)
    return m
end
function spawnClone(B, e, i) -- 影舞者的影分身
    local m = spawnMinion(B, { x = e.x + rand(-6, 6), y = e.y + ((i ~= 0) and 14 or -14), owner = e, maxHp = round(e.maxHp * 0.5),
        atk = round(e.atk * 0.75), cd = e.cd, crit = e.crit, range = e.range, speed = e.speed, proj = 'arrow', dodge = e.dodge,
        life = 12, ghost = true, mspr = BRANCHES.shadow.sprite, mpal = BRPAL.shadow, mkey = 'clone' })
    FX.particle(m.x, m.y, '#c06bff', 14, 50, 30, 0.5)
    return m
end
function deploySprout(B, e) -- 荆棘母株的毒花苗：不会移动，喷射毒液
    local n = #minionsOf(B, e)
    local m = spawnMinion(B, { x = e.x - 8 - ((n ~= 0) and 4 or 0), y = e.y + ({ 0, -18, 18 })[(n % 3) + 1], owner = e, maxHp = round(e.maxHp * 0.6),
        atk = round(e.atk * 0.6), cd = 0.9, crit = e.crit, range = 60, speed = 0, proj = 'parrow', anchor = true, poisonHit = 1,
        mspr = 'sprout', mpal = { a = '#c4405a', A = '#ff7f9a' }, mkey = 'sprout' })
    FX.particle(m.x, m.y, '#9be36b', 14, 50, 60, 0.5)
    return m
end
function revive(o, frac)
    o.dead = false; o.deadT = 0; o.hp = round(o.maxHp * frac); o.stun = 0; o.burn = nil; o.poison = nil; o.curse = nil; o.bleed = nil; o.guard = nil; o.hot = nil
    o.target = nil; o.cdLeft = 0.3
    o.wither = 0; o.root = 0; o.infect = nil; o.silenced = 0; o.chill = nil
    FX.particle(o.x, o.y, '#fff3b0', 24, 60, 20, 0.8); FX.ring(o.x, o.y, 12, '#ffffff')
end

-- 泰坦化身：巨人化期间的减伤、攻击倍率、攻击间隔倍率（攻击间隔 ×1.15 ≈ 攻速 -13%）
GIANT_DR, GIANT_ATK, GIANT_CD = 0.2, 1.3, 1.15
FRIEND_PUSH = 0.05
function landY(y) return clamp(y + rand(-8, 8), 14, FIELD_H - 10) end

function stepBattle(dt)
    local B = G.battle --[[@as table<string, any>?]]
    if not B then return end
    B.t = B.t + dt
    if B.tint then B.tint.t = B.tint.t - dt; if B.tint.t <= 0 then B.tint = nil end end
    if B.moon then B.moon.t = B.moon.t - dt; if B.moon.t <= 0 then B.moon = nil end end -- 血月降临的天象
    local alive = B.ents:filter(function(e) return not e.dead end)
    -- 规模探针：实体数异常增长会让后面的 O(n²) 分离循环平方级爆炸。正常单波 <= 40。
    if B.ents.n > 120 then
        local cnt, order = {}, {}
        for i = 0, B.ents.n - 1 do
            local e = B.ents[i]
            local k = tostring(e.type or e.sprite) .. (e.minion and '(minion)' or '') .. (e.inert and '(inert)' or '')
            if not cnt[k] then cnt[k] = 0; order[#order + 1] = k end
            cnt[k] = cnt[k] + 1
        end
        local parts = {}
        for _, k in ipairs(order) do parts[#parts + 1] = k .. '×' .. cnt[k] end
        local spawnParts = {}
        if SPAWN_COUNT then
            for k, v in pairs(SPAWN_COUNT) do spawnParts[#spawnParts + 1] = k .. ':' .. v end
        end
        print('[拉杆军团] 实体数异常：ents=' .. B.ents.n .. ' alive=' .. alive.n .. ' wave=' .. tostring(G.wave)
            .. ' 当前：' .. table.concat(parts, ' ') .. ' | 累计生成：' .. table.concat(spawnParts, ' '))
    end
    runHooks('step', B, dt, alive)
    for e in of(alive) do e.nAtk = 0 end
    for e in of(alive) do if e.target and not e.target.dead and isMeleeEnt(e) then e.target.nAtk = (e.target.nAtk or 0) + 1 end end
    B.aura = 0
    for e in of(alive) do if e.side == 'p' and T(e.drAura) then B.aura = max(B.aura, e.drAura) end end -- 炽天使光环
    B.eaura = alive:filter(function(e) return e.side == 'e' and T(e.auraDr) end) -- 圣辉方尖碑
    B.ccAura = 0
    for e in of(alive) do if e.side == 'p' and T(e.ccAura) then B.ccAura = max(B.ccAura, e.ccAura) end end
    for e in of(alive) do
        repeat -- 用 repeat ... until true 模拟 continue
            if e.dead then e.moving = false; break end -- 阶段钩子可能在存活快照建立后吞噬单位
            e.flash = max(0, e.flash - dt); e.atkT = e.atkT + dt; e.ready = false
            if e.knock > 0 then e.knock = e.knock - dt end
            if B.over then e.moving = false; break end
            if e.life ~= nil then -- 限时召唤物（影分身）
                e.life = e.life - dt
                if e.life <= 0 then e.hp = 0; e.dead = true; e.deadT = 0; FX.particle(e.x, e.y, '#8f4bc4', 10, 40, 20, 0.5); break end
            end
            if e.burn then
                e.burn.t = e.burn.t - dt; e.burn.tick = e.burn.tick - dt
                if e.burn.tick <= 0 then e.burn.tick = e.burn.tick + 0.5; hit(e.burn.src, e, e.burn.dps * 0.5, { noCrit = true, noLeech = true, dot = 'burn' }) end
                if e.burn and e.burn.t <= 0 then e.burn = nil end
                if e.dead then break end
            end
            if e.poison then
                local P = e.poison
                P.t = P.t - dt; P.tick = P.tick - dt
                if P.tick <= 0 then P.tick = P.tick + 0.5; hit(P.src, e, P.per * P.n * 0.5, { noCrit = true, noLeech = true, dot = 'poison' }) end
                if P.t <= 0 then e.poison = nil end
                if e.dead then break end
            end
            if e.bleed then -- 猛虎的流血
                e.bleed.t = e.bleed.t - dt; e.bleed.tick = e.bleed.tick - dt
                if e.bleed.tick <= 0 then e.bleed.tick = e.bleed.tick + 0.5; hit(e.bleed.src, e, e.bleed.dps * 0.5, { noCrit = true, noLeech = true, dot = true }) end
                if e.bleed and e.bleed.t <= 0 then e.bleed = nil end
                if e.dead then break end
            end
            if e.hot then -- 繁花：持续回血
                e.hot.t = e.hot.t - dt; e.hot.tick = e.hot.tick - dt
                if e.hot.tick <= 0 then e.hot.tick = e.hot.tick + 1; healAmt(e, e.maxHp * (e.hot.pct or 0.06)) end
                if e.hot.t <= 0 then e.hot = nil end
            end
            if e.guard then e.guard.t = e.guard.t - dt; if e.guard.t <= 0 then e.guard = nil end end -- 熊吼、冬眠：限时减伤
            if T(e.regen) and e.hp < e.maxHp then
                local heal = e.maxHp * e.regen * dt
                if (e.wither or 0) > 0 then heal = 0 end
                if B.healMul then heal = heal * B.healMul end
                if e.side == 'p' and G.healBonus then heal = heal * (1 + G.healBonus) end
                e.hp = min(e.maxHp, e.hp + heal)
            end
            if e.curse then e.curse.t = e.curse.t - dt; if e.curse.t <= 0 then e.curse = nil end end
            if (e.inv or 0) > 0 then e.inv = e.inv - dt end
            if (e.giant or 0) > 0 then e.giant = e.giant - dt; if e.giant <= 0 then e.giant = 0; e.big = false; e.r = 5 end end
            if e.slow then e.slow.t = e.slow.t - dt; if e.slow.t <= 0 then e.slow = nil end end
            if (e.venomT or 0) > 0 then e.venomT = e.venomT - dt end
            if (e.frenzyT or 0) > 0 then e.frenzyT = e.frenzyT - dt end
            if (e.evadeT or 0) > 0 then e.evadeT = e.evadeT - dt end
            if (e.holeT or 0) > 0 then e.holeT = e.holeT - dt end
            if (e.wither or 0) > 0 then e.wither = e.wither - dt end
            if (e.root or 0) > 0 then e.root = e.root - dt end
            if (e.surfaceT or 0) > 0 then e.surfaceT = e.surfaceT - dt end
            if (e.ccShield or 0) > 0 then e.ccShield = e.ccShield - dt; e.stun = 0 end
            if e.thornAura then e.thornAura.t = e.thornAura.t - dt; if e.thornAura.t <= 0 then e.thornAura = nil end end
            if e.infect then stepInfect(B, e, dt); if e.dead then break end end
            if (e.haste or 0) > 0 then e.haste = e.haste - dt end
            if T(e.rage) and not e.raged and e.hp < e.maxHp * 0.5 then e.raged = true; bossRage(B, e) end
            if e.phases then bossPhase(B, e) end -- 熔核巨像
            if e.vphases then voidPhase(B, e, dt) end -- 虚空之主
            if (e.cast or 0) > 0 then e.moving = false; break end -- 虚空坍缩吟唱中
            if e.flight then e.moving = false; e.ready = false; break end -- 技能飞行中（巨龙降临 / 俯冲等）
            if e.levState == 'down' then e.moving = false; e.ready = false; break end -- 潜水期间不可行动
            if c45Step(B, e, dt) then break end -- 第四、五章：冰牢、冰棺、冰壳、圣盾、审判、首领阶段
            if (e.charmed or 0) > 0 then e.charmed = e.charmed - dt; if e.charmed <= 0 then uncharm(B, e) end end
            if e.shift then stepShift(e, dt) end
            if T(e.armor) and e.stun > 0 then shatterArmor(e) end -- 黑曜卫士：被控碎甲
            if e.channel then -- 熔核护盾：引导中不动不打，每秒回复 2% 生命
                e.moving = false; e.chT = e.chT + dt
                if e.chT >= 0.5 then e.chT = e.chT - 0.5; e.hp = min(e.maxHp, e.hp + e.maxHp * 0.01) end
                break
            end
            if e.ccImmune and e.stun > 0 then e.stun = 0 end -- 超凡之躯：免疫眩晕
            if e.stun > 0 then e.stun = e.stun - dt * ((e.side == 'p' and B.ccAura > 0) and (1 / (1 - B.ccAura)) or 1); e.moving = false; break end
            if e.blink then e.blinkT = e.blinkT - dt; if e.blinkT <= 0 then doBlink(B, e) end end
            if e.hook then e.hookT = e.hookT - dt; if e.hookT <= 0 then doHook(B, e) end end
            if e.target and not e.target.dead and isMeleeEnt(e) and (e.target.nAtk or 0) >= 3 and
                hypot(e.target.x - e.x, e.target.y - e.y) > e.range + e.r + e.target.r then
                e.reT = (e.reT or 0) + dt
                if e.reT >= 1 then e.reT = 0; e.target.nAtk = max(0, e.target.nAtk - 1); e.target = nil end
            else e.reT = 0 end
            if e.target and e.target.untargetable then e.target = nil end
            if not e.target or e.target.dead or e.target.immune then
                if e.dive then e.target = backmost(B, e) else e.target = nearestFoe(e, alive) end
            end
            local t = e.target
            if not t then e.moving = false; break end
            local dx, dy = t.x - e.x, t.y - e.y
            local d = hypot(dx, dy)
            if d == 0 then d = 0.001 end
            if abs(dx) > 1 then e.face = (dx > 0) and 1 or -1 end
            local reach = e.range + e.r + t.r
            e.ready = d <= reach -- 目标在攻击范围内：画面上开始蓄力
            local sf = e.slow and (1 - e.slow.amt) or 1
            if e.unitRule then sf = sf * e.unitRule.spd end
            if d > reach and e.speed > 0 and not ((e.root or 0) > 0) then
                local sp = e.speed * sf * dt
                e.x = e.x + dx / d * sp; e.y = e.y + dy / d * sp; e.moving = true
            else e.moving = false end
            local spdMul = 1
            if e.rageSpd then spdMul = 1 + min(0.2, floor((1 - e.hp / e.maxHp) * 10) * 0.04) end
            if (e.overT or 0) > 0 then spdMul = spdMul * 1.6 end
            e.cdLeft = e.cdLeft - dt * (e.slow and (1 - e.slow.amt) or 1) * spdMul * (((e.haste or 0) > 0) and 2 or 1)
            if d <= reach and e.cdLeft <= 0 then e.cdLeft = e.cd * (((e.giant or 0) > 0) and GIANT_CD or 1); tryAttack(B, e, t) end
        until true
    end
    if FRAME_STAGE_PROBE then FRAME_STAGE_PROBE('battle:separate') end
    -- 近战挤位（O(n²)）：实体数异常时（正常单波 <= 40）跳过分离，避免平方级卡死。
    if alive.n <= 80 then
        for i = 0, #alive - 1 do
            for j = i + 1, #alive - 1 do
                local a, b = alive[i], alive[j]
                local dx, dy = b.x - a.x, b.y - a.y
                local d = hypot(dx, dy)
                local mn = a.r + b.r + 1
                if d < mn then
                    if d < 0.01 then dx = js.random() - 0.5; dy = js.random() - 0.5; d = hypot(dx, dy) end
                    local push, nx, ny = (mn - d) / 2, dx / d, dy / d
                    -- 接触半径 mn=a.r+b.r+1；敌我保持完整分离，友军仅作轻微视觉分离。
                    -- 重合点先生成非零方向；边缘最终夹回战场，避免巨人/炮塔挤走己方近战。
                    local k = (a.side == b.side) and FRIEND_PUSH or 1
                    local wa = (a.anchor and 0.05 or (a.big and 0.2 or 1)) * k
                    local wb = (b.anchor and 0.05 or (b.big and 0.2 or 1)) * k
                    a.x = a.x - nx * push * wa; a.y = a.y - ny * push * wa; b.x = b.x + nx * push * wb; b.y = b.y + ny * push * wb
                end
            end
        end
    end
    for e in of(alive) do e.x = clamp(e.x, 6, AW - 6); e.y = clamp(e.y, e.big and 22 or 14, FIELD_H - 10) end
    if FRAME_STAGE_PROBE then FRAME_STAGE_PROBE('battle:fields') end
    for f in of(B.fields) do
        if f.kind then if not c45Hazard(B, f, dt) then stepHazard(B, f, dt) end -- 熔岩池 / 地裂 / 暴风雪 / 星陨
        else
            f.t = f.t - dt; f.tick = f.tick - dt -- 黑洞
            for o in of(B.ents) do
                if not (o.dead or o.side == f.src.side) then
                    local dx, dy = f.x - o.x, f.y - o.y
                    local d = hypot(dx, dy)
                    if d < f.r then o.holeT = 0.6; o.holeVuln = f.vuln or 0 end
                    if d < f.r and d > 2 then
                        local pull = min(d - 2, (o.big and 8 or 34) * dt)
                        o.x = o.x + dx / d * pull; o.y = o.y + dy / d * pull
                    end
                end
            end
            if f.tick <= 0 then
                f.tick = f.tick + 0.5
                for o in of(foesOf(B, f.src)) do
                    if hypot(o.x - f.x, o.y - f.y) <= f.r * 0.6 then hit(f.src, o, f.src.atk * f.mul, { noLeech = true }) end
                end
            end
            if f.t <= 0 then
                f.done = true
                for o in of(foesOf(B, f.src)) do
                    if hypot(o.x - f.x, o.y - f.y) <= f.r * 0.7 then hit(f.src, o, f.src.atk * f.boom) end
                end
                FX.ring(f.x, f.y, 26, '#c06bff'); FX.particle(f.x, f.y, '#8f4bc4', 26, 80, 20, 0.6); G.shake = max(G.shake, 0.2)
            end
        end
    end
    B.fields = B.fields:filter(function(f) return not f.done end)
    if FRAME_STAGE_PROBE then FRAME_STAGE_PROBE('battle:projs') end
    for p in of(B.projs) do
        repeat
            -- 坐标/目标异常（NaN/Inf）时直接销毁：否则它永远到不了目标，会无限累积
            if not (p.x == p.x) or not (p.y == p.y) or not (p.tx == p.tx) or not (p.ty == p.ty) then p.done = true; break end
            if p.delay > 0 then p.delay = p.delay - dt; break end
            if p.pierce then -- 贯穿箭：沿直线飞行，路径上每个敌人只命中一次
                local n = max(1, ceil(p.speed * dt / 3))
                -- 护栏：p.speed 或 dt 异常时 n 会变成天文数字，while 循环会卡死整帧。
                if not (n == n) or n > 400 then n = 400 end
                local st = p.speed * dt / n
                local k = 0
                while k < n and not p.done do
                    p.x = p.x + p.vx * st; p.y = p.y + p.vy * st
                    for o in of(B.ents) do
                        if not o.dead and o.side ~= p.src.side and not p.hitSet:has(o) and hypot(o.x - p.x, (o.y - 3) - p.y) <= o.r + 3 then
                            p.hitSet:add(o); hit(p.src, o, p.src.atk * p.mul); procHit(p, o)
                            FX.burst(o.x, o.y - 3, PIERCE_BURST[p.kind] or ((p.kind == 'bloodpierce') and '#ff3434' or '#9ff6ff'), (PIERCE_BURST[p.kind] or p.kind == 'bloodpierce') and 12 or 6)
                        end
                    end
                    if p.x < -6 or p.x > AW + 6 or p.y < 4 or p.y > FIELD_H + 2 then
                        if p.ret and not p.returned then
                            p.returned = true; p.vx = -p.vx; p.vy = -p.vy; p.ang = atan(p.vy, p.vx); p.mul = p.mul * 0.5; p.hitSet = js.Set()
                            p.x = clamp(p.x, -5, AW + 5); p.y = clamp(p.y, 5, FIELD_H + 1)
                        else p.done = true end
                    end
                    k = k + 1
                end
                break
            end
            if p.tgt and not p.tgt.dead then p.tx = p.tgt.x; p.ty = p.tgt.y - 3 end
            local dx, dy = p.tx - p.x, p.ty - p.y
            local d, step = hypot(dx, dy), p.speed * dt
            if d > 0.01 then p.ang = atan(dy, dx) end
            if d <= step + 1 then
                p.done = true
                local dmg = p.src.atk * p.mul
                if p.area then
                    for o in of(B.ents) do
                        if not o.dead and o.side ~= p.src.side and hypot(o.x - p.tx, o.y - (p.ty + 3)) <= p.splash then
                            hit(p.src, o, dmg)
                            procHit(p, o)
                        end
                    end
                    FX.impact(p)
                    if p.pool then B.fields:push({ kind = 'lava', x = p.tx, y = p.ty + 3, r = 18, t = 4, max = 4, tick = 0.5, src = p.src, mul = 0.35 }) end
                else
                    local tg = p.tgt
                    if tg and not tg.dead then
                        hit(p.src, tg, dmg, p.basic and BASIC_HIT or nil); procHit(p, tg)
                        if p.basic and T(p.src.witherHit) and not tg.dead then tg.wither = max(tg.wither or 0, p.src.witherHit) end
                        if p.basic and T(p.src.rootHit) and not tg.dead then tg.root = max(tg.root or 0, p.src.rootHit) end
                        if T(p.killRefund) and tg.dead and not p.src.dead then gainEnergy(p.src, p.killRefund) end -- 猎魔人
                        if T(p.ricochet) then -- 连弩手：弹射一次
                            local o = nearestOther(B, p.src, p.tx, p.ty + 3, 50, js.Set(A(tg)))
                            if o then shoot(B, p.src, o, (p.kind == 'rarrow') and 'rarrow' or 'arrow', { x = p.tx, y = p.ty, mul = p.mul * p.ricochet }) end
                        end
                        if p.kind == 'star' then FX.burst(p.tx, p.ty, '#ffe680', 8) end
                        if p.kind == 'bloodstar' then FX.ring(p.tx, p.ty + 3, 12, '#ff3434'); FX.particle(p.tx, p.ty, '#ff8e6a', 10, 60, 40, 0.5) end
                    end
                    if T(p.splash) then splashDmg(B, p.src, p.tx, p.ty + 3, p.splash, dmg * p.splashMul, p.tgt); FX.burst(p.tx, p.ty, PROJ_BURST[p.kind] or '#c06bff', 10) end
                    if T(p.chain) and js.random() < p.chain then
                        local o = nearestOther(B, p.src, p.tx, p.ty + 3, 44, p.tgt and js.Set(A(p.tgt)) or nil)
                        if o then FX.bolt(p.tx, p.ty, o.x, o.y - 3); hit(p.src, o, dmg * 0.6); Sound.play('zap') end
                    end
                end
            else p.x = p.x + dx / d * step; p.y = p.y + dy / d * step end
        until true
    end
    B.projs = B.projs:filter(function(p) return not p.done end)
    -- 弹道硬上限：正常单波 <= 10；超过 60 说明有弹道永不消失（坐标 NaN 等），
    -- 直接丢掉最老的，避免无限累积拖垮引擎。
    if B.projs.n > 60 then B.projs = B.projs:slice(B.projs.n - 60) end
    -- 弹道探针：数量异常时打印类型分布（正常单波 <= 10）
    if B.projs.n > 25 then
        local cnt, order = {}, {}
        for i = 0, B.projs.n - 1 do
            local p = B.projs[i]
            local k = tostring(p and p.kind) .. (p and p.ret and '(ret)' or '')
            if not cnt[k] then cnt[k] = 0; order[#order + 1] = k end
            cnt[k] = cnt[k] + 1
        end
        local parts = {}
        for _, k in ipairs(order) do parts[#parts + 1] = k .. '×' .. cnt[k] end
        local p0 = B.projs[0]
        print('[拉杆军团] 弹道数异常：projs=' .. B.projs.n .. ' 类型：' .. table.concat(parts, ' ')
            .. ' 首个：x=' .. tostring(p0 and p0.x) .. ' y=' .. tostring(p0 and p0.y) .. ' tx=' .. tostring(p0 and p0.tx) .. ' ty=' .. tostring(p0 and p0.ty) .. ' done=' .. tostring(p0 and p0.done))
    end
    for e in of(B.ents) do if e.dead then e.deadT = e.deadT + dt end end
    -- 回收久死的敌方实体：B.ents 只增不减，长时间战斗会累积到上百个（分离循环是 O(n²)，会卡死）。
    -- 复活类机制会回捞阵亡敌人（第六章「黑死复苏」限 deadT < 20，第五章「复生圣光」无时限），
    -- 回收必须晚于所有复活判定，否则复活池会被提前清空、机制静默失效。
    -- 单波战斗上限 75 秒（B.t > 75 强制结束），故用 80 秒回收，保证本波内任何时刻复活都有尸体可用。
    if B.ents.n > 60 then
        B.ents = B.ents:filter(function(e) return not (e.dead and e.side == 'e' and e.deadT > 80 and not e.unit) end)
    end
    if not B.over then
        local pa = B.ents:some(function(e) return not e.dead and (e.side == 'p' or T(e.charmed)) end)
        if not pa then for _, f in ipairs(HOOKS.lose) do if f(B) then pa = true; break end end end
        local ea = B.ents:some(function(e) return not e.dead and e.side == 'e' and not T(e.charmed) end)
        if not ea or not pa or B.t > 75 then
            B.over = true; B.result = (not ea and pa) and 'win' or 'lose'; B.endT = 0; FX.battleOver(B.result)
        end
    else B.endT = B.endT + dt end
end
function finishBattle(revivable)
    local win = G.battle.result == 'win'
    local interest = min(interestCap(), floor(G.gold / 10))
    local base = win and (5 + G.wave) or 5
    local res = { win = win, base = base, interest = interest, wave = G.wave }
    res.flawless = win and not G.battle.ents:some(function(e) return e.dead and e.side == 'p' and not e.minion and e.unit end)
    res.elite = win and waveTag(G.wave) == '精英波'
    if not win then G.lives = G.lives - 1 end
    G.gold = G.gold + base + interest
    G.battle = nil
    if win then
        if G.wave >= G.maxWave then G.phase = 'victory' else G.wave = G.wave + 1; G.phase = 'prep' end
    else
        G.phase = (G.lives <= 0) and 'gameover' or 'prep'
    end
    runHooks('finish', res)
    -- 最后一滴血战败：先别结算，给玩家一次看广告复活的机会
    res.revivable = (not win) and G.phase == 'gameover' and revivable and G.adRevives < AD_REVIVE_MAX
    if res.revivable then return res end
    if not G.tutorial then -- 教程不计入存档，也不产出军魂
        if win then G.soulPend = G.soulPend + soulPerWave(G.ch, G.diff); G.soulWaves = G.soulWaves + 1; res.soulGain = soulPerWave(G.ch, G.diff) end
        saveBest(G.ch, G.diff, (win and G.phase == 'victory') and G.maxWave or (G.wave - 1))
        local first = G.phase == 'victory' and (SAVE[G.ch].cleared & (1 << G.diff)) == 0 -- 必须在 clearDiff 之前判断
        if G.phase == 'victory' then res.news = clearDiff(G.ch, G.diff) end
        if G.phase == 'victory' then res.soul = settleRun('win', first)
        elseif G.phase == 'gameover' then res.soul = settleRun('lose') end
    end
    Cloud.markDirty()
    return res
end

return true
