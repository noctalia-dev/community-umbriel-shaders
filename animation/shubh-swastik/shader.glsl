// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Zero (zero_likes_nothing)
// Shubh Swastik (outline): a full-scene workspace reveal for Diwali.
// An upright, clockwise Hindu swastika (卐) is traced as a glowing outline with
// rounded arms and four bindu rings, encircled by a double ring of diyas that
// light in turn, in a molten amber "sorcerer's portal" palette. A wavering
// amber rim then opens behind it onto the incoming workspace. Nothing rotates.

const float SYMBOL_SIZE  = 0.14;  // Stem length, fraction of the shorter output side.
const float ARM_WIDTH    = 0.22;  // Thickness of the hollow arms, fraction of the stem.
const float CORNER_ROUND = 0.10;  // Fillet of the inner corners (centre and bends), in stems.
const float HOOK_LEN     = 1.0;   // Hook length, fraction of the stem (1.0 keeps all arms aligned).
const float TIP_LEN      = 0.17;  // Flicked tip at the end of each hook, fraction of the stem.
const float TIP_TAPER    = 0.65;  // Tip thickness at its end, fraction of the arm thickness.
const float TIP_ANGLE    = 38.0;  // Degrees the tip turns outward, away from the centre.
const float LINE         = 0.022; // Bright outline core, fraction of the stem.
const float GLOW         = 0.07;  // Glow falloff around lines, fraction of the stem.
const float SHIMMER      = 0.25;  // 0..1; energy flowing along the lines. 0 = steady.
const float RING_INNER   = 1.85;  // Ring radii, in stems; the diyas sit between them.
const float RING_OUTER   = 2.20;
const float DIYAS        = 16.0;  // Diyas around the ring, lit in turn clockwise from the top.
const float DIYA_SCALE   = 1.0;   // Diya size multiplier.
const float RIM_WOBBLE   = 5.0;   // Logical pixels; flame-like waver of the portal rim.
const float DRAW_END     = 0.40;  // Progress at which the outline finishes tracing.
const float REVEAL_START = 0.30;  // Progress at which the portal starts opening.
const float FADE_START   = 0.70;  // Progress at which the symbol starts fading.
const float TAU = 6.28318530718;
const vec3 CORE  = vec3(1.00, 0.94, 0.72); // White-hot line centre.
const vec3 GOLD  = vec3(1.00, 0.60, 0.14); // Amber glow.
const vec3 EMBER = vec3(0.90, 0.26, 0.03); // Deep orange haze.

float swastik_segment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.00001), 0.0, 1.0);
    return length(p - a - ab * h);
}

// Smooth union: rounds the inner corner where two strokes meet.
float swastik_smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Rounded stroke along ab, radius h at a narrowing to h * taper at b.
// Returns (signed distance, unit direction from the stroke's axis to p).
vec3 swastik_stroke(vec2 p, vec2 a, vec2 b, float h, float taper) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.00001), 0.0, 1.0);
    vec2 v = p - a - ab * t;
    float l = length(v);
    return vec3(l - h * mix(1.0, taper, t), v / max(l, 0.00001));
}

// Union of two strokes that fillets concave corners only. Where both strokes
// face the same way (a shared rounded end, the outside of a bend) it is a
// plain union, so convex corners keep their size instead of bulging.
vec3 swastik_join(vec3 a, vec3 b, float k) {
    float kk = k * clamp(1.0 - dot(a.yz, b.yz), 0.0, 1.0);
    if (kk < 0.0001) return a.x < b.x ? a : b;
    float h = clamp(0.5 + 0.5 * (b.x - a.x) / kk, 0.0, 1.0);
    vec2 n = mix(b.yz, a.yz, h);
    return vec3(mix(b.x, a.x, h) - kk * h * (1.0 - h), n / max(length(n), 0.0001));
}

