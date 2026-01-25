-- Item Registry
-- Manages definitions for all items (relics) in the game

local ItemRegistry = {
    definitions = {},
}

-- Register a new item definition
function ItemRegistry:register(def)
    if not def.id then
        error("Item definition missing id")
    end
    self.definitions[def.id] = def
end

-- Get an item definition by ID
function ItemRegistry:get(id)
    return self.definitions[id]
end

-- Get all definitions
function ItemRegistry:getAll()
    return self.definitions
end

return ItemRegistry
