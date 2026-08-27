--!strict
-- MILLIONS CLUB — server bootstrap.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
Remotes.Init()

-- night-luxury lighting
Lighting.ClockTime = 20.5
Lighting.Brightness = 2.2
Lighting.GlobalShadows = true
Lighting.Ambient = Color3.fromRGB(40, 38, 48)
Lighting.OutdoorAmbient = Color3.fromRGB(34, 36, 52)
Lighting.ExposureCompensation = 0.15
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.35
atmosphere.Color = Color3.fromRGB(90, 96, 128)
atmosphere.Decay = Color3.fromRGB(30, 34, 60)
atmosphere.Glare = 0.4
atmosphere.Haze = 1.6
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.9
bloom.Size = 32
bloom.Threshold = 1.6
bloom.Parent = Lighting

local ClubMap = require(script.Parent.ClubMap)
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

print("[MillionsClub] ready — 100 seats, ever")
