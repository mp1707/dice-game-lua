-- Play State - Main gameplay with NEW UI layout
-- Left: Info panel | Center: Item strip + Selection panels + Dice + CTAs

local Theme = require("src.ui.theme")
local Timer = require("src.core.timer")
local GameState = require("src.game.game_state")
local Hands = require("src.game.hands")
local Scoring = require("src.game.scoring")
local Levels = require("src.game.levels")

local NineSlice = require("src.ui.nine_slice")
local DiceDisplay = require("src.ui.dice_display")
local ItemStrip = require("src.ui.item_strip")
local SelectionPanel = require("src.ui.selection_panel")
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
    self.zahlenPanel = nil
    self.kombinationenPanel = nil
    self.infoPanel = nil
    self.dualCta = nil

    -- Dice home positions (center area below selection panels)
    self.diceHomePositions = {}

    -- Drag state
    self.draggingDice = nil

    -- Reference to state machine (set in enter)
    self.stateMachine = nil

    -- Round counter (mock for now)
    self.currentRound = 1

    return self
end

function PlayState:enter(params)
    self.stateMachine = params.stateMachine

    -- Initialize UI components
    self:initDiceHomePositions()
    self:initDiceDisplays()
    self:initItemStrip()
    self:initSelectionPanels()
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
                -- Default click handler (left click)
                self:onDiceLeftClick(index)
            end,
        })
        -- Set home position for returning from selection panels
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