// One arm in its own frame (y up): a rounded brush stroke up from the centre,
// hooking right, then a short tapered tip flicked outward (up, away from the
// centre). t in [0,1] draws the stroke outward from the centre.
vec3 swastik_arm(vec2 p, float t, float h) {
    float s = t * (1.0 + HOOK_LEN + TIP_LEN);
    vec3 d = swastik_stroke(p, vec2(0.0), vec2(0.0, clamp(s, 0.0, 1.0)), h, 1.0);
    if (s > 1.0) {
        vec2 corner = vec2(0.0, 1.0);
        vec2 hookEnd = corner + vec2(HOOK_LEN, 0.0);
        vec3 hook = swastik_stroke(p, corner, corner + vec2(min(s - 1.0, HOOK_LEN), 0.0), h, 1.0);
        d = swastik_join(d, hook, CORNER_ROUND);
        if (s > 1.0 + HOOK_LEN) {
            float a = radians(TIP_ANGLE);
            float grown = min(s - 1.0 - HOOK_LEN, TIP_LEN);
            vec3 tip = swastik_stroke(p, hookEnd, hookEnd + vec2(cos(a), sin(a)) * grown,
                                      h, mix(1.0, TIP_TAPER, grown / TIP_LEN));
            d = swastik_join(d, tip, CORNER_ROUND);
        }
    }
    return d;
}

// Signed distance to the solid symbol. Clockwise (卐): top arm hooks right,
// right arm hooks down, bottom arm hooks left, left arm hooks up. Each arm's
// direction is rotated back into the shared frame before joining.
float swastik_shape(vec2 q, float t) {
    float h = ARM_WIDTH * 0.5;
    vec3 d = swastik_arm(q, t, h);
    vec3 r = swastik_arm(vec2(-q.y, q.x), t, h);
    d = swastik_join(d, vec3(r.x, r.z, -r.y), CORNER_ROUND);
    r = swastik_arm(-q, t, h);
    d = swastik_join(d, vec3(r.x, -r.yz), CORNER_ROUND);
    r = swastik_arm(vec2(q.y, -q.x), t, h);
    d = swastik_join(d, vec3(r.x, -r.z, r.y), CORNER_ROUND);
    return d.x;
}

// One upright diya at the origin (y up, stem units): an outlined clay
// bowl with a spout, and a teardrop flame on the spout. Returns
// (bowl outline distance, flame signed distance).
vec2 swastik_diya(vec2 p, float lit, float flicker) {
    p /= DIYA_SCALE;
    vec2 r = vec2(0.11, 0.065);
    float bowl = max((length(p / r) - 1.0) * min(r.x, r.y), p.y); // Half ellipse, flat rim.
    float spout = swastik_segment(p, vec2(0.07, -0.015), vec2(0.15, 0.015)) - 0.016;
    bowl = swastik_smin(bowl, spout, 0.03);
    float height = 0.11 * lit;
    vec2 f = p - vec2(0.15, 0.03);
    float rise = clamp(f.y / max(height, 0.001), 0.0, 1.0);
    f.x -= flicker * 0.012 * rise; // Sway the tip, not the base.
    float flame = length(vec2(f.x, f.y - clamp(f.y, 0.0, height))) - 0.028 * lit * (1.0 - rise);
    return vec2(abs(bowl), flame) * DIYA_SCALE;
}

// Light emitted by a line at distance e (same units as LINE/GLOW).
vec3 swastik_light(float e, float aa) {
    float core = 1.0 - smoothstep(LINE * 0.5 - aa, LINE * 0.5 + aa, e);
    vec3 halo = mix(GOLD, EMBER, smoothstep(0.0, 3.0 * GLOW, e));
    return CORE * core * 1.2 + halo * exp(-e / GLOW) * 0.85 + EMBER * exp(-e / (4.0 * GLOW)) * 0.18;
}

