-- ============================================================================
-- 输入：鼠标 / 触摸 / 滚轮 / 键盘 → 页面事件（坐标单位：CSS 像素）
--  * 命中测试用绘制时记录的区域（含 pointer-events、裁剪、变换）
--  * :hover / :active、按钮获得焦点（指针点击不显示焦点框，键盘导航显示）
--  * click 派发给按下与松开目标的共同祖先，disabled 按钮不响应
--  * 战场画布：按下单位后捕获指针（拖拽），与原版 pointer capture 一致
--  * 滚动：滚轮（平滑）、鼠标 / 触摸拖动（带惯性）；touch-action: none 的元素上不滚动
--  * 键盘：Tab 切换焦点，Enter 按下即点击、空格松开时点击（按钮的默认行为）
--  * 第十四次更新：页面元素拖放。带 data-drag 属性的元素可以拖动（page.drag 提供回调）：
--    鼠标按下后移动超过 4px 开始拖；触摸要按住 0.2 秒不动才拿起来（先滑动仍然是滚动列表）。
--    拖动中不滚动、不触发点击；松开时把指针下的元素交给 page.drag.drop
-- ============================================================================
local PAINT = require("ui.paint")
local PAGE_M = require("ui.page")

local M = {}
local Input = {}
Input.__index = Input

--- hooks: { arenaDown(x, y, isTouch) -> capture?, arenaMove(x, y), arenaUp(), arenaCancel(), now() -> ms }
function M.new(page, hooks)
    return setmetatable({ page = page, hooks = hooks, pointers = {}, scrollAnims = {}, lastScroll = {}, lastTouchT = -1e9 }, Input)
end

local function isArena(el) return el and el.attrs and el.attrs.id == 'arena' end

--- 最近的可滚动祖先盒子
local function scrollerOf(el)
    local b = el and el.box
    while b do
        if b.el and PAGE_M.isScroller(b) then return b end
        b = b.parent
    end
    return nil
end

local function touchActionNone(el)
    local n = el
    while n and n.cs do
        if n.cs.raw['touch-action'] == 'none' then return true end
        n = n.parent
    end
    return false
end

local function commonAncestor(a, b)
    if not a or not b then return nil end
    local set = {}
    local n = a
    while n do set[n] = true; n = n.parent end
    n = b
    while n do if set[n] then return n end; n = n.parent end
    return nil
end

local function focusTarget(el)
    local n = el
    while n and n.tag ~= '#document' do
        if n.tag == 'button' then return n end
        n = n.parent
    end
    return nil
end

--- 带 data-drag 的最近祖先
local function dragSourceOf(el)
    local n = el
    while n and n.tag ~= '#document' do
        if n.attrs and n.attrs['data-drag'] ~= nil then
            if n.tag == 'button' and n:isDisabled() then return nil end
            return n
        end
        n = n.parent
    end
    return nil
end
local DRAG_MOUSE_PX, DRAG_TOUCH_PX, DRAG_HOLD_MS = 4, 8, 200
-- 滑动 / 点击判定：列表被拖动超过 TAP_SCROLL_PX、或手指位移超过 TAP_SLIP_PX 就不再算点击；
-- 惯性滚动停下后 STOP_FLING_MS 内按下的那一下只用来停住列表
local TAP_SCROLL_PX, TAP_SLIP_PX, STOP_FLING_MS = 6, 32, 120

function Input:hit(x, y)
    local el = PAINT.hitTest(x, y)
    if el and el.tag == '#text' then el = el.parent end
    return el or self.page.doc.body
end

