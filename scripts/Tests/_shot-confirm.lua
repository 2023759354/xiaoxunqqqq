-- 仅用于截图确认框外观
local V = assert(rawget(_G, 'V'), 'validate only')
V.atFrame(20, function()
    local N = require('game.env') --[[@as table<string, any>]]
    N.TUT.stop()
    N.UI.els.home:setHidden(true)
    N.UI.els.overlay:setHidden(true)
end)
V.atFrame(60, function()
    local N = require('game.env') --[[@as table<string, any>]]
    local src = N.summon('warrior', 3, 0).nu
    local dst = N.summon('warrior', 1, 0).nu
    N.dropAt(src, N.findSlot(src), N.findSlot(dst))
end)
V.atFrame(90, function() end)
