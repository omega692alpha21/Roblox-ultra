--!strict
-- The doors of the pyramid. Every refusal is a sales pitch: you can see the
-- chamber above, everyone can see you not entering it, and the door itself
-- offers to sell you the way through.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
local Membership = require(script.Parent.Membership)

local Gates = {}

-- with StreamingEnabled, pre-stream the destination so nobody falls through
-- an unloaded floor on teleport
local function warpTo(player: Player, target: Vector3)
	local character = player.Character
	if not character then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(target, 2)
	end)
	if player.Character == character then
		character:PivotTo(CFrame.new(target))
	end
end

local function fmt(n: number): string
	local s = tostring(n)
	local out = ""
	local count = 0
	for i = #s, 1, -1 do
		out = s:sub(i, i) .. out
		count += 1
		if count % 3 == 0 and i > 1 then
			out = "," .. out
		end
	end
	return out
end

function Gates.Init(map: any)
	-- the grand doors at the pyramid entrance: members through, guests pitched
	local doorGate = map.memberGate :: BasePart?
	if doorGate then
		local closedL = (map.doorL :: BasePart).CFrame
		local closedR = (map.doorR :: BasePart).CFrame
		local opening = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Enter"
		prompt.ObjectText = "MILLIONS CLUB"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = doorGate
		prompt.Triggered:Connect(function(player)
			if Membership.IsMember(player) then
				if not opening then
					opening = true
					TweenService:Create(map.doorL :: BasePart, TweenInfo.new(1.4, Enum.EasingStyle.Quint), { CFrame = closedL * CFrame.new(-5.6, 0, 0) }):Play()
					TweenService:Create(map.doorR :: BasePart, TweenInfo.new(1.4, Enum.EasingStyle.Quint), { CFrame = closedR * CFrame.new(5.6, 0, 0) }):Play()
					task.delay(7, function()
						TweenService:Create(map.doorL :: BasePart, TweenInfo.new(1.1), { CFrame = closedL }):Play()
						TweenService:Create(map.doorR :: BasePart, TweenInfo.new(1.1), { CFrame = closedR }):Play()
						task.wait(1.1)
						opening = false
					end)
				end
				task.delay(1.5, function()
					warpTo(player, map.hallPoint)
				end)
			else
				local price = tonumber(ReplicatedStorage:GetAttribute("SeatPrice")) or 0
				Remotes.Get("Notify"):FireClient(player, "Members only.", "bad")
				if price > 0 then
					Remotes.Get("Notify"):FireClient(player, ("Seat № %d costs %s R$."):format(
						(tonumber(ReplicatedStorage:GetAttribute("SeatCount")) or 0) + 1, fmt(price)
					), "info")
				end
				Membership.PromptJoin(player)
			end
		end)
	end

	-- chamber gates inside the pyramid: tier-keyed lifts
	for _, gate in map.gates do
		local tier = Config.TierByName(gate.tier)
		local needed = Config.TierIndex(gate.tier)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Ascend"
		prompt.ObjectText = gate.tier
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = gate.door

		prompt.Triggered:Connect(function(player)
			if Membership.TierIndexOf(player) >= needed then
				warpTo(player, gate.landing)
				Remotes.Get("Notify"):FireClient(player, ("Welcome to the %s chamber."):format(gate.tier), "good")
			else
				Remotes.Get("Notify"):FireClient(player, ("This chamber is for %s."):format(gate.tier), "bad")
				if tier and tier.price > 0 then
					Remotes.Get("Notify"):FireClient(player, ("%s — %s R$."):format(gate.tier, fmt(tier.price)), "info")
				end
				Membership.PromptTier(player, gate.tier)
			end
		end)
	end

	-- descent pads in each chamber bring you back to the Grand Hall
	for _, pad in map.descents do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Descend"
		prompt.ObjectText = "Grand Hall"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		prompt.Triggered:Connect(function(player)
			warpTo(player, map.hallPoint)
		end)
	end
end

return Gates
