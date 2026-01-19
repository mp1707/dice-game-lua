-- Info Panel component
-- Right-side panel with level, goal, score, hand formula, counters, and action button

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Button = require("src.ui.button")
local HandFormula = require("src.ui.hand_formula")

local InfoPanel = {}
InfoPanel.__index = InfoPanel

function InfoPanel.new(config)
    local self = setmetatable({}, InfoPanel)

    self.x = config.x or Theme.layout.rightPanelX
    self.y = config.y or Theme.layout.rightPanelY
    self.width = config.width or Theme.layout.rightPanelWidth
    self.height = config.height or Theme.layout.rightPanelHeight
    self.padding = 20

    -- Data callbacks
    self.getLevel = config.getLevel or function() return 1 end
    self.getMoney = config.getMoney or function() return 0 end
    self.getGoal = config.getGoal or function() return 50 end
    self.getScore = config.getScore or function() return 0 end
    self.hasReachedGoal = config.hasReachedGoal or function() return false end
    self.getHandsRemaining = config.getHandsRemaining or function() return 4 end
    self.getRollsRemaining = config.getRollsRemaining or function() return 3 end
    self.getSelectedHand = config.getSelectedHand or function() return nil end
    self.getHandBreakdown = config.getHandBreakdown or function() return nil end

    -- Action button callbacks
    self.onActionClick = config.onActionClick or function() end
    self.getActionText = config.getActionText or function() return "WÜRFELN" end
    self.getActionEnabled = config.getActionEnabled or function() return true end
    self.getActionColor = config.getActionColor or function() return Theme.colors.cyan end

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    -- Hand formula component
    local contentX = self.x + self.padding
    self.handFormula = HandFormula.new({
        x = contentX,
        y = self.y + 340, -- positioned after score section
        width = self.width - self.padding * 2,
    })

    -- Action button (at bottom of panel)
    local buttonWidth = self.width - self.padding * 2
    local buttonHeight = Theme.layout.actionButtonHeight
    self.actionButton = Button.new({
        x = contentX,
        y = self.y + self.height - buttonHeight - self.padding,
        width = buttonWidth,
        height = buttonHeight,
        text = "WÜRFELN",
        bgColor = Theme.colors.cyan,
        textColor = Theme.colors.textDark,
        onClick = function()
            self.onActionClick()
        end,
        disabledBgColor = Theme.colors.surfaceHighlight,
    })

    return self
end

function InfoPanel:updateFormula(handName, level, chips, mult)
    if handName then
        self.handFormula:set(handName, level, chips, mult)
    else
        self.handFormula:clear()
    end
end

function InfoPanel:update(dt)
    -- Update action button state
    local actionText = self.getActionText()
    local actionEnabled = self.getActionEnabled()
    local actionColor = self.getActionColor()

    self.actionButton:setText(actionText)
    self.actionButton:setEnabled(actionEnabled)
    self.actionButton.bgColor = actionColor

    self.actionButton:update(dt)
end

function InfoPanel:mousepressed(x, y, button)
    return self.actionButton:mousepressed(x, y, button)
end

function InfoPanel:mousereleased(x, y, button)
    return self.actionButton:mousereleased(x, y, button)
end

