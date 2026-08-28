#!/usr/bin/env python3
"""Run CampusPlan.luau headless and dump the derived drawing to JSON.

CampusPlan is authored in Luau because MapService has to read it at build time,
but the checks are in Python. Rather than keep two copies of the campus and
watch them drift, the plan is exported: the same file the game builds from is
the file the checker measures. It uses no Roblox datatypes, so unlike
render_map.py it needs no shim -- it just runs.

    python3 tools/plan_export.py           # -> tools/_campus_plan.json
"""
import json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SP = os.environ.get(
    "RBX_SCRATCH",
    "/tmp/claude-0/-home-user-Roblox-ultra/c9243cd0-6f22-5b01-98dd-c5d04d82a899/scratchpad",
)
LUAU = os.environ.get("LUAU_BIN") or shutil.which("luau") or os.path.join(SP, "luau")
PLAN = os.path.join(REPO, "src/ReplicatedStorage/Shared/CampusPlan.luau")

DUMP = r'''
-- minimal JSON writer: the plan is numbers, strings, booleans and tables
local function enc(v)
  local t = type(v)
  if t == "number" then
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%.4f", v)
  elseif t == "string" then
    return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
  elseif t == "boolean" then
    return tostring(v)
  elseif t == "nil" then
    return "null"
  elseif t == "table" then
    local n = 0
    for _ in pairs(v) do n += 1 end
    if #v == n then
      local parts = {}
      for _, item in ipairs(v) do table.insert(parts, enc(item)) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do table.insert(keys, tostring(k)) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      local raw = v[k]
      if raw == nil then raw = v[tonumber(k)] end
      table.insert(parts, '"' .. k .. '":' .. enc(raw))
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

local out = {
  plot = __Plan.PLOT,
  core = __Plan.CORE,
  reserves = __Plan.RESERVES,
  reserveRatio = __Plan.RESERVE_RATIO,
  approach = __Plan.APPROACH,
  site = __Plan.SITE,
  const = {
    exteriorWall = __Plan.EXTERIOR_WALL,
    partition = __Plan.PARTITION,
    doorWidth = __Plan.DOOR_WIDTH,
    doorHeight = __Plan.DOOR_HEIGHT,
    corridorClear = __Plan.CORRIDOR_CLEAR,
    headroom = __Plan.HEADROOM,
    stairRise = __Plan.STAIR_RISE,
    stairTread = __Plan.STAIR_TREAD,
    landing = __Plan.LANDING,
  },
  buildings = {},
}

for _, b in ipairs(__Plan.BUILDINGS) do
  local storeys = {}
  for i, s in ipairs(b.storeys) do
    table.insert(storeys, {
      index = i,
      name = s.name,
      y = s.y,
      height = s.height,
      cells = __Plan.cells(b, i),
      doors = __Plan.doors(b, i),
      walls = __Plan.walls(b, i),
    })
  end
  table.insert(out.buildings, {
    name = b.name,
    rect = b.rect,
    facing = b.facing,
    grid = b.grid,
    storeys = storeys,
    stairs = b.stairs,
    tower = b.tower,
    entrances = b.entrances,
    doubleHeight = b.doubleHeight,
  })
end

print("PLAN" .. enc(out))
'''


def main():
    src = open(PLAN).read().replace("--!strict", "").replace("return Plan", "__Plan = Plan")
    program = "local __Plan\n" + src + DUMP
    path = os.path.join(HERE, "_campus_plan.luau")
    open(path, "w").write(program)
    r = subprocess.run([LUAU, path], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        print("LUAU ERROR:\n" + r.stderr[:4000] + r.stdout[:2000])
        sys.exit(1)
    line = next(l for l in reversed(r.stdout.splitlines()) if l.startswith("PLAN"))
    data = json.loads(line[4:])
    out = os.path.join(HERE, "_campus_plan.json")
    json.dump(data, open(out, "w"), indent=1)
    rooms = sum(
        sum(1 for c in s["cells"] if c["kind"] == "room")
        for b in data["buildings"] for s in b["storeys"]
    )
    walls = sum(len(s["walls"]) for b in data["buildings"] for s in b["storeys"])
    print(f"exported {len(data['site'])} site entries, "
          f"{len(data['buildings'])} drawn buildings, {rooms} rooms, {walls} walls")


if __name__ == "__main__":
    main()
