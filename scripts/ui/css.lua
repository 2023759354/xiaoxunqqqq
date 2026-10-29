-- ============================================================================
-- 迷你 CSS 引擎：解析样式表 → 选择器匹配 → 层叠 → 计算值
-- 支持原版页面用到的全部写法：自定义属性 var()、calc/min/max/clamp/env、
-- @media、@keyframes、:hover/:active/:disabled/:not()/:focus-visible、::before/::after
-- ============================================================================
local DOM = require("ui.dom")
local M = {}

local floor, max, min = math.floor, math.max, math.min

-- ---------------------------------------------------------------------------
-- 颜色
-- ---------------------------------------------------------------------------
local NAMED = { transparent = { 0, 0, 0, 0 }, white = { 255, 255, 255, 1 }, black = { 0, 0, 0, 1 }, red = { 255, 0, 0, 1 } }
local colorCache = {}
function M.parseColor(s)
    if s == nil then return nil end
    local hit = colorCache[s]
    if hit ~= nil then return hit or nil end
    local c = nil
    local t = s:match('^%s*(.-)%s*$')
    if t:sub(1, 1) == '#' then
        local h = t:sub(2)
        if #h == 3 then c = { tonumber(h:sub(1, 1), 16) * 17, tonumber(h:sub(2, 2), 16) * 17, tonumber(h:sub(3, 3), 16) * 17, 1 }
        elseif #h == 6 then c = { tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 1 }
        elseif #h == 8 then c = { tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), tonumber(h:sub(7, 8), 16) / 255 } end
    elseif t:match('^rgba?%(') then
        local nums = {}
        for v in t:match('%((.*)%)'):gmatch('[^,%s/]+') do nums[#nums + 1] = v end
        local function ch(v) if v:sub(-1) == '%' then return tonumber(v:sub(1, -2)) * 2.55 end return tonumber(v) end
        local a = 1
        if nums[4] then if nums[4]:sub(-1) == '%' then a = tonumber(nums[4]:sub(1, -2)) / 100 else a = tonumber(nums[4]) end end
        c = { ch(nums[1]), ch(nums[2]), ch(nums[3]), a }
    else
        c = NAMED[t:lower()]
    end
    colorCache[s] = c or false
    return c
end

-- ---------------------------------------------------------------------------
-- 工具：按顶层分隔符切分（忽略括号和引号里的）
-- ---------------------------------------------------------------------------
local function splitTop(s, sep)
    local out, depth, start, q = {}, 0, 1, nil
    for i = 1, #s do
        local c = s:sub(i, i)
        if q then if c == q then q = nil end
        elseif c == '"' or c == "'" then q = c
        elseif c == '(' then depth = depth + 1
        elseif c == ')' then depth = depth - 1
        elseif depth == 0 and ((sep == ' ' and c:match('%s')) or c == sep) then
            local part = s:sub(start, i - 1)
            if sep ~= ' ' or part:match('%S') then out[#out + 1] = part:match('^%s*(.-)%s*$') end
            start = i + 1
        end
    end
    local last = s:sub(start)
    if sep ~= ' ' or last:match('%S') then out[#out + 1] = last:match('^%s*(.-)%s*$') end
    return out
end
M.splitTop = splitTop

-- ---------------------------------------------------------------------------
-- 数值表达式：长度 / calc / min / max / clamp / env
-- 结果：数字（px）或 延迟到布局阶段的 { pct = 依赖百分比 } 表达式
-- ---------------------------------------------------------------------------
local Expr = {}
M.Expr = Expr

local function tokenize(s)
    local toks, i = {}, 1
    while i <= #s do
        local c = s:sub(i, i)
        if c:match('%s') then i = i + 1
        elseif c:match('[%d%.]') or (c == '-' and s:sub(i + 1, i + 1):match('[%d%.]') and (#toks == 0 or toks[#toks].t == 'op' or toks[#toks].t == '(' or toks[#toks].t == ',')) then
            local num = s:match('^%-?[%d%.]+', i)
            i = i + #num
            local unit = s:match('^[%a%%]+', i) or ''
            i = i + #unit
            toks[#toks + 1] = { t = 'num', v = tonumber(num), u = unit }
        elseif c == '-' and not s:sub(i + 1, i + 1):match('[%a%-_]') then
            toks[#toks + 1] = { t = 'op', v = '-' }; i = i + 1
        elseif c:match('[%a%-_]') then
            local id = s:match('^[%a%-_][%w%-_]*', i)
            i = i + #id
            if s:sub(i, i) == '(' then toks[#toks + 1] = { t = 'fn', v = id:lower() }; i = i + 1
            else toks[#toks + 1] = { t = 'id', v = id } end
        elseif c == '(' or c == ')' or c == ',' then toks[#toks + 1] = { t = c }; i = i + 1
        elseif c == '+' or c == '-' or c == '*' or c == '/' then toks[#toks + 1] = { t = 'op', v = c }; i = i + 1
        else i = i + 1 end
    end
    return toks
end

local parseSum
local function parseAtom(toks, p)
    local t = toks[p]
    if not t then return nil, p end
    if t.t == 'num' then return { k = 'num', v = t.v, u = t.u }, p + 1 end
    if t.t == '(' then
        local e, q = parseSum(toks, p + 1)
        return e, q + 1
    end
    if t.t == 'fn' then
        local args = {}
        local q = p + 1
        if t.v == 'env' then
            -- env(name, fallback)
            local name = toks[q] and toks[q].v
            q = q + 1
            local fb = nil
            if toks[q] and toks[q].t == ',' then fb, q = parseSum(toks, q + 1) end
            return { k = 'env', name = name, fb = fb }, q + 1
        end
        while toks[q] and toks[q].t ~= ')' do
            local e
            e, q = parseSum(toks, q)
            args[#args + 1] = e
            if toks[q] and toks[q].t == ',' then q = q + 1 end
        end
        return { k = 'fn', f = t.v, args = args }, q + 1
    end
    if t.t == 'id' then return { k = 'id', v = t.v }, p + 1 end
    return nil, p + 1
end
local function parseProd(toks, p)
    local a
    a, p = parseAtom(toks, p)
    while toks[p] and toks[p].t == 'op' and (toks[p].v == '*' or toks[p].v == '/') do
        local op = toks[p].v
        local b
        b, p = parseAtom(toks, p + 1)
        a = { k = 'op', op = op, a = a, b = b }
    end
    return a, p
end
parseSum = function(toks, p)
    local a
    a, p = parseProd(toks, p)
    while toks[p] and toks[p].t == 'op' and (toks[p].v == '+' or toks[p].v == '-') do
        local op = toks[p].v
        local b
        b, p = parseProd(toks, p + 1)
        a = { k = 'op', op = op, a = a, b = b }
    end
    return a, p
end

local exprCache = {}
function Expr.parse(s)
    local hit = exprCache[s]
    if hit then return hit end
    local e = parseSum(tokenize(s), 1)
    exprCache[s] = e
    return e
end

--- 是否依赖百分比（需要等布局时才能算）
function Expr.hasPct(e)
    if not e then return false end
    if e.k == 'num' then return e.u == '%' end
    if e.k == 'op' then return Expr.hasPct(e.a) or Expr.hasPct(e.b) end
    if e.k == 'fn' then for _, a in ipairs(e.args) do if Expr.hasPct(a) then return true end end end
    if e.k == 'env' then return Expr.hasPct(e.fb) end
    return false
end

--- ctx: { em, rem, vw, vh, ch, pct(basis or nil), env = {} }
function Expr.eval(e, ctx)
    if not e then return 0 end
    local k = e.k
    if k == 'num' then
        local u, v = e.u, e.v
        if u == 'px' or u == '' then return v end
        if u == '%' then return ctx.pct and (v * ctx.pct / 100) or 0 end
        if u == 'em' then return v * ctx.em end
        if u == 'rem' then return v * (ctx.rem or 16) end
        if u == 'vw' then return v * ctx.vw / 100 end
        if u == 'vh' or u == 'dvh' or u == 'svh' or u == 'lvh' then return v * ctx.vh / 100 end
        if u == 'ch' then return v * (ctx.ch or ctx.em * 0.5) end
        if u == 's' then return v end
        if u == 'ms' then return v / 1000 end
        if u == 'deg' then return v end
        return v
    end
    if k == 'op' then
        local a, b = Expr.eval(e.a, ctx), Expr.eval(e.b, ctx)
        if e.op == '+' then return a + b elseif e.op == '-' then return a - b
        elseif e.op == '*' then return a * b else return a / b end
    end
    if k == 'fn' then
        local f, args = e.f, e.args
        if f == 'calc' then return Expr.eval(args[1], ctx) end
        if f == 'min' then local m = math.huge; for _, a in ipairs(args) do m = min(m, Expr.eval(a, ctx)) end return m end
        if f == 'max' then local m = -math.huge; for _, a in ipairs(args) do m = max(m, Expr.eval(a, ctx)) end return m end
        if f == 'clamp' then return max(Expr.eval(args[1], ctx), min(Expr.eval(args[2], ctx), Expr.eval(args[3], ctx))) end
        return 0
    end
    if k == 'env' then
        local v = ctx.env and ctx.env[e.name]
        if v ~= nil then return v end
        return Expr.eval(e.fb, ctx)
    end
    return 0
end

-- ---------------------------------------------------------------------------
-- 样式表解析
-- ---------------------------------------------------------------------------
local function stripComments(s) return (s:gsub('/%*.-%*/', '')) end

local function parseDecls(body)
    local out = {}
    for _, d in ipairs(splitTop(body, ';')) do
        local k, v = d:match('^%s*([%w%-]+)%s*:%s*(.-)%s*$')
        if k then
            local imp = false
            if v:match('!%s*important$') then imp = true; v = v:gsub('%s*!%s*important$', '') end
            out[#out + 1] = { k = k:lower():match('^%-%-') and k or k:lower(), v = v, imp = imp }
        end
    end
    return out
end
M.parseDecls = parseDecls

local function specificityOf(compounds)
    local a, b, c = 0, 0, 0
    local function add(comp)
        if comp.id then a = a + 1 end
        b = b + #comp.classes + #comp.attrs + #comp.pseudo
        if comp.tag and comp.tag ~= '*' then c = c + 1 end
        for _, n in ipairs(comp.nots) do add(n) end
    end
    for _, comp in ipairs(compounds) do add(comp) end
    return a * 10000 + b * 100 + c
end

--- 媒体查询：返回函数(env) → bool
local function parseMedia(q)
    q = q:lower()
    return function(env)
        for part in q:gmatch('%b()') do
            local feat, val = part:match('^%(%s*([%w%-]+)%s*:%s*(.-)%s*%)$')
            if feat == 'max-width' then if not (env.vw <= tonumber(val:match('[%d%.]+'))) then return false end
            elseif feat == 'min-width' then if not (env.vw >= tonumber(val:match('[%d%.]+'))) then return false end
            elseif feat == 'prefers-reduced-motion' then if val ~= (env.reducedMotion and 'reduce' or 'no-preference') then return false end
            elseif feat == 'prefers-color-scheme' then if val ~= (env.darkScheme and 'dark' or 'light') then return false end
            else return false end
        end
        return true
    end
end

function M.parse(text, origin)
    text = stripComments(text)
    local sheet = { rules = {}, keyframes = {} }
    local order = 0
    local function addRules(src, media)
        local p = 1
        while p <= #src do
            local ws = src:match('^%s*', p); p = p + #ws
            if p > #src then break end
            if src:sub(p, p) == '@' then
                local name = src:match('^@([%w%-]+)', p)
                local brace = src:find('{', p, true)
                local prelude = src:sub(p + 1 + #name, brace - 1):match('^%s*(.-)%s*$')
                -- 找到匹配的右括号
                local depth, q = 1, brace + 1
                while depth > 0 and q <= #src do
                    local c = src:sub(q, q)
                    if c == '{' then depth = depth + 1 elseif c == '}' then depth = depth - 1 end
                    q = q + 1
                end
                local inner = src:sub(brace + 1, q - 2)
                if name == 'media' then
                    local cond = parseMedia(prelude)
                    local combined = cond
                    if media then combined = function(env) return media(env) and cond(env) end end
                    addRules(inner, combined)
                elseif name == 'keyframes' then
                    local frames = {}
                    for sel, body in inner:gmatch('([^{}]+){([^{}]*)}') do
                        local decls = parseDecls(body)
                        for _, off in ipairs(splitTop(sel, ',')) do
                            local o = off:match('^%s*(.-)%s*$')
                            local v = (o == 'from') and 0 or (o == 'to') and 100 or tonumber(o:match('[%d%.]+'))
                            frames[#frames + 1] = { off = v / 100, decls = decls }
                        end
                    end
                    table.sort(frames, function(a, b) return a.off < b.off end)
                    sheet.keyframes[prelude] = frames
                end
                p = q
            else
                local brace = src:find('{', p, true)
                if not brace then break end
                local sel = src:sub(p, brace - 1)
                local close = src:find('}', brace, true)
                local decls = parseDecls(src:sub(brace + 1, close - 1))
                for _, s in ipairs(splitTop(sel, ',')) do
                    s = s:match('^%s*(.-)%s*$')
                    local pseudoElt = nil
                    local base = s:gsub('::([%w%-]+)$', function(pe) pseudoElt = pe; return '' end)
                    local parsed = DOM.parseSelector(base)
                    order = order + 1
                    sheet.rules[#sheet.rules + 1] = { sel = parsed, spec = specificityOf(parsed.cs) + (pseudoElt and 1 or 0), order = order,
                        decls = decls, media = media, pseudo = pseudoElt, origin = origin or 1, text = s }
                end
                p = close + 1
            end
        end
    end
    addRules(text, nil)
    -- 按最右侧复合选择器建索引
    sheet.index = { id = {}, class = {}, tag = {}, any = {} }
    for _, r in ipairs(sheet.rules) do
        local last = r.sel.cs[#r.sel.cs]
        local bucket
        if last.id then bucket = sheet.index.id; bucket[last.id] = bucket[last.id] or {}; table.insert(bucket[last.id], r)
        elseif #last.classes > 0 then bucket = sheet.index.class; local c = last.classes[1]; bucket[c] = bucket[c] or {}; table.insert(bucket[c], r)
        elseif last.tag and last.tag ~= '*' then bucket = sheet.index.tag; bucket[last.tag] = bucket[last.tag] or {}; table.insert(bucket[last.tag], r)
        else table.insert(sheet.index.any, r) end
    end
    return sheet
end

-- ---------------------------------------------------------------------------
-- 简写展开（var() 已替换之后）
-- ---------------------------------------------------------------------------
local SIDES = { 'top', 'right', 'bottom', 'left' }
local function boxSides(vals)
    local n = #vals
    if n == 1 then return vals[1], vals[1], vals[1], vals[1] end
    if n == 2 then return vals[1], vals[2], vals[1], vals[2] end
    if n == 3 then return vals[1], vals[2], vals[3], vals[2] end
    return vals[1], vals[2], vals[3], vals[4]
end
local BORDER_STYLES = { none = true, solid = true, dashed = true, dotted = true, double = true, outset = true, inset = true, hidden = true, groove = true, ridge = true }
local function parseBorderShorthand(v)
    local w, s, c = nil, nil, nil
    for _, part in ipairs(splitTop(v, ' ')) do
        local pl = part:lower()
        if BORDER_STYLES[pl] then s = pl
        elseif pl:match('^[%d%.]') or pl == 'thin' or pl == 'medium' or pl == 'thick' then w = part
        else c = part end
    end
    return w, s, c
end

local function expand(k, v, out)
    if k == 'margin' or k == 'padding' then
        local t, r, b, l = boxSides(splitTop(v, ' '))
        out[#out + 1] = { k .. '-top', t }; out[#out + 1] = { k .. '-right', r }; out[#out + 1] = { k .. '-bottom', b }; out[#out + 1] = { k .. '-left', l }
    elseif k == 'inset' then
        local t, r, b, l = boxSides(splitTop(v, ' '))
        out[#out + 1] = { 'top', t }; out[#out + 1] = { 'right', r }; out[#out + 1] = { 'bottom', b }; out[#out + 1] = { 'left', l }
    elseif k == 'border' then
        local w, s, c = parseBorderShorthand(v)
        for _, sd in ipairs(SIDES) do
            out[#out + 1] = { 'border-' .. sd .. '-width', w or 'medium' }
            out[#out + 1] = { 'border-' .. sd .. '-style', s or 'none' }
            out[#out + 1] = { 'border-' .. sd .. '-color', c or 'currentcolor' }
        end
    elseif k == 'border-top' or k == 'border-right' or k == 'border-bottom' or k == 'border-left' then
        local w, s, c = parseBorderShorthand(v)
        out[#out + 1] = { k .. '-width', w or 'medium' }
        out[#out + 1] = { k .. '-style', s or 'none' }
        out[#out + 1] = { k .. '-color', c or 'currentcolor' }
    elseif k == 'border-color' then
        local t, r, b, l = boxSides(splitTop(v, ' '))
        out[#out + 1] = { 'border-top-color', t }; out[#out + 1] = { 'border-right-color', r }; out[#out + 1] = { 'border-bottom-color', b }; out[#out + 1] = { 'border-left-color', l }
    elseif k == 'border-width' then
        local t, r, b, l = boxSides(splitTop(v, ' '))
        out[#out + 1] = { 'border-top-width', t }; out[#out + 1] = { 'border-right-width', r }; out[#out + 1] = { 'border-bottom-width', b }; out[#out + 1] = { 'border-left-width', l }
    elseif k == 'border-style' then
        local t, r, b, l = boxSides(splitTop(v, ' '))
        out[#out + 1] = { 'border-top-style', t }; out[#out + 1] = { 'border-right-style', r }; out[#out + 1] = { 'border-bottom-style', b }; out[#out + 1] = { 'border-left-style', l }
    elseif k == 'gap' then
        local p = splitTop(v, ' ')
        out[#out + 1] = { 'row-gap', p[1] }; out[#out + 1] = { 'column-gap', p[2] or p[1] }
    elseif k == 'flex' then
        local p = splitTop(v, ' ')
        if v == 'none' then out[#out + 1] = { 'flex-grow', '0' }; out[#out + 1] = { 'flex-shrink', '0' }; out[#out + 1] = { 'flex-basis', 'auto' }
        elseif v == 'auto' then out[#out + 1] = { 'flex-grow', '1' }; out[#out + 1] = { 'flex-shrink', '1' }; out[#out + 1] = { 'flex-basis', 'auto' }
        elseif #p == 1 and tonumber(p[1]) then out[#out + 1] = { 'flex-grow', p[1] }; out[#out + 1] = { 'flex-shrink', '1' }; out[#out + 1] = { 'flex-basis', '0%' }
        else
            out[#out + 1] = { 'flex-grow', p[1] }
            out[#out + 1] = { 'flex-shrink', p[2] or '1' }
            out[#out + 1] = { 'flex-basis', p[3] or '0%' }
        end
    elseif k == 'font' then
        if v == 'inherit' then
            for _, f in ipairs({ 'font-style', 'font-weight', 'font-size', 'line-height', 'font-family' }) do out[#out + 1] = { f, 'inherit' } end
        end
    elseif k == 'background' then
        local lv = v:lower()
        if lv == 'none' then
            out[#out + 1] = { 'background-color', 'transparent' }; out[#out + 1] = { 'background-image', 'none' }
        elseif lv:match('gradient%(') or lv:match('^url%(') then
            out[#out + 1] = { 'background-color', 'transparent' }; out[#out + 1] = { 'background-image', v }
        else
            out[#out + 1] = { 'background-color', v }; out[#out + 1] = { 'background-image', 'none' }
        end
    elseif k == 'place-items' then
        local p = splitTop(v, ' ')
        out[#out + 1] = { 'align-items', p[1] }; out[#out + 1] = { 'justify-items', p[2] or p[1] }
    elseif k == 'grid-area' then
        out[#out + 1] = { 'grid-area', v }
    elseif k == 'outline' then
        local w, s, c = parseBorderShorthand(v)
        out[#out + 1] = { 'outline-width', w or 'medium' }; out[#out + 1] = { 'outline-style', s or 'none' }; out[#out + 1] = { 'outline-color', c or 'currentcolor' }
    elseif k == 'overflow' then
        local p = splitTop(v, ' ')
        out[#out + 1] = { 'overflow-x', p[1] }; out[#out + 1] = { 'overflow-y', p[2] or p[1] }
    else
        out[#out + 1] = { k, v }
    end
end

-- ---------------------------------------------------------------------------
-- var() 替换
-- ---------------------------------------------------------------------------
local function substVars(v, vars)
    if not v:find('var(', 1, true) then return v end
    local out, i = {}, 1
    while true do
        local s = v:find('var%(', i)
        if not s then out[#out + 1] = v:sub(i); break end
        out[#out + 1] = v:sub(i, s - 1)
        local depth, q = 1, s + 4
        while depth > 0 and q <= #v do
            local c = v:sub(q, q)
            if c == '(' then depth = depth + 1 elseif c == ')' then depth = depth - 1 end
            q = q + 1
        end
        local inner = v:sub(s + 4, q - 2)
        local name, fb = inner:match('^%s*(%-%-[%w%-]+)%s*,%s*(.-)%s*$')
        if not name then name = inner:match('^%s*(%-%-[%w%-]+)%s*$') end
        local val = vars[name]
        if val == nil then val = fb and substVars(fb, vars) or '' end
        out[#out + 1] = val
        i = q
    end
    return table.concat(out)
end
M.substVars = substVars
M.expand = function(k, v) local out = {}; expand(k, v, out); return out end

-- ---------------------------------------------------------------------------
-- 计算值
-- ---------------------------------------------------------------------------
local INHERITED = {
    color = true, ['font-size'] = true, ['font-weight'] = true, ['font-style'] = true, ['line-height'] = true,
    ['letter-spacing'] = true, ['text-align'] = true, ['white-space'] = true, cursor = true, ['pointer-events'] = true,
    ['text-shadow'] = true, visibility = true, ['font-family'] = true, ['image-rendering'] = true,
}
M.INHERITED = INHERITED

local INITIAL = {
    display = 'inline', position = 'static', color = '#000000', ['font-size'] = '16px', ['font-weight'] = '400', ['font-style'] = 'normal',
    ['line-height'] = 'normal', ['letter-spacing'] = 'normal', ['text-align'] = 'start', ['white-space'] = 'normal', cursor = 'auto',
    ['pointer-events'] = 'auto', ['text-shadow'] = 'none', visibility = 'visible',
    width = 'auto', height = 'auto', ['min-width'] = 'auto', ['min-height'] = 'auto', ['max-width'] = 'none', ['max-height'] = 'none',
    top = 'auto', right = 'auto', bottom = 'auto', left = 'auto',
    ['flex-direction'] = 'row', ['flex-wrap'] = 'nowrap', ['justify-content'] = 'normal', ['align-items'] = 'normal', ['align-self'] = 'auto',
    ['align-content'] = 'normal', ['justify-items'] = 'normal', ['justify-self'] = 'auto',
    ['flex-grow'] = '0', ['flex-shrink'] = '1', ['flex-basis'] = 'auto', ['row-gap'] = 'normal', ['column-gap'] = 'normal',
    ['grid-template-columns'] = 'none', ['grid-template-areas'] = 'none', ['grid-area'] = 'auto', ['grid-row'] = 'auto', ['grid-column'] = 'auto',
    ['overflow-x'] = 'visible', ['overflow-y'] = 'visible', opacity = '1', transform = 'none', ['transform-origin'] = '50% 50%',
    filter = 'none', ['z-index'] = 'auto', ['box-shadow'] = 'none', ['background-color'] = 'transparent', ['background-image'] = 'none',
    ['background-size'] = 'auto', ['outline-width'] = 'medium', ['outline-style'] = 'none', ['outline-color'] = 'currentcolor', ['outline-offset'] = '0',
    ['aspect-ratio'] = 'auto', content = 'normal', animation = 'none', transition = 'none', ['vertical-align'] = 'baseline', clip = 'auto',
}
for _, sd in ipairs(SIDES) do
    INITIAL['margin-' .. sd] = '0'; INITIAL['padding-' .. sd] = '0'
    INITIAL['border-' .. sd .. '-width'] = 'medium'; INITIAL['border-' .. sd .. '-style'] = 'none'; INITIAL['border-' .. sd .. '-color'] = 'currentcolor'
end
M.INITIAL = INITIAL

--- 计算一个元素（或伪元素）的样式。
--- 返回 cs：{ raw = {属性 → 字符串（var 已替换）}, vars = {--x → 字符串}, fontSize = px, ... }
--- 具体的类型化转换在 layout/paint 里按需完成（M.len 等）
local function ruleLess(a, b)
    if a.origin ~= b.origin then return a.origin < b.origin end
    if a.spec ~= b.spec then return a.spec < b.spec end
    return a.order < b.order
end

--- 一次匹配出元素本身、::before、::after 各自命中的规则（已按层叠顺序排好）
local function matchAll(sheets, el, env, state)
    local m0, mb, ma = {}, nil, nil
    for _, sheet in ipairs(sheets) do
        local idx = sheet.index
        local cands = {}
        if el.attrs.id and idx.id[el.attrs.id] then cands[#cands + 1] = idx.id[el.attrs.id] end
        for _, c in ipairs(el.classes) do if idx.class[c] then cands[#cands + 1] = idx.class[c] end end
        if idx.tag[el.tag] then cands[#cands + 1] = idx.tag[el.tag] end
        cands[#cands + 1] = idx.any
        local seen = {}
        for _, list in ipairs(cands) do
            for _, r in ipairs(list) do
                if not seen[r] and (not r.media or r.media(env)) and DOM.matchSelector(el, r.sel, state) then
                    seen[r] = true
                    local ps = r.pseudo
                    if ps == nil then m0[#m0 + 1] = r
                    elseif ps == 'before' then mb = mb or {}; mb[#mb + 1] = r
                    elseif ps == 'after' then ma = ma or {}; ma[#ma + 1] = r end
                end
            end
        end
    end
    table.sort(m0, ruleLess)
    if mb then table.sort(mb, ruleLess) end
    if ma then table.sort(ma, ruleLess) end
    return m0, mb, ma
end

local cascade
function M.computeStyle(sheets, el, parentCs, env, state, pseudo)
    local m0, mb, ma = matchAll(sheets, el, env, state)
    local matched = (pseudo == nil) and m0 or (pseudo == 'before' and mb or ma) or {}
    return cascade(matched, el, parentCs, env, pseudo)
end

-- 样式共享：父样式对象相同、元素的选择器相关特征相同 → 计算样式相同
local shareCache = setmetatable({}, { __mode = 'k' })
local ROOTKEY = {}
function M.resetShareCache() shareCache = setmetatable({}, { __mode = 'k' }) end
local IGNORE_ATTR = { src = true, alt = true, style = true }
local function elSig(el, state)
    local parts = { el.tag, el.attrs.id or '', table.concat(el.classes, '.') }
    local keys = {}
    for k in pairs(el.attrs) do if not IGNORE_ATTR[k] then keys[#keys + 1] = k end end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. '=' .. el.attrs[k] end
    -- 行内样式（setStyle 写在 el.style 里，按书写顺序）
    local so = el.styleOrder
    if so and #so > 0 then
        local st = el.style
        for _, k in ipairs(so) do parts[#parts + 1] = k .. ':' .. st[k] end
    end
    if state then
        parts[#parts + 1] = (state.hover[el] and 'h' or '') .. (state.active[el] and 'a' or '') .. (state.focusVisible == el and 'f' or '')
    end
    return table.concat(parts, '\1')
end
--- 计算元素自身与两个伪元素的样式（伪元素没有规则时返回 nil）
function M.computeAll(sheets, el, parentCs, env, state)
    local pk = parentCs or ROOTKEY
    local bucket = shareCache[pk]
    if not bucket then bucket = {}; shareCache[pk] = bucket end
    local sig = elSig(el, state)
    local hit = bucket[sig]
    if hit then return hit[1], hit[2], hit[3] end
    local m0, mb, ma = matchAll(sheets, el, env, state)
    local cs = cascade(m0, el, parentCs, env, nil)
    local bcs = mb and cascade(mb, el, cs, env, 'before') or nil
    local acs = ma and cascade(ma, el, cs, env, 'after') or nil
    bucket[sig] = { cs, bcs, acs }
    return cs, bcs, acs
end

cascade = function(matched, el, parentCs, env, pseudo)
    -- 2. 自定义属性（先层叠，再供 var() 使用）
    local vars = setmetatable({}, { __index = parentCs and parentCs.vars or nil })
    local declsInOrder = {}
    for _, r in ipairs(matched) do for _, d in ipairs(r.decls) do declsInOrder[#declsInOrder + 1] = d end end
    if not pseudo then
        for _, k in ipairs(el.styleOrder) do declsInOrder[#declsInOrder + 1] = { k = k, v = el.style[k] } end
    end
    for _, d in ipairs(declsInOrder) do
        local custom = d.custom
        if custom == nil then custom = d.k:sub(1, 2) == '--'; d.custom = custom; d.hasVar = d.v:find('var(', 1, true) ~= nil end
        if custom then rawset(vars, d.k, d.hasVar and substVars(d.v, vars) or d.v) end
    end
    -- 3. 普通属性：替换 var、展开简写，后写覆盖先写（不含 var() 的声明，展开结果缓存在声明上）
    local raw = {}
    for _, d in ipairs(declsInOrder) do
        if not d.custom then
            local exp = d.exp
            if not exp then
                exp = {}
                if d.hasVar then expand(d.k, substVars(d.v, vars), exp)
                else expand(d.k, d.v, exp); d.exp = exp end
            end
            for _, kv in ipairs(exp) do raw[kv[1]] = kv[2] end
        end
    end
    -- 4. 继承与初始值
    local pr = parentCs and parentCs.raw or nil
    for k, init in pairs(INITIAL) do
        local v = raw[k]
        if v == nil then
            if INHERITED[k] and pr then raw[k] = pr[k] else raw[k] = init end
        elseif v == 'inherit' then
            raw[k] = pr and pr[k] or init
        elseif v == 'initial' then
            raw[k] = init
        end
    end
    local cs = { raw = raw, vars = vars, pseudo = pseudo }
    -- 字号（其它 em 单位都依赖它）
    local pfs = parentCs and parentCs.fontSize or 16
    local fsv = raw['font-size']
    if raw['font-size'] == (pr and pr['font-size']) and parentCs then
        cs.fontSize = pfs
    elseif fsv == 'smaller' then cs.fontSize = pfs / 1.2
    elseif fsv == 'larger' then cs.fontSize = pfs * 1.2
    else
        cs.fontSize = Expr.eval(Expr.parse(fsv), { em = pfs, vw = env.vw, vh = env.vh, env = env.envVars, pct = pfs })
    end
    raw['font-size'] = cs.fontSize .. 'px'
    -- 字重
    local fw = raw['font-weight']
    if fw == 'bold' then cs.fontWeight = 700 elseif fw == 'normal' then cs.fontWeight = 400
    elseif fw == 'bolder' then cs.fontWeight = ((parentCs and parentCs.fontWeight or 400) >= 600) and 900 or 700
    else cs.fontWeight = tonumber(fw) or 400 end
    -- 行高：数字（倍数，按数字继承）或 px
    local lh = raw['line-height']
    if lh == 'normal' then cs.lineHeight = nil
    elseif tonumber(lh) then cs.lineHeight = tonumber(lh) * cs.fontSize; cs.lineHeightNum = tonumber(lh)
    else
        cs.lineHeight = Expr.eval(Expr.parse(lh), { em = cs.fontSize, vw = env.vw, vh = env.vh, pct = cs.fontSize })
        -- 继承的是计算后的 px 值
        raw['line-height'] = cs.lineHeight .. 'px'
    end
    -- 字间距：em 按本元素字号换算成 px 后继承
    local ls = raw['letter-spacing']
    if ls == 'normal' then cs.letterSpacing = 0
    else
        cs.letterSpacing = Expr.eval(Expr.parse(ls), { em = cs.fontSize, vw = env.vw, vh = env.vh })
        raw['letter-spacing'] = cs.letterSpacing .. 'px'
    end
    -- 颜色
    if raw.color == 'currentcolor' then raw.color = pr and pr.color or '#000000' end
    cs.color = M.parseColor(raw.color) or { 0, 0, 0, 1 }
    return cs
end

return M
