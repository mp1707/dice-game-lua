function love.conf(t)
    t.identity = "dice-game"
    t.version = "11.4"

    t.window.title = "Dice Game"
    t.window.width = 400
    t.window.height = 700
    t.window.resizable = false
    t.window.vsync = 1
    t.window.minwidth = 400
    t.window.minheight = 700

    -- Disable unused modules
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false

    -- Enable needed modules
    t.modules.audio = true
    t.modules.graphics = true
    t.modules.window = true
    t.modules.timer = true
    t.modules.keyboard = true
    t.modules.mouse = true
    t.modules.sound = true
    t.modules.font = true
    t.modules.image = true
end
