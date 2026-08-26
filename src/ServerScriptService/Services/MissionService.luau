--!strict
-- Story missions: three named characters stand around campus with Talk prompts.
-- Each has a chain of missions with dialogue; completed counts persist in the
-- profile, live progress is per-session. Rewards scale with the grade multiplier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Students = require(ReplicatedStorage.Config.Students)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AuraService = require(script.Parent.AuraService)
local StudentGen = require(script.Parent.StudentGen)
local Signals = require(script.Parent.Parent.Signals)

local MissionService = {}

type Mission = {
	label: string,
	stat: string,
	goal: number,
	cash: number,
	aura: number,
	intro: { string },
	during: string,
	done: { string },
}

type Giver = {
	id: string,
	name: string,
	baseId: string, -- roster id used for the model
	suitColor: Color3?,
	position: Vector3,
	faceToward: Vector3,
	allDone: string,
	missions: { Mission },
}

local GIVERS: { Giver } = {
	{
		id = "principal",
		name = "Principal Crumb",
		baseId = "valedictorian",
		suitColor = Color3.fromRGB(70, 70, 80),
		position = Vector3.new(-186, 0, -60),
		faceToward = Vector3.new(0, 0, -60),
		allDone = "Keep it up. This school runs on lunch money and I pretend not to know.",
		missions = {
			{
				label = "Recruit 3 students",
				stat = "recruit", goal = 3, cash = 2500, aura = 10,
				intro = {
					"Ah, the new kid. Enrollment is DOWN and my bonus depends on it.",
					"Recruit 3 students from the hallway. Don't ask where they come from.",
				},
				during = "Still short on students. The hallway. Go.",
				done = { "Excellent. The superintendent will never audit us now. Here's your cut." },
			},
			{
				label = "Earn $50K lunch money",
				stat = "earn", goal = 50000, cash = 8000, aura = 20,
				intro = {
					"Between us: the school budget is... creative.",
					"Show me you can move money. Earn $50K and I'll make you a prefect. Unofficially.",
				},
				during = "That crew of yours should be earning. $50K. Chop chop.",
				done = { "You've got a gift, kid. A slightly concerning gift." },
			},
			{
				label = "Pass 2 pop quizzes",
				stat = "quiz", goal = 2, cash = 10000, aura = 30,
				intro = {
					"The district wants 'academic results'. Ugh.",
					"Pass 2 pop quizzes so the charts point up and they leave me alone.",
				},
				during = "Listen for the bell. Answer things correctly. Allegedly you can.",
				done = { "Test scores UP. You're my favorite statistic." },
			},
		},
	},
	{
		id = "janitor",
		name = "Janitor Reeves",
		baseId = "the_janitor",
		suitColor = Color3.fromRGB(90, 100, 90),
		position = Vector3.new(150, 0, 10),
		faceToward = Vector3.new(0, 0, 0),
		allDone = "I've seen things in these halls, kid. You're one of the good ones.",
		missions = {
			{
				label = "Collect your pile 6 times",
				stat = "collect", goal = 6, cash = 3000, aura = 10,
				intro = {
					"I mop this hallway every night. You know what I find? Loose change. Everywhere.",
					"Keep your homeroom TIDY. Collect your pile 6 times.",
				},
				during = "Money on the floor attracts ants. And Preps. Keep collecting.",
				done = { "Clean floors, full pockets. That's the Reeves way." },
			},
			{
				label = "Steal 1 student from another homeroom",
				stat = "steal", goal = 1, cash = 6000, aura = 25,
				intro = {
					"See homeroom 3? Kid in there 'borrowed' my favorite mop in 2019. Never returned it.",
					"Go remind everyone that nothing in this school is truly locked. Steal 1 student.",
				},
				during = "Unlocked base. Quiet feet. On your way back, check for lasers.",
				done = { "Heh. Just like I used to. Don't tell the Principal." },
			},
			{
				label = "Farm 30 aura",
				stat = "aura", goal = 30, cash = 5000, aura = 20,
				intro = {
					"Respect ain't given in these halls. It's mopped up, little by little.",
					"Farm 30 aura. Quizzes, steals, defending your crew. All of it counts.",
				},
				during = "Aura comes to those who move. Keep moving.",
				done = { "Now THAT'S a reputation. Shine on, kid." },
			},
		},
	},
	{
		id = "lunchlady",
		name = "Lunch Lady Sue",
		baseId = "lunch_lady_supreme",
		suitColor = Color3.fromRGB(230, 230, 235),
		position = Vector3.new(-215, 0, 32),
		faceToward = Vector3.new(-215, 0, 100),
		allDone = "Extra tots for you today, sugar. You've earned 'em.",
		missions = {
			{
				label = "Earn $10K lunch money",
				stat = "earn", goal = 10000, cash = 2000, aura = 8,
				intro = {
					"Sweetie, the cafeteria till is SHORT and mystery meat isn't free.",
					"Earn $10K and the tots keep flowing for everybody.",
				},
				during = "The till's still short, sugar. $10K.",
				done = { "Bless your hustle. Tots for the people!" },
			},
			{
				label = "Pass 1 pop quiz",
				stat = "quiz", goal = 1, cash = 4000, aura = 15,
				intro = {
					"Smart kids get seconds. That's cafeteria law.",
					"Pass a pop quiz for me, hon.",
				},
				during = "Wait for the bell, then show 'em what you know.",
				done = { "Look at the big brain on you! Seconds. Forever." },
			},
			{
				label = "Recruit a Rare or better student",
				stat = "recruitrare", goal = 1, cash = 7000, aura = 20,
				intro = {
					"Word is there are some SERIOUSLY talented kids in that hallway.",
					"Recruit me somebody special. Rare or better. They eat free.",
				},
				during = "Common kids are lovely but I said SPECIAL, hon.",
				done = { "Ooh, they've got the sauce! Welcome to the family." },
			},
		},
	},
}

