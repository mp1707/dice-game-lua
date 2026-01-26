-- Die Class
-- Individual die with state machine, physics, and rendering

local AnimStates = require("src.dice.animation_states")
local Physics = require("src.dice.physics")
local Shadow = require("src.dice.shadow")
local Juice = require("src.ui.juice")
local Theme = require("src.ui.theme")
local Stickers = require("src.game.stickers")

local Die = {}
Die.__index = Die

function Die.new(slotIndex, slotCenterX, groundY, size)
    local self = setmetatable({}, Die)

    -- Core identity
    self.slotIndex = slotIndex
    self.slotCenterX = slotCenterX
    self.slotWidth = Physics.slotWidth
    self.size = size or 120

    -- Position (x, y are screen coordinates, height is "Z-axis" for 3D effect)
    self.x = slotCenterX - self.size / 2
    self.y = groundY
    self.height = 0 -- 0 = on ground, positive = above ground
    self.groundY = groundY

    -- Velocity
    self.velocityX = 0
    self.velocityY = 0
    self.velocityZ = 0 -- Vertical velocity for bouncing

    -- Roll animation frame (1-6, cycles during roll)
    self.rollFrame = 1

    -- Scale (for squash/stretch)
    self.scaleX = 1
    self.scaleY = 1
    self.squashTimer = 0

    -- Animation state
    self.state = AnimStates.IDLE
    self.stateTimer = 0

    -- Dice face
    self.currentFace = 1 -- Which face is showing (1-6)
    self.targetFace = 1  -- Final face to land on
    self.faceChangeTimer = 0

    -- Sticker data (for type-based rendering)
    self.faces = nil           -- Array of sticker IDs (set by DiceDisplay)
    self.rolledFaceIndex = nil -- Which face index was rolled

    -- Bounce tracking
    self.bounceCount = 0
    self.maxBounces = 3

    -- Target (final resting position)
    self.targetX = slotCenterX - self.size / 2
    self.targetY = groundY

    -- Start delay for staggered rolls
    self.startDelay = 0
    self.isWaitingToStart = false

    -- Callback for bounce effects (screen shake)
    self.onBounce = nil

    return self
end

-- Start a roll animation with given parameters
function Die:startRoll(params)
    -- Apply roll parameters
    self.targetFace = params.targetFace
    self.maxBounces = params.maxBounces

    -- Set starting position
    self.x = params.startX - self.size / 2
    self.y = params.startY
    self.height = params.startHeight

    -- Set velocities
    self.velocityX = params.velocityX
    self.velocityY = params.velocityY
    self.velocityZ = params.velocityZ or 0

    -- Initialize roll animation frame
    self.rollFrame = math.random(1, 6)

    -- Set target position
    self.targetX = params.targetX - self.size / 2
    self.targetY = params.targetY

    -- Set start delay
    self.startDelay = params.startDelay or 0
    self.isWaitingToStart = self.startDelay > 0

    -- Reset state
    self.bounceCount = 0
    self.scaleX = 1
    self.scaleY = 1
    self.squashTimer = 0
    self.faceChangeTimer = 0
    self.currentFace = math.random(1, 6)

    -- Set initial state
    if self.isWaitingToStart then
        self.state = AnimStates.IDLE
    else
        self.state = AnimStates.DROPPING
    end
end

-- Update die state
function Die:update(dt)
    -- Handle start delay
    if self.isWaitingToStart then
        self.startDelay = self.startDelay - dt
        if self.startDelay <= 0 then
            self.isWaitingToStart = false
            self.state = AnimStates.DROPPING
        else
            return -- Still waiting, don't animate
        end
    end

    -- Get the handler for current state
    local handler = AnimStates.Handlers[self.state]
    if handler then
        local newState = handler(self, dt, Physics)

        -- Handle state transitions
        if newState and newState ~= self.state then
            self:onStateChange(self.state, newState)
            self.state = newState
        end
    end

    -- Update squash/stretch
    self:updateSquashStretch(dt)

    -- Constrain to slot
    self:constrainToSlot()
end

-- Handle state transitions
function Die:onStateChange(oldState, newState)
    if newState == AnimStates.BOUNCING then
        -- Trigger squash effect
        self.squashTimer = Physics.squashDuration

        -- Trigger screen shake via callback
        if self.onBounce then
            self.onBounce(self.bounceCount + 1, self.maxBounces)
        end
    elseif newState == AnimStates.LOCKED then
        -- Ensure final state is clean
        self.scaleX = 1
        self.scaleY = 1
    end
