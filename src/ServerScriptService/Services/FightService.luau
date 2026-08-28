--!strict
-- Punches: server-validated cooldown, range and cone.
--
-- This did not work, and the reason is worth writing down. It only ever looked
-- for other PLAYERS. In a school with twenty students walking the corridor and
-- a crew sitting in every homeroom, the overwhelmingly common case is swinging
-- at an NPC -- and the swing played, and nothing happened, so the mechanic
-- read as broken. It hits anything with a Humanoid now.
--
-- NPCs cannot be queried spatially: StudentGen turns CanQuery off on every
-- limb, because thousands of queryable parts is what made the game stutter.
-- So the search walks the models in the workspace instead, which is a few
-- dozen at a punch every 0.35 seconds and costs nothing.
--
-- Punching an NPC pays nothing. It knocks them flat, they get up, and that is
-- the whole reward -- otherwise the corridor becomes an aura farm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Cliques = require(ReplicatedStorage.Config.Cliques)
local Remotes = require(ReplicatedStorage.Remotes)
local StealService = require(script.Parent.StealService)
local RivalService = require(script.Parent.RivalService)
local DodgeballService = require(script.Parent.DodgeballService)
local ActionAnim = require(script.Parent.ActionAnim)
local EffectsService = require(script.Parent.EffectsService)
local VitalsService = require(script.Parent.VitalsService)
local Signals = require(script.Parent.Parent.Signals)

local FightService = {}

local lastPunch: { [Player]: number } = {}

type Target = {
	root: BasePart,
	humanoid: Humanoid?,
	model: Model,
	player: Player?,
}

local function onPunch(player: Player)
	local now = os.clock()
	if now - (lastPunch[player] or 0) < GameConfig.PunchCooldownSeconds then
		return
	end
	lastPunch[player] = now

	if VitalsService.IsKnockedOut(player) then
		return
	end

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
	EffectsService.PlaySound(root, "Punch")

	-- best thing in front of us: mostly facing, partly close
	local best: Target? = nil
	local bestScore = -math.huge
	for _, candidate in targetsNear(character :: Model, root) do
		local offset = candidate.root.Position - root.Position
		local distance = offset.Magnitude
		if distance < 0.01 then
			continue
		end
		local facing = root.CFrame.LookVector:Dot(offset.Unit)
		if facing < 0 then
			continue -- behind you
		end
		local score = facing * 2 - distance / GameConfig.PunchRange
		if score > bestScore then
			bestScore = score
			best = candidate
		end
	end

	if not best then
		-- no player and no student: Rico is the last thing worth checking
		local ricoRoot = RivalService.GetRoot()
		if ricoRoot then
			local offset = ricoRoot.Position - root.Position
			if offset.Magnitude <= GameConfig.PunchRange and root.CFrame.LookVector:Dot(offset.Unit) > 0 then
				RivalService.OnPunched(player)
			end
		end
		return
	end
	local target = best :: Target

	local knockback = GameConfig.PunchKnockback
	local role = Cliques.For(player)
	knockback *= role.knockbackMult

	local direction = (target.root.Position - root.Position).Unit
	local impact = target.root.Position + direction * -1.2 + Vector3.new(0, 0.6, 0)
	EffectsService.Hit(impact, Color3.fromRGB(255, 214, 120), "PunchHit", 18)

	Signals.Punched:Fire(player, target.model)
	if target.player then
		local hit = target.player :: Player
		target.root.AssemblyLinearVelocity = direction * knockback + Vector3.new(0, knockback * 0.5, 0)
		Remotes.Get("ScreenFx"):FireClient(player, "shake", 0.55)
		local before = target.humanoid and target.humanoid.Health or 0
		VitalsService.Damage(hit, GameConfig.PunchDamage, player)
		local after = target.humanoid and target.humanoid.Health or 0
		Remotes.Get("HitMarker"):FireClient(player, impact, math.max(1, math.floor(before - after + 0.5)), after <= 0)
		if StealService.IsCarrying(hit) then
			Signals.ThiefHit:Fire(player, hit)
			StealService.OnThiefPunched(hit, player)
		end
	else
		-- a student: they go over, they get up, nobody gets paid
		ActionAnim.KnockDown(target.model, root.Position)
		Remotes.Get("HitMarker"):FireClient(player, impact, 0, false)
	end
end

function FightService.Init()
	Remotes.Get("Punch").OnServerEvent:Connect(onPunch)
	Players.PlayerRemoving:Connect(function(player)
		lastPunch[player] = nil
	end)
end

return FightService
