-- enemy.lua
local enemy = {}

-- 依赖引用
local world         -- bump world
local gameWorld     -- 包含 platforms 数据
local player        -- 玩家对象
local enemies = {}
local platformGraph = {} -- 导航图
local currentRoomId = nil

-- 辅助函数
local function sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

-- 敌人类型定义
local enemyTypes = {
    chaser = {
        speed = 180,          -- 稍微降低速度，显得更自然
        jumpForce = 550,      -- 跳跃力度
        gravity = 1500,       -- 重力
        hp = 30,
        damage = 10,
        detectionRange = 500, -- 索敌范围
        attackRange = 40,     -- 攻击范围（近战）
        pathUpdateInterval = 0.5, -- 寻路更新频率
        width = 28,
        height = 40,
        color = {1, 0.3, 0.3}
    }
}

-- 初始化
function enemy.init(w, gw, pl)
    world = w
    gameWorld = gw
    player = pl
    enemies = {}
    platformGraph = {}
    currentRoomId = nil
end

-- 生成敌人
function enemy.spawn(x, y, typeKey)
    local template = enemyTypes[typeKey]
    if not template then return end

    local e = {
        x = x, y = y,
        w = template.width, h = template.height,
        vx = 0, vy = 0,
        
        -- 属性复制
        speed = template.speed,
        jumpForce = template.jumpForce,
        gravity = template.gravity,
        hp = template.hp,
        maxHp = template.hp,
        damage = template.damage,
        detectionRange = template.detectionRange,
        attackRange = template.attackRange,
        color = template.color,
        
        -- 状态控制
        type = typeKey,
        state = "idle", -- idle, chase, attack
        onGround = false,
        facing = 1,
        
        -- 寻路与AI
        path = {},
        pathIndex = 1,
        pathUpdateTimer = math.random() * template.pathUpdateInterval, -- 随机化初始时间，错峰计算
        pathUpdateInterval = template.pathUpdateInterval,
        
        -- 行为标志
        wantJump = false,
        stuckTimer = 0,     -- 用于检测是否卡住
        lastX = x,          -- 上一帧位置
        
        -- 攻击冷却
        attackCooldown = 0
    }

    table.insert(enemies, e)
    world:add(e, e.x, e.y, e.w, e.h)
    return e
end

-- 更新所有敌人
function enemy.updateAll(dt, roomId)
    -- 房间切换检测
    if currentRoomId ~= roomId then
        currentRoomId = roomId
        -- 传入 chaser 类型的参数作为参考来构建图（用于计算跳跃能力）
        enemy.buildPlatformGraph(enemyTypes.chaser)
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

