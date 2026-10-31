# Vine Plait

A loose, uneven plait of three thick flowering vines drapes across the
output, with broad bends, varied spacing and a moderate partial roll. The thick
strands overlap, leaving small, irregular pockets between them. Gaps show fragments of the old and new workspaces; the new scene is
fully visible behind the braid. Forward navigation rolls downward and reverse
navigation rolls upward, including when the workspace layout is horizontal.

Part of [Flowering Vine](../../families.toml). The family intentionally has
no screen or movement default.

![Vine Plait in a headless Umbriel session](preview.png)

[Watch the complete transition](preview.gif).

The preview is a real compositor capture over synthetic sample content.

## Use

Save `effect.toml` and `shader.glsl` together under
`~/.config/umbriel/shaders/community/animation/vine-plait/`, retaining the licence notices.
Merge [config.toml](config.toml) into your configuration:

```toml
# Merge into existing tables and append to your include list.
[include]
files = ["shaders/community/animation/vine-plait/effect.toml"]

[animation]
enabled = true

[animation.workspaces]
enabled = true
effect = "flowering-vine.vine-plait"
duration_ms = 2600
curve = "linear"
style = "reveal"
```

Append to existing include lists and merge existing tables. Including the
preset registers it; the selector enables it. Choose **Flowering Vine →
Apply family** in the plugin to select the coordinated defaults.

## Tuning

Edit named controls in `shader.glsl`; edit event timing in your main
configuration. These are not extra preset TOML keys.

| Control | Default | Effect |
| --- | --- | --- |
| `BRAID_HEIGHT` | `0.27` | Nominal braid height as a fraction of output height, clamped to 0.12–0.45. The irregular drape extends beyond this nominal band. |
| `STRAND_WIDTH` | `28.0` logical pixels | Minimum stem half-width, clamped to 2–64, with uneven bulges along each vine. |
| `STRAND_FILL` | `0.46` | Half-width relative to nominal braid half-height, clamped to 0–0.65. Keeps openings small on larger outputs. The larger of this and `STRAND_WIDTH` sets the base width. |
| `WEAVE_SPACING` | `260.0` logical pixels | Nominal twist spacing, with a lower bound of 100. Actual spacing varies along the vines. |
| `ROLL_TURNS` | `0.32` | Turns across the complete transition, clamped to 0–0.5. Zero keeps the plait still while it travels. |
| Event `duration_ms` | `2600` ms | Larger values give a slower rolling reveal. |

The shipped curve is `linear`; easing changes the phase timing, and spring
curves choose their own duration.

The flower colours softly follow the theme palette. Set `palette = false`
in `effect.toml` for the original cream, pink and lilac flowers. Green stems
and leaves keep their botanical colours.

## Compatibility and cost

Requires the full-scene workspace reveal API, including
`umbriel_sample_incoming` and the workspace direction uniform.
**`animation.workspaces.style = "reveal"` is required.** Both scenes remain
in place, including their wallpaper, decorations and shell surfaces. The
reveal field is fixed in space, so forward progress never restores a revealed
patch; reversing progress retraces it. This is not a window lifecycle shader.

Two scene samples per active pixel. Pixels outside the braid skip its artwork.
Inside it, three bounded twelve-segment curve searches locate the thick
strands. Two depth passes draw them with neighbouring leaves and flowers. No feedback buffers or unbounded loops. Exact
endpoints return the outgoing and incoming scene respectively.

Compiled and captured with Umbriel `0.1.0 (a37ae93)` at scale 1.
Checked with two populated workspaces in both directions; the final frames
match the settled incoming scenes.
HDR, rotated outputs and fractional scaling have not been visually verified.
No performance benchmark is claimed.

## Attribution

Original shader by Barrulus. License: [MIT](../../LICENSES/Barrulus-MIT.txt).
