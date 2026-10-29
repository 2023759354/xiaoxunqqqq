-- 像素战场与转轴均作为 UI Widget 绘制，共用 UI 的 NanoVG 帧和输入坐标。
-- 图集由原版字符像素无损烘焙，最近邻过滤，避免每帧逐像素提交。
local UI = require("urhox-libs/UI")
local Data = require("Legion.Data")
local Draw = {}
local atlas = { handle = 0, w = 512, h = 320, entries = {} }
local COLORS = {}

local function Color(hex, alpha)
    local c = COLORS[hex]
    if not c then
        local s = (hex or "#ffffff"):gsub("#", "")
        c = { tonumber(s:sub(1, 2), 16) or 255, tonumber(s:sub(3, 4), 16) or 255, tonumber(s:sub(5, 6), 16) or 255 }
        COLORS[hex] = c
    end
    return nvgRGBA(c[1], c[2], c[3], math.floor(alpha or 255))
end

local function Rect(vg, x, y, w, h, color, alpha)
    nvgBeginPath(vg)
    nvgRect(vg, x, y, w, h)
    nvgFillColor(vg, Color(color, alpha))
    nvgFill(vg)
end

local function Line(vg, x, y, x2, y2, color, width, alpha)
    nvgBeginPath(vg)
    nvgMoveTo(vg, x, y)
    nvgLineTo(vg, x2, y2)
    nvgStrokeColor(vg, Color(color, alpha))
    nvgStrokeWidth(vg, width or 1)
    nvgStroke(vg)
end

local function Circle(vg, x, y, radius, color, alpha, stroke)
    nvgBeginPath(vg)
    nvgCircle(vg, x, y, math.max(0.1, radius))
    if stroke then
        nvgStrokeColor(vg, Color(color, alpha))
        nvgStrokeWidth(vg, stroke)
        nvgStroke(vg)
    else
        nvgFillColor(vg, Color(color, alpha))
        nvgFill(vg)
    end
end

local function Frame(vg, x, y, w, h, col)
    Rect(vg, x, y, w, 1, col)
    Rect(vg, x, y + h - 1, w, 1, col)
    Rect(vg, x, y, 1, h, col)
    Rect(vg, x + w - 1, y, 1, h, col)
end

local function Corners(vg, x, y, w, h, col)
    for _, p in ipairs({ { x, y }, { x + w - 4, y }, { x, y + h - 1 }, { x + w - 4, y + h - 1 } }) do
        Rect(vg, p[1], p[2], 4, 1, col)
    end
    for _, p in ipairs({ { x, y }, { x + w - 1, y }, { x, y + h - 4 }, { x + w - 1, y + h - 4 } }) do
        Rect(vg, p[1], p[2], 1, 4, col)
    end
end

