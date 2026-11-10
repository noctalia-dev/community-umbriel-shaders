// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus.
// Adapted from the original cvd-protan window shader to the screen preset API.
// Coarse and fine animated grain selected by a protan colour-difference heuristic.
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
    vec3 sim = vec3(dot(vec3(0.56667, 0.43333, 0.0),     s.rgb),
                    dot(vec3(0.55833, 0.44167, 0.0),     s.rgb),
                    dot(vec3(0.0,     0.24167, 0.75833), s.rgb));

    // The colour information lost to that viewer; 0 for greys and unaffected colours.
    vec3  err  = s.rgb - sim;
    float loss = length(err);
    float amp  = smoothstep(0.06, 0.45, loss) * s.a;
    if (amp < 0.003) return s;

    // Which side of the confusion axis? >0 = red-ish, <0 = green-ish.
    float side    = err.r - err.g;
    float sideMix = smoothstep(-0.05, 0.05, side);       // 1 = red side

    vec2  px = uv * umbriel_size;
    float gR = grain(px, 3.0,  8.0, 0.0);                // red side: coarse + slow
    float gG = grain(px, 1.0, 20.0, 0.37);               // green side: fine + fast
    float g  = mix(gG, gR, sideMix);

    const float STRENGTH = 0.22;
    return vec4(s.rgb + g * amp * STRENGTH, s.a);        // Equal RGB offset; preserve source alpha.
}
