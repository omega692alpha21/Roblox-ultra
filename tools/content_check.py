#!/usr/bin/env python3
"""Prove every mission, quest and story objective can actually be finished.

The failure this exists to catch is silent and total: an objective whose
`stat` is never incremented anywhere. It compiles, it shows up in the journal,
its bar sits at 0/5 forever, and nothing in the game complains. Same for a
mission giver standing somewhere you cannot walk to, or a reward that names a
rarity the roster does not have.

    python3 tools/content_check.py

Exit code is 1 if anything is unreachable or uncountable.
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "src")


def read(*parts):
    return open(os.path.join(ROOT, *parts)).read()


def main():
    bad = []

    mission_src = read("ServerScriptService", "Services", "MissionService.luau")
    quest_src = read("ServerScriptService", "Services", "QuestService.luau")
    story_src = read("ServerScriptService", "Services", "StoryService.luau")
    rewards_src = read("ReplicatedStorage", "Config", "Rewards.luau")
    story_cfg = read("ReplicatedStorage", "Config", "Story.luau")
    students_src = read("ReplicatedStorage", "Config", "Students.luau")

    # ---- 1. every counter an objective names is one something increments ----
    # Missions and daily quests share the bump() vocabulary.
    counted = set(re.findall(r'bump\(\s*\w+\s*,\s*"([a-z]+)"', mission_src))
    counted |= set(re.findall(r'bump\(\s*\w+\s*,\s*"([a-z]+)"', quest_src))
    mission_stats = set(re.findall(r'stat = "([a-z]+)"', mission_src))
    quest_stats = set(re.findall(r'stat = "([a-z]+)"', rewards_src))

    for stat in sorted(mission_stats):
        if stat not in counted:
            bad.append(f"mission stat '{stat}' is never counted — that mission can never finish")
    for stat in sorted(quest_stats):
        if stat not in counted:
            bad.append(f"daily quest stat '{stat}' is never counted — that quest can never finish")

    # The story keeps its own counters, plus a set of values it reads straight
    # off the profile for "reach this number" objectives.
    story_counted = set(re.findall(r'Bump\(\s*\w+\s*,\s*"([a-zA-Z]+)"', story_src))
    story_counted |= set(re.findall(r'story\.counts\[\s*"([a-zA-Z]+)"\s*\]', story_src))
    story_reach = set(re.findall(r'objective\.stat == "([a-zA-Z]+)"', story_src))
    for m in re.finditer(r'stat = "([a-zA-Z]+)", goal = [\d.]+(, kind = "(\w+)")?', story_cfg):
        stat, kind = m.group(1), m.group(3)
        if kind == "reach":
            if stat not in story_reach:
                bad.append(f"story objective '{stat}' is a reach target the service cannot read")
        elif stat not in story_counted:
            bad.append(f"story objective '{stat}' is never counted — that chapter can never close")

    # ---- 2. every rarity a reward names exists on the roster ----
    rarities = set(re.findall(r'^\t\tname = "(\w+)",', students_src, re.M))
    if not rarities:
        rarities = set(re.findall(r'name = "(Common|Rare|Epic|Legendary|Mythic|Secret)"', students_src))
    for named in set(re.findall(r'rarity = "(\w+)"', rewards_src)):
        if named not in rarities:
            bad.append(f"reward grants rarity '{named}', which is not a rarity on the roster")

    # ---- 3. every mission giver stands somewhere you can reach ----
    anchors_path = os.path.join(HERE, "_map_anchors.json")
    dump_path = os.path.join(HERE, "_map_export.json")
    givers = []
    for m in re.finditer(
        r'name = "([^"]+)",\s*\n\s*baseId[^\n]*\n(?:[^\n]*\n)?\s*position = Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)',
        mission_src,
    ):
        givers.append((m.group(1), [float(m.group(i)) for i in (2, 3, 4)]))
    if not givers:
        bad.append("could not read any mission givers out of MissionService")
    elif os.path.exists(dump_path):
        sys.path.insert(0, HERE)
        src = open(os.path.join(HERE, "world_audit.py")).read()
        src = src.replace('if __name__ == "__main__":\n    sys.exit(main())', "")
        env = {"__name__": "world_audit_lib"}
        argv = sys.argv
        sys.argv = ["world_audit", dump_path, os.path.join(HERE, "..")]
        exec(compile(src, "world_audit.py", "exec"), env)
        sys.argv = argv
        for name, point in givers:
            if not env["reachable"](point):
                bad.append(f"mission giver {name} at {point} — nowhere within reach is standable")

    # ---- 4. missions get harder, not easier ----
    for block in re.findall(r'missions = \{(.*?)\n\t\t\},\n\t\},', mission_src, re.S):
        goals = [(m.group(1), float(m.group(2)))
                 for m in re.finditer(r'stat = "(\w+)", goal = ([\d.]+)', block)]
        by_stat = {}
        for stat, goal in goals:
            by_stat.setdefault(stat, []).append(goal)
        for stat, values in by_stat.items():
            if values != sorted(values):
                bad.append(f"a giver's '{stat}' missions go {values} — a later one is easier than an earlier one")

    for line in bad:
        print("  " + line)
    print(
        f"{len(mission_stats)} mission stats, {len(quest_stats)} quest stats, "
        f"{len(givers)} givers — " + (f"{len(bad)} broken" if bad else "all countable and reachable")
    )
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
