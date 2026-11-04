#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Barrulus
"""Publish the current upstream main catalogue without checking out its branch.

Requires Git credentials with upstream write access. No force pushes, source
branch changes, downloaded artifacts or working-tree shader reads are used.
"""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

import catalogue as c


BRANCH = 'refs/heads/catalogue'
UPSTREAM_REMOTES = {
    c.REPOSITORY, c.REPOSITORY + '.git',
    'git@github.com:noctalia-dev/community-umbriel-shaders.git',
    'ssh://git@github.com/noctalia-dev/community-umbriel-shaders.git',
}


def git(root, *args, data=None):
    try:
        return subprocess.run(['git', '-C', str(root), *args], input=data,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              check=True, timeout=120).stdout
    except subprocess.CalledProcessError as error:
        # Do not echo credentials that might appear in a remote URL or stderr.
        raise c.CatalogueError(f'Git {args[0]} failed (exit {error.returncode}); publication stopped') from error
    except subprocess.TimeoutExpired as error:
        raise c.CatalogueError(f'Git {args[0]} timed out; publication stopped') from error


def remote_ref(root, remote, ref):
    output = git(root, 'ls-remote', '--refs', remote, ref).decode().strip()
    if not output:
        return None
    rows = [line.split() for line in output.splitlines()]
    c.require(len(rows) == 1 and len(rows[0]) == 2 and rows[0][1] == ref,
              'unexpected remote ref response')
    sha = rows[0][0]
    c.require(bool(re.fullmatch(r'[0-9a-f]{40}', sha)), 'unexpected remote commit format')
    return sha


def publish(root, remote, revision):
    # Source validates that the revision is a full commit SHA, not an option/ref.
    source = c.Source(root, revision)
    if remote_ref(root, remote, 'refs/heads/main') != revision:
        return 'Skipped: source revision is no longer upstream main.'
    generator = c.Generator(source)
    registry = generator.build()
    for warning in generator.warnings:
        print('catalogue: ' + warning, file=sys.stderr)
    payload = c.encode(registry).encode('utf-8')

    parent = None
    if remote_ref(root, remote, BRANCH):
        git(root, 'fetch', '--no-tags', remote, BRANCH)
        parent = git(root, 'rev-parse', 'FETCH_HEAD').decode().strip()
        old_payload = git(root, 'show', parent + ':catalogue.json')
        try:
            old = json.loads(old_payload)
        except (ValueError, UnicodeError) as error:
            raise c.CatalogueError('existing catalogue is invalid; refusing to replace it') from error
        c.require(isinstance(old, dict) and old.get('schema_version') == 1 and old.get('draft') is False,
                  'existing catalogue has an unsupported schema or is a draft')
        previous = old.get('source', {})
        c.require(isinstance(previous, dict) and previous.get('repository') == c.REPOSITORY,
                  'existing catalogue has an unexpected source repository')
        previous_revision = previous.get('revision')
        c.require(isinstance(previous_revision, str) and bool(re.fullmatch(r'[0-9a-f]{40}', previous_revision)),
                  'existing catalogue has an invalid source revision')
        # Reject a rollback or divergent source history, including an old rerun.
        git(root, 'merge-base', '--is-ancestor', previous_revision, revision)
        if old_payload == payload:
            return 'Unchanged: this source revision is already published.'
        c.require(previous_revision != revision,
                  'existing catalogue differs for the same source revision; investigate before replacing it')

    # Build a tree containing only the generated JSON, leaving HEAD/index/files alone.
    blob = git(root, 'hash-object', '-w', '--stdin', data=payload).decode().strip()
    tree = git(root, 'mktree', data=f'100644 blob {blob}\tcatalogue.json\n'.encode()).decode().strip()
    parents = ['-p', parent] if parent else []
    commit = git(root, '-c', 'user.name=github-actions[bot]',
                 '-c', 'user.email=41898282+github-actions[bot]@users.noreply.github.com',
                 '-c', 'commit.gpgsign=false', 'commit-tree', tree, *parents,
                 data=f'Publish catalogue from {revision}\n'.encode()).decode().strip()

    # A queued old run must not publish after main has advanced.
    if remote_ref(root, remote, 'refs/heads/main') != revision:
        return 'Skipped: upstream main advanced while generating the catalogue.'
    # A concurrent publication makes this non-fast-forward and Git rejects it.
    # Never force-push or retry using a different parent without revalidating.
    git(root, 'push', remote, f'{commit}:{BRANCH}')
    return (f'Published {len(registry["effects"])} effects and {len(registry["families"])} families '
            f'from {revision} (catalogue commit {commit}).')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--remote', default='origin')
    parser.add_argument('--revision', required=True)
    args = parser.parse_args(argv)
    try:
        c.require(not args.remote.startswith('-'), 'invalid remote name')
        url = git(args.root, 'remote', 'get-url', '--push', args.remote).decode().strip()
        fetch_url = git(args.root, 'remote', 'get-url', args.remote).decode().strip()
        c.require(url in UPSTREAM_REMOTES and fetch_url in UPSTREAM_REMOTES,
                  'publisher remote must fetch from and push to the Noctalia upstream repository')
        print(publish(args.root, args.remote, args.revision))
        return 0
    except (c.CatalogueError, OSError, UnicodeError) as error:
        print(f'catalogue publication: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
