-- ============================================================================
-- 第六次更新：兵种限定装备（13 个兵种各 1 件）+ 3 件通用新装备
--  * 限定装备只会在本局出征的兵种里出货，只能装给对应兵种（转移、吸收时同样检查）
--  * 每件都有一个招牌效果，触发时有专属特效
-- ============================================================================
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local floor, max, min, atan = math.floor, math.max, math.min, math.atan
local round, clamp, hypot = js.round, js.clamp, js.hypot
local of = js.of

local function lim(cls) return '限定：' .. CLASSES[cls].name end
local NEW = {
    lionhelm = { cls = 'warrior', rar = 2, name = '狮心战盔', icon = 'n_lionhelm', desc = '生命 +20%；释放技能后 4 秒内受到的伤害 -30%', fx = { hp = 0.2, lionhelm = true } },
    cloudbow = { cls = 'archer', rar = 2, name = '穿云长弓', icon = 'n_cloudbow', desc = '攻击 +12%；每第 4 次普攻射出一支贯穿全场的穿云箭（150% 伤害）', fx = { atk = 0.12, cloudbow = true } },
    startome = { cls = 'mage', rar = 2, name = '星辉法典', icon = 'n_startome', desc = '技能能量获取 +20%；释放技能时额外落下一颗星陨（150% 范围伤害）', fx = { charge = 0.2, startome = true } },
    kingclaw = { cls = 'tiger', rar = 2, name = '猎王爪套', icon = 'n_kingclaw', desc = '暴击率 +12%；击杀敌人后 2 秒内攻速翻倍并回复 6% 生命', fx = { crit = 0.12, kingclaw = true } },
    beartotem = { cls = 'bear', rar = 2, name = '熊王图腾', icon = 'n_beartotem', desc = '生命 +25%；生命低于 40% 时立刻获得 30% 最大生命的护盾（每场一次）', fx = { hp = 0.25, beartotem = true } },
    rotseed = { cls = 'flytrap', rar = 2, name = '腐根之种', icon = 'n_rotseed', desc = '攻击 +10%；普攻给目标叠 1 层剧毒', fx = { atk = 0.1, rotseed = true } },
    dawncrown = { cls = 'sunflower', rar = 2, name = '晨曦花冠', icon = 'n_dawncrown', desc = '技能能量获取 +15%；释放技能后为全队解除负面状态', fx = { charge = 0.15, dawncrown = true } },
    ancientcore = { cls = 'treant', rar = 2, name = '千年树心', icon = 'n_ancientcore', desc = '生命 +20%，受到的伤害 -8%，每秒回复 2% 最大生命', fx = { hp = 0.2, dr = 0.08, regen = 0.02 } },
    stormplume = { cls = 'hawk', rar = 2, name = '雷羽之冠', icon = 'n_stormplume', desc = '闪避 +10%；每次闪避都对攻击者劈下一道闪电（80% 伤害）', fx = { dodge = 0.1, stormplume = true } },
    perpetual = { cls = 'clockwork', rar = 2, name = '永动核心', icon = 'n_perpetual', desc = '攻速 +10%；「过载」持续时间 +2 秒，结束后不再眩晕', fx = { spd = 0.1, perpetual = true } },
    goldharp = { cls = 'bard', rar = 2, name = '金弦竖琴', icon = 'n_goldharp', desc = '攻击 +10%；释放技能时全队回复 6% 最大生命，身上的增益延长 2 秒', fx = { atk = 0.1, goldharp = true } },
    dragoncrystal = { cls = 'whelp', rar = 2, name = '龙晶之心', icon = 'n_dragoncrystal', desc = '攻击 +10%；普攻附带灼烧；对灼烧中的敌人伤害 +15%', fx = { atk = 0.1, burn = true, dragoncrystal = true } },
    permafrost = { cls = 'frostling', rar = 2, name = '永冻冰晶', icon = 'n_permafrost', desc = '普攻减速 30%；对被减速或冻结的敌人伤害 +20%', fx = { slowHit = 0.3, permafrost = true } },
    -- 通用
    windboots = { rar = 0, name = '风行靴', icon = 'n_windboots', desc = '移动速度 +20%，闪避 +5%', fx = { move = 0.2, dodge = 0.05 } },
    hearthcharm = { rar = 1, name = '暖炉护符', icon = 'n_hearthcharm', desc = '被冻结 / 眩晕的时间 -40%，不会叠寒意', fx = { hearth = true } },
    signet = { rar = 3, name = '王者徽戒', icon = 'n_signet', desc = '攻击 +15%，暴击率 +10%，技能能量获取 +15%', fx = { atk = 0.15, crit = 0.1, charge = 0.15 } },
}
local ORDER = { 'windboots', 'hearthcharm', 'signet', 'lionhelm', 'cloudbow', 'startome', 'kingclaw', 'beartotem', 'rotseed', 'dawncrown', 'ancientcore', 'stormplume', 'perpetual', 'goldharp', 'dragoncrystal', 'permafrost' }
local at = ITEM_KEYS:indexOf('dragonheart') + 1
for i, k in ipairs(ORDER) do
    local v = NEW[k]
    v.kind = 'equip'; v.pal = ICON_PAL
    if v.cls then v.limit = lim(v.cls) end
    ITEMS[k] = v
    ITEM_KEYS:splice(at + i - 1, 0, k)
