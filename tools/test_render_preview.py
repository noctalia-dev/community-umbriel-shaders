#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Barrulus
"""Portable preview-tool checks: python3 -m unittest discover -s tools -p 'test_*.py'."""
import argparse
import importlib.util
import os
from pathlib import Path
import struct
import tempfile
import tomllib
import unittest
from unittest.mock import Mock, patch

from preview_client import Client, string, words

spec = importlib.util.spec_from_file_location('render_preview', Path(__file__).with_name('render-preview.py'))
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


class PreviewTests(unittest.TestCase):
    def test_private_session_replaces_inherited_targets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            args = argparse.Namespace(software=False)
            with patch.dict(os.environ, {'UMBRIEL_SOCKET': '/live/umbriel.sock',
                                        'WAYLAND_DISPLAY': '/live/wayland-1',
                                        'WAYLAND_SOCKET': '17', 'DISPLAY': ':0',
                                        'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/live/bus',
                                        'WLR_BACKENDS': 'drm', 'WLR_DRM_DEVICES': '/dev/dri/card0'}):
                session = preview.Session(root, args, '[general]\nautostart = []\n')
            self.assertEqual(session.env['UMBRIEL_SOCKET'], str(root/'umbriel-wayland-0.sock'))
            self.assertEqual(session.env['XDG_RUNTIME_DIR'], str(root))
            self.assertEqual(session.env['WLR_BACKENDS'], 'headless')
            for name in ('WAYLAND_SOCKET', 'DISPLAY', 'DBUS_SESSION_BUS_ADDRESS', 'WLR_DRM_DEVICES'):
                self.assertNotIn(name, session.env)

    def test_ambiguous_preset_requires_explicit_selection(self):
        with tempfile.TemporaryDirectory(prefix='preview with spaces ') as directory:
            root = Path(directory)
            (root/'shader.glsl').write_text('vec4 cursor(vec2 uv) { return umbriel_sample(uv); }')
            (root/'effect.toml').write_text('\n'.join(
                f'[effects.preset.{name}]\nkind = "cursor"\nshader = "shader.glsl"' for name in ('one', 'two')))
            with self.assertRaisesRegex(ValueError, '--preset'):
                preview.preset_info(root, None)
            definition, name, preset, shader = preview.preset_info(root, 'two')
            self.assertEqual(name, 'two')
            self.assertEqual(shader, root/'shader.glsl')

    def test_closing_only_animation_selects_closing_event(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'config.toml').write_text('[animation.windows_out]\neffect = "closing"\n')
            self.assertEqual(preview.event_for(root/'effect.toml', None), 'windows_out')
            self.assertEqual(preview.event_for(root/'effect.toml', 'windows_in'), 'windows_in')

    def test_failed_capture_does_not_accept_wrong_size(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            args = argparse.Namespace(software=False, grim='grim', size=(640, 400))
            session = preview.Session(root, args, '')
            path = root/'capture.png'
            path.write_bytes(b'\x89PNG\r\n\x1a\n'+b'\0'*8+struct.pack('!II', 1920, 1080))
            with patch.object(preview.subprocess, 'run', return_value=argparse.Namespace(returncode=0)):
                with self.assertRaisesRegex(RuntimeError, 'dimensions'):
                    session.capture(path)

    def test_workspace_preview_preserves_reveal_style(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for style in ('reveal', 'slide', None):
                (root/'config.toml').write_text('[animation.workspaces]\n' +
                    (f'style = "{style}"\n' if style else ''))
                config = tomllib.loads(preview.config_text(root/'effect.toml', 'portal',
                    {'kind': 'animation'}, 640, 400, 'workspaces', 1100))
                self.assertEqual(config['animation']['workspaces'].get('style'), style)
                self.assertEqual(config['animation']['workspaces']['effect'], 'portal')

    def test_fragmented_wayland_events_are_reassembled(self):
        received = []
        payload = words(23)
        message = words(7, (12 << 16) | 2) + payload
        client = Client.__new__(Client)
        client.pending = b''
        client.handlers = {7: lambda opcode, data: received.append((opcode, data))}
        client.socket = Mock()
        client.socket.recv.side_effect = [message[:5], message[5:9], message[9:]]
        client.dispatch()
        client.dispatch()
        self.assertEqual(received, [])
        client.dispatch()
        self.assertEqual(received, [(2, payload)])

    def test_wire_strings_use_utf8_byte_length_and_alignment(self):
        encoded = string('café')
        length = struct.unpack_from('=I', encoded)[0]
        self.assertEqual(length, 6)
        self.assertEqual(len(encoded) % 4, 0)
        self.assertEqual(encoded[4:4+length], 'café'.encode()+b'\0')


if __name__ == '__main__':
    unittest.main()
