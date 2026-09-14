#!/usr/bin/env python3
"""Audit the restic backup of a directory tree without touching the repository.

It walks the tree with the same rules that restic applies, so it reports what
the job would really send: how much data is included, which directories and
files make up the bulk of it, how much every exclude pattern saves, and which
patterns match nothing at all.

The pattern file is the one the systemd unit passes to restic, so the audit
always follows the configuration that is active.

    uv run scripts/backup-audit.py /home/necauqua
    uv run scripts/backup-audit.py --patterns path/to/exclude-patterns ~

With `--patterns -` the list comes from stdin, which evaluating the option
gives without building anything:

    nix eval --raw --apply 'builtins.concatStringsSep "\n"' \
      '.#nixosConfigurations.main.config.services.restic.backups.offsite.exclude' \
      | uv run scripts/backup-audit.py --patterns - ~

Most of the cost is one stat call per file, so the patterns are arranged as
dictionary lookups to keep the interpreter out of the way. The walk uses a few
threads, because stat releases the lock of the interpreter and the disk answers
several requests at once; that pays off while the cache is cold and costs a
little once everything is cached, so `--jobs` is there to tune it.
"""

import argparse
import fnmatch
import os
import re
import sys
import threading
from collections import defaultdict, deque

UNIT = "/run/current-system/etc/systemd/system/restic-backups-offsite.service"
CACHEDIR_TAG = b"Signature: 8a477f597d28d172789f06886806bc55"
CACHES = "--exclude-caches"
GLOB_CHARS = re.compile(r"[*?\[]")


def find_pattern_file():
    """The exclude file of the active backup job."""
    try:
        with open(UNIT) as unit:
            found = re.search(r"--exclude-file=(\S+)", unit.read())
    except OSError as error:
        sys.exit(f"cannot read {UNIT}: {error}\nuse --patterns instead")
    if not found:
        sys.exit(f"no --exclude-file in {UNIT}\nuse --patterns instead")
    return found.group(1)


def read_patterns(path):
    file = sys.stdin if path == "-" else open(path)
    try:
        return [
            line.rstrip("\n")
            for line in file
            if line.strip() and not line.startswith("#")
        ]
    finally:
        if file is not sys.stdin:
            file.close()


def matches(pattern_parts, path_parts):
    """Match like restic: a pattern that starts with a slash is anchored at the
    root, every other pattern matches the end of the path, and ** stands for
    any number of components."""
    if not pattern_parts:
        return not path_parts
    head = pattern_parts[0]
    if head == "**":
        for offset in range(len(path_parts) + 1):
            if matches(pattern_parts[1:], path_parts[offset:]):
                return True
        return False
    if not path_parts:
        return False
    if not fnmatch.fnmatchcase(path_parts[0], head):
        return False
    return matches(pattern_parts[1:], path_parts[1:])


class Matcher:
    """The same rules as `matches`, arranged so that the common patterns cost
    one dictionary lookup instead of a walk over the whole list.

    A pattern of a single component can only match the name of an entry, and a
    pattern anchored with a slash can only match one full path, so both become
    dictionaries. Everything else keeps the general path."""

    def __init__(self, patterns):
        self.names = {}  # plain name -> pattern
        self.paths = {}  # full path -> pattern
        self.rest = []  # (pattern, anchored, parts)
        globs = []
        self.glob_names = {}  # group name -> pattern
        for pattern in patterns:
            anchored = pattern.startswith("/")
            parts = [part for part in pattern.split("/") if part]
            if not parts:
                continue
            globby = bool(GLOB_CHARS.search(pattern))
            if not anchored and len(parts) == 1:
                if globby:
                    group = f"g{len(globs)}"
                    self.glob_names[group] = pattern
                    globs.append(f"(?P<{group}>{fnmatch.translate(parts[0])})")
                else:
                    self.names.setdefault(parts[0], pattern)
            elif anchored and not globby:
                self.paths.setdefault("/" + "/".join(parts), pattern)
            else:
                self.rest.append((pattern, anchored, parts))
        self.globs = re.compile("|".join(globs)) if globs else None

    def rejects(self, name, path):
        """The pattern that excludes this entry, or None."""
        pattern = self.names.get(name)
        if pattern is not None:
            return pattern
        if self.globs is not None:
            found = self.globs.match(name)
            if found is not None:
                return self.glob_names[found.lastgroup]
        pattern = self.paths.get(path)
        if pattern is not None:
            return pattern
        if not self.rest:
            return None
        parts = path.split(os.sep)[1:]
        for pattern, anchored, pattern_parts in self.rest:
            if anchored:
                if matches(pattern_parts, parts):
                    return pattern
            else:
                for offset in range(len(parts) - len(pattern_parts) + 1):
                    if matches(pattern_parts, parts[offset:]):
                        return pattern
        return None


