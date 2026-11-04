// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
const float SPARK_INTENSITY = 2.5;
vec4 animation(vec2 uv) {
    float t = umbriel_clamped_progress;
    if (t <= 0.0 || t >= 1.0) return umbriel_sample(uv);
    float pulse = sin(3.14159265 * t);
    vec4 c = umbriel_sample(uv);
    vec2 p = uv - 0.5;
    // Continuous angular coordinate avoids corner jumps on thin rings.
    float phase = atan(p.y, p.x) / 6.2831853;
    float sparks = pow(0.5 + 0.5 * cos((phase - t * 1.7) * 6.2831853 * 4.0), 18.0);
    vec3 hot = vec3(0.15, 0.65, 1.0) * (0.5 + SPARK_INTENSITY * sparks);
    return vec4(c.rgb + hot * c.a * pulse, c.a);
}
