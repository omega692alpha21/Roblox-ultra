#!/usr/bin/env python3
"""Execute MapService.Build() under luau CLI with datatype shims, dump every
Part to JSON, then software-render camera shots to PNG so the map can be seen
without Roblox. Usage: python3 render_map.py <repo_root> <out_dir>"""
import json, math, os, shutil, subprocess, sys

REPO = sys.argv[1] if len(sys.argv) > 1 else "/home/user/Roblox-ultra"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(__file__))
SP = os.path.dirname(os.path.abspath(__file__))
# the luau CLI is not checked in; point LUAU_BIN at it, or leave it on PATH
LUAU = os.environ.get("LUAU_BIN") or shutil.which("luau") or os.path.join(SP, "luau")

SHIM = r'''
-- ===== datatype + instance shims =====
local function v3mt()
  local mt = {}
  mt.__index = function(v, k)
    if k == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
    if k == "Unit" then local m = math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z); return setmetatable({X=v.X/m,Y=v.Y/m,Z=v.Z/m}, mt) end
    if k == "Dot" then return function(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end end
    if k == "Cross" then return function(a, b) return setmetatable({X=a.Y*b.Z-a.Z*b.Y, Y=a.Z*b.X-a.X*b.Z, Z=a.X*b.Y-a.Y*b.X}, mt) end end
    if k == "Lerp" then return function(a, b, t) return setmetatable({X=a.X+(b.X-a.X)*t, Y=a.Y+(b.Y-a.Y)*t, Z=a.Z+(b.Z-a.Z)*t}, mt) end end
    return nil
  end
  mt.__add = function(a, b) return setmetatable({X=a.X+b.X, Y=a.Y+b.Y, Z=a.Z+b.Z}, mt) end
  mt.__sub = function(a, b) return setmetatable({X=a.X-b.X, Y=a.Y-b.Y, Z=a.Z-b.Z}, mt) end
  mt.__mul = function(a, b)
    if type(a) == "number" then return setmetatable({X=a*b.X, Y=a*b.Y, Z=a*b.Z}, getmetatable(b)) end
    return setmetatable({X=a.X*b, Y=a.Y*b, Z=a.Z*b}, getmetatable(a))
  end
  mt.__div = function(a, b) return setmetatable({X=a.X/b, Y=a.Y/b, Z=a.Z/b}, mt) end
  mt.__unm = function(a) return setmetatable({X=-a.X, Y=-a.Y, Z=-a.Z}, mt) end
  return mt
end
local V3MT = v3mt()
Vector3 = {
  new = function(x, y, z) return setmetatable({X=x or 0, Y=y or 0, Z=z or 0}, V3MT) end,
}
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

local v2mt = {}
v2mt.__index = function(v, k)
  if k == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y) end
  if k == "Unit" then local m = math.sqrt(v.X*v.X + v.Y*v.Y); return setmetatable({X=v.X/m, Y=v.Y/m}, v2mt) end
  return nil
end
v2mt.__add = function(a, b) return setmetatable({X=a.X+b.X, Y=a.Y+b.Y}, v2mt) end
v2mt.__sub = function(a, b) return setmetatable({X=a.X-b.X, Y=a.Y-b.Y}, v2mt) end
v2mt.__mul = function(a, b)
  if type(a) == "number" then return setmetatable({X=a*b.X, Y=a*b.Y}, v2mt) end
  return setmetatable({X=a.X*b, Y=a.Y*b}, v2mt)
end
Vector2 = { new = function(x, y) return setmetatable({X=x or 0, Y=y or 0}, v2mt) end }

Color3 = {
  new = function(r, g, b) return {R=r or 0, G=g or 0, B=b or 0} end,
  fromRGB = function(r, g, b) return {R=(r or 0)/255, G=(g or 0)/255, B=(b or 0)/255} end,
  fromHSV = function(h, s, v) return {R=v, G=v, B=v} end,
}

UDim = { new = function(s, o) return {Scale=s, Offset=o} end }
UDim2 = {
  new = function(a, b, c, d) return {X={Scale=a,Offset=b}, Y={Scale=c,Offset=d}} end,
  fromScale = function(a, b) return UDim2.new(a, 0, b, 0) end,
  fromOffset = function(a, b) return UDim2.new(0, a, 0, b) end,
}

-- CFrame: position + 3x3 rotation (rows r[1..3] are basis ROWS: world = p + R^T? we store columns)
local CFMT = {}
local function cfnew(px, py, pz, m)
  return setmetatable({ p = {px, py, pz}, m = m or {{1,0,0},{0,1,0},{0,0,1}} }, CFMT)
end
local function matmul(a, b)
  local r = {{0,0,0},{0,0,0},{0,0,0}}
  for i = 1, 3 do for j = 1, 3 do
    r[i][j] = a[i][1]*b[1][j] + a[i][2]*b[2][j] + a[i][3]*b[3][j]
  end end
  return r
end
local function rotvec(m, v)
  return { m[1][1]*v[1] + m[1][2]*v[2] + m[1][3]*v[3],
           m[2][1]*v[1] + m[2][2]*v[2] + m[2][3]*v[3],
           m[3][1]*v[1] + m[3][2]*v[2] + m[3][3]*v[3] }
end
CFMT.__index = function(cf, k)
  if k == "Position" then return Vector3.new(cf.p[1], cf.p[2], cf.p[3]) end
  if k == "LookVector" then return Vector3.new(-cf.m[1][3], -cf.m[2][3], -cf.m[3][3]) end
  if k == "RightVector" then return Vector3.new(cf.m[1][1], cf.m[2][1], cf.m[3][1]) end
  if k == "UpVector" then return Vector3.new(cf.m[1][2], cf.m[2][2], cf.m[3][2]) end
  return nil
end
CFMT.__mul = function(a, b)
  local rp = rotvec(a.m, b.p)
  return cfnew(a.p[1] + rp[1], a.p[2] + rp[2], a.p[3] + rp[3], matmul(a.m, b.m))
end
CFrame = {}
function CFrame.new(x, y, z)
  if x ~= nil and y == nil and type(x) == "table" then return cfnew(x.X, x.Y, x.Z) end
  return cfnew(x or 0, y or 0, z or 0)
end
function CFrame.Angles(rx, ry, rz)
  local cx, sx = math.cos(rx), math.sin(rx)
  local cy, sy = math.cos(ry), math.sin(ry)
  local cz, sz = math.cos(rz), math.sin(rz)
  local Rx = {{1,0,0},{0,cx,-sx},{0,sx,cx}}
  local Ry = {{cy,0,sy},{0,1,0},{-sy,0,cy}}
  local Rz = {{cz,-sz,0},{sz,cz,0},{0,0,1}}
  return cfnew(0, 0, 0, matmul(Rx, matmul(Ry, Rz)))
end
function CFrame.lookAt(pos, target, up)
  up = up or Vector3.new(0, 1, 0)
  local f = (target - pos).Unit
  local z = { -f.X, -f.Y, -f.Z }
  local upv = { up.X, up.Y, up.Z }
  local x = { upv[2]*z[3]-upv[3]*z[2], upv[3]*z[1]-upv[1]*z[3], upv[1]*z[2]-upv[2]*z[1] }
  local xm = math.sqrt(x[1]^2 + x[2]^2 + x[3]^2)
  if xm < 1e-6 then x = {1, 0, 0} xm = 1 end
  x = { x[1]/xm, x[2]/xm, x[3]/xm }
  local y = { z[2]*x[3]-z[3]*x[2], z[3]*x[1]-z[1]*x[3], z[1]*x[2]-z[2]*x[1] }
  return cfnew(pos.X, pos.Y, pos.Z, {{x[1],y[1],z[1]},{x[2],y[2],z[2]},{x[3],y[3],z[3]}})
end

ColorSequence = { new = function(...) return { args = { ... } } end }
ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
NumberSequence = { new = function(...) return { args = { ... } } end }
NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }

-- Deterministic Random (LCG)
Random = {}
Random.__index = Random
function Random.new(seed)
  return setmetatable({ state = (seed or 42) % 2147483647 }, Random)
end
function Random.NextNumber(self, lo, hi)
  self.state = (self.state * 48271) % 2147483647
  local r = self.state / 2147483647
  if lo == nil then return r end
  return lo + r * (hi - lo)
end
function Random.NextInteger(self, lo, hi)
  return math.floor(self:NextNumber(lo, hi + 0.9999))
end

-- Enum autotable (cached so identity comparisons work)
local enumCache = {}
Enum = setmetatable({}, { __index = function(_, etype)
  enumCache[etype] = enumCache[etype] or setmetatable({}, { __index = function(t, name)
    local item = { Name = name, EnumTypeName = etype }
    rawset(t, name, item)
    return item
  end })
  return enumCache[etype]
end })

-- Instance shim
local InstMT = {}
InstMT.__index = function(self, k)
  if k == "AddTag" or k == "RemoveTag" then return function() end end
  if k == "GetTagged" then return function() return {} end end
  if k == "GetChildren" then return function(s) local out = {} for _, c in ipairs(s._children) do table.insert(out, c) end return out end end
  if k == "GetDescendants" then
    return function(s)
      local out = {}
      local function walk(node) for _, c in ipairs(node._children) do table.insert(out, c) walk(c) end end
      walk(s)
      return out
    end
  end
  if k == "FindFirstChild" then return function(s, name) for _, c in ipairs(s._children) do if c.Name == name then return c end end return nil end end
  if k == "Position" then
    local props = rawget(self, "_props")
    local cf = props and props.CFrame
    if cf then return Vector3.new(cf.p[1], cf.p[2], cf.p[3]) end
    return Vector3.new(0, 0, 0)
  end
  if k == "FindFirstChildWhichIsA" then
    return function(s, cls)
      for _, c in ipairs(s._children) do if c.ClassName == cls then return c end end
      return nil
    end
  end
  if k == "IsA" then
    return function(s, class)
      if class == "BasePart" then return s.ClassName == "Part" or s.ClassName == "SpawnLocation" end
      return s.ClassName == class
    end
  end
  if k == "Destroy" then
    return function(s)
      local parent = rawget(s, "_parent")
      if parent then
        for i, c in ipairs(parent._children) do if c == s then table.remove(parent._children, i) break end end
      end
      rawset(s, "_parent", nil)
    end
  end
  if k == "Parent" then return rawget(self, "_parent") end
  return rawget(self, "_props")[k]
end
InstMT.__newindex = function(self, k, v)
  if k == "Parent" then
    local old = rawget(self, "_parent")
    if old then for i, c in ipairs(old._children) do if c == self then table.remove(old._children, i) break end end end
    rawset(self, "_parent", v)
    if v then table.insert(v._children, self) end
    return
  end
  rawget(self, "_props")[k] = v
end
Instance = {
  new = function(class)
    local self = { ClassName = class, _children = {}, _props = { Name = class } }
    return setmetatable(self, InstMT)
  end,
}

workspace = Instance.new("Workspace")
workspace.Terrain = { FillBlock = function() end, FillBall = function() end }
-- workspace.Terrain assigned via props; give direct access:
game = { GetService = function(_, name) return Instance.new(name) end }
'''

