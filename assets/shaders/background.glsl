// Balatro-style animated background shader
// A psychedelic swirling pattern with the game's purple/cyan color palette

#define PI 3.14159265359

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

// Fractal Brownian Motion for more organic noise
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
    
    // Center the UV coordinates
    vec2 centered = uv - 0.5;
    
    // Apply swirling distortion (Balatro-style)
    float slowTime = time * 0.15;
    vec2 swirled = swirl(centered, vec2(0.0), 1.5, slowTime * 0.5);
    
    // Add additional swirl centers for complexity
    swirled = swirl(swirled, vec2(-0.3, 0.2), 0.6, -slowTime * 0.3);
    swirled = swirl(swirled, vec2(0.3, -0.2), 0.6, slowTime * 0.4);
    
    // Create flowing noise patterns
    float n1 = fbm(swirled * 3.0 + vec2(slowTime * 0.2, slowTime * 0.1));
    float n2 = fbm(swirled * 2.0 - vec2(slowTime * 0.15, -slowTime * 0.25));
    float n3 = fbm(swirled * 4.0 + vec2(-slowTime * 0.1, slowTime * 0.3));
    
    // Combine noise layers
    float pattern = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
    
    // Create radial gradient for vignette
    float vignette = 1.0 - length(centered) * 0.8;
    vignette = clamp(vignette, 0.0, 1.0);
    
    // Theme colors (from theme.lua)
    vec3 bgColor = vec3(0.165, 0.133, 0.259);      // #2A2242 - dark purple
    vec3 surfaceColor = vec3(0.290, 0.239, 0.478); // #4A3D7A - mid purple  
    vec3 cyanColor = vec3(0.302, 0.933, 0.918);    // #4DEEEA - cyan accent
    vec3 coralColor = vec3(1.0, 0.353, 0.478);     // #FF5A7A - coral accent
    
    // Create color bands based on pattern
    vec3 col;
    float t = pattern * 2.0;
    
    if (t < 0.4) {
        col = mix(bgColor, surfaceColor, t / 0.4);
    } else if (t < 0.7) {
        col = mix(surfaceColor, bgColor * 1.2, (t - 0.4) / 0.3);
    } else if (t < 0.85) {
        // Subtle cyan streaks
        float cyanAmount = (t - 0.7) / 0.15;
        col = mix(bgColor * 1.2, mix(surfaceColor, cyanColor, 0.15), cyanAmount);
    } else {
        // Rare coral highlights
        float coralAmount = (t - 0.85) / 0.15;
        col = mix(mix(surfaceColor, cyanColor, 0.15), mix(surfaceColor, coralColor, 0.1), coralAmount);
    }
    
    // Apply vignette
    col *= (0.7 + vignette * 0.3);
    
    // Subtle pulsing glow
    float pulse = sin(time * 0.5) * 0.02 + 1.0;
    col *= pulse;
    
    return vec4(col, 1.0);
}
