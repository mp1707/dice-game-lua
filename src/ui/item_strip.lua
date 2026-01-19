-- Item Strip component
-- Visual-only container for 7 item/consumable slots at the top center

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
    self.slotCount = config.slotCount or Theme.layout.itemSlotCount

    self.nineSlice = NineSlice.getInstance()

    return self
end

function ItemStrip:getTotalWidth()
    return (self.slotCount * self.slotSize) + ((self.slotCount - 1) * self.slotSpacing)
end

function ItemStrip:getSlotX(index)
    return self.x + (index - 1) * (self.slotSize + self.slotSpacing)
end

function ItemStrip:draw()
    -- Draw each empty slot
    for i = 1, self.slotCount do
        local slotX = self:getSlotX(i)
        local slotY = self.y

        -- Draw dark slot background
        self.nineSlice:draw(
            slotX,
            slotY,
            self.slotSize,
            self.slotSize,
            Theme.colors.surface,
            Theme.nineSlice.borderScale
        )

        -- Draw subtle inner border
        love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", slotX + 4, slotY + 4, self.slotSize - 8, self.slotSize - 8, 4)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ItemStrip
