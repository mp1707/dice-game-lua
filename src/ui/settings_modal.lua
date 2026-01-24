-- Settings Modal
-- Slides in from top, shows volume controls for music and sound FX

local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local Button = require("src.ui.button")
local Slider = require("src.ui.slider")
local Checkbox = require("src.ui.checkbox")
local Juice = require("src.ui.juice")
local Sound = require("src.core.sound")

local SettingsModal = {}
SettingsModal.__index = SettingsModal

function SettingsModal.new(config)
    local self = setmetatable({}, SettingsModal)

    -- Modal dimensions
    self.width = 500
    self.height = 400

    -- Center horizontally
    self.x = (Theme.screen.width - self.width) / 2

    -- Target Y when open (centered vertically)
    self.openY = (Theme.screen.height - self.height) / 2

    -- Start above screen
    self.y = -self.height
    self.targetY = -self.height
    self.velocity = 0

    -- State
    self.isOpen = false

    -- Padding and spacing
    self.padding = 24
    self.rowHeight = 90
    self.rowGap = 16
    self.headerHeight = 50

    -- Store original volumes for mute/unmute
    self.musicVolumeBeforeMute = Sound:getMusicVolume()
    self.sfxVolumeBeforeMute = Sound:getVolume()

    -- 9-slice renderer
    self.nineSlice = NineSlice.getInstance()

    -- Initialize UI components
    self:initComponents()

    -- Callbacks
    self.onClose = config.onClose

    return self
end

function SettingsModal:initComponents()
    local contentX = self.x + self.padding
    local contentWidth = self.width - self.padding * 2

    -- Slider width (70% of content width minus gap for checkbox)
    local sliderWidth = contentWidth * 0.65
    local checkboxX = contentX + sliderWidth + 20

    -- Music row (first row after header)
    local musicRowY = self.y + self.padding + self.headerHeight + 30 -- Label height offset

    self.musicSlider = Slider.new({
        x = contentX,
        y = musicRowY,
        width = sliderWidth,
        height = 40,
        value = Sound:getMusicVolume(),
        onChange = function(value)
            Sound:setMusicVolume(value)
            self.musicVolumeBeforeMute = value
            -- Uncheck mute if user moves slider
            if self.musicMuteCheckbox:isChecked() and value > 0 then
                self.musicMuteCheckbox:setChecked(false)
            end
        end,
    })

    self.musicMuteCheckbox = Checkbox.new({
        x = checkboxX,
        y = musicRowY + 6, -- Align with slider
        label = "Mute",
        checked = Sound:getMusicVolume() == 0,
        onChange = function(checked)
            if checked then
                self.musicVolumeBeforeMute = self.musicSlider:getValue()
                if self.musicVolumeBeforeMute == 0 then
                    self.musicVolumeBeforeMute = 0.3 -- Default restore value
                end
                Sound:setMusicVolume(0)
                self.musicSlider:setEnabled(false)
            else
                Sound:setMusicVolume(self.musicVolumeBeforeMute)
                self.musicSlider:setValue(self.musicVolumeBeforeMute)
                self.musicSlider:setEnabled(true)
            end
        end,
    })

    -- SFX row (second row)
    local sfxRowY = musicRowY + self.rowHeight + self.rowGap

    self.sfxSlider = Slider.new({
        x = contentX,
        y = sfxRowY,
        width = sliderWidth,
        height = 40,
        value = Sound:getVolume(),
        onChange = function(value)
            Sound:setVolume(value)
            self.sfxVolumeBeforeMute = value
            -- Uncheck mute if user moves slider
            if self.sfxMuteCheckbox:isChecked() and value > 0 then
                self.sfxMuteCheckbox:setChecked(false)
            end
        end,
    })

    self.sfxMuteCheckbox = Checkbox.new({
        x = checkboxX,
        y = sfxRowY + 6,
        label = "Mute",
        checked = Sound:getVolume() == 0,
        onChange = function(checked)
            if checked then
                self.sfxVolumeBeforeMute = self.sfxSlider:getValue()
                if self.sfxVolumeBeforeMute == 0 then
                    self.sfxVolumeBeforeMute = 1.0 -- Default restore value
                end
                Sound:setVolume(0)
                self.sfxSlider:setEnabled(false)
            else
                Sound:setVolume(self.sfxVolumeBeforeMute)
                self.sfxSlider:setValue(self.sfxVolumeBeforeMute)
                self.sfxSlider:setEnabled(true)
            end
        end,
    })

    -- Close button
    local buttonWidth = 180
    local buttonHeight = 50
    self.closeButton = Button.new({
        x = self.x + (self.width - buttonWidth) / 2,
        y = self.y + self.height - buttonHeight - self.padding,
        width = buttonWidth,
        height = buttonHeight,
        text = "Close",
        bgColor = Theme.colors.buttonGray,
        textColor = Theme.colors.text,
        font = Theme.fonts.normal,
        onClick = function()
            self:close()
        end,
    })
