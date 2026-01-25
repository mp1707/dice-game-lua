-- Shop State - New shop UI with 2x2 item grid
-- Features booster pack opening animation and sticker selection

local Theme = require("src.ui.theme")
local GameState = require("src.game.game_state")
local Levels = require("src.game.levels")
local Stickers = require("src.game.stickers")
local Relics = require("src.game.relics")
local Button = require("src.ui.button")
local NineSlice = require("src.ui.nine_slice")
local InfoPanel = require("src.ui.info_panel")
local ItemStrip = require("src.ui.item_strip")
local DragZones = require("src.ui.drag_zones")
local DiceEditor = require("src.ui.dice_editor")
local Sound = require("src.core.sound")
local ShopItem = require("src.ui.shop_item")
local ShopTooltip = require("src.ui.shop_tooltip")
local BoosterAnimation = require("src.ui.booster_animation")
local StickerSelection = require("src.ui.sticker_selection")

local ShopState = {}
ShopState.__index = ShopState

-- Shop phases
ShopState.PHASE = {
    BROWSING = "browsing",
    ITEM_SELECTED = "item_selected",
    OPENING_BOOSTER = "opening_booster",
    SELECTING_STICKER = "selecting_sticker",
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

    -- Booster animation
    self.boosterAnimation = BoosterAnimation.getInstance()

    -- Sticker selection
    self.stickerSelection = StickerSelection.getInstance()

    -- Drag zones (for consumable management)
    self.dragZones = DragZones.getInstance()

    -- Dice editor (for consumable use)
    self.diceEditor = DiceEditor.getInstance()
    self.showingDiceForEditor = false
    self.editorCancelButton = nil

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

    -- Reset animation states
    self.boosterAnimation:reset()
    self.stickerSelection:hide()
    self.shopTooltip:hide()
end

function ShopState:exit()
    self.diceEditor:deactivate()
    self.boosterAnimation:reset()
    self.stickerSelection:hide()
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
        onConsumableUse = function(slotIndex)
            self:onConsumableUse(slotIndex)
        end,
        onConsumableSell = function(slotIndex)
            self:onConsumableSell(slotIndex)
        end,
        onConsumableDragStart = function(slotIndex)
            local stripIndex = slotIndex + 5 -- Maps to visual slots 6 and 7
            local slotX = self.itemStrip:getSlotX(stripIndex)
            self.dragZones:show(slotIndex, slotX, self.itemStrip.y, self.itemStrip.slotSize)
        end,
        onConsumableDragEnd = function(slotIndex, x, y)
            self:onConsumableDragEnd(slotIndex, x, y)
        end,
    })
end

