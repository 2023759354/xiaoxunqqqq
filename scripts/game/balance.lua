-- ============================================================================
-- 第三次更新：降低第三章「虚空回廊」的难度
--  * 第三章敌人强度系数约 -7%（普通 / 困难 / 噩梦 / 炼狱同比例）
--  * 第三～五章首领生命 -10%（虚空之主 / 腐母 / 深渊利维坦）
-- 难度说明里的「敌人最高 +N%」按新系数重新生成
--
-- 注：源更新方案是按 5 章体系写的（蚀骨沼泽 = 第四章、沉没海渊 = 第五章）。
-- 本工程是 7 章体系（第四章「霜狱冰原」、第五章「星陨神殿」、
-- 第六章「蚀骨沼泽」、第七章「沉没海渊」），系数是逐章递增的，
-- 且第 6/7 章的章节系数已按本工程的曲线单独定过，因此这里不再下调它们，
-- 只修正第三章。首领生命 -10% 仍对三个对应首领生效。
-- ============================================================================
local _ENV = require("game.env")
local js = require("game.compat")
local round = js.round

-- 第三章「虚空回廊」= CHAPTERS[2]（0 基）：1.4 / 1.9 / 2.3 / 2.75 → 1.3 / 1.75 / 2.15 / 2.55
local MULTS = {
    [2] = { 1.3, 1.75, 2.15, 2.55 },
}
for c, list in pairs(MULTS) do
    local C = CHAPTERS[c]
    if C then
        for d = 0, #C.diffs - 1 do
            local Df = C.diffs[d]
            Df.mult = list[d + 1]
            if Df.desc then
                Df.desc = Df.desc:gsub('敌人最高 %+%d+%%', '敌人最高 +' .. round((Df.mult - 1) * 100) .. '%%')
            end
        end
    end
end
for _, k in ipairs({ 'voidlord', 'rotmother', 'leviathan' }) do
    if ENEMIES[k] then ENEMIES[k].hp = round(ENEMIES[k].hp * 0.9) end
end

return true
