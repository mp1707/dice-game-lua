-- Dice Game - Love2D
-- A roguelike Yahtzee game with Balatro-style desktop UI
-- Main entry point

local HotReload = require("src.core.hot_reload")
local HotReloadSetup = require("src.game.hot_reload_setup")

-- These will be (re)loaded in love.load
local Theme
local StateMachine
local GameState
local Scaling
local Sound
local stateMachine

function love.load()
    -- Set default filter for pixel art
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- (Re)Load modules to support hot reloading
    Theme = require("src.ui.theme")
    StateMachine = require("src.core.state_machine")
    GameState = require("src.game.game_state")
    Scaling = require("src.core.scaling")
    Sound = require("src.core.sound")

    -- Initialize systems
    Theme:load()
    Scaling.init()
    HotReloadSetup.init()
    HotReload.onReload = function() love.load() end

    -- Initialize Game State
    GameState:reset()

    -- Start background music
    love.audio.stop() -- Stop any previous audio (e.g. from hot reload)
    Sound:startMusic()

    -- Initialize State Machine
    stateMachine = StateMachine.new({
        play = function() return require("src.states.play_state").new() end,
        result = function() return require("src.states.result_state").new() end,
        shop = function() return require("src.states.shop_state").new() end,
    })

    stateMachine:change("play", { stateMachine = stateMachine })
end

function love.resize(w, h)
    Scaling.resize(w, h)
end

function love.update(dt)
    HotReload:update(dt)
    Scaling.updateShader(dt)
    stateMachine:update(dt)
end

function love.draw()
    Scaling.draw(function()
        stateMachine:draw()
    end)

    -- Hot reload notification
    love.graphics.setFont(Theme.fonts.normal)
    HotReload:draw()
end

function love.mousepressed(x, y, button)
    local gameX, gameY = Scaling.screenToGame(x, y)
    if gameX and gameY then
        stateMachine:mousepressed(gameX, gameY, button)
    end
end

function love.mousereleased(x, y, button)
    local gameX, gameY = Scaling.screenToGame(x, y)
    if gameX and gameY then
        stateMachine:mousereleased(gameX, gameY, button)
    end
end

function love.mousemoved(x, y)
    local gameX, gameY = Scaling.screenToGame(x, y)
    if gameX and gameY then
        stateMachine:mousemoved(gameX, gameY)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        HotReload:reload()
    elseif key == "f3" then
        Scaling.toggleDebug()
    elseif key == "f10" then
        love.window.setFullscreen(not love.window.getFullscreen())
    end
    stateMachine:keypressed(key)
end
