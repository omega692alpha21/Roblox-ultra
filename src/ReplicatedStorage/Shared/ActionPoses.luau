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
-- This version writes Transform itself, from a render-step bound AFTER
-- Enum.RenderPriority.Character -- the point in the frame at which the
-- animator has finished. Multiplying our offset into whatever it just wrote is
-- additive by construction: the swing rides on the walk, and nothing can
-- overwrite it because nothing else runs that late.

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
	keys: { [string]: { Key } },
	started: number,
	length: number,
	held: boolean,
}

local active: { Active } = {}
local bound = false

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
			table.remove(active, i)
			continue
		end
		if elapsed >= pose.length then
			if not pose.held then
				table.remove(active, i)
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
				-- multiplied into what the animator just wrote, not over it
				motor.Transform *= offset
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
	local keys: { [string]: { Key } } = {}
	local length = 0
	for jointName, list in action do
		local motor = findMotor(character, jointName)
		if motor then
			motors[jointName] = motor
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
	-- fast second punch restarts the swing instead of fighting the first.
	for i = #active, 1, -1 do
		if active[i].character == character then
			table.remove(active, i)
		end
	end
	table.insert(active, {
		character = character,
		kind = kind,
		motors = motors,
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
			table.remove(active, i)
		end
	end
end

function ActionPoses.Has(kind: string): boolean
	return ACTIONS[kind] ~= nil
end

ActionPoses.Actions = ACTIONS

return ActionPoses
