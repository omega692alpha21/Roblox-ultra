--!strict
-- Dormitories: nap on a bed for a luck buff. Per-player cooldown so it's a
-- ritual between hallway runs, not a permanent camp spot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)

local DormService = {}

local NAP_LUCK_MULT = 1.25
local NAP_BUFF_SECONDS = 90
local NAP_COOLDOWN_SECONDS = 300

local lastNap: { [Player]: number } = {}

local function onNap(player: Player)
	local now = os.clock()
	local last = lastNap[player] or -math.huge
	if now - last < NAP_COOLDOWN_SECONDS then
		local wait = math.ceil(NAP_COOLDOWN_SECONDS - (now - last))
		Remotes.Get("Notify"):FireClient(player, ("You're not sleepy yet — nap again in %ds."):format(wait), "info")
		return
	end
	lastNap[player] = now
	local currentUntil = player:GetAttribute("LuckUntil")
	local base = typeof(currentUntil) == "number" and math.max(currentUntil, now) or now
	player:SetAttribute("LuckMult", NAP_LUCK_MULT)
	player:SetAttribute("LuckUntil", base + NAP_BUFF_SECONDS)
	Remotes.Get("Notify"):FireClient(
		player,
		("Power nap! %.2fx luck for %ds — go recruit somebody special."):format(NAP_LUCK_MULT, NAP_BUFF_SECONDS),
		"good"
	)
end

function DormService.Init(map: { dormBeds: { BasePart } })
	for _, bed in map.dormBeds do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take a Nap"
		prompt.ObjectText = "Dorm Bed — luck boost"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = bed
		prompt.Triggered:Connect(onNap)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastNap[player] = nil
	end)
end

return DormService
