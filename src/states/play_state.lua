-- Play State - Main gameplay with new UI layout
-- Left: Hand selection | Center: Item strip + Held tray + Loose dice | Right: Info panel

local Theme = require("src.ui.theme")
local Timer = require("src.core.timer")
local GameState = require("src.game.game_state")
local Hands = require("src.game.hands")
local Scoring = require("src.game.scoring")
local Levels = require("src.game.levels")

local NineSlice = require("src.ui.nine_slice")
local DiceDisplay = require("src.ui.dice_display")
local ItemStrip = require("src.ui.item_strip")
local HeldTray = require("src.ui.held_tray")
local HandList = require("src.ui.hand_list")
local InfoPanel = require("src.ui.info_panel")
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
    self.heldTray = nil
    self.handList = nil
    self.infoPanel = nil

    -- Loose dice positions (staggered)
    self.looseDicePositions = {}

    -- Drag state
    self.draggingDice = nil

    -- Reference to state machine (set in enter)
    self.stateMachine = nil

    return self
end

function PlayState:enter(params)
    self.stateMachine = params.stateMachine

    -- Initialize UI components
    self:initLooseDicePositions()
    self:initDiceDisplays()
    self:initItemStrip()
    self:initHeldTray()
    self:initHandList()
    self:initInfoPanel()
end

function PlayState:exit()
    self.timer:clear()
end

function PlayState:initLooseDicePositions()
    local layout = Theme.layout
    -- Staggered positions below held tray
    local centerX = layout.centerX + (layout.centerWidth / 2)
    local baseY = layout.looseDiceY
    local diceSize = layout.diceSize

    -- Calculate centered positions with stagger
    local totalWidth = 5 * diceSize + 4 * 40 -- wider spacing for scattered look
    local startX = centerX - totalWidth / 2

    self.looseDicePositions = {
        { x = startX,                            y = baseY + 40 },
        { x = startX + diceSize + 60,            y = baseY + 80 },
        { x = startX + (diceSize + 40) * 2,      y = baseY },
        { x = startX + (diceSize + 40) * 3 - 20, y = baseY + 60 },
        { x = startX + (diceSize + 40) * 4 - 40, y = baseY + 30 },
    }
end

function PlayState:initDiceDisplays()
    for i = 1, 5 do
        local pos = self.looseDicePositions[i]
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
        -- Set home position for returning from tray
        self.diceDisplays[i]:setHomePosition(pos.x, pos.y)
    end
end

function PlayState:initItemStrip()
    local layout = Theme.layout
    -- Center the item strip
    local totalWidth = layout.itemSlotCount * layout.itemSlotSize +
        (layout.itemSlotCount - 1) * layout.itemSlotSpacing
    local stripX = layout.centerX + (layout.centerWidth - totalWidth) / 2

    self.itemStrip = ItemStrip.new({
        x = stripX,
        y = layout.itemStripY,
    })
end

function PlayState:initHeldTray()
    local layout = Theme.layout
    -- Center the held tray
    local totalWidth = layout.heldSlotCount * layout.heldSlotSize +
        (layout.heldSlotCount - 1) * layout.heldSlotSpacing
    local trayX = layout.centerX + (layout.centerWidth - totalWidth) / 2

    self.heldTray = HeldTray.new({
        x = trayX,
        y = layout.heldTrayY,
    })
end

function PlayState:initHandList()
    self.handList = HandList.new({
        x = Theme.layout.leftPanelX,
        y = Theme.layout.leftPanelY,
        width = Theme.layout.leftPanelWidth,
        height = Theme.layout.leftPanelHeight,
        isUsed = function(handId)
            return GameState:isHandUsed(handId)
        end,
        isSelected = function(handId)
            return GameState.selectedHandId == handId
        end,
        getScore = function(handId)
            return Scoring.calculateScore(handId, GameState.dice)
        end,
        isValidHand = function(handId)
            return Scoring.isValidHand(handId, GameState.dice)
        end,
        hasRolled = function()
            return GameState.hasRolledThisHand
        end,
        onClick = function(handId)
            self:onHandClick(handId)
        end,
    })
end

