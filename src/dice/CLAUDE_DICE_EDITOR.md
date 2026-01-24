# Dice Editor System Documentation

The Dice Editor system allows players to customize their dice faces using consumable "Stickers". This is the core roguelike mechanic that transforms dice into a customizable "deck".

## Overview

- **5 Dice as "Deck"**: Each die has 6 customizable faces
- **Stickers**: Consumable items that replace die faces (buy $8, sell $2)
- **2 Consumable Slots**: Slots 6-7 in the item strip hold stickers
- **Tactical Usage**: Stickers can be used in shop OR mid-game for strategic advantage

## Architecture

### Data Structures

#### GameState.dice (Extended)
```lua
dice[i] = {
    value = 1,              -- Current rolled value
    locked = false,         -- Selection state
    faces = {1,2,3,4,5,6},  -- 6 face values (customizable)
    rolledFaceIndex = nil,  -- Which face position was rolled
}
```

#### GameState.consumables
```lua
consumables = {nil, nil}  -- 2 consumable slots
-- Each slot contains: { stickerId = "basic_6" }
```

### File Structure

```
src/game/
  stickers.lua          -- Sticker definitions registry

src/ui/
  consumable_slot.lua   -- Individual consumable slot component
  dice_tooltip.lua      -- Horizontal face tooltip on hover
  dice_editor.lua       -- Editor mode controller (singleton)
  drag_zones.lua        -- DELETE/SELL drop zones (singleton)
  item_strip.lua        -- Modified to include consumable slots 6-7
```

## Key Components

### Stickers Registry (`src/game/stickers.lua`)

Defines all sticker types. Currently includes basic 1-6 face stickers.

```lua
Stickers:get(stickerId)       -- Get sticker definition
Stickers:getValue(stickerId)   -- Get face value
Stickers:getBuyPrice(stickerId)
Stickers:getSellPrice(stickerId)
Stickers:getRandomIds(count)   -- For shop generation
```

#### Sticker Definition Format
```lua
{
    id = "basic_6",
    name = "Six",
    description = "Replace a face with 6",
    faceValue = 6,
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 6,  -- Uses existing die face sprites
    rarity = "common",
}
```

### Consumable Slot (`src/ui/consumable_slot.lua`)

Renders a sticker in the item strip with:
- Click to show USE/SELL buttons
- Drag support for DELETE/SELL zones
- Spring animation on hover/click

### Dice Tooltip (`src/ui/dice_tooltip.lua`)

Shows all 6 faces of a die in a horizontal row:
- Appears after 1 second hover (0.3s in editor mode)
- Shows actual values at each face position
- Clickable faces in editor mode

```
[Face1] [Face2] [Face3] [Face4] [Face5] [Face6]
```

### Dice Editor (`src/ui/dice_editor.lua`)

Singleton that manages the face replacement flow:

```lua
local editor = DiceEditor.getInstance()
editor:activate(context, consumableIndex, callbacks)
editor:deactivate()
editor:selectDie(dieIndex)
editor:confirmReplacement()
```

**States:**
1. **Inactive**: Normal gameplay
2. **Active**: Dimmed overlay, dice highlighted
3. **Die Selected**: Tooltip showing all faces
4. **Face Selected**: Confirmation modal

### Drag Zones (`src/ui/drag_zones.lua`)

Shows DELETE (bottom-right) and SELL (top-middle) zones when dragging:
- DELETE: Removes consumable without money
- SELL: Returns sell price ($2)

## Usage Flow

### In Shop
1. Player buys sticker ($8) from shop
2. Sticker goes to consumable slot (6 or 7)
3. Click slot -> USE/SELL buttons appear
4. Click USE -> Editor mode activates
5. Dice appear, click a die
6. Tooltip shows all 6 faces
7. Click a face to replace
8. Confirmation modal -> Confirm
9. Face replaced, consumable removed
10. Return to shop

### In Gameplay
1. Player clicks consumable slot
2. USE button appears, click USE
3. Everything dims except dice
4. Same flow as shop (select die, select face, confirm)
5. Strategic advantage: Change face mid-roll!

## GameState Methods

### Consumables
```lua
GameState:addConsumable(stickerId)     -- Returns slot index or nil
GameState:removeConsumable(index)       -- Returns removed data
GameState:getConsumable(index)          -- Get consumable at slot
GameState:hasConsumableRoom()           -- Check if slot available
```

### Dice Faces
```lua
GameState:setDieFace(dieIndex, faceIndex, value)
GameState:getDieFaces(dieIndex)         -- Returns array of 6 values
GameState:getDieFace(dieIndex, faceIndex)
```

### Editor Mode
```lua
GameState:enterEditorMode(consumableIndex)
GameState:exitEditorMode()
GameState:isInEditorMode()
GameState:getActiveSticker()
```

## Rolling with Custom Faces

The `rollDice()` function now selects from the `faces` array:

```lua
local faceIndex = math.random(1, 6)
die.rolledFaceIndex = faceIndex
die.value = die.faces[faceIndex]  -- Uses custom face value
```

## Extending the System

### Adding New Sticker Types

1. Add definition in `src/game/stickers.lua`:
```lua
register({
    id = "golden_6",
    name = "Golden Six",
    description = "Worth bonus points",
    faceValue = 6,
    bonusPoints = 5,  -- Future: scoring integration
    buyPrice = 15,
    sellPrice = 4,
    spriteId = 6,
    rarity = "rare",
})
```

2. For special sprites, create sticker spritesheet and reference in Theme

3. For bonus scoring effects, modify `src/game/scoring.lua`

### Future Enhancements

- **Special Stickers**: Wild faces, multiplier faces, skull faces
- **Sticker Upgrades**: Level up stickers for more power
- **Face Locking**: Prevent certain faces from being modified
- **Sticker Sets**: Bonuses for matching sticker themes
- **Visual Effects**: Custom sprites and animations per sticker type

## Persistence

Custom faces persist across:
- Hands within a level
- Levels within a run
- Hot reload (R key)

Reset on new run (`GameState:reset()`).
