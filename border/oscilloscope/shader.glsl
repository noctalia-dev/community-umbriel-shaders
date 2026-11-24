// Original shader by cows on Discord (GitHub: acous).
// Source: https://gist.github.com/acous/0e3ae193232cdaffbdeb1ea34c652e50
// Upstream does not declare a license; see README.md.

// 64-band additive standing-wave border oscilloscope for Umbriel compositor.

const vec4  EDGE_MASK    = vec4(1.0, 0.1, 0.0, 0.0); // (bottom, top, left, right)
const float BASELINE_PX  = 8.0;
const float AMPLITUDE_PX = 2.25;

// Explicit constant-index calls below let drivers fold each band
// coefficient and texture coordinate even without automatic loop unrolling.
void add_band(float fi, float px_coord, float t, inout float k_i,
              inout vec4 sums, inout float peak_band) {
  float norm_i = fi * (1.0 / 63.0);

  float raw = umbriel_audio_entry(fi);
  float tilt = 2.0 + 0.8 * (norm_i * norm_i);
  float x = clamp((raw * tilt - 0.035) * 1.25, 0.0, 1.5);

  // Rejected bands contribute exactly zero. The branch is uniform across
  // the border, so silence skips all roots and trigonometry.
  if (x > 0.0) {
    float root_n = sqrt(norm_i);
    // x^2.125 and norm_i^1.5 without general-purpose pow().
    float x2 = x * x;
    float amp = x2 * sqrt(sqrt(sqrt(x)));
    float a = amp * (1.15 - 0.70 * root_n);

    float w_i = 8.0 + 57.0 * norm_i * root_n;
    float s_pos = k_i * px_coord + fi * 2.3999632;
    float standing_amp = a * cos(w_i * t + fi * 1.6180339);

    sums.x += standing_amp * sin(s_pos);
    sums.y += standing_amp * k_i * cos(s_pos);
    sums.z += a * a;
    sums.w += a * norm_i;
    peak_band = max(peak_band, a);
  }

  k_i *= 1.0796488;
}

