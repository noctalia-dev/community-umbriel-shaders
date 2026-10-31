# Dappled Light

Soft leaf shadows sway over the window, with faint warm light in the gaps.
The low-contrast treatment leaves the content in place: text and images are
not warped. It works alongside the Flowering Vine border's inward overlay.

Part of [Flowering Vine](../../families.toml). The family intentionally has
no screen or movement default.

![Dappled Light in a headless Umbriel session](preview.png)

[Watch six seconds of the moving canopy](preview.gif).

The preview is a real compositor capture over synthetic sample content.

## Use

Save `effect.toml` and `shader.glsl` together under
`~/.config/umbriel/shaders/community/window/dappled-light/`, retaining the licence notices.
Merge [config.toml](config.toml) into your configuration:

```toml
# Merge into existing tables and append to your include list.
[include]
files = ["shaders/community/window/dappled-light/effect.toml"]

[effects]
window = "flowering-vine.dappled-light"
```

Append to existing include lists and merge existing tables. Including the
preset registers it; the selector enables it. Choose **Flowering Vine →
Apply family** in the plugin to select the coordinated defaults.

## Tuning

Edit named controls in `shader.glsl`; edit event timing in your main
configuration. These are not extra preset TOML keys.

| Control | Default | Effect |
| --- | --- | --- |
| `SHADOW_STRENGTH` | `0.10` | Maximum darkening from leaf shadows, clamped to 0–0.25. |
| `LIGHT_STRENGTH` | `0.025` | Warm light blend, clamped to 0–0.10. |
| `LEAF_SCALE` | `110.0` logical pixels | Canopy-cell size, with a lower bound of 30. |
| `BREEZE_SPEED` | `0.22` | Slow leaf motion; zero freezes the pattern. |

This effect uses fixed warm sunlight and neutral shadows; it does not read
the theme palette.

## Compatibility and cost

Uses Umbriel's window preset-effects API. Selecting it globally affects all
windows, including unfocused windows. The border companion remains a separate
pass and follows the border's focus gate. Source alpha is preserved and no
previous-frame samples are required.

One source sample and nine softly shaded canopy cells per pixel. No feedback
buffers. The time-driven window effect requests continuous frames while active.
It preserves source alpha without clamping the source image to SDR.

Compiled and captured with Umbriel `0.1.0 (a37ae93)` at scale 1.
HDR, rotated outputs and fractional scaling have not been visually verified.
No performance benchmark is claimed.

## Attribution

Original shader by Barrulus. License: [MIT](../../LICENSES/Barrulus-MIT.txt).
