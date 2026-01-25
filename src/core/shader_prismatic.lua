-- Prismatic Shader
-- Creates a rainbow/holographic/polychrome effect for prismatic dice
-- Similar to Balatro's polychrome card effect

local ShaderPrismatic = {
    shader = nil,
    time = 0,
    enabled = true,
}

-- GLSL shader code for prismatic/holographic effect
local shaderCode = [[
extern float time;

// Rainbow color function - generates smooth rainbow colors
vec3 rainbow(float t) {
    // Use phase-shifted cosines to create smooth RGB rainbow
    return 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(tex, texture_coords);

    // Skip fully transparent pixels
    if (pixel.a < 0.01) {
        return pixel * color;
    }

    // Create shifting rainbow based on position and time
    // Diagonal sweep for more dynamic effect
    float shift = texture_coords.x * 0.5 + texture_coords.y * 0.5 + time * 0.8;

    // Add some wave distortion for more organic feel
    float wave = sin(texture_coords.x * 8.0 + time * 2.0) * 0.05;
    wave += sin(texture_coords.y * 6.0 + time * 1.5) * 0.05;
    shift += wave;

    // Generate rainbow color
    vec3 holo = rainbow(shift);

    // Calculate luminance of original pixel to preserve structure
    float luma = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));

    // Blend rainbow with original - preserve structure, add color
    // Higher blend for brighter areas, lower for darker areas
    float blendAmount = 0.35 + luma * 0.15;
    vec3 finalColor = mix(pixel.rgb, pixel.rgb * holo * 1.5, blendAmount);

    // Add subtle sparkle/shimmer effect
    float sparkle = sin(time * 12.0 + texture_coords.x * 30.0) *
                    sin(time * 10.0 + texture_coords.y * 25.0);
    sparkle = max(0.0, sparkle) * 0.15;
    finalColor += sparkle * holo;

    // Slight brightness boost to make it stand out
    finalColor *= 1.1;

    return vec4(finalColor, pixel.a) * color;
}
]]

function ShaderPrismatic.init()
    -- Try to compile shader
    local success, result = pcall(function()
        return love.graphics.newShader(shaderCode)
    end)

    if success then
        ShaderPrismatic.shader = result
    else
        -- Shader failed, disable
        ShaderPrismatic.enabled = false
        print("Prismatic shader compilation failed: " .. tostring(result))
    end
end

function ShaderPrismatic.update(dt)
    if not ShaderPrismatic.enabled then return end
    ShaderPrismatic.time = ShaderPrismatic.time + dt
end

-- Apply the shader (call before drawing)
function ShaderPrismatic.apply()
    if not ShaderPrismatic.enabled or not ShaderPrismatic.shader then
        return false
    end

    -- Send uniforms to shader
    ShaderPrismatic.shader:send("time", ShaderPrismatic.time)

    -- Set the shader
    love.graphics.setShader(ShaderPrismatic.shader)
    return true
end

-- Clear the shader (call after drawing)
function ShaderPrismatic.clear()
    love.graphics.setShader()
end

function ShaderPrismatic.toggle()
    ShaderPrismatic.enabled = not ShaderPrismatic.enabled
end

function ShaderPrismatic.isEnabled()
    return ShaderPrismatic.enabled
end

-- Get the shader directly (for manual control)
function ShaderPrismatic.getShader()
    return ShaderPrismatic.shader
end

return ShaderPrismatic
