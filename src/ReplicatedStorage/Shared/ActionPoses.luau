--!strict
-- The action animations, as poses rather than assets.
--
-- There are no punch or throw animations in Roblox's free set and none can be
-- uploaded through Open Cloud, so these are built out of Motor6D offsets: a
-- short list of keyframes per joint, layered on top of whatever walk or idle
-- track is already running. The animator writes Motor6D.Transform and this
-- writes C0, and the joint ends up as the product of both, so the swing rides
-- on the walk instead of fighting it.
--
-- This module runs on the CLIENT. The first version tweened joints on the
-- server, which is why nothing appeared to happen: every frame of the tween
-- had to replicate, the owning client's animator overwrote the arm in between,
-- and what arrived was a stutter or nothing at all. The server now just says
-- "this character punched" and every client plays it locally, at its own frame
-- rate, instantly for the player who threw it.

local TweenService = game:GetService("TweenService")

local ActionPoses = {}

type Joint = { motor: Motor6D, base: CFrame }
export type Key = { offset: CFrame, time: number, style: Enum.EasingStyle? }

local function findJoint(character: Model, r15Part: string, r15Motor: string, r6Part: string, r6Motor: string): Joint?
	local part = character:FindFirstChild(r15Part)
	local motor = part and part:FindFirstChild(r15Motor)
	if not (motor and motor:IsA("Motor6D")) then
		part = character:FindFirstChild(r6Part)
		motor = part and part:FindFirstChild(r6Motor)
	end
	if motor and motor:IsA("Motor6D") then
		-- the rest pose, captured once and kept on the joint, so a pose that
		-- is interrupted still has somewhere to return to
		local saved = motor:GetAttribute("BaseC0")
		if typeof(saved) ~= "CFrame" then
			motor:SetAttribute("BaseC0", motor.C0)
			saved = motor.C0
		end
		return { motor = motor, base = saved :: CFrame }
	end
	return nil
end

local JOINTS: { [string]: { string } } = {
	rightArm = { "RightUpperArm", "RightShoulder", "Torso", "Right Shoulder" },
	rightElbow = { "RightLowerArm", "RightElbow", "__none", "__none" },
	leftArm = { "LeftUpperArm", "LeftShoulder", "Torso", "Left Shoulder" },
	torso = { "UpperTorso", "Waist", "__none", "__none" },
	head = { "Head", "Neck", "Head", "Neck" },
}

local function play(character: Model, jointName: string, keys: { Key })
	local spec = JOINTS[jointName]
	if not spec then
		return
	end
	local joint = findJoint(character, spec[1], spec[2], spec[3], spec[4])
	if not joint then
		return
	end
	local motor, base = joint.motor, joint.base
	task.spawn(function()
		for _, key in keys do
			if not motor.Parent then
				return
			end
			TweenService:Create(
				motor,
				TweenInfo.new(key.time, key.style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = base * key.offset }
			):Play()
			task.wait(key.time)
		end
		if motor.Parent then
			motor.C0 = base
		end
	end)
end

