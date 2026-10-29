-- ============================================================================
-- 像素渲染：战场、老虎机转轴、主页画面（逐行移植自原版的 canvas 绘制代码）
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
-- 仅关闭共享符号的 undefined-global 诊断；局部变量仍保留类型诊断。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local PX = require("game.pixel")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, sin, cos, sqrt, atan = math.floor, math.ceil, math.max, math.min, math.abs, math.sin, math.cos, math.sqrt, math.atan
local PI = math.pi
local of = js.of

-- 护栏：多处按半径/坐标逐行或逐段绘制的循环，一旦上游算出 inf/nan 就会撑到几十亿次而卡死整帧。
-- 统一钳制循环次数，超限截断并报警一次（定位用）。
local CAP = 400
local capWarned = false
local function capN(tag, n)
    if not (n == n) then return 0 end
    if n > CAP then
        if not capWarned then capWarned = true; print('[拉杆军团] 渲染护栏触发：' .. tag .. ' n=' .. tostring(n)) end
        return CAP
    end
    if n < 0 then return 0 end
    return n
end

-- 三块画布（与原版 <canvas> 的分辨率一致）
arenaCv = PX.newCanvas(256, 176)
slotCv = PX.newCanvas(72, 72)
homeCv = PX.newCanvas(192, 56)
actx, sctx = arenaCv, slotCv
drag = nil

-- ---------- 像素字体 ----------
-- 文字先画进一张小像素图并缓存（伤害数字每帧都要画，逐像素填充太慢）
local textCache, textN = {}, 0
local function textImg(str, color)
    local key = str .. '|' .. color
    local img = textCache[key]
    if img then return img end
    textN = textN + 1
    if textN > 600 then textCache = {}; textN = 0 end
    local w = #str * 4 - 1
    img = PX.newImage(w + 2, 7)
    for pass = 0, 1 do
        local col = (pass ~= 0) and color or PAL.k
        local cx = 1
        for ci = 1, #str do
            local g = FONT[str:sub(ci, ci)]
            if g then
                for r = 0, 4 do
                    local row = g[r]
                    for c = 0, 2 do
                        if row:sub(c + 1, c + 1) == '1' then
                            if pass ~= 0 then img:set(cx + c, 1 + r, col) else img:fill(cx + c - 1, r, 3, 3, col) end
                        end
                    end
                end
            end
            cx = cx + 4
        end
    end
    textCache[key] = img
    return img
end
function pixText(ctx, str, x, y, color)
    local w = #str * 4 - 1
    local sx, sy = round(x - w / 2), round(y)
    ctx:drawImage(textImg(str, color), sx - 1, sy - 1)
end

-- ---------- 精灵 ----------
local sprCache = {}
-- part：0 整张，1 只画身体，2 只画武器（见 WEAPON_RIG），3 弓手去掉弓弦和手，4 只画拉弦的手（见 BOW_RIG）
function spr(name, over, flash, flip, overKey, part)
    local key = name .. '|' .. (overKey or '') .. '|' .. (flash and 1 or 0) .. '|' .. (flip and 1 or 0) .. ((T(part)) and ('|' .. part) or '')
    local c = sprCache[key]
    if c then return c end
    local rows = SPR[name]
    local h, w = #rows, #rows[0]
    local mask = nil
    if T(part) then
        if part == 3 then mask = bowRigOf(name).mask
        elseif part == 4 then mask = bowRigOf(name).hmask
        else mask = rigOf(name).mask end
    end
    c = PX.newImage(w, h)
    local keep = (part == 2 or part == 4)
    for yy = 0, h - 1 do
        local row = rows[yy]
        for xx = 0, w - 1 do
            local ch = row:sub(xx + 1, xx + 1)
            if ch ~= '.' then
                if not (mask and ((mask[xx * 1000 + yy] == true) ~= keep)) then
                    local col
                    if flash then col = (ch == 'k') and PAL.k or '#ffffff'
                    else col = (over and over[ch]) or PAL[ch] end
                    c:set(flip and (w - 1 - xx) or xx, yy, col)
                end
            end
        end
    end
    sprCache[key] = c
    return c
end
function unitSpr(cls, star, flash, flip) return spr(CLASSES[cls].sprite, TIER_PAL[cls][star], flash, flip, cls .. S(star)) end
function branchSpr(b, flash, flip) return spr(BRANCHES[b].sprite or b, BRPAL[b], flash, flip, 'br:' .. b) end
function unitImg(cls, star, branch, flash, flip)
    if branch then return branchSpr(branch, flash, flip) end
    return unitSpr(cls, star, flash, flip)
end
function entImg(e, flash, flip)
    local a = entSprArgs(e) --[[@as table<number, any>]]
    return spr(a[0], a[1], flash, flip, a[2])
end

