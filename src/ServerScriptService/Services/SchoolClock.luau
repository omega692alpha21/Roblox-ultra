--!strict
-- The school-day cycle: Free Period -> Class Time (pop quiz) -> Free Period ->
-- Lunch Rush (boosted income) -> repeat. The current period + end time are
-- published as ReplicatedStorage attributes for the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
local ClassService = require(script.Parent.ClassService)
local CurfewService = require(script.Parent.CurfewService)
local EconomyService = require(script.Parent.EconomyService)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local SchoolClock = {}

type Period = {
	name: string,
	duration: number,
	incomeMult: number?,
	onStart: (() -> ())?,
	announce: string?,
	kind: string?,
}

local PERIODS: { Period } = {
	{ name = "Free Period", duration = 210 },
	{
		name = "Class Time",
		duration = 75,
		-- ClassService announces the bell itself
		onStart = function()
			ClassService.StartBell()
		end,
	},
	{ name = "Free Period", duration = 180 },
	{
		name = "Lunch Rush",
		duration = 120,
		incomeMult = 1.5,
		announce = "LUNCH RUSH! All crews earn 1.5x lunch money — cafeteria is popping!",
		kind = "announce",
	},
	{ name = "Free Period", duration = 150 },
	{
		name = "Lights Out",
		duration = GameConfig.CurfewNightSeconds,
		-- CurfewService announces, darkens the sky, and runs the aura/detention loop
		onStart = function()
			CurfewService.StartNight()
		end,
	},
}

function SchoolClock.Init()
	task.spawn(function()
		task.wait(20) -- let players settle in first
		while true do
			for _, period in PERIODS do
				ReplicatedStorage:SetAttribute("Period", period.name)
				ReplicatedStorage:SetAttribute("PeriodEndsAt", workspace:GetServerTimeNow() + period.duration)
				EconomyService.SetPeriodMult(period.incomeMult or 1)
				if period.announce then
					Remotes.Get("Notify"):FireAllClients(period.announce, period.kind or "info")
				end
				if period.onStart then
					period.onStart()
				end
				task.wait(period.duration)
				EconomyService.SetPeriodMult(1)
			end
		end
	end)
end

return SchoolClock
