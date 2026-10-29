-- 入口生命周期沿用 templates/scaffold-2d.lua 标准脚手架。
-- Legion.View 持有唯一 UI 树；美术在同一 UI 上下文内绘制。
-- 逻辑层复用 game/ 的数据与战斗/道具/章节实现，通过 Legion.GameCore 桥接。
local View = require("Legion.View")
local GameCore = require("Legion.GameCore")

---@type LegionView?
local view_ = nil

function Start()
    if view_ then view_:Stop() end
    -- 先加载 game/ 的数据层与逻辑层（含 7 章、10 兵种、商店/装备/道具）
    GameCore.Load()
    GameCore.LoadExtras()
    view_ = View.New()
    view_:Init()
    SubscribeToEvent("Update", "HandleLegionUpdate")
    SubscribeToEvent("KeyDown", "HandleLegionKeyDown")
    print("[拉杆军团] 游戏启动")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleLegionUpdate(eventType, eventData)
    if view_ then view_:Update(eventData:GetFloat("TimeStep")) end
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleLegionKeyDown(eventType, eventData)
    if view_ then view_:KeyDown(eventData:GetInt("Key")) end
end

function Stop()
    UnsubscribeFromEvent("Update")
    UnsubscribeFromEvent("KeyDown")
    if view_ then view_:Stop(); view_ = nil end
end
