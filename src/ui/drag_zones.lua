-- Drag Zones component
-- Shows DELETE (bottom right) and SELL (top middle) zones when dragging consumables

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Stickers = require("src.game.stickers")
local GameState = require("src.game.game_state")

local DragZones = {
    _instance = nil,
}
DragZones.__index = DragZones

function DragZones.getInstance()
    if not DragZones._instance then
        DragZones._instance = DragZones.new()
    end
    return DragZones._instance
end

function DragZones.new()
    local self = setmetatable({}, DragZones)

    self.nineSlice = NineSlice.getInstance()

    -- Zone dimensions
    self.deleteZone = {
        width = 160,
        height = 100,
        x = Theme.screen.width - 160 - 40,  -- 40px from right
        y = Theme.screen.height - 100 - 40, -- 40px from bottom
    }

    self.sellZone = {
        width = 180,
        height = 80,
        x = (Theme.screen.width - 180) / 2,                           -- Centered
        y = Theme.layout.itemStripY + Theme.layout.itemSlotSize + 20, -- Below item strip
    }

    -- Animation state
    self.visible = false
    self.alpha = 0
    self.deleteHovered = false
    self.sellHovered = false

    -- Current drag info
    self.dragSlotIndex = nil
    self.sellPrice = 2

    return self
end

function DragZones:show(slotIndex, slotX, slotY, slotSize)
    self.visible = true
    self.dragSlotIndex = slotIndex

    -- Update zone positions based on slot geometry
    local padding = 20
    local zoneWidth = 160
    local zoneHeight = slotSize * 2

    -- Center vertically relative to slot
    local slotCenterY = slotY + slotSize / 2
    local zoneY = slotCenterY - zoneHeight / 2

    -- SELL Zone (Left)
    self.sellZone.width = zoneWidth
    self.sellZone.height = zoneHeight
    self.sellZone.y = zoneY
    self.sellZone.x = slotX - zoneWidth - padding

    -- DELETE Zone (Right)
    self.deleteZone.width = zoneWidth
    self.deleteZone.height = zoneHeight
    self.deleteZone.y = zoneY
    self.deleteZone.x = slotX + slotSize + padding

    -- Get sell price for the dragged consumable
    local consumable = GameState:getConsumable(slotIndex)
    if consumable then
        self.sellPrice = Stickers:getSellPrice(consumable.stickerId)
    else
        self.sellPrice = 2
    end
end

function DragZones:hide()
    self.visible = false
    self.dragSlotIndex = nil
    self.deleteHovered = false
    self.sellHovered = false
end

function DragZones:update(dt, dragX, dragY)
    -- Animate alpha
    local targetAlpha = self.visible and 1 or 0
    self.alpha = self.alpha + (targetAlpha - self.alpha) * dt * 10

    -- Check hover states
    if self.visible and dragX and dragY then
        self.deleteHovered = self:isInDeleteZone(dragX, dragY)
        self.sellHovered = self:isInSellZone(dragX, dragY)
    else
        self.deleteHovered = false
        self.sellHovered = false
    end
end

function DragZones:isInDeleteZone(x, y)
    local z = self.deleteZone
    return x >= z.x and x < z.x + z.width and
        y >= z.y and y < z.y + z.height
end

function DragZones:isInSellZone(x, y)
    local z = self.sellZone
    return x >= z.x and x < z.x + z.width and
        y >= z.y and y < z.y + z.height
end

function DragZones:getZoneAtPosition(x, y)
    if self:isInDeleteZone(x, y) then
        return "delete"
    elseif self:isInSellZone(x, y) then
        return "sell"
    end
    return nil
end

function DragZones:draw()
    if self.alpha < 0.01 then return end

    love.graphics.setColor(1, 1, 1, self.alpha)

    -- Draw DELETE zone (bottom right, red tint)
    self:drawDeleteZone()

    -- Draw SELL zone (top middle, gold tint)
    self:drawSellZone()

    love.graphics.setColor(1, 1, 1, 1)
end

function DragZones:drawDeleteZone()
    local z = self.deleteZone
    -- Dark purple background for zones
    local baseBg = { 0.15, 0.1, 0.25 }   -- Dark purple
    local hoverBg = { 0.25, 0.15, 0.35 } -- Slightly lighter purple

    local color = self.deleteHovered and hoverBg or baseBg
    local finalColor = { color[1], color[2], color[3], self.alpha * 0.95 }

    -- Scale when hovered
    local scale = self.deleteHovered and 1.05 or 1
    local scaledWidth = z.width * scale
    local scaledHeight = z.height * scale
    local offsetX = (scaledWidth - z.width) / 2
    local offsetY = (scaledHeight - z.height) / 2

    -- Draw background
    self.nineSlice:draw(
        z.x - offsetX,
        z.y - offsetY,
        scaledWidth,
        scaledHeight,
        finalColor,
        Theme.nineSlice.borderScale
    )

    -- Draw DELETE text (WHITE)
    local textColor = { 1, 1, 1, self.alpha }
    love.graphics.setColor(textColor)
    local font = Theme.fonts.large
    love.graphics.setFont(font)
    local text = "DELETE"
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    love.graphics.print(text,
        z.x - offsetX + (scaledWidth - textWidth) / 2,
        z.y - offsetY + (scaledHeight - textHeight) / 2)
end

function DragZones:drawSellZone()
    local z = self.sellZone
    local baseBg = { 0.15, 0.1, 0.25 }   -- Dark purple
    local hoverBg = { 0.25, 0.15, 0.35 } -- Slightly lighter purple

    local color = self.sellHovered and hoverBg or baseBg
    local finalColor = { color[1], color[2], color[3], self.alpha * 0.95 }

    -- Scale when hovered
    local scale = self.sellHovered and 1.05 or 1
    local scaledWidth = z.width * scale
    local scaledHeight = z.height * scale
    local offsetX = (scaledWidth - z.width) / 2
    local offsetY = (scaledHeight - z.height) / 2

    -- Draw background
    self.nineSlice:draw(
        z.x - offsetX,
        z.y - offsetY,
        scaledWidth,
        scaledHeight,
        finalColor,
        Theme.nineSlice.borderScale
    )

    -- Draw SELL text with price (GOLD)
    local textColor = { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], self.alpha }
    love.graphics.setColor(textColor)
    local font = Theme.fonts.large
    love.graphics.setFont(font)
    local text = "SELL $" .. self.sellPrice
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    love.graphics.print(text,
        z.x - offsetX + (scaledWidth - textWidth) / 2,
        z.y - offsetY + (scaledHeight - textHeight) / 2)
end

return DragZones
