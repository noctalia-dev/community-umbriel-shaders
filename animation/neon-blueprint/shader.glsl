// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float BLUEPRINT_STRENGTH = 0.95;
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    if (t <= 0.0 || t >= 1.0) return umbriel_sample(uv);
    float pulse = sin(3.14159265 * t);
    vec4 c = umbriel_sample(uv);
    float grey = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec2 grid = abs(fract(uv * umbriel_size / 28.0) - 0.5);
    float lines = step(0.46, max(grid.x, grid.y));
    float scan = step(0.55, sin(uv.y * umbriel_size.y * 0.12 - t * 30.0));
    vec3 blue = vec3(0.02, 0.85, 1.0) * (grey * 0.6 + c.a * (0.2 + 0.5 * lines + 0.22 * scan));
    return vec4(mix(c.rgb, blue, BLUEPRINT_STRENGTH * pulse), c.a);
}
