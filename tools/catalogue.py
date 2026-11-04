#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Barrulus
"""Generate the shader catalogue without networking or executing contribution code.

Python 3.11+. Drafts read the working tree; production reads only Git objects.
This checks packaging/configuration, not GLSL compilation or visual suitability.
"""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tempfile
import tomllib


REPOSITORY = "https://github.com/noctalia-dev/community-umbriel-shaders"
KINDS = {"animation", "border", "window", "screen", "cursor"}
EVENTS = {
    "windows_in", "windows_out", "windows_move", "workspaces", "overview",
    "scratchpad", "border", "dim_unfocused", "layers",
}
USES = {f"animation.{event}" for event in EVENTS} | {
    f"effects.{kind}" for kind in KINDS - {"animation"}
}
TAGS = {
    "minimal", "glow", "geometric", "horror", "blood", "nature", "water", "fire",
    "glitch", "retro", "psychedelic", "colourful", "audio-reactive", "space",
    "playful", "fantasy", "texture", "circuit", "festival", "particles", "romantic", "example",
}
FEATURES = {
    "preset-effects": "Umbriel named effect presets and selectors; the original preset API was introduced at 512e2fb3.",
    "workspace-reveal-full-scene": "Full-scene workspace reveal: outgoing and incoming scene sampling, including umbriel_sample_incoming, with reveal mode. Older root-mask and scene-v1 interfaces are incompatible.",
    "cursor-pointer-history": "Cursor pointer history via umbriel_pointer_count and umbriel_pointer_path[64].",
}
STYLES = {
    "windows_in": {"popin", "zoom", "slide", "fade", "none"},
    "windows_out": {"fade", "slide", "popin", "zoom"},
    "workspaces": {"slide", "reveal"},
}
SPRINGS = {"defaultspring", "bouncy", "smooth", "stiff"}
CURVES = {"linear", "ease", "easein", "easeout", "easeinout", "snappy", "default", "overshoot",
          "quad", "cubic", "quart", "quint", "expo", "circ", "back", "elastic", "bounce"} | SPRINGS | {
    f"ease{direction}{shape}"
    for direction in ("in", "out", "inout")
    for shape in ("sine", "quad", "cubic", "quart", "quint", "expo", "circ", "back", "elastic", "bounce")
}
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
TEXT_LIMIT = 256 * 1024
FILE_LIMIT = 32 * 1024 * 1024
MAX_FILES = 10000
MAX_TOTAL_BYTES = 512 * 1024 * 1024
MAX_DEPENDENCY_DEPTH = 64
DOWNLOAD_SUFFIXES = {".toml", ".glsl", ".md", ".txt", ".png", ".gif", ".webp", ".mp4", ".webm"}


class CatalogueError(ValueError):
    """An authoring or packaging error suitable for a contributor diagnostic."""


def require(condition, message):
    if not condition:
        raise CatalogueError(message)


def table(value, where):
    require(isinstance(value, dict), f"{where}: expected a table")
    return value


def allow_keys(value, allowed, where):
    table(value, where)
    unknown = set(value) - set(allowed)
    require(not unknown, f"{where}: unknown fields: {', '.join(sorted(unknown))}")


def string(value, where):
    require(isinstance(value, str) and bool(value.strip()) and "\0" not in value,
            f"{where}: expected a nonempty string")
    return value


def strings(value, where, nonempty=False):
    require(isinstance(value, list), f"{where}: expected an array")
    for item in value:
        string(item, where)
    require(len(value) == len(set(value)), f"{where}: duplicate entries")
    require(not nonempty or bool(value), f"{where}: expected a nonempty array")
    return value


def number(value, low, high, where, integer=False):
    require(type(value) in ((int,) if integer else (int, float))
            and math.isfinite(value) and low <= value <= high,
            f"{where}: expected {'integer' if integer else 'number'} in {low}..{high}")


