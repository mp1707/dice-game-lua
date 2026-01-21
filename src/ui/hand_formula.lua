-- Hand Formula component
-- Balatro-style display: "LV1 HANDNAME" + [chips] x [mult]

local Theme = require("src.ui.theme")

local HandFormula = {}
HandFormula.__index = HandFormula

function HandFormula.new(config)
    local self = setmetatable({}, HandFormula)

    self.x = config.x or 0
    self.y = config.y or 0
    self.width = config.width or 300

    -- Formula data
    self.handName = nil
    self.level = 1
    self.chips = 0
    self.mult = 1
    self.visible = false

    -- Box dimensions
    self.boxWidth = 70
    self.boxHeight = 50
    self.boxRadius = 8

    return self
end

function HandFormula:set(handName, level, chips, mult)
    self.handName = handName
    self.level = level or 1
    self.chips = chips or 0
    self.mult = mult or 1
    self.visible = true
end

function HandFormula:clear()
    self.handName = nil
    self.visible = false
end

function HandFormula:getHeight()
    if not self.visible then return 0 end
    return 80 -- label + boxes
end

function HandFormula:draw()
    if not self.visible or not self.handName then return end

    local x = self.x
    local y = self.y

    -- Draw hand name with level (e.g., "LV1 VIERER")
    local levelLabel = "LV" .. tostring(self.level) .. " " .. string.upper(self.handName)
    Theme:drawTextWithShadow(levelLabel, x, y, Theme.fonts.normal, Theme.colors.textMuted)

    y = y + 30

    -- Draw formula: [chips] x [mult]
    local chipsText = tostring(self.chips)
    local multText = tostring(self.mult)

    -- Calculate box widths based on text
    love.graphics.setFont(Theme.fonts.large)

    -- Calculate available width for boxes
    -- Space structure: [Box 1] (12px) [x] (12px) [Box 2]
    local xWidth = Theme.fonts.large:getWidth("x")
    local spacing = 12
    local totalFixedSpace = (spacing * 2) + xWidth

    -- Calculate dynamic width (split remaining space equally)
    local dynamicBoxWidth = (self.width - totalFixedSpace) / 2

    -- Ensure we don't shrink below minimum or text size if the panel is somehow very narrow
    -- But prioritize filling the space as requested
    local chipsRequired = Theme.fonts.large:getWidth(chipsText) + 24
    local multRequired = Theme.fonts.large:getWidth(multText) + 24

    local chipsWidth = math.max(self.boxWidth, dynamicBoxWidth)
    local multWidth = math.max(self.boxWidth, dynamicBoxWidth)

    -- Make them equal size (the larger of the two required or the dynamic width)
    -- User requested "both the same size" and "grow to use horizontal space"
    local finalBoxWidth = math.max(chipsWidth, multWidth)

    chipsWidth = finalBoxWidth
    multWidth = finalBoxWidth

    local boxHeight = self.boxHeight

    -- Chips box (blue)
    love.graphics.setColor(Theme.colors.upgradePoints)
    love.graphics.rectangle("fill", x, y, chipsWidth, boxHeight, self.boxRadius)

    -- Chips text (centered in box)
    local textY = y + (boxHeight - Theme.fonts.large:getHeight()) / 2
    Theme:drawTextCenteredWithShadow(chipsText, x, textY, chipsWidth, Theme.fonts.large, Theme.colors.text)

    -- "x" symbol
    local xSymbolX = x + chipsWidth + 12
    Theme:drawTextWithShadow("x", xSymbolX, textY, Theme.fonts.large, Theme.colors.textMuted)

    -- Mult box (red)
    local multBoxX = xSymbolX + xWidth + 12
    love.graphics.setColor(Theme.colors.upgradeMult)
    love.graphics.rectangle("fill", multBoxX, y, multWidth, boxHeight, self.boxRadius)

    -- Mult text (centered in box)
    Theme:drawTextCenteredWithShadow(multText, multBoxX, textY, multWidth, Theme.fonts.large, Theme.colors.text)

    love.graphics.setColor(1, 1, 1, 1)
end

return HandFormula
