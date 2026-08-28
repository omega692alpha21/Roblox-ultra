--!strict
-- Ambient life: NPC students wander Crumbworth High between points of interest,
-- walking, idling, and giving the campus a pulse. Purely cosmetic — no prompts.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StudentGen = require(script.Parent.StudentGen)

local NPCDirector = {}

local POIS = {
	Vector3.new(-150, 0, 70), -- main corridor west
	Vector3.new(150, 0, 70), -- main corridor east
	Vector3.new(28, 0, 162), -- bus stop / spawn
	Vector3.new(-204, 0, -29), -- cafeteria
	Vector3.new(0, 0, -100), -- gym
	Vector3.new(-116, 0, 0), -- west courtyard (cliques)
	Vector3.new(116, 0, 0), -- east courtyard (courts)
	Vector3.new(-74, 0, -94), -- classroom 101
	Vector3.new(204, 0, -29), -- trophy hall
	Vector3.new(0, 0, 22), -- atrium, beside the fountain
	-- OUTSIDE the doors, on the path. These used to sit at z = -186, which is
	-- a stud from the washroom's first toilet: every student sent to the porch
	-- walked into a lavatory and stood there.
	Vector3.new(-176, 0, -180), -- boys dorm porch
	Vector3.new(176, 0, -180), -- girls dorm porch
}

local AMBIENT_IDS = {
	"sleepy_kid", "gum_chewer", "juice_box_kid", "pencil_borrower", "hall_wanderer",
	"homework_forgetter", "class_clown", "locker_lurker", "hall_monitor",
}

type Npc = {
	model: Model,
	root: BasePart?,
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

-- Repaint an avatar into the school uniform (white shirt, navy slacks).
local UNIFORM_SHIRT = Color3.fromRGB(242, 242, 238)
local UNIFORM_PANTS = Color3.fromRGB(38, 46, 66)
local function applyUniform(model: Model)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			local name = child.Name
			if name:find("Torso") or name:find("Arm") or name:find("Hand") then
				child.Color = UNIFORM_SHIRT
			elseif name:find("Leg") or name:find("Foot") then
				child.Color = UNIFORM_PANTS
			end
		end
	end
end

-- Fixed seated students that dress the reference scenes (classroom, courtyard).
local SEATED: { { pos: Vector3, look: Vector3 } } = {
	-- classroom chairs face the whiteboard
	{ pos = Vector3.new(-24, 2.4, -154.6), look = Vector3.new(-24, 2.4, -180) },
	{ pos = Vector3.new(-10, 2.4, -154.6), look = Vector3.new(-10, 2.4, -180) },
	{ pos = Vector3.new(4, 2.4, -140.6), look = Vector3.new(4, 2.4, -180) },
	{ pos = Vector3.new(18, 2.4, -154.6), look = Vector3.new(18, 2.4, -180) },
	-- courtyard platform edge, watching the courts
	{ pos = Vector3.new(-50, 3.6, 120), look = Vector3.new(0, 3, 150) },
	{ pos = Vector3.new(-50, 3.6, 128), look = Vector3.new(0, 3, 158) },
	{ pos = Vector3.new(-50, 3.6, 136), look = Vector3.new(10, 3, 160) },
}

local function spawnSeated()
	for i, seat in SEATED do
		local defId = AMBIENT_IDS[rng:NextInteger(1, #AMBIENT_IDS)]
		local model = StudentGen.Create(defId, "_seat" .. i)
		if model then
			local head = model:FindFirstChild("Head")
			local nameTag = head and head:FindFirstChild("NameTag")
			if nameTag then
				nameTag:Destroy()
			end
			model.Name = "SeatedNPC" .. i
			applyUniform(model)
			model.Parent = workspace
			StudentGen.SitPose(model, CFrame.lookAt(seat.pos, seat.look))
			StudentGen.PlayAnim(model, "idle")
		end
	end
end

function NPCDirector.Init(count: number?)
	spawnSeated()
	for i = 1, count or 20 do
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
		if i % 4 ~= 0 then
			applyUniform(model) -- most of the school wears uniform; a few rebels don't
		end
		local start = POIS[rng:NextInteger(1, #POIS)] + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		model.Parent = workspace
		StudentGen.Stand(model, CFrame.new(start))
		local npc: Npc = {
			model = model,
			root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?,
			position = start,
			target = pickTarget(start),
			speed = rng:NextNumber(6, 10),
			idleUntil = 0,
			walking = true,
		}
		StudentGen.PlayAnim(model, "walk")
		table.insert(npcs, npc)
	end

	-- Model:PivotTo on a rigged student writes ~20 part CFrames and replicates
	-- every one of them. Twenty students at 60Hz is 24,000 CFrame updates a
	-- second, which starved replication and made *everyone's* movement stutter.
	-- Setting the anchored root instead sends one CFrame; each client's own
	-- joint solver carries the limbs along, exactly like a real character.
	local ACTIVE_RANGE = 260

	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		local watchers: { Vector3 } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				table.insert(watchers, root.Position)
			end
		end
		if #watchers == 0 then
			return
		end

		for _, npc in npcs do
			if not npc.model.Parent then
				continue
			end
			-- nobody can see them: skip entirely. Streaming has already sent
			-- them away, so simulating them is pure server cost.
			local visible = false
			for _, watcher in watchers do
				if (watcher - npc.position).Magnitude < ACTIVE_RANGE then
					visible = true
					break
				end
			end
			if not visible then
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
			local root = npc.root
			if root then
				root.CFrame = CFrame.lookAt(
					npc.position + Vector3.new(0, 2.6, 0),
					npc.position + flat.Unit * 10 + Vector3.new(0, 2.6, 0)
				)
			end
		end
	end)
end

return NPCDirector
