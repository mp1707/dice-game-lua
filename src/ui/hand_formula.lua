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
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.textMuted)
    local levelLabel = "LV" .. tostring(self.level) .. " " .. string.upper(self.handName)
    love.graphics.print(levelLabel, x, y)

    y = y + 30

    -- Draw formula: [chips] x [mult]
    local chipsText = tostring(self.chips)
    local multText = tostring(self.mult)

    -- Calculate box widths based on text
    love.graphics.setFont(Theme.fonts.large)
    local chipsWidth = math.max(self.boxWidth, Theme.fonts.large:getWidth(chipsText) + 24)
    local multWidth = math.max(self.boxWidth, Theme.fonts.large:getWidth(multText) + 24)
    local boxHeight = self.boxHeight

    -- Chips box (blue)
    love.graphics.setColor(Theme.colors.upgradePoints)
    love.graphics.rectangle("fill", x, y, chipsWidth, boxHeight, self.boxRadius)

    -- Chips text
    love.graphics.setColor(Theme.colors.text)
    local chipsTextWidth = Theme.fonts.large:getWidth(chipsText)
    local chipsTextX = x + (chipsWidth - chipsTextWidth) / 2
    local textY = y + (boxHeight - Theme.fonts.large:getHeight()) / 2
    love.graphics.print(chipsText, math.floor(chipsTextX), math.floor(textY))

    -- "x" symbol
    local xSymbolX = x + chipsWidth + 12
    love.graphics.setFont(Theme.fonts.large)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("x", xSymbolX, textY)
    local xWidth = Theme.fonts.large:getWidth("x")

    -- Mult box (red)
    local multBoxX = xSymbolX + xWidth + 12
    love.graphics.setColor(Theme.colors.upgradeMult)
    love.graphics.rectangle("fill", multBoxX, y, multWidth, boxHeight, self.boxRadius)

    -- Mult text
    love.graphics.setColor(Theme.colors.text)
    local multTextWidth = Theme.fonts.large:getWidth(multText)
    local multTextX = multBoxX + (multWidth - multTextWidth) / 2
    love.graphics.print(multText, math.floor(multTextX), math.floor(textY))

    love.graphics.setColor(1, 1, 1, 1)
end

return HandFormula