local function deg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- Each action is a table of joint -> keyframes. Times are in seconds and run
-- one after another, so the whole list is the length of the action.
local ACTIONS: { [string]: { [string]: { Key } } } = {
	-- a jab: wind the shoulder back, snap it through, recover
	punch = {
		rightArm = {
			{ offset = deg(-34, 0, 12), time = 0.07 },
			{ offset = deg(108, 0, -20), time = 0.06, style = Enum.EasingStyle.Back },
			{ offset = deg(96, 0, -14), time = 0.06 },
			{ offset = CFrame.new(), time = 0.16 },
		},
		rightElbow = {
			{ offset = deg(-60, 0, 0), time = 0.07 },
			{ offset = deg(8, 0, 0), time = 0.06 },
			{ offset = CFrame.new(), time = 0.2 },
		},
		leftArm = {
			{ offset = deg(24, 0, -14), time = 0.07 },
			{ offset = deg(10, 0, -8), time = 0.12 },
			{ offset = CFrame.new(), time = 0.16 },
		},
		torso = {
			{ offset = deg(0, 18, 0), time = 0.07 },
			{ offset = deg(0, -22, 0), time = 0.06 },
			{ offset = CFrame.new(), time = 0.2 },
		},
	},
	-- an overarm throw: all the way back, then whipped over the top
	throw = {
		rightArm = {
			{ offset = deg(-120, 0, 22), time = 0.13 },
			{ offset = deg(120, 0, -16), time = 0.08, style = Enum.EasingStyle.Back },
			{ offset = deg(70, 0, -10), time = 0.09 },
			{ offset = CFrame.new(), time = 0.18 },
		},
		rightElbow = {
			{ offset = deg(-84, 0, 0), time = 0.13 },
			{ offset = deg(4, 0, 0), time = 0.08 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		torso = {
			{ offset = deg(0, 26, 0), time = 0.13 },
			{ offset = deg(0, -26, 0), time = 0.08 },
			{ offset = CFrame.new(), time = 0.24 },
		},
	},
	-- taking one: a flinch, quick in and slow out
	hurt = {
		torso = {
			{ offset = deg(-14, 0, 6), time = 0.06 },
			{ offset = CFrame.new(), time = 0.26 },
		},
		head = {
			{ offset = deg(12, -10, 0), time = 0.06 },
			{ offset = CFrame.new(), time = 0.3 },
		},
		leftArm = {
			{ offset = deg(-26, 0, -30), time = 0.06 },
			{ offset = CFrame.new(), time = 0.3 },
		},
	},
	-- out cold: both arms drop, the head lolls, held long enough to read
	knockout = {
		torso = {
			{ offset = deg(-34, 0, 10), time = 0.14 },
			{ offset = deg(-30, 0, 8), time = 0.9 },
			{ offset = CFrame.new(), time = 0.3 },
		},
		head = {
			{ offset = deg(26, 0, 14), time = 0.14 },
			{ offset = deg(24, 0, 12), time = 0.9 },
			{ offset = CFrame.new(), time = 0.3 },
		},
		rightArm = {
			{ offset = deg(-40, 0, 26), time = 0.14 },
			{ offset = deg(-36, 0, 24), time = 0.9 },
			{ offset = CFrame.new(), time = 0.3 },
		},
		leftArm = {
			{ offset = deg(-40, 0, -26), time = 0.14 },
			{ offset = deg(-36, 0, -24), time = 0.9 },
			{ offset = CFrame.new(), time = 0.3 },
		},
	},
	-- landed one: a short celebration, so a knockout has a punctuation mark
	flex = {
		rightArm = {
			{ offset = deg(-100, 0, 40), time = 0.16 },
			{ offset = deg(-104, 0, 44), time = 0.5 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		leftArm = {
			{ offset = deg(-100, 0, -40), time = 0.16 },
			{ offset = deg(-104, 0, -44), time = 0.5 },
			{ offset = CFrame.new(), time = 0.24 },
		},
		torso = {
			{ offset = deg(-8, 0, 0), time = 0.16 },
			{ offset = CFrame.new(), time = 0.6 },
		},
	},
}

-- Don't stack two actions on one body: the second would tween from wherever
-- the first had got to and the pair would fight over the return to rest.
local busy: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

function ActionPoses.Play(character: Model, kind: string): boolean
	local action = ACTIONS[kind]
	if not action or not character or not character.Parent then
		return false
	end
	local length = 0
	for _, keys in action do
		local total = 0
		for _, key in keys do
			total += key.time
		end
		length = math.max(length, total)
	end
	local now = os.clock()
	if (busy[character] or 0) > now then
		return false
	end
	busy[character] = now + length * 0.8
	for jointName, keys in action do
		play(character, jointName, keys)
	end
	return true
end

ActionPoses.Actions = ACTIONS

return ActionPoses
