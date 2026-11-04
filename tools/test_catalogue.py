#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Barrulus
"""Catalogue contract checks using isolated source trees, with no compositor."""

import contextlib
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import catalogue as c


ROOT = Path(__file__).resolve().parents[1]


class AnimationSettingTests(unittest.TestCase):
    def test_dim_settings_are_bounded_and_targeted(self):
        c.validate_setting("animation.dim_unfocused.dim", 0.2)
        c.validate_setting("animation.scratchpad.dim", 0.8)
        for key, value in [("animation.border.dim", 0.2), ("animation.dim_unfocused.dim", -0.1),
                           ("animation.scratchpad.dim", 1.1), ("animation.dim_unfocused.dim", True)]:
            with self.subTest(key=key, value=value), self.assertRaises(c.CatalogueError):
                c.validate_setting(key, value)

    def test_example_tag_is_supported(self):
        self.assertIn("example", c.TAGS)


class TreeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="shader catalogue ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write("LICENSES/test.txt", "Test notice\n")

    def write(self, path, text):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)
        return destination

    def effect(self, effect_id, *, uses=None, role="effect", dependencies=(), overlay=None,
               features=(), required=None, recipe=True, name=None):
        kind, slug = effect_id.split("/")
        name = name or slug
        metadata = (f'publish = true\nname = "{slug}"\ndescription = "A test effect."\nauthor = "Test author"\n'
                    f'license = "MIT"\nnotice_files = ["LICENSES/test.txt"]\nrole = "{role}"\n')
        if uses is not None:
            metadata += "uses = " + json.dumps(uses) + "\n"
        if features:
            metadata += "[requirements]\nfeatures = " + json.dumps(list(features)) + "\n"
        if required:
            metadata += "[required_settings]\n" + "".join(
                json.dumps(k) + " = " + json.dumps(v) + "\n" for k, v in required.items())
        self.write(effect_id + "/metadata.toml", metadata)
        includes = ["../../" + dep + "/effect.toml" for dep in dependencies]
        definition = "[include]\nfiles = " + json.dumps(includes) + "\n" if includes else ""
        definition += f'[effects.preset."{name}"]\nkind = "{kind}"\nshader = "shader.glsl"\n'
        if overlay:
            definition += f'overlay = "{overlay}"\n'
        self.write(effect_id + "/effect.toml", definition)
        self.write(effect_id + "/shader.glsl", f"vec4 {kind}(vec2 uv) {{ return vec4(0.0); }}\n")
        if recipe:
            config = f'[include]\nfiles = ["shaders/community/{effect_id}/effect.toml"]\n'
            if kind == "animation":
                config += "[animation]\nenabled = true\n"
                for index, use in enumerate(uses or []):
                    config += (f'[{use}]\neffect = "{name}"\nenabled = true\n'
                               f'duration_ms = {600 + index * 100}\ncurve = "linear"\n')
            else:
                config += f'[effects]\n{kind} = "{name}"\n'
            self.write(effect_id + "/config.toml", config)

    def build(self, **options):
        return c.Generator(c.Source(self.root), **options).build()

    def modify(self, path, old, new):
        full = self.root / path
        self.assertIn(old, full.read_text())
        full.write_text(full.read_text().replace(old, new))

    def vine(self):
        self.effect("window/overlay", role="companion", recipe=False)
        self.effect("border/vine", dependencies=["window/overlay"], overlay="overlay")

    def test_unpublished_entries_and_their_files_are_excluded_by_default(self):
        self.effect("cursor/glow")
        self.effect("window/hidden")
        self.effect("screen/no-flag")
        self.modify("window/hidden/metadata.toml", "publish = true", "publish = false")
        self.modify("screen/no-flag/metadata.toml", "publish = true\n", "")
        # These experiments are not required to have working presets or media.
        self.write("window/hidden/effect.toml", "unfinished = [")
        self.write("screen/no-flag/shader.glsl", "unfinished")
        self.write("window/hidden/preview.png", "unpublished preview")
        registry = self.build()
        self.assertEqual([e["id"] for e in registry["effects"]], ["cursor/glow"])
        self.assertFalse(any(p.startswith(("window/hidden/", "screen/no-flag/"))
                             for p in registry["files"]))
        self.assertNotIn("window/hidden/effect.toml", c.activation_for(
            registry, {"effects.cursor": "cursor/glow"})["files"])

    def test_all_entries_can_be_unpublished(self):
        self.write("cursor/experiment/metadata.toml", "publish = false\n")
        registry = self.build()
        self.assertEqual(registry["effects"], [])
        self.assertEqual(registry["families"], [])
        self.assertEqual(registry["files"], {})

    def test_publication_flag_requires_a_boolean_for_effects_and_families(self):
        self.effect("cursor/glow")
        for path in ("cursor/glow/metadata.toml", "families.toml"):
            original = (self.root / path).read_text() if (self.root / path).exists() else None
            for value in ('"true"', '"false"', "1", "[]"):
                with self.subTest(path=path, value=value):
                    self.write(path, ("[families.test]\n" if path == "families.toml" else "") + "publish = " + value + "\n")
                    with self.assertRaisesRegex(c.CatalogueError, "publish must be boolean"):
                        self.build()
            if original is not None:
                self.write(path, original)

    def test_unpublished_family_adds_no_backlinks_or_files(self):
        self.effect("cursor/glow")
        for flag in ("", "publish = false\n"):
            with self.subTest(flag=flag):
                self.write("families.toml", "[families.test]\n" + flag + 'members = ["cursor/glow", "cursor/unfinished"]\n')

                registry = self.build()
                self.assertEqual(registry["families"], [])
                self.assertEqual(registry["effects"][0]["families"], [])
                self.assertNotIn("families.toml", registry["files"])

    def test_published_effect_cannot_pull_in_an_unpublished_companion(self):
        self.vine()
        self.modify("window/overlay/metadata.toml", "publish = true", "publish = false")
        with self.assertRaisesRegex(c.CatalogueError, "dependency window/overlay is missing or unpublished"):
            self.build()

    def test_published_family_cannot_contain_unpublished_members(self):
        self.effect("cursor/glow")
        self.modify("cursor/glow/metadata.toml", "publish = true", "publish = false")
        self.write("families.toml", "[families.test]\n" + 'publish = true\nname = "Test"\ndescription = "Test"\nmembers = ["cursor/glow"]\n')
        with self.assertRaisesRegex(c.CatalogueError, "member cursor/glow is missing or unpublished"):
            self.build()

    def test_explicit_local_authoring_mode_includes_unpublished_entries(self):
        self.effect("cursor/glow")
        self.modify("cursor/glow/metadata.toml", "publish = true", "publish = false")
        self.write("families.toml", "[families.test]\n" + 'name = "Test"\ndescription = "Test"\nmembers = ["cursor/glow"]\n')
        registry = self.build(include_unpublished=True)
        self.assertTrue(registry["draft"])
        self.assertEqual([e["id"] for e in registry["effects"]], ["cursor/glow"])
        self.assertEqual(registry["effects"][0]["families"], ["test"])
        self.assertEqual(registry["families"][0]["members"], ["cursor/glow"])
        self.write("cursor/glow/shader.glsl", "unfinished")
        with self.assertRaisesRegex(c.CatalogueError, "missing cursor"):
            self.build(include_unpublished=True)

    def test_production_uses_committed_publication_flags(self):
        self.effect("cursor/glow")
        self.effect("window/hidden")
        self.modify("window/hidden/metadata.toml", "publish = true", "publish = false")
        revision = self.commit()
        self.modify("window/hidden/metadata.toml", "publish = false", "publish = true")
        registry = c.Generator(c.Source(self.root, revision)).build()
        self.assertEqual([e["id"] for e in registry["effects"]], ["cursor/glow"])
        self.assertFalse(any(p.startswith("window/hidden/") for p in registry["files"]))
        with self.assertRaisesRegex(c.CatalogueError, "production cannot include unpublished"):
            c.Generator(c.Source(self.root, revision), include_unpublished=True)

    def test_cli_unpublished_mode_cannot_produce_a_production_snapshot(self):
        self.effect("cursor/glow")
        self.modify("cursor/glow/metadata.toml", "publish = true", "publish = false")
        revision = self.commit()
        output = self.write("registry.json", "previous registry\n")
        args = ["--root", str(self.root), "--include-unpublished", "--output", str(output)]
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(c.main(args + ["--revision", revision]), 1)
        self.assertEqual(output.read_text(), "previous registry\n")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(c.main(args + ["--draft"]), 0)
        registry = json.loads(output.read_text())
        self.assertTrue(registry["draft"])
        self.assertEqual([e["id"] for e in registry["effects"]], ["cursor/glow"])

    def test_companion_defaults_to_dependency_only_and_installs_once(self):
        self.vine()
        r = self.build()
        companion = next(e for e in r["effects"] if e["role"] == "companion")
        self.assertEqual(companion["uses"], [])
        self.assertIsNone(companion["activation"])
        plan = c.activation_for(r, {"effects.border": "border/vine"})
        self.assertEqual(plan["include"], ["border/vine/effect.toml"])
        self.assertEqual(plan["effects"], ["border/vine", "window/overlay"])
        self.assertEqual(plan["files"].count("LICENSES/test.txt"), 1)
        self.assertNotIn("effects.window", plan["settings"])
        with self.assertRaisesRegex(c.CatalogueError, "unsupported selection"):
            c.activation_for(r, {"effects.window": "window/overlay"})

    def test_companion_documentation_can_select_parent_without_becoming_recipe(self):
        self.vine()
        self.write("window/overlay/config.toml", '[include]\nfiles = ["shaders/community/border/vine/effect.toml"]\n[effects]\nborder = "vine"\n')
        r = self.build()
        companion = next(e for e in r["effects"] if e["id"] == "window/overlay")
        self.assertEqual(companion["config_example"], "window/overlay/config.toml")
        self.assertIsNone(companion["activation"])
        self.assertEqual(companion["uses"], [])

    def test_explicit_standalone_companion_requires_no_duplicate_include(self):
        self.effect("window/overlay", role="companion", uses=["effects.window"])
        self.effect("border/vine", dependencies=["window/overlay"], overlay="overlay")
        plan = c.activation_for(self.build(), {"effects.border": "border/vine", "effects.window": "window/overlay"})
        self.assertEqual(plan["include"], ["border/vine/effect.toml"])
        self.assertEqual(plan["settings"], {"effects.border": "vine", "effects.window": "overlay"})

    def test_companion_recipe_cannot_infer_a_standalone_use(self):
        self.effect("window/overlay", role="companion")
        record = self.build()["effects"][0]
        self.assertEqual(record["uses"], [])
        self.assertIsNone(record["activation"])

    def test_opening_selection_does_not_change_closing(self):
        self.effect("animation/wobble", uses=["animation.windows_in", "animation.windows_out"])
        r = self.build()
        plan = c.activation_for(r, {"animation.windows_in": "animation/wobble"})
        self.assertEqual(plan["settings"], {"animation.enabled": True, "animation.windows_in.enabled": True,
                         "animation.windows_in.effect": "wobble", "animation.windows_in.curve": "linear",
                         "animation.windows_in.duration_ms": 600})

    def test_partial_family_uses_only_chosen_slots_and_recommendations(self):
        self.effect("cursor/glow")
        self.effect("animation/wobble", uses=["animation.windows_in", "animation.windows_out"])
        self.write("families.toml", "[families.test]\n" + 'publish = true\nname = "Test"\ndescription = "Test family"\n'
                   'members = ["animation/wobble", "cursor/glow"]\n')
        self.modify("families.toml", 'members = ["animation/wobble", "cursor/glow"]\n',
                    'members = ["animation/wobble", "cursor/glow"]\n'
                    '[families.test.defaults]\n"effects.cursor" = "cursor/glow"\n'
                    '"animation.windows_in" = "animation/wobble"\n')
        r = self.build()
        plan = c.activation_for(r, {"effects.cursor": "cursor/glow"}, family="test")
        self.assertEqual(plan["settings"], {"effects.cursor": "glow"})
        self.assertEqual(plan["effects"], ["cursor/glow"])
        opening = c.activation_for(r, {"animation.windows_in": "animation/wobble"}, family="test")
        self.assertEqual(opening["settings"]["animation.windows_in.duration_ms"], 600)
        self.assertNotIn("effects.cursor", opening["settings"])

    def test_dependency_requirements_are_diagnostic_unless_known_incompatible(self):
        self.effect("window/overlay", role="companion", recipe=False, features=["cursor-pointer-history"])
        self.effect("border/vine", dependencies=["window/overlay"], overlay="overlay")
        r = self.build()
        selection = {"effects.border": "border/vine"}
        evidence = {"preset-effects": "supported"}
        plan = c.activation_for(r, selection, evidence=evidence)
        self.assertEqual(plan["compatibility"]["unknown"], ["cursor-pointer-history"])
        evidence["cursor-pointer-history"] = "unsupported"
        with self.assertRaisesRegex(c.CatalogueError, "incompatible capabilities"):
            c.activation_for(r, selection, evidence=evidence)
        evidence["cursor-pointer-history"] = "supported"
        self.assertEqual(c.activation_for(r, selection, evidence=evidence)["compatibility"]["status"], "compatible")

    def test_unrecognized_capability_is_unknown_to_consumer(self):
        result = c.compatibility(["future-api"], {})
        self.assertEqual(result, {"status": "unknown", "unknown": ["future-api"], "incompatible": []})

    def test_required_settings_conflict_between_dependencies(self):
        self.effect("window/one", role="companion", recipe=False, required={"animation.enabled": True})
        self.effect("window/two", role="companion", recipe=False, required={"animation.enabled": False})
        self.effect("border/vine", dependencies=["window/one", "window/two"])
        with self.assertRaisesRegex(c.CatalogueError, "conflicting requirement"):
            self.build()

    def test_required_settings_cannot_select_undeclared_effects(self):
        self.effect("cursor/glow", required={"effects.window": "surprise"})
        with self.assertRaisesRegex(c.CatalogueError, "cannot select another effect"):
            self.build()

    def test_required_settings_conflict_with_recipe(self):
        self.effect("animation/iris", uses=["animation.workspaces"],
                    required={"animation.workspaces.style": "reveal"})
        path = self.root / "animation/iris/config.toml"
        path.write_text(path.read_text() + 'style = "slide"\n')
        with self.assertRaisesRegex(c.CatalogueError, "conflicts with required"):
            self.build()

    def test_out_of_scope_requirements_need_separate_review(self):
        self.effect("window/overlay", role="companion", recipe=False,
                    required={"animation.workspaces.style": "reveal"})
        self.effect("border/vine", dependencies=["window/overlay"], overlay="overlay")
        plan = c.activation_for(self.build(), {"effects.border": "border/vine"})
        self.assertEqual(plan["settings"], {"effects.border": "vine"})
        self.assertEqual(plan["prerequisites"], {"animation.workspaces.style": "reveal"})

    def test_updates_shared_dependencies_once_and_reuses_unchanged_bytes(self):
        self.vine()
        current = self.build()
        self.effect("border/second", dependencies=["window/overlay"], overlay="overlay")
        self.write("window/overlay/shader.glsl", "vec4 window(vec2 uv) { return vec4(1.0); }\n")
        target = self.build()
        plan = c.library_update(current, target, ["border/vine"], ["border/second"])
        self.assertEqual(plan["effects"], ["border/second", "border/vine", "window/overlay"])
        self.assertEqual(plan["download_files"], ["border/second/effect.toml", "border/second/shader.glsl",
                                                "window/overlay/shader.glsl"])
        self.assertNotIn("LICENSES/test.txt", plan["download_files"])
        self.assertEqual(plan["remove_files"], [])

    def test_update_does_not_silently_remove_installed_effect(self):
        self.vine()
        current = self.build()
        target = copy.deepcopy(current)
        target["effects"] = [e for e in target["effects"] if e["id"] != "window/overlay"]
        with self.assertRaisesRegex(c.CatalogueError, "missing dependency"):
            c.library_update(current, target, ["border/vine"])

    def test_invalid_metadata_fields_types_and_uses(self):
        self.effect("cursor/glow")
        path = self.root / "cursor/glow/metadata.toml"
        original = path.read_text()
        cases = [('author = "Test author"', 'author = 12', "nonempty string"),
                 ('role = "effect"', 'role = "other"', "invalid role"),
                 ('role = "effect"', 'uses = ["animation.windows_in"]', "uses do not match"),
                 ('role = "effect"', 'uses = []', "nonempty array"),
                 ('role = "effect"', 'tags = ["not-reviewed"]', "unreviewed tags"),
                 ('role = "effect"', 'author_url = "https://example.com"', "unknown fields"),
                 ('role = "effect"', 'tags = ["glow", "glow"]', "duplicate entries"),
                 ('role = "effect"', '[requirements]\nfeatures = ["future-api"]', "reviewed definition")]
        for old, new, message in cases:
            with self.subTest(new=new):
                path.write_text(original.replace(old, new))
                with self.assertRaisesRegex(c.CatalogueError, message):
                    self.build()

    def test_animation_requires_explicit_uses(self):
        self.effect("animation/open", recipe=False)
        with self.assertRaisesRegex(c.CatalogueError, "nonempty array"):
            self.build()

    def test_multiple_presets_and_name_collisions_are_rejected(self):
        self.effect("cursor/glow")
        self.effect("window/second", name="glow")
        with self.assertRaisesRegex(c.CatalogueError, "duplicate preset"):
            self.build()
        self.effect("window/second")
        p = self.root / "window/second/effect.toml"
        p.write_text(p.read_text() + '[effects.preset.third]\nkind = "window"\nshader = "shader.glsl"\n')
        with self.assertRaisesRegex(c.CatalogueError, "one local preset"):
            self.build()

    def test_missing_dependencies_and_cycles_are_rejected(self):
        self.effect("window/one", dependencies=["window/two"])
        with self.assertRaisesRegex(c.CatalogueError, "missing or unpublished"):
            self.build()
        self.effect("window/two", dependencies=["window/one"])
        with self.assertRaisesRegex(c.CatalogueError, "dependency cycle"):
            self.build()

    def test_overlay_must_be_an_included_window_preset(self):
        self.effect("window/overlay")
        self.effect("border/vine", overlay="overlay")
        with self.assertRaisesRegex(c.CatalogueError, "included window dependency"):
            self.build()

    def test_untrusted_preset_configuration_is_rejected(self):
        self.effect("cursor/glow")
        path = self.root / "cursor/glow/effect.toml"
        original = path.read_text()
        for addition in ('\n[general]\nautostart = ["touch /tmp/never-run"]\n',
                         '\n[effects]\ncursor = "glow"\n',
                         '\n[include.optional]\nfiles = ["optional.toml"]\n',
                         '\n[effects.pool.test]\nkind = "cursor"\nchoose = ["glow"]\n'):
            with self.subTest(addition=addition):
                path.write_text(original + addition)
                with self.assertRaisesRegex(c.CatalogueError, "unknown fields"):
                    self.build()

    def test_preset_ranges_types_and_kind_specific_fields(self):
        self.effect("cursor/glow")
        path = self.root / "cursor/glow/effect.toml"
        original = path.read_text()
        for addition in ('radius = true', 'radius = -1', 'radius = 4097', 'palette = 1',
                         'speed = 1', 'interface = "scene-v1"'):
            with self.subTest(addition=addition):
                path.write_text(original + addition + "\n")
                with self.assertRaises(c.CatalogueError):
                    self.build()

    def test_paths_cannot_escape_or_expand(self):
        self.effect("cursor/glow")
        path = self.root / "cursor/glow/effect.toml"
        original = path.read_text()
        for ref in ('/tmp/outside.glsl', '../../../outside.glsl', '$HOME/test.glsl', '~/test.glsl',
                    'https://example.com/file.glsl', '../../cursor/other/shader.glsl', '%2e%2e/file.glsl'):
            with self.subTest(ref=ref):
                path.write_text(original.replace('"shader.glsl"', json.dumps(ref)))
                with self.assertRaises(c.CatalogueError):
                    self.build()

    def test_notice_paths_are_root_relative_and_restricted(self):
        self.effect("cursor/glow")
        path = self.root / "cursor/glow/metadata.toml"
        original = path.read_text()
        for ref in ('../outside.txt', '/tmp/outside.txt', 'LICENSES/../LICENSES/test.txt', 'LICENSES/test.sh'):
            with self.subTest(ref=ref):
                path.write_text(original.replace('LICENSES/test.txt', ref))
                with self.assertRaises(c.CatalogueError):
                    self.build()

    def test_symlinks_in_files_and_parent_directories_are_rejected(self):
        self.effect("cursor/glow")
        shader = self.root / "cursor/glow/shader.glsl"
        shader.rename(shader.with_suffix(".saved"))
        shader.symlink_to("shader.saved")
        with self.assertRaisesRegex(c.CatalogueError, "symlinks"):
            self.build()
        shader.unlink()
        shader.with_suffix(".saved").rename(shader)
        (self.root / "LICENSES").rename(self.root / "notices")
        (self.root / "LICENSES").symlink_to("notices", target_is_directory=True)
        with self.assertRaisesRegex(c.CatalogueError, "symlinks"):
            self.build()

    def test_special_files_and_executable_files_are_rejected(self):
        self.effect("cursor/glow")
        path = self.root / "cursor/glow/shader.glsl"
        path.chmod(0o755)
        with self.assertRaisesRegex(c.CatalogueError, "regular file"):
            self.build()
        path.unlink()
        os.mkfifo(path)
        with self.assertRaisesRegex(c.CatalogueError, "regular file"):
            self.build()

    def test_shader_size_and_real_entry_point_are_checked(self):
        self.effect("cursor/glow")
        for code in ('// vec4 cursor(vec2 uv) { return vec4(0.0); }\n',
                     '/* vec4 cursor(vec2 uv) { return vec4(0.0); } */\n',
                     'x' * (c.TEXT_LIMIT + 1),
                     '#include "other.glsl"\nvec4 cursor(vec2 uv) { return vec4(0.0); }'):
            with self.subTest(code=code[:30]):
                self.write("cursor/glow/shader.glsl", code)
                with self.assertRaises(c.CatalogueError):
                    self.build()

    def test_unknown_activation_keys_and_wrong_timing_are_rejected(self):
        self.effect("animation/open", uses=["animation.windows_in"])
        path = self.root / "animation/open/config.toml"
        original = path.read_text()
        for old, new in (('duration_ms = 600', 'duration_ms = true'),
                         ('duration_ms = 600', 'duration_ms = 0'),
                         ('curve = "linear"', 'curve = "not-a-curve"'),
                         ('curve = "linear"', 'curve = "bouncy"'),
                         ('curve = "linear"', 'style = "reveal"'),
                         ('curve = "linear"', 'scale = nan'),
                         ('curve = "linear"', 'typo = true')):
            with self.subTest(new=new):
                path.write_text(original.replace(old, new))
                with self.assertRaises(c.CatalogueError):
                    self.build()

    def test_example_cannot_run_commands_or_select_an_unrelated_effect(self):
        self.effect("cursor/glow")
        self.effect("window/other")
        path = self.root / "cursor/glow/config.toml"
        original = path.read_text()
        path.write_text(original + '[general]\nautostart = ["nope"]\n')
        with self.assertRaisesRegex(c.CatalogueError, "unknown fields"):
            self.build()
        path.write_text(original.replace('cursor = "glow"', 'window = "other"'))
        with self.assertRaisesRegex(c.CatalogueError, "not an included member"):
            self.build()

    def test_reviewed_manual_only_example_has_no_executable_recipe(self):
        self.effect("cursor/glow")
        path = self.root / "cursor/glow/config.toml"
        path.write_text(path.read_text() + "max_fps = 30\n")
        generator = c.Generator(c.Source(self.root))
        registry = generator.build()
        self.assertIsNone(registry["effects"][0]["activation"])
        self.assertIn("manual-only", generator.warnings[0])
        with self.assertRaisesRegex(c.CatalogueError, "manual configuration required"):
            c.activation_for(registry, {"effects.cursor": "cursor/glow"})

    def test_family_selections_must_be_members(self):
        self.effect("cursor/glow")
        self.effect("window/other")
        self.write("families.toml", "[families.test]\n" + 'publish = true\nname = "Test"\ndescription = "Test"\nmembers = ["cursor/glow"]\n')
        self.modify("families.toml", 'members = ["cursor/glow"]\n',
                    'members = ["cursor/glow"]\n[families.test.defaults]\n"effects.window" = "window/other"\n')
        with self.assertRaisesRegex(c.CatalogueError, "default selection is not a member"):
            self.build()

    def test_family_defaults_follow_member_settings_without_copied_files(self):
        self.effect("animation/open", uses=["animation.windows_in"])
        self.write("families.toml", '[families.test]\npublish = true\nname = "Test"\n'
                   'description = "Test"\nmembers = ["animation/open"]\n'
                   '[families.test.defaults]\n"animation.windows_in" = "animation/open"\n')
        first = self.build()
        self.assertEqual(first["families"][0]["activation"]["settings"]["animation.windows_in.duration_ms"], 600)
        self.modify("animation/open/config.toml", "duration_ms = 600", "duration_ms = 850")
        second = self.build()
        self.assertEqual(second["families"][0]["activation"]["settings"]["animation.windows_in.duration_ms"], 850)
        self.assertFalse((self.root / "families").exists())
        self.assertEqual(set(first["files"]), set(second["files"]))
        self.assertNotIn("families.toml", second["files"])

    def test_family_defaults_reject_unsupported_uses_and_missing_recipes(self):
        self.effect("cursor/glow", recipe=False)
        self.write("families.toml", '[families.test]\npublish = true\nname = "Test"\n'
                   'description = "Test"\nmembers = ["cursor/glow"]\n'
                   '[families.test.defaults]\n"effects.window" = "cursor/glow"\n')
        with self.assertRaisesRegex(c.CatalogueError, "unsupported default use"):
            self.build()
        self.modify("families.toml", "effects.window", "effects.cursor")
        with self.assertRaisesRegex(c.CatalogueError, "no recipe"):
            self.build()

    def test_family_metadata_rejects_assets_and_runtime_configuration(self):
        self.effect("cursor/glow")
        for extra in ('preview = "copy.png"', 'config = "copy.toml"', 'defaults = []',
                      '[defaults]\n"effects.cursor" = 42'):
            # Nested defaults use the full TOML table name.
            extra = extra.replace('[defaults]', '[families.test.defaults]')
            self.write("families.toml", '[families.test]\npublish = true\nname = "Test"\n'
                       'description = "Test"\nmembers = ["cursor/glow"]\n' + extra + '\n')
            with self.subTest(extra=extra), self.assertRaises(c.CatalogueError):
                self.build()

    def test_committed_family_metadata_ignores_working_tree_changes(self):
        self.effect("cursor/glow")
        self.write("families.toml", '[families.test]\npublish = true\nname = "Test"\n'
                   'description = "Test"\nmembers = ["cursor/glow"]\n')
        revision = self.commit()
        self.modify("families.toml", "publish = true", "publish = false")
        self.assertEqual(self.build()["families"], [])
        registry = c.Generator(c.Source(self.root, revision)).build()
        self.assertEqual(registry["families"][0]["members"], ["cursor/glow"])

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True,
                              text=True, timeout=10).stdout.strip()

    def commit(self):
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=Catalogue test", "-c", "user.email=catalogue@example.invalid",
                 "-c", "commit.gpgsign=false", "commit", "-qm", "Test source")
        return self.git("rev-parse", "HEAD")

    def test_production_reads_pinned_commit_even_when_checkout_is_dirty(self):
        self.effect("cursor/glow")
        expected = hashlib.sha256((self.root / "cursor/glow/shader.glsl").read_bytes()).hexdigest()
        revision = self.commit()
        self.write("cursor/glow/shader.glsl", "uncommitted invalid source")
        self.effect("window/uncommitted")
        r = c.Generator(c.Source(self.root, revision)).build()
        self.assertFalse(r["draft"])
        self.assertEqual(r["source"]["revision"], revision)
        self.assertEqual([e["id"] for e in r["effects"]], ["cursor/glow"])
        self.assertEqual(r["files"]["cursor/glow/shader.glsl"]["sha256"], expected)

    def test_production_rejects_draft_overlay_and_non_commit_revision(self):
        self.effect("cursor/glow")
        revision = self.commit()
        with self.assertRaisesRegex(c.CatalogueError, "cannot use draft"):
            c.Generator(c.Source(self.root, revision), "docs/examples")
        for ref in ("HEAD", revision[:8], "0" * 40):
            with self.subTest(ref=ref), self.assertRaises(c.CatalogueError):
                c.Source(self.root, ref)

    def test_production_rejects_committed_symlinks(self):
        self.effect("cursor/glow")
        path = self.root / "cursor/glow/shader.glsl"
        path.rename(path.with_suffix(".saved"))
        path.symlink_to("shader.saved")
        revision = self.commit()
        with self.assertRaisesRegex(c.CatalogueError, "regular file"):
            c.Generator(c.Source(self.root, revision)).build()

    def test_failed_generation_or_replace_keeps_existing_output(self):
        self.effect("cursor/glow")
        output = self.write("registry.json", "previous registry\n")
        arguments = ["--root", str(self.root), "--draft", "--output", str(output)]
        with contextlib.redirect_stderr(io.StringIO()), patch.object(c.os, "replace", side_effect=OSError("failed")):
            self.assertEqual(c.main(arguments), 1)
        self.assertEqual(output.read_text(), "previous registry\n")
        self.assertEqual(list(self.root.glob(".catalogue-*")), [])
        self.write("cursor/glow/metadata.toml", "broken = [")
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(c.main(arguments), 1)
        self.assertEqual(output.read_text(), "previous registry\n")

    def test_check_detects_stale_content_without_overwriting_it(self):
        self.effect("cursor/glow")
        output = self.root / "registry.json"
        arguments = ["--root", str(self.root), "--draft"]
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(c.main(arguments + ["--output", str(output)]), 0)
            self.assertEqual(c.main(arguments + ["--check", str(output)]), 0)
        old = output.read_bytes()
        self.write("cursor/glow/shader.glsl", "vec4 cursor(vec2 uv) { return vec4(1.0); }\n")
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(c.main(arguments + ["--check", str(output)]), 1)
        self.assertEqual(output.read_bytes(), old)


