-- Shop Item Component
-- Displays a shop item with breathing, hover tilt, and selection animations
-- Only interactive items (booster) get animations, placeholders are static

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Juice = require("src.ui.juice")

local ShopItem = {}
ShopItem.__index = ShopItem

function ShopItem.new(config)
    local self = setmetatable({}, ShopItem)

    self.x = config.x or 0
    self.y = config.y or 0
    self.size = config.size or 160
    self.index = config.index or 1

    -- Item properties
    self.itemType = config.itemType or "placeholder" -- "booster" | "placeholder" | "relic"
    self.spriteImage = config.spriteImage            -- Theme.images.gift, Theme.images.silverKey, or Theme.images.prism
    self.price = config.price                        -- number or nil
    self.name = config.name or ""                    -- For tooltip
    self.relicId = config.relicId                    -- For relic items (e.g., "prism")
    self.sold = false

    -- Interactive state
    self.isInteractive = (self.itemType == "booster" or self.itemType == "relic")
    self.isSelected = false
    self.isHovered = false

    -- Callbacks
    self.onClick = config.onClick or function() end
    self.onHoverStart = config.onHoverStart or function() end
    self.onHoverEnd = config.onHoverEnd or function() end

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    -- =========================================================================
    -- JUICE ANIMATION STATE (only used if interactive)
    -- =========================================================================

    -- Breathing animation
    self.breathingTime = 0

    -- Hover state (Balatro-style tilt)
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

    -- Mouse position
    self.mouseX = 0
    self.mouseY = 0

    return self
end

function ShopItem:setPosition(x, y)
    self.x = x
    self.y = y
end

function ShopItem:setSelected(selected)
    if self.isSelected == selected then return end

    self.isSelected = selected

    if not self.isInteractive then return end

    -- Trigger selection spring animation
    if selected then
        local initialScale, initialYOffset, _, _ = Juice.getSelectionPopParams()
        self.selectionScale = initialScale
        self.selectionYOffset = initialYOffset
    else
        local initialScale, initialYOffset, _, _ = Juice.getDeselectionPopParams()
        self.selectionScale = initialScale
        self.selectionYOffset = initialYOffset
    end
end

function ShopItem:containsPoint(px, py)
    return px >= self.x and px < self.x + self.size and
        py >= self.y and py < self.y + self.size
end

function ShopItem:update(dt)
    if not self.isInteractive or self.sold then
        return
    end

    -- Update breathing animation
    self.breathingTime = self.breathingTime + dt

    -- Update hover effects
    local centerX = self.x + self.size / 2
    local centerY = self.y + self.size / 2
    local rotation, scaleX, scaleY, isHovered = Juice.getHoverEffects(
        self.mouseX, self.mouseY, centerX, centerY, self.size
    )

    -- Track hover state changes
    local wasHovered = self.isHovered
    self.isHovered = isHovered

    if isHovered and not wasHovered then
        self.onHoverStart(self.index)
    elseif not isHovered and wasHovered then
        self.onHoverEnd(self.index)
    end

    -- Set targets for hover animation
    self.targetHoverRotation = rotation
    self.targetHoverScaleX = scaleX
    self.targetHoverScaleY = scaleY

    -- Smooth interpolation for hover effects
    local hoverLerp = 12 * dt
    self.hoverRotation = self.hoverRotation + (self.targetHoverRotation - self.hoverRotation) * hoverLerp
    self.hoverScaleX = self.hoverScaleX + (self.targetHoverScaleX - self.hoverScaleX) * hoverLerp
    self.hoverScaleY = self.hoverScaleY + (self.targetHoverScaleY - self.hoverScaleY) * hoverLerp

    -- Update selection spring animation
    local targetScale = 1
    local targetYOffset = self.isSelected and -30 or 0

    local _, _, stiffness, damping = Juice.getSelectionPopParams()
    self.selectionScale, self.selectionScaleVelocity = Juice.updateSpring(
        self.selectionScale, targetScale, self.selectionScaleVelocity,
        stiffness, damping, dt
    )
    self.selectionYOffset, self.selectionYVelocity = Juice.updateSpring(
        self.selectionYOffset, targetYOffset, self.selectionYVelocity,
        stiffness, damping, dt
    )
end

