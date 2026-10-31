// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original shader.
// Pumpkin fire ignites at bottom-left and burns diagonally toward top-right.
const float INTENSITY = 1.0;
const float FLAME_DEPTH = 48.0; // logical pixels
const vec3 ORANGE = vec3(1.0, 0.27, 0.025);
const vec3 GOLD = vec3(1.0, 0.85, 0.25);
const vec3 GREEN = vec3(0.16, 0.88, 0.39);
float hash21(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float noise21(vec2 p) {
    vec2 c = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(c), hash21(c + vec2(1.0, 0.0)), f.x),
               mix(hash21(c + vec2(0.0, 1.0)), hash21(c + vec2(1.0)), f.x), f.y);
}

vec4 animation(vec2 uv) {
    float progress = clamp(umbriel_linear_progress, 0.0, 1.0);
    float v = umbriel_direction > 0.0 ? progress : 1.0 - progress;
    vec4 source = umbriel_sample(uv);
    if (v <= 0.0) return vec4(0.0);
    if (v >= 1.0) return source;
    vec2 size = max(umbriel_size, vec2(1.0));
    vec2 p = uv * size;
    vec2 origin = vec2(-0.08 * size.x, 1.08 * size.y);
    float maximum = length(vec2(1.08) * size);
    float radius = mix(-FLAME_DEPTH, maximum + FLAME_DEPTH * 1.5, v);
    float t = v * 6.0;
    float n = noise21(p * vec2(0.038, 0.015) + vec2(0.0, t * 2.8));
    float fine = noise21(p * 0.09 + vec2(t * 0.6, t * 4.5));
    float tongues = FLAME_DEPTH * (0.75 * n + 0.25 * fine - 0.45);
    float distance = length(p - origin) - radius;
    float front = distance - tongues;
    float reveal = 1.0 - smoothstep(-3.0, 3.0, front);
    float envelope = smoothstep(0.0, 0.035, v) * (1.0 - smoothstep(0.88, 1.0, v));
    float flame = exp(-pow((front - 4.0) / (FLAME_DEPTH * 0.42), 2.0));
    float core = exp(-pow(front / 5.5, 2.0));
    float wisps = flame * (0.55 + 0.45 * fine);
    vec3 colour = mix(ORANGE * 0.65, ORANGE, n);
    colour = mix(colour, GOLD, core);
    float witch = smoothstep(0.76, 0.95, noise21(p * 0.027 + vec2(t, 4.2)));
    colour = mix(colour, GREEN, witch * (1.0 - core) * 0.8);
    float sparks = 0.0;
    // Embers drift back into the newly revealed portion of the window.
    for (int i = 0; i < 14; ++i) {
        float fi = float(i);
        float age = fract(v * 3.0 + fi * 0.618);
        float angle = -1.55 + hash21(vec2(fi, 9.0)) * 1.5;
        vec2 pos = origin + vec2(cos(angle), sin(angle)) * (radius - age * 90.0);
        pos += vec2(sin(fi + age * 7.0) * 12.0, -age * 38.0);
        vec2 q = p - pos;
        sparks = max(sparks, exp(-dot(q, q) / 5.0) * sin(age * 3.14159265));
    }
    float paint = clamp((wisps + core * 0.35 + sparks) * envelope * INTENSITY, 0.0, 1.0);
    float coverage = reveal + (1.0 - reveal) * paint;
    vec3 rgb = source.rgb * reveal * (1.0 - paint) + mix(colour, GOLD, sparks) * paint * source.a;
    return vec4(rgb, coverage * source.a);
}
