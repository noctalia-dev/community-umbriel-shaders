# Shader catalogue contract

The catalogue lets a browser or plugin discover shaders, show tags and families,
and install selected effects with their dependencies and notices. The repository
keeps one maintained version of each shader, targeting latest Umbriel.
Incompatible shaders are updated or withdrawn rather than keeping old variants.

The repository supplies metadata, a generator, contract tests, read-only PR
checks and a publisher for raw-GitHub delivery. Plugin download support remains
separate work. See [publication and review](catalogue-publication.md) for the
endpoint, workflow and planned repository protection settings.

## Effect metadata

Put `metadata.toml` beside a shader's existing `effect.toml`:

```toml
publish = false
name = "Glow"
description = "A soft theme-accent halo around the pointer."
author = "Noctalia"
license = "MIT"
notice_files = ["LICENSES/Noctalia-MIT.txt", "cursor/glow/README.md"]
tags = ["minimal", "glow"]
```

| Field | Meaning |
| --- | --- |
| `publish` | Boolean, default `false`. Maintainer-reviewed eligibility for the public catalogue. |
| `name`, `description` | Required nonempty display text. |
| `author`, `license` | Required attribution and licence identifier, preserving the original contribution. |
| `notice_files` | Required nonempty list of repository-relative Markdown/text files containing applicable notices. |
| `tags` | Optional descriptive tags from the reviewed vocabulary in `tools/catalogue.py`. |
| `uses` | Supported global slots. Required for animations; persistent effects default to `effects.<kind>`. |
| `role` | `effect` by default, or `companion` for an effect installed through another effect. |
| `requirements.features` | Optional capability labels for rare breaking interface changes. |
| `required_settings` | Required typed configuration values, such as workspace reveal style. Cannot select another effect. |
| `tested_on` | Optional build identifiers documenting test evidence; never interpreted as minimum versions. |

Effect IDs are their kind and directory, such as `cursor/glow`. Display names can
change without changing IDs. Keep published paths stable. Runtime preset names
come from `effect.toml` and can differ from catalogue IDs.

Valid kinds are `animation`, `border`, `cursor`, `screen` and `window`. Persistent
uses are `effects.border`, `effects.cursor`, `effects.screen` and `effects.window`.
Animation uses are `animation.windows_in`, `animation.windows_out`,
`animation.windows_move`, `animation.workspaces`, `animation.overview`,
`animation.scratchpad`, `animation.border`, `animation.dim_unfocused` and
`animation.layers`. Declare only uses actually supported by the shader.

The generator reads preset names, shader paths and dependencies from existing
`effect.toml` files. Preset-relative includes keep their existing meaning.
Metadata paths are relative to the repository root. There is no duplicated
shader manifest or executable installation hook.

Optional presentation files are discovered beside each preset: `preview.png`,
`README.md`, `config.toml`, and the first available `preview.webm`, `preview.mp4`
or `preview.gif`. The top-level local `preview/` development tool is unrelated
and remains excluded from Git.

### Publication and compatibility

Only explicit `publish = true` entries enter the default output. Filtering occurs
before reading their presets, media and notices. Published effects cannot depend
on unpublished effects. Missing or false flags exclude an entry; descriptive
tags never publish it. Public repository files remain public even when excluded.

Contributors submit with `publish = false`. A proposed true flag is not an
access-control mechanism: maintainers must approve source changes through
repository review. Branch protection is deferred; until it is configured,
publication relies on the discipline of accounts with repository write access.

The initial feature labels are `preset-effects`, `workspace-reveal-full-scene`
and `cursor-pointer-history`. Their definitions are included in generated JSON.
A future incompatible API should receive a new label rather than silently
changing an old label's meaning. A different source commit is not itself an API
mismatch. Missing capability evidence is diagnostic, not an extra confirmation
step for every shader. Actual known incompatibility remains an error.

Workspace reveal metadata can require:

```toml
[requirements]
features = ["workspace-reveal-full-scene"]

[required_settings]
"animation.workspaces.style" = "reveal"
```

## Metadata-only families

Root `families.toml` groups existing shader IDs. There are no family directories,
copied previews, duplicated shaders or family activation files.

```toml
[families.flowering-vine]
publish = false
name = "Flowering Vine"
description = "A flowering vine border with its matching inward decoration."
members = ["border/flowering-vine", "window/flowering-vine-overlay"]
tags = ["nature"]

[families.flowering-vine.defaults]
"effects.border" = "border/flowering-vine"
```

Family IDs are stable lowercase kebab-case names. `name`, `description` and a
nonempty `members` list are required; `tags` and `defaults` are optional. Families
opt into publication separately, and all published members must be published.
Members can belong to multiple families and keep their individual catalogue cards.

Defaults map a slot to a member ID, never to copied settings. The generator
resolves settings from that member's current activation example. Membership alone
does not choose between competing members for a slot. Clients compose family
previews from member previews and let users choose which slots to apply.

