-- src/player.lua
local Effects = require 'src.effects'
local utils = require 'src.utils'
local Input = require 'src.input' -- 引用Input模块

local Player = {}

-- 碰撞过滤器
local function playerFilter(item, other)
    return 'slide'
end

function Player.init(x, y)
    local p = {
        x = x, y = y, w = 32, h = 64,
        vx = 0, vy = 0,
        
        -- 物理参数
        speed = 300,
        acceleration = 2000,
        friction = 1500,
        jumpForce = 900,
        gravity = 1500,
        
        -- 状态
        onGround = false,
        facing = 1,
        
        -- 土狼时间和跳跃缓冲
        coyoteTime = 0,
        coyoteTimeMax = 0.1,
        jumpBuffer = 0,
        jumpBufferMax = 0.1,
        
        -- 冲刺系统
        isDashing = false,
        dashTimer = 0,
        dashDuration = 0.2,
        dashSpeed = 800,
        dashCooldown = 1.0,
        dashCooldownTimer = 0,
        
        -- 攻击系统
        isAttacking = false,
        attackTimer = 0,
        attackDuration = 0.3,
        attackCooldown = 0.5,
        attackCooldownTimer = 0,
        attackRange = 40,
        attackDamage = 20,
        
        -- 生命值
        hp = 100,
        maxHp = 100,
        
        -- 祝福列表
        boons = {},
        
        img = love.graphics.newImage("assets/player.png")
    }
    return p
end

function Player.update(player, dt, bumpworld, enemy)
    local p = player
    
    -- 更新冷却
    if p.dashCooldownTimer > 0 then p.dashCooldownTimer = p.dashCooldownTimer - dt end
    if p.attackCooldownTimer > 0 then p.attackCooldownTimer = p.attackCooldownTimer - dt end
    
    -- 冲刺逻辑
    if p.isDashing then
        p.dashTimer = p.dashTimer - dt
        p.vy = 0 
        
        Effects.addTrail(p.x + p.w/2, p.y + p.h/2, "ghost", {
            img = p.img, facing = p.facing, life = 0.1, alpha = 0.7
        })
        
        if p.dashTimer <= 0 then p.isDashing = false end
    end

    -- 攻击逻辑
    if p.isAttacking then
        p.attackTimer = p.attackTimer - dt
        if p.attackTimer <= 0 then p.isAttacking = false end
    end
    
    -- 水平移动输入
    local targetVx = 0
    if Input.isDown("move_left") then
        targetVx = -p.speed
        p.facing = -1
    elseif Input.isDown("move_right") then
        targetVx = p.speed
        p.facing = 1
    end
    
    -- 冲刺速度覆盖
    if p.isDashing then targetVx = p.facing * p.dashSpeed end
    
    -- 平滑加速/摩擦力
    if targetVx ~= 0 then
        p.vx = p.vx + (targetVx - p.vx) * math.min(1, p.acceleration * dt)
    else
        local friction = p.friction * dt
        if math.abs(p.vx) < friction then
            p.vx = 0
        else
            p.vx = p.vx - utils.sign(p.vx) * friction
        end
    end
    
    -- 重力
    p.vy = p.vy + p.gravity * dt
    
    -- 土狼时间
    if p.onGround then p.coyoteTime = p.coyoteTimeMax else p.coyoteTime = math.max(0, p.coyoteTime - dt) end
    
    -- 跳跃缓冲
    if p.jumpBuffer > 0 then p.jumpBuffer = p.jumpBuffer - dt end
    
    -- 执行跳跃
    if p.jumpBuffer > 0 and p.coyoteTime > 0 then
        p.vy = -p.jumpForce
        p.jumpBuffer = 0
        p.coyoteTime = 0
    end
    
    -- 移动碰撞
    local goalX = p.x + p.vx * dt
    local goalY = p.y + p.vy * dt
    local actualX, actualY, cols, len = bumpworld:move(p, goalX, goalY, playerFilter)
    
    p.x, p.y = actualX, actualY
    
    -- 接地检测
    p.onGround = false
    for i = 1, len do
        local col = cols[i]
        if col.normal.y == -1 then p.onGround = true; p.vy = 0
        elseif col.normal.y == 1 then p.vy = 0 end
        if col.normal.x ~= 0 and utils.sign(p.vx) == col.normal.x * -1 then p.vx = 0 end
    end
    
    -- 无敌帧
    if p.invincible then
        p.invincibleTimer = p.invincibleTimer - dt
        if p.invincibleTimer <= 0 then p.invincible = false end
    end
    
    -- 生命回复
    if p.regenRate then p.hp = math.min(p.maxHp, p.hp + p.regenRate * dt) end

    -- 碰撞伤害逻辑
    Player.handleDamageCollision(p, enemy)
end

function Player.handleDamageCollision(p, enemy)
    if not enemy then return end
    for _, e in ipairs(enemy.getAll()) do
        if utils.checkCollision(p, e) then
            if not p.invincible then
                local damage = e.damage
                if p.damageReduction then damage = damage * (1 - p.damageReduction) end
                
                p.hp = p.hp - damage
                
                -- 荆棘
                if p.thornsDamage then
                    enemy.damage(e, damage * p.thornsDamage)
                    Effects.emit(e.x + e.w/2, e.y, 8, {color = {0.8, 0, 0.8}})
                end
                
                Effects.emit(p.x + p.w/2, p.y, 15, {color = {1, 0.2, 0.2}, size = 4})
                
                p.invincible = true
                p.invincibleTimer = 1.0
                
                local knockbackDir = utils.sign(p.x - e.x)
                p.vx = knockbackDir * 400
                p.vy = -300
            end
        end
    end
end

function Player.draw(player)
    love.graphics.setColor(1, 1, 1)
    if player.invincible and math.floor(love.timer.getTime() * 10) % 2 == 0 then
         love.graphics.setColor(1, 1, 1, 0.5) -- 闪烁效果
    end

    local sx = player.facing == 1 and 1 or -1
    local ox = player.img:getWidth() / 2
    local oy = player.img:getHeight() / 2

    love.graphics.draw(player.img, player.x + player.w / 2, player.y + player.h / 2, 0, sx, 1, ox, oy)
    
    -- 绘制血条
    local hpBarHeight = 8
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', player.x, player.y - hpBarHeight - 2, player.w, hpBarHeight)
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle('fill', player.x, player.y - hpBarHeight - 2, player.w * (player.hp / player.maxHp), hpBarHeight)
    love.graphics.setColor(1, 1, 1)
end

return Player