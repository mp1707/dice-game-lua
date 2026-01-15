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

    -- Currently selected hand (nil if none)
    selectedHandId = nil,

    -- Rolling animation state
    isRolling = false,
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

return GameState
