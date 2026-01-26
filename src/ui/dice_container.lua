-- Dice Container
-- Manages the layout, interaction, and rendering of the 5 dice
-- Handles drag-and-drop reordering, selection, and animations

local Theme = require("src.ui.theme")
local DiceDisplay = require("src.ui.dice_display")
local Juice = require("src.ui.juice")
local Sound = require("src.core.sound")
local MouseSelection = require("src.ui.mouse_selection")
local Stickers = require("src.game.stickers")

local DiceContainer = {}
DiceContainer.__index = DiceContainer

function DiceContainer.new(config)
    local self = setmetatable({}, DiceContainer)

    self.x = config.x or 0
    self.y = config.y or 0

    -- Dependencies
    self.onDiceClick = config.onDiceClick or function(index) end
    self.getDiceData = config.getDiceData or function(index) return { value = 1, locked = false } end
    self.isRolling = config.isRolling or function() return false end

    -- Layout
    self.diceDisplays = {}
    self.diceHomePositions = {}
    self.diceVisualOrder = { 1, 2, 3, 4, 5 } -- slot index -> dice index

    -- Interaction State
    self.draggingDice = nil
    self.draggingDiceIndex = nil
    self.dragStartX = nil
    self.dragStartY = nil
    self.hoverSlot = nil

    -- Selection Rectangle State
    self.isSelectingRect = false
    self.isDeselecting = false
    self.selectRectStartX = nil
    self.selectRectStartY = nil
    self.selectRectEndX = nil
    self.selectRectEndY = nil

    self:initDiceDisplays()

    return self
end

function DiceContainer:initDiceDisplays()
    local layout = Theme.layout
    local diceSize = layout.diceSize
    local diceSpacing = layout.diceSpacing

    -- Calculate positions for a neat horizontal row
    -- We assume the container is centered or we use global coordinates if needed
    -- For now, reusing the logic from PlayState but adapting to be self-contained if possible
    -- However, PlayState used global absolute coordinates for dice. Let's stick to that for now to minimize breakage.

    local centerX = layout.centerX + (layout.centerWidth / 2)
    local baseY = layout.diceHomeY

    -- Calculate total width and starting X for centered row
    local totalWidth = 5 * diceSize + 4 * diceSpacing
    local startX = centerX - totalWidth / 2

    self.diceHomePositions = {}
    self.diceDisplays = {}

    for i = 1, 5 do
        -- Home position
        self.diceHomePositions[i] = {
            x = startX + (i - 1) * (diceSize + diceSpacing),
            y = baseY
        }

        -- Create display
        self.diceDisplays[i] = DiceDisplay.new({
            x = self.diceHomePositions[i].x,
            y = self.diceHomePositions[i].y,
            size = diceSize,
            index = i,
            getDiceData = function()
                return self.getDiceData(i)
            end,
            onClick = function(index)
                self.onDiceClick(index)
            end,
        })
        self.diceDisplays[i]:setHomePosition(self.diceHomePositions[i].x, self.diceHomePositions[i].y)
    end
end

function DiceContainer:reset()
    -- Reset visual order
    self.diceVisualOrder = { 1, 2, 3, 4, 5 }

    -- Reset positions
    for i, display in ipairs(self.diceDisplays) do
        display.isInHeldTray = false
        display.heldSlotIndex = nil
        display:snapTo(self.diceHomePositions[i].x, self.diceHomePositions[i].y)
    end
end

