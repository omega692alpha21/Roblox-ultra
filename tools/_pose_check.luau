
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
local source = [==[
--!strict
-- The action animations, as poses rather than assets.
--
-- There are no punch or throw animations in Roblox's free set and none can be
-- uploaded through Open Cloud, so these are built out of joint offsets: a
-- short list of keyframes per joint, layered on top of whatever walk or idle
-- track is already running.
--
-- HOW, and why the obvious way does not work. The first version tweened
-- Motor6D.C0 on the server: every frame of the tween had to replicate and the
-- owning client's animator overwrote the arm in between, so nothing arrived.
-- The second version tweened C0 on the client, which replicates nothing but
-- still loses: the Animator writes Motor6D.Transform every frame during the
-- character render step, and a tween running on its own clock alongside that
-- is a race. A swing either never read or flickered.
--
-- The third version wrote Transform itself from a render step bound after
-- Enum.RenderPriority.Character, on the theory that the animator has finished
-- by then. On a phone it still showed nothing: whether that step lands before
-- or after the animation job is a scheduler detail, and when it lands first
-- the animator simply overwrites the whole swing in the same frame.
--
-- This version stops fighting for the same property. The animator owns
-- Motor6D.Transform; it never touches Motor6D.C0. So the pose is written into
-- C0 instead -- the joint's own rest offset -- and the two compose: the walk
-- cycle keeps playing on Transform while the arm it plays on is rotated by us.
-- Nothing can overwrite it because nothing else writes C0, which also means
-- the render step's priority stops mattering. The original C0 is put back the
-- moment the pose ends, so a joint is never left bent.

local RunService = game:GetService("RunService")

local ActionPoses = {}

export type Key = { offset: CFrame, time: number, style: Enum.EasingStyle? }

-- Actions whose last keyframe STAYS until it is let go, rather than running to
-- the end and releasing. A guard is up for as long as the button is down.
local HELD: { [string]: boolean } = { block = true, carry = true, winded = true }

-- Joint lookup: R15 part and motor first, then the R6 fallback.
local JOINTS: { [string]: { string } } = {
	rightArm = { "RightUpperArm", "RightShoulder", "Torso", "Right Shoulder" },
	rightElbow = { "RightLowerArm", "RightElbow", "__none", "__none" },
	leftArm = { "LeftUpperArm", "LeftShoulder", "Torso", "Left Shoulder" },
	leftElbow = { "LeftLowerArm", "LeftElbow", "__none", "__none" },
	torso = { "UpperTorso", "Waist", "__none", "__none" },
	head = { "Head", "Neck", "Head", "Neck" },
	rightLeg = { "RightUpperLeg", "RightHip", "Torso", "Right Hip" },
	leftLeg = { "LeftUpperLeg", "LeftHip", "Torso", "Left Hip" },
}

local function findMotor(character: Model, jointName: string): Motor6D?
	local spec = JOINTS[jointName]
	if not spec then
		return nil
	end
	local part = character:FindFirstChild(spec[1])
	local motor = part and part:FindFirstChild(spec[2])
	if not (motor and motor:IsA("Motor6D")) then
		part = character:FindFirstChild(spec[3])
		motor = part and part:FindFirstChild(spec[4])
	end
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function deg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- Each action is a table of joint -> keyframes. Times are in seconds and run
-- one after another, so the whole list is the length of the action. Every list
-- starts from rest and is expected to end back at rest.
local ACTIONS: { [string]: { [string]: { Key } } } = {
	-- A jab. Bigger than it needs to be on purpose: a punch that reads at a
	-- glance on a phone, from behind, is worth more than an accurate one.
	punch = {
		rightArm = {
			{ offset = deg(-44, 0, 16), time = 0.08 },
			{ offset = deg(118, 0, -26), time = 0.06, style = Enum.EasingStyle.Back },
			{ offset = deg(104, 0, -18), time = 0.07 },
			{ offset = CFrame.new(), time = 0.17 },
		},
		rightElbow = {
			{ offset = deg(-70, 0, 0), time = 0.08 },
			{ offset = deg(10, 0, 0), time = 0.06 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		leftArm = {
			{ offset = deg(30, 0, -18), time = 0.08 },
			{ offset = deg(14, 0, -10), time = 0.13 },
			{ offset = CFrame.new(), time = 0.17 },
		},
		torso = {
			{ offset = deg(0, 22, 0), time = 0.08 },
			{ offset = deg(0, -28, 0), time = 0.06 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		head = {
			{ offset = deg(0, 14, 0), time = 0.08 },
			{ offset = deg(0, -16, 0), time = 0.06 },
			{ offset = CFrame.new(), time = 0.24 },
		},
	},
	-- an overarm throw: all the way back, then whipped over the top
	throw = {
		rightArm = {
			{ offset = deg(-128, 0, 24), time = 0.14 },
			{ offset = deg(126, 0, -18), time = 0.08, style = Enum.EasingStyle.Back },
			{ offset = deg(74, 0, -12), time = 0.09 },
			{ offset = CFrame.new(), time = 0.19 },
		},
		rightElbow = {
			{ offset = deg(-92, 0, 0), time = 0.14 },
			{ offset = deg(6, 0, 0), time = 0.08 },
			{ offset = CFrame.new(), time = 0.28 },
		},
		torso = {
			{ offset = deg(0, 30, 0), time = 0.14 },
			{ offset = deg(0, -30, 0), time = 0.08 },
			{ offset = CFrame.new(), time = 0.28 },
		},
	},
	-- taking one: a flinch, quick in and slow out
	hurt = {
		torso = {
			{ offset = deg(-18, 0, 8), time = 0.07 },
			{ offset = CFrame.new(), time = 0.28 },
		},
		head = {
			{ offset = deg(16, -14, 0), time = 0.07 },
			{ offset = CFrame.new(), time = 0.32 },
		},
		leftArm = {
			{ offset = deg(-32, 0, -36), time = 0.07 },
			{ offset = CFrame.new(), time = 0.32 },
		},
		rightArm = {
			{ offset = deg(-26, 0, 30), time = 0.07 },
			{ offset = CFrame.new(), time = 0.32 },
		},
	},
	-- out cold: everything drops, held long enough to read across a hallway
	knockout = {
		torso = {
			{ offset = deg(-40, 0, 12), time = 0.16 },
			{ offset = deg(-36, 0, 10), time = 1.1 },
			{ offset = CFrame.new(), time = 0.34 },
		},
		head = {
			{ offset = deg(30, 0, 16), time = 0.16 },
			{ offset = deg(28, 0, 14), time = 1.1 },
			{ offset = CFrame.new(), time = 0.34 },
		},
		rightArm = {
			{ offset = deg(-48, 0, 30), time = 0.16 },
			{ offset = deg(-44, 0, 28), time = 1.1 },
			{ offset = CFrame.new(), time = 0.34 },
		},
		leftArm = {
			{ offset = deg(-48, 0, -30), time = 0.16 },
			{ offset = deg(-44, 0, -28), time = 1.1 },
			{ offset = CFrame.new(), time = 0.34 },
		},
	},
	-- ---------------- the rest of the chain ----------------
	-- A jab on its own is a poke. Three beats with different shapes is a
	-- fight: lead hand, back hand, then a boot. FightService only lets the
	-- second and third land if you keep the rhythm.
	cross = {
		leftArm = {
			{ offset = deg(-40, 0, -18), time = 0.07 },
			{ offset = deg(122, 0, 24), time = 0.06, style = Enum.EasingStyle.Back },
			{ offset = deg(108, 0, 18), time = 0.07 },
			{ offset = CFrame.new(), time = 0.18 },
		},
		leftElbow = {
			{ offset = deg(-72, 0, 0), time = 0.07 },
			{ offset = deg(10, 0, 0), time = 0.06 },
			{ offset = CFrame.new(), time = 0.25 },
		},
		rightArm = {
			{ offset = deg(34, 0, 20), time = 0.07 },
			{ offset = deg(16, 0, 12), time = 0.13 },
			{ offset = CFrame.new(), time = 0.18 },
		},
		torso = {
			{ offset = deg(0, -26, 0), time = 0.07 },
			{ offset = deg(0, 32, 0), time = 0.06 },
			{ offset = CFrame.new(), time = 0.25 },
		},
		head = {
			{ offset = deg(0, -16, 0), time = 0.07 },
			{ offset = deg(0, 18, 0), time = 0.06 },
			{ offset = CFrame.new(), time = 0.25 },
		},
	},
	-- the finisher: chamber the knee, snap the leg, land square
	kick = {
		rightLeg = {
			{ offset = deg(-52, 0, 0), time = 0.09 },
			{ offset = deg(-96, 0, 0), time = 0.07, style = Enum.EasingStyle.Back },
			{ offset = deg(-70, 0, 0), time = 0.08 },
			{ offset = CFrame.new(), time = 0.2 },
		},
		leftLeg = {
			{ offset = deg(8, 0, 0), time = 0.09 },
			{ offset = deg(14, 0, 0), time = 0.15 },
			{ offset = CFrame.new(), time = 0.2 },
		},
		torso = {
			{ offset = deg(16, 0, 0), time = 0.09 },
			{ offset = deg(-14, 0, 0), time = 0.07 },
			{ offset = CFrame.new(), time = 0.28 },
		},
		rightArm = {
			{ offset = deg(-24, 0, 34), time = 0.09 },
			{ offset = deg(-14, 0, 26), time = 0.07 },
			{ offset = CFrame.new(), time = 0.28 },
		},
		leftArm = {
			{ offset = deg(-30, 0, -40), time = 0.09 },
			{ offset = deg(-20, 0, -30), time = 0.07 },
			{ offset = CFrame.new(), time = 0.28 },
		},
	},
	-- guard up. Held: the last frame stays until the button is let go.
	block = {
		rightArm = {
			{ offset = deg(-72, 0, 22), time = 0.1 },
			{ offset = deg(-76, 0, 24), time = 0.1 },
		},
		rightElbow = {
			{ offset = deg(-96, 0, 0), time = 0.1 },
			{ offset = deg(-100, 0, 0), time = 0.1 },
		},
		leftArm = {
			{ offset = deg(-72, 0, -22), time = 0.1 },
			{ offset = deg(-76, 0, -24), time = 0.1 },
		},
		leftElbow = {
			{ offset = deg(-96, 0, 0), time = 0.1 },
			{ offset = deg(-100, 0, 0), time = 0.1 },
		},
		torso = {
			{ offset = deg(10, 0, 0), time = 0.1 },
			{ offset = deg(12, 0, 0), time = 0.1 },
		},
		head = {
			{ offset = deg(12, 0, 0), time = 0.1 },
			{ offset = deg(14, 0, 0), time = 0.1 },
		},
	},
	-- out of energy: hands on knees, and it reads across a corridor
	winded = {
		torso = {
			{ offset = deg(32, 0, 0), time = 0.3 },
			{ offset = deg(34, 0, 0), time = 0.3 },
		},
		head = {
			{ offset = deg(-22, 0, 0), time = 0.3 },
			{ offset = deg(-20, 0, 0), time = 0.3 },
		},
		rightArm = {
			{ offset = deg(-52, 0, 18), time = 0.3 },
			{ offset = deg(-50, 0, 16), time = 0.3 },
		},
		leftArm = {
			{ offset = deg(-52, 0, -18), time = 0.3 },
			{ offset = deg(-50, 0, -16), time = 0.3 },
		},
	},
	-- back on your feet after the nurse
	getup = {
		torso = {
			{ offset = deg(46, 0, 0), time = 0.1 },
			{ offset = deg(-6, 0, 0), time = 0.4, style = Enum.EasingStyle.Back },
			{ offset = CFrame.new(), time = 0.25 },
		},
		head = {
			{ offset = deg(-30, 0, 0), time = 0.1 },
			{ offset = deg(6, 0, 0), time = 0.4 },
			{ offset = CFrame.new(), time = 0.25 },
		},
		rightArm = {
			{ offset = deg(-70, 0, 26), time = 0.1 },
			{ offset = deg(10, 0, 8), time = 0.4 },
			{ offset = CFrame.new(), time = 0.25 },
		},
		leftArm = {
			{ offset = deg(-70, 0, -26), time = 0.1 },
			{ offset = deg(10, 0, -8), time = 0.4 },
			{ offset = CFrame.new(), time = 0.25 },
		},
	},
	-- carrying somebody else's student home. Held while you have them.
	carry = {
		rightArm = {
			{ offset = deg(-96, 0, 16), time = 0.2 },
			{ offset = deg(-100, 0, 18), time = 0.2 },
		},
		leftArm = {
			{ offset = deg(-96, 0, -16), time = 0.2 },
			{ offset = deg(-100, 0, -18), time = 0.2 },
		},
		torso = {
			{ offset = deg(-10, 0, 0), time = 0.2 },
			{ offset = deg(-12, 0, 0), time = 0.2 },
		},
	},

	-- ---------------- emotes ----------------
	-- Eight of them, on a wheel. This is not decoration: in a school game the
	-- thing players do most is stand near each other, and standing near each
	-- other is only worth doing if you can do something while you do it.
	wave = {
		rightArm = {
			{ offset = deg(-142, 0, 30), time = 0.18 },
			{ offset = deg(-142, 0, 54), time = 0.16 },
			{ offset = deg(-142, 0, 26), time = 0.16 },
			{ offset = deg(-142, 0, 54), time = 0.16 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		head = {
			{ offset = deg(0, 12, 6), time = 0.18 },
			{ offset = deg(0, 12, 6), time = 0.48 },
			{ offset = CFrame.new(), time = 0.24 },
		},
	},
	cheer = {
		rightArm = {
			{ offset = deg(-166, 0, 20), time = 0.14 },
			{ offset = deg(-150, 0, 20), time = 0.16 },
			{ offset = deg(-166, 0, 20), time = 0.16 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		leftArm = {
			{ offset = deg(-166, 0, -20), time = 0.14 },
			{ offset = deg(-150, 0, -20), time = 0.16 },
			{ offset = deg(-166, 0, -20), time = 0.16 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		torso = {
			{ offset = deg(-12, 0, 0), time = 0.14 },
			{ offset = deg(-4, 0, 0), time = 0.32 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		head = {
			{ offset = deg(-20, 0, 0), time = 0.14 },
			{ offset = deg(-16, 0, 0), time = 0.32 },
			{ offset = CFrame.new(), time = 0.24 },
		},
	},
	dance = {
		torso = {
			{ offset = deg(0, 22, 8), time = 0.22 },
			{ offset = deg(0, -22, -8), time = 0.22 },
			{ offset = deg(0, 22, 8), time = 0.22 },
			{ offset = deg(0, -22, -8), time = 0.22 },
			{ offset = CFrame.new(), time = 0.2 },
		},
		rightArm = {
			{ offset = deg(-120, 0, 40), time = 0.22 },
			{ offset = deg(-40, 0, 20), time = 0.22 },
			{ offset = deg(-120, 0, 40), time = 0.22 },
			{ offset = deg(-40, 0, 20), time = 0.22 },
			{ offset = CFrame.new(), time = 0.2 },
		},
		leftArm = {
			{ offset = deg(-40, 0, -20), time = 0.22 },
			{ offset = deg(-120, 0, -40), time = 0.22 },
			{ offset = deg(-40, 0, -20), time = 0.22 },
			{ offset = deg(-120, 0, -40), time = 0.22 },
			{ offset = CFrame.new(), time = 0.2 },
		},
		head = {
			{ offset = deg(0, 18, 0), time = 0.22 },
			{ offset = deg(0, -18, 0), time = 0.22 },
			{ offset = deg(0, 18, 0), time = 0.22 },
			{ offset = deg(0, -18, 0), time = 0.22 },
			{ offset = CFrame.new(), time = 0.2 },
		},
	},
	point = {
		rightArm = {
			{ offset = deg(-88, 0, 6), time = 0.14 },
			{ offset = deg(-90, 0, 6), time = 0.7 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		torso = {
			{ offset = deg(0, -10, 0), time = 0.14 },
			{ offset = deg(0, -10, 0), time = 0.7 },
			{ offset = CFrame.new(), time = 0.24 },
		},
	},
	taunt = {
		rightArm = {
			{ offset = deg(-104, 0, 40), time = 0.16 },
			{ offset = deg(-84, 0, 52), time = 0.18 },
			{ offset = deg(-104, 0, 40), time = 0.18 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		torso = {
			{ offset = deg(-14, 0, 0), time = 0.16 },
			{ offset = deg(-6, 0, 0), time = 0.36 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		head = {
			{ offset = deg(-18, 0, 0), time = 0.16 },
			{ offset = deg(-14, 0, 0), time = 0.36 },
			{ offset = CFrame.new(), time = 0.24 },
		},
	},
	clap = {
		rightArm = {
			{ offset = deg(-84, 0, 46), time = 0.14 },
			{ offset = deg(-84, 0, 16), time = 0.12 },
			{ offset = deg(-84, 0, 46), time = 0.12 },
			{ offset = deg(-84, 0, 16), time = 0.12 },
			{ offset = CFrame.new(), time = 0.22 },
		},
		leftArm = {
			{ offset = deg(-84, 0, -46), time = 0.14 },
			{ offset = deg(-84, 0, -16), time = 0.12 },
			{ offset = deg(-84, 0, -46), time = 0.12 },
			{ offset = deg(-84, 0, -16), time = 0.12 },
			{ offset = CFrame.new(), time = 0.22 },
		},
	},
	shrug = {
		rightArm = {
			{ offset = deg(-20, 0, 46), time = 0.2 },
			{ offset = deg(-20, 0, 46), time = 0.4 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		leftArm = {
			{ offset = deg(-20, 0, -46), time = 0.2 },
			{ offset = deg(-20, 0, -46), time = 0.4 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		head = {
			{ offset = deg(-8, 0, 14), time = 0.2 },
			{ offset = deg(-8, 0, 14), time = 0.4 },
			{ offset = CFrame.new(), time = 0.26 },
		},
	},
	facepalm = {
		rightArm = {
			{ offset = deg(-128, 0, 12), time = 0.18 },
			{ offset = deg(-130, 0, 12), time = 0.6 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		rightElbow = {
			{ offset = deg(-104, 0, 0), time = 0.18 },
			{ offset = deg(-106, 0, 0), time = 0.6 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		head = {
			{ offset = deg(24, 0, 0), time = 0.18 },
			{ offset = deg(26, 0, 0), time = 0.6 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		torso = {
			{ offset = deg(12, 0, 0), time = 0.18 },
			{ offset = deg(14, 0, 0), time = 0.6 },
			{ offset = CFrame.new(), time = 0.26 },
		},
	},

	-- landed one: a short celebration, so a knockout has a punctuation mark
	flex = {
		rightArm = {
			{ offset = deg(-104, 0, 44), time = 0.18 },
			{ offset = deg(-108, 0, 48), time = 0.5 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		rightElbow = {
			{ offset = deg(-96, 0, 0), time = 0.18 },
			{ offset = deg(-100, 0, 0), time = 0.5 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		leftArm = {
			{ offset = deg(-104, 0, -44), time = 0.18 },
			{ offset = deg(-108, 0, -48), time = 0.5 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		leftElbow = {
			{ offset = deg(-96, 0, 0), time = 0.18 },
			{ offset = deg(-100, 0, 0), time = 0.5 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		torso = {
			{ offset = deg(-10, 0, 0), time = 0.18 },
			{ offset = CFrame.new(), time = 0.76 },
		},
	},
}

type Active = {
	character: Model,
	kind: string,
	motors: { [string]: Motor6D },
	rest: { [string]: CFrame },
	keys: { [string]: { Key } },
	started: number,
	length: number,
	held: boolean,
}

local active: { Active } = {}
local bound = false

-- Every removal goes through here: a pose that is dropped without its C0
-- being restored leaves the character standing with one arm out forever.
local function release(index: number)
	local pose = active[index]
	table.remove(active, index)
	for jointName, motor in pose.motors do
		if motor.Parent then
			motor.C0 = pose.rest[jointName]
		end
	end
end

local function ease(style: Enum.EasingStyle?, t: number): number
	-- Only the two styles the tables use, hand-rolled: this runs inside the
	-- render step for every animating joint, and TweenService has no API for
	-- "give me the value of this curve at t".
	if style == Enum.EasingStyle.Back then
		local s = 1.70158
		local u = t - 1
		return u * u * ((s + 1) * u + s) + 1
	end
	-- Quad, easing out
	return 1 - (1 - t) * (1 - t)
end

-- Where a joint's offset sits `elapsed` seconds into its keyframe list.
local function sample(keys: { Key }, elapsed: number): CFrame?
	local from = CFrame.new()
	local at = 0
	for _, key in keys do
		if elapsed < at + key.time then
			local t = if key.time > 0 then (elapsed - at) / key.time else 1
			return from:Lerp(key.offset, ease(key.style, math.clamp(t, 0, 1)))
		end
		at += key.time
		from = key.offset
	end
	return nil -- past the end of the list
end

local function step()
	local now = os.clock()
	for i = #active, 1, -1 do
		local pose = active[i]
		local elapsed = now - pose.started
		if not pose.character.Parent then
			release(i)
			continue
		end
		if elapsed >= pose.length then
			if not pose.held then
				release(i)
				continue
			end
			-- a held pose sits on its last frame until it is stopped
			elapsed = pose.length - 0.0001
		end
		for jointName, motor in pose.motors do
			if not motor.Parent then
				continue
			end
			local offset = sample(pose.keys[jointName], elapsed)
			if offset then
				-- into the joint's rest offset, which the animator does not
				-- write, so the swing rides on top of the walk instead of
				-- racing it for the same property
				motor.C0 = pose.rest[jointName] * offset
			end
		end
	end
end

function ActionPoses.Play(character: Model, kind: string): boolean
	local action = ACTIONS[kind]
	if not action or not character or not character.Parent then
		return false
	end

	local motors: { [string]: Motor6D } = {}
	local rest: { [string]: CFrame } = {}
	local keys: { [string]: { Key } } = {}
	local length = 0
	for jointName, list in action do
		local motor = findMotor(character, jointName)
		if motor then
			motors[jointName] = motor
			rest[jointName] = motor.C0
			keys[jointName] = list
			local total = 0
			for _, key in list do
				total += key.time
			end
			length = math.max(length, total)
		end
	end
	if length <= 0 or next(motors) == nil then
		return false -- nothing on this rig to move
	end

	-- Don't stack two actions on one body: replace rather than overlay, so a
	-- fast second punch restarts the swing instead of fighting the first. The
	-- old pose is released BEFORE the new one is inserted, but its rest poses
	-- were captured above, off joints the old pose may have been holding bent
	-- -- so recapture them after the release or the bend becomes permanent.
	for i = #active, 1, -1 do
		if active[i].character == character then
			release(i)
		end
	end
	for jointName, motor in motors do
		rest[jointName] = motor.C0
	end
	table.insert(active, {
		character = character,
		kind = kind,
		motors = motors,
		rest = rest,
		keys = keys,
		started = os.clock(),
		length = length,
		held = HELD[kind] == true,
	})

	if not bound and RunService:IsClient() then
		bound = true
		-- after Character, which is when the Animator has finished writing
		RunService:BindToRenderStep(
			"ActionPoses",
			Enum.RenderPriority.Character.Value + 1,
			step
		)
	end
	return true
end

-- Let go of a held pose. Naming a kind stops only that one, so releasing the
-- guard cannot cancel a punch that started after it.
function ActionPoses.Stop(character: Model, kind: string?)
	for i = #active, 1, -1 do
		if active[i].character == character and (kind == nil or active[i].kind == kind) then
			release(i)
		end
	end
end

function ActionPoses.Has(kind: string): boolean
	return ACTIONS[kind] ~= nil
end

ActionPoses.Actions = ACTIONS

return ActionPoses

]==]
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
