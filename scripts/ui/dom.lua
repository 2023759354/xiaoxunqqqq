-- ============================================================================
-- 迷你 DOM：HTML 解析 + 元素树 + 原版代码用到的 DOM 接口
-- （getElementById / querySelectorAll / classList / dataset / textContent / innerHTML ...）
-- ============================================================================
local M = {}

local Node = {}
Node.__index = Node
M.Node = Node

local VOID = { img = true, br = true, input = true, meta = true, link = true, hr = true }
local ENT = { amp = '&', lt = '<', gt = '>', quot = '"', apos = "'", nbsp = '\u{00A0}', times = '×', middot = '·' }

local function decode(s)
    if not s:find('&', 1, true) then return s end
    return (s:gsub('&(#?)(x?)(%w+);', function(hash, hex, name)
        if hash == '#' then
            local n = tonumber(name, hex == 'x' and 16 or 10)
            if n then return utf8.char(n) end
        end
        return ENT[name] or ('&' .. hash .. hex .. name .. ';')
    end))
end
M.decode = decode

-- ---------------------------------------------------------------------------
-- 节点
-- ---------------------------------------------------------------------------
local nextUid = 0
local function newNode(tag)
    nextUid = nextUid + 1
    return setmetatable({ uid = nextUid, tag = tag, children = {}, parent = nil, attrs = {}, classes = {}, classSet = {},
        style = {}, styleOrder = {}, listeners = nil, doc = nil }, Node)
end
function M.newText(text)
    nextUid = nextUid + 1
    return setmetatable({ uid = nextUid, tag = '#text', text = text, parent = nil, children = {} }, Node)
end
function M.newElement(tag) return newNode(tag) end

function Node:isText() return self.tag == '#text' end

