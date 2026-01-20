-- Item Strip component
-- Visual-only container for 5 + 2 item/consumable slots at the top center
-- Layout: [1][2][3][4][5]   GAP   [6][7]

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local ItemStrip = {}
ItemStrip.__index = ItemStrip

function ItemStrip.new(config)
    local self = setmetatable({}, ItemStrip)

    self.x = config.x or 0
    self.y = config.y or Theme.layout.itemStripY
    self.slotSize = config.slotSize or Theme.layout.itemSlotSize
    self.slotSpacing = config.slotSpacing or Theme.layout.itemSlotSpacing
    self.slotGap = config.slotGap or Theme.layout.itemSlotGap or 50
    self.slotCount = config.slotCount or Theme.layout.itemSlotCount or 7

    self.nineSlice = NineSlice.getInstance()

    return self
end

function ItemStrip:getTotalWidth()
    -- Width of first 5 slots + gap + width of last 2 slots
    local firstFiveWidth = 5 * self.slotSize + 4 * self.slotSpacing
    local lastTwoWidth = 2 * self.slotSize + 1 * self.slotSpacing
    return firstFiveWidth + self.slotGap + lastTwoWidth
end

function ItemStrip:getSlotX(index)
    if index <= 5 then
        -- First 5 slots
        return self.x + (index - 1) * (self.slotSize + self.slotSpacing)
    else
        -- After slot 5, add gap
        local afterFiveX = self.x + 5 * (self.slotSize + self.slotSpacing) - self.slotSpacing + self.slotGap
        return afterFiveX + (index - 6) * (self.slotSize + self.slotSpacing)
    end
end

function ItemStrip:draw()
    -- Draw first 5 slots
    for i = 1, 5 do
        local slotX = self:getSlotX(i)
        local slotY = self.y

        -- Draw dark slot background
        self.nineSlice:draw(
            slotX,
            slotY,
            self.slotSize,
            self.slotSize,
            Theme.colors.panelDark,
            Theme.nineSlice.borderScale
        )
    end

    -- Draw last 2 slots (after gap)
    for i = 6, 7 do
        local slotX = self:getSlotX(i)
        local slotY = self.y

        -- Draw dark slot background
        self.nineSlice:draw(
            slotX,
            slotY,
            self.slotSize,
            self.slotSize,
            Theme.colors.panelDark,
            Theme.nineSlice.borderScale
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ItemStrip
