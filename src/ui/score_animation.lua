-- Score Animation Controller
-- Manages the counting animation sequence when "Play Hand" is pressed
-- State machine: IDLE -> COUNTING -> CALCULATING -> UPDATING_TOTAL -> COMPLETE

local Theme = require("src.ui.theme")
local Juice = require("src.ui.juice")
local PopText = require("src.ui.pop_text")
local Sound = require("src.core.sound")

local ScoreAnimation = {}
ScoreAnimation.__index = ScoreAnimation

-- Timing constants
-- Timing constants
local TIMING = {
    countDelay = 0.6,       -- Reverted to slower checking (was 0.15)
    calcDuration = 0.4,     -- Duration of calculating phase (faster)
    calcBoxFadeStart = 0.0, -- Start fading immediately
    calcScoreAppear = 0.05, -- Reveal score almost immediately
    completeHold = 0.35,    -- Hold before firing callback
}

-- Spring parameters
local SPRINGS = {
    boxPop = { stiffness = 400, damping = 24 },
    handScore = { stiffness = 450, damping = 26 },
    diePulse = { stiffness = 600, damping = 28 },
}

-- Singleton instance
local instance = nil

function ScoreAnimation.getInstance()
    if not instance then
        instance = setmetatable({}, ScoreAnimation)
        instance:reset()
    end
    return instance
end

function ScoreAnimation:reset()
    self.state = "IDLE"
    self.timer = 0
    self.currentDieIndex = 0
    self.data = nil

    -- Animation state
    self.accumulatedChips = 0
    self.popTexts = {}
    self.displayedScore = 0

    -- Box animation state (fade out + scale down for juice)
    self.boxAlpha = 1
    self.boxScale = 1

    -- Chips text animation (only the number pulses, not the box)
    self.chipsTextScale = 1
    self.chipsTextScaleVelocity = 0

    -- Hand score animation state
    self.handScoreVisible = false
    self.handScoreScale = 0
    self.handScoreScaleVelocity = 0

    -- Total score count-up state
    self.totalCountProgress = 0
    self.totalCountDuration = 0
    self.totalScoreScale = 1 -- Scale for punching the total score
end

function ScoreAnimation:start(config)
    self:reset()

    -- Store configuration
    self.data = {
        handId = config.handId,
        breakdown = config.breakdown,
        oldScore = config.oldScore,
        scoringDiceIndices = config.scoringDiceIndices or {},
        diceDisplays = config.diceDisplays,
        diceVisualOrder = config.diceVisualOrder,
        infoPanel = config.infoPanel,
        onComplete = config.onComplete,
    }

    -- Initialize accumulated chips to basePoints
    self.accumulatedChips = self.data.breakdown.basePoints

    -- Start with counting phase (or skip if no dice to count)
    if #self.data.scoringDiceIndices > 0 then
        self.state = "COUNTING"
        self.currentDieIndex = 0
        -- Start with timer = 0 to wait full countDelay before first die
        self.timer = 0

        -- Prime the tick sound to avoid first-sound-not-playing bug
        -- Playing at zero volume initializes the audio source
        Sound:play("tick", { volume = 0 })
    else
        -- No scoring dice, skip to calculating
        self.state = "CALCULATING"
        self.timer = 0
    end
end

function ScoreAnimation:update(dt)
    if self.state == "IDLE" then
        return
    end

    self.timer = self.timer + dt

    -- Update pop texts
    for i = #self.popTexts, 1, -1 do
        self.popTexts[i]:update(dt)
        if self.popTexts[i]:isDone() then
            table.remove(self.popTexts, i)
        end
    end

    -- Update chips text scale spring (subtle pulse, not the box)
    self.chipsTextScale, self.chipsTextScaleVelocity = Juice.updateSpring(
        self.chipsTextScale, 1, self.chipsTextScaleVelocity,
        SPRINGS.boxPop.stiffness, SPRINGS.boxPop.damping, dt
    )

    -- Update hand score scale spring
    if self.handScoreVisible then
        self.handScoreScale, self.handScoreScaleVelocity = Juice.updateSpring(
            self.handScoreScale, 1, self.handScoreScaleVelocity,
            SPRINGS.handScore.stiffness, SPRINGS.handScore.damping, dt
        )
    end

    -- Update total score scale spring (punch effect)
    self.totalScoreScale, self.totalScoreScaleVelocity = Juice.updateSpring(
        self.totalScoreScale, 1, self.totalScoreScaleVelocity or 0,
        SPRINGS.boxPop.stiffness, SPRINGS.boxPop.damping, dt
    )

    -- State machine
    if self.state == "COUNTING" then
        self:updateCounting(dt)
    elseif self.state == "CALCULATING" then
        self:updateCalculating(dt)
    elseif self.state == "UPDATING_TOTAL" then
        self:updateUpdatingTotal(dt)
    elseif self.state == "COMPLETE" then
        self:updateComplete(dt)
    end
end

