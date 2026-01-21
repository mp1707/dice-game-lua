-- Shop State - Upgrade shop between levels (Landscape layout)
-- Currently placeholder, advances to next level

local Theme = require("src.ui.theme")
local GameState = require("src.game.game_state")
local Levels = require("src.game.levels")
local Button = require("src.ui.button")
local NineSlice = require("src.ui.nine_slice")

local ShopState = {}
ShopState.__index = ShopState

function ShopState.new()
    local self = setmetatable({}, ShopState)

    self.nineSlice = NineSlice.getInstance()
    self.actionButton = nil
    self.stateMachine = nil

    return self
end

function ShopState:enter(params)
    self.stateMachine = params.stateMachine
    self:initActionButton()
end

function ShopState:exit()
end

function ShopState:initActionButton()
    local buttonWidth = 300
    local buttonHeight = 60

    local buttonText
    if Levels:isLastLevel(GameState.currentLevel) and GameState:hasReachedGoal() then
        buttonText = "SIEG! NEUER RUN"
    else
        buttonText = "NÄCHSTES LEVEL"
    end

    self.actionButton = Button.new({
        x = (Theme.screen.width - buttonWidth) / 2,
        y = Theme.screen.height - 100,
        width = buttonWidth,
        height = buttonHeight,
        text = buttonText,
        bgColor = Theme.colors.cyan,
        textColor = Theme.colors.textDark,
        hoverBgColor = Theme.colors.cyan,
        onClick = function()
            self:onActionButtonClick()
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
    Theme:drawTextCenteredWithShadow("Shop ist leer...", 0, shopPanelY + shopPanelHeight / 2 - 30, screenWidth, Theme.fonts.large, Theme.colors.textMuted)
    Theme:drawTextCenteredWithShadow("(Upgrades kommen bald)", 0, shopPanelY + shopPanelHeight / 2 + 10, screenWidth, Theme.fonts.large, Theme.colors.textMuted)

    -- Level info
    local levelText = "Level " .. tostring(GameState.currentLevel) .. " / " .. tostring(Levels.totalLevels)
    Theme:drawTextCenteredWithShadow(levelText, 0, shopPanelY + shopPanelHeight + 20, screenWidth, Theme.fonts.normal, Theme.colors.text)

    -- Next goal preview
    if not Levels:isLastLevel(GameState.currentLevel) then
        local nextGoal = Levels:getGoal(GameState.currentLevel + 1)
        local nextText = "Nächstes Ziel: " .. tostring(nextGoal)
        Theme:drawTextCenteredWithShadow(nextText, 0, shopPanelY + shopPanelHeight + 50, screenWidth, Theme.fonts.normal, Theme.colors.textMuted)
    else
        Theme:drawTextCenteredWithShadow("LETZTES LEVEL GESCHAFFT!", 0, shopPanelY + shopPanelHeight + 50, screenWidth, Theme.fonts.normal, Theme.colors.mint)
    end

    -- Action button
    self.actionButton:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function ShopState:mousepressed(x, y, button)
    self.actionButton:mousepressed(x, y, button)
end

function ShopState:mousereleased(x, y, button)
    self.actionButton:mousereleased(x, y, button)
end

function ShopState:keypressed(key)
    if key == "space" or key == "return" then
        self:onActionButtonClick()
    end
end

return ShopState
