--!strict
-- Assigns homeroom plots, keeps the physical crew models in sync with profile data,
-- and owns the slot math. Other services register callbacks for model lifecycle.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Students = require(ReplicatedStorage.Config.Students)
local Remotes = require(ReplicatedStorage.Remotes)
local MapService = require(script.Parent.MapService)
local StudentGen = require(script.Parent.StudentGen)
local DataService = require(script.Parent.DataService)
local Signals = require(script.Parent.Parent.Signals)

local PlotService = {}

local map: MapService.Map? = nil
local plotOwner: { [number]: Player } = {} -- plot index -> player
local playerPlot: { [Player]: MapService.Plot } = {}
local crewModels: { [Player]: { [string]: Model } } = {} -- uid -> model
local modelAddedCallbacks: { (player: Player, plot: MapService.Plot, model: Model, uid: string, defId: string) -> () } = {}
local carriedPredicate: ((uid: string) -> boolean)? = nil

function PlotService.OnStudentModelAdded(fn: (player: Player, plot: MapService.Plot, model: Model, uid: string, defId: string) -> ())
	table.insert(modelAddedCallbacks, fn)
end

-- StealService registers this so rebuilds never respawn a student that is
-- currently being carried by a thief (avoids duplicate grab targets).
function PlotService.SetCarriedPredicate(fn: (uid: string) -> boolean)
	carriedPredicate = fn
end

function PlotService.GetPlot(player: Player): MapService.Plot?
	return playerPlot[player]
end

function PlotService.GetOwnerOfPlot(plot: MapService.Plot): Player?
	return plotOwner[plot.index]
end

function PlotService.MaxSlots(player: Player): number
	local profile = DataService.Get(player)
	local grade = profile and profile.grade or 0
	local slots = GameConfig.BaseSlots + math.min(grade * GameConfig.SlotsPerRebirth, GameConfig.MaxRebirthSlots)
	if player:GetAttribute("PassSlots") then
		slots += GameConfig.ExtraSlotsPass
	end
	return math.min(slots, 12) -- 12 physical desks per plot
end

function PlotService.CrewCount(player: Player): number
	local profile = DataService.Get(player)
	return profile and #profile.crew or 0
end

type CrewMember = { uid: string, id: string, mut: string?, star: boolean? }

local function pushCrew(player: Player)
	local profile = DataService.Get(player)
	if profile then
		Remotes.Get("CrewState"):FireClient(player, profile.crew)
	end
end

local function spawnStudentModel(player: Player, member: CrewMember, slotIndex: number)
	local plot = playerPlot[player]
	if not plot then
		return
	end
	local model = StudentGen.Create(member.id)
	if not model then
		return
	end
	model.Name = "Crew_" .. member.uid
	model:SetAttribute("Uid", member.uid)
	model:SetAttribute("OwnerUserId", player.UserId)
	StudentGen.Decorate(model, member.id, member.mut, member.star)
	local slotCf = plot.deskSlots[slotIndex] or plot.deskSlots[#plot.deskSlots]
	model.Parent = plot.model
	StudentGen.Stand(model, slotCf)
	StudentGen.PlayAnim(model, "idle")
	-- glowing floor ring under Epic and better
	local entry = Students.Get(member.id)
	if entry then
		local rarityIndex = table.find({ "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }, entry.rarity.name) or 1
		if rarityIndex >= 3 then
			local ring = Instance.new("Part")
			ring.Name = "RarityRing"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.15, 5.4, 5.4)
			ring.CFrame = slotCf * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90))
			ring.Color = entry.rarity.color
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.35
			ring.Anchored = true
			ring.CanCollide = false
			ring.Parent = model
		end
	end
	crewModels[player] = crewModels[player] or {}
	crewModels[player][member.uid] = model
	for _, fn in modelAddedCallbacks do
		task.spawn(fn, player, plot, model, member.uid, member.id)
	end
end

-- Rebuild every crew model from profile data (used on load, rebirth, steal).
function PlotService.RebuildCrew(player: Player)
	local plot = playerPlot[player]
	local profile = DataService.Get(player)
	if not plot or not profile then
		return
	end
	local models = crewModels[player]
	if models then
		for _, model in models do
			model:Destroy()
		end
	end
	crewModels[player] = {}
	for i, member in profile.crew do
		if not (carriedPredicate and carriedPredicate(member.uid)) then
			spawnStudentModel(player, member, i)
		end
	end
	pushCrew(player)
	Signals.CrewChanged:Fire(player)
end

