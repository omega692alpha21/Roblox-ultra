--!strict
-- The five reputations: Popular, Smart, Athletic, Creative, Troublemaker.
-- You're never locked in — everything you do slowly shifts how the school
-- sees you. Your dominant track becomes your title.

local DataService = require(script.Parent.DataService)
local Signals = require(script.Parent.Parent.Signals)

local ReputationService = {}

export type Track = "popular" | "smart" | "athletic" | "creative" | "troublemaker"

local TRACKS: { Track } = { "popular", "smart", "athletic", "creative", "troublemaker" }
local ATTR: { [string]: string } = {
	popular = "RepPopular",
	smart = "RepSmart",
	athletic = "RepAthletic",
	creative = "RepCreative",
	troublemaker = "RepTroublemaker",
}
local TITLES: { [string]: string } = {
	popular = "Popular",
	smart = "Smart",
	athletic = "Athletic",
	creative = "Creative",
	troublemaker = "Troublemaker",
}

-- level thresholds: level N needs 40*N^2 points (1600 for lv 5 mastery)
function ReputationService.LevelFor(points: number): number
	return math.floor(math.sqrt(math.max(points, 0) / 40))
end

local function refreshTitle(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local bestTrack: string? = nil
	local bestPoints = 0
	for _, track in TRACKS do
		local points = profile.rep[track] or 0
		if points > bestPoints then
			bestPoints = points
			bestTrack = track
		end
	end
	if bestTrack and bestPoints >= 40 then
		player:SetAttribute("RepTitle", TITLES[bestTrack] .. " Lv" .. ReputationService.LevelFor(bestPoints))
	else
		player:SetAttribute("RepTitle", "New Kid")
	end
end

function ReputationService.Add(player: Player, track: Track, amount: number)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.rep[track] = (profile.rep[track] or 0) + amount
	player:SetAttribute(ATTR[track], profile.rep[track])
	refreshTitle(player)
end

function ReputationService.Init()
	Signals.QuizWon:Connect(function(player)
		ReputationService.Add(player, "smart", 6)
	end)
	Signals.Stole:Connect(function(thief)
		ReputationService.Add(thief, "troublemaker", 5)
	end)
	Signals.CaughtStealing:Connect(function(thief)
		ReputationService.Add(thief, "troublemaker", 1) -- infamy either way
	end)
	Signals.ThiefHit:Connect(function(puncher)
		ReputationService.Add(puncher, "athletic", 4)
	end)
	Signals.RivalFoiled:Connect(function(puncher)
		ReputationService.Add(puncher, "athletic", 3)
	end)
	Signals.Recruited:Connect(function(player)
		ReputationService.Add(player, "popular", 2)
	end)
	Signals.Fused:Connect(function(player)
		ReputationService.Add(player, "creative", 8) -- crafted a star student
	end)
	Signals.EventScore:Connect(function(player)
		ReputationService.Add(player, "popular", 3) -- showed up for the server event
	end)
	Signals.ProfileLoaded:Connect(function(player, profile)
		for _, track in TRACKS do
			player:SetAttribute(ATTR[track], profile.rep[track] or 0)
		end
		refreshTitle(player)
	end)
end

return ReputationService
