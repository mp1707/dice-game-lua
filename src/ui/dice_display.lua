-- Dice display component
-- Shows a single die with value and lock state, clickable to toggle lock

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local DiceDisplay = {}
DiceDisplay.__index = DiceDisplay

function DiceDisplay.new(config)
    local self = setmetatable({}, DiceDisplay)

    self.x = config.x or 0
    self.y = config.y or 0
    self.size = config.size or 56
    self.index = config.index or 1
    self.onClick = config.onClick or function() end

    -- Reference to get dice data
    self.getDiceData = config.getDiceData or function()
        return { value = 1, locked = false }
    end

    -- Animation state
    self.isAnimating = false
    self.animValue = 1
    self.animTimer = 0
    self.animDuration = 0.5

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    return self
end

function DiceDisplay:setPosition(x, y)
    self.x = x
    self.y = y
end

function DiceDisplay:containsPoint(px, py)
    return px >= self.x and px < self.x + self.size and
        py >= self.y and py < self.y + self.size
end

function DiceDisplay:startRollAnimation(duration)
    self.isAnimating = true
    self.animTimer = 0
    self.animDuration = duration or 0.5
end

function DiceDisplay:stopAnimation()
    self.isAnimating = false
end

function DiceDisplay:update(dt)
    if self.isAnimating then
        self.animTimer = self.animTimer + dt
        -- Rapidly change display value during animation
        self.animValue = math.random(1, 6)

        if self.animTimer >= self.animDuration then
            self.isAnimating = false
        end
    end
end

function DiceDisplay:mousepressed(x, y, button)
    if button == 1 and self:containsPoint(x, y) then
        self.onClick(self.index)
        return true
    end
    return false
end

function DiceDisplay:draw()
    local data = self.getDiceData()
    local value = self.isAnimating and self.animValue or data.value
    local locked = data.locked

    -- Background color based on lock state
    local bgColor = locked and Theme.colors.cyan or Theme.colors.surface2

    -- Draw background
    self.nineSlice:draw(self.x, self.y, self.size, self.size, bgColor, Theme.nineSlice.borderScale)

    -- Draw border if locked
    if locked then
        love.graphics.setColor(Theme.colors.text)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.x + 2, self.y + 2, self.size - 4, self.size - 4, 8)
    end

    -- Draw value
    local textColor = locked and Theme.colors.textDark or Theme.colors.text
    love.graphics.setColor(textColor)
    love.graphics.setFont(Theme.fonts.huge)

    local text = tostring(value)
    local textWidth = Theme.fonts.huge:getWidth(text)
    local textHeight = Theme.fonts.huge:getHeight()
    local textX = self.x + (self.size - textWidth) / 2
    local textY = self.y + (self.size - textHeight) / 2

    love.graphics.print(text, math.floor(textX), math.floor(textY))

    -- Draw lock indicator text
    if locked then
        love.graphics.setFont(Theme.fonts.small)
        love.graphics.setColor(Theme.colors.textDark)
        local lockText = "LOCK"
        local lockWidth = Theme.fonts.small:getWidth(lockText)
        love.graphics.print(lockText, self.x + (self.size - lockWidth) / 2, self.y + self.size - 16)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return DiceDisplay