end

function SettingsModal:open()
    if self.isOpen then return end
    self.isOpen = true
    self.targetY = self.openY
    Sound:play("bling")

    -- Sync slider values with current Sound state
    self.musicSlider:setValue(Sound:getMusicVolume())
    self.sfxSlider:setValue(Sound:getVolume())
end

function SettingsModal:close()
    if not self.isOpen then return end
    self.isOpen = false
    self.targetY = -self.height
    if self.onClose then
        self.onClose()
    end
end

function SettingsModal:update(dt)
    -- Spring animation for Y position
    self.y, self.velocity = Juice.updateSpring(
        self.y,
        self.targetY,
        self.velocity,
        400, -- stiffness
        30,  -- damping
        dt
    )

    -- Update component positions based on modal Y
    self:updateComponentPositions()

    -- Update components
    if self.isOpen or self.y > -self.height + 10 then
        self.musicSlider:update(dt)
        self.musicMuteCheckbox:update(dt)
        self.sfxSlider:update(dt)
        self.sfxMuteCheckbox:update(dt)
        self.closeButton:update(dt)
    end
end

function SettingsModal:updateComponentPositions()
    local contentX = self.x + self.padding
    local contentWidth = self.width - self.padding * 2
    local sliderWidth = contentWidth * 0.65
    local checkboxX = contentX + sliderWidth + 20

    -- Music row
    local musicRowY = self.y + self.padding + self.headerHeight + 30
    self.musicSlider.y = musicRowY
    self.musicMuteCheckbox.y = musicRowY + 6

    -- SFX row
    local sfxRowY = musicRowY + self.rowHeight + self.rowGap
    self.sfxSlider.y = sfxRowY
    self.sfxMuteCheckbox.y = sfxRowY + 6

    -- Close button
    self.closeButton.y = self.y + self.height - self.closeButton.height - self.padding
end

function SettingsModal:draw()
    -- Don't draw if fully off screen
    if self.y <= -self.height then return end

    -- Semi-transparent backdrop
    if self.isOpen or self.y > -self.height + 10 then
        local backdropAlpha = math.min(0.6, (self.y + self.height) / self.height * 0.6)
        love.graphics.setColor(0, 0, 0, backdropAlpha)
        love.graphics.rectangle("fill", 0, 0, Theme.screen.width, Theme.screen.height)
    end

    -- Main modal panel
    self.nineSlice:draw(
        self.x,
        self.y,
        self.width,
        self.height,
        Theme.colors.panelDark,
        Theme.nineSlice.borderScale
    )

    -- Header
    local headerY = self.y + self.padding
    Theme:drawTextCenteredWithShadow(
        "SETTINGS",
        self.x,
        headerY,
        self.width,
        Theme.fonts.large,
        Theme.colors.gold
    )

    local contentX = self.x + self.padding

    -- Music section
    local musicLabelY = self.y + self.padding + self.headerHeight
    Theme:drawTextWithShadow("Music", contentX, musicLabelY, Theme.fonts.normal, Theme.colors.text)
    self.musicSlider:draw()
    self.musicMuteCheckbox:draw()

    -- SFX section
    local sfxLabelY = musicLabelY + self.rowHeight + self.rowGap - 30
    Theme:drawTextWithShadow("Sound FX", contentX, sfxLabelY, Theme.fonts.normal, Theme.colors.text)
    self.sfxSlider:draw()
    self.sfxMuteCheckbox:draw()

    -- Close button
    self.closeButton:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function SettingsModal:mousepressed(x, y, button)
    if not self.isOpen then return false end

    -- Check components
    if self.musicSlider:mousepressed(x, y, button) then return true end
    if self.musicMuteCheckbox:mousepressed(x, y, button) then return true end
    if self.sfxSlider:mousepressed(x, y, button) then return true end
    if self.sfxMuteCheckbox:mousepressed(x, y, button) then return true end
    if self.closeButton:mousepressed(x, y, button) then return true end

    -- Click outside modal to close
    if x < self.x or x > self.x + self.width or
       y < self.y or y > self.y + self.height then
        self:close()
        return true
    end

    -- Absorb clicks inside modal
    return true
end

function SettingsModal:mousereleased(x, y, button)
    if not self.isOpen and self.y <= -self.height + 10 then return false end

    if self.musicSlider:mousereleased(x, y, button) then return true end
    if self.musicMuteCheckbox:mousereleased(x, y, button) then return true end
    if self.sfxSlider:mousereleased(x, y, button) then return true end
    if self.sfxMuteCheckbox:mousereleased(x, y, button) then return true end
    if self.closeButton:mousereleased(x, y, button) then return true end

    return false
end

function SettingsModal:keypressed(key)
    if not self.isOpen then return false end

    if key == "escape" then
        self:close()
        return true
    end

    return false
end

return SettingsModal
