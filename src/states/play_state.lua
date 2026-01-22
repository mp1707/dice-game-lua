-- Play State - Main gameplay
-- Left: Info panel | Center: Item strip + Dice + CTAs

local Theme = require("src.ui.theme")
local Timer = require("src.core.timer")
local GameState = require("src.game.game_state")
local Scoring = require("src.game.scoring")

local NineSlice = require("src.ui.nine_slice")
local DiceDisplay = require("src.ui.dice_display")
local ItemStrip = require("src.ui.item_strip")
local InfoPanel = require("src.ui.info_panel")
local DualCta = require("src.ui.dual_cta")
local Juice = require("src.dice.juice")

local PlayState = {}
PlayState.__index = PlayState

function PlayState.new()
    local self = setmetatable({}, PlayState)

    self.timer = Timer.new()
    self.nineSlice = NineSlice.getInstance()

    -- UI Components
    self.diceDisplays = {}
    self.itemStrip = nil
    self.infoPanel = nil
    self.dualCta = nil

    -- Dice home positions (center area)
    self.diceHomePositions = {}

    -- Visual order of dice (slot index -> dice index)
    -- e.g., {3, 1, 2, 4, 5} means slot 1 shows die 3, slot 2 shows die 1, etc.
    self.diceVisualOrder = { 1, 2, 3, 4, 5 }

    -- Hover slot during drag (which slot the dragged die is hovering over)
    self.hoverSlot = nil

    -- Drag state
    self.draggingDice = nil

    -- Reference to state machine (set in enter)
    self.stateMachine = nil

    -- Round counter (mock for now)
    self.currentRound = 1

    -- Selection rectangle state (drag-to-select)
    self.isSelectingRect = false
    self.isDeselecting = false -- true if right-click (deselect mode)
    self.selectRectStartX = nil
    self.selectRectStartY = nil
    self.selectRectEndX = nil
    self.selectRectEndY = nil

    return self
end

function PlayState:enter(params)
    self.stateMachine = params.stateMachine

    -- Initialize UI components
    self:initDiceHomePositions()
    self:initDiceDisplays()
    self:initItemStrip()
    self:initInfoPanel()
    self:initDualCta()
end

function PlayState:exit()
    self.timer:clear()
end

function PlayState:initDiceHomePositions()
    local layout = Theme.layout
    -- Calculate positions for a neat horizontal row in the center
    local centerX = layout.centerX + (layout.centerWidth / 2)
    local baseY = layout.diceHomeY
    local diceSize = layout.diceSize
    local diceSpacing = layout.diceSpacing

    -- Calculate total width and starting X for centered row
    local totalWidth = 5 * diceSize + 4 * diceSpacing
    local startX = centerX - totalWidth / 2

    -- Create evenly-spaced positions in a straight horizontal line
    self.diceHomePositions = {}
    for i = 1, 5 do
        self.diceHomePositions[i] = {
            x = startX + (i - 1) * (diceSize + diceSpacing),
            y = baseY
        }
    end
end

function PlayState:initDiceDisplays()
    for i = 1, 5 do
        local pos = self.diceHomePositions[i]
        self.diceDisplays[i] = DiceDisplay.new({
            x = pos.x,
            y = pos.y,
            size = Theme.layout.diceSize,
            index = i,
            getDiceData = function()
                return GameState.dice[i]
            end,
            onClick = function(index)
                self:onDiceClick(index)
            end,
        })
        -- Set home position
        self.diceDisplays[i]:setHomePosition(pos.x, pos.y)
    end
end

function PlayState:initItemStrip()
    local layout = Theme.layout
    -- Create temp strip to get width
    local tempStrip = ItemStrip.new({})
    local totalWidth = tempStrip:getTotalWidth()
    local stripX = layout.centerX + (layout.centerWidth - totalWidth) / 2

    self.itemStrip = ItemStrip.new({
        x = stripX,
        y = layout.itemStripY,
    })
end

