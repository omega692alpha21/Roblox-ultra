#!/usr/bin/env python3
"""Export the sanctum's geometry the way render_map.py exports the school.

The estate under the school is built by a different module, from a different
project, dropped in at a scale and an origin. Nothing has ever checked it: the
school's flood-fill starts at the front doors and the sanctum is a hundred and
seventy studs underground behind a locked bookshelf, so every audit so far has
walked straight past it.

    LUAU_BIN=<luau> python3 tools/sanctum_export.py

Writes tools/_sanctum_export.json in the same shape as _map_export.json, so
every tool that reads one can read the other.
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, "..")
LUAU = os.environ.get("LUAU_BIN", "luau")

SHIM_PATH = os.path.join(HERE, "render_map.py")
shim_src = open(SHIM_PATH).read()
SHIM = shim_src.split("SHIM = r'''", 1)[1].split("'''", 1)[0]

src = open(os.path.join(REPO, "src/ServerScriptService/Services/SanctumMap.luau")).read()
src = src.replace("--!strict", "")
# InsertService cannot run offline; a mesh that fails to load is skipped in the
# real build too, so returning nil is the honest stand-in.
src = src.replace(
    'local InsertService = game:GetService("InsertService")',
    "local InsertService = { LoadAsset = function() error('offline') end }",
)
# Only the module's final return, anchored to the end of the file. A plain
# replace also hit "return SanctumMap.ToWorld(...)" inside the module and
# turned a return statement into an assignment.
assert src.rstrip().endswith("return SanctumMap"), "SanctumMap no longer ends with its return"
src = src.rstrip()[: -len("return SanctumMap")] + "__SanctumMap = SanctumMap\n"

EXPORT = r'''
local map = __SanctumMap.Build()
local out = {}
local function esc(s) return (s:gsub('"', '\\"')) end
local function walk(inst)
  for _, child in ipairs(inst:GetChildren()) do
    if child.ClassName == "Part" or child.ClassName == "SpawnLocation" then
      local cf = child.CFrame or CFrame.new(0, 0, 0)
      local size = child.Size or Vector3.new(4, 1.2, 2)
      table.insert(out, string.format(
        '{"n":"%s","s":[%.3f,%.3f,%.3f],"p":[%.3f,%.3f,%.3f],"r":[%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f],"cc":%s,"t":%.2f}',
        esc(child.Name), size.X, size.Y, size.Z, cf.p[1], cf.p[2], cf.p[3],
        cf.m[1][1], cf.m[1][2], cf.m[1][3], cf.m[2][1], cf.m[2][2], cf.m[2][3], cf.m[3][1], cf.m[3][2], cf.m[3][3],
        tostring(child.CanCollide ~= false), child.Transparency or 0))
    end
    walk(child)
  end
end
walk(workspace)
print("ENTRANCE[" .. string.format('[%.3f,%.3f,%.3f]',
  __SanctumMap.Entrance.X, __SanctumMap.Entrance.Y, __SanctumMap.Entrance.Z) .. "]")

-- The pads. You do not walk from one chamber to the next -- the estate has no
-- stairs inside the pyramid -- so a reachability check that only floods floors
-- would call the whole interior sealed no matter how it is wired. Dump each
-- link as (from, to) and let the check step through them.
local links = {}
local function link(fromCF, to, label)
  table.insert(links, string.format(
    '{"l":"%s","from":[%.3f,%.3f,%.3f],"to":[%.3f,%.3f,%.3f]}',
    esc(label), fromCF.p[1], fromCF.p[2], fromCF.p[3], to.X, to.Y, to.Z))
end
local floors = { map.hallPoint }
for _, gate in ipairs(map.gates) do
  link(gate.door.CFrame, gate.landing, "up " .. gate.tier)
  table.insert(floors, gate.landing)
end
for i, pad in ipairs(map.descents) do
  if floors[i] then link(pad.CFrame, floors[i], "down " .. i) end
end
print("LINKS[" .. table.concat(links, ",") .. "]")
print("[" .. table.concat(out, ",") .. "]")
'''

program = SHIM + "warn = warn or function(...) end\nlocal __SanctumMap\n" + src + EXPORT
path = os.path.join(HERE, "_sanctum_export.luau")
open(path, "w").write(program)
result = subprocess.run([LUAU, path], capture_output=True, text=True, timeout=180)
if result.returncode != 0:
    print("LUAU ERROR:\n" + result.stderr[:4000] + "\n" + result.stdout[:2000])
    sys.exit(1)
line = next(l for l in reversed(result.stdout.splitlines()) if l.startswith("["))
parts = json.loads(line)
json.dump(parts, open(os.path.join(HERE, "_sanctum_export.json"), "w"))
ent = next((l for l in result.stdout.splitlines() if l.startswith("ENTRANCE[")), None)
if ent:
    # the line is ENTRANCE[[x,y,z]]; the inner list is the point
    point = json.loads(ent[len("ENTRANCE"):])[0]
    json.dump(point, open(os.path.join(HERE, "_sanctum_entrance.json"), "w"))
    print(f"stair arrives at {point}")
links_line = next((l for l in result.stdout.splitlines() if l.startswith("LINKS[")), "LINKS[]")
links = json.loads(links_line[len("LINKS"):])
json.dump(links, open(os.path.join(HERE, "_sanctum_links.json"), "w"))
print(f"wrote {len(parts)} sanctum parts and {len(links)} pad links")
