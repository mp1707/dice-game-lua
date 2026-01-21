-- Result State - Level complete/failed screen (Landscape layout)
-- Shows rewards and transitions to shop or game over

local Theme = require("src.ui.theme")
local GameState = require("src.game.game_state")
local Levels = require("src.game.levels")
local Button = require("src.ui.button")
local NineSlice = require("src.ui.nine_slice")

local ResultState = {}
ResultState.__index = ResultState

function ResultState.new()
    local self = setmetatable({}, ResultState)

    self.nineSlice = NineSlice.getInstance()
    self.actionButton = nil
    self.stateMachine = nil

    -- Result data
    self.won = false
    self.reward = 0
    self.baseReward = 0
    self.unusedHandsBonus = 0

    return self
end

function ResultState:enter(params)
    self.stateMachine = params.stateMachine
    self.won = params.won

    if self.won then
        -- Calculate rewards
        self.baseReward = Levels.baseReward
        self.unusedHandsBonus = GameState.handsRemaining * Levels.bonusPerUnusedHand
        self.reward = self.baseReward + self.unusedHandsBonus

        -- Add money
        GameState:addMoney(self.reward)
    end

    self:initActionButton()
end

function ResultState:exit()
end

function ResultState:initActionButton()
    local buttonWidth = 300
    local buttonHeight = 60

    local buttonText, buttonColor
    if self.won then
        buttonText = "SHOP"
        buttonColor = Theme.colors.mint
    else
        buttonText = "NEUER RUN"
        buttonColor = Theme.colors.coral
    end

    self.actionButton = Button.new({
        x = (Theme.screen.width - buttonWidth) / 2,
        y = Theme.screen.height - 100,
        width = buttonWidth,
        height = buttonHeight,
        text = buttonText,
        bgColor = buttonColor,
        textColor = Theme.colors.textDark,
        hoverBgColor = buttonColor,
        onClick = function()
            self:onActionButtonClick()
        end,
    })
end

function ResultState:onActionButtonClick()
    if self.won then
        -- Go to shop
        self.stateMachine:change("shop", {
            stateMachine = self.stateMachine,
        })
    else
        -- Start new run
        GameState:reset()
        self.stateMachine:change("play", {
            stateMachine = self.stateMachine,
        })
    end
end

function ResultState:update(dt)
    self.actionButton:update(dt)
end

function ResultState:draw()
    local screenWidth = Theme.screen.width
    local screenHeight = Theme.screen.height

    -- Center content panel
    local panelWidth = 500
    local panelHeight = 400
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = 80

    self.nineSlice:draw(panelX, panelY, panelWidth, panelHeight, Theme.colors.surface, Theme.nineSlice.borderScale)

    -- Title
    local titleText = self.won and "LEVEL GESCHAFFT!" or "VERLOREN!"
    local titleColor = self.won and Theme.colors.mint or Theme.colors.coral
    Theme:drawTextCenteredWithShadow(titleText, 0, panelY + 30, screenWidth, Theme.fonts.display, titleColor)

    -- Level and score summary
    local levelText = "Level " .. tostring(GameState.currentLevel)
    Theme:drawTextCenteredWithShadow(levelText, 0, panelY + 90, screenWidth, Theme.fonts.large, Theme.colors.text)

    local scoreText = tostring(GameState.currentScore) .. " / " .. tostring(GameState:getCurrentGoal())
    local scoreColor = GameState:hasReachedGoal() and Theme.colors.mint or Theme.colors.coral
    Theme:drawTextCenteredWithShadow(scoreText, 0, panelY + 130, screenWidth, Theme.fonts.large, scoreColor)

    -- Reward breakdown (only if won)
    if self.won then
        local rewardPanelX = panelX + 40
        local rewardPanelY = panelY + 180
        local rewardPanelWidth = panelWidth - 80
        local rewardPanelHeight = 160

        self.nineSlice:draw(rewardPanelX, rewardPanelY, rewardPanelWidth, rewardPanelHeight, Theme.colors.surface2,
            Theme.nineSlice.borderScale)

        -- Title
        Theme:drawTextWithShadow("BELOHNUNGEN", rewardPanelX + 16, rewardPanelY + 12, Theme.fonts.normal, Theme.colors.textMuted)

        -- Base reward
        Theme:drawTextWithShadow("Level Belohnung", rewardPanelX + 16, rewardPanelY + 45, Theme.fonts.normal, Theme.colors.text)
        local baseText = "+" .. tostring(self.baseReward)
        Theme:drawTextRightWithShadow(baseText, rewardPanelX, rewardPanelY + 45, rewardPanelWidth - 16, Theme.fonts.normal, Theme.colors.gold)

        -- Unused hands bonus
        local handsText = "Hände übrig (" .. tostring(GameState.handsRemaining) .. ")"
        Theme:drawTextWithShadow(handsText, rewardPanelX + 16, rewardPanelY + 75, Theme.fonts.normal, Theme.colors.text)
        local bonusText = "+" .. tostring(self.unusedHandsBonus)
        Theme:drawTextRightWithShadow(bonusText, rewardPanelX, rewardPanelY + 75, rewardPanelWidth - 16, Theme.fonts.normal, Theme.colors.gold)

        -- Divider
        love.graphics.setColor(Theme.colors.border)
        love.graphics.rectangle("fill", rewardPanelX + 16, rewardPanelY + 105, rewardPanelWidth - 32, 2)

        -- Total
        Theme:drawTextWithShadow("GESAMT", rewardPanelX + 16, rewardPanelY + 118, Theme.fonts.large, Theme.colors.text)
        local totalText = "+" .. tostring(self.reward)
        Theme:drawTextRightWithShadow(totalText, rewardPanelX, rewardPanelY + 118, rewardPanelWidth - 16, Theme.fonts.large, Theme.colors.gold)
    else
        -- Loss message
        Theme:drawTextCenteredWithShadow("Ziel nicht erreicht.", 0, panelY + 200, screenWidth, Theme.fonts.large, Theme.colors.textMuted)
        Theme:drawTextCenteredWithShadow("Versuche es erneut!", 0, panelY + 250, screenWidth, Theme.fonts.large, Theme.colors.textMuted)
    end

    -- Action button
    self.actionButton:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function ResultState:mousepressed(x, y, button)
    self.actionButton:mousepressed(x, y, button)
end

function ResultState:mousereleased(x, y, button)
    self.actionButton:mousereleased(x, y, button)
end

function ResultState:keypressed(key)
    if key == "space" or key == "return" then
        self:onActionButtonClick()
    end
end

return ResultState
