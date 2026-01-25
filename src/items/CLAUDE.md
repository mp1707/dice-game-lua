# Item Trigger System

The Item Trigger System provides a structured way to handle relic/item effects at specific points in the game loop.

## Structure

- `src/items/trigger_types.lua`: Defines valid trigger points (e.g., `LEVEL_START`, `HAND_ACCEPTED`).
- `src/items/item_registry.lua`: Manages item definitions loaded from `src/items/definitions/`.
- `src/items/trigger_system.lua`: Singleton that dispatches events to owned relics.
- `src/items/definitions/`: Contains Lua files for each item definition.

## Adding a New Item

1.  Create a new file in `src/items/definitions/` (e.g., `my_item.lua`).
2.  Define the item properties (id, name, sprites) and triggers:

```lua
local Trigger = require("src.items.trigger_types")

return {
    id = "my_item",
    name = "My Item",
    -- ...
    triggers = {
        [Trigger.HAND_ACCEPTED] = function(context, itemInstance)
            -- Your logic here
        end
    }
}
```

3.  Register the new item in `src/game/relics.lua` by adding its module path to the `modules` table.

## Triggers

See `src/items/trigger_types.lua` for the full list of triggers.

Common Triggers:

- `HAND_ACCEPTED`: Triggered when a hand is scored. Context includes `handId`, `scoringIndices`, and `visualOrder`.
- `LEVEL_START`: Triggered when a new level begins.
- `SHOP_ENTER`: Triggered when entering the shop.

## Usage

In Game Logic, emit triggers using the `TriggerSystem`:

```lua
local TriggerSystem = require("src.items.trigger_system")
local Trigger = require("src.items.trigger_types")

TriggerSystem:emit(Trigger.HAND_ACCEPTED, {
    handId = handId,
    scoringIndices = scoringIndices,
    -- ...
})
```