end
local FLAGS = { 'lionhelm', 'cloudbow', 'startome', 'kingclaw', 'beartotem', 'rotseed', 'dawncrown', 'stormplume', 'perpetual', 'goldharp', 'dragoncrystal', 'permafrost', 'hearth' }

-- 商店 / 战利品：只出本局出征兵种的限定装备
local _rollItem = rollItem
function rollItem(kind, odds, exclude)
    if kind == 'equip' and G and G.squad then
        for _, k in ipairs(ORDER) do
            local c = ITEMS[k].cls
            if c and not G.squad:includes(c) then exclude[k] = true end
        end
    end
    return _rollItem(kind, odds, exclude)
end

-- 开战：把装备的招牌效果挂到实体上
addHook('pent', function(ent, u)
    for _, eq in ipairs(equipsOf(u)) do
        local f = ITEMS[eq.id].fx or {}
        for _, k in ipairs(FLAGS) do if f[k] then ent['eq_' .. k] = true end end
    end
end)

local function procFx(e, col, col2, label)
    if FX.equipProc then FX.equipProc(e, col, col2, label) else FX.ring(e.x, e.y, 10, col) end
end

-- 释放技能后
local _castSkill = castSkill
function castSkill(B, e, t)
    _castSkill(B, e, t)
    if e.side ~= 'p' or e.dead then return end
    if e.eq_lionhelm then addBuff(e, 4, { dr = 0.3 }); procFx(e, '#ffe680', '#ff8e6a', '狮心') end
    if e.eq_startome and t then
        local tx = clamp(t.x + rand(-6, 6), 6, AW - 6)
        shoot(B, e, nil, 'starfallx', { x = tx + 30, y = -8, tx = tx, ty = t.y - 3, speed = 170, area = true, splash = 20, mul = 1.5 })
        procFx(e, '#ffe680', '#78a8f2', '星陨')
    end
    if e.eq_dawncrown then
        for o in of(alliesOf(B, e)) do
            if o.stun > 0 or o.poison or o.burn or o.bleed or o.curse or o.slow or (o.wither or 0) > 0 or (o.root or 0) > 0 then cleanse(o, true) end
        end
        procFx(e, '#fff6b0', '#ffffff', '晨曦')
    end
    if e.eq_goldharp then
        for o in of(alliesOf(B, e)) do
            healAmt(o, o.maxHp * 0.06)
            for _, f in ipairs({ 'bAtk', 'bSpd', 'bDr', 'bLeech' }) do if o[f] then o[f].t = o[f].t + 2 end end
        end
        procFx(e, '#ffe680', '#ff8ac8', '金弦')
    end
end
-- 永动核心：过载更久且不眩晕
local _overload = EXT_SKILLS and EXT_SKILLS.overload
if _overload then
    EXT_SKILLS.overload = function(B, e, t)
        _overload(B, e, t)
        if e.eq_perpetual then
            e.overSelf = false
            for o in of(alliesOf(B, e)) do if (o.overT or 0) > 0 then o.overT = o.overT + 2 end end
            procFx(e, '#e2b33c', '#ffe27a', '永动')
        end
    end
end

-- 普攻：近战在出手时结算，远程在命中时结算
local function onBasic(B, e, t)
    if t.dead then return end
    if e.eq_rotseed then addPoison(t, e, 1) end