-- 单个敌人更新逻辑
function updateEnemy(e, dt)
    -- 状态判断
    local dx = player.x - e.x
    local dy = player.y - e.y
    local distSq = dx*dx + dy*dy
    local dist = math.sqrt(distSq)

    -- 简单的状态机
    if dist < e.attackRange then
        e.state = "attack"
    elseif dist < e.detectionRange then
        e.state = "chase"
    else
        e.state = "idle"
    end

    -- 行为执行
    e.vx = 0 -- 默认每帧重置水平速度

    if e.state == "chase" then
        e.pathUpdateTimer = e.pathUpdateTimer + dt
        
        -- 定时更新路径
        if e.pathUpdateTimer >= e.pathUpdateInterval then
            e.pathUpdateTimer = 0
            -- 只有目标移动距离较大或自身卡住时才重新寻路，这里简化为定时
            e.path = findPath(e, player)
            e.pathIndex = 1
        end
        
        followPath(e, dt)
        
        -- 卡死检测：如果想动但位置没变
        if math.abs(e.x - e.lastX) < 0.5 and not e.onGround then
             -- 空中稍微卡住不计
        elseif math.abs(e.x - e.lastX) < 0.5 and #e.path > 0 then
            e.stuckTimer = e.stuckTimer + dt
            if e.stuckTimer > 0.5 then
                e.wantJump = true -- 尝试跳一下解围
                e.stuckTimer = 0
            end
        else
            e.stuckTimer = 0
        end
    elseif e.state == "attack" then
        -- 简单的攻击朝向
        e.facing = sign(player.x - e.x)
        if e.facing == 0 then e.facing = 1 end
        
        if e.attackCooldown <= 0 then
            -- 这里执行造成伤害的逻辑
            e.attackCooldown = 1.0
        end
    end

    if e.attackCooldown > 0 then
        e.attackCooldown = e.attackCooldown - dt
    end

    -- 施加物理分离力
    -- 防止敌人重叠成一个点
    for _, other in ipairs(enemies) do
        if other ~= e and math.abs(other.x - e.x) < e.w and math.abs(other.y - e.y) < e.h then
            local pushDir = sign(e.x - other.x)
            if pushDir == 0 then pushDir = math.random() > 0.5 and 1 or -1 end
            e.vx = e.vx + pushDir * 50 -- 施加排斥速度
        end
    end

    -- 物理积分
    -- 摩擦力/惯性处理
    -- followPath 中已经设置了 e.vx，这里可以做平滑处理，但为了响应性暂不添加惯性

    e.vy = e.vy + e.gravity * dt

    -- 跳跃处理
    if e.wantJump and e.onGround then
        e.vy = -e.jumpForce
        e.wantJump = false
        e.onGround = false
    end

    -- 5. 碰撞检测与移动
    local goalX = e.x + e.vx * dt
    local goalY = e.y + e.vy * dt

    local actualX, actualY, cols, len = world:move(e, goalX, goalY, enemyFilter)
    
    e.lastX = e.x -- 记录移动前位置用于卡死检测
    e.x, e.y = actualX, actualY

    -- 处理碰撞回调
    e.onGround = false
    for i = 1, len do
        local col = cols[i]
        if col.normal.y == -1 then
            e.onGround = true
            e.vy = 0
        elseif col.normal.y == 1 then
            e.vy = 0 -- 撞头
        end
    end
end

-- 改进后的路径跟随
function followPath(e, dt)
    if not e.path or #e.path == 0 then return end
    if e.pathIndex > #e.path then return end

    local targetNode = e.path[e.pathIndex]
    
    -- 目标点是节点中心
    local tx = targetNode.x
    local ty = targetNode.y -- 节点通常在平台表面

    local dx = tx - (e.x + e.w/2)
    -- 容差：如果是跳跃节点，需要更精确
    local tolerance = (targetNode.action == "jump") and 10 or 20

    -- 到达节点判断
    if math.abs(dx) < tolerance and math.abs((e.y + e.h) - ty) < 30 then
        e.pathIndex = e.pathIndex + 1
        if e.pathIndex > #e.path then return end
        targetNode = e.path[e.pathIndex] -- 更新目标
        
        -- 如果新目标需要跳跃，且我们现在在地面，立即起跳
        if targetNode.action == "jump" and e.onGround then
            e.wantJump = true
        end
    end

    -- 水平移动控制
    local moveDir = sign(targetNode.x - (e.x + e.w/2))
    if moveDir ~= 0 then
        e.vx = moveDir * e.speed
        e.facing = moveDir
    end
    
    -- 如果处于 Jump 动作段，但在空中，保持水平惯性朝向目标
    if targetNode.action == "jump" and not e.onGround then
        -- 空中控制力通常较弱，这里保持全速以便跳过坑
        e.vx = moveDir * e.speed
    end
end

-- 碰撞过滤器
function enemyFilter(item, other)
    if other == player then return 'cross' end -- 穿过玩家
    if other.type then return 'slide' end -- 遇到其他敌人滑行（结合分离力）
    return 'slide' -- 遇到墙壁滑行
end

