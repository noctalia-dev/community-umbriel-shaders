// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
// Ghostly Tear's pale colours, carried by a close, gently breathing wisp border.
const float PADDING = 16.0; // Keep equal to effect.toml padding.
const float WISP_REACH = 13.0; // Logical pixels beyond the luminous thread.
const float STRENGTH = 0.95; // 0..1; opacity of all border artwork.
const float WISP_SPEED = 1.0; // Speed of outward wisps and local curling.
const vec3 PEARL = vec3(0.95, 0.98, 1.0);
const vec3 MINT = vec3(0.65, 0.89, 0.83);
const vec3 LAVENDER = vec3(0.80, 0.74, 0.94);
const float TAU = 6.28318530718;

float gtb_offset(float borderWidth) { return min(borderWidth * 0.5, 2.5); }

vec4 gtb_radii(vec2 clientSize, float borderWidth) {
    return clamp(umbriel_border_radius, 0.0, min(clientSize.x, clientSize.y) * 0.5) + gtb_offset(borderWidth);
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

vec4 border(vec2 uv) {
    vec2 clientSize = umbriel_border_hole.zw * umbriel_size;
    if (min(clientSize.x, clientSize.y) <= 0.0) return vec4(0.0);
    float borderWidth = max(0.0, (umbriel_size.y - clientSize.y) * 0.5 - PADDING);
    float offset = gtb_offset(borderWidth);
    float reach = clamp(WISP_REACH, 2.0, PADDING - 2.0);
    float d = umbriel_border_distance(uv);
    float aa = 0.65 / max(umbriel_scale, 0.01);
    if (d < 0.0 || d >= offset + reach + 1.5) return vec4(0.0);

    vec2 point = (uv - umbriel_border_hole.xy) * umbriel_size;
    float perimeter = max(gtb_length(clientSize, borderWidth), 1.0);
    float along = gtb_perimeter(point, clientSize, borderWidth);
    float u = along / perimeter;
    float t = umbriel_time;
    float cells = max(floor(perimeter / 34.0), 4.0);
    float depth = max(d - offset, 0.0);

    // Local patches breathe independently. Nothing advances along the perimeter.
    float wispTime = t * max(WISP_SPEED, 0.0);
    float charge = smoothstep(0.20, 0.80,
        gtb_noise(vec2(u * 8.0, wispTime * 0.30 + 11.0), 8.0));
    float breath = 0.88 + 0.12 * sin(t * 1.55);
    float energy = breath * (0.65 + 0.35 * charge);
    // Standing, bidirectional sway bends the tips while roots stay in place.
    // Only the outward noise coordinate advances: little plumes rise and fade.
    float sway = 0.34 * sin(wispTime * 1.10) * sin(TAU * u * 7.0)
               + 0.23 * sin(wispTime * 0.73) * sin(TAU * u * 13.0);
    float bend = sway * smoothstep(0.0, reach, depth)
               + 0.13 * sin(depth * 0.42) * sin(wispTime * 1.35)
                 * sin(TAU * u * 11.0);
    vec2 q = vec2(u * cells + bend, depth * 0.20 - wispTime * 0.65);
    float broad = gtb_noise(q, cells);
    float detail = gtb_noise(q * 2.0 + vec2(0.0, 17.0), cells * 2.0);
    float fine = gtb_noise(q * 4.0 + vec2(0.0, 39.0), cells * 4.0);
    float fabric = broad * 0.60 + detail * 0.28 + fine * 0.12;
    float rootHeight = min(3.0, reach * 0.4);
    float height = rootHeight + (reach - rootHeight) * smoothstep(0.20, 0.70, fabric);
    float flame = 1.0 - smoothstep(height - 1.8, height + aa, depth);
    float fade = 1.0 - smoothstep(min(2.0, reach * 0.25), reach, depth);
    float wisps = flame * fade * smoothstep(0.16, 0.54, fabric);
    float filament = (1.0 - smoothstep(0.025, 0.13, abs(fabric - 0.52)))
                   * flame * fade;

    float threadPosition = offset + 1.3 * (fabric - 0.5)
                         + 0.16 * sin(TAU * u * cells) * sin(wispTime * 1.8);
    float threadDistance = abs(d - threadPosition);
    float thread = 1.0 - smoothstep(0.38, 0.38 + aa, threadDistance);
    float halo = exp(-threadDistance * 0.52);
    float alpha = thread * (0.34 + 0.40 * energy)
                + halo * 0.17 * energy
                + wisps * (0.50 + 0.30 * charge) * breath
                + filament * 0.22 * energy;
    // Fade within the allocation; shallow inward wisps use the companion overlay.
    alpha *= (1.0 - smoothstep(offset + reach - 1.0, offset + reach + 1.5, d));
    alpha = clamp(alpha * clamp(STRENGTH, 0.0, 1.0), 0.0, 0.92);
    float tintPhase = 0.5 + 0.35 * sin(TAU * u * 2.0)
                   + 0.15 * sin(t * 0.5) * sin(TAU * u * 7.0);
    vec3 tint = mix(MINT, LAVENDER, tintPhase);
    vec3 color = mix(tint, PEARL, 0.30 + 0.60 * thread);
    return vec4(color * alpha, alpha);
}