function PlayState:initInfoPanel()
    local layout = Theme.layout

    self.infoPanel = InfoPanel.new({
        x = layout.leftPanelX,
        y = layout.leftPanelY,
        width = layout.leftPanelWidth,
        height = layout.leftPanelHeight,
        getLevel = function()
            return GameState.currentLevel
        end,
        getRound = function()
            return self.currentRound
        end,
        getMoney = function()
            return GameState.money
        end,
        getGoal = function()
            return GameState:getCurrentGoal()
        end,
        getScore = function()
            return GameState.currentScore
        end,
        hasReachedGoal = function()
            return GameState:hasReachedGoal()
        end,
        getHandsRemaining = function()
            return GameState.handsRemaining
        end,
        getRollsRemaining = function()
            return GameState.rollsRemaining
        end,
        getDetectedHand = function()
            return self:getDetectedHand()
        end,
        getHandBreakdown = function()
            local detected = self:getDetectedHand()
            if detected then
                return Scoring.getBreakdown(detected.id, GameState.dice)
            end
            return nil
        end,
    })
end

function PlayState:initDualCta()
    local layout = Theme.layout

    self.dualCta = DualCta.new({
        centerX = layout.centerX,
        centerWidth = layout.centerWidth,
        y = layout.ctaY,
        buttonWidth = layout.ctaWidth,
        buttonHeight = layout.ctaHeight,
        spacing = layout.ctaSpacing,
        onPlayHand = function()
            self:onPlayHandClick()
        end,
        onRoll = function()
            self:rollDice()
        end,
        canPlayHand = function()
            return self:canPlayHand()
        end,
        canRoll = function()
            return self:canRoll()
        end,
    })
end

-- Auto-detect the best hand from selected dice
function PlayState:getDetectedHand()
    local indices = GameState:getSelectedDiceIndices()
    local hand = Scoring.detectBestHand(indices, GameState.dice)

    -- Filter out used hands
    if hand and GameState:isHandUsed(hand.id) then
        return nil
    end

    return hand
end

function PlayState:canPlayHand()
    if GameState.isRolling then return false end
    if not GameState.hasRolledThisHand then return false end

    -- Check if a valid hand is detected
    local detected = self:getDetectedHand()
    return detected ~= nil
end

function PlayState:canRoll()
    if GameState.isRolling then return false end
    if not GameState:canRoll() then return false end
    -- Can roll if we have rolls remaining
    return true
end

-- Handle unified click on dice (toggle selection)
function PlayState:onDiceClick(index)
    if GameState.isRolling then return end
    if not GameState.hasRolledThisHand then return end

    -- Toggle the dice selection
    GameState:toggleDiceSelection(index)
end

function PlayState:onPlayHandClick()
    if not self:canPlayHand() then return end

    local detected = self:getDetectedHand()
    if not detected then return end

    local score = Scoring.calculateScore(detected.id, GameState.dice)
    GameState:useHand(detected.id, score)

    -- Check end conditions
    if GameState:hasLostLevel() then
        self.stateMachine:change("result", {
            won = false,
            stateMachine = self.stateMachine,
        })
    elseif GameState:hasReachedGoal() then
        -- Goal reached! Immediately cash out
        self:cashOut()
    elseif GameState:allHandsUsed() then
        -- All hands used but goal not reached
        self.stateMachine:change("result", {
            won = false,
            stateMachine = self.stateMachine,
        })
    else
        -- Continue playing - reset for next hand
        self:resetForNextHand()
    end
end

function PlayState:rollDice()
    if not GameState:canRoll() then return end

    -- Capture selection state BEFORE rolling (because rolling clears it)
    local selectedIndices = {}
    for _, idx in ipairs(GameState:getSelectedDiceIndices()) do
        selectedIndices[idx] = true
    end
    -- We can check if it's the first roll BEFORE calling rollDice which sets the flag
    local isFirstRoll = not GameState.hasRolledThisHand

    -- Roll immediately so the new values are ready when animation ends
    if not GameState:rollDice() then return end

    GameState.isRolling = true

    -- Start animations based on captured logic
    for i, die in ipairs(GameState.dice) do
        -- Animate if:
        -- 1. It was the Initial Roll (no selection matters) -> Animate all
        -- 2. This die WAS selected (Reroll) -> Animate
        if isFirstRoll or selectedIndices[i] then
            self.diceDisplays[i]:startRollAnimation()
        end
    end

    -- Finish rolling state after animation
    self.timer:after(1.5, function()
        GameState.isRolling = false
    end)
