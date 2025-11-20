-- world.lua

local world = {
    platforms = {},     -- 存储所有平台
    bumpWorld = nil,    -- bump 世界对象
    utils = nil,        -- utils 模块
}

-- 初始化世界模块
function world.init(bumpWorld, utils)
    world.bumpWorld = bumpWorld
    world.utils = utils
end

-- 创建所有静态平台（测试用，现在已经不需要了）
function world.createPlatforms()
    world.addPlatform(0, 550, 1600, 50)
    world.addPlatform(200, 450, 150, 20)
    world.addPlatform(400, 350, 150, 20)
    world.addPlatform(600, 450, 150, 20)
    world.addPlatform(150, 250, 100, 20)
    world.addPlatform(500, 200, 120, 20)
    world.addPlatform(800, 300, 150, 20)
    world.addPlatform(-10, 0, 10, 600)
    world.addPlatform(1600, 0, 10, 600)
end

-- 添加平台
function world.addPlatform(x, y, w, h)
    local platform = {x = x, y = y, w = w, h = h}
    table.insert(world.platforms, platform)
    
    -- 加入 bump 世界
    if world.bumpWorld then
        world.bumpWorld:add(platform, x, y, w, h)
    end
end

-- 清空所有平台
function world.clearPlatforms()
    if world.bumpWorld then
        for _, platform in ipairs(world.platforms) do
            pcall(function() world.bumpWorld:remove(platform) end)
        end
    end
    world.platforms = {}
end

-- 从房间数据加载平台
function world.loadPlatformsFromRoom(room)
    world.clearPlatforms()
    
    for _, platform in ipairs(room.platforms) do
        world.addPlatform(platform.x, platform.y, platform.w, platform.h)
    end
end

-- 随机生成平台（现在已经不需要了）
function world.createRandomPlatforms(count)
    for i = 1, count do
        local w = 50 + world.utils.rand() * 150
        local h = 20
        local x = world.utils.rand() * 1500
        local y = 100 + world.utils.rand() * 400
        world.addPlatform(x, y, w, h)
    end
end

return world