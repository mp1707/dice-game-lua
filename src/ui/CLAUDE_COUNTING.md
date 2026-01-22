# Counting Animation System

This document describes the score counting animation that plays when the player presses "Play Hand".

## Overview

Instead of instantly calculating the score, the game plays a satisfying sequential animation that:
1. Highlights scoring dice one by one (left to right)
2. Shows pip count pop-ups above each die
3. Accumulates the score in the formula box with visual feedback
4. Reveals the final hand score
5. Counts up the total score

## Animation Sequence

```
[Play Hand pressed]
     |
     v
[COUNTING] --> For each die L->R (0.4s delay between each):
            --> Die pulse animation AND pip number pop-up happen SIMULTANEOUSLY
            --> Pip value added to blue box with pop effect
     |
     v
[CALCULATING] --> Blue/red boxes fade out, hand score appears (1.0s)
     |
     v
[UPDATING_TOTAL] --> Total counts up from old to new value (0.6-1.5s)
     |
     v
[COMPLETE] --> Transition to next hand or result screen (0.3s hold)
```

**Total duration**: ~4-6 seconds (slower, more satisfying)

## Files

### `src/ui/score_animation.lua`

Main animation controller singleton. Manages the state machine and animation timing.

**Key Methods:**
- `ScoreAnimation.getInstance()` - Get singleton instance
- `start(config)` - Begin animation with configuration
- `update(dt)` - Update animation state
- `draw()` - Draw pop texts
- `isAnimating()` - Check if animation is active
- `skip()` - Skip to end (for impatient players)

**Animation Values (for info_panel):**
- `getAnimatedChips()` - Current chips value in blue box
- `getBoxScale()` - Scale multiplier for formula boxes
- `getBoxAlpha()` - Alpha value for formula boxes (fades to 0)
- `isHandScoreVisible()` - Whether to show hand score
- `getHandScore()` - The final hand score value
- `getHandScoreScale()` - Scale for hand score pop animation
- `getAnimatedTotalScore()` - Current total score during count-up

### `src/ui/pop_text.lua`

Floating text component with spring animation for pip count display.

**Features:**
- Scale pop animation (0 -> 1.35 -> 1.0 with spring overshoot)
- Horizontal stretch effect (1.5x -> 1.0x)
- Y offset animation (-20px -> 0)
- Automatic fade out after 0.5s

### Modified Files

**`src/ui/dice_display.lua`:**
- Added `triggerCountPulse()` method for die reaction animation
- Added `countPulseScale` and `countPulseRotation` state variables
- Scale: 1.0 -> 1.12 -> 1.0
- Rotation: Random +/-3 degrees impulse

**`src/ui/info_panel.lua`:**
- Modified `drawHandPreview()` to use animation values
- Modified `drawScoreSection()` to use animated total score
- Boxes scale/fade during CALCULATING phase
- Hand score appears with spring animation

**`src/states/play_state.lua`:**
- `onPlayHandClick()` starts animation instead of immediate score update
- Added `getScoringDiceIndicesInVisualOrder()` helper
- Added `handlePostScoreTransition()` for post-animation logic
- Added animation update/draw calls
- Space/Enter skips animation when active
- Input blocked during animation

## Timing Constants

| Phase | Delay | Notes |
|-------|-------|-------|
| COUNTING | 0.4s per die | Die pulse + pip pop-up + box update (all together) |
| CALCULATING | 1.0s | Boxes fade, score appears |
| UPDATING_TOTAL | 0.6-1.5s | Scales with score difference |
| COMPLETE | 0.3s | Hold before transition |

## Spring Parameters

```lua
-- Box pop effect
boxPop = { stiffness = 400, damping = 24 }

-- Hand score reveal
handScore = { stiffness = 450, damping = 26 }

-- Die pulse reaction
diePulse = { stiffness = 600, damping = 28 }

-- Pip text pop (in pop_text.lua)
pipPop = { stiffness = 500, damping = 22 }
```

## Scoring Dice Identification

The animation uses existing scoring functions to determine which dice to animate:

- **Upper section hands** (Ones, Twos, etc.): Only dice matching the target face value
- **Combination hands** (Full House, Straights, etc.): All selected dice

Dice are animated in visual order (left to right based on `diceVisualOrder`), not by dice index.

## Skip Functionality

Players can press **Space** or **Enter** during the animation to skip to the end:
- All pop texts are immediately cleared
- Completion callback is fired
- Animation state resets to IDLE

## Integration Points

### Starting the Animation

```lua
local scoreAnim = ScoreAnimation.getInstance()
scoreAnim:start({
    handId = detected.id,
    breakdown = Scoring.getBreakdown(detected.id, GameState.dice),
    oldScore = GameState.currentScore,
    scoringDiceIndices = self:getScoringDiceIndicesInVisualOrder(detected.id),
    diceDisplays = self.diceDisplays,
    diceVisualOrder = self.diceVisualOrder,
    infoPanel = self.infoPanel,
    onComplete = function()
        -- Update game state here
        GameState:useHand(detected.id, breakdown.total)
        self:handlePostScoreTransition()
    end,
})
```

### Checking Animation State

```lua
local scoreAnim = ScoreAnimation.getInstance()
if scoreAnim:isAnimating() then
    -- Block input, show different UI, etc.
end
```

## Visual Effects Summary

1. **Die Selection Pop**: Scale 1.15, Y offset -20px, spring back
2. **Die Count Pulse**: Scale 1.12, random rotation +/-3deg
3. **Pip Pop Text**: Scale 0->1.35->1, stretch 1.5x->1x, Y offset -20->0
4. **Box Pop**: Scale 1.1->1 on each pip addition
5. **Box Fade**: Alpha 1->0, scale 1.08->0.9
6. **Hand Score Pop**: Scale 0->1.2->1, gold color
7. **Total Count-up**: Ease-out-quad, duration based on score difference