def load_module(path, localname):
    src = open(path).read()
    src = src.replace("--!strict", "")
    return f"local {localname} = (function()\n{src}\nend)()\n"

map_src = open(os.path.join(REPO, "src/ServerScriptService/Services/MapService.luau")).read()
map_src = map_src.replace("--!strict", "")
map_src = map_src.replace('local ReplicatedStorage = game:GetService("ReplicatedStorage")', "")
map_src = map_src.replace("local Palette = require(ReplicatedStorage.Shared.Palette)", "")
map_src = map_src.replace("local GameConfig = require(ReplicatedStorage.Config.GameConfig)", "")
map_src = map_src.replace("local PropSizes = require(ReplicatedStorage.Config.PropSizes)", "local PropSizes = __PropSizes")
map_src = map_src.replace("local Cliques = require(ReplicatedStorage.Config.Cliques)", "local Cliques = __Cliques")
map_src = map_src.replace(
    "local StudentGen = require(script.Parent.StudentGen) :: any",
    "local StudentGen = { Create = function() return nil end, Stand = function() end } :: any",
)
map_src = map_src.replace("return MapService", "__MapService = MapService")

EXPORT = r'''
local map = __MapService.Build()
local out = {}
local function esc(s) return (s:gsub('"', '\\"')) end
local function walk(inst)
  for _, child in ipairs(inst:GetChildren()) do
    if child.ClassName == "Part" or child.ClassName == "SpawnLocation" then
      local cf = child.CFrame or CFrame.new(0, 0, 0)
      local size = child.Size or Vector3.new(4, 1.2, 2)
      local color = child.Color or {R = 0.64, G = 0.64, B = 0.65}
      local material = child.Material and child.Material.Name or "Plastic"
      local shape = child.Shape and child.Shape.Name or "Block"
      table.insert(out, string.format(
        '{"n":"%s","s":[%.3f,%.3f,%.3f],"p":[%.3f,%.3f,%.3f],"r":[%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f],"c":[%d,%d,%d],"m":"%s","t":%.2f,"sh":"%s","cc":%s}',
        esc(child.Name), size.X, size.Y, size.Z, cf.p[1], cf.p[2], cf.p[3],
        cf.m[1][1], cf.m[1][2], cf.m[1][3], cf.m[2][1], cf.m[2][2], cf.m[2][3], cf.m[3][1], cf.m[3][2], cf.m[3][3],
        math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5),
        material, child.Transparency or 0, shape,
        tostring(child.CanCollide ~= false)))
    end
    walk(child)
  end
end
walk(map.folder)

-- Props are recorded, not built, so they never appear in the part walk. Dump
-- the requests too: the placement checker needs them to test furniture against
-- walls before any of it reaches a server.
local props = {}
for _, request in ipairs(map.props or {}) do
  local cf = request.cframe
  table.insert(props, string.format(
    '{"k":"%s","p":[%.3f,%.3f,%.3f],"r":[%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f],"sc":%.3f,"hang":%s}',
    esc(request.kind), cf.p[1], cf.p[2], cf.p[3],
    cf.m[1][1], cf.m[1][2], cf.m[1][3], cf.m[2][1], cf.m[2][2], cf.m[2][3], cf.m[3][1], cf.m[3][2], cf.m[3][3],
    request.scale or 1, tostring(request.hang == true)))
end
print("PROPS[" .. table.concat(props, ",") .. "]")
print("[" .. table.concat(out, ",") .. "]")
'''

