-- Prism Item Definition
local Trigger = require("src.items.trigger_types")
local GameState = require("src.game.game_state")
local Scoring = require("src.game.scoring")
local Sound = require("src.core.sound")

return {
    id = "prism",
    name = "Prism",
    description = "Scoring a straight turns the rightmost die prismatic for the rest of this round",
    buyPrice = 10,
    sellPrice = 3,
    sprite = "assets/icons/items/prism.png",
    rarity = "uncommon",

    triggers = {
        [Trigger.HAND_ACCEPTED] = function(context, itemInstance)
            -- context should contain: handId, scoringIndices, visualOrder
            local handId = context.handId
            local scoringIndices = context.scoringIndices
            local visualOrder = context.visualOrder

            if Scoring.isStraightHand(handId) then
                local rightmostIndex = Scoring.getRightmostScoringDieIndex(
                    scoringIndices,
                    visualOrder
                )

                if rightmostIndex and not GameState:isPrismatic(rightmostIndex) then
                    GameState:setPrismatic(rightmostIndex, true)
                    Sound:play("levelup")
                end
            end
        end
    }
}
