# Accent Pulse

A soft pulse travels around the focused border, tinted by the theme accent.

![Synthetic preview of Accent Pulse](preview.png)

Preview rendered from this shader over a synthetic desktop sample; it is not a screenshot of a running session. It shows the outer shader only; paired inner overlays and compositor light are not shown.

## Use

Download [effect.toml](effect.toml) and [shader.glsl](shader.glsl) using GitHub’s **Download raw file** button and save them together in `~/.config/umbriel/shaders/community/border/accent-pulse/`. Keep the license notice linked below with your files. See [installation](../../README.md#install) for details.

Then merge this into `~/.config/umbriel/config.toml`:

```toml
[include]
files = ["shaders/community/border/accent-pulse/effect.toml"]

[effects]
border = "accent-pulse"
```

Append the include path to your existing `files` array and merge selectors into existing tables. Including `effect.toml` defines the preset; the selector enables it. [`config.toml`](config.toml) contains the same copyable example.

Borders apply to the focused, decorated window. Fullscreen and urgent windows do not display the border effect.

## Optional audio response

This is Umbriel's bundled `pulse`, renamed `accent-pulse` in this collection.
For audio-driven brightness with the original travelling pulse during silence,
download [shader-audio.glsl](shader-audio.glsl) beside `effect.toml` and change
the existing preset's `shader` value to `"shader-audio.glsl"`. Keep
`animated = true` (the default) and `speed` above zero for idle motion.

Requires Umbriel's spectrum API, verified at revision
[`76477c29`](https://github.com/noctalia-dev/umbriel/commit/76477c29).
The older `umbriel_audio_level()` helper is no longer supplied by current
Umbriel; use `umbriel_audio_spectrum(position)` instead.

In Noctalia, enable **Settings → Umbriel → Audio → Provide Audio to Umbriel**.
It is disabled by default. Alternatively, merge this into **Noctalia's**
configuration, not Umbriel's:

```toml
[shell]
umbriel_audio_provider_enabled = true
```

See [Noctalia's audio setup](https://github.com/noctalia-dev/noctalia/blob/main/docs/user/compositor-settings/umbriel.mdx#audio-reactive-effects).
For older Noctalia or another shell, use the
[standalone Python analyser](../../tools/README.md#standalone-audio-analyser)
(Python and PipeWire's `pw-record`; no pip packages). It sends Umbriel's current
[audio IPC](https://github.com/noctalia-dev/umbriel/blob/main/docs/user/ipc.md#audio-input).
Selecting a shader alone does not start audio capture. Update both Umbriel and
the provider if they use different audio protocol versions.

The variant estimates activity from three low/middle/high spectrum positions.
Below `SILENCE_LOW = 0.02`, or without a feed, it preserves the original pulse;
above `SILENCE_HIGH = 0.10` brightness follows the audio, blending between the
two at intermediate levels. Availability alone cannot detect silence: a live
provider can keep sending zeroes. `AUDIO_GAIN = 2.0` controls response strength;
lower the silence thresholds if quiet audio keeps the idle pulse active.
These are visual intensities, not calibrated loudness or fixed frequency bands.
The variant adds spectrum texture reads but no feedback buffers.

The bundled `audio` example reacts only to the lowest spectrum band and stays
dim without input. First check the provider toggle if it appears unresponsive.
Shader compilation failures also fall back to ordinary rendering; check
Umbriel's logs for obsolete helper names.

## Configuration options

Edit the existing `[effects.preset."accent-pulse"]` table in [effect.toml](effect.toml).
The [complete configuration reference](../../README.md#configuration-reference) explains
selection, overrides, and accepted ranges. The values below are this preset's shipped
settings, including defaults for omitted keys.

| TOML setting | Shipped value | What changing it does |
| --- | --- | --- |
| `kind` | `"border"` | Keep this kind: the source implements its `border` entry point. |
| `shader` | `"shader.glsl"` | Loads the source beside this preset; change the path only when using another compatible source. |
| `palette` | `true` | Supplies theme colours. Disable it to use the shader's fallback colour; see the colour controls below. |
| `padding` | `24` | Logical pixels of extra outward drawing space. Reducing it can clip artwork; it is not a painted-width control. |
| `speed` | `1.0` | Time multiplier: 0.5 halves speed, 2 doubles it, 0 freezes at time zero. Also controls an attached overlay. |
| `animated` | `true` | Set false to freeze this border and its attached overlay at time zero. |
| `overlay` | `""` | No inward pass is attached. A compatible window preset can be attached by name. |

The optional `[effects.preset."accent-pulse".light]` subtable is enabled in this preset.
Adding it enables light; removing the whole table disables it. Shader-painted glow is separate.

| Light setting | Shipped value | What changing it does |
| --- | --- | --- |
| `spread` | `48` | Logical-pixel reach; larger spreads light farther. |
| `intensity` | `1.2` | Brightness; lower is dimmer, 0 makes the light invisible. |
| `threshold` | `0.4` | Raise to emit only from brighter ring pixels; lower to include dimmer pixels. |

### Shader controls

Edit these values in [shader.glsl](shader.glsl), not in TOML. `#define` is
active GLSL code; comments use `//` or `/* ... */`. Start with small changes
and keep paired shaders in sync. Keep size and duration divisors positive.

| GLSL control or expression | Shipped value | Visual effect |
| --- | --- | --- |
| `glow falloff denominator` | `12.0 (both occurrences)` | Larger spreads the shader halo farther; smaller gives a tighter halo. Padding must contain it. |
| `angular frequency` | `3.0` | Number of pulse lobes around the ring; keep an integer to avoid a perimeter seam. |
| `wave time multiplier` | `2.0` | Larger moves pulses faster; the TOML speed also scales this. |
| `fallback tint` | `vec4(0.48, 0.64, 1.0, 1.0)` | Used only with palette disabled; otherwise edit accent_primary. |

Save and reload; see [reloading edits](../../README.md#reloading-edits).

## Compatibility and cost

Requires Umbriel with the preset effects API introduced in [`512e2fb3`](https://github.com/noctalia-dev/umbriel/commit/512e2fb3). No previous-frame feedback buffers are used. This adds a focused-border pass plus compositor light and blur. No performance benchmark is claimed.

The supplied preview does not verify HDR, rotated outputs or fractional scaling.

## Attribution

Author/contributor: Noctalia. License: [MIT](../../LICENSES/Noctalia-MIT.txt).

Copied from [Umbriel’s bundled pulse preset](https://github.com/noctalia-dev/umbriel/tree/c3d0eaafb1e31ee0abd99b547f85b5d52a28d0c7/examples/effects/border/pulse).
The preset is named `accent-pulse` here to distinguish it from Barrulus’s cyan `pulse`.