--导航图构建
-- 检查一个物理配置能否完成跳跃
-- physics: {jumpForce, gravity, speed}
local function isJumpable(fromNode, toNode, physics)
    local dx = math.abs(toNode.x - fromNode.x)
    local dy = toNode.y - fromNode.y -- 负数表示向上

    -- 计算最大跳跃高度 H = v^2 / 2g
    local maxJumpHeight = (physics.jumpForce^2) / (2 * physics.gravity)
    
    -- 如果目标比最大高度还高，不可达
    if dy < -maxJumpHeight then return false end

    -- 估算跳跃所需时间
    -- 假设水平匀速运动
    local timeToReach = dx / physics.speed
    
    -- 在这段时间内，垂直方向能到达的高度 y = v0*t + 0.5*g*t^2
    -- 注意坐标系：dy是终点-起点。物理公式中向上为正，这里y向下为正。
    -- 公式转换为：dy = -jumpForce * t + 0.5 * gravity * t^2
    local heightAtDest = -physics.jumpForce * timeToReach + 0.5 * physics.gravity * (timeToReach^2)

    -- 如果计算出的位置低于目标位置（y值更大），说明跳不到那么高/远
    -- 加上一些宽容度 (tolerance)，比如敌人可以跳得更远一点点
    if heightAtDest > dy + 32 then -- +32 是允许脚部略微低于平台边缘
        return false 
    end

    return true
end

-- 检查是否可以直接走下（下落）
local function isFallable(fromNode, toNode)
    local dy = toNode.y - fromNode.y
    local dx = math.abs(toNode.x - fromNode.x)
    
    if dy <= 0 then return false end -- 目标在上方，不能通过走下到达
    if dx > 150 then return false end -- 水平距离太远，不是简单的下落
    return true
end

