-- State Machine for managing game states
-- States are lazily instantiated functions

local StateMachine = {}
StateMachine.__index = StateMachine

-- Empty state with no-op methods
local emptyState = {
    enter = function() end,
    exit = function() end,
    update = function() end,
    draw = function() end,
    mousepressed = function() end,
    mousereleased = function() end,
    mousemoved = function() end,
    keypressed = function() end,
}

function StateMachine.new(states)
    local self = setmetatable({}, StateMachine)
    self.states = states or {}
    self.current = emptyState
    self.currentName = nil
    return self
end

function StateMachine:change(stateName, enterParams)
    assert(self.states[stateName], "State does not exist: " .. tostring(stateName))

    -- Exit current state
    self.current:exit()

    -- Create new state instance (lazy instantiation)
    self.current = self.states[stateName]()
    self.currentName = stateName

    -- Enter new state with params
    self.current:enter(enterParams or {})
end

function StateMachine:update(dt)
    self.current:update(dt)
end

function StateMachine:draw()
    self.current:draw()
end

function StateMachine:mousepressed(x, y, button)
    if self.current.mousepressed then
        self.current:mousepressed(x, y, button)
    end
end

function StateMachine:mousereleased(x, y, button)
    if self.current.mousereleased then
        self.current:mousereleased(x, y, button)
    end
end

function StateMachine:mousemoved(x, y)
    if self.current.mousemoved then
        self.current:mousemoved(x, y)
    end
end

function StateMachine:keypressed(key)
    if self.current.keypressed then
        self.current:keypressed(key)
    end
end

return StateMachine
