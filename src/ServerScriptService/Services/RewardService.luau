--!strict
-- Retention systems: playtime chests, daily login streak, spin wheel,
-- offline earnings, social rewards. Everything granted server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Rewards = require(ReplicatedStorage.Config.Rewards)
local Products = require(ReplicatedStorage.Config.Products)
local Cliques = require(ReplicatedStorage.Config.Cliques)
local Students = require(ReplicatedStorage.Config.Students)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local Signals = require(script.Parent.Parent.Signals)

local RewardService = {}

local rng = Random.new()
local joinTime: { [Player]: number } = {}
local playtimeClaimed: { [Player]: { [number]: boolean } } = {}
local spinBusy: { [Player]: boolean } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local function grantPrize(player: Player, prize: Rewards.Prize)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if prize.kind == "cash" then
		local amount = math.floor((prize.amount or 0) * EconomyService.Multiplier(player))
		EconomyService.AddCash(player, amount, false)
		Remotes.Get("Notify"):FireClient(player, "+$" .. NumberFormat.Abbreviate(amount) .. "!", "good")
	elseif prize.kind == "luck" then
		player:SetAttribute("LuckMult", prize.luckMult or 1.5)
		player:SetAttribute("LuckUntil", os.clock() + (prize.amount or 600))
		Remotes.Get("Notify"):FireClient(player, "Luck boost active!", "aura")
	elseif prize.kind == "spin" then
		profile.spinTokens += prize.amount or 1
		Remotes.Get("Notify"):FireClient(player, "+" .. tostring(prize.amount or 1) .. " wheel spin!", "good")
	elseif prize.kind == "student" and prize.rarity then
		local def = Students.RollFromRarity(prize.rarity, rng)
		if def then
			if PlotService.CrewCount(player) < PlotService.MaxSlots(player) then
				PlotService.AddStudent(player, def.id)
				Remotes.Get("Notify"):FireClient(player, prize.rarity:upper() .. " " .. def.name .. " joined your crew!", "aura")
			else
				EconomyService.AddCash(player, math.floor(def.cost / 2), false)
				Remotes.Get("Notify"):FireClient(player, "Crew full — converted to $" .. NumberFormat.Abbreviate(def.cost / 2), "info")
			end
		end
	end
end

local function buildState(player: Player): any
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	return {
		elapsed = os.clock() - (joinTime[player] or os.clock()),
		playtimeClaimed = playtimeClaimed[player] or {},
		streakDay = ((profile.loginStreak - 1) % 7) + 1,
		spinTokens = profile.spinTokens,
		freeSpin = profile.lastSpinDay < today(),
		groupClaimed = profile.social.group == true,
		groupId = Products.GroupId,
	}
end

local function pushState(player: Player)
	local state = buildState(player)
	if state then
		Remotes.Get("RewardState"):FireClient(player, state)
	end
end

local function onProfileLoaded(player: Player, profile: DataService.Profile)
	-- daily streak
	local day = today()
	if profile.lastLoginDay ~= day then
		if profile.lastLoginDay == day - 1 then
			profile.loginStreak += 1
		else
			profile.loginStreak = 1
		end
		profile.lastLoginDay = day
		local streakIndex = ((profile.loginStreak - 1) % 7) + 1
		local prize = Rewards.Streak[streakIndex]
		Remotes.Get("Notify"):FireClient(
			player,
			("Day %d streak: %s"):format(streakIndex, prize.label),
			"aura"
		)
		grantPrize(player, prize)
	end

	-- offline earnings
	if profile.lastSeen > 0 and profile.lastIncome > 0 then
		local away = os.time() - profile.lastSeen
		local capHours = GameConfig.OfflineEarningsCapHours
		if player:GetAttribute("Pass2x") then
			capHours = GameConfig.OfflineEarningsCapHours2x
		end
		local cliqueId = profile.clique
		local clique = cliqueId and Cliques.Get(cliqueId) or nil
		if clique then
			capHours += clique.offlineCapBonusHours
		end
		local capped = math.min(away, capHours * 3600)
		local amount = math.floor(profile.lastIncome * GameConfig.OfflineEarningsRate * capped)
		if amount >= 1 then
			EconomyService.AddCash(player, amount, true)
			Remotes.Get("OfflineEarnings"):FireClient(player, amount, away)
		end
	end

	pushState(player)
end

function RewardService.Init()
	Players.PlayerAdded:Connect(function(player)
		joinTime[player] = os.clock()
		playtimeClaimed[player] = {}
	end)
	for _, player in Players:GetPlayers() do
		joinTime[player] = joinTime[player] or os.clock()
		playtimeClaimed[player] = playtimeClaimed[player] or {}
	end
	Players.PlayerRemoving:Connect(function(player)
		joinTime[player] = nil
		playtimeClaimed[player] = nil
		spinBusy[player] = nil
	end)

	Signals.ProfileLoaded:Connect(onProfileLoaded)

	Remotes.GetFunction("GetRewardState").OnServerInvoke = function(player)
		return buildState(player)
	end

	Remotes.Get("ClaimPlaytime").OnServerEvent:Connect(function(player, index)
		if typeof(index) ~= "number" then
			return
		end
		index = math.floor(index)
		local tier = Rewards.Playtime[index]
		if not tier or not DataService.IsLoaded(player) then
			return
		end
		local claimed = playtimeClaimed[player]
		if not claimed or claimed[index] then
			return
		end
		local elapsed = os.clock() - (joinTime[player] or os.clock())
		if elapsed < tier.minutes * 60 then
			return
		end
		claimed[index] = true
		grantPrize(player, tier.prize)
		pushState(player)
	end)

	Remotes.Get("SpinWheel").OnServerEvent:Connect(function(player)
		if spinBusy[player] then
			return
		end
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		spinBusy[player] = true
		if profile.lastSpinDay < today() then
			profile.lastSpinDay = today()
		elseif profile.spinTokens > 0 then
			profile.spinTokens -= 1
		else
			spinBusy[player] = nil
			Remotes.Get("Notify"):FireClient(player, "No spins left — come back tomorrow or grab a spin pack!", "bad")
			return
		end
		local prize = Rewards.RollWheel(rng)
		local prizeIndex = table.find(Rewards.Wheel, prize) or 1
		Remotes.Get("SpinResult"):FireClient(player, prizeIndex, prize.label)
		-- grant after a beat so the client wheel animation can land first
		task.delay(2.5, function()
			if player.Parent then
				grantPrize(player, prize)
				pushState(player)
			end
			spinBusy[player] = nil
		end)
	end)

	Remotes.Get("ClaimSocial").OnServerEvent:Connect(function(player, kind)
		if kind ~= "group" then
			return
		end
		local profile = DataService.Get(player)
		if not profile or profile.social.group or Products.GroupId == 0 then
			return
		end
		local ok, inGroup = pcall(function()
			return (player :: any):IsInGroup(Products.GroupId)
		end)
		if ok and inGroup then
			profile.social.group = true
			EconomyService.AddCash(player, Rewards.GroupJoinCash, false)
			Remotes.Get("Notify"):FireClient(player, "Group reward: +$" .. NumberFormat.Abbreviate(Rewards.GroupJoinCash) .. "!", "good")
			pushState(player)
		else
			Remotes.Get("Notify"):FireClient(player, "Join the group first, then claim!", "bad")
		end
	end)
end

return RewardService
