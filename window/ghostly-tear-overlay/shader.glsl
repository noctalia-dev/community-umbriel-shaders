// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
// Shallow inward wisps for Ghostly Tear Border; source alpha is preserved.
const float INNER_REACH = 8.0; // Logical pixels into the client; hard fade at this depth.
const float INNER_STRENGTH = 0.45; // Maximum tint amount, clamped to 0..0.6.
const float WISP_SPEED = 1.0;
const vec3 PEARL = vec3(0.95, 0.98, 1.0);
const vec3 MINT = vec3(0.65, 0.89, 0.83);
const vec3 LAVENDER = vec3(0.80, 0.74, 0.94);
const float TAU = 6.28318530718;

float gtb_offset(float borderWidth) { return 0.0; }

vec4 gtb_radii(vec2 clientSize, float borderWidth) {
    return clamp(umbriel_corner_radius, 0.0, min(clientSize.x, clientSize.y) * 0.5) + gtb_offset(borderWidth);
}

float gtb_length(vec2 clientSize, float borderWidth) {
    vec2 size = clientSize + 2.0 * gtb_offset(borderWidth);
    return 2.0 * (size.x + size.y) - (2.0 - 1.57079632679) * dot(gtb_radii(clientSize, borderWidth), vec4(1.0));
}

// Rounded arclength gives the local wisps an even scale through corners.
float gtb_perimeter(vec2 coords, vec2 clientSize, float borderWidth) {
    vec2 p = coords + gtb_offset(borderWidth);
    vec2 size = clientSize + 2.0 * gtb_offset(borderWidth);
    vec4 r = gtb_radii(clientSize, borderWidth); // TL, TR, BR, BL
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

// Wrap the noise lattice to join local wisps cleanly at the perimeter seam.
float gtb_hash(vec2 cell, float period) {
    cell.x = mod(cell.x, period);
    vec3 q = fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float gtb_noise(vec2 p, float period) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(gtb_hash(i, period), gtb_hash(i + vec2(1.0, 0.0), period), f.x),
               mix(gtb_hash(i + vec2(0.0, 1.0), period),
                   gtb_hash(i + vec2(1.0), period), f.x), f.y);
}

float gtb_client_distance(vec2 point) {
    vec2 halfSize = umbriel_size * 0.5;
    vec2 p = point - halfSize;
    float radius = p.y < 0.0
        ? (p.x < 0.0 ? umbriel_corner_radius.x : umbriel_corner_radius.y)
        : (p.x < 0.0 ? umbriel_corner_radius.w : umbriel_corner_radius.z);
    radius = clamp(radius, 0.0, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

vec4 window(vec2 uv) {
    vec4 source = umbriel_sample(uv);
    vec2 point = uv * umbriel_size;
    float reach = min(clamp(INNER_REACH, 1.0, 12.0), min(umbriel_size.x, umbriel_size.y) * 0.2);
    float depth = -gtb_client_distance(point);
    if (reach <= 0.0 || depth < 0.0 || depth >= reach) return source;
    float aa = 0.65 / max(umbriel_scale, 0.01);
    float perimeter = max(gtb_length(umbriel_size, 0.0), 1.0);
    float u = gtb_perimeter(point, umbriel_size, 0.0) / perimeter;
    float cells = max(floor(perimeter / 34.0), 4.0);
    float t = umbriel_time;
    float wispTime = t * max(WISP_SPEED, 0.0);
    float charge = smoothstep(0.20, 0.80,
        gtb_noise(vec2(u * 8.0, wispTime * 0.30 + 11.0), 8.0));
    float breath = 0.88 + 0.12 * sin(t * 1.55);
    float sway = 0.34 * sin(wispTime * 1.10) * sin(TAU * u * 7.0)
               + 0.23 * sin(wispTime * 0.73) * sin(TAU * u * 13.0);
    float bend = sway * smoothstep(0.0, reach, depth)
               + 0.13 * sin(depth * 0.42) * sin(wispTime * 1.35)
                 * sin(TAU * u * 11.0);
    // Only depth advects: the wisps curl into the content, never around it.
    vec2 q = vec2(u * cells + bend, depth * 0.27 - wispTime * 0.65);
    float broad = gtb_noise(q, cells);
    float detail = gtb_noise(q * 2.0 + vec2(0.0, 17.0), cells * 2.0);
    float fine = gtb_noise(q * 4.0 + vec2(0.0, 39.0), cells * 4.0);
    float fabric = broad * 0.60 + detail * 0.28 + fine * 0.12;
    float height = reach * (0.20 + 0.80 * smoothstep(0.20, 0.70, fabric));
    float flame = 1.0 - smoothstep(height - 1.2, height + aa, depth);
    float fade = 1.0 - smoothstep(reach * 0.08, reach, depth);
    float wisps = flame * fade * smoothstep(0.16, 0.54, fabric);
    float filament = (1.0 - smoothstep(0.025, 0.13, abs(fabric - 0.52))) * flame * fade;
    float amount = clamp(INNER_STRENGTH, 0.0, 0.6) * breath
                 * (wisps * (0.55 + 0.35 * charge) + filament * 0.10);
    float tintPhase = 0.5 + 0.35 * sin(TAU * u * 2.0)
                   + 0.15 * sin(t * 0.5) * sin(TAU * u * 7.0);
    vec3 color = mix(mix(MINT, LAVENDER, tintPhase), PEARL, 0.40);
    return vec4(mix(source.rgb, color * source.a, amount), source.a);
}
