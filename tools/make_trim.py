"""Extruded moulding profiles: the thing that separates built architecture
from stacked boxes.

Every wall, roof edge and doorway in the school is a rectangular prism with a
hard 90 degree corner. Nothing in the painterly references has a raw edge —
real environment art runs a moulding along every junction, because a profile
catches a highlight and describes the form in a way a flat plane never can.

Each profile is a 2D cross-section extruded one stud along X. That matters:
a MeshPart scales on all three axes, so a bevel baked into a cube stretches
into a wedge the moment the wall is 40 studs long. A moulding is only ever
scaled along its run, so its profile stays exactly as drawn at any length.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_glb import build_glb


def ear_clip(poly):
    """Triangulate a simple polygon given as [(y, z), ...], counter-clockwise."""
    idx = list(range(len(poly)))

    def area2(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    # orient counter-clockwise
    total = sum(area2(poly[0], poly[i], poly[i + 1]) for i in range(1, len(poly) - 1))
    if total < 0:
        idx.reverse()

    def inside(p, a, b, c):
        d1 = area2(a, b, p)
        d2 = area2(b, c, p)
        d3 = area2(c, a, p)
        neg = d1 < -1e-9 or d2 < -1e-9 or d3 < -1e-9
        pos = d1 > 1e-9 or d2 > 1e-9 or d3 > 1e-9
        return not (neg and pos)

    tris = []
    guard = 0
    while len(idx) > 3 and guard < 4000:
        guard += 1
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = poly[i0], poly[i1], poly[i2]
            if area2(a, b, c) <= 1e-9:
                continue  # reflex or degenerate
            if any(inside(poly[j], a, b, c) for j in idx if j not in (i0, i1, i2)):
                continue  # another vertex inside: not an ear
            tris.append((i0, i1, i2))
            idx.pop(k)
            break
        else:
            break
    if len(idx) == 3:
        tris.append((idx[0], idx[1], idx[2]))
    return tris


def extrude(profile, length=1.0):
    """Prism from a (y, z) cross-section, running along X from 0 to length."""
    n = len(profile)
    verts = [(0.0, y, z) for (y, z) in profile] + [(length, y, z) for (y, z) in profile]
    faces = []
    for i in range(n):
        j = (i + 1) % n
        # side quad, wound so the outward normal points away from the solid
        faces.append((i, j, j + n))
        faces.append((i, j + n, i + n))
    caps = ear_clip(profile)
    for (a, b, c) in caps:
        faces.append((a, c, b))                     # near cap, facing -X
        faces.append((a + n, b + n, c + n))         # far cap, facing +X
    return verts, faces


# (y across the moulding, z out from the wall). z is negative into the room.
PROFILES = {
    # skirting board where wall meets floor
    "skirting": ([(0, 0), (0, -0.34), (1.0, -0.34), (1.14, -0.2),
                  (1.3, -0.26), (1.44, -0.1), (1.6, -0.1), (1.6, 0)],
                 (0.86, 0.85, 0.81)),
    # chair rail at wainscot height
    "chairrail": ([(0, 0), (0, -0.14), (0.16, -0.3), (0.44, -0.3),
                   (0.6, -0.15), (0.7, -0.09), (0.7, 0)],
                  (0.86, 0.85, 0.81)),
    # crown moulding where wall meets ceiling
    "cornice": ([(0, 0), (0, -0.24), (0.34, -0.5), (0.54, -1.02), (0.8, -1.18),
                 (1.08, -1.12), (1.32, -0.68), (1.5, -0.28), (1.5, 0)],
                (0.9, 0.89, 0.85)),
    # architrave around a door or window opening
    "architrave": ([(0, 0), (0, -0.3), (0.24, -0.3), (0.3, -0.17),
                    (0.54, -0.21), (0.62, -0.09), (0.9, -0.09), (0.9, 0)],
                   (0.88, 0.86, 0.8)),
    # window sill with a drip edge underneath
    "sill": ([(0, 0), (0, -0.92), (0.16, -0.92), (0.16, -0.78), (0.24, -0.74),
              (0.5, -0.6), (0.5, 0)],
             (0.84, 0.82, 0.78)),
    # roof fascia and soffit at the eaves
    "fascia": ([(0, 0), (0, -0.62), (0.24, -0.62), (0.3, -0.46),
                (1.08, -0.46), (1.16, -0.62), (1.4, -0.62), (1.4, 0)],
               (0.78, 0.74, 0.7)),
}

out = os.path.dirname(os.path.abspath(__file__))
for name, (profile, colour) in PROFILES.items():
    verts, faces = extrude(profile, 1.0)
    path = os.path.join(out, f"trim_{name}.glb")
    build_glb([(verts, faces, colour)], path)
    print(f"  trim_{name}.glb  {len(profile)} point profile, {len(faces)} tris")
print(f"wrote {len(PROFILES)} moulding profiles")
