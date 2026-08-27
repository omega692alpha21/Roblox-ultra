--!strict
-- Live server events: every so often the whole server gets pulled into one
-- moment together — the thing that makes servers feel alive instead of
-- everyone grinding alone. Each event is announced, runs, and pays out
-- cash + Popular reputation via Signals.EventScore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local ClassService = require(script.Parent.ClassService)
local CoinService = require(script.Parent.CoinService)
local DodgeballService = require(script.Parent.DodgeballService)
local EconomyService = require(script.Parent.EconomyService)
local Signals = require(script.Parent.Parent.Signals)

local EventDirector = {}

local rng = Random.new()

-- campus-wide scatter points for the treasure hunt
local HUNT_SPOTS = {
	Vector3.new(-150, 0, 70), Vector3.new(150, 0, 70), Vector3.new(20, 0, 152),
	Vector3.new(-204, 0, -29), Vector3.new(0, 0, -100), Vector3.new(-204, 0, 35),
	Vector3.new(204, 0, -29), Vector3.new(-74, 0, -94), Vector3.new(-136, 0, 196),
	Vector3.new(136, 0, 196), Vector3.new(0, 0, 6), Vector3.new(-116, 0, 20),
}

-- cafeteria cluster for the food fight frenzy
local CAFETERIA = Vector3.new(-204, 0, -29)

local function announce(message: string)
	Remotes.Get("Notify"):FireAllClients(message, "announce")
end

local function scoreEvent(player: Player, eventId: string)
	Signals.EventScore:Fire(player, eventId)
end

local EVENTS: { { id: string, run: () -> () } } = {
	{
		id = "treasure_hunt",
		run = function()
			announce("📦 TREASURE HUNT! Golden coins hidden ALL OVER campus for 2 minutes — GO!")
			for _, spot in HUNT_SPOTS do
				CoinService.SpawnBonus(
					spot + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)),
					rng:NextInteger(150, 400),
					120,
					function(player)
						scoreEvent(player, "treasure_hunt")
					end
				)
			end
			task.wait(120)
			announce("Treasure hunt over — hope you got your share.")
		end,
	},
	{
		id = "food_fight",
		run = function()
			announce("🍕 FOOD FIGHT IN THE CAFETERIA! Grab the flying lunch money — 90 seconds of chaos!")
			EconomyService.SetEventMult(1.5)
			for wave = 1, 6 do
				for _ = 1, 3 do
					CoinService.SpawnBonus(
						CAFETERIA + Vector3.new(rng:NextNumber(-28, 28), 0, rng:NextNumber(-28, 28)),
						rng:NextInteger(80, 200),
						40,
						function(player)
							scoreEvent(player, "food_fight")
						end
					)
				end
				task.wait(15)
			end
			EconomyService.SetEventMult(1)
			announce("Food fight's over. The janitor is NOT happy.")
		end,
	},
	{
		id = "dodgeball",
		run = function()
			announce("🔴 DODGEBALL TOURNAMENT IN THE GYM! Grab a ball, PUNCH to throw — every hit pays! 2 minutes!")
			DodgeballService.StartRound(120)
			task.wait(120)
			announce("Dodgeball's over. Ice those bruises.")
		end,
	},
	{
		id = "quiz_showdown",
		run = function()
			announce("🧠 SURPRISE QUIZ SHOWDOWN! Get to Classroom 101 — double aura for smart kids!")
			ClassService.StartBell()
			task.wait(90)
		end,
	},
}

function EventDirector.Init()
	task.spawn(function()
		task.wait(GameConfig.EventFirstDelay)
		while true do
			local event = EVENTS[rng:NextInteger(1, #EVENTS)]
			local ok, err = pcall(event.run :: any)
			if not ok then
				warn("[EventDirector] event " .. event.id .. " failed: " .. tostring(err))
			end
			task.wait(rng:NextNumber(GameConfig.EventMinInterval, GameConfig.EventMaxInterval))
		end
	end)
end

return EventDirector
