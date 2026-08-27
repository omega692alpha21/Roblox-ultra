#!/usr/bin/env python3
"""Prove the HUD cannot overlap itself or Roblox's own controls.

Reads the real constants out of Layout.luau, so it cannot drift from the game.
Run it after touching any HUD zone:

    python3 tools/hud_zonecheck.py

Roblox reserves four corners of a phone screen before we place anything - its
topbar, the player thumbnail, the movement thumbstick and the jump control -
and three separate builds shipped with elements sitting on top of them. This
catches that before a person has to.
"""
import re
lay = open("/home/user/Roblox-ultra/src/StarterPlayer/StarterPlayerScripts/Controllers/Layout.luau").read()
def c(n):
    m = re.search(rf'^Layout\.{n} = ([0-9.]+)', lay, re.M)
    if not m: raise SystemExit(f"missing Layout.{n}")
    return float(m.group(1))

VH, VW = 400.0, 908.0  # a landscape phone, 2.27:1 - the tightest case
h = lambda f: f * VH
w = lambda f: f * VW
E = c("EdgeX"); tile = h(c("RailTile")); gap = h(c("RailGap"))

Z = {}
Z["minimap"]   = (w(E), h(c("MinimapTop")), w(E) + h(c("MinimapSize")), h(c("MinimapTop")) + h(c("MinimapSize")))
mh = tile * 4 + gap * 3
Z["menu rail"] = (w(E), h(c("MenuRailTop")), w(E) + tile, h(c("MenuRailTop")) + mh)
th = tile * 3 + gap * 2
Z["tool rail"] = (VW - w(E) - tile, h(c("ToolRailTop")), VW - w(E), h(c("ToolRailTop")) + th)
bh = h(c("ToyButtonSize")); bg = h(0.03); bw = bh * 3 + bg * 2
br = VW - w(c("JumpClearance")); bb = VH - h(c("ActionBottom"))
Z["action bar"] = (br - bw, bb - bh, br, bb)
Z["pills"]     = (VW/2 - w(0.17), h(c("PillTop")), VW/2 + w(0.17), h(c("PillTop")) + h(c("PillHeight")))
Z["goal chip"] = (VW/2 - w(0.16), h(c("GoalTop")), VW/2 + w(0.16), h(c("GoalTop")) + h(c("GoalHeight")))

R = {
    "rbx topbar":  (w(0.04), h(0.02), w(0.30), h(0.13)),
    "rbx avatar":  (w(0.92), h(0.02), w(1.00), h(0.16)),
    "rbx stick":   (w(0.00), h(0.70), w(0.24), h(1.00)),
    "rbx jump":    (w(0.80), h(0.66), w(1.00), h(1.00)),
}

def hit(a, b):
    return not (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])

bad = 0
names = list(Z)
for i in range(len(names)):
    for j in range(i + 1, len(names)):
        if hit(Z[names[i]], Z[names[j]]):
            print(f"  OVERLAP  {names[i]} x {names[j]}"); bad += 1
for n, z in Z.items():
    for rn, r in R.items():
        if hit(z, r):
            print(f"  OVERLAP  {n} x {rn}"); bad += 1
for n, (x1, y1, x2, y2) in Z.items():
    print(f"  {n:11s} x {x1/VW:.2f}-{x2/VW:.2f}   y {y1/VH:.2f}-{y2/VH:.2f}")
print("PASS - nothing overlaps" if bad == 0 else f"FAIL - {bad} overlaps")
