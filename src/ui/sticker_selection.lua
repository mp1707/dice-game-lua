-- Sticker Selection Screen
-- Displays 3 random stickers for player selection after opening a booster
-- Uses same juice animations as main game dice

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Button = require("src.ui.button")
local Stickers = require("src.game.stickers")
local Juice = require("src.ui.juice")
local Sound = require("src.core.sound")

local StickerSelection = {}
StickerSelection.__index = StickerSelection

-- Layout constants
local STICKER_SIZE = 110      -- Same as Theme.layout.diceSize
local STICKER_SPACING = 60    -- Space between stickers
local TITLE_Y = 200           -- "Pick a sticker" title Y
local STICKERS_Y = 400        -- Stickers row Y
local CONFIRM_Y = 650         -- Confirm button Y
local SELECTED_OFFSET_Y = -40 -- How far up selected sticker moves

-- Singleton instance
local instance = nil

function StickerSelection.getInstance()
    if not instance then
        instance = StickerSelection.new()
    end
    return instance
end

function StickerSelection.new()
    local self = setmetatable({}, StickerSelection)

    self.nineSlice = NineSlice.getInstance()

    -- State
    self.visible = false
    self.alpha = 0
    self.stickers = {}       -- Array of sticker IDs
    self.selectedIndex = nil -- nil or 1-3

    -- Per-sticker animation state
    self.stickerStates = {}

    -- Confirm button (created when needed)
    self.confirmButton = nil

    -- Callback
    self.onConfirm = nil

    -- Mouse position
    self.mouseX = 0
    self.mouseY = 0

    return self
end

function StickerSelection:show(stickerIds, onConfirm)
    self.visible = true
    self.alpha = 0
    self.stickers = stickerIds
    self.selectedIndex = nil
    self.onConfirm = onConfirm

    -- Initialize animation state for each sticker
    self.stickerStates = {}
    for i = 1, #stickerIds do
        self.stickerStates[i] = {
            breathingTime = i * 0.3, -- Stagger breathing
            hoverRotation = 0,
            hoverScaleX = 1,
            hoverScaleY = 1,
            targetHoverRotation = 0,
            targetHoverScaleX = 1,
            targetHoverScaleY = 1,
            selectionScale = 1,
            selectionScaleVelocity = 0,
            selectionYOffset = 0,
            selectionYVelocity = 0,
            isHovered = false,
        }
    end

    -- Create confirm button (hidden initially)
    self:createConfirmButton()
end

function StickerSelection:hide()
    self.visible = false
    self.selectedIndex = nil
    self.confirmButton = nil
end

function StickerSelection:createConfirmButton()
    local buttonWidth = Theme.layout.ctaWidth
    local buttonHeight = Theme.layout.ctaHeight
    local centerX = Theme.layout.centerX + Theme.layout.centerWidth / 2

    self.confirmButton = Button.new({
        x = centerX - buttonWidth / 2,
        y = Theme.layout.ctaY,
        width = buttonWidth,
        height = buttonHeight,
        text = "CONFIRM",
        bgColor = Theme.colors.cyan,
        textColor = Theme.colors.text,
        hoverBgColor = { Theme.colors.cyan[1] * 0.9, Theme.colors.cyan[2] * 0.9, Theme.colors.cyan[3] * 0.9, 1 },
        font = Theme.fonts.large,
        onClick = function()
            self:onConfirmClick()
        end,
    })
end

function StickerSelection:onConfirmClick()
    if not self.selectedIndex then return end

    local stickerId = self.stickers[self.selectedIndex]
    if self.onConfirm then
        Sound:play("click")
        self.onConfirm(stickerId)
    end
end

function StickerSelection:update(dt)
    if not self.visible then return end

    -- Fade in
    local targetAlpha = 1
    self.alpha = self.alpha + (targetAlpha - self.alpha) * dt * 8

    -- Update each sticker's animation state
    for i, state in ipairs(self.stickerStates) do
        self:updateStickerState(i, state, dt)
    end

    -- Update confirm button
    if self.confirmButton and self.selectedIndex then
        self.confirmButton:update(dt)
    end
end

function StickerSelection:updateStickerState(index, state, dt)
    -- Update breathing
    state.breathingTime = state.breathingTime + dt

    -- Get sticker position for hover detection
    local x, y = self:getStickerPosition(index)
    local centerX = x + STICKER_SIZE / 2
    local centerY = y + STICKER_SIZE / 2

    -- Update hover effects
    local rotation, scaleX, scaleY, isHovered = Juice.getHoverEffects(
        self.mouseX, self.mouseY, centerX, centerY, STICKER_SIZE
    )

    state.isHovered = isHovered
    state.targetHoverRotation = rotation
    state.targetHoverScaleX = scaleX
    state.targetHoverScaleY = scaleY

    -- Smooth interpolation for hover
    local hoverLerp = 12 * dt
    state.hoverRotation = state.hoverRotation + (state.targetHoverRotation - state.hoverRotation) * hoverLerp
    state.hoverScaleX = state.hoverScaleX + (state.targetHoverScaleX - state.hoverScaleX) * hoverLerp
    state.hoverScaleY = state.hoverScaleY + (state.targetHoverScaleY - state.hoverScaleY) * hoverLerp

    -- Update selection spring animation
    local isSelected = (self.selectedIndex == index)
    local targetScale = 1
    local targetYOffset = isSelected and SELECTED_OFFSET_Y or 0

    local _, _, stiffness, damping = Juice.getSelectionPopParams()
    state.selectionScale, state.selectionScaleVelocity = Juice.updateSpring(
        state.selectionScale, targetScale, state.selectionScaleVelocity,
        stiffness, damping, dt
    )
    state.selectionYOffset, state.selectionYVelocity = Juice.updateSpring(
        state.selectionYOffset, targetYOffset, state.selectionYVelocity,
        stiffness, damping, dt
    )
