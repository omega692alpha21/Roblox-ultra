--!strict
-- The doors that don't open. Each one names a rank, and each refusal is the
-- whole hook: you can see it, everyone can see it, and you can't go through.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
local Rep = require(script.Parent.Rep)

local Gates = {}

local REFUSALS = {
	"It does not know you.",
	"The handle is cold and does not turn.",
	"Something on the other side stops moving, then starts again.",
	"Not yet.",
}

function Gates.Init(map: any)
	for _, gate in map.gates do
		local needed = Config.RankIndex(gate.rank)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Try it"
		prompt.ObjectText = ""
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = gate.door

		prompt.Triggered:Connect(function(player)
			if not Rep.IsInitiated(player) then
				return
			end
			if Rep.RankIndexOf(player) >= needed then
				-- the rooms behind these are the next build; the door admits
				-- you and says so rather than pretending nothing is there
				Remotes.Get("Notify"):FireClient(
					player,
					("It opens for %s. There is nothing behind it yet — but it opened."):format(gate.rank),
					"good"
				)
			else
				local rng = Random.new(os.clock() * 1e5)
				Remotes.Get("Notify"):FireClient(player, REFUSALS[rng:NextInteger(1, #REFUSALS)], "bad")
				local rank = Config.Ranks[needed]
				if rank then
					Remotes.Get("Notify"):FireClient(player, ("%d REP."):format(rank.rep), "whisper")
				end
			end
		end)
	end
end

return Gates
