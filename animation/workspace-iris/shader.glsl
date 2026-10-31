// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Noctalia
// Full-scene API adaptation by Barrulus.
// Adapted from the session workspace-pair shader to the full-scene reveal API.
uniform vec2 umbriel_workspace_axis;

float workspace_sign() {
    return umbriel_workspace_axis.x + umbriel_workspace_axis.y < 0.0 ? -1.0 : 1.0;
}

// The destination opens from the center; its coordinates remain unchanged.
vec4 animation(vec2 uv) {
    float p = umbriel_clamped_progress;
    if (p <= 0.0) return umbriel_sample(uv);
    if (p >= 1.0) return umbriel_sample_incoming(uv);
    vec2 centered = uv - vec2(0.5);
    centered.x *= umbriel_size.x / umbriel_size.y;
    float corner = length(vec2(umbriel_size.x / umbriel_size.y, 1.0)) * 0.5;
    float radius = p * corner;
    return length(centered) < radius ? umbriel_sample_incoming(uv) : umbriel_sample(uv);
}
