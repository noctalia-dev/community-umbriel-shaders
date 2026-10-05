# Dual Orbit

A steady accent border with two brighter highlights travelling clockwise, half a perimeter apart. The highlights widen outside the native ring and fade into a soft halo.

![Synthetic preview of Dual Orbit](preview.png)

The preview renders the shader over a synthetic window. It shows the border pass without Umbriel's separate light blur.

## Use

Save [effect.toml](effect.toml) and [shader.glsl](shader.glsl) together in `~/.config/umbriel/shaders/community/border/dual-orbit/`. Keep the [license notice](../../LICENSES/neonvoidx-MIT.txt) with redistributed copies. See [installation](../../README.md#install) for details.

Merge the entries in [config.toml](config.toml) into your Umbriel config. Append the include path to an existing `[include].files` list and set `border = "dual-orbit"` in the existing `[effects]` table.

The effect appears on the focused, decorated window. Fullscreen and urgent windows do not display the border effect.

## Theme and tuning

`palette = true` uses `accent_primary` for the steady border and `accent_secondary` for both orbit highlights. Set those values in Umbriel's `[colors]` table; the shader requires a palette and has no built-in fallback. The preview uses green and cyan example accents.

Edit these settings in the existing `[effects.preset.dual-orbit]` table in [effect.toml](effect.toml):

| Setting | Shipped value | Effect |
| --- | --- | --- |
| `padding` | `12` | Outward drawing space and the reach of the steady border fade. Keep at least 8 to avoid clipping the orbit's wide band. |
| `speed` | `6.0` | Multiplies the shader's 100 logical pixels per second base travel rate. Use 0 to freeze; valid range is 0–10. |
| `palette` | `true` | Supplies the two accent colors. Keep enabled unless you add fallback colors to the shader. |

The `[effects.preset.dual-orbit.light]` table enables Umbriel's extra light blur. Its `spread = 24`, `intensity = 2.2`, and `threshold = 0.75` can be tuned or the whole table can be removed. The shader-painted band and halo remain when the light table is removed.

In [shader.glsl](shader.glsl), `48.0` controls the highlights' length along the perimeter; larger values make longer arcs. The `5.0` and `8.0` smoothstep limits set their outward band width, while the halo's `5.0` falloff controls its soft edge. Increasing either outward reach may require more `padding`.

## Compatibility and cost

Requires Umbriel's preset effects API introduced in [`512e2fb3`](https://github.com/noctalia-dev/umbriel/commit/512e2fb3). See [validation and limitations](../../VALIDATION.md). The shader uses one focused-border pass, no texture history, and the optional compositor light blur. It is animated at the configured effect frame rate. No performance benchmark is claimed.

## Attribution

Author/contributor: [neonvoidx](https://github.com/neonvoidx). License: [MIT](../../LICENSES/neonvoidx-MIT.txt).
