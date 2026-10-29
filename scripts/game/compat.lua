-- ============================================================================
-- JS 语义兼容层：让原版逻辑可以逐行移植，行为保持一致
--  * A(...)  ：下标从 0 开始的数组（#a 返回长度），方法与 JS Array 同名同义
--  * T(v)    ：JS 真值判断（0、""、nil、false、NaN 都为假）
--  * S(v)    ：JS 的 String(number)（整数不带 .0，小数取最短表示）
--  * 其余：Math.round / toFixed / 稳定排序 等与 JS 完全一致的实现
-- ============================================================================

local M = {}

local floor, sqrt = math.floor, math.sqrt
local select, type, tostring = select, type, tostring

-- ---------------------------------------------------------------------------
-- 随机数：统一出口，方便替换（测试时用固定种子对拍）
-- ---------------------------------------------------------------------------
M.random = math.random

function M.rand(a, b) return a + M.random() * (b - a) end

-- ---------------------------------------------------------------------------
-- 数字 → 字符串（JS 语义）
-- ---------------------------------------------------------------------------
local function numStr(v)
    if v ~= v then return "NaN" end
    if v == math.huge then return "Infinity" end
    if v == -math.huge then return "-Infinity" end
    if math.type(v) == "integer" then return tostring(v) end
    if v == floor(v) and v > -1e21 and v < 1e21 then
        return string.format("%d", v)
    end
    for p = 15, 17 do
        local s = string.format("%." .. p .. "g", v)
        if tonumber(s) == v then
            -- 去掉多余的指数形式（本游戏不会出现极大/极小值）
            return s
        end
    end
    return string.format("%.17g", v)
end
M.numStr = numStr

--- JS 的 String(v) / 模板字符串插值
function M.S(v)
    local t = type(v)
    if t == "number" then return numStr(v) end
    if t == "nil" then return "undefined" end
    if t == "boolean" then return v and "true" or "false" end
    return tostring(v)
end

--- JS 真值
function M.T(v)
    if v == nil or v == false or v == 0 or v == "" then return false end
    if v ~= v then return false end
    return true
end

--- JS 的 a || b（a 为假值时取 b）
function M.OR(a, b)
    if M.T(a) then return a end
    return b
end

-- ---------------------------------------------------------------------------
-- Math
-- ---------------------------------------------------------------------------
-- 特效参数包含小数，显式保留 number 类型，避免按首个整数实参推断。
---@param a number
---@param b number
---@return number
function M.max(a, b) return math.max(a, b) end

function M.round(x) return floor(x + 0.5) end
function M.clamp(v, a, b) if v < a then v = a end if v > b then v = b end return v end
-- 与 V8 的 Math.hypot 完全一致（先按最大值缩放，再做 Kahan 求和），结果逐位相同
function M.hypot(x, y)
    if x < 0 then x = -x end
    if y < 0 then y = -y end
    local m = x > y and x or y
    if m == 0 then return 0 end
    if m == math.huge then return math.huge end
    local sum, comp = 0, 0
    local n = x / m
    local summand = n * n - comp
    local pre = sum + summand
    comp = (pre - sum) - summand
    sum = pre
    n = y / m
    summand = n * n - comp
    pre = sum + summand
    sum = pre
    return sqrt(sum) * m
end
function M.sign(x) if x > 0 then return 1 elseif x < 0 then return -1 end return 0 end
function M.trunc(x) if x >= 0 then return floor(x) end return -floor(-x) end
--- JS 的 a % b（结果符号随被除数）
function M.mod(a, b) return math.fmod(a, b) end

--- JS 的 Number.prototype.toFixed：按精确十进制展开、四舍五入（.5 进位）
---@param x number
---@param d integer
---@return string
function M.toFixed(x, d)
    local neg = x < 0
    if neg then x = -x end
    local s = string.format("%.30f", x)
    local ip, fp = s:match("^(%d+)%.(%d+)$")
    assert(ip and fp, "toFixed 需要可展开的有限数字")
    local digits = ip .. fp:sub(1, d)
    local nextDigit = tonumber(fp:sub(d + 1, d + 1)) or 0
    if nextDigit >= 5 then
        -- 十进制字符串进位
        local arr = {}
        for i = 1, #digits do arr[i] = digits:byte(i) - 48 end
        local i = #arr
        while i >= 1 do
            if arr[i] == 9 then arr[i] = 0; i = i - 1
            else arr[i] = arr[i] + 1; break end
        end
        if i < 1 then table.insert(arr, 1, 1) end
        for k = 1, #arr do arr[k] = string.char(arr[k] + 48) end
        digits = table.concat(arr)
    end
    local il = #digits - d
    local out = digits:sub(1, il)
    if d > 0 then out = out .. "." .. digits:sub(il + 1) end
    if neg and tonumber(out) ~= 0 then out = "-" .. out end
    return out