vec4 border(vec2 uv) {
  float signed_distance = umbriel_border_distance(uv);
  // Umbriel masks these fragments completely; preserve the antialiased edge.
  if (signed_distance <= -0.5 / umbriel_scale) return vec4(0.0);
  float d = max(signed_distance, 0.0);
  vec4 native = umbriel_sample(uv);

  // Inner window half-extents and center-relative fragment coords in logical px
  vec2 win_half = max(umbriel_border_hole.zw * umbriel_size * 0.5, vec2(1.0));
  vec2 p = (uv - (umbriel_border_hole.xy + umbriel_border_hole.zw * 0.5)) * umbriel_size;

  // Raised-cosine-like bell envelopes (1 - x^2)^2 along horizontal and vertical spans
  vec2 uv_norm = clamp(p / win_half, -1.0, 1.0);
  vec2 bell = 1.0 - uv_norm * uv_norm;
  bell *= bell;

  // Vectorized edge masks: (bottom, top, left, right)
  vec4 edge_step_masks = smoothstep(win_half.yyxx - 4.0, win_half.yyxx, vec4(p.y, -p.y, -p.x, p.x));
  float edge_envelope = clamp(dot(EDGE_MASK, edge_step_masks * bell.xxyy), 0.0, 1.0);

  // Early-out for static border segments: skip 64-band synthesis completely
  // on disabled edges/corners or when the audio feed is unavailable.
  float trace_d = BASELINE_PX;
  float edge_slope = 0.0;
  float local_loudness = 0.0;
  float high_mod = 0.0;

  if (edge_envelope > 1e-3 && umbriel_audio_available() > 0.5) {
    bool is_horiz = (abs(p.y) - win_half.y) >= (abs(p.x) - win_half.x);
    float px_coord = is_horiz ? p.x : p.y;
    float t = umbriel_time;

    float peak_band = 0.0;

    // Preserve the original rounded recurrence, k *= 1.0796488.
    // Keep all 64 calls: their literal indices allow constant folding.
    float k_i = 0.024;

    // Wave, slope, energy and high-frequency contribution.
    vec4 sums = vec4(0.0);
    add_band(0.0, px_coord, t, k_i, sums, peak_band);
    add_band(1.0, px_coord, t, k_i, sums, peak_band);
    add_band(2.0, px_coord, t, k_i, sums, peak_band);
    add_band(3.0, px_coord, t, k_i, sums, peak_band);
    add_band(4.0, px_coord, t, k_i, sums, peak_band);
    add_band(5.0, px_coord, t, k_i, sums, peak_band);
    add_band(6.0, px_coord, t, k_i, sums, peak_band);
    add_band(7.0, px_coord, t, k_i, sums, peak_band);
    add_band(8.0, px_coord, t, k_i, sums, peak_band);
    add_band(9.0, px_coord, t, k_i, sums, peak_band);
    add_band(10.0, px_coord, t, k_i, sums, peak_band);
    add_band(11.0, px_coord, t, k_i, sums, peak_band);
    add_band(12.0, px_coord, t, k_i, sums, peak_band);
    add_band(13.0, px_coord, t, k_i, sums, peak_band);
    add_band(14.0, px_coord, t, k_i, sums, peak_band);
    add_band(15.0, px_coord, t, k_i, sums, peak_band);
    add_band(16.0, px_coord, t, k_i, sums, peak_band);
    add_band(17.0, px_coord, t, k_i, sums, peak_band);
    add_band(18.0, px_coord, t, k_i, sums, peak_band);
    add_band(19.0, px_coord, t, k_i, sums, peak_band);
    add_band(20.0, px_coord, t, k_i, sums, peak_band);
    add_band(21.0, px_coord, t, k_i, sums, peak_band);
    add_band(22.0, px_coord, t, k_i, sums, peak_band);
    add_band(23.0, px_coord, t, k_i, sums, peak_band);
    add_band(24.0, px_coord, t, k_i, sums, peak_band);
    add_band(25.0, px_coord, t, k_i, sums, peak_band);
    add_band(26.0, px_coord, t, k_i, sums, peak_band);
    add_band(27.0, px_coord, t, k_i, sums, peak_band);
    add_band(28.0, px_coord, t, k_i, sums, peak_band);
    add_band(29.0, px_coord, t, k_i, sums, peak_band);
    add_band(30.0, px_coord, t, k_i, sums, peak_band);
    add_band(31.0, px_coord, t, k_i, sums, peak_band);
    add_band(32.0, px_coord, t, k_i, sums, peak_band);
    add_band(33.0, px_coord, t, k_i, sums, peak_band);
    add_band(34.0, px_coord, t, k_i, sums, peak_band);
    add_band(35.0, px_coord, t, k_i, sums, peak_band);
    add_band(36.0, px_coord, t, k_i, sums, peak_band);
    add_band(37.0, px_coord, t, k_i, sums, peak_band);
    add_band(38.0, px_coord, t, k_i, sums, peak_band);
    add_band(39.0, px_coord, t, k_i, sums, peak_band);
    add_band(40.0, px_coord, t, k_i, sums, peak_band);
    add_band(41.0, px_coord, t, k_i, sums, peak_band);
    add_band(42.0, px_coord, t, k_i, sums, peak_band);
    add_band(43.0, px_coord, t, k_i, sums, peak_band);
    add_band(44.0, px_coord, t, k_i, sums, peak_band);
    add_band(45.0, px_coord, t, k_i, sums, peak_band);
    add_band(46.0, px_coord, t, k_i, sums, peak_band);
    add_band(47.0, px_coord, t, k_i, sums, peak_band);
    add_band(48.0, px_coord, t, k_i, sums, peak_band);
    add_band(49.0, px_coord, t, k_i, sums, peak_band);
    add_band(50.0, px_coord, t, k_i, sums, peak_band);
    add_band(51.0, px_coord, t, k_i, sums, peak_band);
    add_band(52.0, px_coord, t, k_i, sums, peak_band);
    add_band(53.0, px_coord, t, k_i, sums, peak_band);
    add_band(54.0, px_coord, t, k_i, sums, peak_band);
    add_band(55.0, px_coord, t, k_i, sums, peak_band);
    add_band(56.0, px_coord, t, k_i, sums, peak_band);
    add_band(57.0, px_coord, t, k_i, sums, peak_band);
    add_band(58.0, px_coord, t, k_i, sums, peak_band);
    add_band(59.0, px_coord, t, k_i, sums, peak_band);
    add_band(60.0, px_coord, t, k_i, sums, peak_band);
    add_band(61.0, px_coord, t, k_i, sums, peak_band);
    add_band(62.0, px_coord, t, k_i, sums, peak_band);
    add_band(63.0, px_coord, t, k_i, sums, peak_band);

    // Hardware rsqrt (`inversesqrt`) replaces 1.0 / sqrt(...)
    float rms_env = edge_envelope * inversesqrt(max(sums.z * 0.4225, 1.0));
    trace_d += sums.x * rms_env * AMPLITUDE_PX;
    edge_slope = sums.y * rms_env * 1.25;
    local_loudness = clamp(max(peak_band, sqrt(sums.z) * 0.42), 0.0, 1.35) * edge_envelope;
    high_mod = sums.w * 0.06 * edge_envelope;
  }

  float line_dist = abs(d - trace_d);
  float corrected_dist = line_dist * clamp(inversesqrt(1.0 + edge_slope * edge_slope), 0.2857, 1.0);

  // GLSL requires ascending smoothstep edges.
  float trace = 1.0 - smoothstep(0.30, 1.75, corrected_dist);
  float glow  = exp(-line_dist / (3.0 + 5.0 * local_loudness))
              * (0.15 + 0.85 * min(local_loudness, 1.0));

  float palette_pos = clamp(local_loudness * 0.35 + high_mod, 0.0, 0.70);
  vec4 base_palette = umbriel_palette_count > 0
      ? umbriel_palette_at(palette_pos)
      : vec4(0.60, 0.71, 0.95, 1.0);

  vec3 beam_rgb = mix(base_palette.rgb, vec3(1.0), trace * (0.25 + 0.50 * min(local_loudness, 1.0)));
  float intensity = min(trace + glow, 1.0);
  return mix(native, vec4(beam_rgb, 1.0), intensity) * max(native.a, intensity);
}
