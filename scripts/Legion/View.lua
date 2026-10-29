-- 基于 templates/scaffold-2d.lua：UI 统一负责输入、布局与 NanoVG 渲染。
-- 只在界面切换时重建控件树；回调延迟至 Update 后销毁旧控件。
local UI = require("urhox-libs/UI")
local Theme = require("Legion.Theme")
local Draw = require("Legion.Draw")
local Data = require("Legion.Data")
local Game = require("Legion.Game")
local Battle = require("Legion.Battle")
local Audio = require("Legion.Audio")
local C = Theme.C

---@class LegionView
---@field game table
---@field root Widget?
---@field battle LegionBattle?
---@field preview table[]
---@field modal table?
---@field drag table?
---@field spinResult table?
---@field spinArmy table[]?
local View = {}
View.__index = View

local function merge(a, b)
    for k, v in pairs(b or {}) do a[k] = v end
    return a
end

local function label(text, props)
    return UI.Label(merge({ text = tostring(text or ""), fontSize = 10.5,
        fontColor = C.ink, whiteSpace = "normal", lineHeight = 1.5, flexShrink = 1 }, props))
end

local function button(text, action, props)
    return UI.Button(merge({ text = text, onClick = action, height = 44,
        fontSize = 11.25, fontWeight = "bold", variant = "secondary" }, props))
end

local function goldButton(text, action, props)
    return button(text, action, merge({ backgroundColor = C.gold, textColor = C.night,
        hoverBackgroundColor = C.goldHi, pressedBackgroundColor = "#9a6f1c",
        borderColor = "#9a6f1c" }, props))
end

local function redButton(text, action, props)
    return button(text, action, merge({ backgroundColor = C.red, textColor = C.ink,
        hoverBackgroundColor = "#ef5a4c", pressedBackgroundColor = "#8e2420",
        borderColor = "#8e2420" }, props))
end

local function row(children, props)
    -- 横排文字使用固有宽度；自动换行的空 HUD 标签在横排里会被分配零宽度。
    for _, child in ipairs(children) do
        if child._className == "Label" and not child.userSetWidth_ then
            local text = child --[[@as Label]]
            text:SetStyle({ whiteSpace = "nowrap", alignSelf = "auto" })
            text:SetWidthAuto()
        end
    end
    return UI.Panel(merge({ flexDirection = "row", alignItems = "center", gap = 8,
        flexWrap = "wrap", children = children }, props))
end

local function card(children, props)
    return UI.Card(merge({ variant = "outlined", padding = 14, gap = 10,
        backgroundColor = C.panel, borderColor = C.night, children = children }, props))
end

local function section(text, color)
    return label(text, { fontSize = 15, fontWeight = "bold", fontColor = color or C.gold,
        textShadow = { offsetX = 2, offsetY = 2, blur = 0, color = C.night } })
end

local function portrait(u, size)
    local cls = Data.CLASSES[u.cls]
    local branch = u.branch and Data.BRANCHES[u.branch]
    return Draw.Portrait { cls = u.cls, sprite = branch and (branch.sprite or u.branch) or cls.sprite,
        branch = u.branch, q = u.q or 1, star = u.star or 1, width = size or 48, height = size or 48 }
end

local function pct(value)
    return math.floor(((value or 1) - 1) * 100 + 0.5)
end

local function countSlots(slots)
    local n = 0
    for _, u in ipairs(slots) do if u then n = n + 1 end end
    return n
end

function View.New()
    local self = setmetatable({}, View)
    self:Prepare()
    return self
end

function View:Prepare()
    self.game = Game.New()
    self.root = nil
    self.battle = nil
    self.preview = {}
    self.modal = nil
    self.drag = nil
    self.spinResult = nil
    self.spinArmy = nil
    self.page = "home"
    self.selected = 0
    self.time, self.spinT, self.spinDuration = 0, 0, 1.4
    self.paused, self.speed, self.stopped = false, 1, false
    self.dirty, self.screenW, self.screenH = true, 0, 0
    self.pickCh, self.pickDiff = 1, 1
    self.squad = Data.ValidSquad(self.game.progress.squad)
    self.codexTab, self.forgeTab, self.backPage = "warrior", "eco", "home"
    self.tutorialStep = 0
    self.tutorialSpins = 0
    self.offered = {}
    self.textCache = {}
    self.styleCache = {}
    self.summary = "横、竖、斜连成三个相同图标，即可召唤战士。"
    self.notice, self.noticeT = "", 0
    self.soundOn, self.nextTick, self.hitCooldown = true, 0, 0
    self.seenEffects = setmetatable({}, { __mode = "k" })
    self.banner, self.bannerT = "", 0
end

function View:Init()
    -- 新运行时提供方向接口，旧版本和不支持转屏的宿主保留响应式布局。
    ---@type table?
    local commonApi = rawget(_G, "common")
    if commonApi and type(commonApi.setDeviceOrientation) == "function" then
        local ok, err = pcall(commonApi.setDeviceOrientation, { value = "landscape" })
        if not ok then print("[拉杆军团] 请求横屏失败：" .. tostring(err)) end
    end
    Theme.Init()
    Audio.Init()
    graphics.windowTitle = "拉杆军团"
    input.mouseMode = MM_ABSOLUTE
    self:BuildRoot()
    print("[拉杆军团/界面] 紫铜金 PixelForge 界面初始化完成")
end

function View:RequestBuild()
    self.dirty = true
end

function View:SetPage(page)
    self.page = page
    self.modal = nil
    self.drag = nil
    self:RequestBuild()
    print("[拉杆军团/界面] 切换页面=" .. page)
end

function View:Notify(text)
    self.notice, self.noticeT = tostring(text or ""), 3
    self:SetLabel("notice", self.notice)
end

function View:SetLabel(id, text)
    local value = tostring(text or "")
    if self.textCache[id] == value or not self.root then return end
    local w = self.root:FindById(id) --[[@as Label?]]
    if w then w:SetText(value); self.textCache[id] = value end
end

function View:SetButton(id, text, disabled)
    if not self.root then return end
    local w = self.root:FindById(id) --[[@as Button?]]
    if not w then return end
    local key = text .. "/" .. tostring(disabled)
    if self.textCache[id] ~= key then
        w:SetText(text)
        w:SetDisabled(disabled)
        self.textCache[id] = key
    end
end

function View:ShowModal(title, children, actions, kind)
    self.modal = { title = title, children = children, actions = actions or {}, kind = kind or "info" }
    self.drag = nil
    self:RequestBuild()
end

function View:CloseModal()
    self.modal = nil
    self:RequestBuild()
end

function View:ConfirmHome()
    if self.game.g.tutorial then self:GoHome(); return end
    local g = self.game.g
    self:ShowModal("回到主页？", {
        label("这一局的阵容不会保存。现在是第 " .. g.wave .. " 波。", { fontColor = C.dim }),
        label("中途放弃只结算已获得军魂的 50%；完成整局可以拿全额。", { fontColor = C.goldHi }),
    }, {
        button("继续这局", function() self:CloseModal() end, { width = 132 }),
        goldButton("确认回主页", function() self.game:Abandon(); self:GoHome() end, { width = 148 }),
    }, "confirm")
end

