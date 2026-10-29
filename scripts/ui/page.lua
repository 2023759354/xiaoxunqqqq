-- ============================================================================
-- 页面运行时：把 DOM + CSS 变成可绘制的盒树，并维护交互状态
--  * 增量更新：DOM 变动只重算变动的子树样式、只重建脏路径上的盒子，排版靠记忆化跳过干净子树
--  * 交互状态：:hover / :active / :focus-visible、滚动位置、事件分发（冒泡、disabled 按钮不收点击）
-- ============================================================================
local DOM = require("ui.dom")
local CSS = require("ui.css")
local LAY = require("ui.layout")

local M = {}
local Page = {}
Page.__index = Page

--- opts: { html = body 内部 HTML, css = 样式表文本, vw, vh, envVars = { ['safe-area-inset-top'] = 0, ... }, imageSize = fn(src) -> w, h }
function M.new(opts)
    local self = setmetatable({}, Page)
    self.doc = DOM.newDocument(opts.html)
    self.sheets = { CSS.parse(require("ui.ua"), 0), CSS.parse(opts.css, 1) }
    self.env = { vw = opts.vw, vh = opts.vh, envVars = opts.envVars or {} }
    self.state = { hover = {}, active = {}, focus = nil, focusVisible = nil }
    self.lastInput = nil -- 'keyboard' | 'pointer'
    self.full = true
    self.needs = true
    self.layoutVersion = 0
    LAY.imageSize = opts.imageSize or function() return 0, 0 end
    DOM.setInvalidateHook(function(node) self:invalidate(node) end)
    self.doc.onRemove = function(node) self:onRemove(node) end
    self:collectStateCompounds()
    return self
end

-- ---------------------------------------------------------------------------
-- 脏标记
-- ---------------------------------------------------------------------------
function Page:invalidate(node)
    node.dirty = true
    local p = node.parent
    while p and not p.descDirty do p.descDirty = true; p = p.parent end
    self.needs = true
end

function Page:onRemove(node)
    local st = self.state
    st.hover[node] = nil
    st.active[node] = nil
    if st.focus == node then st.focus = nil; st.focusVisible = nil end
    if self.pressed == node then self.pressed = nil end
    if self.onRemoveHook then self.onRemoveHook(node) end
    node.cs = nil; node.pseudoCs = nil
end

function Page:setViewport(vw, vh, envVars)
    if vw == self.env.vw and vh == self.env.vh and not envVars then return end
    self.env.vw, self.env.vh = vw, vh
    if envVars then self.env.envVars = envVars end
    self.full = true
    self.needs = true
end

-- ---------------------------------------------------------------------------
-- 更新：样式 → 盒树 → 排版
-- ---------------------------------------------------------------------------
-- DOM 环检测：parent 链若有环（树操作失误造出），下面所有递归遍历都会无限递归→卡死。
-- 这里每帧低成本检查一次（只走 parent 链，最坏 O(深度)），发现环就断开并报警。
local domWarned = false
local function checkCycle(doc)
    if domWarned then return end
    local el, guard = doc.documentElement, 0
    while el do
        el = el.parent
        guard = guard + 1
        if guard > 200 then
            domWarned = true
            print('[拉杆军团] 检测到 DOM 环：已断开（树操作 bug，请上报）')
            -- 断开：把最深那个节点的 parent 置 nil，终止环
            local p, g2 = doc.documentElement, 0
            while p and g2 < 200 do p = p.parent; g2 = g2 + 1 end
            if p then p.parent = nil end
            return
        end
    end
end

