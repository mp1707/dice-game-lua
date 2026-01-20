-- Dice display component
-- Shows a single die with value and lock state
-- Supports drag-and-drop and smooth position animation
-- Features: roll-in from right, 3 bounces, dynamic shadows, varied landing slots

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local DiceDisplay = {}
DiceDisplay.__index = DiceDisplay

function DiceDisplay.new(config)
    local self = setmetatable({}, DiceDisplay)

    self.x = config.x or 0
    self.y = config.y or 0
    self.size = config.size or 120
    self.index = config.index or 1
    self.onClick = config.onClick or function() end

    -- Reference to get dice data
    self.getDiceData = config.getDiceData or function()
        return { value = 1, locked = false }
    end

    -- Animation state (roll animation)
    self.isAnimating = false
    self.animValue = 1
    self.animTimer = 0
    self.animDuration = 0.8

    -- Throw & bounce animation state
    self.throwHeight = 0           -- Current Y offset (negative = up)
    self.throwVelocity = 0         -- Vertical velocity
    self.bounceCount = 0           -- Number of bounces completed
    self.maxBounces = 3            -- Total bounces before settling
    self.faceChangeTimer = 0       -- Timer for face changes
    self.faceChangeInterval = 0.08 -- ~12fps face changes (slower)
    self.rotation = 0              -- Current rotation
    self.rotationSpeed = 0         -- Rotation velocity
    self.squash = 1.0              -- Squash/stretch factor

    -- Horizontal roll-in animation
    self.horizontalOffset = 0   -- Current X offset (positive = right of target)
    self.horizontalVelocity = 0 -- Horizontal velocity

    -- Landing slot variation (slight random offsets for organic feel)
    self.landingOffsetX = 0 -- Random X offset for this roll
    self.landingOffsetY = 0 -- Random Y offset for this roll

    -- Position animation state
    self.targetX = nil
    self.targetY = nil
    self.animationSpeed = 1200 -- pixels per second

    -- Home position (loose area position)
    self.homeX = config.x or 0
    self.homeY = config.y or 0

    -- Held tray state
    self.isInHeldTray = false
    self.heldSlotIndex = nil

    -- Drag state
    self.isDragging = false
    self.dragOffsetX = 0
    self.dragOffsetY = 0

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    return self
end

function DiceDisplay:setPosition(x, y)
    self.x = x
    self.y = y
end

function DiceDisplay:setHomePosition(x, y)
    self.homeX = x
    self.homeY = y
end

function DiceDisplay:containsPoint(px, py)
    return px >= self.x and px < self.x + self.size and
        py >= self.y and py < self.y + self.size
end

function DiceDisplay:startRollAnimation(duration)
    self.isAnimating = true
    self.animTimer = 0
    self.animDuration = duration or 0.8

    -- Stagger delay: each die starts at a slightly different time for organic feel
    -- Randomize order so it's not always left-to-right
    self.staggerDelay = math.random() * 0.08 + 0.03 * (math.random(1, 5) - 1)
    self.staggerWaiting = true

    -- Generate random landing slot offsets for this roll (varies each time)
    -- This creates slightly different landing positions while keeping dice in order
    self.landingOffsetX = (math.random() - 0.5) * 16 -- ±8 pixels X variation
    self.landingOffsetY = (math.random() - 0.5) * 10 -- ±5 pixels Y variation

    -- Final rotation: small random tilt so dice don't all end perfectly straight
    self.finalRotation = (math.random() - 0.5) * 0.3 -- ±0.15 radians (~8.5 degrees)

    -- Choose a random animation type for variety
    -- 1 = straight drop, 2 = arc from left, 3 = arc from right
    local animType = math.random(1, 3)

    -- All animations start from the FINAL landing position offsets
    -- The dice will animate and settle exactly where they belong
    self.horizontalOffset = self.landingOffsetX
    self.throwHeight = self.landingOffsetY

    if animType == 1 then
        -- Straight drop: start above, fall straight down
        self.throwHeight = self.landingOffsetY - 120 - math.random() * 40
        self.throwVelocity = 50 + math.random() * 50         -- Slight downward velocity
        self.horizontalVelocity = (math.random() - 0.5) * 30 -- Tiny horizontal drift
    elseif animType == 2 then
        -- Arc from left: start above and to the left
        self.throwHeight = self.landingOffsetY - 80 - math.random() * 40
        self.horizontalOffset = self.landingOffsetX - 60 - math.random() * 40
        self.throwVelocity = -100 - math.random() * 50     -- Upward arc
        self.horizontalVelocity = 150 + math.random() * 50 -- Move right
    else
        -- Arc from right: start above and to the right
        self.throwHeight = self.landingOffsetY - 80 - math.random() * 40
        self.horizontalOffset = self.landingOffsetX + 60 + math.random() * 40
        self.throwVelocity = -100 - math.random() * 50      -- Upward arc
        self.horizontalVelocity = -150 - math.random() * 50 -- Move left
    end

    self.bounceCount = 0
    self.rotation = self.finalRotation              -- Start at final rotation, will spin during animation
    self.rotationSpeed = (math.random() - 0.5) * 12 -- Random spin direction
    self.squash = 1.0
    self.faceChangeTimer = 0
