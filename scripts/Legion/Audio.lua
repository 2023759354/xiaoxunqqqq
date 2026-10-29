-- 复古短音效：本地 WAV，无外部服务依赖；复用声道并持有 Scene 生命周期。
local Audio = { enabled = true, next = 1, channels = {}, sounds = {} }
---@type Scene?
local audioScene = nil

function Audio.Init()
    audioScene = Scene()
    local names = { "lever", "tick", "stop", "win", "jackpot", "fight", "hit", "skill", "victory", "defeat", "merge", "up", "deny" }
    for _, name in ipairs(names) do
        Audio.sounds[name] = cache:GetResource("Sound", "audio/Sounds/" .. name .. ".ogg")
    end
    for i = 1, 8 do
        local node = audioScene:CreateChild("声道" .. i)
        local source = node:CreateComponent("SoundSource")
        source:SetSoundType("Effect")
        Audio.channels[i] = source
    end
    print("[拉杆军团] 本地复古音效加载完毕")
end

---@param name string
function Audio.Play(name)
    if not Audio.enabled then return end
    local sound = Audio.sounds[name]
    local source = Audio.channels[Audio.next] --[[@as SoundSource?]]
    if source and sound then
        source:Play(sound, 0, name == "hit" and 0.16 or 0.42)
        Audio.next = Audio.next % 8 + 1
    end
end

---@return boolean
function Audio.Toggle()
    Audio.enabled = not Audio.enabled
    if not Audio.enabled then
        for _, source in ipairs(Audio.channels) do source:Stop() end
    end
    return Audio.enabled
end

function Audio.Stop()
    for _, source in ipairs(Audio.channels) do source:Stop() end
    Audio.channels, Audio.sounds = {}, {}
    if audioScene then audioScene:Dispose() end
    audioScene = nil
end
return Audio
