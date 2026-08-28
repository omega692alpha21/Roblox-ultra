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

-- The chain. A jab on its own is a poke; three beats with different shapes is
-- a fight. Keep the rhythm -- another swing within COMBO_WINDOW of the last --
-- and you move up the chain, hit harder, and knock further. Miss the window
-- and you are back to a jab.
local COMBO_WINDOW = 1.15
local CHAIN: { { kind: string, damage: number, knock: number } } = {
	{ kind = "punch", damage = 1.0, knock = 1.0 },
	{ kind = "cross", damage = 1.2, knock = 1.15 },
	{ kind = "kick", damage = 1.6, knock = 1.6 },
}
local comboStep: { [Player]: number } = {}

-- Which beat this swing is. Shared with the client, which runs the same rule
-- so it can play the right pose the instant the button goes down instead of
-- waiting a round trip to be told which one it was.
function FightService.StepFor(player: Player, now: number): number
	local since = now - (lastPunch[player] or -math.huge)
	local step = if since <= COMBO_WINDOW then (comboStep[player] or 0) % #CHAIN + 1 else 1
	return step
end

FightService.ComboWindow = COMBO_WINDOW
FightService.ChainLength = #CHAIN

type Target = {
	root: BasePart,
	humanoid: Humanoid?,
	model: Model,
	player: Player?,
}

local EMPTY_TARGETS: { Target } = {}

-- Everything within range that can be hit.
--
-- Deliberately not a spatial query. StudentGen sets CanQuery = false on every
-- NPC limb (thousands of queryable parts is what made the game stutter), so
-- GetPartBoundsInRadius returns players and scenery and never a single
-- student -- which is exactly the bug this replaced. Walking the workspace's
-- direct children is a few dozen models, once per 0.35s punch.
local function targetsNear(self: Model, root: BasePart): { Target }
	local found: { Target } = {}
	local range = GameConfig.PunchRange

	-- players first, by name, so a knocked-out or unloaded one is skipped
	local byCharacter: { [Model]: Player } = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			byCharacter[character] = other
		end
	end

	for _, model in workspace:GetChildren() do
		if not model:IsA("Model") or model == self then
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end
		local otherRoot = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if not otherRoot then
			continue
		end
		if (otherRoot.Position - root.Position).Magnitude > range then
			continue
		end
		local owner = byCharacter[model]
		if owner and VitalsService.IsKnockedOut(owner) then
			continue -- already at the nurse
		end
		table.insert(found, {
			root = otherRoot,
			humanoid = humanoid,
			model = model,
			player = owner,
		})
	end

	-- crews and escorts are parented into folders, not straight into the
	-- workspace, so one level down is where most students actually live
	for _, folder in workspace:GetChildren() do
		if not folder:IsA("Folder") and not folder:IsA("Model") then
			continue
		end
		if folder:IsA("Model") and folder:FindFirstChildOfClass("Humanoid") then
			continue -- already counted above
		end
		for _, model in folder:GetChildren() do
			if not model:IsA("Model") or model == self then
				continue
			end
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				continue
			end
			local otherRoot = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
			if not otherRoot or (otherRoot.Position - root.Position).Magnitude > range then
				continue
			end
			local owner = byCharacter[model]
			if owner and VitalsService.IsKnockedOut(owner) then
				continue
			end
			table.insert(found, {
				root = otherRoot,
				humanoid = humanoid,
				model = model,
				player = owner,
			})
		end
	end

	return #found > 0 and found or EMPTY_TARGETS
end

local function onPunch(player: Player)
	local now = os.clock()
	if now - (lastPunch[player] or 0) < GameConfig.PunchCooldownSeconds then
		return
	end
	local step = FightService.StepFor(player, now)
	comboStep[player] = step
	lastPunch[player] = now
	local beat = CHAIN[step]

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
	ActionAnim.Play(character, beat.kind)
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
	knockback *= role.knockbackMult * beat.knock

	local direction = (target.root.Position - root.Position).Unit
	local impact = target.root.Position + direction * -1.2 + Vector3.new(0, 0.6, 0)
	EffectsService.Hit(impact, Color3.fromRGB(255, 214, 120), "PunchHit", 18)

	Signals.Punched:Fire(player, target.model)
	if target.player then
		local hit = target.player :: Player
		target.root.AssemblyLinearVelocity = direction * knockback + Vector3.new(0, knockback * 0.5, 0)
		Remotes.Get("ScreenFx"):FireClient(player, "shake", 0.55)
		local before = target.humanoid and target.humanoid.Health or 0
		VitalsService.Damage(hit, GameConfig.PunchDamage * beat.damage, player)
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
		comboStep[player] = nil
	end)
end

return FightService