function Page:update()
    checkCycle(self.doc)
    if not self.needs then
        LAY.computeSticky(self.root)
        return false
    end
    local full = self.full
    if full then CSS.resetShareCache() end
    local sheets, env, state = self.sheets, self.env, self.state
    -- 1. 样式
    local function rec(el, pcs, force)
        if force or el.dirty or not el.cs then
            local oldCs, oldPs = el.cs, el.pseudoCs
            local cs, bcs, acs = CSS.computeAll(sheets, el, pcs, env, state)
            el.cs = cs
            if not oldPs or oldPs.before ~= bcs or oldPs.after ~= acs then el.pseudoCs = { before = bcs, after = acs } end
            if cs ~= oldCs or el.pseudoCs ~= oldPs then
                el.dirty = true
                local hook = self.onStyle
                if hook then
                    if cs ~= oldCs then hook(el, nil, oldCs, cs) end
                    local np = el.pseudoCs
                    if not oldPs or oldPs.before ~= np.before then hook(el, 'before', oldPs and oldPs.before, np.before) end
                    if not oldPs or oldPs.after ~= np.after then hook(el, 'after', oldPs and oldPs.after, np.after) end
                end
            end
            force = (cs ~= oldCs)
            if force or el.dirty then
                for _, c in ipairs(el.children) do if c.tag ~= '#text' then rec(c, cs, force) end end
                return
            end
        end
        if el.descDirty then
            for _, c in ipairs(el.children) do if c.tag ~= '#text' then rec(c, el.cs, false) end end
        end
    end
    rec(self.doc.documentElement, nil, full)
    -- 焦点修正：获得焦点的元素被隐藏（display: none / hidden）或移除后，焦点回到 body（Chromium 在样式更新时清除）
    local f = self.state.focus
    local lostVis
    if f and (not f.doc or M.isInert(f)) then
        self.state.focus = nil
        lostVis = self.state.focusVisible
        self.state.focusVisible = nil
    end
    -- 2. 盒树（干净的子树直接复用）
    if full then
        local function mark(n) n.dirty = true; for _, c in ipairs(n.children) do mark(c) end end
        mark(self.doc.documentElement)
    end
    local getCs = function(el, pseudo) if pseudo then return el.pseudoCs and el.pseudoCs[pseudo] end return el.cs end
    self.root = LAY.build(self.doc.documentElement, getCs)
    local function clear(n)
        if n.dirty or n.descDirty then
            n.dirty = nil; n.descDirty = nil
            for _, c in ipairs(n.children) do clear(c) end
        end
    end
    clear(self.doc.documentElement)
    -- 3. 排版
    LAY.layoutDocument(self.root, env.vw, env.vh, env.envVars)
    self:applyScroll()
    self.full = false
    self.needs = false
    self.layoutVersion = self.layoutVersion + 1
    -- 失去 :focus-visible 的元素（已不可见）下一次更新时重算样式
    if lostVis and lostVis.doc then self:invalidate(lostVis) end
    return true
end

-- ---------------------------------------------------------------------------
-- 滚动：元素的 scrollTop 存在 DOM 节点上；盒子读它绘制并计算粘性定位
-- ---------------------------------------------------------------------------
local function scrollRange(b)
    local clientH = b.h - b.bt - b.bb
    return math.max(0, (b.scrollH or b.h) - b.bt - b.bb - clientH)
end
M.scrollRange = scrollRange

function Page:applyScroll()
    local function walk(b)
        if b.el and b.el.scrollTop then
            local mx = scrollRange(b)
            if b.el.scrollTop > mx then b.el.scrollTop = mx end
            if b.el.scrollTop < 0 then b.el.scrollTop = 0 end
            b.scrollTop = b.el.scrollTop
        elseif b.el then
            b.scrollTop = nil
        end
        for _, c in ipairs(b.children) do if c.kind ~= 'text' then walk(c) end end
    end
    if self.root then walk(self.root); LAY.computeSticky(self.root) end
end

function Page:setScrollTop(el, y)
    el.scrollTop = y
    local b = el.box
    if b and b.ax then
        local mx = scrollRange(b)
        if y > mx then y = mx end
        if y < 0 then y = 0 end
        el.scrollTop = y
        b.scrollTop = y
        LAY.computeSticky(self.root)
    end
end

--- 元素是否是滚动容器（overflow 不为 visible，且内容超出）
function M.isScroller(b)
    if not b or not b.cs then return false end
    local oy = b.cs.raw['overflow-y']
    return (oy == 'auto' or oy == 'scroll') and scrollRange(b) > 0
end

