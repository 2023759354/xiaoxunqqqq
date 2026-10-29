-- ============================================================================
-- CSS 动画（@keyframes）与过渡（transition）
--  * 计时函数：steps(n[, jump-end])、linear、ease 系列（三次贝塞尔）
--  * 计时函数作用在每一段关键帧之间（与 CSS 规定一致）
--  * 可动画的属性：opacity、transform（translate / scale 系列）、margin-top、border-*-color、color
-- 结果通过 overrides 交给绘制：opacity / transform / 偏移 / 颜色
-- ============================================================================
local CSS = require("ui.css")

local M = {}
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

-- ---------------------------------------------------------------------------
-- 计时函数
-- ---------------------------------------------------------------------------
local function bezier(x1, y1, x2, y2)
    return function(x)
        if x <= 0 then return 0 elseif x >= 1 then return 1 end
        local t = x
        for _ = 1, 8 do
            local cx = 3 * x1 * t * (1 - t) ^ 2 + 3 * x2 * t ^ 2 * (1 - t) + t ^ 3 - x
            local dx = 3 * x1 * (1 - t) ^ 2 + 6 * (x2 - x1) * t * (1 - t) + 3 * (1 - x2) * t ^ 2
            if abs(cx) < 1e-6 or dx == 0 then break end
            t = t - cx / dx
        end
        return 3 * y1 * t * (1 - t) ^ 2 + 3 * y2 * t ^ 2 * (1 - t) + t ^ 3
    end
end
local EASE = { ease = bezier(0.25, 0.1, 0.25, 1), ['ease-in'] = bezier(0.42, 0, 1, 1), ['ease-out'] = bezier(0, 0, 0.58, 1),
    ['ease-in-out'] = bezier(0.42, 0, 0.58, 1), linear = function(x) return x end }
local function timingFn(s)
    if not s then return EASE.ease end
    local n, pos = s:match('^steps%(%s*(%d+)%s*,?%s*([%w%-]*)%s*%)$')
    if n then
        n = tonumber(n)
        -- 与 Blink 一致：直接 floor(fraction * steps)，不做容差
        if pos == 'start' or pos == 'jump-start' then return function(x) return min(1, floor(x * n) / n + 1 / n) end end
        return function(x) if x >= 1 then return 1 end return floor(x * n) / n end
    end
    local a, b, c, d = s:match('^cubic%-bezier%(([^,]+),([^,]+),([^,]+),([^)]+)%)$')
    if a then return bezier(tonumber(a), tonumber(b), tonumber(c), tonumber(d)) end
    return EASE[s] or EASE.ease
end
M.timingFn = timingFn

local function timeMs(t)
    local v, u = t:match('^([%d%.]+)(m?s)$')
    if not v then return nil end
    v = tonumber(v)
    return (u == 'ms') and v or v * 1000
end

