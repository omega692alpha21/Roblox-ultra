#!/usr/bin/env python3
"""Validate THE DRAWING -- src/ReplicatedStorage/Shared/CampusPlan.luau -- on
its own, before a single part exists.

Every other check in this repo runs on a built map, which means every design
mistake had to be built, published and played before anybody found it. That is
why the same bugs kept coming back: a stair behind a wall, a room with no door,
lockers across the principal's office. None of those are construction faults.
They are drawing faults, and a drawing can be checked in a second.

    python3 tools/plan_export.py && python3 tools/plan_check.py
"""
import json, os, sys
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
PLAN = os.path.join(HERE, "_campus_plan.json")

EPS = 1e-6


def area(r):
    return (r[2] - r[0]) * (r[3] - r[1])


def overlap(a, b):
    return a[0] < b[2] - EPS and b[0] < a[2] - EPS and a[1] < b[3] - EPS and b[1] < a[3] - EPS


def inside(inner, outer):
    return (inner[0] >= outer[0] - EPS and inner[1] >= outer[1] - EPS
            and inner[2] <= outer[2] + EPS and inner[3] <= outer[3] + EPS)


def adjacent(a, b):
    """Do two rects share a face of non-zero length (not just a corner)?"""
    if abs(a[2] - b[0]) < EPS or abs(b[2] - a[0]) < EPS:
        return min(a[3], b[3]) - max(a[1], b[1]) > EPS
    if abs(a[3] - b[1]) < EPS or abs(b[3] - a[1]) < EPS:
        return min(a[2], b[2]) - max(a[0], b[0]) > EPS
    return False


def shared_edge(a, b):
    """The overlap of two rects' shared face, as (lo, hi), or None."""
    if abs(a[2] - b[0]) < EPS or abs(b[2] - a[0]) < EPS:
        lo, hi = max(a[1], b[1]), min(a[3], b[3])
        return ("x", lo, hi) if hi - lo > EPS else None
    if abs(a[3] - b[1]) < EPS or abs(b[3] - a[1]) < EPS:
        lo, hi = max(a[0], b[0]), min(a[2], b[2])
        return ("z", lo, hi) if hi - lo > EPS else None
    return None


def check_site(plan, bad):
    core, plot = plan["core"], plan["plot"]
    if not inside(core, plot):
        bad.append(("site", "the core is not inside the plot"))

    linked = {}
    for e in plan["site"]:
        linked[e["name"]] = set(e.get("link") or [])

    for e in plan["site"]:
        if not inside(e["rect"], core):
            bad.append(("site", f"{e['name']} {e['rect']} is not inside the core {core}"))

    for i, a in enumerate(plan["site"]):
        for b in plan["site"][i + 1:]:
            if overlap(a["rect"], b["rect"]):
                if b["name"] in linked[a["name"]] and a["name"] in linked[b["name"]]:
                    continue
                bad.append(("site", f"{a['name']} overlaps {b['name']}"))

    # the reserves: cleared ground held for future buildings
    reserved = 0.0
    for i, r in enumerate(plan["reserves"]):
        if not inside(r["rect"], plot):
            bad.append(("reserve", f"{r['name']} is not inside the plot"))
        if overlap(r["rect"], core):
            bad.append(("reserve", f"{r['name']} overlaps the built core"))
        for other in plan["reserves"][i + 1:]:
            if overlap(r["rect"], other["rect"]):
                bad.append(("reserve", f"{r['name']} overlaps {other['name']}"))
        reserved += area(r["rect"])
        for e in plan["site"]:
            if overlap(r["rect"], e["rect"]):
                bad.append(("reserve", f"{e['name']} is built on {r['name']}"))

    ratio = reserved / area(core)
    if ratio < plan["reserveRatio"] - 1e-3:
        bad.append(("reserve", f"expansion land is only {ratio:.2f}x the core, "
                               f"below the required {plan['reserveRatio']}x"))
    return ratio


