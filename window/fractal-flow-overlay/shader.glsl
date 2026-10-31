// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original procedural artwork.

const float REACH = 8.0; // Logical pixels per side; fades from a narrow bright core.
const float INTENSITY = 0.90; // 0..1.
const float PATTERN_SCALE = 90.0; // Approximate logical pixels per large fractal fold.
const float ROLL_SPEED = 0.24; // Contour cycles per second; border speed scales this too.

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

float psyche_perimeter(vec2 p, vec2 size, vec4 r) {
    const float quarter = 1.57079632679;
    float top = size.x - r.x - r.y;
    float right_start = top + quarter * r.y;
    float br_start = right_start + size.y - r.y - r.z;
    float bottom_start = br_start + quarter * r.z;
    float bl_start = bottom_start + size.x - r.z - r.w;
    float left_start = bl_start + quarter * r.w;
    float tl_start = left_start + size.y - r.w - r.x;
    if (p.x >= size.x - r.y && p.y <= r.y)
        return top + r.y * atan(max(p.x - size.x + r.y, 0.00001), max(r.y - p.y, 0.00001));
    if (p.x >= size.x - r.z && p.y >= size.y - r.z)
        return br_start + r.z * atan(max(p.y - size.y + r.z, 0.00001), max(p.x - size.x + r.z, 0.00001));
    if (p.x <= r.w && p.y >= size.y - r.w)
        return bl_start + r.w * atan(max(r.w - p.x, 0.00001), max(p.y - size.y + r.w, 0.00001));
    if (p.x <= r.x && p.y <= r.x)
        return tl_start + r.x * atan(max(r.x - p.y, 0.00001), max(r.x - p.x, 0.00001));
    vec4 distances = abs(vec4(p.y, p.x - size.x, p.y - size.y, p.x));
    float nearest = min(min(distances.x, distances.y), min(distances.z, distances.w));
    if (nearest == distances.x) return clamp(p.x - r.x, 0.0, top);
    if (nearest == distances.y) return right_start + clamp(p.y - r.y, 0.0, size.y - r.y - r.z);
    if (nearest == distances.z) return bottom_start + clamp(size.x - r.z - p.x, 0.0, size.x - r.z - r.w);
    return left_start + clamp(size.y - r.w - p.y, 0.0, size.y - r.w - r.x);
}

// Same nested inversion fields as Fractal Iris, wrapped seamlessly around
// the client perimeter. Incommensurate-looking integer harmonics avoid a row
// of identical tiles while still matching exactly at the perimeter seam.
vec3 psyche_terrain(float angle, float d, float frequency) {
    vec2 q = vec2(
        sin(angle * frequency + 0.65 * sin(angle * 3.0)),
        d / max(REACH, 2.0) + 0.65 * sin(angle * (frequency + 1.0)));
    q = 1.4 * vec2(sin(q.x + 0.7 * sin(q.y * 1.7)),
                   sin(q.y - 0.7 * sin(q.x * 1.3)));
    vec2 mainField = psyche_fractal(q, 0.52, 0.02);
    vec2 fineField = psyche_fractal(q * 1.7 + vec2(0.31, 0.57), 0.71, 0.02);
    float terrain = smoothstep(0.22, 0.72, mainField.y);
    float tears = smoothstep(0.58, 0.80, fineField.y);
    float across = 0.5 + 0.5 * d / max(REACH, 2.0);
    float phase = 2.0 * (0.55 * across + 0.45 * terrain - 0.12 * tears)
        - angle / 3.14159265359;
    return vec3(phase, mainField.y, fineField.y);
}

vec4 psyche_edge(vec2 point, vec2 size, vec4 radii, float d) {
    vec4 r = clamp(radii, 0.0, min(size.x, size.y) * 0.5);
    float perimeter = max(2.0 * (size.x + size.y) - 0.4292036732 * dot(r, vec4(1.0)), 1.0);
    float along = psyche_perimeter(point, size, r);
    float angle = 6.28318530718 * along / perimeter;
    float frequency = max(2.0, floor(perimeter / max(PATTERN_SCALE, 30.0) + 0.5));
    vec3 terrain = psyche_terrain(angle, d, frequency);
    float pixel = 0.65 / max(umbriel_scale, 0.01);
    float dx = psyche_terrain(angle + 6.28318530718 * pixel / perimeter, d, frequency).x - terrain.x;
    float dy = psyche_terrain(angle, d + pixel, frequency).x - terrain.x;
    float aa = clamp(length(vec2(dx, dy)), 0.02, 0.26);
    // Sweeping an isocontour continuously opens, splits and merges the folds.
    // Geometry is not translated along the edge or scaled into fixed diamonds.
    float roll = umbriel_time * ROLL_SPEED;
    float phase = terrain.x + roll;
    float distance = abs(fract(phase + 0.5) - 0.5);
    float lip = 1.0 - smoothstep(0.065, 0.065 + aa, distance);
    float shoulder = 1.0 - smoothstep(0.10, 0.38, distance);
    float envelope = 1.0 - smoothstep(2.0, max(REACH, 2.5), abs(d));
    float guide = exp(-abs(d) * 1.8) * 0.10;
    float alpha = clamp(INTENSITY, 0.0, 1.0) * envelope
        * clamp(guide + 0.38 * lip + 0.55 * shoulder, 0.0, 1.0);
    vec3 colour = psyche_colour(terrain.y * 1.7 + terrain.z * 0.30
        + 0.30 * sin(angle * 3.0 - roll) + roll * 0.12);
    colour = mix(colour, vec3(0.88, 1.0, 0.97), lip * 0.24);
    return vec4(colour * alpha, alpha);
}

float psyche_distance(vec2 point) {
    vec2 halfSize = umbriel_size * 0.5;
    vec2 p = point - halfSize;
    float r = p.y < 0.0
        ? (p.x < 0.0 ? umbriel_corner_radius.x : umbriel_corner_radius.y)
        : (p.x < 0.0 ? umbriel_corner_radius.w : umbriel_corner_radius.z);
    r = clamp(r, 0.0, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec4 window(vec2 uv) {
    vec4 source = umbriel_sample(uv);
    vec2 point = uv * umbriel_size;
    float d = psyche_distance(point);
    if (d > 0.0 || d <= -REACH) return source;
    vec4 ink = psyche_edge(point, umbriel_size, umbriel_corner_radius, d);
    return vec4(source.rgb * (1.0 - ink.a) + ink.rgb * source.a, source.a);
}

