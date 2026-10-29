-- ============================================================================
-- Legion 侧对 game/ 逻辑层的桥接。
-- game/ 的逻辑层（logic/skills/items/equip/fx/...）通过共享命名空间 game.env
-- 读写游戏符号，并在少数几处回调 UI.* / Sound.* / PAGE.*。
-- 这里把这些回调接到 Legion 的原生 UI 上，使 Legion 能复用 game/ 的
-- 数据层与纯逻辑层（战斗、技能、道具、商店、章节），只需重写界面。
--
-- 加载顺序：必须先 Load() 再访问 Logic 命名空间里的符号。
-- ============================================================================
local GameCore = {}

---@type table<string, any>?
local N = nil

-- ---------------------------------------------------------------------------
-- UI / Sound / PAGE 适配桩
-- Legion 的原生界面在 View 里；这里把逻辑层的提示转成 Legion 的回调。
-- 未接入前先落到控制台，保证逻辑层能独立跑通。
-- ---------------------------------------------------------------------------
---@type table<string, any>
local sink = {
    banner = function(text, kind) print('[拉杆军团/逻辑] banner: ' .. tostring(text) .. ' (' .. tostring(kind) .. ')') end,
    toast = function(text) print('[拉杆军团/逻辑] toast: ' .. tostring(text)) end,
    modal = function(title, body, ok) print('[拉杆军团/逻辑] modal: ' .. tostring(title)) end,
    showAdConfirm = function(title, body, note, onOk) if onOk then onOk() end end,
    bumpGold = function() end,
    skillPop = function() end,
    supFlash = function() end,
    pullLever = function() end,
    shakeCabinet = function() end,
    updateRuleBar = function() end,
    sound = function(name) print('[拉杆军团/逻辑] sound: ' .. tostring(name)) end,
}

--- 供 Legion 的 View 覆盖：把逻辑层的提示接到原生控件上。
---@param handlers table<string, any>
function GameCore.SetSink(handlers)
    for k, v in pairs(handlers or {}) do sink[k] = v end
end

--- game/ 的逻辑层期望这些符号在运行时由 app 装配（game/app.lua 里 require game.ui）。
--- Legion 不加载那套 HTML 运行时，所以在共享命名空间上放自己的实现。
--- 注意：必须用 rawget/rawset —— game.env 的 __index 落到 _G，而引擎自带同名的
--- 原生 UI / Sound 对象，普通索引会拿到它们，往引擎对象上写字段会触发元表递归。
local function installShims()
    local ns = N --[[@as table<string, any>]]

    local UI = rawget(ns, 'UI')
    if type(UI) ~= 'table' then
        UI = {}
        rawset(ns, 'UI', UI)
    end
    UI.banner = function(text, kind) sink.banner(text, kind) end
    UI.toast = function(text) sink.toast(text) end
    UI.modal = function(title, body, ok, after) sink.modal(title, body, ok, after) end
    UI.showAdConfirm = function(title, body, note, okText, onOk) sink.showAdConfirm(title, body, note, okText, onOk) end
    UI.bumpGold = function(...) sink.bumpGold(...) end
    UI.skillPop = function(...) sink.skillPop(...) end
    UI.supFlash = function(...) sink.supFlash(...) end
    UI.pullLever = function(...) sink.pullLever(...) end
    UI.shakeCabinet = function(...) sink.shakeCabinet(...) end
    UI.updateRuleBar = function(...) sink.updateRuleBar(...) end
    -- 缓存桩：逻辑层用它避免重复排版，Legion 侧无对应概念，空实现即可。
    UI.cache = { get = function() return nil end, set = function() end, clear = function() end }
    UI.init = function() end
    UI.update = function() end
    UI.showHome = function() end

    local Sound = rawget(ns, 'Sound')
    if type(Sound) ~= 'table' then
        Sound = {}
        rawset(ns, 'Sound', Sound)
    end
    Sound.play = function(name) sink.sound(name) end
    Sound.init = function() end
    if type(Sound.now) ~= 'function' then Sound.now = function() return 0 end end
    if Sound.on == nil then Sound.on = true end

    -- 逻辑层少数几处访问 PAGE.doc（商店/装备的 HTML 生成），Legion 不用 HTML。
    if type(rawget(ns, 'PAGE')) ~= 'table' then
        rawset(ns, 'PAGE', { doc = setmetatable({}, { __index = function() return function() end end }) })
    end
end

-- ---------------------------------------------------------------------------
-- 加载
-- ---------------------------------------------------------------------------
--- 加载 game/ 的数据层 + 纯逻辑层，并安装适配桩。
--- 幂等：重复调用直接返回同一命名空间。
---@return table<string, any>
function GameCore.Load()
    if N then return N end
    N = require('game.env') --[[@as table<string, any>]]
    require('game.core')
    installShims()
    -- game/app.lua 的 boot() 里做的初始化：建立存档快照 + 载入局外成长。
    -- Legion 侧由自己驱动，所以在这里初始化，之后 META / SAVE 才可用。
    local ns = N --[[@as table<string, any>]]
    if type(ns.buildSave) == 'function' then ns.buildSave() end
    if type(ns.loadMeta) == 'function' then ns.loadMeta() end
    print('[拉杆军团/逻辑] game.core 已加载：章节 ' .. tostring(#N.CHAPTERS) .. '，兵种 ' .. tostring(#N.CLASS_KEYS))
    return N
end

--- 逻辑层里属于 app 装配（不在 game.core 链）的部分：章节 6/7、战场规则、
--- 装备、技能特效、新道具。这些是纯逻辑，Legion 也需要，但 game.core 不含。
--- HTML 运行时专属的模块（render / ui / ui_shop / layout / unitcard / pixel）不加载。
--- 幂等。
function GameCore.LoadExtras()
    if not N then GameCore.Load() end
    for _, name in ipairs({
        'game.rules', 'game.chapters', 'game.balance', 'game.equip',
        'game.skillfx', 'game.skillfx2', 'game.items2',
    }) do
        pcall(require, name)
    end
    print('[拉杆军团/逻辑] 扩展模块已加载：章节 ' .. tostring(#N.CHAPTERS))
    return N
end

--- 加载后的命名空间（须先 Load）。
---@return table<string, any>
function GameCore.N()
    if not N then return GameCore.Load() end
    return N
end

return GameCore
