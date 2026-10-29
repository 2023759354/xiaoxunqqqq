-- ============================================================================
-- setTimeout / clearTimeout：按毫秒时钟触发（时钟由主循环推进）
-- 同一时刻到期的按「到期时间，再按注册顺序」执行，和浏览器一致
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")

Timers = { now = 0, list = {}, seq = 0 }

function setTimeout(fn, ms)
    Timers.seq = Timers.seq + 1
    local t = { id = Timers.seq, at = Timers.now + math.max(0, ms or 0), fn = fn }
    Timers.list[#Timers.list + 1] = t
    return t.id
end

function clearTimeout(id)
    if not id then return end
    for i, t in ipairs(Timers.list) do
        if t.id == id then table.remove(Timers.list, i); return end
    end
end

--- 推进时钟并执行到期的回调（回调里新注册的定时器若也已到期，同一轮里继续执行）
function Timers.advance(nowMs)
    Timers.now = nowMs
    while true do
        local best, bi = nil, nil
        for i, t in ipairs(Timers.list) do
            if t.at <= nowMs and (not best or t.at < best.at or (t.at == best.at and t.id < best.id)) then best, bi = t, i end
        end
        if not best then break end
        table.remove(Timers.list, bi)
        best.fn()
    end
end

return Timers
