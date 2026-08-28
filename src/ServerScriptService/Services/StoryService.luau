--!strict
-- Runs THE CRUMBWORTH FILES.
--
-- The design rule here is that the story never asks you to go and do a story
-- activity. Every objective counts something the game already fires a signal
-- for -- a recruit, a lesson passed, a hit landed, Rico foiled -- so the
-- chapter advances while you play the game you were already playing, and the
-- narrative arrives as a consequence rather than an errand.
--
-- Chapters open on the school year (grade), so the story and the progression
-- are one ladder instead of two running side by side. A chapter you have not
-- reached the year for still shows, greyed, with the year it opens -- knowing
-- what is coming is most of why anyone graduates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage.Config.Story)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AuraService = require(script.Parent.AuraService)
local Signals = require(script.Parent.Parent.Signals)

local StoryService = {}

local function storyOf(profile: any)
	local story = profile.story
	if typeof(story) ~= "table" then
		story = { chapter = 1, counts = {}, done = {} }
		profile.story = story
	end
	story.counts = story.counts or {}
	story.done = story.done or {}
	story.chapter = story.chapter or 1
	return story
end

-- The value an objective is measured against: either a counter this service
-- keeps, or something already on the profile.
local function valueFor(player: Player, profile: any, objective: any): number
	local story = storyOf(profile)
	if objective.kind ~= "reach" then
		return story.counts[objective.stat] or 0
	end
	if objective.stat == "totalEarned" then
		return profile.totalEarned or 0
	elseif objective.stat == "aura" then
		return profile.aura or 0
	elseif objective.stat == "grade" then
		return profile.grade or 0
	elseif objective.stat == "goodgrades" then
		-- subjects sitting at a B or better on the report card
		local good = 0
		for _, ratio in profile.grades or {} do
			if typeof(ratio) == "number" and ratio >= 0.7 then
				good += 1
			end
		end
		return good
	end
	return story.counts[objective.stat] or 0
end

-- What the client draws: the current chapter, its objectives with progress,
-- and every chapter's title so the shape of the whole thing is visible.
local function publish(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local story = storyOf(profile)
	local chapters = {}
	for _, chapter in Story.Chapters do
		local entry: any = {
			number = chapter.number,
			title = chapter.title,
			speaker = chapter.speaker,
			grade = chapter.grade,
			state = "locked",
			objectives = {},
		}
		if story.done[chapter.id] then
			entry.state = "done"
			entry.reveal = chapter.reveal
		elseif chapter.number == story.chapter then
			entry.state = if (profile.grade or 0) >= chapter.grade then "open" else "waiting"
			entry.hook = chapter.hook
			entry.unlock = chapter.unlock
			entry.cash = chapter.cash
			entry.aura = chapter.aura
			for _, objective in chapter.objectives do
				table.insert(entry.objectives, {
					label = objective.label,
					have = math.min(valueFor(player, profile, objective), objective.goal),
					goal = objective.goal,
				})
			end
		end
		table.insert(chapters, entry)
	end
	Remotes.Get("StoryState"):FireClient(player, {
		chapter = story.chapter,
		total = Story.Count(),
		chapters = chapters,
	})
end

local function tell(player: Player, speaker: string, lines: { string })
	Remotes.Get("Dialogue"):FireClient(player, speaker, lines)
end

-- Has the current chapter's last objective just landed?
local function check(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local story = storyOf(profile)
	local chapter = Story.Get(story.chapter)
	if not chapter or story.done[chapter.id] then
		return
	end
	if (profile.grade or 0) < chapter.grade then
		return -- the year has not come round yet
	end
	for _, objective in chapter.objectives do
		if valueFor(player, profile, objective) < objective.goal then
			publish(player)
			return
		end
	end

	story.done[chapter.id] = true
	story.chapter = math.min(chapter.number + 1, Story.Count() + 1)
	EconomyService.AddCash(player, chapter.cash, true)
	AuraService.Add(player, chapter.aura)
	Remotes.Get("Notify"):FireClient(
		player,
		("📖 CHAPTER %d COMPLETE — %s  +$%s"):format(chapter.number, chapter.title, NumberFormat.Abbreviate(chapter.cash)),
		"aura"
	)
	Signals.ChapterDone:Fire(player, chapter.number)
	tell(player, chapter.speaker, chapter.reveal)
	if chapter.unlock then
		task.delay(1.5, function()
			Remotes.Get("Notify"):FireClient(player, "🔓 " .. chapter.unlock, "good")
		end)
	end
	player:SetAttribute("StoryChapter", story.chapter)
	publish(player)

	-- and open the next one, if its year has already arrived
	task.delay(4, function()
		StoryService.Nudge(player)
	end)
end

-- Say the next chapter's hook, once, when its year arrives.
function StoryService.Nudge(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local story = storyOf(profile)
	local chapter = Story.Get(story.chapter)
	if not chapter or story.done[chapter.id] then
		return
	end
	if (profile.grade or 0) < chapter.grade then
		return
	end
	if not story.told then
		story.told = {}
	end
	if not story.told[chapter.id] then
		story.told[chapter.id] = true
		tell(player, chapter.speaker, chapter.hook)
	end
	publish(player)
end

function StoryService.Bump(player: Player, stat: string, amount: number?)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local story = storyOf(profile)
	story.counts[stat] = (story.counts[stat] or 0) + (amount or 1)
	check(player)
end

function StoryService.Init()
	Remotes.GetFunction("GetStory").OnServerInvoke = function(player)
		publish(player)
		return true
	end

	Signals.ProfileLoaded:Connect(function(player)
		local profile = DataService.Get(player)
		if profile then
			player:SetAttribute("StoryChapter", storyOf(profile).chapter)
		end
		task.delay(6, function()
			if player.Parent then
				StoryService.Nudge(player)
			end
		end)
	end)

	Signals.Recruited:Connect(function(player)
		StoryService.Bump(player, "recruit")
	end)
	Signals.QuizWon:Connect(function(player)
		StoryService.Bump(player, "classpass")
	end)
	Signals.RivalFoiled:Connect(function(player)
		StoryService.Bump(player, "foil")
	end)
	Signals.ThiefHit:Connect(function(player)
		StoryService.Bump(player, "foil")
	end)
	Signals.Earned:Connect(function(player)
		check(player)
	end)
	Signals.AuraGained:Connect(function(player)
		check(player)
	end)
	Signals.FoundTheDoor:Connect(function(player)
		StoryService.Bump(player, "founddoor")
	end)

	-- the year turning is what opens most chapters
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("Grade"):Connect(function()
			task.wait(2)
			StoryService.Nudge(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal("Grade"):Connect(function()
			task.wait(2)
			StoryService.Nudge(player)
		end)
	end
end

return StoryService
