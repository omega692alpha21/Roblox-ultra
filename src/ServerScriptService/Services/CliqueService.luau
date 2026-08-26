--!strict
-- Cliques: join at the courtyard boards or from the Cliques panel. Switching costs
-- a slice of your cash. Perk values live in Config/Cliques and are read by the
-- services that apply them (walkspeed, quiz rewards, offline cap, carry penalty).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cliques = require(ReplicatedStorage.Config.Cliques)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StealService = require(script.Parent.StealService)
local Signals = require(script.Parent.Parent.Signals)

local CliqueService = {}

local function join(player: Player, cliqueId: string)
	local profile = DataService.Get(player)
	local clique = Cliques.Get(cliqueId)
	if not profile or not clique then
		return
	end
	if profile.clique == cliqueId then
		Remotes.Get("Notify"):FireClient(player, "You're already a " .. clique.name .. "!", "info")
		return
	end
	if profile.clique ~= nil then
		local cost = math.floor(profile.cash * Cliques.SwitchCostFraction)
		if cost > 0 and not EconomyService.TrySpend(player, cost) then
			return
		end
		Remotes.Get("Notify"):FireClient(player, "Switched cliques (the old one took a cut).", "info")
	end
	profile.clique = cliqueId
	player:SetAttribute("Clique", cliqueId)
	StealService.RefreshWalkSpeed(player)
	Remotes.Get("Notify"):FireClient(player, "Welcome to the " .. clique.name .. "! " .. clique.motto, "aura")
end

function CliqueService.Init(map: { cliqueBoards: { [string]: BasePart } })
	Remotes.Get("JoinClique").OnServerEvent:Connect(function(player, cliqueId)
		if typeof(cliqueId) == "string" then
			join(player, cliqueId)
		end
	end)

	for cliqueId, board in map.cliqueBoards do
		local prompt = Instance.new("ProximityPrompt")
		local clique = Cliques.Get(cliqueId)
		prompt.ActionText = "Join " .. (clique and clique.name or cliqueId)
		prompt.ObjectText = "Clique Board"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = board
		prompt.Triggered:Connect(function(player)
			join(player, cliqueId)
		end)
	end

	Signals.ProfileLoaded:Connect(function(player, profile)
		if profile.clique then
			player:SetAttribute("Clique", profile.clique)
			StealService.RefreshWalkSpeed(player)
		end
	end)
end

return CliqueService
