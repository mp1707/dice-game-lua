-- Central game state singleton
-- Holds all game data that persists across states

local Levels = require("src.game.levels")

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

    -- Dice state (5 dice)
    dice = {},

    -- Used hands this level (set of hand IDs)
    usedHands = {},

    -- Currently selected hand (nil if none) - DEPRECATED: kept for compatibility
    selectedHandId = nil,

    -- Rolling animation state
    isRolling = false,

    -- NEW: Selection state for Zahlen/Kombinationen system
    zahlenDice = {},           -- Array of dice indices selected for Zahlen (upper hands)
    kombinationenDice = {},    -- Array of dice indices selected for Kombinationen (lower hands)
    selectionMode = nil,       -- "zahlen" | "kombinationen" | nil
}

-- Initialize dice
function GameState:initDice()
    self.dice = {}
    for i = 1, 5 do
        self.dice[i] = {
            value = 1,
            locked = false,
        }
    end
end

-- Full game reset (new run)
function GameState:reset()
    self.currentLevel = 1
    self.money = 0
    self:resetForLevel()
end

-- Reset for new level
function GameState:resetForLevel()
    self.currentScore = 0
    self.handsRemaining = Levels.handsPerLevel
    self.usedHands = {}
    self:resetForHand()
end

-- Reset for new hand
function GameState:resetForHand()
    self.rollsRemaining = Levels.rollsPerHand
    self.hasRolledThisHand = false
    self.selectedHandId = nil
    self.isRolling = false
    self:clearAllSelections()
    self:unlockAllDice()
    self:initDice()
end

-- Unlock all dice
function GameState:unlockAllDice()
    for _, die in ipairs(self.dice) do
        die.locked = false
    end
end

-- Roll all unlocked dice
function GameState:rollDice()
    if not self:canRoll() then return false end

    for _, die in ipairs(self.dice) do
        if not die.locked then
            die.value = math.random(1, 6)
        end
    end

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
    return self.rollsRemaining > 0 and not self.isRolling
end

-- Check if hand is used
function GameState:isHandUsed(handId)
    return self.usedHands[handId] == true
end

-- Use a hand (mark as used, add score)
function GameState:useHand(handId, score)
    self.usedHands[handId] = true
    self.currentScore = self.currentScore + score
    self.handsRemaining = self.handsRemaining - 1
    self.selectedHandId = nil
end

-- Select a hand
function GameState:selectHand(handId)
    if self:isHandUsed(handId) then return false end
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
-- NEW: Selection system for Zahlen/Kombinationen
-- ============================================

-- Clear all selections and unlock dice
function GameState:clearAllSelections()
    self:clearZahlenSelection()
    self:clearKombinationenSelection()
    self.selectionMode = nil
end

-- Clear Zahlen selection
function GameState:clearZahlenSelection()
    for _, idx in ipairs(self.zahlenDice) do
        if self.dice[idx] then
            self.dice[idx].locked = false
        end
    end
    self.zahlenDice = {}
    if self.selectionMode == "zahlen" then
        self.selectionMode = nil
    end
end

-- Clear Kombinationen selection
function GameState:clearKombinationenSelection()
    for _, idx in ipairs(self.kombinationenDice) do
        if self.dice[idx] then
            self.dice[idx].locked = false
        end
    end
    self.kombinationenDice = {}
    if self.selectionMode == "kombinationen" then
        self.selectionMode = nil
    end
end

-- Select a die for Zahlen (upper section hands)
function GameState:selectDiceForZahlen(index)
    if not self.hasRolledThisHand then return false end
    if index < 1 or index > 5 then return false end
    if self:isDiceInZahlen(index) then return false end

    -- Clear kombinationen if switching
    if #self.kombinationenDice > 0 then
        self:clearKombinationenSelection()
    end

    -- Add to zahlen selection
    table.insert(self.zahlenDice, index)
    self.selectionMode = "zahlen"

    -- Lock the die
    self.dice[index].locked = true

    return true
end

-- Select a die for Kombinationen (lower section hands)
function GameState:selectDiceForKombinationen(index)
    if not self.hasRolledThisHand then return false end
    if index < 1 or index > 5 then return false end
    if self:isDiceInKombinationen(index) then return false end

    -- Clear zahlen if switching
    if #self.zahlenDice > 0 then
        self:clearZahlenSelection()
    end

    -- Add to kombinationen selection
    table.insert(self.kombinationenDice, index)
    self.selectionMode = "kombinationen"

    -- Lock the die
    self.dice[index].locked = true

    return true
end

-- Remove a die from selection (either Zahlen or Kombinationen)
function GameState:removeDiceFromSelection(index)
    -- Try to remove from Zahlen
    for i, idx in ipairs(self.zahlenDice) do
        if idx == index then
            table.remove(self.zahlenDice, i)
            self.dice[index].locked = false
            if #self.zahlenDice == 0 then
                self.selectionMode = nil
            end
            return true
        end
    end

    -- Try to remove from Kombinationen
    for i, idx in ipairs(self.kombinationenDice) do
        if idx == index then
            table.remove(self.kombinationenDice, i)
            self.dice[index].locked = false
            if #self.kombinationenDice == 0 then
                self.selectionMode = nil
            end
            return true
        end
    end

    return false
end

-- Check if a die is in Zahlen selection
function GameState:isDiceInZahlen(index)
    for _, idx in ipairs(self.zahlenDice) do
        if idx == index then return true end
    end
    return false
end

-- Check if a die is in Kombinationen selection
function GameState:isDiceInKombinationen(index)
    for _, idx in ipairs(self.kombinationenDice) do
        if idx == index then return true end
    end
    return false
end

-- Check if a die is selected (in either panel)
function GameState:isDiceSelected(index)
    return self:isDiceInZahlen(index) or self:isDiceInKombinationen(index)
end

-- Get the currently selected dice indices (from whichever panel is active)
function GameState:getSelectedDiceIndices()
    if self.selectionMode == "zahlen" then
        return self.zahlenDice
    elseif self.selectionMode == "kombinationen" then
        return self.kombinationenDice
    end
    return {}
end

-- Get count of selected dice
function GameState:getSelectedCount()
    return #self.zahlenDice + #self.kombinationenDice
end

return GameState
