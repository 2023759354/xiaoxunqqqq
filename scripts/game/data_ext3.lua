-- ============================================================================
-- 第十次更新：全部转职路线换成独立设计的新形象（18×18，见 data_spr_ext3.lua）
-- 以前大多数路线只是给基础兵种换个颜色，现在每条路线一张图、一套调色板，
-- 带武器的路线（剑、斧、枪、法杖、弓、爪）同时登记武器 / 弓弦骨架，攻击动画照常摆动
-- 超凡形态（sup_*）保持原样
-- 第十五次更新：古树卫士的橡木卫士、荆棘古木、盘根者、世界树、远古树人重绘，并登记树枝手臂骨架（limb），普攻时手臂抡起砸下
-- 由 logic.lua 在合并完前几次更新的数据之后调用
-- ============================================================================
return function(N)
    local X = require("game.data_spr_ext3")
    for k, v in pairs(X.SPR) do N.SPR[k] = v end
    for k, pal in pairs(X.PAL) do
        local B = N.BRANCHES[k]
        if B and not B.sup then
            B.sprite = 'pr_' .. k
            N.BRPAL[k] = pal
        end
    end
    for k, r in pairs(X.RIG) do N.WEAPON_RIG[k] = r end
    for k, r in pairs(X.BOW) do N.BOW_RIG[k] = r end
end
