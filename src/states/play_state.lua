-- Play State - Main gameplay
-- Rolling dice, selecting hands, scoring

local Theme = require("src.ui.theme")
local Timer = require("src.core.timer")
local GameState = require("src.game.game_state")
local Hands = require("src.game.hands")
local Scoring = require("src.game.scoring")
local Levels = require("src.game.levels")

local Panel = require("src.ui.panel")
local Button = require("src.ui.button")
local DiceDisplay = require("src.ui.dice_display")
local HandButton = require("src.ui.hand_button")
local NineSlice = require("src.ui.nine_slice")

local PlayState = {}
PlayState.__index = PlayState

function PlayState.new()
    local self = setmetatable({}, PlayState)

    self.timer = Timer.new()
    self.nineSlice = NineSlice.getInstance()

    -- UI Components
    self.diceDisplays = {}
    self.handButtons = {}
    self.actionButton = nil

    -- Reference to state machine (set in enter)
    self.stateMachine = nil

    return self
end

function PlayState:enter(params)
    self.stateMachine = params.stateMachine

    -- Initialize UI
    self:initDiceDisplays()
    self:initHandButtons()
    self:initActionButton()
end

function PlayState:exit()
    self.timer:clear()
end

function PlayState:initDiceDisplays()
    local layout = Theme.layout
    local diceSize = layout.diceSize
    local spacing = layout.diceSpacing
    local totalWidth = (diceSize * 5) + (spacing * 4)
    local startX = (Theme.screen.width - totalWidth) / 2

    for i = 1, 5 do
        self.diceDisplays[i] = DiceDisplay.new({
            x = startX + (i - 1) * (diceSize + spacing),
            y = layout.diceAreaY + 30,
            size = diceSize,
            index = i,
            getDiceData = function()
                return GameState.dice[i]
            end,
            onClick = function(index)
                self:onDiceClick(index)
            end,
        })
    end
end

function PlayState:initHandButtons()
    local layout = Theme.layout
    local screenPadding = layout.screenPadding
    local buttonWidth = layout.handButtonWidth
    local buttonHeightUpper = layout.handButtonHeightUpper
    local buttonHeightLower = layout.handButtonHeightLower
    local spacing = layout.handButtonSpacing
    local rowSpacing = layout.handRowSpacing

    -- Upper row (6 buttons)
    local upperHands = Hands:getUpper()
    local upperTotalWidth = (buttonWidth * 6) + (spacing * 5)
    local upperStartX = (Theme.screen.width - upperTotalWidth) / 2

    for i, handDef in ipairs(upperHands) do
        self.handButtons[handDef.id] = HandButton.new({
            x = upperStartX + (i - 1) * (buttonWidth + spacing),
            y = layout.handsPanelY,
            width = buttonWidth,
            height = buttonHeightUpper,
            handDef = handDef,
            isUsed = function()
                return GameState:isHandUsed(handDef.id)
            end,
            isSelected = function()
                return GameState.selectedHandId == handDef.id
            end,
            getScore = function()
                return Scoring.calculateScore(handDef.id, GameState.dice)
            end,
            isValidHand = function()
                return Scoring.isValidHand(handDef.id, GameState.dice)
            end,
            hasRolled = function()
                return GameState.hasRolledThisHand
            end,
            onClick = function(id)
                self:onHandClick(id)
            end,
        })
    end

    -- Lower rows (6 buttons in 2 rows of 3)
    local lowerHands = Hands:getLower()
    local lowerTotalWidth = (buttonWidth * 3) + (spacing * 2)
    local lowerStartX = (Theme.screen.width - lowerTotalWidth) / 2
    local lowerY1 = layout.handsPanelY + buttonHeightUpper + rowSpacing
    local lowerY2 = lowerY1 + buttonHeightLower + rowSpacing

    -- First lower row: 3ofKind, 4ofKind, Yahtzee
    local row1Hands = {lowerHands[1], lowerHands[2], lowerHands[3]}
    for i, handDef in ipairs(row1Hands) do
        self.handButtons[handDef.id] = HandButton.new({
            x = lowerStartX + (i - 1) * (buttonWidth + spacing),
            y = lowerY1,
            width = buttonWidth,
            height = buttonHeightLower,
            handDef = handDef,
            isUsed = function()
                return GameState:isHandUsed(handDef.id)
            end,
            isSelected = function()
                return GameState.selectedHandId == handDef.id
            end,
            getScore = function()
                return Scoring.calculateScore(handDef.id, GameState.dice)
            end,
            isValidHand = function()
                return Scoring.isValidHand(handDef.id, GameState.dice)
            end,
            hasRolled = function()
                return GameState.hasRolledThisHand
            end,
            onClick = function(id)
                self:onHandClick(id)
            end,
        })
    end

    -- Second lower row: FullHouse, SmallStraight, LargeStraight
    local row2Hands = {lowerHands[4], lowerHands[5], lowerHands[6]}
    for i, handDef in ipairs(row2Hands) do
        self.handButtons[handDef.id] = HandButton.new({
            x = lowerStartX + (i - 1) * (buttonWidth + spacing),
            y = lowerY2,
            width = buttonWidth,
            height = buttonHeightLower,
            handDef = handDef,
            isUsed = function()
                return GameState:isHandUsed(handDef.id)
            end,
            isSelected = function()
                return GameState.selectedHandId == handDef.id
            end,
            getScore = function()
                return Scoring.calculateScore(handDef.id, GameState.dice)
            end,
            isValidHand = function()
                return Scoring.isValidHand(handDef.id, GameState.dice)
            end,
            hasRolled = function()
                return GameState.hasRolledThisHand
            end,
            onClick = function(id)
                self:onHandClick(id)
            end,
        })
    end
