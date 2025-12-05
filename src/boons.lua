-- src/boons.lua
local Boons = {}
local Dungeon = require('src.dungeon')
local enemy = require('src.enemy')
--准备做38张正逆位塔罗牌祝福，世界、命运之轮、恶魔专门拿出来做成特殊祝福
--恶魔——高风险高回报 ps：badend
--世界——与上帝联手 ps：normalend
--命运之轮——掌控命运 ps：loopend/secretend
Boons.list = {
    crit_chance = {
        name = "【正义·逆位】致命审判",
        desc = "命运之刃带来的不公，15% 几率造成双倍伤害。",
        rarity = "common",
        apply = function(player)
            player.critChance = (player.critChance or 0) + 0.15
        end,
        onAttack = function(player, damage)
            if math.random() < (player.critChance or 0) then
                return damage * 2
            end
            return damage
        end
    },
--[[
    world_raphael = {
        name = "【世界·拉斐尔】天使之赐",
        desc = "获得天使拉斐尔的祝福，战斗胜利后回复15点生命值。",
        rarity = "epic",
        apply = function(player)
            player.hasWorldRaphael = true
            player.swapGod = player.swapGod +1
        end
    },

    world_gabriel = {
        name = "【世界·加百列】护心盾",
        desc = "获得天使加百列的祝福，受到致命攻击时会复活并获得100hp（不会超过最大hp）。",
        rarity = "epic",
        apply = function(player)
            player.hasWorldGabriel = true
            player.swapGod = player.swapGod +1
        end
    },

    fortune_ring = {
        name = "【命运之轮】幸运之环",
        desc = "掌控命运的轮盘，此后必定暴击。", --包括此后所有的循环
        rarity = "epic",
        apply = function(player)
            player.hasFortuneRing = true
            player.critChance = (player.critChance or 0) + 1.0
            end,
            onAttack = function(player, damage)
            if math.random() < (player.critChance or 0) then
                return damage * 2
            end
            return damage
        end
    },

    fortune_eyes = {
        name = "【命运之轮】全视之眼",
        desc = "曾是上帝的一只眼睛，可以看到ΛΚΝΜτθ的未来。",
        rarity = "epic",
        apply = function(player)
            player.hasFortuneEyes = true
        end
    },

    tower_recorder = {
        name = "【塔】计数器"
        desc = "你是怎么得到这张卡牌的？"
        rarity = "impossible"
        apply = function(player)
            player.hasTowerRecorder = true

    _
    ]]


    devil_DamageExchange = {
        name = "【恶魔I】血债契约",
        desc = "与恶魔做出的交换，以20%最大生命的代价换取15%的全伤害加成。",
        rarity = "devil",
        apply = function(player)
            player.damageMultiplier = (player.damageMultiplier or 1) * 1.15
            player.devilsDamageExchange = true
            player.maxHp = math.floor(player.maxHp * 0.8)
            player.hp = math.min(player.hp, player.maxHp)
            player.devilBossI= true
            Dungeon.registerSpecialBoss(1, "devil_I") -- 替换1-11的boss
        end
    },
    
    devil_bet = {
        name = "【恶魔XII】赌约",
        desc = "与恶魔的赌约，祂将一切赌注压在了你身上，希望你能走到祂面前，向祂挥剑，祂已经好久没有享受过玩弄猎物的感受了",
        rarity = "devil",
        apply = function(player)
            player.devilsBet = true
            player.damageMultiplier = (player.damageMultiplier or 1) * 5.0
            player.hp = 1
            player.maxHp = 1
            player.speed = player.speed * 2.0
            player.devilBossXII= true --只要选择恶魔祝福，就会将最终BOSS替换并加入所有已选择祝福的BOSS
            Dungeon.registerSpecialBoss(10, "devil_XII")
        end
    },

    devil_dream = {
        name = "【恶魔X】永恒之梦",
        desc = "恶魔许诺你永生，但却忘了说代价。",
        rarity = "devil",
        apply = function(player)
            player.devilsDream = true
            player.damageMultiplier = (player.damageMultiplier or 1) * 0.1
            player.maxHp = math.min(math.floor(player.maxHp * 10.0), 99999)--或许可以让你的队友选赌约输出，你在前面抗伤害
            player.hp = math.min(player.hp, player.maxHp)
            player.devilBossX= true
            Dungeon.registerSpecialBoss(10, "devil_X")
        end
    },
--[[
    devil_hatred = {
        name = "【恶魔V】恨天恨地咏叹调", 
        desc = "你的怨恨让恶魔感到欣慰，祂给予了你毁灭一切怨恨之物的力量，也让你同时被世人所唾弃。",
        rarity = "devil",
        apply = function(player)
            player.hasDevilsHatred = true
            player.damageMultiplier = (player.damageMultiplier or 1) * 2.0
            商店价格增加300%
            无法选择篝火（回血）、祝福升级、祝福交换节点
            player.devilBossV= true
            Dungeon.registerSpecialBoss(5, "devil_V")
        end
    },

    devil_gluttony = {
        name = "【恶魔III】最后的晚餐",
        desc = "恶魔给予了你对食物的渴望，但你似乎吃不下这顿晚餐了。",
        rarity = "devil",
        apply = function(player)
            player.devilsGluttony = true
            生命拾取效果x3
            但是最大HP减少50%
            每场战斗最多掉落2个生命拾取
            player.devilBossIII= true
            Dungeon.registerSpecialBoss(3, "devil_III")
        end
    },

    devil_sloth = {
        name = "【恶魔VI】永寂之座",
        desc = "恶魔赋予了你不用动就可以完成战斗的能力，但你似乎无法行动了。",
        rarity = "devil",
        apply = function(player)
            player.devilsSloth = true
            增加两个VI恶魔召唤物 --帮忙打怪的
            移动速度-50%
            攻击速度-50%
            player.devilBossIV = true
            Dungeon.registerSpecialBoss(6, "devil_IV")
        end
    },

    devil_pride = {
        name = "【恶魔VIII】断罪者的荆冕",
        desc = "恶魔赋予了你践踏一切生命的傲慢，但你也同时失去了身边人。",
        rarity = "devil",
        apply = function(player)
            player.devilsPride = true
            全伤害+100%
            失去所有伙伴（召唤物、宠物等）
            商店价格增加200%
            篝火、祝福升级、祝福交换节点有40%概率被赶出去，并扣除5滴血
            player.devilBossVIII= true
            Dungeon.registerSpecialBoss(8, "devil_VIII")
        end
    },

    devil_greed = {
        name = "【恶魔IX】黄金馒头",
        desc = "恶魔赋予了你无尽的财富，但你似乎失去了对Ӝ҂ѦⱵⱷȸ的判断。",
        rarity = "devil",
        apply = function(player)
            player.devilsGreed = true
            金钱掉落x3
            无法恢复血量
            敌人数量x2
            敌人金钱掉落概率降低50%
            player.devilBossIX= true
            Dungeon.registerSpecialBoss(9, "devil_IX")
        end
    },

]]

    chain_lightning = {
    name = "【高塔】雷霆洗礼",
    desc = "攻击命中后，对目标附近的敌人释放轰鸣的连锁闪电。",
    rarity = "rare",
    apply = function(player)
        player.hasChainLightning = true
    end,
    onHit = function(player, target)
        for _, e in ipairs(enemy.getAll()) do
            if e ~= target then
                local dx = e.x - target.x
                local dy = e.y - target.y
                if math.sqrt(dx*dx + dy*dy) < 150 then
                    enemy.damage(e, 10)
                     -- 添加雷霆特效
                end
            end
        end
    end
    },

    lifesteal = {
        name = "【死神·正位】生命轮回",
        desc = "汲取生命的循环：攻击回复 5% 造成伤害的生命值。",
        rarity = "common",
        apply = function(player)
            player.lifesteal = (player.lifesteal or 0) + 0.05
        end
    },

    -- ===== 移动类 =====
    dash_strike = {
        name = "【战车】破阵突击",
        desc = "冲刺结束时，对路径上所有敌人造成伤害。",
        rarity = "epic",
        apply = function(player)
            player.hasDashStrike = true
        end
    },

    double_jump = {
        name = "【愚者】跃入未知",
        desc = "借由愚者的勇气，你可以进行空中二段跳。",
        rarity = "common",
        apply = function(player)
            player.maxJumps = 2
            player.jumpsLeft = 2
        end
    },

    speed_boost = {
        name = "【太阳】疾光行者",
        desc = "阳光赐福：移动速度提升 25%。",
        rarity = "common",
        apply = function(player)
            player.speed = player.speed * 1.25
        end
    },

    damage_reduction = {
        name = "【力量】圣狮守护",
        desc = "受到的伤害减少 20%。",
        rarity = "common",
        apply = function(player)
            player.damageReduction = (player.damageReduction or 0) + 0.2
        end
    },

    revenge_damage = {
        name = "【审判】苦难回响",
        desc = "受击时反弹 30% 所承受的伤害。",
        rarity = "rare",
        apply = function(player)
            player.thornsDamage = (player.thornsDamage or 0) + 0.3
        end
    },

    health_regen = {
        name = "【星星】宁静重生",
        desc = "星光的温柔抚慰你，每秒恢复 2 点生命。",
        rarity = "rare",
        apply = function(player)
            player.regenRate = (player.regenRate or 0) + 2
        end
    },
}

function Boons.grant(player, boonName)
    local boon = Boons.list[boonName]
    if not boon then return end

    for _, b in ipairs(player.boons) do
        if b == boonName then
            return
        end
    end

    boon.apply(player)
    table.insert(player.boons, boonName)
end

function Boons.getRandomSelection(count)
    local available = {}
    for name, _ in pairs(Boons.list) do
        table.insert(available, name)
    end

    local selection = {}
    for i = 1, math.min(count, #available) do
        local idx = math.random(#available)
        table.insert(selection, available[idx])
        table.remove(available, idx)
    end

    return selection
end

return Boons