def check_building(b, const, bad):
    name = b["name"]
    gx, gz = b["grid"]["x"], b["grid"]["z"]
    for label, bands in (("x", gx), ("z", gz)):
        for i in range(len(bands) - 1):
            if bands[i + 1] <= bands[i]:
                bad.append((name, f"{label} grid band {i + 1} is not increasing"))

    envelope = [b["rect"][0] + const["exteriorWall"], b["rect"][1] + const["exteriorWall"],
                b["rect"][2] - const["exteriorWall"], b["rect"][3] - const["exteriorWall"]]

    storeys = b["storeys"]
    by_storey = {}

    for s in storeys:
        idx, cells = s["index"], s["cells"]
        by_storey[idx] = {(c["row"], c["col"]): c for c in cells}

        for c in cells:
            r = c["rect"]
            if not inside(r, envelope):
                bad.append((name, f"{s['name']}: {c['name']} escapes the envelope"))
            w, d = r[2] - r[0], r[3] - r[1]
            if c["kind"] == "corridor":
                if min(w, d) < const["corridorClear"] - EPS:
                    bad.append((name, f"{s['name']}: corridor r{c['row']}c{c['col']} is "
                                      f"{min(w, d):.0f} wide, under the {const['corridorClear']:.0f} clear"))
            elif min(w, d) < const["doorWidth"] + 4:
                bad.append((name, f"{s['name']}: {c['name']} is {min(w, d):.0f} across, "
                                  f"too narrow for a {const['doorWidth']:.0f} door"))

        # every room reaches a corridor, and the door sits in the shared face
        for door in s["doors"]:
            if door.get("orphan"):
                bad.append((name, f"{s['name']}: {door['room']} has no corridor to open onto"))
                continue
            room = by_storey[idx][(door["row"], door["col"])]
            corridor = None
            for c in cells:
                if c["kind"] != "corridor" or not adjacent(room["rect"], c["rect"]):
                    continue
                edge = shared_edge(room["rect"], c["rect"])
                # the shared face has to run the same way the door does, or a
                # corridor round the corner answers for a wall it isn't in
                if not edge or edge[0] != door["axis"]:
                    continue
                pos = door["x"] if edge[0] == "z" else door["z"]
                if edge[1] - EPS <= pos <= edge[2] + EPS:
                    corridor = (c, edge)
                    break
            if corridor is None:
                bad.append((name, f"{s['name']}: {door['room']}'s door is not in a wall it shares "
                                  f"with a corridor"))
                continue
            _, edge = corridor
            pos = door["x"] if edge[0] == "z" else door["z"]
            half = const["doorWidth"] / 2
            if pos - half < edge[1] - EPS or pos + half > edge[2] + EPS:
                bad.append((name, f"{s['name']}: {door['room']}'s door runs off the end of its wall"))

        # the corridors have to be one network, not two disconnected halves
        corridors = [c for c in cells if c["kind"] == "corridor"]
        if corridors:
            seen, queue = {0}, deque([0])
            while queue:
                i = queue.popleft()
                for j, c in enumerate(corridors):
                    if j not in seen and adjacent(corridors[i]["rect"], c["rect"]):
                        seen.add(j)
                        queue.append(j)
            if len(seen) != len(corridors):
                stranded = [corridors[j]["name"] for j in range(len(corridors)) if j not in seen]
                bad.append((name, f"{s['name']}: {len(stranded)} corridor cells are cut off from "
                                  f"the rest ({', '.join(stranded[:3])})"))

    # ---- stairs: a flight has to cover its own rise, and meet the next one ---
    reached = {1}
    going = const["stairTread"] / const["stairRise"]
    for st in b.get("stairs") or []:
        cell_rect = None
        for s in storeys:
            c = by_storey[s["index"]].get((st["cell"]["row"], st["cell"]["col"]))
            if c:
                cell_rect = c["rect"]
                break
        prev = None
        for i, f in enumerate(st["flights"]):
            a, c = f["from"], f["to"]
            rise = abs(c[1] - a[1])
            run = ((c[0] - a[0]) ** 2 + (c[2] - a[2]) ** 2) ** 0.5
            need = rise * going
            if run < need - 0.5:
                bad.append((name, f"{st['name']} flight {i + 1} rises {rise:.0f} over {run:.0f} of "
                                  f"run; it needs {need:.0f}"))
            half = st["width"] / 2
            dx, dz = c[0] - a[0], c[2] - a[2]
            length = (dx * dx + dz * dz) ** 0.5 or 1.0
            px, pz = -dz / length * half, dx / length * half
            xs = [a[0] + px, a[0] - px, c[0] + px, c[0] - px]
            zs = [a[2] + pz, a[2] - pz, c[2] + pz, c[2] - pz]
            foot = [min(xs), min(zs), max(xs), max(zs)]
            if cell_rect and not inside(foot, cell_rect):
                bad.append((name, f"{st['name']} flight {i + 1} does not fit inside "
                                  f"{st['cell']['row']}/{st['cell']['col']}"))
            if prev is not None:
                if abs(prev[1] - a[1]) > EPS:
                    bad.append((name, f"{st['name']}: flight {i + 1} starts at y {a[1]:.0f} but the "
                                      f"one before it ends at {prev[1]:.0f}"))
                pad = (st.get("landings") or [None] * 9)[i - 1]
                if pad is None:
                    bad.append((name, f"{st['name']}: no landing drawn between flights {i} and {i + 1}"))
                else:
                    if abs(pad["y"] - a[1]) > EPS:
                        bad.append((name, f"{st['name']}: landing {i} is at y {pad['y']:.0f}, the "
                                          f"flights meet at {a[1]:.0f}"))
                    for label, pt in (("down", prev), ("up", a)):
                        if not (pad["rect"][0] - EPS <= pt[0] <= pad["rect"][2] + EPS
                                and pad["rect"][1] - EPS <= pt[2] <= pad["rect"][3] + EPS):
                            bad.append((name, f"{st['name']}: the {label} flight does not reach "
                                              f"landing {i}"))
                    if min(pad["rect"][2] - pad["rect"][0],
                           pad["rect"][3] - pad["rect"][1]) < st["width"] - EPS:
                        bad.append((name, f"{st['name']}: landing {i} is narrower than the stair"))
                    if cell_rect and not inside(pad["rect"], cell_rect):
                        bad.append((name, f"{st['name']}: landing {i} does not fit inside "
                                          f"{st['cell']['row']}/{st['cell']['col']}"))
            prev = c

        top = st["flights"][-1]["to"]
        landed = None
        for s in storeys:
            if abs(s["y"] - top[1]) < EPS:
                landed = s
        if landed is None:
            bad.append((name, f"{st['name']} arrives at y {top[1]:.0f}, which is not a storey"))
        else:
            reached.add(landed["index"])
            if not any(inside([top[0], top[2], top[0], top[2]], c["rect"])
                       for c in landed["cells"]):
                bad.append((name, f"{st['name']} lands at "
                                  f"({top[0]:.0f}, {top[2]:.0f}) on {landed['name']}, where there "
                                  f"is no floor"))

    for s in storeys:
        if s["index"] not in reached and s["cells"]:
            bad.append((name, f"{s['name']} has {len(s['cells'])} cells and no stair reaching it"))

    # ---- a room has to stand on something ---------------------------------
    # Missing a cell ABOVE a room is normal: that is the roof. Missing the cell
    # BELOW one is a room floating in mid-air, which is the actual fault, and
    # the only excuse for it is a double-height space rising to meet its floor.
    ends_at = {}
    for d in b.get("doubleHeight") or []:
        ends_at[(d["storey"] + d.get("storeys", 2), d["row"], d["col"])] = d
    for s_ in storeys:
        below = by_storey.get(s_["index"] - 1)
        if not below:
            continue
        for key, c in by_storey[s_["index"]].items():
            if key in below:
                continue
            if (s_["index"], key[0], key[1]) in ends_at:
                continue
            bad.append((name, f"{s_['name']}: {c['name']} has no floor under it"))

    # ---- every way in has to arrive somewhere ------------------------------
    ground = by_storey[1]
    for e in b.get("entrances") or []:
        step = const["exteriorWall"] + 1
        dx = {"north": 0, "south": 0, "east": -step, "west": step}[e["facing"]]
        dz = {"north": -step, "south": step, "east": 0, "west": 0}[e["facing"]]
        px, pz = e["at"]["x"] + dx, e["at"]["z"] + dz
        landed = [c for c in ground.values()
                  if c["rect"][0] - EPS <= px <= c["rect"][2] + EPS
                  and c["rect"][1] - EPS <= pz <= c["rect"][3] + EPS]
        if not landed:
            bad.append((name, f"{e['name']} opens onto nothing at ({px:.0f}, {pz:.0f})"))

    # ---- and every room has to be walkable to from a way in ----------------
    for s in storeys:
        cells = s["cells"]
        corridors = [c for c in cells if c["kind"] == "corridor"]
        if not corridors:
            continue
        live = set()
        for c in cells:
            if c["kind"] == "corridor":
                live.add((c["row"], c["col"]))
        for door in s["doors"]:
            if not door.get("orphan"):
                live.add((door["row"], door["col"]))
        for c in cells:
            if (c["row"], c["col"]) not in live:
                bad.append((name, f"{s['name']}: {c['name']} cannot be walked to"))


def main():
    plan = json.load(open(PLAN))
    bad = []
    ratio = check_site(plan, bad)
    for b in plan["buildings"]:
        check_building(b, plan["const"], bad)

    rooms = sum(sum(1 for c in s["cells"] if c["kind"] == "room")
                for b in plan["buildings"] for s in b["storeys"])
    print(f"drawing: {len(plan['site'])} structures, {len(plan['buildings'])} detailed, "
          f"{rooms} rooms, {ratio:.2f}x expansion land")
    if not bad:
        print("the drawing is sound.")
        return 0
    for where, why in bad:
        print(f"  [{where}] {why}")
    print(f"{len(bad)} problems in the drawing")
    return 1


if __name__ == "__main__":
    sys.exit(main())
