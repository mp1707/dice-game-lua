-- Dice Game - Love2D
-- A roguelike Yahtzee game with Balatro-style desktop UI

local Theme = require("src.ui.theme")
local StateMachine = require("src.core.state_machine")
local GameState = require("src.game.game_state")
local HotReload = require("src.core.hot_reload")

local stateMachine

-- Scaling state
local Scaling = {
    canvas = nil,
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    initialized = false,
    showDebug = false,
}

-- Calculate scaling to fit window while maintaining aspect ratio
local function calculateScale()
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
local function screenToGame(screenX, screenY)
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

_G.screenToGame = screenToGame

-- Hot reload callbacks
HotReload.getState = function()
    return {
        currentLevel = GameState.currentLevel,
        money = GameState.money,
        currentScore = GameState.currentScore,
        handsRemaining = GameState.handsRemaining,
        rollsRemaining = GameState.rollsRemaining,
        hasRolledThisHand = GameState.hasRolledThisHand,
        dice = GameState.dice,
        usedHands = GameState.usedHands,
        selectedHandId = GameState.selectedHandId,
        isRolling = GameState.isRolling,
    }
end

HotReload.setState = function(state)
    for k, v in pairs(state) do
        GameState[k] = v
    end
end

HotReload.onReload = function()
    Theme = require("src.ui.theme")
    GameState = require("src.game.game_state")
    StateMachine = require("src.core.state_machine")
    love.load()
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    Theme:load()

    Scaling.canvas = love.graphics.newCanvas(Theme.screen.width, Theme.screen.height)
    Scaling.canvas:setFilter("nearest", "nearest")

    calculateScale()
    Scaling.initialized = true

    GameState:reset()

    stateMachine = StateMachine.new({
        play = function() return require("src.states.play_state").new() end,
        result = function() return require("src.states.result_state").new() end,
        shop = function() return require("src.states.shop_state").new() end,
    })

    stateMachine:change("play", { stateMachine = stateMachine })
end

function love.resize(w, h)
    calculateScale()
end

function love.update(dt)
    HotReload:update(dt)
    stateMachine:update(dt)
end

function love.draw()
    -- Render to canvas
    love.graphics.setCanvas(Scaling.canvas)
    love.graphics.clear(Theme.colors.bg)
    stateMachine:draw()
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

    -- Hot reload notification
    love.graphics.setFont(Theme.fonts.normal)
    HotReload:draw()

    -- Debug overlay
    if Scaling.showDebug then
        local mx, my = love.mouse.getPosition()
        local vx, vy = screenToGame(mx, my)
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
end

function love.mousepressed(x, y, button)
    local gameX, gameY = screenToGame(x, y)
    if gameX and gameY then
        stateMachine:mousepressed(gameX, gameY, button)
    end
end

function love.mousereleased(x, y, button)
    local gameX, gameY = screenToGame(x, y)
    if gameX and gameY then
        stateMachine:mousereleased(gameX, gameY, button)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        HotReload:reload()
    elseif key == "f3" then
        Scaling.showDebug = not Scaling.showDebug
    elseif key == "f10" then
        love.window.setFullscreen(not love.window.getFullscreen())
    end
    stateMachine:keypressed(key)
end
