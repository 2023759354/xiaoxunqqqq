-- 复现纯 NanoVG 游戏首次广告时的 UI 装配顺序；不请求真实广告、不写玩家存档。
local V = assert(rawget(_G, 'V'), '本脚本只供 -validate-test 使用') --[[@as table<string, any>]]
local N = require('game.env') --[[@as table<string, any>]]
local baseline = false
for _, arg in ipairs(GetArguments()) do
    if arg == '-inspector-baseline' then baseline = true end
end

V.atFrame(15, function()
    local core = require('urhox-libs/UI/Core/UI') --[[@as table<string, any>]]
    local oldSdk, oldEnv, rawLog = rawget(_G, 'sdk'), rawget(_G, 'GetTapMakerEnvString'), rawget(_G, 'log')
    local oldLog = log
    local oldRequire = require
    local entry = 'urhox-libs/UI'
    local loaded, inspector = package.loaded[entry], core.Inspector
    local beginHook, finishHook = N.Ads.onBegin, N.Ads.onFinish
    local errors, calls, begins, finishes, completed, rewards = 0, 0, 0, 0, 0, 0
    local ok, err = xpcall(function()
        V.assert(core.GetNVGContext() == nil, '冷启动时游戏未创建广告 UI 上下文')
        core.Inspector = nil
        package.loaded[entry] = nil
        rawset(_G, 'GetTapMakerEnvString', function() return 'preview' end)
        rawset(_G, 'log', { Write = function(_, level, message)
            if message:find('UI Inspector requested but failed to load', 1, true) then
                errors = errors + 1
            end
            oldLog:Write(level, message)
        end })
        N.Ads.onBegin = function() begins = begins + 1 end
        N.Ads.onFinish = function() finishes = finishes + 1 end
        rawset(_G, 'sdk', { ShowRewardVideoAd = function(_, callback)
            calls = calls + 1
            if not baseline then
                local preparedInspector = core.Inspector --[[@as table<string, any>?]]
                V.assert(preparedInspector ~= nil and type(preparedInspector.Init) == 'function',
                    '调用 SDK 前已装配真实检查器，不是假占位对象')
                V.assert(core.GetNVGContext() == nil, '依赖准备不提前初始化或修改 UI 配置')
            end
            -- 与 FakeAd 首次展示相同：直接通过 Core UI 初始化。
            core.Init({ scale = function() return graphics:GetDPR() end, autoEvents = false, useInspector = true })
            callback({ success = true, msg = 'test complete' })
            callback({ success = true, msg = 'test duplicate' })
            return true
        end })
        N.Ads.show(function(success)
            completed = completed + 1
            if success then rewards = rewards + 1 end
        end)
        V.assert(calls == 1, '只请求一次 SDK')
        V.assert(completed == 1 and rewards == 1, '完整观看重复回调只结算一次')
        V.assert(begins == 1 and finishes == 1 and not N.Ads.busy, '开始结束各一次且广告锁释放')
        V.assert(errors == (baseline and 1 or 0), baseline
            and '修复前对照准确复现原文错误' or '修复后真实 Core 初始化不再报检查器错误')
        if not baseline then
            V.assert(rawget(_G, 'UI_INSPECTOR_ENABLED') == true, '检查器真实初始化成功')
        end
        -- Shutdown 要求已装配检查器，先补齐后再清理对照运行。
        if not core.Inspector then oldRequire(entry) end
        core.Shutdown()

        if baseline then return end
        local function failedPreparation(loader, label)
            local beforeCalls, beforeBegins, beforeFinishes = calls, begins, finishes
            local results, successful = 0, false
            rawset(_G, 'require', function(name)
                if name == entry then return loader() end
                return oldRequire(name)
            end)
            N.Ads.show(function(success, message)
                results = results + 1
                successful = success
                V.assert(message == 'ui-unavailable', label .. '：返回明确失败原因')
            end)
            rawset(_G, 'require', oldRequire)
            V.assert(results == 1 and not successful, label .. '：只失败一次，不发奖')
            V.assert(calls == beforeCalls, label .. '：不进入缺依赖的广告 UI 路径')
            V.assert(begins == beforeBegins and finishes == beforeFinishes,
                label .. '：不暂停音频，也不错误恢复其他模块的暂停')
            V.assert(not N.Ads.busy, label .. '：不留下广告锁')
        end
        failedPreparation(function() error('测试 UI 入口加载失败') end, '入口异常')
        failedPreparation(function() return {} end, '入口成功但检查器缺失')
        failedPreparation(function() return { Inspector = {} } end, '检查器缺少 Init')

        -- 原生正式环境不应因可选的预览检查器依赖而失去广告能力。
        rawset(_G, 'GetTapMakerEnvString', function() return 'release' end)
        local uiLoads = 0
        rawset(_G, 'require', function(name)
            if name == entry then uiLoads = uiLoads + 1; error('正式广告不应加载此依赖') end
            return oldRequire(name)
        end)
        rawset(_G, 'sdk', { ShowRewardVideoAd = function(_, callback)
            callback({ success = false, msg = 'native close' })
            return false
        end })
        local nativeResults = 0
        N.Ads.show(function(success)
            nativeResults = nativeResults + 1
            V.assert(not success, '正式广告提前关闭不发奖')
        end)
        V.assert(nativeResults == 1 and not N.Ads.busy, '正式环境同步回调加返回 false 只结算一次')
        V.assert(uiLoads == 0, '正式环境不把检查器变成广告硬依赖')
    end, debug.traceback)
    rawset(_G, 'require', oldRequire)
    rawset(_G, 'sdk', oldSdk)
    rawset(_G, 'GetTapMakerEnvString', oldEnv)
    rawset(_G, 'log', rawLog)
    N.Ads.onBegin, N.Ads.onFinish = beginHook, finishHook
    N.Ads.cancel()
    if core.GetNVGContext() then
        if not core.Inspector then oldRequire(entry) end
        core.Shutdown()
    end
    core.Inspector = inspector
    package.loaded[entry] = loaded
    V.assert(ok, '预览广告初始化回归无异常：' .. tostring(err or ''))
    V.finish()
end)
