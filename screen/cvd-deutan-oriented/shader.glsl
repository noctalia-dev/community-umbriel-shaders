// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus.
// Adapted from the original cvd-deutan-oriented window shader to the screen preset API.
// Angled animated streaks encode deutan colour differences.
// STRENGTH controls texture amplitude; 0 disables the texture.

float grainCell(vec2 q, vec2 t){
    vec2 seed = fract(q * 0.01371 + t);
    return (fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 2.0;  // -1..1
}

vec4 screen(vec2 uv){
    vec4 s = umbriel_sample(uv);

    // Approximate colour-difference heuristic; not a calibrated vision model.
    vec3 sim = vec3(dot(vec3(0.625, 0.375, 0.0), s.rgb),
                    dot(vec3(0.700, 0.300, 0.0), s.rgb),
                    dot(vec3(0.0,   0.300, 0.7), s.rgb));
    vec3  err  = s.rgb - sim;
    float loss = length(err);
    float amp  = smoothstep(0.06, 0.45, loss) * s.a;
    if (amp < 0.003) return s;

    // Continuous confusion-axis coordinate: +1 = strongly red, -1 = strongly green.
    float axis = clamp(err.r - err.g, -1.0, 1.0);

    // Rotate the grain domain by the hue angle, then quantize ANISOTROPICALLY:
    // fine across the streak, long along it -> oriented streaky static.
    float th = axis * 0.873;                             // +-50deg
    float ca = cos(th), sa = sin(th);
    vec2  px = uv * umbriel_size;
    vec2  rp = vec2(ca * px.x - sa * px.y,
                    sa * px.x + ca * px.y);
    vec2  q  = floor(rp / vec2(1.5, 10.0));              // streaks along the rotated y axis

    vec2  t  = fract(vec2(floor(umbriel_time * 12.0)) * 0.36593);
    float g  = grainCell(q, t);

    const float STRENGTH = 0.22;
    return vec4(s.rgb + g * amp * STRENGTH, s.a);        // Equal RGB offset; preserve source alpha.
}
