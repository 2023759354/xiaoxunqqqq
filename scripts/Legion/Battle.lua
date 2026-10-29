-- 拉杆军团：从原 HTML 战斗逻辑移植，纯 Lua 状态模拟，不创建引擎物理对象。
-- 生命周期/更新分离沿用 scaffold-2d.lua；渲染、暂停、倍速、经济结算由主模块负责。
-- 坐标是原画布的逻辑像素（256 x 142），不是 UrhoX 物理世界的米。
-- 碰撞/命中设计（先设计后实现）
--     x=6 +--------------------------------------------+ x=250
--         |  A(rA) -- d -- B(rB)                       |
--         |  圆形分离: d < rA+rB+1，双向软推开         |
--         |  攻击范围: d <= range+rA+rB                |
--         |  箭路径: [上帧位置]==========>[本帧位置]   |
--         |          点到线段 <= r目标+3 命中一次      |
--         |  地裂: 线段半宽w+目标r；地面池:扁椭圆     |
--  y=14   +--------------------------------------------+ y=132
-- 目的：同阵营与异阵营单位都不叠成一点；远程单位能接近射程并完成攻击。
-- 边界：相切不额外推；同心圆用稳定方向；尸体不碰撞；锚定/首领少推。
-- 移动步长不越过射程边界，贴边后重新寻敌；穿透箭用线段检测避免漏击。
-- 黑洞/跃击后再次夹紧边界；无敌敌人低优先，全部无敌时仍追击而非卡死。
-- 上限：100 实体（保留可复活友军，及时清理其他尸体）、32 场、384 弹、240 事件。

---@type LegionData
local Data = require('Legion.Data')
---@class LegionBattle
---@field game table
---@field entities table[]
---@field projectiles table[]
---@field fields table[]
---@field effects table[]
---@field result string|nil
---@field elapsed number
---@field over boolean
---@field accumulator number
---@field aura number
---@field chapter table
---@field difficulty table
---@field wave number
---@field logs table
local Battle = {}
Battle.__index = Battle
local W, H, STEP = 256, 142, 1 / 60
local MAX_ENT, MAX_FIELD, MAX_PROJ, MAX_FX = 100, 32, 384, 240
local SLOW_PROJ = {orb=true, dark=true, arcane=true, frost=true, frostbig=true,
    holy=true, prism=true, fireball=true, lavaball=true, bloodorb=true, sunfire=true}
local PROJ_COLOR = {orb='#6ef0ff', dark='#c06bff', frost='#bff4ff', frostbig='#bff4ff',
    spark='#ffe14a', holy='#fff3b0', prism='#ffffff', fireball='#ff8a2a', lavaball='#ff8a2a',
    bloodorb='#ff3434', sunfire='#ff8e6a', bloodstar='#ff3434', bloodpierce='#ff3434',
    parrow='#9be36b', star='#ffe680', meteor='#ff8a2a', arrow='#e6edf7', earrow='#d8d2c4'}

---@param v number
---@param lo number
---@param hi number
---@return number
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
---@param n number
---@return number
local function round(n) return math.floor(n + 0.5) end
---@param x number
---@param y number
---@return number
local function hypot(x, y) return math.sqrt(x * x + y * y) end
---@param a table
---@param b table
---@return number
local function dist(a, b) return hypot(a.x - b.x, a.y - b.y) end
---@param lo number
---@param hi number
---@return number
local function rand(lo, hi) return lo + math.random() * (hi - lo) end
---@param dst table
---@param src table|nil
---@return table
local function assign(dst, src)
    for k, v in pairs(src or {}) do dst[k] = v end
    return dst
end
---@param list table[]
---@param less fun(a: table,b: table):boolean
---@return table|nil
local function firstSorted(list, less) table.sort(list, less); return list[1] end
---@param px number
---@param py number
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
local function segDist(px, py, x1, y1, x2, y2)
    local vx, vy = x2 - x1, y2 - y1
    local len = math.max(0.0001, vx * vx + vy * vy)
    local k = clamp(((px - x1) * vx + (py - y1) * vy) / len, 0, 1)
    return hypot(px - x1 - vx * k, py - y1 - vy * k)
end
---@param e table
local function bound(e)
    e.x = clamp(e.x, 6, W - 6)
    e.y = clamp(e.y, e.big and 22 or 14, H - 10)
end
---@param side number
---@param o table
---@return table
local function makeEnt(side, o)
    local e = assign({side=side, originalSide=side, x=0, y=72, hp=o.maxHp or 1,
        maxHp=1, atk=1, cd=1, cdLeft=0.15 + math.random() * (o.cd or 1) * 0.6,
        range=8, speed=20, r=5, crit=0.05, critMul=2, leech=0, splash=0,
        flash=0, attackAnim=0, atkT=9, atkBig=false, atkFx=false, ready=false,
        knock=0, knockDir=0, dead=false, deadT=0, face=side == 1 and 1 or -1,
        moving=false, phase=math.random() * 6, energy=o.skill and (side == 2 and 40 or math.random(0,29)) or 0,
        stun=0, shield=0, dr=0, haste=0, inv=0, giant=0, cast=0, charmed=0,
        q=1, star=1, cls='', sprite='', type='', branch=false, kills=0, elemIdx=0, rage=0, adds=0}, o)
    e.hp = e.maxHp
    e.baseAtk, e.baseCd, e.baseR, e.baseBig = e.atk, e.cd, e.r, not not e.big
    if e.fullEnergy then e.energy = 100 end
    return e
end
---@param game table
---@return table,table
local function currentConfig(game)
    local g = game.g or game
    local chapters = Data.CHAPTERS or {}
    local ch = chapters[g.ch or 1] or chapters[1] or {}
    local ds = ch.diffs or Data.DIFFS1 or Data.DIFFS or {}
    return ch, ds[g.diff or 1] or ds[1] or {mult=1,waves=10,adds=0}
end
---@param game table
---@param item table
---@param wave number
---@return table
local function enemyEnt(game, item, wave)
    local ch, d = currentConfig(game)
    local defs = Data.ENEMIES or ch.enemies or {}
    local def = defs[item.type] or defs.slime or {hp=48,atk=6,cd=1,range=7,speed=18,r=5,sprite='slime'}
    local wm = Data.WaveMult and Data.WaveMult(wave) or (1 + 0.24 * (math.min(wave,10)-1) + 0.18 * math.max(0,wave-10))
    local dm = Data.DiffMult and Data.DiffMult(d,wave) or (1 + ((d.mult or 1)-1) * (0.5+0.5*(wave-1)/math.max(1,(d.waves or 10)-1)))
    local e = makeEnt(2, {x=item.x or 180, y=item.y or 72, maxHp=round(def.hp*wm*dm*(item.elite and 1.6 or 1)),
        atk=round(def.atk*wm*dm*(item.elite and 1.3 or 1)), cd=def.cd, range=def.range,
        speed=def.speed, r=def.r, proj=def.proj, splash=def.splash or 0, sprite=def.sprite or item.type,
        pal=def.pal, type=item.type, cls=item.type, big=not not def.big, skill=def.skill,
        elite=not not item.elite, adds=d.adds or 0})
    assign(e,def.fx)
    e.rage = e.big and not (e.phases or e.vphases) and (d.adds or 0) or 0
    if e.blink then e.blinkT = rand(1,1.6) end
    if e.hook then e.hookT = rand(1.6,2.1) end
    if e.shift then e.shiftT = rand(2,4) end
    return e
end
---@param game table
---@param u table
---@param index number
---@return table
local function playerEnt(game, u, index)
    local st = game:Stats(u)
    local c = (Data.CLASSES or {})[u.cls] or {}
    local br = (Data.BRANCHES or {})[u.branch or ''] or {}
    local sprite = br.sprite or c.sprite or u.cls
    if not br.sprite and Data.SPR and Data.SPR[u.branch or ''] then sprite = u.branch end
    local e = makeEnt(1, assign(assign({},st), {x=20+((index-1)%4)*28, y=34+math.floor((index-1)/4)*38,
        maxHp=st.hp, cls=u.cls, type=u.cls, sprite=sprite, star=u.star or 1, q=clamp(u.q or 1,1,5),
        branch=u.branch or false, id=u.id, r=st.r or c.r or 5, splash=st.splash or c.splash or 0,
        skill=st.skill or br.skill or (Data.CLASS_SKILL or {})[u.cls], pal=(Data.BRPAL or {})[u.branch or '']}))
    -- 机制开关 fx 必须复制到实体而不是改写属性计算结果或原库存单位。
    assign(e,c.fx); assign(e,br.fx); assign(e,st.fx)
    e.sup, e.tall = not not br.sup, not not br.sup
    e.unitId = u.id
    return e
end

