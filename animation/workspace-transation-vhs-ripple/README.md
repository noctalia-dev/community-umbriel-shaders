# Workspace VHS Ripple

A ripple with strong VHS tracking bands, horizontal jitter, RGB separation,
scanlines, and noise over the native workspace slide. The distortion peaks
mid-transition and returns to the original image at both endpoints.

![Synthetic midpoint of Workspace VHS Ripple](preview.png)

Synthetic render of this shader over a desktop illustration at 50% progress.
It illustrates the distortion, not the compositor's workspace movement.

## Use

Save [effect.toml](effect.toml) and [shader.glsl](shader.glsl) together in
`~/.config/umbriel/shaders/community/animation/workspace-transation-vhs-ripple/`,
keeping the [MIT license](../../LICENSES/Barrulus-MIT.txt).
Merge [config.toml](config.toml) into your Umbriel configuration:

```toml
# Merge into your config; append includes and do not duplicate tables.
[include]
files = ["shaders/community/animation/workspace-transation-vhs-ripple/effect.toml"]

[animation]
enabled = true

[animation.workspaces]
enabled = true
effect = "workspace-transation-vhs-ripple"
duration_ms = 600
curve = "easeout"
```

Append the include to your existing `files` array and merge existing tables;
do not duplicate them. Including the preset registers it; selecting it under
`animation.workspaces` enables it globally for workspace switching.
The identifier intentionally uses the `workspace-transation-` prefix.

## Configuration options

Edit the existing `[effects.preset."workspace-transation-vhs-ripple"]` table in [effect.toml](effect.toml).
The [complete configuration reference](../../README.md#configuration-reference) explains
selection, overrides, and accepted ranges. The values below are this preset's shipped
settings, including defaults for omitted keys.

| TOML setting | Shipped value | What changing it does |
| --- | --- | --- |
| `kind` | `"animation"` | Keep this kind: the source implements its `animation` entry point. |
| `shader` | `"shader.glsl"` | Loads the source beside this preset; change the path only when using another compatible source. |
| `palette` | `false` | This source does not read the palette; enabling it alone does not recolour the effect. |

Edit the event tables in your main Umbriel configuration (the activation
example is [config.toml](config.toml)). Larger `duration_ms` gives a slower
transition. Both `[animation] enabled` and the event must be enabled.

| Event | Example duration | Example curve |
| --- | --- | --- |
| `[animation.workspaces]` | `600` ms | `"easeout"` |

Use `effect = ""` to clear the custom selection or event `enabled = false`
to disable the transition. Spring curves choose their own duration.
This shader uses linear progress: changing easing does not reshape its internal phases.
Opening/closing `style` and `scale` do not tune a working custom shader.
There is no animation-preset TOML `speed`; use event timing.

### Shader controls

Edit these values in [shader.glsl](shader.glsl), not in TOML. `#define` is
active GLSL code; comments use `//` or `/* ... */`. Start with small changes
and keep paired shaders in sync. Keep size and duration divisors positive.

| GLSL control or expression | Shipped value | Visual effect |
| --- | --- | --- |
| `wave displacement` | `0.030` | UV displacement amplitude; lower makes a gentler ripple. |
| `tracking / jitter` | `0.080 / 0.015` | UV displacement strengths; lower reduces band tearing / line jitter. |
| `colour split` | `0.006 + 0.012 * band` | Base and tracking-band red/blue displacement; lower reduces colour fringing. |
| `scanline / band darkening` | `0.14 / 0.22` | Lower reduces dimming during the switch. |
| `noise brightness` | `0.065` | Lower reduces added brightness noise. |

Save and reload; see [reloading edits](../../README.md#reloading-edits).

## Tuning

The default is 600 ms. Increase `duration_ms` to slow the transition.
`curve` controls the native slide; the distortion follows linear timeline
progress. Spring curves choose their own duration.

In `shader.glsl`, `0.030` controls ripple displacement, `0.080` the tracking
shift, and `0.015` the jitter, all as fractions of the capture dimensions.
The `0.006 + 0.012 * band` expression controls colour separation.
Reduce these values for a subtler result. The shader does not use theme colours.

## Compatibility and cost

Uses Umbriel's preset animation API and GLSL ES 1.00. It postprocesses the
combined workspace view during the built-in slide, rather than independently
rendering outgoing and incoming workspaces. Both endpoints sample the original
input exactly. Intermediate frames retain the displaced central sample's alpha.
Colour processing is SDR-clamped; HDR colour fidelity has not been validated.

Three texture samples per intermediate fragment, no loops, and no previous-frame
feedback. It only runs during the transition. Full-workspace capture cost depends
on output size and inner effects; no performance benchmark is claimed.

The original `workspace-ripple` preset was compiled and tried in a live desktop
session using `umbriel 0.1.0 (e5056a594c3b-dirty)` on 2026-10-01; its stronger
VHS settings were accepted by the contributor. This package preserves that shader
apart from attribution comments and the preset name.

## Attribution

Author/contributor: Barrulus. Original implementation,
2026-10-01. License: [MIT](../../LICENSES/Barrulus-MIT.txt).
