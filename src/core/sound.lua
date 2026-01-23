-- Sound Manager Singleton
-- Centralized audio playback for all game sounds
-- See assets/soundfx/CLAUDE.md for documentation

local Sound = {
    sources = {},      -- Preloaded audio sources
    volume = 1.0,      -- Master volume (0.0 to 1.0)
    music = nil,       -- Background music source
    musicVolume = 0.3, -- Music volume (0.0 to 1.0)
}

-- Sound configuration
local soundConfig = {
    lightClick = { file = "assets/soundfx/lightClick.wav", volume = 0.7 },
    click = { file = "assets/soundfx/click.wav", volume = 0.7 },
    button = { file = "assets/soundfx/button.wav", volume = 0.8 },
    cash = { file = "assets/soundfx/cash.wav", volume = 0.6 },
    diceroll = { file = "assets/soundfx/diceroll.wav", volume = 0.8 },
    tick2 = { file = "assets/soundfx/tick2.wav", volume = 0.6 },
    -- Additional sounds (available for future use)
    select = { file = "assets/soundfx/select.wav", volume = 0.7 },
    unselect = { file = "assets/soundfx/unselect.wav", volume = 0.7 },
    tick = { file = "assets/soundfx/tick.wav", volume = 0.5 },
    info = { file = "assets/soundfx/info.wav", volume = 0.6 },
    tap = { file = "assets/soundfx/tap.wav", volume = 0.6 },
    lost = { file = "assets/soundfx/lost.wav", volume = 0.7 },
    gameboy = { file = "assets/soundfx/gameboy.wav", volume = 0.7 },
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
        self.music:setVolume(self.musicVolume)
    end
end

-- Get music volume
function Sound:getMusicVolume()
    return self.musicVolume
end

-- Initialize on load
Sound:init()

return Sound