program = (
    SHIM
    + load_module(os.path.join(REPO, "src/ReplicatedStorage/Shared/Palette.luau"), "Palette")
    + load_module(os.path.join(REPO, "src/ReplicatedStorage/Config/GameConfig.luau"), "GameConfig")
    + load_module(os.path.join(REPO, "src/ReplicatedStorage/Config/Cliques.luau"), "__Cliques")
    + load_module(os.path.join(REPO, "src/ReplicatedStorage/Config/PropSizes.luau"), "__PropSizes")
    + "local __MapService\n"
    + map_src
    + EXPORT
)
lua_path = os.path.join(OUT, "_map_export.luau")
open(lua_path, "w").write(program)
result = subprocess.run([LUAU, lua_path], capture_output=True, text=True, timeout=120)
if result.returncode != 0:
    print("LUAU ERROR:\n" + result.stderr[:4000] + "\n" + result.stdout[:2000])
    sys.exit(1)
# MapService prints diagnostics before the dump, so take the JSON line rather
# than the whole of stdout
_json_line = next(l for l in reversed(result.stdout.splitlines()) if l.startswith("["))
parts = json.loads(_json_line)
with open(os.path.join(OUT, "_map_export.json"), "w") as fh:
    json.dump(parts, fh)
print(f"wrote {len(parts)} parts to _map_export.json")

