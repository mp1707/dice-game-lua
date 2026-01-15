-- Dice Game - Love2D
-- A roguelike Yahtzee game

local Theme = require("src.ui.theme")
local StateMachine = require("src.core.state_machine")
local GameState = require("src.game.game_state")

local stateMachine

function love.load()
    -- Pixel-perfect rendering
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Load theme assets (fonts, images)
    Theme:load()

    -- Initialize game state
    GameState:reset()

    -- Create state machine with lazy state loading
    stateMachine = StateMachine.new({
        play = function()
            return require("src.states.play_state").new()
        end,
        result = function()
            return require("src.states.result_state").new()
        end,
        shop = function()
            return require("src.states.shop_state").new()
        end,
    })

    -- Start with play state
    stateMachine:change("play", {
        stateMachine = stateMachine,
    })
end

function love.update(dt)
    stateMachine:update(dt)
end

function love.draw()
    -- Clear with background color
    love.graphics.clear(Theme.colors.bg)
    stateMachine:draw()
end

function love.mousepressed(x, y, button)
    stateMachine:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    stateMachine:mousereleased(x, y, button)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    stateMachine:keypressed(key)
end
