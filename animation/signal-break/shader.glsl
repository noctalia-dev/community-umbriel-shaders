// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float BREAK_PX = 48.0;
float bandNoise(float x) { return fract(sin(x * 127.1 + umbriel_random_seed.x * 73.0) * 43758.5453); }
vec4 animation(vec2 uv) {
    // Distort only the window losing focus; the incoming window stays readable.
    if (umbriel_direction >= 0.0) return umbriel_sample(uv);
    float t = umbriel_clamped_progress;
    if (t <= 0.0 || t >= 1.0) return umbriel_sample(uv);
    float pulse = sin(3.14159265 * t);
    vec2 size = max(umbriel_size, vec2(1.0));
    float cell = 1.0 + 18.0 * pulse;
    vec2 q = mix(uv, (floor(uv * size / cell) + 0.5) * cell / size, pulse);
    float band = floor(uv.y * size.y / 16.0);
    q.x += (bandNoise(band + floor(t * 12.0)) - 0.5) * BREAK_PX * pulse / size.x;
    vec2 d = vec2(14.0 * pulse / size.x, 0.0);
    vec4 c = umbriel_sample(q), r = umbriel_sample(q + d), b = umbriel_sample(q - d);
    vec3 rgb = vec3(r.r / max(r.a, 0.0001), c.g / max(c.a, 0.0001), b.b / max(b.a, 0.0001));
    return vec4(rgb * c.a, c.a);
}
