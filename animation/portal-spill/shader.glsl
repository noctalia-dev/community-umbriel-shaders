// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float EDGE_WIDTH = 0.12;
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    float v = umbriel_direction > 0.0 ? t : 1.0 - t;
    if (v >= 1.0) return umbriel_sample(uv);
    if (v <= 0.0) return vec4(0.0);
    vec2 p = (uv - 0.5) * umbriel_size / max(min(umbriel_size.x, umbriel_size.y), 1.0);
    float radius = length(p);
    float angle = atan(p.y, p.x);
    float field = clamp(radius / max(length(umbriel_size / max(min(umbriel_size.x, umbriel_size.y), 1.0)) * 0.5, 0.001)
        + 0.12 * sin(angle * 5.0 - radius * 12.0 + v * 10.0), 0.0, 1.0);
    float front = v * (1.0 + 2.0 * EDGE_WIDTH) - EDGE_WIDTH;
    float mask = smoothstep(field - EDGE_WIDTH, field + EDGE_WIDTH, front);
    float edge = 4.0 * mask * (1.0-mask);
    vec4 c = umbriel_sample(uv);
    return vec4(c.rgb * mask + vec3(0.8, 0.08, 1.0) * c.a * edge * 1.4, c.a * mask);
}
