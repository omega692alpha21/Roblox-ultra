--!strict
-- Assigns homeroom plots, keeps the physical crew models in sync with profile data,
-- and owns the slot math. Other services register callbacks for model lifecycle.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Students = require(ReplicatedStorage.Config.Students)
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

local function spawnStudentModel(player: Player, uid: string, defId: string, slotIndex: number)
	local plot = playerPlot[player]
	if not plot then
		return
	end
	local model = StudentGen.Create(defId)
	if not model then
		return
	end
	model.Name = "Crew_" .. uid
	model:SetAttribute("Uid", uid)
	model:SetAttribute("OwnerUserId", player.UserId)
	local slotCf = plot.deskSlots[slotIndex] or plot.deskSlots[#plot.deskSlots]
	model.Parent = plot.model
	StudentGen.Stand(model, slotCf)
	crewModels[player] = crewModels[player] or {}
	crewModels[player][uid] = model
	for _, fn in modelAddedCallbacks do
		task.spawn(fn, player, plot, model, uid, defId)
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
			spawnStudentModel(player, member.uid, member.id, i)
		end
	end
	Signals.CrewChanged:Fire(player)
end

-- Add a student to the player's crew (validates a free slot). Returns the uid.
function PlotService.AddStudent(player: Player, defId: string): string?
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
	local uid = HttpService:GenerateGUID(false)
	table.insert(profile.crew, { uid = uid, id = defId })
	spawnStudentModel(player, uid, defId, #profile.crew)
	Signals.CrewChanged:Fire(player)
	return uid
end

-- Remove by uid (steal transfer / rebirth). Returns the defId that was removed.
function PlotService.RemoveStudent(player: Player, uid: string): string?
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
			return member.id
		end
	end
	return nil
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
