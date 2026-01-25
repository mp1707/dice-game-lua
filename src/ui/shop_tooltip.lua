-- Shop Tooltip Component
-- Simple text tooltip that appears above shop items
-- Shows item name on hover after delay

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Juice = require("src.ui.juice")

local ShopTooltip = {}
ShopTooltip.__index = ShopTooltip

-- Singleton instance
local instance = nil

function ShopTooltip.getInstance()
    if not instance then
        instance = ShopTooltip.new()
    end
    return instance
end

function ShopTooltip.new()
    local self = setmetatable({}, ShopTooltip)

    self.nineSlice = NineSlice.getInstance()

    -- State
    self.visible = false
    self.text = ""
    self.x = 0
    self.y = 0

    -- Dimensions (calculated from text)
    self.width = 0
    self.height = 0
    self.padding = Theme.spacing.md

    -- Animation
    self.alpha = 0
    self.scale = 0.9
    self.scaleVelocity = 0

    return self
end

function ShopTooltip:show(text, anchorX, anchorY)
    self.visible = true
    self.text = text

    -- Calculate dimensions
    local font = Theme.fonts.normal
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()

    self.width = textWidth + self.padding * 2
    self.height = textHeight + self.padding * 2

    -- Position above anchor
    self.x = anchorX - self.width / 2
    self.y = anchorY - self.height - 15

    -- Clamp to screen bounds
    local margin = 20
    self.x = math.max(margin, math.min(Theme.screen.width - self.width - margin, self.x))
    self.y = math.max(margin, math.min(Theme.screen.height - self.height - margin, self.y))
end

function ShopTooltip:hide()
    self.visible = false
end

function ShopTooltip:update(dt)
    -- Animate visibility
    local targetAlpha = self.visible and 1 or 0
    self.alpha = self.alpha + (targetAlpha - self.alpha) * dt * 12

    -- Spring animation for scale
    local targetScale = self.visible and 1 or 0.9
    self.scale, self.scaleVelocity = Juice.updateSpring(
        self.scale, targetScale, self.scaleVelocity,
        500, 30, dt
    )
end

function ShopTooltip:isVisible()
    return self.visible and self.alpha > 0.1
end

function ShopTooltip:draw()
    if self.alpha < 0.01 then return end
    if not self.text or self.text == "" then return end

    -- Calculate center for scaling
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-self.width / 2, -self.height / 2)

    -- Draw background panel
    local bgColor = {
        Theme.colors.panelDark[1],
        Theme.colors.panelDark[2],
        Theme.colors.panelDark[3],
        self.alpha * 0.95
    }
    self.nineSlice:draw(0, 0, self.width, self.height, bgColor, Theme.nineSlice.borderScale)

    -- Draw text
    local font = Theme.fonts.normal
    love.graphics.setFont(font)

    local textX = self.padding
    local textY = self.padding

    -- Text with alpha
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.print(self.text, textX, textY)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return ShopTooltip
