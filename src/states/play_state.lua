-- Play State - Main gameplay
-- Left: Info panel | Center: Item strip + Dice + Hand Cards + CTAs

local Theme = require("src.ui.theme")
local Timer = require("src.core.timer")
local GameState = require("src.game.game_state")
local Hands = require("src.game.hands")
local Scoring = require("src.game.scoring")
local Levels = require("src.game.levels")

local NineSlice = require("src.ui.nine_slice")
local DiceDisplay = require("src.ui.dice_display")
local ItemStrip = require("src.ui.item_strip")
local HandCardArea = require("src.ui.hand_card_area")
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
    self.handCardArea = nil
    self.infoPanel = nil
    self.dualCta = nil

    -- Dice home positions (center area)
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
    self:initHandCardArea()
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

function PlayState:initHandCardArea()
    local layout = Theme.layout

    self.handCardArea = HandCardArea.new({
        x = layout.centerX,
        y = layout.handCardAreaY,
        width = layout.centerWidth,
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

-- Get the currently selected hand from the hand card area
function PlayState:getDetectedHand()
    local selectedHand = self.handCardArea:getSelectedHand()
    if selectedHand then
        return {
            id = selectedHand.id,
            name = selectedHand.name,
            level = selectedHand.level or 1,
        }
    end
    return nil
end

-- Update hand cards based on current dice selection
function PlayState:updateHandCards()
    local indices = GameState:getSelectedDiceIndices()
    if #indices == 0 then
        self.handCardArea:setHands(nil, nil)
        return
    end

    -- Detect both hand types
    local zahlenId = Scoring.detectZahlenHand(indices, GameState.dice)
    local kombiId = Scoring.detectBestKombinationFromIndices(indices, GameState.dice)

    local zahlenHand = nil
    if zahlenId and not GameState:isHandUsed(zahlenId) then
        local def = Hands:get(zahlenId)
        zahlenHand = {
            id = zahlenId,
            name = def.name,
            level = def.level or 1,
            scoringDice = Scoring.getScoringDiceForHand(zahlenId, indices, GameState.dice)
        }
    end

    local kombiHand = nil
    if kombiId and not GameState:isHandUsed(kombiId) then
        local def = Hands:get(kombiId)
        kombiHand = {
            id = kombiId,
            name = def.name,
            level = def.level or 1,
            scoringDice = Scoring.getScoringDiceForHand(kombiId, indices, GameState.dice)
        }
    end

    self.handCardArea:setHands(zahlenHand, kombiHand)
end

function PlayState:canPlayHand()
    if GameState.isRolling then return false end
    if not GameState.hasRolledThisHand then return false end

    -- Check if a hand card is selected
    local selectedHand = self.handCardArea:getSelectedHand()
    if not selectedHand then return false end

    -- Check if the hand is already used
    if GameState:isHandUsed(selectedHand.id) then return false end

    return true
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

    -- Update hand cards to reflect new selection
    self:updateHandCards()
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

    -- Explicitly clear displayed hand cards
    self.handCardArea:setHands(nil, nil)

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

    -- Update hand card area
    self.handCardArea:update(dt)

    -- Update info panel
    self.infoPanel:update(dt)

    -- Update dual CTA buttons
    self.dualCta:update(dt)

    -- Update dice positions based on selection state
    self:updateDicePositions()
end

function PlayState:updateDicePositions()
    -- Selected dice move up, unselected stay at home
    for i, display in ipairs(self.diceDisplays) do
        local homePos = self.diceHomePositions[i]
        local homeX, homeY = homePos.x, homePos.y

        if GameState:isDiceSelected(i) then
            -- Selected dice move up
            local selectedY = homeY + Theme.layout.diceSelectedOffsetY
            if not display.isDragging then
                display:animateTo(homeX, selectedY)
            end
        else
            -- Unselected dice stay at home
            if not display.isDragging then
                display:animateTo(homeX, homeY)
            end
        end
    end
end

function PlayState:draw()
    -- Draw item strip (top center)
    self.itemStrip:draw()

    -- Draw hand card area (between dice and CTAs)
    self.handCardArea:draw()

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

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayState:mousemoved(x, y)
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

    -- Check hand card area clicks
    if button == 1 then
        if self.handCardArea:mousepressed(x, y, button) then
            return
        end
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
        local homePos = self.diceHomePositions[index]

        -- Stop dragging/holding
        local currentY = display:endDrag()

        -- Check if it was a simple click (moved less than threshold)
        local dragDist = math.sqrt((x - self.dragStartX) ^ 2 + (y - self.dragStartY) ^ 2)
        local clickThreshold = 6

        if dragDist < clickThreshold then
            -- Simple click: toggle selection
            GameState:toggleDiceSelection(index)
            self:updateHandCards()
        else
            -- Drag release: determine selection based on Y position
            local homeY = homePos.y
            local selectedY = homeY + Theme.layout.diceSelectedOffsetY
            local midpointY = (homeY + selectedY) / 2

            -- Determine if should be selected based on Y position (up is smaller Y)
            local shouldBeSelected = currentY < midpointY
            local isCurrentlySelected = GameState:isDiceSelected(index)

            -- Change state if dropped in different zone
            if shouldBeSelected ~= isCurrentlySelected then
                GameState:toggleDiceSelection(index)
                self:updateHandCards()
            end
        end

        -- Clear drag state
        self.draggingDice = nil
        self.draggingDiceIndex = nil
        self.dragStartX = nil
        self.dragStartY = nil
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
    elseif key == "left" or key == "right" then
        -- Arrow keys navigate hand cards
        self.handCardArea:keypressed(key)
    elseif key == "1" or key == "2" or key == "3" or key == "4" or key == "5" then
        local index = tonumber(key)
        self:onDiceClick(index)
    end
end

return PlayState
