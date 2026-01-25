-- Shop State - Upgrade shop between levels (Landscape layout)
-- Sells stickers that modify dice faces

local Theme = require("src.ui.theme")
local GameState = require("src.game.game_state")
local Levels = require("src.game.levels")
local Stickers = require("src.game.stickers")
local Button = require("src.ui.button")
local NineSlice = require("src.ui.nine_slice")
local InfoPanel = require("src.ui.info_panel")
local ItemStrip = require("src.ui.item_strip")
local DragZones = require("src.ui.drag_zones")
local DiceEditor = require("src.ui.dice_editor")
local Sound = require("src.core.sound")

local ShopState = {}
ShopState.__index = ShopState

function ShopState.new()
    local self = setmetatable({}, ShopState)

    self.nineSlice = NineSlice.getInstance()
    self.actionButton = nil
    self.stateMachine = nil
    self.infoPanel = nil
    self.itemStrip = nil

    -- Shop inventory (3 sticker offers)
    self.shopItems = {}
    self.shopItemButtons = {}

    -- Drag zones
    self.dragZones = DragZones.getInstance()

    -- Dice editor
    self.diceEditor = DiceEditor.getInstance()

    -- Shop dice display (for sticker use)
    self.showingDiceForEditor = false
    self.shopDiceValues = {} -- 5 random face values for display

    -- Cancel button for dice editor
    self.cancelButton = nil

    return self
end

function ShopState:enter(params)
    self.stateMachine = params.stateMachine
    self:initInfoPanel()
    self:initActionButton()
    self:initItemStrip()
    self:generateShopItems()
end

function ShopState:exit()
    self.diceEditor:deactivate()
end

function ShopState:initActionButton()
    local buttonWidth = Theme.layout.ctaWidth
    local buttonHeight = Theme.layout.ctaHeight

    local buttonText
    if Levels:isLastLevel(GameState.currentLevel) and GameState:hasReachedGoal() then
        buttonText = "VICTORY! NEW RUN"
    else
        buttonText = "NEXT LEVEL"
    end

    -- Center button in the center area (same as DualCta)
    local centerX = Theme.layout.centerX
    local centerWidth = Theme.layout.centerWidth
    local buttonX = centerX + (centerWidth - buttonWidth) / 2

    self.actionButton = Button.new({
        x = buttonX,
        y = Theme.layout.ctaY,
        width = buttonWidth,
        height = buttonHeight,
        text = buttonText,
        bgColor = Theme.colors.cyan,
        textColor = Theme.colors.text,
        hoverBgColor = { Theme.colors.cyan[1] * 0.9, Theme.colors.cyan[2] * 0.9, Theme.colors.cyan[3] * 0.9, 1 },
        disabledBgColor = Theme.colors.surface,
        disabledTextColor = Theme.colors.textMuted,
        font = Theme.fonts.large,
        onClick = function()
            self:onActionButtonClick()
        end,
    })
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
            return 1 -- Not relevant in shop
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

    -- Calculate centered position for item strip
    local totalWidth = 7 * layout.itemSlotSize + 4 * layout.itemSlotSpacing + layout.itemSlotGap + layout.itemSlotSpacing
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
            self.dragZones:show(slotIndex)
        end,
        onConsumableDragEnd = function(slotIndex, x, y)
            self:onConsumableDragEnd(slotIndex, x, y)
        end,
    })
end

function ShopState:generateShopItems()
    -- Generate 3 random sticker offers
    local stickerIds = Stickers:getRandomIds(3)
    self.shopItems = {}
    self.shopItemButtons = {}

    for i, stickerId in ipairs(stickerIds) do
        self.shopItems[i] = {
            stickerId = stickerId,
            sold = false,
        }
    end
end

function ShopState:purchaseItem(index)
    local item = self.shopItems[index]
    if not item or item.sold then return false end

    local sticker = Stickers:get(item.stickerId)
    if not sticker then return false end

    -- Check if player has enough money
    if GameState.money < sticker.buyPrice then
        Sound:play("click") -- Error sound
        return false
    end

    -- Check if there's room for consumable
    if not GameState:hasConsumableRoom() then
        Sound:play("click") -- Error sound
        return false
    end

    -- Make purchase
    GameState:addMoney(-sticker.buyPrice)
    GameState:addConsumable(item.stickerId)
    item.sold = true

    Sound:play("cash")
    return true
