# Vampire Wake

A vampire companion to [Witchfire](../witchfire/): a curved crimson ribbon fades
into burgundy wisps, with falling blood-red sparks and small fluttering bats
peeling away from the pointer's path. A faint wine-coloured halo remains at rest.
Pairs with [Vampire Blood Wash](../../animation/vampire-blood-wash/).

![Vampire Wake compositor preview](preview.png)

[Animated movement and fade preview](preview.gif). These are private headless
Umbriel captures over synthetic light and dark content. The cursor sprite itself
is omitted from the captures; the shader colours the scene underneath it.

## Use

Save [effect.toml](effect.toml) and [shader.glsl](shader.glsl) together under
`~/.config/umbriel/shaders/community/cursor/vampire-wake/`. Merge
[config.toml](config.toml) into your configuration:

```toml
[include]
files = ["shaders/community/cursor/vampire-wake/effect.toml"]

[effects]
cursor = "vampire-wake"
```

Append to existing include lists and merge existing tables. Including the preset
registers it; the cursor selector activates it. See [installation](../../README.md#install).

## Tuning

Edit the constants at the top of [shader.glsl](shader.glsl):

| Constant | Default | Suggested range / meaning |
| --- | --- | --- |
| `INTENSITY` | `0.88` | 0–1, trail and particle strength. |
| `TRAIL_LIFE` | `1.25` | 0.5–1.5 seconds of fading history. |
| `FLAME_WIDTH` | `9.0` | 4–14 logical pixels, ribbon width. |
| `BAT_SIZE` | `9.0` | 6–14 logical pixels, bat half-span; 0 disables bats. |
| `CRIMSON`, `WINE`, `SPARK`, `BAT` | Fixed colours | Ribbon, smoke, sparks and silhouettes. |

These are GLSL controls, not TOML parameters. No theme palette or audio is used.
The preset's `radius = 128` pads the retained pointer path; increase it if tuning
lifetimes or particle sizes beyond these ranges. Bat releases are limited to
eight per second and may be fewer with sparse or stationary pointer history.

## Compatibility and cost

Tested with Umbriel **0.1.0 (`2145668`)**. Requires the preset-effects and
64-point pointer-history APIs. The time-weighted curve uses Witchfire's twelve
subdivisions per segment to follow fast swirls smoothly. Stationary segments and
jumps over 800 logical pixels are ignored. History drives the fade; there are no
feedback buffers or external textures.

One source sample, up to 63 curve segments, twelve subdivisions per segment and
procedural bat silhouettes, with conservative distance rejection. Source alpha
is preserved. Effects clip at output edges and do not replace the cursor sprite.
Hardware performance, HDR and native rotated/fractional-scale output composition
have not been benchmarked.

## Attribution

Adapted from Witchfire by Barrulus. Curve interpolation
derives from Comet and Noctalia's bundled trail shader.
[Barrulus MIT](../../LICENSES/Barrulus-MIT.txt) and
[Noctalia MIT](../../LICENSES/Noctalia-MIT.txt).
