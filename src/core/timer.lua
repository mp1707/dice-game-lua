-- Simple timer utility for animations and delays

local Timer = {}
Timer.__index = Timer

function Timer.new()
    local self = setmetatable({}, Timer)
    self.timers = {}
    return self
end

-- Schedule a callback after duration seconds
function Timer:after(duration, callback)
    table.insert(self.timers, {
        remaining = duration,
        callback = callback,
        type = "after",
    })
end

-- Schedule a callback every interval seconds
function Timer:every(interval, callback, times)
    table.insert(self.timers, {
        remaining = interval,
        interval = interval,
        callback = callback,
        times = times or math.huge,
        type = "every",
    })
end

-- Create a tween (simple linear interpolation)
function Timer:tween(duration, subject, target, callback)
    local start = {}
    for k, v in pairs(target) do
        start[k] = subject[k]
    end

    table.insert(self.timers, {
        remaining = duration,
        duration = duration,
        subject = subject,
        target = target,
        start = start,
        callback = callback or function() end,
        type = "tween",
    })
end

function Timer:update(dt)
    for i = #self.timers, 1, -1 do
        local t = self.timers[i]
        t.remaining = t.remaining - dt

        if t.type == "tween" then
            -- Update tween progress
            local progress = 1 - math.max(0, t.remaining / t.duration)
            for k, v in pairs(t.target) do
                t.subject[k] = t.start[k] + (v - t.start[k]) * progress
            end
        end

        if t.remaining <= 0 then
            if t.type == "after" then
                t.callback()
                table.remove(self.timers, i)
            elseif t.type == "every" then
                t.callback()
                t.times = t.times - 1
                if t.times <= 0 then
                    table.remove(self.timers, i)
                else
                    t.remaining = t.interval
                end
            elseif t.type == "tween" then
                -- Ensure final values are exact
                for k, v in pairs(t.target) do
                    t.subject[k] = v
                end
                t.callback()
                table.remove(self.timers, i)
            end
        end
    end
end

function Timer:clear()
    self.timers = {}
end

return Timer
