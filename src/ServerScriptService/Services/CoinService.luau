--!strict
-- Loose lunch money around campus: spinning coins that pay a little cash on
-- touch and respawn later. Makes running around the school inherently rewarding.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Palette = require(ReplicatedStorage.Shared.Palette)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EffectsService = require(script.Parent.EffectsService)

local CoinService = {}

local SPOTS = {
	Vector3.new(-140, 0, 8), Vector3.new(-95, 0, -9), Vector3.new(-45, 0, 10),
	Vector3.new(10, 0, -9), Vector3.new(70, 0, 9), Vector3.new(125, 0, -8),
	Vector3.new(0, 0, 35), Vector3.new(-30, 0, 100), Vector3.new(35, 0, 105),
	Vector3.new(0, 0, 168), Vector3.new(-55, 0, 145), Vector3.new(58, 0, 160),
	Vector3.new(-190, 0, 40), Vector3.new(-195, 0, 85), Vector3.new(190, 0, 40),
	Vector3.new(195, 0, 82), Vector3.new(-190, 0, -55), Vector3.new(192, 0, -62),
	Vector3.new(0, 0, -120), Vector3.new(-130, 0, 118),
	Vector3.new(-120, 0, 178), Vector3.new(120, 0, 178),
}

local rng = Random.new()

local function makeCoin(spot: Vector3)
	local coin = Instance.new("Part")
	coin.Name = "LunchCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.5, 3, 3)
	coin.Color = Palette.BusYellow
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CFrame = CFrame.new(spot + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	coin.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Palette.BusYellow
	light.Brightness = 0.6
	light.Range = 10
	light.Parent = coin

	-- lazy spin + bob
	local spin = TweenService:Create(
		coin,
		TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ CFrame = coin.CFrame * CFrame.Angles(math.rad(180), 0, 0) * CFrame.Angles(0, 0, 0) }
	)
	spin:Play()

	local active = true
	coin.Touched:Connect(function(hit)
		if not active then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character :: any)
		if not player or not DataService.IsLoaded(player) then
			return
		end
		active = false
		local amount = math.floor(rng:NextInteger(GameConfig.CoinValueMin, GameConfig.CoinValueMax) * EconomyService.Multiplier(player))
		EconomyService.AddCash(player, amount, true)
		EffectsService.CashPopup(coin.Position, amount)
		EffectsService.PlaySound(coin, "Collect")
		coin.Transparency = 1
		light.Enabled = false
		task.delay(rng:NextNumber(GameConfig.CoinRespawnMin, GameConfig.CoinRespawnMax), function()
			coin.Transparency = 0
			light.Enabled = true
			active = true
		end)
	end)
end

-- One-shot event coin: bigger, brighter, fixed value, despawns after lifetime.
-- onPickup lets the caller award event/reputation credit.
function CoinService.SpawnBonus(position: Vector3, value: number, lifetime: number, onPickup: ((Player) -> ())?)
	local coin = Instance.new("Part")
	coin.Name = "BonusCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.7, 4.2, 4.2)
	coin.Color = Color3.fromRGB(255, 196, 70)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CFrame = CFrame.new(position + Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	coin.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = coin.Color
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = coin

	local spin = TweenService:Create(
		coin,
		TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ CFrame = coin.CFrame * CFrame.Angles(math.rad(180), 0, 0) }
	)
	spin:Play()

	local taken = false
	coin.Touched:Connect(function(hit)
		if taken then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character :: any)
		if not player or not DataService.IsLoaded(player) then
			return
		end
		taken = true
		local amount = math.floor(value * EconomyService.Multiplier(player))
		EconomyService.AddCash(player, amount, true)
		EffectsService.CashPopup(coin.Position, amount)
		EffectsService.PlaySound(coin, "Collect")
		if onPickup then
			onPickup(player)
		end
		coin:Destroy()
	end)
	task.delay(lifetime, function()
		if coin.Parent then
			coin:Destroy()
		end
	end)
end

function CoinService.Init()
	for _, spot in SPOTS do
		makeCoin(spot)
	end
end

return CoinService