function enemy.buildPlatformGraph(physicsTemplate)
    platformGraph = {}
    if not gameWorld or not gameWorld.platforms then return end

    -- 生成节点
    -- 在平台的 左边缘、右边缘和中间生成节点
    for i, plat in ipairs(gameWorld.platforms) do
        local y = plat.y
        -- 左边缘
        table.insert(platformGraph, {id = #platformGraph+1, x = plat.x + 10, y = y, platIndex = i})
        -- 右边缘
        table.insert(platformGraph, {id = #platformGraph+1, x = plat.x + plat.w - 10, y = y, platIndex = i})
        
        -- 如果平台很宽，中间加几个点
        local w = plat.w
        if w > 200 then
            local steps = math.floor(w / 150)
            for k = 1, steps do
                table.insert(platformGraph, {
                    id = #platformGraph+1, 
                    x = plat.x + (w / (steps + 1)) * k, 
                    y = y, 
                    platIndex = i
                })
            end
        end
    end

    -- 生成边
    for _, nodeA in ipairs(platformGraph) do
        nodeA.edges = {}
        for _, nodeB in ipairs(platformGraph) do
            if nodeA.id ~= nodeB.id then
                local dist = math.sqrt((nodeA.x - nodeB.x)^2 + (nodeA.y - nodeB.y)^2)
                
                -- 同一平台行走连接
                if nodeA.platIndex == nodeB.platIndex then
                    -- 只有相邻或者没有障碍时才连接这里简化为必定连接
                    table.insert(nodeA.edges, { to = nodeB, cost = dist, action = "walk" })
                else
                    -- 不同平台：跳跃或下落连接
                    -- 距离太远直接忽略，优化性能
                    if dist < 400 then 
                        if isFallable(nodeA, nodeB) then
                            table.insert(nodeA.edges, { to = nodeB, cost = dist * 0.8, action = "fall" }) -- 下落代价较小
                        elseif isJumpable(nodeA, nodeB, physicsTemplate) then
                            table.insert(nodeA.edges, { to = nodeB, cost = dist * 1.5, action = "jump" }) -- 跳跃代价较大
                        end
                    end
                end
            end
        end
    end
    print("导航图构建完成，节点数: " .. #platformGraph)
end


-- A* 寻路
local function heuristic(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y) -- 曼哈顿距离通常更快
end

-- 寻找最近的导航节点
local function findNearestNode(x, y)
    local bestNode = nil
    local minDst = math.huge
    for _, node in ipairs(platformGraph) do
        local dx = node.x - x
        local dy = node.y - y
        -- 优先找当前位置下方的点（脚下的平台），忽略头顶太远的点
        if dy > -20 and dy < 100 then 
            local d = dx*dx + dy*dy
            if d < minDst then
                minDst = d
                bestNode = node
            end
        end
    end
    -- 如果没找到合适的，就找绝对距离最近的
    if not bestNode then
        minDst = math.huge
        for _, node in ipairs(platformGraph) do
            local d = (node.x - x)^2 + (node.y - y)^2
            if d < minDst then minDst = d; bestNode = node end
        end
    end
    return bestNode
end

function findPath(e, target)
    if #platformGraph == 0 then return {} end

    -- 敌人脚底中心
    local startNode = findNearestNode(e.x + e.w/2, e.y + e.h)
    -- 目标脚底中心
    local endNode = findNearestNode(target.x + target.w/2, target.y + target.h)

    if not startNode or not endNode then return {} end
    if startNode == endNode then return {} end

    local openSet = { startNode }
    local cameFrom = {}
    
    local gScore = {}
    local fScore = {}
    
    -- 初始化分数
    for _, n in ipairs(platformGraph) do 
        gScore[n.id] = math.huge 
        fScore[n.id] = math.huge 
    end
    
    gScore[startNode.id] = 0
    fScore[startNode.id] = heuristic(startNode, endNode)

    -- 简单的集合检查优化
    local inOpenSet = {[startNode.id] = true}

    while #openSet > 0 do
        -- 寻找 fScore 最小的节点
        local current = openSet[1]
        local lowestIndex = 1
        for i = 2, #openSet do
            if fScore[openSet[i].id] < fScore[current.id] then
                current = openSet[i]
                lowestIndex = i
            end
        end

        if current == endNode then
            -- 重建路径
            local path = {}
            local curr = current
            while cameFrom[curr.id] do
                local prevData = cameFrom[curr.id]
                -- 插入当前节点，并标记到达该节点需要的动作
                table.insert(path, 1, {
                    x = curr.x, 
                    y = curr.y, 
                    action = prevData.action
                })
                curr = prevData.node
            end
            -- 可以在路径最后加入目标真实坐标，但这通常需要在 followPath 里特殊处理
            return path
        end

        table.remove(openSet, lowestIndex)
        inOpenSet[current.id] = nil

        for _, edge in ipairs(current.edges) do
            local neighbor = edge.to
            local tentative_gScore = gScore[current.id] + edge.cost

            if tentative_gScore < gScore[neighbor.id] then
                cameFrom[neighbor.id] = { node = current, action = edge.action }
                gScore[neighbor.id] = tentative_gScore
                fScore[neighbor.id] = gScore[neighbor.id] + heuristic(neighbor, endNode)

                if not inOpenSet[neighbor.id] then
                    table.insert(openSet, neighbor)
                    inOpenSet[neighbor.id] = true
                end
            end
        end
    end

    return {} -- 没找到路径
end

-- 调试绘制
function enemy.drawAll()
    for _, e in ipairs(enemies) do
        love.graphics.setColor(e.color)
        love.graphics.rectangle('fill', e.x, e.y, e.w, e.h)
        
        -- 血条
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle('fill', e.x, e.y - 10, e.w, 4)
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle('fill', e.x, e.y - 10, e.w * (e.hp / e.maxHp), 4)

        -- 画路径
        if e.path and #e.path > 0 then
            love.graphics.setColor(1, 1, 0, 0.5)
            local lastX, lastY = e.x + e.w/2, e.y + e.h
            for _, p in ipairs(e.path) do
                love.graphics.line(lastX, lastY, p.x, p.y)
                love.graphics.circle('fill', p.x, p.y, 3)
                lastX, lastY = p.x, p.y
            end
        end
    end
    
    love.graphics.setColor(1,1,1,0.2)
    for _, n in ipairs(platformGraph) do
         love.graphics.circle('line', n.x, n.y, 2)
         for _, edge in ipairs(n.edges) do
             love.graphics.line(n.x, n.y, edge.to.x, edge.to.y)
         end
    end
end

function enemy.clearAll()
    for i = #enemies, 1, -1 do
        if world then world:remove(enemies[i]) end
    end
    enemies = {}
    platformGraph = {}
end

function enemy.damage(e, val)
    e.hp = e.hp - val
end

return enemy