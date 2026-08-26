--!strict
-- DETENTION — server bootstrap.
-- Order matters: remotes + data first, then the map, then every gameplay system.
-- Each Init is isolated: one failing service logs loudly instead of killing boot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
Remotes.Init()

local Services = script.Parent.Services

local DataService = require(Services.DataService)
local MapService = require(Services.MapService)
local PlotService = require(Services.PlotService)
local EconomyService = require(Services.EconomyService)

DataService.Init()

local map = MapService.Build()

PlotService.Init(map)
EconomyService.Init()
for _, plot in map.plots do
	EconomyService.WireCollectPad(plot)
end

-- everything else boots isolated, in order
local BOOT: { { name: string, init: (typeof(map)) -> () } } = {
	{ name = "ConveyorService", init = function(m) (require(Services.ConveyorService) :: any).Init(m) end },
	{ name = "LockService", init = function(m) (require(Services.LockService) :: any).Init(m) end },
	{ name = "StealService", init = function() (require(Services.StealService) :: any).Init() end },
	{ name = "FightService", init = function() (require(Services.FightService) :: any).Init() end },
	{ name = "AuraService", init = function() (require(Services.AuraService) :: any).Init() end },
	{ name = "RebirthService", init = function() (require(Services.RebirthService) :: any).Init() end },
	{ name = "CliqueService", init = function(m) (require(Services.CliqueService) :: any).Init(m) end },
	{ name = "ClassService", init = function() (require(Services.ClassService) :: any).Init() end },
	{ name = "MonetizationService", init = function() (require(Services.MonetizationService) :: any).Init() end },
	{ name = "RewardService", init = function() (require(Services.RewardService) :: any).Init() end },
	{ name = "QuestService", init = function() (require(Services.QuestService) :: any).Init() end },
	{ name = "LeaderboardService", init = function(m) (require(Services.LeaderboardService) :: any).Init(m) end },
	{ name = "EffectsService", init = function() (require(Services.EffectsService) :: any).Init() end },
	{ name = "NPCDirector", init = function() (require(Services.NPCDirector) :: any).Init() end },
	{ name = "SchoolClock", init = function() (require(Services.SchoolClock) :: any).Init() end },
	{ name = "MissionService", init = function() (require(Services.MissionService) :: any).Init() end },
	{ name = "RivalService", init = function() (require(Services.RivalService) :: any).Init() end },
	{ name = "CoinService", init = function() (require(Services.CoinService) :: any).Init() end },
	{ name = "DormService", init = function(m) (require(Services.DormService) :: any).Init(m) end },
	{ name = "CurfewService", init = function(m) (require(Services.CurfewService) :: any).Init(m) end },
	{ name = "CosmeticsService", init = function() (require(Services.CosmeticsService) :: any).Init() end },
	{ name = "ReputationService", init = function() (require(Services.ReputationService) :: any).Init() end },
	{ name = "EventDirector", init = function() (require(Services.EventDirector) :: any).Init() end },
	{ name = "DiagnosticsService", init = function() (require(Services.DiagnosticsService) :: any).Init() end },
}
for _, entry in BOOT do
	local ok, err = pcall(entry.init :: any, map)
	if not ok then
		warn(("[DETENTION] %s.Init FAILED: %s"):format(entry.name, tostring(err)))
	end
end

print("[DETENTION] server ready — one school, endless stories")
