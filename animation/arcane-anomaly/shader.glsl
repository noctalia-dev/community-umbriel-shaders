// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
// Centre-out arrival field adapted from Ghostly Tear by Barrulus.
// Coverage is stationary and monotonic; the neon discharge evolves with progress.
const float RAGGEDNESS = 1.35; // 0..2: torn lobes, holes and detached islands.
const float GLOW_WIDTH = 0.022; // Fraction of the shorter output dimension.
const float RIP_REACH = 0.055; // Reach of the secondary neon tears.
const float INTENSITY = 0.95; // 0..1: artwork only; never changes coverage.
const vec3 CYAN = vec3(0.035, 0.88, 1.0);
const vec3 MAGENTA = vec3(1.0, 0.035, 0.48);
const vec3 VIOLET = vec3(0.40, 0.055, 0.90);

float anomaly_hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)
        + umbriel_random_seed.xyz);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float anomaly_noise(vec2 p) {
    vec2 cell = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(anomaly_hash(cell), anomaly_hash(cell + vec2(1, 0)), f.x),
               mix(anomaly_hash(cell + vec2(0, 1)), anomaly_hash(cell + 1.0), f.x), f.y);
}

vec4 animation(vec2 uv) {
    float progress = umbriel_clamped_progress;
    if (progress <= 0.0) return umbriel_sample(uv);
    if (progress >= 1.0) return umbriel_sample_incoming(uv);

    float unit = max(min(umbriel_size.x, umbriel_size.y), 1.0);
    float pixel = 1.0 / (unit * max(umbriel_scale, 0.001));
    vec2 point = (uv - 0.5) * umbriel_size / unit;
    float radial = length(point);
    float corner = length(0.5 * umbriel_size / unit);
    float roughness = clamp(RAGGEDNESS, 0.0, 2.0);
    float width = max(GLOW_WIDTH, 0.002);
    float reach = clamp(RIP_REACH, 0.0, 0.15);

    // Ghostly Tear's perforated fabric becomes an irregular portal. The fixed
    // field opens satellite holes that join the main opening as it grows.
    vec2 warp = vec2(anomaly_noise(point * 3.1 + 7.0),
                     anomaly_noise(point * 3.1 + 39.0)) - 0.5;
    vec2 fabric = point + 0.20 * warp;
    float folds = anomaly_noise(fabric * 5.0);
    float tears = anomaly_noise(fabric * 13.0 + 17.0);
    float pores = anomaly_noise(fabric * 31.0 + 51.0);
    float fibres = anomaly_noise(fabric * 67.0 + 83.0);
    float erosion = 0.28 * (folds - 0.5) + 0.22 * (tears - 0.5)
                  + 0.16 * (pores - 0.5) + 0.035 * (fibres - 0.5);
    float arrival = max(radial * 0.25,
        radial + roughness * erosion * smoothstep(0.015, 0.22, radial));
    // Bounds cover every aspect ratio and allow the rim to leave the corners
    // before the exact incoming endpoint. Forward coverage cannot grow back.
    float margin = 0.348 * roughness + 3.0 * width + reach + 2.0 * pixel;
    float travel = progress * progress * (3.0 - 2.0 * progress);
    float radius = mix(-2.0 * pixel, corner, travel) + margin * pow(travel, 6.0);
    float d = arrival - radius;
    float coverage = 1.0 - smoothstep(-pixel, pixel, d);
    vec4 source = mix(umbriel_sample(uv), umbriel_sample_incoming(uv), coverage);

    float envelope = smoothstep(0.0, 0.10, progress)
                   * (1.0 - smoothstep(0.86, 1.0, progress));
    // Advect the electricity along the ragged fabric independently of coverage.
    // Progress, rather than wall time, makes reversing a swipe retrace the rips.
    vec2 flow = fabric * 38.0 + vec2(progress * 16.0, -progress * 23.0);
    float surge = anomaly_noise(flow);
    float splinter = anomaly_noise(fabric * 91.0 + vec2(-progress * 37.0, progress * 19.0));
    float discharge = 0.65 + 0.35 * sin(progress * 44.0 + folds * 16.0);
    float halo = exp(-abs(d) / (width * 1.5));
    float hotEdge = 1.0 - smoothstep(pixel, width * 0.18 + pixel, abs(d));

    // Opposite-colour rips peel away from both sides of the aperture, break up,
    // and reconnect. Their varying offsets form branching slivers and sparks.
    float offset = reach * (0.20 + 0.80 * surge);
    float jag = (splinter - 0.5) * width * 0.65;
    float outerDistance = abs(d - offset + jag);
    float innerDistance = abs(d + offset * 0.72 + jag);
    float filamentWidth = pixel * 0.7 + width * 0.045;
    float outer = (1.0 - smoothstep(filamentWidth, filamentWidth + pixel, outerDistance))
                * smoothstep(0.30, 0.58, surge);
    float inner = (1.0 - smoothstep(filamentWidth, filamentWidth + pixel, innerDistance))
                * smoothstep(0.35, 0.63, 1.0 - surge);
    float flare = max(exp(-outerDistance / (width * 0.36)),
                      exp(-innerDistance / (width * 0.36)));
    float sparks = smoothstep(0.78, 0.93, splinter)
                 * (1.0 - smoothstep(reach * 0.4, reach + width, abs(d)));
    float strength = clamp(INTENSITY, 0.0, 1.0) * envelope;
    vec3 color = mix(source.rgb, VIOLET * source.a, halo * strength * 0.36);
    color = mix(color, mix(CYAN, MAGENTA, surge) * source.a,
                flare * strength * 0.32);
    vec3 rim = mix(CYAN, MAGENTA, smoothstep(0.28, 0.72, surge));
    color = mix(color, rim * source.a, hotEdge * strength * discharge);
    color = mix(color, MAGENTA * source.a, outer * strength);
    color = mix(color, CYAN * source.a, inner * strength);
    color = mix(color, vec3(0.86, 0.96, 1.0) * source.a,
                max(sparks * 0.85, hotEdge * pow(surge, 6.0)) * strength);
    return vec4(color, source.a);
}
