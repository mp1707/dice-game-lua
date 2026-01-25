-- Dice Editor Mode Controller
-- Manages the dice face editing flow with dimming overlay
-- Singleton pattern for global access

local Theme = require("src.ui.theme")
local GameState = require("src.game.game_state")
local Stickers = require("src.game.stickers")
local DiceTooltip = require("src.ui.dice_tooltip")
local Sound = require("src.core.sound")
local Juice = require("src.ui.juice")

local DiceEditor = {
    _instance = nil,
}
DiceEditor.__index = DiceEditor

function DiceEditor.getInstance()
    if not DiceEditor._instance then
        DiceEditor._instance = DiceEditor.new()
    end
    return DiceEditor._instance
end

function DiceEditor.new()
    local self = setmetatable({}, DiceEditor)

    -- State
    self.isActive = false
    self.context = nil -- "shop" or "play"
    self.consumableIndex = nil
    self.stickerId = nil
    self.newFaceValue = nil

    -- Selected die and face for editing
    self.selectedDieIndex = nil
    self.hoveredDieIndex = nil

    -- Animation state
    self.dimAlpha = 0
    self.targetDimAlpha = 0

    -- Confirmation modal state
    self.showingConfirmation = false
    self.confirmDieIndex = nil
    self.confirmFaceIndex = nil
    self.confirmOldValue = nil
    self.confirmNewValue = nil
    self.confirmModalY = -300
    self.confirmModalVelocity = 0

    -- Callbacks
    self.onComplete = nil       -- Called when editing is complete
    self.onCancel = nil         -- Called when editing is cancelled
    self.getDicePositions = nil -- Function to get dice positions for tooltip

    -- Tooltip
    self.tooltip = DiceTooltip.getInstance()
    self.tooltip:setOnFaceClick(function(dieIndex, faceIndex)
        self:onFaceSelected(dieIndex, faceIndex)
    end)

    -- Hover time tracking for tooltip
    self.hoverTime = 0
    self.tooltipDelay = 0.1 -- Show tooltip after 0.1 seconds

    return self
end

function DiceEditor:activate(context, consumableIndex, callbacks)
    local consumable = GameState:getConsumable(consumableIndex)
    if not consumable then return false end

    local sticker = Stickers:get(consumable.stickerId)
    if not sticker then return false end

    self.isActive = true
    self.context = context
    self.consumableIndex = consumableIndex
    self.stickerId = consumable.stickerId
    self.newFaceValue = sticker.faceValue

    self.selectedDieIndex = nil
    self.hoveredDieIndex = nil
    self.showingConfirmation = false

    self.targetDimAlpha = 0.7

    self.onComplete = callbacks and callbacks.onComplete
    self.onCancel = callbacks and callbacks.onCancel
    self.getDicePositions = callbacks and callbacks.getDicePositions

    GameState:enterEditorMode(consumableIndex)

    Sound:play("bling")

    -- If a pre-selected die was specified, select it immediately
    local preSelectedDie = callbacks and callbacks.preSelectedDie
    if preSelectedDie then
        -- Use a small delay so the editor is fully set up
        self.pendingDieSelection = preSelectedDie
    end

    return true
end

function DiceEditor:deactivate()
    self.isActive = false
    self.targetDimAlpha = 0
    self.tooltip:hide()
    self.showingConfirmation = false

    GameState:exitEditorMode()
end

function DiceEditor:cancel()
    self:deactivate()
    if self.onCancel then
        self.onCancel()
    end
end

function DiceEditor:selectDie(dieIndex)
    if not self.isActive then return end
    if self.showingConfirmation then return end

    -- Get the currently rolled face index for this die
    local die = GameState.dice[dieIndex]
    if not die or not die.rolledFaceIndex then return end

    local rolledFaceIndex = die.rolledFaceIndex
    local oldValue = die.value

    -- Apply the sticker directly to the rolled face
    GameState:setDieFace(dieIndex, rolledFaceIndex, self.newFaceValue)

    -- Remove the consumable
    GameState:removeConsumable(self.consumableIndex)

    Sound:play("cash")

    -- Deactivate editor
    self:deactivate()

    -- Call completion callback
    if self.onComplete then
        self.onComplete()
    end
