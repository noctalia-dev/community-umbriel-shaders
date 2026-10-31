# Workspace Transporter

Continuous blue-white shafts carry vertical streaks of the outgoing scene, with drifting glints, then clear to the destination.

![Workspace Transporter compositor preview](preview.png)

[Animated full-scene preview](preview.gif), sampled from a private headless
Umbriel session with synthetic wallpaper, a panel and two populated workspaces.
The animation uses the configured 1400 ms timeline. These are compositor
captures, not a recording of a personal desktop or a performance benchmark.

## Use

Save [effect.toml](effect.toml) and [shader.glsl](shader.glsl) together under
`~/.config/umbriel/shaders/community/animation/workspace-transporter/`, retaining the
license notices below. Merge [config.toml](config.toml) into your configuration:

```toml
[include]
files = ["shaders/community/animation/workspace-transporter/effect.toml"]

[animation]
enabled = true

[animation.workspaces]
enabled = true
style = "reveal"
effect = "workspace-transporter"
duration_ms = 1400
curve = "linear"
```

Append to existing include lists and merge existing tables. Including a preset
registers it; the event selector enables it. `style = "reveal"` is required.
See [installation](../../README.md#install).

## Configuration options

The example uses **1400 ms** and `curve = "linear"`. Increase the duration
for a slower transition. Eased progress drives the shader; reversing a swipe
retraces the same effect with the transition’s held seed. Spring curves choose
their own duration. Clear `effect = ""` and restore `style = "slide"` to return
to native workspace sliding.

Edit [shader.glsl](shader.glsl) to tune the artwork: `energy_strength = 1.0` controls light (0–2); `beam_spacing = 30.0` and `beam_width = 1.8` are logical pixels. `beam_color` and `core_color` set the light colours.
These are GLSL controls, not TOML parameters. Colours are fixed; this preset
does not use the theme palette or audio input.

## Compatibility and cost

Requires Umbriel’s **full-scene workspace reveal API**, tested with
`0.1.0 (2145668)`: `umbriel_sample` reads the outgoing scene and
`umbriel_sample_incoming` reads the incoming scene. Both cover the whole output,
including wallpaper, windows, decorations and shell surfaces. The cursor and
output postprocessing follow the transition. Identical shared content can look
unchanged where a transition simply exchanges matching pixels.

Older root-mask reveal builds and the experimental `scene-v1` interface are
incompatible with this packaged preset. It uses the standard `animation` entry
point and requires no shared shader file or external texture. Exact endpoints
return the original outgoing and incoming scene respectively.

Four scene samples plus two procedural shaft layers and sparkles. No previous-frame feedback. Full-scene composition has capture costs;
hardware performance, HDR and rotated-output composition have not been
benchmarked.

## Provenance and attribution

Recovered from the showcase presets referenced by the effects-session launcher. Ported to the current reveal API with
output-wide coordinates and navigation direction from `umbriel_workspace_axis`.
Shared helpers and the saved parameter values are embedded in this shader so it
can be downloaded independently.

Original shader by Barrulus.
[MIT license](../../LICENSES/Barrulus-MIT.txt).
