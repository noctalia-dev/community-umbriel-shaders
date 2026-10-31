# Proposal: an optional community shader catalogue for Umbriel

**Status:** Proposal for discussion with Lemmy and Lysec  
**Scope:** Repository organisation, discovery, contribution requirements, and integration with noctalia.dev and a Noctalia Shaders plugin. Local catalogue tooling and the plugin are implemented; online publication remains pending.

**Companion contract:** [Metadata and catalogue contract with real examples](docs/shader-catalogue-contract.md). The nine-effect sample remains a non-installable review fixture.

**Implementation progress:** [Generator and validator](tools/README.md#catalogue-generation-and-validation) cover 138 effects and ten families, with explicit `publish = true` required for catalogue inclusion. Missing flags default to unpublished. Local shader and family browsing, Apply, Undo and Restore are implemented in `umbriel-shaders`. Online delivery is agreed as CI-generated JSON and raw GitHub files, without GitHub Pages or a separate API server; the publisher and remote consumer remain to be implemented. See [publication and maintainer review](docs/catalogue-publication.md).

## Purpose

As the community shader collection grows, browsing directories and following README links becomes increasingly difficult. Users need to find effects suitable for a particular purpose, see how they look, and discover coordinated families such as **Vampire**, **kzzzt**, and **Umbriel After Dark**.

The proposal is to preserve the repository's existing organisation by kind and add structured catalogue metadata. That metadata would support generated repository indexes, a public visual catalogue alongside Noctalia's plugins and palettes, and a Noctalia Shaders plugin for local installation and configuration.

**The current scope is repository automation, integration with noctalia.dev, and a Noctalia Shaders plugin. The plugin provides browsing, selective installation, application of effects and families, and shader-specific window rules. `umbriel-config` integration remains deferred.**

Community content remains optional. Users explicitly choose which effects or families to install and apply through the plugin, or download and configure manually. Installing the plugin must not download the shader collection or change shader selections.

## Problems to address

- **Kind alone does not establish suitability.** Window opening, window closing, and workspace transitions are all animations, but their shaders are not interchangeable. Some workspace effects also require a specific transition mode and API.
- **Families are difficult to discover.** Links between individual READMEs do not give users a clear view of a coordinated collection spanning several kinds.
- **Related effects and required dependencies are easily confused.** A matching closing animation is optional; a border's companion overlay may be required for its intended appearance.
- **Documentation repeats information.** Contributors maintain installation prose, configuration examples, category listings, attribution, and cross-links in several places.
- **Downloading the whole repository will not scale.** Shader sources, previews, and supporting material grow together, even when a user wants only one effect.

## 1. Preserve organisation by kind

Keep shader sources in their current locations:

```text
animation/<effect>/
border/<effect>/
window/<effect>/
screen/<effect>/
cursor/<effect>/
```

Add a small catalogue metadata file beside each effect. Keep `effect.toml` responsible for Umbriel's runtime preset definition.

Describe families purely through root `families.toml`. Each table names an
existing set of effect IDs; no family directories, copied previews, README pages
or activation files are created. The plugin composes family views from member
metadata and previews, and derives apply settings from selected members.

```toml
[families.vampire]
publish = true
name = "Vampire"
description = "Blood-themed transitions, border and cursor effects."
members = ["animation/blood-in", "animation/blood-out", "border/heartbeat"]
tags = ["horror", "blood"]

[families.vampire.defaults]
"animation.windows_in" = "animation/blood-in"
"animation.windows_out" = "animation/blood-out"
"effects.border" = "border/heartbeat"
```

Optional defaults select member IDs, not another copy of their runtime settings.
Shader paths and existing preset names remain unchanged.

## 2. Describe suitability explicitly

The catalogue should distinguish the following information:

| Information | Question it answers | Example |
| --- | --- | --- |
| Kind | Where does Umbriel run it? | Animation, border, window, screen, cursor |
| Supported use | What can the user select it for? | Window opening, window closing, workspace transition |
| Requirements | Which settings or features does it need? | Workspace reveal mode; full-scene workspace API |
| Tags | What does it look or feel like? | Horror, retro, water, minimal |
| Family | Which coordinated collection includes it? | Vampire, kzzzt, Umbriel After Dark |
| Dependencies | What else must be installed with it? | A companion window overlay |

For example:

| Effect | Kind | Supported use | Family |
| --- | --- | --- | --- |
| Blood In | Animation | Window opening | Vampire |
| Blood Out | Animation | Window closing | Vampire |
| Heartbeat | Border | Window border | Vampire |
| Workspace Iris | Animation | Workspace transition with reveal mode | — |

An effect may support multiple uses, but each should be declared explicitly and reviewed. Descriptive tags must not determine compatibility.

The website and plugin should allow users to filter for effects declared suitable for a particular event, such as window opening. A workspace reveal should display its required mode and feature information. Suitability must not be inferred from names or tags.

Required capabilities and known build requirements should be separate from testing evidence. “Tested on this revision” does not establish the earliest compatible revision. The community catalogue targets latest Umbriel: maintainers update or withdraw incompatible shaders. Older variants are not retained, and missing runtime capability evidence does not require a warning or confirmation in the normal browser flow.

Use capability labels as compatibility tags, separate from visual tags. A rare breaking shader API change gets a distinct label; a repository revision change alone does not mean incompatibility. Check the selected effects and all their dependencies. Known incompatibility blocks application; missing shader capability evidence does not gate ordinary Apply. File and configuration validation remain required, and failures during activation restore the previous selection.

## 3. Give families their own catalogue entries

A family should have a stable identifier, display name, description, credits, and member list. Its page should group members by purpose and allow access to each effect independently. Family previews are composed from existing member previews, without copied artwork.

Searching for **Vampire**, for example, would return a family card containing:

- **Border:** Heartbeat.
- **Window opening:** Blood In.
- **Window closing:** Blood Out.

Each member's page would link back to the family. Declare membership once in the family definition and generate the reciprocal links. An effect may appear in more than one family or curated collection without another copy of its source.

Family definitions are optional and may be supplied by contributors or maintainers. One contribution can be an individual effect, a complete family spanning several kinds, or an extension to an existing family. Maintainers can help with packaging; they are not the exclusive authors of families.

A family may provide optional default selections in metadata: a family might contain several alternative opening animations, so membership alone cannot mean “activate everything”. Defaults select at most one member per slot. Apply settings come from that member’s existing configuration example.

Required companion effects remain a separate relationship. Installing a border includes its required overlay; it does not automatically install matching animations from the same family. Companion components should be labelled clearly in the catalogue.

Companions default to no standalone uses. Offer one as an independent selection only when its metadata explicitly declares a reviewed standalone use.

## 4. Browse, install, and apply through the Noctalia Shaders plugin

The website provides public discovery and manual downloads. The plugin provides the local choose, install, apply, and undo workflow, using the same catalogue. It targets Noctalia v5's Luau plugin system.

The proposed plugin flow is:

1. The user opens the plugin. Installed effects and saved selections are available locally; online browsing or refresh is explicit.
2. The user browses effects or families, with previews, supported uses, requirements, credits, and download sizes.
3. The user chooses members, affected slots, and scope: defaults, matching applications/windows, or supported output selections.
4. The plugin downloads only missing selected files, required companions, and notices from the catalogue's pinned revision. Browsing and recorded previews do not install or execute shaders.
5. Before applying, the plugin shows which selections and requirements will change, validates the complete candidate configuration, and applies it only after all required files are ready.
6. Undo restores the previous plugin selection; **Restore original configuration** returns control to the user's base configuration.

Installation and activation remain distinct. An explicit **Apply** action may perform both steps, but a download alone must not change active selections. Family application reviews each selected slot, including any global prerequisites.

Filter activation recipes to the chosen slots for both individual effects and families. Choosing an animation for window opening must not also replace the closing animation merely because its example configures both.

The plugin maintains installed-file records and bounded preview caches outside its replaceable runtime directory. It preserves locally edited shaders, retains dependencies still in use, and permits offline use of installed content. Update checks are explicit; automatic checks would require a separate opt-in. No full-repository download is needed. Manual cloning remains available to users who deliberately want the source collection.

Keep one committed version per installed effect and shared dependency, with the managed library matching one catalogue snapshot. Installing from a newer snapshot reviews and updates the existing library together, downloading only missing or changed files. Compatibility tags identify API requirements; they do not require keeping old shader releases. Temporary staging supports failed-transaction recovery, and superseded files are removed after a successful switch. Updating active shader files requires Apply. Undo restores selections against the current library, not previous shader bytes; updates clear undo records that depend on superseded definitions.

### Shader-specific window rules

Window rules are a first-class part of the plugin, with a deliberately shader-focused editor:

| Scope | Supported application |
| --- | --- |
| Global defaults | Border/window defaults, screen/cursor selections, and supported animation events |
| An application or matching windows | Persistent `border_effect` and `window_effect` rules |
| An output | A screen-effect override for that output |
| One current window temporarily | Border/window runtime actions; no persistent window-ID rule |

The rule editor should offer a running-window/application picker, automatically escaping and anchoring application IDs for exact matches. Advanced matching can expose supported title, tag, content-type, and window-state selectors. Rules belong to the user's local plugin state; shader contributors do not supply application matches.

Each rule field offers **Leave unchanged**, **Use this effect**, or **Disable effect**. Leave unchanged supplies no plugin override and preserves the result of existing rules; it does not necessarily mean the global default. Removing a plugin rule reveals the remaining rules.

Umbriel combines matching rules field by field, with later rules winning. Plugin rules should follow the base configuration's rules and set only the selected shader fields, preserving placement, size, opacity, and unrelated behaviour. The UI must explain overlapping shader rules and their order. Runtime overrides can still take precedence. [Window rules](https://docs.noctalia.dev/umbriel/window-rules/), [runtime effect selection](https://docs.noctalia.dev/umbriel/effects/#runtime-selection).

The current window-rule interface supports border and window effects, not per-application animation, cursor, or screen effects. Applying a family to an application offers its supported border/window members; other members require a separate, explicit global or output choice. Family membership must not imply that every effect can be scoped to a window.

### Apply configuration without repeatedly editing the user's base file

The preferred approach to prototype is a generated wrapper that includes the user's original configuration and selected presets, then supplies plugin selections and rules. A normal include inside the original config is insufficient because the original file's values take precedence. [Configuration precedence](https://docs.noctalia.dev/umbriel/configuration/#include).

The plugin would validate a new candidate and switch to it with `umbriel config-replace <absolute-path>`. This existing command changes the active file and watch set; invalid replacements leave the previous configuration active. Each apply should use a new candidate path so writing or validating it cannot trigger an early reload of the active file. No compositor changes are proposed. [Config replacement](https://docs.noctalia.dev/umbriel/ipc/#config-commands).

Setup must identify the actual base config, including custom paths and declaratively managed configurations. Existing preset collisions, include chains, and root-only configuration requirements need validation. The plugin should retain the original file and the last successful candidate for recovery.

This is a proposed integration, not a completed plugin. Isolated validation confirmed wrapper precedence with the installed Umbriel; live switching, shader compilation, rules, undo, and restart recovery still require prototype tests. Config replacement is session-local: restoring saved selections at startup, handling plugin disable/uninstall, and supporting older Umbriel builds remain explicit design decisions. The plugin must never treat a missing capability as a successful apply.

## 5. Publish one catalogue for repository navigation, the website, and plugin

Generate a versioned catalogue from the repository after contributions are validated and merged. Repository indexes, the website, and the plugin should consume the same data.

```text
Contribution PR → validation and review → merge
                                         ↓
                              generated catalogue
                              references to files
                                         ↓
                    repository indexes / website / plugin
```

Keep the searchable index, preview assets, and downloadable shader files separate so clients fetch only what is needed. Catalogue entries and downloads should identify the same repository revision, preventing metadata from describing different content from the files being installed.

The proposed division of responsibility is for repository tooling to generate the catalogue and for Lemmy's existing webhook/API infrastructure to serve its JSON through `api.noctalia.dev`. The website and plugin can download individual shader files, required companions, and previews directly from GitHub at that revision. Their direct requests do not use Noctalia's server credentials or consume its authenticated API quota. Noctalia does not need to host these assets or provide a server-side installer; the plugin performs local installation. The precise endpoint and publication trigger remain subject to the contract review.

A proposed shader catalogue alongside [Noctalia Plugins](https://noctalia.dev/plugins) and [Noctalia Palettes](https://noctalia.dev/palettes) would offer:

- Effects and Families views.
- Search and filters for supported use, kind, tags, and author.
- Appropriate still or animated previews.
- Clear requirements and links to source and documentation.
- Individual and family downloads with dependencies and notices included.

The [community palettes repository](https://github.com/noctalia-dev/community-palettes) already documents a CI-generated registry and delivery of merged palettes to the application. That provides a useful precedent for the contribution-to-catalogue cycle. The exact hosting arrangement for shaders would need agreement. Lemmy has offered the backend/API; ownership of website frontend and plugin implementation must be agreed separately. Repository tooling and contributor guidance remain with the shader maintainers.

## 6. Keep metadata and contributor requirements manageable

**Submit one contribution per PR: one effect or one coordinated family.** Contributors do not need to understand the catalogue format or be programmers. They should be able to explain what they made, where it should apply, which files belong to it, who made it or supplied the original work, and show it working. The same review and validation apply to effects created with LLM assistance.

Tooling and maintainers can translate those answers into directory placement, metadata, tags, previews, and family membership. Contributors comfortable preparing those files directly can do so. Missing optional metadata should not block an otherwise suitable contribution; required information must be resolved before publication. Supported uses need verification, and licence permission and attribution cannot be guessed.

The published entry needs a display name, short description, author, licence and attribution references, supported uses, and any additional requirements. Tags and family membership are optional. Use stable catalogue identifiers, initially matching paths such as `animation/blood-in`, separately from runtime preset names.

Derive kind, preset names, shader paths, and existing include dependencies from `effect.toml`. Read family membership from family definitions. Keep activation examples in `config.toml` and generate restricted, typed activation recipes from those examples after validating them against declared uses and requirements. Contributors do not maintain a second activation format or application-specific rules.

Start with a small documented tag vocabulary. Contributors can propose new tags through review, avoiding several spellings for the same concept.

Validation should check metadata structure, identifiers, references, family members, dependency resolution, required files, and agreement with preset and activation files. Existing configuration and shader checks remain relevant. Automated checks cannot establish visual suitability; contributors should test declared uses and document limitations.

## 7. Simplify READMEs and generate routine listings

| Location | Responsibility |
| --- | --- |
| Root README | Introduction, catalogue link, quick start, contribution link |
| Shared documentation | Installation, configuration, troubleshooting, authoring |
| Effect metadata | Searchable facts, requirements, credits, preview references |
| Effect README | Unusual setup, tuning guidance, testing limitations, design notes |
| Generated category and family pages | Listings, member links, badges, standard usage information |

Contributors should not need to repeat generic installation instructions or manually maintain root listings, category tables, and reciprocal family links. Generate those views from the catalogue while retaining useful navigation directly on GitHub.

Preserve meaningful tuning and testing information. Licence and attribution notices must remain available with downloaded content, including notices for adapted work; they must not exist only on the website.

## 8. Validate shader and configuration security

GLSL effects have no ordinary filesystem, network, or shell-command API, but they still process untrusted code through a compiler and graphics driver. 

Accompanying configuration also needs review. Umbriel configuration can express command execution through features such as autostart. A file that passes ordinary configuration validation is not necessarily appropriate to distribute as a community effect.

The proposed CI requirements are:

| Check | Requirement |
| --- | --- |
| Restricted configuration | Allow only the specific preset, dependency, and activation fields approved for community effects. Reject unrelated settings and executable providers. Allowlisting an entire effects section is insufficient. |
| Files and dependencies | Restrict package contents to approved file types; reject symlinks and special files; enforce file-count and size limits; ensure resolved paths stay within the installation root. Relative references between sibling effects remain valid. |
| Compilation and linking | Validate shaders using the intended Umbriel wrappers, with process timeouts and memory limits. Compilation itself must be treated as processing untrusted input. |
| Complexity review | Require bounded loops and flag excessive bounds, nesting, array sizes, and sampling work. These checks assist review; bounded code is not automatically inexpensive. |
| Isolated rendering | Exercise representative inputs and animation endpoints in a disposable environment with execution limits. Begin with software rendering; use separate, dedicated infrastructure for hardware testing. |
| Human review | Review declared uses, unexpected configuration, obscured code, and visual behaviour before publication. |

The existing `tools/validate.py` already checks source size, repository-contained paths, preset names, entry points, and configuration validity. It does not currently enforce the restricted configuration policy above, compile shaders, or impose execution limits. These checks should extend the existing validation rather than replace it.

CI jobs handling untrusted contributions should have no secrets or write-capable repository tokens and should run in disposable environments. Do not execute PR content in privileged `pull_request_target` jobs.

For manual downloads, publication checks and clear configuration examples are the main safeguards. The plugin must also validate downloaded paths, sizes, checksums, dependencies, and restricted preset/activation content before applying anything. User-authored window matches are local decisions, never instructions fetched from the catalogue. Validation of existing user configuration must preserve its unrelated settings rather than applying the downloaded-content allowlist to the whole desktop config.

Published effects should be described as **validated and reviewed**, without claiming safety across every graphics driver. Software-rendering tests cannot prove hardware-driver safety, and a process timeout does not guarantee recovery from a GPU hang.

## 9. Use configuration-based disabling and recovery

Effects are enabled and disabled through plugin-managed configuration or manual configuration. Disabling an effect means clearing or restoring its selection, including relevant event, window-rule, output, or runtime overrides. Removing downloaded files alone is not a disable mechanism. The plugin must distinguish undoing its last change, removing one local rule, and restoring the original base configuration.

Shared documentation should explain how to preserve and restore the previous configuration and how to recover from another session or TTY if the desktop becomes unusable. If the compositor cannot process a configuration reload, recovery may require correcting the configuration and restarting the session.

## Suggested rollout

1. **Agree the metadata contract and contribution rules.** Trial the proposed structure with Vampire, kzzzt, Umbriel After Dark, and a workspace reveal. These cover families across kinds, dependencies, and event-specific requirements.
2. **Improve repository navigation and prepare selective distribution.** Generate category and family indexes, simplify repeated documentation, add the metadata and security checks, and produce file lists with dependency information. Document configuration-based disabling and recovery. Existing manual installation paths remain usable.
3. **Prove plugin application and recovery.** Prototype Glow, Flowering Vine with its companion, and selected Vampire members. Test application-specific rules, existing-rule precedence, undo, offline operation, and restart/disable behaviour before committing to the wrapper strategy.
4. **Publish the website and plugin catalogue experiences.** Use the shared index and selective downloads. Keep manual installation available and expose supported family members and scopes clearly.

`umbriel-config` remains deferred. The simpler shader-only submission mechanism can follow later; contributors can receive maintainer assistance from the outset.

## Decisions requested

- Retain kind-based shader storage and existing paths.
- Adopt explicit supported-use and requirement metadata, separate from descriptive tags.
- Make families first-class catalogue entries, with optional default member selections.
- Provide selective website downloads and manual installation guidance without requiring a full-repository download.
- Use one generated catalogue for repository navigation, the public website, and the Noctalia Shaders plugin.
- Add plugin application and shader-specific window rules, with explicit family scope and reversible configuration changes.
- Reduce repeated README requirements by generating routine information from that catalogue.
- Accept one effect or one coherent family per PR, with contributor assistance for publication metadata.
- Add targeted shader, configuration, and packaging security checks before publication, with restricted CI execution.

The immediate next step is review of the [draft contract and examples](docs/shader-catalogue-contract.md): Lemmy can review publication and API needs; shader, website, and plugin maintainers can agree generated activation data, frontend ownership, and the application/recovery prototype. No compositor changes are proposed.
