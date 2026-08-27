#!/usr/bin/env python3
"""Prove the HUD cannot overlap itself or Roblox's own controls.

Reads the Scale constants straight out of Layout.luau, so it cannot drift from
the game. Run after touching any zone:

    python3 tools/hud_zonecheck.py

Roblox reserves four corners of a phone screen before we place anything - its
topbar, the player thumbnail, the movement thumbstick and the jump control -
and several builds shipped with elements sitting on top of them.
"""
import re, sys

LAY = "src/StarterPlayer/StarterPlayerScripts/Controllers/Layout.luau"
src = open(LAY).read()

def c(name):
    m = re.search(rf'^Layout\.{name} = ([0-9.]+)', src, re.M)
    if not m:
        sys.exit(f"missing Layout.{name}")
    return float(m.group(1))

# a landscape phone, 2.27:1 - the tightest case. Squares are sized off HEIGHT,
# so their width as a fraction of the screen is height_fraction / ASPECT.
ASPECT = 2.27
sq = lambda f: f / ASPECT

E = c("EdgeX")
Z = {}

mm = c("MinimapH")
Z["minimap"] = (E, c("MinimapY"), E + sq(mm), c("MinimapY") + mm)

menu_tile = c("MenuTileH") * c("MenuRailH")
Z["menu rail"] = (E, c("MenuRailY"), E + sq(menu_tile), c("MenuRailY") + c("MenuRailH"))

tool_tile = c("ToolTileH") * c("ToolRailH")
Z["tool rail"] = (1 - E - sq(tool_tile), c("ToolRailY"), 1 - E, c("ToolRailY") + c("ToolRailH"))

Z["pills"] = (0.5 - c("PillsW") / 2, c("PillsY"), 0.5 + c("PillsW") / 2, c("PillsY") + c("PillsH"))
Z["goal chip"] = (0.5 - c("GoalW") / 2, c("GoalY"), 0.5 + c("GoalW") / 2, c("GoalY") + c("GoalH"))

aw, ah = c("ActionW"), c("ActionH")
Z["action bar"] = (c("ActionRight") - aw, c("ActionBottom") - ah, c("ActionRight"), c("ActionBottom"))

R = {}
for m in re.finditer(r'(\w+) = \{ ([0-9.]+), ([0-9.]+), ([0-9.]+), ([0-9.]+) \}', src):
    R["rbx " + m.group(1)] = tuple(float(m.group(i)) for i in range(2, 6))
if not R:
    sys.exit("could not read Layout.Reserved")

def hit(a, b):
    return not (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])

bad = 0
names = list(Z)
for i in range(len(names)):
    for j in range(i + 1, len(names)):
        if hit(Z[names[i]], Z[names[j]]):
            print(f"  OVERLAP  {names[i]} x {names[j]}")
            bad += 1
for n, z in Z.items():
    for rn, r in R.items():
        if hit(z, r):
            print(f"  OVERLAP  {n} x {rn}")
            bad += 1

for n, (x1, y1, x2, y2) in sorted(Z.items()):
    print(f"  {n:11s} x {x1:.2f}-{x2:.2f}   y {y1:.2f}-{y2:.2f}")
for n, (x1, y1, x2, y2) in sorted(R.items()):
    print(f"  {n:11s} x {x1:.2f}-{x2:.2f}   y {y1:.2f}-{y2:.2f}   (reserved)")

print("PASS - nothing overlaps" if bad == 0 else f"FAIL - {bad} overlaps")
sys.exit(0 if bad == 0 else 1)
