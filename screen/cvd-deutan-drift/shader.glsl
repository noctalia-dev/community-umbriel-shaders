// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus.
// Adapted from the original cvd-deutan-drift window shader to the screen preset API.
// Persistent grain drifts in a direction selected by deutan colour differences.
// STRENGTH controls texture amplitude; 0 disables the texture.

float grainCell(vec2 q){
    vec2 seed = fract(q * 0.01371);
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

    // Compass: axis +1 -> up, 0 -> right, -1 -> down (screen y grows downward).
    float axis = clamp(err.r - err.g, -1.0, 1.0);
    float phi  = axis * 1.571;                           // +-90deg
    vec2  dir  = vec2(cos(phi), -sin(phi));

    const float SPEED = 30.0;                            // px/s
    vec2  px = uv * umbriel_size - dir * umbriel_time * SPEED;
    float g  = grainCell(floor(px / 2.0));

    const float STRENGTH = 0.22;
    return vec4(s.rgb + g * amp * STRENGTH, s.a);        // Equal RGB offset; preserve source alpha.
}
