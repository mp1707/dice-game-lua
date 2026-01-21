-- Spritesheet Module
-- Manages the dice spritesheet and quads

local Spritesheet = {}

-- Sprite configuration
Spritesheet.config = {
    path = "assets/PixelDice_White.png",
    columns = 6,      -- 6 faces per row
    rows = 6,         -- 6 rows total
    faceRow = 1,      -- Row containing face values 1-6
    rollRow = 6,      -- Row containing rolling animation frames
}

-- Storage for loaded assets
Spritesheet.image = nil
Spritesheet.faceQuads = {}  -- faceQuads[1-6] for static face display
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

    -- Create quads for face values (row 1)
    -- Layout: columns = faces 1-6
    for face = 1, 6 do
        local x = (face - 1) * sw
        local y = (cfg.faceRow - 1) * sh

        self.faceQuads[face] = love.graphics.newQuad(x, y, sw, sh, imgW, imgH)
    end

    -- Create quads for rolling animation frames (last row)
    for frame = 1, 6 do
        local x = (frame - 1) * sw
        local y = (cfg.rollRow - 1) * sh

        self.rollQuads[frame] = love.graphics.newQuad(x, y, sw, sh, imgW, imgH)
    end
end

-- Get the quad for a specific face value (1-6)
function Spritesheet:getQuad(face)
    face = math.max(1, math.min(6, face))
    return self.faceQuads[face]
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
