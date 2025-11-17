-- console.lua
local console = {
    isOpen = false,
    input = "",
    history = {},
    registry = {},
    deps = {}
}

-- 初始化依赖
function console.init(dependencies)
    console.deps = dependencies
end

-- 注册命令
function console.register(name, fn)
    console.registry[name] = fn
end

-- 打印信息到控制台
function console.print(text)
    table.insert(console.history, text)
end

-- 执行命令
function console.execute(line)
    table.insert(console.history, "> " .. line)

    local args = {}
    for word in line:gmatch("%S+") do
        table.insert(args, word)
    end

    if #args == 0 then return end

    local cmd = args[1]
    table.remove(args, 1)

    local fn = console.registry[cmd]
    if fn then
        local ok, err = pcall(fn, args)
        if not ok then
            console.print("错误: " .. tostring(err))
        end
    else
        console.print("未知命令: " .. cmd)
    end
end

-- Love2D 输入
function console.keypressed(key)
    if key == "return" then
        console.execute(console.input)
        console.input = ""
        return
    end
    if key == "backspace" then
        console.input = console.input:sub(1, -2)
        return
    end
end

function console.textinput(t)
    console.input = console.input .. t
end

-- 绘制控制台
function console.draw()
    if not console.isOpen then return end

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 200)

    love.graphics.setColor(1, 1, 1)
    local y = 10
    for i = math.max(1, #console.history - 5), #console.history do
        love.graphics.print(console.history[i], 10, y)
        y = y + 20
    end

    -- 输入栏
    love.graphics.print("> " .. console.input .. "_", 10, 180)
end

-- 注册命令
console.register("summon", function(args)
    local player = console.deps.player
    local enemy = console.deps.enemy
    
    if not enemy then
        console.print("错误: enemy 模块未加载")
        return
    end
    
    local x = tonumber(args[1]) or player.x
    local y = tonumber(args[2]) or player.y
    local type = args[3] or "chaser"
    enemy.spawn(x, y, type)
    console.print("已在(" .. x .. ", " .. y .. ")生成敌人")
end)

console.register("god", function(args)
    local player = console.deps.player
    player.maxHp = 999999
    player.hp = 999999
    console.print("上帝模式已启用")
end)

console.register("tp", function(args)
    local player = console.deps.player
    local bumpworld = console.deps.bumpworld
    
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    if x and y then
        player.x = x
        player.y = y
        bumpworld:update(player, x, y)
        console.print("已传送至(" .. x .. ", " .. y .. ")")
    else
        console.print("用法: tp <x> <y>")
    end
end)

console.register("help", function(args)
    console.print("可用命令:")
    console.print("  summon [x] [y] [type]")
    console.print("  god - 无敌模式")
    console.print("  tp <x> <y> - 传送")
    console.print("  help - 显示帮助")
end)

return console