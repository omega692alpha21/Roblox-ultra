
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

local C3MT = {}
C3MT.__index = function(c, k)
  -- Color3:Lerp is how the tree canopies and the rock faces mix their two
  -- tones, so the shim has to answer it or the map cannot be exported at all.
  if k == "Lerp" then
    return function(a, b, t)
      return setmetatable({R=a.R+(b.R-a.R)*t, G=a.G+(b.G-a.G)*t, B=a.B+(b.B-a.B)*t}, C3MT)
    end
  end
  return nil
end
local function c3(r, g, b) return setmetatable({R=r or 0, G=g or 0, B=b or 0}, C3MT) end
Color3 = {
  new = c3,
  fromRGB = function(r, g, b) return c3((r or 0)/255, (g or 0)/255, (b or 0)/255) end,
  fromHSV = function(h, s, v) return c3(v, v, v) end,
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
-- CFrame +/- Vector3: offsets the position, keeps the rotation. `cf - cf.Position`
-- is the idiom for "just the rotation", which is how the sanctum places
-- everything, and without this the shim could not run that module at all.
CFMT.__sub = function(a, v)
  return cfnew(a.p[1] - v.X, a.p[2] - v.Y, a.p[3] - v.Z, a.m)
end
CFMT.__add = function(a, v)
  return cfnew(a.p[1] + v.X, a.p[2] + v.Y, a.p[3] + v.Z, a.m)
end
CFMT.__mul = function(a, b)
  -- CFrame * Vector3 rotates and translates the point, and returns a Vector3;
  -- CFrame * CFrame composes. The sanctum needs the first to place a whole
  -- estate through one transform.
  if b.p == nil then
    local rp = rotvec(a.m, { b.X, b.Y, b.Z })
    return Vector3.new(a.p[1] + rp[1], a.p[2] + rp[2], a.p[3] + rp[3])
  end
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
      if class == "BasePart" then
        -- A WedgePart IS a BasePart. While this said otherwise, every pass
        -- that walks the map by IsA("BasePart") -- optimise, the window
        -- lighting -- skipped every pitched roof in the school, and the
        -- offline render behaved differently from the running game.
        return s.ClassName == "Part" or s.ClassName == "SpawnLocation"
          or s.ClassName == "WedgePart" or s.ClassName == "CornerWedgePart"
          or s.ClassName == "MeshPart" or s.ClassName == "TrussPart"
      end
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
local Palette = (function()

-- Brand palette (see design doc): used by map, models, and UI.

return {
	CashGreen = Color3.fromRGB(63, 191, 74),
	CashGreenDark = Color3.fromRGB(28, 92, 34),
	LockerBlue = Color3.fromRGB(46, 107, 214),
	LockerBlueDark = Color3.fromRGB(29, 68, 145),
	BusYellow = Color3.fromRGB(245, 197, 49),
	BusYellowDark = Color3.fromRGB(138, 107, 18),
	DetentionRed = Color3.fromRGB(217, 67, 47),
	DetentionRedDark = Color3.fromRGB(125, 35, 23),
	Blackboard = Color3.fromRGB(34, 48, 31),
	Chalk = Color3.fromRGB(216, 230, 212),
	AuraPurple = Color3.fromRGB(180, 75, 217),
	PanelBg = Color3.fromRGB(28, 39, 26),
	Floor = Color3.fromRGB(201, 195, 154),
	White = Color3.fromRGB(255, 255, 255),
}

end)()
local GameConfig = (function()

-- Central tuning knobs. Change numbers here, not in service code.

return {
	-- Plots / bases
	PlotCount = 8,
	BaseSlots = 6, -- default character slots per base
	ExtraSlotsPass = 2, -- added by the +2 Slots game pass
	SlotsPerRebirth = 1, -- extra slot per rebirth...
	MaxRebirthSlots = 4, -- ...capped at this many

	-- Conveyor
	ConveyorSpawnInterval = 3.5, -- seconds between character spawns
	ConveyorTravelTime = 28, -- seconds to cross the map
	ConveyorMaxAlive = 12, -- max characters on the belt at once

	-- Income
	IncomeTickSeconds = 1,
	StarterCash = 250,

	-- Stealing
	CarrySpeedMultiplier = 0.7, -- thief walkspeed while carrying
	StealDepositRadius = 6,

	-- Locks
	JoinGraceLockSeconds = 30,
	BaseLockSeconds = 60,
	LockSecondsPerRebirth = 10,
	LockCooldownSeconds = 90,
	ExtendedLockPassBonus = 30,

	-- Offline earnings
	OfflineEarningsRate = 0.35, -- fraction of live income/s earned while away
	OfflineEarningsCapHours = 2,
	OfflineEarningsCapHours2x = 4, -- with 2x Cash pass

	-- Movement. Roblox's default 16/7.2 is a walking pace built for obbies;
	-- this genre reads as sluggish at that speed, so the whole game moves a
	-- notch faster and jumps a little higher.
	BaseWalkSpeed = 20,
	JumpHeight = 8.4,

	-- Speed pass
	SpeedPassBonus = 6, -- added walkspeed
	SprintBonus = 10, -- extra walkspeed while holding sprint

	-- School RPG layer
	ClassBellIntervalSeconds = 300, -- time between class bells
	ClassOpenSeconds = 75, -- window to get to the room and sit in
	QuizQuestionCount = 3,
	QuizCashReward = 500, -- scaled by rebirth multiplier
	QuizRepReward = 15,
	QuizLuckBuffSeconds = 120,
	QuizLuckBuffMultiplier = 1.5,

	-- Fighting
	PunchCooldownSeconds = 0.6,
	PunchRange = 8,
	PunchKnockback = 40,
	PunchDamage = 9,
	-- the account that owns the place: the principal
	OwnerUserId = 11578479542,
	RepPerThiefHit = 2,
	RepPerSteal = 10,

	-- Event flags (set for special weekends, no code changes needed)
	EventLuckMultiplier = 1, -- e.g. 2 for a "2x Luck Weekend"
	EventCashMultiplier = 1, -- e.g. 2 for a "2x Cash Hour"

	-- Secret Rush: recurring in-server hype window with boosted odds
	SecretRushMinInterval = 1080, -- seconds between rushes (min)
	SecretRushMaxInterval = 1560, -- (max)
	SecretRushDuration = 75,
	SecretRushLuckMult = 5,

	-- Bounty: the richest player in the server wears a crown; robbing them pays extra
	BountyStealAuraBonus = 15,

	-- Rico the Bully (NPC rival)
	RivalRaidMinSeconds = 100,
	RivalRaidMaxSeconds = 180,
	RivalWalkSpeed = 11,
	RivalEscapeReturnSeconds = 15,
	RivalFoilAura = 3,

	-- Live server events (EventDirector)
	EventFirstDelay = 240, -- seconds after server start before the first event
	EventMinInterval = 420, -- seconds between events (min)
	EventMaxInterval = 720, -- (max)

	-- Curfew: after Lights Out, being outdoors farms aura but risks detention
	CurfewNightSeconds = 120,
	CurfewTickSeconds = 5,
	CurfewAuraCap = 6, -- per-tick aura ramps 1,2,3... up to this
	CurfewCatchBase = 0.04, -- prefect catch chance on the first tick outside
	CurfewCatchRamp = 0.025, -- extra catch chance per consecutive tick
	CurfewCatchMax = 0.35,
	DetentionSeconds = 75,
	DetentionAuraPenalty = 5,

	-- Campus coin pickups
	CoinValueMin = 25,
	CoinValueMax = 75,
	CoinRespawnMin = 45,
	CoinRespawnMax = 90,

	-- Misc
	AutosaveSeconds = 60,
	LeaderboardPushSeconds = 120,
	LeaderboardSize = 50,
}

end)()
local __Cliques = (function()

-- The five roles. You pick one when you first walk in, along with who you are,
-- and it decides what you are good at for the rest of the game.
--
-- This used to be four "cliques" you joined at a board in the courtyard, with
-- one perk each. It is the character class now, because a school game where
-- everyone plays identically has nothing to choose. The board is still there
-- and still lets you re-sort, for a slice of your cash -- people change.
--
-- The shape of it:
--
--   NERD     wins in the classroom and loses in the corridor
--   JOCK     the bruiser: hits hard, takes hits, average everywhere else
--   ATHLETE  fastest, longest wind, best throw -- fragile in a brawl
--   BULLY    hurts most and lasts longest, and is hopeless at lessons
--   REGULAR  average at all of it, and paid a little better for the trouble
--
-- Every number is a multiplier on the baseline (or an offset where the field
-- name says bonus), so the "average" role is a row of ones and the others read
-- as what they trade away.
--
-- The old field names are kept exactly as they were -- walkSpeedBonus,
-- knockbackMult, quizRewardMult, offlineCapBonusHours, carrySpeedMultOverride
-- -- because StealService, FightService, ClassService and RewardService all
-- read them and none of that had to change.

export type CliqueDef = {
	id: string,
	name: string,
	motto: string,
	blurb: string, -- what the pick screen says this role is for
	icon: string,
	color: Color3,

	-- movement and the chase
	walkSpeedBonus: number,
	energyMax: number,
	energyDrainMult: number, -- below 1 means you sprint for longer

	-- taking and giving out punishment
	maxHealth: number,
	damageMult: number, -- punches and thrown toys
	knockbackMult: number,
	aimAssistMult: number, -- how forgiving the throw reticle is

	-- the classroom and the wallet
	quizRewardMult: number,
	classTimeBonus: number, -- extra seconds on a lesson's clock
	cashMult: number,
	offlineCapBonusHours: number,

	carrySpeedMultOverride: number?, -- replaces GameConfig.CarrySpeedMultiplier
}

local Cliques: { CliqueDef } = {
	{
		id = "nerds",
		name = "Nerd",
		motto = "Actually, it's pronounced GIF.",
		blurb = "Top of every class. Bottom of every fight.",
		icon = "🤓",
		color = Color3.fromRGB(46, 107, 214),
		walkSpeedBonus = -1,
		energyMax = 80,
		energyDrainMult = 1.15,
		maxHealth = 85,
		damageMult = 0.8,
		knockbackMult = 0.9,
		aimAssistMult = 0.9,
		quizRewardMult = 1.75,
		classTimeBonus = 4,
		cashMult = 1,
		offlineCapBonusHours = 1,
	},
	{
		id = "jocks",
		name = "Jock",
		motto = "Touch grass? We ARE the grass.",
		blurb = "Built for contact. Hits hard, shrugs it off.",
		icon = "🏈",
		color = Color3.fromRGB(217, 67, 47),
		walkSpeedBonus = 2,
		energyMax = 110,
		energyDrainMult = 0.95,
		maxHealth = 120,
		damageMult = 1.25,
		knockbackMult = 1.25,
		aimAssistMult = 1,
		quizRewardMult = 0.9,
		classTimeBonus = 0,
		cashMult = 1,
		offlineCapBonusHours = 0,
	},
	{
		id = "athletes",
		name = "Athlete",
		motto = "You will hear the whistle. You will not catch me.",
		blurb = "Fastest legs, longest wind, best throw.",
		icon = "🏃",
		color = Color3.fromRGB(64, 176, 132),
		walkSpeedBonus = 4,
		energyMax = 150,
		energyDrainMult = 0.65,
		maxHealth = 95,
		damageMult = 1,
		knockbackMult = 1,
		aimAssistMult = 1.7,
		quizRewardMult = 1,
		classTimeBonus = 0,
		cashMult = 1,
		offlineCapBonusHours = 0,
		carrySpeedMultOverride = 0.85, -- still quick with a student over the shoulder
	},
	{
		id = "bullies",
		name = "Bully",
		motto = "Lunch money is a participation fee.",
		blurb = "Hurts the most. Lasts the longest. Learns the least.",
		icon = "😤",
		color = Color3.fromRGB(180, 75, 217),
		walkSpeedBonus = 0,
		energyMax = 95,
		energyDrainMult = 1,
		maxHealth = 145,
		damageMult = 1.5,
		knockbackMult = 1.35,
		aimAssistMult = 0.95,
		quizRewardMult = 0.7,
		classTimeBonus = -2,
		cashMult = 1,
		offlineCapBonusHours = 0,
	},
	{
		id = "regulars",
		name = "Regular",
		motto = "Just here for the lunch, honestly.",
		blurb = "Average at everything, and paid better for it.",
		icon = "🙂",
		color = Color3.fromRGB(245, 197, 49),
		walkSpeedBonus = 0,
		energyMax = 100,
		energyDrainMult = 1,
		maxHealth = 100,
		damageMult = 1,
		knockbackMult = 1,
		aimAssistMult = 1,
		quizRewardMult = 1,
		classTimeBonus = 0,
		cashMult = 1.18,
		offlineCapBonusHours = 1,
	},
}

local module = {
	List = Cliques,
	SwitchCostFraction = 0.15, -- re-sorting costs this fraction of your cash
}

function module.Get(id: string): CliqueDef?
	for _, c in Cliques do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- The role a player is actually playing, falling back to Regular so nothing
-- downstream has to keep writing "or 1".
function module.For(player: Player): CliqueDef
	local id = player:GetAttribute("Clique")
	if typeof(id) == "string" then
		local found = module.Get(id)
		if found then
			return found
		end
	end
	return Cliques[5]
end

return module

end)()
local __PropSizes = (function()

-- Generated by tools/prop_registry.py -- do not edit by hand.
--
-- The size in studs of every prop the school can place, measured from the
-- uploaded mesh. MapService scatters furniture into rooms and has to know
-- how much floor each piece needs before it puts the next one down.
-- Only kinds whose model actually uploaded appear here, so a scatter pool
-- naturally narrows to what exists.
return {
	SchoolDesk = Vector3.new(2.63, 3.27, 2.02),
	SchoolChair = Vector3.new(2.09, 3.72, 2.50),
	OfficeDesk = Vector3.new(7.40, 2.91, 3.50),
	Chalkboard = Vector3.new(3.40, 5.58, 2.81),
	ProjectorScreen = Vector3.new(4.05, 6.66, 3.39),
	Bookshelf = Vector3.new(5.08, 7.63, 2.15),
	Shelf = Vector3.new(3.71, 7.70, 0.95),
	SteelShelves = Vector3.new(3.90, 7.60, 1.78),
	SteelShelves2 = Vector3.new(2.20, 7.92, 1.86),
	Clock = Vector3.new(1.19, 1.19, 0.17),
	Laptop = Vector3.new(2.41, 2.01, 1.80),
	Stationery = Vector3.new(1.12, 0.61, 0.31),
	Notepads = Vector3.new(4.08, 0.08, 2.44),
	Clipboard = Vector3.new(0.85, 0.16, 1.25),
	BunsenBurner = Vector3.new(1.28, 1.60, 1.28),
	FireAlarm = Vector3.new(0.37, 0.53, 0.10),
	Extinguisher = Vector3.new(1.04, 2.44, 1.36),
	Bin = Vector3.new(6.83, 3.35, 2.06),
	WetFloorSign = Vector3.new(1.11, 2.33, 1.33),
	Table = Vector3.new(6.66, 2.03, 2.43),
	Table2 = Vector3.new(1.87, 2.60, 1.87),
	Chair = Vector3.new(1.60, 3.54, 2.00),
	Chair2 = Vector3.new(2.37, 4.68, 2.45),
	ArmChair = Vector3.new(3.14, 3.94, 2.83),
	Sofa = Vector3.new(5.81, 2.95, 2.43),
	Sofa2 = Vector3.new(6.69, 2.63, 3.03),
	CoffeeTable = Vector3.new(5.70, 1.94, 3.60),
	SideTable = Vector3.new(2.04, 2.04, 1.67),
	CeilingLamp = Vector3.new(1.60, 3.52, 1.60),
	HangingLamp = Vector3.new(2.03, 5.01, 2.03),
	PictureFrame = Vector3.new(2.20, 3.11, 0.06),
	FramedPicture = Vector3.new(3.90, 3.00, 0.13),
	Mirror = Vector3.new(3.92, 6.00, 0.21),
	WhaleStatue = Vector3.new(3.45, 3.97, 5.05),
	RayStatue = Vector3.new(2.62, 2.18, 1.98),
	Vase1 = Vector3.new(0.75, 1.48, 0.75),
	Vase2 = Vector3.new(0.81, 1.14, 0.81),
	Vase4 = Vector3.new(0.67, 1.27, 0.67),
	PlanterPot = Vector3.new(3.60, 3.00, 3.56),
	PlanterBox = Vector3.new(6.44, 3.00, 2.92),
	PottedPlant = Vector3.new(3.14, 5.00, 3.45),
	Fern = Vector3.new(11.07, 2.40, 9.67),
	GrandfatherClock = Vector3.new(2.31, 8.11, 1.58),
	Ottoman = Vector3.new(3.27, 2.31, 2.30),
	GreenChair = Vector3.new(2.49, 3.92, 2.46),
	MonoblocChair = Vector3.new(2.37, 3.26, 2.32),
	DiningTable = Vector3.new(8.35, 3.24, 5.14),
	Bench = Vector3.new(4.31, 3.29, 1.84),
	StreetLamp = Vector3.new(4.73, 26.00, 2.60),
	StreetLampShort = Vector3.new(4.61, 20.00, 9.63),
	WallLantern = Vector3.new(1.49, 3.60, 1.19),
	DeskLamp = Vector3.new(1.21, 2.40, 1.73),
	Stool = Vector3.new(1.42, 2.14, 1.50),
	PicnicTable = Vector3.new(8.29, 2.76, 11.18),
	Football = Vector3.new(1.88, 0.82, 0.82),
	AmericanFootball = Vector3.new(1.68, 0.95, 0.95),
	Baseball = Vector3.new(0.59, 0.60, 0.60),
	Dartboard = Vector3.new(1.67, 1.67, 0.15),
	Shrub = Vector3.new(14.57, 2.40, 6.06),
	Flowers = Vector3.new(10.84, 2.20, 2.33),
	SecurityLight = Vector3.new(1.20, 1.96, 1.54),
	IndustrialLamp = Vector3.new(1.01, 1.59, 0.52),
	DayBed = Vector3.new(7.30, 4.17, 3.16),
	Nightstand = Vector3.new(2.10, 2.59, 1.57),
	Cabinet = Vector3.new(3.69, 9.50, 2.70),
	Drawer = Vector3.new(3.17, 2.02, 1.69),
	Pillows = Vector3.new(3.78, 1.67, 2.32),
	Boombox = Vector3.new(2.68, 1.74, 0.69),
	Television = Vector3.new(3.94, 3.00, 3.09),
	LoungeChair = Vector3.new(3.73, 4.33, 4.40),
	ModernCoffeeTable = Vector3.new(2.22, 1.44, 4.45),
	WoodenTable = Vector3.new(4.20, 2.96, 2.61),
	PaintedWoodenNightstand = Vector3.new(1.87, 2.28, 1.88),
	PaintedWoodenTable = Vector3.new(8.90, 3.55, 4.21),
	ChineseSofa = Vector3.new(8.46, 3.18, 3.58),
	ChineseStool = Vector3.new(2.22, 2.33, 1.87),
	RollershutterDoor = Vector3.new(11.40, 8.88, 1.11),
	RollershutterWindow = Vector3.new(18.87, 6.85, 1.11),
	RollershutterWindow2 = Vector3.new(13.32, 5.78, 0.62),
	RollershutterWindow3 = Vector3.new(11.01, 5.72, 0.57),
	Barrel = Vector3.new(2.35, 3.44, 2.36),
	StandingPictureFrame = Vector3.new(0.37, 0.92, 0.74),
	Croissant = Vector3.new(0.74, 0.23, 0.28),
	SweetPotato = Vector3.new(0.22, 0.37, 0.23),
	CarvedWoodenPlate = Vector3.new(1.01, 0.14, 0.99),
	PaintedWoodenCabinet = Vector3.new(4.42, 4.37, 2.28),
	WoodenTable2 = Vector3.new(4.91, 3.07, 2.13),
	Television2 = Vector3.new(1.48, 1.52, 1.30),
	ChineseTeaTable = Vector3.new(3.11, 1.84, 3.09),
	BrassVase = Vector3.new(0.31, 0.74, 0.31),
	BaseballBat = Vector3.new(0.24, 3.38, 0.24),
	ChineseArmchair = Vector3.new(3.14, 5.87, 2.92),
	Barrel2 = Vector3.new(2.08, 3.26, 2.08),
	Barrel3 = Vector3.new(1.81, 3.26, 1.79),
	CarvedWoodenElephant = Vector3.new(0.40, 0.36, 0.21),
	BrassVase2 = Vector3.new(0.30, 0.63, 0.23),
	CeramicVase = Vector3.new(0.42, 1.53, 0.42),
	OldTyre = Vector3.new(2.22, 2.22, 0.61),
	StandingPictureFrame2 = Vector3.new(0.38, 0.99, 0.80),
	WoodenDisplayShelves = Vector3.new(1.37, 5.76, 3.99),
	Plunger = Vector3.new(0.64, 1.56, 0.64),
	WoodenCandlestick = Vector3.new(0.36, 0.81, 0.37),
	BrassPot = Vector3.new(1.36, 0.40, 1.12),
	SmallWoodenTable = Vector3.new(3.39, 1.97, 1.63),
	WoodenCuttingBoard = Vector3.new(1.66, 0.15, 0.91),
	CeramicPot = Vector3.new(2.43, 1.38, 1.86),
	HangingPictureFrame = Vector3.new(2.78, 1.85, 0.12),
	BrassPot2 = Vector3.new(1.12, 1.08, 1.12),
	GothicCommode = Vector3.new(4.45, 4.48, 2.15),
	Lemon = Vector3.new(0.25, 0.35, 0.25),
	CoffeeTableRound = Vector3.new(4.81, 1.82, 4.81),
	PlasticContainer = Vector3.new(3.31, 1.59, 2.32),
	VintagePocketWatch = Vector3.new(0.23, 0.30, 0.05),
	RoundWoodenTable = Vector3.new(2.95, 2.76, 2.95),
	BarberShopChair = Vector3.new(2.80, 5.51, 4.91),
	Dustpan = Vector3.new(1.23, 0.37, 1.36),
	BrassPan = Vector3.new(0.71, 0.19, 1.66),
	PasticTorch6v = Vector3.new(0.51, 0.52, 0.83),
	VintageStapler = Vector3.new(0.77, 0.35, 0.18),
	Lightbulb = Vector3.new(0.22, 0.37, 0.22),
	UtilityBox = Vector3.new(1.92, 4.15, 1.60),
	Trashbag = Vector3.new(1.95, 2.13, 1.71),
	WoodenBowl = Vector3.new(0.48, 0.27, 0.46),
	CassettePlayer = Vector3.new(0.48, 0.88, 0.18),
	WoodenBucket = Vector3.new(1.36, 2.03, 1.27),
	WoodenCrate = Vector3.new(1.96, 1.72, 4.32),
	YellowOnion = Vector3.new(0.27, 0.32, 0.25),
	GallineraTable = Vector3.new(3.07, 1.80, 1.92),
	Jug = Vector3.new(1.02, 0.78, 0.62),
	PaintedWoodenSofa = Vector3.new(9.07, 4.74, 2.91),
	PlasticCrate = Vector3.new(1.87, 0.94, 1.50),
	LanternChandelier = Vector3.new(2.14, 3.25, 2.13),
	MetalJug = Vector3.new(0.73, 1.06, 0.72),
	WoodenLadder = Vector3.new(3.66, 6.37, 2.29),
	UtilityBox2 = Vector3.new(3.40, 4.15, 1.60),
	FoldingWoodenStool = Vector3.new(1.95, 1.64, 2.02),
	WornMetalRack = Vector3.new(3.39, 7.03, 2.22),
	SideTableTall = Vector3.new(1.42, 2.82, 1.42),
	LightbulbLed = Vector3.new(0.23, 0.37, 0.23),
	MetalStool = Vector3.new(1.66, 1.70, 1.75),
	MetalStool2 = Vector3.new(1.70, 3.79, 1.74),
	WoodenCrate2 = Vector3.new(3.05, 1.29, 1.51),
	ChineseCommode = Vector3.new(16.61, 7.47, 4.33),
	FoodLychee = Vector3.new(0.15, 0.19, 0.16),
	GardenGloves = Vector3.new(0.84, 0.28, 1.11),
	BrassVase3 = Vector3.new(0.78, 1.96, 0.78),
	FoodApple = Vector3.new(0.36, 0.32, 0.35),
	IndustrialPasticContainer = Vector3.new(1.76, 1.57, 2.34),
	FoodGinger = Vector3.new(0.89, 2.13, 0.55),
	VintageOilLamp = Vector3.new(0.81, 2.97, 0.81),
	WoodenBucket2 = Vector3.new(2.28, 1.30, 2.28),
	SungkaBoard = Vector3.new(0.52, 0.13, 2.22),
	BronzeSharkStatue = Vector3.new(1.30, 1.60, 2.81),
	ClassicConsole = Vector3.new(5.71, 3.51, 2.18),
	FoodAvocado = Vector3.new(0.35, 0.53, 0.35),
	FoodKiwi = Vector3.new(0.26, 0.33, 0.25),
	ChineseChandelier = Vector3.new(3.25, 2.77, 3.25),
	Sofa3 = Vector3.new(10.11, 4.14, 3.42),
	ModernArmChair = Vector3.new(3.04, 3.78, 3.65),
	SteelFrameShelves = Vector3.new(8.70, 8.55, 2.67),
	AlarmClock = Vector3.new(0.49, 0.64, 0.25),
	PlanterBox2 = Vector3.new(4.63, 1.68, 1.73),
	PlanterBox3 = Vector3.new(3.38, 3.16, 2.43),
	SeedingTray = Vector3.new(0.81, 0.22, 0.81),
	WateringCanMetal = Vector3.new(0.71, 0.73, 1.67),
	GardenSprinkler = Vector3.new(1.33, 0.80, 0.92),
	GardenHoseWallMounted = Vector3.new(1.73, 2.06, 0.93),
	WoodenBroom = Vector3.new(1.81, 5.38, 0.42),
	MetalToolbox = Vector3.new(1.48, 1.28, 1.08),
	MetalToolChest = Vector3.new(2.54, 2.41, 1.51),
	HandTruck = Vector3.new(2.20, 5.19, 2.56),
	WoodenLadder2 = Vector3.new(3.55, 4.94, 1.85),
	OutdoorTableChairSet = Vector3.new(2.87, 3.18, 6.77),
	RoundWoodenTable2 = Vector3.new(5.18, 3.72, 5.18),
	BarChairRound = Vector3.new(1.79, 2.78, 1.80),
	Rockingchair = Vector3.new(2.62, 3.68, 3.08),
	GothicCabinet = Vector3.new(6.36, 8.74, 4.18),
	ChineseConsoleTable = Vector3.new(6.36, 2.44, 1.25),
	ModernCoffeeTable2 = Vector3.new(4.44, 1.37, 4.44),
	WoodenStool = Vector3.new(1.57, 1.62, 1.64),
	WoodenStool2 = Vector3.new(0.98, 0.67, 0.68),
	GallineraChair = Vector3.new(2.15, 3.82, 2.23),
	PotEnamel = Vector3.new(0.97, 0.66, 0.67),
	HamburgerBuns = Vector3.new(1.47, 0.23, 0.42),
	CarrotCake = Vector3.new(0.83, 0.36, 0.83),
	FoodPearsAsian = Vector3.new(0.58, 0.41, 0.66),
	FoodPomegranate = Vector3.new(0.42, 0.43, 0.43),
	FoodLime = Vector3.new(0.22, 0.28, 0.23),
	SecurityCamera = Vector3.new(0.63, 1.06, 2.05),
	SecurityCamera2 = Vector3.new(0.52, 0.77, 1.46),
	IndustrialWallSconce = Vector3.new(0.56, 1.26, 0.93),
	IndustrialPipeLamp = Vector3.new(0.68, 1.35, 0.97),
	WoodenLantern = Vector3.new(0.82, 1.96, 0.87),
	BrassDiyaLantern = Vector3.new(0.46, 1.41, 0.46),
	BrassGoblets = Vector3.new(1.68, 1.01, 1.10),
	SeadogsCompass = Vector3.new(0.30, 0.32, 0.56),
	RoundSpectacles = Vector3.new(0.58, 0.17, 0.55),
	FishermansHat = Vector3.new(1.20, 0.46, 1.29),
	Lifebuoy = Vector3.new(2.90, 3.11, 0.57),
	PortableCassettePlayer = Vector3.new(0.64, 0.48, 0.15),
	RetroMultimeter = Vector3.new(0.80, 1.03, 0.75),
	VintageMicrowave = Vector3.new(3.97, 1.95, 2.76),
	VintageElectricKettle = Vector3.new(1.19, 1.13, 0.92),
	Gamepad = Vector3.new(1.49, 0.07, 1.61),
	DigitalWristWatch = Vector3.new(0.14, 0.03, 0.80),
	VintageFlashlight = Vector3.new(0.35, 0.53, 1.13),
	SmallPlasticTorch = Vector3.new(0.37, 0.20, 0.84),
	SignalFlashlight = Vector3.new(0.26, 0.55, 0.16),
	WineBarrel = Vector3.new(2.75, 3.22, 2.80),
	QuartersBed = Vector3.new(2.92, 2.80, 7.51),
	QuartersBedDouble = Vector3.new(4.21, 2.80, 7.51),
	QuartersCloset = Vector3.new(3.25, 8.60, 1.80),
	QuartersLocker = Vector3.new(2.90, 5.40, 2.28),
	QuartersNightstand = Vector3.new(2.81, 2.80, 3.09),
	QuartersDesk = Vector3.new(6.57, 3.60, 3.05),
	HeadmasterChair = Vector3.new(2.94, 4.60, 3.29),
	TallBookcase = Vector3.new(4.20, 8.60, 1.52),
	StockedBookcase = Vector3.new(4.20, 8.60, 1.52),
	LodgeSofa = Vector3.new(9.92, 3.60, 3.82),
	LodgeSofaLong = Vector3.new(9.92, 3.60, 6.94),
	LodgeArmchair = Vector3.new(4.34, 3.60, 3.81),
	LoungeStool = Vector3.new(2.46, 2.80, 2.59),
	RefectoryTable = Vector3.new(5.85, 3.40, 11.47),
	RefectoryTable2 = Vector3.new(5.16, 3.00, 10.12),
	PlainChair = Vector3.new(2.00, 4.20, 2.49),
	CeilingLampBox = Vector3.new(1.18, 2.20, 1.17),
	CeilingLampDisc = Vector3.new(1.58, 2.00, 1.58),
	PendantLamp = Vector3.new(1.88, 3.40, 1.97),
	GrandChandelier = Vector3.new(8.46, 5.40, 8.46),
	Houseplant = Vector3.new(5.79, 5.40, 5.23),
	Houseplant2 = Vector3.new(1.78, 4.40, 1.76),
	Houseplant3 = Vector3.new(7.49, 6.20, 7.73),
	Houseplant4 = Vector3.new(6.35, 4.80, 6.64),
	BunkBed = Vector3.new(6.44, 9.00, 11.87),
	Nightstand2 = Vector3.new(2.82, 2.80, 2.82),
	Fridge = Vector3.new(3.29, 8.40, 3.31),
	Oven = Vector3.new(3.68, 5.00, 3.36),
	KitchenSink = Vector3.new(2.63, 5.00, 2.91),
	KitchenCabinet = Vector3.new(3.23, 5.00, 3.42),
	KitchenDrawers = Vector3.new(3.11, 5.00, 3.45),
	BinLarge = Vector3.new(3.05, 4.60, 3.05),
	BinSmall = Vector3.new(1.98, 2.80, 1.20),
	Toilet = Vector3.new(2.14, 3.40, 3.03),
	Washbasin = Vector3.new(3.07, 3.20, 1.80),
	WashroomMirror = Vector3.new(2.79, 4.00, 0.44),
	WideShelf = Vector3.new(6.09, 8.00, 1.36),
	DiningChair = Vector3.new(1.89, 4.20, 2.08),
	RoundTable = Vector3.new(11.26, 3.40, 5.89),
	RoundTableSmall = Vector3.new(4.74, 2.80, 4.74),
	PaddedStool = Vector3.new(2.46, 2.80, 2.59),
	LoungeCouch = Vector3.new(8.84, 3.60, 4.15),
	ChestOfDrawers = Vector3.new(12.11, 4.60, 3.90),
	Rug = Vector3.new(25.31, 0.30, 26.04),
	RoundRug = Vector3.new(47.52, 0.30, 48.26),
	LodgeFireplace = Vector3.new(10.15, 8.00, 3.62),
	BunkBed2 = Vector3.new(6.05, 9.00, 11.59),
	SingleBed = Vector3.new(3.96, 2.60, 7.80),
	DoubleBed = Vector3.new(6.63, 2.60, 7.80),
	BedsideDrawers = Vector3.new(2.63, 2.60, 2.15),
	OpenBookcase = Vector3.new(3.18, 7.00, 1.99),
	WideBookcase = Vector3.new(7.09, 7.00, 2.22),
	BookStack = Vector3.new(1.74, 1.20, 1.09),
	CoatRack = Vector3.new(2.48, 7.00, 2.48),
	StudyDesk = Vector3.new(5.54, 2.90, 2.96),
	StudyChair = Vector3.new(1.87, 3.40, 1.76),
	SideDrawers = Vector3.new(3.89, 2.80, 1.62),
	TableLamp = Vector3.new(0.97, 2.00, 1.12),
	FloorLamp = Vector3.new(0.89, 6.40, 0.89),
	CommonSofa = Vector3.new(6.39, 3.00, 2.67),
	CommonChair = Vector3.new(3.20, 3.00, 2.67),
	LowTable = Vector3.new(4.60, 1.60, 2.78),
	LongPillow = Vector3.new(1.22, 0.70, 0.28),
	RugRect = Vector3.new(1.57, 0.01, 0.92),
	RugRound2 = Vector3.new(0.92, 0.01, 0.92),
	Bin2 = Vector3.new(1.17, 2.40, 1.31),
	DeskPlant = Vector3.new(1.08, 1.60, 1.08),
	PottedPlant2 = Vector3.new(1.36, 4.20, 1.55),
	Basin2 = Vector3.new(1.94, 3.20, 1.66),
	Mirror2 = Vector3.new(2.36, 3.40, 1.13),
	Toilet2 = Vector3.new(2.36, 3.40, 3.60),
	Shower = Vector3.new(4.11, 8.00, 4.25),
	LaundryStack = Vector3.new(2.74, 6.60, 2.74),
	Stove2 = Vector3.new(3.44, 3.60, 3.60),
	Sink2 = Vector3.new(3.16, 3.60, 3.31),
	Fridge2 = Vector3.new(3.27, 7.00, 2.22),
	StoneWall = Vector3.new(10.69, 14.00, 10.69),
	StoneWallCorner = Vector3.new(10.69, 14.00, 10.69),
	StoneWallGate = Vector3.new(5.34, 14.00, 10.69),
	StonePier = Vector3.new(12.21, 16.00, 12.21),
	PicketFence = Vector3.new(4.34, 6.00, 4.14),
	IronGate = Vector3.new(2.00, 12.00, 8.73),
	StoneSteps = Vector3.new(1.72, 5.00, 6.07),
	Banner = Vector3.new(0.22, 12.00, 3.48),
	FallenLog = Vector3.new(2.34, 2.60, 9.38),
	TowerBase = Vector3.new(15.84, 16.00, 15.84),
	TowerMid = Vector3.new(14.73, 16.00, 14.73),
	TowerTop = Vector3.new(18.52, 20.00, 18.52),
	KTree = Vector3.new(11.49, 26.00, 9.95),
	KTreeOak = Vector3.new(15.67, 30.00, 18.10),
	KTreeTall = Vector3.new(8.05, 34.00, 9.30),
	KTreeThin = Vector3.new(10.96, 24.00, 9.93),
	KPineTall = Vector3.new(9.09, 36.00, 9.22),
	KPineRound = Vector3.new(11.74, 26.00, 13.56),
	KStump = Vector3.new(4.55, 3.40, 4.73),
	KBush = Vector3.new(6.48, 4.00, 6.48),
	KBushLarge = Vector3.new(9.24, 6.00, 8.29),
	KGrass = Vector3.new(3.54, 2.20, 3.53),
	KFlowerRed = Vector3.new(1.09, 2.00, 1.24),
	KFlowerYellow = Vector3.new(1.65, 2.00, 1.88),
	KFlowerPurple = Vector3.new(1.31, 2.00, 1.49),
	KRockLarge = Vector3.new(21.15, 7.00, 27.36),
	KRockTall = Vector3.new(11.85, 12.00, 8.23),
	KRockSmall = Vector3.new(5.66, 3.00, 5.66),
	KFencePlanks = Vector3.new(17.39, 6.00, 1.67),
	KFenceGate = Vector3.new(20.29, 7.00, 1.42),
	KCampfire = Vector3.new(9.32, 2.00, 9.32),
}

end)()
local __CampusPlan = (function()

-- THE DRAWING. Every wall, door, stair and room on the campus, as data.
--
-- Crumbworth High was never drawn before it was built. Every coordinate in
-- MapService was chosen in isolation, months apart, by whoever was adding that
-- feature, which is why the school grew stairs behind walls, lockers across the
-- principal's door, and two signs pointing at each other's rooms. Each of those
-- was found by playing, fixed by hand, and replaced by the next one.
--
-- This file ends that. It is the ONE place the layout lives. MapService is only
-- allowed to RENDER it -- walls from Plan.walls, stairs from Plan.stairs,
-- openings from Plan.doors -- so a wall or a staircase that is not drawn here
-- cannot be built. tools/plan_check.py validates the drawing on its own, in
-- under a second, before a single part exists.
--
-- Axes: +x east, +z north, y up. The Academy's front doors face +z, onto the
-- Great Court. Rects are {x0, z0, x1, z1} with x0 < x1 and z0 < z1, in studs.

local Plan = {}

-- ---------------------------------------------------------------------------
-- THE PLOT
-- ---------------------------------------------------------------------------
-- The core is the built campus. The plot is a little over twice its area, and
-- the difference is held as four cleared, drained, grassed reserves inside the
-- outer wall -- so the next building drops onto ready ground instead of forcing
-- another re-survey of everything already standing.

Plan.PLOT = { -800, -640, 840, 780 } -- 1640 x 1420 = 2,328,800
Plan.CORE = { -560, -420, 590, 560 } -- 1150 x  980 = 1,127,000

Plan.RESERVES = {
	{ name = "North Reserve", rect = { -800, 560, 840, 780 } },
	{ name = "South Reserve", rect = { -800, -640, 840, -420 } },
	{ name = "West Reserve", rect = { -800, -420, -560, 560 } },
	{ name = "East Reserve", rect = { 590, -420, 840, 560 } },
}

-- Nothing may be built in a reserve, and the reserves together must stay at or
-- above this multiple of the core's area, so expansion room cannot be quietly
-- eaten by the next thing somebody wants to put up.
Plan.RESERVE_RATIO = 0.9

-- ---------------------------------------------------------------------------
-- CONSTRUCTION CONSTANTS
-- ---------------------------------------------------------------------------

Plan.EXTERIOR_WALL = 8.0 -- coursed stone, load bearing
Plan.PARTITION = 3.0 -- interior division
Plan.DOOR_WIDTH = 12.0
Plan.DOOR_HEIGHT = 11.0
Plan.GRAND_DOOR_WIDTH = 20.0
Plan.CORRIDOR_CLEAR = 24.0 -- a corridor's middle must stay this clear
Plan.HEADROOM = 9.0 -- floor to the underside of anything above it
Plan.STAIR_RISE = 0.8
Plan.STAIR_TREAD = 1.6
Plan.LANDING = 14.0

-- ---------------------------------------------------------------------------
-- THE SITE
-- ---------------------------------------------------------------------------
-- Every structure on the campus and the ground it stands on. `link` names the
-- structures this one is allowed to touch; anything else that overlaps is a
-- collision the checker rejects.

Plan.SITE = {
	{ name = "Academy", rect = { -224, -124, 224, 124 }, kind = "building" },
	{ name = "Great Court", rect = { -150, 135, 150, 285 }, kind = "grounds", ceremonial = true },
	{ name = "Student Dorms", rect = { -150, -370, 150, -250 }, kind = "building" },
	-- The courtyard between the school's back and the boarding house's front.
	-- 320 x 126 studs of open grass with one walk down the middle of it: the
	-- second-largest empty rectangle on the campus after the Great Court, and
	-- the one every boarder crosses twice a day.
	{ name = "Dorm Court", rect = { -140, -246, 140, -152 }, kind = "grounds" },
	{ name = "Library", rect = { -420, -348, -220, -252 }, kind = "building" },
	{ name = "Cafeteria", rect = { 220, -348, 420, -252 }, kind = "building" },
	{ name = "Detention Hall", rect = { -485, -40, -315, 80 }, kind = "building" },
	{ name = "Parking Lot", rect = { 335, -35, 525, 115 }, kind = "grounds" },
	-- The two painted ball courts. They were built at (-300, -250) and
	-- (300, -250), which the drawing gives to the Library and the Cafeteria --
	-- so a basketball key was painted across the library floor and a
	-- volleyball net stood in the servery. They belong on open ground east of
	-- the Academy, between the car park and the cafeteria.
	{ name = "Ball Courts", rect = { 250, -220, 530, -100 }, kind = "grounds" },
	{ name = "Sports Field", rect = { 300, 150, 580, 320 }, kind = "grounds" },
	{ name = "Gymnasium", rect = { 330, 340, 520, 470 }, kind = "building", link = { "Hidden Alley" } },
	{ name = "Secret Rooftop", rect = { 155, 345, 265, 455 }, kind = "building", link = { "Hidden Alley" } },
	{ name = "Hidden Alley", rect = { 265, 390, 330, 410 }, kind = "grounds", link = { "Gymnasium", "Secret Rooftop" } },
	{ name = "Bike Track", rect = { -550, 230, -310, 430 }, kind = "grounds" },
	{ name = "Main Gate", rect = { -30, 540, 30, 560 }, kind = "grounds", ceremonial = true },
}

-- The ceremonial approach: the axis from the gate to the front doors. Nothing
-- back-of-house (bins, sheds, courts, goalposts, skips) may stand on it.
Plan.APPROACH = { -150, 124, 150, 575 }

-- ---------------------------------------------------------------------------
-- THE ACADEMY
-- ---------------------------------------------------------------------------
-- Drawn as a grid rather than as a list of rooms, because a grid is the one
-- form in which "every room opens onto a corridor" is true BY CONSTRUCTION
-- instead of true by inspection. The bands below cut the interior into cells;
-- two columns and two rows are corridor, and every remaining cell touches at
-- least one of them on a full face. There is no way to draw a landlocked room.
--
--   columns  1 W0 | 2 corridor | 3 W1 | 4 CENTRE | 5 E1 | 6 corridor | 7 E0
--   rows     1 rear | 2 corridor | 3 middle | 4 corridor | 5 front
--
-- Row 5 is the front range, facing the Great Court. Row 1 backs onto the dorms.

local ACADEMY_X = { -216, -152, -120, -56, 56, 120, 152, 216 }
local ACADEMY_Z = { -116, -52, -20, 44, 76, 116 }

Plan.BUILDINGS = {
	{
		name = "Academy",
		rect = { -224, -124, 224, 124 },
		facing = "north", -- +z
		grid = { x = ACADEMY_X, z = ACADEMY_Z, corridorCols = { 2, 6 }, corridorRows = { 2, 4 } },
		storeys = {
			{ y = 0.0, height = 16.0, name = "Ground" },
			{ y = 16.0, height = 16.0, name = "Upper" },
			{ y = 32.0, height = 15.0, name = "Top", inRoof = true },
		},
		-- cells[storey][row][col]. false = not a room on this storey (roof void,
		-- or the open well of a double-height space below).
		cells = {
			{ -- Ground
				{ "Art room", false, "Chemistry lab", "Assembly hall", "Computer lab", false, "History room" },
				{},
				{ "Science lab", false, "Music room", "Atrium", "Room 101", false, "Maths room" },
				{},
				{ "Infirmary", false, "Reception", "Entrance hall", "Trophy hall", false, "Principal's office" },
			},
			{ -- Upper
				{ "Homeroom 2C", false, "Homeroom 2D", "Assembly gallery", "Homeroom 2E", false, "Homeroom 2F" },
				{},
				{ "Physics lab", false, "Biology lab", "Great stair", "Homeroom 2A", false, "Homeroom 2B" },
				{},
				{ "Art studio", false, "Language room", false, "Staff room", false, "Geography room" },
			},
			{ -- Top: inside the roof, so only the front range and the stair head
				{ false, false, false, false, false, false, false },
				{},
				{ false, false, false, "Great stair head", false, false, false },
				{},
				{ "Records room", false, "Secretary's office", "Headmaster's office", "Waiting room", false, "Board room" },
			},
		},
		-- Which corridors exist on which storey. The top floor is under the roof
		-- slope, so only the front corridor runs up there.
		storeyCorridors = {
			{ cols = { 2, 6 }, rows = { 2, 4 } },
			{ cols = { 2, 6 }, rows = { 2, 4 } },
			{ cols = {}, rows = { 4 } },
		},
		-- Rooms that rise through more than one storey. The cell above one of
		-- these is false, and the checker knows that is deliberate rather than a
		-- floor with a hole in it.
		doubleHeight = {
			-- the entrance hall is two storeys tall, so the cell above it is
			-- deliberately empty rather than a floor with a hole in it
			{ storey = 1, row = 5, col = 4, storeys = 2 },
		},
		-- Every stair, drawn: where it starts, where it lands, how wide, and
		-- which cell it lives in. Nothing else may occupy the run.
		-- Every stair, drawn as flights. A flight's horizontal run has to cover
		-- its own rise at the going below, and consecutive flights have to meet
		-- on a landing -- which is checked, not assumed. Both stairs stand in
		-- the Atrium cell (112 x 64) side by side in x rather than stacked in z,
		-- because two U-flights and their landings need 46 studs of depth each
		-- and the cell only has 64.
		stairs = {
			{
				name = "Great stair",
				cell = { row = 3, col = 4 },
				width = 18.0,
				flights = {
					{ from = { -38, 0.0, 40 }, to = { -38, 8.0, 24 } },
					{ from = { -20, 8.0, 6 }, to = { -20, 16.0, -10 } },
				},
				landings = { { y = 8.0, rect = { -47, 6, -11, 24 } } },
			},
			{
				name = "Tower stair",
				cell = { row = 3, col = 4 },
				width = 18.0,
				flights = {
					{ from = { 20, 16.0, 40 }, to = { 20, 24.0, 24 } },
					{ from = { 38, 24.0, 6 }, to = { 38, 32.0, -10 } },
				},
				landings = { { y = 24.0, rect = { 11, 6, 47, 24 } } },
			},
		},
		-- The tower stands on the axis over the front range and carries the
		-- clock and the spire. It is not a room; it is a mass.
		tower = { x = 0, z = 96, width = 44, top = 118, spire = 44 },
		-- Ways in from outside, on the outer face of the named wall.
		entrances = {
			{ name = "Front doors", at = { x = 0, z = 124 }, facing = "north", width = 20.0, grand = true },
			{ name = "West door", at = { x = -224, z = -36 }, facing = "west", width = 12.0 },
			{ name = "East door", at = { x = 224, z = -36 }, facing = "east", width = 12.0 },
			{ name = "Rear doors", at = { x = 0, z = -124 }, facing = "south", width = 16.0 },
		},
	},
	{
		name = "Student Dorms",
		rect = { -150, -370, 150, -250 },
		facing = "north",
		grid = {
			x = { -142, -86, -30, 30, 86, 142 },
			z = { -362, -326, -294, -258 },
			corridorCols = {},
			corridorRows = { 2 },
		},
		storeys = {
			{ y = 0.0, height = 15.0, name = "Ground" },
			{ y = 15.0, height = 15.0, name = "Upper", inRoof = true },
		},
		cells = {
			{
				{ "Dorm 1", "Dorm 2", "Common room", "Dorm 3", "Dorm 4" },
				{},
				{ "Warden's flat", "Dorm 5", "Dorm lobby", "Dorm 6", "Laundry" },
			},
			{
				{ "Dorm 7", "Dorm 8", "Study", "Dorm 9", "Dorm 10" },
				{},
				{ "Dorm 11", "Dorm 12", "Upper landing", "Dorm 13", "Dorm 14" },
			},
		},
		storeyCorridors = { { cols = {}, rows = { 2 } }, { cols = {}, rows = { 2 } } },
		stairs = {
			{
				name = "Dorm stair",
				cell = { row = 3, col = 3 },
				width = 14.0,
				flights = {
					{ from = { -20, 0.0, -266 }, to = { -4, 8.0, -266 } },
					{ from = { -4, 8.0, -282 }, to = { -20, 15.0, -282 } },
				},
				-- The landing is at the TURN, past the head of the lower
				-- flight -- not over it. Drawn as (-21, -289) to (-3, -259) it
				-- covered the whole of the lower flight's footprint, so the
				-- flight climbed into the underside of its own landing.
				landings = { { y = 8.0, rect = { -4, -290, 10, -258 } } },
			},
		},
		entrances = {
			{ name = "Dorm doors", at = { x = 0, z = -250 }, facing = "north", width = 14.0 },
			{ name = "Dorm rear door", at = { x = 0, z = -370 }, facing = "south", width = 12.0 },
		},
	},
	{
		name = "Library",
		rect = { -420, -348, -220, -252 },
		facing = "north",
		grid = {
			x = { -412, -336, -304, -228 },
			z = { -340, -300, -260 },
			corridorCols = { 2 },
			corridorRows = {},
		},
		storeys = { { y = 0.0, height = 22.0, name = "Ground" } },
		cells = {
			{
				{ "Stacks west", false, "Stacks east" },
				{ "Reading room", false, "Archive" },
			},
		},
		storeyCorridors = { { cols = { 2 }, rows = {} } },
		stairs = {},
		entrances = {
			{ name = "Library doors", at = { x = -320, z = -252 }, facing = "north", width = 14.0 },
		},
	},
	{
		name = "Cafeteria",
		rect = { 220, -348, 420, -252 },
		facing = "north",
		grid = {
			x = { 228, 300, 332, 412 },
			z = { -340, -300, -260 },
			corridorCols = { 2 },
			corridorRows = {},
		},
		storeys = { { y = 0.0, height = 20.0, name = "Ground" } },
		cells = {
			{
				{ "Kitchen", false, "Dining hall" },
				{ "Servery", false, "Dining hall" },
			},
		},
		storeyCorridors = { { cols = { 2 }, rows = {} } },
		stairs = {},
		entrances = {
			{ name = "Cafeteria doors", at = { x = 316, z = -252 }, facing = "north", width = 16.0 },
		},
	},
	{
		name = "Detention Hall",
		rect = { -485, -40, -315, 80 },
		facing = "east",
		grid = {
			x = { -477, -400, -323 },
			z = { -32, 4, 36, 72 },
			corridorCols = {},
			corridorRows = { 2 },
		},
		storeys = { { y = 0.0, height = 18.0, name = "Ground" } },
		cells = {
			{
				{ "Detention hall", "Holding room" },
				{},
				{ "Warden's office", "Confiscation store" },
			},
		},
		storeyCorridors = { { cols = {}, rows = { 2 } } },
		stairs = {},
		entrances = {
			{ name = "Detention doors", at = { x = -315, z = 20 }, facing = "east", width = 14.0 },
		},
	},
	{
		name = "Gymnasium",
		rect = { 330, 340, 520, 470 },
		facing = "west",
		grid = {
			x = { 338, 512 },
			z = { 348, 380, 412, 462 },
			corridorCols = {},
			corridorRows = { 2 },
		},
		storeys = { { y = 0.0, height = 26.0, name = "Ground" } },
		cells = {
			{
				{ "Changing rooms" },
				{},
				{ "Sports hall" },
			},
		},
		storeyCorridors = { { cols = {}, rows = { 2 } } },
		stairs = {},
		entrances = {
			{ name = "Gym doors", at = { x = 330, z = 396 }, facing = "west", width = 16.0 },
		},
	},
	{
		name = "Secret Rooftop",
		rect = { 155, 345, 265, 455 },
		facing = "east",
		grid = {
			x = { 163, 210, 257 },
			z = { 353, 385, 417, 447 },
			corridorCols = {},
			corridorRows = { 2 },
		},
		storeys = { { y = 0.0, height = 16.0, name = "Ground" } },
		cells = {
			{
				{ "Boiler room", "Store" },
				{},
				{ "Stairwell", "Roof access" },
			},
		},
		storeyCorridors = { { cols = {}, rows = { 2 } } },
		stairs = {},
		entrances = {
			{ name = "Alley door", at = { x = 265, z = 400 }, facing = "east", width = 12.0 },
		},
	},
}

-- ---------------------------------------------------------------------------
-- DERIVATION
-- ---------------------------------------------------------------------------
-- The grid above is the authored drawing; everything below is read off it. A
-- room's rect, its corridor, and the door between them are all computed, so
-- they cannot disagree with each other the way hand-typed numbers do.

export type Rect = { number }

local function isIn(list: { number }, value: number): boolean
	for _, v in list do
		if v == value then
			return true
		end
	end
	return false
end

-- Every cell of a building's grid, as a rect with its row/col and what it is.
function Plan.cells(b, storey: number)
	local gx, gz = b.grid.x, b.grid.z
	local corridors = b.storeyCorridors[storey]
	local out = {}
	for row = 1, #gz - 1 do
		for col = 1, #gx - 1 do
			local isCorridor = isIn(corridors.cols, col) or isIn(corridors.rows, row)
			local named = b.cells[storey][row] and b.cells[storey][row][col]
			if isCorridor or named then
				table.insert(out, {
					row = row,
					col = col,
					rect = { gx[col], gz[row], gx[col + 1], gz[row + 1] },
					kind = if isCorridor then "corridor" else "room",
					name = if isCorridor then string.format("Corridor r%dc%d", row, col) else named,
				})
			end
		end
	end
	return out
end

-- Rooms only, in build order.
function Plan.rooms(b, storey: number)
	local out = {}
	for _, cell in Plan.cells(b, storey) do
		if cell.kind == "room" then
			table.insert(out, cell)
		end
	end
	return out
end

-- Which corridor cell a room opens onto, and the door between them. Preference
-- is a corridor ROW (a door in the room's front or back wall) before a corridor
-- COLUMN, because a corridor row is the spine and that is where a school's
-- classroom doors belong.
function Plan.doors(b, storey: number)
	local gx, gz = b.grid.x, b.grid.z
	local corridors = b.storeyCorridors[storey]
	local out = {}
	for _, room in Plan.rooms(b, storey) do
		local r, c = room.row, room.col
		local door = nil
		if isIn(corridors.rows, r + 1) then
			door = { x = (gx[c] + gx[c + 1]) / 2, z = gz[r + 1], axis = "z" }
		elseif isIn(corridors.rows, r - 1) then
			door = { x = (gx[c] + gx[c + 1]) / 2, z = gz[r], axis = "z" }
		elseif isIn(corridors.cols, c + 1) then
			door = { x = gx[c + 1], z = (gz[r] + gz[r + 1]) / 2, axis = "x" }
		elseif isIn(corridors.cols, c - 1) then
			door = { x = gx[c], z = (gz[r] + gz[r + 1]) / 2, axis = "x" }
		end
		if door then
			table.insert(out, {
				room = room.name,
				row = r,
				col = c,
				x = door.x,
				z = door.z,
				axis = door.axis,
				width = Plan.DOOR_WIDTH,
				height = Plan.DOOR_HEIGHT,
			})
		else
			-- left in deliberately: plan_check reports it as a landlocked room
			table.insert(out, { room = room.name, row = r, col = c, orphan = true })
		end
	end
	return out
end

-- Every wall the building needs on a storey: the exterior envelope, then one
-- partition on each internal grid line that actually divides two occupied
-- cells. A grid line with nothing on one side of it gets no wall, which is why
-- the top floor does not sprout partitions inside its own roof void.
function Plan.walls(b, storey: number)
	local gx, gz = b.grid.x, b.grid.z
	local out = {}
	local occupied = {}
	for _, cell in Plan.cells(b, storey) do
		occupied[cell.row * 100 + cell.col] = cell
	end
	local function at(row: number, col: number)
		return occupied[row * 100 + col]
	end

	local x0, z0, x1, z1 = b.rect[1], b.rect[2], b.rect[3], b.rect[4]
	local t = Plan.EXTERIOR_WALL
	table.insert(out, { from = { x0, z0 }, to = { x1, z0 }, thickness = t, kind = "exterior", storey = storey })
	table.insert(out, { from = { x0, z1 }, to = { x1, z1 }, thickness = t, kind = "exterior", storey = storey })
	table.insert(out, { from = { x0, z0 }, to = { x0, z1 }, thickness = t, kind = "exterior", storey = storey })
	table.insert(out, { from = { x1, z0 }, to = { x1, z1 }, thickness = t, kind = "exterior", storey = storey })

	for col = 2, #gx - 1 do
		for row = 1, #gz - 1 do
			local a, c = at(row, col - 1), at(row, col)
			-- Two cells with the same name are one room drawn in two pieces --
			-- a dining hall, a sports hall -- so no wall goes between them.
			if a and c and a.name ~= c.name and not (a.kind == "corridor" and c.kind == "corridor") then
				table.insert(out, {
					from = { gx[col], gz[row] },
					to = { gx[col], gz[row + 1] },
					thickness = Plan.PARTITION,
					kind = "partition",
					storey = storey,
				})
			end
		end
	end
	for row = 2, #gz - 1 do
		for col = 1, #gx - 1 do
			local a, c = at(row - 1, col), at(row, col)
			if a and c and a.name ~= c.name and not (a.kind == "corridor" and c.kind == "corridor") then
				table.insert(out, {
					from = { gx[col], gz[row] },
					to = { gx[col + 1], gz[row] },
					thickness = Plan.PARTITION,
					kind = "partition",
					storey = storey,
				})
			end
		end
	end
	return out
end

-- The site rect a name is drawn on, so a builder can take its extent from the
-- drawing instead of holding its own copy of the numbers. The Great Court was
-- drawn 300 x 150 at (0, 210) and built 280 x 84 at (0, 166): the fountain
-- landed on the entrance steps and the court's paths crossed the approach at
-- the wrong place, because nothing made the builder read what was drawn.
function Plan.site(name: string)
	for _, s in Plan.SITE do
		if s.name == name then
			return s
		end
	end
	return nil
end

function Plan.building(name: string)
	for _, b in Plan.BUILDINGS do
		if b.name == name then
			return b
		end
	end
	return nil
end

return Plan

end)()
local __Kit = (function()

-- The vocabulary every building on this campus is assembled from.
--
-- The reference buildings look like each other because they ARE each other:
-- the same steep slate roof, the same gabled dormers, the same stone spire,
-- the same chimney, repeated at different sizes. Until now every building here
-- grew its own version of each of those inline, which is why the dorms, the
-- quarters and the school all read as different games.
--
-- Everything here takes a `part` maker and a `tag` function from the caller
-- rather than requiring MapService, so the kit stays a leaf: MapService owns
-- how a part gets made, the kit owns what shape the school is.

local CollegiateKit = {}

export type Maker = (props: { [string]: any }) -> BasePart
export type Tagger = (part: Instance, tag: string) -> ()

export type Ctx = {
	parent: Instance,
	part: Maker,
	tag: Tagger,
}

-- The palette, once. Nothing in the kit picks a colour inline.
CollegiateKit.SLATE = Color3.fromRGB(90, 100, 114)
CollegiateKit.RIDGE = Color3.fromRGB(74, 82, 94)
CollegiateKit.STONE = Color3.fromRGB(138, 128, 114)
CollegiateKit.ASHLAR = Color3.fromRGB(201, 191, 169)
CollegiateKit.FRAME = Color3.fromRGB(42, 42, 40)
CollegiateKit.GLASS_LIT = Color3.fromRGB(255, 196, 107)
CollegiateKit.TIMBER = Color3.fromRGB(107, 74, 46)
CollegiateKit.IRON = Color3.fromRGB(28, 28, 32)
CollegiateKit.LANTERN = Color3.fromRGB(255, 220, 160)

local function wedge(ctx: Ctx, name: string, size: Vector3, cf: CFrame, colour: Color3, tagName: string?)
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = colour
	w.Material = Enum.Material.Slate
	w.Parent = ctx.parent
	if tagName then
		ctx.tag(w, tagName)
	end
	return w
end

-- ---------------------------------------------------------------------------
-- SPIRE
-- ---------------------------------------------------------------------------
-- Four corner wedges, each filling one quadrant of the base with its apex over
-- the corner nearest the middle, so the four apexes meet at a single point.
--
-- A CornerWedgePart's apex stands over its own (-x, -z) corner. Under a yaw of
-- theta that corner direction (-1, -1) maps to (-cos + -sin, sin - cos), which
-- gives 0 degrees for the (+x, +z) quadrant and then ninety at a time round the
-- other three. Getting this wrong puts four apexes on the OUTSIDE corners and
-- builds a crown instead of a spire.
function CollegiateKit.spire(ctx: Ctx, o: { x: number, z: number, base: number, width: number, height: number, colour: Color3? })
	local half = o.width / 4
	local colour = o.colour or CollegiateKit.SLATE
	for _, q in {
		{ dx = 1, dz = 1, yaw = 0 },
		{ dx = 1, dz = -1, yaw = 90 },
		{ dx = -1, dz = -1, yaw = 180 },
		{ dx = -1, dz = 1, yaw = 270 },
	} do
		local c = Instance.new("CornerWedgePart")
		c.Name = "SpireFace"
		c.Anchored = true
		c.CanCollide = false
		c.Size = Vector3.new(o.width / 2, o.height, o.width / 2)
		c.CFrame = CFrame.new(o.x + q.dx * half, o.base + o.height / 2, o.z + q.dz * half)
			* CFrame.Angles(0, math.rad(q.yaw), 0)
		c.Color = colour
		c.Material = Enum.Material.Slate
		c.Parent = ctx.parent
		ctx.tag(c, "TexSlateRoof")
	end
	-- the finial: a stone ball on an iron rod, which is the thing that reads
	-- against the sky from the far side of the grounds
	ctx.part({ Name = "SpireRod", Size = Vector3.new(0.5, o.height * 0.16, 0.5), CFrame = CFrame.new(o.x, o.base + o.height + o.height * 0.08, o.z), Color = CollegiateKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "SpireFinial", Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(o.x, o.base + o.height + o.height * 0.18, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Shape = Enum.PartType.Ball, Parent = ctx.parent }).CanCollide = false
end

-- ---------------------------------------------------------------------------
-- GABLE ROOF
-- ---------------------------------------------------------------------------
-- Two slate planes, a ridge capping along the top, a verge board down each
-- gable end and an eaves board along each side. The boards are what stop a
-- pitched roof reading as two triangles leaning together.
function CollegiateKit.gableRoof(ctx: Ctx, o: { x: number, z: number, width: number, depth: number, eaves: number, rise: number, runsX: boolean? })
	local runsX = o.runsX ~= false -- the ridge runs along x by default
	local w = if runsX then o.width else o.depth
	local d = if runsX then o.depth else o.width
	for _, side in { -1, 1 } do
		local piece = Instance.new("WedgePart")
		piece.Name = "RoofPlane"
		piece.Anchored = true
		piece.CanCollide = true
		piece.Size = Vector3.new(w, o.rise, d / 2)
		piece.CFrame = CFrame.new(o.x, o.eaves + o.rise / 2, o.z + side * d / 4)
			* CFrame.Angles(0, if side > 0 then 0 else math.rad(180), 0)
		if not runsX then
			piece.CFrame = CFrame.new(o.x + side * d / 4, o.eaves + o.rise / 2, o.z)
				* CFrame.Angles(0, math.rad(if side > 0 then 90 else 270), 0)
		end
		piece.Color = CollegiateKit.SLATE
		piece.Material = Enum.Material.Slate
		piece.Parent = ctx.parent
		ctx.tag(piece, "TexSlateRoof")
	end
	-- ridge capping
	local ridgeSize = if runsX then Vector3.new(w + 1.2, 1.1, 1.6) else Vector3.new(1.6, 1.1, w + 1.2)
	ctx.part({ Name = "RoofRidge", Size = ridgeSize, CFrame = CFrame.new(o.x, o.eaves + o.rise + 0.4, o.z), Color = CollegiateKit.RIDGE, Material = Enum.Material.Slate, Parent = ctx.parent }).CanCollide = false
	-- eaves board along both long sides
	for _, side in { -1, 1 } do
		local size = if runsX then Vector3.new(w + 2.4, 1.3, 1.1) else Vector3.new(1.1, 1.3, w + 2.4)
		local at = if runsX then CFrame.new(o.x, o.eaves - 0.4, o.z + side * d / 2) else CFrame.new(o.x + side * d / 2, o.eaves - 0.4, o.z)
		ctx.tag(ctx.part({ Name = "RoofEaves", Size = size, CFrame = at, Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- DORMER
-- ---------------------------------------------------------------------------
-- A gabled window standing out of a roof slope: two cheeks, a face, a lit pane
-- in a stone surround, its own little roof and a finial on the point. Ten
-- pieces, because a dormer that is one box with a light in it is the exact
-- thing the asset audit exists to catch.
function CollegiateKit.dormer(ctx: Ctx, o: { x: number, y: number, z: number, facing: number, width: number?, height: number? })
	local w = o.width or 7
	local h = o.height or 8
	local yaw = CFrame.Angles(0, math.rad(o.facing), 0)
	local at = CFrame.new(o.x, o.y, o.z) * yaw

	for _, side in { -1, 1 } do
		ctx.tag(ctx.part({ Name = "DormerCheek", Size = Vector3.new(0.9, h, 6.5), CFrame = at * CFrame.new(side * (w / 2 - 0.45), h / 2, -0.6), Color = CollegiateKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	end
	ctx.tag(ctx.part({ Name = "DormerFace", Size = Vector3.new(w, h, 0.9), CFrame = at * CFrame.new(0, h / 2, 2.4), Color = CollegiateKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.tag(ctx.part({ Name = "DormerSurround", Size = Vector3.new(w - 1.4, h - 2.2, 1.2), CFrame = at * CFrame.new(0, h / 2 + 0.3, 2.5), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	local pane = ctx.part({ Name = "DormerGlass", Size = Vector3.new(w - 3, h - 4, 0.5), CFrame = at * CFrame.new(0, h / 2 + 0.3, 2.9), Color = CollegiateKit.GLASS_LIT, Material = Enum.Material.Neon, Transparency = 0.08, Parent = ctx.parent })
	pane.CanCollide = false
	pane.CastShadow = false
	ctx.part({ Name = "DormerMullion", Size = Vector3.new(0.35, h - 4, 0.6), CFrame = at * CFrame.new(0, h / 2 + 0.3, 3.05), Color = CollegiateKit.FRAME, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "DormerSill", Size = Vector3.new(w + 0.8, 0.6, 2.0), CFrame = at * CFrame.new(0, 2.2, 2.6), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = CollegiateKit.LANTERN
	light.Brightness = 1.2
	light.Range = 20
	light.Shadows = false
	light.Parent = pane

	-- Its own gable, with the ridge running front to back.
	--
	-- This was 90 degrees out and it showed: a WedgePart's tall face is at its
	-- local -Z, so under a yaw of 90 its LENGTH becomes the world Z extent and
	-- its depth becomes the world X extent. Sized as though the length were
	-- still across the front, the two halves splayed outward like wings with a
	-- gap between them and the finial floating over the gap. Five of these sat
	-- on the roof looking like lanterns hung in mid-air.
	--
	-- Under yaw 90 the local +Z axis maps to world +X, so that half slopes out
	-- to +X with its tall face on the ridge at the centre; yaw 270 mirrors it.
	local RISE = 3.4
	local OVERHANG = 1.0
	local halfSpan = w / 2 + OVERHANG
	local roofDepth = 7.6
	for _, side in { -1, 1 } do
		local piece = Instance.new("WedgePart")
		piece.Name = "DormerRoof"
		piece.Anchored = true
		piece.CanCollide = false
		piece.Size = Vector3.new(roofDepth, RISE, halfSpan)
		piece.CFrame = at * CFrame.new(side * halfSpan / 2, h + RISE / 2, -0.2)
			* CFrame.Angles(0, math.rad(if side > 0 then 90 else 270), 0)
		piece.Color = CollegiateKit.SLATE
		piece.Material = Enum.Material.Slate
		piece.Parent = ctx.parent
		ctx.tag(piece, "TexSlateRoof")
	end
	ctx.part({ Name = "DormerRidge", Size = Vector3.new(1.1, 0.8, roofDepth + 0.6), CFrame = at * CFrame.new(0, h + RISE + 0.3, -0.2), Color = CollegiateKit.RIDGE, Material = Enum.Material.Slate, Parent = ctx.parent }).CanCollide = false
	-- the verge board on the gable end that faces the court
	ctx.tag(ctx.part({ Name = "DormerVerge", Size = Vector3.new(w + 2.6, 1.0, 0.9), CFrame = at * CFrame.new(0, h + 0.4, 3.4), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	ctx.part({ Name = "DormerFinial", Size = Vector3.new(0.4, 2.0, 0.4), CFrame = at * CFrame.new(0, h + RISE + 1.2, 2.9), Color = CollegiateKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
end

-- ---------------------------------------------------------------------------
-- CHIMNEY
-- ---------------------------------------------------------------------------
function CollegiateKit.chimney(ctx: Ctx, o: { x: number, z: number, base: number, height: number, width: number? })
	local w = o.width or 6
	ctx.tag(ctx.part({ Name = "ChimneyStack", Size = Vector3.new(w, o.height, w), CFrame = CFrame.new(o.x, o.base + o.height / 2, o.z), Color = CollegiateKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.tag(ctx.part({ Name = "ChimneyBand", Size = Vector3.new(w + 1.0, 0.8, w + 1.0), CFrame = CFrame.new(o.x, o.base + o.height * 0.62, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	ctx.tag(ctx.part({ Name = "ChimneyCap", Size = Vector3.new(w + 1.8, 1.2, w + 1.8), CFrame = CFrame.new(o.x, o.base + o.height + 0.6, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	for _, dx in { -1, 1 } do
		ctx.part({ Name = "ChimneyPot", Size = Vector3.new(1.5, 3.0, 1.5), CFrame = CFrame.new(o.x + dx * w * 0.24, o.base + o.height + 2.7, o.z), Color = Color3.fromRGB(150, 96, 70), Material = Enum.Material.Brick, Shape = Enum.PartType.Cylinder, Parent = ctx.parent }).CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- PINNACLE
-- ---------------------------------------------------------------------------
-- The little stone spike on a corner or a buttress. Six pieces.
function CollegiateKit.pinnacle(ctx: Ctx, o: { x: number, z: number, base: number, height: number? })
	local h = o.height or 12
	ctx.tag(ctx.part({ Name = "PinnaclePlinth", Size = Vector3.new(3.4, 1.2, 3.4), CFrame = CFrame.new(o.x, o.base + 0.6, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	ctx.tag(ctx.part({ Name = "PinnacleShaft", Size = Vector3.new(2.4, h * 0.55, 2.4), CFrame = CFrame.new(o.x, o.base + 1.2 + h * 0.275, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	ctx.tag(ctx.part({ Name = "PinnacleCornice", Size = Vector3.new(3.2, 0.7, 3.2), CFrame = CFrame.new(o.x, o.base + 1.2 + h * 0.55 + 0.35, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	CollegiateKit.spire(ctx, { x = o.x, z = o.z, base = o.base + 1.2 + h * 0.55 + 0.7, width = 3.0, height = h * 0.42, colour = CollegiateKit.ASHLAR })
end

-- ---------------------------------------------------------------------------
-- POINTED ARCH
-- ---------------------------------------------------------------------------
-- A real two-centred gothic arch, cut into voussoirs, because the alternative
-- everywhere in this repo so far has been a rectangle with a triangle on top.
--
-- Each half is a circular arc springing horizontally and meeting its twin at a
-- point. For a span S and a rise R the centre sits c = (R^2 - S^2/4) / S to the
-- FAR side of the springing, which gives radius S/2 + c and puts the apex
-- exactly on both arcs. Set c to zero and you get a semicircle -- a Roman arch,
-- the wrong century.
function CollegiateKit.pointedArch(ctx: Ctx, o: { x: number, y: number, z: number, span: number, rise: number, depth: number, ring: number?, segments: number?, colour: Color3?, tagName: string?, yaw: number? })
	local ring = o.ring or 2.2
	local n = o.segments or 9
	local colour = o.colour or CollegiateKit.ASHLAR
	local tagName = o.tagName or "TexAshlar"
	-- An arch on a wall that faces east or west has to be turned to face it.
	-- Without this the only way to place one on a side elevation was to swap
	-- the x and z arguments, which does not rotate the arch -- it moves it to
	-- a completely different place on the map. Every side entrance PlanBuilder
	-- built had its arch somewhere else entirely.
	local yaw = CFrame.Angles(0, o.yaw or 0, 0)
	local anchor = CFrame.new(o.x, 0, o.z) * yaw
	local halfSpan = o.span / 2
	local c = (o.rise * o.rise - halfSpan * halfSpan) / o.span
	local radius = halfSpan + c
	local sweep = math.atan2(o.rise, c)

	for _, side in { -1, 1 } do
		for i = 0, n - 1 do
			local a0 = sweep * (i / n)
			local a1 = sweep * ((i + 1) / n)
			local mid = (a0 + a1) / 2
			local segLen = radius * (a1 - a0) * 1.08
			local px = side * radius * math.cos(mid) - side * c
			local py = o.y + radius * math.sin(mid)
			local block = ctx.part({
				Name = "ArchVoussoir",
				Size = Vector3.new(ring, segLen, o.depth),
				CFrame = anchor * CFrame.new(px, py, 0) * CFrame.Angles(0, 0, side * mid),
				Color = colour,
				Material = Enum.Material.Concrete,
				Parent = ctx.parent,
			})
			block.CanCollide = false
			ctx.tag(block, tagName)
		end
	end
	-- the springer each side and the apex block, which are the pieces that make
	-- an arch look built rather than drawn
	for _, side in { -1, 1 } do
		ctx.tag(ctx.part({ Name = "ArchSpringer", Size = Vector3.new(ring + 1.4, 1.6, o.depth + 0.6), CFrame = anchor * CFrame.new(side * halfSpan, o.y - 0.4, 0), Color = colour, Material = Enum.Material.Concrete, Parent = ctx.parent }), tagName).CanCollide = false
	end
	ctx.tag(ctx.part({ Name = "ArchApex", Size = Vector3.new(2.6, 3.0, o.depth + 0.6), CFrame = anchor * CFrame.new(0, o.y + o.rise + 0.6, 0), Color = colour, Material = Enum.Material.Concrete, Parent = ctx.parent }), tagName).CanCollide = false
end

-- ---------------------------------------------------------------------------
-- BUTTRESS
-- ---------------------------------------------------------------------------
-- A stepped pier standing off a wall, narrowing at each set-off and finished
-- with a weathering slope. This is what carries a gothic elevation; round
-- classical columns say a different building entirely.
function CollegiateKit.buttress(ctx: Ctx, o: { x: number, z: number, base: number, height: number, width: number?, depth: number?, stages: number? })
	local w = o.width or 6
	local d = o.depth or 7
	local stages = o.stages or 3
	local each = o.height / stages
	for i = 0, stages - 1 do
		local shrink = i * 0.9
		ctx.tag(ctx.part({
			Name = "ButtressStage",
			Size = Vector3.new(w - shrink, each, d - shrink),
			CFrame = CFrame.new(o.x, o.base + each * (i + 0.5), o.z),
			Color = CollegiateKit.STONE,
			Material = Enum.Material.Slate,
			Parent = ctx.parent,
		}), "TexCoursedStone")
		ctx.tag(ctx.part({
			Name = "ButtressSetOff",
			Size = Vector3.new(w - shrink + 1.0, 0.8, d - shrink + 1.0),
			CFrame = CFrame.new(o.x, o.base + each * (i + 1) - 0.4, o.z),
			Color = CollegiateKit.ASHLAR,
			Material = Enum.Material.Concrete,
			Parent = ctx.parent,
		}), "TexAshlar").CanCollide = false
	end
	-- the weathering: a wedge shedding water back to the wall
	local cap = Instance.new("WedgePart")
	cap.Name = "ButtressWeathering"
	cap.Anchored = true
	cap.CanCollide = false
	cap.Size = Vector3.new(w - (stages - 1) * 0.9 + 1.0, 3.4, d - (stages - 1) * 0.9 + 1.0)
	cap.CFrame = CFrame.new(o.x, o.base + o.height + 1.7, o.z) * CFrame.Angles(0, math.rad(180), 0)
	cap.Color = CollegiateKit.ASHLAR
	cap.Material = Enum.Material.Concrete
	cap.Parent = ctx.parent
	ctx.tag(cap, "TexAshlar")
end

return CollegiateKit

end)()
local __Grounds = (function()

-- The vocabulary the grounds are assembled from.
--
-- Everything outdoors used to be written inline at its call site, so a fountain
-- was three cylinders on a stem, a parterre was a brown rectangle with a green
-- cross painted on it, and a bench was two boxes. That is the "basic shapes
-- that look like objects" problem: the shapes are right and the object is not
-- there. Each builder here puts down the parts a real one is made of --
-- coping, kerb, plinth, moulding, standard, jet -- and every one of them
-- clears tools/asset_audit.py's bar on its own.
--
-- Geometry comes from the caller as a rect or a centre and a radius, and the
-- caller gets its numbers from CampusPlan. Nothing here invents a coordinate.

local GroundsKit = {}

export type Ctx = {
	parent: Instance,
	part: (props: { [string]: any }) -> BasePart,
	tag: (p: BasePart, tagName: string) -> BasePart,
	prop: ((kind: string, cf: CFrame, options: any?) -> ())?,
}

GroundsKit.STONE = Color3.fromRGB(183, 174, 158)
GroundsKit.STONE_PALE = Color3.fromRGB(206, 200, 186)
GroundsKit.STONE_DEEP = Color3.fromRGB(150, 142, 128)
GroundsKit.WATER = Color3.fromRGB(120, 176, 200)
GroundsKit.HEDGE = Color3.fromRGB(47, 90, 52)
GroundsKit.HEDGE_DEEP = Color3.fromRGB(34, 68, 38)
GroundsKit.YEW = Color3.fromRGB(38, 74, 46)
GroundsKit.GRAVEL = Color3.fromRGB(176, 166, 148)
GroundsKit.IRON = Color3.fromRGB(28, 28, 32)
GroundsKit.TIMBER = Color3.fromRGB(107, 74, 46)
GroundsKit.LANTERN = Color3.fromRGB(255, 220, 160)

local TAU = math.pi * 2

-- ---------------------------------------------------------------- octagon --
-- A ring of eight straight runs is what a stone basin actually is: cut blocks
-- laid to a polygon. It also renders as a polygon rather than as the square a
-- Cylinder part collapses to when anything looks at it side on.
local function octagonRing(
	ctx: Ctx,
	name: string,
	cx: number,
	cz: number,
	radius: number,
	thickness: number,
	height: number,
	y: number,
	colour: Color3,
	material: Enum.Material
): { BasePart }
	local out = {}
	-- The flat-to-flat length of one side of a regular octagon at this radius,
	-- plus the mitre: two runs meeting at 45 degrees each need to reach
	-- (thickness / 2) * tan(22.5) past the flat to close the corner. Adding
	-- the whole thickness instead -- which is what this did -- overshoots by
	-- more than half the wall on a wide ring, and on the fountain's 11-stud
	-- apron that threw the octagon's south vertex 6 studs into the school's
	-- entrance terrace.
	local mitre = math.tan(math.pi / 8)
	local side = mitre * (2 * radius + thickness)
	for i = 0, 7 do
		local a = i * TAU / 8 + TAU / 16
		local piece = ctx.part({
			Name = name,
			Size = Vector3.new(side, height, thickness),
			CFrame = CFrame.new(cx + math.cos(a) * radius, y, cz + math.sin(a) * radius)
				* CFrame.Angles(0, -a, 0),
			Color = colour,
			Material = material,
			Parent = ctx.parent,
		})
		table.insert(out, piece)
	end
	return out
end

GroundsKit.octagonRing = octagonRing

-- A solid octagonal course. A regular octagon is exactly the union of a square
-- and the same square turned 45 degrees, so two parts do it -- and the second
-- is raised four hundredths of a stud so the two never share a face.
local function octagonSlab(
	ctx: Ctx,
	name: string,
	cx: number,
	cz: number,
	halfWidth: number,
	height: number,
	y: number,
	colour: Color3,
	material: Enum.Material
)
	for i, turn in { 0, math.pi / 4 } do
		ctx.part({
			Name = name,
			Size = Vector3.new(halfWidth * 2, height, halfWidth * 2),
			CFrame = CFrame.new(cx, y + (i - 1) * 0.04, cz) * CFrame.Angles(0, turn, 0),
			Color = colour,
			Material = material,
			Parent = ctx.parent,
		}).CanCollide = false
	end
end

GroundsKit.octagonSlab = octagonSlab

-- --------------------------------------------------------------- fountain --
-- rim, coping, water, a stepped pedestal, three dishes with their falls, a
-- ring of jets and a finial. `r` is the outside of the basin.
export type FountainSpec = {
	x: number,
	z: number,
	r: number,
	upLight: ((parent: Instance, x: number, z: number, colour: Color3?) -> ())?,
}

function GroundsKit.fountain(ctx: Ctx, o: FountainSpec)
	local cx, cz, r = o.x, o.z, o.r

	-- The courses, bottom to top, each one clear of the last: apron -0.3..0.9,
	-- step 0.9..1.4, basin wall 1.4..3.4, coping 3.4..4.3 -- coping height, so
	-- the water is visible over it from standing eye level and the edge is
	-- something to sit on. No two of them meet
	-- on the same side of a plane, which is what makes a stack of stone read as
	-- stone instead of speckling.
	octagonRing(ctx, "FountainApron", cx, cz, r + 5.5, 11.0, 1.2, 0.3, GroundsKit.STONE_PALE, Enum.Material.Concrete)
	for _, piece in octagonRing(ctx, "FountainStep", cx, cz, r + 2.0, 4.0, 0.5, 1.15, GroundsKit.STONE_PALE, Enum.Material.Concrete) do
		piece.CanCollide = false
	end

	-- the basin wall, and the coping course over it
	octagonRing(ctx, "FountainRim", cx, cz, r, 3.0, 2.0, 2.4, GroundsKit.STONE, Enum.Material.Marble)
	for _, piece in octagonRing(ctx, "FountainCoping", cx, cz, r, 4.2, 0.9, 3.85, GroundsKit.STONE_PALE, Enum.Material.Marble) do
		piece.CanCollide = false
	end
	-- a moulded band low on the wall, so the basin has a base
	for _, piece in octagonRing(ctx, "FountainBase", cx, cz, r, 4.0, 1.1, 2.15, GroundsKit.STONE_DEEP, Enum.Material.Marble) do
		piece.CanCollide = false
	end

	-- the water, and the floor of the basin under it. Both are cylinders: an
	-- octagon of stone with a square of water in it is what the first one was.
	local floor = ctx.part({
		Name = "FountainFloor",
		Size = Vector3.new(0.9, (r - 1.5) * 2, (r - 1.5) * 2),
		CFrame = CFrame.new(cx, 1.85, cz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(52, 74, 84),
		Material = Enum.Material.Slate,
		Shape = Enum.PartType.Cylinder,
		Parent = ctx.parent,
	})
	floor.CanCollide = false
	local water = ctx.part({
		Name = "FountainWater",
		Size = Vector3.new(0.5, (r - 1.6) * 2, (r - 1.6) * 2),
		CFrame = CFrame.new(cx, 3.0, cz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GroundsKit.WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Shape = Enum.PartType.Cylinder,
		Parent = ctx.parent,
	})
	water.CanCollide = false
	water.Reflectance = 0.4

	-- the pedestal: three octagonal courses, smallest on top
	for i, course in { { w = 7.0, h = 1.8 }, { w = 5.2, h = 1.6 }, { w = 3.6, h = 1.4 } } do
		octagonSlab(ctx, "FountainPedestal", cx, cz, course.w, course.h,
			1.9 + (i - 1) * 1.7 + course.h / 2, GroundsKit.STONE_PALE, Enum.Material.Marble)
	end

	-- three dishes on a shaft, each with the sheet of water falling off it
	local dishes = { { r = r * 0.46, y = 10.6 }, { r = r * 0.30, y = 16.0 }, { r = r * 0.18, y = 20.4 } }
	local shaftFrom = 6.6
	for i, dish in dishes do
		ctx.part({
			Name = "FountainShaft",
			Size = Vector3.new(2.6, dish.y - shaftFrom + 1.2, 2.6),
			CFrame = CFrame.new(cx, (shaftFrom + dish.y) / 2, cz),
			Color = GroundsKit.STONE_PALE,
			Material = Enum.Material.Marble,
			Parent = ctx.parent,
		}).CanCollide = false
		-- the bowl under the lip: two courses, the lower one well in, so the
		-- dish tapers to its shaft instead of reading as a tray on a stick
		octagonSlab(ctx, "FountainDishBowl", cx, cz, dish.r * 0.86, 1.1, dish.y - 1.05, GroundsKit.STONE, Enum.Material.Marble)
		octagonSlab(ctx, "FountainDishBowl", cx, cz, dish.r * 0.52, 1.0, dish.y - 2.0, GroundsKit.STONE, Enum.Material.Marble)
		for _, piece in octagonRing(ctx, "FountainDishLip", cx, cz, dish.r, 2.0, 1.2, dish.y, GroundsKit.STONE_PALE, Enum.Material.Marble) do
			piece.CanCollide = false
		end
		-- the water standing in the dish
		octagonSlab(ctx, "FountainDishWater", cx, cz, dish.r * 0.94, 0.4, dish.y + 0.5, GroundsKit.WATER, Enum.Material.Glass)
		-- the fall: a curtain of water hanging off the lip all the way round,
		-- not a translucent block the width of the dish
		local drop = if i == 1 then 6.2 else 5.0
		for _, piece in octagonRing(ctx, "FountainFall", cx, cz, dish.r + 0.3, 0.5, drop, dish.y - 0.4 - drop / 2, Color3.fromRGB(214, 238, 248), Enum.Material.Glass) do
			piece.CanCollide = false
			piece.Transparency = 0.55
			piece.Reflectance = 0.2
			piece.CastShadow = false
		end
		shaftFrom = dish.y
	end

	-- the finial, and a jet standing over it
	ctx.part({
		Name = "FountainFinial",
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = CFrame.new(cx, 21.8, cz),
		Color = GroundsKit.STONE_PALE,
		Material = Enum.Material.Marble,
		Shape = Enum.PartType.Ball,
		Parent = ctx.parent,
	}).CanCollide = false
	-- the plume: a narrow column of water off the finial with a head on it,
	-- rather than a seven-stud white pillar standing in the middle of the court
	local plume = ctx.part({
		Name = "FountainPlume",
		Size = Vector3.new(0.5, 4.0, 0.5),
		CFrame = CFrame.new(cx, 24.8, cz),
		Color = Color3.fromRGB(226, 246, 252),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		Shape = Enum.PartType.Cylinder,
		Parent = ctx.parent,
	})
	plume.CFrame = CFrame.new(cx, 24.8, cz) * CFrame.Angles(0, 0, math.rad(90))
	plume.CanCollide = false
	plume.CastShadow = false
	local head = ctx.part({
		Name = "FountainPlumeHead",
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(cx, 27.2, cz),
		Color = Color3.fromRGB(232, 248, 252),
		Material = Enum.Material.Neon,
		Transparency = 0.62,
		Shape = Enum.PartType.Ball,
		Parent = ctx.parent,
	})
	head.CanCollide = false
	head.CastShadow = false

	-- eight jets round the basin, each arcing in towards the middle
	for i = 0, 7 do
		local a = i * TAU / 8
		local jx, jz = cx + math.cos(a) * (r - 5.0), cz + math.sin(a) * (r - 5.0)
		-- leaning IN towards the middle: yaw the jet to face the centre first,
		-- then tip it about its own X so the lean is inward whatever side of
		-- the basin it stands on
		local jet = ctx.part({
			Name = "FountainJet",
			Size = Vector3.new(0.45, 5.4, 0.45),
			CFrame = CFrame.new(jx, 6.4, jz)
				* CFrame.Angles(0, -a + math.pi / 2, 0)
				* CFrame.Angles(math.rad(-24), 0, 0),
			Color = Color3.fromRGB(226, 246, 252),
			Material = Enum.Material.Neon,
			Transparency = 0.5,
			Shape = Enum.PartType.Cylinder,
			Parent = ctx.parent,
		})
		jet.CFrame = jet.CFrame * CFrame.Angles(0, 0, math.rad(90))
		jet.CanCollide = false
		jet.CastShadow = false
		ctx.part({
			Name = "FountainSpout",
			Size = Vector3.new(1.4, 1.0, 1.4),
			CFrame = CFrame.new(jx, 3.1, jz),
			Color = GroundsKit.STONE_DEEP,
			Material = Enum.Material.Metal,
			Parent = ctx.parent,
		}).CanCollide = false
	end

	if o.upLight then
		for i = 0, 11 do
			local a = i * TAU / 12
			o.upLight(ctx.parent, cx + math.cos(a) * (r + 4.0), cz + math.sin(a) * (r + 4.0), Color3.fromRGB(190, 226, 255))
		end
	end
end

-- ----------------------------------------------------------------- hedges --
-- A run of clipped box: a bed of its own soil, the hedge over it, and a
-- lighter top face so it reads as clipped rather than as a green slab.
function GroundsKit.hedgeRun(ctx: Ctx, x0: number, z0: number, x1: number, z1: number, thickness: number, height: number)
	local w = math.max(math.abs(x1 - x0), thickness)
	local d = math.max(math.abs(z1 - z0), thickness)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	ctx.part({
		Name = "Hedge",
		Size = Vector3.new(w, height, d),
		CFrame = CFrame.new(cx, 0.4 + height / 2, cz),
		Color = GroundsKit.HEDGE_DEEP,
		Material = Enum.Material.Grass,
		Parent = ctx.parent,
	})
	ctx.part({
		Name = "HedgeClip",
		Size = Vector3.new(w - 0.4, 0.5, d - 0.4),
		CFrame = CFrame.new(cx, 0.4 + height - 0.1, cz),
		Color = GroundsKit.HEDGE,
		Material = Enum.Material.Grass,
		Parent = ctx.parent,
	}).CanCollide = false
end

-- A clipped yew cone: four stacked, shrinking courses on a short stem. Not a
-- cone, but read as one at any distance, and it is five named parts rather
-- than one green box.
function GroundsKit.yewCone(ctx: Ctx, x: number, z: number, height: number)
	ctx.part({
		Name = "YewStem",
		Size = Vector3.new(1.2, 1.6, 1.2),
		CFrame = CFrame.new(x, 1.2, z),
		Color = GroundsKit.TIMBER,
		Material = Enum.Material.Wood,
		Parent = ctx.parent,
	}).CanCollide = false
	local courses = 4
	for i = 0, courses - 1 do
		local t = i / courses
		local w = (height * 0.46) * (1 - t * 0.78)
		local h = height / courses
		ctx.part({
			Name = "YewCone",
			Size = Vector3.new(w, h, w),
			CFrame = CFrame.new(x, 2.0 + i * h + h / 2, z) * CFrame.Angles(0, math.rad(22 * i), 0),
			Color = GroundsKit.YEW:Lerp(GroundsKit.HEDGE, t * 0.4),
			Material = Enum.Material.Grass,
			Parent = ctx.parent,
		}).CanCollide = false
	end
end

-- A stone urn on a plinth: base, plinth, moulding, bowl, lip, and planting.
function GroundsKit.urn(ctx: Ctx, x: number, z: number, scale: number?)
	local s = scale or 1.0
	ctx.part({ Name = "UrnBase", Size = Vector3.new(4.4 * s, 1.0 * s, 4.4 * s), CFrame = CFrame.new(x, 0.9 + 0.5 * s, z), Color = GroundsKit.STONE, Material = Enum.Material.Concrete, Parent = ctx.parent })
	ctx.part({ Name = "UrnPlinth", Size = Vector3.new(3.0 * s, 4.0 * s, 3.0 * s), CFrame = CFrame.new(x, 1.4 + 2.5 * s, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent })
	ctx.part({ Name = "UrnMoulding", Size = Vector3.new(4.0 * s, 0.7 * s, 4.0 * s), CFrame = CFrame.new(x, 1.4 + 4.7 * s, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "UrnBowl", Size = Vector3.new(5.2 * s, 2.6 * s, 5.2 * s), CFrame = CFrame.new(x, 1.4 + 6.3 * s, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "UrnLip", Size = Vector3.new(6.0 * s, 0.6 * s, 6.0 * s), CFrame = CFrame.new(x, 1.4 + 7.7 * s, z), Color = GroundsKit.STONE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "UrnPlanting", Size = Vector3.new(5.0 * s, 2.2 * s, 5.0 * s), CFrame = CFrame.new(x, 1.4 + 8.9 * s, z), Color = GroundsKit.HEDGE, Material = Enum.Material.Grass, Parent = ctx.parent }).CanCollide = false
end

-- ------------------------------------------------------------- a parterre --
-- Gravel, a clipped box edge, a knot of box inside it, a yew at each corner,
-- an urn in the middle and flowers in the compartments. The old one was a
-- rectangle of bare soil with a green cross laid on it.
export type ParterreSpec = {
	x: number,
	z: number,
	hw: number,
	hd: number,
	flower: ((kind: string, cf: CFrame) -> ())?,
	upLight: ((parent: Instance, x: number, z: number, colour: Color3?) -> ())?,
}

function GroundsKit.parterre(ctx: Ctx, o: ParterreSpec)
	local x, z, hw, hd = o.x, o.z, o.hw, o.hd
	-- gravel, laid over the paving and inside its own kerb
	ctx.tag(ctx.part({
		Name = "ParterreGravel",
		Size = Vector3.new(hw * 2 - 2, 0.34, hd * 2 - 2),
		-- 0.55 .. 0.89: over the court's paving joints (0.47 .. 0.57), which
		-- run the full width of the court and pass under every bed
		CFrame = CFrame.new(x, 0.72, z),
		Color = GroundsKit.GRAVEL,
		Material = Enum.Material.Pebble,
		Parent = ctx.parent,
	}), "TexCourtPaving").CanCollide = false
	for _, run in {
		{ x - hw, z - hd, x + hw, z - hd },
		{ x - hw, z + hd, x + hw, z + hd },
		{ x - hw, z - hd, x - hw, z + hd },
		{ x + hw, z - hd, x + hw, z + hd },
	} do
		ctx.part({
			Name = "ParterreKerb",
			Size = Vector3.new(math.max(math.abs(run[3] - run[1]) + 1.4, 1.4), 0.9, math.max(math.abs(run[4] - run[2]) + 1.4, 1.4)),
			CFrame = CFrame.new((run[1] + run[3]) / 2, 0.75, (run[2] + run[4]) / 2),
			Color = GroundsKit.STONE_PALE,
			Material = Enum.Material.Concrete,
			Parent = ctx.parent,
		})
	end

	-- the clipped box edge, set in from the kerb
	local ex, ez = hw - 3.0, hd - 3.0
	GroundsKit.hedgeRun(ctx, x - ex, z - ez, x + ex, z - ez, 1.8, 2.4)
	GroundsKit.hedgeRun(ctx, x - ex, z + ez, x + ex, z + ez, 1.8, 2.4)
	GroundsKit.hedgeRun(ctx, x - ex, z - ez, x - ex, z + ez, 1.8, 2.4)
	GroundsKit.hedgeRun(ctx, x + ex, z - ez, x + ex, z + ez, 1.8, 2.4)

	-- a knot inside it: a diamond of box on the bed's own axes
	local kx, kz = ex - 5.0, ez - 5.0
	for _, seg in {
		{ x - kx, z, x, z - kz },
		{ x, z - kz, x + kx, z },
		{ x + kx, z, x, z + kz },
		{ x, z + kz, x - kx, z },
	} do
		local dx, dz = seg[3] - seg[1], seg[4] - seg[2]
		local length = math.sqrt(dx * dx + dz * dz)
		ctx.part({
			Name = "ParterreKnot",
			Size = Vector3.new(1.4, 1.7, length),
			CFrame = CFrame.new((seg[1] + seg[3]) / 2, 1.25, (seg[2] + seg[4]) / 2)
				* CFrame.Angles(0, math.atan2(dx, dz), 0),
			Color = GroundsKit.HEDGE,
			Material = Enum.Material.Grass,
			Parent = ctx.parent,
		}).CanCollide = false
	end

	-- a clipped yew at each inside corner, and an urn on the middle
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		GroundsKit.yewCone(ctx, x + corner[1] * (ex - 2.6), z + corner[2] * (ez - 2.6), 9.0)
	end
	GroundsKit.urn(ctx, x, z, 1.1)

	-- flowers in the four compartments the knot makes
	if o.flower then
		for _, corner in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do
			for i = -1, 1 do
				local fx = x + corner[1] * (kx * 0.62) + (if corner[1] == 0 then i * 4.4 else 0)
				local fz = z + corner[2] * (kz * 0.62) + (if corner[2] == 0 then 0 else i * 4.4)
				if corner[1] ~= 0 then
					fz = z + i * 4.4
				end
				o.flower(if (i + corner[1]) % 2 == 0 then "KFlowerRed" else "KFlowerYellow", CFrame.new(fx, 0.8, fz))
			end
		end
	end
	if o.upLight then
		o.upLight(ctx.parent, x, z - hd - 2.4, Color3.fromRGB(255, 224, 172))
		o.upLight(ctx.parent, x, z + hd + 2.4, Color3.fromRGB(255, 224, 172))
	end
end

-- --------------------------------------------------------------- a bench --
-- Cast-iron ends, five timber slats, a back of three, and an arm each side.
function GroundsKit.bench(ctx: Ctx, x: number, z: number, yaw: number)
	local at = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	for _, side in { -1, 1 } do
		ctx.part({ Name = "BenchEnd", Size = Vector3.new(0.6, 2.4, 4.4), CFrame = at * CFrame.new(side * 5.6, 1.6, 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent })
		ctx.part({ Name = "BenchFoot", Size = Vector3.new(1.2, 0.5, 5.2), CFrame = at * CFrame.new(side * 5.6, 0.65, 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "BenchArm", Size = Vector3.new(0.7, 0.7, 4.6), CFrame = at * CFrame.new(side * 5.6, 4.3, -0.2), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "BenchStay", Size = Vector3.new(0.5, 2.6, 0.5), CFrame = at * CFrame.new(side * 5.6, 3.4, 1.9), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	for i = -2, 2 do
		ctx.part({
			Name = "BenchSlat",
			Size = Vector3.new(11.6, 0.4, 0.85),
			CFrame = at * CFrame.new(0, 2.9, i * 1.0),
			Color = GroundsKit.TIMBER,
			Material = Enum.Material.WoodPlanks,
			Parent = ctx.parent,
		})
	end
	for i = 0, 2 do
		ctx.part({
			Name = "BenchBackSlat",
			Size = Vector3.new(11.6, 0.85, 0.4),
			CFrame = at * CFrame.new(0, 3.9 + i * 1.1, 2.1),
			Color = GroundsKit.TIMBER,
			Material = Enum.Material.WoodPlanks,
			Parent = ctx.parent,
		}).CanCollide = false
	end
end

-- ------------------------------------------------------------- iron fence --
-- Spear-topped railings between stone piers: the thing that encloses every
-- courtyard in the reference art.
function GroundsKit.railing(ctx: Ctx, x0: number, z0: number, x1: number, z1: number, height: number)
	local dx, dz = x1 - x0, z1 - z0
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1 then
		return
	end
	local yaw = math.atan2(dx, dz)
	local mid = CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2) * CFrame.Angles(0, yaw, 0)
	ctx.part({ Name = "RailingKerb", Size = Vector3.new(1.6, 1.0, length), CFrame = mid * CFrame.new(0, 0.7, 0), Color = GroundsKit.STONE, Material = Enum.Material.Concrete, Parent = ctx.parent })
	for _, band in { { y = height * 0.30, h = 0.4 }, { y = height * 0.88, h = 0.5 } } do
		ctx.part({ Name = "RailingRail", Size = Vector3.new(0.42, band.h, length), CFrame = mid * CFrame.new(0, 1.2 + band.y, 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	local bays = math.max(1, math.floor(length / 2.6))
	for i = 0, bays do
		local along = -length / 2 + i * (length / bays)
		ctx.part({ Name = "RailingBar", Size = Vector3.new(0.3, height, 0.3), CFrame = mid * CFrame.new(0, 1.2 + height / 2, along), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "RailingSpear", Size = Vector3.new(0.55, 1.1, 0.55), CFrame = mid * CFrame.new(0, 1.2 + height + 0.4, along) * CFrame.Angles(0, math.rad(45), 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
end

-- ------------------------------------------------------------- boundary --
-- The estate fence. Four thousand two hundred studs of it round the built
-- core, which is why it is not GroundsKit.railing: that one puts a bar every
-- 2.6 studs, and round the whole core that is sixteen hundred bars before a
-- single rail. This is the same fence written as bays -- a coursed dwarf wall
-- with an ashlar coping, two rails and a spear every nine studs standing on
-- it -- with a pier at every bay end.
--
-- The dwarf wall is the only part of it that collides. Railings are half a
-- stud thick and a player walks straight between them, so each bay also
-- carries one invisible guard slab: the fence keeps people in, which is the
-- whole reason a school has one.
function GroundsKit.boundaryPier(ctx: Ctx, x: number, z: number)
	ctx.part({ Name = "BoundaryPierPlinth", Size = Vector3.new(3.6, 2.4, 3.6), CFrame = CFrame.new(x, 0.7, z), Color = GroundsKit.STONE_DEEP, Material = Enum.Material.Concrete, Parent = ctx.parent })
	ctx.tag(ctx.part({ Name = "BoundaryPierShaft", Size = Vector3.new(2.8, 7.5, 2.8), CFrame = CFrame.new(x, 5.65, z), Color = GroundsKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.part({ Name = "BoundaryPierCornice", Size = Vector3.new(3.4, 0.9, 3.4), CFrame = CFrame.new(x, 9.85, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "BoundaryPierCap", Size = Vector3.new(2.4, 1.5, 2.4), CFrame = CFrame.new(x, 11.05, z) * CFrame.Angles(0, math.rad(45), 0), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "BoundaryPierFinial", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(x, 12.6, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Shape = Enum.PartType.Ball, Parent = ctx.parent }).CanCollide = false
end

-- One bay of it, pier centre to pier centre. Everything laid here is narrower
-- than the 2.8-stud pier shaft, so the wall, the coping and both rails run
-- straight through a pier and come out the other side as one continuous line
-- instead of stopping at every pier with a joint to hide.
function GroundsKit.boundaryRun(ctx: Ctx, x0: number, z0: number, x1: number, z1: number)
	local dx, dz = x1 - x0, z1 - z0
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 4 then
		return
	end
	local yaw = math.atan2(dx, dz)
	local mid = CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2) * CFrame.Angles(0, yaw, 0)
	-- founded at -0.6 rather than on grade: the gate apron's own underside is
	-- at y = 0 and the two runs of the fence pass over the ends of it
	ctx.tag(ctx.part({ Name = "BoundaryWall", Size = Vector3.new(1.6, 3.2, length), CFrame = mid * CFrame.new(0, 1.0, 0), Color = GroundsKit.STONE_DEEP, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.part({ Name = "BoundaryCoping", Size = Vector3.new(2.2, 0.5, length), CFrame = mid * CFrame.new(0, 2.85, 0), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({
		Name = "BoundaryGuard",
		Size = Vector3.new(1.0, 10.1, length),
		CFrame = mid * CFrame.new(0, 5.55, 0),
		Color = GroundsKit.IRON,
		Material = Enum.Material.Metal,
		Transparency = 1,
		Parent = ctx.parent,
	})
	for _, y in { 4.6, 8.7 } do
		ctx.part({ Name = "BoundaryRail", Size = Vector3.new(0.55, 0.45, length), CFrame = mid * CFrame.new(0, y, 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	local bars = math.max(2, math.floor(length / 9 + 0.5))
	for i = 0, bars - 1 do
		local along = -length / 2 + (i + 0.5) * (length / bars)
		ctx.part({ Name = "BoundaryBar", Size = Vector3.new(0.4, 6.0, 0.4), CFrame = mid * CFrame.new(0, 6.1, along), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "BoundarySpear", Size = Vector3.new(0.72, 1.3, 0.72), CFrame = mid * CFrame.new(0, 9.75, along) * CFrame.Angles(0, math.rad(45), 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
end

-- A gate pier: plinth, shaft, cornice and a ball finial.
function GroundsKit.gatePier(ctx: Ctx, x: number, z: number, height: number)
	ctx.part({ Name = "PierPlinth", Size = Vector3.new(7.0, 1.6, 7.0), CFrame = CFrame.new(x, 0.9, z), Color = GroundsKit.STONE, Material = Enum.Material.Concrete, Parent = ctx.parent })
	ctx.tag(ctx.part({ Name = "PierShaft", Size = Vector3.new(5.4, height, 5.4), CFrame = CFrame.new(x, 1.7 + height / 2, z), Color = GroundsKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.part({ Name = "PierCornice", Size = Vector3.new(6.8, 1.1, 6.8), CFrame = CFrame.new(x, 1.7 + height + 0.55, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "PierCap", Size = Vector3.new(5.0, 0.9, 5.0), CFrame = CFrame.new(x, 1.7 + height + 1.55, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "PierFinial", Size = Vector3.new(3.0, 3.0, 3.0), CFrame = CFrame.new(x, 1.7 + height + 3.4, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Shape = Enum.PartType.Ball, Parent = ctx.parent }).CanCollide = false
end

-- ----------------------------------------------------------- floodlight --
-- A mast with a head on it, not a glowing box in the air. Base, mast, ladder,
-- a bracket arm, a head frame, six lamp units in it and a service walkway.
function GroundsKit.floodMast(ctx: Ctx, x: number, z: number, height: number, aimYaw: number)
	local at = CFrame.new(x, 0, z) * CFrame.Angles(0, aimYaw, 0)
	ctx.part({ Name = "MastBase", Size = Vector3.new(6.0, 2.0, 6.0), CFrame = at * CFrame.new(0, 1.0, 0), Color = Color3.fromRGB(150, 150, 156), Material = Enum.Material.Concrete, Parent = ctx.parent })
	ctx.part({ Name = "MastPlinth", Size = Vector3.new(4.2, 1.2, 4.2), CFrame = at * CFrame.new(0, 2.6, 0), Color = Color3.fromRGB(168, 168, 174), Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "FloodMast", Size = Vector3.new(2.4, height, 2.4), CFrame = at * CFrame.new(0, 2.0 + height / 2, 0), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = ctx.parent })
	-- a ladder up the back of it
	for i = 0, math.floor(height / 4) do
		ctx.part({ Name = "MastRung", Size = Vector3.new(2.4, 0.28, 0.28), CFrame = at * CFrame.new(0, 5.0 + i * 4.0, -1.5), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	for _, side in { -1, 1 } do
		ctx.part({ Name = "MastLadderRail", Size = Vector3.new(0.3, height - 4, 0.3), CFrame = at * CFrame.new(side * 1.0, 4.0 + (height - 4) / 2, -1.5), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	local top = 2.0 + height
	-- the bracket the head hangs off, and the walkway under it
	ctx.part({ Name = "MastBracket", Size = Vector3.new(2.0, 1.0, 7.0), CFrame = at * CFrame.new(0, top - 1.4, 3.0), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "MastWalkway", Size = Vector3.new(11.0, 0.4, 3.4), CFrame = at * CFrame.new(0, top - 2.6, 2.4), Color = Color3.fromRGB(84, 88, 94), Material = Enum.Material.DiamondPlate, Parent = ctx.parent }).CanCollide = false
	for _, side in { -1, 1 } do
		ctx.part({ Name = "MastGuard", Size = Vector3.new(0.3, 2.4, 3.4), CFrame = at * CFrame.new(side * 5.4, top - 1.4, 2.4), Color = Color3.fromRGB(84, 88, 94), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	-- the head: a frame with six lamp units in it, each with its own cowl
	ctx.part({ Name = "FloodHead", Size = Vector3.new(13.0, 5.4, 1.4), CFrame = at * CFrame.new(0, top + 1.2, 4.4), Color = Color3.fromRGB(72, 76, 82), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	for i = 0, 5 do
		local lx = -5.0 + (i % 3) * 5.0
		local ly = top + (if i < 3 then 2.4 else 0.0)
		ctx.part({ Name = "FloodCowl", Size = Vector3.new(4.2, 2.2, 1.8), CFrame = at * CFrame.new(lx, ly, 5.2) * CFrame.Angles(math.rad(-18), 0, 0), Color = Color3.fromRGB(60, 64, 70), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		local lamp = ctx.part({
			Name = "FloodLamp",
			Size = Vector3.new(3.4, 1.6, 0.5),
			CFrame = at * CFrame.new(lx, ly - 0.2, 5.9) * CFrame.Angles(math.rad(-18), 0, 0),
			Color = Color3.fromRGB(255, 246, 214),
			Material = Enum.Material.Neon,
			Parent = ctx.parent,
		})
		lamp.CanCollide = false
		lamp.CastShadow = false
		if i == 1 or i == 4 then
			local light = Instance.new("SpotLight")
			light.Angle = 110
			light.Brightness = 2.2
			light.Range = 96
			light.Face = Enum.NormalId.Front
			light.Shadows = false
			light.Color = Color3.fromRGB(255, 248, 226)
			light.Parent = lamp
		end
	end
end

-- ----------------------------------------------------------------- goal --
-- Posts, crossbar, the two back stanchions, the stays between them, and a net
-- on three faces. A goal was two white sticks and a bar.
function GroundsKit.goal(ctx: Ctx, x: number, z: number, width: number, height: number, yaw: number)
	local at = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local hw, back = width / 2, 8.0
	for _, side in { -1, 1 } do
		ctx.part({ Name = "GoalPost", Size = Vector3.new(1.1, height, 1.1), CFrame = at * CFrame.new(side * hw, height / 2, 0), Color = Color3.fromRGB(238, 238, 240), Material = Enum.Material.Metal, Parent = ctx.parent })
		ctx.part({ Name = "GoalStanchion", Size = Vector3.new(0.8, height * 0.52, 0.8), CFrame = at * CFrame.new(side * hw, height * 0.26, -back), Color = Color3.fromRGB(226, 226, 230), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "GoalStay", Size = Vector3.new(0.7, 0.7, back + 1), CFrame = at * CFrame.new(side * hw, height * 0.52, -back / 2), Color = Color3.fromRGB(226, 226, 230), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "GoalNetSide", Size = Vector3.new(0.2, height * 0.7, back), CFrame = at * CFrame.new(side * (hw - 0.1), height * 0.35, -back / 2), Color = Color3.fromRGB(238, 240, 244), Material = Enum.Material.Fabric, Transparency = 0.45, Parent = ctx.parent }).CanCollide = false
	end
	ctx.part({ Name = "GoalBar", Size = Vector3.new(width + 1.1, 1.1, 1.1), CFrame = at * CFrame.new(0, height, 0), Color = Color3.fromRGB(238, 238, 240), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "GoalNetBack", Size = Vector3.new(width, height * 0.55, 0.2), CFrame = at * CFrame.new(0, height * 0.275, -back), Color = Color3.fromRGB(238, 240, 244), Material = Enum.Material.Fabric, Transparency = 0.45, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "GoalNetRoof", Size = Vector3.new(width, 0.2, back), CFrame = at * CFrame.new(0, height * 0.78, -back / 2) * CFrame.Angles(math.rad(18), 0, 0), Color = Color3.fromRGB(238, 240, 244), Material = Enum.Material.Fabric, Transparency = 0.45, Parent = ctx.parent }).CanCollide = false
	-- the ground bar the net is laced to, and the pegs holding it down
	ctx.part({ Name = "GoalGroundBar", Size = Vector3.new(width, 0.5, 0.5), CFrame = at * CFrame.new(0, 0.3, -back), Color = Color3.fromRGB(226, 226, 230), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	for i = -1, 1 do
		ctx.part({ Name = "GoalPeg", Size = Vector3.new(0.4, 0.9, 0.4), CFrame = at * CFrame.new(i * (width / 3), 0.45, -back - 0.6), Color = Color3.fromRGB(160, 164, 170), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
end

-- ------------------------------------------------------------ lawn panel --
-- A panel of mown grass inside a clipped box edge and a stone kerb, with the
-- mowing stripes a groundsman actually leaves. The thing a college court is
-- mostly made of, and what "an empty rectangle of terrain" is not.
function GroundsKit.lawnPanel(ctx: Ctx, x: number, z: number, hw: number, hd: number)
	ctx.tag(ctx.part({
		Name = "CourtLawn",
		Size = Vector3.new(hw * 2, 0.36, hd * 2),
		CFrame = CFrame.new(x, 0.72, z),
		Color = Color3.fromRGB(62, 107, 58),
		Material = Enum.Material.Grass,
		Parent = ctx.parent,
	}), "TexGrass").CanCollide = false
	-- the stripes: alternating cut, lighter where the mower ran towards you
	local stripes = math.max(3, math.floor(hw / 5))
	for i = 0, stripes - 1 do
		if i % 2 == 0 then
			ctx.part({
				Name = "LawnStripe",
				Size = Vector3.new((hw * 2 - 2) / stripes, 0.2, hd * 2 - 2),
				CFrame = CFrame.new(x - hw + 1 + (i + 0.5) * ((hw * 2 - 2) / stripes), 0.95, z),
				Color = Color3.fromRGB(76, 124, 68),
				Material = Enum.Material.Grass,
				Parent = ctx.parent,
			}).CanCollide = false
		end
	end
	-- a stone kerb round it, and a clipped box edge inside that
	for _, run in {
		{ x - hw, z - hd, x + hw, z - hd },
		{ x - hw, z + hd, x + hw, z + hd },
		{ x - hw, z - hd, x - hw, z + hd },
		{ x + hw, z - hd, x + hw, z + hd },
	} do
		ctx.part({
			Name = "LawnKerb",
			Size = Vector3.new(math.max(math.abs(run[3] - run[1]) + 1.6, 1.6), 1.0, math.max(math.abs(run[4] - run[2]) + 1.6, 1.6)),
			CFrame = CFrame.new((run[1] + run[3]) / 2, 0.7, (run[2] + run[4]) / 2),
			Color = GroundsKit.STONE_PALE,
			Material = Enum.Material.Concrete,
			Parent = ctx.parent,
		})
	end
	GroundsKit.hedgeRun(ctx, x - hw + 3, z - hd + 3, x + hw - 3, z - hd + 3, 1.6, 2.2)
	GroundsKit.hedgeRun(ctx, x - hw + 3, z + hd - 3, x + hw - 3, z + hd - 3, 1.6, 2.2)
	GroundsKit.hedgeRun(ctx, x - hw + 3, z - hd + 3, x - hw + 3, z + hd - 3, 1.6, 2.2)
	GroundsKit.hedgeRun(ctx, x + hw - 3, z - hd + 3, x + hw - 3, z + hd - 3, 1.6, 2.2)
end

-- ---------------------------------------------------------------- sundial --
-- A stone drinking fountain and dial on a plinth: something small to close a
-- vista on that is not another statue.
function GroundsKit.dial(ctx: Ctx, x: number, z: number, upLight: ((parent: Instance, x: number, z: number, colour: Color3?) -> ())?)
	-- radius 9 with a 5-thick ring reaches 11.5, which keeps it inside the
	-- thirteen-stud half-width of the axis walk it stands on
	octagonRing(ctx, "DialApron", x, z, 9.0, 5.0, 0.9, 0.45, GroundsKit.STONE_PALE, Enum.Material.Concrete)
	octagonSlab(ctx, "DialStep", x, z, 5.4, 0.6, 1.2, GroundsKit.STONE_PALE, Enum.Material.Concrete)
	ctx.part({ Name = "DialPlinth", Size = Vector3.new(6.4, 5.2, 6.4), CFrame = CFrame.new(x, 4.1, z), Color = GroundsKit.STONE, Material = Enum.Material.Marble, Parent = ctx.parent })
	ctx.part({ Name = "DialMoulding", Size = Vector3.new(7.4, 0.8, 7.4), CFrame = CFrame.new(x, 7.1, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "DialBowl", Size = Vector3.new(5.0, 1.4, 5.0), CFrame = CFrame.new(x, 8.2, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	local water = ctx.part({ Name = "DialWater", Size = Vector3.new(3.6, 0.3, 3.6), CFrame = CFrame.new(x, 8.7, z), Color = GroundsKit.WATER, Material = Enum.Material.Glass, Transparency = 0.4, Parent = ctx.parent })
	water.CanCollide = false
	water.Reflectance = 0.4
	ctx.part({ Name = "DialFace", Size = Vector3.new(4.4, 0.3, 4.4), CFrame = CFrame.new(x, 9.1, z), Color = Color3.fromRGB(168, 132, 58), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "DialGnomon", Size = Vector3.new(0.35, 3.4, 0.35), CFrame = CFrame.new(x, 10.6, z) * CFrame.Angles(math.rad(38), 0, 0), Color = Color3.fromRGB(168, 132, 58), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		ctx.part({ Name = "DialSpout", Size = Vector3.new(0.9, 0.9, 1.6), CFrame = CFrame.new(x + math.cos(a) * 2.6, 8.5, z + math.sin(a) * 2.6) * CFrame.Angles(0, -a, 0), Color = Color3.fromRGB(168, 132, 58), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	if upLight then
		for i = 0, 3 do
			local a = i * math.pi / 2
			upLight(ctx.parent, x + math.cos(a) * 8.0, z + math.sin(a) * 8.0, Color3.fromRGB(255, 224, 172))
		end
	end
end

return GroundsKit

end)()
local __PlanBuilder = (function()

-- Build a building FROM THE DRAWING.
--
-- This is the step the whole plan was written around. Until now MapService has
-- been the author of the campus: every wall, every door, every stair was a
-- number typed into a seven-thousand-line file by whoever was adding that
-- feature, and CampusPlan could only be checked against the result afterwards.
--
-- Here the drawing is the input. Give this a building's name and it emits the
-- floors, the walls, the openings, the windows, the roof and the entrances that
-- CampusPlan says that building has -- and nothing else. A wall that is not
-- drawn cannot be built, which is the property the last several months of
-- whack-a-mole were missing.
--
-- It takes its part maker, its tagger and its prop placer from the caller
-- rather than requiring MapService back, so it stays a leaf module the way
-- CollegiateKit does.



local CampusPlan = __CampusPlan
local Kit = __Kit

local PlanBuilder = {}

export type Ctx = {
	parent: Instance,
	part: (props: { [string]: any }) -> BasePart,
	tag: (part: Instance, tag: string) -> (),
	prop: ((kind: string, cf: CFrame, options: any?) -> ())?,
}

local FLOOR = Color3.fromRGB(196, 194, 188)
local CEILING = Color3.fromRGB(238, 234, 224)
local STONE = Kit.STONE
local ASHLAR = Kit.ASHLAR
local GLASS_LIT = Kit.GLASS_LIT
local FRAME = Kit.FRAME
local TIMBER = Kit.TIMBER

-- The layer ladder, same as MapService's: a thing drawn ON a surface takes the
-- next rung up, never that surface's own height.
local FLOOR_THICK = 1.0
local CEIL_THICK = 0.6
local WINDOW_PITCH = 22.0
local WINDOW_W = 8.0
local WINDOW_H = 11.0
local SILL = 5.0

local function kit(ctx: Ctx): Kit.Ctx
	return { parent = ctx.parent, part = ctx.part :: any, tag = ctx.tag :: any }
end

-- ---------------------------------------------------------------------------
-- WALLS
-- ---------------------------------------------------------------------------
-- A wall run minus the openings drawn in it. The gaps are cut, not painted
-- over: the two stubs either side of a doorway are separate parts, and the head
-- above it is a third, so a door is a hole you can walk through rather than a
-- dark rectangle on a solid wall.
local function wallRun(
	ctx: Ctx,
	name: string,
	from: { number },
	to: { number },
	baseY: number,
	height: number,
	thickness: number,
	gaps: { { at: number, width: number, height: number } },
	tagName: string
)
	local dx, dz = to[1] - from[1], to[2] - from[2]
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.1 then
		return
	end
	local alongX = math.abs(dx) > math.abs(dz)
	local dir = if alongX then (if dx > 0 then 1 else -1) else (if dz > 0 then 1 else -1)
	local originAlong = if alongX then from[1] else from[2]
	local across = if alongX then from[2] else from[1]

	local function slab(nm: string, startAt: number, endAt: number, y0: number, y1: number)
		local span = endAt - startAt
		if span <= 0.05 or y1 - y0 <= 0.05 then
			return
		end
		local mid = (startAt + endAt) / 2
		local size = if alongX
			then Vector3.new(span, y1 - y0, thickness)
			else Vector3.new(thickness, y1 - y0, span)
		local cf = if alongX
			then CFrame.new(mid, (y0 + y1) / 2, across)
			else CFrame.new(across, (y0 + y1) / 2, mid)
		ctx.tag(ctx.part({ Name = nm, Size = size, CFrame = cf, Color = STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), tagName)
	end

	-- put the gaps in order along the run
	local sorted = table.clone(gaps)
	table.sort(sorted, function(a, b)
		return a.at < b.at
	end)

	local lo = math.min(originAlong, originAlong + dir * length)
	local hi = math.max(originAlong, originAlong + dir * length)
	local cursor = lo
	for _, gap in sorted do
		local g0 = gap.at - gap.width / 2
		local g1 = gap.at + gap.width / 2
		if g1 <= lo or g0 >= hi then
			continue
		end
		g0 = math.max(g0, lo)
		g1 = math.min(g1, hi)
		slab(name, cursor, g0, baseY, baseY + height)
		-- the head over the opening
		slab(name .. "Head", g0, g1, baseY + gap.height, baseY + height)
		cursor = g1
	end
	slab(name, cursor, hi, baseY, baseY + height)
end

-- ---------------------------------------------------------------------------
-- WINDOWS
-- ---------------------------------------------------------------------------
-- Bays down an exterior wall at a fixed pitch, skipping anywhere an opening is
-- already drawn. Each is a stone surround, a lit leaf and a mullion -- the same
-- vocabulary as the Academy, so the ring buildings read as the same school.
local function windowsAlong(
	ctx: Ctx,
	from: { number },
	to: { number },
	baseY: number,
	height: number,
	gaps: { { at: number, width: number, height: number } },
	outward: number,
	thickness: number
)
	local dx, dz = to[1] - from[1], to[2] - from[2]
	local length = math.sqrt(dx * dx + dz * dz)
	local alongX = math.abs(dx) > math.abs(dz)
	local lo = if alongX then math.min(from[1], to[1]) else math.min(from[2], to[2])
	local across = if alongX then from[2] else from[1]

	local count = math.max(1, math.floor((length - WINDOW_PITCH) / WINDOW_PITCH))
	local spacing = length / (count + 1)
	for i = 1, count do
		local at = lo + i * spacing
		local blocked = false
		for _, gap in gaps do
			if at > gap.at - gap.width / 2 - WINDOW_W and at < gap.at + gap.width / 2 + WINDOW_W then
				blocked = true
				break
			end
		end
		if blocked then
			continue
		end
		-- Size the window to the STOREY, not to a constant.
		--
		-- With a fixed 11-stud light on a 5-stud sill, a sixteen-stud storey
		-- fails the headroom guard for every opening, and the guard is a silent
		-- `continue` -- so the Secret Rooftop block came out with four blank
		-- elevations and the parts simply were not there. Nothing in the suite
		-- could tell that from a building that had no windows drawn.
		local wh = math.clamp(height * 0.44, 4.5, 13.0)
		local sill = math.max(3.0, height * 0.22)
		local y = baseY + sill + wh / 2
		if y + wh / 2 > baseY + height - 1.2 then
			continue
		end
		-- An exterior wall is eight studs thick and centred on the building
		-- line, so its outer face is four studs out from the centreline. The
		-- first version pushed windows out by one or two studs, which put every
		-- one of them INSIDE the masonry: twenty-one windows on the gymnasium,
		-- none of them visible from anywhere.
		local face = thickness / 2
		local function at3(w: number, h: number, d: number, push: number)
			local size = if alongX then Vector3.new(w, h, d) else Vector3.new(d, h, w)
			local cf = if alongX
				then CFrame.new(at, y, across + outward * (face + push))
				else CFrame.new(across + outward * (face + push), y, at)
			return size, cf
		end
		local sSize, sCf = at3(WINDOW_W + 3.0, wh + 3.0, 1.4, -0.5)
		ctx.tag(ctx.part({ Name = "PlanWindowSurround", Size = sSize, CFrame = sCf, Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
		local gSize, gCf = at3(WINDOW_W, wh, 0.6, 0.4)
		local pane = ctx.part({ Name = "PlanWindowGlass", Size = gSize, CFrame = gCf, Color = GLASS_LIT, Material = Enum.Material.Neon, Transparency = 0.34, Parent = ctx.parent })
		pane.CanCollide = false
		pane.CastShadow = false
		local mSize, mCf = at3(0.5, wh, 0.8, 0.7)
		ctx.part({ Name = "PlanWindowMullion", Size = mSize, CFrame = mCf, Color = FRAME, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		local silSize, silCf = at3(WINDOW_W + 4.0, 0.7, 2.2, 0.1)
		local sill = ctx.part({ Name = "PlanWindowSill", Size = silSize, CFrame = silCf, Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent })
		sill.CFrame = silCf - Vector3.new(0, wh / 2 + 0.4, 0)
		sill.CanCollide = false
		ctx.tag(sill, "TexAshlar")
		if i % 2 == 1 then
			local light = Instance.new("PointLight")
			light.Color = Kit.LANTERN
			light.Brightness = 0.8
			light.Range = 22
			light.Shadows = false
			light.Parent = pane
		end
	end
end

-- ---------------------------------------------------------------------------
-- BUILD
-- ---------------------------------------------------------------------------
function PlanBuilder.build(ctx: Ctx, name: string)
	local b = CampusPlan.building(name)
	if not b then
		warn("[PlanBuilder] no drawing for " .. name)
		return
	end
	local K = kit(ctx)
	local rect = b.rect
	local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
	local width, depth = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local top = b.storeys[#b.storeys]
	local eaves = top.y + top.height

	-- ---- doorways, gathered per storey so the walls can be cut for them ----
	local openings: { [number]: { { at: number, width: number, height: number, axis: string, across: number } } } = {}
	for i in b.storeys do
		openings[i] = {}
		for _, door in CampusPlan.doors(b, i) do
			if not door.orphan then
				table.insert(openings[i], {
					at = if door.axis == "z" then door.x else door.z,
					width = door.width,
					height = door.height,
					axis = door.axis,
					across = if door.axis == "z" then door.z else door.x,
				})
			end
		end
	end
	-- the ways in from outside are openings in the exterior wall
	for _, e in b.entrances or {} do
		local vertical = e.facing == "east" or e.facing == "west"
		table.insert(openings[1], {
			at = if vertical then e.at.z else e.at.x,
			width = e.width,
			height = CampusPlan.DOOR_HEIGHT + 2,
			axis = if vertical then "x" else "z",
			across = if vertical then e.at.x else e.at.z,
		})
	end

	for index, storey in b.storeys do
		local cells = CampusPlan.cells(b, index)
		if #cells == 0 then
			continue
		end

		-- ---- the stairwell holes this storey's floor has to be cut for ----
		-- A stair that arrives at this storey comes up THROUGH its floor. With
		-- the floor laid whole, the flight climbed into the underside of the
		-- slab it was climbing to: four studs of headroom on the last third of
		-- every run in the building.
		local wells = {}
		for _, st in b.stairs or {} do
			for _, flight in st.flights do
				local top = math.max(flight.from[2], flight.to[2])
				if math.abs(top - storey.y) < 1.0 then
					local half = st.width / 2
					local runAxis = math.abs(flight.to[1] - flight.from[1]) > math.abs(flight.to[3] - flight.from[3])
					local x0 = math.min(flight.from[1], flight.to[1]) - (if runAxis then 1.0 else half)
					local x1 = math.max(flight.from[1], flight.to[1]) + (if runAxis then 1.0 else half)
					local z0 = math.min(flight.from[3], flight.to[3]) - (if runAxis then half else 1.0)
					local z1 = math.max(flight.from[3], flight.to[3]) + (if runAxis then half else 1.0)
					table.insert(wells, { x0, z0, x1, z1 })
				end
			end
		end

		-- ---- floor under every cell, ceiling over it ----
		for _, cell in cells do
			local r = cell.rect
			local w, d = r[3] - r[1], r[4] - r[2]
			local mx, mz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
			-- band the cell along z at every well edge, split each band along x
			-- around the wells that reach into it, and lay a slab only where no
			-- well covers it
			local zEdges = { r[2], r[4] }
			for _, h in wells do
				if h[1] < r[3] and h[3] > r[1] then
					table.insert(zEdges, math.clamp(h[2], r[2], r[4]))
					table.insert(zEdges, math.clamp(h[4], r[2], r[4]))
				end
			end
			table.sort(zEdges)
			for zi = 1, #zEdges - 1 do
				local z0, z1 = zEdges[zi], zEdges[zi + 1]
				if z1 - z0 > 0.5 then
					local zm = (z0 + z1) / 2
					local xEdges = { r[1], r[3] }
					for _, h in wells do
						if zm > h[2] and zm < h[4] then
							table.insert(xEdges, math.clamp(h[1], r[1], r[3]))
							table.insert(xEdges, math.clamp(h[3], r[1], r[3]))
						end
					end
					table.sort(xEdges)
					for xi = 1, #xEdges - 1 do
						local x0, x1 = xEdges[xi], xEdges[xi + 1]
						local xm = (x0 + x1) / 2
						local covered = false
						for _, h in wells do
							if xm > h[1] and xm < h[3] and zm > h[2] and zm < h[4] then
								covered = true
							end
						end
						if not covered and x1 - x0 > 0.5 then
							ctx.tag(ctx.part({
								Name = "PlanFloor",
								Size = Vector3.new(x1 - x0, FLOOR_THICK, z1 - z0),
								CFrame = CFrame.new((x0 + x1) / 2, storey.y - FLOOR_THICK / 2, (z0 + z1) / 2),
								Color = FLOOR,
								Parent = ctx.parent,
							}), "TexFloorTile")
						end
					end
				end
			end
			local ceil = ctx.part({
				Name = "PlanCeiling",
				Size = Vector3.new(w, CEIL_THICK, d),
				-- bedded UP into the storey above rather than flush with it:
				-- flush is what put sixty thousand square studs of the Academy's
				-- ceiling in the same plane as its own floor
				CFrame = CFrame.new(mx, storey.y + storey.height - CEIL_THICK / 2 + 0.15, mz),
				Color = CEILING,
				Parent = ctx.parent,
			})
			ceil.CanCollide = false
			ctx.tag(ceil, "TexCeiling")

			-- a light in every room, so light_check has something to find
			if cell.kind == "room" or (cell.row == 2 and cell.col == 1) then
				local lamp = ctx.part({
					Name = "PlanRoomLight",
					Size = Vector3.new(math.min(w * 0.4, 10), 0.4, math.min(d * 0.3, 6)),
					CFrame = CFrame.new(mx, storey.y + storey.height - 1.6, mz),
					Color = Color3.fromRGB(255, 248, 230),
					Material = Enum.Material.Neon,
					Parent = ctx.parent,
				})
				lamp.CanCollide = false
				lamp.CastShadow = false
				local light = Instance.new("PointLight")
				light.Brightness = 1.3
				light.Range = math.max(w, d) * 0.9
				light.Color = Color3.fromRGB(255, 244, 218)
				light.Shadows = false
				light.Parent = lamp
			end
		end

		-- ---- the walls the drawing says exist, cut for the drawn openings ----
		for _, wall in CampusPlan.walls(b, index) do
			local vertical = math.abs(wall.to[1] - wall.from[1]) < 0.01
			local axis = if vertical then "x" else "z"
			local across = if vertical then wall.from[1] else wall.from[2]
			local gaps = {}
			for _, o in openings[index] do
				if o.axis == axis and math.abs(o.across - across) < wall.thickness / 2 + 0.6 then
					table.insert(gaps, { at = o.at, width = o.width, height = o.height })
				end
			end
			local nm = if wall.kind == "exterior" then "PlanWall" else "PlanPartition"
			local tagName = if wall.kind == "exterior" then "TexCoursedStone" else "TexPlaster"
			wallRun(ctx, nm, wall.from, wall.to, storey.y, storey.height, wall.thickness, gaps, tagName)

			if wall.kind == "exterior" then
				local outward = if vertical then (if across > cx then 1 else -1) else (if across > cz then 1 else -1)
				windowsAlong(ctx, wall.from, wall.to, storey.y, storey.height, gaps, outward, wall.thickness)
			end
		end
	end

	-- ---- the storey bands and the corners, so it is the same school ----
	for index, storey in b.storeys do
		if index == 1 then
			ctx.tag(ctx.part({ Name = "PlanPlinth", Size = Vector3.new(width + 3.0, 3.0, depth + 3.0), CFrame = CFrame.new(cx, 1.5, cz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
		else
			ctx.tag(ctx.part({ Name = "PlanStringCourse", Size = Vector3.new(width + 1.6, 1.5, depth + 1.6), CFrame = CFrame.new(cx, storey.y, cz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
		end
	end
	ctx.tag(ctx.part({ Name = "PlanCornice", Size = Vector3.new(width + 3.4, 2.2, depth + 3.4), CFrame = CFrame.new(cx, eaves + 1.1, cz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		ctx.tag(ctx.part({
			Name = "PlanQuoin",
			Size = Vector3.new(5.0, eaves - 1.0, 5.0),
			CFrame = CFrame.new(cx + corner.X * (width / 2 - 1.0), (eaves + 1.0) / 2, cz + corner.Z * (depth / 2 - 1.0)),
			Color = ASHLAR,
			Material = Enum.Material.Concrete,
			Parent = ctx.parent,
		}), "TexAshlar").CanCollide = false
	end

	-- ---- the roof, ridged along the long axis ----
	local runsX = width >= depth
	local rise = math.min(if runsX then depth else width, 90) * 0.30
	Kit.gableRoof(K, {
		x = cx,
		z = cz,
		width = if runsX then width + 4 else depth + 4,
		depth = if runsX then depth + 4 else width + 4,
		eaves = eaves + 2.2,
		rise = rise,
		runsX = runsX,
	})
	-- Gable walls closing the ends, or the roof is two planes over open air.
	--
	-- A gable is a TRIANGLE. Built as a rectangle -- which is what this was --
	-- it stands the full ridge height across the whole end of the building and
	-- reads as an enormous blank slab towering over its own roof, which is
	-- exactly what the first gymnasium looked like. Two mirrored wedges make
	-- the triangle: each is tall at the ridge and falls away to the eaves.
	local span = if runsX then depth + 4 else width + 4
	local endAt = if runsX then width / 2 + 1 else depth / 2 + 1
	for _, side in { -1, 1 } do
		for _, half in { -1, 1 } do
			local piece = Instance.new("WedgePart")
			piece.Name = "PlanGableEnd"
			piece.Anchored = true
			piece.CanCollide = false
			piece.Size = Vector3.new(2.0, rise, span / 2)
			-- yaw 180 puts the wedge's tall face at +Z, so the half on the -Z
			-- side of the ridge rises TOWARD the ridge instead of away from it
			local spin = if half > 0 then 0 else math.rad(180)
			local along = half * span / 4
			piece.CFrame = (if runsX
				then CFrame.new(cx + side * endAt, eaves + 2.2 + rise / 2, cz + along)
				else CFrame.new(cx + along, eaves + 2.2 + rise / 2, cz + side * endAt))
				* CFrame.Angles(0, spin + (if runsX then 0 else math.rad(90)), 0)
			piece.Color = STONE
			piece.Material = Enum.Material.Slate
			piece.Parent = ctx.parent
			ctx.tag(piece, "TexCoursedStone")
		end
		-- a verge board down each slope of the gable
		local vSize = if runsX then Vector3.new(3.2, 1.2, span + 1) else Vector3.new(span + 1, 1.2, 3.2)
		local vAt = if runsX
			then CFrame.new(cx + side * (endAt + 0.6), eaves + 2.6, cz)
			else CFrame.new(cx, eaves + 2.6, cz + side * (endAt + 0.6))
		ctx.tag(ctx.part({ Name = "PlanVerge", Size = vSize, CFrame = vAt, Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	end

	-- dormers down the long slopes, and a chimney on each gable end
	local slopeCount = math.max(2, math.floor((if runsX then width else depth) / 46))
	for i = 1, slopeCount do
		local t = (i - 0.5) / slopeCount
		local along = (if runsX then x0 else z0) + t * (if runsX then width else depth)
		local halfSpan = (if runsX then depth else width) / 2 + 2
		local dormerBase = eaves + 2.2 + rise * 0.34
		local set = halfSpan * 0.62
		-- both slopes. A pitched roof has two, and putting dormers on only one
		-- of them gives a building that looks finished from one side.
		for _, slope in { -1, 1 } do
			if runsX then
				Kit.dormer(K, { x = along, y = dormerBase, z = cz + slope * set, facing = if slope > 0 then 0 else 180, width = 7, height = 6 })
			else
				Kit.dormer(K, { x = cx + slope * set, y = dormerBase, z = along, facing = if slope > 0 then 90 else 270, width = 7, height = 6 })
			end
		end
	end
	for _, side in { -1, 1 } do
		local chx = if runsX then cx + side * (width / 2 - 8) else cx
		local chz = if runsX then cz else cz + side * (depth / 2 - 8)
		Kit.chimney(K, { x = chx, z = chz, base = eaves, height = rise + 10, width = 6 })
	end

	-- ---- the way in ----
	for _, e in b.entrances or {} do
		local vertical = e.facing == "east" or e.facing == "west"
		local outward = if e.facing == "east" or e.facing == "north" then 1 else -1
		local ex = if vertical then e.at.x + outward * 1.6 else e.at.x
		local ez = if vertical then e.at.z else e.at.z + outward * 1.6
		local doorH = CampusPlan.DOOR_HEIGHT + 2

		local leafSize = if vertical
			then Vector3.new(1.2, doorH - 1, e.width / 2 - 0.4)
			else Vector3.new(e.width / 2 - 0.4, doorH - 1, 1.2)
		for _, half in { -1, 1 } do
			local lx = if vertical then ex else ex + half * e.width / 4
			local lz = if vertical then ez + half * e.width / 4 else ez
			ctx.part({ Name = "PlanDoorLeaf", Size = leafSize, CFrame = CFrame.new(lx, (doorH - 1) / 2, lz), Color = TIMBER, Material = Enum.Material.WoodPlanks, Parent = ctx.parent }).CanCollide = false
		end
		-- an arch over it, and a name board over that
		local span = e.width + 4
		-- Turned to face the wall it is in, not transposed. Swapping x and z
		-- does not rotate an arch; it puts it somewhere else on the map.
		Kit.pointedArch(K, {
			x = ex,
			y = doorH + 0.4,
			z = ez,
			yaw = if vertical then math.rad(90) else 0,
			span = span,
			rise = span * 0.75,
			depth = 3.0,
			ring = 2.2,
			segments = 8,
		})
		for _, step in { 0, 1, 2 } do
			local sw = e.width + 8 - step * 2
			local size = if vertical then Vector3.new(6 - step * 1.2, 1, sw) else Vector3.new(sw, 1, 6 - step * 1.2)
			local px = if vertical then ex + outward * (2.4 + step * 2.2) else ex
			local pz = if vertical then ez else ez + outward * (2.4 + step * 2.2)
			ctx.tag(ctx.part({ Name = "PlanStep", Size = size, CFrame = CFrame.new(px, 0.5 - step * 0.34, pz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar")
		end
		for _, half in { -1, 1 } do
			-- clear of the wall face. The entrance point is on the building line
			-- and the wall is eight studs thick, so a lantern half a stud out
			-- from there is inside the masonry.
			local lx = if vertical then ex + outward * 3.4 else ex + half * (e.width / 2 + 1.5)
			local lz = if vertical then ez + half * (e.width / 2 + 1.5) else ez + outward * 3.4
			local glow = ctx.part({ Name = "PlanPorchGlow", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(lx, 13, lz), Color = Kit.LANTERN, Material = Enum.Material.Neon, Transparency = 0.4, Parent = ctx.parent })
			glow.CanCollide = false
			glow.CastShadow = false
			local lamp = Instance.new("PointLight")
			lamp.Color = Kit.LANTERN
			lamp.Brightness = 1.1
			lamp.Range = 26
			lamp.Shadows = false
			lamp.Parent = glow
			if ctx.prop then
				(ctx.prop :: any)("WallLantern", CFrame.new(lx, 13, lz))
			end
		end
	end

	-- ---- the stairs, exactly as drawn ----
	for _, st in b.stairs or {} do
		for _, flight in st.flights do
			local a, c = flight.from, flight.to
			local rise2 = c[2] - a[2]
			local steps = math.max(2, math.floor(rise2 / CampusPlan.STAIR_RISE))
			for i = 1, steps do
				local t = i / steps
				local tx = a[1] + (c[1] - a[1]) * t
				local tz = a[3] + (c[3] - a[3]) * t
				local ty = a[2] + rise2 * t
				local runAxis = math.abs(c[1] - a[1]) > math.abs(c[3] - a[3])
				local tread = if runAxis
					then Vector3.new(math.abs(c[1] - a[1]) / steps + 0.2, 0.6, st.width)
					else Vector3.new(st.width, 0.6, math.abs(c[3] - a[3]) / steps + 0.2)
				ctx.tag(ctx.part({ Name = "PlanTread", Size = tread, CFrame = CFrame.new(tx, ty - 0.3, tz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar")
			end
		end
		for _, pad in st.landings or {} do
			local r = pad.rect
			ctx.tag(ctx.part({
				Name = "PlanLanding",
				-- top at pad.y + 0.05, not pad.y: the tread at the head of the
				-- flight tops out at exactly pad.y and the two shared a plane
				Size = Vector3.new(r[3] - r[1], 0.9, r[4] - r[2]),
				CFrame = CFrame.new((r[1] + r[3]) / 2, pad.y - 0.4, (r[2] + r[4]) / 2),
				Color = ASHLAR,
				Material = Enum.Material.Concrete,
				Parent = ctx.parent,
			}), "TexAshlar")
		end
	end
end

return PlanBuilder

end)()
local __MapService

-- Generates all of Crumbworth High from parts at server start. No Studio assets needed.
-- Returns handles to everything other services attach behavior to.

local CollectionService = game:GetService("CollectionService")



local Kit = __Kit
local PlanBuilder = __PlanBuilder
local CampusPlan = __CampusPlan
local Grounds = __Grounds

local PropSizes = __PropSizes

export type Plot = {
	index: number,
	model: Model,
	cframe: CFrame, -- origin at plot center, LookVector = toward the hallway
	floor: BasePart,
	gate: BasePart,
	lockSwitch: BasePart,
	collectPad: BasePart,
	sign: BasePart,
	signGui: SurfaceGui,
	pileBillboard: BillboardGui,
	pileLabel: TextLabel,
	deskSlots: { CFrame }, -- world CFrames for crew members
	halfSize: Vector2, -- (x, z) half extents for inside tests
}

export type Map = {
	plots: { Plot },
	trim: { TrimRun },
	props: { PropRequest },
	library: Vector3,
	conveyorStart: Vector3,
	conveyorEnd: Vector3,
	trophyCashBoard: BasePart,
	trophyAuraBoard: BasePart,
	cliqueBoards: { [string]: BasePart },
	dormBeds: { BasePart },
	detentionSpot: Vector3,
	infirmary: Vector3,
	secretDoors: { BasePart },
	houseBoard: BasePart?,
	sanctumSpawn: Vector3,
	folder: Folder,
}

local MapService = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- Tag a part for the client-side EditableImage texture painter.
local function tag(p: BasePart, tagName: string): BasePart
	CollectionService:AddTag(p, tagName)
	return p
end

local function signText(parent: BasePart, text: string, textColor: Color3, face: Enum.NormalId?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
	return gui
end

local function buildPlot(index: number, cf: CFrame, parent: Instance): Plot
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	-- 44 deep, not 48. The front row's plots run from the corridor at z = 79
	-- and the school's facade is at 124, so at 48 they ran three studs THROUGH
	-- the front wall -- which put four ten-stud blue locker walls on the
	-- outside of the building, in a band right across the front of the school.
	local width, depth = 62, 44 -- x, z in plot-local space (+Z local = front/hallway)

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(width, 1, depth),
		CFrame = cf * CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(224, 218, 189),
		Parent = model,
	})

	-- locker wall along the back
	part({
		Name = "LockerWall",
		Size = Vector3.new(width - 4, 10, 2),
		CFrame = cf * CFrame.new(0, 5, -(depth / 2 - 1)),
		Color = Palette.LockerBlue,
		Parent = model,
	})
	-- locker detail: seams, handles, vents
	for i = 1, 7 do
		part({
			Name = "LockerSeam",
			Size = Vector3.new(0.4, 9, 0.4),
			CFrame = cf * CFrame.new(-24 + i * 6, 4.5, -(depth / 2 - 2.2)),
			Color = Palette.LockerBlueDark,
			Parent = model,
		})
	end
	for i = 0, 7 do
		local lockerX = -21 + i * 6
		part({
			Name = "LockerHandle",
			Size = Vector3.new(0.5, 1.2, 0.4),
			CFrame = cf * CFrame.new(lockerX + 1.8, 4.6, -(depth / 2 - 2.15)),
			Color = Palette.BusYellow,
			Material = Enum.Material.Metal,
			Parent = model,
		})
		part({
			Name = "LockerVent",
			Size = Vector3.new(2.6, 0.5, 0.3),
			CFrame = cf * CFrame.new(lockerX, 7.6, -(depth / 2 - 2.1)),
			Color = Palette.LockerBlueDark,
			Parent = model,
		})
	end

	-- side rails so the plot reads as a room
	for _, side in { -1, 1 } do
		part({
			Name = "SideRail",
			Size = Vector3.new(1.5, 3, depth),
			CFrame = cf * CFrame.new(side * (width / 2 - 0.75), 1.5, 0),
			Color = Palette.LockerBlueDark,
			Parent = model,
		})
	end

	-- desks (crew slots): two rows of 6
	local deskSlots: { CFrame } = {}
	for row = 0, 1 do
		for col = 0, 5 do
			local x = -25 + col * 10
			local z = -6 - row * 11
			local deskCf = cf * CFrame.new(x, 0, z)
			-- A school desk, not a box. Ninety-six of these stand in the plots
			-- and the player looks at them for the whole game; each was one
			-- 4.5 x 2.4 x 3 slab. Seven pieces now: the lid, the apron under
			-- its front edge, four legs set in from the corners, and a book
			-- left open on top, which is the piece that says "desk" from across
			-- the room more than the shape does.
			local LID = Color3.fromRGB(178, 138, 92)
			local FRAME = Color3.fromRGB(64, 66, 74)
			part({ Name = "DeskLid", Size = Vector3.new(4.5, 0.32, 3), CFrame = deskCf * CFrame.new(0, 2.28, 0), Color = LID, Material = Enum.Material.WoodPlanks, Parent = model })
			part({ Name = "DeskApron", Size = Vector3.new(4.2, 0.7, 0.28), CFrame = deskCf * CFrame.new(0, 1.8, -1.3), Color = LID, Material = Enum.Material.WoodPlanks, Parent = model })
			for _, leg in { Vector3.new(-1.9, 0, -1.2), Vector3.new(1.9, 0, -1.2), Vector3.new(-1.9, 0, 1.2), Vector3.new(1.9, 0, 1.2) } do
				part({ Name = "DeskLeg", Size = Vector3.new(0.24, 2.12, 0.24), CFrame = deskCf * CFrame.new(leg.X, 1.06, leg.Z), Color = FRAME, Material = Enum.Material.Metal, Parent = model }).CanCollide = false
			end
			part({ Name = "DeskBook", Size = Vector3.new(1.6, 0.16, 1.1), CFrame = deskCf * CFrame.new(-0.7, 2.52, 0.2) * CFrame.Angles(0, 0.22, 0), Color = Color3.fromRGB(206, 198, 180), Material = Enum.Material.SmoothPlastic, Parent = model }).CanCollide = false
			-- the student stands behind the desk, facing the front of the plot
			table.insert(deskSlots, deskCf * CFrame.new(0, 0, -2.6) * CFrame.Angles(0, 0, 0))
		end
	end

	-- collect pad
	local collectPad = part({
		Name = "CollectPad",
		Size = Vector3.new(10, 0.4, 8),
		-- proud of the plot floor rather than flush in it
		CFrame = cf * CFrame.new(0, 0.32, 16),
		Color = Palette.CashGreen,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	local pileBillboard = Instance.new("BillboardGui")
	pileBillboard.Name = "PileBillboard"
	pileBillboard.Size = UDim2.fromScale(9, 2.4)
	pileBillboard.StudsOffset = Vector3.new(0, 6, 0)
	pileBillboard.AlwaysOnTop = true
	pileBillboard.MaxDistance = 110
	pileBillboard.Parent = collectPad
	local pileLabel = Instance.new("TextLabel")
	pileLabel.Size = UDim2.fromScale(1, 1)
	pileLabel.BackgroundTransparency = 1
	pileLabel.Font = Enum.Font.FredokaOne
	pileLabel.TextScaled = true
	pileLabel.TextColor3 = Palette.CashGreen
	pileLabel.TextStrokeTransparency = 0.4
	pileLabel.Text = "$0"
	pileLabel.Parent = pileBillboard

	-- lock switch
	local lockSwitch = part({
		Name = "LockSwitch",
		Size = Vector3.new(2, 5, 2),
		CFrame = cf * CFrame.new(width / 2 - 3, 2.5, 18),
		Color = Palette.DetentionRed,
		Parent = model,
	})

	-- laser gate across the entrance, in a frame that emits it. The field on
	-- its own was one translucent slab hanging in a doorway with nothing
	-- holding it up.
	for _, side in { -1, 1 } do
		local jx = side * (width / 2 - 1.2)
		part({ Name = "GateJamb", Size = Vector3.new(2.4, 13, 2.4), CFrame = cf * CFrame.new(jx, 6.5, depth / 2), Color = Color3.fromRGB(72, 76, 84), Material = Enum.Material.Metal, Parent = model })
		part({ Name = "GateJambFoot", Size = Vector3.new(3.6, 0.8, 3.6), CFrame = cf * CFrame.new(jx, 0.4, depth / 2), Color = Color3.fromRGB(52, 56, 62), Material = Enum.Material.Metal, Parent = model })
		for i = 0, 3 do
			local emitter = part({
				Name = "GateEmitter",
				Size = Vector3.new(0.5, 1.4, 1.4),
				CFrame = cf * CFrame.new(jx - side * 1.3, 2.0 + i * 2.8, depth / 2),
				Color = Palette.CashGreen,
				Material = Enum.Material.Neon,
				Parent = model,
			})
			emitter.CanCollide = false
			emitter.CastShadow = false
		end
	end
	part({ Name = "GateHead", Size = Vector3.new(width, 2.2, 2.4), CFrame = cf * CFrame.new(0, 13.6, depth / 2), Color = Color3.fromRGB(72, 76, 84), Material = Enum.Material.Metal, Parent = model })
	part({ Name = "GateHeadStripe", Size = Vector3.new(width - 1, 0.7, 2.6), CFrame = cf * CFrame.new(0, 12.7, depth / 2), Color = Palette.BusYellow, Material = Enum.Material.SmoothPlastic, Parent = model }).CanCollide = false
	local gate = part({
		Name = "Gate",
		Size = Vector3.new(width - 3, 12, 1),
		CFrame = cf * CFrame.new(0, 6, depth / 2),
		Color = Palette.CashGreen,
		Material = Enum.Material.ForceField,
		CanCollide = false,
		Transparency = 0.7,
		Parent = model,
	})

	-- name sign above the entrance
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(26, 5, 1),
		-- 0.6 proud of the gate face: the gate is a 1-thick slab on the same
		-- plane and the two speckled against each other across the whole board
		CFrame = cf * CFrame.new(0, 14, depth / 2 + 0.6),
		Color = Palette.Blackboard,
		Parent = model,
	})
	local signGui = signText(sign, "HOMEROOM " .. index, Palette.Chalk, Enum.NormalId.Front)
	-- also readable from the back
	signText(sign, "HOMEROOM " .. index, Palette.Chalk, Enum.NormalId.Back)

	model.Parent = parent

	return {
		index = index,
		model = model,
		cframe = cf,
		floor = floor,
		gate = gate,
		lockSwitch = lockSwitch,
		collectPad = collectPad,
		sign = sign,
		signGui = signGui,
		pileBillboard = pileBillboard,
		pileLabel = pileLabel,
		deskSlots = deskSlots,
		halfSize = Vector2.new(width / 2, depth / 2),
	}
end

-- A courtyard lab annex: a glass-walled pavilion with an open south side, so
-- the science subjects get real rooms without cutting new space out of a
-- floor plan that is already full.
local function buildPavilion(
	parent: Instance,
	name: string,
	center: Vector3,
	size: Vector2,
	label: string,
	accent: Color3,
	glass: Color3
)
	local half = Vector2.new(size.X / 2, size.Y / 2)
	part({
		Name = name .. "Floor",
		Size = Vector3.new(size.X, 1, size.Y),
		CFrame = CFrame.new(center) * CFrame.new(0, -0.4, 0),
		Color = Color3.fromRGB(226, 226, 222),
		Material = Enum.Material.CeramicTiles,
		Parent = parent,
	})
	-- three glass walls; the fourth side is the way in
	local walls = {
		{ pos = Vector3.new(0, 7, -half.Y), size = Vector3.new(size.X, 14, 1) },
		{ pos = Vector3.new(-half.X, 7, 0), size = Vector3.new(1, 14, size.Y) },
		{ pos = Vector3.new(half.X, 7, 0), size = Vector3.new(1, 14, size.Y) },
	}
	for i, wall in walls do
		local pane = part({
			Name = name .. "Glass" .. i,
			Size = wall.size,
			CFrame = CFrame.new(center) * CFrame.new(wall.pos),
			Color = glass,
			Material = Enum.Material.Glass,
			Transparency = 0.62,
			Parent = parent,
		})
		pane.Reflectance = 0.08
	end
	-- frame posts at the corners and either side of the opening
	for _, corner in { Vector3.new(-half.X, 0, -half.Y), Vector3.new(half.X, 0, -half.Y), Vector3.new(-half.X, 0, half.Y), Vector3.new(half.X, 0, half.Y) } do
		part({
			Name = name .. "Post",
			Size = Vector3.new(1.6, 15, 1.6),
			CFrame = CFrame.new(center) * CFrame.new(corner + Vector3.new(0, 7.5, 0)),
			Color = accent,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end
	-- lintel over the open side, so it reads as a doorway and not a missing wall
	part({
		Name = name .. "Lintel",
		Size = Vector3.new(size.X, 2, 1.6),
		CFrame = CFrame.new(center) * CFrame.new(0, 14, half.Y),
		Color = accent,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local roof = part({
		Name = name .. "Roof",
		Size = Vector3.new(size.X + 2, 0.8, size.Y + 2),
		CFrame = CFrame.new(center) * CFrame.new(0, 15.2, 0),
		Color = glass,
		Material = Enum.Material.Glass,
		Transparency = 0.5,
		Parent = parent,
	})
	roof.Reflectance = 0.12
	-- benches down both sides: this is a lab, not an empty box
	for _, bx in { -half.X + 5, half.X - 5 } do
		part({
			Name = name .. "Bench",
			Size = Vector3.new(5, 3.2, size.Y - 10),
			CFrame = CFrame.new(center) * CFrame.new(bx, 1.6, 0),
			Color = Color3.fromRGB(64, 78, 74),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	local sign = part({
		Name = name .. "Sign",
		Size = Vector3.new(size.X - 6, 4, 0.6),
		CFrame = CFrame.new(center) * CFrame.new(0, 17.6, half.Y),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(sign, label, accent, Enum.NormalId.Front)
	signText(sign, label, accent, Enum.NormalId.Back)
end

-- ===== campus grounds: the three places that are not the school building =====
--
-- The floor plan is full, so these sit outside it. Paths run back to the
-- building so they read as part of the campus and not as scenery dropped on a
-- lawn. (The tennis stadium east and the pool west were two of these; the
-- Sports Field replaced both.)

local function buildCampusPath(parent: Instance, from: Vector3, to: Vector3, width: number, over: boolean?)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local mid = from:Lerp(to, 0.5)
	local path = part({
		Name = "CampusPath",
		Size = Vector3.new(width, 0.4, length),
		-- `over` raises the path onto the next course, for the one that runs
		-- ACROSS another. Two paths crossing at the same height is 343 square
		-- studs of flicker at the junction, and a junction is exactly where a
		-- player stands and looks around.
		CFrame = CFrame.lookAt(mid + Vector3.new(0, if over then 0.17 else 0.05, 0), mid + delta.Unit + Vector3.new(0, if over then 0.17 else 0.05, 0)),
		Color = Color3.fromRGB(196, 190, 176),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	tag(path, "TexCourtPaving")
end

-- Where the secret bookshelf sits in the library's west wall. The wall is
-- built eight hundred lines before the door is, so the one number both of them
-- need lives up here: LIB_SHAFT.Z below is the same value, and
-- tools/doorway_check.py proves the opening and the shelf still line up.
-- THE LIBRARY MOVED to its drawn ground at (-320, -300), delta (-320, -68).
-- The pyramid sanctum hangs off it, and a survey of the whole chain showed
-- the risk is not spread over fifty coordinates: SanctumMap builds every one
-- of its 1198 lines in estate-local space and passes them through
-- ORIGIN + ROT * (v * SCALE), and MapService's descent is written as
-- LIB_SHAFT.X +/- n throughout. Six absolutes carry the whole thing, and
-- they are all here.
local LIBRARY_DOOR_Z = -290

local function buildLibrary(parent: Instance, center: Vector3)
	local W, D, H = 92, 68, 26
	local halfW, halfD = W / 2, D / 2
	tag(part({
		Name = "LibraryFloor",
		Size = Vector3.new(W, 1, D),
		CFrame = CFrame.new(center) * CFrame.new(0, -0.4, 0),
		Color = Color3.fromRGB(150, 118, 88),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	}), "TexWood")

	-- Stone shell, open in the middle of the south face for the doors -- and
	-- open in the WEST face for the secret bookshelf, which is the whole point
	-- of this building. The west wall used to run unbroken from corner to
	-- corner: the shelf slid aside on the right four digits and left you
	-- looking at twenty-six studs of solid sandstone.
	--
	-- The opening is cut to the shelf: fourteen wide on z, fourteen high,
	-- centred on the shaft's z so the shelf covers it exactly when shut.
	local doorZ = LIBRARY_DOOR_Z - center.Z
	local doorHalf, doorH = 7, 14
	local walls = {
		{ size = Vector3.new(W, H, 2), offset = Vector3.new(0, H / 2, -halfD) },
		-- west wall, in three pieces round the secret door
		{
			size = Vector3.new(2, H, (doorZ - doorHalf) + halfD),
			offset = Vector3.new(-halfW, H / 2, (-halfD + doorZ - doorHalf) / 2),
		},
		{
			size = Vector3.new(2, H, halfD - (doorZ + doorHalf)),
			offset = Vector3.new(-halfW, H / 2, (doorZ + doorHalf + halfD) / 2),
		},
		{
			size = Vector3.new(2, H - doorH, doorHalf * 2),
			offset = Vector3.new(-halfW, doorH + (H - doorH) / 2, doorZ),
		},
		{ size = Vector3.new(2, H, D), offset = Vector3.new(halfW, H / 2, 0) },
		{ size = Vector3.new(halfW - 8, H, 2), offset = Vector3.new(-(halfW / 2 + 4), H / 2, halfD) },
		{ size = Vector3.new(halfW - 8, H, 2), offset = Vector3.new(halfW / 2 + 4, H / 2, halfD) },
		{ size = Vector3.new(16, 8, 2), offset = Vector3.new(0, H - 4, halfD) }, -- over the doors
	}
	for i, wall in walls do
		tag(part({
			Name = "LibraryWall" .. i,
			Size = wall.size,
			CFrame = CFrame.new(center) * CFrame.new(wall.offset),
			Color = Color3.fromRGB(206, 198, 182),
			Material = Enum.Material.Sandstone,
			Parent = parent,
		}), "TexCoursedStone")
	end

	-- WINDOWS. The library had none: ninety-two studs of blank sandstone on
	-- each long side, a portico, and nothing else. build_check's new
	-- blank-elevation rule is what found it -- no other check can see an
	-- absence, because absence looks exactly like a building drawn without
	-- windows.
	--
	-- Tall round-headed lights, four down the north face and four down the
	-- south, skipping the middle of the south where the doors are and the west
	-- face entirely, because that one has the secret bookshelf in it.
	local WIN_W, WIN_H, WIN_SILL = 9, 15, 5
	for _, face in { { dz = -halfD, out = -1 }, { dz = halfD, out = 1 } } do
		for _, wx in { -34, -18, 18, 34 } do
			if face.out > 0 and math.abs(wx) < 12 then
				continue
			end
			local at = CFrame.new(center) * CFrame.new(wx, WIN_SILL + WIN_H / 2, face.dz + face.out * 1.3)
			tag(part({ Name = "LibraryWinSurround", Size = Vector3.new(WIN_W + 3.4, WIN_H + 3.4, 1.6), CFrame = at, Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
			local pane = part({ Name = "LibraryWindow", Size = Vector3.new(WIN_W, WIN_H, 0.7), CFrame = at * CFrame.new(0, 0, face.out * 0.5), Color = Color3.fromRGB(255, 196, 107), Material = Enum.Material.Neon, Transparency = 0.34, Parent = parent })
			pane.CanCollide = false
			pane.CastShadow = false
			part({ Name = "LibraryWinMullion", Size = Vector3.new(0.6, WIN_H, 0.9), CFrame = at * CFrame.new(0, 0, face.out * 0.8), Color = Color3.fromRGB(42, 42, 40), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "LibraryWinTransom", Size = Vector3.new(WIN_W, 0.6, 0.9), CFrame = at * CFrame.new(0, WIN_H / 4, face.out * 0.8), Color = Color3.fromRGB(42, 42, 40), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			tag(part({ Name = "LibraryWinSill", Size = Vector3.new(WIN_W + 4.4, 0.8, 2.4), CFrame = at * CFrame.new(0, -(WIN_H / 2 + 0.6), face.out * 0.3), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
			-- the round head, which is what makes it a library and not a shed
			local arch = Instance.new("Part")
			arch.Name = "LibraryWinHead"
			arch.Shape = Enum.PartType.Cylinder
			arch.Anchored = true
			arch.CanCollide = false
			arch.Size = Vector3.new(1.6, WIN_W + 3.4, WIN_W + 3.4)
			arch.CFrame = at * CFrame.new(0, WIN_H / 2, 0) * CFrame.Angles(0, math.rad(90), math.rad(90))
			arch.Color = Color3.fromRGB(201, 191, 169)
			arch.Material = Enum.Material.Concrete
			arch.Parent = parent
			tag(arch, "TexAshlar")
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 220, 160)
			glow.Brightness = 0.9
			glow.Range = 24
			glow.Shadows = false
			glow.Parent = pane
		end
	end

	-- portico: six columns and a pediment over the entrance
	-- Slimmer and further apart than they were: at 4 studs across on a 13 stud
	-- pitch the colonnade read as a fence and hid the building behind it. Each
	-- column now gets a base and a capital, without which a cylinder is a pipe.
	for i = -2, 2 do
		local cx = i * 18
		part({
			Name = "LibraryColumn",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(H - 3, 3.2, 3.2),
			CFrame = CFrame.new(center) * CFrame.new(cx, (H - 3) / 2 + 1.6, halfD + 9) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(232, 226, 212),
			Material = Enum.Material.Marble,
			Parent = parent,
		})
		part({ Name = "LibraryColumnBase", Size = Vector3.new(4.6, 1.6, 4.6), CFrame = CFrame.new(center) * CFrame.new(cx, 0.8, halfD + 9), Color = Color3.fromRGB(226, 220, 206), Material = Enum.Material.Marble, Parent = parent })
		part({ Name = "LibraryColumnCap", Size = Vector3.new(4.8, 1.4, 4.8), CFrame = CFrame.new(center) * CFrame.new(cx, H - 0.7, halfD + 9), Color = Color3.fromRGB(236, 231, 218), Material = Enum.Material.Marble, Parent = parent })
	end
	-- entablature the columns actually carry
	part({ Name = "LibraryArchitrave", Size = Vector3.new(W - 4, 2.6, 7), CFrame = CFrame.new(center) * CFrame.new(0, H + 1.3, halfD + 9), Color = Color3.fromRGB(236, 231, 218), Material = Enum.Material.Marble, Parent = parent })
	part({
		Name = "LibraryPediment",
		Size = Vector3.new(W - 6, 5, 18),
		CFrame = CFrame.new(center) * CFrame.new(0, H + 2, halfD + 5),
		Color = Color3.fromRGB(232, 226, 212),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	local plaque = part({
		Name = "LibrarySign",
		Size = Vector3.new(40, 4, 0.6),
		CFrame = CFrame.new(center) * CFrame.new(0, H + 2, halfD + 14),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(plaque, "CRUMBWORTH LIBRARY", Palette.BusYellow, Enum.NormalId.Front)
	signText(plaque, "CRUMBWORTH LIBRARY", Palette.BusYellow, Enum.NormalId.Back)
	signText(plaque, "SILENCE, PLEASE", Palette.BusYellow, Enum.NormalId.Back)

	local roof = part({
		Name = "LibraryRoof",
		Size = Vector3.new(W + 4, 1.5, D + 4),
		CFrame = CFrame.new(center) * CFrame.new(0, H + 0.5, 0),
		Color = Color3.fromRGB(96, 90, 84),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	local _ = roof

	-- stacks: rows of shelves down both halves, with an aisle between
	for row = -1, 1 do
		for side = 0, 1 do
			local x = row * 26 + (side == 0 and -7 or 7)
			part({
				Name = "LibraryShelf",
				Size = Vector3.new(5, 12, 40),
				CFrame = CFrame.new(center) * CFrame.new(x, 6, -8),
				Color = Color3.fromRGB(146, 106, 72),
				Material = Enum.Material.WoodPlanks,
				Parent = parent,
			})
			-- a band of spines so the shelves are not brown slabs
			for shelfLevel = 1, 4 do
				part({
					Name = "LibraryBooks",
					Size = Vector3.new(6, 1.8, 38),
					CFrame = CFrame.new(center) * CFrame.new(x, shelfLevel * 2.7, -8),
					-- spines, not mud: a wider spread so a wall of books reads
					-- as many books rather than one brown mass
					Color = Color3.fromRGB(
						math.clamp(150 + (row + 1) * 34 + side * 26, 60, 250),
						math.clamp(96 + shelfLevel * 30 - side * 18, 50, 245),
						math.clamp(104 + side * 52 - shelfLevel * 12, 50, 240)
					),
					Material = Enum.Material.Fabric,
					Parent = parent,
				})
			end
		end
	end

	-- reading floor at the front: this is where the study desks land
	tag(part({
		Name = "LibraryReadingFloor",
		Size = Vector3.new(W - 8, 0.3, 22),
		CFrame = CFrame.new(center) * CFrame.new(0, 0.2, halfD - 13),
		Color = Color3.fromRGB(126, 60, 52),
		Material = Enum.Material.Carpet,
		Parent = parent,
	}), "TexCarpet")

	for _, lampX in { -30, 0, 30 } do
		part({
			Name = "LibraryChandelier",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(5, 5, 5),
			CFrame = CFrame.new(center) * CFrame.new(lampX, H - 6, 0),
			Color = Color3.fromRGB(255, 236, 190),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 1.6
		light.Range = 44
		light.Color = Color3.fromRGB(255, 236, 196)
		light.Parent = parent:FindFirstChild("LibraryChandelier") :: Instance
	end
end

-- The tennis stadium and the swimming pool are gone.
--
-- The plan retired both when the Sports Field was drawn -- a running track, a
-- pitch and four floodlight masts at (300, 150) to (580, 320) do the job of a
-- two-court stadium and an outdoor pool between them. They stayed built
-- anyway, and by the time the drawing caught up they were standing inside two
-- buildings: the pool at (-340, -20) is inside the Detention Hall, which
-- CampusPlan draws at (-485, -40) to (-315, 80), and the tennis stands ran
-- x 244..435 across the Parking Lot, drawn at (335, -35) to (525, 115). Two
-- venues nothing could see because two buildings were standing in them.
--
-- The pool took a terrain water fill and an 80 x 48 air-carve with it; both
-- are removed here, so the basin is grass again rather than an unlit hole in
-- the west lawn with a building over it.

local function buildZone(parent: Instance, name: string, center: Vector3, size: Vector2, color: Color3, label: string, material: Enum.Material?): BasePart
	local floor = part({
		Name = name .. "Floor",
		Size = Vector3.new(size.X, 1, size.Y),
		CFrame = CFrame.new(center) * CFrame.new(0, -0.5, 0),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	-- A plaque high on the wall, not a billboard on a post. The post used to be
	-- a solid 9-stud pillar standing at floor level in the middle of the room's
	-- edge, which is what was blocking doorways all over the school.
	local sign = part({
		Name = name .. "Sign",
		Size = Vector3.new(math.min(size.X - 6, 26), 3.4, 0.5),
		CFrame = CFrame.new(center) * CFrame.new(0, 12.4, -size.Y / 2 + 0.9),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	sign.CanCollide = false
	signText(sign, label, Palette.Chalk, Enum.NormalId.Front)
	signText(sign, label, Palette.Chalk, Enum.NormalId.Back)
	return floor
end

-- ===== decorations (all parts, no assets) =====

local function buildBus(parent: Instance, cf: CFrame)
	local body = part({
		Name = "BusBody",
		Size = Vector3.new(24, 9, 9),
		CFrame = cf * CFrame.new(0, 6.5, 0),
		Color = Palette.BusYellow,
		Parent = parent,
	})
	part({
		Name = "BusHood",
		Size = Vector3.new(4, 5, 9),
		CFrame = cf * CFrame.new(14, 4.5, 0),
		Color = Palette.BusYellow,
		Parent = parent,
	})
	-- windows strip
	part({
		Name = "BusWindows",
		Size = Vector3.new(20, 3, 9.2),
		CFrame = cf * CFrame.new(0, 8, 0),
		Color = Color3.fromRGB(140, 190, 220),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Parent = parent,
	})
	-- stripe
	part({
		Name = "BusStripe",
		Size = Vector3.new(24.2, 0.8, 9.3),
		CFrame = cf * CFrame.new(0, 5.4, 0),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	-- wheels
	for _, offset in { Vector3.new(-8, 2, 4.6), Vector3.new(8, 2, 4.6), Vector3.new(-8, 2, -4.6), Vector3.new(8, 2, -4.6) } do
		local wheel = part({
			Name = "BusWheel",
			Size = Vector3.new(3.4, 3.4, 1.2),
			CFrame = cf * CFrame.new(offset) * CFrame.Angles(0, math.rad(90), math.rad(90)),
			Color = Color3.fromRGB(30, 30, 30),
			Parent = parent,
		})
		wheel.Shape = Enum.PartType.Cylinder
	end
	local sign = part({
		Name = "BusSign",
		Size = Vector3.new(18, 2.2, 0.4),
		CFrame = cf * CFrame.new(0, 10.6, 0),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	-- clear of the bodywork: at the bus's own centre both faces of this read
	-- into eighteen studs of yellow panel
	sign.CFrame = cf * CFrame.new(0, 10.6, 4.9)
	signText(sign, "CRUMBWORTH HIGH", Palette.BusYellow, Enum.NormalId.Front)
	signText(sign, "CRUMBWORTH HIGH", Palette.BusYellow, Enum.NormalId.Back)
	local _ = body
end

local function buildBenches(parent: Instance)
	for x = -90, 90, 60 do
		for _, side in { -1, 1 } do
			local cf = CFrame.new(x + 30, 0, side * 20)
			part({
				Name = "BenchSeat",
				Size = Vector3.new(8, 0.8, 2.4),
				CFrame = cf * CFrame.new(0, 1.6, 0),
				Color = Color3.fromRGB(160, 120, 76),
				Material = Enum.Material.Wood,
				Parent = parent,
			})
			for _, legX in { -3.2, 3.2 } do
				part({
					Name = "BenchLeg",
					Size = Vector3.new(0.8, 1.6, 2.4),
					CFrame = cf * CFrame.new(legX, 0.8, 0),
					Color = Palette.LockerBlueDark,
					Parent = parent,
				})
			end
		end
	end
end

-- Superseded by the prop dining set in furnishProps: four cylinder tables and
-- the sixteen prop chairs, benches and refectory tables all stood in the same
-- forty studs of floor, which is six of the "props sticking out of each other"
-- reports on its own.
local function _buildCafeteriaTables(parent: Instance, center: Vector3)
	-- Fourteen studs out, not eighteen: the east pair used to reach x = -183,
	-- which is the west edge of the wing stair, and the table's rim stood in
	-- the flight.
	for _, offset in { Vector3.new(-14, 0, -18), Vector3.new(14, 0, -18), Vector3.new(-14, 0, 14), Vector3.new(14, 0, 14) } do
		local pos = center + offset
		local top = part({
			Name = "TableTop",
			Size = Vector3.new(1, 10, 10),
			CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(222, 100, 90),
			Parent = parent,
		})
		top.Shape = Enum.PartType.Cylinder
		part({
			Name = "TableLeg",
			Size = Vector3.new(1.2, 3, 1.2),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)),
			Color = Color3.fromRGB(120, 120, 120),
			Parent = parent,
		})
	end
end

-- A stylised tree, in the manner of the painterly reference art: a leaning
-- tapered trunk, two branch stubs, and a canopy built as a CLUSTER of faceted
-- lobes rather than one ball.
--
-- The old one was a box and three spheres of nearly the same green. From ten
-- studs it read as a lollipop, and a hundred and ninety lollipops around the
-- horizon is what a placeholder looks like. What makes the reference canopies
-- read is that they are lumpy and two-toned: a dark mass with a few lighter
-- lobes catching the sun on the upper side. Same part budget, different shape.
local CANOPY_DARK = Color3.fromRGB(46, 104, 48)
local CANOPY_LIT = Color3.fromRGB(96, 168, 74)

-- Rectangles the scatter must not drop anything into. Scatter already avoids
-- other PROPS -- it seeds its occupancy from everything placed so far -- but
-- it has never known about built PARTS, and the campus is mostly built parts.
-- A rock outcrop is forty studs of stone that scatter saw as empty lawn.
local scatterBlocks: { { number } } = {}

local function blockScatter(x: number, z: number, halfX: number, halfZ: number)
	table.insert(scatterBlocks, { x - halfX, z - halfZ, x + halfX, z + halfZ })
end

local function scatterBlocked(x: number, z: number, radius: number): boolean
	for _, rect in scatterBlocks do
		if x + radius > rect[1] and x - radius < rect[3]
			and z + radius > rect[2] and z - radius < rect[4] then
			return true
		end
	end
	return false
end

local ROCK_PALE = Color3.fromRGB(178, 188, 202)
local ROCK_DEEP = Color3.fromRGB(120, 134, 154)

local function buildRockOutcrop(parent: Instance, pos: Vector3, scale: number, seed: number)
	local rng = Random.new(seed)
	-- twenty studs of skirt round it, so nothing is scattered into the stone
	blockScatter(pos.X, pos.Z, 22 * scale, 22 * scale)
	local slabs = rng:NextInteger(2, 4)
	for i = 1, slabs do
		local h = rng:NextNumber(9, 22) * scale
		local w = rng:NextNumber(6, 13) * scale
		local d = rng:NextNumber(6, 12) * scale
		local away = rng:NextNumber(0, math.pi * 2)
		local out = rng:NextNumber(0, 7) * scale
		local slab = part({
			Name = "RockSlab",
			Size = Vector3.new(w, h, d),
			CFrame = CFrame.new(pos + Vector3.new(math.cos(away) * out, h / 2 - 1.5, math.sin(away) * out))
				* CFrame.Angles(
					math.rad(rng:NextNumber(-7, 7)),
					rng:NextNumber(0, math.pi * 2),
					math.rad(rng:NextNumber(-7, 7))
				),
			Color = ROCK_DEEP:Lerp(ROCK_PALE, rng:NextNumber(0.2, 1)),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
		-- a cap a shade paler, so the top face reads as catching the sky
		part({
			Name = "RockCap",
			Size = Vector3.new(w * 0.86, 1.6 * scale, d * 0.86),
			CFrame = slab.CFrame * CFrame.new(0, h / 2, 0),
			Color = ROCK_PALE,
			Material = Enum.Material.Slate,
			Parent = parent,
		}).CanCollide = false
	end
	for i = 1, rng:NextInteger(2, 4) do
		local r = rng:NextNumber(2.2, 4.6) * scale
		local away = rng:NextNumber(0, math.pi * 2)
		-- outside the slabs, not inside them: the slabs reach eleven studs from
		-- the centre and the boulders were being dropped at seven
		local out = rng:NextNumber(14, 21) * scale
		part({
			Name = "RockBoulder",
			Size = Vector3.new(r * 2, r * 1.5, r * 1.8),
			CFrame = CFrame.new(pos + Vector3.new(math.cos(away) * out, r * 0.55, math.sin(away) * out))
				* CFrame.Angles(
					math.rad(rng:NextNumber(-14, 14)),
					rng:NextNumber(0, math.pi * 2),
					math.rad(rng:NextNumber(-14, 14))
				),
			Color = ROCK_DEEP:Lerp(ROCK_PALE, rng:NextNumber(0, 0.7)),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
end

local function buildGymMarkings(parent: Instance, center: Vector3)
	local circle = part({
		Name = "GymCircle",
		-- Three markings on one floor, each on its own course. All three used
		-- to start or end within a hundredth of a stud of each other, so the
		-- centre circle of the gym -- the thing the whole room is arranged
		-- around -- speckled.
		Size = Vector3.new(0.2, 26, 26),
		CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Palette.White,
		Parent = parent,
	})
	circle.Shape = Enum.PartType.Cylinder
	local inner = part({
		Name = "GymCircleInner",
		Size = Vector3.new(0.22, 23, 23),
		CFrame = CFrame.new(center + Vector3.new(0, 0.23, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(210, 160, 110),
		Parent = parent,
	})
	inner.Shape = Enum.PartType.Cylinder
	part({
		Name = "GymCenterLine",
		Size = Vector3.new(66, 0.2, 1.2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.38, 0)),
		Color = Palette.White,
		Parent = parent,
	})
end

local function buildStatues(parent: Instance)
	local StudentGen = { Create = function() return nil end, Stand = function() end } :: any
	for i, spec in { { id = "school_legend", x = 215 - 14 }, { id = "substitute_who_stayed", x = 215 + 14 } } do
		local pedestal = part({
			Name = "StatuePedestal",
			Size = Vector3.new(6, 3, 6),
			CFrame = CFrame.new(spec.x, 1.5, -78),
			Color = Color3.fromRGB(200, 200, 200),
			Material = Enum.Material.Marble,
			Parent = parent,
		})
		local model = StudentGen.Create(spec.id)
		if model then
			-- solid gold repaint
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") then
					child.Color = Palette.BusYellow
					child.Material = Enum.Material.Metal
					child.Anchored = true
				elseif child:IsA("BillboardGui") or child:IsA("ParticleEmitter") or child:IsA("Highlight") then
					child:Destroy()
				end
			end
			model.Name = "Statue" .. i
			model.Parent = parent
			StudentGen.Stand(model, pedestal.CFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(180), 0))
		end
		local _ = i
	end
end

-- Stepped roof + warm interior lighting for a walled building.
local function buildRoof(parent: Instance, center: Vector3, size: Vector2)
	local layers = {
		{ inset = -4, y = 14.75 },
		{ inset = 8, y = 16.25 },
		{ inset = 20, y = 17.75 },
		{ inset = 32, y = 19.25 },
	}
	for _, layer in layers do
		if size.X - layer.inset > 6 and size.Y - layer.inset > 6 then
			part({
				Name = "RoofLayer",
				Size = Vector3.new(size.X - layer.inset, 1.5, size.Y - layer.inset),
				CFrame = CFrame.new(center + Vector3.new(0, layer.y, 0)),
				Color = Color3.fromRGB(84, 98, 110),
				Material = Enum.Material.ClayRoofTiles,
				Parent = parent,
			})
		end
	end
	-- interior ceiling lights so roofed rooms stay warm and readable
	for _, offset in { Vector3.new(-size.X / 5, 0, 0), Vector3.new(size.X / 5, 0, 0) } do
		local strip = part({
			Name = "CeilingLight",
			Size = Vector3.new(1, 0.4, size.Y * 0.5),
			CFrame = CFrame.new(center + offset + Vector3.new(0, 13.6, 0)),
			Color = Color3.fromRGB(255, 244, 214),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Range = 34
		light.Color = Color3.fromRGB(255, 238, 200)
		light.Parent = strip
	end
end

-- Concrete walkway between two points.
local function buildPath(parent: Instance, from: Vector3, to: Vector3, width: number)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	local mid = (from + to) / 2
	part({
		Name = "Walkway",
		Size = Vector3.new(width, 0.3, length),
		CFrame = CFrame.lookAt(Vector3.new(mid.X, 0.05, mid.Z), Vector3.new(to.X, 0.05, to.Z)),
		Color = Color3.fromRGB(178, 172, 160),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
end

-- Courtyard fountain: stone basin, water, spray.
local function buildFountain(parent: Instance, center: Vector3)
	local basin = part({
		Name = "FountainBasin",
		Size = Vector3.new(2.5, 16, 16),
		CFrame = CFrame.new(center + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 190, 190),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	basin.Shape = Enum.PartType.Cylinder
	local water = part({
		Name = "FountainWater",
		Size = Vector3.new(1.2, 14, 14),
		CFrame = CFrame.new(center + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 160, 220),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Parent = parent,
	})
	water.Shape = Enum.PartType.Cylinder
	local column = part({
		Name = "FountainColumn",
		Size = Vector3.new(1.6, 5, 1.6),
		CFrame = CFrame.new(center + Vector3.new(0, 3.5, 0)),
		Color = Color3.fromRGB(190, 190, 190),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
	spray.Rate = 24
	spray.Lifetime = NumberRange.new(0.7, 1.1)
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.Size = NumberSequence.new(0.35)
	spray.Transparency = NumberSequence.new(0.35)
	spray.LightEmission = 0.4
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = column
end

-- Banners hanging under the hallway canopy.
local function buildBanners(parent: Instance)
	local colors = { Palette.DetentionRed, Palette.LockerBlue, Palette.BusYellow, Palette.AuraPurple }
	local texts = { "GO LEGENDS!", "QUIZ FRIDAY", "LOCK YOUR BASE", "FARM AURA" }
	for i = 1, 4 do
		local banner = part({
			Name = "Banner" .. i,
			Size = Vector3.new(8, 4.5, 0.3),
			CFrame = CFrame.new(-90 + (i - 1) * 60, 11.6, 0) ,
			Color = colors[i],
			Parent = parent,
		})
		signText(banner, texts[i], Palette.White, Enum.NormalId.Front)
		signText(banner, texts[i], Palette.White, Enum.NormalId.Back)
	end
end

-- Three walls + a window band around a zone, leaving the side facing `openDir` open.
local function buildZoneWalls(parent: Instance, center: Vector3, size: Vector2, openDir: Vector3)
	local height = 14
	local sides = {
		{ dir = Vector3.new(0, 0, -1), cf = CFrame.new(center + Vector3.new(0, 0, -size.Y / 2)), len = size.X },
		{ dir = Vector3.new(0, 0, 1), cf = CFrame.new(center + Vector3.new(0, 0, size.Y / 2)), len = size.X },
		{ dir = Vector3.new(-1, 0, 0), cf = CFrame.new(center + Vector3.new(-size.X / 2, 0, 0)) , len = size.Y },
		{ dir = Vector3.new(1, 0, 0), cf = CFrame.new(center + Vector3.new(size.X / 2, 0, 0)) , len = size.Y },
	}
	for _, side in sides do
		if side.dir:Dot(openDir) > 0.5 then
			continue
		end
		-- lower wall, window band, upper band
		part({
			Name = "ZoneWallLower",
			Size = Vector3.new(side.len, 6, 2),
			CFrame = side.cf * CFrame.new(0, 3, 0),
			Color = Color3.fromRGB(226, 218, 196),
			Material = Enum.Material.Brick,
			Parent = parent,
		})
		part({
			Name = "ZoneWallWindows",
			Size = Vector3.new(side.len, 4, 1.2),
			CFrame = side.cf * CFrame.new(0, 8, 0),
			Color = Color3.fromRGB(150, 200, 225),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			Parent = parent,
		})
		-- window mullions
		local mullions = math.floor(side.len / 9)
		for m = 1, mullions - 1 do
			part({
				Name = "WindowMullion",
				Size = Vector3.new(0.5, 4, 1.4),
				CFrame = side.cf * CFrame.new(-side.len / 2 + m * 9, 8, 0),
				Color = Color3.fromRGB(226, 218, 196),
				Material = Enum.Material.Concrete,
				Parent = parent,
			})
		end
		part({
			Name = "ZoneWallUpper",
			Size = Vector3.new(side.len, height - 10, 2),
			CFrame = side.cf * CFrame.new(0, 10 + (height - 10) / 2, 0),
			Color = Color3.fromRGB(226, 218, 196),
			Material = Enum.Material.Brick,
			Parent = parent,
		})
	end
end

local function buildEntranceArch(parent: Instance)
	for _, x in { -20, 20 } do
		part({
			Name = "ArchPillar",
			Size = Vector3.new(4, 18, 4),
			CFrame = CFrame.new(x, 9, 104),
			Color = Color3.fromRGB(150, 100, 70),
			Material = Enum.Material.Brick,
			Parent = parent,
		})
	end
	local beam = part({
		Name = "ArchBeam",
		Size = Vector3.new(48, 6, 3),
		CFrame = CFrame.new(0, 20, 104),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(beam, "CRUMBWORTH HIGH", Palette.BusYellow, Enum.NormalId.Front)
	signText(beam, "GO LEGENDS!", Palette.BusYellow, Enum.NormalId.Back)
end

-- On the lawn beside the walk, not on the axis. A 26 stud pole dead centre in
-- front of the doors is the first thing a player sees and it stood between
-- them and the entrance.
local function buildFlagpole(parent: Instance)
	local FX = -38
	part({
		Name = "FlagpoleBase",
		Size = Vector3.new(5, 1.6, 5),
		CFrame = CFrame.new(FX, 0.4, 150),
		Color = Color3.fromRGB(206, 202, 192),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	part({
		Name = "Flagpole",
		Size = Vector3.new(0.8, 26, 0.8),
		CFrame = CFrame.new(FX, 13, 150),
		Color = Color3.fromRGB(190, 190, 195),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local flag = part({
		Name = "Flag",
		Size = Vector3.new(9, 5, 0.3),
		CFrame = CFrame.new(FX + 5.3, 22.5, 150),
		Color = Palette.CashGreen,
		Parent = parent,
	})
	signText(flag, "$", Palette.BusYellow, Enum.NormalId.Front)
	signText(flag, "$", Palette.BusYellow, Enum.NormalId.Back)
end

local function buildHoops(parent: Instance, center: Vector3)
	for _, side in { -1, 1 } do
		local base = center + Vector3.new(side * 30, 0, 0)
		part({
			Name = "HoopPole",
			Size = Vector3.new(1, 12, 1),
			CFrame = CFrame.new(base + Vector3.new(0, 6, 0)),
			Color = Color3.fromRGB(190, 190, 195),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		part({
			Name = "HoopBoard",
			Size = Vector3.new(1, 4.5, 7),
			CFrame = CFrame.new(base + Vector3.new(side * -0.9, 11.5, 0)),
			Color = Palette.White,
			Parent = parent,
		})
		local ring = part({
			Name = "HoopRing",
			Size = Vector3.new(0.4, 2.6, 2.6),
			CFrame = CFrame.new(base + Vector3.new(side * -2.6, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(230, 120, 60),
			Parent = parent,
		})
		ring.Shape = Enum.PartType.Cylinder
	end
	local board = part({
		Name = "GymScoreboard",
		Size = Vector3.new(16, 8, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 12, -34)),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(board, "LEGENDS 21\nVISITORS 3", Palette.BusYellow, Enum.NormalId.Front)
end

-- Glass canopy over the main hallway: tinted panels on the existing light beams.
local function buildCanopy(parent: Instance)
	for x = -150, 150, 60 do
		part({
			Name = "CanopyPanel",
			Size = Vector3.new(60, 0.5, 30),
			CFrame = CFrame.new(x + 30 <= 150 and x + 30 or 150, 14.4, 0),
			Color = Color3.fromRGB(160, 205, 230),
			Material = Enum.Material.Glass,
			Transparency = 0.55,
			Parent = parent,
		})
	end
	for _, side in { -1, 1 } do
		part({
			Name = "CanopyEdge",
			Size = Vector3.new(320, 0.8, 1.2),
			CFrame = CFrame.new(0, 14.4, side * 14.6),
			Color = Palette.LockerBlueDark,
			Parent = parent,
		})
	end
end

-- Checkered cafeteria floor tiles.
local function buildCheckerFloor(parent: Instance, center: Vector3, size: Vector2)
	local tile = 10
	local cols, rows = math.floor(size.X / tile), math.floor(size.Y / tile)
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			if (i + j) % 2 == 0 then
				part({
					Name = "CheckerTile",
					Size = Vector3.new(tile - 0.4, 0.2, tile - 0.4),
					CFrame = CFrame.new(
						center.X - size.X / 2 + tile / 2 + i * tile,
						-- 0.24, not 0.11: a checker tile is drawn ON the hallway
						-- floor, and at 0.11 its top landed on the floor's top
						0.24,
						center.Z - size.Y / 2 + tile / 2 + j * tile
					),
					-- a warm stone against the pale floor: the old pillarbox red
					-- read as a diner, not a school atrium
					Color = Color3.fromRGB(176, 142, 120),
					Parent = parent,
				})
			end
		end
	end
end

-- Flowerbeds: planter box + colored flower balls.
local function buildFlowerbed(parent: Instance, center: Vector3)
	part({
		Name = "PlanterBox",
		Size = Vector3.new(10, 2.0, 4),
		CFrame = CFrame.new(center + Vector3.new(0, 0.6, 0)),
		Color = Color3.fromRGB(105, 76, 48),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local rng = Random.new(math.floor(center.X * 13 + center.Z * 7))
	local colors = {
		Color3.fromRGB(240, 96, 130),
		Color3.fromRGB(245, 197, 49),
		Color3.fromRGB(180, 75, 217),
		Color3.fromRGB(255, 255, 255),
	}
	for i = 1, 6 do
		local flower = part({
			Name = "Flower",
			Size = Vector3.one * rng:NextNumber(0.9, 1.4),
			CFrame = CFrame.new(center + Vector3.new(-4 + i * 1.35, 1.9 + rng:NextNumber(0, 0.3), rng:NextNumber(-1, 1))),
			Color = colors[rng:NextInteger(1, #colors)],
			Parent = parent,
		})
		flower.Shape = Enum.PartType.Ball
	end
end

-- Ambient falling leaves over the courtyard.
local function buildLeaves(parent: Instance, center: Vector3)
	local emitterPart = part({
		Name = "LeafEmitter",
		Size = Vector3.new(100, 1, 60),
		CFrame = CFrame.new(center + Vector3.new(0, 26, 0)),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	local leaves = Instance.new("ParticleEmitter")
	leaves.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 190, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 180, 70)),
	})
	leaves.Rate = 4
	leaves.Lifetime = NumberRange.new(6, 9)
	leaves.Speed = NumberRange.new(2, 4)
	leaves.Acceleration = Vector3.new(1.5, -2.5, 0.8)
	leaves.Rotation = NumberRange.new(0, 360)
	leaves.RotSpeed = NumberRange.new(-90, 90)
	leaves.Size = NumberSequence.new(0.35)
	leaves.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.9, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	leaves.EmissionDirection = Enum.NormalId.Bottom
	leaves.Parent = emitterPart
end

local function buildRoad(parent: Instance)
	part({
		Name = "Road",
		Size = Vector3.new(200, 0.4, 16),
		CFrame = CFrame.new(-160, -0.3, 120),
		Color = Color3.fromRGB(70, 70, 74),
		Material = Enum.Material.Asphalt,
		Parent = parent,
	})
	for x = -240, -80, 20 do
		part({
			Name = "RoadStripe",
			Size = Vector3.new(6, 0.2, 0.8),
			CFrame = CFrame.new(x, -0.05, 120),
			Color = Palette.BusYellow,
			Parent = parent,
		})
	end
end


-- School props that fill the space: vending machines, bins, notice boards,
-- water fountains, planters. Placed along the hallway edges and in the zones.
local function buildProps(parent: Instance)
	local function vending(x: number, z: number, yaw: number, color: Color3)
		local body = part({
			Name = "VendingMachine",
			Size = Vector3.new(6, 11, 3.5),
			CFrame = CFrame.new(x, 5.5, z) * CFrame.Angles(0, yaw, 0),
			Color = color,
			Parent = parent,
		})
		part({
			Name = "VendingGlass",
			Size = Vector3.new(4.4, 7, 0.4),
			CFrame = body.CFrame * CFrame.new(0, 1.4, -1.8),
			Color = Color3.fromRGB(40, 50, 60),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Parent = parent,
		})
		for row = 0, 2 do
			part({
				Name = "VendingShelf",
				Size = Vector3.new(4.2, 0.3, 0.5),
				CFrame = body.CFrame * CFrame.new(0, 3.4 - row * 2.1, -1.9),
				Color = Color3.fromRGB(180, 180, 185),
				Parent = parent,
			})
		end
		local glow = part({
			Name = "VendingGlow",
			Size = Vector3.new(5, 0.6, 0.3),
			CFrame = body.CFrame * CFrame.new(0, 5, -1.85),
			Color = Palette.BusYellow,
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 1
		light.Range = 16
		light.Color = Palette.BusYellow
		light.Parent = glow
	end

	local function bin(x: number, z: number)
		local body = part({
			Name = "TrashBin",
			Size = Vector3.new(3.4, 4.4, 3.4),
			CFrame = CFrame.new(x, 2.2, z),
			Color = Color3.fromRGB(70, 78, 68),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		body.Shape = Enum.PartType.Cylinder
		body.CFrame = CFrame.new(x, 2.2, z) * CFrame.Angles(0, 0, math.rad(90))
		part({
			Name = "TrashLid",
			Size = Vector3.new(0.5, 3.8, 3.8),
			CFrame = CFrame.new(x, 4.6, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(45, 52, 44),
			Material = Enum.Material.Metal,
			Parent = parent,
		}).Shape = Enum.PartType.Cylinder
	end

	local function noticeBoard(x: number, z: number, yaw: number)
		local board = part({
			Name = "NoticeBoard",
			Size = Vector3.new(10, 7, 0.6),
			CFrame = CFrame.new(x, 6, z) * CFrame.Angles(0, yaw, 0),
			Color = Color3.fromRGB(120, 88, 56),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		local rng = Random.new(math.floor(x * 7 + z * 3))
		for i = 1, 6 do
			part({
				Name = "Flyer",
				Size = Vector3.new(rng:NextNumber(1.6, 2.4), rng:NextNumber(2, 2.8), 0.15),
				CFrame = board.CFrame
					* CFrame.new(rng:NextNumber(-3.6, 3.6), rng:NextNumber(-2, 2), -0.4)
					* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
				Color = ({
					Color3.fromRGB(245, 245, 235),
					Color3.fromRGB(250, 220, 160),
					Color3.fromRGB(200, 235, 245),
				})[rng:NextInteger(1, 3)],
				Parent = parent,
			})
		end
	end

	local function fountain(x: number, z: number, yaw: number)
		part({
			Name = "WaterFountain",
			Size = Vector3.new(3.6, 3.6, 2.4),
			CFrame = CFrame.new(x, 1.8, z) * CFrame.Angles(0, yaw, 0),
			Color = Color3.fromRGB(200, 205, 210),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		part({
			Name = "FountainBowl",
			Size = Vector3.new(3.2, 0.5, 2),
			CFrame = CFrame.new(x, 3.6, z) * CFrame.Angles(0, yaw, 0),
			Color = Color3.fromRGB(225, 230, 235),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end

	local function planter(x: number, z: number)
		part({
			Name = "PlanterPot",
			Size = Vector3.new(3.4, 3, 3.4),
			CFrame = CFrame.new(x, 1.5, z),
			Color = Color3.fromRGB(160, 96, 70),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
		local rng = Random.new(math.floor(x * 11 + z * 5))
		for i = 1, 4 do
			local leaf = part({
				Name = "PlantLeaf",
				Size = Vector3.one * rng:NextNumber(2, 3.2),
				CFrame = CFrame.new(x + rng:NextNumber(-1, 1), 4 + rng:NextNumber(0, 1.4), z + rng:NextNumber(-1, 1)),
				Color = Color3.fromRGB(70, 140 + i * 8, 60),
				Material = Enum.Material.Grass,
				Parent = parent,
			})
			leaf.Shape = Enum.PartType.Ball
		end
	end

	-- hallway furniture, alternating along both sides
	for i, x in { -145, -105, -65, -25, 15, 55, 95, 135 } do
		local z = (i % 2 == 0) and -12.5 or 12.5
		local yaw = (i % 2 == 0) and 0 or math.pi
		local kind = i % 4
		if kind == 0 then
			vending(x, z, yaw, Palette.DetentionRed)
		elseif kind == 1 then
			noticeBoard(x, z, yaw)
		elseif kind == 2 then
			vending(x, z, yaw, Palette.LockerBlue)
		else
			fountain(x, z, yaw)
		end
		bin(x + 12, z * 0.86)
		planter(x + 22, z * 0.9)
	end

	-- cafeteria + gym extras
	vending(-186, 40, math.pi / 2, Palette.CashGreen)
	vending(-186, 78, math.pi / 2, Palette.BusYellow)
	bin(-192, 60)
	for _, spot in { Vector3.new(196, 34, 0), Vector3.new(196, 86, 0) } do
		bin(spot.X, spot.Y)
	end
	planter(-40, 100)
	planter(40, 100)
end

-- Dense treeline just inside the perimeter walls, so the horizon reads as woods.
-- Footprints the treeline is not allowed to grow in. The ring runs at a
-- radius of roughly 300 to 370 studs, which is exactly where the outbuildings
-- are: a grove was growing up through the staff lodge, and one of its trunks
-- stood in the middle of the stair to the studies. A tree inside a building is
-- not a decoration, it is a wall.
-- ================= THE PLOT =================
-- The campus boundary, in one place. It used to be a 558-stud square wall
-- round a 900-stud square of ground, which put the pool and the tennis
-- stadium hard against the fence and left nothing at all behind the school
-- but the strip the library and the two boarding houses stood on.
--
-- It is a rectangle now, and a long one: the whole back of the plot -- the
-- playing fields, the boarding houses, the orchard, the lake -- lives south
-- of the library, which is where a school this size keeps its land.
-- and it is not a hand-typed rectangle either. CampusPlan.CORE is the built
-- campus -- (-560, -420) to (590, 560) -- and the four expansion reserves are
-- the plot minus it, so the core boundary is the one line the treeline, the
-- rock ridge and the estate fence all want. 420/320/-520 was an 840 x 840
-- square typed before the drawing existed: it ran 140 studs inside the core
-- on the east and 160 inside on the north, so the belt of trees meant to
-- close the horizon grew across the car park and the sports field instead.
local CORE_X0, CORE_Z0, CORE_X1, CORE_Z1 =
	CampusPlan.CORE[1], CampusPlan.CORE[2], CampusPlan.CORE[3], CampusPlan.CORE[4]

-- The plot, from CampusPlan. The far ridge of rock is thrown 110 to 170 studs
-- beyond the wall, and off the south side that put 81 boulders out at z -722,
-- eighty studs past the edge of the land the campus is drawn on. Scenery is
-- held inside the plot like everything else.
local PLOT_MIN_X, PLOT_MIN_Z, PLOT_MAX_X, PLOT_MAX_Z = -800, -640, 840, 780

-- Where the scenery already stands.
--
-- The treeline and the rock ridge are two independent loops walking the same
-- boundary, and neither has ever known about the other, so fourteen trees grew
-- straight through boulders. It is the same fault as the two sets of dormers
-- and the two builders planting shrubs in one bed: whatever goes down first
-- has to leave a record the next builder reads.
local sceneryPlaced: { { pos: Vector3, radius: number } } = {}

local function claimGround(pos: Vector3, radius: number): boolean
	for _, taken in sceneryPlaced do
		local dx, dz = pos.X - taken.pos.X, pos.Z - taken.pos.Z
		local reach = radius + taken.radius
		if dx * dx + dz * dz < reach * reach then
			return false
		end
	end
	table.insert(sceneryPlaced, { pos = pos, radius = radius })
	return true
end

-- THE LAYER LADDER.
--
-- Every one of these was found by tools/zfight_check.py and every one was the
-- same mistake: something drawn ON a surface given exactly that surface's
-- height. The upper floor's ceiling against the deck above it -- sixty
-- thousand square studs across the whole school. Eight carpets against the
-- deck they lie on. The court paving against the plaza it covers. Two courts
-- against their own playing surfaces. A corridor with three surfaces inside a
-- fiftieth of a stud of each other.
--
-- A depth buffer cannot separate two faces closer than about a hundredth of a
-- stud, and the result is not a small artefact: the two flicker against each
-- other in bands as the camera moves. So there is a ladder, the rungs are far
-- enough apart to be safe, and anything laid on a surface takes the next rung
-- up rather than a number that looked about right.
local Layer = {
	ground = 0.20,   -- terrain-level: lawn, bare earth, the bed of everything
	paving = 0.40,   -- slabs, plazas, aprons, court surfaces
	path = 0.58,     -- walks and paths crossing paving
	marking = 0.74,  -- lines, joints, stripes, painted bays
	inlay = 0.90,    -- anything drawn on a marking
}
local _ = Layer

local function insidePlot(pos: Vector3, margin: number): boolean
	return pos.X > PLOT_MIN_X + margin and pos.X < PLOT_MAX_X - margin
		and pos.Z > PLOT_MIN_Z + margin and pos.Z < PLOT_MAX_Z - margin
end
-- The front road, north of the Great Court. It used to run at z = 208, which
-- the court now covers to z = 285: twenty-two studs of asphalt through the
-- middle of the parterres, with the school bus parked on the fountain's north
-- walk.
local ROAD_Z = 320

-- The ground is the plot, exactly. It used to be a 1400 x 1500 slab centred on
-- (0, -100), drawn before the plot grew to its expansion size, so the East
-- Reserve (x 700..840) and the North Reserve (z 650..780) had no ground under
-- them at all -- you could walk off the edge of the world inside the estate
-- wall -- while 210 studs of grass ran on past the south wall to z = -850.
local PLOT_W, PLOT_D = PLOT_MAX_X - PLOT_MIN_X, PLOT_MAX_Z - PLOT_MIN_Z
local PLOT_MID_X = (PLOT_MIN_X + PLOT_MAX_X) / 2
local PLOT_MID = (PLOT_MIN_Z + PLOT_MAX_Z) / 2

local NO_TREES = {
	{ -556, 224, -304, 436 },    -- the bike track, on its drawn ground
	{ -350, -210, -250, -130 },  -- the staff lodge and its turret
	{ -265, -202, -232, -170 },
	-- (the boarding house's own ground comes from CampusPlan.SITE below)
	{ -387, -352, -253, -248 }, -- the library, on its drawn ground
	{ -230, -130, 230, 130 },    -- the school itself
	{ -180, -470, 180, -320 },   -- the running track and playing field
	-- (the ball courts have moved to their drawn ground east of the Academy)
	{ -392, -258, -356, -166 },  -- the groundsman's yard
	-- The three structures that come out of the drawing. The treeline knew
	-- nothing about them because they did not exist when this list was written,
	-- so it planted an oak inside the hidden alley.
	{ 318, 328, 532, 482 },      -- the gymnasium
	{ 143, 333, 277, 467 },      -- the secret rooftop block
	{ 265, 390, 330, 410 },      -- the alley between them
	{ 300, 150, 580, 320 },      -- the sports field, in its drawn place
	{ 335, -35, 525, 115 },      -- the car park
	{ 208, -360, 432, -240 },    -- the cafeteria, on its drawn ground
	{ -497, -52, -303, 92 },     -- the detention hall, on its drawn ground
	-- THE CEREMONIAL APPROACH. Standing at the main gate on the axis, the
	-- school was completely hidden behind a wall of trees: 178 canopies, 58
	-- branches, 29 trunks and sixteen boulders between the gate and the front
	-- doors. The treeline follows the boundary and the boundary runs straight
	-- across the walk, and nothing had ever told it not to. This rect is
	-- CampusPlan.APPROACH, and tools/build_check.py holds the built map to it.
	{ -150, 124, 150, 575 },
}

-- and every rectangle the drawing has spent, whatever it is and whenever it
-- was drawn. The hand-kept list above is where the trees came from: its
-- library entry is (-387, -352) to (-253, -248) and the drawing gives the
-- Library (-420, -348) to (-220, -252), so ten trees grew inside the west end
-- of it. A hand-kept exclusion list drifts from the drawing by construction;
-- reading the drawing does not.
for _, site in CampusPlan.SITE do
	table.insert(NO_TREES, { site.rect[1], site.rect[2], site.rect[3], site.rect[4] })
end

-- A point on a rounded rectangle, so the belt of trees and the ridge of rock
-- follow the boundary the campus actually has instead of a circle drawn round
-- the middle of it. With a plot half as long again as it is wide, a circle
-- either crosses the wall at the ends or leaves the corners bare.
local function onBoundary(t: number, x0: number, z0: number, x1: number, z1: number): Vector3
	local w, d = x1 - x0, z1 - z0
	local perimeter = (w + d) * 2
	local at = (t % 1) * perimeter
	if at < w then
		return Vector3.new(x0 + at, 0, z1)
	elseif at < w + d then
		return Vector3.new(x1, 0, z1 - (at - w))
	elseif at < w * 2 + d then
		return Vector3.new(x1 - (at - w - d), 0, z0)
	end
	return Vector3.new(x0, 0, z0 + (at - w * 2 - d))
end

local function buildTreeline(parent: Instance, treeFn: (Instance, Vector3, number) -> ())
	local rng = Random.new(2026)
	for i = 1, 300 do
		local out = rng:NextNumber(26, 96)
		local pos = onBoundary(i / 300 + rng:NextNumber(-0.001, 0.001),
			CORE_X0 - out, CORE_Z0 - out, CORE_X1 + out, CORE_Z1 + out)
		local scale = rng:NextNumber(1.1, 2.3)
		local blocked = false
		for _, rect in NO_TREES do
			-- pad by the canopy, not the trunk: leaves poking through a wall
			-- read exactly as badly as a trunk standing in a corridor
			if pos.X > rect[1] - 8 and pos.X < rect[3] + 8 and pos.Z > rect[2] - 8 and pos.Z < rect[4] + 8 then
				blocked = true
				break
			end
		end
		if not blocked and insidePlot(pos, 20) and claimGround(pos, 10 * scale) then
			treeFn(parent, pos, scale)
		end
	end
end

-- The stone ridge the treeline stands in front of. Two rings: a far one out
-- past the wall that closes the horizon in every direction you can look, and a
-- near one of low outcrops inside the grounds, so the lawn has something in it
-- other than lawn. Both skip the building footprints for the same reason the
-- trees do.
local function buildRocks(parent: Instance)
	local rng = Random.new(511)
	local function clear(pos: Vector3, pad: number): boolean
		for _, rect in NO_TREES do
			if pos.X > rect[1] - pad and pos.X < rect[3] + pad
				and pos.Z > rect[2] - pad and pos.Z < rect[4] + pad then
				return false
			end
		end
		return true
	end

	-- the far ridge: big, out past the treeline, closing the horizon
	for i = 1, 62 do
		-- 110..170, not 110..210: at 210 the ridge stepped outside the plot
		local out = rng:NextNumber(110, 170)
		local pos = onBoundary(i / 62 + rng:NextNumber(-0.002, 0.002),
			CORE_X0 - out, CORE_Z0 - out, CORE_X1 + out, CORE_Z1 + out)
		local grade = rng:NextNumber(1.2, 2.4)
		-- 48, not 26: buildRockOutcrop throws its boulders up to 21 studs
		-- off the seed, so a seed cleared at 26 could still drop stone five
		-- studs inside a rectangle the drawing had spoken for
		if clear(pos, 48) and insidePlot(pos, 24) and claimGround(pos, 20 * grade) then
			buildRockOutcrop(parent, pos, grade, 900 + i)
		end
	end
	-- low outcrops on the lawns, well clear of anything anybody walks through
	for _, spot in {
		Vector3.new(-300, 0, 150), Vector3.new(300, 0, 150),
		Vector3.new(-330, 0, -78), Vector3.new(330, 0, -78),
		Vector3.new(-360, 0, 60), Vector3.new(360, 0, 60),
		Vector3.new(-340, 0, -300), Vector3.new(340, 0, -300),
		Vector3.new(-380, 0, -430), Vector3.new(380, 0, -430),
		Vector3.new(-120, 0, -470), Vector3.new(120, 0, -470),
		Vector3.new(-262, 0, -252), Vector3.new(262, 0, -252),
	} do
		local grade = rng:NextNumber(0.6, 0.95)
		if clear(spot, 18) and claimGround(spot, 20 * grade) then
			buildRockOutcrop(parent, spot, grade, 700 + math.floor(spot.X))
		end
	end
end

-- THE ESTATE FENCE, on the drawn core boundary.
--
-- What used to be here was buildPerimeter: four brick slabs six studs high on
-- that 840 x 840 square, in a colour nothing else on the campus uses -- and
-- nothing ever called it. So the campus had no boundary at all: you walked off
-- the Great Court, across the reserves and out to the edge of the world.
--
-- It is inset from the core by 2.2 studs so not one stud of it stands on
-- reserved ground: a pier plinth is 3.6 wide and tools/build_check.py fails
-- the build for a single built part overlapping a reserve.
--
-- The one opening is the main gate, which already has its own four piers on
-- the axis. The fence stops 64 studs either side of it and turns in to meet
-- them.
local FENCE_INSET = 2.2
-- how far short of a corner pier's centre a run stops. Inside the pier's
-- 3.6-stud plinth, so no two runs meeting at a corner share a plane.
local FENCE_CORNER = 1.1
local FENCE_BAY = 60.0
local function buildCoreFence(parent: Instance)
	local ctx = { parent = parent, part = part :: any, tag = tag :: any }
	local x0, z0 = CORE_X0 + FENCE_INSET, CORE_Z0 + FENCE_INSET
	local x1, z1 = CORE_X1 - FENCE_INSET, CORE_Z1 - FENCE_INSET
	local built: { [string]: boolean } = {}
	local function run(ax: number, az: number, bx: number, bz: number, cutStart: number, cutEnd: number)
		local dx, dz = bx - ax, bz - az
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 8 then
			return
		end
		local ux, uz = dx / length, dz / length
		local bays = math.max(1, math.floor(length / FENCE_BAY + 0.5))
		local step = length / bays
		for i = 0, bays - 1 do
			local a = i * step + (if i == 0 then cutStart else 0)
			local b = (i + 1) * step - (if i == bays - 1 then cutEnd else 0)
			Grounds.boundaryRun(ctx, ax + ux * a, az + uz * a, ax + ux * b, az + uz * b)
		end
		for i = 0, bays do
			local at = i * step
			local px, pz = ax + ux * at, az + uz * at
			local key = ("%d|%d"):format(math.round(px), math.round(pz))
			if not built[key] then
				built[key] = true
				Grounds.boundaryPier(ctx, px, pz)
			end
		end
	end

	local gap = 64.0
	-- north, either side of the gate
	run(x0, z1, -gap, z1, FENCE_CORNER, 0)
	run(gap, z1, x1, z1, 0, FENCE_CORNER)
	-- and the two returns that carry it in to the gate's own piers
	run(-gap, z1, -gap, 546, 0, 0)
	run(gap, z1, gap, 546, 0, 0)
	-- south, west, east
	run(x0, z0, x1, z0, FENCE_CORNER, FENCE_CORNER)
	run(x0, z0, x0, z1, FENCE_CORNER, FENCE_CORNER)
	run(x1, z0, x1, z1, FENCE_CORNER, FENCE_CORNER)
end

-- Real terrain: grass base under the campus + rolling hills outside the walls.
local function buildTerrain()
	local terrain = workspace.Terrain
	-- painterly terrain palette: warm grass, pale stone, so the horizon reads
	-- as painted hills instead of default grey rock
	pcall(function()
		-- Grass blades. This is the one property that separates the reference
		-- landscape from ours: with Decoration off, terrain grass is a flat
		-- green surface, and every stud of the campus that is not a building is
		-- terrain grass. With it on the same surface grows the blades the
		-- reference art is more than half made of, and it costs nothing to
		-- author -- the engine renders it.
		terrain.Decoration = true
		-- Night colours. These were a bright daylight green -- 116, 186, 72 --
		-- and every stud of the campus that is not a building is terrain grass,
		-- so under the new lighting the ground came out as a sheet of yellow
		-- green brighter than the school standing on it. The palette's grass is
		-- 62, 107, 58 and the rest follow it down.
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(62, 107, 58))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(96, 104, 116))
		terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(84, 68, 50))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(48, 88, 46))
		terrain:SetMaterialColor(Enum.Material.Water, Color3.fromRGB(28, 74, 104))
	end)
	-- The whole plot, ground level, in one slab: whatever CampusPlan draws as
	-- the estate has grass under it, reserves included.
	terrain:FillBlock(CFrame.new(PLOT_MID_X, -2.1, PLOT_MID), Vector3.new(PLOT_W, 4, PLOT_D), Enum.Material.Grass)
	local rng = Random.new(7)
	for i = 1, 34 do
		local angle = (i / 34) * math.pi * 2
		local dist = rng:NextNumber(640, 730)
		local pos = Vector3.new(PLOT_MID_X + math.cos(angle) * dist, rng:NextNumber(-6, 8), PLOT_MID + math.sin(angle) * dist)
		terrain:FillBall(pos, rng:NextNumber(34, 78), Enum.Material.Grass)
	end
	-- hard rule: nothing rises above ground level anywhere inside the walls
	terrain:FillBlock(CFrame.new(PLOT_MID_X, 34, PLOT_MID), Vector3.new(PLOT_W, 64, PLOT_D), Enum.Material.Air)

	-- no terrain under any interior floor (air-carved, so no grass blades either)
	for _, region in {
		{ cf = CFrame.new(0, -2.3, 0), size = Vector3.new(452, 5, 252) }, -- main building (plan footprint)
		{ cf = CFrame.new(0, -2.3, -135), size = Vector3.new(104, 5, 26) }, -- gym protrusion
		-- The five buildings PlanBuilder draws from CampusPlan. None of them
		-- had a carve, so terrain grass grew up through every floor in the
		-- boarding house, the cafeteria, the detention hall, the gymnasium and
		-- the rooftop block -- and the two entries that WERE here, at
		-- (+-176, -232), were the two split dorms that the drawing replaced
		-- with one range: a hundred by eighty-six studs of bare earth on each
		-- flank of the Dorm Court where two buildings used to be. These are
		-- the footprints the builder actually lays, measured off the dump,
		-- not the drawn envelopes -- the Library's envelope is 200 x 96 and
		-- its building is 92 x 68, so an envelope carve would strip the lawn
		-- fifty studs clear of the walls.
		{ cf = CFrame.new(0, -2.3, -310), size = Vector3.new(314, 5, 145) },      -- boarding house
		{ cf = CFrame.new(320, -2.3, -297.5), size = Vector3.new(215, 5, 116) },  -- cafeteria
		{ cf = CFrame.new(-397.5, -2.3, 20), size = Vector3.new(190, 5, 135) },   -- detention hall
		{ cf = CFrame.new(422.5, -2.3, 405), size = Vector3.new(210, 5, 145) },   -- gymnasium
		{ cf = CFrame.new(212.5, -2.3, 400), size = Vector3.new(130, 5, 125) },   -- secret rooftop block
		{ cf = CFrame.new(-320, -2.3, -300), size = Vector3.new(96, 5, 72) }, -- library
		-- the staff lodge, and the turret with the headmaster's spiral in it
		{ cf = CFrame.new(-300, -2.3, -170), size = Vector3.new(96, 5, 76) },
		{ cf = CFrame.new(-249, -2.3, -186), size = Vector3.new(28, 5, 28) },
		-- the library's passage west under the field, and its shaft
		{ cf = CFrame.new(-393, -8, -290), size = Vector3.new(64, 34, 22) },
		{ cf = CFrame.new(-420, -8, -290), size = Vector3.new(26, 34, 26) },
	} do
		terrain:FillBlock(region.cf, region.size, Enum.Material.Air)
	end

	-- a few distant rocky peaks for the horizon
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2 + 0.3
		local dist = rng:NextNumber(640, 740)
		local pos = Vector3.new(PLOT_MID_X + math.cos(angle) * dist, rng:NextNumber(10, 30), PLOT_MID + math.sin(angle) * dist)
		terrain:FillBall(pos, rng:NextNumber(40, 80), Enum.Material.Grass)
		terrain:FillBall(pos + Vector3.new(0, 26, 0), rng:NextNumber(16, 30), Enum.Material.Rock)
	end
end


-- A wall run with door gaps: brick base, window band, brick top, parapet cap.
local function buildWallRun(parent: Instance, from: Vector3, to: Vector3, gaps: { { at: number, width: number } }, tall: boolean?)
	local dir = (to - from)
	local length = dir.Magnitude
	local unit = dir.Unit
	local perp = Vector3.new(-unit.Z, 0, unit.X)
	local cuts = { 0, length }
	for _, gap in gaps do
		table.insert(cuts, math.clamp(gap.at - gap.width / 2, 0, length))
		table.insert(cuts, math.clamp(gap.at + gap.width / 2, 0, length))
	end
	table.sort(cuts)
	for i = 1, #cuts - 1 do
		-- odd segments are wall, even segments are gaps (cuts alternate)
		local a, b = cuts[i], cuts[i + 1]
		local isGap = false
		for _, gap in gaps do
			local mid = (a + b) / 2
			if mid > gap.at - gap.width / 2 and mid < gap.at + gap.width / 2 then
				isGap = true
				break
			end
		end
		local segLen = b - a
		if isGap or segLen < 1 then
			continue
		end
		local mid = from + unit * ((a + b) / 2)
		local cf = CFrame.lookAt(mid, mid + perp)
		tag(part({ Name = "ShellBrickLow", Size = Vector3.new(segLen, 6, 2), CFrame = cf * CFrame.new(0, 3, 0) , Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
		tag(part({ Name = "ShellWindow", Size = Vector3.new(segLen, 4, 1.2), CFrame = cf * CFrame.new(0, 8, 0) , Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent }), "TexWindow")
		local mullions = math.floor(segLen / 9)
		for m2 = 1, mullions - 1 do
			part({ Name = "ShellMullion", Size = Vector3.new(0.5, 4, 1.4), CFrame = cf * CFrame.new(-segLen / 2 + m2 * 9, 8, 0) , Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		end
		tag(part({ Name = "ShellBrickHigh", Size = Vector3.new(segLen, 6, 2), CFrame = cf * CFrame.new(0, 13, 0) , Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
		-- white frames around the first-story windows (reference-art trim)
		part({ Name = "ShellSill", Size = Vector3.new(segLen, 0.7, 2.3), CFrame = cf * CFrame.new(0, 5.8, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "ShellLintel", Size = Vector3.new(segLen, 0.7, 2.3), CFrame = cf * CFrame.new(0, 10.2, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		if tall then
			-- second story: floor band, framed window band, brick, high parapet
			part({ Name = "ShellFloorBand", Size = Vector3.new(segLen, 1.4, 2.6), CFrame = cf * CFrame.new(0, 16.6, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
			tag(part({ Name = "ShellWindow2", Size = Vector3.new(segLen, 4, 1.2), CFrame = cf * CFrame.new(0, 19.5, 0) , Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent }), "TexWindow")
			local mullions2 = math.floor(segLen / 9)
			for m3 = 1, mullions2 - 1 do
				part({ Name = "ShellMullion2", Size = Vector3.new(0.5, 4, 1.4), CFrame = cf * CFrame.new(-segLen / 2 + m3 * 9, 19.5, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
			end
			part({ Name = "ShellLintel2", Size = Vector3.new(segLen, 0.7, 2.3), CFrame = cf * CFrame.new(0, 21.8, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
			tag(part({ Name = "ShellBrickTop", Size = Vector3.new(segLen, 3.6, 2), CFrame = cf * CFrame.new(0, 24, 0) , Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
			part({ Name = "ShellParapet", Size = Vector3.new(segLen + 0.6, 1.2, 2.8), CFrame = cf * CFrame.new(0, 26.4, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		else
			part({ Name = "ShellParapet", Size = Vector3.new(segLen + 0.6, 1.2, 2.8), CFrame = cf * CFrame.new(0, 16.6, 0) , Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		end
	end
	-- door frames at each gap
	for _, gap in gaps do
		local mid = from + unit * gap.at
		local cf = CFrame.lookAt(mid, mid + perp)
		for _, side in { -1, 1 } do
			part({ Name = "DoorPost", Size = Vector3.new(1.6, 12, 2.6), CFrame = cf * CFrame.new(side * (gap.width / 2 + 0.8), 6, 0) , Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		end
		part({ Name = "DoorLintel", Size = Vector3.new(gap.width + 4, 2, 2.8), CFrame = cf * CFrame.new(0, 13, 0) , Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		if tall then
			-- fill the second story above the doorway so the wall reads solid
			tag(part({ Name = "GapUpperBrick", Size = Vector3.new(gap.width + 4, 12.4, 2), CFrame = cf * CFrame.new(0, 20.2, 0) , Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
			part({ Name = "GapParapet", Size = Vector3.new(gap.width + 4, 1.2, 2.8), CFrame = cf * CFrame.new(0, 26.4, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		end
	end
end

-- Clean interior partitions: navy wainscot + warm white upper, solid, with
-- framed door gaps. (The window-band builder is for exterior facades only.)
-- ===== mouldings =====
--
-- Every junction in the school used to be a raw 90 degree corner between two
-- prisms. Nothing in the painterly references has one: real architecture runs
-- a profile along every wall/floor, wall/ceiling and opening edge, and the
-- highlight that profile catches is what makes a surface read as built rather
-- than extruded.
--
-- The profiles are one-stud extrusions (see tools/make_trim.py), so they are
-- only ever scaled along their run and the cross-section stays exactly as
-- drawn at any length. A bevel baked into a cube would stretch into a wedge
-- the moment the wall was forty studs long.
-- MeshPart.MeshId cannot be assigned by a script, so the mouldings are not
-- built here. MapService records where each run goes and TrimService places
-- them afterwards from templates it loads through InsertService — the same
-- route MeshService already uses for the flora.
export type TrimRun = { kind: string, cframe: CFrame, length: number }

local trimRuns: { TrimRun } = {}

-- One run of moulding. `cf` puts the profile's origin corner where the wall
-- face meets the surface, +X along the run and -Z into the room.
local function moulding(cf: CFrame, kind: string, length: number)
	if length < 0.6 then
		return
	end
	table.insert(trimRuns, { kind = kind, cframe = cf, length = length })
end

-- Props are real furniture: CC0 models from Poly Haven, repacked as .glb and
-- uploaded to this account (tools/polyhaven.py). Same constraint as the
-- mouldings — MeshPart.MeshId is not assignable from a script — so MapService
-- only records where each one goes and PropService places it from a template.
--
-- `cframe` positions the prop's BASE CENTRE, because a desk is placed by where
-- its feet land, not by where the middle of its bounding box floats. `fallback`
-- is the block-built furniture standing in for it; PropService deletes that
-- once the real model has loaded, so a failed asset leaves a furnished room
-- rather than an empty one.
-- `hang` flips that: a pendant lamp is placed by the point it hangs from.
export type PropRequest = { kind: string, cframe: CFrame, scale: number?, hang: boolean?, fallback: Instance? }

local propRequests: { PropRequest } = {}

-- The kit needs to make parts the way MapService does -- same defaults, same
-- tagging -- so it is handed the two helpers rather than requiring MapService
-- back and tying the two together in a knot.
local function kitFor(parent: Instance): Kit.Ctx
	return { parent = parent, part = part :: any, tag = tag :: any }
end

local function prop(kind: string, cf: CFrame, options: { scale: number?, hang: boolean?, fallback: Instance? }?)
	table.insert(propRequests, {
		kind = kind,
		cframe = cf,
		scale = options and options.scale,
		hang = options and options.hang,
		fallback = options and options.fallback,
	})
end

-- Naming a coordinate for every prop stops scaling somewhere around fifty of
-- them, and a room dressed by hand at that size reads as a showroom anyway:
-- everything squared up, evenly spaced, nothing where a person would have left
-- it. Clutter is scattered instead -- a rectangle of clear floor, a pool of
-- things that plausibly live there, and a seeded RNG so the same school comes
-- out of every server.
--
-- Sizes come from PropSizes, which is measured off the uploaded meshes
-- (tools/prop_registry.py). That is also what keeps the pools honest: a kind
-- whose model has not uploaded is simply absent from the table, so it drops
-- out of the pool instead of leaving a hole in the room.
type Zone = {
	min: Vector2,
	max: Vector2,
	y: number,
	pool: { string },
	count: number,
	seed: number,
	margin: number?,
	-- a zone the author means to sit inside a drawn footprint
	inside: boolean?,
}

-- A tree that is a TREE.
--
-- buildTree assembles one out of a trunk, a root flare, two branches and six
-- flattened spheres: ten parts, and three hundred of them along the boundary
-- is three thousand parts of blocky canopy filling the top of every frame. It
-- is the single largest thing in shot on a campus this size and it looked
-- exactly like what it was.
--
-- Poly Haven's scanned trees are the obvious upgrade and they are unusable:
-- jacaranda_tree is 3.9 million triangles and pine_tree_01 is 17 million,
-- against Roblox's cap of ten thousand per MeshPart. Kenney's nature kit is
-- CC0, already uploaded, and built at game scale -- four species, real
-- silhouettes, one mesh each. Ten parts becomes one, and it looks like a tree.
-- The Hidden Alley: the dark slot between the gymnasium and the rooftop block.
--
-- CampusPlan gives it as grounds at (265, 390) to (330, 410) linking the two,
-- which is all it needs to be -- sixty-five studs of wet paving with a wall
-- either side, one lamp, and a fire escape at the far end. It is the only lit
-- thing back there and the only way onto the rooftop block, so it wants to read
-- as somewhere you are not supposed to be rather than as a gap between two
-- buildings.
local function buildHiddenAlley(parent: Instance)
	local X0, Z0, X1, Z1 = 265, 390, 330, 410
	local cx, cz = (X0 + X1) / 2, (Z0 + Z1) / 2
	local width = X1 - X0

	tag(part({ Name = "AlleyPaving", Size = Vector3.new(width, 0.9, Z1 - Z0), CFrame = CFrame.new(cx, 0.05, cz), Color = Color3.fromRGB(58, 58, 62), Material = Enum.Material.Slate, Parent = parent }), "TexCourtPaving")
	for _, side in { -1, 1 } do
		tag(part({ Name = "AlleyWall", Size = Vector3.new(width + 2, 22, 2), CFrame = CFrame.new(cx, 11, cz + side * ((Z1 - Z0) / 2)), Color = Color3.fromRGB(111, 103, 92), Material = Enum.Material.Slate, Parent = parent }), "TexCoursedStone")
		tag(part({ Name = "AlleyCoping", Size = Vector3.new(width + 3, 1.2, 3), CFrame = CFrame.new(cx, 22.6, cz + side * ((Z1 - Z0) / 2)), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
	end
	-- the one lamp, bracketed off the gymnasium wall
	local glow = part({ Name = "AlleyLampGlow", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(X1 - 6, 15, cz), Color = Color3.fromRGB(255, 220, 160), Material = Enum.Material.Neon, Transparency = 0.35, Parent = parent })
	glow.CanCollide = false
	glow.CastShadow = false
	part({ Name = "AlleyLampBracket", Size = Vector3.new(5, 0.5, 0.5), CFrame = CFrame.new(X1 - 3.4, 15.8, cz), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(255, 220, 160)
	lamp.Brightness = 1.6
	lamp.Range = 44
	lamp.Shadows = false
	lamp.Parent = glow
	prop("WallLantern", CFrame.new(X1 - 6, 15, cz))

	-- the fire escape up the rooftop block, which is what the alley is FOR
	for i = 0, 11 do
		part({ Name = "FireEscapeTread", Size = Vector3.new(5, 0.4, 1.4), CFrame = CFrame.new(X0 + 4, 1.4 + i * 1.3, cz - 6 + i * 1.1), Color = Color3.fromRGB(64, 66, 74), Material = Enum.Material.DiamondPlate, Parent = parent })
	end
	part({ Name = "FireEscapeRail", Size = Vector3.new(0.4, 12, 0.4), CFrame = CFrame.new(X0 + 6.4, 8, cz), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	part({ Name = "FireEscapePlatform", Size = Vector3.new(9, 0.5, 7), CFrame = CFrame.new(X0 + 3, 16.4, cz + 7), Color = Color3.fromRGB(64, 66, 74), Material = Enum.Material.DiamondPlate, Parent = parent })
	-- back-of-house dressing: this is where the bins live
	-- inside the alley walls, not out in the boundary planting
	prop("Bin", CFrame.new(X0 + 22, 0, cz + 4))
	prop("Bin", CFrame.new(X0 + 30, 0, cz - 4))
	local sign = part({ Name = "AlleySign", Size = Vector3.new(9, 3, 0.4), CFrame = CFrame.new(cx, 13, Z0 + 1.4), Color = Color3.fromRGB(22, 35, 63), Parent = parent })
	sign.CanCollide = false
	signText(sign, "NO ENTRY", Color3.fromRGB(217, 180, 92), Enum.NormalId.Back)
end

local TREE_KINDS = { "KTreeOak", "KTree", "KTreeTall", "KTreeThin" }

local function meshTree(parent: Instance, pos: Vector3, scale: number)
	-- chosen by position, so the same tree stands in the same place on every
	-- server rather than reshuffling on each build
	local seed = math.floor(math.abs(pos.X) * 3 + math.abs(pos.Z) * 7)
	local kind = TREE_KINDS[(seed % #TREE_KINDS) + 1]
	prop(kind, CFrame.new(pos) * CFrame.Angles(0, (seed % 62) / 10, 0), { scale = scale * 0.62 })
end

local function scatter(zone: Zone)
	local available = {}
	for _, kind in zone.pool do
		if PropSizes[kind] then
			table.insert(available, kind)
		end
	end
	if #available == 0 then
		return
	end

	local rng = Random.new(zone.seed)
	local margin = zone.margin or 1
	local placed: { { at: Vector2, radius: number } } = {}

	-- Seed the occupancy with anything already placed by hand inside this
	-- rectangle. Without this the scatter cheerfully drops a planter through
	-- the dorm chest of drawers, because it only knows about its own picks.
	for _, existing in propRequests do
		local size = PropSizes[existing.kind]
		if not size then
			continue
		end
		local at = Vector2.new(existing.cframe.Position.X, existing.cframe.Position.Z)
		local radius = math.sqrt(size.X * size.X + size.Z * size.Z) * 0.5 + 0.5
		if at.X > zone.min.X - radius and at.X < zone.max.X + radius
			and at.Y > zone.min.Y - radius and at.Y < zone.max.Y + radius then
			table.insert(placed, { at = at, radius = radius })
		end
	end
	local prior = #placed

	local attempts = 0
	while #placed - prior < zone.count and attempts < zone.count * 40 do
		attempts += 1
		local kind = available[rng:NextInteger(1, #available)]
		local size = PropSizes[kind]
		-- circumradius: props are dropped at a random yaw, and half the longest
		-- side is not far enough for a box turned forty-five degrees
		local radius = math.sqrt(size.X * size.X + size.Z * size.Z) * 0.5 + 0.5
		local inset = margin + radius
		if zone.max.X - zone.min.X < inset * 2 or zone.max.Y - zone.min.Y < inset * 2 then
			continue
		end
		local at = Vector2.new(
			rng:NextNumber(zone.min.X + inset, zone.max.X - inset),
			rng:NextNumber(zone.min.Y + inset, zone.max.Y - inset)
		)
		-- `inside` marks a zone the author has deliberately put within a drawn
		-- footprint -- the two quadrangles are open courtyards in the middle
		-- of the Academy's rect, and blocking the whole rect stripped their
		-- planting the moment the drawing started blocking scatter.
		local clear = zone.inside == true or not scatterBlocked(at.X, at.Y, radius)
		for _, other in placed do
			if not clear then
				break
			end
			if (at - other.at).Magnitude < radius + other.radius then
				clear = false
				break
			end
		end
		if clear then
			table.insert(placed, { at = at, radius = radius })
			prop(kind, CFrame.new(at.X, zone.y, at.Y) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		end
	end
end

local function buildInteriorWall(parent: Instance, from: Vector3, to: Vector3, gaps: { { at: number, width: number } })
	local dir = (to - from)
	local length = dir.Magnitude
	local unit = dir.Unit
	local perp = Vector3.new(-unit.Z, 0, unit.X)
	local cuts = { 0, length }
	for _, gap in gaps do
		table.insert(cuts, math.clamp(gap.at - gap.width / 2, 0, length))
		table.insert(cuts, math.clamp(gap.at + gap.width / 2, 0, length))
	end
	table.sort(cuts)
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		local isGap = false
		for _, gap in gaps do
			local mid = (a + b) / 2
			if mid > gap.at - gap.width / 2 and mid < gap.at + gap.width / 2 then
				isGap = true
				break
			end
		end
		local segLen = b - a
		if isGap or segLen < 0.8 then
			continue
		end
		local mid = from + unit * ((a + b) / 2)
		local cf = CFrame.lookAt(mid, mid + perp)
		tag(part({ Name = "InnerWainscot", Size = Vector3.new(segLen, 4.6, 1.6), CFrame = cf * CFrame.new(0, 2.3, 0) , Color = Color3.fromRGB(94, 118, 158), Material = Enum.Material.SmoothPlastic, Parent = parent }), "TexWood")
		part({ Name = "InnerWainscotCap", Size = Vector3.new(segLen, 0.5, 1.8), CFrame = cf * CFrame.new(0, 4.75, 0) , Color = Color3.fromRGB(226, 222, 210), Material = Enum.Material.SmoothPlastic, Parent = parent })
		tag(part({ Name = "InnerWallUpper", Size = Vector3.new(segLen, 10.6, 1.4), CFrame = cf * CFrame.new(0, 10.3, 0) , Color = Color3.fromRGB(238, 234, 224), Material = Enum.Material.SmoothPlastic, Parent = parent }), "TexPlaster")

		-- skirting, chair rail and cornice down both faces of the run
		for _, face in { 1, -1 } do
			local run = cf * CFrame.Angles(0, face > 0 and 0 or math.pi, 0)
			local wallFace = run * CFrame.new(-segLen / 2, 0, -0.82)
			moulding(wallFace * CFrame.new(0, 0.05, 0), "skirting", segLen)
			moulding(wallFace * CFrame.new(0, 4.5, 0), "chairrail", segLen)
			moulding(wallFace * CFrame.new(0, 14.0, 0), "cornice", segLen)
		end
	end
	for _, gap in gaps do
		local mid = from + unit * gap.at
		local cf = CFrame.lookAt(mid, mid + perp)
		for _, side in { -1, 1 } do
			part({ Name = "InnerDoorPost", Size = Vector3.new(1.2, 11, 1.9), CFrame = cf * CFrame.new(side * (gap.width / 2 + 0.6), 5.5, 0) , Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
		end
		part({ Name = "InnerDoorLintel", Size = Vector3.new(gap.width + 2.6, 1.6, 1.9), CFrame = cf * CFrame.new(0, 11.8, 0) , Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
		part({ Name = "InnerDoorHeader", Size = Vector3.new(gap.width + 2.6, 3.9, 1.4), CFrame = cf * CFrame.new(0, 14.7, 0) , Color = Color3.fromRGB(238, 234, 224), Material = Enum.Material.SmoothPlastic, Parent = parent })

		-- architrave: two jambs and a head, framing the opening on both faces
		for _, face in { 1, -1 } do
			local run = cf * CFrame.Angles(0, face > 0 and 0 or math.pi, 0)
			local half = gap.width / 2 + 1.2
			for _, side in { -1, 1 } do
				moulding(run * CFrame.new(side * half, 0.1, -1.0) * CFrame.Angles(0, 0, math.rad(90)), "architrave", 12.4)
			end
			moulding(run * CFrame.new(-half, 12.5, -1.0), "architrave", half * 2)
		end
	end
end

-- The main school becomes a real building: an outer shell around the hallway
-- and all eight homerooms, wing roofs, interior lights, and a grand entrance.
local function buildMainShell(parent: Instance)
	local x0, x1, z0, z1 = -168, 168, -84, 84
	buildWallRun(parent, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), { { at = 168, width = 16 } }, true) -- north (path to classroom)
	buildWallRun(parent, Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1), { { at = 168, width = 30 } }, true) -- south (main entrance)
	buildWallRun(parent, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), { { at = 84, width = 30 } }, true) -- west hallway mouth
	buildWallRun(parent, Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), { { at = 84, width = 30 } }, true) -- east hallway mouth

	-- gabled slate roofs over the homeroom rows (skylight strip stays over the hallway)
	local pitch = math.rad(12)
	for _, zc in { -55, 55 } do
		for _, side in { -1, 1 } do
			tag(part({
				Name = "WingRoofSlope",
				Size = Vector3.new(336, 1.2, 30.6),
				CFrame = CFrame.new(0, 29.8, zc + side * 14.5) * CFrame.Angles(side * pitch, 0, 0),
				Color = Color3.fromRGB(62, 78, 70),
				Material = Enum.Material.Slate,
				Parent = parent,
			}), "TexSlateRoof")
		end
		part({ Name = "WingRidge", Size = Vector3.new(336, 0.9, 2.4), CFrame = CFrame.new(0, 33.2, zc), Color = Color3.fromRGB(52, 64, 58), Material = Enum.Material.Slate, Parent = parent })
		part({ Name = "WingCeiling", Size = Vector3.new(336, 0.8, 58), CFrame = CFrame.new(0, 26.6, zc), Color = Color3.fromRGB(214, 210, 200), Material = Enum.Material.SmoothPlastic, Parent = parent })
	end
	-- interior lights above each homeroom
	for _, zc in { -52, 52 } do
		for _, xc in { -117, -39, 39, 117 } do
			local strip = part({ Name = "WingLight", Size = Vector3.new(26, 0.4, 1), CFrame = CFrame.new(xc, 15.6, zc), Color = Color3.fromRGB(255, 244, 214), Material = Enum.Material.Neon, Parent = parent })
			local light = Instance.new("PointLight")
			light.Brightness = 1.1
			light.Range = 36
			light.Color = Color3.fromRGB(255, 238, 200)
			light.Parent = strip
		end
	end

	-- grand entrance: steps, columns, facade sign
	part({ Name = "EntranceStepLow", Size = Vector3.new(34, 1, 8), CFrame = CFrame.new(0, 0.5, 90), Color = Color3.fromRGB(200, 196, 186), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "EntranceStepHigh", Size = Vector3.new(30, 1, 5), CFrame = CFrame.new(0, 1.0, 87), Color = Color3.fromRGB(214, 210, 200), Material = Enum.Material.Concrete, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "EntranceColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(15, 2.6, 2.6), CFrame = CFrame.new(side * 17, 7.5, 87) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
	end
	local facade = part({ Name = "FacadeSign", Size = Vector3.new(52, 5.4, 1.4), CFrame = CFrame.new(0, 24.4, 84.4), Color = Color3.fromRGB(24, 32, 58), Parent = parent })
	signText(facade, "DETENTION", Color3.fromRGB(255, 196, 60), Enum.NormalId.Front)
	signText(facade, "DETENTION", Color3.fromRGB(255, 196, 60), Enum.NormalId.Back)

	-- brick clock tower rising over the entrance (the campus landmark)
	local towerBrick = Color3.fromRGB(138, 128, 114)
	tag(part({ Name = "ClockTower", Size = Vector3.new(14, 34, 14), CFrame = CFrame.new(0, 33, 78), Color = towerBrick, Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
	part({ Name = "TowerClockBlock", Size = Vector3.new(15.5, 12, 15.5), CFrame = CFrame.new(0, 44, 78), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "TowerTrim", Size = Vector3.new(16.2, 1.6, 16.2), CFrame = CFrame.new(0, 50.6, 78), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "TowerCap", Size = Vector3.new(12, 4, 12), CFrame = CFrame.new(0, 53.4, 78), Color = Color3.fromRGB(60, 72, 86), Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "TowerSpire", Size = Vector3.new(1.2, 7, 1.2), CFrame = CFrame.new(0, 58.9, 78), Color = Color3.fromRGB(255, 196, 60), Material = Enum.Material.Metal, Parent = parent })
	for _, side in { { normal = Enum.NormalId.Front, cf = CFrame.new(0, 44, 86.0) }, { normal = Enum.NormalId.Back, cf = CFrame.new(0, 44, 70.0) } } do
		local face = part({ Name = "ClockFace", Size = Vector3.new(8, 8, 0.4), CFrame = side.cf, Color = Color3.fromRGB(240, 236, 224), Material = Enum.Material.SmoothPlastic, Parent = parent })
		local hourHand = part({ Name = "ClockHour", Size = Vector3.new(0.6, 2.6, 0.2), CFrame = side.cf * CFrame.new(0, 1.1, side.normal == Enum.NormalId.Front and 0.31 or -0.31), Color = Color3.fromRGB(28, 30, 34), Parent = parent })
		local minuteHand = part({ Name = "ClockMinute", Size = Vector3.new(0.5, 3.4, 0.2), CFrame = side.cf * CFrame.new(1.0, 0.6, side.normal == Enum.NormalId.Front and 0.32 or -0.32) * CFrame.Angles(0, 0, math.rad(-55)), Color = Color3.fromRGB(28, 30, 34), Parent = parent })
		local _ = hourHand
		local _ = minuteHand
		local ring = Instance.new("SelectionBox")
		ring.Adornee = face
		ring.Color3 = Color3.fromRGB(120, 90, 40)
		ring.LineThickness = 0.06
		ring.Parent = face
	end
end

-- Dormitory: a snug building full of beds. Napping gives a luck buff.
-- Boys and girls dorms share a layout but wear their own accent color.
-- ================= THE BOARDING HOUSES =================
-- A seventy-by-sixty box, one storey, with three stepped slabs on top for a
-- roof and its front door facing AWAY from the school. That is a shed with
-- beds in it, and it was two of the four buildings a player spends real time
-- in.
--
-- This is a boarding house: two storeys, a pitched roof with dormers and
-- chimneys, a porch you come up steps onto, and the beds upstairs where beds
-- go. The common room, the kitchen and the washroom are on the ground floor,
-- and the stair between them is in the east bay with a proper well cut for it.
-- buildDorm is gone. The boarding house comes out of the drawing now:
-- PlanBuilder renders its shell and furnishDorms puts the beds, the kitchen,
-- the washroom and the study in the rooms CampusPlan names.

-- ===== 1:1 reference-art detail pass =========================================
-- Brick academy w/ white trim + castellated towers, furnished interiors,
-- courtyard balconies + lined courts, front lawn with fence and parking.

local WHITE_TRIM = Color3.fromRGB(232, 228, 218)
local BRICK = Color3.fromRGB(138, 128, 114)
local HEDGE = Color3.fromRGB(52, 96, 48)

local function buildCornerTower(parent: Instance, x: number, z: number)
	tag(part({ Name = "CornerTower", Size = Vector3.new(12, 36, 12), CFrame = CFrame.new(x, 18, z), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
	part({ Name = "TowerBand", Size = Vector3.new(13, 1.2, 13), CFrame = CFrame.new(x, 34.4, z), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	-- crenellated top
	for _, offset in { Vector3.new(-4.5, 0, -4.5), Vector3.new(4.5, 0, -4.5), Vector3.new(-4.5, 0, 4.5), Vector3.new(4.5, 0, 4.5), Vector3.new(0, 0, -4.5), Vector3.new(0, 0, 4.5), Vector3.new(-4.5, 0, 0), Vector3.new(4.5, 0, 0) } do
		part({ Name = "Merlon", Size = Vector3.new(2.4, 2.2, 2.4), CFrame = CFrame.new(x + offset.X, 37.1, z + offset.Z), Color = BRICK, Material = Enum.Material.Brick, Parent = parent })
	end
	local shield = part({ Name = "TowerShield", Size = Vector3.new(3.4, 4, 0.4), CFrame = CFrame.new(x, 29, z + (z > 0 and 6.3 or -6.3)), Color = Color3.fromRGB(24, 32, 58), Parent = parent })
	signText(shield, "D", Color3.fromRGB(255, 196, 60), z > 0 and Enum.NormalId.Front or Enum.NormalId.Back)
end

local function buildPortico(parent: Instance, x: number)
	-- white columned entry with a stepped pediment, on the south face
	local z = 86.5
	for i = 0, 3 do
		part({ Name = "PorticoColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(13, 2.0, 2.0), CFrame = CFrame.new(x - 7.5 + i * 5, 6.5, z) * CFrame.Angles(0, 0, math.rad(90)), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	part({ Name = "PorticoBeam", Size = Vector3.new(20, 2, 5), CFrame = CFrame.new(x, 14, z - 0.6), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "PorticoPed1", Size = Vector3.new(16, 1.6, 4.4), CFrame = CFrame.new(x, 15.8, z - 0.6), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "PorticoPed2", Size = Vector3.new(10, 1.6, 4.0), CFrame = CFrame.new(x, 17.4, z - 0.6), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "PorticoPed3", Size = Vector3.new(4, 1.6, 3.6), CFrame = CFrame.new(x, 19.0, z - 0.6), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
end

local function buildFrontYard(parent: Instance)
	-- lawns + hedges in the strip between the building and the courtyard
	part({ Name = "FrontLawnWest", Size = Vector3.new(120, 0.35, 22), CFrame = CFrame.new(-85, 0.18, 102), Color = Color3.fromRGB(96, 152, 80), Material = Enum.Material.Grass, Parent = parent })
	part({ Name = "FrontLawnEast", Size = Vector3.new(50, 0.35, 22), CFrame = CFrame.new(50, 0.18, 102), Color = Color3.fromRGB(96, 152, 80), Material = Enum.Material.Grass, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "FrontHedge", Size = Vector3.new(110, 3.2, 2.6), CFrame = CFrame.new(side * 85, 1.6, 91), Color = HEDGE, Material = Enum.Material.Grass, Parent = parent })
	end
	-- short iron fence runs framing the lawns (kept clear of the courtyard)
	for _, run in { { x0 = -140, x1 = -30 }, { x0 = 78, x1 = 145 } } do
		local mid = (run.x0 + run.x1) / 2
		local length = run.x1 - run.x0
		for x = run.x0, run.x1, 14 do
			part({ Name = "FencePier", Size = Vector3.new(2, 5, 2), CFrame = CFrame.new(x, 2.5, 113), Color = BRICK, Material = Enum.Material.Brick, Parent = parent })
		end
		part({ Name = "FenceRail", Size = Vector3.new(length, 0.5, 0.4), CFrame = CFrame.new(mid, 3.9, 113), Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "FenceRailLow", Size = Vector3.new(length, 0.5, 0.4), CFrame = CFrame.new(mid, 1.3, 113), Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.Metal, Parent = parent })
	end
	-- tall cypress pairs flanking the porticos and gates
	for _, x in { -74, -46, 46, 74, -20, 20 } do
		for layer = 0, 2 do
			local w = 3.4 - layer * 0.9
			part({ Name = "Cypress", Size = Vector3.new(w, 4.6, w), CFrame = CFrame.new(x, 2.3 + layer * 4.2, 93.5) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(44, 88, 46), Material = Enum.Material.Grass, Parent = parent })
		end
	end
	-- lampposts lighting the entrance walk
	for _, spot in { Vector3.new(-9, 0, 100), Vector3.new(9, 0, 100), Vector3.new(-9, 0, 128), Vector3.new(9, 0, 128) } do
		part({ Name = "LampPost", Size = Vector3.new(0.7, 9, 0.7), CFrame = CFrame.new(spot.X, 4.5, spot.Z), Color = Color3.fromRGB(34, 38, 44), Material = Enum.Material.Metal, Parent = parent })
		local lamp = part({ Name = "LampHead", Size = Vector3.new(1.5, 1.5, 1.5), CFrame = CFrame.new(spot.X, 9.6, spot.Z), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, Parent = parent })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 234, 190)
		light.Brightness = 1.2
		light.Range = 24
		light.Parent = lamp
	end

	-- parking lot east of the entrance strip
	part({ Name = "ParkingLot", Size = Vector3.new(64, 0.3, 22), CFrame = CFrame.new(110, 0.16, 100), Color = Color3.fromRGB(74, 76, 80), Material = Enum.Material.Asphalt, Parent = parent })
	for i = 0, 5 do
		part({ Name = "ParkingLine", Size = Vector3.new(0.6, 0.32, 10), CFrame = CFrame.new(86 + i * 9, 0.2, 95), Color = Color3.fromRGB(230, 230, 230), Parent = parent })
	end
end

local function detailHallway(parent: Instance)
	-- terrazzo accent tiles down the hallway + water coolers + open lockers
	for i = 0, 7 do
		part({ Name = "TerrazzoTile", Size = Vector3.new(6, 0.22, 6), CFrame = CFrame.new(-140 + i * 40, 0.12, 0), Color = Color3.fromRGB(228, 224, 214), Material = Enum.Material.Marble, Parent = parent })
	end
	for _, x in { -70, 70 } do
		local cooler = part({ Name = "WaterCooler", Size = Vector3.new(1.8, 4, 1.8), CFrame = CFrame.new(x, 2, -12.4), Color = Color3.fromRGB(36, 38, 42), Parent = parent })
		local _ = cooler
		part({ Name = "CoolerJug", Size = Vector3.new(1.4, 1.6, 1.4), CFrame = CFrame.new(x, 4.8, -12.4), Color = Color3.fromRGB(190, 220, 240), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
	end
	-- a few open lockers with shelves + books (reference shot detail)
	for _, spec in { { x = -110, z = 13.2 }, { x = -46, z = -13.2 }, { x = 94, z = 13.2 } } do
		local inward = spec.z > 0 and -1 or 1
		part({ Name = "OpenLockerBox", Size = Vector3.new(2.2, 7.8, 1.4), CFrame = CFrame.new(spec.x, 4.2, spec.z + inward * 0.2), Color = Color3.fromRGB(38, 70, 140), Parent = parent })
		part({ Name = "OpenLockerDoor", Size = Vector3.new(2.1, 7.8, 0.3), CFrame = CFrame.new(spec.x - 1.7, 4.2, spec.z + inward * 1.3) * CFrame.Angles(0, math.rad(inward * 65), 0), Color = Color3.fromRGB(58, 104, 196), Parent = parent })
		for shelf = 0, 1 do
			part({ Name = "LockerShelf", Size = Vector3.new(1.9, 0.2, 1.2), CFrame = CFrame.new(spec.x, 3.2 + shelf * 2.4, spec.z + inward * 0.2), Color = Color3.fromRGB(30, 56, 118), Parent = parent })
			part({ Name = "LockerBook", Size = Vector3.new(0.5, 1.1, 0.9), CFrame = CFrame.new(spec.x - 0.4, 3.9 + shelf * 2.4, spec.z + inward * 0.2), Color = ({ Color3.fromRGB(214, 82, 60), Color3.fromRGB(240, 214, 120) })[shelf + 1], Parent = parent })
		end
	end
end

local function detailCourtyard(parent: Instance)
	-- white court boundary lines
	for _, line in {
		{ size = Vector3.new(34, 0.24, 0.7), cf = CFrame.new(-38, 0.14, 147) },
		{ size = Vector3.new(34, 0.24, 0.7), cf = CFrame.new(-38, 0.14, 169) },
		{ size = Vector3.new(0.7, 0.24, 22), cf = CFrame.new(-55, 0.14, 158) },
		{ size = Vector3.new(0.7, 0.24, 22), cf = CFrame.new(-21, 0.14, 158) },
		{ size = Vector3.new(30, 0.24, 0.7), cf = CFrame.new(40, 0.14, 149.5) },
		{ size = Vector3.new(30, 0.24, 0.7), cf = CFrame.new(40, 0.14, 166.5) },
		{ size = Vector3.new(0.7, 0.24, 17), cf = CFrame.new(25, 0.14, 158) },
		{ size = Vector3.new(0.7, 0.24, 17), cf = CFrame.new(55, 0.14, 158) },
	} do
		part({ Name = "CourtLine", Size = line.size, CFrame = line.cf, Color = Color3.fromRGB(240, 240, 240), Parent = parent })
	end
	-- palm trees flanking the courts
	for _, x in { -14, 14 } do
		for layer = 0, 3 do
			part({ Name = "PalmTrunk", Size = Vector3.new(1.4 - layer * 0.15, 3, 1.4 - layer * 0.15), CFrame = CFrame.new(x + layer * 0.5, 1.5 + layer * 2.8, 176), Color = Color3.fromRGB(140, 104, 76), Material = Enum.Material.Wood, Parent = parent })
		end
		for leaf = 0, 5 do
			local angle = leaf * math.pi / 3
			part({ Name = "PalmLeaf", Size = Vector3.new(6, 0.3, 1.8), CFrame = CFrame.new(x + 1.5 + math.cos(angle) * 2.6, 13, 176 + math.sin(angle) * 2.6) * CFrame.Angles(0, -angle, math.rad(-18)), Color = Color3.fromRGB(64, 132, 60), Material = Enum.Material.Grass, Parent = parent })
		end
	end
	-- balcony walkway over the courtyard face of the main building
	part({ Name = "BalconyFloor", Size = Vector3.new(96, 1, 7), CFrame = CFrame.new(0, 17.2, 89.5), Color = Color3.fromRGB(200, 196, 186), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "BalconyRail", Size = Vector3.new(96, 2.4, 0.5), CFrame = CFrame.new(0, 18.9, 93), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	for i = 0, 8 do
		if i ~= 4 then -- keep the entrance walk clear
			part({ Name = "BalconyPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 1.4, 1.4), CFrame = CFrame.new(-44 + i * 11, 8.5, 92) * CFrame.Angles(0, 0, math.rad(90)), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
		end
	end
end

-- The courtyard from the reference render: wrapped on three sides by a
-- two-story colonnade building — open balcony walkway upstairs, flat roof
-- with parapet, flags, and window-textured back walls.
-- Enclosed glazed corridor between two points: floor, walls with a window
-- band, and a flat roof. Turns the scattered rooms into one connected school.
-- An open swung door panel + frame at a doorway (doors, not floating gaps).
local function addOpenDoor(parent: Instance, hingeCf: CFrame, width: number, double: boolean?)
	local leaves = double and 2 or 1
	for i = 1, leaves do
		local side = i == 1 and -1 or 1
		local leafWidth = double and width / 2 - 0.3 or width - 0.6
		local panel = part({
			Name = "DoorPanel",
			Size = Vector3.new(leafWidth, 10.5, 0.35),
			CFrame = hingeCf
				* CFrame.new(side * (width / 2), 5.25, 0)
				* CFrame.Angles(0, math.rad(side * -105), 0)
				* CFrame.new(-side * leafWidth / 2, 0, 0),
			Color = Color3.fromRGB(96, 66, 44),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		part({
			Name = "DoorWindow",
			Size = Vector3.new(math.min(leafWidth * 0.4, 2), 2.4, 0.1),
			CFrame = panel.CFrame * CFrame.new(0, 2.2, -0.24),
			Color = Color3.fromRGB(180, 210, 230),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			Parent = parent,
		})
	end
end

-- Interior floor plan: every homeroom becomes an enclosed room off the
-- hallway — front wall with a doorway, partitions between neighbors.
local function buildHomeroomWalls(parent: Instance)
	for _, zSign in { -1, 1 } do
		local z = zSign * 27
		-- hallway-facing wall with a doorway per homeroom
		buildWallRun(
			parent,
			Vector3.new(-156, 0, z),
			Vector3.new(156, 0, z),
			{ { at = 39, width = 16 }, { at = 117, width = 16 }, { at = 195, width = 16 }, { at = 273, width = 16 } }
		)
		-- doors standing open in each doorway
		for _, x in { -117, -39, 39, 117 } do
			local inward = Vector3.new(x, 0, zSign * 30)
			addOpenDoor(parent, CFrame.lookAt(Vector3.new(x, 0, z), inward), 16, true)
		end
		-- partitions between neighboring homerooms
		for _, x in { -78, 0, 78, -152, 152 } do
			part({
				Name = "HomeroomPartition",
				Size = Vector3.new(2, 13, 50),
				CFrame = CFrame.new(x, 6.5, zSign * 52),
				Color = Color3.fromRGB(214, 206, 186),
				Material = Enum.Material.Concrete,
				Parent = parent,
			})
		end
	end
end

local function buildCorridor(parent: Instance, from: Vector3, to: Vector3, width: number)
	local dir = to - from
	local length = dir.Magnitude
	local unit = dir.Unit
	local mid = from + unit * (length / 2)
	local cf = CFrame.lookAt(mid, to)
	part({ Name = "CorridorFloor", Size = Vector3.new(width, 0.6, length + 2), CFrame = cf * CFrame.new(0, 0.05, 0), Color = Color3.fromRGB(196, 194, 188), Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "CorridorWallLow", Size = Vector3.new(1.4, 4.5, length), CFrame = cf * CFrame.new(side * (width / 2), 2.25, 0), Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Brick, Parent = parent })
		part({ Name = "CorridorGlass", Size = Vector3.new(1.0, 3.6, length), CFrame = cf * CFrame.new(side * (width / 2), 6.3, 0), Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
		part({ Name = "CorridorBand", Size = Vector3.new(1.4, 1.6, length), CFrame = cf * CFrame.new(side * (width / 2), 8.9, 0), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
	end
	part({ Name = "CorridorRoof", Size = Vector3.new(width + 2.4, 1, length + 2), CFrame = cf * CFrame.new(0, 10.2, 0), Color = Color3.fromRGB(84, 98, 110), Material = Enum.Material.Slate, Parent = parent })
end

local function buildCourtyardWings(parent: Instance)
	local STONE = Color3.fromRGB(196, 200, 206)
	local wings = {
		{ from = Vector3.new(-65, 0, 115), to = Vector3.new(-65, 0, 185), inner = Vector3.new(1, 0, 0), gapAt = 45 },
		{ from = Vector3.new(65, 0, 115), to = Vector3.new(65, 0, 185), inner = Vector3.new(-1, 0, 0), gapAt = 45 },
		{ from = Vector3.new(-65, 0, 190), to = Vector3.new(65, 0, 190), inner = Vector3.new(0, 0, -1), gapAt = -1 },
	}
	for _, wing in wings do
		local dir = (wing.to - wing.from)
		local length = dir.Magnitude
		local unit = dir.Unit
		local mid = wing.from + unit * (length / 2)
		local cf = CFrame.lookAt(mid, mid + wing.inner)
		-- back wall (two stories of window texture; split around the walk-through gap)
		local segments: { { number } } = if wing.gapAt >= 0
			then { { 0, wing.gapAt - 9 }, { wing.gapAt + 9, length } }
			else { { 0, length } }
		for _, seg in segments do
			local segLen2 = seg[2] - seg[1]
			if segLen2 > 1 then
				local segMid = wing.from + unit * ((seg[1] + seg[2]) / 2)
				local segCf = CFrame.lookAt(segMid, segMid + wing.inner)
				tag(part({ Name = "WingBackLow", Size = Vector3.new(segLen2, 10, 1.6), CFrame = segCf * CFrame.new(0, 5, -8) , Color = Color3.fromRGB(105, 118, 138), Material = Enum.Material.Concrete, Parent = parent }), "TexBlueStone")
			end
		end
		tag(part({ Name = "WingBackHigh", Size = Vector3.new(length, 9, 1.6), CFrame = cf * CFrame.new(0, 15, -8) , Color = Color3.fromRGB(105, 118, 138), Material = Enum.Material.Concrete, Parent = parent }), "TexBlueStone")
		-- second-floor balcony slab + railing
		part({ Name = "WingBalcony", Size = Vector3.new(length, 1, 9), CFrame = cf * CFrame.new(0, 10.2, -3.5) , Color = STONE, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "WingRailTop", Size = Vector3.new(length, 0.5, 0.5), CFrame = cf * CFrame.new(0, 13.4, 0.6) , Color = Color3.fromRGB(235, 235, 235), Parent = parent })
		part({ Name = "WingRailPanel", Size = Vector3.new(length, 2.2, 0.25), CFrame = cf * CFrame.new(0, 12.2, 0.6) , Color = Color3.fromRGB(210, 214, 220), Transparency = 0.25, Parent = parent })
		-- flat roof + parapet
		part({ Name = "WingTopRoof", Size = Vector3.new(length + 2, 1, 11), CFrame = cf * CFrame.new(0, 20.2, -3) , Color = Color3.fromRGB(154, 158, 164), Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "WingTopParapet", Size = Vector3.new(length + 2, 1.6, 0.6), CFrame = cf * CFrame.new(0, 21.3, 2.2) , Color = STONE, Parent = parent })
		-- ground colonnade (cylindrical columns on the courtyard side)
		local count = math.floor(length / 10)
		for i = 0, count do
			local at = i * (length / count)
			if wing.gapAt < 0 or math.abs(at - wing.gapAt) > 9 then
				part({ Name = "WingColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 1.6, 1.6), CFrame = CFrame.lookAt(wing.from + unit * at, wing.from + unit * at + wing.inner) * CFrame.new(0, 5, 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Concrete, Parent = parent })
			end
		end
		-- upper-floor columns matching the rhythm
		for i = 0, count do
			local at = i * (length / count)
			part({ Name = "WingColumnUp", Size = Vector3.new(1.2, 9, 1.2), CFrame = CFrame.lookAt(wing.from + unit * at, wing.from + unit * at + wing.inner) * CFrame.new(0, 15.5, -7.4), Color = STONE, Material = Enum.Material.Concrete, Parent = parent })
		end
	end
	-- flags on the south wing roof
	local flagColors = { Color3.fromRGB(232, 76, 76), Color3.fromRGB(255, 196, 60), Color3.fromRGB(64, 140, 226), Color3.fromRGB(74, 160, 90) }
	for i = 0, 3 do
		local x = -45 + i * 30
		part({ Name = "RoofFlagPole", Size = Vector3.new(0.5, 8, 0.5), CFrame = CFrame.new(x, 24.7, 190), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "RoofFlag", Size = Vector3.new(4, 2.4, 0.2), CFrame = CFrame.new(x + 2.2, 27.4, 190), Color = flagColors[i + 1], Parent = parent })
	end
	-- raised stone viewing platform with steps on the west edge (reference left side)
	part({ Name = "CourtPlatform", Size = Vector3.new(16, 3, 26), CFrame = CFrame.new(-52, 1.5, 128), Color = Color3.fromRGB(178, 182, 188), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "CourtSteps1", Size = Vector3.new(4, 1, 26), CFrame = CFrame.new(-42, 0.5, 128), Color = Color3.fromRGB(190, 194, 200), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "CourtSteps2", Size = Vector3.new(4, 2, 26), CFrame = CFrame.new(-46, 1.0, 128), Color = Color3.fromRGB(184, 188, 194), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "PlatformRail", Size = Vector3.new(0.5, 3, 26), CFrame = CFrame.new(-59.7, 4.5, 128), Color = Color3.fromRGB(235, 235, 235), Parent = parent })
	-- extra bunting: two diagonal lines like the render
	for _, spec in {
		{ from = Vector3.new(-58, 18, 120), to = Vector3.new(58, 15, 150) },
		{ from = Vector3.new(-58, 15, 178), to = Vector3.new(58, 18, 152) },
	} do
		local dirv = spec.to - spec.from
		local lineMid = spec.from + dirv * 0.5
		local lineCf = CFrame.lookAt(lineMid, spec.to)
		part({ Name = "BuntingLineDiag", Size = Vector3.new(0.15, 0.15, dirv.Magnitude), CFrame = lineCf, Color = Color3.fromRGB(220, 220, 220), Parent = parent })
		local flagColors2 = { Color3.fromRGB(232, 76, 76), Color3.fromRGB(255, 196, 60), Color3.fromRGB(74, 160, 90), Color3.fromRGB(64, 140, 226), Color3.fromRGB(168, 90, 220) }
		for i = 1, 12 do
			local alpha = i / 13
			local pos = spec.from + dirv * alpha
			part({ Name = "BuntingFlagDiag", Size = Vector3.new(1.2, 1.5, 0.14), CFrame = CFrame.new(pos - Vector3.new(0, 0.9, 0)), Color = flagColors2[(i % #flagColors2) + 1], Parent = parent })
		end
	end
end

-- Everything that is not architecture. A room reads as lived-in from the
-- clutter more than from the walls: a bin by the door, a plant in the corner,
-- a clock over the board. These are recorded, not built -- PropService places
-- them from Poly Haven templates once the models have loaded.
local function furnishProps()
	local function row(kind: string, y: number, yaw: number, points: { { number } })
		for _, pt in points do
			prop(kind, CFrame.new(pt[1], y, pt[2]) * CFrame.Angles(0, math.rad(yaw), 0))
		end
	end

	-- ---------------- lobby ----------------
	-- the clock tower comes down through the middle of the lobby, so the
	-- seating goes in the two side bays rather than across the doors
	-- the lobby stairs come down through x 41..51, so the seating stays inside
	-- them rather than under them
	prop("Sofa", CFrame.new(26, 0, 112) * CFrame.Angles(0, math.rad(90), 0))
	prop("Sofa2", CFrame.new(36, 0, 112) * CFrame.Angles(0, math.rad(-90), 0))
	prop("CoffeeTable", CFrame.new(31, 0, 112))
	prop("ArmChair", CFrame.new(31, 0, 106))
	prop("ArmChair", CFrame.new(31, 0, 118) * CFrame.Angles(0, math.pi, 0))
	prop("GrandfatherClock", CFrame.new(56, 0, 119) * CFrame.Angles(0, math.rad(-90), 0))
	-- The two statues used to stand at twice size in the WEST bay, one of them
	-- four studs from the stair foot: between them they took nine metres of the
	-- room a player crosses on the way in, and the hall read as a junk shop.
	-- One to each side wall now, at a size a school could afford.
	prop("WhaleStatue", CFrame.new(-56, 0, 130) * CFrame.Angles(0, math.pi, 0), { scale = 1.2 })
	prop("RayStatue", CFrame.new(56, 0, 130) * CFrame.Angles(0, math.pi, 0), { scale = 1.2 })
	prop("Vase1", CFrame.new(-38, 3.8, 92))
	prop("Vase2", CFrame.new(-22, 3.8, 92))
	row("PlanterPot", 0, 0, { { -56, 86 }, { 42, 122 }, { -56, 118 } })
	-- greenery where people wait, which is every school lobby ever built
	-- in the corners, not either side of the way in
	row("Houseplant", 0, 0, { { -54, 118 }, { 54, 118 } })
	row("Houseplant2", 0, 0, { { -20, 84 }, { 20, 84 } })
	row("Houseplant4", 0, 0, { { -34, 30 }, { 34, 30 } })
	row("PottedPlant", 0, 0, { { -56, 100 }, { 54.5, 93 } })
	-- on the west wall. At x = -40 it hung one stud off the west flight.
	prop("Clock", CFrame.new(-60.5, 12, 102) * CFrame.Angles(0, math.rad(90), 0))

	-- ---------------- atrium ----------------
	row("PlanterBox", 0, 0, { { -28, -20 }, { 28, -20 }, { -28, 32 }, { 28, 32 } })
	row("PottedPlant", 0, 0, { { -34, 6 }, { 34, 6 } })
	row("Bin", 0, 0, { { -44, 30 }, { 44, 30 } })

	-- ---------------- corridors ----------------
	row("Bin", 0, 0, { { -56, 70 }, { 56, 70 }, { -56, -56 }, { 56, -56 } })
	row("Extinguisher", 0, 0, { { -57, 60 }, { 57, 60 }, { -57, -50 }, { 57, -50 } })
	row("WetFloorSign", 0, 25, { { -46, 46 }, { 40, -30 } })
	prop("Clock", CFrame.new(-58.4, 12, 20) * CFrame.Angles(0, math.rad(90), 0))
	prop("Clock", CFrame.new(58.4, 12, 20) * CFrame.Angles(0, math.rad(-90), 0))
	row("FireAlarm", 8, 90, { { -58.4, 40 } })
	row("FireAlarm", 8, -90, { { 58.4, 40 } })

	-- Room 101, the Music Room, the two science pavilions and the gym are
	-- dressed in furnishSubjectRooms, which knows what each room is for. What
	-- used to be here put a teacher's desk at x = -104, inside the homeroom
	-- next door, and a whole second classroom at z = -172 -- a field north of
	-- the gym.

	-- ---------------- library ----------------
	-- These twenty pieces were authored for the library when it stood at
	-- (0, -232). The library moved to (-320, -300) with the sanctum hanging
	-- off it, and the furniture did not: a whole reading room -- four study
	-- desks, eight chairs, two sofas, two shelf banks -- was left standing on
	-- open grass in the middle of what is now the Dorm Court, and the mirror
	-- and the two pictures ended up buried in the boarding house's front wall.
	-- LIB is the library's centre, so the room travels with the building from
	-- here on rather than being re-typed each time it moves.
	local LIB = Vector2.new(-320, -300)
	local function libProp(kind: string, x: number, y: number, z: number, yaw: number?)
		local cf = CFrame.new(LIB.X + x, y, LIB.Y + z)
		if yaw then
			cf *= CFrame.Angles(0, math.rad(yaw), 0)
		end
		prop(kind, cf)
	end
	-- four study tables on the reading carpet, two chairs each
	for i, x in { -33, -11, 11, 33 } do
		libProp("Table", x, 0, 23)
		libProp("Chair", x, 0, 19, 180)
		libProp("Chair2", x, 0, 27)
		if i % 2 == 1 then
			libProp("Vase4", x, 2.7, 23)
		end
	end
	libProp("Sofa", -38, 0, 15, 90)
	libProp("ArmChair", 38, 0, 15, -90)
	libProp("SideTable", -41, 0, 21, 90)
	libProp("LoungeChair", 41, 0, 21, -90)
	-- against the front wall either side of the doors, not down the aisles
	row("SteelShelves", 0, 180, { { LIB.X - 38, LIB.Y + 30 }, { LIB.X + 38, LIB.Y + 30 } })
	libProp("Mirror", 0, 6, -32.4)
	libProp("PictureFrame", -24, 8, -32.4)
	libProp("PictureFrame", 24, 8, -32.4)
	row("PlanterPot", 0, 0, { { LIB.X - 30, LIB.Y + 31 }, { LIB.X + 30, LIB.Y + 31 } })
	libProp("Bin", -38, 0, 28)

	-- ---------------- cafeteria ----------------
	-- The real cafeteria is the outer bay at x -224..-184, z -52..6. What used
	-- to be here laid four dining tables out at z 36..52, which is the middle
	-- of the principal's office.
	for _, cx in { -212, -198 } do
		for _, cz in { -39, -27 } do
			prop("DiningTable", CFrame.new(cx, 0, cz))
			prop("Bench", CFrame.new(cx, 0, cz - 4.4))
			prop("Bench", CFrame.new(cx, 0, cz + 4.4) * CFrame.Angles(0, math.pi, 0))
		end
	end
	-- two more rows, so a room forty by fifty-eight does not seat sixteen
	-- Twelve studs apart, not eight: a refectory table is eleven and a half
	-- long, so a row every eight studs was a row of tables inside each other.
	for _, cx in { -212, -198 } do
		for _, cz in { -16, -4 } do
			prop("RefectoryTable", CFrame.new(cx, 0, cz))
			for _, sx in { -4.6, 4.6 } do
				prop("LoungeStool", CFrame.new(cx + sx, 0, cz))
			end
		end
	end
	-- the servery: a kitchen behind the counter rather than a painted wall
	prop("Fridge", CFrame.new(-220, 0, 4) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Oven", CFrame.new(-211, 0, 5) * CFrame.Angles(0, math.pi, 0))
	prop("KitchenSink", CFrame.new(-204, 0, 5) * CFrame.Angles(0, math.pi, 0))
	prop("KitchenCabinet", CFrame.new(-197, 0, 5) * CFrame.Angles(0, math.pi, 0))
	prop("KitchenDrawers", CFrame.new(-191, 0, 5) * CFrame.Angles(0, math.pi, 0))
	prop("BinLarge", CFrame.new(-186, 0, -4))
	prop("Stool", CFrame.new(-221, 0, -32))
	prop("Stool", CFrame.new(-189, 0, -32))
	prop("Bin", CFrame.new(-221, 0, -48))
	prop("Extinguisher", CFrame.new(-189, 0, -48))
	row("PottedPlant", 0, 0, { { -220, -10 }, { -188, -14 } })

	-- ---------------- the principal's office ----------------
	-- Everything here stays clear of x -222..-206, z 16..40: that is the
	-- sanctum shaft, and a filing cabinet standing in it would give the game
	-- away before the bookshelf did.
	prop("OfficeDesk", CFrame.new(-196, 0, 46) * CFrame.Angles(0, math.pi, 0))
	prop("Laptop", CFrame.new(-196, 2.9, 46))
	prop("Notepads", CFrame.new(-192, 2.9, 46))
	prop("ArmChair", CFrame.new(-196, 0, 52) * CFrame.Angles(0, math.pi, 0))
	prop("SchoolChair", CFrame.new(-200, 0, 40))
	prop("SchoolChair", CFrame.new(-192, 0, 40))
	-- Hard against the east wall at x = -190, not -187: the corridor's south
	-- walking lane runs at z = 56 and a filing cabinet three studs proud of
	-- the wall stood in the middle of it.
	prop("Cabinet", CFrame.new(-190, 0, 30) * CFrame.Angles(0, math.rad(-90), 0))
	prop("SteelShelves2", CFrame.new(-190, 0, 46) * CFrame.Angles(0, math.rad(-90), 0))
	prop("GrandfatherClock", CFrame.new(-190, 0, 12) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Sofa", CFrame.new(-214, 0, 10) * CFrame.Angles(0, math.rad(90), 0))
	prop("CoffeeTable", CFrame.new(-208, 0, 10))
	prop("PottedPlant", CFrame.new(-189, 0, 60))
	prop("Vase1", CFrame.new(-199, 2.9, 46))
	prop("Bin", CFrame.new(-220, 0, 52))
	prop("FramedPicture", CFrame.new(-222.5, 9, 40) * CFrame.Angles(0, math.rad(90), 0))

	-- ---------------- gym ----------------
	row("Football", 0, 0, { { -22, -98 }, { 18, -112 } })
	row("AmericanFootball", 0, 0, { { 8, -94 } })
	row("Baseball", 0, 0, { { -12, -118 } })
	prop("Dartboard", CFrame.new(-48.4, 8, -105) * CFrame.Angles(0, math.rad(90), 0))
	row("Bin", 0, 0, { { -46, -70 }, { 46, -70 } })

	-- ---------------- dorms ----------------
	for _, sx in { -1, 1 } do
		local cx = sx * 176
		-- A day bed, a chest of drawers, a nightstand, a cabinet, a television
		-- and a boombox used to stand in the same floor as the six bunks and
		-- their footlockers, four of them inside each other. A dormitory is
		-- beds; the lounge is the south end of the room.
		prop("Cabinet", CFrame.new(cx + sx * 24, 0, -204) * CFrame.Angles(0, math.rad(-sx * 90), 0))
		prop("Television", CFrame.new(cx + sx * 24, 3.3, -204) * CFrame.Angles(0, math.rad(-sx * 90), 0))
		prop("LoungeChair", CFrame.new(cx, 0, -204) * CFrame.Angles(0, math.pi, 0))
		prop("ModernCoffeeTable", CFrame.new(cx, 0, -198))
		prop("PottedPlant", CFrame.new(cx - sx * 22, 0, -200))
		prop("Bin", CFrame.new(cx + sx * 22, 0, -200))
	end

	-- ---------------- grounds ----------------
	row("PicnicTable", 0, 0, { { -86, 150 }, { 86, 150 }, { -86, 176 }, { 86, 176 } })
	row("PlanterBox", 0, 0, { { -44, 138 }, { 44, 138 }, { -70, 138 }, { 70, 138 } })
	row("Shrub", 0, 0, {
		{ -110, 130 }, { -100, 143 }, { 100, 143 }, { 110, 130 },
		{ -130, 96 }, { 130, 96 }, { -150, 40 }, { 150, 40 },
	})
	-- The inner pair moved out from x +-36 to +-42: the entrance bay now has a
	-- buttress standing at +-31 that runs out to x = 35, and they were planted
	-- a stud inside it.
	row("Flowers", 0, 0, {
		{ -48, 142 }, { -42, 138 }, { 42, 138 }, { 48, 142 },
		{ -120, 112 }, { 120, 112 },
	})
	row("SecurityLight", 9, 0, { { -62, 126.5 }, { 62, 126.5 } })
	-- The industrial lamps that used to hang here at x +-30 are gone: the
	-- entrance now carries a pair of scanned wall lanterns either side of
	-- the arch, and these stood inside the new buttresses.
	-- clear of both the court lamp posts at (+-30, 132) and the planter
	-- boxes at (+-44, 138)
	-- out by the bike racks at +-186, off the ceremonial approach entirely
	prop("Bin", CFrame.new(-176, 0, 132))
	prop("Bin", CFrame.new(176, 0, 132))

	-- ---------------- second dressing pass ----------------
	-- the pieces that turn a furnished room into an inhabited one
	prop("GreenChair", CFrame.new(-56, 0, 96) * CFrame.Angles(0, math.rad(90), 0))
	-- Both of these hung at x = -44 and x = 38, which is INSIDE the west lobby
	-- flight and three studs off the east one, at chest height over the
	-- seventh tread. This is the "the stairs are blocked by something" bug:
	-- you climbed six steps and walked into a picture frame. They are on the
	-- side walls now, where a picture goes.
	prop("FramedPicture", CFrame.new(-60.5, 9, 96) * CFrame.Angles(0, math.rad(90), 0))
	prop("FramedPicture", CFrame.new(60.5, 9, 96) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Table2", CFrame.new(-320, 0, -284))
	prop("Chair", CFrame.new(-320, 0, -288) * CFrame.Angles(0, math.pi, 0))
	prop("Fern", CFrame.new(-355, 0, -277))
	prop("Fern", CFrame.new(-285, 0, -277))
	for _, x in { -335, -305 } do
		prop("CeilingLamp", CFrame.new(x, 24.5, -300), { hang = true })
	end
	for _, z in { 36, 50 } do
		prop("HangingLamp", CFrame.new(-204, 13, z), { hang = true })
	end
	-- stacking chairs along the gym wall, left out after an assembly
	for i = 0, 3 do
		prop("MonoblocChair", CFrame.new(-44, 0, -76 + i * 9) * CFrame.Angles(0, math.rad(90 + i * 7), 0))
	end

	-- ---------------- scattered clutter ----------------
	local MAINTENANCE = {
		"WoodenCrate", "WoodenCrate2", "Barrel", "Barrel2", "Barrel3", "WineBarrel",
		"WoodenBucket", "WoodenBucket2", "PlasticCrate", "PlasticContainer",
		"IndustrialPasticContainer", "MetalToolbox", "MetalToolChest", "HandTruck",
		"WoodenLadder", "WoodenLadder2", "WornMetalRack", "UtilityBox", "UtilityBox2",
		"Trashbag", "OldTyre", "CompostBag", "WoodenBroom", "SteelFrameShelves",
	}
	local SPORTS = {
		"MetalStool", "MetalStool2", "MetalStool3", "FoldingWoodenStool", "WoodenStool",
		"MonoblocChair", "Bin", "Lifebuoy", "OldTyre", "WoodenCrate", "PlasticCrate",
	}
	local KITCHEN = {
		"BrassPot", "BrassPot2", "BrassPan", "PotEnamel", "MetalJug", "Jug",
		"VintageMicrowave", "VintageElectricKettle", "PlasticThermos", "WoodenBowl",
		"WoodenCuttingBoard", "LongLifeFood", "RussianFoodCans", "PlasticBottleGallon",
		"HamburgerBuns", "CarrotCake", "BrassGoblets",
	}
	local CLASSROOM_CLUTTER = {
		"WoodenCrate2", "PlasticCrate", "MetalStool", "FoldingWoodenStool", "Bin",
		"SteelShelves2", "WoodenDisplayShelves", "PottedPlant", "CeramicPot",
		"MedicalBox", "PlasticContainer", "SmallWoodenTable",
	}
	local GARDEN = {
		"PlanterBox", "PlanterBox2", "PlanterBox3", "PlanterPot", "CeramicPot",
		"Shrub", "Flowers", "SeedingTray", "WateringCanMetal", "GardenSprinkler",
		"GardenGloves", "CompostBag", "WoodenBucket", "Fern",
	}
	local TERRACE = {
		"PicnicTable", "OutdoorTableChairSet", "RoundWoodenTable", "RoundWoodenTable2",
		"MonoblocChair", "Bench", "Stool", "PlanterBox2", "Shrub", "Bin",
	}

	for _, zone in {
		-- the gym keeps its equipment down the flanks
		{ min = Vector2.new(-48, -118), max = Vector2.new(-42, -70), y = 0, pool = MAINTENANCE, count = 12, seed = 3101 },
		{ min = Vector2.new(42, -118), max = Vector2.new(48, -70), y = 0, pool = SPORTS, count = 10, seed = 3102 },
		-- the servery end of the cafeteria
		{ min = Vector2.new(-221, 49), max = Vector2.new(-208, 58), y = 0, pool = KITCHEN, count = 10, seed = 3103 },
		-- the back of the two homerooms flanking each wing corridor
		{ min = Vector2.new(-150, -112), max = Vector2.new(-140, -100), y = 0, pool = CLASSROOM_CLUTTER, count = 6, seed = 3104 },
		{ min = Vector2.new(140, -112), max = Vector2.new(150, -100), y = 0, pool = CLASSROOM_CLUTTER, count = 6, seed = 3105 },
		-- the courtyard edges, left and right of the way through
		{ min = Vector2.new(-40, 34), max = Vector2.new(-30, 66), y = 0, pool = GARDEN, count = 8, seed = 3106 },
		{ min = Vector2.new(30, 34), max = Vector2.new(40, 66), y = 0, pool = GARDEN, count = 8, seed = 3107 },
		-- the lawn OUTSIDE the two courts, which is where the front approach's
		-- seating went when the courts came out of the quadrangles
		{ min = Vector2.new(-196, 150), max = Vector2.new(-156, 182), y = 0, pool = TERRACE, count = 7, seed = 3108 },
		{ min = Vector2.new(156, 150), max = Vector2.new(196, 182), y = 0, pool = TERRACE, count = 7, seed = 3109 },
		-- the dorm yards
		{ min = Vector2.new(-198, -234), max = Vector2.new(-180, -214), y = 0, pool = GARDEN, count = 6, seed = 3110 },
		{ min = Vector2.new(180, -234), max = Vector2.new(198, -214), y = 0, pool = GARDEN, count = 6, seed = 3111 },
	} do
		scatter(zone)
	end
end

-- furnishClassroom and furnishCafeteria used to live here. Neither was ever
-- called: one furnished a classroom at z = -150, which is a field north of the
-- gym, and the other a cafeteria that buildCafeteriaTables already builds. The
-- rooms that exist are furnished in furnishSubjectRooms.

local function detailGym(parent: Instance)
	local c = Vector3.new(215, 0, 60)
	-- red/white pennant stripe around the top of the walls
	for i = 0, 15 do
		part({ Name = "GymStripe", Size = Vector3.new(4.2, 2.2, 0.4), CFrame = CFrame.new(c.X - 32 + i * 4.3, 12.5, c.Z - 33.6), Color = i % 2 == 0 and Color3.fromRGB(196, 44, 44) or Color3.fromRGB(240, 240, 240), Parent = parent })
	end
	-- high window band
	part({ Name = "GymWindowBand", Size = Vector3.new(50, 3.2, 0.5), CFrame = CFrame.new(c.X, 10, c.Z + 33.6), Color = Color3.fromRGB(200, 224, 240), Material = Enum.Material.Glass, Transparency = 0.4, Parent = parent })
	-- cool-white sport lighting overhead
	for _, off in { -20, 0, 20 } do
		local strip = part({ Name = "GymLightStrip", Size = Vector3.new(40, 0.4, 1.2), CFrame = CFrame.new(c.X, 13.2, c.Z + off), Color = Color3.fromRGB(235, 245, 255), Material = Enum.Material.Neon, Parent = parent })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(225, 240, 255)
		light.Brightness = 1.3
		light.Range = 34
		light.Parent = strip
	end

	-- basketball hoop on the gym wall
	part({ Name = "GymBoard", Size = Vector3.new(6, 4, 0.4), CFrame = CFrame.new(c.X, 9.6, c.Z - 32.8), Color = Color3.fromRGB(240, 240, 240), Parent = parent })
	part({ Name = "GymRim", Size = Vector3.new(1.6, 0.3, 1.6), CFrame = CFrame.new(c.X, 8.2, c.Z - 31.6), Color = Color3.fromRGB(226, 100, 60), Material = Enum.Material.Neon, Parent = parent })
end


-- Three-storey exterior facade: brick piers, tall framed windows per floor,
-- white trim banding between floors, dentil cornice at the top. This is what
-- makes the school read as a civic academy instead of a strip mall.
local FACADE_H = 38
local function buildFacadeWall(parent: Instance, from: Vector3, to: Vector3, gaps: { { at: number, width: number } })
	local BRICK = Color3.fromRGB(138, 128, 114)
	local TRIM = Color3.fromRGB(238, 236, 228)
	local dir = (to - from)
	local length = dir.Magnitude
	local unit = dir.Unit
	local perp = Vector3.new(-unit.Z, 0, unit.X)
	local cuts = { 0, length }
	for _, gap in gaps do
		table.insert(cuts, math.clamp(gap.at - gap.width / 2, 0, length))
		table.insert(cuts, math.clamp(gap.at + gap.width / 2, 0, length))
	end
	table.sort(cuts)
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		local isGap = false
		for _, gap in gaps do
			local mid = (a + b) / 2
			if mid > gap.at - gap.width / 2 and mid < gap.at + gap.width / 2 then
				isGap = true
				break
			end
		end
		local segLen = b - a
		if isGap or segLen < 1 then
			continue
		end
		local mid = from + unit * ((a + b) / 2)
		local cf = CFrame.lookAt(mid, mid + perp)
		local function slab(name: string, w: number, h: number, d: number, y: number, color: Color3, mat: Enum.Material, texTag: string?)
			local p = part({ Name = name, Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, y, 0) , Color = color, Material = mat, Parent = parent })
			if texTag then
				tag(p, texTag)
			end
			return p
		end
		-- base course
		slab("FacadeBase", segLen, 3.2, 2.6, 1.6, Color3.fromRGB(198, 194, 184), Enum.Material.Concrete, "TexBlueStone")
		-- three storeys of solid brick with punched, white-framed windows
		for floor = 0, 2 do
			local y0 = 3.2 + floor * 11.6
			-- the wall itself is brick, full height of the storey
			slab("FacadeBrick", segLen, 11.6, 2.2, y0 + 5.8, BRICK, Enum.Material.Brick, "TexCoursedStone")
			-- punched windows: one per bay, brick left between them
			local bays = math.max(1, math.round(segLen / 16))
			local pitch = segLen / bays
			local winW = math.min(7.5, pitch * 0.5)
			for m = 0, bays - 1 do
				local wx = -segLen / 2 + (m + 0.5) * pitch
				-- A window is LAYERS, each one proud of the last. The frame,
				-- the pane and both muntins used to be concentric boxes on the
				-- same centre -- 2.6, 2.9 and 3.0 deep through a 2.2 brick wall
				-- -- so every window on every storey of the school was four
				-- solids fighting for the same pixels, and the frame, being
				-- the shallowest, was inside the glass and invisible. That is
				-- most of what "messy everywhere" looked like from inside.
				--
				-- Brick 2.2, glass 2.4, frame bars 3.0, muntins 3.2, sill and
				-- shutters 3.4: nothing shares a face with anything.
				-- Set down to 5.6 in the storey, not 6.2. At 6.2 the window's
				-- head, its keystone and the string course between storeys all
				-- wanted the same three studs of an eleven-and-a-half stud
				-- floor, and all three got them.
				local pane = part({ Name = "FacadeWindow", Size = Vector3.new(winW, 6.6, 2.4), CFrame = cf * CFrame.new(wx, y0 + 5.6, 0) , Color = Color3.fromRGB(96, 138, 170), Material = Enum.Material.SmoothPlastic, Reflectance = 0.3, Parent = parent })
				tag(pane, "TexWindow")
				-- the frame, as four bars round the opening
				local jamb = 1.0
				for _, bar in {
					{ winW + 2.0, jamb, 0, 3.8 }, { winW + 2.0, jamb, 0, -3.8 },
					{ jamb, 8.4, -(winW / 2 + 0.5), 0 }, { jamb, 8.4, winW / 2 + 0.5, 0 },
				} do
					part({ Name = "FacadeWinFrame", Size = Vector3.new(bar[1], bar[2], 3.0), CFrame = cf * CFrame.new(wx + bar[3], y0 + 5.6 + bar[4], 0), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
				end
				-- muntin cross
				part({ Name = "Muntin", Size = Vector3.new(0.45, 6.6, 3.2), CFrame = cf * CFrame.new(wx, y0 + 5.6, 0) , Color = TRIM, Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
				part({ Name = "Muntin", Size = Vector3.new(winW, 0.45, 3.2), CFrame = cf * CFrame.new(wx, y0 + 5.6, 0) , Color = TRIM, Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
				-- sill under each window
				part({ Name = "FacadeSill", Size = Vector3.new(winW + 2.6, 0.6, 3.4), CFrame = cf * CFrame.new(wx, y0 + 0.95, 0) , Color = TRIM, Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
				-- Ashlar jambs and a hood mould, not green timber shutters.
				-- Shutters read colonial cottage; the reference school is
				-- collegiate gothic, where a window is a hole cut in stone with
				-- dressed stone round it. Same pieces in the same places -- a
				-- vertical either side, a horizontal over the top -- but they
				-- are stone, and the hood steps out over the head with a
				-- keystone at its middle, which is what makes the wall read as
				-- masonry rather than as a painted rectangle.
				local ASHLAR = Color3.fromRGB(201, 191, 169)
				for _, sh in { -1, 1 } do
					tag(part({ Name = "WindowJamb", Size = Vector3.new(2.4, 9.4, 3.4), CFrame = cf * CFrame.new(wx + sh * (winW / 2 + 1.2), y0 + 5.6, 0), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
				end
				tag(part({ Name = "WindowHood", Size = Vector3.new(winW + 6.2, 1.3, 3.8), CFrame = cf * CFrame.new(wx, y0 + 10.6, 0), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
				part({ Name = "Keystone", Size = Vector3.new(2.2, 2.4, 4.0), CFrame = cf * CFrame.new(wx, y0 + 10.4, 0), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
				for _, sh in { -1, 1 } do
					part({ Name = "HoodStop", Size = Vector3.new(1.4, 1.9, 3.9), CFrame = cf * CFrame.new(wx + sh * (winW / 2 + 2.8), y0 + 9.9, 0), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
				end
			end
			-- slim string course between storeys only
			if floor < 2 then
				slab("FacadeStringCourse", segLen + 0.4, 0.9, 2.5, y0 + 11.4, TRIM, Enum.Material.Concrete)
			end
		end
		-- cornice + dentils
		slab("FacadeCornice", segLen + 0.6, 1.8, 3.2, FACADE_H - 0.6, TRIM, Enum.Material.Concrete)
		local dentils = math.floor(segLen / 4)
		for dI = 0, dentils do
			part({ Name = "Dentil", Size = Vector3.new(1.6, 1.0, 2.9), CFrame = cf * CFrame.new(-segLen / 2 + dI * 4, FACADE_H - 2.2, 0) , Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		end
	end
	for _, gap in gaps do
		local mid = from + unit * gap.at
		local cf = CFrame.lookAt(mid, mid + perp)
		for _, side in { -1, 1 } do
			part({ Name = "FacadeDoorPost", Size = Vector3.new(2.4, 15, 3.0), CFrame = cf * CFrame.new(side * (gap.width / 2 + 1.2), 7.5, 0) , Color = Color3.fromRGB(238, 236, 228), Material = Enum.Material.Concrete, Parent = parent })
		end
		part({ Name = "FacadeDoorLintel", Size = Vector3.new(gap.width + 5, 2.4, 3.0), CFrame = cf * CFrame.new(0, 16.2, 0) , Color = Color3.fromRGB(238, 236, 228), Material = Enum.Material.Concrete, Parent = parent })
		tag(part({ Name = "FacadeGapBrick", Size = Vector3.new(gap.width + 5, 20, 2.2), CFrame = cf * CFrame.new(0, 27.4, 0) , Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
	end
end

-- ============================ GRAND FACADE ============================
-- The reference is a civic brick academy: pitched slate roofs with dormers,
-- a central clock tower over a columned portico, corner towers with
-- crenellations, white trim banding every floor, and hedges hugging the base.
-- ONE lamp post, used everywhere.
--
-- The asset audit counted forty lamps on this campus and every one of them was
-- between two and four boxes: a cylinder with a cube on top and a slab for a
-- cap. Forty chances to notice, on the object the reference images repeat more
-- than any other -- down every path, round the court, along the fence. This is
-- Poly Haven's CC0 street_lamp_01, a scan, so all forty are now the same real
-- object at the same real scale. The glow and the light hang on a small neon
-- lens at the head, because a mesh cannot carry a PointLight on its own until
-- PropService has instanced it.
local LAMP_GLOW = Color3.fromRGB(255, 220, 160)

local function lampPost(parent: Instance, x: number, z: number, opts: { short: boolean?, range: number?, brightness: number? }?)
	local o = opts or {}
	local short = o.short == true
	prop(if short then "StreetLampShort" else "StreetLamp", CFrame.new(x, 0, z))
	local head = part({
		Name = "LampGlow",
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = CFrame.new(x, if short then 18.2 else 24.0, z),
		Color = LAMP_GLOW,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		Parent = parent,
	})
	head.CanCollide = false
	head.CastShadow = false
	local light = Instance.new("PointLight")
	light.Brightness = o.brightness or 1.3
	light.Range = o.range or 38
	light.Color = LAMP_GLOW
	light.Shadows = false
	light.Parent = head
end

local function buildGrandFacade(parent: Instance)
	local BRICK = Color3.fromRGB(138, 128, 114)
	local TRIM = Color3.fromRGB(238, 236, 228)
	local SLATE = Color3.fromRGB(90, 100, 114)
	local Z = 124 -- south facade line

	local function trimBand(x: number, y: number, z: number, w: number, d: number, h: number?)
		part({ Name = "FacadeTrim", Size = Vector3.new(w, h or 1.4, d), CFrame = CFrame.new(x, y, z), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end

	-- ---- pitched roofs over the room rows (wedge pairs) ----
	-- eaves: which of the two ends gets a board. Where two blocks abut -- the
	-- outer column meeting the north range at z = -64 -- both were laying a
	-- 168 x 2.4 board in exactly the same plane, so the joint flickered along
	-- its whole length. The board belongs to the block whose roof is visible
	-- there, which is the one that does not stop at the joint.
	local function pitchedRoof(cx: number, cz: number, w: number, d: number, h: number, baseY: number, eaves: { boolean }?)
		for _, side in { -1, 1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "PitchRoof"
			wedge.Anchored = true
			wedge.Size = Vector3.new(w, h, d / 2)
			wedge.CFrame = CFrame.new(cx, baseY + h / 2, cz + side * d / 4)
				* CFrame.Angles(0, side > 0 and 0 or math.rad(180), 0)
			wedge.Color = SLATE
			wedge.Material = Enum.Material.Slate
			wedge.Parent = parent
			tag(wedge, "TexSlateRoof")
		end
		-- eaves overhang + carved brackets underneath
		local north = if eaves then eaves[1] else true
		local south = if eaves then eaves[2] else true
		if north then
			trimBand(cx, baseY - 0.3, cz + d / 2, w + 4, 2.4, 1.2)
		end
		if south then
			trimBand(cx, baseY - 0.3, cz - d / 2, w + 4, 2.4, 1.2)
		end
		local brackets = math.floor(w / 14)
		local edges = {}
		if north then
			table.insert(edges, cz + d / 2)
		end
		if south then
			table.insert(edges, cz - d / 2)
		end
		for bI = 0, brackets do
			local bx = cx - w / 2 + bI * (w / math.max(brackets, 1))
			for _, bz in edges do
				part({ Name = "EaveBracket", Size = Vector3.new(1.4, 2.6, 3.2), CFrame = CFrame.new(bx, baseY - 2.0, bz), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
			end
		end
	end

	pitchedRoof(-142, 100, 164, 48, 14, 38.0)
	pitchedRoof(142, 100, 164, 48, 14, 38.0)
	-- Dormers on the front slope. Every roof in the reference art is broken by
	-- them, and a bare slate plane 164 studs long is the single largest blank
	-- surface on the building. They sit on the front pitch, which runs from the
	-- ridge at z = 100 down to the eaves at z = 124, so the roof surface at a
	-- given z is baseY + rise * (1 - (z - ridge) / (d / 2)); at z = 112 that is
	-- 38 + 14 * 0.5 = 45, and the dormer stands on it.
	-- Set LOW on the slope. At z 112 and eight studs tall the dormers finished
	-- above the ridge, so from a player's eye on the court there was sky behind
	-- each one and five of them read as lanterns floating over the roof. The
	-- pitch runs from the ridge at z 100, y 52 down to the eaves at z 124,
	-- y 38, so the surface at z 116 is y 42.7 and a six-stud dormer with its
	-- own little roof tops out just under the ridge, which is where a dormer
	-- belongs.
	for _, wing in { -142, 142 } do
		for i = -2, 2 do
			Kit.dormer(kitFor(parent), {
				x = wing + i * 32,
				y = 42.3,
				z = 116,
				facing = 0,
				width = 7,
				height = 6,
			})
		end
	end
	-- The old `dormers` helper is gone from the front slope: CollegiateKit
	-- already put five on each wing above, and these landed at the same x, four
	-- studs lower and seven studs further back, so every dormer on the school
	-- was two dormers inside each other with the older one's roof wedge poking
	-- out sideways like a blade. Two builders, one patch of roof, neither aware
	-- of the other -- the same fault as the shrubs and the planters.
	pitchedRoof(-142, -94, 164, 60, 15, 38.0)
	pitchedRoof(142, -94, 164, 60, 15, 38.0)
	-- no south eaves: these two abut the north range's roof at z = -64 and
	-- that range already boards the joint
	pitchedRoof(-198, 0, 52, 128, 12, 38.0, { true, false })
	pitchedRoof(198, 0, 52, 128, 12, 38.0, { true, false })
	-- gym: taller, its own ridge
	pitchedRoof(0, -105, 104, 86, 18, 38.0)

	-- ---- central block: portico, clock tower, grand steps ----
	-- projecting entrance bay (the white stone block in the reference)
	-- the bay is a frame, not a plug: piers each side, header above, so the
	-- doors underneath actually open into the lobby
	for _, side in { -1, 1 } do
		part({ Name = "EntryBayPier", Size = Vector3.new(15, 46, 14), CFrame = CFrame.new(side * 20.5, 23, Z + 5), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	part({ Name = "EntryBayHeader", Size = Vector3.new(56, 26, 14), CFrame = CFrame.new(0, 33, Z + 5), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	-- arched transom over the doors
	part({ Name = "EntryTransom", Size = Vector3.new(24, 4.6, 1.2), CFrame = CFrame.new(0, 17.4, Z - 1.6), Color = Color3.fromRGB(150, 196, 222), Material = Enum.Material.Glass, Transparency = 0.25, Parent = parent })
	part({ Name = "EntryTransomBar", Size = Vector3.new(0.5, 4.6, 1.5), CFrame = CFrame.new(0, 17.4, Z - 1.7), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	-- double doors, swung open
	for _, side in { -1, 1 } do
		part({
			Name = "MainDoor",
			Size = Vector3.new(11, 14, 0.9),
			CFrame = CFrame.new(side * 11.5, 7.6, Z - 2.2) * CFrame.Angles(0, side * math.rad(72), 0),
			Color = Color3.fromRGB(96, 60, 40),
			Material = Enum.Material.WoodPlanks,
			Parent = parent,
		})
		part({
			Name = "MainDoorGlass",
			Size = Vector3.new(6.4, 7, 1.1),
			CFrame = CFrame.new(side * 11.5, 10.2, Z - 2.2) * CFrame.Angles(0, side * math.rad(72), 0),
			Color = Color3.fromRGB(150, 196, 222),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			Parent = parent,
		})
	end
	-- door surround
	for _, side in { -1, 1 } do
		part({ Name = "EntryJambStone", Size = Vector3.new(3, 16, 6), CFrame = CFrame.new(side * 13.5, 8, Z + 1), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	part({ Name = "EntryLintelStone", Size = Vector3.new(30, 2.4, 6), CFrame = CFrame.new(0, 16.8, Z + 1), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	-- Articulation on the bay face. It was a 56 x 46 slab of blank concrete,
	-- which is the first thing anyone sees when they arrive. Real civic
	-- frontages break that mass up: pilasters carry the eye up, string courses
	-- carry it across, and tall windows give the storey above the doors
	-- something to be.
	local bayFace = Z + 12.2
	-- outboard of the portico columns at +/-11, not on top of them
	for _, px in { -25, -38, 25, 38 } do
		part({ Name = "EntryPilaster", Size = Vector3.new(4.4, 40, 1.6), CFrame = CFrame.new(px, 21, bayFace), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		-- a capital block so the pilaster lands somewhere
		part({ Name = "EntryPilasterCap", Size = Vector3.new(5.6, 1.8, 2.2), CFrame = CFrame.new(px, 41.6, bayFace), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "EntryPilasterBase", Size = Vector3.new(5.6, 2.2, 2.2), CFrame = CFrame.new(px, 2.1, bayFace), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	-- Brick to the first string course, stone above. The bay was one uniform
	-- slab of trim concrete from the pavement to the pediment, which reads as
	-- a blank wall however much moulding is stuck to it. Civic buildings put a
	-- heavier material at the bottom and it is what gives the front a base.
	for _, side in { -1, 1 } do
		tag(part({ Name = "EntryBayBrick", Size = Vector3.new(15.4, 19, 1.4), CFrame = CFrame.new(side * 20.5, 9.5, bayFace - 0.1), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
	end
	-- In two lengths, with the doorway left open between them. This was one
	-- 58-stud block laid straight across the front of the entrance bay -- a
	-- 2.4-stud kerb across the doors themselves, which is a step you cannot
	-- take (a Humanoid manages 2.2) and the reason the whole school read as
	-- walled in from outside.
	for _, side in { -1, 1 } do
		part({ Name = "EntryBayPlinth", Size = Vector3.new(14.5, 2.4, 2.6), CFrame = CFrame.new(side * 21.75, 1.2, bayFace - 0.2), Color = Color3.fromRGB(198, 194, 184), Material = Enum.Material.Concrete, Parent = parent })
	end

	-- string courses at the floor lines
	for _, band in { { y = 19.6, h = 1.6 }, { y = 43.4, h = 2.0 } } do
		part({ Name = "EntryStringCourse", Size = Vector3.new(58, band.h, 2.4), CFrame = CFrame.new(0, band.y, bayFace - 0.2), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	-- three tall windows in the storey over the doors
	-- two windows flanking the name sign, which owns the centre of the bay
	for _, wx in { -17.5, 17.5 } do
		local pane = part({ Name = "EntryBayWindow", Size = Vector3.new(9, 17, 1), CFrame = CFrame.new(wx, 30.5, bayFace - 0.4), Color = Color3.fromRGB(150, 196, 222), Material = Enum.Material.Glass, Transparency = 0.2, Parent = parent })
		tag(pane, "TexWindow")
		-- A FRAME, not a slab. This was an eleven-by-nineteen sheet of concrete
		-- standing in front of the glass and set flush into the bay's face, so
		-- the two windows over the front door were a solid wall you could not
		-- see and the pane behind them was never visible from anywhere.
		local bars: { { w: number, h: number, dx: number, dy: number } } = {
			{ w = 11, h = 1.6, dx = 0, dy = 9.3 }, { w = 11, h = 1.6, dx = 0, dy = -9.3 },
			{ w = 1.4, h = 19, dx = -4.8, dy = 0 }, { w = 1.4, h = 19, dx = 4.8, dy = 0 },
		}
		for _, bar in bars do
			part({
				Name = "EntryWinSurround",
				Size = Vector3.new(bar.w, bar.h, 1.4),
				CFrame = CFrame.new(wx + bar.dx, 30.5 + bar.dy, bayFace + 0.3),
				Color = TRIM, Material = Enum.Material.Concrete, Parent = parent,
			}).CanCollide = false
		end
		-- a bar across the middle, which is what makes a window read as glazed
		part({ Name = "EntryWinBar", Size = Vector3.new(9.4, 0.9, 1.2), CFrame = CFrame.new(wx, 30.5, bayFace + 0.2), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
		part({ Name = "EntryWinKeystone", Size = Vector3.new(2.2, 3, 2), CFrame = CFrame.new(wx, 40.6, bayFace + 0.1), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	-- cheek walls flanking the steps, so the approach is funnelled
	for _, side in { -1, 1 } do
		part({ Name = "EntryCheek", Size = Vector3.new(3, 5.5, 16), CFrame = CFrame.new(side * 21, 2.6, Z + 22), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "EntryCheekCap", Size = Vector3.new(4, 1, 17), CFrame = CFrame.new(side * 21, 5.7, Z + 22), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "EntryUrn", Shape = Enum.PartType.Ball, Size = Vector3.new(4.4, 4.4, 4.4), CFrame = CFrame.new(side * 21, 8, Z + 14.5), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end

	trimBand(0, 46.4, Z + 5, 60, 16, 2.2)

	-- ---- the entrance, in the right century ----
	-- What stood here was four round columns under a flat roof with a
	-- triangular pediment on it: Greek Revival, from a different building and a
	-- different two thousand years. The reference entrance is a projecting
	-- gabled bay with a pointed stone arch over timber doors, buttresses either
	-- side, lanterns on the wall and a name board over the head.
	--
	-- Every number below is measured off what is already standing rather than
	-- guessed from the facade line, because the first attempt at this put the
	-- arch at z = 121 -- INSIDE the bay, behind fourteen studs of solid header,
	-- where nobody would ever see it. The bay runs z 122 to 136; its front face
	-- is 136. The opening between the piers is x +-13 with its head at y = 20.
	local kit = kitFor(parent)
	local FACE = 136.0
	local OPENING = 26.0

	Kit.pointedArch(kit, { x = 0, y = 19.4, z = FACE - 1.2, span = OPENING, rise = 19, depth = 3.8, ring = 2.8, segments = 10 })
	-- The head of the arch is a WINDOW, not a wall.
	--
	-- From a player's eye on the court the arch read as a thin outline drawn
	-- over a flat brown panel, and the two little round lights in it did not
	-- register at all. In the reference the great arch over the doors is filled
	-- with one tall traceried window, lit from inside, and that window is the
	-- brightest thing on the whole elevation -- it is what makes the entrance
	-- read as the entrance from the far end of the grounds.
	--
	-- Below the springing the opening stays clear: the doors are recessed at
	-- z 116..127 and people walk through here.
	local HEAD_LOW, HEAD_TOP = 20.6, 37.0
	local headMid = (HEAD_LOW + HEAD_TOP) / 2
	local headHeight = HEAD_TOP - HEAD_LOW
	tag(part({ Name = "ArchReveal", Size = Vector3.new(OPENING - 1.0, headHeight + 2.4, 2.2), CFrame = CFrame.new(0, headMid, FACE - 1.6), Color = Color3.fromRGB(111, 103, 92), Material = Enum.Material.Slate, Parent = parent }), "TexCoursedStone").CanCollide = false
	local light = part({ Name = "ArchWindow", Size = Vector3.new(OPENING - 4.2, headHeight, 0.6), CFrame = CFrame.new(0, headMid, FACE - 0.5), Color = Color3.fromRGB(255, 196, 107), Material = Enum.Material.Neon, Transparency = 0.3, Parent = parent })
	light.CanCollide = false
	light.CastShadow = false
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 220, 160)
	glow.Brightness = 1.4
	glow.Range = 40
	glow.Shadows = false
	glow.Parent = light

	-- tracery: two mullions, a transom, and a quatrefoil in the head. This is
	-- the difference between a lit window and a lit rectangle.
	for _, mx in { -7.2, 0, 7.2 } do
		tag(part({ Name = "ArchMullion", Size = Vector3.new(1.1, headHeight + 0.4, 1.3), CFrame = CFrame.new(mx, headMid, FACE - 0.2), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
	end
	tag(part({ Name = "ArchTransom", Size = Vector3.new(OPENING - 4.0, 1.1, 1.3), CFrame = CFrame.new(0, HEAD_LOW + headHeight * 0.58, FACE - 0.2), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
	local lie = CFrame.Angles(0, math.rad(90), math.rad(90))
	tag(part({ Name = "ArchQuatrefoil", Size = Vector3.new(1.3, 6.2, 6.2), CFrame = CFrame.new(0, HEAD_TOP - 3.6, FACE - 0.1) * lie, Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Shape = Enum.PartType.Cylinder, Parent = parent }), "TexAshlar").CanCollide = false
	local eye = part({ Name = "ArchQuatrefoilGlass", Size = Vector3.new(0.7, 4.8, 4.8), CFrame = CFrame.new(0, HEAD_TOP - 3.6, FACE + 0.3) * lie, Color = Color3.fromRGB(255, 214, 150), Material = Enum.Material.Neon, Transparency = 0.25, Shape = Enum.PartType.Cylinder, Parent = parent })
	eye.CanCollide = false
	eye.CastShadow = false

	-- the jambs of the walk-through below, so the opening reads as cut through
	-- thick stone rather than as a hole in a panel
	for _, side in { -1, 1 } do
		tag(part({ Name = "PortalJamb", Size = Vector3.new(2.6, HEAD_LOW, 3.2), CFrame = CFrame.new(side * (OPENING / 2 - 1.3), HEAD_LOW / 2, FACE - 1.2), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
	end
	tag(part({ Name = "PortalThreshold", Size = Vector3.new(OPENING + 3.0, 1.2, 5.0), CFrame = CFrame.new(0, 0.5, FACE - 1.5), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false

	-- buttresses at the bay's own corners, standing on the bay, not in front of
	-- it: the bay is x -28..28 and z 122..136, so they centre at x +-31, z 129
	for _, side in { -1, 1 } do
		Kit.buttress(kit, { x = side * 31, z = 129, base = 0, height = 42, width = 8, depth = 9, stages = 3 })
		Kit.pinnacle(kit, { x = side * 31, z = 129, base = 45.4, height = 14 })
	end

	-- a steep gable over the bay instead of a classical pediment. The header
	-- tops out at 46, so the eaves sit just above it and the ridge runs across
	-- the bay's depth.
	Kit.gableRoof(kit, { x = 0, z = 129, width = 62, depth = 18, eaves = 47.0, rise = 19 })
	tag(part({ Name = "BayGableWall", Size = Vector3.new(60, 17, 1.6), CFrame = CFrame.new(0, 55.5, FACE + 0.4), Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Slate, Parent = parent }), "TexCoursedStone").CanCollide = false

	-- the name board on the face, between the arch head and the eaves
	local board = part({ Name = "AcademyNameBoard", Size = Vector3.new(34, 6.0, 0.9), CFrame = CFrame.new(0, 42.0, FACE + 0.5), Color = Color3.fromRGB(22, 35, 63), Material = Enum.Material.SmoothPlastic, Parent = parent })
	-- Back, not Front: NormalId.Front is the -Z face, and this board sits on
	-- the +Z side of the building, so Front would read straight into the
	-- header behind it.
	signText(board, "DETENTION ACADEMY", Color3.fromRGB(217, 180, 92), Enum.NormalId.Back)
	tag(part({ Name = "NameBoardFrame", Size = Vector3.new(35.8, 7.6, 0.5), CFrame = CFrame.new(0, 42.0, FACE + 0.1), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false

	-- wall lanterns either side of the doors -- a scanned one, not a glowing box
	for _, side in { -1, 1 } do
		prop("WallLantern", CFrame.new(side * 17.5, 13.5, FACE + 1.9))
		local glow = part({ Name = "PorchGlow", Size = Vector3.new(1.1, 1.1, 1.1), CFrame = CFrame.new(side * 17.5, 13.5, FACE + 1.9), Color = Color3.fromRGB(255, 220, 160), Material = Enum.Material.Neon, Transparency = 0.4, Parent = parent })
		glow.CanCollide = false
		glow.CastShadow = false
		local lamp = Instance.new("PointLight")
		lamp.Color = Color3.fromRGB(255, 220, 160)
		lamp.Brightness = 1.1
		lamp.Range = 26
		lamp.Shadows = false
		lamp.Parent = glow
	end

	-- The entrance terrace.
	--
	-- What was here was a flight of five steps climbing 4.6 studs TOWARDS the
	-- doors -- and the lobby floor behind those doors is at 0.28, with the
	-- court paving outside at 0.4. So the approach rose nearly five studs and
	-- then fell off a cliff back to the threshold. Nobody drew it; it was five
	-- lines of a loop that looked like steps.
	--
	-- The school stands on level ground, so its entrance is a terrace, not a
	-- flight: one broad paved platform on the door line, a moulded kerb round
	-- its edge, and a single shallow riser down onto the court. The grandeur is
	-- the bay, the arch, the cheek walls, the urns and the lanterns -- all of
	-- which are already standing.
	local TERRACE_TOP = 0.9
	-- from the door line out into the court: z 123 .. 151
	local terraceMid, terraceDepth = Z + 13, 28
	part({ Name = "EntranceTerrace", Size = Vector3.new(64, TERRACE_TOP + 0.6, terraceDepth), CFrame = CFrame.new(0, (TERRACE_TOP - 0.6) / 2, terraceMid), Color = Color3.fromRGB(206, 202, 192), Material = Enum.Material.Concrete, Parent = parent })
	-- The kerb is a FRAME round the terrace, standing a little proud of it --
	-- not a 66 x 42 slab laid at exactly the terrace's own top, which is 2,560
	-- square studs of two surfaces in one plane.
	for _, run in {
		{ w = 66, d = 1.6, dx = 0, dz = -(terraceDepth / 2 + 0.2) },
		{ w = 66, d = 1.6, dx = 0, dz = terraceDepth / 2 + 0.2 },
		{ w = 1.6, d = terraceDepth + 2, dx = -32.7, dz = 0 },
		{ w = 1.6, d = terraceDepth + 2, dx = 32.7, dz = 0 },
	} do
		tag(part({ Name = "TerraceKerb", Size = Vector3.new(run.w, 0.9, run.d), CFrame = CFrame.new(run.dx, TERRACE_TOP - 0.15, terraceMid + run.dz), Color = Color3.fromRGB(224, 218, 204), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
	end
	-- one riser down onto the court, half the terrace's height, so the step
	-- off the paving is 0.25 and then 0.25 again
	part({ Name = "TerraceRiser", Size = Vector3.new(58, 0.55, 4), CFrame = CFrame.new(0, 0.475, terraceMid + terraceDepth / 2 + 2), Color = Color3.fromRGB(214, 210, 200), Material = Enum.Material.Concrete, Parent = parent })
	-- the joints, so 64 x 40 studs of terrace reads as laid stone
	for i = -5, 5 do
		part({ Name = "TerraceJoint", Size = Vector3.new(64, 0.1, 0.4), CFrame = CFrame.new(0, TERRACE_TOP + 0.02, terraceMid + i * 3.4), Color = Color3.fromRGB(186, 182, 172), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
	end

	-- clock tower rising behind the portico
	local towerZ = Z - 6
	tag(part({ Name = "ClockTower", Size = Vector3.new(24, 54, 24), CFrame = CFrame.new(0, 44, towerZ), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
	-- The shaft was 54 studs of blank stone -- the largest unbroken surface in
	-- the whole school, standing where the eye goes first. A tower is
	-- articulated: pilasters up the corners, string courses dividing it into
	-- stages, and a tall lit lancet on each face of each stage.
	for _, corner in { Vector3.new(-11, 0, -11), Vector3.new(11, 0, -11), Vector3.new(-11, 0, 11), Vector3.new(11, 0, 11) } do
		tag(part({ Name = "TowerPilaster", Size = Vector3.new(4.4, 54, 4.4), CFrame = CFrame.new(corner.X, 44, towerZ + corner.Z), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
	end
	for _, stage in { 31, 48, 64 } do
		tag(part({ Name = "TowerStringCourse", Size = Vector3.new(25.6, 1.2, 25.6), CFrame = CFrame.new(0, stage, towerZ), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
	end
	for _, face in {
		{ dx = 0, dz = 12.2, ax = 1 },
		{ dx = 0, dz = -12.2, ax = 1 },
		{ dx = 12.2, dz = 0, ax = 0 },
		{ dx = -12.2, dz = 0, ax = 0 },
	} do
		for _, mid in { 39.5, 56 } do
			local w = if face.ax == 1 then Vector3.new(5.6, 13, 0.9) else Vector3.new(0.9, 13, 5.6)
			local reveal = if face.ax == 1 then Vector3.new(8.0, 15.4, 0.7) else Vector3.new(0.7, 15.4, 8.0)
			tag(part({ Name = "TowerLancetSurround", Size = reveal, CFrame = CFrame.new(face.dx * 1.02, mid, towerZ + face.dz * 1.02), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
			local pane = part({ Name = "TowerLancetGlass", Size = w, CFrame = CFrame.new(face.dx * 1.06, mid, towerZ + face.dz * 1.06), Color = Color3.fromRGB(255, 196, 107), Material = Enum.Material.Neon, Transparency = 0.34, Parent = parent })
			pane.CanCollide = false
			pane.CastShadow = false
		end
	end
	trimBand(0, 71.6, towerZ, 26, 26, 2.0)
	part({ Name = "TowerClockBlock", Size = Vector3.new(25, 15, 25), CFrame = CFrame.new(0, 80, towerZ), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	trimBand(0, 88.2, towerZ, 27.5, 27.5, 2.0)
	-- A flat lid with a gold pole on it is not a spire. The reference tower
	-- ends in a steep stone one, and it is the single thing that reads against
	-- the sky from anywhere on the grounds. Four corner wedges, apexes meeting
	-- in the middle, forty studs tall over a cornice, with a pinnacle standing
	-- on each corner of the parapet.
	tag(part({ Name = "TowerCornice", Size = Vector3.new(26, 2.2, 26), CFrame = CFrame.new(0, 90.2, towerZ), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar")
	tag(part({ Name = "TowerParapet", Size = Vector3.new(24.5, 3.4, 24.5), CFrame = CFrame.new(0, 93, towerZ), Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Slate, Parent = parent }), "TexCoursedStone")
	Kit.spire(kitFor(parent), { x = 0, z = towerZ, base = 94.7, width = 22, height = 40 })
	for _, corner in { Vector3.new(-11.4, 0, -11.4), Vector3.new(11.4, 0, -11.4), Vector3.new(-11.4, 0, 11.4), Vector3.new(11.4, 0, 11.4) } do
		Kit.pinnacle(kitFor(parent), { x = corner.X, z = towerZ + corner.Z, base = 94.7, height = 15 })
	end
	for _, spec in {
		{ z = towerZ + 12.6, n = Enum.NormalId.Front },
		{ z = towerZ - 12.6, n = Enum.NormalId.Back },
	} do
		local face = part({ Name = "ClockFace", Size = Vector3.new(11, 11, 0.5), CFrame = CFrame.new(0, 80, spec.z), Color = Color3.fromRGB(244, 240, 230), Material = Enum.Material.SmoothPlastic, Parent = parent })
		local dir = spec.n == Enum.NormalId.Front and 1 or -1
		part({ Name = "ClockRing", Size = Vector3.new(12.6, 12.6, 0.3), CFrame = CFrame.new(0, 80, spec.z - dir * 0.2), Color = Color3.fromRGB(120, 90, 40), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "ClockHour", Size = Vector3.new(0.8, 3.2, 0.25), CFrame = CFrame.new(0, 81.4, spec.z + dir * 0.35), Color = Color3.fromRGB(28, 30, 34), Parent = parent })
		part({ Name = "ClockMinute", Size = Vector3.new(0.6, 4.2, 0.25), CFrame = CFrame.new(1.3, 80.8, spec.z + dir * 0.36) * CFrame.Angles(0, 0, math.rad(-58)), Color = Color3.fromRGB(28, 30, 34), Parent = parent })
		-- twelve numerals, a boss over the hands' spindle and a moulded bezel:
		-- a clock face is not a white disc with two sticks on it, and this one
		-- is eighty studs up on the campus's one landmark
		for h = 0, 11 do
			local a = h * math.pi / 6
			local long = h % 3 == 0
			part({
				Name = "ClockNumeral",
				Size = Vector3.new(if long then 0.55 else 0.35, if long then 1.5 else 0.9, 0.2),
				CFrame = CFrame.new(math.sin(a) * 4.5, 80 + math.cos(a) * 4.5, spec.z + dir * 0.32)
					* CFrame.Angles(0, 0, -a),
				Color = Color3.fromRGB(38, 40, 46),
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			}).CanCollide = false
		end
		part({ Name = "ClockBezel", Size = Vector3.new(13.4, 13.4, 0.5), CFrame = CFrame.new(0, 80, spec.z - dir * 0.55), Color = Color3.fromRGB(96, 72, 34), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		part({ Name = "ClockBoss", Size = Vector3.new(1.1, 1.1, 0.5), CFrame = CFrame.new(0, 80, spec.z + dir * 0.45), Color = Color3.fromRGB(120, 90, 40), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		local _ = face
	end

	-- school name over the entrance
	-- Proud of the entry bay's header, not flush with it. Flush, the sign's
	-- reading face was inside fourteen studs of concrete: the school's own
	-- name over its own front door, unreadable from the drive.
	local sign = part({ Name = "FacadeSign", Size = Vector3.new(40, 5, 1.2), CFrame = CFrame.new(0, 39.6, Z + 15.4), Color = Color3.fromRGB(24, 32, 58), Parent = parent })
	signText(sign, "DETENTION", Color3.fromRGB(255, 196, 60), Enum.NormalId.Front)

	-- ---- corner towers with crenellations ----
	for _, corner in { { -224, 124 }, { 224, 124 }, { -224, -124 }, { 224, -124 } } do
		local cx, cz = corner[1], corner[2]
		tag(part({ Name = "CornerTower", Size = Vector3.new(32, 52, 32), CFrame = CFrame.new(cx, 26, cz), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
		trimBand(cx, 52.8, cz, 35, 35, 2.0)
		for i = 0, 5 do
			for _, edge in { { x = cx - 16 + i * 6.4, z = cz - 16 }, { x = cx - 16 + i * 6.4, z = cz + 16 }, { x = cx - 16, z = cz - 16 + i * 6.4 }, { x = cx + 16, z = cz - 16 + i * 6.4 } } do
				part({ Name = "Crenel", Size = Vector3.new(3.4, 3.4, 3.4), CFrame = CFrame.new(edge.x, 55.4, edge.z), Color = BRICK, Material = Enum.Material.Brick, Parent = parent })
			end
		end
		-- Articulated the same way the clock tower is, so the corner towers stop
		-- being 52 studs of blank stone with three windows on one face. Corner
		-- pilasters, a string course at each stage, and a lancet on EVERY face
		-- rather than only the one the old code happened to pick.
		local kit = kitFor(parent)
		for _, corner in { Vector3.new(-14.6, 0, -14.6), Vector3.new(14.6, 0, -14.6), Vector3.new(-14.6, 0, 14.6), Vector3.new(14.6, 0, 14.6) } do
			tag(part({ Name = "CornerTowerPilaster", Size = Vector3.new(5.4, 52, 5.4), CFrame = CFrame.new(cx + corner.X, 26, cz + corner.Z), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
		end
		for _, stage in { 19, 33, 47 } do
			tag(part({ Name = "CornerTowerCourse", Size = Vector3.new(33.6, 1.2, 33.6), CFrame = CFrame.new(cx, stage, cz), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
		end
		for _, face in {
			{ dx = 0, dz = 16.2, ax = 1 },
			{ dx = 0, dz = -16.2, ax = 1 },
			{ dx = 16.2, dz = 0, ax = 0 },
			{ dx = -16.2, dz = 0, ax = 0 },
		} do
			for _, y in { 11, 26, 40 } do
				local reveal = if face.ax == 1 then Vector3.new(9.0, 12.4, 0.7) else Vector3.new(0.7, 12.4, 9.0)
				local paneSize = if face.ax == 1 then Vector3.new(6.0, 9.6, 0.7) else Vector3.new(0.7, 9.6, 6.0)
				tag(part({ Name = "TowerLancetSurround", Size = reveal, CFrame = CFrame.new(cx + face.dx, y, cz + face.dz), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar").CanCollide = false
				local pane = part({ Name = "TowerLancetGlass", Size = paneSize, CFrame = CFrame.new(cx + face.dx * 1.04, y, cz + face.dz * 1.04), Color = Color3.fromRGB(255, 196, 107), Material = Enum.Material.Neon, Transparency = 0.34, Parent = parent })
				pane.CanCollide = false
				pane.CastShadow = false
			end
		end
		-- and a pinnacle standing on each corner of the parapet
		for _, corner in { Vector3.new(-14.6, 0, -14.6), Vector3.new(14.6, 0, -14.6), Vector3.new(-14.6, 0, 14.6), Vector3.new(14.6, 0, 14.6) } do
			Kit.pinnacle(kit, { x = cx + corner.X, z = cz + corner.Z, base = 57.1, height = 13 })
		end
	end

	-- ---- white trim banding along the long facades ----
	for _, spec in {
		{ z = Z + 1.2, len = 448 },
		{ z = -Z - 1.2, len = 448 },
	} do
		trimBand(0, 14.6, spec.z, spec.len, 2.6, 1.5)
		trimBand(0, 26.2, spec.z, spec.len, 2.6, 1.5)
	end
	for _, x in { -225.2, 225.2 } do
		part({ Name = "FacadeTrim", Size = Vector3.new(2.6, 1.5, 248), CFrame = CFrame.new(x, 14.6, 0), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "FacadeTrim", Size = Vector3.new(2.6, 1.5, 248), CFrame = CFrame.new(x, 26.2, 0), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end

	-- ---- lamps and planters at the entrance ----
	-- The entrance plaza, its walk and the lawn strip are gone. Three separate
	-- ground surfaces were laid over each other and over the Great Court's
	-- paving in the same 46 studs of ground: EntrancePlaza at 0.05, FrontLawn
	-- at 0.12, PlazaWalk at 0.20 and CourtPaving at 0.20. The court paves this
	-- ground now, and the terrace is the one thing standing on it.
	for _, lx in { -50, -38, 38, 50 } do
		lampPost(parent, lx, Z + 30, { short = true, range = 40 })
	end
	-- Stone planters: a base, a tapered body, a moulded rim, soil and a clipped
	-- bay standing in it. Three boxes stacked was a tub with a bush on top.
	for _, px in { -44, 44 } do
		local pz = Z + 46
		part({ Name = "PlanterBase", Size = Vector3.new(11, 0.8, 11), CFrame = CFrame.new(px, 0.6, pz), Color = Color3.fromRGB(160, 154, 144), Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "Planter", Size = Vector3.new(9.4, 3.0, 9.4), CFrame = CFrame.new(px, 2.5, pz), Color = Color3.fromRGB(176, 170, 160), Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "PlanterRim", Size = Vector3.new(10.6, 0.8, 10.6), CFrame = CFrame.new(px, 4.2, pz), Color = Color3.fromRGB(198, 192, 180), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
		for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			part({ Name = "PlanterPanel", Size = Vector3.new(if side[1] ~= 0 then 0.5 else 6.4, 1.8, if side[1] ~= 0 then 6.4 else 0.5), CFrame = CFrame.new(px + side[1] * 4.8, 2.5, pz + side[2] * 4.8), Color = Color3.fromRGB(196, 190, 178), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
		end
		part({ Name = "PlanterSoil", Size = Vector3.new(8.6, 0.6, 8.6), CFrame = CFrame.new(px, 3.9, pz), Color = Color3.fromRGB(78, 58, 42), Material = Enum.Material.Ground, Parent = parent }).CanCollide = false
		Grounds.yewCone({ parent = parent, part = part :: any, tag = tag :: any }, px, pz, 8.0)
	end
	-- flower boxes under the ground-floor windows (the Reddit-street touch)
	for i = 0, 25 do
		local bx = -206 + i * 16.4
		if math.abs(bx) > 40 then
			part({ Name = "WindowBox", Size = Vector3.new(8, 1.6, 2.4), CFrame = CFrame.new(bx, 10.2, Z + 1.6), Color = Color3.fromRGB(104, 68, 44), Material = Enum.Material.WoodPlanks, Parent = parent })
			for f = 0, 2 do
				part({ Name = "BoxBloom", Shape = Enum.PartType.Ball, Size = Vector3.new(1.9, 1.9, 1.9), CFrame = CFrame.new(bx - 2.4 + f * 2.4, 11.4, Z + 1.6), Color = f == 1 and Color3.fromRGB(226, 96, 108) or Color3.fromRGB(238, 176, 84), Material = Enum.Material.Grass, Parent = parent })
			end
		end
	end

	-- ---- the hedge along the front of the school ----
	-- Set back against the facade, and BROKEN at the court's two flank walks.
	-- It used to run unbroken from x = -217 to 217 straight across them, which
	-- sealed the front of the school off from its own grounds: the only way in
	-- or out of the court was the entrance axis.
	for i = 0, 27 do
		local x = -210 + i * 15.5
		local a = math.abs(x)
		if a > 52 and not (a > 82 and a < 112) and not (a > 138 and a < 164) then
			part({ Name = "FrontHedge", Size = Vector3.new(13, 4.4, 6), CFrame = CFrame.new(x, 2.2, Z + 8), Color = Color3.fromRGB(58, 108, 56), Material = Enum.Material.Grass, Parent = parent })
		end
	end
	-- flanking flag poles
	for _, fx in { -38, 38 } do
		part({ Name = "FlagPoleSmall", Size = Vector3.new(0.7, 22, 0.7), CFrame = CFrame.new(fx, 11, Z + 16), Color = Color3.fromRGB(198, 198, 202), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "FlagSmall", Size = Vector3.new(6, 3.6, 0.2), CFrame = CFrame.new(fx + 3.2, 19, Z + 16), Color = fx < 0 and Color3.fromRGB(196, 56, 56) or Color3.fromRGB(56, 96, 196), Material = Enum.Material.Fabric, Parent = parent })
	end
end

-- The campus front, built from the reference: a paved parking apron with
-- parked cars and a bus, bike racks, benches, a bronze statue on a plinth,
-- clipped hedge borders and tall conifers flanking the facade.
-- ================= THE GREAT COURT =================
-- The reference is a formal court: a tiered fountain on the entrance axis,
-- paths radiating from it in a hard geometry, clipped hedge parterres filling
-- the quadrants between them, and lamps at every junction. Ours was an apron
-- of pale paving with a statue off to one side and a car park behind it, which
-- is a forecourt, not a court.
--
-- Everything here is laid out from the fountain, so the whole thing reads as
-- one composition rather than as things that happen to be near each other.
-- The fountain's basin radius. 22 gave a 49-stud bowl on a court 300 wide,
-- which from the gate read as a wedding cake on a paving slab.
local COURT_R = 34

local function courtLamp(parent: Instance, x: number, z: number)
	lampPost(parent, x, z, { range = 52, brightness = 2.4 })
end

-- a light set into the paving, aimed up. The reference is full of these and
-- they are most of why its ground reads as wet stone rather than as a floor.
local function upLight(parent: Instance, x: number, z: number, colour: Color3?)
	local lens = part({ Name = "CourtUplight", Size = Vector3.new(1.6, 0.3, 1.6), CFrame = CFrame.new(x, 0.45, z), Color = colour or Color3.fromRGB(255, 224, 170), Material = Enum.Material.Neon, Parent = parent })
	lens.CanCollide = false
	local light = Instance.new("PointLight")
	light.Brightness = 1.5
	light.Range = 22
	light.Color = colour or Color3.fromRGB(255, 214, 156)
	light.Parent = lens
end

-- ================= THE DORM COURT =================
-- The ground between the school's back wall and the boarding house's front.
-- CampusPlan draws it at (-140, -246) to (140, -152): 280 x 94 studs that the
-- boarders cross twice a day and that the campus spent on nothing -- open
-- terrain with one walk down the middle of it, and the second-largest empty
-- rectangle on the estate after the Great Court was built.
--
-- It is the quiet counterpart to the Great Court, so it is lawn rather than
-- paving: two mown panels inside clipped box, a walk round and across them, an
-- avenue of limes down both sides, benches facing in, and a stone dial on the
-- crossing.
local function buildDormCourt(parent: Instance)
	local site = CampusPlan.site("Dorm Court")
	local rx0, rz0, rx1, rz1 = site.rect[1], site.rect[2], site.rect[3], site.rect[4]
	local cx, cz = (rx0 + rx1) / 2, (rz0 + rz1) / 2
	local width, depth = rx1 - rx0, rz1 - rz0
	local kit = { parent = parent, part = part :: any, tag = tag :: any }
	local AXIS_HALF = 13
	local WALK = 7

	-- the paved perimeter walk and the two that cross it
	local PAVE = Color3.fromRGB(120, 120, 128)
	for _, run in {
		{ w = width, d = WALK * 2, dx = 0, dz = -depth / 2 + WALK },
		{ w = width, d = WALK * 2, dx = 0, dz = depth / 2 - WALK },
		{ w = WALK * 2, d = depth - WALK * 4, dx = -width / 2 + WALK, dz = 0 },
		{ w = WALK * 2, d = depth - WALK * 4, dx = width / 2 - WALK, dz = 0 },
		{ w = AXIS_HALF * 2, d = depth - WALK * 4, dx = 0, dz = 0 },
	} do
		tag(part({
			Name = "DormCourtWalk",
			-- -0.2 .. 0.4, so the walk's underside clears the boarding house's
			-- entrance steps, which start at 0 where the north walk meets them
			Size = Vector3.new(run.w, 0.6, run.d),
			CFrame = CFrame.new(cx + run.dx, 0.1, cz + run.dz),
			Color = PAVE,
			Material = Enum.Material.Slate,
			Parent = parent,
		}), "TexCourtPaving").CanCollide = false
	end

	-- two mown lawn panels either side of the axis walk
	local panelHalfX = (width / 2 - WALK * 2 - AXIS_HALF) / 2
	local panelHalfZ = (depth / 2 - WALK * 2)
	for _, side in { -1, 1 } do
		Grounds.lawnPanel(kit, cx + side * (AXIS_HALF + panelHalfX), cz, panelHalfX, panelHalfZ)
	end

	-- the dial on the crossing, and lamps at the four corners of the walks
	Grounds.dial(kit, cx, cz, upLight :: any)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		courtLamp(parent, cx + corner[1] * (AXIS_HALF + 5), cz + corner[2] * (panelHalfZ + 2))
		courtLamp(parent, cx + corner[1] * (width / 2 - WALK), cz + corner[2] * (panelHalfZ + 2))
	end

	-- benches on the axis walk, backs to the lawn, facing each other
	for _, seat in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		Grounds.bench(
			kit,
			cx + seat[1] * (AXIS_HALF - 2),
			cz + seat[2] * 22,
			if seat[1] > 0 then -math.pi / 2 else math.pi / 2
		)
	end

	-- a lime avenue outside the perimeter walk, down both long sides
	for _, side in { -1, 1 } do
		for i = -1, 1 do
			meshTree(parent, Vector3.new(cx + side * (width / 2 + 12), 0.5, cz + i * 30), 1.1)
		end
	end
	-- and a pair of urns marking the head of the axis walk at each end
	for _, side in { -1, 1 } do
		for _, endz in { -1, 1 } do
			Grounds.urn(kit, cx + side * (AXIS_HALF + 4), cz + endz * (depth / 2 - WALK * 2 - 4), 0.9)
		end
	end
end

-- ================= THE BIKE TRACK =================
-- CampusPlan draws it at (-550, 230) to (-310, 430) and nothing has ever
-- stood there: 48,000 square studs of the campus that the drawing spends on a
-- feature and the build spends on grass and eight trees the scatter planted
-- because nothing told it the ground was spoken for.
--
-- A pump track is a closed ribbon of tarmac that winds: the wobble in the
-- radius below is the point of it, not decoration. Round the outside of each
-- bend the ribbon is banked, there is a gate and a start pad on the straight,
-- and the whole loop is edged so it reads from the air.
local function buildBikeTrack(parent: Instance)
	local site = CampusPlan.site("Bike Track")
	local cx = (site.rect[1] + site.rect[3]) / 2
	local cz = (site.rect[2] + site.rect[4]) / 2
	local A = (site.rect[3] - site.rect[1]) / 2 - 16
	local B = (site.rect[4] - site.rect[2]) / 2 - 16
	local TARMAC = Color3.fromRGB(58, 60, 66)
	local KERB = Color3.fromRGB(206, 200, 186)
	local SEGMENTS = 48
	local HALF_W = 7.0

	local function at(i: number): (number, number)
		local t = (i % SEGMENTS) / SEGMENTS * math.pi * 2
		local wobbleX = 1 + 0.16 * math.cos(3 * t)
		local wobbleZ = 1 + 0.16 * math.sin(2 * t)
		return cx + math.cos(t) * A * wobbleX, cz + math.sin(t) * B * wobbleZ
	end

	for i = 0, SEGMENTS - 1 do
		local x0, z0 = at(i)
		local x1, z1 = at(i + 1)
		local dx, dz = x1 - x0, z1 - z0
		local length = math.sqrt(dx * dx + dz * dz)
		local yaw = math.atan2(dx, dz)
		local mid = CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2) * CFrame.Angles(0, yaw, 0)
		-- the ribbon, overlength by a stud so the joints close on the bends
		-- Alternating courses. Each run overlaps its neighbour by a stud and a
		-- bit so the joints close round the bends, and at one height that is
		-- forty-eight overlapping slabs all topping out in the same plane.
		tag(part({
			Name = "TrackRibbon",
			Size = Vector3.new(HALF_W * 2, 0.5, length + 1.4),
			CFrame = mid * CFrame.new(0, if i % 2 == 0 then 0.25 else 0.31, 0),
			Color = TARMAC,
			Material = Enum.Material.Asphalt,
			Parent = parent,
		}), "TexTarmac").CanCollide = false
		-- the banking: a wedge on the OUTSIDE of the curve, so a bend is a
		-- berm. Which side that is depends on which way the ribbon is turning,
		-- and the ribbon turns both ways -- it winds.
		if i % 2 == 0 then
			-- The berm goes on the side AWAY from the middle of the loop.
			-- Deciding that from which way the ribbon is turning gets it wrong
			-- wherever the wobble reverses the curve, and the first version
			-- banked the whole track on its inside edge. The run's own +X in
			-- world is (cos yaw, -sin yaw); dotted with the vector out from
			-- the centre it says which side is outside, always.
			local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
			local outward = if (mx - cx) * math.cos(yaw) - (mz - cz) * math.sin(yaw) >= 0 then 1 else -1
			local berm = Instance.new("WedgePart")
			berm.Name = "TrackBerm"
			berm.Anchored = true
			berm.CanCollide = false
			berm.Size = Vector3.new(length + 1.4, 3.6, 6.5)
			berm.CFrame = mid
				* CFrame.new(outward * (HALF_W + 3.0), 1.8, 0)
				* CFrame.Angles(0, math.rad(if outward > 0 then -90 else 90), 0)
			berm.Color = Color3.fromRGB(66, 68, 74)
			berm.Material = Enum.Material.Asphalt
			berm.Parent = parent
			tag(berm, "TexTarmac")
			-- packed earth behind the bank, so it stands on something
			part({
				Name = "TrackBermFill",
				Size = Vector3.new(4.0, 1.2, length + 1.4),
				CFrame = mid * CFrame.new(outward * (HALF_W + 7.6), 0.5, 0),
				Color = Color3.fromRGB(74, 62, 48),
				Material = Enum.Material.Ground,
				Parent = parent,
			}).CanCollide = false
		end
		-- edging markers, alternating, every third segment
		if i % 3 == 0 then
			for _, side in { -1, 1 } do
				part({
					Name = "TrackEdge",
					Size = Vector3.new(1.2, 0.9, 2.6),
					CFrame = mid * CFrame.new(side * (HALF_W + 0.8), 0.45, 0),
					Color = if (i // 3) % 2 == 0 then KERB else Color3.fromRGB(188, 68, 58),
					Material = Enum.Material.Concrete,
					Parent = parent,
				}).CanCollide = false
			end
		end
	end

	-- the start: a gate over the ribbon, a grid pad under it and a board
	local sx, sz = at(0)
	local nx, nz = at(1)
	local startYaw = math.atan2(nx - sx, nz - sz)
	local startAt = CFrame.new(sx, 0, sz) * CFrame.Angles(0, startYaw, 0)
	part({ Name = "TrackStartPad", Size = Vector3.new(HALF_W * 2, 0.2, 8), CFrame = startAt * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(226, 224, 216), Material = Enum.Material.SmoothPlastic, Parent = parent }).CanCollide = false
	for i = 0, 6 do
		part({ Name = "TrackStartSquare", Size = Vector3.new(HALF_W * 2 / 7, 0.2, 4), CFrame = startAt * CFrame.new(-HALF_W + (i + 0.5) * (HALF_W * 2 / 7), 0.72, 0), Color = if i % 2 == 0 then Color3.fromRGB(38, 40, 46) else Color3.fromRGB(232, 230, 224), Material = Enum.Material.SmoothPlastic, Parent = parent }).CanCollide = false
	end
	for _, side in { -1, 1 } do
		part({ Name = "TrackGatePost", Size = Vector3.new(1.4, 14, 1.4), CFrame = startAt * CFrame.new(side * (HALF_W + 2), 7, 0), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "TrackGateFoot", Size = Vector3.new(3.0, 0.7, 3.0), CFrame = startAt * CFrame.new(side * (HALF_W + 2), 0.35, 0), Color = Color3.fromRGB(72, 76, 82), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "TrackGateBrace", Size = Vector3.new(0.6, 0.6, 5.0), CFrame = startAt * CFrame.new(side * (HALF_W + 2), 12.4, 2.2) * CFrame.Angles(math.rad(28), 0, 0), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	end
	part({ Name = "TrackGateBeam", Size = Vector3.new(HALF_W * 2 + 6, 1.4, 1.4), CFrame = startAt * CFrame.new(0, 14, 0), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	local banner = part({ Name = "TrackBanner", Size = Vector3.new(HALF_W * 2 + 4, 4.4, 0.4), CFrame = startAt * CFrame.new(0, 11.4, 0), Color = Color3.fromRGB(22, 35, 63), Material = Enum.Material.SmoothPlastic, Parent = parent })
	banner.CanCollide = false
	signText(banner, "CRUMBWORTH TRACK", Color3.fromRGB(217, 180, 92), Enum.NormalId.Front)
	signText(banner, "START / FINISH", Color3.fromRGB(217, 180, 92), Enum.NormalId.Back)

	-- somewhere to leave a bike, and something to watch from
	for _, off in { -14, 14 } do
		local rackAt = startAt * CFrame.new(off, 0, -14)
		part({ Name = "TrackRackBase", Size = Vector3.new(12, 0.5, 5), CFrame = rackAt * CFrame.new(0, 0.35, 0), Color = Color3.fromRGB(150, 150, 156), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
		for i = 0, 3 do
			part({ Name = "TrackHoop", Size = Vector3.new(0.4, 4.0, 0.4), CFrame = rackAt * CFrame.new(-4.5 + i * 3, 2.5, 0), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "TrackHoopTop", Size = Vector3.new(0.4, 0.4, 3.4), CFrame = rackAt * CFrame.new(-4.5 + i * 3, 4.4, 0), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		end
	end

	-- four lamps round the loop, so it is usable at the hour the game is set
	for i = 0, 3 do
		local lx, lz = at(i * SEGMENTS / 4 + 3)
		local away = math.sqrt((lx - cx) ^ 2 + (lz - cz) ^ 2)
		local k = (away + 16) / math.max(away, 1)
		lampPost(parent, cx + (lx - cx) * k, cz + (lz - cz) * k, { range = 52, brightness = 2.0 })
	end
end

local function buildGreatCourt(parent: Instance)
	-- The court comes out of the drawing. It was built 280 x 84 centred on
	-- (0, 166) while CampusPlan drew it 300 x 150 centred on (0, 210), and the
	-- 44-stud difference is why the fountain stood on the school's entrance
	-- steps, why the parterres walled off both flanks, and why the only way
	-- across the court was over the top of a hedge.
	local site = CampusPlan.site("Great Court")
	local rx0, rz0, rx1, rz1 = site.rect[1], site.rect[2], site.rect[3], site.rect[4]
	local cx, cz = (rx0 + rx1) / 2, (rz0 + rz1) / 2
	local width, depth = rx1 - rx0, rz1 - rz0
	local PAVE = Color3.fromRGB(120, 120, 128)
	local PAVE_LIGHT = Color3.fromRGB(126, 126, 132)
	local HEDGE = Color3.fromRGB(44, 84, 46)

	-- ---- circulation, decided before anything is planted ----
	-- Half-widths of the ways through the court. Everything else has to keep
	-- clear of these, and tools/reach_check.py walks them from the spawn pad.
	local AXIS_HALF = 13 -- the entrance walk, on the school's axis
	local CROSS_HALF = 13 -- the walk across the court, through the fountain
	local FLANK = 96 -- the two side walks
	local FLANK_HALF = 7
	local RING = COURT_R + 18 -- open paving kept clear all round the fountain

	-- ---- the paved court ----
	tag(part({ Name = "CourtPaving", Size = Vector3.new(width, 0.4, depth), CFrame = CFrame.new(cx, 0.2, cz), Color = PAVE, Material = Enum.Material.Slate, Parent = parent }), "TexCourtPaving").CanCollide = false
	-- the banding that makes paving read as paving
	for i = -11, 11 do
		part({ Name = "CourtJoint", Size = Vector3.new(width, 0.1, 0.5), CFrame = CFrame.new(cx, 0.52, cz + i * 6.4), Color = PAVE_LIGHT, Material = Enum.Material.Slate, Parent = parent }).CanCollide = false
	end

	-- ---- the walks ----
	-- The three walks that run the depth of the court are laid whole; the walk
	-- across it is laid in the four lengths BETWEEN them. Two paths crossing
	-- means two surfaces in one plane over the whole crossing, and this court
	-- has three crossings -- 1,404 square studs of flicker on the four spots a
	-- player is most likely to be standing.
	for _, x in { -FLANK, 0, FLANK } do
		local half = if x == 0 then AXIS_HALF else FLANK_HALF
		part({
			Name = "CourtPath",
			Size = Vector3.new(half * 2, 0.3, depth),
			CFrame = CFrame.new(cx + x, 0.5, cz),
			Color = PAVE_LIGHT,
			Material = Enum.Material.Slate,
			Parent = parent,
		}).CanCollide = false
	end
	for _, span in {
		{ -width / 2, -FLANK - FLANK_HALF },
		{ -FLANK + FLANK_HALF, -AXIS_HALF },
		{ AXIS_HALF, FLANK - FLANK_HALF },
		{ FLANK + FLANK_HALF, width / 2 },
	} do
		part({
			Name = "CourtPath",
			Size = Vector3.new(span[2] - span[1], 0.3, CROSS_HALF * 2),
			CFrame = CFrame.new(cx + (span[1] + span[2]) / 2, 0.5, cz),
			Color = PAVE_LIGHT,
			Material = Enum.Material.Slate,
			Parent = parent,
		}).CanCollide = false
	end

	-- ---- the paving pattern ----
	-- A field of one grey 300 x 150 studs across is the largest flat surface
	-- on the campus and it read as one. A formal court is laid in courses: a
	-- border band inside the railings, and an octagonal rondel of darker stone
	-- round the fountain that the four walks run out of.
	local kitCtx0 = { parent = parent, part = part :: any, tag = tag :: any }
	local BORDER = Color3.fromRGB(146, 146, 152)
	for _, run in {
		{ w = width, d = 7, dx = 0, dz = -depth / 2 + 3.5 },
		{ w = width, d = 7, dx = 0, dz = depth / 2 - 3.5 },
		{ w = 7, d = depth - 14, dx = -width / 2 + 3.5, dz = 0 },
		{ w = 7, d = depth - 14, dx = width / 2 - 3.5, dz = 0 },
	} do
		tag(part({
			Name = "CourtBorder",
			Size = Vector3.new(run.w, 0.3, run.d),
			CFrame = CFrame.new(cx + run.dx, 0.66, cz + run.dz),
			Color = BORDER,
			Material = Enum.Material.Slate,
			Parent = parent,
		}), "TexCourtPaving").CanCollide = false
	end
	-- the rondel: an octagonal band of darker stone, one course over the
	-- paving and under the fountain's own apron
	for _, piece in Grounds.octagonRing(kitCtx0, "CourtRondel", cx, cz, RING - 5.0, 10.0, 0.3, 0.66, Color3.fromRGB(104, 104, 112), Enum.Material.Slate) do
		piece.CanCollide = false
		tag(piece, "TexCourtPaving")
	end

	-- ---- lime avenue down both flanks ----
	-- The court's two long sides were 150 studs of empty paving. An avenue is
	-- what stands there in every one of the references.
	for _, sx in { -1, 1 } do
		for i = -2, 2 do
			local tz = cz + i * 28
			if math.abs(tz - cz) > CROSS_HALF + 10 or i == 0 then
				meshTree(parent, Vector3.new(cx + sx * (FLANK + 16), 0.5, tz), 1.15)
			end
		end
	end

	-- ---- the fountain, on the crossing ----
	-- Built by GroundsKit: an octagonal basin with a coping and a moulded base,
	-- water in it, a stepped pedestal, three dishes with their falls, eight
	-- jets arcing in off the rim and a plume over the finial. What stood here
	-- was three cylinders on a stem, 49 studs across in a court 300 wide, and
	-- from the gate it read as a wedding cake on a paving slab.
	local kitCtx = { parent = parent, part = part :: any, tag = tag :: any }
	Grounds.fountain(kitCtx, { x = cx, z = cz, r = COURT_R, upLight = upLight :: any })

	-- ---- the parterres ----
	-- One in each quadrant, inside the walks and outside the ring of open
	-- paving round the fountain: gravel, a stone kerb, a clipped box edge, a
	-- knot of box, a yew cone at each corner, an urn on the middle and flowers
	-- in the compartments. They were sixteen rectangles of bare soil on a grid
	-- that ignored both the walks and the fountain, so the hedges met across
	-- every route and the only continuous surface through the court was the
	-- top of a hedge.
	local bedHalfX = (FLANK - FLANK_HALF - RING) / 2
	local bedHalfZ = (depth / 2 - CROSS_HALF - 10) / 2
	for _, quad in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		Grounds.parterre(kitCtx, {
			x = cx + quad[1] * (RING + bedHalfX),
			z = cz + quad[2] * (CROSS_HALF + 6 + bedHalfZ),
			hw = bedHalfX,
			hd = bedHalfZ,
			flower = prop :: any,
			upLight = upLight :: any,
		})
	end

	-- ---- the court is enclosed, the way every reference court is ----
	-- spear-topped railings on a stone kerb between piers, broken at the
	-- entrance axis and at both flank walks
	local function railRun(x0: number, z0: number, x1: number, z1: number)
		Grounds.railing(kitCtx, x0, z0, x1, z1, 8.0)
	end
	for _, side in { -1, 1 } do
		local ex = cx + side * width / 2
		for _, span in {
			{ cz - depth / 2, cz - CROSS_HALF - 4 },
			{ cz + CROSS_HALF + 4, cz + depth / 2 },
		} do
			railRun(ex, span[1], ex, span[2])
		end
		Grounds.gatePier(kitCtx, ex, cz - CROSS_HALF - 4, 9.0)
		Grounds.gatePier(kitCtx, ex, cz + CROSS_HALF + 4, 9.0)
		Grounds.gatePier(kitCtx, ex, cz - depth / 2, 9.0)
		Grounds.gatePier(kitCtx, ex, cz + depth / 2, 9.0)
	end
	-- the north side, either side of the drive
	for _, span in {
		{ cx - width / 2 + 4, cx - AXIS_HALF - 5 },
		{ cx + AXIS_HALF + 5, cx + width / 2 - 4 },
	} do
		railRun(span[1], cz + depth / 2, span[2], cz + depth / 2)
	end
	Grounds.gatePier(kitCtx, cx - AXIS_HALF - 5, cz + depth / 2, 13.0)
	Grounds.gatePier(kitCtx, cx + AXIS_HALF + 5, cz + depth / 2, 13.0)

	-- ---- benches on the ring, facing the water ----
	-- On the diagonals, so they stand clear of the entrance walk and the walk
	-- across, in the open paving between the fountain's apron and the beds.
	for _, seat in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local ox, oz = seat[1] * (COURT_R + 9), seat[2] * (COURT_R + 9)
		Grounds.bench(kitCtx, cx + ox, cz + oz, math.atan2(ox, oz))
	end

	-- ---- lamps: at every junction of the walks, and down the flanks ----
	for _, at in {
		{ -AXIS_HALF - 4, -CROSS_HALF - 4 }, { AXIS_HALF + 4, -CROSS_HALF - 4 },
		{ -AXIS_HALF - 4, CROSS_HALF + 4 }, { AXIS_HALF + 4, CROSS_HALF + 4 },
		{ -FLANK, -CROSS_HALF - 8 }, { FLANK, -CROSS_HALF - 8 },
		{ -FLANK, CROSS_HALF + 8 }, { FLANK, CROSS_HALF + 8 },
		{ -FLANK, -depth / 2 + 14 }, { FLANK, -depth / 2 + 14 },
		{ -FLANK, depth / 2 - 14 }, { FLANK, depth / 2 - 14 },
		{ -AXIS_HALF - 4, -depth / 2 + 14 }, { AXIS_HALF + 4, -depth / 2 + 14 },
		{ -AXIS_HALF - 4, depth / 2 - 14 }, { AXIS_HALF + 4, depth / 2 - 14 },
	} do
		courtLamp(parent, cx + at[1], cz + at[2])
	end
	-- and uplighters along the entrance axis, outside the walk
	for i = -6, 6 do
		local z = cz + i * 9
		-- skip the band the fountain's own rim lights already cover
		if math.abs(z - cz) > RING then
			upLight(parent, cx - AXIS_HALF - 2, z)
			upLight(parent, cx + AXIS_HALF + 2, z)
		end
	end

	-- ---- the founder, closing the CROSS axis ----
	-- Not on the entrance axis. The drawing keeps the ceremonial approach clear
	-- of anything over eleven studs so the school is the thing you see walking
	-- in from the gate, and tools/build_check.py enforces it -- an eighteen
	-- stud bronze standing on the centre line was the one thing in the court
	-- that broke that rule.
	local mx, mz = cx - 120, cz
	part({ Name = "MonumentBase", Size = Vector3.new(18, 1.6, 18), CFrame = CFrame.new(mx, 0.9, mz), Color = Color3.fromRGB(178, 174, 166), Material = Enum.Material.Concrete, Parent = parent })
	tag(part({ Name = "MonumentPlinth", Size = Vector3.new(11, 8, 11), CFrame = CFrame.new(mx, 5.7, mz), Color = Color3.fromRGB(196, 192, 184), Material = Enum.Material.Marble, Parent = parent }), "TexAshlar")
	part({ Name = "MonumentCap", Size = Vector3.new(13, 1.2, 13), CFrame = CFrame.new(mx, 10.3, mz), Color = Color3.fromRGB(206, 202, 194), Material = Enum.Material.Marble, Parent = parent })
	local BRONZE = Color3.fromRGB(122, 92, 52)
	part({ Name = "StatueTorso", Size = Vector3.new(4, 6, 2.6), CFrame = CFrame.new(mx, 14, mz), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "StatueHead", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(mx, 18.2, mz), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "StatueArm", Size = Vector3.new(1.2, 5.4, 1.2), CFrame = CFrame.new(mx - 2.8, 15.2, mz) * CFrame.Angles(0, 0, math.rad(24)), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "StatueArmUp", Size = Vector3.new(1.2, 6, 1.2), CFrame = CFrame.new(mx + 2.9, 16.4, mz) * CFrame.Angles(0, 0, math.rad(-38)), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	for _, lx in { -1.1, 1.1 } do
		part({ Name = "StatueLeg", Size = Vector3.new(1.5, 5, 1.5), CFrame = CFrame.new(mx + lx, 8.4, mz), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	end
	local plaque = part({ Name = "StatuePlaque", Size = Vector3.new(7, 2.4, 0.4), CFrame = CFrame.new(mx, 6.4, mz - 5.7), Color = Color3.fromRGB(96, 74, 44), Material = Enum.Material.Metal, Parent = parent })
	plaque.CanCollide = false
	-- Front, which in Roblox is the MINUS-Z face -- so this reads south, back
	-- down the axis towards the school.
	signText(plaque, "CRUMBWORTH", Color3.fromRGB(238, 226, 196), Enum.NormalId.Front)
	for _, uz in { -7, 7 } do
		upLight(parent, mx + 8, mz + uz, Color3.fromRGB(255, 224, 172))
	end

	-- ---- and an armillary sphere closing the other end of it ----
	local ax, az = cx + 120, cz
	part({ Name = "SundialBase", Size = Vector3.new(14, 1.4, 14), CFrame = CFrame.new(ax, 0.85, az), Color = Color3.fromRGB(178, 174, 166), Material = Enum.Material.Concrete, Parent = parent })
	tag(part({ Name = "SundialPlinth", Size = Vector3.new(6, 7, 6), CFrame = CFrame.new(ax, 5.1, az), Color = Color3.fromRGB(196, 192, 184), Material = Enum.Material.Marble, Parent = parent }), "TexAshlar")
	part({ Name = "SundialCap", Size = Vector3.new(8.4, 1.1, 8.4), CFrame = CFrame.new(ax, 9.1, az), Color = Color3.fromRGB(206, 202, 194), Material = Enum.Material.Marble, Parent = parent })
	local BRASS = Color3.fromRGB(168, 132, 58)
	-- three brass rings on the polar axis, which is what an armillary is
	for i, ring in { { 0, 0 }, { 0, 90 }, { 34, 0 } } do
		local hoop = part({
			Name = "ArmillaryRing",
			Size = Vector3.new(9.6, 0.5, 9.6),
			CFrame = CFrame.new(ax, 13.2, az) * CFrame.Angles(math.rad(ring[1] + 56), math.rad(ring[2]), 0),
			Color = BRASS,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		hoop.Shape = Enum.PartType.Cylinder
		hoop.CanCollide = false
		local _ = i
	end
	part({ Name = "ArmillaryGnomon", Size = Vector3.new(0.5, 12, 0.5), CFrame = CFrame.new(ax, 13.2, az) * CFrame.Angles(math.rad(34), 0, 0), Color = BRASS, Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	part({ Name = "ArmillaryCore", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = CFrame.new(ax, 13.2, az), Color = Color3.fromRGB(214, 178, 96), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	local dialPlate = part({ Name = "SundialPlate", Size = Vector3.new(5.4, 0.4, 2.2), CFrame = CFrame.new(ax, 9.75, az - 2.4), Color = Color3.fromRGB(96, 74, 44), Material = Enum.Material.Metal, Parent = parent })
	dialPlate.CanCollide = false
	signText(dialPlate, "TEMPUS FUGIT", Color3.fromRGB(238, 226, 196), Enum.NormalId.Top)
	for _, uz in { -7, 7 } do
		upLight(parent, ax - 8, az + uz, Color3.fromRGB(255, 224, 172))
	end
end

local function buildFrontGrounds(parent: Instance)
	local Z = 124
	local ASPHALT = Color3.fromRGB(64, 66, 72)
	local CURB = Color3.fromRGB(198, 194, 186)

	-- THE CAR PARK, moved east to where it is drawn.
	--
	-- It was two aprons flanking the entrance plaza at x +-132, and they were
	-- wrong twice over. A car park across the walk from the gate to the front
	-- doors is the same fault as the bike racks and the wood: back-of-house on
	-- the ceremonial approach. And it lay under the Great Court -- 4,216 square
	-- yards of tarmac in exactly the plane of the court paving, the largest
	-- single patch of flickering surface on the campus.
	--
	-- CampusPlan puts the Parking Lot at (430, 40), 190 x 150, which is where
	-- the reference aerial has it: off to one side, reached from the road, out
	-- of the view of the school.
	do
		local LOT_X, LOT_Z = 430, 40
		part({ Name = "ParkingLot", Size = Vector3.new(180, 0.5, 140), CFrame = CFrame.new(LOT_X, 0.15, LOT_Z), Color = ASPHALT, Material = Enum.Material.Asphalt, Parent = parent })
		tag(part({ Name = "ParkingCurb", Size = Vector3.new(182, 1.1, 2), CFrame = CFrame.new(LOT_X, 0.5, LOT_Z - 70), Color = CURB, Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar")
		tag(part({ Name = "ParkingCurb", Size = Vector3.new(182, 1.1, 2), CFrame = CFrame.new(LOT_X, 0.5, LOT_Z + 70), Color = CURB, Material = Enum.Material.Concrete, Parent = parent }), "TexAshlar")
		-- two ranks of bays back to back, the way a car park is actually laid out
		for _, rank in { -1, 1 } do
			local rz = LOT_Z + rank * 34
			for i = 0, 10 do
				part({ Name = "ParkingLine", Size = Vector3.new(0.6, 0.15, 26), CFrame = CFrame.new(LOT_X - 75 + i * 15, 0.42, rz), Color = Color3.fromRGB(232, 228, 210), Material = Enum.Material.SmoothPlastic, Parent = parent })
			end
			local carColors = {
				Color3.fromRGB(196, 62, 58), Color3.fromRGB(52, 96, 176),
				Color3.fromRGB(226, 226, 230), Color3.fromRGB(64, 148, 108),
				Color3.fromRGB(228, 176, 66),
			}
			for i = 0, 5 do
				local cx = LOT_X - 68 + i * 15
				local col = carColors[(i + (rank > 0 and 2 or 0)) % #carColors + 1]
				part({ Name = "CarBody", Size = Vector3.new(7.4, 3.4, 15), CFrame = CFrame.new(cx, 2.4, rz), Color = col, Material = Enum.Material.SmoothPlastic, Parent = parent })
				part({ Name = "CarCabin", Size = Vector3.new(6.8, 3.2, 7.6), CFrame = CFrame.new(cx, 5.4, rz + rank * 0.6), Color = col, Material = Enum.Material.SmoothPlastic, Parent = parent })
				part({ Name = "CarGlass", Size = Vector3.new(6.9, 2.2, 6.4), CFrame = CFrame.new(cx, 5.8, rz + rank * 0.6), Color = Color3.fromRGB(126, 158, 178), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
				for _, wz in { rz - 5.6, rz + 5.6 } do
					for _, wx in { cx - 3.5, cx + 3.5 } do
						part({ Name = "CarWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 2.8, 2.8), CFrame = CFrame.new(wx, 1.4, wz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.SmoothPlastic, Parent = parent })
					end
				end
				part({ Name = "CarLight", Size = Vector3.new(5.6, 0.8, 0.4), CFrame = CFrame.new(cx, 2.8, rz - rank * 7.4), Color = Color3.fromRGB(255, 246, 214), Material = Enum.Material.Neon, Parent = parent })
			end
		end
		-- Lamp masts INSIDE the lot. The far-side rank stood at LOT_X + 84,
		-- which is four studs past the tarmac and into the boundary planting,
		-- so one of them grew out of an oak.
		for _, lz in { LOT_Z - 52, LOT_Z + 52 } do
			for _, lx in { LOT_X - 62, LOT_X + 62 } do
				lampPost(parent, lx, lz, { range = 62, brightness = 2.4 })
			end
		end
		lampPost(parent, LOT_X, LOT_Z, { range = 58, brightness = 2.2 })
	end

	-- Bike racks OFF the ceremonial approach.
	--
	-- These stood at x +-68 on the walk up to the front doors, which is the one
	-- place on the campus they cannot go: the approach is the view of the
	-- school, and a rank of steel hoops across it is exactly the "why is there
	-- a court on the front of the school" problem in miniature. They sit out at
	-- +-186, past the wings, where people actually arrive from the road.
	for _, sgn in { -1, 1 } do
		local bx = sgn * 186
		part({ Name = "BikeRackBase", Size = Vector3.new(16, 0.5, 6), CFrame = CFrame.new(bx, 0.4, Z + 22), Color = Color3.fromRGB(150, 150, 156), Material = Enum.Material.Concrete, Parent = parent })
		for i = 0, 4 do
			part({ Name = "BikeHoop", Size = Vector3.new(0.5, 4.4, 0.5), CFrame = CFrame.new(bx - 6 + i * 3, 2.6, Z + 22), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = parent })
			part({ Name = "BikeHoopTop", Size = Vector3.new(0.5, 0.5, 4), CFrame = CFrame.new(bx - 6 + i * 3, 4.7, Z + 22), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = parent })
		end
	end

	-- The benches are the court's, built by GroundsKit on the fountain's ring
	-- with cast-iron ends and slatted seats. These were two boxes and a leg
	-- each, standing at x = +-18 on the entrance walk.

	-- The founder's statue is not here any more. It stood at (-56, 168), which
	-- is inside the Great Court as drawn, half on the west flank walk; the
	-- court builds it as the monument that closes the vista instead.
	--
	-- The border hedges are gone with it. They were the edging of a lawn that
	-- the court replaced, and they ran x = +-74 the whole depth of the court
	-- and straight across both flank walks: an unbroken 3.6-stud hedge round
	-- three sides of the approach, which is why nothing outside the entrance
	-- axis could be walked to.

	-- school sign board, out at the road where it can be read from a car
	for _, sx2 in { 56, 84 } do
		part({ Name = "SignPost", Size = Vector3.new(1.4, 8, 1.4), CFrame = CFrame.new(sx2, 4, ROAD_Z - 16), Color = Color3.fromRGB(96, 62, 42), Material = Enum.Material.WoodPlanks, Parent = parent })
	end
	local board = part({ Name = "SchoolSignBoard", Size = Vector3.new(28, 9, 1.2), CFrame = CFrame.new(70, 11, ROAD_Z - 16), Color = Color3.fromRGB(28, 44, 78), Material = Enum.Material.SmoothPlastic, Parent = parent })
	-- both faces: the road is on one side of this and the whole school on the
	-- other, and only the road could read it
	signText(board, "DETENTION\nCRUMBWORTH HIGH", Color3.fromRGB(255, 208, 96), Enum.NormalId.Front)
	signText(board, "DETENTION\nCRUMBWORTH HIGH", Color3.fromRGB(255, 208, 96), Enum.NormalId.Back)
	part({ Name = "SignBoardTrim", Size = Vector3.new(29.4, 10.4, 0.6), CFrame = CFrame.new(70, 11, ROAD_Z - 15.5), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
end


-- The main corridor, built from the locker-hallway reference: banks of
-- lockers with a few doors swung open and contents inside, water coolers,
-- trophy cases, recessed ceiling panels and a tiled floor band.
local function detailCorridor(parent: Instance)
	local LOCKER = Color3.fromRGB(46, 84, 168)
	local LOCKER_DARK = Color3.fromRGB(30, 58, 122)
	local rng = Random.new(91)
	for _, spec in {
		{ z = 79.6, face = -1, banks = { -196, -168, -140, -112, 112, 140, 168, 196 } },
		-- the north wall moved out with the widening, and the banks with it;
		-- past x = 172 there is no wall on this side any more, only the way
		-- through to the far rooms
		{ z = 50.4, face = 1, banks = { -160, -128, 128, 160 } },
	} do
		for _, bankX in spec.banks do
			for i = 0, 5 do
				local lx = bankX - 12 + i * 4.2
				local open = rng:NextNumber() < 0.22
				-- carcass
				part({ Name = "LockerBody", Size = Vector3.new(4, 9, 3), CFrame = CFrame.new(lx, 4.6, spec.z + spec.face * 1.4), Color = LOCKER_DARK, Material = Enum.Material.Metal, Parent = parent })
				if open then
					-- shelf + contents visible in the opening
					part({ Name = "LockerShelf", Size = Vector3.new(3.4, 0.3, 2.4), CFrame = CFrame.new(lx, 6.6, spec.z + spec.face * 1.4), Color = Color3.fromRGB(196, 196, 200), Material = Enum.Material.Metal, Parent = parent })
					part({ Name = "LockerBooks", Size = Vector3.new(2.4, 2.2, 1.6), CFrame = CFrame.new(lx, 2.2, spec.z + spec.face * 1.5), Color = rng:NextNumber() < 0.5 and Color3.fromRGB(178, 62, 58) or Color3.fromRGB(58, 118, 92), Material = Enum.Material.SmoothPlastic, Parent = parent })
					part({ Name = "LockerBottle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1, 1), CFrame = CFrame.new(lx + 0.9, 7.9, spec.z + spec.face * 1.4) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(232, 226, 214), Material = Enum.Material.SmoothPlastic, Parent = parent })
					-- door swung out into the corridor
					-- A third of a stud of sheet metal swung out into the
					-- corridor at head height. It is scenery, and a player
					-- walking into one and stopping dead is a bug wearing a
					-- locker door: the audit found two of them standing in the
					-- new walking lanes.
					part({ Name = "LockerDoorOpen", Size = Vector3.new(3.9, 8.6, 0.35), CFrame = CFrame.new(lx - 1.9, 4.6, spec.z + spec.face * 4.2) * CFrame.Angles(0, math.rad(78) * spec.face, 0), Color = LOCKER, Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
				else
					local door = part({ Name = "LockerDoor", Size = Vector3.new(3.9, 8.6, 0.4), CFrame = CFrame.new(lx, 4.6, spec.z + spec.face * 2.9), Color = LOCKER, Material = Enum.Material.Metal, Parent = parent })
					local _ = door
					-- vent slots + handle
					for v = 0, 2 do
						part({ Name = "LockerVent", Size = Vector3.new(2.6, 0.28, 0.5), CFrame = CFrame.new(lx, 7.6 + v * 0.6, spec.z + spec.face * 3.1), Color = LOCKER_DARK, Material = Enum.Material.Metal, Parent = parent })
					end
					part({ Name = "LockerHandle", Size = Vector3.new(0.4, 1.4, 0.5), CFrame = CFrame.new(lx + 1.4, 4.4, spec.z + spec.face * 3.1), Color = Color3.fromRGB(214, 214, 220), Material = Enum.Material.Metal, Parent = parent })
				end
			end
			-- bank top rail
			part({ Name = "LockerTop", Size = Vector3.new(26, 0.6, 3.4), CFrame = CFrame.new(bankX, 9.3, spec.z + spec.face * 1.6), Color = LOCKER_DARK, Material = Enum.Material.Metal, Parent = parent })
		end
		-- water coolers between banks
		for _, wx in { -110, 110 } do
			part({ Name = "CoolerBody", Size = Vector3.new(3, 5, 2.6), CFrame = CFrame.new(wx, 2.5, spec.z + spec.face * 1.4), Color = Color3.fromRGB(226, 228, 232), Material = Enum.Material.SmoothPlastic, Parent = parent })
			part({ Name = "CoolerBottle", Size = Vector3.new(2.4, 3.4, 2.4), CFrame = CFrame.new(wx, 6.7, spec.z + spec.face * 1.4), Color = Color3.fromRGB(150, 206, 226), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
		end
	end
	-- trophy cases flanking the lobby end
	for _, tx in { -74, 74 } do
		part({ Name = "TrophyCase", Size = Vector3.new(16, 10, 2.4), CFrame = CFrame.new(tx, 5.4, 79.4), Color = Color3.fromRGB(92, 60, 40), Material = Enum.Material.WoodPlanks, Parent = parent })
		part({ Name = "TrophyGlass", Size = Vector3.new(14.4, 7.6, 0.4), CFrame = CFrame.new(tx, 6, 78), Color = Color3.fromRGB(196, 226, 238), Material = Enum.Material.Glass, Transparency = 0.5, Parent = parent })
		for tI = 0, 3 do
			part({ Name = "Trophy", Size = Vector3.new(1.2, 2.4, 1.2), CFrame = CFrame.new(tx - 5 + tI * 3.4, 4.6, 78.8), Color = Color3.fromRGB(212, 176, 78), Material = Enum.Material.Metal, Parent = parent })
		end
	end
	-- recessed ceiling panels down the corridor
	for i = 0, 26 do
		part({ Name = "CeilingPanel", Size = Vector3.new(10, 0.3, 6), CFrame = CFrame.new(-208 + i * 16, 15.1, 65), Color = Color3.fromRGB(255, 250, 236), Material = Enum.Material.Neon, Parent = parent })
	end
	-- tiled centre band on the floor
	tag(part({ Name = "CorridorTileBand", Size = Vector3.new(440, 0.12, 10), CFrame = CFrame.new(0, 0.09, 65), Color = Color3.fromRGB(212, 208, 198), Material = Enum.Material.CeramicTiles, Parent = parent }), "TexFloorTile")
end

-- ================= THE UPPER FLOOR =================
-- The school always looked like three storeys from the outside -- the facade
-- has three bands of windows -- and was one storey deep. This is the second,
-- built into the band the facade already draws: floor at y = 16, walls to
-- 31.6, which is exactly the height buildInteriorWall makes when it is handed
-- a base at that level.
--
-- The plan is a ring. South rooms, the upper hall over the main hallway, a
-- wing down each side and a north row, with the whole middle left open: you
-- come up the stairs and the atrium and both courtyards fall away beneath
-- you. A second storey that is merely more corridor is not worth climbing.
local UPPER_Y = 16
local UPPER_CEIL = 31.6

-- Each entry is a floor rectangle {x0, z0, x1, z1}. The holes -- the atrium,
-- the courtyards, the gym, the lobby light well and the four stair wells --
-- are cut by leaving them out, which is why the south band is in pieces.
--
-- The stair wells have to stop exactly where the top tread does. They used to
-- run four studs past it, so you climbed sixteen studs, stepped forward off
-- the last step and fell straight back down the hole.
local UPPER_SLABS = {
	-- south band, around the lobby light well and the two lobby stairs
	{ -224, 81, -52, 124 },
	{ -52, 81, -40, 89 },
	{ -52, 118, -40, 124 },
	{ -40, 81, -34, 124 },
	{ -34, 81, 34, 88 },
	{ -34, 118, 34, 124 },
	{ 34, 81, 40, 124 },
	{ 40, 81, 52, 89 },
	{ 40, 118, 52, 124 },
	{ 52, 81, 224, 124 },
	-- the upper hall, straight across over the main hallway
	{ -224, 49, 224, 81 },
	-- West wing, around its stair well.
	--
	-- The well used to be cut at x -202..-190, z -22..6, which is where the
	-- flight used to be before it was moved out of the principal's office to
	-- x = -178. Nothing moved the hole with it, so the stairs climbed
	-- straight into the underside of this slab -- an unclimbable flight and,
	-- next to it, an unreachable hole. It is cut to the flight now:
	-- 12 wide over x -184..-172, opening at z = 4 (where the treads first get
	-- within head height of the deck) and ending at z = 17.6, the far edge of
	-- the sixteenth tread, so you step off the top onto solid floor.
	{ -224, -64, -184, 49 },
	{ -184, -64, -172, 4 },
	{ -184, 17.6, -172, 49 },
	-- east wing, mirrored
	{ 184, -64, 224, 49 },
	{ 172, -64, 184, 4 },
	{ 172, 17.6, 184, 49 },
	-- north band, open over the gym
	{ -224, -124, -50, -64 },
	{ 50, -124, 224, -64 },
}

-- Where the void edges are, so a railing can run along each one.
local UPPER_RAILS = {
	{ -172, 49, 172, 49 }, -- the long inner edge over the courtyards
	{ -60, -64, 60, -64 }, -- over the gym doors
	{ -172, -64, -172, 49 },
	{ 172, -64, 172, 49 },
	{ -50, -124, -50, -64 }, -- the gym well
	{ 50, -124, 50, -64 },
	{ -34, 88, 34, 88 }, -- the lobby light well
	{ -34, 118, 34, 118 },
	{ -34, 88, -34, 118 },
	{ 34, 88, 34, 118 },
	{ -184, 4, -172, 4 }, -- the wing stair wells: the lip you walk up to
	{ -184, 4, -184, 17.6 },
	{ 172, 4, 184, 4 },
	{ 184, 4, 184, 17.6 },
}

-- The rooms upstairs. The five timetabled subjects stay on the ground floor
-- where the professors are; these are the rest of a school, and each one is
-- built around a single idea rather than being a room with desks in it.
export type UpperRoom = {
	name: string,
	label: string,
	icon: string,
	center: Vector3,
	size: Vector2,
	color: Color3,
	floor: Color3,
}

local UPPER_ROOMS: { UpperRoom } = {
	{ name = "ArtRoom", label = "ART", icon = "🎨", center = Vector3.new(-190, UPPER_Y, 103), size = Vector2.new(52, 38), color = Color3.fromRGB(236, 132, 88), floor = Color3.fromRGB(176, 122, 88) },
	{ name = "HistoryRoom", label = "HISTORY", icon = "🏛️", center = Vector3.new(-122, UPPER_Y, 103), size = Vector2.new(52, 38), color = Color3.fromRGB(190, 158, 96), floor = Color3.fromRGB(122, 92, 64) },
	{ name = "ComputerLab", label = "COMPUTER LAB", icon = "💻", center = Vector3.new(122, UPPER_Y, 103), size = Vector2.new(52, 38), color = Color3.fromRGB(104, 176, 226), floor = Color3.fromRGB(70, 78, 92) },
	{ name = "LanguageLab", label = "LANGUAGES", icon = "🗣️", center = Vector3.new(190, UPPER_Y, 103), size = Vector2.new(52, 38), color = Color3.fromRGB(140, 200, 150), floor = Color3.fromRGB(126, 130, 120) },
	{ name = "StudyHall", label = "STUDY HALL", icon = "📖", center = Vector3.new(-190, UPPER_Y, -94), size = Vector2.new(52, 52), color = Color3.fromRGB(196, 176, 216), floor = Color3.fromRGB(120, 96, 130) },
	{ name = "DramaStudio", label = "DRAMA", icon = "🎭", center = Vector3.new(-122, UPPER_Y, -94), size = Vector2.new(52, 52), color = Color3.fromRGB(214, 96, 120), floor = Color3.fromRGB(78, 60, 72) },
	{ name = "Infirmary", label = "NURSE", icon = "🏥", center = Vector3.new(122, UPPER_Y, -94), size = Vector2.new(52, 52), color = Color3.fromRGB(232, 240, 244), floor = Color3.fromRGB(206, 224, 226) },
	-- The staff room used to be here. Teachers live in their own lodge off the
	-- west path now, so this is the students' common room.
	{ name = "CommonRoom", label = "COMMON ROOM", icon = "🛋️", center = Vector3.new(190, UPPER_Y, -94), size = Vector2.new(52, 52), color = Color3.fromRGB(238, 176, 96), floor = Color3.fromRGB(126, 104, 84) },
}

-- A flight of stairs as solid blocks: each tread is a box from the ground to
-- its own top, so there is no gap to fall through and no invisible ramp to
-- disagree with what you can see. `base` sits at the foot and looks up the
-- flight, so the climb runs along its LookVector -- local -Z, which is why
-- every offset here is negative in Z.
local function buildStair(parent: Instance, base: CFrame, steps: number, rise: number, run: number, width: number)
	for i = 0, steps - 1 do
		local top = (i + 1) * rise
		part({
			Name = "StairTread",
			Size = Vector3.new(width, top, run),
			CFrame = base * CFrame.new(0, top / 2, -(i + 0.5) * run),
			Color = Color3.fromRGB(214, 208, 196),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
	end
	local length = steps * run
	local climb = steps * rise
	for _, side in { -1, 1 } do
		-- a stringer and a rail, so the flight reads as built rather than
		-- as a stack of boxes
		local stringer = part({
			Name = "StairStringer",
			Size = Vector3.new(1.2, 2.4, math.sqrt(length * length + climb * climb)),
			CFrame = base
				* CFrame.new(side * (width / 2 + 0.5), climb / 2, -length / 2)
				* CFrame.Angles(math.atan2(climb, length), 0, 0),
			Color = Color3.fromRGB(120, 84, 58),
			Material = Enum.Material.WoodPlanks,
			Parent = parent,
		})
		stringer.CanCollide = false
		local rail = part({
			Name = "StairRail",
			Size = Vector3.new(0.5, 0.5, math.sqrt(length * length + climb * climb)),
			CFrame = base
				* CFrame.new(side * (width / 2 + 0.5), climb / 2 + 3.4, -length / 2)
				* CFrame.Angles(math.atan2(climb, length), 0, 0),
			Color = Color3.fromRGB(226, 220, 208),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		rail.CanCollide = false
	end
end

local function buildRailing(parent: Instance, from: Vector3, to: Vector3)
	local dir = to - from
	local length = dir.Magnitude
	if length < 1 then
		return
	end
	local mid = from + dir * 0.5
	local cf = CFrame.lookAt(mid, mid + Vector3.new(-dir.Unit.Z, 0, dir.Unit.X))
	part({ Name = "BalconyKick", Size = Vector3.new(length, 1.6, 1.2), CFrame = cf * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(226, 222, 210), Material = Enum.Material.Concrete, Parent = parent })
	local top = part({ Name = "BalconyRail", Size = Vector3.new(length, 0.7, 1.4), CFrame = cf * CFrame.new(0, 5.2, 0), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
	top.CanCollide = true
	local balusters = math.max(2, math.floor(length / 3.2))
	for i = 0, balusters do
		local at = -length / 2 + (length / balusters) * i
		local post = part({ Name = "Baluster", Size = Vector3.new(0.4, 3.4, 0.4), CFrame = cf * CFrame.new(at, 3.3, 0), Color = Color3.fromRGB(206, 200, 188), Material = Enum.Material.Metal, Parent = parent })
		post.CanCollide = false
	end
	-- an invisible wall so nobody walks between the balusters
	local guard = part({ Name = "BalconyGuard", Size = Vector3.new(length, 5.4, 1), CFrame = cf * CFrame.new(0, 2.7, 0), Color = Color3.fromRGB(226, 222, 210), Parent = parent })
	guard.Transparency = 1
	guard.CanCollide = true
end

local function buildUpperFloor(parent: Instance)
	-- ---- the deck ----
	for index, rect in UPPER_SLABS do
		local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
		tag(part({
			Name = "UpperFloor" .. index,
			Size = Vector3.new(x1 - x0, 1, z1 - z0),
			CFrame = CFrame.new((x0 + x1) / 2, UPPER_Y - 0.5, (z0 + z1) / 2),
			Color = Color3.fromRGB(196, 194, 188),
			Parent = parent,
		}), "TexFloorTile")
		-- the underside is the ground floor's ceiling, which it never had
		tag(part({
			Name = "UpperSoffit" .. index,
			Size = Vector3.new(x1 - x0, 0.6, z1 - z0),
			-- 1.15, not 1.3. The deck spans UPPER_Y-1 to UPPER_Y and the soffit
			-- spanned UPPER_Y-1.6 to UPPER_Y-1, so its top face landed EXACTLY
			-- on the deck's underside: nearly sixty thousand square studs of
			-- ceiling fighting the floor above it, over the whole school. It
			-- was invisible in a list sorted by how MANY pairs each name makes,
			-- because it is one enormous pair per slab.
			CFrame = CFrame.new((x0 + x1) / 2, UPPER_Y - 1.15, (z0 + z1) / 2),
			Color = Color3.fromRGB(238, 234, 224),
			Parent = parent,
		}), "TexCeiling")
		-- no ceiling here: the school's roof slabs cap the upper storey at
		-- 32.6, which is a stud above the upper walls
	end

	-- ---- the edges you can fall off ----
	for _, rail in UPPER_RAILS do
		buildRailing(parent, Vector3.new(rail[1], UPPER_Y, rail[2]), Vector3.new(rail[3], UPPER_Y, rail[4]))
	end

	-- ---- getting up there ----
	-- two grand flights out of the lobby, one in each wing. 16 treads of 1 by
	-- 1.8 is a climb Roblox's step height takes without a stutter.
	-- 12 wide, which is the full width of the well: a flight narrower than its
	-- own hole leaves a slot down each side to fall through
	for _, sx in { -46, 46 } do
		buildStair(parent, CFrame.lookAt(Vector3.new(sx, 0, 117.2), Vector3.new(sx, 0, 90)), 16, 1, 1.8, 12)
	end
	for _, sx in { -178, 178 } do
		buildStair(parent, CFrame.lookAt(Vector3.new(sx, 0, -11.2), Vector3.new(sx, 0, 16)), 16, 1, 1.8, 12)
	end

	-- ---- the rooms ----
	for _, room in UPPER_ROOMS do
		local halfX, halfZ = room.size.X / 2, room.size.Y / 2
		tag(part({
			Name = room.name .. "Floor",
			Size = Vector3.new(room.size.X, 0.4, room.size.Y),
			-- 0.08, not 0.2. At 0.2 the carpet's underside sat exactly on the
			-- deck's top face and every upper room's floor fought the slab it
			-- was laid on -- eight rooms, two to three thousand square studs
			-- each. It is bedded INTO the deck now and still stands proud.
			CFrame = CFrame.new(room.center) * CFrame.new(0, 0.08, 0),
			Color = room.floor,
			Material = Enum.Material.Carpet,
			Parent = parent,
		}), "TexCarpet")

		-- the wall onto the hall, with the door in it, then the two sides
		local hallSide = if room.center.Z > 0 then -1 else 1
		local front = room.center.Z + hallSide * halfZ
		buildInteriorWall(
			parent,
			Vector3.new(room.center.X - halfX, UPPER_Y, front),
			Vector3.new(room.center.X + halfX, UPPER_Y, front),
			{ { at = halfX, width = 14 } }
		)
		for _, side in { -1, 1 } do
			buildInteriorWall(
				parent,
				Vector3.new(room.center.X + side * halfX, UPPER_Y, room.center.Z - halfZ),
				Vector3.new(room.center.X + side * halfX, UPPER_Y, room.center.Z + halfZ),
				{}
			)
		end

        -- The sign hangs over the door, out in the hall, double sided and lit.
		-- Finding a room should not require walking into it.
		local sign = part({
			Name = room.name .. "Sign",
			Size = Vector3.new(22, 4.4, 0.6),
			CFrame = CFrame.new(room.center.X, UPPER_Y + 12.6, front + hallSide * 2.4),
			Color = Palette.Blackboard,
			Parent = parent,
		})
		sign.CanCollide = false
		signText(sign, room.icon .. " " .. room.label, room.color, Enum.NormalId.Front)
		signText(sign, room.icon .. " " .. room.label, room.color, Enum.NormalId.Back)
		local glow = Instance.new("SurfaceLight")
		glow.Face = if hallSide < 0 then Enum.NormalId.Front else Enum.NormalId.Back
		glow.Range = 22
		glow.Brightness = 1.4
		glow.Color = room.color
		glow.Parent = sign
	end
end

-- ================= THE SUBJECT ROOMS =================
-- Five timetabled subjects, five rooms, and each one built around what
-- happens in it rather than being a box with desks in it. A player should be
-- able to stand in a doorway and know which lesson they walked into.
--
-- Room boxes, from the plan above:
--   Room 101 (Maths)     x -88..-60   z -124..-64
--   Music Room           x  60..88    z -124..-64
--   Greenhouse (Bio)     x -134..-98  z  -45..-11
--   East Lab (Chemistry) x  98..134   z  -45..-11
--   Gym                  x -50..50    z -146..-64

local function furnishSubjectRooms(parent: Instance)
	-- ---------------- Room 101: Mathematics ----------------
	do
		local cx = -74
		prop("OfficeDesk", CFrame.new(cx, 0, -116))
		prop("Laptop", CFrame.new(cx, 2.9, -116))
		prop("Notepads", CFrame.new(cx + 3.2, 2.9, -116))
		prop("Bookshelf", CFrame.new(-86, 0, -110) * CFrame.Angles(0, math.rad(90), 0))
		prop("SteelShelves2", CFrame.new(-86, 0, -76) * CFrame.Angles(0, math.rad(90), 0))
		prop("Bin", CFrame.new(-63, 0, -70))
		prop("Extinguisher", CFrame.new(-63, 0, -114))
		prop("PottedPlant", CFrame.new(-86, 0, -70))
		prop("Clock", CFrame.new(cx, 11, -120.4))

		-- the wall of shapes: a maths room says what it is with geometry
		local shapes = {
			{ shape = Enum.PartType.Cylinder, size = Vector3.new(0.6, 7, 7), color = Color3.fromRGB(228, 96, 88), z = -108 },
			{ shape = Enum.PartType.Block, size = Vector3.new(0.6, 6, 6), color = Color3.fromRGB(96, 160, 228), z = -98 },
			{ shape = Enum.PartType.Ball, size = Vector3.new(6, 6, 6), color = Color3.fromRGB(246, 200, 74), z = -88 },
		}
		for _, spec in shapes do
			local piece = part({
				Name = "MathShape",
				Shape = spec.shape,
				Size = spec.size,
				CFrame = CFrame.new(-87.2, 9, spec.z) * (spec.shape == Enum.PartType.Cylinder and CFrame.Angles(0, 0, 0) or CFrame.new()),
				Color = spec.color,
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			})
			piece.CanCollide = false
		end
		-- a number line down the east wall, which is the one thing every
		-- maths room in the world actually has
		for i = 0, 10 do
			local tile = part({
				Name = "NumberTile",
				Size = Vector3.new(0.4, 2.4, 2.4),
				CFrame = CFrame.new(-60.9, 10, -114 + i * 4.4),
				Color = i % 2 == 0 and Color3.fromRGB(244, 242, 236) or Color3.fromRGB(96, 160, 228),
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			})
			tile.CanCollide = false
			signText(tile, tostring(i), i % 2 == 0 and Color3.fromRGB(40, 44, 56) or Color3.fromRGB(255, 255, 255), Enum.NormalId.Left)
		end
		-- an abacus on a stand by the board
		local frame = part({ Name = "AbacusFrame", Size = Vector3.new(9, 7, 0.8), CFrame = CFrame.new(-66, 5.5, -119), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
		frame.CanCollide = false
		for row = 0, 3 do
			part({ Name = "AbacusRod", Size = Vector3.new(8, 0.2, 0.2), CFrame = CFrame.new(-66, 3.2 + row * 1.5, -118.6), Color = Color3.fromRGB(200, 196, 186), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			for bead = 0, 6 do
				local ball = part({
					Name = "AbacusBead",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.9, 0.9, 0.9),
					CFrame = CFrame.new(-69.4 + bead * 1.15, 3.2 + row * 1.5, -118.6),
					Color = row % 2 == 0 and Color3.fromRGB(228, 96, 88) or Color3.fromRGB(96, 160, 228),
					Parent = parent,
				})
				ball.CanCollide = false
			end
		end
	end

	-- ---------------- the Music Room ----------------
	do
		local cx = 74
		-- the piano sits east of centre: Maestro Quill stands at (74, -108),
		-- and the case used to close over him
		local px = cx + 7
		-- a grand piano: case, lid on its stick, keyboard, three legs, bench
		local case = part({ Name = "PianoCase", Size = Vector3.new(11, 3.2, 15), CFrame = CFrame.new(px, 4.2, -112), Color = Color3.fromRGB(22, 22, 26), Material = Enum.Material.SmoothPlastic, Parent = parent })
		local _ = case
		part({ Name = "PianoLid", Size = Vector3.new(11, 0.5, 15), CFrame = CFrame.new(px - 1.8, 7.4, -112) * CFrame.Angles(0, 0, math.rad(-22)), Color = Color3.fromRGB(28, 28, 34), Material = Enum.Material.SmoothPlastic, Parent = parent })
		part({ Name = "PianoStick", Size = Vector3.new(0.3, 4.4, 0.3), CFrame = CFrame.new(px + 4.6, 7.6, -108) * CFrame.Angles(math.rad(8), 0, 0), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.Wood, Parent = parent })
		for i = 0, 21 do
			part({ Name = "PianoKeyWhite", Size = Vector3.new(0.5, 0.4, 3.4), CFrame = CFrame.new(px - 5.4 + i * 0.52, 5.9, -104.4), Color = Color3.fromRGB(248, 246, 240), Material = Enum.Material.SmoothPlastic, Parent = parent }).CanCollide = false
			if i % 7 ~= 2 and i % 7 ~= 6 then
				part({ Name = "PianoKeyBlack", Size = Vector3.new(0.3, 0.5, 2.1), CFrame = CFrame.new(px - 5.15 + i * 0.52, 6.2, -105.1), Color = Color3.fromRGB(18, 18, 22), Material = Enum.Material.SmoothPlastic, Parent = parent }).CanCollide = false
			end
		end
		for _, leg in { { -4.4, -118 }, { 4.4, -118 }, { 0, -105 } } do
			part({ Name = "PianoLeg", Size = Vector3.new(0.9, 2.6, 0.9), CFrame = CFrame.new(px + leg[1], 1.3, leg[2]), Color = Color3.fromRGB(22, 22, 26), Material = Enum.Material.SmoothPlastic, Parent = parent })
		end
		part({ Name = "PianoBench", Size = Vector3.new(5, 0.6, 2), CFrame = CFrame.new(px, 2.6, -101), Color = Color3.fromRGB(60, 40, 34), Material = Enum.Material.Fabric, Parent = parent })
		for _, bx in { -2, 2 } do
			part({ Name = "PianoBenchLeg", Size = Vector3.new(0.4, 2.3, 1.6), CFrame = CFrame.new(px + bx, 1.15, -101), Color = Color3.fromRGB(22, 22, 26), Parent = parent })
		end

		-- risers, so a choir has somewhere to stand
		for step = 0, 2 do
			part({
				Name = "MusicRiser",
				Size = Vector3.new(24, 1.2 + step * 1.2, 5),
				CFrame = CFrame.new(cx, (1.2 + step * 1.2) / 2, -92 + step * 5),
				Color = Color3.fromRGB(96, 70, 54),
				Material = Enum.Material.WoodPlanks,
				Parent = parent,
			})
		end
		-- music stands in a row in front of them
		for i = 0, 5 do
			local sx = cx - 10 + i * 4
			part({ Name = "StandPole", Size = Vector3.new(0.25, 4.4, 0.25), CFrame = CFrame.new(sx, 2.2, -78), Color = Color3.fromRGB(40, 42, 48), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "StandTray", Size = Vector3.new(3, 0.2, 2.2), CFrame = CFrame.new(sx, 4.7, -78.4) * CFrame.Angles(math.rad(-58), 0, 0), Color = Color3.fromRGB(40, 42, 48), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "StandFoot", Size = Vector3.new(1.8, 0.2, 1.8), CFrame = CFrame.new(sx, 0.1, -78), Color = Color3.fromRGB(40, 42, 48), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		end
		-- a stave painted across the wall, with notes on it
		for line = 0, 4 do
			part({ Name = "StaveLine", Size = Vector3.new(0.3, 0.25, 24), CFrame = CFrame.new(88.8, 8 + line * 1.4, -96), Color = Color3.fromRGB(40, 44, 56), Parent = parent }).CanCollide = false
		end
		for i, note in { 0, 2, 1, 3, 2, 4 } do
			local head = part({ Name = "StaveNote", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(88.6, 8 + note * 1.4, -106 + i * 3.6), Color = Color3.fromRGB(40, 44, 56), Parent = parent })
			head.CanCollide = false
			part({ Name = "StaveStem", Size = Vector3.new(0.25, 4, 0.25), CFrame = CFrame.new(88.6, 10 + note * 1.4, -105.4 + i * 3.6), Color = Color3.fromRGB(40, 44, 56), Parent = parent }).CanCollide = false
		end
		prop("Bookshelf", CFrame.new(62, 0, -110) * CFrame.Angles(0, math.rad(-90), 0))
		prop("Boombox", CFrame.new(62.5, 3.2, -76) * CFrame.Angles(0, math.rad(-90), 0))
		prop("Bin", CFrame.new(63, 0, -70))
		prop("Clock", CFrame.new(cx, 11, -120.4))
	end

	-- ---------------- the East Lab: Chemistry ----------------
	do
		local cx, cz = 116, -28
		-- Three benches with black tops, a sink and a tap in each.
		--
		-- Thirteen wide, not twenty-six. The pavilion this room is built from
		-- already runs a bench down each side wall (x 100.5-105.5 and
		-- 126.5-131.5), so full-width cross benches met them at both ends and
		-- the three of them together sealed the middle of the lab into a pen
		-- with Dr. Fizzle inside it. Chemistry was a lesson you could not
		-- attend. Now there is a four-stud aisle down each side of the
		-- benches, which is what a lab looks like anyway.
		local BENCH_W = 13
		for row = 0, 2 do
			local bz = cz - 10 + row * 9
			part({ Name = "LabBench", Size = Vector3.new(BENCH_W, 3, 4), CFrame = CFrame.new(cx, 1.5, bz), Color = Color3.fromRGB(206, 202, 194), Material = Enum.Material.SmoothPlastic, Parent = parent })
			part({ Name = "LabBenchTop", Size = Vector3.new(BENCH_W + 1, 0.5, 5), CFrame = CFrame.new(cx, 3.2, bz), Color = Color3.fromRGB(34, 36, 42), Material = Enum.Material.Slate, Parent = parent })
			part({ Name = "LabSink", Size = Vector3.new(3.4, 0.4, 2.6), CFrame = CFrame.new(cx + 4.6, 3.3, bz), Color = Color3.fromRGB(180, 186, 192), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "LabTap", Size = Vector3.new(0.3, 2.2, 0.3), CFrame = CFrame.new(cx + 4.6, 4.5, bz - 1.4), Color = Color3.fromRGB(200, 206, 212), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			prop("BunsenBurner", CFrame.new(cx - 4.6, 3.5, bz))
			prop("BunsenBurner", CFrame.new(cx - 1.6, 3.5, bz))
			-- glassware: a flask and two beakers per bench
			local flask = part({ Name = "LabFlask", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(cx + 1, 4.4, bz), Color = Color3.fromRGB(196, 232, 240), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
			flask.CanCollide = false
			part({ Name = "LabFlaskNeck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 0.7, 0.7), CFrame = CFrame.new(cx + 1, 6, bz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(196, 232, 240), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent }).CanCollide = false
			for i, tint in { Color3.fromRGB(120, 230, 160), Color3.fromRGB(230, 140, 200) } do
				local beaker = part({ Name = "LabBeaker", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1.5, 1.5), CFrame = CFrame.new(cx + 1.4 + i * 1.6, 4.4, bz) * CFrame.Angles(0, 0, math.rad(90)), Color = tint, Material = Enum.Material.Glass, Transparency = 0.3, Parent = parent })
				beaker.CanCollide = false
			end
		end
		-- fume cupboard against the back wall
		part({ Name = "FumeHood", Size = Vector3.new(12, 10, 4), CFrame = CFrame.new(cx - 10, 5, cz - 14.4), Color = Color3.fromRGB(214, 216, 220), Material = Enum.Material.SmoothPlastic, Parent = parent })
		part({ Name = "FumeGlass", Size = Vector3.new(10.4, 4.6, 0.4), CFrame = CFrame.new(cx - 10, 6, cz - 12.3), Color = Color3.fromRGB(196, 232, 240), Material = Enum.Material.Glass, Transparency = 0.4, Parent = parent }).CanCollide = false
		-- the periodic table, as an actual grid of tiles
		for col = 0, 8 do
			for row = 0, 5 do
				local tile = part({
					Name = "ElementTile",
					Size = Vector3.new(2, 2, 0.3),
					CFrame = CFrame.new(cx + 5 + (col - 4) * 2.2, 12 - row * 2.2, cz - 16.6),
					Color = Color3.fromRGB(80 + col * 16, 150 + row * 12, 220 - col * 14),
					Material = Enum.Material.SmoothPlastic,
					Parent = parent,
				})
				tile.CanCollide = false
			end
		end
		-- safety kit, because a chemistry room without it reads as a kitchen
		part({ Name = "SafetyShowerPipe", Size = Vector3.new(0.4, 9, 0.4), CFrame = CFrame.new(cx + 15, 4.5, cz + 12), Color = Color3.fromRGB(206, 210, 214), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		part({ Name = "SafetyShowerHead", Size = Vector3.new(3, 0.4, 3), CFrame = CFrame.new(cx + 15, 9, cz + 12), Color = Color3.fromRGB(230, 178, 40), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		local hazard = part({ Name = "HazardSign", Size = Vector3.new(5, 5, 0.3), CFrame = CFrame.new(cx - 15, 9, cz - 16.6), Color = Color3.fromRGB(246, 200, 48), Parent = parent })
		hazard.CanCollide = false
		signText(hazard, "⚠", Color3.fromRGB(30, 30, 34), Enum.NormalId.Front)
		prop("Extinguisher", CFrame.new(cx + 16, 0, cz - 13))
		prop("Bin", CFrame.new(cx - 16, 0, cz + 13))
		prop("SteelShelves", CFrame.new(cx - 16, 0, cz) * CFrame.Angles(0, math.rad(90), 0))
	end

	-- ---------------- the Greenhouse: Biology, outdoors ----------------
	-- The brief for this one is "outdoor". It is a glasshouse, so the floor
	-- becomes ground and beds, not tile, and everything in it is alive.
	do
		local cx, cz = -116, -28
		tag(part({
			Name = "GreenhouseGround",
			Size = Vector3.new(34, 0.64, 32),
			-- 0.06 .. 0.70. The bed's TOP has to clear the quad lawn's top
			-- (0.40) and the quad path's (0.60), and its UNDERSIDE has to
			-- clear the lawn's (0.00) -- all three, or 1,088 square studs of
			-- glasshouse floor fights the grass round it. And the underside
			-- stays ABOVE zero: dropped below it, the bed swallowed the
			-- biology professor, who stands on this spot at y = 0.
			CFrame = CFrame.new(cx, 0.38, cz),
			Color = Color3.fromRGB(96, 148, 74),
			Material = Enum.Material.Grass,
			Parent = parent,
		}), "TexGround")
		-- a path through the middle so the beds are reachable
		part({ Name = "GreenhousePath", Size = Vector3.new(7, 0.3, 32), CFrame = CFrame.new(cx, 0.7, cz), Color = Color3.fromRGB(178, 162, 132), Material = Enum.Material.Sand, Parent = parent })

		-- raised beds down both sides, planted
		for _, side in { -1, 1 } do
			for row = 0, 2 do
				local bx = cx + side * 10
				local bz = cz - 10 + row * 10
				part({ Name = "BedFrame", Size = Vector3.new(9, 2, 8), CFrame = CFrame.new(bx, 1, bz), Color = Color3.fromRGB(126, 92, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
				part({ Name = "BedSoil", Size = Vector3.new(8, 0.6, 7), CFrame = CFrame.new(bx, 2.1, bz), Color = Color3.fromRGB(74, 54, 38), Material = Enum.Material.Ground, Parent = parent }).CanCollide = false
				prop("Fern", CFrame.new(bx - 2.2, 2.4, bz))
				prop("Flowers", CFrame.new(bx + 2.2, 2.4, bz - 1.6))
				prop("Shrub", CFrame.new(bx + side * 2.6, 2.4, bz + 1.8))
			end
		end

		-- a pond at the north end with lilies in it
		part({ Name = "PondRim", Size = Vector3.new(13, 1.8, 9), CFrame = CFrame.new(cx, 0.5, cz - 13), Color = Color3.fromRGB(140, 136, 126), Material = Enum.Material.Slate, Parent = parent })
		local water = part({ Name = "PondWater", Size = Vector3.new(11.4, 0.8, 7.4), CFrame = CFrame.new(cx, 1.1, cz - 13), Color = Color3.fromRGB(78, 140, 158), Material = Enum.Material.Glass, Transparency = 0.28, Parent = parent })
		water.CanCollide = false
		for i, spot in { { -3, -1 }, { 1, 1.6 }, { 3.4, -1.8 } } do
			local pad = part({ Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.6, 2.6), CFrame = CFrame.new(cx + spot[1], 1.6, cz - 13 + spot[2]) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(76, 150, 74), Material = Enum.Material.Grass, Parent = parent })
			pad.CanCollide = false
			if i == 2 then
				part({ Name = "LilyFlower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(cx + spot[1], 2.2, cz - 13 + spot[2]), Color = Color3.fromRGB(240, 180, 210), Parent = parent }).CanCollide = false
			end
		end

		-- a potting bench, and the tools that belong on it
		part({ Name = "PottingBench", Size = Vector3.new(10, 0.5, 3.4), CFrame = CFrame.new(cx, 3.2, cz + 13), Color = Color3.fromRGB(140, 104, 68), Material = Enum.Material.WoodPlanks, Parent = parent })
		for _, lx in { -4.4, 4.4 } do
			part({ Name = "PottingLeg", Size = Vector3.new(0.6, 3.2, 3), CFrame = CFrame.new(cx + lx, 1.6, cz + 13), Color = Color3.fromRGB(126, 92, 58), Material = Enum.Material.Wood, Parent = parent })
		end
		prop("SeedingTray", CFrame.new(cx - 3, 3.5, cz + 13))
		prop("WateringCanMetal", CFrame.new(cx + 1, 3.5, cz + 13))
		prop("GardenGloves", CFrame.new(cx + 3.4, 3.5, cz + 13))
		prop("PlanterPot", CFrame.new(cx - 14, 0.7, cz + 13))
		prop("PlanterBox", CFrame.new(cx + 14, 0.7, cz + 13))

		-- trellises up the glass, and a tree the roof is built around
		for _, side in { -1, 1 } do
			for i = 0, 5 do
				part({ Name = "Trellis", Size = Vector3.new(0.3, 12, 0.3), CFrame = CFrame.new(cx + side * 16, 6, cz - 12 + i * 5), Color = Color3.fromRGB(150, 116, 76), Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
			end
			for i = 0, 3 do
				part({ Name = "TrellisVine", Size = Vector3.new(0.5, 0.5, 30), CFrame = CFrame.new(cx + side * 15.7, 3 + i * 3, cz), Color = Color3.fromRGB(72, 128, 62), Material = Enum.Material.Grass, Parent = parent }).CanCollide = false
			end
		end
		part({ Name = "GreenhouseTrunk", Size = Vector3.new(2.4, 13, 2.4), CFrame = CFrame.new(cx, 6.5, cz + 6.5), Color = Color3.fromRGB(104, 78, 52), Material = Enum.Material.Wood, Parent = parent })
		for i = 0, 2 do
			part({
				Name = "GreenhouseCanopy",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(13 - i * 2.5, 7 - i, 13 - i * 2.5),
				CFrame = CFrame.new(cx, 12 + i * 2.4, cz + 6.5),
				Color = Color3.fromRGB(70 + i * 10, 132 + i * 12, 62),
				Material = Enum.Material.Grass,
				Parent = parent,
			}).CanCollide = false
		end
		-- hanging baskets from the ridge
		for _, hz in { cz - 6, cz + 8 } do
			part({ Name = "BasketChain", Size = Vector3.new(0.2, 4, 0.2), CFrame = CFrame.new(cx - 6, 15, hz), Color = Color3.fromRGB(180, 176, 168), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "HangingBasket", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 3, 4), CFrame = CFrame.new(cx - 6, 12.4, hz), Color = Color3.fromRGB(86, 148, 70), Material = Enum.Material.Grass, Parent = parent }).CanCollide = false
		end
	end

	-- ---------------- the Gym ----------------
	do
		-- bleachers down both flanks
		for _, side in { -1, 1 } do
			for tier = 0, 3 do
				part({
					Name = "Bleacher",
					Size = Vector3.new(4, 2.4 + tier * 2.4, 60),
					CFrame = CFrame.new(side * (46 - tier * 4), (2.4 + tier * 2.4) / 2, -100),
					Color = tier % 2 == 0 and Color3.fromRGB(146, 100, 62) or Color3.fromRGB(122, 84, 52),
					Material = Enum.Material.WoodPlanks,
					Parent = parent,
				})
			end
		end
		-- a scoreboard on the north wall
		local board = part({ Name = "Scoreboard", Size = Vector3.new(26, 12, 1.2), CFrame = CFrame.new(0, 20, -143.4), Color = Color3.fromRGB(24, 26, 32), Parent = parent })
		board.CanCollide = false
		-- Back, which is +Z: this hangs on the gym's NORTH wall, so it has to read
		-- south into the hall. Front pointed it into the facade behind it.
		signText(board, "HOME  00 : 00  AWAY", Color3.fromRGB(255, 96, 72), Enum.NormalId.Back)
		local glow = Instance.new("SurfaceLight")
		glow.Face = Enum.NormalId.Front
		glow.Range = 30
		glow.Brightness = 1.2
		glow.Color = Color3.fromRGB(255, 120, 90)
		glow.Parent = board
		-- climbing ropes and wall bars, the two things every gym has
		for _, rx in { -30, -18, 18, 30 } do
			part({ Name = "ClimbRope", Size = Vector3.new(0.5, 22, 0.5), CFrame = CFrame.new(rx, 13, -132), Color = Color3.fromRGB(206, 184, 140), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
		end
		for bar = 0, 7 do
			part({ Name = "WallBar", Size = Vector3.new(0.8, 0.8, 14), CFrame = CFrame.new(-49, 3 + bar * 2.2, -76), Color = Color3.fromRGB(196, 158, 104), Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
		end
		-- banners for the houses
		for i, tint in {
			Color3.fromRGB(214, 72, 64), Color3.fromRGB(72, 128, 214),
			Color3.fromRGB(238, 190, 60), Color3.fromRGB(84, 178, 108),
		} do
			part({
				Name = "GymBanner",
				Size = Vector3.new(0.4, 14, 7),
				CFrame = CFrame.new(49, 22, -126 + (i - 1) * 12),
				Color = tint,
				Material = Enum.Material.Fabric,
				Parent = parent,
			}).CanCollide = false
		end
		prop("Football", CFrame.new(-22, 0, -98))
		prop("AmericanFootball", CFrame.new(14, 0, -112))
		prop("Baseball", CFrame.new(4, 0, -90))
	end
end


-- Each upper room dressed for what it is. The rule is the same as downstairs:
-- one strong idea per room, built rather than labelled, so you know where you
-- are the moment you step through the door.
local function furnishUpperRooms(parent: Instance)
	local Y = 16

	-- ---- Art (-190, 103) ----
	for i = 0, 4 do
		local ex = -206 + i * 8
		part({ Name = "EaselLeg", Size = Vector3.new(0.4, 7, 0.4), CFrame = CFrame.new(ex, Y + 3.5, 96) * CFrame.Angles(math.rad(-10), 0, 0), Color = Color3.fromRGB(150, 116, 76), Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
		part({ Name = "EaselCanvas", Size = Vector3.new(5, 5.4, 0.3), CFrame = CFrame.new(ex, Y + 6, 95.4) * CFrame.Angles(math.rad(-10), 0, 0), Color = Color3.fromRGB(248, 246, 238), Parent = parent }).CanCollide = false
		part({ Name = "EaselTray", Size = Vector3.new(5.4, 0.3, 1.2), CFrame = CFrame.new(ex, Y + 3.1, 95.8), Color = Color3.fromRGB(150, 116, 76), Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
	end
	-- a colour wheel on the back wall
	for i = 0, 11 do
		local angle = i * math.pi / 6
		part({
			Name = "ColourChip",
			Size = Vector3.new(3.4, 3.4, 0.3),
			CFrame = CFrame.new(-190 + math.cos(angle) * 7, Y + 12 + math.sin(angle) * 7, 121.4) * CFrame.Angles(0, 0, angle),
			Color = Color3.fromHSV(i / 12, 0.72, 0.95),
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}).CanCollide = false
	end
	prop("Table", CFrame.new(-198, Y, 110))
	prop("Table", CFrame.new(-182, Y, 110))
	prop("Chair", CFrame.new(-198, Y, 114) * CFrame.Angles(0, math.pi, 0))
	prop("Chair", CFrame.new(-182, Y, 114) * CFrame.Angles(0, math.pi, 0))
	prop("Vase1", CFrame.new(-198, Y + 2.1, 110))
	prop("Bin", CFrame.new(-206, Y, 90))
	prop("SteelShelves2", CFrame.new(-212, Y, 100) * CFrame.Angles(0, math.rad(90), 0))

	-- ---- History (-122, 103) ----
	-- a timeline down the back wall, and cases under it
	for i = 0, 7 do
		local tx = -144 + i * 6.4
		part({ Name = "TimelineBar", Size = Vector3.new(6.4, 0.4, 0.3), CFrame = CFrame.new(tx, Y + 12, 121.4), Color = Color3.fromRGB(212, 178, 96), Parent = parent }).CanCollide = false
		part({ Name = "TimelinePin", Size = Vector3.new(3.4, 4.2, 0.3), CFrame = CFrame.new(tx, Y + (i % 2 == 0 and 15 or 9), 121.4), Color = Color3.fromRGB(228, 220, 196), Parent = parent }).CanCollide = false
	end
	for _, dx in { -136, -122, -108 } do
		part({ Name = "DisplayCase", Size = Vector3.new(8, 6, 4), CFrame = CFrame.new(dx, Y + 3, 116), Color = Color3.fromRGB(92, 62, 44), Material = Enum.Material.WoodPlanks, Parent = parent })
		part({ Name = "DisplayGlass", Size = Vector3.new(7.4, 4.4, 3.6), CFrame = CFrame.new(dx, Y + 4, 116), Color = Color3.fromRGB(206, 232, 240), Material = Enum.Material.Glass, Transparency = 0.55, Parent = parent }).CanCollide = false
	end
	prop("GrandfatherClock", CFrame.new(-146, Y, 108) * CFrame.Angles(0, math.rad(90), 0))
	prop("Table", CFrame.new(-122, Y, 98))
	prop("Chair2", CFrame.new(-128, Y, 98) * CFrame.Angles(0, math.rad(90), 0))
	prop("Chair2", CFrame.new(-116, Y, 98) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Bookshelf", CFrame.new(-98, Y, 108) * CFrame.Angles(0, math.rad(-90), 0))

	-- ---- Computer Lab (122, 103) ----
	for row = 0, 1 do
		for col = 0, 4 do
			local mx = 106 + col * 8
			local mz = 96 + row * 12
			part({ Name = "LabDesk", Size = Vector3.new(7, 0.4, 4), CFrame = CFrame.new(mx, Y + 2.8, mz), Color = Color3.fromRGB(58, 62, 70), Material = Enum.Material.SmoothPlastic, Parent = parent })
			for _, lx in { -3, 3 } do
				part({ Name = "LabDeskLeg", Size = Vector3.new(0.3, 2.8, 3.4), CFrame = CFrame.new(mx + lx, Y + 1.4, mz), Color = Color3.fromRGB(80, 84, 92), Material = Enum.Material.Metal, Parent = parent })
			end
			part({ Name = "MonitorStand", Size = Vector3.new(0.5, 1.4, 0.5), CFrame = CFrame.new(mx, Y + 3.7, mz - 1), Color = Color3.fromRGB(40, 42, 48), Parent = parent }).CanCollide = false
			local screen = part({ Name = "Monitor", Size = Vector3.new(5, 3, 0.4), CFrame = CFrame.new(mx, Y + 5.9, mz - 1), Color = Color3.fromRGB(28, 30, 36), Parent = parent })
			screen.CanCollide = false
			part({ Name = "MonitorGlow", Size = Vector3.new(4.4, 2.4, 0.15), CFrame = CFrame.new(mx, Y + 5.9, mz - 1.25), Color = Color3.fromRGB(96, 172, 226), Material = Enum.Material.Neon, Parent = parent }).CanCollide = false
			part({ Name = "Keyboard", Size = Vector3.new(3.4, 0.2, 1.2), CFrame = CFrame.new(mx, Y + 3.1, mz + 0.8), Color = Color3.fromRGB(226, 224, 218), Parent = parent }).CanCollide = false
			prop("SchoolChair", CFrame.new(mx, Y, mz + 4) * CFrame.Angles(0, math.pi, 0))
		end
	end
	prop("OfficeDesk", CFrame.new(122, Y, 118))
	prop("Laptop", CFrame.new(122, Y + 2.9, 118))
	prop("Bin", CFrame.new(100, Y, 118))

	-- ---- Languages (190, 103) ----
	for i = 0, 5 do
		local bx = 172 + i * 7
		part({ Name = "LangBooth", Size = Vector3.new(6, 5, 5), CFrame = CFrame.new(bx, Y + 2.5, 112), Color = Color3.fromRGB(210, 214, 220), Material = Enum.Material.SmoothPlastic, Parent = parent })
		part({ Name = "LangDesk", Size = Vector3.new(6, 0.4, 4), CFrame = CFrame.new(bx, Y + 2.8, 108), Color = Color3.fromRGB(178, 150, 112), Material = Enum.Material.WoodPlanks, Parent = parent })
		prop("SchoolChair", CFrame.new(bx, Y, 104) * CFrame.Angles(0, math.pi, 0))
	end
	for i, tint in {
		Color3.fromRGB(214, 72, 64), Color3.fromRGB(72, 128, 214), Color3.fromRGB(238, 190, 60),
		Color3.fromRGB(84, 178, 108), Color3.fromRGB(226, 226, 230), Color3.fromRGB(150, 100, 200),
	} do
		part({ Name = "LangFlag", Size = Vector3.new(6, 4, 0.3), CFrame = CFrame.new(172 + (i - 1) * 7, Y + 13, 121.4), Color = tint, Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
	end
	prop("OfficeDesk", CFrame.new(190, Y, 90))
	prop("Bin", CFrame.new(168, Y, 90))

	-- ---- Study Hall (-190, -94) ----
	for row = 0, 2 do
		local tz = -110 + row * 14
		prop("Table", CFrame.new(-198, Y, tz))
		prop("Table", CFrame.new(-182, Y, tz))
		for _, cx in { -198, -182 } do
			prop("Chair", CFrame.new(cx, Y, tz - 4))
			prop("Chair", CFrame.new(cx, Y, tz + 4) * CFrame.Angles(0, math.pi, 0))
		end
	end
	prop("SteelShelves", CFrame.new(-212, Y, -100) * CFrame.Angles(0, math.rad(90), 0))
	prop("Bookshelf", CFrame.new(-168, Y, -100) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Clock", CFrame.new(-190, Y + 11, -119.4))
	prop("Bin", CFrame.new(-212, Y, -74))

	-- ---- Drama (-122, -94) ----
	part({ Name = "DramaStage", Size = Vector3.new(34, 3, 16), CFrame = CFrame.new(-122, Y + 1.5, -110), Color = Color3.fromRGB(88, 62, 44), Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "DramaCurtain", Size = Vector3.new(7, 18, 1.2), CFrame = CFrame.new(-122 + side * 15, Y + 12, -102), Color = Color3.fromRGB(140, 26, 42), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
	end
	part({ Name = "DramaPelmet", Size = Vector3.new(36, 4, 1.6), CFrame = CFrame.new(-122, Y + 19.2, -102.3), Color = Color3.fromRGB(140, 26, 42), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
	for _, lx in { -10, 0, 10 } do
		local can = part({ Name = "Spotlight", Size = Vector3.new(2, 2, 3), CFrame = CFrame.new(-122 + lx, Y + 18, -94) * CFrame.Angles(math.rad(35), 0, 0), Color = Color3.fromRGB(34, 36, 42), Material = Enum.Material.Metal, Parent = parent })
		can.CanCollide = false
		local beam = Instance.new("SpotLight")
		beam.Angle = 50
		beam.Range = 40
		beam.Brightness = 2
		beam.Color = Color3.fromRGB(255, 236, 200)
		beam.Face = Enum.NormalId.Front
		beam.Parent = can
	end
	for i, tint in { Color3.fromRGB(240, 226, 190), Color3.fromRGB(60, 62, 70) } do
		part({ Name = "DramaMask", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 6, 2), CFrame = CFrame.new(-134 + (i - 1) * 24, Y + 13, -119.4), Color = tint, Parent = parent }).CanCollide = false
	end
	for i = 0, 5 do
		prop("MonoblocChair", CFrame.new(-134 + i * 5, Y, -80) * CFrame.Angles(0, math.rad(4 * i), 0))
	end

	-- ---- Nurse (122, -94) ----
	for i = 0, 2 do
		local bz = -112 + i * 12
		part({ Name = "WardBed", Size = Vector3.new(6, 2.4, 12), CFrame = CFrame.new(104, Y + 1.2, bz), Color = Color3.fromRGB(232, 236, 240), Material = Enum.Material.SmoothPlastic, Parent = parent })
		part({ Name = "WardMattress", Size = Vector3.new(5.4, 1, 11), CFrame = CFrame.new(104, Y + 2.7, bz), Color = Color3.fromRGB(206, 226, 232), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
		part({ Name = "WardPillow", Size = Vector3.new(4.4, 0.9, 2.6), CFrame = CFrame.new(104, Y + 3.5, bz - 4), Color = Color3.fromRGB(248, 248, 246), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
		part({ Name = "WardScreen", Size = Vector3.new(0.4, 9, 11), CFrame = CFrame.new(109, Y + 4.5, bz), Color = Color3.fromRGB(180, 214, 210), Material = Enum.Material.Fabric, Parent = parent })
	end
	local cross = part({ Name = "NurseCross", Size = Vector3.new(8, 2.4, 0.4), CFrame = CFrame.new(122, Y + 13, -119.4), Color = Color3.fromRGB(226, 68, 68), Material = Enum.Material.Neon, Parent = parent })
	cross.CanCollide = false
	part({ Name = "NurseCross", Size = Vector3.new(2.4, 8, 0.4), CFrame = CFrame.new(122, Y + 13, -119.4), Color = Color3.fromRGB(226, 68, 68), Material = Enum.Material.Neon, Parent = parent }).CanCollide = false
	prop("OfficeDesk", CFrame.new(136, Y, -110))
	prop("SchoolChair", CFrame.new(136, Y, -104) * CFrame.Angles(0, math.pi, 0))
	prop("SteelShelves2", CFrame.new(144, Y, -96) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Bin", CFrame.new(144, Y, -74))
	prop("PottedPlant", CFrame.new(104, Y, -74))

	-- ---- Common Room (190, -94) ----
	prop("Sofa", CFrame.new(176, Y, -110) * CFrame.Angles(0, math.rad(90), 0))
	prop("Sofa2", CFrame.new(190, Y, -116))
	prop("CoffeeTable", CFrame.new(183, Y, -110))
	prop("ArmChair", CFrame.new(190, Y, -104) * CFrame.Angles(0, math.pi, 0))
	prop("Table", CFrame.new(202, Y, -88))
	prop("Chair", CFrame.new(202, Y, -84) * CFrame.Angles(0, math.pi, 0))
	prop("VintageMicrowave", CFrame.new(210, Y + 3.4, -100) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Boombox", CFrame.new(210, Y + 3.4, -94) * CFrame.Angles(0, math.rad(-90), 0))
	part({ Name = "CommonCounter", Size = Vector3.new(5, 3.2, 22), CFrame = CFrame.new(211, Y + 1.6, -97), Color = Color3.fromRGB(150, 116, 82), Material = Enum.Material.WoodPlanks, Parent = parent })
	-- cubbies, one per homeroom
	for row = 0, 3 do
		for col = 0, 5 do
			part({
				Name = "Cubby",
				Size = Vector3.new(0.6, 2.4, 3.4),
				CFrame = CFrame.new(165.2, Y + 4 + row * 2.6, -108 + col * 3.6),
				Color = row % 2 == col % 2 and Color3.fromRGB(206, 200, 188) or Color3.fromRGB(178, 170, 158),
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			}).CanCollide = false
		end
	end
	prop("Bin", CFrame.new(168, Y, -74))
	prop("Clock", CFrame.new(190, Y + 11, -119.4))
end


-- ================= THE TEACHERS' QUARTERS =================
-- Every professor in the timetable stands in a classroom all day and then
-- stands in it all night. They live here now: a lodge off the west path with
-- a common room downstairs and a study apiece above it, in the same brick as
-- the school so it reads as part of the campus rather than a prop dropped
-- next to it.
--
-- Students can walk in. That is the point -- a staff room you can be caught in
-- is worth more than one you cannot enter.
local TEACHERS = {
	{ name = "MR. TANGENT", subject = "Mathematics", color = Color3.fromRGB(120, 176, 255) },
	{ name = "DR. FIZZLE", subject = "Chemistry", color = Color3.fromRGB(150, 240, 190) },
	{ name = "MS. FERN", subject = "Biology", color = Color3.fromRGB(150, 220, 130) },
	{ name = "MAESTRO QUILL", subject = "Music", color = Color3.fromRGB(212, 160, 240) },
	{ name = "COACH BRICKER", subject = "Gym", color = Color3.fromRGB(255, 176, 88) },
}

-- A globe, built rather than imported: no CC0 scan of one exists, and a bare
-- sphere on a stick is the sort of stand-in this pass is meant to get rid of.
-- Eight pieces -- foot, stem, cradle, tilted axis, the sphere, a meridian ring
-- in two halves, and the north pin -- with the axis raked over at the 23.4
-- degrees a globe actually sits at, which is most of what makes one readable
-- from across a room.
local function buildGlobe(parent: Instance, at: CFrame)
	local BRASS = Color3.fromRGB(178, 142, 78)
	local TIMBER = Color3.fromRGB(107, 74, 46)
	local OCEAN = Color3.fromRGB(96, 138, 178)
	local tilt = at * CFrame.Angles(0, 0, math.rad(23.4))

	part({ Name = "GlobeFoot", Size = Vector3.new(2.2, 0.24, 2.2), CFrame = at * CFrame.new(0, 0.12, 0), Color = TIMBER, Material = Enum.Material.WoodPlanks, Shape = Enum.PartType.Cylinder, Parent = parent })
	part({ Name = "GlobeFootBead", Size = Vector3.new(1.9, 0.18, 1.9), CFrame = at * CFrame.new(0, 0.33, 0), Color = TIMBER, Material = Enum.Material.WoodPlanks, Shape = Enum.PartType.Cylinder, Parent = parent })
	part({ Name = "GlobeStem", Size = Vector3.new(0.3, 0.9, 0.3), CFrame = at * CFrame.new(0, 0.87, 0), Color = BRASS, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "GlobeCradle", Size = Vector3.new(1.5, 0.16, 0.3), CFrame = at * CFrame.new(0, 1.36, 0), Color = BRASS, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "GlobeAxis", Size = Vector3.new(0.14, 2.5, 0.14), CFrame = tilt * CFrame.new(0, 1.5, 0), Color = BRASS, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "GlobeSphere", Size = Vector3.new(1.9, 1.9, 1.9), CFrame = tilt * CFrame.new(0, 1.5, 0), Color = OCEAN, Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Ball, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "GlobeMeridian", Size = Vector3.new(0.12, 2.15, 0.12), CFrame = tilt * CFrame.new(side * 1.06, 1.5, 0), Color = BRASS, Material = Enum.Material.Metal, Parent = parent })
	end
	part({ Name = "GlobePin", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = tilt * CFrame.new(0, 2.78, 0), Color = BRASS, Material = Enum.Material.Metal, Shape = Enum.PartType.Ball, Parent = parent })
end

local function buildTeachersQuarters(parent: Instance, center: Vector3)
	local W, D = 84, 64
	local halfW, halfD = W / 2, D / 2
	-- Three storeys now: common room, the teachers' studies, and above them
	-- the whole top floor as one room -- the headmaster's office. It is the
	-- grandest room on the campus on purpose, because it is the one with the
	-- door in it.
	-- Storeys are sixteen studs apart: common room at y = 3, the studies at
	-- 19, the headmaster's office at 35 with a twenty-stud ceiling over it.
	local GROUND, UPPER, RIDGE = 16, 32, 56
	local OFFICE_FLOOR = UPPER + 3
	local BRICK = Color3.fromRGB(138, 128, 114)
	local STONE = Color3.fromRGB(206, 200, 188)

	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(center + Vector3.new(x, y, z))
	end

	-- ---- ground, plinth, floors ----
	-- The plinth, with a notch cut in its east edge for the turret. It used to
	-- run the full 92 studs and the spiral inside the turret was driven
	-- straight through it: two solid studs of stone across the descent, six
	-- studs down from the top.
	for _, rect in {
		{ -(W + 8) / 2, -(D + 8) / 2, (W + 8) / 2, -29 },
		{ -(W + 8) / 2, -3, (W + 8) / 2, (D + 8) / 2 },
		{ -(W + 8) / 2, -29, 38, -3 },
	} do
		local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
		tag(part({ Name = "QuartersPlinth", Size = Vector3.new(x1 - x0, 2, z1 - z0), CFrame = at((x0 + x1) / 2, 1, (z0 + z1) / 2), Color = STONE, Material = Enum.Material.Concrete, Parent = parent }), "TexBlueStone")
	end
	tag(part({ Name = "QuartersFloor", Size = Vector3.new(W, 1, D), CFrame = at(0, 2.5, 0), Color = Color3.fromRGB(150, 110, 78), Material = Enum.Material.WoodPlanks, Parent = parent }), "TexWood")
	-- the upper deck, with a well over the common room so the fire is visible
	-- from the landing -- and a SECOND well over the east bay, because that is
	-- where the stair is. The deck used to run straight over the top of the
	-- flight: you climbed four treads and hit the underside of the floor you
	-- were climbing to, which is why nobody could get upstairs here.
	for _, rect in {
		{ -halfW, -halfD, halfW, -14 },
		{ -halfW, -14, -16, 14 },
		{ 16, -14, 24, 14 },
		{ 38, -14, halfW, 14 },
		{ 24, -14, 38, -6 },
		{ 24, 10, 38, 14 },
		{ -halfW, 14, 24, halfD },
		{ 38, 14, halfW, halfD },
		{ 24, 14, 38, halfD },
	} do
		local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
		tag(part({ Name = "QuartersUpperFloor", Size = Vector3.new(x1 - x0, 1, z1 - z0), CFrame = at((x0 + x1) / 2, GROUND + 2.5, (z0 + z1) / 2), Color = Color3.fromRGB(150, 110, 78), Material = Enum.Material.WoodPlanks, Parent = parent }), "TexWood")
		tag(part({ Name = "QuartersSoffit", Size = Vector3.new(x1 - x0, 0.6, z1 - z0), CFrame = at((x0 + x1) / 2, GROUND + 1.82, (z0 + z1) / 2), Color = Color3.fromRGB(238, 234, 224), Parent = parent }), "TexCeiling")
	end
	-- railing round both wells -- the light well over the fire, and the
	-- stairwell. The stairwell is left open on its south edge, which is where
	-- the top tread lands.
	for _, rail in {
		{ -16, -14, 16, -14 }, { -16, 14, 16, 14 },
		{ -16, -14, -16, 14 }, { 16, -14, 16, 14 },
		{ 24, -6, 24, 10 }, { 38, -6, 38, 10 }, { 24, 10, 38, 10 },
	} do
		buildRailing(parent, center + Vector3.new(rail[1], GROUND + 3, rail[2]), center + Vector3.new(rail[3], GROUND + 3, rail[4]))
	end

	-- ---- shell: brick with punched windows, doors on the campus side ----
	local function wall(name: string, size: Vector3, offset: Vector3)
		tag(part({ Name = name, Size = size, CFrame = at(offset.X, offset.Y, offset.Z), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
	end
	local SHELL = 53 -- brick from the plinth at y = 3 to the eaves at 56
	wall("QuartersWallN", Vector3.new(W, SHELL, 2), Vector3.new(0, SHELL / 2 + 3, -halfD))
	wall("QuartersWallW", Vector3.new(2, SHELL, D), Vector3.new(-halfW, SHELL / 2 + 3, 0))
	wall("QuartersWallS", Vector3.new(W, SHELL, 2), Vector3.new(0, SHELL / 2 + 3, halfD))
	-- east face: two piers and a lintel, the gap between them is the way in
	for _, sz in { -1, 1 } do
		wall("QuartersWallE", Vector3.new(2, SHELL, halfD - 7), Vector3.new(halfW, SHELL / 2 + 3, sz * (halfD / 2 + 3.5)))
	end
	wall("QuartersWallE", Vector3.new(2, SHELL - 14, 14), Vector3.new(halfW, SHELL / 2 + 10, 0))
	for _, sz in { -7, 7 } do
		part({ Name = "QuartersDoorPost", Size = Vector3.new(3, 14, 2.4), CFrame = at(halfW, 10, sz), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
	end

	-- Windows: three rows of six on each long face, standing PROUD of the
	-- brick. They used to be a frame two and a half studs deep centred on a
	-- two-stud wall -- a third of a stud of relief either side -- which from
	-- any distance is a window painted on a wall. Fifty-three studs of brick
	-- with painted-on windows is why this building read as a warehouse.
	--
	-- A surround an inch off the face, a sill under it, and a mullion across
	-- the middle: three cheap parts that turn a rectangle into an opening.
	for _, sz in { -1, 1 } do
		for i = 0, 5 do
			for _, wy in { 11, 26, 43 } do
				local wx = -32 + i * 13
				-- The wall is two studs thick centred on halfD, so its face is
				-- at halfD + 1. Glass at +0.6 was INSIDE the brick, and the
				-- lit pane behind it at +0.1 was deeper still: both fought the
				-- wall for the same pixels and the windows came out as noise.
				local face = sz * (halfD + 1.45)
				-- A FRAME, four bars round the opening -- not a slab. A solid
				-- nine-by-eleven sheet of concrete standing an inch in front
				-- of the glass is a blank grey rectangle, and eighteen of them
				-- a side is worse than no windows at all.
				local bars: { { w: number, h: number, dx: number, dy: number } } = {
					{ w = 9.6, h = 1.1, dx = 0, dy = 4.75 },
					{ w = 9.6, h = 1.1, dx = 0, dy = -4.75 },
					{ w = 1.1, h = 10.6, dx = -4.25, dy = 0 },
					{ w = 1.1, h = 10.6, dx = 4.25, dy = 0 },
				}
				for _, bar in bars do
					part({
						Name = "QuartersWinReveal",
						Size = Vector3.new(bar.w, bar.h, 1.2),
						CFrame = at(wx + bar.dx, wy + bar.dy, face),
						Color = Color3.fromRGB(238, 236, 228),
						Material = Enum.Material.Concrete,
						Parent = parent,
					}).CanCollide = false
				end
				local glass = part({ Name = "QuartersWindow", Size = Vector3.new(7.4, 8.4, 0.3), CFrame = at(wx, wy, sz * (halfD + 1.3)), Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
				glass.CanCollide = false
				tag(glass, "TexWindow")
				part({ Name = "QuartersWinMullion", Size = Vector3.new(0.7, 8.4, 1.5), CFrame = at(wx, wy, face), Color = Color3.fromRGB(238, 236, 228), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
				part({ Name = "QuartersWinTransom", Size = Vector3.new(7.4, 0.7, 1.5), CFrame = at(wx, wy + 1.4, face), Color = Color3.fromRGB(238, 236, 228), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
				part({ Name = "QuartersWinSill", Size = Vector3.new(11.2, 1, 2.6), CFrame = at(wx, wy - 5.8, sz * (halfD + 1.7)), Color = Color3.fromRGB(224, 218, 204), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
				-- a lit pane behind the glass on the lower two storeys, so the
				-- building reads as occupied from the campus
				if wy < 40 then
					local warm = part({ Name = "QuartersWinGlow", Size = Vector3.new(6.6, 7.6, 0.3), CFrame = at(wx, wy, sz * (halfD + 1.06)), Color = Color3.fromRGB(255, 226, 176), Material = Enum.Material.Neon, Transparency = 0.35, Parent = parent })
					warm.CanCollide = false
				end
			end
		end
	end

	-- ---- the roof ----
	-- Seven concentric slabs stacked one on the next is a ziggurat, not a
	-- roof, and it sat on top of a fifty-three stud brick box with nothing on
	-- it. This is a real pitch: two slate planes to a ridge, stepped gable
	-- ends, a course of dormers on the campus side and two stacks with pots.
	local RIDGE_TOP = RIDGE + 22
	local slope = math.sqrt(halfD * halfD + (RIDGE_TOP - RIDGE) * (RIDGE_TOP - RIDGE))
	local pitch = math.atan2(RIDGE_TOP - RIDGE, halfD)
	for _, side in { -1, 1 } do
		tag(part({
			Name = "QuartersRoof",
			Size = Vector3.new(W + 10, 2, slope + 4),
			CFrame = at(0, (RIDGE + RIDGE_TOP) / 2, side * halfD / 2) * CFrame.Angles(side * pitch, 0, 0),
			Color = Color3.fromRGB(84, 92, 102),
			Material = Enum.Material.Slate,
			Parent = parent,
		}), "TexSlateRoof")
	end
	part({ Name = "QuartersRidge", Size = Vector3.new(W + 11, 1.8, 3), CFrame = at(0, RIDGE_TOP + 0.6, 0), Color = Color3.fromRGB(64, 72, 82), Material = Enum.Material.Slate, Parent = parent }).CanCollide = false
	-- eaves board, which is what stops a roof reading as a lid
	for _, side in { -1, 1 } do
		part({ Name = "QuartersEaves", Size = Vector3.new(W + 12, 2.2, 1.4), CFrame = at(0, RIDGE - 1, side * (halfD + 4.4)), Color = Color3.fromRGB(232, 226, 214), Material = Enum.Material.WoodPlanks, Parent = parent }).CanCollide = false
	end
	for _, side in { -1, 1 } do
		for step = 0, 6 do
			local inset = (step + 0.5) * (halfD / 7)
			wall("QuartersGable", Vector3.new(2, (RIDGE_TOP - RIDGE) / 7 + 1.4, halfD * 2 - inset * 2),
				Vector3.new(side * halfW, RIDGE + (step + 0.5) * ((RIDGE_TOP - RIDGE) / 7), 0))
		end
	end
	-- dormers, on the side the campus is
	for _, dx in { -28, -9, 9, 28 } do
		part({ Name = "QuartersDormer", Size = Vector3.new(10, 9, 11), CFrame = at(dx, RIDGE + 3, halfD - 8), Color = Color3.fromRGB(232, 226, 214), Material = Enum.Material.WoodPlanks, Parent = parent })
		local pane = part({ Name = "QuartersDormerGlass", Size = Vector3.new(6.6, 5.6, 0.5), CFrame = at(dx, RIDGE + 3.2, halfD - 2.6), Color = Color3.fromRGB(255, 226, 176), Material = Enum.Material.Neon, Parent = parent })
		pane.CanCollide = false
		local warm = Instance.new("PointLight")
		warm.Brightness = 1.4
		warm.Range = 26
		warm.Color = Color3.fromRGB(255, 208, 150)
		warm.Parent = pane
		for _, side in { -1, 1 } do
			part({ Name = "QuartersDormerRoof", Size = Vector3.new(7, 1.1, 11.4), CFrame = at(dx + side * 2.7, RIDGE + 8.6, halfD - 8) * CFrame.Angles(0, 0, math.rad(-side * 34)), Color = Color3.fromRGB(84, 92, 102), Material = Enum.Material.Slate, Parent = parent }).CanCollide = false
		end
	end
	-- two stacks, with pots
	for _, cx in { -halfW + 10, halfW - 10 } do
		tag(part({ Name = "QuartersChimney", Size = Vector3.new(10, 40, 10), CFrame = at(cx, RIDGE_TOP - 8, -10), Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
		part({ Name = "QuartersChimneyCap", Size = Vector3.new(12, 1.6, 12), CFrame = at(cx, RIDGE_TOP + 12.8, -10), Color = Color3.fromRGB(214, 208, 196), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
		for _, px in { -2.6, 2.6 } do
			part({ Name = "QuartersChimneyPot", Size = Vector3.new(2.4, 4, 2.4), CFrame = at(cx + px, RIDGE_TOP + 15.6, -10), Color = Color3.fromRGB(178, 108, 78), Material = Enum.Material.Slate, Parent = parent }).CanCollide = false
		end
	end

	-- ---- a string course between the storeys, and quoins at the corners ----
	-- Fifty-three studs of unbroken brick is a warehouse. Two bands and a run
	-- of stone at each corner is what turns it into a building with floors.
	for _, band in { GROUND + 3, UPPER + 3 } do
		part({ Name = "QuartersBand", Size = Vector3.new(W + 3, 1.6, D + 3), CFrame = at(0, band, 0), Color = Color3.fromRGB(226, 220, 206), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
	end
	for _, corner in { Vector3.new(-halfW, 0, -halfD), Vector3.new(halfW, 0, -halfD), Vector3.new(-halfW, 0, halfD), Vector3.new(halfW, 0, halfD) } do
		for course = 0, 12 do
			local wide = if course % 2 == 0 then 5.2 else 3.4
			part({ Name = "QuartersQuoin", Size = Vector3.new(wide, 4, wide), CFrame = at(corner.X, 5 + course * 4, corner.Z), Color = Color3.fromRGB(222, 216, 202), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
		end
	end

	-- ---- the porch over the east door ----
	part({ Name = "QuartersPorchStep", Size = Vector3.new(9, 1, 22), CFrame = at(halfW + 5, 1.4, 0), Color = Color3.fromRGB(206, 200, 188), Material = Enum.Material.Concrete, Parent = parent })
	for _, sz in { -8, 8 } do
		-- from the step's own surface at 1.9, not from thin air at 3
		part({ Name = "QuartersPorchPost", Size = Vector3.new(1.8, 15.8, 1.8), CFrame = at(halfW + 7, 9.8, sz), Color = Color3.fromRGB(232, 226, 214), Material = Enum.Material.WoodPlanks, Parent = parent })
	end
	part({ Name = "QuartersPorchBeam", Size = Vector3.new(11, 1.8, 22), CFrame = at(halfW + 4, 17.6, 0), Color = Color3.fromRGB(232, 226, 214), Material = Enum.Material.WoodPlanks, Parent = parent }).CanCollide = false
	for _, sz in { -1, 1 } do
		part({ Name = "QuartersPorchRoof", Size = Vector3.new(11.4, 1.2, 13), CFrame = at(halfW + 4, 19.6, sz * 5.6) * CFrame.Angles(sz * math.rad(24), 0, 0), Color = Color3.fromRGB(84, 92, 102), Material = Enum.Material.Slate, Parent = parent }).CanCollide = false
	end
	for _, sz in { -10, 10 } do
		local lantern = part({ Name = "QuartersLantern", Size = Vector3.new(1.8, 2.8, 1.8), CFrame = at(halfW + 1.6, 12, sz), Color = Color3.fromRGB(255, 214, 150), Material = Enum.Material.Neon, Parent = parent })
		lantern.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Brightness = 2.2
		glow.Range = 36
		glow.Color = Color3.fromRGB(255, 206, 148)
		glow.Parent = lantern
	end

	-- ---- the sign over the door ----
	local sign = part({ Name = "QuartersSign", Size = Vector3.new(30, 5, 0.8), CFrame = at(halfW + 2.4, 24, 0), Color = Palette.Blackboard, Parent = parent })
	sign.CanCollide = false
	signText(sign, "TEACHERS' QUARTERS", Palette.BusYellow, Enum.NormalId.Right)
	signText(sign, "STAFF ONLY (GOOD LUCK)", Palette.BusYellow, Enum.NormalId.Left)

	-- ---- the common room ----
	-- a hearth on the west wall, which is the whole reason to come in
	part({ Name = "Hearth", Size = Vector3.new(4, 14, 20), CFrame = at(-halfW + 3, 10, 0), Color = Color3.fromRGB(150, 142, 130), Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "HearthOpening", Size = Vector3.new(2, 8, 12), CFrame = at(-halfW + 4.2, 7, 0), Color = Color3.fromRGB(28, 24, 22), Parent = parent }).CanCollide = false
	local fire = part({ Name = "HearthFire", Size = Vector3.new(1.6, 4, 9), CFrame = at(-halfW + 4.6, 5.4, 0), Color = Color3.fromRGB(255, 148, 52), Material = Enum.Material.Neon, Parent = parent })
	fire.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Brightness = 2.4
	glow.Range = 52
	glow.Color = Color3.fromRGB(255, 168, 96)
	glow.Parent = fire
	part({ Name = "HearthMantel", Size = Vector3.new(5.4, 1.2, 22), CFrame = at(-halfW + 3.4, 14.6, 0), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })

	prop("ArmChair", CFrame.new(center + Vector3.new(-28, 3, -8)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("ArmChair", CFrame.new(center + Vector3.new(-28, 3, 8)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Sofa", CFrame.new(center + Vector3.new(-18, 3, 0)) * CFrame.Angles(0, math.rad(90), 0))
	prop("CoffeeTable", CFrame.new(center + Vector3.new(-23, 3, 0)))
	prop("Bookshelf", CFrame.new(center + Vector3.new(-34, 3, -22)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Bookshelf", CFrame.new(center + Vector3.new(-34, 3, 22)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("GrandfatherClock", CFrame.new(center + Vector3.new(-6, 3, -29)))
	prop("PottedPlant", CFrame.new(center + Vector3.new(34, 3, -28)))
	prop("Fern", CFrame.new(center + Vector3.new(-12, 3, 26)))

	-- the long table they mark books at
	part({ Name = "StaffTable", Size = Vector3.new(26, 0.7, 7), CFrame = at(6, 6.4, -20), Color = Color3.fromRGB(122, 86, 56), Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, lx in { -11, 11 } do
		part({ Name = "StaffTableLeg", Size = Vector3.new(1.2, 3.6, 6), CFrame = at(6 + lx, 4.3, -20), Color = Color3.fromRGB(96, 66, 44), Material = Enum.Material.Wood, Parent = parent })
	end
	for i = 0, 3 do
		prop("Chair", CFrame.new(center + Vector3.new(-3 + i * 6, 3, -15)) * CFrame.Angles(0, math.pi, 0))
	end

	-- a kitchen counter along the north wall
	part({ Name = "StaffCounterTop", Size = Vector3.new(30, 0.6, 5), CFrame = at(18, 6.4, -halfD + 4), Color = Color3.fromRGB(216, 212, 202), Material = Enum.Material.Marble, Parent = parent })
	part({ Name = "StaffCounterBody", Size = Vector3.new(30, 3.4, 4.6), CFrame = at(18, 4.4, -halfD + 4), Color = Color3.fromRGB(96, 108, 122), Material = Enum.Material.SmoothPlastic, Parent = parent })
	part({ Name = "StaffSink", Size = Vector3.new(5, 0.4, 3.4), CFrame = at(10, 6.6, -halfD + 4), Color = Color3.fromRGB(184, 190, 196), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	prop("VintageElectricKettle", CFrame.new(center + Vector3.new(22, 6.8, -halfD + 4)))
	prop("VintageMicrowave", CFrame.new(center + Vector3.new(28, 6.8, -halfD + 4)))

	-- ---- the stair up, in the east bay ----
	-- Sixteen treads, not fourteen: the floor of the ground storey is at y = 3
	-- and the deck above it at 19, so a fourteen-tread flight stopped two
	-- studs short of the floor it was meant to arrive at.
	buildStair(parent, CFrame.lookAt(center + Vector3.new(30, 3, 24), center + Vector3.new(30, 3, -4)), 16, 1, 1.9, 9)

	-- ---- five studies upstairs ----
	for index, teacher in TEACHERS do
		local sz = -halfD + 14 + (index - 1) * 11
		local doorX = 14
		-- a partition per study, opening onto the landing
		buildInteriorWall(
			parent,
			center + Vector3.new(-halfW + 2, GROUND + 3, sz),
			center + Vector3.new(doorX, GROUND + 3, sz),
			{}
		)
		local plaque = part({
			Name = "StudyPlaque",
			Size = Vector3.new(11, 2.6, 0.5),
			CFrame = at(doorX + 1.6, GROUND + 12, sz - 6),
			Color = Palette.Blackboard,
			Parent = parent,
		})
		plaque.CanCollide = false
		signText(plaque, teacher.name .. "\n" .. teacher.subject, teacher.color, Enum.NormalId.Right)

		-- a bed, a desk and a lamp: a study is a room somebody lives in
		part({ Name = "StudyBed", Size = Vector3.new(7, 2.6, 12), CFrame = at(-halfW + 8, GROUND + 4.3, sz - 6), Color = Color3.fromRGB(128, 92, 62), Material = Enum.Material.WoodPlanks, Parent = parent })
		part({ Name = "StudyMattress", Size = Vector3.new(6.4, 1.2, 11), CFrame = at(-halfW + 8, GROUND + 6.2, sz - 6), Color = teacher.color, Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
		prop("QuartersDesk", CFrame.new(center + Vector3.new(-halfW + 22, GROUND + 3, sz - 6)) * CFrame.Angles(0, math.rad(-90), 0))
		prop("PlainChair", CFrame.new(center + Vector3.new(-halfW + 28, GROUND + 3, sz - 6)) * CFrame.Angles(0, math.rad(90), 0))
		prop("QuartersCloset", CFrame.new(center + Vector3.new(-halfW + 14, GROUND + 3, sz - 7.5)) * CFrame.Angles(0, math.rad(180), 0))
		prop("QuartersNightstand", CFrame.new(center + Vector3.new(-halfW + 13, GROUND + 3, sz - 1)))
	end
	-- and a landing worth standing on
	prop("Sofa2", CFrame.new(center + Vector3.new(18, GROUND + 3, 26)) * CFrame.Angles(0, math.rad(180), 0))
	prop("SideTable", CFrame.new(center + Vector3.new(11, GROUND + 3, 26)))
	prop("PottedPlant", CFrame.new(center + Vector3.new(30, GROUND + 3, -26)))

	-- ---- the second flight, up to the headmaster ----
	-- Stacked over the first and running the other way, from the north end of
	-- the east bay back south. It used to start at z = -24 and climb north,
	-- which put its well straight through the east wall at z = -16 -- the wall
	-- the turret and the secret bookshelf are in. The headmaster's own door
	-- opened onto a stairwell void.
	buildStair(parent, CFrame.lookAt(center + Vector3.new(30, GROUND + 3, 30), center + Vector3.new(30, GROUND + 3, 0)), 16, 1, 1.9, 9)

	-- ================= THE HEADMASTER'S OFFICE =================
	-- The whole top floor, one room, and the grandest on the campus. It has to
	-- be: it is the room the school's one secret is kept in, and a secret kept
	-- in a broom cupboard is not worth finding. Panelled walls, a coffered
	-- ceiling, a fire, a desk on a dais at the far end, and a long table for
	-- the people who get summoned.
	local OAK = Color3.fromRGB(96, 62, 42)
	local OAK_LIGHT = Color3.fromRGB(138, 96, 62)
	local GILT = Color3.fromRGB(212, 172, 96)

	-- the floor, and the well railed off so the fire is visible from up here
	for _, rect in {
		{ -halfW, -halfD, halfW, -14 },
		{ -halfW, -14, -16, 0 },
		{ 16, -14, halfW, 0 },
		{ -halfW, 0, -16, 14 },
		{ 16, 0, 24, 14 },
		{ 38, 0, halfW, 14 },
		{ -halfW, 14, halfW, halfD },
	} do
		local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
		tag(part({ Name = "OfficeFloor", Size = Vector3.new(x1 - x0, 1, z1 - z0), CFrame = at((x0 + x1) / 2, OFFICE_FLOOR - 0.5, (z0 + z1) / 2), Color = Color3.fromRGB(92, 60, 40), Material = Enum.Material.WoodPlanks, Parent = parent }), "TexWood")
		tag(part({ Name = "OfficeSoffit", Size = Vector3.new(x1 - x0, 0.6, z1 - z0), CFrame = at((x0 + x1) / 2, OFFICE_FLOOR - 1.18, (z0 + z1) / 2), Color = Color3.fromRGB(238, 234, 224), Parent = parent }), "TexCeiling")
	end
	for _, rail in {
		{ -16, -14, 16, -14 }, { -16, 14, 16, 14 },
		{ -16, -14, -16, 14 }, { 16, -14, 16, 14 },
		{ 24, 0, 24, 14 }, { 38, 0, 38, 14 }, { 24, 14, 38, 14 },
	} do
		buildRailing(parent, center + Vector3.new(rail[1], OFFICE_FLOOR, rail[2]), center + Vector3.new(rail[3], OFFICE_FLOOR, rail[4]))
	end

	-- panelling all the way round, and a coffered ceiling over it
	for _, sz in { -1, 1 } do
		tag(part({ Name = "OfficePanel", Size = Vector3.new(W - 4, 9, 1.2), CFrame = at(0, OFFICE_FLOOR + 4.5, sz * (halfD - 1.6)), Color = OAK, Material = Enum.Material.WoodPlanks, Parent = parent }), "TexWood")
		part({ Name = "OfficeRail", Size = Vector3.new(W - 4, 0.8, 1.8), CFrame = at(0, OFFICE_FLOOR + 9.4, sz * (halfD - 1.6)), Color = GILT, Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	end
	for _, sx in { -1, 1 } do
		tag(part({ Name = "OfficePanel", Size = Vector3.new(1.2, 9, D - 4), CFrame = at(sx * (halfW - 1.6), OFFICE_FLOOR + 4.5, 0), Color = OAK, Material = Enum.Material.WoodPlanks, Parent = parent }), "TexWood")
		part({ Name = "OfficeRail", Size = Vector3.new(1.8, 0.8, D - 4), CFrame = at(sx * (halfW - 1.6), OFFICE_FLOOR + 9.4, 0), Color = GILT, Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	end
	tag(part({ Name = "OfficeCeiling", Size = Vector3.new(W, 1, D), CFrame = at(0, OFFICE_FLOOR + 18, 0), Color = Color3.fromRGB(58, 40, 28), Material = Enum.Material.Wood, Parent = parent }), "TexCeiling")
	for cx = -3, 3 do
		for cz = -2, 2 do
			part({ Name = "OfficeCoffer", Size = Vector3.new(9, 0.8, 9), CFrame = at(cx * 11, OFFICE_FLOOR + 17.3, cz * 12), Color = OAK, Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
		end
	end

	-- the dais and the desk at the west end, facing the door
	part({ Name = "OfficeDais", Size = Vector3.new(30, 1.8, 26), CFrame = at(-halfW + 17, OFFICE_FLOOR + 0.8, 0), Color = Color3.fromRGB(78, 50, 34), Material = Enum.Material.WoodPlanks, Parent = parent })
	part({ Name = "OfficeDaisStep", Size = Vector3.new(30, 0.7, 3), CFrame = at(-halfW + 17, OFFICE_FLOOR + 0.35, 14.5), Color = Color3.fromRGB(78, 50, 34), Material = Enum.Material.WoodPlanks, Parent = parent })
	part({ Name = "HeadDesk", Size = Vector3.new(8, 1, 22), CFrame = at(-halfW + 18, OFFICE_FLOOR + 6.4, 0), Color = OAK_LIGHT, Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, dz in { -9, 9 } do
		part({ Name = "HeadDeskPed", Size = Vector3.new(7, 4.4, 4), CFrame = at(-halfW + 18, OFFICE_FLOOR + 3.7, dz), Color = OAK, Material = Enum.Material.WoodPlanks, Parent = parent })
	end
	part({ Name = "HeadDeskInlay", Size = Vector3.new(6, 0.2, 18), CFrame = at(-halfW + 18, OFFICE_FLOOR + 6.95, 0), Color = Color3.fromRGB(64, 34, 30), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
	prop("HeadmasterChair", CFrame.new(center + Vector3.new(-halfW + 17, OFFICE_FLOOR + 1.6, 0)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("PlainChair", CFrame.new(center + Vector3.new(-halfW + 26, OFFICE_FLOOR, -6)) * CFrame.Angles(0, math.rad(90), 0))
	prop("PlainChair", CFrame.new(center + Vector3.new(-halfW + 26, OFFICE_FLOOR, 6)) * CFrame.Angles(0, math.rad(90), 0))
	-- a pair flanking the crest, so the wall behind the desk is not bare brick
	for _, cz in { -13, 13 } do
		prop("TallBookcase", CFrame.new(center + Vector3.new(-halfW + 6, OFFICE_FLOOR, cz)) * CFrame.Angles(0, math.rad(90), 0))
	end
	prop("LodgeArmchair", CFrame.new(center + Vector3.new(-14, OFFICE_FLOOR, -22)) * CFrame.Angles(0, math.rad(20), 0))
	prop("LodgeArmchair", CFrame.new(center + Vector3.new(2, OFFICE_FLOOR, -22)) * CFrame.Angles(0, math.rad(-20), 0))
	prop("Rug", CFrame.new(center + Vector3.new(-halfW + 30, OFFICE_FLOOR + 1.6, 0)))
	prop("Houseplant3", CFrame.new(center + Vector3.new(-halfW + 8, OFFICE_FLOOR, 26)))
	prop("Houseplant", CFrame.new(center + Vector3.new(-halfW + 8, OFFICE_FLOOR, -26)))
	buildGlobe(parent, CFrame.new(center + Vector3.new(-halfW + 26, OFFICE_FLOOR, 16)))
	prop("DeskLamp", CFrame.new(center + Vector3.new(-halfW + 18, OFFICE_FLOOR + 6.9, -8)))

	-- the crest behind the desk
	local crest = part({ Name = "HeadCrest", Size = Vector3.new(1, 14, 18), CFrame = at(-halfW + 2.6, OFFICE_FLOOR + 9, 0), Color = Palette.Blackboard, Parent = parent })
	crest.CanCollide = false
	signText(crest, "CRUMBWORTH HIGH\nHEADMASTER", GILT, Enum.NormalId.Right)

	-- a fire on the north wall, over the one two floors below
	part({ Name = "OfficeHearth", Size = Vector3.new(18, 12, 4), CFrame = at(-6, OFFICE_FLOOR + 6, -halfD + 3), Color = Color3.fromRGB(150, 142, 130), Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "OfficeHearthOpening", Size = Vector3.new(11, 7, 2), CFrame = at(-6, OFFICE_FLOOR + 4, -halfD + 4.4), Color = Color3.fromRGB(28, 24, 22), Parent = parent }).CanCollide = false
	local officeFire = part({ Name = "OfficeFire", Size = Vector3.new(8, 3.4, 1.6), CFrame = at(-6, OFFICE_FLOOR + 2.6, -halfD + 4.8), Color = Color3.fromRGB(255, 148, 52), Material = Enum.Material.Neon, Parent = parent })
	officeFire.CanCollide = false
	local officeGlow = Instance.new("PointLight")
	officeGlow.Brightness = 2.6
	officeGlow.Range = 56
	officeGlow.Color = Color3.fromRGB(255, 168, 96)
	officeGlow.Parent = officeFire
	part({ Name = "OfficeMantel", Size = Vector3.new(21, 1.2, 5.4), CFrame = at(-6, OFFICE_FLOOR + 12.6, -halfD + 3.4), Color = OAK_LIGHT, Material = Enum.Material.WoodPlanks, Parent = parent })

	-- the long table, for whoever has been summoned
	part({ Name = "OfficeTable", Size = Vector3.new(11, 0.8, 30), CFrame = at(8, OFFICE_FLOOR + 6.4, 0), Color = OAK_LIGHT, Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, tz in { -12, 12 } do
		part({ Name = "OfficeTableLeg", Size = Vector3.new(9, 6, 1.4), CFrame = at(8, OFFICE_FLOOR + 3, tz), Color = OAK, Material = Enum.Material.Wood, Parent = parent })
	end
	for i = 0, 3 do
		prop("Chair", CFrame.new(center + Vector3.new(1, OFFICE_FLOOR, -11 + i * 7)) * CFrame.Angles(0, math.rad(-90), 0))
		prop("Chair", CFrame.new(center + Vector3.new(15, OFFICE_FLOOR, -11 + i * 7)) * CFrame.Angles(0, math.rad(90), 0))
	end

	-- bookshelves down the south wall, which is what makes one more bookshelf
	-- on the east wall unremarkable
	for i = 0, 4 do
		prop("StockedBookcase", CFrame.new(center + Vector3.new(-26 + i * 13, OFFICE_FLOOR, halfD - 5)) * CFrame.Angles(0, math.pi, 0))
	end
	prop("StockedBookcase", CFrame.new(center + Vector3.new(halfW - 5, OFFICE_FLOOR, -18)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("GrandfatherClock", CFrame.new(center + Vector3.new(halfW - 5, OFFICE_FLOOR, 18)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("PottedPlant", CFrame.new(center + Vector3.new(halfW - 6, OFFICE_FLOOR, 26)))

	-- chandeliers, because the room is twenty studs tall and otherwise reads
	-- as a warehouse
	for _, lx in { -22, 8, 30 } do
		local chain = part({ Name = "OfficeChandelierChain", Size = Vector3.new(0.4, 5, 0.4), CFrame = at(lx, OFFICE_FLOOR + 14, 0), Color = GILT, Material = Enum.Material.Metal, Parent = parent })
		chain.CanCollide = false
		local ring = part({ Name = "OfficeChandelier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 7, 7), CFrame = at(lx, OFFICE_FLOOR + 11, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GILT, Material = Enum.Material.Metal, Parent = parent })
		ring.CanCollide = false
		local candle = part({ Name = "OfficeChandelierGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), CFrame = at(lx, OFFICE_FLOOR + 11, 0), Color = Color3.fromRGB(255, 226, 168), Material = Enum.Material.Neon, Parent = parent })
		candle.CanCollide = false
		local lamp = Instance.new("PointLight")
		lamp.Brightness = 2.2
		lamp.Range = 46
		lamp.Color = Color3.fromRGB(255, 228, 180)
		lamp.Parent = candle
	end
end


-- A floor slab with a rectangle missing, emitted as up to four parts. A nil
-- hole is a plain slab: the school's floors were cut around a stairwell that
-- has since moved out to the staff lodge, and a hole nothing goes through is
-- just a place to fall.
local function floorWithHole(parent: Instance, name: string, centre: Vector3, size: Vector2, hole: { x0: number, z0: number, x1: number, z1: number }?, texTag: string?)
	local x0, x1 = centre.X - size.X / 2, centre.X + size.X / 2
	local z0, z1 = centre.Z - size.Y / 2, centre.Z + size.Y / 2
	if not hole then
		hole = { x0 = 0, z0 = 0, x1 = 0, z1 = 0 }
	end
	local cut = hole :: { x0: number, z0: number, x1: number, z1: number }
	local hx0 = math.max(x0, cut.x0)
	local hx1 = math.min(x1, cut.x1)
	local hz0 = math.max(z0, cut.z0)
	local hz1 = math.min(z1, cut.z1)
	local rects
	if hx0 >= hx1 or hz0 >= hz1 then
		rects = { { x0, z0, x1, z1 } } -- the hole misses this slab entirely
	else
		rects = {
			{ x0, z0, hx0, z1 },
			{ hx1, z0, x1, z1 },
			{ hx0, z0, hx1, hz0 },
			{ hx0, hz1, hx1, z1 },
		}
	end
	for index, rect in rects do
		local rx0, rz0, rx1, rz1 = rect[1], rect[2], rect[3], rect[4]
		if rx1 - rx0 < 0.05 or rz1 - rz0 < 0.05 then
			continue
		end
		local piece = part({
			Name = name .. index,
			Size = Vector3.new(rx1 - rx0, 1, rz1 - rz0),
			CFrame = CFrame.new((rx0 + rx1) / 2, centre.Y, (rz0 + rz1) / 2),
			Color = Color3.fromRGB(196, 194, 188),
			Parent = parent,
		})
		if texTag then
			tag(piece, texTag)
		end
	end
end

-- A spiral stair in a shaft: treads on a circle, each one a step higher than
-- the last, with a newel down the middle and a stone tube around the outside.
--
-- This is what replaced a hundred and ten treads running in a straight line
-- under the school. A straight flight needs as much floor as it needs height,
-- which is why the old one ran a hundred and seventy-six studs north from the
-- principal's office and dictated where the estate had to be. A spiral needs a
-- twenty-stud square, so the way in can be wherever the fiction wants it.
local function buildSpiral(
	parent: Instance,
	centre: Vector3,
	topY: number,
	bottomY: number,
	radius: number,
	facing: number
)
	local RISE = 1.4
	local PER_TURN = 24
	local steps = math.max(4, math.floor((topY - bottomY) / RISE))
	local tread = radius * 2 * math.pi / PER_TURN * 1.35
	for i = 0, steps do
		local angle = facing + i * (math.pi * 2 / PER_TURN)
		local y = topY - i * RISE
		local px = centre.X + math.cos(angle) * radius
		local pz = centre.Z + math.sin(angle) * radius
		part({
			Name = "SanctumTread",
			Size = Vector3.new(radius * 1.5, 1.2, tread),
			CFrame = CFrame.new(px, y - 0.6, pz) * CFrame.Angles(0, -angle, 0),
			Color = Color3.fromRGB(150, 142, 128),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	-- the newel: one column the whole way down, so the middle is not a void
	part({
		Name = "SanctumNewel",
		Size = Vector3.new(radius * 0.7, topY - bottomY + 4, radius * 0.7),
		CFrame = CFrame.new(centre.X, (topY + bottomY) / 2, centre.Z),
		Color = Color3.fromRGB(120, 114, 104),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	-- torches every turn and a half
	local lit = 0
	while lit * RISE * PER_TURN * 1.5 < topY - bottomY do
		local y = topY - lit * RISE * PER_TURN * 1.5 - 3
		local angle = facing + lit * math.pi
		local flame = part({
			Name = "SanctumTorch",
			Size = Vector3.new(1.3, 2.2, 1.3),
			CFrame = CFrame.new(centre.X + math.cos(angle) * (radius + 3.2), y + 5, centre.Z + math.sin(angle) * (radius + 3.2)),
			Color = Color3.fromRGB(255, 168, 76),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		flame.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 2.2
		light.Range = 44
		light.Color = Color3.fromRGB(255, 174, 96)
		light.Parent = flame
		lit += 1
	end
	return steps
end

-- The stone tube around a spiral. Built as four walls with a square bore, so
-- the shaft reads as cut through rock rather than hanging in it.
--
-- `openings` are the doorways: which wall, and between which two heights.
-- Every shaft needs at least the one at the bottom -- the way OUT. Without it
-- you walk down a hundred and twenty studs of spiral and arrive in a sealed
-- stone tube. The library's needs a second one at the top as well, where its
-- passage comes in from under the field.
export type ShaftOpening = { dir: Vector3, y0: number, y1: number }

local DOORWAY_W = 16
local function buildShaft(
	parent: Instance,
	centre: Vector3,
	topY: number,
	bottomY: number,
	half: number,
	openings: { ShaftOpening }?
)
	local wide = half * 2 + 4
	local jamb = (wide - DOORWAY_W) / 2
	local lo, hi = bottomY - 3, topY + 3
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local x = centre.X + side[1] * (half + 1)
		local z = centre.Z + side[2] * (half + 1)
		local function slab(h: number, y: number, w: number, offset: number)
			if h <= 0.05 or w <= 0.05 then
				return
			end
			part({
				Name = "SanctumShaftWall",
				Size = if side[1] ~= 0 then Vector3.new(2, h, w) else Vector3.new(w, h, 2),
				CFrame = CFrame.new(
					x + (if side[1] ~= 0 then 0 else offset),
					y,
					z + (if side[1] ~= 0 then offset else 0)
				),
				Color = Color3.fromRGB(104, 98, 90),
				Material = Enum.Material.Slate,
				Parent = parent,
			})
		end

		-- the doorways on THIS wall, bottom to top
		local mine: { ShaftOpening } = {}
		for _, opening in openings or {} :: { ShaftOpening } do
			if side[1] == math.sign(opening.dir.X) and side[2] == math.sign(opening.dir.Z) then
				table.insert(mine, opening)
			end
		end
		table.sort(mine, function(a, b)
			return a.y0 < b.y0
		end)

		-- solid bands between them, jambs beside them
		local y = lo
		for _, opening in mine do
			slab(math.max(opening.y0 - y, 0), (y + opening.y0) / 2, wide, 0)
			for _, dir in { -1, 1 } do
				slab(opening.y1 - opening.y0, (opening.y0 + opening.y1) / 2, jamb, dir * (DOORWAY_W / 2 + jamb / 2))
			end
			y = opening.y1
		end
		slab(math.max(hi - y, 0), (y + hi) / 2, wide, 0)
	end
end

-- A level tunnel between two points: floor, two walls, a ceiling and lamps.
local function buildTunnel(parent: Instance, from: Vector3, to: Vector3, halfWidth: number, height: number)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local mid = (from + to) / 2
	local cf = CFrame.lookAt(mid, mid + Vector3.new(delta.X, 0, delta.Z).Unit)
	local function piece(name: string, size: Vector3, offset: Vector3, colour: Color3)
		part({
			Name = name,
			Size = size,
			CFrame = cf * CFrame.new(offset),
			Color = colour,
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	piece("SanctumTunnelFloor", Vector3.new(halfWidth * 2, 1.4, length), Vector3.new(0, -0.7, 0), Color3.fromRGB(150, 142, 128))
	piece("SanctumTunnelRoof", Vector3.new(halfWidth * 2 + 4, 1.6, length), Vector3.new(0, height, 0), Color3.fromRGB(88, 82, 76))
	for _, side in { -1, 1 } do
		piece("SanctumTunnelWall", Vector3.new(2, height + 2, length), Vector3.new(side * (halfWidth + 1), height / 2, 0), Color3.fromRGB(104, 98, 90))
	end
	local lamps = math.max(1, math.floor(length / 26))
	for i = 0, lamps do
		local t = if lamps > 0 then i / lamps else 0.5
		local at = from:Lerp(to, t)
		local flame = part({
			Name = "SanctumTorch",
			Size = Vector3.new(1.3, 2.2, 1.3),
			CFrame = CFrame.new(at.X, at.Y + height - 3, at.Z),
			Color = Color3.fromRGB(255, 168, 76),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		flame.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 2.1
		light.Range = 40
		light.Color = Color3.fromRGB(255, 174, 96)
		light.Parent = flame
	end
end

-- A bookshelf that is a door. Returned so a service can own the prompt and
-- slide it aside; the boards and books are scenery hung on the front of it.
-- The boards and the books are CHILDREN of the backing slab, not siblings of
-- it. They used to be siblings, and only the slab was ever moved: pulling the
-- book slid a bare panel fifteen studs down the passage and left the shelf you
-- were looking at -- four boards and thirty-two books, hanging in mid-air in
-- the doorway -- exactly where it was. What that looks like from the reading
-- room is a bookshelf that does not open, and a SECOND bookshelf appearing
-- behind it. Owning the pieces is what lets SanctumService swing the whole
-- thing as one door.
local function buildSecretBookshelf(parent: Instance, at: CFrame, name: string): BasePart
	local shelf = part({
		Name = name,
		Size = Vector3.new(14, 14, 2.4),
		CFrame = at,
		Color = Color3.fromRGB(88, 58, 40),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	for level = 0, 3 do
		part({
			Name = "SecretShelfBoard",
			Size = Vector3.new(13.4, 0.5, 2.6),
			CFrame = at * CFrame.new(0, -5 + level * 3.4, 0),
			Color = Color3.fromRGB(112, 76, 52),
			Material = Enum.Material.Wood,
			Parent = shelf,
		}).CanCollide = false
		for book = 0, 7 do
			part({
				Name = "SecretShelfBook",
				Size = Vector3.new(1.1, 2.4, 1.6),
				CFrame = at * CFrame.new(-5.6 + book * 1.55, -3.6 + level * 3.4, -0.7),
				Color = Color3.fromHSV(((level * 8 + book) % 12) / 12, 0.45, 0.62),
				Material = Enum.Material.Fabric,
				Parent = shelf,
			}).CanCollide = false
		end
	end
	return shelf
end

-- ================= THE WAYS DOWN =================
-- Two doors, both bookshelves, both opening on the same four digits.
--
--   The headmaster's, in his office at the top of the staff lodge: a turret
--   off its east wall with a spiral inside, then a tunnel east to the far end
--   of the boulevard, so he arrives at the head of the whole approach.
--
--   The library's, behind the stacks on its west wall: a low passage under the
--   north field and a shorter spiral, arriving partway along the boulevard
--   with the pyramid already in front of you.
--
-- The estate itself is under the LIBRARY -- its capstone is thirty-odd studs
-- below the reading room floor -- which is why the library has a door onto it
-- at all. See SanctumMap for the transform that puts it there.
local SANCTUM_FLOOR_Y = -119.5
-- the far end of the boulevard: SanctumMap.Entrance, which is checked against
-- this by tools/content_check.py so the two can never drift apart
local SANCTUM_ENTRANCE = Vector3.new(-478.4, -118, -300)
local SANCTUM_LANDING = Vector3.new(-99.8, -118, -221.8)

-- the office turret: where the headmaster's spiral lives
local TURRET = Vector3.new(-249, 0, -186)
local OFFICE_Y = 35

-- the library's shaft, under the north field just west of the building
local LIB_SHAFT = Vector3.new(-420, 0, -290)
local LIB_DOOR_X = -366

local function buildSanctum(parent: Instance): { BasePart }
	local shelves: { BasePart } = {}

	-- ---------------- the headmaster's way down ----------------
	-- the turret, standing against the lodge's east wall
	local turretHalf = 11
	local TURRET_TOP = 62
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local size = if side[1] ~= 0
			then Vector3.new(2, TURRET_TOP, turretHalf * 2 + 4)
			else Vector3.new(turretHalf * 2 + 4, TURRET_TOP, 2)
		-- the west face is where the bookshelf is, so leave a doorway in it
		if not (side[1] == -1) then
			tag(part({
				Name = "TurretWall",
				Size = size,
				CFrame = CFrame.new(TURRET.X + side[1] * (turretHalf + 1), TURRET_TOP / 2, TURRET.Z + side[2] * (turretHalf + 1)),
				Color = Color3.fromRGB(138, 128, 114),
				Material = Enum.Material.Brick,
				Parent = parent,
			}), "TexCoursedStone")
		end
	end
	-- the west face, in two pieces with the doorway between them
	for _, piece in { { TURRET.Z - turretHalf - 1, TURRET.Z - 7 }, { TURRET.Z + 7, TURRET.Z + turretHalf + 1 } } do
		tag(part({
			Name = "TurretWall",
			Size = Vector3.new(2, TURRET_TOP, piece[2] - piece[1]),
			CFrame = CFrame.new(TURRET.X - turretHalf - 1, TURRET_TOP / 2, (piece[1] + piece[2]) / 2),
			Color = Color3.fromRGB(138, 128, 114),
			Material = Enum.Material.Brick,
			Parent = parent,
		}), "TexCoursedStone")
	end
	-- above and below the doorway, so the wall is not open from floor to roof
	-- above and below the doorway, so the west face is not open floor to roof
	local headY = OFFICE_Y + 14
	tag(part({ Name = "TurretWall", Size = Vector3.new(2, TURRET_TOP - headY, 14), CFrame = CFrame.new(TURRET.X - turretHalf - 1, (headY + TURRET_TOP) / 2, TURRET.Z), Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
	tag(part({ Name = "TurretWall", Size = Vector3.new(2, OFFICE_Y, 14), CFrame = CFrame.new(TURRET.X - turretHalf - 1, OFFICE_Y / 2, TURRET.Z), Color = Color3.fromRGB(138, 128, 114), Material = Enum.Material.Brick, Parent = parent }), "TexCoursedStone")
	part({ Name = "TurretCap", Size = Vector3.new(turretHalf * 2 + 8, 2, turretHalf * 2 + 8), CFrame = CFrame.new(TURRET.X, TURRET_TOP + 1, TURRET.Z), Color = Color3.fromRGB(96, 90, 84), Material = Enum.Material.Slate, Parent = parent })
	-- No landing slab. One used to cover the whole turret at office level,
	-- which put a stone lid two studs above the second tread: you stepped
	-- through the shelf and could not stand up. The spiral's own top tread is
	-- the landing, and it starts at the doorway (facing = pi, the west side)
	-- rather than eighteen studs across the shaft from it.
	buildSpiral(parent, TURRET, OFFICE_Y - 1.4, SANCTUM_FLOOR_Y, 7, math.pi)
	-- the way out at the bottom faces the tunnel
	local outward = SANCTUM_ENTRANCE - TURRET
	local axis = if math.abs(outward.X) >= math.abs(outward.Z)
		then Vector3.new(math.sign(outward.X), 0, 0)
		else Vector3.new(0, 0, math.sign(outward.Z))
	buildShaft(parent, TURRET, -2, SANCTUM_FLOOR_Y, turretHalf, {
		{ dir = axis, y0 = SANCTUM_FLOOR_Y, y1 = SANCTUM_FLOOR_Y + 14 },
	})
	table.insert(shelves, buildSecretBookshelf(
		parent,
		CFrame.new(TURRET.X - turretHalf, OFFICE_Y + 7, TURRET.Z) * CFrame.Angles(0, math.rad(90), 0),
		"SecretBookshelf"
	))
	-- from the shaft's doorway, not from its middle: the newel is in the middle
	local mouth = Vector3.new(TURRET.X, SANCTUM_FLOOR_Y, TURRET.Z) + axis * (turretHalf + 1)
	buildTunnel(parent, mouth, SANCTUM_ENTRANCE, 7, 13)

	-- ---------------- the library's way down ----------------
	-- A flight down, then a passage west under the field, then a spiral.
	--
	-- The passage used to run at the library's own floor level with a
	-- twelve-stud ceiling, which put a thirteen-stud corridor STANDING ON THE
	-- LAWN for forty studs west of the building with nothing over it. A secret
	-- passage you can see from the playing field is not a secret passage; it
	-- is a shed. It goes under the field now, which is what it always said it
	-- did, and the steps are inside the door where nobody can see them either.
	local libHalf = 10
	local PASSAGE_Y = -16
	part({ Name = "LibraryPassageLanding", Size = Vector3.new(10, 1.2, 14), CFrame = CFrame.new(LIB_DOOR_X - 5, -0.6, LIB_SHAFT.Z), Color = Color3.fromRGB(150, 142, 128), Material = Enum.Material.Slate, Parent = parent })
	-- sixteen steps down, from the landing at y = 0 to the passage at -16
	for i = 0, 15 do
		part({
			Name = "LibraryStep",
			Size = Vector3.new(1.9, 30 - i, 12),
			CFrame = CFrame.new(LIB_DOOR_X - 10.95 - i * 1.9, -1 - i - (30 - i) / 2, LIB_SHAFT.Z),
			Color = Color3.fromRGB(150, 142, 128),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	-- The first twenty studs of the descent are necessarily at ground level,
	-- because the library's floor is. So they are inside a VESTRY -- a stone
	-- outshot against the library's west wall, with buttresses and a slate
	-- cap. From the field that reads as part of the building's plinth, which
	-- is what it should read as; a bare corridor standing on the lawn reads as
	-- a shed with a secret in it.
	local VX = LIB_DOOR_X - 13
	for _, sz in { -1, 1 } do
		tag(part({ Name = "LibraryVestryWall", Size = Vector3.new(26, 15, 2), CFrame = CFrame.new(VX, 7.5, LIB_SHAFT.Z + sz * 9), Color = Color3.fromRGB(206, 198, 182), Material = Enum.Material.Sandstone, Parent = parent }), "TexCoursedStone")
	end
	tag(part({ Name = "LibraryVestryWall", Size = Vector3.new(2, 15, 20), CFrame = CFrame.new(VX - 13, 7.5, LIB_SHAFT.Z), Color = Color3.fromRGB(206, 198, 182), Material = Enum.Material.Sandstone, Parent = parent }), "TexCoursedStone")
	part({ Name = "LibraryVestryRoof", Size = Vector3.new(30, 1.8, 24), CFrame = CFrame.new(VX, 15.9, LIB_SHAFT.Z), Color = Color3.fromRGB(88, 96, 106), Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "LibraryVestryCap", Size = Vector3.new(31, 1, 25), CFrame = CFrame.new(VX, 17, LIB_SHAFT.Z), Color = Color3.fromRGB(224, 218, 204), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
	for _, corner in { Vector3.new(-12, 0, -9), Vector3.new(-12, 0, 9), Vector3.new(11, 0, -9), Vector3.new(11, 0, 9) } do
		tag(part({ Name = "LibraryVestryButtress", Size = Vector3.new(3.4, 13, 3.4), CFrame = CFrame.new(VX + corner.X, 6.5, LIB_SHAFT.Z + corner.Z), Color = Color3.fromRGB(214, 206, 190), Material = Enum.Material.Sandstone, Parent = parent }), "TexCoursedStone")
	end
	-- from there on the steps are deep enough to be roofed under the lawn
	for _, sz in { -1, 1 } do
		part({ Name = "LibraryStairWall", Size = Vector3.new(20, 22, 2), CFrame = CFrame.new(LIB_DOOR_X - 34, -12, LIB_SHAFT.Z + sz * 7), Color = Color3.fromRGB(104, 98, 90), Material = Enum.Material.Slate, Parent = parent })
	end
	part({ Name = "LibraryStairRoof", Size = Vector3.new(20, 1.6, 18), CFrame = CFrame.new(LIB_DOOR_X - 34, -1.2, LIB_SHAFT.Z), Color = Color3.fromRGB(88, 82, 76), Material = Enum.Material.Slate, Parent = parent })
	-- ends at the shaft's east wall, not at its middle: run it to the centre
	-- and its own floor becomes a lid four studs over the second tread
	buildTunnel(parent, Vector3.new(LIB_DOOR_X - 40, PASSAGE_Y, LIB_SHAFT.Z), Vector3.new(LIB_SHAFT.X + libHalf + 2, PASSAGE_Y, LIB_SHAFT.Z), 6, 12)
	-- facing 0: the top tread is on the east side, where the passage from
	-- the library arrives, not across the shaft from it
	buildSpiral(parent, LIB_SHAFT, PASSAGE_Y - 1.4, SANCTUM_FLOOR_Y, 6.5, 0)
	-- this one comes down ON the boulevard, so its doorway opens straight onto
	-- it, facing the pyramid
	buildShaft(parent, LIB_SHAFT, PASSAGE_Y + 13, SANCTUM_FLOOR_Y, libHalf, {
		{ dir = Vector3.new(1, 0, 0), y0 = SANCTUM_FLOOR_Y, y1 = SANCTUM_FLOOR_Y + 14 },
		{ dir = Vector3.new(1, 0, 0), y0 = PASSAGE_Y - 1.6, y1 = PASSAGE_Y + 11 },
	})
	part({ Name = "SanctumShaftLid", Size = Vector3.new(libHalf * 2 + 4, 2, libHalf * 2 + 4), CFrame = CFrame.new(LIB_SHAFT.X, PASSAGE_Y + 14, LIB_SHAFT.Z), Color = Color3.fromRGB(88, 82, 76), Material = Enum.Material.Slate, Parent = parent })
	table.insert(shelves, buildSecretBookshelf(
		parent,
		CFrame.new(LIB_DOOR_X + 1, 7, LIB_SHAFT.Z) * CFrame.Angles(0, math.rad(90), 0),
		"SecretBookshelfLibrary"
	))

	-- ---------------- the cavern the estate sits in ----------------
	-- A sealed box around the whole thing, with a gap in its west wall where
	-- the headmaster's tunnel comes through and a hole in its roof where the
	-- library's shaft does.
	-- THE CAVERN the estate sits inside, moved with it. These are absolute
	-- world bounds, and when the library took the pyramid to (-320, -300) they
	-- stayed behind -- so the whole estate was outside its own cave, lit by
	-- nothing, with a 286 x 282 stone box sitting empty where it used to be.
	local CX0, CX1 = -498, -212
	local CZ0, CZ1 = -450, -168
	local CY0, CY1 = -132, -18
	local function shell(name: string, size: Vector3, at: Vector3)
		part({ Name = name, Size = size, CFrame = CFrame.new(at), Color = Color3.fromRGB(46, 42, 40), Material = Enum.Material.Slate, Parent = parent })
	end
	shell("SanctumCavernFloor", Vector3.new(CX1 - CX0, 4, CZ1 - CZ0), Vector3.new((CX0 + CX1) / 2, CY0, (CZ0 + CZ1) / 2))
	shell("SanctumCavernE", Vector3.new(4, CY1 - CY0, CZ1 - CZ0), Vector3.new(CX1, (CY0 + CY1) / 2, (CZ0 + CZ1) / 2))
	shell("SanctumCavernS", Vector3.new(CX1 - CX0, CY1 - CY0, 4), Vector3.new((CX0 + CX1) / 2, (CY0 + CY1) / 2, CZ0))
	shell("SanctumCavernN", Vector3.new(CX1 - CX0, CY1 - CY0, 4), Vector3.new((CX0 + CX1) / 2, (CY0 + CY1) / 2, CZ1))
	-- west wall, in two halves around the tunnel mouth
	-- generous, because the tunnel meets it on a diagonal: the mouth is not a
	-- neat perpendicular hole, and the tunnel's own walls seal the gap anyway
	for _, piece in { { CZ0, SANCTUM_ENTRANCE.Z - 30 }, { SANCTUM_ENTRANCE.Z + 30, CZ1 } } do
		shell("SanctumCavernW", Vector3.new(4, CY1 - CY0, piece[2] - piece[1]), Vector3.new(CX0, (CY0 + CY1) / 2, (piece[1] + piece[2]) / 2))
	end
	-- Roof. Two ways down pass through it -- the library shaft and the
	-- headmaster's turret -- and when the cavern moved west to follow the
	-- library it swallowed the turret, so a roof cut only for the shaft came
	-- down through the headmaster's spiral. Cut it for every hole instead:
	-- band along z at each hole edge, split each band along x around the holes
	-- that reach into it, and emit a slab only where no hole covers it.
	local holes = {
		{ LIB_SHAFT.X - libHalf - 2, LIB_SHAFT.Z - libHalf - 2, LIB_SHAFT.X + libHalf + 2, LIB_SHAFT.Z + libHalf + 2 },
		{ TURRET.X - turretHalf - 2, TURRET.Z - turretHalf - 2, TURRET.X + turretHalf + 2, TURRET.Z + turretHalf + 2 },
	}
	local zEdges = { CZ0, CZ1 }
	for _, h in holes do
		table.insert(zEdges, math.clamp(h[2], CZ0, CZ1))
		table.insert(zEdges, math.clamp(h[4], CZ0, CZ1))
	end
	table.sort(zEdges)
	for i = 1, #zEdges - 1 do
		local z0, z1 = zEdges[i], zEdges[i + 1]
		if z1 - z0 > 0.5 then
			local zm = (z0 + z1) / 2
			local xEdges = { CX0, CX1 }
			for _, h in holes do
				if zm > h[2] and zm < h[4] then
					table.insert(xEdges, math.clamp(h[1], CX0, CX1))
					table.insert(xEdges, math.clamp(h[3], CX0, CX1))
				end
			end
			table.sort(xEdges)
			for j = 1, #xEdges - 1 do
				local x0, x1 = xEdges[j], xEdges[j + 1]
				local xm = (x0 + x1) / 2
				local covered = false
				for _, h in holes do
					if xm > h[1] and xm < h[3] and zm > h[2] and zm < h[4] then
						covered = true
					end
				end
				if not covered and x1 - x0 > 0.5 then
					shell("SanctumCavernRoof", Vector3.new(x1 - x0, 4, z1 - z0), Vector3.new((x0 + x1) / 2, CY1, (z0 + z1) / 2))
				end
			end
		end
	end

	return shelves
end

-- ================= LIGHT =================
-- Future lighting gives an interior nothing except what its own fixtures emit
-- and what comes through its windows, and this building had 46 light sources
-- in it, most of them door signs. The main hallway had none: there was a
-- buildHallwayLights that was written for the corridor's old position and was
-- never called from anywhere, so four hundred studs of school ran on ambient.
--
-- One table, read by the builder below and by tools/light_check.py, so the
-- fixtures and the check can never disagree about which rooms exist.
--   name, centre x, centre z, half width, half depth, ceiling y, spacing
export type LitRoom = {
	name: string,
	x: number,
	z: number,
	hx: number,
	hz: number,
	y: number,
	step: number,
	warm: boolean?,
	lamp: string?,
}

local LIT_ROOMS: { LitRoom } = {
	{ name = "MainHall", x = 0, z = 65, hx = 212, hz = 14, y = 13.6, step = 24 },
	{ name = "UpperHall", x = 0, z = 65, hx = 212, hz = 14, y = 30, step = 24 },
	{ name = "Lobby", x = 0, z = 100, hx = 26, hz = 20, y = 13.6, step = 20 , lamp = "CeilingLampDisc" },
	{ name = "Atrium", x = 0, z = 22, hx = 26, hz = 24, y = 13.6, step = 20 , lamp = "CeilingLampDisc" },
	{ name = "AssemblyHall", x = 0, z = -100, hx = 46, hz = 28, y = 24, step = 26 , lamp = "CeilingLampBox" },
	{ name = "Gymnasium", x = 425, z = 437, hx = 82, hz = 22, y = 24, step = 28 , lamp = "CeilingLampBox" },
	{ name = "Library", x = -320, z = -300, hx = 42, hz = 30, y = 23, step = 26, warm = true , lamp = "GrandChandelier" },
	{ name = "Cafeteria", x = -204, z = -29, hx = 17, hz = 26, y = 13.6, step = 20 , lamp = "CeilingLampBox" },
	{ name = "Office", x = -204, z = 35, hx = 17, hz = 26, y = 13.6, step = 20, warm = true , lamp = "PendantLamp" },
	{ name = "Detention", x = 204, z = 35, hx = 17, hz = 26, y = 13.6, step = 20 , lamp = "CeilingLampBox" },
	{ name = "TrophyRoom", x = 204, z = -29, hx = 17, hz = 26, y = 13.6, step = 20, warm = true , lamp = "PendantLamp" },
	{ name = "Room101", x = -74, z = -95, hx = 11, hz = 25, y = 13.6, step = 20 , lamp = "CeilingLampDisc" },
	{ name = "MusicRoom", x = 74, z = -95, hx = 11, hz = 25, y = 13.6, step = 20, warm = true , lamp = "CeilingLampDisc" },
	{ name = "EastLab", x = 116, z = -28, hx = 15, hz = 14, y = 13.6, step = 18 , lamp = "CeilingLampDisc" },
	{ name = "Greenhouse", x = -116, z = -28, hx = 15, hz = 14, y = 13.6, step = 18 , lamp = "CeilingLampDisc" },
	-- WestDorm and EastDorm used to be here, at (+-176, -212). They were the
	-- two split dorm blocks the drawing replaced with one range at (0, -310),
	-- and when the blocks went the fixtures did not: eight ceiling panels and
	-- eight lamps hanging fifteen studs up in open air on both flanks of the
	-- Dorm Court, lighting nothing. The boarding house's own rooms are lit by
	-- PlanBuilder, one PlanRoomLight per drawn room, so there is nothing to
	-- replace them with here.
	{ name = "StaffCommon", x = -300, z = -170, hx = 36, hz = 26, y = 17, step = 22, warm = true , lamp = "PendantLamp" },
	{ name = "StaffStudies", x = -300, z = -170, hx = 36, hz = 26, y = 33, step = 22, warm = true , lamp = "PendantLamp" },
	{ name = "LibraryPassage", x = -393, z = -290, hx = 25, hz = 4, y = 10, step = 22 },
}

MapService.LitRooms = LIT_ROOMS

-- A fixture: a housing, a neon panel, and the light itself. Cheap enough to
-- put a hundred of in a school and bright enough that a corridor reads as lit
-- rather than as merely not black.
local function ceilingFixture(parent: Instance, at: Vector3, warm: boolean?, lamp: string?)
	local tint = if warm then Color3.fromRGB(255, 226, 176) else Color3.fromRGB(248, 250, 255)
	-- A room gets a real fitting; a corridor gets a strip. Four hundred studs
	-- of hallway is a hundred and eighty fixtures, and a hundred and eighty
	-- imported meshes to light a corridor is a poor trade for a panel nobody
	-- looks at. The rooms people stand still in get the lamp.
	if lamp then
		prop(lamp, CFrame.new(at + Vector3.new(0, 0.6, 0)), { hang = true })
	else
		local housing = part({
			Name = "CeilingFixture",
			Size = Vector3.new(7, 0.6, 2.6),
			CFrame = CFrame.new(at),
			Color = Color3.fromRGB(226, 224, 218),
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		})
		housing.CanCollide = false
	end
	local panel = part({
		Name = "CeilingPanel",
		Size = Vector3.new(if lamp then 1.4 else 6.2, 0.3, if lamp then 1.4 else 2),
		CFrame = CFrame.new(at - Vector3.new(0, if lamp then 2.4 else 0.4, 0)),
		Color = tint,
		Material = Enum.Material.Neon,
		Transparency = if lamp then 0.25 else 0,
		Parent = parent,
	})
	panel.CanCollide = false
	local light = Instance.new("PointLight")
	light.Brightness = 1.4
	light.Range = 34
	light.Color = tint
	light.Shadows = false -- a hundred shadow-casting lights is a slideshow
	light.Parent = panel
end

local function buildInteriorLights(parent: Instance)
	-- Cell CENTRES, not grid nodes. Spanning the room corner to corner put a
	-- fixture exactly on every boundary: nine of the library's chandeliers hung
	-- half inside its walls, the office pendants hung inside a partition, and
	-- one of the staff-room pendants hung inside the chimney. Half a cell of
	-- inset costs nothing and no fixture can reach a wall.
	for _, room in LIT_ROOMS do
		local cols = math.max(1, math.floor(room.hx * 2 / room.step))
		local rows = math.max(1, math.floor(room.hz * 2 / room.step))
		local cellX, cellZ = room.hx * 2 / cols, room.hz * 2 / rows
		for i = 0, cols - 1 do
			for j = 0, rows - 1 do
				local x = room.x - room.hx + (i + 0.5) * cellX
				local z = room.z - room.hz + (j + 0.5) * cellZ
				ceilingFixture(parent, Vector3.new(x, room.y, z), room.warm, room.lamp)
			end
		end
	end
end

-- ================= LOCKER ISLANDS =================
-- The reference corridor is not a tube with lockers painted on its walls: it
-- is a run of freestanding locker BLOCKS standing out in the floor, with a
-- bench along the foot of each and the walking lanes either side of them. That
-- is what gives a school corridor depth instead of reading as a hallway in a
-- hotel. Ours is thirty-two studs across, which is room for a seven-stud
-- island down the middle and a twelve-stud lane on each side.
-- One run of lockers: body, capping, door seams, handles, vents, a plinth and
-- a bench along the foot. `at` stands at the run's middle at floor level with
-- its local -Z pointing at whoever is looking.
local function lockerRun(parent: Instance, at: CFrame, halfW: number, halfD: number, height: number, bench: boolean)
	part({
		Name = "LockerBankRun",
		Size = Vector3.new(halfW * 2, height, halfD * 2),
		CFrame = at * CFrame.new(0, height / 2, 0),
		Color = Palette.LockerBlue,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	part({
		Name = "LockerBankCap",
		Size = Vector3.new(halfW * 2 + 0.8, 0.8, halfD * 2 + 0.8),
		CFrame = at * CFrame.new(0, height + 0.3, 0),
		Color = Color3.fromRGB(226, 224, 216),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}).CanCollide = false
	local faceZ = -(halfD + 0.05)
	local doors = math.max(2, math.floor(halfW / 2))
	for i = 0, doors - 1 do
		local dx = -halfW + (i + 0.5) * (halfW * 2 / doors)
		part({ Name = "LockerSeam", Size = Vector3.new(0.3, height - 1, 0.3), CFrame = at * CFrame.new(dx - halfW / doors, height / 2, faceZ), Color = Palette.LockerBlueDark, Parent = parent }).CanCollide = false
		for _, row in { height * 0.29, height * 0.71 } do
			part({ Name = "LockerHandle", Size = Vector3.new(0.4, 1, 0.3), CFrame = at * CFrame.new(dx + 1.2, row, faceZ), Color = Palette.BusYellow, Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "LockerVent", Size = Vector3.new(2.4, 0.4, 0.25), CFrame = at * CFrame.new(dx, row + 1.5, faceZ), Color = Palette.LockerBlueDark, Parent = parent }).CanCollide = false
		end
	end
	if bench then
		part({ Name = "LockerPlinth", Size = Vector3.new(halfW * 2 + 5, 0.5, 3.0), CFrame = at * CFrame.new(0, 0.38, -halfD - 1.6), Color = Color3.fromRGB(214, 210, 200), Material = Enum.Material.Concrete, Parent = parent }).CanCollide = false
		part({ Name = "CorridorBench", Size = Vector3.new(halfW * 2 + 2, 0.5, 2.0), CFrame = at * CFrame.new(0, 2.2, -halfD - 1.5), Color = Color3.fromRGB(178, 84, 62), Material = Enum.Material.WoodPlanks, Parent = parent })
		for _, lx in { -halfW + 1, halfW - 1 } do
			part({ Name = "CorridorBenchLeg", Size = Vector3.new(0.6, 2, 1.8), CFrame = at * CFrame.new(lx, 1, -halfD - 1.5), Color = Color3.fromRGB(120, 122, 126), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		end
	end
end

local function buildLockerIslands(parent: Instance)
	-- Against the NORTH WALL, in a run, the way a school corridor is. They
	-- used to stand out in the middle of the floor as freestanding islands,
	-- because a reference photograph had them that way -- in a corridor twice
	-- this one's width. Here the hall is thirty-two studs across and a
	-- sixteen-by-seven island down the centre of it leaves two lanes and reads
	-- as a barricade. One of them stood squarely across the principal's door.
	--
	-- The middle of a corridor is for walking down; tools/plan_check.py keeps
	-- it that way now.
	local Z = 77.6                      -- hard against the north wall at 81
	local HALF_D, HALF_W, H = 2.6, 8, 9
	for _, cx in { -150, -100, -50, 50, 100, 150 } do
		lockerRun(parent, CFrame.new(cx, 0, Z), HALF_W, HALF_D, H, true)
	end
end

-- ================= THE COURTYARD COURTS =================
-- Every school game that looks like a school has painted courts in its
-- courtyard and bunting strung over them. Ours had two empty lawns with a
-- greenhouse at one end. This is the single most recognisable thing about the
-- reference and it is flat coloured parts and triangles: cheap to build,
-- impossible to miss.

local function courtLine(parent: Instance, a: Vector3, b: Vector3, width: number)
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local mid = (a + b) / 2
	local line = part({
		Name = "CourtLine",
		Size = Vector3.new(width, 0.12, length),
		CFrame = CFrame.lookAt(mid, mid + Vector3.new(delta.X, 0, delta.Z).Unit),
		Color = Color3.fromRGB(248, 250, 252),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	line.CanCollide = false
end

local function courtRing(parent: Instance, centre: Vector3, radius: number, width: number)
	local segments = 24
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local b = (i + 1) / segments * math.pi * 2
		courtLine(
			parent,
			centre + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius),
			centre + Vector3.new(math.cos(b) * radius, 0, math.sin(b) * radius),
			width
		)
	end
end

-- Bunting: a sagging string of triangles between two points, the way it hangs
-- across a real schoolyard.
local BUNTING = {
	Color3.fromRGB(238, 78, 74), Color3.fromRGB(248, 176, 54),
	Color3.fromRGB(250, 226, 84), Color3.fromRGB(96, 200, 120),
	Color3.fromRGB(72, 158, 234), Color3.fromRGB(166, 106, 220),
}

local function bunting(parent: Instance, a: Vector3, b: Vector3, sag: number)
	local flags = 22
	local previous: Vector3? = nil
	for i = 0, flags do
		local t = i / flags
		-- a parabola is close enough to a catenary at this scale
		local droop = sag * 4 * t * (1 - t)
		local at = a:Lerp(b, t) - Vector3.new(0, droop, 0)
		if previous then
			local mid = (previous + at) / 2
			local span = at - previous
			local cord = part({
				Name = "BuntingCord",
				Size = Vector3.new(0.16, 0.16, span.Magnitude),
				CFrame = CFrame.lookAt(mid, mid + span.Unit),
				Color = Color3.fromRGB(58, 54, 50),
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			})
			cord.CanCollide = false
			local flag = part({
				Name = "BuntingFlag",
				Shape = Enum.PartType.Wedge,
				Size = Vector3.new(0.1, 2.2, 1.9),
				CFrame = CFrame.new(mid - Vector3.new(0, 1.2, 0)) * CFrame.Angles(math.pi, 0, 0),
				Color = BUNTING[(i % #BUNTING) + 1],
				Material = Enum.Material.Fabric,
				Parent = parent,
			})
			flag.CanCollide = false
		end
		previous = at
	end
end

local function buildCourt(parent: Instance, centre: Vector3, kind: string, surface: Color3, accent: Color3)
	local W, D = 56, 34
	-- the painted surface, a shade over the lawn
	local pad = part({
		Name = kind .. "Court",
		Size = Vector3.new(W + 6, 0.4, D + 6),
		-- 0.14, not 0.2: the pad and the playing surface laid on it both
		-- started at y 0, so 1,900 square studs of each court fought itself.
		CFrame = CFrame.new(centre + Vector3.new(0, 0.14, 0)),
		Color = accent,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	pad.CanCollide = false
	local floor = part({
		Name = kind .. "CourtFloor",
		Size = Vector3.new(W, 0.5, D),
		CFrame = CFrame.new(centre + Vector3.new(0, 0.25, 0)),
		Color = surface,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	floor.CanCollide = false

	local y = centre.Y + 0.5
	local hw, hd = W / 2 - 2, D / 2 - 2
	-- the boundary and the halfway line
	courtLine(parent, centre + Vector3.new(-hw, y, -hd), centre + Vector3.new(hw, y, -hd), 0.5)
	courtLine(parent, centre + Vector3.new(-hw, y, hd), centre + Vector3.new(hw, y, hd), 0.5)
	courtLine(parent, centre + Vector3.new(-hw, y, -hd), centre + Vector3.new(-hw, y, hd), 0.5)
	courtLine(parent, centre + Vector3.new(hw, y, -hd), centre + Vector3.new(hw, y, hd), 0.5)
	courtLine(parent, centre + Vector3.new(0, y, -hd), centre + Vector3.new(0, y, hd), 0.5)
	courtRing(parent, centre + Vector3.new(0, y, 0), 6, 0.5)

	if kind == "Basketball" then
		-- a key at each end, and a backboard on a post
		for _, side in { -1, 1 } do
			local keyX = side * (hw - 9)
			courtLine(parent, centre + Vector3.new(keyX, y, -5.5), centre + Vector3.new(keyX, y, 5.5), 0.5)
			courtLine(parent, centre + Vector3.new(side * hw, y, -5.5), centre + Vector3.new(keyX, y, -5.5), 0.5)
			courtLine(parent, centre + Vector3.new(side * hw, y, 5.5), centre + Vector3.new(keyX, y, 5.5), 0.5)
			local px = centre.X + side * (hw + 2)
			part({ Name = "HoopPost", Size = Vector3.new(1, 13, 1), CFrame = CFrame.new(px, centre.Y + 6.5, centre.Z), Color = Color3.fromRGB(96, 100, 106), Material = Enum.Material.Metal, Parent = parent })
			part({ Name = "HoopArm", Size = Vector3.new(3.4, 0.6, 0.6), CFrame = CFrame.new(px - side * 1.7, centre.Y + 12.4, centre.Z), Color = Color3.fromRGB(96, 100, 106), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			local board = part({ Name = "HoopBoard", Size = Vector3.new(0.4, 4.2, 7), CFrame = CFrame.new(px - side * 3.4, centre.Y + 11.6, centre.Z), Color = Color3.fromRGB(246, 248, 250), Material = Enum.Material.SmoothPlastic, Parent = parent })
			board.CanCollide = false
			local rim = part({ Name = "HoopRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 3.2, 3.2), CFrame = CFrame.new(px - side * 5.2, centre.Y + 10.2, centre.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(238, 108, 46), Material = Enum.Material.Metal, Parent = parent })
			rim.CanCollide = false
		end
	else
		-- a net across the middle, on posts that are built like posts
		for _, side in { -1, 1 } do
			local pz = centre.Z + side * (hd + 1)
			part({ Name = "NetPostFoot", Size = Vector3.new(2.4, 0.6, 2.4), CFrame = CFrame.new(centre.X, centre.Y + 0.3, pz), Color = Color3.fromRGB(72, 76, 82), Material = Enum.Material.Metal, Parent = parent })
			part({ Name = "NetPost", Size = Vector3.new(0.8, 11, 0.8), CFrame = CFrame.new(centre.X, centre.Y + 5.5, pz), Color = Color3.fromRGB(96, 100, 106), Material = Enum.Material.Metal, Parent = parent })
			part({ Name = "NetPostCap", Size = Vector3.new(1.3, 0.5, 1.3), CFrame = CFrame.new(centre.X, centre.Y + 11.2, pz), Color = Color3.fromRGB(72, 76, 82), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "NetPostCleat", Size = Vector3.new(1.4, 0.9, 0.5), CFrame = CFrame.new(centre.X, centre.Y + 3.2, pz - side * 0.7), Color = Color3.fromRGB(60, 64, 70), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "NetStay", Size = Vector3.new(0.3, 0.3, 3.0), CFrame = CFrame.new(centre.X, centre.Y + 9.6, pz + side * 1.2) * CFrame.Angles(math.rad(side * 34), 0, 0), Color = Color3.fromRGB(96, 100, 106), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		end
		part({ Name = "NetTape", Size = Vector3.new(0.28, 0.5, (hd + 1) * 2), CFrame = CFrame.new(centre.X, centre.Y + 10.3, centre.Z), Color = Color3.fromRGB(244, 246, 250), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
		local net = part({
			Name = "CourtNet",
			Size = Vector3.new(0.2, 3.4, (hd + 1) * 2),
			CFrame = CFrame.new(centre.X, centre.Y + 8.4, centre.Z),
			Color = Color3.fromRGB(232, 236, 240),
			Material = Enum.Material.Fabric,
			Transparency = 0.35,
			Parent = parent,
		})
		net.CanCollide = false
	end
end

local function buildCourtyards(parent: Instance)
	-- The courts are on the FIELD, north of the building, not in the two
	-- quadrangles. A quadrangle is a light well a hundred studs across with
	-- school on all four sides of it; a painted sports court and a bunting run
	-- inside one reads as an indoor gymnasium with the roof forgotten, which
	-- is exactly what it was being read as. Out here they have sky over them
	-- and the whole north lawn around them, which is what a court wants.
	-- BEHIND the school, beside the boarding houses -- not on the north lawn.
	-- North is the FRONT: the doors, the drive, the clock tower and the whole
	-- ceremonial approach face that way, and a painted sports court with three
	-- runs of bunting over it sat squarely across it.
	-- On the ground the drawing gives them. They stood at (-300, -250) and
	-- (300, -250), which CampusPlan draws as the Library and the Cafeteria: a
	-- basketball key painted through the library's floor slab and a volleyball
	-- court through the cafeteria's, 392 square studs of each fighting for the
	-- same plane, and two sports courts inside two buildings.
	local courts = CampusPlan.site("Ball Courts")
	local ccz = (courts.rect[2] + courts.rect[4]) / 2
	local courtX = { courts.rect[1] + 70, courts.rect[3] - 70 }
	buildCourt(parent, Vector3.new(courtX[1], 0, ccz), "Basketball", Color3.fromRGB(58, 104, 190), Color3.fromRGB(196, 86, 128))
	buildCourt(parent, Vector3.new(courtX[2], 0, ccz), "Volleyball", Color3.fromRGB(176, 74, 116), Color3.fromRGB(58, 104, 190))

	for _, cx in courtX do
		for _, bz in { ccz - 18, ccz, ccz + 18 } do
			bunting(parent, Vector3.new(cx - 52, 21, bz), Vector3.new(cx + 52, 21, bz), 5)
		end
	end

	-- and the quadrangles become quadrangles: lawn, a path across, a bench
	-- under a tree at each corner. The glasshouse and the lab stay -- a
	-- glasshouse in a school quad is what a school quad is for -- but they now
	-- stand in a garden instead of on the touchline of a volleyball court.
	for _, cx in { -116, 116 } do
		tag(part({
			Name = "QuadLawn",
			Size = Vector3.new(104, 0.4, 92),
			CFrame = CFrame.new(cx, 0.2, -2),
			Color = Color3.fromRGB(104, 168, 72),
			Material = Enum.Material.Grass,
			Parent = parent,
		}), "TexGrass").CanCollide = false
		-- The cross run is laid in two lengths either side of the long one.
		-- Two 7-wide paths crossing at the same height is 49 square studs of
		-- flicker in the middle of each quadrangle -- the exact spot the
		-- benches and the trees are arranged to look at.
		for _, run in { { Vector3.new(cx, 0.45, -48), Vector3.new(cx, 0.45, 44) },
		                { Vector3.new(cx - 50, 0.45, -2), Vector3.new(cx - 3.5, 0.45, -2) },
		                { Vector3.new(cx + 3.5, 0.45, -2), Vector3.new(cx + 50, 0.45, -2) } } do
			local delta = run[2] - run[1]
			part({
				Name = "QuadPath",
				Size = Vector3.new(if math.abs(delta.X) > 1 then delta.Magnitude else 7,
					0.3, if math.abs(delta.Z) > 1 then delta.Magnitude else 7),
				CFrame = CFrame.new((run[1] + run[2]) / 2),
				Color = Color3.fromRGB(206, 198, 182),
				Material = Enum.Material.Slate,
				Parent = parent,
			}).CanCollide = false
		end
		for _, corner in { Vector3.new(-34, 0, -34), Vector3.new(34, 0, -34),
		                   Vector3.new(-34, 0, 30), Vector3.new(34, 0, 30) } do
			meshTree(parent, Vector3.new(cx + corner.X, 0, corner.Z), 0.85)
		end
	end
end

-- ================= THE BACK OF THE PLOT =================
-- The campus used to stop eighty studs behind the library. Everything a
-- school actually keeps out the back -- the running track, the playing field,
-- the orchard, the groundsman's yard -- had nowhere to be, so the boarding
-- houses stood on the boundary with a fence behind them.
--
-- This is that land. It is walked to down an avenue from the gym, and it is
-- the reason the plot is now half as long again as it is wide.
local function buildBackCampus(parent: Instance)
	-- THE SPORTS FIELD, moved to its drawn ground.
	--
	-- It sat at (0, -400) with the track's outer lane reaching z -486, which is
	-- sixty-six studs into the South Reserve -- land the drawing holds clear so
	-- a future building has somewhere to go. build_check has been reporting 164
	-- TrackLane parts standing on it. CampusPlan puts the Sports Field at
	-- (300, 150) to (580, 320): centre (440, 235), which is where the reference
	-- aerial has it, east of the school beyond the car park.
	local FIELD = Vector3.new(440, 0, 235)

	-- ---- the running track: an oval of six lanes round a grass infield ----
	-- 136 x 80, not 150 x 86: the drawn Sports Field is 280 x 170 and the old
	-- oval was 300 x 172, so it would have hung over both ends of its own
	-- ground the moment it moved.
	local RX, RZ = 136, 80
	for lane = 0, 5 do
		local rx, rz = RX - lane * 5.5, RZ - lane * 5.5
		local segments = 64
		for i = 0, segments - 1 do
			local a0 = (i / segments) * math.pi * 2
			local a1 = ((i + 1) / segments) * math.pi * 2
			-- Every lane sat at y 0.25 and every segment was overlength by 0.6,
			-- so each lane fought its neighbours AND its own next segment: 568
			-- flickering pairs, the worst single case on the campus. The lanes
			-- step up by four hundredths each, which is under a rendering
			-- artefact and over the depth buffer's resolution.
			local ly = 0.30 + lane * 0.04
			local p0 = FIELD + Vector3.new(math.cos(a0) * rx, ly, math.sin(a0) * rz)
			local p1 = FIELD + Vector3.new(math.cos(a1) * rx, ly, math.sin(a1) * rz)
			local mid = (p0 + p1) / 2
			local run = (p1 - p0).Magnitude
			local piece = part({
				Name = "TrackLane",
				-- abutting, not overlapping: an overlength segment shares a plane
				-- with the next one along
				Size = Vector3.new(run + 0.02, 0.3, 5.4),
				CFrame = CFrame.lookAt(mid, mid + Vector3.new(-(p1 - p0).Z, 0, (p1 - p0).X)),
				Color = if lane % 2 == 0 then Color3.fromRGB(196, 84, 62) else Color3.fromRGB(208, 100, 76),
				Material = Enum.Material.Concrete,
				Parent = parent,
			})
			piece.CanCollide = false
		end
	end
	tag(part({ Name = "FieldTurf", Size = Vector3.new(RX * 2 - 70, 0.4, RZ * 2 - 70), CFrame = CFrame.new(FIELD + Vector3.new(0, 0.2, 0)), Color = Color3.fromRGB(96, 162, 68), Material = Enum.Material.Grass, Parent = parent }), "TexGrass").CanCollide = false
	-- goals at each end of the infield, and the four floodlight masts the
	-- drawing calls for. The goals were two white sticks and a bar with no
	-- net between them, and the field had no lighting at all -- CampusPlan
	-- gives it "track + pitch + four floodlight masts" and only two of the
	-- three were ever built.
	local fieldCtx = { parent = parent, part = part :: any, tag = tag :: any }
	for _, side in { -1, 1 } do
		Grounds.goal(fieldCtx, FIELD.X + side * 92, FIELD.Z, 26, 17, if side > 0 then 0 else math.pi)
	end
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local mx = FIELD.X + corner[1] * (RX - 26)
		local mz = FIELD.Z + corner[2] * (RZ - 24)
		Grounds.floodMast(fieldCtx, mx, mz, 54, math.atan2(-corner[1], -corner[2]))
	end

	-- ---- a stand along the SOUTH side, so the field has a front ----
	--
	-- It used to sit on the north side, and when the field moved east to its
	-- drawn ground the stand went with it -- straight into the Gymnasium, which
	-- CampusPlan puts at (330, 340)-(520, 470). The stand reached z 352 and the
	-- gym starts at 340. South of the track there is a clear thirty-five stud
	-- band between the car park (z <= 115) and the field's own boundary
	-- (z >= 150), which is exactly what four tiers need.
	for tier = 0, 3 do
		part({
			Name = "StandTier",
			Size = Vector3.new(210, 3, 8),
			CFrame = CFrame.new(FIELD.X, 1.5 + tier * 3, FIELD.Z - RZ - 16 - tier * 7),
			Color = Color3.fromRGB(214, 208, 196),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
		for seat = -6, 6 do
			part({
				Name = "StandSeat",
				Size = Vector3.new(11, 1, 3.4),
				CFrame = CFrame.new(FIELD.X + seat * 15, 3.4 + tier * 3, FIELD.Z - RZ - 15 - tier * 7),
				Color = if seat % 2 == 0 then Color3.fromRGB(64, 108, 196) else Color3.fromRGB(226, 92, 76),
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			}).CanCollide = false
		end
	end

	-- ---- the avenue down to it ----
	-- East of the library, not through it. Straight south from the gym runs
	-- into the library's own pediment at z = -193: the building is ninety-two
	-- studs wide and sits squarely on the centre line, so the way to the back
	-- of the plot goes round it.
	-- The back avenue is gone. It ran at x = 100 from z = -158 to the boarding
	-- houses with a lime either side of it, and the Dorm Court is now drawn
	-- over that ground -- (-140, -246) to (140, -152) -- so the avenue crossed
	-- the court's east lawn panel and six of its trees stood on it. The court's
	-- own axis walk is the way to the boarding house, and its perimeter walk is
	-- the way round.

	-- ---- the orchard, SOUTH of the library, in rows ----
	-- It began at z = -318 and ran five rows of oaks straight through the
	-- Library, which the drawing puts at (-420, -348) to (-220, -252): ten
	-- trees inside the reading room. It sits in the band between the library's
	-- back wall and the South Reserve now.
	for row = 0, 2 do
		for col = 0, 6 do
			prop("KTreeOak", CFrame.new(-232 - col * 24, 0, -360 - row * 24)
				* CFrame.Angles(0, (row * 7 + col) * 0.7, 0))
		end
	end
	-- THE KITCHEN GARDEN, east of the boarding house.
	--
	-- It has moved twice for the same reason. It stood at x 224..320,
	-- z -300..-385 and the Cafeteria was drawn over it; it was moved to
	-- x -70..24 and the boarding house was built over THAT -- its beds ran
	-- from z -368.5 to -377.5 and the range's south wall is on z = -370, so
	-- the vegetable beds were inside the building and its back steps were
	-- standing in them. It sits east of the range now, in the band between
	-- the Cafeteria's south wall and the South Reserve, which the drawing
	-- gives to nothing at all.
	local GX, GZ = 250, 0
	-- a plank fence round it. Eighteen studs apart: a panel measures seventeen
	-- and a half across, so any tighter pitch is a row of fences standing
	-- inside each other. The gate is the corner post, and both runs start
	-- clear of it.
	prop("KFenceGate", CFrame.new(GX - 70, 0, GZ - 340))
	-- four panels, not five: a fifth reached z -477 and the South Reserve
	-- starts at -420
	for i = 0, 3 do
		prop("KFencePlanks", CFrame.new(GX - 70, 0, GZ - 352 - i * 18) * CFrame.Angles(0, math.rad(90), 0))
	end
	for i = 0, 3 do
		prop("KFencePlanks", CFrame.new(GX - 51 + i * 18, 0, GZ - 340))
	end
	-- and the kitchen garden's beds
	for row = 0, 3 do
		for col = 0, 3 do
			part({
				Name = "GardenBed",
				Size = Vector3.new(20, 1.4, 9),
				CFrame = CFrame.new(GX - 54 + col * 26, 0.7, GZ - 358 - row * 15),
				Color = Color3.fromRGB(122, 88, 60),
				Material = Enum.Material.Ground,
				Parent = parent,
			})
			part({
				Name = "GardenCrop",
				Size = Vector3.new(18, 2.2, 7),
				CFrame = CFrame.new(GX - 54 + col * 26, 2, GZ - 358 - row * 15),
				Color = Color3.fromRGB(104, 158, 74),
				Material = Enum.Material.Grass,
				Parent = parent,
			}).CanCollide = false
		end
	end

	-- ---- the groundsman's yard: three sheds and a wall ----
	-- West of the staff lodge, not inside it: at x = -320 these stood in the
	-- middle of the common room, whose own footprint runs to -342.
	for index, off in { Vector3.new(-374, 0, -180), Vector3.new(-374, 0, -212), Vector3.new(-374, 0, -244) } do
		part({ Name = "ShedWall", Size = Vector3.new(24, 12, 20), CFrame = CFrame.new(off + Vector3.new(0, 6, 0)), Color = Color3.fromRGB(126, 92, 66), Material = Enum.Material.WoodPlanks, Parent = parent })
		for _, side in { -1, 1 } do
			part({ Name = "ShedRoof", Size = Vector3.new(26, 1.2, 12), CFrame = CFrame.new(off + Vector3.new(0, 14, side * 5)) * CFrame.Angles(side * math.rad(22), 0, 0), Color = Color3.fromRGB(90, 100, 114), Material = Enum.Material.Slate, Parent = parent }).CanCollide = false
		end
		local door = part({ Name = "ShedDoor", Size = Vector3.new(8, 9, 0.6), CFrame = CFrame.new(off + Vector3.new(0, 4.5, 10.2)), Color = Color3.fromRGB(96, 68, 46), Material = Enum.Material.WoodPlanks, Parent = parent })
		door.CanCollide = false
		local _ = index
	end
end

-- ================= PLANTING =================
-- The lawns were lawns: a flat green surface out to the wall with a tree
-- every so often. What the reference art has and this did not is UNDERGROWTH
-- -- bushes, tufts, flowers and loose stone at ankle height, which is what
-- stops a field reading as a billiard table with scenery standing on it.
--
-- Scattered rather than placed, from a seeded RNG, so the same campus comes
-- out of every server and nobody has to name three hundred coordinates.
-- ================= FURNISHING THE BOARDING HOUSE =================
-- PlanBuilder renders the shell -- floors, cut walls, windows, stairs, roof --
-- and stops there, because a drawing says where the rooms are and not what is
-- in them. This puts the boarding house's contents in the rooms the drawing
-- names: beds and lockers in every "Dorm n", a kitchen and seating in the
-- common room, basins and cubicles in the laundry, a desk run in the study.
--
-- Every rect comes from CampusPlan.rooms, so nothing here holds a coordinate:
-- move a partition in the drawing and the beds move with it.
local function furnishDorms(parent: Instance, beds: { BasePart })
	local b = CampusPlan.building("Student Dorms")
	if not b then
		return
	end
	local ACCENT = { Color3.fromRGB(70, 130, 220), Color3.fromRGB(232, 110, 170) }
	for storey = 1, #b.storeys do
		local y = b.storeys[storey].y
		for _, room in CampusPlan.rooms(b, storey) do
			local r = room.rect
			local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
			local hw, hd = (r[3] - r[1]) / 2, (r[4] - r[2]) / 2
			if string.match(room.name, "^Dorm %d") then
				-- four beds down the two long walls, head to the wall, with a
				-- locker and a bedside table to each
				local accent = ACCENT[(math.floor(cx / 56) % 2) + 1]
				for i, spot in {
					{ x = -hw + 9, z = -hd + 9, yaw = 0 },
					{ x = -hw + 9, z = hd - 9, yaw = 0 },
					{ x = hw - 9, z = -hd + 9, yaw = math.pi },
					{ x = hw - 9, z = hd - 9, yaw = math.pi },
				} do
					local at = CFrame.new(cx + spot.x, y, cz + spot.z) * CFrame.Angles(0, spot.yaw, 0)
					part({ Name = "BedFrame", Size = Vector3.new(7, 1.6, 12), CFrame = at * CFrame.new(0, 2.8, 0), Color = Color3.fromRGB(105, 76, 48), Material = Enum.Material.Wood, Parent = parent })
					local shade = 0.84 + (i % 3) * 0.11
					local mattress = part({
						Name = "DormBed",
						Size = Vector3.new(6.4, 1, 11),
						CFrame = at * CFrame.new(0, 3.9, 0),
						Color = Color3.new(math.min(1, accent.R * shade), math.min(1, accent.G * shade), math.min(1, accent.B * shade)),
						Material = Enum.Material.Fabric,
						Parent = parent,
					})
					part({ Name = "Pillow", Size = Vector3.new(4.5, 0.8, 2.6), CFrame = at * CFrame.new(0, 4.6, -3.8), Color = Color3.fromRGB(240, 240, 232), Material = Enum.Material.Fabric, Parent = parent })
					part({ Name = "BedBlanket", Size = Vector3.new(6.6, 0.4, 5.0), CFrame = at * CFrame.new(0, 4.5, 2.6), Color = Color3.fromRGB(214, 210, 198), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
					prop("BedsideDrawers", at * CFrame.new(0, 2, -6.4))
					prop("TableLamp", at * CFrame.new(0, 4.6, -6.4))
					table.insert(beds, mattress)
				end
				-- a locker run against the far short wall, NOT down the middle
				-- of the room: the middle of a bedroom is the floor you walk
				-- on, and a nine-stud bank standing on it is the same fault as
				-- the locker islands that used to block the main corridor.
				lockerRun(parent, CFrame.new(cx, y, cz - hd + 1.4), 9, 1.2, 9, false)
				prop("PottedPlant2", CFrame.new(cx + hw - 5, y + 2, cz + hd - 5))
			elseif room.name == "Common room" then
				prop("RefectoryTable", CFrame.new(cx, y + 2, cz + 6))
				for _, sx in { -8, 0, 8 } do
					prop("LoungeStool", CFrame.new(cx + sx, y + 2, cz - 1))
				end
				for index, kind in { "Sink2", "Stove2", "KitchenCabinet", "Fridge2" } do
					prop(kind, CFrame.new(cx - 22 + index * 10, y + 2, cz - hd + 4))
				end
				prop("Sofa", CFrame.new(cx - 14, y + 2, cz + hd - 6) * CFrame.Angles(0, math.pi, 0))
				prop("Bookshelf", CFrame.new(cx + 18, y + 2, cz + hd - 3) * CFrame.Angles(0, math.pi, 0))
				prop("CoatRack", CFrame.new(cx + hw - 5, y + 2, cz - hd + 5))
			elseif room.name == "Laundry" then
				part({ Name = "WashroomFloor", Size = Vector3.new(hw * 2 - 3, 0.4, hd * 2 - 3), CFrame = CFrame.new(cx, y + 0.35, cz), Color = Color3.fromRGB(206, 214, 216), Material = Enum.Material.CeramicTiles, Parent = parent }).CanCollide = false
				for index = 0, 2 do
					prop("Basin2", CFrame.new(cx - 16 + index * 11, y + 2, cz - hd + 4))
					prop("Mirror2", CFrame.new(cx - 16 + index * 11, y + 7, cz - hd + 2.6))
					prop("Toilet2", CFrame.new(cx - 16 + index * 11, y + 2, cz + hd - 4) * CFrame.Angles(0, math.pi, 0))
				end
				prop("Shower", CFrame.new(cx + hw - 6, y + 2, cz + hd - 5) * CFrame.Angles(0, math.pi, 0))
				prop("LaundryStack", CFrame.new(cx + hw - 6, y + 2, cz - hd + 5))
				prop("Bin2", CFrame.new(cx + hw - 6, y + 2, cz))
			elseif room.name == "Study" then
				for row = 0, 1 do
					for col = 0, 2 do
						prop("SchoolDesk", CFrame.new(cx - 18 + col * 18, y + 2, cz - 8 + row * 16))
						prop("Chair", CFrame.new(cx - 18 + col * 18, y + 2, cz - 3 + row * 16) * CFrame.Angles(0, math.pi, 0))
					end
				end
				prop("Bookshelf", CFrame.new(cx, y + 2, cz + hd - 3) * CFrame.Angles(0, math.pi, 0))
			elseif room.name == "Warden's flat" then
				prop("Sofa", CFrame.new(cx - 8, y + 2, cz + hd - 6) * CFrame.Angles(0, math.pi, 0))
				prop("Table2", CFrame.new(cx + 12, y + 2, cz))
				prop("Chair", CFrame.new(cx + 12, y + 2, cz - 5))
				prop("Bookshelf", CFrame.new(cx - 16, y + 2, cz - hd + 3))
				prop("Television", CFrame.new(cx - 8, y + 5.4, cz - hd + 4))
			elseif room.name == "Dorm lobby" then
				prop("Sofa", CFrame.new(cx - 12, y + 2, cz - hd + 6))
				prop("PottedPlant2", CFrame.new(cx + hw - 6, y + 2, cz - hd + 6))
				prop("Bookshelf", CFrame.new(cx + 12, y + 2, cz - hd + 3) * CFrame.Angles(0, math.pi, 0))
			end
		end
	end
end

local function buildPlanting(parent: Instance)
	local COVER = { "KBush", "KBushLarge", "KGrass", "KGrass", "KFlowerRed",
		"KFlowerYellow", "KFlowerPurple", "KRockSmall" }
	local SCRUB = { "KBushLarge", "KGrass", "KRockSmall", "KRockLarge", "KStump" }
	for _, zone in {
		-- the front approach, either side of the road
		{ min = Vector2.new(-260, 140), max = Vector2.new(-130, 250), pool = COVER, count = 30, seed = 4001 },
		{ min = Vector2.new(130, 140), max = Vector2.new(260, 250), pool = COVER, count = 30, seed = 4002 },
		-- the outer lawns, east and west of the school
		{ min = Vector2.new(-390, -120), max = Vector2.new(-250, 120), pool = SCRUB, count = 26, seed = 4003 },
		{ min = Vector2.new(250, -120), max = Vector2.new(390, 120), pool = SCRUB, count = 26, seed = 4004 },
		-- behind the school, between the library and the boarding houses
		{ min = Vector2.new(-120, -320), max = Vector2.new(-60, -180), pool = COVER, count = 22, seed = 4005 },
		{ min = Vector2.new(52, -320), max = Vector2.new(74, -180), pool = COVER, count = 14, seed = 4006 },
		-- the far back, round the track
		-- kept off the boundary itself: the far ridge of rock outcrops runs
		-- along it, and scatter has no idea the outcrops are there
		{ min = Vector2.new(-388, -500), max = Vector2.new(-352, -310), pool = SCRUB, count = 14, seed = 4007 },
		{ min = Vector2.new(210, -498), max = Vector2.new(352, -424), pool = SCRUB, count = 20, seed = 4008 },
		{ min = Vector2.new(-170, -496), max = Vector2.new(170, -478), pool = COVER, count = 20, seed = 4009 },
		-- the boarding houses' gardens
		{ min = Vector2.new(-240, -190), max = Vector2.new(-115, -160), pool = COVER, count = 16, seed = 4010 },
		{ min = Vector2.new(115, -190), max = Vector2.new(240, -160), pool = COVER, count = 16, seed = 4011 },
		-- the two quadrangles, at the foot of their corner trees
		{ min = Vector2.new(-165, -44), max = Vector2.new(-68, 40), pool = COVER, count = 14, seed = 4012, inside = true },
		{ min = Vector2.new(68, -44), max = Vector2.new(165, 40), pool = COVER, count = 14, seed = 4013, inside = true },
	} do
		scatter({
			min = zone.min, max = zone.max, y = 0,
			pool = zone.pool, count = zone.count, seed = zone.seed, margin = 3,
			inside = zone.inside,
		})
	end
	-- loose rock along the boundary, where the ridge meets the lawn
	local rng = Random.new(4100)
	for i = 1, 40 do
		-- 18 to 44 studs inside the boundary, not 6 to 22: the estate fence
		-- stands on that line now, and a boulder with an eleven-stud reach
		-- thrown six studs off it is a boulder through the railings
		local pos = onBoundary(i / 40 + rng:NextNumber(-0.004, 0.004),
			CORE_X0 + rng:NextNumber(18, 44), CORE_Z0 + rng:NextNumber(18, 44),
			CORE_X1 - rng:NextNumber(18, 44), CORE_Z1 - rng:NextNumber(18, 44))
		-- one of these landed on the ceremonial axis, between the gate and the
		-- front doors, which is the one strip of ground on the campus that has
		-- to stay clear; and three of them landed on the bike track, because
		-- this loop was the one scatter that never asked whether the drawing
		-- had spoken for the ground it was standing on
		local onAxis = math.abs(pos.X) < 46 and pos.Z > 124
		if not onAxis and not scatterBlocked(pos.X, pos.Z, 11) and claimGround(pos, 11) then
			prop(if i % 3 == 0 then "KRockTall" else "KRockLarge",
				CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		end
	end
end

-- ================= FINDING YOUR WAY =================
-- A school you cannot navigate is a maze with lockers. Three things fix that,
-- and they are the three things real buildings use: a board at the door that
-- lists everything, a sign hanging over every room you might be looking for,
-- and a line on the floor you can follow without reading anything at all.
local ROUTES = {
	{ id = "math", label = "ROOM 101 · MATHS", icon = "➗", color = Color3.fromRGB(120, 176, 255),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(-74, 0, 65), Vector3.new(-74, 0, -60) } },
	{ id = "music", label = "MUSIC ROOM", icon = "🎵", color = Color3.fromRGB(212, 160, 240),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(74, 0, 65), Vector3.new(74, 0, -60) } },
	{ id = "biology", label = "GREENHOUSE · BIOLOGY", icon = "🧬", color = Color3.fromRGB(150, 220, 130),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(-116, 0, 65), Vector3.new(-116, 0, -8) } },
	{ id = "chemistry", label = "EAST LAB · CHEMISTRY", icon = "⚗️", color = Color3.fromRGB(150, 240, 190),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(116, 0, 65), Vector3.new(116, 0, -8) } },
	{ id = "assembly", label = "ASSEMBLY HALL", icon = "🎭", color = Color3.fromRGB(255, 176, 88),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(0, 0, -60) } },
}

-- Doors worth signposting from the hall, and what to call them.
local DOOR_SIGNS = {
	{ label = "ROOM 101 · MATHS", icon = "➗", at = Vector3.new(-74, 0, -62), face = 1, color = Color3.fromRGB(120, 176, 255) },
	{ label = "MUSIC ROOM", icon = "🎵", at = Vector3.new(74, 0, -62), face = 1, color = Color3.fromRGB(212, 160, 240) },
	{ label = "ASSEMBLY HALL", icon = "🎭", at = Vector3.new(0, 0, -62), face = 1, color = Color3.fromRGB(255, 176, 88) },
	{ label = "GREENHOUSE", icon = "🧬", at = Vector3.new(-116, 0, -9), face = 1, color = Color3.fromRGB(150, 220, 130) },
	{ label = "EAST LAB", icon = "⚗️", at = Vector3.new(116, 0, -9), face = 1, color = Color3.fromRGB(150, 240, 190) },
	-- These two were the wrong way round for every build the west wing has
	-- existed: the office is the NORTH half of the wing and the cafeteria the
	-- south, and the signs named each other's rooms.
	{ label = "OFFICE · THE STORE", icon = "🛒", at = Vector3.new(-204, 0, 62), face = 1, color = Color3.fromRGB(214, 226, 235) },
	{ label = "CAFETERIA", icon = "🍔", at = Vector3.new(-204, 0, -50), face = -1, color = Color3.fromRGB(235, 214, 156) },
	{ label = "TROPHY HALL", icon = "🏆", at = Vector3.new(204, 0, -50), face = -1, color = Color3.fromRGB(240, 226, 190) },
	{ label = "DETENTION", icon = "⛓️", at = Vector3.new(204, 0, 62), face = 1, color = Color3.fromRGB(226, 96, 88) },
}

local houseBoard: BasePart? = nil

local function buildWayfinding(parent: Instance)
	-- ---- the coloured lines on the floor ----
	for index, route in ROUTES do
		-- every route leaves the lobby down the same hall, so they are fanned
		-- apart by a stud and a bit each. Without this they are one stripe,
		-- and a stripe that leads everywhere leads nowhere.
		local spread = (index - 3) * 1.2
		for i = 1, #route.path - 1 do
			local from, to = route.path[i], route.path[i + 1]
			local delta = to - from
			local length = delta.Magnitude
			if length < 1 then
				continue
			end
			-- shift across the run, whichever way it runs
			local sideways = if math.abs(delta.X) > math.abs(delta.Z)
				then Vector3.new(0, 0, spread)
				else Vector3.new(spread, 0, 0)
			-- 0.34, not 0.2. The floors and the lobby runner are 0.16 thick
			-- slabs centred at 0.2, so a line at 0.2 was EXACTLY coplanar with
			-- them and the two z-fought: the wayfinding stripes flickered
			-- through the carpet in bands wherever they crossed it. A line is
			-- painted ON a floor, so it sits on top of one.
			-- 0.49, not 0.34. Outdoors the quad lawn tops out at 0.40 and a
			-- 0.1-thick line centred on 0.34 topped out at 0.39, one hundredth
			-- of a stud under it, so every run of route line that crosses a
			-- quadrangle flickered through the grass. 0.49 puts the line on
			-- the paths' own course (0.30 .. 0.60) and clear of both.
			local mid = from + delta * 0.5 + sideways + Vector3.new(0, 0.49, 0)
			local horizontal = Vector3.new(delta.X, 0, delta.Z).Unit
			local line = part({
				Name = "Route_" .. route.id,
				-- overlength by a stud so the corners meet instead of leaving
				-- a gap the eye has to jump
				Size = Vector3.new(0.9, 0.1, length + 1),
				CFrame = CFrame.lookAt(mid, mid + horizontal),
				Color = route.color,
				Material = Enum.Material.Neon,
				Parent = parent,
			})
			line.CanCollide = false
			line.CanQuery = false
		end
	end

	-- ---- a sign hanging in the hall over every door ----
	for _, door in DOOR_SIGNS do
		local sign = part({
			Name = "DoorSign",
			Size = Vector3.new(18, 4, 0.6),
			CFrame = CFrame.new(door.at + Vector3.new(0, 12.4, door.face * 2.5)),
			Color = Palette.Blackboard,
			Parent = parent,
		})
		sign.CanCollide = false
		signText(sign, door.icon .. " " .. door.label, door.color, Enum.NormalId.Front)
		signText(sign, door.icon .. " " .. door.label, door.color, Enum.NormalId.Back)
		local lamp = Instance.new("SurfaceLight")
		lamp.Face = if door.face > 0 then Enum.NormalId.Front else Enum.NormalId.Back
		lamp.Range = 20
		lamp.Brightness = 1.3
		lamp.Color = door.color
		lamp.Parent = sign
	end

	-- ---- the House Cup board, opposite the directory ----
	local cupBack = part({ Name = "HouseBoardFrame", Size = Vector3.new(20, 22, 1), CFrame = CFrame.new(24, 12, 120.5), Color = Color3.fromRGB(58, 40, 30), Material = Enum.Material.WoodPlanks, Parent = parent })
	cupBack.CanCollide = false
	local cupBoard = part({ Name = "HouseBoard", Size = Vector3.new(18, 20, 0.4), CFrame = CFrame.new(24, 12, 119.9), Color = Palette.Blackboard, Parent = parent })
	cupBoard.CanCollide = false
	signText(cupBoard, "THE HOUSE CUP", Palette.BusYellow, Enum.NormalId.Front)
	houseBoard = cupBoard

	-- ---- the directory, where you come in ----
	local boardBack = part({ Name = "DirectoryBoard", Size = Vector3.new(20, 22, 1), CFrame = CFrame.new(-24, 12, 120.5), Color = Color3.fromRGB(58, 40, 30), Material = Enum.Material.WoodPlanks, Parent = parent })
	boardBack.CanCollide = false
	local face = part({ Name = "DirectoryFace", Size = Vector3.new(18, 20, 0.4), CFrame = CFrame.new(-24, 12, 119.9), Color = Palette.Blackboard, Parent = parent })
	face.CanCollide = false
	signText(face, "DIRECTORY\n\nGROUND\n101 MATHS · WEST\nMUSIC · EAST\nGREENHOUSE · WEST YARD\nEAST LAB · EAST YARD\nASSEMBLY HALL · STRAIGHT ON\n\nUPSTAIRS\nART · HISTORY\nCOMPUTERS · LANGUAGES\nSTUDY · DRAMA\nNURSE · COMMON ROOM\n\nOUTSIDE\nGYMNASIUM · EAST\nCAFETERIA · SOUTH EAST\nLIBRARY · SOUTH WEST\nDETENTION · WEST", Palette.Chalk, Enum.NormalId.Front)

	-- ---- overhead direction signs at the two junctions ----
	for _, spec in {
		{ at = Vector3.new(-74, 0, 66), text = "◀ 101 MATHS   GREENHOUSE ▶" },
		{ at = Vector3.new(74, 0, 66), text = "◀ EAST LAB   MUSIC ▶" },
		{ at = Vector3.new(0, 0, 66), text = "GYM ▼    UPSTAIRS ▲" },
	} do
		local hanger = part({ Name = "JunctionSign", Size = Vector3.new(26, 3.6, 0.5), CFrame = CFrame.new(spec.at + Vector3.new(0, 13.2, 0)), Color = Color3.fromRGB(30, 34, 44), Parent = parent })
		hanger.CanCollide = false
		signText(hanger, spec.text, Palette.BusYellow, Enum.NormalId.Front)
		signText(hanger, spec.text, Palette.BusYellow, Enum.NormalId.Back)
		part({ Name = "JunctionRod", Size = Vector3.new(0.3, 2.6, 0.3), CFrame = CFrame.new(spec.at + Vector3.new(-10, 16.2, 0)), Color = Color3.fromRGB(140, 144, 152), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		part({ Name = "JunctionRod", Size = Vector3.new(0.3, 2.6, 0.3), CFrame = CFrame.new(spec.at + Vector3.new(10, 16.2, 0)), Color = Color3.fromRGB(140, 144, 152), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	end
end

function MapService.Build(): Map
-- Every part the school builds defaults to queryable, touchable and
-- shadow-casting. On a campus this size that is thousands of parts taxing
-- every raycast, every Touched event and every light update — which is a large
-- part of why moving around felt heavy.
--
-- A part that is anchored, non-collidable and carries no interaction is
-- decoration by definition: nothing should ever raycast it, touch it, or ask
-- it for a shadow. Structure (anything you can walk into) keeps every flag, so
-- the aim reticle still stops at walls.
-- Light every window from the inside.
--
-- The night references are lit almost entirely by their own windows: a wall of
-- warm gold rectangles is what makes the building read as a building at 21:00
-- rather than as a dark mass. There are fifteen separate places in this file
-- that put glass in a wall, and touching all fifteen is how the last four
-- passes of this kind went wrong -- one gets missed, and one facade stays dark.
--
-- So this runs ONCE over the finished map instead. Anything that is glass and
-- is called a window gets a neon leaf in the same plane, inset a little so the
-- frame still reads around it, and every third one carries the actual light.
-- One PointLight per window would be several hundred lights on a campus this
-- size; per bay is what the engine can afford and what the eye reads anyway.
local WINDOW_LIT = Color3.fromRGB(255, 196, 107)
local WINDOW_DARK = Color3.fromRGB(58, 68, 80)
local LANTERN = Color3.fromRGB(255, 220, 160)

local function litWindows(root: Instance)
	local lit, lights = 0, 0

	-- Some windows are lit already. The staff quarters build their own
	-- QuartersWinGlow panes, and this pass put a WindowLeaf in exactly the same
	-- plane over twenty-four of them: two emissive surfaces fighting for the
	-- same pixels, which at night flickers hard. Anything already glowing is
	-- left alone.
	local alreadyLit: { BasePart } = {}
	for _, existing in root:GetDescendants() do
		if existing:IsA("BasePart") and existing.Material == Enum.Material.Neon then
			table.insert(alreadyLit, existing)
		end
	end
	local function isAlreadyLit(at: Vector3): boolean
		for _, glow in alreadyLit do
			if (glow.Position - at).Magnitude < 2.5 then
				return true
			end
		end
		return false
	end
	for _, glass in root:GetDescendants() do
		if not glass:IsA("BasePart") or glass.Material ~= Enum.Material.Glass then
			continue
		end
		local n = glass.Name
		if not (n:find("Window") or n:find("Pane") or n:find("Glass")) then
			continue
		end
		-- vending machines, water coolers and door lights are glass too, and a
		-- glowing drinks cabinet is not the effect we are after
		if n:find("Vending") or n:find("Cooler") or n:find("Jug") or n:find("Canopy") then
			continue
		end
		local size = glass.Size
		if size.X * size.Y * size.Z < 1.2 then
			continue
		end
		if isAlreadyLit(glass.Position) then
			continue
		end
		local leafFor: BasePart? = nil

		-- The wall normal is the part's thinnest axis. But several of these
		-- "windows" are BANDS -- one part running the whole length of a facade
		-- -- and lighting a band gives a forty-stud bar of neon, which is what
		-- turned the school into a sheet of light. A band is cut into separate
		-- panes instead, which both drops the emissive area by two thirds and
		-- is what the reference actually shows: a row of individual lit
		-- windows with dark wall between them.
		local thin = math.min(size.X, size.Y, size.Z)
		local runAxis, runLength
		if thin == size.Z then
			runAxis, runLength = "X", size.X
		elseif thin == size.X then
			runAxis, runLength = "Z", size.Z
		else
			runAxis, runLength = "X", size.X
		end

		-- Split in BOTH directions. Cutting only along the length still left
		-- panes sixteen studs tall where a glass wall spans two storeys, and a
		-- lit rectangle that size is a light panel, not a window.
		local PANE, PITCH = 4.4, 9.0
		local VPANE, VPITCH = 4.6, 8.0
		local height = size.Y
		if thin == size.Y then
			height = size.Z
		end
		local across = math.max(1, math.floor(runLength / PITCH))
		local up = math.max(1, math.floor(height / VPITCH))
		local paneRun = if across > 1 then PANE else math.max(runLength - 0.7, 0.4)
		local paneUp = if up > 1 then VPANE else math.max(height - 0.7, 0.4)

		local leaf: Vector3
		if thin == size.Z then
			leaf = Vector3.new(paneRun, paneUp, 0.16)
		elseif thin == size.X then
			leaf = Vector3.new(0.16, paneUp, paneRun)
		else
			leaf = Vector3.new(paneRun, 0.16, paneUp)
		end

		local p = glass.Position
		local seed = math.floor(p.X * 7.3 + p.Y * 3.1 + p.Z * 11.7)
		local dark = seed % 9 == 0

		local gapX = if across > 1 then runLength / across else 0
		local gapY = if up > 1 then height / up else 0
		for i = 1, across do
			for j = 1, up do
				local slide = if across > 1 then (i - 0.5) * gapX - runLength / 2 else 0
				local rise = if up > 1 then (j - 0.5) * gapY - height / 2 else 0
				local offset
				if thin == size.Y then
					offset = if runAxis == "X" then CFrame.new(slide, 0, rise) else CFrame.new(rise, 0, slide)
				elseif runAxis == "X" then
					offset = CFrame.new(slide, rise, 0)
				else
					offset = CFrame.new(0, rise, slide)
				end
				local paneDark = dark or (seed + i * 7 + j * 23) % 11 == 0
				local pane = part({
					Name = "WindowLeaf",
					Size = leaf,
					CFrame = glass.CFrame * offset,
					Color = if paneDark then WINDOW_DARK else WINDOW_LIT,
					Material = if paneDark then Enum.Material.SmoothPlastic else Enum.Material.Neon,
					Transparency = if paneDark then 0.2 else 0.34,
					Parent = glass.Parent,
				})
				pane.CanCollide = false
				pane.CastShadow = false
				lit += 1
				if not paneDark then
					leafFor = pane
				end
			end
		end

		if not dark and leafFor and seed % 5 == 0 then
			-- one light per BAY, not per pane: a light behind every window on a
			-- campus this size is several hundred of them, and the eye reads a
			-- lit row the same either way
			local light = Instance.new("PointLight")
			light.Color = LANTERN
			light.Brightness = 0.8
			light.Range = math.clamp(math.max(size.X, size.Y, size.Z) * 1.6, 12, 22)
			light.Shadows = false
			light.Parent = leafFor
			lights += 1
		end
	end
	print(("[map] lit %d windows, %d of them carrying light"):format(lit, lights))
end

local function optimize(root: Instance)
	for _, part in root:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part:IsA("MeshPart") then
			-- precise mesh collision on scenery is the most expensive default
			-- in the engine and buys us nothing
			part.CollisionFidelity = Enum.CollisionFidelity.Box
		end
		-- Signage is never something you walk into. Generated geometry makes it
		-- very easy to plant a board or a post exactly where a door goes, and
		-- the only reliable defence is that none of it is ever solid.
		local n = part.Name
		if n:find("Sign") or n:find("Plaque") or n:find("Board") or n:find("Banner")
			or n:find("Crest") or n:find("Emblem") or n:find("Pennant") or n:find("Motto")
		then
			part.CanCollide = false
		end
		if not part.Anchored or part.CanCollide then
			continue
		end
		local interactive = part:FindFirstChildWhichIsA("ProximityPrompt")
			or part:FindFirstChildWhichIsA("ClickDetector")
			or part:FindFirstChildWhichIsA("SurfaceGui")
			or part:FindFirstChildWhichIsA("BillboardGui")
		if interactive then
			continue
		end
		part.CanQuery = false
		part.CanTouch = false
		if part.Size.Magnitude < 12 then
			part.CastShadow = false
		end
	end
end

	trimRuns = {}
	propRequests = {}
	scatterBlocks = {}

	-- Ground the drawing has spoken for is not lawn.
	--
	-- The scatter avoids other props and it avoids the rectangles in NO_TREES,
	-- and NO_TREES is a hand-kept list -- so every feature added to the drawing
	-- since is fair game to it. The Bike Track came out with three boulders and
	-- eight trees on it. Every drawn site blocks the scatter now, whatever it
	-- is and whenever it was drawn.
	--
	-- AFTER the reset above, not before it: Build clears scatterBlocks a few
	-- lines into itself, so a registration made at the top of the function is
	-- thrown away before a single builder runs.
	for _, site in CampusPlan.SITE do
		blockScatter(
			(site.rect[1] + site.rect[3]) / 2,
			(site.rect[2] + site.rect[4]) / 2,
			(site.rect[3] - site.rect[1]) / 2 + 8,
			(site.rect[4] - site.rect[2]) / 2 + 8
		)
	end

	local folder = Instance.new("Folder")
	folder.Name = "CrumbworthHigh"

	buildTerrain()

	-- ================= THE FLOOR PLAN =================
	-- Followed from the CAD plan: a symmetric school. Central spine =
	-- entrance lobby (south) -> atrium -> big gym hall (north, protruding).
	-- Each wing = ring corridor around an open inner courtyard, rooms on the
	-- perimeter. Main corridor (the conveyor) runs the full width at z=70.
	--
	--   x: -224 .. 224      z: -124 (north) .. 124 (south), gym to -146
	--   S rooms row  z[76,124]   : plots A/B + janitor | LOBBY | mirrored
	--   Main corridor z[64,76]   : full width, lockers, conveyor line
	--   Middle band  z[-64,64]   : outer col rooms | inner corridor |
	--                              courtyard | spine atrium | mirrored
	--   N corridor   z[-64,-52]  : per wing
	--   N rooms row  z[-124,-64] : plots C/D + classroom | gym flanks
	-- ===================================================

	-- interior base slab
	-- built around the sanctum shaft rather than over it
	-- and the structural slab under everything is lower again, at -0.20
	floorWithHole(folder, "SchoolBaseFloor", Vector3.new(0, -0.7, 0), Vector2.new(448, 248), nil, "TexFloorTile")

	-- main corridor floor + stripe (the conveyor line)
	-- Its top is at -0.06, not 0. The room floors either side run 15 studs
	-- into this slab -- the principal's office and the detention room are both
	-- drawn z 6..64 and the corridor slab is z 49..81 -- and all of them topped
	-- out at exactly 0, so 1,200 square studs of corridor flickered against the
	-- two rooms it runs under. The corridor is the lower course; the room
	-- floors lie on it, which is also the order they are built in.
	tag(part({
		Name = "HallwayFloor",
		Size = Vector3.new(448, 1, 32),
		CFrame = CFrame.new(0, -0.56, 65),
		Color = Color3.fromRGB(196, 194, 188),
		Parent = folder,
	}), "TexFloorTile")
	part({
		Name = "HallwayStripe",
		Size = Vector3.new(440, 0.2, 2.4),
		-- 0.22, not 0.11. The floor tops out at 0, the tile band starts at
		-- 0.02 and this started at 0.01, so a 440-stud run of corridor had
		-- three surfaces inside a fiftieth of a stud of each other.
		CFrame = CFrame.new(0, 0.22, 65),
		Color = Palette.BusYellow,
		Material = Enum.Material.Neon,
		Parent = folder,
	})

	-- ---------------- plots: 8 homerooms on the perimeter rows ----------------
	local plots: { Plot } = {}
	-- South row: doors NORTH onto the main corridor. North row: doors SOUTH
	-- onto the wing corridor. Both rows had these the wrong way round, and it
	-- sealed all eight homerooms.
	--
	-- CFrame.lookAt puts the look direction on local -Z, so local +Z -- which
	-- is a plot's front, where its gate and sign go -- points AWAY from the
	-- target. Aiming a south plot at c - Z therefore put its front at z = 127,
	-- flat against the exterior facade, and its solid back wall of lockers at
	-- z = 80: exactly across the bay opening the interior walls deliberately
	-- leave clear. Every homeroom was a closed box with its door facing a
	-- brick wall. Nothing in the game complained, because nothing in the game
	-- ever needed to walk in.
	for i, x in { -190, -122 } do
		local c = Vector3.new(x, 0, 101)
		table.insert(plots, buildPlot(i, CFrame.lookAt(c, c + Vector3.new(0, 0, 1)), folder))
	end
	for i, x in { 122, 190 } do
		local c = Vector3.new(x, 0, 101)
		table.insert(plots, buildPlot(2 + i, CFrame.lookAt(c, c + Vector3.new(0, 0, 1)), folder))
	end
	for i, x in { -190, -122 } do
		local c = Vector3.new(x, 0, -92)
		table.insert(plots, buildPlot(4 + i, CFrame.lookAt(c, c + Vector3.new(0, 0, -1)), folder))
	end
	for i, x in { 122, 190 } do
		local c = Vector3.new(x, 0, -92)
		table.insert(plots, buildPlot(6 + i, CFrame.lookAt(c, c + Vector3.new(0, 0, -1)), folder))
	end

	-- ---------------- room floors (plan rooms, both wings) ----------------
	buildZone(folder, "Cafeteria", Vector3.new(-204, 0, -23), Vector2.new(40, 58), Color3.fromRGB(235, 214, 156), "CAFETERIA", Enum.Material.CeramicTiles)
	buildZone(folder, "PrincipalsOffice", Vector3.new(-204, 0, 35), Vector2.new(40, 58), Color3.fromRGB(214, 226, 235), "PRINCIPAL'S OFFICE\n(THE STORE)", Enum.Material.Marble)
	-- and cut the same shaft out of the office floor the zone just laid down
	for _, existing in folder:GetChildren() do
		if existing.Name == "PrincipalsOfficeFloor" then
			existing:Destroy()
		end
	end
	floorWithHole(folder, "PrincipalsOfficeFloor", Vector3.new(-204, -0.5, 35), Vector2.new(40, 58), nil, "TexFloorTile")
	local trophyFloor = buildZone(folder, "TrophyHall", Vector3.new(204, 0, -23), Vector2.new(40, 58), Color3.fromRGB(228, 228, 228), "TROPHY HALL", Enum.Material.Marble)
	buildZone(folder, "Detention", Vector3.new(204, 0, 35), Vector2.new(40, 58), Color3.fromRGB(126, 126, 132), "DETENTION", Enum.Material.Concrete)
	tag(buildZone(folder, "Classroom101", Vector3.new(-74, 0, -94), Vector2.new(28, 60), Color3.fromRGB(148, 118, 96), "ROOM 101\nMATHEMATICS", Enum.Material.Carpet), "TexCarpet")
	buildZone(folder, "MusicRoom", Vector3.new(74, 0, -94), Vector2.new(28, 60), Color3.fromRGB(196, 168, 210), "MUSIC ROOM", Enum.Material.Carpet)
	-- the two science annexes, dropped into the courtyards
	buildPavilion(
		folder,
		"Greenhouse",
		Vector3.new(-116, 0, -28),
		Vector2.new(36, 34),
		"THE GREENHOUSE\nBIOLOGY",
		Color3.fromRGB(150, 220, 130),
		Color3.fromRGB(206, 238, 210)
	)
	buildPavilion(
		folder,
		"EastLab",
		Vector3.new(116, 0, -28),
		Vector2.new(36, 34),
		"EAST LAB\nCHEMISTRY",
		Color3.fromRGB(150, 240, 190),
		Color3.fromRGB(202, 232, 240)
	)
	-- The gymnasium moved out to its own building at (425, 405). This hall
	-- stays -- it is a hundred by eighty-two studs of sprung floor and every
	-- school has one -- but it is the Academy's ASSEMBLY HALL now, not a second
	-- gym. Leaving it labelled "GYM" would have given the campus two.
	buildZone(folder, "AssemblyHall", Vector3.new(0, 0, -105), Vector2.new(100, 82), Color3.fromRGB(210, 160, 110), "ASSEMBLY HALL", Enum.Material.WoodPlanks)
	buildCheckerFloor(folder, Vector3.new(0, 0, 0), Vector2.new(120, 128)) -- atrium
	-- courtyards: open-air grass
	for _, cx in { -116, 116 } do
		local lawn = part({
			Name = "CourtyardLawn",
			Size = Vector3.new(112, 1, 104),
			CFrame = CFrame.new(cx, -0.45, 0),
			Color = Color3.fromRGB(112, 168, 82),
			Material = Enum.Material.Grass,
			Parent = folder,
		})
		tag(lawn, "TexGround")
	end

	-- ---------------- walls: exterior (two-story look) ----------------
	local T = true
	-- south face: wings + lobby with grand doors
	buildFacadeWall(folder, Vector3.new(-224, 0, 124), Vector3.new(-60, 0, 124), {})
	buildFacadeWall(folder, Vector3.new(60, 0, 124), Vector3.new(224, 0, 124), {})
	buildFacadeWall(folder, Vector3.new(-60, 0, 124), Vector3.new(60, 0, 124), { { at = 60, width = 26 } })
	-- north face (interrupted by the gym block)
	buildFacadeWall(folder, Vector3.new(-224, 0, -124), Vector3.new(-60, 0, -124), {})
	buildFacadeWall(folder, Vector3.new(60, 0, -124), Vector3.new(224, 0, -124), {})
	buildFacadeWall(folder, Vector3.new(-60, 0, -124), Vector3.new(-50, 0, -124), {})
	buildFacadeWall(folder, Vector3.new(50, 0, -124), Vector3.new(60, 0, -124), {})
	-- gym protrusion
	buildFacadeWall(folder, Vector3.new(-50, 0, -124), Vector3.new(-50, 0, -146), {})
	buildFacadeWall(folder, Vector3.new(50, 0, -146), Vector3.new(50, 0, -124), {})
	buildFacadeWall(folder, Vector3.new(-50, 0, -146), Vector3.new(50, 0, -146), {})
	-- east/west faces
	buildFacadeWall(folder, Vector3.new(-224, 0, -124), Vector3.new(-224, 0, 124), {})
	buildFacadeWall(folder, Vector3.new(224, 0, 124), Vector3.new(224, 0, -124), {})

	-- ---------------- walls: interior ----------------
	local function mirrorX(v: Vector3): Vector3
		return Vector3.new(-v.X, v.Y, v.Z)
	end
	local function wingWalls(sgn: number)
		local function W(a: Vector3, b: Vector3, gaps)
			if sgn < 0 then
				buildInteriorWall(folder, a, b, gaps or {})
			else
				buildInteriorWall(folder, mirrorX(a), mirrorX(b), gaps or {})
			end
		end
		-- z=76: plot bays OPEN onto the corridor (their laser gates are the
		-- front wall); only stubs at bay edges + the janitor room front
		W(Vector3.new(-224, 0, 81), Vector3.new(-218, 0, 81), {})
		W(Vector3.new(-162, 0, 81), Vector3.new(-150, 0, 81), {})
		W(Vector3.new(-94, 0, 81), Vector3.new(-88, 0, 81), {})
		W(Vector3.new(-88, 0, 81), Vector3.new(-60, 0, 81), { { at = 14, width = 8 } })
		-- z=49: courtyard south colonnade. It used to stand at z=59, which left
		-- the main hallway 22 studs across -- narrow enough that two students
		-- and a professor filled it. Ten studs off the courtyard's south end
		-- buys a hall you can actually move through.
		W(Vector3.new(-172, 0, 49), Vector3.new(-60, 0, 49), { { at = 32, width = 18 }, { at = 80, width = 18 } })
		-- z=-52: cafeteria front (door) + courtyard north wall (arch)
		W(Vector3.new(-224, 0, -52), Vector3.new(-184, 0, -52), { { at = 20, width = 12 } })
		W(Vector3.new(-172, 0, -52), Vector3.new(-60, 0, -52), { { at = 56, width = 16 } })
		-- z=-64: north plot bays OPEN onto the full-width wing corridor;
		-- stubs at bay edges + the classroom front with its door
		W(Vector3.new(-224, 0, -64), Vector3.new(-218, 0, -64), {})
		W(Vector3.new(-162, 0, -64), Vector3.new(-150, 0, -64), {})
		W(Vector3.new(-94, 0, -64), Vector3.new(-88, 0, -64), {})
		W(Vector3.new(-88, 0, -64), Vector3.new(-60, 0, -64), { { at = 14, width = 10 } })
		-- x=-184: outer column onto inner corridor (cafeteria + principal doors)
		W(Vector3.new(-184, 0, -52), Vector3.new(-184, 0, 49), { { at = 29, width = 12 }, { at = 87, width = 12 } })
		-- x=-172: inner corridor onto courtyard (two arches)
		W(Vector3.new(-172, 0, -52), Vector3.new(-172, 0, 49), { { at = 28, width = 14 }, { at = 76, width = 14 } })
		-- room separators, south row then north row
		W(Vector3.new(-156, 0, 81), Vector3.new(-156, 0, 124), {})
		W(Vector3.new(-88, 0, 81), Vector3.new(-88, 0, 124), {})
		W(Vector3.new(-156, 0, -124), Vector3.new(-156, 0, -64), {})
		W(Vector3.new(-88, 0, -124), Vector3.new(-88, 0, -64), {})
		-- cafeteria/principal divider (outer column now starts at z=-52)
		W(Vector3.new(-224, 0, 6), Vector3.new(-184, 0, 6), {})
	end
	wingWalls(-1)
	wingWalls(1)

	-- spine walls
	buildInteriorWall(folder, Vector3.new(-60, 0, 81), Vector3.new(-60, 0, 124), {})
	buildInteriorWall(folder, Vector3.new(-26, 0, 81), Vector3.new(26, 0, 81), { { at = 26, width = 22 } }) -- lobby west
	buildInteriorWall(folder, Vector3.new(60, 0, 81), Vector3.new(60, 0, 124), {}) -- lobby east
	buildInteriorWall(folder, Vector3.new(-60, 0, -64), Vector3.new(-60, 0, 64), { { at = 70, width = 12 } }) -- atrium west (arch to courtyard)
	buildInteriorWall(folder, Vector3.new(60, 0, -64), Vector3.new(60, 0, 64), { { at = 70, width = 12 } }) -- atrium east
	buildInteriorWall(folder, Vector3.new(-50, 0, -64), Vector3.new(50, 0, -64), { { at = 50, width = 20 } }) -- gym south (grand doors)
	buildInteriorWall(folder, Vector3.new(-60, 0, -64), Vector3.new(-60, 0, -124), {}) -- west flank outer
	buildInteriorWall(folder, Vector3.new(60, 0, -124), Vector3.new(60, 0, -64), {}) -- east flank outer
	buildInteriorWall(folder, Vector3.new(-50, 0, -64), Vector3.new(-50, 0, -124), {}) -- gym west (flank divider)
	buildInteriorWall(folder, Vector3.new(50, 0, -124), Vector3.new(50, 0, -64), {}) -- gym east

	-- open doors on the main rooms
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(-204, 0, 64), Vector3.new(-204, 0, 60)), 12, true)
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(204, 0, 64), Vector3.new(204, 0, 60)), 12, true)
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(-204, 0, -52), Vector3.new(-204, 0, -48)), 12, true)
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(204, 0, -52), Vector3.new(204, 0, -48)), 12, true)
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(0, 0, -64), Vector3.new(0, 0, -68)), 18, true)

	-- ---------------- lockers on real wall sections ----------------
	for _, spec in {
		{ cf = CFrame.new(-58.6, 4.2, 20), rot = 90 }, -- atrium west wall
		{ cf = CFrame.new(58.6, 4.2, 20), rot = 90 }, -- atrium east wall
		{ cf = CFrame.new(-58.6, 4.2, -30), rot = 90 },
		{ cf = CFrame.new(58.6, 4.2, -30), rot = 90 },
	} do
		-- These were four 24 x 8.4 x 1.6 boards painted locker blue and stuck
		-- flat to the atrium walls. A bank of lockers has doors, handles,
		-- vents and a capping, and the corridor's own run has had all of
		-- those since it was built -- it was just written inline there and
		-- nothing else could reach it.
		lockerRun(folder, spec.cf * CFrame.Angles(0, math.rad(spec.rot), 0) * CFrame.new(0, -4.2, 0), 12, 0.8, 8.4, false)
	end
	-- columns along the open corridor edges (colonnade + lobby + atrium)
	-- On the corridor's south EDGE at z = 52, not four studs into it at 59.
	-- The hall is thirty-two studs across and a colonnade standing a third of
	-- the way into it narrows the walking lane to the point where the columns
	-- are the thing you are dodging rather than the thing holding the roof up.
	for _, colSpec in {
		{ z = 52, xs = { -160, -132, -104, -76 } },
		{ z = 52, xs = { 76, 104, 132, 160 } },
		-- no column at x = 0: that is the middle of the lobby opening
		{ z = 81, xs = { -40, 40 } },
	} do
		for _, cx in colSpec.xs do
			part({
				Name = "CorridorColumn",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(15.4, 1.5, 1.5),
				CFrame = CFrame.new(cx, 7.7, colSpec.z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(238, 234, 224),
				Material = Enum.Material.SmoothPlastic,
				Parent = folder,
			})
		end
	end
	for _, xEnd in { -218, 218 } do
		local sign = part({
			Name = "HallwaySign",
			Size = Vector3.new(2, 5, 10),
			CFrame = CFrame.new(xEnd, 7, 70),
			Color = Palette.Blackboard,
			Parent = folder,
		})
		signText(sign, "MAIN HALLWAY", Palette.BusYellow, Enum.NormalId.Left)
		signText(sign, "MAIN HALLWAY", Palette.BusYellow, Enum.NormalId.Right)
	end
	-- corridor ceiling lights
	for i = 0, 26 do
		part({ Name = "CeilingDot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.2, 2.2), CFrame = CFrame.new(-208 + i * 16, 14.4, 70) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 248, 230), Material = Enum.Material.Neon, Parent = folder })
	end

	-- ---------------- roofs (flat slabs; courtyards stay open) ----------------
	-- These used to sit at y = 16.2. The upper floor's deck is at 16, so the
	-- roof was resting flush on the first floor's carpet: you climbed the
	-- stairs and arrived in a two-tenths-of-a-stud gap between deck and slab,
	-- which is what "can't go upstairs, it's glitching" was. The roof is above
	-- the upper storey now, at the height the upper walls actually reach.
	local ROOF_Y = 32.6
	-- The slab is the CEILING of the room under it, so it keeps its pale
	-- plaster. But seen from anywhere above -- the tower, the upper windows, an
	-- overview -- these read as a white plaza laid across the middle of a slate
	-- roof, which is the single ugliest thing on the building.
	--
	-- A real school of this kind has lead flats between its pitches, edged with
	-- a parapet. So each slab gets a lead covering laid over it and a low kerb
	-- round the edge: the ceiling stays a ceiling, and the roof becomes a roof.
	local function roofSlab(cx: number, cz: number, sx: number, sz: number, y: number?)
		local at = y or ROOF_Y
		tag(part({
			Name = "RoofSlab",
			Size = Vector3.new(sx, 1.2, sz),
			CFrame = CFrame.new(cx, at, cz),
			Color = Color3.fromRGB(228, 226, 220),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		}), "TexCeiling")
		local lead = part({
			Name = "RoofLead",
			Size = Vector3.new(sx, 0.5, sz),
			-- 0.7, not 0.85: at 0.85 the lead's underside landed EXACTLY on the
			-- slab's top face and 10,400 square studs of roof z-fought. It
			-- overlaps into the slab now, so no two faces share a plane.
			CFrame = CFrame.new(cx, at + 0.7, cz),
			Color = Color3.fromRGB(96, 104, 116),
			Material = Enum.Material.Slate,
			Parent = folder,
		})
		lead.CanCollide = false
		tag(lead, "TexSlateRoof")
		-- a parapet kerb on the two long edges, so the flat has an edge to it
		for _, side in { -1, 1 } do
			if sx >= sz then
				tag(part({ Name = "RoofKerb", Size = Vector3.new(sx + 1.0, 2.2, 1.4), CFrame = CFrame.new(cx, at + 1.6, cz + side * (sz / 2 - 0.3)), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = folder }), "TexAshlar").CanCollide = false
			else
				tag(part({ Name = "RoofKerb", Size = Vector3.new(1.4, 2.2, sz + 1.0), CFrame = CFrame.new(cx + side * (sx / 2 - 0.3), at + 1.6, cz), Color = Color3.fromRGB(201, 191, 169), Material = Enum.Material.Concrete, Parent = folder }), "TexAshlar").CanCollide = false
			end
		end
	end
	-- 116 wide, not 448: the wing slabs below already cover x +-58..226, so
	-- this was laying a second ceiling over both of them.
	roofSlab(0, 102, 116, 44) -- the centre bay only; wings are covered below
	roofSlab(0, 71.5, 448, 15) -- corridor, between the colonnades and the front range
	roofSlab(-116, 58, 112, 12) -- west colonnade
	roofSlab(116, 58, 112, 12) -- east colonnade
	roofSlab(-116, -57.5, 112, 11) -- west north leg
	roofSlab(116, -57.5, 112, 11) -- east north leg
	roofSlab(0, 0, 120, 128) -- atrium (with skylight ring)
	roofSlab(-142, 102, 168, 46) -- west south rooms
	roofSlab(142, 102, 168, 46) -- east south rooms
	roofSlab(-142, -94, 168, 62) -- west north rooms
	roofSlab(142, -94, 168, 62) -- east north rooms
	-- x -226..-172, z -63..64: butted against the north range at -63, the
	-- colonnade at -172 and the corridor at 64, rather than lapping two
	-- studs over each of them
	roofSlab(-199, 0.5, 54, 127) -- west outer column
	roofSlab(199, 0.5, 54, 127) -- east outer column
	-- 38.9, not 40: the gym's brick tops out at 38 and its cornice at 38.3, so
	-- a roof whose underside sat at 39.4 left a stud of daylight running right
	-- round the building between the wall and the lid.
	roofSlab(0, -105, 106, 88, 38.9) -- gym: open to its full height
	roofSlab(-54, -94, 8, 60) -- west flank, butted to the north range at -58
	roofSlab(54, -94, 8, 60) -- east flank
	-- atrium skylight
	part({
		Name = "Skylight",
		Size = Vector3.new(44, 0.6, 44),
		CFrame = CFrame.new(0, 32.8, 6),
		Color = Color3.fromRGB(170, 215, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		Parent = folder,
	})

	-- ---------------- signature interiors ----------------
	buildFountain(folder, Vector3.new(0, 0, 6)) -- atrium centerpiece
	buildGymMarkings(folder, Vector3.new(0, 0, -105))
	buildHoops(folder, Vector3.new(0, 0, -105))
	-- gym stage at the north end
	part({ Name = "GymStage", Size = Vector3.new(60, 3, 16), CFrame = CFrame.new(0, 1.5, -136), Color = Color3.fromRGB(120, 70, 50), Material = Enum.Material.WoodPlanks, Parent = folder })
	-- Classroom 101 is the box x -88..-60, z -124..-64. The grid has been wrong
	-- twice: it ran to z = -86 (through the partition at z = -94) and then to
	-- x = -96 (through the west wall at x = -88, into the homeroom next door).
	-- Two columns of three, facing the professor, wholly inside the room.
	for row = 0, 2 do
		for col = 0, 1 do
			local dx, dz = -80 + col * 12, -100 + row * 10
			-- a top on legs with a chair behind it, rather than a solid block:
			-- furniture you can see under is most of what makes a room read
			local unit = Instance.new("Folder")
			unit.Name = "ClassDeskUnit"
			unit.Parent = folder
			part({ Name = "ClassDeskTop", Size = Vector3.new(6, 0.4, 3), CFrame = CFrame.new(dx, 2.6, dz), Color = Color3.fromRGB(196, 158, 118), Material = Enum.Material.WoodPlanks, Parent = unit })
			for _, lx in { -2.5, 2.5 } do
				for _, lz in { -1.2, 1.2 } do
					part({ Name = "ClassDeskLeg", Size = Vector3.new(0.35, 2.4, 0.35), CFrame = CFrame.new(dx + lx, 1.2, dz + lz), Color = Color3.fromRGB(104, 108, 116), Material = Enum.Material.Metal, Parent = unit })
				end
			end
			local seat = Instance.new("Folder")
			seat.Name = "ClassChairUnit"
			seat.Parent = folder
			part({ Name = "ClassChairSeat", Size = Vector3.new(2.6, 0.35, 2.4), CFrame = CFrame.new(dx, 1.7, dz + 3.4), Color = Color3.fromRGB(86, 116, 158), Material = Enum.Material.SmoothPlastic, Parent = seat })
			part({ Name = "ClassChairBack", Size = Vector3.new(2.6, 2.2, 0.35), CFrame = CFrame.new(dx, 2.8, dz + 4.4), Color = Color3.fromRGB(86, 116, 158), Material = Enum.Material.SmoothPlastic, Parent = seat })
			for _, lx in { -1, 1 } do
				part({ Name = "ClassChairLeg", Size = Vector3.new(0.3, 1.5, 0.3), CFrame = CFrame.new(dx + lx, 0.75, dz + 3.4), Color = Color3.fromRGB(104, 108, 116), Material = Enum.Material.Metal, Parent = seat })
			end
			-- the board is to the north, so both face -Z
			prop("SchoolDesk", CFrame.new(dx, 0, dz) * CFrame.Angles(0, math.pi, 0), { fallback = unit :: Instance })
			prop("SchoolChair", CFrame.new(dx, 0, dz + 3.6) * CFrame.Angles(0, math.pi, 0), { fallback = seat :: Instance })
		end
	end
	-- against the far wall, facing the desks. It used to sit at z = -67, which
	-- is the doorway, so the room could not be walked into.
	local classBoard = part({ Name = "ClassBoard", Size = Vector3.new(18, 8, 0.6), CFrame = CFrame.new(-74, 6, -121), Color = Palette.Blackboard, Parent = folder })
	classBoard.CanCollide = false
	signText(classBoard, "CLASSROOM 101", Palette.White, Enum.NormalId.Front)

	-- trophy hall boards
	local trophyCashBoard = part({
		Name = "TrophyCashBoard",
		Size = Vector3.new(1, 12, 22),
		CFrame = CFrame.new(221.5, 7, -42),
		Color = Palette.Blackboard,
		Parent = folder,
	})
	local trophyAuraBoard = part({
		Name = "TrophyAuraBoard",
		Size = Vector3.new(1, 12, 22),
		CFrame = CFrame.new(221.5, 7, -14),
		Color = Palette.Blackboard,
		Parent = folder,
	})

	-- clique boards along the west courtyard's north wall
	local Cliques = __Cliques
	local cliqueBoards: { [string]: BasePart } = {}
	for i, clique in Cliques.List do
		local board = part({
			Name = "CliqueBoard_" .. clique.id,
			Size = Vector3.new(13, 8, 1),
			CFrame = CFrame.new(-166 + (i - 1) * 30, 4.5, -47),
			Color = clique.color,
			Parent = folder,
		})
		signText(board, clique.name:upper() .. "\n" .. clique.motto, Palette.White, Enum.NormalId.Front)
		signText(board, clique.name:upper(), Palette.White, Enum.NormalId.Back)
		cliqueBoards[clique.id] = board
	end

	-- west courtyard dressing: flowerbeds + trees; east courtyard: courts
	buildFlowerbed(folder, Vector3.new(-150, 0, 20))
	buildFlowerbed(folder, Vector3.new(-86, 0, 20))
	meshTree(folder, Vector3.new(-146, 0, -16), 1.1)
	meshTree(folder, Vector3.new(-90, 0, 24), 0.95)
	-- Laid ON the quad lawn (top 0.40), not inside it. At 0.01 .. 0.21 the
	-- court was buried in the grass slab with its underside 0.01 from the
	-- lawn's -- the whole court flickered and none of it was visible.
	-- 0.30 .. 0.60, so the slab straddles the lawn's top face (0.40) instead of
	-- sharing a plane with it, and the key straddles the court's top (0.60).
	local courtBase = part({ Name = "BasketballCourt", Size = Vector3.new(34, 0.3, 22), CFrame = CFrame.new(96, 0.57, -14), Color = Color3.fromRGB(52, 118, 190), Material = Enum.Material.SmoothPlastic, Parent = folder })
	local _cb = courtBase
	part({ Name = "CourtKey", Size = Vector3.new(10, 0.22, 22), CFrame = CFrame.new(96, 0.83, -14), Color = Color3.fromRGB(226, 130, 62), Material = Enum.Material.SmoothPlastic, Parent = folder }).CanCollide = false
	-- Hoops, not posts. These were two bare uprights at each end of a painted
	-- court: no backboard, no rim, nothing to aim at.
	for _, hoop in { { x = 80, dir = 1 }, { x = 112, dir = -1 } } do
		local hx, dir = hoop.x, hoop.dir
		part({ Name = "HoopFoot", Size = Vector3.new(3.4, 0.7, 3.4), CFrame = CFrame.new(hx, 0.95, -14), Color = Color3.fromRGB(72, 76, 82), Material = Enum.Material.Metal, Parent = folder })
		part({ Name = "HoopPost", Size = Vector3.new(1.0, 12, 1.0), CFrame = CFrame.new(hx, 6.6, -14), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = folder })
		part({ Name = "HoopArm", Size = Vector3.new(3.2, 0.6, 0.6), CFrame = CFrame.new(hx + dir * 1.6, 12.0, -14), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
		local board = part({ Name = "HoopBoard", Size = Vector3.new(0.4, 4.0, 6.6), CFrame = CFrame.new(hx + dir * 3.4, 11.4, -14), Color = Color3.fromRGB(246, 248, 250), Material = Enum.Material.SmoothPlastic, Parent = folder })
		board.CanCollide = false
		part({ Name = "HoopBoardBox", Size = Vector3.new(0.2, 2.0, 3.0), CFrame = CFrame.new(hx + dir * 3.65, 10.9, -14), Color = Color3.fromRGB(226, 84, 52), Material = Enum.Material.SmoothPlastic, Parent = folder }).CanCollide = false
		local rim = part({ Name = "HoopRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 3.0, 3.0), CFrame = CFrame.new(hx + dir * 5.2, 10.0, -14) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(238, 108, 46), Material = Enum.Material.Metal, Parent = folder })
		rim.CanCollide = false
		local net = part({ Name = "HoopNet", Size = Vector3.new(2.6, 2.4, 2.6), CFrame = CFrame.new(hx + dir * 5.2, 8.8, -14), Color = Color3.fromRGB(240, 242, 246), Material = Enum.Material.Fabric, Transparency = 0.45, Parent = folder })
		net.CanCollide = false
	end
	local volleyBase = part({ Name = "VolleyballCourt", Size = Vector3.new(30, 0.3, 18), CFrame = CFrame.new(136, 0.57, 24), Color = Color3.fromRGB(226, 148, 168), Material = Enum.Material.SmoothPlastic, Parent = folder })
	local _vb = volleyBase
	part({ Name = "VolleyNet", Size = Vector3.new(0.2, 2.4, 17), CFrame = CFrame.new(136, 6.4, 24), Color = Color3.fromRGB(235, 235, 235), Material = Enum.Material.Fabric, Transparency = 0.35, Parent = folder })

	-- ---- lobby dressing ----
	-- It was a grey box with a doorway in it, and it is the second thing
	-- anyone sees. A school entrance hall is a reception desk, a trophy run,
	-- somewhere to sit and something to read.
	part({ Name = "LobbyDesk", Size = Vector3.new(18, 3.4, 4), CFrame = CFrame.new(-30, 1.7, 92), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = folder })
	part({ Name = "LobbyDeskTop", Size = Vector3.new(19.4, 0.4, 5), CFrame = CFrame.new(-30, 3.6, 92), Color = Color3.fromRGB(196, 158, 118), Material = Enum.Material.WoodPlanks, Parent = folder })
	part({ Name = "LobbyDeskBack", Size = Vector3.new(18, 8, 0.8), CFrame = CFrame.new(-30, 4, 96), Color = Color3.fromRGB(150, 112, 82), Material = Enum.Material.WoodPlanks, Parent = folder })

	-- Trophy cases down the east wall.
	--
	-- The trophies used to stand at x = 45.6, which is the middle of the east
	-- lobby staircase: buried inside the treads, and in the way of the climb.
	-- The case is built as a case now -- back panel, two uprights, a shelf and
	-- glass in front -- so there is somewhere for them to actually be.
	for i = 0, 2 do
		local cz = 86 + i * 13
		part({ Name = "LobbyCaseFrame", Size = Vector3.new(0.8, 11, 11), CFrame = CFrame.new(59.0, 5.5, cz), Color = Color3.fromRGB(96, 68, 48), Material = Enum.Material.WoodPlanks, Parent = folder })
		for _, side in { -1, 1 } do
			part({ Name = "LobbyCasePost", Size = Vector3.new(2.2, 11, 0.8), CFrame = CFrame.new(57.9, 5.5, cz + side * 5.1), Color = Color3.fromRGB(96, 68, 48), Material = Enum.Material.WoodPlanks, Parent = folder })
		end
		part({ Name = "LobbyCaseShelf", Size = Vector3.new(2.2, 0.4, 10.2), CFrame = CFrame.new(57.9, 5.4, cz), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = folder })
		part({ Name = "LobbyCaseGlass", Size = Vector3.new(0.4, 9, 9.4), CFrame = CFrame.new(57.0, 5.6, cz), Color = Color3.fromRGB(186, 214, 226), Material = Enum.Material.Glass, Transparency = 0.55, Parent = folder })
		for j = 0, 1 do
			part({
				Name = "LobbyTrophy",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2.4, 1.5, 1.5),
				-- inside the case: behind the glass at x = 57.2, in front of
				-- the back panel at x = 58.6, one trophy per shelf
				CFrame = CFrame.new(57.9, 3 + j * 4.4, cz - 2.6 + j * 5) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(226, 186, 92),
				Material = Enum.Material.Metal,
				Parent = folder,
			})
		end
	end

	-- benches facing the desk, with a runner between them
	for _, bz in { 88, 102 } do
		part({ Name = "LobbyBenchSeat", Size = Vector3.new(3.4, 0.5, 16), CFrame = CFrame.new(18, 2.4, bz), Color = Color3.fromRGB(158, 116, 82), Material = Enum.Material.WoodPlanks, Parent = folder })
		for _, lz in { -6.5, 6.5 } do
			part({ Name = "LobbyBenchLeg", Size = Vector3.new(2.8, 2.2, 0.6), CFrame = CFrame.new(18, 1.2, bz + lz), Color = Color3.fromRGB(104, 108, 116), Material = Enum.Material.Metal, Parent = folder })
		end
	end
	tag(part({ Name = "LobbyRunner", Size = Vector3.new(20, 0.16, 40), CFrame = CFrame.new(0, 0.2, 100), Color = Color3.fromRGB(132, 68, 60), Material = Enum.Material.Fabric, Parent = folder }), "TexCarpet")

	-- notice board by the doors, and planters flanking the way in
	-- Hung ON the wall. InnerWallUpper here is rotated a quarter turn -- it runs
	-- north to south at x = -60 with its east face at x = -59.3 -- so the board
	-- is thin in X and long in Z, sitting a quarter stud proud of that face and
	-- reading east into the hall. It used to hang at x = -56.6, two and a half
	-- studs off the wall with nothing behind it.
	local notice = part({ Name = "LobbyNotice", Size = Vector3.new(0.5, 9, 16), CFrame = CFrame.new(-59.05, 7, 104), Color = Palette.Blackboard, Parent = folder })
	signText(notice, "NOTICES\nBELL 8:40\nDETENTION 4PM", Palette.Chalk, Enum.NormalId.Right)
	-- NOT a tree: these are indoors, under thirty studs of roof, in the
	-- entrance hall. A planted bay in a glazed tub is the thing a school lobby
	-- actually has either side of its doors -- with a base, a moulding and a
	-- rim on the tub, rather than a box with a green box on it.
	for _, side in { -1, 1 } do
		local px = side * 30
		part({ Name = "LobbyPlanterBase", Size = Vector3.new(7.0, 0.6, 7.0), CFrame = CFrame.new(px, 0.5, 116), Color = Color3.fromRGB(132, 104, 84), Material = Enum.Material.Concrete, Parent = folder })
		part({ Name = "LobbyPlanter", Size = Vector3.new(6, 3.2, 6), CFrame = CFrame.new(px, 2.4, 116), Color = Color3.fromRGB(150, 118, 96), Material = Enum.Material.Concrete, Parent = folder })
		part({ Name = "LobbyPlanterBand", Size = Vector3.new(6.4, 0.5, 6.4), CFrame = CFrame.new(px, 3.1, 116), Color = Color3.fromRGB(178, 142, 116), Material = Enum.Material.Concrete, Parent = folder }).CanCollide = false
		part({ Name = "LobbyPlanterRim", Size = Vector3.new(6.8, 0.7, 6.8), CFrame = CFrame.new(px, 4.35, 116), Color = Color3.fromRGB(186, 150, 122), Material = Enum.Material.Concrete, Parent = folder }).CanCollide = false
		part({ Name = "LobbyPlanterSoil", Size = Vector3.new(5.4, 0.5, 5.4), CFrame = CFrame.new(px, 4.05, 116), Color = Color3.fromRGB(78, 62, 48), Material = Enum.Material.Ground, Parent = folder }).CanCollide = false
		part({ Name = "LobbyBayStem", Size = Vector3.new(0.9, 3.0, 0.9), CFrame = CFrame.new(px, 5.8, 116), Color = Color3.fromRGB(112, 84, 58), Material = Enum.Material.Wood, Parent = folder }).CanCollide = false
		for i = 0, 2 do
			local w = 6.6 - i * 1.6
			part({ Name = "LobbyBayFoliage", Size = Vector3.new(w, 2.2, w), CFrame = CFrame.new(px, 8.0 + i * 2.0, 116) * CFrame.Angles(0, math.rad(24 * i), 0), Color = Color3.fromRGB(96 - i * 8, 148 - i * 10, 84 - i * 6), Material = Enum.Material.Grass, Parent = folder }).CanCollide = false
		end
	end
	-- On the wall beside the corridor opening, not across it. This was a 16
	-- stud board hung in the middle of a 23 stud doorway, so walking in from
	-- the lobby meant walking into a blackboard.
	local crest = part({ Name = "LobbyCrest", Size = Vector3.new(13, 7, 0.5), CFrame = CFrame.new(-18.5, 9, 80.1), Color = Palette.Blackboard, Parent = folder })
	crest.CanCollide = false
	signText(crest, "CRUMBWORTH HIGH\nEST. 1954", Palette.BusYellow, Enum.NormalId.Front)

	buildGrandFacade(folder)
	buildFrontGrounds(folder)
	buildGreatCourt(folder)
	buildBikeTrack(folder)
	buildDormCourt(folder)
	detailCorridor(folder)

	-- ---------------- outside: entrance, dorms, grounds ----------------
	-- The road runs behind the court, not through it. The bus stands at the
	-- kerb by the shelter, on the court's west flank walk where the walk meets
	-- the road -- it used to be parked at (-96, 190), which is now the middle
	-- of the north-west parterre.
	buildBus(folder, CFrame.new(-96, 0, ROAD_Z) * CFrame.Angles(0, math.rad(-2), 0))
	part({ Name = "FrontRoad", Size = Vector3.new(520, 0.4, 22), CFrame = CFrame.new(0, 0.05, ROAD_Z), Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Asphalt, Parent = folder })
	for _, dash in { -220, -180, -140, 140, 180, 220 } do
		part({ Name = "RoadMarking", Size = Vector3.new(18, 0.15, 0.9), CFrame = CFrame.new(dash, 0.3, ROAD_Z), Color = Color3.fromRGB(226, 222, 206), Material = Enum.Material.SmoothPlastic, Parent = folder }).CanCollide = false
	end
	-- the drive off the road onto the court's axis, and the link from the
	-- bus stop down onto the west flank walk
	buildPath(folder, Vector3.new(0, 0, ROAD_Z - 10), Vector3.new(0, 0, 285), 26)
	buildPath(folder, Vector3.new(-96, 0, ROAD_Z - 10), Vector3.new(-96, 0, 285), 14)

	-- ---------------- the main gate ----------------
	-- CampusPlan has drawn it at (-30, 540) to (30, 560) since the drawing was
	-- made and nothing has ever stood there: the ceremonial approach ran 250
	-- studs past the road to an empty field. It is the first thing anybody
	-- arriving sees and it closes the vista from the school's front doors.
	do
		local gateCtx = { parent = folder, part = part :: any, tag = tag :: any }
		local gate = CampusPlan.site("Main Gate")
		local gz = (gate.rect[2] + gate.rect[4]) / 2
		local half = (gate.rect[3] - gate.rect[1]) / 2
		-- the drive up to it, and the sweep inside the piers
		-- up to the gate, and no further: the North Reserve starts at z = 560
		-- and the drawing keeps it clear of anything built
		buildPath(folder, Vector3.new(0, 0, ROAD_Z + 10), Vector3.new(0, 0, gz + 4), 26)
		tag(part({
			Name = "GateApron",
			-- half * 4 + 4, not + 24: at 144 wide it ran to x +-72 and the
			-- estate fence's terminal piers stand at +-64. 124 covers the
			-- four gate piers (outer edge +-59.5) and stops short of them.
			Size = Vector3.new(half * 4 + 4, 0.4, 26),
			CFrame = CFrame.new(0, 0.2, gz - 4),
			Color = Color3.fromRGB(120, 120, 128),
			Material = Enum.Material.Slate,
			Parent = folder,
		}), "TexCourtPaving").CanCollide = false

		-- the two great piers, and a lesser pier each side of them
		Grounds.gatePier(gateCtx, -half, gz, 20.0)
		Grounds.gatePier(gateCtx, half, gz, 20.0)
		Grounds.gatePier(gateCtx, -half - 26, gz, 13.0)
		Grounds.gatePier(gateCtx, half + 26, gz, 13.0)
		-- a lantern on each of the great piers
		-- A LANTERN: a plinth on the pier, a moulded base, four glazing bars
		-- with the glass between them, a crowned cap and a finial. What stood
		-- here was a glowing box with a lid on it.
		local IRONWORK = Color3.fromRGB(28, 28, 32)
		for _, px in { -half, half } do
			part({ Name = "GateLanternPlinth", Size = Vector3.new(3.0, 1.0, 3.0), CFrame = CFrame.new(px, 25.0, gz), Color = IRONWORK, Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			part({ Name = "GateLanternBase", Size = Vector3.new(2.6, 0.7, 2.6), CFrame = CFrame.new(px, 25.9, gz), Color = IRONWORK, Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
				part({
					Name = "GateLanternBar",
					Size = Vector3.new(0.3, 3.4, 0.3),
					CFrame = CFrame.new(px + corner[1] * 1.1, 27.9, gz + corner[2] * 1.1),
					Color = IRONWORK,
					Material = Enum.Material.Metal,
					Parent = folder,
				}).CanCollide = false
			end
			local glass = part({
				Name = "GateLantern",
				Size = Vector3.new(2.0, 3.2, 2.0),
				CFrame = CFrame.new(px, 27.9, gz),
				Color = Color3.fromRGB(255, 220, 160),
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				Parent = folder,
			})
			glass.CanCollide = false
			part({ Name = "GateLanternCrown", Size = Vector3.new(2.8, 1.0, 2.8), CFrame = CFrame.new(px, 30.1, gz), Color = IRONWORK, Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			part({ Name = "GateLanternVane", Size = Vector3.new(1.6, 0.8, 1.6), CFrame = CFrame.new(px, 30.9, gz) * CFrame.Angles(0, math.rad(45), 0), Color = IRONWORK, Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			part({ Name = "GateLanternFinial", Size = Vector3.new(0.5, 2.0, 0.5), CFrame = CFrame.new(px, 32.0, gz), Color = IRONWORK, Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			local lamp = Instance.new("PointLight")
			lamp.Color = Color3.fromRGB(255, 220, 160)
			lamp.Brightness = 2.0
			lamp.Range = 46
			lamp.Shadows = false
			lamp.Parent = glass
		end

		-- the leaves, standing open against the piers, and the flanking screens
		for _, side in { -1, 1 } do
			local hingeX = side * half
			local leafW = half * 0.92
			local leafCx = hingeX + side * (leafW / 2 - 1.0)
			part({ Name = "MainGateStile", Size = Vector3.new(0.9, 15, 0.9), CFrame = CFrame.new(hingeX + side * 3.4, 8.0, gz + 5.6), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = folder })
			part({ Name = "MainGateRail", Size = Vector3.new(leafW, 0.7, 0.7), CFrame = CFrame.new(leafCx, 2.4, gz + 5.6), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			part({ Name = "MainGateRail", Size = Vector3.new(leafW, 0.7, 0.7), CFrame = CFrame.new(leafCx, 13.6, gz + 5.6), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			local bars = math.max(3, math.floor(leafW / 2.4))
			for i = 0, bars do
				local bx = leafCx - leafW / 2 + i * (leafW / bars)
				part({ Name = "MainGateBar", Size = Vector3.new(0.32, 12, 0.32), CFrame = CFrame.new(bx, 8.0, gz + 5.6), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
				part({ Name = "MainGateSpear", Size = Vector3.new(0.6, 1.1, 0.6), CFrame = CFrame.new(bx, 14.6, gz + 5.6) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			end
			-- the screen between the lesser pier and the great one
			Grounds.railing(gateCtx, side * (half + 3), gz, side * (half + 23), gz, 9.0)
			-- and the boundary railing running out from the lesser pier
			Grounds.railing(gateCtx, side * (half + 29), gz, side * 210, gz, 9.0)
			Grounds.gatePier(gateCtx, side * 210, gz, 13.0)
		end

		-- the school's name across the gate, hung between the great piers
		local arch = part({ Name = "GateArch", Size = Vector3.new(half * 2 - 4, 1.0, 1.0), CFrame = CFrame.new(0, 21.5, gz + 5.6), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = folder })
		arch.CanCollide = false
		-- ironwork under the arch: a run of scrolls with a finial over each
		-- pier. Without them the arch was a single bar in the air.
		for i = -3, 3 do
			local sx = i * ((half * 2 - 8) / 7)
			part({ Name = "GateArchScroll", Size = Vector3.new(0.4, 3.2, 0.4), CFrame = CFrame.new(sx, 19.8, gz + 5.6) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 22 else -22)), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			part({ Name = "GateArchBoss", Size = Vector3.new(1.0, 1.0, 0.6), CFrame = CFrame.new(sx, 18.2, gz + 5.6) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(217, 180, 92), Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
		end
		part({ Name = "GateArchRail", Size = Vector3.new(half * 2 - 4, 0.5, 0.5), CFrame = CFrame.new(0, 17.6, gz + 5.6), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
		local board = part({ Name = "GateNameBoard", Size = Vector3.new(30, 5.4, 0.6), CFrame = CFrame.new(0, 24.4, gz + 5.6), Color = Color3.fromRGB(22, 35, 63), Material = Enum.Material.SmoothPlastic, Parent = folder })
		board.CanCollide = false
		signText(board, "CRUMBWORTH HIGH", Color3.fromRGB(217, 180, 92), Enum.NormalId.Back)
		signText(board, "CRUMBWORTH HIGH", Color3.fromRGB(217, 180, 92), Enum.NormalId.Front)
		for _, hx in { -8, 8 } do
			part({ Name = "GateBoardHanger", Size = Vector3.new(0.4, 2.0, 0.4), CFrame = CFrame.new(hx, 22.5, gz + 5.6), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
		end
	end
	local dormBeds: { BasePart } = {}
	-- The walks to the boarding house. They used to run east and west at
	-- z = -196 to two blocks at (+-176, -232); the boarding house is one range
	-- on the axis at (0, -310) now, so the approach is the axis itself with a
	-- pair of walks off it onto the front of the range.
	-- north end at z = -132, eight studs off the Academy's back wall, so the
	-- walk starts at the building rather than in the middle of a field
	buildCampusPath(folder, Vector3.new(0, 0, -132), Vector3.new(0, 0, -246), 18)
	-- laid OVER the axis walk it crosses at the dorm front. It used to run at
	-- z = -246, which put seven of its fourteen studs inside the boarding
	-- house's front wall (z -254..-246); at -238 it stops one stud short of
	-- the stonework instead of running under it.
	buildCampusPath(folder, Vector3.new(-70, 0, -238), Vector3.new(70, 0, -238), 14, true)
	-- The two diagonal paths that used to cut from (+-60, 150) out to
	-- (+-130, 192) are gone: they crossed the court's parterres and its flank
	-- walks at an angle, which is what a formal court never does. The court's
	-- own walks do the work.
	-- ---- the buildings that come out of the DRAWING ----
	--
	-- These are the first two structures on the campus that MapService did not
	-- author. CampusPlan says where the Gymnasium and the Secret Rooftop block
	-- stand, what rooms they hold, where their corridors and doors are and how
	-- their stairs run; PlanBuilder turns that into floors, cut walls, windows,
	-- a roof, dormers, chimneys and a porch. Nothing here chooses a coordinate.
	--
	-- tools/build_check.py has been reporting both as "drawn and only 0 parts
	-- stand there" since the drawing was made.
	local planCtx = { parent = folder, part = part :: any, tag = tag :: any, prop = prop :: any }
	-- Keep the scatter off them too. NO_TREES stops the treeline and the rock
	-- ridge; ground cover is a separate pass, and a tuft of grass came up
	-- through the detention hall's south wall because nothing told it.
	for _, r in {
		{ 425, 405, 100, 70 },   -- gymnasium
		{ 210, 400, 60, 60 },    -- secret rooftop block
		{ 320, -300, 106, 54 },  -- cafeteria
		{ -400, 20, 91, 66 },    -- detention hall
		{ -320, -300, 106, 54 }, -- library
	} do
		blockScatter(r[1], r[2], r[3], r[4])
	end
	PlanBuilder.build(planCtx, "Gymnasium")
	PlanBuilder.build(planCtx, "Secret Rooftop")
	PlanBuilder.build(planCtx, "Cafeteria")
	PlanBuilder.build(planCtx, "Detention Hall")
	-- THE BOARDING HOUSE, on its drawn ground.
	--
	-- There were two blocks at (+-176, -232), which is 26 studs outside the
	-- rectangle CampusPlan gives the Student Dorms and 78 studs off its centre
	-- line -- so the drawing had a boarding house with fourteen rooms in it
	-- and the campus had two sheds either side of the ground it was drawn on.
	-- PlanBuilder renders the shell from the drawing; furnishDorms puts the
	-- beds, the kitchen, the washroom and the study in the rooms it names.
	PlanBuilder.build(planCtx, "Student Dorms")
	furnishDorms(folder, dormBeds)
	buildHiddenAlley(folder)
	buildFlagpole(folder)
	buildCoreFence(folder)
	buildTreeline(folder, meshTree)
	buildRocks(folder)
	-- Feature trees flanking the facade and the wings. The pair at +-58 moved
	-- out to +-66: a mesh oak is eighteen studs across where the old box tree
	-- was ten, and at 58 it swallowed the whale statue standing beside it.
	for _, pos in {
		Vector3.new(-76, 0, 158), Vector3.new(76, 0, 158),
		Vector3.new(-112, 0, 158), Vector3.new(112, 0, 158),
		Vector3.new(-236, 0, 60), Vector3.new(236, 0, 60),
		Vector3.new(-236, 0, -60), Vector3.new(236, 0, -60),
		Vector3.new(-236, 0, 0), Vector3.new(236, 0, 0),
	} do
		meshTree(folder, pos, 1.1 + (math.abs(pos.X) % 3) * 0.12)
	end

	-- Moved with the building. JailService holds a second copy of this at its
	-- own CELL_CENTER; both are the Detention hall cell's centre in the drawing.
	local detentionCenter = Vector3.new(-438, 0, -14)

	-- ---------------- the bus stop ----------------
	-- Every player's first two seconds of the game are spent standing here, so
	-- this is the one place in the map that has to look built. It used to be a
	-- bare yellow 14 x 14 pad dropped at (20, 152) -- which, once the Great
	-- Court went in, sat on the court paving with its east edge buried in the
	-- entrance cheek wall. It stands where the bus stands now: at the kerb on
	-- the front road, at the head of the court's west flank walk, so the walk
	-- to the front doors is the walk down the court.
	local STOP = Vector3.new(-114, 0, ROAD_Z - 22)
	local shelter = {
		w = 20, -- along x, facing the road
		d = 9, -- along z
		post = 11, -- clear height under the roof
	}
	do
		local hw, hd = shelter.w / 2, shelter.d / 2
		-- a kerb and a paved standing, so the shelter sits on something
		tag(part({
			Name = "BusStopPaving",
			Size = Vector3.new(shelter.w + 6, 0.5, shelter.d + 10),
			CFrame = CFrame.new(STOP.X, 0.25, STOP.Z + 2),
			Color = Color3.fromRGB(92, 92, 98),
			Material = Enum.Material.Slate,
			Parent = folder,
		}), "TexCourtPaving")
		part({
			Name = "BusStopKerb",
			Size = Vector3.new(shelter.w + 6, 1.3, 1.2),
			CFrame = CFrame.new(STOP.X, 0.25, STOP.Z + hd + 5),
			Color = Color3.fromRGB(198, 192, 180),
			Material = Enum.Material.Concrete,
			Parent = folder,
		})
		-- four cast-iron posts with a moulded base and cap on each
		for _, corner in { Vector3.new(-hw + 0.7, 0, -hd + 0.7), Vector3.new(hw - 0.7, 0, -hd + 0.7), Vector3.new(-hw + 0.7, 0, hd - 0.7), Vector3.new(hw - 0.7, 0, hd - 0.7) } do
			local x, z = STOP.X + corner.X, STOP.Z + corner.Z
			part({ Name = "ShelterPostBase", Size = Vector3.new(1.6, 0.8, 1.6), CFrame = CFrame.new(x, 0.9, z), Color = Kit.IRON, Material = Enum.Material.Metal, Parent = folder })
			part({ Name = "ShelterPost", Size = Vector3.new(0.9, shelter.post, 0.9), CFrame = CFrame.new(x, 0.5 + shelter.post / 2 + 0.8, z), Color = Kit.IRON, Material = Enum.Material.Metal, Parent = folder })
			part({ Name = "ShelterPostCap", Size = Vector3.new(1.4, 0.5, 1.4), CFrame = CFrame.new(x, shelter.post + 1.5, z), Color = Kit.IRON, Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
		end
		-- back and sides glazed, so it reads as a shelter and not a shed
		local glassY = 0.5 + (shelter.post - 1.6) / 2 + 1.2
		local glassH = shelter.post - 2.6
		part({ Name = "ShelterBackGlass", Size = Vector3.new(shelter.w - 2.6, glassH, 0.3), CFrame = CFrame.new(STOP.X, glassY, STOP.Z - hd + 0.7), Color = Color3.fromRGB(150, 178, 196), Material = Enum.Material.Glass, Transparency = 0.55, Parent = folder })
		part({ Name = "ShelterBackRail", Size = Vector3.new(shelter.w - 2.6, 0.4, 0.7), CFrame = CFrame.new(STOP.X, glassY - glassH / 2 - 0.2, STOP.Z - hd + 0.7), Color = Kit.IRON, Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
		for _, side in { -1, 1 } do
			part({ Name = "ShelterSideGlass", Size = Vector3.new(0.3, glassH, shelter.d - 2.6), CFrame = CFrame.new(STOP.X + side * (hw - 0.7), glassY, STOP.Z), Color = Color3.fromRGB(150, 178, 196), Material = Enum.Material.Glass, Transparency = 0.55, Parent = folder })
			part({ Name = "ShelterSideRail", Size = Vector3.new(0.7, 0.4, shelter.d - 2.6), CFrame = CFrame.new(STOP.X + side * (hw - 0.7), glassY - glassH / 2 - 0.2, STOP.Z), Color = Kit.IRON, Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
		end
		-- roof: a slate deck on a moulded fascia, oversailing the posts
		part({ Name = "ShelterRoof", Size = Vector3.new(shelter.w + 2.4, 0.8, shelter.d + 2.4), CFrame = CFrame.new(STOP.X, shelter.post + 2.2, STOP.Z), Color = Kit.SLATE, Material = Enum.Material.Slate, Parent = folder })
		part({ Name = "ShelterRoofCap", Size = Vector3.new(shelter.w + 1.2, 0.8, shelter.d + 1.2), CFrame = CFrame.new(STOP.X, shelter.post + 2.9, STOP.Z), Color = Kit.RIDGE, Material = Enum.Material.Slate, Parent = folder }).CanCollide = false
		for _, edge in { Vector3.new(0, 0, hd + 1.2), Vector3.new(0, 0, -hd - 1.2) } do
			part({ Name = "ShelterFascia", Size = Vector3.new(shelter.w + 2.4, 0.7, 0.4), CFrame = CFrame.new(STOP.X + edge.X, shelter.post + 1.5, STOP.Z + edge.Z), Color = Kit.ASHLAR, Material = Enum.Material.Concrete, Parent = folder }).CanCollide = false
		end
		-- a bench of timber slats on iron cheeks
		for i = -1, 1 do
			part({
				Name = "ShelterBenchSlat",
				Size = Vector3.new(shelter.w - 6, 0.5, 1.4),
				CFrame = CFrame.new(STOP.X, 3.2, STOP.Z - hd + 2.0 + i * 1.7),
				Color = Kit.TIMBER,
				Material = Enum.Material.WoodPlanks,
				Parent = folder,
			})
		end
		for _, side in { -1, 1 } do
			part({ Name = "ShelterBenchCheek", Size = Vector3.new(0.5, 3.0, 5.2), CFrame = CFrame.new(STOP.X + side * (shelter.w / 2 - 3.2), 1.5, STOP.Z - hd + 2.0), Color = Kit.IRON, Material = Enum.Material.Metal, Parent = folder })
		end
		-- the stop's own name board, navy and gold like the rest of the signage
		local board = part({
			Name = "BusStopBoard",
			Size = Vector3.new(shelter.w - 4, 2.6, 0.4),
			CFrame = CFrame.new(STOP.X, shelter.post + 0.2, STOP.Z + hd + 0.9),
			Color = Color3.fromRGB(22, 35, 63),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})
		board.CanCollide = false
		signText(board, "CRUMBWORTH HIGH", Color3.fromRGB(217, 180, 92), Enum.NormalId.Back)
		-- a timetable in the back panel, and a lantern so the stop is lit
		local timetable = part({
			Name = "BusStopTimetable",
			Size = Vector3.new(4.4, 6.0, 0.3),
			CFrame = CFrame.new(STOP.X + shelter.w / 2 - 3.4, 6.0, STOP.Z - hd + 1.0),
			Color = Color3.fromRGB(22, 35, 63),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})
		timetable.CanCollide = false
		signText(timetable, "BUSES\n07:40\n08:10\n15:45\n16:20", Color3.fromRGB(217, 180, 92), Enum.NormalId.Back)
		local lantern = part({
			Name = "ShelterLantern",
			Size = Vector3.new(2.0, 2.0, 2.0),
			CFrame = CFrame.new(STOP.X, shelter.post + 0.9, STOP.Z),
			Color = Kit.LANTERN,
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		lantern.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Color = Kit.LANTERN
		glow.Brightness = 1.6
		glow.Range = 26
		glow.Parent = lantern
	end

	-- the spawn pad itself, invisible, under the shelter roof: the pad is the
	-- rule about where players appear, and the shelter is what they see
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(shelter.w - 4, 1, shelter.d - 3)
	spawn.CFrame = CFrame.new(STOP.X, 0.75, STOP.Z + 1)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Color = Palette.BusYellow
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Name = "BusStop"
	spawn.Parent = folder

	-- ---------------- campus grounds ----------------
	local LIBRARY = Vector3.new(-320, 0, -300)
	buildLibrary(folder, LIBRARY)
	-- The walk out to the library. It used to be one 16-wide diagonal from
	-- (0, -150) straight to the library door, which cut corner to corner
	-- across the west half of the Dorm Court -- the one thing a formal court
	-- never has through it. It goes round instead: west along the court's
	-- north edge, south down its flank at x = -180, then east-west into the
	-- door. Every leg is square to the campus grid and none of them enters
	-- the court's rect (x -140..140, z -246..-152).
	buildCampusPath(folder, Vector3.new(0, 0, -140), Vector3.new(-180, 0, -140), 16, true)
	buildCampusPath(folder, Vector3.new(-180, 0, -140), Vector3.new(-180, 0, -256), 16)
	-- the two legs either side of the flank run are laid a course higher, so
	-- neither elbow is sixty-four square studs of two slabs sharing a plane
	buildCampusPath(folder, Vector3.new(-180, 0, -256), LIBRARY + Vector3.new(0, 0, 44), 16, true)

	-- The treeline predates the pool and the tennis stadium, so it plants
	-- trees inside both. Rather than teach every scatter about every venue,
	-- clear the venues afterwards: one list to extend when a venue is added.
	local KEEP_CLEAR = {
		{ c = LIBRARY, rx = 52, rz = 42, what = "the library" },
	}
	local cleared = 0
	for _, item in folder:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local n = item.Name
		if not (n:find("Tree") or n:find("Conifer") or n:find("Palm") or n:find("Flower") or n:find("Hedge")) then
			continue
		end
		for _, zone in KEEP_CLEAR do
			local offset = item.Position - zone.c
			if math.abs(offset.X) < zone.rx and math.abs(offset.Z) < zone.rz then
				item:Destroy()
				cleared += 1
				break
			end
		end
	end
	if cleared > 0 then
		print(("[MapService] cleared %d plants growing through the new venues"):format(cleared))
	end

	buildUpperFloor(folder)
	furnishSubjectRooms(folder)
	furnishUpperRooms(folder)
	buildTeachersQuarters(folder, Vector3.new(-300, 0, -170))
	-- the walk out to the lodge, from the west side of the campus
	buildCampusPath(folder, Vector3.new(-232, 0, -60), Vector3.new(-232, 0, -170), 14)
	buildCampusPath(folder, Vector3.new(-239, 0, -170), Vector3.new(-258, 0, -170), 14)
	buildWayfinding(folder)
	-- last, so every room it lights already exists
	buildLockerIslands(folder)
	buildCourtyards(folder)
	buildBackCampus(folder)
	buildPlanting(folder)
	buildInteriorLights(folder)
	local secretDoors = buildSanctum(folder)
	furnishProps()

	litWindows(folder)
	optimize(folder)
	folder.Parent = workspace

	local _ = trophyFloor

	return {
		plots = plots,
		trim = trimRuns,
		props = propRequests,
		library = LIBRARY,
		conveyorStart = Vector3.new(-190, 0, 65),
		conveyorEnd = Vector3.new(190, 0, 65),
		trophyCashBoard = trophyCashBoard,
		trophyAuraBoard = trophyAuraBoard,
		cliqueBoards = cliqueBoards,
		dormBeds = dormBeds,
		detentionSpot = detentionCenter,
		infirmary = Vector3.new(122, 17, -94),
		secretDoors = secretDoors,
		houseBoard = houseBoard,
		-- the far end of the boulevard, where the headmaster's tunnel arrives
		sanctumSpawn = SANCTUM_ENTRANCE,
		folder = folder,
	}
end

-- Is a world position inside the plot's footprint (with a little slack)?
function MapService.IsInsidePlot(plot: Plot, position: Vector3): boolean
	local localPos = plot.cframe:PointToObjectSpace(position)
	return math.abs(localPos.X) <= plot.halfSize.X + 2
		and math.abs(localPos.Z) <= plot.halfSize.Y + 2
		and localPos.Y < 30
end

local _ = GameConfig -- (kept for future map knobs)

__MapService = MapService

local map = __MapService.Build()
local out = {}
local function esc(s) return (s:gsub('"', '\\"')) end
local function walk(inst, parentName)
  for _, child in ipairs(inst:GetChildren()) do
    local cls = child.ClassName
    if cls == "Part" or cls == "SpawnLocation" or cls == "WedgePart"
      or cls == "CornerWedgePart" or cls == "MeshPart" or cls == "TrussPart" then
      local cf = child.CFrame or CFrame.new(0, 0, 0)
      local size = child.Size or Vector3.new(4, 1.2, 2)
      local color = child.Color or {R = 0.64, G = 0.64, B = 0.65}
      local material = child.Material and child.Material.Name or "Plastic"
      local shape = child.Shape and child.Shape.Name or "Block"
      -- does this part carry a light? the audit counts lit floor area, and a
      -- roofed room with no fixture in it is a cave under Future lighting
      local lit = 0
      local lamps = {}
      -- which faces carry writing, so a sign pressed text-first into a wall
      -- can be found without anybody having to walk up to it
      local guiFaces = {}
      for _, sub in ipairs(child:GetChildren()) do
        if sub.ClassName == "PointLight" or sub.ClassName == "SpotLight" or sub.ClassName == "SurfaceLight" then
          lit = math.max(lit, sub.Range or 16)
          table.insert(lamps, string.format("[%.2f,%.2f]", sub.Range or 16, sub.Brightness or 1))
        end
        if sub.ClassName == "SurfaceGui" then
          local f = sub.Face
          table.insert(guiFaces, '"' .. ((f and f.Name) or "Front") .. '"')
        end
      end
      table.insert(out, string.format(
        '{"n":"%s","s":[%.3f,%.3f,%.3f],"p":[%.3f,%.3f,%.3f],"r":[%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f],"c":[%d,%d,%d],"m":"%s","t":%.2f,"sh":"%s","cls":"%s","cc":%s,"par":"%s","gui":['.. table.concat(guiFaces, ",") ..'],"lit":'.. lit ..',"lamps":['.. table.concat(lamps, ",") ..']}',
        esc(child.Name), size.X, size.Y, size.Z, cf.p[1], cf.p[2], cf.p[3],
        cf.m[1][1], cf.m[1][2], cf.m[1][3], cf.m[2][1], cf.m[2][2], cf.m[2][3], cf.m[3][1], cf.m[3][2], cf.m[3][3],
        math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5),
        material, child.Transparency or 0, shape, cls,
        tostring(child.CanCollide ~= false), esc(parentName or "")))
    end
    -- The name of the thing a part hangs off. A door that MOVES has to own
    -- every piece of itself, and parentage is the only place that is visible.
    walk(child, child.Name)
  end
end
walk(map.folder, "")

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

-- Every named place the map hands to a service: a plot pad, a clique board,
-- the secret door, the infirmary. These are the game's verbs -- if one of them
-- ends up inside a wall or over a hole, that feature is dead and no part-level
-- check would notice. Dumped by key path so the audit can name what it found.
local anchors = {}
local function isVec(v) return type(v) == "table" and type(v.X) == "number" and type(v.Y) == "number" and type(v.Z) == "number" and v.Magnitude ~= nil end
local function record(path, x, y, z)
  table.insert(anchors, string.format('{"k":"%s","p":[%.3f,%.3f,%.3f]}', esc(path), x, y, z))
end
local function scan(value, path, depth)
  if depth > 4 or value == nil then return end
  if type(value) == "table" and value.ClassName == "Part" then
    local cf = value.CFrame
    record(path, cf.p[1], cf.p[2], cf.p[3])
    return
  end
  if isVec(value) then
    record(path, value.X, value.Y, value.Z)
    return
  end
  if type(value) == "table" then
    for k, v in pairs(value) do
      if k ~= "folder" and k ~= "props" and k ~= "trim" and k ~= "_children" and k ~= "_props" and k ~= "_parent" then
        scan(v, path .. "." .. tostring(k), depth + 1)
      end
    end
  end
end
scan(map, "map", 0)
print("ANCHORS[" .. table.concat(anchors, ",") .. "]")
print("[" .. table.concat(out, ",") .. "]")
