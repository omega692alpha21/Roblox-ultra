--!strict
-- CULT — server bootstrap. Every system boots isolated: one failure warns
-- loudly and leaves the rest of the world standing.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
Remotes.Init()

-- deep-night ritual lighting under a painted star sky
Lighting.ClockTime = 0.15
Lighting.Brightness = 1.7
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.08
Lighting.EnvironmentDiffuseScale = 0.35
Lighting.EnvironmentSpecularScale = 0.6
Lighting.Ambient = Color3.fromRGB(20, 20, 27)
Lighting.OutdoorAmbient = Color3.fromRGB(26, 30, 46)
Lighting.ExposureCompensation = 0.35

local sky = Instance.new("Sky")
sky.SkyboxFt = "rbxassetid://118975540614116" -- the moon face
sky.SkyboxBk = "rbxassetid://83074969930157"
sky.SkyboxLf = "rbxassetid://79429743980832"
sky.SkyboxRt = "rbxassetid://82929303517531"
sky.SkyboxUp = "rbxassetid://138826407413576"
sky.SkyboxDn = "rbxassetid://137321645510315"
sky.CelestialBodiesShown = false
sky.StarCount = 0
sky.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.42
atmosphere.Color = Color3.fromRGB(58, 64, 94)
atmosphere.Decay = Color3.fromRGB(14, 18, 38)
atmosphere.Glare = 0.2
atmosphere.Haze = 2.4
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 1.2
bloom.Size = 44
bloom.Threshold = 1.35
bloom.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Contrast = 0.12
grade.Saturation = 0.1
grade.TintColor = Color3.fromRGB(236, 232, 246)
grade.Parent = Lighting

local ClubMap = require(script.Parent.ClubMap)
local Rep = require(script.Parent.Rep)
local Initiation = require(script.Parent.Initiation)
local Convocation = require(script.Parent.Convocation)
local Missions = require(script.Parent.Missions)
local Gates = require(script.Parent.Gates)
local Cults = require(script.Parent.Cults)
local Membership = require(script.Parent.Membership)
local Profiles = require(script.Parent.Profiles)
local Robes = require(script.Parent.Robes)

local okBuild, mapOrErr = xpcall(ClubMap.Build, debug.traceback)
if not okBuild then
	warn("[CULT] MAP BUILD FAILED:\n" .. tostring(mapOrErr))
	local sign = Instance.new("Part")
	sign.Anchored = true
	sign.Size = Vector3.new(40, 12, 1)
	sign.Position = Vector3.new(0, 8, 100)
	sign.Color = Color3.fromRGB(120, 20, 20)
	sign.Parent = workspace
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextWrapped = true
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ("BUILD %d FAILED\n%s"):format(game.PlaceVersion, tostring(mapOrErr):sub(1, 400))
	label.Parent = gui
	return
end
local map = mapOrErr :: any

local BOOT: { { name: string, init: () -> () } } = {
	{ name = "Rep", init = function() Rep.Init() end },
	{ name = "Initiation", init = function() Initiation.Init(map) end },
	{ name = "Membership", init = function() Membership.Init(map) end },
	{ name = "Gates", init = function() Gates.Init(map) end },
	{ name = "Cults", init = function() Cults.Init(map) end },
	{ name = "Convocation", init = function() Convocation.Init(map) end },
	{ name = "Missions", init = function() Missions.Init(map) end },
	{ name = "Profiles", init = function() (Profiles :: any).Init() end },
	{ name = "Robes", init = function() Robes.Init() end },
}
for _, entry in BOOT do
	local ok, err = pcall(entry.init :: any)
	if not ok then
		warn(("[CULT] %s.Init failed: %s"):format(entry.name, tostring(err)))
	end
end

-- the seat claim and the altar's answers cross module boundaries
Initiation.OnInitiated(function(player)
	Membership.OnInitiated(player)
end)
Initiation.SetAltarHandler(function(player, answer): (boolean, string)
	return Missions.AnswerAltar(player, answer)
end)

print(("[CULT] build %d ready"):format(game.PlaceVersion))