end

function DiceEditor:onFaceSelected(dieIndex, faceIndex)
    if not self.isActive then return end
    if self.showingConfirmation then return end

    -- Get current face value
    local oldValue = GameState:getDieFace(dieIndex, faceIndex)
    if not oldValue then return end

    -- Show confirmation modal
    self.confirmDieIndex = dieIndex
    self.confirmFaceIndex = faceIndex
    self.confirmOldValue = oldValue
    self.confirmNewValue = self.newFaceValue
    self.showingConfirmation = true
    self.confirmModalY = -300
    self.confirmModalVelocity = 0

    self.tooltip:hide()
    Sound:play("click")
end

function DiceEditor:confirmReplacement()
    if not self.showingConfirmation then return end

    -- Replace the face
    GameState:setDieFace(self.confirmDieIndex, self.confirmFaceIndex, self.confirmNewValue)

    -- Remove the consumable
    GameState:removeConsumable(self.consumableIndex)

    Sound:play("cash")

    -- Deactivate editor
    self:deactivate()

    -- Call completion callback
    if self.onComplete then
        self.onComplete()
    end
end

function DiceEditor:cancelConfirmation()
    self.showingConfirmation = false
    self.confirmDieIndex = nil
    self.confirmFaceIndex = nil

    -- Re-show tooltip for the selected die
    if self.selectedDieIndex and self.getDicePositions then
        local positions = self.getDicePositions()
        if positions and positions[self.selectedDieIndex] then
            local pos = positions[self.selectedDieIndex]
            self.tooltip:show(self.selectedDieIndex, pos.x + pos.width / 2, pos.y)
        end
    end

    Sound:play("click")
end

function DiceEditor:update(dt)
    -- Animate dimming
    self.dimAlpha = self.dimAlpha + (self.targetDimAlpha - self.dimAlpha) * dt * 8

    -- Update tooltip
    self.tooltip:update(dt)

    -- Update confirmation modal animation
    if self.showingConfirmation then
        local targetY = (Theme.screen.height - 280) / 2
        self.confirmModalY, self.confirmModalVelocity = Juice.updateSpring(
            self.confirmModalY, targetY, self.confirmModalVelocity,
            400, 30, dt
        )
    else
        local targetY = -300
        self.confirmModalY, self.confirmModalVelocity = Juice.updateSpring(
            self.confirmModalY, targetY, self.confirmModalVelocity,
            400, 30, dt
        )
    end

    -- Handle pending die selection (from drag-to-die)
    if self.pendingDieSelection and self.dimAlpha > 0.3 then
        self:selectDie(self.pendingDieSelection)
        self.pendingDieSelection = nil
    end

    -- Handle hover for showing tooltip
    if self.isActive and not self.showingConfirmation and not self.tooltip:isVisible() then
        if self.hoveredDieIndex then
            self.hoverTime = self.hoverTime + dt
            if self.hoverTime >= self.tooltipDelay then
                self:selectDie(self.hoveredDieIndex)
            end
        else
            self.hoverTime = 0
        end
    end
end

function DiceEditor:setHoveredDie(dieIndex)
    if self.hoveredDieIndex ~= dieIndex then
        self.hoveredDieIndex = dieIndex
        self.hoverTime = 0
    end
end

function DiceEditor:mousepressed(x, y, button)
    if not self.isActive then return false end

    -- Handle confirmation modal
    if self.showingConfirmation and self.confirmModalY > 0 then
        return self:handleConfirmationClick(x, y, button)
    end

    -- Handle tooltip face clicks
    if self.tooltip:isVisible() then
        if self.tooltip:mousepressed(x, y, button) then
            return true
        end
    end

    return false
end

