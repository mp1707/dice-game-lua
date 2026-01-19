-- Dice display component
-- Shows a single die with value and lock state
-- Supports drag-and-drop and smooth position animation

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
    self.throwHeight = 0          -- Current Y offset (negative = up)
    self.throwVelocity = 0        -- Vertical velocity
    self.bounceCount = 0          -- Number of bounces completed
    self.maxBounces = 3           -- Total bounces before settling
    self.faceChangeTimer = 0      -- Timer for face changes
    self.faceChangeInterval = 0.08 -- ~12fps face changes (slower)
    self.rotation = 0             -- Current rotation
    self.rotationSpeed = 0        -- Rotation velocity
    self.squash = 1.0             -- Squash/stretch factor

    -- Position animation state
    self.targetX = nil
    self.targetY = nil
    self.animationSpeed = 1200  -- pixels per second

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

    -- Initialize throw physics
    self.throwHeight = 0
    self.throwVelocity = -400 - math.random() * 200  -- Random upward velocity
    self.bounceCount = 0
    self.rotation = 0
    self.rotationSpeed = (math.random() - 0.5) * 15  -- Random spin direction
    self.squash = 1.0
    self.faceChangeTimer = 0
end

function DiceDisplay:stopAnimation()
    self.isAnimating = false
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
        local gravity = 2000  -- pixels/sec²

        -- Update throw height with gravity
        self.throwVelocity = self.throwVelocity + gravity * dt
        self.throwHeight = self.throwHeight + self.throwVelocity * dt

        -- Rotation during flight
        self.rotation = self.rotation + self.rotationSpeed * dt

        -- Face changes at controlled rate (not every frame)
        self.faceChangeTimer = self.faceChangeTimer + dt
        if self.faceChangeTimer >= self.faceChangeInterval then
            self.faceChangeTimer = 0
            self.animValue = math.random(1, 6)
        end

        -- Bounce when hitting ground
        if self.throwHeight >= 0 then
            self.throwHeight = 0
            self.bounceCount = self.bounceCount + 1

            -- Squash on impact
            self.squash = 0.7

            -- Decreasing bounce height each time
            local bounciness = 0.6
            self.throwVelocity = -math.abs(self.throwVelocity) * bounciness * (1 - self.bounceCount / self.maxBounces)

            -- Slow down rotation on bounce
            self.rotationSpeed = self.rotationSpeed * 0.5

            -- Change face on each bounce
            self.animValue = math.random(1, 6)

            -- End animation after max bounces
            if self.bounceCount >= self.maxBounces then
                self.isAnimating = false
                self.throwHeight = 0
                self.rotation = 0
                self.squash = 1.0
            end
        end

        -- Recover squash over time
        self.squash = self.squash + (1.0 - self.squash) * dt * 15
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

    -- Calculate draw position with throw offset
    local drawY = self.y + self.throwHeight

    -- Draw shadow on ground (spreads when dice is higher)
    local shadowScale = 1.0 + math.abs(self.throwHeight) / 200
    local shadowAlpha = 0.4 - math.abs(self.throwHeight) / 400
    if shadowAlpha > 0 then
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        local shadowW = self.size * 0.6 * shadowScale
        local shadowH = self.size * 0.15
        love.graphics.ellipse("fill",
            self.x + self.size / 2,
            self.y + self.size - 5,
            shadowW / 2, shadowH / 2)
    end

    -- Draw dice face image
    local diceImage = Theme.images.diceFaces[value]
    if diceImage then
        local iw, ih = diceImage:getDimensions()
        local baseScale = self.size / math.max(iw, ih)

        -- Apply squash (compress Y, expand X)
        local scaleX = baseScale * (2 - self.squash)
        local scaleY = baseScale * self.squash

        local centerX = self.x + self.size / 2
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