end

function PlayState:initActionButton()
    local layout = Theme.layout

    self.actionButton = Button.new({
        x = (Theme.screen.width - layout.actionButtonWidth) / 2,
        y = layout.actionButtonY,
        width = layout.actionButtonWidth,
        height = layout.actionButtonHeight,
        text = "WURFELN",
        bgColor = Theme.colors.cyan,
        textColor = Theme.colors.textDark,
        hoverBgColor = Theme.colors.cyan,
        onClick = function()
            self:onActionButtonClick()
        end,
    })
end

function PlayState:onDiceClick(index)
    if GameState.isRolling then return end
    if not GameState.hasRolledThisHand then return end

    GameState:toggleLock(index)
end

function PlayState:onHandClick(handId)
    if GameState.isRolling then return end
    if not GameState.hasRolledThisHand then return end
    if GameState:isHandUsed(handId) then return end

    -- Toggle selection
    if GameState.selectedHandId == handId then
        GameState:deselectHand()
    else
        GameState:selectHand(handId)
    end
end

function PlayState:onActionButtonClick()
    if GameState.isRolling then return end

    -- Check if we should cash out
    if GameState:hasReachedGoal() and GameState.hasRolledThisHand and not GameState.selectedHandId then
        -- Cash out
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

    GameState.isRolling = true

    -- Start animations for unlocked dice
    local maxDuration = 0
    for i, die in ipairs(GameState.dice) do
        if not die.locked then
            local duration = 0.3 + (i - 1) * 0.08
            self.diceDisplays[i]:startRollAnimation(duration)
            maxDuration = math.max(maxDuration, duration)
        end
    end

    -- Actually roll after animation
    -- NOTE: Must set isRolling = false BEFORE calling GameState:rollDice()
    -- because rollDice() checks canRoll() which requires isRolling = false
    self.timer:after(maxDuration + 0.1, function()
        GameState.isRolling = false
        GameState:rollDice()
    end)
end

