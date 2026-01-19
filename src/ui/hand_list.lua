-- Hand List component
-- Single-column vertical list for hand selection with icons

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Hands = require("src.game.hands")

local HandList = {}
HandList.__index = HandList

-- Map hand IDs to icon filenames
local iconMap = {
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

function HandList.new(config)
    local self = setmetatable({}, HandList)

    self.x = config.x or Theme.layout.leftPanelX
    self.y = config.y or Theme.layout.leftPanelY
    self.width = config.width or Theme.layout.leftPanelWidth
    self.height = config.height or Theme.layout.leftPanelHeight
    self.padding = config.padding or Theme.layout.handListPadding
    self.itemHeight = config.itemHeight or Theme.layout.handListItemHeight
    self.itemSpacing = config.itemSpacing or Theme.layout.handListItemSpacing

    -- Icon settings
    self.iconSize = 52  -- Size to display icons at (nice big icons)

    -- Callbacks
    self.isUsed = config.isUsed or function(handId) return false end
    self.isSelected = config.isSelected or function(handId) return false end
    self.getScore = config.getScore or function(handId) return 0 end
    self.isValidHand = config.isValidHand or function(handId) return false end
    self.hasRolled = config.hasRolled or function() return false end
    self.onClick = config.onClick or function(handId) end

    -- Internal state
    self.hoveredHandId = nil
    self.nineSlice = NineSlice.getInstance()

    -- Load icons
    self.icons = {}
    for handId, filename in pairs(iconMap) do
        local path = "assets/icons/hands/" .. filename
        local success, img = pcall(love.graphics.newImage, path)
        if success then
            img:setFilter("nearest", "nearest")
            self.icons[handId] = img
        end
    end

    -- Pre-calculate item positions
    self.items = {}
    local startY = self.y + self.padding + 40 -- space for title
    for i, handDef in ipairs(Hands.definitions) do
        self.items[i] = {
            handDef = handDef,
            x = self.x + self.padding,
            y = startY + (i - 1) * (self.itemHeight + self.itemSpacing),
            width = self.width - self.padding * 2,
            height = self.itemHeight,
        }
    end

    return self
end

function HandList:getItemAtPoint(px, py)
    for _, item in ipairs(self.items) do
        if px >= item.x and px < item.x + item.width and
            py >= item.y and py < item.y + item.height then
            return item
        end
    end
    return nil
end

function HandList:update(dt)
    -- Hover state is updated in mousemoved
end

function HandList:mousemoved(x, y)
    local item = self:getItemAtPoint(x, y)
    if item then
        self.hoveredHandId = item.handDef.id
    else
        self.hoveredHandId = nil
    end
end

function HandList:mousepressed(x, y, button)
    if button ~= 1 then return false end

    local item = self:getItemAtPoint(x, y)
    if item then
        local handId = item.handDef.id
        -- Only allow click if not used and rolled
        if not self.isUsed(handId) and self.hasRolled() then
            self.onClick(handId)
            return true
        end
    end
    return false
end

function HandList:mousereleased(x, y, button)
    -- No release handling needed
end

function HandList:draw()
    -- Panel background
    self.nineSlice:draw(
        self.x,
        self.y,
        self.width,
        self.height,
        Theme.colors.surface,
        Theme.nineSlice.borderScale
    )

    -- Title
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.textMuted)
    love.graphics.print("HÄNDE", self.x + self.padding, self.y + self.padding)

    -- Draw each hand item
    for _, item in ipairs(self.items) do
        self:drawItem(item)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function HandList:drawItem(item)
    local handDef = item.handDef
    local handId = handDef.id

    local isUsed = self.isUsed(handId)
    local isSelected = self.isSelected(handId)
    local isValid = self.isValidHand(handId)
    local isHovered = self.hoveredHandId == handId
    local hasRolled = self.hasRolled()

    -- Determine background color
    local bgColor
    if isUsed then
        bgColor = Theme.colors.surface
    elseif isSelected then
        bgColor = Theme.colors.cyan
    elseif isHovered and hasRolled and not isUsed then
        bgColor = Theme.colors.surfaceHighlight
    else
        bgColor = Theme.colors.surface2
    end

    -- Draw item background
    self.nineSlice:draw(
        item.x,
        item.y,
        item.width,
        item.height,
        bgColor,
        Theme.nineSlice.borderScale
    )

    -- Draw valid hand indicator (cyan border)
    if isValid and hasRolled and not isSelected and not isUsed then
        love.graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", item.x + 2, item.y + 2, item.width - 4, item.height - 4, 6)
    end

    -- Draw icon
    local icon = self.icons[handId]
    local iconX = item.x + 8
    local iconY = item.y + (item.height - self.iconSize) / 2

    if icon then
        -- Determine icon opacity
        local iconAlpha = isUsed and 0.4 or 1.0
        love.graphics.setColor(1, 1, 1, iconAlpha)

        local iconScale = self.iconSize / icon:getWidth()
        love.graphics.draw(icon, iconX, iconY, 0, iconScale, iconScale)
    end

    -- Determine text color
    local textColor
    if isUsed then
        textColor = Theme.colors.textMuted
    elseif isSelected then
        textColor = Theme.colors.textDark
    else
        textColor = Theme.colors.text
    end

    -- Draw hand name (offset by icon)
    local textX = iconX + self.iconSize + 10
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(textColor)
    local textY = item.y + (item.height - Theme.fonts.normal:getHeight()) / 2
    love.graphics.print(handDef.name, textX, textY)

    -- Draw score if valid and rolled (right aligned)
    if hasRolled and isValid and not isUsed then
        local score = self.getScore(handId)
        if score > 0 then
            love.graphics.setFont(Theme.fonts.normal)
            local scoreText = tostring(score)
            local scoreWidth = Theme.fonts.normal:getWidth(scoreText)
            local scoreColor = isSelected and Theme.colors.textDark or Theme.colors.gold
            love.graphics.setColor(scoreColor)
            love.graphics.print(scoreText, item.x + item.width - scoreWidth - 12, textY)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return HandList
