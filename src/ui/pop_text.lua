-- PopText: Floating text with spring animation for counting animation
-- Pops up with scale overshoot and horizontal stretch, then fades out

local Theme = require("src.ui.theme")
local Juice = require("src.dice.juice")

local PopText = {}
PopText.__index = PopText

-- Spring parameters for pop animation
local POP_SPRING = {
    stiffness = 500,
    damping = 22,
}

-- Animation timing (50% slower for visibility)
local HOLD_DURATION = 1.2  -- Time before starting fade
local FADE_DURATION = 0.45 -- Fade out duration

function PopText.new(config)
    local self = setmetatable({}, PopText)

    -- Required config
    self.text = tostring(config.text)
    self.x = config.x
    self.y = config.y

    -- Optional config
    self.color = config.color or Theme.colors.text
    self.font = config.font or Theme.fonts.large

    -- Animation state
    self.scale = 0           -- Current scale (starts at 0, targets 1)
    self.scaleVelocity = 0
    self.scaleX = 1.5        -- Horizontal stretch (starts wide)
    self.scaleXVelocity = 0

    -- Timing
    self.timer = 0
    self.phase = "popping"   -- "popping" | "holding" | "fading" | "done"
    self.alpha = 1

    -- Y offset for initial pop-up movement
    self.yOffset = -20
    self.yOffsetVelocity = 0

    return self
end

function PopText:update(dt)
    if self.phase == "done" then
        return
    end

    self.timer = self.timer + dt

    if self.phase == "popping" then
        -- Update scale spring (0 -> 1 with overshoot to ~1.35)
        self.scale, self.scaleVelocity = Juice.updateSpring(
            self.scale, 1, self.scaleVelocity,
            POP_SPRING.stiffness, POP_SPRING.damping, dt
        )

        -- Update horizontal stretch spring (1.5 -> 1)
        self.scaleX, self.scaleXVelocity = Juice.updateSpring(
            self.scaleX, 1, self.scaleXVelocity,
            POP_SPRING.stiffness, POP_SPRING.damping, dt
        )

        -- Update Y offset spring (-20 -> 0)
        self.yOffset, self.yOffsetVelocity = Juice.updateSpring(
            self.yOffset, 0, self.yOffsetVelocity,
            POP_SPRING.stiffness, POP_SPRING.damping, dt
        )

        -- Check if springs have settled
        if math.abs(self.scale - 1) < 0.01 and math.abs(self.scaleVelocity) < 1 then
            self.scale = 1
            self.scaleX = 1
            self.yOffset = 0
            self.phase = "holding"
            self.timer = 0
        end

    elseif self.phase == "holding" then
        if self.timer >= HOLD_DURATION then
            self.phase = "fading"
            self.timer = 0
        end

    elseif self.phase == "fading" then
        local progress = self.timer / FADE_DURATION
        self.alpha = 1 - progress

        -- Slight upward drift while fading
        self.yOffset = self.yOffset - dt * 30

        if progress >= 1 then
            self.phase = "done"
            self.alpha = 0
        end
    end
end

function PopText:draw()
    if self.phase == "done" or self.alpha <= 0 then
        return
    end

    love.graphics.setFont(self.font)

    local textWidth = self.font:getWidth(self.text)
    local textHeight = self.font:getHeight()

    -- Calculate draw position (centered on x, y is top of text)
    local drawX = self.x - (textWidth * self.scale * self.scaleX) / 2
    local drawY = self.y + self.yOffset

    -- Apply color with alpha
    local r, g, b = self.color[1], self.color[2], self.color[3]
    local a = (self.color[4] or 1) * self.alpha

    love.graphics.push()
    love.graphics.translate(self.x, drawY + textHeight / 2)
    love.graphics.scale(self.scale * self.scaleX, self.scale)
    love.graphics.translate(-self.x, -(drawY + textHeight / 2))

    -- Draw shadow
    love.graphics.setColor(0, 0, 0, 0.5 * self.alpha)
    love.graphics.print(self.text, math.floor(drawX + 2), math.floor(drawY + 2))

    -- Draw main text
    love.graphics.setColor(r, g, b, a)
    love.graphics.print(self.text, math.floor(drawX), math.floor(drawY))

    love.graphics.pop()
end

function PopText:isDone()
    return self.phase == "done"
end

-- Force complete the animation immediately
function PopText:skip()
    self.phase = "done"
    self.alpha = 0
end

return PopText
