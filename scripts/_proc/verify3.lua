function Start()
    local App = require('game.app')
    App.boot({ vw = 960, vh = 540, envVars = {}, nowMs = 0 })
    local N = require('game.env')
    local D = N.FX.D
    local kinds = {}
    for k, v in pairs(D) do if type(v) == 'function' then kinds[#kinds+1] = k end end
    table.sort(kinds)
    local out = io.open('/tmp/verify3.txt', 'w')
    for _, kind in ipairs(kinds) do
        if out then out:write("BEGIN " .. kind .. "\n") out:flush() end
        local a = { kind = kind, x = 50, y = 60, r = 1e9, h = 1e9, n = 1e9, L = 1e9, w = 1e9,
            col = '#fff', col2 = '#000', t = 0.2, dur = 0.6, delay = 0, layer = 0 }
        local t0 = os.clock()
        pcall(function() D[kind](a, 0.5, 50, 60) end)
        if out then out:write(string.format("END %s %.3f\n", kind, os.clock()-t0)) out:flush() end
    end
    if out then out:close() end
    engine:Exit()
end