end

function StickerSelection:updateMouse(mouseX, mouseY)
    self.mouseX = mouseX
    self.mouseY = mouseY
end

function StickerSelection:getStickerPosition(index)
    local totalWidth = #self.stickers * STICKER_SIZE + (#self.stickers - 1) * STICKER_SPACING
    local startX = Theme.layout.centerX + (Theme.layout.centerWidth - totalWidth) / 2
    local x = startX + (index - 1) * (STICKER_SIZE + STICKER_SPACING)
    return x, STICKERS_Y
end

function StickerSelection:getStickerAtPosition(px, py)
    for i = 1, #self.stickers do
        local x, y = self:getStickerPosition(i)
        if px >= x and px < x + STICKER_SIZE and
            py >= y and py < y + STICKER_SIZE then
            return i
        end
    end
    return nil
end

function StickerSelection:selectSticker(index)
    if self.selectedIndex == index then
        -- Already selected
        return
    end

    local wasSelected = self.selectedIndex

    self.selectedIndex = index

    -- Trigger selection animation
    if index and self.stickerStates[index] then
        local state = self.stickerStates[index]
        local initialScale, initialYOffset, _, _ = Juice.getSelectionPopParams()
        state.selectionScale = initialScale
        state.selectionYOffset = initialYOffset
    end

    -- Trigger deselection animation on previous
    if wasSelected and self.stickerStates[wasSelected] then
        local state = self.stickerStates[wasSelected]
        local initialScale, initialYOffset, _, _ = Juice.getDeselectionPopParams()
        state.selectionScale = initialScale
        state.selectionYOffset = initialYOffset
    end

    Sound:play("click")
end

function StickerSelection:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if not self.visible or self.alpha < 0.5 then return false end

    -- Check sticker clicks
    local clickedIndex = self:getStickerAtPosition(x, y)
    if clickedIndex then
        self:selectSticker(clickedIndex)
        return true
    end

    -- Check confirm button
    if self.confirmButton and self.selectedIndex then
        if self.confirmButton:mousepressed(x, y, button) then
            return true
        end
    end

    return false
end

function StickerSelection:mousereleased(x, y, button)
    if self.confirmButton then
        self.confirmButton:mousereleased(x, y, button)
    end
end

function StickerSelection:draw()
    if not self.visible or self.alpha < 0.01 then return end

    -- Draw title
    self:drawTitle()

    -- Draw stickers
    self:drawStickers()

    -- Draw confirm button (only if something selected)
    if self.confirmButton and self.selectedIndex then
        self.confirmButton:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function StickerSelection:drawTitle()
    local title = "Pick a sticker"
    local font = Theme.fonts.huge
    local centerX = Theme.layout.centerX + Theme.layout.centerWidth / 2

    love.graphics.setFont(font)
    local textWidth = font:getWidth(title)
    local textX = centerX - textWidth / 2

    -- Shadow
    love.graphics.setColor(Theme.colors.textShadow[1], Theme.colors.textShadow[2],
        Theme.colors.textShadow[3], self.alpha * Theme.colors.textShadow[4])
    love.graphics.print(title, textX + 2, TITLE_Y + 2)

    -- Main text
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.print(title, textX, TITLE_Y)
end

function StickerSelection:drawStickers()
    for i, stickerId in ipairs(self.stickers) do
        self:drawSticker(i, stickerId)
    end
end

function StickerSelection:drawSticker(index, stickerId)
    local sticker = Stickers:get(stickerId)
    if not sticker then return end

    local state = self.stickerStates[index]
    if not state then return end

    local x, y = self:getStickerPosition(index)

    -- Get breathing values
    local breathScale, breathY = Juice.getBreathingValues(state.breathingTime, index)

    -- Calculate final transform
    local centerX = x + STICKER_SIZE / 2
    local centerY = y + STICKER_SIZE / 2
    local finalScale = breathScale * state.selectionScale * state.hoverScaleX
    local finalScaleY = breathScale * state.selectionScale * state.hoverScaleY
    local finalY = centerY + breathY + state.selectionYOffset
    local finalRotation = state.hoverRotation

    love.graphics.push()
    love.graphics.translate(centerX, finalY)
    love.graphics.rotate(finalRotation)
    love.graphics.scale(finalScale, finalScaleY)
    love.graphics.translate(-STICKER_SIZE / 2, -STICKER_SIZE / 2)

    -- Draw background
    local isSelected = (self.selectedIndex == index)

    -- Every sticker has a white background panel now
    local bgColor = { 1, 1, 1, self.alpha }
    self.nineSlice:draw(0, 0, STICKER_SIZE, STICKER_SIZE, bgColor, Theme.nineSlice.borderScale)

    -- Draw sticker sprite (die face) with less padding
    if Theme.diceSpritesheet then
        -- Use sticker's die type for the correct sprite
        local quad = Theme.diceSpritesheet:getQuad(sticker.spriteId, sticker.dieType)
        local image = Theme.diceSpritesheet:getImage()

        love.graphics.setColor(1, 1, 1, self.alpha)
        local spriteW, _ = Theme.diceSpritesheet:getSpriteSize()
        -- Increase sprite size to reduce padding (was 0.9)
        local spriteScale = STICKER_SIZE * 0.96 / spriteW
        local spriteOffset = STICKER_SIZE * 0.02 -- Position adjusted for less padding
        love.graphics.draw(image, quad, spriteOffset, spriteOffset, 0, spriteScale, spriteScale)
    end

    love.graphics.pop()
end

function StickerSelection:isVisible()
    return self.visible and self.alpha > 0.1
end

return StickerSelection
