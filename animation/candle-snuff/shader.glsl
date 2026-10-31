// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original shader.
const float INTENSITY = 0.95; // 0..1, edge flicker only
const float EDGE_WIDTH = 8.0; // logical pixels
const vec3 ORANGE = vec3(1.0, 0.39, 0.075);
const vec3 GREEN = vec3(0.16, 0.88, 0.39);

vec4 animation(vec2 uv) {
    float progress = clamp(umbriel_linear_progress, 0.0, 1.0);
    float gone = umbriel_direction < 0.0 ? progress : 1.0 - progress;
    vec4 source = umbriel_sample(uv);
    if (gone <= 0.0) return source;
    if (gone >= 1.0) return vec4(0.0);
    vec2 p = uv * umbriel_size;
    vec2 edge = min(p, umbriel_size - p);
    float d = min(edge.x, edge.y);
    float rim = 1.0 - smoothstep(0.0, EDGE_WIDTH, d);
    // Captures can include transparent margins: follow their actual silhouette too.
    vec2 stepUV = vec2(EDGE_WIDTH) / max(umbriel_size, vec2(1.0));
    float innerAlpha = min(min(umbriel_sample(uv + vec2(stepUV.x, 0.0)).a,
                               umbriel_sample(uv - vec2(stepUV.x, 0.0)).a),
                           min(umbriel_sample(uv + vec2(0.0, stepUV.y)).a,
                               umbriel_sample(uv - vec2(0.0, stepUV.y)).a));
    rim = max(rim, clamp((source.a - innerAlpha) / max(source.a, 0.001), 0.0, 1.0));
    // Content yields immediately; all light remains inside the source silhouette.
    float body = 1.0 - smoothstep(0.0, 0.78, gone);
    float flicker = sin(3.14159265 * smoothstep(0.05, 0.95, gone));
    float patch = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(p.x * 0.023 + p.y * 0.031), 2.0);
    float flame = rim * patch * flicker * INTENSITY;
    vec3 tint = mix(ORANGE, GREEN, smoothstep(0.28, 0.72, gone));
    float a = (body + (1.0 - body) * flame) * source.a;
    vec3 rgb = source.rgb * body * (1.0 - 0.35 * gone);
    rgb = rgb * (1.0 - flame) + tint * flame * source.a;
    return vec4(rgb, a);
}
