-- Physics Configuration for Dice Rolling
-- Tunable parameters for adjusting the feel of dice animations

local Physics = {
    -- Gravity (pixels per second squared)
    gravity = 1800,

    -- Bounce behavior
    baseBounceStrength = 650,    -- Initial upward velocity on bounce
    bounceDamping = 0.68,        -- Multiplier per bounce (0.5 = half strength)
    horizontalDamping = 0.7,     -- How much horizontal speed is lost per bounce
    angularDamping = 0.6,        -- How much rotation slows per bounce

    -- Settling
    settleSpeed = 8,             -- Lerp speed when settling to final position

    -- Squash/stretch
    squashDuration = 0.08,       -- How long squash effect lasts
    squashAmount = 0.7,          -- Scale Y multiplier during squash
    stretchAmount = 1.2,         -- Scale Y multiplier during fast fall

    -- Face changes during animation
    faceChangeInterval = 0.04,   -- How fast faces cycle during roll (~25fps)

    -- Initial drop parameters (ranges for randomization)
    dropHeight = { min = 200, max = 350 },
    initialVelocityX = { min = -80, max = 80 },
    initialVelocityY = { min = 20, max = 60 },
    initialAngularVelocity = { min = -15, max = 15 },

    -- Bounce count range
    bounceCount = { min = 2, max = 5 },

    -- Slot constraints
    slotWidth = 70,              -- How much horizontal freedom within slot

    -- Stagger timing
    staggerDelay = 0,            -- Per-die delay multiplier (0 = instant start)
    staggerRandom = 0.02,        -- Random addition to stagger (minimal for organic feel)
}

-- Helper function to get random value within a range
function Physics.randomInRange(range)
    return range.min + math.random() * (range.max - range.min)
end

-- Helper to get random integer in range (inclusive)
function Physics.randomIntInRange(range)
    return math.random(range.min, range.max)
end

-- Generate roll parameters for a single die
function Physics.generateRollParams(slotIndex, slotCenterX, groundY)
    local params = {}

    -- Determine final face (1-6)
    params.targetFace = math.random(1, 6)

    -- Randomize bounce count
    params.maxBounces = Physics.randomIntInRange(Physics.bounceCount)

    -- Calculate drop position
    -- Start above the slot center with some random offset
    local slotWidth = Physics.slotWidth
    params.startX = slotCenterX + (math.random() - 0.5) * slotWidth * 0.8
    params.startY = groundY  -- Y position stays near ground level
    params.startHeight = Physics.randomInRange(Physics.dropHeight)

    -- Initial velocities
    params.velocityX = Physics.randomInRange(Physics.initialVelocityX)
    params.velocityY = Physics.randomInRange(Physics.initialVelocityY)
    params.velocityZ = 0  -- Start with no vertical velocity (will accelerate down)
    params.angularVelocity = Physics.randomInRange(Physics.initialAngularVelocity)

    -- Final target position (within slot bounds with small variation)
    local targetOffsetX = (math.random() - 0.5) * slotWidth * 0.6
    local targetOffsetY = (math.random() - 0.5) * 90
    params.targetX = slotCenterX + targetOffsetX
    params.targetY = groundY + targetOffsetY

    -- Final rotation (small random tilt)
    params.targetRotation = (math.random() - 0.5) * 0.3  -- ~8.5 degrees max

    -- Stagger start time for more organic feel
    params.startDelay = slotIndex * Physics.staggerDelay + math.random() * Physics.staggerRandom

    return params
end

return Physics