local function setClassString(el, s)
    el.classes, el.classSet = {}, {}
    for c in (s or ''):gmatch('%S+') do
        if not el.classSet[c] then el.classSet[c] = true; el.classes[#el.classes + 1] = c end
    end
end

--- 按顶层分号切分（url(data:...;base64,...) 里的分号不算）
local function splitDecls(s)
    local out, depth, start = {}, 0, 1
    for i = 1, #s do
        local c = s:byte(i)
        if c == 40 then depth = depth + 1
        elseif c == 41 then depth = depth - 1
        elseif c == 59 and depth == 0 then out[#out + 1] = s:sub(start, i - 1); start = i + 1 end
    end
    out[#out + 1] = s:sub(start)
    return out
end
local function parseStyleAttr(el, s)
    el.style, el.styleOrder = {}, {}
    for _, decl in ipairs(splitDecls(s or '')) do
        local k, v = decl:match('^%s*([%w%-]+)%s*:%s*(.-)%s*$')
        if k then
            if el.style[k] == nil then el.styleOrder[#el.styleOrder + 1] = k end
            el.style[k] = v
        end
    end
end

function Node:getAttribute(k)
    if k == 'class' then return table.concat(self.classes, ' ') end
    return self.attrs[k]
end
function Node:hasAttribute(k)
    if k == 'class' then return #self.classes > 0 end
    return self.attrs[k] ~= nil
end
function Node:setAttribute(k, v)
    v = tostring(v)
    if k == 'class' then setClassString(self, v)
    elseif k == 'style' then parseStyleAttr(self, v); self.attrs.style = v
    else
        self.attrs[k] = v
        if k == 'id' and self.doc then self.doc.ids[v] = self end
    end
    M.invalidate(self)
end
function Node:removeAttribute(k)
    if k == 'class' then setClassString(self, '')
    elseif k == 'style' then self.style = {}; self.styleOrder = {}; self.attrs.style = nil
    else self.attrs[k] = nil end
    M.invalidate(self)
end

-- hidden / disabled（布尔属性）
function Node:isHidden() return self.attrs.hidden ~= nil end
function Node:setHidden(b)
    if (self.attrs.hidden ~= nil) == (not not b) then return end
    if b then self.attrs.hidden = '' else self.attrs.hidden = nil end
    M.invalidate(self)
end
function Node:isDisabled() return self.attrs.disabled ~= nil end
function Node:setDisabled(b)
    if (self.attrs.disabled ~= nil) == (not not b) then return end
    if b then self.attrs.disabled = '' else self.attrs.disabled = nil end
    M.invalidate(self)
end

-- classList
function Node:hasClass(c) return self.classSet[c] == true end
function Node:addClass(...)
    local changed = false
    for i = 1, select('#', ...) do
        local c = select(i, ...)
        if not self.classSet[c] then self.classSet[c] = true; self.classes[#self.classes + 1] = c; changed = true end
    end
    if changed then M.invalidate(self) end
end
function Node:removeClass(...)
    local changed = false
    for i = 1, select('#', ...) do
        local c = select(i, ...)
        if self.classSet[c] then
            self.classSet[c] = nil
            for k, v in ipairs(self.classes) do if v == c then table.remove(self.classes, k); break end end
            changed = true
        end
    end
    if changed then M.invalidate(self) end
end
function Node:toggleClass(c, force)
    local want
    if force == nil then want = not self.classSet[c] else want = not not force end
    if want then self:addClass(c) else self:removeClass(c) end
    return want
end
function Node:setClassName(s) setClassString(self, s); M.invalidate(self) end

-- style
function Node:setStyle(k, v)
    if v == nil or v == '' then
        if self.style[k] ~= nil then
            self.style[k] = nil
            for i, kk in ipairs(self.styleOrder) do if kk == k then table.remove(self.styleOrder, i); break end end
            M.invalidate(self)
        end
        return
    end
    v = tostring(v)
    if self.style[k] == v then return end
    if self.style[k] == nil then self.styleOrder[#self.styleOrder + 1] = k end
    self.style[k] = v
    M.invalidate(self)
end

-- dataset
function Node:data(k) return self.attrs['data-' .. k] end
function Node:setData(k, v)
    if v == nil then self.attrs['data-' .. k] = nil else self.attrs['data-' .. k] = tostring(v) end
end

-- 树操作
function Node:appendChild(c)
    if c.parent then c:remove() end
    c.parent = self
    self.children[#self.children + 1] = c
    if self.doc then M.adopt(c, self.doc) end
    M.invalidate(self)
    return c
end
function Node:remove()
    local p = self.parent
    if not p then return end
    for i, c in ipairs(p.children) do if c == self then table.remove(p.children, i); break end end
    self.parent = nil
    if p.doc then M.unadopt(self, p.doc) end
    M.invalidate(p)
end
function Node:isConnected() return self.doc ~= nil end
function Node:childElementCount()
    local n = 0
    for _, c in ipairs(self.children) do if c.tag ~= '#text' then n = n + 1 end end
    return n
end

function M.adopt(node, doc)
    node.doc = doc
    if node.attrs and node.attrs.id then doc.ids[node.attrs.id] = node end
    for _, c in ipairs(node.children) do M.adopt(c, doc) end
end
function M.unadopt(node, doc)
    if node.attrs and node.attrs.id and doc.ids[node.attrs.id] == node then doc.ids[node.attrs.id] = nil end
    if doc.onRemove then doc.onRemove(node) end
    node.doc = nil
    for _, c in ipairs(node.children) do M.unadopt(c, doc) end
end

function Node:clearChildren()
    local doc = self.doc
    for _, c in ipairs(self.children) do c.parent = nil; if doc then M.unadopt(c, doc) end end
    self.children = {}
end

function Node:setText(s)
    s = tostring(s)
    if #self.children == 1 and self.children[1].tag == '#text' and self.children[1].text == s then return end
    self:clearChildren()
    if s ~= '' then self:appendChild(M.newText(s)) else M.invalidate(self) end
end
function Node:getText()
    if self.tag == '#text' then return self.text end
    local parts = {}
    for _, c in ipairs(self.children) do parts[#parts + 1] = c:getText() end
    return table.concat(parts)
end

function Node:setHTML(html)
    self:clearChildren()
    for _, c in ipairs(M.parseFragment(html)) do self:appendChild(c) end
    M.invalidate(self)
end

-- ---------------------------------------------------------------------------
-- 第十五次更新（卡顿）：按差异更新子树。
-- setHTML 每次都整棵换新：所有节点重新算样式、重建盒子、重新排版（排版缓存跟着旧盒子一起丢掉）。
-- 战斗中信息栏（伤害统计）每 0.4 秒刷新一次，一次就是一百多个节点，手机上每次卡一下。
-- morphHTML 解析出新的子树后逐个对照：标签相同就保留旧节点，只改有变化的属性 / 文字；
-- 结构变了才替换那一个节点。没变的节点不重算样式，盒子和排版缓存都能复用。
-- 只给「子节点上没有单独绑定事件」的容器用（旧节点会被保留，上面的监听器也会留下）。
-- ---------------------------------------------------------------------------
local function sameAttrs(a, b)
    local aa, ba = a.attrs, b.attrs
    for k, v in pairs(ba) do if k ~= 'style' and aa[k] ~= v then return false end end
    for k in pairs(aa) do if k ~= 'style' and ba[k] == nil then return false end end
    local ac, bc = a.classes, b.classes
    if #ac ~= #bc then return false end
    for i = 1, #bc do if ac[i] ~= bc[i] then return false end end
    -- 行内样式按解析结果比（setStyle 改过的也算在内）
    local ao, bo = a.styleOrder, b.styleOrder
    if #ao ~= #bo then return false end
    local as, bs = a.style, b.style
    for i = 1, #bo do local k = bo[i]; if ao[i] ~= k or as[k] ~= bs[k] then return false end end
    return true
end
local function morphChildren(el, kids)
    local doc = el.doc
    local old = el.children
    local changed = false
    for i = 1, #kids do
        local nk, ok = kids[i], old[i]
        if ok and ok.tag == nk.tag then
            if nk.tag == '#text' then
                if ok.text ~= nk.text then ok.text = nk.text; changed = true end
            else
                if not sameAttrs(ok, nk) then
                    local oldId = ok.attrs.id
                    ok.attrs, ok.classes, ok.classSet, ok.style, ok.styleOrder = nk.attrs, nk.classes, nk.classSet, nk.style, nk.styleOrder
                    if doc then
                        if oldId and doc.ids[oldId] == ok then doc.ids[oldId] = nil end
                        if ok.attrs.id then doc.ids[ok.attrs.id] = ok end
                    end
                    M.invalidate(ok)
                end
                morphChildren(ok, nk.children)
            end
        else
            if ok then ok.parent = nil; if doc then M.unadopt(ok, doc) end end
            nk.parent = el
            old[i] = nk
            if doc then M.adopt(nk, doc) end
            changed = true
        end
    end
    for i = #old, #kids + 1, -1 do
        local ok = old[i]
        old[i] = nil
        ok.parent = nil
        if doc then M.unadopt(ok, doc) end
        changed = true
    end
    if changed then M.invalidate(el) end
end
function Node:morphHTML(html)
    morphChildren(self, M.parseFragment(html))
end

-- ---------------------------------------------------------------------------
-- HTML 解析（只需要支持本游戏模板里出现的写法）
-- ---------------------------------------------------------------------------
function M.parseFragment(html)
    local root = newNode('#fragment')
    local stack = { root }
    local pos, n = 1, #html
    local function top() return stack[#stack] end
    while pos <= n do
        local lt = html:find('<', pos, true)
        if not lt then
            local t = html:sub(pos)
            if t ~= '' then local tn = M.newText(decode(t)); tn.parent = top(); top().children[#top().children + 1] = tn end
            break
        end
        if lt > pos then
            local t = html:sub(pos, lt - 1)
            local tn = M.newText(decode(t)); tn.parent = top(); top().children[#top().children + 1] = tn
        end
        if html:sub(lt, lt + 3) == '<!--' then
            local e = html:find('-->', lt + 4, true)
            pos = (e or n) + 3
        elseif html:sub(lt + 1, lt + 1) == '/' then
            local gt = html:find('>', lt, true)
            local name = html:sub(lt + 2, gt - 1):match('^%s*([%w%-]+)'):lower()
            for i = #stack, 2, -1 do
                if stack[i].tag == name then
                    for _ = #stack, i, -1 do table.remove(stack) end
                    break
                end
            end
            pos = gt + 1
        elseif html:sub(lt + 1, lt + 1) == '!' then
            local gt = html:find('>', lt, true)
            pos = gt + 1
        else
            -- 开始标签：逐个解析属性（属性值里可能有 >）
            local p = lt + 1
            local name = html:match('^([%w%-]+)', p):lower()
            p = p + #name
            local el = newNode(name)
            local selfClose = false
            while true do
                local ws = html:match('^%s*', p); p = p + #ws
                local c = html:sub(p, p)
                if c == '>' then p = p + 1; break end
                if c == '/' and html:sub(p + 1, p + 1) == '>' then p = p + 2; selfClose = true; break end
                local an = html:match('^([^%s=/>]+)', p)
                if not an then p = p + 1
                else
                    p = p + #an
                    local ws2 = html:match('^%s*', p)
                    local val = ''
                    if html:sub(p + #ws2, p + #ws2) == '=' then
                        p = p + #ws2 + 1
                        local ws3 = html:match('^%s*', p); p = p + #ws3
                        local q = html:sub(p, p)
                        if q == '"' or q == "'" then
                            local e = html:find(q, p + 1, true)
                            val = html:sub(p + 1, e - 1); p = e + 1
                        else
                            local v = html:match('^([^%s>]+)', p); val = v; p = p + #v
                        end
                        val = decode(val)
                    end
                    an = an:lower()
                    if an == 'class' then setClassString(el, val)
                    elseif an == 'style' then parseStyleAttr(el, val); el.attrs.style = val
                    else el.attrs[an] = val end
                end
            end
            el.parent = top()
            top().children[#top().children + 1] = el
            if not VOID[name] and not selfClose then stack[#stack + 1] = el end
            pos = p
        end
    end
    local out = root.children
    for _, c in ipairs(out) do c.parent = nil end
    return out
end

-- ---------------------------------------------------------------------------
-- 选择器（querySelector / querySelectorAll 只用到简单的复合选择器 + 后代组合）
-- ---------------------------------------------------------------------------
local function parseCompound(s)
    local c = { classes = {}, attrs = {}, pseudo = {}, nots = {} }
    local p = 1
    local tag = s:match('^([%w%-%*]+)', p)
    if tag then c.tag = tag:lower(); p = p + #tag end
    while p <= #s do
        local ch = s:sub(p, p)
        if ch == '.' then local v = s:match('^%.([%w%-_]+)', p); c.classes[#c.classes + 1] = v; p = p + 1 + #v
        elseif ch == '#' then local v = s:match('^#([%w%-_]+)', p); c.id = v; p = p + 1 + #v
        elseif ch == '[' then
            local e = s:find(']', p, true)
            local body = s:sub(p + 1, e - 1)
            local k, v = body:match('^([%w%-]+)%s*=%s*"?([^"]*)"?$')
            if k then c.attrs[#c.attrs + 1] = { k, v } else c.attrs[#c.attrs + 1] = { body } end
            p = e + 1
        elseif ch == ':' then
            if s:sub(p, p + 4) == ':not(' then
                local depth, q = 1, p + 5
                while depth > 0 do
                    local cc = s:sub(q, q)
                    if cc == '(' then depth = depth + 1 elseif cc == ')' then depth = depth - 1 end
                    q = q + 1
                end
                c.nots[#c.nots + 1] = parseCompound(s:sub(p + 5, q - 2))
                p = q
            else
                local v = s:match('^:([%w%-]+)', p); c.pseudo[#c.pseudo + 1] = v; p = p + 1 + #v
            end
        else p = p + 1 end
    end
    return c
end
M.parseCompound = parseCompound

local function matchCompound(el, c, state)
    if el.tag == '#text' then return false end
    if c.tag and c.tag ~= '*' and c.tag ~= el.tag then return false end
    if c.id and el.attrs.id ~= c.id then return false end
    for _, cl in ipairs(c.classes) do if not el.classSet[cl] then return false end end
    for _, a in ipairs(c.attrs) do
        if a[2] ~= nil then
            if el:getAttribute(a[1]) ~= a[2] then return false end
        else
            if not el:hasAttribute(a[1]) then return false end
        end
    end
    for _, ps in ipairs(c.pseudo) do
        if ps == 'disabled' then if el.attrs.disabled == nil then return false end
        elseif ps == 'hover' then if not (state and state.hover[el]) then return false end
        elseif ps == 'active' then if not (state and state.active[el]) then return false end
        elseif ps == 'focus-visible' then if not (state and state.focusVisible == el) then return false end
        elseif ps == 'root' then if el.tag ~= 'html' then return false end
        else return false end
    end
    for _, nc in ipairs(c.nots) do if matchCompound(el, nc, state) then return false end end
    return true
end
M.matchCompound = matchCompound

--- 解析选择器：返回 { compounds, combinators }（从左到右）
function M.parseSelector(sel)
    local parts, combs = {}, {}
    local s = sel:gsub('%s*>%s*', ' > ')
    local pending = ' '
    for tok in s:gmatch('%S+') do
        if tok == '>' then pending = '>'
        else
            if #parts > 0 then combs[#parts] = pending end
            parts[#parts + 1] = tok
            pending = ' '
        end
    end
    local cs = {}
    for i, p in ipairs(parts) do cs[i] = parseCompound(p) end
    return { cs = cs, combs = combs }
end

function M.matchSelector(el, sel, state)
    local cs, combs = sel.cs, sel.combs
    local i = #cs
    if not matchCompound(el, cs[i], state) then return false end
    local function rec(node, idx)
        if idx < 1 then return true end
        local comb = combs[idx]
        local p = node.parent
        if comb == '>' then
            if p and p.tag ~= '#fragment' and matchCompound(p, cs[idx], state) then return rec(p, idx - 1) end
            return false
        end
        while p and p.tag ~= '#fragment' do
            if matchCompound(p, cs[idx], state) and rec(p, idx - 1) then return true end
            p = p.parent
        end
        return false
    end
    return rec(el, i - 1)
end

local selCache = {}
local function getSel(s)
    local v = selCache[s]
    if not v then v = M.parseSelector(s); selCache[s] = v end
    return v
end

function Node:querySelectorAll(s)
    local sel = getSel(s)
    local out = {}
    local function walk(n)
        for _, c in ipairs(n.children) do
            if c.tag ~= '#text' then
                if M.matchSelector(c, sel, nil) then out[#out + 1] = c end
                walk(c)
            end
        end
    end
    walk(self)
    return out
end
function Node:querySelector(s)
    return self:querySelectorAll(s)[1]
end

-- ---------------------------------------------------------------------------
-- 事件
-- ---------------------------------------------------------------------------
function Node:addEventListener(ev, fn)
    self.listeners = self.listeners or {}
    local l = self.listeners[ev]
    if not l then l = {}; self.listeners[ev] = l end
    l[#l + 1] = fn
end

-- ---------------------------------------------------------------------------
-- 文档
-- ---------------------------------------------------------------------------
local invalidateHook = nil
function M.setInvalidateHook(fn) invalidateHook = fn end
function M.invalidate(node) if invalidateHook and node and node.doc then invalidateHook(node) end end

function M.newDocument(bodyHTML)
    local doc = { ids = {} }
    local html = newNode('html')
    local body = newNode('body')
    body.parent = html
    html.children = { body }
    doc.documentElement = html
    doc.body = body
    for _, c in ipairs(M.parseFragment(bodyHTML)) do
        c.parent = body
        body.children[#body.children + 1] = c
    end
    M.adopt(html, doc)
    function doc.getElementById(id) return doc.ids[id] end
    function doc.createElement(tag) return newNode(tag) end
    return doc
end

return M
