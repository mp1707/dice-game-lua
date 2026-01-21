-- Spritesheet Module
-- Manages the isometric dice spritesheet and quads

local Spritesheet = {}

-- Sprite configuration
Spritesheet.config = {
    path = "assets/dice.png",
    spriteWidth = 32,
    spriteHeight = 32,
    columns = 4,      -- 4 orientations per face
    rows = 6,         -- 6 face values (1-6)
}

-- Storage for loaded assets
Spritesheet.image = nil
Spritesheet.quads = {}  -- quads[face][orientation] (1-indexed)

function Spritesheet:load()
    local cfg = self.config

    -- Load the spritesheet image
    self.image = love.graphics.newImage(cfg.path)
    self.image:setFilter("nearest", "nearest")

    local imgW, imgH = self.image:getDimensions()

    -- Create quads for each face and orientation
    -- Layout: rows = faces (1-6), columns = orientations (1-4)
    for face = 1, cfg.rows do
        self.quads[face] = {}
        for orientation = 1, cfg.columns do
            local x = (orientation - 1) * cfg.spriteWidth
            local y = (face - 1) * cfg.spriteHeight

            self.quads[face][orientation] = love.graphics.newQuad(
                x, y,
                cfg.spriteWidth, cfg.spriteHeight,
                imgW, imgH
            )
        end
    end
end

-- Get the quad for a specific face and orientation
function Spritesheet:getQuad(face, orientation)
    face = math.max(1, math.min(6, face))
    orientation = math.max(1, math.min(4, orientation))
    return self.quads[face][orientation]
end

-- Get the image
function Spritesheet:getImage()
    return self.image
end

-- Get sprite dimensions (for scaling calculations)
function Spritesheet:getSpriteSize()
    return self.config.spriteWidth, self.config.spriteHeight
end

return Spritesheet
