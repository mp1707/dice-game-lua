-- Relic Definitions Registry
-- Relics are passive items that provide ongoing effects
-- They are placed in slots 1-5 of the item strip

local Relics = {
    -- Registry of all relic definitions, keyed by ID
    definitions = {},
}

-- Helper to register a relic
local function register(def)
    Relics.definitions[def.id] = def
end

-- Prism relic
-- When scoring a straight, the rightmost die becomes prismatic
register({
    id = "prism",
    name = "Prism",
    description = "Scoring a straight turns the rightmost die prismatic",
    buyPrice = 10,
    sellPrice = 3,
    sprite = "assets/icons/items/prism.png",
    rarity = "uncommon",
})

-- Get a relic definition by ID
function Relics:get(relicId)
    return self.definitions[relicId]
end

-- Get all relic definitions
function Relics:getAll()
    return self.definitions
end

-- Get relic's buy price
function Relics:getBuyPrice(relicId)
    local def = self:get(relicId)
    return def and def.buyPrice or 10
end

-- Get relic's sell price
function Relics:getSellPrice(relicId)
    local def = self:get(relicId)
    return def and def.sellPrice or 3
end

-- Get all relics of a specific rarity
function Relics:getByRarity(rarity)
    local result = {}
    for id, def in pairs(self.definitions) do
        if def.rarity == rarity then
            table.insert(result, def)
        end
    end
    return result
end

-- Get a random relic ID (for shop generation)
function Relics:getRandomId()
    local ids = {}
    for id, _ in pairs(self.definitions) do
        table.insert(ids, id)
    end
    if #ids == 0 then return nil end
    return ids[math.random(1, #ids)]
end

-- Get random relic IDs (for shop, avoiding duplicates)
function Relics:getRandomIds(count)
    local ids = {}
    for id, _ in pairs(self.definitions) do
        table.insert(ids, id)
    end

    -- Shuffle
    for i = #ids, 2, -1 do
        local j = math.random(1, i)
        ids[i], ids[j] = ids[j], ids[i]
    end

    -- Take first 'count' items
    local result = {}
    for i = 1, math.min(count, #ids) do
        table.insert(result, ids[i])
    end
    return result
end

return Relics
