-- src/input.lua
local json = require 'json'

local Input = {}
local keyMap = {}

-- 默认键位防止文件读取失败
local defaultKeys = {
    up = {"w", "up"},
    down = {"s", "down"},
    left = {"a", "left"},
    right = {"d", "right"},
    jump = {"space", "w"},
    dash = {"lshift"},
    attack = {"j", "z"},
    interact = {"e"},
    console = {"`"},
    quit = {"escape"}
}

function Input.load()
    if love.filesystem.getInfo("config/keysbind.json") then
        local content = love.filesystem.read("config/keysbind.json")
        keyMap = json.decode(content)
    else
        keyMap = defaultKeys
    end
    return keyMap
end

function Input.getMap()
    return keyMap
end

function Input.isDown(actionName)
    local bindings = keyMap[actionName]
    if not bindings then return false end
    for _, k in ipairs(bindings) do
        if love.keyboard.isDown(k) then return true end
    end
    return false
end

function Input.isPressed(actionName, key)
    local bindings = keyMap[actionName]
    if not bindings then return false end
    for _, k in ipairs(bindings) do
        if key == k then return true end
    end
    return false
end

return Input