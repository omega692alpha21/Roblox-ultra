--!strict
-- Daily quests: 3 per day from the pool, progressed by game signals, claimed from
-- the Quests panel. Completing all three grants a bonus wheel spin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Config.Rewards)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AuraService = require(script.Parent.AuraService)
local Signals = require(script.Parent.Parent.Signals)

local QuestService = {}

type Quest = {
	id: string,
	label: string,
	stat: string,
	goal: number,
	progress: number,
	claimed: boolean,
	cash: number,
	aura: number,
}

-- quests are per-day but not persisted across servers to keep the save small;
-- they live in memory keyed by (player, utc day) and reset daily
local quests: { [Player]: { day: number, list: { Quest }, allBonusGiven: boolean } } = {}
local rng = Random.new()

local function today(): number
	return math.floor(os.time() / 86400)
end

local function rollQuests(player: Player)
	local pool = table.clone(Rewards.QuestPool)
	local list: { Quest } = {}
	for _ = 1, math.min(Rewards.QuestsPerDay, #pool) do
		local pick = table.remove(pool, rng:NextInteger(1, #pool)) :: any
		table.insert(list, {
			id = pick.id,
			label = pick.label,
			stat = pick.stat,
			goal = pick.goal,
			progress = 0,
			claimed = false,
			cash = pick.cash,
			aura = pick.aura,
		})
	end
	quests[player] = { day = today(), list = list, allBonusGiven = false }
end

local function pushState(player: Player)
	local entry = quests[player]
	if entry then
		Remotes.Get("QuestState"):FireClient(player, entry.list)
	end
end

local function ensureQuests(player: Player)
	local entry = quests[player]
	if not entry or entry.day ~= today() then
		rollQuests(player)
		pushState(player)
	end
end

local function bump(player: Player, stat: string, amount: number)
	ensureQuests(player)
	local entry = quests[player]
	if not entry then
		return
	end
	local changed = false
	for _, quest in entry.list do
		if quest.stat == stat and not quest.claimed and quest.progress < quest.goal then
			quest.progress = math.min(quest.goal, quest.progress + amount)
			changed = true
			if quest.progress >= quest.goal then
				Remotes.Get("Notify"):FireClient(player, "Quest complete: " .. quest.label .. " — claim it!", "aura")
			end
		end
	end
	if changed then
		pushState(player)
	end
end

-- Today's quests, for anything that needs to read progress without owning it.
function QuestService.List(player: Player): { Quest }?
	local entry = quests[player]
	return entry and entry.list or nil
end

function QuestService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.defer(ensureQuests, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		quests[player] = nil
	end)
	Signals.ProfileLoaded:Connect(function(player)
		ensureQuests(player)
		pushState(player)
	end)

	-- and again a few seconds later: the panels connect their handlers as the
	-- client boots, which can land after the first push, and a journal that
	-- opens empty until the next quest tick reads as broken
	Signals.ProfileLoaded:Connect(function(player)
		task.delay(4, function()
			if player.Parent then
				pushState(player)
			end
		end)
	end)

	Signals.Recruited:Connect(function(player)
		bump(player, "recruit", 1)
	end)
	Signals.Stole:Connect(function(thief)
		bump(thief, "steal", 1)
	end)
	Signals.QuizWon:Connect(function(player)
		bump(player, "quiz", 1)
	end)
	Signals.Earned:Connect(function(player, amount)
		bump(player, "earn", amount)
	end)
	Signals.ThiefHit:Connect(function(puncher)
		bump(puncher, "thiefhit", 1)
	end)
	Signals.Collected:Connect(function(player)
		bump(player, "collect", 1)
	end)
	Signals.AuraGained:Connect(function(player, amount)
		bump(player, "aura", amount)
	end)

	Remotes.Get("ClaimQuest").OnServerEvent:Connect(function(player, index)
		if typeof(index) ~= "number" then
			return
		end
		local entry = quests[player]
		local profile = DataService.Get(player)
		if not entry or not profile then
			return
		end
		local quest = entry.list[math.floor(index)]
		if not quest or quest.claimed or quest.progress < quest.goal then
			return
		end
		quest.claimed = true
		local cash = math.floor(quest.cash * EconomyService.Multiplier(player))
		EconomyService.AddCash(player, cash, false)
		if quest.aura > 0 then
			AuraService.Add(player, quest.aura)
		end
		Remotes.Get("Notify"):FireClient(
			player,
			("Quest claimed: +$%s%s"):format(NumberFormat.Abbreviate(cash), quest.aura > 0 and " +" .. quest.aura .. " aura" or ""),
			"good"
		)
		local allDone = true
		for _, q in entry.list do
			if not q.claimed then
				allDone = false
				break
			end
		end
		if allDone and not entry.allBonusGiven then
			entry.allBonusGiven = true
			profile.spinTokens += Rewards.QuestAllBonusSpins
			Remotes.Get("Notify"):FireClient(player, "All quests done — bonus wheel spin!", "aura")
		end
		pushState(player)
	end)
end

return QuestService
