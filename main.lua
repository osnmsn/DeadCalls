-- main.lua
-- 120712 3water
local bump = require 'bump'
local anim8 = require 'anim8'
local Camera = require 'camera'
local enemy = require 'src.enemy'
local json = require 'json'
local utils= require 'src.utils'
local gameWorld = require 'src.world'
local console = require 'src.console'
local RoomGenerator = require 'src.room_generator'
local Dungeon = require 'src.dungeon'
local Effects = require 'src.effects'
local BoonChoice = require 'src.boon_choice'
local Boon = require 'src.boons'
local Menu = require('src.menu')
local Weapons = require('src.weapons')

-- 字体
local font = love.graphics.newFont("assets/fonts/zpix.ttf", 20)
love.graphics.setFont(font)

-- 全局变量
local bumpworld
local camera
local player
local enemies = {}
local attacks = {} -- 攻击判定列表
local key = {} -- 键位
local gameState = "menu" -- menu, playing, gameover, victory

-- 相机死区
local cameraDeadzone = {
    w = 300,
    h = 150,
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
    
    -- 初始化相机
    camera = Camera(400, 300)

    loadKeyBinding()
    
    -- 创建玩家
    player = {
        x = 100,
        y = 100,
        w = 32,
        h = 64,
        vx = 0,
        vy = 0,
        
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
    }
    
    -- 初始化精灵图
    player.img = love.graphics.newImage("assets/player.png")
    --[[
    enemy.melee.img = love.graphics.newImage("assets/enemy_melee.png")
    enemy.ranged.img = love.graphics.newImage("assets/enemy_ranged.png")
    ]]
    bumpworld:add(player, player.x, player.y, player.w, player.h)
    
    -- 初始化敌人系统（传入 gameWorld）
    if enemy then
        enemy.init(bumpworld, gameWorld, player)
    end
    
    -- 初始化 RoomGenerator
    RoomGenerator.init(bumpworld, utils)
    
    -- 初始化 console
    console.init({
        player = player,
        enemy = enemy,
        bumpworld = bumpworld
    })
    
    -- 从菜单开始
    gameState = "menu"
end

function love.update(dt)
    --  只有一个判断，避免重复执行
    if gameState == "menu" then
        -- 菜单不需要更新逻辑
        
    elseif gameState == "playing" then
        updatePlayer(dt)
        
        -- 传入房间ID以便重建平台图
        local roomId = Dungeon.currentFloor * 100 + Dungeon.currentRoom
        enemy.updateAll(dt, roomId)
        
        Effects.update(dt)
        updateAttacks(dt)
        updateCamera(dt)
        
        -- 检查玩家死亡
        if player.hp <= 0 then
            gameState = "gameover"
        end
        
        -- 检查房间清理
        if RoomGenerator.checkCleared(enemy) then
            local door = RoomGenerator.checkDoorCollision(player)
            if door and keyDown(key.interact) then
                -- 1. 更新地牢进度
                Dungeon.currentRoom = Dungeon.currentRoom + 1
                
                if Dungeon.currentRoom > 10 then
                    -- 进入下一层
                    Dungeon.currentFloor = Dungeon.currentFloor + 1
                    Dungeon.currentRoom = 1
                    
                    if Dungeon.currentFloor > 10 then
                        gameState = "victory" -- 通关!
                        return
                    end
                    
                    Dungeon.generateFloor(Dungeon.currentFloor)
                end
                
                -- 2. 生成新房间
                local roomData = Dungeon.floorData[Dungeon.currentFloor][Dungeon.currentRoom]
                local room = RoomGenerator.generate(roomData.type)
                
                -- 3. 加载房间（自动清理旧平台、重建平台图）
                RoomGenerator.loadRoom(room, gameWorld, enemy, player)
                
                -- 4. 每3关显示祝福选择
                if Dungeon.currentRoom % 3 == 0 then
                    BoonChoice.show()
                end
            end
        end
        
    elseif gameState == "gameover" then
        -- 游戏结束状态可以添加重启逻辑
        
    elseif gameState == "victory" then
        -- 胜利状态
    end
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
        p.vy = 0   -- 冲刺锁定垂直速度
        
        Effects.addTrail(
            p.x + p.w/2,
            p.y + p.h/2,
            "ghost",
            {
                img = player.img,
                facing = player.facing,
                life = 0.1,
                alpha = 0.7
            }
        )
        
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
    if p.onGround then
        p.coyoteTime = p.coyoteTimeMax
    else
        p.coyoteTime = math.max(0, p.coyoteTime - dt)
    end
    
    -- 跳跃缓冲
    if p.jumpBuffer > 0 then
        p.jumpBuffer = p.jumpBuffer - dt
    end
    
    -- 跳跃
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
        if col.normal.y == -1 then
            p.onGround = true
            p.vy = 0
        elseif col.normal.y == 1 then
            p.vy = 0
        end
        
        if col.normal.x ~= 0 then
            if utils.sign(p.vx) == col.normal.x * -1 then  
                p.vx = 0
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
    
    -- 生命回复（星星祝福）
    if player.regenRate then
        player.hp = math.min(player.maxHp, player.hp + player.regenRate * dt)
    end
    
    -- 检查敌人碰撞
    if enemy then
        for _, e in ipairs(enemy.getAll()) do
            if utils.checkCollision(player, e) then
                if not player.invincible then
                    local damage = e.damage
                    
                    -- 伤害减免
                    if player.damageReduction then
                        damage = damage * (1 - player.damageReduction)
                    end
                    
                    player.hp = player.hp - damage
                    
                    -- 荆棘反伤
                    if player.thornsDamage then
                        enemy.damage(e, damage * player.thornsDamage)
                        Effects.emit(e.x + e.w/2, e.y, 8, {
                            color = {0.8, 0, 0.8}
                        })
                    end
                    
                    -- 受伤特效
                    Effects.emit(player.x + player.w/2, player.y, 15, {
                        color = {1, 0.2, 0.2},
                        size = 4
                    })
                    
                    player.invincible = true
                    player.invincibleTimer = 1.0
                    
                    local knockbackDir = utils.sign(player.x - e.x)
                    player.vx = knockbackDir * 400
                    player.vy = -300
                end
            end
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
    local baseDamage = p.attackDamage
    
    -- 应用伤害倍率
    if p.damageMultiplier then
        baseDamage = baseDamage * p.damageMultiplier
    end
    
    -- 暴击检查
    local finalDamage = baseDamage
    if p.critChance and math.random() < p.critChance then
        finalDamage = finalDamage * 2
        -- 暴击特效
        Effects.emit(p.x + p.w/2, p.y, 20, {
            color = {1, 1, 0},
            size = 6,
            life = 0.3
        })
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
    
    -- 检测攻击命中
    if enemy then
        for _, e in ipairs(enemy.getAll()) do
            if utils.checkCollision(atk, e) then
                enemy.damage(e, atk.damage)
                
                -- 吸血效果
                if p.lifesteal then
                    local heal = atk.damage * p.lifesteal
                    p.hp = math.min(p.maxHp, p.hp + heal)
                    Effects.emit(p.x + p.w/2, p.y, 5, {
                        color = {0, 1, 0},
                        size = 4
                    })
                end
                
                -- 连锁闪电
                if p.hasChainLightning then
                    triggerChainLightning(e, 10)
                end
                
                Effects.emit(e.x + e.w/2, e.y + e.h/2, 10, {
                    color = {1, 0, 0},
                    size = 3,
                    life = 0.5
                })
            end
        end
    end
end

-- 连锁闪电函数
function triggerChainLightning(target, damage)
    for _, e in ipairs(enemy.getAll()) do
        if e ~= target then
            local dx = e.x - target.x
            local dy = e.y - target.y
            if math.sqrt(dx*dx + dy*dy) < 150 then
                enemy.damage(e, damage)
                -- 闪电特效
                Effects.addLightning(target.x, target.y, e.x, e.y)
            end
        end
    end
end

function love.keypressed(k)
    -- 打开/关闭控制台
    if keyPressed(key.console, k) then
        console.isOpen = not console.isOpen
        return
    end

    -- 如果控制台打开，优先处理控制台输入
    if console.isOpen then
        console.keypressed(k)
        return
    end
    
    -- 游戏结束状态处理
    if gameState == "gameover" then
        if k == "r" then
            -- 重新开始
            love.load()
        end
        return
    end
    
    -- 游戏中按键处理
    if gameState == "playing" then
        if keyPressed(key.jump, k) then
            player.jumpBuffer = player.jumpBufferMax
        end
        
        -- 冲刺
        if keyPressed(key.dash, k) then
            if player.dashCooldownTimer <= 0 and not player.isDashing then
                player.isDashing = true
                player.dashTimer = player.dashDuration
                player.dashCooldownTimer = player.dashCooldown
            end
        end
        
        -- 攻击
        if keyPressed(key.attack, k) then
            if player.attackCooldownTimer <= 0 and not player.isAttacking then
                player.isAttacking = true
                player.attackTimer = player.attackDuration
                player.attackCooldownTimer = player.attackCooldown
                createAttack()
            end
        end
    end
    
    if keyPressed(key.quit, k) then
        love.event.quit()
    end
end
-- 鼠标点击处理
function love.mousepressed(x, y, button)
    if gameState == "menu" then
        local selectedWeapon = Menu.mousepressed(x, y, button)
        if selectedWeapon then
            -- 装备武器
            Weapons.equip(player, selectedWeapon)
            
            -- 初始化地牢系统
            Dungeon.init()
            Dungeon.currentFloor = 1
            Dungeon.currentRoom = 1
            Dungeon.floorData = {}
            Dungeon.generateFloor(1)
            
            -- 生成第一个房间
            local firstRoom = Dungeon.floorData[1][1]
            local room = RoomGenerator.generate(firstRoom.type)
            RoomGenerator.loadRoom(room, gameWorld, enemy, player)
            
            -- 开始游戏
            gameState = "playing"
        end
    end
    BoonChoice.mousepressed(x, y, button, player)
end
-- 鼠标移动处理（悬停高亮）
function love.mousemoved(x, y, dx, dy)
    if gameState == "playing" then
        BoonChoice.mousemoved(x, y)
    end
    if gameState == "menu" then
        Menu.mousemoved(x, y)
    end
end

function love.draw()
    --  菜单界面
    if gameState == "menu" then
        Menu.draw()
        return
    end
    
    --  游戏结束界面
    if gameState == "gameover" then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("游戏结束", 0, 250, 800, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("按 R 重新开始", 0, 300, 800, "center")
        return
    end
    
    --  胜利界面
    if gameState == "victory" then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("恭喜通关！", 0, 250, 800, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("你征服了所有10层地牢", 0, 300, 800, "center")
        return
    end
    
    --  游戏中绘制
    camera:attach()
    Effects.draw()

    -- 绘制平台
    love.graphics.setColor(0.3, 0.3, 0.3)
    for _, platform in ipairs(gameWorld.platforms) do
        love.graphics.rectangle('fill', platform.x, platform.y, platform.w, platform.h)
    end
    
    -- 绘制房间特殊元素（门、宝箱等）
    RoomGenerator.draw()
    
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
    love.graphics.setColor(1, 1, 1)

    local sx = player.facing == 1 and 1 or -1
    local ox = player.img:getWidth() / 2
    local oy = player.img:getHeight() / 2

    love.graphics.draw(
        player.img,
        player.x + player.w / 2,
        player.y + player.h / 2,
        0,
        sx,
        1,
        ox, oy
    )
    
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
    love.graphics.print("Shift: 冲刺", 10, 50)
    love.graphics.print("J: 攻击", 10, 70)
    love.graphics.print(string.format("生命值: %d/%d", player.hp, player.maxHp), 10, 100)
    
    -- 显示进度
    love.graphics.print(string.format("第%d层 - 第%d关/10", 
        Dungeon.currentFloor, Dungeon.currentRoom), 10, 120)
    
    if enemy then
        love.graphics.print(string.format("敌人数量: %d", #enemy.getAll()), 10, 140)
    end
    
    -- 调试信息
    love.graphics.print(string.format("速度: %.1f, %.1f", player.vx, player.vy), 10, 160)
    love.graphics.print(string.format("位置: %.0f, %.0f", player.x, player.y), 10, 180)
    love.graphics.print("在地面: " .. tostring(player.onGround), 10, 200)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 220)
    
    -- 冷却时间显示
    if player.dashCooldownTimer > 0 then
        love.graphics.print(string.format("冲刺冷却: %.1fs", player.dashCooldownTimer), 10, 240)
    end
    if player.attackCooldownTimer > 0 then
        love.graphics.print(string.format("攻击冷却: %.1fs", player.attackCooldownTimer), 10, 260)
    end
    
    -- 祝福选择界面
    BoonChoice.draw()
    
    -- 控制台
    console.draw()
end

function love.textinput(t)
    if console.isOpen then
        console.textinput(t)
        return
    end

end



