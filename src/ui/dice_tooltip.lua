-- Dice Tooltip component
-- Shows all 6 faces of a die in a horizontal row
-- Appears on hover after 1 second delay
-- Clickable during editor mode

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local GameState = require("src.game.game_state")
local Juice = require("src.ui.juice")

local DiceTooltip = {}
DiceTooltip.__index = DiceTooltip

-- Singleton instance
local instance = nil

function DiceTooltip.getInstance()
    if not instance then
        instance = DiceTooltip.new()
    end
    return instance
end

function DiceTooltip.new()
    local self = setmetatable({}, DiceTooltip)

    self.nineSlice = NineSlice.getInstance()

    -- Tooltip dimensions (compact, no label)
    self.faceSize = 54
    self.faceSpacing = Theme.spacing.sm
    self.padding = Theme.spacing.sm
    self.width = 6 * self.faceSize + 5 * self.faceSpacing + self.padding * 2
    self.height = self.faceSize + self.padding * 2

    -- State
    self.visible = false
    self.targetDieIndex = nil
    self.x = 0
    self.y = 0

    -- Animation
    self.alpha = 0
    self.scale = 0.9
    self.scaleVelocity = 0

    -- Hover tracking for faces (editor mode)
    self.hoveredFaceIndex = nil

    -- Callback for face selection (editor mode)
    self.onFaceClick = nil

    return self
end

function DiceTooltip:updateLayout()
    self.faceSize = 54
    self.faceSpacing = Theme.spacing.sm
    self.padding = Theme.spacing.sm
    self.width = 6 * self.faceSize + 5 * self.faceSpacing + self.padding * 2
    self.height = self.faceSize + self.padding * 2
end

function DiceTooltip:show(dieIndex, anchorX, anchorY)
    self:updateLayout()
    self.visible = true
    self.targetDieIndex = dieIndex

    -- Position tooltip above the die
    self.x = anchorX - self.width / 2
    self.y = anchorY - self.height - 20

    -- Clamp to screen bounds
    local margin = 20
    self.x = math.max(margin, math.min(Theme.screen.width - self.width - margin, self.x))
    self.y = math.max(margin, math.min(Theme.screen.height - self.height - margin, self.y))
end

function DiceTooltip:hide()
    self.visible = false
    self.targetDieIndex = nil
    self.hoveredFaceIndex = nil
end

function DiceTooltip:setOnFaceClick(callback)
    self.onFaceClick = callback
end

function DiceTooltip:update(dt)
    -- Animate visibility
    local targetAlpha = self.visible and 1 or 0
    self.alpha = self.alpha + (targetAlpha - self.alpha) * dt * 12

    -- Spring animation for scale
    local targetScale = self.visible and 1 or 0.9
    self.scale, self.scaleVelocity = Juice.updateSpring(
        self.scale, targetScale, self.scaleVelocity,
        500, 30, dt
    )

    -- Update hovered face
    if self.visible and self.alpha > 0.5 then
        local mx, my = love.mouse.getPosition()
        if _G.screenToGame then
            mx, my = _G.screenToGame(mx, my)
        end
        if mx and my then
            self.hoveredFaceIndex = self:getFaceAtPosition(mx, my)
        else
            self.hoveredFaceIndex = nil
        end
    else
        self.hoveredFaceIndex = nil
    end
end

function DiceTooltip:getFaceAtPosition(px, py)
    if not self.visible or self.alpha < 0.5 then return nil end

    local startX = self.x + self.padding
    local startY = self.y + self.padding

    for i = 1, 6 do
        local faceX = startX + (i - 1) * (self.faceSize + self.faceSpacing)
        local faceY = startY

        if px >= faceX and px < faceX + self.faceSize and
            py >= faceY and py < faceY + self.faceSize then
            return i
        end
    end

    return nil
end

function DiceTooltip:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if not self.visible or self.alpha < 0.5 then return false end

    local faceIndex = self:getFaceAtPosition(x, y)
    if faceIndex and self.onFaceClick then
        self.onFaceClick(self.targetDieIndex, faceIndex)
        return true
    end

    return false
end

function DiceTooltip:isVisible()
    return self.visible and self.alpha > 0.1
end

function DiceTooltip:draw()
    if self.alpha < 0.01 then return end
    if not self.targetDieIndex then return end

    local faces = GameState:getDieFaces(self.targetDieIndex)
    if not faces then return end

    -- Calculate center for scaling
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-self.width / 2, -self.height / 2)

    -- Draw background panel
    local bgColor = {
        Theme.colors.panelDark[1],
        Theme.colors.panelDark[2],
        Theme.colors.panelDark[3],
        self.alpha * 0.95
    }
    self.nineSlice:draw(0, 0, self.width, self.height, bgColor, Theme.nineSlice.borderScale)

    -- Draw 6 faces in a horizontal row
    local startX = self.padding
    local startY = self.padding

    -- Center the row horizontally if the container is wider than the dice row
    -- (Though currently self.width is calculated based on drag row width, so it fits perfectly)
    local totalDiceWidth = 6 * self.faceSize + 5 * self.faceSpacing
    startX = (self.width - totalDiceWidth) / 2

    for i = 1, 6 do
        local faceX = startX + (i - 1) * (self.faceSize + self.faceSpacing)
        local faceY = startY
        local faceValue = faces[i]

        -- Highlight hovered face
        local isHovered = (i == self.hoveredFaceIndex)
        local faceScale = isHovered and 1.05 or 1 -- Reduced scale due to larger size

        self:drawFace(faceX, faceY, faceValue, faceScale, isHovered)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function DiceTooltip:drawFace(x, y, value, scale, isHovered)
    local centerX = x + self.faceSize / 2
    local centerY = y + self.faceSize / 2

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-self.faceSize / 2, -self.faceSize / 2)

    -- Draw highlight if hovered (in editor mode)
    if isHovered and GameState:isInEditorMode() then
        local highlightColor = {
            Theme.colors.cyan[1],
            Theme.colors.cyan[2],
            Theme.colors.cyan[3],
            self.alpha * 0.3
        }
        self.nineSlice:draw(-4, -4, self.faceSize + 8, self.faceSize + 8,
            highlightColor, Theme.nineSlice.borderScale)
    end

    -- Draw face sprite
    if Theme.diceSpritesheet then
        local quad = Theme.diceSpritesheet:getQuad(value)
        local image = Theme.diceSpritesheet:getImage()

        love.graphics.setColor(1, 1, 1, self.alpha)
        local spriteW, _ = Theme.diceSpritesheet:getSpriteSize()
        local spriteScale = self.faceSize / spriteW
        love.graphics.draw(image, quad, 0, 0, 0, spriteScale, spriteScale)
    else
        -- Fallback: draw value text
        love.graphics.setColor(1, 1, 1, self.alpha)
        self.nineSlice:draw(0, 0, self.faceSize, self.faceSize,
            Theme.colors.surface2, Theme.nineSlice.borderScale)
        local font = Theme.fonts.large
        love.graphics.setFont(font)
        local text = tostring(value)
        local textWidth = font:getWidth(text)
        love.graphics.print(text,
            (self.faceSize - textWidth) / 2,
            (self.faceSize - font:getHeight()) / 2)
    end

    love.graphics.pop()
end

return DiceTooltip
