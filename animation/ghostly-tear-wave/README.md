# Ghostly Tear Wave

Opening begins along an uneven horizontal line near the window's centre.
Two ragged tear fronts sweep upward and downward, revealing the window between
them. Closing consumes the window from its top and bottom edges, bringing both
fronts inward until the remaining centre line dissolves. Small perforations,
pearl threads and soft mint/lavender wisps travel with the torn edges.

![Ghostly Tear Wave opening in a private compositor](preview.png)

[Watch opening](preview.gif) at 1100 ms, or [watch closing](preview-close.gif)
at 950 ms. These are real headless compositor captures over synthetic content,
sampled in 40 ms frozen-clock steps. The last sample can extend past the event.

## Use

Keep [effect.toml](effect.toml) and [shader.glsl](shader.glsl) together under
`~/.config/umbriel/shaders/community/animation/ghostly-tear-wave/`, retaining the
[license](../../LICENSES/Barrulus-MIT.txt). Merge [config.toml](config.toml)
into your configuration, appending to existing include lists and merging tables:

```toml
[include]
files = ["shaders/community/animation/ghostly-tear-wave/effect.toml"]

[animation]
enabled = true

[animation.windows_in]
enabled = true
effect = "ghostly-tear-wave"
duration_ms = 1100
curve = "linear"

[animation.windows_out]
enabled = true
effect = "ghostly-tear-wave"
duration_ms = 950
curve = "linear"
```

One preset handles both directions. Opening expands from the centre seam;
closing contracts towards it. The actual window geometry stays in place.
This is a window lifecycle animation; it does not use the workspace reveal API.

Pairs with [Ghostly Tear Border](../../border/ghostly-tear-border/) and the
[Ghostly Tear workspace transition](../ghostly-tear/). No companion is required
for the animation itself. Its fixed colours are independent of the theme palette.

## Tuning

Adjust the two event durations independently. Try 800/700 ms for a brisker
open/close pair. Keep `curve = "linear"` for the intended timing; the shader
eases the front expansion internally. Spring curves choose their own duration.

In [shader.glsl](shader.glsl):

| Constant | Default | Effect |
| --- | --- | --- |
| `RAGGEDNESS` | `1.0` | Strength of irregular tears and perforations, clamped to `0`–`2`; try `0.6`–`1.5`. Zero keeps the wavering centre seam with smooth fronts. |
| `WISP_WIDTH` | `18.0` | Edge-haze width in logical pixels, limited to 8% of the shorter window dimension on small windows; try `12`–`26`. |
| `INTENSITY` | `0.95` | Pale edge-artwork strength, clamped to `0`–`1`; zero keeps the tear mask. |
| `PEARL`, `MINT`, `LAVENDER` | Pale RGB colours | Colour blend shared with the matching border and workspace effect. |

The seam varies gently around the centre with a held transition seed. Tear
geometry stays fixed as progress changes, so opening only adds coverage and
closing only removes it. Reversing progress retraces the same fronts. Upper and
lower tears are independently irregular, rather than mirrored copies.

## Compatibility and cost

Tested with **Umbriel 0.1.0 (`693b689`)**. Uses the standard animation entry point,
progress, direction and random seed. Exact endpoints return the unmodified
source or transparent black as appropriate. Artwork is restricted to the
captured silhouette, with premultiplied alpha preserved; transparent margins
and cutouts remain transparent.

One source sample and six bounded noise evaluations per fragment; no feedback
buffers, extra texture assets or scene sampling. Native HDR, output rotation,
fractional-scale composition and hardware performance remain unverified.

## Attribution

Original shader by Barrulus, using the colours and fabric
erosion approach of Ghostly Tear. [MIT license](../../LICENSES/Barrulus-MIT.txt).