function View:GoHome()
    self.battle, self.drag, self.spinResult = nil, nil, nil
    self.spinT, self.selected, self.spinArmy = 0, 0, nil
    self.banner, self.bannerT = "", 0
    self.paused, self.speed, self.tutorialStep = false, 1, 0
    self:SetPage("home")
end

function View:BuildRoot()
    -- 根安全区域保护所有可交互界面与弹窗，避让设备边缘和 Tap 胶囊。
    local root = UI.SafeAreaView { id = "legion-root", width = "100%", height = "100%",
        nativeMenuInset = true, backgroundColor = C.bg, pointerEvents = "box-none" }
    self.root = root
    self.textCache, self.styleCache = {}, {}
    local screen
    if self.page == "home" then screen = self:BuildHome()
    elseif self.page == "chapter" then screen = self:BuildChapter()
    elseif self.page == "squad" then screen = self:BuildSquad()
    elseif self.page == "codex" then screen = self:BuildCodex()
    elseif self.page == "forge" then screen = self:BuildForge()
    else screen = self:BuildGame() end
    root:AddChild(screen)
    if self.modal then root:AddChild(self:BuildModal()) end
    UI.SetRoot(root, true)
    self.dirty = false
    self:RefreshHUD()
end

function View:BuildModal()
    local m = self.modal
    local content = UI.Panel { width = "100%", gap = 12, children = m.children }
    return UI.Panel { id = "dialog-overlay", position = "absolute", top = 0, left = 0,
        right = 0, bottom = 0, padding = 18, backgroundColor = {15, 10, 28, 220},
        justifyContent = "center", alignItems = "center", zIndex = 40,
        pointerEvents = "auto", children = {
            card({
                section(m.title),
                UI.ScrollView { width = "100%", flexGrow = 1, flexBasis = 0,
                    scrollY = true, bounces = false, children = { content } },
                row(m.actions, { justifyContent = "flex-end", paddingTop = 8 }),
            }, { id = "dialog", width = "100%", maxWidth = 780, height = "86%",
                borderColor = C.gold, padding = 18 }),
        } }
end

function View:PageFrame(title, body, back)
    return UI.Panel { width = "100%", height = "100%", padding = 16, gap = 12,
        alignItems = "center", children = {
            row({ section(title), button("返回", back, { width = 86, height = 38 }) },
                { width = "100%", maxWidth = 1080, justifyContent = "space-between" }),
            UI.ScrollView { width = "100%", maxWidth = 1080, flexGrow = 1, flexBasis = 0,
                scrollY = true, bounces = false, children = { body } },
        } }
end

function View:BuildHome()
    local progress = {}
    for ch, chapter in ipairs(Data.CHAPTERS) do
        local open = self.game:ChapterOpen(ch)
        local record = self.game.progress.chapters[ch]
        local cleared = 0
        for diff = 1, 4 do if (record.cleared & (1 << (diff - 1))) ~= 0 then cleared = cleared + 1 end end
        progress[#progress + 1] = card({
            row({ label(chapter.name, { fontWeight = "bold", fontColor = chapter.color }),
                label(chapter.title, { flexGrow = 1 }),
                label(open and (cleared .. "/4") or "未解锁", { fontColor = C.dim }) }, { width = "100%" }),
        }, { width = "100%", padding = 8, backgroundColor = C.night,
            borderColor = chapter.color, opacity = open and 1 or 0.5 })
    end
    local menu = UI.Panel { width = "100%", maxWidth = 328, gap = 12, children = {
        redButton("开始游戏", function() self:SetPage("chapter") end, { width = "100%", height = 52, fontSize = 15 }),
        button("新手教程", function() self:StartTutorial() end, { width = "100%", height = 48 }),
        goldButton("军魂强化  ·  " .. self.game.progress.meta.s,
            function() self.backPage = "home"; self:SetPage("forge") end, { width = "100%", height = 48 }),
        row({ button("图鉴", function() self.backPage = "home"; self:SetPage("codex") end, { width = 112, height = 40 }),
            button("玩法说明", function() self:ShowHelp() end, { width = 154, height = 40 }) }, { justifyContent = "center" }),
        button(self.soundOn and "音效 开" or "音效 关", function() self:ToggleSound() end,
            { id = "sound", width = 112, height = 40, alignSelf = "center" }),
    } }
    local landscape = UI.GetWidth() > UI.GetHeight() and UI.GetWidth() >= 650
    local hero = UI.Panel { width = "100%", flexGrow = landscape and 1 or 0,
        flexBasis = landscape and 0 or "auto", minWidth = 0, gap = 14, children = {
        Draw.Decor { width = "100%", height = landscape and 100 or 120, view = self },
        label("拉杆军团", { fontSize = landscape and 30 or 36, fontWeight = "bold", fontColor = C.gold,
            width = "100%", textAlign = "center", letterSpacing = 4,
            textStroke = { width = 3, color = C.night },
            textShadow = { offsetX = 4, offsetY = 4, blur = 0, color = C.night } }),
        label("拉杆召唤，吸收升星，转职成军", { fontColor = C.dim, textAlign = "center", width = "100%" }),
        UI.Panel { width = "100%", gap = 8, children = progress },
        label("空格拉杆  /  回车开战  /  P 暂停", { fontSize = 9, fontColor = C.dim, textAlign = "center", width = "100%" }),
    } }
    if landscape then menu:SetStyle({ width = 300, flexShrink = 0 }) end
    local home = card({ hero, menu }, { width = "100%", maxWidth = landscape and 960 or 560,
        flexDirection = landscape and "row" or "column", padding = 24, gap = 28, alignItems = "center" })
    return UI.ScrollView { width = "100%", height = "100%", bounces = false, children = {
        UI.Panel { width = "100%", minHeight = "100%", padding = 24,
            alignItems = "center", justifyContent = "center", children = { home } },
    } }
end

function View:BuildChapter()
    local chapters = {}
    for ch, chapter in ipairs(Data.CHAPTERS) do
        local open = self.game:ChapterOpen(ch)
        chapters[#chapters + 1] = button(chapter.name .. " · " .. chapter.title,
            function() self.pickCh = ch; self:RequestBuild() end,
            { width = "100%", height = 48, disabled = not open,
                backgroundColor = self.pickCh == ch and C.panelHi or C.night,
                borderColor = self.pickCh == ch and chapter.color or C.panelHi,
                textColor = chapter.color })
        if not open then chapters[#chapters + 1] = label("通关上一章「普通」后解锁", { fontSize = 9, fontColor = C.dim }) end
    end
    local chapter = Data.CHAPTERS[self.pickCh]
    local diffs = {}
    for index, diff in ipairs(chapter.diffs) do
        local open = self.game:DifficultyOpen(self.pickCh, index)
        local record = self.game.progress.chapters[self.pickCh]
        local cleared = (record.cleared & (1 << (index - 1))) ~= 0
        local status = not open and "通关上一难度后解锁" or cleared and "已通关" or
            ((record.best[index] or 0) > 0 and ("最佳守住 " .. record.best[index] .. " 波") or "尚未挑战")
        diffs[#diffs + 1] = card({
            section(diff.name .. " · " .. diff.waves .. " 波", diff.color),
            label(diff.desc, { fontColor = C.dim }),
            label(status, { fontSize = 9.75, fontColor = C.goldHi }),
            goldButton(open and "选择此难度" or "尚未解锁", function()
                self.pickDiff = index
                self:SetPage("squad")
            end, { width = "100%", disabled = not open }),
        }, { width = "100%", backgroundColor = C.night, borderColor = diff.color,
            opacity = open and 1 or 0.5 })
    end
    return self:PageFrame("选择章节与难度", UI.Panel { width = "100%", gap = 14, children = {
        UI.Panel { width = "100%", gap = 8, children = chapters },
        label(chapter.desc, { fontColor = C.dim }),
        UI.SimpleGrid { columns = UI.GetWidth() >= 650 and 2 or 1, gap = 12, children = diffs },
    } }, function() self:GoHome() end)