function InfoPanel:draw()
    -- Panel background
    self.nineSlice:draw(
        self.x,
        self.y,
        self.width,
        self.height,
        Theme.colors.surface,
        Theme.nineSlice.borderScale
    )

    local contentX = self.x + self.padding
    local contentY = self.y + self.padding
    local contentW = self.width - self.padding * 2

    -- Level and Money row
    self:drawLevelMoney(contentX, contentY, contentW)
    contentY = contentY + 50

    -- Goal box (red background)
    self:drawGoalBox(contentX, contentY, contentW)
    contentY = contentY + 100

    -- Points display
    self:drawPointsBox(contentX, contentY, contentW)
    contentY = contentY + 80

    -- Divider
    love.graphics.setColor(Theme.colors.border)
    love.graphics.rectangle("fill", contentX, contentY, contentW, 2)
    contentY = contentY + 16

    -- Hand formula (if hand selected)
    self.handFormula.x = contentX
    self.handFormula.y = contentY
    self.handFormula:draw()

    if self.handFormula.visible then
        contentY = contentY + self.handFormula:getHeight() + 16
        -- Divider after formula
        love.graphics.setColor(Theme.colors.border)
        love.graphics.rectangle("fill", contentX, contentY, contentW, 2)
        contentY = contentY + 16
    end

    -- Hands remaining counter
    self:drawCounter(contentX, contentY, contentW, "Hände", self.getHandsRemaining(), Theme.images.glove,
        Theme.colors.mint)
    contentY = contentY + 50

    -- Rolls remaining counter
    self:drawCounter(contentX, contentY, contentW, "Würfe", self.getRollsRemaining(), Theme.images.die, Theme.colors
        .cyan)

    -- Action button
    self.actionButton:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function InfoPanel:drawLevelMoney(x, y, width)
    -- Level label and number
    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("LEVEL " .. tostring(self.getLevel()), x, y)

    -- Money with coin icon (right aligned)
    local money = self.getMoney()
    local moneyText = tostring(money)
    local moneyWidth = Theme.fonts.large:getWidth(moneyText)
    local coinSize = 28

    love.graphics.setColor(Theme.colors.gold)
    if Theme.images.coin then
        local coinScale = coinSize / Theme.images.coin:getWidth()
        local moneyX = x + width - moneyWidth
        local coinX = moneyX - coinSize - 8
        love.graphics.draw(Theme.images.coin, coinX, y, 0, coinScale, coinScale)
        love.graphics.print(moneyText, moneyX, y + (coinSize - Theme.fonts.large:getHeight()) / 2)
    else
        love.graphics.print("$" .. moneyText, x + width - moneyWidth - 20, y)
    end
end

function InfoPanel:drawGoalBox(x, y, width)
    local boxHeight = 80

    -- Red background box
    self.nineSlice:draw(x, y, width, boxHeight, Theme.colors.coral, Theme.nineSlice.borderScale)

    -- "ZIEL" label
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.text)
    love.graphics.print("ZIEL", x + 16, y + 12)

    -- Goal value (large, centered)
    local goal = self.getGoal()
    love.graphics.setFont(Theme.fonts.display)
    love.graphics.setColor(Theme.colors.text)
    local goalText = tostring(goal)
    local goalWidth = Theme.fonts.display:getWidth(goalText)
    local goalX = x + (width - goalWidth) / 2
    local goalY = y + (boxHeight - Theme.fonts.display:getHeight()) / 2 + 4
    love.graphics.print(goalText, math.floor(goalX), math.floor(goalY))
end

function InfoPanel:drawPointsBox(x, y, width)
    local boxHeight = 60

    -- Dark background box
    self.nineSlice:draw(x, y, width, boxHeight, Theme.colors.surface2, Theme.nineSlice.borderScale)

    -- "PUNKTE" label
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("PUNKTE", x + 16, y + (boxHeight - Theme.fonts.normal:getHeight()) / 2)

    -- Score value (right aligned)
    local score = self.getScore()
    local scoreColor = self.hasReachedGoal() and Theme.colors.mint or Theme.colors.text
    love.graphics.setFont(Theme.fonts.huge)
    love.graphics.setColor(scoreColor)
    local scoreText = tostring(score)
    local scoreWidth = Theme.fonts.huge:getWidth(scoreText)
    local scoreX = x + width - scoreWidth - 16
    local scoreY = y + (boxHeight - Theme.fonts.huge:getHeight()) / 2
    love.graphics.print(scoreText, math.floor(scoreX), math.floor(scoreY))
end

function InfoPanel:drawCounter(x, y, width, label, value, icon, valueColor)
    local iconSize = 32

    -- Icon
    if icon then
        love.graphics.setColor(1, 1, 1, 1)
        local iconScale = iconSize / icon:getWidth()
        love.graphics.draw(icon, x, y, 0, iconScale, iconScale)
    end

    -- Label
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.textMuted)
    local labelX = icon and (x + iconSize + 12) or x
    local labelY = y + (iconSize - Theme.fonts.normal:getHeight()) / 2
    love.graphics.print(label, labelX, labelY)

    -- Value (right aligned)
    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(valueColor or Theme.colors.text)
    local valueText = tostring(value)
    local valueWidth = Theme.fonts.large:getWidth(valueText)
    local valueY = y + (iconSize - Theme.fonts.large:getHeight()) / 2
    love.graphics.print(valueText, x + width - valueWidth, valueY)
end

return InfoPanel
