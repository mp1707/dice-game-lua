local Scoring = require("src.game.scoring")

-- Mock dice objects
local function makeDice(values)
    local dice = {}
    for i, v in ipairs(values) do
        dice[i] = { value = v }
    end
    return dice
end

local function runTest(name, handId, values, indices, expected)
    local dice = makeDice(values)
    local result = Scoring.getScoringDiceForHand(handId, indices, dice)

    local loops = math.max(#result, #expected)
    local match = true
    if #result ~= #expected then match = false end

    local resStr = "{" .. table.concat(result, ",") .. "}"
    local expStr = "{" .. table.concat(expected, ",") .. "}"

    for i = 1, loops do
        if result[i] ~= expected[i] then match = false end
    end

    if match then
        print("PASS: " .. name .. " -> " .. resStr)
    else
        print("FAIL: " .. name)
        print("  Expected: " .. expStr)
        print("  Got:      " .. resStr)
    end
end

print("Testing Scoring.getScoringDiceForHand N-of-Kind Filtering...")

-- Test 1: Three of a Kind with extra die (User case)
-- Select 1,1,1,6 -> Expect 1,1,1
runTest("Three of a Kind (1,1,1,6)", "threeOfKind", { 1, 1, 1, 6 }, { 1, 2, 3, 4 }, { 1, 1, 1 })

-- Test 2: Three of a Kind with 4 ones (should show all 4 if used as 3-kind? Or just 3?)
-- My logic shows ALL matching faces. So if I have 4 ones, and it's 3-of-kind, it shows 1,1,1,1.
-- This is technically correct as "at least 3" are 1s, and all 1s contribute.
-- If user strictly wanted 3, I'd need to limit. But usually "valid hand" implies the matching components.
runTest("Three of a Kind (1,1,1,1) showing all matches", "threeOfKind", { 1, 1, 1, 1 }, { 1, 2, 3, 4 }, { 1, 1, 1, 1 })

-- Test 3: Four of a Kind with extra
-- Select 2,2,2,2,3 -> Expect 2,2,2,2
runTest("Four of a Kind (2,2,2,2,3)", "fourOfKind", { 2, 2, 2, 2, 3 }, { 1, 2, 3, 4, 5 }, { 2, 2, 2, 2 })

-- Test 4: Yahtzee
-- Select 5,5,5,5,5 -> Expect 5,5,5,5,5
runTest("Yahtzee (5,5,5,5,5)", "yahtzee", { 5, 5, 5, 5, 5 }, { 1, 2, 3, 4, 5 }, { 5, 5, 5, 5, 5 })

-- Test 5: Full House (should ensure regression test)
-- Select 2,3,2,2,3 -> Expect 2,2,2,3,3
runTest("Full House (regression)", "fullHouse", { 2, 3, 2, 2, 3 }, { 1, 2, 3, 4, 5 }, { 2, 2, 2, 3, 3 })
