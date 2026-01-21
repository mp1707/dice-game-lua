-- Hand definitions
-- All 12 Yahtzee hand types with scoring metadata

local Hands = {}

-- Hand type definitions
-- id: unique identifier
-- name: German display name
-- shortName: abbreviated name for compact display
-- section: "upper" or "lower"
-- basePoints: base score value
-- mult: score multiplier
-- level: hand level (starts at 1, can be upgraded)
Hands.definitions = {
    -- Upper section (6 hands) - score matching dice only
    { id = "ones",          name = "Ones",            shortName = "1s",     section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "twos",          name = "Twos",            shortName = "2s",     section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "threes",        name = "Threes",          shortName = "3s",     section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "fours",         name = "Fours",           shortName = "4s",     section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "fives",         name = "Fives",           shortName = "5s",     section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "sixes",         name = "Sixes",           shortName = "6s",     section = "upper", basePoints = 10, mult = 1, level = 1 },

    -- Lower section (6 hands) - score all dice if pattern matches
    { id = "threeOfKind",   name = "Three of a Kind", shortName = "3x",     section = "lower", basePoints = 20, mult = 2, level = 1 },
    { id = "fourOfKind",    name = "Four of a Kind",  shortName = "4x",     section = "lower", basePoints = 20, mult = 3, level = 1 },
    { id = "yahtzee",       name = "Yahtzee",         shortName = "5x",     section = "lower", basePoints = 50, mult = 4, level = 1 },
    { id = "fullHouse",     name = "Full House",      shortName = "FH",     section = "lower", basePoints = 20, mult = 3, level = 1 },
    { id = "smallStraight", name = "Small Straight",  shortName = "Sm.Str", section = "lower", basePoints = 20, mult = 2, level = 1 },
    { id = "largeStraight", name = "Large Straight",  shortName = "Lg.Str", section = "lower", basePoints = 40, mult = 3, level = 1 },
}

-- Lookup table by ID
Hands.byId = {}
for _, def in ipairs(Hands.definitions) do
    Hands.byId[def.id] = def
end

-- Get upper section hands
function Hands:getUpper()
    local result = {}
    for _, def in ipairs(self.definitions) do
        if def.section == "upper" then
            table.insert(result, def)
        end
    end
    return result
end

-- Get lower section hands
function Hands:getLower()
    local result = {}
    for _, def in ipairs(self.definitions) do
        if def.section == "lower" then
            table.insert(result, def)
        end
    end
    return result
end

-- Get hand definition by ID
function Hands:get(id)
    return self.byId[id]
end

return Hands
