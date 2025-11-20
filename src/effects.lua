local Effects = {}

local trails = {}    -- 拖尾对象
local particles = {} -- 简单粒子对象

local dashGhostCD = 0
Effects.dashGhostInterval = 0.03  -- 玩家冲刺残影生成间隔

--[[
type:
    "ghost" = 残影（复制贴图）
    "line" = 白线（速度轨迹）
        config:
    life     = 生存时间
    size     = 白线长度
    alpha    = 初始透明度
    img      = 贴图（ghost 用）
    facing   = 翻转
]]
function Effects.addTrail(x, y, type, config)
    config = config or {}

    table.insert(trails, {
        x = x,
        y = y,
        type = type,
        life = config.life or 0.3,
        maxLife = config.life or 0.3,
        size = config.size or 40,
        alpha = config.alpha or 1.0,
        img = config.img,
        facing = config.facing or 1,
    })
end

function Effects.emit(x, y, count, config)
    for i = 1, count do
        table.insert(particles, {
            x = x + math.random(-10, 10),
            y = y + math.random(-10, 10),
            vx = math.random(-100, 100),
            vy = math.random(-200, -50),
            life = config.life or 0.5,
            color = config.color or {1, 1, 1},
            size = config.size or 4,
        })
    end
end

function Effects.update(dt)
    -- 拖尾
    for i = #trails, 1, -1 do
        local t = trails[i]
        t.life = t.life - dt
        if t.life <= 0 then
            table.remove(trails, i)
        end
    end

    -- 粒子
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 500 * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

function Effects.draw()
    love.graphics.setColor(1,1,1)

    -- 拖尾
    for _, t in ipairs(trails) do
        local alpha = (t.life / t.maxLife) * t.alpha

        if t.type == "line" then
            -- 白色风线
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.rectangle("fill", t.x - t.size/2, t.y, t.size, 4)

        elseif t.type == "ghost" and t.img then
            -- 残影（复制贴图）
            love.graphics.setColor(1, 1, 1, alpha)

            local ox = t.img:getWidth() / 2
            local oy = t.img:getHeight() / 2

            love.graphics.draw(
                t.img,
                t.x, t.y,
                0,
                t.facing == 1 and 1 or -1,
                1,
                ox, oy
            )
        end
    end

    -- 粒子绘制
    for _, p in ipairs(particles) do
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.life)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end

    love.graphics.setColor(1,1,1)
end

return Effects
