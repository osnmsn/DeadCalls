-- main.lua

local bump = require 'bump'
local anim8 = require 'anim8'
local Camera = require 'camera'
--local player = require 'src.player'
--local skill = require 'src.skill'
local enemy = require 'src.enemy'
local json = require 'json'
local utils= require 'src.utils'
local gameWorld = require 'src.world'
local console = require 'src.console'

-- 字体
local font = love.graphics.newFont("NotoSansCJKsc-Regular.otf", 20)
love.graphics.setFont(font)

-- 全局变量
local bumpworld
local camera
local player
local enemies = {}
local attacks = {} -- 攻击判定列表
local key = {} -- 键位

-- 相机死区
local cameraDeadzone = {
    w = 300,   -- 死区宽度
    h = 150,   -- 死区高度
}
-- 键位加载
local function loadKeyBinding()
    local content = love.filesystem.read("config/keysbind.json")
    key = json.decode(content)
    
end
local function keyDown(bindList)
    for _, k in ipairs(bindList) do
        if love.keyboard.isDown(k) then return true end
    end
    return false
end
local function keyPressed(bindList, key)
    for _, k in ipairs(bindList) do
        if key == k then return true end
    end
    return false
end

function love.load()
    -- 设置窗口
    love.window.setTitle("Dead Calls")
    love.graphics.setDefaultFilter('nearest', 'nearest')
    
    -- 初始化碰撞世界
    bumpworld = bump.newWorld(32)
    -- 初始化游戏世界
    gameWorld.init(bumpworld, utils)
    -- 创建平台
    gameWorld.createPlatforms()
    
    -- 初始化相机
    camera = Camera(400, 300)

    loadKeyBinding()
    
    -- 创建玩家
    player = {
        x = 100,--位置
        y = 100,--位置
        w = 32,--宽碰撞体积
        h = 64,--高碰撞体积
        vx = 0,
        vy = 0,
        
        -- 物理参数
        speed = 300,            -- 速度
        acceleration = 2000,    -- 加速度
        friction = 1500,        -- 摩擦力
        jumpForce = 700,        -- 跳跃高度
        gravity = 1500,         -- 重力
        
        -- 状态
        onGround = false,
        facing = 1, -- 1=右, -1=左
        
        -- 土狼时间和跳跃缓冲
        coyoteTime = 0,
        coyoteTimeMax = 0.1,    -- 离开平台后还能跳跃的时间
        jumpBuffer = 0,
        jumpBufferMax = 0.1,    -- 提前按跳跃键的时间
        
        -- 冲刺系统
        isDashing = false,
        dashTimer = 0,
        dashDuration = 0.2,--持续时间
        dashSpeed = 800,
        dashCooldown = 1.0,
        dashCooldownTimer = 0,
        
        -- 攻击系统
        isAttacking = false,
        attackTimer = 0,
        attackDuration = 0.3,
        attackCooldown = 0.5,
        attackCooldownTimer = 0,
        attackRange = 40,--范围
        attackDamage = 20,--伤害
        
        -- 生命值
        hp = 100,
        maxHp = 100,
    }
        -- 初始化精灵图
    player.img = love.graphics.newImage("assets/player.png")
    
    bumpworld:add(player, player.x, player.y, player.w, player.h)

    if enemy then
        enemy.init(bumpworld, gameWorld.platforms, player)
        
        -- 生成一些敌人
        enemy.spawn(400, 320, "chaser")
        enemy.spawn(800, 270, "chaser")
    end
    
    -- 初始化 console (放在最后,确保所有依赖都准备好)
    console.init({
        player = player,
        enemy = enemy,
        bumpworld = bumpworld
    })
end

function love.update(dt)
        updatePlayer(dt)

        if enemy then
            enemy.updateAll(dt)
        end

        updateAttacks(dt)

        -- 最后更新摄像机
        updateCamera(dt)
end

function updateCamera(dt)
    -- 摄像机目标
    local camX, camY = camera.x, camera.y  

    -- 玩家中心点
    local px = player.x + player.w/2
    local py = player.y + player.h/2

    -- 死区尺寸
    local dzW = cameraDeadzone.w
    local dzH = cameraDeadzone.h

    -- 死区边界
    local left   = camX - dzW/2
    local right  = camX + dzW/2
    local top    = camY - dzH/2
    local bottom = camY + dzH/2

    -- 玩家出死区则移动摄像机
    if px < left then
        camX = px + dzW/2
    elseif px > right then
        camX = px - dzW/2
    end

    if py < top then
        camY = py + dzH/2
    elseif py > bottom then
        camY = py - dzH/2
    end

    -- 平滑移动
    local smooth = 10
    camera.x = camera.x + (camX - camera.x) * smooth * dt
    camera.y = camera.y + (camY - camera.y) * smooth * dt

    -- 应用摄像机
    camera:lookAt(camera.x, camera.y)
