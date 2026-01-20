-- Dice Manager
-- Orchestrates all 5 dice, handles rolling, updates, and rendering

local Die = require("src.dice.die")
local Physics = require("src.dice.physics")
local Juice = require("src.dice.juice")

local DiceManager = {}
DiceManager.__index = DiceManager

function DiceManager.new(config)
    local self = setmetatable({}, DiceManager)

    config = config or {}

    -- Layout configuration
    self.positions = config.positions or {}  -- Array of {x, y} positions for each die
    self.groundY = config.groundY or 400
    self.diceSize = config.diceSize or 120

    -- Create dice array
    self.dice = {}

    -- Rolling state
    self.isRolling = false

    -- Callbacks
    self.onRollComplete = nil  -- Called when all dice finish animating
    self.onBounce = nil        -- Called on each bounce (for sound effects)

    return self
end

-- Initialize dice at given positions
-- @param positions: Array of {x, y} positions for each die
function DiceManager:initDice(positions)
    self.positions = positions
    self.dice = {}

    for i, pos in ipairs(positions) do
        -- Calculate slot center (position is top-left, we need center)
        local slotCenterX = pos.x + self.diceSize / 2

        local die = Die.new(i, slotCenterX, pos.y, self.diceSize)

        -- Set up bounce callback
        die.onBounce = function(bounceNum, maxBounces)
            self:handleBounce(i, bounceNum, maxBounces)
        end

        self.dice[i] = die
    end
end

-- Handle bounce event from a die
function DiceManager:handleBounce(dieIndex, bounceNum, maxBounces)
    -- Trigger screen shake
    local intensity, duration = Juice.getBounceShake(bounceNum, maxBounces)
    Juice.triggerShake(intensity, duration)

    -- Call external bounce callback if set
    if self.onBounce then
        self.onBounce(dieIndex, bounceNum, maxBounces)
    end
end

-- Start rolling dice
-- @param targetFaces: Optional table of predetermined results {3, 1, 5, 2, 6}
-- @param lockedIndices: Table of dice indices that should not roll (e.g., {2, 4})
function DiceManager:roll(targetFaces, lockedIndices)
    -- Convert locked indices to a set for fast lookup
    local isLocked = {}
    if lockedIndices then
        for _, idx in ipairs(lockedIndices) do
            isLocked[idx] = true
        end
    end

    self.isRolling = true

    for i, die in ipairs(self.dice) do
        if not isLocked[i] then
            -- Generate roll parameters
            local params = Physics.generateRollParams(
                i,
                die.slotCenterX,
                self.positions[i].y
            )

            -- Override target face if provided
            if targetFaces and targetFaces[i] then
                params.targetFace = targetFaces[i]
            end

            -- Start the roll animation
            die:startRoll(params)
        end
    end
end

-- Update all dice
function DiceManager:update(dt)
    -- Update juice effects
    Juice.updateShake(dt)

    -- Track if any die is still animating
    local anyAnimating = false

    for _, die in ipairs(self.dice) do
        die:update(dt)

        if not die:isStable() then
            anyAnimating = true
        end
    end

    -- Check if rolling just completed
    if self.isRolling and not anyAnimating then
        self.isRolling = false

        if self.onRollComplete then
            local results = self:getResults()
            self.onRollComplete(results)
        end
    end
end

-- Draw all dice (with proper layering)
function DiceManager:draw()
    -- Apply screen shake
    local shakeX, shakeY = Juice.getShakeOffset()
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    -- Draw all shadows first
    for _, die in ipairs(self.dice) do
        die:drawShadow()
    end

    -- Sort dice by visual Y position for proper overlap
    local sortedDice = {}
    for _, die in ipairs(self.dice) do
        table.insert(sortedDice, die)
    end
    table.sort(sortedDice, function(a, b)
        return (a.y - a.height) < (b.y - b.height)
    end)

    -- Draw all dice
    for _, die in ipairs(sortedDice) do
        die:draw()
    end

    love.graphics.pop()
end

-- Get current face values
function DiceManager:getResults()
    local results = {}
    for i, die in ipairs(self.dice) do
        results[i] = die:getFace()
    end
    return results
end

-- Set face values directly (when not animating)
function DiceManager:setFaces(faces)
    for i, face in ipairs(faces) do
        if self.dice[i] then
            self.dice[i]:setFace(face)
        end
    end
end

-- Check if any dice are animating
function DiceManager:isAnimating()
    for _, die in ipairs(self.dice) do
        if not die:isStable() then
            return true
        end
    end
    return false
end

-- Get a specific die
function DiceManager:getDie(index)
    return self.dice[index]
end

-- Reset all dice to idle at their positions
function DiceManager:reset()
    for i, die in ipairs(self.dice) do
        local pos = self.positions[i]
        if pos then
            die:resetToIdle(pos.x, pos.y)
        end
    end
    self.isRolling = false
    Juice.resetShake()
end

-- Update a die's position (for when moving to/from held tray)
function DiceManager:setDiePosition(index, x, y)
    local die = self.dice[index]
    if die then
        die.x = x
        die.y = y
        die.slotCenterX = x + die.size / 2
    end
end

return DiceManager
