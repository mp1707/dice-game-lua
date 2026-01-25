-- Relic Slot component
-- Renders a relic in the item strip with SELL button only
-- Supports dragging for repositioning
-- Relics are passive items (no USE button)

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local GameState = require("src.game.game_state")
local Relics = require("src.game.relics")
local Sound = require("src.core.sound")
local Juice = require("src.ui.juice")
local ShopTooltip = require("src.ui.shop_tooltip")

local RelicSlot = {}
RelicSlot.__index = RelicSlot

function RelicSlot.new(config)
    local self = setmetatable({}, RelicSlot)

    self.x = config.x or 0
    self.y = config.y or 0
    self.size = config.size or Theme.layout.itemSlotSize
    self.slotIndex = config.slotIndex or 1 -- 1-5 (maps to relics array)

    -- Callbacks
    self.onSell = config.onSell or function() end
    self.onDragStart = config.onDragStart or function() end
    self.onDragEnd = config.onDragEnd or function() end

    -- State
    self.isHovered = false
    self.isSelected = false      -- Shows SELL button
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

    -- Load relic sprite image (lazy loaded)
    self.relicImages = {}

    self.shopTooltip = ShopTooltip.getInstance()

    return self
end

function RelicSlot:getRelic()
    return GameState:getRelic(self.slotIndex)
end

function RelicSlot:hasRelic()
    return self:getRelic() ~= nil
end

function RelicSlot:containsPoint(px, py)
    local x, y = self:getDrawPosition()
    return px >= x and px < x + self.size and
        py >= y and py < y + self.size
end

function RelicSlot:getDrawPosition()
    if self.isDragging then
        return self.dragX, self.dragY
    end
    return self.x, self.y
end

-- Load or get cached relic image
function RelicSlot:getRelicImage(relicId)
    if self.relicImages[relicId] then
        return self.relicImages[relicId]
    end

    local relicDef = Relics:get(relicId)
    if relicDef and relicDef.sprite then
        local success, image = pcall(love.graphics.newImage, relicDef.sprite)
        if success then
            image:setFilter("nearest", "nearest")
            self.relicImages[relicId] = image
            return image
        end
    end
    return nil
end

function RelicSlot:update(dt)
    local mx, my = love.mouse.getPosition()
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end

    local wasHovered = self.isHovered
    if mx and my then
        self.isHovered = self:containsPoint(mx, my) and self:hasRelic() and not self.isDragging
    else
        self.isHovered = false
    end

    if wasHovered and not self.isHovered then
        self.shopTooltip:hide()
    end

    -- Track hover time
    if self.isHovered then
        self.hoverTime = self.hoverTime + dt
        if self.hoverTime >= 0.1 then
            local relic = self:getRelic()
            if relic then
                local relicDef = Relics:get(relic.relicId)
                if relicDef then
                    local drawX, drawY = self:getDrawPosition()
                    local centerX = drawX + self.size / 2
                    local bottomY = drawY + self.size
                    self.shopTooltip:show(relicDef.name, centerX, bottomY, relicDef.description, "below")
                end
            end
        end
    else
        self.hoverTime = 0
        -- Only hide if we were the one showing it (simplification: just hide if not hovered)
        -- In a more complex system we might check if we are the current source
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

    -- Hide buttons if we start dragging or lose the relic
    if self.isDragging or not self:hasRelic() then
        self.isSelected = false
    end
end

function RelicSlot:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if not self:hasRelic() then return false end

    -- Check if clicking on SELL button (below slot)
    -- Relaxed alpha check to make it more responsive during animation
    if self.isSelected and self.buttonsAlpha > 0.1 then
        local buttonWidth = self.size + 20
        local buttonHeight = 38
        local buttonX = self.x - 10

        -- SELL button (below slot)
        local sellY = self.y + self.size + 8 + self.buttonsY
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

function RelicSlot:mousereleased(x, y, button)
    if button ~= 1 then return false end

    local wasMouseDownOnSlot = self.mouseDownOnSlot
    self.mouseDownOnSlot = false

    if self.isDragging then
        self.isDragging = false
        self.onDragEnd(self.slotIndex, x, y)
        return true
    end

    -- If we clicked and released without dragging, toggle selection
    if wasMouseDownOnSlot and self:containsPoint(x, y) and self:hasRelic() then
        self.isSelected = not self.isSelected
        if self.isSelected then
            Sound:play("lightClick")
        end
        return true
    end

    return false
