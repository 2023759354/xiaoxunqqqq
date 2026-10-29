function Start()
    local App = require('game.app')
    App.boot({ vw = 960, vh = 540, envVars = {}, nowMs = 0 })
    local N = require('game.env')
    local D = N.FX.D
    -- 收集 skillfx2 注册的动画 kind（它们在 D 里，且不在 skillfx 原有集合）
    local kinds = {}
    for k, v in pairs(D) do if type(v) == 'function' then kinds[#kinds+1] = k end end
    table.sort(kinds)
    print("[fx2] D 中动画 kind 数=" .. #kinds)
    -- 对每个 kind，用极端值调 3 次，测单次耗时
    local bad = {}
    for _, kind in ipairs(kinds) do
        for _, h in ipairs({ 14, 1e6, math.huge, 0/0 }) do
            local a = { kind = kind, x = 50, y = 60, r = 10, h = h, n = 5, col = '#fff', col2 = '#000',
                t = 0.2, dur = 0.6, delay = 0, layer = 0, k = 0.5 }
            local t0 = os.clock()
            local ok = pcall(function() D[kind](a, 0.5, 50, 60) end)
            local d = os.clock() - t0
            if d > 0.5 then bad[#bad+1] = kind .. "(h=" .. tostring(h) .. ")=" .. string.format('%.2fs', d) end
            if not ok then bad[#bad+1] = kind .. "(h=" .. tostring(h) .. ")=ERR" end
        end
    end
    print("[fx2] 异常项 " .. #bad .. " 个")
    for i = 1, math.min(#bad, 15) do print("[fx2]   " .. bad[i]) end
    engine:Exit()
end
