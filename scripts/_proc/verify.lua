function Start()
    local App = require('game.app')
    App.boot({ vw = 960, vh = 540, envVars = {}, nowMs = 0 })
    local N = require('game.env')
    local D = N.FX.D
    local kinds = {}
    for k, v in pairs(D) do if type(v) == 'function' then kinds[#kinds+1] = k end end
    table.sort(kinds)
    local bad, maxd = 0, 0
    for _, kind in ipairs(kinds) do
        for _, h in ipairs({ 14, 1e9, math.huge, 0/0, -math.huge }) do
            local a = { kind = kind, x = 50, y = 60, r = 1e9, h = h, n = 1e9, L = 1e9,
                col = '#fff', col2 = '#000', t = 0.2, dur = 0.6, delay = 0, layer = 0 }
            local t0 = os.clock()
            pcall(function() D[kind](a, 0.5, 50, 60) end)
            local d = os.clock() - t0
            if d > maxd then maxd = d end
            if d > 0.2 then bad = bad + 1 end
        end
    end
    print(string.format("[verify] 测了 %d 个 kind x 5 种极端值, 慢于200ms的=%d, 最慢=%.3fs",
        #kinds, bad, maxd))
    engine:Exit()
end
