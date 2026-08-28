--!strict
-- Spawns students that walk the main hallway; players buy them with a
-- ProximityPrompt. Server-authoritative: prices come from config, the client
-- only triggers the prompt.
--
-- Every walker belongs to a clique, and you can only recruit your own. That is
-- what makes the role you picked on your first day mean something after the
-- first day: a Bully's homeroom fills with bullies, and the crew that walks
-- around behind you is recognisably yours.
--
-- Walkers are weighted toward the cliques actually present on the server -- a
-- flat roll would leave four in five walkers useless to any given player and
-- turn the corridor into a queue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Students = require(ReplicatedStorage.Config.Students)
local Cliques = require(ReplicatedStorage.Config.Cliques)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local StudentGen = require(script.Parent.StudentGen)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)
local Signals = require(script.Parent.Parent.Signals)

local ConveyorService = {}

type Walker = {
	model: Model,
	defId: string,
	role: string,
	startedAt: number,
	bought: boolean,
	recruitOwner: Player?,
	recruitUid: string?,
	position: Vector3?,
}

local rng = Random.new()
local walkers: { Walker } = {}
local startPos: Vector3 = Vector3.zero
local endPos: Vector3 = Vector3.zero

local rushUntil = 0

-- Server-wide luck multiplier: config event flag x active Secret Rush window.
local function serverLuck(): number
	local luck = GameConfig.EventLuckMultiplier or 1
	if os.clock() < rushUntil then
		luck *= GameConfig.SecretRushLuckMult
	end
	return luck
end

