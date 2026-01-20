-- Shadow Rendering for Dice
-- Height-based dynamic shadows that provide depth perception

local Shadow = {}

-- Shadow configuration
Shadow.config = {
    maxHeight = 350,        -- Maximum height for shadow calculations
    maxOffsetX = 15,        -- Maximum X offset when at max height
    maxOffsetY = 25,        -- Maximum Y offset when at max height
    scaleGrowth = 0.5,      -- How much shadow grows with height
    baseAlpha = 0.4,        -- Base shadow opacity
    fadeRate = 0.6,         -- How much shadow fades with height
    baseWidth = 0.5,        -- Shadow width as fraction of die size
    baseHeight = 0.12,      -- Shadow height as fraction of die size
}

-- Draw shadow for a die
-- @param die: Die object with x, y, height, size, scaleX, scaleY properties
-- @param groundY: Y position of the ground (where shadow appears)
function Shadow.draw(die, groundY)
    local config = Shadow.config

    -- Only draw shadow when die is in the air
    if die.height <= 2 then
        return
    end

    -- Calculate height ratio (0 = on ground, 1 = at max height)
    local heightRatio = math.min(die.height / config.maxHeight, 1)

    -- Shadow offset (moves away from die as height increases)
    local offsetX = heightRatio * config.maxOffsetX
    local offsetY = heightRatio * config.maxOffsetY

    -- Shadow scale (larger when higher)
    local scale = 1 + heightRatio * config.scaleGrowth

    -- Shadow alpha (more transparent when higher)
    local alpha = config.baseAlpha * (1 - heightRatio * config.fadeRate)
    alpha = math.max(0.1, alpha)

    -- Calculate shadow dimensions
    local shadowW = die.size * config.baseWidth * scale
    local shadowH = die.size * config.baseHeight

    -- Apply die's squash/stretch to shadow (inverted - squashed die = wider shadow)
    shadowW = shadowW * die.scaleX
    shadowH = shadowH * (2 - die.scaleY) * 0.5  -- Subtle inverse relationship

    -- Shadow position (follows die horizontally, stays on ground vertically)
    local shadowX = die.x + die.size / 2 + offsetX
    local shadowY = groundY + die.size - 5 + offsetY

    -- Draw the shadow ellipse
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.ellipse("fill", shadowX, shadowY, shadowW / 2, shadowH / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return Shadow
