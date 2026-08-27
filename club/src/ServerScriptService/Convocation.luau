--!strict
-- Every twenty minutes the altar flares and the hall gathers. Sit for the full
-- minute and you gain standing. One attendee leaves with a fragment of lore
-- that means nothing until someone else tells you theirs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
local Rep = require(script.Parent.Rep)

local Convocation = {}

local FRAGMENTS = {
	"the first hall was not built. it was found.",
	"nine flames. one for each of them.",
	"the painting is a door that forgot how to open.",
	"we do not keep names. names keep us.",
	"the twelfth chair has an occupant. you are not to look at it.",
	"whatever is under the floor was here first.",
	"the code changes because the lock is listening.",
	"the roof is not the top.",
	"count again. you counted what you were shown.",
	"one of us has never left this room.",
}

local held: { [number]: { string } } = {}

local function seatedInCircle(chairs: { Seat }): { Player }
	local out: { Player } = {}
	for _, seat in chairs do
		local occupant = seat.Occupant
		local character = occupant and occupant.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			table.insert(out, player)
		end
	end
	return out
end

function Convocation.Init(map: any)
	local altarFlame = map.folder:FindFirstChild("AltarFlame") :: BasePart?

	Remotes.GetFunction("GetFragments").OnServerInvoke = function(player: Player): any
		return held[player.UserId] or {}
	end

	Players.PlayerRemoving:Connect(function(player)
		held[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.ConvocationPeriod)

			Remotes.Get("Convocation"):FireAllClients("call", Config.ConvocationDuration)
			Remotes.Get("Notify"):FireAllClients("The altar flares. Take a chair.", "announce")
			local original = altarFlame and altarFlame.Size or nil
			if altarFlame and original then
				altarFlame.Size = original * 2.2
			end

			-- attendance is measured across the whole minute, not sampled once:
			-- you have to actually sit through it
			local attendance: { [number]: number } = {}
			local ticks = Config.ConvocationDuration // 5
			for _ = 1, ticks do
				task.wait(5)
				for _, player in seatedInCircle(map.chairs) do
					attendance[player.UserId] = (attendance[player.UserId] or 0) + 1
				end
			end

			if altarFlame and original then
				altarFlame.Size = original
			end

			local attended: { Player } = {}
			for _, player in Players:GetPlayers() do
				if (attendance[player.UserId] or 0) >= ticks - 1 then
					table.insert(attended, player)
					Rep.Award(player, Config.Rep.Convocation, "convocation")
				end
			end

			if #attended > 0 then
				local rng = Random.new(os.time())
				local chosen = attended[rng:NextInteger(1, #attended)]
				local text = FRAGMENTS[rng:NextInteger(1, #FRAGMENTS)]
				held[chosen.UserId] = held[chosen.UserId] or {}
				local list = held[chosen.UserId]
				local seen = false
				for _, existing in list do
					if existing == text then
						seen = true
					end
				end
				if not seen then
					table.insert(list, text)
				end
				Remotes.Get("Fragment"):FireClient(chosen, text)
				Remotes.Get("Notify"):FireAllClients("One of you was given something. It was not written down.", "announce")
			end
			Remotes.Get("Convocation"):FireAllClients("over", 0)
		end
	end)
end

return Convocation
