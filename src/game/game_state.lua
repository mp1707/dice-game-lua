-- Central game state singleton
-- Holds all game data that persists across states

local Levels = require("src.game.levels")
local Sound = require("src.core.sound")

local GameState = {
    -- Run state (persists across levels)
    currentLevel = 1,
    money = 0,

    -- Level state (resets each level)
    currentScore = 0,
    handsRemaining = 4,

    -- Hand state (resets each hand)
    rollsRemaining = 3,
    hasRolledThisHand = false,

    -- Dice state (5 dice with customizable faces)
    dice = {},

    -- Consumables (stickers in slots 6-7 of item strip)
    consumables = { nil, nil }, -- Max 2 consumable slots

    -- Relics (passive items in slots 1-5 of item strip)
    relics = { nil, nil, nil, nil, nil }, -- Max 5 relic slots

    -- Dice editor state
    editorMode = false,      -- True when editing dice faces
    activeSticker = nil,     -- Currently selected sticker for editing

    -- Used hands this level (set of hand IDs)


    -- Rolling animation state
    isRolling = false,

    -- Selection state (unified system)
    selectedDice = {},    -- Array of dice indices that are selected
    selectedHandId = nil, -- Currently selected hand card for playing
}

-- Initialize dice (preserves custom faces and prismatic state if they exist)
function GameState:initDice()
    for i = 1, 5 do
        if not self.dice[i] then
            self.dice[i] = {
                value = 1,
                locked = false,
                faces = { 1, 2, 3, 4, 5, 6 }, -- Default standard faces
                rolledFaceIndex = nil,        -- Which face index was rolled
                prismatic = false,            -- Prismatic state (from Prism relic)
            }
        else
            -- Reset per-hand state but preserve faces and prismatic
            self.dice[i].value = 1
            self.dice[i].locked = false
            self.dice[i].rolledFaceIndex = nil
            -- Ensure faces array exists (for backwards compatibility)
            if not self.dice[i].faces then
                self.dice[i].faces = { 1, 2, 3, 4, 5, 6 }
            end
            -- Ensure prismatic field exists (for backwards compatibility)
            if self.dice[i].prismatic == nil then
                self.dice[i].prismatic = false
            end
        end
    end
end

-- Full game reset (new run)
function GameState:reset()
    self.currentLevel = 1
    self.money = 0
    -- Reset dice to default faces (clears prismatic state)
    self.dice = {}
    -- Clear consumables
    self.consumables = { nil, nil }
    -- Clear relics
    self.relics = { nil, nil, nil, nil, nil }
    self.editorMode = false
    self.activeSticker = nil
    self:resetForLevel()
end

-- Reset for new level
function GameState:resetForLevel()
    self.currentScore = 0
    self.handsRemaining = Levels.handsPerLevel
    self:resetForHand()
end

-- Reset for new hand
function GameState:resetForHand()
    self.rollsRemaining = Levels.rollsPerHand
    self.hasRolledThisHand = false
    self.selectedHandId = nil
    self.isRolling = false
    self:clearSelection()
    self:unlockAllDice()
    self:initDice()
end

-- Unlock all dice
function GameState:unlockAllDice()
    for _, die in ipairs(self.dice) do
        die.locked = false
    end
end

-- Roll all selected dice (or all dice if first roll)
function GameState:rollDice()
    if not self:canRoll() then return false end

    local isFirstRoll = not self.hasRolledThisHand

    for i, die in ipairs(self.dice) do
        -- Reroll if it's the first roll OR if the die is selected (locked)
        if isFirstRoll or die.locked then
            -- Pick a random face from this die's faces array
            local faceIndex = math.random(1, 6)
            die.rolledFaceIndex = faceIndex
            -- Get the value from the faces array (supports custom faces)
            die.value = die.faces[faceIndex]
            -- If rerolled, it should be unlocked immediately
            die.locked = false
        end
    end

    -- Clear selection list since we just used it/unlocked everything
    self:clearSelection()

    self.rollsRemaining = self.rollsRemaining - 1
    self.hasRolledThisHand = true
    return true
end

-- Toggle dice lock
function GameState:toggleLock(index)
    if not self.hasRolledThisHand then return end
    if index < 1 or index > 5 then return end

    self.dice[index].locked = not self.dice[index].locked
end

-- Explicitly lock a die
function GameState:lockDice(index)
    if not self.hasRolledThisHand then return end
    if index < 1 or index > 5 then return end

    self.dice[index].locked = true
end

-- Explicitly unlock a die
function GameState:unlockDice(index)
    if not self.hasRolledThisHand then return end
    if index < 1 or index > 5 then return end

    self.dice[index].locked = false
