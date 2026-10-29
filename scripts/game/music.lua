-- 双音源战斗音乐：资源缺失时静默跳过，不影响音效和战斗。
local N = require('game.env')
local Assets = require('game.audio_assets')
local Music = { VOLUME = 0.42, sources = {}, tracks = {}, enabled = true, generation = 0 }
local FILES = { 'bgm_battle1', 'bgm_battle2', 'bgm_battle3', 'bgm_battle4', 'bgm_battle5', 'bgm_battle6', 'bgm_battle7', 'bgm_boss',
    'bgm_c8', 'bgm_c9', 'bgm_c10', 'bgm_boss8', 'bgm_boss9', 'bgm_boss10',
    'home_a', 'home_b', 'home_c',
    -- 第十三次更新：分界面背景音乐
    'bgm_select', 'bgm_prep', 'bgm_shop' }
-- 章节使用零起始索引；旧第四、五章曲目不被新章节挤占。
local CHAPTER_TRACKS = {
    [0] = 'bgm_battle1', [1] = 'bgm_battle2', [2] = 'bgm_battle3',
    [3] = 'bgm_battle4', [4] = 'bgm_battle5', [5] = 'bgm_battle6', [6] = 'bgm_battle7',
    [7] = 'bgm_c8', [8] = 'bgm_c9', [9] = 'bgm_c10',
}
-- 首领曲：第八～十章各有专属首领曲，其余章节沿用通用首领曲。
local BOSS_TRACKS = { [7] = 'bgm_boss8', [8] = 'bgm_boss9', [9] = 'bgm_boss10' }

---@param scene Scene
function Music.init(scene)
    Music.generation = Music.generation + 1
    local generation = Music.generation
    Music.sources, Music.tracks = {}, {}
    Music.current = nil
    local node = scene:CreateChild('Music')
    for i = 1, 2 do
        local source = node:CreateComponent('SoundSource')
        source.soundType = SOUND_MUSIC
        source.gain = 0
        Music.sources[i] = { source = source, gain = 0 }
    end
    local completed, loaded = 0, 0
    for _, name in ipairs(FILES) do
        local path = Assets.music[name]
        Assets.load(path, function(sound)
            if generation ~= Music.generation then return end
            completed = completed + 1
            if sound and sound.length > 0 then
                sound.looped = true
                Music.tracks[name] = sound
                loaded = loaded + 1
            else
                print('[拉杆军团] 音乐加载失败，可重新进入重试：' .. path)
            end
            if completed == #FILES then print('[拉杆军团] 战斗音乐加载完成：' .. loaded .. '/' .. #FILES) end
        end)
    end
end

function Music.wanted()
    local game = N.G
    if not Music.enabled or Music.suspended or N.Ads.busy or not game or not N.Sound.on or not N.Sound.ready then return nil end
    local ui = N.UI --[[@as {els: table<string, any>}]]
    -- 主页：轮换主页曲（UI.showHome 每次回到主页换下一首）
    if ui.els.home and not ui.els.home:isHidden() then
        if game.tutorial then return nil end
        return ui.homeTrack or 'home_a'
    end
    -- 第十三次更新：界面各有专属曲。战斗（含教程战斗）仍用本章战斗曲 / 首领曲；
    -- 战斗中打开商店不换曲（G.phase == 'battle' 优先），其余情况按弹窗所属界面选曲。
    if game.phase == 'battle' and game.battle and not game.battle.over then
        if game.wave >= game.maxWave and not game.tutorial then
            return BOSS_TRACKS[game.ch] or 'bgm_boss'
        end
        return CHAPTER_TRACKS[game.ch]
    end
    -- 非战斗：看当前弹窗属于哪个界面（ui13 会给弹窗打 musicScreen 标记）
    local overlayOpen = ui.els.overlay and not ui.els.overlay:isHidden()
    if overlayOpen then
        local scr = ui.musicScreen
        if scr == 'select' then return 'bgm_select' end
        if scr == 'shop' then return 'bgm_shop' end
    end
    return 'bgm_prep'
end

-- 兼容上游 ui.lua 的显式选曲接口（本地以 wanted() 自动推导为主，
-- 这里仍提供 set 以便任何外部调用不会报错；显式指定时优先采用）。
function Music.set(name)
    Music.forced = name
end


function Music.update(dt)
    if #Music.sources == 0 then return end
    local wanted = Music.wanted()
    -- 曲目还没加载完（真机 DWP 按需下载）时先不切歌，但要保留 wanted 的意图：
    -- 以前这里直接把 wanted 置 nil，同时把 Music.current 清空，等于彻底放弃这首曲目，
    -- 等资源下载完成后也不会自动补播（表现为「某章进去没音乐，重开才有」）。
    local ready = wanted and Music.tracks[wanted] or nil
    if wanted and not ready then
        wanted = nil
    end
    if wanted and (not Music.current or Music.current.track ~= wanted) then
        local a, b = Music.sources[1], Music.sources[2]
        local slot = a.track == wanted and a or (b.track == wanted and b or (a.gain <= b.gain and a or b))
        if slot.track ~= wanted then
            slot.source:Stop()
            slot.track, slot.gain, slot.source.gain = wanted, 0, 0
            local ok = pcall(slot.source.Play, slot.source, Music.tracks[wanted], 0, 0)
            print('[拉杆军团] 战斗音乐开始：' .. wanted .. '，音源=' .. tostring(ok and slot.source:IsPlaying()))
        end
        Music.current = slot
    elseif not wanted then
        Music.current = nil
    end
    -- 重启已停止的音源：必须用「当前这首」的音轨，不能拿可能为 nil 的 wanted 去查。
    if Music.current and not Music.current.source:IsPlaying() then
        local track = Music.tracks[Music.current.track]
        if track then
            pcall(Music.current.source.Play, Music.current.source, track, 0, Music.current.gain * Music.VOLUME)
            print('[拉杆军团] 重新启动战斗音乐：' .. tostring(Music.current.track))
        end
    end
    for _, slot in ipairs(Music.sources) do
        if slot.track then
            local gain = slot == Music.current and math.min(1, slot.gain + dt / 0.8) or math.max(0, slot.gain - dt / 1.2)
            slot.gain = gain
            slot.source.gain = gain * Music.VOLUME
            if not N.Sound.on or N.Ads.busy or Music.suspended or not Music.enabled then slot.source.gain = 0 end
            if gain <= 0 and slot ~= Music.current then slot.source:Stop(); slot.track = nil end
        end
    end
end

function Music.stop()
    Music.generation = Music.generation + 1
    for _, slot in ipairs(Music.sources) do slot.source:Stop() end
    Music.sources, Music.tracks, Music.current = {}, {}, nil
end

return Music
