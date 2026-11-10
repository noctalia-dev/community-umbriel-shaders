// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus.
// Adapted from the original cvd-tritan window shader to the screen preset API.
// Coarse and fine animated grain selected by a tritan colour-difference heuristic.
// STRENGTH controls texture amplitude; 0 disables the texture.

float grain(vec2 px, float cellsz, float hz, float ofs){
    vec2 t    = fract(vec2(floor(umbriel_time * hz)) * 0.36593 + ofs);
    vec2 q    = floor(px / cellsz);
    vec2 seed = fract(q * 0.01371 + t);
    return (fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 2.0;  // -1..1
}

vec4 screen(vec2 uv){
    vec4 s = umbriel_sample(uv);

    // Approximate colour-difference heuristic; not a calibrated vision model.
    vec3 sim = vec3(dot(vec3(0.95, 0.05,    0.0),     s.rgb),
                    dot(vec3(0.0,  0.43333, 0.56667), s.rgb),
                    dot(vec3(0.0,  0.475,   0.525),   s.rgb));

    // The colour information lost to that viewer; 0 for greys and unaffected colours.
    vec3  err  = s.rgb - sim;
    float loss = length(err);
    float amp  = smoothstep(0.06, 0.45, loss) * s.a;
    if (amp < 0.003) return s;

    // Which side of the confusion axis? >0 = blue-ish, <0 = yellow-ish.
    float side    = err.b - 0.5 * (err.r + err.g);
    float sideMix = smoothstep(-0.05, 0.05, side);       // 1 = blue side

    vec2  px = uv * umbriel_size;
    float gB = grain(px, 3.0,  8.0, 0.0);                // blue side: coarse + slow
    float gY = grain(px, 1.0, 20.0, 0.37);               // yellow side: fine + fast
    float g  = mix(gY, gB, sideMix);

    const float STRENGTH = 0.22;
    return vec4(s.rgb + g * amp * STRENGTH, s.a);        // Equal RGB offset; preserve source alpha.
}
