# Ink Drip

A wet ink stroke in the theme's primary accent follows the pointer. Beads fall a short distance,
flatten into irregular splotches, and scatter a few smaller spots before fading.
Small reflections give the fresh drops a wet surface.

Default cursor for [Paper](../../families.toml). The trail is capped at
**150 logical pixels of path** and **0.45 seconds**, matching the compact
[Train Tracks](../train-tracks/) reference. Droplets fall within that lifetime;
no stains remain on the desktop after the pointer stops.

![Ink Drip in a headless Umbriel session](preview.png)

[Watch the droplets, splotches and idle fade](preview.gif). Previews use
synthetic content; GIF timing follows the captured pointer-motion intervals.

## Use

Save `effect.toml` and `shader.glsl` together under
`~/.config/umbriel/shaders/community/cursor/ink-drip/`, retaining both licence
notices. Merge [config.toml](config.toml) into your configuration:

```toml
# Merge into existing tables and append to your include list.
[include]
files = ["shaders/community/cursor/ink-drip/effect.toml"]

[effects]
cursor = "paper.ink-drip"
```

Append to existing include lists and merge existing tables. Including the preset
registers it; the cursor selector enables it. Refresh the plugin catalogue and
apply Paper to select it alongside the family's other defaults.

## Tuning

Edit named controls in `shader.glsl`, not as extra preset TOML keys.

| Control | Default | Effect |
| --- | --- | --- |
| `TRAIL_LIFE` | `0.45` seconds | Maximum age; keep positive and no greater than the two-second history. Droplet and splotch phases scale with this lifetime. |
| `MAX_TRAIL_LENGTH` | `150.0` logical pixels | Maximum recent path length; the final 40% fades smoothly. Keep positive. |
| `STROKE_WIDTH` | `1.8` logical pixels | Half-width of the thin wet stroke. |
| `DROP_INTERVAL` | `0.075` seconds | Time between droplets; keep positive and use a divisor of 60. |
| `DROP_DISTANCE` | `20.0` logical pixels | Falling distance before each drop spreads. |
| `BLOT_SIZE` | `9.0` logical pixels | Maximum main-splotch radius. |

The default `palette = true` uses the full primary theme accent with pale wet
highlights so the ink stands out. Set `palette = false` for blue-black ink.
Keep the preset's
`radius` large enough for the falling distance, splatter and antialias margin
if increasing the artwork size. Radius controls padding, not path length.

## Compatibility and cost

Requires Umbriel's cursor pointer-history API (`umbriel_pointer_path[64]`).
The newest samples are visited first using six curve pieces per segment,
stopping at the path or lifetime limit. Large pointer warps are skipped.
History resets on output crossing, cursor hide and program changes.

One background sample per pixel. Bounded droplet stamps have one main stain
and four small satellite spots each, with early distance rejection. Source
alpha is preserved. No feedback buffers or continuously running clock.
The compositor retains two seconds of history, so fast movement can still
produce a larger shaded rectangle than the short visible artwork.

Compiled and visually checked in an isolated Umbriel **0.1.0 (a37ae93)**
software-rendered session. Motion captures exercise the droplets and splotches;
after stopping, the captured frame matches the effect-disabled frame exactly.

HDR, rotated outputs and fractional scaling have not been visually verified.
No performance benchmark is claimed.

## Attribution

Original ink artwork by Barrulus. Path interpolation and bounded traversal
adapted from Train Tracks / Comet and the Noctalia trail shader.
Retain the [Barrulus MIT](../../LICENSES/Barrulus-MIT.txt) and
[Noctalia MIT](../../LICENSES/Noctalia-MIT.txt) notices.
