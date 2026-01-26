local Trigger = require("src.items.trigger_types")

return {
    id = "some_spice",
    name = "Some Spice",
    sprite = "assets/icons/items/chili.png",
    description = "+4 Mult",
    buyPrice = 4,
    triggers = {
        [Trigger.HAND_SCORED] = function(context, item, slotIndex)
            -- Apply effect
            context.mult = context.mult + 4

            -- Queue visual effect
            if context.triggeredEffects then
                table.insert(context.triggeredEffects, {
                    slotIndex = slotIndex,
                    text = "+4",
                    color = "red", -- Corresponds to mult color
                    multMod = 4
                    -- sound can be default or specific
                })
            end
        end
    }
}
