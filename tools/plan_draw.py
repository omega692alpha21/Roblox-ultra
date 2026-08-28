#!/usr/bin/env python3
"""Draw CampusPlan as a site plan and a set of floor plans, so the drawing can
be looked at instead of only being checked.

A checker says the drawing is legal. It cannot say the drawing is any good --
whether the school reads as a school, whether the front door is where a front
door belongs. That is a judgement, and judgement needs a picture.

    python3 tools/plan_export.py && python3 tools/plan_draw.py
"""
import json, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PLAN = json.load(open(os.path.join(HERE, "_campus_plan.json")))

INK = (28, 32, 40)
PAPER = (247, 244, 236)
STONE = (196, 188, 172)
CORRIDOR = (226, 220, 206)
ROOM = (238, 233, 221)
GRASS = (206, 219, 198)
RESERVE = (232, 238, 224)
DOOR = (198, 84, 48)
STAIR = (60, 110, 160)
GRID = (216, 210, 198)


def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                pass
    return ImageFont.load_default()


class Sheet:
    def __init__(self, rect, px, margin=70, title=""):
        self.r = rect
        w, h = rect[2] - rect[0], rect[3] - rect[1]
        self.k = px / max(w, h)
        self.W, self.H = int(w * self.k) + margin * 2, int(h * self.k) + margin * 2
        self.m = margin
        self.img = Image.new("RGB", (self.W, self.H), PAPER)
        self.d = ImageDraw.Draw(self.img)
        if title:
            self.d.text((margin, 22), title, fill=INK, font=font(26))

    def xy(self, x, z):
        # +z is north, and north points UP the sheet
        return (self.m + (x - self.r[0]) * self.k,
                self.m + (self.r[3] - z) * self.k)

    def box(self, rect, fill=None, outline=INK, width=2):
        a, b = self.xy(rect[0], rect[3]), self.xy(rect[2], rect[1])
        self.d.rectangle([a, b], fill=fill, outline=outline, width=width)

    def label(self, rect, text, size=13, fill=INK):
        cx, cz = (rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2
        px, py = self.xy(cx, cz)
        f = font(size)
        w = self.d.textlength(text, font=f)
        avail = (rect[2] - rect[0]) * self.k - 6
        if w > avail and " " in text:
            a, b = text.rsplit(" ", 1)
            self.label_lines(px, py, [a, b], f)
            return
        self.d.text((px - w / 2, py - size / 2), text, fill=fill, font=f)

    def label_lines(self, px, py, lines, f):
        for i, line in enumerate(lines):
            w = self.d.textlength(line, font=f)
            self.d.text((px - w / 2, py - len(lines) * 7 + i * 15), line, fill=INK, font=f)


def site_plan(out):
    sh = Sheet(PLAN["plot"], 1500, title="CRUMBWORTH  —  SITE PLAN")
    sh.box(PLAN["plot"], fill=RESERVE, outline=INK, width=4)
    for r in PLAN["reserves"]:
        sh.box(r["rect"], fill=RESERVE, outline=GRID, width=2)
        sh.label(r["rect"], r["name"].replace(" Reserve", " reserve"), 15, (120, 132, 112))
    sh.box(PLAN["core"], fill=GRASS, outline=INK, width=3)
    sh.box(PLAN["approach"], fill=(214, 226, 206), outline=None, width=0)
    for e in PLAN["site"]:
        fill = STONE if e["kind"] == "building" else (200, 214, 192)
        sh.box(e["rect"], fill=fill, outline=INK, width=3 if e["kind"] == "building" else 2)
        sh.label(e["rect"], e["name"], 16)
    # the axis from the gate to the front doors
    a, b = sh.xy(0, 560), sh.xy(0, 124)
    sh.d.line([a, b], fill=(150, 110, 90), width=2)
    n = sh.xy(PLAN["plot"][0] + 70, PLAN["plot"][3] - 70)
    sh.d.text((n[0] - 6, n[1] - 10), "N", fill=INK, font=font(30))
    sh.d.line([(n[0], n[1] + 22), (n[0], n[1] + 62)], fill=INK, width=3)
    sh.img.save(out)
    return out


def floor_plans(building, out):
    b = building
    sheets = []
    for s in b["storeys"]:
        if not s["cells"]:
            continue
        sh = Sheet(b["rect"], 900, title=f"{b['name'].upper()}  —  {s['name'].upper()}  (y {s['y']:.0f})")
        sh.box(b["rect"], fill=STONE, outline=INK, width=4)
        for c in s["cells"]:
            sh.box(c["rect"], fill=CORRIDOR if c["kind"] == "corridor" else ROOM,
                   outline=(150, 145, 135), width=1)
        for c in s["cells"]:
            if c["kind"] == "room":
                sh.label(c["rect"], c["name"], 14)
        # doors, drawn as the gap they actually are
        for d in s["doors"]:
            if d.get("orphan"):
                continue
            half = PLAN["const"]["doorWidth"] / 2
            if d["axis"] == "z":
                a, e = sh.xy(d["x"] - half, d["z"]), sh.xy(d["x"] + half, d["z"])
            else:
                a, e = sh.xy(d["x"], d["z"] - half), sh.xy(d["x"], d["z"] + half)
            sh.d.line([a, e], fill=DOOR, width=5)
        for e in b.get("entrances") or []:
            if s["index"] != 1:
                continue
            px, py = sh.xy(e["at"]["x"], e["at"]["z"])
            sh.d.ellipse([px - 7, py - 7, px + 7, py + 7], fill=DOOR, outline=INK, width=2)
        for st in b.get("stairs") or []:
            for f in st["flights"]:
                # a stair belongs on the plan of the floor it LEAVES, all of
                # its flights, not just the one that starts at this exact y
                lo, hi = s["y"] - 1e-6, s["y"] + s["height"] + 1e-6
                if not (lo <= f["from"][1] <= hi or lo <= f["to"][1] <= hi):
                    continue
                a, e = sh.xy(f["from"][0], f["from"][2]), sh.xy(f["to"][0], f["to"][2])
                sh.d.line([a, e], fill=STAIR, width=7)
                sh.d.ellipse([e[0] - 5, e[1] - 5, e[0] + 5, e[1] + 5], fill=STAIR)
            for pad in st.get("landings") or []:
                if not (s["y"] - 1e-6 <= pad["y"] <= s["y"] + s["height"] + 1e-6):
                    continue
                sh.box(pad["rect"], fill=None, outline=STAIR, width=2)
        path = out.replace(".png", f"_{s['name'].lower()}.png")
        sh.img.save(path)
        sheets.append(path)
    return sheets


def main():
    made = [site_plan(os.path.join(HERE, "plan_site.png"))]
    for b in PLAN["buildings"]:
        slug = b["name"].lower().replace(" ", "").replace("'", "")
        made += floor_plans(b, os.path.join(HERE, f"plan_{slug}.png"))
    for m in made:
        print("  " + os.path.basename(m))
    print(f"drew {len(made)} sheets")


if __name__ == "__main__":
    main()
