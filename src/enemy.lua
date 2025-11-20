-- enemy.lua
-- 敌人AI系统，使用Platform Graph + A*寻路

local enemy = {}

local world
local gameWorld  -- 改为存储 gameWorld
local player
local enemies = {}
local platformGraph = {}
local currentRoomId = nil  -- 追踪当前房间

-- 敌人类型定义
local enemyTypes = {
    chaser = {
        speed = 200,
        jumpForce = 600,
        gravity = 1500,
        hp = 30,
        damage = 10,
        detectionRange = 400,
        attackRange = 200,
        color = {1, 0.3, 0.3},
    }
}

-- 接收 gameWorld 而不是 platforms
function enemy.init(w, gw, pl)
    world = w
    gameWorld = gw  -- 存储 gameWorld 引用
    player = pl
    enemies = {}
    platformGraph = {}
    currentRoomId = nil
end

function enemy.spawn(x, y, type)
    local template = enemyTypes[type]
    if not template then return end
    
    local e = {
        x = x,
        y = y,
        w = 28,
        h = 40,
        vx = 0,
        vy = 0,
        
        speed = template.speed,
        jumpForce = template.jumpForce,
        gravity = template.gravity,
        hp = template.hp,
        maxHp = template.hp,
        damage = template.damage,
        detectionRange = template.detectionRange,
        attackRange = template.attackRange,
        color = template.color,
        
        type = type,
        state = "idle",
        onGround = false,
        facing = 1,
        
        path = {},
        pathIndex = 1,
        pathUpdateTimer = 0,
        pathUpdateInterval = 0.5,
        
        wantJump = false,
        wantDash = false,
    }
    
    table.insert(enemies, e)
    world:add(e, e.x, e.y, e.w, e.h)
    
    return e
end

-- 添加 roomId 参数
function enemy.updateAll(dt, roomId)
    -- 检查房间是否改变，改变则重建平台图
    if currentRoomId ~= roomId then
        currentRoomId = roomId
        buildPlatformGraph()
        print("重建敌人平台图 - 房间ID: " .. tostring(roomId))
    end
    
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        
        if e.hp <= 0 then
            world:remove(e)
            table.remove(enemies, i)
        else
            updateEnemy(e, dt)
        end
    end
end

function updateEnemy(e, dt)
    local dx = player.x - e.x
    local dy = player.y - e.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < e.attackRange then
        e.state = "attack"
        if not e.attackCooldown or e.attackCooldown <= 0 then
            e.attackCooldown = 1.0
        end
    elseif dist < e.detectionRange then
        e.state = "chase"
    else
        e.state = "idle"
    end
    
    if e.state == "chase" then
        e.pathUpdateTimer = e.pathUpdateTimer + dt
        if e.pathUpdateTimer >= e.pathUpdateInterval then
            e.pathUpdateTimer = 0
            e.path = findPath(e, player)
            e.pathIndex = 1
        end
    end
    
    if e.state == "chase" and #e.path > 0 then
        followPath(e, dt)
    else
        local friction = 800 * dt
        if math.abs(e.vx) < friction then
            e.vx = 0
        else
            e.vx = e.vx - math.sign(e.vx) * friction
        end
    end
    
    e.vy = e.vy + e.gravity * dt
    
    if e.wantJump and e.onGround then
        e.vy = -e.jumpForce
        e.wantJump = false
    end
    
    local goalX = e.x + e.vx * dt
    local goalY = e.y + e.vy * dt
    
    local actualX, actualY, cols, len = world:move(e, goalX, goalY, enemyFilter)
    e.x = actualX
    e.y = actualY
    
    e.onGround = false
    for i = 1, len do
        local col = cols[i]
        if col.normal.y == -1 then
            e.onGround = true
            e.vy = 0
        elseif col.normal.y == 1 then
            e.vy = 0
        end
        if col.normal.x ~= 0 then
            if math.sign(e.vx) == col.normal.x * -1 then
                e.vx = 0
            end
        end
    end
    
    if e.attackCooldown and e.attackCooldown > 0 then
        e.attackCooldown = e.attackCooldown - dt
    end
end

function followPath(e, dt)
    if e.pathIndex > #e.path then return end
    
    local target = e.path[e.pathIndex]
    local dx = target.x - (e.x + e.w/2)
    local dy = target.y - (e.y + e.h)
    
    if math.abs(dx) < 20 and math.abs(dy) < 20 then
        e.pathIndex = e.pathIndex + 1
        if e.pathIndex > #e.path then return end
        target = e.path[e.pathIndex]
        dx = target.x - (e.x + e.w/2)
        dy = target.y - (e.y + e.h)
    end
    
    if math.abs(dx) > 10 then
        if dx > 0 then
            e.vx = e.speed
            e.facing = 1
        else
            e.vx = -e.speed
            e.facing = -1
        end
    else
        e.vx = 0
    end
    
    if target.action == "jump" and e.onGround then
        e.wantJump = true
    end
end

function enemyFilter(item, other)
    if other == player then
        return 'cross'
    end
    return 'slide'
end

