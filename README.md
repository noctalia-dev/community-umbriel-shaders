# Community Umbriel Shaders

A collection of reusable GLSL effects for the [Umbriel Wayland compositor](https://github.com/noctalia-dev/umbriel), organised by kind.

This collection includes 77 community presets by Barrulus, Dual Orbit by neonvoidx, six bundled Umbriel examples, and the original minimal animation example. Browse the categories for descriptions, previews, and copyable settings:

| Kind | What it affects |
| --- | --- |
| [Animation](animation/) | Opening, closing, moving, and resizing windows; workspace transitions |
| [Border](border/) | The focused window’s decoration, with optional inner overlays and light |
| [Window](window/) | Window content, including companion border overlays |
| [Screen](screen/) | A whole output |
| [Cursor](cursor/) | The area around the pointer |

Ten new [paired window transitions](animation/) include Shattered Glass, Wet Paint,
Flame Grilled, Glitch, Cells, Void, Old TV, VHS, Magic, and Triangle Flaps.
Use the [interactive preview](preview/) to play or scrub both directions locally.

For adjustments, see the [configuration reference](#configuration-reference),
[border width and overlays](#border-width-padding-and-overlays), and the
**Configuration options** section in each effect's README.

## Compatibility

Use Umbriel with the preset effects API introduced in [commit `512e2fb3`](https://github.com/noctalia-dev/umbriel/commit/512e2fb3). The `0.1.0` version number alone does not distinguish older builds; check the commit printed by `umbriel --version` when available.

[Comet](cursor/comet/) and [Fairy Tail](cursor/fairy-tail/) additionally require the newer cursor pointer-history API (`umbriel_pointer_count` and `umbriel_pointer_path[64]`). They were shader-tested against local Umbriel cursor revision `a8cdaca1`; the original preset-effects API alone cannot run them.

GLSL source and configuration checks are described in [VALIDATION.md](VALIDATION.md).

## Install

### Download individual effects

Choose an effect from the category pages and download its **`effect.toml` and `shader.glsl`**. On GitHub, open each file and use **Download raw file** to save its contents. Keep the linked license notice with your downloaded files.

For example, download [Glow’s preset](cursor/glow/effect.toml) and [shader](cursor/glow/shader.glsl) into:

```text
~/.config/umbriel/shaders/community/cursor/glow/
  effect.toml
  shader.glsl
```

You only need the effects you choose. Their `config.toml` files, READMEs, and previews are references; Umbriel loads the preset and shader files.

Some border effects also need a companion window overlay. Their READMEs link the additional files and show where to save them. Keep the same relative layout; for example, Flowering Vine needs these four files:

```text
~/.config/umbriel/shaders/community/
  border/flowering-vine/
    effect.toml
    shader.glsl
  window/flowering-vine-overlay/
    effect.toml
    shader.glsl
```

The border preset includes its companion automatically. You do not need to select or include the overlay separately.

### Enable your chosen effect

Each effect directory contains `shader.glsl`, `effect.toml` (the preset definition), `config.toml` (a copyable activation example), and a README. **Include `effect.toml`, then select its preset name.** For example, merge this into `~/.config/umbriel/config.toml`:

```toml
[include]
files = [
  "shaders/community/cursor/glow/effect.toml",
]

[effects]
cursor = "glow"
```

If those tables already exist, append the include paths to `files` and add the selectors inside the existing `[effects]` table. Do not paste duplicate TOML tables. `config.toml` files are examples to merge, not files to include. A trailing comma in the `files` array is valid TOML.

The paths above assume the standard config location. Relative include paths resolve from the TOML file containing them; shader paths resolve from the TOML file defining the preset. Any readable directory works, including `~/.config`; `/usr/share` is not required. Keep `effect.toml` with its `shader.glsl`, and retain any companion directory listed in its README.

Save the configuration to reload, then run:

```sh
umbriel validate
```

Including a preset makes it available but does not enable it. Do not define the same preset name twice, for example by including both a bundled preset and its community copy. Border presets include their companion overlay automatically; do not include that overlay separately.

To update an individually downloaded effect, download its files again, including any companion files. Keep your own customised copies separately if you want to preserve your edits.

### Optional: download the whole collection

If you want to browse and try the whole collection locally, you can download the repository ZIP or clone it. For a new installation:

```sh
mkdir -p ~/.config/umbriel/shaders
git clone https://github.com/noctalia-dev/community-umbriel-shaders.git \
  ~/.config/umbriel/shaders/community
```

For the ZIP, extract its contents into `~/.config/umbriel/shaders/community`. Both options use the same include paths as the individual downloads above. If you choose a different location, adjust your include paths accordingly.

To update a Git clone later:

```sh
git -C ~/.config/umbriel/shaders/community pull --ff-only
```

Keep your own edited copies outside that checkout if you want to update without merging shader edits.

## Selecting and disabling effects

The four persistent selectors live under `[effects]`: `border`, `window`, `screen`, and `cursor`. The preset name is shown in each effect’s README; some names contain a literal dot, such as `"window.crt"`.

```toml
[effects]
window = "window.crt" # after including window/crt/effect.toml
cursor = ""           # disable the default cursor effect
```

Animation effects use an event selector instead:

```toml
[include]
files = ["shaders/community/animation/wobbly-lifecycle/effect.toml"]

[animation]
enabled = true

[animation.windows_in]
enabled = true
effect = "wobbly-lifecycle"
duration_ms = 620
curve = "linear"
```

Use `effect = ""` to remove a custom animation selection. Set the event’s `enabled = false` to disable that transition entirely. Each animation README provides suitable events and timing.

Window rules can select or disable border/window effects, and outputs can override the screen effect:

```toml
[[window_rule]]
match.app_id = "^foot$"
border_effect = "paper"          # include border/paper/effect.toml
window_effect = "paper-content" # include window/paper-content/effect.toml

[[window_rule]]
match.app_id = "^mpv$"
window_effect = "off"

[output."HDMI-A-1"]
screen_effect = "off"
```

Replace application and output names with your own. Animation selections are global per event, and cursor effects have no per-window override.

## Configuration reference

This reference covers the effect configuration supported by **upstream Umbriel
`main` at [`2040758e`](https://github.com/noctalia-dev/umbriel/commit/2040758e5a33bed1fe5f56e830951346e13ed02f)**,
checked on 2026-10-01 against its [effects documentation](https://github.com/noctalia-dev/umbriel/blob/2040758e5a33bed1fe5f56e830951346e13ed02f/docs/user/effects.md),
[configuration parser](https://github.com/noctalia-dev/umbriel/blob/2040758e5a33bed1fe5f56e830951346e13ed02f/src/config/fields_effects.cpp),
and [animation documentation](https://github.com/noctalia-dev/umbriel/blob/2040758e5a33bed1fe5f56e830951346e13ed02f/docs/user/animation.md).
Pools and runtime selection need a build that includes those features; the
collection's original minimum revision predates them.

There are three places to edit:

| File | What to change |
| --- | --- |
| Your Umbriel `config.toml` | Includes, effect selection, animation timing, decoration size, and theme colours. |
| An effect's `effect.toml` | Its preset definition: drawing area, border speed, companion overlay, light, or cursor radius. |
| An effect's `shader.glsl` | Visual details such as thickness, opacity, particle size, and colours. Each effect's README lists its controls and shipped values. |

The `config.toml` beside each shader is an activation example, not an additional
file loaded by its preset. Edit your installed files. Preserve a personal copy
before updating the collection.

### Global effects settings

These keys go under `[effects]` in your main configuration. Defaults below are
Umbriel defaults, which individual activation examples may override.

| Key | Default / accepted values | Effect of changing it |
| --- | --- | --- |
| `border` | `""`; border preset or pool name | Selects the focused window's decoration effect. Empty string clears the default. |
| `window` | `""`; window preset or pool name | Selects an effect for window content, including unfocused and fullscreen windows. Empty string clears the default. |
| `screen` | `""`; screen preset or pool name | Selects a whole-output effect. Empty string clears the default. |
| `cursor` | `""`; cursor preset or pool name | Selects the effect around the pointer. Empty string clears the default. |
| `max_fps` | Integer `0`–`240`, default `0` | Caps frames requested by animated effects. Lower values reduce effect-driven rendering and smoothness, not animation speed. `0` follows output refresh. |
| `in_capture` | `false` / `true`, default `false` | `true` includes window, screen, and cursor effects in screencopy/image-copy captures. Border effects are always included; export-dmabuf always captures the displayed frame. |

`[[window_rule]]` accepts `border_effect` and `window_effect`; an output table
accepts `screen_effect`. Use a matching preset/pool name or `"off"` to disable
that slot. The last matching window rule that sets a key wins. These settings
are independent of a border's companion `overlay`. See the
[selection examples](#selecting-and-disabling-effects).

### Preset settings

Edit the existing `[effects.preset."name"]` table in `effect.toml`. Do not
redeclare an included preset in your main configuration: duplicate preset
definitions are errors. Names share a namespace with pools, must be nonempty,
and cannot be `off` or contain `/`. Quote names containing a literal dot.

| Key | Applies to | Umbriel default / range | Effect of changing it |
| --- | --- | --- | --- |
| `kind` | All | Required: `animation`, `border`, `window`, `screen`, `cursor` | Determines where the shader runs and its required entry point. Changing the name alone does not convert a shader to another kind. |
| `shader` | All | No default; file path | Loads the GLSL file relative to the defining TOML file. Missing/unreadable source leaves the preset inert. Maximum source size is 256 KiB. |
| `palette` | All | `false` | Supplies theme colours. It changes appearance only if the shader reads the palette; otherwise it has no visual effect. |
| `padding` | Border | Integer `0`–`1024`, default `0`, logical pixels | Reserves space outside the native ring. More room permits outward decoration; it does not automatically enlarge the artwork. Too little clips it. Keep a shader's `ring_padding` equal to this value. |
| `speed` | Border | `0`–`10`, default `1.0` | Multiplies the border and attached overlay's time: `0.5` is half speed, `2` is double speed. `0` fixes time at zero. |
| `animated` | Border | `true` | `false` fixes the border and attached overlay's time at zero; it does not remove them. |
| `overlay` | Border | `""` | Names a separately defined **window preset** that paints inside the focused window with the border's clock and visibility gate. Remove the key or use `""` to omit the inward pass. Pools and `"off"` are not overlay selections. |
| `radius` | Cursor | Integer `0`–`4096`, default `0`, logical pixels | Half-size of the square being shaded. `0` means the whole output. A smaller square may clip artwork; whether it also resizes the artwork depends on that shader's coordinates. |

Only border presets accept `padding`, `speed`, `animated`, `overlay`, and
`light`; only cursor presets accept `radius`. Window, screen, and animation
presets have just `kind`, `shader`, and `palette`. There is no generic TOML
`opacity`, `strength`, `width`, custom-uniform, or parameter table in this API.

### Border light

A `[effects.preset."name".light]` table enables compositor light from the
painted ring. These values belong in that subtable, not the parent preset.

| Key | Default / range | Effect of changing it |
| --- | --- | --- |
| `spread` | Integer `1`–`256`, default `80`, logical pixels | Larger values spread light farther from the ring. |
| `intensity` | `0`–`4`, default `1.0` | Larger values brighten the light; `0` makes it invisible. |
| `threshold` | `0`–`1`, default `0.5` | Higher values restrict emission to brighter ring pixels; lower values let more of the ring emit. |

Remove the **whole light table, including its fields**, to disable the light
pass. An empty light table still enables it with defaults. This is separate
from any glow painted by the shader itself. Light adds rendering/blur work,
and its brightness can vary with output scale.

### Animation settings

`[animation]` provides the master `enabled` switch (default `true`) and default
`duration_ms` (`250`) and `curve` (`"easeout"`). Event-specific values override
the default timeline; some events ship with their own defaults. Use each
shader's activation example as the starting point.

| Key in `[animation.<event>]` | What it does |
| --- | --- |
| `effect` | Selects an animation preset. `""` removes the custom selection; pools are not accepted. |
| `enabled` | `false` disables this transition. The master switch must also be enabled. |
| `duration_ms` | Integer `1`–`10000`; larger values make a non-spring transition last longer. Spring curves determine their own duration. |
| `curve` | Easing name, cubic Bézier string, or `"spring:<damping>,<stiffness>"`. Shaders using linear progress keep their internal phase timing regardless of easing, but a spring still changes event duration. |

The events accepting these keys are `windows_in`, `windows_out`,
`windows_move`, `workspaces`, `overview`, `scratchpad`, `border`,
`dim_unfocused`, and `layers`. A shader still needs to suit the event: a
closing fade is generally unsuitable for movement. `windows_drag` accepts
only `physics = true/false`, not a custom effect.

Built-in curves include `linear`, `ease`, `easeout`, `snappy`, `bounce`, and
`elastic`. A Bézier string such as `"0.05,0.9,0.1,1.0"` uses x coordinates
between 0 and 1. Register reusable curves in `[animation.beziers]` as four-number
arrays or `[animation.springs]` as `{ damping = 1.0, stiffness = 900 }`.
Spring damping below 1 overshoots; higher stiffness settles faster.

Other event settings affect native presentation: opening/closing `style` and
`scale` are ignored while a working custom lifecycle shader is selected;
overview `workspace_curve` controls filmstrip movement; scratchpad `dim`,
`blur`, `scale`, `maximize`, and `fullscreen` control its presentation; and
`dim_unfocused.dim` controls unfocused opacity. See upstream's
[animation reference](https://github.com/noctalia-dev/umbriel/blob/2040758e5a33bed1fe5f56e830951346e13ed02f/docs/user/animation.md)
for these native behaviours.

### Preset pools and runtime selection

On upstream builds supporting pools, define `[effects.pool."name"]`:

| Key | Values | Effect |
| --- | --- | --- |
| `kind` | Required: `border`, `window`, `screen`, or `cursor` | All members must have this kind. |
| `choose` | Required array of preset names | Lists available members in order. Include their definitions separately. Pools cannot contain pools. |
| `selection` | `"unused_first"` (default), `"round_robin"`, `"random"` | Chooses the least-held member (ties in list order), the next member in sequence, or a uniformly random member. |

Select the pool wherever a persistent preset can be selected. Each owner
keeps its selection; this does not cycle colours or effects every frame.
Animation events and border overlays accept individual presets only.

Runtime commands use a colon between the action and its argument:

```sh
umbriel msg effect-border-set:rainbow
umbriel msg effect-border-toggle
umbriel msg effect-border-reset
umbriel effects --json
```

Replace `border` with `window`, `screen`, or `cursor` for the other slots.
`set:<name>` selects a preset/pool, `set:off` suppresses the slot,
`cycle:<pool>` advances through a pool, `toggle` toggles suppression, and
`reset` returns to configuration. Window/border commands default to the focused
window; screen commands default to the preferred output. Runtime overrides
take precedence over configuration and are not saved to disk. See upstream's
[runtime selection reference](https://github.com/noctalia-dev/umbriel/blob/2040758e5a33bed1fe5f56e830951346e13ed02f/docs/user/effects.md#runtime-selection)
for explicit targets.

## Customising a shader

In `.glsl`, `#define NAME value` and `const float NAME = value;` are active
code. GLSL comments use `//` or `/* ... */`. In `.toml`, `#` starts a comment.
The per-effect tuning tables describe GLSL edits, not new TOML keys. Where
the shader has no named control, the table identifies the expression to edit.
Sizes may be logical pixels, buffer pixels, or fractions of a window: use the
units given for that shader. Mathematical constants and coordinate adapters
are implementation details, not visual controls.

### Border width, padding, and overlays

These controls do different jobs:

| Desired change | Control |
| --- | --- |
| Remove artwork covering the inside of the window | Disable the border's `overlay`. |
| Thin the painted effect while keeping the window decoration | Change the shader's width/extent controls, in both halves of a paired effect. |
| Change the actual window decoration | Change `[appearance] border_width`; update any hardcoded overlay geometry to match. |
| Give outward artwork more drawing room | Change preset `padding` and the matching GLSL `ring_padding` together. |
| Reduce light spilling outside the border | Adjust/remove the `.light` table, or adjust a shader's own glow. |

For example, to make an **outer-only Rainbow** variant, copy
`border/rainbow/` to `border/rainbow-thin/`, keep its shader, and replace the
copy's `effect.toml` with:

```toml
[effects.preset."rainbow-thin"]
kind = "border"
shader = "shader.glsl"
padding = 14
speed = 1
animated = true
```

Include `shaders/community/border/rainbow-thin/effect.toml` and select
`[effects] border = "rainbow-thin"`. Both the companion `[include]` block and
the `overlay` key are absent. This leaves the outer rainbow without inward
paint. Keep `padding = 14`, matching `ring_padding` in the copied shader.
Do not disable overlays by misspelling their name or breaking an include.

For an existing paired preset, removing `overlay` (or setting it to `""`)
is enough to stop its inward pass. Remove its companion include too if it is
no longer needed; preserve other includes. A separately selected
`[effects] window = "rainbow-overlay"` or window rule still runs independently
and must be cleared separately.

For a variant that keeps its overlay, retain the relative companion paths.
If you copy and customise the companion too, give it a new preset name, update
the border's `overlay` and include path, and edit matching visual controls in
both shaders. Copying a folder alone does not rename its preset. Do not load
two definitions of the same name.

Several overlays hardcode `ring_width = 6.0` and a client radius of `4.0`,
matching `[appearance] border_width = 6` and `corner_radius = 10`. For a
3-pixel border with the same outer radius, their client radius becomes
`max(10 - 3, 0) = 7`. Update both the radius macro and the literal used in the
distance function where present. Other overlays use different geometry; follow
their own README. These appearance sizes accept integers from 0 to 100 logical
pixels. Per-window decoration overrides must also match these assumptions. The [Rainbow instructions](border/rainbow/#configuration-options)
cover all three ways to narrow that effect.

### Reloading edits

Umbriel watches referenced shader files and configuration. Save your edits;
`umbriel msg config-reload` explicitly reloads the running session. An animation
already in progress keeps its existing shader, so trigger a new event to check
changes. Run `umbriel validate` for configuration/source-loading errors and
inspect compositor logs for GLSL compilation errors. Configuration validation
does not compile shaders. A failed shader can render plainly, so an error is
not a reliable way to select a thinner effect.

The tuning tables describe the shipped source. They do not imply that every
custom value has been visually tested; the existing [validation report](VALIDATION.md)
applies to the shipped presets.

## Theme colours

All 69 presets that draw coloured artwork now enable `palette = true` and read
`accent_primary`, `accent_secondary`, `warning`, and `error` from `[colors]`.
`glow`, `accent-pulse`, and `tv-glitch` use the primary accent; cycling rainbow
effects interpolate through the four colours. Other artwork uses palette stops
with its original dark shading and pale highlights. Sampled window content is
only tinted where the effect already applies a colour treatment.

```toml
[colors]
accent_primary = "#CBA6F7"
accent_secondary = "#89B4FA"
warning = "#F9E2AF"
error = "#F38BA8"
```

A theme or wallpaper-colour generator can write these settings to an included TOML file. Umbriel reloads config changes; it does not extract a palette from the wallpaper itself. Values in your main config override included values.

Set `palette = false` in an installed preset's `effect.toml` to restore its
original colours (shown in the static previews). For paired borders and window
overlays, set it in both presets; the setting is independent for each half.

Thirteen effects remain palette-neutral because they transform existing content
without a separate coloured artwork layer: animation `example`, `reveal`,
`squash`, `vhs`, `wobbly-lifecycle`, `wobbly-move`, and
`workspace-transation-vhs-ripple`; cursor `spotlight`; screen `vignette`; and
window `adaptive-text-v4`, `crt`, `flap-board`, and `scanlines`. Their distortion,
channel separation, contrast, or darkening continues to use the source image.

## Troubleshooting

- **`unknown key effects`:** the file was read, but an older Umbriel build does not understand the preset API. Update/rebuild, then log out and back in. Moving the file cannot fix an unrecognised setting.
- **`include not found` or unreadable shader:** check the path, and download both `effect.toml` and `shader.glsl`. Border dependencies must retain their relative directory layout.
- **Unknown preset or wrong kind:** check the selector against the effect’s README and make sure its definition is included.
- **Duplicate preset:** remove the extra definition/include; do not load a bundled preset and its community copy under the same name.
- **No visible change:** selecting the name is required. Borders need a focused, decorated, non-fullscreen, non-urgent window. Animation effects appear only during their event.
- **GLSL compile failure:** inspect Umbriel’s logs for the preset name and driver message. `umbriel validate` checks configuration, not GPU compilation.
- **Effects missing from capture:** window, screen, and cursor effects are excluded from screencopy/image-copy captures by default. Set `[effects] in_capture = true` to include them; this can increase capture cost. Border effects already appear.

## Contributing

For assistant-guided shader creation, use [SKILL.md](SKILL.md). It provides
LLM-agnostic instructions for Umbriel's shader API, preset packaging, and validation.

Use one top-level directory per kind and a lowercase kebab-case directory per effect:

```text
animation/<name>/
border/<name>/
window/<name>/
screen/<name>/
cursor/<name>/
```

Include `shader.glsl`, `effect.toml`, a copyable `config.toml`, and a README with a preview, compatibility, tuning, cost, attribution, and license. A preset definition should not enable itself. Document any companion effects and use relative paths. Do not include personal keybinds, app assignments, machine paths, or binaries.

Shaders use GLSL ES 1.00 and the entry point for their kind: `vec4 animation(vec2 uv)`, `border`, `window`, `screen`, or `cursor`. Do not supply `#version`, `main`, or precision declarations. Return premultiplied RGBA. See the [Umbriel effect API](https://github.com/noctalia-dev/umbriel/blob/main/docs/user/effects.md) for uniforms and sampling semantics.

Check config paths and GLSL compilation, then test the effect in a compositor, including both ends of animation events. Mark any untested behaviour honestly. Keep loops bounded and document previous-frame feedback and other expensive operations.

## Attribution and licensing

Barrulus’s 74 contributed presets are [MIT licensed](LICENSES/Barrulus-MIT.txt). The six bundled Umbriel examples retain [Noctalia’s MIT notice](LICENSES/Noctalia-MIT.txt). Each effect README identifies its source. Keep the appropriate notice when redistributing those shaders.

Dual Orbit is [MIT licensed by neonvoidx](LICENSES/neonvoidx-MIT.txt).

`animation/tv-glitch` is ported from Simon Schneegans’s [Burn-My-Windows](https://github.com/Schneegans/Burn-My-Windows) and is [GPL-3.0-or-later](LICENSES/BurnMyWindows-GPL-3.0-or-later.txt), like its source.

The pre-existing `animation/example` shader is by Lemmy; its original contribution did not declare a license, and this contribution does not relicense it.
