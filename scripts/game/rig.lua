-- ============================================================================
-- 动作风格 / 武器骨架 / 弓弦骨架：逻辑层（出箭点、出手特效）和渲染层共用
-- 对应原版 atkStyle / entSprArgs / bowRigOf / rigOf / bowMuzzle / atkTip ...
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T = js.A, js.T
local floor, ceil, max, min, abs, atan, sqrt = math.floor, math.ceil, math.max, math.min, math.abs, math.atan, math.sqrt

BOW_PROJ = js.Set(A('arrow', 'earrow', 'parrow', 'rarrow'))

---@return table<number, any> -- 兼容层 A() 为零起始数组，不是普通 Lua 序列。
function entSprArgs(e) -- [精灵名, 调色板, 缓存键]
    if e.mspr then return A(e.mspr, e.mpal, e.mkey) end
    if e.minion then
        if e.msprite == 'wolf' then return A('wolf', BRPAL.wolf, 'wolf') end
        return A('skeleton', BRPAL.minion, 'minion')
    end
    if e.side == 'e' and not e.vcopy and not T(e.charmed) then
        return A(e.sprite, e.pal, e.pkey or (e.pal and e.type or ''))
    end -- 虚影、倒戈的单位仍用原外观
    if e.branch then return A(BRANCHES[e.branch].sprite or e.branch, BRPAL[e.branch], 'br:' .. e.branch) end
    return A(CLASSES[e.cls].sprite, TIER_PAL[e.cls][e.star], e.cls .. js.S(e.star))
end

function atkStyle(e)
    if e.astyle then return e.astyle end
    local s = nil
    if e.mspr == 'turret' then s = 'recoil'
    elseif e.mspr == 'sprout' then s = 'spit'
    elseif e.msprite == 'wolf' then s = 'claw'
    elseif e.type and ATK_STYLE_EN[e.type] then s = ATK_STYLE_EN[e.type]
    elseif e.branch and ATK_STYLE_BR[e.branch] then s = ATK_STYLE_BR[e.branch]
    elseif e.cls and ATK_STYLE_CLS[e.cls] then s = ATK_STYLE_CLS[e.cls] end
    if not s then
        if e.proj then s = BOW_PROJ:has(e.proj) and 'bow' or 'cast' else s = 'slash' end
    end
    e.astyle = s
    return s
end

-- "行:起-止" 列表 → 像素集合（键为 x*1000+y）
local function parseMask(str)
    local set = {}
    for seg in str:gmatch("%S+") do
        local r, cs = seg:match("^(%d+):(.+)$")
        local a, b = cs:match("^(%d+)%-(%d+)$")
        if not a then a = cs; b = cs end
        r = tonumber(r); a = tonumber(a); b = tonumber(b)
        for c = a, b do set[c * 1000 + r] = true end
    end
    return set
end
maskKey = function(x, y) return x * 1000 + y end

local bowCache = {}
function bowRigOf(name)
    local hit = bowCache[name]
    if hit ~= nil then return hit or nil end
    local R = BOW_RIG[name]
    local out = false
    if R and SPR[name] then
        out = js.assign({}, R, { mask = parseMask(R.m), hmask = parseMask(R.hd) })
    end
    bowCache[name] = out
    return out or nil
end

local rigCache = {}
function rigOf(name)
    local hit = rigCache[name]
    if hit ~= nil then return hit or nil end
    local R = WEAPON_RIG[name]
    local out = false
    if R and SPR[name] then
        local mask = {}
        local far = 0
        for seg in R.m:gmatch("%S+") do
            local r, cs = seg:match("^(%d+):(.+)$")
            local a, b = cs:match("^(%d+)%-(%d+)$")
            if not a then a = cs; b = cs end
            r = tonumber(r); a = tonumber(a); b = tonumber(b)
            for c = a, b do
                mask[c * 1000 + r] = true
                for _, d in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
                    far = max(far, js.hypot(c + d[1] - R.p[0], r + d[2] - R.p[1]))
                end
            end
        end
        local vx, vy = R.t[0] - R.p[0], R.t[1] - R.p[1]
        out = js.assign({}, R, { mask = mask, rad = ceil(far) + 1, base = atan(vy, vx) * 180 / math.pi, len = js.hypot(vx, vy), vx = vx, vy = vy })
    end
    rigCache[name] = out
    return out or nil
end

-- 弓手的箭从弓臂上、搭箭那一行射出，和拉弓动画对得上
function bowMuzzle(e)
    if atkStyle(e) ~= 'bow' then return nil end
    local n = entSprArgs(e)[0]
    local R = bowRigOf(n)
    if not R then return nil end
    local rows = SPR[n]
    local w, h = #rows[0], #rows
    return { x = e.x + e.face * (R.n[0] + 2.5 - w / 2), y = e.y + 8 - h + R.n[1] + 0.5 }
end

function atkTip(e, x, y) -- 法杖顶端 / 弓 / 花心：蓄力光点和出手闪光的位置
    local st, f = atkStyle(e), e.face
    local s = ((e.giant or 0) > 0) and 2 or 1
    if st == 'bloom' or st == 'pulse' then return { x = x, y = y - 4 * s } end
    if st == 'spit' then return { x = x + f * 5 * s, y = y - 3 * s } end
    if st == 'bow' or st == 'recoil' then return { x = x + f * 7 * s, y = y - 1 * s } end
    local b = e.big and 1.5 or 1
    return { x = x + f * 6 * s * b, y = y - 3 * s * b }
end

function atkFxCol(e)
    if e.branch then return BRANCHES[e.branch].aura end
    if e.cls then return CLASS_COLOR[e.cls] end
    if e.side == 'p' or e.minion then return '#cfe3ff' end
    return ATK_EN_COL[e.type] or '#ff9b8c'
end

function projCol(e)
    local c = e.proj and (PROJ_BURST[e.proj] or PROJ_COL[e.proj])
    if c then return c end
    if atkStyle(e) == 'bloom' then return '#ffe14a' end
    return atkFxCol(e)
end

function swingFx(e) -- 普攻出手瞬间的火花、尘土、闪光
    if e.dead or e.atkTx == nil then return end
    local st, f, tx, ty = atkStyle(e), e.face, e.atkTx, e.atkTy
    if st == 'slash' or st == 'thrust' then FX.particle(tx - f * 3, ty - 4, '#ffffff', 3, 45, 40, 0.18)
    elseif st == 'maul' then
        FX.particle(tx, ty + 6, '#b9a07a', e.big and 10 or 5, e.big and 50 or 30, 90, 0.35)
        if e.branch == 'sup_treant' and not REDUCED and FX.R and FX.R.roots then -- 血根古神：根爪抓地处钻出几根血色根须
            FX.R.roots(tx, ty, { n = 3, r = 5, h = 7, col = '#43281a', col2 = '#b3142a', leaf = '#ff3b3b', dur = 0.45, delay = 0.06 })
        end
    elseif st == 'bounce' then FX.particle(tx - f * 4, ty + 3, atkFxCol(e), 4, 30, 110, 0.3)
    elseif st ~= 'claw' then
        local p = atkTip(e, e.x, e.y)
        local plain = st == 'bow' or st == 'recoil'
        FX.particle(p.x, p.y, plain and '#ffffff' or projCol(e), plain and 2 or 5, 30, 0, 0.18)
    end
end

return true