end

function DiceDisplay:stopAnimation()
    self.isAnimating = false
    self.staggerWaiting = false
    -- Ensure we're at final position with final tilt
    self.horizontalOffset = self.landingOffsetX
    self.throwHeight = self.landingOffsetY
    self.rotation = self.finalRotation or 0
    self.squash = 1.0
end

-- Start dragging the die
function DiceDisplay:startDrag(mouseX, mouseY)
    self.isDragging = true
    self.dragOffsetX = self.x - mouseX
    self.dragOffsetY = self.y - mouseY
    -- Cancel any position animation
    self.targetX = nil
    self.targetY = nil
end

-- Update position while dragging
function DiceDisplay:updateDrag(mouseX, mouseY)
    if self.isDragging then
        self.x = mouseX + self.dragOffsetX
        self.y = mouseY + self.dragOffsetY
    end
end

-- End drag
function DiceDisplay:endDrag()
    self.isDragging = false
end

-- Animate to target position
function DiceDisplay:animateTo(targetX, targetY)
    self.targetX = targetX
    self.targetY = targetY
end

-- Move to held tray slot
function DiceDisplay:moveToHeldSlot(slotX, slotY, slotIndex)
    self.isInHeldTray = true
    self.heldSlotIndex = slotIndex
    self:animateTo(slotX, slotY)
end

-- Return to loose area (home position)
function DiceDisplay:returnToLoose()
    self.isInHeldTray = false
    self.heldSlotIndex = nil
    self:animateTo(self.homeX, self.homeY)
end

-- Snap immediately to position (no animation)
function DiceDisplay:snapTo(x, y)
    self.x = x
    self.y = y
    self.targetX = nil
    self.targetY = nil
end

