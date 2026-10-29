-- ============================================================================
-- 特效（逻辑层通过 FX 调用）与音效节流（逐行移植自原版）
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S = js.A, js.T, js.S
local round, clamp, hypot = js.round, js.clamp, js.hypot
local floor, ceil, max, min, abs, sin, cos, sqrt = math.floor, math.ceil, js.max, math.min, math.abs, math.sin, math.cos, math.sqrt
local PI = math.pi
local of = js.of

-- ---------------------------------------------------------------------------
-- 音效：新版 Ogg 由入口加载，合并提示保留原 wav；节流和恢复入口保持不变。
-- ---------------------------------------------------------------------------
Sound = {
    on = true, lastHit = 0, lastTick = 0, lastSkill = 0, lastZap = 0,
    backend = nil, -- 由 main.lua 注入：backend(name)
    now = function() return 0 end, -- 毫秒时钟（performance.now）
}
Sound.lastAny = {}
Sound.GAP = { die = 70, q1 = 120, q2 = 120, q3 = 150, q4 = 200, star = 90, summon = 60, absorb = 70, drop = 50, deny = 120, item = 100, buy = 80, sell = 80, refresh = 80, awaken = 200,
    lock = 80, unlockslot = 80, purchase = 90, equip = 90, unequip = 80, exchange = 120 }
-- 原版在第一次用户操作时才创建 AudioContext，之前不会发声
Sound.ready = false
function Sound.init()
    Sound.ready = true
    -- 首次用户操作时就确保混音器已启动（对齐浏览器「用户手势后才能出声」的语义）。
    -- 只置 ready 而不启动输出的话，SoundSource 会显示正在播放却完全没有声音。
    if Sound.on and not audio:IsPlaying() then pcall(audio.Play, audio) end
    if Sound.resumeBackend then Sound.resumeBackend() end
end
function Sound.play(n)
    if not Sound.on or not Sound.ready then return end
    local now = Sound.now()
    if n == 'tick' then if now - Sound.lastTick < 35 then return end Sound.lastTick = now
    elseif n == 'hit' then if now - Sound.lastHit < 45 then return end Sound.lastHit = now
    elseif n == 'shoot' then if now - Sound.lastHit < 30 then return end
    elseif n == 'skill' then if now - Sound.lastSkill < 80 then return end Sound.lastSkill = now
    elseif n == 'zap' then if now - Sound.lastZap < 60 then return end Sound.lastZap = now
    elseif n == 'ult' then if now - Sound.lastSkill < 80 then return end Sound.lastSkill = now
    else
        -- 其他音效也做节流：同一个音效 60~120 毫秒内只放一次，避免一大串同时叠加造成爆音
        local gap = Sound.GAP[n] or 50
        local last = Sound.lastAny[n] or -1e9
        if now - last < gap then return end
        Sound.lastAny[n] = now
    end
    if Sound.backend then Sound.backend(n) end
end

-- ---------------------------------------------------------------------------
-- 特效
-- ---------------------------------------------------------------------------
FX = { parts = A(), floats = A() }
function FX.reset() FX.parts = A(); FX.floats = A() end
function FX.sound(n) Sound.play(n) end
function FX.particle(x, y, color, n, spd, g, life)
    for i = 0, n - 1 do
        local a = js.random() * PI * 2
        local s = rand(spd * 0.3, spd)
        local lf = rand(life * 0.6, life)
        local size = (js.random() < 0.3) and 2 or 1
        FX.parts:push({ x = x, y = y, vx = cos(a) * s, vy = sin(a) * s - spd * 0.3, g = (g == nil) and 120 or g,
            life = lf, max = life, color = color, size = size })
    end
end
function FX.burst(x, y, color, n) FX.particle(x, y, color, n, 50, 80, 0.45) end
function FX.float(x, y, text, color) FX.floats:push({ x = x, y = y, text = text, color = color, life = 0.85, max = 0.85 }) end
function FX.damage(t, dmg, crit, shielded, dot)
    local col
    if dot == 'poison' then col = '#9be36b'
    elseif T(dot) then col = '#ffa04a'
    elseif shielded then col = '#9fdcff'
    elseif crit then col = '#ffd84a'
    else col = (t.side == 'p') and '#ff7a6a' or '#ffffff' end
    FX.float(t.x + rand(-3, 3), t.y - 12, S(dmg) .. (crit and '!' or ''), col)
    if T(dot) then return end
    FX.particle(t.x, t.y - 2, (t.side == 'p') and '#ff7a6a' or '#f1e3c2', 2, 40, 100, 0.3)
    Sound.play('hit')
