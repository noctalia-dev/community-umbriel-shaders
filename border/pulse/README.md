# Pulse

A cyan border that gently brightens and fades.

![Synthetic preview of Pulse](preview.png)

Preview rendered from this shader over a synthetic desktop sample; it is not a screenshot of a running session. It shows the outer shader only; paired inner overlays and compositor light are not shown.

## Use

Download [effect.toml](effect.toml) and [shader.glsl](shader.glsl) using GitHub’s **Download raw file** button and save them together in `~/.config/umbriel/shaders/community/border/pulse/`. Keep the license notice linked below with your files. See [installation](../../README.md#install) for details.

Then merge this into `~/.config/umbriel/config.toml`:

```toml
[include]
files = ["shaders/community/border/pulse/effect.toml"]

[effects]
border = "pulse"
```

Append the include path to your existing `files` array and merge selectors into existing tables. Including `effect.toml` defines the preset; the selector enables it. [`config.toml`](config.toml) contains the same copyable example.

Borders apply to the focused, decorated window. Fullscreen and urgent windows do not display the border effect. The `ring_padding` constant in the shader must match `padding` in `effect.toml`.

## Optional audio response

For audio-driven brightness with the same breathing pulse during silence,
download [shader-audio.glsl](shader-audio.glsl) beside `effect.toml` and change
the existing preset's `shader` value to `"shader-audio.glsl"`. Keep
`animated = true` and `speed` above zero.

Follow [audio setup and compatibility](../accent-pulse/README.md#optional-audio-response),
including enabling **Provide Audio to Umbriel** in Noctalia. This variant needs
the current `umbriel_audio_spectrum(position)` API, verified at Umbriel
[`76477c29`](https://github.com/noctalia-dev/umbriel/commit/76477c29).
The default `shader.glsl` still needs only the original preset API.

The variant samples low/middle/high spectrum positions. `SILENCE_LOW = 0.02`
and `SILENCE_HIGH = 0.10` blend between the original pulse and audio brightness;
`AUDIO_GAIN = 2.0` controls response strength. No feed or silent input preserves
the original pulse exactly. It adds spectrum texture reads and no feedback
buffers. The preview above shows the default shader.

## Theme palette

This preset enables `palette = true` in `effect.toml`. Artwork colours follow
Umbriel's `[colors]` accents, warning, and error colours, while retaining shading
and highlights. Set `palette = false` in that preset to restore the original
colours shown in the preview. For a border with a companion overlay, change
both presets together. Shader colour constants are the fallback colours.

## Configuration options

Edit the existing `[effects.preset."pulse"]` table in [effect.toml](effect.toml).
The [complete configuration reference](../../README.md#configuration-reference) explains
selection, overrides, and accepted ranges. The values below are this preset's shipped
settings, including defaults for omitted keys.

| TOML setting | Shipped value | What changing it does |
| --- | --- | --- |
| `kind` | `"border"` | Keep this kind: the source implements its `border` entry point. |
| `shader` | `"shader.glsl"` | Loads the source beside this preset; change the path only when using another compatible source. |
| `palette` | `true` | Use theme colours for artwork. Set false to restore the original shader colours. |
| `padding` | `0` | Logical pixels of extra outward drawing space. Keep GLSL `ring_padding` equal to it. Reducing it can clip artwork; it is not a painted-width control. |
| `speed` | `1` | Time multiplier: 0.5 halves speed, 2 doubles it, 0 freezes at time zero. Also controls an attached overlay. |
| `animated` | `true` | Set false to freeze this border and its attached overlay at time zero. |
| `overlay` | `""` | No inward pass is attached. A compatible window preset can be attached by name. |

The optional `[effects.preset."pulse".light]` subtable is absent, so compositor light is off.
Adding it enables light; removing the whole table disables it. Shader-painted glow is separate.

| Light setting | Default if enabled | What changing it does |
| --- | --- | --- |
| `spread` | `80` | Logical-pixel reach; larger spreads light farther. |
| `intensity` | `1.0` | Brightness; lower is dimmer, 0 makes the light invisible. |
| `threshold` | `0.5` | Raise to emit only from brighter ring pixels; lower to include dimmer pixels. |

### Shader controls

Edit these values in [shader.glsl](shader.glsl), not in TOML. `#define` is
active GLSL code; comments use `//` or `/* ... */`. Start with small changes
and keep paired shaders in sync. Keep size and duration divisors positive.

| GLSL control or expression | Shipped value | Visual effect |
| --- | --- | --- |
| `pulse baseline / amplitude` | `0.65 / 0.35` | Brightness average and breathing depth; reduce amplitude for a steadier ring. Keep the sum at most 1 and baseline at least amplitude. |
| `time multiplier` | `2.0` | Larger makes faster breathing; TOML speed also scales it. |
| `pigment` | `vec3(0.15, 0.8, 1.0)` | Cyan RGB colour; edit components in 0–1. |
| `ring_width in coverage` | `native border width` | The painted band follows the actual decoration width. Change appearance.border_width to narrow it. |

Save and reload; see [reloading edits](../../README.md#reloading-edits).

## Compatibility and cost

Requires Umbriel with the preset effects API introduced in [`512e2fb3`](https://github.com/noctalia-dev/umbriel/commit/512e2fb3). No previous-frame feedback buffers are used. This adds a focused-border pass. No performance benchmark is claimed.

The supplied preview does not verify HDR, rotated outputs or fractional scaling.

## Attribution

Author/contributor: Barrulus. License: [MIT](../../LICENSES/Barrulus-MIT.txt).

Contributed by Barrulus on 2026-09-27.
