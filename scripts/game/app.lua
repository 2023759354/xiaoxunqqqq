-- ---------------------------------------------------------------------------
-- 应用装配：页面（原版 HTML + CSS）+ 游戏逻辑 + 界面，与引擎无关
-- main.lua 负责创建 NanoVG、转发输入、驱动每帧；测试脚本也直接用这个模块
-- ---------------------------------------------------------------------------
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local N = require("game.core")
local _ENV = N
require("game.render")
require("game.ui")
require("game.ui_shop")
require("game.rules")
require("game.chapters")
require("game.balance")  -- 第三次更新：降低第三～五章难度
require("game.chapters2") -- 第六次更新：第八～十章「霜寒冰原 / 天空浮城 / 终焉王座」
require("game.equip")    -- 更新：每个单位 3 个装备栏、新装备
require("game.skillfx")  -- 更新：全部技能特效、吸收经验进度
require("game.skillfx2") -- 第三次更新：树根、地刺、箭雨、陨石、爪痕等实体化技能特效
require("game.skillfx3") -- 第六次更新：新兵种、新敌人、新首领、限定装备的特效
require("game.layout")   -- 更新：按屏幕尺寸自适应排版
require("game.items2")   -- 第三次更新：独立图标、新道具、商店免费刷新、商店装备位
require("game.unitcard") -- 第三次更新：单位卡片、装备转移、圣物栏、紧凑菜单
require("game.equip2")   -- 第六次更新：兵种限定装备与新装备
require("game.itemhalo") -- 第八次更新：道具图标按品质加光圈、撞脸图标换新图
require("game.meter")    -- 第九次更新：战斗统计（输出 / 承伤 / 治疗），只在战斗中显示
require("game.mithril")  -- 第九次更新：秘银货币、独立商店（不再每波弹出）、精英战利品刷新
require("game.ui_redo")  -- 第十次更新：选关、组建军团、商店界面重新设计
require("game.inspect")  -- 第十次更新：点地块、点敌人查看效果和数值
require("game.skillfix") -- 第十次更新：技能和描述对齐（巨龙降临真的飞过去等）
require("game.skills_sup") -- 第十二次更新：超凡角色的新技能、专属特效和主题光效
require("game.ui13")      -- 第十三次更新：分界面背景音乐标记、结算界面重做、精英战利品锁定 + 秘银刷新
require("game.equipdrag") -- 第十四次更新：装备管理改成拖放（拖给角色 / 拖进仓库 / 拖去出售）
require("game.jackpot14") -- 第十四次更新：提高九格大奖几率的圣物
require("game.balance14") -- 第十四次更新：转职 / 敌人 / 首领强度调整
require("game.skills14")  -- 第十四次更新：雷同技能重做（机制 + 特效）
require("game.relic15")   -- 第十五次更新：圣物 8 格、仓库 10 格并可放圣物；圣物栏满时战利品 / 商店可放仓库或替换
local PX = require("game.pixel")
local PAGE_M = require("ui.page")
local PAINT = require("ui.paint")
local CONTENT = require("ui.content")
local ANIM = require("ui.anim")

local App = {}

local function imageSize(src)
    local img = ICONS[src]
    if img then return img.width, img.height end
    return 0, 0
end

function App.boot(opts)
    buildSave()
    META = loadMeta()
    PAGE = PAGE_M.new({ html = CONTENT.body, css = CONTENT.css, vw = opts.vw, vh = opts.vh,
        envVars = opts.envVars, imageSize = imageSize })
    App.page = PAGE
    local anim = ANIM.new(PAGE)
    App.anim = anim
    anim.now = opts.nowMs or 0
    PAGE.onStyle = function(el, ps, oldStyle, newStyle) anim:onStyle(el, ps, oldStyle, newStyle) end
    PAGE.onRemoveHook = function(node) anim:onRemove(node) end
    App.host.transformOverride = function(box) return anim:transform(box) end
    App.host.opacityOverride = function(box) return anim:opacity(box) end
    App.host.offsetY = function(box) return anim:offsetY(box) end
    App.host.colorOverride = function(box, prop) return anim:color(box, prop) end
    App.host.isAnimating = function(box) return anim:active(box) end
    PAGE.doc.documentElement:setAttribute('lang', 'zh-CN')
    arenaEl = PAGE.doc.getElementById('arena')
    bgFor('grass')
    buildFloor()
    PAGE.doc.documentElement:setStyle('--floor', 'url(floor)')
    newGame()
    UI.init()
    UI.update()
    UI.showHome()
    Timers.now = opts.nowMs or 0
    frameReset(opts.nowMs or 0)
    return App
end

function App.frame(nowMs)
    App.anim.now = nowMs
    Timers.advance(nowMs)
    frame(nowMs)
    PAGE:update()
end

local canvasOf = {
    arena = function() return arenaCv end,
    slot = function() return slotCv end,
    homeArt = function() return homeCv end,
}

local function drawImg(vg, img, x, y, w, h, dpr, colorFn)
    if not colorFn then return PX.drawImageNVG(vg, img, x, y, w, h, dpr, 1) end
    return PX.drawImageNVG(vg, img, x, y, w, h, dpr, 1, colorFn)
end

App.host = {
    fontRegular = 'sil',
    fontBold = 'sil-b',
    drawImage = function(vg, src, x, y, w, h, dpr, colorFn)
        local img = ICONS[src]
        if img then drawImg(vg, img, x, y, w, h, dpr, colorFn) end
    end,
    drawCanvas = function(vg, el, x, y, w, h, dpr, colorFn)
        local getter = canvasOf[el.attrs.id]
        local canvas = getter and getter()
        if canvas then canvas:drawNVG(vg, x, y, w, h, dpr, 1, colorFn) end
    end,
    drawPattern = nil,
}

function App.paint(vg, dpr)
    PAINT.paint(PAGE, vg, dpr, App.host)
    if paintOverlay then paintOverlay(vg, dpr, App.host) end -- 第十四次更新：拖动中的装备图标画在最上层
end

return App