vec4 animation(vec2 uv) {
    float p = umbriel_clamped_progress;
    if (p <= 0.0) return umbriel_sample(uv);
    if (p >= 1.0) return umbriel_sample_incoming(uv);

    vec2 px = (uv - 0.5) * umbriel_size;
    float minSide = min(umbriel_size.x, umbriel_size.y);
    float pixel = 1.0 / max(umbriel_scale, 0.01);

    // Portal behind the symbol: a wavering amber rim opening onto the new scene.
    float open = smoothstep(REVEAL_START, 0.98, p);
    float pr = length(px);
    float pang = atan(px.x, px.y);
    float wob = RIM_WOBBLE * (0.6 * sin(pang * 23.0 + p * 30.0) + 0.4 * sin(pang * 41.0 - p * 47.0));
    float radius = open * (length(umbriel_size) * 0.5 + 80.0) + wob * smoothstep(0.0, 0.1, open);
    float inside = 1.0 - smoothstep(radius - pixel, radius + pixel, pr);
    vec4 scene = mix(umbriel_sample(uv), umbriel_sample_incoming(uv), inside);
    float er = abs(pr - radius);
    vec3 rim = CORE * (1.0 - smoothstep(1.0, 2.5, er)) + GOLD * exp(-er / 6.0) * 0.9
             + EMBER * exp(-er / 22.0) * 0.35;
    scene.rgb += rim * smoothstep(0.0, 0.05, open) * scene.a;

    // Symbol.
    float show = smoothstep(0.0, 0.04, p) * (1.0 - smoothstep(FADE_START, 0.97, p));
    if (show <= 0.0) return scene;
    float L = SYMBOL_SIZE * minSide * (1.0 + 0.45 * smoothstep(REVEAL_START, 1.0, p));
    vec2 q = vec2(px.x, -px.y) / L;
    float aa = pixel / L;
    float draw = smoothstep(0.0, DRAW_END, p);

    // Soft darkening behind the symbol so the light reads on bright desktops.
    scene.rgb *= 1.0 - 0.5 * show * exp(-dot(q, q) / 5.0);

    // Swastika outline.
    float e = abs(swastik_shape(q, draw));

    // Bindu rings in the four quadrants, appearing as the arms complete.
    float pop = smoothstep(DRAW_END - 0.10, DRAW_END + 0.02, p);
    if (pop > 0.001) e = min(e, abs(length(abs(q) - vec2(0.5)) - 0.11 * pop));

    // Double ring traced clockwise from the top.
    float rr = length(q);
    float ang = fract(atan(q.x, q.y) / TAU);
    if (ang < draw) e = min(e, min(abs(rr - RING_INNER), abs(rr - RING_OUTER)));

    // Diyas between the rings, each lit as the trace passes it. Only the
    // nearest diya to this pixel is evaluated.
    vec3 flameLight = vec3(0.0);
    float idx = mod(floor(ang * DIYAS + 0.5), DIYAS);
    float slot = idx / DIYAS * 0.92;
    float lit = smoothstep(slot, slot + 0.08, draw);
    if (lit > 0.0) {
        float a = idx / DIYAS * TAU;
        vec2 centre = 0.5 * (RING_INNER + RING_OUTER) * vec2(sin(a), cos(a));
        vec2 local = q - centre + vec2(0.03, 0.055) * DIYA_SCALE; // Centre the lamp and flame.
        float flick = 0.6 * sin(umbriel_time * 9.0 + idx * 1.7) + 0.4 * sin(umbriel_time * 23.0 + idx * 4.1);
        vec2 diya = swastik_diya(local, lit * (0.92 + 0.08 * flick), flick);
        e = min(e, diya.x);
        float fd = diya.y;
        float body = 1.0 - smoothstep(-aa, aa, fd);
        flameLight = (CORE * body * 1.1 + GOLD * exp(-max(fd, 0.0) / 0.03) * 0.8
                    + EMBER * exp(-max(fd, 0.0) / 0.10) * 0.25) * lit;
    }

    float flow = 1.0 - SHIMMER + SHIMMER * (0.5 + 0.5 * sin(ang * TAU * 6.0 + rr * 8.0 - p * 25.0));
    scene.rgb += (swastik_light(e, aa) * flow + flameLight) * show * scene.a;
    return scene;
}
