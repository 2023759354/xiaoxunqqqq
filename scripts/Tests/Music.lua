-- 真实入口音乐与本地音效验收；只用于 -validate-test，不写玩家存档。
local V = assert(rawget(_G, 'V'), '本脚本只供 -validate-test 使用') --[[@as table<string, any>]]
local N = require('game.env') --[[@as table<string, any>]]
local Music = require('game.music') --[[@as table<string, any>]]
local Assets = require('game.audio_assets') --[[@as table<string, any>]]
local validation = false
for _, arg in ipairs(GetArguments()) do
    if arg:match('^%-validate%-test=') then validation = true end
end
assert(validation, '必须通过 -validate-test 启动，禁止接触玩家真实档')

V.atFrame(15, function()
    local oldGame, oldMeta, oldSave = N.G, N.META, N.SAVE
    local oldData, oldPersist = N.store.data, N.store.persist
    local oldOn, oldReady, oldBusy = N.Sound.on, N.Sound.ready, N.Ads.busy
    local oldActive, oldSynced = N.Cloud.active, N.Cloud.onSynced
    local oldApi = rawget(_G, 'clientCloud')
    local oldEnabled, oldSuspended = Music.enabled, Music.suspended
    local timers, time = N.Timers.list, N.Timers.now
    N.store.data, N.store.persist = {}, function() end
    N.Cloud.active, N.Cloud.onSynced = false, nil
    rawset(_G, 'clientCloud', {})
    N.Timers.list = {}
    local ok, err = xpcall(function()
        N.buildSave(); N.loadMeta()
        N.TUT.stop()
        N.UI.els.home:setHidden(true)
        N.UI.els.overlay:setHidden(true)
        N.Sound.on, N.Sound.ready, N.Ads.busy = true, true, false
        Music.enabled, Music.suspended = true, false
        local paths = {
            [0] = 'audio/Sounds/bgm_c1.ogg', [1] = 'audio/Sounds/bgm_c2.ogg',
            [2] = 'audio/Sounds/bgm_c3.ogg', [3] = 'audio/bgm_battle4.ogg',
            [4] = 'audio/bgm_battle5.ogg', [5] = 'audio/Sounds/bgm_c4.ogg',
            [6] = 'audio/Sounds/bgm_c5.ogg',
        }
        for chapter = 0, 6 do
            local name = 'bgm_battle' .. (chapter + 1)
            V.assert(Assets.music[name] == paths[chapter], '七章显式映射且旧4/5不被挤占：' .. name)
        end
        V.assert(Assets.music.bgm_boss == 'audio/Sounds/bgm_boss.ogg', '首领使用更新包首领曲')
        local count = 0
        for name in pairs(Assets.music) do
            count = count + 1
            local sound = Music.tracks[name]
            V.assert(sound ~= nil, '本地音乐成功加载：' .. name)
            if sound then
                V.assert(sound.looped and sound.length > 0 and sound.frequency > 0,
                    name .. ' 可解码、时长为正且循环，不限定素材时长/采样率')
            end
        end
        V.assert(count == 8, '七首章节曲及一首首领曲')
        local effects, ogg = 0, 0
        for name, path in pairs(Assets.effects) do
            effects = effects + 1
            if path:match('%.ogg$') then ogg = ogg + 1 end
            V.assert(cache:Exists(path), '音效在本地资源根可用：' .. name)
            local sound = cache:GetResource('Sound', path)
            V.assert(sound and sound.length > 0 and sound.frequency > 0, '音效实际解码成功：' .. name)
        end
        V.assert(effects == 32 and ogg == 32, '32个本地ogg音效')
        V.assert(Assets.effects.merge == 'audio/Sounds/merge.ogg', 'merge 使用 ogg')
        for _, name in ipairs({ 'shop', 'buy', 'refresh', 'sell', 'item' }) do
            V.assert(Assets.effects[name] == 'audio/Sounds/' .. name .. '.ogg', '新商店音效映射：' .. name)
        end
        for chapter = 0, 6 do
            N.newGame(chapter, 0)
            N.summon('warrior', 1, 0)
            N.startBattle()
            local track = 'bgm_battle' .. (chapter + 1)
            V.assert(Music.wanted() == track, '章节使用对应战斗曲：' .. (chapter + 1))
            Music.update(0.4)
            V.assert(Music.current ~= nil and Music.current.track == track, '战斗曲进入真实播放音源')
            if Music.current and Music.tracks[track] then
                V.assert(Music.current.source.frequency == Music.tracks[track].frequency,
                    'Play采用真实素材采样率，不变速：' .. track)
                V.assert(Music.current.source.gain > 0 and Music.current.source.gain <= Music.VOLUME, '音乐淡入且音量受限')
                Music.current.source:Stop()
                Music.update(0.1)
                V.assert(Music.current.source:IsPlaying() and Music.current.source.frequency == Music.tracks[track].frequency,
                    '同曲恢复播放仍不变速：' .. track)
            end
        end
        N.G.wave = N.G.maxWave
        V.assert(Music.wanted() == 'bgm_boss', '最终波切换首领音乐')
        Music.update(0.4)
        V.assert(Music.current ~= nil and Music.current.track == 'bgm_boss', '首领曲进入真实音源')
        if Music.current and Music.tracks.bgm_boss then
            V.assert(Music.current.source.frequency == Music.tracks.bgm_boss.frequency, '首领曲Play也不变速')
        end
        N.Ads.busy = true
        Music.update(0.1)
        V.assert(Music.wanted() == nil and Music.current == nil, '广告期间不选择战斗音乐')
        for _, slot in ipairs(Music.sources) do V.assert(slot.source.gain == 0, '广告期间音乐立即静音') end
        N.Ads.busy = false
        Music.update(0.1)
        V.assert(Music.current ~= nil and Music.current.track == 'bgm_boss', '广告结束恢复战斗音乐')
        N.Sound.on = false
        Music.update(0.1)
        for _, slot in ipairs(Music.sources) do V.assert(slot.source.gain == 0, '关闭声音立即静音') end
        N.Sound.on = true
        Music.update(0.4)
        N.G.tutorial = true
        V.assert(Music.wanted() == nil, '教程不播放战斗音乐')
        N.G.tutorial = false
        N.UI.els.home:setHidden(false)
        V.assert(Music.wanted() == nil, '主页不播放战斗音乐')
        Music.update(2)
        for _, slot in ipairs(Music.sources) do V.assert(slot.track == nil and slot.source.gain == 0, '离开战斗淡出并释放播放槽') end
    end, function(e) return tostring(e) end)
    N.G, N.META, N.SAVE = oldGame, oldMeta, oldSave
    N.store.data, N.store.persist = oldData, oldPersist
    N.Sound.on, N.Sound.ready, N.Ads.busy = oldOn, oldReady, oldBusy
    N.Cloud.active, N.Cloud.onSynced = oldActive, oldSynced
    rawset(_G, 'clientCloud', oldApi)
    Music.enabled, Music.suspended = oldEnabled, oldSuspended
    N.Timers.list, N.Timers.now = timers, time
    N.UI.els.overlay:setHidden(true)
    N.UI.update()
    V.assert(ok, '音乐与音效验收无异常：' .. tostring(err))
    V.finish()
end)