end

function ShopState:onConsumableUse(slotIndex)
    -- Show dice for editing in shop
    self.showingDiceForEditor = true

    -- Generate random dice display and set up dice state for editing
    -- Each die shows a random face, and that becomes the "rolled" face
    for i = 1, 5 do
        local randomFaceIndex = math.random(1, 6)
        self.shopDiceValues[i] = randomFaceIndex

        -- Set up the die's rolled state so the sticker can be applied
        local faces = GameState:getDieFaces(i)
        local faceValue = faces[randomFaceIndex]
        GameState.dice[i].rolledFaceIndex = randomFaceIndex
        GameState.dice[i].value = faceValue
    end

    -- Create cancel button
    local buttonWidth = 200
    local buttonHeight = 60
    local centerX = Theme.layout.centerX + Theme.layout.centerWidth / 2
    local buttonY = Theme.layout.diceHomeY + 150

    self.cancelButton = Button.new({
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

    -- Activate dice editor
    self.diceEditor:activate("shop", slotIndex, {
        onComplete = function()
            -- Editor completed - hide dice display
            self.showingDiceForEditor = false
            self.cancelButton = nil
        end,
        onCancel = function()
            -- Editor cancelled
            self.showingDiceForEditor = false
            self.cancelButton = nil
        end,
        getDicePositions = function()
            return self:getShopDicePositions()
        end,
    })
end

function ShopState:cancelDiceEditor()
    self.diceEditor:cancel()
    self.showingDiceForEditor = false
    self.cancelButton = nil
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
        -- Delete consumable (no money back)
        GameState:removeConsumable(slotIndex)
        Sound:play("click")
    elseif zone == "sell" then
        -- Sell consumable
        self:onConsumableSell(slotIndex)
    end
end

function ShopState:onActionButtonClick()
    -- Check if game is won
    if Levels:isLastLevel(GameState.currentLevel) and GameState:hasReachedGoal() then
        -- Game complete! Start new run
        GameState:reset()
        self.stateMachine:change("play", {
            stateMachine = self.stateMachine,
        })
    else
        -- Advance to next level
        GameState:advanceLevel()
        self.stateMachine:change("play", {
            stateMachine = self.stateMachine,
        })
    end
end

function ShopState:update(dt)
    self.actionButton:update(dt)
    if self.infoPanel then
        self.infoPanel:update(dt)
    end
    if self.itemStrip then
        self.itemStrip:update(dt)
    end

    -- Update cancel button if showing dice
    if self.cancelButton then
        self.cancelButton:update(dt)
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
end

function ShopState:draw()
    -- Draw item strip at top
    if self.itemStrip and not self.itemStrip:isDragging() then
        self.itemStrip:draw()
    end

    -- If showing dice for editor, draw dice instead of shop panel
    if self.showingDiceForEditor then
        self:drawShopDice()
    else
        -- Center content panel (aligned with Center Area and above CTA)
        local panelWidth = 600
        local panelHeight = 480

        local centerAreaX = Theme.layout.centerX
        local centerAreaWidth = Theme.layout.centerWidth

        local panelX = centerAreaX + (centerAreaWidth - panelWidth) / 2
        local panelY = 150

        self.nineSlice:draw(panelX, panelY, panelWidth, panelHeight, Theme.colors.surface, Theme.nineSlice.borderScale)

        -- Title
        Theme:drawTextCenteredWithShadow("SHOP", panelX, panelY + 25, panelWidth, Theme.fonts.display, Theme.colors.cyan)

        -- Current money
        local moneyText = "$" .. tostring(GameState.money)
        Theme:drawTextCenteredWithShadow(moneyText, panelX, panelY + 80, panelWidth, Theme.fonts.large, Theme.colors.gold)

        -- Stickers section label
        Theme:drawTextCenteredWithShadow("Stickers", panelX, panelY + 130, panelWidth, Theme.fonts.normal,
            Theme.colors.textMuted)

        -- Draw shop items (3 stickers)
        local itemSize = 100
        local itemSpacing = 30
        local totalItemsWidth = 3 * itemSize + 2 * itemSpacing
        local startX = panelX + (panelWidth - totalItemsWidth) / 2
        local itemY = panelY + 160

        for i, item in ipairs(self.shopItems) do
            local itemX = startX + (i - 1) * (itemSize + itemSpacing)
            self:drawShopItem(itemX, itemY, itemSize, item, i)
        end

        -- Level info
        local levelText = "Level " .. tostring(GameState.currentLevel) .. " / " .. tostring(Levels.totalLevels)
        Theme:drawTextCenteredWithShadow(levelText, panelX, panelY + 340, panelWidth, Theme.fonts.normal, Theme.colors.text)

        -- Next goal preview
        if not Levels:isLastLevel(GameState.currentLevel) then
            local nextGoal = Levels:getGoal(GameState.currentLevel + 1)
            local nextText = "Next Goal: " .. tostring(nextGoal)
            Theme:drawTextCenteredWithShadow(nextText, panelX, panelY + 370, panelWidth, Theme.fonts.normal,
                Theme.colors.textMuted)
        else
            Theme:drawTextCenteredWithShadow("LAST LEVEL CLEARED!", panelX, panelY + 370, panelWidth,
                Theme.fonts.normal, Theme.colors.mint)
        end

        -- Consumables full warning
        if not GameState:hasConsumableRoom() then
            Theme:drawTextCenteredWithShadow("Consumable slots full!", panelX, panelY + 410, panelWidth,
                Theme.fonts.small, Theme.colors.coral)
        end

        -- Action button
        self.actionButton:draw()
    end

    -- Draw info panel (left side)
    if self.infoPanel then
        self.infoPanel:draw()
    end

    -- Draw drag zones (on top)
    self.dragZones:draw()

    -- Draw item strip again if dragging (so dragged item is on top)
    if self.itemStrip and self.itemStrip:isDragging() then
        self.itemStrip:draw()
    end

    -- Draw dice editor overlay if active
    if self.diceEditor.isActive then
        self.diceEditor:drawOverlay()
        self.diceEditor:drawInstructions()
        self.diceEditor:drawTooltip()
        self.diceEditor:drawConfirmationModal()
    end

    -- Draw cancel button if showing dice
    if self.cancelButton and not self.diceEditor.showingConfirmation then
        self.cancelButton:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ShopState:drawShopDice()
    local positions = self:getShopDicePositions()
    local diceSize = 110

    for i = 1, 5 do
        local pos = positions[i]
        -- Use the die's current value (set up in onConsumableUse)
        local faceValue = GameState.dice[i].value

        -- Draw die background
        self.nineSlice:draw(pos.x, pos.y, diceSize, diceSize, Theme.colors.surface2, Theme.nineSlice.borderScale)

        -- Draw die face sprite
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

        -- Draw die number label below
        love.graphics.setColor(Theme.colors.textMuted)
        local font = Theme.fonts.small
        love.graphics.setFont(font)
        local label = "Die " .. i
        local labelWidth = font:getWidth(label)
        love.graphics.print(label, pos.x + (diceSize - labelWidth) / 2, pos.y + diceSize + 5)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ShopState:drawShopItem(x, y, size, item, index)
    local sticker = Stickers:get(item.stickerId)
    if not sticker then return end

    -- Check if hovered
    local mx, my = love.mouse.getPosition()
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end
    local isHovered = mx and my and mx >= x and mx < x + size and my >= y and my < size + 60 + y

    -- Background
    local bgColor = item.sold and Theme.colors.panelDark or
        (isHovered and Theme.colors.surfaceHighlight or Theme.colors.surface2)
    self.nineSlice:draw(x, y, size, size + 60, bgColor, Theme.nineSlice.borderScale)

    if item.sold then
        -- SOLD label
        Theme:drawTextCenteredWithShadow("SOLD", x, y + size / 2, size, Theme.fonts.large, Theme.colors.textMuted)
    else
        -- Draw sticker sprite
        if Theme.diceSpritesheet then
            local spriteSize = size * 0.85
            local spriteX = x + (size - spriteSize) / 2
            local spriteY = y + 5

            local quad = Theme.diceSpritesheet:getQuad(sticker.spriteId)
            local image = Theme.diceSpritesheet:getImage()

            love.graphics.setColor(1, 1, 1, 1)
            local spriteW, _ = Theme.diceSpritesheet:getSpriteSize()
            local scale = spriteSize / spriteW
            love.graphics.draw(image, quad, spriteX, spriteY, 0, scale, scale)
        end

        -- Sticker name
        Theme:drawTextCenteredWithShadow(sticker.name, x, y + size - 15, size, Theme.fonts.small, Theme.colors.text)

        -- Price
        local canAfford = GameState.money >= sticker.buyPrice
        local priceColor = canAfford and Theme.colors.gold or Theme.colors.coral
        local priceText = "$" .. sticker.buyPrice
        Theme:drawTextCenteredWithShadow(priceText, x, y + size + 15, size, Theme.fonts.normal, priceColor)

        -- BUY button
        local buttonY = y + size + 35
        local buttonHeight = 22
        local buttonColor = canAfford and Theme.colors.cyan or Theme.colors.surface
        self.nineSlice:draw(x + 10, buttonY, size - 20, buttonHeight, buttonColor, Theme.nineSlice.borderScale)

        local buyTextColor = canAfford and Theme.colors.textDark or Theme.colors.textMuted
        love.graphics.setColor(buyTextColor)
        love.graphics.setFont(Theme.fonts.small)
        local buyText = "BUY"
        local buyTextWidth = Theme.fonts.small:getWidth(buyText)
        love.graphics.print(buyText, x + (size - buyTextWidth) / 2, buttonY + 3)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ShopState:mousepressed(x, y, button)
    -- Dice editor takes priority
    if self.diceEditor.isActive then
        if self.diceEditor:mousepressed(x, y, button) then
            return
        end

        -- In editor mode in shop, clicking on a die should select it
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

    -- Cancel button when showing dice
    if self.cancelButton and not self.diceEditor.showingConfirmation then
        if self.cancelButton:mousepressed(x, y, button) then
            return
        end
    end

    -- Don't process shop clicks when showing dice
    if self.showingDiceForEditor then
        return
    end

    -- Check shop item clicks
    if button == 1 then
        local clickedItem = self:getShopItemAtPosition(x, y)
        if clickedItem then
            self:purchaseItem(clickedItem)
            return
        end
    end

    -- Item strip (consumables)
    if self.itemStrip and self.itemStrip:mousepressed(x, y, button) then
        return
    end

    self.actionButton:mousepressed(x, y, button)
    if self.infoPanel then
        self.infoPanel:mousepressed(x, y, button)
    end
end

function ShopState:mousereleased(x, y, button)
    if self.cancelButton then
        self.cancelButton:mousereleased(x, y, button)
    end

    if self.itemStrip then
        self.itemStrip:mousereleased(x, y, button)
    end

    self.actionButton:mousereleased(x, y, button)
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
        -- If item strip has selection, deselect
        if self.itemStrip then
            self.itemStrip:deselectAll()
        end
        return
    end

    if key == "space" or key == "return" then
        self:onActionButtonClick()
    end
end

function ShopState:getShopItemAtPosition(x, y)
    local panelWidth = 600
    local panelX = Theme.layout.centerX + (Theme.layout.centerWidth - panelWidth) / 2
    local panelY = 150

    local itemSize = 100
    local itemSpacing = 30
    local totalItemsWidth = 3 * itemSize + 2 * itemSpacing
    local startX = panelX + (panelWidth - totalItemsWidth) / 2
    local itemY = panelY + 160

    for i, item in ipairs(self.shopItems) do
        if not item.sold then
            local itemX = startX + (i - 1) * (itemSize + itemSpacing)
            -- Check if click is on the BUY button
            local buttonY = itemY + itemSize + 35
            local buttonHeight = 22
            if x >= itemX + 10 and x < itemX + itemSize - 10 and
                y >= buttonY and y < buttonY + buttonHeight then
                return i
            end
        end
    end

    return nil
end

return ShopState
