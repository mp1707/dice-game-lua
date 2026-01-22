-- Hand Card component
-- Displays a single selectable hand option with dice icons, level, and name

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local HandCard = {}
HandCard.__index = HandCard

function HandCard.new(config)
    local self = setmetatable({}, HandCard)

    self.x = config.x or 0
    self.y = config.y or 0
    self.width = config.width or Theme.layout.handCardWidth
    self.height = config.height or Theme.layout.handCardHeight

    -- Hand data
    self.handId = config.handId
    self.handName = config.handName or ""
    self.level = config.level or 1
    self.scoringDice = config.scoringDice or {} -- Array of dice values to display

    -- State
    self.isSelected = false
    self.isHovered = false

    -- Callback
    self.onClick = config.onClick

    return self
end

function HandCard:update(dt)
    -- Check hover state
    local mx, my = love.mouse.getPosition()
    -- Convert to game coordinates using Scaling if available
    local Scaling = require("src.core.scaling")
    mx, my = Scaling.screenToGame(mx, my)

    self.isHovered = self:containsPoint(mx, my)
end

function HandCard:draw()
    local nineSlice = NineSlice.getInstance()

    -- Determine background color based on state
    local bgColor = Theme.colors.surface
    if self.isSelected then
        bgColor = Theme.colors.surface2
    elseif self.isHovered then
        bgColor = Theme.colors.surfaceHighlight
    end

    -- Elevation offset
    local yOffset = 0

    -- Draw shadow if selected (match button style)
    if self.isSelected then
        yOffset = -2 -- Slightly elevate
        local shadowColor = { 0, 0, 0, 0.4 }
        -- Use theme scale for shadow to match button shadow exactly
        nineSlice:draw(self.x, self.y + 4, self.width, self.height, shadowColor, Theme.nineSlice.borderScale)
    end

    -- Draw background panel
    nineSlice:draw(self.x, self.y + yOffset, self.width, self.height, bgColor, Theme.nineSlice.borderScale)

    local padding = 12

    -- Draw small dice faces (top-left)
    local diceX = self.x + padding
    local diceY = self.y + padding + yOffset
    local diceSize = Theme.layout.handCardDiceSize
    local diceSpacing = 4

    for i, value in ipairs(self.scoringDice) do
        local sheet = Theme.diceSpritesheet
        if sheet then
            local quad = sheet:getQuad(value)
            local image = sheet:getImage()
            local sw, sh = sheet:getSpriteSize()

            -- Calculate scale if not already done
            local scale = diceSize / math.max(sw, sh)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image, quad, diceX, diceY, 0, scale, scale)
            diceX = diceX + diceSize + diceSpacing
        end
    end

    -- Draw level indicator (top-right)
    local levelText = "LV" .. self.level
    Theme:drawTextRightWithShadow(
        levelText,
        self.x,
        self.y + padding + yOffset,
        self.width - padding,
        Theme.fonts.normal,
        Theme.colors.textMuted
    )

    -- Draw hand name (bottom-left, large text)
    local nameY = self.y + self.height - padding - Theme.fonts.large:getHeight() + yOffset
    Theme:drawTextWithShadow(
        self.handName,
        self.x + padding,
        nameY,
        Theme.fonts.large,
        Theme.colors.text
    )
end

function HandCard:containsPoint(px, py)
    if not px or not py then return false end
    return px >= self.x and px <= self.x + self.width and
        py >= self.y and py <= self.y + self.height
end

function HandCard:mousepressed(x, y, button)
    if button == 1 and self:containsPoint(x, y) then
        if self.onClick then
            self.onClick(self)
        end
        return true
    end
    return false
end

function HandCard:setSelected(selected)
    self.isSelected = selected
end

function HandCard:setPosition(x, y)
    self.x = x
    self.y = y
end

return HandCard
