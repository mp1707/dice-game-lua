-- Checkbox component for mute toggle
-- Box with label, toggles on click

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Sound = require("src.core.sound")

local Checkbox = {}
Checkbox.__index = Checkbox

function Checkbox.new(config)
    local self = setmetatable({}, Checkbox)

    self.x = config.x or 0
    self.y = config.y or 0
    self.label = config.label or "Mute"
    self.checked = config.checked or false
    self.onChange = config.onChange or function() end

    -- Checkbox dimensions
    self.boxSize = 28

    -- State
    self.isHovered = false
    self.isPressed = false

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    return self
end

function Checkbox:setChecked(checked)
    self.checked = checked
end

function Checkbox:isChecked()
    return self.checked
end

function Checkbox:getWidth()
    local labelWidth = Theme.fonts.normal:getWidth(self.label)
    return labelWidth + 12 + self.boxSize
end

function Checkbox:getHeight()
    return math.max(self.boxSize, Theme.fonts.normal:getHeight())
end

function Checkbox:containsPoint(px, py)
    local width = self:getWidth()
    local height = self:getHeight()
    return px >= self.x and px < self.x + width and
        py >= self.y and py < self.y + height
end

function Checkbox:update(dt)
    local mx, my = love.mouse.getPosition()
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end

    if mx == nil or my == nil then
        self.isHovered = false
        return
    end

    self.isHovered = self:containsPoint(mx, my)
end

function Checkbox:mousepressed(x, y, button)
    if button ~= 1 then return false end

    if self:containsPoint(x, y) then
        self.isPressed = true
        return true
    end

    return false
end

function Checkbox:mousereleased(x, y, button)
    if button ~= 1 then return false end

    if self.isPressed then
        self.isPressed = false
        if self:containsPoint(x, y) then
            self.checked = not self.checked
            Sound:play("lightClick")
            self.onChange(self.checked)
            return true
        end
    end

    return false
end

function Checkbox:draw()
    local height = self:getHeight()

    -- Draw label on left
    local labelY = self.y + (height - Theme.fonts.normal:getHeight()) / 2
    Theme:drawTextWithShadow(self.label, self.x, labelY, Theme.fonts.normal, Theme.colors.text)

    -- Draw checkbox box on right
    local labelWidth = Theme.fonts.normal:getWidth(self.label)
    local boxX = self.x + labelWidth + 12
    local boxY = self.y + (height - self.boxSize) / 2

    -- Box background
    local boxColor = self.checked and Theme.colors.cyan or Theme.colors.panelDark
    self.nineSlice:draw(boxX, boxY, self.boxSize, self.boxSize, boxColor, Theme.nineSlice.borderScale)

    -- Hover highlight
    if self.isHovered then
        love.graphics.setColor(1, 1, 1, 0.1)
        love.graphics.rectangle("fill", boxX, boxY, self.boxSize, self.boxSize, 4)
    end

    -- Draw checkmark when checked
    if self.checked then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(3)

        local cx = boxX + self.boxSize / 2
        local cy = boxY + self.boxSize / 2
        local size = self.boxSize * 0.3

        -- Draw checkmark (two lines forming a V shape)
        love.graphics.line(
            cx - size, cy,
            cx - size * 0.3, cy + size * 0.7,
            cx + size, cy - size * 0.5
        )

        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Checkbox
