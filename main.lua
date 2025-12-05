-- main.lua
--120712 3Water
--just hush, and watch my ace

-- 库引用
local bump = require 'bump'
local Camera = require 'camera'
local utils = require 'src.utils'
local json = require 'json'

-- 游戏模块引用
local Input = require 'src.input'
local Player = require 'src.player'
local Combat = require 'src.combat'
local CamCtrl = require 'src.camera_controller'
local enemy = require 'src.enemy'
local gameWorld = require 'src.world'
local console = require 'src.console'
local RoomGenerator = require 'src.room_generator'
local Dungeon = require 'src.dungeon'
local Effects = require 'src.effects'
local BoonChoice = require 'src.boon_choice'
local Menu = require 'src.menu'
local Weapons = require 'src.weapons'

-- 字体
local font = love.graphics.newFont("assets/fonts/zpix.ttf", 20)
love.graphics.setFont(font)

-- 全局变量
local bumpworld
local camera
local player
local gameState = "menu" -- menu, playing, gameover, victory

function love.load()
    love.window.setTitle("Dead Calls 《死亡电话》")
    love.graphics.setDefaultFilter('nearest', 'nearest')
    
    -- 初始化物理世界
    bumpworld = bump.newWorld(32)
    
    -- 初始化静态游戏世界
    gameWorld.init(bumpworld, utils)
    
    -- 初始化相机
    camera = Camera(400, 300)

    -- 加载键位
    Input.load()
    
    -- 初始化玩家
    player = Player.init(100, 100)
    bumpworld:add(player, player.x, player.y, player.w, player.h)
    
    -- 初始化敌人系统
    if enemy then enemy.init(bumpworld, gameWorld, player) end
    
    -- 初始化房间生成器
    RoomGenerator.init(bumpworld, utils)
    
    -- 初始化控制台
    console.init({
        player = player,
        enemy = enemy,
        bumpworld = bumpworld
    })
    --no me gusta, porque console es aburido y dificil
    gameState = "menu"
end

function love.update(dt)
    if gameState == "menu" then
        --菜单逻辑
    elseif gameState == "playing" then
        --更新玩家
        Player.update(player, dt, bumpworld, enemy)
        
        --更新环境/敌人
        local roomId = Dungeon.currentFloor * 100 + Dungeon.currentRoom
        enemy.updateAll(dt, roomId)
        Effects.update(dt)--え？うそ？私天才じゃないの？
        
        --更新战斗系统
        Combat.update(dt, enemy)
        
        --更新相机
        CamCtrl.update(camera, player, dt)
        
        --游戏流程检查
        checkGameFlow()
        
    elseif gameState == "gameover" or gameState == "victory" then
        -- 结束状态逻辑
    end
end

-- 将复杂的过关逻辑分离出来保持 update 干净
function checkGameFlow()
    -- 死亡检查
    if player.hp <= 0 then gameState = "gameover"; return end
    
    -- 房间清理检查
    if RoomGenerator.checkCleared(enemy) then
        local door = RoomGenerator.checkDoorCollision(player)
        if door and Input.isDown("interact") then
            advanceLevel()
        end
    end
end

function advanceLevel()
    Dungeon.currentRoom = Dungeon.currentRoom + 1
    
    if Dungeon.currentRoom > 10 then
        Dungeon.currentFloor = Dungeon.currentFloor + 1
        Dungeon.currentRoom = 1
        
        if Dungeon.currentFloor > 10 then
            gameState = "victory"
            return
        end
        Dungeon.generateFloor(Dungeon.currentFloor)
    end
    
    local roomData = Dungeon.floorData[Dungeon.currentFloor][Dungeon.currentRoom]
    local room = RoomGenerator.generate(roomData.type)
    
    RoomGenerator.loadRoom(room, gameWorld, enemy, player)
    
    if Dungeon.currentRoom % 3 == 0 then
        BoonChoice.show()
    end
end

