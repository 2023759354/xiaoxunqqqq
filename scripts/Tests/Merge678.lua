-- 第六/七/八次更新合并验收；仅供 -validate-test=Tests/Merge678.lua 使用。
-- 覆盖：8/9/10 章加载与首领机制、3 个新兵种、兵种限定装备、装备仓库、道具品质光圈、
--       新章节背景与音乐、pixel 整图引用、paint 池清理。
-- 不重载模块、不写文件；SDK/云 API 用桩，业务逻辑仍走真实函数。
local V = assert(rawget(_G, 'V'), '本脚本只供 -validate-test 使用') --[[@as table<string, any>]]
local N = require('game.env') --[[@as table<string, any>]]
local js = require('game.compat')

local validation = false
for _, arg in ipairs(GetArguments()) do
    if arg:match('^%-validate%-test=') then validation = true end
end
assert(validation, '必须通过 -validate-test 启动，禁止接触玩家真实档')

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function seed()
    N.store.data = {}
    N.buildSave()
    N.loadMeta()
end

local function at(frame, name, test)
    V.atFrame(frame, function()
        V.assert(N.PAGE ~= nil, '真实入口已初始化页面')
        if not N.PAGE then V.finish(); return end
        local storeData, persist = N.store.data, N.store.persist
        local cloud, timers, ads = copy(N.Cloud), copy(N.Timers), copy(N.Ads)
        N.store.data = {}
        N.store.persist = function() end
        N.Cloud.active, N.Cloud.onSynced = false, nil
        rawset(_G, 'clientCloud', {})
        N.Timers.list = {}
        local ok, err = xpcall(function()
            N.Ads.cancel()
            N.Ads.available = function() return true end
            seed()
            N.TUT.stop()
            N.UI.els.home:setHidden(true)
            N.UI.els.overlay:setHidden(true)
            test()
        end, debug.traceback)
        N.Ads.cancel()
        N.store.data, N.store.persist = storeData, persist
        N.Cloud.active, N.Cloud.onSynced = cloud.active, cloud.onSynced
        for k in pairs(N.Timers) do N.Timers[k] = timers[k] end
        for k in pairs(N.Ads) do N.Ads[k] = ads[k] end
        if not ok then
            print('[Merge678] 失败：' .. name .. '\n' .. tostring(err))
            V.assert(false, name .. '：' .. tostring(err))
            V.finish()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- 1. 章节：8/9/10 章已注册，索引 7/8/9，显示名与解锁链正确
-- ---------------------------------------------------------------------------
at(30, '新章节注册与显示', function()
    V.assert(#N.CHAPTERS == 10, '共 10 章（7 + 新 3），实际 ' .. tostring(#N.CHAPTERS))
    local c8, c9, c10 = N.CHAPTERS[7], N.CHAPTERS[8], N.CHAPTERS[9]
    V.assert(c8 and c8.title == '霜寒冰原' and c8.num == '8', '第八章 霜寒冰原')
    V.assert(c9 and c9.title == '天空浮城' and c9.num == '9', '第九章 天空浮城')
    V.assert(c10 and c10.title == '终焉王座' and c10.num == '10', '第十章 终焉王座')
    V.assert(c8.bg == 'tundra' and c9.bg == 'sky' and c10.bg == 'throne', '新章节背景键')
    V.assert(c8.music == 'bgm_c8' and c8.bossMusic == 'bgm_boss8', '第八章曲目')
    V.assert(c9.music == 'bgm_c9' and c10.music == 'bgm_c10', '第九/十章曲目')
    -- 敌人已注册到正确章节
    V.assert(N.ENEMIES.frostwolf and N.ENEMIES.frostwolf.ch == 7, '雪狼归属第八章')
    V.assert(N.ENEMIES.stormlord and N.ENEMIES.stormlord.ch == 8, '风暴之主归属第九章')
    V.assert(N.ENEMIES.doomking and N.ENEMIES.doomking.ch == 9, '终焉之王归属第十章')
    -- 雪人投手已改名，不与第三章雪原巨猿撞名
    V.assert(N.ENEMIES.snowthrower and N.ENEMIES.snowthrower.name == '雪人投手', '雪人投手已注册')
    V.assert(N.ENEMIES.yeti and N.ENEMIES.yeti.ch == 3 and N.ENEMIES.yeti.name == '雪原巨猿', '第三章雪原巨猿未被覆盖')
    -- 精灵齐备
    for _, k in ipairs({ 'frostwolf', 'snowthrower', 'glacier', 'frostwyrm', 'stormlord', 'doomking', 'bard', 'whelp', 'frostling' }) do
        V.assert(N.SPR[k] ~= nil, '精灵存在：' .. k)
    end
end)

-- ---------------------------------------------------------------------------
-- 2. 新兵种：3 个、解锁条件、新类别
-- ---------------------------------------------------------------------------
at(35, '新兵种与解锁', function()
    V.assert(N.CLASSES.bard and N.CLASSES.bard.name == '吟游诗人', '吟游诗人已注册')
    V.assert(N.CLASSES.whelp and N.CLASSES.whelp.kind == 'dragon', '幼龙属龙族')
    V.assert(N.CLASSES.frostling and N.CLASSES.frostling.kind == 'element', '冰霜元素属元素')
    V.assert(N.KIND_NAME.dragon == '龙族' and N.KIND_NAME.element == '元素', '新类别名')
    -- 解锁语义：吟游诗人=通关第七章(索引6)、幼龙=第八章(7)、冰霜元素=第九章(8)
    V.assert(N.CLASSES.bard.unlock == 6, '吟游诗人解锁第七章')
    V.assert(N.CLASSES.whelp.unlock == 7, '幼龙解锁第八章')
    V.assert(N.CLASSES.frostling.unlock == 8, '冰霜元素解锁第九章')
    V.assert(#N.CLASS_KEYS == 13, '兵种共 13 个，实际 ' .. tostring(#N.CLASS_KEYS))
    -- 每条路线 + 超凡形态
    for _, cls in ipairs({ 'bard', 'whelp', 'frostling' }) do
        V.assert(N.CLASS_BRANCHES[cls] ~= nil, cls .. ' 有转职路线')
        V.assert(N.SUPER_OF[cls] ~= nil, cls .. ' 有超凡形态')
        V.assert(N.CLASS_SKILL[cls] ~= nil, cls .. ' 有基础技能')
    end
end)

-- ---------------------------------------------------------------------------
-- 3. 兵种限定装备 + 装备仓库
-- ---------------------------------------------------------------------------
at(40, '限定装备与仓库', function()
    local eq2 = N.ITEMS.goldharp
    V.assert(eq2 and eq2.cls == 'bard', '金弦竖琴限定吟游诗人')
    V.assert(eq2.limit and eq2.limit:find('吟游诗人', 1, true) ~= nil, '限定文案')
    V.assert(N.ITEMS.lionhelm.cls == 'warrior' and N.ITEMS.permafrost.cls == 'frostling', '限定装备兵种字段')
    -- 仓库 API
    N.newGame()
    V.assert(N.STASH_SLOTS == 10, '仓库 10 格（第十五次更新）')
    local it = { id = 'windboots', rar = 0 }
    V.assert(N.stashPut(it) == true and #N.stashOf() == 1, '放入仓库')
    V.assert(N.stashFull() == false, '未满')
    -- 装满后不能再放
    for _ = 1, N.STASH_SLOTS - 1 do N.stashPut({ id = 'windboots', rar = 0 }) end
    V.assert(N.stashFull() == true, '10 格已满')
    V.assert(N.stashPut({ id = 'windboots', rar = 0 }) == false, '满了拒绝')
    local p = N.stashSell(1)
    V.assert(p >= 0 and #N.stashOf() == N.STASH_SLOTS - 1, '从仓库卖出')
    -- canEquipItem 兵种限定检查
    local u = N.summon('bard', 1, 0).nu
    V.assert(N.canEquipItem({ id = 'goldharp' }, u) == true, '吟游诗人可装金弦竖琴')
    local w = N.summon('warrior', 1, 0).nu
    V.assert(N.canEquipItem({ id = 'goldharp' }, w) == false, '战士不可装吟游诗人限定装备')
end)

-- ---------------------------------------------------------------------------
-- 4. 道具品质光圈
-- ---------------------------------------------------------------------------
at(45, '道具品质光圈', function()
    -- 直接验证 haloIconURL：同一张原图，不同品质产出不同的带光圈图，且尺寸 +2（16→18）
    local base = N.itemIconBase({ id = 'goldharp', rar = 2 })
    V.assert(base ~= nil, '基础图标可生成')
    local bimg = N.ICONS[base]
    V.assert(bimg and bimg.width == 16, '基础图标 16 宽，实际 ' .. tostring(bimg and bimg.width))
    local k0 = N.haloIconURL(base, 0)
    local k3 = N.haloIconURL(base, 3)
    V.assert(k0 ~= k3, '普通与传说产出不同键')
    local i0, i3 = N.ICONS[k0], N.ICONS[k3]
    V.assert(i0 and i3, '两种光圈图都已生成')
    V.assert(i0.width == 18 and i3.width == 18, '光圈图 18 宽（16→18），实际 ' .. tostring(i0.width) .. '/' .. tostring(i3.width))
    -- 撞脸图标已换新
    V.assert(N.ITEMS.awl and N.ITEMS.awl.icon == 'n_awl', '破甲锥换新图标')
    V.assert(N.ITEMS.lens and N.ITEMS.lens.icon == 'n_spyglass', '远视镜换新图标')
    -- itemIcon 对传说装备返回带光圈图
    local kL = N.itemIcon({ id = 'signet', rar = 3 })
    V.assert(N.ICONS[kL] ~= nil and N.ICONS[kL].width == 18, 'itemIcon 对传说装备返回 18 宽光圈图')
end)

-- ---------------------------------------------------------------------------
-- 5. 新章节战斗：生成首领波并触发机制
-- ---------------------------------------------------------------------------
at(60, '第八章首领机制', function()
    N.newGame(7, 0)
    N.summonSuper('warrior')
    N.G.wave = N.G.maxWave
    N.startBattle()
    local b = N.G.battle
    V.assert(b ~= nil, '第八章战斗已开始')
    local boss = b.ents:find(function(e) return e.type == 'frostwyrm' end)
    V.assert(boss ~= nil, '凛冬巨龙生成')
    local target = b.ents:find(function(e) return e.side == 'p' end)
    V.assert(target ~= nil, '我方单位存在')
    -- 60% 生命触发凛冬降临
    N.hit(target, boss, boss.maxHp * 10, { noCrit = true, noLeech = true })
    N.stepBattle(0)
    V.assert(boss.ph1 == true, '凛冬降临触发')
    -- 30% 触发霜龙之怒
    N.hit(target, boss, boss.maxHp * 10, { noCrit = true, noLeech = true })
    N.stepBattle(0)
    V.assert(boss.ph2 == true, '霜龙之怒触发')
    N.G.phase = 'prep'
end)

at(70, '第九章首领机制', function()
    N.newGame(8, 0)
    N.summonSuper('warrior')
    N.G.wave = N.G.maxWave
    N.startBattle()
    local b = N.G.battle
    local boss = b.ents:find(function(e) return e.type == 'stormlord' end)
    V.assert(boss ~= nil, '风暴之主生成')
    local target = b.ents:find(function(e) return e.side == 'p' end)
    N.hit(target, boss, boss.maxHp * 10, { noCrit = true, noLeech = true })
    N.stepBattle(0)
    V.assert(boss.ph1 == true and boss.tents2 ~= nil, '风暴图腾召唤触发')
    N.hit(target, boss, boss.maxHp * 10, { noCrit = true, noLeech = true })
    N.stepBattle(0)
    V.assert(boss.ph2 == true, '风暴之眼触发')
    N.G.phase = 'prep'
end)

at(80, '第十章首领机制', function()
    N.newGame(9, 0)
    N.summonSuper('warrior')
    N.G.wave = N.G.maxWave
    N.startBattle()
    local b = N.G.battle
    local boss = b.ents:find(function(e) return e.type == 'doomking' end)
    V.assert(boss ~= nil, '终焉之王生成')
    local target = b.ents:find(function(e) return e.side == 'p' end)
    -- 75% 历代残影
    N.hit(target, boss, boss.maxHp * 10, { noCrit = true, noLeech = true })
    N.stepBattle(0)
    V.assert(boss.ph1 == true, '历代残影触发')
    V.assert(b.ents:some(function(e) return e.echo and not e.dead end), '残影已生成')
    -- 45% 王座结界
    N.hit(target, boss, boss.maxHp * 10, { noCrit = true, noLeech = true })
    N.stepBattle(0)
    V.assert(boss.ph2 == true and boss.barrier == true, '王座结界触发')
    V.assert(boss.pillars ~= nil and #boss.pillars >= 2, '终焉之柱已生成')
    N.G.phase = 'prep'
end)

-- ---------------------------------------------------------------------------
-- 6. 新兵种实战：技能可施放、特效不报错
-- ---------------------------------------------------------------------------
at(100, '新兵种技能实战', function()
    for _, spec in ipairs({ { 'bard', 'battlesong' }, { 'whelp', 'dragonbreath' }, { 'frostling', 'icenova' } }) do
        N.newGame()
        local u = N.summon(spec[1], 1, 0).nu
        V.assert(u ~= nil, '召唤 ' .. spec[1])
        N.startBattle()
        local b = N.G.battle
        V.assert(b ~= nil, spec[1] .. ' 战斗开始')
        local caster = b.ents:find(function(e) return e.unit == u end)
        local target = b.ents:find(function(e) return e.side == 'e' end)
        V.assert(caster ~= nil and target ~= nil, spec[1] .. ' 施法者与目标')
        V.assert(caster.skill == spec[2], spec[1] .. ' 基础技能 = ' .. spec[2])
        local ok, err = pcall(N.castSkill, b, caster, target)
        V.assert(ok, spec[1] .. ' 技能施放不报错：' .. tostring(err))
        N.G.phase = 'prep'
    end
end)

-- ---------------------------------------------------------------------------
-- 7. 新兵种限定装备实战触发
-- ---------------------------------------------------------------------------
at(115, '限定装备效果触发', function()
    N.newGame()
    local u = N.summon('bard', 1, 0).nu
    N.equipItem({ id = 'goldharp', rar = 2 }, u)
    N.startBattle()
    local b = N.G.battle
    local caster = b.ents:find(function(e) return e.unit == u end)
    V.assert(caster and caster.eq_goldharp == true, '金弦竖琴标志已挂到实体')
    local target = b.ents:find(function(e) return e.side == 'e' end)
    local ok = pcall(N.castSkill, b, caster, target)
    V.assert(ok, '金弦竖琴触发不报错')
    N.G.phase = 'prep'
end)

-- ---------------------------------------------------------------------------
-- 8. 选关 UI 能列出 10 章
-- ---------------------------------------------------------------------------
at(130, '选关列出 10 章', function()
    N.newGame()
    N.UI.pickCh = 0
    local html = N.UI.pickerHTML()
    V.assert(type(html) == 'string' and #html > 0, '选关 HTML 可生成')
    -- 第十三次更新把选关界面重写成 ui_redo.lua，章节页签的 class 从 chap2 改成了 pk-ch
    local count = 0
    for _ in html:gmatch('class="pk%-ch[ "]') do count = count + 1 end
    V.assert(count == 10, '选关页签 10 个，实际 ' .. tostring(count))
    V.assert(html:find('霜寒冰原', 1, true) ~= nil, '选关含第八章')
    V.assert(html:find('终焉王座', 1, true) ~= nil, '选关含第十章')
end)

V.atFrame(200, function() V.finish() end)