end

function PlayState:resetForNextHand()
    -- Clear selections and reset game state
    GameState:resetForHand()

    -- Reset visual order to default
    self.diceVisualOrder = { 1, 2, 3, 4, 5 }

    -- Reset dice positions to home area
    for i, display in ipairs(self.diceDisplays) do
        display.isInHeldTray = false
        display.heldSlotIndex = nil
        display:snapTo(self.diceHomePositions[i].x, self.diceHomePositions[i].y)
    end

    -- Increment round
    self.currentRound = self.currentRound + 1
end

function PlayState:cashOut()
    self.stateMachine:change("result", {
        won = true,
        stateMachine = self.stateMachine,
    })
end

function PlayState:update(dt)
    self.timer:update(dt)

    -- Update juice effects (screen shake)
    Juice.updateShake(dt)

    -- Update dice displays
    for _, display in ipairs(self.diceDisplays) do
        display:update(dt)
    end

    -- Update info panel
    self.infoPanel:update(dt)

    -- Update dual CTA buttons
    self.dualCta:update(dt)

    -- Update dice positions based on selection state
    self:updateDicePositions()
end

function PlayState:updateDicePositions()
    -- Calculate target positions for all dice based on:
    -- 1. Their slot in diceVisualOrder
    -- 2. Whether another die is being dragged and hovering over a slot
    -- 3. Selection state (Y offset)

    local layout = Theme.layout
    local diceSize = layout.diceSize
    local diceSpacing = layout.diceSpacing

    -- Update hover slot if dragging
    if self.draggingDice then
        self.hoverSlot = self:getSlotFromX(self.draggingDice.x + diceSize / 2)
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

    -- Calculate target positions for each die
    for slot, dieIndex in ipairs(self.diceVisualOrder) do
        local display = self.diceDisplays[dieIndex]

        -- Skip the die being dragged
        if display.isDragging then
            goto continue
        end

        -- Calculate base X position for this slot
        local targetSlot = slot
        local targetX = self.diceHomePositions[slot].x

        -- If we're dragging a die and hovering, shift other dice
        if self.hoverSlot and draggedCurrentSlot then
            if self.hoverSlot < draggedCurrentSlot then
                -- Dragging left: dice between hoverSlot and draggedCurrentSlot shift right
                if slot >= self.hoverSlot and slot < draggedCurrentSlot then
                    targetX = self.diceHomePositions[slot + 1].x
                end
            elseif self.hoverSlot > draggedCurrentSlot then
                -- Dragging right: dice between draggedCurrentSlot and hoverSlot shift left
                if slot > draggedCurrentSlot and slot <= self.hoverSlot then
                    targetX = self.diceHomePositions[slot - 1].x
                end
            end
        end

        -- Calculate Y based on selection state
        local baseY = self.diceHomePositions[slot].y
        local targetY = baseY
        if GameState:isDiceSelected(dieIndex) then
            targetY = baseY + Theme.layout.diceSelectedOffsetY
        end

        -- Animate to target position
        display:animateTo(targetX, targetY)

        ::continue::
    end
end

