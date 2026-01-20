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
    panelDark = { 0.12, 0.10, 0.18, 1 },           -- Darker containers inside panels

    -- Text
    text = { 1, 1, 1, 1 },
    textMuted = { 0.667, 0.620, 0.812, 1 }, -- #AA9ECF
    textDark = { 0.102, 0.082, 0.157, 1 },  -- #1A1528
    textShadow = { 0, 0, 0, 0.5 },          -- Text shadow color

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

    -- Button colors
    buttonGray = { 0.35, 0.35, 0.40, 1 },         -- Settings button
    buttonLightBlue = { 0.45, 0.70, 0.90, 1 },    -- Info button
    buttonPurple = { 0.55, 0.35, 0.75, 1 },       -- Würfeln button

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
    giant = nil,   -- 80px (for goal number)
}

-- Images
Theme.images = {
    coin = nil,
    glove = nil,
    die = nil,
    lock = nil,
    diceFaces = {},  -- Array for dice faces 1-6
}

-- Layout constants for new 2-column UI (1080p)
-- NEW LAYOUT: Info on LEFT, Center has item strip + selection panels + dice + CTAs
Theme.layout = {
    -- Screen padding
    screenPadding = 24,
    panelPadding = 20,
    innerGap = 12,           -- Consistent small gap between elements

    -- Left Panel (Info/Stats) - NOW ON LEFT
    leftPanelX = 24,
    leftPanelY = 24,
    leftPanelWidth = 380,
    leftPanelHeight = 1032,

    -- Center Area (Item Strip + Selection Panels + Dice + CTAs)
    centerX = 428,           -- 24 + 380 + 24
    centerWidth = 1468,      -- 1920 - 428 - 24

    -- Item strip (top center) - 5 + gap + 2 slots
    itemStripY = 24,
    itemStripHeight = 100,
    itemSlotSize = 90,
    itemSlotSpacing = 16,
    itemSlotGap = 50,        -- Gap between first 5 and last 2 slots
    itemSlotCount = 7,

    -- Selection panels (Zahlen / Kombinationen)
    selectionPanelY = 180,
    selectionPanelHeight = 200,
    selectionPanelGap = 30,  -- Gap between Zahlen and Kombinationen panels
    selectionSlotSize = 100,
    selectionSlotSpacing = 16,

    -- Dice home area (below selection panels)
    diceHomeY = 480,
    diceHomeHeight = 200,
    diceSize = 100,
    diceSpacing = 40,

    -- CTA buttons (bottom center)
    ctaY = 780,
    ctaWidth = 280,
    ctaHeight = 100,
    ctaSpacing = 60,

    -- Deprecated: keeping for backwards compatibility during transition
    heldTrayY = 380,
    heldTrayHeight = 160,
    heldSlotSize = 120,
    heldSlotSpacing = 20,
    heldSlotCount = 5,
    looseDiceY = 580,
    looseDiceHeight = 300,
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
    self.fonts.giant = love.graphics.newFont(fontPath, 80)   -- for goal number

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

    -- Load dice face images
    for i = 1, 6 do
        local path = "assets/icons/hands/" .. i .. "die.png"
        self.images.diceFaces[i] = love.graphics.newImage(path)
        self.images.diceFaces[i]:setFilter("nearest", "nearest")
    end
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

-- Helper function to draw text with shadow
function Theme:drawTextWithShadow(text, x, y, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    shadowOffset = shadowOffset or 2

    love.graphics.setFont(font)

    -- Draw shadow
    love.graphics.setColor(self.colors.textShadow)
    love.graphics.print(text, math.floor(x + shadowOffset), math.floor(y + shadowOffset))

    -- Draw main text
    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(x), math.floor(y))
end

-- Helper function to draw text centered with shadow
function Theme:drawTextCenteredWithShadow(text, x, y, width, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    shadowOffset = shadowOffset or 2

    love.graphics.setFont(font)

    local textWidth = font:getWidth(text)
    local textX = x + (width - textWidth) / 2

    -- Draw shadow
    love.graphics.setColor(self.colors.textShadow)
    love.graphics.print(text, math.floor(textX + shadowOffset), math.floor(y + shadowOffset))

    -- Draw main text
    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(textX), math.floor(y))
end

-- Helper function to draw text right-aligned with shadow
function Theme:drawTextRightWithShadow(text, x, y, width, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    shadowOffset = shadowOffset or 2

    love.graphics.setFont(font)

    local textWidth = font:getWidth(text)
    local textX = x + width - textWidth

    -- Draw shadow
    love.graphics.setColor(self.colors.textShadow)
    love.graphics.print(text, math.floor(textX + shadowOffset), math.floor(y + shadowOffset))

    -- Draw main text
    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(textX), math.floor(y))
end

return Theme