end
function FX.heal(t, amt) FX.float(t.x + rand(-3, 3), t.y - 14, '+' .. S(round(amt)), '#8fe07a') end
function FX.miss(t) FX.float(t.x, t.y - 12, 'MISS', '#cfe3ff') end
function FX.undying(t)
    FX.particle(t.x, t.y, '#6ef0ff', 30, 80, 20, 0.9); FX.ring(t.x, t.y, 14, '#ffffff')
    FX.skill(t, '战魂不灭'); G.shake = max(G.shake, 0.3); Sound.play('star')
end
function FX.ring(x, y, r, color)
    for i = 0, 17 do
        local a = i / 18 * PI * 2
        FX.parts:push({ x = x + cos(a) * r * 0.4, y = y + sin(a) * r * 0.3, vx = cos(a) * r * 1.6, vy = sin(a) * r * 1.1,
            g = 0, life = 0.4, max = 0.4, color = color, size = 1 })
    end
end
function FX.trail(x1, y1, x2, y2, color)
    local n = max(4, round(hypot(x2 - x1, y2 - y1) / 3))
    for i = 0, n do
        local k = i / n
        local arc = sin(k * PI) * 14
        local vx = rand(-6, 6)
        local vy = rand(-6, 6)
        FX.parts:push({ x = x1 + (x2 - x1) * k, y = y1 + (y2 - y1) * k - arc, vx = vx, vy = vy, g = 0,
            life = 0.15 + k * 0.3, max = 0.45, color = (i % 3 ~= 0) and color or '#ffffff', size = 1 })
    end
end
function FX.slash(x, y)
    for i = -8, 8 do
        FX.parts:push({ x = x + i, y = y - 4 - i * 0.7, vx = 0, vy = 0, g = 0, life = 0.28, max = 0.28,
            color = (abs(i) < 5) and '#ffffff' or '#cfe3ff', size = 1 })
    end
    FX.burst(x, y - 4, '#ffffff', 6)
end
function FX.bolt(x1, y1, x2, y2)
    local n = max(2, round(hypot(x2 - x1, y2 - y1) / 6))
    local px, py = x1, y1
    for i = 1, n do
        local k = i / n
        local j = (i < n) and 3 or 0
        local qx = x1 + (x2 - x1) * k + rand(-j, j)
        local qy = y1 + (y2 - y1) * k + rand(-j, j)
        local m = max(1, ceil(max(abs(qx - px), abs(qy - py))))
        for t = 0, m do
            FX.parts:push({ x = px + (qx - px) * t / m, y = py + (qy - py) * t / m, vx = 0, vy = 0, g = 0,
                life = 0.22, max = 0.22, color = (js.random() < 0.35) and '#ffffff' or '#ffe14a', size = 1 })
        end
        px = qx; py = qy
    end
    FX.burst(x2, y2, '#ffe14a', 4)
end
function FX.impact(p)
    if p.kind == 'frostbig' then FX.ring(p.tx, p.ty + 3, 24, '#bff4ff'); FX.particle(p.tx, p.ty, '#ffffff', 18, 70, 30, 0.6); FX.particle(p.tx, p.ty, '#7fd0ff', 14, 50, 20, 0.7); G.shake = max(G.shake, 0.15)
    elseif p.kind == 'meteor' then FX.particle(p.tx, p.ty, '#ff8a2a', 30, 90, 60, 0.6); FX.particle(p.tx, p.ty, '#ffe14a', 14, 60, 40, 0.5); G.shake = max(G.shake, 0.2)
    elseif p.kind == 'arcane' then FX.ring(p.tx, p.ty + 3, 20, '#6ef0ff'); FX.burst(p.tx, p.ty, '#ffffff', 6)
    elseif p.kind == 'lavaball' then FX.ring(p.tx, p.ty + 3, 14, '#ff8a2a'); FX.particle(p.tx, p.ty, '#ff5a2a', 16, 50, 40, 0.6)
    elseif p.kind == 'parrow' then FX.ring(p.tx, p.ty + 3, 18, '#9be36b'); FX.particle(p.tx, p.ty, '#4fbf4a', 16, 40, -10, 0.8)
    else FX.burst(p.tx, p.ty, '#e8d2a8', 4) end
