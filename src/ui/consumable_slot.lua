-- Consumable Slot component
-- Renders a sticker in the item strip with USE/SELL buttons
-- Supports dragging for DELETE/SELL zones

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local GameState = require("src.game.game_state")
local Stickers = require("src.game.stickers")
local Sound = require("src.core.sound")
local Juice = require("src.ui.juice")

local ConsumableSlot = {}
ConsumableSlot.__index = ConsumableSlot

function ConsumableSlot.new(config)
    local self = setmetatable({}, ConsumableSlot)

    self.x = config.x or 0
    self.y = config.y or 0
    self.size = config.size or Theme.layout.itemSlotSize
    self.slotIndex = config.slotIndex or 1 -- 1 or 2 (maps to consumables array)

    -- Callbacks
    self.onUse = config.onUse or function() end
    self.onSell = config.onSell or function() end
    self.onDragStart = config.onDragStart or function() end
    self.onDragEnd = config.onDragEnd or function() end

    -- State
    self.isHovered = false
    self.isSelected = false -- Shows USE/SELL buttons
    self.isDragging = false
    self.mouseDownOnSlot = false -- Track if mouse was pressed on this slot
    self.dragOffsetX = 0
    self.dragOffsetY = 0
    self.dragX = 0
    self.dragY = 0

    -- Animation state (spring physics)
    self.scale = 1
    self.scaleVelocity = 0
    self.targetScale = 1
    self.rotation = 0
    self.rotationVelocity = 0

    -- Button animation
    self.buttonsVisible = false
    self.buttonsAlpha = 0
    self.buttonsY = 0 -- Slide in from above

    -- Hover time tracking (for potential tooltip)
    self.hoverTime = 0

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    return self
end

function ConsumableSlot:getConsumable()
    return GameState:getConsumable(self.slotIndex)
end

function ConsumableSlot:hasConsumable()
    return self:getConsumable() ~= nil
end

function ConsumableSlot:containsPoint(px, py)
    local x, y = self:getDrawPosition()
    return px >= x and px < x + self.size and
        py >= y and py < y + self.size
end

function ConsumableSlot:getDrawPosition()
    if self.isDragging then
        return self.dragX, self.dragY
    end
    return self.x, self.y
end

function ConsumableSlot:update(dt)
    local mx, my = love.mouse.getPosition()
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end

    local wasHovered = self.isHovered
    if mx and my then
        self.isHovered = self:containsPoint(mx, my) and self:hasConsumable() and not self.isDragging
    else
        self.isHovered = false
    end

    -- Track hover time
    if self.isHovered then
        self.hoverTime = self.hoverTime + dt
    else
        self.hoverTime = 0
    end

    -- Update hover scale animation
    if self.isHovered and not self.isDragging then
        self.targetScale = 1.08
    elseif self.isDragging then
        self.targetScale = 1.15
    else
        self.targetScale = 1
    end

    -- Spring physics for scale
    self.scale, self.scaleVelocity = Juice.updateSpring(
        self.scale, self.targetScale, self.scaleVelocity,
        400, 25, dt
    )

    -- Wobble rotation when dragging
    if self.isDragging then
        local wobbleSpeed = 8
        self.rotation = math.sin(love.timer.getTime() * wobbleSpeed) * 0.05
    else
        self.rotation = self.rotation * 0.9 -- Decay rotation
    end

    -- Update button visibility animation
    local targetAlpha = self.isSelected and 1 or 0
    local targetY = self.isSelected and 0 or 10
    self.buttonsAlpha = self.buttonsAlpha + (targetAlpha - self.buttonsAlpha) * dt * 12
    self.buttonsY = self.buttonsY + (targetY - self.buttonsY) * dt * 12

    -- Hide buttons if we start dragging or lose the consumable
    if self.isDragging or not self:hasConsumable() then
        self.isSelected = false
    end
end

function ConsumableSlot:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if not self:hasConsumable() then return false end

    -- Check if clicking on USE/SELL buttons (stacked below slot)
    if self.isSelected and self.buttonsAlpha > 0.5 then
        local buttonWidth = self.size + 20
        local buttonHeight = 38
        local buttonX = self.x - 10
        local gap = 6

        -- USE button (top, below slot)
        local useY = self.y + self.size + 8 + self.buttonsY
        if x >= buttonX and x < buttonX + buttonWidth and
            y >= useY and y < useY + buttonHeight then
            Sound:play("lightClick")
            self.isSelected = false
            self.onUse(self.slotIndex)
            return true
        end

        -- SELL button (below USE)
        local sellY = useY + buttonHeight + gap
        if x >= buttonX and x < buttonX + buttonWidth and
            y >= sellY and y < sellY + buttonHeight then
            Sound:play("lightClick")
            self.isSelected = false
            self.onSell(self.slotIndex)
            return true
        end
    end

    -- Check if clicking on the slot itself
    if self:containsPoint(x, y) then
        -- Start potential drag
        self.mouseDownOnSlot = true
        self.dragOffsetX = x - self.x
        self.dragOffsetY = y - self.y
        self.dragX = self.x
        self.dragY = self.y
        return true
    end

    -- Click outside while selected - deselect
    if self.isSelected then
        self.isSelected = false
        return false
    end

    return false
end