_prop_line = next((l for l in reversed(result.stdout.splitlines()) if l.startswith("PROPS[")), "PROPS[]")
props = json.loads(_prop_line[len("PROPS"):])
with open(os.path.join(OUT, "_map_props.json"), "w") as fh:
    json.dump(props, fh)
print(f"exported {len(parts)} parts and {len(props)} prop placements")

# ===== renderer =====
from PIL import Image, ImageDraw

LIGHT = (0.45, 0.8, 0.35)
lm = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / lm for c in LIGHT)

def render(cam, target, path, width=1280, height=720, fov=70, sky=((150, 195, 235), (208, 226, 240)), interior=False):
    img = Image.new("RGB", (width, height))
    d = ImageDraw.Draw(img)
    for y in range(height):
        t = y / height
        col = tuple(int(sky[0][i] + (sky[1][i] - sky[0][i]) * t) for i in range(3))
        d.line([(0, y), (width, y)], fill=col)

    fwd = [target[i] - cam[i] for i in range(3)]
    fm = math.sqrt(sum(c * c for c in fwd)); fwd = [c / fm for c in fwd]
    right = [-fwd[2], 0, fwd[0]]  # cross(fwd, worldUp) normalized
    rm = math.sqrt(sum(c * c for c in right)) or 1; right = [c / rm for c in right]
    up = [right[1] * fwd[2] - right[2] * fwd[1], right[2] * fwd[0] - right[0] * fwd[2], right[0] * fwd[1] - right[1] * fwd[0]]
    focal = (width / 2) / math.tan(math.radians(fov) / 2)

    def project(w):
        rel = [w[i] - cam[i] for i in range(3)]
        z = sum(rel[i] * fwd[i] for i in range(3))
        if z < 0.6:
            return None
        x = sum(rel[i] * right[i] for i in range(3))
        y = sum(rel[i] * up[i] for i in range(3))
        return (width / 2 + x * focal / z, height / 2 - y * focal / z, z)

    # ground plane (grass) — draw as a huge quad
    ground = [(-600, 0, -600), (600, 0, -600), (600, 0, 600), (-600, 0, 600)]
    gp = [project(g) for g in ground]
    if all(gp):
        d.polygon([(p[0], p[1]) for p in gp], fill=(104, 148, 88))

    faces = []
    AXES = [((1, 0, 0), (0, 1, 0), (0, 0, 1)), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), ((0, 0, 1), (1, 0, 0), (0, 1, 0))]
    for part in parts:
        sx, sy, sz = [c / 2 for c in part["s"]]
        px, py, pz = part["p"]
        r = part["r"]
        R = [[r[0], r[1], r[2]], [r[3], r[4], r[5]], [r[6], r[7], r[8]]]
        if part["t"] >= 0.95:
            continue
        # cull tiny far parts cheaply
        dist = math.sqrt((px - cam[0]) ** 2 + (py - cam[1]) ** 2 + (pz - cam[2]) ** 2)
        if dist > 900:
            continue
        def world(local):
            return (px + R[0][0]*local[0] + R[0][1]*local[1] + R[0][2]*local[2],
                    py + R[1][0]*local[0] + R[1][1]*local[1] + R[1][2]*local[2],
                    pz + R[2][0]*local[0] + R[2][1]*local[1] + R[2][2]*local[2])
        half = (sx, sy, sz)
        for axis in range(3):
            for sign in (-1, 1):
                normal_local = [0, 0, 0]; normal_local[axis] = sign
                nx = R[0][axis] * sign; ny = R[1][axis] * sign; nz = R[2][axis] * sign
                center_local = [0, 0, 0]; center_local[axis] = sign * half[axis]
                fcx, fcy, fcz = world(center_local)
                view = (cam[0] - fcx, cam[1] - fcy, cam[2] - fcz)
                if nx * view[0] + ny * view[1] + nz * view[2] <= 0:
                    continue
                u_axis, v_axis = [a for a in range(3) if a != axis]
                corners = []
                behind = False
                for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    local = [0, 0, 0]
                    local[axis] = sign * half[axis]
                    local[u_axis] = su * half[u_axis]
                    local[v_axis] = sv * half[v_axis]
                    pr = project(world(local))
                    if pr is None:
                        behind = True
                        break
                    corners.append(pr)
                if behind or len(corners) < 4:
                    continue
                fd = math.sqrt((fcx - cam[0]) ** 2 + (fcy - cam[1]) ** 2 + (fcz - cam[2]) ** 2)
                shade = 0.52 + 0.48 * max(0.0, nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2])
                c = part["c"]
                if part["m"] == "Neon":
                    shade = 1.25
                col = tuple(min(255, int(ch * shade)) for ch in c)
                faces.append((fd, [(p[0], p[1]) for p in corners], col))
    faces.sort(key=lambda f: -f[0])
    for _, poly, col in faces:
        d.polygon(poly, fill=col)
    img.save(path)
    print("wrote", path)

