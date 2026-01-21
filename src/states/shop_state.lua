-- Shop State - Upgrade shop between levels (Landscape layout)
-- Currently placeholder, advances to next level

local Theme = require("src.ui.theme")
local GameState = require("src.game.game_state")
local Levels = require("src.game.levels")
local Button = require("src.ui.button")
local NineSlice = require("src.ui.nine_slice")
local InfoPanel = require("src.ui.info_panel")

local ShopState = {}
ShopState.__index = ShopState

function ShopState.new()
    local self = setmetatable({}, ShopState)

    self.nineSlice = NineSlice.getInstance()
    self.actionButton = nil
    self.stateMachine = nil
    self.infoPanel = nil

    return self
end

function ShopState:enter(params)
    self.stateMachine = params.stateMachine
    self:initInfoPanel()
    self:initActionButton()
end

function ShopState:exit()
end

function ShopState:initActionButton()
    local buttonWidth = Theme.layout.ctaWidth
    local buttonHeight = Theme.layout.ctaHeight

    local buttonText
    if Levels:isLastLevel(GameState.currentLevel) and GameState:hasReachedGoal() then
        buttonText = "SIEG! NEUER RUN"
    else
        buttonText = "NÄCHSTES LEVEL"
    end

    -- Center button in the center area (same as DualCta)
    local centerX = Theme.layout.centerX
    local centerWidth = Theme.layout.centerWidth
    local buttonX = centerX + (centerWidth - buttonWidth) / 2

    self.actionButton = Button.new({
        x = buttonX,
        y = Theme.layout.ctaY,
        width = buttonWidth,
        height = buttonHeight,
        text = buttonText,
        bgColor = Theme.colors.cyan,
        textColor = Theme.colors.text,
        hoverBgColor = { Theme.colors.cyan[1] * 0.9, Theme.colors.cyan[2] * 0.9, Theme.colors.cyan[3] * 0.9, 1 },
        disabledBgColor = Theme.colors.surface,
        disabledTextColor = Theme.colors.textMuted,
        font = Theme.fonts.large,
        onClick = function()
            self:onActionButtonClick()
        end,
    })
end

function ShopState:initInfoPanel()
    local layout = Theme.layout

    self.infoPanel = InfoPanel.new({
        x = layout.leftPanelX,
        y = layout.leftPanelY,
        width = layout.leftPanelWidth,
        height = layout.leftPanelHeight,
        phase = "shop",
        getLevel = function()
            return GameState.currentLevel
        end,
        getRound = function()
            return 1 -- Not relevant in shop
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
            return nil
        end,
        getHandBreakdown = function()
            return nil
        end,
    })
end

function ShopState:onActionButtonClick()
    -- Check if game is won
    if Levels:isLastLevel(GameState.currentLevel) and GameState:hasReachedGoal() then
        -- Game complete! Start new run
        GameState:reset()
        self.stateMachine:change("play", {
            stateMachine = self.stateMachine,
        })
    else
        -- Advance to next level
        GameState:advanceLevel()
        self.stateMachine:change("play", {
            stateMachine = self.stateMachine,
        })
    end
end

function ShopState:update(dt)
    self.actionButton:update(dt)
    if self.infoPanel then
        self.infoPanel:update(dt)
    end
end

function ShopState:draw()
    local screenWidth = Theme.screen.width
    local screenHeight = Theme.screen.height

    -- Center content panel
    local panelWidth = 600
    local panelHeight = 450
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = 60

    self.nineSlice:draw(panelX, panelY, panelWidth, panelHeight, Theme.colors.surface, Theme.nineSlice.borderScale)

    -- Title
    Theme:drawTextCenteredWithShadow("SHOP", 0, panelY + 30, screenWidth, Theme.fonts.display, Theme.colors.cyan)

    -- Current money
    local moneyText = "Guthaben: " .. tostring(GameState.money)
    Theme:drawTextCenteredWithShadow(moneyText, 0, panelY + 90, screenWidth, Theme.fonts.large, Theme.colors.gold)

    -- Empty shop content area
    local shopPanelX = panelX + 40
    local shopPanelY = panelY + 140
    local shopPanelWidth = panelWidth - 80
    local shopPanelHeight = 200

    self.nineSlice:draw(shopPanelX, shopPanelY, shopPanelWidth, shopPanelHeight, Theme.colors.surface2,
        Theme.nineSlice.borderScale)

    -- Empty message
    Theme:drawTextCenteredWithShadow("Shop ist leer...", 0, shopPanelY + shopPanelHeight / 2 - 30, screenWidth,
        Theme.fonts.large, Theme.colors.textMuted)
    Theme:drawTextCenteredWithShadow("(Upgrades kommen bald)", 0, shopPanelY + shopPanelHeight / 2 + 10, screenWidth,
        Theme.fonts.large, Theme.colors.textMuted)

    -- Level info
    local levelText = "Level " .. tostring(GameState.currentLevel) .. " / " .. tostring(Levels.totalLevels)
    Theme:drawTextCenteredWithShadow(levelText, 0, shopPanelY + shopPanelHeight + 20, screenWidth, Theme.fonts.normal,
        Theme.colors.text)

    -- Next goal preview
    if not Levels:isLastLevel(GameState.currentLevel) then
        local nextGoal = Levels:getGoal(GameState.currentLevel + 1)
        local nextText = "Nächstes Ziel: " .. tostring(nextGoal)
        Theme:drawTextCenteredWithShadow(nextText, 0, shopPanelY + shopPanelHeight + 50, screenWidth, Theme.fonts.normal,
            Theme.colors.textMuted)
    else
        Theme:drawTextCenteredWithShadow("LETZTES LEVEL GESCHAFFT!", 0, shopPanelY + shopPanelHeight + 50, screenWidth,
            Theme.fonts.normal, Theme.colors.mint)
    end

    -- Action button
    self.actionButton:draw()

    -- Draw info panel (left side)
    if self.infoPanel then
        self.infoPanel:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ShopState:mousepressed(x, y, button)
    self.actionButton:mousepressed(x, y, button)
    if self.infoPanel then
        self.infoPanel:mousepressed(x, y, button)
    end
end

function ShopState:mousereleased(x, y, button)
    self.actionButton:mousereleased(x, y, button)
    if self.infoPanel then
        self.infoPanel:mousereleased(x, y, button)
    end
end

function ShopState:keypressed(key)
    if key == "space" or key == "return" then
        self:onActionButtonClick()
    end
end

return ShopState
