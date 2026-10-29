-- ============================================================================
-- 拉杆军团（UrhoX 版）入口
-- 原版是单文件 HTML（DOM + CSS + canvas + WebAudio）。这里用 Lua 实现了一个小型
-- HTML/CSS 排版与绘制引擎，加载原版的页面结构与样式表，再用 NanoVG 画出来；
-- 游戏逻辑、界面代码逐行移植自原版，保证在引擎里看到的效果与浏览器里一致。
--
-- 坐标约定：1 个 CSS 像素 = DPR 个物理像素（与浏览器的 devicePixelRatio 相同）
-- ============================================================================
local cjson = require("cjson")
local App = require("game.app")
local Music = require("game.music")
local AudioAssets = require("game.audio_assets")
local AudioRecovery = require("game.audio_recovery")
local N = require("game.env")
local INPUT = require("ui.input")
local PAGE_M = require("ui.page")

---@type NVGContextWrapper?
local vg = nil
---@type table?
local inputMgr = nil
local nowMs = 0
local floorImage = -1
-- GPU 设备丢失（WebGPU device lost / 驱动重置）后，vg 里的字体与纹理句柄全部失效，
-- 必须停止绘制、等 DeviceReset 重建，否则每帧都会对已失效的上下文提交命令。
local deviceLost = false
-- 真机字体资源可能异步下载未完成：先不阻断启动，稍后重试加载
local fontsReady = false
-- 重试计数与节流（避免每帧无脑重试）
local fontRetryAt, fontRetryN = 0, 0
-- 战场背景纹理句柄缓存：设备重建后必须清空，否则会拿着旧句柄继续画
local texCache = {}
---@type Scene?
local scene_ = nil
---@type Node?
local soundNode = nil
---@type SoundSource[]
local soundPool = {}
local priorityPool, priorityIdx = {}, 0 -- 高优先级音效专用音源（initAudio 里填充）
local soundIdx = 0
---@type table<string, Sound>
local sounds = {}
local physW, physH, dpr = 0, 0, 1
local isMobile = false
local audioGeneration = 0
local isIOS = false

-- ---------------------------------------------------------------------------
-- 存档（对应原版的 localStorage）
-- ---------------------------------------------------------------------------
local SAVE_FILE = "save.json"

local function loadStore()
    if fileSystem:FileExists(SAVE_FILE) then
        local f = File(SAVE_FILE, FILE_READ)
        if f:IsOpen() then
            local ok, data = pcall(cjson.decode, f:ReadString())
            f:Close()
            if ok and type(data) == "table" then
                for k, v in pairs(data) do N.store.data[k] = tostring(v) end
            end
        end
    end
end

local function persistStore(data)
    local f = File(SAVE_FILE, FILE_WRITE)
    if f:IsOpen() then
        f:WriteString(cjson.encode(data))
        f:Close()
    end
end

-- ---------------------------------------------------------------------------
-- 音效：全部 Ogg；SoundSource 池轮流播放（可叠加）
-- ---------------------------------------------------------------------------
local SOUND_NAMES = { 'tick', 'stop', 'lever', 'win', 'jackpot', 'q1', 'q2', 'q3', 'summon', 'absorb', 'star', 'hit', 'shoot',
    'die', 'fight', 'victory', 'defeat', 'deny', 'drop', 'skill', 'awaken', 'zap', 'unlock', 'q4', 'ult', 'merge', 'up',
    'shop', 'buy', 'refresh', 'sell', 'item',
    -- 第十三次更新：锁定 / 解锁、购买、装备、卸下、金币换秘银
    'lock', 'unlockslot', 'purchase', 'equip', 'unequip', 'exchange' }

local function initAudio()
    scene_ = Scene()
    soundNode = scene_:CreateChild("Sounds")
    for i = 1, 16 do
        local source = soundNode:CreateComponent("SoundSource")
        source.soundType = SOUND_EFFECT
        soundPool[i] = source
    end
    -- 高优先级音效的专用音源（玩家主动操作的反馈，不能被战斗音效挤掉）
    priorityPool, priorityIdx = {}, 0
    for i = 1, 6 do
        local source = soundNode:CreateComponent("SoundSource")
        source.soundType = SOUND_EFFECT
        priorityPool[i] = source
    end
    audioGeneration = audioGeneration + 1
    local generation = audioGeneration
    local completed, loaded = 0, 0
    for _, n in ipairs(SOUND_NAMES) do
        local path = AudioAssets.effects[n]
        AudioAssets.load(path, function(sound)
            if generation ~= audioGeneration then return end
            completed = completed + 1
            if sound and sound.length > 0 then
                sounds[n] = sound
                loaded = loaded + 1
            else
                print('[拉杆军团] 音效加载失败：' .. path)
            end
            if completed == #SOUND_NAMES then print('[拉杆军团] 音效加载完成：' .. loaded .. '/' .. #SOUND_NAMES) end
        end)
    end
end

-- 高优先级音效：用独立音源池播放，避免被战斗中密集的命中/射击音效挤掉
-- （第十三次更新：锁定、解锁、购买、装备、卸下、兑换这类玩家主动操作必须听得到）
local PRIORITY_SFX = {
    lock = true, unlockslot = true, purchase = true, equip = true,
    unequip = true, exchange = true, unlock = true, buy = true, sell = true, item = true,
}

local function playSound(name)
    if N.Ads.busy or not AudioRecovery.foreground then return end
    local s = sounds[name]
    if not s then return end
    if PRIORITY_SFX[name] and #priorityPool > 0 then
        priorityIdx = priorityIdx % #priorityPool + 1
        priorityPool[priorityIdx]:Play(s, 0, 1.0)
        return
    end
    if #soundPool == 0 then return end
    soundIdx = soundIdx % #soundPool + 1
    local src = soundPool[soundIdx]
    src:Play(s, 0, 1.0)
end

