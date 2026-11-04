// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float FOLD_COUNT = 8.0;
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    float v = umbriel_direction > 0.0 ? t : 1.0 - t;
    if (v >= 1.0) return umbriel_sample(uv);
    if (v <= 0.0) return vec4(0.0);
    float band = floor(uv.y * FOLD_COUNT);
    float local = fract(uv.y * FOLD_COUNT);
    float open = max(v, 0.001);
    float mapped = (local - 0.5) / open + 0.5;
    float mask = step(0.0, mapped) * step(mapped, 1.0);
    vec4 c = umbriel_sample(vec2(uv.x, (band + mapped) / FOLD_COUNT));
    float edge = exp(-min(mapped, 1.0-mapped) * 25.0) * (1.0-v);
    vec3 rgb = c.rgb * (0.45 + 0.55*v) + vec3(1.0, 0.3, 0.02) * edge * c.a;
    return vec4(rgb, c.a) * mask * smoothstep(0.0, 0.06, v);
}