end
function FX.superSummon(u, s) -- 超凡降世：血色光柱、冲击环、全场红闪
    local p = slotPos(s)
    for i = 0, 45 do
        local x = p.x + rand(-5, 5)
        local y = p.y + 8 - rand(0, 70)
        local vx = rand(-3, 3)
        local vy = -rand(20, 70)
        local life = rand(0.4, 1)
        local color = pick(A('#ff3434', '#ff8e6a', '#fff2ea', '#a8102a'))
        local size = (js.random() < 0.3) and 2 or 1
        FX.parts:push({ x = x, y = y, vx = vx, vy = vy, g = 0, life = life, max = 1, color = color, size = size })
    end
    FX.ring(p.x, p.y, 30, '#ff3434'); FX.ring(p.x, p.y, 16, '#fff2ea')
    FX.particle(p.x, p.y, '#ff3434', 50, 110, 30, 1.0)
    u.pop = 0.5; G.shake = max(G.shake, 0.6)
    UI.supFlash(p.x, p.y)
    Sound.play('q4')
end
function FX.crescent(x, y, f, R) -- 血月斩：向前推进的血色月牙，中间厚、两端尖
    local cols = { [0] = '#ff3434', '#fff2ea', '#ff8e6a', '#ff3434', '#a8102a' }
    for i = 0, 56 do
        local a = -1.35 + 2.7 * i / 56
        local c, sn = cos(a), sin(a)
        local n = 2 + round(3 * (1 - abs(a) / 1.35))
        for j = 0, n - 1 do
            FX.parts:push({ x = x + f * c * (R - j) * 0.55, y = y + sn * (R - j) * 0.85, vx = f * 140, vy = sn * 10, g = 0,
                life = 0.3, max = 0.3, color = (n < 3 and j == 0) and '#a8102a' or cols[j], size = 1 })
        end
    end
end
function FX.thorns(x, y) -- 血棘：从脚下穿出的荆棘
    for j = -2, 2 do
        for i = 0, 7 - abs(j) * 2 - 1 do
            local col
            if i >= 5 - abs(j) * 2 then col = '#ff8e6a' elseif i % 2 ~= 0 then col = '#a8102a' else col = '#4c1b2f' end
            FX.parts:push({ x = x + j * 3, y = y + 7 - i * 2, vx = 0, vy = -24, g = 60, life = 0.32 + i * 0.03, max = 0.5, color = col, size = 1 })
        end
    end
    FX.burst(x, y - 2, '#ff3434', 5)
end
function FX.quake(x, y) -- 末日践踏：放射状的地裂
    for k = 0, 7 do
        local a = k / 8 * PI * 2 + rand(-0.2, 0.2)
        local i = 4
        while i < 26 do
            FX.parts:push({ x = x + cos(a) * i, y = y + 6 + sin(a) * i * 0.55, vx = 0, vy = 0, g = 0,
                life = 0.5 - i * 0.008, max = 0.5, color = (i % 4 ~= 0) and '#ff3434' or '#ff8e6a', size = 1 })
            i = i + 2
        end
    end
end
function FX.skill(e, name)
    Sound.play(e.sup and 'ult' or 'skill')
    UI.skillPop(e, name)
end
function FX.awaken(u)
    local s = findSlot(u)
    if not s then return end
    local p, B = slotPos(s), BRANCHES[u.branch]
    FX.particle(p.x, p.y, B.aura, 40, 90, 30, 1.0)
    FX.particle(p.x, p.y, '#ffffff', 16, 60, 20, 0.7)
    u.pop = 0.35; G.shake = 0.4
    Sound.play('awaken')
    UI.banner((T(u.q) and QUAL[u.q].name or '') .. B.name .. ' 转职完成', T(u.q) and ('q' .. S(u.q)) or 'gold')
end
function FX.promote(u)
    local s = findSlot(u)
    if not s then return end
    local p, q = slotPos(s), u.q or 0
    local col = QUAL[q].color
    FX.ring(p.x, p.y, 10 + q * 4, col)
    FX.particle(p.x, p.y, col, 28 + q * 8, 85, -30, 1.0)
    FX.particle(p.x, p.y, '#ffffff', 12 + q * 4, 60, 20, 0.7)
    FX.float(p.x, p.y - 14, '^', col)
    u.pop = 0.35; G.shake = max(G.shake, 0.3)
    Sound.play('q' .. S(q))
    UI.banner('晋升为' .. QUAL[q].name .. CLASSES[u.cls].name .. starStr(1), 'q' .. S(q))
