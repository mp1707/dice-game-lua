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

    love.graphics.setFont(Theme.fonts.display)
    love.graphics.setColor(titleColor)
    local titleWidth = Theme.fonts.display:getWidth(titleText)
    love.graphics.print(titleText, (screenWidth - titleWidth) / 2, panelY + 30)

    -- Level and score summary
    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.text)
    local levelText = "Level " .. tostring(GameState.currentLevel)
    local levelWidth = Theme.fonts.large:getWidth(levelText)
    love.graphics.print(levelText, (screenWidth - levelWidth) / 2, panelY + 90)

    local scoreText = tostring(GameState.currentScore) .. " / " .. tostring(GameState:getCurrentGoal())
    local scoreWidth = Theme.fonts.large:getWidth(scoreText)
    local scoreColor = GameState:hasReachedGoal() and Theme.colors.mint or Theme.colors.coral
    love.graphics.setColor(scoreColor)
    love.graphics.print(scoreText, (screenWidth - scoreWidth) / 2, panelY + 130)

    -- Reward breakdown (only if won)
    if self.won then
        local rewardPanelX = panelX + 40
        local rewardPanelY = panelY + 180
        local rewardPanelWidth = panelWidth - 80
        local rewardPanelHeight = 160

        self.nineSlice:draw(rewardPanelX, rewardPanelY, rewardPanelWidth, rewardPanelHeight, Theme.colors.surface2,
            Theme.nineSlice.borderScale)

        -- Title
        love.graphics.setFont(Theme.fonts.normal)
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.print("BELOHNUNGEN", rewardPanelX + 16, rewardPanelY + 12)

        -- Base reward
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print("Level Belohnung", rewardPanelX + 16, rewardPanelY + 45)

        love.graphics.setColor(Theme.colors.gold)
        local baseText = "+" .. tostring(self.baseReward)
        local baseWidth = Theme.fonts.normal:getWidth(baseText)
        love.graphics.print(baseText, rewardPanelX + rewardPanelWidth - 16 - baseWidth, rewardPanelY + 45)

        -- Unused hands bonus
        love.graphics.setColor(Theme.colors.text)
        local handsText = "Hände übrig (" .. tostring(GameState.handsRemaining) .. ")"
        love.graphics.print(handsText, rewardPanelX + 16, rewardPanelY + 75)

        love.graphics.setColor(Theme.colors.gold)
        local bonusText = "+" .. tostring(self.unusedHandsBonus)
        local bonusWidth = Theme.fonts.normal:getWidth(bonusText)
        love.graphics.print(bonusText, rewardPanelX + rewardPanelWidth - 16 - bonusWidth, rewardPanelY + 75)

        -- Divider
        love.graphics.setColor(Theme.colors.border)
        love.graphics.rectangle("fill", rewardPanelX + 16, rewardPanelY + 105, rewardPanelWidth - 32, 2)

        -- Total
        love.graphics.setFont(Theme.fonts.large)
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print("GESAMT", rewardPanelX + 16, rewardPanelY + 118)

        love.graphics.setColor(Theme.colors.gold)
        local totalText = "+" .. tostring(self.reward)
        local totalWidth = Theme.fonts.large:getWidth(totalText)
        love.graphics.print(totalText, rewardPanelX + rewardPanelWidth - 16 - totalWidth, rewardPanelY + 118)
    else
        -- Loss message
        love.graphics.setFont(Theme.fonts.large)
        love.graphics.setColor(Theme.colors.textMuted)
        local lossText = "Ziel nicht erreicht."
        local lossWidth = Theme.fonts.large:getWidth(lossText)
        love.graphics.print(lossText, (screenWidth - lossWidth) / 2, panelY + 200)

        local tryAgainText = "Versuche es erneut!"
        local tryAgainWidth = Theme.fonts.large:getWidth(tryAgainText)
        love.graphics.print(tryAgainText, (screenWidth - tryAgainWidth) / 2, panelY + 250)
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