end

function RelicSlot:mousemoved(x, y, dx, dy)
    if not love.mouse.isDown(1) then return end
    if not self:hasRelic() then return end
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

function RelicSlot:deselect()
    self.isSelected = false
end

function RelicSlot:draw(alphaMult)
    alphaMult = alphaMult or 1

    -- STATIC VISUALS: Always at self.x, self.y
    local staticCenterX = self.x + self.size / 2
    local staticCenterY = self.y + self.size / 2

    -- Draw slot background (Static)
    local bgColor = self.isHovered and Theme.colors.surface2 or Theme.colors.panelDark
    local finalBgColor = { bgColor[1], bgColor[2], bgColor[3], (bgColor[4] or 1) * alphaMult }

    -- Draw BG with NineSlice at static position
    -- Note: NineSlice draws from top-left, so we just use self.x, self.y
    -- We're not applying scale/rotation to the background anymore as requested ("keep slot stationary")
    self.nineSlice:draw(self.x, self.y, self.size, self.size, finalBgColor, Theme.nineSlice.borderScale)

    -- DYNAMIC VISUALS: Sprite follows drag
    local drawX, drawY = self:getDrawPosition()
    local centerX = drawX + self.size / 2
    local centerY = drawY + self.size / 2

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(self.rotation)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-self.size / 2, -self.size / 2)

    -- Draw relic sprite if present
    local relic = self:getRelic()
    if relic then
        local relicImage = self:getRelicImage(relic.relicId)
        if relicImage then
            love.graphics.setColor(1, 1, 1, alphaMult)
            local imgW, imgH = relicImage:getDimensions()
            -- Scale to fit slot with some padding
            local spriteSize = self.size * 0.8
            local scale = math.min(spriteSize / imgW, spriteSize / imgH)
            local spriteX = (self.size - imgW * scale) / 2
            local spriteY = (self.size - imgH * scale) / 2
            love.graphics.draw(relicImage, spriteX, spriteY, 0, scale, scale)
        end
    end

    love.graphics.pop()

    -- Draw SELL button below slot (using static position as anchor, but it slides)
    -- Buttons are UI controls attached to the slot logical position (self.x, self.y)
    if self.isSelected and self.buttonsAlpha > 0.01 then
        self:drawButtons()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function RelicSlot:drawButtons()
    local buttonWidth = self.size + 20
    local buttonHeight = 38
    local buttonX = self.x - 10
    local shadowOffset = 4

    local font = Theme.fonts.normal
    love.graphics.setFont(font)

    -- SELL button (below slot) - Gold CTA style
    local sellY = self.y + self.size + 8 + self.buttonsY

    -- Get sell price
    local relic = self:getRelic()
    local sellPrice = 3
    if relic then
        sellPrice = Relics:getSellPrice(relic.relicId)
    end

    -- SELL shadow
    local shadowColor = { 0, 0, 0, 0.4 * self.buttonsAlpha }
    self.nineSlice:draw(buttonX, sellY + shadowOffset, buttonWidth, buttonHeight, shadowColor,
        Theme.nineSlice.borderScale)

    -- SELL button
    local sellColor = { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], self.buttonsAlpha }
    self.nineSlice:draw(buttonX, sellY, buttonWidth, buttonHeight, sellColor, Theme.nineSlice.borderScale)

    -- SELL text with price
    love.graphics.setColor(Theme.colors.textDark[1], Theme.colors.textDark[2], Theme.colors.textDark[3],
        self.buttonsAlpha)
    local sellText = "SELL $" .. sellPrice
    local sellTextWidth = font:getWidth(sellText)
    love.graphics.print(sellText,
        buttonX + (buttonWidth - sellTextWidth) / 2,
        sellY + (buttonHeight - font:getHeight()) / 2)

    love.graphics.setColor(1, 1, 1, 1)
end

function RelicSlot:isDraggingRelic()
    return self.isDragging
end

function RelicSlot:getDragPosition()
    return self.dragX + self.size / 2, self.dragY + self.size / 2
end

return RelicSlot
