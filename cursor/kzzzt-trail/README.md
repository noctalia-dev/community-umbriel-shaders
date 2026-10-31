# kzzzt Trail

A short circuit-board trail with angular branches, terminal pads and brief electric zap sparks.

Angular tracks branch from a fine central circuit, ending in hollow pads.
Brief blue-white zaps leap from the newest terminals. The default green traces
follow the theme accent when the palette is enabled.

Default cursor for [kzzzt](../../families.toml). The trail is limited to
**150 logical pixels of path** and **0.45 seconds**.
It disappears when the pointer stops. Path length is capped even during fast
movement, using the same traversal as [Train Tracks](../train-tracks/).

![kzzzt Trail in a headless Umbriel session](preview.png)

[Watch the motion and idle fade](preview.gif). Captures use synthetic sample
content and recorded pointer motion; GIF timing follows the captured intervals.

## Use

Save `effect.toml` and `shader.glsl` together under
`~/.config/umbriel/shaders/community/cursor/kzzzt-trail/`, retaining both licence
notices. Merge [config.toml](config.toml) into your configuration:

```toml
# Merge into existing tables and append to your include list.
[include]
files = ["shaders/community/cursor/kzzzt-trail/effect.toml"]

[effects]
cursor = "kzzzt-trail"
```

Append to existing include lists and merge existing tables. Including the preset
registers it; the cursor selector enables it. Refresh the plugin catalogue and
apply the family to select it alongside the other family effects.

## Tuning

Edit named controls in `shader.glsl`, not as extra preset TOML keys.

| Control | Default | Effect |
| --- | --- | --- |
| `TRAIL_LIFE` | `0.45` seconds | Maximum lifetime; keep positive and at most two seconds. |
| `MAX_TRAIL_LENGTH` | `150.0` logical pixels | Maximum recent path length. The final 40% fades smoothly; keep positive. |
| `TRAIL_WIDTH` | `19.0` logical pixels | Branch reach. |
| `TRACE_WIDTH` | `1.2` logical pixels | Circuit line half-width. |
| `NODE_INTERVAL` | `0.06` seconds | Time between terminal pads. Use a positive divisor of 60, such as 0.05 or 0.06. |

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
The bounded path search also draws angular branch stamps and brief sparks;
there is no audio dependency or continuous idle flicker.

Compiled and captured with Umbriel `0.1.0 (a37ae93)` at scale 1. After
stopping, the capture matches the disabled effect within the short idle check.
HDR, rotated outputs and fractional scaling have not been visually verified.
No performance benchmark is claimed.

## Attribution

Original artwork by Barrulus. Path interpolation and bounded traversal adapted
from Train Tracks / Comet and the Noctalia trail shader.
Retain the [Barrulus MIT](../../LICENSES/Barrulus-MIT.txt) and
[Noctalia MIT](../../LICENSES/Noctalia-MIT.txt) notices.