def relative_path(value):
    string(value, "path")
    require(not any(c in value for c in ("\\", "$", "~", ":", "%"))
            and not any(ord(c) < 32 or ord(c) == 127 for c in value),
            f"invalid repository path: {value!r}")
    parts = value.split("/")
    require(all(p not in ("", ".", "..") for p in parts), f"invalid repository path: {value!r}")
    return value


def runtime_path(parent, value):
    """Resolve preset-relative paths, allowing contained sibling references."""
    string(value, parent)
    require(not value.startswith("/") and not any(c in value for c in ("\\", "$", "~", ":", "%")),
            f"{parent}: invalid relative reference {value!r}")
    parts = parent.split("/") if parent else []
    for part in value.split("/"):
        if part == "..":
            require(bool(parts), f"{parent}: reference escapes repository: {value}")
            parts.pop()
        elif part not in ("", "."):
            parts.append(part)
    return relative_path("/".join(parts))


class Source:
    """Bounded regular-file reads from a checkout or a single immutable Git tree."""

    def __init__(self, root, revision=None):
        self.root = Path(root).resolve()
        self.revision = revision
        self.cache = {}
        self.entries = None
        if revision is not None:
            require(bool(re.fullmatch(r"[0-9a-f]{40}", revision)), "revision must be a full lowercase commit SHA")
            actual = self.git("rev-parse", "--verify", revision + "^{commit}").decode().strip()
            require(actual == revision, "revision must identify a commit")
            self.entries = {}
            for entry in self.git("ls-tree", "-r", "-l", "-z", revision).split(b"\0"):
                if not entry:
                    continue
                header, path = entry.split(b"\t", 1)
                mode, kind, oid, size = header.split()
                self.entries[path.decode("utf-8")] = (mode, kind, oid.decode(), size)

    def git(self, *args):
        try:
            return subprocess.run(["git", "-C", str(self.root), *args], check=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30).stdout
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            raise CatalogueError(f"Git source read failed: {' '.join(args)}") from error

    def exists(self, path):
        relative_path(path)
        if self.entries is not None:
            return path in self.entries
        # lexists also catches dangling links, so optional files cannot hide them.
        return os.path.lexists(self.root / path)

    def discover(self, prefix, filename):
        prefix = "" if prefix == "." else relative_path(prefix) + "/"
        if self.entries is not None:
            paths = [p for p in self.entries if p.startswith(prefix)
                     and p.endswith("/" + filename) and len(p[len(prefix):].split("/")) == 3]
        else:
            paths = [p.relative_to(self.root).as_posix()
                     for p in (self.root / prefix).glob(f"*/*/{filename}")]
        require(len(paths) <= MAX_FILES, "too many authoring files")
        return sorted(paths)

    def read(self, path, limit=TEXT_LIMIT):
        relative_path(path)
        if path not in self.cache:
            if self.entries is not None:
                require(path in self.entries, f"missing source file: {path}")
                mode, kind, oid, size = self.entries[path]
                require(mode == b"100644" and kind == b"blob", f"{path}: expected a non-executable regular file")
                require(int(size) <= limit, f"{path}: exceeds {limit} bytes")
                data = self.git("cat-file", "blob", oid)
            else:
                current = self.root
                for part in path.split("/"):
                    current = current / part
                    require(not current.is_symlink(), f"{path}: symlinks are forbidden")
                try:
                    info = current.stat()
                    require(stat.S_ISREG(info.st_mode) and not info.st_mode & 0o111,
                            f"{path}: expected a non-executable regular file")
                    require(info.st_size <= limit, f"{path}: exceeds {limit} bytes")
                    with current.open("rb") as stream:
                        data = stream.read(limit + 1)
                except OSError as error:
                    raise CatalogueError(f"{path}: {error.strerror}") from error
            require(len(data) <= limit, f"{path}: exceeds {limit} bytes")
            require(len(self.cache) < MAX_FILES, "too many source files")
            require(sum(map(len, self.cache.values())) + len(data) <= MAX_TOTAL_BYTES,
                    "source files exceed total byte limit")
            self.cache[path] = data
        require(len(self.cache[path]) <= limit, f"{path}: exceeds {limit} bytes")
        return self.cache[path]

    def toml(self, path):
        try:
            return tomllib.loads(self.read(path).decode("utf-8"))
        except (UnicodeError, tomllib.TOMLDecodeError) as error:
            raise CatalogueError(f"{path}: {error}") from error


