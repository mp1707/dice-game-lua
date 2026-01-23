-- Button component with 9-slice background

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Sound = require("src.core.sound")

local Button = {}
Button.__index = Button

function Button.new(config)
    local self = setmetatable({}, Button)

    self.x = config.x or 0
    self.y = config.y or 0
    self.width = config.width or 100
    self.height = config.height or 40
    self.text = config.text or ""
    self.onClick = config.onClick or function() end
    self.enabled = config.enabled ~= false

    -- Optional styling
    self.bgColor = config.bgColor or Theme.colors.surface2
    self.textColor = config.textColor or Theme.colors.text
    self.disabledBgColor = config.disabledBgColor or Theme.colors.surface
    self.disabledTextColor = config.disabledTextColor or Theme.colors.textMuted
    self.hoverBgColor = config.hoverBgColor or Theme.colors.surfaceHighlight
    self.font = config.font or Theme.fonts.large

    -- State
    self.isHovered = false
    self.isPressed = false

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    return self
end

function Button:setEnabled(enabled)
    self.enabled = enabled
end

function Button:setText(text)
    self.text = text
end

function Button:setPosition(x, y)
    self.x = x
    self.y = y
end

function Button:containsPoint(px, py)
    return px >= self.x and px < self.x + self.width and
        py >= self.y and py < self.y + self.height
end

function Button:update(dt)
    local mx, my = love.mouse.getPosition()
    -- Use global screenToGame if available for proper scaling
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end
    -- If mouse is outside viewport (nil values), don't hover
    if mx == nil or my == nil then
        self.isHovered = false
        return
    end
    self.isHovered = self:containsPoint(mx, my) and self.enabled
end

function Button:mousepressed(x, y, button)
    if button == 1 and self:containsPoint(x, y) and self.enabled then
        self.isPressed = true
        return true
    end
    return false
end

function Button:mousereleased(x, y, button)
    if button == 1 and self.isPressed then
        self.isPressed = false
        if self:containsPoint(x, y) and self.enabled then
            Sound:play("lightClick")
            self.onClick()
            return true
        end
    end
    return false
end

function Button:draw()
    -- 3D shadow offset
    local shadowOffset = 4
    local pressOffset = self.isPressed and shadowOffset or 0

    -- Determine colors based on state
    local bgColor, textColor

    if not self.enabled then
        bgColor = self.disabledBgColor
        textColor = self.disabledTextColor
    elseif self.isPressed then
        bgColor = self.bgColor -- Keep same color when pressed, just moved
        textColor = self.textColor
    elseif self.isHovered then
        bgColor = self.hoverBgColor
        textColor = self.textColor
    else
        bgColor = self.bgColor
        textColor = self.textColor
    end

    -- Draw shadow (darker version of bg, offset down)
    local shadowColor = { 0, 0, 0, 0.4 }
    self.nineSlice:draw(self.x, self.y + shadowOffset, self.width, self.height, shadowColor, Theme.nineSlice.borderScale)

    -- Draw 9-slice background (offset when pressed)
    self.nineSlice:draw(self.x, self.y + pressOffset, self.width, self.height, bgColor, Theme.nineSlice.borderScale)

    -- Draw text centered with shadow (offset when pressed)
    local textHeight = self.font:getHeight()
    local textY = self.y + pressOffset + (self.height - textHeight) / 2

    Theme:drawTextCenteredWithShadow(self.text, self.x, textY, self.width, self.font, textColor)
    love.graphics.setColor(1, 1, 1, 1)
end

return Button
