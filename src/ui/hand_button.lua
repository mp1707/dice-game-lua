-- Hand button component for Balatro-style layout
-- Displays hand type horizontally: Icon | Name | Score

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local HandButton = {}
HandButton.__index = HandButton

-- Icon mapping
local IconMapping = {
    ones = "1die.png",
    twos = "2die.png",
    threes = "3die.png",
    fours = "4die.png",
    fives = "5die.png",
    sixes = "6die.png",
    threeOfKind = "3x.png",
    fourOfKind = "4x.png",
    yahtzee = "5x.png",
    fullHouse = "fullHouse.png",
    smallStraight = "smStraight.png",
    largeStraight = "lgStraight.png",
}

-- Cache for loaded images
local IconCache = {}

function HandButton.new(config)
    local self = setmetatable({}, HandButton)

    self.x = config.x or 0
    self.y = config.y or 0
    self.width = config.width or 120
    self.height = config.height or 50
    self.handDef = config.handDef
    self.onClick = config.onClick or function() end

    -- Load icon if not cached
    local iconName = IconMapping[self.handDef.id]
    if iconName then
        if not IconCache[iconName] then
            local path = "assets/icons/hands/" .. iconName
            local success, img = pcall(love.graphics.newImage, path)
            if success then
                img:setFilter("nearest", "nearest")
                IconCache[iconName] = img
            else
                print("Failed to load icon: " .. path)
            end
        end
        self.icon = IconCache[iconName]
    end

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
    -- Use global screenToGame if available for proper scaling
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end
    -- If mouse is outside viewport (nil values), don't hover
    if mx == nil or my == nil then
        self.isHovered = false
        return
    end
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
        bgColor = Theme.colors.surface2
    else
        bgColor = Theme.colors.surface
    end

    -- Draw background with 0.5 scale for appropriate borders
    self.nineSlice:draw(self.x, self.y, self.width, self.height, bgColor, 0.5)

    -- Draw border for valid/selected hands
    if selected then
        love.graphics.setColor(Theme.colors.textDark)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.x + 2, self.y + 2, self.width - 4, self.height - 4, 6)
    elseif hasRolled and valid and score > 0 and not used then
        love.graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.x + 2, self.y + 2, self.width - 4, self.height - 4, 6)
    end

    -- Horizontal layout: Icon | Name | Score
    local contentY = self.y + (self.height - 20) / 2

    -- Draw Icon (left side)
    local iconX = self.x + 8
    if self.icon then
        love.graphics.setColor(1, 1, 1, 1)
        if used then
            love.graphics.setColor(1, 1, 1, 0.4)
        elseif selected then
            love.graphics.setColor(Theme.colors.textDark)
        end

        local iw, ih = self.icon:getDimensions()
        local targetSize = 20
        local scale = targetSize / math.max(iw, ih)
        local iy = self.y + (self.height - ih * scale) / 2
        love.graphics.draw(self.icon, iconX, iy, 0, scale, scale)
    end

    -- Draw hand name (center)
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
    love.graphics.print(name, self.x + 32, contentY + 2)

    -- Draw score (right side) if rolled and valid
    if hasRolled and score > 0 and not used then
        local scoreText = tostring(score)
        local scoreWidth = Theme.fonts.small:getWidth(scoreText)

        if selected then
            love.graphics.setColor(Theme.colors.textDark)
        else
            love.graphics.setColor(Theme.colors.gold)
        end
        love.graphics.print(scoreText, self.x + self.width - scoreWidth - 8, contentY + 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return HandButton