function PlayState:initInfoPanel()
    self.infoPanel = InfoPanel.new({
        x = Theme.layout.rightPanelX,
        y = Theme.layout.rightPanelY,
        width = Theme.layout.rightPanelWidth,
        height = Theme.layout.rightPanelHeight,
        getLevel = function()
            return GameState.currentLevel
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
        getSelectedHand = function()
            return GameState.selectedHandId
        end,
        getHandBreakdown = function()
            if GameState.selectedHandId then
                return Scoring.getBreakdown(GameState.selectedHandId, GameState.dice)
            end
            return nil
        end,
        onActionClick = function()
            self:onActionButtonClick()
        end,
        getActionText = function()
            return self:getActionButtonText()
        end,
        getActionEnabled = function()
            return self:isActionButtonEnabled()
        end,
        getActionColor = function()
            return self:getActionButtonColor()
        end,
    })
end

function PlayState:getActionButtonText()
    if GameState.isRolling then
        return "..."
    elseif GameState.selectedHandId then
        return "ANNEHMEN"
    elseif GameState:hasReachedGoal() and GameState.hasRolledThisHand then
        return "CASH OUT"
    elseif GameState:canRoll() then
        return "WÜRFELN"
    else
        return "HAND WAHLEN"
    end
end

function PlayState:isActionButtonEnabled()
    if GameState.isRolling then
        return false
    elseif GameState.selectedHandId then
        return true
    elseif GameState:hasReachedGoal() and GameState.hasRolledThisHand then
        return true
    elseif GameState:canRoll() then
        return true
    else
        return false
    end
end

function PlayState:getActionButtonColor()
    if GameState.isRolling then
        return Theme.colors.surface
    elseif GameState.selectedHandId then
        return Theme.colors.mint
    elseif GameState:hasReachedGoal() and GameState.hasRolledThisHand then
        return Theme.colors.mint
    elseif GameState:canRoll() then
        return Theme.colors.cyan
    else
        return Theme.colors.surface
    end
end

function PlayState:onDiceClick(index)
    if GameState.isRolling then return end
    if not GameState.hasRolledThisHand then return end

    local display = self.diceDisplays[index]
    local die = GameState.dice[index]

    if die.locked then
        -- Unlock: move from tray back to loose area
        GameState:unlockDice(index)
        self.heldTray:freeSlotByDice(index)
        display:returnToLoose()
    else
        -- Lock: find empty slot in tray and move there
        local slotIndex = self.heldTray:getEmptySlot()
        if slotIndex then
            GameState:lockDice(index)
            local bounds = self.heldTray:getSlotBounds(slotIndex)
            self.heldTray:occupySlot(slotIndex, index)
            display:moveToHeldSlot(bounds.x, bounds.y, slotIndex)
        end
    end
end

function PlayState:onHandClick(handId)
    if GameState.isRolling then return end
    if not GameState.hasRolledThisHand then return end
    if GameState:isHandUsed(handId) then return end

    -- Toggle selection
    if GameState.selectedHandId == handId then
        GameState:deselectHand()
        self.infoPanel:updateFormula(nil)
    else
        GameState:selectHand(handId)
        -- Update formula display
        local handDef = Hands:get(handId)
        local breakdown = Scoring.getBreakdown(handId, GameState.dice)
        if breakdown then
            self.infoPanel:updateFormula(
                handDef.name,
                1, -- level (could be upgraded later)
                breakdown.basePoints + breakdown.pips,
                breakdown.mult
            )
        end
    end
end

function PlayState:onActionButtonClick()
    if GameState.isRolling then return end

    -- Check if we should cash out
    if GameState:hasReachedGoal() and GameState.hasRolledThisHand and not GameState.selectedHandId then
        self:cashOut()
        return
    end

    -- Check if a hand is selected - accept it
    if GameState.selectedHandId then
        self:acceptHand()
        return
    end

    -- Roll dice
    if GameState:canRoll() then
        self:rollDice()
    end
end

function PlayState:rollDice()
    if not GameState:canRoll() then return end

    -- Roll immediately so the new values are ready when animation ends
    -- This prevents the glitch where the old value is shown briefly
    if not GameState:rollDice() then return end

    GameState.isRolling = true

    -- Start animations for unlocked dice
    for i, die in ipairs(GameState.dice) do
        if not die.locked then
            self.diceDisplays[i]:startRollAnimation()
        end
    end

    -- Finish rolling state after animation
    -- New animation system takes ~1.2 seconds with stagger and bounces
    self.timer:after(1.5, function()
        GameState.isRolling = false
    end)
end

function PlayState:acceptHand()
    local handId = GameState.selectedHandId
    if not handId then return end

    local score = Scoring.calculateScore(handId, GameState.dice)
    GameState:useHand(handId, score)

    -- Clear formula display
    self.infoPanel:updateFormula(nil)

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

