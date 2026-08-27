--!strict
-- MILLIONS CLUB — server bootstrap.

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
Lighting.Ambient = Color3.fromRGB(24, 24, 32)
Lighting.OutdoorAmbient = Color3.fromRGB(28, 32, 50)
Lighting.ExposureCompensation = 0.3

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
bloom.Intensity = 1.1
bloom.Size = 40
bloom.Threshold = 1.4
bloom.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Contrast = 0.1
grade.Saturation = 0.14
grade.TintColor = Color3.fromRGB(232, 238, 255)
grade.Parent = Lighting

local ClubMap = require(script.Parent.ClubMap)
local Robes = require(script.Parent.Robes)
local Membership = require(script.Parent.Membership)
local Profiles = require(script.Parent.Profiles)

local okBuild, mapOrErr = xpcall(ClubMap.Build, debug.traceback)
if not okBuild then
	warn("[MillionsClub] MAP BUILD FAILED:\n" .. tostring(mapOrErr))
	return
end
local map = mapOrErr :: any

local ok1, err1 = pcall(function()
	Membership.Init(map)
end)
if not ok1 then
	warn("[MillionsClub] Membership.Init failed: " .. tostring(err1))
end
local ok2, err2 = pcall(Profiles.Init :: any)
if not ok2 then
	warn("[MillionsClub] Profiles.Init failed: " .. tostring(err2))
end
local ok3, err3 = pcall(Robes.Init :: any)
if not ok3 then
	warn("[MillionsClub] Robes.Init failed: " .. tostring(err3))
end

print("[MillionsClub] ready — 100 seats, ever")