-- ---------------------------------------------------------------------------
-- 指针
-- ---------------------------------------------------------------------------
function Input:pointerDown(id, x, y, isTouch)
    local page = self.page
    if isTouch then self.lastTouchT = self.hooks.now() end
    local target = self:hit(x, y)
    local p = { id = id, x0 = x, y0 = y, x = x, y = y, target = target, touch = isTouch, moved = false,
        t = self.hooks.now(), samples = { { x = x, y = y, t = self.hooks.now() } } }
    self.pointers[id] = p
    page.lastInput = 'pointer'
    -- 焦点：点到按钮就聚焦（不显示焦点框），点到别处就失焦
    local ft = focusTarget(target)
    if ft and PAGE_M.focusable(ft) then
        if page.state.focus ~= ft then page:focus(ft, 'pointer') else page:focus(ft, 'pointer') end
    elseif page.state.focus then
        page:blur()
    end
    -- 触摸时 :hover 跟着点到的元素（移动端浏览器的行为）
    if isTouch then page:setHover(target) end
    -- 战场画布
    if isArena(target) and self.hooks.arenaDown then
        if self.hooks.arenaDown(x, y, isTouch) then p.capture = true end
    end
    -- 停止正在进行的惯性滚动。列表还在滑的时候按下去，本意是「让它停住」而不是点按钮
    -- （手机浏览器同样如此），这一下松手时不算点击
    local sb = scrollerOf(target)
    if sb then
        local now = self.hooks.now()
        if self.scrollAnims[sb.el] or now - (self.lastScroll[sb.el] or -1e9) < STOP_FLING_MS then p.noTap = true end
        self.scrollAnims[sb.el] = nil
    end
    -- 桌面鼠标与触摸一致：在可滚动区域按住拖动即可滚动；战场画布是 touch-action: none，仍走拖放
    p.tapTarget = focusTarget(target) -- 从按钮上起手的触摸：轻微滑动仍应算点击（见 pointerUp）
    p.scroller = (not touchActionNone(target)) and sb or nil
    page:setActive(target)
    p.active = true
    -- 第十四次更新：可拖动的元素
    if not p.capture and page.drag then
        local src = dragSourceOf(target)
        if src then p.dragSrc = src end
    end
end

--- 拿起：回调同意后进入拖动状态（不再滚动、不再算点击）
function Input:startDrag(p)
    local page = self.page
    local src = p.dragSrc
    p.dragSrc = nil
    if not (page.drag and src and page.drag.start(src, p.x, p.y, p.touch)) then return false end
    p.dragging = true
    p.scroller = nil
    p.moved = true
    page:setActive(nil)
    p.active = false
    if page.drag.move then page.drag.move(p.x, p.y, self:hit(p.x, p.y)) end
    return true
end

