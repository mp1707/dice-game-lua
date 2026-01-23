-- Hot Reload Module
-- Watches for file changes and reloads code while preserving game state

local HotReload = {
    enabled = true,
    fileModTimes = {},
    checkInterval = 0.5,
    lastCheck = 0,
    reloadMessage = nil,
    reloadMessageTime = 0,
    -- Callbacks (set by main.lua)
    getState = nil,
    setState = nil,
    onReload = nil,
}

-- Recursively get all Lua files in a directory
local function getLuaFiles(dir, files)
    files = files or {}
    local items = love.filesystem.getDirectoryItems(dir)
    for _, item in ipairs(items) do
        local path = dir .. "/" .. item
        local info = love.filesystem.getInfo(path)
        if info then
            if info.type == "directory" then
                getLuaFiles(path, files)
            elseif item:match("%.lua$") then
                files[path] = info.modtime
            end
        end
    end
    return files
end

-- Check for file changes
local function checkForChanges()
    local currentFiles = getLuaFiles("src")
    local hasChanges = false

    for path, modtime in pairs(currentFiles) do
        if HotReload.fileModTimes[path] ~= modtime then
            hasChanges = true
            break
        end
    end

    HotReload.fileModTimes = currentFiles
    return hasChanges
end

-- Perform hot reload
function HotReload:reload()
    print("Hot reloading...")

    -- Save game state before reload
    local savedState = nil
    if self.getState then
        savedState = self.getState()
    end

    -- Clear module cache
    for name, _ in pairs(package.loaded) do
        if name:match("^src%.") then
            package.loaded[name] = nil
        end
    end

    -- Let main.lua handle the actual reload
    if self.onReload then
        self.onReload()
    end

    -- Restore game state after reload
    if savedState and self.setState then
        self.setState(savedState)
    end

    self.reloadMessage = "Reloaded!"
    self.reloadMessageTime = love.timer.getTime()
end

-- Update (call from love.update)
function HotReload:update(dt)
    if not self.enabled then return end

    self.lastCheck = self.lastCheck + dt
    if self.lastCheck >= self.checkInterval then
        self.lastCheck = 0
        if checkForChanges() then
            self:reload()
        end
    end
end

-- Draw notification (call from love.draw)
function HotReload:draw()
    if not self.reloadMessage then return end

    local elapsed = love.timer.getTime() - self.reloadMessageTime
    if elapsed < 2 then
        local alpha = elapsed < 1.5 and 1 or (2 - elapsed) * 2
        love.graphics.setColor(0.2, 0.8, 0.3, alpha)
        love.graphics.print(self.reloadMessage, 20, love.graphics.getHeight() - 40)
        love.graphics.setColor(1, 1, 1, 1)
    else
        self.reloadMessage = nil
    end
end

-- Initialize mod times on load to prevent immediate reload
HotReload.fileModTimes = getLuaFiles("src")

return HotReload
