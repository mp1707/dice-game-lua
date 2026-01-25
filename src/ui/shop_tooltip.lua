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
    self.description = nil -- Optional description for relics
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

function ShopTooltip:show(text, anchorX, anchorY, description)
    self.visible = true
    self.text = text
    self.description = description

    -- Calculate dimensions
    local titleFont = Theme.fonts.normal
    local textWidth = titleFont:getWidth(text)
    local textHeight = titleFont:getHeight()

    -- If we have a description, make the tooltip wider and taller
    if description then
        local descFont = Theme.fonts.small
        local descWidth = descFont:getWidth(description)
        local descHeight = descFont:getHeight()

        -- Use the wider of title or description
        textWidth = math.max(textWidth, descWidth)
        textHeight = textHeight + 4 + descHeight -- 4px gap between title and description
    end

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

    -- Draw title
    local titleFont = Theme.fonts.normal
    love.graphics.setFont(titleFont)

    local textX = self.padding
    local textY = self.padding

    -- Title with gold color (for relics) or white
    if self.description then
        love.graphics.setColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], self.alpha)
    else
        love.graphics.setColor(1, 1, 1, self.alpha)
    end
    love.graphics.print(self.text, textX, textY)

    -- Draw description if present
    if self.description then
        local descFont = Theme.fonts.small
        love.graphics.setFont(descFont)
        local descY = textY + titleFont:getHeight() + 4

        -- Description in muted color
        love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], self.alpha)
        love.graphics.print(self.description, textX, descY)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return ShopTooltip
