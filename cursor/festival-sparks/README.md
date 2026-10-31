# Festival Sparks

Fine gold sparks and occasional rose accents fan out from the pointer's recent
path and lift gently. A clear area around the pointer preserves its visibility;
the trail fully fades after movement stops.

![Festival Sparks](preview.png)

[Motion and rest preview](preview.gif). Native headless capture over synthetic content.

## Use and tuning

Merge [config.toml](config.toml), following the [collection instructions](../../README.md#install).
Select `diwali.festival-sparks` as the cursor effect. The effect decorates the surrounding scene, not the cursor image.

Edit constants near the top of [shader.glsl](shader.glsl):

| Control | Default | Meaning |
| --- | --- | --- |
| `TRAIL_LIFE` | `1.45` | Seconds; try 0.8–1.6, below the two-second history limit. |
| `INTENSITY` | `0.95` | Spark opacity, from 0 to 1. |
| `DENSITY` | `0.82` | Fraction of eligible samples emitting paired sparks, from 0 to 1. |
| `LIFT` | `22.0` | Upward drift in logical pixels per second; try 10–28. |

These are GLSL constants. The preset's `radius = 64` surrounds the retained
path and accommodates the ranges above. Larger lift/lifetime values may need
more padding. Stationary segments and jumps over 180 logical pixels are ignored,
so very fast movement can leave gaps.

## Compatibility and cost

Requires `umbriel_pointer_path[64]`, with sample ages and stable birth phases.
Tested in Umbriel 0.1.0 (`8449975`).
Native compilation and 72 captured frames cover movement and rest; the expired
trail matches a disabled-effect baseline pixel for pixel. Another 432 software
GLES frames pass.

The shader checks at most 64 path samples and draws up to two sparks per eligible
sample, with early rejection outside their small bounds. Source alpha is
preserved. No feedback buffers or continuous idle clock are used; retained
history drives the fade. Long sweeps enlarge the drawn rectangle. Hardware
performance and native HDR/rotation/fractional scaling remain unverified.

Original artwork by Barrulus, using the stable-history
emission approach from Snowflake Trail.
[MIT license](../../LICENSES/Barrulus-MIT.txt).

## Related Diwali effects

- [Diya Lights border](../../border/diya-lights/README.md).
- [Diya Glow companion overlay](../../window/diya-glow-overlay/README.md).
- [Firelit Clouds window effect](../../window/firelit-clouds/README.md).
- [Cloud Puff opening and closing](../../animation/cloud-puff/README.md).
- [Rangoli Iris workspace reveal](../../animation/rangoli-iris/README.md).

Each effect has its own activation example. Diya Lights includes Diya Glow
automatically; do not include or select the overlay separately.
