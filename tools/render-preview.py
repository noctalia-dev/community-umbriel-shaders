#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Barrulus
"""Render one preset to PNG using the installed Umbriel in a private session."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import select
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import tomllib

KINDS = ('animation', 'border', 'window', 'screen', 'cursor')
EVENTS = ('windows_in', 'windows_out', 'windows_move', 'workspaces')


def size(value):
    try:
        width, height = map(int, value.lower().split('x'))
        if not (320 <= width <= 2560 and 240 <= height <= 1440):
            raise ValueError
        return width, height
    except ValueError:
        raise argparse.ArgumentTypeError('use WIDTHxHEIGHT, from 320x240 to 2560x1440') from None


def finite(value):
    result = float(value)
    if not math.isfinite(result) or not 0 <= result <= 30:
        raise argparse.ArgumentTypeError('must be a finite number between 0 and 30')
    return result


def preset_info(path, name):
    definition = path / 'effect.toml' if path.is_dir() else path
    definition = definition.resolve(strict=True)
    data = tomllib.loads(definition.read_text())
    presets = data.get('effects', {}).get('preset', {})
    if name is None:
        if len(presets) != 1:
            raise ValueError('Use --preset NAME when effect.toml defines more than one preset')
        name = next(iter(presets))
    if name not in presets:
        raise ValueError(f'Preset {name!r} is not defined in {definition}')
    preset = presets[name]
    if preset.get('kind') not in KINDS:
        raise ValueError('Unsupported or missing preset kind')
    shader = (definition.parent / preset['shader']).resolve(strict=True)
    return definition, name, preset, shader


def event_for(definition, requested):
    if requested:
        return requested
    example = definition.with_name('config.toml')
    if example.exists():
        animations = tomllib.loads(example.read_text()).get('animation', {})
        for event in animations:
            if event in EVENTS:
                return event
    return 'windows_in'


def config_text(definition, name, preset, width, height, event, duration):
    kind = preset['kind']
    # Only the supplied preset definition is included, never the user's config.
    text = f'''[include]
files = [{json.dumps(str(definition))}]

[general]
xwayland = false
show_cheatsheet = false
autostart = []

[output.HEADLESS-1]
mode = "{width}x{height}@60"
scale = 1.0
workspaces = 2

[appearance]
border_width = 6
corner_radius = 10

[appearance.blur]
enabled = false

[effects]
in_capture = true
'''
    if kind != 'animation':
        text += f'{kind} = {json.dumps(name)}\n'
    text += '\n[animation]\nenabled = ' + ('true' if kind == 'animation' else 'false') + '\n'
    for candidate in EVENTS:
        text += f'\n[animation.{candidate}]\nenabled = {str(kind == "animation" and candidate == event).lower()}\n'
        if kind == 'animation' and candidate == event:
            text += f'effect = {json.dumps(name)}\nduration_ms = {duration}\ncurve = "linear"\n'
            if event == 'workspaces':
                example = definition.with_name('config.toml')
                if example.exists():
                    workspace = tomllib.loads(example.read_text()).get('animation', {}).get('workspaces', {})
                    if 'style' in workspace:
                        text += f'style = {json.dumps(workspace["style"])}\n'
    # Frame the native border, including its light/overlay, with useful margins.
    margin = min(max(36, int(preset.get('padding', 0)) + 20), min(width, height)//3)
    text += f'''
[[window_rule]]
match.app_id = "^community[.]umbriel[.]preview$"
default_floating = true
default_focused = true
default_floating_size_px = {{ width = {width-2*margin}, height = {height-2*margin} }}
default_position = {{ x = 0, y = 0, anchor = "center" }}
'''
    return text


class Session:
    def __init__(self, root, args, config):
        self.root, self.args = root, args
        self.processes = []
        self.logs = []
        self.env = os.environ.copy()
        # Remove every inherited session target before setting private endpoints.
        for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'UMBRIEL_SOCKET',
                    'DBUS_SESSION_BUS_ADDRESS', 'WLR_DRM_DEVICES', 'WLR_BACKENDS',
                    'WLR_HEADLESS_OUTPUTS'):
            self.env.pop(key, None)
        self.env.update(XDG_RUNTIME_DIR=str(root), WAYLAND_DISPLAY='wayland-0',
                        XDG_CONFIG_HOME=str(root/'config'), XDG_CACHE_HOME=str(root/'cache'),
                        XDG_STATE_HOME=str(root/'state'),
                        UMBRIEL_SOCKET=str(root/'umbriel-wayland-0.sock'),
                        WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='1',
                        WLR_LIBINPUT_NO_DEVICES='1', WLR_RENDERER='gles2')
        if args.software:
            self.env['LIBGL_ALWAYS_SOFTWARE'] = '1'
        self.config = root/'config.toml'
        self.config.write_text(config)

    def command(self, *arguments, check=True):
        result = subprocess.run([self.args.umbriel, *arguments], env=self.env,
                                capture_output=True, text=True, timeout=15)
        if check and result.returncode:
            raise RuntimeError(f'umbriel {" ".join(arguments)}: {(result.stderr or result.stdout).strip()}')
        return result

    def spawn(self, command, name, client=False):
        log = (self.root/f'{name}.log').open('w')
        self.logs.append(log)
        process = subprocess.Popen(command, env=self.env, start_new_session=True,
                                   stdin=subprocess.PIPE if client else subprocess.DEVNULL,
                                   stdout=subprocess.PIPE if client else log, stderr=log)
        self.processes.append(process)
        return process

    def start(self):
        self.command('config', 'validate', '-c', str(self.config))
        # The backend is explicit; no DRM/input session is acquired.
        self.server = self.spawn([self.args.umbriel, '-c', str(self.config)], 'compositor')
        deadline = time.monotonic()+15
        while not Path(self.env['UMBRIEL_SOCKET']).is_socket():
            if self.server.poll() is not None:
                raise RuntimeError('Headless Umbriel exited during startup')
            if time.monotonic() >= deadline:
                raise RuntimeError('Timed out starting headless Umbriel')
            time.sleep(0.03)
        outputs = json.loads(self.command('outputs', '--json').stdout)
        if not outputs:
            raise RuntimeError('Headless Umbriel has no output')

    def start_client(self):
        self.client = self.spawn([sys.executable, str(Path(__file__).with_name('preview_client.py')),
                                  '--socket', str(self.root/'wayland-0'),
                                  '--width', str(self.args.size[0]-72),
                                  '--height', str(self.args.size[1]-72)], 'client', client=True)
        self.wait_line('ready')
        deadline = time.monotonic()+10
        while True:
            windows = json.loads(self.command('windows', '--json').stdout)
            window = next((w for w in windows if w['app_id'] == 'community.umbriel.preview'), None)
            if window:
                return window
            if time.monotonic() > deadline:
                raise RuntimeError('Sample window did not map')
            time.sleep(0.02)

    def wait_line(self, expected):
        deadline = time.monotonic()+15
        while time.monotonic() < deadline:
            if select.select([self.client.stdout], [], [], 0.1)[0]:
                line = self.client.stdout.readline().decode().strip()
                if line == expected:
                    return
                if not line and self.client.poll() is not None:
                    raise RuntimeError('Sample client exited before becoming ready')
        raise RuntimeError(f'Timed out waiting for sample client: {expected}')

    def client_command(self, command, **kwargs):
        self.client.stdin.write((json.dumps({'command': command, **kwargs})+'\n').encode())
        self.client.stdin.flush()

    def move(self, x, y):
        self.client_command('move', position=[round(x), round(y), *self.args.size])

    def trail(self):
        width, height = self.args.size
        # Fixed figure-eight path, with real timestamps; works on release builds.
        start = time.monotonic()
        for index in range(64):
            phase = index / 63 * math.tau
            self.move(width*(0.5+0.32*math.sin(phase)), height*(0.5+0.25*math.sin(2*phase)))
            time.sleep(max(0, start+(index+1)*1.8/64-time.monotonic()))
        self.client_command('sync')
        self.wait_line('synced')

    def ensure_compiled(self, name):
        report = json.loads(self.command('effects', '--json').stdout)
        preset = next((p for p in report['presets'] if p['name'] == name), None)
        if not preset or preset['state'] != 'compiled':
            raise RuntimeError(f'Preset did not compile: {preset}')
        if preset.get('overlay'):
            overlay = next((p for p in report['presets'] if p['name'] == preset['overlay']), None)
            if not overlay or overlay['state'] != 'compiled':
                raise RuntimeError(f'Companion overlay did not compile: {overlay}')

    def capture(self, path):
        result = subprocess.run([self.args.grim, '-o', 'HEADLESS-1', str(path)],
                                env=self.env, capture_output=True, text=True, timeout=15)
        if result.returncode:
            raise RuntimeError(f'grim: {result.stderr.strip()}')
        data = path.read_bytes()
        if not data.startswith(b'\x89PNG\r\n\x1a\n'):
            raise RuntimeError('Capture did not produce a PNG')
        if len(data) < 24 or struct.unpack('!II', data[16:24]) != self.args.size:
            raise RuntimeError('Headless output did not use the requested image dimensions')

    def close(self):
        # Terminate only process groups created by this invocation.
        for process in reversed(self.processes):
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        for process in reversed(self.processes):
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=3)
            for stream in (process.stdin, process.stdout):
                if stream:
                    stream.close()
        for log in self.logs:
            log.close()


def render(args, definition, name, preset, shader):
    event = event_for(definition, args.event) if preset['kind'] == 'animation' else None
    config = config_text(definition, name, preset, *args.size, event, args.duration_ms)
    output = (args.output or definition.with_name('preview.png')).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Keep socket paths short enough for sockaddr_un even with a long TMPDIR.
    with tempfile.TemporaryDirectory(prefix='umprev-', dir='/tmp') as directory:
        root = Path(directory)
        session = Session(root, args, config)
        try:
            session.start()
            frozen = False
            if event == 'windows_in':
                frozen = session.command('clock-freeze', check=False).returncode == 0
            session.start_client()
            session.move(args.size[0]*0.5, args.size[1]*0.5)
            if event:
                if event != 'windows_in':
                    time.sleep(0.15)
                    frozen = session.command('clock-freeze', check=False).returncode == 0
                    if event == 'windows_out':
                        session.client_command('close')
                        session.client.wait(timeout=5)
                    elif event == 'windows_move':
                        session.command('msg', 'window-toggle-maximize')
                    elif event == 'workspaces':
                        session.command('msg', 'workspace-switch:2')
                milliseconds = round(args.progress * args.duration_ms)
                if frozen:
                    session.command('clock-advance', str(milliseconds))
                else:
                    print('Note: this Umbriel lacks test clock controls; animation timing is approximate.')
                    time.sleep(milliseconds/1000)
            elif preset['kind'] == 'cursor':
                time.sleep(args.time)
                session.trail()
            else:
                time.sleep(args.time)
            session.ensure_compiled(name)
            # Capturing uses the isolated session and includes window/cursor/screen effects.
            image = root/'preview.png'
            session.capture(image)
            # Copy via a sibling temporary file: failed rendering never replaces an existing preview.
            with tempfile.NamedTemporaryFile(prefix='.preview-', suffix='.png', dir=output.parent, delete=False) as temp:
                temporary = Path(temp.name)
                temp.write(image.read_bytes())
            try:
                temporary.replace(output)
            finally:
                temporary.unlink(missing_ok=True)
            print(f'Rendered {name} ({preset["kind"]}) → {output}')
            print(f'{session.command("--version").stdout.strip()}; shader SHA256 {hashlib.sha256(shader.read_bytes()).hexdigest()[:16]}')
            if event:
                print(f'Event: {event}; linear {args.duration_ms} ms; progress {args.progress:g}; clock {"frozen" if frozen else "real time"}')
        except Exception:
            session.close()
            for name in ('compositor', 'client'):
                log = root/f'{name}.log'
                if log.exists():
                    print(f'\n{name} log (last 30 lines):\n'+ '\n'.join(log.read_text(errors='replace').splitlines()[-30:]), file=sys.stderr)
            raise
        finally:
            if any(p.poll() is None for p in session.processes):
                session.close()
            elif any(not log.closed for log in session.logs):
                session.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('effect', type=Path, help='one preset directory or effect.toml')
    parser.add_argument('--preset', help='preset name if the file defines more than one')
    parser.add_argument('-o', '--output', type=Path, help='PNG path (default: preset directory/preview.png)')
    parser.add_argument('--umbriel', default='umbriel', help='Umbriel executable (default: PATH)')
    parser.add_argument('--grim', default='grim', help='grim executable (default: PATH)')
    parser.add_argument('--size', type=size, default=(640, 400), help='output size (default: 640x400)')
    parser.add_argument('--time', type=finite, default=1.2, help='settling time before capture/path, seconds (default: 1.2)')
    parser.add_argument('--event', choices=EVENTS, help='animation event (default: first supported event in config.toml)')
    parser.add_argument('--progress', type=float, default=0.55, help='animation progress, 0–1 (default: 0.55)')
    parser.add_argument('--duration-ms', type=int, default=1600, help='linear preview animation duration (default: 1600)')
    parser.add_argument('--software', action='store_true', help='request Mesa software rendering; a usable EGL/render device may still be needed')
    args = parser.parse_args()
    if not math.isfinite(args.progress) or not 0 <= args.progress <= 1:
        parser.error('--progress must be between 0 and 1')
    if not 100 <= args.duration_ms <= 10000:
        parser.error('--duration-ms must be between 100 and 10000')
    for option in ('umbriel', 'grim'):
        resolved = shutil.which(getattr(args, option))
        if not resolved:
            parser.error(f'{option} is not installed or not on PATH')
        setattr(args, option, resolved)
    try:
        definition, name, preset, shader = preset_info(args.effect, args.preset)
        if args.event and preset['kind'] != 'animation':
            parser.error('--event applies only to animation presets')
        render(args, definition, name, preset, shader)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'Preview failed: {error}', file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print('Preview cancelled.', file=sys.stderr)
        return 130
    return 0


def interrupted(signum, frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, interrupted)
    sys.exit(main())
