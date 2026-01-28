-- Item Strip component
-- Container for 5 relic slots at the top center
-- Layout: [1][2][3][4][5]
-- Slots 1-5 are interactive relic slots for passive items

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local RelicSlot = require("src.ui.relic_slot")

local ItemStrip = {}
ItemStrip.__index = ItemStrip

function ItemStrip.new(config)
    local self = setmetatable({}, ItemStrip)

    self.x = config.x or 0
    self.y = config.y or Theme.layout.itemStripY
    self.slotSize = config.slotSize or Theme.layout.itemSlotSize
    self.slotSpacing = config.slotSpacing or Theme.layout.itemSlotSpacing
    self.slotCount = config.slotCount or Theme.layout.itemSlotCount or 5

    self.nineSlice = NineSlice.getInstance()

    -- Callbacks for relic actions
    self.onRelicSell = config.onRelicSell or function() end
    self.onRelicDragStart = config.onRelicDragStart or function() end
    self.onRelicDragEnd = config.onRelicDragEnd or function() end

    -- Create relic slots for positions 1-5
    self.relicSlots = {}
    for i = 1, 5 do
        local slotX = self:getSlotX(i)
        self.relicSlots[i] = RelicSlot.new({
            x = slotX,
            y = self.y,
            size = self.slotSize,
            slotIndex = i,
            onSell = function(slotIndex)
                self.onRelicSell(slotIndex)
            end,
            onDragStart = function(slotIndex)
                self.onRelicDragStart(slotIndex)
            end,
            onDragEnd = function(slotIndex, x, y)
                self.onRelicDragEnd(slotIndex, x, y)
            end,
        })
    end

    return self
end

function ItemStrip:getTotalWidth()
    -- Width of 5 slots
    return 5 * self.slotSize + 4 * self.slotSpacing
end

function ItemStrip:getSlotX(index)
    -- 5 slots laid out horizontally
    return self.x + (index - 1) * (self.slotSize + self.slotSpacing)
end

function ItemStrip:update(dt)
    -- Update relic slots
    for _, slot in ipairs(self.relicSlots) do
        slot:update(dt)
    end
end

function ItemStrip:mousepressed(x, y, button)
    -- Check relic slots
    for _, slot in ipairs(self.relicSlots) do
        if slot:mousepressed(x, y, button) then
            -- Deselect other slots
            for _, otherSlot in ipairs(self.relicSlots) do
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
    for _, slot in ipairs(self.relicSlots) do
        if slot:mousereleased(x, y, button) then
            return true
        end
    end
    return false
end

function ItemStrip:mousemoved(x, y, dx, dy)
    for _, slot in ipairs(self.relicSlots) do
        slot:mousemoved(x, y, dx, dy)
    end
end

function ItemStrip:deselectAll()
    for _, slot in ipairs(self.relicSlots) do
        slot:deselect()
    end
end

function ItemStrip:isDragging()
    for _, slot in ipairs(self.relicSlots) do
        if slot:isDraggingRelic() then
            return true
        end
    end
    return false
end

function ItemStrip:getDraggingSlot()
    for _, slot in ipairs(self.relicSlots) do
        if slot:isDraggingRelic() then
            return slot
        end
    end
    return nil
end

function ItemStrip:getSlotAtPosition(x, y)
    -- Check relic slots
    for _, slot in ipairs(self.relicSlots) do
        local sx, sy = slot.x, slot.y
        if x >= sx and x < sx + slot.size and
            y >= sy and y < sy + slot.size then
            return slot
        end
    end
    return nil
end

function ItemStrip:triggerItemAnim(slotIndex)
    if slotIndex <= 5 then
        local slot = self.relicSlots[slotIndex]
        if slot and slot:hasRelic() then
            slot:triggerPulse()
        end
    end
end

function ItemStrip:draw()
    local draggingSlot = nil

    -- Draw non-dragging relic slots
    for _, slot in ipairs(self.relicSlots) do
        if slot:isDraggingRelic() then
            draggingSlot = slot
        else
            slot:draw(1.0)
        end
    end

    -- Draw the dragging slot last (on top)
    if draggingSlot then
        draggingSlot:draw(1.0)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ItemStrip
