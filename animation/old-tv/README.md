# Old TV

Closing collapses the picture into a horizontal phosphor line, then a brighter central blink that lingers before winking out. Opening reverses the slower line-and-afterimage sequence.

![Synthetic opening frame of Old TV](preview.png)

Synthetic shader render at 55% of opening, not a compositor screenshot.

## Use

Save [effect.toml](effect.toml) and [shader.glsl](shader.glsl) together in `~/.config/umbriel/shaders/community/animation/old-tv/`, keeping the [MIT license](../../LICENSES/Barrulus-MIT.txt). Merge [config.toml](config.toml) into your Umbriel configuration:

```toml
[include]
files = ["shaders/community/animation/old-tv/effect.toml"]

[animation]
enabled = true

[animation.windows_in]
enabled = true
effect = "old-tv"
duration_ms = 850
curve = "linear"

[animation.windows_out]
enabled = true
effect = "old-tv"
duration_ms = 900
curve = "linear"
```

Append the include path to an existing `files` array and merge existing tables; do not duplicate them. Including the preset registers it; the two selectors activate the opening/closing pair. Animation selection is global per event.

## Theme palette

This preset enables `palette = true` in `effect.toml`. Artwork colours follow
Umbriel's `[colors]` accents, warning, and error colours, while retaining shading
and highlights. Set `palette = false` in that preset to restore the original
colours shown in the preview. For a border with a companion overlay, change
both presets together. Shader colour constants are the fallback colours.

## Configuration options

Edit the existing `[effects.preset."old-tv"]` table in [effect.toml](effect.toml).
The [complete configuration reference](../../README.md#configuration-reference) explains
selection, overrides, and accepted ranges. The values below are this preset's shipped
settings, including defaults for omitted keys.

| TOML setting | Shipped value | What changing it does |
| --- | --- | --- |
| `kind` | `"animation"` | Keep this kind: the source implements its `animation` entry point. |
| `shader` | `"shader.glsl"` | Loads the source beside this preset; change the path only when using another compatible source. |
| `palette` | `true` | Use theme colours for artwork. Set false to restore the original shader colours. |

Edit the event tables in your main Umbriel configuration (the activation
example is [config.toml](config.toml)). Larger `duration_ms` gives a slower
transition. Both `[animation] enabled` and the event must be enabled.

| Event | Example duration | Example curve |
| --- | --- | --- |
| `[animation.windows_in]` | `850` ms | `"linear"` |
| `[animation.windows_out]` | `900` ms | `"linear"` |

Use `effect = ""` to clear the custom selection or event `enabled = false`
to disable the transition. Spring curves choose their own duration.
This shader uses linear progress: changing easing does not reshape its internal phases.
Opening/closing `style` and `scale` do not tune a working custom shader.
There is no animation-preset TOML `speed`; use event timing.

### Shader controls

Edit these values in [shader.glsl](shader.glsl), not in TOML. `#define` is
active GLSL code; comments use `//` or `/* ... */`. Start with small changes
and keep paired shaders in sync. Keep size and duration divisors positive.

| GLSL control or expression | Shipped value | Visual effect |
| --- | --- | --- |
| `PHOSPHOR_WIDTH` | `2.0` | Bright line width in logical pixels; lower gives a finer phosphor line. |
| `BLINK_RADIUS` | `10.0` | Final bright-dot radius in logical pixels; lower makes a smaller dot. |

Save and reload; see [reloading edits](../../README.md#reloading-edits).

### Additional tuning notes

Edit `PHOSPHOR_WIDTH` for line-glow width in logical pixels; try 1–3 (default 2). `BLINK_RADIUS` sets the final central glow radius in logical pixels; try 6–14 (default 10). The final fifth of shutdown is reserved for the afterimage. Artwork follows the theme palette; shader colour constants apply with `palette = false`.

## Compatibility and cost

Targets `animation.windows_in` and `animation.windows_out` with the Umbriel preset effects API and GLSL ES 1.00. Both visible endpoints return the original premultiplied sample; both hidden endpoints return transparent black. No previous-frame feedback or extra textures are used.

One texture sample and analytic phosphor glows per fragment. No hardware performance benchmark is claimed.

The line and final blink add light over transparent regions. The vertical collapse can look sharper on very small windows.

WebGL checks covered compilation, transition endpoints and premultiplied alpha
over synthetic inputs. They do not verify native HDR, rotated or fractional-scale
outputs, interrupted transitions or hardware performance.

## Attribution

Author/contributor: Barrulus. Original implementation for this collection, 2026-09-29. License: [MIT](../../LICENSES/Barrulus-MIT.txt).