function DiceEditor:handleConfirmationClick(x, y, button)
    if button ~= 1 then return false end

    local modalWidth = 400
    local modalHeight = 280
    local modalX = (Theme.screen.width - modalWidth) / 2
    local modalY = self.confirmModalY

    -- Cancel button (left)
    local buttonY = modalY + modalHeight - 70
    local buttonWidth = 150
    local buttonHeight = 50
    local cancelX = modalX + 30
    local confirmX = modalX + modalWidth - buttonWidth - 30

    if x >= cancelX and x < cancelX + buttonWidth and
        y >= buttonY and y < buttonY + buttonHeight then
        self:cancelConfirmation()
        return true
    end

    -- Confirm button (right)
    if x >= confirmX and x < confirmX + buttonWidth and
        y >= buttonY and y < buttonY + buttonHeight then
        self:confirmReplacement()
        return true
    end

    -- Click outside modal to cancel
    if x < modalX or x > modalX + modalWidth or
        y < modalY or y > modalY + modalHeight then
        self:cancelConfirmation()
        return true
    end

    return true -- Absorb click
end

function DiceEditor:keypressed(key)
    if not self.isActive then return false end

    if key == "escape" then
        if self.showingConfirmation then
            self:cancelConfirmation()
        else
            self:cancel()
        end
        return true
    end

    if key == "return" then
        if self.showingConfirmation then
            self:confirmReplacement()
            return true
        end
    end

    return false
end

function DiceEditor:drawOverlay()
    if self.dimAlpha < 0.01 then return end

    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, self.dimAlpha)
    love.graphics.rectangle("fill", 0, 0, Theme.screen.width, Theme.screen.height)

    love.graphics.setColor(1, 1, 1, 1)
end

function DiceEditor:drawInstructions()
    if not self.isActive then return end
    if self.dimAlpha < 0.3 then return end

    -- Draw instruction text
    local text = "Click a die to apply the sticker"

    love.graphics.setColor(1, 1, 1, self.dimAlpha)
    local font = Theme.fonts.large
    love.graphics.setFont(font)
    local textWidth = font:getWidth(text)
    love.graphics.print(text,
        (Theme.screen.width - textWidth) / 2,
        Theme.layout.diceHomeY - 80)

    love.graphics.setColor(1, 1, 1, 1)
end

function DiceEditor:drawTooltip()
    self.tooltip:draw()
end

