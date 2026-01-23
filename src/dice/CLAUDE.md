# Dice Rolling Animation System

This directory contains a modular, physics-based dice rolling animation system for the dice game. The system provides juicy, satisfying dice rolls with proper state machines, dynamic shadows, and screen shake effects.

## Architecture Overview

```
src/dice/
  animation_states.lua  -- State machine definitions and handlers
  physics.lua           -- Tunable physics configuration
  shadow.lua            -- Height-based shadow rendering
  die.lua               -- Individual die class
  spritesheet.lua       -- Dice spritesheet management
```

## Module Descriptions

### `animation_states.lua`

Defines the state machine for dice animation:

| State      | Description                              |
| ---------- | ---------------------------------------- |
| `IDLE`     | Die sits still, no animation             |
| `DROPPING` | Die falling with gravity, cycling faces  |
| `BOUNCING` | Die hits ground, triggers bounce         |
| `SETTLING` | Die lerps to final position              |
| `LOCKED`   | Die locked in place (animation complete) |

Each state has a handler function that updates the die and returns the next state.

### `physics.lua`

Tunable physics parameters:

```lua
gravity = 1800           -- Pixels/sec^2 (higher = snappier)
baseBounceStrength = 400 -- Initial upward velocity on bounce
bounceDamping = 0.55     -- Multiplier per bounce
horizontalDamping = 0.7  -- Horizontal speed loss per bounce
settleSpeed = 8          -- Lerp speed when settling
squashDuration = 0.08    -- Squash effect duration
squashAmount = 0.7       -- Scale Y during squash
faceChangeInterval = 0.04 -- Face cycling speed (~25fps)
```

Also provides `Physics.generateRollParams()` for creating randomized roll parameters.

> **Note**: Dice final positions are defined in `src/states/play_state.lua` via `initLooseDicePositions()`, which creates a neat horizontal row using `Theme.layout.diceSpacing`. The physics system uses these positions as animation targets.

### `shadow.lua`

Dynamic shadows that respond to die height:

- **Offset**: Shadow moves away from die as height increases
- **Scale**: Shadow grows larger when die is higher
- **Alpha**: Shadow fades as die gets higher

### `die.lua`

The core Die class with:

- State machine integration
- Physics simulation (position, velocity, height)
- Squash/stretch effects
- Slot constraints (keeps die within horizontal bounds)
- Shadow and face rendering

Key methods:

```lua
Die.new(slotIndex, slotCenterX, groundY, size)
Die:startRoll(params)  -- Begin roll animation
Die:update(dt)         -- Update state machine
Die:draw()             -- Render die face
Die:drawShadow()       -- Render shadow
Die:isStable()         -- Check if idle/locked
```

### `spritesheet.lua`

Manages the dice spritesheet:

- Loads and configures the dice texture
- Creates quads for face values (1-6) and rolling animation frames
- Provides quad lookup methods for rendering

## Integration with DiceDisplay

The `src/ui/dice_display.lua` wraps `Die` to provide:

- Drag-and-drop functionality
- Position animation (moving to/from held tray)
- Home position tracking
- Integration with game state

## Animation Flow

1. **Roll triggered**: `DiceDisplay:startRollAnimation()` called
2. **Parameters generated**: `Physics.generateRollParams()` creates random values
3. **State: DROPPING**: Die falls with gravity, faces cycle rapidly
4. **State: BOUNCING**: Die hits ground, triggers squash + screen shake
5. **Repeat**: DROPPING → BOUNCING (2-4 times based on `maxBounces`)
6. **State: SETTLING**: Die lerps to final position
7. **State: LOCKED**: Animation complete, die shows final face

> **Note**: Dice settle into a neat, straight horizontal row. These positions are defined in `play_state.lua:initLooseDicePositions()` and used both as home positions and animation targets.

## Customization

### Adjusting Feel

Edit `physics.lua` to tune:

- `gravity`: Higher = faster, snappier drops
- `bounceDamping`: Lower = more bounces, higher energy
- `faceChangeInterval`: Lower = faster face cycling
- `squashAmount`: Lower = more dramatic squash

### Adding Effects

The `die.onBounce` callback fires on each bounce - use for:

- Sound effects
- Particle effects
- Additional screen shake

## Usage Example

```lua
local Die = require("src.dice.die")
local Physics = require("src.dice.physics")

-- Create a die
local die = Die.new(1, 500, 400, 120)

-- Generate roll parameters
local params = Physics.generateRollParams(1, 500, 400)
params.targetFace = 6  -- Override to land on 6

-- Start the roll
die:startRoll(params)

-- In update loop
function love.update(dt)
    die:update(dt)
end

-- In draw loop
function love.draw()
    die:drawShadow()
    die:draw()
end
```
