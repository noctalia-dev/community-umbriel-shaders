// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float INK_STRENGTH = 0.95;
vec4 animation(vec2 uv) {
    // Ink belongs only to the window losing focus.
    if (umbriel_direction >= 0.0) return umbriel_sample(uv);
    float t = umbriel_clamped_progress;
    if (t <= 0.0 || t >= 1.0) return umbriel_sample(uv);
    float pulse = sin(3.14159265 * t);
    float sweep = smoothstep(-0.2, 0.15, t * 1.6 - (uv.x * 0.65 + uv.y * 0.35));
    float ink = INK_STRENGTH * pulse * sweep;
    vec4 c = umbriel_sample(uv);
    float grey = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    return vec4(mix(c.rgb, vec3(grey * 0.12), ink), c.a);
}
