-- Dice display component
-- Shows a single die with value and lock state
-- Supports drag-and-drop and smooth position animation
-- Integrates with new animation system for roll animations

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Die = require("src.dice.die")
local Physics = require("src.dice.physics")
local Shadow = require("src.dice.shadow")
local Juice = require("src.dice.juice")

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

    -- Create the Die object for animation
    local slotCenterX = self.x + self.size / 2
    self.die = Die.new(self.index, slotCenterX, self.y, self.size)

    -- Animation state tracking
    self.isAnimating = false

    -- Spring position animation state
    self.targetX = nil
    self.targetY = nil
    self.velocityX = 0
    self.velocityY = 0
    -- Stiffness: How strong the spring is (speed)
    -- Damping: friction (prevents endless oscillation)
    self.moveStiffness = 180
    self.moveDamping = 20

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

    -- 9-slice renderer (for potential UI elements)
    self.nineSlice = NineSlice.getInstance()

    -- Bounce callback for screen shake
    self.die.onBounce = function(bounceNum, maxBounces)
        local intensity, duration = Juice.getBounceShake(bounceNum, maxBounces)
        Juice.triggerShake(intensity, duration)
    end

    -- =========================================================================
    -- JUICE ANIMATION STATE
    -- =========================================================================

    -- Breathing animation (always active)
    self.breathingTime = 0

    -- Hover state (Balatro-style tilt)
    self.isHovered = false
    self.hoverRotation = 0
    self.hoverScaleX = 1
    self.hoverScaleY = 1
    self.targetHoverRotation = 0
    self.targetHoverScaleX = 1
    self.targetHoverScaleY = 1

    -- Selection spring animation
    self.selectionScale = 1
    self.selectionScaleVelocity = 0
    self.selectionYOffset = 0
    self.selectionYVelocity = 0
    self.wasSelected = false

    -- Held state (mouse down on die)
    self.isHeld = false
    self.heldScale = 1
    self.targetHeldScale = 1

    -- Mouse position (updated by play_state)
    self.mouseX = 0
    self.mouseY = 0

    return self
end

function DiceDisplay:setPosition(x, y)
    self.x = x
    self.y = y
    self.die.x = x
    self.die.y = y
    self.die.slotCenterX = x + self.size / 2
end

function DiceDisplay:setHomePosition(x, y)
    self.homeX = x
    self.homeY = y
end

function DiceDisplay:containsPoint(px, py)
    -- During animation, use the die's visual position
    local checkX = self.x
    local checkY = self.y

    if self.isAnimating then
        checkX = self.die.x
        checkY = self.die.y - self.die.height
    end

    return px >= checkX and px < checkX + self.size and
        py >= checkY and py < checkY + self.size
end

function DiceDisplay:startRollAnimation(duration)
    self.isAnimating = true

    -- Generate roll parameters
    local params = Physics.generateRollParams(
        self.index,
        self.x + self.size / 2, -- slot center
        self.homeY              -- ground Y (always use table level, even if elevated)
    )

    -- Get the target face from game state
    local data = self.getDiceData()
    params.targetFace = data.value

    -- Start the die animation
    self.die:startRoll(params)
end

function DiceDisplay:stopAnimation()
    self.isAnimating = false
    -- Reset die to idle at current position
    self.die:resetToIdle(self.x, self.y)
    -- Update face from game state
    local data = self.getDiceData()
    self.die:setFace(data.value)
    -- Set a random orientation for visual variety
    self.die.orientation = math.random(1, 4)
end

-- Start dragging the die
function DiceDisplay:startDrag(mouseX, mouseY)
    self.isDragging = true
    self.dragOffsetX = self.x - mouseX
    self.dragOffsetY = self.y - mouseY
    -- Cancel any position animation
    self.targetX = nil
    self.targetY = nil
    self.velocityX = 0
    self.velocityY = 0
    -- Stop roll animation if in progress
    if self.isAnimating then
        self:stopAnimation()
    end
end

-- Update position while dragging
function DiceDisplay:updateDrag(mouseX, mouseY)
    if self.isDragging then
        self.x = mouseX + self.dragOffsetX
        self.y = mouseY + self.dragOffsetY
        -- Keep die position in sync
        self.die.x = self.x
        self.die.y = self.y
        self.die.slotCenterX = self.x + self.size / 2
    end
end

-- End drag and return held state info for selection logic
function DiceDisplay:endDrag()
    self.isDragging = false
    self.isHeld = false
    self.targetHeldScale = 1
    self.velocityX = 0
    self.velocityY = 0
    return self.y -- Return current Y position for selection logic
end

-- Set held state (mouse pressed but not necessarily dragging yet)
function DiceDisplay:setHeld(held)
    self.isHeld = held
    self.targetHeldScale = held and 1.12 or 1
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
    self.velocityX = 0
    self.velocityY = 0
    -- Update die position
    self.die.x = x
    self.die.y = y
    self.die.slotCenterX = x + self.size / 2
end

