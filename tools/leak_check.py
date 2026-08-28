#!/usr/bin/env python3
"""Find per-player state that is never released when the player leaves.

Every `{ [Player]: ... }` table in a service is a strong reference to a Player
instance. A server that has run for six hours has had hundreds of players
through it, and any table that never drops them keeps every one of those
characters, profiles and connections alive. It does not crash; it degrades,
which is worse, because nothing points at the cause.

The rule this enforces: if a module declares a table keyed by Player, that
module must clear the key somewhere -- almost always in a PlayerRemoving
handler, sometimes in a shared cleanup function.

    python3 tools/leak_check.py

Exit code is 1 if anything is unreleased.
"""
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")

# annotated: `local lastPunch: { [Player]: number } = {}`
DECL = re.compile(r'^local ([A-Za-z0-9_]+)\s*:\s*\{\s*\[Player\]\s*:', re.M)
# untyped: `local lastPunch = {}` that the file then indexes with a player
BARE = re.compile(r'^local ([A-Za-z0-9_]+)\s*=\s*\{\}\s*$', re.M)
PLAYER_KEY = re.compile(r'\[(player|other|target|owner|asker|mate|from|hit)\b')


def main():
    bad, checked = [], 0
    for base, _, names in os.walk(ROOT):
        for name in sorted(names):
            if not name.endswith(".luau"):
                continue
            path = os.path.join(base, name)
            rel = os.path.relpath(path, os.path.join(ROOT, ".."))
            src = open(path).read()
            tables = list(DECL.findall(src))
            for table in BARE.findall(src):
                if table in tables:
                    continue
                # only count it if the file actually indexes it by a player
                for use in re.findall(rf'\b{table}(\[[A-Za-z0-9_.]+\])', src):
                    if PLAYER_KEY.match(use):
                        tables.append(table)
                        break
            if not tables:
                continue
            has_removing = "PlayerRemoving" in src
            for table in tables:
                checked += 1
                # cleared by assignment, by table.remove, or wholesale
                cleared = (
                    re.search(rf'\b{table}\[[A-Za-z0-9_.]+\]\s*=\s*nil', src)
                    or re.search(rf'table\.clear\(\s*{table}\s*\)', src)
                    or re.search(rf'\b{table}\[[A-Za-z0-9_.]+\]\s*=\s*nil', src)
                )
                if not cleared:
                    bad.append(f"{rel}: `{table}` is keyed by Player and never cleared")
                elif not has_removing:
                    bad.append(
                        f"{rel}: `{table}` is cleared somewhere but the module has no "
                        "PlayerRemoving handler"
                    )

    for line in bad:
        print("  " + line)
    print(f"{checked} per-player tables — " + (f"{len(bad)} leaking" if bad else "all released"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
