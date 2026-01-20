-- Juice System for Dice Animations
-- Screen shake and other polish effects

local Juice = {}

-- Screen shake state
Juice.shake = {
    intensity = 0,
    duration = 0,
    timer = 0,
}

-- Trigger a screen shake effect
-- @param intensity: Maximum pixel displacement
-- @param duration: How long the shake lasts in seconds
function Juice.triggerShake(intensity, duration)
    -- Only override if new shake is stronger
    if intensity > Juice.shake.intensity * (Juice.shake.timer / Juice.shake.duration) then
        Juice.shake.intensity = intensity
        Juice.shake.duration = duration
        Juice.shake.timer = duration
    end
end

-- Update shake state
-- @param dt: Delta time
function Juice.updateShake(dt)
    if Juice.shake.timer > 0 then
        Juice.shake.timer = Juice.shake.timer - dt
        if Juice.shake.timer < 0 then
            Juice.shake.timer = 0
        end
    else
        Juice.shake.intensity = 0
    end
end

-- Get current shake offset for rendering
-- @return offsetX, offsetY: Pixel offsets to apply to rendering
function Juice.getShakeOffset()
    if Juice.shake.timer <= 0 or Juice.shake.duration <= 0 then
        return 0, 0
    end

    -- Calculate progress (1 at start, 0 at end)
    local progress = Juice.shake.timer / Juice.shake.duration

    -- Current intensity decays with progress
    local currentIntensity = Juice.shake.intensity * progress

    -- Random offset within current intensity
    local offsetX = (math.random() - 0.5) * 2 * currentIntensity
    local offsetY = (math.random() - 0.5) * 2 * currentIntensity

    return offsetX, offsetY
end

-- Reset shake state
function Juice.resetShake()
    Juice.shake.intensity = 0
    Juice.shake.duration = 0
    Juice.shake.timer = 0
end

-- Calculate shake intensity based on bounce number
-- Earlier bounces = stronger shake
-- @param bounceCount: Current bounce number (1 = first bounce)
-- @param maxBounces: Total bounces expected
-- @return intensity, duration
function Juice.getBounceShake(bounceCount, maxBounces)
    -- Intensity decreases with each bounce
    local baseIntensity = 3
    local intensity = baseIntensity * (1 - (bounceCount - 1) / maxBounces)
    local duration = 0.08

    return intensity, duration
end

return Juice
