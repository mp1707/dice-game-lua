-- Level configuration
-- Goals and progression data

local Levels = {
    -- Score goals for each level
    goals = {50, 80, 120, 180, 250, 350, 480, 650},

    -- Game constants
    handsPerLevel = 4,
    rollsPerHand = 3,
    totalLevels = 8,

    -- Reward configuration
    baseReward = 10,
    bonusPerUnusedHand = 2,
}

function Levels:getGoal(level)
    return self.goals[level] or self.goals[#self.goals]
end

function Levels:isLastLevel(level)
    return level >= self.totalLevels
end

function Levels:calculateReward(handsRemaining)
    return self.baseReward + (handsRemaining * self.bonusPerUnusedHand)
end

return Levels
