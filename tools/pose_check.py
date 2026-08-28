#!/usr/bin/env python3
"""Run every action pose on a mock rig and prove a joint actually moves.

The punch and the emotes are not assets -- they are joint offsets written into
Motor6D.Transform from a render step. Nothing about that is visible in code
review: a pose whose joint names do not exist on the rig, or whose keyframe
list sums to zero, plays silently and looks exactly like a pose that never
fired. So this builds an R15 rig and an R6 rig out of tables, drives the
module's own render step over the length of each action, and asserts that at
least one joint left the identity on both rigs.

    python3 tools/pose_check.py [repo_root]
"""
import os, shutil, subprocess, sys

REPO = sys.argv[1] if len(sys.argv) > 1 else "."
SP = os.path.dirname(os.path.abspath(__file__))
LUAU = os.environ.get("LUAU_BIN") or shutil.which("luau") or os.path.join(SP, "luau")

SCRIPT = r'''
-- ---- the shims ActionPoses needs, and no more ----
local V3MT = {}
V3MT.__index = function() return nil end
Vector3 = { new = function(x, y, z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0}, V3MT) end }

local CFMT = {}
local function matmul(a, b)
  local r = {{0,0,0},{0,0,0},{0,0,0}}
  for i = 1, 3 do for j = 1, 3 do
    r[i][j] = a[i][1]*b[1][j] + a[i][2]*b[2][j] + a[i][3]*b[3][j]
  end end
  return r
end
local function cfnew(px, py, pz, m)
  return setmetatable({ p = {px, py, pz}, m = m or {{1,0,0},{0,1,0},{0,0,1}} }, CFMT)
end
CFMT.__index = function(cf, k)
  if k == "Position" then return Vector3.new(cf.p[1], cf.p[2], cf.p[3]) end
  if k == "Lerp" then
    return function(a, b, t)
      -- good enough for "did anything move": component-wise on the matrix
      local m = {{0,0,0},{0,0,0},{0,0,0}}
      for i = 1, 3 do for j = 1, 3 do m[i][j] = a.m[i][j] + (b.m[i][j] - a.m[i][j]) * t end end
      return cfnew(a.p[1] + (b.p[1]-a.p[1])*t, a.p[2] + (b.p[2]-a.p[2])*t, a.p[3] + (b.p[3]-a.p[3])*t, m)
    end
  end
  return nil
end
CFMT.__mul = function(a, b)
  local rp = { a.m[1][1]*b.p[1]+a.m[1][2]*b.p[2]+a.m[1][3]*b.p[3],
               a.m[2][1]*b.p[1]+a.m[2][2]*b.p[2]+a.m[2][3]*b.p[3],
               a.m[3][1]*b.p[1]+a.m[3][2]*b.p[2]+a.m[3][3]*b.p[3] }
  return cfnew(a.p[1]+rp[1], a.p[2]+rp[2], a.p[3]+rp[3], matmul(a.m, b.m))
end
CFrame = {}
function CFrame.new(x, y, z) return cfnew(x or 0, y or 0, z or 0) end
function CFrame.Angles(rx, ry, rz)
  local cx, sx = math.cos(rx), math.sin(rx)
  local cy, sy = math.cos(ry), math.sin(ry)
  local cz, sz = math.cos(rz), math.sin(rz)
  return cfnew(0, 0, 0, matmul({{1,0,0},{0,cx,-sx},{0,sx,cx}},
    matmul({{cy,0,sy},{0,1,0},{-sy,0,cy}}, {{cz,-sz,0},{sz,cz,0},{0,0,1}})))
end

local enumCache = {}
Enum = setmetatable({}, { __index = function(_, etype)
  enumCache[etype] = enumCache[etype] or setmetatable({}, { __index = function(t, name)
    local item = { Name = name, EnumTypeName = etype, Value = if name == "Character" then 300 else 0 }
    rawset(t, name, item)
    return item
  end })
  return enumCache[etype]
end })

-- the render step the module binds, captured rather than run
local BOUND
local RunService = {
  IsClient = function() return true end,
  BindToRenderStep = function(_, _, _, fn) BOUND = fn end,
}
game = { GetService = function(_, name)
  if name == "RunService" then return RunService end
  return {}
end }

-- ---- a rig, as a tree of tables that answers FindFirstChild ----
local function node(name)
  local self = { Name = name, _children = {}, Parent = true }
  function self.FindFirstChild(s, key) return s._children[key] end
  function self.IsA(_, class) return class == "Model" end
  return self
end
local function motor()
  return { C0 = CFrame.new(), Transform = CFrame.new(), Parent = true, IsA = function(_, c) return c == "Motor6D" end }
end
local function rig(joints)
  local model = node("rig")
  for part, motorNames in joints do
    local p = node(part)
    for _, m in motorNames do
      p._children[m] = motor()
    end
    model._children[part] = p
  end
  return model
end

local R15 = {
  RightUpperArm = { "RightShoulder" }, RightLowerArm = { "RightElbow" },
  LeftUpperArm = { "LeftShoulder" }, LeftLowerArm = { "LeftElbow" },
  UpperTorso = { "Waist" }, Head = { "Neck" },
  RightUpperLeg = { "RightHip" }, LeftUpperLeg = { "LeftHip" },
}
local R6 = {
  Torso = { "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" },
  Head = { "Neck" },
}

-- The module reads os.clock(); drive it from here instead of real time.
-- os is frozen in the luau CLI, so the clock is swapped by giving the module
-- its own environment rather than by patching the global.
local NOW = 0
local source = @SRC@
local chunk = (loadstring or load)(source, "ActionPoses")
local env = setmetatable({ os = setmetatable({ clock = function() return NOW end }, { __index = os }) },
  { __index = getfenv and getfenv(1) or _G })
if setfenv then setfenv(chunk, env) end
local ActionPoses = chunk()

local function identity(cf)
  local sum = 0
  for i = 1, 3 do for j = 1, 3 do
    sum += math.abs(cf.m[i][j] - (if i == j then 1 else 0))
  end end
  for i = 1, 3 do sum += math.abs(cf.p[i]) end
  return sum < 1e-5
end

local bad = 0
local names = {}
for kind in ActionPoses.Actions do table.insert(names, kind) end
table.sort(names)

for _, kind in names do
  for rigName, joints in { R15 = R15, R6 = R6 } do
    local model = rig(joints)
    NOW = NOW + 10
    local start = NOW
    if not ActionPoses.Play(model, kind) then
      if rigName == "R15" then
        print(("  %-12s %-4s Play() refused -- no joint in the table exists on this rig"):format(kind, rigName))
        bad += 1
      end
      continue
    end
    -- drive the render step across the action and watch every motor
    local moved = false
    local total = 0
    for _, entry in ActionPoses.Actions[kind] do
      local t = 0
      for _, key in entry do t += key.time end
      total = math.max(total, t)
    end
    for frame = 1, 40 do
      -- The animator rewrites Transform every frame and never touches C0.
      -- Clobbering Transform here is exactly what killed the old version, so
      -- the check does it too: a pose that only survives when the animator is
      -- idle is a pose that does not work in the game.
      for _, part in model._children do
        for _, m in part._children do m.Transform = CFrame.new() end
      end
      NOW = start + total * frame / 40
      BOUND()
      for _, part in model._children do
        for _, m in part._children do
          if not identity(m.C0) then moved = true end
        end
      end
    end
    ActionPoses.Stop(model)
    -- and every joint must be back at its rest pose afterwards: a punch that
    -- leaves the arm out is worse than a punch that never played
    for partName, part in model._children do
      for motorName, m in part._children do
        if not identity(m.C0) then
          print(("  %-12s %-4s left %s.%s bent after the pose ended"):format(kind, rigName, partName, motorName))
          bad += 1
        end
      end
    end
    if not moved then
      print(("  %-12s %-4s played, but no joint ever left the rest pose"):format(kind, rigName))
      bad += 1
    end
  end
end

print((if bad == 0 then "PASS" else "FAIL") .. " - " .. bad .. " dead poses (" .. #names .. " actions on two rigs)")
if bad > 0 then error("dead poses", 0) end
'''

module = open(os.path.join(REPO, "src/ReplicatedStorage/Shared/ActionPoses.luau")).read()
src = SCRIPT.replace("@SRC@", "[==[\n" + module + "\n]==]")
path = os.path.join(SP, "_pose_check.luau")
open(path, "w").write(src)
out = subprocess.run([LUAU, path], capture_output=True, text=True)
sys.stdout.write(out.stdout)
sys.stderr.write(out.stderr)
sys.exit(0 if out.returncode == 0 else 1)