-- Get slot index (1-5) from X coordinate
function PlayState:getSlotFromX(x)
    local layout = Theme.layout
    local diceSize = layout.diceSize
    local diceSpacing = layout.diceSpacing

    -- Calculate slot boundaries
    for slot = 1, 5 do
        local slotX = self.diceHomePositions[slot].x
        local slotCenterX = slotX + diceSize / 2

        -- First slot: anything to the left of center goes here
        if slot == 1 then
            if x < slotCenterX + (diceSize + diceSpacing) / 2 then
                return 1
            end
            -- Last slot: anything to the right goes here
        elseif slot == 5 then
            if x >= slotCenterX - (diceSize + diceSpacing) / 2 then
                return 5
            end
            -- Middle slots: check if x is within half-spacing of slot center
        else
            local leftBound = slotCenterX - (diceSize + diceSpacing) / 2
            local rightBound = slotCenterX + (diceSize + diceSpacing) / 2
            if x >= leftBound and x < rightBound then
                return slot
            end
        end
    end

    return 3 -- Default to middle slot
end

-- Reorder dice: move die from oldSlot to newSlot
function PlayState:reorderDice(dieIndex, newSlot)
    -- Find current slot
    local oldSlot = nil
    for slot, idx in ipairs(self.diceVisualOrder) do
        if idx == dieIndex then
            oldSlot = slot
            break
        end
    end

    if not oldSlot or oldSlot == newSlot then return end

    -- Remove from old position
    table.remove(self.diceVisualOrder, oldSlot)

    -- Insert at new position
    table.insert(self.diceVisualOrder, newSlot, dieIndex)
end

function PlayState:draw()
    -- Draw item strip (top center)
    self.itemStrip:draw()

    -- Draw info panel (left panel)
    self.infoPanel:draw()

    -- Draw dual CTA buttons (bottom center)
    self.dualCta:draw()

    -- Apply screen shake to dice area
    local shakeX, shakeY = Juice.getShakeOffset()
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- Draw dice with proper layering or "Roll the dice!" text
    local showDice = GameState.hasRolledThisHand or GameState.isRolling

    if showDice then
        -- 1. Unselected dice (unlocked) - drawn first
        -- 2. Selected dice (locked) - drawn on top
        -- 3. Dragging dice - drawn last (always on top)
        for _, display in ipairs(self.diceDisplays) do
            local data = display.getDiceData()
            if not display.isDragging and not data.locked then
                display:draw()
            end
        end
        for _, display in ipairs(self.diceDisplays) do
            local data = display.getDiceData()
            if not display.isDragging and data.locked then
                display:draw()
            end
        end
        for _, display in ipairs(self.diceDisplays) do
            if display.isDragging then
                display:draw()
            end
        end
    else
        -- Draw "Roll the dice!" text
        local layout = Theme.layout
        local centerX = layout.centerX + (layout.centerWidth / 2)
        local totalDiceWidth = 5 * layout.diceSize + 4 * layout.diceSpacing
        local startX = centerX - totalDiceWidth / 2
        local centerY = layout.diceHomeY + layout.diceSize / 2

        -- Use display font (66px) or giant (80px)
        Theme:drawTextCenteredWithShadow(
            "Roll the dice!",
            startX,
            centerY - Theme.fonts.display:getHeight() / 2,
            totalDiceWidth,
            Theme.fonts.display,
            Theme.colors.textMuted
        )
    end

    -- Draw selection rectangle on top of dice (but below UI)
    if self.isSelectingRect then
        self:drawSelectionRect()
    end

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayState:mousemoved(x, y)
    -- Update selection rectangle if active
    if self.isSelectingRect then
        self.selectRectEndX = x
        self.selectRectEndY = y
        -- Update dice feedback (which dice are inside the rectangle)
        self:updateDiceInSelectionRect()
    end

    -- Update dragging dice position
    if self.draggingDice then
        self.draggingDice:updateDrag(x, y)
    end

    -- Update hover state for all dice (Balatro-style tilt effect)
    for _, display in ipairs(self.diceDisplays) do
        display:updateHover(x, y)
    end
end

