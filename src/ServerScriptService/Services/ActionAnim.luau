--!strict
-- Hand-built action animations.
--
-- Punching and throwing used to play nothing at all: the avatar stood still
-- and a projectile appeared, which is why the actions read as low quality.
-- These pose the arm directly through its Motor6D C0, which layers on top of
-- whatever walk/idle track is running and replicates to every client, so we
-- get real swings without shipping animation assets.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ActionAnim = {}

type Joint = { motor: Motor6D, base: CFrame }

-- R15 first, R6 as the fallback, so this works whatever rig the player picked.
local function findJoint(character: Model, r15Part: string, r15Motor: string, r6Part: string, r6Motor: string): Joint?
	local part = character:FindFirstChild(r15Part)
	local motor = part and part:FindFirstChild(r15Motor)
	if not (motor and motor:IsA("Motor6D")) then
		part = character:FindFirstChild(r6Part)
		motor = part and part:FindFirstChild(r6Motor)
	end
	if motor and motor:IsA("Motor6D") then
		local saved = motor:GetAttribute("BaseC0")
		if typeof(saved) ~= "CFrame" then
			motor:SetAttribute("BaseC0", motor.C0)
			saved = motor.C0
		end
		return { motor = motor, base = saved :: CFrame }
	end
	return nil
end

local function rightArm(character: Model): Joint?
	return findJoint(character, "RightUpperArm", "RightShoulder", "Torso", "Right Shoulder")
end

local function rightElbow(character: Model): Joint?
	return findJoint(character, "RightLowerArm", "RightElbow", "__none", "__none")
end

local function torso(character: Model): Joint?
	return findJoint(character, "UpperTorso", "Waist", "__none", "__none")
end

-- one keyframe: where the joint goes and how long it takes to get there
type Key = { offset: CFrame, time: number, style: Enum.EasingStyle? }

local function playJoint(joint: Joint?, keys: { Key })
	if not joint then
		return
	end
	local motor, base = joint.motor, joint.base
	task.spawn(function()
		for _, key in keys do
			if not motor.Parent then
				return
			end
			local info = TweenInfo.new(key.time, key.style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(motor, info, { C0 = base * key.offset }):Play()
			task.wait(key.time)
		end
		if motor.Parent then
			motor.C0 = base
		end
	end)
end

local busy: { [Model]: number } = {}

local function claim(character: Model, seconds: number): boolean
	local now = os.clock()
	if (busy[character] or 0) > now then
		return false
	end
	busy[character] = now + seconds
	return true
end

-- A jab: wind the shoulder back, snap it through, recover.
function ActionAnim.Punch(character: Model)
	if not claim(character, 0.36) then
		return
	end
	playJoint(rightArm(character), {
		{ offset = CFrame.Angles(math.rad(-30), 0, math.rad(10)), time = 0.08 },
		{ offset = CFrame.Angles(math.rad(105), 0, math.rad(-18)), time = 0.06, style = Enum.EasingStyle.Back },
		{ offset = CFrame.Angles(math.rad(95), 0, math.rad(-14)), time = 0.06 },
		{ offset = CFrame.new(), time = 0.16 },
	})
	playJoint(rightElbow(character), {
		{ offset = CFrame.Angles(math.rad(-55), 0, 0), time = 0.08 },
		{ offset = CFrame.Angles(math.rad(6), 0, 0), time = 0.06 },
		{ offset = CFrame.new(), time = 0.2 },
	})
	playJoint(torso(character), {
		{ offset = CFrame.Angles(0, math.rad(16), 0), time = 0.08 },
		{ offset = CFrame.Angles(0, math.rad(-20), 0), time = 0.06 },
		{ offset = CFrame.new(), time = 0.2 },
	})
end

-- An overarm throw: the arm goes all the way back, then whips over the top.
function ActionAnim.Throw(character: Model)
	if not claim(character, 0.46) then
		return
	end
	playJoint(rightArm(character), {
		{ offset = CFrame.Angles(math.rad(-145), 0, math.rad(14)), time = 0.15 },
		{ offset = CFrame.Angles(math.rad(80), 0, math.rad(-10)), time = 0.09, style = Enum.EasingStyle.Back },
		{ offset = CFrame.Angles(math.rad(40), 0, 0), time = 0.08 },
		{ offset = CFrame.new(), time = 0.18 },
	})
	playJoint(rightElbow(character), {
		{ offset = CFrame.Angles(math.rad(-80), 0, 0), time = 0.15 },
		{ offset = CFrame.Angles(math.rad(0), 0, 0), time = 0.09 },
		{ offset = CFrame.new(), time = 0.22 },
	})
	playJoint(torso(character), {
		{ offset = CFrame.Angles(math.rad(-8), math.rad(26), 0), time = 0.15 },
		{ offset = CFrame.Angles(math.rad(10), math.rad(-22), 0), time = 0.09 },
		{ offset = CFrame.new(), time = 0.22 },
	})
end

-- Motor6D poses survive respawns only if we forget the old character.
function ActionAnim.Init()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for character, until_ in busy do
			if not character.Parent or until_ + 5 < now then
				busy[character] = nil
			end
		end
	end)
end

-- Knock a student flat for a couple of seconds. They are root-anchored movers
-- rather than physics bodies, so this is a shove and a lie-down: rotate the
-- root, drop it, and stand it back up on a timer. Shared by the fist and the
-- thrown toy, which is why it lives here rather than in either.
local knockedUntil: { [Model]: number } = {}

function ActionAnim.KnockDown(model: Model, from: Vector3, seconds: number?)
	local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not root then
		return false
	end
	local now = os.clock()
	if (knockedUntil[model] or 0) > now then
		return false
	end
	local hold = seconds or 2.4
	knockedUntil[model] = now + hold + 0.6

	local direction = root.Position - from
	direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.new(0, 0, 1)
	local upright = root.CFrame - root.CFrame.Position
	root.CFrame = CFrame.new(root.Position + direction * 1.5 - Vector3.new(0, 1.4, 0))
		* upright
		* CFrame.Angles(math.rad(-72), 0, 0)

	task.delay(hold, function()
		if model.Parent and root.Parent then
			root.CFrame = CFrame.new(root.Position + Vector3.new(0, 1.4, 0)) * upright
		end
		knockedUntil[model] = nil
	end)
	return true
end

return ActionAnim
