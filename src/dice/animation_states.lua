-- Animation State Machine for Dice Rolling
-- Defines states and state handler functions

local AnimationStates = {}

-- State constants
AnimationStates.IDLE = "idle"
AnimationStates.DROPPING = "dropping"
AnimationStates.BOUNCING = "bouncing"
AnimationStates.SETTLING = "settling"
AnimationStates.LOCKED = "locked"

-- State handlers table
AnimationStates.Handlers = {}

-- IDLE: Die sits still, no updates needed
function AnimationStates.Handlers.idle(die, dt, physics)
    return AnimationStates.IDLE
end

-- DROPPING: Die is falling with gravity, cycling faces
function AnimationStates.Handlers.dropping(die, dt, physics)
    -- Apply gravity to vertical velocity
    die.velocityZ = die.velocityZ + physics.gravity * dt

    -- Update height (negative height = above ground)
    die.height = die.height - die.velocityZ * dt

    -- Apply horizontal movement
    die.x = die.x + die.velocityX * dt
    die.y = die.y + die.velocityY * dt

    -- Apply spring force toward target X position
    local distToTargetX = die.targetX - die.x
    die.velocityX = die.velocityX + distToTargetX * 8 * dt
    -- Apply damping
    die.velocityX = die.velocityX * (1 - physics.horizontalDamping * dt)
    die.velocityY = die.velocityY * (1 - physics.horizontalDamping * dt)

    -- Rotate while falling
    die.rotation = die.rotation + die.angularVelocity * dt
    -- Slow rotation over time (air resistance)
    die.angularVelocity = die.angularVelocity * (1 - 2 * dt)

    -- Cycle through faces rapidly
    die.faceChangeTimer = die.faceChangeTimer + dt
    if die.faceChangeTimer >= physics.faceChangeInterval then
        die.faceChangeTimer = 0
        die.currentFace = math.random(1, 6)
    end

    -- Apply stretch when falling fast
    if die.velocityZ > 100 then
        local stretchAmount = math.min(math.abs(die.velocityZ) / 600, 0.25)
        die.scaleY = 1 + stretchAmount
        die.scaleX = 1 - stretchAmount * 0.4
    end

    -- Check for ground hit (height reaches 0)
    if die.height <= 0 then
        die.height = 0
        return AnimationStates.BOUNCING
    end

    return AnimationStates.DROPPING
end

-- BOUNCING: Die hits ground, triggers bounce or settles
function AnimationStates.Handlers.bouncing(die, dt, physics)
    die.bounceCount = die.bounceCount + 1

    -- Check if we've bounced enough
    if die.bounceCount > die.maxBounces then
        die.currentFace = die.targetFace
        return AnimationStates.SETTLING
    end

    -- Calculate bounce strength (decreases each bounce)
    local bounceStrength = physics.baseBounceStrength *
                           math.pow(physics.bounceDamping, die.bounceCount)

    -- Apply bounce velocity (negative = upward)
    die.velocityZ = -bounceStrength

    -- Reduce horizontal velocity
    die.velocityX = die.velocityX * physics.horizontalDamping
    die.velocityY = die.velocityY * physics.horizontalDamping

    -- Reduce angular velocity and nudge toward final rotation
    die.angularVelocity = die.angularVelocity * physics.angularDamping
    local rotationDiff = die.targetRotation - die.rotation
    die.rotation = die.rotation + rotationDiff * 0.3

    -- Squash effect on impact
    die.squashTimer = physics.squashDuration

    -- Change face on bounce (except last bounce shows target)
    if die.bounceCount < die.maxBounces then
        die.currentFace = math.random(1, 6)
    else
        die.currentFace = die.targetFace
    end

    -- Trigger screen shake callback if available
    if die.onBounce then
        die.onBounce(die.bounceCount, die.maxBounces)
    end

    return AnimationStates.DROPPING  -- Go back to dropping (will rise then fall)
end

-- SETTLING: Die lerps to final position
function AnimationStates.Handlers.settling(die, dt, physics)
    local lerpSpeed = physics.settleSpeed * dt

    -- Lerp position toward target
    die.x = die.x + (die.targetX - die.x) * lerpSpeed
    die.y = die.y + (die.targetY - die.y) * lerpSpeed

    -- Lerp rotation to target
    die.rotation = die.rotation + (die.targetRotation - die.rotation) * lerpSpeed

    -- Lerp scale back to normal
    die.scaleX = die.scaleX + (1 - die.scaleX) * lerpSpeed
    die.scaleY = die.scaleY + (1 - die.scaleY) * lerpSpeed

    -- Check if settled (close enough to target)
    local distX = math.abs(die.x - die.targetX)
    local distY = math.abs(die.y - die.targetY)
    local rotDist = math.abs(die.rotation - die.targetRotation)

    if distX < 0.5 and distY < 0.5 and rotDist < 0.01 then
        -- Snap to final position
        die.x = die.targetX
        die.y = die.targetY
        die.rotation = die.targetRotation
        die.scaleX = 1
        die.scaleY = 1
        return AnimationStates.LOCKED
    end

    return AnimationStates.SETTLING
end

-- LOCKED: Die is locked in place
function AnimationStates.Handlers.locked(die, dt, physics)
    return AnimationStates.LOCKED
end

return AnimationStates