local function EnsureAtlas(vg)
    if atlas.handle > 0 then return end
    local keys = {}
    for name, rows in pairs(Data.SPR) do keys["spr:" .. name] = rows end
    for cls, def in pairs(Data.CLASSES) do
        for star = 1, 3 do keys["unit:" .. cls .. ":" .. star] = Data.SPR[def.sprite] end
    end
    for branch, def in pairs(Data.BRANCHES) do keys["branch:" .. branch] = Data.SPR[def.sprite or branch] end
    keys.minion = Data.SPR.skeleton
    local sorted = {}
    for key in pairs(keys) do sorted[#sorted + 1] = key end
    table.sort(sorted)
    atlas.h = math.ceil(#sorted / 16) * 32
    for i, key in ipairs(sorted) do
        local rows = keys[key]
        atlas.entries[key] = { x = ((i - 1) % 16) * 32, y = math.floor((i - 1) / 16) * 32, w = #rows[1], h = #rows }
    end
    atlas.handle = nvgCreateImage(vg, "Textures/legion-atlas.png", NVG_IMAGE_NEAREST)
    print("[拉杆军团] 像素图集加载：" .. #sorted .. " 个变体，句柄 " .. atlas.handle)
end

local function Sprite(vg, key, x, y, scale, flip, alpha)
    EnsureAtlas(vg)
    local entry = atlas.entries[key] or atlas.entries["spr:warrior"]
    if not entry or atlas.handle <= 0 then return end
    local sc = scale or 1
    nvgSave(vg)
    nvgTranslate(vg, math.floor(x + 0.5), math.floor(y + 0.5))
    if flip then nvgScale(vg, -1, 1) end
    local ox, oy = -entry.w * sc / 2, 8 * sc - entry.h * sc
    nvgBeginPath(vg)
    nvgRect(vg, ox, oy, entry.w * sc, entry.h * sc)
    nvgFillPaint(vg, nvgImagePattern(vg, ox - entry.x * sc, oy - entry.y * sc,
        atlas.w * sc, atlas.h * sc, 0, atlas.handle, alpha or 1))
    nvgFill(vg)
    nvgRestore(vg)
end

---@type table<string, string[]>
local DIGITS = {
    ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" },
    ["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "111", "001", "111" },
    ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
    ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "010", "010", "010" },
    ["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
    ["+"] = { "000", "010", "111", "010", "000" }, ["-"] = { "000", "000", "111", "000", "000" },
    ["!"] = { "010", "010", "010", "000", "010" },
}

local function PixelText(vg, str, x, y, col)
    local start = math.floor(x - (#str * 4 - 1) / 2)
    for i = 1, #str do
        local glyph = DIGITS[str:sub(i, i)]
        if glyph then
            for r = 1, 5 do
                for c = 1, 3 do
                    if (glyph[r] or ""):sub(c, c) == "1" then
                        Rect(vg, start + (i - 1) * 4 + c - 2, y + r - 2, 3, 3, "#1b1530")
                    end
                end
            end
        end
    end
    nvgBeginPath(vg)
    for i = 1, #str do
        local glyph = DIGITS[str:sub(i, i)]
        if glyph then
            for r = 1, 5 do for c = 1, 3 do
                if (glyph[r] or ""):sub(c, c) == "1" then nvgRect(vg, start + (i - 1) * 4 + c - 1, y + r - 1, 1, 1) end
            end end
        end
    end
    nvgFillColor(vg, Color(col))
    nvgFill(vg)
end

local function Badge(vg, u, x, y)
    if u.branch then
        Sprite(vg, "spr:" .. ((u.q or 1) == 5 and "supbadge" or "crown"), x, y - 6, 1)
    else
        local n = u.star or 1
        for i = 1, n do
            local sx = x - (n * 4 - 1) / 2 + (i - 1) * 4 + 1
            Rect(vg, sx - 1, y - 1, 3, 3, "#1b1530")
            Rect(vg, sx, y - 1, 1, 3, n == 3 and "#ffd84a" or n == 2 and "#cfe3ff" or "#d8d2c4")
            Rect(vg, sx - 1, y, 3, 1, n == 3 and "#ffd84a" or n == 2 and "#cfe3ff" or "#d8d2c4")
        end
    end
end

---@param e table
local function EntityKey(e)
    if e.mspr then return "spr:" .. e.mspr end
    if e.minion and not e.branch then return e.msprite == "wolf" and "spr:wolf" or e.sprite == "sprout" and "spr:sprout" or "minion" end
    if e.branch and Data.BRANCHES[e.branch] then return "branch:" .. e.branch end
    if e.cls and Data.CLASSES[e.cls] then return "unit:" .. e.cls .. ":" .. (e.star or 1) end
    return "spr:" .. (e.sprite or e.type or "slime")
end

local function Unit(vg, e, time, battle)
    if e.dead and (e.deadT or 1) > 0.35 then return end
    local x, y, q = e.x or 0, e.y or 0, e.q or 1
    local scale = (e.giant or 0) > 0 and 2 or 1
    local color = Data.QUAL[q].color
    local bob = math.sin(time * (e.moving and 16 or 3) + (e.id or x)) > 0.4 and -1 or 0
    if e.shifted then nvgGlobalAlpha(vg, 0.3) elseif e.dead then nvgGlobalAlpha(vg, 0.5) end
    Rect(vg, x - (e.big and 9 or 6), y + 7, e.big and 18 or 12, 2, "#1b1530", 120)
    if q > 1 or e.elite then
        Circle(vg, x, y + 5, q == 5 and 11 or 7, e.elite and "#ff4a3a" or color, 30)
        Line(vg, x - 7, y + 8, x + 7, y + 8, e.elite and "#ff4a3a" or color, 1, 180)
    end
    if q == 5 then
        local pulse = 0.5 + math.sin(time * 5) * 0.5
        Rect(vg, x - 9, y + 7, 18, 1, "#ff3434", 100 + pulse * 100)
        for i = 1, 3 do
            local p = (time * 15 + i * 7 + x) % 18
            Rect(vg, x - 7 + i * 4, y + 5 - p, 1, 1, "#ff8e6a", (1 - p / 18) * 255)
        end
    end
    local age = e.atkT or (e.attackAnim and (0.3 - e.attackAnim)) or 5
    local attack = battle and age >= 0 and age < 0.24 and not e.dead
    local push = attack and math.sin(age / 0.24 * math.pi) * 2 or 0
    local face = e.face or (e.side == 2 and -1 or 1)
    Sprite(vg, EntityKey(e), x + push * face, y + bob - (attack and 1 or 0), scale, face < 0)
    if attack and (e.range or 0) < 20 then
        nvgBeginPath(vg)
        nvgMoveTo(vg, x + face * 3, y - 10)
        nvgLineTo(vg, x + face * 11, y - 4)
        nvgLineTo(vg, x + face * 5, y + 5)
        nvgStrokeColor(vg, Color(e.side == 2 and "#ff9b8c" or "#fff2b0", (1 - age / 0.24) * 230))
        nvgStrokeWidth(vg, e.atkBig and 2 or 1)
        nvgStroke(vg)
    end
    nvgGlobalAlpha(vg, 1)
    if e.dead then return end
    if battle then
        local w = e.big and 22 or 12
        local top = y - (scale == 2 and 29 or e.big and 21 or e.tall and 17 or q == 5 and 16 or 11)
        Rect(vg, x - w / 2 - 1, top - 1, w + 2, e.skill and 6 or 4, "#1b1530")
        Rect(vg, x - w / 2, top, w, 2, "#4b3c69")
        Rect(vg, x - w / 2, top, math.max(0, w * math.min(1, (e.hp or 0) / math.max(1, e.maxHp or 1))), 2,
            e.side == 2 and "#ff5a4a" or "#6be06b")
        if (e.shield or 0) > 0 then Rect(vg, x - w / 2, top, w * math.min(1, e.shield / e.maxHp), 1, "#d6f2ff") end
        if e.skill then
            Rect(vg, x - w / 2, top + 3, w, 1, "#2d2245")
            Rect(vg, x - w / 2, top + 3, w * math.min(1, (e.energy or 0) / 100), 1, "#6ef0ff")
        end
        if e.side == 1 and not e.minion then Badge(vg, e, x, top - 5) end
        if (e.stun or 0) > 0 then PixelText(vg, "!", x, top - 6, "#ffd84a") end
        if (e.cast or 0) > 0 then PixelText(vg, tostring(math.ceil(e.cast)), x, top - 9, "#c06bff") end
        if e.immune then Circle(vg, x, y - 2, e.big and 17 or 10, "#ffe14a", 200, 1) end
    elseif e.side ~= 2 then
        Badge(vg, e, x, y - (q == 5 and 16 or 12))
    elseif e.elite then
        PixelText(vg, "!", x, y - 18, "#ff5a4a")
    end
end

local BACKGROUNDS = {}
local function Background(vg, kind)
    local ground = kind == "lava" and "#342834" or kind == "void" and "#292344" or "#44733a"
    Rect(vg, 0, 0, 256, 142, ground)
    if not BACKGROUNDS[kind] then
        local groups, seed = {}, 11
        local function Rnd()
            seed = seed * 16807 % 2147483647
            return seed / 2147483647
        end
        local shades = kind == "lava" and { "#4a3540", "#29212c", "#58373b", "#ff652e" }
            or kind == "void" and { "#342b50", "#201a39", "#45305b", "#8052b2" }
            or { "#3c6834", "#4e8241", "#3a6230", "#55894a" }
        for i = 1, 640 do
            local col = shades[math.floor(Rnd() * 4) + 1]
            groups[col] = groups[col] or {}
            groups[col][#groups[col] + 1] = { math.floor(Rnd() * 256), math.floor(Rnd() * 142), i % 9 == 0 and 2 or 1 }
        end
        BACKGROUNDS[kind] = groups
    end
    for col, pixels in pairs(BACKGROUNDS[kind]) do
        nvgBeginPath(vg)
        for _, p in ipairs(pixels) do nvgRect(vg, p[1], p[2], p[3], 1) end
        nvgFillColor(vg, Color(col))
        nvgFill(vg)
    end
    if kind == "void" then
        for x = 0, 256, 24 do Line(vg, x, 10, x, 142, "#19142e", 1) end
        for y = 12, 142, 26 do Line(vg, 0, y, 256, y, "#19142e", 1) end
    elseif kind == "lava" then
        for i = 1, 5 do
            local x = i * 45 - 20
            Line(vg, x, 8, x + 13, 44, "#b34527", 2)
            Line(vg, x + 13, 44, x + 4, 83, "#ff8a2a", 1)
            Line(vg, x + 4, 83, x + 22, 139, "#a73728", 2)
        end
    end
    Rect(vg, 0, 0, 256, 7, kind == "grass" and "#2b4c25" or "#1b1530")
    Rect(vg, 0, 142, 256, 2, "#1b1530")
    Rect(vg, 0, 144, 256, 32, "#5a3a22")
    Rect(vg, 0, 144, 256, 1, "#9b6a3c")
    for i = 1, 8 do
        local x = 18 + (i - 1) * 31
        Rect(vg, x - 13, 148, 26, 26, "#3e2715")
        Line(vg, x - 13, 148, x + 13, 148, "#2b1a0e", 1)
        Line(vg, x - 13, 173, x + 13, 173, "#7a5233", 1)
    end
end

function Draw.CellPosition(index)
    if index <= 12 then
        return 20 + ((index - 1) % 4) * 28, 34 + math.floor((index - 1) / 4) * 38
    end
    return 18 + (index - 13) * 31, 160
end

function Draw.CellAt(x, y)
    if x < 0 or x >= 256 or y < 0 or y >= 176 then return 0 end
    if y >= 148 then
        local i = math.floor((x - 5) / 31) + 13
        if i >= 13 and i <= 20 then return i end
    elseif x < 120 and y >= 18 and y < 128 then
        local col = math.floor((x - 6) / 28)
        local row = math.floor((y - 18) / 38)
        if col >= 0 and col <= 3 and row >= 0 and row <= 2 then return row * 4 + col + 1 end
    end
    return 0
end

local function Field(vg, f, time)
    local r = f.r or 16
    local col = f.color or (f.kind == "lava" and "#ff8a2a" or "#c06bff")
    if f.kind == "fissure" then
        Line(vg, f.x, f.y, f.x2 or f.x, f.y2 or f.y, col, f.fired and 3 or 1, f.fired and 220 or 140)
    else
        Circle(vg, f.x or 128, f.y or 72, r, col, f.kind == "blackhole" and 100 or 50)
        Circle(vg, f.x or 128, f.y or 72, r * (0.8 + math.sin(time * 5) * 0.1), col, 210, 1)
    end
end

local function Effects(vg, list)
    for _, f in ipairs(list or {}) do
        local t = math.max(0, math.min(1, (f.life or 0) / math.max(0.01, f.maxLife or 0.7)))
        local col = f.color or "#ffe27a"
        if f.kind == "text" or f.kind == "heal" and f.text then
            nvgSave(vg)
            nvgGlobalAlpha(vg, t)
            PixelText(vg, tostring(f.text or ""), f.x, f.y - (1 - t) * 8, col)
            nvgRestore(vg)
        elseif f.kind == "line" or f.kind == "bolt" or f.kind == "slash" then
            Line(vg, f.x, f.y, f.x2 or f.x + 8, f.y2 or f.y, col, 1, t * 255)
        elseif f.kind ~= "skill" and f.kind ~= "phase" then
            Circle(vg, f.x, f.y, (f.r or 8) * (1 - t) + 1, col, t * 220, 1)
            if f.kind == "impact" or f.kind == "death" then
                for i = 1, 6 do
                    local a = i * math.pi / 3
                    Rect(vg, f.x + math.cos(a) * (1 - t) * 11, f.y + math.sin(a) * (1 - t) * 7, 1, 1, col, t * 255)
                end
            end
        end
    end
end

---@class LegionArena : Widget
---@field props table
---@overload fun(props: table): LegionArena
local Arena = UI.Widget:Extend("LegionArena")

function Arena:Init(props)
    UI.Widget.Init(self, props)
end

function Arena:Render(vg)
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end
    local view, game = self.props.view, self.props.game
    local g, b = game.g, view.battle
    nvgSave(vg)
    nvgIntersectScissor(vg, l.x, l.y, l.w, l.h)
    nvgTranslate(vg, l.x, l.y)
    nvgScale(vg, l.w / 256, l.h / 176)
    nvgShapeAntiAlias(vg, 0)
    local kind = Data.CHAPTERS[g.ch].bg
    Background(vg, kind)
    local time = view.time or 0
    if not b then
        for y = 12, 139, 6 do Rect(vg, 128, y, 1, 3, "#1b1530", 80) end
        for i = 1, 12 do
            local x, y = Draw.CellPosition(i)
            Corners(vg, x - 12, y - 14, 24, 28, "#a0bd84")
        end
        local units = {}
        for i = 1, 12 do
            local u = game:GetSlot(i)
            if (view.spinT or 0) > 0 and view.spinArmy then u = view.spinArmy[i] end
            if u and not (view.drag and view.drag.moved and view.drag.src == i) then
                local e = {}
                for key, value in pairs(u) do e[key] = value end
                e.x, e.y = Draw.CellPosition(i)
                e.side = 1
                units[#units + 1] = e
            end
        end
        for _, e in ipairs(view.preview or {}) do units[#units + 1] = e end
        table.sort(units, function(a, c) return a.y < c.y end)
        for _, e in ipairs(units) do Unit(vg, e, time, false) end
    else
        for _, f in ipairs(b.fields or {}) do Field(vg, f, time) end
        local units = {}
        for _, e in ipairs(b.entities) do units[#units + 1] = e end
        table.sort(units, function(a, c) return a.y < c.y end)
        for _, e in ipairs(units) do Unit(vg, e, b.elapsed or time, true) end
        for _, p in ipairs(b.projectiles or {}) do
            if (p.delay or 0) <= 0 then
                local col = p.kind == "arrow" and "#f1e3c2" or p.kind == "parrow" and "#8fe07a" or "#d2a6ff"
                local angle = p.ang or 0
                Line(vg, p.x - math.cos(angle) * 4, p.y - math.sin(angle) * 4, p.x, p.y, col, 1)
                Rect(vg, p.x, p.y, 2, 2, col)
            end
        end
        Effects(vg, b.effects)
    end
    for i = 13, 20 do
        local u = game:GetSlot(i)
        if (view.spinT or 0) > 0 and view.spinArmy then u = view.spinArmy[i] end
        if u and not (view.drag and view.drag.moved and view.drag.src == i) then
            local e = {}
            for key, value in pairs(u) do e[key] = value end
            e.x, e.y = Draw.CellPosition(i)
            e.side = 1
            Unit(vg, e, time, false)
        end
    end
    if not b then
        local selected = view.selected or 0
        if selected > 0 then
            local x, y = Draw.CellPosition(selected)
            Corners(vg, x - 13, y - 15, 26, 29, "#ffe27a")
        end
        local drag = view.drag
        if drag and drag.moved then
            if (drag.over or 0) > 0 then
                local x, y = Draw.CellPosition(drag.over)
                Frame(vg, x - 13, y - 15, 26, 29, "#ffe27a")
            end
            local u = game:GetSlot(drag.src)
            if u then
                local e = {}
                for key, value in pairs(u) do e[key] = value end
                e.x, e.y, e.side = drag.x, drag.y - 5, 1
                Unit(vg, e, time, false)
            end
        end
    end
    nvgRestore(vg)
end

function Arena:ToField(event)
    local l = self:GetAbsoluteLayout()
    return (event.x - l.x) * 256 / math.max(1, l.w), (event.y - l.y) * 176 / math.max(1, l.h)
end

function Arena:OnPointerDown(event)
    local view = self.props.view
    if self.props.game.g.phase ~= "prep" or (view.spinT or 0) > 0 or not event:IsPrimaryButton() then return end
    local x, y = self:ToField(event)
    local index = Draw.CellAt(x, y)
    if index > 0 then
        view.drag = { src = index, x = x, y = y, startX = x, startY = y, moved = false, over = index, pointerId = event.pointerId }
        event:PreventDefault()
    end
end

function Arena:OnPointerMove(event)
    local view = self.props.view
    local drag = view.drag
    if not drag or drag.pointerId ~= event.pointerId then return end
    local x, y = self:ToField(event)
    drag.x, drag.y, drag.over = x, y, Draw.CellAt(x, y)
    if (x - drag.startX)^2 + (y - drag.startY)^2 > 9 and self.props.game:GetSlot(drag.src) then drag.moved = true end
end

function Arena:OnPointerUp(event)
    local view = self.props.view
    local drag = view.drag
    if not drag or drag.pointerId ~= event.pointerId then return end
    local x, y = self:ToField(event)
    local target = Draw.CellAt(x, y)
    view.drag = nil
    if target > 0 and self.props.onCell then
        if drag.moved then self.props.onCell(target, drag.src) else self.props.onCell(target) end
    end
end

function Arena:OnPointerCancel(_event)
    self.props.view.drag = nil
end

---@class LegionPortrait : Widget
---@field props table
---@overload fun(props: table): LegionPortrait
local Portrait = UI.Widget:Extend("LegionPortrait")
function Portrait:Init(props) UI.Widget.Init(self, props) end
function Portrait:Render(vg)
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end
    local p = self.props
    local key = p.branch and "branch:" .. p.branch or p.cls and "unit:" .. p.cls .. ":" .. (p.star or 1) or "spr:" .. (p.sprite or "warrior")
    local rows = p.branch and Data.SPR[Data.BRANCHES[p.branch].sprite or p.branch]
        or p.cls and Data.SPR[Data.CLASSES[p.cls].sprite] or Data.SPR[p.sprite or "warrior"]
    local size = rows and math.max(#rows, #rows[1]) or 16
    local scale = math.min(l.w, l.h) / (size + 4)
    Sprite(vg, key, l.x + l.w / 2, l.y + l.h / 2 + (size / 2 - 8) * scale, scale, p.flip)
end

---@class LegionReels : Widget
---@field props table
---@overload fun(props: table): LegionReels
local Reels = UI.Widget:Extend("LegionReels")
function Reels:Init(props) UI.Widget.Init(self, props) end
function Reels:Render(vg)
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end
    local view, g = self.props.view, self.props.game.g
    local grid = view.spinResult and view.spinResult.grid or (g.slot and g.slot.grid) or { "W", "A", "M", "M", "S", "W", "A", "W", "M" }
    local remaining = view.spinT or 0
    local elapsed = 1.4 - remaining
    nvgSave(vg)
    nvgIntersectScissor(vg, l.x, l.y, l.w, l.h)
    nvgTranslate(vg, l.x, l.y)
    nvgScale(vg, l.w / 72, l.h / 72)
    nvgShapeAntiAlias(vg, 0)
    Rect(vg, 0, 0, 72, 72, "#e2b33c")
    Rect(vg, 2, 2, 68, 68, "#1b1530")
    local syms = {}
    for _, cls in ipairs(g.squad) do syms[#syms + 1] = Data.CLASS_SYM[cls] end
    syms[#syms + 1] = "S"
    for col = 1, 3 do
        local spinning = remaining > 0 and elapsed < (0.6 + col * 0.22)
        nvgSave(vg)
        nvgIntersectScissor(vg, 3 + (col - 1) * 22, 3, 22, 66)
        for row = 1, 3 do
            local i = (row - 1) * 3 + col
            local x, y = 14 + (col - 1) * 22, 14 + (row - 1) * 22
            Rect(vg, x - 10, y - 10, 20, 20, row % 2 == 0 and "#3a2d52" or "#2d2245")
            local sym = grid[i] or "S"
            local off = 0
            if spinning then
                sym = syms[(math.floor((view.time or 0) * 18) + row + col) % #syms + 1]
                off = ((view.time or 0) * 140) % 22
            end
            Sprite(vg, "spr:" .. (Data.SYM_SPRITE[sym] or "sym_star"), x, y + off, 1)
            if spinning then Sprite(vg, "spr:" .. (Data.SYM_SPRITE[syms[row % #syms + 1]] or "sym_star"), x, y + off - 22, 1) end
        end
        nvgRestore(vg)
    end
    if remaining <= 0 and view.spinResult then
        for _, win in ipairs(view.spinResult.wins or {}) do
            local cells = Data.LINES[win.li]
            if cells then
                local a, z = cells[1], cells[3]
                local x1, y1 = 14 + ((a - 1) % 3) * 22, 14 + math.floor((a - 1) / 3) * 22
                local x2, y2 = 14 + ((z - 1) % 3) * 22, 14 + math.floor((z - 1) / 3) * 22
                Line(vg, x1, y1, x2, y2, "#ffe27a", 1, 150)
            end
        end
        if view.spinResult.jackpot then Frame(vg, 3, 3, 66, 66, "#ff3434") end
    end
    for x = 2, 70, 22 do Line(vg, x, 2, x, 70, "#e2b33c", 1) end
    for y = 2, 70, 22 do Line(vg, 2, y, 70, y, "#e2b33c", 1) end
    Frame(vg, 0, 0, 72, 72, "#1b1530")
    nvgRestore(vg)
end

---@class LegionDecor : Widget
---@field props table
---@overload fun(props: table): LegionDecor
local Decor = UI.Widget:Extend("LegionDecor")
function Decor:Init(props) UI.Widget.Init(self, props) end
function Decor:Render(vg)
    local l = self:GetAbsoluteLayout()
    nvgSave(vg)
    nvgIntersectScissor(vg, l.x, l.y, l.w, l.h)
    nvgTranslate(vg, l.x, l.y)
    nvgScale(vg, l.w / 192, l.h / 56)
    nvgShapeAntiAlias(vg, 0)
    Rect(vg, 0, 0, 192, 56, "#1b1530")
    Rect(vg, 0, 43, 192, 13, "#365f2e")
    for i = 1, 24 do Rect(vg, (i * 37) % 190, 2 + (i * 17) % 35, 1, 1, "#806a98") end
    Sprite(vg, "unit:warrior:3", 20, 33, 1.4)
    Sprite(vg, "unit:archer:2", 46, 34, 1.4)
    Sprite(vg, "unit:mage:2", 71, 34, 1.4)
    Sprite(vg, "spr:boss", 125, 33, 1.2, true)
    Sprite(vg, "spr:colossus", 155, 33, 1.1, true)
    Sprite(vg, "spr:voidlord", 179, 33, 1, true)
    Frame(vg, 0, 0, 192, 56, "#4b3c69")
    nvgRestore(vg)
end

Draw.Arena = Arena
Draw.Portrait = Portrait
Draw.Reels = Reels
Draw.Decor = Decor
function Draw.Shutdown()
    if atlas.handle > 0 then nvgDeleteImage(UI.GetNVGContext(), atlas.handle) end
    atlas.handle = 0
end
return Draw