function ShopState:initShopItems()
    self.shopItems = {}

    -- Calculate grid position (centered in center area)
    local totalWidth = 2 * GRID_ITEM_SIZE + GRID_SPACING
    local startX = Theme.layout.centerX + (Theme.layout.centerWidth - totalWidth) / 2

    -- Item positions in 2x2 grid:
    -- [1] [2]   <- Top row: placeholder, booster (gift)
    -- [3] [4]   <- Bottom row: placeholder, placeholder
    local positions = {
        { x = startX,                                 y = GRID_START_Y },                                 -- Top-left
        { x = startX + GRID_ITEM_SIZE + GRID_SPACING, y = GRID_START_Y },                                 -- Top-right (gift)
        { x = startX,                                 y = GRID_START_Y + GRID_ITEM_SIZE + GRID_SPACING }, -- Bottom-left
        { x = startX + GRID_ITEM_SIZE + GRID_SPACING, y = GRID_START_Y + GRID_ITEM_SIZE + GRID_SPACING }, -- Bottom-right
    }

    -- Create items
    for i = 1, 4 do
        local itemType = "placeholder"
        local spriteImage = Theme.images.silverKey
        local price = nil
        local name = ""
        local relicId = nil

        if i == 1 then
            -- Top-left: Prism relic
            itemType = "relic"
            spriteImage = Theme.images.prism
            price = 10
            name = "Prism"
            relicId = "prism"
        elseif i == 2 then
            -- Top-right: Booster gift
            itemType = "booster"
            spriteImage = Theme.images.gift
            price = 8
            name = "Random Basic Sticker"
        end

        self.shopItems[i] = ShopItem.new({
            x = positions[i].x,
            y = positions[i].y,
            size = GRID_ITEM_SIZE,
            index = i,
            itemType = itemType,
            spriteImage = spriteImage,
            price = price,
            name = name,
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
        textColor = Theme.colors.textDark,
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
        textColor = Theme.colors.textDark,
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
    if self.phase ~= ShopState.PHASE.BROWSING then return end

    local item = self.shopItems[index]
    if not item or item.sold then return end
    if not item.isInteractive then return end

    -- Select this item
    self.selectedItemIndex = index
    self.phase = ShopState.PHASE.ITEM_SELECTED
    item:setSelected(true)

    -- Hide tooltip
    self.shopTooltip:hide()
    self.hoveredItemIndex = nil

    Sound:play("click")
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
    else
        -- Booster purchase
        -- Check if there's room for consumable
        if not GameState:hasConsumableRoom() then
            Sound:play("click")
            return
        end

        -- Deduct money
        if item.price then
            GameState:addMoney(-item.price)
        end

        Sound:play("cash")

        -- Start booster animation
        self:startBoosterAnimation()
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

function ShopState:startBoosterAnimation()
    self.phase = ShopState.PHASE.OPENING_BOOSTER

    local item = self.shopItems[self.selectedItemIndex]
    local centerX, centerY = item:getCenterPosition()

    self.boosterAnimation:start(centerX, centerY, function()
        self:showStickerSelection()
    end)
end

function ShopState:showStickerSelection()
    self.phase = ShopState.PHASE.SELECTING_STICKER

    -- Get 3 random stickers
    local stickerIds = Stickers:getRandomIds(3)

    self.stickerSelection:show(stickerIds, function(stickerId)
        self:onStickerSelected(stickerId)
    end)
end

function ShopState:onStickerSelected(stickerId)
    -- Add sticker to consumable slot
    GameState:addConsumable(stickerId)

    -- Mark the booster as sold
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
    self.stickerSelection:hide()
    self.boosterAnimation:reset()
end

-- Consumable management (reused from original)
function ShopState:onConsumableUse(slotIndex)
    self.showingDiceForEditor = true

    -- Set up random dice values for the editor
    for i = 1, 5 do
        local randomFaceIndex = math.random(1, 6)
        local faces = GameState:getDieFaces(i)
        local faceValue = faces[randomFaceIndex]
        GameState.dice[i].rolledFaceIndex = randomFaceIndex
        GameState.dice[i].value = faceValue
    end

    local buttonWidth = 200
    local buttonHeight = 60
    local centerX = Theme.layout.centerX + Theme.layout.centerWidth / 2
    local buttonY = Theme.layout.diceHomeY + 150

    self.editorCancelButton = Button.new({
        x = centerX - buttonWidth / 2,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight,
        text = "CANCEL",
        bgColor = Theme.colors.surface2,
        textColor = Theme.colors.text,
        hoverBgColor = Theme.colors.surfaceHighlight,
        font = Theme.fonts.large,
        onClick = function()
            self:cancelDiceEditor()
        end,
    })

    self.diceEditor:activate("shop", slotIndex, {
        onComplete = function()
            self.showingDiceForEditor = false
            self.editorCancelButton = nil
        end,
        onCancel = function()
            self.showingDiceForEditor = false
            self.editorCancelButton = nil
        end,
        getDicePositions = function()
            return self:getShopDicePositions()
        end,
    })
end

function ShopState:cancelDiceEditor()
    self.diceEditor:cancel()
    self.showingDiceForEditor = false
    self.editorCancelButton = nil
end

function ShopState:getShopDicePositions()
    local positions = {}
    local layout = Theme.layout
    local diceSize = 110
    local diceSpacing = 20
    local totalWidth = 5 * diceSize + 4 * diceSpacing
    local startX = layout.centerX + (layout.centerWidth - totalWidth) / 2
    local y = layout.diceHomeY

    for i = 1, 5 do
        positions[i] = {
            x = startX + (i - 1) * (diceSize + diceSpacing),
            y = y,
            width = diceSize,
            height = diceSize,
        }
    end
    return positions
end

function ShopState:onConsumableSell(slotIndex)
    local consumable = GameState:getConsumable(slotIndex)
    if not consumable then return end

    local sellPrice = Stickers:getSellPrice(consumable.stickerId)
    GameState:addMoney(sellPrice)
    GameState:removeConsumable(slotIndex)

    Sound:play("cash")
end

function ShopState:onConsumableDragEnd(slotIndex, x, y)
    self.dragZones:hide()

    local zone = self.dragZones:getZoneAtPosition(x, y)
    if zone == "delete" then
        GameState:removeConsumable(slotIndex)
        Sound:play("click")
    elseif zone == "sell" then
        self:onConsumableSell(slotIndex)
    end
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
    elseif self.phase == ShopState.PHASE.OPENING_BOOSTER then
        self:updateOpeningBooster(dt)
    elseif self.phase == ShopState.PHASE.SELECTING_STICKER then
        self:updateSelectingSticker(dt)
    end

    -- Update drag zones
    local dragSlot = self.itemStrip and self.itemStrip:getDraggingSlot()
    if dragSlot then
        local dragX, dragY = dragSlot:getDragPosition()
        self.dragZones:update(dt, dragX, dragY)
    else
        self.dragZones:update(dt, nil, nil)
    end

    -- Update dice editor
    self.diceEditor:update(dt)

    -- Update editor cancel button
    if self.editorCancelButton then
        self.editorCancelButton:update(dt)
    end
end

function ShopState:updateBrowsing(dt)
    -- Update shop items
    for _, item in ipairs(self.shopItems) do
        item:updateMouse(self.mouseX, self.mouseY)
        item:update(dt)
    end

    -- Update tooltip hover timer
    if self.hoveredItemIndex then
        self.hoverTimer = self.hoverTimer + dt
        if self.hoverTimer >= 1.0 then -- 1 second delay
            local item = self.shopItems[self.hoveredItemIndex]
            if item and item.name and item.name ~= "" and not item.sold then
                local centerX, centerY = item:getCenterPosition()
                -- Get description for relics
                local description = nil
                if item.itemType == "relic" and item.relicId then
                    local relicDef = Relics:get(item.relicId)
                    if relicDef then
                        description = relicDef.description
                    end
                end
                self.shopTooltip:show(item.name, centerX, centerY - GRID_ITEM_SIZE / 2, description)
            end
        end
    end

    -- Update tooltip
    self.shopTooltip:update(dt)

    -- Update next level button
    self.nextLevelButton:update(dt)
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
end

function ShopState:updateOpeningBooster(dt)
    self.boosterAnimation:update(dt)
end

function ShopState:updateSelectingSticker(dt)
    self.stickerSelection:updateMouse(self.mouseX, self.mouseY)
    self.stickerSelection:update(dt)
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

    -- Draw based on phase
    if self.showingDiceForEditor then
        self:drawShopDice()
    elseif self.phase == ShopState.PHASE.OPENING_BOOSTER then
        -- Draw booster animation on top (no shop items visible)
        self.boosterAnimation:draw()
    elseif self.phase == ShopState.PHASE.SELECTING_STICKER then
        self.stickerSelection:draw()
    else
        -- Normal browsing or item selected
        self:drawShopItems(1)
        self:drawButtons()
        self.shopTooltip:draw()
    end

    -- Draw drag zones
    self.dragZones:draw()

    -- Draw item strip again if dragging
    if self.itemStrip and self.itemStrip:isDragging() then
        self.itemStrip:draw()
    end

    -- Draw dice editor overlay
    if self.diceEditor.isActive then
        self.diceEditor:drawOverlay()
        self.diceEditor:drawInstructions()
        self.diceEditor:drawTooltip()
        self.diceEditor:drawConfirmationModal()
    end

    -- Draw editor cancel button
    if self.editorCancelButton and not self.diceEditor.showingConfirmation then
        self.editorCancelButton:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ShopState:drawShopItems(alpha)
    love.graphics.setColor(1, 1, 1, alpha)

    for i, item in ipairs(self.shopItems) do
        -- If opening booster, don't draw the selected item (it's being animated in center)
        if self.phase == ShopState.PHASE.OPENING_BOOSTER and i == self.selectedItemIndex then
            -- Skip
        else
            item:draw()
        end
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
    -- No buttons during OPENING_BOOSTER or SELECTING_STICKER phases
end

function ShopState:drawShopDice()
    local positions = self:getShopDicePositions()
    local diceSize = 110

    for i = 1, 5 do
        local pos = positions[i]
        local faceValue = GameState.dice[i].value

        self.nineSlice:draw(pos.x, pos.y, diceSize, diceSize, Theme.colors.surface2, Theme.nineSlice.borderScale)

        if Theme.diceSpritesheet then
            local quad = Theme.diceSpritesheet:getQuad(faceValue)
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
    -- Dice editor takes priority
    if self.diceEditor.isActive then
        if self.diceEditor:mousepressed(x, y, button) then
            return
        end

        if self.showingDiceForEditor and button == 1 then
            local positions = self:getShopDicePositions()
            for i = 1, 5 do
                local pos = positions[i]
                if x >= pos.x and x < pos.x + pos.width and
                    y >= pos.y and y < pos.y + pos.height then
                    self.diceEditor:selectDie(i)
                    return
                end
            end
        end
    end

    -- Editor cancel button
    if self.editorCancelButton and not self.diceEditor.showingConfirmation then
        if self.editorCancelButton:mousepressed(x, y, button) then
            return
        end
    end

    -- Don't process other clicks when showing dice editor
    if self.showingDiceForEditor then
        return
    end

    -- Item strip (consumables)
    if self.itemStrip and self.itemStrip:mousepressed(x, y, button) then
        return
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
    elseif self.phase == ShopState.PHASE.SELECTING_STICKER then
        if self.stickerSelection:mousepressed(x, y, button) then
            return
        end
    end

    -- Info panel
    if self.infoPanel then
        self.infoPanel:mousepressed(x, y, button)
    end
end

function ShopState:mousereleased(x, y, button)
    if self.editorCancelButton then
        self.editorCancelButton:mousereleased(x, y, button)
    end

    if self.itemStrip then
        self.itemStrip:mousereleased(x, y, button)
    end

    self.nextLevelButton:mousereleased(x, y, button)
    self.buyButton:mousereleased(x, y, button)
    self.cancelButton:mousereleased(x, y, button)

    if self.phase == ShopState.PHASE.SELECTING_STICKER then
        self.stickerSelection:mousereleased(x, y, button)
    end

    if self.infoPanel then
        self.infoPanel:mousereleased(x, y, button)
    end
end

function ShopState:mousemoved(x, y, dx, dy)
    if self.itemStrip then
        self.itemStrip:mousemoved(x, y, dx, dy)
    end
end

function ShopState:keypressed(key)
    -- Dice editor takes priority
    if self.diceEditor.isActive then
        if self.diceEditor:keypressed(key) then
            return
        end
    end

    if key == "escape" then
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
    end
end

return ShopState