-- Which clique this walker belongs to. Seven times in ten it is somebody's
-- who is here right now; the rest of the time it is anyone's, so the corridor
-- still has strangers in it.
local function rollRole(): string
	local present = {}
	for _, player in Players:GetPlayers() do
		local id = player:GetAttribute("Clique")
		if typeof(id) == "string" and Cliques.Get(id) then
			table.insert(present, id)
		end
	end
	if #present > 0 and rng:NextNumber() < 0.7 then
		return present[rng:NextInteger(1, #present)]
	end
	return Cliques.List[rng:NextInteger(1, #Cliques.List)].id
end

local function spawnWalker()
	if #walkers >= GameConfig.ConveyorMaxAlive then
		return
	end
	-- roll with the *best* current player luck so buffs feel impactful server-wide
	local bestLuck = 1
	for _, player in Players:GetPlayers() do
		local until_ = player:GetAttribute("LuckUntil")
		if typeof(until_) == "number" and until_ > os.clock() then
			local mult = player:GetAttribute("LuckMult")
			if typeof(mult) == "number" then
				bestLuck = math.max(bestLuck, mult)
			end
		end
	end
	local totalLuck = serverLuck() * bestLuck
	local rarity = Students.RollRarity(rng, totalLuck)
	local def = rarity.students[rng:NextInteger(1, #rarity.students)]
	local mut = Students.RollMutation(rng, totalLuck)
	local mutation = Students.GetMutation(mut)
	local cost = math.ceil(def.cost * (mutation and mutation.mult or 1))
	local model = StudentGen.Create(def.id)
	if not model then
		return
	end
	model.Name = "Walker_" .. def.id
	StudentGen.Decorate(model, def.id, mut, false)

	local role = rollRole()
	local clique = Cliques.Get(role)
	model:SetAttribute("Clique", role)
	-- a ring in the clique's colour, so you can tell across the hall whether a
	-- walker is one of yours before you have walked over to them
	local marker = Instance.new("Part")
	marker.Name = "CliqueRing"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.25, 6, 6)
	marker.Color = clique and clique.color or Color3.fromRGB(200, 200, 200)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.35
	marker.Anchored = false
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Massless = true
	marker.CFrame = CFrame.new(0, 0, 0)
	marker.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recruit"
	prompt.ObjectText = ("%s%s  ·  %s  ·  $%s"):format(
		mutation and mutation.name .. " " or "",
		def.name,
		clique and clique.name or role,
		NumberFormat.Abbreviate(cost)
	)
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not root then
		model:Destroy()
		return
	end
	prompt.Parent = root

	local walker: Walker = { model = model, defId = def.id, role = role, startedAt = os.clock(), bought = false }

	prompt.Triggered:Connect(function(player)
		if walker.bought then
			return
		end
		if not DataService.IsLoaded(player) then
			Remotes.Get("Notify"):FireClient(player, "Your data hasn't loaded yet!", "bad")
			return
		end
		local mine = player:GetAttribute("Clique")
		if mine ~= role then
			local yours = Cliques.Get(typeof(mine) == "string" and mine or nil)
			Remotes.Get("Notify"):FireClient(
				player,
				("%s won't join you — they're %s and you're %s. Recruit your own."):format(
					def.name,
					clique and clique.name or role,
					yours and yours.name or "unsorted"
				),
				"bad"
			)
			return
		end
		if not PlotService.HasPlot(player) then
			Remotes.Get("Notify"):FireClient(player, "You have no homeroom yet — every room is taken. You're in line.", "bad")
			return
		end
		if PlotService.CrewCount(player) >= PlotService.MaxSlots(player) then
			Remotes.Get("Notify"):FireClient(player, "Your homeroom is full! Rebirth or get the +2 Slots pass.", "bad")
			return
		end
		if not EconomyService.TrySpend(player, cost) then
			Remotes.Get("Notify"):FireClient(player, "Not enough lunch money! Need $" .. NumberFormat.Abbreviate(cost), "bad")
			return
		end
		walker.bought = true
		prompt:Destroy()
		local uid = PlotService.AddStudent(player, def.id, mut, false, true, role) -- model deferred: they walk home
		walker.recruitOwner = player
		walker.recruitUid = uid
		walker.position = walker.model:GetPivot().Position
		Signals.Recruited:Fire(player, def.id)
		Remotes.Get("Notify"):FireClient(
			player,
			"Recruited " .. (mutation and mutation.name .. " " or "") .. def.name .. "!",
			mutation and "aura" or "good"
		)
		if rarity.name == "Secret" or rarity.name == "Mythic" then
			Remotes.Get("Notify"):FireAllClients(
				player.DisplayName .. " recruited " .. rarity.name:upper() .. " " .. def.name .. "!",
				"announce"
			)
		end
	end)

	model.Parent = workspace
	StudentGen.Stand(model, CFrame.lookAt(startPos, endPos))
	StudentGen.PlayAnim(model, "walk")
	table.insert(walkers, walker)
end

function ConveyorService.Init(map: { conveyorStart: Vector3, conveyorEnd: Vector3 })
	startPos = map.conveyorStart
	endPos = map.conveyorEnd

	task.spawn(function()
		while true do
			task.wait(GameConfig.ConveyorSpawnInterval)
			spawnWalker()
		end
	end)

	-- Secret Rush: recurring hype window with massively boosted odds
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(GameConfig.SecretRushMinInterval, GameConfig.SecretRushMaxInterval))
			rushUntil = os.clock() + GameConfig.SecretRushDuration
			Remotes.Get("Notify"):FireAllClients(
				("SECRET RUSH! %dx luck in the hallway for %d seconds — GO GO GO!"):format(
					GameConfig.SecretRushLuckMult,
					GameConfig.SecretRushDuration
				),
				"announce"
			)
			task.wait(GameConfig.SecretRushDuration)
			Remotes.Get("Notify"):FireAllClients("Secret Rush is over. Back to class.", "info")
		end
	end)

	RunService.Heartbeat:Connect(function(step: number)
		local now = os.clock()
		for i = #walkers, 1, -1 do
			local walker = walkers[i]
			if not walker.model.Parent then
				table.remove(walkers, i)
				continue
			end
			if walker.bought then
				-- walk to the new desk, then take a seat
				local owner, uid = walker.recruitOwner, walker.recruitUid
				local slotCf = owner and uid and owner.Parent and PlotService.GetSlotWorldCFrame(owner, uid) or nil
				if not slotCf or not uid or not owner then
					walker.model:Destroy()
					table.remove(walkers, i)
					continue
				end
				local target = slotCf.Position
				local pos = walker.position or walker.model:GetPivot().Position
				local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
				local dt = step
				if flat.Magnitude < 2.5 then
					walker.model:Destroy()
					table.remove(walkers, i)
					PlotService.SpawnPendingModel(owner, uid)
				else
					local newPos = pos + flat.Unit * 14 * dt
					walker.position = newPos
					-- root only: PivotTo would replicate every limb, every frame
					local walkerRoot = walker.model.PrimaryPart
					if walkerRoot then
						walkerRoot.CFrame = CFrame.lookAt(
							newPos + Vector3.new(0, 2.6, 0),
							newPos + flat.Unit * 10 + Vector3.new(0, 2.6, 0)
						)
					end
				end
				continue
			end
			local alpha = (now - walker.startedAt) / GameConfig.ConveyorTravelTime
			if alpha >= 1 then
				walker.model:Destroy()
				table.remove(walkers, i)
				continue
			end
			local pos = startPos:Lerp(endPos, alpha)
			local root = walker.model.PrimaryPart
			if root then
				root.CFrame = CFrame.lookAt(pos + Vector3.new(0, 2.6, 0), endPos + Vector3.new(0, 2.6, 0))
			end
		end
	end)
end

return ConveyorService
