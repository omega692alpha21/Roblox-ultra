--!strict
-- Spawns students that walk the main hallway; players buy them with a ProximityPrompt.
-- Server-authoritative: prices come from config, the client only triggers the prompt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Students = require(ReplicatedStorage.Config.Students)
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
	startedAt: number,
	bought: boolean,
}

local rng = Random.new()
local walkers: { Walker } = {}
local startPos: Vector3 = Vector3.zero
local endPos: Vector3 = Vector3.zero

-- Server-wide luck multiplier from events (config flag) + per-buy player luck applies at roll time.
local function serverLuck(): number
	return GameConfig.EventLuckMultiplier or 1
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
	local rarity = Students.RollRarity(rng, serverLuck() * bestLuck)
	local def = rarity.students[rng:NextInteger(1, #rarity.students)]
	local model = StudentGen.Create(def.id)
	if not model then
		return
	end
	model.Name = "Walker_" .. def.id

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recruit"
	prompt.ObjectText = def.name .. "  $" .. NumberFormat.Abbreviate(def.cost)
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not root then
		model:Destroy()
		return
	end
	prompt.Parent = root

	local walker: Walker = { model = model, defId = def.id, startedAt = os.clock(), bought = false }

	prompt.Triggered:Connect(function(player)
		if walker.bought then
			return
		end
		if not DataService.IsLoaded(player) then
			Remotes.Get("Notify"):FireClient(player, "Your data hasn't loaded yet!", "bad")
			return
		end
		if PlotService.CrewCount(player) >= PlotService.MaxSlots(player) then
			Remotes.Get("Notify"):FireClient(player, "Your homeroom is full! Rebirth or get the +2 Slots pass.", "bad")
			return
		end
		if not EconomyService.TrySpend(player, def.cost) then
			Remotes.Get("Notify"):FireClient(player, "Not enough lunch money! Need $" .. NumberFormat.Abbreviate(def.cost), "bad")
			return
		end
		walker.bought = true
		PlotService.AddStudent(player, def.id)
		Signals.Recruited:Fire(player, def.id)
		Remotes.Get("Notify"):FireClient(player, "Recruited " .. def.name .. "!", "good")
		if rarity.name == "Secret" or rarity.name == "Mythic" then
			Remotes.Get("Notify"):FireAllClients(
				player.DisplayName .. " recruited " .. rarity.name:upper() .. " " .. def.name .. "!",
				"announce"
			)
		end
		model:Destroy()
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

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #walkers, 1, -1 do
			local walker = walkers[i]
			if walker.bought or not walker.model.Parent then
				table.remove(walkers, i)
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
				walker.model:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 2.6, 0), endPos + Vector3.new(0, 2.6, 0)))
			end
		end
	end)
end

return ConveyorService
