# Firelit Clouds

Gentle cloud banks billow across the window. Unseen fireworks illuminate them
from behind with changing amber, rose, blue, violet and green light. Each pulse
brightens quickly, blooms again more softly, then fades; thicker folds stay
shadowed while thinner cloud carries the colour. Cloud motion is independent
of the light pulses.

![Firelit Clouds](preview.png)

[Eight-second animated preview](preview.gif) · [With Diya Lights](preview-with-diyas.png).
Native headless Umbriel captures over synthetic light/dark content at scale 1.

## Use

Merge [config.toml](config.toml), following the [collection instructions](../../README.md#install).
Select `diwali.firelit-clouds` as the window effect. The Diya Lights border
companion remains separate and works alongside this window effect.

Clouds cover the entire window, including the centre. They are translucent and
preserve source alpha, with no displacement of text or images. As a standalone
window effect, this also runs on fullscreen windows.

## Tuning

Edit the constants at the top of [shader.glsl](shader.glsl):

| Control | Default | Meaning |
| --- | --- | --- |
| `INTENSITY` | `0.48` | Cloud coverage; zero returns the original content. |
| `CLOUD_SPEED` | `0.045` | Gentle rolling rate; zero freezes cloud shapes. |
| `CLOUD_SIZE` | `190.0` | Logical pixels per broad billow; larger means broader clouds. |
| `FLASH_STRENGTH` | `1.0` | Coloured backlight, from 0 to 2; zero leaves quiet clouds. |
| `FLASH_SPEED` | `0.85` | Pulse timing; zero holds the opening illumination. |

These are GLSL controls, not TOML settings. The default pulse spacing is about
2.6 seconds, with a soft tail and occasional overlap. Set both speed controls
to zero to freeze the entire scene. Combined cloud opacity is capped at 0.65.

## Validation and cost

Tested in **Umbriel 0.1.0 (`8449975`)** on 2026-10-24. Native compilation and
96 recorded frames verify visible motion across the whole window, including
the centre. A paired capture includes the Diya Lights border and its overlay.

324 software GLES frames cover three sizes, three corner configurations,
scale 1/1.5, transparent/translucent/opaque input, and six clocks including
24 hours. Source alpha and SDR premultiplication pass. Zero intensity returns
unchanged content; both clocks at zero freeze the result. Separate checks
confirm that clouds move with flashes disabled and flashes animate with
cloud geometry frozen.

One scene sample, thirteen procedural noise evaluations and four light slots
per pixel. This is an animated pass over the full selected window, with no
feedback buffers, blur kernels or external textures. Hardware performance and
native HDR/rotation/fractional scaling remain unverified.

Original shader by Barrulus.
[MIT license](../../LICENSES/Barrulus-MIT.txt).

## Related Diwali effects

- [Diya Lights border](../../border/diya-lights/README.md).
- [Diya Glow companion overlay](../../window/diya-glow-overlay/README.md).
- [Festival Sparks cursor effect](../../cursor/festival-sparks/README.md).
- [Cloud Puff opening and closing](../../animation/cloud-puff/README.md).
- [Rangoli Iris workspace reveal](../../animation/rangoli-iris/README.md).

Each effect has its own activation example. Diya Lights includes Diya Glow
automatically; do not include or select the overlay separately.
