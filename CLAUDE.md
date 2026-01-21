# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A roguelike Yahtzee dice game built with Love2D (LÖVE), featuring Balatro-style desktop UI. The game uses German UI text and implements a scoring system with 12 Yahtzee-style hands.

## Running the Game

```bash
love .
```

Requires Love2D 11.4+ installed on the system.

## Controls

### Mouse
- **Left-click dice** - Toggle selection (selected dice move up and are not rerolled)
- **Click hand card** - Select which hand to play (radio-button style)

### Keyboard
- **R** - Hot reload (reloads all src/ modules)
- **Space** - Roll dice or play hand (context-dependent)
- **Backspace** - Roll dice (shortcut for "Würfeln")
- **1-5** - Toggle dice selection
- **Left/Right arrows** - Navigate between hand cards
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

### UI Layout (1920x1080)

```
┌─────────────────────────────────────────────────────┐
│  LEFT PANEL        │        CENTER AREA             │
│  (Info Panel)      │  ┌─────────────────────────┐  │
│  - Level + Round   │  │  Item Strip (5+2 slots) │  │
│  - Goal            │  └─────────────────────────┘  │
│  - Score           │                               │
│  - Hand Preview    │     [Dice Home Area]         │
│  - Hände + Würfe   │     (selected = raised)       │
│  - Money           │  ┌─────────┐  ┌─────────┐    │
│  - Settings/Info   │  │Hand Card│  │Hand Card│    │
│                    │  └─────────┘  └─────────┘    │
│                    │  [Hand spielen] [Würfeln]    │
└─────────────────────────────────────────────────────┘
```

### Selection Mechanics

- **Unified Selection**: Click any die to toggle selection. Selected dice move up visually and are locked (not rerolled).
- **Hand Detection**: Based on selected dice, the game detects playable hands:
  - **Zahlen** (upper section): The highest face value among selected dice determines the hand (e.g., selecting dice 5,5,3 → "Fünfer")
  - **Kombinationen** (lower section): Best pattern match is detected (priority: Yahtzee > Large Straight > Small Straight > Full House > 4ofKind > 3ofKind)
- **Hand Cards**: 1 or 2 hand cards appear above CTAs showing playable hands. If both Zahlen and Kombination match, two cards are shown.
- **Hand Selection**: Click a hand card (or use arrow keys) to select which hand to play. Only one can be selected at a time.
- **Rolling**: Selected dice stay locked, unselected dice get re-rolled.

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
- **dice_display.lua**: Wraps Die with animation support
- **info_panel.lua**: Left panel with level, round, goal, score, hand preview, counters, money
- **hand_card.lua**: Single hand card showing hand name, level, and scoring dice
- **hand_card_area.lua**: Container managing 0-2 hand cards with radio-button selection
- **dual_cta.lua**: Two action buttons - "Hand spielen" and "Würfeln"
- **item_strip.lua**: 5+2 item slots at top center

### Text Rendering

All game UI text uses shadow helper functions for consistent readability. Located in `theme.lua`:

```lua
Theme:drawTextWithShadow(text, x, y, font, color, shadowOffset)
Theme:drawTextCenteredWithShadow(text, x, y, width, font, color, shadowOffset)
Theme:drawTextRightWithShadow(text, x, y, width, font, color, shadowOffset)
```

**Shadow settings** (defined in `theme.lua`):
- Color: `Theme.colors.textShadow` (black, 50% opacity)
- Default offset: 2 pixels

**IMPORTANT**: Never use `love.graphics.print()` directly for game UI text. Always use the shadow helpers above. This ensures visual consistency across all screens and makes text readable on any background.

### Scoring System

**hands.lua**: Defines 12 hands (6 upper, 6 lower) with basePoints, mult, level.

**scoring.lua**: Pure functions for calculating scores:
- `Scoring.isValidHand(handId, dice)` - Check if pattern matches
- `Scoring.calculateScore(handId, dice)` - Returns `(basePoints + pips) * mult`
- `Scoring.getBreakdown(handId, dice)` - Detailed breakdown for UI
- `Scoring.detectZahlenHand(selectedIndices, dice)` - Detect upper hand from selection
- `Scoring.detectBestKombinationFromIndices(selectedIndices, dice)` - Detect highest priority pattern from selected dice
- `Scoring.getScoringDiceForHand(handId, selectedIndices, dice)` - Get dice values that contribute to score (for hand card display)

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
