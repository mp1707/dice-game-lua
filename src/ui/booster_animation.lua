-- Booster Animation Controller
-- Manages the booster pack opening animation sequence
-- Phases: FADE_OUT -> MOVING -> WIGGLING -> FLASH -> COMPLETE

local Theme = require("src.ui.theme")
local Juice = require("src.ui.juice")

local BoosterAnimation = {}
BoosterAnimation.__index = BoosterAnimation

-- Animation phases
BoosterAnimation.PHASE = {
    NONE = "none",
    FADE_OUT = "fade_out",
    MOVING = "moving",
    WIGGLING = "wiggling",
    FLASH = "flash",
    COMPLETE = "complete",
}

-- Phase durations (seconds)
local PHASE_DURATIONS = {
    [BoosterAnimation.PHASE.FADE_OUT] = 0.3,
    [BoosterAnimation.PHASE.MOVING] = 0.5,
    [BoosterAnimation.PHASE.WIGGLING] = 1.2,
    [BoosterAnimation.PHASE.FLASH] = 0.3,
}

-- Singleton instance
local instance = nil

function BoosterAnimation.getInstance()
    if not instance then
        instance = BoosterAnimation.new()
    end
    return instance
end

function BoosterAnimation.new()
    local self = setmetatable({}, BoosterAnimation)

    -- State
    self.phase = BoosterAnimation.PHASE.NONE
    self.phaseTimer = 0

    -- Gift sprite state
    self.giftX = 0
    self.giftY = 0
    self.giftStartX = 0
    self.giftStartY = 0
    self.giftTargetX = 0
    self.giftTargetY = 0
    self.giftScale = 1
    self.giftRotation = 0

    -- Shop fade
    self.shopAlpha = 1

    -- Flash effect
    self.flashAlpha = 0

    -- Callback
    self.onComplete = nil

    return self
end

function BoosterAnimation:start(startX, startY, onComplete)
    self.phase = BoosterAnimation.PHASE.FADE_OUT
    self.phaseTimer = 0

    -- Set up gift positions
    self.giftStartX = startX
    self.giftStartY = startY
    self.giftX = startX
    self.giftY = startY

    -- Target is center of the play area
    self.giftTargetX = Theme.layout.centerX + Theme.layout.centerWidth / 2
    self.giftTargetY = Theme.screen.height / 2

    -- Reset visual state
    self.giftScale = 1
    self.giftRotation = 0
    self.shopAlpha = 1
    self.flashAlpha = 0

    self.onComplete = onComplete
end

function BoosterAnimation:update(dt)
    if self.phase == BoosterAnimation.PHASE.NONE then
        return
    end

    self.phaseTimer = self.phaseTimer + dt

    if self.phase == BoosterAnimation.PHASE.FADE_OUT then
        self:updateFadeOut(dt)
    elseif self.phase == BoosterAnimation.PHASE.MOVING then
        self:updateMoving(dt)
    elseif self.phase == BoosterAnimation.PHASE.WIGGLING then
        self:updateWiggling(dt)
    elseif self.phase == BoosterAnimation.PHASE.FLASH then
        self:updateFlash(dt)
    end
end

function BoosterAnimation:updateFadeOut(dt)
    local duration = PHASE_DURATIONS[BoosterAnimation.PHASE.FADE_OUT]
    local progress = math.min(self.phaseTimer / duration, 1)

    -- Fade shop alpha
    self.shopAlpha = 1 - Juice.easeOutCubic(progress)

    -- Check for phase transition
    if progress >= 1 then
        self.phase = BoosterAnimation.PHASE.MOVING
        self.phaseTimer = 0
        self.shopAlpha = 0
    end
end

function BoosterAnimation:updateMoving(dt)
    local duration = PHASE_DURATIONS[BoosterAnimation.PHASE.MOVING]
    local progress = math.min(self.phaseTimer / duration, 1)
    local eased = Juice.easeOutCubic(progress)

    -- Move gift to center
    self.giftX = self.giftStartX + (self.giftTargetX - self.giftStartX) * eased
    self.giftY = self.giftStartY + (self.giftTargetY - self.giftStartY) * eased

    -- Scale up slightly during move
    self.giftScale = 1 + 0.2 * eased

    -- Check for phase transition
    if progress >= 1 then
        self.phase = BoosterAnimation.PHASE.WIGGLING
        self.phaseTimer = 0
    end