local progress: { [Player]: { [string]: number } } = {}

local function currentMission(player: Player, giver: Giver): (Mission?, number)
	local profile = DataService.Get(player)
	if not profile then
		return nil, 0
	end
	local doneCount = profile.missions[giver.id] or 0
	return giver.missions[doneCount + 1], doneCount
end

local function bump(player: Player, stat: string, amount: number)
	local perPlayer = progress[player]
	if not perPlayer then
		return
	end
	for _, giver in GIVERS do
		local mission = currentMission(player, giver)
		if mission and mission.stat == stat and perPlayer[giver.id] ~= nil then
			perPlayer[giver.id] += amount
		end
	end
end

local function talk(player: Player, giver: Giver)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	progress[player] = progress[player] or {}
	local perPlayer = progress[player]
	local mission = currentMission(player, giver)
	if not mission then
		Remotes.Get("Dialogue"):FireClient(player, giver.name, { giver.allDone })
		return
	end
	local active = perPlayer[giver.id]
	if active == nil then
		perPlayer[giver.id] = 0
		local lines = table.clone(mission.intro)
		table.insert(lines, "MISSION: " .. mission.label)
		Remotes.Get("Dialogue"):FireClient(player, giver.name, lines)
	elseif active < mission.goal then
		Remotes.Get("Dialogue"):FireClient(
			player,
			giver.name,
			{ mission.during, ("Progress: %s / %s"):format(NumberFormat.Abbreviate(active), NumberFormat.Abbreviate(mission.goal)) }
		)
	else
		local cash = math.floor(mission.cash * EconomyService.Multiplier(player))
		EconomyService.AddCash(player, cash, false)
		AuraService.Add(player, mission.aura)
		profile.missions[giver.id] = (profile.missions[giver.id] or 0) + 1
		perPlayer[giver.id] = nil
		local lines = table.clone(mission.done)
		table.insert(lines, ("REWARD: $%s + %d aura"):format(NumberFormat.Abbreviate(cash), mission.aura))
		Remotes.Get("Dialogue"):FireClient(player, giver.name, lines)
	end
end

local function spawnGiver(giver: Giver)
	local model = StudentGen.Create(giver.baseId, "_giver")
	if not model then
		return
	end
	model.Name = "Giver_" .. giver.id
	-- outfit + clean name tag
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and (child.Name:find("Torso") or child.Name:find("Leg")) and giver.suitColor then
			child.Color = giver.suitColor
		end
	end
	local head = model:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("NameTag")
	if tag then
		local nameLabel = tag:FindFirstChild("StudentName") :: TextLabel?
		local info = tag:FindFirstChild("Info") :: TextLabel?
		local rarityLabel = tag:FindFirstChild("Rarity") :: TextLabel?
		if nameLabel then
			nameLabel.Text = giver.name
			nameLabel.TextColor3 = Color3.fromRGB(245, 197, 49)
		end
		if info then
			info.Text = "has work for you"
			info.TextColor3 = Color3.fromRGB(216, 230, 212)
		end
		if rarityLabel then
			rarityLabel:Destroy()
		end
	end
	model.Parent = workspace
	StudentGen.Stand(model, CFrame.lookAt(giver.position, giver.faceToward))
	StudentGen.PlayAnim(model, "idle")
	local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = giver.name
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(player)
			talk(player, giver)
		end)
	end
end

function MissionService.Init()
	for _, giver in GIVERS do
		spawnGiver(giver)
	end
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
	end)

	Signals.Recruited:Connect(function(player, defId)
		bump(player, "recruit", 1)
		local entry = Students.Get(defId)
		if entry and entry.rarity.name ~= "Common" then
			bump(player, "recruitrare", 1)
		end
	end)
	Signals.Earned:Connect(function(player, amount)
		bump(player, "earn", amount)
	end)
	Signals.Stole:Connect(function(thief)
		bump(thief, "steal", 1)
	end)
	Signals.QuizWon:Connect(function(player)
		bump(player, "quiz", 1)
	end)
	Signals.Collected:Connect(function(player)
		bump(player, "collect", 1)
	end)
	Signals.AuraGained:Connect(function(player, amount)
		bump(player, "aura", amount)
	end)
	Signals.ThiefHit:Connect(function(puncher)
		bump(puncher, "thiefhit", 1)
	end)
end

return MissionService
