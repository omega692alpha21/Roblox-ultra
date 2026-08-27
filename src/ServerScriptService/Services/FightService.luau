--!strict
-- Punches: knockback only (no health damage), server-validated cooldown + range.
-- Primary purpose is catching thieves; the Gym is the free-for-all flex zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Cliques = require(ReplicatedStorage.Config.Cliques)
local Remotes = require(ReplicatedStorage.Remotes)
local StealService = require(script.Parent.StealService)
local RivalService = require(script.Parent.RivalService)
local DodgeballService = require(script.Parent.DodgeballService)
local ActionAnim = require(script.Parent.ActionAnim)
local Signals = require(script.Parent.Parent.Signals)

local FightService = {}

local lastPunch: { [Player]: number } = {}

local function onPunch(player: Player)
	local now = os.clock()
	if now - (lastPunch[player] or 0) < GameConfig.PunchCooldownSeconds then
		return
	end
	lastPunch[player] = now

	-- holding a dodgeball? the punch input throws it instead
	if DodgeballService.TryThrow(player) then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not character then
		return
	end
	-- swing on every punch, hit or miss: a punch that connects invisibly is
	-- what made the action read as broken
	ActionAnim.Punch(character)

	-- find the closest other character within range, biased to who we're facing
	local bestTarget: Player? = nil
	local bestScore = -math.huge
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not otherRoot then
			continue
		end
		local offset = otherRoot.Position - root.Position
		local distance = offset.Magnitude
		if distance > GameConfig.PunchRange then
			continue
		end
		local facing = root.CFrame.LookVector:Dot(offset.Unit)
		if facing < 0.2 then
			continue
		end
		local score = facing - distance / GameConfig.PunchRange
		if score > bestScore then
			bestScore = score
			bestTarget = other
		end
	end

	if not bestTarget then
		-- no player in range: check Rico the Bully
		local ricoRoot = RivalService.GetRoot()
		if ricoRoot then
			local offset = ricoRoot.Position - root.Position
			if offset.Magnitude <= GameConfig.PunchRange and root.CFrame.LookVector:Dot(offset.Unit) > 0.2 then
				RivalService.OnPunched(player)
			end
		end
		return
	end
	local target = bestTarget :: Player
	local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	local knockback = GameConfig.PunchKnockback
	local cliqueId = player:GetAttribute("Clique")
	local clique = typeof(cliqueId) == "string" and Cliques.Get(cliqueId) or nil
	if clique then
		knockback *= clique.knockbackMult
	end

	local direction = (targetRoot.Position - root.Position).Unit
	targetRoot.AssemblyLinearVelocity = direction * knockback + Vector3.new(0, knockback * 0.5, 0)
	Remotes.Get("ScreenFx"):FireClient(target, "shake", 1.1)
	Remotes.Get("ScreenFx"):FireClient(player, "shake", 0.45)

	if StealService.IsCarrying(target) then
		Signals.ThiefHit:Fire(player, target)
		StealService.OnThiefPunched(target, player)
	end
end

function FightService.Init()
	Remotes.Get("Punch").OnServerEvent:Connect(onPunch)
	Players.PlayerRemoving:Connect(function(player)
		lastPunch[player] = nil
	end)
end

return FightService
