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

-- unmistakable proof-of-life: shows game + build even if everything below dies
do
	local beacon = Instance.new("Part")
	beacon.Name = "BootBeacon"
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.Transparency = 1
	beacon.Size = Vector3.new(1, 1, 1)
	beacon.Position = Vector3.new(0, 40, 22)
	beacon.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(30, 8)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 500
	gui.Parent = beacon
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 196, 60)
	label.TextStrokeTransparency = 0.2
	label.Text = "DETENTION · build " .. tostring(game.PlaceVersion)
	label.Parent = gui
	task.delay(20, function()
		beacon:Destroy() -- proof shown; get out of the way
	end)
end

DataService.Init()

local okBuild, mapOrErr = xpcall(MapService.Build, debug.traceback)
if not okBuild then
	warn("[DETENTION] MAP BUILD FAILED:\n" .. tostring(mapOrErr))
	local sign = Instance.new("Part")
	sign.Anchored = true
	sign.Size = Vector3.new(40, 12, 1)
	sign.Position = Vector3.new(0, 8, 30)
	sign.Color = Color3.fromRGB(190, 46, 46)
	sign.Parent = workspace
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.35)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "MAP BUILD FAILED (build " .. tostring(game.PlaceVersion) .. ")"
	label.Parent = gui
	local errLabel = Instance.new("TextLabel")
	errLabel.Position = UDim2.fromScale(0, 0.35)
	errLabel.Size = UDim2.fromScale(1, 0.65)
	errLabel.BackgroundTransparency = 1
	errLabel.Font = Enum.Font.Code
	errLabel.TextWrapped = true
	errLabel.TextScaled = true
	errLabel.TextColor3 = Color3.fromRGB(255, 220, 220)
	errLabel.Text = tostring(mapOrErr):sub(1, 380)
	errLabel.Parent = gui
	-- persist the full traceback where the dev can read it via Open Cloud
	task.spawn(function()
		pcall(function()
			local DataStoreService = game:GetService("DataStoreService")
			DataStoreService:GetDataStore("ClientDiagnostics"):SetAsync(
				("map_fail_b%d_t%d"):format(game.PlaceVersion, os.time()),
				{ err = tostring(mapOrErr):sub(1, 3500), build = game.PlaceVersion, time = os.time() }
			)
		end)
	end)
	return
end
local map = mapOrErr :: any

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
	{ name = "DodgeballService", init = function() (require(Services.DodgeballService) :: any).Init() end },
	{ name = "EventDirector", init = function() (require(Services.EventDirector) :: any).Init() end },
	{ name = "TextureService", init = function() (require(Services.TextureService) :: any).Init() end },
	{ name = "CharacterService", init = function() (require(Services.CharacterService) :: any).Init() end },
	{ name = "DiagnosticsService", init = function() (require(Services.DiagnosticsService) :: any).Init() end },
}
for _, entry in BOOT do
	local ok, err = pcall(entry.init :: any, map)
	if not ok then
		warn(("[DETENTION] %s.Init FAILED: %s"):format(entry.name, tostring(err)))
	end
end

print("[DETENTION] server ready — one school, endless stories")