--- 备战预览使用游戏模块已固定的阵容（同波重试与实战精英完全一致）。
---@param game table
---@return table[]
function Battle.Preview(game)
    local g = game.g or game
    local list = game.CurrentLineup and game:CurrentLineup() or (g.lineup and g.lineup.list) or {}
    local out = {}
    for _, item in ipairs(list) do out[#out+1] = enemyEnt(game,item,g.wave or 1) end
    return out
end
---@param game table
---@return LegionBattle
function Battle.New(game)
    local b = setmetatable({},Battle)
    b:Init(game)
    return b
end
---@param game table
function Battle:Init(game)
    self.game, self.entities, self.projectiles, self.fields, self.effects = game, {}, {}, {}, {}
    self.result, self.over, self.elapsed, self.accumulator, self.aura = nil, false, 0, 0, 0
    self.logs = {}
    self.chapter, self.difficulty = currentConfig(game)
    local g = game.g or game
    self.wave = g.wave or 1
    for i=1,12 do
        local u = (g.form or {})[i]
        if type(u) == 'table' then self.entities[#self.entities+1] = playerEnt(game,u,i) end
    end
    for _, e in ipairs(Battle.Preview(game)) do self.entities[#self.entities+1] = e end
    local ps, open = self:Allies({side=1}), 0
    for _, e in ipairs(ps) do open = math.max(open,e.openHaste or 0) end
    for _, e in ipairs(ps) do
        e.haste = math.max(e.haste,open)
        if e.openTurret then self:Summon(e,'turret') end
        if e.openSprout then self:Summon(e,'sprout') end
    end
    print(string.format('[军团战斗] 开始：章节=%d 难度=%d 波次=%d 实体数=%d',g.ch or 1,g.diff or 1,self.wave,#self.entities))
end
---@param src table
---@return table[]
function Battle:Foes(src)
    local out = {}
    for _, e in ipairs(self.entities) do if not e.dead and e.side ~= src.side then out[#out+1] = e end end
    return out
end
---@param src table
---@return table[]
function Battle:Allies(src)
    local out = {}
    for _, e in ipairs(self.entities) do if not e.dead and e.side == src.side then out[#out+1] = e end end
    return out
end
---@param src table
---@return table[]
function Battle:Minions(src)
    local out = {}
    for _, e in ipairs(self.entities) do if not e.dead and e.owner == src then out[#out+1] = e end end
    return out
end
---@param kind string
---@param x number
---@param y number
---@param color string|nil
---@param life number|nil
---@param extra table|nil
function Battle:Effect(kind,x,y,color,life,extra)
    if #self.effects >= MAX_FX then table.remove(self.effects,1) end
    local duration = life or 0.4
    self.effects[#self.effects+1] = assign({kind=kind,x=x,y=y,color=color or '#ffffff',life=duration,maxLife=duration},extra)
end
---@param e table
---@param text string
---@param phase boolean|nil
function Battle:SkillEffect(e,text,phase)
    self:Effect(phase and 'phase' or 'skill',e.x,e.y-16,phase and '#ffb04a' or '#ffe680',0.85,{text=text})
    local key = tostring(e.id or e)..':'..text
    if phase or not self.logs[key] then
        self.logs[key] = true
        print('[军团战斗] '..(phase and '首领阶段：' or '技能：')..(e.branch or e.type or e.cls)..' '..text)
    end
end
---@param src table
---@param n number
function Battle:Energy(src,n)
    if src.skill then src.energy = math.min(100,src.energy+n*(src.chargeMul or 1)) end
end
---@param t table
---@param amount number
---@return number
function Battle:Heal(t,amount)
    if t.dead or amount <= 0 then return 0 end
    local got = math.min(t.maxHp-t.hp,amount)
    t.hp = t.hp+got
    if got >= 1 then self:Effect('heal',t.x,t.y-12,'#8fe07a',0.55,{text='+'..round(got)}) end
    return got
end
---@param src table
---@param amount number
function Battle:HealLowest(src,amount)
    local low = firstSorted(self:Allies(src),function(a,b) return a.hp/a.maxHp < b.hp/b.maxHp end)
    if low then self:Heal(low,amount) end
end
---@param t table
---@param dur number
---@param vuln number
---@param weak number
function Battle:Curse(t,dur,vuln,weak)
    if t.dead then return end
    local c = t.curse or {}
    t.curse = {t=math.max(dur,c.t or 0),vuln=math.max(vuln,c.vuln or 0),weak=math.max(weak,c.weak or 0)}
end
---@param t table
---@param dur number
---@param amt number
function Battle:Slow(t,dur,amt)
    if t.dead then return end
    local s = t.slow or {}
    t.slow = {t=math.max(dur,s.t or 0),amt=math.max(amt,s.amt or 0)}
end
---@param t table
---@param src table
---@param dur number
---@param dps number
---@param kind string
function Battle:Dot(t,src,dur,dps,kind)
    if not t.dead then t[kind] = {t=dur,dps=dps,tick=0.5,src=src} end
end
---@param t table
---@param src table
---@param n number
function Battle:Poison(t,src,n)
    if t.dead or n <= 0 then return end
    local p = t.poison or {n=0,t=0,tick=0.5,src=src,per=0}
    p.n, p.t, p.src, p.per = math.min(8,p.n+n), 4, src, math.max(p.per,src.atk*0.15)
    t.poison = p
end
---@param t table
---@param src table|nil
function Battle:Death(t,src)
    if t.dead then return end
    if t.charmed > 0 then t.side, t.charmed = t.originalSide, 0 end
    t.hp, t.dead, t.deadT, t.moving = 0, true, 0, false
    self:Effect('death',t.x,t.y,'#d8433a',0.55,{r=t.r})
    if t.split and not t.splitDone then
        t.splitDone = true
        for i=1,2 do self:SpawnEnemy(t.split,t.x+rand(-3,3),t.y+(i == 1 and -7 or 7),0.5) end
    end
    if t.deathCurse then
        for _, o in ipairs(self:Foes(t)) do if dist(o,t) <= 26 then self:Curse(o,5,0.3,0.3) end end
        self:Effect('ring',t.x,t.y,'#9be36b',0.7,{r=22})
    end
    if src and not src.dead and src.side ~= t.side then
        if src.killStack and src.kills < 8 then
            src.kills = src.kills+1
            src.atk, src.cd = round(src.baseAtk*(1+0.15*src.kills)), src.baseCd/(1+0.1*src.kills)
            self:Heal(src,src.maxHp*0.15)
        end
        if src.killHeal then self:Heal(src,src.maxHp*src.killHeal) end
    end
    if t.side == 2 then
        for _, owner in ipairs(self.entities) do
            if not owner.dead and owner.deathRaise and math.random() < owner.deathRaise and #self:Minions(owner) < 5 then
                self:Summon(owner,'lichbone',{x=t.x,y=t.y}); break
            end
        end
    end
end
---@param src table
---@param t table
---@param base number
---@param opt table|nil
---@return number
function Battle:Hit(src,t,base,opt)
    if t.dead then return 0 end
    local o = opt or {}
    if t.inv > 0 or t.immune then return 0 end
    if t.dodge and not o.dot and not o.reflect and math.random() < t.dodge then
        self:Effect('miss',t.x,t.y-12,'#c9cbd6',0.5,{text='闪避'}); return 0
    end
    local crit = o.forceCrit or (not o.noCrit and math.random() < src.crit)
    local mul = crit and src.critMul or 1
    if src.execBonus and not o.dot and t.hp < t.maxHp*0.5 then mul = mul*(1+src.execBonus) end
    if t.curse then mul = mul*(1+t.curse.vuln) end
    if src.curse and not o.dot then mul = mul*(1-src.curse.weak) end
    local dr = math.min(0.8,t.dr+(t.armor or 0)+(t.giant > 0 and 0.2 or 0)+(t.guard and t.guard.dr or 0)+(t.side == 1 and self.aura or 0))
    local dmg = math.max(1,round(base*mul*(1-dr)))
    local absorbed = math.min(t.shield,dmg)
    t.shield, t.hp, t.flash = t.shield-absorbed, t.hp-dmg+absorbed, 0.1
    if not o.dot and not t.big and not t.anchor and src ~= t then
        t.knock, t.knockDir = 0.08, t.x >= src.x and 1 or -1
    end
    if not o.noLeech and not src.dead then
        local leech = src.leech+(src.berserk and src.hp < src.maxHp*0.5 and 0.2 or 0)
        if leech > 0 then src.hp = math.min(src.maxHp,src.hp+dmg*leech) end
    end
    if t.skill and t.side == 1 and not o.dot then self:Energy(t,6) end
    if src.drain and o.melee and t.skill then t.energy = math.max(0,t.energy-src.drain) end
    if crit and src.critEnergy and not src.dead then self:Energy(src,src.critEnergy) end
    if src.healHit and not o.dot and not src.dead then self:HealLowest(src,dmg*src.healHit) end
    self:Effect('text',t.x,t.y-12,o.dot and '#9be36b' or crit and '#ffe680' or '#ffffff',0.5,
        {text=tostring(dmg),crit=not not crit,dot=o.dot,shield=absorbed >= dmg})
    -- 阶段门槛不允许高伤害跳过（与 HTML 一样）。
    if t.phases and not t.ph1 and t.hp < t.maxHp*0.6 then t.hp = math.floor(t.maxHp*0.6) end
    if t.vphases then
        if not t.ph1 and t.hp < t.maxHp*0.66 then t.hp = math.floor(t.maxHp*0.66)
        elseif not t.ph2 and t.hp < t.maxHp*0.33 then t.hp = math.floor(t.maxHp*0.33) end
    end
    if t.hp <= 0 then
        if t.undying and not t.undyingUsed then
            t.undyingUsed, t.hp, t.inv, t.stun = true, round(t.maxHp*0.5), 2.5, 0
            self:SkillEffect(t,'不灭重生',true)
        else self:Death(t,src) end
    end
    if o.melee and t.thorns and not o.reflect and not src.dead then
        self:Hit(t,src,dmg*t.thorns,{noCrit=true,noLeech=true,reflect=true})
    end
    if t.mirrorArmor and not o.melee and not o.dot and not o.reflect and not src.dead and src ~= t then
        self:Hit(t,src,math.min(dmg*t.mirrorArmor,src.maxHp*0.08),{noCrit=true,noLeech=true,reflect=true})
        self:Effect('impact',t.x,t.y-6,'#9ff6ff',0.2,{r=5})
    end
    return dmg
end
---@param src table
---@param t table
function Battle:Execute(src,t)
    if t.dead then return end
    if t.charmed > 0 then self:Hit(src,t,src.atk*2.8); return end
    self:Death(t,src)
    self:Effect('slash',t.x,t.y,'#ff4a4a',0.35,{r=14})
end
---@param t table
---@param frac number
function Battle:Revive(t,frac)
    t.dead, t.deadT, t.hp, t.stun, t.cdLeft, t.target = false, 0, round(t.maxHp*frac), 0, 0.3, nil
    for _, k in ipairs({'burn','poison','curse','bleed','guard','hot'}) do t[k] = nil end
    self:Effect('ring',t.x,t.y,'#fff3b0',0.75,{r=12})
end
---@param src table
---@param x number
---@param y number
---@param maxD number
---@param skip table|nil
---@return table|nil
function Battle:NearestOther(src,x,y,maxD,skip)
    ---@type table|nil
    local best = nil
    local bd = maxD
    for _, o in ipairs(self.entities) do
        if not o.dead and o.side ~= src.side and not (skip and skip[o]) then
            local d = hypot(o.x-x,o.y-y)
            if d < bd then best, bd = o, d end
        end
    end
    return best
end
---@param src table
---@return table|nil
function Battle:Nearest(src)
    ---@type table|nil
    local best = nil
    local bd = math.huge
    for _, o in ipairs(self.entities) do
        if not o.dead and o.side ~= src.side then
            local d = hypot(o.x-src.x,(o.y-src.y)*1.3)+(o.immune and 400 or 0)
            if d < bd then best, bd = o, d end
        end
    end
    return best
end
---@param src table
---@return table|nil
function Battle:Backmost(src)
    local fs, main = self:Foes(src), {}
    for _, o in ipairs(fs) do if not o.minion then main[#main+1] = o end end
    return firstSorted(#main > 0 and main or fs,function(a,b) return a.x < b.x end)
end
---@param e table
---@return boolean
function Battle:AddEntity(e)
    -- 不在实体遍历期间删数组；统一由每帧更新末尾回收尸体，避免索引失效。
    if #self.entities >= MAX_ENT then return false end
    self.entities[#self.entities+1] = e
    return true
end
---@param typ string
---@param x number
---@param y number
---@param cd number|nil
---@return table|nil
function Battle:SpawnEnemy(typ,x,y,cd)
    local e = enemyEnt(self.game,{type=typ,x=x,y=y},self.wave)
    bound(e); e.cdLeft = cd or 0.6
    if not self:AddEntity(e) then return nil end
    self:Effect('ring',e.x,e.y,'#ff8a2a',0.5,{r=8})
    return e
end
---@param owner table
---@param kind string
---@param extra table|nil
---@return table|nil
function Battle:Summon(owner,kind,extra)
    local n = #self:Minions(owner)
    local o = {x=owner.x+owner.face*10,y=owner.y+rand(-8,8),owner=owner,minion=true,star=0,q=owner.q,
        maxHp=round(owner.maxHp*0.6),atk=round(owner.atk*0.55),cd=1,range=8,speed=22,
        sprite='skeleton',cls='skeleton',type=kind,mkey=kind}
    if kind == 'lichbone' then
        assign(o,{maxHp=round(owner.maxHp*0.8),atk=round(owner.atk*0.75),cd=0.9,speed=24,pal=(Data.BRPAL or {}).lichbone})
    elseif kind == 'wolf' then
        assign(o,{maxHp=round(owner.maxHp*1.2),atk=round(owner.atk*0.75),cd=0.75,crit=0.1,speed=34,sprite='wolf',cls='wolf'})
    elseif kind == 'turret' then
        assign(o,{x=owner.x-10,y=owner.y+(n%2 == 1 and 18 or -18),maxHp=round(owner.maxHp*0.8),
            atk=round(owner.atk*0.5),cd=0.4,crit=owner.crit,range=84,speed=0,proj='arrow',anchor=true,sprite='turret',cls='turret'})
    elseif kind == 'sprout' then
        local offset = n%3 == 0 and 0 or n%3 == 1 and -18 or 18
        assign(o,{x=owner.x-8-(n > 0 and 4 or 0),y=owner.y+offset,maxHp=round(owner.maxHp*0.6),
            atk=round(owner.atk*0.6),cd=0.9,crit=owner.crit,range=60,speed=0,proj='parrow',anchor=true,
            poisonHit=1,sprite='sprout',cls='sprout',pal={a='#c4405a',A='#ff7f9a'}})
    elseif kind == 'clone' then
        assign(o,{x=owner.x+rand(-6,6),y=owner.y+(n == 0 and -14 or 14),maxHp=round(owner.maxHp*0.5),
            atk=round(owner.atk*0.75),cd=owner.cd,crit=owner.crit,range=owner.range,speed=owner.speed,
            proj='arrow',dodge=owner.dodge,life=12,ghost=true,sprite='sniper',cls=owner.cls,pal=(Data.BRPAL or {}).shadow})
    end
    assign(o,extra)
    local e = makeEnt(owner.originalSide,o)
    e.mspr, e.mpal, e.cdLeft = e.sprite, e.pal, kind == 'wolf' and 0.3 or 0.4
    bound(e)
    if not self:AddEntity(e) then return nil end
    self:Effect('ring',e.x,e.y,kind == 'lichbone' and '#6ef0ff' or '#c06bff',0.5,{r=8})
    return e
end
---@param e table
---@param t table|nil
---@param kind string
---@param extra table|nil
function Battle:Shoot(e,t,kind,extra)
    if #self.projectiles >= MAX_PROJ then return end
    local p = assign({x=e.x+e.face*5,y=e.y-3,tgt=t,tx=t and t.x or 0,ty=t and t.y-3 or 0,
        kind=kind,speed=SLOW_PROJ[kind] and 95 or 150,src=e,mul=1,splash=0,splashMul=0.6,
        area=false,delay=0,done=false,ang=0,life=12,color=PROJ_COLOR[kind] or '#c9cbd6'},extra)
    self.projectiles[#self.projectiles+1] = p
end
---@param field table
function Battle:AddField(field)
    if #self.fields >= MAX_FIELD then return end
    field.kind = field.kind or 'blackhole'
    field.max = field.max or field.t
    field.life, field.maxLife = field.t, field.max
    field.color = field.color or ((field.kind == 'lava' or field.kind == 'fissure') and '#ff8a2a' or '#c06bff')
    self.fields[#self.fields+1] = field
end
---@param p table
---@param o table
function Battle:ProcHit(p,o)
    if o.dead then return end
    if p.burn then self:Dot(o,p.src,p.burn.t,p.burn.dps,'burn') end
    if p.slow then self:Slow(o,p.slow.t,p.slow.amt) end
    if p.stunHit then o.stun = math.max(o.stun,p.stunHit) end
    if p.poison then self:Poison(o,p.src,p.poison) end
    if p.curse then self:Curse(o,p.curse.t,p.curse.vuln,p.curse.weak) end
end
---@param e table
---@param t table
function Battle:Attack(e,t)
    if e.proj then
        local burn = e.burnOnHit and {t=2,dps=e.atk*0.25} or nil
        local slow = e.slowHit and e.slowHit > 0 and {t=2,amt=e.slowHit} or nil
        local chain = e.chainHit or 0
        if e.elemHit then
            local k = math.random(1,3)
            if k == 1 then burn = {t=2,dps=e.atk*0.3}
            elseif k == 2 then slow = {t=2,amt=0.35} else chain = 1 end
        end
        self:Shoot(e,t,e.proj,{splash=e.splash,burn=burn,slow=slow,chain=chain,poison=e.poisonHit or 0,
            ricochet=e.ricochet or 0,curse=e.curseHit and {t=3,vuln=e.curseHit,weak=0} or nil})
        if e.extra and e.extra > 0 and math.random() < e.extra then self:Shoot(e,t,e.proj,{delay=0.1,mul=0.7}) end
    else
        if e.bomb then
            e.exploded, e.dead, e.hp, e.deadT = true, true, 0, 0
            for _, o in ipairs(self:Foes(e)) do if dist(o,e) <= 20+o.r then self:Hit(e,o,e.atk*e.bomb,{noLeech=true,noCrit=true}) end end
            self:Effect('ring',e.x,e.y,'#ffb03a',0.6,{r=20}); return
        end
        local bs = e.backstab and 2 or 1
        e.backstab = false
        self:Hit(e,t,e.atk*(e.giant > 0 and 1.3 or 1)*bs,{melee=true})
        if e.bleedHit and not t.dead and math.random() < e.bleedHit then self:Dot(t,e,3,e.atk*0.45,'bleed') end
        if e.giant > 0 then
            for _, o in ipairs(self:Foes(e)) do
                if dist(o,t) <= 22 then
                    if o ~= t then self:Hit(e,o,e.atk*0.8,{noLeech=true}) end
                    if not o.dead then o.stun = math.max(o.stun,0.4) end
                end
            end
            self:Effect('ring',t.x,t.y,'#ffa53a',0.35,{r=18})
        end
        if e.splash > 0 then self:Splash(e,t.x,t.y,e.splash,e.atk*0.5,t) end
        self:Effect('slash',t.x,t.y,'#e6edf7',0.22,{x2=e.x,y2=e.y,r=9})
    end
end
---@param src table
---@param x number
---@param y number
---@param rad number
---@param dmg number
---@param except table|nil
function Battle:Splash(src,x,y,rad,dmg,except)
    for _, o in ipairs(self:Foes(src)) do if o ~= except and hypot(o.x-x,o.y-y) <= rad then self:Hit(src,o,dmg) end end
end
---@param e table
---@param t table
---@param mul number
function Battle:Meteor(e,t,mul)
    self:Shoot(e,t,'meteor',{x=t.x-26,y=t.y-70,speed=130,area=true,splash=24,mul=mul,burn={t=3,dps=e.atk*0.4}})
end
---@param e table
---@param t table
---@param mul number
---@param freeze number
function Battle:Frost(e,t,mul,freeze)
    self:Shoot(e,t,'frostbig',{area=true,splash=26,mul=mul,stunHit=freeze,slow={t=3,amt=0.35}})
end
---@param e table
---@param t table
---@param mul number
---@param count number
function Battle:Chain(e,t,mul,count)
    local cur, px, py, done = t, e.x+e.face*5, e.y-4, {}
    local damageMul = mul
    for _=1,count do
        if not cur then break end
        done[cur] = true
        self:Effect('bolt',px,py,'#ffe14a',0.25,{x2=cur.x,y2=cur.y-3})
        self:Hit(e,cur,e.atk*damageMul)
        damageMul, px, py = damageMul*0.85, cur.x, cur.y-3
        cur = self:NearestOther(e,cur.x,cur.y,46,done)
    end
end
---@param e table
---@param t table
---@param color string
---@param behind boolean|nil
function Battle:Jump(e,t,color,behind)
    local dir, ox, oy = t.x >= e.x and 1 or -1, e.x, e.y
    e.x = t.x+(behind and dir or -dir)*(t.r+e.r+2)
    e.y, e.face, e.target = t.y, behind and -dir or dir, t
    bound(e)
    self:Effect('line',ox,oy-4,color,0.4,{x2=e.x,y2=e.y-4})
end
---@param e table
---@param radius number
---@param mul number
---@param stun number|nil
---@param bossStun number|nil
function Battle:AreaMelee(e,radius,mul,stun,bossStun)
    for _, o in ipairs(self:Foes(e)) do
        if dist(o,e) <= radius then
            self:Hit(e,o,e.atk*mul,{noLeech=true})
            if stun and not o.dead then o.stun = math.max(o.stun,o.big and (bossStun or stun) or stun) end
        end
    end
    self:Effect('ring',e.x,e.y,'#ffb04a',0.5,{r=radius})
end

--- 完整的 67 个主动技能分支；同技能路线共享逻辑，但不抹平独特机制。
---@param e table
---@param t table
function Battle:Cast(e,t)
    local s = e.skill
    local info = (Data.SKILLS or {})[s] or {name=s}
    self:SkillEffect(e,s == 'elements' and ('元素·'..({'陨火','冰封','雷链'} --[[@as string[] ]])[e.elemIdx%3+1]) or info.name)
    if s == 'bash' then
        self:Hit(e,t,e.atk*1.6); if not t.dead then t.stun = math.max(t.stun,1) end
    elseif s == 'triple' then
        for i=0,2 do self:Shoot(e,t,'arrow',{delay=i*0.1,mul=0.8}) end
    elseif s == 'arcane' then self:Shoot(e,t,'arcane',{area=true,splash=22,mul=1.5})
    elseif s == 'whirlwind' then
        local dealt = 0
        for _, o in ipairs(self:Foes(e)) do if dist(o,e) <= 24 then dealt = dealt+self:Hit(e,o,e.atk*1.4,{noLeech=true}) end end
        self:Heal(e,dealt*0.3); self:Effect('ring',e.x,e.y,'#ff9a7a',0.4,{r=22})
    elseif s == 'aegis' then
        local al = self:Allies(e)
        table.sort(al,function(a,b) return a.hp/a.maxHp < b.hp/b.maxHp end)
        local chosen = {e}
        for _, o in ipairs(al) do if o ~= e and #chosen < 3 then chosen[#chosen+1] = o end end
        for _, o in ipairs(chosen) do o.shield = math.min(o.maxHp,o.shield+e.maxHp*0.3) end
        for _, o in ipairs(self:Foes(e)) do if dist(o,e) <= 60 then o.target = e end end
    elseif s == 'snipe' or s == 'hunt' then
        local target = firstSorted(self:Foes(e),s == 'snipe' and function(a,b) return a.hp > b.hp end or function(a,b) return a.hp/a.maxHp < b.hp/b.maxHp end) or t
        self:Shoot(e,target,'snipe',{speed=s == 'snipe' and 420 or 380,mul=s == 'snipe' and 4 or 3.5,killRefund=s == 'hunt' and 60 or nil})
    elseif s == 'volley' then
        for i=0,5 do
            local x, y = clamp(t.x+rand(-14,14),6,W-6), clamp(t.y+rand(-12,12),14,H-10)
            self:Shoot(e,nil,'rain',{x=x,y=y-46,tx=x,ty=y,speed=170,delay=0.12+i*0.11,area=true,splash=10,mul=0.8})
        end
    elseif s == 'meteor' then self:Meteor(e,t,2.2)
    elseif s == 'stomp' then self:AreaMelee(e,30,1.2,1)
    elseif s == 'raise' or s == 'wolf' or s == 'turret' or s == 'seedling' then
        local mine = self:Minions(e)
        local caps = {raise=2,wolf=1,turret=2,seedling=3}
        if #mine < caps[s] then self:Summon(e,s == 'raise' and 'bone' or s == 'seedling' and 'sprout' or s)
        else for _, o in ipairs(mine) do o.hp = o.maxHp; if s ~= 'raise' then o.haste = 4 end end end
    elseif s == 'leap' then
        local target = firstSorted(self:Foes(e),function(a,b) return math.abs(a.x-e.x) > math.abs(b.x-e.x) end)
        if target then self:Jump(e,target,'#7fe0c0'); self:AreaMelee(e,22,2,0.8) end
    elseif s == 'issen' then
        self:Hit(e,t,e.atk*2.8,{forceCrit=true}); if t.dead then e.energy = 50 end
    elseif s == 'pierce' or s == 'bloodarrow' then
        local dx, dy = t.x-e.x, t.y-e.y
        local d = math.max(0.001,hypot(dx,dy))
        self:Shoot(e,nil,s == 'pierce' and 'pierce' or 'bloodpierce',{pierce=true,vx=dx/d,vy=dy/d,
            ang=math.atan(dy,dx),speed=s == 'pierce' and 240 or 300,mul=s == 'pierce' and 2.2 or 4.5,hitSet={},
            curse=s == 'bloodarrow' and {t=6,vuln=0.35,weak=0} or nil})
    elseif s == 'frostnova' then self:Frost(e,t,1.3,1.5)
    elseif s == 'chain' then self:Chain(e,t,1.6,5)
    elseif s == 'warcry' or s == 'sunburst' then
        for _, o in ipairs(self:Allies(e)) do
            o.haste = math.max(o.haste,s == 'warcry' and 3 or 2)
            self:Heal(o,o.maxHp*(s == 'warcry' and 0.12 or 0.15)); if s == 'sunburst' then o.stun = 0 end
        end
    elseif s == 'vengeance' then
        self:Hit(e,t,e.atk*1.8+(e.maxHp-e.hp)*0.6); if not t.dead then t.stun = math.max(t.stun,0.8) end
    elseif s == 'venomburst' then self:Shoot(e,t,'parrow',{area=true,splash=20,mul=1,poison=3})
    elseif s == 'heal' then
        for _, o in ipairs(self:Allies(e)) do self:Heal(o,o.maxHp*0.28); o.stun = 0 end
    elseif s == 'hex' then
        for _, o in ipairs(self:Foes(e)) do if dist(o,t) <= 30 then self:Curse(o,6,0.3,0.3); self:Hit(e,o,e.atk*0.8) end end
        self:Effect('ring',t.x,t.y,'#9be36b',0.5,{r=28})
    elseif s == 'shockwave' then
        for _, o in ipairs(self:Foes(e)) do
            if dist(o,e) <= 34 and (o.x-e.x)*e.face >= -4 then
                self:Hit(e,o,e.atk*1.8,{noLeech=true})
                if not o.dead then o.stun = math.max(o.stun,0.6); if not o.big then o.x = clamp(o.x+e.face*20,6,W-6) end end
            end
        end
        self:Effect('ring',e.x+e.face*12,e.y,'#6ef0ff',0.4,{r=22})
    elseif s == 'behead' then
        self:Hit(e,t,e.atk*(t.big and 5 or 2.8))
        if not t.dead and not t.big and t.hp < t.maxHp*0.35 then self:Execute(e,t) end
    elseif s == 'barrage' then
        local foes = self:Foes(e)
        for i=0,7 do if #foes > 0 then self:Shoot(e,foes[math.random(1,#foes)],'arrow',{delay=i*0.07,mul=1,ricochet=e.ricochet or 0}) end end
    elseif s == 'timestop' or s == 'moonlight' then
        for _, o in ipairs(self:Foes(e)) do o.stun = math.max(o.stun,o.big and (s == 'timestop' and 0.8 or 0.7) or (s == 'timestop' and 1.6 or 1.5)) end
        for _, o in ipairs(self:Allies(e)) do
            if s == 'timestop' then o.haste = math.max(o.haste,2.5) else self:Heal(o,o.maxHp*0.12) end
        end
        self:Effect('ring',128,72,'#bff4ff',0.6,{r=100})
    elseif s == 'blackhole' then self:AddField({x=t.x,y=t.y,t=3,tick=0.5,r=40,src=e,mul=0.5,boom=1.5})
    elseif s == 'giant' then
        e.big, e.r, e.giant = true, 9, 6; self:Heal(e,e.maxHp*0.15)
        self:Effect('ring',e.x,e.y,'#ffa53a',0.6,{r=24})
    elseif s == 'sanctuary' then
        local fallen = {}
        for _, o in ipairs(self.entities) do if o.dead and o.side == e.side and not o.minion and o ~= e then fallen[#fallen+1] = o end end
        local target = firstSorted(fallen,function(a,b) return a.atk > b.atk end)
        if target then self:Revive(target,0.6) end
        for _, o in ipairs(self:Allies(e)) do o.shield = math.min(o.maxHp,o.shield+o.maxHp*0.35) end
    elseif s == 'starfall' or s == 'bloodmoon' then
        for i, o in ipairs(self:Foes(e)) do
            self:Shoot(e,o,s == 'starfall' and 'star' or 'bloodstar',{x=o.x+rand(-12,12),y=s == 'starfall' and -6 or -8,
                speed=s == 'starfall' and 220 or 240,delay=s == 'starfall' and (i-1)*0.06 or 0.2+(i-1)*0.05,
                mul=s == 'starfall' and 1.5 or 2.4,stunHit=s == 'starfall' and 0.4 or nil,
                burn=s == 'bloodmoon' and {t=4,dps=e.atk*0.4} or nil})
        end
        if s == 'bloodmoon' then
            for _, o in ipairs(self:Allies(e)) do o.haste = math.max(o.haste,3) end
            self:Effect('ring',128,35,'#ff3434',1.6,{r=28,text='血月'})
        end
    elseif s == 'shadowclone' then
        local mine = self:Minions(e)
        if #mine < 2 then for _=#mine+1,2 do self:Summon(e,'clone') end
        else e.haste = math.max(e.haste,4); for _, o in ipairs(mine) do o.haste = math.max(o.haste,4) end end
    elseif s == 'elements' then
        local k = e.elemIdx%3; e.elemIdx = k+1
        if k == 0 then self:Meteor(e,t,3.2) elseif k == 1 then self:Frost(e,t,2,2) else self:Chain(e,t,2.6,7) end
    elseif s == 'legion' then
        local room = 5-#self:Minions(e)
        for i=1,math.min(2,room) do self:Summon(e,'lichbone',{x=e.x+e.face*10,y=e.y+(i == 1 and -10 or 10)}) end
        for _, o in ipairs(self:Minions(e)) do o.hp, o.haste = o.maxHp, math.max(o.haste,5) end
    elseif s == 'pounce' or s == 'ambush' or s == 'bearhug' then
        local fs = {}
        for _, o in ipairs(self:Foes(e)) do if not o.immune then fs[#fs+1] = o end end
        local target = firstSorted(fs,s == 'pounce' and function(a,b) return a.hp/a.maxHp < b.hp/b.maxHp end
            or s == 'ambush' and function(a,b) return a.hp < b.hp end or function(a,b) return a.atk > b.atk end)
        if not target and s == 'bearhug' then target = t end
        if target then
            self:Jump(e,target,s == 'ambush' and '#ffffff' or '#ffa53a',s == 'ambush')
            self:Hit(e,target,e.atk*(s == 'pounce' and 2.2 or s == 'ambush' and 3 or 2.5),{melee=true,forceCrit=s == 'ambush'})
            if s == 'pounce' and target.dead then e.energy = 50 end
            if s == 'bearhug' then
                if not target.dead then target.stun = math.max(target.stun,target.big and 0.8 or 2) end
                self:Heal(e,e.maxHp*0.2)
            end
        end
    elseif s == 'rend' then
        for _=1,3 do if not t.dead then self:Hit(e,t,e.atk*0.8,{melee=true}) end end
        self:Dot(t,e,3,e.atk*0.5,'bleed'); self:Effect('slash',t.x,t.y,'#ff4a3a',0.4,{r=12})
    elseif s == 'tigerroar' then
        e.haste = math.max(e.haste,6); self:Heal(e,e.maxHp*0.2)
        for _, o in ipairs(self:Foes(e)) do if dist(o,e) <= 36 then o.stun = math.max(o.stun,o.big and 0.4 or 0.8) end end
    elseif s == 'roar' then
        for _, o in ipairs(self:Foes(e)) do if dist(o,e) <= 60 then o.target = e end end
        e.guard = {t=4,dr=0.35}; self:Heal(e,e.maxHp*0.1)
    elseif s == 'quake' then self:AreaMelee(e,26,1.3,0.8,0.4)
    elseif s == 'hibernate' then
        e.shield = math.min(e.maxHp,e.shield+e.maxHp*0.4); self:Heal(e,e.maxHp*0.25); e.guard = {t=5,dr=0.4}
    elseif s == 'frostroar' then
        for _, o in ipairs(self:Foes(e)) do
            if dist(o,e) <= 56 then
                self:Hit(e,o,e.atk,{noLeech=true})
                if not o.dead then self:Slow(o,4,0.5); o.stun = math.max(o.stun,o.big and 0.3 or 0.6); o.target = e end
            end
        end
    elseif s == 'spore' or s == 'entangle' then
        for _, o in ipairs(self:Foes(e)) do
            if dist(o,t) <= (s == 'spore' and 24 or 26) then
                self:Hit(e,o,e.atk*0.7)
                if s == 'spore' then self:Poison(o,e,2); self:Slow(o,3,0.3)
                elseif not o.dead then o.stun = math.max(o.stun,o.big and 0.6 or 1.2) end
            end
        end
        self:Effect('ring',t.x,t.y,'#9be36b',0.6,{r=24})
    elseif s == 'virulence' then
        local sick = {}
        for _, o in ipairs(self:Foes(e)) do if o.poison then sick[#sick+1] = o end end
        if #sick == 0 then self:Poison(t,e,3) end
        for _, o in ipairs(sick) do
            local n = o.poison.n; o.poison = nil; self:Hit(e,o,e.atk*0.7*n,{noCrit=true})
            self:Effect('ring',o.x,o.y,'#e6ff6a',0.5,{r=14})
        end
    elseif s == 'plague' then
        for _, o in ipairs(self:Foes(e)) do self:Poison(o,e,4); self:Curse(o,6,0.2,0) end
    elseif s == 'devour' then
        local fs = {}
        for _, o in ipairs(self:Foes(e)) do if not o.immune then fs[#fs+1] = o end end
        local target = firstSorted(fs,function(a,b) return a.hp < b.hp end) or t
        self:Hit(e,target,e.atk*3)
        if not target.dead and not target.big and target.hp < target.maxHp*0.4 then self:Execute(e,target) end
        if target.dead then for _, o in ipairs(self:Allies(e)) do self:Heal(o,o.maxHp*0.12) end end
    elseif s == 'bloom' then
        for _, o in ipairs(self:Allies(e)) do o.hot = {t=5,tick=1} end
    elseif s == 'solarflare' or s == 'rebirth' then
        if s == 'rebirth' and not e.rebirthUsed then
            e.rebirthUsed = true
            for _, o in ipairs(self.entities) do if o.dead and o.side == e.side and not o.minion and o ~= e then self:Revive(o,0.5) end end
        end
        for _, o in ipairs(self:Foes(e)) do self:Hit(e,o,e.atk*(s == 'solarflare' and 1.1 or 1.2)); self:Dot(o,e,3,e.atk*0.4,'burn') end
        for _, o in ipairs(self:Allies(e)) do
            self:Heal(o,o.maxHp*(s == 'solarflare' and 0.08 or 0.3))
            if s == 'rebirth' then o.haste = math.max(o.haste,4) end
        end
    elseif s == 'crimsonmoon' then
        local dealt = 0
        for _, o in ipairs(self:Foes(e)) do
            if hypot(o.x-e.x,(o.y-e.y)*1.2) <= 64 and (o.x-e.x)*e.face >= -8 then
                dealt = dealt+self:Hit(e,o,e.atk*3.2,{noLeech=true}); self:Dot(o,e,4,e.atk*0.6,'bleed')
            end
        end
        self:Heal(e,dealt*0.25); self:Effect('slash',e.x+e.face*8,e.y-4,'#ff3434',0.5,{r=30})
    elseif s == 'bloodrush' then
        for _=1,5 do
            local fs = {}
            for _, o in ipairs(self:Foes(e)) do if not o.immune then fs[#fs+1] = o end end
            local target = firstSorted(fs,function(a,b) return a.hp/a.maxHp < b.hp/b.maxHp end)
            if not target then break end
            self:Jump(e,target,'#ff3434'); self:Hit(e,target,e.atk*2.2,{melee=true,forceCrit=true})
        end
    elseif s == 'doomstomp' then
        self:AreaMelee(e,52,2.6,2,1)
        for _, o in ipairs(self:Foes(e)) do if dist(o,e) <= 52 then o.target = e end end
        e.shield = math.min(e.maxHp,e.shield+e.maxHp*0.4)
    elseif s == 'bloodthorn' then
        local dealt = 0
        for _, o in ipairs(self:Foes(e)) do
            dealt = dealt+self:Hit(e,o,e.atk*1.8)
            if not o.dead then self:Poison(o,e,4); o.stun = math.max(o.stun,o.big and 0.6 or 1.5) end
            self:Effect('impact',o.x,o.y,'#ff3434',0.6,{r=12})
        end
        local al = self:Allies(e)
        for _, o in ipairs(al) do self:Heal(o,dealt*0.3/math.max(1,#al)) end
    elseif s == 'rally' then
        for _, o in ipairs(self:Allies(e)) do o.haste = math.max(o.haste,3) end
    elseif s == 'mend' then
        local al = self:Allies(e)
        local low = firstSorted(al,function(a,b) return a.hp/a.maxHp < b.hp/b.maxHp end)
        for _, o in ipairs(al) do self:Heal(o,o.maxHp*(o == low and 0.3 or 0.08)) end
    elseif s == 'lavapool' then self:Shoot(e,t,'lavaball',{area=true,splash=14,mul=0.8,pool=true,speed=90})
    elseif s == 'forge' then
        for _, o in ipairs(self:Allies(e)) do o.shield = math.min(o.maxHp*0.5,o.shield+o.maxHp*0.25) end
    elseif s == 'fissure' then
        local dx, dy = t.x-e.x, t.y-e.y
        local d = math.max(0.001,hypot(dx,dy))
        self:AddField({kind='fissure',x=e.x,y=e.y+4,x2=e.x+dx/d*230,y2=e.y+4+dy/d*230,w=7,
            warn=0.9,t=1.4,max=1.4,src=e,mul=1.8,fired=false})
    elseif s == 'charm' then
        local fs = {}
        for _, o in ipairs(self:Foes(e)) do if not o.minion and o.charmed <= 0 and not o.ccImmune then fs[#fs+1] = o end end
        local target = firstSorted(fs,function(a,b) return a.atk > b.atk end)
        if target then
            target.side, target.charmed, target.target = e.side, 3, nil
            self:ClearTargets(target); self:SkillEffect(target,'倒戈')
        end
    elseif s == 'rift' then
        local fs, main = self:Foes(e), {}
        for _, o in ipairs(fs) do if not o.minion then main[#main+1] = o end end
        local list = #main > 0 and main or fs
        for i=#list,2,-1 do local j = math.random(1,i); list[i],list[j] = list[j],list[i] end
        for i=1,math.min(3,#list) do
            local o = list[i]
            if o then self:AddField({kind='rift',x=o.x,y=o.y+3,r=15,warn=1.2,t=1.25,max=1.25,src=e,mul=1.6,fired=false}) end
        end
    else print('[军团战斗] 未知技能：'..tostring(s)) end
end

---@param target table
function Battle:ClearTargets(target)
    for _, o in ipairs(self.entities) do if o.target == target then o.target = nil end end
end
---@param e table
function Battle:BossPhase(e)
    local f = e.hp/e.maxHp
    if e.rage > 0 and not e.raged and f < 0.5 then
        e.raged = true; self:SkillEffect(e,'亡灵召唤',true)
        self:BossAdds(e,e.rage)
    end
    if e.phases then
        if not e.ph1 and f <= 0.6 then
            e.ph1, e.immune, e.channel, e.chT, e.stun, e.energy = true, true, true, 0, 0, 0
            e.x, e.y, e.pillars = 214, 72, {}
            self:SkillEffect(e,'熔核护盾',true)
            for _, p in ipairs({{182,30},{182,114},{244,72}}) do
                local pillar = self:SpawnEnemy('pillar',p[1],p[2],0.8)
                if pillar then e.pillars[#e.pillars+1] = pillar end
            end
            self:ClearTargets(e); return
        end
        if e.channel then
            local allDead = true
            for _, p in ipairs(e.pillars or {}) do if not p.dead then allDead = false end end
            if allDead then
                e.channel, e.immune, e.stun = false, false, math.max(e.stun,3)
                self:Curse(e,5,0.5,0); self:SkillEffect(e,'核心过载',true)
            end
        end
        if not e.ph2 and not e.channel and f <= 0.3 then
            e.ph2, e.frenzy = true, true
            self:SkillEffect(e,'熔核暴走',true); self:BossAdds(e,e.adds)
        end
    end
    if e.vphases then
        if not e.ph1 and f <= 0.66 then
            e.ph1 = true; self:SkillEffect(e,'虚空镜像',true)
            local fs = {}
            for _, o in ipairs(self:Foes(e)) do if not o.minion and o.charmed <= 0 then fs[#fs+1] = o end end
            table.sort(fs,function(a,b) return a.atk > b.atk end)
            local n = math.min(#fs,math.max(1,e.adds))
            for i=1,n do
                local o = fs[i]
                if o then
                    local mirror = makeEnt(2,{x=e.x-20,y=e.y+((i-1)-(n-1)/2)*22,maxHp=round(o.maxHp*0.6),
                        atk=round(o.atk*0.6),cd=o.cd,crit=o.crit,range=o.range,speed=o.speed or 20,r=o.r,
                        proj=o.proj,splash=o.splash,sprite=o.sprite,cls=o.cls,star=o.star,q=o.q,branch=o.branch,
                        critMul=o.critMul,tall=o.tall,type='voidmirror',vcopy=true,ghost=true,pal=o.pal})
                    mirror.cdLeft = 0.6; bound(mirror); self:AddEntity(mirror)
                end
            end
        end
        if not e.ph2 and f <= 0.33 then
            e.ph2, e.cast, e.stun, e.energy, e.shield = true, 6, 0, 0, round(e.maxHp*0.2)
            self:SkillEffect(e,'虚空坍缩',true)
        end
    end
    if e.frenzy then e.haste = math.max(e.haste,0.1) end
end
---@param e table
---@param count number
function Battle:BossAdds(e,count)
    local pool = self.chapter.rage or {'skeleton','skelarcher'}
    for i=1,count do
        self:SpawnEnemy(pool[(i-1)%#pool+1],e.x-16+rand(-4,4),e.y+((i-1)-(count-1)/2)*16,0.6)
    end
end
---@param e table
function Battle:Blink(e)
    local fs, main = self:Foes(e), {}
    for _, o in ipairs(fs) do if not o.minion then main[#main+1] = o end end
    local prey = firstSorted(#main > 0 and main or fs,function(a,b) return a.maxHp < b.maxHp end)
    if not prey then e.blinkT = 2; return end
    local x, y = e.x, e.y
    e.x, e.y, e.target, e.face, e.backstab = clamp(prey.x-10,6,W-6), prey.y, prey, 1, true
    e.cdLeft, e.blinkT = math.min(e.cdLeft,0.25), 8
    self:Effect('line',x,y,'#ff5a2a',0.4,{x2=e.x,y2=e.y}); self:SkillEffect(e,'闪现')
end
---@param e table
function Battle:Hook(e)
    local fs = {}
    for _, o in ipairs(self:Foes(e)) do if not o.minion and not o.anchor then fs[#fs+1] = o end end
    local prey = firstSorted(fs,function(a,b) return a.x < b.x end)
    if not prey or prey.x > e.x-24 then e.hookT = 2; return end
    self:Effect('line',e.x,e.y-4,'#8d9ab2',0.4,{x2=prey.x,y2=prey.y-4})
    prey.x, prey.y, prey.stun, prey.target = clamp(e.x-e.r-prey.r-2,6,W-6), e.y, math.max(prey.stun,0.6), e
    e.target, e.hookT = prey, 9; self:SkillEffect(e,'锁魂钩')
end
---@param e table
---@param dt number
function Battle:Status(e,dt)
    for _, kind in ipairs({'burn','poison','bleed'}) do
        local dot = e[kind]
        if dot then
            dot.t, dot.tick = dot.t-dt, dot.tick-dt
            if dot.tick <= 0 then
                dot.tick = dot.tick+0.5
                self:Hit(dot.src,e,(kind == 'poison' and dot.per*dot.n or dot.dps)*0.5,{noCrit=true,noLeech=true,dot=kind})
            end
            if dot.t <= 0 then e[kind] = nil end
            if e.dead then return end
        end
    end
    if e.hot then
        e.hot.t, e.hot.tick = e.hot.t-dt, e.hot.tick-dt
        if e.hot.tick <= 0 then e.hot.tick = e.hot.tick+1; self:Heal(e,e.maxHp*0.06) end
        if e.hot.t <= 0 then e.hot = nil end
    end
    for _, k in ipairs({'guard','curse','slow'}) do
        local st = e[k]
        if st then st.t = st.t-dt; if st.t <= 0 then e[k] = nil end end
    end
    if e.regen then e.hp = math.min(e.maxHp,e.hp+e.maxHp*e.regen*dt) end
    e.inv, e.haste = math.max(0,e.inv-dt), math.max(0,e.haste-dt)
    if e.giant > 0 then
        e.giant = math.max(0,e.giant-dt)
        if e.giant == 0 then e.big, e.r = e.baseBig, e.baseR end
    end
end
---@param e table
---@param dt number
function Battle:StepEntity(e,dt)
    e.flash, e.atkT, e.attackAnim = math.max(0,e.flash-dt), e.atkT+dt, math.max(0,e.attackAnim-dt)
    e.ready, e.knock = false, math.max(0,e.knock-dt)
    if self.over or e.dead then e.moving = false; return end
    if e.life then
        e.life = e.life-dt
        if e.life <= 0 then e.hp, e.dead, e.deadT = 0, true, 0; return end
    end
    self:Status(e,dt)
    if e.dead then return end
    self:BossPhase(e)
    if e.cast > 0 then
        e.moving = false
        if e.shield <= 0 then
            e.cast, e.stun = 0, 3; self:Curse(e,5,0.5,0); self:SkillEffect(e,'吟唱打断',true)
        else
            e.cast = math.max(0,e.cast-dt)
            if e.cast == 0 then
                e.shield, e.stun, e.frenzy = 0, 0, true
                for _, o in ipairs(self:Foes(e)) do
                    self:Hit(e,o,o.maxHp*0.45,{noCrit=true,noLeech=true})
                    if not o.dead then o.stun = math.max(o.stun,1) end
                end
                self:SkillEffect(e,'坍缩',true)
            end
        end
        return
    end
    if e.charmed > 0 then
        e.charmed = math.max(0,e.charmed-dt)
        if e.charmed == 0 then
            e.side, e.target, e.cdLeft = e.originalSide, nil, math.max(e.cdLeft,0.2)
            self:ClearTargets(e)
        end
    end
    if e.shift then
        e.shiftT = e.shiftT-dt
        if e.shiftT <= 0 then
            e.shifted = not e.shifted; e.immune = e.shifted; e.shiftT = e.shifted and 1.5 or 4
            self:Effect('ring',e.x,e.y,'#6ef0ff',0.3,{r=8})
        end
    end
    if e.armor and e.armor > 0 and e.stun > 0 then
        e.armor, e.pal, e.pkey = 0, ((Data.ENEMIES or {})[e.type] or {}).palBroken, e.type..':broken'
        self:SkillEffect(e,'碎甲'); self:Effect('ring',e.x,e.y,'#c9a6ff',0.4,{r=10})
    end
    if e.channel then
        e.moving, e.chT = false, e.chT+dt
        if e.chT >= 0.5 then e.chT = e.chT-0.5; e.hp = math.min(e.maxHp,e.hp+e.maxHp*0.01) end
        return
    end
    if e.ccImmune then e.stun = 0 end
    if e.stun > 0 then e.stun = math.max(0,e.stun-dt); e.moving = false; return end
    if e.blink then e.blinkT = e.blinkT-dt; if e.blinkT <= 0 then self:Blink(e) end end
    if e.hook then e.hookT = e.hookT-dt; if e.hookT <= 0 then self:Hook(e) end end
    if not e.target or e.target.dead or e.target.immune or e.target.side == e.side then
        e.target = e.dive and self:Backmost(e) or self:Nearest(e)
    end
    local target = e.target
    if not target then e.moving = false; return end
    local dx, dy = target.x-e.x, target.y-e.y
    local d = math.max(0.001,hypot(dx,dy))
    if math.abs(dx) > 1 then e.face = dx > 0 and 1 or -1 end
    local reach, sf = e.range+e.r+target.r, e.slow and 1-e.slow.amt or 1
    e.ready, e.moving = d <= reach+0.05, false
    if d > reach and e.speed > 0 then
        local step = math.min(e.speed*sf*dt,d-reach+0.02)
        e.x, e.y, e.moving = e.x+dx/d*step, e.y+dy/d*step, true
    end
    e.cdLeft = e.cdLeft-dt*sf*(e.haste > 0 and 2 or 1)
    if e.ready and e.cdLeft <= 0 then
        e.cdLeft, e.atkT, e.attackAnim, e.atkTx, e.atkTy = e.cd*(e.giant > 0 and 1.15 or 1), 0, 0.3, target.x, target.y
        if e.skill and e.energy >= 100 and e.charmed <= 0 then
            e.energy, e.atkBig, e.atkFx = 0, true, false; self:Cast(e,target)
        else
            e.atkBig, e.atkFx = false, true; self:Attack(e,target)
            local info = (Data.SKILLS or {})[e.skill or ''] or {}
            if e.skill then self:Energy(e,info.charge or 25) end
        end
    end
end
---@param dt number
function Battle:Separate(dt)
    for i=1,#self.entities do
        local a = self.entities[i]
        if not a.dead then
            for j=i+1,#self.entities do
                local b = self.entities[j]
                if not b.dead then
                    local dx, dy = b.x-a.x, b.y-a.y
                    local d, min = hypot(dx,dy), a.r+b.r+1
                    if d < min then
                        if d < 0.01 then dx,dy,d = ((i+j)%2 == 0 and 1 or -1), 0.5, hypot(1,0.5) end
                        local push, nx, ny = (min-d)*0.5, dx/d, dy/d
                        local wa, wb = a.anchor and 0.05 or a.big and 0.2 or 1, b.anchor and 0.05 or b.big and 0.2 or 1
                        a.x, a.y, b.x, b.y = a.x-nx*push*wa, a.y-ny*push*wa, b.x+nx*push*wb, b.y+ny*push*wb
                    end
                end
            end
            bound(a)
        end
    end
    -- 夹边以后仍以最新敌人距离计算攻击；不存在远程必须后退的死锁分支。
    for _, e in ipairs(self.entities) do if not e.dead then bound(e) end end
end
---@param f table
---@param dt number
function Battle:StepField(f,dt)
    f.t, f.life = f.t-dt, math.max(0,f.t-dt)
    if f.kind == 'blackhole' then
        f.tick = f.tick-dt
        for _, o in ipairs(self:Foes(f.src)) do
            local dx, dy = f.x-o.x, f.y-o.y
            local d = hypot(dx,dy)
            if d < f.r and d > 2 then
                local pull = math.min(d-2,(o.big and 8 or 34)*dt)
                o.x, o.y = o.x+dx/d*pull, o.y+dy/d*pull; bound(o)
            end
        end
        if f.tick <= 0 then
            f.tick = f.tick+0.5
            for _, o in ipairs(self:Foes(f.src)) do
                if hypot(o.x-f.x,o.y-f.y) <= f.r*0.6 then self:Hit(f.src,o,f.src.atk*f.mul,{noLeech=true}) end
            end
        end
        if f.t <= 0 then
            self:Splash(f.src,f.x,f.y,f.r*0.7,f.src.atk*f.boom)
            self:Effect('ring',f.x,f.y,'#c06bff',0.6,{r=26})
        end
    elseif f.kind == 'lava' then
        f.tick = f.tick-dt
        if f.tick <= 0 then
            f.tick = f.tick+0.5
            for _, o in ipairs(self:Foes(f.src)) do
                if hypot(o.x-f.x,(o.y-f.y)*1.6) <= f.r then self:Hit(f.src,o,f.src.atk*f.mul,{noCrit=true,noLeech=true,dot=true}) end
            end
        end
    elseif not f.fired and f.t <= f.max-f.warn then
        f.fired = true
        for _, o in ipairs(self:Foes(f.src)) do
            local inArea = f.kind == 'fissure' and segDist(o.x,o.y,f.x,f.y,f.x2,f.y2) <= f.w+o.r
                or f.kind == 'rift' and hypot(o.x-f.x,(o.y-f.y)*1.3) <= f.r+o.r
            if inArea then
                self:Hit(f.src,o,f.src.atk*f.mul,{noLeech=true})
                if f.kind == 'fissure' then self:Dot(o,f.src,3,f.src.atk*0.3,'burn') end
            end
        end
        self:Effect(f.kind == 'fissure' and 'line' or 'ring',f.x,f.y,f.color,0.45,{x2=f.x2,y2=f.y2,r=f.r or f.w})
    end
    if f.t <= 0 then f.done = true end
end
---@param p table
---@param dt number
function Battle:StepProjectile(p,dt)
    p.life = p.life-dt
    if p.life <= 0 then p.done = true; return end
    if p.delay > 0 then p.delay = p.delay-dt; return end
    if p.pierce then
        local x, y = p.x, p.y
        p.x, p.y = p.x+p.vx*p.speed*dt, p.y+p.vy*p.speed*dt
        for _, o in ipairs(self:Foes(p.src)) do
            if not p.hitSet[o] and segDist(o.x,o.y-3,x,y,p.x,p.y) <= o.r+3 then
                p.hitSet[o] = true; self:Hit(p.src,o,p.src.atk*p.mul); self:ProcHit(p,o)
                self:Effect('impact',o.x,o.y-3,p.color,0.25,{r=7})
            end
        end
        if p.x < -6 or p.x > W+6 or p.y < 4 or p.y > H+2 then p.done = true end
        return
    end
    if p.tgt and not p.tgt.dead then p.tx,p.ty = p.tgt.x,p.tgt.y-3 end
    local dx, dy = p.tx-p.x,p.ty-p.y
    local d, step = hypot(dx,dy), p.speed*dt
    if d > 0.01 then p.ang = math.atan(dy,dx) end
    if d > step+1 then p.x,p.y = p.x+dx/d*step,p.y+dy/d*step; return end
    p.x,p.y,p.done = p.tx,p.ty,true
    local dmg = p.src.atk*p.mul
    if p.area then
        for _, o in ipairs(self:Foes(p.src)) do
            if hypot(o.x-p.tx,o.y-p.ty-3) <= p.splash then self:Hit(p.src,o,dmg); self:ProcHit(p,o) end
        end
        self:Effect('impact',p.tx,p.ty+3,p.color,0.4,{r=p.splash})
        if p.pool then self:AddField({kind='lava',x=p.tx,y=p.ty+3,r=18,t=4,tick=0.5,src=p.src,mul=0.35}) end
    else
        local target = p.tgt
        -- 倒戈切换后，旧锁定弹不继续伤害已经成为同阵营的单位。
        if target and not target.dead and target.side ~= p.src.side then
            self:Hit(p.src,target,dmg); self:ProcHit(p,target)
            if p.killRefund and target.dead and not p.src.dead then self:Energy(p.src,p.killRefund) end
            if p.ricochet and p.ricochet > 0 then
                local other = self:NearestOther(p.src,p.tx,p.ty+3,50,{[target]=true})
                if other then self:Shoot(p.src,other,p.kind == 'rarrow' and 'rarrow' or 'arrow',{x=p.tx,y=p.ty,mul=p.mul*p.ricochet}) end
            end
            self:Effect('impact',p.tx,p.ty,p.color,0.2,{r=5})
        end
        if p.splash > 0 then self:Splash(p.src,p.tx,p.ty+3,p.splash,dmg*p.splashMul,target) end
        if p.chain and p.chain > 0 and math.random() < p.chain then
            local skip = {}; if target then skip[target] = true end
            local other = self:NearestOther(p.src,p.tx,p.ty+3,44,skip)
            if other then self:Effect('bolt',p.tx,p.ty,'#ffe14a',0.25,{x2=other.x,y2=other.y-3}); self:Hit(p.src,other,dmg*0.6) end
        end
    end
end
---@param dt number
function Battle:Tick(dt)
    self.elapsed = self.elapsed+dt
    for i=#self.effects,1,-1 do
        local fx = self.effects[i]; fx.life = fx.life-dt
        if fx.life <= 0 then table.remove(self.effects,i) end
    end
    if self.over then
        for _, e in ipairs(self.entities) do e.moving = false; e.attackAnim = math.max(0,e.attackAnim-dt); e.flash = math.max(0,e.flash-dt) end
        return
    end
    self.aura = 0
    for _, e in ipairs(self.entities) do if not e.dead and e.side == 1 and e.drAura then self.aura = math.max(self.aura,e.drAura) end end
    -- 固定本帧实体数；新召唤物从下一帧开始行动，避免动态遍历无限生长。
    local count = #self.entities
    for i=1,count do self:StepEntity(self.entities[i],dt) end
    self:Separate(dt)
    for i=#self.fields,1,-1 do
        local field = self.fields[i]; self:StepField(field,dt)
        if field.done then table.remove(self.fields,i) end
    end
    local pn = #self.projectiles
    for i=1,pn do self:StepProjectile(self.projectiles[i],dt) end
    for i=#self.projectiles,1,-1 do if self.projectiles[i].done then table.remove(self.projectiles,i) end end
    local pa, ea = false, false
    for i=#self.entities,1,-1 do
        local e = self.entities[i]
        if e.dead then
            e.deadT = e.deadT+dt
            if e.deadT > 1.2 and (e.minion or e.originalSide == 2) then table.remove(self.entities,i) end
        elseif e.originalSide == 1 then pa = true
        elseif e.side == 2 and e.charmed <= 0 then ea = true end
    end
    if not ea or not pa or self.elapsed >= 75 then
        self.over = true
        self.result = not ea and pa and 'win' or 'lose' -- 原版超时一律败；同归于尽也败。
        self:Effect('phase',128,62,self.result == 'win' and '#8fe07a' or '#d8433a',1.2,
            {text=self.result == 'win' and '胜利' or self.elapsed >= 75 and '战斗超时' or '战败'})
        print(string.format('[军团战斗] 结束：结果=%s 用时=%.2f秒 实体数=%d',self.result == 'win' and '胜利' or '战败',self.elapsed,#self.entities))
    end
end

--- 外部固定 1/60 调用；其他 dt 也用累积器拆成固定步。暂停/倍速不要写进本模块。
---@param dt number
function Battle:Update(dt)
    if type(dt) ~= 'number' or dt <= 0 or dt ~= dt then return end
    self.accumulator = math.min(self.accumulator+math.min(dt,0.5),0.5)
    local steps = math.min(30,math.floor((self.accumulator+0.0000001)/STEP))
    for _=1,steps do self:Tick(STEP) end
    self.accumulator = math.max(0,self.accumulator-steps*STEP)
end

return Battle