def setting_scope(key):
    if key == "animation.enabled":
        return None
    if key.startswith("effects."):
        return key
    return ".".join(key.split(".")[:2])


def validate_setting(key, value):
    if key in USES and key.startswith("effects."):
        string(value, key)
        return
    if key == "animation.enabled":
        require(type(value) is bool, f"{key}: expected boolean")
        return
    parts = key.split(".")
    require(len(parts) == 3 and parts[0] == "animation" and parts[1] in EVENTS,
            f"unapproved activation setting: {key}")
    _, event, field = parts
    if field == "enabled":
        require(type(value) is bool, f"{key}: expected boolean")
    elif field == "effect":
        string(value, key)
    elif field == "duration_ms":
        number(value, 1, 10000, key, integer=True)
    elif field == "dim" and event in {"dim_unfocused", "scratchpad"}:
        number(value, 0, 1, key)
    elif field == "curve":
        require(isinstance(value, str) and value in CURVES, f"{key}: unsupported built-in curve")
    elif field == "style":
        require(isinstance(value, str) and value in STYLES.get(event, set()), f"{key}: unsupported style")
    elif field == "scale" and event in {"windows_in", "windows_out", "scratchpad"}:
        number(value, 0 if event == "scratchpad" else 0.1, 1, key)
    else:
        raise CatalogueError(f"unapproved activation setting: {key}")


def closure(effects, selected):
    found, visiting = set(), []

    def visit(effect_id):
        require(effect_id in effects, f"missing dependency/effect: {effect_id}")
        require(effect_id not in visiting, f"dependency cycle: {' -> '.join(visiting + [effect_id])}")
        if effect_id in found:
            return
        require(len(visiting) < MAX_DEPENDENCY_DEPTH, "dependency graph is too deep")
        visiting.append(effect_id)
        for dependency in effects[effect_id]["dependencies"]:
            visit(dependency)
        visiting.pop()
        found.add(effect_id)

    for effect_id in selected:
        visit(effect_id)
    return sorted(found)


def include_roots(effects, selected):
    selected = set(selected)
    indirect = {dep for effect_id in selected
                for dep in closure(effects, effects[effect_id]["dependencies"])}
    return [effects[e]["path"] + "/effect.toml" for e in sorted(selected - indirect)]


def requirements_for(effects, selected):
    features, settings = set(), {}
    for effect_id in closure(effects, selected):
        effect = effects[effect_id]
        features.update(effect["requirements"]["features"])
        for key, value in effect["required_settings"].items():
            require(key not in settings or (type(settings[key]) is type(value) and settings[key] == value),
                    f"conflicting requirement {key} from {effect_id}")
            settings[key] = value
    return sorted(features), dict(sorted(settings.items()))


def compatibility(features, evidence):
    """Evidence is a caller-supplied capability -> supported/unsupported/unknown map."""
    require(all(v in {"supported", "unsupported", "unknown"} for v in evidence.values()),
            "invalid compatibility evidence")
    incompatible = sorted(f for f in features if evidence.get(f) == "unsupported")
    unknown = sorted(f for f in features if evidence.get(f, "unknown") == "unknown")
    return {"status": "incompatible" if incompatible else "unknown" if unknown else "compatible",
            "incompatible": incompatible, "unknown": unknown}


