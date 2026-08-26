--!strict
-- Aura: the farmable status currency. Listens to game signals, updates the profile,
-- attributes, rank title over the head, and fires quest progress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Signals = require(script.Parent.Parent.Signals)

local AuraService = {}

local function updateOverhead(player: Player)
	local profile = DataService.Get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not profile or not head then
		return
	end
	local existing = head:FindFirstChild("AuraTitle") :: BillboardGui?
	local billboard: BillboardGui
	if existing then
		billboard = existing
	else
		billboard = Instance.new("BillboardGui")
		billboard.Name = "AuraTitle"
		billboard.Size = UDim2.fromOffset(200, 56)
		billboard.StudsOffset = Vector3.new(0, 2.4, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 120
		billboard.Parent = head
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.fromScale(1, 0.55)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Palette.AuraPurple
		title.TextStrokeTransparency = 0.3
		title.Parent = billboard
		local grade = Instance.new("TextLabel")
		grade.Name = "Grade"
		grade.Position = UDim2.fromScale(0, 0.55)
		grade.Size = UDim2.fromScale(1, 0.45)
		grade.BackgroundTransparency = 1
		grade.Font = Enum.Font.FredokaOne
		grade.TextScaled = true
		grade.TextColor3 = Palette.BusYellow
		grade.TextStrokeTransparency = 0.3
		grade.Parent = billboard
	end
	local rank = Rebirths.RankFor(profile.aura)
	local crown = player:GetAttribute("Bounty") == true and "👑 " or "";
	(billboard:FindFirstChild("Title") :: TextLabel).Text = crown .. rank .. " · " .. NumberFormat.Abbreviate(profile.aura) .. " aura";
	(billboard:FindFirstChild("Grade") :: TextLabel).Text = Rebirths.GradeName(profile.grade)
	player:SetAttribute("Rank", rank)
end
AuraService.UpdateOverhead = updateOverhead

function AuraService.Add(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile or amount == 0 then
		return
	end
	profile.aura = math.max(0, profile.aura + amount)
	player:SetAttribute("Aura", profile.aura)
	EconomyService.RefreshStats(player)
	updateOverhead(player)
	if amount > 0 then
		Signals.AuraGained:Fire(player, amount)
	end
end

function AuraService.Init()
	Signals.Stole:Connect(function(thief, victim)
		local bonus = 0
		if victim and victim:GetAttribute("Bounty") == true then
			bonus = GameConfig.BountyStealAuraBonus
		end
		AuraService.Add(thief, GameConfig.RepPerSteal + bonus)
	end)
	Signals.ThiefHit:Connect(function(puncher)
		AuraService.Add(puncher, GameConfig.RepPerThiefHit)
	end)
	Signals.CaughtStealing:Connect(function(thief)
		AuraService.Add(thief, -5)
	end)
	Signals.QuizWon:Connect(function(player)
		AuraService.Add(player, GameConfig.QuizRepReward)
	end)
	Signals.QuizWrong:Connect(function(player)
		AuraService.Add(player, -1)
	end)
	Signals.ProfileLoaded:Connect(function(player, profile)
		player:SetAttribute("Aura", profile.aura)
		updateOverhead(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			updateOverhead(player)
		end)
		player:GetAttributeChangedSignal("Bounty"):Connect(function()
			updateOverhead(player)
		end)
	end)
end

return AuraService