end

function M.rep(s, n) if n <= 0 then return "" end return string.rep(s, n) end

-- ---------------------------------------------------------------------------
-- 数组（0 起始，#a = 长度）
-- ---------------------------------------------------------------------------
local Arr = {}
Arr.__index = Arr
Arr.__len = function(a) return a.n end
M.Arr = Arr

local function newArr()
    return setmetatable({ n = 0 }, Arr)
end
M.newArr = newArr

--- A(v1, v2, ...) —— 支持 nil 元素；方法与数字键由运行时元表提供。
---@return table<any, any>
function M.A(...)
    local n = select("#", ...)
    local a = setmetatable({ n = n }, Arr)
    for i = 1, n do a[i - 1] = (select(i, ...)) end
    return a
end
local A = M.A

--- 从普通 Lua 序列（1 起始）转换
function M.fromList(list, n)
    local a = newArr()
    n = n or #list
    for i = 1, n do a[i - 1] = list[i] end
    a.n = n
    return a
end

--- Array(n).fill(v)
function M.filled(n, v)
    local a = newArr()
    for i = 0, n - 1 do a[i] = v end
    a.n = n
    return a
end

--- Array.from({ length: n }, fn)
function M.from(n, fn)
    local a = newArr()
    for i = 0, n - 1 do a[i] = fn(i) end
    a.n = n
    return a
end

function M.isArr(v) return getmetatable(v) == Arr end

function Arr:push(...)
    local k = select("#", ...)
    for i = 1, k do self[self.n] = (select(i, ...)); self.n = self.n + 1 end
    return self.n
end

function Arr:pop()
    if self.n == 0 then return nil end
    self.n = self.n - 1
    local v = self[self.n]
    self[self.n] = nil
    return v
end

function Arr:shift()
    if self.n == 0 then return nil end
    local v = self[0]
    for i = 1, self.n - 1 do self[i - 1] = self[i] end
    self[self.n - 1] = nil
    self.n = self.n - 1
    return v
end

function Arr:unshift(v)
    for i = self.n - 1, 0, -1 do self[i + 1] = self[i] end
    self[0] = v
    self.n = self.n + 1
    return self.n
end

local function normIdx(i, n, def)
    if i == nil then return def end
    if i < 0 then i = n + i; if i < 0 then i = 0 end end
    if i > n then i = n end
    return i
end

function Arr:slice(s, e)
    local n = self.n
    s = normIdx(s, n, 0); e = normIdx(e, n, n)
    local out = newArr()
    for i = s, e - 1 do out[out.n] = self[i]; out.n = out.n + 1 end
    return out
end

