-- ============================================================================
-- 排版引擎：块级流式（含外边距折叠）、行内（断行、行盒、垂直对齐）、
-- Flexbox、Grid、绝对 / 固定 / 粘性定位、滚动容器
-- 目标：对原版页面给出与 Chromium 一致的盒子位置和尺寸
-- ============================================================================
local CSS = require("ui.css")
local TXT = require("ui.text")
local Expr = CSS.Expr

local M = {} --[[@as table<string, any>]]
local floor, ceil, max, min, abs, huge = math.floor, math.ceil, math.max, math.min, math.abs, math.huge

local ENV = { vw = 1280, vh = 800, envVars = {} }
M.ENV = ENV

-- ---------------------------------------------------------------------------
-- 数值工具
-- ---------------------------------------------------------------------------
local lenCache = {}
local function lenExpr(v)
    local e = lenCache[v]
    if e == nil then
        if v == 'auto' or v == 'none' or v == 'normal' or v == nil then e = false
        else e = Expr.parse(v) or false end
        lenCache[v] = e
    end
    return e
end

--- 解析长度：返回 px 或 nil（auto/none，或百分比基准不确定）
local pctCache = {}
local function hasPct(e)
    local h = pctCache[e]
    if h == nil then h = Expr.hasPct(e); pctCache[e] = h end
    return h
end
local NIL = {}
local function L(cs, prop, basis)
    local lc = cs.Lc
    if lc then
        local r = lc[prop]
        if r ~= nil then if r == NIL then return nil end return r end
    end
    local v = cs.raw[prop]
    local e = lenExpr(v)
    if not e then
        if not lc then lc = {}; cs.Lc = lc end
        lc[prop] = NIL
        return nil
    end
    if hasPct(e) then
        if basis == nil then return nil end
        return Expr.eval(e, { em = cs.fontSize, vw = ENV.vw, vh = ENV.vh, pct = basis, env = ENV.envVars, ch = TXT.advance(48, cs.fontSize, cs.fontWeight) })
    end
    -- 与百分比无关的长度：按样式对象缓存（视口变化时样式对象会整体重建）
    local r = Expr.eval(e, { em = cs.fontSize, vw = ENV.vw, vh = ENV.vh, env = ENV.envVars, ch = TXT.advance(48, cs.fontSize, cs.fontWeight) })
    if not lc then lc = {}; cs.Lc = lc end
    lc[prop] = (r == nil) and NIL or r
    return r
end
M.L = L
local function Lz(cs, prop, basis) return L(cs, prop, basis) or 0 end

local function isAuto(cs, prop) local v = cs.raw[prop]; return v == 'auto' or v == nil end

local function borderW(cs, side)
    local st = cs.raw['border-' .. side .. '-style']
    if st == 'none' or st == 'hidden' then return 0 end
    local v = cs.raw['border-' .. side .. '-width']
    if v == 'thin' then return 1 elseif v == 'medium' then return 3 elseif v == 'thick' then return 5 end
    return L(cs, 'border-' .. side .. '-width', 0) or 0
end

local function collapse(a, b)
    if a >= 0 and b >= 0 then return max(a, b) end
    if a < 0 and b < 0 then return min(a, b) end
    return a + b
end

-- ---------------------------------------------------------------------------
-- 盒树
-- ---------------------------------------------------------------------------
--- box.kind：'block'（块容器）'flex' 'grid' 'inline'（行内元素）'text' 'replaced' 'br'
local function displayOf(cs)
    return cs.raw.display
end

local REPLACED = { img = true, canvas = true }


-- 匿名盒（包住行内内容的块、弹性 / 网格里的文本项目）的样式：可继承属性取父元素的，其余取初始值
local anonCache = setmetatable({}, { __mode = 'k' })
local function anonCs(pcs)
    local c = anonCache[pcs]
    if c then return c end
    local raw = {}
    for k, v in pairs(CSS.INITIAL) do
        if CSS.INHERITED[k] then raw[k] = pcs.raw[k] else raw[k] = v end
    end
    raw.display = 'block'
    c = { raw = raw, vars = pcs.vars, fontSize = pcs.fontSize, fontWeight = pcs.fontWeight, lineHeight = pcs.lineHeight,
        lineHeightNum = pcs.lineHeightNum, letterSpacing = pcs.letterSpacing, color = pcs.color, anon = true }
    anonCache[pcs] = c
    return c
end
M.anonCs = anonCs

local function newBox(el, cs, kind)
    return { el = el, cs = cs, kind = kind, children = {}, parent = nil }
end

