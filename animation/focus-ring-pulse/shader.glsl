// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
vec4 animation(vec2 uv) {
    vec4 c = umbriel_sample(uv);
    float pulse = 0.25 * sin(3.14159265 * umbriel_clamped_progress);
    return vec4(c.rgb + vec3(0.2, 0.6, 1.0) * pulse * c.a, c.a);
}
