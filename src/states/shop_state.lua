-- Shop State - New shop UI with 2x2 item grid

local Theme = require("src.ui.theme")
local GameState = require("src.game.game_state")
local Levels = require("src.game.levels")
local Relics = require("src.game.relics")
local Button = require("src.ui.button")
local NineSlice = require("src.ui.nine_slice")
local InfoPanel = require("src.ui.info_panel")
local ItemStrip = require("src.ui.item_strip")
local Sound = require("src.core.sound")
local ShopItem = require("src.ui.shop_item")
local ShopTooltip = require("src.ui.shop_tooltip")

local ShopState = {}
ShopState.__index = ShopState

-- Shop phases
ShopState.PHASE = {
    BROWSING = "browsing",
    ITEM_SELECTED = "item_selected",
}

-- Layout constants for 2x2 grid
local GRID_ITEM_SIZE = 160
local GRID_SPACING = 40
local GRID_START_Y = 280

function ShopState.new()
    local self = setmetatable({}, ShopState)

    self.nineSlice = NineSlice.getInstance()
    self.stateMachine = nil
    self.infoPanel = nil
    self.itemStrip = nil

    -- State machine
    self.phase = ShopState.PHASE.BROWSING
    self.selectedItemIndex = nil

    -- Shop items (4 items in 2x2 grid)
    self.shopItems = {}

    -- Buttons
    self.nextLevelButton = nil
    self.buyButton = nil
    self.cancelButton = nil

    -- Tooltip
    self.shopTooltip = ShopTooltip.getInstance()
    self.hoveredItemIndex = nil
    self.hoverTimer = 0

    -- Mouse position
    self.mouseX = 0
    self.mouseY = 0

    return self
end

function ShopState:enter(params)
    self.stateMachine = params.stateMachine
    self.phase = ShopState.PHASE.BROWSING
    self.selectedItemIndex = nil

    self:initInfoPanel()
    self:initItemStrip()
    self:initShopItems()
    self:initButtons()

    -- Reset tooltip
    self.shopTooltip:hide()
end

function ShopState:exit()
    -- Cleanup
end

function ShopState:initInfoPanel()
    local layout = Theme.layout

    self.infoPanel = InfoPanel.new({
        x = layout.leftPanelX,
        y = layout.leftPanelY,
        width = layout.leftPanelWidth,
        height = layout.leftPanelHeight,
        phase = "shop",
        getLevel = function()
            return GameState.currentLevel
        end,
        getRound = function()
            return 1
        end,
        getMoney = function()
            return GameState.money
        end,
        getGoal = function()
            return GameState:getCurrentGoal()
        end,
        getScore = function()
            return GameState.currentScore
        end,
        hasReachedGoal = function()
            return GameState:hasReachedGoal()
        end,
        getHandsRemaining = function()
            return GameState.handsRemaining
        end,
        getRollsRemaining = function()
            return GameState.rollsRemaining
        end,
        getDetectedHand = function()
            return nil
        end,
        getHandBreakdown = function()
            return nil
        end,
    })
end

function ShopState:initItemStrip()
    local layout = Theme.layout

    local totalWidth = 7 * layout.itemSlotSize + 4 * layout.itemSlotSpacing + layout.itemSlotGap + layout
        .itemSlotSpacing
    local stripX = layout.centerX + (layout.centerWidth - totalWidth) / 2

    self.itemStrip = ItemStrip.new({
        x = stripX,
        y = layout.itemStripY,
        -- Relic callbacks
        onRelicSell = function(slotIndex)
            local relic = GameState:getRelic(slotIndex)
            if not relic then return end

            local sellPrice = Relics:getSellPrice(relic.relicId)
            GameState:addMoney(sellPrice)
            GameState:removeRelic(slotIndex)

            Sound:play("cash")
        end,
        onRelicDragStart = function(slotIndex)
            -- Start drag
        end,
        onRelicDragEnd = function(slotIndex, x, y)
            -- Check for swap
            local targetSlot = self.itemStrip:getSlotAtPosition(x, y)
            if targetSlot and targetSlot.slotIndex ~= slotIndex then
                -- Check if target is also a relic slot (indices 1-5)
                if targetSlot.slotIndex <= 5 then
                    GameState:swapRelics(slotIndex, targetSlot.slotIndex)
                    Sound:play("click")
                end
            end
        end,
    })
