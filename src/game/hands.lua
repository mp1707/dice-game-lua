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
    { id = "ones",          name = "Einser",      shortName = "1er",    section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "twos",          name = "Zweier",      shortName = "2er",    section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "threes",        name = "Dreier",      shortName = "3er",    section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "fours",         name = "Vierer",      shortName = "4er",    section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "fives",         name = "Fünfer",      shortName = "5er",    section = "upper", basePoints = 10, mult = 1, level = 1 },
    { id = "sixes",         name = "Sechser",     shortName = "6er",    section = "upper", basePoints = 10, mult = 1, level = 1 },

    -- Lower section (6 hands) - score all dice if pattern matches
    { id = "threeOfKind",   name = "Dreierpasch", shortName = "3x",     section = "lower", basePoints = 20, mult = 2, level = 1 },
    { id = "fourOfKind",    name = "Viererpasch", shortName = "4x",     section = "lower", basePoints = 20, mult = 3, level = 1 },
    { id = "yahtzee",       name = "Fünferpasch", shortName = "5x",     section = "lower", basePoints = 50, mult = 4, level = 1 },
    { id = "fullHouse",     name = "Full House",  shortName = "FH",     section = "lower", basePoints = 20, mult = 3, level = 1 },
    { id = "smallStraight", name = "Kl. Strasse", shortName = "Kl.Str", section = "lower", basePoints = 20, mult = 2, level = 1 },
    { id = "largeStraight", name = "Gr. Strasse", shortName = "Gr.Str", section = "lower", basePoints = 40, mult = 3, level = 1 },
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
