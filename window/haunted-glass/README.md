# Haunted Glass — Claw Strike

Three hooked talons press against the inside of the pane, denting the window
content around their tips. They rake sideways in a quick diagonal strike,
leaving three deep grooves and branching fractures. The claws retreat, the
cracks slowly heal, and the window has a quiet interval before the next attack.
The attack changes position and direction between cycles.

![Claw strike on the window](preview.png)

[Watch the full attack cycle](preview.gif). These previews use a private headless
Umbriel session over synthetic light/dark content. The GIF samples a twelve-second
cycle at 20 fps. It may begin partway through an attack because the shader uses
the continuous compositor clock.

Part of [Umbriel After Dark](../../families.toml). This replaces Ghost Scratch
while retaining the `after-dark.haunted-glass` preset name and installation paths.

## Use

Keep [effect.toml](effect.toml) and [shader.glsl](shader.glsl) in
`~/.config/umbriel/shaders/community/window/haunted-glass/`.
Merge [config.toml](config.toml) into your configuration, appending include paths
and merging existing tables. Existing After Dark configurations need only the
replacement shader.

## Configuration options

| Constant | Default | Meaning |
| --- | --- | --- |
| `INTENSITY` | `0.90` | Talon and fracture opacity, 0–1. |
| `ATTACK_SIZE` | `120.0` | Logical-pixel scale, reduced automatically to fit small windows. Try 80–150. |
| `CYCLE_SECONDS` | `12.0` | Time between attacks. Keep at least 10 seconds. |
| `PRESS_DEPTH` | `7.0` | Glass distortion in logical pixels. Set 0 to remove the pressure/ripple distortion. |

Claws emerge during the first second. Pressure builds until a half-second rake
at 1.7–2.2 seconds. The claws retreat by 2.85 seconds; fractures heal between
4 and 8.4 seconds. Both the cuts and their forks are tied to the talon paths,
so damage never appears ahead of the strike. The pressure and impact ripple
affect the underlying content in a local area; window geometry does not move.

## Compatibility and cost

Requires Umbriel’s preset-effects API. Uses two source samples in the attack
area, up to 36 talon curve segments, 36 slash segments and 12 forked fractures.
Pixels outside that area or during the quiet interval return unchanged. Source
alpha is preserved; the displaced colour is remapped to that alpha. There are
no previous-frame feedback textures or frame-rate-dependent damage trails.

Tested with Umbriel 0.1.0 (`1d01b3a`): compilation, private compositor capture
and 1,008 supplemental software-GLES cases covering time, wide/tall/tiny sizes,
scale, dark/light content and transparent/translucent/opaque input. Checks cover
premultiplication, source alpha, unchanged borders and a completely clear quiet
interval. Hardware performance has not been benchmarked.

## Attribution

Original procedural artwork by Barrulus.
[MIT license](../../LICENSES/Barrulus-MIT.txt).
