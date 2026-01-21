-- Selection Panel component
-- Displays dice selection area for Zahlen or Kombinationen

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local SelectionPanel = {}
SelectionPanel.__index = SelectionPanel

function SelectionPanel.new(config)
    local self = setmetatable({}, SelectionPanel)

    self.x = config.x or 0
    self.y = config.y or 0
    self.width = config.width or 400
    self.height = config.height or 180

    self.title = config.title or "Selection"
    self.section = config.section or "upper" -- "upper" for Zahlen, "lower" for Kombinationen

    -- Callbacks for getting data
    self.getSelectedDice = config.getSelectedDice or function() return {} end
    self.getDiceValue = config.getDiceValue or function(idx) return 1 end
    self.onDiceClick = config.onDiceClick or function(idx) end

    -- Slot configuration
    self.slotCount = 5
    self.slotSize = Theme.layout.selectionSlotSize or 100
    self.slotSpacing = Theme.layout.selectionSlotSpacing or 16

    -- Calculate slot positions
    self:calculateSlotPositions()

    return self
end

function SelectionPanel:calculateSlotPositions()
    local totalSlotsWidth = self.slotCount * self.slotSize + (self.slotCount - 1) * self.slotSpacing
    local startX = self.x + (self.width - totalSlotsWidth) / 2
    local slotY = self.y + self.height - self.slotSize - 20 -- Position slots near bottom

    self.slotPositions = {}
    for i = 1, self.slotCount do
        self.slotPositions[i] = {
            x = startX + (i - 1) * (self.slotSize + self.slotSpacing),
            y = slotY,
        }
    end
end

function SelectionPanel:getSlotAtPoint(px, py)
    for i, slot in ipairs(self.slotPositions) do
        if px >= slot.x and px < slot.x + self.slotSize and
            py >= slot.y and py < slot.y + self.slotSize then
            return i
        end
    end
    return nil
end

function SelectionPanel:containsPoint(px, py)
    return px >= self.x and px < self.x + self.width and
        py >= self.y and py < self.y + self.height
end

function SelectionPanel:getSlotCenter(slotIndex)
    if slotIndex < 1 or slotIndex > self.slotCount then return nil end
    local slot = self.slotPositions[slotIndex]
    return slot.x + self.slotSize / 2, slot.y + self.slotSize / 2
end

function SelectionPanel:getSlotPosition(slotIndex)
    if slotIndex < 1 or slotIndex > self.slotCount then return nil end
    return self.slotPositions[slotIndex].x, self.slotPositions[slotIndex].y
end

function SelectionPanel:mousepressed(x, y, button)
    if not self:containsPoint(x, y) then return false end

    -- Check if clicking on a dice in a slot
    local selectedDice = self.getSelectedDice()
    for i, diceIdx in ipairs(selectedDice) do
        if i <= self.slotCount then
            local slot = self.slotPositions[i]
            if x >= slot.x and x < slot.x + self.slotSize and
                y >= slot.y and y < slot.y + self.slotSize then
                -- Clicked on a dice - remove it from selection
                self.onDiceClick(diceIdx)
                return true
            end
        end
    end

    return false
end

function SelectionPanel:update(dt)
    -- No update logic needed for now
end

function SelectionPanel:draw()
    local nineSlice = NineSlice.getInstance()

    -- Draw panel background (darker shade)
    nineSlice:draw(self.x, self.y, self.width, self.height, Theme.colors.panelDark, Theme.nineSlice.borderScale)

    -- Draw title label (subtle, at top)
    local titleColor = Theme.colors.textMuted
    love.graphics.setFont(Theme.fonts.large)
    Theme:drawTextWithShadow(self.title, self.x + 20, self.y + 12, Theme.fonts.large, titleColor)

    -- Draw slot backgrounds
    local selectedDice = self.getSelectedDice()
    for i = 1, self.slotCount do
        local slot = self.slotPositions[i]
        local hasDice = i <= #selectedDice

        -- Slot background color
        local slotColor = hasDice and Theme.colors.surface2 or Theme.colors.bg2
        nineSlice:draw(slot.x, slot.y, self.slotSize, self.slotSize, slotColor, Theme.nineSlice.borderScale)

        -- Draw dice face if occupied
        if hasDice then
            local diceIdx = selectedDice[i]
            local diceValue = self.getDiceValue(diceIdx)
            self:drawDiceFace(slot.x, slot.y, self.slotSize, diceValue)
        end
    end
end

function SelectionPanel:drawDiceFace(x, y, size, value)
    local padding = 8
    local innerSize = size - padding * 2

    -- Draw white dice background
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x + padding, y + padding, innerSize, innerSize, 8, 8)

    -- Draw dice face image
    if Theme.images.diceFaces[value] then
        local img = Theme.images.diceFaces[value]
        local imgW, imgH = img:getDimensions()
        local scale = (innerSize - 8) / math.max(imgW, imgH)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            img,
            x + padding + innerSize / 2,
            y + padding + innerSize / 2,
            0,
            scale, scale,
            imgW / 2, imgH / 2
        )
    end
end

return SelectionPanel
