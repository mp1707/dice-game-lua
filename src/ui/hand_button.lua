-- Hand button component
-- Displays a Yahtzee hand type with score preview and usage state

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local HandButton = {}
HandButton.__index = HandButton

function HandButton.new(config)
    local self = setmetatable({}, HandButton)

    self.x = config.x or 0
    self.y = config.y or 0
    self.width = config.width or 58
    self.height = config.height or 65
    self.handDef = config.handDef
    self.onClick = config.onClick or function() end

    -- State callbacks
    self.isUsed = config.isUsed or function() return false end
    self.isSelected = config.isSelected or function() return false end
    self.getScore = config.getScore or function() return 0 end
    self.isValidHand = config.isValidHand or function() return true end
    self.hasRolled = config.hasRolled or function() return false end

    -- Interaction state
    self.isHovered = false
    self.isPressed = false

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    return self
end

function HandButton:setPosition(x, y)
    self.x = x
    self.y = y
end

function HandButton:containsPoint(px, py)
    return px >= self.x and px < self.x + self.width and
           py >= self.y and py < self.y + self.height
end

function HandButton:update(dt)
    local mx, my = love.mouse.getPosition()
    local canInteract = not self.isUsed() and self.hasRolled()
    self.isHovered = self:containsPoint(mx, my) and canInteract
end

function HandButton:mousepressed(x, y, button)
    if button == 1 and self:containsPoint(x, y) then
        local canInteract = not self.isUsed() and self.hasRolled()
        if canInteract then
            self.isPressed = true
            return true
        end
    end
    return false
end

function HandButton:mousereleased(x, y, button)
    if button == 1 and self.isPressed then
        self.isPressed = false
        if self:containsPoint(x, y) and not self.isUsed() then
            self.onClick(self.handDef.id)
            return true
        end
    end
    return false
end

function HandButton:draw()
    local used = self.isUsed()
    local selected = self.isSelected()
    local valid = self.isValidHand()
    local score = self.getScore()
    local hasRolled = self.hasRolled()

    -- Determine background color
    local bgColor
    if selected then
        bgColor = Theme.colors.cyan
    elseif used then
        bgColor = Theme.colors.surface
    elseif self.isPressed then
        bgColor = Theme.colors.surface
    elseif self.isHovered then
        bgColor = Theme.colors.surfaceHighlight
    elseif hasRolled and valid and score > 0 then
        -- Valid hand with score - slight highlight
        bgColor = Theme.colors.surface2
    else
        bgColor = Theme.colors.surface
    end

    -- Draw background
    self.nineSlice:draw(self.x, self.y, self.width, self.height, bgColor)

    -- Draw border for valid/selected hands
    if selected then
        love.graphics.setColor(Theme.colors.textDark)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.x + 2, self.y + 2, self.width - 4, self.height - 4, 8)
    elseif hasRolled and valid and score > 0 and not used then
        love.graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.x + 2, self.y + 2, self.width - 4, self.height - 4, 8)
    end

    -- Draw hand name
    local textColor
    if selected then
        textColor = Theme.colors.textDark
    elseif used then
        textColor = Theme.colors.textMuted
    else
        textColor = Theme.colors.text
    end

    love.graphics.setColor(textColor)
    love.graphics.setFont(Theme.fonts.small)

    local name = self.handDef.shortName
    local nameWidth = Theme.fonts.small:getWidth(name)
    love.graphics.print(name, math.floor(self.x + (self.width - nameWidth) / 2), self.y + 6)

    -- Draw score or state indicator
    if used then
        -- Show checkmark or "USED"
        love.graphics.setColor(Theme.colors.gold)
        love.graphics.setFont(Theme.fonts.normal)
        local usedText = "OK"
        local usedWidth = Theme.fonts.normal:getWidth(usedText)
        love.graphics.print(usedText, math.floor(self.x + (self.width - usedWidth) / 2), self.y + 24)
    elseif hasRolled then
        -- Show potential score
        local scoreText = tostring(score)
        local scoreColor
        if selected then
            scoreColor = Theme.colors.textDark
        elseif valid and score > 0 then
            scoreColor = Theme.colors.gold
        else
            scoreColor = Theme.colors.textMuted
        end

        love.graphics.setColor(scoreColor)
        love.graphics.setFont(Theme.fonts.large)
        local scoreWidth = Theme.fonts.large:getWidth(scoreText)
        love.graphics.print(scoreText, math.floor(self.x + (self.width - scoreWidth) / 2), self.y + 24)

        -- Draw multiplier indicator
        love.graphics.setFont(Theme.fonts.small)
        local multText = self.handDef.mult .. "x"
        local multWidth = Theme.fonts.small:getWidth(multText)
        local multColor = selected and Theme.colors.textDark or Theme.colors.textMuted
        love.graphics.setColor(multColor)
        love.graphics.print(multText, math.floor(self.x + (self.width - multWidth) / 2), self.y + self.height - 18)
    else
        -- Not rolled yet - show dash
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.setFont(Theme.fonts.large)
        local dashText = "-"
        local dashWidth = Theme.fonts.large:getWidth(dashText)
        love.graphics.print(dashText, math.floor(self.x + (self.width - dashWidth) / 2), self.y + 24)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return HandButton
