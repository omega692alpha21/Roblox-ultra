--!strict
-- Class bells: every few minutes a pop quiz goes out. The answer key stays on the
-- server; the client only ever sends (questionIndex, answerIndex). Passing (2/3)
-- pays cash + aura + a luck buff. Nerds get boosted rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Questions = require(ReplicatedStorage.Config.Quizzes)
local Cliques = require(ReplicatedStorage.Config.Cliques)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Signals = require(script.Parent.Parent.Signals)

local ClassService = {}

type Session = {
	questionIndexes: { number }, -- indexes into the Questions pool
	answered: { [number]: boolean },
	correct: number,
	deadline: number,
	finished: boolean,
}

local rng = Random.new()
local sessions: { [Player]: Session } = {}

local function finishQuiz(player: Player, session: Session)
	if session.finished then
		return
	end
	session.finished = true
	sessions[player] = nil

	local passed = session.correct >= 2
	local cash = 0
	if passed then
		local profile = DataService.Get(player)
		if profile then
			local mult = EconomyService.Multiplier(player) * (GameConfig.EventCashMultiplier or 1)
			local cliqueId = player:GetAttribute("Clique")
			local clique = typeof(cliqueId) == "string" and Cliques.Get(cliqueId) or nil
			if clique then
				mult *= clique.quizRewardMult
			end
			cash = math.floor(GameConfig.QuizCashReward * mult)
			EconomyService.AddCash(player, cash, true)
		end
		-- luck buff
		player:SetAttribute("LuckMult", GameConfig.QuizLuckBuffMultiplier)
		player:SetAttribute("LuckUntil", os.clock() + GameConfig.QuizLuckBuffSeconds)
		Signals.QuizWon:Fire(player)
	end
	Remotes.Get("QuizResult"):FireClient(player, session.correct, cash, passed and GameConfig.QuizRepReward or 0)
	if passed then
		Remotes.Get("Notify"):FireClient(
			player,
			("Quiz passed! +$%s, +%d aura, luck boost active!"):format(NumberFormat.Abbreviate(cash), GameConfig.QuizRepReward),
			"good"
		)
	end
end

local function startBell()
	Remotes.Get("Notify"):FireAllClients("CLASS BELL! Pop quiz — answer for cash, aura and LUCK!", "info")
	local picks: { number } = {}
	while #picks < GameConfig.QuizQuestionCount do
		local index = rng:NextInteger(1, #Questions)
		if not table.find(picks, index) then
			table.insert(picks, index)
		end
	end
	local publicQuestions = {}
	for _, index in picks do
		table.insert(publicQuestions, { q = Questions[index].q, answers = Questions[index].answers })
	end
	local deadline = os.clock() + GameConfig.ClassOpenSeconds
	for _, player in Players:GetPlayers() do
		if DataService.IsLoaded(player) then
			sessions[player] = {
				questionIndexes = picks,
				answered = {},
				correct = 0,
				deadline = deadline,
				finished = false,
			}
			Remotes.Get("QuizStart"):FireClient(player, publicQuestions, GameConfig.ClassOpenSeconds)
		end
	end
	task.delay(GameConfig.ClassOpenSeconds + 1, function()
		for player, session in sessions do
			if session.deadline <= os.clock() then
				finishQuiz(player, session)
			end
		end
	end)
end

function ClassService.Init()
	Remotes.Get("QuizAnswer").OnServerEvent:Connect(function(player, questionIndex, answerIndex)
		local session = sessions[player]
		if not session or session.finished or os.clock() > session.deadline then
			return
		end
		if typeof(questionIndex) ~= "number" or typeof(answerIndex) ~= "number" then
			return
		end
		questionIndex = math.floor(questionIndex)
		answerIndex = math.floor(answerIndex)
		if questionIndex < 1 or questionIndex > #session.questionIndexes or session.answered[questionIndex] then
			return
		end
		local question = Questions[session.questionIndexes[questionIndex]]
		if answerIndex < 1 or answerIndex > #question.answers then
			return
		end
		session.answered[questionIndex] = true
		if answerIndex == question.correct then
			session.correct += 1
		else
			Signals.QuizWrong:Fire(player)
		end
		local answeredCount = 0
		for _ in session.answered do
			answeredCount += 1
		end
		if answeredCount >= #session.questionIndexes then
			finishQuiz(player, session)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

-- SchoolClock rings the bell as part of the school-day cycle.
ClassService.StartBell = startBell

return ClassService
