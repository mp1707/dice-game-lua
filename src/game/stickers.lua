-- Sticker Definitions Registry
-- Stickers are consumable items that replace die faces
-- For now, basic stickers just set a face to a specific value (1-6)
-- Later this can be extended with special effects, bonus points, etc.

local Stickers = {
    -- Registry of all sticker definitions, keyed by ID
    definitions = {},
}

-- Helper to register a sticker
local function register(def)
    Stickers.definitions[def.id] = def
end

-- Basic face stickers (1-6)
-- These simply replace a die face with the specified value
register({
    id = "basic_1",
    name = "One",
    description = "Replace a face with 1",
    faceValue = 1,
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 1, -- Uses existing die face sprite
    rarity = "common",
})

register({
    id = "basic_2",
    name = "Two",
    description = "Replace a face with 2",
    faceValue = 2,
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 2,
    rarity = "common",
})

register({
    id = "basic_3",
    name = "Three",
    description = "Replace a face with 3",
    faceValue = 3,
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 3,
    rarity = "common",
})

register({
    id = "basic_4",
    name = "Four",
    description = "Replace a face with 4",
    faceValue = 4,
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 4,
    rarity = "common",
})

register({
    id = "basic_5",
    name = "Five",
    description = "Replace a face with 5",
    faceValue = 5,
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 5,
    rarity = "common",
})

register({
    id = "basic_6",
    name = "Six",
    description = "Replace a face with 6",
    faceValue = 6,
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 6,
    rarity = "common",
})

-- Get a sticker definition by ID
function Stickers:get(stickerId)
    return self.definitions[stickerId]
end

-- Get all sticker definitions
function Stickers:getAll()
    return self.definitions
end

-- Get sticker's face value
function Stickers:getValue(stickerId)
    local def = self:get(stickerId)
    return def and def.faceValue or 0
end

-- Get sticker's sprite ID (for rendering)
function Stickers:getSpriteId(stickerId)
    local def = self:get(stickerId)
    return def and def.spriteId or 1
end

-- Get sticker's buy price
function Stickers:getBuyPrice(stickerId)
    local def = self:get(stickerId)
    return def and def.buyPrice or 8
end

-- Get sticker's sell price
function Stickers:getSellPrice(stickerId)
    local def = self:get(stickerId)
    return def and def.sellPrice or 2
end

-- Get all stickers of a specific rarity
function Stickers:getByRarity(rarity)
    local result = {}
    for id, def in pairs(self.definitions) do
        if def.rarity == rarity then
            table.insert(result, def)
        end
    end
    return result
end

-- Get a random sticker ID (for shop generation)
function Stickers:getRandomId()
    local ids = {}
    for id, _ in pairs(self.definitions) do
        table.insert(ids, id)
    end
    if #ids == 0 then return nil end
    return ids[math.random(1, #ids)]
end

-- Get random sticker IDs (for shop, avoiding duplicates)
function Stickers:getRandomIds(count)
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

return Stickers
