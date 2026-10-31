# Candle Snuff

A quick dim and fade with a small orange-to-green edge flicker, confined to the departing window. Part of [Umbriel After Dark](../../families.toml).

![Candle Snuff headless preview](preview.png)

Preview: private headless Umbriel capture over synthetic light/dark content.
A still frame cannot demonstrate the motion or the complete family together.

[Animated compositor preview at the configured speed](preview.gif)

## Use

Save [effect.toml](effect.toml) and [shader.glsl](shader.glsl) in
`~/.config/umbriel/shaders/community/animation/candle-snuff/`. Merge [config.toml](config.toml)
into your main configuration, appending includes and merging existing tables.
Selects `after-dark.candle-snuff`. Including a preset only registers it.
To apply the family together, choose **After Dark → Apply family** in the plugin.

## Configuration options

Edit the named constants at the top of `shader.glsl`. INTENSITY = 0.95 (0–1); EDGE_WIDTH = 8 logical pixels (3–12). Closing duration = 240 ms; try 180–300 ms.

Colours use the family's fixed pumpkin orange, witch green and charcoal purple;
they are independent of the desktop theme. Intensity zero removes the decorative
colour; animation visibility still follows its timeline. Save edits to reload.

## Compatibility and cost

Requires Umbriel's preset-effects API. Designed for windows_out and a busy workspace: content fades by 78% of the timeline and the edge flicker ends by 95%. No particles, geometry changes or afterimage. Five source samples (including silhouette detection), linear event progress, no feedback. Exact endpoints are unchanged source and transparent; reverse selection also has valid endpoints.
 Hardware performance is not benchmarked.

The supplied preview does not verify HDR, rotated outputs or fractional scaling.

## Attribution

Original shader by Barrulus, inspired by Umbriel's playful
Halloween icon. No raster assets are required.
License: [Barrulus MIT](../../LICENSES/Barrulus-MIT.txt).
