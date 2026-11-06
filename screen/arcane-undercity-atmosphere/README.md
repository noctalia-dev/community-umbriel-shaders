# Undercity Atmosphere

Slow teal-violet peripheral haze and sparse brass dust leave the desktop centre clear.

![Native compositor capture over synthetic content](preview.png)

An unpublished member of **Arcane Inspired**, for local testing. Original procedural artwork by Barrulus; no extracted show assets.

## Use and tuning

Include [effect.toml](effect.toml), then select `arcane.undercity-atmosphere`. Merge [config.toml](config.toml) into existing tables. In the plugin’s local checkout mode, refresh **Arcane Inspired** to load this revision. Fixed cyan, magenta and brass constants are at the top of [shader.glsl](shader.glsl); palette adaptation is intentionally disabled.

One texture sample plus procedural noise. Haze opacity stays below seven percent and is confined to the periphery. Full-output animation requests frames.

## Validation and limitations

Compiled and captured with Umbriel 0.1.0 (`b6c4b7d`) in private native compositor sessions. Native screen effect. Preview inspected. Configuration and unpublished catalogue validation pass.

This is a revised local prototype, not a final visual approval. Hardware performance, HDR, output rotation and fractional scaling have not been measured. No feedback buffers or external textures. Costs scale with target size; time-dependent persistent effects request frames.

## License

Copyright (c) 2026 Barrulus. [MIT](../../LICENSES/Barrulus-MIT.txt). Unofficial work inspired by Arcane.