class Generator:
    def __init__(self, source, metadata_root=".", *, include_unpublished=False):
        self.source = source
        if metadata_root != ".":
            relative_path(metadata_root)
        self.metadata_root = metadata_root
        require(source.revision is None or metadata_root == ".", "production cannot use draft metadata overlays")
        require(not include_unpublished or source.revision is None,
                "production cannot include unpublished entries")
        self.include_unpublished = include_unpublished
        self.effects = {}
        self.presets = {}
        self.files = {}
        self.warnings = []
        self.definitions = {}

    def metadata(self, path):
        meta = self.source.toml(path)
        return self.published_metadata(meta, path)

    def published_metadata(self, meta, path):
        table(meta, path)
        publish = meta.get("publish", False)
        require(type(publish) is bool, f"{path}: publish must be boolean")
        # Filter before reading presets, media, notices or family references so
        # incomplete experiments cannot leak files into the public registry.
        return meta if publish or self.include_unpublished else None

    def file(self, path):
        require(PurePosixPath(path).suffix in DOWNLOAD_SUFFIXES, f"{path}: unapproved downloadable file type")
        data = self.source.read(path, FILE_LIMIT if PurePosixPath(path).suffix in
                                {".png", ".gif", ".webp", ".mp4", ".webm"} else TEXT_LIMIT)
        self.files[path] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        return path

    def optional_file(self, path):
        return self.file(path) if self.source.exists(path) else None

    def presentation(self, path):
        animation = next((path + "/preview" + suffix for suffix in (".webm", ".mp4", ".gif")
                          if self.source.exists(path + "/preview" + suffix)), None)
        return {
            "preview": {"image": self.optional_file(path + "/preview.png"),
                        "animation": self.file(animation) if animation else None},
            "readme": self.optional_file(path + "/README.md"),
            "config_example": self.optional_file(path + "/config.toml"),
        }

    def read_preset(self, effect_id):
        path = effect_id + "/effect.toml"
        data = self.source.toml(path)
        allow_keys(data, {"include", "effects"}, path)
        allow_keys(data.get("effects"), {"preset"}, path + ": effects")
        presets = table(data["effects"].get("preset"), path + ": presets")
        require(len(presets) == 1, f"{path}: expected one local preset; packaging review required")
        name, preset = next(iter(presets.items()))
        string(name, path + ": preset name")
        require(name != "off" and "/" not in name, f"{path}: invalid preset name")
        require(name not in self.presets, f"{path}: duplicate preset name {name}")
        self.presets[name] = effect_id
        table(preset, path + ": preset")
        kind = effect_id.split("/")[0]
        require(preset.get("kind") == kind, f"{path}: kind must match directory")
        fields = {"kind", "shader", "palette"}
        if kind == "border":
            fields |= {"padding", "speed", "animated", "overlay", "light"}
        if kind == "cursor":
            fields.add("radius")
        allow_keys(preset, fields, path + ": preset")
        for field in ("palette", "animated"):
            if field in preset:
                require(type(preset[field]) is bool, f"{path}: {field} must be boolean")
        for field, bounds, integer in (("padding", (0, 1024), True), ("radius", (0, 4096), True),
                                       ("speed", (0, 10), False)):
            if field in preset:
                number(preset[field], *bounds, path + ": " + field, integer=integer)
        if "light" in preset:
            light = preset["light"]
            allow_keys(light, {"spread", "intensity", "threshold"}, path + ": light")
            for field, bounds in (("spread", (1, 256)), ("intensity", (0, 4)), ("threshold", (0, 1))):
                if field in light:
                    number(light[field], *bounds, path + ": light." + field, integer=field == "spread")
        if "overlay" in preset:
            require(isinstance(preset["overlay"], str), f"{path}: overlay must be a string")
        shader = runtime_path(effect_id, preset.get("shader"))
        require(shader.startswith(effect_id + "/") and shader.endswith(".glsl"),
                f"{path}: shader must belong to its effect directory")
        raw = self.source.read(shader)
        try:
            code = raw.decode("utf-8")
        except UnicodeError as error:
            raise CatalogueError(f"{shader}: expected UTF-8") from error
        code = re.sub(r"/\*.*?\*/|//[^\n]*", "", code, flags=re.S)
        require(bool(re.search(r"\bvec4\s+" + kind + r"\s*\(\s*vec2\s+\w+\s*\)", code)),
                f"{shader}: missing {kind}(vec2) entry point")
        require(not re.search(r"^\s*#\s*(version|include)\b|\bvoid\s+main\s*\(", code, re.M),
                f"{shader}: wrapper-owned version/main or shader include is forbidden")
        includes = data.get("include", {})
        allow_keys(includes, {"files"}, path + ": include")
        dependencies = []
        for ref in strings(includes.get("files", []), path + ": include.files"):
            target = runtime_path(effect_id, ref)
            require(target.endswith("/effect.toml"), f"{path}: includes must reference effect.toml")
            dependencies.append(target.removesuffix("/effect.toml"))
        self.definitions[effect_id] = preset
        return name, shader, sorted(set(dependencies))

    def read_effect(self, metadata_path):
        relative = metadata_path if self.metadata_root == "." else metadata_path[len(self.metadata_root) + 1:]
        effect_id = relative.removesuffix("/metadata.toml")
        kind, slug = effect_id.split("/")
        require(kind in KINDS and bool(SLUG.fullmatch(slug)), f"{metadata_path}: invalid effect ID")
        meta = self.metadata(metadata_path)
        if meta is None:
            return
        allow_keys(meta, {"name", "description", "author", "license", "notice_files", "uses", "tags",
                          "role", "requirements", "required_settings", "tested_on", "publish"}, metadata_path)
        for key in ("name", "description", "author", "license"):
            string(meta.get(key), metadata_path + ": " + key)
        notices = strings(meta.get("notice_files"), metadata_path + ": notice_files", nonempty=True)
        for notice in notices:
            require(PurePosixPath(notice).suffix in {".txt", ".md"}, f"{notice}: notices must be text or Markdown")
            self.file(relative_path(notice))
        tags = strings(meta.get("tags", []), metadata_path + ": tags")
        require(set(tags) <= TAGS, f"{metadata_path}: unreviewed tags {sorted(set(tags) - TAGS)}")
        role = meta.get("role", "effect")
        require(role in ("effect", "companion"), f"{metadata_path}: invalid role")
        default_uses = [] if role == "companion" or kind == "animation" else ["effects." + kind]
        uses = strings(meta.get("uses", default_uses), metadata_path + ": uses", nonempty=role == "effect")
        allowed_uses = {u for u in USES if u.startswith("animation.")} if kind == "animation" else {"effects." + kind}
        require(set(uses) <= allowed_uses, f"{metadata_path}: uses do not match kind")
        requirements = meta.get("requirements", {})
        allow_keys(requirements, {"features"}, metadata_path + ": requirements")
        features = strings(requirements.get("features", []), metadata_path + ": features")
        require(set(features) <= FEATURES.keys(), f"{metadata_path}: feature labels need a reviewed definition")
        required = table(meta.get("required_settings", {}), metadata_path + ": required_settings")
        for key, value in required.items():
            validate_setting(key, value)
            require(not key.startswith("effects.") and not key.endswith(".effect"),
                    f"{metadata_path}: required_settings cannot select another effect")
        tested = strings(meta.get("tested_on", []), metadata_path + ": tested_on")
        name, shader, dependencies = self.read_preset(effect_id)
        record = {"id": effect_id, "path": effect_id,
                  **{key: meta[key] for key in ("name", "description", "author", "license")},
                  "notice_files": notices, "tags": tags, "role": role, "kind": kind, "preset": name,
                  "uses": uses, "dependencies": dependencies, "families": [],
                  "requirements": {"features": ["preset-effects"] + sorted(set(features) - {"preset-effects"})},
                  "required_settings": dict(sorted(required.items())), "tested_on": tested,
                  "install_files": sorted(set(notices + [effect_id + "/effect.toml", shader])),
                  **self.presentation(effect_id), "activation": None}
        for path in record["install_files"]:
            self.file(path)
        self.effects[effect_id] = record

    def recipe(self, path, members):
        if path is None:
            return None
        data = self.source.toml(path)
        allow_keys(data, {"include", "effects", "animation"}, path)
        include = data.get("include", {})
        allow_keys(include, {"files"}, path + ": include")
        included = []
        for ref in strings(include.get("files", []), path + ": include.files"):
            require(ref.startswith("shaders/community/"), f"{path}: expected shaders/community/ include prefix")
            ref = relative_path(ref.removeprefix("shaders/community/"))
            require(ref.endswith("/effect.toml"), f"{path}: expected preset include")
            included.append(ref.removesuffix("/effect.toml"))
        available = closure(self.effects, included)
        require(set(included) <= set(closure(self.effects, members)), f"{path}: unrelated preset includes")
        settings = {}
        manual = []

        def flatten(value, prefix):
            table(value, path + ": " + prefix)
            require(bool(value), f"{path}: empty activation table {prefix}")
            for key, item in value.items():
                require("." not in key, f"{path}: quoted dotted activation key is not a nested table")
                full = prefix + "." + key
                if isinstance(item, dict):
                    flatten(item, full)
                else:
                    # Explicitly reviewed manual-only example settings. Do not
                    # broaden the executable recipe allowlist to accommodate them.
                    if full == "effects.max_fps":
                        number(item, 0, 240, full, integer=True)
                        manual.append(full)
                        continue
                    if full == "effects.in_capture":
                        require(type(item) is bool, f"{full}: expected boolean")
                        manual.append(full)
                        continue
                    validate_setting(full, item)
                    settings[full] = item

        for section in ("effects", "animation"):
            if section in data:
                flatten(data[section], section)
        selections = {}
        for key, value in settings.items():
            if key.startswith("effects.") or key.endswith(".effect"):
                scope = setting_scope(key)
                require(value in self.presets, f"{path}: unknown selected preset {value}")
                effect_id = self.presets[value]
                require(effect_id in members and effect_id in available, f"{path}: selection is not an included member")
                require(scope in self.effects[effect_id]["uses"], f"{path}: {effect_id} does not declare use {scope}")
                selections[scope] = effect_id
        require(bool(selections), f"{path}: example does not select an effect")
        for key in settings:
            require(setting_scope(key) is None or setting_scope(key) in selections,
                    f"{path}: setting without a selected slot: {key}")
        for scope in selections:
            require(not (settings.get(scope + ".curve") in SPRINGS and scope + ".duration_ms" in settings),
                    f"{path}: spring curve determines its duration; remove {scope}.duration_ms")
        _, required = requirements_for(self.effects, selections.values())
        for key, value in required.items():
            require(key not in settings or (type(settings[key]) is type(value) and settings[key] == value),
                    f"{path}: recipe conflicts with required setting {key}")
        if manual:
            self.warnings.append(f"{path}: manual-only settings {', '.join(manual)}; activation is null")
            return None
        return {"include": include_roots(self.effects, included), "settings": dict(sorted(settings.items()))}

    def build(self):
        metadata = self.source.discover(self.metadata_root, "metadata.toml")
        require(bool(metadata), "no effect metadata found")
        for path in metadata:
            self.read_effect(path)
        for effect_id, effect in self.effects.items():
            for dependency in effect["dependencies"]:
                require(dependency in self.effects,
                        f"{effect_id}: dependency {dependency} is missing or unpublished")
            dependencies = closure(self.effects, effect["dependencies"])
            overlay = self.definitions[effect_id].get("overlay", "")
            if overlay:
                target = self.presets.get(overlay)
                require(target in dependencies and self.effects[target]["kind"] == "window",
                        f"{effect_id}: overlay must resolve to an included window dependency")
            requirements_for(self.effects, [effect_id])
        for effect_id, effect in self.effects.items():
            # Companion-only examples intentionally select the parent border. They
            # are documentation, not an independent activation recipe.
            effect["activation"] = self.recipe(effect["config_example"], [effect_id]) if effect["uses"] else None
        families = []
        family_path = "families.toml" if self.metadata_root == "." else self.metadata_root + "/families.toml"
        definitions = self.source.toml(family_path) if self.source.exists(family_path) else {}
        allow_keys(definitions, {"families"}, family_path)
        definitions = table(definitions.get("families", {}), family_path + ": families")
        for family_id, definition in sorted(definitions.items()):
            path = family_path + ": " + family_id
            require(bool(SLUG.fullmatch(family_id)), f"{path}: invalid family ID")
            meta = self.published_metadata(definition, path)
            if meta is None:
                continue
            allow_keys(meta, {"name", "description", "members", "tags", "publish", "defaults"}, path)
            for key in ("name", "description"):
                string(meta.get(key), path + ": " + key)
            members = strings(meta.get("members"), path + ": members", nonempty=True)
            for member in members:
                require(member in self.effects,
                        f"{path}: member {member} is missing or unpublished")
            closure(self.effects, members)
            tags = strings(meta.get("tags", []), path + ": tags")
            require(set(tags) <= TAGS, f"{path}: unreviewed tags")
            defaults = table(meta.get("defaults", {}), path + ": defaults")
            for slot, member in defaults.items():
                string(member, path + ": default member")
                require(member in members, f"{path}: default selection is not a member: {member}")
                require(slot in self.effects[member]["uses"], f"{path}: unsupported default use {slot}")
            recipe = None
            if defaults:
                plan = activation_for({"effects": list(self.effects.values()), "families": []}, defaults)
                recipe = {"include": plan["include"], "settings": plan["settings"]}
            for member in members:
                self.effects[member]["families"].append(family_id)
            families.append({"id": family_id, "name": meta["name"],
                             "description": meta["description"], "members": members, "tags": tags,
                             "authors": sorted({self.effects[m]["author"] for m in closure(self.effects, members)}),
                             "preview": {"image": None, "animation": None},
                             "readme": None, "config_example": None, "activation": recipe})
        return {"schema_version": 1, "draft": self.source.revision is None,
                "source": {"repository": REPOSITORY, "revision": self.source.revision},
                "feature_definitions": FEATURES.copy(),
                "effects": [self.effects[k] for k in sorted(self.effects)],
                "families": sorted(families, key=lambda f: f["id"]),
                "files": dict(sorted(self.files.items()))}


