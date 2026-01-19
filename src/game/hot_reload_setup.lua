local HotReload = require("src.core.hot_reload")
local GameState = require("src.game.game_state")

local HotReloadSetup = {}

function HotReloadSetup.init()
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
end

return HotReloadSetup