This migration replaces `packs/psychedelic/` with the Psychedelic definition in
`families.toml`. Existing manual users of `packs/psychedelic/config.toml` should
use the individual members' `config.toml` examples for their desired slots.
The actual shader directories and preset names are unchanged.

## Generated JSON, schema version 1

| Field | Meaning |
| --- | --- |
| `schema_version` | Integer `1`. Consumers reject unknown schema versions. |
| `draft` | `true` for working-tree output; `false` only for committed-source generation. |
| `source.repository` | `https://github.com/noctalia-dev/community-umbriel-shaders`. |
| `source.revision` | Full source commit SHA, or `null` in a draft. |
| `feature_definitions` | Reviewed capability labels and descriptions. |
| `effects` | Effect records in ID order. |
| `families` | Family records in ID order. |
| `files` | Referenced repository-relative paths mapped to byte lengths and SHA-256 hashes. |

Effect records contain `id`, `path`, `kind`, `preset`, display and attribution
fields, `notice_files`, `tags`, `role`, `uses`, `dependencies`, family backlinks,
requirements, test evidence and `install_files`. They also contain
`preview: {image, animation}`, `readme`, `config_example` and `activation`.
Absent optional paths and activation recipes are `null`.

Family records contain `id`, `name`, `description`, `members`, `tags`, authors
from the dependency closure, and an optional derived `activation`. They have no
`path`; `preview` contains two null fields, and `readme` and `config_example` are
null. Clients use the member records for those assets.

`install_files` contains an effect's own preset, shader and notices. Installation
must also traverse its `dependencies`. `files` includes presentation assets too,
so downloading every file in that map is unnecessary for applying one shader.
Shared paths occur once. Arrays and object output have deterministic ordering;
SHA-256 values are lowercase hex strings and lengths count bytes.

### Activation recipes

The generator derives restricted `{include, settings}` recipes from existing
`config.toml` examples. Includes use repository-relative preset paths. Settings
are full configuration leaf names with validated typed values. Consumers must
not execute downloaded example configs or append arbitrary downloaded TOML.

Recipes support the declared effect slots and reviewed animation settings such
as enabled, duration, curve and style. Unsupported configuration is rejected.
The explicitly recognised manual-only settings `effects.max_fps` and
`effects.in_capture` produce a warning and `activation: null`.

For a chosen slot, retain only settings for that slot and shared animation
requirements. For example, applying a paired animation to opening does not
change closing. Border dependencies install their companion overlays without
selecting them as global window effects. Requirements affecting other slots are
reported separately; they must not silently change an unrelated choice.

`activation_for()` and `library_update()` are pure planning helpers for generated
data. They do not install, apply configuration or validate arbitrary downloaded
JSON. A consumer must implement its own input validation, transaction, local-copy
reuse and recovery behaviour. Existing local presets, including customisations,
should be reused without overwriting their definitions.

## Source integrity and delivery

`--draft` reads the working tree. `--draft --include-unpublished` also validates
experiments. `--metadata-root docs/catalogue-examples` selects the nine-effect
review fixture; it is never a production source.

Production `--revision FULL_SOURCE_COMMIT_SHA` reads immutable Git objects only,
rejects draft overlays and unpublished inclusion, and records that source commit.
It does not require a clean checkout and never substitutes working-tree files.
The generator bounds file sizes and dependency traversal, rejects symlinks and
path escapes, and replaces output atomically after validation succeeds. It
neither executes contribution code nor fetches network resources.

Delivery uses `catalogue.json` on a dedicated `catalogue` branch, generated by
the publishing workflow after changes reach upstream `main` and pass its checks. No GitHub
Pages deployment is needed. Source file URLs resolve against the immutable
`source.revision`; verify downloaded byte counts and hashes. Keep one installed
shader library rather than multiple versioned copies.

Consumers must reject drafts, unknown schemas, unexpected source repositories
and unsafe paths. Pin downloads to the recorded source commit, preserve notices,
and fail on missing or mismatched bytes rather than substituting newer files.
Hashes verify consistency, not authorship or trust. A failed update keeps the
last good catalogue. Fork publishers must not claim an upstream source identity
for commits unavailable upstream.

## Checks and examples

See [tool commands](../tools/README.md#catalogue-generation) and the reproducible
[nine-effect JSON example](catalogue-examples/registry.example.json). That example
is explicitly a draft and hashes the source files in this checkout.

The upstream migration covers 136 presets and ten families. This fork retains
fifteen additional presets, for 151 total, with their additional family memberships
and defaults. `animation/example` is excluded pending clarification of its original
licence. The generator preserves existing contributor credits and notice files;
it cannot establish licence permission itself.

CI checks metadata, dependencies, recipes, file integrity and deterministic
committed-source generation. It does not establish GPU compilation, visual
quality or compatibility on every device. Shader testing remains part of
maintainer review; specific limitations stay in each shader's README.
