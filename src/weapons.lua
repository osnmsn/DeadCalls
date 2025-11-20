-- src/weapons.lua
local Weapons = {}

Weapons.list = {
    sword = {
        name = "断逝之刃",
        attackDuration = 0.3,
        attackCooldown = 0.5,
        attackRange = 40,
        damage = 20,
        describe = "象征徒劳的剑，似乎对敌人造成不了太大伤害，但它能随你一样不断成长。",

        -- 攻击判定生成函数
        createAttack = function(player)
            return {
                x = player.x + (player.facing > 0 and player.w or -40),
                y = player.y,
                w = 40,
                h = player.h,
                damage = player.attackDamage,
                lifetime = 0.2,
            }
        end
    },
    
    spear = {
        name = "方天画戟",
        attackDuration = 0.4,
        attackCooldown = 0.7,
        attackRange = 80,  -- 更长的攻击距离
        damage = 25,
        describe = "古代遗留下来的神兵利器，在这里却只是一根长一点的铁棍子。",

        createAttack = function(player)
            return {
                x = player.x + (player.facing > 0 and player.w or -80),
                y = player.y,
                w = 80,
                h = player.h,
                damage = player.attackDamage,
                lifetime = 0.3,
            }
        end
    },
    
    bow = {
        name = "烈阳神弓",
        attackDuration = 0.2,
        attackCooldown = 0.8,
        attackRange = 600,  -- 射程
        damage = 15,
        describe = "用伊卡洛斯之羽制成的弓，虽然是用蜡粘上去的，但好在射程够远。",

        createAttack = function(player)
            -- 发射弹道
            return {
                x = player.x + player.w/2,
                y = player.y + player.h/2,
                w = 10,
                h = 10,
                vx = player.facing * 600,  -- 会飞的攻击
                vy = 0,
                damage = player.attackDamage,
                lifetime = 1.0,
                isProjectile = true,
            }
        end
    },
    
    hammer = {
        name = "瓦解之锤",
        attackDuration = 0.5,  -- 攻击慢
        attackCooldown = 1.2,
        attackRange = 60,
        damage = 40,  -- 但伤害高
        describe = "用这把锤子瓦解敌人的进攻吧！虽然冷却可能撑不到下次攻击。",

        createAttack = function(player)
            -- 范围攻击（下砸）
            return {
                x = player.x - 20,
                y = player.y + player.h - 40,
                w = player.w + 40,
                h = 40,
                damage = player.attackDamage,
                lifetime = 0.3,
                knockback = 800,  -- 击退效果
            }
        end
    },
}

function Weapons.equip(player, weaponName)
    local weapon = Weapons.list[weaponName]
    if not weapon then return end
    
    player.weapon = weaponName
    player.attackDuration = weapon.attackDuration
    player.attackCooldown = weapon.attackCooldown
    player.attackRange = weapon.attackRange
    player.attackDamage = weapon.damage
    player.createAttack = weapon.createAttack
end

return Weapons