def activation_for(registry, selections, *, family=None, evidence=None):
    """Pure review planner for generated data; never installs or executes anything.

    selections maps a global catalogue use to an effect ID. Window/output rule
    conversion remains the future plugin's responsibility. This is not a parser
    or trust boundary for arbitrary downloaded JSON.
    """
    effects = {e["id"]: e for e in registry["effects"]}
    require(bool(selections), "choose at least one slot")
    family_record = None
    if family is not None:
        family_record = next((f for f in registry["families"] if f["id"] == family), None)
        require(family_record is not None, f"unknown family: {family}")
    settings = {}
    for slot, effect_id in selections.items():
        require(effect_id in effects and slot in effects[effect_id]["uses"],
                f"{effect_id}: unsupported selection {slot}")
        if family_record:
            require(effect_id in family_record["members"], f"{effect_id}: not in family {family}")
        recipe = effects[effect_id]["activation"]
        selector = slot + ".effect" if slot.startswith("animation.") else slot
        # Family recommendations apply only when they recommend this chosen member.
        if family_record and family_record["activation"] and \
                family_record["activation"]["settings"].get(selector) == effects[effect_id]["preset"]:
            recipe = family_record["activation"]
        require(recipe is not None and recipe["settings"].get(selector) == effects[effect_id]["preset"],
                f"{effect_id}: no recipe for {slot}; manual configuration required")
        for key, value in recipe["settings"].items():
            if setting_scope(key) == slot or (key == "animation.enabled" and slot.startswith("animation.")):
                require(key not in settings or settings[key] == value, f"conflicting recommendation: {key}")
                settings[key] = value
    features, required = requirements_for(effects, selections.values())
    prerequisites = {}
    for key, value in required.items():
        require(key not in settings or (type(settings[key]) is type(value) and settings[key] == value),
                f"conflicting required setting: {key}")
        if setting_scope(key) in selections or key == "animation.enabled":
            settings[key] = value
        else:
            # The plugin must review these conditions separately; selecting a
            # border must not silently alter a different event's settings.
            prerequisites[key] = value
    status = compatibility(features, evidence or {})
    require(status["status"] != "incompatible", f"incompatible capabilities: {', '.join(status['incompatible'])}")
    # The maintained catalogue targets latest Umbriel. Missing capability evidence
    # is diagnostic only; actual incompatibility and invalid settings still fail.
    selected = closure(effects, selections.values())
    return {"include": include_roots(effects, selections.values()), "settings": dict(sorted(settings.items())),
            "effects": selected, "files": sorted({p for e in selected for p in effects[e]["install_files"]}),
            "prerequisites": prerequisites, "compatibility": status}


