-- Hand Card Area component
-- Manages 0-2 hand cards displayed horizontally centered

local Theme = require("src.ui.theme")
local HandCard = require("src.ui.hand_card")

local HandCardArea = {}
HandCardArea.__index = HandCardArea

function HandCardArea.new(config)
    local self = setmetatable({}, HandCardArea)

    -- Area bounds
    self.x = config.x or 0
    self.y = config.y or Theme.layout.handCardAreaY
    self.width = config.width or Theme.layout.centerWidth

    -- Card dimensions
    self.cardWidth = Theme.layout.handCardWidth
    self.cardHeight = Theme.layout.handCardHeight
    self.cardSpacing = Theme.layout.handCardSpacing

    -- Cards array (0, 1, or 2 cards)
    self.cards = {}

    -- Track which card is selected (1, 2, or nil)
    self.selectedIndex = nil

    -- Store hand data for retrieval
    self.handData = {}  -- {zahlen = {...}, kombination = {...}}

    return self
end

function HandCardArea:update(dt)
    for _, card in ipairs(self.cards) do
        card:update(dt)
    end
end

function HandCardArea:draw()
    for _, card in ipairs(self.cards) do
        card:draw()
    end
end

-- Set the hands to display (nil for no hand)
-- zahlenHand and kombinationHand are tables with: {id, name, level, scoringDice}
function HandCardArea:setHands(zahlenHand, kombinationHand)
    self.cards = {}
    self.handData = {}
    self.selectedIndex = nil

    local handsToShow = {}

    if zahlenHand then
        table.insert(handsToShow, zahlenHand)
        self.handData[1] = zahlenHand
    end

    if kombinationHand then
        table.insert(handsToShow, kombinationHand)
        self.handData[#self.handData + 1] = kombinationHand
    end

    -- Calculate centered positions
    local numCards = #handsToShow
    if numCards == 0 then
        return
    end

    local totalWidth = numCards * self.cardWidth + (numCards - 1) * self.cardSpacing
    local startX = self.x + (self.width - totalWidth) / 2

    for i, handInfo in ipairs(handsToShow) do
        local cardX = startX + (i - 1) * (self.cardWidth + self.cardSpacing)

        local card = HandCard.new({
            x = cardX,
            y = self.y,
            width = self.cardWidth,
            height = self.cardHeight,
            handId = handInfo.id,
            handName = handInfo.name,
            level = handInfo.level,
            scoringDice = handInfo.scoringDice,
            onClick = function(clickedCard)
                self:onCardClick(i)
            end,
        })

        table.insert(self.cards, card)
    end
end

function HandCardArea:onCardClick(index)
    -- Radio button behavior: clicking selected card keeps it selected
    -- clicking different card switches selection
    if self.selectedIndex == index then
        -- Already selected, do nothing (or could deselect if desired)
        return
    end

    -- Deselect previous
    if self.selectedIndex and self.cards[self.selectedIndex] then
        self.cards[self.selectedIndex]:setSelected(false)
    end

    -- Select new
    self.selectedIndex = index
    if self.cards[index] then
        self.cards[index]:setSelected(true)
    end
end

function HandCardArea:mousepressed(x, y, button)
    for _, card in ipairs(self.cards) do
        if card:mousepressed(x, y, button) then
            return true
        end
    end
    return false
end

function HandCardArea:keypressed(key)
    if #self.cards == 0 then
        return false
    end

    if key == "left" then
        if self.selectedIndex == nil then
            -- Select first card
            self:onCardClick(1)
        elseif self.selectedIndex > 1 then
            -- Move selection left
            self:onCardClick(self.selectedIndex - 1)
        end
        return true
    elseif key == "right" then
        if self.selectedIndex == nil then
            -- Select last card
            self:onCardClick(#self.cards)
        elseif self.selectedIndex < #self.cards then
            -- Move selection right
            self:onCardClick(self.selectedIndex + 1)
        end
        return true
    end

    return false
end

-- Get the currently selected hand info, or nil if none selected
function HandCardArea:getSelectedHand()
    if self.selectedIndex and self.handData[self.selectedIndex] then
        return self.handData[self.selectedIndex]
    end
    return nil
end

-- Clear selection
function HandCardArea:clearSelection()
    if self.selectedIndex and self.cards[self.selectedIndex] then
        self.cards[self.selectedIndex]:setSelected(false)
    end
    self.selectedIndex = nil
end

-- Check if any cards are displayed
function HandCardArea:hasCards()
    return #self.cards > 0
end

return HandCardArea
