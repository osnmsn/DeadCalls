-- src/combat.lua
local utils = require 'src.utils'
local Effects = require 'src.effects'

local Combat = {}
local attacks = {}

function Combat.update(dt, enemyModule)
    for i = #attacks, 1, -1 do
        local atk = attacks[i]
        atk.lifetime = atk.lifetime - dt
        if atk.lifetime <= 0 then
            table.remove(attacks, i)
        end
    end
end

function Combat.createAttack(player, enemyModule)
    local p = player
    local baseDamage = p.attackDamage
    
    if p.damageMultiplier then baseDamage = baseDamage * p.damageMultiplier end
    
    local finalDamage = baseDamage
    if p.critChance and math.random() < p.critChance then
        finalDamage = finalDamage * 2
        Effects.emit(p.x + p.w/2, p.y, 20, {color = {1, 1, 0}, size = 6, life = 0.3})
    end
    
    local atk = {
        x = p.x + (p.facing > 0 and p.w or -p.attackRange),
        y = p.y,
        w = p.attackRange,
        h = p.h,
        damage = finalDamage,
        owner = "player",
        lifetime = 0.2,
    }
    table.insert(attacks, atk)
    
    -- 判定命中
    if enemyModule then
        for _, e in ipairs(enemyModule.getAll()) do
            if utils.checkCollision(atk, e) then
                enemyModule.damage(e, atk.damage)
                
                if p.lifesteal then
                    local heal = atk.damage * p.lifesteal
                    p.hp = math.min(p.maxHp, p.hp + heal)
                    Effects.emit(p.x + p.w/2, p.y, 5, {color = {0, 1, 0}, size = 4})
                end
                
                if p.hasChainLightning then
                    Combat.triggerChainLightning(e, 10, enemyModule)
                end
                
                Effects.emit(e.x + e.w/2, e.y + e.h/2, 10, {color = {1, 0, 0}, size = 3, life = 0.5})
            end
        end
    end
end

function Combat.triggerChainLightning(target, damage, enemyModule)
    for _, e in ipairs(enemyModule.getAll()) do
        if e ~= target then
            local dx = e.x - target.x
            local dy = e.y - target.y
            if math.sqrt(dx*dx + dy*dy) < 150 then
                enemyModule.damage(e, damage)
                Effects.addLightning(target.x, target.y, e.x, e.y)
            end
        end
    end
end

function Combat.drawDebug()
    love.graphics.setColor(1, 0, 0, 0.3)
    for _, atk in ipairs(attacks) do
        love.graphics.rectangle('fill', atk.x, atk.y, atk.w, atk.h)
    end
    love.graphics.setColor(1, 1, 1)
end

return Combat