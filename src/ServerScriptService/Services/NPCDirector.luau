--!strict
-- Ambient life: NPC students wander Crumbworth High between points of interest,
-- walking, idling, and giving the campus a pulse. Purely cosmetic — no prompts.

local RunService = game:GetService("RunService")

local StudentGen = require(script.Parent.StudentGen)

local NPCDirector = {}

local POIS = {
	Vector3.new(-140, 0, 6), -- hallway west
	Vector3.new(140, 0, -6), -- hallway east
	Vector3.new(0, 0, 22), -- bus stop / spawn
	Vector3.new(-200, 0, 60), -- cafeteria
	Vector3.new(200, 0, 60), -- gym
	Vector3.new(0, 0, 150), -- courtyard
	Vector3.new(0, 0, -140), -- classroom
	Vector3.new(200, 0, -60), -- trophy hall
	Vector3.new(-70, 0, 110), -- flowerbeds
	Vector3.new(-195, 0, 175), -- boys dorm porch
	Vector3.new(195, 0, 175), -- girls dorm porch
}

local AMBIENT_IDS = {
	"sleepy_kid", "gum_chewer", "juice_box_kid", "pencil_borrower", "hall_wanderer",
	"homework_forgetter", "class_clown", "locker_lurker", "hall_monitor",
}

type Npc = {
	model: Model,
	position: Vector3,
	target: Vector3,
	speed: number,
	idleUntil: number,
	walking: boolean,
}

local npcs: { Npc } = {}
local rng = Random.new()

local function pickTarget(current: Vector3): Vector3
	for _ = 1, 5 do
		local poi = POIS[rng:NextInteger(1, #POIS)]
		if (poi - current).Magnitude > 30 then
			return poi + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
		end
	end
	return POIS[rng:NextInteger(1, #POIS)]
end

function NPCDirector.Init(count: number?)
	for i = 1, count or 9 do
		local defId = AMBIENT_IDS[rng:NextInteger(1, #AMBIENT_IDS)]
		local model = StudentGen.Create(defId, "_npc" .. i)
		if not model then
			continue
		end
		-- ambient NPCs don't show recruit info
		local head = model:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("NameTag")
		if tag then
			tag:Destroy()
		end
		model.Name = "AmbientNPC" .. i
		local start = POIS[rng:NextInteger(1, #POIS)] + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		model.Parent = workspace
		StudentGen.Stand(model, CFrame.new(start))
		local npc: Npc = {
			model = model,
			position = start,
			target = pickTarget(start),
			speed = rng:NextNumber(6, 10),
			idleUntil = 0,
			walking = true,
		}
		StudentGen.PlayAnim(model, "walk")
		table.insert(npcs, npc)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		for _, npc in npcs do
			if not npc.model.Parent then
				continue
			end
			if not npc.walking then
				if now >= npc.idleUntil then
					npc.walking = true
					npc.target = pickTarget(npc.position)
					StudentGen.PlayAnim(npc.model, "walk")
				end
				continue
			end
			local offset = npc.target - npc.position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < 2 then
				npc.walking = false
				npc.idleUntil = now + rng:NextNumber(4, 14)
				StudentGen.PlayAnim(npc.model, "idle")
				continue
			end
			npc.position += flat.Unit * npc.speed * dt
			npc.model:PivotTo(CFrame.lookAt(npc.position + Vector3.new(0, 2.6, 0), npc.position + flat.Unit * 10 + Vector3.new(0, 2.6, 0)))
		end
	end)
end

return NPCDirector
