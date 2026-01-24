-- Play State - Main gameplay
-- Left: Info panel | Center: Item strip + Dice + CTAs

local Theme = require("src.ui.theme")
local Timer = require("src.core.timer")
local GameState = require("src.game.game_state")
local Scoring = require("src.game.scoring")
local Sound = require("src.core.sound")

local NineSlice = require("src.ui.nine_slice")
local ItemStrip = require("src.ui.item_strip")
local InfoPanel = require("src.ui.info_panel")
local DualCta = require("src.ui.dual_cta")
local Juice = require("src.ui.juice")
local ScoreAnimation = require("src.ui.score_animation")
local DiceContainer = require("src.ui.dice_container")
local HandsModal = require("src.ui.hands_modal")
local SettingsModal = require("src.ui.settings_modal")

local PlayState = {}
PlayState.__index = PlayState

function PlayState.new()
    local self = setmetatable({}, PlayState)

    self.timer = Timer.new()
    self.nineSlice = NineSlice.getInstance()

    -- UI Components
    self.itemStrip = nil
    self.infoPanel = nil
    self.dualCta = nil
    self.diceContainer = nil
    self.handsModal = nil
    self.settingsModal = nil

    -- Reference to state machine (set in enter)
    self.stateMachine = nil

    -- Round counter (mock for now)
    self.currentRound = 1

    return self
end

function PlayState:enter(params)
    self.stateMachine = params.stateMachine

    -- Initialize UI components
    self:initDiceContainer()
    self:initItemStrip()
    self:initHandsModal()
    self:initSettingsModal()
    self:initInfoPanel()
    self:initDualCta()
end

function PlayState:initHandsModal()
    self.handsModal = HandsModal.new({
        onClose = function()
            -- Modal closed
        end,
    })
end

function PlayState:initSettingsModal()
    self.settingsModal = SettingsModal.new({
        onClose = function()
            -- Modal closed
        end,
    })
end

function PlayState:exit()
    self.timer:clear()
end

function PlayState:initDiceContainer()
    self.diceContainer = DiceContainer.new(
        {
            getDiceData = function(index)
                return GameState.dice[index]
            end,
            onDiceClick = function(index, suppressSound)
                self:onDiceClick(index, suppressSound)
            end,
            isRolling = function()
                return GameState.isRolling
            end,
        }
    )
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
        onInfoClick = function()
            self.handsModal:open()
        end,
        onSettingsClick = function()
            self.settingsModal:open()
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
    return hand
end

function PlayState:canPlayHand()
    if GameState.isRolling then return false end
    if not GameState.hasRolledThisHand then return false end

    -- Block during score animation
    local scoreAnim = ScoreAnimation.getInstance()
    if scoreAnim:isAnimating() then return false end

    -- Check if a valid hand is detected
    local detected = self:getDetectedHand()
    return detected ~= nil
end

function PlayState:canRoll()
    if GameState.isRolling then return false end
    if not GameState:canRoll() then return false end

    -- Block during score animation
    local scoreAnim = ScoreAnimation.getInstance()
    if scoreAnim:isAnimating() then return false end

    -- Can roll if we have rolls remaining
    return true
end

-- Handle unified click on dice (toggle selection)
function PlayState:onDiceClick(index, suppressSound)
    if GameState.isRolling then return end
    if not GameState.hasRolledThisHand then return end

    -- Block during score animation
    local scoreAnim = ScoreAnimation.getInstance()
    if scoreAnim:isAnimating() then return end

    -- Toggle the dice selection
    GameState:toggleDiceSelection(index, suppressSound)
end

function PlayState:onPlayHandClick()
    if not self:canPlayHand() then return end

    local scoreAnim = ScoreAnimation.getInstance()
    if scoreAnim:isAnimating() then return end

    local detected = self:getDetectedHand()
    if not detected then return end

    local breakdown = Scoring.getBreakdown(detected.id, GameState.dice)
    local oldScore = GameState.currentScore

    -- Get scoring dice indices in visual order
    local scoringIndices = self:getScoringDiceIndicesInVisualOrder(detected.id)

    -- Start the counting animation
    scoreAnim:start({
        handId = detected.id,
        breakdown = breakdown,
        oldScore = oldScore,
        scoringDiceIndices = scoringIndices,
        diceDisplays = self.diceContainer.diceDisplays,
        diceVisualOrder = self.diceContainer.diceVisualOrder,
        infoPanel = self.infoPanel,
        onComplete = function()
            -- Update game state after animation completes
            GameState:useHand(detected.id, breakdown.total)
            self:handlePostScoreTransition()
        end,
    })
end

