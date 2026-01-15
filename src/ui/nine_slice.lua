-- 9-slice panel renderer
-- Draws a scalable panel with preserved corners

local Theme = require("src.ui.theme")

local NineSlice = {}
NineSlice.__index = NineSlice

function NineSlice.new(image, cornerSize)
    local self = setmetatable({}, NineSlice)

    self.image = image or Theme.nineSlice.image
    self.cornerSize = cornerSize or Theme.nineSlice.cornerSize

    if not self.image then
        error("NineSlice: No image provided and Theme.nineSlice.image is nil")
    end

    local iw, ih = self.image:getDimensions()
    local cs = self.cornerSize
    local centerW = iw - cs * 2
    local centerH = ih - cs * 2

    -- Create 9 quads for the slices
    self.quads = {
        -- Top row
        love.graphics.newQuad(0, 0, cs, cs, iw, ih),                    -- 1: top-left
        love.graphics.newQuad(cs, 0, centerW, cs, iw, ih),              -- 2: top-center
        love.graphics.newQuad(iw - cs, 0, cs, cs, iw, ih),              -- 3: top-right
        -- Middle row
        love.graphics.newQuad(0, cs, cs, centerH, iw, ih),              -- 4: mid-left
        love.graphics.newQuad(cs, cs, centerW, centerH, iw, ih),        -- 5: center
        love.graphics.newQuad(iw - cs, cs, cs, centerH, iw, ih),        -- 6: mid-right
        -- Bottom row
        love.graphics.newQuad(0, ih - cs, cs, cs, iw, ih),              -- 7: bot-left
        love.graphics.newQuad(cs, ih - cs, centerW, cs, iw, ih),        -- 8: bot-center
        love.graphics.newQuad(iw - cs, ih - cs, cs, cs, iw, ih),        -- 9: bot-right
    }

    self.sourceCenter = { w = centerW, h = centerH }

    return self
end

function NineSlice:draw(x, y, width, height, color)
    local cs = self.cornerSize
    local img = self.image
    local q = self.quads

    -- Set color (defaults to white for no tint)
    if color then
        love.graphics.setColor(color)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Calculate center dimensions
    local centerW = width - cs * 2
    local centerH = height - cs * 2

    -- Scale factors for center pieces
    local scaleX = centerW / self.sourceCenter.w
    local scaleY = centerH / self.sourceCenter.h

    -- Draw corners (no scaling)
    love.graphics.draw(img, q[1], x, y)                                    -- top-left
    love.graphics.draw(img, q[3], x + width - cs, y)                       -- top-right
    love.graphics.draw(img, q[7], x, y + height - cs)                      -- bot-left
    love.graphics.draw(img, q[9], x + width - cs, y + height - cs)         -- bot-right

    -- Draw edges (scale one axis)
    love.graphics.draw(img, q[2], x + cs, y, 0, scaleX, 1)                 -- top
    love.graphics.draw(img, q[8], x + cs, y + height - cs, 0, scaleX, 1)   -- bottom
    love.graphics.draw(img, q[4], x, y + cs, 0, 1, scaleY)                 -- left
    love.graphics.draw(img, q[6], x + width - cs, y + cs, 0, 1, scaleY)    -- right

    -- Draw center (scale both axes)
    love.graphics.draw(img, q[5], x + cs, y + cs, 0, scaleX, scaleY)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Singleton instance for convenience
local _instance = nil

function NineSlice.getInstance()
    if not _instance then
        _instance = NineSlice.new()
    end
    return _instance
end

return NineSlice
