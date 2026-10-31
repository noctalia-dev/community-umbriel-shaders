# Blossom Trail

Two slender vines twist along the recent pointer path. Cream, pink and lilac
flowers bloom on the stems, detach, then flutter downward with loose petals.
Like [Train Tracks](../train-tracks/), the trail is limited to **150 logical
pixels of path** and **0.45 seconds**. Flowers bloom and detach earlier to
fit the short tail, and the artwork fades away when movement stops.

Part of [Flowering Vine](../../families.toml). The family intentionally has
no screen or movement default.

![Blossom Trail in a headless Umbriel session](preview.png)

[Watch the vines, falling flowers and idle fade](preview.gif). Capture timing
follows the recorded pointer motion and frame intervals.

The preview is a real compositor capture over synthetic sample content.

## Use

Save `effect.toml` and `shader.glsl` together under
`~/.config/umbriel/shaders/community/cursor/blossom-trail/`, retaining the licence notices.
Merge [config.toml](config.toml) into your configuration:

```toml
# Merge into existing tables and append to your include list.
[include]
files = ["shaders/community/cursor/blossom-trail/effect.toml"]

[effects]
cursor = "flowering-vine.blossom-trail"
```

Append to existing include lists and merge existing tables. Including the
preset registers it; the selector enables it. Choose **Flowering Vine →
Apply family** in the plugin to select the coordinated defaults.

## Tuning

Edit named controls in `shader.glsl`; edit event timing in your main
configuration. These are not extra preset TOML keys.

| Control | Default | Effect |
| --- | --- | --- |
| `TRAIL_LIFE` | `0.45` seconds | Maximum lifetime, matching Train Tracks. Keep positive and at or below the two-second retained history. |
| `MAX_TRAIL_LENGTH` | `150.0` logical pixels | Maximum recent path length, matching Train Tracks. The final 40% fades smoothly. Keep positive. |
| `VINE_WIDTH` | `1.6` logical pixels | Stem half-width; keep above the antialias width for a solid core. |
| `BLOSSOM_SIZE` | `8.0` logical pixels | Base flower radius. |
| `FLOWER_INTERVAL` | `0.08` seconds | Flower spacing in time. Keep positive and choose a divisor of 60, such as 0.06, 0.08 or 0.12, for a continuous birth-phase wrap. |

The flower colours softly follow the theme palette. Set `palette = false`
in `effect.toml` for the original cream, pink and lilac flowers. Green stems
and leaves keep their botanical colours.

## Compatibility and cost

Requires the cursor pointer-history API (`umbriel_pointer_path[64]`). The preset
uses 64 logical pixels of padding around the retained path, separate from
the 150-pixel path limit. Falling petals can drift beyond the vine itself. Output edges clip the artwork. Large
pointer warps and stationary segments are skipped. History resets when
crossing outputs, hiding the cursor or changing presets.

One source sample per pixel, at most 64 history segments, two stems with six
curve pieces per segment, and one flower per emission boundary. Distance
rejection limits the expensive work. Reading history requests frames only
while samples remain; no continuously running time uniform or feedback buffers.
The compositor retains its two-second history even though this shader draws
only the short tail, so fast motion can still produce a large shaded rectangle.

Compiled and captured with Umbriel `0.1.0 (a37ae93)` at scale 1.
After the history expires, the captured result matches the disabled effect.
HDR, rotated outputs and fractional scaling have not been visually verified.
No performance benchmark is claimed.

## Attribution

Original botanical artwork by Barrulus. Time-weighted curve interpolation is
adapted from [Witchfire](../witchfire/), Comet and the Noctalia trail shader.
The length-limited traversal follows [Train Tracks](../train-tracks/).
Retain both the [Barrulus MIT](../../LICENSES/Barrulus-MIT.txt) and
[Noctalia MIT](../../LICENSES/Noctalia-MIT.txt) notices.
