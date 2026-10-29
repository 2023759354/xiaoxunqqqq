-- ============================================================================
-- 第十四次更新：强度调整（转职路线 / 敌人 / 首领）
-- 依据：无界面逐帧模拟。每条路线和固定队友组成队伍，对 5 个章节的标准波次求「敌方强度要缩放到多少才打平」，
-- 和同品质的其他路线比较；敌人和首领用固定的参考队伍（5 个史诗转职）做同样的测试。
-- 详细数字见更新说明「第十四次更新」。
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")

-- ---------------------------------------------------------------------------
-- 敌人 / 首领
-- ---------------------------------------------------------------------------
local function E(k, f) if ENEMIES[k] then f(ENEMIES[k]) end end
-- 第二章：中段波次比后面几章还难（第 9 波比第十章第 9 波还难），而首领波反而比前两波容易
E('obsidian', function(e) e.fx = e.fx or {}; e.fx.armor = 0.4; if e.desc then e.desc = e.desc:gsub('%-50%%', '-40%%') end end)      -- 黑曜卫士：减伤 50% → 40%
E('ashblade', function(e) e.atk = 13 end)                              -- 灰烬刺客：攻击 14 → 13
E('colossus', function(e) e.hp = 2650; e.atk = 33 end)                 -- 熔核巨像：生命 2400 → 2650，攻击 30 → 33，首领波重新成为本章最难的一波
-- 熔炉祭司「熔铸护盾」：每次给所有敌人 25% 护盾 → 18%（第二章的高压主要来自护盾叠在黑曜甲上）
SKILLS.forge.desc = '所有敌人获得 18% 最大生命的护盾'
EXT_SKILLS2.forge = function(B, e, t)
    for o in js.of(alliesOf(B, e)) do o.shield = math.min(o.maxHp * 0.5, (o.shield or 0) + o.maxHp * 0.18); FX.ring(o.x, o.y, 9, '#ffb04a') end
    FX.ring(e.x, e.y, 20, '#ffb04a')
end
-- 第三章：镜甲守卫比同章其他敌人强一截
E('mirrorguard', function(e) e.hp = 190; e.atk = 13; e.fx = e.fx or {}; e.fx.mirrorArmor = 0.25; if e.desc then e.desc = e.desc:gsub('30%%', '25%%') end end) -- 生命 220 → 190，攻击 14 → 13，反弹 30% → 25%
-- 第五章：利维坦的首领波比上一波难一倍多
-- 本工程是 7 章体系，深渊利维坦在第七章且基础值（5600/38）远高于上游 5 章版的 2970/30，
-- 因此这里按上游同样的相对幅度（生命 -9%、攻击 -10%）缩放，不能写死上游的绝对值。
E('leviathan', function(e) e.hp = js.round(e.hp * 0.91); e.atk = js.round(e.atk * 0.9) end)
-- 第九章：风暴之主是全游戏落差最大的首领（首领波难度是上一波的 2.6 倍，比最终首领还难打）
E('stormlord', function(e) e.hp = 2100; e.atk = 23 end)                -- 生命 2800 → 2100，攻击 27 → 23
E('stormtotem', function(e) e.hp = 240; e.atk = 8 end)                 -- 风暴图腾：生命 300 → 240，攻击 10 → 8（图腾在场时首领减伤 50%，拆得更快）
-- 第十章：骨龙是全游戏最强的普通敌人（远程 + 灼烧 + 高血）
E('bonedragon', function(e) e.hp = 128; e.atk = 13 end)               -- 生命 150 → 128，攻击 14 → 13

-- ---------------------------------------------------------------------------
-- 转职路线（mods 改动会同步到被动说明）
-- ---------------------------------------------------------------------------
BAL14 = { changed = {} }
local PAT = { atk = '攻击', hp = '生命', spd = '攻速', crit = '暴击率' }
local function fmtPct(v) return string.format('%d', math.floor(v * 100 + 0.5)) end
--- 改一项属性加成，被动说明里的数字一起改（找不到就加在最前面）
local function mod(br, key, v)
    local B = BRANCHES[br]
    if not B then return end
    B.mods = B.mods or {}
    local old = B.mods[key] or 0
    B.mods[key] = v
    BAL14.changed[br] = true
    if key == 'dr' then
        local n
        B.passive, n = B.passive:gsub('受到的伤害 %-%d+%%', '受到的伤害 -' .. fmtPct(v) .. '%%', 1)
        if n == 0 then B.passive = '受到的伤害 -' .. fmtPct(v) .. '%，' .. B.passive end
        return
    end
    local word = PAT[key]
    local sign = (v >= 0) and '+' or '-'
    local rep = word .. ' ' .. sign .. fmtPct(math.abs(v)) .. '%%'
    local n
    B.passive, n = B.passive:gsub(word .. ' [%+%-]%d+%%', rep, 1)
    if n == 0 then B.passive = word .. ' ' .. sign .. fmtPct(math.abs(v)) .. '%，' .. B.passive end