function DiceDisplay:update(dt)
    -- Update roll animation if active
    if self.isAnimating then
        self.die:update(dt)

        -- Check if animation completed
        if self.die:isStable() then
            self.isAnimating = false
            -- Sync position back
            self.x = self.die.x
            self.y = self.die.y
        end
    end

    -- Spring Position Animation (Snap-back)
    -- Uses spring physics for a "rubber band" effect
    if self.targetX and self.targetY and not self.isDragging and not self.isAnimating then
        local finishedX = false
        local finishedY = false

        -- Update X spring
        self.x, self.velocityX = Juice.updateSpring(
            self.x, self.targetX, self.velocityX,
            self.moveStiffness, self.moveDamping, dt
        )

        -- Update Y spring
        self.y, self.velocityY = Juice.updateSpring(
            self.y, self.targetY, self.velocityY,
            self.moveStiffness, self.moveDamping, dt
        )

        -- Check stability (Juice.updateSpring snaps if very close and slow)
        if self.x == self.targetX and self.velocityX == 0 then finishedX = true end
        if self.y == self.targetY and self.velocityY == 0 then finishedY = true end

        -- Clear target if stable
        if finishedX and finishedY then
            self.targetX = nil
            self.targetY = nil
        end

        -- Sync die position
        self.die.x = self.x
        self.die.y = self.y
        self.die.slotCenterX = self.x + self.size / 2
    end

    -- =========================================================================
    -- JUICE ANIMATIONS (only when not roll-animating)
    -- =========================================================================
    if not self.isAnimating then
        -- Update breathing animation timer
        self.breathingTime = self.breathingTime + dt

        -- Check selection state change for spring animation
        local data = self.getDiceData()
        local isSelected = data.locked

        if isSelected and not self.wasSelected then
            -- Just got selected - trigger pop animation
            local popScale, popY, _, _ = Juice.getSelectionPopParams()
            self.selectionScale = popScale
            self.selectionYOffset = popY
            self.selectionScaleVelocity = 0
            self.selectionYVelocity = 0
        elseif not isSelected and self.wasSelected then
            -- Just got deselected - trigger smaller pop
            local popScale, popY, _, _ = Juice.getDeselectionPopParams()
            self.selectionScale = popScale
            self.selectionYOffset = popY
            self.selectionScaleVelocity = 0
            self.selectionYVelocity = 0
        end
        self.wasSelected = isSelected

        -- Update spring physics for selection animation
        local _, _, stiffness, damping = Juice.getSelectionPopParams()
        self.selectionScale, self.selectionScaleVelocity = Juice.updateSpring(
            self.selectionScale, 1, self.selectionScaleVelocity,
            stiffness, damping, dt
        )
        self.selectionYOffset, self.selectionYVelocity = Juice.updateSpring(
            self.selectionYOffset, 0, self.selectionYVelocity,
            stiffness, damping, dt
        )

        -- Update hover effects
        local centerX = self.x + self.size / 2
        local centerY = self.y + self.size / 2
        self.targetHoverRotation, self.targetHoverScaleX, self.targetHoverScaleY, self.isHovered =
            Juice.getHoverEffects(self.mouseX, self.mouseY, centerX, centerY, self.size)

        -- Smooth interpolation for hover (fluid response)
        local hoverLerp = 12 * dt
        self.hoverRotation = self.hoverRotation + (self.targetHoverRotation - self.hoverRotation) * hoverLerp
        self.hoverScaleX = self.hoverScaleX + (self.targetHoverScaleX - self.hoverScaleX) * hoverLerp
        self.hoverScaleY = self.hoverScaleY + (self.targetHoverScaleY - self.hoverScaleY) * hoverLerp

        -- Update held scale smoothly
        self.heldScale = self.heldScale + (self.targetHeldScale - self.heldScale) * hoverLerp
    end
end

-- Update hover state with current mouse position
function DiceDisplay:updateHover(mouseX, mouseY)
    self.mouseX = mouseX
    self.mouseY = mouseY
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
    local locked = data.locked

    -- During roll animation, delegate to die
    if self.isAnimating then
        -- Draw shadow
        self.die:drawShadow()
        -- Draw die
        self.die:draw()
    else
        -- Static rendering (not animating) using spritesheet
        local value = data.value
        local Spritesheet = Theme.diceSpritesheet

        if Spritesheet then
            local orientation = self.die.orientation or 1
            local quad = Spritesheet:getQuad(value, orientation)
            local image = Spritesheet:getImage()
            local spriteW, spriteH = Spritesheet:getSpriteSize()

            -- Base scale
            local baseScale = self.size / math.max(spriteW, spriteH)

            -- Get breathing animation values (disabled when held)
            local breathScale, breathY = 1, 0
            if not self.isHeld and not self.isDragging then
                breathScale, breathY = Juice.getBreathingValues(self.breathingTime, self.index)
            end

            -- Combine all scale effects (include held scale)
            local finalScaleX = baseScale * breathScale * self.selectionScale * self.hoverScaleX * self.heldScale
            local finalScaleY = baseScale * breathScale * self.selectionScale * self.hoverScaleY * self.heldScale

            -- Calculate position with breathing and selection offsets
            local centerX = self.x + self.size / 2
            local centerY = self.y + self.size / 2 + breathY + self.selectionYOffset

            -- No tint - dice are distinguished by position only
            love.graphics.setColor(1, 1, 1, 1)

            love.graphics.draw(
                image,
                quad,
                centerX, centerY,
                self.hoverRotation, -- Balatro-style tilt
                finalScaleX, finalScaleY,
                spriteW / 2, spriteH / 2
            )
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return DiceDisplay
