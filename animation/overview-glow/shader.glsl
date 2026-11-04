// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    vec4 c = umbriel_sample(uv);
    float glow = 0.10 * sin(3.14159265 * t);
    return vec4(c.rgb + vec3(0.3, 0.6, 1.0) * glow * c.a, c.a);
}
