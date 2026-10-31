# Pumpkin Parade — inward overlay

The inward portion of the [Pumpkin Parade border](../../border/somethings-watching/):
twisting vines, growing jack-o’-lanterns, blinking cat eyes and marching skeletons.
Its artwork uses the same client-relative geometry and clock as the outer border,
so characters and stems can cross the window edge continuously.

![Inward vines and pumpkins](preview.png)

Private headless compositor capture over synthetic content.
[Full coupled animation preview](../../border/somethings-watching/preview.gif).

## Use and tuning

This preset is included and selected automatically by the border. Keep its
`effect.toml` and `shader.glsl` in `window/somethings-watching-overlay/`, alongside
the border directory layout. Merge [config.toml](config.toml) to enable the border;
do not additionally include this preset or select it as your general window effect.

Edit shared constants in **both** shaders. Controls and validation are documented
in the [border README](../../border/somethings-watching/). The overlay preserves
source alpha and returns the centre unchanged beyond its 70-pixel edge band.
It uses one source texture sample and bounded procedural drawing with no feedback.

The companion follows border focus and works alongside an independently
selected window effect.

## Attribution

Original procedural artwork by Barrulus.
[MIT license](../../LICENSES/Barrulus-MIT.txt).