function Arr:splice(start, cnt, ...)
    local n = self.n
    start = normIdx(start, n, 0)
    if cnt == nil then cnt = n - start end
    if cnt < 0 then cnt = 0 end
    if start + cnt > n then cnt = n - start end
    local removed = newArr()
    for i = 0, cnt - 1 do removed:push(self[start + i]) end
    local ins = select("#", ...)
    local tail = {}
    for i = start + cnt, n - 1 do tail[#tail + 1] = self[i] end
    local tn = n - (start + cnt)
    for i = start, n - 1 do self[i] = nil end
    local w = start
    for i = 1, ins do self[w] = (select(i, ...)); w = w + 1 end
    for i = 1, tn do self[w] = tail[i]; w = w + 1 end
    self.n = w
    return removed
end

--- concat：参数是数组则展开，否则作为元素追加
function Arr:concat(...)
    local out = self:slice()
    for k = 1, select("#", ...) do
        local v = select(k, ...)
        if getmetatable(v) == Arr then
            for i = 0, v.n - 1 do out[out.n] = v[i]; out.n = out.n + 1 end
        else
            out[out.n] = v; out.n = out.n + 1
        end
    end
    return out
end

function Arr:filter(fn)
    local out = newArr()
    for i = 0, self.n - 1 do
        local v = self[i]
        if M.T(fn(v, i, self)) then out[out.n] = v; out.n = out.n + 1 end
    end
    return out
end

--- filter(Boolean)
function Arr:compact()
    local out = newArr()
    for i = 0, self.n - 1 do
        local v = self[i]
        if M.T(v) then out[out.n] = v; out.n = out.n + 1 end
    end
    return out
end

function Arr:map(fn)
    local out = newArr()
    for i = 0, self.n - 1 do out[i] = fn(self[i], i, self) end
    out.n = self.n
    return out
end

function Arr:forEach(fn)
    -- JS forEach 在开始时确定长度
    local n = self.n
    for i = 0, n - 1 do
        if i < self.n then fn(self[i], i, self) end
    end
end

function Arr:some(fn)
    for i = 0, self.n - 1 do if M.T(fn(self[i], i, self)) then return true end end
    return false
end

function Arr:every(fn)
    for i = 0, self.n - 1 do if not M.T(fn(self[i], i, self)) then return false end end
    return true
end

function Arr:find(fn)
    for i = 0, self.n - 1 do if M.T(fn(self[i], i, self)) then return self[i] end end
    return nil
end

function Arr:findIndex(fn)
    for i = 0, self.n - 1 do if M.T(fn(self[i], i, self)) then return i end end
    return -1
end

function Arr:indexOf(v)
    for i = 0, self.n - 1 do if self[i] == v then return i end end
    return -1
end

function Arr:includes(v) return self:indexOf(v) >= 0 end

function Arr:reduce(fn, init)
    local acc, s = init, 0
    if init == nil then acc = self[0]; s = 1 end
    for i = s, self.n - 1 do acc = fn(acc, self[i], i, self) end
    return acc
end

function Arr:join(sep)
    if sep == nil then sep = "," end
    local parts = {}
    for i = 0, self.n - 1 do
        local v = self[i]
        if v == nil then parts[i + 1] = ""
        elseif type(v) == "number" then parts[i + 1] = numStr(v)
        else parts[i + 1] = tostring(v) end
    end
    return table.concat(parts, sep)
end

function Arr:reverse()
    local i, j = 0, self.n - 1
    while i < j do self[i], self[j] = self[j], self[i]; i = i + 1; j = j - 1 end
    return self
end

function Arr:fill(v)
    for i = 0, self.n - 1 do self[i] = v end
    return self
end

-- 稳定归并排序（与 V8 的 TimSort 一样稳定）；cmp 返回数字或布尔
local function cmpNum(r)
    if r == true then return 1 elseif r == false or r == nil then return 0 end
    if r ~= r then return 0 end
    return r
end

-- 与 V8 的 TimSort 完全一致（数组长度 < 64 时是「找初始顺序段 + 二分插入」），
-- 这样连比较函数的调用顺序都一样（原版用随机比较函数洗牌时结果也一致）
local function v8SmallSort(self, cmp)
    local n = self.n
    local w = {}
    for i = 0, n - 1 do w[i] = self[i] end
    local function compare(a, b)
        if cmp then return cmpNum(cmp(a, b)) end
        local sa, sb = M.S(a), M.S(b)
        if sa < sb then return -1 elseif sa > sb then return 1 end
        return 0
    end
    -- 新版 V8（Chromium 141 实测）：长度小于 8 的数组直接做二分插入排序，不先找有序段
    if n < 8 then
        for start = 1, n - 1 do
            local left, right = 0, start
            local pivot = w[start]
            while left < right do
                local mid = left + ((right - left) >> 1)
                if compare(pivot, w[mid]) < 0 then right = mid else left = mid + 1 end
            end
            for p = start, left + 1, -1 do w[p] = w[p - 1] end
            w[left] = pivot
        end
        for i = 0, n - 1 do self[i] = w[i] end
        return self
    end
    -- CountAndMakeRun(0, n)
    local runLength = 2
    local order = compare(w[1], w[0])
    local desc = order < 0
    local prev = w[1]
    for idx = 2, n - 1 do
        local cur = w[idx]
        order = compare(cur, prev)
        if desc then if order >= 0 then break end
        else if order < 0 then break end end
        prev = cur
        runLength = runLength + 1
    end
    if desc then
        local i, j = 0, runLength - 1
        while i < j do w[i], w[j] = w[j], w[i]; i = i + 1; j = j - 1 end
    end
    -- BinaryInsertionSort(0, runLength, n)
    local start = runLength
    while start < n do
        local left, right = 0, start
        local pivot = w[start]
        while left < right do
            local mid = left + ((right - left) >> 1)
            local o = compare(pivot, w[mid])
            if o < 0 then right = mid else left = mid + 1 end
        end
        for p = start, left + 1, -1 do w[p] = w[p - 1] end
        w[left] = pivot
        start = start + 1
    end
    for i = 0, n - 1 do self[i] = w[i] end
    return self
end

function Arr:sort(cmp)
    local n = self.n
    -- 护栏：n 非有限数时（nan/inf）下面的 while width < n 永远不结束。
    if not (n == n) or n > 1e7 then
        print('[拉杆军团] sort 护栏触发：n=' .. tostring(n))
        return self
    end
    if n < 2 then return self end
    if n < 64 then return v8SmallSort(self, cmp) end
    local src, tmp = {}, {}
    for i = 1, n do src[i] = self[i - 1] end
    local less
    if cmp then
        less = function(a, b) return cmpNum(cmp(a, b)) > 0 end -- a 排在 b 之后？
    else
        less = function(a, b) return M.S(a) > M.S(b) end
    end
    -- 自底向上归并
    local width = 1
    while width < n do
        local i = 1
        while i <= n do
            local mid = math.min(i + width, n + 1)
            local hi = math.min(i + 2 * width, n + 1)
            local l, r, k = i, mid, i
            while l < mid and r < hi do
                -- 稳定：只有右边严格更小才先取右边
                if less(src[l], src[r]) then tmp[k] = src[r]; r = r + 1
                else tmp[k] = src[l]; l = l + 1 end
                k = k + 1
            end
            while l < mid do tmp[k] = src[l]; l = l + 1; k = k + 1 end
            while r < hi do tmp[k] = src[r]; r = r + 1; k = k + 1 end
            i = i + 2 * width
        end
        src, tmp = tmp, src
        width = width * 2
    end
    for i = 1, n do self[i - 1] = src[i] end
    return self
end

--- for (const v of arr)：长度在每一步重新检查（与 JS 一样能遍历到循环中新增的元素）
function M.of(a)
    local i = -1
    return function()
        i = i + 1
        if i < a.n then return a[i] end
        return nil
    end
end

--- 带下标遍历：for i, v in js.ipairs0(a)
function M.ipairs0(a)
    local i = -1
    return function()
        i = i + 1
        if i < a.n then return i, a[i] end
        return nil
    end
end

--- 去重（保持首次出现的顺序），等价 [...new Set(arr)]
function M.uniq(a)
    local seen, out = {}, newArr()
    for i = 0, a.n - 1 do
        local v = a[i]
        if not seen[v] then seen[v] = true; out:push(v) end
    end
    return out
end

--- Math.max(...arr) / Math.min
function M.maxOf(a, init)
    local m = init or -math.huge
    for i = 0, a.n - 1 do if a[i] > m then m = a[i] end end
    return m
end

-- ---------------------------------------------------------------------------
-- 对象
-- ---------------------------------------------------------------------------
--- Object.assign（注意：Lua 无法表达值为 nil 的键，调用处需单独处理 null 覆盖）
function M.assign(t, ...)
    for k = 1, select("#", ...) do
        local s = select(k, ...)
        if s then for key, v in pairs(s) do t[key] = v end end
    end
    return t
end

function M.copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return setmetatable(o, getmetatable(t))
end

--- 简单的集合（new Set()）
local SetMT = {}
SetMT.__index = SetMT
function M.Set(arr)
    local s = setmetatable({ items = {}, size = 0 }, SetMT)
    if arr then for i = 0, arr.n - 1 do s:add(arr[i]) end end
    return s
end
function SetMT:add(v) if not self.items[v] then self.items[v] = true; self.size = self.size + 1 end return self end
function SetMT:has(v) return self.items[v] == true end
function SetMT:delete(v) if self.items[v] then self.items[v] = nil; self.size = self.size - 1 end end
function SetMT:clear() self.items = {}; self.size = 0 end

-- ---------------------------------------------------------------------------
-- 颜色解析："#rrggbb" / "rgba(r,g,b,a)" → r, g, b, a(0~1)
-- ---------------------------------------------------------------------------
local colorCache = {}
local colorCacheN = 0
function M.parseColor(c)
    local hit = colorCache[c]
    if hit then return hit[1], hit[2], hit[3], hit[4] end
    colorCacheN = colorCacheN + 1
    if colorCacheN > 4000 then colorCache = {}; colorCacheN = 0 end -- 动态拼出来的颜色（渐隐等）不会无限占内存
    local r, g, b, a = 0, 0, 0, 1
    if c:sub(1, 1) == "#" then
        local h = c:sub(2)
        if #h == 3 then
            r = tonumber(h:sub(1, 1), 16) * 17; g = tonumber(h:sub(2, 2), 16) * 17; b = tonumber(h:sub(3, 3), 16) * 17
        else
            r = tonumber(h:sub(1, 2), 16); g = tonumber(h:sub(3, 4), 16); b = tonumber(h:sub(5, 6), 16)
            if #h == 8 then a = tonumber(h:sub(7, 8), 16) / 255 end
        end
    else
        local inner = c:match("%((.*)%)")
        local parts = {}
        for p in inner:gmatch("[^,]+") do parts[#parts + 1] = tonumber((p:gsub("%s", ""))) end
        r, g, b = parts[1], parts[2], parts[3]
        a = parts[4] or 1
    end
    colorCache[c] = { r, g, b, a }
    return r, g, b, a
end

return M