end

function BoosterAnimation:updateWiggling(dt)
    local duration = PHASE_DURATIONS[BoosterAnimation.PHASE.WIGGLING]
    local progress = math.min(self.phaseTimer / duration, 1)

    -- Wiggle with increasing intensity
    local wiggleIntensity = progress * 15 -- Max 15 degrees
    local wiggleSpeed = 8 + progress * 20  -- Accelerating speed
    self.giftRotation = math.sin(self.phaseTimer * wiggleSpeed) * math.rad(wiggleIntensity)

    -- Scale pulses slightly
    local scalePulse = math.sin(self.phaseTimer * 12) * 0.05 * progress
    self.giftScale = 1.2 + scalePulse

    -- Check for phase transition
    if progress >= 1 then
        self.phase = BoosterAnimation.PHASE.FLASH
        self.phaseTimer = 0
    end
end

function BoosterAnimation:updateFlash(dt)
    local duration = PHASE_DURATIONS[BoosterAnimation.PHASE.FLASH]
    local progress = math.min(self.phaseTimer / duration, 1)

    -- Flash in then out
    if progress < 0.4 then
        -- Flash in (0 to 0.4)
        self.flashAlpha = progress / 0.4
    else
        -- Flash out (0.4 to 1)
        self.flashAlpha = 1 - (progress - 0.4) / 0.6
    end

    -- Keep rotation at final position
    self.giftRotation = 0

    -- Check for phase transition
    if progress >= 1 then
        self.phase = BoosterAnimation.PHASE.COMPLETE
        self.flashAlpha = 0

        if self.onComplete then
            self.onComplete()
        end
    end
end

function BoosterAnimation:draw()
    if self.phase == BoosterAnimation.PHASE.NONE then
        return
    end

    -- Draw gift sprite
    if self.phase ~= BoosterAnimation.PHASE.COMPLETE then
        self:drawGift()
    end

    -- Draw flash overlay
    if self.flashAlpha > 0.01 then
        self:drawFlash()
    end
end

function BoosterAnimation:drawGift()
    local giftImage = Theme.images.gift
    if not giftImage then return end

    local spriteW = giftImage:getWidth()
    local spriteH = giftImage:getHeight()

    -- Base size (match shop item size)
    local baseSize = 160 * 0.75
    local baseScale = baseSize / math.max(spriteW, spriteH)
    local finalScale = baseScale * self.giftScale

    love.graphics.push()
    love.graphics.translate(self.giftX, self.giftY)
    love.graphics.rotate(self.giftRotation)
    love.graphics.scale(finalScale, finalScale)

    -- Apply white tint during flash
    if self.flashAlpha > 0.01 then
        -- Blend toward white
        local r = 1
        local g = 1
        local b = 1
        love.graphics.setColor(r, g, b, 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    love.graphics.draw(giftImage, -spriteW / 2, -spriteH / 2)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function BoosterAnimation:drawFlash()
    love.graphics.setColor(1, 1, 1, self.flashAlpha * 0.8)
    love.graphics.rectangle("fill", 0, 0, Theme.screen.width, Theme.screen.height)
    love.graphics.setColor(1, 1, 1, 1)
end

function BoosterAnimation:isActive()
    return self.phase ~= BoosterAnimation.PHASE.NONE and
        self.phase ~= BoosterAnimation.PHASE.COMPLETE
end

function BoosterAnimation:getShopAlpha()
    return self.shopAlpha
end

function BoosterAnimation:reset()
    self.phase = BoosterAnimation.PHASE.NONE
    self.phaseTimer = 0
    self.shopAlpha = 1
    self.flashAlpha = 0
    self.onComplete = nil
end

return BoosterAnimation
