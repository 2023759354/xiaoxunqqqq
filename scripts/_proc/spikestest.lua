function Start()
    local App = require('game.app')
    App.boot({ vw = 960, vh = 540, envVars = {}, nowMs = 0 })
    local N = require('game.env')
    local out = io.open('/tmp/spikes.txt', 'w')
    for _, h in ipairs({ 10, 1e6, 1e9, math.huge }) do
        local a = { kind = 'spikes', x = 50, y = 60, r = 1e9, h = h, n = 1e9, w = 4,
            col = '#fff', col2 = '#000', t = 0.2, dur = 0.6, delay = 0, layer = 0 }
        local t0 = os.clock()
        pcall(function() N.FX.D.spikes(a, 0.5, 50, 60) end)
        local d = os.clock() - t0
        if out then out:write(string.format("h=%s 耗时=%.3f\n", tostring(h), d)) out:flush() end
        if d > 1 then break end
    end
    if out then out:close() end
    engine:Exit()
end
