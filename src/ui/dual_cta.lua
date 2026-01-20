-- Dual CTA component
-- Two action buttons: "Hand spielen" (play hand) and "Würfeln" (roll)

local Theme = require("src.ui.theme")
local Button = require("src.ui.button")

local DualCta = {}
DualCta.__index = DualCta

function DualCta.new(config)
    local self = setmetatable({}, DualCta)

    -- Position and sizing
    self.centerX = config.centerX or Theme.layout.centerX
    self.centerWidth = config.centerWidth or Theme.layout.centerWidth
    self.y = config.y or Theme.layout.ctaY
    self.buttonWidth = config.buttonWidth or Theme.layout.ctaWidth
    self.buttonHeight = config.buttonHeight or Theme.layout.ctaHeight
    self.spacing = config.spacing or Theme.layout.ctaSpacing

    -- Callbacks
    self.onPlayHand = config.onPlayHand or function() end
    self.onRoll = config.onRoll or function() end
    self.canPlayHand = config.canPlayHand or function() return false end
    self.canRoll = config.canRoll or function() return true end

    -- Calculate button positions (centered in the center area)
    local totalWidth = self.buttonWidth * 2 + self.spacing
    local startX = self.centerX + (self.centerWidth - totalWidth) / 2

    -- Create "Hand spielen" button (cyan)
    self.playButton = Button.new({
        x = startX,
        y = self.y,
        width = self.buttonWidth,
        height = self.buttonHeight,
        text = "Hand spielen",
        bgColor = Theme.colors.cyan,
        textColor = Theme.colors.textDark,
        hoverBgColor = { Theme.colors.cyan[1] * 0.9, Theme.colors.cyan[2] * 0.9, Theme.colors.cyan[3] * 0.9, 1 },
        disabledBgColor = Theme.colors.surface,
        disabledTextColor = Theme.colors.textMuted,
        font = Theme.fonts.large,
        onClick = function()
            self.onPlayHand()
        end,
    })

    -- Create "Würfeln" button (purple)
    self.rollButton = Button.new({
        x = startX + self.buttonWidth + self.spacing,
        y = self.y,
        width = self.buttonWidth,
        height = self.buttonHeight,
        text = "Wurfeln",
        bgColor = Theme.colors.buttonPurple,
        textColor = Theme.colors.text,
        hoverBgColor = { Theme.colors.buttonPurple[1] * 1.1, Theme.colors.buttonPurple[2] * 1.1, Theme.colors.buttonPurple[3] * 1.1, 1 },
        disabledBgColor = Theme.colors.surface,
        disabledTextColor = Theme.colors.textMuted,
        font = Theme.fonts.large,
        onClick = function()
            self.onRoll()
        end,
    })

    return self
end

function DualCta:update(dt)
    -- Update button enabled states
    self.playButton:setEnabled(self.canPlayHand())
    self.rollButton:setEnabled(self.canRoll())

    -- Update hover states
    self.playButton:update(dt)
    self.rollButton:update(dt)
end

function DualCta:mousepressed(x, y, button)
    if self.playButton:mousepressed(x, y, button) then
        return true
    end
    if self.rollButton:mousepressed(x, y, button) then
        return true
    end
    return false
end

function DualCta:mousereleased(x, y, button)
    if self.playButton:mousereleased(x, y, button) then
        return true
    end
    if self.rollButton:mousereleased(x, y, button) then
        return true
    end
    return false
end

function DualCta:draw()
    self.playButton:draw()
    self.rollButton:draw()
end

return DualCta