function PlayState:mousepressed(x, y, button)
    -- Check info panel clicks (settings/info buttons)
    if self.infoPanel:mousepressed(x, y, button) then
        return
    end

    -- Check dual CTA clicks
    if self.dualCta:mousepressed(x, y, button) then
        return
    end

    -- Check if clicking on a dice - start drag (selection happens on release)
    if GameState.hasRolledThisHand and not GameState.isRolling then
        for i, display in ipairs(self.diceDisplays) do
            if display:containsPoint(x, y) then
                if button == 1 then
                    -- Start dragging this die
                    self.draggingDice = display
                    self.draggingDiceIndex = i
                    self.dragStartX = x
                    self.dragStartY = y
                    display:startDrag(x, y)
                    display:setHeld(true)
                    return
                end
            end
        end
    end

    -- Background click - start selection rectangle (works anytime for fidgeting)
    if button == 1 and not GameState.isRolling then
        -- Check if click is NOT on the info panel
        local layout = Theme.layout
        local isOnInfoPanel = x >= layout.leftPanelX and
            x <= layout.leftPanelX + layout.leftPanelWidth and
            y >= layout.leftPanelY and
            y <= layout.leftPanelY + layout.leftPanelHeight

        if not isOnInfoPanel then
            self.isSelectingRect = true
            self.isDeselecting = false
            self.selectRectStartX = x
            self.selectRectStartY = y
            self.selectRectEndX = x
            self.selectRectEndY = y
        end
    end

    -- Right-click background - start deselection rectangle
    if button == 2 and not GameState.isRolling then
        -- Check if click is NOT on the info panel
        local layout = Theme.layout
        local isOnInfoPanel = x >= layout.leftPanelX and
            x <= layout.leftPanelX + layout.leftPanelWidth and
            y >= layout.leftPanelY and
            y <= layout.leftPanelY + layout.leftPanelHeight

        if not isOnInfoPanel then
            self.isSelectingRect = true
            self.isDeselecting = true
            self.selectRectStartX = x
            self.selectRectStartY = y
            self.selectRectEndX = x
            self.selectRectEndY = y
        end
    end
end

function PlayState:mousereleased(x, y, button)
    -- Release dual CTA
    self.dualCta:mousereleased(x, y, button)

    -- Release info panel
    self.infoPanel:mousereleased(x, y, button)

    -- Handle dice drag release
    if button == 1 and self.draggingDice then
        local display = self.draggingDice
        local index = self.draggingDiceIndex

        -- Find current slot index for this die
        local currentSlot = nil
        for slot, dieIndex in ipairs(self.diceVisualOrder) do
            if dieIndex == index then
                currentSlot = slot
                break
            end
        end

        -- Get home position for this die's current slot
        local homePos = self.diceHomePositions[currentSlot]

        -- Stop dragging/holding
        local currentY = display:endDrag()

        -- Check if it was a simple click (moved less than threshold)
        local dragDistX = math.abs(x - self.dragStartX)
        local dragDistY = math.abs(y - self.dragStartY)
        local dragDist = math.sqrt(dragDistX ^ 2 + dragDistY ^ 2)
        local clickThreshold = 6
        local horizontalDragThreshold = 20 -- Minimum X movement to trigger reorder

        if dragDist < clickThreshold then
            -- Simple click: toggle selection
            GameState:toggleDiceSelection(index)
        elseif dragDistX > horizontalDragThreshold then
            -- Horizontal drag: reorder dice
            local layout = Theme.layout
            local dropSlot = self:getSlotFromX(display.x + layout.diceSize / 2)
            self:reorderDice(index, dropSlot)
        else
            -- Primarily vertical drag: determine selection based on Y position
            local homeY = homePos.y
            local selectedY = homeY + Theme.layout.diceSelectedOffsetY
            local midpointY = (homeY + selectedY) / 2

            -- Determine if should be selected based on Y position (up is smaller Y)
            local shouldBeSelected = currentY < midpointY
            local isCurrentlySelected = GameState:isDiceSelected(index)

            -- Change state if dropped in different zone
            if shouldBeSelected ~= isCurrentlySelected then
                GameState:toggleDiceSelection(index)
            end
        end

        -- Clear drag state and hover slot
        self.draggingDice = nil
        self.draggingDiceIndex = nil
        self.dragStartX = nil
        self.dragStartY = nil
        self.hoverSlot = nil
    end

    -- Handle selection rectangle release
    if (button == 1 or button == 2) and self.isSelectingRect then
        -- Select or deselect all dice inside the rectangle
        self:selectDiceInRect()
        -- Clear selection rectangle state
        self.isSelectingRect = false
        self.isDeselecting = false
        self.selectRectStartX = nil
        self.selectRectStartY = nil
        self.selectRectEndX = nil
        self.selectRectEndY = nil
        -- Clear dice feedback
        for _, display in ipairs(self.diceDisplays) do
            display:setInSelectionRect(false)
        end
    end