class Totals:
    """What one thread found, merged into one of these at the end."""

    def __init__(self, top):
        self.top = top
        self.files = 0
        self.bytes = 0
        self.skipped = 0
        self.unreadable = 0
        self.direct = defaultdict(int)  # directory -> bytes of its own files
        self.excluded = defaultdict(int)  # pattern -> bytes it keeps out
        self.biggest = []

    def file(self, directory, path, size):
        self.files += 1
        self.bytes += size
        self.direct[directory] += size
        self.biggest.append((size, path))
        if len(self.biggest) > 4 * self.top + 4096:
            self.biggest.sort(reverse=True)
            del self.biggest[self.top:]

    def merge(self, other):
        self.files += other.files
        self.bytes += other.bytes
        self.skipped += other.skipped
        self.unreadable += other.unreadable
        for directory, size in other.direct.items():
            self.direct[directory] += size
        for pattern, size in other.excluded.items():
            self.excluded[pattern] += size
        self.biggest.extend(other.biggest)


def is_cache_dir(path, names):
    if "CACHEDIR.TAG" not in names:
        return False
    try:
        with open(os.path.join(path, "CACHEDIR.TAG"), "rb") as tag:
            return tag.read(len(CACHEDIR_TAG)) == CACHEDIR_TAG
    except OSError:
        return False


