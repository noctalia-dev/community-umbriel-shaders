# Frayed Veil

Three long pearl, mint and lavender fabric strips follow the pointer path.
Connected ribbons flutter locally, with ragged edges and irregular perforations
that leave fine attached threads as the veil dissolves.

![Frayed Veil over synthetic light/dark content](preview.png)

[Watch the animated cursor preview](preview.gif). The previews are real private
headless compositor captures, with a figure-eight pointer path followed by a
stop. The pointer image is omitted so the artwork is visible. GIF timing uses
real pointer timestamps and approximately 80 ms captures.

## Use

Keep [effect.toml](effect.toml) and [shader.glsl](shader.glsl) together under
`~/.config/umbriel/shaders/community/cursor/frayed-veil/`. Retain the license notices
linked below. Merge [config.toml](config.toml) into your configuration, appending
to the include list and merging existing tables:

```toml
[include]
files = ["shaders/community/cursor/frayed-veil/effect.toml"]

[effects]
cursor = "frayed-veil"
```

Including the preset registers it; selecting it activates it. Choose one cursor
effect at a time. It pairs with the Ghostly Tear workspace transition, border
and window animations, using the same fixed pearl, mint and lavender colours.
The theme palette does not change these colours.

## Tuning

Edit constants in [shader.glsl](shader.glsl):

| Constant | Default | Effect |
| --- | --- | --- |
| `TRAIL_LIFE` | `1.15` | Trail lifetime in seconds; try `0.8`–`1.5`. Keep positive and at most the retained two seconds. |
| `MAX_LENGTH` | `240.0` | Maximum retained path length in logical pixels; try `180`–`320`. The last 40% fades smoothly. |
| `STRENGTH` | `0.95` | Artwork opacity, clamped to `0`–`1`; lower for a softer effect. |
| `PEARL`, `MINT`, `LAVENDER` | Pale RGB colours | Shared colour blend. |

The first three logical pixels around the pointer stay clear, reaching full
artwork strength at eight pixels. The moving ribbon ends at the newest path
sample without projecting a line ahead of it. Artwork preserves the underlying alpha and
does not distort the desktop or replace the pointer image.

The ribbons disappear completely after movement stops and their lifetime
expires. They use retained sample ages, without a continuous animation clock.
Their folds vary smoothly along the path; tight turns can overlap strips.

`radius = 104` in [effect.toml](effect.toml) reserves padding around the retained
path, containing its curvature and up to 20 pixels of side detail. It is not a
painted halo. Keep this padding when using the suggested length range.

## Compatibility and cost

Tested with **Umbriel 0.1.0 (`693b689`)**. Requires the extended cursor API:
`umbriel_pointer_path[64]`, `umbriel_pointer_count`, sample ages and stable birth
phases. No previous-frame feedback buffers or texture assets are used.

One source sample per fragment. Up to 63 retained segments are visited newest
first, with six subdivisions for curved distance and length, early age/length
termination and per-pixel distance rejection. Stationary samples and jumps over
800 logical pixels are skipped. Fast, sparsely sampled sweeps still respect the
length limit. The compositor retains up to two seconds of path history, so the
affected rectangle can grow during long movements beyond the visible tail.

Native HDR, fractional-scale and rotated output composition and hardware
performance remain unverified.

## Attribution

Original artwork by Barrulus. Time-aware path interpolation
adapted from this collection's [Train Tracks](../train-tracks/) and
[Comet](../comet/), originating in Noctalia's trail-path implementation.
Licenses: [Barrulus MIT](../../LICENSES/Barrulus-MIT.txt) and
[Noctalia MIT](../../LICENSES/Noctalia-MIT.txt).