local glowCache = setmetatable({}, { __mode = 'k' })
function glowImg(img, color, outer) -- outer：只往外扩，被身体围住的空隙（比如弓弦和弓臂之间）不发光
    local m = glowCache[img]
    if not m then m = {}; glowCache[img] = m end
    local ck = color .. (outer and '|o' or '')
    local c = m[ck]
    if c then return c end
    local w, h = img.width, img.height
    local W, H = w + 2, h + 2
    c = PX.newImage(W, H)
    local d = img.data
    local function solid(px, py) return px >= 1 and py >= 1 and px <= w and py <= h and d[(py - 1) * w + px - 1] ~= nil end
    local out = nil
    if outer then -- 从画布边缘出发，沿透明像素泛洪，到得了的才算外面
        out = {}
        local st = {}
        for i = 0, W - 1 do st[#st + 1] = i; st[#st + 1] = 0; st[#st + 1] = i; st[#st + 1] = H - 1 end
        for j = 0, H - 1 do st[#st + 1] = 0; st[#st + 1] = j; st[#st + 1] = W - 1; st[#st + 1] = j end
        while #st > 0 do
            local py = table.remove(st)
            local px = table.remove(st)
            if not (px < 0 or py < 0 or px >= W or py >= H or out[py * W + px] or solid(px, py)) then
                out[py * W + px] = true
                st[#st + 1] = px + 1; st[#st + 1] = py
                st[#st + 1] = px - 1; st[#st + 1] = py
                st[#st + 1] = px; st[#st + 1] = py + 1
                st[#st + 1] = px; st[#st + 1] = py - 1
            end
        end
    end
    for yy = 0, h - 1 do
        for xx = 0, w - 1 do
            if d[yy * w + xx] ~= nil then
                if not out then
                    c:fill(xx + 1, yy, 1, 3, color); c:fill(xx, yy + 1, 3, 1, color)
                else
                    local pts = { xx + 1, yy + 1, xx, yy + 1, xx + 2, yy + 1, xx + 1, yy, xx + 1, yy + 2 }
                    for k = 1, 9, 2 do
                        local px, py = pts[k], pts[k + 1]
                        if out[py * W + px] or solid(px, py) then c:set(px, py, color) end
                    end
                end
            end
        end
    end
    m[ck] = c
    return c
end
function qGlowAlpha(q)
    if q >= 3 and not REDUCED then return (floor(G.time * 5) % 2 ~= 0) and 1 or 0.55 end
    if q == 2 then return 0.9 end
    return 0.75
end
SUP_GLOW, SUP_HALO = '#ff2a2a', '#b80f28'
function supPulse() return REDUCED and 0.6 or (0.5 + 0.5 * sin(G.time * 5)) end
function drawQGlow(img, x, y, q, sc, P, f)
    if not T(q) then return end
    sc = OR(sc, 1)
    if q >= Q_SUP then -- 超凡：内层亮红描边 + 外层暗红光晕，一起呼吸
        local k = supPulse()
        local g1 = glowImg(img, SUP_GLOW, true)
        local g2 = glowImg(g1, SUP_HALO, true)
        local prev = actx.globalAlpha
        actx.globalAlpha = prev * (0.3 + 0.35 * k); drawPosed(g2, x, y, sc, P, OR(f, 1), 2)
        actx.globalAlpha = prev * (0.75 + 0.25 * k); drawPosed(g1, x, y, sc, P, OR(f, 1), 1)
        actx.globalAlpha = prev
        return
    end
    local g = glowImg(img, QUAL[q].color)
    local prev = actx.globalAlpha
    actx.globalAlpha = prev * qGlowAlpha(q)
    drawPosed(g, x, y, sc, P, OR(f, 1), 1)
    actx.globalAlpha = prev
end
ELITE_AURA = 'rgba(255,74,74,0.8)'
function auraOf(star, branch)
    if branch then return BRANCHES[branch].aura end
    if star == 3 then return 'rgba(255,216,74,0.55)' end
    if star == 2 then return 'rgba(207,227,255,0.45)' end
    return 'rgba(0,0,0,0.28)'
end

FIELD_DRAW, PROJ_DRAW = FIELD_DRAW or {}, PROJ_DRAW or {}
BG_PAINT = BG_PAINT or {} -- 章节模块登记额外背景；内置冰原 / 神殿保持原绘制。
-- ---------- 背景 ----------
local BGS = {}
function bgFor(k)
    if not BGS[k] then
        BGS[k] = buildBg(k)
        local path = 'Textures/bg_' .. k .. '.png'
        -- .tex 会跳过像素数据；缺图时不能交给 textureHook，否则本帧留白并禁用共享纹理钩子。
        -- 未导出纹理的章节保留程序化背景，已有纹理仍走快速路径。
        if cache and cache:Exists(path) then BGS[k].tex = path end
    end
    return BGS[k]
end
local function paintLava(x, rnd)
    x:fill(0, 0, AW, FIELD_H, '#3a2a2e')
    local rock = { [0] = '#33242a', '#45323a', '#2e2026', '#4a363c' }
    for i = 0, 1499 do local c = rock[floor(rnd() * 4)]; local px = floor(rnd() * AW); local py = floor(rnd() * FIELD_H); x:fill(px, py, 1, 1, c) end
    for i = 0, 69 do
        local px = floor(rnd() * AW)
        local py = 10 + floor(rnd() * (FIELD_H - 12))
        x:fill(px, py, 2, 1, '#5a464c'); x:fill(px, py + 1, 2, 1, '#241a1e')
    end
    for c = 0, 9 do
        local px = rnd() * AW
        local py = 14 + rnd() * (FIELD_H - 24)
        local len = 12 + floor(rnd() * 26)
        local dir = (rnd() < 0.5) and 1 or -1
        for i = 0, len - 1 do
            x:fill(js.trunc(px), js.trunc(py) + 1, 1, 1, '#5a1a1a')
            local col = (rnd() < 0.22) and '#ffb03a' or '#e2541f'
            x:fill(js.trunc(px), js.trunc(py), 1, 1, col)
            px = px + dir
            if rnd() < 0.35 then py = py + ((rnd() < 0.5) and -1 or 1) end
        end
    end
    local glow = { [0] = '#ff8a2a', '#ffd84a', '#e2541f' }
    for i = 0, 23 do local c = glow[floor(rnd() * 3)]; local px = floor(rnd() * AW); local py = 10 + floor(rnd() * (FIELD_H - 12)); x:fill(px, py, 1, 1, c) end
    x:fill(0, 0, AW, 7, '#1f1418')
    for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#1f1418') end
    for i = 0, AW - 1, 6 do local px = i + floor(rnd() * 3); local py = 3 + floor(rnd() * 3); x:fill(px, py, 2, 1, '#5a1a1a') end
    for i = 0, AW - 1, 17 do local px = i + floor(rnd() * 9); x:fill(px, 6, 1, 1, '#e2541f') end
end
local function paintIce(x, rnd) -- 第四章：霜狱冰原的雪地、冰面裂纹与冰晶
    x:fill(0, 0, AW, FIELD_H, '#9fbcd6')
    local snow = { [0] = '#94b2cd', '#aac6de', '#8aa9c6', '#b4cee4' }
    for i = 0, 1599 do local c = snow[floor(rnd() * 4)]; local px = floor(rnd() * AW); local py = floor(rnd() * FIELD_H); x:fill(px, py, 1, 1, c) end
    for i = 0, 5 do -- 冰面
        local cx, cy = 20 + floor(rnd() * (AW - 40)), 18 + floor(rnd() * (FIELD_H - 34))
        local w, h = 14 + floor(rnd() * 22), 5 + floor(rnd() * 6)
        for dy = -h, h do
            local ww = floor(w * sqrt(max(0, 1 - (dy / h) * (dy / h))))
            x:fill(cx - ww, cy + dy, ww * 2, 1, (abs(dy) >= h - 1) and '#6f94b8' or '#86aed0')
        end
        x:fill(cx - floor(w / 2), cy - 1, 4, 1, '#e6f1fa'); x:fill(cx + 2, cy + 1, 3, 1, '#e6f1fa')
    end
    for c = 0, 7 do -- 裂纹
        local px, py = rnd() * AW, 14 + rnd() * (FIELD_H - 24)
        local len, dir = 8 + floor(rnd() * 16), (rnd() < 0.5) and 1 or -1
        for i = 0, len - 1 do
            x:fill(js.trunc(px), js.trunc(py), 1, 1, '#5d7fa3')
            px = px + dir
            if rnd() < 0.4 then py = py + ((rnd() < 0.5) and -1 or 1) end
        end
    end
    for i = 0, 17 do -- 冰晶
        local px, py = 4 + floor(rnd() * (AW - 8)), 12 + floor(rnd() * (FIELD_H - 18))
        x:fill(px, py - 1, 1, 3, '#ffffff'); x:fill(px - 1, py, 3, 1, '#ffffff'); x:fill(px, py, 1, 1, '#7cc0ff')
    end
    x:fill(0, 0, AW, 7, '#3a6ea8')
    for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#3a6ea8') end
    for i = 0, AW - 1, 7 do local px = i + floor(rnd() * 4); local py = 2 + floor(rnd() * 3); x:fill(px, py, 2, 2, '#7cc0ff') end
    for i = 0, AW - 1, 5 do local px = i + floor(rnd() * 3); x:fill(px, 7, 1, 2 + floor(rnd() * 3), '#e6f1fa') end
end
local function paintAstral(x, rnd) -- 第五章：星陨神殿的金砖地面、星图与圣光
    x:fill(0, 0, AW, FIELD_H, '#3a2f5a')
    local st = { [0] = '#352a52', '#40345f', '#30264b', '#463a66' }
    for i = 0, 1399 do local c = st[floor(rnd() * 4)]; local px = floor(rnd() * AW); local py = floor(rnd() * FIELD_H); x:fill(px, py, 1, 1, c) end
    for gx = 0, AW - 1, 24 do x:fill(gx, 8, 1, FIELD_H - 8, '#2a2142') end
    for gy = 22, FIELD_H - 1, 20 do x:fill(0, gy, AW, 1, '#2a2142') end
    for gx = 1, AW - 1, 24 do x:fill(gx, 8, 1, FIELD_H - 8, '#5a4a7a') end
    for gy = 23, FIELD_H - 1, 20 do x:fill(0, gy, AW, 1, '#5a4a7a') end
    for i = 0, 3 do -- 金色星图
        local cx, cy, r = 30 + floor(rnd() * (AW - 60)), 30 + floor(rnd() * (FIELD_H - 60)), 9 + floor(rnd() * 8)
        for k = 0, 23 do local a = k / 24 * 6.283; x:fill(floor(cx + cos(a) * r), floor(cy + sin(a) * r * 0.6), 1, 1, '#b8892a') end
        x:fill(cx - 1, cy, 3, 1, '#ffd84a'); x:fill(cx, cy - 1, 1, 3, '#ffd84a')
    end
    for i = 0, 39 do local c = (rnd() < 0.6) and '#fff6d0' or '#ffd84a'; local px = floor(rnd() * AW); local py = 10 + floor(rnd() * (FIELD_H - 12)); x:fill(px, py, 1, 1, c) end
    x:fill(0, 0, AW, 7, '#1f1838')
    for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#1f1838') end
    for i = 0, AW - 1, 12 do x:fill(i + 3, 1, 2, 6, '#b8892a'); x:fill(i + 3, 1, 2, 1, '#ffd84a') end
end
local function paintVoid(x, rnd) -- 第三章：虚空回廊的石板、符文与星光
    x:fill(0, 0, AW, FIELD_H, '#231e3c')
    local st = { [0] = '#1f1a36', '#28223f', '#1c1832', '#2b2546' }
    for i = 0, 1399 do local c = st[floor(rnd() * 4)]; local px = floor(rnd() * AW); local py = floor(rnd() * FIELD_H); x:fill(px, py, 1, 1, c) end
    for gx = 0, AW - 1, 32 do x:fill(gx, 8, 1, FIELD_H - 8, '#1a1530') end
    for gy = 24, FIELD_H - 1, 28 do x:fill(0, gy, AW, 1, '#1a1530') end
    for gx = 1, AW - 1, 32 do x:fill(gx, 8, 1, FIELD_H - 8, '#2f2850') end
    for gy = 25, FIELD_H - 1, 28 do x:fill(0, gy, AW, 1, '#2f2850') end
    local rune = { [0] = '#6a33c9', '#8f4bc4', '#c06bff' }
    for i = 0, 13 do
        local px = 6 + floor(rnd() * (AW - 12))
        local py = 14 + floor(rnd() * (FIELD_H - 24))
        local c = rune[floor(rnd() * 3)]
        x:fill(px - 1, py, 3, 1, c); x:fill(px, py - 1, 1, 3, c)
    end
    for i = 0, 29 do local c = (rnd() < 0.5) and '#cfe3ff' or '#8f7bc4'; local px = floor(rnd() * AW); local py = 10 + floor(rnd() * (FIELD_H - 12)); x:fill(px, py, 1, 1, c) end
    x:fill(0, 0, AW, 7, '#120e20')
    for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#120e20') end
    for i = 0, AW - 1, 9 do local px = i + floor(rnd() * 4); local py = 3 + floor(rnd() * 2); x:fill(px, py, 1, 1, '#6a33c9') end
end
function buildBg(kind)
    local x = PX.newImage(AW, AH)
    local s = 11
    local function rnd() s = (s * 16807) % 2147483647; return s / 2147483647 end
    if kind == 'lava' then paintLava(x, rnd)
    elseif kind == 'void' then paintVoid(x, rnd)
    elseif kind == 'ice' then paintIce(x, rnd)
    elseif kind == 'astral' then paintAstral(x, rnd)
    elseif BG_PAINT[kind] then BG_PAINT[kind](x, rnd)
    else
        x:fill(0, 0, AW, FIELD_H, '#44733a')
        local greens = { [0] = '#3c6834', '#4e8241', '#3a6230', '#55894a' }
        for i = 0, 1499 do local c = greens[floor(rnd() * 4)]; local px = floor(rnd() * AW); local py = floor(rnd() * FIELD_H); x:fill(px, py, 1, 1, c) end
        for i = 0, 79 do
            local px = floor(rnd() * AW)
            local py = 10 + floor(rnd() * (FIELD_H - 10))
            x:fill(px, py, 1, 2, '#62a050'); x:fill(px + 2, py + 1, 1, 1, '#62a050')
        end
        local fl = { [0] = '#f1e3c2', '#ffd84a', '#e88aa8' }
        for i = 0, 25 do local c = fl[floor(rnd() * 3)]; local px = floor(rnd() * AW); local py = 10 + floor(rnd() * (FIELD_H - 12)); x:fill(px, py, 1, 1, c) end
        x:fill(0, 0, AW, 7, '#2b4c25')
        for i = 0, AW - 1, 2 do x:fill(i, 7, 2, floor(rnd() * 3), '#2b4c25') end
        for i = 0, AW - 1, 5 do local py = 2 + floor(rnd() * 3); x:fill(i, py, 3, 2, '#365f2e') end
    end
    x:fill(0, FIELD_H, AW, 2, PAL.k)
    x:fill(0, FIELD_H + 2, AW, AH - FIELD_H - 2, '#5a3a22')
    x:fill(0, FIELD_H + 2, AW, 1, '#7a5233')
    for i = 0, 129 do
        local px = floor(rnd() * AW)
        local py = FIELD_H + 3 + floor(rnd() * (AH - FIELD_H - 4))
        local w = 2 + floor(rnd() * 4)
        x:fill(px, py, w, 1, '#4a2f1b')
    end
    for i = 0, BENCH_N - 1 do
        local p = bPos(i)
        x:fill(p.x - 13, 148, 26, 26, '#3e2715')
        x:fill(p.x - 13, 148, 26, 1, '#2b1a0e'); x:fill(p.x - 13, 148, 1, 26, '#2b1a0e')
        x:fill(p.x - 13, 173, 26, 1, '#6b4527'); x:fill(p.x + 12, 148, 1, 26, '#6b4527')
    end
    return x
end
function corners(ctx, x0, y0, w, h, color, len)
    ctx.fillStyle = color
    local l = OR(len, 3)
    ctx:fillRect(x0, y0, l, 1); ctx:fillRect(x0, y0, 1, l)
    ctx:fillRect(x0 + w - l, y0, l, 1); ctx:fillRect(x0 + w - 1, y0, 1, l)
    ctx:fillRect(x0, y0 + h - 1, l, 1); ctx:fillRect(x0, y0 + h - l, 1, l)
    ctx:fillRect(x0 + w - l, y0 + h - 1, l, 1); ctx:fillRect(x0 + w - 1, y0 + h - l, 1, l)
end
function frameRect(ctx, x0, y0, w, h, color)
    ctx.fillStyle = color
    ctx:fillRect(x0, y0, w, 1); ctx:fillRect(x0, y0 + h - 1, w, 1); ctx:fillRect(x0, y0, 1, h); ctx:fillRect(x0 + w - 1, y0, 1, h)
end
function cellRect(s)
    local p = slotPos(s)
    if s.t == 'f' then return { x = p.x - 13, y = p.y - 16, w = 26, h = 28 } end
    return { x = p.x - 13, y = 148, w = 26, h = 26 }
end
function drawShadow(x, y, color, big, wide)
    local w = big and 18 or (wide and 12 or 10)
    actx.fillStyle = color
    if color:sub(1, 1) == '#' then actx.globalAlpha = 0.7 end
    actx:fillRect(round(x - w / 2), round(y + 7), w, 1)
    actx:fillRect(round(x - w / 2 + 1), round(y + 8), w - 2, 1)
    actx.globalAlpha = 1
end
function drawSupLight(x, y) -- 超凡角色脚下一圈呼吸的红光
    local k, X, Y = supPulse(), round(x), round(y)
    actx.fillStyle = '#ff2a2a'
    actx.globalAlpha = 0.22 + 0.2 * k; actx:fillRect(X - 10, Y + 7, 20, 1); actx:fillRect(X - 8, Y + 6, 16, 1); actx:fillRect(X - 8, Y + 8, 16, 1)
    actx.globalAlpha = 0.45 + 0.3 * k; actx:fillRect(X - 6, Y + 7, 12, 1)
    actx.fillStyle = '#ff8e6a'; actx.globalAlpha = 0.5 + 0.4 * k; actx:fillRect(X - 3, Y + 7, 6, 1)
    actx.globalAlpha = 1
end
function supEmbers(x, y) -- 往上飘的血色余烬
    if REDUCED or js.random() > 0.35 then return end
    local px = x + rand(-7, 7)
    local py = y + rand(-8, 6)
    local vx = rand(-3, 3)
    local vy = -rand(12, 24)
    local color = pick(A('#ff3434', '#ff8e6a', '#a8102a', '#ff3434'))
    local size = (js.random() < 0.2) and 2 or 1
    FX.parts:push({ x = px, y = py, vx = vx, vy = vy, g = 0, life = 0.7, max = 0.7, color = color, size = size })
end
function drawBadge(x, y, star, branch)
    if branch and BRANCHES[branch].sup then
        local c = spr('supbadge', SUP_PAL, false, false, 'supbadge'); actx:drawImage(c, round(x - 3), round(y - 3))
    elseif branch then
        local c = spr('crown'); actx:drawImage(c, round(x - 3), round(y - 3))
    else drawStars(x, y, star) end
end
function drawStars(x, y, n)
    local sx = round(x - (n * 4 - 1) / 2) + 1
    for i = 0, n - 1 do
        local cx, cy = sx + i * 4, round(y)
        actx.fillStyle = PAL.k; actx:fillRect(cx - 1, cy - 1, 3, 3)
        actx.fillStyle = STAR_COLOR[n]
        actx:fillRect(cx, cy - 1, 1, 3); actx:fillRect(cx - 1, cy, 3, 1)
    end
end
function drawHp(e)
    local w = e.big and 22 or 12
    local x0 = round(e.x - w / 2)
    local y0 = round(e.y - (((e.giant or 0) > 0) and 28 or (e.big and 20 or (e.tall and 16 or (e.mid and 13 or 11)))))
    actx.fillStyle = PAL.k; actx:fillRect(x0 - 1, y0 - 1, w + 2, e.skill and 6 or 4)
    actx.fillStyle = '#3a2d52'; actx:fillRect(x0, y0, w, 2)
    actx.fillStyle = e.minion and '#b9a6ff' or ((e.side == 'p') and '#6be06b' or '#ff5a4a')
    actx:fillRect(x0, y0, max(1, round(w * e.hp / e.maxHp)), 2)
    if e.shield > 0 then actx.fillStyle = '#d6f2ff'; actx:fillRect(x0, y0, max(1, round(w * min(1, e.shield / e.maxHp))), 1) end
    if e.elite then actx.fillStyle = PAL.k; actx:fillRect(x0 - 4, y0 - 1, 3, 3); actx.fillStyle = '#ff4a4a'; actx:fillRect(x0 - 3, y0, 1, 1) end
    if e.skill then
        actx.fillStyle = '#2d2245'; actx:fillRect(x0, y0 + 3, w, 1)
        local full = e.energy >= 100
        actx.fillStyle = full and ((floor(G.time * 10) % 2 ~= 0) and '#ffffff' or '#6ef0ff') or '#3fa8ff'
        actx:fillRect(x0, y0 + 3, round(w * e.energy / 100), 1)
    end
end
function drawImg(img, x, y, sc)
    sc = OR(sc, 1)
    actx:drawImage(img, round(x - img.width * sc / 2), round(y + 8 - img.height * sc), img.width * sc, img.height * sc)
end

-- ---------- 攻击动画：蓄力 → 出手 → 收招 ----------
local function pv(o, k, d) if o[k] == nil then return d end return o[k] end
function easeOut(k) return 1 - (1 - k) * (1 - k) end
local function mixPose(Ap, Z, k)
    return {
        x = pv(Ap, 'x', 0) + (pv(Z, 'x', 0) - pv(Ap, 'x', 0)) * k, y = pv(Ap, 'y', 0) + (pv(Z, 'y', 0) - pv(Ap, 'y', 0)) * k,
        lean = pv(Ap, 'lean', 0) + (pv(Z, 'lean', 0) - pv(Ap, 'lean', 0)) * k,
        sx = pv(Ap, 'sx', 1) + (pv(Z, 'sx', 1) - pv(Ap, 'sx', 1)) * k, sy = pv(Ap, 'sy', 1) + (pv(Z, 'sy', 1) - pv(Ap, 'sy', 1)) * k, wind = 0,
    }
end
function atkTiming(e) -- 出手 S、定格 H、收招 R；攻速快的单位动作更利落
    local t = clamp(OR(e.cd, 1) / 0.9, 0.55, 1.25)
    return { S = 0.06 * t, H = 0.07 * t, R = 0.17 * t }
end
function poseOf(e)
    local P = ATK_POSE[atkStyle(e)]
    local a, Tm = e.atkT, atkTiming(e)
    if REDUCED then
        if a < 0.12 and T(P.h.x) then return { x = js.sign(P.h.x) * round((1 - a / 0.12) * 2), y = 0, lean = 0, sx = 1, sy = 1, wind = 0 } end
        return nil
    end
    if a < Tm.S + Tm.H + Tm.R then
        local amp = e.atkBig and 1.4 or 1
        local H = { x = pv(P.h, 'x', 0) * amp, y = pv(P.h, 'y', 0), lean = pv(P.h, 'lean', 0) * amp, sx = pv(P.h, 'sx', 1), sy = pv(P.h, 'sy', 1) }
        local o
        if a < Tm.S + Tm.H then
            local k = (a < Tm.S) and easeOut(a / Tm.S) or 1
            o = mixPose(P.w, H, k); o.ph = 'strike'; o.k = k
        else
            local r = (a - Tm.S - Tm.H) / Tm.R
            local sm = r * r * (3 - 2 * r)
            o = mixPose(H, {}, sm); o.ph = 'rec'; o.r = sm
        end
        local hop = pv(P.h, 'hop', 0) * amp
        if T(hop) then o.y = o.y - hop * sin(PI * min(1, a / (Tm.S + Tm.H))) end
        return o
    end
    if not e.ready or e.stun > 0 or e.channel or (e.cast or 0) > 0 then return nil end
    local W = (P == ATK_POSE.bow) and min(0.42, OR(e.cd, 1) * 0.55) or min(0.24, OR(e.cd, 1) * 0.45)
    local w = clamp(1 - e.cdLeft / W, 0, 1)
    if w <= 0 then return nil end
    local o = mixPose({}, P.w, w * w)
    o.wind = w; o.ph = 'wind'
    return o
end
-- 按姿势逐行绘制像素图：整行平移做前倾（保持像素整齐），按比例缩放做挤压拉伸，脚底始终贴地
-- pad：图片四周多出来的像素（品质光晕图是 1）
function posedXf(w, h, x, y, sc, P, pad)
    local cw, ch = w - pad * 2, h - pad * 2
    local sx, sy = P and P.sx or 1, P and P.sy or 1
    local ux = max(1, round(cw * sc * sx)) / cw
    local uy = max(1, round(ch * sc * sy)) / ch
    return { ux = ux, uy = uy, cw = cw, ch = ch, left = round(x - cw * ux / 2 - pad * ux), top = round(y + 8 - ch * uy - pad * uy) }
end
function drawPosed(img, x, y, sc, P, f, pad)
    sc = OR(sc, 1); pad = OR(pad, 0); f = OR(f, 1)
    local w, h = img.width, img.height
    local sx, sy, lean = P and P.sx or 1, P and P.sy or 1, P and P.lean or 0
    local X = posedXf(w, h, x, y, sc, P, pad)
    local ux, uy, ch, left, top = X.ux, X.uy, X.ch, X.left, X.top
    local dw = round(w * ux)
    if round(lean) == 0 and sx == 1 and sy == 1 then actx:drawImage(img, left, top, dw, round(h * uy)); return end
    actx:beginBatch() -- 逐行绘制的各行互不重叠：合成一批，按颜色一次填充（性能）
    for r = 0, h - 1 do
        local y0, y1 = top + round(r * uy), top + round((r + 1) * uy)
        if y1 > y0 then
            local off = round(lean * f * (1 - (r - pad + 0.5) / ch))
            actx:drawImage(img, 0, r, w, 1, left + off, y0, dw, y1 - y0)
        end
    end
    actx:endBatch()
end

-- ---------- 武器摆动 ----------
local wpnCache = {}
function wpnImg(name, over, flash, key, deg, flip) -- 旋转后的武器（按 6° 取整缓存），握把在画布正中那一格
    local q = round(deg / 6) * 6
    local ck = name .. '|' .. (key or '') .. '|' .. (flash and 1 or 0) .. '|' .. S(q) .. '|' .. (flip and 1 or 0)
    local c = wpnCache[ck]
    if c then return c end
    local R = rigOf(name)
    local n = R.rad * 2 + 1
    c = PX.newImage(n, n)
    if flip then
        local src = wpnImg(name, over, flash, key, q, false)
        for y = 0, n - 1 do for x = 0, n - 1 do
            local col = src.data[y * n + x]
            if col then c.data[y * n + (n - 1 - x)] = col end
        end end
    else
        local src = spr(name, over, flash, false, key, 2)
        local w, h = src.width, src.height
        local a = -q * PI / 180
        local cs, sn = cos(a), sin(a)
        for j = 0, n - 1 do
            for i = 0, n - 1 do -- 反向旋转取最近的像素，保持像素画的硬边
                local dx, dy = i - R.rad, j - R.rad
                local sx = floor(R.p[0] + dx * cs - dy * sn)
                local sy = floor(R.p[1] + dx * sn + dy * cs)
                if not (sx < 0 or sy < 0 or sx >= w or sy >= h) then
                    local col = src.data[sy * w + sx]
                    if col then c.data[j * n + i] = col end
                end
            end
        end
    end
    wpnCache[ck] = c
    return c
end
function rigAngle(R, P) -- 当前武器相对原图转了多少度、沿武器方向推了多少像素
    local Mv = WEAPON_MOVE[R.k]
    local dw, dh, pw, ph = Mv.w - R.base, Mv.h - R.base, Mv.pw or 0, Mv.ph or 0
    local rot, push
    if P.ph == 'wind' then local k = P.wind * P.wind; rot = dw * k; push = pw * k
    elseif P.ph == 'strike' then rot = dw + (dh - dw) * P.k; push = pw + (ph - pw) * P.k
    else rot = dh * (1 - P.r); push = ph * (1 - P.r) end
    return { rot = rot, push = push, dir = R.base + rot, M = Mv }
end
-- 身体照常按姿势画，武器单独旋转后贴到握把上；返回握把位置给刀光、法杖光点用
function drawRigged(e, Ar, R, flash, x, y, sc, P)
    local name, over, key = Ar[0], Ar[1], Ar[2]
    local f = e.face
    local flip = f < 0
    local body = spr(name, over, flash, flip, key, 1)
    local W = rigAngle(R, P)
    local X = posedXf(body.width, body.height, x, y, sc, P, 0)
    local row = floor(R.p[1])
    local off = round(P.lean * f * (1 - (row + 0.5) / X.ch))
    local dr = W.dir * PI / 180
    local cx = X.left + (flip and (body.width - R.p[0]) or R.p[0]) * X.ux + off + f * cos(dr) * W.push * sc
    local cy = X.top + R.p[1] * X.uy + sin(dr) * W.push * sc
    local wi = wpnImg(name, over, flash, key, W.rot, flip)
    local L, Tp = round(cx - (R.rad + 0.5) * sc), round(cy - (R.rad + 0.5) * sc)
    if T(e.q) and not e.dead then
        drawQGlow(body, x, y, e.q, sc, P, f)
        local prev = actx.globalAlpha
        if e.q >= Q_SUP then
            local k = supPulse()
            local g1 = glowImg(wi, SUP_GLOW, true)
            local g2 = glowImg(g1, SUP_HALO, true)
            actx.globalAlpha = prev * (0.3 + 0.35 * k); actx:drawImage(g2, L - 2 * sc, Tp - 2 * sc, g2.width * sc, g2.height * sc)
            actx.globalAlpha = prev * (0.75 + 0.25 * k); actx:drawImage(g1, L - sc, Tp - sc, g1.width * sc, g1.height * sc)
        else
            local g = glowImg(wi, QUAL[e.q].color)
            actx.globalAlpha = prev * qGlowAlpha(e.q)
            actx:drawImage(g, L - sc, Tp - sc, g.width * sc, g.height * sc)
        end
        actx.globalAlpha = prev
    end
    drawPosed(body, x, y, sc, P, f)
    actx:drawImage(wi, L, Tp, wi.width * sc, wi.height * sc)
    local tr = (R.base + W.rot) * PI / 180
    return { cx = cx, cy = cy, R = R, W = W, tip = { x = cx + f * cos(tr) * R.len * sc, y = cy + sin(tr) * R.len * sc } }
end
function drawBow(e, Ar, R, flash, x, y, sc, P, im)
    local name, over, key = Ar[0], Ar[1], Ar[2]
    local f = e.face
    local flip = f < 0
    local body, hand = spr(name, over, flash, flip, key, 3), spr(name, over, flash, flip, key, 4)
    local w = body.width
    local X = posedXf(w, body.height, x, y, sc, P, 0)
    local Tm, a = atkTiming(e), e.atkT
    local pull, handBack, vib, nocked = 0, 0, 0, false
    if P.ph == 'wind' then -- 拉弦：先快后慢，最后一小段拉满停住
        pull = round(R.pull * easeOut(min(1, P.wind * 1.25)))
        handBack = pull; nocked = P.wind > 0.04
    else -- 松弦：弦往前弹过头再来回抖，手停在拉满的位置，收招时才放下
        local s = a - Tm.S
        vib = (a < Tm.S) and 1 or round(sin(s * 55) * 1.4 * max(0, 1 - s / (Tm.H + Tm.R)))
        handBack = round(R.pull * ((P.ph == 'rec') and (1 - P.r) or 1))
    end
    if T(e.q) and not e.dead then drawQGlow(im, x, y, e.q, sc, P, f) end
    drawPosed(body, x, y, sc, P, f)
    local lean = P.lean or 0
    local cw, ch = max(1, round(X.ux)), max(1, round(X.uy))
    local function dot(c, r, col)
        local off = round(lean * f * (1 - (r + 0.5) / X.ch))
        actx.fillStyle = col
        actx:fillRect(round(X.left + (flip and (w - 1 - c) or c) * X.ux + off), round(X.top + r * X.uy), cw, ch)
    end
    local nx, ny = R.n[0] - pull + vib, R.n[1]
    local function colAt(r)
        if r <= ny then return R.a[0] + (nx - R.a[0]) * (r - R.a[1]) / (ny - R.a[1]) end
        return nx + (R.b[0] - nx) * (r - ny) / (R.b[1] - ny)
    end
    local pts = {}
    for r = R.a[1] + 1, R.b[1] - 1 do pts[#pts + 1] = { round(colAt(r)), r } end
    local strCol = flash and '#ffffff' or ((over and over.t) or PAL.t)
    for _, p in ipairs(pts) do dot(p[1] - 1, p[2], PAL.k) end -- 弦后面一像素的描边，和原图一致
    for _, p in ipairs(pts) do dot(p[1], p[2], strCol) end
    if nocked then -- 搭在弦上的箭：箭尾羽毛用本职业的光环色，能量满时箭头闪烁
        local red, poison, bone = e.proj == 'rarrow', e.proj == 'parrow', e.proj == 'earrow'
        local shaft = red and '#ff3434' or (poison and '#4fbf4a' or (bone and '#bdb4a0' or '#c99a5b'))
        local head = red and '#fff2ea' or (poison and '#d6ff9a' or '#ffffff')
        local fl = atkFxCol(e)
        local charged = e.skill and e.energy >= 100 and not T(e.charmed)
        local tip = nx + R.len
        for c = nx + 1, tip - 1 do dot(c, ny, shaft) end
        dot(tip - 1, ny - 1, '#8d9ab2'); dot(tip - 1, ny + 1, '#8d9ab2')
        dot(tip, ny, (charged and floor(G.time * 12) % 2 ~= 0) and fl or head)
        dot(nx + 1, ny - 1, fl); dot(nx + 1, ny + 1, fl)
        if charged and not REDUCED and js.random() < 0.45 then
            local tx = X.left + (flip and (w - 1 - tip) or tip) * X.ux + 0.5
            local ty = X.top + ny * X.uy + 0.5
            local an = js.random() * PI * 2
            local d = 7
            FX.parts:push({ x = tx + cos(an) * d, y = ty + sin(an) * d, vx = -cos(an) * d / 0.16, vy = -sin(an) * d / 0.16, g = 0, life = 0.15, max = 0.15, color = fl, size = 1 })
        end
    end
    drawPosed(hand, x - f * handBack * sc, y, sc, P, f)
end

function px1(x, y, c) actx.fillStyle = c; actx:fillRect(round(x), round(y), 1, 1) end
function pxLine(x0, y0, x1, y1, part, colAt) -- part：从起点画到全长的多少（0~1）
    local n = max(1, round(max(abs(x1 - x0), abs(y1 - y0))))
    local m = round(n * part)
    for i = 0, m do px1(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, colAt(i / n)) end
end
function drawArc(cx, cy, R, f, tail, head, col, heavy, ys) -- 刀光：从头顶后方扫到身前下方的月牙，越靠近刀尖越亮、越粗
    local n = capN('arc', max(3, ceil((head - tail) * R * 1.3)))
    if n < 3 then n = 3 end
    for i = 0, n do
        local u = i / n
        local a = tail + (head - tail) * u
        local c = cos(a) * f
        local sn = sin(a) * ((ys == nil) and 0.85 or ys)
        local hot = (u > 0.8) and '#ffffff' or col
        px1(cx + c * R, cy + sn * R, hot)
        if u > 0.4 then px1(cx + c * (R - 1), cy + sn * (R - 1), hot) end
        if heavy and u > 0.6 then px1(cx + c * (R - 2), cy + sn * (R - 2), col) end
    end
end
function drawAtkFx(e, ox, oy, sc, P, W)
    local st, a, f, Tm, col = atkStyle(e), e.atkT, e.face, atkTiming(e), atkFxCol(e)
    local wk = W and W.R.k
    if e.atkFx and W and wk ~= 'staff' and wk ~= 'spear' and P and P.ph ~= 'wind' then -- 刀光沿着武器尖端真实划过的弧线
        local fade = 0.13
        if a < Tm.S + fade then
            local Mv = W.W.M
            local A0, A1 = Mv.w * PI / 180, Mv.h * PI / 180
            local head = A0 + (A1 - A0) * easeOut(min(1, a / Tm.S))
            local u = clamp((a - Tm.S) / fade, 0, 1)
            local tail = max(A0 + (A1 - A0) * u, head - 2.6)
            local Rr = max(W.R.len, (wk == 'paw') and 6 or ((wk == 'limb' or wk == 'rootclaw') and 8 or 0)) * sc + 0.5
            actx.globalAlpha = 1 - u * 0.4
            drawArc(W.cx, W.cy, Rr, f, tail, head, col, wk == 'heavy' or wk == 'rootmaul' or wk == 'rootclaw' or e.atkBig, 1)
            actx.globalAlpha = 1
        end
    elseif e.atkFx and W and wk == 'spear' and P and P.ph ~= 'wind' then -- 枪尖往前的残影
        if a < Tm.S + 0.12 then
            local g = easeOut(min(1, a / Tm.S))
            local u = clamp((a - Tm.S) / 0.12, 0, 1)
            local d = W.W.dir * PI / 180
            local dx, dy = f * cos(d), sin(d)
            local L = 9 * sc * (e.atkBig and 1.4 or 1)
            local sx, sy = W.tip.x + dx, W.tip.y + dy
            pxLine(sx + dx * L * u, sy + dy * L * u, sx + dx * L * g, sy + dy * L * g, 1, function(k) return (k > 0.7) and '#ffffff' or col end)
        end
    elseif e.atkFx and not W then
        if st == 'slash' or st == 'maul' then
            local fade = 0.13
            if a < Tm.S + fade then
                local A0, A1, heavy = -2.0, 0.95, st == 'maul'
                local head = A0 + (A1 - A0) * easeOut(min(1, a / Tm.S))
                local u = clamp((a - Tm.S) / fade, 0, 1)
                local tail = max(A0 + (A1 - A0) * u, head - 2.6)
                local R = ((heavy and 10 or 9) + (e.big and 6 or 0)) * sc * (e.atkBig and 1.25 or 1)
                actx.globalAlpha = 1 - u * 0.4
                drawArc(ox + f * sc, oy - (e.big and 6 or 3) * sc, R, f, tail, head, col, heavy or e.atkBig)
                actx.globalAlpha = 1
            end
        elseif st == 'thrust' then
            if a < Tm.S + 0.12 then
                local g = easeOut(min(1, a / Tm.S))
                local u = clamp((a - Tm.S) / 0.12, 0, 1)
                local x0, L, yy = ox + f * 7 * sc, 10 * sc * (e.atkBig and 1.4 or 1), oy - 3 * sc
                local hx, tx = x0 + f * L * g, x0 + f * L * u
                pxLine(tx, yy, hx, yy, 1, function(k) return (k > 0.7) and '#ffffff' or col end)
                if g > 0.5 then pxLine(hx - f * 4, yy + 1, hx - f, yy + 1, 1, function() return col end) end
            end
        end
    end
    if e.atkFx then
        if st == 'claw' and e.atkTx ~= nil then
            if a < 0.24 then
                local g = min(1, a / 0.07)
                actx.globalAlpha = (a < 0.12) and 1 or (1 - (a - 0.12) / 0.12)
                for i = -1, 1 do
                    local bx, by = e.atkTx + i * 3, e.atkTy - 4 + abs(i)
                    pxLine(bx - f * 2, by - 5, bx + f * 2, by + 3, g, function(k) return (k > 0.25 and k < 0.75) and '#ffffff' or col end)
                end
                actx.globalAlpha = 1
            end
        end
    end
    if not P or not T(P.wind) then return end
    local w = P.wind
    if st == 'bow' and not bowRigOf(entSprArgs(e)[0]) then -- 没有弓弦骨架的弓手：箭跟着弦往后拉
        local tl, c = 5 - 3 * w, projCol(e)
        pxLine(ox + f * tl * sc, oy, ox + f * (tl + 5) * sc, oy, 1, function(k) return (k > 0.8) and '#ffffff' or c end)
    elseif st == 'cast' or st == 'bloom' or st == 'pulse' then -- 法杖顶端聚能
        local p = W and W.tip or atkTip(e, ox, oy)
        local c = projCol(e)
        local r = (w > 0.66) and 2 or ((w > 0.33) and 1 or 0)
        local x, y = round(p.x), round(p.y)
        actx.globalAlpha = 0.5 + 0.5 * w; actx.fillStyle = c
        actx:fillRect(x - r, y, r * 2 + 1, 1); actx:fillRect(x, y - r, 1, r * 2 + 1)
        actx.globalAlpha = 1
        if w > 0.5 then px1(x, y, '#ffffff') end
        if js.random() < 0.35 then
            local an = js.random() * PI * 2
            local d = 7
            FX.parts:push({ x = p.x + cos(an) * d, y = p.y + sin(an) * d, vx = -cos(an) * d / 0.16, vy = -sin(an) * d / 0.16, g = 0, life = 0.15, max = 0.15, color = c, size = 1 })
        end
    end
end
function drawLava(f) -- 熔岩池
    local a, h = clamp(f.t / 0.6, 0, 1), f.r / 1.6
    h = capN('lava', h)
    actx.globalAlpha = a
    for dy = -floor(h), h do
        local w = round(f.r * sqrt(max(0, 1 - (dy / h) * (dy / h))))
        actx.fillStyle = (abs(dy) >= h - 1) and 'rgba(122,31,43,0.8)' or 'rgba(226,84,31,0.55)'
        actx:fillRect(round(f.x - w), round(f.y + dy), w * 2, 1)
    end
    for i = 0, 9 do
        local ang = i * 2.4 + floor(G.time * 5) * 0.7
        local rr = f.r * 0.8 * ((i * 7) % 10) / 10
        actx.fillStyle = (i % 3 ~= 0) and '#ff8a2a' or '#ffe14a'
        actx:fillRect(round(f.x + cos(ang) * rr), round(f.y + sin(ang) * rr / 1.6), 1, 1)
    end
    actx.globalAlpha = 1
end
function drawFissure(f) -- 地裂：先闪烁预警，再喷发
    local n = max(1, round(hypot(f.x2 - f.x, f.y2 - f.y) / 3))
    n = capN('fissure', n)
    if not f.fired then
        if floor(G.time * 10) % 2 ~= 0 then return end
        actx.fillStyle = '#ff4a3a'
        for i = 2, n, 2 do local k = i / n; actx:fillRect(round(f.x + (f.x2 - f.x) * k), round(f.y + (f.y2 - f.y) * k), 2, 1) end
        return
    end
    actx.globalAlpha = clamp(f.t / 0.5, 0, 1)
    for i = 1, n do
        local k = i / n
        local x, y = round(f.x + (f.x2 - f.x) * k), round(f.y + (f.y2 - f.y) * k)
        actx.fillStyle = '#7a1f2b'; actx:fillRect(x - 1, y, 3, 2)
        actx.fillStyle = (i % 2 ~= 0) and '#ff8a2a' or '#ffe14a'; actx:fillRect(x, y, 1, 1)
    end
    actx.globalAlpha = 1
end
function drawRift(f) -- 虚空新星：外圈闪烁预警，内圈收缩计时
    if f.fired then return end
    local k, n = clamp((f.max - f.t) / f.warn, 0, 1), 20
    actx.fillStyle = (floor(G.time * 10) % 2 ~= 0) and '#c06bff' or '#ffffff'
    for i = 0, n - 1 do local a = i / n * 6.283; actx:fillRect(round(f.x + cos(a) * f.r), round(f.y + sin(a) * f.r * 0.6), 1, 1) end
    actx.fillStyle = '#8f4bc4'
    local rr = f.r * (1 - k)
    for i = 0, n - 1, 2 do local a = i / n * 6.283 + G.time * 3; actx:fillRect(round(f.x + cos(a) * rr), round(f.y + sin(a) * rr * 0.6), 1, 1) end
end
function drawLink(a, b) -- 晶柱向巨像输送熔岩
    local n, off = max(1, round(hypot(b.x - a.x, b.y - a.y) / 3)), floor(G.time * 12) % 3
    n = capN('link', n)
    actx.fillStyle = '#ffb03a'
    for i = off, n - 1, 3 do local k = i / n; actx:fillRect(round(a.x + (b.x - a.x) * k), round(a.y - 4 + (b.y - 6 - a.y + 4) * k), 1, 1) end
end
function drawBloodMoon(m) -- 血月降临：天上浮现一轮血月
    local a = clamp(min((m.max - m.t) / 0.25, m.t / 0.4), 0, 1)
    local cx, cy, r = 128, 22, 9
    local function disk(rr, col, al)
        actx.globalAlpha = al; actx.fillStyle = col
        for dy = -rr, rr do local w = round(sqrt(rr * rr - dy * dy)); actx:fillRect(cx - w, cy + dy, w * 2 + 1, 1) end
    end
    disk(r + 5, '#ff2a2a', 0.18 * a); disk(r + 2, '#ff2a2a', 0.3 * a); disk(r, '#a8102a', a); disk(r - 2, '#d81e30', a)
    actx.globalAlpha = a; actx.fillStyle = '#ff6a5a'; actx:fillRect(cx - 5, cy - 6, 4, 2); actx:fillRect(cx - 6, cy - 4, 2, 3)
    actx.fillStyle = '#7a0f20'; actx:fillRect(cx + 2, cy - 1, 3, 2); actx:fillRect(cx - 3, cy + 3, 2, 2); actx:fillRect(cx + 4, cy + 4, 2, 1)
    actx.globalAlpha = 1
end
function drawBlizzard(f) -- 暴风雪：斜落的雪片（全场暴风雪只画飘雪，不画边界）
    local n = f.perm and 40 or 22
    local a = clamp(min(f.t, f.max - f.t + 0.3) / 0.4, 0, 1)
    actx.globalAlpha = a
    if not f.perm then
        actx.fillStyle = 'rgba(190,230,255,0.18)'
        local h = f.r / 1.4
        h = capN('blizzard', h)
        for dy = -floor(h), h, 1 do
            local w = round(f.r * sqrt(max(0, 1 - (dy / h) * (dy / h))))
            actx:fillRect(round(f.x - w), round(f.y + dy), w * 2, 1)
        end
    end
    for i = 0, n - 1 do
        local k = math.fmod(i * 0.618 + G.time * (0.9 + (i % 3) * 0.2), 1)
        ---@type number, number
        local px, py
        if f.perm then px = math.fmod(i * 37.3 + G.time * 18, AW); py = 8 + k * (FIELD_H - 10)
        else
            local ang = i * 2.39996
            local rr = f.r * (0.15 + 0.85 * math.fmod(i * 0.37, 1))
            px = f.x + cos(ang) * rr - 6 + k * 12; py = f.y + sin(ang) * rr / 1.4 - 8 + k * 14
        end
        actx.fillStyle = (i % 3 == 0) and '#bfe8ff' or '#ffffff'
        actx:fillRect(round(px), round(py), 1, 1)
    end
    actx.globalAlpha = 1
end
function drawStarMark(f) -- 星陨：金色预警圈，内圈收缩
    if f.fired then return end
    local k, n = clamp((f.max - f.t) / f.warn, 0, 1), 20
    actx.fillStyle = (floor(G.time * 10) % 2 ~= 0) and '#ffd84a' or '#ffffff'
    for i = 0, n - 1 do local a = i / n * 6.283; actx:fillRect(round(f.x + cos(a) * f.r), round(f.y + sin(a) * f.r * 0.6), 1, 1) end
    actx.fillStyle = '#b8892a'
    local rr = f.r * (1 - k)
    for i = 0, n - 1, 2 do local a = i / n * 6.283 - G.time * 3; actx:fillRect(round(f.x + cos(a) * rr), round(f.y + sin(a) * rr * 0.6), 1, 1) end
    actx.fillStyle = '#fff6d0'; actx:fillRect(round(f.x), round(f.y - 40 + 38 * k), 1, 3) -- 坠落中的星
end
function drawAuraRing(e) -- 方尖碑的减伤范围
    actx.globalAlpha = 0.35; actx.fillStyle = '#ffd84a'
    local n, off = 36, G.time * 0.6
    for i = 0, n - 1, 2 do local a = i / n * 6.283 + off; actx:fillRect(round(e.x + cos(a) * 60), round(e.y + sin(a) * 36), 1, 1) end
    actx.globalAlpha = 1
end
function drawCloud(f)
    local a = clamp(f.t / 0.6, 0, 1)
    for i = 0, 17 do
        local ang = i * 2.4 + G.time * (0.6 + (i % 3) * 0.3)
        local rr = f.r * (0.25 + 0.75 * ((i * 7) % 10) / 10)
        actx.globalAlpha = a * 0.75
        actx.fillStyle = (i % 3 == 0) and (f.foe and '#9be36b' or '#c06bff') or (f.foe and '#4f8a3a' or '#7a4a9a')
        actx:fillRect(round(f.x + cos(ang) * rr), round(f.y + sin(ang) * rr / 1.4), 2, 1)
    end
    actx.globalAlpha = 1
end
function drawThornZone(f)
    actx.globalAlpha = clamp(f.t / 0.5, 0, 1) * 0.8
    for i = 0, 23 do
        local ang = i / 24 * 6.283 + G.time * 0.4
        actx.fillStyle = (i % 2 == 0) and '#2f7a34' or '#ff6a8a'
        actx:fillRect(round(f.x + cos(ang) * f.r), round(f.y + sin(ang) * f.r * 0.55), 1, 2)
    end
    actx.globalAlpha = 1
end
function drawField(f)
    if FIELD_DRAW[f.kind] then return FIELD_DRAW[f.kind](f) end
    if f.kind == 'cloud' then return drawCloud(f) end
    if f.kind == 'thornzone' then return drawThornZone(f) end
    if f.kind == 'blizzard' then return drawBlizzard(f) end
    if f.kind == 'star' then return drawStarMark(f) end
    if f.kind == 'lava' then return drawLava(f) end
    if f.kind == 'fissure' then return drawFissure(f) end
    if f.kind == 'rift' then return drawRift(f) end
    -- 黑洞
    local n = 16
    for i = 0, n - 1 do
        local k = math.fmod((i / n) + G.time * 0.8, 1)
        local rr, a = f.r * (1 - k), i * 2.4 + G.time * 5
        actx.fillStyle = (i % 3 ~= 0) and '#8f4bc4' or '#e0b0ff'
        actx:fillRect(round(f.x + cos(a) * rr), round(f.y + sin(a) * rr * 0.6), 1, 1)
    end
    actx.fillStyle = PAL.k; actx:fillRect(round(f.x) - 2, round(f.y) - 2, 5, 5)
    actx.fillStyle = '#5a2a7a'; actx:fillRect(round(f.x) - 1, round(f.y) - 1, 3, 3)
end

function drawUnitPrep(u, x, y, lifted)
    local bob = lifted and 0 or ((sin(G.time * 3 + u.id) > 0.3) and -1 or 0)
    local dy, flash = 0, false
    if u.pop > 0 then dy = -round(u.pop * u.pop * 60); flash = u.pop > 0.32 end
    local sup = isSup(u)
    if not lifted then if sup then drawSupLight(x, y) else drawShadow(x, y, auraOf(u.star, u.branch), false, not not u.branch) end end
    if sup then supEmbers(x, y + dy) end
    if (u.star == 3 or u.branch) and js.random() < (u.branch and 0.08 or 0.04) then
        local px, py = x + rand(-6, 6), y + rand(-6, 6)
        FX.parts:push({ x = px, y = py, vx = 0, vy = -12, g = 0, life = 0.6, max = 0.6, color = u.branch and BRANCHES[u.branch].aura or '#ffe680', size = 1 })
    end
    if (u.q or 0) >= 2 and js.random() < (((u.q or 0) >= 3) and 0.12 or 0.05) then
        local px, py = x + rand(-7, 7), y + rand(-8, 6)
        FX.parts:push({ x = px, y = py, vx = 0, vy = -10, g = 0, life = 0.5, max = 0.5, color = QUAL[u.q].color, size = 1 })
    end
    local img
    if u.awakenReady and floor(G.time * 3) % 2 == 0 then img = unitImg(u.cls, u.star, nil, true, false)
    else img = unitImg(u.cls, u.star, u.branch, flash, false) end
    drawQGlow(img, x, y + bob + dy, u.q or 0)
    drawImg(img, x, y + bob + dy)
    drawBadge(x, y - (sup and 16 or (u.branch and 14 or 12)) + bob + dy, u.star, u.branch)
end

local PROJ_MAIN = { orb = '#6ef0ff', frost = '#bff4ff', spark = '#ffe14a', holy = '#fff3b0', fireball = '#ff8a2a', lavaball = '#e2541f', bloodorb = '#ff3434', sunfire = '#ff8e6a' }
local PROJ_CORE = { orb = '#ffffff', frost = '#ffffff', spark = '#ffffff', holy = '#ffffff', prism = '#ffffff', fireball = '#ffe14a', lavaball = '#ffb03a', bloodorb = '#fff2ea', sunfire = '#fff2ea' }
function drawProj(p)
    local c, s = cos(p.ang), sin(p.ang)
    local k = p.kind
    if PROJ_DRAW[k] then return PROJ_DRAW[k](p, c, s) end
    if k == 'rock' then
        actx.fillStyle = '#5a4a38'; actx:fillRect(round(p.x) - 2, round(p.y) - 2, 5, 4)
        actx.fillStyle = '#a89878'; actx:fillRect(round(p.x) - 1, round(p.y) - 2, 3, 2)
        if js.random() < 0.4 then FX.parts:push({ x = p.x, y = p.y, vx = rand(-6, 6), vy = -4, g = 0, life = 0.3, max = 0.3, color = '#8a7a62', size = 1 }) end
        return
    end
    if k == 'snipe' then
        for i = 0, 8 do
            actx.fillStyle = (i < 2) and '#ffffff' or ((i < 5) and '#ffe680' or 'rgba(255,230,128,0.4)')
            actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1)
        end
    elseif k == 'meteor' then
        actx.fillStyle = '#ff8a2a'; actx:fillRect(round(p.x) - 2, round(p.y) - 2, 5, 5)
        actx.fillStyle = '#ffe14a'; actx:fillRect(round(p.x) - 1, round(p.y) - 1, 3, 3)
        actx.fillStyle = '#ffffff'; actx:fillRect(round(p.x), round(p.y), 1, 1)
        for i = 0, 1 do
            local x, y, vx, vy = p.x + rand(-2, 2), p.y + rand(-2, 2), rand(-8, 8), rand(-12, -2)
            FX.parts:push({ x = x, y = y, vx = vx, vy = vy, g = 0, life = 0.35, max = 0.35, color = (js.random() < 0.5) and '#ff5a2a' or '#ffb03a', size = 1 })
        end
    elseif k == 'pierce' then
        for i = 0, 9 do
            actx.fillStyle = (i < 2) and '#ffffff' or ((i < 6) and '#9ff6ff' or 'rgba(159,246,255,0.4)')
            actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1)
        end
        if js.random() < 0.6 then FX.parts:push({ x = p.x, y = p.y + rand(-1, 1), vx = 0, vy = 0, g = 0, life = 0.3, max = 0.3, color = '#9ff6ff', size = 1 }) end
    elseif k == 'frostbig' then
        actx.fillStyle = '#7fd0ff'; actx:fillRect(round(p.x) - 2, round(p.y) - 1, 5, 3); actx:fillRect(round(p.x) - 1, round(p.y) - 2, 3, 5)
        actx.fillStyle = '#ffffff'; actx:fillRect(round(p.x) - 1, round(p.y), 3, 1); actx:fillRect(round(p.x), round(p.y) - 1, 1, 3)
        local x, y = p.x + rand(-1, 1), p.y + rand(-1, 1)
        FX.parts:push({ x = x, y = y, vx = 0, vy = 0, g = 0, life = 0.3, max = 0.3, color = '#bff4ff', size = 1 })
    elseif k == 'arcane' then
        actx.fillStyle = '#6ef0ff'; actx:fillRect(round(p.x) - 2, round(p.y) - 1, 5, 3); actx:fillRect(round(p.x) - 1, round(p.y) - 2, 3, 5)
        actx.fillStyle = '#ffffff'; actx:fillRect(round(p.x), round(p.y), 1, 1)
        FX.parts:push({ x = p.x, y = p.y, vx = 0, vy = 0, g = 0, life = 0.3, max = 0.3, color = '#6ef0ff', size = 1 })
    elseif k == 'star' then
        for i = 0, 6 do
            actx.fillStyle = (i < 1) and '#ffffff' or ((i < 3) and '#ffe680' or 'rgba(255,230,128,0.45)')
            actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1)
        end
        actx.fillStyle = '#ffe14a'; actx:fillRect(round(p.x) - 1, round(p.y), 3, 1); actx:fillRect(round(p.x), round(p.y) - 1, 1, 3)
    elseif k == 'rarrow' then -- 赤月弓神的血色箭
        for i = 0, 5 do
            actx.fillStyle = (i == 0) and '#fff2ea' or ((i < 4) and '#ff3434' or '#a8102a')
            actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1)
        end
        if js.random() < 0.5 then FX.parts:push({ x = p.x - c * 4, y = p.y - s * 4, vx = 0, vy = -4, g = 0, life = 0.25, max = 0.25, color = '#ff3434', size = 1 }) end
    elseif k == 'bloodpierce' then -- 赤月天罚：两像素粗的血月巨箭
        for i = 0, 15 do
            actx.fillStyle = (i < 2) and '#ffffff' or ((i < 5) and '#fff2ea' or ((i < 10) and '#ff3434' or 'rgba(255,52,52,0.45)'))
            actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 2)
        end
        actx.fillStyle = '#ff8e6a'; actx:fillRect(round(p.x - c * 2 - s * 2), round(p.y - s * 2 + c * 2), 1, 1); actx:fillRect(round(p.x - c * 2 + s * 2), round(p.y - s * 2 - c * 2) + 1, 1, 1)
        for i = 0, 1 do
            local x = p.x - c * rand(2, 12)
            local y = p.y - s * rand(2, 12) + rand(-2, 3)
            local vx, vy = rand(-8, 8), rand(-14, 6)
            FX.parts:push({ x = x, y = y, vx = vx, vy = vy, g = 0, life = 0.35, max = 0.35, color = (js.random() < 0.5) and '#ff3434' or '#ff8e6a', size = 1 })
        end
    elseif k == 'bloodstar' then -- 血月降临：从天而降的血光
        for i = 0, 8 do
            actx.fillStyle = (i < 1) and '#ffffff' or ((i < 4) and '#ff3434' or 'rgba(168,16,42,0.55)')
            actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1)
        end
        actx.fillStyle = '#ff8e6a'; actx:fillRect(round(p.x) - 1, round(p.y), 3, 1); actx:fillRect(round(p.x), round(p.y) - 1, 1, 3)
    elseif k == 'arrow' or k == 'earrow' or k == 'rain' or k == 'parrow' then
        for i = 0, 4 do
            if i == 0 then actx.fillStyle = (k == 'parrow') and '#d6ff9a' or '#ffffff'
            else actx.fillStyle = (k == 'arrow') and '#c99a5b' or ((k == 'parrow') and '#4fbf4a' or '#bdb4a0') end
            actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1)
        end
    else
        local prism = ({ [0] = '#ff8a2a', '#6ef0ff', '#ffe14a' })[floor(G.time * 12) % 3]
        local main = (k == 'prism') and prism or (PROJ_MAIN[k] or '#b04ad8')
        local core = PROJ_CORE[k] or '#ff8be0'
        if k == 'lavaball' then actx.fillStyle = main; actx:fillRect(round(p.x) - 2, round(p.y) - 1, 5, 3); actx:fillRect(round(p.x) - 1, round(p.y) - 2, 3, 5) end
        actx.fillStyle = main; actx:fillRect(round(p.x) - 1, round(p.y) - 1, 3, 3)
        actx.fillStyle = core; actx:fillRect(round(p.x), round(p.y), 1, 1)
        if js.random() < 0.5 then FX.parts:push({ x = p.x, y = p.y, vx = 0, vy = 0, g = 0, life = 0.25, max = 0.25, color = main, size = 1 }) end
    end
