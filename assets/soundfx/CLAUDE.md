# Sound Effects System

This document describes the sound effects system for the dice game.

## Overview

The game uses a centralized `Sound` module (`src/core/sound.lua`) for all audio playback. Sounds are preloaded on startup and can be played with simple API calls.

## Available Sounds

| Name         | File           | Purpose                       |
| ------------ | -------------- | ----------------------------- |
| `lightClick` | lightClick.wav | Button clicks, dice selection |
| `click`      | click.wav      | Dice deselection              |
| `diceroll`   | diceroll.wav   | Dice rolling                  |
| `cash`       | cash.wav       | Cashout row animations        |
| `tick2`      | tick2.wav      | Dice counting, grabbing       |
| `tick`       | tick.wav       | (Available for future use)    |
| `info`       | info.wav       | (Available for future use)    |
| `tap`        | tap.wav        | (Available for future use)    |
| `lost`       | lost.wav       | (Available for future use)    |
| `gameboy`    | gameboy.wav    | (Available for future use)    |

## Usage

```lua
local Sound = require("src.core.sound")

-- Basic playback
Sound:play("select")

-- With options
Sound:play("diceroll", {
    volume = 0.8,      -- Optional: 0.0 to 1.0 (default: 1.0)
    pitch = 1.0,       -- Optional: pitch multiplier (default: 1.0)
    pitchVariance = 0.1 -- Optional: random ±variance (default: 0)
})
```

## Integration Points

| Event               | Location                               | Sound        |
| ------------------- | -------------------------------------- | ------------ |
| Dice selected       | `game_state.lua:toggleDiceSelection()` | `lightClick` |
| Dice deselected     | `game_state.lua:toggleDiceSelection()` | `click`      |
| Button clicked      | `button.lua:mousereleased()`           | `lightClick` |
| Dice rolled         | `play_state.lua:rollDice()`            | `diceroll`   |
| Cashout row appears | `result_state.lua:drawRow()`           | `cash`       |
| Die counted         | `score_animation.lua:updateCounting()` | `tick2`      |

## Background Music

The game features looping background music that starts automatically when the game loads:

- **File**: `Analog Dreams - Blue Saga.ogg`
- **Volume**: 30% (configurable via `Sound:setMusicVolume()`)
- **Type**: Streamed (for memory efficiency)
- **Looping**: Yes

### Music Controls

```lua
local Sound = require("src.core.sound")

-- Start music (called automatically in main.lua)
Sound:startMusic()

-- Stop music
Sound:stopMusic()

-- Adjust music volume (0.0 to 1.0)
Sound:setMusicVolume(0.5)
```

## Adding New Sounds

1. Add the `.wav` file to `assets/soundfx/`
2. Add an entry to `soundConfig` in `src/core/sound.lua`:
   ```lua
   newSound = { file = "assets/soundfx/newsound.wav", volume = 0.7 },
   ```
3. Call `Sound:play("newSound")` where needed
