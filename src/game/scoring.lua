-- Scoring logic
-- Pure functions for calculating Yahtzee scores

local Hands = require("src.game.hands")

local Scoring = {}

-- Helper: Count occurrences of each face value (1-6)
local function countFaces(dice)
    local counts = { 0, 0, 0, 0, 0, 0 }
    for _, die in ipairs(dice) do
        if die.value >= 1 and die.value <= 6 then
            counts[die.value] = counts[die.value] + 1
        end
    end
    return counts
end

-- Helper: Get dice values as array
local function getValues(dice)
    local values = {}
    for i, die in ipairs(dice) do
        values[i] = die.value
    end
    return values
end

-- Helper: Sum all dice
local function sumAll(dice)
    local sum = 0
    for _, die in ipairs(dice) do
        sum = sum + die.value
    end
    return sum
end

-- Helper: Sum dice matching a specific face
local function sumMatching(dice, face)
    local sum = 0
    for _, die in ipairs(dice) do
        if die.value == face then
            sum = sum + die.value
        end
    end
    return sum
end

-- Helper: Check for N of a kind
local function hasNOfKind(counts, n)
    for _, count in ipairs(counts) do
        if count >= n then
            return true
        end
    end
    return false
end

-- Helper: Check for full house (3 + 2)
local function isFullHouse(counts)
    local hasThree, hasTwo = false, false
    for _, count in ipairs(counts) do
        if count == 3 then hasThree = true end
        if count == 2 then hasTwo = true end
    end
    return hasThree and hasTwo
end

-- Helper: Create unique set of values
local function getUniqueSet(dice)
    local set = {}
    for _, die in ipairs(dice) do
        set[die.value] = true
    end
    return set
end

-- Helper: Check for small straight (4 consecutive)
local function isSmallStraight(dice)
    local unique = getUniqueSet(dice)
    -- Check for 1-2-3-4, 2-3-4-5, or 3-4-5-6
    return (unique[1] and unique[2] and unique[3] and unique[4]) or
        (unique[2] and unique[3] and unique[4] and unique[5]) or
        (unique[3] and unique[4] and unique[5] and unique[6])
end

-- Helper: Check for large straight (5 consecutive)
local function isLargeStraight(dice)
    local unique = getUniqueSet(dice)
    local count = 0
    for _ in pairs(unique) do count = count + 1 end

    if count ~= 5 then return false end

    -- Check for 1-2-3-4-5 or 2-3-4-5-6
    return (unique[1] and unique[2] and unique[3] and unique[4] and unique[5]) or
        (unique[2] and unique[3] and unique[4] and unique[5] and unique[6])
end

-- Map upper hand IDs to face values
local upperFaceMap = {
    ones = 1,
    twos = 2,
    threes = 3,
    fours = 4,
    fives = 5,
    sixes = 6,
}

-- Check if a hand pattern is valid for current dice
function Scoring.isValidHand(handId, dice)
    local counts = countFaces(dice)

    -- Upper section hands always return true (can score 0)
    if upperFaceMap[handId] then
        return true
    end

    -- Lower section hands require pattern matching
    if handId == "threeOfKind" then
        return hasNOfKind(counts, 3)
    elseif handId == "fourOfKind" then
        return hasNOfKind(counts, 4)
    elseif handId == "yahtzee" then
        return hasNOfKind(counts, 5)
    elseif handId == "fullHouse" then
        return isFullHouse(counts)
    elseif handId == "smallStraight" then
        return isSmallStraight(dice)
    elseif handId == "largeStraight" then
        return isLargeStraight(dice)
    end

    return false
end

-- Calculate score for a hand
-- Formula: score = (basePoints + pips) * mult
function Scoring.calculateScore(handId, dice)
    local handDef = Hands:get(handId)
    if not handDef then return 0 end

    local basePoints = handDef.basePoints
    local mult = handDef.mult
    local pips = 0

    if handDef.section == "upper" then
        -- Upper hands: pips = sum of matching dice only
        local face = upperFaceMap[handId]
        pips = sumMatching(dice, face)
    else
        -- Lower hands: pips = sum of all dice (if valid pattern)
        if Scoring.isValidHand(handId, dice) then
            pips = sumAll(dice)
        else
            return 0 -- Invalid pattern scores 0
        end
    end

    return (basePoints + pips) * mult
