-- Global Mouse Selection Feedback
-- Manages the visual feedback for the drag-to-select rectangle (fidget feature)
-- Independent of game state, works everywhere

local Theme = require("src.ui.theme")
local Scaling = require("src.core.scaling")

local MouseSelection = {
    isActive = false,
    startX = 0,
    startY = 0,
    currentX = 0,
    currentY = 0,
    button = 1, -- 1 = left (select), 2 = right (deselect)
}

function MouseSelection:mousepressed(x, y, button)
    -- Only track left (1) or right (2) mouse buttons
    if button ~= 1 and button ~= 2 then return end

    -- In main.lua, coordinates are already converted to game space
    -- But if this is called from love.mousepressed directly, we might need conversion.
    -- We'll assume the caller passes GAME coordinates (like stateMachine)

    self.isActive = true
    self.startX = x
    self.startY = y
    self.currentX = x
    self.currentY = y
    self.button = button
end

function MouseSelection:mousemoved(x, y)
    if not self.isActive then return end

    self.currentX = x
    self.currentY = y
end

function MouseSelection:mousereleased(x, y, button)
    if not self.isActive then return end
    if self.button ~= button then return end -- Ignore if different button released

    self.isActive = false
end

function MouseSelection:draw()
    if not self.isActive then return end

    local x = math.min(self.startX, self.currentX)
    local width = math.abs(self.currentX - self.startX)
    local y = math.min(self.startY, self.currentY)
    local height = math.abs(self.currentY - self.startY)

    -- Determine colors based on button
    local debugColor = { 1, 1, 1, 1 }
    local fillColor
    local borderColor

    if self.button == 2 then
        -- Right click = Deselect = Purple
        fillColor = Theme.colors.deselectionRect
        borderColor = Theme.colors.deselectionRectBorder
    else
        -- Left click = Select = Cyan
        fillColor = Theme.colors.selectionRect
        borderColor = Theme.colors.selectionRectBorder
    end

    -- Draw fill
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x, y, width, height)

    -- Draw border
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(Theme.dimensions.borderWidthThin) -- 1px
    love.graphics.rectangle("line", x, y, width, height)

    love.graphics.setColor(1, 1, 1, 1)
end

function MouseSelection:getRect()
    if not self.isActive then return nil end

    local x1 = math.min(self.startX, self.currentX)
    local x2 = math.max(self.startX, self.currentX)
    local y1 = math.min(self.startY, self.currentY)
    local y2 = math.max(self.startY, self.currentY)

    return {
        x1 = x1,
        y1 = y1,
        x2 = x2,
        y2 = y2,
        isDeselecting = (self.button == 2)
    }
end

return MouseSelection
