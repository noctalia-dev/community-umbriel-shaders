#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Barrulus
"""Private sample client for render-preview.py; Python standard library only.

Implements the small subset of wl_display/registry/compositor/shm, xdg-shell
and wlr-virtual-pointer needed for a synthetic window and pointer path.
It connects only to an explicitly supplied private Wayland socket.
"""
import argparse
import array
import json
import os
from pathlib import Path
import select
import socket
import struct
import sys
import time


def words(*values):
    return struct.pack('=' + 'I' * len(values), *values)


def string(value):
    data = value.encode() + b'\0'
    return words(len(data)) + data + b'\0' * (-len(data) % 4)


class Client:
    def __init__(self, path, width, height):
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.socket.connect(str(path))
        self.pending = b''
        self.next_id = 2
        self.handlers = {1: self.display_event}
        self.globals = {}
        self.width, self.height = width, height
        self.buffer_size = None
        self.ready = False
        self.closed = False
        self.sync_callbacks = {}
        self.registry = self.new(self.registry_event)
        self.send(1, 1, words(self.registry))  # wl_display.get_registry
        self.sync(self.setup)

    def new(self, handler=None):
        result = self.next_id
        self.next_id += 1
        if handler:
            self.handlers[result] = handler
        return result

    def send(self, obj, opcode, payload=b'', fd=None):
        message = words(obj, ((8 + len(payload)) << 16) | opcode) + payload
        if fd is None:
            self.socket.sendall(message)
        else:
            sent = self.socket.sendmsg([message], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array('i', [fd]))])
            if sent < len(message):
                self.socket.sendall(message[sent:])

    def sync(self, callback):
        obj = self.new()
        self.sync_callbacks[obj] = callback
        self.handlers[obj] = lambda opcode, data: self.sync_callbacks.pop(obj)()
        self.send(1, 0, words(obj))

    def display_event(self, opcode, data):
        if opcode == 0:
            obj, code, length = struct.unpack_from('=III', data)
            message = data[12:12 + length - 1].decode(errors='replace')
            raise RuntimeError(f'Wayland error on object {obj} ({code}): {message}')
        if opcode == 1:
            self.handlers.pop(struct.unpack_from('=I', data)[0], None)

    def registry_event(self, opcode, data):
        if opcode == 0:
            name, length = struct.unpack_from('=II', data)
            interface = data[8:8 + length - 1].decode()
            version = struct.unpack_from('=I', data, 8 + (length + 3) // 4 * 4)[0]
            self.globals[interface] = (name, version)

    def bind(self, interface, version, handler=None):
        if interface not in self.globals:
            raise RuntimeError(f'The isolated compositor does not advertise {interface}')
        name, available = self.globals[interface]
        obj = self.new(handler)
        self.send(self.registry, 0, words(name) + string(interface) + words(min(version, available), obj))
        return obj

    def setup(self):
        self.compositor = self.bind('wl_compositor', 4)
        self.shm = self.bind('wl_shm', 1)
        self.wm = self.bind('xdg_wm_base', 1, self.wm_event)
        self.surface = self.new()
        self.send(self.compositor, 0, words(self.surface))
        self.xdg_surface = self.new(self.surface_event)
        self.send(self.wm, 2, words(self.xdg_surface, self.surface))
        self.toplevel = self.new(self.toplevel_event)
        self.send(self.xdg_surface, 1, words(self.toplevel))
        self.send(self.toplevel, 2, string('Umbriel shader preview'))
        self.send(self.toplevel, 3, string('community.umbriel.preview'))
        manager = self.bind('zwlr_virtual_pointer_manager_v1', 1)
        self.pointer = self.new()
        self.send(manager, 0, words(0, self.pointer))
        self.send(self.surface, 6)  # initial empty commit

    def wm_event(self, opcode, data):
        if opcode == 0:
            self.send(self.wm, 3, data)  # pong

    def toplevel_event(self, opcode, data):
        if opcode == 0:
            width, height = struct.unpack_from('=ii', data)
            if width > 0 and height > 0:
                self.width, self.height = width, height
        elif opcode == 1:
            self.closed = True

    def surface_event(self, opcode, data):
        if opcode != 0:
            return
        self.send(self.xdg_surface, 4, data)  # ack_configure
        if self.buffer_size != (self.width, self.height):
            self.draw()
        else:
            self.send(self.surface, 6)
        if not self.ready:
            self.ready = True
            self.sync(lambda: print('ready', flush=True))

    def draw(self):
        width, height = self.width, self.height
        if not (0 < width <= 8192 and 0 < height <= 8192):
            raise RuntimeError('Unexpected preview window dimensions')
        pixels = array.array('I')
        # Original synthetic editor/document scene, with contrasting colours.
        for y in range(height):
            for x in range(width):
                rgb = (25 + int(12*x/width), 31 + int(12*y/height), 44)
                if y < 32:
                    rgb = (47, 57, 78)
                if width*.60 < x < width-20 and 52 < y < height-22:
                    rgb = (212, 217, 226)
                if 24 < x < width*.55 and 58 < y < height-24 and y % 20 < 3:
                    if x < width*.20 + (y//20*43) % max(1, int(width*.32)):
                        rgb = (136, 190, 174)
                if width*.64 < x < width-36 and 72 < y < height-35 and y % 24 < 3:
                    rgb = (71, 86, 117)
                pixels.append(0xff000000 | rgb[0] << 16 | rgb[1] << 8 | rgb[2])
        fd = os.memfd_create('umbriel-preview', os.MFD_CLOEXEC)
        try:
            data = pixels.tobytes()
            os.ftruncate(fd, len(data))
            with os.fdopen(os.dup(fd), 'wb') as stream:
                stream.write(data)
            pool = self.new()
            self.send(self.shm, 0, words(pool, len(data)), fd=fd)
            buffer = self.new()
            self.handlers[buffer] = lambda opcode, data: self.send(buffer, 0)  # release -> destroy
            self.send(pool, 0, words(buffer, 0, width, height, width*4, 0))  # ARGB8888
            self.send(pool, 1)
            self.send(self.surface, 1, words(buffer, 0, 0))
            self.send(self.surface, 2, words(0, 0, width, height))
            self.send(self.surface, 6)
            self.buffer_size = (width, height)
        finally:
            os.close(fd)

    def move(self, x, y, width, height):
        self.send(self.pointer, 1, words(int(time.monotonic()*1000) & 0xffffffff, x, y, width, height))
        self.send(self.pointer, 4)

    def dispatch(self):
        received = self.socket.recv(65536)
        if not received:
            raise RuntimeError('The isolated compositor closed the Wayland connection')
        self.pending += received
        while len(self.pending) >= 8:
            obj, header = struct.unpack_from('=II', self.pending)
            size, opcode = header >> 16, header & 0xffff
            if size < 8 or size % 4:
                raise RuntimeError('Invalid Wayland event size')
            if len(self.pending) < size:
                break
            data, self.pending = self.pending[8:size], self.pending[size:]
            if obj in self.handlers:
                self.handlers[obj](opcode, data)

    def run(self):
        commands = b''
        while not self.closed:
            readable, _, _ = select.select([self.socket, sys.stdin.buffer], [], [], 1)
            for source in readable:
                if source is self.socket:
                    self.dispatch()
                else:
                    block = os.read(sys.stdin.fileno(), 4096)
                    if not block:
                        return
                    commands += block
                    while b'\n' in commands:
                        line, commands = commands.split(b'\n', 1)
                        request = json.loads(line)
                        if request['command'] == 'move':
                            self.move(*request['position'])
                        elif request['command'] == 'close':
                            self.send(self.toplevel, 0)
                            self.send(self.xdg_surface, 0)
                            self.send(self.surface, 0)
                            self.closed = True
                        elif request['command'] == 'sync':
                            self.sync(lambda: print('synced', flush=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--socket', type=Path, required=True)
    parser.add_argument('--width', type=int, required=True)
    parser.add_argument('--height', type=int, required=True)
    args = parser.parse_args()
    try:
        Client(args.socket, args.width, args.height).run()
    except (OSError, RuntimeError, ValueError) as error:
        print(f'Preview client: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
