-- src/menu.lua
local Menu = {
    state = "main", -- main, weapon_select, settings
    selectedIndex = 1,
    weapons = {"sword", "spear", "bow", "hammer"},
    weaponDescriptions = {
        sword = "平衡型武器,适合新手",
        spear = "远程近战,攻击范围大",
        bow = "远程射击,风筝流",
        hammer = "重型武器,高伤害慢攻速"
    }
}

local screenWidth, screenHeight = 800, 600
local optionStartY = 200
local optionSpacing = 50
local weaponStartY = 150
local weaponSpacing = 80
local optionHeight = 40 -- 点击检测用的选项高度

function Menu.draw()
    if Menu.state == "main" then
        Menu.drawMainMenu()
    elseif Menu.state == "weapon_select" then
        Menu.drawWeaponSelect()
    end
end

function Menu.drawMainMenu()
    local options = {"开始游戏", "设置", "退出"}
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Dead Calls", 0, 100, screenWidth, "center")
    
    for i, option in ipairs(options) do
        local color = (i == Menu.selectedIndex) and {1, 1, 0} or {1, 1, 1}
        love.graphics.setColor(color)
        love.graphics.printf(option, 0, optionStartY + i * optionSpacing, screenWidth, "center")
    end
end

function Menu.drawWeaponSelect()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("选择你的武器", 0, 50, screenWidth, "center")
    
    for i, weapon in ipairs(Menu.weapons) do
        local Weapons = require('src.weapons')
        local w = Weapons.list[weapon]
        local color = (i == Menu.selectedIndex) and {1, 1, 0} or {1, 1, 1}
        love.graphics.setColor(color)
        love.graphics.printf(w.name, 0, weaponStartY + i * weaponSpacing, screenWidth, "center")
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf(w.describe, 0, weaponStartY + 20 + i * weaponSpacing, screenWidth, "center")
    end
end

-- 鼠标点击检测
function Menu.mousepressed(x, y, button)
    if button ~= 1 then return nil end -- 只响应左键
    if Menu.state == "main" then
        local options = {"开始游戏", "设置", "退出"}
        for i, option in ipairs(options) do
            local top = optionStartY + i * optionSpacing
            local bottom = top + optionHeight
            if y >= top and y <= bottom then
                Menu.selectedIndex = i
                if i == 1 then
                    Menu.state = "weapon_select"
                    Menu.selectedIndex = 1
                elseif i == 3 then
                    love.event.quit()
                end
                return nil
            end
        end
    elseif Menu.state == "weapon_select" then
        for i, weapon in ipairs(Menu.weapons) do
            local top = weaponStartY + i * weaponSpacing
            local bottom = top + optionHeight
            if y >= top and y <= bottom then
                Menu.selectedIndex = i
                return Menu.weapons[i] -- 返回选择的武器
            end
        end
    end
    return nil
end

-- 鼠标移动检测（悬停高亮）
function Menu.mousemoved(x, y)
    if Menu.state == "main" then
        local options = {"开始游戏", "设置", "退出"}
        for i, option in ipairs(options) do
            local top = optionStartY + i * optionSpacing
            local bottom = top + optionHeight
            if y >= top and y <= bottom then
                Menu.selectedIndex = i
                return
            end
        end
    elseif Menu.state == "weapon_select" then
        for i, weapon in ipairs(Menu.weapons) do
            local top = weaponStartY + i * weaponSpacing
            local bottom = top + optionHeight
            if y >= top and y <= bottom then
                Menu.selectedIndex = i
                return
            end
        end
    end
end

return Menu
