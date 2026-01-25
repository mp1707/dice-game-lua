-- Trigger System
-- Handles dispatching events to items (relics) that subscribe to triggers

local ItemRegistry = require("src.items.item_registry")
local GameState = require("src.game.game_state")

local TriggerSystem = {}

-- Initialize the system
function TriggerSystem:init()
    -- Nothing to init yet
end

-- Emit a trigger with context
-- Scans player's relics and executes matching triggers
function TriggerSystem:emit(trigger, context)
    context = context or {}

    -- Iterate over all relics currently owned by the player
    -- GameState.relics is a list of tables: { {relicId="prism"}, ... }
    for i, relicInstance in ipairs(GameState.relics) do
        local def = ItemRegistry:get(relicInstance.relicId)

        if def and def.triggers and def.triggers[trigger] then
            local handler = def.triggers[trigger]

            -- Structure: handler can be a function OR a table { condition=..., action=... }
            if type(handler) == "function" then
                handler(context, relicInstance)
            elseif type(handler) == "table" then
                local conditionMet = true
                if handler.condition then
                    conditionMet = handler.condition(context, relicInstance)
                end

                if conditionMet and handler.action then
                    handler.action(context, relicInstance)
                end
            end
        end
    end
end

return TriggerSystem
