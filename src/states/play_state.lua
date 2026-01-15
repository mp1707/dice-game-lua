-- Play State - Main gameplay with Balatro-style 3-column layout
-- Left: Info panel | Center: Dice + Action | Right: Hand selection

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

    -- Center dice in the center column
    local centerX = layout.centerX + (layout.centerWidth - totalWidth) / 2

    for i = 1, 5 do
        self.diceDisplays[i] = DiceDisplay.new({
            x = centerX + (i - 1) * (diceSize + spacing),
            y = layout.diceAreaY,
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
    local panelX = layout.rightPanelX
    local panelY = layout.rightPanelY
    local buttonWidth = layout.handButtonWidth
    local buttonHeight = layout.handButtonHeight
    local spacing = layout.handButtonSpacing
    local rowSpacing = layout.handRowSpacing
    local padding = layout.handPanelPadding

    -- All 12 hands in 2-column layout
    local allHands = Hands.definitions
    local startX = panelX + padding
    local startY = panelY + 50  -- Space for title

    for i, handDef in ipairs(allHands) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)

        local x = startX + col * (buttonWidth + spacing)
        local y = startY + row * (buttonHeight + rowSpacing)

        self.handButtons[handDef.id] = HandButton.new({
            x = x,
            y = y,
            width = buttonWidth,
            height = buttonHeight,
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

    -- Center the action button in the center column
    local buttonX = layout.centerX + (layout.centerWidth - layout.actionButtonWidth) / 2

    self.actionButton = Button.new({
        x = buttonX,
        y = layout.actionButtonY,
        width = layout.actionButtonWidth,
        height = layout.actionButtonHeight,
        text = "WÜRFELN",
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
        self.stateMachine:change("result", {
            won = false,
            stateMachine = self.stateMachine,
        })
    elseif GameState:allHandsUsed() then
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
        self.actionButton:setText("WÜRFELN")
        self.actionButton:setEnabled(true)
        self.actionButton.bgColor = Theme.colors.cyan
    else
        -- No rolls left, must select hand
        self.actionButton:setText("HAND WÄHLEN")
        self.actionButton:setEnabled(false)
        self.actionButton.bgColor = Theme.colors.surface
    end
end

function PlayState:draw()
    -- Draw left panel (info/stats)
    self:drawLeftPanel()

    -- Draw center area (dice + action)
    self:drawCenterArea()

    -- Draw right panel (hand selection)
    self:drawRightPanel()
end

function PlayState:drawLeftPanel()
    local layout = Theme.layout
    local x = layout.leftPanelX
    local y = layout.leftPanelY
    local w = layout.leftPanelWidth
    local h = layout.leftPanelHeight

    -- Panel background
    self.nineSlice:draw(x, y, w, h, Theme.colors.surface)

    local contentX = x + 20
    local contentY = y + 20

    -- Level section
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("LEVEL", contentX, contentY)

    love.graphics.setFont(Theme.fonts.display)
    love.graphics.setColor(Theme.colors.text)
    love.graphics.print(tostring(GameState.currentLevel), contentX, contentY + 16)

    -- Divider
    contentY = contentY + 80
    love.graphics.setColor(Theme.colors.border)
    love.graphics.rectangle("fill", contentX, contentY, w - 40, 2)
    contentY = contentY + 20

    -- Goal panel
    self.nineSlice:draw(contentX - 4, contentY, w - 32, 70, Theme.colors.surface2)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("ZIEL", contentX + 8, contentY + 8)

    love.graphics.setFont(Theme.fonts.huge)
    love.graphics.setColor(Theme.colors.coral)
    local goalText = tostring(GameState:getCurrentGoal())
    love.graphics.print(goalText, contentX + 8, contentY + 28)

    contentY = contentY + 85

    -- Score panel
    self.nineSlice:draw(contentX - 4, contentY, w - 32, 70, Theme.colors.surface2)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("PUNKTE", contentX + 8, contentY + 8)

    love.graphics.setFont(Theme.fonts.huge)
    local scoreColor = GameState:hasReachedGoal() and Theme.colors.mint or Theme.colors.text
    love.graphics.setColor(scoreColor)
    love.graphics.print(tostring(GameState.currentScore), contentX + 8, contentY + 28)

    contentY = contentY + 85

    -- Divider
    love.graphics.setColor(Theme.colors.border)
    love.graphics.rectangle("fill", contentX, contentY, w - 40, 2)
    contentY = contentY + 20

    -- Hands remaining
    self.nineSlice:draw(contentX - 4, contentY, w - 32, 55, Theme.colors.surface2)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("HÄNDE", contentX + 8, contentY + 8)
    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.mint)
    love.graphics.print(tostring(GameState.handsRemaining), contentX + 8, contentY + 26)

    contentY = contentY + 65

    -- Rolls remaining
    self.nineSlice:draw(contentX - 4, contentY, w - 32, 55, Theme.colors.surface2)
    love.graphics.setFont(Theme.fonts.small)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("WÜRFE", contentX + 8, contentY + 8)
    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.cyan)
    love.graphics.print(tostring(GameState.rollsRemaining), contentX + 8, contentY + 26)

    contentY = contentY + 75

    -- Divider
    love.graphics.setColor(Theme.colors.border)
    love.graphics.rectangle("fill", contentX, contentY, w - 40, 2)
    contentY = contentY + 20

    -- Money
    love.graphics.setColor(Theme.colors.gold)
    if Theme.images.coin then
        local coinScale = 24 / 512
        love.graphics.draw(Theme.images.coin, contentX, contentY, 0, coinScale, coinScale)
        love.graphics.setFont(Theme.fonts.large)
        love.graphics.print(tostring(GameState.money), contentX + 32, contentY + 2)
    else
        love.graphics.setFont(Theme.fonts.large)
        love.graphics.print("$" .. tostring(GameState.money), contentX, contentY)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayState:drawCenterArea()
    local layout = Theme.layout

    -- Title bar
    local titleX = layout.centerX
    local titleY = layout.topBarY
    local titleW = layout.centerWidth
    local titleH = layout.topBarHeight

    self.nineSlice:draw(titleX, titleY, titleW, titleH, Theme.colors.surface)

    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.text)
    local title = "DICE GAME - Level " .. tostring(GameState.currentLevel)
    local titleWidth = Theme.fonts.large:getWidth(title)
    love.graphics.print(title, titleX + (titleW - titleWidth) / 2, titleY + 18)

    -- Draw label above dice
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.textMuted)
    local labelText = "KLICKE UM ZU SPERREN"
    if not GameState.hasRolledThisHand then
        labelText = "WÜRFLE ZUERST"
    end
    local labelWidth = Theme.fonts.normal:getWidth(labelText)
    love.graphics.print(labelText, layout.centerX + (layout.centerWidth - labelWidth) / 2, layout.diceAreaY - 30)

    -- Draw dice
    for _, display in ipairs(self.diceDisplays) do
        display:draw()
    end

    -- Draw action button
    self.actionButton:draw()

    -- Draw selected hand preview (below action button)
    if GameState.selectedHandId then
        self:drawScorePreview()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayState:drawScorePreview()
    local layout = Theme.layout
    local handDef = Hands:get(GameState.selectedHandId)
    local breakdown = Scoring.getBreakdown(GameState.selectedHandId, GameState.dice)

    local previewX = layout.centerX + (layout.centerWidth - layout.previewWidth) / 2
    local previewY = layout.previewY
    local previewW = layout.previewWidth
    local previewH = layout.previewHeight

    self.nineSlice:draw(previewX, previewY, previewW, previewH, Theme.colors.surface2)

    -- Hand name
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print(handDef.name, previewX + 16, previewY + 12)

    -- Score formula: (base + pips) x mult = total
    local baseText = tostring(breakdown.basePoints + breakdown.pips)
    local multText = tostring(breakdown.mult)
    local totalText = tostring(breakdown.total)

    local formulaY = previewY + 40

    love.graphics.setFont(Theme.fonts.huge)

    -- Base (cyan)
    love.graphics.setColor(Theme.colors.cyan)
    love.graphics.print(baseText, previewX + 16, formulaY)
    local baseWidth = Theme.fonts.huge:getWidth(baseText)

    -- × (muted)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print(" × ", previewX + 16 + baseWidth, formulaY)
    local xWidth = Theme.fonts.huge:getWidth(" × ")

    -- Mult (coral)
    love.graphics.setColor(Theme.colors.coral)
    love.graphics.print(multText, previewX + 16 + baseWidth + xWidth, formulaY)
    local multWidth = Theme.fonts.huge:getWidth(multText)

    -- = (muted)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print(" = ", previewX + 16 + baseWidth + xWidth + multWidth, formulaY)
    local eqWidth = Theme.fonts.huge:getWidth(" = ")

    -- Total (gold)
    love.graphics.setColor(Theme.colors.gold)
    love.graphics.print(totalText, previewX + 16 + baseWidth + xWidth + multWidth + eqWidth, formulaY)
end

function PlayState:drawRightPanel()
    local layout = Theme.layout
    local x = layout.rightPanelX
    local y = layout.rightPanelY
    local w = layout.rightPanelWidth
    local h = layout.rightPanelHeight

    -- Panel background
    self.nineSlice:draw(x, y, w, h, Theme.colors.surface)

    -- Title
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("HAND AUSWAHL", x + layout.handPanelPadding, y + 16)

    -- Draw hand buttons
    for _, button in pairs(self.handButtons) do
        button:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
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
