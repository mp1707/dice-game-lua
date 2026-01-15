-- Panel component with 9-slice background
-- A simple container for grouping UI elements

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")

local Panel = {}
Panel.__index = Panel

function Panel.new(config)
    local self = setmetatable({}, Panel)

    self.x = config.x or 0
    self.y = config.y or 0
    self.width = config.width or 100
    self.height = config.height or 100
    self.bgColor = config.bgColor or Theme.colors.surface
    self.padding = config.padding or Theme.spacing.md

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    return self
end

function Panel:setPosition(x, y)
    self.x = x
    self.y = y
end

function Panel:setSize(width, height)
    self.width = width
    self.height = height
end

function Panel:getInnerBounds()
    return {
        x = self.x + self.padding,
        y = self.y + self.padding,
        width = self.width - self.padding * 2,
        height = self.height - self.padding * 2,
    }
end

function Panel:draw()
    self.nineSlice:draw(self.x, self.y, self.width, self.height, self.bgColor)
end

return Panel
