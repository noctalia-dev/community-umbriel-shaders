// Spooky Move: adapted from Barrulus's Wobbly Move (MIT).
// A slow, deeply stretching sheet for animated moves and resizes.
// Deformation follows the event timeline, not pointer velocity.
const float STRETCH_STRENGTH = 3.0;
const float SWAY_CYCLES = 1.5;

vec4 animation(vec2 uv) {
    float p = clamp(umbriel_linear_progress, 0.0, 1.0);
    if (p <= 0.0 || p >= 1.0) return umbriel_sample(uv);
    // Exact resting endpoints, with the same damped envelope as Wobbly Move.
    float envelope = sin(3.14159265 * p) * (1.0 - p) * 1.55;
    float phase = 6.28318531 * SWAY_CYCLES * p;
    float swing = sin(phase);
    float counter = sin(phase - 1.15);
    float amplitude = envelope * clamp(STRETCH_STRENGTH, 0.0, 3.0);
    vec2 q = uv - 0.5;
    // Reserve room for the stronger bends inside the captured rectangle.
    // The strength cap keeps these divisors positive and the sheet bounded.
    vec2 inset = vec2(1.0) - amplitude * vec2(0.13, 0.12);
    q /= inset;
    float direction = umbriel_direction < 0.0 ? -1.0 : 1.0;
    q.x -= direction * amplitude * (0.035 * swing * cos(q.y * 5.2)
        + 0.022 * counter * sin(q.y * 6.0));
    q.y -= amplitude * (0.028 * counter * cos(q.x * 5.0)
        + 0.014 * swing * sin(q.x * 6.0));
    return umbriel_sample(q + 0.5);
}