function DiceContainer:startRollAnimation(selectedIndices, isFirstRoll)
    for i, display in ipairs(self.diceDisplays) do
        if isFirstRoll or selectedIndices[i] then
            -- Check if the current face is a metal sticker (can't be rerolled)
            -- Skip animation for metal faces unless it's the first roll
            local dieData = display.getDiceData()
            local canAnimate = true

            if not isFirstRoll and dieData.faces and dieData.rolledFaceIndex then
                local stickerId = dieData.faces[dieData.rolledFaceIndex]
                if stickerId and not Stickers:canReroll(stickerId) then
                    canAnimate = false
                end
            end

            if canAnimate then
                display:startRollAnimation()
            end
        end
    end
end

function DiceContainer:update(dt)
    -- Update dice displays
    for _, display in ipairs(self.diceDisplays) do
        display:update(dt)
    end

    -- Update positions based on drag/selection state
    self:updateDicePositions()
end

function DiceContainer:updateDicePositions()
    local layout = Theme.layout

    -- Update hover slot if dragging
    if self.draggingDice then
        self.hoverSlot = self:getSlotFromX(self.draggingDice.x + layout.diceSize / 2)
    else
        self.hoverSlot = nil
    end

    -- Find the current slot of the dragged die
    local draggedDiceIndex = self.draggingDiceIndex
    local draggedCurrentSlot = nil
    if draggedDiceIndex then
        for slot, dieIndex in ipairs(self.diceVisualOrder) do
            if dieIndex == draggedDiceIndex then
                draggedCurrentSlot = slot
                break
            end
        end
    end

    -- Calculate target positions
    for slot, dieIndex in ipairs(self.diceVisualOrder) do
        local display = self.diceDisplays[dieIndex]

        -- Skip dragged die
        if display.isDragging then
            goto continue
        end

        local targetX = self.diceHomePositions[slot].x

        -- Shift other dice if dragging
        if self.hoverSlot and draggedCurrentSlot then
            if self.hoverSlot < draggedCurrentSlot then
                -- Dragging left
                if slot >= self.hoverSlot and slot < draggedCurrentSlot then
                    targetX = self.diceHomePositions[slot + 1].x
                end
            elseif self.hoverSlot > draggedCurrentSlot then
                -- Dragging right
                if slot > draggedCurrentSlot and slot <= self.hoverSlot then
                    targetX = self.diceHomePositions[slot - 1].x
                end
            end
        end

        -- Calculate Y based on selection
        local baseY = self.diceHomePositions[slot].y
        local targetY = baseY
        local data = self.getDiceData(dieIndex)
        if data.locked then
            targetY = baseY + Theme.layout.diceSelectedOffsetY
        end

        display:animateTo(targetX, targetY)

        ::continue::
    end
end

function DiceContainer:getSlotFromX(x)
    local layout = Theme.layout
    local diceSize = layout.diceSize
    local diceSpacing = layout.diceSpacing

    for slot = 1, 5 do
        local slotX = self.diceHomePositions[slot].x
        local slotCenterX = slotX + diceSize / 2

        if slot == 1 then
            if x < slotCenterX + (diceSize + diceSpacing) / 2 then return 1 end
        elseif slot == 5 then
            if x >= slotCenterX - (diceSize + diceSpacing) / 2 then return 5 end
        else
            local leftBound = slotCenterX - (diceSize + diceSpacing) / 2
            local rightBound = slotCenterX + (diceSize + diceSpacing) / 2
            if x >= leftBound and x < rightBound then return slot end
        end
    end

    return 3
end

function DiceContainer:reorderDice(dieIndex, newSlot)
    local oldSlot = nil
    for slot, idx in ipairs(self.diceVisualOrder) do
        if idx == dieIndex then
            oldSlot = slot
            break
        end
    end

    if not oldSlot or oldSlot == newSlot then return end

    table.remove(self.diceVisualOrder, oldSlot)
    table.insert(self.diceVisualOrder, newSlot, dieIndex)
end

function DiceContainer:mousepressed(x, y, button)
    if self.isRolling() then return end

    -- Check dice click
    for i, display in ipairs(self.diceDisplays) do
        if display:containsPoint(x, y) then
            if button == 1 then
                print("Dice Clicked! Index:", i)
                -- Start dragging
                self.draggingDice = display
                self.draggingDiceIndex = i
                self.dragStartX = x
                self.dragStartY = y
                display:startDrag(x, y)
                display:setHeld(true)
                return true
            end
        end
    end

    return false
end

function DiceContainer:mousemoved(x, y)
    -- Update visual feedback based on global selection rect
    if MouseSelection.isActive then
        local rect = MouseSelection:getRect()
        if rect then
            self:updateSelectionFeedback(rect)
        end
    end

    if self.draggingDice then
        self.draggingDice:updateDrag(x, y)
    end

    for _, display in ipairs(self.diceDisplays) do
        display:updateHover(x, y)
    end
end

function DiceContainer:mousereleased(x, y, button)
    if button == 1 and self.draggingDice then
        local display = self.draggingDice
        local index = self.draggingDiceIndex

        -- Find slot
        local currentSlot = nil
        for slot, dieIndex in ipairs(self.diceVisualOrder) do
            if dieIndex == index then
                currentSlot = slot
                break
            end
        end

        local homePos = self.diceHomePositions[currentSlot]
        local currentY = display:endDrag()

        -- Check click vs drag
        local dragDistX = math.abs(x - self.dragStartX)
        local dragDistY = math.abs(y - self.dragStartY)
        local dragDist = math.sqrt(dragDistX ^ 2 + dragDistY ^ 2)
        local clickThreshold = 6
        local horizontalDragThreshold = 20

        if dragDist < clickThreshold then
            self.onDiceClick(index)
        elseif dragDistX > horizontalDragThreshold then
            local layout = Theme.layout
            local dropSlot = self:getSlotFromX(display.x + layout.diceSize / 2)
            self:reorderDice(index, dropSlot)
        else
            -- Vertical drag selection logic
            local homeY = homePos.y
            local selectedY = homeY + Theme.layout.diceSelectedOffsetY
            local midpointY = (homeY + selectedY) / 2

            local shouldBeSelected = currentY < midpointY
            local data = self.getDiceData(index)
            local isCurrentlySelected = data.locked

            if shouldBeSelected ~= isCurrentlySelected then
                self.onDiceClick(index) -- Toggle
            end
        end

        self.draggingDice = nil
        self.draggingDiceIndex = nil
        self.dragStartX = nil
        self.dragStartY = nil
        self.hoverSlot = nil
    end

    -- Commit selection if MouseSelection was active
    if MouseSelection.isActive and (button == 1 or button == 2) then
        local rect = MouseSelection:getRect()
        if rect then
            self:commitSelection(rect)
        end

        -- Always clear local feedback
        for _, display in ipairs(self.diceDisplays) do
            display:setInSelectionRect(false)
        end
    end
end

function DiceContainer:updateSelectionFeedback(rect)
    if self.isRolling() then
        for _, display in ipairs(self.diceDisplays) do
            display:setInSelectionRect(false)
        end
        return
    end

    local x1 = rect.x1
    local x2 = rect.x2
    local y1 = rect.y1
    local y2 = rect.y2

    for _, display in ipairs(self.diceDisplays) do
        local dx = display.x + display.size / 2
        local dy = display.y + display.size / 2

        local inRect = dx >= x1 and dx <= x2 and dy >= y1 and dy <= y2
        display:setInSelectionRect(inRect)
    end
end

function DiceContainer:commitSelection(rect)
    if self.isRolling() then return end

    local x1 = rect.x1
    local x2 = rect.x2
    local y1 = rect.y1
    local y2 = rect.y2
    local isDeselecting = rect.isDeselecting

    local anyChanged = false

    for i, display in ipairs(self.diceDisplays) do
        local dx = display.x + display.size / 2
        local dy = display.y + display.size / 2

        if dx >= x1 and dx <= x2 and dy >= y1 and dy <= y2 then
            local data = self.getDiceData(i)
            local isSelected = data.locked
            local changed = false

            if isDeselecting then
                if isSelected then
                    -- Pass true to suppress sound (we play one sound at end)
                    self.onDiceClick(i, true)
                    changed = true
                end
            else
                if not isSelected then
                    -- Pass true to suppress sound
                    self.onDiceClick(i, true)
                    changed = true
                end
            end

            if changed then
                anyChanged = true
            end
        end
    end

    if anyChanged then
        if isDeselecting then
            Sound:play("click")
        else
            Sound:play("lightClick")
        end
    end
end

function DiceContainer:draw()
    -- Apply shake
    local shakeX, shakeY = Juice.getShakeOffset()
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- Draw Dice
    -- 1. Unselected
    -- 2. Selected
    -- 3. Dragging
    for _, display in ipairs(self.diceDisplays) do
        local data = self.getDiceData(display.index)
        if not display.isDragging and not data.locked then
            display:draw()
        end
    end
    for _, display in ipairs(self.diceDisplays) do
        local data = self.getDiceData(display.index)
        if not display.isDragging and data.locked then
            display:draw()
        end
    end
    for _, display in ipairs(self.diceDisplays) do
        if display.isDragging then
            display:draw()
        end
    end

    -- Selection Rect is now drawn globally by MouseSelection

    love.graphics.pop()
end

return DiceContainer