end
local _attack = attack
function attack(B, e, t)
    if e.eq_cloudbow and e.proj then
        e.cbN = (e.cbN or 0) + 1
        if e.cbN % 4 == 0 then
            local dx, dy = t.x - e.x, (t.y - 3) - (e.y - 3)
            local d = hypot(dx, dy); if d == 0 then d = 1 end
            shoot(B, e, nil, 'cloudarrow', { pierce = true, vx = dx / d, vy = dy / d, ang = atan(dy, dx), speed = 300, mul = 1.5, hitSet = js.Set() })
            procFx(e, '#e4f2ff', '#ffffff', nil)
            return
        end
    end
    _attack(B, e, t)
    if not e.proj then onBasic(B, e, t) end
end
local _procHit = procHit
function procHit(p, o)
    _procHit(p, o)
    if p.basic and p.src and p.src.side == 'p' then onBasic(G.battle, p.src, o) end
end

-- 伤害修正：龙晶之心、永冻冰晶；雷羽之冠的闪避反击
local CUR_SRC = nil
local _hit = hit
function hit(src, t, base, o)
    if src and not (o and T(o.dot)) then
        if src.eq_dragoncrystal and t.burn then base = base * 1.15 end
        if src.eq_permafrost and (t.slow or t.stun > 0) then base = base * 1.2 end
    end
    local prev = CUR_SRC
    CUR_SRC = src
    local r = _hit(src, t, base, o)
    CUR_SRC = prev
    return r
end
local _miss = FX.miss
function FX.miss(t)
    _miss(t)
    local src = CUR_SRC
    if t.eq_stormplume and src and not src.dead and src ~= t and src.side ~= t.side and not t.dead then
        local B = G.battle
        if B then
            _hit(t, src, t.atk * 0.8, { noLeech = true, noCrit = true, reflect = true })
            FX.bolt(src.x, 0, src.x, src.y - 3)
            if FX.P then FX.P.star(src.x, src.y - 4, '#ffe14a', '#ffffff', 6, 0.25) end
        end
    end
end

-- 击杀：猎王爪套
addHook('death', function(t, src, B)
    if src and src.eq_kingclaw and not src.dead and src.side ~= t.side then
        src.haste = max(src.haste or 0, 2); healAmt(src, src.maxHp * 0.06)
        procFx(src, '#ff8a2a', '#ffe680', '猎王')
    end
end)

-- 每帧：熊王图腾、暖炉护符
addHook('step', function(B, dt, alive)
    for e in of(alive) do
        if e.eq_beartotem and not e.totemUsed and e.hp < e.maxHp * 0.4 then
            e.totemUsed = true; e.shield = min(e.maxHp, (e.shield or 0) + e.maxHp * 0.3)
            procFx(e, '#c08a5a', '#ffd27a', '熊王')
        end
        if e.eq_hearth then
            if e.stun > 0 and not B.over then e.stun = max(0, e.stun - dt * 0.667) end
            e.frostStack = nil
        end
    end
end)

-- 穿云箭、星陨的画法
PROJ_DRAW.cloudarrow = function(p, c, s)
    for i = 0, 12 do
        actx.fillStyle = (i == 0) and '#ffffff' or ((i < 4) and '#e4f2ff' or ((i % 2 == 0) and '#9fdcff' or '#ffffff'))
        actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1)
    end
    if js.random() < 0.6 then FX.parts:push({ x = p.x - c * rand(4, 12), y = p.y + rand(-2, 2), vx = 0, vy = rand(-4, 4), g = 0, life = 0.35, max = 0.35, color = '#ffffff', size = 1 }) end
end
PROJ_DRAW.starfallx = function(p, c, s)
    for i = 0, 7 do
        actx.fillStyle = (i == 0) and '#ffffff' or ((i < 3) and '#ffe680' or '#78a8f2')
        actx:fillRect(round(p.x - c * i), round(p.y - s * i), 1, 1)
    end
    local x, y = round(p.x), round(p.y)
    actx.fillStyle = '#ffffff'; actx:fillRect(x - 1, y, 3, 1); actx:fillRect(x, y - 1, 1, 3)
end
PROJ_BURST.cloudarrow = '#e4f2ff'; PROJ_BURST.starfallx = '#ffe680'

return true
