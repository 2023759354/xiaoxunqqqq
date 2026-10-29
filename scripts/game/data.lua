-- 自动生成：从原版 HTML 的数据表逐项导出（数值、文案、像素精灵完全一致）
-- 数组统一用 A() 构造：下标从 0 开始，与原版 JS 一致
-- 数据按原始顺序装配，各模块只填充同一张 D 表。
---@type table<string, any>
local D = {}

require('game.data_base')(D)
require('game.data_branches')(D)
require('game.data_progression')(D)
require('game.data_sprites')(D)
require('game.data_catalog')(D)

require('game.chapter_data')(D)
require('game.data_ext')(D)
for k, v in pairs(require('game.data_spr_ext')) do D.SPR[k] = v end
-- 第六次更新：三个新兵种（吟游诗人 / 幼龙 / 冰霜元素）及其路线、第八～十章的像素精灵
require('game.data_ext2')(D)
for k, v in pairs(require('game.data_spr_ext2')) do D.SPR[k] = v end
-- 第十次更新：全部转职路线换成独立设计的 18×18 新形象（超凡形态不变）
require('game.data_ext3')(D)
-- 第十二次更新：13 个超凡角色重做（20×20 新形象 + 新技能 + 主题光效配色）
require('game.data_ext4')(D)

return D
