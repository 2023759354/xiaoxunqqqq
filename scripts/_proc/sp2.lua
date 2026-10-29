function Start()
    local App = require('game.app')
    App.boot({ vw = 960, vh = 540, envVars = {}, nowMs = 0 })
    local N = require('game.env')
    local out = io.open('/tmp/sp2.txt', 'w')
    local a = { kind = 'spikes', x = 50, y = 60, r = 1e9, h = 1e9, n = 1e9, L = 1e9, w = 1e9,
        col = '#fff', col2 = '#000', t = 0.2, dur = 0.6, delay = 0, layer = 0 }
    local t0 = os.clock()
    local ok, err = pcall(function() N.FX.D.spikes(a, 0.5, 50, 60) end)
    if out then out:write(string.format("spikes(L=1e9) 耗时=%.3f ok=%s %s\n", os.clock()-t0, tostring(ok), tostring(err))) out:close() end
    engine:Exit()
end