end

function updatePlayer(dt)
    local p = player
    
    -- 更新冷却计时器
    if p.dashCooldownTimer > 0 then
        p.dashCooldownTimer = p.dashCooldownTimer - dt
    end
    
    if p.attackCooldownTimer > 0 then
        p.attackCooldownTimer = p.attackCooldownTimer - dt
    end
    
    -- 冲刺逻辑
    if p.isDashing then
        p.dashTimer = p.dashTimer - dt
        if p.dashTimer <= 0 then
            p.isDashing = false
        end
    end
    
    -- 攻击逻辑
    if p.isAttacking then
        p.attackTimer = p.attackTimer - dt
        if p.attackTimer <= 0 then
            p.isAttacking = false
        end
    end
    
    -- 水平移动
    local targetVx = 0
    if keyDown(key.move_left) then
        targetVx = -p.speed
        p.facing = -1
    elseif keyDown(key.move_right) then
        targetVx = p.speed
        p.facing = 1
    end
    
    -- 冲刺时速度加成
    if p.isDashing then
        targetVx = p.facing * p.dashSpeed
    end
    
    -- 平滑加速/减速
    if targetVx ~= 0 then
        p.vx = p.vx + (targetVx - p.vx) * math.min(1, p.acceleration * dt)
    else
        -- 摩擦力
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
    -- 就是在离开地面后的一小段时间内仍然允许跳跃
    if p.onGround then
        p.coyoteTime = p.coyoteTimeMax
    else
        p.coyoteTime = math.max(0, p.coyoteTime - dt)
    end
    
    -- 跳跃缓冲
    if p.jumpBuffer > 0 then
        p.jumpBuffer = p.jumpBuffer - dt
    end
    
    -- 跳跃（土狼时间内或在地面）
    if p.jumpBuffer > 0 and p.coyoteTime > 0 then
        p.vy = -p.jumpForce
        p.jumpBuffer = 0
        p.coyoteTime = 0
    end
    
    -- 移动和碰撞检测
    local goalX = p.x + p.vx * dt
    local goalY = p.y + p.vy * dt
    
    local actualX, actualY, cols, len = bumpworld:move(p, goalX, goalY, playerFilter)
    
    p.x = actualX
    p.y = actualY
    
    -- 检查是否在地面
    p.onGround = false
    for i = 1, len do
        local col = cols[i]
        if col.normal.y == -1 then -- 从上方碰撞
            p.onGround = true
            p.vy = 0
        elseif col.normal.y == 1 then -- 从下方碰撞
            p.vy = 0
        end
        
        if col.normal.x ~= 0 then -- 水平碰撞
            -- 只有当与当前运动方向相反时才清零
            if utils.sign(p.vx) == col.normal.x * -1 then  
                p.vx = 0
            end
        end
    end
    -- 检查敌人碰撞
    if enemy then
        for _, e in ipairs(enemy.getAll()) do
            if utils.checkCollision(player, e) then
                -- 受伤逻辑（加个无敌帧）
                if not player.invincible then
                    player.hp = player.hp - e.damage
                    player.invincible = true
                    player.invincibleTimer = 1.0 -- 1秒无敌
                    
                    -- 击退效果
                    local knockbackDir = utils.sign(player.x - e.x)
                    player.vx = knockbackDir * 400
                    player.vy = -300
                end
            end
        end
    end
    
    -- 无敌帧倒计时
    if player.invincible then
        player.invincibleTimer = player.invincibleTimer - dt
        if player.invincibleTimer <= 0 then
            player.invincible = false
        end
    end
end

function playerFilter(item, other)
    return 'slide'
end

function updateAttacks(dt)
    for i = #attacks, 1, -1 do
        local atk = attacks[i]
        atk.lifetime = atk.lifetime - dt
        if atk.lifetime <= 0 then
            table.remove(attacks, i)
        end
    end
end

function createAttack()
    local p = player
    local atk = {
        x = p.x + (p.facing > 0 and p.w or -p.attackRange),
        y = p.y,
        w = p.attackRange,
        h = p.h,
        damage = p.attackDamage,
        owner = "player",
        lifetime = 0.2,--无敌帧持续时间
    }
    table.insert(attacks, atk)
    
    -- 检测攻击命中
    if enemy then
        local enemies_list = enemy.getAll()
        for _, e in ipairs(enemies_list) do
            if utils.checkCollision(atk, e) then
                enemy.damage(e, atk.damage)
            end
        end
    end
