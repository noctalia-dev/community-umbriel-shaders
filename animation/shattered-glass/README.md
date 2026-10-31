# Shattered Glass

Opening reassembles an irregular fracture map. Closing breaks the window into 41 unequal polygonal shards, with clustered small splinters, large fragments, independent release delays, tumbling, launch velocities, and gravity.

![Synthetic opening frame of Shattered Glass](preview.png)

Synthetic shader render at 55% of opening, not a compositor screenshot.

## Use

Save [effect.toml](effect.toml) and [shader.glsl](shader.glsl) together in `~/.config/umbriel/shaders/community/animation/shattered-glass/`, keeping the [MIT license](../../LICENSES/Barrulus-MIT.txt). Merge [config.toml](config.toml) into your Umbriel configuration:

```toml
[include]
files = ["shaders/community/animation/shattered-glass/effect.toml"]

[animation]
enabled = true

[animation.windows_in]
enabled = true
effect = "shattered-glass"
duration_ms = 900
curve = "linear"

[animation.windows_out]
enabled = true
effect = "shattered-glass"
duration_ms = 800
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

Edit the existing `[effects.preset."shattered-glass"]` table in [effect.toml](effect.toml).
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
| `[animation.windows_in]` | `900` ms | `"linear"` |
| `[animation.windows_out]` | `800` ms | `"linear"` |

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
| `SHARD_FLIGHT` | `1.0` | Shard travel multiplier in shorter-window-side units; lower keeps shards nearer their origins. Try 0.6–1.4; the fracture topology stays fixed. |

Save and reload; see [reloading edits](../../README.md#reloading-edits).

### Additional tuning notes

Edit `SHARD_FLIGHT` in the shader to scale flight distances in shorter-window-side units; try 0.6–1.4 (default 1.0). The unequal polygon geometry is baked into the shader to avoid a per-fragment Voronoi search. Per-transition seeds vary movement, not the fracture topology. Artwork follows the theme palette; shader colour constants apply with `palette = false`.

## Compatibility and cost

Targets `animation.windows_in` and `animation.windows_out` with the Umbriel preset effects API and GLSL ES 1.00. Both visible endpoints return the original premultiplied sample; both hidden endpoints return transparent black. No previous-frame feedback or extra textures are used.

Up to 41 bounded shard candidates per fragment, with early culling, up to nine half-plane distances, and a texture sample only for covering fragments. This is the most expensive effect in the set. No hardware performance benchmark is claimed.

Shards are clipped at the original window bounds. The same seed follows the exact reverse trajectory; separate events receive separate seeds. The fixed fracture topology contains unequal convex polygons rather than a triangle grid.

WebGL checks covered compilation, transition endpoints and premultiplied alpha
over synthetic inputs. They do not verify native HDR, rotated or fractional-scale
outputs, interrupted transitions or hardware performance.

## Attribution

Author/contributor: Barrulus. Original implementation for this collection, 2026-09-29. License: [MIT](../../LICENSES/Barrulus-MIT.txt).
