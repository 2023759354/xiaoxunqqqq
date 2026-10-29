-- ============================================================================
-- 老虎机：拉杆、转轴动画、连线结算（逐行移植自原版）
-- ============================================================================
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local A, T, S, OR = js.A, js.T, js.S, js.OR
local floor, max, min = math.floor, math.max, math.min

function easeOutBack(k)
    local c1 = 1.3
    local c3 = c1 + 1
    return 1 + c3 * (k - 1) ^ 3 + c1 * (k - 1) ^ 2
end

function startSpin()
    ---@type table<string, any>
    local UI = UI
    local G = G --[[@as table<string, any>]]
    if G.phase ~= 'prep' then return end
    local free = G.freeSpins > 0
    if not free and G.gold < spinCost() then Sound.play('deny'); UI.banner('金币不足，开战赢取更多金币', 'red'); return end
    local stamped = paySpin()
    G.stats.spins = G.stats.spins + 1
    G.sel = nil
    local Sl = G.slot --[[@as table<string, any>]]
    -- 教程会预设前两次的结果
    if G.rig and #G.rig > 0 then Sl.next = G.rig:shift() else beforeSpin(); Sl.next = afterRollGrid(rollGrid()) end
    Sl.show = A(); Sl.t = 0; Sl.spinning = true; Sl.stopped = A(false, false, false)
    for c = 0, 2 do
        local strip = A(pick(G.symW.keys), Sl.next[c], Sl.next[3 + c], Sl.next[6 + c])
        local extra = 10 + c * 4
        local fill = squadSyms():concat('S', squadSyms()) -- 转动时的陪衬图案也只用本局的兵种
        for i = 0, extra - 1 do strip:push(pick(fill)) end
        strip:push(Sl.grid[c], Sl.grid[3 + c], Sl.grid[6 + c])
        Sl.strips[c] = strip; Sl.off[c] = (#strip - 3) * 22
    end
    G.phase = 'spinning'
    Sound.play('lever')
    UI.pullLever()
    if stamped then UI.toast('集满 ' .. S(stampGoal()) .. ' 点：下一次拉杆免费') end
end

function updateSlot(dt)
    ---@type table<string, any>
    local UI = UI
    local Sl = G.slot --[[@as table<string, any>]]
    if Sl.spinning then
        Sl.t = Sl.t + dt
        local done = true
        for c = 0, 2 do
            local n = #Sl.strips[c]
            local o0, o1 = (n - 3) * 22, 22
            local k = min(1, Sl.t / Sl.dur[c])
            local o = o1 + (o0 - o1) * (1 - easeOutBack(k))
            if floor(o / 22) ~= floor(Sl.off[c] / 22) and k < 0.97 then Sound.play('tick') end
            Sl.off[c] = o
            if k < 1 then done = false
            elseif not Sl.stopped[c] then Sl.stopped[c] = true; Sound.play('stop') end
        end
        if done then
            Sl.spinning = false; Sl.grid = Sl.next
            Sl.jack = jackpotSym(Sl.grid)
            Sl.wins = Sl.jack and A() or evalGrid(Sl.grid); Sl.ri = 0; Sl.rt = 0
            G.phase = 'resolving'
            if Sl.jack then resolveJackpot(Sl.jack)
            elseif #Sl.wins == 0 then
                UI.toast((G.luck < OR(G.luckMax, 3) - 1) and '没有连线，幸运 +1' or '没有连线，幸运已满：★ 更容易出现')
            end
        end
    end
    if G.phase == 'resolving' then
        Sl.rt = Sl.rt + dt
        while Sl.ri < #Sl.wins and Sl.rt >= Sl.ri * 0.34 do resolveOne(Sl.wins[Sl.ri]); Sl.ri = Sl.ri + 1 end
        local hold = Sl.jack and 1.1 or (#Sl.wins * 0.34 + 0.2)
        if Sl.ri >= #Sl.wins and Sl.rt >= hold then
            local n = #Sl.wins
            afterSpin(Sl.jack and 1 or n)
            if n >= 3 then UI.banner('大奖！连中 ' .. S(n) .. ' 条线', 'gold'); UI.shakeCabinet(); Sound.play('jackpot') end
            Sl.jack = nil
            G.phase = 'prep'
        end
    end
end

function announceSummon(r, head)
    ---@type table<string, any>
    local UI = UI
    local u = r.nu
    local q = u.q or 0
    local msg
    if r.displaced then
        msg = '位置已满，' .. fullName(u) .. ' 顶替了 ' .. fullName(r.displaced) .. (r.sold and ('（折算为 ' .. S(r.coins or 2) .. ' 金币）') or ('（被 ' .. fullName(r.into) .. ' 吸收）'))
    elseif r.into then msg = '位置已满，新' .. fullName(u) .. '被 ' .. fullName(r.into) .. ' 吸收'
    elseif r.sold then msg = '阵地和备战席都满了，新' .. fullName(u) .. '折算为 ' .. S(r.coins or 2) .. ' 金币'
    else msg = isSup(u) and (fullName(u) .. ' 降世') or ('召唤 ' .. fullName(u)) end
    if r.redirect then msg = CLASSES[r.redirect].name .. '的超凡角色已在场，改为' .. fullName(u) .. '降世' .. (r.displaced and ('；' .. msg) or '') end
    if r.fallback then msg = '三个兵种的超凡角色都已在场，改为召唤' .. fullName(u) end
    UI.toast(msg)
    if T(head) then UI.banner(head .. '：' .. fullName(u), T(q) and ('q' .. S(q)) or 'gold')
    elseif q >= 2 then UI.banner(QUAL[q].call .. '：' .. unitName(u), 'q' .. S(q)) end
end
function resolveOne(w)
    local Sl = G.slot --[[@as table<string, any>]]
    Sl.show:push({ li = w.li, sym = w.sym, t = G.time })
    local r = applyWin(w)
    Sound.play('win')
    announceSummon(r, (w.sym == 'S') and '星辉连线' or '')
end
function resolveJackpot(sym)
    ---@type table<string, any>
    local UI = UI
    local Sl, t = G.slot, G.time
    local r = applyJackpot(sym)
    local col = QUAL[isSup(r.nu) and Q_SUP or Q_MAX].color
    Sl.show = LINES:map(function(_, li) return { li = li, sym = sym, t = t, col = col } end)
    if not r.displaced and (r.into or r.sold) then Sound.play('jackpot') end -- 上场了的话召唤特效已经放过传说音效
    UI.shakeCabinet()
    announceSummon(r, '九格大奖')
end

return true
