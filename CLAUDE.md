# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A roguelike Yahtzee dice game built with Love2D (LÖVE), featuring Balatro-style desktop UI. The game uses English UI text and implements a scoring system with 12 Yahtzee-style hands.

## Running the Game

```bash
love .
```

Requires Love2D 11.4+ installed on the system.

**Testing:** User tests manually. Do not start browser agents or run automated tests.

## Controls

### Mouse

- **Left-click dice** - Toggle selection (Select dice to REROLL or PLAY)
- **Click hand card** - Select which hand to play (radio-button style)
- **Drag on background** - Draw a selection rectangle to select multiple dice at once (desktop-style selection)
  - Left-click drag: Cyan rectangle, selects dice
  - Right-click drag: Purple rectangle, deselects dice
  - Dice inside the rectangle show visual feedback (elevation + scale)

### Keyboard

- **R** - Hot reload (reloads all src/ modules)
- **Space** - Roll dice or play hand (context-dependent)
- **Backspace** - Roll dice (shortcut for "Roll")
- **1-5** - Toggle dice selection
- **F3** - Toggle scaling debug
- **F10** - Toggle fullscreen
- **Escape** - Quit

## Architecture

### Core Systems

**State Machine** (`src/core/state_machine.lua`): Manages game states with lazy instantiation. States implement `enter`, `exit`, `update`, `draw`, and input methods.

**Game State** (`src/game/game_state.lua`): Central singleton holding all persistent game data (level, money, score, dice, hands remaining). Provides methods for game logic like rolling, locking dice, and hand management. Hands can be played multiple times per round.

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
│  - Hands + Rolls   │     (selected = raised)       │
│  - Money           │  ┌─────────┐  ┌─────────┐    │
│  - Settings/Info   │  │Hand Card│  │Hand Card│    │
│                    │  └─────────┘  └─────────┘    │
│                    │  [Play Hand] [Roll]          │
┌─────────────────────────────────────────────────────┐
```

### Selection Mechanics

- **Unified Selection**: Click any die to toggle selection. Selected dice move up visually.
- **Rerolling**: **Selected dice are rerolled** (similar to Balatro discard). Unselected dice are kept.
  - **Initial Roll**: The first roll of a hand automatically rolls ALL dice regardless of selection.
  - **Immediate Unselect**: When Reroll is clicked, selected dice immediately unselect and drop to the table to roll.
- **Play Hand**: "Play Hand" uses the **Selected dice** to score.
  - _Strategy_: Select dice to Keep/Play (if playing hand), or Select dice to Discard/Reroll (if rolling).
- **Auto-Detection**: Based on selected dice, the game automatically detects the BEST playable hand with this priority:
  1.  **Yahtzee** (5 matching)
  2.  **Large Straight** (5 consecutive)
  3.  **Small Straight** (4 consecutive)
  4.  **Full House** (3+2)
  5.  **Four of a Kind** (4 matching)
  6.  **Three of a Kind** (3 matching)
  7.  **Upper section** - falls back to the face with highest count (e.g., 2,2,6 → "Twos" not "Sixes")
- **Hand Preview**: The info panel displays the auto-detected best hand.
- **Dice Reordering**: Drag dice horizontally to reorder them. Other dice animate to make room while dragging. The visual order resets when a new hand starts.

### Dice Animation System

Located in `src/dice/`, see `src/dice/CLAUDE.md` for detailed documentation. Key components:

- **animation_states.lua**: State machine (IDLE → DROPPING → BOUNCING → SETTLING → LOCKED)
- **physics.lua**: Tunable physics parameters and roll param generation
- **die.lua**: Individual die with state machine, physics, squash/stretch
- **dice_manager.lua**: Orchestrates multiple dice with callbacks

### Sticker System & Dice Editor (Roguelike Core)

See `src/game/CLAUDE_STICKERS.md` for comprehensive documentation covering both the sticker system and dice editor. Core roguelike deck-building mechanic:

- **Custom Dice Faces**: Each die has 6 faces storing sticker IDs in `GameState.dice[i].faces`
- **Three Die Types**:
  - **Basic** (common, $8): Standard faces, no special effects
  - **Golden** (uncommon, $12): Adds money equal to face value when scored
  - **Metal** (rare, $15): x2 multiplier when scored, **cannot be rerolled**
- **Consumable Slots**: 2 slots in item strip (positions 6-7) for stickers
- **Spritesheet**: `assets/diceSpriteSheet.png` (168x336, rows for each die type)
- **Usage Flow**: Click consumable → USE → Select die → Select face → Confirm replacement

Key files:

- **stickers.lua**: Registry of all sticker definitions with effects
- **consumable_slot.lua**: Interactive slot component with USE/SELL buttons
- **dice_editor.lua**: Singleton managing editor mode (dimming, selection, confirmation)
- **dice_tooltip.lua**: Shows all 6 faces on die hover (1 sec delay)
- **drag_zones.lua**: DELETE (bottom-right) and SELL (top-middle) drop zones
- **spritesheet.lua**: Manages die type quads for rendering

### UI Components

All in `src/ui/`:

- **theme.lua**: Colors, fonts, spacing, layout constants (1080p)
- **nine_slice.lua**: Singleton for drawing panel backgrounds
- **panel.lua**, **button.lua**: Basic UI primitives
- **dice_display.lua**: Wraps Die with animation support
- **info_panel.lua**: Left panel with level, round, goal, score, hand preview, counters, money
- **dual_cta.lua**: Two action buttons - "Play Hand" and "Roll"
- **item_strip.lua**: 5+2 item slots at top center (slots 6-7 are consumable slots)
- **consumable_slot.lua**: Interactive consumable slot with USE/SELL buttons and drag support
- **dice_tooltip.lua**: Horizontal tooltip showing all 6 faces of a die
- **dice_editor.lua**: Singleton managing dice face editing mode
- **drag_zones.lua**: DELETE and SELL drop zones for consumables
- **score_animation.lua**: Counting animation when playing a hand
- **pop_text.lua**: Floating text with spring animation

### Item Trigger System

New event-driven system for item effects. See `src/items/CLAUDE.md` for detailed documentation. Replaces hardcoded item checks.

### Counting Animation

When "Play Hand" is pressed, a satisfying counting animation plays instead of instant calculation. See `src/ui/CLAUDE_COUNTING.md` for detailed documentation.

**Animation Sequence:**

1. Scoring dice highlight left-to-right (0.08s per die)
2. Pip numbers pop up above each die (0.12s per die)
3. Formula boxes fade, hand score appears (0.6s)
4. Total score counts up (0.4-1.2s)

**Skip:** Press Space or Enter during animation to skip to the end.

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
- `Scoring.detectBestHand(selectedIndices, dice)` - Detect the single best hand from selected dice (combination > upper)
- `Scoring.getScoringDiceForHand(handId, selectedIndices, dice)` - Get dice values that contribute to score

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

- **Sound Effects**: `assets/soundfx/` - See `assets/soundfx/CLAUDE.md` for documentation
- **Fonts**: `assets/fonts/m6x11plus.ttf` (pixel font)
- **Icons**: `assets/icons/hands/` (dice faces, hand types), `assets/icons/ui/` (coin, glove, die, lock)
- **UI**: `assets/ui/pixelSurface.png` (9-slice panel texture)
- **Dice Spritesheet**: `assets/diceSpriteSheet.png` (168x336, 28x28 sprites)
  - Row 1: Golden dice faces
  - Row 2: Metal dice faces
  - Row 4: Basic dice faces
  - Row 12: Rolling animation frames

Graphics use nearest-neighbor filtering for crisp pixel art.