function DiceEditor:drawConfirmationModal()
    if self.confirmModalY <= -200 then return end

    local nineSlice = require("src.ui.nine_slice").getInstance()

    local modalWidth = 400
    local modalHeight = 280
    local modalX = (Theme.screen.width - modalWidth) / 2
    local modalY = self.confirmModalY

    -- Draw modal background
    nineSlice:draw(modalX, modalY, modalWidth, modalHeight,
        Theme.colors.surface, Theme.nineSlice.borderScale)

    -- Title
    love.graphics.setColor(Theme.colors.text)
    local titleFont = Theme.fonts.large
    love.graphics.setFont(titleFont)
    local title = "Replace Face?"
    local titleWidth = titleFont:getWidth(title)
    love.graphics.print(title, modalX + (modalWidth - titleWidth) / 2, modalY + 20)

    -- Draw old face -> new face comparison
    local faceSize = 70
    local arrowGap = 40
    local totalWidth = faceSize * 2 + arrowGap
    local startX = modalX + (modalWidth - totalWidth) / 2
    local faceY = modalY + 70

    -- Old face
    self:drawModalFace(startX, faceY, faceSize, self.confirmOldValue)

    -- Arrow
    love.graphics.setColor(Theme.colors.textMuted)
    local arrowFont = Theme.fonts.huge
    love.graphics.setFont(arrowFont)
    local arrow = ">"
    local arrowWidth = arrowFont:getWidth(arrow)
    love.graphics.print(arrow,
        startX + faceSize + (arrowGap - arrowWidth) / 2,
        faceY + (faceSize - arrowFont:getHeight()) / 2)

    -- New face
    self:drawModalFace(startX + faceSize + arrowGap, faceY, faceSize, self.confirmNewValue)

    -- Value labels
    love.graphics.setColor(Theme.colors.textMuted)
    local labelFont = Theme.fonts.normal
    love.graphics.setFont(labelFont)

    local oldLabel = "\"" .. self.confirmOldValue .. "\""
    local newLabel = "\"" .. self.confirmNewValue .. "\""
    local oldLabelWidth = labelFont:getWidth(oldLabel)
    local newLabelWidth = labelFont:getWidth(newLabel)

    love.graphics.print(oldLabel, startX + (faceSize - oldLabelWidth) / 2, faceY + faceSize + 8)
    love.graphics.print(newLabel, startX + faceSize + arrowGap + (faceSize - newLabelWidth) / 2, faceY + faceSize + 8)

    -- Buttons
    local buttonY = modalY + modalHeight - 70
    local buttonWidth = 150
    local buttonHeight = 50

    -- Cancel button
    local cancelX = modalX + 30
    local cancelHovered = self:isButtonHovered(cancelX, buttonY, buttonWidth, buttonHeight)
    local cancelColor = cancelHovered and Theme.colors.surfaceHighlight or Theme.colors.surface2
    nineSlice:draw(cancelX, buttonY, buttonWidth, buttonHeight, cancelColor, Theme.nineSlice.borderScale)
    love.graphics.setColor(Theme.colors.text)
    local cancelText = "Cancel"
    local cancelTextWidth = labelFont:getWidth(cancelText)
    love.graphics.print(cancelText,
        cancelX + (buttonWidth - cancelTextWidth) / 2,
        buttonY + (buttonHeight - labelFont:getHeight()) / 2)

    -- Confirm button
    local confirmX = modalX + modalWidth - buttonWidth - 30
    local confirmHovered = self:isButtonHovered(confirmX, buttonY, buttonWidth, buttonHeight)
    local confirmColor = confirmHovered and Theme.colors.cyan or
        { Theme.colors.cyan[1] * 0.85, Theme.colors.cyan[2] * 0.85, Theme.colors.cyan[3] * 0.85, 1 }
    nineSlice:draw(confirmX, buttonY, buttonWidth, buttonHeight, confirmColor, Theme.nineSlice.borderScale)
    love.graphics.setColor(Theme.colors.textDark)
    local confirmText = "Confirm"
    local confirmTextWidth = labelFont:getWidth(confirmText)
    love.graphics.print(confirmText,
        confirmX + (buttonWidth - confirmTextWidth) / 2,
        buttonY + (buttonHeight - labelFont:getHeight()) / 2)

    love.graphics.setColor(1, 1, 1, 1)
end

function DiceEditor:drawModalFace(x, y, size, value)
    if Theme.diceSpritesheet then
        local quad = Theme.diceSpritesheet:getQuad(value)
        local image = Theme.diceSpritesheet:getImage()

        love.graphics.setColor(1, 1, 1, 1)
        local spriteW, _ = Theme.diceSpritesheet:getSpriteSize()
        local scale = size / spriteW
        love.graphics.draw(image, quad, x, y, 0, scale, scale)
    else
        local nineSlice = require("src.ui.nine_slice").getInstance()
        nineSlice:draw(x, y, size, size, Theme.colors.panelDark, Theme.nineSlice.borderScale)
        love.graphics.setColor(1, 1, 1, 1)
        local font = Theme.fonts.huge
        love.graphics.setFont(font)
        local text = tostring(value)
        love.graphics.print(text,
            x + (size - font:getWidth(text)) / 2,
            y + (size - font:getHeight()) / 2)
    end
end

function DiceEditor:isButtonHovered(bx, by, bw, bh)
    local mx, my = love.mouse.getPosition()
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end
    if not mx or not my then return false end
    return mx >= bx and mx < bx + bw and my >= by and my < by + bh
end

return DiceEditor
