local Theme = require("src.ui.theme")

---@class Scaling
local Scaling = {
    ---@type table|nil Canvas object (from love.graphics.newCanvas)
    canvas = nil,
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    initialized = false,
    showDebug = false,
}

-- Calculate scaling to fit window while maintaining aspect ratio
function Scaling.calculateScale()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local baseWidth = Theme.screen.width
    local baseHeight = Theme.screen.height

    local scaleX = windowWidth / baseWidth
    local scaleY = windowHeight / baseHeight
    Scaling.scale = math.min(scaleX, scaleY)

    if Scaling.scale <= 0 then Scaling.scale = 1 end

    local scaledWidth = baseWidth * Scaling.scale
    local scaledHeight = baseHeight * Scaling.scale
    Scaling.offsetX = (windowWidth - scaledWidth) / 2
    Scaling.offsetY = (windowHeight - scaledHeight) / 2
end

-- Convert screen coordinates to game coordinates
function Scaling.screenToGame(screenX, screenY)
    if not Scaling.initialized then
        return screenX or 0, screenY or 0
    end
    local gameX = ((screenX or 0) - Scaling.offsetX) / Scaling.scale
    local gameY = ((screenY or 0) - Scaling.offsetY) / Scaling.scale

    local baseWidth = Theme.screen.width
    local baseHeight = Theme.screen.height
    if gameX < 0 or gameX >= baseWidth or gameY < 0 or gameY >= baseHeight then
        return nil, nil
    end

    return gameX, gameY
end

function Scaling.init()
    Scaling.canvas = love.graphics.newCanvas(Theme.screen.width, Theme.screen.height)
    Scaling.canvas:setFilter("nearest", "nearest")

    Scaling.calculateScale()
    Scaling.initialized = true

    -- Expose to global for convenience if needed, or better yet, modules should require this file.
    _G.screenToGame = Scaling.screenToGame
end

function Scaling.resize(w, h)
    Scaling.calculateScale()
end

function Scaling.toggleDebug()
    Scaling.showDebug = not Scaling.showDebug
end

---Draw the game content scaled to the window
---@param drawCallback function The function that draws the actual game content
function Scaling.draw(drawCallback)
    -- Render to canvas
    love.graphics.setCanvas(Scaling.canvas)
    love.graphics.clear(Theme.colors.bg)

    if drawCallback then
        drawCallback()
    end

    love.graphics.setCanvas()

    -- Draw scaled canvas
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Scaling.canvas, Scaling.offsetX, Scaling.offsetY, 0, Scaling.scale, Scaling.scale)

    -- Letterboxing
    love.graphics.setColor(0, 0, 0, 1)
    if Scaling.offsetX > 0 then
        love.graphics.rectangle("fill", 0, 0, Scaling.offsetX, love.graphics.getHeight())
        love.graphics.rectangle("fill", love.graphics.getWidth() - Scaling.offsetX, 0, Scaling.offsetX,
            love.graphics.getHeight())
    end
    if Scaling.offsetY > 0 then
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), Scaling.offsetY)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight() - Scaling.offsetY, love.graphics.getWidth(),
            Scaling.offsetY)
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- Debug overlay
    if Scaling.showDebug then
        Scaling.drawDebug()
    end
end

function Scaling.drawDebug()
    local mx, my = love.mouse.getPosition()
    local vx, vy = Scaling.screenToGame(mx, my)
    local inViewport = vx ~= nil

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 280, 130)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.print("=== DEBUG (F3 to hide) ===", 20, 20)
    love.graphics.print(string.format("Window: %dx%d", love.graphics.getWidth(), love.graphics.getHeight()), 20, 40)
    love.graphics.print(string.format("Virtual: %dx%d", Theme.screen.width, Theme.screen.height), 20, 60)
    love.graphics.print(string.format("Scale: %.2f", Scaling.scale), 20, 80)
    love.graphics.print(string.format("Offset: %.0f, %.0f", Scaling.offsetX, Scaling.offsetY), 20, 100)
    if inViewport then
        love.graphics.setColor(0.3, 1, 0.3, 1)
        love.graphics.print(string.format("Mouse: %.0f, %.0f (in viewport)", vx, vy), 20, 120)
    else
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.print("Mouse: outside viewport", 20, 120)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Scaling
