// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
// Two ghost-lit tear fronts unfold from a horizontal seam, then fold back to it.
const float RAGGEDNESS = 1.0; // 0..2; irregular tears and perforations.
const float WISP_WIDTH = 18.0; // Logical pixels, limited on small windows.
const float INTENSITY = 0.95; // 0..1; edge artwork only.
const vec3 PEARL = vec3(0.95, 0.98, 1.0);
const vec3 MINT = vec3(0.65, 0.89, 0.83);
const vec3 LAVENDER = vec3(0.80, 0.74, 0.94);

float gtw_hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)
                   + umbriel_random_seed.xyz);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float gtw_noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(gtw_hash(i), gtw_hash(i + vec2(1.0, 0.0)), f.x),
               mix(gtw_hash(i + vec2(0.0, 1.0)), gtw_hash(i + vec2(1.0)), f.x), f.y);
}

vec4 animation(vec2 uv) {
    float p = umbriel_clamped_progress;
    bool opening = umbriel_direction > 0.0;
    vec4 source = umbriel_sample(uv);
    if (p <= 0.0) return opening ? vec4(0.0) : source;
    if (p >= 1.0) return opening ? source : vec4(0.0);

    vec2 size = max(umbriel_size, vec2(1.0));
    vec2 point = uv * size;
    float unit = min(size.x, size.y);
    // A gently wavering horizontal seam, shared by both moving fronts.
    float centre = size.y * (0.5 + 0.035 * (umbriel_random_seed.w - 0.5))
                 + min(18.0, size.y * 0.045)
                   * (2.0 * gtw_noise(vec2(point.x * 0.009, 19.0)) - 1.0);
    float signedDepth = point.y - centre;
    float span = max(signedDepth < 0.0 ? centre : size.y - centre, 1.0);
    float depth = abs(signedDepth) / span;
    // Noise is held still so visible fabric never disappears during opening,
    // or returns during closing. Upper and lower edges erode independently.
    vec2 fabric = point / max(unit, 1.0);
    float folds = gtw_noise(fabric * 5.0 + 7.0);
    float tears = gtw_noise(fabric * 19.0 + 23.0);
    float pores = gtw_noise(fabric * 43.0 + 51.0);
    float fibres = gtw_noise(fabric * 89.0 + 83.0);
    float erosion = 0.20 * (folds - 0.5) + 0.20 * (tears - 0.5)
                  + 0.13 * (pores - 0.5) + 0.035 * (fibres - 0.5);
    float endFade = smoothstep(0.0, 0.14, depth)
                  * (1.0 - smoothstep(0.84, 1.0, depth));
    float arrival = clamp(depth + clamp(RAGGEDNESS, 0.0, 2.0) * erosion * endFade,
                          depth * 0.25, 1.0 - (1.0 - depth) * 0.25);
    float progress = p * p * (3.0 - 2.0 * p);
    float visible = opening ? progress : 1.0 - progress;
    float pixel = 1.0 / (span * max(umbriel_scale, 0.01));
    // Small margins place both near-endpoint frames beyond the antialias band.
    float front = mix(-pixel, 1.0 + pixel, visible);
    float edge = arrival - front;
    float coverage = 1.0 - smoothstep(-pixel, pixel, edge);

    float width = max(min(WISP_WIDTH, unit * 0.08), 1.0) / span;
    float distanceToEdge = abs(edge);
    float mist = 1.0 - smoothstep(0.0, width * 2.3, distanceToEdge);
    float veil = 1.0 - smoothstep(width * 0.10, width, distanceToEdge);
    float thread = 1.0 - smoothstep(pixel, width * 0.13 + pixel, distanceToEdge);
    float wisp = gtw_noise(vec2(point.x / max(unit, 1.0) * 29.0,
                               abs(signedDepth) / max(unit, 1.0) * 23.0 - visible * 4.0));
    float envelope = smoothstep(0.0, 0.035, visible)
                   * (1.0 - smoothstep(0.94, 1.0, visible));
    float strength = clamp(INTENSITY, 0.0, 1.0) * envelope;
    vec3 tint = mix(MINT, LAVENDER, smoothstep(0.2, 0.8, folds));
    vec3 spectral = mix(tint, PEARL, 0.40 + 0.60 * thread);
    vec3 color = mix(source.rgb, tint * source.a, mist * strength * (0.14 + wisp * 0.22));
    color = mix(color, spectral * source.a,
                strength * max(thread * 0.98, veil * (0.40 + wisp * 0.34)));
    // Confine wisps to the captured silhouette and preserve premultiplication.
    return vec4(color, source.a) * coverage;
}
