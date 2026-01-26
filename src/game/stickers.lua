-- Sticker Definitions Registry
-- Stickers are consumable items that replace die faces
-- Supports basic, golden, and metal die types with special effects

local Stickers = {
    -- Registry of all sticker definitions, keyed by ID
    definitions = {},

    -- Rarity weights for random selection
    rarityWeights = {
        common = 70,    -- 70% chance
        uncommon = 25,  -- 25% chance
        rare = 5,       -- 5% chance
    },
}

-- Helper to register a sticker
local function register(def)
    -- Apply defaults
    def.dieType = def.dieType or "basic"
    def.canReroll = def.canReroll ~= false  -- Default to true
    Stickers.definitions[def.id] = def
end

-- ============================================
-- Basic face stickers (1-6)
-- These simply replace a die face with the specified value
-- ============================================
register({
    id = "basic_1",
    name = "One",
    description = "Drag on a die to replace its current face",
    faceValue = 1,
    dieType = "basic",
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 1,
    rarity = "common",
})

register({
    id = "basic_2",
    name = "Two",
    description = "Drag on a die to replace its current face",
    faceValue = 2,
    dieType = "basic",
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 2,
    rarity = "common",
})

register({
    id = "basic_3",
    name = "Three",
    description = "Drag on a die to replace its current face",
    faceValue = 3,
    dieType = "basic",
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 3,
    rarity = "common",
})

register({
    id = "basic_4",
    name = "Four",
    description = "Drag on a die to replace its current face",
    faceValue = 4,
    dieType = "basic",
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 4,
    rarity = "common",
})

register({
    id = "basic_5",
    name = "Five",
    description = "Drag on a die to replace its current face",
    faceValue = 5,
    dieType = "basic",
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 5,
    rarity = "common",
})

register({
    id = "basic_6",
    name = "Six",
    description = "Drag on a die to replace its current face",
    faceValue = 6,
    dieType = "basic",
    buyPrice = 8,
    sellPrice = 2,
    spriteId = 6,
    rarity = "common",
})

-- ============================================
-- Golden stickers (1-6)
-- Add money equal to face value when scored
-- ============================================
register({
    id = "golden_1",
    name = "Golden One",
    description = "Adds $1 when scored",
    faceValue = 1,
    dieType = "golden",
    buyPrice = 12,
    sellPrice = 4,
    spriteId = 1,
    rarity = "uncommon",
    effects = {
        onCount = { type = "money", amount = 1 }
    }
})

register({
    id = "golden_2",
    name = "Golden Two",
    description = "Adds $2 when scored",
    faceValue = 2,
    dieType = "golden",
    buyPrice = 12,
    sellPrice = 4,
    spriteId = 2,
    rarity = "uncommon",
    effects = {
        onCount = { type = "money", amount = 2 }
    }
})

register({
    id = "golden_3",
    name = "Golden Three",
    description = "Adds $3 when scored",
    faceValue = 3,
    dieType = "golden",
    buyPrice = 12,
    sellPrice = 4,
    spriteId = 3,
    rarity = "uncommon",
    effects = {
        onCount = { type = "money", amount = 3 }
    }
})

register({
    id = "golden_4",
    name = "Golden Four",
    description = "Adds $4 when scored",
    faceValue = 4,
    dieType = "golden",
    buyPrice = 12,
    sellPrice = 4,
    spriteId = 4,
    rarity = "uncommon",
    effects = {
        onCount = { type = "money", amount = 4 }
    }
})

register({
    id = "golden_5",
    name = "Golden Five",
    description = "Adds $5 when scored",
    faceValue = 5,
    dieType = "golden",
    buyPrice = 12,
    sellPrice = 4,
    spriteId = 5,
    rarity = "uncommon",
    effects = {
        onCount = { type = "money", amount = 5 }
    }
})

register({
    id = "golden_6",
    name = "Golden Six",
    description = "Adds $6 when scored",
    faceValue = 6,
    dieType = "golden",
    buyPrice = 12,
    sellPrice = 4,
    spriteId = 6,
    rarity = "uncommon",
    effects = {
        onCount = { type = "money", amount = 6 }
    }
})

