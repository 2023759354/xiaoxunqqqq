-- 完整路径供构建引用分析；Exists 只判断本地，远端声音必须走异步下载。
local Assets = {}
Assets.music = {
    bgm_battle1 = 'audio/Sounds/bgm_c1.ogg',
    bgm_battle2 = 'audio/Sounds/bgm_c2.ogg',
    bgm_battle3 = 'audio/Sounds/bgm_c3.ogg',
    bgm_battle4 = 'audio/bgm_battle4.ogg', -- 保留霜狱冰原原曲
    bgm_battle5 = 'audio/bgm_battle5.ogg', -- 保留星陨神殿原曲
    bgm_battle6 = 'audio/Sounds/bgm_c4.ogg', -- 新第六章：蚀骨沼泽
    bgm_battle7 = 'audio/Sounds/bgm_c5.ogg', -- 新第七章：沉没海渊
    bgm_boss = 'audio/Sounds/bgm_boss.ogg',
    -- 第六次更新：第八～十章的专属战斗曲与首领曲
    bgm_c8 = 'audio/Sounds/bgm_c8.ogg',
    bgm_c9 = 'audio/Sounds/bgm_c9.ogg',
    bgm_c10 = 'audio/Sounds/bgm_c10.ogg',
    bgm_boss8 = 'audio/Sounds/bgm_boss8.ogg',
    bgm_boss9 = 'audio/Sounds/bgm_boss9.ogg',
    bgm_boss10 = 'audio/Sounds/bgm_boss10.ogg',
    home_a = 'audio/Sounds/home_a.ogg',
    home_b = 'audio/Sounds/home_b.ogg',
    home_c = 'audio/Sounds/home_c.ogg',
    -- 第十三次更新：分界面背景音乐（选英雄 / 拉杆布阵 / 商店）
    bgm_select = 'audio/05/bgm_select.ogg',
    bgm_prep = 'audio/05/bgm_prep.ogg',
    bgm_shop = 'audio/05/bgm_shop.ogg',
}
Assets.effects = {
    tick = 'audio/Sounds/tick.ogg', stop = 'audio/Sounds/stop.ogg', lever = 'audio/Sounds/lever.ogg',
    win = 'audio/Sounds/win.ogg', jackpot = 'audio/Sounds/jackpot.ogg', q1 = 'audio/Sounds/q1.ogg',
    q2 = 'audio/Sounds/q2.ogg', q3 = 'audio/Sounds/q3.ogg', summon = 'audio/Sounds/summon.ogg',
    absorb = 'audio/Sounds/absorb.ogg', star = 'audio/Sounds/star.ogg', hit = 'audio/Sounds/hit.ogg',
    shoot = 'audio/Sounds/shoot.ogg', die = 'audio/Sounds/die.ogg', fight = 'audio/Sounds/fight.ogg',
    victory = 'audio/Sounds/victory.ogg', defeat = 'audio/Sounds/defeat.ogg', deny = 'audio/Sounds/deny.ogg',
    drop = 'audio/Sounds/drop.ogg', skill = 'audio/Sounds/skill.ogg', awaken = 'audio/Sounds/awaken.ogg',
    zap = 'audio/Sounds/zap.ogg', unlock = 'audio/Sounds/unlock.ogg', q4 = 'audio/Sounds/q4.ogg',
    ult = 'audio/Sounds/ult.ogg', merge = 'audio/Sounds/merge.ogg', up = 'audio/Sounds/up.ogg',
    shop = 'audio/Sounds/shop.ogg', buy = 'audio/Sounds/buy.ogg', refresh = 'audio/Sounds/refresh.ogg',
    sell = 'audio/Sounds/sell.ogg', item = 'audio/Sounds/item.ogg',
    -- 第十三次更新：锁定 / 解锁、购买、装备、卸下、金币换秘银的专属音效
    lock = 'audio/05/lock.ogg', unlockslot = 'audio/05/unlockslot.ogg',
    purchase = 'audio/05/purchase.ogg', equip = 'audio/05/equip.ogg',
    unequip = 'audio/05/unequip.ogg', exchange = 'audio/05/exchange.ogg',
}

---@param path string
---@param done fun(sound: Sound?)
function Assets.load(path, done)
    if cache:Exists(path) then
        done(cache:GetResource('Sound', path))
    else
        cache:GetResourceAsync('Sound', path, function(resource)
            done(resource --[[@as Sound?]])
        end)
    end
end

return Assets
