--!strict
-- Curfew: SchoolClock calls StartNight() on the Lights Out period. While it's
-- dark, every tick spent OUTDOORS farms aura (ramping the longer you stay out),
-- but the prefects roll to catch you — busted means detention and an aura fine.
-- Indoors (main building, dorms) is always safe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local AuraService = require(script.Parent.AuraService)
local StealService = require(script.Parent.StealService)

local CurfewService = {}

local detentionSpot = Vector3.new(-100, 0, -210)
local night = false
local streaks: { [Player]: number } = {}
local rng = Random.new()

-- Safe = inside the main school shell or either dorm footprint.
local function isIndoors(pos: Vector3): boolean
	if math.abs(pos.X) < 168 and math.abs(pos.Z) < 84 then
		return true
	end
	for _, dormX in { -195, 195 } do
		if math.abs(pos.X - dormX) < 35 and math.abs(pos.Z - 200) < 30 then
			return true
		end
	end
	return false
end

local function sendToDetention(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	root.CFrame = CFrame.new(detentionSpot + Vector3.new(rng:NextNumber(-6, 6), 4, rng:NextNumber(-4, 4)))
	player:SetAttribute("DetentionUntil", os.clock() + GameConfig.DetentionSeconds)
	humanoid.WalkSpeed = 0
	AuraService.Add(player, -GameConfig.DetentionAuraPenalty)
	Remotes.Get("Notify"):FireClient(
		player,
		("BUSTED! A prefect caught you after dark. Detention %ds, -%d aura."):format(
			GameConfig.DetentionSeconds,
			GameConfig.DetentionAuraPenalty
		),
		"bad"
	)
	Remotes.Get("Notify"):FireAllClients(player.DisplayName .. " got dragged to DETENTION for breaking curfew!", "info")
	task.delay(GameConfig.DetentionSeconds, function()
		if player.Parent then
			player:SetAttribute("DetentionUntil", nil)
			StealService.RefreshWalkSpeed(player)
			Remotes.Get("Notify"):FireClient(player, "Detention's over. Walk it off.", "info")
		end
	end)
end

local function tickNight()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local detention = player:GetAttribute("DetentionUntil")
		if typeof(detention) == "number" and detention > now then
			continue
		end
		if isIndoors(root.Position) then
			streaks[player] = 0
			continue
		end
		local streak = (streaks[player] or 0) + 1
		streaks[player] = streak
		local gain = math.min(streak, GameConfig.CurfewAuraCap)
		AuraService.Add(player, gain)
		if streak % 4 == 1 then
			Remotes.Get("Notify"):FireClient(
				player,
				("Out after dark... +%d aura a tick and climbing. Don't get caught."):format(gain),
				"aura"
			)
		end
		local chance = math.min(
			GameConfig.CurfewCatchBase + streak * GameConfig.CurfewCatchRamp,
			GameConfig.CurfewCatchMax
		)
		if rng:NextNumber() < chance then
			streaks[player] = 0
			sendToDetention(player)
		end
	end
end

local function tweenClock(target: number, ambient: Color3)
	TweenService:Create(Lighting, TweenInfo.new(4, Enum.EasingStyle.Sine), {
		ClockTime = target,
		OutdoorAmbient = ambient,
	}):Play()
end

function CurfewService.StartNight()
	if night then
		return
	end
	night = true
	streaks = {}
	tweenClock(0.6, Color3.fromRGB(40, 48, 78))
	Remotes.Get("Notify"):FireAllClients(
		"LIGHTS OUT! Get inside — prefects patrol after dark. Or stay out and farm that aura... 😈",
		"announce"
	)
	task.spawn(function()
		while night do
			task.wait(GameConfig.CurfewTickSeconds)
			if night then
				tickNight()
			end
		end
	end)
	task.delay(GameConfig.CurfewNightSeconds, function()
		night = false
		streaks = {}
		tweenClock(12.8, Color3.fromRGB(130, 135, 125))
		Remotes.Get("Notify"):FireAllClients("Morning bell! Curfew's over — back to business.", "info")
	end)
end

function CurfewService.Init(map: { detentionSpot: Vector3 })
	detentionSpot = map.detentionSpot
	Players.PlayerRemoving:Connect(function(player)
		streaks[player] = nil
	end)
end

return CurfewService