function PlayState:initSelectionPanels()
    local layout = Theme.layout
    local panelGap = layout.selectionPanelGap or 30
    local totalPanelWidth = layout.centerWidth - panelGap
    local panelWidth = totalPanelWidth / 2

    -- Zahlen panel (left)
    self.zahlenPanel = SelectionPanel.new({
        x = layout.centerX,
        y = layout.selectionPanelY,
        width = panelWidth,
        height = layout.selectionPanelHeight,
        title = "Zahlen",
        section = "upper",
        getSelectedDice = function()
            return GameState.zahlenDice
        end,
        getDiceValue = function(idx)
            return GameState.dice[idx] and GameState.dice[idx].value or 1
        end,
        onDiceClick = function(diceIdx)
            self:onRemoveDiceFromSelection(diceIdx)
        end,
    })

    -- Kombinationen panel (right)
    self.kombinationenPanel = SelectionPanel.new({
        x = layout.centerX + panelWidth + panelGap,
        y = layout.selectionPanelY,
        width = panelWidth,
        height = layout.selectionPanelHeight,
        title = "Kombinationen",
        section = "lower",
        getSelectedDice = function()
            return GameState.kombinationenDice
        end,
        getDiceValue = function(idx)
            return GameState.dice[idx] and GameState.dice[idx].value or 1
        end,
        onDiceClick = function(diceIdx)
            self:onRemoveDiceFromSelection(diceIdx)
        end,
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

-- Get the currently detected hand based on selection mode
function PlayState:getDetectedHand()
    if GameState.selectionMode == "zahlen" and #GameState.zahlenDice > 0 then
        local handId = Scoring.detectZahlenHand(GameState.zahlenDice, GameState.dice)
        if handId then
            local handDef = Hands:get(handId)
            return {
                id = handId,
                name = handDef.name,
                level = handDef.level or 1,
            }
        end
    elseif GameState.selectionMode == "kombinationen" and #GameState.kombinationenDice > 0 then
        local handId = Scoring.detectBestKombination(GameState.dice)
        if handId then
            local handDef = Hands:get(handId)
            return {
                id = handId,
                name = handDef.name,
                level = handDef.level or 1,
            }
        end
    end
    return nil
end

function PlayState:canPlayHand()
    if GameState.isRolling then return false end
    if not GameState.hasRolledThisHand then return false end

    local detected = self:getDetectedHand()
    if not detected then return false end

    -- Check if the hand is already used
    if GameState:isHandUsed(detected.id) then return false end

    return true
end

function PlayState:canRoll()
    if GameState.isRolling then return false end
    if not GameState:canRoll() then return false end
    -- Can roll if we have rolls remaining
    return true
end

-- Handle left-click on dice (Zahlen selection)
function PlayState:onDiceLeftClick(index)
    if GameState.isRolling then return end
    if not GameState.hasRolledThisHand then return end

    -- If already in zahlen, remove it
    if GameState:isDiceInZahlen(index) then
        self:onRemoveDiceFromSelection(index)
    else
        -- Add to zahlen (clears kombinationen if needed)
        if GameState:selectDiceForZahlen(index) then
            self:moveDiceToZahlenPanel(index)
        end
    end
end

-- Handle right-click on dice (Kombinationen selection)
function PlayState:onDiceRightClick(index)
    if GameState.isRolling then return end
    if not GameState.hasRolledThisHand then return end

    -- If already in kombinationen, remove it
    if GameState:isDiceInKombinationen(index) then
        self:onRemoveDiceFromSelection(index)
    else
        -- Add to kombinationen (clears zahlen if needed)
        if GameState:selectDiceForKombinationen(index) then
            self:moveDiceToKombinationenPanel(index)
        end
    end
end

-- Remove dice from whichever selection it's in
function PlayState:onRemoveDiceFromSelection(index)
    -- Check if dice was cleared due to switching modes
    local wasInZahlen = GameState:isDiceInZahlen(index)
    local wasInKombinationen = GameState:isDiceInKombinationen(index)

    if GameState:removeDiceFromSelection(index) then
        self:moveDiceToHome(index)
    end

    -- Also check if other dice were cleared (due to mode switch)
    for i = 1, 5 do
        if not GameState:isDiceSelected(i) then
            local display = self.diceDisplays[i]
            if display.isInHeldTray then
                self:moveDiceToHome(i)
            end
        end
    end
end

function PlayState:moveDiceToZahlenPanel(index)
    local display = self.diceDisplays[index]
    local slotIndex = #GameState.zahlenDice -- Position in the zahlen array

    -- Get slot position from panel
    local slotX, slotY = self.zahlenPanel:getSlotPosition(slotIndex)
    if slotX and slotY then
        display:moveToHeldSlot(slotX, slotY, slotIndex)
        display.isInHeldTray = true
        display.heldSlotIndex = slotIndex
    end
end

function PlayState:moveDiceToKombinationenPanel(index)
    local display = self.diceDisplays[index]
    local slotIndex = #GameState.kombinationenDice -- Position in the kombinationen array

    -- Get slot position from panel
    local slotX, slotY = self.kombinationenPanel:getSlotPosition(slotIndex)
    if slotX and slotY then
        display:moveToHeldSlot(slotX, slotY, slotIndex)
        display.isInHeldTray = true
        display.heldSlotIndex = slotIndex
    end
end

function PlayState:moveDiceToHome(index)
    local display = self.diceDisplays[index]
    display:returnToLoose()
    display.isInHeldTray = false
    display.heldSlotIndex = nil
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

    -- Roll immediately so the new values are ready when animation ends
    if not GameState:rollDice() then return end

    GameState.isRolling = true

    -- Start animations for unlocked dice only
    for i, die in ipairs(GameState.dice) do
        if not die.locked then
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

    -- Update selection panels
    self.zahlenPanel:update(dt)
    self.kombinationenPanel:update(dt)

    -- Update info panel
    self.infoPanel:update(dt)

    -- Update dual CTA buttons
    self.dualCta:update(dt)

    -- Update dice positions based on selection state
    self:updateDicePositions()
end

function PlayState:updateDicePositions()
    -- Ensure dice in selection panels are positioned correctly
    for i, idx in ipairs(GameState.zahlenDice) do
        local display = self.diceDisplays[idx]
        local slotX, slotY = self.zahlenPanel:getSlotPosition(i)
        if slotX and slotY and not display.isDragging then
            if display.targetX ~= slotX or display.targetY ~= slotY then
                display:animateTo(slotX, slotY)
            end
            display.isInHeldTray = true
        end
    end

    for i, idx in ipairs(GameState.kombinationenDice) do
        local display = self.diceDisplays[idx]
        local slotX, slotY = self.kombinationenPanel:getSlotPosition(i)
        if slotX and slotY and not display.isDragging then
            if display.targetX ~= slotX or display.targetY ~= slotY then
                display:animateTo(slotX, slotY)
            end
            display.isInHeldTray = true
        end
    end
end

function PlayState:draw()
    -- Draw item strip (top center)
    self.itemStrip:draw()

    -- Draw selection panels
    self.zahlenPanel:draw()
    self.kombinationenPanel:draw()

    -- Apply screen shake to dice area
    local shakeX, shakeY = Juice.getShakeOffset()
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- Draw dice with proper layering:
    -- 1. Dice in selection panels (locked) - drawn first
    -- 2. Dice in home area (unlocked) - drawn on top
    -- 3. Dragging dice - drawn last (always on top)
    for _, display in ipairs(self.diceDisplays) do
        local data = display.getDiceData()
        if not display.isDragging and data.locked then
            display:draw()
        end
    end
    for _, display in ipairs(self.diceDisplays) do
        local data = display.getDiceData()
        if not display.isDragging and not data.locked then
            display:draw()
        end
    end
    for _, display in ipairs(self.diceDisplays) do
        if display.isDragging then
            display:draw()
        end
    end

    love.graphics.pop()

    -- Draw info panel (left panel)
    self.infoPanel:draw()

    -- Draw dual CTA buttons (bottom center)
    self.dualCta:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayState:mousemoved(x, y)
    -- Update dragging dice position
    if self.draggingDice then
        self.draggingDice:updateDrag(x, y)
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

    -- Check selection panel clicks (to remove dice)
    if button == 1 then
        if self.zahlenPanel:mousepressed(x, y, button) then
            return
        end
        if self.kombinationenPanel:mousepressed(x, y, button) then
            return
        end
    end

    -- Check if clicking on a dice in home area
    if GameState.hasRolledThisHand and not GameState.isRolling then
        for i, display in ipairs(self.diceDisplays) do
            if display:containsPoint(x, y) and not GameState:isDiceSelected(i) then
                if button == 1 then
                    -- Left click - Zahlen selection
                    self:onDiceLeftClick(i)
                    return
                elseif button == 2 then
                    -- Right click - Kombinationen selection
                    self:onDiceRightClick(i)
                    return
                end
            end
        end
    end
end

function PlayState:mousereleased(x, y, button)
    -- Release dual CTA
    self.dualCta:mousereleased(x, y, button)

    -- Release info panel
    self.infoPanel:mousereleased(x, y, button)
end

function PlayState:keypressed(key)
    -- Debug keys
    if key == "space" then
        -- Roll if possible, otherwise play hand if possible
        if self:canRoll() then
            self:rollDice()
        elseif self:canPlayHand() then
            self:onPlayHandClick()
        end
    elseif key == "1" or key == "2" or key == "3" or key == "4" or key == "5" then
        local index = tonumber(key)
        -- Default to left-click behavior (Zahlen)
        self:onDiceLeftClick(index)
    end
end

return PlayState
