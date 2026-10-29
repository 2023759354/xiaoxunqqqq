function Start()
    local App = require('game.app')
    App.boot({ vw = 960, vh = 540, envVars = {}, nowMs = 0 })
    local N = require('game.env')
    local out = io.open('/tmp/rest.txt', 'w')
    for _, kind in ipairs({ 'spikes', 'steam', 'timber', 'vinewrap', 'wings', 'ghost', 'expbar' }) do
        local a = { kind = kind, x = 50, y = 60, r = 1e9, h = 1e9, n = 1e9, L = 1e9, w = 1e9,
            col = '#fff', col2 = '#000', t = 0.2, dur = 0.6, delay = 0, layer = 0, ent = nil }
        local t0 = os.clock()
        local ok, err = pcall(function() N.FX.D[kind](a, 0.5, 50, 60) end)
        local d = os.clock() - t0
        if out then out:write(string.format("%s 耗时=%.3f ok=%s %s\n", kind, d, tostring(ok), tostring(err))) out:flush() end
        if d > 1 then break end
    end
    if out then out:close() end
    engine:Exit()
end
