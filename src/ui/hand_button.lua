-- Hand button component
-- Displays a Yahtzee hand type with score preview and usage state

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
    self.width = config.width or 58
    self.height = config.height or 65
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

    -- Draw background with 0.33 scale for thinner borders
    self.nineSlice:draw(self.x, self.y, self.width, self.height, bgColor, 0.33)

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

    -- Draw Icon
    if self.icon then
        love.graphics.setColor(1, 1, 1, 1)
        if used then
             love.graphics.setColor(1, 1, 1, 0.5) -- Dim used icons
        elseif selected then
             love.graphics.setColor(0, 0, 0, 1) -- Black icon on cyan selection? Or just keep white?
             -- Screenshot shows white icons usually on dark. If background is cyan (bright), maybe dark icon is better.
             -- Theme.colors.textDark is dark.
             -- Let's stick to valid/active logic.
             love.graphics.setColor(Theme.colors.textDark)
        end
        
        -- Fit icon to center
        local iw, ih = self.icon:getDimensions()
        local targetSize = 24 -- Target size for icon
        local scale = targetSize / math.max(iw, ih)
        
        local ix = self.x + (self.width - iw * scale) / 2
        local iy = self.y + (self.height - ih * scale) / 2 - 4 -- Slight nudge up for text space
        
        love.graphics.draw(self.icon, ix, iy, 0, scale, scale)
    else
        -- Fallback if no icon
    end

    -- Draw hand name (Moved to bottom)
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
    love.graphics.print(name, math.floor(self.x + (self.width - nameWidth) / 2), self.y + self.height - 14)

    -- Draw LV indicator (Top Right) or Score if relevant?
    -- Screenshot has "LV 1" in top left/right.
    -- We'll put Score there if rolled?
    -- For now just minimal changes to match "Use proper icons".
    
    -- Draw Level/Score small in top right corner if needed, or if we want to show potential points.
    -- The user requested updating icons and scaling.
    -- I will remove the big center score rendering as the icon replaces it.
    
    love.graphics.setColor(1, 1, 1, 1)
end

return HandButton
