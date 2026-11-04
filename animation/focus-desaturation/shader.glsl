// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
vec4 animation(vec2 uv) {
    vec4 c = umbriel_sample(uv);
    float pulse = 0.30 * sin(3.14159265 * umbriel_clamped_progress);
    float grey = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    return vec4(mix(c.rgb, vec3(grey), pulse), c.a);
}
