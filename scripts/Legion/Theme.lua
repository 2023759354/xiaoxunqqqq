-- PixelForge 硬边主题，保留《拉杆军团》的紫色、黄铜和木柜配色。
local UI = require("urhox-libs/UI")
local Theme = {}
Theme.C = {
    bg = "#241b39", night = "#1b1530", panel = "#3a2d52", panelHi = "#4b3c69",
    ink = "#f1e3c2", dim = "#b9aacb", gold = "#e2b33c", goldHi = "#ffe27a",
    red = "#d8433a", wood = "#6b3f22", woodDark = "#4a2a15", green = "#8fe07a", soul = "#6ef0ff",
}
Theme.colors = Theme.C

---@param hex string
---@return table
function Theme.Color(hex)
    local s = hex:gsub("#", "")
    return { tonumber(s:sub(1, 2), 16) or 255, tonumber(s:sub(3, 4), 16) or 255,
        tonumber(s:sub(5, 6), 16) or 255, 255 }
end

function Theme.Init()
    local hard = { { x = 3, y = 3, blur = 0, color = { 10, 10, 26, 204 } },
        { x = -1, y = -1, blur = 0, color = { 255, 255, 255, 48 } } }
    local theme = UI.Theme.ExtendTheme(UI.Theme.defaultTheme, {
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/FusionPixel-12px-Prop-zh_hans.ttf",
                bold = "Fonts/FusionPixel-12px-Prop-zh_hans-Bold.ttf",
            } },
            { family = "mono", weights = { normal = "Fonts/FusionPixel-12px-Mono-zh_hans.ttf" } },
        },
        colors = {
            primary = { 33, 189, 174, 255 }, primaryHover = { 61, 208, 193, 255 }, primaryPressed = { 25, 168, 153, 255 },
            secondary = { 108, 92, 231, 255 }, secondaryHover = { 133, 119, 237, 255 }, secondaryPressed = { 90, 75, 214, 255 },
            background = Theme.Color(Theme.C.bg), surface = Theme.Color(Theme.C.panel), surfaceHover = Theme.Color(Theme.C.panelHi),
            text = Theme.Color(Theme.C.ink), textSecondary = Theme.Color(Theme.C.dim),
            textDisabled = { 80, 80, 112, 255 }, disabledText = { 100, 90, 120, 255 }, disabled = { 42, 42, 74, 255 },
            border = { 27, 21, 48, 255 }, borderFocus = { 226, 179, 60, 255 }, overlay = { 15, 10, 28, 220 },
            success = { 80, 200, 120, 255 }, successHover = { 102, 216, 142, 255 },
            warning = { 255, 217, 61, 255 }, warningHover = { 255, 224, 102, 255 },
            error = { 255, 71, 87, 255 }, errorHover = { 255, 107, 122, 255 },
            info = { 69, 170, 242, 255 },
        },
        componentDefaults = { borderRadius = 0 },
        components = {
            Panel = { borderRadius = 0 },
            Button = { borderRadius = 0, borderWidth = 2, boxShadow = hard, fontSize = 10.5, height = 44 },
            Label = { fontSize = 10.5 },
            Card = { borderRadius = 0, borderWidth = 2, boxShadow = { { x = 4, y = 4, blur = 0, color = { 10, 10, 26, 204 } } } },
            Modal = { borderRadius = 0, borderWidth = 2, headerBgColor = { 27, 21, 48, 255 },
                headerBorderWidth = 2, headerFullWidthBorder = true, footerBorderWidth = 2,
                footerFullWidthBorder = true, contentPadding = 16, footerPadding = { 10, 16 },
                boxShadow = { { x = 4, y = 4, blur = 0, color = { 0, 0, 0, 204 } } } },
            Toast = { borderRadius = 0, borderWidth = 2, showIcon = false,
                boxShadow = { { x = 3, y = 3, blur = 0, color = { 10, 10, 26, 204 } } } },
            ProgressBar = { borderRadius = 0, borderWidth = 2, height = 12 },
            ScrollView = { borderRadius = 0 },
        },
    })
    UI.Init({ theme = theme, scale = UI.Scale.DEFAULT })
    print("[拉杆军团] PixelForge 像素字体与 UI 主题已初始化")
end

return Theme
