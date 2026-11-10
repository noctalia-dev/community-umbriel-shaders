// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus (Umbriel adaptation).
// Based on BanchouBoo's picom grain, released under the Unlicense.
// See README.md and LICENSES/BanchouBoo-Unlicense.txt for provenance.

const float GRAIN_INTERVAL = 15.0;
const float GRAIN_OPACITY  = 0.035;
const float GRAIN_SIZE     = 1.0;

vec4 screen(vec2 uv){
    vec4 s = umbriel_sample(uv);

    // Refresh the noise field INTERVAL times/sec (not every frame). .36593 is just a
    // random number so the offset never sticks on whole-number multiples.
    vec2 offset = fract(vec2(floor(umbriel_time * GRAIN_INTERVAL)) * 0.36593);

    // Pixel-locked seed, quantized to GRAIN_SIZE physical pixels.
    vec2 q    = floor(uv * umbriel_size / GRAIN_SIZE);
    vec2 seed = fract(q * 0.01371 + offset);
    float g   = (fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 2.0;  // -1..1

    // Boost the grain ONLY very close to pure black or pure white (midtones untouched).
    float luma = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
    float ext  = abs(luma * 2.0 - 1.0);                 // 0 mid -> 1 at black/white
    float gain = 1.0 + smoothstep(0.85, 0.95, ext) * 1.10;

    // Add the same offset to each RGB channel; preserve source alpha.
    // Scaled by s.a so rounded corners / transparent edges stay clean.
    return vec4(s.rgb + g * GRAIN_OPACITY * gain * s.a, s.a);
}
