# Scratchpad fade

A gentle fade as scratchpad windows and their backdrops appear or disappear.

## Target and selection

Animation shader for `animation.scratchpad`: scratchpad windows and their dim/blur backdrops during showing and hiding. It is not a persistent window, border or screen effect. The metadata declares only this supported use.

Include `effect.toml`, then merge the settings from [config.toml](config.toml) into your configuration. The plugin discovers this example from its catalogue metadata; it can apply it, change its timing, return to native Default, Undo or Restore.

## Configuration options

The example enables the animation master switch and this event, with `280` ms and `easeoutcubic`. Fixed durations need a duration-based easing curve; springs determine their own length. Native target availability still applies: borders must be visible; scratchpad windows, overview and layer surfaces must actually transition for their effects to run.

## Preview and validation

`preview.png` is an illustrative CPU evaluation of the shader at mid-transition over synthetic content, not a captured Umbriel session. Configuration and catalogue validation do not establish GPU rendering or motion quality. Live visual testing remains necessary.

## Cost and limitations

One texture sample per fragment and a few arithmetic operations. Content is processed only on the declared animation target. Colours retain premultiplied alpha. No pointer history, audio input, secondary textures or external dependencies are required.

## License

MIT, Copyright (c) 2026 Barrulus. Keep [the license notice](../../LICENSES/Barrulus-MIT.txt) with downloaded files.