class RepositoryExamples(unittest.TestCase):
    def test_nine_effect_example_is_reproducible_and_hashes_current_files(self):
        one = c.Generator(c.Source(ROOT), "docs/catalogue-examples").build()
        two = c.Generator(c.Source(ROOT), "docs/catalogue-examples").build()
        self.assertEqual(c.encode(one), c.encode(two))
        self.assertEqual(c.encode(one), (ROOT / "docs/catalogue-examples/registry.example.json").read_text())
        self.assertEqual(len(one["effects"]), 9)
        self.assertEqual(len(one["families"]), 1)
        self.assertTrue(one["draft"])
        self.assertIsNone(one["source"]["revision"])
        for path, record in one["files"].items():
            raw = (ROOT / path).read_bytes()
            self.assertEqual(record, {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})




class RepositoryMetadataTests(unittest.TestCase):
    """Keep the real catalogue complete as contributors add presets and families."""
    @classmethod
    def setUpClass(cls):
        cls.registry = c.Generator(c.Source(ROOT)).build()
        cls.effects = {e["id"]: e for e in cls.registry["effects"]}

    def test_published_presets_have_complete_metadata(self):
        folders = {p.parent.relative_to(ROOT).as_posix()
                   for kind in c.KINDS for p in (ROOT / kind).glob("*/effect.toml")}
        # Experimental folders (with no metadata, or publish=false) may coexist
        # with the released set without being eligible for catalogue installs.
        self.assertEqual(set(self.effects) - folders, set())
        for effect in self.effects.values():
            with self.subTest(effect=effect["id"]):
                self.assertTrue(effect["tags"])
                self.assertTrue(effect["preview"]["image"])
                self.assertTrue(effect["notice_files"])
                if effect["uses"]:
                    self.assertIsNotNone(effect["activation"])
                else:
                    self.assertEqual(effect["role"], "companion")

    def test_contributor_credits_and_licences_are_preserved(self):
        for effect in ("animation/blood-in", "animation/blood-out", "border/heartbeat"):
            self.assertEqual(self.effects[effect]["author"], "WinterMyst")
        self.assertEqual(self.effects["cursor/glow"]["author"], "Noctalia")
        self.assertEqual(self.effects["border/dual-orbit"]["author"], "neonvoidx")
        self.assertEqual(self.effects["animation/kzzzt-open"]["author"], "weegs710")
        self.assertEqual(self.effects["animation/tv-glitch"]["license"], "GPL-3.0-or-later")
        self.assertIn("LICENSES/Noctalia-MIT.txt", self.effects["cursor/vampire-wake"]["notice_files"])

    def test_family_members_have_consistent_backlinks_and_recipes(self):
        families = {f["id"]: f for f in self.registry["families"]}
        self.assertTrue({"vampire", "after-dark", "psychedelic", "diwali", "ghostly-tear"} <= families.keys())
        for family in families.values():
            for member in family["members"]:
                self.assertIn(family["id"], self.effects[member]["families"])
        for effect in self.effects.values():
            for family in effect["families"]:
                self.assertIn(effect["id"], families[family]["members"])
        self.assertFalse((ROOT / "families").exists())
        self.assertFalse(any(path.startswith("families/") for path in self.registry["files"]))
        for family in families.values():
            self.assertNotIn("path", family)
            self.assertIsNone(family["readme"])
            self.assertIsNone(family["config_example"])
            self.assertEqual(family["preview"], {"image": None, "animation": None})
        self.assertEqual(self.effects["window/diya-glow-overlay"]["uses"], [])
        self.assertIsNone(self.effects["window/diya-glow-overlay"]["activation"])


if __name__ == "__main__":
    unittest.main()
