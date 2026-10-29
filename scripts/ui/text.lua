-- ============================================================================
-- 文字测量与断行规则（与 Chromium 的结果保持一致）
--  * 拉丁字母、数字、常用符号用 Silkscreen（像素字体，原版通过 Google Fonts 加载）
--  * 其余字符（中文、全角标点、★ 等）回落到中文字体
--  * 行盒高度只看首选字体（Silkscreen）的上下沿，和浏览器一样
-- ============================================================================
local FM = require("ui.fontmetrics")
local M = {}

local floor = math.floor

-- Silkscreen 的垂直度量（em）：typo ascender 1030 / descender 250，x-height 500
M.ASC, M.DESC, M.XH = 1.03, 0.25, 0.5

--- 浏览器把字体上下沿取整到整数像素
function M.metrics(fs)
    local asc = floor(M.ASC * fs + 0.5)
    local desc = floor(M.DESC * fs + 0.5)
    return asc, desc, M.XH * fs
end

local function isBold(w) return w >= 600 end

--- 码点的字宽（em）
local function emOf(cp, bold)
    local t = bold and FM.silkBold or FM.silk
    local a = t[cp]
    if a == nil then a = (bold and FM.cjkBold[cp]) or FM.cjk[cp] or 1 end
    return a
end

-- FreeType 的定点缩放（两种字体的 unitsPerEm 都是 1000）：
--   x_scale = FT_DivFix(字号 26.6, 1000)；步进(16.16) = FT_MulDiv(字宽单位, x_scale, 64)
-- Chromium 在 Linux 上就是这样得到字形步进的，再把每段文字的宽度向上取整到 1/64 像素
local xsCache = {}
local function xScale(fs)
    local xs = xsCache[fs]
    if not xs then
        local s26 = floor(fs * 64)
        xs = (s26 * 65536 + 500) // 1000
        xsCache[fs] = xs
    end
    return xs
end

--- 单个码点的步进（16.16 定点整数）
local advCache = {}
function M.adv16(cp, fs, weight)
    local bold = isBold(weight)
    local key = bold and -fs or fs
    local t = advCache[key]
    if not t then t = {}; advCache[key] = t end
    local a = t[cp]
    if not a then
        local units = floor(emOf(cp, bold) * 1000 + 0.5)
        a = (units * xScale(fs) + 32) // 64
        t[cp] = a
    end
    return a
end

--- 单个码点的步进（px）
function M.advance(cp, fs, weight)
    return M.adv16(cp, fs, weight) / 65536
end

--- 16.16 宽度和 → 布局单位（向上取整到 1/64 像素）
function M.lu(s16)
    return math.ceil(s16 / 1024 - 1e-7) / 64
end

--- 码点是否由 Silkscreen 渲染
function M.inPrimary(cp, weight)
    local t = isBold(weight) and FM.silkBold or FM.silk
    return t[cp] ~= nil
end

-- ---------------------------------------------------------------------------
-- 断行：用在 Chromium 里实测得到的断行机会表（ui/linebreak.lua）
-- 类别：'SP' 表示空白，其余是行为桶编号
-- ---------------------------------------------------------------------------
local LB = require("ui.linebreak")

function M.classOf(cp)
    if cp == 32 or cp == 9 or cp == 10 or cp == 13 then return 'SP' end
    local b = LB.bucket[cp]
    if b then return b end
    if (cp >= 0x2E80 and cp <= 0x9FFF) or (cp >= 0xF900 and cp <= 0xFAFF) or (cp >= 0xAC00 and cp <= 0xD7AF) or (cp >= 0x20000) then return LB.ID end
    return LB.AL
end

--- 能否在 b 之前断行。a：前一个字符的类别；nsp：空格之前最后一个非空白字符的类别；pp：a 之前的字符类别（nil = 行首）
function M.canBreakBetween(a, b, nsp, pp)
    if b == 'SP' then return false end -- 空格之前不断（空格挂在行尾）
    if a == 'SP' then
        if nsp == nil then return true end
        return LB.sp[nsp][b]
    end
    if a == LB.HY and (pp == nil or pp == 'SP') and LB.sotNo[b] then return false end
    return LB.direct[a][b]
end

-- ---------------------------------------------------------------------------
-- 全角标点挤压（Chromium 的 text-spacing-trim: normal，实测得到的规则）
--  * 开括号前面是开括号 / 闭括号 / 句读点 / 引号 / 间隔号 / 全角空格时，去掉左半边
--  * 闭括号与句读点后面是闭括号 / 句读点 / 右引号 / 间隔号 / 全角空格时，去掉右半边
--  * 行尾的闭括号放不下时，可以去掉右半边来挤进这一行（allow-end）
-- ---------------------------------------------------------------------------
local P_OPEN, P_CLOSE, P_DOT, P_PREV, P_NEXT = {}, {}, {}, {}, {}
for _, cp in utf8.codes('「（《【〈『〔') do P_OPEN[cp] = true end
for _, cp in utf8.codes('」）》】〉』〕') do P_CLOSE[cp] = true end
for _, cp in utf8.codes('、。，．：；') do P_DOT[cp] = true end
for cp in pairs(P_OPEN) do P_PREV[cp] = true end
for cp in pairs(P_CLOSE) do P_PREV[cp] = true; P_NEXT[cp] = true end
for cp in pairs(P_DOT) do P_PREV[cp] = true; P_NEXT[cp] = true end
for _, cp in utf8.codes('“”‘’·・　') do P_PREV[cp] = true end
for _, cp in utf8.codes('”’·・　') do P_NEXT[cp] = true end
M.P_OPEN, M.P_CLOSE, M.P_DOT, M.P_PREV, M.P_NEXT = P_OPEN, P_CLOSE, P_DOT, P_PREV, P_NEXT

return M
