-- ============================================================================
-- 激励视频广告：统一入口
-- 只有完整看完（result.success == true）才算成功；玩家中途关闭不给奖励
-- sdk:ShowRewardVideoAd 的返回值与回调都可能触发，这里用一次性状态收敛
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
require("game.timers")

Ads = {}
Ads.busy = false       -- 同一时刻只允许一个广告请求
-- 兜底超时（毫秒）：广告没回调也要解锁界面。
-- 真机上 SDK 一般在几秒内回调；卡住时 120 秒太久——这期间再点「看广告」全被 busy 挡掉，
-- 玩家就会反复点。30 秒没结果按失败处理并放开重试。
Ads.TIMEOUT = 30000
---@type function?
local cancelPending = nil

local function audioHook(hook)
    if not hook then return end
    local ok, err = pcall(hook)
    if not ok then print('[拉杆军团] 广告音频处理失败：' .. tostring(err)) end
end

-- 退出或重载时作废在途请求，迟到回调不能给新游戏发奖励。
function Ads.cancel()
    local wasBusy = Ads.busy
    if cancelPending then cancelPending() end
    Ads.busy = false
    if wasBusy then audioHook(Ads.onFinish) end
end

--- 当前环境是否可能真的能播广告。
--- 非手机宿主（PC / Web 调试）上 SDK 一律返回 unsupported，这里提前问一句，
--- 避免玩家点了「看广告」才发现播不了。
---@return boolean
function Ads.available()
    local platform, native = '', ''
    if GetPlatform then local ok, v = pcall(GetPlatform); if ok and v then platform = tostring(v) end end
    if GetNativePlatform then local ok, v = pcall(GetNativePlatform); if ok and v then native = tostring(v) end end
    return platform == 'Android' or platform == 'iOS' or platform == 'HarmonyOS'
        or native == 'Android' or native == 'iOS' or native == 'HarmonyOS'
end

--- 播放一段激励视频。onDone(ok, msg) 保证最多回调一次
--- 失败分支不区分原因：真正的发奖判定只看 result.success
---@param onDone fun(ok: boolean, msg: string)
function Ads.show(onDone)
    if Ads.busy then onDone(false, 'busy'); return end
    local api = rawget(_G, 'sdk')
    if not api or type(api.ShowRewardVideoAd) ~= 'function' then
        print('[拉杆军团] 广告不可用：当前环境没有 sdk:ShowRewardVideoAd')
        onDone(false, 'unsupported')
        return
    end
    -- 预览的 FakeAd 直接初始化 UI Core；完整入口才会装配 UI.Inspector。
    -- 必须在 SDK 首次展示前补齐依赖，但不主动 Init，避免改变游戏或广告的 UI 配置。
    -- 正式宿主的原生广告不依赖预览检查器，不增加此项前置条件。
    local inPreview = false
    if GetTapMakerEnvString then
        local ok, env = pcall(GetTapMakerEnvString)
        inPreview = ok and env == 'preview'
    end
    if inPreview then
        local loaded, previewUI = pcall(require, 'urhox-libs/UI')
        if not loaded or type(previewUI) ~= 'table' or not previewUI.Inspector
            or type(previewUI.Inspector.Init) ~= 'function' then
            print('[拉杆军团] 预览广告 UI 未就绪：' .. tostring(loaded and '检查器未装配' or previewUI))
            onDone(false, 'ui-unavailable')
            return
        end
    end
    Ads.busy = true
    local settled = false
    ---@type integer?
    local timer = nil
    cancelPending = function()
        settled = true
        if timer then clearTimeout(timer); timer = nil end
        cancelPending = nil
    end
    local function finish(ok, msg)
        if settled then return end
        settled = true
        Ads.busy = false
        cancelPending = nil
        if timer then clearTimeout(timer); timer = nil end
        print('[拉杆军团] 广告结果：' .. (ok and 'success' or 'fail') .. '（' .. tostring(msg or '') .. '）')
        audioHook(Ads.onFinish)
        onDone(ok, msg or '')
    end
    if not settled then
        audioHook(Ads.onBegin)
    end
    local fired = false
    local called, accepted = pcall(function()
        return api:ShowRewardVideoAd(function(result)
            fired = true
            finish(type(result) == 'table' and result.success == true, type(result) == 'table' and result.msg or '')
        end)
    end)
    if not called then
        print('[拉杆军团] 广告 SDK 异常：' .. tostring(accepted))
        finish(false, 'exception')
        return
    end
    -- 返回 false 且回调没同步触发：请求未被受理，直接判失败
    if accepted == false and not fired then
        finish(false, 'unavailable')
        return
    end
    if not settled then timer = setTimeout(function() finish(false, 'timeout') end, Ads.TIMEOUT) end
end

return true