--- 生成盒树（getCs(el, pseudo) 返回计算样式）
--- 节点干净（node.dirty / node.descDirty 都为假）且父盒类型相同时，直接复用上次的盒子（连同排版缓存）
function M.build(el, getCs)
    local function mk(node, parentBox)
        local pkey = parentBox and parentBox.kind or ''
        if node.box and not node.dirty and not node.descDirty and node.boxPKey == pkey and node.tag ~= '#text' then
            return node.box
        end
        node.boxPKey = pkey
        if node.tag == '#text' then
            local b = newBox(nil, parentBox and parentBox.cs, 'text')
            b.text = node.text
            b.node = node
            return b
        end
        local cs = getCs(node)
        local disp = displayOf(cs)
        if disp == 'none' then
            local function clearBoxes(n) n.box = nil; for _, c in ipairs(n.children) do clearBoxes(c) end end
            clearBoxes(node)
            return nil
        end
        -- 块级化：弹性 / 网格项目、绝对定位元素、根元素
        local pk = parentBox and parentBox.kind
        local posv = cs.raw.position
        if pk == 'flex' or pk == 'grid' or posv == 'absolute' or posv == 'fixed' or not parentBox then
            if disp == 'inline' or disp == 'inline-block' then disp = 'block'
            elseif disp == 'inline-flex' then disp = 'flex'
            elseif disp == 'inline-grid' then disp = 'grid' end
        end
        local kind
        if REPLACED[node.tag] then kind = 'replaced'
        elseif node.tag == 'br' then kind = 'br'
        elseif disp == 'flex' or disp == 'inline-flex' then kind = 'flex'
        elseif disp == 'grid' or disp == 'inline-grid' then kind = 'grid'
        elseif disp == 'inline' then kind = 'inline'
        else kind = 'block' end
        local b = newBox(node, cs, kind)
        b.inlineLevel = (disp == 'inline' or disp == 'inline-block' or disp == 'inline-flex' or disp == 'inline-grid')
        b.pos = cs.raw.position
        b.isButton = node.tag == 'button'
        node.box = b
        local kids = {}
        local function addPseudo(which)
            local pcs = getCs(node, which)
            if pcs and pcs.raw.content ~= 'normal' and pcs.raw.content ~= 'none' and displayOf(pcs) ~= 'none' then
                local pd = displayOf(pcs)
                if b.kind == 'flex' or b.kind == 'grid' or pcs.raw.position == 'absolute' or pcs.raw.position == 'fixed' then
                    if pd == 'inline' or pd == 'inline-block' then pd = 'block' end
                end
                local pk = (pd == 'flex') and 'flex' or ((pd == 'inline') and 'inline' or 'block')
                local pb = newBox(nil, pcs, pk)
                pb.pseudo = which
                pb.ownerEl = node
                pb.inlineLevel = (pd == 'inline' or pd == 'inline-block')
                pb.pos = pcs.raw.position
                local content = pcs.raw.content
                local txt = content:match("^'(.*)'$") or content:match('^"(.*)"$')
                if txt and txt ~= '' then
                    local tb = newBox(nil, pcs, 'text'); tb.text = txt; tb.parent = pb; pb.children[1] = tb
                end
                kids[#kids + 1] = pb
            end
        end
        if kind ~= 'replaced' and kind ~= 'br' then
            addPseudo('before')
            for _, c in ipairs(node.children) do
                local cb = mk(c, b)
                if cb then kids[#kids + 1] = cb end
            end
            addPseudo('after')
        end
        for _, k in ipairs(kids) do k.parent = b end
        b.children = kids
        return b
    end
    return mk(el, nil)
end

-- ---------------------------------------------------------------------------
-- 内边距 / 边框 / 外边距
-- ---------------------------------------------------------------------------
local function resolveEdges(b, cbW)
    local cs = b.cs
    b.pt, b.pr, b.pb, b.pl = Lz(cs, 'padding-top', cbW), Lz(cs, 'padding-right', cbW), Lz(cs, 'padding-bottom', cbW), Lz(cs, 'padding-left', cbW)
    b.bt, b.br, b.bb, b.bl = borderW(cs, 'top'), borderW(cs, 'right'), borderW(cs, 'bottom'), borderW(cs, 'left')
    b.mt = Lz(cs, 'margin-top', cbW); b.mb = Lz(cs, 'margin-bottom', cbW)
    b.ml = L(cs, 'margin-left', cbW); b.mr = L(cs, 'margin-right', cbW)
    b.mlAuto = cs.raw['margin-left'] == 'auto'; b.mrAuto = cs.raw['margin-right'] == 'auto'
    b.ml = b.ml or 0; b.mr = b.mr or 0
end
M.resolveEdges = resolveEdges

local function hEdges(b) return b.pl + b.pr + b.bl + b.br end
local function vEdges(b) return b.pt + b.pb + b.bt + b.bb end

local function isBFCRoot(b)
    local cs = b.cs
    if b.kind ~= 'block' then return true end
    if b.inlineLevel then return true end
    if b.pos == 'absolute' or b.pos == 'fixed' then return true end
    if cs.raw['overflow-x'] ~= 'visible' or cs.raw['overflow-y'] ~= 'visible' then return true end
    if b.isButton then return true end
    if b.isItem then return true end
    if b.el and b.el.tag == 'html' then return true end
    return false
end

local function outOfFlow(b) return b.pos == 'absolute' or b.pos == 'fixed' end

-- ---------------------------------------------------------------------------
-- 替换元素（img / canvas）的固有尺寸
-- ---------------------------------------------------------------------------
M.intrinsic = function(el)
    if el.tag == 'canvas' then return tonumber(el.attrs.width) or 300, tonumber(el.attrs.height) or 150 end
    if el.tag == 'img' then
        local src = el.attrs.src
        if src and M.imageSize then local w, h = M.imageSize(src); if w then return w, h end end
        return 0, 0
    end
    return 0, 0
end

local function aspectOf(b)
    local ar = b.cs.raw['aspect-ratio']
    if ar and ar ~= 'auto' then
        local a, c = ar:match('([%d%.]+)%s*/%s*([%d%.]+)')
        if a then return tonumber(a) / tonumber(c) end
        if tonumber(ar) then return tonumber(ar) end
    end
    if b.kind == 'replaced' then
        local iw, ih = M.intrinsic(b.el)
        if ih > 0 then return iw / ih end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- 固有尺寸（min-content / max-content，返回边框盒宽度）
-- ---------------------------------------------------------------------------
local intrinsicCache = setmetatable({}, { __mode = 'k' })
local inlineItems -- 前向声明

local function specifiedWidth(b, cbW)
    local w = L(b.cs, 'width', cbW)
    return w
end

local function clampW(b, w, cbW)
    local mx = L(b.cs, 'max-width', cbW)
    if mx and w > mx then w = mx end
    local mn = L(b.cs, 'min-width', cbW)
    if mn and w < mn then w = mn end
    return w
end

local intrinsicW
intrinsicW = function(b, which) -- which = 'min' | 'max'；返回外边距盒宽度
    local c = b.intr
    if c and c[which] then return c[which] end
    resolveEdges(b, nil)
    local cs = b.cs
    local edges = hEdges(b)
    local margins = (b.ml or 0) + (b.mr or 0)
    local w
    local sw = L(cs, 'width', nil)
    if b.kind == 'replaced' then
        local iw, ih = M.intrinsic(b.el)
        local sh = L(cs, 'height', nil)
        if sw then w = sw
        elseif sh then local ar = aspectOf(b); w = ar and sh * ar or iw
        else w = iw end
        if not (cs.raw.width or ''):match('%%') or sw then
            -- 百分比宽度的替换元素：最小内容贡献为 0（Chromium 的行为）
        end
        if (cs.raw.width or ''):match('%%') and which == 'min' then w = 0 end
    elseif sw then
        w = sw
    else
        local content = 0
        if b.kind == 'flex' then
            local dir = cs.raw['flex-direction']
            local row = dir == 'row' or dir == 'row-reverse'
            local wrap = cs.raw['flex-wrap'] ~= 'nowrap'
            local gap = (cs.raw['column-gap'] ~= 'normal') and Lz(cs, 'column-gap', nil) or 0
            local n = 0
            for _, k in ipairs(M.flexItems(b)) do
                do
                    local kw = intrinsicW(k, which)
                    if row and not (wrap and which == 'min') then content = content + kw; n = n + 1
                    else content = max(content, kw) end
                end
            end
            if row and not (wrap and which == 'min') and n > 1 then content = content + gap * (n - 1) end
        elseif b.kind == 'grid' then
            content = M.gridIntrinsic(b, which)
        else
            -- 块容器：行内内容或块级子元素
            local hasBlock = false
            for _, k in ipairs(b.children) do
                if not outOfFlow(k) and not k.inlineLevel and k.kind ~= 'text' and k.kind ~= 'inline' and k.kind ~= 'br' and k.kind ~= 'replaced' then hasBlock = true end
            end
            if hasBlock then
                for _, k in ipairs(b.children) do
                    if not outOfFlow(k) then content = max(content, intrinsicW(k, which)) end
                end
            else
                content = M.inlineIntrinsic(b, which)
            end
        end
        w = content + edges
    end
    w = clampW(b, w, nil)
    if w < edges then w = edges end
    w = w + margins
    c = c or {}
    c[which] = w
    b.intr = c
    return w
end
M.intrinsicW = intrinsicW

-- ---------------------------------------------------------------------------
-- 行内排版
-- ---------------------------------------------------------------------------
--- 把块容器里的行内内容拍平成「片段」列表
--- 片段：{ t='text', s=字符串, cps={码点}, cls={断行类}, adv={步进}, cs=样式, ib=所属行内盒链 }
---       { t='atom', box=盒 } / { t='br' }
inlineItems = function(b)
    local items = {}
    local prevSpace = true -- 行首空白要折叠
    local function walk(node, chain, nowrap)
        for _, k in ipairs(node.children) do
            if outOfFlow(k) then
                items[#items + 1] = { t = 'abs', box = k }
            elseif k.kind == 'text' then
                local cs = node.cs
                local ws = cs.raw['white-space']
                local cps, cls = {}, {}
                for _, cp in utf8.codes(k.text) do
                    if cp == 10 or cp == 9 or cp == 13 then cp = 32 end
                    if cp == 32 then
                        if not prevSpace then cps[#cps + 1] = 32; cls[#cls + 1] = 'SP'; prevSpace = true end
                    else
                        cps[#cps + 1] = cp; cls[#cls + 1] = TXT.classOf(cp); prevSpace = false
                    end
                end
                if #cps > 0 then
                    local a16 = {}
                    local fs, fw, ls = cs.fontSize, cs.fontWeight, cs.letterSpacing
                    local ls16 = ls * 65536
                    for i, cp in ipairs(cps) do a16[i] = TXT.adv16(cp, fs, fw) + ls16 end
                    items[#items + 1] = { t = 'text', cps = cps, cls = cls, a16 = a16, cs = cs, chain = chain, nowrap = nowrap or ws == 'nowrap' or ws == 'pre', node = k.node }
                end
            elseif k.kind == 'br' then
                items[#items + 1] = { t = 'br', chain = chain }
                prevSpace = true
            elseif k.kind == 'inline' then
                local ch2 = { k, up = chain }
                items[#items + 1] = { t = 'open', box = k, chain = ch2 }
                walk(k, ch2, nowrap or k.cs.raw['white-space'] == 'nowrap')
                items[#items + 1] = { t = 'close', box = k, chain = ch2 }
            else
                items[#items + 1] = { t = 'atom', box = k, chain = chain }
                prevSpace = false
            end
        end
    end
    walk(b, nil, b.cs.raw['white-space'] == 'nowrap')
    -- 全角标点挤压：跨行内元素边界，遇到原子盒 / 换行中断
    local pIt, pI = nil, nil
    for _, it in ipairs(items) do
        if it.t == 'text' then
            for i = 1, #it.cps do
                local cp = it.cps[i]
                if pIt then
                    local pcp = pIt.cps[pI]
                    if TXT.P_OPEN[cp] and TXT.P_PREV[pcp] then
                        local t16 = it.cs.fontSize * 32768
                        it.a16[i] = it.a16[i] - t16
                        it.dx = it.dx or {}
                        it.dx[i] = -t16 / 65536 -- 字形左移半个字宽
                    elseif (TXT.P_CLOSE[pcp] or TXT.P_DOT[pcp]) and TXT.P_NEXT[cp] and not (pIt.trimmed and pIt.trimmed[pI]) then
                        pIt.a16[pI] = pIt.a16[pI] - pIt.cs.fontSize * 32768
                        pIt.trimmed = pIt.trimmed or {}
                        pIt.trimmed[pI] = true
                    end
                end
                pIt, pI = it, i
            end
        elseif it.t == 'atom' or it.t == 'br' then
            pIt = nil
        end
    end
    return items
end
M.inlineItems = inlineItems

--- 宽度计量：同一文本项里连续的字符算一段，每段宽度向上取整到 1/64 像素（和 Chromium 一样）
local LU = TXT.lu
local function meterNew() return { c = 0, it = nil, last = 0, s = 0 } end
local function meterAdd(m, p)
    if p.t == 'ch' then
        if m.it == p.it and p.i == m.last + 1 then
            m.s = m.s + p.it.a16[p.i]
        else
            if m.it then m.c = m.c + LU(m.s) end
            m.it = p.it; m.s = p.it.a16[p.i]
        end
        m.last = p.i
    else
        if m.it then m.c = m.c + LU(m.s); m.it = nil; m.s = 0 end
        m.c = m.c + (p.w or 0)
    end
end
local function meterW(m) return m.c + (m.it and LU(m.s) or 0) end
local function meterCopy(m) return { c = m.c, it = m.it, last = m.last, s = m.s } end
local function measure(pieces, n)
    local m = meterNew()
    for k = 1, n do meterAdd(m, pieces[k]) end
    return meterW(m)
end
--- 末尾「可悬挂」部分之前的最后一个下标（空格、零宽标签、br、绝对定位占位）
local function lastSolid(pieces)
    local k = #pieces
    while k >= 1 do
        local p = pieces[k]
        if p.t == 'ch' then if p.it.cls[p.i] ~= 'SP' then break end
        elseif p.t == 'atom' then break
        elseif (p.t == 'open' or p.t == 'close') and p.w > 0 then break end
        k = k - 1
    end
    return k
end

--- 拆成「断行单元」：单元内部不可断行，单元之间可以断行
--- 单元：{ pieces = {...}, w = 宽度, trail = 末尾空格宽度, forced = 之后强制换行 }
--- piece：{ t='ch', it=文本项, i=下标, w } / { t='atom', box, w } / { t='open'|'close', box, w } / { t='abs', box } / { t='br' }
local function buildUnits(items, cw, b)
    local units = {}
    local cur = { pieces = {}, w = 0, trail = 0 }
    local lastCls = nil
    local lastNsp, prevCls = nil, nil -- 空格前最后一个非空白字符的类别、再前一个字符的类别
    local lastNowrap = false
    local function flush(carry)
        -- 断点处：末尾的「开标签」跟着后面的内容走
        local moved = nil
        if carry then
            local n = #cur.pieces
            local k = n
            while k >= 1 and cur.pieces[k].t == 'open' do k = k - 1 end
            if k < n and k >= 1 then
                moved = {}
                for j = k + 1, n do
                    local pc = cur.pieces[j]
                    moved[#moved + 1] = pc
                    cur.pieces[j] = nil
                    cur.w = cur.w - pc.w
                end
            end
        end
        if #cur.pieces > 0 then units[#units + 1] = cur end
        cur = { pieces = {}, w = 0, trail = 0 }
        if moved then
            for _, pc in ipairs(moved) do cur.pieces[#cur.pieces + 1] = pc; cur.w = cur.w + pc.w end
        end
    end
    -- 两个字符之间能否断行由它们最近的共同祖先的 white-space 决定
    local blockNowrap = function(bx) local ws = bx.cs.raw['white-space']; return ws == 'nowrap' or ws == 'pre' end
    local lastChain, lastItem = nil, nil
    local function commonNowrap(chA, chB, itB)
        if chA == chB then return itB.nowrap end
        local set = {}
        local c = chA
        while c do set[c[1]] = true; c = c.up end
        c = chB
        while c do
            if set[c[1]] then return blockNowrap(c[1]) or false end
            c = c.up
        end
        return blockNowrap(b) or false
    end
    for _, it in ipairs(items) do
        if it.t == 'text' then
            for i = 1, #it.cps do
                local c = it.cls[i]
                local nw
                if lastItem == it then nw = it.nowrap else nw = lastCls and commonNowrap(lastChain, it.chain, it) end
                if lastCls and not nw and TXT.canBreakBetween(lastCls, c, lastNsp, prevCls) then flush(true) end
                lastItem, lastChain = it, it.chain
                cur.pieces[#cur.pieces + 1] = { t = 'ch', it = it, i = i, w = 0 } -- 文字宽度由计量器按 a16 计算
                if lastCls ~= 'SP' and lastCls ~= nil then lastNsp = lastCls end
                if c ~= 'SP' and lastCls ~= 'SP' then lastNsp = nil end
                prevCls = lastCls
                lastCls = c
                lastNowrap = it.nowrap
            end
        elseif it.t == 'atom' then
            if lastCls and not (it.box.parent and it.box.parent.cs.raw['white-space'] == 'nowrap') then flush(true) end
            cur.pieces[#cur.pieces + 1] = { t = 'atom', box = it.box, w = 0, chain = it.chain }
            prevCls = lastCls
            lastCls = TXT.classOf(0x4E2D) -- 原子盒按表意文字处理
            lastItem, lastChain = it, it.chain
            lastNsp = nil
        elseif it.t == 'br' then
            cur.pieces[#cur.pieces + 1] = { t = 'br', chain = it.chain }
            cur.forced = true
            flush()
            lastCls = nil; lastNsp = nil; prevCls = nil
        elseif it.t == 'open' or it.t == 'close' then
            cur.pieces[#cur.pieces + 1] = { t = it.t, box = it.box, w = 0, chain = it.chain }
        elseif it.t == 'abs' then
            cur.pieces[#cur.pieces + 1] = { t = 'abs', box = it.box, w = 0 }
        end
    end
    flush()
    return units
end

--- 行内内容的缓存（盒子存活期间不变）：文本项与断行单元；每次排版前刷新可变部分
local function copyT(t) local r = {}; for k, v in pairs(t) do r[k] = v end; return r end
local function inlineCache(b)
    local c = b.inl
    if c then return c end
    local items = inlineItems(b)
    for _, it in ipairs(items) do
        if it.t == 'text' then
            it.a16b = table.move(it.a16, 1, #it.a16, 1, {})
            it.dxb = it.dx and copyT(it.dx) or nil
            it.trimmedb = it.trimmed and copyT(it.trimmed) or nil
        end
    end
    c = { items = items, units = buildUnits(items, nil, b) }
    b.inl = c
    return c
end
local function refreshInline(c, cw)
    for _, it in ipairs(c.items) do
        if it.t == 'text' then
            it.a16 = table.move(it.a16b, 1, #it.a16b, 1, {})
            it.dx = it.dxb and copyT(it.dxb) or nil
            it.trimmed = it.trimmedb and copyT(it.trimmedb) or nil
        elseif it.t == 'open' then
            it.box.ifr = nil
        end
    end
    for _, u in ipairs(c.units) do
        for _, p in ipairs(u.pieces) do
            local t = p.t
            if t == 'atom' then
                local bx = p.box
                p.w = bx.ml + bx.w + bx.mr
            elseif t == 'open' then
                local k = p.box
                resolveEdges(k, cw)
                p.w = k.ml + k.bl + k.pl
            elseif t == 'close' then
                local k = p.box
                resolveEdges(k, cw)
                p.w = k.mr + k.br + k.pr
            end
        end
        u.nt = lastSolid(u.pieces)
    end
end

--- 行内内容的固有宽度
function M.inlineIntrinsic(b, which)
    local ic = inlineCache(b)
    local items = ic.items
    for _, it in ipairs(items) do
        if it.t == 'atom' then
            local bx = it.box
            resolveEdges(bx, nil)
            local w = intrinsicW(bx, which)
            bx.ml, bx.mr = 0, 0
            bx.w = w
        end
    end
    refreshInline(ic, nil)
    local units = ic.units
    local best = 0
    if which == 'min' then
        for _, u in ipairs(units) do best = max(best, measure(u.pieces, u.nt)) end
    else
        local ps = {}
        local function done()
            best = max(best, measure(ps, lastSolid(ps)))
            ps = {}
        end
        for _, u in ipairs(units) do
            for _, p in ipairs(u.pieces) do ps[#ps + 1] = p end
            if u.forced then done() end
        end
        done()
    end
    return best
end

--- 一个行内盒在行上的垂直范围（相对基线：above / below）
local function inlineBoxExtent(cs)
    local fs = cs.fontSize
    local asc, desc = TXT.metrics(fs)
    if not cs.lineHeight then return asc, desc end
    -- Chromium：行高截断到 1/64 像素；上半行距 = floor((行高 - 内容高) / 2)，余下的给下半
    local L = cs.lineHeight * 64
    L = L >= 0 and math.floor(L) or math.ceil(L)
    local d = L - (asc + desc) * 64
    local halfRaw = d >= 0 and (d // 2) or -((-d) // 2) -- C++ 整数除法向零截断
    local up = math.floor(halfRaw / 64)
    local down = (d - up * 64) / 64
    return asc + up, desc + down
end
M.inlineBoxExtent = inlineBoxExtent

--- 原子行内盒的基线（相对其外边距盒顶部）
local function atomBaseline(box)
    if box.kind == 'replaced' then return box.mt + box.h end
    if box.firstBaseline and (box.kind == 'flex' or box.isButton or box.kind == 'grid') then
        return box.mt + box.firstBaseline
    end
    if box.lastBaseline and box.cs.raw['overflow-x'] == 'visible' and box.cs.raw['overflow-y'] == 'visible' then
        return box.mt + box.lastBaseline
    end
    return box.mt + box.h + box.mb
end

--- 在宽度 cw 内排出行盒；返回总高度。行和片段坐标相对内容盒左上角
local layoutBox -- 前向声明
function M.layoutInline(b, cw)
    local ic = inlineCache(b)
    local items = ic.items
    local cs = b.cs
    local align = cs.raw['text-align']
    if align == 'start' then align = 'left' end
    -- 原子盒先排版（得到尺寸）
    for _, it in ipairs(items) do
        if it.t == 'atom' then layoutBox(it.box, cw, nil, { shrink = true, avail = cw }) end
    end
    refreshInline(ic, cw)
    local units = ic.units
    -- 贪心分行
    local rawLines = {}
    local line = { pieces = {} }
    local meter = meterNew()
    local EPS = 1 / 64 + 1e-6 -- Chromium：AvailableWidth().AddEpsilon()
    local function candW(u)
        local c = meterCopy(meter)
        for k = 1, u.nt do meterAdd(c, u.pieces[k]) end
        return meterW(c)
    end
    -- 行尾闭括号：放不下时可以挤掉右半边（allow-end）
    local function endTrimPiece(u)
        local k = u.nt
        while k >= 1 and u.pieces[k].t == 'close' do k = k - 1 end
        local pc = u.pieces[k]
        if pc and pc.t == 'ch' and TXT.P_CLOSE[pc.it.cps[pc.i]] and not (pc.it.trimmed and pc.it.trimmed[pc.i]) then return pc end
    end
    -- 返回：nil 不需要 / 'ok' 已挤压 / 'quirk' 文本项末尾的闭括号（Chromium 认为放得下，实际按原宽排版并回退到该项之前的断点）
    local nextOf = {}
    for k = 1, #items - 1 do nextOf[items[k]] = items[k + 1] end
    local function tryTrim(u)
        if candW(u) <= cw + EPS then return nil end
        local pc = endTrimPiece(u)
        if not pc then return nil end
        local it, i = pc.it, pc.i
        local t16 = it.cs.fontSize * 32768
        it.a16[i] = it.a16[i] - t16
        local fits = candW(u) <= cw + EPS
        if fits and i == #it.cps then
            it.a16[i] = it.a16[i] + t16
            local nx = nextOf[it]
            while nx and (nx.t == 'close' or nx.t == 'open') do nx = nextOf[nx] end
            if nx and nx.t == 'br' then return nil end
            return 'quirk', it
        end
        if fits then
            it.trimmed = it.trimmed or {}
            it.trimmed[i] = true
            return 'ok'
        end
        it.a16[i] = it.a16[i] + t16
        return nil
    end
    local function newLine()
        rawLines[#rawLines + 1] = line
        line = { pieces = {}, units = {} }
        meter = meterNew()
    end
    -- 行首的开括号不挤压（撤销相邻挤压）
    local function untrimStart(u)
        for _, p in ipairs(u.pieces) do
            if p.t == 'ch' then
                local it, i = p.it, p.i
                if it.dx and it.dx[i] then
                    it.a16[i] = it.a16[i] - it.dx[i] * 65536
                    it.dx[i] = nil
                end
                return
            elseif p.t == 'atom' then return end
        end
    end
    local function addUnit(u)
        if #line.units == 0 then untrimStart(u) end
        line.units[#line.units + 1] = u
        for _, p in ipairs(u.pieces) do line.pieces[#line.pieces + 1] = p; meterAdd(meter, p) end
    end
    line.units = {}
    for _, u in ipairs(units) do
        local hasContent = meterW(meter) > 0.0001
        local r, qit = tryTrim(u)
        if r == 'quirk' then
            -- 回退到该文本项之前的最后一个断点
            local k = nil
            for j, lu in ipairs(line.units) do
                for _, p in ipairs(lu.pieces) do if p.t == 'ch' and p.it == qit then k = j; break end end
                if k then break end
            end
            if k == nil then k = #line.units + 1 end
            if k > 1 then
                local moved = {}
                for j = k, #line.units do moved[#moved + 1] = line.units[j] end
                local keep = {}
                for j = 1, k - 1 do keep[j] = line.units[j] end
                line = { pieces = {}, units = {} }
                meter = meterNew()
                for _, lu in ipairs(keep) do addUnit(lu) end
                newLine()
                for _, lu in ipairs(moved) do addUnit(lu) end
            end
            addUnit(u) -- 放不下也留在这一行（溢出）
        else
            if hasContent and candW(u) > cw + EPS then
                newLine()
                untrimStart(u)
                tryTrim(u)
            end
            addUnit(u)
        end
        if u.forced then
            line.forced = true
            newLine()
        end
    end
    rawLines[#rawLines + 1] = line
    -- 去掉行首 / 行尾空格，转成片段
    local lines = {}
    local absPending = {}
    for _, rl in ipairs(rawLines) do
        local ps = rl.pieces
        local s, e = 1, #ps
        while s <= e and ps[s].t == 'ch' and ps[s].it.cls[ps[s].i] == 'SP' do s = s + 1 end
        while e >= s and ((ps[e].t == 'ch' and ps[e].it.cls[ps[e].i] == 'SP') or ps[e].t == 'br' and false) do e = e - 1 end
        -- 行尾空格（在 br 前面的也去掉）
        local frags = {}
        local x = 0
        local hasContent = false
        local curText = nil
        for pi = 1, #ps do
            local p = ps[pi]
            local inRange = pi >= s and pi <= e
            if p.t == 'ch' then
                if inRange then
                    local a = p.it.a16[p.i]
                    if curText and curText.it == p.it and curText.i1 == p.i - 1 then
                        curText.i1 = p.i; curText.s16 = curText.s16 + a
                    else
                        curText = { t = 'text', it = p.it, cs = p.it.cs, i0 = p.i, i1 = p.i, x = x, s16 = a, chain = p.it.chain, a16 = p.it.a16, dx = p.it.dx }
                        frags[#frags + 1] = curText
                    end
                    curText.w = LU(curText.s16)
                    x = curText.x + curText.w
                    hasContent = true
                end
            else
                curText = nil
                if p.t == 'atom' then
                    frags[#frags + 1] = { t = 'atom', box = p.box, x = x, w = p.w, chain = p.chain }
                    x = x + p.w
                    hasContent = true
                elseif p.t == 'open' or p.t == 'close' then
                    frags[#frags + 1] = { t = p.t, box = p.box, x = x, w = p.w, chain = p.chain }
                    x = x + p.w
                    if p.w > 0 then hasContent = true end
                elseif p.t == 'br' then
                    frags[#frags + 1] = { t = 'br', x = x, w = 0, chain = p.chain }
                    hasContent = true
                elseif p.t == 'abs' then
                    frags[#frags + 1] = { t = 'abs', box = p.box, x = x, w = 0 }
                end
            end
        end
        if hasContent then
            lines[#lines + 1] = { frags = frags, w = x }
        else
            for _, f in ipairs(frags) do if f.t == 'abs' then absPending[#absPending + 1] = f.box end end
        end
    end

    -- 行高与基线
    local rootA, rootD = inlineBoxExtent(cs)
    local y = 0
    local firstBaseline, lastBaseline = nil, nil
    for _, ln in ipairs(lines) do
        local above, below = rootA, rootD
        local seen = {}
        local function addChain(ch)
            while ch do
                local ib = ch[1]
                if not seen[ib] then
                    seen[ib] = true
                    local a, d = inlineBoxExtent(ib.cs)
                    local va = ib.cs.raw['vertical-align']
                    local shift = 0
                    if va ~= 'baseline' and va ~= 'middle' then shift = L(ib.cs, 'vertical-align', ib.cs.lineHeight or ib.cs.fontSize) or 0 end
                    ib.vaShift = shift
                    above = max(above, a + shift); below = max(below, d - shift)
                end
                ch = ch.up
            end
        end
        for _, fr in ipairs(ln.frags) do
            if fr.chain then addChain(fr.chain) end
            if fr.t == 'atom' then
                local bx = fr.box
                local va = bx.cs.raw['vertical-align']
                local bh = bx.mt + bx.h + bx.mb
                local base = atomBaseline(bx)
                local a, d
                if va == 'middle' then
                    local pcs = (fr.chain and fr.chain[1].cs) or cs
                    local _, _, xh = TXT.metrics(pcs.fontSize)
                    a = bh / 2 + xh / 2; d = bh - a
                else
                    a = base; d = bh - base
                    if va ~= 'baseline' then
                        local sh = L(bx.cs, 'vertical-align', bx.cs.lineHeight or bx.cs.fontSize) or 0
                        a = a + sh; d = d - sh
                    end
                end
                fr.above = a
                above = max(above, a); below = max(below, d)
            end
        end
        ln.y = y
        ln.baseline = y + above
        ln.h = above + below
        y = y + ln.h
        if not firstBaseline then firstBaseline = ln.baseline end
        lastBaseline = ln.baseline
        -- 水平对齐
        local off = 0
        if align == 'center' then off = (cw - ln.w) / 2
        elseif align == 'right' or align == 'end' then off = cw - ln.w end
        ln.x = off
        for _, fr in ipairs(ln.frags) do
            if fr.t == 'atom' then
                local bx = fr.box
                bx.rx = off + fr.x + bx.ml -- 相对内容盒（稍后加上内容盒偏移）
                bx.ry = ln.baseline - fr.above + bx.mt
                bx.inLine = true
            elseif fr.t == 'abs' then
                fr.box.staticX = off + fr.x; fr.box.staticY = ln.y
            end
        end
        -- 行内盒在这一行上的片段（边框盒，相对内容盒）
        local spans = {}
        local order = {}
        local function cover(ib, x0, x1)
            local sp = spans[ib]
            if not sp then sp = { x0 = x0, x1 = x1 }; spans[ib] = sp; order[#order + 1] = ib
            else if x0 < sp.x0 then sp.x0 = x0 end; if x1 > sp.x1 then sp.x1 = x1 end end
            return sp
        end
        for _, fr in ipairs(ln.frags) do
            local ch = fr.chain
            if fr.t == 'open' or fr.t == 'close' then ch = ch and ch.up end
            while ch do cover(ch[1], off + fr.x, off + fr.x + fr.w); ch = ch.up end
            if fr.t == 'open' then
                local ib = fr.box
                local sp = cover(ib, off + fr.x + ib.ml, off + fr.x + fr.w)
                sp.open = off + fr.x + ib.ml
            elseif fr.t == 'close' then
                local ib = fr.box
                local sp = cover(ib, off + fr.x, off + fr.x + ib.pr + ib.br)
                sp.close = off + fr.x + ib.pr + ib.br
            end
        end
        for _, ib in ipairs(order) do
            local sp = spans[ib]
            local x0, x1 = sp.open or sp.x0, sp.close or sp.x1
            local asc, desc = TXT.metrics(ib.cs.fontSize)
            local top = ln.baseline - (ib.vaShift or 0) - asc - ib.pt - ib.bt
            local hh = asc + desc + ib.pt + ib.pb + ib.bt + ib.bb
            ib.ifr = ib.ifr or {}
            ib.ifr[#ib.ifr + 1] = { x = x0, y = top, w = x1 - x0, h = hh, first = sp.open ~= nil, last = sp.close ~= nil }
            ib.ifrOwner = b
        end
    end
    for _, ab in ipairs(absPending) do ab.staticX = 0; ab.staticY = y end
    b.lines = lines
    b.firstBaseline = firstBaseline
    b.lastBaseline = lastBaseline
    return y
end

-- ---------------------------------------------------------------------------
-- 通用排版入口
-- opts: { w = 强制边框盒宽, h = 强制边框盒高, shrink = 收缩适应, avail = 可用宽度, cbH = 包含块高度 }
-- ---------------------------------------------------------------------------
local layoutBlockChildren, layoutFlex, layoutGrid

local function contentHeightFromChildren(b, cw, ch)
    if b.kind == 'flex' then return layoutFlex(b, cw, ch)
    elseif b.kind == 'grid' then return layoutGrid(b, cw, ch)
    else return layoutBlockChildren(b, cw, ch) end
end

local function hasBlockChildren(b)
    for _, k in ipairs(b.children) do
        if not outOfFlow(k) and not k.inlineLevel and (k.kind == 'block' or k.kind == 'flex' or k.kind == 'grid') then return true end
    end
    return false
end

-- 记忆化：同一个盒子、同样的输入，排版结果相同。命中时只恢复盒子自身的字段；
-- 子孙的状态若不是这次输入对应的（stateKey ~= servedKey），finalize 时再补排一次
local MEMO_FIELDS = { 'w', 'h', 'pt', 'pr', 'pb', 'pl', 'bt', 'br', 'bb', 'bl', 'mt', 'mb', 'ml', 'mr', 'mlAuto', 'mrAuto',
    'cbH', 'contentW', 'contentH', 'lines', 'firstBaseline', 'lastBaseline', 'btnShift', 'lineOX', 'lineOY', 'scrollH',
    'collapsedTop', 'collapsedBottom', 'flow', 'flexItemsList', 'gridItemsList' }
local NMEMO = #MEMO_FIELDS
local function memoKey(cbW, cbH, opts)
    return string.format('%s|%s|%s|%s|%s|%s|%s', cbW, cbH, opts.w, opts.h, opts.shrink and 1 or 0, opts.avail, opts.hIndef and 1 or 0)
end
M.memoStats = { hit = 0, miss = 0 }
local layoutBoxRaw
layoutBox = function(b, cbW, cbH, opts)
    opts = opts or {}
    local key = memoKey(cbW, cbH, opts)
    b.servedKey = key
    b.servedArgs = { cbW, cbH, opts }
    local memo = b.memo
    local m = memo and memo[key]
    if m then
        for i = 1, NMEMO do local f = MEMO_FIELDS[i]; b[f] = m[f] end
        M.memoStats.hit = M.memoStats.hit + 1
        return b
    end
    M.memoStats.miss = M.memoStats.miss + 1
    layoutBoxRaw(b, cbW, cbH, opts)
    b.stateKey = key
    m = {}
    for i = 1, NMEMO do local f = MEMO_FIELDS[i]; m[f] = b[f] end
    if not memo then memo = {}; b.memo = memo end
    memo[key] = m
    return b
end
--- 补排：子孙状态与最后一次输入不一致时，按最后一次输入完整重排
local function ensureState(b)
    if b.servedKey and b.servedKey ~= b.stateKey then
        local a = b.servedArgs
        layoutBoxRaw(b, a[1], a[2], a[3])
        b.stateKey = b.servedKey
    end
end
M.ensureState = ensureState
layoutBoxRaw = function(b, cbW, cbH, opts)
    local cs = b.cs
    resolveEdges(b, cbW)
    b.cbH = cbH
    local edgesH, edgesV = hEdges(b), vEdges(b)
    -- 宽度
    local w
    local ar = aspectOf(b)
    local sh = L(cs, 'height', cbH)
    if opts.w then w = opts.w
    else
        local sw = L(cs, 'width', cbW)
        if sw then w = sw
        elseif b.kind == 'replaced' then
            local iw, ih = M.intrinsic(b.el)
            if sh then w = ar and sh * ar or iw else w = iw end
        elseif opts.shrink then
            local avail = (opts.avail or cbW or 0) - b.ml - b.mr
            local mnc = intrinsicW(b, 'min') - b.ml - b.mr
            local mxc = intrinsicW(b, 'max') - b.ml - b.mr
            w = min(max(mnc, avail), mxc)
        else
            w = (cbW or 0) - b.ml - b.mr
        end
        w = clampW(b, w, cbW)
    end
    if w < edgesH then w = edgesH end
    b.w = w
    -- 块级元素的 auto 外边距（居中）
    if not opts.w and not b.inlineLevel and not b.isItem and cbW and (b.mlAuto or b.mrAuto) and not opts.shrink then
        local free = cbW - w - (b.mlAuto and 0 or b.ml) - (b.mrAuto and 0 or b.mr)
        if b.mlAuto and b.mrAuto then b.ml = free / 2; b.mr = free / 2
        elseif b.mlAuto then b.ml = free
        else b.mr = free end
    end
    local cw = w - edgesH
    -- 高度
    local fixedH = opts.h
    if not fixedH then
        if sh then fixedH = sh
        elseif b.kind == 'replaced' and ar then fixedH = w / ar
        elseif ar and not sh then fixedH = w / ar end
        if fixedH then
            local mx = L(cs, 'max-height', cbH)
            if mx and fixedH > mx then fixedH = mx end
            local mn = L(cs, 'min-height', cbH)
            if mn and fixedH < mn then fixedH = mn end
        end
    end
    local chDef = fixedH and (fixedH - edgesV) or nil
    if opts.hIndef then chDef = nil end -- 列方向弹性容器高度不定时，项目伸缩后的高度不算「确定」
    -- min-height 作为子元素百分比基准时不算确定高度，但 flex 列容器需要知道
    b.contentW = cw
    local contentH = 0
    b.lines = nil
    b.firstBaseline, b.lastBaseline = nil, nil
    if b.kind == 'replaced' then
        contentH = 0
    elseif b.kind == 'flex' or b.kind == 'grid' then
        contentH = contentHeightFromChildren(b, cw, chDef)
    elseif hasBlockChildren(b) then
        contentH = layoutBlockChildren(b, cw, chDef)
    else
        contentH = M.layoutInline(b, cw)
        -- 按钮：内容在内容盒里垂直居中（和 Chromium 的按钮一样）
    end
    local h
    if fixedH then h = fixedH
    else
        h = contentH + edgesV
        local mx = L(cs, 'max-height', cbH)
        if mx and h > mx then h = mx end
        local mn = L(cs, 'min-height', cbH)
        if mn and h < mn then h = mn end
    end
    if h < edgesV then h = edgesV end
    -- 按钮内容垂直居中
    if b.isButton and b.kind == 'block' then
        local extra = (h - edgesV) - contentH
        b.btnShift = extra > 0 and extra / 2 or 0
        if b.firstBaseline then b.firstBaseline = b.firstBaseline + b.btnShift + b.bt + b.pt end
        if b.lastBaseline then b.lastBaseline = b.lastBaseline + b.btnShift + b.bt + b.pt end
    else
        b.btnShift = 0
        if b.kind == 'block' and b.lines then
            if b.firstBaseline then b.firstBaseline = b.firstBaseline + b.bt + b.pt end
            if b.lastBaseline then b.lastBaseline = b.lastBaseline + b.bt + b.pt end
        end
    end
    b.h = h
    b.contentH = contentH
    -- 行内原子盒的位置加上内容盒偏移
    if b.lines then
        for _, ln in ipairs(b.lines) do
            for _, fr in ipairs(ln.frags) do
                if fr.t == 'atom' then
                    fr.box.rx = fr.box.rx + b.bl + b.pl
                    fr.box.ry = fr.box.ry + b.bt + b.pt + b.btnShift
                end
            end
        end
        b.lineOX, b.lineOY = b.bl + b.pl, b.bt + b.pt + b.btnShift
    end
    -- 滚动范围
    b.scrollH = max(contentH + edgesV, h)
    return b
end
M.layoutBox = layoutBox

-- ---------------------------------------------------------------------------
-- 块级子元素堆叠（含外边距折叠）
-- ---------------------------------------------------------------------------
layoutBlockChildren = function(b, cw, ch)
    local y = 0
    local pending = nil -- 待折叠的外边距
    local first = true
    local canTop = not isBFCRoot(b) and b.bt == 0 and b.pt == 0
    b.collapsedTop = nil
    local lastInFlow = nil
    local anyContent = false
    -- 行内子元素混在块级里时，包成匿名块
    local seq = {}
    local run = nil
    for _, k in ipairs(b.children) do
        if outOfFlow(k) then
            seq[#seq + 1] = k
        elseif k.inlineLevel or k.kind == 'text' or k.kind == 'inline' or k.kind == 'br' or k.kind == 'replaced' then
            if k.kind == 'text' and not k.text:match('%S') and not run then
                -- 块之间的纯空白文本忽略
            else
                if not run then
                    run = newBox(nil, anonCs(b.cs), 'block')
                    run.anon = true
                    run.parent = b
                    seq[#seq + 1] = run
                end
                run.children[#run.children + 1] = k
            end
        else
            run = nil
            seq[#seq + 1] = k
        end
    end
    -- 去掉只含空白的匿名块
    local seq2 = {}
    for _, k in ipairs(seq) do
        if k.anon then
            local has = false
            for _, c in ipairs(k.children) do if not (c.kind == 'text' and not c.text:match('%S')) then has = true end end
            if has then seq2[#seq2 + 1] = k end
        else seq2[#seq2 + 1] = k end
    end
    b.flow = seq2
    for _, k in ipairs(seq2) do
        if outOfFlow(k) then
            k.staticX = 0
            k.staticY = y + (pending or 0)
        else
            layoutBox(k, cw, ch, {})
            local kmt = k.collapsedTop or k.mt
            local kmb = k.collapsedBottom or k.mb
            -- 能穿透折叠的空盒
            local empty = k.h == 0 and k.kind == 'block' and not isBFCRoot(k) and (not k.lines or #k.lines == 0) and (#(k.flow or {}) == 0)
            if empty then
                pending = collapse(pending or 0, collapse(kmt, kmb))
                k.rx = k.ml
                k.ry = y
            else
                local m
                if first and canTop then
                    b.collapsedTop = collapse(b.mt, collapse(pending or 0, kmt))
                    m = 0
                else
                    m = collapse(pending or 0, kmt)
                end
                first = false
                k.rx = b.bl + b.pl + k.ml
                y = y + m
                k.ry = b.bt + b.pt + y
                y = y + k.h
                pending = kmb
                anyContent = true
                lastInFlow = k
            end
        end
    end
    -- 末尾外边距
    local hAuto = isAuto(b.cs, 'height') and not ch
    local canBottom = not isBFCRoot(b) and b.bb == 0 and b.pb == 0 and hAuto
    if pending then
        if canBottom and anyContent then
            b.collapsedBottom = collapse(b.mb, pending)
        elseif canBottom and not anyContent and canTop then
            -- 整个盒子都是空的：上下外边距一起折叠
            b.collapsedTop = collapse(b.mt, pending)
            b.collapsedBottom = 0
        else
            y = y + pending
            b.collapsedBottom = nil
        end
    else
        b.collapsedBottom = nil
    end
    -- 基线：取最后一个行内内容
    if lastInFlow and lastInFlow.lastBaseline then
        b.lastBaseline = lastInFlow.ry + lastInFlow.lastBaseline
    end
    for _, k in ipairs(seq2) do
        if not outOfFlow(k) and k.firstBaseline then b.firstBaseline = k.ry + k.firstBaseline; break end
    end
    return y
end

-- Flexbox / Grid 保持原定义顺序，传入已初始化的共享引用。
layoutFlex, layoutGrid = require("ui.layout_flex_grid")(M, {
    CSS = CSS, Expr = Expr, ENV = ENV,
    L = L, outOfFlow = outOfFlow, newBox = newBox, anonCs = anonCs,
    resolveEdges = resolveEdges, vEdges = vEdges,
    intrinsicW = intrinsicW, aspectOf = aspectOf, layoutBox = layoutBox, isAuto = isAuto,
    floor = floor, max = max, min = min, abs = abs, huge = huge,
})

-- ---------------------------------------------------------------------------
-- 绝对坐标、定位元素、相对偏移
-- ---------------------------------------------------------------------------
local function isPositioned(b) return b.pos and b.pos ~= 'static' end

--- 布局一个绝对 / 固定定位盒（包含块：cb 的内边距盒）
local function layoutAbs(b, cbX, cbY, cbW, cbH, staticAx, staticAy)
    local cs = b.cs
    resolveEdges(b, cbW)
    local left, right = L(cs, 'left', cbW), L(cs, 'right', cbW)
    local top, bottom = L(cs, 'top', cbH), L(cs, 'bottom', cbH)
    local sw = L(cs, 'width', cbW)
    local opts = {}
    if sw then opts.w = clampW(b, sw, cbW)
    elseif left and right and b.kind ~= 'replaced' then opts.w = cbW - left - right - b.ml - b.mr
    elseif b.kind ~= 'replaced' then opts.shrink = true; opts.avail = cbW - (left or 0) - (right or 0) end
    local shv = L(cs, 'height', cbH)
    if not shv and top and bottom and b.kind ~= 'replaced' then opts.h = cbH - top - bottom - b.mt - b.mb end
    layoutBox(b, cbW, cbH, opts)
    local ax, ay
    if left then ax = cbX + left + b.ml
    elseif right then ax = cbX + cbW - right - b.mr - b.w
    else ax = staticAx + b.ml end
    if top then ay = cbY + top + b.mt
    elseif bottom then ay = cbY + cbH - bottom - b.mb - b.h
    else ay = staticAy + b.mt end
    return ax, ay
end

--- 计算整棵树的绝对坐标；定位元素在这里布局
-- 第十五次更新（卡顿）：walk 里的 mark / childAbs 以前是每个盒子新建一次的闭包（每次重排上千个），改成外层函数
local finStickies
local finWalk
local function finMark(node, b, childSc)
    for _, c in ipairs(node.children) do
        if c.kind ~= 'text' then
            c.sc = (c.pos == 'fixed') and nil or childSc
            c.cbBox = b
            if c.kind == 'inline' or c.anon then finMark(c, b, childSc) end
        end
    end
end
local function finChildAbs(k, b, ax, ay, myCb, cbFixed)
    if k.pos == 'absolute' or k.pos == 'fixed' then
        local cb = (k.pos == 'fixed') and cbFixed or myCb
        local sx = ax + b.bl + b.pl + (k.staticX or 0)
        local sy = ay + b.bt + b.pt + (k.staticY or 0)
        local kx, ky = layoutAbs(k, cb.x, cb.y, cb.w, cb.h, sx, sy)
        if k.pos == 'fixed' then k.fixed = true end
        finWalk(k, kx, ky, myCb, cbFixed)
    else
        local kx, ky = ax + (k.rx or 0), ay + (k.ry or 0)
        if k.pos == 'relative' then
            local cs = k.cs
            local l, r = L(cs, 'left', b.contentW), L(cs, 'right', b.contentW)
            local t, bt = L(cs, 'top', b.contentH), L(cs, 'bottom', b.contentH)
            if l then kx = kx + l elseif r then kx = kx - r end
            if t then ky = ky + t elseif bt then ky = ky - bt end
        end
        finWalk(k, kx, ky, myCb, cbFixed)
    end
end
function M.finalize(root, vw, vh)
    local stickies = {}
    root.stickies = stickies
    root.sc = nil
    finStickies = stickies
    local walk = finWalk
    local vp = { x = 0, y = 0, w = vw, h = vh }
    walk(root, 0, 0, vp, vp)
    finStickies = nil
    M.computeSticky(root)
end
finWalk = function(b, ax, ay, cbAbs, cbFixed)
        local walk = finWalk
        ensureState(b)
        b.ax, b.ay = ax, ay
        if b.pos == 'sticky' then finStickies[#finStickies + 1] = b end
        -- 记下每个子孙的滚动容器与包含块（粘性定位要用）
        do
            local ox, oy = b.cs.raw['overflow-x'], b.cs.raw['overflow-y']
            local childSc = ((ox and ox ~= 'visible') or (oy and oy ~= 'visible')) and b or b.sc
            finMark(b, b, childSc)
            if b.flow then for _, k in ipairs(b.flow) do if k.anon then k.sc = childSc; k.cbBox = b; finMark(k, b, childSc) end end end
        end
        -- 相对定位偏移
        -- 子元素的包含块
        local myCb = cbAbs
        if isPositioned(b) then
            local c = b.finCb -- 包含块表按盒子复用
            if not c then c = {}; b.finCb = c end
            c.x, c.y, c.w, c.h, c.box = ax + b.bl, ay + b.bt, b.w - b.bl - b.br, b.h - b.bt - b.bb, b
            myCb = c
        end
        if b.kind == 'block' and b.flow then
            for _, k in ipairs(b.flow) do
                if k.anon then
                    k.ax, k.ay = ax + (k.rx or 0), ay + (k.ry or 0)
                    local abx, aby = k.ax, k.ay
                    for _, kk in ipairs(k.children) do
                        if kk.kind ~= 'text' and kk.kind ~= 'inline' and kk.kind ~= 'br' then
                            if kk.pos == 'absolute' or kk.pos == 'fixed' then
                                local cb = (kk.pos == 'fixed') and cbFixed or myCb
                                local kx, ky = layoutAbs(kk, cb.x, cb.y, cb.w, cb.h, abx + (kk.staticX or 0), aby + (kk.staticY or 0))
                                walk(kk, kx, ky, myCb, cbFixed)
                            else
                                walk(kk, abx + (kk.rx or 0), aby + (kk.ry or 0), myCb, cbFixed)
                            end
                        end
                    end
                    -- 匿名块里行内元素中的原子盒
                    M.walkInlineAtoms(k, abx, aby, myCb, cbFixed, walk, layoutAbs)
                else
                    finChildAbs(k, b, ax, ay, myCb, cbFixed)
                end
            end
        elseif b.kind == 'flex' and b.flexItemsList then
            for _, k in ipairs(b.flexItemsList) do finChildAbs(k, b, ax, ay, myCb, cbFixed) end
            for _, k in ipairs(b.children) do if outOfFlow(k) then finChildAbs(k, b, ax, ay, myCb, cbFixed) end end
        elseif b.kind == 'grid' and b.gridItemsList then
            for _, k in ipairs(b.gridItemsList) do finChildAbs(k, b, ax, ay, myCb, cbFixed) end
            for _, k in ipairs(b.children) do if outOfFlow(k) then finChildAbs(k, b, ax, ay, myCb, cbFixed) end end
        else
            -- 行内内容：原子盒与行内元素里的原子盒
            for _, k in ipairs(b.children) do
                if k.kind ~= 'text' and k.kind ~= 'inline' and k.kind ~= 'br' then finChildAbs(k, b, ax, ay, myCb, cbFixed) end
            end
            M.walkInlineAtoms(b, ax, ay, myCb, cbFixed, walk, layoutAbs, true)
        end
end

--- 粘性定位偏移（随滚动位置变化；滚动后重新调用）
--- 约束矩形 = 滚动容器的内容盒（视口坐标）；不能移出包含块的内容盒（含外边距）
function M.computeSticky(root)
    for _, b in ipairs(root.stickies or {}) do
        local cs = b.cs
        local sc = b.sc
        local st = 0
        local vt, vb
        if sc then
            st = sc.scrollTop or 0
            vt = sc.ay + sc.bt + sc.pt
            vb = sc.ay + sc.h - sc.bb - sc.pb
        else
            vt, vb = 0, ENV.vh
        end
        local y = b.ay - st
        local cb = b.cbBox
        local cbTop, cbBot = -math.huge, math.huge
        if cb then
            cbTop = cb.ay + cb.bt + cb.pt - st
            local inner = cb.h - cb.bt - cb.bb - cb.pt - cb.pb
            if cb == sc then inner = math.max(inner, (cb.scrollH or cb.h) - cb.bt - cb.bb - cb.pt - cb.pb) end
            cbBot = cbTop + inner
        end
        local dy = 0
        local T = L(cs, 'top', sc and (vb - vt) or ENV.vh)
        local B = L(cs, 'bottom', sc and (vb - vt) or ENV.vh)
        if B then
            local lim = vb - B
            if y + b.h > lim then
                dy = lim - (y + b.h)
                dy = math.max(dy, cbTop + b.mt - y)
                if dy > 0 then dy = 0 end
            end
        end
        if T then
            local lim = vt + T
            if y + dy < lim then
                dy = lim - y
                dy = math.min(dy, cbBot - b.mb - (y + b.h))
                if dy < 0 then dy = 0 end
            end
        end
        b.stickyDY = dy
    end
end

--- 行内元素内部的原子盒 / 定位盒
-- 第十五次更新（卡顿）：递归函数提到外面，不再每次调用新建闭包
local function inlineAtomsRec(node, direct, b, ax, ay, myCb, cbFixed, walk, layoutAbsFn)
    for _, k in ipairs(node.children) do
        if k.kind == 'inline' then
            inlineAtomsRec(k, false, b, ax, ay, myCb, cbFixed, walk, layoutAbsFn)
        elseif k.kind ~= 'text' and k.kind ~= 'br' and not direct then
            if k.pos == 'absolute' or k.pos == 'fixed' then
                local cb = (k.pos == 'fixed') and cbFixed or myCb
                local kx, ky = layoutAbsFn(k, cb.x, cb.y, cb.w, cb.h, ax + b.bl + b.pl + (k.staticX or 0), ay + b.bt + b.pt + (k.staticY or 0))
                walk(k, kx, ky, myCb, cbFixed)
            else
                walk(k, ax + (k.rx or 0), ay + (k.ry or 0), myCb, cbFixed)
            end
        end
    end
end
function M.walkInlineAtoms(b, ax, ay, myCb, cbFixed, walk, layoutAbsFn, skipDirect)
    inlineAtomsRec(b, skipDirect, b, ax, ay, myCb, cbFixed, walk, layoutAbsFn)
end

-- ---------------------------------------------------------------------------
-- 整页排版
-- ---------------------------------------------------------------------------
function M.layoutDocument(rootBox, vw, vh, envVars)
    ENV.vw, ENV.vh = vw, vh
    if envVars then ENV.envVars = envVars end
    layoutBox(rootBox, vw, vh, { w = vw })
    rootBox.rx, rootBox.ry = 0, 0
    M.finalize(rootBox, vw, vh)
end

return M
