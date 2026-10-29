function Start()
    local App = require('game.app')
    print("[fx2b] app ok")
    App.boot({ vw = 960, vh = 540, envVars = {}, nowMs = 0 })
    print("[fx2b] boot ok")
    local N = require('game.env')
    local D = N.FX.D
    local kinds = {}
    for k, v in pairs(D) do if type(v) == 'function' then kinds[#kinds+1] = k end end
    print("[fx2b] kind 数=" .. #kinds)
    -- 只测第一个 kind 的正常值
    local kind = kinds[1]
    print("[fx2b] 测 kind=" .. kind)
    local a = { kind = kind, x = 50, y = 60, r = 10, h = 14, n = 5, col = '#fff', col2 = '#000', t = 0.2, dur = 0.6, delay = 0, layer = 0 }
    local ok, err = pcall(function() D[kind](a, 0.5, 50, 60) end)
    print("[fx2b] 正常值 ok=" .. tostring(ok) .. " err=" .. tostring(err))
    engine:Exit()
end