-- ---------------------------------------------------------------------------
-- 视口：直接使用设备的逻辑像素（DPR 换算），画布内排版交给 game.layout 自适应
-- ---------------------------------------------------------------------------
--- 设计分辨率（第四次更新）：以「短边 400 设计像素」为基准
--  * 手机（短边 360~430 dp/pt）：1 设计像素 = 1 dp/pt，字号就是系统字号（最小 12，正文 13~14）
--  * 平板、电脑：按短边放大，指数 0.65 让大屏既放大字号又多放一点内容：
--      短边 768 → 1.53 倍（设计高度约 500），1024 → 1.84 倍（约 556），1080 → 1.91 倍（约 566），1440 → 2.3 倍
--  放大后再交给排版，等于在一块「更小但更清晰」的屏幕上排版，所以不会裁切
--
--  重要（真机适配）：小游戏容器里 graphics:GetDPR() 常常返回 1，即使设备是 @3x 屏。
--  这时物理尺寸报的是 1280×591 而不是 2436×1125，若按上表放大就会把手机当成平板，
--  字号被放大 ~29%、排版也换成大屏方案。所以对「超宽比且尺寸偏小」的屏幕直接认成手机：
--  长宽比 ≥ 1.9 且短边 ≤ 620 → 按手机处理（短边固定 375 设计像素，zoom = 1）。
local DESIGN_SHORT = 400
local PHONE_SHORT = 375   -- 手机设计短边（iPhone 812×375 / 375×812 等）
local function uiZoom(w, h)
    local short = math.min(w, h)
    local long = math.max(w, h)
    -- 超宽比的小屏：真机 @2x/@3x 但引擎报 DPR=1 的情况（如 1280×591、1334×750）
    -- 阈值 1.7：覆盖 16:9 手机横屏（1.78），同时排除平板（4:3 = 1.33）和电脑（16:10 = 1.6）
    if short <= 620 and long / math.max(1, short) >= 1.7 then
        return short / PHONE_SHORT
    end
    if short <= DESIGN_SHORT then return 1 end
    return math.min(3.2, (short / DESIGN_SHORT) ^ 0.65)
end
local zoom = 1
local safeKey = ""
local safeCheckT = 0
local appliedKey = ""       -- 上次交给页面的视口（尺寸 + DPR + 安全区）
local forceViewport = false -- 下一帧无条件重新排版一次
local watchUntil = 0        -- 这个时刻之前每帧都核对视口

-- ---------------------------------------------------------------------------
-- 第七次更新：iPhone 横屏只让出灵动岛 / 刘海那一侧
-- 系统给的横屏安全区左右都是 59pt（对称），但灵动岛只在一侧，而且只占离边缘 11~48pt 的一小段。
-- 以前左右各让 59pt，两边各浪费一整条。现在：
--   * 灵动岛那一侧只让 ISLAND_W（灵动岛 / 刘海的外沿）
--   * 另一侧只留 EDGE_W（屏幕圆角），其余空间全部给界面，战场优先
-- 灵动岛在哪一侧：玩家手动设置 > 系统给的左右安全区不对称 > 引擎报的屏幕方向 > 上次的结果 > 默认左侧
-- ---------------------------------------------------------------------------
-- 真机实测胶囊外沿约 42~43dp（系统安全区报 59pt）。取 46 仍留 3~4dp 余量，
-- 再把顶栏在胶囊侧的内边距从 12 收到 4，左栏内容整体左移约 10dp，不再空出一条。
local ISLAND_W = 46
local EDGE_W = 8
local ISLAND_KEY = 'reel-legion-island' -- 存档：'L' / 'R' / 不存（自动）
local lastSide = 'L'
SAFE_INFO = { island = false, side = 'L', manual = false } -- 菜单里的「灵动岛位置」按钮读这里

--- 引擎报的屏幕方向 → 'L'（灵动岛在左）/ 'R'（在右）/ nil（不知道）
--  只认意思明确的写法：landscapeReverse / flipped = 主屏幕键在左 → 灵动岛在右；单独的 landscape = 灵动岛在左
local function orientSide()
    local function parse(v)
        if v == nil then return nil end
        local s = string.lower(tostring(v))
        if s:find('portrait', 1, true) then return nil end
        if s:find('reverse', 1, true) or s:find('flipped', 1, true) then return 'R' end
        if s == 'landscape' then return 'L' end
        return nil
    end
    for _, name in ipairs({ 'GetScreenOrientation', 'GetDeviceOrientation', 'GetDisplayOrientation' }) do
        local fn = _G[name]
        if type(fn) == 'function' then
            local ok, v = pcall(fn)
            local s = ok and parse(v) or nil
            if s then return s end
        end
    end
    -- 只允许一种横屏方向时（Urho 的 Orientations 设置），方向是固定的
    if graphics then
        local ok, o = pcall(function() return graphics:GetOrientations() end)
        if ok and type(o) == 'string' then
            local hasL, hasR = o:find('LandscapeLeft', 1, true) ~= nil, o:find('LandscapeRight', 1, true) ~= nil
            if hasR and not hasL then return 'L' end -- 主屏幕键在右 → 灵动岛在左
            if hasL and not hasR then return 'R' end
        end
    end
    return nil
end

local function islandSide(l, r)
    local m = N.store and N.store.data and N.store.data[ISLAND_KEY]
    if m == 'L' or m == 'R' then return m, true end
    if math.abs(l - r) > 6 then lastSide = (l > r) and 'L' or 'R'; return lastSide, false end
    local s = orientSide()
    if s then lastSide = s end
    return lastSide, false
end

--- 切屏（旋转 / 分屏 / 折叠）后，容器偶尔会先报出上一轮方向的尺寸：
--- 横屏游戏拿到「高 > 宽」的值，页面就会按竖屏排版，画布只占左边一条（表现为半屏 + 右边黑边）。
--- 本作固定横屏：竖着拿手机时把「画面 + 触摸」一起旋转 90°（见 rt / HandleRender），
--- 绝不能再把宽高对调——对调后 page 视口与真实表面方向不一致，截屏取证时只截得到左半边。
local rt = false          -- 当前是否旋转 90° 绘制（容器比宽还高）
local physRawW, physRawH = 0, 0 -- 容器报的原始尺寸（未旋转）
--- 读容器尺寸并确定是否旋转；Phys 尺寸统一返回「横屏方向」的值
local function updateOrientation()
    physRawW, physRawH = graphics:GetWidth(), graphics:GetHeight()
    rt = (physRawW > 0 and physRawH > 0 and physRawH > physRawW)
    return physRawW, physRawH
end