end

function renderArena()
    local ctx = actx
    ctx:clear()
    ctx:save()
    if G.shake > 0 and not REDUCED and G.phase == 'battle' then
        local dx = round(rand(-1.5, 1.5))
        local dy = round(rand(-1.5, 1.5))
        ctx:translate(dx, dy)
    end
    ctx:drawImage(bgFor(curCh().bg), 0, 0)
    if curCh().bg == 'lava' and not REDUCED and js.random() < 0.2 then -- 熔岩裂谷的飘散余烬
        local x, y, vx, vy = rand(0, AW), rand(14, FIELD_H - 4), rand(-3, 3), -rand(6, 14)
        FX.parts:push({ x = x, y = y, vx = vx, vy = vy, g = 0, life = 1, max = 1, color = (js.random() < 0.6) and '#ff8a2a' or '#ffd84a', size = 1 })
    end
    if curCh().bg == 'void' and not REDUCED and js.random() < 0.15 then -- 虚空回廊的浮游微光
        local x, y, vy = rand(0, AW), rand(14, FIELD_H - 4), -rand(3, 8)
        FX.parts:push({ x = x, y = y, vx = 0, vy = vy, g = 0, life = 1.4, max = 1.4, color = (js.random() < 0.5) and '#c06bff' or '#8f7bc4', size = 1 })
    end
    if curCh().bg == 'ice' and not REDUCED and js.random() < 0.25 then -- 霜狱冰原的飘雪
        local x = rand(0, AW)
        FX.parts:push({ x = x, y = 8, vx = rand(-4, 2), vy = rand(10, 18), g = 0, life = 3, max = 3, color = (js.random() < 0.7) and '#ffffff' or '#bfe8ff', size = 1 })
    end
    if curCh().bg == 'astral' and not REDUCED and js.random() < 0.15 then -- 星陨神殿的金色星尘
        local x, y = rand(0, AW), rand(14, FIELD_H - 4)
        FX.parts:push({ x = x, y = y, vx = 0, vy = -rand(3, 7), g = 0, life = 1.4, max = 1.4, color = (js.random() < 0.5) and '#ffd84a' or '#fff6d0', size = 1 })
    end
    local prep = G.phase == 'prep' or G.phase == 'spinning' or G.phase == 'resolving'
    if drawCells and (prep or G.battle) then drawCells(ctx, not prep) end
    if prep then
        ctx.fillStyle = 'rgba(27,21,48,0.22)'
        for y = 10, FIELD_H - 3, 5 do ctx:fillRect(128, y, 1, 3) end
        for i = 0, FORM_N - 1 do local r = cellRect({ t = 'f', i = i }); corners(ctx, r.x, r.y, r.w, r.h, 'rgba(241,227,194,0.28)', 3) end
        if drag and drag.moved and drag.over then
            local t, r = getSlot(drag.over), cellRect(drag.over)
            local col = (not t) and '#8fe07a' or (canAbsorb(drag.u, t) and '#ffd84a' or '#ffffff')
            frameRect(ctx, r.x, r.y, r.w, r.h, col); frameRect(ctx, r.x + 1, r.y + 1, r.w - 2, r.h - 2, col)
        end
        if G.sel and not (drag and drag.moved) then
            local s = findSlot(G.sel)
            if s and floor(G.time * 4) % 2 == 0 then local r = cellRect(s); corners(ctx, r.x - 1, r.y - 1, r.w + 2, r.h + 2, '#ffd84a', 4) end
        end
        local items = A()
        G.form:forEach(function(u, i)
            if u and not (drag and drag.moved and drag.u == u) then
                local p = fPos(i)
                items:push({ y = p.y, f = function() drawUnitPrep(u, p.x, p.y) end })
            end
        end)
        currentLineup():forEach(function(e, k)
            items:push({ y = e.y, f = function()
                local E = ENEMIES[e.type]
                local bob = (sin(G.time * 2.5 + k) > 0.4) and -1 or 0
                drawShadow(e.x, e.y, e.elite and ELITE_AURA or auraOf(1), E.big, e.elite)
                drawImg(spr(E.sprite, E.pal or nil, false, true, E.pal and e.type or ''), e.x, e.y + bob)
                if e.elite then
                    pixText(ctx, '!', e.x, e.y - 17 + bob, '#ff5a4a')
                    if js.random() < 0.06 then
                        local px, py = e.x + rand(-6, 6), e.y + rand(-6, 6)
                        FX.parts:push({ x = px, y = py, vx = 0, vy = -12, g = 0, life = 0.5, max = 0.5, color = '#ff5a4a', size = 1 })
                    end
                end
            end })
        end)
        if drawAnims then drawAnims(0) end
        items:sort(function(a, b) return a.y - b.y end):forEach(function(it) it.f() end)
        G.bench:forEach(function(u, i)
            if u and not (drag and drag.moved and drag.u == u) then local p = bPos(i); drawUnitPrep(u, p.x, p.y) end
        end)
        if drawEquipMarks then drawEquipMarks() end -- 布阵阶段：单位身上的装备标记
        if drawAnims then drawAnims(1) end
    elseif G.battle then
        ---@type table<string, any>
        local B = G.battle
        if B.moon then drawBloodMoon(B.moon) end
        for f in of(B.fields) do drawField(f) end
        if drawAnims then drawAnims(0) end -- 技能特效：地面层（法阵、冲击环……）
        for e in of(B.ents) do
            if e.channel and e.pillars then for p in of(e.pillars) do if not p.dead then drawLink(p, e) end end end
            if not e.dead and T(e.auraDr) then drawAuraRing(e) end
            if not e.dead and e.tether then for p in of(e.tether) do if not p.dead then drawLink(p, e) end end end
        end
        local ents = B.ents:filter(function(e) return not e.dead or e.deadT < 0.35 end):sort(function(a, b) return a.y - b.y end)
        for e in of(ents) do
            repeat
                if e.dead and floor(e.deadT * 20) % 2 ~= 0 then break end
                local bob
                if e.moving then bob = (sin(B.t * 16 + e.phase) > 0) and -1 or 0
                else bob = (sin(B.t * 3 + e.phase) > 0.5) and -1 or 0 end
                local P = (not e.dead) and poseOf(e) or nil -- 攻击姿势：蓄力 → 出手 → 收招
                local ox = e.x + (P and round(P.x) * e.face or 0) + ((e.knock > 0) and e.knockDir or 0)
                local oy = e.y + bob + (P and round(P.y) or 0)
                if not e.dead then
                    if e.sup and not T(e.charmed) then drawSupLight(e.x, e.y)
                    else
                        local col = (e.side == 'p' and not e.minion) and auraOf(e.star, e.branch) or (e.elite and ELITE_AURA or auraOf(1))
                        drawShadow(e.x, e.y, col, e.big, (not not e.branch) or e.elite)
                    end
                end
                if e.sup and not e.dead then supEmbers(e.x, e.y) end
                local flash = e.flash > 0 or e.dead or ((e.inv or 0) > 0 and floor(B.t * 12) % 2 == 0)
                local im = entImg(e, flash, e.face < 0)
                local sc = ((e.giant or 0) > 0) and 2 or 1
                if e.ghost or e.shifted then actx.globalAlpha = e.shifted and 0.3 or 0.6 end
                ---@type any
                local Ar = (P and P.ph) and entSprArgs(e) or nil
                local R = Ar and rigOf(Ar[0])
                local BW = (Ar and not R) and bowRigOf(Ar[0]) or nil
                local W = nil
                if R then W = drawRigged(e, Ar, R, flash, ox, oy, sc, P) -- 武器单独绕握把摆动
                elseif BW then drawBow(e, Ar, BW, flash, ox, oy, sc, P, im) -- 弓手：拉弦、搭箭、松弦
                else
                    if T(e.q) and not e.dead then drawQGlow(im, ox, oy, e.q, sc, P, e.face) end
                    drawPosed(im, ox, oy, sc, P, e.face)
                end
                actx.globalAlpha = 1
                if not e.dead and not e.shifted then drawAtkFx(e, ox, oy, sc, P, W) end
                if not e.dead then
                    drawHp(e)
                    if (e.side == 'p' or T(e.charmed)) and not e.minion then drawBadge(e.x, e.y - ((sc > 1) and 31 or (e.tall and 21 or (e.mid and 17 or 15))), e.star, e.branch) end
                    if e.stun > 0 then
                        local a = B.t * 9
                        actx.fillStyle = '#ffd84a'
                        actx:fillRect(round(e.x + cos(a) * 4), round(e.y - 19 + sin(a) * 1.5), 1, 1)
                        actx:fillRect(round(e.x - cos(a) * 4), round(e.y - 19 - sin(a) * 1.5), 1, 1)
                    end
                    -- 第十五次更新（卡顿）：状态粒子改成直接判断（以前每个单位每帧新建二十多个闭包，条件不满足也照建）。
                    -- 判断顺序、随机数的消耗和以前完全一样，粒子效果不变
                    if (e.burn) and js.random() < (0.3) then local x, y = e.x + rand(-4, 4), e.y + rand(-4, 4); FX.parts:push({ x = x, y = y, vx = 0, vy = -18, g = 0, life = 0.4, max = 0.4, color = (js.random() < 0.5) and '#ff8a2a' or '#ffe14a', size = 1 }) end
                    if (e.slow) and js.random() < (0.25) then local x, y = e.x + rand(-5, 5), e.y + rand(-6, 4); FX.parts:push({ x = x, y = y, vx = 0, vy = 6, g = 0, life = 0.4, max = 0.4, color = (js.random() < 0.5) and '#bff4ff' or '#ffffff', size = 1 }) end
                    if ((e.haste or 0) > 0) and js.random() < (0.3) then local x, y = e.x + rand(-5, 5), e.y + rand(-4, 4); FX.parts:push({ x = x, y = y, vx = 0, vy = -14, g = 0, life = 0.35, max = 0.35, color = '#ff6a4a', size = 1 }) end
                    if (e.shield > 0) and js.random() < (0.12) then local x, y = e.x + rand(-7, 7), e.y + rand(-8, 6); FX.parts:push({ x = x, y = y, vx = 0, vy = -6, g = 0, life = 0.4, max = 0.4, color = '#d6f2ff', size = 1 }) end
                    if (e.poison) and js.random() < (0.2 + (e.poison and e.poison.n or 0) * 0.03) then local x, y = e.x + rand(-4, 4), e.y + rand(-6, 2); FX.parts:push({ x = x, y = y, vx = 0, vy = -10, g = 0, life = 0.45, max = 0.45, color = (js.random() < 0.5) and '#4fbf4a' or '#9be36b', size = 1 }) end
                    if (e.bleed) and js.random() < (0.3) then local x, y = e.x + rand(-4, 4), e.y + rand(-5, 0); FX.parts:push({ x = x, y = y, vx = 0, vy = 16, g = 0, life = 0.4, max = 0.4, color = '#d8433a', size = 1 }) end
                    if (e.guard) and js.random() < (0.2) then local x, y = e.x + rand(-7, 7), e.y + rand(-8, 6); FX.parts:push({ x = x, y = y, vx = 0, vy = -8, g = 0, life = 0.4, max = 0.4, color = '#c9b08a', size = 1 }) end
                    if (e.hot) and js.random() < (0.25) then local x, y = e.x + rand(-5, 5), e.y + rand(-4, 4); FX.parts:push({ x = x, y = y, vx = 0, vy = -14, g = 0, life = 0.4, max = 0.4, color = '#ff8ab8', size = 1 }) end
                    if (e.curse) and js.random() < (0.25) then local x = e.x + rand(-5, 5); FX.parts:push({ x = x, y = e.y - 8, vx = 0, vy = 10, g = 0, life = 0.5, max = 0.5, color = '#2f7a34', size = 1 }) end
                    if ((e.inv or 0) > 0) and js.random() < (0.4) then local x, y = e.x + rand(-6, 6), e.y + rand(-8, 6); FX.parts:push({ x = x, y = y, vx = 0, vy = -16, g = 0, life = 0.4, max = 0.4, color = '#6ef0ff', size = 1 }) end
                    if e.immune and not e.shifted and js.random() < 0.7 then
                        local an = js.random() * 6.28
                        FX.parts:push({ x = e.x + cos(an) * 13, y = e.y - 6 + sin(an) * 11, vx = 0, vy = -6, g = 0, life = 0.3, max = 0.3, color = ((e.shellT or 0) > 0) and '#ffffff' or ((js.random() < 0.5) and '#ffb03a' or '#ffe14a'), size = 1 })
                    end
                    if (T(e.armor)) and js.random() < (0.06) then local x, y = e.x + rand(-6, 6), e.y + rand(-8, 4); FX.parts:push({ x = x, y = y, vx = 0, vy = -4, g = 0, life = 0.35, max = 0.35, color = '#c9a6ff', size = 1 }) end
                    if (e.cast or 0) > 0 then -- 虚空坍缩倒计时
                        pixText(actx, S(ceil(e.cast)), e.x, e.y - 30, '#e0b0ff')
                        if js.random() < 0.8 then
                            local an = js.random() * 6.28
                            FX.parts:push({ x = e.x + cos(an) * 22, y = e.y - 4 + sin(an) * 14, vx = -cos(an) * 30, vy = -sin(an) * 20, g = 0, life = 0.6, max = 0.6, color = '#c06bff', size = 1 })
                        end
                    end
                    if (T(e.charmed)) and js.random() < (0.3) then local x = e.x + rand(-4, 4); FX.parts:push({ x = x, y = e.y - 12, vx = 0, vy = -10, g = 0, life = 0.5, max = 0.5, color = '#ff6ad5', size = 1 }) end
                    if (e.shifted) and js.random() < (0.3) then local x, y = e.x + rand(-5, 5), e.y + rand(-8, 4); FX.parts:push({ x = x, y = y, vx = 0, vy = -6, g = 0, life = 0.4, max = 0.4, color = '#6ef0ff', size = 1 }) end
                    if (T(e.blocks)) and js.random() < (0.08 * (e.blocks or 0)) then local an = js.random() * 6.28; FX.parts:push({ x = e.x + cos(an) * 8, y = e.y - 5 + sin(an) * 8, vx = 0, vy = -4, g = 0, life = 0.35, max = 0.35, color = '#ffd84a', size = 1 }) end
                    if (T(e.furyN)) and js.random() < (0.04 * (e.furyN or 0)) then local x, y = e.x + rand(-5, 5), e.y + rand(-6, 4); FX.parts:push({ x = x, y = y, vx = 0, vy = -14, g = 0, life = 0.4, max = 0.4, color = '#ff5a4a', size = 1 }) end
                    if ((e.silenced or 0) > 0) and js.random() < (0.3) then local x = e.x + rand(-4, 4); FX.parts:push({ x = x, y = e.y - 14, vx = 0, vy = -6, g = 0, life = 0.4, max = 0.4, color = '#8f7bc4', size = 1 }) end
                    if (e.chill) and js.random() < (0.15 + (e.chill and e.chill.n or 0) * 0.1) then local x, y = e.x + rand(-5, 5), e.y + rand(-7, 3); FX.parts:push({ x = x, y = y, vx = 0, vy = 5, g = 0, life = 0.4, max = 0.4, color = '#bfe8ff', size = 1 }) end
                    if ((e.shellT or 0) > 0) and js.random() < (0.6) then local an = js.random() * 6.28; FX.parts:push({ x = e.x + cos(an) * 10, y = e.y - 5 + sin(an) * 10, vx = 0, vy = -4, g = 0, life = 0.3, max = 0.3, color = '#ffffff', size = 1 }) end
                    if e.tombT then pixText(actx, S(ceil(e.tombT)), e.x, e.y - 22, '#bfe8ff') end
                    if e.jailT then pixText(actx, S(ceil(e.jailT)), e.x, e.y - 24, '#bfe8ff') end
                    if (e.vcopy) and js.random() < (0.15) then local x, y = e.x + rand(-5, 5), e.y + rand(-8, 4); FX.parts:push({ x = x, y = y, vx = 0, vy = -8, g = 0, life = 0.5, max = 0.5, color = '#c06bff', size = 1 }) end
                    if (T(e.kills)) and js.random() < (0.04 * (e.kills or 0)) then local x, y = e.x + rand(-5, 5), e.y + rand(-6, 4); FX.parts:push({ x = x, y = y, vx = 0, vy = -12, g = 0, life = 0.4, max = 0.4, color = '#ff4a3a', size = 1 }) end
                end
            until true
        end
        for p in of(B.projs) do if not (p.delay > 0) then drawProj(p) end end
        if drawAnims then drawAnims(1) end -- 技能特效：上层（光柱、刀光、天雷……）
        if B.tint then
            ctx.fillStyle = 'rgba(' .. B.tint.rgb .. ',' .. js.toFixed(0.35 * B.tint.t / B.tint.max, 3) .. ')'
            ctx:fillRect(0, 0, AW, FIELD_H)
        end
    end
    ctx:beginBatch(true) -- 粒子：互不影响，按颜色合批
    for p in of(FX.parts) do
        ctx.globalAlpha = clamp(p.life / p.max * 1.5, 0, 1); ctx.fillStyle = p.color
        ctx:fillRect(round(p.x), round(p.y), p.size, p.size)
    end
    ctx:endBatch()
    ctx.globalAlpha = 1
    for f in of(FX.floats) do ctx.globalAlpha = clamp(f.life / f.max * 2, 0, 1); pixText(ctx, f.text, f.x, f.y, f.color) end
    ctx.globalAlpha = 1
    if drag and drag.moved then
        local u = drag.u
        local img = unitImg(u.cls, u.star, u.branch, false, false)
        local lift = drag.touch and 14 or 4
        ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx:fillRect(round(drag.x - 5), round(drag.y + 6), 10, 2)
        drawQGlow(img, drag.x, drag.y - lift, u.q or 0)
        drawImg(img, drag.x, drag.y - lift)
        drawBadge(drag.x, drag.y - lift - (isSup(u) and 16 or (u.branch and 14 or 12)), u.star, u.branch)
    end
    ctx:restore()
