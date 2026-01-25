-- Sound Manager Singleton
-- Centralized audio playback for all game sounds
-- See assets/soundfx/CLAUDE.md for documentation

local Sound = {
    sources = {},       -- Preloaded audio sources
    volume = 1.0,       -- Master volume (0.0 to 1.0)
    music = nil,        -- Background music source
    musicVolume = 0.3,  -- Music volume (0.0 to 1.0)
    musicMuted = false, -- Whether music is muted
}

-- Sound configuration
local soundConfig = {
    lightClick = { file = "assets/soundfx/lightClick.wav", volume = 0.7 },
    click = { file = "assets/soundfx/click.wav", volume = 0.7 },
    button = { file = "assets/soundfx/button.wav", volume = 0.8 },
    cash = { file = "assets/soundfx/cash.wav", volume = 0.6 },
    -- New dice roll sounds (per-die impact sounds)
    diceroll1 = { file = "assets/soundfx/diceroll1.wav", volume = 0.7 },
    diceroll2 = { file = "assets/soundfx/diceroll2.wav", volume = 0.7 },
    diceroll3 = { file = "assets/soundfx/diceroll3.wav", volume = 0.7 },
    diceroll4 = { file = "assets/soundfx/diceroll4.wav", volume = 0.7 },
    tick2 = { file = "assets/soundfx/tick2.wav", volume = 0.8 },
    -- Additional sounds (available for future use)
    unselect = { file = "assets/soundfx/unselect.wav", volume = 0.7 },
    tick = { file = "assets/soundfx/tick.wav", volume = 0.5 },
    info = { file = "assets/soundfx/info.wav", volume = 0.6 },
    tap = { file = "assets/soundfx/tap.wav", volume = 0.6 },
    lost = { file = "assets/soundfx/lost.wav", volume = 0.7 },
    gameboy = { file = "assets/soundfx/gameboy.wav", volume = 0.7 },
    bling = { file = "assets/soundfx/bling.wav", volume = 0.7 },
    boxOpening = { file = "assets/soundfx/boxOpening.wav", volume = 0.8 },
}

-- Initialize and preload all sounds
function Sound:init()
    for name, config in pairs(soundConfig) do
        local success, source = pcall(function()
            return love.audio.newSource(config.file, "static")
        end)
        if success then
            self.sources[name] = {
                source = source,
                volume = config.volume or 1.0,
            }
        else
            print("[Sound] Warning: Failed to load " .. config.file)
        end
    end

    -- Load background music (streamed for memory efficiency)
    local success, music = pcall(function()
        return love.audio.newSource("assets/soundfx/Analog Dreams - Blue Saga.ogg", "stream")
    end)
    if success then
        music:setLooping(true)
        music:setVolume(self.musicVolume)
        self.music = music
        print("[Sound] Background music loaded")
    else
        print("[Sound] Warning: Failed to load background music")
    end
end

-- Play a sound by name
-- @param name string - Sound name (e.g., "select", "button")
-- @param opts table (optional) - { volume, pitch, pitchVariance }
function Sound:play(name, opts)
    local soundData = self.sources[name]
    if not soundData then
        print("[Sound] Warning: Unknown sound '" .. tostring(name) .. "'")
        return
    end

    opts = opts or {}

    -- Clone the source to allow overlapping playback
    local source = soundData.source:clone()

    -- Calculate final volume
    local volume = (opts.volume or 1.0) * soundData.volume * self.volume
    source:setVolume(volume)

    -- Apply pitch with optional variance
    local pitch = opts.pitch or 1.0
    if opts.pitchVariance then
        pitch = pitch + (math.random() - 0.5) * 2 * opts.pitchVariance
    end
    source:setPitch(pitch)

    -- Play the sound
    love.audio.play(source)
end

-- Play a random dice roll sound (for impact)
-- @param opts table (optional) - { volume, pitch, pitchVariance }
function Sound:playDiceRoll(opts)
    local rollSounds = { "diceroll1", "diceroll2", "diceroll3", "diceroll4" }
    local randomSound = rollSounds[math.random(1, 4)]
    opts = opts or {}
    -- Add slight pitch variance for natural feel
    opts.pitchVariance = opts.pitchVariance or 0.08
    self:play(randomSound, opts)
end

-- Start background music
function Sound:startMusic()
    if self.music then
        -- Stop any existing music first (important for hot reload)
        if self.music:isPlaying() then
            self.music:stop()
        end
        love.audio.play(self.music)
        print("[Sound] Background music started")
    end
end

-- Stop background music
function Sound:stopMusic()
    if self.music and self.music:isPlaying() then
        self.music:stop()
    end
end

-- Toggle music mute state
function Sound:toggleMusicMute()
    self.musicMuted = not self.musicMuted
    if self.music then
        local targetVol = self.musicMuted and 0 or self.musicVolume
        self.music:setVolume(targetVol)
        print("[Sound] Music " .. (self.musicMuted and "muted" or "unmuted"))
    end
    return self.musicMuted
end

-- Set master volume
function Sound:setVolume(vol)
    self.volume = math.max(0, math.min(1, vol))
end

-- Get master volume
function Sound:getVolume()
    return self.volume
end

-- Set music volume
function Sound:setMusicVolume(vol)
    self.musicVolume = math.max(0, math.min(1, vol))
    if self.music then
        local targetVol = self.musicMuted and 0 or self.musicVolume
        self.music:setVolume(targetVol)
    end
end

-- Get music volume
function Sound:getMusicVolume()
    return self.musicVolume
end

-- Initialize on load
Sound:init()

return Sound
