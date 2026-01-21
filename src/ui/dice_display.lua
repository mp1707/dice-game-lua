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

    -- Position animation state (for moving to/from held tray)
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

    -- 9-slice renderer (for potential UI elements)
    self.nineSlice = NineSlice.getInstance()

    -- Bounce callback for screen shake
    self.die.onBounce = function(bounceNum, maxBounces)
        local intensity, duration = Juice.getBounceShake(bounceNum, maxBounces)
        Juice.triggerShake(intensity, duration)
    end

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
        self.y                  -- ground Y
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
end

-- Start dragging the die
function DiceDisplay:startDrag(mouseX, mouseY)
    self.isDragging = true
    self.dragOffsetX = self.x - mouseX
    self.dragOffsetY = self.y - mouseY
    -- Cancel any position animation
    self.targetX = nil
    self.targetY = nil
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

    -- Position animation (lerp towards target) - for tray movement
    if self.targetX and self.targetY and not self.isDragging and not self.isAnimating then
        local dx = self.targetX - self.x
        local dy = self.targetY - self.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < 2 then
            -- Snap to target
            self.x = self.targetX
            self.y = self.targetY
            self.targetX = nil
            self.targetY = nil
            -- Update die position
            self.die.x = self.x
            self.die.y = self.y
            self.die.slotCenterX = self.x + self.size / 2
        else
            -- Move towards target
            local moveAmount = self.animationSpeed * dt
            local ratio = math.min(moveAmount / dist, 1)
            self.x = self.x + dx * ratio
            self.y = self.y + dy * ratio
            -- Update die position
            self.die.x = self.x
            self.die.y = self.y
            self.die.slotCenterX = self.x + self.size / 2
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
    local locked = data.locked

    -- During roll animation, delegate to die
    if self.isAnimating then
        -- Draw shadow
        self.die:drawShadow()
        -- Draw die
        self.die:draw()
    else
        -- Static rendering (not animating)
        local value = data.value

        -- Draw dice face image
        local diceImage = Theme.images.diceFaces[value]
        if diceImage then
            local iw, ih = diceImage:getDimensions()
            local baseScale = self.size / math.max(iw, ih)

            local centerX = self.x + self.size / 2
            local centerY = self.y + self.size / 2

            -- No tint - dice are distinguished by position only
            love.graphics.setColor(1, 1, 1, 1)

            love.graphics.draw(
                diceImage,
                centerX, centerY,
                0, -- no rotation when static
                baseScale, baseScale,
                iw / 2, ih / 2
            )
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return DiceDisplay
