// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    float visible = umbriel_direction > 0.0 ? t : 1.0 - t;
    vec2 sampleUv = uv + vec2(0.0, 0.035 * (1.0 - visible));
    float inside = step(0.0, sampleUv.y) * step(sampleUv.y, 1.0);
    return umbriel_sample(sampleUv) * visible * inside;
}
