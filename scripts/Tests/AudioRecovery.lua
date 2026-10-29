-- 只用 SDK/音频输出桩，不请求真实广告、不接触玩家存档。
local V = assert(rawget(_G, 'V'), '本脚本只供 -validate-test 使用') --[[@as table<string, any>]]
local N = require('game.env') --[[@as table<string, any>]]
local Music = require('game.music') --[[@as table<string, any>]]
local Assets = require('game.audio_assets') --[[@as table<string, any>]]
local Recovery = require('game.audio_recovery')

V.atFrame(15, function()
    local oldAudio, oldCache, oldSdk = rawget(_G, 'audio'), rawget(_G, 'cache'), rawget(_G, 'sdk')
    local oldLoad = Assets.load
    local oldGame, oldOn, oldReady = N.G, N.Sound.on, N.Sound.ready
    local timers, time = N.Timers.list, N.Timers.now
    local scene = Scene()
    local paused, gains = {}, {}
    local playing, playCalls = true, 0
    for _, kind in ipairs({ SOUND_MASTER, SOUND_MUSIC, SOUND_EFFECT }) do gains[kind] = 0.7 end
    local output = {
        IsSoundTypePaused = function(_, kind) return paused[kind] == true end,
        GetMasterGain = function(_, kind) return gains[kind] end,
        SetMasterGain = function(_, kind, value) gains[kind] = value end,
        PauseSoundType = function(_, kind) paused[kind] = true end,
        ResumeSoundType = function(_, kind) paused[kind] = false end,
        IsPlaying = function() return playing end,
        IsInitialized = function() return true end,
        Play = function() playing = true; playCalls = playCalls + 1; return true end,
    }
    local ok, err = xpcall(function()
        N.TUT.stop()
        N.UI.els.home:setHidden(true)
        N.UI.els.overlay:setHidden(true)
        N.Sound.on, N.Sound.ready = true, true
        N.Timers.list = {}
        rawset(_G, 'audio', output)
        Recovery.init()
        N.newGame(0, 0)
        N.summon('warrior', 1, 0)
        N.startBattle()
        Music.update(0.4)
        V.assert(Music.current ~= nil, '战斗中存在音乐音源')
        if Music.current then
            Music.current.source:Stop()
            V.assert(not Music.current.source:IsPlaying(), '模拟宿主停止了音乐音源')
            Music.update(0.1)
            V.assert(Music.current.source:IsPlaying(), '同曲目已停止音源会重新播放')
        end

        local function restored(label)
            V.assert(not N.Ads.busy, label .. '：释放广告锁')
            V.assert(not paused[SOUND_MUSIC] and not paused[SOUND_EFFECT], label .. '：解除自己建立的音类暂停')
            V.assert(playing, label .. '：恢复停止的混音输出')
            V.assert(N.Sound.on, label .. '：不改变玩家声音偏好')
        end
        for _, mode in ipairs({ 'success', 'close', 'reject', 'exception', 'timeout', 'cancel' }) do
            local callback
            rawset(_G, 'sdk', { ShowRewardVideoAd = function(_, cb)
                V.assert(paused[SOUND_MUSIC] and paused[SOUND_EFFECT], mode .. '：SDK调用前已暂停游戏声音')
                callback = cb
                playing = false
                if Music.current then Music.current.source:Stop() end
                if mode == 'exception' then error('测试 SDK 异常') end
                if mode == 'reject' then return false end
                return true
            end })
            local rewards, finished = 0, 0
            N.Ads.show(function(success)
                finished = finished + 1
                if success then rewards = rewards + 1 end
            end)
            if mode == 'success' then
                gains[SOUND_MUSIC] = 0
                callback({ success = true, msg = 'test complete' })
                callback({ success = true, msg = 'duplicate' })
                V.assert(gains[SOUND_MUSIC] == 0.7, '只恢复广告前的音量，不强设为1')
            elseif mode == 'close' then callback({ success = false, msg = 'manual close' })
            elseif mode == 'timeout' then N.Timers.advance(N.Timers.now + N.Ads.TIMEOUT + 1)
            elseif mode == 'cancel' then N.Ads.cancel(); callback({ success = true }) end
            restored(mode)
            V.assert(rewards == (mode == 'success' and 1 or 0), mode .. '：只有完整观看发奖且重复回调不重发')
            V.assert(finished == (mode == 'cancel' and 0 or 1), mode .. '：业务完成至多一次，取消不调用业务')
            Recovery.update(0.4); Recovery.update(0.4); Recovery.update(0.4)
        end
        V.assert(playCalls >= 6, '各广告结束分支均尝试恢复停止输出')

        N.Ads.busy = true
        Recovery.begin()
        N.Sound.on, playing = false, false
        N.Ads.busy = false
        Recovery.finish()
        V.assert(not paused[SOUND_MUSIC] and not paused[SOUND_EFFECT], '静音状态仍释放自己的暂停')
        V.assert(not playing and not N.Sound.on, '恢复不强行打开玩家已关闭的声音')
        N.Sound.on = true
        N.Sound.init()
        V.assert(playing, '玩家重新开声音时恢复输出')
        Recovery.update(0.4); Recovery.update(0.4); Recovery.update(0.4)
        gains[SOUND_MUSIC] = 0
        Recovery.resume()
        V.assert(gains[SOUND_MUSIC] == 0, '恢复窗口结束后不使用陈旧音量快照')
        gains[SOUND_MUSIC] = 0.7
        paused[SOUND_EFFECT] = true
        N.Ads.busy = true; Recovery.begin()
        N.Ads.busy = false; Recovery.finish()
        V.assert(paused[SOUND_EFFECT], '不解除广告前已有的其他音效暂停')
        paused[SOUND_EFFECT] = false
        Recovery.update(0.4); Recovery.update(0.4); Recovery.update(0.4)
        Recovery.focus(false)
        V.assert(Music.suspended and paused[SOUND_MUSIC], '切后台暂停音乐')
        playing = false
        Recovery.focus(true)
        restored('前台恢复')
        V.assert(not Music.suspended, '回前台允许战斗音乐播放')
        Recovery.update(0.4); Recovery.update(0.4); Recovery.update(0.4)
        rawset(_G, 'sdk', { ShowRewardVideoAd = function(_, cb)
            Recovery.focus(false)
            playing = false
            cb({ success = true })
            return true
        end })
        local backgroundReward = 0
        N.Ads.show(function(success) if success then backgroundReward = backgroundReward + 1 end end)
        V.assert(backgroundReward == 1 and not playing and paused[SOUND_MUSIC],
            '后台收到完成回调时发奖但不抢占音频输出')
        Recovery.focus(true)
        restored('后台广告完成后回前台')
        Recovery.update(0.4); Recovery.update(0.4); Recovery.update(0.4)
        N.Ads.busy = true
        Recovery.begin()
        Recovery.focus(false)
        playing = false
        Recovery.focus(true)
        V.assert(not playing and paused[SOUND_MUSIC], '广告尚未完成时焦点恢复不提前播放游戏声音')
        N.Ads.busy = false
        Recovery.finish()
        restored('先回前台后收到广告完成回调')
        paused[SOUND_EFFECT], paused[SOUND_MASTER] = true, true
        gains[SOUND_MUSIC] = 0
        Recovery.update(0.4)
        V.assert(paused[SOUND_EFFECT] and paused[SOUND_MASTER], '恢复窗口内不解除其他调用方新设的暂停')
        V.assert(gains[SOUND_MUSIC] == 0, '恢复窗口内不覆盖后来主动设置的零音量')
        Recovery.stop()
        V.assert(paused[SOUND_EFFECT] and paused[SOUND_MASTER], '停止恢复模块不解除未持有的暂停')
        paused[SOUND_EFFECT], paused[SOUND_MASTER], gains[SOUND_MUSIC] = false, false, 0.7
        Recovery.init()
        N.Ads.busy = true; Recovery.begin()
        paused[SOUND_MASTER] = true
        N.Ads.busy = false; Recovery.finish()
        V.assert(paused[SOUND_MASTER], '广告恢复不解除本模块从未暂停过的 MASTER')
        paused[SOUND_MASTER] = false
        Recovery.update(0.4); Recovery.update(0.4); Recovery.update(0.4)
        local suspend, stopped = N.Sound.suspendBackend, 0
        N.Sound.suspendBackend = function() stopped = stopped + 1; suspend() end
        N.Sound.on = false
        N.Sound.init()
        V.assert(stopped == 1, '关闭声音立即停止已经播放中的一次性音效')
        N.Sound.suspendBackend = suspend
        N.Sound.on = true; N.Sound.init()

        -- 音频恢复钩子异常不能阻断成功回调和业务奖励。
        local finishHook, beginHook = N.Ads.onFinish, N.Ads.onBegin
        N.Ads.onBegin = function() error('测试 begin 异常') end
        N.Ads.onFinish = function() error('测试 finish 异常') end
        rawset(_G, 'sdk', { ShowRewardVideoAd = function(_, cb) cb({ success = true }); return true end })
        local rewarded = 0
        N.Ads.show(function(success) if success then rewarded = rewarded + 1 end end)
        N.Ads.onFinish, N.Ads.onBegin = finishHook, beginHook
        V.assert(rewarded == 1 and not N.Ads.busy, '音频钩子异常不阻断奖励')

        local pending, synchronous = {}, 0
        local sample = Music.tracks.bgm_battle1
        rawset(_G, 'cache', {
            Exists = function(_, path) return path == 'local.wav' end,
            GetResource = function() synchronous = synchronous + 1; return sample end,
            GetResourceAsync = function(_, kind, path, done)
                V.assert(kind == 'Sound', '远端音频按 Sound 类型请求下载')
                pending[#pending + 1] = { path = path, done = done }
            end,
        })
        local localSound, remoteSound
        Assets.load('local.wav', function(sound) localSound = sound end)
        Assets.load('remote.ogg', function(sound) remoteSound = sound end)
        V.assert(localSound == sample and synchronous == 1, '已在本地的音频同步加载')
        V.assert(remoteSound == nil and #pending == 1, '未下载的音频发起异步请求，不直接跳过')
        pending[1].done(sample)
        V.assert(remoteSound == sample, '异步下载回调补齐声音资源')
        pending = {}
        Music.stop()
        Music.init(scene)
        local trackCount = 0
        for _ in pairs(Assets.music) do trackCount = trackCount + 1 end
        V.assert(trackCount == 17 and #pending == trackCount and next(Music.tracks) == nil,
            '冷启动为十章与首领的十七首音乐发起下载（含第六次更新新增 6 首）')
        for _, job in ipairs(pending) do job.done(sample) end
        V.assert(Music.tracks.bgm_battle1 == sample and Music.tracks.bgm_boss == sample, '下载完成后章节曲与首领曲均可用')
        pending = {}
        Music.stop(); Music.init(scene)
        local stale = pending
        Music.stop()
        for _, job in ipairs(stale) do job.done(sample) end
        V.assert(next(Music.tracks) == nil, '停止后迟到下载回调不写回资源')
        pending = {}
        Music.init(scene)
        local previous = pending
        pending = {}
        Music.init(scene)
        for _, job in ipairs(previous) do job.done(sample) end
        V.assert(next(Music.tracks) == nil, '重启后上一代下载回调不污染新音乐')
        for _, job in ipairs(pending) do job.done(sample) end
        V.assert(Music.tracks.bgm_boss == sample, '重启后只接收新一代下载结果')
    end, function(e) return tostring(e) end)
    N.Ads.cancel()
    Recovery.stop()
    Music.stop()
    Assets.load = oldLoad
    rawset(_G, 'audio', oldAudio)
    rawset(_G, 'cache', oldCache)
    rawset(_G, 'sdk', oldSdk)
    scene:Dispose()
    N.G, N.Sound.on, N.Sound.ready = oldGame, oldOn, oldReady
    N.Timers.list, N.Timers.now = timers, time
    V.assert(ok, '音频下载与广告恢复验收无异常：' .. tostring(err))
    V.finish()
end)