function ConsumableSlot:mousereleased(x, y, button)
    if button ~= 1 then return false end

    local wasMouseDownOnSlot = self.mouseDownOnSlot
    self.mouseDownOnSlot = false

    if self.isDragging then
        self.isDragging = false
        self.onDragEnd(self.slotIndex, x, y)
        return true
    end

    -- If we clicked and released without dragging, toggle selection
    if wasMouseDownOnSlot and self:containsPoint(x, y) and self:hasConsumable() then
        self.isSelected = not self.isSelected
        if self.isSelected then
            Sound:play("lightClick")
        end
        return true
    end

    return false
end

function ConsumableSlot:mousemoved(x, y, dx, dy)
    if not love.mouse.isDown(1) then return end
    if not self:hasConsumable() then return end
    if not self.mouseDownOnSlot then return end -- Only drag if mouse was pressed on this slot

    -- Check if we should start dragging
    if not self.isDragging then
        local dragDist = math.sqrt(
            (x - (self.x + self.dragOffsetX)) ^ 2 +
            (y - (self.y + self.dragOffsetY)) ^ 2
        )
        if dragDist > 8 then
            self.isDragging = true
            self.isSelected = false
            self.onDragStart(self.slotIndex)
        end
    end

    -- Update drag position
    if self.isDragging then
        self.dragX = x - self.dragOffsetX
        self.dragY = y - self.dragOffsetY
    end
end

function ConsumableSlot:deselect()
    self.isSelected = false
end

function ConsumableSlot:draw()
    local drawX, drawY = self:getDrawPosition()

    -- Calculate center for scaling/rotation
    local centerX = drawX + self.size / 2
    local centerY = drawY + self.size / 2

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(self.rotation)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-self.size / 2, -self.size / 2)

    -- Draw slot background
    local bgColor = self.isHovered and Theme.colors.surface2 or Theme.colors.panelDark
    self.nineSlice:draw(0, 0, self.size, self.size, bgColor, Theme.nineSlice.borderScale)

    -- Draw sticker sprite if present
    local consumable = self:getConsumable()
    if consumable then
        local sticker = Stickers:get(consumable.stickerId)
        if sticker and Theme.diceSpritesheet then
            local spriteSize = self.size * 0.9
            local spriteX = (self.size - spriteSize) / 2
            local spriteY = (self.size - spriteSize) / 2

            local quad = Theme.diceSpritesheet:getQuad(sticker.spriteId)
            local image = Theme.diceSpritesheet:getImage()

            love.graphics.setColor(1, 1, 1, 1)
            local scale = spriteSize / 60 -- Assuming 60x60 sprite size
            love.graphics.draw(image, quad, spriteX, spriteY, 0, scale, scale)
        end
    end

    love.graphics.pop()

    -- Draw USE/SELL buttons above slot (outside transform)
    if self.isSelected and self.buttonsAlpha > 0.01 then
        self:drawButtons()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ConsumableSlot:drawButtons()
    local buttonWidth = self.size + 20
    local buttonHeight = 38
    local buttonX = self.x - 10
    local gap = 6
    local shadowOffset = 4

    local font = Theme.fonts.normal
    love.graphics.setFont(font)

    -- USE button (top, below slot) - Cyan CTA style
    local useY = self.y + self.size + 8 + self.buttonsY

    -- USE shadow
    local shadowColor = { 0, 0, 0, 0.4 * self.buttonsAlpha }
    self.nineSlice:draw(buttonX, useY + shadowOffset, buttonWidth, buttonHeight, shadowColor, Theme.nineSlice.borderScale)

    -- USE button
    local useColor = { Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], self.buttonsAlpha }
    self.nineSlice:draw(buttonX, useY, buttonWidth, buttonHeight, useColor, Theme.nineSlice.borderScale)

    -- USE text
    love.graphics.setColor(Theme.colors.textDark[1], Theme.colors.textDark[2], Theme.colors.textDark[3], self.buttonsAlpha)
    local useText = "USE"
    local useTextWidth = font:getWidth(useText)
    love.graphics.print(useText,
        buttonX + (buttonWidth - useTextWidth) / 2,
        useY + (buttonHeight - font:getHeight()) / 2)

    -- SELL button (below USE) - Gold CTA style
    local sellY = useY + buttonHeight + gap

    -- Get sell price
    local consumable = self:getConsumable()
    local sellPrice = 2
    if consumable then
        sellPrice = Stickers:getSellPrice(consumable.stickerId)
    end

    -- SELL shadow
    self.nineSlice:draw(buttonX, sellY + shadowOffset, buttonWidth, buttonHeight, shadowColor, Theme.nineSlice.borderScale)

    -- SELL button
    local sellColor = { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], self.buttonsAlpha }
    self.nineSlice:draw(buttonX, sellY, buttonWidth, buttonHeight, sellColor, Theme.nineSlice.borderScale)

    -- SELL text with price
    love.graphics.setColor(Theme.colors.textDark[1], Theme.colors.textDark[2], Theme.colors.textDark[3], self.buttonsAlpha)
    local sellText = "SELL $" .. sellPrice
    local sellTextWidth = font:getWidth(sellText)
    love.graphics.print(sellText,
        buttonX + (buttonWidth - sellTextWidth) / 2,
        sellY + (buttonHeight - font:getHeight()) / 2)

    love.graphics.setColor(1, 1, 1, 1)
end

function ConsumableSlot:isDraggingSticker()
    return self.isDragging
end

function ConsumableSlot:getDragPosition()
    return self.dragX + self.size / 2, self.dragY + self.size / 2
end

return ConsumableSlot