-- ============================================
-- Metal stickers (1-6)
-- x2 mult when scored, cannot be rerolled
-- ============================================
register({
    id = "metal_1",
    name = "Metal One",
    description = "x2 mult when scored. Cannot be rerolled.",
    faceValue = 1,
    dieType = "metal",
    buyPrice = 15,
    sellPrice = 5,
    spriteId = 1,
    rarity = "rare",
    canReroll = false,
    effects = {
        onCount = { type = "mult_x", multiplier = 2 }
    }
})

register({
    id = "metal_2",
    name = "Metal Two",
    description = "x2 mult when scored. Cannot be rerolled.",
    faceValue = 2,
    dieType = "metal",
    buyPrice = 15,
    sellPrice = 5,
    spriteId = 2,
    rarity = "rare",
    canReroll = false,
    effects = {
        onCount = { type = "mult_x", multiplier = 2 }
    }
})

register({
    id = "metal_3",
    name = "Metal Three",
    description = "x2 mult when scored. Cannot be rerolled.",
    faceValue = 3,
    dieType = "metal",
    buyPrice = 15,
    sellPrice = 5,
    spriteId = 3,
    rarity = "rare",
    canReroll = false,
    effects = {
        onCount = { type = "mult_x", multiplier = 2 }
    }
})

register({
    id = "metal_4",
    name = "Metal Four",
    description = "x2 mult when scored. Cannot be rerolled.",
    faceValue = 4,
    dieType = "metal",
    buyPrice = 15,
    sellPrice = 5,
    spriteId = 4,
    rarity = "rare",
    canReroll = false,
    effects = {
        onCount = { type = "mult_x", multiplier = 2 }
    }
})

register({
    id = "metal_5",
    name = "Metal Five",
    description = "x2 mult when scored. Cannot be rerolled.",
    faceValue = 5,
    dieType = "metal",
    buyPrice = 15,
    sellPrice = 5,
    spriteId = 5,
    rarity = "rare",
    canReroll = false,
    effects = {
        onCount = { type = "mult_x", multiplier = 2 }
    }
})

register({
    id = "metal_6",
    name = "Metal Six",
    description = "x2 mult when scored. Cannot be rerolled.",
    faceValue = 6,
    dieType = "metal",
    buyPrice = 15,
    sellPrice = 5,
    spriteId = 6,
    rarity = "rare",
    canReroll = false,
    effects = {
        onCount = { type = "mult_x", multiplier = 2 }
    }
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

-- Get sticker's die type (basic, golden, metal)
function Stickers:getType(stickerId)
    local def = self:get(stickerId)
    return def and def.dieType or "basic"
end

-- Check if sticker can be rerolled
function Stickers:canReroll(stickerId)
    local def = self:get(stickerId)
    if not def then return true end
    return def.canReroll ~= false
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

-- Get a random sticker ID with rarity weighting
function Stickers:getRandomId()
    -- Calculate total weight
    local totalWeight = 0
    for _, weight in pairs(self.rarityWeights) do
        totalWeight = totalWeight + weight
    end

    -- Roll for rarity
    local roll = math.random() * totalWeight
    local selectedRarity = "common"
    local cumulative = 0
    for rarity, weight in pairs(self.rarityWeights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            selectedRarity = rarity
            break
        end
    end

    -- Get all stickers of that rarity
    local candidates = self:getByRarity(selectedRarity)

    -- Fallback to common if no candidates found
    if #candidates == 0 then
        candidates = self:getByRarity("common")
    end

    if #candidates == 0 then return nil end

    -- Pick random from candidates
    return candidates[math.random(1, #candidates)].id
end

-- Get random sticker IDs with rarity weighting (for shop, avoiding duplicates)
function Stickers:getRandomIds(count)
    local result = {}
    local usedIds = {}

    for _ = 1, count do
        -- Try up to 10 times to get a unique sticker
        for _ = 1, 10 do
            local id = self:getRandomId()
            if id and not usedIds[id] then
                usedIds[id] = true
                table.insert(result, id)
                break
            end
        end
    end

    return result
end

return Stickers