local function readViewport()
    -- 竖着拿手机（容器比宽还高）时旋转 90° 绘制：设计视口按「高×宽」的方向排版，
    -- 画布与触摸由 HandleRender / xy() 一起旋转。这里绝不能把宽高对调了事——
    -- 那样 page 视口和真实表面方向不一致，截屏取证只会截到左半边。
    local rawW, rawH = updateOrientation()
    if rt then physW, physH = rawH, rawW else physW, physH = rawW, rawH end
    local sysDpr = graphics:GetDPR()
    if not sysDpr or sysDpr <= 0 then sysDpr = 1 end
    zoom = uiZoom(physW / sysDpr, physH / sysDpr)
    dpr = sysDpr * zoom
    local env = {}
    -- 第五次更新：安全区（灵动岛 / 刘海 / 挖孔）。下面统一用 dp（= iOS 的 pt）计算
    local l, t, r, b = 0, 0, 0, 0
    local function readInsets(arg)
        local ok, rc = pcall(GetSafeAreaInsets, arg)
        if not (ok and rc and rc.min and rc.max) then return end
        local a, c, d, e = rc.min.x or 0, rc.min.y or 0, rc.max.x or 0, rc.max.y or 0
        -- 有的平台返回的是「安全矩形」的右下角坐标而不是边距：换算成边距
        local wd, hd = physW / sysDpr, physH / sysDpr
        if d > physW * 0.5 then d = physW - d elseif d > wd * 0.5 then d = (wd - d) * sysDpr end -- 物理像素 / dp 的矩形
        if e > physH * 0.5 then e = physH - e elseif e > hd * 0.5 then e = (hd - e) * sysDpr end
        local function toDp(v)
            v = math.max(0, v or 0)
            if v > math.max(physW, physH) * 0.25 then return 0 end -- 不可能是边距，丢掉
            -- 单位判断：真机的安全区至少 20dp 左右；按物理像素换算后小得离谱，说明本来就是 dp / pt
            if v > 0 and sysDpr > 1.2 and v / sysDpr < 14 and v >= 14 then return v end
            return v / sysDpr
        end
        l, t, r, b = math.max(l, toDp(a)), math.max(t, toDp(c)), math.max(r, toDp(d)), math.max(b, toDp(e))
    end
    if GetSafeAreaInsets then readInsets(false); readInsets(true) end
    -- 竖着拿手机、画面旋转 90° 绘制：安全区跟着一起转（物理 top → 画面 left，依此类推），
    -- 旋转后「横屏」语义才成立，下面的横屏判断与灵动岛分段避让照常生效。
    if rt then l, t, r, b = t, r, b, l end
    -- 兜底下限：引擎没给安全区、或者给小了时，也保证摄像头不压在按钮和文字上（安全区外照样铺背景）
    --  * 长宽比 ≥ 1.9 基本都是刘海 / 灵动岛 / 挖孔屏；iPhone SE、老式 16:9 安卓不受影响
    --  * iPhone 灵动岛横屏时离屏幕边缘约 11~48pt（系统安全区报 59pt）：灵动岛一侧让 48pt，另一侧 8pt；底部横条至少 14dp
    --    竖屏：顶部至少 54dp，底部至少 30dp
    --  * 安卓挖孔一般在离边缘 20~40dp 以内：横屏左右至少 32dp，竖屏顶部至少 32dp
    --  * iOS 横屏（第七次更新）：只在灵动岛那一侧让 48pt，另一侧 8pt，见上面的 ISLAND_W / EDGE_W
    --  * 安卓按系统给的实际值，只在两边都没给时对称兜底
    local wdp, hdp = physW / sysDpr, physH / sysDpr
    local long = math.max(wdp, hdp) / math.max(1, math.min(wdp, hdp))
    local land = wdp > hdp
    -- 横屏顶部兜底：任何超宽比屏幕在横屏时顶部都没有物理遮挡
    -- （灵动岛/挖孔在左右两侧，Home 条在底部）。系统报的 top 往往是平台自己的浮层
    -- （测试横幅、右上角调试按钮组）占掉的空间，实测可达 55~60pt。
    -- 不夹掉的话整页会空出一大条。这里对所有「横屏 + 超宽比」统一夹到 4pt。
    if land and long >= 1.7 then t = math.min(t, 4) end
    -- iPhone 的特征：横屏时系统给的安全区在 40pt 以上（安卓挖孔一般 24~32dp）。
    -- 小游戏容器里 GetPlatform 不一定返回 iOS，所以也按这个特征认
    local iosLike = isIOS or (land and math.max(l, r) >= 40)
    SAFE_INFO.island = false
    if land and iosLike and long >= 1.9 then
        local side, manual = islandSide(l, r)
        if side == 'L' then l, r = ISLAND_W, EDGE_W else l, r = EDGE_W, ISLAND_W end
        b = math.max(b, 14)
        -- 横屏顶部物理上没有遮挡（灵动岛在左右、底部的 Home 条在下面）。
        -- 但小游戏容器常把「平台自己的浮层」（顶部测试横幅、右上角调试按钮组）
        -- 也计入 safe-area-inset-top，实测能报到 55~60pt，整页就会空出一大条。
        -- 横屏一律夹掉顶部安全区，只保留极小的呼吸空间。
        t = math.min(t, 4)
        -- 底部同理：容器常把平台底栏也算进 bottom（实测报到 30pt）。
        -- 按需求直接贴到屏幕底边，横屏时 Home 指示条是叠加的，不挡内容。
        b = 0
        SAFE_INFO.island, SAFE_INFO.side, SAFE_INFO.manual = true, side, manual
    elseif isMobile and long >= 1.9 then
        if isIOS then -- 竖屏（横屏在上面单独处理）
            if not land then t = math.max(t, 54); b = math.max(b, 30) end
        else
            if land then
                if l < 8 and r < 8 then l, r = 32, 32 -- 系统没告诉在哪边：两边都让
                elseif l >= 8 then l = math.max(l, 32) else r = math.max(r, 32) end
                t = math.min(t, 4) -- 横屏顶部没有遮挡（挖孔在左右）
            else
                t = math.max(t, 32)
            end
        end
    end
    -- 竖着拿手机旋转 90° 绘制：安全区已在上面交换过（物理边 → 画面边）。
    -- dp → 设计像素（手机上 zoom = 1，两者相同）
    env['safe-area-inset-left'] = l / zoom
    env['safe-area-inset-top'] = t / zoom
    env['safe-area-inset-right'] = r / zoom
    env['safe-area-inset-bottom'] = b / zoom
    safeKey = l .. ',' .. t .. ',' .. r .. ',' .. b
    return physW / dpr, physH / dpr, env
end

