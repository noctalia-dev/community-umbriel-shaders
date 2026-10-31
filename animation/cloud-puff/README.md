# Cloud Puff

A quick, outward-billowing cloud puff for window opening and closing. Bright
gold, magenta and cyan backlighting rolls through the folds, much stronger
than the persistent Firelit Clouds window shader. Opening reveals the window
through the puff; closing lets the window disappear into it before it disperses.

![Cloud Puff opening](preview-open.png)

[Opening animation](preview-open.gif) · [Closing animation](preview-close.gif).
Native headless captures over synthetic content, recorded in 25 ms clock steps.
GIFs include short pauses before and after the effect.

## Use

Merge [config.toml](config.toml) into your existing configuration. It registers
`diwali.cloud-puff` and selects it for `animation.windows_in` and
`animation.windows_out`, at **650 ms opening** and **550 ms closing**, both
using a linear curve. Do not duplicate existing TOML tables.

## Tuning

Edit the constants at the top of [shader.glsl](shader.glsl):

| Control | Default | Meaning |
| --- | --- | --- |
| `INTENSITY` | `1.0` | Cloud opacity, from 0 to 1; zero retains the content transition. |
| `LIGHTING` | `1.35` | Strength of the coloured backlighting, from 0 to 2. |
| `CLOUD_SIZE` | `105.0` | Logical pixels per billow; larger makes broader folds. |

Duration belongs in the animation event configuration. The shader uses linear
progress and a stable per-event seed; it does not depend on the desktop clock.
The puff stays within the captured window silhouette, including its alpha.
There is no animation padding control for artwork beyond that captured region.

## Validation and cost

Tested in **Umbriel 0.1.0 (`8449975`)** on 2026-10-24. Opening and closing
compile and render in private sessions using the native frozen clock. Opening
starts empty and finishes at the normal scene; closing finishes fully empty.
The closing start preserves client pixels exactly; its decorated boundary has
the compositor's observed snapshot rounding of at most 3/255.

720 software GLES frames cover both directions, three sizes, scale 1/1.5,
transparent/translucent/opaque inputs, two seeds, endpoints, intermediate
progress and out-of-range progress. Alpha never exceeds the source silhouette,
SDR output stays premultiplied, and endpoint pixels match exactly. Another
164 black/white-source frames verify that visible source content only increases
on opening and only decreases on closing, without briefly reappearing.

One source sample and twelve procedural noise evaluations per pixel, only while
the transition runs. No feedback buffers or external textures. Native HDR,
rotation/fractional scaling, interrupted lifecycle transitions and hardware
performance remain unverified.

Original shader by Barrulus, using the Firelit Clouds
noise helpers. [MIT license](../../LICENSES/Barrulus-MIT.txt).

## Related Diwali effects

- [Diya Lights border](../../border/diya-lights/README.md).
- [Diya Glow companion overlay](../../window/diya-glow-overlay/README.md).
- [Firelit Clouds window effect](../../window/firelit-clouds/README.md).
- [Festival Sparks cursor effect](../../cursor/festival-sparks/README.md).
- [Rangoli Iris workspace reveal](../../animation/rangoli-iris/README.md).

Each effect has its own activation example. Diya Lights includes Diya Glow
automatically; do not include or select the overlay separately.
