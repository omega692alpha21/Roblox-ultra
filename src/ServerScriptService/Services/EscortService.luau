--!strict
-- Your crew, out of their desks and walking behind you.
--
-- Recruiting used to end at a desk: you paid, a student sat down, a number went
-- up. Nothing you recruited was ever with you. Now the most recent few come
-- along -- they follow, they pile in when you throw a punch, they go after
-- whoever hits you, and standing between you and a fist is worth something.
--
-- They are separate models from the desk ones on purpose. The homeroom is the
-- income and it keeps working; this is the same students walking with you
-- between lessons, which is what a school crew actually is.
--
-- Movement is root-only, like every other NPC in this game: PivotTo on a
-- rigged student writes twenty part CFrames and replicates every one, and five
-- of those per player at 60Hz is what makes a server crawl.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cliques = require(ReplicatedStorage.Config.Cliques)
local DataService = require(script.Parent.DataService)
local StudentGen = require(script.Parent.StudentGen)
local ActionAnim = require(script.Parent.ActionAnim)
local EffectsService = require(script.Parent.EffectsService)
local SquadService = require(script.Parent.SquadService)
local Signals = require(script.Parent.Parent.Signals)

local EscortService = {}

-- two to start, one more each school year, and never more than five: past
-- that they stop reading as a crew and start reading as a crowd
local BASE_ESCORTS = 2
local MAX_ESCORTS = 5
local FOLLOW_SPEED = 19
local SPACING = 5.5

type Escort = {
	model: Model,
	root: BasePart,
	uid: string,
	slot: number,
	position: Vector3,
	swingUntil: number,
	target: BasePart?,
	targetUntil: number,
	moving: boolean,
}

local escorts: { [Player]: { Escort } } = {}

function EscortService.SlotsFor(player: Player): number
	local profile = DataService.Get(player)
	local grade = profile and profile.grade or 0
	return math.clamp(BASE_ESCORTS + grade, BASE_ESCORTS, MAX_ESCORTS)
end

-- How much of a hit the crew soaks. Someone standing in front of you is the
-- oldest defence there is, and it gives recruiting a reason beyond income.
function EscortService.Guard(player: Player): number
	local crew = escorts[player]
	local count = crew and #crew or 0
	return 1 - math.min(count, MAX_ESCORTS) * 0.05
end

local EMPTY: { Escort } = {}

-- Feet-on-the-floor raycasts ignore every character in the game: an escort
-- must not stand on its own owner's head, or on another escort.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

local function refreshGroundFilter()
	local ignore: { Instance } = {}
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			table.insert(ignore, model)
		end
	end
	groundParams.FilterDescendantsInstances = ignore
end

local function clear(player: Player)
	for _, escort in escorts[player] or EMPTY do
		if escort.model.Parent then
			escort.model:Destroy()
		end
	end
	escorts[player] = nil
	player:SetAttribute("EscortCount", 0)
end

