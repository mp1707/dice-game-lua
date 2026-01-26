local Trigger = require("src.items.trigger_types")
local Scoring = require("src.game.scoring")

return {
    id = "first_aid",
    name = "First Aid",
    sprite = "assets/icons/items/medikit.png",
    description = "+10 Mult if a number hand is played",
    buyPrice = 6,
    triggers = {
        [Trigger.HAND_SCORED] = function(context, item, slotIndex)
            -- Check condition: Number hand (Upper Section)
            if Scoring.isUpperSectionHand(context.handId) then
                -- Apply effect
                context.mult = context.mult + 10

                -- Queue visual effect
                if context.triggeredEffects then
                    table.insert(context.triggeredEffects, {
                        slotIndex = slotIndex,
                        text = "+10",
                        color = "red",
                        multMod = 10
                    })
                end
            end
        end
    }
}
