-- src/room_generator.lua

local json = require('../json')

local RoomGenerator = {}

-- 房间类型
RoomGenerator.RoomType = {
    START = "start",
    NORMAL = "normal",
    TREASURE = "treasure",
    SHOP = "shop",
    CAMPFIRE = "campfire",
    BOSS = "boss",
}

-- 房间模板池
RoomGenerator.templates = {
    start = nil,
    normal = nil,
    treasure = nil,
    campfire = nil,
    boss = nil,
}

-- 房间尺寸
RoomGenerator.ROOM_WIDTH = 1600
RoomGenerator.ROOM_HEIGHT = 600

-- 当前房间数据
RoomGenerator.currentRoom = nil
RoomGenerator.roomCleared = false

-- 初始化
function RoomGenerator.init(world, utils)
    RoomGenerator.world = world
    RoomGenerator.utils = utils
    
    -- 加载所有房间模板
    RoomGenerator.loadTemplates()
end

-- 加载房间模板
function RoomGenerator.loadTemplates()
    local roomTypes = {"start", "normal", "treasure", "campfire", "boss"}
    
    for _, roomType in ipairs(roomTypes) do
        local path = "data/rooms/" .. roomType .. ".json"
        local success, content = pcall(love.filesystem.read, path)
        
        if success and content then
            local data = json.decode(content)
            RoomGenerator.templates[roomType] = data.rooms
            print(string.format("加载 %s 房间模板: %d 个", roomType, #data.rooms))
        else
            print(string.format("警告: 无法加载 %s 房间模板", roomType))
            RoomGenerator.templates[roomType] = {}
        end
    end
end

-- 从模板生成房间
function RoomGenerator.generate(roomType, seed)
    if seed then
        math.randomseed(seed)
    end
    
    local templates = RoomGenerator.templates[roomType]
    
    -- 如果没有模板，使用旧的随机生成方法（后备方案）
    if not templates or #templates == 0 then
        print("警告: " .. roomType .. " 没有模板，使用随机生成")
        return RoomGenerator.generateFallback(roomType)
    end
    
    -- 随机选择一个模板
    local templateIndex = math.random(1, #templates)
    local template = templates[templateIndex]
    
    -- 深拷贝模板（避免修改原始数据）
    local room = RoomGenerator.deepCopy(template)
    room.type = roomType
    room.cleared = false
    
    print(string.format("生成房间: %s (%s)", room.id or "unknown", room.name or "unnamed"))
    
    RoomGenerator.currentRoom = room
    RoomGenerator.roomCleared = false
    
    return room
end

-- 深拷贝函数
function RoomGenerator.deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = RoomGenerator.deepCopy(orig_value)
        end
    else
        copy = orig
    end
    return copy
end

-- 后备随机生成方法（保留原有逻辑）
function RoomGenerator.generateFallback(roomType)
    local room = {
        type = roomType,
        platforms = {},
        enemies = {},
        doors = {},
        items = {},
        cleared = false,
    }
    
    if roomType == RoomGenerator.RoomType.START then
        RoomGenerator.generateStartRoom(room)
    elseif roomType == RoomGenerator.RoomType.NORMAL then
        RoomGenerator.generateNormalRoom(room)
    elseif roomType == RoomGenerator.RoomType.TREASURE then
        RoomGenerator.generateTreasureRoom(room)
    elseif roomType == RoomGenerator.RoomType.CAMPFIRE then
        RoomGenerator.generateCampfireRoom(room)
    elseif roomType == RoomGenerator.RoomType.BOSS then
        RoomGenerator.generateBossRoom(room)
    end
    
    return room
end

-- 保留原有的生成函数作为后备
function RoomGenerator.generateStartRoom(room)
    table.insert(room.platforms, {x = 0, y = 550, w = 1600, h = 50})
    table.insert(room.platforms, {x = 400, y = 400, w = 200, h = 20})
    table.insert(room.platforms, {x = 1000, y = 400, w = 200, h = 20})
    table.insert(room.platforms, {x = -10, y = 0, w = 10, h = 600})
    table.insert(room.platforms, {x = 1600, y = 0, w = 10, h = 600})
    table.insert(room.doors, {
        x = 1520, y = 500, w = 80, h = 50,
        direction = "right", locked = false
    })
end

function RoomGenerator.generateNormalRoom(room)
    table.insert(room.platforms, {x = 0, y = 550, w = 1600, h = 50})
    local platformCount = math.random(5, 10)
    for i = 1, platformCount do
        local w = math.random(80, 200)
        local h = 20
        local x = math.random(100, 1500 - w)
        local y = math.random(200, 500)
        table.insert(room.platforms, {x = x, y = y, w = w, h = h})
    end
    table.insert(room.platforms, {x = -10, y = 0, w = 10, h = 600})
    table.insert(room.platforms, {x = 1600, y = 0, w = 10, h = 600})
    
    local enemyCount = math.random(3, 6)
    for i = 1, enemyCount do
        table.insert(room.enemies, {
            type = "chaser",
            x = math.random(200, 1400),
            y = 100
        })
    end
    
    table.insert(room.doors, {x = 20, y = 500, w = 80, h = 50, direction = "left", locked = false})
    table.insert(room.doors, {x = 1520, y = 500, w = 80, h = 50, direction = "right", locked = true})
end

function RoomGenerator.generateTreasureRoom(room)
    table.insert(room.platforms, {x = 0, y = 550, w = 1600, h = 50})
    table.insert(room.platforms, {x = 700, y = 350, w = 200, h = 20})
    table.insert(room.platforms, {x = -10, y = 0, w = 10, h = 600})
    table.insert(room.platforms, {x = 1600, y = 0, w = 10, h = 600})
    table.insert(room.items, {type = "chest", x = 800, y = 330})
    table.insert(room.doors, {x = 20, y = 500, w = 80, h = 50, direction = "left", locked = false})
    table.insert(room.doors, {x = 1520, y = 500, w = 80, h = 50, direction = "right", locked = false})
end

function RoomGenerator.generateCampfireRoom(room)
    table.insert(room.platforms, {x = 0, y = 550, w = 1600, h = 50})
    table.insert(room.platforms, {x = 650, y = 400, w = 300, h = 20})
    table.insert(room.platforms, {x = -10, y = 0, w = 10, h = 600})
    table.insert(room.platforms, {x = 1600, y = 0, w = 10, h = 600})
    table.insert(room.items, {type = "campfire", x = 800, y = 370, healAmount = 30, used = false})
    table.insert(room.doors, {x = 20, y = 500, w = 80, h = 50, direction = "left", locked = false})
    table.insert(room.doors, {x = 1520, y = 500, w = 80, h = 50, direction = "right", locked = false})
end

function RoomGenerator.generateBossRoom(room)
    table.insert(room.platforms, {x = 0, y = 550, w = 1600, h = 50})
    table.insert(room.platforms, {x = 100, y = 350, w = 150, h = 20})
    table.insert(room.platforms, {x = 1350, y = 350, w = 150, h = 20})
    table.insert(room.platforms, {x = -10, y = 0, w = 10, h = 600})
    table.insert(room.platforms, {x = 1600, y = 0, w = 10, h = 600})
    table.insert(room.enemies, {type = "boss", x = 800, y = 100})
    table.insert(room.doors, {x = 20, y = 500, w = 80, h = 50, direction = "left", locked = false})
end

-- 加载房间到游戏世界
function RoomGenerator.loadRoom(room, gameWorld, enemy, player)
    --使用 gameWorld 的方法清空和加载平台
    if gameWorld and gameWorld.loadPlatformsFromRoom then
        gameWorld.loadPlatformsFromRoom(room)
    end
    
    -- 清空并生成敌人
    if enemy and enemy.clearAll then
        enemy.clearAll()
        
        for _, enemyData in ipairs(room.enemies) do
            enemy.spawn(enemyData.x, enemyData.y, enemyData.type)
        end
    end
    
    -- 重置玩家位置
    if player then
        player.x = 100
        player.y = 100
        player.hp = math.min(player.maxHp, player.hp + 20)
        if RoomGenerator.world then
            RoomGenerator.world:update(player, player.x, player.y)
        end
    end
    
    RoomGenerator.currentRoom = room
    RoomGenerator.roomCleared = (#room.enemies == 0)
end

-- 检查房间是否清理完毕
function RoomGenerator.checkCleared(enemy)
    if RoomGenerator.roomCleared then return true end
    
    if enemy then
        local enemies = enemy.getAll()
        if #enemies == 0 then
            RoomGenerator.roomCleared = true
            RoomGenerator.unlockDoors()
            return true
        end
    end
    
    return false
end

-- 解锁门
function RoomGenerator.unlockDoors()
    if not RoomGenerator.currentRoom then return end
    
    for _, door in ipairs(RoomGenerator.currentRoom.doors) do
        door.locked = false
    end
end

-- 检查玩家是否在门口
function RoomGenerator.checkDoorCollision(player)
    if not RoomGenerator.currentRoom then return nil end
    
    for _, door in ipairs(RoomGenerator.currentRoom.doors) do
        if not door.locked then
            if player.x + player.w > door.x and 
               player.x < door.x + door.w and
               player.y + player.h > door.y and
               player.y < door.y + door.h then
                return door
            end
        end
    end
    
    return nil
end

-- 检查玩家是否在篝火附近
function RoomGenerator.checkCampfireCollision(player)
    if not RoomGenerator.currentRoom then return nil end
    if not RoomGenerator.currentRoom.items then return nil end

    for _, item in ipairs(RoomGenerator.currentRoom.items) do
        if item.type == "campfire" and not item.used then
            local dx = math.abs(player.x + player.w/2 - item.x)
            local dy = math.abs(player.y + player.h/2 - item.y)
            
            if dx < 50 and dy < 50 then
                return item
            end
        end
    end
    
    return nil
end

-- 绘制房间特殊元素
function RoomGenerator.draw()
    if not RoomGenerator.currentRoom then return end
    
    -- 绘制门
    if RoomGenerator.currentRoom.doors then
        for _, door in ipairs(RoomGenerator.currentRoom.doors) do
            if door.locked then
                love.graphics.setColor(0.8, 0, 0)
            else
                love.graphics.setColor(0, 0.8, 0)
            end
            love.graphics.rectangle('fill', door.x, door.y, door.w, door.h)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle('line', door.x, door.y, door.w, door.h)
        end
    end
    -- 绘制物品
    if RoomGenerator.currentRoom.items then
        for _, item in ipairs(RoomGenerator.currentRoom.items) do
            if item.type == "chest" then
                love.graphics.setColor(1, 0.8, 0)
                love.graphics.rectangle('fill', item.x - 20, item.y - 20, 40, 30)
                love.graphics.setColor(0.4, 0.2, 0)
                love.graphics.rectangle('line', item.x - 20, item.y - 20, 40, 30)
                
            elseif item.type == "campfire" then
                if item.used then
                    -- 已使用：灰色灰烬
                    love.graphics.setColor(0.3, 0.3, 0.3)
                    love.graphics.circle('fill', item.x, item.y, 15)
                    love.graphics.setColor(0.5, 0.5, 0.5)
                    love.graphics.circle('line', item.x, item.y, 15)
                else
                    -- 未使用：橙色火焰
                    love.graphics.setColor(1, 0.5, 0)
                    love.graphics.circle('fill', item.x, item.y, 20)
                    love.graphics.setColor(1, 1, 0)
                    love.graphics.circle('fill', item.x, item.y - 10, 12)
                    love.graphics.setColor(1, 0.8, 0)
                    love.graphics.circle('fill', item.x - 5, item.y - 5, 8)
                    love.graphics.circle('fill', item.x + 5, item.y - 5, 8)
                    
                    -- 提示文字
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print("按 F 休息", item.x - 30, item.y - 40)
                end
            end
        end
    end
end

return RoomGenerator