local function spawnFor(player: Player)
	local profile = DataService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root then
		return
	end
	clear(player)

	local want = EscortService.SlotsFor(player)
	local crew = profile.crew or {}
	local list: { Escort } = {}
	-- the most recent recruits walk with you: the ones you just paid for are
	-- the ones you want to see
	for index = #crew, 1, -1 do
		if #list >= want then
			break
		end
		local member = crew[index]
		local model = StudentGen.Create(member.id, "_escort" .. member.uid:sub(1, 6))
		if model then
			StudentGen.Decorate(model, member.id, member.mut, member.star)
			model.Name = "Escort_" .. player.Name .. "_" .. member.uid:sub(1, 6)
			model:SetAttribute("EscortOf", player.UserId)
			-- the same ring the hallway walkers wear, so a crew reads as one
			-- clique at a glance rather than as five random students
			local clique = Cliques.Get(member.role)
			local ring = Instance.new("Part")
			ring.Name = "CliqueRing"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.25, 6, 6)
			ring.Color = clique and clique.color or Color3.fromRGB(200, 200, 200)
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.45
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.Massless = true
			ring.Parent = model

			local escortRoot = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
			if escortRoot then
				local slot = #list + 1
				local behind = root.Position - root.CFrame.LookVector * (SPACING * slot)
				model.Parent = workspace
				StudentGen.Stand(model, CFrame.new(behind))
				StudentGen.PlayAnim(model, "idle")
				table.insert(list, {
					model = model,
					root = escortRoot,
					uid = member.uid,
					slot = slot,
					position = behind,
					swingUntil = 0,
					targetUntil = 0,
					moving = false,
				})
			else
				model:Destroy()
			end
		end
	end
	escorts[player] = list
	player:SetAttribute("EscortCount", #list)
end

-- Send the crew at something for a few seconds.
--
-- A crew is what turns a fight into a brawl: everyone in the squad who is
-- close enough to see it sends their escorts in too. Far-away squad-mates
-- stay out of it, because escorts sprinting across the whole school to a
-- fight they cannot see just looks broken.
local BACKUP_RANGE = 120

local function sicOne(player: Player, targetRoot: BasePart)
	for _, escort in escorts[player] or EMPTY do
		escort.target = targetRoot
		escort.targetUntil = os.clock() + 4
	end
end

local function sic(player: Player, targetModel: Instance?)
	if typeof(targetModel) ~= "Instance" or not targetModel:IsA("Model") then
		return
	end
	local targetRoot = (targetModel.PrimaryPart or targetModel:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not targetRoot then
		return
	end
	sicOne(player, targetRoot)
	for _, mate in SquadService.MembersOf(player) do
		if mate ~= player and mate.Parent then
			local character = mate.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - targetRoot.Position).Magnitude <= BACKUP_RANGE then
				sicOne(mate, targetRoot)
			end
		end
	end
end

function EscortService.Init()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(1.5)
			if player.Parent then
				spawnFor(player)
			end
		end)
		if player.Character then
			task.delay(2, function()
				if player.Parent then
					spawnFor(player)
				end
			end)
		end
	end
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(clear)

	-- the crew changes when you recruit, fuse, get robbed or graduate
	Signals.CrewChanged:Connect(function(player)
		task.delay(1.5, function()
			if player.Parent and player.Character then
				spawnFor(player)
			end
		end)
	end)

	Signals.Punched:Connect(function(player, targetModel)
		sic(player, targetModel)
	end)
	Signals.Damaged:Connect(function(player, from)
		if from and typeof(from) == "Instance" and from:IsA("Player") then
			sic(player, (from :: Player).Character)
		end
	end)

	refreshGroundFilter()
	-- characters come and go; the exclude list is cheap to rebuild and very
	-- expensive to get wrong (an escort standing on your head)
	task.spawn(function()
		while true do
			task.wait(3)
			refreshGroundFilter()
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		for player, list in escorts do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			for _, escort in list do
				if not escort.model.Parent then
					continue
				end
				local goal: Vector3
				local facing: Vector3
				local target = escort.target
				if target and target.Parent and escort.targetUntil > now then
					-- close on whoever we were sent at, and stop a pace short
					local toward = target.Position - escort.position
					local flat = Vector3.new(toward.X, 0, toward.Z)
					if flat.Magnitude > 4 then
						goal = escort.position + flat.Unit * math.min(FOLLOW_SPEED * dt * 1.3, flat.Magnitude - 4)
					else
						goal = escort.position
						if escort.swingUntil < now then
							escort.swingUntil = now + 1.1
							ActionAnim.Play(escort.model, "punch")
							EffectsService.Hit(
								target.Position + Vector3.new(0, 1, 0),
								Color3.fromRGB(255, 214, 120),
								"PunchHit",
								10
							)
						end
					end
					facing = target.Position
				else
					escort.target = nil
					-- a loose wedge behind the player, offset left and right so
					-- they are not a single-file queue
					local side = if escort.slot % 2 == 0 then 1 else -1
					local back = root.CFrame.LookVector * -(SPACING + math.floor(escort.slot / 2) * 2.6)
					local across = root.CFrame.RightVector * (side * 3.4)
					local want = root.Position + back + across
					local toward = want - escort.position
					local flat = Vector3.new(toward.X, 0, toward.Z)
					if flat.Magnitude > 1.2 then
						goal = escort.position + flat.Unit * math.min(FOLLOW_SPEED * dt, flat.Magnitude)
					else
						goal = escort.position
					end
					facing = root.Position
					-- if they fall a long way behind, put them back rather than
					-- letting them jog through half the school
					if flat.Magnitude > 90 then
						goal = want
					end
				end

				-- Put their feet on whatever is under them.
				--
				-- They used to keep the Y they spawned at forever, which is
				-- why a crew read as floating: follow a player up a staircase
				-- and they trail along at ground level through the treads,
				-- follow them downstairs and they hover. The root is placed a
				-- fixed height above the surface below instead.
				local hit = workspace:Raycast(
					Vector3.new(goal.X, escort.position.Y + 6, goal.Z),
					Vector3.new(0, -40, 0),
					groundParams
				)
				local groundY = if hit then hit.Position.Y else goal.Y - 2.6
				local moved = (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(escort.position.X, 0, escort.position.Z)).Magnitude
				escort.position = Vector3.new(goal.X, groundY + 2.6, goal.Z)

				-- And play the animation that matches what they are doing.
				-- They were spawned into "idle" and never taken out of it, so
				-- a crew slid along the corridor standing perfectly still.
				local moving = moved > dt * 2
				if moving ~= escort.moving then
					escort.moving = moving
					StudentGen.PlayAnim(escort.model, if moving then "walk" else "idle")
				end

				local at = escort.position
				local look = Vector3.new(facing.X, at.Y, facing.Z)
				if (look - at).Magnitude > 0.1 then
					escort.root.CFrame = CFrame.lookAt(at, look)
				end
			end
		end
	end)
end

return EscortService
