--!strict
-- The doors that don't open. Each one names a rank, and each refusal is the
-- whole hook: you can see it, everyone can see it, and you can't go through.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
	-- the pyramid's heart is for MEMBERS — 100 REP and 50 hours served
	local memberGate = map.memberGate :: BasePart?
	if memberGate then
		local closed = memberGate.CFrame
		local opening = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Enter"
		prompt.ObjectText = ""
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = memberGate
		prompt.Triggered:Connect(function(player)
			if Rep.RankIndexOf(player) >= 2 then
				if not opening then
					opening = true
					TweenService:Create(memberGate, TweenInfo.new(1.6, Enum.EasingStyle.Quint), {
						CFrame = closed * CFrame.new(0, -11.4, 0),
					}):Play()
					task.delay(8, function()
						TweenService:Create(memberGate, TweenInfo.new(1.2), { CFrame = closed }):Play()
						task.wait(1.2)
						opening = false
					end)
				end
			else
				local member = Config.Ranks[2]
				local rep = tonumber(player:GetAttribute("Rep")) or 0
				local hours = tonumber(player:GetAttribute("Hours")) or 0
				Remotes.Get("Notify"):FireClient(player, "The heart of the pyramid is for MEMBERS.", "bad")
				Remotes.Get("Notify"):FireClient(
					player,
					("%d/%d REP · %.1f/%d hours served. Time away counts half."):format(rep, member.rep, hours, member.hours),
					"whisper"
				)
			end
		end)
	end

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
