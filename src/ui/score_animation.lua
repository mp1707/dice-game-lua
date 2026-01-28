-- Score Animation Controller
-- Manages the counting animation sequence when "Play Hand" is pressed
-- State machine: IDLE -> COUNTING -> CALCULATING -> UPDATING_TOTAL -> COMPLETE

local Theme = require("src.ui.theme")
local Juice = require("src.ui.juice")
local PopText = require("src.ui.pop_text")
local Sound = require("src.core.sound")
local GameState = require("src.game.game_state")

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
    self.accumulatedMult = 0
    self.popTexts = {}
    self.displayedScore = 0

    -- Box animation state (fade out + scale down for juice)
    self.boxAlpha = 1
    self.boxScale = 1

    -- Chips text animation (only the number pulses, not the box)
    self.chipsTextScale = 1
    self.chipsTextScaleVelocity = 0

    -- Mult text animation
    self.multTextScale = 1
    self.multTextScaleVelocity = 0

    -- Hand score animation state
    self.handScoreVisible = false
    self.handScoreScale = 0
    self.handScoreScaleVelocity = 0

    -- Total score count-up state
    self.totalCountProgress = 0
    self.totalCountDuration = 0
    self.totalScoreScale = 1 -- Scale for punching the total score

    -- Sequence state
    self.sequence = {}
    self.currentStepIndex = 0
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
        diceVisualOrder = config.diceVisualOrder,
        infoPanel = config.infoPanel,
        itemStrip = config.itemStrip,
        onComplete = config.onComplete,
    }

    -- Initialize accumulated values
    self.accumulatedChips = self.data.breakdown.basePoints
    self.accumulatedMult = self.data.breakdown.mult

    -- Build the animation sequence from scoring dice
    self:buildSequence()

    -- Start with counting phase (or skip if no steps)
    if #self.sequence > 0 then
        self.state = "COUNTING"
        self.currentStepIndex = 0
        -- Start with timer = 0 to wait full countDelay before first step
        self.timer = 0

        -- Prime the tick sound
        Sound:play("tick", { volume = 0 })
    else
        -- No scoring steps, skip to calculating
        self.state = "CALCULATING"
        self.timer = 0
    end
end

function ScoreAnimation:buildSequence()
    self.sequence = {}
    local prismaticDice = self.data.breakdown.prismaticDice or {}

    -- Create lookup for prismatic value
    local prismaticValueMap = {}
    for _, pd in ipairs(prismaticDice) do
        prismaticValueMap[pd.index] = pd.value
    end

    for _, dieIndex in ipairs(self.data.scoringDiceIndices) do
        -- Get the die value from the display (or data)
        local value = 0
        local dieData = nil
        if self.data.diceDisplays[dieIndex] then
            dieData = self.data.diceDisplays[dieIndex].getDiceData()
            value = dieData.value
        end

        -- Step 1: Count Pips
        table.insert(self.sequence, {
            type = "PIPS",
            dieIndex = dieIndex,
            value = value
        })

        -- Step 2: Count Mult (only if Prismatic)
        if prismaticValueMap[dieIndex] then
            table.insert(self.sequence, {
                type = "MULT",
                dieIndex = dieIndex,
                value = value -- The mult added is the die value
            })
        end
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

    -- Update chips text scale spring
    self.chipsTextScale, self.chipsTextScaleVelocity = Juice.updateSpring(
        self.chipsTextScale, 1, self.chipsTextScaleVelocity,
        SPRINGS.boxPop.stiffness, SPRINGS.boxPop.damping, dt
    )

    -- Update mult text scale spring
    self.multTextScale, self.multTextScaleVelocity = Juice.updateSpring(
        self.multTextScale, 1, self.multTextScaleVelocity,
        SPRINGS.boxPop.stiffness, SPRINGS.boxPop.damping, dt
    )

    -- Update hand score scale spring
    if self.handScoreVisible then
        self.handScoreScale, self.handScoreScaleVelocity = Juice.updateSpring(
            self.handScoreScale, 1, self.handScoreScaleVelocity,
            SPRINGS.handScore.stiffness, SPRINGS.handScore.damping, dt
        )
    end

    -- Update total score scale spring
    self.totalScoreScale, self.totalScoreScaleVelocity = Juice.updateSpring(
        self.totalScoreScale, 1, self.totalScoreScaleVelocity or 0,
        SPRINGS.boxPop.stiffness, SPRINGS.boxPop.damping, dt
    )

    -- State machine
    if self.state == "COUNTING" then
        self:updateCounting(dt)
    elseif self.state == "ANIMATING_TRIGGERS" then
        self:updateAnimatingTriggers(dt)
    elseif self.state == "CALCULATING" then
        self:updateCalculating(dt)
    elseif self.state == "UPDATING_TOTAL" then
        self:updateUpdatingTotal(dt)
    elseif self.state == "COMPLETE" then
        self:updateComplete(dt)
    end
end

