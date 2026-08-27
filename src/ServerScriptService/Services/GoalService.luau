--!strict
-- The next thing to do.
--
-- Every retention system in this game already existed — playtime chests, a
-- daily streak, a spin wheel, daily quests, story missions, graduating — and
-- every one of them was invisible behind a menu. A player standing on the
-- lawn had nothing telling them what the game wanted from them next, which is
-- what makes a reward loop feel like it isn't there.
--
-- This picks the single highest-value action available right now and writes it
-- to player attributes. The client just renders them; no remote traffic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local Subjects = require(ReplicatedStorage.Config.Subjects)
local ClassService = require(script.Parent.ClassService)
local OnboardingService = require(script.Parent.OnboardingService)
local QuestService = require(script.Parent.QuestService)
local RewardService = require(script.Parent.RewardService)

local GoalService = {}

export type Goal = {
	text: string,
	progress: number, -- 0..1, drives the bar; 1 means "go do it now"
	kind: string, -- drives the accent colour on the client
}

-- The pile is worth collecting once it is worth a real fraction of what you
-- already have, or simply large. Below that, nagging about it is noise.
local function pileGoal(player: Player, profile: DataService.Profile): Goal?
	local pile = EconomyService.Pile(player)
	if pile < 250 then
		return nil
	end
	local income = player:GetAttribute("Income")
	local perSecond = typeof(income) == "number" and income or 0
	local worthIt = perSecond > 0 and pile >= perSecond * 25 or pile >= 1500
	if not worthIt then
		return nil
	end
	local streak = player:GetAttribute("CollectStreak")
	local streakNote = typeof(streak) == "number" and streak > 0 and (" · streak x%d"):format(streak + 1) or ""
	local _ = profile
	return {
		text = ("COLLECT YOUR PILE — $%s%s"):format(NumberFormat.Abbreviate(pile), streakNote),
		progress = 1,
		kind = "collect",
	}
end

-- A class only runs for a minute and pays a permanent income bonus the first
-- time you pass it, so while one is open it is the best thing on the board.
local function classGoal(player: Player, profile: DataService.Profile): Goal?
	local subjectId, until_ = ClassService.OpenSubject()
	if not subjectId then
		return nil
	end
	local subject = Subjects.Get(subjectId)
	if not subject then
		return nil
	end
	local seconds = math.max(0, math.ceil(until_ - os.clock()))
	local best = profile.grades[subjectId] or 0
	local note = if best >= Subjects.BonusMinRatio then "retake for a better grade" else "+2% income if you pass"
	return {
		text = ("%s %s in %s — %ds · %s"):format(subject.icon, subject.name:upper(), subject.room, seconds, note),
		progress = 1,
		kind = "class",
	}
end

local function questGoal(player: Player): Goal?
	local list = QuestService.List(player)
	if not list then
		return nil
	end
	-- a finished-but-unclaimed quest is free money sitting there
	for _, quest in list do
		if not quest.claimed and quest.progress >= quest.goal then
			return { text = ("CLAIM: %s"):format(quest.label), progress = 1, kind = "claim" }
		end
	end
	-- otherwise point at the one closest to done, so progress always reads
	local best, bestRatio = nil, -1
	for _, quest in list do
		if quest.claimed then
			continue
		end
		local ratio = quest.goal > 0 and quest.progress / quest.goal or 0
		if ratio > bestRatio then
			bestRatio = ratio
			best = quest
		end
	end
	if not best then
		return nil
	end
	local quest = best :: any
	return {
		text = ("%s  %s/%s"):format(
			quest.label,
			NumberFormat.Abbreviate(quest.progress),
			NumberFormat.Abbreviate(quest.goal)
		),
		progress = math.clamp(bestRatio, 0, 0.99),
		kind = "quest",
	}
end

local function chestGoal(player: Player): Goal?
	local tier = RewardService.ReadyChest(player)
	if not tier then
		return nil
	end
	return { text = ("CHEST READY: %s"):format(tier.prize.label), progress = 1, kind = "claim" }
end

local function crewGoal(player: Player, profile: DataService.Profile): Goal?
	local slots = PlotService.MaxSlots(player)
	local crew = PlotService.CrewCount(player)
	if crew >= slots then
		-- desks are full: the only way forward is graduating
		local cost = Rebirths.CostFor(profile.grade + 1)
		if cost <= 0 then
			return nil
		end
		local ready = profile.cash >= cost
		return {
			text = if ready
				then ("GRADUATE — x%.1f income, +1 desk"):format(Rebirths.Multiplier(profile.grade + 1))
				else ("Save $%s to graduate"):format(NumberFormat.Abbreviate(cost)),
			progress = if ready then 1 else math.clamp(profile.cash / cost, 0, 0.99),
			kind = if ready then "graduate" else "save",
		}
	end
	return {
		text = ("RECRUIT in the main hallway — %d desk%s free"):format(slots - crew, if slots - crew == 1 then "" else "s"),
		progress = math.clamp(crew / math.max(slots, 1), 0, 0.99),
		kind = "recruit",
	}
end

local function computeGoal(player: Player): Goal?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	-- a player still on their first day has exactly one thing to do, and it is
	-- not whichever pile happens to be biggest
	local first = OnboardingService.Current(player)
	if first then
		return {
			text = first.text,
			progress = (first.index - 1) / first.total,
			kind = "tutorial",
		}
	end
	-- highest value first: free money you already earned, then free money you
	-- already unlocked, then the thing that grows income
	return classGoal(player, profile)
		or pileGoal(player, profile)
		or chestGoal(player)
		or questGoal(player)
		or crewGoal(player, profile)
end

local function push(player: Player)
	-- where home is, so the minimap can mark it and "collect your pile" means
	-- somewhere instead of nowhere
	local plot = PlotService.GetPlot(player)
	player:SetAttribute("HomePad", plot and plot.collectPad.Position or nil)

	local goal = computeGoal(player)
	if goal then
		player:SetAttribute("Goal", goal.text)
		player:SetAttribute("GoalProgress", goal.progress)
		player:SetAttribute("GoalKind", goal.kind)
	else
		player:SetAttribute("Goal", nil)
	end
end

function GoalService.Init()
	task.spawn(function()
		while true do
			task.wait(1.5)
			for _, player in Players:GetPlayers() do
				if DataService.IsLoaded(player) then
					pcall(push, player)
				end
			end
		end
	end)
	local _ = GameConfig
end

return GoalService
