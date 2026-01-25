-- Booster Animation Controller
-- Manages the booster pack opening animation sequence
-- Phases: FADE_OUT -> WIGGLING -> FLASH -> COMPLETE

local Theme = require("src.ui.theme")
local Juice = require("src.ui.juice")
local Sound = require("src.core.sound")

local BoosterAnimation = {}
BoosterAnimation.__index = BoosterAnimation

-- Animation phases
BoosterAnimation.PHASE = {
    NONE = "none",
    FADE_OUT = "fade_out",
    WIGGLING = "wiggling",
    FLASH = "flash",
    COMPLETE = "complete",
}

-- Phase durations (seconds)
local PHASE_DURATIONS = {
    [BoosterAnimation.PHASE.FADE_OUT] = 0.1, -- Very fast fade/pre-delay
    [BoosterAnimation.PHASE.WIGGLING] = 0.6, -- Snappier wiggle
    [BoosterAnimation.PHASE.FLASH] = 0.25,   -- Faster flash/explosion
}

-- Shader for white flash effect
local whiteShader = love.graphics.newShader [[
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 texcolor = Texel(texture, texture_coords);
        return vec4(1.0, 1.0, 1.0, texcolor.a) * color;
    }
]]

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
    self.giftScale = 1
    self.giftRotation = 0

    -- Shop fade
    self.shopAlpha = 1

    -- Flash effect
    self.flashAlpha = 0

    -- Sparks
    self.sparks = {}

    -- Callback
    self.onComplete = nil

    return self
end

function BoosterAnimation:start(startX, startY, onComplete)
    self.phase = BoosterAnimation.PHASE.FADE_OUT
    self.phaseTimer = 0

    -- Target is center of the play area
    -- We ignore startX/startY for movement and just appear at target
    self.giftX = Theme.layout.centerX + Theme.layout.centerWidth / 2
    self.giftY = Theme.screen.height / 2

    -- Reset visual state
    self.giftScale = 1
    self.giftRotation = 0
    self.shopAlpha = 1
    self.flashAlpha = 0
    self.sparks = {}
    self.triggeredComplete = false

    self.onComplete = onComplete
end

function BoosterAnimation:update(dt)
    if self.phase == BoosterAnimation.PHASE.NONE then
        return
    end

    self.phaseTimer = self.phaseTimer + dt
    self:updateSparks(dt)

    if self.phase == BoosterAnimation.PHASE.FADE_OUT then
        self:updateFadeOut(dt)
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
        self.phase = BoosterAnimation.PHASE.WIGGLING
        self.phaseTimer = 0
        self.shopAlpha = 0
    end
end

function BoosterAnimation:updateWiggling(dt)
    local duration = PHASE_DURATIONS[BoosterAnimation.PHASE.WIGGLING]
    local progress = math.min(self.phaseTimer / duration, 1)

    -- Wiggle with increasing intensity (faster and juicier)
    local wiggleIntensity = progress * 12  -- Reduced amplitude (was 25)
    local wiggleSpeed = 20 + progress * 40 -- Much faster speed
    self.giftRotation = math.sin(self.phaseTimer * wiggleSpeed) * math.rad(wiggleIntensity)

    -- Scale pulses
    local scalePulse = math.sin(self.phaseTimer * 20) * 0.1 * progress
    self.giftScale = 1.2 + scalePulse

    -- Check for phase transition
    if progress >= 1 then
        self.phase = BoosterAnimation.PHASE.FLASH
        self.phaseTimer = 0
        self:spawnSparks()
        Sound:play("boxOpening")
    end
end

function BoosterAnimation:updateFlash(dt)
    local duration = PHASE_DURATIONS[BoosterAnimation.PHASE.FLASH]
    local progress = math.min(self.phaseTimer / duration, 1)

    -- Flash in then out (applied to sprite)
    if progress < 0.2 then
        -- Flash in very fast
        self.flashAlpha = progress / 0.2
    else
        -- Fade out
        self.flashAlpha = 1 - (progress - 0.2) / 0.8
    end

    -- Keep rotation at 0
    self.giftRotation = 0
    -- Expand scale for explosion effect
    self.giftScale = 1.2 + progress * 0.5

    -- Check for phase transition
    if progress >= 0.5 then -- Transition faster, don't wait for full fade out
        if not self.triggeredComplete then
            self.triggeredComplete = true
            if self.onComplete then
                self.onComplete()
            end
        end
    end

    if progress >= 1 then
        self.phase = BoosterAnimation.PHASE.COMPLETE
        self.flashAlpha = 0
    end
end

function BoosterAnimation:spawnSparks()
    self.sparks = {}
    for i = 1, 30 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(200, 500)
        table.insert(self.sparks, {
            x = self.giftX,
            y = self.giftY,
            dx = math.cos(angle) * speed,
            dy = math.sin(angle) * speed,
            life = 0.5 + math.random() * 0.3,
            maxLife = 0.8,
            size = math.random(2, 5),
            color = Theme.colors.gold -- Use gold sparks
        })
    end
end

function BoosterAnimation:updateSparks(dt)
    for i = #self.sparks, 1, -1 do
        local spark = self.sparks[i]
        spark.x = spark.x + spark.dx * dt
        spark.y = spark.y + spark.dy * dt
        spark.life = spark.life - dt

        -- Gravity-ish
        spark.dy = spark.dy + 200 * dt

        if spark.life <= 0 then
            table.remove(self.sparks, i)
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

    -- Draw sparks
    self:drawSparks()
end

function BoosterAnimation:drawGift()
    local giftImage = Theme.images.gift
    if not giftImage then return end

    local spriteW = giftImage:getWidth()
    local spriteH = giftImage:getHeight()

    -- Base size (match shop item size)
    -- Using the new reduced size factor: 160 * 0.525
    local baseSize = 160 * 0.525
    local baseScale = baseSize / math.max(spriteW, spriteH)
    local finalScale = baseScale * self.giftScale

    love.graphics.push()
    love.graphics.translate(self.giftX, self.giftY)
    love.graphics.rotate(self.giftRotation)
    love.graphics.scale(finalScale, finalScale)

    -- Apply white tint during flash
    if self.flashAlpha > 0.01 then
        love.graphics.setShader(whiteShader)
        love.graphics.setColor(1, 1, 1, self.flashAlpha)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    love.graphics.draw(giftImage, -spriteW / 2, -spriteH / 2)

    love.graphics.setShader()
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function BoosterAnimation:drawSparks()
    if #self.sparks == 0 then return end

    for _, spark in ipairs(self.sparks) do
        local alpha = spark.life / spark.maxLife
        local r, g, b = unpack(spark.color or Theme.colors.white)
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.rectangle("fill", spark.x, spark.y, spark.size, spark.size)
    end
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
    self.sparks = {}
    self.onComplete = nil
end

return BoosterAnimation
