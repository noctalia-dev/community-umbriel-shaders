// Optional audio variant. See README.md for provider setup and selection.
const float SILENCE_LOW = 0.02;
const float SILENCE_HIGH = 0.10;
const float AUDIO_GAIN = 2.0;

// Sample low, middle and high spectrum positions for a simple activity estimate.
float audio_level() {
    return max(umbriel_audio_spectrum(0.08),
        max(umbriel_audio_spectrum(0.4), umbriel_audio_spectrum(0.7)));
}

vec4 border(vec2 uv) {
    float d = max(umbriel_border_distance(uv), 0.0);
    float ring = umbriel_sample(uv).a;
    float angle = atan(uv.y - 0.5, uv.x - 0.5);
    float wave = 0.5 + 0.5 * sin(angle * 3.0 - umbriel_time * 2.0);
    float level = audio_level();
    // A connected provider can send silence, so availability alone is insufficient.
    float live = umbriel_audio_available() * smoothstep(SILENCE_LOW, SILENCE_HIGH, level);
    wave = mix(wave, clamp(level * AUDIO_GAIN, 0.0, 1.0), live);
    vec4 tint = umbriel_palette_count > 0 ? umbriel_palette_at(0.0) : vec4(0.48, 0.64, 1.0, 1.0);
    float glow = exp(-d / 12.0) * (0.35 + 0.65 * wave);
    vec4 native = umbriel_sample(uv);
    return native * (1.0 - glow) + tint * glow * max(ring, 0.6 * exp(-d / 12.0));
}