end

function love.keypressed(k)
    -- 打开/关闭控制台
    if keyPressed(key.console, k) then
        console.isOpen = not console.isOpen
        return  -- 阻止下面的游戏按键逻辑
    end

    -- 如果控制台打开，优先处理控制台输入
    if console.isOpen then
        console.keypressed(k)
        return  -- 阻止游戏逻辑响应
    end
    
    if keyPressed(key.jump, k) then
        player.jumpBuffer = player.jumpBufferMax
    end
    
    -- 冲刺 (Shift)
    if keyPressed(key.dash, k) then
        if player.dashCooldownTimer <= 0 and not player.isDashing then
            player.isDashing = true
            player.dashTimer = player.dashDuration
            player.dashCooldownTimer = player.dashCooldown
        end
    end
    
    -- 攻击 (J键)
    if keyPressed(key.attack, k) then
        if player.attackCooldownTimer <= 0 and not player.isAttacking then
            player.isAttacking = true
            player.attackTimer = player.attackDuration
            player.attackCooldownTimer = player.attackCooldown
            createAttack()
        end
    end
    
    if keyPressed(key.quit, k) then
        love.event.quit()
    end
end

function love.draw()
    camera:attach()
    
    -- 绘制平台
    love.graphics.setColor(0.3, 0.3, 0.3)
    for _, platform in ipairs(gameWorld.platforms) do
        love.graphics.rectangle('fill', platform.x, platform.y, platform.w, platform.h)
    end
    
    -- 绘制敌人
    if enemy then
        enemy.drawAll()
    end
    
    -- 绘制攻击判定（调试用）
    love.graphics.setColor(1, 0, 0, 0.3)
    for _, atk in ipairs(attacks) do
        love.graphics.rectangle('fill', atk.x, atk.y, atk.w, atk.h)
    end
    
    -- 绘制玩家
    love.graphics.setColor(1, 1, 1) -- 图片保持颜色

local sx = player.facing == 1 and 1 or -1   -- 水平翻转（根据朝向）
local ox = player.img:getWidth() / 2
local oy = player.img:getHeight() / 2

love.graphics.draw(
    player.img,
    player.x + player.w / 2,  -- 图片中心对齐玩家矩形中心
    player.y + player.h / 2,
    0,   -- 不旋转
    sx,  -- scaleX（左右翻转）
    1,   -- scaleY
    ox, oy  -- 以图片中心作为原点
)
    
    -- 绘制玩家朝向指示
    love.graphics.setColor(1, 1, 1)
    local eyeX = player.x + player.w/2 + player.facing * 8
    local eyeY = player.y + 15
    love.graphics.circle('fill', eyeX, eyeY, 4)
    
    -- 生命条
    local hpBarHeight = 8

love.graphics.setColor(1, 0, 0)
love.graphics.rectangle('fill', player.x, player.y - hpBarHeight - 2, player.w, hpBarHeight)

love.graphics.setColor(0, 1, 0)
love.graphics.rectangle('fill', player.x, player.y - hpBarHeight - 2, 
    player.w * (player.hp / player.maxHp), hpBarHeight)
    
    camera:detach()
    
    -- UI信息
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("WASD/方向键: 移动", 10, 10)
    love.graphics.print("空格/W: 跳跃", 10, 30)
    love.graphics.print("Shift/: 冲刺", 10, 50)
    love.graphics.print("J: 攻击", 10, 70)
    love.graphics.print(string.format("生命值: %d/%d", player.hp, player.maxHp), 10, 100)
    
    if enemy then
        love.graphics.print(string.format("敌人数量: %d", #enemy.getAll()), 10, 120)
    end
    
    -- 调试信息
    love.graphics.print(string.format("速度: %.1f, %.1f", player.vx, player.vy), 10, 140)
    love.graphics.print(string.format("位置: %.0f, %.0f", player.x, player.y), 10, 160)
    love.graphics.print("在地面: " .. tostring(player.onGround), 10, 180)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 200)
    
    -- 冷却时间显示
    if player.dashCooldownTimer > 0 then
        love.graphics.print(string.format("冲刺冷却: %.1fs", player.dashCooldownTimer), 10, 220)
    end
    if player.attackCooldownTimer > 0 then
        love.graphics.print(string.format("攻击冷却: %.1fs", player.attackCooldownTimer), 10, 240)
    end
    console.draw()

end

function love.textinput(t)
    if console.isOpen then
        console.textinput(t)
        return  -- 阻止游戏其他文本输入
    end
end




