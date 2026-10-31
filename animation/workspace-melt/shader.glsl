// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Noctalia
// Full-scene API adaptation by Barrulus.
// Adapted from the session workspace-pair shader to the full-scene reveal API.
uniform vec2 umbriel_workspace_axis;

float workspace_sign() {
    return umbriel_workspace_axis.x + umbriel_workspace_axis.y < 0.0 ? -1.0 : 1.0;
}

// The outgoing image drips along the navigation axis. The destination is always
// sampled at its original coordinate. Progress and seed alone define motion,
// so reversing progress retraces the same shape at any point in the transition.
vec4 animation(vec2 output_uv) {
  float p = umbriel_clamped_progress;
  if (p <= 0.0) return umbriel_sample(output_uv);
  if (p >= 1.0) return umbriel_sample_incoming(output_uv);
  vec2 axis = abs(umbriel_workspace_axis);
  if (dot(axis, axis) < 0.5) axis = vec2(0.0, 1.0);
  float across = dot(output_uv, axis.yx);
  float wave = 0.5 + 0.5 * sin(across * 27.0 + umbriel_random_seed.x * 6.28318531)
      * cos(across * 43.0 + umbriel_random_seed.y * 6.28318531);
  float fall = p * (1.05 + 0.75 * wave * (1.0 - p));
  float direction = workspace_sign() < 0.0 ? -1.0 : 1.0;
  vec4 outgoing = umbriel_sample(output_uv - axis * direction * fall);
  return outgoing + umbriel_sample_incoming(output_uv) * (1.0 - outgoing.a);
}