function PlayState:resetForNextHand()
    GameState:resetForHand()
    -- Reset held tray
    self.heldTray:reset()
    -- Reset dice positions to loose area
    for i, display in ipairs(self.diceDisplays) do
        display.isInHeldTray = false
        display.heldSlotIndex = nil
        display:snapTo(self.looseDicePositions[i].x, self.looseDicePositions[i].y)
    end
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

    -- Update hand list
    self.handList:update(dt)

    -- Update info panel
    self.infoPanel:update(dt)

    -- Update formula if hand selected
    if GameState.selectedHandId and GameState.hasRolledThisHand then
        local handDef = Hands:get(GameState.selectedHandId)
        local breakdown = Scoring.getBreakdown(GameState.selectedHandId, GameState.dice)
        if breakdown then
            self.infoPanel:updateFormula(
                handDef.name,
                1,
                breakdown.basePoints + breakdown.pips,
                breakdown.mult
            )
        end
    elseif not GameState.selectedHandId then
        self.infoPanel:updateFormula(nil)
    end
end

function PlayState:draw()
    -- Draw item strip (top center)
    self.itemStrip:draw()

    -- Draw held tray (middle center)
    self.heldTray:draw()

    -- Apply screen shake to dice area
    local shakeX, shakeY = Juice.getShakeOffset()
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- Draw dice (both in tray and loose area)
    -- Draw non-dragging dice first, then dragging dice on top
    for _, display in ipairs(self.diceDisplays) do
        if not display.isDragging then
            display:draw()
        end
    end
    for _, display in ipairs(self.diceDisplays) do
        if display.isDragging then
            display:draw()
        end
    end

    love.graphics.pop()

    -- Draw hand list (left panel)
    self.handList:draw()

    -- Draw info panel (right panel)
    self.infoPanel:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayState:mousemoved(x, y)
    -- Update hand list hover
    self.handList:mousemoved(x, y)

    -- Update dragging dice position
    if self.draggingDice then
        self.draggingDice:updateDrag(x, y)
    end
end

function PlayState:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Check if clicking on a dice (for drag start)
    for i, display in ipairs(self.diceDisplays) do
        if display:containsPoint(x, y) and GameState.hasRolledThisHand and not GameState.isRolling then
            display:startDrag(x, y)
            self.draggingDice = display
            return
        end
    end

    -- Check hand list clicks
    if self.handList:mousepressed(x, y, button) then
        return
    end

    -- Check info panel clicks (action button)
    self.infoPanel:mousepressed(x, y, button)
end

function PlayState:mousereleased(x, y, button)
    if button ~= 1 then return end

    -- Handle dice drag release
    if self.draggingDice then
        local display = self.draggingDice
        local diceIndex = display.index
        local die = GameState.dice[diceIndex]

        -- Check if dropped on held tray (and not already locked)
        local slotIndex = self.heldTray:getSlotAtPoint(x, y)

        if slotIndex and not self.heldTray.slots[slotIndex].occupied and not die.locked then
            -- Lock dice and move to tray
            GameState:lockDice(diceIndex)
            local bounds = self.heldTray:getSlotBounds(slotIndex)
            self.heldTray:occupySlot(slotIndex, diceIndex)
            display:moveToHeldSlot(bounds.x, bounds.y, slotIndex)
        elseif display.isInHeldTray and not self.heldTray:containsPoint(x, y) then
            -- Was in tray, dropped outside - unlock and return to loose
            GameState:unlockDice(diceIndex)
            self.heldTray:freeSlotByDice(diceIndex)
            display:returnToLoose()
        else
            -- Return to current position (either home or tray slot)
            if display.isInHeldTray then
                local bounds = self.heldTray:getSlotBounds(display.heldSlotIndex)
                display:animateTo(bounds.x, bounds.y)
            else
                display:animateTo(display.homeX, display.homeY)
            end
        end

        display:endDrag()
        self.draggingDice = nil
        return
    end

    -- Release hand list
    self.handList:mousereleased(x, y, button)

    -- Release info panel
    self.infoPanel:mousereleased(x, y, button)
end

function PlayState:keypressed(key)
    -- Debug keys
    if key == "space" then
        self:onActionButtonClick()
    elseif key == "1" or key == "2" or key == "3" or key == "4" or key == "5" then
        local index = tonumber(key)
        self:onDiceClick(index)
    end
end

return PlayState
