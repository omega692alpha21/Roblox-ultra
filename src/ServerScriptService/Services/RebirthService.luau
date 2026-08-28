--!strict
-- Grades (rebirth): pay the cost, lose cash + crew, gain a permanent multiplier,
-- an extra desk, and longer locks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local AuraService = require(script.Parent.AuraService)

local RebirthService = {}

local debounce: { [Player]: boolean } = {}

function RebirthService.Init()
	Remotes.Get("DoRebirth").OnServerEvent:Connect(function(player)
		if debounce[player] then
			return
		end
		-- released on a timer rather than after the work: an error anywhere
		-- below used to leave the flag set forever, which locked that player
		-- out of graduating for the rest of the session and held a reference
		-- to them after they left
		debounce[player] = true
		task.delay(0.5, function()
			debounce[player] = nil
		end)
		local profile = DataService.Get(player)
		if profile then
			local cost = Rebirths.CostFor(profile.grade + 1)
			if profile.cash >= cost then
				profile.cash = GameConfig.StarterCash
				profile.crew = {}
				profile.grade += 1
				PlotService.RebuildCrew(player)
				EconomyService.RefreshStats(player)
				AuraService.UpdateOverhead(player)
				Remotes.Get("Notify"):FireClient(
					player,
					("GRADUATED to %s! Income x%.1f, +1 desk, longer locks."):format(
						Rebirths.GradeName(profile.grade),
						Rebirths.Multiplier(profile.grade)
					),
					"good"
				)
			else
				Remotes.Get("Notify"):FireClient(
					player,
					"Graduating costs $" .. NumberFormat.Abbreviate(cost) .. " — keep grinding!",
					"bad"
				)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		debounce[player] = nil
	end)
end

return RebirthService