function ScoreAnimation:updateCounting(dt)
    -- Process sequence steps

    if self.timer >= TIMING.countDelay then
        self.timer = self.timer - TIMING.countDelay
        self.currentStepIndex = self.currentStepIndex + 1

        if self.currentStepIndex <= #self.sequence then
            local step = self.sequence[self.currentStepIndex]
            local display = self.data.diceDisplays[step.dieIndex]

            if display then
                -- Play tick sound
                Sound:play("tick")

                -- Trigger die pulse
                display.selectionScale = 1.15
                display.selectionYOffset = -20
                display.selectionScaleVelocity = 0
                display.selectionYVelocity = 0
                display:triggerCountPulse()

                local popX = display.x + display.size / 2

                if step.type == "PIPS" then
                    -- Handle PIPS step
                    local popY = display.y - 60 -- Above die

                    local popText = PopText.new({
                        text = "+" .. step.value,
                        x = popX,
                        y = popY,
                        color = Theme.colors.text,
                        font = Theme.fonts.huge,
                    })
                    table.insert(self.popTexts, popText)

                    -- Update chips
                    self.accumulatedChips = self.accumulatedChips + step.value

                    -- Pulse chips text (Blue)
                    self.chipsTextScale = 1.12
                    self.chipsTextScaleVelocity = 0
                elseif step.type == "MULT" then
                    -- Handle MULT step (prismatic)
                    local popY = display.y + display.size + 30 -- Below die

                    local popText = PopText.new({
                        text = "x" .. step.value,
                        x = popX,
                        y = popY,
                        color = Theme.colors.coral, -- Red multiplier color
                        font = Theme.fonts.huge,
                    })
                    table.insert(self.popTexts, popText)

                    -- Update mult
                    self.accumulatedMult = self.accumulatedMult * step.value

                    -- Pulse mult text (Red)
                    self.multTextScale = 1.12
                    self.multTextScaleVelocity = 0
                end
            end
        else
            -- Sequence complete, emit HAND_SCORED trigger
            local TriggerSystem = require("src.items.trigger_system")
            local Trigger = require("src.items.trigger_types")

            local triggerContext = {
                handId = self.data.handId,
                mult = self.accumulatedMult,
                chips = self.accumulatedChips,
                scoringIndices = self.data.scoringDiceIndices,
                triggeredEffects = {} -- Queue for visual effects
            }

            TriggerSystem:emit(Trigger.HAND_SCORED, triggerContext)

            -- Check if any effects triggered visuals
            if #triggerContext.triggeredEffects > 0 then
                self.state = "ANIMATING_TRIGGERS"
                self.triggerQueue = triggerContext.triggeredEffects
                self.currentTriggerIndex = 0
                self.timer = TIMING.countDelay

                -- Store final values to snap to at the end
                self.targetMult = triggerContext.mult
                self.targetChips = triggerContext.chips
            else
                -- No visual effects, update values immediately
                self.accumulatedMult = triggerContext.mult
                self.accumulatedChips = triggerContext.chips

                self.state = "CALCULATING"
                self.timer = 0
            end
        end
    end
end

function ScoreAnimation:updateAnimatingTriggers(dt)
    if self.timer >= TIMING.countDelay then
        self.timer = 0
        self.currentTriggerIndex = self.currentTriggerIndex + 1

        if self.currentTriggerIndex <= #self.triggerQueue then
            local effect = self.triggerQueue[self.currentTriggerIndex]

            -- 1. Trigger Item Strip Animation
            if self.data.itemStrip then
                self.data.itemStrip:triggerItemAnim(effect.slotIndex)
            end

            -- 2. Show Pop Text (centerish or near item strip? usually center top)
            -- Ideally near the item, but we don't know item position easily without quering itemStrip
            -- Let's put it near the itemStrip area or center top
            local popX = Theme.layout.centerX
            -- Calculate roughly where the slot is if possible, or just center
            -- Using a generic position for now
            local layout = Theme.layout
            if self.data.itemStrip then
                local slotX = self.data.itemStrip:getSlotX(effect.slotIndex)
                popX = slotX + layout.itemSlotSize / 2
            end

            local popY = layout.itemStripY + layout.itemSlotSize + 20

            local color = Theme.colors.text
            if effect.color == "red" then color = Theme.colors.coral end
            -- Add others as needed

            local popText = PopText.new({
                text = effect.text,
                x = popX,
                y = popY,
                color = color,
                font = Theme.fonts.huge,
            })
            table.insert(self.popTexts, popText)

            -- 3. Sound
            Sound:play("tick") -- Use tick or specific sound

            -- 4. Pulse the Mult/Chips display if relevant
            -- Since we don't track *which* value changed per effect easily without diffing,
            -- we assume mult items pulse mult, chip items pulse chips.
            -- For now, just pulse both slightly or check effect text?
            -- " Some Spice" is +4 Mult. "First Aid" is +10 Mult.
            -- Assume Mult pulse for now since that's what we implemented.
            -- 4. Apply Score Changes Incrementally (Score like dice)
            if effect.multMod then
                self.accumulatedMult = self.accumulatedMult + effect.multMod
                self.multTextScale = 1.12
                self.multTextScaleVelocity = 0
            end

            if effect.chipsMod then
                self.accumulatedChips = self.accumulatedChips + effect.chipsMod
                self.chipsTextScale = 1.12
                self.chipsTextScaleVelocity = 0
            end
        else
            -- Done with triggers, move to calculating
            self.state = "CALCULATING"
            self.timer = 0

            -- Snap to target values (handles any silent effects or floating point drift)
            if self.targetMult then self.accumulatedMult = self.targetMult end
            if self.targetChips then self.accumulatedChips = self.targetChips end

            -- Update the final total in breakdown so calculating phase uses new total
            self.data.breakdown.mult = self.accumulatedMult
            self.data.breakdown.pips = self.accumulatedChips - self.data.breakdown.basePoints -- Approx
            -- Actually we just need to update total for the count up
            self.data.breakdown.total = self.accumulatedChips * self.accumulatedMult
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

function ScoreAnimation:getAnimatedMult()
    if self.state == "IDLE" then
        return nil
    end
    return math.floor(self.accumulatedMult)
end

function ScoreAnimation:getChipsTextScale()
    return self.chipsTextScale
end

function ScoreAnimation:getMultTextScale()
    return self.multTextScale
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
