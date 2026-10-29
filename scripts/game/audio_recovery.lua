-- 广告与前后台切换的音频恢复，不改变玩家的声音开关。
local N = require('game.env')
local Music = require('game.music')
local Recovery = { alive = false, foreground = true, remaining = 0, elapsed = 0, holding = false }
---@type table<string, {paused: boolean, gain: number}>?
local saved = nil
local TYPES = { SOUND_MASTER, SOUND_MUSIC, SOUND_EFFECT }

local function hold()
    if Recovery.holding then return end
    local state = {}
    for _, kind in ipairs(TYPES) do
        state[kind] = { paused = audio:IsSoundTypePaused(kind), gain = audio:GetMasterGain(kind) }
    end
    saved = state
    Recovery.holding = true
    Recovery.remaining = 0
    audio:PauseSoundType(SOUND_MUSIC)
    audio:PauseSoundType(SOUND_EFFECT)
    if N.Sound.suspendBackend then N.Sound.suspendBackend() end
end

function Recovery.init()
    Recovery.alive, Recovery.foreground, Recovery.holding = true, true, false
    Recovery.remaining, Recovery.elapsed = 0, 0
    Music.suspended = false
    saved = nil
end

function Recovery.begin()
    if not Recovery.alive then return end
    hold()
    Music.update(0)
    print('[拉杆军团] 广告开始：暂停游戏音频')
end

function Recovery.resume(reason)
    if not Recovery.alive or not Recovery.foreground or N.Ads.busy then return end
    -- 即使玩家静音，也要释放本模块的暂停，避免下次开声音仍被锁住。
    if saved then
        for _, kind in ipairs(TYPES) do
            local state = saved[kind]
            if kind ~= SOUND_MASTER and not state.paused then audio:ResumeSoundType(kind) end
            if state.gain > 0 and audio:GetMasterGain(kind) == 0 then audio:SetMasterGain(kind, state.gain) end
        end
        -- 暂停与音量快照只恢复一次；后续重试只检查混音输出和音乐音源。
        saved = nil
    end
    Recovery.holding = false
    local ok = audio:IsPlaying()
    -- 不再用 audio:IsInitialized() 做前置条件：它反映的是「音频子系统是否已建好」，
    -- 首次启动、刚切回前台、真机音频焦点被抢后该值可能是 false，而 audio:Play()
    -- 恰恰是把它重新建起来/拉起来的入口。以前这里一旦 IsInitialized=false 就永远
    -- 不会调用 Play，混音器保持关闭 —— SoundSource 显示 IsPlaying=true 但完全没有输出，
    -- 表现就是「音乐音效都没声，但日志一切正常」。
    if N.Sound.on and N.Sound.ready and not ok then
        local played, ret = pcall(audio.Play, audio)
        if played and ret ~= false then ok = audio:IsPlaying() end
    end
    Music.update(0)
    if reason then
        print('[拉杆军团] 音频恢复检查：' .. reason .. '，输出=' .. tostring(ok) ..
            '，初始化=' .. tostring(audio:IsInitialized()) ..
            '，音乐=' .. tostring(Music.current and Music.current.track or '非战斗阶段'))
    end
end

function Recovery.finish()
    if not Recovery.alive then return end
    -- 广告播完回到游戏：原生广告常抢走音频会话焦点（iOS AVAudioSession / Android AudioFocus），
    -- 回来后混音输出可能还是停的。这里只补「让输出重新播放」，不解除玩家自己按下的暂停
    -- （音量/暂停快照由 resume 按保存的状态精确还原）。
    -- 注意：只有回到前台才恢复输出；应用还在后台时收到回调（广告在别的 app 里播完）
    -- 不能抢占音频输出，等真正回到前台再由 resume 处理。
    Music.suspended = false
    if Recovery.foreground and N.Sound.on and N.Sound.ready
        and audio:IsInitialized() and not audio:IsPlaying() then
        pcall(audio.Play, audio)
    end
    Music.update(0)
    Recovery.remaining, Recovery.elapsed = 3, 0
    Recovery.resume('广告返回')
end

function Recovery.focus(foreground)
    if not Recovery.alive then return end
    -- 前台事件可能重复派发（引擎同时有 AppWillEnterForeground / AppDidEnterForebackground），
    -- 不能因为「状态没变」就跳过：广告期间 hold() 建立的暂停要靠这次恢复来解除，
    -- 否则重复回调反而会把已暂停的音频永久锁死。
    local changed = Recovery.foreground ~= foreground
    Recovery.foreground = foreground
    Music.suspended = not foreground
    if foreground then
        Recovery.remaining, Recovery.elapsed = 3, 0
        Recovery.resume('回到前台')
    elseif changed then
        hold()
        Music.update(0)
    end
end

function Recovery.update(dt)
    -- 混音器自愈（与恢复窗口无关，独立计时）：真机上音频输出可能被系统、宿主、
    -- 广告 SDK 或来电等外部事件停掉，而我们的 SoundSource 仍是「正在播放」状态。
    -- 这时玩家会听到「彻底没声音但一切正常」。每 2 秒检查一次，停了就拉起来。
    Recovery.watchdog = (Recovery.watchdog or 0) + (dt or 0)
    if Recovery.watchdog >= 2 then
        Recovery.watchdog = 0
        if Recovery.alive and Recovery.foreground and not N.Ads.busy and not Recovery.holding
            and N.Sound.on and N.Sound.ready and not audio:IsPlaying() then
            local played, ret = pcall(audio.Play, audio)
            print('[拉杆军团] 音频输出已停止，尝试恢复：' .. tostring(played) .. '/' .. tostring(ret))
        end
    end
    if Recovery.remaining <= 0 or not Recovery.foreground or N.Ads.busy then return end
    Recovery.elapsed = Recovery.elapsed + dt
    if Recovery.elapsed < 0.35 then return end
    Recovery.elapsed = 0
    Recovery.remaining = Recovery.remaining - 1
    Recovery.resume()
    -- 快照只用于这次恢复窗口，不能在以后的用户操作中恢复陈旧音量。
    if Recovery.remaining <= 0 then saved = nil end
end

function Recovery.stop()
    Recovery.alive = false
    Recovery.remaining = 0
    if saved then
        for _, kind in ipairs(TYPES) do
            if kind ~= SOUND_MASTER and not saved[kind].paused then audio:ResumeSoundType(kind) end
        end
    end
    Recovery.holding = false
    saved = nil
end

return Recovery