end

function View:ToggleSquad(cls)
    for i, key in ipairs(self.squad) do
        if key == cls then table.remove(self.squad, i); self:RefreshSquad(); return end
    end
    self.squad[#self.squad + 1] = cls
    if #self.squad > 3 then table.remove(self.squad, 1) end
    self:RefreshSquad()
end

function View:RefreshSquad()
    self:SetLabel("squad-count", "已选 " .. #self.squad .. "/3 · 选满后点击新兵种，替换最早的选择")
    self:SetButton("squad-start", "出征", #self.squad ~= 3)
    if not self.root then return end
    for _, cls in ipairs(Data.CLASS_KEYS) do
        local on = false
        for _, chosen in ipairs(self.squad) do if cls == chosen then on = true end end
        local w = self.root:FindById("squad-" .. cls)
        if w and self.styleCache[cls] ~= on then
            w:SetStyle({ borderColor = on and C.goldHi or C.panelHi,
                backgroundColor = on and C.panelHi or C.night })
            self.styleCache[cls] = on
        end
        self:SetButton("pick-" .. cls, on and "已选择" or "选择", false)
    end
end

function View:BuildSquad()
    local units = {}
    for _, cls in ipairs(Data.CLASS_KEYS) do
        local def = Data.CLASSES[cls]
        local skill = Data.SKILLS[Data.CLASS_SKILL[cls]]
        units[#units + 1] = card({
            row({ portrait({ cls = cls, q = 1, star = 1 }, 52), section(def.name) }),
            label((Data.KIND_NAME[def.kind] or def.kind) .. " · " .. (def.proj and "远程" or "近战") .. " · " .. def.note,
                { fontColor = C.dim, fontSize = 9.75 }),
            label("生命 " .. def.hp .. "  攻击 " .. def.atk .. "  射程 " .. def.range, { fontSize = 9.75 }),
            label("技能「" .. skill.name .. "」" .. skill.desc, { fontSize = 9.75 }),
            button("选择", function() self:ToggleSquad(cls) end, { id = "pick-" .. cls, width = "100%" }),
        }, { id = "squad-" .. cls, width = "100%", backgroundColor = C.night, borderColor = C.panelHi })
    end
    local columns = UI.GetWidth() >= 850 and 3 or UI.GetWidth() >= 580 and 2 or 1
    local body = UI.Panel { width = "100%", gap = 14, children = {
        label(Data.CHAPTERS[self.pickCh].title .. " · " .. Data.CHAPTERS[self.pickCh].diffs[self.pickDiff].name ..
            "。七选三：老虎机只会出现所选兵种，星星可替代任何图标。", { fontColor = C.dim }),
        label("", { id = "squad-count", fontColor = C.goldHi }),
        button("随机选择三个", function()
            local keys = {}
            for _, cls in ipairs(Data.CLASS_KEYS) do keys[#keys + 1] = cls end
            for i = #keys, 2, -1 do local j = math.random(i); keys[i], keys[j] = keys[j], keys[i] end
            self.squad = { keys[1], keys[2], keys[3] }; self:RefreshSquad()
        end, { width = 184 }),
        UI.SimpleGrid { columns = columns, gap = 12, children = units },
        redButton("出征", function() self:BeginRun() end, { id = "squad-start", width = "100%", height = 52 }),
    } }
    return self:PageFrame("组建军团", body, function() self:SetPage("chapter") end)
end

function View:BeginRun()
    if #self.squad ~= 3 then return end
    local ok, reason = self.game:NewRun(self.pickCh, self.pickDiff, self.squad)
    if not ok then self:Notify(reason); return end
    self.battle, self.drag, self.spinResult = nil, nil, nil
    self.selected, self.spinT, self.tutorialStep = 0, 0, 0
    self.offered, self.speed, self.paused = {}, 1, false
    self.summary = "阵地准备就绪，拉杆召唤你的军团。"
    self.preview = Battle.Preview(self.game)
    self:SetPage("game")
    print("[拉杆军团/界面] 开始新局，章节=" .. self.pickCh .. "，难度=" .. self.pickDiff)
end

function View:BuildGame()
    local wide = UI.GetWidth() >= 650 and UI.GetWidth() > UI.GetHeight()
    local compact = wide and UI.GetHeight() < 760
    -- 手机横屏短边较小，限制战场高度，保留同屏拉杆和开战按钮。
    local arenaHeight = math.max(140, UI.GetHeight() - (self.game.g.tutorial and 280 or 230))
    local arena = Draw.Arena { game = self.game, view = self, id = "arena",
        width = "100%", maxWidth = compact and arenaHeight * 256 / 176 or nil,
        alignSelf = "center", aspectRatio = 256 / 176,
        onCell = function(index, src) self:OnCell(index, src) end }
    local field = UI.Panel { id = "field", width = "100%",
        flexGrow = wide and 1 or 0, flexBasis = wide and 0 or "auto", minWidth = 0,
        gap = compact and 5 or 10, children = {
            card({ arena, label("", { id = "battle-banner", position = "absolute", top = 12,
                left = 8, right = 8, textAlign = "center", fontSize = 16,
                fontWeight = "bold", fontColor = C.goldHi,
                textStroke = { width = 2, color = C.night }, pointerEvents = "none" }) },
                { width = "100%", padding = 4, borderColor = C.woodDark, backgroundColor = C.night }),
            card({ label("", { id = "unit-info", fontColor = C.dim, width = "100%",
                    height = compact and 38 or 84, maxLines = compact and 2 or 4 }),
                row({ goldButton("转职 / 晋升", function() self:OfferSelected() end,
                    { id = "unit-upgrade", width = compact and 138 or 166, height = compact and 34 or 44, disabled = true }),
                    button("取消选择", function() self.selected = 0; self:RefreshHUD() end,
                        { width = 116, height = compact and 34 or 40 }) }) },
                { width = "100%", backgroundColor = C.night, padding = compact and 6 or 12, gap = compact and 4 or 10 }),
            label("", { id = "unit-count", fontColor = C.dim, fontSize = 9.75 }),
            label("左侧阵地参战，底部备战席不参战。点击选中，再点击目的地；也可拖拽。",
                { fontColor = C.dim, fontSize = 9.75 }),
        } }
    local cabinet = self:BuildCabinet(wide, compact)
    ---@type Widget[]
    local children = { self:BuildHUD() }
    if self.game.g.tutorial then children[#children + 1] = self:BuildTutorialCoach() end
    children[#children + 1] = UI.ScrollView { id = "game-scroll", width = "100%",
        flexGrow = 1, flexBasis = 0, scrollY = true, bounces = false, children = {
            UI.Panel { id = "game-board", width = "100%", maxWidth = 1120,
                flexDirection = wide and "row" or "column", gap = 18,
                alignItems = "flex-start", padding = 4, paddingBottom = 16,
                children = { field, cabinet } },
        } }
    children[#children + 1] = label("", { id = "notice", fontColor = C.goldHi,
        minHeight = 20, fontSize = 10, width = "100%", textAlign = "center" })
    return UI.Panel { width = "100%", height = "100%", padding = 14,
        gap = 12, alignItems = "center", children = children }
end

function View:BuildHUD()
    return card({ row({
        label("拉杆军团", { fontSize = 18, fontWeight = "bold", fontColor = C.gold }),
        label("", { id = "hud-diff", fontColor = C.dim }),
        label("", { id = "hud-wave", fontWeight = "bold" }),
        row({ Draw.Portrait { sprite = "heart", width = 22, height = 22 },
            label("", { id = "hud-lives", fontWeight = "bold" }) }),
        row({ Draw.Portrait { sprite = "sym_coin", width = 24, height = 24 },
            label("", { id = "hud-gold", fontColor = C.goldHi, fontWeight = "bold" }) }),
        button("音效 开", function() self:ToggleSound() end, { id = "sound", width = 92, height = 36, fontSize = 9.75 }),
        button("主页", function() self:ConfirmHome() end, { width = 70, height = 36, fontSize = 9.75 }),
        button("玩法", function() self:ShowHelp() end, { width = 70, height = 36, fontSize = 9.75 }),
        button("图鉴", function() self.backPage = "game"; self:SetPage("codex") end,
            { width = 70, height = 36, fontSize = 9.75 }),
    }, { width = "100%", gap = 12 }) },
        { width = "100%", maxWidth = 1120, padding = 10, backgroundColor = C.panel })
end

function View:BuildCabinet(wide, compact)
    local reelSize = compact and 90 or 192
    local luckLabels = { label("", { id = "luck", fontColor = C.goldHi }) }
    if not compact then luckLabels[#luckLabels + 1] = label("空转积累幸运，星星出现率上升。", { fontColor = "#e7c9a6", fontSize = 9 }) end
    luckLabels[#luckLabels + 1] = label("", { id = "stamps", fontColor = C.green, fontSize = 9.75,
        height = compact and 18 or nil, maxLines = compact and 1 or nil })
    -- 拉杆是 UI 树里的真实按钮与面板，不另外创建 NanoVG 渲染层。
    local lever = button("", function() self:Spin() end, { id = "lever", width = 58, height = compact and 96 or 194,
        backgroundColor = C.woodDark, borderColor = C.night, padding = 0,
        children = {
            UI.Panel { pointerEvents = "none", width = 16, height = compact and 72 or 122, position = "absolute",
                left = 21, top = 12, backgroundColor = C.night, children = {
                    UI.Panel { id = "lever-stick", position = "absolute", width = 6, height = compact and 34 or 70,
                        left = 5, top = 28, backgroundColor = "#b9c5da", children = {
                            UI.Panel { id = "lever-knob", position = "absolute", width = 28, height = 28,
                                left = -11, top = -20, backgroundColor = C.red,
                                borderColor = "#8e2420", borderWidth = 3 },
                        } },
                } },
            label("拉杆", { position = "absolute", bottom = 14, left = 0, right = 0,
                textAlign = "center", fontSize = 11.25, fontWeight = "bold", pointerEvents = "none" }),
        } })
    return card({
        card({ label("", { id = "next-label", textAlign = "center", fontColor = C.dim, fontSize = 9 }),
            label("", { id = "next-wave", textAlign = "center", fontColor = "#ff9b8c", fontSize = compact and 9 or 10.5,
                height = compact and 18 or nil, maxLines = compact and 1 or nil }) },
            { width = "100%", backgroundColor = C.night, borderColor = C.gold, padding = compact and 4 or 8, gap = compact and 2 or 10 }),
        row({ Draw.Reels { game = self.game, view = self, id = "reels", width = reelSize, height = reelSize }, lever },
            { justifyContent = "center", flexWrap = "no-wrap", gap = 12 }),
        label("", { id = "spin-cost", fontColor = C.goldHi, textAlign = "center", width = "100%" }),
        card(luckLabels, { width = "100%", backgroundColor = C.woodDark, padding = compact and 4 or 8, gap = compact and 2 or 10 }),
        label(self.summary, { id = "spin-summary", fontSize = 9.75, minHeight = compact and 20 or 42,
            height = compact and 20 or nil, maxLines = compact and 1 or nil, fontColor = C.ink }),
        redButton("开战", function() self:Fight() end, { id = "fight", width = "100%", height = compact and 38 or 50, fontSize = compact and 12 or 15 }),
        row({ button("倍速 ×1", function() self.speed = self.speed == 1 and 2 or 1; self:RefreshHUD() end,
            { id = "speed", width = compact and 112 or 132, height = compact and 32 or 40 }),
            button("暂停", function() self:TogglePause() end, { id = "pause", width = compact and 90 or 108, height = compact and 32 or 40 }) }),
    }, { id = "cabinet", width = wide and (compact and 260 or 320) or "100%", maxWidth = wide and (compact and 260 or 320) or 520,
        alignSelf = compact and "flex-start" or "center", backgroundColor = C.wood, borderColor = C.woodDark,
        padding = compact and 8 or 16, gap = compact and 2 or 12 })
end

function View:RefreshHUD()
    if self.page == "squad" then self:RefreshSquad(); return end
    if self.page ~= "game" then return end
    local g = self.game.g
    self:SetLabel("hud-diff", g.tutorial and "新手教程" or (Data.CHAPTERS[g.ch].title .. " · " .. Data.CHAPTERS[g.ch].diffs[g.diff].name))
    self:SetLabel("hud-wave", "波次 " .. g.wave .. "/" .. g.maxWave)
    self:SetLabel("hud-lives", g.lives .. "/" .. g.maxLives)
    self:SetLabel("hud-gold", g.gold)
    self:SetLabel("unit-count", "阵地 " .. countSlots(g.form) .. "/12   备战席 " .. countSlots(g.bench) .. "/8")
    self:SetLabel("next-label", self.battle and not self.battle.result and "本波敌人" or "下一波敌人")
    self:SetLabel("next-wave", self:EnemySummary())
    self:SetLabel("spin-cost", self.spinT > 0 and "转轴转动中……" or g.freeSpins > 0 and
        ("免费拉杆 ×" .. g.freeSpins) or ("花费 " .. self.game:SpinCost() .. " 金币"))
    self:SetLabel("luck", "幸运  " .. string.rep("■", g.luck) .. string.rep("□", math.max(0, g.luckMax - g.luck)))
    local goal = self.game:StampGoal()
    self:SetLabel("stamps", goal > 0 and ("拉杆集点 " .. g.paidSpins .. "/" .. goal .. "，集满送一次免费") or "★ 可以代替任何兵种图标")
    self:SetLabel("spin-summary", self.spinT > 0 and "命运的转轴正在转动……" or self.summary)
    self:SetLabel("unit-info", self:UnitInfo())
    self:SetLabel("notice", self.noticeT > 0 and self.notice or "")
    self:SetLabel("battle-banner", self.bannerT > 0 and self.banner or "")
    self:SetButton("sound", self.soundOn and "音效 开" or "音效 关", false)
    local prep = g.phase == "prep" and self.spinT <= 0 and not self.battle
    self:SetButton("lever", "", not prep or self.modal ~= nil)
    self:SetButton("fight", self.spinT > 0 and "召唤中……" or g.phase == "battle" and "战斗进行中" or "开战",
        not prep or not self.game:CanStart())
    self:SetButton("speed", "倍速 ×" .. self.speed, g.phase ~= "battle")
    self:SetButton("pause", self.paused and "继续" or "暂停", g.phase ~= "battle")
    local unit = self.selected > 0 and self.game:GetSlot(self.selected)
    self:SetButton("unit-upgrade", unit and unit.branch and "已转职" or "转职 / 晋升",
        not prep or not unit or not not unit.branch or unit.star < 3 or (unit.q or 1) > 4)
    if self.game.g.tutorial then self:RefreshCoach() end
end

function View:EnemySummary()
    local list = {}
    if self.battle then
        for _, e in ipairs(self.battle.entities) do
            if e.side == 2 and not e.dead then list[#list + 1] = e end
        end
    else
        for _, e in ipairs(self.preview) do if e.side == 2 then list[#list + 1] = e end end
    end
    local counts, order = {}, {}
    for _, e in ipairs(list) do
        local key = e.type or e.sprite
        if not counts[key] then counts[key] = 0; order[#order + 1] = key end
        counts[key] = counts[key] + 1
    end
    local text = {}
    for _, key in ipairs(order) do text[#text + 1] = (Data.ENEMIES[key] and Data.ENEMIES[key].name or key) .. " ×" .. counts[key] end
    return #text > 0 and table.concat(text, "，") or "本波敌人已被消灭"
end

function View:UnitInfo()
    if self.spinT > 0 then return "转轴转动中……召唤结束前不能再次拉杆或开战。" end
    if self.battle and not self.battle.result then
        local friend, foe = 0, 0
        for _, e in ipairs(self.battle.entities) do
            if not e.dead then if e.side == 1 then friend = friend + 1 else foe = foe + 1 end end
        end
        return (self.paused and "已暂停。" or "战斗中：") .. "我方剩余 " .. friend .. "，敌方剩余 " .. foe ..
            "。能量蓄满后自动释放技能。"
    end
    local u = self.selected > 0 and self.game:GetSlot(self.selected)
    if not u then return "点击单位查看属性；点击目的地或拖拽可以搬移。未转职的一、二星单位可吸收材料，同兵种全经验、跨兵种半经验，品质不变。" end
    local st = self.game:Stats(u)
    local name = Data.FullName(u)
    local text = { name .. (self.selected > 12 and "（备战席，不参战）" or "") ..
        "  生命 " .. st.hp .. "，攻击 " .. st.atk .. "，每秒攻击 " .. string.format("%.2f", 1 / st.cd) .. " 次。" }
    text[#text + 1] = u.branch and (Data.IsSup(u) and "超凡单位不能作为吸收材料。" or "已转职，不能继续吸收材料；仍可作为其他单位的经验材料。") or
        (u.star >= 3 and "已达三星，可以选择转职或晋升。" or
            ("经验 " .. u.pts .. "/" .. Data.STAR_PTS[u.star + 1] .. "，吸收同类积累经验升星。"))
    local af = u.affix
    if af then
        for _, def in ipairs(Data.AFFIXES) do if def.id == af.id then text[#text + 1] = "词条「" .. def.name .. "」" .. def.fmt(af.v); break end end
    end
    local skill = Data.SKILLS[st.skill]
    if skill then text[#text + 1] = "技能「" .. skill.name .. "」" .. skill.desc end
    if u.branch then text[#text + 1] = "被动：" .. Data.BRANCHES[u.branch].passive end
    return table.concat(text, "\n")
end

function View:AfterArmyChange()
    self.preview = Battle.Preview(self.game)
    self:RefreshHUD()
    self:OfferReady()
end

function View:OnCell(index, src)
    if self.page ~= "game" or self.modal or self.spinT > 0 or self.game.g.phase ~= "prep" or self.battle then return end
    if index < 1 or index > 20 then return end
    local source = src and src > 0 and src or self.selected
    if source > 0 and source ~= index and self.game:GetSlot(source) then
        local ok, result = self.game:Move(source, index)
        if ok then
            Audio.Play("merge")
            self.selected = index
            self:Notify(type(result) == "table" and (result.summary or "移动 / 吸收完成") or "移动 / 吸收完成")
            self:AfterArmyChange()
        else self:Notify(result) end
    else
        self.selected = self.selected == index and 0 or (self.game:GetSlot(index) and index or 0)
        self:RefreshHUD()
    end
end

function View:Spin()
    if self.page ~= "game" or self.modal or self.spinT > 0 or self.battle or self.game.g.phase ~= "prep" then return end
    local army = {}
    for i = 1, 20 do
        local unit = self.game:GetSlot(i)
        if unit then
            local copy = {}
            for k, v in pairs(unit) do copy[k] = v end
            if unit.affix then copy.affix = merge({}, unit.affix) end
            army[i] = copy
        else army[i] = false end
    end
    local result, reason = self.game:Spin()
    if not result then Audio.Play("deny"); self:Notify(reason); return end
    self.spinArmy = army
    self.spinResult, self.spinT = result, self.spinDuration
    self.nextTick = 0
    Audio.Play("lever")
    self.selected, self.drag = 0, nil
    self.tutorialSpins = self.tutorialSpins + 1
    self:RefreshHUD()
    if self.root then
        local knob = self.root:FindById("lever-knob")
        if knob then knob:Animate({ keyframes = { [0] = { translateY = 0 }, [0.4] = { translateY = 74 },
            [0.7] = { translateY = 74 }, [1] = { translateY = 0 } }, duration = 0.5 }) end
    end
    print("[拉杆军团/界面] 拉杆动画开始")
end

function View:Fight()
    if self.page ~= "game" or self.modal or self.spinT > 0 or self.battle then return end
    local ok, reason = self.game:Start()
    if not ok then self:Notify(reason); self:OfferReady(); return end
    self.battle = Battle.New(self.game)
    self.seenEffects = setmetatable({}, { __mode = "k" })
    Audio.Play("fight")
    self.banner, self.bannerT = "第 " .. self.game.g.wave .. " 波开战", 1.1
    self.selected, self.drag, self.paused = 0, nil, false
    self:RefreshHUD()
    print("[拉杆军团/界面] 开战，波次=" .. self.game.g.wave)
end

function View:ToggleSound()
    self.soundOn = Audio.Toggle()
    self:SetButton("sound", self.soundOn and "音效 开" or "音效 关", false)
end

function View:TogglePause()
    if self.game.g.phase ~= "battle" then return end
    self.paused = not self.paused
    self:RefreshHUD()
end

function View:OfferReady()
    if self.modal or self.spinT > 0 or self.game.g.phase ~= "prep" then return end
    for index = 1, 20 do
        local u = self.game:GetSlot(index)
        if u and u.star >= 3 and not u.branch and (u.q or 1) <= 4 and not self.offered[u.id] then
            self.offered[u.id] = true
            self.selected = index
            self:ShowAwaken(index)
            return
        end
    end
end

function View:OfferSelected()
    if self.selected > 0 then self:ShowAwaken(self.selected) end
end

function View:ShowAwaken(index)
    local u = self.game:GetSlot(index)
    if not u or u.branch or u.star < 3 or (u.q or 1) > 4 then return end
    local q = u.q or 1
    local quality = Data.QUAL[q]
    ---@type Widget[]
    local children = {
        label("转职立刻换上专属技能与被动，且不能更改；也可晋升品质、从一星重新培养。", { fontColor = C.dim }),
        label(quality.name .. "路线：转职后全属性 +" .. pct(quality.awaken) .. "%", { fontColor = quality.color }),
    }
    for _, key in ipairs(Data.CLASS_BRANCHES[u.cls][q]) do
        local def = Data.BRANCHES[key]
        local skill = Data.SKILLS[def.skill]
        children[#children + 1] = card({
            row({ portrait({ cls = u.cls, branch = key, q = q, star = 3 }, 64), section(def.name, quality.color) }),
            label(def.role, { fontColor = C.dim }),
            label("被动：" .. def.passive),
            label("技能「" .. skill.name .. "」" .. skill.desc),
            goldButton("转职为" .. def.name, function()
                local ok, result = self.game:Awaken(index, key)
                if not ok then Audio.Play("deny"); self:Notify(result); return end
                Audio.Play("up")
                self:CloseModal(); self:AfterArmyChange()
            end, { width = "100%" }),
        }, { width = "100%", backgroundColor = C.night, borderColor = quality.color })
    end
    if q < 4 then
        local nextQ = Data.QUAL[q + 1]
        children[#children + 1] = card({
            section("或者：晋升为" .. nextQ.name, nextQ.color),
            label("品质 +1，星级回到一星，经验清零。暂时变弱，再练到三星后有更强的专属路线。", { fontColor = C.dim }),
            label("下一级路线：" .. Data.RouteNames(u.cls, q + 1), { fontColor = nextQ.color }),
            goldButton("晋升品质", function()
                local ok, result = self.game:Promote(index)
                if not ok then Audio.Play("deny"); self:Notify(result); return end
                Audio.Play("up")
                self:CloseModal(); self:AfterArmyChange()
            end, { width = "100%" }),
        }, { width = "100%", backgroundColor = C.night, borderColor = nextQ.color })
    end
    self:ShowModal(Data.FullName(u) .. " · 转职或晋升", children,
        { button("稍后决定", function() self:CloseModal() end, { width = 132 }) }, "awaken")
end

function View:ShowResult(result)
    local g = self.game.g
    local terminal = g.phase == "victory" or g.phase == "gameover"
    Audio.Play(terminal and (g.phase == "victory" and "victory" or "defeat") or (result.win and "win" or "defeat"))
    if g.tutorial and g.phase == "victory" then
        self:ShowModal("教程完成！", {
            section("拉杆召唤 → 吸收升星 → 转职晋升 → 开战", C.goldHi),
            label("教程不会写入通关进度，也不会产出军魂。正式游戏中，守住每一波都会获得军魂。"),
        }, {
            button("返回主页", function() self:GoHome() end, { width = 132 }),
            goldButton("开始游戏", function() self:GoHome(); self:SetPage("chapter") end, { width = 148 }),
        }, "result")
        return
    end
    local title = terminal and (g.phase == "victory" and (Data.CHAPTERS[g.ch].bossName .. "倒下了") or "军团覆灭")
        or result.win and ("第 " .. result.wave .. " 波胜利") or "防线失守"
    local body = {}
    if terminal then
        body[#body + 1] = section(g.phase == "victory" and ("守住全部 " .. g.maxWave .. " 波！") or ("止步第 " .. result.wave .. " 波"))
        body[#body + 1] = label("拉杆 " .. g.stats.spins .. " 次，召唤 " .. g.stats.summoned .. " 个单位，转职 " ..
            g.stats.awakened .. " 次，晋升 " .. (g.stats.promoted or 0) .. " 次。", { fontColor = C.dim })
        local soul = result.soul
        if soul then body[#body + 1] = label("本局获得 " .. soul.total .. " 军魂 · 守住 " .. soul.waves .. " 波", { fontColor = C.soul }) end
        for _, news in ipairs(result.news or {}) do
            body[#body + 1] = label("新内容解锁：" .. Data.CHAPTERS[news.c].name .. " · " .. Data.CHAPTERS[news.c].diffs[news.d].name,
                { fontColor = C.goldHi })
        end
    else
        body[#body + 1] = label(result.win and ("奖励 +" .. result.base .. " 金币，利息 +" .. (result.interest or 0) .. "。") or
            ("失去一点生命，还剩 " .. g.lives .. "；补给 +" .. result.base .. " 金币。"))
        if (result.soulGain or 0) > 0 then body[#body + 1] = label("军魂 +" .. result.soulGain .. "，完成整局后一并结算。", { fontColor = C.soul }) end
        if g.wave == g.maxWave then body[#body + 1] = label("首领波：" .. Data.CHAPTERS[g.ch].bossWarn(Data.CHAPTERS[g.ch].diffs[g.diff]),
            { fontColor = "#ff9b8c" }) end
    end
    local actions
    if terminal then
        actions = {
            button("回到主页", function() self:GoHome() end, { width = 120 }),
            button("去强化", function() self.battle = nil; self.backPage = "chapter"; self:SetPage("forge") end, { width = 120 }),
            goldButton("继续选关", function() self.battle = nil; self:SetPage("chapter") end, { width = 144 }),
        }
    else
        actions = { goldButton(result.win and ("准备第 " .. g.wave .. " 波") or "重新布阵", function()
            self.battle = nil; self.paused = false; self.selected = 0
            self.preview = Battle.Preview(self.game)
            self:CloseModal(); self:RefreshHUD(); self:OfferReady()
        end, { width = 186 }) }
    end
    self:ShowModal(title, body, actions, "result")
end

function View:BuildCodex()
    local tabs = {}
    for _, cls in ipairs(Data.CLASS_KEYS) do
        tabs[#tabs + 1] = button(Data.CLASSES[cls].name, function() self.codexTab = cls; self:RequestBuild() end,
            { width = 96, height = 40, backgroundColor = self.codexTab == cls and C.panelHi or C.night })
    end
    tabs[#tabs + 1] = button("敌人", function() self.codexTab = "foes"; self:RequestBuild() end,
        { width = 96, height = 40, backgroundColor = self.codexTab == "foes" and C.panelHi or C.night })
    local body = UI.Panel { width = "100%", gap = 14, children = { row(tabs, { width = "100%" }) } }
    if self.codexTab == "foes" then self:BuildEnemyCodex(body) else self:BuildClassCodex(body, self.codexTab) end
    return self:PageFrame("军团图鉴", body, function() self:SetPage(self.backPage) end)
end

function View:BuildClassCodex(body, cls)
    local def = Data.CLASSES[cls]
    local skill = Data.SKILLS[Data.CLASS_SKILL[cls]]
    body:AddChild(label("三星后按自己的品质转职；也可先晋升再培养。普通 → 稀有 → 史诗 → 传说；超凡仅由九格大奖降世。",
        { fontColor = C.dim }))
    body:AddChild(card({ row({ portrait({ cls = cls, q = 1, star = 1 }, 64), section(def.name) }),
        label("基础职业 · " .. def.note .. "。生命 " .. def.hp .. "，攻击 " .. def.atk .. "，射程 " .. def.range),
        label("技能「" .. skill.name .. "」" .. skill.desc),
        label("二星属性 ×" .. Data.STAR_MULT[2] .. "，三星属性 ×" .. Data.STAR_MULT[3], { fontColor = C.dim }),
    }, { width = "100%", backgroundColor = C.night }))
    for q = 1, 5 do
        local quality = Data.QUAL[q]
        body:AddChild(section(quality.name .. " · 基础 +" .. pct(quality.base) .. "% · " ..
            (q == 5 and "超凡之力" or "转职全属性") .. " +" .. pct(quality.awaken) .. "%", quality.color))
        local branches = q == 5 and { Data.SUPER_OF[cls] } or Data.CLASS_BRANCHES[cls][q]
        if q == 5 then body:AddChild(label("九格大奖直接召唤，无需转职，免疫眩晕和魅惑；每个兵种同时只可有一位。", { fontColor = C.dim })) end
        local cards = {}
        for _, key in ipairs(branches) do
            local branch = Data.BRANCHES[key]
            local sk = Data.SKILLS[branch.skill]
            cards[#cards + 1] = card({
                row({ portrait({ cls = cls, branch = key, q = q, star = 3 }, 56), section(branch.name, quality.color) }),
                label(branch.role, { fontColor = C.dim }),
                label("被动：" .. branch.passive),
                label("技能「" .. sk.name .. "」" .. sk.desc),
            }, { width = "100%", borderColor = quality.color, backgroundColor = C.night })
        end
        body:AddChild(UI.SimpleGrid { columns = UI.GetWidth() >= 700 and 2 or 1, gap = 12, children = cards })
    end
end

function View:BuildEnemyCodex(body)
    for ch, chapter in ipairs(Data.CHAPTERS) do
        body:AddChild(section(chapter.name .. " · " .. chapter.title, chapter.color))
        if not self.game:ChapterOpen(ch) then
            body:AddChild(label("通关上一章普通难度后解锁本章敌人图鉴。", { fontColor = C.dim }))
        else
            local keys, cards = {}, {}
            for key, enemy in pairs(Data.ENEMIES) do if enemy.ch == ch then keys[#keys + 1] = key end end
            table.sort(keys)
            for _, key in ipairs(keys) do
                local e = Data.ENEMIES[key]
                cards[#cards + 1] = card({
                    row({ Draw.Portrait { sprite = e.sprite, width = 52, height = 52 },
                        section(e.name, e.big and C.red or chapter.color) }),
                    label((e.big and "首领 · " or "") .. "生命 " .. e.hp .. "，攻击 " .. e.atk),
                    label(e.desc or (e.proj and "远程攻击" or "近战攻击"), { fontColor = C.dim }),
                }, { width = "100%", backgroundColor = C.night, borderColor = chapter.color })
            end
            body:AddChild(UI.SimpleGrid { columns = UI.GetWidth() >= 700 and 2 or 1, gap = 12, children = cards })
        end
    end
end

function View:BuildForge()
    local tabs = {}
    for _, tab in ipairs(Data.UPG_TABS) do
        local key, name = tab[1], tab[2]
        tabs[#tabs + 1] = button(name, function() self.forgeTab = key; self:RequestBuild() end,
            { width = 112, height = 42, backgroundColor = key == self.forgeTab and C.panelHi or C.night })
    end
    local rows, spent = {}, 0
    for _, up in ipairs(self.game:Upgrades()) do
        for level = 1, up.level do spent = spent + up.definition.cost[level] end
        if up.tab == self.forgeTab then
            local def = up.definition
            rows[#rows + 1] = card({
                row({ Draw.Portrait { sprite = up.icon, width = 40, height = 40 }, section(up.name),
                    label("Lv " .. up.level .. "/" .. up.max, { fontColor = C.goldHi }) }),
                label(up.note, { fontColor = C.dim }),
                label("当前：" .. up.text),
                label(up.level < up.max and ("下一级：" .. def.txt(up.level + 1)) or "已满级", { fontColor = C.green }),
                goldButton(up.level >= up.max and "已满级" or ("升级 · " .. up.cost .. " 军魂"), function()
                    local ok, result = self.game:BuyUpgrade(up.id)
                    if ok then self:RequestBuild(); print("[拉杆军团/界面] 购买强化=" .. up.id) else self:Notify(result) end
                end, { width = "100%", disabled = not up.canBuy }),
            }, { width = "100%", backgroundColor = C.night })
        end
    end
    local body = UI.Panel { width = "100%", gap = 14, children = {
        card({ row({ Draw.Portrait { sprite = "m_soul", width = 48, height = 48 },
            section(self.game.progress.meta.s .. " 军魂", C.soul) }),
            label("每守住一波获得军魂，失败也照算；通关与首次通关有额外奖励。永久强化在下一局生效。", { fontColor = C.dim }),
        }, { width = "100%" }),
        row(tabs, { width = "100%" }),
        UI.Panel { width = "100%", gap = 12, children = rows },
        label("已投入 " .. spent .. " 军魂；重置全额返还。", { fontColor = C.dim }),
        button("重置并返还", function()
            self:ShowModal("确认重置军魂强化？", {
                label("所有永久强化将清零，已投入的 " .. spent .. " 军魂全部返还。"),
                label("当前这局已快照的强化不受影响。", { fontColor = C.dim }),
            }, { button("取消", function() self:CloseModal() end, { width = 112 }),
                goldButton("确认重置", function()
                    local refund = self.game:ResetUpgrades()
                    self:CloseModal(); self:RequestBuild()
                    print("[拉杆军团/界面] 重置强化，返还军魂=" .. refund)
                end, { width = 148 }) }, "confirm")
        end, { width = 196, disabled = spent == 0 }),
    } }
    return self:PageFrame("军魂强化", body, function() self:SetPage(self.backPage) end)
end

function View:ShowHelp()
    local body = {
        section("拉杆与召唤"),
        label("每局从七个兵种里选三个。每次拉杆花费三金币，横、竖、斜共八条线，三个相同图标连线召唤一个单位；星星替代任意图标。三个星星至少召唤稀有二星单位。"),
        section("吸收与站位"),
        label("鼠标与触屏均可点击单位，再点目的格子搬移，也可拖拽。未转职的一、二星接收者会吸收材料（超凡不能作材料），同兵种全经验、跨兵种半经验，接收者品质不变；二星需 " .. Data.STAR_PTS[2] .. "，三星需 " .. Data.STAR_PTS[3] .. "。其他情况交换位置。左侧阵地参战，底部备战席不参战。"),
        section("品质、转职与晋升"),
        label("普通 → 稀有 → 史诗 → 传说。品质越高，基础属性和转职加成越高。三星单位可以选择专属转职，也可晋升品质回到一星。超凡仅由九格大奖直接召唤，不必转职。图鉴收录所有兵种的品质路线。"),
        section("战斗与成长"),
        label("战斗全自动，攻击和受伤积攒能量，蓄满释放技能。每章四个难度，通关一个解锁下一个，通关普通解锁下一章。每存十金币，战后多一金币利息，初始最多三金币。每守住一波收集军魂，在主页购买永久强化。"),
        label("空格拉杆，回车开战，P 暂停；按钮可切换倍速。教程不写通关进度、不产军魂。", { fontColor = C.goldHi }),
        label("进度与军魂使用本地存档。网页预览刷新后会清空内存存档，当前版本尚未接入云存档。", { fontColor = C.dim }),
    }
    self:ShowModal("玩法说明", body, { goldButton("知道了", function() self:CloseModal() end, { width = 144 }) })
end

function View:StartTutorial()
    self.game:NewTutorial()
    self.battle, self.drag, self.spinResult = nil, nil, nil
    self.selected, self.spinT, self.tutorialStep, self.tutorialSpins = 0, 0, 1, 0
    self.offered, self.speed, self.paused = {}, 1, false
    self.summary = "教程：点击拉杆，先召唤第一个战士。"
    self.preview = Battle.Preview(self.game)
    self:SetPage("game")
    print("[拉杆军团/界面] 教程开始，不写通关进度、不产军魂")
end

function View:BuildTutorialCoach()
    local compact = UI.GetWidth() > UI.GetHeight() and UI.GetHeight() < 760
    return card({ label("", { id = "coach-text", fontColor = C.goldHi,
            flexGrow = compact and 1 or 0, flexBasis = compact and 0 or "auto" }),
        row({ button("下一步", function() self:NextTutorial() end, { id = "coach-next", width = 132, height = 38 }),
            button("退出教程", function() self:GoHome() end, { width = 132, height = 38 }) }),
    }, { width = "100%", maxWidth = 1120, padding = compact and 6 or 10,
        flexDirection = compact and "row" or "column", alignItems = "center",
        backgroundColor = C.night, borderColor = C.gold })
end

function View:RefreshCoach()
    local steps = {
        "1/6 拉杆召唤：点击右侧红色拉杆（或空格），转轴连线会召唤单位。",
        "2/6 再拉一次，召唤第二个战士。每次召唤结束前不能再次拉杆。",
        "3/6 吸收升星：点选一个战士，再点另一个战士；也可拖过去，吸收后经验增长。",
        "4/6 三星单位可以转职或晋升。点击「下一步」领取三星射手体验。",
        "5/6 选中三星射手，点击转职 / 晋升，选择喜欢的路线。",
        "6/6 点击开战！战斗全自动，能量满自动释放技能；可暂停或切换倍速。",
    }
    self:SetLabel("coach-text", steps[self.tutorialStep] or steps[6])
    self:SetButton("coach-next", self.tutorialStep == 4 and "领取三星射手" or "下一步", self.tutorialStep ~= 4)
end

function View:NextTutorial()
    if not self.game.g.tutorial or self.tutorialStep ~= 4 then return end
    self.game:TutorialGift()
    self.tutorialStep = 5
    self:AfterArmyChange()
    self:RefreshHUD()
end

function View:UpdateTutorial()
    if not self.game.g.tutorial or self.page ~= "game" then return end
    local changed = false
    if self.tutorialStep == 1 and self.tutorialSpins >= 1 and self.spinT <= 0 then self.tutorialStep = 2; changed = true
    elseif self.tutorialStep == 2 and self.tutorialSpins >= 2 and self.spinT <= 0 then self.tutorialStep = 3; changed = true
    elseif self.tutorialStep == 3 then
        for _, u in ipairs(self.game:AllUnits()) do
            if u.star >= 2 or u.pts > Data.STAR_PTS[1] then self.tutorialStep = 4; changed = true; break end
        end
    elseif self.tutorialStep == 5 then
        for _, u in ipairs(self.game:AllUnits()) do
            if u.cls == "archer" and (u.branch or (u.q or 1) > 1) then self.tutorialStep = 6; changed = true; break end
        end
    end
    if changed then self:RefreshCoach() end
end

function View:ReadBattleEffects()
    if not self.battle then return end
    for _, effect in ipairs(self.battle.effects) do
        if not self.seenEffects[effect] then
            self.seenEffects[effect] = true
            if effect.kind == "skill" or effect.kind == "phase" then
                self.banner, self.bannerT = tostring(effect.text or "技能释放"), 0.9
                Audio.Play("skill")
            elseif effect.kind == "impact" and self.hitCooldown <= 0 then
                Audio.Play("hit")
                self.hitCooldown = 0.12
            end
        end
    end
end

function View:Update(dt)
    if self.stopped then return end
    self.time = self.time + dt
    self.hitCooldown = math.max(0, self.hitCooldown - dt)
    self.bannerT = math.max(0, self.bannerT - dt)
    local w, h = UI.GetWidth(), UI.GetHeight()
    if math.abs(w - self.screenW) > 2 or math.abs(h - self.screenH) > 2 then
        self.screenW, self.screenH = w, h
        self:RequestBuild()
    end
    -- 每次重建只在 Update 执行，绝不在按钮自身回调里销毁按钮。
    if self.dirty then self:BuildRoot() end
    if self.noticeT > 0 then
        self.noticeT = math.max(0, self.noticeT - dt)
        if self.noticeT == 0 then self:SetLabel("notice", "") end
    end
    -- 转轴使用独立时钟，不受战斗倍速、暂停或查看图鉴影响。
    if self.spinT > 0 then
        self.spinT = math.max(0, self.spinT - dt)
        self.nextTick = self.nextTick - dt
        if self.nextTick <= 0 and self.spinT > 0 then Audio.Play("tick"); self.nextTick = 0.12 end
        if self.spinT == 0 then
            self.spinArmy = nil
            Audio.Play("stop")
            if self.spinResult.jackpot then Audio.Play("jackpot")
            elseif #(self.spinResult.units or {}) > 0 then Audio.Play("win") end
            self.summary = tostring(self.spinResult.summary or "召唤结束")
            self.preview = Battle.Preview(self.game)
            self:RefreshHUD()
            self:OfferReady()
            print("[拉杆军团/界面] 召唤结束：" .. self.summary)
        end
    end
    if self.page == "game" and self.battle and not self.battle.result and not self.modal and not self.paused then
        self.battle:Update(dt * self.speed)
        self:ReadBattleEffects()
        if self.battle.result then
            local result = self.game:FinishBattle(self.battle.result == "win")
            self:ShowResult(result)
            print("[拉杆军团/界面] 战斗结果=" .. self.battle.result)
        end
    end
    self:UpdateTutorial()
    self:RefreshHUD()
end

function View:KeyDown(key)
    if self.modal then
        if key == KEY_ESCAPE and self.modal.kind ~= "result" then self:CloseModal() end
        return
    end
    if key == KEY_ESCAPE then
        if self.page == "game" then self:ConfirmHome()
        elseif self.page == "codex" or self.page == "forge" then self:SetPage(self.backPage)
        else self:GoHome() end
    elseif self.page == "game" then
        if key == KEY_SPACE then self:Spin()
        elseif key == KEY_RETURN then self:Fight()
        elseif key == KEY_P then self:TogglePause() end
    end
end

function View:Stop()
    if self.stopped then return end
    self.stopped = true
    self.battle, self.drag = nil, nil
    Audio.Stop()
    Draw.Shutdown()
    UI.Shutdown()
    self.root = nil
    print("[拉杆军团/界面] 已停止并释放资源")
end

return View