end

-- Get detailed score breakdown for display
function Scoring.getBreakdown(handId, dice)
    local handDef = Hands:get(handId)
    if not handDef then
        return nil
    end

    local basePoints = handDef.basePoints
    local mult = handDef.mult
    local pips = 0
    local isValid = Scoring.isValidHand(handId, dice)

    if handDef.section == "upper" then
        local face = upperFaceMap[handId]
        pips = sumMatching(dice, face)
    elseif isValid then
        pips = sumAll(dice)
    end

    local total = isValid and ((basePoints + pips) * mult) or 0

    return {
        basePoints = basePoints,
        pips = pips,
        mult = mult,
        total = total,
        isValid = isValid,
    }
end

-- ============================================
-- NEW: Detection functions for Zahlen/Kombinationen system
-- ============================================

-- Priority order for Kombinationen (lower section hands)
-- Higher index = lower priority
local KOMBINATIONEN_PRIORITY = {
    "yahtzee",       -- 1st priority
    "largeStraight", -- 2nd priority
    "smallStraight", -- 3rd priority
    "fullHouse",     -- 4th priority
    "fourOfKind",    -- 5th priority
    "threeOfKind",   -- 6th priority
}

-- Detect the best (highest priority) Kombinationen pattern for given dice
-- Returns the hand ID of the highest valid pattern, or nil if none
function Scoring.detectBestKombination(dice)
    for _, handId in ipairs(KOMBINATIONEN_PRIORITY) do
        if Scoring.isValidHand(handId, dice) then
            return handId
        end
    end
    return nil
end

-- Detect the best Kombinationen pattern for ONLY the selected dice
-- This builds a subset of dice from the indices and checks patterns against it
-- Returns the hand ID of the highest valid pattern, or nil if none
function Scoring.detectBestKombinationFromIndices(selectedIndices, dice)
    if #selectedIndices == 0 then
        return nil
    end

    -- Build a dice array from only the selected indices
    local selectedDice = {}
    for _, idx in ipairs(selectedIndices) do
        if dice[idx] then
            table.insert(selectedDice, { value = dice[idx].value })
        end
    end

    -- Check patterns against the selected dice only
    for _, handId in ipairs(KOMBINATIONEN_PRIORITY) do
        if Scoring.isValidHand(handId, selectedDice) then
            return handId
        end
    end
    return nil
end

-- Map face values to hand IDs for Zahlen
local faceToHandId = {
    [1] = "ones",
    [2] = "twos",
    [3] = "threes",
    [4] = "fours",
    [5] = "fives",
    [6] = "sixes",
}

-- Detect the Zahlen hand based on selected dice indices
-- Returns the hand ID for the highest face value among selected dice
function Scoring.detectZahlenHand(selectedIndices, dice)
    if #selectedIndices == 0 then
        return nil
    end

    local counts = { 0, 0, 0, 0, 0, 0 }
    for _, idx in ipairs(selectedIndices) do
        if dice[idx] then
            local val = dice[idx].value
            if val >= 1 and val <= 6 then
                counts[val] = counts[val] + 1
            end
        end
    end

    local bestFace = 0
    local maxCount = -1

    -- Iterate from 6 down to 1 to prioritize higher face value on ties
    for face = 6, 1, -1 do
        if counts[face] > maxCount then
            maxCount = counts[face]
            bestFace = face
        end
    end

    if bestFace == 0 then return nil end
    return faceToHandId[bestFace]
end

-- Get the face value from a hand ID (for display purposes)
function Scoring.getFaceFromHandId(handId)
    return upperFaceMap[handId]
end

-- Check if a hand ID is an upper section (Zahlen) hand
function Scoring.isUpperSectionHand(handId)
    return upperFaceMap[handId] ~= nil
end

-- Check if a hand ID is a lower section (Kombinationen) hand
function Scoring.isLowerSectionHand(handId)
    return handId == "threeOfKind" or
        handId == "fourOfKind" or
        handId == "yahtzee" or
        handId == "fullHouse" or
        handId == "smallStraight" or
        handId == "largeStraight"
