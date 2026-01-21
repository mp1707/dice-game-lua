# UI System Documentation

This document explains the UI architecture and layout systems used in the dice game.

## Overview

The UI is designed for 1920x1080 virtual resolution with a Balatro-inspired aesthetic. All coordinates and sizes are defined in `theme.lua`.

## Layout Structure

```
┌──────────────────────────────────────────────────────────────┐
│  LEFT PANEL          │           CENTER AREA                 │
│  (Info Panel)        │  ┌─────────────────────────────────┐  │
│  380px wide          │  │   Item Strip (5+2 slots)        │  │
│                      │  └─────────────────────────────────┘  │
│  - Level + Round     │                                       │
│  - Goal              │        [Dice Home Area]               │
│  - Score             │        (selected = raised)            │
│  - Hand Preview      │                                       │
│  - Hände + Würfe     │   ┌───────────┐   ┌───────────┐      │
│  - Money             │   │ Hand Card │   │ Hand Card │      │
│  - Settings/Info     │   └───────────┘   └───────────┘      │
│                      │   [Hand spielen]    [Würfeln]         │
└──────────────────────────────────────────────────────────────┘
```

## Info Panel - 10-Unit Vertical Spacing System

The info panel uses a proportional spacing system to fill vertical space dynamically. This ensures consistent layouts regardless of panel height.

### Unit Allocation

| Section           | Units        | Notes                                   |
| ----------------- | ------------ | --------------------------------------- |
| Level/Round row   | 1            | Two boxes side by side                  |
| Goal section      | 3            | + 2 absorbed gaps (like 3 stacked rows) |
| Score section     | 1            | Label left, value right                 |
| Selected Hand     | 2            | + 1 absorbed gap (like 2 stacked rows)  |
| Hände/Würfe row   | 1            | Two boxes side by side                  |
| Money row         | 1            | Centered value                          |
| Settings/Info row | 1            | Two buttons side by side                |
| **Total**         | **10 units** |                                         |

### Gap System

- **9 total gaps**: 6 visible between rows + 3 absorbed inside larger sections
- **Gap size**: 15% of one unit (`gapRatio = 0.15`)
- **Formula**: `totalUnits = 10 + 9 * gapRatio` = 11.35 equivalent units

### Calculation in Code

```lua
local availableHeight = self.height - self.padding * 2
local gapRatio = 0.15
local totalUnits = 10 + 9 * gapRatio
local unit = availableHeight / totalUnits
local gap = unit * gapRatio

-- Larger sections include absorbed gaps
local goalHeight = unit * 3 + gap * 2
local handHeight = unit * 2 + gap * 1
```

## Component Files

| File                  | Purpose                                         |
| --------------------- | ----------------------------------------------- |
| `theme.lua`           | Colors, fonts, spacing, layout constants        |
| `nine_slice.lua`      | Singleton for drawing 9-slice panel backgrounds |
| `panel.lua`           | Basic panel container                           |
| `button.lua`          | Clickable button with hover/press states        |
| `info_panel.lua`      | Left panel with game stats and hand preview     |
| `hand_card.lua`       | Single hand card with dice icons, level, name   |
| `hand_card_area.lua`  | Container for 0-2 hand cards with selection     |
| `dice_display.lua`    | Single die with animation support               |
| `dual_cta.lua`        | "Hand spielen" + "Würfeln" button pair          |
| `item_strip.lua`      | 5+2 item slots at top center                    |
| `hand_button.lua`     | Individual hand selection button                |
| `hand_formula.lua`    | Chips × Mult formula display                    |

## 9-Slice System

The `nine_slice.lua` module renders resizable panels using a 9-slice texture (`assets/ui/pixelSurface.png`). This allows panels of any size while maintaining crisp corners.

```lua
local nineSlice = NineSlice.getInstance()
nineSlice:draw(x, y, width, height, color, borderScale)
```

## Theme Colors

Key colors defined in `theme.lua`:

- **Background**: `bg` (#2A2242), `bg2` (#3C325B)
- **Surfaces**: `surface` (#352B58), `panelDark` (darker inner containers)
- **Accents**: `cyan`, `gold`, `coral`, `mint`
- **Formula boxes**: `upgradePoints` (blue), `upgradeMult` (red)

## Dice Selection System

- **Unified Selection**: Click any die to toggle selection (selected dice move up visually)
- **Hand Detection**: Based on selected dice, detects both Zahlen (upper) and Kombination (lower) hands
- **Hand Cards**: 1-2 cards appear showing playable hands with dice icons, level, and name
- **Hand Card Selection**: Click card or use arrow keys to select which hand to play (radio-button style)
- **Visual Feedback**: Selected dice are raised; selected hand card has cyan border highlight
