--!strict
-- Classes.
--
-- The bell used to fire the same three-question pop quiz at everybody,
-- wherever they were standing. Now the bell names a subject, and that
-- subject's professor is a person standing in a real room waiting for you.
-- You walk there, they let you sit in, and the lesson is a minigame built for
-- that subject.
--
-- The answer key never leaves the server: the client is sent prompts and
-- buttons, and sends back which button it pressed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Cliques = require(ReplicatedStorage.Config.Cliques)
local Subjects = require(ReplicatedStorage.Config.Subjects)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local ClassGames = require(script.Parent.ClassGames)
local JailService = require(script.Parent.JailService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AuraService = require(script.Parent.AuraService)
local StudentGen = require(script.Parent.StudentGen)
local Signals = require(script.Parent.Parent.Signals)

local ClassService = {}

local ROUNDS_PER_CLASS = 8
-- how close to the professor you have to be to sit in
local ATTEND_RADIUS = 26

type Session = {
	subjectId: string,
	level: number,
	rounds: { ClassGames.Round },
	answered: { [number]: boolean },
	correct: number,
	deadline: number,
	finished: boolean,
}

local sessions: { [Player]: Session } = {}
local prompts: { [string]: ProximityPrompt } = {}
local openSubject: string? = nil
local openUntil = 0
local rotation = 1

local function reward(player: Player, session: Session)
	local subject = Subjects.Get(session.subjectId)
	if not subject then
		return
	end
	local total = #session.rounds
	local ratio = total > 0 and session.correct / total or 0
	local letter = Subjects.Letter(ratio)
	local passed = ratio >= 0.5

	local cash = 0
	if passed then
		local mult = EconomyService.Multiplier(player) * (GameConfig.EventCashMultiplier or 1)
		local cliqueId = player:GetAttribute("Clique")
		local clique = typeof(cliqueId) == "string" and Cliques.Get(cliqueId) or nil
		if clique then
			mult *= clique.quizRewardMult
		end
		-- score scales the payout, so a C is worth going to and an A is worth
		-- trying for
		-- the setting the player chose pays what it costs them
		mult *= Subjects.Level(session.level).pay
		cash = math.floor(GameConfig.QuizCashReward * mult * (0.5 + ratio))
		EconomyService.AddCash(player, cash, true)
		player:SetAttribute("LuckMult", GameConfig.QuizLuckBuffMultiplier)
		player:SetAttribute("LuckUntil", os.clock() + GameConfig.QuizLuckBuffSeconds)
		Signals.QuizWon:Fire(player)
	end

	local aura = passed and math.floor(GameConfig.QuizRepReward * (0.5 + ratio)) or 0
	if aura > 0 then
		AuraService.Add(player, aura)
	end

	-- the report card keeps your best, so a bad day never costs you ground
	local card = DataService.Get(player)
	if card then
		local profile = card
		local best = profile.grades[session.subjectId] or 0
		if ratio > best then
			profile.grades[session.subjectId] = ratio
			player:SetAttribute("Grade_" .. session.subjectId, ratio)
			if ratio >= Subjects.BonusMinRatio and best < Subjects.BonusMinRatio then
				Remotes.Get("Notify"):FireClient(
					player,
					("%s %s — %s passed! +%d%% income, forever."):format(
						subject.icon,
						letter,
						subject.name,
						math.floor(Subjects.IncomeBonusPerSubject * 100)
					),
					"good"
				)
			end
		end
	end

	-- a perfect lesson is what a good student trades for a hall pass
	if ratio >= 0.999 then
		JailService.GrantHallPass(player, 1, ("for acing %s"):format(subject.name))
	end

	Remotes.Get("ClassResult"):FireClient(player, session.correct, total, cash, aura, letter, session.level)
	if passed then
		Remotes.Get("Notify"):FireClient(
			player,
			("%s %s: %s — +$%s, +%d aura, luck boost!"):format(
				subject.icon,
				subject.name,
				letter,
				NumberFormat.Abbreviate(cash),
				aura
			),
			"good"
		)
	else
		Remotes.Get("Notify"):FireClient(
			player,
			("%s %s: %s. %s is not impressed."):format(subject.icon, subject.name, letter, subject.professor),
			"bad"
		)
	end
end

local function finish(player: Player, session: Session)
	if session.finished then
		return
	end
	session.finished = true
	sessions[player] = nil
	reward(player, session)
end

local function beginLesson(player: Player, subject: Subjects.Subject)
	if sessions[player] then
		return
	end
	if not DataService.IsLoaded(player) then
		return
	end
	local profile = DataService.Get(player)
	local level = Subjects.Level(profile and profile.classLevel or nil)
	-- a Nerd gets longer on the clock and a Bully gets less: same lesson, and
	-- the role decides how much of it you can actually get through
	local seconds = math.max(8, level.seconds + Cliques.For(player).classTimeBonus)
	local rounds = ClassGames.Build(subject.id, ROUNDS_PER_CLASS, level.id)
	local session: Session = {
		subjectId = subject.id,
		level = level.id,
		rounds = rounds,
		answered = {},
		correct = 0,
		deadline = os.clock() + seconds,
		finished = false,
	}
	sessions[player] = session
	Signals.ClassAttended:Fire(player, subject.id)
	Remotes.Get("ClassStart"):FireClient(player, {
		subject = subject.id,
		name = subject.name,
		icon = subject.icon,
		professor = subject.professor,
		mode = subject.mode,
		level = level.id,
		levelName = level.name,
		rounds = ClassGames.Public(rounds),
		seconds = seconds,
	})
	task.delay(seconds + 1.5, function()
		local live = sessions[player]
		if live == session then
			finish(player, session)
		end
	end)
end

-- ------------------------------------------------------------- professors ---

local function spawnProfessor(subject: Subjects.Subject)
	local model = StudentGen.Create(subject.baseId, "_prof_" .. subject.id)
	if not model then
		return
	end
	model.Name = "Professor_" .. subject.id
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and (child.Name:find("Torso") or child.Name:find("Arm")) then
			child.Color = subject.coat
		end
	end
	local head = model:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("NameTag")
	if tag then
		local nameLabel = tag:FindFirstChild("StudentName") :: TextLabel?
		local info = tag:FindFirstChild("Info") :: TextLabel?
		local rarityLabel = tag:FindFirstChild("Rarity") :: TextLabel?
		if nameLabel then
			nameLabel.Text = subject.icon .. " " .. subject.professor
			nameLabel.TextColor3 = subject.color
		end
		if info then
			info.Text = subject.name .. " · " .. subject.room
			info.TextColor3 = Color3.fromRGB(216, 230, 212)
		end
		if rarityLabel then
			rarityLabel:Destroy()
		end
	end
	model.Parent = workspace
	StudentGen.Stand(model, CFrame.lookAt(subject.position, subject.facing))
	StudentGen.PlayAnim(model, "idle")

	local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Attend " .. subject.name
	prompt.ObjectText = subject.professor
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- only while their period is running
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		ClassService.Attend(player, subject.id)
	end)
	prompts[subject.id] = prompt
