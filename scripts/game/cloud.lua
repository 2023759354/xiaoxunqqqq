-- 云存档：先拉取合并再上传；失败保留本地进度并重试，不覆盖尚未读取的云端。
-- 普通纪录取最大值，通关标记取位或；军魂和强化沿用原有较高值策略。
-- 此移植模块通过共享 _ENV 读写游戏符号，跨模块符号在运行时由 game.core 装配。
---@diagnostic disable: undefined-global
local _ENV = require("game.env")
local js = require("game.compat")
local S = js.S
local floor = math.floor

Cloud = { ready = false, dirty = false, pushedAt = -1e9, active = true,
    fetching = false, pushing = false, retryAt = 0, now = 0, revision = 0, epoch = 0 }
local PUSH_INTERVAL, RETRY_INTERVAL = 3000, 15000
local LOCAL_FIRST = { 'reel-legion-squad', 'lever-legion-sound', 'reel-legion-tut' }

local function toNum(v)
    local n = tonumber(v) or (v == true and 1 or 0)
    if n ~= n or n == math.huge or n == -math.huge then return 0 end
    return n
end

local function allKeys()
    local seen, keys = {}, {}
    local function add(k)
        if not seen[k] then seen[k] = true; keys[#keys + 1] = k end
    end
    add(META_KEY)
    for _, k in ipairs(LOCAL_FIRST) do add(k) end
    CHAPTERS:forEach(function(C, c)
        add(C.key .. '-cleared')
        add(C.key .. '-unlock')
        C.diffs:forEach(function(_, d) add(bestKey(c, d)) end)
    end)
    return keys
end

local function mergeMeta(raw)
    if type(raw) ~= 'string' then return end
    local ok, value = pcall(jsonDecode, raw)
    if not ok or type(value) ~= 'table' or js.isArr(value) then return end
    -- 必须在取最大值之前迁移，防止旧云档把已退款清零的集点等级重新恢复。
    local m, refund = normalizeMeta(value)
    local changed = false
    if m.s > META.s then
        META.s = m.s
        changed = true
        if refund > 0 then
            META.refund = math.max(META.refund or 0, refund)
            META.refundKind = 'cheap3'
        end
    end
    UPG:forEach(function(u)
        if m.l[u.id] > (META.l[u.id] or 0) then
            META.l[u.id] = m.l[u.id]
            if u.id == 'cheap' then META.cheapSpent = m.cheapSpent end
            changed = true
        end
    end)
    if changed then saveMeta() end
end

local function mergeNumeric(key, remote, bitmask)
    if remote == nil then return end
    local current, incoming = math.max(0, floor(toNum(store.get(key)))), math.max(0, floor(toNum(remote)))
    local merged = bitmask and (current | incoming) or math.max(current, incoming)
    if merged ~= current then store.set(key, S(merged)) end
end

function Cloud.merge(values)
    if type(values) ~= 'table' then return end
    mergeMeta(values[META_KEY])
    CHAPTERS:forEach(function(C, c)
        mergeNumeric(C.key .. '-cleared', values[C.key .. '-cleared'], true)
        mergeNumeric(C.key .. '-unlock', values[C.key .. '-unlock'])
        C.diffs:forEach(function(_, d)
            local key = bestKey(c, d)
            mergeNumeric(key, values[key])
        end)
    end)
    for _, key in ipairs(LOCAL_FIRST) do
        if store.get(key) == nil and values[key] ~= nil then store.set(key, values[key]) end
    end
end

function Cloud.sync()
    if Cloud.fetching or not Cloud.active then return end
    local api = rawget(_G, 'clientCloud')
    if not api or type(api.BatchGet) ~= 'function' then
        if Cloud.retryAt == 0 then print('[拉杆军团] 云存档暂不可用，保留本地进度') end
        Cloud.retryAt = Cloud.now + RETRY_INTERVAL
        return
    end
    Cloud.fetching = true
    local epoch = Cloud.epoch
    local finished = false
    local function failed(code, reason)
        if finished or not Cloud.active or epoch ~= Cloud.epoch then return end
        finished = true
        Cloud.fetching = false
        Cloud.ready = false
        Cloud.retryAt = Cloud.now + RETRY_INTERVAL
        print('[拉杆军团] 云存档读取失败，暂不上传：' .. tostring(code) .. ' ' .. tostring(reason))
    end
    local ok, err = pcall(function()
        local builder = api:BatchGet()
        for _, key in ipairs(allKeys()) do builder:Key(key) end
        builder:Fetch({
            ok = function(values)
                if finished or not Cloud.active or epoch ~= Cloud.epoch then return end
                finished = true
                Cloud.fetching = false
                Cloud.merge(values)
                Cloud.ready = true
                Cloud.markDirty()
                Cloud.pushedAt = -1e9
                print('[拉杆军团] 云存档读取并合并完成')
                if Cloud.onSynced then Cloud.onSynced() end
            end,
            error = failed,
            timeout = function() failed('timeout', '请求超时') end,
        })
    end)
    if not ok then failed('exception', err) end
end

function Cloud.push()
    if not Cloud.active or not Cloud.ready or Cloud.pushing then return end
    local api = rawget(_G, 'clientCloud')
    if not api or type(api.BatchSet) ~= 'function' then return end
    local revision, epoch = Cloud.revision, Cloud.epoch
    local finished = false
    Cloud.pushing = true
    local function failed(code, reason)
        if finished or not Cloud.active or epoch ~= Cloud.epoch then return end
        finished = true
        Cloud.pushing = false
        Cloud.dirty = true
        print('[拉杆军团] 云存档上传失败，将重试：' .. tostring(code) .. ' ' .. tostring(reason))
    end
    local ok, err = pcall(function()
        local builder, count = api:BatchSet(), 0
        for _, key in ipairs(allKeys()) do
            local value = store.get(key)
            if value ~= nil then builder:Set(key, tostring(value)); count = count + 1 end
        end
        if count == 0 then Cloud.pushing = false; return end
        builder:Save('拉杆军团云存档', {
            ok = function()
                if finished or not Cloud.active or epoch ~= Cloud.epoch then return end
                finished = true
                Cloud.pushing = false
                Cloud.dirty = Cloud.revision ~= revision
                print('[拉杆军团] 云存档上传成功：' .. S(count) .. ' 项')
            end,
            error = failed,
            timeout = function() failed('timeout', '请求超时') end,
        })
    end)
    if not ok then failed('exception', err) end
end

function Cloud.markDirty()
    Cloud.dirty = true
    Cloud.revision = Cloud.revision + 1
end

function Cloud.tick(nowMs)
    if not Cloud.active then return end
    Cloud.now = nowMs
    if not Cloud.ready then
        if not Cloud.fetching and nowMs >= Cloud.retryAt then Cloud.sync() end
        return
    end
    if Cloud.dirty and not Cloud.pushing and nowMs - Cloud.pushedAt >= PUSH_INTERVAL then
        Cloud.pushedAt = nowMs
        Cloud.push()
    end
end

function Cloud.stop()
    Cloud.active = false
    Cloud.epoch = Cloud.epoch + 1
    Cloud.fetching, Cloud.pushing = false, false
    Cloud.onSynced = nil
end

return true