-- Get scoring dice indices sorted by visual order (left to right)
function PlayState:getScoringDiceIndicesInVisualOrder(handId)
    local scoringIndices = {}

    if Scoring.isUpperSectionHand(handId) then
        -- Upper section hands: only dice matching the target face (from selected dice)
        local selectedIndices = GameState:getSelectedDiceIndices()
        local targetFace = Scoring.getFaceFromHandId(handId)

        -- Collect indices to deselect (those that don't match target face)
        local toDeselect = {}
        for _, idx in ipairs(selectedIndices) do
            if GameState.dice[idx].value == targetFace then
                table.insert(scoringIndices, idx)
            else
                table.insert(toDeselect, idx)
            end
        end

        -- Deselect the non-matching dice
        for _, idx in ipairs(toDeselect) do
            GameState:toggleDiceSelection(idx)
        end
    else
        -- Lower section hands (x of a kind, straights, full house): ALL 5 dice
        -- The score formula uses sumAll(dice), so all dice contribute
        for i = 1, 5 do
            table.insert(scoringIndices, i)
            -- Also ensure all dice are selected for the animation
            if not GameState:isDiceSelected(i) then
                GameState:toggleDiceSelection(i)
            end
        end
    end

    -- Sort by visual order (position in diceVisualOrder)
    table.sort(scoringIndices, function(a, b)
        local slotA, slotB = 0, 0
        for slot, dieIndex in ipairs(self.diceContainer.diceVisualOrder) do
            if dieIndex == a then slotA = slot end
            if dieIndex == b then slotB = slot end
        end
        return slotA < slotB
    end)

    return scoringIndices
end

-- Handle transition after score animation completes
function PlayState:handlePostScoreTransition()
    -- Check end conditions
    if GameState:hasLostLevel() then
        self.stateMachine:change("result", {
            won = false,
            stateMachine = self.stateMachine,
        })
    elseif GameState:hasReachedGoal() then
        -- Goal reached! Cash out
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

    -- Sound is now played per-die on impact (in dice_display.lua onBounce callback)

    -- Start animations in container
    self.diceContainer:startRollAnimation(selectedIndices, isFirstRoll)

    -- Finish rolling state after animation (shortened to match faster physics)
    self.timer:after(0.8, function()
        GameState.isRolling = false
    end)
end

function PlayState:resetForNextHand()
    -- Clear selections and reset game state
    GameState:resetForHand()

    -- Reset dice container
    self.diceContainer:reset()

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

    -- Update score animation
    local scoreAnim = ScoreAnimation.getInstance()
    scoreAnim:update(dt)

    -- Update dice container
    self.diceContainer:update(dt)

    -- Update info panel
    self.infoPanel:update(dt)

    -- Update dual CTA buttons
    self.dualCta:update(dt)

    -- Update hands modal
    self.handsModal:update(dt)

    -- Update settings modal
    self.settingsModal:update(dt)
end

function PlayState:draw()
    -- Draw item strip (top center)
    self.itemStrip:draw()

    -- Draw info panel (left panel)
    self.infoPanel:draw()

    -- Draw dual CTA buttons (bottom center)
    self.dualCta:draw()

    local showDice = GameState.hasRolledThisHand or GameState.isRolling

    if showDice then
        self.diceContainer:draw()
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

    -- Draw score animation pop texts (on top of dice)
    local scoreAnim = ScoreAnimation.getInstance()
    scoreAnim:draw()

    -- Draw hands modal (on top of everything)
    self.handsModal:draw()

    -- Draw settings modal (on top of everything)
    self.settingsModal:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayState:mousemoved(x, y)
    self.diceContainer:mousemoved(x, y)
end

function PlayState:mousepressed(x, y, button)
    -- Check settings modal first when open
    if self.settingsModal.isOpen then
        if self.settingsModal:mousepressed(x, y, button) then
            return true
        end
    end

    -- Check hands modal when open
    if self.handsModal.isOpen then
        if self.handsModal:mousepressed(x, y, button) then
            return true
        end
    end

    -- Check info panel clicks (settings/info buttons)
    if self.infoPanel:mousepressed(x, y, button) then
        return true
    end

    -- Check dual CTA clicks
    if self.dualCta:mousepressed(x, y, button) then
        return true
    end

    -- Forward to dice container
    if self.diceContainer:mousepressed(x, y, button) then
        print("PlayState handled by DiceContainer")
        return true
    end
end

function PlayState:mousereleased(x, y, button)
    -- Release settings modal
    if self.settingsModal:mousereleased(x, y, button) then
        return
    end

    -- Release hands modal
    if self.handsModal:mousereleased(x, y, button) then
        return
    end

    -- Release dual CTA
    self.dualCta:mousereleased(x, y, button)

    -- Release info panel
    self.infoPanel:mousereleased(x, y, button)

    -- Release dice container
    self.diceContainer:mousereleased(x, y, button)
end

function PlayState:keypressed(key)
    -- Check settings modal first
    if self.settingsModal:keypressed(key) then
        return
    end

    -- Check hands modal
    if self.handsModal:keypressed(key) then
        return
    end

    -- Check if score animation is running - Space/Enter can skip it
    local scoreAnim = ScoreAnimation.getInstance()
    if scoreAnim:isAnimating() then
        if key == "space" or key == "return" then
            scoreAnim:skip()
        end
        return
    end

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

return PlayState
