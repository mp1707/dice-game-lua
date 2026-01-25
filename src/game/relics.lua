-- Relic Definitions Registry
-- Relics are passive items that provide ongoing effects
-- They are placed in slots 1-5 of the item strip

local ItemRegistry = require("src.items.item_registry")

local Relics = {}

-- Load all definitions
local function loadDefinitions()
    -- List of definition modules to load
    local modules = {
        "src.items.definitions.prism",
    }

    for _, modPath in ipairs(modules) do
        local def = require(modPath)
        ItemRegistry:register(def)
    end
end

-- Initialize definitions
loadDefinitions()

-- Get a relic definition by ID
function Relics:get(relicId)
    return ItemRegistry:get(relicId)
end

-- Get all relic definitions
function Relics:getAll()
    return ItemRegistry:getAll()
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
    for id, def in pairs(ItemRegistry:getAll()) do
        if def.rarity == rarity then
            table.insert(result, def)
        end
    end
    return result
end

-- Get a random relic ID (for shop generation)
function Relics:getRandomId()
    local ids = {}
    for id, _ in pairs(ItemRegistry:getAll()) do
        table.insert(ids, id)
    end
    if #ids == 0 then return nil end
    return ids[math.random(1, #ids)]
end

-- Get random relic IDs (for shop, avoiding duplicates)
function Relics:getRandomIds(count)
    local ids = {}
    for id, _ in pairs(ItemRegistry:getAll()) do
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