-- Add a student to the player's crew (validates a free slot). Returns the uid.
-- skipModel defers the desk model (the recruit is walking over from the hallway).
function PlotService.AddStudent(player: Player, defId: string, mut: string?, star: boolean?, skipModel: boolean?): string?
	local profile = DataService.Get(player)
	if not profile or not playerPlot[player] then
		return nil
	end
	if #profile.crew >= PlotService.MaxSlots(player) then
		return nil
	end
	if not Students.Get(defId) then
		return nil
	end
	local member: CrewMember = { uid = HttpService:GenerateGUID(false), id = defId, mut = mut, star = star }
	table.insert(profile.crew, member)
	if not skipModel then
		spawnStudentModel(player, member, #profile.crew)
	end
	pushCrew(player)
	Signals.CrewChanged:Fire(player)
	return member.uid
end

-- Spawn the desk model for a member added with skipModel (recruit arrived).
function PlotService.SpawnPendingModel(player: Player, uid: string)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local models = crewModels[player]
	if models and models[uid] then
		return
	end
	for i, member in profile.crew do
		if member.uid == uid then
			spawnStudentModel(player, member, i)
			return
		end
	end
end

-- World CFrame of the desk slot a member stands at (nil if gone).
function PlotService.GetSlotWorldCFrame(player: Player, uid: string): CFrame?
	local profile = DataService.Get(player)
	local plot = playerPlot[player]
	if not profile or not plot then
		return nil
	end
	for i, member in profile.crew do
		if member.uid == uid then
			return plot.deskSlots[i] or plot.deskSlots[#plot.deskSlots]
		end
	end
	return nil
end

-- Remove by uid (steal transfer / rebirth). Returns a copy of the removed member.
function PlotService.RemoveStudent(player: Player, uid: string): CrewMember?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	for i, member in profile.crew do
		if member.uid == uid then
			table.remove(profile.crew, i)
			local models = crewModels[player]
			if models and models[uid] then
				models[uid]:Destroy()
				models[uid] = nil
			end
			-- re-seat remaining students so desks fill front-first
			PlotService.RebuildCrew(player)
			return table.clone(member)
		end
	end
	return nil
end

-- Fuse N duplicates of one student into a Star version (keeps the best mutation).
function PlotService.FuseStudent(player: Player, defId: string): boolean
	local profile = DataService.Get(player)
	if not profile or not Students.Get(defId) then
		return false
	end
	local candidates: { number } = {}
	for i, member in profile.crew do
		if member.id == defId and not member.star then
			table.insert(candidates, i)
		end
	end
	if #candidates < Students.FuseCount then
		return false
	end
	-- keep the most valuable mutation among the consumed copies
	local bestMut: string? = nil
	local bestMult = 1
	for i = 1, Students.FuseCount do
		local member = profile.crew[candidates[i]]
		local mutation = Students.GetMutation(member.mut)
		if mutation and mutation.mult > bestMult then
			bestMult = mutation.mult
			bestMut = mutation.id
		end
	end
	-- remove back-to-front so indexes stay valid
	for i = Students.FuseCount, 1, -1 do
		table.remove(profile.crew, candidates[i])
	end
	table.insert(profile.crew, { uid = HttpService:GenerateGUID(false), id = defId, mut = bestMut, star = true })
	PlotService.RebuildCrew(player)
	return true
end

function PlotService.GetStudentModel(player: Player, uid: string): Model?
	local models = crewModels[player]
	return models and models[uid] or nil
end

local function assignPlot(player: Player)
	local m = map
	if not m then
		return
	end
	for _, plot in m.plots do
		if not plotOwner[plot.index] then
			plotOwner[plot.index] = player
			playerPlot[player] = plot
			local label = plot.signGui:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = player.DisplayName .. "'s\nHOMEROOM"
			end
			return
		end
	end
	warn("[PlotService] no free plot for " .. player.Name)
end

local function releasePlot(player: Player)
	local plot = playerPlot[player]
	if plot then
		plotOwner[plot.index] = nil
		playerPlot[player] = nil
		local models = crewModels[player]
		if models then
			for _, model in models do
				model:Destroy()
			end
		end
		crewModels[player] = nil
		local label = plot.signGui:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = "HOMEROOM " .. plot.index
		end
		plot.pileLabel.Text = "$0"
	end
end

function PlotService.Init(builtMap: MapService.Map)
	map = builtMap

	Remotes.GetFunction("GetCrew").OnServerInvoke = function(player)
		local profile = DataService.Get(player)
		return profile and profile.crew or {}
	end
	local fuseDebounce: { [Player]: number } = {}
	Remotes.Get("FuseStudent").OnServerEvent:Connect(function(player, defId)
		if typeof(defId) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (fuseDebounce[player] or 0) < 0.5 then
			return
		end
		fuseDebounce[player] = now
		if PlotService.FuseStudent(player, defId) then
			local entry = Students.Get(defId)
			Remotes.Get("Notify"):FireClient(
				player,
				("FUSED! ★ %s joined your crew (x%d income)."):format(entry and entry.def.name or defId, Students.StarIncomeMult),
				"aura"
			)
		else
			Remotes.Get("Notify"):FireClient(player, "Fusing needs 3 un-starred copies of the same student.", "bad")
		end
	end)

	Players.PlayerAdded:Connect(assignPlot)
	for _, player in Players:GetPlayers() do
		if not playerPlot[player] then
			assignPlot(player)
		end
	end
	Players.PlayerRemoving:Connect(releasePlot)
	Signals.ProfileLoaded:Connect(function(player)
		PlotService.RebuildCrew(player)
	end)
end

return PlotService