local function refreshViewport(dt)
    -- 第七次更新（修切屏后画面只剩左半边）：以前每 0.5 秒的安全区检查会顺手更新 physW / physH，
    -- 如果正好在这一帧屏幕尺寸也变了（切回游戏后的第一帧 TimeStep 很大，必定先走这条），
    -- 尺寸变化就被「吞掉」，页面还按切出去时的竖屏宽度排版，右边一大块黑。
    -- 现在：任何路径读到的视口，只要和上次交给页面的不一样（appliedKey 比较）就重新排版；
    -- 并且每帧直接比较物理尺寸 / DPR，尺寸一变立刻重排，不必等 0.5 秒窗口。
    safeCheckT = safeCheckT + (dt or 0)
    local force = forceViewport
    forceViewport = false
    local watching = nowMs < watchUntil
    local rawW, rawH = graphics:GetWidth(), graphics:GetHeight()
    local nowRt = (rawW > 0 and rawH > 0 and rawH > rawW)
    local w, h = nowRt and rawH or rawW, nowRt and rawW or rawH
    local ratio = graphics:GetDPR()
    if not ratio or ratio <= 0 then ratio = 1 end
    local sizeChanged = (w ~= physW or h ~= physH or ratio * zoom ~= dpr or nowRt ~= rt)
    if not (force or watching or sizeChanged or safeCheckT > 0.5) then return end
    safeCheckT = 0
    local vw, vh, env = readViewport()
    local key = string.format('%.2f,%.2f,%.3f,%s', vw, vh, dpr, safeKey)
    if key == appliedKey and not force then return end
    appliedKey = key
    if inputMgr then inputMgr:cancelAll() end
    N.Arena.cancel()
    App.page:setViewport(vw, vh, env)
    App.page:update()
    print('[拉杆军团] 重新适配：' .. math.floor(vw) .. '×' .. math.floor(vh))
end

-- ---------------------------------------------------------------------------
-- NanoVG 资源（上下文 + 字体 + 平铺底纹）
-- 设备丢失后 DeviceReset 会再次调用，重建全部失效句柄。
-- ---------------------------------------------------------------------------
local function buildNVGResources()
    if vg then pcall(nvgDelete, vg) end
    vg = nvgCreate(1)
    -- 真机上资源是按需异步下载的，字体可能在第一次调用时还没落到本地缓存，
    -- nvgCreateFont 会返回 -1。这里绝不能用 assert 中断启动（真机直接闪退），
    -- 而是记录下来，等资源下载完成后由 RetryFonts 再补一次。
    if not vg then
        print("[拉杆军团] NanoVG 上下文创建失败，跳过绘制")
        deviceLost = true
        return
    end
    fontsReady = false
    -- 字体：拉丁字母用 Silkscreen（原版从 Google Fonts 加载），中文回落到思源黑体（与浏览器里的 Noto Sans CJK 同一套字形）
    local latin = nvgCreateFont(vg, "sil", "Fonts/Silkscreen-Regular.ttf")
    local latinBold = nvgCreateFont(vg, "sil-b", "Fonts/Silkscreen-Bold.ttf")
    if latin ~= -1 and latinBold ~= -1 then
        fontsReady = true
        print("[拉杆军团] 像素字体已加载")
    else
        print("[拉杆军团] 像素字体暂不可用（-1），稍后重试")
    end
    local cjk, cjkB = -1, -1
    if cache:Exists("Fonts/NotoSansSC-Regular.ttf") then
        cjk = nvgCreateFont(vg, "cjk", "Fonts/NotoSansSC-Regular.ttf")
    end
    if cache:Exists("Fonts/NotoSansSC-Bold.ttf") then
        cjkB = nvgCreateFont(vg, "cjk-b", "Fonts/NotoSansSC-Bold.ttf")
    end
    local mi = nvgCreateFont(vg, "mi", "Fonts/MiSans-Regular.ttf")
    local miBold = nvgCreateFont(vg, "mi-b", "Fonts/MiSans-Bold.ttf")
    if cjk == -1 then print("[拉杆军团] 中文字体使用 MiSans 后备") end
    if cjk == -1 and mi == -1 then print("[拉杆军团] 中文字体暂不可用（-1），稍后重试") end
    if cjk ~= -1 then nvgAddFallbackFont(vg, "sil", "cjk") end
    if cjkB ~= -1 then nvgAddFallbackFont(vg, "sil-b", "cjk-b") elseif cjk ~= -1 then nvgAddFallbackFont(vg, "sil-b", "cjk") end
    if mi ~= -1 then nvgAddFallbackFont(vg, "sil", "mi") end
    if miBold ~= -1 then nvgAddFallbackFont(vg, "sil-b", "mi-b") elseif mi ~= -1 then nvgAddFallbackFont(vg, "sil-b", "mi") end
    floorImage = nvgCreateImage(vg, "Textures/floor.png", NVG_IMAGE_NEAREST + NVG_IMAGE_REPEATX + NVG_IMAGE_REPEATY)
    -- 旧的纹理句柄已随上下文失效，清空缓存让 textureHook 重新创建
    texCache = {}
    deviceLost = false
end

--- 字体没加载成功时（真机首次启动资源还在异步下载）每秒重试一次，最多 15 次。
--- 加载成功后立刻重绘一帧，避免玩家看到空白文字。
local function retryFonts()
    if fontsReady or deviceLost or not vg then return end
    if nowMs < fontRetryAt then return end
    if fontRetryN >= 15 then return end
    fontRetryN = fontRetryN + 1
    fontRetryAt = nowMs + 1000
    local latin = nvgCreateFont(vg, "sil", "Fonts/Silkscreen-Regular.ttf")
    local latinBold = nvgCreateFont(vg, "sil-b", "Fonts/Silkscreen-Bold.ttf")
    local cjk = nvgCreateFont(vg, "cjk", "Fonts/NotoSansSC-Regular.ttf")
    local cjkB = nvgCreateFont(vg, "cjk-b", "Fonts/NotoSansSC-Bold.ttf")
    local mi = nvgCreateFont(vg, "mi", "Fonts/MiSans-Regular.ttf")
    local miBold = nvgCreateFont(vg, "mi-b", "Fonts/MiSans-Bold.ttf")
    if latin ~= -1 and latinBold ~= -1 then
        if cjk ~= -1 then nvgAddFallbackFont(vg, "sil", "cjk") end
        if cjkB ~= -1 then nvgAddFallbackFont(vg, "sil-b", "cjk-b") elseif cjk ~= -1 then nvgAddFallbackFont(vg, "sil-b", "cjk") end
        if mi ~= -1 then nvgAddFallbackFont(vg, "sil", "mi") end
        if miBold ~= -1 then nvgAddFallbackFont(vg, "sil-b", "mi-b") elseif mi ~= -1 then nvgAddFallbackFont(vg, "sil-b", "mi") end
        fontsReady = true
        if PAGE then PAGE.needs = true end
        print('[拉杆军团] 字体重试成功（第 ' .. fontRetryN .. ' 次）')
    end
end

