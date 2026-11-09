// Sky Manipulation (swipe): window open/close inspired by Takako Uro's
// technique in Jujutsu Kaisen, which grabs the "sky" like cloth and warps space.
//
// A curved, rippling front of folded space sweeps across the window.
//   Close: everything behind the front is swallowed by the fold.
//   Open:  everything behind the front is revealed as space unfolds.
// Both sweep the same way, so a close followed by an open feels continuous.
// Near the front the content is dragged toward it and folds back over itself,
// with a chromatic split, a glowing crease, and strain lines in the hidden side.
//
// Uses umbriel_clamped_progress/direction and the per-transition seed. No
// umbriel_time. Three samples per pixel.

// ---- Tuning (logical pixels unless noted) --------------------------------
const float SWIPE_ANGLE_DEG   = 12.0;  // sweep direction: 0 = left to right, 90 = top to bottom
const float ANGLE_JITTER_DEG  = 20.0;  // random +/- spread per transition (0 = fixed)
const float FLIP_RANDOM       = 0.0;   // 1.0 = randomly sweep the opposite way too
const float CURVE             = 110.0; // front bows by this much (pulled-cloth bend)
const float WOBBLE            = 16.0;  // ripple in the front edge
const float WOBBLE_WAVELENGTH = 150.0; // distance between edge ripples
const float FOLD_DEPTH        = 110.0; // how far content is dragged toward the front
const float FOLD_FALLOFF      = 34.0;  // how quickly the drag fades with distance from the front
const float RIPPLE_AMP        = 16.0;  // sideways cloth ripple near the front
const float RIPPLE_WAVELENGTH = 90.0;
const float LIQUID_AMP        = 26.0;  // secondary glassy bands trailing behind the fold
const float LIQUID_WAVELENGTH = 38.0;  // distance between those bands along the sweep
const float DISPERSION        = 0.30;  // chromatic split of the fold (fraction of FOLD_DEPTH)
const float EDGE_SOFT         = 3.0;   // softness of the front's cut edge
const float RIM_WIDTH         = 3.5;   // glowing edge
const float RIM_GAIN          = 1.2;
const float CREASE_GAIN       = 0.55;  // highlight where the content folds over
const float HALO_WIDTH        = 48.0;  // strain lines in the hidden side
const float HALO_GAIN         = 0.5;
const float STRAIN_FREQ       = 0.30;  // radians per pixel for strain lines
const vec3  FALLBACK_A        = vec3(0.42, 0.55, 1.00); // used when palette is off
const vec3  FALLBACK_B        = vec3(0.78, 0.45, 1.00);
// ---------------------------------------------------------------------------

const float PI = 3.14159265;

vec3 sky_color(float t) {
    if (umbriel_palette_count > 0) {
        return mix(umbriel_palette_at(0.0), umbriel_palette_at(0.25), t).rgb;
    }
    return mix(FALLBACK_A, FALLBACK_B, t);
}

