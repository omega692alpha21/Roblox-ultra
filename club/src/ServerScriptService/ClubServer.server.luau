--!strict
-- MILLIONS CLUB — server bootstrap. Every system boots isolated: one failure
-- warns loudly and leaves the rest of the world standing.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
Remotes.Init()

-- gilded night: the estate glows warm against a deep star sky
Lighting.ClockTime = 0.15
Lighting.Brightness = 1.6
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.12
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.7
-- rich night: readable everywhere, but the marble and gold stay moody
Lighting.Ambient = Color3.fromRGB(36, 35, 42)
Lighting.OutdoorAmbient = Color3.fromRGB(54, 58, 76)
Lighting.ExposureCompensation = 0.15

local sky = Instance.new("Sky")
sky.SkyboxFt = "rbxassetid://118975540614116"
sky.SkyboxBk = "rbxassetid://83074969930157"
sky.SkyboxLf = "rbxassetid://79429743980832"
sky.SkyboxRt = "rbxassetid://82929303517531"
sky.SkyboxUp = "rbxassetid://138826407413576"
sky.SkyboxDn = "rbxassetid://137321645510315"
sky.CelestialBodiesShown = false
sky.StarCount = 0
sky.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.24
atmosphere.Color = Color3.fromRGB(84, 88, 116)
atmosphere.Decay = Color3.fromRGB(40, 44, 68)
atmosphere.Glare = 0.25
atmosphere.Haze = 1.4
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.55
bloom.Size = 40
bloom.Threshold = 1.6
bloom.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Brightness = 0
grade.Contrast = 0.05
grade.Saturation = 0.12
grade.TintColor = Color3.fromRGB(244, 240, 246)
grade.Parent = Lighting

local ClubMap = require(script.Parent.ClubMap)
local Membership = require(script.Parent.Membership)
local Gates = require(script.Parent.Gates)
local Profiles = require(script.Parent.Profiles)
local Robes = require(script.Parent.Robes)

local okBuild, mapOrErr = xpcall(ClubMap.Build, debug.traceback)
if not okBuild then
	warn("[MC] MAP BUILD FAILED:\n" .. tostring(mapOrErr))
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
	{ name = "Membership", init = function() Membership.Init(map) end },
	{ name = "Gates", init = function() Gates.Init(map) end },
	{ name = "Profiles", init = function() (Profiles :: any).Init() end },
	{ name = "Robes", init = function() Robes.Init() end },
}
for _, entry in BOOT do
	local ok, err = pcall(entry.init :: any)
	if not ok then
		warn(("[MC] %s.Init failed: %s"):format(entry.name, tostring(err)))
	end
end

print(("[MC] build %d ready"):format(game.PlaceVersion))