-- ---------------------------------------------------------------------------
-- 值：解析与插值
-- ---------------------------------------------------------------------------
local function parseTransform(s)
    if not s or s == 'none' then return {} end
    local ops = {}
    for name, args in s:gmatch('([%w]+)%(([^)]*)%)') do
        local a = {}
        for v in args:gmatch('[^,%s]+') do
            local num, unit = v:match('^(%-?[%d%.]+)(%a*%%?)$')
            a[#a + 1] = { tonumber(num) or 0, unit or '' }
        end
        -- 统一成 translate(x, y) / scale(x, y)
        if name == 'translate' then ops[#ops + 1] = { 'translate', a[1] or { 0, 'px' }, a[2] or { 0, 'px' } }
        elseif name == 'translateX' then ops[#ops + 1] = { 'translate', a[1], { 0, 'px' } }
        elseif name == 'translateY' then ops[#ops + 1] = { 'translate', { 0, 'px' }, a[1] }
        elseif name == 'scale' then ops[#ops + 1] = { 'scale', a[1], a[2] or a[1] }
        elseif name == 'scaleX' then ops[#ops + 1] = { 'scale', a[1], { 1, '' } }
        elseif name == 'scaleY' then ops[#ops + 1] = { 'scale', { 1, '' }, a[1] } end
    end
    return ops
end
local function identityOf(op)
    if op[1] == 'translate' then return { 'translate', { 0, op[2][2] }, { 0, op[3][2] } } end
    return { 'scale', { 1, '' }, { 1, '' } }
end
local function lerp(a, b, t) return a + (b - a) * t end
local function lerpTransform(A, B, t)
    -- 函数序列相同才逐项插值；一边为 none 时用对方的单位函数补齐
    if #A == 0 then A = {}; for i, op in ipairs(B) do A[i] = identityOf(op) end end
    if #B == 0 then B = {}; for i, op in ipairs(A) do B[i] = identityOf(op) end end
    local out = {}
    local n = max(#A, #B)
    for i = 1, n do
        local a, b = A[i] or identityOf(B[i]), B[i] or identityOf(A[i])
        if a[1] ~= b[1] then return (t < 0.5) and A or B end
        out[i] = { a[1], { lerp(a[2][1], b[2][1], t), b[2][2] ~= '' and b[2][2] or a[2][2] }, { lerp(a[3][1], b[3][1], t), b[3][2] ~= '' and b[3][2] or a[3][2] } }
    end
    return out
end
local function parseLen(s) local v = s and s:match('^(%-?[%d%.]+)px$'); return v and tonumber(v) or ((s == '0') and 0 or nil) end

local KINDS = { opacity = 'num', transform = 'transform', ['margin-top'] = 'len', color = 'color',
    ['border-top-color'] = 'color', ['border-right-color'] = 'color', ['border-bottom-color'] = 'color', ['border-left-color'] = 'color' }

local function parseVal(prop, v)
    local k = KINDS[prop]
    if k == 'num' then return tonumber(v) or 1
    elseif k == 'len' then return parseLen(v) or 0
    elseif k == 'transform' then return parseTransform(v)
    elseif k == 'color' then
        local c = CSS.parseColor(v)
        return c and { c[1], c[2], c[3], c[4] } or { 0, 0, 0, 0 }
    end
end
local function interp(prop, a, b, t)
    local k = KINDS[prop]
    if k == 'num' or k == 'len' then return lerp(a, b, t)
    elseif k == 'transform' then return lerpTransform(a, b, t)
    elseif k == 'color' then
        -- 预乘空间插值
        local al = lerp(a[4], b[4], t)
        if al <= 0 then return { 0, 0, 0, 0 } end
        return { (a[1] * a[4] + (b[1] * b[4] - a[1] * a[4]) * t) / al, (a[2] * a[4] + (b[2] * b[4] - a[2] * a[4]) * t) / al,
            (a[3] * a[4] + (b[3] * b[4] - a[3] * a[4]) * t) / al, al }
    end
end

-- ---------------------------------------------------------------------------
-- 动画简写
-- ---------------------------------------------------------------------------
local function parseAnimation(s)
    if not s or s == 'none' then return nil end
    local a = { iter = 1, fill = 'none', timing = 'ease', delay = 0 }
    local times = 0
    local toks = {}
    local i = 1
    while i <= #s do
        local ws = s:match('^%s*', i); i = i + #ws
        if i > #s then break end
        local tok = s:match('^[%w%-%.]+%b()', i) or s:match('^[^%s]+', i)
        toks[#toks + 1] = tok
        i = i + #tok
    end
    for _, t in ipairs(toks) do
        local ms = timeMs(t)
        if ms then
            if times == 0 then a.dur = ms else a.delay = ms end
            times = times + 1
        elseif t:match('^steps%(') or t:match('^cubic%-bezier') or EASE[t] then a.timing = t
        elseif t == 'infinite' then a.iter = math.huge
        elseif tonumber(t) then a.iter = tonumber(t)
        elseif t == 'forwards' or t == 'backwards' or t == 'both' or t == 'none' then a.fill = t
        elseif t == 'normal' or t == 'reverse' or t == 'alternate' or t == 'alternate-reverse' or t == 'running' or t == 'paused' then
        else a.name = t end
    end
    a.dur = a.dur or 0
    a.ease = timingFn(a.timing)
    return a.name and a or nil
end
local function parseTransitions(s)
    if not s or s == 'none' then return nil end
    local out = {}
    for _, part in ipairs(require('ui.paint').splitTop(s, ',')) do
        local prop, dur, timing
        for tok in part:gmatch('%S+') do
            local ms = timeMs(tok)
            if ms then dur = dur or ms
            elseif tok:match('^steps') or EASE[tok] or tok:match('^cubic') then timing = tok
            else prop = tok end
        end
        if prop then out[prop] = { dur = dur or 0, ease = timingFn(timing or 'ease') } end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- 引擎：每个（元素，伪元素）一份状态
-- ---------------------------------------------------------------------------
local Engine = {}
Engine.__index = Engine

function M.new(page)
    local self = setmetatable({ page = page, now = 0, states = {}, keyframes = {} }, Engine)
    for _, sh in ipairs(page.sheets) do for k, v in pairs(sh.keyframes or {}) do self.keyframes[k] = v end end
    return self
end

-- 第十五次更新（卡顿）：伪元素的键按元素缓存（以前每次查询都拼一次字符串，绘制时每帧每个伪元素查好几次）
local pseudoKeys = setmetatable({}, { __mode = 'k' })
local function keyOf(el, pseudo)
    if not pseudo then return el end
    local t = pseudoKeys[el]
    if not t then t = {}; pseudoKeys[el] = t end
    local k = t[pseudo]
    if not k then k = tostring(el) .. pseudo; t[pseudo] = k end
    return k
end

--- 样式重算后调用：检测动画的开始 / 结束，过渡的开始
function Engine:onStyle(el, pseudo, oldCs, newCs)
    local key = keyOf(el, pseudo)
    local st = self.states[key]
    -- 动画
    local anim = newCs and newCs.raw.display ~= 'none' and parseAnimation(newCs.raw.animation) or nil
    if anim then
        if not st or not st.anim or st.anim.name ~= anim.name then
            st = st or { el = el, pseudo = pseudo }
            st.anim = anim
            st.t0 = self.now
            self.states[key] = st
        else
            -- 同名动画继续：时长等参数可能变了
            anim.t0 = st.t0
            st.anim = anim
        end
    elseif st then
        st.anim = nil
    end
    -- 过渡
    if oldCs and newCs and newCs.raw.display ~= 'none' then
        local tr = parseTransitions(newCs.raw.transition)
        if tr then
            for prop, spec in pairs(tr) do
                local props = (prop == 'all') and { 'opacity', 'transform' } or { prop }
                for _, p in ipairs(props) do
                    if KINDS[p] then
                        local ov, nv = oldCs.raw[p], newCs.raw[p]
                        if ov ~= nv and spec.dur > 0 then
                            st = st or { el = el, pseudo = pseudo }
                            st.trans = st.trans or {}
                            local cur = self:currentValue(st, p, oldCs)
                            local from = cur
                            local old = st.trans[p]
                            local dur = spec.dur
                            local factor = 1
                            if old and old.toRaw == ov and old.fromRaw == nv then
                                -- 反向过渡：按已走过的比例缩短（CSS Transitions 的 reversing shortening）
                                local prog = old.ease(min(1, (self.now - old.t0) / old.dur))
                                factor = prog * old.factor + (1 - old.factor)
                                factor = max(0, min(1, factor))
                                dur = dur * factor
                            end
                            st.trans[p] = { from = from, to = parseVal(p, nv), t0 = self.now, dur = dur, ease = spec.ease,
                                fromRaw = ov, toRaw = nv, factor = factor }
                            self.states[key] = st
                        end
                    end
                end
            end
        end
    end
end

function Engine:onRemove(el)
    for k, st in pairs(self.states) do
        if st.el == el then self.states[k] = nil end
    end
end

--- 关键帧动画在当前时刻某属性的值（nil 表示动画不影响它）
local function substVarsCs(v, cs) return CSS.substVars(v, cs.vars) end
function Engine:animValue(st, prop, cs)
    local a = st.anim
    if not a then return nil end
    local frames = self.keyframes[a.name]
    if not frames then return nil end
    local t = self.now - st.t0 - a.delay
    if t < 0 then return nil end
    local p
    -- Blink 用秒做单位计算进度（浮点结果和用毫秒算不同，会影响 steps() 落在哪一步）
    if a.dur <= 0 then p = 1 else p = (t / 1000) / (a.dur / 1000) end
    local iterDone = false
    if p >= a.iter then
        if a.fill == 'forwards' or a.fill == 'both' then p = (a.iter == math.huge) and 1 or (a.iter - floor(a.iter) == 0 and 1 or a.iter % 1); iterDone = true
        else return nil end
    elseif p >= 1 then p = p % 1 end
    -- 这个属性在哪些关键帧里出现（含隐式的 0% / 100%：取元素本来的值）
    local base = cs.raw[prop]
    local pts = {}
    for _, f in ipairs(frames) do
        for _, d in ipairs(f.decls) do
            local ex
            if d.animExp then ex = d.animExp
            else
                ex = CSS.expand(d.k, substVarsCs(d.v, cs))
                if not d.v:find('var(', 1, true) then d.animExp = ex end
            end
            for _, kv in ipairs(ex) do
                if kv[1] == prop then pts[#pts + 1] = { off = f.off, v = kv[2] } end
            end
        end
    end
    if #pts == 0 then return nil end
    if pts[1].off > 0 then table.insert(pts, 1, { off = 0, v = base }) end
    if pts[#pts].off < 1 then pts[#pts + 1] = { off = 1, v = base } end
    local i = 1
    while i < #pts - 1 and p >= pts[i + 1].off do i = i + 1 end
    local a0, a1 = pts[i], pts[i + 1]
    local span = a1.off - a0.off
    local q = span > 0 and (p - a0.off) / span or 1
    if iterDone and p >= 1 then q = 1 end
    q = a.ease(min(1, max(0, q)))
    return interp(prop, parseVal(prop, a0.v), parseVal(prop, a1.v), q)
end

function Engine:transValue(st, prop)
    local tr = st.trans and st.trans[prop]
    if not tr then return nil end
    local t = ((self.now - tr.t0) / 1000) / (tr.dur / 1000)
    if t >= 1 then st.trans[prop] = nil; return nil end
    if t < 0 then t = 0 end
    return interp(prop, tr.from, tr.to, tr.ease(t))
end

--- 当前生效的值（动画 > 过渡 > 样式）
function Engine:currentValue(st, prop, cs)
    if st then
        local v = self:animValue(st, prop, cs)
        if v ~= nil then return v end
        v = self:transValue(st, prop)
        if v ~= nil then return v end
    end
    return parseVal(prop, cs.raw[prop])
end

--- 有没有任何动画 / 过渡正在影响这个盒子
function Engine:stateOf(b)
    if next(self.states) == nil then return nil end -- 没有任何动画时直接返回（绝大多数帧）
    local el = b.el or b.ownerEl
    if not el then return nil end
    return self.states[keyOf(el, b.pseudo)]
end

local function animRunning(self, st)
    local a = st.anim
    if not a then return false end
    if a.fill == 'forwards' or a.fill == 'both' then return true end
    return (self.now - st.t0 - a.delay) < a.dur * a.iter
end
function Engine:active(b)
    local st = self:stateOf(b)
    if not st then return false end
    if animRunning(self, st) then return true end
    if st.trans then
        for p, tr in pairs(st.trans) do
            if self.now - tr.t0 < tr.dur then return true end
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- 给绘制用的覆盖值
-- ---------------------------------------------------------------------------
function Engine:opacity(b)
    local st = self:stateOf(b)
    if not st then return nil end
    local v = self:animValue(st, 'opacity', b.cs)
    if v == nil then v = self:transValue(st, 'opacity') end
    return v
end

--- 返回绘制格式的变换列表：{ 't', x, y } / { 's', sx, sy }
function Engine:transform(b)
    local st = self:stateOf(b)
    if not st then return nil end
    local v = self:animValue(st, 'transform', b.cs)
    if v == nil then v = self:transValue(st, 'transform') end
    if v == nil then return nil end
    local ops = {}
    for _, op in ipairs(v) do
        if op[1] == 'translate' then
            local x = op[2][2] == '%' and op[2][1] / 100 * b.w or op[2][1]
            local y = op[3][2] == '%' and op[3][1] / 100 * b.h or op[3][1]
            ops[#ops + 1] = { 't', x, y }
        else
            ops[#ops + 1] = { 's', op[2][1], op[3][1] }
        end
    end
    return ops
end

--- margin-top 动画带来的位移（只用于绝对定位元素，等价于平移）
function Engine:offsetY(b)
    local st = self:stateOf(b)
    if not st or not st.anim then return 0 end
    local v = self:animValue(st, 'margin-top', b.cs)
    if v == nil then return 0 end
    return v - (parseLen(b.cs.raw['margin-top']) or 0)
end

function Engine:color(b, prop)
    local st = self:stateOf(b)
    if not st then return nil end
    local v = self:animValue(st, prop, b.cs)
    if v == nil then v = self:transValue(st, prop) end
    return v
end

--- 是否还需要继续重画（有正在进行的动画 / 过渡）
function Engine:busy()
    for _, st in pairs(self.states) do
        if st.anim or (st.trans and next(st.trans)) then return true end
    end
    return false
end

M.parseAnimation = parseAnimation
return M
