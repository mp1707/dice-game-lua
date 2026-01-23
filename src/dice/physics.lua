-- Physics Configuration for Dice Rolling
-- Tunable parameters for adjusting the feel of dice animations

local Physics = {
    -- Gravity (pixels per second squared)
    gravity = 2200,

    -- Bounce behavior
    baseBounceStrength = 380, -- Reduced for quicker settle
    bounceDamping = 0.55,     -- More damping per bounce
    horizontalDamping = 0.6,  -- More damping to settle faster

    -- Settling
    settleSpeed = 14, -- Faster lerp to final position

    -- Squash/stretch
    squashDuration = 0.06, -- Slightly faster squash
    squashAmount = 0.75,   -- Scale Y multiplier during squash
    stretchAmount = 1.15,  -- Less stretch for snappier feel

    -- Roll animation
    faceChangeInterval = 0.035, -- Slightly faster face cycling

    -- Initial drop parameters (ranges for randomization) - REDUCED for shorter animation
    dropHeight = { min = 120, max = 200 },
    initialVelocityX = { min = -50, max = 50 },
    initialVelocityY = { min = 10, max = 40 },

    -- Bounce count range - REDUCED for faster settling
    bounceCount = { min = 1, max = 2 },

    -- Slot constraints
    slotWidth = 70, -- How much horizontal freedom within slot

    -- Stagger timing
    staggerDelay = 0,     -- Per-die delay multiplier (0 = instant start)
    staggerRandom = 0.02, -- Random addition to stagger (minimal for organic feel)

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
    params.startY = groundY -- Y position stays near ground level
    params.startHeight = Physics.randomInRange(Physics.dropHeight)

    -- Initial velocities
    params.velocityX = Physics.randomInRange(Physics.initialVelocityX)
    params.velocityY = Physics.randomInRange(Physics.initialVelocityY)
    params.velocityZ = 0 -- Start with no vertical velocity (will accelerate down)

    -- Final target position (use the passed-in position - now correctly calculated as a row)
    params.targetX = slotCenterX
    params.targetY = groundY

    -- Stagger start time for more organic feel
    params.startDelay = slotIndex * Physics.staggerDelay + math.random() * Physics.staggerRandom

    return params
end

return Physics
