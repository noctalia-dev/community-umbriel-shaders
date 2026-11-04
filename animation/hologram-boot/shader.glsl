// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float STRIP_HEIGHT_PX = 12.0;
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    float v = umbriel_direction > 0.0 ? t : 1.0 - t;
    if (v >= 1.0) return umbriel_sample(uv);
    if (v <= 0.0) return vec4(0.0);
    float band = floor(uv.y * umbriel_size.y / STRIP_HEIGHT_PX);
    float delay = fract(band * 0.61803399) * 0.55;
    float on = smoothstep(delay, delay + 0.45, v);
    float pulse = sin(3.14159265 * v);
    vec2 q = uv + vec2(sin(band * 7.0 + floor(v * 16.0)) * 32.0 * pulse / max(umbriel_size.x, 1.0), 0.0);
    vec4 c = umbriel_sample(q);
    float grey = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 holo = vec3(0.02, 0.9, 1.0) * (grey + c.a * 0.65);
    return vec4(mix(c.rgb, holo, pulse), c.a) * on;
}