def walk(root, matcher, jobs, top, quick, use_caches):
    """Walk the tree with a pool of threads over a queue of directories.

    An entry that a pattern rejects is still walked, because the report tells
    how much every pattern saves; `quick` drops that and only counts the
    entries. Directories carry the pattern that rejected them, so everything
    below one is charged to it without matching again.

    Each thread keeps the directories it finds to itself and only hands the
    oldest ones over when it has a few to spare, so the shared queue is touched
    about once per handful of directories instead of once per directory."""
    pending = deque([(root, None)])
    lock = threading.Lock()
    idle = threading.Condition(lock)
    waiting = 0
    done = False
    hardlinks = set()

    def worker(mine):
        nonlocal waiting, done
        local = deque()
        while True:
            if local:
                path, rejected = local.pop()
            else:
                with idle:
                    while not pending and not done:
                        waiting += 1
                        if waiting == jobs:
                            done = True
                            idle.notify_all()
                        else:
                            idle.wait()
                        waiting -= 1
                    if done and not pending:
                        return
                    path, rejected = pending.popleft()
            try:
                entries = list(os.scandir(path))
            except OSError:
                mine.unreadable += 1
                continue
            names = {entry.name for entry in entries}
            if rejected is None and use_caches and is_cache_dir(path, names):
                rejected = CACHES
                mine.excluded[CACHES] += 0
                mine.skipped += 1
                if quick:
                    continue
            found = []
            for entry in entries:
                try:
                    if entry.is_dir(follow_symlinks=False):
                        below = rejected or matcher.rejects(entry.name, entry.path)
                        if below is not None:
                            mine.excluded[below] += 0
                            if rejected is None:
                                mine.skipped += 1
                            if quick:
                                continue
                        found.append((entry.path, below))
                        continue
                    pattern = rejected or matcher.rejects(entry.name, entry.path)
                    if pattern is not None:
                        mine.excluded[pattern] += 0
                        if rejected is None:
                            mine.skipped += 1
                        if quick:
                            continue
                        mine.excluded[pattern] += entry.stat(
                            follow_symlinks=False
                        ).st_size
                        continue
                    stat = entry.stat(follow_symlinks=False)
                except OSError:
                    continue
                if stat.st_nlink > 1:
                    key = (stat.st_dev, stat.st_ino)
                    with lock:
                        if key in hardlinks:
                            continue
                        hardlinks.add(key)
                mine.file(path, entry.path, stat.st_size)
            local.extend(found)
            if len(local) > 3 and jobs > 1:
                with idle:
                    share = len(local) // 2
                    for _ in range(share):
                        pending.append(local.popleft())
                    idle.notify(share if share < jobs else jobs)

    results = [Totals(top) for _ in range(jobs)]
    threads = [
        threading.Thread(target=worker, args=(mine,), daemon=True) for mine in results
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    totals = Totals(top)
    for other in results:
        totals.merge(other)
    return totals


def roll_up(direct, root):
    """Turn the bytes of every directory into the bytes below it."""
    total = defaultdict(int)
    for directory, size in direct.items():
        total[directory] += size
        parent = directory
        while len(parent) > len(root):
            parent = os.path.dirname(parent)
            total[parent] += 0
    for directory in sorted(total, key=lambda path: -path.count(os.sep)):
        if directory == root or len(directory) <= len(root):
            continue
        total[os.path.dirname(directory)] += total[directory]
    return total


def human(size):
    for unit in ["B", "K", "M", "G", "T"]:
        if size < 1024 or unit == "T":
            return f"{size:.0f}B" if unit == "B" else f"{size:.1f}{unit}"
        size /= 1024


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", help="directory to audit")
    parser.add_argument("--patterns",
                        help="exclude file, - for stdin, defaults to the active job")
    parser.add_argument("--top", type=int, default=25, help="rows per table")
    parser.add_argument("--depth", type=int, default=3,
                        help="depth of the directory table")
    parser.add_argument("--jobs", type=int, default=4,
                        help="threads; more helps a cold cache, 1 is best on a warm one")
    parser.add_argument("--quick", action="store_true",
                        help="do not size what the patterns exclude, only count it")
    parser.add_argument("--no-exclude-caches", action="store_true",
                        help="ignore CACHEDIR.TAG, which the job honours")
    arguments = parser.parse_args()

    root = os.path.abspath(arguments.root)
    pattern_file = arguments.patterns or find_pattern_file()
    patterns = read_patterns(pattern_file)
    matcher = Matcher(patterns)
    jobs = max(1, arguments.jobs)

    print(f"root:     {root}")
    print(f"patterns: {pattern_file} ({len(patterns)} of them)")
    print(f"threads:  {jobs}\n")

    totals = walk(root, matcher, jobs, arguments.top, arguments.quick,
                  not arguments.no_exclude_caches)

    print(f"included: {human(totals.bytes)} in {totals.files} files")
    excluded = sum(totals.excluded.values())
    print(f"excluded: {human(excluded)} in {totals.skipped} entries"
          + (" (not sized, --quick)" if arguments.quick else ""))
    if totals.unreadable:
        print(f"warning:  {totals.unreadable} directories could not be read")

    below = roll_up(totals.direct, root)
    depth = root.count(os.sep) + arguments.depth
    rows = [
        (size, path)
        for path, size in below.items()
        if path != root and path.count(os.sep) <= depth
    ]
    print(f"\nbiggest included directories (depth {arguments.depth}):")
    for size, path in sorted(rows, reverse=True)[: arguments.top]:
        print(f"  {human(size):>8}  {path}")

    totals.biggest.sort(reverse=True)
    print("\nbiggest included files:")
    for size, path in totals.biggest[: arguments.top]:
        print(f"  {human(size):>8}  {path}")

    if not arguments.quick:
        print("\nsavings per pattern:")
        order = sorted(totals.excluded.items(), key=lambda row: (-row[1], row[0]))
        for pattern, size in order:
            print(f"  {human(size):>8}  {pattern}")

    dead = [pattern for pattern in patterns if pattern not in totals.excluded]
    if dead:
        print("\npatterns that match nothing:")
        for pattern in dead:
            print(f"  {pattern}")


if __name__ == "__main__":
    main()
