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

function NineSlice:draw(x, y, width, height, color, scale)
    local s = scale or 1
    local cs = self.cornerSize * s
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
    
    -- Ensure we don't overlapping if too small
    if centerW < 0 then centerW = 0 end
    if centerH < 0 then centerH = 0 end

    -- Scale factors for center pieces (stretching to fill the gap)
    -- We want the texture to stretch from source_size to target_size
    local scaleX = centerW / self.sourceCenter.w
    local scaleY = centerH / self.sourceCenter.h

    -- Draw corners (scaled by s)
    love.graphics.draw(img, q[1], x, y, 0, s, s)                                    -- top-left
    love.graphics.draw(img, q[3], x + width - cs, y, 0, s, s)                       -- top-right
    love.graphics.draw(img, q[7], x, y + height - cs, 0, s, s)                      -- bot-left
    love.graphics.draw(img, q[9], x + width - cs, y + height - cs, 0, s, s)         -- bot-right

    -- Draw edges (one axis stretches to size, other axis scales by s to match corners)
    love.graphics.draw(img, q[2], x + cs, y, 0, scaleX, s)                 -- top
    love.graphics.draw(img, q[8], x + cs, y + height - cs, 0, scaleX, s)   -- bottom
    love.graphics.draw(img, q[4], x, y + cs, 0, s, scaleY)                 -- left
    love.graphics.draw(img, q[6], x + width - cs, y + cs, 0, s, scaleY)    -- right

    -- Draw center (stretch both)
    love.graphics.draw(img, q[5], x + cs, y + cs, 0, scaleX, scaleY)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function NineSlice:drawBorder(x, y, width, height, color, scale, thickness)
    local s = scale or 1
    local cs = self.cornerSize * s
    local img = self.image
    local q = self.quads
    local t = thickness or 0

    -- Set color (defaults to white for no tint)
    if color then
        love.graphics.setColor(color)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Calculate center dimensions
    local centerW = width - cs * 2
    local centerH = height - cs * 2

    -- Ensure we don't overlap if too small
    if centerW < 0 then centerW = 0 end
    if centerH < 0 then centerH = 0 end

    -- Scale factors for edge pieces (stretching to fill the gap)
    local scaleX = centerW / self.sourceCenter.w
    local scaleY = centerH / self.sourceCenter.h

    -- Draw corners (scaled by s)
    love.graphics.draw(img, q[1], x, y, 0, s, s)                                    -- top-left
    love.graphics.draw(img, q[3], x + width - cs, y, 0, s, s)                       -- top-right
    love.graphics.draw(img, q[7], x, y + height - cs, 0, s, s)                      -- bot-left
    love.graphics.draw(img, q[9], x + width - cs, y + height - cs, 0, s, s)         -- bot-right

    -- Draw edges (one axis stretches to size, other axis scales by s to match corners)
    love.graphics.draw(img, q[2], x + cs, y, 0, scaleX, s)                 -- top
    love.graphics.draw(img, q[8], x + cs, y + height - cs, 0, scaleX, s)   -- bottom
    love.graphics.draw(img, q[4], x, y + cs, 0, s, scaleY)                 -- left
    love.graphics.draw(img, q[6], x + width - cs, y + cs, 0, s, scaleY)    -- right

    -- Note: Center piece (quad[5]) is intentionally skipped to create border-only effect

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
