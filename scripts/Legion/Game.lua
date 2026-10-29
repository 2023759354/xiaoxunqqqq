-- 准备阶段、拉杆结算、养成进度与本地存档的数据模型，运算全部在 Lua 内存中进行。
-- 渲染模块管理动画；战斗模块使用独立临时实体，不修改库存单位。
local Data = require("Legion.Data")

---@class LegionAffix
---@field id string
---@field v number
---@field q number 词缀等级 1..4

---@class LegionUnit
---@field id number
---@field cls string
---@field star number 1..3
---@field q number 品质 1..5
---@field pts number 累计经验，升星阈值为 0、4、16
---@field affix LegionAffix
---@field branch string|false
---@field awakenReady boolean
---@field pop number

---@class LegionProgress
---@field version number
---@field chapters table[]
---@field meta table
---@field squad string[]
---@field tutorialDone boolean

---@class LegionRun
---@field ch number
---@field diff number
---@field wave number
---@field maxWave number
---@field lives number
---@field maxLives number
---@field gold number
---@field luck number
---@field luckMax number
---@field freeSpins number
---@field paidSpins number
---@field mx table<string, number>
---@field soulPend number
---@field soulWaves number
---@field settled boolean
---@field form (LegionUnit|false)[]
---@field bench (LegionUnit|false)[]
---@field squad string[]
---@field symW table<string, number>
---@field nextId number
---@field phase string
---@field slot table
---@field stats table
---@field pendingAwaken LegionUnit[]
---@field lineup table|false
---@field seen table<string, boolean>
---@field tutorial boolean
---@field rig table[]
---@field tutorialGift boolean
---@field battle table|false
---@field time number
---@field speed number
---@field sel LegionUnit|false

---@class LegionGame
---@field g LegionRun
---@field progress LegionProgress
---@field savePath string
---@field saveError string|false
local Game = {}
Game.__index = Game

local function Round(n) return math.floor(n + 0.5) end
local function Clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
local function Num(n, fallback)
    local v = tonumber(n)
    if not v or v ~= v or v == math.huge or v == -math.huge then return fallback or 0 end
    return v
