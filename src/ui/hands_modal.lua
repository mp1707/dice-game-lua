-- Hands Overview Modal
-- Slides in from top, shows all 12 hands with levels and formulas

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Button = require("src.ui.button")
local Hands = require("src.game.hands")
local Juice = require("src.ui.juice")
local Sound = require("src.core.sound")

local HandsModal = {}
HandsModal.__index = HandsModal

function HandsModal.new(config)
    local self = setmetatable({}, HandsModal)

    -- Modal dimensions
    self.width = 700
    self.height = 900

    -- Center horizontally
    self.x = (Theme.screen.width - self.width) / 2

    -- Target Y when open (centered vertically)
    self.openY = (Theme.screen.height - self.height) / 2

    -- Start above screen
    self.y = -self.height
    self.targetY = -self.height
    self.velocity = 0

    -- State
    self.isOpen = false

    -- Padding and spacing
    self.padding = 24
    self.rowHeight = 54
    self.rowGap = 6
    self.headerHeight = 50

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    -- Close button
    local buttonWidth = 180
    local buttonHeight = 50
    self.closeButton = Button.new({
        x = self.x + (self.width - buttonWidth) / 2,
        y = self.y + self.height - buttonHeight - self.padding,
        width = buttonWidth,
        height = buttonHeight,
        text = "Close",
        bgColor = Theme.colors.buttonGray,
        textColor = Theme.colors.text,
        font = Theme.fonts.normal,
        onClick = function()
            self:close()
        end,
    })

    -- Callbacks
    self.onClose = config.onClose

    return self
end

function HandsModal:open()
    if self.isOpen then return end
    self.isOpen = true
    self.targetY = self.openY
    Sound:play("bling")
end

function HandsModal:close()
    if not self.isOpen then return end
    self.isOpen = false
    self.targetY = -self.height
    if self.onClose then
        self.onClose()
    end
end

function HandsModal:update(dt)
    -- Spring animation for Y position
    self.y, self.velocity = Juice.updateSpring(
        self.y,
        self.targetY,
        self.velocity,
        400, -- stiffness
        30,  -- damping
        dt
    )

    -- Update close button position
    self.closeButton.y = self.y + self.height - self.closeButton.height - self.padding

    -- Update button hover state
    if self.isOpen or self.y > -self.height + 10 then
        self.closeButton:update(dt)
    end
end

function HandsModal:draw()
    -- Don't draw if fully off screen
    if self.y <= -self.height then return end

    -- Semi-transparent backdrop
    if self.isOpen or self.y > -self.height + 10 then
        local backdropAlpha = math.min(0.6, (self.y + self.height) / self.height * 0.6)
        love.graphics.setColor(0, 0, 0, backdropAlpha)
        love.graphics.rectangle("fill", 0, 0, Theme.screen.width, Theme.screen.height)
    end

    -- Main modal panel
    self.nineSlice:draw(
        self.x,
        self.y,
        self.width,
        self.height,
        Theme.colors.panelDark,
        Theme.nineSlice.borderScale
    )

    -- Header
    local headerY = self.y + self.padding
    Theme:drawTextCenteredWithShadow(
        "ALL HANDS",
        self.x,
        headerY,
        self.width,
        Theme.fonts.large,
        Theme.colors.gold
    )

    -- Content area
    local contentX = self.x + self.padding
    local contentY = headerY + self.headerHeight
    local contentWidth = self.width - self.padding * 2

    -- Draw all 12 hands
    for i, hand in ipairs(Hands.definitions) do
        local rowY = contentY + (i - 1) * (self.rowHeight + self.rowGap)
        self:drawHandRow(contentX, rowY, contentWidth, self.rowHeight, hand)
    end

    -- Close button
    self.closeButton:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function HandsModal:drawHandRow(x, y, width, height, hand)
    -- Row background
    self.nineSlice:draw(
        x,
        y,
        width,
        height,
        Theme.colors.surface,
        Theme.nineSlice.borderScale
    )

    local innerPadding = 12
    local textY = y + (height - Theme.fonts.normal:getHeight()) / 2

    -- Hand name (left aligned)
    local nameX = x + innerPadding
    Theme:drawTextWithShadow(
        hand.name,
        nameX,
        textY,
        Theme.fonts.normal,
        Theme.colors.text
    )

    -- Level badge (gold, after name)
    local levelText = "Lv." .. tostring(hand.level)
    local nameWidth = Theme.fonts.normal:getWidth(hand.name)
    local levelX = nameX + nameWidth + 16
    Theme:drawTextWithShadow(
        levelText,
        levelX,
        textY,
        Theme.fonts.small,
        Theme.colors.gold
    )

    -- Formula boxes (right aligned)
    local formulaBoxHeight = 36
    local formulaBoxWidth = 60
    local xSymbolWidth = Theme.fonts.normal:getWidth("x")
    local spacing = 8
    local formulaWidth = formulaBoxWidth * 2 + xSymbolWidth + spacing * 2

    local formulaX = x + width - formulaWidth - innerPadding
    local formulaY = y + (height - formulaBoxHeight) / 2

    -- Blue box (basePoints)
    love.graphics.setColor(Theme.colors.upgradePoints)
    love.graphics.rectangle("fill", formulaX, formulaY, formulaBoxWidth, formulaBoxHeight, 6)

    local boxTextY = formulaY + (formulaBoxHeight - Theme.fonts.normal:getHeight()) / 2
    local baseText = tostring(hand.basePoints)
    local baseTextWidth = Theme.fonts.normal:getWidth(baseText)
    local baseTextX = formulaX + (formulaBoxWidth - baseTextWidth) / 2

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(Theme.fonts.normal)
    -- Draw text with shadow manually for colored box
    love.graphics.setColor(Theme.colors.textShadow)
    love.graphics.print(baseText, math.floor(baseTextX + 2), math.floor(boxTextY + 2))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(baseText, math.floor(baseTextX), math.floor(boxTextY))

    -- "x" symbol
    local xX = formulaX + formulaBoxWidth + spacing
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("x", xX, boxTextY)

    -- Red box (mult)
    local multBoxX = xX + xSymbolWidth + spacing
    love.graphics.setColor(Theme.colors.upgradeMult)
    love.graphics.rectangle("fill", multBoxX, formulaY, formulaBoxWidth, formulaBoxHeight, 6)

    local multText = tostring(hand.mult)
    local multTextWidth = Theme.fonts.normal:getWidth(multText)
    local multTextX = multBoxX + (formulaBoxWidth - multTextWidth) / 2

    love.graphics.setColor(Theme.colors.textShadow)
    love.graphics.print(multText, math.floor(multTextX + 2), math.floor(boxTextY + 2))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(multText, math.floor(multTextX), math.floor(boxTextY))
end

function HandsModal:mousepressed(x, y, button)
    if not self.isOpen then return false end

    -- Check close button
    if self.closeButton:mousepressed(x, y, button) then
        return true
    end

    -- Click outside modal to close
    if x < self.x or x > self.x + self.width or
       y < self.y or y > self.y + self.height then
        self:close()
        return true
    end

    -- Absorb clicks inside modal
    return true
end

function HandsModal:mousereleased(x, y, button)
    if not self.isOpen and self.y <= -self.height + 10 then return false end

    if self.closeButton:mousereleased(x, y, button) then
        return true
    end

    return false
end

function HandsModal:keypressed(key)
    if not self.isOpen then return false end

    if key == "escape" then
        self:close()
        return true
    end

    return false
end

return HandsModal
