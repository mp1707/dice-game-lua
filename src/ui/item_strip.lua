-- Item Strip component
-- Container for 5 item slots + 2 consumable slots at the top center
-- Layout: [1][2][3][4][5]   GAP   [6][7]
-- Slots 6-7 are interactive consumable slots for stickers

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local ConsumableSlot = require("src.ui.consumable_slot")

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

    -- Callbacks for consumable actions
    self.onConsumableUse = config.onConsumableUse or function() end
    self.onConsumableSell = config.onConsumableSell or function() end
    self.onConsumableDragStart = config.onConsumableDragStart or function() end
    self.onConsumableDragEnd = config.onConsumableDragEnd or function() end

    -- Create consumable slots for positions 6 and 7
    self.consumableSlots = {}
    for i = 1, 2 do
        local slotX = self:getSlotX(i + 5) -- Slots 6 and 7
        self.consumableSlots[i] = ConsumableSlot.new({
            x = slotX,
            y = self.y,
            size = self.slotSize,
            slotIndex = i,
            onUse = function(slotIndex)
                self.onConsumableUse(slotIndex)
            end,
            onSell = function(slotIndex)
                self.onConsumableSell(slotIndex)
            end,
            onDragStart = function(slotIndex)
                self.onConsumableDragStart(slotIndex)
            end,
            onDragEnd = function(slotIndex, x, y)
                self.onConsumableDragEnd(slotIndex, x, y)
            end,
        })
    end

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

function ItemStrip:update(dt)
    -- Update consumable slots
    for _, slot in ipairs(self.consumableSlots) do
        slot:update(dt)
    end
end

function ItemStrip:mousepressed(x, y, button)
    -- Check consumable slots first
    for _, slot in ipairs(self.consumableSlots) do
        if slot:mousepressed(x, y, button) then
            -- Deselect other slots
            for _, otherSlot in ipairs(self.consumableSlots) do
                if otherSlot ~= slot then
                    otherSlot:deselect()
                end
            end
            return true
        end
    end
    return false
end

function ItemStrip:mousereleased(x, y, button)
    for _, slot in ipairs(self.consumableSlots) do
        if slot:mousereleased(x, y, button) then
            return true
        end
    end
    return false
end

function ItemStrip:mousemoved(x, y, dx, dy)
    for _, slot in ipairs(self.consumableSlots) do
        slot:mousemoved(x, y, dx, dy)
    end
end

function ItemStrip:deselectAll()
    for _, slot in ipairs(self.consumableSlots) do
        slot:deselect()
    end
end

function ItemStrip:isDragging()
    for _, slot in ipairs(self.consumableSlots) do
        if slot:isDraggingSticker() then
            return true
        end
    end
    return false
end

function ItemStrip:getDraggingSlot()
    for _, slot in ipairs(self.consumableSlots) do
        if slot:isDraggingSticker() then
            return slot
        end
    end
    return nil
end

function ItemStrip:draw()
    -- Draw first 5 slots (passive items - visual only for now)
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

    -- Draw consumable slots (6-7)
    for _, slot in ipairs(self.consumableSlots) do
        slot:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ItemStrip
