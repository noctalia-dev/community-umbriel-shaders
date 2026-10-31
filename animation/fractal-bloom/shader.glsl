// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original procedural artwork.

const float INTENSITY = 0.85; // 0..1; glowing dissolve edge.
const float PATTERN_SCALE = 180.0; // Logical pixels per fractal unit.
const float EDGE_WIDTH = 0.10; // Threshold-space glow width; 0.03..0.2.

// Twelve mirrored wedges give the fractal a true kaleidoscope symmetry.
vec2 psyche_fold(vec2 p, float rotation) {
    float radius = length(p);
    float angle = radius > 0.00001 ? atan(p.y, p.x) : 0.0;
    float wedge = 1.0471975512;
    angle = abs(mod(angle + rotation + wedge * 0.5, wedge) - wedge * 0.5);
    return radius * vec2(cos(angle), sin(angle));
}

// Six bounded inversion/fold iterations form nested branching orbit traps.
// Keep this helper identical across the Psychedelic pack; no texture or history.
vec2 psyche_fractal(vec2 p, float phase, float pixel) {
    float c = cos(phase), s = sin(phase);
    mat2 turn = mat2(c, -s, s, c);
    vec2 z = p;
    float trap = 1.0;
    float field = 0.0;
    float weight = 0.5;
    for (int i = 0; i < 6; ++i) {
        z = turn * abs(z);
        z = z / clamp(dot(z, z), 0.24, 2.4) - vec2(0.92, 0.64);
        float orbit = abs(length(z) - 0.72);
        trap = min(trap, orbit);
        field += weight * exp(-3.0 * orbit);
        weight *= 0.5;
    }
    float line = 1.0 - smoothstep(0.012, 0.038 + min(pixel, 0.035), trap);
    return vec2(line, clamp(field, 0.0, 1.0));
}
vec3 psyche_colour(float t) {
    return 0.52 + 0.48 * cos(6.28318530718 * (t + vec3(0.0, 0.33, 0.67)));
}

vec4 animation(vec2 uv) {
    float progress = umbriel_clamped_progress;
    float visibility = umbriel_direction > 0.0 ? progress : 1.0 - progress;
    if (visibility <= 0.0) return vec4(0.0);
    vec4 source = umbriel_sample(uv);
    if (visibility >= 1.0) return source;
    vec2 size = max(umbriel_size, vec2(1.0));
    vec2 point = (uv - 0.5) * size;
    float scale = max(PATTERN_SCALE, 40.0);
    // Seed rotates the whole mandala without breaking its mirror symmetry.
    float rotation = umbriel_random_seed.x * 1.0471975512;
    vec2 f = psyche_fractal(psyche_fold(point / scale, rotation), 0.52,
        1.0 / (scale * max(umbriel_scale, 0.01)));
    float radial = clamp(length(point) / max(length(size * 0.5), 1.0), 0.0, 1.0);
    float threshold = 0.12 + 0.76 * (0.56 * radial + 0.44 * f.y);
    float aa = 0.022;
    float mask = smoothstep(threshold - aa, threshold + aa, visibility);
    float edgeWidth = clamp(EDGE_WIDTH, 0.03, 0.2);
    float edge = 1.0 - smoothstep(0.0, edgeWidth, abs(threshold - visibility));
    float envelope = smoothstep(0.0, 0.12, visibility)
        * (1.0 - smoothstep(0.88, 1.0, visibility));
    vec2 ornament = psyche_fractal(psyche_fold(point / scale, rotation + visibility * 0.4),
        0.52 + 0.06 * sin(visibility * 3.14159265),
        1.0 / (scale * max(umbriel_scale, 0.01)));
    vec3 colour = psyche_colour(ornament.y * 1.8 + radial * 0.35);
    colour = mix(colour, vec3(0.94, 1.0, 0.97), ornament.x * 0.6);
    float ink = edge * envelope * clamp(INTENSITY, 0.0, 1.0);
    return vec4(mix(source.rgb, colour * source.a, ink), source.a) * mask;
}

