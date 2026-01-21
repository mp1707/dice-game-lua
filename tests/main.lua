
package.path = package.path .. ";../?.lua"

function love.load()
    print("Running filter tests...")
    
    local Scoring = require("src.game.scoring")
    
    -- Mock hands needed for getScoringDiceForHand? 
    -- Actually getScoringDiceForHand calls Hands:get(handId) internally via Hands requirement?
    -- No, only Scoring.calculateScore and getBreakdown call Hands:get.
    -- getScoringDiceForHand only uses upperFaceMap and simple logic.
    -- WAIT: line 140 `local handDef = Hands:get(handId)` is in calculateScore.
    -- `getScoringDiceForHand` is generic.
    -- Ah, line 315 `Scoring.isUpperSectionHand(handId)` uses `upperFaceMap` which is local.
    
    -- Since Hands is required at top of scoring.lua, we need to mock it or allow it to load.
    -- Hands requires specific file structure.
    -- Let's just mock package.loaded["src.game.hands"] again to be safe.
    
    package.loaded["src.game.hands"] = {
        get = function(self, id) return {} end
    }

    local chunk = love.filesystem.load("test_filter.lua")
    if chunk then
        chunk()
    else
        print("Could not load test_filter.lua")
    end
    
    love.event.quit()
end