function PlayState:acceptHand()
    local handId = GameState.selectedHandId
    if not handId then return end

    local score = Scoring.calculateScore(handId, GameState.dice)
    GameState:useHand(handId, score)

    -- Check end conditions
    if GameState:hasLostLevel() then
        -- Lost - go to result with loss
        self.stateMachine:change("result", {
            won = false,
            stateMachine = self.stateMachine,
        })
    elseif GameState:allHandsUsed() then
        -- All hands used - check if won
        if GameState:hasReachedGoal() then
            self:cashOut()
        else
            self.stateMachine:change("result", {
                won = false,
                stateMachine = self.stateMachine,
            })
        end
    else
        -- Continue playing - reset for next hand
        GameState:resetForHand()
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

    -- Update dice displays
    for _, display in ipairs(self.diceDisplays) do
        display:update(dt)
    end

    -- Update hand buttons
    for _, button in pairs(self.handButtons) do
        button:update(dt)
    end

    -- Update action button state and text
    self:updateActionButton()
    self.actionButton:update(dt)
end

function PlayState:updateActionButton()
    local hasSelection = GameState.selectedHandId ~= nil
    local canRoll = GameState:canRoll() and not GameState.isRolling
    local goalReached = GameState:hasReachedGoal()

    if GameState.isRolling then
        self.actionButton:setText("...")
        self.actionButton:setEnabled(false)
        self.actionButton.bgColor = Theme.colors.surface
    elseif hasSelection then
        self.actionButton:setText("ANNEHMEN")
        self.actionButton:setEnabled(true)
        self.actionButton.bgColor = Theme.colors.mint
    elseif goalReached and GameState.hasRolledThisHand then
        self.actionButton:setText("CASH OUT")
        self.actionButton:setEnabled(true)
        self.actionButton.bgColor = Theme.colors.mint
    elseif canRoll then
        self.actionButton:setText("WURFELN")
        self.actionButton:setEnabled(true)
        self.actionButton.bgColor = Theme.colors.cyan
    else
        -- No rolls left, must select hand
        self.actionButton:setText("HAND WAHLEN")
        self.actionButton:setEnabled(false)
        self.actionButton.bgColor = Theme.colors.surface
    end
end

function PlayState:draw()
    -- Draw top bar
    self:drawTopBar()

    -- Draw dice area
    self:drawDiceArea()

    -- Draw hand buttons
    self:drawHandButtons()

    -- Draw action button
    self.actionButton:draw()
end

