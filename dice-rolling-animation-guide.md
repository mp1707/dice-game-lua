# Dice Rolling Animation System — Love2D Implementation Guide

## Overview

This document provides a comprehensive implementation guide for creating a polished, juicy dice rolling animation system in Love2D. The system uses 2D sprite-based dice with simulated physics to create the illusion of bouncing, settling dice while maintaining visual order and predictable final positions.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Asset Requirements](#2-asset-requirements)
3. [Core Data Structures](#3-core-data-structures)
4. [Animation State Machine](#4-animation-state-machine)
5. [Pseudo-Physics System](#5-pseudo-physics-system)
6. [Randomization Strategy](#6-randomization-strategy)
7. [Shadow System](#7-shadow-system)
8. [Juice & Polish](#8-juice--polish)
9. [Full Implementation](#9-full-implementation)
10. [Tuning Parameters](#10-tuning-parameters)

---

## 1. Architecture Overview

### Design Philosophy

The system uses a **slot-based constraint model** where each die has a designated horizontal zone but freedom within that zone. This maintains visual order while allowing organic, random-feeling movement.

```
┌─────────────────────────────────────────────────────────┐
│  Slot 1   │  Slot 2   │  Slot 3   │  Slot 4   │  Slot 5  │
│  ┌───┐    │    ┌───┐  │  ┌───┐    │  ┌───┐    │   ┌───┐  │
│  │ ⚀ │    │    │ ⚂ │  │  │ ⚄ │    │  │ ⚁ │    │   │ ⚅ │  │
│  └───┘    │    └───┘  │  └───┘    │  └───┘    │   └───┘  │
│   ↕ wiggle room within each slot for final position     │
└─────────────────────────────────────────────────────────┘
```

### Component Breakdown

| Component | Responsibility |
|-----------|----------------|
| `DiceManager` | Orchestrates all dice, triggers rolls, manages state |
| `Die` | Individual die state, physics, rendering |
| `AnimationController` | State machine for each die's animation phase |
| `PhysicsSimulator` | Handles fake physics: gravity, bounce, friction |
| `ShadowRenderer` | Draws dynamic shadows based on die height |
| `JuiceSystem` | Squash/stretch, screen shake, particles |

---

## 2. Asset Requirements

### Sprite Specifications

```
dice_faces.png (sprite sheet)
├── Frame 0: Face 1 (single pip)
├── Frame 1: Face 2
├── Frame 2: Face 3
├── Frame 3: Face 4
├── Frame 4: Face 5
└── Frame 5: Face 6

Recommended size: 32x32 or 64x64 pixels per face
Format: PNG with transparency
Style: Consistent pixel art with slight 3D shading
```

### Shadow Sprite

```
dice_shadow.png
├── Soft oval/rounded square shadow
├── Semi-transparent (alpha ~0.3-0.5)
└── Slightly larger than die face for blur effect
```

### Loading Assets

```lua
-- assets.lua
local Assets = {}

function Assets.load()
    Assets.diceFaces = {}
    local sheet = love.graphics.newImage("sprites/dice_faces.png")
    local frameSize = 32
    
    for i = 0, 5 do
        Assets.diceFaces[i + 1] = love.graphics.newQuad(
            i * frameSize, 0,
            frameSize, frameSize,
            sheet:getDimensions()
        )
    end
    
    Assets.diceSheet = sheet
    Assets.shadow = love.graphics.newImage("sprites/dice_shadow.png")
end

return Assets
```

---

## 3. Core Data Structures

### Die State Object

```lua
-- die.lua
local Die = {}
Die.__index = Die

function Die.new(slotIndex, slotCenterX)
    local self = setmetatable({}, Die)
    
    -- Identity
    self.slotIndex = slotIndex
    self.slotCenterX = slotCenterX
    
    -- Current visual state
    self.x = slotCenterX
    self.y = 0
    self.height = 0           -- Simulated Z-axis (elevation)
    self.rotation = 0         -- Visual rotation (cosmetic)
    self.scale = 1.0          -- For squash/stretch
    self.scaleX = 1.0
    self.scaleY = 1.0
    
    -- Physics state
    self.velocityX = 0
    self.velocityY = 0
    self.velocityZ = 0        -- Vertical velocity (for bouncing)
    self.angularVelocity = 0
    
    -- Animation state
    self.state = "idle"       -- idle, dropping, bouncing, settling, locked
    self.currentFace = 1      -- Which face is showing (1-6)
    self.targetFace = 1       -- Final face to land on
    self.bounceCount = 0
    self.maxBounces = 3
    
    -- Timing
    self.stateTimer = 0
    self.faceChangeTimer = 0
    self.faceChangeInterval = 0.05  -- How fast faces cycle during roll
    
    -- Target position (where die will settle)
    self.targetX = slotCenterX
    self.targetY = 0
    
    -- Constraints
    self.slotWidth = 80       -- How much horizontal freedom within slot
    self.groundY = 400        -- Y position of "ground"
    
    return self
end

return Die
```

### Dice Manager

```lua
-- dice_manager.lua
local DiceManager = {}
DiceManager.__index = DiceManager

function DiceManager.new(config)
    local self = setmetatable({}, DiceManager)
    
    self.dice = {}
    self.config = config or {}
    self.isRolling = false
    self.onRollComplete = nil  -- Callback
    
    -- Layout configuration
    self.startX = config.startX or 100
    self.spacing = config.spacing or 90
    self.groundY = config.groundY or 400
    
    -- Initialize 5 dice
    for i = 1, 5 do
        local slotCenterX = self.startX + (i - 1) * self.spacing
        self.dice[i] = Die.new(i, slotCenterX)
        self.dice[i].groundY = self.groundY
    end
    
    return self
end

return DiceManager
```

---

## 4. Animation State Machine

Each die follows a deterministic state machine that creates the illusion of physics-based movement.

### State Diagram

```
                    ┌─────────┐
                    │  IDLE   │
                    └────┬────┘
                         │ roll()
                         ▼
                    ┌─────────┐
              ┌────▶│DROPPING │
              │     └────┬────┘
              │          │ hit ground
              │          ▼
              │     ┌─────────┐
              │     │BOUNCING │◀─────┐
              │     └────┬────┘      │
              │          │           │ bounce count < max
              │          ├───────────┘
              │          │ bounce count >= max
              │          ▼
              │     ┌─────────┐
              │     │SETTLING │
              │     └────┬────┘
              │          │ reached target
              │          ▼
              │     ┌─────────┐
              └─────│ LOCKED  │
                    └─────────┘
```

### State Implementation

```lua
-- animation_states.lua
local States = {}

States.IDLE = "idle"
States.DROPPING = "dropping"
States.BOUNCING = "bouncing"
States.SETTLING = "settling"
States.LOCKED = "locked"

-- State handlers
local StateHandlers = {}

function StateHandlers.idle(die, dt)
    -- Die sits still, no updates needed
end

function StateHandlers.dropping(die, dt, physics)
    -- Apply gravity
    die.velocityZ = die.velocityZ + physics.gravity * dt
    die.height = die.height - die.velocityZ * dt
    
    -- Apply horizontal movement
    die.x = die.x + die.velocityX * dt
    die.y = die.y + die.velocityY * dt
    
    -- Rotate while falling
    die.rotation = die.rotation + die.angularVelocity * dt
    
    -- Cycle through faces rapidly
    die.faceChangeTimer = die.faceChangeTimer + dt
    if die.faceChangeTimer >= die.faceChangeInterval then
        die.faceChangeTimer = 0
        die.currentFace = math.random(1, 6)
    end
    
    -- Check for ground hit
    if die.height <= 0 then
        die.height = 0
        return States.BOUNCING
    end
    
    return States.DROPPING
end

function StateHandlers.bouncing(die, dt, physics)
    die.bounceCount = die.bounceCount + 1
    
    if die.bounceCount > die.maxBounces then
        die.currentFace = die.targetFace
        return States.SETTLING
    end
    
    -- Calculate bounce strength (decreases each bounce)
    local bounceStrength = physics.baseBounceStrength * 
                           math.pow(physics.bounceDamping, die.bounceCount)
    
    -- Apply bounce velocity
    die.velocityZ = -bounceStrength
    
    -- Reduce horizontal velocity
    die.velocityX = die.velocityX * physics.horizontalDamping
    die.velocityY = die.velocityY * physics.horizontalDamping
    
    -- Reduce angular velocity
    die.angularVelocity = die.angularVelocity * physics.angularDamping
    
    -- Squash effect on impact
    die.squashTimer = physics.squashDuration
    
    -- Change face on bounce (except last bounce)
    if die.bounceCount < die.maxBounces then
        die.currentFace = math.random(1, 6)
    else
        die.currentFace = die.targetFace
    end
    
    return States.DROPPING  -- Go back to dropping (will rise then fall)
end

function StateHandlers.settling(die, dt, physics)
    -- Lerp towards target position
    local lerpSpeed = physics.settleSpeed * dt
    
    die.x = die.x + (die.targetX - die.x) * lerpSpeed
    die.y = die.y + (die.targetY - die.y) * lerpSpeed
    
    -- Lerp rotation to nearest "flat" angle
    local targetRotation = math.floor(die.rotation / (math.pi/2) + 0.5) * (math.pi/2)
    die.rotation = die.rotation + (targetRotation - die.rotation) * lerpSpeed
    
    -- Reset scale
    die.scaleX = die.scaleX + (1 - die.scaleX) * lerpSpeed
    die.scaleY = die.scaleY + (1 - die.scaleY) * lerpSpeed
    
    -- Check if settled
    local distX = math.abs(die.x - die.targetX)
    local distY = math.abs(die.y - die.targetY)
    
    if distX < 0.5 and distY < 0.5 then
        die.x = die.targetX
        die.y = die.targetY
        die.rotation = targetRotation
        die.scaleX = 1
        die.scaleY = 1
        return States.LOCKED
    end
    
    return States.SETTLING
end

function StateHandlers.locked(die, dt)
    -- Die is locked in place, subtle idle animation possible
    return States.LOCKED
end

return {
    States = States,
    Handlers = StateHandlers
}
```

---

## 5. Pseudo-Physics System

The physics system simulates believable motion without actual physics calculations. Everything is carefully tuned for feel rather than accuracy.

### Physics Configuration

```lua
-- physics.lua
local Physics = {
    -- Gravity (pixels per second squared)
    gravity = 1800,
    
    -- Bounce behavior
    baseBounceStrength = 400,    -- Initial upward velocity on bounce
    bounceDamping = 0.55,        -- Multiplier per bounce (0.5 = half strength)
    horizontalDamping = 0.7,     -- How much horizontal speed is lost per bounce
    angularDamping = 0.6,        -- How much rotation slows per bounce
    
    -- Settling
    settleSpeed = 8,             -- Lerp speed when settling to final position
    
    -- Squash/stretch
    squashDuration = 0.08,       -- How long squash effect lasts
    squashAmount = 0.7,          -- Scale Y multiplier during squash
    stretchAmount = 1.2,         -- Scale Y multiplier during fast fall
    
    -- Initial drop parameters
    dropHeight = {min = 200, max = 350},
    initialVelocityX = {min = -80, max = 80},
    initialVelocityY = {min = 20, max = 60},
    initialAngularVelocity = {min = -15, max = 15},
    
    -- Bounce count
    bounceCount = {min = 2, max = 4},
}

function Physics.randomInRange(range)
    return range.min + math.random() * (range.max - range.min)
end

return Physics
```

### Height-Based Squash/Stretch

```lua
function Die:updateSquashStretch(dt, physics)
    if self.squashTimer and self.squashTimer > 0 then
        -- Squash on impact
        self.squashTimer = self.squashTimer - dt
        local t = self.squashTimer / physics.squashDuration
        self.scaleX = 1 + (1/physics.squashAmount - 1) * t
        self.scaleY = physics.squashAmount + (1 - physics.squashAmount) * (1 - t)
    elseif self.velocityZ > 200 then
        -- Stretch when falling fast
        local stretchFactor = math.min(self.velocityZ / 500, 0.3)
        self.scaleY = 1 + stretchFactor
        self.scaleX = 1 - stretchFactor * 0.5
    else
        -- Return to normal
        self.scaleX = self.scaleX + (1 - self.scaleX) * 10 * dt
        self.scaleY = self.scaleY + (1 - self.scaleY) * 10 * dt
    end
end
```

---

## 6. Randomization Strategy

### Seed-Based Deterministic Randomness

For network play or replays, use seeded randomness:

```lua
-- randomizer.lua
local Randomizer = {}

function Randomizer.new(seed)
    local self = {}
    self.seed = seed or os.time()
    math.randomseed(self.seed)
    return self
end

function Randomizer.generateRollParams(slotIndex, slotCenterX, groundY, physics)
    local params = {}
    
    -- Determine final face (1-6)
    params.targetFace = math.random(1, 6)
    
    -- Randomize bounce count
    params.maxBounces = math.random(
        physics.bounceCount.min,
        physics.bounceCount.max
    )
    
    -- Calculate drop position (above and slightly offset from slot center)
    local slotWidth = 60
    params.startX = slotCenterX + (math.random() - 0.5) * slotWidth * 0.8
    params.startY = groundY - physics.randomInRange(physics.dropHeight)
    params.startHeight = physics.randomInRange(physics.dropHeight)
    
    -- Initial velocities
    params.velocityX = physics.randomInRange(physics.initialVelocityX)
    params.velocityY = physics.randomInRange(physics.initialVelocityY)
    params.angularVelocity = physics.randomInRange(physics.initialAngularVelocity)
    
    -- Final target position (within slot bounds)
    local targetOffsetX = (math.random() - 0.5) * slotWidth * 0.6
    local targetOffsetY = (math.random() - 0.5) * 30
    params.targetX = slotCenterX + targetOffsetX
    params.targetY = groundY + targetOffsetY
    
    -- Stagger start time for more organic feel
    params.startDelay = slotIndex * 0.03 + math.random() * 0.05
    
    return params
end

return Randomizer
```

### Ensuring Visual Order

The key insight: **randomize within constraints**. Each die can only move within its designated slot width, ensuring dice never cross over each other.

```lua
function Die:constrainToSlot()
    local halfSlotWidth = self.slotWidth / 2
    local minX = self.slotCenterX - halfSlotWidth
    local maxX = self.slotCenterX + halfSlotWidth
    
    self.x = math.max(minX, math.min(maxX, self.x))
    self.targetX = math.max(minX, math.min(maxX, self.targetX))
end
```

---

## 7. Shadow System

Shadows provide crucial visual feedback about die height and add significant polish.

### Shadow Rendering Logic

```lua
-- shadow.lua
local Shadow = {}

function Shadow.draw(die, shadowImage, config)
    if die.state == "idle" or die.state == "locked" then
        return  -- No shadow when grounded
    end
    
    -- Calculate shadow properties based on height
    local heightRatio = die.height / config.maxHeight
    
    -- Shadow offset (moves away from die as height increases)
    local offsetX = heightRatio * config.maxOffsetX
    local offsetY = heightRatio * config.maxOffsetY
    
    -- Shadow scale (smaller and sharper when close to ground)
    local scale = 1 + heightRatio * config.scaleGrowth
    
    -- Shadow alpha (more transparent when higher)
    local alpha = config.baseAlpha * (1 - heightRatio * config.fadeRate)
    alpha = math.max(0.1, alpha)
    
    -- Draw shadow
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(
        shadowImage,
        die.x + offsetX,
        die.y + offsetY,
        0,  -- rotation
        scale * die.scaleX,
        scale * die.scaleY * 0.5,  -- Flatten shadow
        shadowImage:getWidth() / 2,
        shadowImage:getHeight() / 2
    )
    love.graphics.setColor(1, 1, 1, 1)
end

Shadow.config = {
    maxHeight = 350,
    maxOffsetX = 15,
    maxOffsetY = 25,
    scaleGrowth = 0.5,
    baseAlpha = 0.4,
    fadeRate = 0.6,
}

return Shadow
```

### Shadow Visual Reference

```
Height = 0 (grounded)        Height = 100               Height = 300
     ┌───┐                        ┌───┐                      ┌───┐
     │ ⚂ │                        │ ⚂ │                      │ ⚂ │
     └───┘                        └───┘                      └───┘
       ▀  (no shadow)               ▄▄                         ▄▄▄▄
                                  (small, dark)            (large, faint)
```

---

## 8. Juice & Polish

### Screen Shake

```lua
-- juice.lua
local Juice = {}

Juice.shake = {
    intensity = 0,
    duration = 0,
    timer = 0,
}

function Juice.triggerShake(intensity, duration)
    Juice.shake.intensity = intensity
    Juice.shake.duration = duration
    Juice.shake.timer = duration
end

function Juice.updateShake(dt)
    if Juice.shake.timer > 0 then
        Juice.shake.timer = Juice.shake.timer - dt
        return
    end
    Juice.shake.intensity = 0
end

function Juice.getShakeOffset()
    if Juice.shake.timer <= 0 then
        return 0, 0
    end
    
    local progress = Juice.shake.timer / Juice.shake.duration
    local currentIntensity = Juice.shake.intensity * progress
    
    local offsetX = (math.random() - 0.5) * 2 * currentIntensity
    local offsetY = (math.random() - 0.5) * 2 * currentIntensity
    
    return offsetX, offsetY
end

-- Trigger shake on bounce
function Die:onBounce()
    local shakeIntensity = 3 * (1 - self.bounceCount / self.maxBounces)
    Juice.triggerShake(shakeIntensity, 0.1)
end

return Juice
```

### Particle Effects (Optional)

```lua
-- particles.lua
local Particles = {}

function Particles.createBounceParticles(x, y)
    local ps = love.graphics.newParticleSystem(Assets.particle, 10)
    ps:setParticleLifetime(0.2, 0.4)
    ps:setEmissionRate(0)
    ps:setSizes(0.5, 0.1)
    ps:setColors(1, 1, 1, 0.8, 1, 1, 1, 0)
    ps:setSpeed(50, 150)
    ps:setSpread(math.pi)
    ps:setPosition(x, y)
    ps:emit(6)
    return ps
end

return Particles
```

### Easing Functions

```lua
-- easing.lua
local Easing = {}

function Easing.outBounce(t)
    if t < 1/2.75 then
        return 7.5625 * t * t
    elseif t < 2/2.75 then
        t = t - 1.5/2.75
        return 7.5625 * t * t + 0.75
    elseif t < 2.5/2.75 then
        t = t - 2.25/2.75
        return 7.5625 * t * t + 0.9375
    else
        t = t - 2.625/2.75
        return 7.5625 * t * t + 0.984375
    end
end

function Easing.outQuad(t)
    return 1 - (1 - t) * (1 - t)
end

function Easing.outElastic(t)
    local c4 = (2 * math.pi) / 3
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
end

return Easing
```

---

## 9. Full Implementation

### Main Die Class

```lua
-- die.lua
local Physics = require("physics")
local Shadow = require("shadow")
local Juice = require("juice")
local AnimStates = require("animation_states")

local Die = {}
Die.__index = Die

function Die.new(slotIndex, slotCenterX, groundY)
    local self = setmetatable({}, Die)
    
    -- Core identity
    self.slotIndex = slotIndex
    self.slotCenterX = slotCenterX
    self.slotWidth = 70
    
    -- Position
    self.x = slotCenterX
    self.y = groundY
    self.height = 0
    self.groundY = groundY
    
    -- Velocity
    self.velocityX = 0
    self.velocityY = 0
    self.velocityZ = 0
    
    -- Rotation
    self.rotation = 0
    self.angularVelocity = 0
    
    -- Scale (for squash/stretch)
    self.scaleX = 1
    self.scaleY = 1
    self.squashTimer = 0
    
    -- Animation state
    self.state = AnimStates.States.IDLE
    self.stateTimer = 0
    
    -- Dice face
    self.currentFace = 1
    self.targetFace = 1
    self.faceChangeTimer = 0
    self.faceChangeInterval = 0.04
    
    -- Bounce tracking
    self.bounceCount = 0
    self.maxBounces = 3
    
    -- Target (final resting position)
    self.targetX = slotCenterX
    self.targetY = groundY
    
    -- Start delay for staggered rolls
    self.startDelay = 0
    
    return self
end

function Die:startRoll(params)
    -- Apply roll parameters
    self.targetFace = params.targetFace
    self.maxBounces = params.maxBounces
    
    self.x = params.startX
    self.y = self.groundY
    self.height = params.startHeight
    
    self.velocityX = params.velocityX
    self.velocityY = params.velocityY
    self.velocityZ = 0
    
    self.angularVelocity = params.angularVelocity
    
    self.targetX = params.targetX
    self.targetY = params.targetY
    
    self.startDelay = params.startDelay
    
    self.bounceCount = 0
    self.state = AnimStates.States.DROPPING
    self.currentFace = math.random(1, 6)
end

function Die:update(dt)
    -- Handle start delay
    if self.startDelay > 0 then
        self.startDelay = self.startDelay - dt
        return
    end
    
    -- Update based on current state
    local newState = AnimStates.Handlers[self.state](self, dt, Physics)
    
    if newState and newState ~= self.state then
        self:onStateChange(self.state, newState)
        self.state = newState
    end
    
    -- Update squash/stretch
    self:updateSquashStretch(dt)
    
    -- Constrain to slot
    self:constrainToSlot()
end

function Die:onStateChange(oldState, newState)
    if newState == AnimStates.States.BOUNCING then
        -- Trigger bounce effects
        self.squashTimer = Physics.squashDuration
        Juice.triggerShake(2 * (1 - self.bounceCount / self.maxBounces), 0.08)
    elseif newState == AnimStates.States.LOCKED then
        -- Final settle effect
        self.scaleX = 1
        self.scaleY = 1
        self.rotation = 0
    end
end

function Die:updateSquashStretch(dt)
    if self.squashTimer > 0 then
        self.squashTimer = self.squashTimer - dt
        local t = math.max(0, self.squashTimer / Physics.squashDuration)
        -- Squash on impact
        self.scaleY = Physics.squashAmount + (1 - Physics.squashAmount) * (1 - t)
        self.scaleX = 1 + (1 - Physics.squashAmount) * t * 0.5
    elseif self.state == AnimStates.States.DROPPING and self.velocityZ > 100 then
        -- Stretch when falling
        local stretchAmount = math.min(math.abs(self.velocityZ) / 600, 0.25)
        self.scaleY = 1 + stretchAmount
        self.scaleX = 1 - stretchAmount * 0.4
    else
        -- Lerp back to normal
        self.scaleX = self.scaleX + (1 - self.scaleX) * 12 * dt
        self.scaleY = self.scaleY + (1 - self.scaleY) * 12 * dt
    end
end

function Die:constrainToSlot()
    local halfWidth = self.slotWidth / 2
    local minX = self.slotCenterX - halfWidth
    local maxX = self.slotCenterX + halfWidth
    
    if self.x < minX then
        self.x = minX
        self.velocityX = math.abs(self.velocityX) * 0.5
    elseif self.x > maxX then
        self.x = maxX
        self.velocityX = -math.abs(self.velocityX) * 0.5
    end
end

function Die:drawShadow(shadowImage)
    Shadow.draw(self, shadowImage, Shadow.config)
end

function Die:draw(diceSheet, faceQuads)
    local quad = faceQuads[self.currentFace]
    local frameSize = 32  -- Adjust to your sprite size
    
    -- Calculate visual Y position (includes height offset)
    local visualY = self.y - self.height
    
    love.graphics.draw(
        diceSheet,
        quad,
        self.x,
        visualY,
        self.rotation,
        self.scaleX,
        self.scaleY,
        frameSize / 2,  -- Origin X (center)
        frameSize / 2   -- Origin Y (center)
    )
end

function Die:isAnimating()
    return self.state ~= AnimStates.States.IDLE and 
           self.state ~= AnimStates.States.LOCKED
end

return Die
```

### Dice Manager

```lua
-- dice_manager.lua
local Die = require("die")
local Randomizer = require("randomizer")
local Physics = require("physics")
local Juice = require("juice")
local Assets = require("assets")

local DiceManager = {}
DiceManager.__index = DiceManager

function DiceManager.new(config)
    local self = setmetatable({}, DiceManager)
    
    config = config or {}
    self.startX = config.startX or 160
    self.spacing = config.spacing or 80
    self.groundY = config.groundY or 350
    
    self.dice = {}
    for i = 1, 5 do
        local slotCenterX = self.startX + (i - 1) * self.spacing
        self.dice[i] = Die.new(i, slotCenterX, self.groundY)
    end
    
    self.isRolling = false
    self.onRollComplete = nil
    
    return self
end

function DiceManager:roll(targetFaces, seed)
    -- targetFaces: optional table of predetermined results {3, 1, 5, 2, 6}
    -- seed: optional random seed for deterministic rolls
    
    if seed then
        math.randomseed(seed)
    end
    
    self.isRolling = true
    
    for i, die in ipairs(self.dice) do
        local params = Randomizer.generateRollParams(
            i, 
            die.slotCenterX, 
            self.groundY,
            Physics
        )
        
        -- Override target face if provided
        if targetFaces and targetFaces[i] then
            params.targetFace = targetFaces[i]
        end
        
        die:startRoll(params)
    end
end

function DiceManager:update(dt)
    Juice.updateShake(dt)
    
    local allSettled = true
    
    for _, die in ipairs(self.dice) do
        die:update(dt)
        if die:isAnimating() then
            allSettled = false
        end
    end
    
    if self.isRolling and allSettled then
        self.isRolling = false
        if self.onRollComplete then
            local results = self:getResults()
            self.onRollComplete(results)
        end
    end
end

function DiceManager:draw()
    -- Apply screen shake
    local shakeX, shakeY = Juice.getShakeOffset()
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)
    
    -- Draw all shadows first (back to front)
    for _, die in ipairs(self.dice) do
        die:drawShadow(Assets.shadow)
    end
    
    -- Draw all dice (sorted by Y for proper overlap)
    local sortedDice = {}
    for _, die in ipairs(self.dice) do
        table.insert(sortedDice, die)
    end
    table.sort(sortedDice, function(a, b)
        return (a.y - a.height) < (b.y - b.height)
    end)
    
    for _, die in ipairs(sortedDice) do
        die:draw(Assets.diceSheet, Assets.diceFaces)
    end
    
    love.graphics.pop()
end

function DiceManager:getResults()
    local results = {}
    for i, die in ipairs(self.dice) do
        results[i] = die.currentFace
    end
    return results
end

function DiceManager:isAnimating()
    return self.isRolling
end

return DiceManager
```

### Main Entry Point

```lua
-- main.lua
local Assets = require("assets")
local DiceManager = require("dice_manager")

local diceManager

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")  -- Pixel art scaling
    
    Assets.load()
    
    diceManager = DiceManager.new({
        startX = 120,
        spacing = 85,
        groundY = 300
    })
    
    diceManager.onRollComplete = function(results)
        print("Roll complete! Results:", table.concat(results, ", "))
    end
end

function love.update(dt)
    diceManager:update(dt)
end

function love.draw()
    love.graphics.clear(0.15, 0.15, 0.2)
    
    -- Draw play area
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", 50, 200, 500, 200, 10, 10)
    love.graphics.setColor(1, 1, 1)
    
    diceManager:draw()
    
    -- Instructions
    love.graphics.print("Press SPACE to roll", 10, 10)
    love.graphics.print("Results: " .. table.concat(diceManager:getResults(), ", "), 10, 30)
end

function love.keypressed(key)
    if key == "space" and not diceManager:isAnimating() then
        diceManager:roll()
    end
end
```

---

## 10. Tuning Parameters

### Quick Reference Table

| Parameter | Default | Range | Effect |
|-----------|---------|-------|--------|
| `gravity` | 1800 | 1000-2500 | Higher = faster falls |
| `baseBounceStrength` | 400 | 200-600 | Higher = bouncier |
| `bounceDamping` | 0.55 | 0.4-0.7 | Lower = faster decay |
| `horizontalDamping` | 0.7 | 0.5-0.9 | Lower = more slide |
| `settleSpeed` | 8 | 4-15 | Higher = snappier settle |
| `squashAmount` | 0.7 | 0.5-0.85 | Lower = more squash |
| `faceChangeInterval` | 0.04 | 0.02-0.08 | Lower = faster cycle |
| `startDelay` stagger | 0.03 | 0.02-0.06 | Per-die delay multiplier |

### Recommended Starting Values by Feel

**Snappy & Arcade:**
```lua
gravity = 2200
baseBounceStrength = 350
bounceDamping = 0.45
bounceCount = {min = 2, max = 3}
settleSpeed = 12
```

**Weighty & Realistic:**
```lua
gravity = 1400
baseBounceStrength = 450
bounceDamping = 0.6
bounceCount = {min = 3, max = 5}
settleSpeed = 6
```

**Chaotic & Fun:**
```lua
gravity = 1800
baseBounceStrength = 500
bounceDamping = 0.5
bounceCount = {min = 3, max = 4}
initialAngularVelocity = {min = -20, max = 20}
```

---

## Checklist for Implementation

- [ ] Create/source 6 dice face sprites (32x32 or 64x64)
- [ ] Create shadow sprite (soft oval, semi-transparent)
- [ ] Implement `Die` class with state machine
- [ ] Implement `DiceManager` for orchestration
- [ ] Add shadow rendering with height-based properties
- [ ] Implement squash/stretch transforms
- [ ] Add screen shake on bounces
- [ ] Tune physics parameters for desired feel
- [ ] Add sound effects at key moments (drop, bounce, settle)
- [ ] Test with all 5 dice rolling simultaneously
- [ ] Verify dice stay within their slots
- [ ] Confirm smooth settling without teleporting

---

## Summary

This implementation provides a robust, maintainable system for juicy dice animations. The key principles are:

1. **Slot-based constraints** keep dice ordered while allowing organic movement
2. **State machine** provides clear animation phases
3. **Fake physics** prioritizes feel over accuracy
4. **Height-based shadows** add crucial depth perception
5. **Squash/stretch** and screen shake add juice
6. **Randomization within bounds** creates variety without chaos

The system is designed to be easily tunable—adjust the physics parameters to find the perfect feel for your game.
