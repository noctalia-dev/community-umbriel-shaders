# Diya Lights

Small terracotta oil lamps straddle the focused window's edge, approximately
half inside and half outside. They remain upright around rounded corners and
are about 14 logical pixels across.
Three multicoloured lights fill each gap, twinkling independently with short
star-shaped glints. Warm flames sway gently above gold-edged bowls.

![Diya Lights with coloured sparkling lights](preview.png)

[Animated preview](preview.gif). Native headless capture over synthetic content.
Screen-edge examples: [top and left](preview-top_left.png),
[bottom and right](preview-bottom_right.png). The outward halves clip at the
screen edge; the matching inward artwork stays visible on the window.

## Use and tuning

Merge [config.toml](config.toml), following the [collection instructions](../../README.md#install).
Select `diwali.diya-lights` as the border.
The border automatically includes [Diya Glow](../../window/diya-glow-overlay/README.md).
Keep both directories in their relative locations and do not select the overlay separately.

Edit the constants in [shader.glsl](shader.glsl) and make the same changes in
the [companion shader](../../window/diya-glow-overlay/shader.glsl). Keep the shared
`diya_*` artwork helpers and constants identical in both files so lamp centres,
colours and flicker stay aligned across the client edge.

- `LAMP_SPACING = 72.0`: approximate logical pixels between lamps; try 56–96.
- `LAMP_SCALE = 0.60`: size relative to the original 23-pixel-wide lamp.
- `INTENSITY = 0.98`: artwork opacity, from 0 to 1.
- `REACH = 14.0`: hard bound on each side; only the soft halo reaches this far.

Keep `padding = 16` for this geometry. The preset's `speed` and `animated`
settings control both halves, including the coloured twinkles. The overlay
preserves source alpha and leaves content beyond 14 pixels inside untouched.
Both effects follow border eligibility and disappear in fullscreen.

## Compatibility and cost

Tested in Umbriel 0.1.0 (`8449975`).
Native captures verify flame motion, unchanged centre pixels, fullscreen gating
and visibility at output edges. Software GLES checks cover 144 border frames
and 216 overlay frames.

Each material evaluation checks three nearby lamps and three nearby light
positions. The border reserves 16 logical pixels of padding. Its companion
adds a window pass for the eligible focused window, returning immediately
outside the shallow inner fringe. No native border-light or feedback passes
are used. Hardware performance and native HDR/rotation/fractional scaling
remain unverified.

Original artwork by Barrulus; perimeter geometry adapted
from Barrulus's Fairy Lights and Ghostly Tear Border.
[MIT license](../../LICENSES/Barrulus-MIT.txt).

## Related Diwali effects

- [Diya Glow companion overlay](../../window/diya-glow-overlay/README.md).
- [Firelit Clouds window effect](../../window/firelit-clouds/README.md).
- [Festival Sparks cursor effect](../../cursor/festival-sparks/README.md).
- [Cloud Puff opening and closing](../../animation/cloud-puff/README.md).
- [Rangoli Iris workspace reveal](../../animation/rangoli-iris/README.md).

Each effect has its own activation example. Diya Lights includes Diya Glow
automatically; do not include or select the overlay separately.
