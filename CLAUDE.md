# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A roguelike Yahtzee dice game built with Love2D (LÖVE), featuring Balatro-style desktop UI. The game uses German UI text and implements a scoring system with 12 Yahtzee-style hands.

## Running the Game

```bash
love .
```

Requires Love2D 11.4+ installed on the system.

## Keyboard Shortcuts

- **R** - Hot reload (reloads all src/ modules)
- **Space** - Trigger action button (roll/accept hand)
- **1-5** - Toggle lock on dice 1-5
- **F3** - Toggle scaling debug
- **F10** - Toggle fullscreen
- **Escape** - Quit

## Architecture

### Core Systems

**State Machine** (`src/core/state_machine.lua`): Manages game states with lazy instantiation. States implement `enter`, `exit`, `update`, `draw`, and input methods.

**Game State** (`src/game/game_state.lua`): Central singleton holding all persistent game data (level, money, score, dice, hands used). Provides methods for game logic like rolling, locking dice, and hand management.

**Hot Reload** (`src/core/hot_reload.lua`): Watches `src/` for file changes and reloads modules while preserving state. Clears `package.loaded` for `src.*` modules.

**Scaling** (`src/core/scaling.lua`): Virtual 1920x1080 resolution with letterboxing. Use `Scaling.screenToGame()` for mouse coordinates.

### Game Flow

```
main.lua → StateMachine → PlayState ←→ ResultState ←→ ShopState
                              ↓
                         GameState (singleton)
```

### Dice Animation System

Located in `src/dice/`, see `src/dice/CLAUDE.md` for detailed documentation. Key components:

- **animation_states.lua**: State machine (IDLE → DROPPING → BOUNCING → SETTLING → LOCKED)
- **physics.lua**: Tunable physics parameters and roll param generation
- **die.lua**: Individual die with state machine, physics, squash/stretch
- **dice_manager.lua**: Orchestrates multiple dice with callbacks

### UI Components

All in `src/ui/`:

- **theme.lua**: Colors, fonts, spacing, layout constants (1080p)
- **nine_slice.lua**: Singleton for drawing panel backgrounds
- **panel.lua**, **button.lua**: Basic UI primitives
- **dice_display.lua**: Wraps Die with drag-and-drop
- **hand_list.lua**: Left panel showing 12 Yahtzee hands
- **info_panel.lua**: Right panel with score, rolls, action button
- **held_tray.lua**: 5 slots for locked dice

### Scoring System

**hands.lua**: Defines 12 hands (6 upper, 6 lower) with basePoints, mult, level.

**scoring.lua**: Pure functions for calculating scores:
- `Scoring.isValidHand(handId, dice)` - Check if pattern matches
- `Scoring.calculateScore(handId, dice)` - Returns `(basePoints + pips) * mult`
- `Scoring.getBreakdown(handId, dice)` - Detailed breakdown for UI

## Module Pattern

All modules follow this pattern:
```lua
local Module = {}
Module.__index = Module

function Module.new(config)
    local self = setmetatable({}, Module)
    -- init
    return self
end

return Module
```

Singletons use direct table returns with `:method()` syntax.

## Assets

- **Fonts**: `assets/fonts/m6x11plus.ttf` (pixel font)
- **Icons**: `assets/icons/hands/` (dice faces, hand types), `assets/icons/ui/` (coin, glove, die, lock)
- **UI**: `assets/ui/pixelSurface.png` (9-slice panel texture)

Graphics use nearest-neighbor filtering for crisp pixel art.
