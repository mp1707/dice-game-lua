-- Info Panel component (NEW LAYOUT)
-- Left-side panel with level, round, goal, score, hand formula, counters, money, and utility buttons

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Button = require("src.ui.button")
local HandFormula = require("src.ui.hand_formula")

local InfoPanel = {}
InfoPanel.__index = InfoPanel

function InfoPanel.new(config)
    local self = setmetatable({}, InfoPanel)

    -- Position on LEFT side now
    self.x = config.x or Theme.layout.leftPanelX
    self.y = config.y or Theme.layout.leftPanelY
    self.width = config.width or Theme.layout.leftPanelWidth
    self.height = config.height or Theme.layout.leftPanelHeight
    self.padding = Theme.layout.panelPadding or 20
    self.innerGap = Theme.layout.innerGap or 12

    -- Data callbacks
    self.getLevel = config.getLevel or function() return 1 end
    self.getRound = config.getRound or function() return 1 end
    self.getMoney = config.getMoney or function() return 0 end
    self.getGoal = config.getGoal or function() return 300 end
    self.getScore = config.getScore or function() return 0 end
    self.hasReachedGoal = config.hasReachedGoal or function() return false end
    self.getHandsRemaining = config.getHandsRemaining or function() return 4 end
    self.getRollsRemaining = config.getRollsRemaining or function() return 3 end
    self.getDetectedHand = config.getDetectedHand or function() return nil end
    self.getHandBreakdown = config.getHandBreakdown or function() return nil end

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    -- Hand formula component
    local contentX = self.x + self.padding
    local contentW = self.width - self.padding * 2
    self.handFormula = HandFormula.new({
        x = contentX,
        y = 0, -- will be positioned dynamically
        width = contentW,
    })

    -- Utility buttons (settings and info)
    local buttonWidth = (contentW - self.innerGap) / 2
    local buttonHeight = 50
    local buttonY = self.y + self.height - buttonHeight - self.padding

    self.settingsButton = Button.new({
        x = contentX,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight,
        text = "Einstellungen",
        bgColor = Theme.colors.buttonGray,
        textColor = Theme.colors.text,
        font = Theme.fonts.normal,
        onClick = function()
            -- Mock functionality for now
        end,
    })

    self.infoButton = Button.new({
        x = contentX + buttonWidth + self.innerGap,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight,
        text = "Info",
        bgColor = Theme.colors.buttonLightBlue,
        textColor = Theme.colors.text,
        font = Theme.fonts.normal,
        onClick = function()
            -- Mock functionality for now
        end,
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
    self.settingsButton:update(dt)
    self.infoButton:update(dt)
end

function InfoPanel:mousepressed(x, y, button)
    if self.settingsButton:mousepressed(x, y, button) then
        return true
    end
    if self.infoButton:mousepressed(x, y, button) then
        return true
    end
    return false
end

function InfoPanel:mousereleased(x, y, button)
    if self.settingsButton:mousereleased(x, y, button) then
        return true
    end
    if self.infoButton:mousereleased(x, y, button) then
        return true
    end
    return false
end

function InfoPanel:draw()
    -- Main panel background
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

    -- 1. Level + Round row
    self:drawLevelRoundRow(contentX, contentY, contentW)
    contentY = contentY + 60 + self.innerGap

    -- 2. Goal section
    self:drawGoalSection(contentX, contentY, contentW)
    contentY = contentY + 160 + self.innerGap

    -- 3. Score section
    self:drawScoreSection(contentX, contentY, contentW)
    contentY = contentY + 70 + self.innerGap

    -- 4. Hand preview (always visible space)
    self:drawHandPreview(contentX, contentY, contentW)
    contentY = contentY + 130 + self.innerGap

    -- 5. Counters row (Hände + Würfe)
    self:drawCountersRow(contentX, contentY, contentW)
    contentY = contentY + 70 + self.innerGap

    -- 6. Money display
    self:drawMoneyDisplay(contentX, contentY, contentW)

    -- 7. Utility buttons (positioned at bottom)
    self.settingsButton:draw()
    self.infoButton:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function InfoPanel:drawLevelRoundRow(x, y, width)
    local boxWidth = (width - self.innerGap) / 2
    local boxHeight = 60

    -- Level box
    self.nineSlice:draw(x, y, boxWidth, boxHeight, Theme.colors.panelDark, Theme.nineSlice.borderScale)
    Theme:drawTextCenteredWithShadow("Level " .. tostring(self.getLevel()), x, y + (boxHeight - Theme.fonts.large:getHeight()) / 2, boxWidth, Theme.fonts.large, Theme.colors.text)

    -- Round box
    local roundX = x + boxWidth + self.innerGap
    self.nineSlice:draw(roundX, y, boxWidth, boxHeight, Theme.colors.panelDark, Theme.nineSlice.borderScale)
    Theme:drawTextCenteredWithShadow("Runde " .. tostring(self.getRound()), roundX, y + (boxHeight - Theme.fonts.large:getHeight()) / 2, boxWidth, Theme.fonts.large, Theme.colors.text)
end

function InfoPanel:drawGoalSection(x, y, width)
    local boxHeight = 160

    -- Goal box with dark background
    self.nineSlice:draw(x, y, width, boxHeight, Theme.colors.panelDark, Theme.nineSlice.borderScale)

    -- "erreiche" label
    local labelY = y + 16
    Theme:drawTextCenteredWithShadow("erreiche", x, labelY, width, Theme.fonts.large, Theme.colors.text)

    -- Big goal number (coral/red color)
    local goal = self.getGoal()
    local goalY = labelY + 30
    Theme:drawTextCenteredWithShadow(tostring(goal), x, goalY, width, Theme.fonts.giant, Theme.colors.coral)

    -- "Punkte" label below
    local punkteY = goalY + 70
    Theme:drawTextCenteredWithShadow("Punkte", x, punkteY, width, Theme.fonts.large, Theme.colors.text)
end

function InfoPanel:drawScoreSection(x, y, width)
    local boxHeight = 70

    -- Score box
    self.nineSlice:draw(x, y, width, boxHeight, Theme.colors.panelDark, Theme.nineSlice.borderScale)

    -- "Punkte" label on left
    local labelX = x + 16
    local textY = y + (boxHeight - Theme.fonts.large:getHeight()) / 2
    Theme:drawTextWithShadow("Punkte", labelX, textY, Theme.fonts.large, Theme.colors.text)

    -- Score value on right
    local score = self.getScore()
    local scoreText = tostring(score)
    local scoreWidth = Theme.fonts.huge:getWidth(scoreText)
    local scoreX = x + width - scoreWidth - 16
    local scoreY = y + (boxHeight - Theme.fonts.huge:getHeight()) / 2
    Theme:drawTextWithShadow(scoreText, scoreX, scoreY, Theme.fonts.huge, Theme.colors.text)
end

function InfoPanel:drawHandPreview(x, y, width)
    local boxHeight = 130

    -- Hand preview box (always visible)
    self.nineSlice:draw(x, y, width, boxHeight, Theme.colors.panelDark, Theme.nineSlice.borderScale)

    local detectedHand = self.getDetectedHand()
    local breakdown = self.getHandBreakdown()

    if detectedHand and breakdown then
        -- Show hand name at top
        local handY = y + 12
        local handName = string.upper(detectedHand.name or detectedHand.id or "")
        local levelText = "LV " .. tostring(detectedHand.level or 1)

        -- Draw hand name on left, level on right
        Theme:drawTextWithShadow(handName, x + 16, handY, Theme.fonts.large, Theme.colors.text)
        local levelWidth = Theme.fonts.large:getWidth(levelText)
        Theme:drawTextWithShadow(levelText, x + width - levelWidth - 16, handY, Theme.fonts.large, Theme.colors.text)

        -- Draw formula boxes
        local formulaY = y + 55
        local formulaX = x + 16
        local formulaWidth = width - 32

        -- Calculate box sizes
        local xSymbolWidth = Theme.fonts.large:getWidth("x")
        local spacing = 12
        local boxWidth = (formulaWidth - spacing * 2 - xSymbolWidth) / 2
        local boxHeightInner = 50

        -- Chips box (blue)
        love.graphics.setColor(Theme.colors.upgradePoints)
        love.graphics.rectangle("fill", formulaX, formulaY, boxWidth, boxHeightInner, 8)

        local chipsText = tostring(breakdown.basePoints + breakdown.pips)
        local chipsTextWidth = Theme.fonts.large:getWidth(chipsText)
        local chipsTextX = formulaX + (boxWidth - chipsTextWidth) / 2
        local textCenterY = formulaY + (boxHeightInner - Theme.fonts.large:getHeight()) / 2
        love.graphics.setColor(Theme.colors.text)
        love.graphics.setFont(Theme.fonts.large)
        love.graphics.print(chipsText, math.floor(chipsTextX), math.floor(textCenterY))

        -- "x" symbol
        local xX = formulaX + boxWidth + spacing
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.print("x", xX, textCenterY)

        -- Mult box (red)
        local multBoxX = xX + xSymbolWidth + spacing
        love.graphics.setColor(Theme.colors.upgradeMult)
        love.graphics.rectangle("fill", multBoxX, formulaY, boxWidth, boxHeightInner, 8)

        local multText = tostring(breakdown.mult)
        local multTextWidth = Theme.fonts.large:getWidth(multText)
        local multTextX = multBoxX + (boxWidth - multTextWidth) / 2
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print(multText, math.floor(multTextX), math.floor(textCenterY))
    else
        -- Empty state - show placeholder
        local emptyY = y + boxHeight / 2 - Theme.fonts.normal:getHeight() / 2
        Theme:drawTextCenteredWithShadow("Wähle Würfel aus", x, emptyY, width, Theme.fonts.normal, Theme.colors.textMuted)
    end
end

function InfoPanel:drawCountersRow(x, y, width)
    local boxWidth = (width - self.innerGap) / 2
    local boxHeight = 70

    -- Hände box
    self.nineSlice:draw(x, y, boxWidth, boxHeight, Theme.colors.panelDark, Theme.nineSlice.borderScale)

    local handeY = y + 12
    Theme:drawTextWithShadow("Hände", x + 16, handeY, Theme.fonts.normal, Theme.colors.text)

    local handsValue = tostring(self.getHandsRemaining())
    local handsValueWidth = Theme.fonts.huge:getWidth(handsValue)
    local handsValueY = y + boxHeight - Theme.fonts.huge:getHeight() - 8
    Theme:drawTextWithShadow(handsValue, x + boxWidth - handsValueWidth - 16, handsValueY, Theme.fonts.huge, Theme.colors.mint)

    -- Würfe box
    local wurfeX = x + boxWidth + self.innerGap
    self.nineSlice:draw(wurfeX, y, boxWidth, boxHeight, Theme.colors.panelDark, Theme.nineSlice.borderScale)

    Theme:drawTextWithShadow("Würfe", wurfeX + 16, handeY, Theme.fonts.normal, Theme.colors.text)

    local rollsValue = tostring(self.getRollsRemaining())
    local rollsValueWidth = Theme.fonts.huge:getWidth(rollsValue)
    Theme:drawTextWithShadow(rollsValue, wurfeX + boxWidth - rollsValueWidth - 16, handsValueY, Theme.fonts.huge, Theme.colors.cyan)
end

function InfoPanel:drawMoneyDisplay(x, y, width)
    local boxHeight = 60

    -- Money box
    self.nineSlice:draw(x, y, width, boxHeight, Theme.colors.panelDark, Theme.nineSlice.borderScale)

    -- Money value centered in gold
    local money = self.getMoney()
    local moneyText = "$" .. tostring(money)
    Theme:drawTextCenteredWithShadow(moneyText, x, y + (boxHeight - Theme.fonts.huge:getHeight()) / 2, width, Theme.fonts.huge, Theme.colors.gold)
end

return InfoPanel