# eye height 6 for anything meant to be seen on foot: a shot from 50 studs up
# flatters massing and hides everything a player actually walks past
shots = [
    ("entrance",   (0, 55, 300),     (0, 26, 110)),
    ("approach",   (0, 6, 190),      (0, 12, 120)),
    ("facade34",   (-190, 70, 300),  (0, 24, 60)),
    ("lobby",      (0, 7, 116),      (0, 6, 60)),
    ("corridor",   (-180, 6, 70),    (0, 6, 70)),
    ("atrium",     (0, 7, 56),       (0, 8, -30)),
    ("courtyard",  (-116, 8, 40),    (-116, 4, -40)),
    ("greenhouse", (-116, 6, 20),    (-116, 6, -40)),
    ("eastlab",    (116, 6, 20),     (116, 6, -40)),
    ("wingcorr",   (-178, 6, -20),   (-178, 6, -60)),
    ("plotroom",   (-190, 7, 78),    (-190, 5, 110)),
    ("gym",        (0, 9, -70),      (0, 8, -130)),
    ("room101",    (-74, 6, -70),    (-74, 6, -120)),
    ("library",    (0, 16, -152),    (0, 14, -232)),
    ("libinside",  (0, 7, -196),     (0, 9, -262)),
    ("tennis",     (340, 20, 90),    (340, 6, -20)),
    ("pool",       (-340, 14, 60),   (-340, 2, -20)),
    ("dorms",      (-176, 8, -160),  (-176, 8, -212)),
    ("northquad",  (0, 40, -120),    (0, 10, -220)),
    ("overview",   (-330, 250, 360), (0, 0, 0)),
]
for name, cam, target in shots:
    render(cam, target, os.path.join(OUT, f"shot_{name}.png"))
print("done")
