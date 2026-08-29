#!/usr/bin/env python3
"""Find a building that was not built the way the rest of the school was.

Every check in this repo asks whether something PRESENT is wrong -- a wall
through a roof, a stair into a slab, a prop inside a bench. None of them can
see an absence, because a building with no chimneys looks exactly like a
building drawn without them, and a roof that is a flat slab is a perfectly
valid part in a perfectly sensible place.

That blind spot cost two things. The library was the one building on campus
with no collegiate work on it at all -- no plinth, no string course, no
cornice, no quoins, no dormers, no chimney, and a flat grey slab a stud and a
half thick for a roof -- and the Academy, with a hundred and twenty dormers, a
clock tower and a spire, had not one chimney stack on any of its seven ridges.
Both were found by counting features per building by hand. This does it every
build.

The vocabulary is CollegiateKit's, and the rule is that a building uses it:

  plinth  a base course at the foot, so the wall does not grow out of the lawn
  string  a course at each floor above the first
  cornice an eaves course at the top
  quoins  dressed stone at the corners (or pilasters, on a tower)
  roof    PITCHED -- wedges, not a slab. Every reference roof is steep slate.
  dormer  the slopes are broken by them; a bare pitch is the largest blank
          surface a building has
  chimney at least one stack on the ridge
  door    a way in that reads as one: a leaf, a porch, an entrance bay

    python3 tools/render_map.py .
    python3 tools/kit_check.py
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")
PLAN = os.path.join(HERE, "_campus_plan.json")

# Buildings the drawing does not hold: the staff lodge is MapService's own, and
# it is a building by any measure -- three storeys, a turret and the
# headmaster's office in the roof.
EXTRA = [{"name": "Staff Lodge", "rect": [-342, -202, -258, -138], "storeys": 3}]

# What each feature is called, across all three builders (the Academy's own
# Facade*, PlanBuilder's Plan*, and the hand-built library and lodge).
FEATURES = {
    "plinth":  ("Plinth", "BaseCourse", "FacadeBase"),
    "string":  ("StringCourse",),
    "cornice": ("Cornice", "Eaves", "RoofKerb", "Architrave"),
    "quoins":  ("Quoin", "Pilaster", "Buttress"),
    "dormer":  ("Dormer",),
    "chimney": ("Chimney",),
    "door":    ("DoorLeaf", "EntryBay", "EntranceBay", "Portico", "Porch",
                "MainDoor", "Column"),
}
# A roof is pitched when it slopes: a wedge, a tilted slab, or a part the
# builders named for a pitch. A flat axis-aligned box named "Roof" is a lid.
PITCHED = ("PitchRoof", "RoofPlane", "GableEnd", "RoofSlope")


def tilted(p):
    """Is this part rotated off the world axes at all?"""
    r = p["r"]
    return not (abs(abs(r[0]) - 1) < 1e-4 and abs(abs(r[4]) - 1) < 1e-4
                and abs(abs(r[8]) - 1) < 1e-4)

# How many of each a building must have. Quoins come four to a building, one
# per corner; everything else needs at least one to prove the builder knew
# about it.
NEED = {"plinth": 1, "string": 1, "cornice": 1, "quoins": 4,
        "roof": 2, "dormer": 2, "chimney": 1, "door": 1}
WHY = {
    "plinth": "no base course: the wall grows straight out of the lawn",
    "string": "no string course between storeys",
    "cornice": "no eaves or cornice at the head of the wall",
    "quoins": "fewer than four dressed corners",
    "roof": "the roof is not pitched -- a flat slab where the campus is steep slate",
    "dormer": "no dormers: the roof is one blank plane",
    "chimney": "not one chimney stack on the whole roof",
    "door": "no entrance that reads as one",
}
PAD = 10.0   # a cornice oversails, a chimney leans out; measure a little wide


def main():
    parts = json.load(open(DUMP))
    plan = json.load(open(PLAN))
    sites = [s for s in plan["site"] if s.get("kind") == "building"] + EXTRA
    storeys = {b["name"]: len(b.get("storeys", [])) for b in plan["buildings"]}
    for e in EXTRA:
        storeys[e["name"]] = e["storeys"]

    bad, table = [], []
    for site in sites:
        r = site["rect"]
        inside = [p for p in parts
                  if r[0] - PAD < p["p"][0] < r[2] + PAD
                  and r[1] - PAD < p["p"][2] < r[3] + PAD]
        got = {}
        for feat, words in FEATURES.items():
            got[feat] = sum(1 for p in inside if any(w in p["n"] for w in words))
        got["roof"] = sum(1 for p in inside
                          if any(w in p["n"] for w in PITCHED)
                          or ("Roof" in p["n"]
                              and (p.get("cls") == "WedgePart" or tilted(p))))

        missing = [f for f, need in NEED.items() if got[f] < need]
        # A single-storey building has no floor above the first for a string
        # course to run at, so it is not owed one. The storey count comes off
        # the drawing, not off how tall the parts happen to be -- a
        # single-storey gymnasium is 26 studs to the eaves and any height
        # heuristic calls it a two-storey building.
        if "string" in missing and storeys.get(site["name"], 1) < 2:
            missing.remove("string")
        table.append((site["name"], len(inside), got, missing))
        for f in missing:
            bad.append((site["name"], f))

    width = max(len(n) for n, _, _, _ in table)
    for name, n, got, missing in table:
        mark = "  " if not missing else "!!"
        cells = " ".join(f"{f}={got[f]}" for f in NEED)
        print(f"{mark} {name:<{width}} {n:5d} parts  {cells}")
    if bad:
        for name, f in bad:
            print(f"   {name}: {WHY[f]}")
        print(f"FAIL - {len(bad)} pieces of the kit missing across "
              f"{len({n for n, _ in bad})} buildings")
        return 1
    print(f"PASS - all {len(table)} buildings are built from the same kit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