function ScoreAnimation:updateCounting(dt)
    -- Count each die's pip value - die pulse AND number pop-up happen TOGETHER
    if self.timer >= TIMING.countDelay then
        self.timer = self.timer - TIMING.countDelay
        self.currentDieIndex = self.currentDieIndex + 1

        if self.currentDieIndex <= #self.data.scoringDiceIndices then
            local dieIndex = self.data.scoringDiceIndices[self.currentDieIndex]
            local display = self.data.diceDisplays[dieIndex]

            if display then
                -- DEBUG: Print which die is being counted
                print("[ScoreAnimation] Counting die #" ..
                    tostring(self.currentDieIndex) .. " (dieIndex=" .. tostring(dieIndex) .. ")")

                -- Play tick sound for this die being counted
                Sound:play("tick")

                -- Trigger BOTH selection pop AND count pulse at the same time
                display.selectionScale = 1.15
                display.selectionYOffset = -20
                display.selectionScaleVelocity = 0
                display.selectionYVelocity = 0
                display:triggerCountPulse()

                -- Get pip value for this die
                local diceData = display.getDiceData()
                local pipValue = diceData.value

                -- Create pop text above die (use huge font for visibility)
                local popX = display.x + display.size / 2
                local popY = display.y - 60 -- Higher up for bigger text

                local popText = PopText.new({
                    text = "+" .. pipValue,
                    x = popX,
                    y = popY,
                    color = Theme.colors.text,
                    font = Theme.fonts.huge, -- Bigger font!
                })
                table.insert(self.popTexts, popText)

                -- Add to accumulated chips
                self.accumulatedChips = self.accumulatedChips + pipValue

                -- Trigger subtle text pulse animation (not the box)
                self.chipsTextScale = 1.12
                self.chipsTextScaleVelocity = 0
            end
        else
            -- All dice counted, move to calculating
            self.state = "CALCULATING"
            self.timer = 0
        end
    end
end

function ScoreAnimation:updateCalculating(dt)
    -- Animate the formula boxes disappearing and hand score appearing
    local progress = self.timer / TIMING.calcDuration

    -- Fade out and scale down boxes together (much faster and juicier)
    -- Fade out and scale down boxes together (much faster and juicier)
    if self.timer >= TIMING.calcBoxFadeStart then
        local fadeDuration = TIMING.calcScoreAppear - TIMING.calcBoxFadeStart
        local fadeProgress = math.min(1, (self.timer - TIMING.calcBoxFadeStart) / fadeDuration)
        -- Use linear for alpha, but back-in for scale? actually just simple cubic out is fine for fade
        local easedFade = Juice.easeOutCubic(fadeProgress)
        self.boxAlpha = math.max(0, 1 - easedFade)
        -- Scale down from 1 to 0.5 as boxes fade
        self.boxScale = 1 - (easedFade * 0.5)
    end

    -- Show hand score (appears sooner now)
    if self.timer >= TIMING.calcScoreAppear and not self.handScoreVisible then
        self.handScoreVisible = true
        self.handScoreScale = 0
        self.handScoreScaleVelocity = 60 -- Higher initial velocity for snappier pop
    end

    -- Move to updating total
    if progress >= 1 then
        self.state = "UPDATING_TOTAL"
        self.timer = 0
        self.displayedScore = self.data.oldScore

        -- Calculate count-up duration based on score difference (slower and smoother)
        local diff = self.data.breakdown.total
        self.totalCountDuration = math.min(2.5, math.max(1.5, diff / 60))

        -- Play bling sound for the total count up
        Sound:play("bling")
    end
end

function ScoreAnimation:updateUpdatingTotal(dt)
    -- Count up the total score
    local progress = self.timer / self.totalCountDuration

    -- Ease-out-cubic for smoother, less jarring deceleration
    local t = math.min(1, progress)
    local easedProgress = 1 - (1 - t) ^ 3

    self.displayedScore = self.data.oldScore + self.data.breakdown.total * easedProgress

    if progress >= 1 then
        self.displayedScore = self.data.oldScore + self.data.breakdown.total
        self.state = "COMPLETE"
        self.timer = 0

        -- PUNCH the total score display!
        self.totalScoreScale = 1.3
        self.totalScoreScaleVelocity = 0
        Sound:play("tick")
    end
end

function ScoreAnimation:updateComplete(dt)
    if self.timer >= TIMING.completeHold then
        -- Fire completion callback
        if self.data.onComplete then
            self.data.onComplete()
        end

        self:reset()
    end
end

function ScoreAnimation:draw()
    if self.state == "IDLE" then
        return
    end

    -- Draw pop texts
    for _, popText in ipairs(self.popTexts) do
        popText:draw()
    end
end

function ScoreAnimation:isAnimating()
    return self.state ~= "IDLE"
end

-- Get animated values for the info panel to use
function ScoreAnimation:getAnimatedChips()
    if self.state == "IDLE" then
        return nil
    end
    return math.floor(self.accumulatedChips)
end

function ScoreAnimation:getChipsTextScale()
    return self.chipsTextScale
end

function ScoreAnimation:getBoxAlpha()
    return self.boxAlpha
end

function ScoreAnimation:getBoxScale()
    return self.boxScale
end

function ScoreAnimation:isHandScoreVisible()
    return self.handScoreVisible
end

function ScoreAnimation:getHandScore()
    if self.data and self.data.breakdown then
        return self.data.breakdown.total
    end
    return 0
end

function ScoreAnimation:getHandScoreScale()
    return self.handScoreScale
end

function ScoreAnimation:getAnimatedTotalScore()
    if self.state == "UPDATING_TOTAL" or self.state == "COMPLETE" then
        return math.floor(self.displayedScore)
    end
    return nil
end

function ScoreAnimation:getTotalScoreScale()
    return self.totalScoreScale or 1
end

-- Skip to end (for impatient players)
function ScoreAnimation:skip()
    if self.state == "IDLE" then
        return
    end

    -- Clear all pop texts
    for _, popText in ipairs(self.popTexts) do
        popText:skip()
    end
    self.popTexts = {}

    -- Fire completion callback
    if self.data and self.data.onComplete then
        self.data.onComplete()
    end

    self:reset()
end

return ScoreAnimation