vec4 animation(vec2 uv) {
    float w = umbriel_clamped_progress;           // 0 -> 1 for both open and close
    bool opening = umbriel_direction > 0.0;

    // Exact endpoints: opening starts empty / ends untouched; closing the reverse.
    if (opening ? w >= 1.0 : w <= 0.0) { return umbriel_sample(uv); }
    if (opening ? w <= 0.0 : w >= 1.0) { return vec4(0.0); }

    // Per-transition sweep direction.
    vec4 seed = fract(umbriel_random_seed);
    float ang = radians(SWIPE_ANGLE_DEG + (seed.x - 0.5) * 2.0 * ANGLE_JITTER_DEG);
    if (FLIP_RANDOM > 0.5 && seed.z > 0.5) { ang += PI; }
    vec2 axis = vec2(cos(ang), sin(ang));
    vec2 tang = vec2(-axis.y, axis.x);

    vec2 p = uv * umbriel_size - 0.5 * umbriel_size;
    float half_s = 0.5 * (abs(axis.x) * umbriel_size.x + abs(axis.y) * umbriel_size.y);
    float half_n = 0.5 * (abs(tang.x) * umbriel_size.x + abs(tang.y) * umbriel_size.y);

    // The front travels far enough that the fold has fully cleared the window.
    float margin = 5.0 * FOLD_FALLOFF + CURVE + WOBBLE + 2.0 * EDGE_SOFT;
    float f = mix(-(half_s + margin), half_s + margin, w);

    float s = dot(p, axis);   // position along the sweep
    float n = dot(p, tang);   // position across it
    float nn = n / half_n;

    // Wavy, bowed front.
    float ph = w * 7.0;
    float k1 = 2.0 * PI / WOBBLE_WAVELENGTH;
    float edge = CURVE * (1.0 - nn * nn)
               + WOBBLE * (sin(n * k1 + ph) + 0.5 * sin(n * k1 * 2.3 - ph * 1.3)) / 1.5;

    // d > 0 inside the visible side, measured from the front.
    float vs = opening ? -1.0 : 1.0;
    float d = vs * (s - f - edge);

    // Fold: content within the band is dragged toward the front, and with
    // FOLD_DEPTH > FOLD_FALLOFF it folds back over itself.
    // The drag reaches exactly zero by 5 * FOLD_FALLOFF; the front starts and
    // ends at least that far away, so both endpoints match the source exactly.
    float dd = max(d, 0.0);
    float reach = 1.0 - smoothstep(4.0 * FOLD_FALLOFF, 5.0 * FOLD_FALLOFF, dd);
    float drag = reach * (FOLD_DEPTH * exp(-dd / FOLD_FALLOFF)
               + LIQUID_AMP * exp(-dd / (FOLD_FALLOFF * 1.5))
                 * sin(dd * 2.0 * PI / LIQUID_WAVELENGTH - w * 10.0 + n * 0.012));
    float rip = reach * RIPPLE_AMP * exp(-dd / (FOLD_FALLOFF * 1.5))
              * sin(n * 2.0 * PI / RIPPLE_WAVELENGTH + w * 9.0);
    vec2 base = p + tang * rip;
    vec2 centre = 0.5 * umbriel_size;
    vec2 src_r = base + axis * vs * drag * (1.0 + DISPERSION) + centre;
    vec2 src_g = base + axis * vs * drag + centre;
    vec2 src_b = base + axis * vs * drag * (1.0 - DISPERSION) + centre;

    vec4 sr = umbriel_sample(src_r / umbriel_size);
    vec4 sg = umbriel_sample(src_g / umbriel_size);
    vec4 sb = umbriel_sample(src_b / umbriel_size);
    // Widest alpha keeps the split channels valid premultiplied colour at edges.
    vec4 col = vec4(sr.r, sg.g, sb.b, max(sg.a, max(sr.a, sb.a)));

    // Cut the hidden side with a soft edge.
    col *= smoothstep(0.0, EDGE_SOFT, d);

    // Light only while the front is crossing the window.
    float gate = clamp(1.0 - (abs(f) - half_s) / (2.0 * HALO_WIDTH), 0.0, 1.0);

    float rim = exp(-abs(d) / RIM_WIDTH) * RIM_GAIN;
    float crease_d = FOLD_FALLOFF * log(max(FOLD_DEPTH / FOLD_FALLOFF, 1.0001));
    float crease = d > 0.0 ? exp(-abs(d - crease_d) / 3.0) * CREASE_GAIN : 0.0;
    float dh = max(-d, 0.0);
    float strain = d < 0.0
        ? exp(-dh / HALO_WIDTH) * (0.55 + 0.45 * cos(dh * STRAIN_FREQ - w * 12.0)) * HALO_GAIN
        : 0.0;
    float glow = clamp((rim + crease + strain) * gate, 0.0, 1.0);

    vec3 gc = sky_color(0.5 + 0.5 * sin(n * k1 * 0.7 + w * 5.0));
    vec4 outc;
    outc.rgb = col.rgb + gc * glow * 0.85;
    outc.a = col.a + glow * (1.0 - col.a);
    return outc;
}