-- ---------------------------------------------------------------------------
-- 启动
-- ---------------------------------------------------------------------------
--- 事件订阅单独成函数：必须在任何可能失败的资源加载之前调用，
--- 否则一旦前半段抛错（xpcall 捕获后跳过剩余代码），主循环和输入就全断了，
--- 表现就是「界面出来了但点什么都没反应」。
local function subscribeAll()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleRender")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("MouseWheel", "HandleMouseWheel")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("KeyUp", "HandleKeyUp")
    SubscribeToEvent("InputFocus", "HandleAudioFocus")
    SubscribeToEvent("AppWillEnterBackground", "HandleAudioBackground")
    SubscribeToEvent("AppDidEnterBackground", "HandleAudioBackground")
    -- 引擎在事件表里同时列了 AppWillEnterForeground 和拼写异常的 AppDidEnterForebackground，
    -- 真机只派发前者；只订阅后者会导致「回前台」永远收不到，foreground 卡在 false，
    -- 音效被 playSound 的前台判断永久拦掉（表现为看完广告后彻底没声音）。两个都订阅，重复回调无副作用。
    SubscribeToEvent("AppWillEnterForeground", "HandleAudioForeground")
    SubscribeToEvent("AppDidEnterForebackground", "HandleAudioForeground")
    pcall(SubscribeToEvent, "InputFocus", "HandleFocus")
    pcall(SubscribeToEvent, "ScreenMode", "HandleFocus")
end

function StartInner()
    _G.CRASH_STAGE = 'start'
    graphics.windowTitle = "拉杆军团"
    print("[拉杆军团] 启动导入版 r9-layout（含分段避让 + 视口对齐）")
    local platform = ""
    if GetPlatform then
        local ok, v = pcall(GetPlatform)
        if ok and v then platform = tostring(v) end
    end
    local pl = string.lower(platform)
    isIOS = pl:find("ios", 1, true) ~= nil or pl:find("iphone", 1, true) ~= nil or pl:find("ipad", 1, true) ~= nil
    isMobile = isIOS or pl:find("android", 1, true) ~= nil or pl:find("harmony", 1, true) ~= nil or pl:find("ohos", 1, true) ~= nil
    -- 平台接口在小游戏容器里不一定都存在：一律 pcall 包住，缺了就走默认值，
    -- 绝不能让「可选接口不存在」把启动打断。
    local native = ''
    if GetNativePlatform then
        local ok, v = pcall(GetNativePlatform)
        if ok and v then native = tostring(v) end
    end
    local nativeMobile = native == 'Android' or native == 'iOS' or native == 'HarmonyOS'
    isMobile = isMobile or nativeMobile
    if input then input.mouseVisible = true end

    _G.CRASH_STAGE = 'nvg'; buildNVGResources()

    _G.CRASH_STAGE = 'audio'; initAudio()
    Music.enabled = true
    _G.CRASH_STAGE = 'music'; Music.init(scene_)
    N.Sound.backend = playSound
    N.Sound.now = function() return nowMs end
    N.Sound.suspendBackend = function()
        for _, source in ipairs(soundPool) do source:Stop() end
    end
    N.Sound.resumeBackend = function()
        if not N.Sound.on then N.Sound.suspendBackend() end
        AudioRecovery.resume()
    end
    _G.CRASH_STAGE = 'recovery'; AudioRecovery.init()
    N.Ads.onBegin = AudioRecovery.begin
    N.Ads.onFinish = AudioRecovery.finish
    -- 原版浏览器要等第一次用户手势才能建 AudioContext（Sound.init 只在点击/触摸里调），
    -- 移植到引擎后音频子系统启动即可用，没有这个限制。若不在这里置 ready，
    -- Music.wanted() 会一直返回 nil —— 玩家不点任何东西时主页/战斗 BGM 全程静音。
    _G.CRASH_STAGE = 'sound'; N.Sound.init()

    local validationMode = false
    if GetArguments then
        local ok, args = pcall(GetArguments)
        if ok and type(args) == 'table' then
            for _, argument in ipairs(args) do
                if tostring(argument):match('^%-validate%-test=') then validationMode = true; break end
            end
        end
    end
    if validationMode then
        N.store.persist = function() end
    else
        loadStore()
        N.store.persist = persistStore
    end

    N.Sound.on = N.store.get('lever-legion-sound') ~= '0'

    _G.CRASH_STAGE = 'viewport'; local vw, vh, env = readViewport()
    _G.CRASH_STAGE = 'boot'; App.boot({ vw = vw, vh = vh, envVars = env, nowMs = 0 })
    App.page:update()
    -- 启动后的前 3 秒每帧核对视口：小游戏容器常先报竖屏尺寸，转屏后过几帧才变成横屏
    watchUntil = nowMs + 3000
    print("[拉杆军团] 页面就绪：" .. math.floor(vw) .. "×" .. math.floor(vh) .. "，DPR=" .. dpr)

    -- 云存档：先拉取云端进度合并到本地，之后存档有变化就增量推送
    if not validationMode then
        local Cloud = N.Cloud
        Cloud.active, Cloud.ready, Cloud.fetching, Cloud.pushing = true, false, false, false
        Cloud.onSynced = function()
            N.buildSave()
            N.Sound.on = N.store.get('lever-legion-sound') ~= '0'
            N.UI.cache:clear()
            N.UI.syncSound(false)
            N.UI.update()
            local ui = N.UI --[[@as {els: table<string, any>}]]
            if not ui.els.home:isHidden() then N.UI.showHome() else N.UI.homeForge() end
        end
        Cloud.sync()
    else
        N.Cloud.active = false
    end

    -- 页面背景：floor 平铺图（48px 一格，像素风最近邻）
    App.host.drawPattern = function(ctx, src, x, y, w, h, ox, oy, tw, th, pdpr, colorFn)
        if floorImage == -1 then return end
        -- 同 textureHook：非法宽高会产生非法几何，跳过这一帧的底纹。
        if not (w and h and w > 0 and h > 0 and tw and th and tw > 0 and th > 0) then return end
        nvgBeginPath(ctx)
        nvgRect(ctx, x, y, w, h)
        nvgFillPaint(ctx, nvgImagePattern(ctx, ox, oy, tw, th, 0, floorImage, 1))
        nvgFill(ctx)
    end

    -- 战场背景是固定的像素图：直接用预先导出的纹理画（比逐块画快得多）
    local PX = require("game.pixel")
    PX.textureHook = function(ctx, path, x, y, w, h, alpha)
        -- 布局求解失败时 w/h 可能为 0 或负数；把这种矩形交给 NanoVG 会产出非法几何，
        -- WebGPU 侧表现为 device lost。这里直接跳过这一块（少画一块好过丢设备）。
        if not (w and h and w > 0 and h > 0) then return true end
        local img = texCache[path]
        if img == nil then
            img = nvgCreateImage(vg, path, NVG_IMAGE_NEAREST)
            texCache[path] = img
        end
        if not img or img == -1 then return false end
        nvgBeginPath(ctx)
        nvgRect(ctx, x, y, w, h)
        nvgFillPaint(ctx, nvgImagePattern(ctx, x, y, w, h, 0, img, alpha or 1))
        nvgFill(ctx)
        return true
    end

    inputMgr = INPUT.new(App.page, {
        now = function() return nowMs end,
        arenaDown = function(x, y, isTouch) return N.Arena.down(x, y, isTouch) end,
        arenaMove = function(x, y) N.Arena.move(x, y) end,
        arenaUp = function(x, y) N.Arena.up(x, y) end,
        arenaCancel = function() N.Arena.cancel() end,
    })

    N.UI.syncSound(false)

    -- 菜单里「灵动岛 在左/在右」点完调这个：下一帧重新读安全区并排版
    SAFE_INFO.refresh = function() forceViewport = true; watchUntil = nowMs + 3000 end
