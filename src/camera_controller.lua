-- src/camera_controller.lua
local CameraController = {}

local deadzone = { w = 300, h = 150 }

function CameraController.update(camera, player, dt)
    local camX, camY = camera.x, camera.y  
    local px = player.x + player.w/2
    local py = player.y + player.h/2

    local left   = camX - deadzone.w/2
    local right  = camX + deadzone.w/2
    local top    = camY - deadzone.h/2
    local bottom = camY + deadzone.h/2

    if px < left then camX = px + deadzone.w/2
    elseif px > right then camX = px - deadzone.w/2 end

    if py < top then camY = py + deadzone.h/2
    elseif py > bottom then camY = py - deadzone.h/2 end

    local smooth = 10
    camera.x = camera.x + (camX - camera.x) * smooth * dt
    camera.y = camera.y + (camY - camera.y) * smooth * dt

    camera:lookAt(camera.x, camera.y)
end

return CameraController