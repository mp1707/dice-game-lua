-- Spritesheet Module
-- Manages the dice spritesheet and quads for different die types

local Spritesheet = {}

-- Sprite configuration
-- Image is 168x336 = 6 columns x 12 rows, sprites are 28x28 pixels each
Spritesheet.config = {
    path = "assets/diceSpriteSheet.png",
    columns = 6,      -- 6 faces per row
    rows = 12,        -- 12 rows total (168x336 image, sprites are 28x28)
    -- Row mapping for die types (1-indexed)
    typeRows = {
        golden = 1,   -- Row 1: Golden dice
        metal = 2,    -- Row 2: Metal dice
        -- Row 3: Rusty (ignored for now)
        basic = 4,    -- Row 4: Basic/normal dice
    },
    rollRow = 12,     -- Row 12 (last row): Rolling animation frames
}

-- Storage for loaded assets
Spritesheet.image = nil
Spritesheet.typeQuads = {}  -- typeQuads[type][face] for static face display by type
Spritesheet.rollQuads = {}  -- rollQuads[1-6] for rolling animation frames
Spritesheet.spriteWidth = 0
Spritesheet.spriteHeight = 0

function Spritesheet:load()
    local cfg = self.config

    -- Load the spritesheet image
    self.image = love.graphics.newImage(cfg.path)
    self.image:setFilter("nearest", "nearest")

    local imgW, imgH = self.image:getDimensions()

    -- Calculate sprite dimensions from image size
    self.spriteWidth = imgW / cfg.columns
    self.spriteHeight = imgH / cfg.rows

    local sw, sh = self.spriteWidth, self.spriteHeight

    -- Create quads for each die type
    for dieType, row in pairs(cfg.typeRows) do
        self.typeQuads[dieType] = {}
        for face = 1, 6 do
            local x = (face - 1) * sw
            local y = (row - 1) * sh
            self.typeQuads[dieType][face] = love.graphics.newQuad(x, y, sw, sh, imgW, imgH)
        end
    end

    -- Create quads for rolling animation frames (last row)
    for frame = 1, 6 do
        local x = (frame - 1) * sw
        local y = (cfg.rollRow - 1) * sh
        self.rollQuads[frame] = love.graphics.newQuad(x, y, sw, sh, imgW, imgH)
    end
end

-- Get the quad for a specific face value (1-6) and optional die type
-- dieType can be "basic", "golden", or "metal" (defaults to "basic")
function Spritesheet:getQuad(face, dieType)
    face = math.max(1, math.min(6, face))
    dieType = dieType or "basic"

    -- Ensure valid die type
    if not self.typeQuads[dieType] then
        dieType = "basic"
    end

    return self.typeQuads[dieType][face]
end

-- Get the quad for a rolling animation frame (1-6)
function Spritesheet:getRollQuad(frame)
    frame = math.max(1, math.min(6, frame))
    return self.rollQuads[frame]
end

-- Get the image
function Spritesheet:getImage()
    return self.image
end

-- Get sprite dimensions (for scaling calculations)
function Spritesheet:getSpriteSize()
    return self.spriteWidth, self.spriteHeight
end

return Spritesheet