end

-- ---------- 老虎机渲染 ----------
function renderSlot()
    ---@type table<string, any>
    local Sl = G.slot
    local ctx = sctx
    ctx:clear()
    ctx.fillStyle = '#120d22'; ctx:fillRect(0, 0, 72, 72)
    local showing = not Sl.spinning and #Sl.show > 0
    local lit = {}
    Sl.show:forEach(function(l) LINES[l.li]:forEach(function(i) lit[i] = true end) end)
    for c = 0, 2 do
        local x0 = 3 + c * 22
        ctx:save(); ctx:clipRect(x0, 3, 22, 66)
        for r = 0, 2 do
            ctx.fillStyle = '#2a2042'; ctx:fillRect(x0 + 1, 3 + r * 22 + 1, 20, 20)
            ctx.fillStyle = '#342853'; ctx:fillRect(x0 + 1, 3 + r * 22 + 1, 20, 1)
        end
        if Sl.spinning then
            local o, strip = Sl.off[c], Sl.strips[c]
            local fast = not Sl.stopped[c] and Sl.t < Sl.dur[c] - 0.25
            local j0 = max(0, floor(o / 22) - 1)
            for j = j0, min(#strip, j0 + 6) - 1 do
                local y = round(3 + j * 22 - o) + 3
                ctx.globalAlpha = fast and 0.75 or 1
                ctx:drawImage(spr(SYM_SPRITE[strip[j]]), x0 + 3, y)
                if fast then ctx.globalAlpha = 0.25; ctx:drawImage(spr(SYM_SPRITE[strip[j]]), x0 + 3, y - 4) end
                ctx.globalAlpha = 1
            end
        else
            for r = 0, 2 do
                local i = r * 3 + c
                ctx.globalAlpha = (showing and not lit[i]) and 0.35 or 1
                ctx:drawImage(spr(SYM_SPRITE[Sl.grid[i]]), x0 + 3, 3 + r * 22 + 3)
                ctx.globalAlpha = 1
            end
        end
        ctx:restore()
    end
    ctx.fillStyle = 'rgba(0,0,0,0.35)'; ctx:fillRect(3, 3, 66, 3); ctx:fillRect(3, 66, 66, 3)
    for l in of(Sl.show) do
        repeat
            local age = G.time - l.t
            if age < 0.5 and floor(age * 12) % 2 ~= 0 then break end
            local L = LINES[l.li]
            local col = l.col or SYM_COLOR[l.sym]
            local pts = L:map(function(i) return { x = 3 + (i % 3) * 22 + 11, y = 3 + floor(i / 3) * 22 + 11 } end)
            ctx.fillStyle = col
            for i in of(L) do frameRect(ctx, 3 + (i % 3) * 22 + 1, 3 + floor(i / 3) * 22 + 1, 20, 20, col) end
            if age > 1.1 then break end
            local a, b = pts[0], pts[2]
            local steps = max(abs(b.x - a.x), abs(b.y - a.y))
            for k = 0, steps do
                local x, y = round(a.x + (b.x - a.x) * k / steps), round(a.y + (b.y - a.y) * k / steps)
                ctx.fillStyle = PAL.k; ctx:fillRect(x - 1, y - 1, 3, 3)
            end
            ctx.fillStyle = col
            for k = 0, steps do
                local x, y = round(a.x + (b.x - a.x) * k / steps), round(a.y + (b.y - a.y) * k / steps)
                ctx:fillRect(x, y, 1, 1)
            end
        until true
    end
end

-- ---------- 主页画面 ----------
HOME = { bg = nil }
function homeBg()
    local x = PX.newImage(192, 56)
    local s = 7
    local function rnd() s = (s * 16807) % 2147483647; return s / 2147483647 end
    x:fill(0, 0, 192, 56, '#1b1530')
    for i = 0, 191 do local h = 7 + round(4 * sin(i / 9) + 3 * sin(i / 4.3)); x:fill(i, 46 - h, 1, h, '#2a2042') end
    local zones = { { 0, 76, '#44733a', { [0] = '#3b6633', '#5b8f45', '#4f8040' } }, { 76, 134, '#3a2a2e', { [0] = '#33242a', '#45323a', '#4a363c' } }, { 134, 192, '#231e3c', { [0] = '#1f1a36', '#2b2546', '#28223f' } } }
    for _, z in ipairs(zones) do
        local a, b, base, sp = z[1], z[2], z[3], z[4]
        x:fill(a, 46, b - a, 10, base)
        for i = 0, 69 do local c = sp[floor(rnd() * 3)]; local px = a + floor(rnd() * (b - a)); local py = 46 + floor(rnd() * 10); x:fill(px, py, 1, 1, c) end
    end
    for i = 0, 8 do local px = 78 + floor(rnd() * 52); local py = 48 + floor(rnd() * 7); x:fill(px, py, 2, 1, '#e2541f') end
    for i = 0, 5 do
        local px = 138 + floor(rnd() * 50)
        local py = 49 + floor(rnd() * 5)
        x:fill(px - 1, py, 3, 1, '#8f4bc4'); x:fill(px, py - 1, 1, 3, '#8f4bc4')
    end
    x:fill(0, 46, 192, 1, '#1b1530')
    return x
end
function renderHome()
    if not HOME.bg then HOME.bg = homeBg() end
    local x, t = homeCv, G.time
    x:clear()
    x:drawImage(HOME.bg, 0, 0)
    for i = 0, 15 do
        if REDUCED or sin(t * 2 + i * 1.7) > 0.2 then
            x.fillStyle = (i % 4 ~= 0) and '#cfe3ff' or '#ffe27a'; x:fillRect((i * 37 + 11) % 192, (i * 13 + 3) % 26, 1, 1)
        end
    end
    local function put(img, cx, ph)
        local b = REDUCED and 0 or round(sin(t * 3 + ph))
        x:drawImage(img, round(cx - img.width / 2), 48 - img.height + b)
    end
    put(unitImg('warrior', 3, 'titan', false, false), 14, 0)
    put(unitImg('mage', 3, 'archmage', false, false), 31, 1.3)
    put(unitImg('archer', 3, 'starfall', false, false), 48, 2.6)
    local function foe(k, cx, ph) local E = ENEMIES[k]; put(spr(E.sprite, E.pal or nil, false, true, E.pal and k or ''), cx, ph) end
    foe('slime', 66, 0.5); foe('magmaslime', 90, 1.1); foe('colossus', 116, 2); foe('charmer', 148, 0.8); foe('voidlord', 174, 1.7)
    if not REDUCED then
        x.fillStyle = '#ff8a2a'; x:fillRect(80 + (js.trunc(t * 7) % 50), round(44 - math.fmod(t * 12, 30)), 1, 1)
        x.fillStyle = '#c06bff'; x:fillRect(138 + (js.trunc(t * 5) % 50), round(44 - math.fmod(t * 9, 30)), 1, 1)
    end
end

-- ---------- 界面里的像素图标（原版 iconURL 生成 dataURL，这里登记像素图并返回键名） ----------
ICONS = {}
function iconURL(name, over, key)
    local k = 'spr:' .. name .. '|' .. (key or '')
    if not ICONS[k] then ICONS[k] = spr(name, over, false, false, key) end
    return k
end
-- 带品质描边的单位头像（晋升卡片用，和战场上的描边一致）
function qIconURL(cls, star, q)
    local k = 'q|' .. cls .. S(star) .. '|' .. S(q)
    if not ICONS[k] then
        local img = unitSpr(cls, star, false, false)
        local g = glowImg(img, QUAL[q].color)
        local c = PX.newImage(g.width, g.height)
        for i, col in pairs(g.data) do c.data[i] = col end
        for yy = 0, img.height - 1 do for xx = 0, img.width - 1 do
            local col = img.data[yy * img.width + xx]
            if col then c.data[(yy + 1) * c.width + xx + 1] = col end
        end end
        ICONS[k] = c
    end
    return k
end
-- 页面底纹：16×16 的随机砖纹（原版启动时用 Math.random 生成一次）
function buildFloor()
    local x = PX.newImage(16, 16)
    x:fill(0, 0, 16, 16, '#2a2042')
    for i = 0, 17 do local px = floor(js.random() * 16); local py = floor(js.random() * 16); x:fill(px, py, 2, 1, '#251c3b') end
    for i = 0, 7 do local px = floor(js.random() * 16); local py = floor(js.random() * 16); x:fill(px, py, 1, 1, '#30254b') end
    ICONS['floor'] = x
    return 'floor'
end

return true
