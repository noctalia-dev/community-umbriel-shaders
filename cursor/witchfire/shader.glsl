// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus. Original shader.
// Curve interpolation adapted from Comet and the bundled Noctalia trail shader.
const float INTENSITY = 0.8;
const float TRAIL_LIFE = 1.25;
const float FLAME_WIDTH = 10.0;
const vec3 GREEN = vec3(0.16, 0.88, 0.39);
const vec3 ORANGE = vec3(1.0, 0.39, 0.075);

vec2 liftPoint(vec2 p, float age, float birth) {
    return p + vec2(sin(birth * 13.0 + age * 25.0) * age * 7.0, -age * 23.0);
}
void flameSegment(vec2 here, vec4 p0, vec4 p1, vec4 p2, vec4 p3,
                  inout float fire, inout float embers) {
    if (p2.z >= TRAIL_LIFE) return;
    vec2 a = p1.xy * umbriel_size, b = p2.xy * umbriel_size;
    vec2 chord = b - a;
    float len = length(chord);
    if (len < 0.5 || len > 800.0) return;
    float dt = max(p1.z - p2.z, 0.001);
    vec2 m0 = (b - p0.xy * umbriel_size) * dt / max(p0.z - p2.z, 0.001);
    vec2 m1 = (p3.xy * umbriel_size - a) * dt / max(p1.z - p3.z, 0.001);
    m0 *= min(1.0, 1.5 * len / max(length(m0), 0.001));
    m1 *= min(1.0, 1.5 * len / max(length(m1), 0.001));
    float u = clamp(dot(here - a, chord) / (len * len), 0.0, 1.0);
    float bulge = (4.0 / 27.0) * (length(m0 - chord) + length(m1 - chord));
    if (length(here - mix(a, b, u)) > bulge + 3.0 * FLAME_WIDTH + TRAIL_LIFE * 90.0) return;
    vec2 previous = liftPoint(a, p1.z, p1.w);
    for (int j = 1; j <= 12; ++j) {
        float s = float(j) / 12.0;
        float s2 = s * s, s3 = s2 * s;
        vec2 point = (2.0*s3 - 3.0*s2 + 1.0)*a + (s3 - 2.0*s2 + s)*m0
                   + (-2.0*s3 + 3.0*s2)*b + (s3 - s2)*m1;
        point = liftPoint(point, mix(p1.z, p2.z, s), mix(p1.w, p2.w, s));
        vec2 piece = point - previous;
        float f = clamp(dot(here - previous, piece) / max(dot(piece, piece), 0.001), 0.0, 1.0);
        float along = (float(j) - 1.0 + f) / 12.0;
        float age = mix(p1.z, p2.z, along);
        float life = clamp(1.0 - age / TRAIL_LIFE, 0.0, 1.0);
        float d = length(here - mix(previous, point, f));
        float width = FLAME_WIDTH * (0.22 + 0.78 * life);
        fire = max(fire, exp(-d*d / (width*width)) * life);
        // Thin flame tongues peel off the curved ribbon as it ages.
        vec2 normal = vec2(-piece.y, piece.x) / max(length(piece), 0.001);
        float birth = mix(p1.w, p2.w, along);
        vec2 wisp = mix(previous, point, f) + normal * sin(birth * 14.0 + age * 9.0) * age * 17.0;
        wisp.y -= age * 9.0;
        float wd = length(here - wisp);
        float wispWidth = 1.2 + 2.8 * life;
        fire = max(fire, exp(-wd*wd/(wispWidth*wispWidth)) * life * 0.42 * smoothstep(0.02,0.2,age));
        previous = point;
    }
    float seed = fract(sin(p2.w * 173.1) * 4375.13);
    if (seed > 0.70) {
        vec2 spark = b + vec2((seed - 0.5) * p2.z * 75.0, -p2.z * 62.0);
        vec2 q = here - spark;
        embers = max(embers, exp(-dot(q,q) / 4.5) * clamp(1.0-p2.z/TRAIL_LIFE,0.0,1.0));
    }
}
vec4 cursor(vec2 uv) {
    vec4 source = umbriel_sample(uv);
    float fire = 0.0, embers = 0.0;
    vec4 p0 = vec4(0.0), p1 = p0, p2 = p0, p3 = p0;
    for (int k = 0; k < 64; ++k) {
        if (k < umbriel_pointer_count) {
            vec4 next = umbriel_pointer_path[k];
            if (k == 0) { p1 = next; p2 = next; p3 = next; }
            p0 = p1; p1 = p2; p2 = p3; p3 = next;
            if (k >= 2) flameSegment(uv * umbriel_size, p0,p1,p2,p3,fire,embers);
        }
    }
    if (umbriel_pointer_count >= 2) flameSegment(uv * umbriel_size,p1,p2,p3,p3,fire,embers);
    float head = length((uv - umbriel_pointer) * umbriel_size);
    float idle = exp(-head*head/95.0)*0.14;
    float strength = clamp(INTENSITY*(fire+idle),0.0,1.0)*smoothstep(2.0,7.0,head);
    vec3 rgb = mix(source.rgb,GREEN*source.a,strength);
    rgb = mix(rgb,ORANGE*source.a,clamp(embers*INTENSITY,0.0,1.0));
    return vec4(rgb,source.a);
}
