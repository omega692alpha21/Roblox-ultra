--!strict
-- First day at Crumbworth: a six-step quest that teaches the loop by making
-- you do it once.
--
-- The old tutorial was a card listing three things and then getting out of the
-- way, which is a manual, not a lesson. This tracks one step at a time, pays
-- for each, and puts a marker on the thing you are supposed to walk to — so a
-- new player never has to guess what the game wants or where it is.
--
-- Progress persists, so quitting mid-chain resumes rather than restarts, and
-- steps complete in whatever order they happen. Going to a class means waiting
-- for a bell, and a chain that blocks on a bell is a chain that strands the
-- player; doing something out of turn should count, not be ignored.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AuraService = require(script.Parent.AuraService)
local JailService = require(script.Parent.JailService)
local PlotService = require(script.Parent.PlotService)
local Signals = require(script.Parent.Parent.Signals)

local OnboardingService = {}

type Step = {
	id: string,
	title: string,
	hint: string,
	cash: number,
	aura: number,
	-- where to point the marker. nil means "no particular place"
	target: (Player) -> Vector3?,
}

local function hallway(_: Player): Vector3?
	return Vector3.new(0, 3, 70)
end

local function myPad(player: Player): Vector3?
	local plot = PlotService.GetPlot(player)
	return plot and plot.collectPad.Position or nil
end

local function myLock(player: Player): Vector3?
	local plot = PlotService.GetPlot(player)
	return plot and plot.lockSwitch.Position or nil
end

-- the nearest homeroom that is not yours: where a first steal is possible
local function someoneElsesPlot(player: Player): Vector3?
	local mine = PlotService.GetPlot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local plot = PlotService.GetPlot(other)
		if plot and plot ~= mine then
			local distance = (plot.cframe.Position - root.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = plot
			end
		end
	end
	return best and best.cframe.Position or nil
end

local STEPS: { Step } = {
	{
		id = "recruit",
		title = "Recruit your first student",
		hint = "Students walk the MAIN HALLWAY. Walk up to one and take the prompt — they earn you lunch money every second.",
		cash = 750,
		aura = 5,
		target = hallway,
	},
	{
		id = "collect",
		title = "Collect your pile",
		hint = "Your crew's earnings stack up in your homeroom. Stand on the GREEN PAD to bank them.",
		cash = 1000,
		aura = 5,
		target = myPad,
	},
	{
		id = "lock",
		title = "Lock your homeroom",
		hint = "An unlocked homeroom can be robbed. Hit the LOCK SWITCH by your door.",
		cash = 1500,
		aura = 10,
		target = myLock,
	},
	{
		id = "toy",
		title = "Throw something",
		hint = "You start with a slingshot. Aim with the reticle and tap the 🎯 button, bottom right.",
		cash = 1500,
		aura = 10,
		target = nil :: any,
	},
	{
		id = "class",
		title = "Go to a class",
		hint = "When the bell rings, get to the room it names and talk to the professor. Passing pays income forever.",
		cash = 2500,
		aura = 15,
		target = nil :: any,
	},
	{
		id = "steal",
		title = "Rob someone",
		hint = "Walk into an UNLOCKED homeroom, grab a student, and carry them back to yours.",
		cash = 4000,
		aura = 25,
		target = someoneElsesPlot,
	},
}

OnboardingService.StepCount = #STEPS

-- The first step still outstanding, plus how many are behind you.
local function stepFor(player: Player): (Step?, number)
	local profile = DataService.Get(player)
	if not profile then
		return nil, 0
	end
	local done = profile.tutorialDone or {}
	local count = 0
	local next_: Step? = nil
	for _, step in STEPS do
		if done[step.id] then
			count += 1
		elseif not next_ then
			next_ = step
		end
	end
	return next_, count
end

-- What the goal bar should say. Returns nil once the chain is finished.
function OnboardingService.Current(player: Player): { text: string, hint: string, index: number, total: number, target: Vector3? }?
	local step, done = stepFor(player)
	if not step then
		return nil
	end
	local ok, target = pcall(step.target or function()
		return nil
	end, player)
	return {
		text = ("FIRST DAY %d/%d — %s"):format(done + 1, #STEPS, step.title),
		hint = step.hint,
		index = done,
		total = #STEPS,
		target = ok and target or nil,
	}
end

local function publish(player: Player)
	local current = OnboardingService.Current(player)
	player:SetAttribute("TutorialHint", current and current.hint or nil)
	player:SetAttribute("TutorialTarget", current and current.target or nil)
	player:SetAttribute("TutorialStep", current and current.index or nil)
	player:SetAttribute("TutorialTotal", #STEPS)
end

local function complete(player: Player, id: string)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local done = profile.tutorialDone
	if not done or done[id] then
		return
	end
	local step: Step? = nil
	for _, candidate in STEPS do
		if candidate.id == id then
			step = candidate
			break
		end
	end
	if not step then
		return
	end
	local completed = step :: Step
	done[id] = true

	local cash = math.floor(completed.cash * EconomyService.Multiplier(player))
	EconomyService.AddCash(player, cash, true)
	AuraService.Add(player, completed.aura)

	local next_ = stepFor(player)
	if next_ then
		Remotes.Get("Notify"):FireClient(
			player,
			("✅ %s — +$%s, +%d aura.\nNEXT: %s — %s"):format(
				completed.title,
				NumberFormat.Abbreviate(cash),
				completed.aura,
				next_.title,
				next_.hint
			),
			"good"
		)
	else
		-- finishing the chain hands over the two things a new player has no
		-- other way to get yet
		JailService.GrantHallPass(player, 2, "for surviving your first day")
		profile.spinTokens += 1
		Remotes.Get("Notify"):FireClient(
			player,
			("🎓 FIRST DAY COMPLETE — +$%s, 2 hall passes and a free wheel spin. The school is yours."):format(
				NumberFormat.Abbreviate(cash)
			),
			"announce"
		)
	end
	publish(player)
end

function OnboardingService.Init()
	Signals.ProfileLoaded:Connect(function(player: Player)
		task.delay(1.5, function()
			if not player.Parent then
				return
			end
			publish(player)
			-- the hint is said once, on arrival, as a notification rather than
			-- a card that sits on the screen forever
			local current = OnboardingService.Current(player)
			if current then
				Remotes.Get("Notify"):FireClient(
					player,
					("FIRST DAY %d/%d — %s"):format(current.index + 1, current.total, current.hint),
					"info"
				)
			end
		end)
	end)

	Signals.Recruited:Connect(function(player)
		complete(player, "recruit")
	end)
	Signals.Collected:Connect(function(player)
		complete(player, "collect")
	end)
	Signals.Locked:Connect(function(player)
		complete(player, "lock")
	end)
	Signals.ToyUsed:Connect(function(player)
		complete(player, "toy")
	end)
	Signals.ClassAttended:Connect(function(player)
		complete(player, "class")
	end)
	Signals.Stole:Connect(function(thief)
		complete(thief, "steal")
	end)

	-- the steal marker and the collect pad both move with the world, so keep
	-- the target fresh rather than pinning it once
	task.spawn(function()
		while true do
			task.wait(4)
			for _, player in Players:GetPlayers() do
				if DataService.IsLoaded(player) then
					pcall(publish, player)
				end
			end
		end
	end)
end

return OnboardingService
