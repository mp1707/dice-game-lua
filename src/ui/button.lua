-- Button component with 9-slice background

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

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
            self.onClick()
            return true
        end
    end
    return false
end

function Button:draw()
    -- Determine colors based on state
    local bgColor, textColor

    if not self.enabled then
        bgColor = self.disabledBgColor
        textColor = self.disabledTextColor
    elseif self.isPressed then
        bgColor = Theme.colors.surface
        textColor = self.textColor
    elseif self.isHovered then
        bgColor = self.hoverBgColor
        textColor = self.textColor
    else
        bgColor = self.bgColor
        textColor = self.textColor
    end

    -- Draw 9-slice background
    self.nineSlice:draw(self.x, self.y, self.width, self.height, bgColor, Theme.nineSlice.borderScale)

    -- Draw text centered
    love.graphics.setFont(self.font)
    love.graphics.setColor(textColor)

    local textWidth = self.font:getWidth(self.text)
    local textHeight = self.font:getHeight()
    local textX = self.x + (self.width - textWidth) / 2
    local textY = self.y + (self.height - textHeight) / 2

    love.graphics.print(self.text, math.floor(textX), math.floor(textY))
    love.graphics.setColor(1, 1, 1, 1)
end

return Button