end

--- 启动入口：任何一步失败都只记录并继续，绝不让异常冒泡导致真机闪退。
--- 真机上「缺一个可选接口 / 资源还没下载完」不该是致命错误。
function Start()
    -- 关键顺序：先把主循环与输入事件订阅上，再执行可能失败的资源加载。
    -- 以前订阅放在 StartInner 末尾，一旦前半段抛错（xpcall 捕获后跳过剩余代码），
    -- 事件全没订阅上 → 界面显示出来了但点什么都没反应。
    local okSub = pcall(subscribeAll)
    if not okSub then print('[拉杆军团] 事件订阅失败，稍后仍会重试') end

    local ok, err = xpcall(StartInner, debug.traceback)
    if not ok then
        local msg = tostring(err)
        print('[拉杆军团] 启动失败（已捕获，尝试继续）：' .. msg)
        -- 写进崩溃痕迹，真机上拿不到日志时靠这个定位
        pcall(function()
            local f = File('crash_trace.txt', FILE_WRITE)
            if f and f:IsOpen() then
                f:WriteString('start_error stage=' .. tostring(_G.CRASH_STAGE) .. ' ' .. msg)
                f:Close()
            end
        end)
        -- 再补一次订阅，确保主循环和输入一定活着
        pcall(subscribeAll)
    end
end

function Stop()

    audioGeneration = audioGeneration + 1
    AudioRecovery.stop()
    N.Ads.onBegin, N.Ads.onFinish = nil, nil
    N.Sound.resumeBackend, N.Sound.suspendBackend = nil, nil
    N.Ads.cancel()
    N.Cloud.stop()
    Music.stop()
    UnsubscribeFromAllEvents()
    if inputMgr then inputMgr:cancelAll() end
    if scene_ then scene_:Dispose(); scene_ = nil end
    soundPool, sounds = {}, {}
    texCache, deviceLost = {}, false
    if vg then nvgDelete(vg); vg = nil end
end

