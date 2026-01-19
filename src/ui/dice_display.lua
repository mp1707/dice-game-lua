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
    self.animDuration = 0.5

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
    self.animDuration = duration or 0.5
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
    -- Roll animation
    if self.isAnimating then
        self.animTimer = self.animTimer + dt
        -- Rapidly change display value during animation
        self.animValue = math.random(1, 6)

        if self.animTimer >= self.animDuration then
            self.isAnimating = false
        end
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

    -- Background color based on lock state
    local bgColor = locked and Theme.colors.cyan or Theme.colors.surface2

    -- Draw highlight when dragging
    if self.isDragging then
        love.graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.3)
        love.graphics.rectangle("fill", self.x - 6, self.y - 6, self.size + 12, self.size + 12, 14)
    end

    -- Draw background
    self.nineSlice:draw(self.x, self.y, self.size, self.size, bgColor, Theme.nineSlice.borderScale)

    -- Draw border if locked
    if locked then
        love.graphics.setColor(Theme.colors.text)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.x + 2, self.y + 2, self.size - 4, self.size - 4, 8)
    end

    -- Draw value
    local textColor = locked and Theme.colors.textDark or Theme.colors.text
    love.graphics.setColor(textColor)
    love.graphics.setFont(Theme.fonts.huge)

    local text = tostring(value)
    local textWidth = Theme.fonts.huge:getWidth(text)
    local textHeight = Theme.fonts.huge:getHeight()
    local textX = self.x + (self.size - textWidth) / 2
    local textY = self.y + (self.size - textHeight) / 2

    love.graphics.print(text, math.floor(textX), math.floor(textY))

    -- Draw lock indicator text
    if locked then
        love.graphics.setFont(Theme.fonts.small)
        love.graphics.setColor(Theme.colors.textDark)
        local lockText = "LOCK"
        local lockWidth = Theme.fonts.small:getWidth(lockText)
        love.graphics.print(lockText, self.x + (self.size - lockWidth) / 2, self.y + self.size - 20)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return DiceDisplay
