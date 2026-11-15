vec4 border(vec2 uv) {
    vec4 native = umbriel_sample(uv);

    float angle = atan(uv.y - 0.5, uv.x - 0.5);
    float runner = pow(max(0.0, cos(angle - umbriel_time * 0.7)), 10.0);
    float breathe = 0.90 + 0.10 * sin(umbriel_time * 0.8);
    float brightness = (0.25 + 0.75 * runner) * breathe;

    vec4 tint = umbriel_palette_count > 0
        ? umbriel_palette_at(0.0)
        : vec4(0.48, 0.64, 1.0, 1.0);

    vec3 paletteTint = mix(vec3(1.0), tint.rgb, 0.30);
    vec3 color = native.rgb * paletteTint * brightness;

    return vec4(color, native.a);
}