function Input:pointerMove(id, x, y, isTouch)
    local page = self.page
    if isTouch then self.lastTouchT = self.hooks.now() end
    local p = self.pointers[id]
    if not p then
        -- 鼠标悬停
        if not isTouch then page:setHover(self:hit(x, y)) end
        return
    end
    local dx, dy = x - p.x, y - p.y
    p.x, p.y = x, y
    p.travel = math.max(p.travel or 0, math.abs(x - p.x0) + math.abs(y - p.y0))
    local s = p.samples
    s[#s + 1] = { x = x, y = y, t = self.hooks.now() }
    if #s > 6 then table.remove(s, 1) end
    if p.capture then
        if self.hooks.arenaMove then self.hooks.arenaMove(x, y) end
        return
    end
    if p.dragging then
        if page.drag and page.drag.move then page.drag.move(x, y, self:hit(x, y)) end
        return
    end
    if p.dragSrc then
        local d = math.abs(x - p.x0) + math.abs(y - p.y0)
        if not isTouch then
            if d > DRAG_MOUSE_PX and self:startDrag(p) then return end
        elseif d > DRAG_TOUCH_PX then
            p.dragSrc = nil -- 触摸：还没按满时间就滑动了，当作滚动
        end
    end
    if not isTouch then page:setHover(self:hit(x, y)) end
    -- 触摸拖动滚动（超过阈值后不再算点击）
    -- 阈值 14px：手机上点按按钮几乎必然带 5~12px 的位移，太小会把点击判成滚动
    -- （表现就是「点了没反应」）。可滚动容器里的按钮用更宽的 20px。
    local slop = p.tapTarget and 20 or 14
    if p.scroller then
        if not p.moved and math.abs(y - p.y0) + math.abs(x - p.x0) > slop then
            p.moved = true
            page:setActive(nil)
            p.active = false
        end
        if p.moved and dy ~= 0 then
            local el = p.scroller.el
            local before = el.scrollTop or 0
            page:setScrollTop(el, before - dy)
            p.scrolled = (p.scrolled or 0) + math.abs((el.scrollTop or 0) - before)
            self.lastScroll[el] = self.hooks.now()
        end
    end
end

function Input:pointerUp(id, x, y, isTouch)
    local page = self.page
    if isTouch then self.lastTouchT = self.hooks.now() end
    local p = self.pointers[id]
    if not p then return end
    self.pointers[id] = nil
    if p.capture then
        if self.hooks.arenaUp then self.hooks.arenaUp(x, y) end
        page:setActive(nil)
        return
    end
    page:setActive(nil)
    local upTarget = self:hit(x, y)
    if p.dragging then
        if page.drag and page.drag.drop then page.drag.drop(x, y, upTarget) end
        return
    end
    if p.moved then
        -- 起手和松手都在同一个按钮上：手指稍微滑了一下，用户的本意仍是点击
        -- （否则手机上按按钮会「有时没反应」，尤其是内容可滚动的弹窗）。
        -- 但列表真的被拖动了就是在滑动：内容跟着手指走，松手时手指往往还停在起手的那张卡片上，
        -- 以前会被当成点击（转职 / 晋升弹窗里往下滑找「晋升」，结果点中了转职卡片）。
        -- 所以只有内容几乎没动、手指位移也不大时才补发点击。
        local travel = math.max(p.travel or 0, math.abs(x - p.x0) + math.abs(y - p.y0))
        if p.tapTarget and upTarget == p.tapTarget and not p.noTap
            and (p.scrolled or 0) <= TAP_SCROLL_PX and travel <= TAP_SLIP_PX then
            page:click(p.tapTarget)
            return
        end
        -- 惯性：用最近几次移动估计速度
        ---@type {t:number, y:number}[]
        local s = p.samples
        local a, b = s[1], s[#s]
        local dt = (b.t - a.t)
        if p.scroller and dt > 0 and dt < 200 then
            local v = (b.y - a.y) / dt -- 像素 / 毫秒
            if math.abs(v) > 0.05 then self.scrollAnims[p.scroller.el] = { kind = 'fling', v = -v, t = self.hooks.now() } end
        end
        return
    end
    if p.noTap then return end
    -- 不可滚动的区域：触摸滑出一大段再松手也不算点击（和手机浏览器一致）
    if p.touch and (p.travel or 0) > TAP_SLIP_PX then return end
    local target = commonAncestor(p.target, upTarget)
    if target then page:click(target) end
end

function Input:pointerCancel(id)
    local p = self.pointers[id]
    if not p then return end
    self.pointers[id] = nil
    if p.capture and self.hooks.arenaCancel then self.hooks.arenaCancel() end
    if p.dragging and self.page.drag and self.page.drag.cancel then self.page.drag.cancel() end
    self.page:setActive(nil)
end

--- 正在拖动吗（main 用来决定要不要画拖动中的图标）
function Input:dragging()
    for _, p in pairs(self.pointers) do if p.dragging then return p end end
    return nil
end

function Input:cancelAll()
    for id in pairs(self.pointers) do self:pointerCancel(id) end
    self.pointers = {}
    self.scrollAnims = {}
    self.lastScroll = {}
    self.spaceButton = nil
    self.page:setActive(nil)
    self.page:setHover(nil)
end

--- 桌面上触摸后浏览器也会模拟鼠标事件：短时间内忽略鼠标
function Input:mouseAllowed()
    return self.hooks.now() - self.lastTouchT > 800
end

-- ---------------------------------------------------------------------------
-- 滚轮：平滑滚动（约 150ms）
-- ---------------------------------------------------------------------------
function Input:wheel(x, y, dy)
    local target = self:hit(x, y)
    local sb = scrollerOf(target)
    if not sb then return end
    local el = sb.el
    local cur = self.scrollAnims[el]
    local from = el.scrollTop or 0
    local to = ((cur and cur.kind == 'smooth') and cur.to or from) + dy
    local mx = PAGE_M.scrollRange(sb)
    if to < 0 then to = 0 elseif to > mx then to = mx end
    self.scrollAnims[el] = { kind = 'smooth', from = from, to = to, t = self.hooks.now(), dur = 150 }
end

--- 每帧推进滚动动画
function Input:update()
    local now = self.hooks.now()
    -- 第十四次更新：触摸按住不动满 0.2 秒拿起；拖动中每帧回调（靠近边缘时自动滚动列表）
    for _, p in pairs(self.pointers) do
        if p.dragSrc and p.touch and not p.dragging and now - p.t >= DRAG_HOLD_MS then self:startDrag(p) end
        if p.dragging and self.page.drag and self.page.drag.tick then self.page.drag.tick(p.x, p.y) end
    end
    for el, a in pairs(self.scrollAnims) do
        if not el.box then self.scrollAnims[el] = nil
        elseif a.kind == 'smooth' then
            local k = math.min(1, (now - a.t) / a.dur)
            local e = 1 - (1 - k) ^ 3
            self.page:setScrollTop(el, a.from + (a.to - a.from) * e)
            self.lastScroll[el] = now
            if k >= 1 then self.scrollAnims[el] = nil end
        elseif a.kind == 'fling' then
            local dt = now - (a.last or a.t)
            a.last = now
            local before = el.scrollTop or 0
            self.page:setScrollTop(el, before + a.v * dt)
            self.lastScroll[el] = now
            a.v = a.v * (0.995 ^ dt)
            if math.abs(a.v) < 0.02 or (el.scrollTop or 0) == before then self.scrollAnims[el] = nil end
        end
    end
end

-- ---------------------------------------------------------------------------
-- 键盘
-- ---------------------------------------------------------------------------
--- 文档顺序里所有可获得焦点的按钮（当前可见的）
function Input:focusables()
    local out = {}
    local function walk(n)
        for _, c in ipairs(n.children) do
            if c.tag ~= '#text' then
                if c.attrs.hidden == nil and (not c.cs or c.cs.raw.display ~= 'none') then
                    if c.tag == 'button' and not c:isDisabled() and c.box then out[#out + 1] = c end
                    walk(c)
                end
            end
        end
    end
    walk(self.page.doc.body)
    return out
end

--- code：'Space' 'Enter' 'Tab' 'Escape' 'KeyA' ...；shift：是否按着 Shift
function Input:keyDown(code, shift, isRepeat)
    local page = self.page
    page.lastInput = 'keyboard'
    local target = page.state.focus or page.doc.body
    local ev = page:dispatch(target, { type = 'keydown', code = code, key = code, shiftKey = shift, ['repeat'] = isRepeat })
    if ev.defaultPrevented then return end
    if code == 'Tab' then
        local list = self:focusables()
        if #list == 0 then return end
        local idx = 0
        for i, el in ipairs(list) do if el == page.state.focus then idx = i end end
        local nxt
        if shift then nxt = list[idx > 1 and idx - 1 or #list] else nxt = list[(idx % #list) + 1] end
        page:focus(nxt, 'keyboard')
    elseif target.tag == 'button' then
        if code == 'Enter' then
            page:click(target)
        elseif code == 'Space' and not isRepeat then
            self.spaceButton = target
            page:setActive(target)
        end
    end
end

function Input:keyUp(code)
    local page = self.page --[[@as table<string, any>]]
    local target = page.state.focus or page.doc.body
    page:dispatch(target, { type = 'keyup', code = code, key = code })
    if code == 'Space' and self.spaceButton then
        local b = self.spaceButton
        self.spaceButton = nil
        page:setActive(nil)
        if b == page.state.focus then page:click(b) end
    end
end

--- 最近滚动过的滚动容器（绘制叠加滚动条用）：{ [el] = 最近时间 }
function Input:recentScrolls() return self.lastScroll end

return M