function ShopItem:updateMouse(mouseX, mouseY)
    self.mouseX = mouseX
    self.mouseY = mouseY
end

function ShopItem:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if not self.isInteractive then return false end
    if self.sold then return false end
    if not self:containsPoint(x, y) then return false end

    self.onClick(self.index)
    return true
end

function ShopItem:draw()
    -- Calculate center for transformations
    local centerX = self.x + self.size / 2
    local centerY = self.y + self.size / 2

    -- Get breathing values (only for interactive items)
    local breathScale, breathY = 1, 0
    if self.isInteractive and not self.sold then
        breathScale, breathY = Juice.getBreathingValues(self.breathingTime, self.index)
    end

    -- Calculate final transform
    local finalScale = breathScale * self.selectionScale * self.hoverScaleX
    local finalScaleY = breathScale * self.selectionScale * self.hoverScaleY
    local finalY = centerY + breathY + self.selectionYOffset
    local finalRotation = self.hoverRotation

    love.graphics.push()
    love.graphics.translate(centerX, finalY)
    love.graphics.rotate(finalRotation)
    love.graphics.scale(finalScale, finalScaleY)
    love.graphics.translate(-self.size / 2, -self.size / 2)

    -- Draw price above (before other content, so it's behind the item)
    self:drawPrice()

    -- Draw item background
    local bgColor
    if self.sold then
        bgColor = Theme.colors.panelDark
    elseif self.isSelected then
        bgColor = Theme.colors.surfaceHighlight
    elseif self.isHovered and self.isInteractive then
        bgColor = Theme.colors.surface2
    else
        bgColor = Theme.colors.surface
    end
    self.nineSlice:draw(0, 0, self.size, self.size, bgColor, Theme.nineSlice.borderScale)

    -- Draw sprite or sold label
    if self.sold then
        self:drawSoldLabel()
    else
        self:drawSprite()
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopItem:drawSprite()
    if not self.spriteImage then return end

    local spriteW = self.spriteImage:getWidth()
    local spriteH = self.spriteImage:getHeight()

    -- Scale sprite to fit with padding
    local maxSize = self.size * 0.525 -- Reduced by 30% (was 0.75)
    local scale = math.min(maxSize / spriteW, maxSize / spriteH)

    local drawW = spriteW * scale
    local drawH = spriteH * scale
    local drawX = (self.size - drawW) / 2
    local drawY = (self.size - drawH) / 2

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.spriteImage, drawX, drawY, 0, scale, scale)
end

function ShopItem:drawPrice()
    -- Draw price above the item (in local coordinates, so above y=0)
    local priceY = -30

    if self.price then
        local priceText = "$" .. tostring(self.price)
        local font = Theme.fonts.normal
        love.graphics.setFont(font)
        local textWidth = font:getWidth(priceText)
        local textX = (self.size - textWidth) / 2

        -- Shadow
        love.graphics.setColor(Theme.colors.textShadow)
        love.graphics.print(priceText, textX + 2, priceY + 2)

        -- Main text (gold color)
        love.graphics.setColor(Theme.colors.gold)
        love.graphics.print(priceText, textX, priceY)
    else
        -- Placeholder price "-$"
        local priceText = "-$"
        local font = Theme.fonts.normal
        love.graphics.setFont(font)
        local textWidth = font:getWidth(priceText)
        local textX = (self.size - textWidth) / 2

        -- Shadow
        love.graphics.setColor(Theme.colors.textShadow)
        love.graphics.print(priceText, textX + 2, priceY + 2)

        -- Main text (muted)
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.print(priceText, textX, priceY)
    end
end

function ShopItem:drawSoldLabel()
    local font = Theme.fonts.large
    love.graphics.setFont(font)
    local text = "Sold"
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    local textX = (self.size - textWidth) / 2
    local textY = (self.size - textHeight) / 2

    -- Shadow
    love.graphics.setColor(Theme.colors.textShadow)
    love.graphics.print(text, textX + 2, textY + 2)

    -- Main text
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print(text, textX, textY)
end

function ShopItem:getCenterPosition()
    local _, breathY = 1, 0
    if self.isInteractive and not self.sold then
        _, breathY = Juice.getBreathingValues(self.breathingTime, self.index)
    end

    return self.x + self.size / 2, self.y + self.size / 2 + breathY + self.selectionYOffset
end

return ShopItem