end
local function fx(br, key, v, from, to)
    local B = BRANCHES[br]
    if not B then return end
    B.fx = B.fx or {}; B.fx[key] = v
    if from then B.passive = B.passive:gsub(from, to, 1) end
    BAL14.changed[br] = true
end
BAL14.mod, BAL14.fx = mod, fx

-- —— 削弱：同品质里明显超标的 ——
mod('paladin', 'hp', 0.25); mod('paladin', 'dr', 0.1)                -- 圣骑士：生命 +40% → +25%，减伤 15% → 10%
SKILLS.warcry.charge = 18                                             -- 战旗手「战吼」：每次普攻能量 25 → 18（多打一两下才放），回血 12% → 8%
SKILLS.warcry.desc = '全队狂热 3 秒（攻速翻倍），并回复 8% 最大生命'
EXT_SKILLS2.warcry = function(B, e, t)
    for o in js.of(alliesOf(B, e)) do o.haste = math.max(o.haste or 0, 3); healAmt(o, o.maxHp * 0.08); FX.ring(o.x, o.y, 8, '#ffb04a') end
    FX.ring(e.x, e.y, 26, '#ff6a4a')
end
-- 圣骑士「圣光庇护」：护盾 30% → 18%
SKILLS.aegis.desc = '给自己和血量最低的两名队友加上 18% 最大生命的护盾，并嘲讽附近敌人'
EXT_SKILLS2.aegis = function(B, e, t)
    local amt = e.maxHp * 0.18
    local al = alliesOf(B, e):filter(function(o) return o ~= e end):sort(function(a, b) return a.hp / a.maxHp - b.hp / b.maxHp end):slice(0, 2)
    js.A(e):concat(al):forEach(function(o) o.shield = math.min(o.maxHp, (o.shield or 0) + amt); FX.ring(o.x, o.y, 9, '#fff3b0') end)
    for o in js.of(foesOf(B, e)) do if js.hypot(o.x - e.x, o.y - e.y) <= 60 then o.target = e end end
end
-- 炽天使「圣域降临」：复活 60% → 50% 生命，全队护盾 35% → 25%
SKILLS.sanctuary.desc = '复活一名阵亡的队友（50% 生命），并给全队加上 25% 最大生命的护盾'
EXT_SKILLS2.sanctuary = function(B, e, t)
    local fallen = B.ents:filter(function(o) return o.dead and o.side == e.side and not o.minion and o ~= e end):sort(function(a, b) return b.atk - a.atk end)[0]
    if fallen then revive(fallen, 0.5) end
    for o in js.of(alliesOf(B, e)) do o.shield = math.min(o.maxHp, (o.shield or 0) + o.maxHp * 0.25); FX.ring(o.x, o.y, 9, '#fff3b0') end
    B.tint = { t = 0.5, max = 0.5, rgb = '255,243,176' }
end
-- 北地史诗吟唱者「英雄史诗」：护盾 20% → 14%
SKILLS.saga.desc = '全队获得 14% 最大生命的护盾，并攻速 +30%，持续 5 秒'
EXT_SKILLS2.saga = function(B, e, t)
    for o in js.of(alliesOf(B, e)) do if not o.dead then o.shield = math.min(o.maxHp, (o.shield or 0) + o.maxHp * 0.14) end; addBuff(o, 5, { spd = 0.3 }) end
end
-- 冬眠熊「冬眠」：护盾 40% → 25%，回血 25% → 15%，减伤 40% → 30%
SKILLS.hibernate.desc = '给自己加上 25% 最大生命的护盾并回复 15% 生命，5 秒内受到的伤害 -30%'
EXT_SKILLS2.hibernate = function(B, e, t)
    e.shield = math.min(e.maxHp, (e.shield or 0) + e.maxHp * 0.25); healAmt(e, e.maxHp * 0.15)
    e.guard = { t = 5, dr = 0.3 }
    FX.ring(e.x, e.y, 22, '#6a8ad8'); FX.particle(e.x, e.y, '#bcd0ff', 14, 40, -10, 0.8)