end

-- Get the dice values that contribute to a hand's score display
-- For Zahlen: returns values matching the highest face
-- For Kombinationen: returns all selected dice values
function Scoring.getScoringDiceForHand(handId, selectedIndices, dice)
    if #selectedIndices == 0 then
        return {}
    end

    local scoringValues = {}

    if Scoring.isUpperSectionHand(handId) then
        -- For Zahlen: only dice matching the target face value
        local targetFace = upperFaceMap[handId]
        for _, idx in ipairs(selectedIndices) do
            if dice[idx] and dice[idx].value == targetFace then
                table.insert(scoringValues, targetFace)
            end
        end
    elseif handId == "smallStraight" or handId == "largeStraight" then
        -- Straights: Extract unique sorted values and find the consecutive sequence
        local values = {}
        for _, idx in ipairs(selectedIndices) do
            if dice[idx] then
                table.insert(values, dice[idx].value)
            end
        end
        table.sort(values)

        -- Get unique values sorted
        local unique = {}
        local seen = {}
        for _, v in ipairs(values) do
            if not seen[v] then
                table.insert(unique, v)
                seen[v] = true
            end
        end

        -- Find the sequence
        local reqLen = (handId == "largeStraight") and 5 or 4

        -- Try to find a consecutive run of required length
        local bestRun = {}

        for i = 1, #unique - reqLen + 1 do
            local run = {}
            local isConsecutive = true
            for j = 0, reqLen - 1 do
                if unique[i + j] ~= unique[i] + j then
                    isConsecutive = false
                    break
                end
                table.insert(run, unique[i + j])
            end

            if isConsecutive then
                bestRun = run
                break -- Found the straight, use it
            end
        end

        scoringValues = bestRun
    elseif handId == "fullHouse" then
        -- Full House: Sort all selected dice ascending
        -- User requested: "always order full house ascending in groups"
        -- Standard sort achieves grouping (e.g., 2,2,3,3,3)
        for _, idx in ipairs(selectedIndices) do
            if dice[idx] then
                table.insert(scoringValues, dice[idx].value)
            end
        end
        table.sort(scoringValues)
    else
        -- Other low hands (3-kind, 4-kind, Yahtzee):
        -- Only show the dice that form the combination (the N matching faces)
        local requiredCount = 3
        if handId == "fourOfKind" then requiredCount = 4 end
        if handId == "yahtzee" then requiredCount = 5 end

        -- Count faces in selection
        local counts = { 0, 0, 0, 0, 0, 0 }
        local selectedValues = {}
        for _, idx in ipairs(selectedIndices) do
            if dice[idx] then
                local v = dice[idx].value
                counts[v] = counts[v] + 1
                table.insert(selectedValues, v)
            end
        end

        -- Find the face that satisfies the condition (highest face priority if multiple)
        local matchFace = nil
        for f = 6, 1, -1 do
            if counts[f] >= requiredCount then
                matchFace = f
                break
            end
        end

        if matchFace then
            -- Collect only instances of matchFace
            -- Limit to actual count present in selection (which is counts[matchFace])
            -- The user wants "valid hand", so if I have 4 ones and it's "3 of kind", do I show 3 or 4?
            -- User example: "1,1,1,6" -> "1,1,1".
            -- If I have "1,1,1,1" and it's detected as "3 of kind" (because 4ofKind used?), I should show all 4?
            -- Usually all matching dice contribute.
            -- If I have 1,1,1,1 and hand is "threeOfKind", showing 1,1,1,1 is correct as it satisfies "at least 3".
            -- Showing 1,1,1 might be misleading if I actually have 4.
            -- But "1,1,1,6" -> "1,1,1" implies we exclude NON-matching.
            -- So I will include all dice that match the matchFace.

            for _, v in ipairs(selectedValues) do
                if v == matchFace then
                    table.insert(scoringValues, v)
                end
            end
        else
            -- Fallback: shouldn't happen if hand detection works, but just show all sorted
            scoringValues = selectedValues
            table.sort(scoringValues)
        end
    end

    return scoringValues
end

return Scoring
