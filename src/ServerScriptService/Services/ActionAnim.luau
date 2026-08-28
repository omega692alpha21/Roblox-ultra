--!strict
-- Action animations, dispatched rather than played.
--
-- The first version tweened Motor6D.C0 here, on the server. Nothing appeared
-- to happen: every frame of every tween had to replicate, the owning client's
-- animator overwrote the arm in between, and what arrived was a stutter or
-- nothing at all. The poses live in ReplicatedStorage.Shared.ActionPoses now
-- and every client plays them locally -- instantly for the player who swung,
-- at each viewer's own frame rate for everyone else.
--
-- What is still done here is the knockdown, because a student is a
-- server-anchored mover: there is no client with authority over them to ask.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)

local ActionAnim = {}

-- Tell every client to play `kind` on this character.
function ActionAnim.Play(character: Model?, kind: string)
	if not character or not character.Parent then
		return
	end
	Remotes.Get("PlayAction"):FireAllClients(character, kind)
end

function ActionAnim.Punch(character: Model)
	ActionAnim.Play(character, "punch")
end

function ActionAnim.Throw(character: Model)
	ActionAnim.Play(character, "throw")
end

function ActionAnim.Hurt(character: Model?)
	ActionAnim.Play(character, "hurt")
end

function ActionAnim.KnockOut(character: Model?)
	ActionAnim.Play(character, "knockout")
end

function ActionAnim.Flex(character: Model?)
	ActionAnim.Play(character, "flex")
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