def library_update(current, target, installed, additions=()):
    """Describe a coherent single-snapshot update; assumes caller-verified old bytes.

    No network, filesystem mutation, compositor apply, or local-edit detection.
    """
    old = {e["id"]: e for e in current["effects"]}
    new = {e["id"]: e for e in target["effects"]}
    old_ids = closure(old, installed)
    # Preserve installed effects, including companions, unless explicitly removed.
    new_ids = closure(new, set(old_ids) | set(additions))
    requirements_for(new, new_ids)
    old_files = {p for e in old_ids for p in old[e]["install_files"]}
    new_files = {p for e in new_ids for p in new[e]["install_files"]}
    downloads = sorted(p for p in new_files if p not in old_files or current["files"][p] != target["files"][p])
    return {"source": target["source"].copy(), "effects": new_ids,
            "download_files": downloads, "remove_files": sorted(old_files - new_files),
            "changed_effects": sorted(e for e in new_ids if e not in old or new[e] != old[e]
                                      or any(p in downloads for p in new[e]["install_files"]))}


def encode(registry):
    return json.dumps(registry, indent=2, ensure_ascii=False, allow_nan=False) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--draft", action="store_true", help="read working-tree files; never installable")
    mode.add_argument("--revision", help="read all source files from this full Git commit SHA")
    parser.add_argument("--metadata-root", default=".", help="draft-only metadata overlay relative to root")
    parser.add_argument("--include-unpublished", action="store_true",
                        help="draft-only: also validate and list experimental effects and families")
    output = parser.add_mutually_exclusive_group(required=True)
    output.add_argument("--output", type=Path, help="atomically replace this JSON file after validation")
    output.add_argument("--check", type=Path, help="fail if this JSON file differs from generated output")
    args = parser.parse_args(argv)
    temporary = None
    try:
        generator = Generator(Source(args.root, args.revision), args.metadata_root,
                              include_unpublished=args.include_unpublished)
        registry = generator.build()
        for warning in generator.warnings:
            print(f"catalogue: {warning}", file=sys.stderr)
        text = encode(registry)
        if args.check:
            require(args.check.read_text() == text, f"{args.check}: catalogue is stale; regenerate it")
        else:
            destination = args.output.absolute()
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=destination.parent,
                                             prefix=".catalogue-", delete=False) as stream:
                temporary = Path(stream.name)
                stream.write(text)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, destination)
            temporary = None
        print(f"Validated {len(registry['effects'])} effects, {len(registry['families'])} families, "
              f"{len(registry['files'])} files ({'draft' if registry['draft'] else registry['source']['revision']}).")
        return 0
    except (CatalogueError, OSError, UnicodeError) as error:
        print(f"catalogue: {error}", file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main())
