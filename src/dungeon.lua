-- src/dungeon.lua

local Dungeon = {
    currentFloor = 1,
    currentRoom = 1,
    totalFloors = 10,
    roomsPerFloor = 10,
    seed = 0,
    floorData = {},
    specialBosses = {},
}

--  确保 roomWeights 在模块级别定义
local roomWeights = {
    normal = 50,    -- 70% 概率普通房间
    treasure = 15,  -- 15% 概率宝藏房间
    shop = 15,      -- 15% 概率商店房间
    campfire = 20,  -- 20% 概率篝火房间（回血）
    --[[
    boon_upgrade = 10,
    boon_trader = 5,
    elite = 10,
    ]]
}

-- 初始化函数
function Dungeon.init(seed)
    Dungeon.seed = seed or os.time()
    math.randomseed(Dungeon.seed)
    Dungeon.currentFloor = 1
    Dungeon.currentRoom = 1
    Dungeon.floorData = {}
    Dungeon.specialBosses = {}
end

-- 生成一层的房间序列
function Dungeon.generateFloor(floorNumber)
    local RoomGenerator = require('src.room_generator')
    local sequence = {}
    
    -- 第1关：起始房间
    table.insert(sequence, {
        type = RoomGenerator.RoomType.START,
        index = 1,
    })
    
    -- 第2-9关：随机房间
    for i = 2, 9 do
        local roomType = Dungeon.selectRandomRoomType()
        table.insert(sequence, {
            type = roomType,
            index = i,
        })
    end
    
    -- 第10关：BOSS房间（检查特殊boss）
    local bossType = "normal"
    for _, special in ipairs(Dungeon.specialBosses) do
        if special.floor == floorNumber then
            bossType = special.bossType
            break
        end
    end
    
    table.insert(sequence, {
        type = RoomGenerator.RoomType.BOSS,
        bossType = bossType,
        index = 10,
    })
    
    Dungeon.floorData[floorNumber] = sequence
    return sequence
end

-- 根据权重随机选择房间类型
function Dungeon.selectRandomRoomType()
    local RoomGenerator = require('src.room_generator')
    
    -- 计算总权重
    local totalWeight = 0
    for _, weight in pairs(roomWeights) do
        totalWeight = totalWeight + weight
    end
    
    -- 随机选择
    local rand = math.random() * totalWeight
    local cumulative = 0
    
    for roomType, weight in pairs(roomWeights) do
        cumulative = cumulative + weight
        if rand <= cumulative then
            if roomType == "normal" then
                return RoomGenerator.RoomType.NORMAL
            elseif roomType == "treasure" then
                return RoomGenerator.RoomType.TREASURE
            elseif roomType == "shop" then
                return RoomGenerator.RoomType.SHOP
            elseif roomType == "campfire" then
                return RoomGenerator.RoomType.CAMPFIRE  -- 添加篝火
            end
        end
    end
    
    -- 默认返回普通房间
    return RoomGenerator.RoomType.NORMAL
end

-- 注册特殊boss
function Dungeon.registerSpecialBoss(floorNumber, bossType)
    table.insert(Dungeon.specialBosses, {
        floor = floorNumber,
        bossType = bossType
    })
end

-- 检查是否是最终关卡
function Dungeon.isFinalBoss()
    return Dungeon.currentFloor == 10 and Dungeon.currentRoom == 10
end

-- 获取进度字符串
function Dungeon.getProgressString()
    return string.format("层数 %d - 房间 %d/%d", 
        Dungeon.currentFloor, 
        Dungeon.currentRoom, 
        10)
end

-- 重置地牢（死亡或重新开始）
function Dungeon.reset()
    Dungeon.init()
    Dungeon.generateFloor(1)
end

return Dungeon