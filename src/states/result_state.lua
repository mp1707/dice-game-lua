-- Result State - Level complete/failed screen (Landscape layout)
-- Shows rewards and transitions to shop or game over

local Theme = require("src.ui.theme")
local GameState = require("src.game.game_state")
local Levels = require("src.game.levels")
local Button = require("src.ui.button")
local NineSlice = require("src.ui.nine_slice")
local InfoPanel = require("src.ui.info_panel")
local Juice = require("src.ui.juice")
local Sound = require("src.core.sound")

local ResultState = {}
ResultState.__index = ResultState

function ResultState.new()
    local self = setmetatable({}, ResultState)

    self.nineSlice = NineSlice.getInstance()
    self.actionButton = nil
    self.stateMachine = nil
    self.infoPanel = nil

    -- Result data
    self.won = false
    self.reward = 0
    self.baseReward = 0
    self.unusedHandsBonus = 0

    -- Animation state
    self.timer = 0
    -- Timings
    self.slideDuration = 0.5
    self.staggerStart = 0.5
    self.staggerDelay = 0.4 -- Slower stagger (was 0.15)
    self.itemFadeDuration = 0.3

    -- Track which rows have played their sound
    self.rowSoundsPlayed = {}

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

    -- Reset animation timer
    self.timer = 0
    -- Reset row sounds tracking
    self.rowSoundsPlayed = {}

    -- Initialize spring for total reward text
    self.totalRewardScale = 1
    self.totalRewardScaleVelocity = 0

    -- Initialize info panel for cashout phase
    self:initInfoPanel()
    self:initActionButton()
end

function ResultState:exit()
end

function ResultState:initActionButton()
    local buttonWidth = Theme.layout.ctaWidth
    local buttonHeight = Theme.layout.ctaHeight

    local buttonText, buttonColor
    if self.won then
        buttonText = "SHOP"
        buttonColor = Theme.colors.mint
    else
        buttonText = "NEW RUN"
        buttonColor = Theme.colors.coral
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
        bgColor = buttonColor,
        textColor = Theme.colors.text,
        hoverBgColor = { buttonColor[1] * 0.9, buttonColor[2] * 0.9, buttonColor[3] * 0.9, 1 },
        disabledBgColor = Theme.colors.surface,
        disabledTextColor = Theme.colors.textMuted,
        font = Theme.fonts.large,
        onClick = function()
            self:onActionButtonClick()
        end,
    })
end