end

-- ----------------------------------------------------------------- public ---

-- Sit in on the open class. Public so the professor's prompt and the client's
-- "attend" button both land in the same validated path.
function ClassService.Attend(player: Player, subjectId: string)
	local subject = Subjects.Get(subjectId)
	if not subject then
		return
	end
	if openSubject ~= subjectId or os.clock() > openUntil then
		Remotes.Get("Notify"):FireClient(
			player,
			("%s is not teaching right now. Listen for the bell."):format(subject.professor),
			"info"
		)
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - subject.position).Magnitude > ATTEND_RADIUS then
		Remotes.Get("Notify"):FireClient(
			player,
			("Get to %s — %s only teaches in person."):format(subject.room, subject.professor),
			"bad"
		)
		return
	end
	beginLesson(player, subject)
end

function ClassService.OpenSubject(): (string?, number)
	return openSubject, openUntil
end

-- SchoolClock rings the bell as part of the school-day cycle. Each bell opens
-- the next subject on the timetable rather than quizzing the whole server.
function ClassService.StartBell()
	local subject = Subjects.List[rotation]
	rotation = rotation % #Subjects.List + 1
	openSubject = subject.id
	openUntil = os.clock() + GameConfig.ClassOpenSeconds
	ReplicatedStorage:SetAttribute("ClassSubject", subject.id)
	ReplicatedStorage:SetAttribute("ClassRoom", subject.room)
	ReplicatedStorage:SetAttribute("ClassEndsAt", workspace:GetServerTimeNow() + GameConfig.ClassOpenSeconds)
	-- the HUD period readout should say which lesson, not "Class Time"
	ReplicatedStorage:SetAttribute("Period", subject.name)
	ReplicatedStorage:SetAttribute("PeriodEndsAt", workspace:GetServerTimeNow() + GameConfig.ClassOpenSeconds)

	local prompt = prompts[subject.id]
	if prompt then
		prompt.Enabled = true
	end
	Remotes.Get("Notify"):FireAllClients(
		("%s BELL — %s with %s in %s. Get to class!"):format(
			subject.icon,
			subject.name:upper(),
			subject.professor,
			subject.room
		),
		"announce"
	)

	task.delay(GameConfig.ClassOpenSeconds, function()
		if openSubject ~= subject.id then
			return
		end
		openSubject = nil
		ReplicatedStorage:SetAttribute("ClassSubject", nil)
		ReplicatedStorage:SetAttribute("ClassRoom", nil)
		if prompt then
			prompt.Enabled = false
		end
	end)
