# Sticker System Documentation

The sticker system is the core roguelike customization mechanic. Players buy stickers from the shop and apply them to dice faces, transforming their "deck" of dice over a run.

## Overview

- **5 Dice as "Deck"**: Each die has 6 customizable faces
- **Stickers replace die faces**: Each sticker defines a face value and optional special effects
- **Three die types**: Basic, Golden, Metal - each with distinct visual appearance and behavior
- **2 Consumable Slots**: Slots 6-7 in the item strip hold stickers
- **Tactical Usage**: Stickers can be used in shop OR mid-game for strategic advantage
- **Persistent customization**: Face modifications persist across hands and levels within a run

## Die Types

### Basic (Common)
- **Rarity**: 70% shop spawn chance
- **Price**: $8 buy / $2 sell
- **Effect**: None - simply provides the face value for scoring
- **Behavior**: Can be freely rerolled

```lua
{
    id = "basic_6",
    faceValue = 6,
    dieType = "basic",
    rarity = "common",
}
```

### Golden (Uncommon)
- **Rarity**: 25% shop spawn chance
- **Price**: $12 buy / $4 sell
- **Effect**: Adds money equal to face value when scored
- **Behavior**: Can be freely rerolled

```lua
{
    id = "golden_3",
    faceValue = 3,
    dieType = "golden",
    effects = {
        onCount = { type = "money", amount = 3 }
    }
}
```

**Strategic value**: Golden stickers generate economy during play. A Golden Six adds $6 every time it scores, compounding over multiple hands.

### Metal (Rare)
- **Rarity**: 5% shop spawn chance
- **Price**: $15 buy / $5 sell
- **Effect**: x2 multiplier when scored
- **Behavior**: **Cannot be rerolled** (locked in place once rolled)

```lua
{
    id = "metal_4",
    faceValue = 4,
    dieType = "metal",
    canReroll = false,
    effects = {
        onCount = { type = "mult_x", multiplier = 2 }
    }
}
```

**Strategic value**: Metal stickers provide powerful multipliers but at the cost of flexibility. Once a metal face is rolled, it stays until played or the hand ends.

## Data Structures

### Sticker Definition
```lua
{
    id = "golden_6",           -- Unique identifier
    name = "Golden Six",       -- Display name
    description = "Adds $6 when scored",
    faceValue = 6,             -- Pip value (1-6)
    dieType = "golden",        -- "basic", "golden", or "metal"
    buyPrice = 12,
    sellPrice = 4,
    spriteId = 6,              -- Row offset in spritesheet
    rarity = "uncommon",       -- "common", "uncommon", "rare"
    canReroll = true,          -- false for metal stickers
    effects = {                -- Optional effects
        onCount = { type = "money", amount = 6 }
    }
}
```

### GameState.dice Storage
```lua
dice[i] = {
    value = 3,                                                    -- Current pip value
    locked = false,                                               -- Selection state
    faces = { "basic_1", "golden_2", "basic_3", "metal_4", "basic_5", "basic_6" },
    rolledFaceIndex = 2,                                          -- Which face position was rolled
}
```

Key points:
- `faces` array stores **sticker IDs**, not numeric values
- `rolledFaceIndex` tracks which physical face position was rolled
- `value` is derived from the sticker's `faceValue` property

### GameState.consumables
```lua
consumables = {nil, nil}  -- 2 consumable slots
-- Each slot contains: { stickerId = "basic_6" }
```

## Effects System

Effects trigger during the scoring animation when a die is counted.

### Effect Types

| Type | Property | Description |
|------|----------|-------------|
| `money` | `amount` | Adds money to player (golden stickers) |
| `mult_x` | `multiplier` | Multiplies the accumulated mult (metal stickers) |

### Trigger Flow

1. Player presses "Play Hand"
2. Score animation begins, processing dice left-to-right
3. For each scoring die:
   - **PIPS step**: Add face value to chips
   - **Effect step**: If sticker has `effects.onCount`, apply it
4. Effects shown as pop text ($X for money, xN for mult)
5. Final score calculated

### Code Reference (score_animation.lua)
```lua
local stickerId = dieData.faces[dieData.rolledFaceIndex]
local sticker = Stickers:get(stickerId)

if sticker.effects and sticker.effects.onCount then
    local effect = sticker.effects.onCount
    if effect.type == "money" then
        -- Queue MONEY animation step
    elseif effect.type == "mult_x" then
        -- Queue MULT_X animation step
    end
end
```

## Reroll Restrictions

Metal stickers introduce a unique constraint:

```lua
-- In game_state.lua:rollDice()
local canRerollFace = Stickers:canReroll(currentFaceId)
if not isFirstRoll and not canRerollFace then
    -- Metal face - skip reroll but still unlock selection
    die.locked = false
else
    -- Normal reroll
end
```

- **First roll**: All faces roll normally (including metal)
- **Subsequent rolls**: Metal faces are locked and cannot be rerolled
- The die can still be selected, but selecting a metal face and rolling has no effect on that face

## Rendering System

