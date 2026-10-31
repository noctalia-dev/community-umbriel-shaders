// Optional audio variant. See README.md for provider setup and selection.
const float SILENCE_LOW = 0.02;
const float SILENCE_HIGH = 0.10;
const float AUDIO_GAIN = 2.0;

// Sample low, middle and high spectrum positions for a simple activity estimate.
float audio_level() {
    return max(umbriel_audio_spectrum(0.08),
        max(umbriel_audio_spectrum(0.4), umbriel_audio_spectrum(0.7)));
}

// Adapted from shaders/rings/pulse.glsl

// Theme colours affect artwork only; palette = false restores the original RGB.
// Keep the original shade and soften highlights without changing effect opacity.
vec3 theme_color(vec3 original, float position) {
    if (umbriel_palette_count <= 0) return original;
    float value = max(original.r, max(original.g, original.b));
    float white = min(original.r, min(original.g, original.b)) / max(value, 0.0001);
    return value * mix(umbriel_palette_at(position).rgb, vec3(1.0), white * 0.75);
}

#define ring_padding 0.0
#define ring_size (umbriel_border_hole.zw * umbriel_size)
#define ring_width max((1.0 - umbriel_border_hole.w) * umbriel_size.y * 0.5 - ring_padding, 1.0)
#define ring_radius umbriel_border_radius
float ring_distance(vec2 coords) { return umbriel_border_distance(coords / umbriel_size + umbriel_border_hole.xy); }
// Custom shader by Barrulus.
vec4 ring_color(vec2 coords) {
    float d = ring_distance(coords);
    float half_px = 0.5 / umbriel_scale;
    float coverage = smoothstep(-half_px, half_px, d)
        * (1.0 - smoothstep(ring_width - half_px, ring_width + half_px, d));
    float pulse = 0.65 + 0.35 * sin(umbriel_time * 2.0);
    float level = audio_level();
    // A connected provider can send silence, so availability alone is insufficient.
    float live = umbriel_audio_available() * smoothstep(SILENCE_LOW, SILENCE_HIGH, level);
    pulse = mix(pulse, 0.3 + 0.7 * clamp(level * AUDIO_GAIN, 0.0, 1.0), live);
    return vec4(theme_color(vec3(0.15, 0.8, 1.0), 0.25) * pulse, coverage);
}

vec4 border(vec2 uv) {
    vec4 c = ring_color((uv - umbriel_border_hole.xy) * umbriel_size);
    return vec4(c.rgb * c.a, c.a);
}
