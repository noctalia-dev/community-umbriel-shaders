// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float STRIPE_WIDTH_PX = 24.0;
vec4 animation(vec2 uv) {
    // Highlight only the newly focused window.
    if (umbriel_direction <= 0.0) return umbriel_sample(uv);
    float t = umbriel_clamped_progress;
    if (t <= 0.0 || t >= 1.0) return umbriel_sample(uv);
    float pulse = sin(3.14159265 * t);
    vec4 c = umbriel_sample(uv);
    float stripe = step(0.5, fract((uv.x * umbriel_size.x + uv.y * umbriel_size.y) / STRIPE_WIDTH_PX - t * 8.0));
    vec3 hazard = mix(vec3(0.015), vec3(1.0, 0.8, 0.01), stripe) * c.a;
    return vec4(mix(c.rgb, hazard, pulse), c.a);
}
