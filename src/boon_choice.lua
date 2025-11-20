-- src/boon_choice.lua
local BoonChoice = {}
local Boons = require 'src.boons'

BoonChoice.hoverIndex = nil
BoonChoice.isActive = false
BoonChoice.options = {}

-- 稀有度颜色
local rarityColors = {
    common = {0.8, 0.8, 0.8},
    rare = {0.3, 0.6, 1},
    epic = {0.8, 0.2, 1},
    devil = {0.9, 0.1, 0.1},  -- 恶魔专属红色
}

function BoonChoice.show()
    BoonChoice.isActive = true
    BoonChoice.options = Boons.getRandomSelection(3)
end

function BoonChoice.draw()
    if not BoonChoice.isActive then return end
    
    -- 半透明背景
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- 标题
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("命运的轮盘在转动...", 0, 80, love.graphics.getWidth(), 'center')
    
    -- 绘制三张卡牌
    local cardWidth = 220
    local cardHeight = 300
    local spacing = 40
    local startX = (love.graphics.getWidth() - (cardWidth * 3 + spacing * 2)) / 2
    local startY = 150
    
    for i, boonName in ipairs(BoonChoice.options) do
        local boon = Boons.list[boonName]
        local x = startX + (i - 1) * (cardWidth + spacing)
        local y = startY

        -- 是否悬停
        local isHover = (BoonChoice.hoverIndex == i)

        -- 稀有度颜色
        local color = rarityColors[boon.rarity] or {0.5, 0.5, 0.5}

        -- 背景亮度
        local brightness = isHover and 0.45 or 0.3
        love.graphics.setColor(color[1] * brightness, color[2] * brightness, color[3] * brightness)
        love.graphics.rectangle('fill', x, y, cardWidth, cardHeight, 10)

        -- 边框（悬停变粗）
        love.graphics.setColor(color)
        love.graphics.setLineWidth(isHover and 5 or 3)
        love.graphics.rectangle('line', x, y, cardWidth, cardHeight, 10)
        love.graphics.setLineWidth(1)

        -- 稀有度标记
        love.graphics.setColor(color)
        love.graphics.printf(boon.rarity:upper(), x, y + 10, cardWidth, 'center')

        -- 名称
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(boon.name, x + 10, y + 40, cardWidth - 20, 'center')

        -- 描述
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.printf(boon.desc, x + 10, y + 100, cardWidth - 20, 'center')

        -- 按键提示
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("按 " .. i, x, y + cardHeight - 30, cardWidth, 'center')

        -- 恶魔卡特殊提示
        if boon.rarity == "devil" then
            love.graphics.setColor(1, 0, 0)
            love.graphics.printf("恶魔交易", x, y + cardHeight - 60, cardWidth, 'center')
        end
    end
    -- 底部提示
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("选择你的命运", 0, startY + cardHeight + 40, love.graphics.getWidth(), 'center')
end

function BoonChoice.keypressed(key, player)
    if not BoonChoice.isActive then return end
    
    local num = tonumber(key)
    if num and num >= 1 and num <= #BoonChoice.options then
        local boonName = BoonChoice.options[num]
        Boons.grant(player, boonName)
        BoonChoice.isActive = false
    end
end

function BoonChoice.mousemoved(x, y)
    if not BoonChoice.isActive then return end

    BoonChoice.hoverIndex = nil

    local cardWidth = 220
    local cardHeight = 300
    local spacing = 40
    local startX = (love.graphics.getWidth() - (cardWidth * 3 + spacing * 2)) / 2
    local startY = 150

    for i = 1, #BoonChoice.options do
        local cx = startX + (i - 1) * (cardWidth + spacing)
        local cy = startY

        if x >= cx and x <= cx + cardWidth and y >= cy and y <= cy + cardHeight then
            BoonChoice.hoverIndex = i
            return
        end
    end
end

function BoonChoice.mousepressed(x, y, button, player)
    if not BoonChoice.isActive or button ~= 1 then return end

    if BoonChoice.hoverIndex then
        local boonName = BoonChoice.options[BoonChoice.hoverIndex]
        Boons.grant(player, boonName)
        BoonChoice.isActive = false
    end
end

return BoonChoice