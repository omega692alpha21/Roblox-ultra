--!strict
-- Roles. You pick one on your first join, in the character screen; the
-- courtyard boards and the Roles panel let you re-sort later for a slice of
-- your cash. The numbers live in Config/Cliques and are read by the services
-- that apply them -- walkspeed here, health and energy in VitalsService,
-- damage in the fight and toy services, rewards in the classroom.
--
-- Everything a role changes is re-applied the moment it changes, so switching
-- does not need a respawn to take effect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cliques = require(ReplicatedStorage.Config.Cliques)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StealService = require(script.Parent.StealService)
local VitalsService = require(script.Parent.VitalsService)
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
	CliqueService.Apply(player)
	Remotes.Get("Notify"):FireClient(player, "You're a " .. clique.name .. " now. " .. clique.motto, "aura")
end

-- Push the role onto the body and onto the attributes the client reads. The
-- aim assist is one of those: the reticle's forgiveness is decided on the
-- client, so the number has to be somewhere the client can see it.
function CliqueService.Apply(player: Player)
	local role = Cliques.For(player)
	player:SetAttribute("RoleName", role.name)
	player:SetAttribute("AimAssist", role.aimAssistMult)
	player:SetAttribute("ClassTimeBonus", role.classTimeBonus)
	StealService.RefreshWalkSpeed(player)
	VitalsService.ApplyRole(player)
end

function CliqueService.Init(map: { cliqueBoards: { [string]: BasePart } })
	local Players = game:GetService("Players")
	for _, player in Players:GetPlayers() do
		CliqueService.Apply(player)
	end
	Players.PlayerAdded:Connect(function(player)
		CliqueService.Apply(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			CliqueService.Apply(player)
		end)
	end)
	Signals.ProfileLoaded:Connect(CliqueService.Apply)

	Remotes.Get("JoinClique").OnServerEvent:Connect(function(player, cliqueId)
		if typeof(cliqueId) == "string" then
			join(player, cliqueId)
		end
	end)

	for cliqueId, board in map.cliqueBoards do
		local prompt = Instance.new("ProximityPrompt")
		local clique = Cliques.Get(cliqueId)
		prompt.ActionText = "Become a " .. (clique and clique.name or cliqueId)
		prompt.ObjectText = "Re-sorting Board"
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
