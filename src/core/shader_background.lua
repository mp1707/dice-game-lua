-- Shader Background Manager
-- Handles the animated Balatro-style background shader

local ShaderBackground = {
    shader = nil,
    time = 0,
    enabled = true,
}

-- Simple test shader first to verify shader pipeline works
local shaderCode = [[
extern float time;
extern vec2 screen;

// Simple noise function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// Swirl distortion
vec2 swirl(vec2 uv, vec2 center, float radius, float angle) {
    vec2 d = uv - center;
    float len = length(d);
    float factor = smoothstep(radius, 0.0, len);
    float a = factor * angle;
    float s = sin(a);
    float c = cos(a);
    d = vec2(c * d.x - s * d.y, s * d.x + c * d.y);
    return center + d;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = screen_coords / screen;
    vec2 centered = uv - 0.5;

    // Use oscillating swirl angles instead of accumulating - prevents infinite curl
    float slowTime = time * 0.08;
    float swirlAngle1 = sin(slowTime * 0.5) * 0.8;  // Oscillate between -0.8 and 0.8 radians
    float swirlAngle2 = sin(slowTime * 0.3 + 1.0) * 0.5;
    float swirlAngle3 = sin(slowTime * 0.4 + 2.0) * 0.6;

    vec2 swirled = swirl(centered, vec2(0.0), 1.5, swirlAngle1);
    swirled = swirl(swirled, vec2(-0.3, 0.2), 0.6, -swirlAngle2);
    swirled = swirl(swirled, vec2(0.3, -0.2), 0.6, swirlAngle3);

    // Noise still flows over time for nice movement
    float n1 = fbm(swirled * 3.0 + vec2(slowTime * 0.3, slowTime * 0.15));
    float n2 = fbm(swirled * 2.0 - vec2(slowTime * 0.2, -slowTime * 0.3));
    float n3 = fbm(swirled * 4.0 + vec2(-slowTime * 0.15, slowTime * 0.4));

    float pattern = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

    float vignette = 1.0 - length(centered) * 0.8;
    vignette = clamp(vignette, 0.0, 1.0);

    // Theme colors
    vec3 bgColor = vec3(0.165, 0.133, 0.259);
    vec3 surfaceColor = vec3(0.290, 0.239, 0.478);
    vec3 cyanColor = vec3(0.302, 0.933, 0.918);
    vec3 coralColor = vec3(1.0, 0.353, 0.478);

    vec3 col;
    float t = pattern * 2.0;

    if (t < 0.4) {
        col = mix(bgColor, surfaceColor, t / 0.4);
    } else if (t < 0.7) {
        col = mix(surfaceColor, bgColor * 1.2, (t - 0.4) / 0.3);
    } else if (t < 0.85) {
        float cyanAmount = (t - 0.7) / 0.15;
        col = mix(bgColor * 1.2, mix(surfaceColor, cyanColor, 0.15), cyanAmount);
    } else {
        float coralAmount = (t - 0.85) / 0.15;
        col = mix(mix(surfaceColor, cyanColor, 0.15), mix(surfaceColor, coralColor, 0.1), coralAmount);
    }

    // Slightly dimmed for better UI visibility (was 0.7 + vignette * 0.3)
    col *= (0.55 + vignette * 0.3);

    float pulse = sin(time * 0.5) * 0.02 + 1.0;
    col *= pulse;

    return vec4(col, 1.0);
}
]]

function ShaderBackground.init()
    -- Try to compile shader
    local success, result = pcall(function()
        return love.graphics.newShader(shaderCode)
    end)

    if success then
        ShaderBackground.shader = result
    else
        -- Shader failed, disable
        ShaderBackground.enabled = false
        -- Show error on screen (will be visible as love.errorhandler fallback)
        error("Shader compilation failed: " .. tostring(result))
    end
end

function ShaderBackground.update(dt)
    if not ShaderBackground.enabled then return end
    ShaderBackground.time = ShaderBackground.time + dt
end

function ShaderBackground.draw(width, height)
    if not ShaderBackground.enabled or not ShaderBackground.shader then
        return false
    end

    -- Send uniforms to shader
    ShaderBackground.shader:send("time", ShaderBackground.time)
    ShaderBackground.shader:send("screen", { width, height })

    -- Draw fullscreen quad with shader
    love.graphics.setShader(ShaderBackground.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setShader()

    return true
end

function ShaderBackground.toggle()
    ShaderBackground.enabled = not ShaderBackground.enabled
end

function ShaderBackground.isEnabled()
    return ShaderBackground.enabled
end

return ShaderBackground
