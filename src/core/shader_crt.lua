-- Shader CRT Manager
-- Handles the CRT post-processing effect

local ShaderCRT = {
    shader = nil,
    time = 0,
    enabled = true,
}

local shaderCode = [[
extern vec2 screenSize;
extern float time;

// CRT Effect for Love2D
// Based on common CRT shader techniques
// Features: Curvature, Chromatic Aberration, Scanlines, Vignette

// Distortion factor
const vec2 curvature = vec2(3.0, 3.0);

vec2 curve(vec2 uv) {
    uv = (uv - 0.5) * 2.0;
    // minimal curvature
    uv.x *= 1.0 + pow((abs(uv.y) / 9.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 8.0), 2.0);
    uv = (uv / 2.0) + 0.5;
    return uv;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    // 1. Curvature / Distortion
    vec2 uv = curve(texture_coords);

    // Discard outside
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    // 2. Chromatic Aberration
    // Very subtle, just a hint of fringe at the far edges
    float dist = distance(uv, vec2(0.5));
    // Reduced from 0.015 to 0.002
    vec2 offset = (uv - 0.5) * (dist * 0.002);

    float r = Texel(tex, uv - offset).r;
    float g = Texel(tex, uv).g;
    float b = Texel(tex, uv + offset).b;

    vec3 col = vec3(r, g, b);

    // 3. Scanlines
    // Make them relative to the texture height (screenSize.y)
    // Using a sine wave
    // Reduced density for thicker, lower-res feel (simulating ~270 lines instead of 540)
    float density = screenSize.y * 0.25;
    // Add subtle drift with time (extremely slow now)
    float scanline = sin((uv.y + time * 0.001) * density * 3.14159 * 2.0) * 0.5 + 0.5;
    // scanline varies from 0 to 1
    // 20% less visible from previous step: 0.88 to 1.0 (12% varying darkness)
    scanline = 0.88 + 0.12 * scanline;

    col *= scanline;

    // 4. Vignette
    // Darken corners - reduced strength
    uv = uv * (1.0 - uv.yx);
    float vig = uv.x * uv.y * 35.0; // was 25.0 (higher multiplier here actually makes the gradient tighter/edge-focused)
    vig = pow(vig, 0.1); // significantly reduced curve (closer to 1.0)

    col *= vig;

    // 5. Glow / Bleed (simplified)
    // For a really cheap bloom, we can't easily sample neighbors efficiently in a single pass without meaningful cost
    // But we can just brighten the center a bit or adjust contrast

    // Contrast boost
    col = col * 1.05;

    return vec4(col, 1.0) * color;
}
]]

function ShaderCRT.init()
    local success, result = pcall(function()
        return love.graphics.newShader(shaderCode)
    end)

    if success then
        ShaderCRT.shader = result
    else
        print("CRT Shader compilation failed: " .. tostring(result))
        ShaderCRT.enabled = false
    end
end

function ShaderCRT.update(dt)
    if not ShaderCRT.enabled then return end
    ShaderCRT.time = ShaderCRT.time + dt
end

function ShaderCRT.sendUniforms(width, height)
    if not ShaderCRT.enabled or not ShaderCRT.shader then return end

    ShaderCRT.shader:send("time", ShaderCRT.time)
    ShaderCRT.shader:send("screenSize", { width, height })
end

function ShaderCRT.isEnabled()
    return ShaderCRT.enabled
end

function ShaderCRT.toggle()
    ShaderCRT.enabled = not ShaderCRT.enabled
end

return ShaderCRT
