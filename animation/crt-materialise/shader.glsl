// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float SCAN_STRENGTH = 0.45;
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    float v = umbriel_direction > 0.0 ? t : 1.0 - t;
    if (v >= 1.0) return umbriel_sample(uv);
    if (v <= 0.0) return vec4(0.0);
    float height = max(v * v, 0.002);
    vec2 q = vec2(uv.x, (uv.y - 0.5) / height + 0.5);
    vec4 c = umbriel_sample(q);
    float scan = 0.5 + 0.5 * sin(uv.y * umbriel_size.y * 1.7);
    float edge = exp(-abs(abs(uv.y - 0.5) - height * 0.5) * 100.0);
    vec3 rgb = c.rgb * (1.0 - SCAN_STRENGTH * (1.0-v) * scan);
    rgb += vec3(0.3, 1.0, 0.8) * c.a * (1.0-v) * (2.0 * edge + 0.6);
    return vec4(rgb, c.a) * smoothstep(0.0, 0.08, v);
}