function ResultState:initInfoPanel()
    local layout = Theme.layout

    self.infoPanel = InfoPanel.new({
        x = layout.leftPanelX,
        y = layout.leftPanelY,
        width = layout.leftPanelWidth,
        height = layout.leftPanelHeight,
        phase = "cashout",
        getLevel = function()
            return GameState.currentLevel
        end,
        getRound = function()
            return 1 -- Not relevant in cashout
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
    self.timer = self.timer + dt

    -- Update total reward pulse spring
    self.totalRewardScale, self.totalRewardScaleVelocity = Juice.updateSpring(
        self.totalRewardScale, 1, self.totalRewardScaleVelocity,
        400, 24, dt
    )

    self.actionButton:update(dt)
    if self.infoPanel then
        self.infoPanel:update(dt)
    end
end

-- Helper for easing (removed, using Juice)

function ResultState:draw()
    local screenWidth = Theme.screen.width
    local screenHeight = Theme.screen.height

    -- Center content panel (aligned with Center Area and above CTA)
    local panelWidth = 500
    local panelHeight = 400

    local centerAreaX = Theme.layout.centerX
    local centerAreaWidth = Theme.layout.centerWidth

    local panelX = centerAreaX + (centerAreaWidth - panelWidth) / 2
    local finalPanelY = (Theme.layout.ctaY - panelHeight) / 2

    -- Animation: Slide in from top (Juicy Back/Overshoot)
    local slideProgress = math.min(1, self.timer / self.slideDuration)
    local easedSlide = Juice.easeOutBack(slideProgress)

    -- Start above screen (-panelHeight), end at finalPanelY
    local startY = -panelHeight - 50
    local currentPanelY = startY + (finalPanelY - startY) * easedSlide

    -- Draw Main Panel with Glass Effect
    self.nineSlice:draw(panelX, currentPanelY, panelWidth, panelHeight, Theme.colors.panelGlass,
        Theme.nineSlice.borderScale)

    -- Title
    local titleText = self.won and "LEVEL CLEARED!" or "GAME OVER!"
    local titleColor = self.won and Theme.colors.mint or Theme.colors.coral
    Theme:drawTextCenteredWithShadow(titleText, panelX, currentPanelY + 30, panelWidth, Theme.fonts.display, titleColor)

    -- Level and score summary
    local levelText = "Level " .. tostring(GameState.currentLevel)
    Theme:drawTextCenteredWithShadow(levelText, panelX, currentPanelY + 90, panelWidth, Theme.fonts.large,
        Theme.colors.text)

    local scoreText = tostring(GameState.currentScore) .. " / " .. tostring(GameState:getCurrentGoal())
    local scoreColor = GameState:hasReachedGoal() and Theme.colors.mint or Theme.colors.coral
    Theme:drawTextCenteredWithShadow(scoreText, panelX, currentPanelY + 130, panelWidth, Theme.fonts.large, scoreColor)

    -- Reward breakdown (only if won)
    if self.won then
        local rewardPanelX = panelX + 40
        local rewardPanelY = currentPanelY + 180
        local rewardPanelWidth = panelWidth - 80
        local rewardPanelHeight = 160

        -- Background for rewards (slightly darker/opaque for readability)
        self.nineSlice:draw(rewardPanelX, rewardPanelY, rewardPanelWidth, rewardPanelHeight, Theme.colors.surface2,
            Theme.nineSlice.borderScale)

        local contentX = rewardPanelX + 16
        local contentW = rewardPanelWidth - 32

        -- Function to draw a staggered row with POP effect
        local function drawRow(index, yOffset, drawFn)
            local startT = self.staggerStart + (index - 1) * self.staggerDelay
            if self.timer < startT then return end

            -- Play cash sound when row first appears
            if not self.rowSoundsPlayed[index] then
                self.rowSoundsPlayed[index] = true
                Sound:play("cash")

                -- Trigger pulse for Total row (index 3)
                if index == 3 then
                    self.totalRewardScale = 1.3
                    self.totalRewardScaleVelocity = 0
                end
            end

            local progress = math.min(1, (self.timer - startT) / self.itemFadeDuration)
            local alpha = math.min(1, progress * 1.5) -- Fade in slightly faster than pop

            -- Removed scale animation

            love.graphics.push()
            -- No scaling

            love.graphics.setColor(1, 1, 1, alpha) -- Apply alpha to context
            drawFn(yOffset, alpha)

            love.graphics.pop()
        end

        -- Title (Header) - Index 0 (appears with panel or first)
        Theme:drawTextWithShadow("REWARDS", contentX, rewardPanelY + 12, Theme.fonts.normal, Theme.colors.textMuted)

        -- 1. Base Reward
        drawRow(1, rewardPanelY + 45, function(y, alpha)
            local textColor = { Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha }
            local goldColor = { Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], alpha }
            local shadowColor = { Theme.colors.textShadow[1], Theme.colors.textShadow[2], Theme.colors.textShadow[3],
                Theme.colors.textShadow[4] * alpha }

            -- Override shadow util temporarily or just draw manually for alpha support
            -- Simplest is to set color and let drawTextWithShadow use current alpha if it supported it,
            -- but Theme helper resets color. So we must be careful.
            -- Actually Theme helpers reset color. I should probably copy the shadow logic locally for alpha control
            -- or assume standard helpers don't support alpha well without modification.
            -- Let's stick to standard opaque drawing if alpha is 1, and skip if 0.
            -- For fade in, we can hack it by ignoring alpha if we trust the text helper doesn't clear it?
            -- No, helper sets color.
            -- Let's just mock the fade by drawing only when visible enough, or better:
            -- Use love.graphics.setColor then print manually for full control.

            -- Helper for alpha text
            local function drawAlphaText(str, tx, ty, font, col)
                love.graphics.setFont(font)
                -- Shadow
                love.graphics.setColor(0, 0, 0, 0.5 * alpha)
                love.graphics.print(str, tx + 2, ty + 2)
                -- Text
                love.graphics.setColor(col[1], col[2], col[3], alpha)
                love.graphics.print(str, tx, ty)
            end

            local function drawAlphaTextRight(str, tx, ty, w, font, col)
                love.graphics.setFont(font)
                local width = font:getWidth(str)
                local finalX = tx + w - width
                -- Shadow
                love.graphics.setColor(0, 0, 0, 0.5 * alpha)
                love.graphics.print(str, finalX + 2, ty + 2)
                -- Text
                love.graphics.setColor(col[1], col[2], col[3], alpha)
                love.graphics.print(str, finalX, ty)
            end

            drawAlphaText("Level Reward", contentX, y, Theme.fonts.normal, Theme.colors.text)
            drawAlphaTextRight("+" .. tostring(self.baseReward), contentX, y, contentW, Theme.fonts.normal,
                Theme.colors.gold)
        end)

        -- 2. Bonus
        drawRow(2, rewardPanelY + 75, function(y, alpha)
            local function drawAlphaText(str, tx, ty, font, col)
                love.graphics.setFont(font)
                love.graphics.setColor(0, 0, 0, 0.5 * alpha)
                love.graphics.print(str, tx + 2, ty + 2)
                love.graphics.setColor(col[1], col[2], col[3], alpha)
                love.graphics.print(str, tx, ty)
            end
            local function drawAlphaTextRight(str, tx, ty, w, font, col)
                love.graphics.setFont(font)
                local width = font:getWidth(str)
                local finalX = tx + w - width
                love.graphics.setColor(0, 0, 0, 0.5 * alpha)
                love.graphics.print(str, finalX + 2, ty + 2)
                love.graphics.setColor(col[1], col[2], col[3], alpha)
                love.graphics.print(str, finalX, ty)
            end

            drawAlphaText("Hands remaining (" .. tostring(GameState.handsRemaining) .. ")", contentX, y,
                Theme.fonts.normal, Theme.colors.text)
            drawAlphaTextRight("+" .. tostring(self.unusedHandsBonus), contentX, y, contentW, Theme.fonts.normal,
                Theme.colors.gold)
        end)

        -- Divider (fades in with Total)
        drawRow(3, rewardPanelY + 105, function(y, alpha)
            love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], alpha)
            love.graphics.rectangle("fill", contentX, y, contentW, 2)
        end)

        -- 3. Total
        drawRow(3, rewardPanelY + 118, function(y, alpha)
            local function drawAlphaText(str, tx, ty, font, col)
                love.graphics.setFont(font)
                love.graphics.setColor(0, 0, 0, 0.5 * alpha)
                love.graphics.print(str, tx + 2, ty + 2)
                love.graphics.setColor(col[1], col[2], col[3], alpha)
                love.graphics.print(str, tx, ty)
            end
            local function drawAlphaTextRight(str, tx, ty, w, font, col)
                love.graphics.setFont(font)
                local width = font:getWidth(str)
                local finalX = tx + w - width

                -- Apply Pulse Scale if provided (global self.totalRewardScale)
                local scale = 1
                -- Check if this is the reward number (starts with +)
                if string.sub(str, 1, 1) == "+" then
                    scale = self.totalRewardScale
                end

                local cx = finalX + width / 2
                local cy = ty + font:getHeight() / 2

                love.graphics.push()
                love.graphics.translate(cx, cy)
                love.graphics.scale(scale, scale)
                love.graphics.translate(-cx, -cy)

                love.graphics.setColor(0, 0, 0, 0.5 * alpha)
                love.graphics.print(str, finalX + 2, ty + 2)
                love.graphics.setColor(col[1], col[2], col[3], alpha)
                love.graphics.print(str, finalX, ty)

                love.graphics.pop()
            end

            drawAlphaText("TOTAL", contentX, y, Theme.fonts.large, Theme.colors.text)
            drawAlphaTextRight("+" .. tostring(self.reward), contentX, y, contentW, Theme.fonts.large, Theme.colors.gold)
        end)
    else
        -- Loss message
        Theme:drawTextCenteredWithShadow("Goal not reached.", panelX, currentPanelY + 200, panelWidth, Theme.fonts.large,
            Theme.colors.textMuted)
        Theme:drawTextCenteredWithShadow("Try again!", panelX, currentPanelY + 250, panelWidth, Theme.fonts.large,
            Theme.colors.textMuted)
    end

    -- Action button (always visible? or fade in last?)
    -- Let's fade it in with the last element
    local btnAlpha = math.min(1, math.max(0, (self.timer - (self.staggerStart + self.staggerDelay * 2)) / 0.5))
    if btnAlpha > 0 then
        -- Hack: setting global color affects some parts of button depending on implementation
        -- Button class likely resets color. We might just let it slide up?
        -- For simplicity, let's just draw it. It has its own draw state.
        -- If we want to animate it, we might need a setOpacity method on Button or just let it be there.
        -- Let's just draw it normally for now, maybe it's fine if it waits?
        -- Or better, slide it up with the panel!
        -- The button y is fixed in init. We should update its y in draw or update based on panel position?
        -- No, the button is outside the panel in the original layout.
        -- Let's make the button also slide in from bottom or appear.
        -- Let's keep it simple: Button slides in from bottom while panel slides from top?
        -- Or just static at bottom?
        -- The request was "animate the reward rows in in a staggered way and the total as last row."
        -- It didn't explicitly ask for button animation, but "whole cashout panel" implies everything.
        -- I'll stick to the original button position but maybe fade it in.
        self.actionButton:draw()
    end

    -- Draw info panel (left side)
    if self.infoPanel then
        self.infoPanel:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ResultState:mousepressed(x, y, button)
    -- Only allow interaction after animation settles largely?
    if self.timer < 0.5 then return end

    self.actionButton:mousepressed(x, y, button)
    if self.infoPanel then
        self.infoPanel:mousepressed(x, y, button)
    end
end

function ResultState:mousereleased(x, y, button)
    self.actionButton:mousereleased(x, y, button)
    if self.infoPanel then
        self.infoPanel:mousereleased(x, y, button)
    end
end

function ResultState:keypressed(key)
    if key == "space" or key == "return" then
        if self.timer > 0.5 then
            self:onActionButtonClick()
        else
            -- Skip animation?
            self.timer = 10
        end
    end
end

return ResultState