end

-- Update squash/stretch effect
function Die:updateSquashStretch(dt)
    if self.squashTimer > 0 then
        -- Squash on impact
        self.squashTimer = self.squashTimer - dt
        local t = math.max(0, self.squashTimer / Physics.squashDuration)

        -- Squash Y, expand X (volume preservation)
        self.scaleY = Physics.squashAmount + (1 - Physics.squashAmount) * (1 - t)
        self.scaleX = 1 + (1 - Physics.squashAmount) * t * 0.5
    elseif self.state == AnimStates.DROPPING and self.velocityZ > 100 then
        -- Stretch when falling fast
        local stretchAmount = math.min(math.abs(self.velocityZ) / 600, 0.25)
        self.scaleY = 1 + stretchAmount
        self.scaleX = 1 - stretchAmount * 0.4
    else
        -- Lerp back to normal
        self.scaleX = self.scaleX + (1 - self.scaleX) * 12 * dt
        self.scaleY = self.scaleY + (1 - self.scaleY) * 12 * dt
    end
end

-- Constrain die position within its slot
function Die:constrainToSlot()
    local halfWidth = self.slotWidth / 2
    local minX = self.slotCenterX - halfWidth - self.size / 2
    local maxX = self.slotCenterX + halfWidth - self.size / 2

    if self.x < minX then
        self.x = minX
        self.velocityX = math.abs(self.velocityX) * 0.5
    elseif self.x > maxX then
        self.x = maxX
        self.velocityX = -math.abs(self.velocityX) * 0.5
    end
end

-- Draw the die's shadow
function Die:drawShadow()
    Shadow.draw(self, self.groundY)
end

-- Draw the die
function Die:draw()
    local Spritesheet = Theme.diceSpritesheet
    if not Spritesheet then return end

    -- Determine die type from sticker (for static rendering)
    local dieType = "basic"
    if self.faces and self.rolledFaceIndex then
        local stickerId = self.faces[self.rolledFaceIndex]
        if stickerId then
            dieType = Stickers:getType(stickerId)
        end
    end

    -- Choose quad based on animation state
    local quad
    if self.state == AnimStates.DROPPING or self.state == AnimStates.BOUNCING then
        -- During roll animation, use roll animation frames
        quad = Spritesheet:getRollQuad(self.rollFrame)
    else
        -- Static display (IDLE, SETTLING, LOCKED) - show face value with type
        quad = Spritesheet:getQuad(self.currentFace, dieType)
    end

    local image = Spritesheet:getImage()
    local spriteW, spriteH = Spritesheet:getSpriteSize()

    -- Calculate scale to fit desired size
    local baseScale = self.size / math.max(spriteW, spriteH)

    -- Apply squash/stretch
    local scaleX = baseScale * self.scaleX
    local scaleY = baseScale * self.scaleY

    -- Calculate visual position (height offsets Y position)
    local drawX = self.x
    local drawY = self.y - self.height

    -- Center point for drawing
    local centerX = drawX + self.size / 2
    local centerY = drawY + self.size / 2

    -- Set color
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw the die using quad
    love.graphics.draw(
        image,
        quad,
        centerX, centerY,
        0,
        scaleX, scaleY,
        spriteW / 2, spriteH / 2
    )
end

-- Check if die is currently animating
function Die:isAnimating()
    return self.state ~= AnimStates.IDLE and
        self.state ~= AnimStates.LOCKED and
        not self.isWaitingToStart == false    -- Still counts as animating if waiting
end

-- Check if die is in a stable state (idle or locked)
function Die:isStable()
    return (self.state == AnimStates.IDLE or self.state == AnimStates.LOCKED) and
        not self.isWaitingToStart
end

-- Set the die face directly (for when not animating)
function Die:setFace(value)
    self.currentFace = value
    self.targetFace = value
end

-- Get the current face value
function Die:getFace()
    return self.currentFace
end

-- Reset to idle state at a specific position
function Die:resetToIdle(x, y)
    self.state = AnimStates.IDLE
    self.x = x
    self.y = y
    self.height = 0
    self.velocityX = 0
    self.velocityY = 0
    self.velocityZ = 0
    self.rollFrame = 1
    self.scaleX = 1
    self.scaleY = 1
    self.squashTimer = 0
    self.isWaitingToStart = false
    self.startDelay = 0
end

return Die
