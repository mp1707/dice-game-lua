-- Theme constants for the dice game
-- Colors, fonts, spacing, and layout values

local Theme = {}

-- Colors (RGBA 0-1, converted from hex)
Theme.colors = {
    -- Core backgrounds
    bg = {0.165, 0.133, 0.259, 1},           -- #2A2242
    bg2 = {0.235, 0.196, 0.357, 1},          -- #3C325B
    surface = {0.208, 0.169, 0.345, 1},       -- #352B58
    surface2 = {0.290, 0.239, 0.478, 1},      -- #4A3D7A
    surfaceHighlight = {0.365, 0.302, 0.561, 1}, -- #5D4D8F

    -- Text
    text = {1, 1, 1, 1},
    textMuted = {0.667, 0.620, 0.812, 1},     -- #AA9ECF
    textDark = {0.102, 0.082, 0.157, 1},      -- #1A1528

    -- Accents
    cyan = {0.302, 0.933, 0.918, 1},          -- #4DEEEA
    gold = {1, 0.784, 0.341, 1},              -- #FFC857
    goldHighlight = {1, 0.851, 0.522, 1},     -- #FFD985
    coral = {1, 0.353, 0.478, 1},             -- #FF5A7A
    mint = {0.424, 1, 0.722, 1},              -- #6CFFB8

    -- Borders
    border = {0.365, 0.302, 0.561, 1},        -- #5D4D8F
    borderHighlight = {0.533, 0.455, 0.769, 1}, -- #8874C4

    -- Dice enhancement colors
    upgradePoints = {0, 0.384, 1, 1},         -- #0062FF (blue)
    upgradeMult = {0.878, 0.180, 0.298, 1},   -- #E02E4C (red)

    -- Overlays (pre-mixed for convenience)
    overlayWhite = {1, 1, 1, 0.2},
    overlayBlack = {0, 0, 0, 0.3},
    overlayCyan = {0.302, 0.933, 0.918, 0.15},
}

-- Spacing scale (pixels)
Theme.spacing = {
    xxs = 2,
    xs = 4,
    sm = 8,
    md = 12,
    lg = 16,
    xl = 20,
    xxl = 24,
}

-- Dimensions
Theme.dimensions = {
    borderRadius = 12,
    borderRadiusSmall = 8,
    borderRadiusLarge = 16,
    borderWidth = 2,
    borderWidthThin = 1,
    borderWidthThick = 3,
}

-- Screen dimensions
Theme.screen = {
    width = 1280,
    height = 720,
}

-- 9-slice configuration
Theme.nineSlice = {
    cornerSize = 12,
    image = nil, -- Loaded in Theme:load()
}

-- Fonts
Theme.fonts = {
    small = nil,    -- 12px
    normal = nil,   -- 16px
    large = nil,    -- 24px
    huge = nil,     -- 32px
    display = nil,  -- 44px
}

-- Images
Theme.images = {
    coin = nil,
}

-- Layout constants for Balatro-style 3-column UI
Theme.layout = {
    -- Screen padding
    screenPadding = 16,
    panelPadding = 16,

    -- Left Panel (Info/Stats)
    leftPanelX = 16,
    leftPanelY = 16,
    leftPanelWidth = 260,
    leftPanelHeight = 688,

    -- Center Area (Dice + Action)
    centerX = 292,
    centerWidth = 680,

    -- Dice area (in center)
    diceAreaY = 200,
    diceAreaHeight = 160,
    diceSize = 80,
    diceSpacing = 20,

    -- Action button (in center, below dice)
    actionButtonY = 420,
    actionButtonWidth = 280,
    actionButtonHeight = 60,

    -- Score preview (in center, below action)
    previewY = 500,
    previewWidth = 400,
    previewHeight = 80,

    -- Right Panel (Hand Selection)
    rightPanelX = 988,
    rightPanelY = 16,
    rightPanelWidth = 276,
    rightPanelHeight = 688,

    -- Hand buttons (2 columns in right panel)
    handButtonWidth = 120,
    handButtonHeight = 50,
    handButtonSpacing = 8,
    handRowSpacing = 8,
    handPanelPadding = 12,

    -- Top bar in center (Level indicator)
    topBarY = 16,
    topBarHeight = 60,
}

function Theme:load()
    -- Load 9-slice texture
    self.nineSlice.image = love.graphics.newImage("assets/ui/pixelSurface.png")
    self.nineSlice.image:setFilter("nearest", "nearest")

    -- Load fonts
    local fontPath = "assets/fonts/m6x11plus.ttf"
    self.fonts.small = love.graphics.newFont(fontPath, 12)
    self.fonts.normal = love.graphics.newFont(fontPath, 16)
    self.fonts.large = love.graphics.newFont(fontPath, 24)
    self.fonts.huge = love.graphics.newFont(fontPath, 32)
    self.fonts.display = love.graphics.newFont(fontPath, 44)

    -- Set filter for crisp text
    for _, font in pairs(self.fonts) do
        font:setFilter("nearest", "nearest")
    end

    -- Load images
    self.images.coin = love.graphics.newImage("assets/icons/ui/coin.png")
    self.images.coin:setFilter("nearest", "nearest")
end

-- Helper function to draw text centered
function Theme:drawTextCentered(text, x, y, width, font, color)
    font = font or self.fonts.normal
    color = color or self.colors.text

    love.graphics.setFont(font)
    love.graphics.setColor(color)

    local textWidth = font:getWidth(text)
    local textX = x + (width - textWidth) / 2
    love.graphics.print(text, math.floor(textX), math.floor(y))
end

-- Helper function to draw text right-aligned
function Theme:drawTextRight(text, x, y, width, font, color)
    font = font or self.fonts.normal
    color = color or self.colors.text

    love.graphics.setFont(font)
    love.graphics.setColor(color)

    local textWidth = font:getWidth(text)
    local textX = x + width - textWidth
    love.graphics.print(text, math.floor(textX), math.floor(y))
end

return Theme