### Spritesheet Layout (`assets/diceSpriteSheet.png`)
```
168x336 pixels = 6 columns x 12 rows (28x28 sprites)

Row 1: Golden dice faces (1-6)
Row 2: Metal dice faces (1-6)
Row 3: Rusty dice (reserved)
Row 4: Basic dice faces (1-6)
...
Row 12: Rolling animation frames
```

### Quad Selection (spritesheet.lua)
```lua
-- Get quad for a specific sticker
function Spritesheet:getQuadForSticker(stickerId)
    local def = Stickers:get(stickerId)
    return self:getQuad(def.spriteId, def.dieType)
end

-- During rolling animation, use generic roll frames
quad = Spritesheet:getRollQuad(self.rollFrame)

-- When settled, use type-specific face
quad = Spritesheet:getQuad(self.currentFace, dieType)
```

### Die Type Detection (die.lua)
```lua
local dieType = "basic"
if self.faces and self.rolledFaceIndex then
    local stickerId = self.faces[self.rolledFaceIndex]
    dieType = Stickers:getType(stickerId)
end
```

## Editor UI Components

Located in `src/ui/`:

### Consumable Slot (`consumable_slot.lua`)

Renders a sticker in the item strip with:
- Click to show USE/SELL buttons
- Drag support for DELETE/SELL zones
- Spring animation on hover/click

### Dice Tooltip (`dice_tooltip.lua`)

Shows all 6 faces of a die in a horizontal row:
- Appears after 1 second hover (0.3s in editor mode)
- Shows actual values at each face position
- Clickable faces in editor mode

```
[Face1] [Face2] [Face3] [Face4] [Face5] [Face6]
```

### Dice Editor (`dice_editor.lua`)

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

### Drag Zones (`drag_zones.lua`)

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

## API Reference

### Stickers Module (`src/game/stickers.lua`)

```lua
-- Core getters
Stickers:get(stickerId)           -- Full definition
Stickers:getValue(stickerId)      -- Face value (1-6)
Stickers:getType(stickerId)       -- "basic", "golden", "metal"
Stickers:getSpriteId(stickerId)   -- Sprite row index
Stickers:canReroll(stickerId)     -- true/false

-- Pricing
Stickers:getBuyPrice(stickerId)
Stickers:getSellPrice(stickerId)

-- Shop generation
Stickers:getByRarity(rarity)      -- All stickers of rarity
Stickers:getRandomId()            -- Single weighted random
Stickers:getRandomIds(count)      -- Multiple unique weighted randoms
```

### GameState Methods

```lua
-- Face manipulation
GameState:setDieFace(dieIndex, faceIndex, stickerId)
GameState:getDieFaces(dieIndex)   -- Array of 6 sticker IDs
GameState:getDieFace(dieIndex, faceIndex)

-- Consumables
GameState:addConsumable(stickerId)     -- Returns slot index or nil
GameState:removeConsumable(index)       -- Returns removed data
GameState:getConsumable(index)          -- Get consumable at slot
GameState:hasConsumableRoom()           -- Check if slot available

-- Editor Mode
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

### Adding a New Die Type

1. **Add spritesheet row** in `assets/diceSpriteSheet.png`

2. **Register row in spritesheet.lua**:
```lua
typeRows = {
    golden = 1,
    metal = 2,
    cursed = 3,  -- New type
    basic = 4,
}
```

3. **Define stickers in stickers.lua**:
```lua
register({
    id = "cursed_6",
    name = "Cursed Six",
    description = "Steals $2 when scored",
    faceValue = 6,
    dieType = "cursed",
    effects = {
        onCount = { type = "money", amount = -2 }  -- Negative!
    }
})
```

4. **Handle effect in score_animation.lua** (if new effect type)

### Adding a New Effect Type

1. **Define in sticker**:
```lua
effects = {
    onCount = { type = "chips_bonus", amount = 10 }
}
```

2. **Add sequence step in score_animation.lua:buildSequence()**:
```lua
elseif effect.type == "chips_bonus" then
    table.insert(self.sequence, {
        type = "CHIPS_BONUS",
        dieIndex = dieIndex,
        amount = effect.amount,
    })
end
```

3. **Handle in updateCounting()**:
```lua
elseif step.type == "CHIPS_BONUS" then
    self.accumulatedChips = self.accumulatedChips + step.amount
    -- Show pop text, pulse chips box, etc.
end
```

## Rarity Weights

```lua
rarityWeights = {
    common = 70,    -- Basic stickers
    uncommon = 25,  -- Golden stickers
    rare = 5,       -- Metal stickers
}
```

Used by `Stickers:getRandomId()` for shop generation.

## Persistence

Custom faces persist across:
- Hands within a level
- Levels within a run
- Hot reload (R key)

Reset on new run (`GameState:reset()`).

## Future Ideas

- **Skull stickers**: Negative effects, very cheap or free
- **Wild stickers**: Count as any value (context-dependent)
- **Charged stickers**: Powerful effects that consume on use
- **Set bonuses**: Extra effects for matching sticker types on a die
- **Sticker upgrades**: Level up stickers for enhanced effects
