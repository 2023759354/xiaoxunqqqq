-- Flexbox / Grid：由 layout.lua 原位注入同一模块、环境和辅助函数引用。
---@param M table<string, any>
---@param deps table<string, any>
return function(M, deps)
local CSS, Expr, ENV = deps.CSS, deps.Expr, deps.ENV
local L, outOfFlow, newBox, anonCs = deps.L, deps.outOfFlow, deps.newBox, deps.anonCs
local resolveEdges, vEdges = deps.resolveEdges, deps.vEdges
local intrinsicW, aspectOf, layoutBox, isAuto = deps.intrinsicW, deps.aspectOf, deps.layoutBox, deps.isAuto
local floor, max, min, abs, huge = deps.floor, deps.max, deps.min, deps.abs, deps.huge
local layoutFlex, layoutGrid

-- ---------------------------------------------------------------------------
-- Flexbox
-- ---------------------------------------------------------------------------
local function flexItems(b)
    local items = {}
    for _, k in ipairs(b.children) do
        if outOfFlow(k) then
            k.staticX = 0; k.staticY = 0
        elseif k.kind == 'text' then
            if k.text:match('%S') then
                -- 文本作为匿名弹性项目
                local anon = newBox(nil, anonCs(b.cs), 'block')
                anon.anon = true; anon.parent = b; anon.children = { k }; k.parent = anon
                items[#items + 1] = anon
            end
        else
            items[#items + 1] = k
        end
    end
    for _, it in ipairs(items) do it.isItem = true end
    return items
end
M.flexItems = flexItems

local function gapOf(cs, prop, basis)
    local v = cs.raw[prop]
    if v == 'normal' or v == nil then return 0 end
    return L(cs, prop, basis) or 0
end

layoutFlex = function(b, cw, ch)
    local cs = b.cs
    local dir = cs.raw['flex-direction']
    local row = dir == 'row' or dir == 'row-reverse'
    local wrap = cs.raw['flex-wrap'] ~= 'nowrap'
    local items = flexItems(b)
    b.flexItemsList = items
    local mainGap = row and gapOf(cs, 'column-gap', cw) or gapOf(cs, 'row-gap', ch)
    local crossGap = row and gapOf(cs, 'row-gap', ch) or gapOf(cs, 'column-gap', cw)
    -- 可用主轴空间
    local mainAvail -- 列方向且高度不定时为 nil
    if row then mainAvail = cw else mainAvail = ch end
    local minMainCont = nil
    if not row and not ch then
        -- 列方向：min-height 也会约束
        local mnh = L(cs, 'min-height', b.cbH)
        if mnh then minMainCont = mnh - vEdges(b) end
    end
    -- 1. 基准尺寸
    for _, it in ipairs(items) do
        local ics = it.cs
        resolveEdges(it, cw)
        it.flexGrow = tonumber(ics.raw['flex-grow']) or 0
        it.flexShrink = tonumber(ics.raw['flex-shrink']) or 1
        local basisV = ics.raw['flex-basis']
        local base
        if row then
            if basisV ~= 'auto' and basisV ~= 'content' then base = L(ics, 'flex-basis', cw) end
            if not base then
                base = L(ics, 'width', cw)
                if not base then
                    -- 内容尺寸：max-content
                    base = intrinsicW(it, 'max') - it.ml - it.mr
                    if it.kind == 'replaced' and L(ics, 'height', ch) then
                        local ar = aspectOf(it); if ar then base = L(ics, 'height', ch) * ar end
                    end
                end
            end
            -- 自动最小尺寸
            local mn = L(ics, 'min-width', cw)
            if mn == nil and ics.raw['min-width'] == 'auto' and ics.raw['overflow-x'] == 'visible' then
                local mc = intrinsicW(it, 'min') - it.ml - it.mr
                local sw = L(ics, 'width', cw)
                if sw then mc = min(mc, sw) end
                mn = mc
            end
            it.minMain = mn or 0
            it.maxMain = L(ics, 'max-width', cw) or huge
        else
            if basisV ~= 'auto' and basisV ~= 'content' then base = L(ics, 'flex-basis', ch) end
            if not base then
                base = L(ics, 'height', ch)
                if not base then
                    layoutBox(it, cw, ch, { shrink = false, w = (it.kind ~= 'replaced' and isAuto(ics, 'width') and (ics.raw['align-self'] == 'stretch' or (ics.raw['align-self'] == 'auto' and (cs.raw['align-items'] == 'stretch' or cs.raw['align-items'] == 'normal')))) and (cw - it.ml - it.mr) or nil })
                    base = it.h
                end
            end
            local mn = L(ics, 'min-height', ch)
            if mn == nil and ics.raw['min-height'] == 'auto' and ics.raw['overflow-y'] == 'visible' then
                -- 内容高度
                if not it.h then layoutBox(it, cw, ch, {}) end
                mn = min(it.contentH + vEdges(it), base)
            end
            it.minMain = mn or 0
            it.maxMain = L(ics, 'max-height', ch) or huge
        end
        it.base = base
        it.hypo = max(it.minMain, min(it.maxMain, base))
        it.outerHypo = it.hypo + (row and (it.ml + it.mr) or (it.mt + it.mb))
    end
    if M.DEBUGFLEX and b.el and b.el.classSet[M.DEBUGFLEX] then
        for _, it in ipairs(items) do io.stderr:write(string.format('item %s base=%.2f hypo=%.2f min=%.2f h=%.2f\n', it.el and it.el.attrs.id or '?', it.base, it.hypo, it.minMain, it.h or -1)) end
    end
    -- 2. 分行
    local lines = {}
    local curLine = { items = {}, sum = 0 }
    for _, it in ipairs(items) do
        local add = it.outerHypo + ((#curLine.items > 0) and mainGap or 0)
        if wrap and mainAvail and #curLine.items > 0 and curLine.sum + add > mainAvail + 0.001 then
            lines[#lines + 1] = curLine
            curLine = { items = {}, sum = 0 }
            add = it.outerHypo
        end
        curLine.items[#curLine.items + 1] = it
        curLine.sum = curLine.sum + add
    end
    if #curLine.items > 0 or #lines == 0 then lines[#lines + 1] = curLine end
    -- 主轴尺寸未定（列方向、高度 auto）：取内容之和
    local containerMain = mainAvail
    if not containerMain then
        local mx = 0
        for _, ln in ipairs(lines) do mx = max(mx, ln.sum) end
        containerMain = max(mx, minMainCont or 0)
        local mxh = L(cs, 'max-height', b.cbH)
        if mxh then containerMain = min(containerMain, mxh - vEdges(b)) end
    end
    -- 3. 解析弹性长度
    for _, ln in ipairs(lines) do
        local its = ln.items
        local used = 0
        for i, it in ipairs(its) do used = used + it.outerHypo + ((i > 1) and mainGap or 0) end
        local free = containerMain - used
        local growing = free > 0
        for _, it in ipairs(its) do it.target = it.hypo; it.frozen = false end
        -- 不可伸缩的项目先冻结
        for _, it in ipairs(its) do
            local f = growing and it.flexGrow or it.flexShrink
            if f == 0 or (growing and it.base > it.hypo) or (not growing and it.base < it.hypo) then it.frozen = true end
            it.target = it.frozen and it.hypo or it.base
        end
        for _ = 1, 20 do
            local unfrozen = {}
            local space = containerMain
            for i, it in ipairs(its) do
                space = space - ((i > 1) and mainGap or 0) - (row and (it.ml + it.mr) or (it.mt + it.mb))
                if it.frozen then space = space - it.target else space = space - it.base; unfrozen[#unfrozen + 1] = it end
            end
            if #unfrozen == 0 then break end
            local sumF = 0
            for _, it in ipairs(unfrozen) do sumF = sumF + (growing and it.flexGrow or it.flexShrink) end
            if sumF < 1 and growing then
                -- 小于 1 时只分配部分剩余空间
                local initial = free
                if abs(initial * sumF) < abs(space) then space = initial * sumF end
            end
            local totalViol = 0
            for _, it in ipairs(unfrozen) do
                local t
                if growing then
                    t = it.base + (sumF > 0 and space * it.flexGrow / sumF or 0)
                else
                    local scaled = it.flexShrink * it.base
                    local sumScaled = 0
                    for _, u in ipairs(unfrozen) do sumScaled = sumScaled + u.flexShrink * u.base end
                    t = it.base + (sumScaled > 0 and space * scaled / sumScaled or 0)
                end
                local c = max(it.minMain, min(it.maxMain, t))
                it.viol = c - t
                it.target = c
                totalViol = totalViol + it.viol
            end
            if abs(totalViol) < 0.0001 then for _, it in ipairs(unfrozen) do it.frozen = true end break end
            for _, it in ipairs(unfrozen) do
                if (totalViol > 0 and it.viol > 0) or (totalViol < 0 and it.viol < 0) then it.frozen = true end
            end
        end
    end
    -- 4. 交叉轴尺寸：按主轴尺寸排版
    local alignItems = cs.raw['align-items']
    local crossDef
    if row then crossDef = ch else crossDef = cw end
    for _, ln in ipairs(lines) do
        local lc = 0
        for _, it in ipairs(ln.items) do
            local as = it.cs.raw['align-self']
            if as == 'auto' then as = alignItems end
            if as == 'normal' then as = 'stretch' end
            it.alignS = as
            if row then
                layoutBox(it, cw, ch, { w = it.target })
                lc = max(lc, it.h + it.mt + it.mb)
            else
                local stretchW = (as == 'stretch' and isAuto(it.cs, 'width') and it.kind ~= 'replaced') and (cw - it.ml - it.mr) or nil
                local indef = (ch == nil)
                if stretchW then layoutBox(it, cw, ch, { w = stretchW, h = it.target, hIndef = indef })
                else layoutBox(it, cw, ch, { shrink = true, avail = cw, h = it.target, hIndef = indef }) end
                lc = max(lc, it.w + it.ml + it.mr)
            end
        end
        ln.cross = lc
    end
    -- 单行且交叉轴尺寸确定：行的交叉尺寸就是容器的
    if #lines == 1 and crossDef then lines[1].cross = crossDef end
    -- 5. 拉伸
    for _, ln in ipairs(lines) do
        for _, it in ipairs(ln.items) do
            if it.alignS == 'stretch' then
                if row and isAuto(it.cs, 'height') then
                    local hh = ln.cross - it.mt - it.mb
                    local mxh = L(it.cs, 'max-height', ch); if mxh then hh = min(hh, mxh) end
                    local mnh = L(it.cs, 'min-height', ch); if mnh then hh = max(hh, mnh) end
                    if abs(hh - it.h) > 0.001 then layoutBox(it, cw, ch, { w = it.target, h = hh }) end
                    it.stretched = true
                elseif not row and isAuto(it.cs, 'width') and it.kind ~= 'replaced' then
                    local ww = ln.cross - it.ml - it.mr
                    if abs(ww - it.w) > 0.001 then layoutBox(it, cw, ch, { w = ww, h = it.target, hIndef = (ch == nil) }) end
                end
            end
        end
    end
    -- 6. 主轴对齐
    local jc = cs.raw['justify-content']
    local crossPos = 0
    local totalCross = 0
    for i, ln in ipairs(lines) do totalCross = totalCross + ln.cross + ((i > 1) and crossGap or 0) end
    for li, ln in ipairs(lines) do
        local its = ln.items
        local used = 0
        local autoM = 0
        for i, it in ipairs(its) do
            used = used + it.target + ((i > 1) and mainGap or 0)
            if row then
                used = used + (it.mlAuto and 0 or it.ml) + (it.mrAuto and 0 or it.mr)
                if it.mlAuto then autoM = autoM + 1 end
                if it.mrAuto then autoM = autoM + 1 end
            else
                used = used + it.mt + it.mb
            end
        end
        local free = containerMain - used
        local pos, between = 0, 0
        if autoM > 0 and free > 0 then
            local each = free / autoM
            for _, it in ipairs(its) do
                if it.mlAuto then it.ml = each end
                if it.mrAuto then it.mr = each end
            end
            free = 0
        elseif row then
            for _, it in ipairs(its) do if it.mlAuto then it.ml = 0 end if it.mrAuto then it.mr = 0 end end
        end
        if jc == 'center' then pos = free / 2
        elseif jc == 'flex-end' or jc == 'end' then pos = free
        elseif jc == 'space-between' and #its > 1 then between = free / (#its - 1)
        elseif jc == 'space-between' then pos = 0
        elseif jc == 'space-around' and #its > 0 and free > 0 then between = free / #its; pos = between / 2
        elseif jc == 'space-evenly' and #its > 0 and free > 0 then between = free / (#its + 1); pos = between end
        if free < 0 and jc ~= 'center' then pos = (jc == 'flex-end' or jc == 'end') and free or 0 end
        for i, it in ipairs(its) do
            if i > 1 then pos = pos + mainGap + between end
            if row then
                pos = pos + it.ml
                it.rx = b.bl + b.pl + pos
                pos = pos + it.w + it.mr
            else
                pos = pos + it.mt
                it.ry = b.bt + b.pt + pos
                pos = pos + it.h + it.mb
            end
        end
        -- 交叉轴对齐
        for _, it in ipairs(its) do
            local outer = row and (it.h + it.mt + it.mb) or (it.w + it.ml + it.mr)
            local off = 0
            local as = it.alignS
            if as == 'center' then off = (ln.cross - outer) / 2
            elseif as == 'flex-end' or as == 'end' then off = ln.cross - outer end
            if row then it.ry = b.bt + b.pt + crossPos + off + it.mt
            else it.rx = b.bl + b.pl + crossPos + off + it.ml end
        end
        crossPos = crossPos + ln.cross + crossGap
    end
    -- 基线（第一项）
    local f = lines[1] and lines[1].items[1]
    if f then
        if row then
            -- 第一项的基线；没有基线（如图片）就用它的下边缘
            if f.firstBaseline then b.firstBaseline = f.ry + f.firstBaseline else b.firstBaseline = f.ry + f.h end
        else
            if f.firstBaseline then b.firstBaseline = f.ry + f.firstBaseline else b.firstBaseline = f.ry + f.h end
        end
        local lastLn = lines[#lines] --[[@as {items:table[]}]]
        local li = lastLn.items[1]
        if li and li.lastBaseline then b.lastBaseline = li.ry + li.lastBaseline end
    end
    if row then return totalCross end
    return containerMain
end

-- ---------------------------------------------------------------------------
-- Grid
-- ---------------------------------------------------------------------------
local function parseTracks(cs, avail, gap)
    local tpl = cs.raw['grid-template-columns']
    if tpl == 'none' then return { { kind = 'auto' } }, false end
    local out = {}
    local autoFit = false
    local function parseOne(t)
        if t == 'auto' then return { kind = 'auto' } end
        local fr = t:match('^([%d%.]+)fr$')
        if fr then return { kind = 'fr', fr = tonumber(fr), minAuto = true } end
        local a, c = t:match('^minmax%((.-),%s*(.-)%)$')
        if a then
            local mn = (a == 'auto') and 'auto' or Expr.eval(Expr.parse(a), { em = cs.fontSize, vw = ENV.vw, vh = ENV.vh })
            local frv = c:match('^([%d%.]+)fr$')
            if frv then return { kind = 'fr', fr = tonumber(frv), minAuto = (mn == 'auto'), min = (mn ~= 'auto') and mn or nil } end
            return { kind = 'fixed', size = Expr.eval(Expr.parse(c), { em = cs.fontSize, vw = ENV.vw, vh = ENV.vh }) }
        end
        return { kind = 'fixed', size = Expr.eval(Expr.parse(t), { em = cs.fontSize, vw = ENV.vw, vh = ENV.vh, pct = avail }) }
    end
    for _, t in ipairs(CSS.splitTop(tpl, ' ')) do
        local cnt, inner = t:match('^repeat%(%s*([%w%-]+)%s*,%s*(.-)%s*%)$')
        if cnt then
            local parts = CSS.splitTop(inner, ' ')
            if cnt == 'auto-fit' or cnt == 'auto-fill' then
                autoFit = (cnt == 'auto-fit')
                local one = parseOne(parts[1])
                local mn = one.min or one.size or 0
                local n = max(1, floor(((avail or 0) + gap) / (mn + gap)))
                for _ = 1, n do local tr = parseOne(parts[1]); tr.repeated = true; out[#out + 1] = tr end
            else
                for _ = 1, tonumber(cnt) do for _, p in ipairs(parts) do out[#out + 1] = parseOne(p) end end
            end
        else
            out[#out + 1] = parseOne(t)
        end
    end
    return out, autoFit
end

local function gridItems(b)
    local items = {}
    for _, k in ipairs(b.children) do
        if outOfFlow(k) then k.staticX = 0; k.staticY = 0
        elseif k.kind == 'text' then
            if k.text:match('%S') then
                local anon = newBox(nil, anonCs(b.cs), 'block')
                anon.anon = true; anon.parent = b; anon.children = { k }; k.parent = anon
                items[#items + 1] = anon
            end
        else items[#items + 1] = k end
    end
    for _, it in ipairs(items) do it.isItem = true end
    return items
end

local function placeItems(b, items, ncols)
    local cs = b.cs
    -- 模板区域
    local areas = {}
    local tplA = cs.raw['grid-template-areas']
    if tplA and tplA ~= 'none' then
        local r = 0
        for rowS in tplA:gmatch('"([^"]*)"') do
            local c = 0
            for name in rowS:gmatch('%S+') do
                local a = areas[name]
                if not a then a = { r0 = r, r1 = r, c0 = c, c1 = c }; areas[name] = a
                else a.r0 = min(a.r0, r); a.r1 = max(a.r1, r); a.c0 = min(a.c0, c); a.c1 = max(a.c1, c) end
                c = c + 1
            end
            r = r + 1
        end
    end
    local occ = {}
    local function isFree(r, c, rs, csn)
        for rr = r, r + rs - 1 do for cc = c, c + csn - 1 do
            if cc >= ncols then return false end
            if occ[rr * 1000 + cc] then return false end
        end end
        return true
    end
    local function mark(r, c, rs, csn) for rr = r, r + rs - 1 do for cc = c, c + csn - 1 do occ[rr * 1000 + cc] = true end end end
    local curR, curC = 0, 0
    -- 先放置有确定位置的项目
    for _, it in ipairs(items) do
        local ics = it.cs
        local area = ics.raw['grid-area']
        if area and area ~= 'auto' and areas[area] then
            local a = areas[area]
            it.gr, it.gc, it.grs, it.gcs = a.r0, a.c0, a.r1 - a.r0 + 1, a.c1 - a.c0 + 1
            mark(it.gr, it.gc, it.grs, it.gcs)
            it.placed = true
        else it.placed = false end
    end
    for _, it in ipairs(items) do
        if not it.placed then
            local ics = it.cs
            local rs, csn = 1, 1
            local span = (ics.raw['grid-row'] or ''):match('span%s+(%d+)')
            if span then rs = tonumber(span) end
            local gcol = ics.raw['grid-column'] or 'auto'
            local fixedC0 = nil
            local a1, a2 = gcol:match('^%s*(%-?%d+)%s*/%s*(%-?%d+)%s*$')
            if a1 then
                local s, e = tonumber(a1), tonumber(a2)
                if s < 0 then s = ncols + 2 + s end
                if e < 0 then e = ncols + 2 + e end
                fixedC0 = s - 1; csn = e - s
            else
                local cspan = gcol:match('span%s+(%d+)')
                if cspan then csn = tonumber(cspan) end
            end
            if csn > ncols then csn = ncols end
            while true do
                local c = fixedC0 or curC
                if fixedC0 and curC > fixedC0 then curR = curR + 1; curC = 0; c = fixedC0 end
                if c + csn <= ncols and isFree(curR, c, rs, csn) then
                    it.gr, it.gc, it.grs, it.gcs = curR, c, rs, csn
                    mark(curR, c, rs, csn)
                    curC = c + csn
                    break
                end
                curC = curC + 1
                if fixedC0 then curC = ncols end
                if curC >= ncols then curC = 0; curR = curR + 1 end
            end
        end
    end
    local nrows = 0
    for _, it in ipairs(items) do nrows = max(nrows, it.gr + it.grs) end
    return nrows
end

local function sizeColumns(b, items, tracks, cw, gap, autoFit, which)
    local n = #tracks
    -- auto-fit：空的重复轨道折叠
    local used = {}
    for _, it in ipairs(items) do for c = it.gc, it.gc + it.gcs - 1 do used[c] = true end end
    local collapsed = {}
    if autoFit then for i = 1, n do if tracks[i].repeated and not used[i - 1] then collapsed[i] = true end end end
    local nGaps = 0
    for i = 1, n do if not collapsed[i] then nGaps = nGaps + 1 end end
    nGaps = max(0, nGaps - 1)
    local sizes = {}
    local growth = {}
    -- 初始化
    for i, t in ipairs(tracks) do
        if collapsed[i] then sizes[i] = 0; growth[i] = 0
        elseif t.kind == 'fixed' then sizes[i] = t.size; growth[i] = t.size
        elseif t.kind == 'fr' then sizes[i] = t.minAuto and 0 or (t.min or 0); growth[i] = huge
        else sizes[i] = 0; growth[i] = 0 end
    end
    -- 跨一个轨道的项目贡献
    for _, it in ipairs(items) do
        if it.gcs == 1 then
            local i = it.gc + 1
            local t = tracks[i]
            if t and not collapsed[i] then
                if t.kind == 'auto' then
                    local mnc = intrinsicW(it, 'min')
                    local mxc = intrinsicW(it, 'max')
                    sizes[i] = max(sizes[i], (which == 'max') and mxc or mnc)
                    growth[i] = max(growth[i], mxc)
                elseif t.kind == 'fr' and t.minAuto then
                    sizes[i] = max(sizes[i], intrinsicW(it, 'min'))
                end
            end
        end
    end
    for i = 1, n do if growth[i] ~= huge and growth[i] < sizes[i] then growth[i] = sizes[i] end end
    if which then
        -- 固有尺寸计算：fr 轨道按 max-content
        local total = 0
        local frMax = 0
        for i, t in ipairs(tracks) do
            if t.kind == 'fr' and not collapsed[i] then
                local mx = 0
                for _, it in ipairs(items) do if it.gcs == 1 and it.gc + 1 == i then mx = max(mx, intrinsicW(it, which)) end end
                frMax = max(frMax, mx / t.fr)
            end
        end
        for i, t in ipairs(tracks) do
            if t.kind == 'fr' and not collapsed[i] then sizes[i] = max(sizes[i], frMax * t.fr) end
            total = total + sizes[i]
        end
        return sizes, total + nGaps * gap
    end
    local avail = cw - nGaps * gap
    -- 最大化非弹性轨道
    local free = avail
    for i = 1, n do free = free - sizes[i] end
    local hasFr = false
    for i, t in ipairs(tracks) do if t.kind == 'fr' and not collapsed[i] then hasFr = true end end
    if free > 0 then
        -- 平均分给还没到增长上限的 auto 轨道
        for _ = 1, 10 do
            local grow = {}
            for i, t in ipairs(tracks) do if t.kind == 'auto' and not collapsed[i] and growth[i] > sizes[i] + 0.0001 then grow[#grow + 1] = i end end
            if #grow == 0 or free <= 0.0001 then break end
            local each = free / #grow
            for _, i in ipairs(grow) do
                local add = min(each, growth[i] - sizes[i])
                sizes[i] = sizes[i] + add; free = free - add
            end
        end
    end
    -- 弹性轨道
    if hasFr then
        local leftover = avail
        for i, t in ipairs(tracks) do if not (t.kind == 'fr' and not collapsed[i]) then leftover = leftover - sizes[i] end end
        local inflex = {}
        local frSize
        for _ = 1, 10 do
            local sumFr, space = 0, leftover
            for i, t in ipairs(tracks) do
                if t.kind == 'fr' and not collapsed[i] then
                    if inflex[i] then space = space - sizes[i] else sumFr = sumFr + t.fr end
                end
            end
            frSize = (sumFr > 0) and max(0, space) / max(sumFr, 1) or 0
            local again = false
            for i, t in ipairs(tracks) do
                if t.kind == 'fr' and not collapsed[i] and not inflex[i] and sizes[i] > frSize * t.fr + 0.0001 then inflex[i] = true; again = true end
            end
            if not again then break end
        end
        for i, t in ipairs(tracks) do
            if t.kind == 'fr' and not collapsed[i] and not inflex[i] then sizes[i] = max(sizes[i], frSize * t.fr) end
        end
    elseif free > 0 then
        -- 没有弹性轨道时 auto 轨道拉伸（justify-content: normal）
        local autos = {}
        for i, t in ipairs(tracks) do if t.kind == 'auto' and not collapsed[i] then autos[#autos + 1] = i end end
        if #autos > 0 then for _, i in ipairs(autos) do sizes[i] = sizes[i] + free / #autos end end
    end
    return sizes, nil, collapsed
end

function M.gridIntrinsic(b, which)
    local cs = b.cs
    local gap = gapOf(cs, 'column-gap', nil)
    local tracks, autoFit = parseTracks(cs, nil, gap)
    local items = gridItems(b)
    for _, it in ipairs(items) do resolveEdges(it, nil) end
    placeItems(b, items, #tracks)
    local _, total = sizeColumns(b, items, tracks, 0, gap, autoFit, which)
    return total
end

layoutGrid = function(b, cw, ch)
    local cs = b.cs
    local colGap = gapOf(cs, 'column-gap', cw)
    local rowGap = gapOf(cs, 'row-gap', ch)
    local tracks, autoFit = parseTracks(cs, cw, colGap)
    local items = gridItems(b)
    b.gridItemsList = items
    for _, it in ipairs(items) do resolveEdges(it, cw) end
    local ncols = #tracks
    local nrows = placeItems(b, items, ncols)
    local colSizes, _, collapsed = sizeColumns(b, items, tracks, cw, colGap, autoFit, nil)
    collapsed = collapsed or {}
    -- 列位置
    local colX = {}
    local x = 0
    local firstCol = true
    for i = 1, ncols do
        if collapsed[i] then colX[i] = x
        else
            if not firstCol then x = x + colGap end
            colX[i] = x
            x = x + colSizes[i]
            firstCol = false
        end
    end
    local function areaW(it)
        local w = 0
        local cnt = 0
        for c = it.gc + 1, it.gc + it.gcs do if not collapsed[c] then w = w + colSizes[c]; cnt = cnt + 1 end end
        return w + max(0, cnt - 1) * colGap
    end
    -- 先按区域宽度排版每个项目，得到高度
    local ji = cs.raw['justify-items']
    local ai = cs.raw['align-items']
    for _, it in ipairs(items) do
        local aw = areaW(it)
        local js = it.cs.raw['justify-self']
        if js == 'auto' or js == nil then js = ji end
        if js == 'normal' or js == 'legacy' then js = (it.kind == 'replaced') and 'start' or 'stretch' end
        it.justS = js
        local as = it.cs.raw['align-self']
        if as == 'auto' then as = ai end
        if as == 'normal' then as = (it.kind == 'replaced') and 'start' or 'stretch' end
        it.alignS = as
        it.areaW = aw
        if js == 'stretch' and isAuto(it.cs, 'width') and it.kind ~= 'replaced' then
            layoutBox(it, aw, nil, { w = aw - it.ml - it.mr })
        else
            layoutBox(it, aw, nil, { shrink = true, avail = aw })
        end
    end
    -- 行高
    local rowSizes = {}
    for r = 1, nrows do rowSizes[r] = 0 end
    for _, it in ipairs(items) do
        if it.grs == 1 then
            local r = it.gr + 1
            rowSizes[r] = max(rowSizes[r], it.h + it.mt + it.mb)
        end
    end
    -- 跨多行的项目：不足的部分平均分给所跨的行
    for _, it in ipairs(items) do
        if it.grs > 1 then
            local have = (it.grs - 1) * rowGap
            for r = it.gr + 1, it.gr + it.grs do have = have + rowSizes[r] end
            local need = it.h + it.mt + it.mb
            if need > have then
                local each = (need - have) / it.grs
                for r = it.gr + 1, it.gr + it.grs do rowSizes[r] = rowSizes[r] + each end
            end
        end
    end
    -- 容器高度确定时，auto 行拉伸填满（align-content: normal）
    local total = 0
    for r = 1, nrows do total = total + rowSizes[r] end
    total = total + max(0, nrows - 1) * rowGap
    local defH = ch
    if not defH then
        local mnh = L(cs, 'min-height', b.cbH)
        if mnh and mnh - vEdges(b) > total then defH = mnh - vEdges(b) end
    end
    local ac = cs.raw['align-content'] or 'normal'
    local y0, between = 0, 0
    if defH and defH > total and nrows > 0 then
        local free = defH - total
        if ac == 'normal' or ac == 'stretch' then
            local each = free / nrows
            for r = 1, nrows do rowSizes[r] = rowSizes[r] + each end
        elseif ac == 'center' then y0 = free / 2
        elseif ac == 'end' or ac == 'flex-end' then y0 = free
        elseif ac == 'space-between' then if nrows > 1 then between = free / (nrows - 1) end
        elseif ac == 'space-around' then between = free / nrows; y0 = between / 2
        elseif ac == 'space-evenly' then between = free / (nrows + 1); y0 = between end
        total = defH
    end
    local rowY = {}
    local y = y0
    for r = 1, nrows do
        rowY[r] = y
        y = y + rowSizes[r] + rowGap + between
    end
    -- 放置并对齐
    for _, it in ipairs(items) do
        local ah = (it.grs - 1) * rowGap
        for r = it.gr + 1, it.gr + it.grs do ah = ah + rowSizes[r] end
        local aw = it.areaW
        if it.alignS == 'stretch' and isAuto(it.cs, 'height') and it.kind ~= 'replaced' then
            local hh = ah - it.mt - it.mb
            if abs(hh - it.h) > 0.001 then
                if it.justS == 'stretch' and isAuto(it.cs, 'width') then layoutBox(it, aw, ah, { w = aw - it.ml - it.mr, h = hh })
                else layoutBox(it, aw, ah, { w = it.w, h = hh }) end
            end
            it.stretched = true
        end
        local ox = 0
        local outerW = it.w + it.ml + it.mr
        if it.justS == 'center' then ox = (aw - outerW) / 2 elseif it.justS == 'end' or it.justS == 'flex-end' then ox = aw - outerW end
        local oy = 0
        local outerH = it.h + it.mt + it.mb
        if it.alignS == 'center' then oy = (ah - outerH) / 2 elseif it.alignS == 'end' or it.alignS == 'flex-end' then oy = ah - outerH end
        it.rx = b.bl + b.pl + colX[it.gc + 1] + ox + it.ml
        it.ry = b.bt + b.pt + rowY[it.gr + 1] + oy + it.mt
    end
    -- 基线
    for _, it in ipairs(items) do
        if it.gr == 0 and it.firstBaseline then b.firstBaseline = it.ry + it.firstBaseline; break end
    end
    return total
end

return layoutFlex, layoutGrid
end