end
fx('hibernator', 'regen', 0.006, '每秒回复 1.5%%', '每秒回复 0.6%%') -- 冬眠熊：每秒回复 1.5% → 0.6%
mod('hibernator', 'hp', 0.2)                                          --         生命 +40% → +20%
SKILLS.hibernate.charge = 24                                          --         「冬眠」能量 30 → 24
mod('beastmaster', 'hp', 0.1)                                         -- 驯兽师：生命 +20% → +10%
fx('lich', 'deathRaise', 0.25, '50%% 几率', '25%% 几率')              -- 巫妖王：复生几率 50% → 25%
mod('lich', 'hp', 0.3)                                                --         生命 +40% → +30%
fx('seraph', 'drAura', 0.07, '%-12%%', '-7%%')                        -- 炽天使：光环减伤 12% → 7%
mod('sup_frost', 'atk', 0.3); mod('sup_frost', 'hp', 0.4)             -- 血霜魔灵：攻击 +40% → +30%，生命 +55% → +40%
SKILLS.frostcoffin.charge = 28                                        --         「霜狱碎魂」每次普攻能量 34 → 28
SUP_COFFIN_FREEZE, SUP_COFFIN_MUL = 1.0, 1.5                          --         「霜狱碎魂」冻结 1.8 → 1.0 秒，碎裂 220% → 150%
SKILLS.frostcoffin.desc = SKILLS.frostcoffin.desc:gsub('冻结 1%.8 秒', '冻结 1 秒'):gsub('220%%', '150%%')
mod('sup_treant', 'hp', 0.5); mod('sup_treant', 'dr', 0.15)           -- 血根古神：生命 +60% → +50%，减伤 20% → 15%
fx('sup_treant', 'regen', 0.015, '每秒回复 2%%', '每秒回复 1.5%%')   --         每秒回复 2% → 1.5%
fx('guardbear', 'guardShare', 0.2, '30%% 转由', '20%% 转由')          -- 守护熊：替身边队友分担 30% → 20%

-- —— 加强：同品质里明显偏弱的 ——
SKILLS.chain.charge = 38                                              -- 雷术士「连锁闪电」：每次普攻能量 30 → 38（放得更勤）
SKILLS.elements.charge = 38                                           -- 大魔导师「元素风暴」：每次普攻能量 30 → 38
mod('claw', 'spd', 0.25)                                              -- 利爪：攻速 +15% → +25%
fx('claw', 'bleedHit', 0.35, '25%% 几率', '35%% 几率')                --       流血几率 25% → 35%
mod('corroder', 'spd', 0.25); mod('corroder', 'atk', 0.15)            -- 腐蚀花：攻速 +15% → +25%，新增攻击 +15%
mod('rendtiger', 'atk', 0.2)                                          -- 裂爪虎：攻击 +10% → +20%
mod('parasite', 'atk', 0.2)                                           -- 寄生花：攻击 +10% → +20%
mod('frost', 'atk', 0.15)                                             -- 冰霜术士：新增攻击 +15%
mod('storm', 'atk', 0.75); mod('storm', 'hp', 0.5)                    -- 雷术士：攻击 +20% → +75%，生命 +25% → +50%，弹射几率 50% → 80%
BRANCHES.storm.mods.chainHit = 0.8; BRANCHES.storm.passive = BRANCHES.storm.passive:gsub('50%% 几率弹射', '80%% 几率弹射', 1)
mod('sabre', 'atk', 0.5); mod('sabre', 'hp', 0.6)                     -- 剑齿王：攻击 +15% → +50%，生命 +30% → +60%，新增吸血 15%
BRANCHES.sabre.mods.leech = 0.15; BRANCHES.sabre.passive = BRANCHES.sabre.passive:gsub('；', '，吸血 15%%；', 1)
mod('archmage', 'atk', 0.7); mod('archmage', 'hp', 0.5)               -- 大魔导师：攻击 +25% → +70%，生命 +40% → +50%
mod('devourer', 'atk', 0.45); mod('devourer', 'hp', 0.55)             -- 噬魂花：攻击 +20% → +45%，生命 +40% → +55%
mod('sniper', 'atk', 0.7); mod('sniper', 'hp', 0.3)                   -- 神射手：攻击 +20% → +70%，新增生命 +30%
mod('blademaster', 'spd', 0.3); mod('blademaster', 'atk', 0.3); mod('blademaster', 'hp', 0.3) -- 剑圣：攻速 +15% → +30%，新增攻击 +30%、生命 +30%
mod('tigerspirit', 'atk', 0.4); mod('tigerspirit', 'hp', 0.2)        -- 虎魄：攻击 +25% → +40%，新增生命 +20%
mod('phoenixhawk', 'atk', 0.5); mod('phoenixhawk', 'hp', 0.2)        -- 炎羽隼：攻击 +25% → +50%，新增生命 +20%
mod('guardbear', 'hp', 0.4)                                           -- 守护熊：生命 +50% → +40%（「守护誓约」替队友挨打，自己更耐打了）
mod('sup_clock', 'atk', 0.5); mod('sup_clock', 'hp', 0.6)             -- 赤钢天机：攻击 +35% → +50%，生命 +50% → +60%
mod('sup_mage', 'atk', 0.45)                                          -- 血月魔尊：攻击 +35% → +45%
mod('sup_whelp', 'atk', 0.5)                                          -- 血焰魔龙：攻击 +40% → +50%
mod('sup_bear', 'hp', 0.7)                                            -- 赤铠熊魔：生命 +60% → +70%

return true
