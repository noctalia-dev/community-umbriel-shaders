# Contributor tools

## Standalone audio analyser

[`audio-analyzer.py`](audio-analyzer.py) captures PipeWire playback and sends
64 spectrum bands to Umbriel. Use it with an older Noctalia that lacks the
audio provider, or with another shell. Download that one script; it needs
**Python 3.11+ and `pw-record`** (PipeWire's command-line tools), with no pip
packages. It requires Umbriel's **version-2 spectrum protocol**, as shipped
at `76477c2`; it does not support the old single-level version-1 protocol.

```sh
python3 audio-analyzer.py --verbose
```

From this repository, use `python3 tools/audio-analyzer.py --verbose`.
Run it inside the Umbriel session and select an audio-reactive shader.
It captures the default output's playback monitor, not the microphone.
Audio is processed in memory and is not saved. Stop with **Ctrl+C**.
Only one provider can own Umbriel's feed: disable Noctalia's **Provide Audio
to Umbriel** setting if it is enabled before using this script.

```sh
# Stronger response for quiet playback
python3 audio-analyzer.py --gain 2

# Choose an output by its PipeWire node.name or object.serial
python3 audio-analyzer.py --target alsa_output.example --verbose

# Explicit compositor socket, if session environment variables are unavailable
python3 audio-analyzer.py --socket /run/user/1000/umbriel-wayland-0.sock
```

Use `wpctl status -n` and `wpctl inspect ID` to find an output's `node.name`
or `object.serial`; the numeric ID shown by `wpctl status` is not necessarily
its serial. `--target auto` delegates output selection to the PipeWire session
manager. Restart the script when changing outputs if capture does not follow.
`--fps 10` through `--fps 60` adjusts the analysis/send rate (default 30).

The analyser uses a 2,048-sample Hann-windowed FFT at 48 kHz, mono playback,
and 64 logarithmic bands covering approximately 40 Hz–16 kHz. Low bands share
FFT bins because frequency resolution is about 23 Hz. Intensities map -60 to
-6 dBFS into 0–1 with fast attack and slower decay; these are visual values,
not calibrated loudness or an exact match for Noctalia's analyser. Mono mixing
can reduce out-of-phase stereo content. The pure-Python FFT costs more CPU
than a native analyser; lower `--fps` if needed.

The script waits for acknowledgements, sends fresh snapshots during silence,
clears stalled capture, and retries disconnected or rejected feeds once per
second. A lock/unlock or compositor restart therefore does not require
restarting the script. `pw-record` failure exits with a diagnostic; fix the
capture source and rerun. `--verbose` reports capture activity, peak band
intensity and IPC connection status. A connected feed with a zero peak means
silence or the wrong output; a waiting feed reports the IPC error. The bundled
`audio` shader reads only the lowest band, so it can stay dim while higher
bands are active.

References: [PipeWire capture options](https://docs.pipewire.org/page_man_pw-cat_1.html),
[playback-monitor property](https://docs.pipewire.org/group__pw__keys.html),
and [Umbriel spectrum IPC](https://github.com/noctalia-dev/umbriel/blob/main/docs/user/ipc.md#audio-input).

The script is [MIT licensed](../LICENSES/Barrulus-MIT.txt).

## Generate one shader preview

Requires Python 3.11+, installed Umbriel and `grim`, and an accessible GLES/EGL
render device. The tool starts a private headless compositor with synthetic
content and leaves the desktop session alone.

```sh
# Render into this shader's preview.png; replace it only after success.
python3 tools/render-preview.py cursor/starlight

# Inspect a capture without replacing the published preview.
python3 tools/render-preview.py border/flowering-vine -o /tmp/flowering-vine.png

# Capture a closing animation at a particular point.
python3 tools/render-preview.py animation/wet-paint --event windows_out --progress 0.4
```

Use `--size 400x600` for portrait content, `--time 2` to change the settling delay,
`--software` to request software rendering, or `--umbriel`/`--grim` to select
executables. When an effect file defines multiple presets, pass `--preset NAME`.
Keep `preview_client.py` beside the script; it supplies the sample content and
virtual pointer. Run `python3 tools/render-preview.py --help` for all options.

Animation captures use a 1600 ms linear timeline at progress 0.55 by default;
`--duration-ms` and `--progress` change the capture without editing the preset.
The tool retains the preset's workspace reveal style. Frozen-clock commands are
used when available; otherwise it reports approximate wall-clock timing.
Supported animation events are opening, closing, window movement and workspace
switches. Persistent clocks and pointer motion are real-time.

Inspect every image before submitting it. Captures show a real compositor at
scale 1 over synthetic content; they do not establish motion quality, HDR,
rotated/fractional-scale behaviour or GPU performance. Failed or interrupted
renders preserve an existing output image.

If EGL initialization fails, make a graphics render device available; software
rendering does not bypass that requirement. Configuration errors and GLSL errors
are reported separately. A fallback render after shader compilation failure is
not accepted as a successful preview.

The preview scripts and synthetic scene use the [Barrulus MIT license](../LICENSES/Barrulus-MIT.txt).

## Configuration validation

```sh
python3 tools/validate.py
# Select a particular installed build:
python3 tools/validate.py --umbriel /path/to/umbriel
```

Checks all installation examples, unique preset names, dependencies and the
combined library without editing the user's configuration. It detects the
installed Umbriel validation command. Configuration validation checks parsing
and source loading; compile and inspect selected shaders in a compositor session
as a separate step.

## Catalogue generation

Requires Python 3.11+; committed-source generation also needs Git. The generator
reads effect `metadata.toml` files and root `families.toml`. Families reference
existing shaders and optional default member IDs; they have no asset folders.

```sh
# Validate the working tree and write a non-installable draft.
python3 tools/catalogue.py --draft --output /tmp/catalogue.json

# Include unpublished entries for contributor testing.
python3 tools/catalogue.py --draft --include-unpublished --output /tmp/catalogue-development.json

# Generate from an immutable source commit.
python3 tools/catalogue.py --revision FULL_SOURCE_COMMIT_SHA --output /tmp/catalogue.json
```

Only explicit boolean `publish = true` entries appear by default. Published
effects and families require published dependencies and members. Committed mode
reads only the specified full commit, rejects development overlays and
`--include-unpublished`, and ignores working-tree changes. `--root PATH` selects
another repository; `--check FILE` compares output without replacing the file.

The generator validates metadata, paths, dependencies, family membership and
restricted activation recipes, then records file sizes and hashes. Output is
deterministic and replaced only after validation succeeds. It does not compile
GLSL, establish licence permission, publish an API, install shaders or change
compositor configuration. See the [contract](../docs/shader-catalogue-contract.md)
and [publication rules](../docs/catalogue-publication.md).

## Contributor checks

```sh
python3 -m unittest discover -s tools -p 'test*catalogue.py'
python3 -m unittest discover -s tools -p test_render_preview.py
python3 tools/catalogue.py --draft --metadata-root docs/catalogue-examples \
  --check docs/catalogue-examples/registry.example.json
```

If a documented source change makes the review fixture stale, regenerate it with
`--output docs/catalogue-examples/registry.example.json` instead of `--check`.
Run only the checks relevant to the changed tool, and include the commands and
results in the PR description. Shader READMEs should retain relevant limitations.
Local development logs, browser tooling and audio-analyser tests are excluded
from the tracked repository and checked by CI.

## Catalogue publication

`publish_catalogue.py` generates from a full upstream `main` commit and writes
only `catalogue.json` to upstream's `catalogue` branch. Git write credentials and
full source history are required. It checks remote identity, current source SHA,
previously published source ancestry and fast-forward publication; failed
validation preserves the previous catalogue. It does not change the source
checkout or use working-tree shader bytes.

The **Publish catalogue** workflow invokes it after its validation job passes.
See [publication instructions](../docs/catalogue-publication.md) for the public
URL, manual invocation and recovery. `test_publish_catalogue.py` exercises this
behaviour using local Git repositories, with no network or compositor.