end

-- Get count of locked dice
function GameState:getLockedCount()
    local count = 0
    for _, die in ipairs(self.dice) do
        if die.locked then
            count = count + 1
        end
    end
    return count
end

-- Check if can roll
function GameState:canRoll()
    if self.rollsRemaining <= 0 or self.isRolling then
        return false
    end

    -- If we have rolled already, we must have at least one die selected to reroll
    if self.hasRolledThisHand and self:getSelectedCount() == 0 then
        return false
    end

    return true
end

-- Use a hand (add score, hands can be repeated)
function GameState:useHand(handId, score)
    self.currentScore = self.currentScore + score
    self.handsRemaining = self.handsRemaining - 1
    self.selectedHandId = nil
end

-- Select a hand
function GameState:selectHand(handId)
    self.selectedHandId = handId
    return true
end

-- Deselect hand
function GameState:deselectHand()
    self.selectedHandId = nil
end

-- Check if level goal reached
function GameState:hasReachedGoal()
    return self.currentScore >= Levels:getGoal(self.currentLevel)
end

-- Check if level is lost (no hands remaining and score < goal)
function GameState:hasLostLevel()
    return self.handsRemaining <= 0 and not self:hasReachedGoal()
end

-- Check if all hands are used
function GameState:allHandsUsed()
    return self.handsRemaining <= 0
end

-- Add money
function GameState:addMoney(amount)
    self.money = self.money + amount
end

-- Advance to next level
function GameState:advanceLevel()
    self.currentLevel = self.currentLevel + 1
    self:resetForLevel()
end

-- Get current level goal
function GameState:getCurrentGoal()
    return Levels:getGoal(self.currentLevel)
end

-- Check if game is won (all levels complete)
function GameState:hasWonGame()
    return Levels:isLastLevel(self.currentLevel) and self:hasReachedGoal()
end

-- ============================================
-- Unified Selection System
-- ============================================

-- Clear all selections and unlock dice
function GameState:clearSelection()
    for _, idx in ipairs(self.selectedDice) do
        if self.dice[idx] then
            self.dice[idx].locked = false
        end
    end
    self.selectedDice = {}
    self.selectedHandId = nil
end

-- Toggle dice selection
function GameState:toggleDiceSelection(index, suppressSound)
    if not self.hasRolledThisHand then return false end
    if index < 1 or index > 5 then return false end

    -- Check if already selected
    for i, idx in ipairs(self.selectedDice) do
        if idx == index then
            -- Deselect: remove from array and unlock
            if not suppressSound then
                Sound:play("click")
            end
            table.remove(self.selectedDice, i)
            self.dice[index].locked = false
            -- Clear hand selection when dice change
            self.selectedHandId = nil
            return true
        end
    end

    -- Select: add to array and lock
    if not suppressSound then
        Sound:play("lightClick")
    end
    table.insert(self.selectedDice, index)
    self.dice[index].locked = true
    -- Clear hand selection when dice change
    self.selectedHandId = nil
    return true
end

-- Check if a die is selected
function GameState:isDiceSelected(index)
    for _, idx in ipairs(self.selectedDice) do
        if idx == index then return true end
    end
    return false
end

-- Get selected dice indices
function GameState:getSelectedDiceIndices()
    return self.selectedDice
end

-- Get count of selected dice
function GameState:getSelectedCount()
    return #self.selectedDice
end

-- Set the selected hand (for hand card selection)
function GameState:setSelectedHand(handId)
    self.selectedHandId = handId
end

-- Get the selected hand
function GameState:getSelectedHand()
    return self.selectedHandId
end

-- ============================================
-- Consumable System
-- ============================================

-- Add a consumable (sticker) to inventory
-- Returns slot index (1 or 2) if successful, nil if no room
function GameState:addConsumable(stickerId)
    for i = 1, 2 do
        if not self.consumables[i] then
            self.consumables[i] = { stickerId = stickerId }
            return i
        end
    end
    return nil -- No room
end

-- Remove a consumable from inventory
-- Returns the removed consumable data or nil
function GameState:removeConsumable(index)
    if index < 1 or index > 2 then return nil end
    local removed = self.consumables[index]
    self.consumables[index] = nil
    return removed
end

-- Get consumable at index
function GameState:getConsumable(index)
    if index < 1 or index > 2 then return nil end
    return self.consumables[index]
end

-- Check if there's room for another consumable
function GameState:hasConsumableRoom()
    return not self.consumables[1] or not self.consumables[2]
end

-- Get count of consumables
function GameState:getConsumableCount()
    local count = 0
    for i = 1, 2 do
        if self.consumables[i] then
            count = count + 1
        end
    end
    return count