end
local function Pick(a) return a[math.random(1, #a)] end
---@param t table
---@return table
local function Copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and Copy(v) or v end
    return out
end

---@param raw table|nil
---@return LegionProgress
local function Normalize(raw)
    local p = type(raw) == "table" and raw or {}
    p.version = 2
    p.chapters = type(p.chapters) == "table" and p.chapters or {}
    for ch, c in ipairs(Data.CHAPTERS) do
        local s = type(p.chapters[ch]) == "table" and p.chapters[ch] or {}
        s.best = type(s.best) == "table" and s.best or {}
        s.cleared = math.floor(Num(s.cleared)) & 15
        s.unlock = Clamp(math.floor(Num(s.unlock, 1)), 1, 4)
        for d, def in ipairs(c.diffs) do
            s.best[d] = Clamp(math.floor(Num(s.best[d])), 0, def.waves)
            if s.best[d] >= def.waves then s.cleared = s.cleared | (1 << (d - 1)) end
            if (s.cleared & (1 << (d - 1))) ~= 0 then s.unlock = math.min(4, math.max(s.unlock, d + 1)) end
        end
        p.chapters[ch] = s
    end
    local fresh = type(p.meta) ~= "table"
    p.meta = type(p.meta) == "table" and p.meta or {s=0,l={},v=2}
    p.meta.s = math.max(0, math.floor(Num(p.meta.s)))
    p.meta.l = type(p.meta.l) == "table" and p.meta.l or {}
    for _, u in ipairs(Data.UPG) do p.meta.l[u.id] = Clamp(math.floor(Num(p.meta.l[u.id])), 0, u.max) end
    if fresh then
        for ch, c in ipairs(Data.CHAPTERS) do
            for d, def in ipairs(c.diffs) do
                local s = p.chapters[ch]
                local per = Data.SoulPerWave(ch, d)
                local cleared = (s.cleared & (1 << (d - 1))) ~= 0
                p.meta.s = p.meta.s + (cleared and def.waves or s.best[d]) * per
                if cleared then p.meta.s = p.meta.s + Round(per * def.waves * (Data.SOUL_CLEAR + Data.SOUL_FIRST)) end
            end
        end
    elseif Num(p.meta.v) < 2 and p.meta.l.cheap >= 1 then
        p.meta.l.cheap = 1
        p.meta.s = p.meta.s + 150
    end
    p.meta.v = 2
    p.squad = Data.ValidSquad(p.squad)
    p.tutorialDone = p.tutorialDone == true
    return p
end

---@return table|nil
function Game.Load()
    if not File or not cjson then return nil end
    if not fileSystem:FileExists("legion-save.json") then return nil end
    local ok, data = pcall(function()
        local f = File("legion-save.json", FILE_READ)
        if not f or not f:IsOpen() then if f then f:Dispose() end return nil end
        local text = f:ReadString()
        f:Close()
        f:Dispose()
        local decoded = cjson.decode(text)
        return type(decoded) == "table" and decoded or nil
    end)
    if not ok then print("[拉杆军团] 读取存档失败：" .. tostring(data)) return nil end
    return data
end

---@param progress table|nil
---@return LegionGame
function Game.New(progress)
    local self = setmetatable({}, Game)
    self:Init(progress)
    return self
end

---@param progress table|nil
function Game:Init(progress)
    self.savePath = "legion-save.json"
    self.saveError = false
    self.progress = Normalize(progress or Game.Load())
    self.g = self:MakeRun(1, 1, self.progress.squad)
    print("[拉杆军团] 模型初始化完成，已加载完整七兵种数据；军魂=" .. self.progress.meta.s)
end

---@return boolean, string|nil
function Game:Save()
    if not File or not cjson then self.saveError = "File/cjson 存档接口不可用" return false, self.saveError end
    local ok, err = pcall(function()
        local encoded = cjson.encode(self.progress)
        local f = File(self.savePath, FILE_WRITE)
        if not f or not f:IsOpen() then if f then f:Dispose() end error("无法打开本地存档") end
        f:WriteString(encoded)
        f:Close()
        f:Dispose()
    end)
    if not ok then self.saveError = tostring(err) print("[拉杆军团] 存档失败：" .. self.saveError) return false, self.saveError end
    self.saveError = false
    return true
end

---@param ch number
---@return boolean
function Game:ChapterOpen(ch)
    if not Data.CHAPTERS[ch] then return false end
    return ch == 1 or (self.progress.chapters[ch - 1].cleared & 1) ~= 0
end

---@param ch number
---@param diff number
---@return boolean
function Game:DifficultyOpen(ch, diff)
    return self:ChapterOpen(ch) and Data.CHAPTERS[ch].diffs[diff] ~= nil and diff <= self.progress.chapters[ch].unlock
end

---@param id string
---@return number
function Game:UpgradeLevel(id) return self.progress.meta.l[id] or 0 end

---@return table<string, number>
function Game:MetaFx()
    local out = Copy(Data.MX_NONE)
    for _, u in ipairs(Data.UPG) do out[u.id] = self:UpgradeLevel(u.id) * (u.scale or 1) end
    return out
end

---@return table[]
function Game:Upgrades()
    local out = {}
    for _, u in ipairs(Data.UPG) do
        local level = self:UpgradeLevel(u.id)
        local cost = u.cost[level + 1] or 0
        out[#out+1] = {definition=u,id=u.id,name=u.name,tab=u.tab,icon=u.icon,note=u.note,level=level,max=u.max,cost=cost,canBuy=level<u.max and self.progress.meta.s>=cost,text=u.txt(level)}
    end
    return out
end

---@param id string
---@return boolean, table|string
function Game:BuyUpgrade(id)
    for _, u in ipairs(Data.UPG) do
        if u.id == id then
            local level = self:UpgradeLevel(id)
            if level >= u.max then return false, "已经满级" end
            local cost = u.cost[level + 1]
            if self.progress.meta.s < cost then return false, "军魂不足" end
            self.progress.meta.s = self.progress.meta.s - cost
            self.progress.meta.l[id] = level + 1
            self:Save()
            return true, {id=id,level=level+1,cost=cost}
        end
    end
    return false, "强化不存在"
end

---@return number
function Game:ResetUpgrades()
    local refund = 0
    for _, u in ipairs(Data.UPG) do
        for l = 1, self:UpgradeLevel(u.id) do refund = refund + u.cost[l] end
        self.progress.meta.l[u.id] = 0
    end
    self.progress.meta.s = self.progress.meta.s + refund
    self:Save()
    return refund
end

---@param ch number
---@param diff number
---@param squad string[]
---@return LegionRun
function Game:MakeRun(ch, diff, squad)
    local def, mx = Data.CHAPTERS[ch].diffs[diff], self:MetaFx()
    local g = {
        ch=ch,diff=diff,wave=1,maxWave=def.waves,lives=def.lives,maxLives=def.lives,
        gold=Data.START_GOLD+(def.gold or 0)+mx.gold,luck=0,luckMax=3+mx.luck,freeSpins=mx.free,paidSpins=0,mx=mx,
        soulPend=0,soulWaves=0,settled=false,form={},bench={},squad=Data.ValidSquad(squad),symW={},nextId=1,phase="prep",
        slot={grid=Data.SquadGrid(Data.ValidSquad(squad)),wins={},jack=false,spinning=false,show={}},
        stats={spins=0,summoned=0,maxStar=1,maxQ=1,awakened=0,promoted=0,jackpots=0},pendingAwaken={},lineup=false,seen={},
        tutorial=false,rig={},tutorialGift=false,battle=false,time=0,speed=1,sel=false,
    }
    for i=1,Data.FORM_N do g.form[i]=false end
    for i=1,Data.BENCH_N do g.bench[i]=false end
    g.symW = Data.SquadWeights(g.squad)
    return g
end

---@param ch number|nil
---@param diff number|nil
---@param squad table|nil
---@return LegionRun|false, string|nil
function Game:NewRun(ch, diff, squad)
    local c, d = math.floor(Num(ch,1)), math.floor(Num(diff,1))
    if not self:DifficultyOpen(c,d) then return false, "章节或难度尚未解锁" end
    if self.g and not self.g.settled and not self.g.tutorial then self:SettleRun("abandon",false) end
    local sq = Data.ValidSquad(squad or self.progress.squad)
    self.progress.squad = sq
    self.g = self:MakeRun(c,d,sq)
    self:Save()
    print("[拉杆军团] 开始新局，章节=" .. c .. " 难度=" .. d)
    return self.g
end

---@return LegionRun
function Game:NewTutorial()
    if self.g and not self.g.settled and not self.g.tutorial then self:SettleRun("abandon",false) end
    self.g = self:MakeRun(1,1,Data.DEFAULT_SQUAD)
    local g = self.g
    g.tutorial=true; g.maxWave=1; g.gold=12; g.mx=Copy(Data.MX_NONE); g.freeSpins=0; g.luckMax=3
    g.lineup={wave=1,list={{type="slime",x=160,y=52,elite=false},{type="slime",x=160,y=92,elite=false}}}
    g.rig={{"A","M","A","W","W","W","M","A","M"},{"W","W","W","A","M","A","M","A","M"}}
    return g
end

---@return table|false, string|nil
function Game:TutorialGift()
    if not self.g.tutorial or self.g.tutorialGift then return false,"教程礼物已领取或不在教程" end
    self.g.tutorialGift=true
    return self:Summon("archer",3,1)
end

---@param index number
---@return LegionUnit|false
function Game:GetSlot(index)
    if index~=math.floor(index) or index<1 or index>20 then return false end
    return index<=12 and self.g.form[index] or self.g.bench[index-12] or false
end

---@param index number
---@param unit LegionUnit|false
function Game:SetSlot(index, unit)
    if index<=12 then self.g.form[index]=unit else self.g.bench[index-12]=unit end
end

---@return LegionUnit[]
function Game:AllUnits()
    local out = {}
    for i=1,20 do local u=self:GetSlot(i); if u then out[#out+1]=u end end
    return out
end

---@param u LegionUnit
---@return number|false
function Game:FindSlot(u)
    for i=1,20 do if self:GetSlot(i)==u then return i end end
    return false
end

---@param u LegionUnit
---@return table
function Game:Stats(u)
    local c = Data.CLASSES[u.cls]
    local b = u.branch and Data.BRANCHES[u.branch] or {}
    local m, q, a = b.mods or {}, Data.QUAL[u.q or 1], u.affix or {id="atk",v=0,q=1}
    local scale=(Data.STAR_MULT --[[@as number[] ]])[u.star]*q.base*(u.branch and q.awaken or 1)
    local hp=c.hp*scale*(1+(m.hp or 0))
    local atk=c.atk*scale*(1+(m.atk or 0))
    local cd=c.cd/(1+(m.spd or 0))
    local crit=0.05+(m.crit or 0)
    local leech=m.leech or 0
    if a.id=="atk" then atk=atk*(1+a.v/100) end
    if a.id=="hp" then hp=hp*(1+a.v/100) end
    if a.id=="spd" then cd=cd/(1+a.v/100) end
    if a.id=="crit" then crit=crit+a.v/100 end
    if a.id=="leech" then leech=leech+a.v/100 end
    local mx=self.g.mx or Data.MX_NONE
    local fx=Copy(c.fx or {})
    for k,v in pairs(b.fx or {}) do fx[k]=v end
    return {hp=Round(hp*(1+mx.hp)),atk=Round(atk*(1+mx.atk)),cd=cd,crit=crit,leech=leech,range=c.range+(m.range or 0),
        speed=c.speed*(1+(m.move or 0)),r=c.r,splash=c.splash or 0,proj=b.proj or c.proj or false,fx=fx,
        skill=b.skill or Data.CLASS_SKILL[u.cls],dr=m.dr or 0,berserk=not not m.berserk,burnOnHit=not not m.burn,extra=m.extra or 0,
        critMul=m.critMul or 2,slowHit=m.slowHit or 0,chainHit=m.chainHit or 0,fullEnergy=not not m.fullEnergy,
        sprite=b.sprite or (u.branch and Data.SPR[u.branch] and u.branch) or c.sprite,branch=u.branch,q=u.q,star=u.star,cls=u.cls,sup=Data.IsSup(u)}
end

---@param q number
---@return LegionAffix
function Game:RollAffix(q)
    local a=Pick(Data.AFFIXES)
    local f=Data.QUAL[q or 1].affix
    local r=f+math.random()*(1-f)
    return {id=a.id,v=Round(a.min+r*(a.max-a.min)),q=r<0.4 and 1 or r<0.7 and 2 or r<0.9 and 3 or 4}
end

---@param a LegionAffix
---@param q number
---@return LegionAffix
function Game:UpgradeAffix(a,q)
    for _,def in ipairs(Data.AFFIXES) do
        if def.id==a.id then
            local span=def.max-def.min
            local old=span>0 and (a.v-def.min)/span or 1
            local f=Data.QUAL[q].affix
            local r=math.max(old,f+math.random()*(1-f))
            return {id=a.id,v=Round(def.min+r*span),q=r<0.4 and 1 or r<0.7 and 2 or r<0.9 and 3 or 4}
        end
    end
    return self:RollAffix(q)
end

function Game:RefreshPending()
    local pending={}
    for _,u in ipairs(self:AllUnits()) do if u.awakenReady and not u.branch then pending[#pending+1]=u end end
    self.g.pendingAwaken=pending
end

---@param src LegionUnit
---@param dst LegionUnit
---@return boolean
function Game:CanAbsorb(src,dst)
    -- 手动吸收保持原版条件：接收者保留职业和品质，跨职业获得一半经验。
    return src~=dst and not Data.IsSup(src) and not dst.branch and not dst.awakenReady and dst.star<3
end

---@param src LegionUnit
---@param dst LegionUnit
---@return table
function Game:Absorb(src,dst)
    local from=self:FindSlot(src)
    if from then self:SetSlot(from,false) end
    local before=dst.star
    local gain=src.cls==dst.cls and 2+src.pts or math.ceil((2+src.pts)/2)
    dst.pts=dst.pts+gain
    while dst.star<3 and dst.pts>=Data.STAR_PTS[dst.star+1] do dst.star=dst.star+1 end
    if dst.star==3 then dst.pts=16; dst.awakenReady=not dst.branch end
    self.g.stats.maxStar=math.max(self.g.stats.maxStar,dst.star)
    self:RefreshPending()
    return {kind="absorb",gain=gain,up=dst.star>before,ready=dst.awakenReady,into=dst,unit=dst,source=src}
end

---@param src number
---@param dst number
---@return boolean, table|string
function Game:Move(src,dst)
    if self.g.phase~="prep" or self.g.slot.spinning then return false,"只能在准备阶段调整阵容" end
    if src==dst then return false,"请选择另一个格子" end
    if src~=math.floor(src) or dst~=math.floor(dst) or src<1 or src>20 or dst<1 or dst>20 then return false,"格子编号无效" end
    local a,b=self:GetSlot(src),self:GetSlot(dst)
    if not a then return false,"起始格子没有单位" end
    if b and self:CanAbsorb(a,b) then return true,self:Absorb(a,b) end
    self:SetSlot(src,b); self:SetSlot(dst,a)
    self:RefreshPending()
    return true,{kind=b and "swap" or "move",source=src,target=dst,unit=a}
end

---@param index number
---@return boolean, table|string
function Game:Promote(index)
    local u=self:GetSlot(index)
    if self.g.phase~="prep" then return false,"只能在准备阶段晋升" end
    if not u or u.branch or u.star~=3 or u.q>=Data.Q_MAX then return false,"需要未转职的三星单位，最高晋升到传说" end
    u.q=u.q+1; u.star=1; u.pts=0; u.awakenReady=false; u.affix=self:UpgradeAffix(u.affix,u.q)
    self.g.stats.promoted=self.g.stats.promoted+1
    self.g.stats.maxQ=math.max(self.g.stats.maxQ,u.q)
    self:RefreshPending()
    return true,{kind="promote",unit=u,q=u.q}
end

---@param index number
---@param branch string
---@return boolean, table|string
function Game:Awaken(index,branch)
    local u,b=self:GetSlot(index),Data.BRANCHES[branch]
    if self.g.phase~="prep" then return false,"只能在准备阶段转职" end
    if not u or u.branch or u.star~=3 then return false,"需要未转职的三星单位" end
    if not b or b.sup or b.cls~=u.cls or b.q~=u.q then return false,"这条转职路线不属于该兵种或品质" end
    u.branch=branch; u.awakenReady=false
    self.g.stats.awakened=self.g.stats.awakened+1
    self:RefreshPending()
    return true,{kind="awaken",unit=u,branch=branch}
end

---@param u LegionUnit
---@return number|false
function Game:AutoPlace(u)
    local cols=Data.CLASSES[u.cls].proj and {2,1,3,4} or {4,3,2,1}
    for _,c in ipairs(cols) do
        for _,r in ipairs({2,1,3}) do
            local i=(r-1)*4+c
            if not self.g.form[i] then self.g.form[i]=u return i end
        end
    end
    for i=1,8 do if not self.g.bench[i] then self.g.bench[i]=u return i+12 end end
    return false
end

---@param v LegionUnit
---@return table
function Game:FeedAway(v)
    -- 满编自动吸收保留原版跨职业、跨品质规则，跨职业获得一半经验。
    local cands={}
    for _,x in ipairs(self:AllUnits()) do
        if x~=v and not Data.IsSup(v) and not x.branch and not x.awakenReady and x.star<3 then cands[#cands+1]=x end
    end
    table.sort(cands,function(a,b)
        local sameA,sameB=a.cls==v.cls and 1 or 0,b.cls==v.cls and 1 or 0
        if sameA~=sameB then return sameA>sameB end
        if a.q~=b.q then return a.q>b.q end
        if a.pts~=b.pts then return a.pts>b.pts end
        return a.id<b.id
    end)
    if #cands>0 then return self:Absorb(v,cands[1]) end
    local slot=self:FindSlot(v); if slot then self:SetSlot(slot,false) end
    self.g.gold=self.g.gold+2
    self:RefreshPending()
    return {kind="sold",sold=true,gold=2}
end

---@param cls string
---@param star number
---@param q number
---@return table|false, string|nil
function Game:Summon(cls,star,q)
    if not Data.CLASSES[cls] then return false,"兵种无效" end
    local s,quality=Clamp(math.floor(star),1,3),Clamp(math.floor(q or 1),1,4)
    ---@type LegionUnit
    local u={id=self.g.nextId,cls=cls,star=s,q=quality,pts=Data.STAR_PTS[s] or 0,affix=self:RollAffix(quality),pop=0.5,branch=false,awakenReady=s==3}
    self.g.nextId=self.g.nextId+1
    self.g.stats.summoned=self.g.stats.summoned+1
    self.g.stats.maxStar=math.max(self.g.stats.maxStar,s); self.g.stats.maxQ=math.max(self.g.stats.maxQ,quality)
    local slot=self:AutoPlace(u)
    local result={nu=u,unit=u,slot=slot,placed=not not slot}
    if not slot then
        local victims={}
        for _,x in ipairs(self:AllUnits()) do
            if not x.branch and not x.awakenReady and x.q<quality and (s>=3 or x.star<=s) then victims[#victims+1]=x end
        end
        table.sort(victims,function(a,b) if a.q~=b.q then return a.q<b.q end if a.pts~=b.pts then return a.pts<b.pts end return a.id<b.id end)
        if #victims>0 then
            local v=victims[1]; local into=self:FindSlot(v)
            if not into then return false,"替换目标已离开阵容" end
            self:SetSlot(into,u); result.displaced=v; result.slot=into; result.placed=true
            for k,val in pairs(self:FeedAway(v)) do result[k]=val end
        else
            for k,val in pairs(self:FeedAway(u)) do result[k]=val end
        end
    end
    self:RefreshPending()
    return result
end

---@param cls string
---@return boolean
function Game:HasSuper(cls)
    for _,u in ipairs(self:AllUnits()) do if u.cls==cls and Data.IsSup(u) then return true end end
    return false
end

---@param cls string
---@return table
function Game:SummonSuper(cls)
    ---@type LegionUnit
    local u={id=self.g.nextId,cls=cls,star=3,q=5,pts=16,affix=self:RollAffix(5),pop=0.5,branch=Data.SUPER_OF[cls] or false,awakenReady=false}
    self.g.nextId=self.g.nextId+1
    self.g.stats.summoned=self.g.stats.summoned+1; self.g.stats.maxStar=3; self.g.stats.maxQ=5
    local slot=self:AutoPlace(u)
    local result={nu=u,unit=u,slot=slot,placed=true,super=true}
    if not slot then
        local victims={}
        for _,x in ipairs(self:AllUnits()) do if not Data.IsSup(x) then victims[#victims+1]=x end end
        table.sort(victims,function(a,b)
            if not not a.branch~=not not b.branch then return not a.branch end
            if a.q~=b.q then return a.q<b.q end
            if a.pts~=b.pts then return a.pts<b.pts end
            return a.id<b.id
        end)
        if #victims==0 then return {nu=u,unit=u,placed=false,sold=true} end
        local v=victims[1]; local into=self:FindSlot(v)
        if not into then return {nu=u,unit=u,placed=false,error="替换目标已离开阵容"} end
        self:SetSlot(into,u); result.slot=into; result.displaced=v
        for k,val in pairs(self:FeedAway(v)) do result[k]=val end
    end
    self:RefreshPending()
    return result
end

---@param sym string
---@return table
function Game:ApplyJackpot(sym)
    self.g.stats.jackpots=self.g.stats.jackpots+1
    local free={}
    for _,cls in ipairs(self.g.squad) do if not self:HasSuper(cls) then free[#free+1]=cls end end
    local want=sym=="S" and Pick(#free>0 and free or self.g.squad) or Data.SYM_CLASS[sym]
    if not self:HasSuper(want) then return self:SummonSuper(want) end
    if #free>0 then local r=self:SummonSuper(Pick(free)); r.redirect=want return r end
    local r,err=self:Summon(want,3,4)
    if not r then return {error=err,fallback=true} end
    r.fallback=true
    return r
end

---@return number
function Game:SpinCost() return Data.SPIN_COST end
---@return number
function Game:StampGoal() return (Data.CHEAP_EVERY --[[@as number[] ]])[self.g.mx.cheap+1] or 0 end
---@return number
function Game:InterestCap() return 3+self.g.mx.interest end

---@param min number|nil
---@return number
function Game:RollQuality(min)
    local floorQ=min or 1
    local total=0
    for q=floorQ,4 do total=total+Data.Q_ODDS[q]+Data.Q_SHIFT[q]*self.g.mx.qual end
    local target=math.random()*total
    local partial=0
    for q=floorQ,4 do partial=partial+Data.Q_ODDS[q]+Data.Q_SHIFT[q]*self.g.mx.qual; if target<partial then return q end end
    return floorQ
end

---@return string
function Game:RollSymbol()
    local weights=Copy(self.g.symW)
    weights.S=weights.S+self.g.luck*Data.LUCK_BONUS+self.g.mx.star
    local total=0; for _,v in pairs(weights) do total=total+v end
    local target=math.random()*total
    local partial=0
    for _,cls in ipairs(self.g.squad) do
        local sym=Data.CLASS_SYM[cls]
        partial=partial+weights[sym]
        if target<partial then return sym end
    end
    return "S"
end

---@param grid string[]
---@return table[]
function Game.EvalGrid(grid)
    local wins={}
    for li,line in ipairs(Data.LINES) do
        local sym=false; local match=true
        for _,i in ipairs(line) do
            if grid[i]~="S" then if sym and sym~=grid[i] then match=false break end sym=grid[i] end
        end
        if match then wins[#wins+1]={li=li,sym=sym or "S"} end
    end
    return wins
end

---@param grid string[]
---@return string|false
function Game.JackpotSym(grid)
    ---@type string|false
    local sym=false
    for _,s in ipairs(grid) do if s~="S" then if sym and sym~=s then return false end sym=s end end
    return sym or "S"
end

---@param rig string[]|nil 可选固定九格，仅供确定性测试，正常界面不传入。
---@return table|false, string|nil
function Game:Spin(rig)
    if self.g.phase~="prep" or self.g.slot.spinning then return false,"只能在准备阶段拉杆" end
    if self.g.freeSpins<=0 and self.g.gold<self:SpinCost() then return false,"金币不足，开战赢取更多金币" end
    local grid={}
    local specified=rig or (#self.g.rig>0 and table.remove(self.g.rig,1))
    if specified then
        if #specified~=9 then return false,"转轴必须有九格" end
        for i=1,9 do if specified[i]~="S" and not self.g.symW[specified[i]] then return false,"转轴包含未选兵种" end grid[i]=specified[i] end
    else for i=1,9 do grid[i]=self:RollSymbol() end end
    local free=self.g.freeSpins>0
    local stamped=false
    if free then self.g.freeSpins=self.g.freeSpins-1
    else
        self.g.gold=self.g.gold-self:SpinCost()
        local goal=self:StampGoal()
        if goal>0 then
            self.g.paidSpins=self.g.paidSpins+1
            if self.g.paidSpins>=goal then self.g.paidSpins=0; self.g.freeSpins=self.g.freeSpins+1; stamped=true end
        end
    end
    self.g.stats.spins=self.g.stats.spins+1
    local jack=Game.JackpotSym(grid)
    local wins=Game.EvalGrid(grid)
    ---@type LegionUnit[]
    local units = {}
    ---@type table[]
    local rewards = {}
    if jack then
        local r=self:ApplyJackpot(jack); rewards[1]=r; units[1]=r.nu
    else
        for _,w in ipairs(wins) do
            local r=w.sym=="S" and self:Summon(Pick(self.g.squad),2,self:RollQuality(2)) or self:Summon(Data.SYM_CLASS[w.sym],1,self:RollQuality(1))
            if r then rewards[#rewards+1]=r; units[#units+1]=r.nu end
        end
    end
    self.g.luck=(jack or #wins>0) and 0 or math.min(self.g.luckMax,self.g.luck+1)
    self.g.slot.grid=grid; self.g.slot.wins=wins; self.g.slot.jack=jack
    self.g.slot.show=rewards
    local jackpotUnit=units[1]
    local summary=jack and ("九格大奖！" .. (jackpotUnit and Data.FullName(jackpotUnit) or "召唤目标无效")) or (#wins>0 and ("连线 " .. #wins .. " 条，召唤 " .. #units .. " 个单位") or ("未中奖，幸运 +1（" .. self.g.luck .. "/" .. self.g.luckMax .. "）"))
    return {grid=grid,wins=wins,jackpot=jack,jack=jack,units=units,rewards=rewards,summary=summary,free=free,stamped=stamped,cost=free and 0 or self:SpinCost(),luck=self.g.luck}
end

---@param w number|nil
---@return string[]
function Game:WaveDef(w)
    local wave=w or self.g.wave
    local chapter=Data.CHAPTERS[self.g.ch]
    return Copy(wave>=self.g.maxWave and chapter.boss(self.g.maxWave) or chapter.waves[wave])
end
---@param w number
---@return number
function Game:WaveMult(w) return Data.WaveMult(w) end

---@param w number|nil
---@return string[]
function Game:WaveList(w)
    local wave=w or self.g.wave
    local list=self:WaveDef(wave)
    local d=Data.CHAPTERS[self.g.ch].diffs[self.g.diff]
    local n=wave>=6 and d.extra or wave>=3 and math.min(1,d.extra) or 0
    local pool={}
    for _,t in ipairs(list) do if not Data.ENEMIES[t].big then pool[#pool+1]=t end end
    for i=1,n do list[#list+1]=pool[(i-1)%#pool+1] end
    return list
end

---@return table[]
function Game:CurrentLineup()
    if self.g.lineup and self.g.lineup.wave==self.g.wave then return self.g.lineup.list end
    local list=self:WaveList(self.g.wave)
    local out,used={},{}
    for _,t in ipairs(list) do if Data.ENEMIES[t].big then used["3:2"]=true; used["4:2"]=true; out[#out+1]={type=t,x=222,y=72,elite=false} break end end
    local function Place(t,cols)
        for _,c in ipairs(cols) do for _,r in ipairs({2,1,3}) do
            local key=c .. ":" .. r
            if not used[key] then used[key]=true; out[#out+1]={type=t,x=152+(c-1)*28,y=34+(r-1)*38,elite=false} return end
        end end
    end
    for _,t in ipairs(list) do if not Data.ENEMIES[t].big and not Data.ENEMIES[t].proj then Place(t,{1,2,3,4}) end end
    for _,t in ipairs(list) do if not Data.ENEMIES[t].big and Data.ENEMIES[t].proj then Place(t,{4,3,2,1}) end end
    local d=Data.CHAPTERS[self.g.ch].diffs[self.g.diff]
    if d.elite>0 and self.g.wave>=2 then for _,e in ipairs(out) do if not Data.ENEMIES[e.type].big and math.random()<d.elite then e.elite=true end end end
    self.g.lineup={wave=self.g.wave,list=out}
    return out
end

---@return boolean, string|nil
function Game:CanStart()
    if self.g.phase~="prep" or self.g.slot.spinning then return false,"请等待准备阶段" end
    local any=false
    for _,u in ipairs(self.g.form) do if u then any=true break end end
    if not any then return false,"阵地没有单位，请先拉杆或从备战席移入单位" end
    for _,u in ipairs(self:AllUnits()) do if u.awakenReady and not u.branch then return false,"请先为三星单位选择转职或晋升" end end
    return true
end

---@return boolean, string|nil
function Game:Start()
    local ok,err=self:CanStart()
    if not ok then return false,err end
    self.g.phase="battle"; self.g.sel=false; self.g.slot.show={}
    for _,e in ipairs(self:CurrentLineup()) do self.g.seen[e.type]=true end
    return true
end

---@param kind string
---@param first boolean|nil
---@return table|false
function Game:SettleRun(kind,first)
    if self.g.tutorial or self.g.settled then return false end
    self.g.settled=true
    local per=Data.SoulPerWave(self.g.ch,self.g.diff)
    local r={kind=kind,waves=self.g.soulWaves,per=per,base=self.g.soulPend,bonus=0,first=0,total=self.g.soulPend}
    if kind=="win" then r.bonus=Round(per*self.g.maxWave*Data.SOUL_CLEAR); r.first=first and Round(per*self.g.maxWave*Data.SOUL_FIRST) or 0; r.total=r.base+r.bonus+r.first
    elseif kind=="abandon" then r.total=math.floor(r.base*Data.SOUL_ABANDON) end
    self.progress.meta.s=self.progress.meta.s+r.total
    self:Save()
    return r
end

---@return table|false
function Game:Abandon()
    local r=self:SettleRun("abandon",false)
    self.g.phase="gameover"
    return r
end

---@param win boolean
---@return table|false, string|nil
function Game:FinishBattle(win)
    if self.g.phase~="battle" then return false,"本波战斗尚未开始或已经结算" end
    local wave=self.g.wave
    local interest=math.min(self:InterestCap(),math.floor(self.g.gold/10))
    local base=win and 5+wave or 5
    local result={win=win,base=base,interest=interest,wave=wave,news={},soulGain=0,soul=false}
    self.g.gold=self.g.gold+base+interest
    self.g.battle=false
    if win then
        if wave>=self.g.maxWave then self.g.phase="victory" else self.g.wave=wave+1; self.g.phase="prep" end
    else self.g.lives=self.g.lives-1; self.g.phase=self.g.lives<=0 and "gameover" or "prep" end
    if not self.g.tutorial then
        local s=self.progress.chapters[self.g.ch]
        if win then self.g.soulPend=self.g.soulPend+Data.SoulPerWave(self.g.ch,self.g.diff); self.g.soulWaves=self.g.soulWaves+1; result.soulGain=Data.SoulPerWave(self.g.ch,self.g.diff) end
        local best=win and wave or wave-1
        s.best[self.g.diff]=math.max(s.best[self.g.diff],best)
        if self.g.phase=="victory" then
            local first=(s.cleared & (1 << (self.g.diff-1)))==0
            local nextWasOpen=self:ChapterOpen(self.g.ch+1)
            s.cleared=s.cleared | (1 << (self.g.diff-1))
            if self.g.diff<4 and s.unlock<self.g.diff+1 then s.unlock=self.g.diff+1; result.news[#result.news+1]={c=self.g.ch,d=self.g.diff+1} end
            if self.g.ch<3 and not nextWasOpen and self:ChapterOpen(self.g.ch+1) then result.news[#result.news+1]={c=self.g.ch+1,d=1} end
            result.soul=self:SettleRun("win",first)
        elseif self.g.phase=="gameover" then result.soul=self:SettleRun("lose",false) end
        self:Save()
    end
    result.phase=self.g.phase
    print("[拉杆军团] 战斗结算，波次=" .. wave .. " 胜利=" .. tostring(win) .. " 阶段=" .. self.g.phase)
    return result
end

return Game
