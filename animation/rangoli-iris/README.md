# Rangoli Iris

A circular iris inspired by the user's floral reference: white petal outlines
on red, green and orange bands, surrounded by blue beads with white spirals.
A small medallion blooms at the centre, then opens to reveal the incoming
workspace. The patterned rings expand beyond the output edges.

![Rangoli Iris between two populated workspaces](preview.png)

[Animated preview](preview.gif) · [Reverse navigation](preview-reverse.gif) ·
[Over an empty workspace](preview-empty.png).
These are native headless Umbriel captures with synthetic windows, wallpaper
and a panel, recorded at 40 ms steps over the actual 1200 ms transition.

## Use

Merge [config.toml](config.toml) into existing tables and append its include
path. Select `diwali.rangoli-iris` for `animation.workspaces` with
`style = "reveal"`, `duration_ms = 1200` and `curve = "linear"`.

This is a full-scene workspace transition. `umbriel_sample` supplies the old
scene and `umbriel_sample_incoming` supplies the new one, including wallpaper,
windows and shell surfaces. It is not a persistent screen shader or a lifecycle
animation. Both scenes stay stationary while the aperture opens.

## Tuning

Edit constants in [shader.glsl](shader.glsl):

| Control | Default | Meaning |
| --- | --- | --- |
| `INTENSITY` | `0.98` | Opacity of the coloured ornament; zero leaves a plain circular iris. |
| `BAND_WIDTH` | `0.22` | Total ring width as a fraction of the shorter output dimension; clamped to 0.08–0.4. |
| `LINE_WIDTH` | `1.4` | White line width in logical pixels. |

The inner flower has 16 petals, followed by 20 green leaf loops, 24 orange
petals and 32 blue spiral beads. Colour and linework are procedural, without
external image textures. Duration belongs in the workspace event configuration.
Reversing progress retraces the same ornament and aperture exactly.

## Validation and cost

Tested with **Umbriel 0.1.0 (`8449975`)** on 2026-10-24. Both navigation directions
compile and render across 62 captured frames. Outgoing and incoming native
endpoints match their resting scenes exactly. An empty-workspace switch also
returns to its resting scene, and cancelling a native swipe restores the
original workspace pixel for pixel.

480 software GLES frames cover landscape/portrait/wide targets, scale 1/1.5,
transparent/translucent/opaque and differing scene alphas, two seeds, endpoint
overshoot and repeated/reversed progress. SDR premultiplication, alpha bounds
and exact two-scene endpoints pass. Another 162 source-comparison frames confirm
that outgoing content never reappears as the iris expands, including under
the ornament's antialiased inner edge.

Native compilation validates the installed compositor API; supplemental GLES
checks use a supplied full-scene two-texture wrapper.

Two scene samples per pixel, with ornament calculation restricted to the ring.
No previous-frame feedback or blur passes. Full-scene composition requires
scene captures. Hardware performance, native HDR, output rotation and native
fractional scaling remain unverified.

Procedural interpretation of the user-supplied reference by Barrulus; the reference bitmap is not bundled. Shader and helper code
use the [Barrulus MIT license](../../LICENSES/Barrulus-MIT.txt).

## Related Diwali effects

- [Diya Lights border](../../border/diya-lights/README.md).
- [Diya Glow companion overlay](../../window/diya-glow-overlay/README.md).
- [Firelit Clouds window effect](../../window/firelit-clouds/README.md).
- [Festival Sparks cursor effect](../../cursor/festival-sparks/README.md).
- [Cloud Puff opening and closing](../../animation/cloud-puff/README.md).

Each effect has its own activation example. Diya Lights includes Diya Glow
automatically; do not include or select the overlay separately.