end

function PlayState:keypressed(key)
    if key == "space" then
        -- Roll if possible, otherwise play hand if possible
        if self:canRoll() then
            self:rollDice()
        elseif self:canPlayHand() then
            self:onPlayHandClick()
        end
    elseif key == "backspace" then
        -- Backspace triggers roll
        if self:canRoll() then
            self:rollDice()
        end
    elseif key == "1" or key == "2" or key == "3" or key == "4" or key == "5" then
        local index = tonumber(key)
        self:onDiceClick(index)
    end
end

-- =========================================================================
-- SELECTION RECTANGLE HELPERS
-- =========================================================================

-- Draw the selection rectangle
function PlayState:drawSelectionRect()
    if not self.selectRectStartX then return end

    -- Calculate rectangle bounds (handle reverse dragging)
    local x1 = math.min(self.selectRectStartX, self.selectRectEndX)
    local y1 = math.min(self.selectRectStartY, self.selectRectEndY)
    local x2 = math.max(self.selectRectStartX, self.selectRectEndX)
    local y2 = math.max(self.selectRectStartY, self.selectRectEndY)
    local w = x2 - x1
    local h = y2 - y1

    -- Draw filled rectangle (use purple for deselect mode)
    if self.isDeselecting then
        love.graphics.setColor(Theme.colors.deselectionRect)
    else
        love.graphics.setColor(Theme.colors.selectionRect)
    end
    love.graphics.rectangle("fill", x1, y1, w, h)

    -- Draw border
    if self.isDeselecting then
        love.graphics.setColor(Theme.colors.deselectionRectBorder)
    else
        love.graphics.setColor(Theme.colors.selectionRectBorder)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x1, y1, w, h)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1, 1)
end

-- Check if a dice display intersects with the selection rectangle
function PlayState:isDiceInSelectionRect(display)
    if not self.selectRectStartX then return false end

    -- Calculate rectangle bounds
    local rectX1 = math.min(self.selectRectStartX, self.selectRectEndX)
    local rectY1 = math.min(self.selectRectStartY, self.selectRectEndY)
    local rectX2 = math.max(self.selectRectStartX, self.selectRectEndX)
    local rectY2 = math.max(self.selectRectStartY, self.selectRectEndY)

    -- Dice bounds
    local diceX1 = display.x
    local diceY1 = display.y
    local diceX2 = display.x + display.size
    local diceY2 = display.y + display.size

    -- Check for intersection (AABB collision)
    return rectX1 < diceX2 and rectX2 > diceX1 and
        rectY1 < diceY2 and rectY2 > diceY1
end

-- Update which dice are inside the selection rectangle (for visual feedback)
function PlayState:updateDiceInSelectionRect()
    for _, display in ipairs(self.diceDisplays) do
        local isIn = self:isDiceInSelectionRect(display)
        display:setInSelectionRect(isIn)
    end
end

-- Select or deselect dice that are inside the selection rectangle
function PlayState:selectDiceInRect()
    for i, display in ipairs(self.diceDisplays) do
        if self:isDiceInSelectionRect(display) then
            if self.isDeselecting then
                -- Deselect the dice (if currently selected)
                if GameState:isDiceSelected(i) then
                    GameState:toggleDiceSelection(i)
                end
            else
                -- Select the dice (if not currently selected)
                if not GameState:isDiceSelected(i) then
                    GameState:toggleDiceSelection(i)
                end
            end
        end
    end
end

return PlayState
