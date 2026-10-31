// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original shader.
const float INTENSITY = 0.68; // 0..1
const float FOG_HEIGHT = 0.32; // output height fraction, use 0.15..0.45

float fog_hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float fog_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    // Hash each shared lattice coordinate identically to avoid cell seams.
    vec4 h = vec4(fog_hash(cell), fog_hash(cell + vec2(1.0, 0.0)),
                  fog_hash(cell + vec2(0.0, 1.0)), fog_hash(cell + vec2(1.0)));
    return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

vec4 screen(vec2 uv) {
    vec4 source = umbriel_sample(uv);
    float altitude = 1.0 - uv.y;
    if (altitude >= FOG_HEIGHT) return source;
    vec2 p = uv * umbriel_size / 170.0;
    float t = umbriel_time * 0.24;
    float warp = fog_noise(p * 0.7 + vec2(t, -t));
    float n = fog_noise(p * vec2(1.0, 2.3) + vec2(-t, warp * 2.8 + t * 0.3));
    float detail = fog_noise(p * 2.8 + vec2(t * 1.5, n));
    float bank = 1.0 - smoothstep(FOG_HEIGHT * (0.15 + 0.50 * n), FOG_HEIGHT, altitude);
    float opacity = INTENSITY * bank * (0.35 + 0.65 * smoothstep(0.2, 0.8, n)) * (0.65 + 0.35 * detail);
    vec3 purple = mix(vec3(0.30, 0.20, 0.43), vec3(0.73, 0.61, 0.86), n);
    return vec4(mix(source.rgb, purple * source.a, opacity), source.a);
}