-- ---------------------------------------------------------------------------
-- 交互状态（:hover / :active / :focus-visible）
-- 只有可能被状态选择器影响的元素才需要重算样式
-- ---------------------------------------------------------------------------
function Page:collectStateCompounds()
    local list = {}
    for _, sheet in ipairs(self.sheets) do
        for _, r in ipairs(sheet.rules) do
            for _, c in ipairs(r.sel.cs) do
                local hasState = false
                for _, ps in ipairs(c.pseudo) do
                    if ps == 'hover' or ps == 'active' or ps == 'focus-visible' then hasState = true end
                end
                if hasState then
                    local copy = { tag = c.tag, id = c.id, classes = c.classes, attrs = c.attrs, nots = {}, pseudo = {} }
                    for _, ps in ipairs(c.pseudo) do
                        if ps ~= 'hover' and ps ~= 'active' and ps ~= 'focus-visible' then copy.pseudo[#copy.pseudo + 1] = ps end
                    end
                    list[#list + 1] = copy
                end
            end
        end
    end
    self.stateCompounds = list
end

function Page:stateSensitive(el)
    if el.tag == '#text' then return false end
    for _, c in ipairs(self.stateCompounds) do
        if DOM.matchCompound(el, c, nil) then return true end
    end
    return false
end

local function chainSet(el)
    local s = {}
    while el and el.tag ~= '#text' and el.tag ~= '#document' do s[el] = true; el = el.parent end
    return s
end

function Page:setHover(el)
    local new = el and chainSet(el) or {}
    local old = self.state.hover
    for e in pairs(old) do if not new[e] and self:stateSensitive(e) then self:invalidate(e) end end
    for e in pairs(new) do if not old[e] and self:stateSensitive(e) then self:invalidate(e) end end
    self.state.hover = new
end

function Page:setActive(el)
    local new = el and chainSet(el) or {}
    local old = self.state.active
    for e in pairs(old) do if not new[e] and self:stateSensitive(e) then self:invalidate(e) end end
    for e in pairs(new) do if not old[e] and self:stateSensitive(e) then self:invalidate(e) end end
    self.state.active = new
end

--- 可获得焦点的元素（本游戏里只有按钮会拿焦点）
function M.focusable(el)
    return el and el.tag == 'button' and el.doc ~= nil and not el:isDisabled() and not M.isInert(el)
end

--- 不可见（display: none / hidden 祖先）
function M.isInert(el)
    local n = el
    while n and n.tag ~= '#document' do
        if n.attrs and n.attrs.hidden ~= nil then return true end
        if n.cs and n.cs.raw.display == 'none' then return true end
        n = n.parent
    end
    return false
end

--- 设置焦点。how：'keyboard' | 'pointer' | 'script'
function Page:focus(el, how)
    local st = self.state
    local visible
    if how == 'keyboard' then visible = true
    elseif how == 'pointer' then visible = false
    else
        -- 脚本调用 focus()：最近一次交互不是指针时显示焦点框（Chromium 的 :focus-visible 启发式）
        visible = self.lastInput ~= 'pointer'
    end
    local oldVis = st.focusVisible
    st.focus = el
    st.focusVisible = (el and visible) and el or nil
    if oldVis ~= st.focusVisible then
        if oldVis then self:invalidate(oldVis) end
        if st.focusVisible then self:invalidate(st.focusVisible) end
    end
end

function Page:blur()
    self:focus(nil, 'script')
end

-- ---------------------------------------------------------------------------
-- 事件：冒泡分发
-- ---------------------------------------------------------------------------
--- 派发事件：先目标，再逐级向上。ev 字段：type, target, 以及调用方附加的字段
function Page:dispatch(target, ev)
    ev.target = target
    ev.defaultPrevented = false
    ev.stopped = false
    ev.preventDefault = function() ev.defaultPrevented = true end
    ev.stopPropagation = function() ev.stopped = true end
    local n = target
    while n and not ev.stopped do
        ev.currentTarget = n
        local ls = n.listeners and n.listeners[ev.type]
        if ls then
            local copy = { table.unpack(ls) }
            for _, fn in ipairs(copy) do fn(ev); if ev.stopped then break end end
        end
        local prop = n['on' .. ev.type]
        if prop and not ev.stopped then prop(ev) end
        n = n.parent
        if n and n.tag == '#document' then n = nil end
    end
    -- 窗口级监听
    if not ev.stopped and self.windowListeners and self.windowListeners[ev.type] then
        local copy = { table.unpack(self.windowListeners[ev.type]) }
        for _, fn in ipairs(copy) do fn(ev) end
    end
    return ev
end

function Page:addWindowListener(type, fn)
    self.windowListeners = self.windowListeners or {}
    local l = self.windowListeners[type]
    if not l then l = {}; self.windowListeners[type] = l end
    l[#l + 1] = fn
end

--- 点击：disabled 的按钮（以及它里面的元素）不会收到 click
function Page:click(target)
    local n = target
    while n and n.tag ~= '#document' do
        if n.tag == 'button' and n:isDisabled() then return nil end
        n = n.parent
    end
    return self:dispatch(target, { type = 'click' })
end

return M
