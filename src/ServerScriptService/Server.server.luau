--!strict
-- Lunch Money Legends — server bootstrap.
-- Order matters: remotes + data first, then the map, then every gameplay system.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
Remotes.Init()

local Services = script.Parent.Services

local DataService = require(Services.DataService)
local MapService = require(Services.MapService)
local PlotService = require(Services.PlotService)
local EconomyService = require(Services.EconomyService)
local ConveyorService = require(Services.ConveyorService)
local LockService = require(Services.LockService)
local StealService = require(Services.StealService)
local FightService = require(Services.FightService)
local AuraService = require(Services.AuraService)
local RebirthService = require(Services.RebirthService)
local CliqueService = require(Services.CliqueService)
local ClassService = require(Services.ClassService)
local MonetizationService = require(Services.MonetizationService)
local RewardService = require(Services.RewardService)
local QuestService = require(Services.QuestService)
local LeaderboardService = require(Services.LeaderboardService)

DataService.Init()

local map = MapService.Build()

PlotService.Init(map)
EconomyService.Init()
for _, plot in map.plots do
	EconomyService.WireCollectPad(plot)
end
ConveyorService.Init(map)
LockService.Init(map)
StealService.Init()
FightService.Init()
AuraService.Init()
RebirthService.Init()
CliqueService.Init(map)
ClassService.Init()
MonetizationService.Init()
RewardService.Init()
QuestService.Init()
LeaderboardService.Init(map)

print("[LunchMoneyLegends] server ready — welcome to Crumbworth High")
