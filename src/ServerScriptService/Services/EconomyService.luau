--!strict
-- Income tick, cash mutation helpers, leaderstats, collect pads, friend bonus.
-- All cash changes in the game go through AddCash/TrySpend so attributes,
-- leaderstats and signals stay consistent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Students = require(ReplicatedStorage.Config.Students)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local Rewards = require(ReplicatedStorage.Config.Rewards)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Signals = require(script.Parent.Parent.Signals)

local EconomyService = {}

local uncollected: { [Player]: number } = {}
local friendBonus: { [Player]: number } = {}
local collectDebounce: { [Player]: number } = {}

local function ensureLeaderstats(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Cash", "Aura", "Grade" } do
		local v = Instance.new("StringValue")
		v.Name = name
		v.Value = "0"
		v.Parent = stats
	end
	stats.Parent = player
end

local function refreshStats(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	player:SetAttribute("Cash", profile.cash)
	player:SetAttribute("TotalEarned", profile.totalEarned)
	player:SetAttribute("Grade", profile.grade)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Cash") :: StringValue).Value = NumberFormat.Abbreviate(profile.cash);
		(stats:FindFirstChild("Aura") :: StringValue).Value = NumberFormat.Abbreviate(profile.aura);
		(stats:FindFirstChild("Grade") :: StringValue).Value = tostring(profile.grade)
	end
end
EconomyService.RefreshStats = refreshStats

-- Full income multiplier for a player: grade x passes x clique x friends.
function EconomyService.Multiplier(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	local mult = Rebirths.Multiplier(profile.grade)
	if player:GetAttribute("Pass2x") then
		mult *= 2
	end
	mult *= 1 + (friendBonus[player] or 0)
	return mult
end

-- Raw income per second from the crew (before multipliers).
function EconomyService.BaseIncome(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, member in profile.crew do
		local entry = Students.Get(member.id)
		if entry then
			total += entry.def.income
		end
	end
	return total
end

function EconomyService.AddCash(player: Player, amount: number, countsAsEarned: boolean?)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.cash += amount
	if countsAsEarned then
		profile.totalEarned += amount
		Signals.Earned:Fire(player, amount)
	end
	refreshStats(player)
end

function EconomyService.TrySpend(player: Player, amount: number): boolean
	local profile = DataService.Get(player)
	if not profile or amount < 0 or profile.cash < amount then
		return false
	end
	profile.cash -= amount
	refreshStats(player)
	return true
end

local function bank(player: Player)
	local pile = uncollected[player] or 0
	if pile < 1 then
		return
	end
	uncollected[player] = 0
	EconomyService.AddCash(player, math.floor(pile), true)
	Signals.Collected:Fire(player)
	local plot = PlotService.GetPlot(player)
	if plot then
		plot.pileLabel.Text = "$0"
	end
end

local function updateFriendBonus(player: Player)
	task.spawn(function()
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local ok, isFriend = pcall(function()
					return (player :: any):IsFriendsWith(other.UserId)
				end)
				if ok and isFriend then
					count += 1
				end
			end
		end
		friendBonus[player] = math.min(count * Rewards.FriendIncomeBonus, Rewards.FriendIncomeBonusCap)
	end)
end

function EconomyService.Init()
	Players.PlayerAdded:Connect(function(player)
		ensureLeaderstats(player)
		uncollected[player] = 0
		updateFriendBonus(player)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				updateFriendBonus(other)
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		ensureLeaderstats(player)
		uncollected[player] = uncollected[player] or 0
		updateFriendBonus(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		uncollected[player] = nil
		friendBonus[player] = nil
		collectDebounce[player] = nil
	end)
	Signals.ProfileLoaded:Connect(refreshStats)

	-- income tick
	task.spawn(function()
		while true do
			task.wait(GameConfig.IncomeTickSeconds)
			for _, player in Players:GetPlayers() do
				if not DataService.IsLoaded(player) then
					continue
				end
				local income = EconomyService.BaseIncome(player) * EconomyService.Multiplier(player)
				player:SetAttribute("Income", math.floor(income))
				local profile = DataService.Get(player)
				if profile then
					profile.lastIncome = income
				end
				if income <= 0 then
					continue
				end
				if player:GetAttribute("PassAutoCollect") then
					EconomyService.AddCash(player, income, true)
				else
					uncollected[player] = (uncollected[player] or 0) + income
					local plot = PlotService.GetPlot(player)
					if plot then
						plot.pileLabel.Text = "$" .. NumberFormat.Abbreviate(uncollected[player] or 0)
					end
				end
			end
		end
	end)

	-- collect pads: touching your own pad banks your pile
	task.defer(function()
		for _, player in Players:GetPlayers() do
			local _ = player
		end
	end)
end

-- Wire one plot's collect pad (called by Server bootstrap after map build).
function EconomyService.WireCollectPad(plot: any)
	plot.collectPad.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character :: any)
		if not player then
			return
		end
		if PlotService.GetPlot(player) ~= plot then
			return
		end
		local now = os.clock()
		if now - (collectDebounce[player] or 0) < 0.5 then
			return
		end
		collectDebounce[player] = now
		bank(player)
	end)
end

return EconomyService
