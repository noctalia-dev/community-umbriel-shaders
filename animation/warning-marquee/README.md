# Warning marquee (experimental)

Yellow and black hazard stripes highlight only the border gaining focus.

![Illustrative shader preview](preview.png)

## Try it

Unpublished experiment (`publish = false`), available through the plugin's local-checkout catalogue mode. Include [effect.toml](effect.toml), then merge [config.toml](config.toml) into existing Umbriel tables and append to your include list. The configuration selects only `animation.border`, enables its master/event switches, and uses a deliberately bold 800 ms linear transition. Choose one preset per slot; including its definition alone does not select it.

Targets latest Umbriel with the `animation.border` custom effect slot and the documented animation GLSL inputs. Only the native border ring is shaded. A wider border makes the diagonal stripes easier to see.

## Tune

Edit `STRIPE_WIDTH_PX` in [shader.glsl](shader.glsl); suggested range: 12–48 logical pixels. Adjust `duration_ms` (try 500–900 ms) in your configuration. Linear timing makes the experiment easy to inspect; a duration-based easing curve can be substituted. Trigger a fresh transition after shader reload.

## Cost and validation

1 texture sample per fragment, bounded arithmetic, no feedback buffers, extra textures, audio or pointer inputs. Returns premultiplied RGBA. Bright accents may exceed SDR white. Transparent samples remain transparent.

Validated with Umbriel 0.1.0 (`11c3a82`): activation configuration and combined definitions pass. All ten shaders compile under Mesa llvmpipe GLES; 420 offscreen cases across the batch cover both directions, clamped overshoot, exact endpoints and transparent/partial-alpha input.

Preview: actual GLSL rendered offscreen over synthetic content and visually inspected, not an Umbriel compositor capture. Native slot appearance, interrupted transitions, HDR, rotation, fractional scaling and hardware performance require live testing. This experiment is deliberately exaggerated.

## License

Original shader by Barrulus, Copyright (c) 2026 Barrulus, MIT. Retain [the license notice](../../LICENSES/Barrulus-MIT.txt).


## Focus direction

Runs only while gaining focus (`umbriel_direction > 0`). Losing focus returns the unmodified target so the outgoing border keeps its native colour transition. Both native focus transitions still run; this shader adds its treatment to only one side. Directional previews show losing focus on the left and gaining focus on the right, at progress 0.5.

The directional update is checked by compiling the GLSL under Mesa llvmpipe GLES and testing both directions, endpoints, clamped overshoot and transparent/partial-alpha targets. This is offscreen validation, not live compositor testing.
