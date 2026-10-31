# Fractal Trail

A compact, short-lived trail of crisp, brightly coloured nested fractal contours.

Two nested four-level inversion fields draw sharply defined coloured contours.
A narrow dark outline keeps the pattern visible on pale content. The colour
softly follows the theme palette, with a rainbow fallback.

Default cursor for [Psychedelic](../../families.toml). The trail is limited to
**120 logical pixels of path** and **0.30 seconds**.
It disappears when the pointer stops. Path length is capped even during fast
movement, using the same traversal as [Train Tracks](../train-tracks/).

![Fractal Trail in a headless Umbriel session](preview.png)

[Watch the motion and idle fade](preview.gif). Captures use synthetic sample
content and recorded pointer motion; GIF timing follows the captured intervals.

## Use

Save `effect.toml` and `shader.glsl` together under
`~/.config/umbriel/shaders/community/cursor/fractal-trail/`, retaining both licence
notices. Merge [config.toml](config.toml) into your configuration:

```toml
# Merge into existing tables and append to your include list.
[include]
files = ["shaders/community/cursor/fractal-trail/effect.toml"]

[effects]
cursor = "psychedelic.fractal-trail"
```

Append to existing include lists and merge existing tables. Including the preset
registers it; the cursor selector enables it. Refresh the plugin catalogue and
apply the family to select it alongside the other family effects.

## Tuning

Edit named controls in `shader.glsl`, not as extra preset TOML keys.

| Control | Default | Effect |
| --- | --- | --- |
| `TRAIL_LIFE` | `0.30` seconds | Maximum lifetime; keep positive and at most two seconds. |
| `MAX_TRAIL_LENGTH` | `120.0` logical pixels | Maximum recent path length. The final 40% fades smoothly; keep positive. |
| `TRAIL_WIDTH` | `16.0` logical pixels | Half-width of the fractal band. |
| `INTENSITY` | `1.0` | Fractal contrast/opacity, clamped to 0–1. |

Set `palette = false` in `effect.toml` for the original colours. The preset's
`radius = 48` reserves space around the path; it does not set the trail length.

## Compatibility and cost

Requires Umbriel's cursor pointer-history API (`umbriel_pointer_path[64]`).
The newest samples are traversed first with six curve pieces per segment,
stopping at the length or lifetime limit. Large pointer warps are discarded.
History resets when crossing outputs, hiding the cursor or changing presets.

One background sample per pixel, with source alpha preserved. No previous-frame
feedback or continuously running time uniform. History requests frames while
samples remain. The compositor still retains its two-second path, so fast
movement can create a larger shaded rectangle than the visible short tail.
Two four-iteration fractal evaluations run only within the compact visible
trail, after the path search. The artwork has no blurred halo or feedback.

Compiled and captured with Umbriel `0.1.0 (a37ae93)` at scale 1. After
stopping, the capture matches the disabled effect within the short idle check.
HDR, rotated outputs and fractional scaling have not been visually verified.
No performance benchmark is claimed.

## Attribution

Original artwork by Barrulus. Path interpolation and bounded traversal adapted
from Train Tracks / Comet and the Noctalia trail shader. The fractal field is adapted from the Psychedelic family by Barrulus.
Retain the [Barrulus MIT](../../LICENSES/Barrulus-MIT.txt) and
[Noctalia MIT](../../LICENSES/Noctalia-MIT.txt) notices.
