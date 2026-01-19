-- Held Tray component
-- 5-slot container for locked dice with "HELD" label

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local HeldTray = {}
HeldTray.__index = HeldTray

function HeldTray.new(config)
    local self = setmetatable({}, HeldTray)

    self.x = config.x or 0
    self.y = config.y or Theme.layout.heldTrayY
    self.slotSize = config.slotSize or Theme.layout.heldSlotSize
    self.slotSpacing = config.slotSpacing or Theme.layout.heldSlotSpacing
    self.slotCount = config.slotCount or Theme.layout.heldSlotCount

    -- Track which slots are occupied and by which dice index
    self.slots = {}
    for i = 1, self.slotCount do
        self.slots[i] = {
            occupied = false,
            diceIndex = nil,
        }
    end

    self.label = "HALTEN"
    self.nineSlice = NineSlice.getInstance()

    return self
end

function HeldTray:getTotalWidth()
    return (self.slotCount * self.slotSize) + ((self.slotCount - 1) * self.slotSpacing)
end

function HeldTray:getSlotBounds(slotIndex)
    local slotX = self.x + (slotIndex - 1) * (self.slotSize + self.slotSpacing)
    return {
        x = slotX,
        y = self.y,
        width = self.slotSize,
        height = self.slotSize,
    }
end

function HeldTray:getEmptySlot()
    for i = 1, self.slotCount do
        if not self.slots[i].occupied then
            return i
        end
    end
    return nil
end

function HeldTray:getSlotForDice(diceIndex)
    for i = 1, self.slotCount do
        if self.slots[i].diceIndex == diceIndex then
            return i
        end
    end
    return nil
end

function HeldTray:occupySlot(slotIndex, diceIndex)
    if slotIndex >= 1 and slotIndex <= self.slotCount then
        self.slots[slotIndex].occupied = true
        self.slots[slotIndex].diceIndex = diceIndex
    end
end

function HeldTray:freeSlot(slotIndex)
    if slotIndex >= 1 and slotIndex <= self.slotCount then
        self.slots[slotIndex].occupied = false
        self.slots[slotIndex].diceIndex = nil
    end
end

function HeldTray:freeSlotByDice(diceIndex)
    local slotIndex = self:getSlotForDice(diceIndex)
    if slotIndex then
        self:freeSlot(slotIndex)
    end
end

function HeldTray:reset()
    for i = 1, self.slotCount do
        self.slots[i].occupied = false
        self.slots[i].diceIndex = nil
    end
end

function HeldTray:containsPoint(px, py)
    local totalWidth = self:getTotalWidth()
    return px >= self.x and px < self.x + totalWidth and
        py >= self.y and py < self.y + self.slotSize
end

function HeldTray:getSlotAtPoint(px, py)
    if not self:containsPoint(px, py) then
        return nil
    end

    for i = 1, self.slotCount do
        local bounds = self:getSlotBounds(i)
        if px >= bounds.x and px < bounds.x + bounds.width and
            py >= bounds.y and py < bounds.y + bounds.height then
            return i
        end
    end
    return nil
end

function HeldTray:draw()
    -- Draw each slot
    for i = 1, self.slotCount do
        local bounds = self:getSlotBounds(i)
        local isOccupied = self.slots[i].occupied

        -- Slot background (slightly different if occupied)
        local bgColor = isOccupied and Theme.colors.surface2 or Theme.colors.surface
        self.nineSlice:draw(
            bounds.x,
            bounds.y,
            bounds.width,
            bounds.height,
            bgColor,
            Theme.nineSlice.borderScale
        )

        -- Draw subtle inner border for empty slots
        if not isOccupied then
            love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 0.3)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", bounds.x + 6, bounds.y + 6, bounds.width - 12, bounds.height - 12, 6)
        end
    end

    -- Draw "HELD" label below the tray
    love.graphics.setFont(Theme.fonts.normal)
    love.graphics.setColor(Theme.colors.cyan)
    local labelWidth = Theme.fonts.normal:getWidth(self.label)
    local totalWidth = self:getTotalWidth()
    local labelX = self.x + (totalWidth - labelWidth) / 2
    local labelY = self.y + self.slotSize + 8

    -- Draw label with decorative lines
    local lineWidth = 60
    local lineY = labelY + Theme.fonts.normal:getHeight() / 2

    love.graphics.setLineWidth(2)
    love.graphics.line(labelX - lineWidth - 10, lineY, labelX - 10, lineY)
    love.graphics.line(labelX + labelWidth + 10, lineY, labelX + labelWidth + lineWidth + 10, lineY)

    love.graphics.print(self.label, math.floor(labelX), math.floor(labelY))

    love.graphics.setColor(1, 1, 1, 1)
end

return HeldTray
