---
name: umbriel-shaders
description: Create, adapt, and review GLSL effects for Umbriel, including community shader presets, activation examples, and validation. Use for Umbriel animation, border, window, screen, and cursor shaders.
---

# Umbriel shader authoring

Produce a usable Umbriel effect: a GLSL source file, its preset definition,
and instructions for selecting and testing it. These instructions work with
any coding assistant and require no particular editor, model, or tool API.

## Establish the target

Read [Contributing](README.md#contributing), [contributor tools](tools/README.md), and a
nearby preset of the requested kind. Follow their directory, naming, licensing,
attribution, preview, and catalog conventions; do not invent a repository
manifest format.
When adapting someone else's shader, retain required attribution and license.
Do not add Codex or other AI-assistance attribution to shaders or their documentation.

Choose the kind by where the effect must run. Infer it from the request when
clear; clarify when the choice would change the result. Keep the work within
the preset and its documentation unless broader changes were requested.

This contract was checked against Umbriel revision `0bd1b3a5`. If targeting
another version, check its documentation and implementation before using
additional inputs or configuration keys. In an Umbriel source checkout, use:

- `docs/user/effects.md` and `docs/user/animation.md` for the public contract.
- `examples/effects/` for working presets of all five kinds.
- `src/config/fields_effects.cpp` for accepted preset keys.
- `umbrielfx/render/fx_renderer/effect_shader.c` for injected GLSL declarations.
- `docs/design/effects.md` for feedback, composition, and rendering details.

These are paths in the Umbriel source repository, not required files in the
community repository. If unavailable, use the contract below and report any
version-dependent uncertainty instead of inventing an API.

## Choose a kind and activation point

| Kind | Required entry point | Selection | Rendering behavior |
| --- | --- | --- | --- |
| `animation` | `vec4 animation(vec2 uv)` | `[animation.<event>] effect = "name"` | Processes the event's captured target on its existing timeline. |
| `border` | `vec4 border(vec2 uv)` | `[effects] border = "name"` | Focused, decorated, non-urgent, non-fullscreen window's border ring. |
| `window` | `vec4 window(vec2 uv)` | `[effects] window = "name"` | Each window, including unfocused, undecorated, and fullscreen windows. |
| `screen` | `vec4 screen(vec2 uv)` | `[effects] screen = "name"` | Whole output after scene effects, before the cursor effect and software cursor. |
| `cursor` | `vec4 cursor(vec2 uv)` | `[effects] cursor = "name"` | Pixels around the pointer on its current output; never the cursor image itself. |

Window rules can select `border_effect` and `window_effect`; an output table
can select `screen_effect`. These overrides accept `"off"`. Use `""` to clear
a top-level selector. There is no per-window or per-output cursor override.

`[animation.border]` is a transient focus-border transition using an
`animation` preset. `[effects] border` is the persistent border effect using
a `border` preset. Do not interchange them.

## Package a preset

Use a top-level kind directory and a lowercase kebab-case effect directory:
`<kind>/<name>/`. Include `shader.glsl`, `effect.toml`, a copyable `config.toml`,
and a README with a preview, compatibility, tuning, cost, attribution, and
license. Update the relevant category page when adding a preset.

Add catalogue `metadata.toml` with `publish = false` for new submissions.
Maintainers approve `publish = true` after review and testing; tags do not control
publication. Families use the same flag in `[families.<id>]` definitions in root
`families.toml`. Declare member IDs and optional slot-to-member `defaults`;
never create family folders, copied previews or separate family configs. To validate unpublished
metadata locally, run `python3 tools/catalogue.py --draft --include-unpublished
--output /tmp/catalogue-development.json` (as one command). See
[publication and review](docs/catalogue-publication.md).

Choose a distinctive preset name: names are shared across all included files
and kinds, duplicate definitions are errors, and `off` is reserved. Quote TOML
table keys when the preset name contains a literal dot, for example
`[effects.preset."window.crt"]`.

A complete minimal window preset in `effect.toml`:

```toml
[effects.preset.soft-scanlines]
kind = "window"
shader = "shader.glsl"
```

Its `shader.glsl`:

```glsl
// Darken one logical pixel in every three, preserving source alpha.
vec4 window(vec2 uv) {
    vec4 source = umbriel_sample(uv);
    float row = mod(floor(uv.y * umbriel_size.y), 3.0);
    float gain = row < 1.0 ? 0.9 : 1.0;
    return vec4(source.rgb * gain, source.a);
}
```

Keep selection out of the distributable preset so including it only registers
it. Supply a separate activation example, with paths adapted to its installation:

```toml
[include]
files = ["shaders/community/window/soft-scanlines/effect.toml"]

[effects]
window = "soft-scanlines"
```

This example assumes the collection is installed under
`~/.config/umbriel/shaders/community/`. Put activation examples in `config.toml`
for users to merge, not include. Border presets with companion overlays should
include their companion's `effect.toml` using a relative path, as existing
presets do; users should not also include that companion separately.

Tell users to merge these entries into existing tables and append to existing
include lists. Repeating a TOML table is invalid. `shader` resolves relative
to the TOML file that declares it, including when that file is included.
It is a file path, not inline GLSL. Ship a nonblank regular source file with
no NUL bytes and a maximum size of 256 KiB.

Accepted preset keys:

| Kind | Keys and defaults |
| --- | --- |
| All | Required `kind`; `shader` path (missing means inert); `palette = false`. |
| Border only | `padding = 0` (integer, 0–1024 logical pixels); `speed = 1.0` (0–10); `animated = true`; `overlay = ""` (name of a window preset). |
| Border light only | A `[effects.preset.<name>.light]` table enables light: `spread = 80` (integer, 1–256 logical pixels), `intensity = 1.0` (0–4), `threshold = 0.5` (0–1). |
| Cursor only | `radius = 0` (integer, 0–4096 logical pixels). Positive values are the half-size of a square; zero covers the output. |

Keys for another kind are unknown keys. There is no generic custom-uniform,
texture-asset, multipass, or parameter table in this preset interface. Expose
shader-specific tuning as clearly named GLSL constants, with documented units
and useful ranges. Do not invent TOML controls such as `strength`, or put
`shader` directly under `[animation.<event>]`.

## Write against Umbriel's GLSL contract

Write GLSL ES 1.00 fragment code. Umbriel supplies precision, uniforms,
sampling helpers, and `main()`. Define the selected kind's entry point and
any private helpers/constants; omit `#version`, precision declarations,
`main`, and redeclarations of supplied symbols. Avoid desktop GLSL, GLSL ES
3 features, and extension-dependent functions unless verified on the target.
Use fixed loop bounds and ES 1.00-compatible indexing.

Port Shadertoy or other compositor code explicitly: do not retain `mainImage`,
`iResolution`, `iTime`, `iChannel0`, foreign uniforms, or raw framebuffer UVs.
Use `umbriel_sample` and `umbriel_sample_previous` rather than bypassing their
transforms with direct texture access. Do not assume extra textures or vertex
shaders can be supplied by a community preset.

The entry point receives normalized rectangle coordinates with `(0, 0)` at
the top left. Output rotation and fractional scaling are already handled by
the sampling helpers. Samples outside `[0, 1]` return transparent black.
For distances in logical pixels, use `(uv - center) * umbriel_size`; this
avoids stretching circles on non-square targets. One buffer pixel corresponds
to `1.0 / (umbriel_size * umbriel_scale)` in UV space.

Return **premultiplied RGBA**. To fade sampled content, multiply the whole
`vec4` by the mask. For a new straight RGB color and opacity `a`, return
`vec4(rgb * a, a)`. Preserve source alpha for ordinary color adjustments.
If unpremultiplication is necessary, guard zero alpha and premultiply again.
Do not force alpha to one or clamp every sample to SDR: captures can use
FP16 working buffers. In-place effects return the complete replacement pixel;
blend a tint with `umbriel_sample(uv)` inside the shader when appropriate.

### Shared inputs

| Input | Type and meaning |
| --- | --- |
| `umbriel_sample(uv)` | `vec4`: current input for this effect's rectangle. |
| `umbriel_sample_previous(uv)` | `vec4`: previous result belonging to this effect instance; see feedback below. |
| `umbriel_size` | `vec2`: drawn width and height in logical pixels. |
| `umbriel_scale` | `float`: buffer pixels per logical pixel. |
| `umbriel_expand` | `vec2`: expansion on each side as fractions of window width/height; normally zero, nonzero for an animation during drag deformation. Not a configurable padding control. |
| `umbriel_time` | `float`: seconds on the compositor's animation clock, not time since the effect started. Border speed scales it; frozen border clocks give zero. It is an unwrapped single-precision value. |
| `umbriel_palette_count` | `int`: four with `palette = true`, otherwise zero. |
| `umbriel_palette_at(t)` | `vec4`: interpolates a wrapping palette using `fract(t)`. The sequence is `accent_primary`, `accent_secondary`, `warning`, `error` at `t = 0.0, 0.25, 0.5, 0.75`. Returns transparent black without a palette. |

Enable `palette = true` when the shader depends on theme colors. Prefer the
palette helper over dynamic indexing of the injected array. Supply a fallback
color if the shader is intended to work with the palette disabled.

### Kind-specific behavior

**Animation:** Additional inputs are `float umbriel_progress` (eased, may
overshoot or reverse), `umbriel_clamped_progress` (a macro clamping that value
to `[0, 1]`), `float umbriel_linear_progress` (before easing),
`float umbriel_direction` (`+1` entering, `-1` leaving), and
`vec4 umbriel_random_seed` (stable for a transition). Use the stable seed for
per-transition randomness rather than making random choices every frame.
Clamped eased progress can still reverse; use linear progress when monotonic
timing is required.

Supported events are `windows_in`, `windows_out`, `windows_move`,
`workspaces`, `overview`, `scratchpad`, `border`, `dim_unfocused`, and `layers`.
`windows_drag` only accepts `physics`; it cannot select a custom preset.
Master/event `enabled`, `curve`, and `duration_ms` own the timeline; spring
curves choose their own duration. Shaders do not change geometry, hit testing,
clipping bounds, or lifetime. Opening/closing effects replace native lifecycle
visuals, so `style` and `scale` are ignored while the custom effect is active.
Other events postprocess the native presentation.

For a reveal, compute visibility as
`umbriel_direction > 0.0 ? umbriel_clamped_progress : 1.0 - umbriel_clamped_progress`
and multiply the sampled `vec4` by the resulting mask. Check both endpoints:
opening ends fully visible; closing ends invisible. A temporary movement
distortion should normally return the unmodified input at both endpoints.
Do not apply a lifecycle fade to a movement effect unless that is intended.
Workspace and overview effects shade whole trees, including inner effects.

**Border:** `umbriel_sample` reads the native ring. Extra uniforms are
`vec4 umbriel_border_hole` (UV origin in `.xy`, UV size in `.zw`) and
`vec4 umbriel_border_radius` (logical radii: top-left, top-right, bottom-right,
bottom-left). `umbriel_border_distance(uv)` returns signed logical distance
to the rounded client rectangle, negative inside. Umbriel always cuts out
the client hole after the shader returns. Use `padding` for an external glow;
the shader cannot draw beyond its allocated rectangle. A border's `overlay`
must reference a separately defined window preset and follows the border's
focus gate and clock. Border light adds rendering cost and its brightness
varies with output scale.

**Window:** At rest, sampling reads the framebuffer after the window has
drawn, including the backdrop visible through translucent content. Inside an
enclosing animation, sampling reads that animation's capture instead. Avoid
assuming the live backdrop is always available. Umbriel restores pixels
outside its rounded window mask. Client-side transparent margins can still
be shaded when corner radius is zero. This behavior also applies to overlays.

**Screen:** Sampling reads the composed output. Screen effects are detached
during session lock and do not shade the lock surface.

**Cursor:** `vec2 umbriel_pointer` is the pointer position in the drawn
rectangle's UV coordinates. Use it instead of assuming the center is always
`vec2(0.5)`, especially near output edges. Sampling reads the pixels beneath
the effect, not the cursor sprite. The square is clipped at output edges;
the effect hides when Umbriel hides the pointer and detaches during session
lock. A client hiding its cursor image alone does not disable the effect.

### Feedback and frame cost

Only use `umbriel_sample_previous` when history is part of the requested
effect. On the first render it samples the current input, not a cleared
buffer. History is local to the target, slot, output, renderer, and composition
role; it follows movement and is resampled when the target changes size.
New transitions/programs and changes to output transform, working format,
or renderer reset history. Close snapshots can inherit it.

Feedback allocates two extra target-sized buffers per instance and composition
role: about eight bytes per pixel in SDR, sixteen in FP16, before overhead.
Do not depend on history for correctness if allocation fails. There is no
public frame index or delta-time input; fixed per-frame decay changes speed
with frame rate. A previous-result sample alone does not request new frames.

Persistent effects request animation frames when their linked program actively
reads `umbriel_time` and their clock advances. Remove unnecessary time use
from static effects. Border `animated = false` or `speed = 0` freezes its time
at zero. `[effects] max_fps` (0–240, default 0 following output refresh) caps
effect-driven frames; it is a user setting, not a preset key. Avoid unnecessary
full-output cursor passes, large kernels, and unbounded work: window effects
run per window, while screen and cursor effects also prevent direct scanout
on affected outputs.

## Validate and deliver

For a contributor preview of one preset, use the installed compositor through
`python3 tools/render-preview.py <kind>/<name>`. Read [the tool instructions](tools/README.md)
for dependencies and animation options. This writes `<kind>/<name>/preview.png`
using synthetic content in a private headless session. Inspect the image and
describe it accurately; it is a real compositor capture rather than the older
offscreen preview format. No batch generation or personal-config changes are needed.

1. Check the TOML, unique preset name, matching kind/entry point, relative file
   paths, source size, and absence of unsupported keys or foreign shader inputs.
   Run `python3 tools/validate.py --umbriel /path/to/umbriel` as described in
   [contributor tools](tools/README.md). This checks configuration and source
   loading, not GPU compilation.
2. If Umbriel is installed, validate a configuration that includes and selects
   the preset: `umbriel config validate -c /path/to/test-config.toml`.
   Older builds use `umbriel validate -c /path/to/test-config.toml`; check
   `umbriel --help` for the installed command. This checks configuration and
   source loading; it does **not** compile GLSL.
3. Compile and inspect in an Umbriel test session with the preset selected.
   Unreferenced presets are not compiled. Shader files are watched for reload;
   `umbriel msg config-reload` explicitly reloads the addressed session.
   A running animation retains its program, so trigger a new event after edits.
   Check driver logs: compile failure falls back to ordinary rendering and
   can otherwise look like an effect that merely has no visible impact.
   GLSL diagnostics preserve source-file line numbers.
4. Exercise the behaviors the shader depends on: animation endpoints and
   overshoot; transparent and opaque content; wide/tall windows; fractional
   scale and rotation; border focus/fullscreen gating; cursor output edges;
   or feedback initialization and resize. Check cost at the intended sizes.
   A standalone compiler needs Umbriel's wrapper and cannot prove runtime
   sampling, composition, or appearance.
5. For screenshots or recordings of window, screen, and cursor effects, use
   `[effects] in_capture = true` in the test configuration if needed. Its
   default is false for screencopy/image-copy. Border effects remain visible;
   export-dmabuf always sees the displayed frame. Do not diagnose a missing
   captured effect as shader failure before checking capture policy.

Deliver the preset files and a concise usage note covering selection, tuning,
any companion preset, and relevant performance costs. Include previews or
catalog entries when the community repository requires them. Report the
Umbriel version/revision tested and distinguish configuration validation,
GLSL compilation, and visual testing. If no compositor or GPU was available,
state that runtime behavior remains unverified; do not claim a visual pass.

## Local development material

Keep `VALIDATION.md`, the browser `preview/` directory, and
`tools/test_audio_analyzer.py` local and ignored. Do not force-add them or
include them in an upstream contribution. Record concise test results in the
PR description and lasting limitations in each shader's README. Public tool
documentation describes how to run tools; it is not a development log.