-- ---------------------------------------------------------------------------
-- 每帧
-- ---------------------------------------------------------------------------
-- 看门狗：某帧卡住时，下一帧的 TimeStep 会异常大。打印当时的游戏状态帮定位。
local watchdogArmed = true
local function watchdog(dt)
    if dt < 1.5 then return end
    if not watchdogArmed then return end
    watchdogArmed = false
    local g = N.G --[[@as table<string, any>?]]
    local parts = { '[拉杆军团] 看门狗：单帧 ' .. string.format('%.2f', dt) .. 's' }
    if g then
        parts[#parts + 1] = 'phase=' .. tostring(g.phase)
        parts[#parts + 1] = 'ch=' .. tostring(g.ch) .. ' wave=' .. tostring(g.wave) .. '/' .. tostring(g.maxWave)
        if g.battle then
            parts[#parts + 1] = 'ents=' .. tostring(g.battle.ents and g.battle.ents.n)
            parts[#parts + 1] = 'projs=' .. tostring(g.battle.projs and g.battle.projs.n)
            parts[#parts + 1] = 'fields=' .. tostring(g.battle.fields and g.battle.fields.n)
        end
    end
    parts[#parts + 1] = 'anims=' .. tostring(N.FX and N.FX.anims and #N.FX.anims)
    parts[#parts + 1] = 'parts=' .. tostring(N.FX and N.FX.parts and N.FX.parts.n)
    parts[#parts + 1] = 'floats=' .. tostring(N.FX and N.FX.floats and N.FX.floats.n)
    print(table.concat(parts, ' '))
end
-- 卡死恢复后重新武装（避免刷屏）
local function rearmWatchdog(dt) if dt < 0.5 then watchdogArmed = true end end

-- 崩溃痕迹文件：日志常拿不到，就把"当前进行到哪一步"直接写进文件。
-- 崩溃（死循环/原生崩溃）时文件停在最后一次写入的内容，据此定位卡死位置。
local TRACE_FILE = "crash_trace.txt"
local traceTick = 0
local function writeTrace(extra)
    local f = File(TRACE_FILE, FILE_WRITE)
    if f:IsOpen() then
        local g = N.G --[[@as table<string, any>?]]
        local s = 'stage=' .. tostring(_G.CRASH_STAGE)
            .. ' nowMs=' .. tostring(math.floor(nowMs))
            .. ' phase=' .. tostring(g and g.phase)
            .. ' ch=' .. tostring(g and g.ch) .. ' wave=' .. tostring(g and g.wave)
        if g and g.battle then
            local b = g.battle
            s = s .. ' ents=' .. tostring(b.ents and b.ents.n)
                .. ' projs=' .. tostring(b.projs and b.projs.n)
                .. ' fields=' .. tostring(b.fields and b.fields.n)
        end
        s = s .. ' anims=' .. tostring(N.FX and N.FX.anims and #N.FX.anims)
            .. ' parts=' .. tostring(N.FX and N.FX.parts and N.FX.parts.n)
        if extra then s = s .. ' ' .. extra end
        f:WriteString(s)
        f:Close()
    end
end

-- Lua 错误捕获：脚本报错（nil 索引、类型错等）不再静默崩溃/中断，记录一次后继续跑。
-- 同一条错误只打一次，避免每帧刷屏。
local lastErr = nil
local errCount = 0
local lastSnapshot = 0
local function guard(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        errCount = errCount + 1
        local msg = tostring(err)
        if msg ~= lastErr then
            lastErr = msg
            print('[拉杆军团] 脚本错误（已捕获，游戏继续）：' .. what .. ' → ' .. msg)
            writeTrace('ERR=' .. what .. ':' .. msg)
        end
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- GPU 设备丢失 / 恢复（WebGPU device lost、驱动重置、切显卡等）
-- 丢失后 vg 里的字体、纹理句柄全部失效：必须停止绘制，等设备恢复后重建。
-- 用 graphics:IsDeviceLost() 轮询而不是订阅事件——丢失时事件不保证投递，
-- 轮询每帧一次开销可忽略，且丢帧也不会漏掉恢复时机。
-- ---------------------------------------------------------------------------
function CheckDevice()
    local lost = false
    local ok = pcall(function() lost = graphics:IsDeviceLost() end)
    if not ok then return end
    if lost then
        if not deviceLost then
            deviceLost = true
            print("[拉杆军团] GPU 设备丢失，暂停绘制，等待设备恢复")
        end
        return
    end
    if not deviceLost then return end
    -- 设备已恢复：旧的字体 / 纹理句柄全部失效，重建整个 NanoVG 上下文
    print("[拉杆军团] GPU 设备已恢复，重建 NanoVG 资源")
    local ok2, err = pcall(buildNVGResources)
    if not ok2 then
        print("[拉杆军团] NanoVG 资源重建失败，稍后重试：" .. tostring(err))
        deviceLost = true -- 保持暂停，下一帧再试
        return
    end
    local vw, vh, env = readViewport()
    appliedKey = string.format('%.2f,%.2f,%.3f,%s', vw, vh, dpr, safeKey)
    App.page:setViewport(vw, vh, env)
    App.page:update()
    App.page.needs = true
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    _G.CRASH_STAGE = 'update'
    watchdog(dt)
    rearmWatchdog(dt)
    nowMs = nowMs + dt * 1000
    _G.CRASH_STAGE = 'device'; guard('device', CheckDevice)
    _G.CRASH_STAGE = 'fonts'; guard('fonts', retryFonts)
    _G.CRASH_STAGE = 'refreshViewport'; guard('refreshViewport', refreshViewport, dt)
    _G.CRASH_STAGE = 'input'
    -- 输入管理器兜底：若 Start 阶段抛错没来得及创建，这里补建，避免「点什么都没反应」
    if not inputMgr and App.page then
        local okI, mgr = pcall(INPUT.new, App.page, {
            now = function() return nowMs end,
            arenaDown = function(x, y, isTouch) return N.Arena.down(x, y, isTouch) end,
            arenaMove = function(x, y) N.Arena.move(x, y) end,
            arenaUp = function(x, y) N.Arena.up(x, y) end,
            arenaCancel = function() N.Arena.cancel() end,
        })
        if okI then inputMgr = mgr; print('[拉杆军团] 输入管理器已补建') end
    end
    if inputMgr then guard('input', function() inputMgr:update() end) end
    _G.CRASH_STAGE = 'App.frame'; guard('App.frame', App.frame, nowMs)
    _G.CRASH_STAGE = 'Cloud'; guard('Cloud', function() N.Cloud.tick(nowMs) end)
    _G.CRASH_STAGE = 'Audio'; guard('Audio', function() AudioRecovery.update(dt) end)
    _G.CRASH_STAGE = 'Music'; guard('Music', function() Music.update(dt) end)
    _G.CRASH_STAGE = 'idle'
    -- 每约 1 秒写一次痕迹（30 帧）；崩溃时文件停在最后一步
    traceTick = traceTick + 1
    if traceTick >= 30 then traceTick = 0; writeTrace() end
    -- 战斗状态快照：每 5 秒一条
    if nowMs - (lastSnapshot or 0) > 5000 then
        lastSnapshot = nowMs
        local g = N.G --[[@as table<string, any>?]]
        if g and g.battle and not g.battle.over then
            local b = g.battle
            print('[拉杆军团] 战斗快照：ch=' .. tostring(g.ch) .. ' wave=' .. tostring(g.wave)
                .. ' ents=' .. tostring(b.ents and b.ents.n) .. ' projs=' .. tostring(b.projs and b.projs.n)
                .. ' fields=' .. tostring(b.fields and b.fields.n) .. ' anims=' .. tostring(N.FX and N.FX.anims and #N.FX.anims)
                .. ' parts=' .. tostring(N.FX and N.FX.parts and N.FX.parts.n))
        end
    end
end

---@param eventType string
---@param eventData InputFocusEventData
function HandleAudioFocus(eventType, eventData)
    AudioRecovery.focus(eventData:GetBool('Focus') and not eventData:GetBool('Minimized'))
end

--- 第七次更新：切回前台 / 屏幕模式变化后 3 秒内每帧核对视口（配合 refreshViewport 的 appliedKey 比较）
function HandleFocus()
    forceViewport = true
    watchUntil = nowMs + 3000
end

function HandleAudioBackground()
    AudioRecovery.focus(false)
end

function HandleAudioForeground()
    AudioRecovery.focus(true)
end

--- 叠加滚动条：滚动时出现，停下 1 秒后淡出（移动端浏览器的样式）
local function drawScrollbars()
    -- 输入管理器可能还没建好（Start 前半段抛错时由 Update 兜底补建）：
    -- 这里不判空的话，每帧都会抛一次错、写一条日志，真机上表现就是持续掉帧 + 日志刷屏。
    if not inputMgr then return end
    local now = nowMs
    for el, t in pairs(inputMgr:recentScrolls()) do
        local b = el.box
        local age = now - t
        if not b or not b.ax or age > 1300 then
            inputMgr.lastScroll[el] = nil
        else
            local alpha = age < 1000 and 1 or (1 - (age - 1000) / 300)
            local range = PAGE_M.scrollRange(b)
            if range > 0 then
                local x0, y0 = b.ax + b.bl, b.ay + b.bt
                local w, hgt = b.w - b.bl - b.br, b.h - b.bt - b.bb
                local thumbH = math.max(24, hgt * hgt / (hgt + range))
                local ty = y0 + (hgt - thumbH) * ((el.scrollTop or 0) / range)
                nvgBeginPath(vg)
                nvgRect(vg, x0 + w - 6, ty + 2, 4, thumbH - 4)
                nvgFillColor(vg, nvgRGBA(140, 140, 140, math.floor(150 * alpha)))
                nvgFill(vg)
            end
        end
    end
end

function HandleRender(eventType, eventData)
    -- 设备丢失期间：句柄全部失效，跳过绘制，等 DeviceReset 重建后再画。
    -- 否则每帧都会对已失效的上下文提交命令，错误刷屏且可能拖垮恢复。
    if not vg or deviceLost then return end
    -- 画布尺寸必须和页面排版用的视口一致，否则会出现「内容只占左半边、右边全黑」。
    -- 物理尺寸一变就当场重排，保证两者同帧同步（SetMode 被禁用，只能靠轮询发现）。
    local rawW, rawH = graphics:GetWidth(), graphics:GetHeight()
    local nowRt = (rawW > 0 and rawH > 0 and rawH > rawW)
    local pw, ph = nowRt and rawH or rawW, nowRt and rawW or rawH
    local sysDpr = graphics:GetDPR()
    if not sysDpr or sysDpr <= 0 then sysDpr = 1 end
    -- 期望视口（与 readViewport 同一套算法）。页面视口若和它对不上，
    -- 说明排版尺寸落后于真实屏幕（例如被别处写小、或容器报过一次错误尺寸），
    -- 这时画布按页面尺寸画就会「内容只占左半边、右边全黑」。
    local wantDpr = sysDpr * uiZoom(pw / sysDpr, ph / sysDpr)
    local wantVw, wantVh = pw / wantDpr, ph / wantDpr
    local curVw, curVh = App.page.env.vw, App.page.env.vh
    local mismatch = math.abs(curVw - wantVw) > 1.5 or math.abs(curVh - wantVh) > 1.5
    if pw ~= physW or ph ~= physH or nowRt ~= rt or mismatch then
        local vw, vh, env = readViewport()
        appliedKey = string.format('%.2f,%.2f,%.3f,%s', vw, vh, dpr, safeKey)
        if inputMgr then inputMgr:cancelAll() end
        N.Arena.cancel()
        App.page:setViewport(vw, vh, env)
        App.page:update()
        print('[拉杆军团] 渲染时对齐视口：' .. math.floor(vw) .. '×' .. math.floor(vh)
            .. '（物理 ' .. pw .. '×' .. ph .. (rt and '，旋转 90°' or '') .. '）')
    end
    -- 尺寸为 0（最小化 / 后台）时 NanoVG 不接受，直接跳过
    if not (physW > 0 and physH > 0) or not (dpr > 0) then return end
    -- 下面 nvgBeginFrame 用的是页面视口（env.vw/vh），不是物理尺寸。
    -- 容器转屏 / 切后台回来的瞬间，env 里可能残留 0 或负数（排版求解失败时也会写出非法值），
    -- 把非法的宽高交给 NanoVG 会让 WebGPU 直接丢设备。这里必须单独校验一次。
    local envVw, envVh = App.page.env.vw, App.page.env.vh
    if not (envVw and envVh and envVw > 0 and envVh > 0) then return end
    -- 用页面视口作画布尺寸（与排版严格一致，不会半屏）。
    -- 竖着拿手机时把画布转 90° 再画，最终落到的物理区域与真实表面完全一致——
    -- 这正是「截屏只有一半」的根因：以前只把宽高对调，画布按交换后的尺寸铺在了未旋转的表面上。
    if rt then
        nvgBeginFrame(vg, App.page.env.vh, App.page.env.vw, dpr)
        nvgSave(vg)
        nvgTranslate(vg, App.page.env.vh, 0)
        nvgRotate(vg, math.pi / 2)
        guard('paint', App.paint, vg, dpr)
        guard('scrollbars', drawScrollbars)
        nvgRestore(vg)
    else
        nvgBeginFrame(vg, App.page.env.vw, App.page.env.vh, dpr)
        guard('paint', App.paint, vg, dpr)
        guard('scrollbars', drawScrollbars)
    end
    nvgEndFrame(vg)
end

-- ---------------------------------------------------------------------------
-- 输入（物理像素 → CSS 像素）
-- ---------------------------------------------------------------------------
local function xy(eventData)
    local x, y = eventData["X"]:GetInt() / dpr, eventData["Y"]:GetInt() / dpr
    -- 旋转 90° 绘制时，触摸坐标要反向旋转回页面坐标系（与 HandleRender 的变换互逆）
    if rt then x, y = y, physRawW / dpr - x end
    return x, y
end

function HandleMouseDown(eventType, eventData)
    if isMobile or not inputMgr:mouseAllowed() then return end
    if eventData["Button"]:GetInt() ~= MOUSEB_LEFT then return end
    local x, y = xy(eventData)
    inputMgr:pointerDown('mouse', x, y, false)
end

function HandleMouseUp(eventType, eventData)
    if isMobile or not inputMgr:mouseAllowed() then return end
    if eventData["Button"]:GetInt() ~= MOUSEB_LEFT then return end
    local x, y = xy(eventData)
    inputMgr:pointerUp('mouse', x, y, false)
end

function HandleMouseMove(eventType, eventData)
    if isMobile or not inputMgr:mouseAllowed() then return end
    local x, y = xy(eventData)
    inputMgr:pointerMove('mouse', x, y, false)
end

function HandleMouseWheel(eventType, eventData)
    if isMobile then return end
    local wheel = eventData["Wheel"]:GetInt()
    local mp = input:GetMousePosition()
    inputMgr:wheel(mp.x / dpr, mp.y / dpr, -wheel * 100)
end

function HandleTouchBegin(eventType, eventData)
    local x, y = xy(eventData)
    inputMgr:pointerDown('t' .. eventData["TouchID"]:GetInt(), x, y, true)
end

function HandleTouchMove(eventType, eventData)
    local x, y = xy(eventData)
    inputMgr:pointerMove('t' .. eventData["TouchID"]:GetInt(), x, y, true)
end

function HandleTouchEnd(eventType, eventData)
    local x, y = xy(eventData)
    inputMgr:pointerUp('t' .. eventData["TouchID"]:GetInt(), x, y, true)
end

local KEYCODE = nil
local function codeOf(key)
    if not KEYCODE then
        KEYCODE = {}
        if KEY_SPACE then KEYCODE[KEY_SPACE] = 'Space' end
        if KEY_RETURN then KEYCODE[KEY_RETURN] = 'Enter' end
        if KEY_RETURN2 then KEYCODE[KEY_RETURN2] = 'Enter' end
        if KEY_KP_ENTER then KEYCODE[KEY_KP_ENTER] = 'Enter' end
        if KEY_TAB then KEYCODE[KEY_TAB] = 'Tab' end
        if KEY_ESCAPE then KEYCODE[KEY_ESCAPE] = 'Escape' end
    end
    return KEYCODE[key] or ('Key' .. tostring(key))
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    local quals = eventData["Qualifiers"] and eventData["Qualifiers"]:GetInt() or 0
    local rep = eventData["Repeat"] and eventData["Repeat"]:GetBool() or false
    local shift = QUAL_SHIFT and (quals & QUAL_SHIFT) ~= 0 or false
    inputMgr:keyDown(codeOf(key), shift, rep)
end

function HandleKeyUp(eventType, eventData)
    inputMgr:keyUp(codeOf(eventData["Key"]:GetInt()))
end
