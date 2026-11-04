// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    float visible = umbriel_direction > 0.0 ? t : 1.0 - t;
    return umbriel_sample(uv) * visible;
}