end

function ShopState:initShopItems()
    self.shopItems = {}

    -- Calculate grid position (centered in center area)
    local totalWidth = 2 * GRID_ITEM_SIZE + GRID_SPACING
    local startX = Theme.layout.centerX + (Theme.layout.centerWidth - totalWidth) / 2

    -- Item positions in 2x2 grid:
    -- [1] [2]   <- Top row: relic, placeholder
    -- [3] [4]   <- Bottom row: placeholder, placeholder
    local positions = {
        { x = startX,                                 y = GRID_START_Y },                                 -- Top-left
        { x = startX + GRID_ITEM_SIZE + GRID_SPACING, y = GRID_START_Y },                                 -- Top-right (gift)
        { x = startX,                                 y = GRID_START_Y + GRID_ITEM_SIZE + GRID_SPACING }, -- Bottom-left
        { x = startX + GRID_ITEM_SIZE + GRID_SPACING, y = GRID_START_Y + GRID_ITEM_SIZE + GRID_SPACING }, -- Bottom-right
    }

    -- Create items
    -- Slot 1: Random unowned relic
    -- Slots 2, 3 & 4: Empty placeholders

    -- Find unowned relics
    local unownedRelicIds = {}
    local allRelics = Relics:getAll()
    for id, _ in pairs(allRelics) do
        if not GameState:hasRelic(id) then
            table.insert(unownedRelicIds, id)
        end
    end

    for i = 1, 4 do
        local itemType = "placeholder"
        local spriteImage = Theme.images.silverKey
        local price = nil
        local name = ""
        local relicId = nil
        local description = nil

        if i == 1 then
            -- Top-left: Random unowned relic
            if #unownedRelicIds > 0 then
                local randomIndex = math.random(1, #unownedRelicIds)
                relicId = unownedRelicIds[randomIndex]
                local def = Relics:get(relicId)

                if def then
                    itemType = "relic"
                    spriteImage = love.graphics.newImage(def.sprite)
                    price = def.buyPrice
                    name = def.name
                    description = def.description

                    -- Remove from available list (though we only pick one, so doesn't matter much)
                    table.remove(unownedRelicIds, randomIndex)
                end
            end
        end
        -- Slots 2, 3 & 4 use defaults (placeholder, silverKey, no price)

        self.shopItems[i] = ShopItem.new({
            x = positions[i].x,
            y = positions[i].y,
            size = GRID_ITEM_SIZE,
            index = i,
            itemType = itemType,
            spriteImage = spriteImage,
            price = price,
            name = name,
            description = description,
            relicId = relicId,
            onClick = function(index)
                self:onItemClick(index)
            end,
            onHoverStart = function(index)
                self:onItemHoverStart(index)
            end,
            onHoverEnd = function(index)
                self:onItemHoverEnd(index)
            end,
        })
    end
end

function ShopState:initButtons()
    local buttonWidth = Theme.layout.ctaWidth
    local buttonHeight = Theme.layout.ctaHeight
    local centerX = Theme.layout.centerX + Theme.layout.centerWidth / 2

    -- Determine button text based on game state
    local nextLevelText
    if Levels:isLastLevel(GameState.currentLevel) and GameState:hasReachedGoal() then
        nextLevelText = "VICTORY! NEW RUN"
    else
        nextLevelText = "NEXT LEVEL"
    end

    -- Next Level button (shown in BROWSING phase)
    self.nextLevelButton = Button.new({
        x = centerX - buttonWidth / 2,
        y = Theme.layout.ctaY,
        width = buttonWidth,
        height = buttonHeight,
        text = nextLevelText,
        bgColor = Theme.colors.cyan,
        textColor = Theme.colors.text,
        hoverBgColor = { Theme.colors.cyan[1] * 0.9, Theme.colors.cyan[2] * 0.9, Theme.colors.cyan[3] * 0.9, 1 },
        font = Theme.fonts.large,
        onClick = function()
            self:onNextLevelClick()
        end,
    })

    -- BUY button (shown in ITEM_SELECTED phase)
    local halfWidth = (buttonWidth - 20) / 2
    self.buyButton = Button.new({
        x = centerX - halfWidth - 10,
        y = Theme.layout.ctaY,
        width = halfWidth,
        height = buttonHeight,
        text = "BUY",
        bgColor = Theme.colors.cyan,
        textColor = Theme.colors.text,
        hoverBgColor = { Theme.colors.cyan[1] * 0.9, Theme.colors.cyan[2] * 0.9, Theme.colors.cyan[3] * 0.9, 1 },
        font = Theme.fonts.large,
        onClick = function()
            self:onBuyClick()
        end,
    })

    -- CANCEL button (shown in ITEM_SELECTED phase)
    self.cancelButton = Button.new({
        x = centerX + 10,
        y = Theme.layout.ctaY,
        width = halfWidth,
        height = buttonHeight,
        text = "CANCEL",
        bgColor = Theme.colors.surface2,
        textColor = Theme.colors.text,
        hoverBgColor = Theme.colors.surfaceHighlight,
        font = Theme.fonts.large,
        onClick = function()
            self:onCancelClick()
        end,
    })
end

function ShopState:onItemClick(index)
    if self.phase ~= ShopState.PHASE.BROWSING and self.phase ~= ShopState.PHASE.ITEM_SELECTED then return end

    local item = self.shopItems[index]
    if not item or item.sold then return end
    if not item.isInteractive then return end

    -- Toggle selection or swap
    if self.selectedItemIndex == index then
        -- Deselect if clicking same item
        item:setSelected(false)
        self.selectedItemIndex = nil
        self.phase = ShopState.PHASE.BROWSING
        Sound:play("click")
    else
        -- Deselect previous if exists
        if self.selectedItemIndex then
            local prevItem = self.shopItems[self.selectedItemIndex]
            if prevItem then
                prevItem:setSelected(false)
            end
        end

        -- Select new item
        self.selectedItemIndex = index
        self.phase = ShopState.PHASE.ITEM_SELECTED
        item:setSelected(true)
        Sound:play("click")
    end

    -- Hide tooltip (Removed to keep tooltip visible on selection)
    -- self.shopTooltip:hide()
    -- self.hoveredItemIndex = nil -- Keep hovered index to allow tooltip to persist
end

function ShopState:onItemHoverStart(index)
    self.hoveredItemIndex = index
    self.hoverTimer = 0
end

function ShopState:onItemHoverEnd(index)
    if self.hoveredItemIndex == index then
        self.hoveredItemIndex = nil
        self.hoverTimer = 0
        self.shopTooltip:hide()
    end
end

function ShopState:onNextLevelClick()
    if Levels:isLastLevel(GameState.currentLevel) and GameState:hasReachedGoal() then
        GameState:reset()
        self.stateMachine:change("play", {
            stateMachine = self.stateMachine,
        })
    else
        GameState:advanceLevel()
        self.stateMachine:change("play", {
            stateMachine = self.stateMachine,
        })
    end
end

function ShopState:onBuyClick()
    if self.phase ~= ShopState.PHASE.ITEM_SELECTED then return end
    if not self.selectedItemIndex then return end

    local item = self.shopItems[self.selectedItemIndex]
    if not item or item.sold then return end

    -- Check if player already owns this relic
    if item.relicId and GameState:hasRelic(item.relicId) then
        Sound:play("click")
        return
    end

    -- Check if player can afford
    if item.price and GameState.money < item.price then
        Sound:play("click")
        return
    end

    -- Handle different item types
    if item.itemType == "relic" then
        -- Check if there's room for relic
        if not GameState:hasRelicRoom() then
            Sound:play("click")
            return
        end

        -- Deduct money
        if item.price then
            GameState:addMoney(-item.price)
        end

        Sound:play("cash")

        -- Add relic directly (no animation needed)
        self:onRelicPurchased(item.relicId)
    end
end

function ShopState:onRelicPurchased(relicId)
    -- Add relic to inventory
    GameState:addRelic(relicId)

    -- Mark the item as sold
    if self.selectedItemIndex then
        local item = self.shopItems[self.selectedItemIndex]
        if item then
            item.sold = true
            item:setSelected(false)
        end
    end

    -- Return to browsing
    self.phase = ShopState.PHASE.BROWSING
    self.selectedItemIndex = nil
end

function ShopState:onCancelClick()
    if self.phase ~= ShopState.PHASE.ITEM_SELECTED then return end

    -- Deselect item
    if self.selectedItemIndex then
        local item = self.shopItems[self.selectedItemIndex]
        if item then
            item:setSelected(false)
        end
    end

    self.selectedItemIndex = nil
    self.phase = ShopState.PHASE.BROWSING

    Sound:play("click")
end

function ShopState:update(dt)
    -- Get mouse position
    local mx, my = love.mouse.getPosition()
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end
    self.mouseX = mx or 0
    self.mouseY = my or 0

    -- Update info panel
    if self.infoPanel then
        self.infoPanel:update(dt)
    end

    -- Update item strip
    if self.itemStrip then
        self.itemStrip:update(dt)
    end

    -- Update based on phase
    if self.phase == ShopState.PHASE.BROWSING then
        self:updateBrowsing(dt)
    elseif self.phase == ShopState.PHASE.ITEM_SELECTED then
        self:updateItemSelected(dt)
    end
end

function ShopState:updateBrowsing(dt)
    -- Update shop items
    for _, item in ipairs(self.shopItems) do
        -- Check affordability
        if item.price then
            item:setIsAffordable(GameState.money >= item.price)
        else
            item:setIsAffordable(true) -- Items without price are considered affordable (or irrelevant)
        end

        item:updateMouse(self.mouseX, self.mouseY)
        item:update(dt)
    end

    -- Update next level button
    self.nextLevelButton:update(dt)

    -- Update tooltips (valid in browsing too)
    self:updateTooltips(dt)
end

function ShopState:updateTooltips(dt)
    -- Update tooltip hover timer
    if self.hoveredItemIndex then
        self.hoverTimer = self.hoverTimer + dt
        if self.hoverTimer >= 0.1 then -- 0.1 second delay for consistency
            local item = self.shopItems[self.hoveredItemIndex]
            if item and item.name and item.name ~= "" and not item.sold then
                local centerX, centerY = item:getCenterPosition()
                -- Get description for relics or use item description
                local description = item.description
                if not description and item.itemType == "relic" and item.relicId then
                    local relicDef = Relics:get(item.relicId)
                    if relicDef then
                        description = relicDef.description
                    end
                end
                self.shopTooltip:show(item.name, centerX, centerY - self.shopItems[self.hoveredItemIndex].size / 2,
                    description)
            end
        end
    end

    -- Update tooltip
    self.shopTooltip:update(dt)
end

function ShopState:updateItemSelected(dt)
    -- Update shop items (for animation)
    for _, item in ipairs(self.shopItems) do
        item:updateMouse(self.mouseX, self.mouseY)
        item:update(dt)
    end

    -- Update buttons
    self.buyButton:update(dt)
    self.cancelButton:update(dt)

    -- Update tooltips
    self:updateTooltips(dt)
end

function ShopState:draw()
    -- Always draw info panel
    if self.infoPanel then
        self.infoPanel:draw()
    end

    -- Draw item strip (unless dragging)
    if self.itemStrip and not self.itemStrip:isDragging() then
        self.itemStrip:draw()
    end

    -- Draw shop items and buttons
    self:drawShopItems(1)
    self:drawButtons()
    self.shopTooltip:draw()

    -- Draw item strip again if dragging
    if self.itemStrip and self.itemStrip:isDragging() then
        self.itemStrip:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ShopState:mousemoved(x, y, dx, dy)
    if self.itemStrip then
        self.itemStrip:mousemoved(x, y, dx, dy)
    end
end

function ShopState:drawShopItems(alpha)
    love.graphics.setColor(1, 1, 1, alpha)

    for _, item in ipairs(self.shopItems) do
        item:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ShopState:drawButtons()
    if self.phase == ShopState.PHASE.ITEM_SELECTED then
        self.buyButton:draw()
        self.cancelButton:draw()
    elseif self.phase == ShopState.PHASE.BROWSING then
        self.nextLevelButton:draw()
    end
end

function ShopState:drawShopDice()
    local positions = self:getShopDicePositions()
    local diceSize = 110

    for i = 1, 5 do
        local pos = positions[i]
        local die = GameState.dice[i]
        local faceValue = die.value

        self.nineSlice:draw(pos.x, pos.y, diceSize, diceSize, Theme.colors.surface2, Theme.nineSlice.borderScale)

        if Theme.diceSpritesheet then
            local quad = Theme.diceSpritesheet:getQuad(faceValue, "basic")
            local image = Theme.diceSpritesheet:getImage()

            love.graphics.setColor(1, 1, 1, 1)
            local spriteSize = diceSize * 0.9
            local spriteX = pos.x + (diceSize - spriteSize) / 2
            local spriteY = pos.y + (diceSize - spriteSize) / 2
            local spriteW, _ = Theme.diceSpritesheet:getSpriteSize()
            local scale = spriteSize / spriteW
            love.graphics.draw(image, quad, spriteX, spriteY, 0, scale, scale)
        end

        love.graphics.setColor(Theme.colors.textMuted)
        local font = Theme.fonts.small
        love.graphics.setFont(font)
        local label = "Die " .. i
        local labelWidth = font:getWidth(label)
        love.graphics.print(label, pos.x + (diceSize - labelWidth) / 2, pos.y + diceSize + 5)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ShopState:mousepressed(x, y, button)
    -- Check item strip (relics)
    if self.itemStrip and self.itemStrip:mousepressed(x, y, button) then
        return true
    end

    -- Handle based on phase
    if self.phase == ShopState.PHASE.BROWSING then
        -- Shop items
        for _, item in ipairs(self.shopItems) do
            if item:mousepressed(x, y, button) then
                return
            end
        end

        -- Next level button
        if self.nextLevelButton:mousepressed(x, y, button) then
            return
        end
    elseif self.phase == ShopState.PHASE.ITEM_SELECTED then
        -- BUY/CANCEL buttons
        if self.buyButton:mousepressed(x, y, button) then
            return
        end
        if self.cancelButton:mousepressed(x, y, button) then
            return
        end

        -- Shop items (allow switching/deselecting)
        for _, item in ipairs(self.shopItems) do
            if item:mousepressed(x, y, button) then
                return
            end
        end
    end

    -- Info panel
    if self.infoPanel then
        self.infoPanel:mousepressed(x, y, button)
    end
end

function ShopState:mousereleased(x, y, button)
    if self.itemStrip then
        self.itemStrip:mousereleased(x, y, button)
    end

    self.nextLevelButton:mousereleased(x, y, button)
    self.buyButton:mousereleased(x, y, button)
    self.cancelButton:mousereleased(x, y, button)

    if self.infoPanel then
        self.infoPanel:mousereleased(x, y, button)
    end
end

function ShopState:keypressed(key)
    if key == "escape" or key == "backspace" then
        if self.phase == ShopState.PHASE.ITEM_SELECTED then
            self:onCancelClick()
        elseif self.itemStrip then
            self.itemStrip:deselectAll()
        end
        return
    end

    if key == "return" then
        if self.phase == ShopState.PHASE.BROWSING then
            self:onNextLevelClick()
        elseif self.phase == ShopState.PHASE.ITEM_SELECTED then
            self:onBuyClick()
        end
        return
    end

    -- Item selection shortcuts
    if self.phase == ShopState.PHASE.BROWSING or self.phase == ShopState.PHASE.ITEM_SELECTED then
        local index = tonumber(key)
        if index and index >= 1 and index <= 4 then
            self:onItemClick(index)
        end
    end
end

return ShopState
