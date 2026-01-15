-- Shop State - Upgrade shop between levels
-- Currently empty placeholder, just advances to next level

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
    local layout = Theme.layout

    local buttonText
    if Levels:isLastLevel(GameState.currentLevel) and GameState:hasReachedGoal() then
        buttonText = "SIEG! NEUER RUN"
    else
        buttonText = "NACHSTES LEVEL"
    end

    self.actionButton = Button.new({
        x = (Theme.screen.width - layout.actionButtonWidth) / 2,
        y = layout.actionButtonY,
        width = layout.actionButtonWidth,
        height = layout.actionButtonHeight,
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
    local padding = Theme.layout.screenPadding

    -- Title
    love.graphics.setFont(Theme.fonts.display)
    love.graphics.setColor(Theme.colors.cyan)
    local titleText = "SHOP"
    local titleWidth = Theme.fonts.display:getWidth(titleText)
    love.graphics.print(titleText, (screenWidth - titleWidth) / 2, 80)

    -- Current money
    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.gold)
    local moneyText = "Guthaben: " .. tostring(GameState.money)
    local moneyWidth = Theme.fonts.large:getWidth(moneyText)
    love.graphics.print(moneyText, (screenWidth - moneyWidth) / 2, 140)

    -- Empty shop placeholder
    local panelX = padding + 20
    local panelY = 200
    local panelWidth = screenWidth - padding * 2 - 40
    local panelHeight = 300

    self.nineSlice:draw(panelX, panelY, panelWidth, panelHeight, Theme.colors.surface)

    -- Empty message
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.textMuted)
    local emptyText = "Shop ist leer..."
    local emptyWidth = Theme.fonts.normal:getWidth(emptyText)
    love.graphics.print(emptyText, (screenWidth - emptyWidth) / 2, panelY + panelHeight / 2 - 20)

    local comingSoonText = "(Upgrades kommen bald)"
    local comingSoonWidth = Theme.fonts.normal:getWidth(comingSoonText)
    love.graphics.print(comingSoonText, (screenWidth - comingSoonWidth) / 2, panelY + panelHeight / 2 + 10)

    -- Level info
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.text)
    local levelText = "Level " .. tostring(GameState.currentLevel) .. " / " .. tostring(Levels.totalLevels)
    local levelWidth = Theme.fonts.normal:getWidth(levelText)
    love.graphics.print(levelText, (screenWidth - levelWidth) / 2, panelY + panelHeight + 20)

    -- Next goal preview
    if not Levels:isLastLevel(GameState.currentLevel) then
        love.graphics.setColor(Theme.colors.textMuted)
        local nextGoal = Levels:getGoal(GameState.currentLevel + 1)
        local nextText = "Nachstes Ziel: " .. tostring(nextGoal)
        local nextWidth = Theme.fonts.normal:getWidth(nextText)
        love.graphics.print(nextText, (screenWidth - nextWidth) / 2, panelY + panelHeight + 50)
    else
        love.graphics.setColor(Theme.colors.mint)
        local finalText = "LETZTES LEVEL GESCHAFFT!"
        local finalWidth = Theme.fonts.normal:getWidth(finalText)
        love.graphics.print(finalText, (screenWidth - finalWidth) / 2, panelY + panelHeight + 50)
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