end
local DEATH_COL = { slime = '#7bd36a', orc = '#7bd36a', orcwar = '#e86a4a', lichpriest = '#9be36b', magmaslime = '#ff8a2a', magmalet = '#ff8a2a', bomber = '#ffb03a',
    obsidian = '#9a6ad8', ashblade = '#8a8590', pyromancer = '#ff5a2a', forgepriest = '#ffb04a', pillar = '#ff8a2a', colossus = '#ff8a2a',
    voidleech = '#7fe0e8', mirrorguard = '#d6e2f2', hooker = '#8f4bc4', charmer = '#ff6ad5', phaser = '#6ef0ff', cultist = '#9be36b', voidlord = '#c06bff', voidmirror = '#c06bff' }
function FX.death(t)
    local col = (t.side == 'p') and '#8fb8ff' or (DEATH_COL[t.type] or '#e9e2cf')
    FX.particle(t.x, t.y, col, t.big and 40 or 14, t.big and 90 or 60, 140, 0.7)
    if t.big then G.shake = 0.5 end
    Sound.play('die')
end
function FX.summon(u, s)
    local p, q = slotPos(s), u.q or 0
    FX.particle(p.x, p.y, CLASS_COLOR[u.cls], 14, 55, 60, 0.6)
    if T(q) then
        FX.ring(p.x, p.y, 8 + q * 4, QUAL[q].color)
        FX.particle(p.x, p.y, QUAL[q].color, 10 + q * 10, 50 + q * 15, 30, 0.8)
        if q >= 2 then FX.particle(p.x, p.y, '#ffffff', q * 6, 60, 20, 0.6) end
        if q >= 3 then G.shake = max(G.shake, 0.4) end
    end
    Sound.play(T(q) and ('q' .. S(q)) or 'summon')
end
function FX.absorb(src, dst, fromPos, gain, up, ready)
    local ds = findSlot(dst)
    if not ds then return end
    local p = slotPos(ds)
    -- 被吞噬的单位先响一声，避免直接消失没有任何反馈
    Sound.play('merge')
    if fromPos then
        for i = 0, 9 do
            local k = i / 10
            FX.parts:push({ x = fromPos.x + (p.x - fromPos.x) * k, y = fromPos.y + (p.y - fromPos.y) * k - 4, vx = 0, vy = -10,
                g = 0, life = 0.2 + k * 0.4, max = 0.6, color = '#ffe680', size = 1 })
        end
    end
    dst.pop = max(dst.pop or 0, 0.25)
    FX.float(p.x, p.y - 14, '+' .. S(gain), '#8fe07a')
    if ready then
        FX.particle(p.x, p.y, '#ffd84a', 26, 80, 40, 0.9)
        FX.particle(p.x, p.y, '#ffffff', 20, 70, 30, 0.8)
        Sound.play('star'); G.shake = 0.35
        UI.banner((T(dst.q) and QUAL[dst.q].name or '') .. CLASSES[dst.cls].name .. '★★★ ' .. (canPromote(dst) and '转职或晋升' or '可以转职'), 'gold')
    elseif up then
        FX.particle(p.x, p.y, '#ffd84a', 26, 80, 40, 0.9)
        FX.particle(p.x, p.y, '#ffffff', 10, 60, 30, 0.6)
        Sound.play('star')
        if dst.star == 3 then G.shake = 0.35 end
        UI.banner((T(dst.q) and QUAL[dst.q].name or '') .. CLASSES[dst.cls].name .. ' 升到 ' .. starStr(dst.star), 'gold')
    else Sound.play('absorb') end
end
function FX.battleOver(res) Sound.play((res == 'win') and 'victory' or 'defeat') end
-- 粒子上限：大招叠在一起时粒子能到上千个，手机上每个粒子都是一次绘制。超出时丢掉最老的
FX.MAX_PARTS, FX.MAX_FLOATS = 600, 40
--- 原地更新并压缩数组（不再每帧新建数组，减少垃圾回收造成的卡顿）
local function compact(arr, cap, step)
    local n, w = arr.n, 0
    local skip = n - cap
    for i = 0, n - 1 do
        local p = arr[i]
        step(p)
        if p.life > 0 and i >= skip then arr[w] = p; w = w + 1 end
    end
    for i = w, n - 1 do arr[i] = nil end
    arr.n = w
end
local function stepPart(p, dt) end
function FX.update(dt)
    compact(FX.parts, FX.MAX_PARTS, function(p) p.vy = p.vy + p.g * dt; p.x = p.x + p.vx * dt; p.y = p.y + p.vy * dt; p.life = p.life - dt end)
    compact(FX.floats, FX.MAX_FLOATS, function(f) f.life = f.life - dt; f.y = f.y - 16 * dt end)
    if FX.updateAnims then FX.updateAnims(dt) end
end

return true