function PlayState:drawTopBar()
    local layout = Theme.layout
    local padding = layout.screenPadding
    local panelWidth = Theme.screen.width - padding * 2

    -- Main panel background
    self.nineSlice:draw(padding, layout.topBarY, panelWidth, layout.topBarHeight, Theme.colors.surface)

    -- Left side info
    local leftX = padding + 12
    local topY = layout.topBarY + 10

    -- Level
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("LEVEL", leftX, topY)

    love.graphics.setFont(Theme.fonts.huge)
    love.graphics.setColor(Theme.colors.text)
    love.graphics.print(tostring(GameState.currentLevel), leftX, topY + 14)

    -- Hands remaining
    local handsX = leftX + 70
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("HANDE", handsX, topY)

    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.mint)
    love.graphics.print(tostring(GameState.handsRemaining), handsX, topY + 16)

    -- Rolls remaining
    local rollsX = handsX + 60
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("WURFE", rollsX, topY)

    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.cyan)
    love.graphics.print(tostring(GameState.rollsRemaining), rollsX, topY + 16)

    -- Money (top right of left section)
    local moneyX = leftX + 150
    love.graphics.setColor(Theme.colors.gold)
    if Theme.images.coin then
        -- Coin is 512x512, scale to 16px
        local coinScale = 16 / 512
        love.graphics.draw(Theme.images.coin, moneyX, topY + 2, 0, coinScale, coinScale)
        love.graphics.setFont(Theme.fonts.normal)
        love.graphics.print(tostring(GameState.money), moneyX + 20, topY + 2)
    else
        love.graphics.setFont(Theme.fonts.normal)
        love.graphics.print("$" .. tostring(GameState.money), moneyX, topY + 2)
    end

    -- Right side - Goal and Score
    local rightX = Theme.screen.width - padding - 110

    -- Goal panel
    self.nineSlice:draw(rightX, layout.topBarY + 8, 100, 40, Theme.colors.surface2)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("ZIEL", rightX + 10, layout.topBarY + 12)

    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.coral)
    local goalText = tostring(GameState:getCurrentGoal())
    local goalWidth = Theme.fonts.large:getWidth(goalText)
    love.graphics.print(goalText, rightX + 90 - goalWidth, layout.topBarY + 22)

    -- Score panel
    self.nineSlice:draw(rightX, layout.topBarY + 52, 100, 40, Theme.colors.surface2)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("PUNKTE", rightX + 10, layout.topBarY + 56)

    love.graphics.setFont(Theme.fonts.large)
    local scoreColor = GameState:hasReachedGoal() and Theme.colors.mint or Theme.colors.text
    love.graphics.setColor(scoreColor)
    local scoreText = tostring(GameState.currentScore)
    local scoreWidth = Theme.fonts.large:getWidth(scoreText)
    love.graphics.print(scoreText, rightX + 90 - scoreWidth, layout.topBarY + 66)

    -- Selected hand preview (middle bottom of top bar)
    if GameState.selectedHandId then
        local handDef = Hands:get(GameState.selectedHandId)
        local breakdown = Scoring.getBreakdown(GameState.selectedHandId, GameState.dice)

        local previewX = padding + 12
        local previewY = layout.topBarY + 58

        love.graphics.setFont(Theme.fonts.small)
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.print(handDef.name, previewX, previewY)

        -- Score breakdown: (base + pips) x mult
        local baseText = tostring(breakdown.basePoints + breakdown.pips)
        local multText = tostring(breakdown.mult)

        love.graphics.setFont(Theme.fonts.normal)
        love.graphics.setColor(Theme.colors.cyan)
        love.graphics.print(baseText, previewX, previewY + 16)

        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.print(" x ", previewX + Theme.fonts.normal:getWidth(baseText), previewY + 16)

        love.graphics.setColor(Theme.colors.coral)
        love.graphics.print(multText, previewX + Theme.fonts.normal:getWidth(baseText .. " x "), previewY + 16)

        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.print(" = ", previewX + Theme.fonts.normal:getWidth(baseText .. " x " .. multText), previewY + 16)

        love.graphics.setColor(Theme.colors.gold)
        love.graphics.print(tostring(breakdown.total), previewX + Theme.fonts.normal:getWidth(baseText .. " x " .. multText .. " = "), previewY + 16)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayState:drawDiceArea()
    local layout = Theme.layout

    -- Draw label
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    local labelText = "KLICKE UM ZU SPERREN"
    if not GameState.hasRolledThisHand then
        labelText = "WURFLE ZUERST"
    end
    local labelWidth = Theme.fonts.small:getWidth(labelText)
    love.graphics.print(labelText, (Theme.screen.width - labelWidth) / 2, layout.diceAreaY + 8)

    -- Draw dice
    for _, display in ipairs(self.diceDisplays) do
        display:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayState:drawHandButtons()
    for _, button in pairs(self.handButtons) do
        button:draw()
    end
end

function PlayState:mousepressed(x, y, button)
    -- Check dice clicks
    for _, display in ipairs(self.diceDisplays) do
        if display:mousepressed(x, y, button) then
            return
        end
    end

    -- Check hand button clicks
    for _, handButton in pairs(self.handButtons) do
        if handButton:mousepressed(x, y, button) then
            return
        end
    end

    -- Check action button
    self.actionButton:mousepressed(x, y, button)
end

function PlayState:mousereleased(x, y, button)
    -- Release hand buttons
    for _, handButton in pairs(self.handButtons) do
        handButton:mousereleased(x, y, button)
    end

    -- Release action button
    self.actionButton:mousereleased(x, y, button)
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