-- 使用 gameWorld.platforms
function buildPlatformGraph()
    platformGraph = {}
    
    -- 检查 gameWorld 是否存在
    if not gameWorld or not gameWorld.platforms then 
        print("警告: gameWorld 或 platforms 不存在")
        return 
    end
    
    print(string.format("构建平台图 - 平台数量: %d", #gameWorld.platforms))
    
    -- 为每个平台创建节点
    for i, platform in ipairs(gameWorld.platforms) do
        local nodeCount = math.max(2, math.floor(platform.w / 60))
        for j = 1, nodeCount do
            local nodeX = platform.x + (platform.w / (nodeCount + 1)) * j
            local nodeY = platform.y - 5
            
            local node = {
                id = #platformGraph + 1,
                x = nodeX,
                y = nodeY,
                platform = i,
                edges = {}
            }
            table.insert(platformGraph, node)
        end
    end
    
    -- 构建边（连接）
    for i, nodeA in ipairs(platformGraph) do
        for j, nodeB in ipairs(platformGraph) do
            if i ~= j then
                local dx = nodeB.x - nodeA.x
                local dy = nodeB.y - nodeA.y
                local dist = math.sqrt(dx*dx + dy*dy)
                
                if nodeA.platform == nodeB.platform then
                    table.insert(nodeA.edges, {
                        to = nodeB.id,
                        cost = dist / 200,
                        action = "walk"
                    })
                else
                    if canJump(nodeA, nodeB) then
                        table.insert(nodeA.edges, {
                            to = nodeB.id,
                            cost = dist / 100,
                            action = "jump"
                        })
                    end
                    
                    if canFall(nodeA, nodeB) then
                        table.insert(nodeA.edges, {
                            to = nodeB.id,
                            cost = dist / 250,
                            action = "fall"
                        })
                    end
                end
            end
        end
    end
    
    print(string.format("平台图构建完成 - 节点数: %d", #platformGraph))
end

function canJump(from, to)
    local dx = math.abs(to.x - from.x)
    local dy = to.y - from.y
    
    if dy > 50 then return false end
    if dx > 200 then return false end
    if dy < -250 then return false end
    
    return true
end

function canFall(from, to)
    local dy = to.y - from.y
    if dy <= 0 then return false end
    
    local dx = math.abs(to.x - from.x)
    if dx > 100 then return false end
    
    return true
end

-- A* 寻路算法
function findPath(from, to)
    if #platformGraph == 0 then return {} end
    
    local startNode = findNearestNode(from.x + from.w/2, from.y + from.h)
    local goalNode = findNearestNode(to.x + to.w/2, to.y + to.h)
    
    if not startNode or not goalNode then return {} end
    
    local openSet = {startNode}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    
    for _, node in ipairs(platformGraph) do
        gScore[node.id] = math.huge
        fScore[node.id] = math.huge
    end
    
    gScore[startNode.id] = 0
    fScore[startNode.id] = heuristic(startNode, goalNode)
    
    while #openSet > 0 do
        local current = openSet[1]
        local currentIdx = 1
        for i, node in ipairs(openSet) do
            if fScore[node.id] < fScore[current.id] then
                current = node
                currentIdx = i
            end
        end
        
        if current.id == goalNode.id then
            return reconstructPath(cameFrom, current)
        end
        
        table.remove(openSet, currentIdx)
        
        for _, edge in ipairs(current.edges) do
            local neighbor = platformGraph[edge.to]
            local tentativeGScore = gScore[current.id] + edge.cost
            
            if tentativeGScore < gScore[neighbor.id] then
                cameFrom[neighbor.id] = {node = current, action = edge.action}
                gScore[neighbor.id] = tentativeGScore
                fScore[neighbor.id] = gScore[neighbor.id] + heuristic(neighbor, goalNode)
                
                local inOpenSet = false
                for _, n in ipairs(openSet) do
                    if n.id == neighbor.id then
                        inOpenSet = true
                        break
                    end
                end
                if not inOpenSet then
                    table.insert(openSet, neighbor)
                end
            end
        end
    end
    
    return {}
end

function findNearestNode(x, y)
    local nearest = nil
    local minDist = math.huge
    
    for _, node in ipairs(platformGraph) do
        local dx = node.x - x
        local dy = node.y - y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist < minDist then
            minDist = dist
            nearest = node
        end
    end
    
    return nearest
end

function heuristic(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx*dx + dy*dy) / 200
end

function reconstructPath(cameFrom, current)
    local path = {{x = current.x, y = current.y, action = "walk"}}
    
    while cameFrom[current.id] do
        local prev = cameFrom[current.id]
        current = prev.node
        table.insert(path, 1, {x = current.x, y = current.y, action = prev.action})
    end
    
    return path
end

-- 清空所有敌人
function enemy.clearAll()
    for i = #enemies, 1, -1 do
        if world then
            pcall(function() world:remove(enemies[i]) end)
        end
    end
    enemies = {}
    platformGraph = {}
    currentRoomId = nil
    print("清空所有敌人")
end

function enemy.damage(e, dmg)
    e.hp = e.hp - dmg
end

function enemy.getAll()
    return enemies
end

function enemy.drawAll()
    for _, e in ipairs(enemies) do
        love.graphics.setColor(e.color)
        love.graphics.rectangle('fill', e.x, e.y, e.w, e.h)
        
        love.graphics.setColor(1, 1, 1)
        local eyeX = e.x + e.w/2 + e.facing * 6
        love.graphics.circle('fill', eyeX, e.y + 12, 3)
        
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle('fill', e.x, e.y - 8, e.w, 3)
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle('fill', e.x, e.y - 8, e.w * (e.hp / e.maxHp), 3)
        
        -- 绘制路径（调试）
        if e.path and #e.path > 0 then
            love.graphics.setColor(1, 1, 0, 0.5)
            for i, node in ipairs(e.path) do
                love.graphics.circle('fill', node.x, node.y, 4)
                if i > 1 then
                    love.graphics.line(e.path[i-1].x, e.path[i-1].y, node.x, node.y)
                end
            end
        end
    end
end

function math.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

return enemy