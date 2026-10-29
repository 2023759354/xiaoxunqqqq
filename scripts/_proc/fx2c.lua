function Start()
    local App = require('game.app')
    App.boot({ vw = 960, vh = 540, envVars = {}, nowMs = 0 })
    local N = require('game.env')
    local D = N.FX.D
    local kinds = {}
    for k, v in pairs(D) do if type(v) == 'function' then kinds[#kinds+1] = k end end
    table.sort(kinds)
    -- 写入文件，避免日志丢失
    local out = io.open('/tmp/fx2c_result.txt', 'w')
    for _, kind in ipairs(kinds) do
        for _, h in ipairs({ 1e9, math.huge }) do
            local a = { kind = kind, x = 50, y = 60, r = 1e9, h = h, n = 1e9, col = '#fff', col2 = '#000', t = 0.2, dur = 0.6, delay = 0, layer = 0 }
            local t0 = os.clock()
            local ok, err = pcall(function() D[kind](a, 0.5, 50, 60) end)
            local d = os.clock() - t0
            if out then out:write(string.format("%s h=%s 耗时=%.3f ok=%s\n", kind, tostring(h), d, tostring(ok))) out:flush() end
            if d > 0.3 then break end
        end
    end
    if out then out:close() end
    engine:Exit()
end
