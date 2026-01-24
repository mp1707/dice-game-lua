-- Slider component for volume control
-- Draggable thumb on a track, value 0-1

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Sound = require("src.core.sound")

local Slider = {}
Slider.__index = Slider

function Slider.new(config)
    local self = setmetatable({}, Slider)

    self.x = config.x or 0
    self.y = config.y or 0
    self.width = config.width or 200
    self.height = config.height or 40

    self.value = config.value or 0.5
    self.enabled = config.enabled ~= false
    self.onChange = config.onChange or function() end

    -- Track dimensions
    self.trackHeight = 12
    self.thumbSize = 24

    -- State
    self.isDragging = false
    self.isHovered = false

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    return self
end

function Slider:setValue(value)
    self.value = math.max(0, math.min(1, value))
end

function Slider:getValue()
    return self.value
end

function Slider:setEnabled(enabled)
    self.enabled = enabled
    if not enabled then
        self.isDragging = false
    end
end

function Slider:getTrackBounds()
    local trackY = self.y + (self.height - self.trackHeight) / 2
    return self.x, trackY, self.width, self.trackHeight
end

function Slider:getThumbBounds()
    local trackX, trackY, trackW, trackH = self:getTrackBounds()
    local thumbX = trackX + (trackW - self.thumbSize) * self.value
    local thumbY = self.y + (self.height - self.thumbSize) / 2
    return thumbX, thumbY, self.thumbSize, self.thumbSize
end

function Slider:containsPoint(px, py)
    return px >= self.x and px < self.x + self.width and
        py >= self.y and py < self.y + self.height
end

function Slider:thumbContainsPoint(px, py)
    local tx, ty, tw, th = self:getThumbBounds()
    return px >= tx and px < tx + tw and
        py >= ty and py < ty + th
end

function Slider:updateValueFromMouse(mx)
    local trackX, _, trackW, _ = self:getTrackBounds()
    local newValue = (mx - trackX) / trackW
    newValue = math.max(0, math.min(1, newValue))

    if newValue ~= self.value then
        self.value = newValue
        self.onChange(self.value)
    end
end

function Slider:update(dt)
    if not self.enabled then
        self.isHovered = false
        return
    end

    local mx, my = love.mouse.getPosition()
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end

    if mx == nil or my == nil then
        self.isHovered = false
        return
    end

    self.isHovered = self:containsPoint(mx, my)

    -- Continue dragging even if mouse leaves bounds
    if self.isDragging then
        self:updateValueFromMouse(mx)
    end
end

function Slider:mousepressed(x, y, button)
    if not self.enabled then return false end
    if button ~= 1 then return false end

    if self:containsPoint(x, y) then
        self.isDragging = true
        self:updateValueFromMouse(x)
        return true
    end

    return false
end

function Slider:mousereleased(x, y, button)
    if button ~= 1 then return false end

    if self.isDragging then
        self.isDragging = false
        Sound:play("lightClick")
        return true
    end

    return false
end

function Slider:draw()
    local trackX, trackY, trackW, trackH = self:getTrackBounds()

    -- Determine colors based on state
    local trackColor = self.enabled and Theme.colors.panelDark or Theme.colors.surface
    local fillColor = self.enabled and Theme.colors.cyan or Theme.colors.textMuted
    local thumbColor = self.enabled and Theme.colors.surface2 or Theme.colors.surface

    -- Draw track background
    self.nineSlice:draw(trackX, trackY, trackW, trackH, trackColor, Theme.nineSlice.borderScale)

    -- Draw filled portion
    local fillWidth = trackW * self.value
    if fillWidth > 0 then
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", trackX, trackY, fillWidth, trackH, 6)
    end

    -- Draw thumb
    local thumbX, thumbY, thumbW, thumbH = self:getThumbBounds()

    -- Thumb shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", thumbX + 2, thumbY + 2, thumbW, thumbH, thumbW / 2)

    -- Thumb body
    love.graphics.setColor(thumbColor)
    love.graphics.rectangle("fill", thumbX, thumbY, thumbW, thumbH, thumbW / 2)

    -- Thumb highlight when hovered/dragging
    if self.enabled and (self.isHovered or self.isDragging) then
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("fill", thumbX, thumbY, thumbW, thumbH, thumbW / 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Slider