function DiceDisplay:update(dt)
    -- Roll animation with throw & bounce physics
    if self.isAnimating then
        -- Handle stagger delay: wait before starting actual animation
        if self.staggerWaiting then
            self.staggerDelay = self.staggerDelay - dt
            if self.staggerDelay <= 0 then
                self.staggerWaiting = false
            else
                return -- Still waiting, don't animate yet
            end
        end

        local gravity = 1400 -- pixels/sec²

        -- Update throw height with gravity
        self.throwVelocity = self.throwVelocity + gravity * dt
        self.throwHeight = self.throwHeight + self.throwVelocity * dt

        -- Update horizontal position
        self.horizontalOffset = self.horizontalOffset + self.horizontalVelocity * dt

        -- Apply spring force toward landing X (always active, gets stronger as we slow)
        local distToLandingX = self.landingOffsetX - self.horizontalOffset
        self.horizontalVelocity = self.horizontalVelocity + distToLandingX * 8 * dt
        -- Apply damping to horizontal velocity
        self.horizontalVelocity = self.horizontalVelocity * (1 - 3 * dt)

        -- Rotation during flight (slows down with squash recovery)
        self.rotation = self.rotation + self.rotationSpeed * dt

        -- Face changes at controlled rate (not every frame)
        self.faceChangeTimer = self.faceChangeTimer + dt
        if self.faceChangeTimer >= self.faceChangeInterval then
            self.faceChangeTimer = 0
            self.animValue = math.random(1, 6)
        end

        -- Bounce when hitting ground (ground is at landingOffsetY)
        if self.throwHeight >= self.landingOffsetY then
            self.throwHeight = self.landingOffsetY
            self.bounceCount = self.bounceCount + 1

            -- Squash on impact
            self.squash = 0.7

            -- Decreasing bounce height each time
            local bounciness = 0.5
            local bounceDecay = math.max(0, 1 - (self.bounceCount / (self.maxBounces + 1)))
            self.throwVelocity = -math.abs(self.throwVelocity) * bounciness * bounceDecay

            -- Slow down rotation on bounce, nudge toward final rotation
            self.rotationSpeed = self.rotationSpeed * 0.3
            -- Gently steer rotation toward final tilt
            local rotationDiff = self.finalRotation - self.rotation
            self.rotation = self.rotation + rotationDiff * 0.3

            -- Change face on each bounce
            self.animValue = math.random(1, 6)

            -- Check if animation should end (velocity is negligible)
            local isSettled = math.abs(self.throwVelocity) < 20 and
                math.abs(self.horizontalVelocity) < 5 and
                math.abs(distToLandingX) < 1

            if self.bounceCount >= self.maxBounces or isSettled then
                -- Animation complete - settle at final position with final tilt
                self.horizontalOffset = self.landingOffsetX
                self.throwHeight = self.landingOffsetY
                self.rotation = self.finalRotation
                self.squash = 1.0
                self.throwVelocity = 0
                self.horizontalVelocity = 0
                self.isAnimating = false
            end
        end

        -- Recover squash over time
        self.squash = self.squash + (1.0 - self.squash) * dt * 12

        -- Slow down rotation over time (air resistance) and drift toward final tilt
        self.rotationSpeed = self.rotationSpeed * (1 - 2 * dt)
    end

    -- Position animation (lerp towards target)
    if self.targetX and self.targetY and not self.isDragging then
        local dx = self.targetX - self.x
        local dy = self.targetY - self.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < 2 then
            -- Snap to target
            self.x = self.targetX
            self.y = self.targetY
            self.targetX = nil
            self.targetY = nil
        else
            -- Move towards target
            local moveAmount = self.animationSpeed * dt
            local ratio = math.min(moveAmount / dist, 1)
            self.x = self.x + dx * ratio
            self.y = self.y + dy * ratio
        end
    end
end

function DiceDisplay:mousepressed(x, y, button)
    if button == 1 and self:containsPoint(x, y) then
        self.onClick(self.index)
        return true
    end
    return false
end

function DiceDisplay:draw()
    local data = self.getDiceData()
    local value = self.isAnimating and self.animValue or data.value
    local locked = data.locked

    -- Calculate draw position with throw offset and horizontal roll-in
    -- horizontalOffset and throwHeight include the final landing offsets
    local drawX = self.x + self.horizontalOffset
    local drawY = self.y + self.throwHeight

    -- Draw shadow on ground - follows dice horizontally but stays on ground vertically
    -- Shadow should only appear when dice is in the air (throwHeight < landingOffsetY)
    local groundY = self.landingOffsetY -- Ground level for this die
    local airborne = self.throwHeight < groundY - 2
    if airborne then
        local height = math.abs(self.throwHeight - groundY)
        local shadowScale = 1.0 + height / 200
        local shadowAlpha = math.min(0.4, 0.15 + height / 300)
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        local shadowW = self.size * 0.5 * shadowScale
        local shadowH = self.size * 0.12
        -- Shadow follows dice horizontally but stays on ground
        local shadowX = drawX + self.size / 2
        local shadowY = self.y + groundY + self.size - 5
        love.graphics.ellipse("fill", shadowX, shadowY, shadowW / 2, shadowH / 2)
    end

    -- Draw dice face image
    local diceImage = Theme.images.diceFaces[value]
    if diceImage then
        local iw, ih = diceImage:getDimensions()
        local baseScale = self.size / math.max(iw, ih)

        -- Apply squash (compress Y, expand X)
        local scaleX = baseScale * (2 - self.squash)
        local scaleY = baseScale * self.squash

        local centerX = drawX + self.size / 2
        local centerY = drawY + self.size / 2

        -- Tint for locked state
        if locked then
            love.graphics.setColor(0.7, 0.9, 1.0, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end

        love.graphics.draw(
            diceImage,
            centerX, centerY,
            self.rotation,
            scaleX, scaleY,
            iw / 2, ih / 2
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return DiceDisplay
