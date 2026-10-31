// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Noctalia
// Full-scene API adaptation by Barrulus.
uniform vec2 umbriel_workspace_axis;

float workspace_sign() {
    return umbriel_workspace_axis.x + umbriel_workspace_axis.y < 0.0 ? -1.0 : 1.0;
}

vec4 animation(vec2 uv) {
    float p = umbriel_clamped_progress;
    if (p <= 0.0) return umbriel_sample(uv);
    if (p >= 1.0) return umbriel_sample_incoming(uv);
    float coordinate = dot(uv, abs(umbriel_workspace_axis));
    if (workspace_sign() < 0.0) coordinate = 1.0 - coordinate;
    return mix(umbriel_sample(uv), umbriel_sample_incoming(uv), step(coordinate, p));
}
