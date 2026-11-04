#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Barrulus
"""Publication checks against isolated local Git repositories; no network."""

import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import catalogue as c
import publish_catalogue as p


class PublicationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='catalogue-publish-')
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.root = self.base / 'source'
        self.remote = self.base / 'remote.git'
        self.root.mkdir()
        self.git('init', '-q', '-b', 'main')
        self.git('config', 'user.name', 'Publication test')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')
        subprocess.run(['git', 'init', '-q', '--bare', str(self.remote)], check=True)
        self.git('remote', 'add', 'origin', str(self.remote))
        self.write('notice.txt', 'Test attribution\n')
        self.write('cursor/glow/metadata.toml', 'publish = true\nname = "Glow"\n'
                   'description = "Test glow."\nauthor = "Test"\nlicense = "MIT"\n'
                   'notice_files = ["notice.txt"]\n')
        self.write('cursor/glow/effect.toml', '[effects.preset.glow]\nkind = "cursor"\nshader = "shader.glsl"\n')
        self.write('cursor/glow/shader.glsl', 'vec4 cursor(vec2 uv) { return vec4(0.0); }\n')
        self.revision = self.commit_source()

    def git(self, *args, data=None):
        return subprocess.run(['git', '-C', str(self.root), *args], input=data,
                              capture_output=True, check=True, timeout=20).stdout

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def commit_source(self):
        self.git('add', '.')
        self.git('commit', '-qm', 'Source update')
        self.git('push', 'origin', 'main')
        return self.git('rev-parse', 'HEAD').decode().strip()

    def catalogue_ref(self):
        return p.remote_ref(self.root, 'origin', p.BRANCH)

    def published(self):
        self.git('fetch', '-q', 'origin', p.BRANCH)
        return self.git('show', 'FETCH_HEAD:catalogue.json')

    def replace_catalogue(self, payload):
        parent = self.catalogue_ref()
        blob = self.git('hash-object', '-w', '--stdin', data=payload).decode().strip()
        tree = self.git('mktree', data=f'100644 blob {blob}\tcatalogue.json\n'.encode()).decode().strip()
        commit = self.git('commit-tree', tree, *(['-p', parent] if parent else []),
                          data=b'Concurrent external publication\n').decode().strip()
        self.git('push', 'origin', f'{commit}:{p.BRANCH}')
        return commit

    def test_first_publication_is_pinned_and_leaves_source_checkout_untouched(self):
        # Dirty shader bytes must never be published, stashed or overwritten.
        self.write('cursor/glow/shader.glsl', 'uncommitted invalid shader')
        before = self.git('status', '--porcelain')
        result = p.publish(self.root, 'origin', self.revision)
        self.assertTrue(result.startswith('Published 1 effects'))
        registry = json.loads(self.published())
        self.assertFalse(registry['draft'])
        self.assertEqual(registry['source']['revision'], self.revision)
        self.assertEqual(self.git('ls-tree', '--name-only', self.catalogue_ref()), b'catalogue.json\n')
        self.assertEqual(self.git('rev-parse', 'HEAD').decode().strip(), self.revision)
        self.assertEqual(self.git('status', '--porcelain'), before)
        self.assertEqual((self.root / 'cursor/glow/shader.glsl').read_text(), 'uncommitted invalid shader')

    def test_repeat_is_noop_and_new_main_fast_forwards_catalogue(self):
        p.publish(self.root, 'origin', self.revision)
        old = self.catalogue_ref()
        self.assertTrue(p.publish(self.root, 'origin', self.revision).startswith('Unchanged:'))
        self.assertEqual(self.catalogue_ref(), old)
        self.write('notice.txt', 'Updated attribution\n')
        new = self.commit_source()
        p.publish(self.root, 'origin', new)
        self.assertEqual(json.loads(self.published())['source']['revision'], new)
        self.assertEqual(self.git('rev-parse', self.catalogue_ref() + '^').decode().strip(), old)

    def test_old_rerun_cannot_replace_latest_publication(self):
        p.publish(self.root, 'origin', self.revision)
        self.write('notice.txt', 'New source\n')
        new = self.commit_source()
        p.publish(self.root, 'origin', new)
        latest = self.catalogue_ref()
        self.assertTrue(p.publish(self.root, 'origin', self.revision).startswith('Skipped:'))
        self.assertEqual(self.catalogue_ref(), latest)

    def test_invalid_source_preserves_last_good_catalogue(self):
        p.publish(self.root, 'origin', self.revision)
        old = self.catalogue_ref()
        self.write('cursor/glow/shader.glsl', 'invalid source')
        new = self.commit_source()
        with self.assertRaisesRegex(c.CatalogueError, 'entry point'):
            p.publish(self.root, 'origin', new)
        self.assertEqual(self.catalogue_ref(), old)

    def test_main_advancing_during_generation_skips_publication(self):
        p.publish(self.root, 'origin', self.revision)
        old = self.catalogue_ref()
        self.write('notice.txt', 'Second source\n')
        second = self.commit_source()
        original = p.remote_ref
        main_reads = 0

        def advance(root, remote, ref):
            nonlocal main_reads
            if ref == 'refs/heads/main':
                main_reads += 1
                if main_reads == 2:
                    self.write('notice.txt', 'Third source\n')
                    self.commit_source()
            return original(root, remote, ref)

        with patch.object(p, 'remote_ref', side_effect=advance):
            self.assertTrue(p.publish(self.root, 'origin', second).startswith('Skipped:'))
        self.assertEqual(self.catalogue_ref(), old)

    def test_concurrent_push_is_rejected_without_overwriting_winner(self):
        p.publish(self.root, 'origin', self.revision)
        payload = self.published()
        self.write('notice.txt', 'New source\n')
        new = self.commit_source()
        original = p.git
        winner = None

        def race(root, *args, **kwargs):
            nonlocal winner
            if args[0] == 'push':
                winner = self.replace_catalogue(payload)
            return original(root, *args, **kwargs)

        with patch.object(p, 'git', side_effect=race):
            with self.assertRaisesRegex(c.CatalogueError, 'Git push failed'):
                p.publish(self.root, 'origin', new)
        self.assertEqual(self.catalogue_ref(), winner)
        self.assertEqual(self.published(), payload)

    def test_unknown_existing_catalogue_is_preserved(self):
        p.publish(self.root, 'origin', self.revision)
        registry = json.loads(self.published())
        registry['source']['repository'] = 'https://example.invalid/other'
        old = self.replace_catalogue(json.dumps(registry).encode())
        with self.assertRaisesRegex(c.CatalogueError, 'unexpected source repository'):
            p.publish(self.root, 'origin', self.revision)
        self.assertEqual(self.catalogue_ref(), old)

    def test_divergent_source_history_cannot_replace_catalogue(self):
        p.publish(self.root, 'origin', self.revision)
        old = self.catalogue_ref()
        self.git('checkout', '--orphan', 'replacement')
        self.write('notice.txt', 'Unrelated history\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'Replacement source history')
        replacement = self.git('rev-parse', 'HEAD').decode().strip()
        # Simulate an administrator rewriting main; publisher must refuse rollback.
        self.git('push', '--force', 'origin', 'HEAD:main')
        with self.assertRaisesRegex(c.CatalogueError, 'merge-base'):
            p.publish(self.root, 'origin', replacement)
        self.assertEqual(self.catalogue_ref(), old)

    def test_cli_rejects_non_upstream_remote(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(p.main(['--root', str(self.root), '--revision', self.revision]), 1)
        self.assertIsNone(self.catalogue_ref())


if __name__ == '__main__':
    unittest.main()
