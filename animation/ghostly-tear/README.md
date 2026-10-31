# Ghostly Tear

A ghost-lit hole opens at the exact centre of the screen and rips outwards
through the outgoing workspace. Small holes perforate the fabric ahead of the
main opening, merge into it, and leave thin scraps that dissolve away. Pearl
white, pale mint and lavender blend along the frayed edges with a soft mist.
Both scenes stay in place, including their wallpaper, windows and shell surfaces.

![Ghostly Tear in a private headless Umbriel session](preview.png)

[Watch the animated workspace switch](preview.gif) at the configured 1200 ms speed.
These are real headless compositor captures over two populated synthetic
workspaces, with sample wallpaper and a panel.

## Use

Keep [effect.toml](effect.toml) and [shader.glsl](shader.glsl) together under
`~/.config/umbriel/shaders/community/animation/ghostly-tear/`, along with the
[license](../../LICENSES/Barrulus-MIT.txt). Merge [config.toml](config.toml)
into your configuration, appending to existing include lists and merging tables:

```toml
[include]
files = ["shaders/community/animation/ghostly-tear/effect.toml"]

[animation]
enabled = true

[animation.workspaces]
enabled = true
style = "reveal"
effect = "ghostly-tear"
duration_ms = 1200
curve = "linear"
```

Including the preset only registers it. The workspace selection activates it;
**`style = "reveal"` is required.**

## Tuning

Try `duration_ms = 900` for a faster tear or `1500` for a slower opening.
Keep `curve = "linear"` for the intended timing; the shader eases the expansion
internally. The centre stays fixed in either navigation direction. Seeded,
stationary noise keeps the reveal monotonic as progress advances and makes
reversed swipes retrace the same holes.

Edit the constants in [shader.glsl](shader.glsl):

| Constant | Default | Effect |
| --- | --- | --- |
| `RAGGEDNESS` | `1.0` | Tear and hole strength, clamped to `0`–`2`. Try `0.6`–`1.5`; zero gives a smooth aperture. |
| `GLOW_WIDTH` | `0.026` | Edge haze width as a fraction of the shorter output dimension; try `0.015`–`0.045`. |
| `INTENSITY` | `0.85` | Pale artwork strength, clamped to `0`–`1`; zero retains the torn reveal. |
| `PEARL`, `MINT`, `LAVENDER` | Pale RGB colours | Fixed colour blend, independent of the theme palette. |

## Compatibility and cost

Requires Umbriel's full-scene workspace reveal API with
`umbriel_sample_incoming`. Tested with **Umbriel 0.1.0 (`693b689`)**.
Exact endpoints return the outgoing scene at zero
and the incoming scene at one. The shader preserves premultiplied alpha and
uses the shorter output dimension to keep its centre opening unstretched.

Two scene samples and six bounded procedural-noise evaluations per fragment;
no feedback buffers or texture assets. Full-scene capture adds compositor cost.
Hardware performance, HDR and native fractional-scale or rotated output
composition have not been benchmarked.

## Attribution

Original shader by Barrulus, combining the centre-out
portal idea of Witching Hour with procedural fabric erosion inspired by
Workspace Burn. [MIT license](../../LICENSES/Barrulus-MIT.txt).