end

function ClassService.Init()
	for _, subject in Subjects.List do
		task.spawn(spawnProfessor, subject)
	end

	-- the report card rides attributes, so the panel needs no remote of its own
	Signals.ProfileLoaded:Connect(function(player: Player, profile: DataService.Profile)
		for _, subject in Subjects.List do
			player:SetAttribute("Grade_" .. subject.id, profile.grades[subject.id])
		end
		player:SetAttribute("ClassLevel", Subjects.Level(profile.classLevel).id)
	end)

	Remotes.Get("SetClassLevel").OnServerEvent:Connect(function(player, level)
		if typeof(level) ~= "number" then
			return
		end
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		-- changing it mid-lesson would let you drop to Remedial for the hard
		-- questions and still be paid at Honors
		if sessions[player] then
			Remotes.Get("Notify"):FireClient(player, "Finish this lesson first.", "info")
			return
		end
		local chosen = Subjects.Level(math.floor(level))
		profile.classLevel = chosen.id
		player:SetAttribute("ClassLevel", chosen.id)
		Remotes.Get("Notify"):FireClient(
			player,
			("Classes set to %s — %s"):format(chosen.name, chosen.note),
			"good"
		)
	end)

	Remotes.Get("AttendClass").OnServerEvent:Connect(function(player, subjectId)
		if typeof(subjectId) == "string" then
			ClassService.Attend(player, subjectId)
		end
	end)

	Remotes.Get("ClassAnswer").OnServerEvent:Connect(function(player, roundIndex, answer)
		local session = sessions[player]
		if not session or session.finished or os.clock() > session.deadline then
			return
		end
		if typeof(roundIndex) ~= "number" then
			return
		end
		roundIndex = math.floor(roundIndex)
		local round = session.rounds[roundIndex]
		if not round or session.answered[roundIndex] then
			return
		end
		session.answered[roundIndex] = true

		local right = false
		if round.sequence then
			-- memory mode: the whole phrase has to come back in order
			if typeof(answer) == "table" then
				local entered = answer :: { any }
				right = #entered == #round.sequence
				if right then
					for i, note in round.sequence do
						if entered[i] ~= note then
							right = false
							break
						end
					end
				end
			end
		elseif typeof(answer) == "number" then
			right = math.floor(answer) == round.correct
		end

		if right then
			session.correct += 1
		else
			Signals.QuizWrong:Fire(player)
		end

		local answeredCount = 0
		for _ in session.answered do
			answeredCount += 1
		end
		if answeredCount >= #session.rounds then
			finish(player, session)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return ClassService
