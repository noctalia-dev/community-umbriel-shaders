// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float DISTORTION_PX = 38.0;
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    if (t <= 0.0 || t >= 1.0) return umbriel_sample(uv);
    float pulse = sin(3.14159265 * t);
    vec2 size = max(umbriel_size, vec2(1.0));
    vec2 p = (uv - 0.5) * size;
    float r = length(p);
    vec2 direction = p / max(r, 1.0);
    float wave = sin(r * 0.065 - t * 24.0) * pulse;
    vec2 d = direction * DISTORTION_PX * wave / size;
    vec4 c = umbriel_sample(uv + d);
    vec4 red = umbriel_sample(uv + d * 1.8);
    vec4 blue = umbriel_sample(uv - d * 0.6);
    // Keep all channels premultiplied by the central sample's alpha.
    vec3 rgb = vec3(red.r / max(red.a, 0.0001), c.g / max(c.a, 0.0001), blue.b / max(blue.a, 0.0001));
    return vec4(rgb * c.a, c.a);
}
