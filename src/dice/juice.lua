-- Juice System for Dice Animations
-- Screen shake and other polish effects

local Juice = {}

-- Easing functions
function Juice.easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

function Juice.easeOutElastic(t)
    local c4 = (2 * math.pi) / 3

    if t == 0 then
        return 0
    elseif t == 1 then
        return 1
    else
        return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
    end
end

function Juice.easeOutBounce(t)
    local n1 = 7.5625
    local d1 = 2.75

    if t < 1 / d1 then
        return n1 * t * t
    elseif t < 2 / d1 then
        t = t - 1.5 / d1
        return n1 * t * t + 0.75
    elseif t < 2.5 / d1 then
        t = t - 2.25 / d1
        return n1 * t * t + 0.9375
    else
        t = t - 2.625 / d1
        return n1 * t * t + 0.984375
    end
end

function Juice.easeOutCubic(t)
    return 1 - math.pow(1 - t, 3)
end

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

-- =============================================================================
-- BREATHING ANIMATION
-- Subtle oscillation for "alive" feeling
-- =============================================================================

-- Get breathing animation values
-- @param time: Current animation time
-- @param index: Dice index (for phase offset)
-- @return scale, yOffset
function Juice.getBreathingValues(time, index)
    -- Each die has a phase offset for organic wave effect
    local phaseOffset = (index - 1) * 0.4
    local breathCycle = time + phaseOffset

    -- Subtle scale oscillation (0.98 - 1.02)
    local scaleOscillation = math.sin(breathCycle * 2.5) * 0.015
    local scale = 1 + scaleOscillation

    -- Subtle Y offset oscillation (±2px)
    local yOffset = math.sin(breathCycle * 2.5 + 0.5) * 2

    return scale, yOffset
end

-- =============================================================================
-- SPRING PHYSICS
-- For pop/bounce animations with overshoot
-- =============================================================================

-- Update spring physics
-- @param current: Current value
-- @param target: Target value
-- @param velocity: Current velocity
-- @param stiffness: Spring stiffness (higher = faster)
-- @param damping: Damping factor (higher = less overshoot)
-- @param dt: Delta time
-- @return newValue, newVelocity
function Juice.updateSpring(current, target, velocity, stiffness, damping, dt)
    -- Calculate spring force
    local displacement = target - current
    local springForce = displacement * stiffness
    local dampingForce = velocity * damping

    -- Apply forces
    local acceleration = springForce - dampingForce
    local newVelocity = velocity + acceleration * dt
    local newValue = current + newVelocity * dt

    -- Snap to target if close enough and slow enough
    if math.abs(displacement) < 0.5 and math.abs(newVelocity) < 1 then
        return target, 0
    end

    return newValue, newVelocity
end

-- =============================================================================
-- HOVER TILT (Balatro-style)
-- 3D perspective tilt based on mouse position
-- =============================================================================

-- Calculate hover effects based on mouse position
-- @param mouseX, mouseY: Current mouse position
-- @param centerX, centerY: Dice center position
-- @param size: Dice size
-- @return rotation (radians), scaleX, scaleY, isHovered
function Juice.getHoverEffects(mouseX, mouseY, centerX, centerY, size)
    -- Check if mouse is within hover area (slightly larger than dice)
    local hoverPadding = size * 0.3
    local dx = mouseX - centerX
    local dy = mouseY - centerY
    local halfSize = size / 2 + hoverPadding

    local isHovered = math.abs(dx) < halfSize and math.abs(dy) < halfSize

    if not isHovered then
        return 0, 1, 1, false
    end

    -- Normalize position within hover area (-1 to 1)
    local normalizedX = dx / halfSize
    local normalizedY = dy / halfSize

    -- Calculate rotation (tilt toward mouse, max ±8 degrees)
    local maxRotation = math.rad(8)
    local rotation = normalizedX * maxRotation * 0.5

    -- Slight scale increase when hovered
    local hoverScale = 1.08

    -- Perspective effect: slight Y scale based on vertical mouse position
    local perspectiveY = 1 + normalizedY * 0.03

    return rotation, hoverScale, hoverScale * perspectiveY, true
end

-- Get selection pop parameters
-- @return initialScale, initialYOffset, stiffness, damping
function Juice.getSelectionPopParams()
    return 1.15, -20, 320, 24
end

-- Get deselection pop parameters (smaller, snappier)
-- @return initialScale, initialYOffset, stiffness, damping
function Juice.getDeselectionPopParams()
    return 0.94, 6, 400, 26
end

return Juice