function love.draw()
    if gameState == "menu" then
        Menu.draw()
        return
    elseif gameState == "gameover" then
        drawEndScreen("游戏结束", "按 R 重新开始", {1, 0, 0})
        return
    elseif gameState == "victory" then
        drawEndScreen("恭喜通关！", "你征服了所有10层地牢", {1, 1, 0})
        return
    end
    
    -- 游戏中绘制
    camera:attach()
        Effects.draw()
        
        -- 绘制环境
        love.graphics.setColor(0.3, 0.3, 0.3)
        for _, platform in ipairs(gameWorld.platforms) do
            love.graphics.rectangle('fill', platform.x, platform.y, platform.w, platform.h)
        end
        RoomGenerator.draw()
        
        -- 绘制实体
        if enemy then enemy.drawAll() end
        Combat.drawDebug() -- 看攻击范围
        Player.draw(player)
    camera:detach()
    
    -- UI 绘制
    drawUI()
    BoonChoice.draw()
    console.draw()
end

function drawUI()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("WASD/方向键: 移动  空格: 跳跃  Shift: 冲刺  J: 攻击", 10, 10)
    love.graphics.print(string.format("生命值: %d/%d", math.floor(player.hp), player.maxHp), 10, 40)
    love.graphics.print(string.format("第%d层 - 第%d关/10", Dungeon.currentFloor, Dungeon.currentRoom), 10, 60)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 80)
    
    if player.dashCooldownTimer > 0 then
        love.graphics.print(string.format("冲刺CD: %.1f", player.dashCooldownTimer), 10, 100)
    end
end

function drawEndScreen(title, subtitle, color)
    love.graphics.setColor(unpack(color))
    love.graphics.printf(title, 0, 250, 800, "center")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(subtitle, 0, 300, 800, "center")
end

function love.keypressed(k)
    -- 控制台
    if Input.isPressed("console", k) then
        console.isOpen = not console.isOpen
        return
    end
    if console.isOpen then console.keypressed(k); return end
    
    -- 游戏状态处理
    if gameState == "gameover" and k == "r" then
        love.load() -- 重启
        return
    end
    
    if gameState == "playing" then
        if Input.isPressed("jump", k) then
            player.jumpBuffer = player.jumpBufferMax
        end
        
        if Input.isPressed("dash", k) then
            if player.dashCooldownTimer <= 0 and not player.isDashing then
                player.isDashing = true
                player.dashTimer = player.dashDuration
                player.dashCooldownTimer = player.dashCooldown
            end
        end
        
        if Input.isPressed("attack", k) then
            if player.attackCooldownTimer <= 0 and not player.isAttacking then
                player.isAttacking = true
                player.attackTimer = player.attackDuration
                player.attackCooldownTimer = player.attackCooldown
                Combat.createAttack(player, enemy)
            end
        end
    end
    
    if Input.isPressed("quit", k) then love.event.quit() end
end

function love.mousepressed(x, y, button)
    if gameState == "menu" then
        local selectedWeapon = Menu.mousepressed(x, y, button)
        if selectedWeapon then
            Weapons.equip(player, selectedWeapon)
            
            -- 重置地牢
            Dungeon.init()
            Dungeon.currentFloor, Dungeon.currentRoom = 1, 1
            Dungeon.floorData = {}
            Dungeon.generateFloor(1)
            
            local firstRoom = Dungeon.floorData[1][1]
            local room = RoomGenerator.generate(firstRoom.type)
            RoomGenerator.loadRoom(room, gameWorld, enemy, player)
            
            gameState = "playing"
        end
    end
    BoonChoice.mousepressed(x, y, button, player)
end

function love.mousemoved(x, y, dx, dy)
    if gameState == "playing" then BoonChoice.mousemoved(x, y) end
    if gameState == "menu" then Menu.mousemoved(x, y) end
end

function love.textinput(t)
    if console.isOpen then console.textinput(t) end
end