end

-- ============================================
-- Dice Face Customization
-- ============================================

-- Set a specific face value on a die
-- dieIndex: 1-5 (which die)
-- faceIndex: 1-6 (which face position)
-- value: the new value for that face (1-6)
function GameState:setDieFace(dieIndex, faceIndex, value)
    if dieIndex < 1 or dieIndex > 5 then return false end
    if faceIndex < 1 or faceIndex > 6 then return false end
    if not self.dice[dieIndex] then return false end

    -- Ensure faces array exists
    if not self.dice[dieIndex].faces then
        self.dice[dieIndex].faces = { 1, 2, 3, 4, 5, 6 }
    end

    self.dice[dieIndex].faces[faceIndex] = value

    -- If this is the currently rolled face, update the displayed value too
    if self.dice[dieIndex].rolledFaceIndex == faceIndex then
        self.dice[dieIndex].value = value
    end

    return true
end

-- Get all faces for a die
function GameState:getDieFaces(dieIndex)
    if dieIndex < 1 or dieIndex > 5 then return nil end
    if not self.dice[dieIndex] then return nil end
    return self.dice[dieIndex].faces or { 1, 2, 3, 4, 5, 6 }
end

-- Get a specific face value from a die
function GameState:getDieFace(dieIndex, faceIndex)
    local faces = self:getDieFaces(dieIndex)
    if not faces then return nil end
    if faceIndex < 1 or faceIndex > 6 then return nil end
    return faces[faceIndex]
end

-- ============================================
-- Dice Editor Mode
-- ============================================

-- Enter dice editor mode with a sticker
function GameState:enterEditorMode(consumableIndex)
    if consumableIndex < 1 or consumableIndex > 2 then return false end
    local consumable = self.consumables[consumableIndex]
    if not consumable then return false end

    self.editorMode = true
    self.activeSticker = {
        consumableIndex = consumableIndex,
        stickerId = consumable.stickerId,
    }
    return true
end

-- Exit dice editor mode
function GameState:exitEditorMode()
    self.editorMode = false
    self.activeSticker = nil
end

-- Check if in editor mode
function GameState:isInEditorMode()
    return self.editorMode
end

-- Get active sticker info
function GameState:getActiveSticker()
    return self.activeSticker
end

-- ============================================
-- Relic System
-- ============================================

-- Add a relic to inventory
-- Returns slot index (1-5) if successful, nil if no room
function GameState:addRelic(relicId)
    for i = 1, 5 do
        if not self.relics[i] then
            self.relics[i] = { relicId = relicId }
            return i
        end
    end
    return nil -- No room
end

-- Remove a relic from inventory
-- Returns the removed relic data or nil
function GameState:removeRelic(index)
    if index < 1 or index > 5 then return nil end
    local removed = self.relics[index]
    self.relics[index] = nil
    return removed
end

-- Get relic at index
function GameState:getRelic(index)
    if index < 1 or index > 5 then return nil end
    return self.relics[index]
end

-- Check if player has a specific relic (by ID)
function GameState:hasRelic(relicId)
    for i = 1, 5 do
        if self.relics[i] and self.relics[i].relicId == relicId then
            return true
        end
    end
    return false
end

-- Check if there's room for another relic
function GameState:hasRelicRoom()
    for i = 1, 5 do
        if not self.relics[i] then
            return true
        end
    end
    return false
end

-- Get count of relics
function GameState:getRelicCount()
    local count = 0
    for i = 1, 5 do
        if self.relics[i] then
            count = count + 1
        end
    end
    return count
end

-- ============================================
-- Prismatic Dice System
-- ============================================

-- Set prismatic state on a die
function GameState:setPrismatic(dieIndex, isPrismatic)
    if dieIndex < 1 or dieIndex > 5 then return false end
    if not self.dice[dieIndex] then return false end
    self.dice[dieIndex].prismatic = isPrismatic
    return true
end

-- Check if a die is prismatic
function GameState:isPrismatic(dieIndex)
    if dieIndex < 1 or dieIndex > 5 then return false end
    if not self.dice[dieIndex] then return false end
    return self.dice[dieIndex].prismatic == true
end

-- Get all prismatic dice indices
function GameState:getPrismaticDice()
    local indices = {}
    for i = 1, 5 do
        if self.dice[i] and self.dice[i].prismatic then
            table.insert(indices, i)
        end
    end
    return indices
end

-- Get dice data (for use by UI components)
function GameState:getDiceData(dieIndex)
    if dieIndex < 1 or dieIndex > 5 then return nil end
    return self.dice[dieIndex]
end

return GameState
