// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus.
// Adapted from the original cvd-deutan-alphabet window shader to the screen preset API.
// Four grain size and refresh-rate combinations encode deutan colour differences.
// STRENGTH controls texture amplitude; 0 disables the texture.

float grain(vec2 px, float cellsz, float hz){
    vec2 t    = fract(vec2(floor(umbriel_time * hz)) * 0.36593);
    vec2 q    = floor(px / cellsz);
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

    // Continuous axis, then quantized into the four zones.
    float axis    = clamp(err.r - err.g, -1.0, 1.0);
    float redSide = step(0.0, axis);                     // 1 = red family
    float strong  = step(0.55, abs(axis));               // 1 = deep end of the family

    float cellsz = mix(1.0, 3.0, redSide);               // size = family
    float hz     = mix(mix(6.0, 18.0, redSide),          // rate = depth (see table above)
                       mix(18.0, 6.0, redSide), strong);

    float g = grain(uv * umbriel_size, cellsz, hz);

    const float STRENGTH = 0.22;
    return vec4(s.rgb + g * amp * STRENGTH, s.a);        // Equal RGB offset; preserve source alpha.
}
