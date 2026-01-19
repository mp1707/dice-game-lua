-- Theme constants for the dice game
-- Colors, fonts, spacing, and layout values

local Theme = {}

-- Colors (RGBA 0-1, converted from hex)
Theme.colors = {
    -- Core backgrounds
    bg = { 0.165, 0.133, 0.259, 1 },               -- #2A2242
    bg2 = { 0.235, 0.196, 0.357, 1 },              -- #3C325B
    surface = { 0.208, 0.169, 0.345, 1 },          -- #352B58
    surface2 = { 0.290, 0.239, 0.478, 1 },         -- #4A3D7A
    surfaceHighlight = { 0.365, 0.302, 0.561, 1 }, -- #5D4D8F

    -- Text
    text = { 1, 1, 1, 1 },
    textMuted = { 0.667, 0.620, 0.812, 1 }, -- #AA9ECF
    textDark = { 0.102, 0.082, 0.157, 1 },  -- #1A1528

    -- Accents
    cyan = { 0.302, 0.933, 0.918, 1 },      -- #4DEEEA
    gold = { 1, 0.784, 0.341, 1 },          -- #FFC857
    goldHighlight = { 1, 0.851, 0.522, 1 }, -- #FFD985
    coral = { 1, 0.353, 0.478, 1 },         -- #FF5A7A
    mint = { 0.424, 1, 0.722, 1 },          -- #6CFFB8

    -- Borders
    border = { 0.365, 0.302, 0.561, 1 },          -- #5D4D8F
    borderHighlight = { 0.533, 0.455, 0.769, 1 }, -- #8874C4

    -- Dice enhancement colors
    upgradePoints = { 0, 0.384, 1, 1 },       -- #0062FF (blue)
    upgradeMult = { 0.878, 0.180, 0.298, 1 }, -- #E02E4C (red)

    -- Overlays (pre-mixed for convenience)
    overlayWhite = { 1, 1, 1, 0.2 },
    overlayBlack = { 0, 0, 0, 0.3 },
    overlayCyan = { 0.302, 0.933, 0.918, 0.15 },
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

-- Screen dimensions (1080p virtual resolution - Balatro style)
Theme.screen = {
    width = 1920,
    height = 1080,
}

-- 9-slice configuration
Theme.nineSlice = {
    cornerSize = 24,
    borderScale = 0.5, -- Scale factor for 9-slice borders (0.5 = half size)
    image = nil,       -- Loaded in Theme:load()
}

-- Fonts
Theme.fonts = {
    small = nil,   -- 18px
    normal = nil,  -- 24px
    large = nil,   -- 36px
    huge = nil,    -- 48px
    display = nil, -- 66px
}

-- Images
Theme.images = {
    coin = nil,
    glove = nil,
    die = nil,
    lock = nil,
}

-- Layout constants for Balatro-style 3-column UI (1080p)
-- NEW LAYOUT: Hands on LEFT, Info on RIGHT, Center has item strip + held tray + loose dice
Theme.layout = {
    -- Screen padding
    screenPadding = 24,
    panelPadding = 24,

    -- Left Panel (Hand Selection) - NOW ON LEFT
    leftPanelX = 24,
    leftPanelY = 24,
    leftPanelWidth = 280,   -- wider for icons + text
    leftPanelHeight = 1032,

    -- Hand list (single column in left panel)
    handListItemHeight = 70, -- taller for bigger icons
    handListItemSpacing = 4,
    handListPadding = 10,

    -- Center Area (Item Strip + Held Tray + Loose Dice + Action)
    centerX = 328,       -- 24 + 280 + 24
    centerWidth = 1188,  -- adjusted for wider left panel

    -- Item strip (top center) - 7 empty slots
    itemStripY = 24,
    itemStripHeight = 80,
    itemSlotSize = 70,
    itemSlotSpacing = 12,
    itemSlotCount = 7,

    -- Held tray (middle center) - 5 slots for locked dice
    heldTrayY = 380,
    heldTrayHeight = 160,
    heldSlotSize = 120,
    heldSlotSpacing = 20,
    heldSlotCount = 5,

    -- Loose dice area (below held tray)
    looseDiceY = 580,
    looseDiceHeight = 300,
    diceSize = 120,
    diceSpacing = 30,

    -- Action button (in info panel now, but keep for reference)
    actionButtonY = 920,
    actionButtonWidth = 300,
    actionButtonHeight = 80,

    -- Right Panel (Info/Stats) - NOW ON RIGHT
    rightPanelX = 1540, -- 1920 - 24 - 356
    rightPanelY = 24,
    rightPanelWidth = 356,
    rightPanelHeight = 1032,

    -- Top bar in center (Level indicator) - removed, level now in info panel
    topBarY = 24,
    topBarHeight = 90,
}

function Theme:load()
    -- Load 9-slice texture
    self.nineSlice.image = love.graphics.newImage("assets/ui/pixelSurface.png")
    self.nineSlice.image:setFilter("nearest", "nearest")

    -- Load fonts (scaled 1.5x for 1080p)
    local fontPath = "assets/fonts/m6x11plus.ttf"
    self.fonts.small = love.graphics.newFont(fontPath, 18)   -- was 12
    self.fonts.normal = love.graphics.newFont(fontPath, 24)  -- was 16
    self.fonts.large = love.graphics.newFont(fontPath, 36)   -- was 24
    self.fonts.huge = love.graphics.newFont(fontPath, 48)    -- was 32
    self.fonts.display = love.graphics.newFont(fontPath, 66) -- was 44

    -- Set filter for crisp text
    for _, font in pairs(self.fonts) do
        font:setFilter("nearest", "nearest")
    end

    -- Load images
    self.images.coin = love.graphics.newImage("assets/icons/ui/coin.png")
    self.images.coin:setFilter("nearest", "nearest")

    self.images.glove = love.graphics.newImage("assets/icons/ui/Glove.png")
    self.images.glove:setFilter("nearest", "nearest")

    self.images.die = love.graphics.newImage("assets/icons/ui/die.png")
    self.images.die:setFilter("nearest", "nearest")

    self.images.lock = love.graphics.newImage("assets/icons/ui/lock.png")
    self.images.lock:setFilter("nearest", "nearest")
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
