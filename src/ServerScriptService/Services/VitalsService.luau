--!strict
-- Health and energy, and the consequences of running out of either.
--
-- The game had neither. Punches were knockback, toys were a slow effect, and
-- sprinting was free and infinite -- so a fight had no arc and running away
-- had no cost. A health bar on the HUD would have been a decoration.
--
-- Now both are real and both are spent:
--
--   Health  drops when someone lands a punch or a toy on you. At zero you are
--           sent to the nurse: full health back, a handful of cash gone, and
--           a few seconds walking it off. Nobody dies in a school.
--   Energy  drains while you sprint and comes back while you do not. Empty
--           energy drops you out of a sprint, which is what makes a chase a
--           chase rather than two people holding a button.
--
-- Both are published as attributes so the HUD reads one source. Health lives
-- on the Humanoid, because that is where Roblox puts it and fighting it only
-- creates two numbers that disagree.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cliques = require(ReplicatedStorage.Config.Cliques)
local Signals = require(script.Parent.Parent.Signals)
local Remotes = require(ReplicatedStorage.Remotes)
local ActionAnim = require(script.Parent.ActionAnim)

local VitalsService = {}

local REGEN_DELAY = 7 -- seconds after the last hit before health comes back
local REGEN_RATE = 5 -- health per second
local KNOCKOUT_SECONDS = 5 -- how long you walk it off

-- the Regular role's baseline; every other role scales off these
local ENERGY_DRAIN = 15 -- per second while sprinting
local ENERGY_REGEN = 22 -- per second while not

local lastHit: { [Player]: number } = {}
local knockedOut: { [Player]: number } = {}
local infirmary = Vector3.new(0, 4, 100)

-- Where the nurse sends you. MapService hands this over once the school is up.
function VitalsService.SetInfirmary(position: Vector3)
	infirmary = position
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function knockOut(player: Player, from: Player?)
	if (knockedOut[player] or 0) > os.clock() then
		return
	end
	knockedOut[player] = os.clock() + KNOCKOUT_SECONDS

	local humanoid = humanoidOf(player)
	local character = player.Character
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	if character then
		character:PivotTo(CFrame.new(infirmary + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))))
	end

	-- a real cost, but never enough to wipe someone out
	local cash = player:GetAttribute("Cash")
	if typeof(cash) == "number" and cash > 0 then
		local fee = math.floor(math.min(cash * 0.06, 250))
		if fee > 0 then
			player:SetAttribute("Cash", cash - fee)
			Remotes.Get("Notify"):FireClient(player, ("🏥 Sent to the nurse. $%d for the ice pack."):format(fee), "warn")
		else
			Remotes.Get("Notify"):FireClient(player, "🏥 Sent to the nurse.", "warn")
		end
	else
		Remotes.Get("Notify"):FireClient(player, "🏥 Sent to the nurse.", "warn")
	end
	ActionAnim.KnockOut(character)
	Remotes.Get("ScreenFx"):FireClient(player, "shake", 1)
	if from then
		ActionAnim.Flex(from.Character)
		Remotes.Get("Notify"):FireClient(from, ("🥊 You knocked out %s."):format(player.DisplayName), "good")
	end
end

-- The one way anything in the game takes health off a player. `from`'s role
-- decides how hard it lands, so a Bully's punch and a Nerd's punch are not the
-- same punch.
function VitalsService.Damage(player: Player, amount: number, from: Player?)
	if from then
		-- no friendly fire inside a crew: you both said yes to it, and a
		-- brawl where your own side knocks you out is not a crew
		if from ~= player and from:GetAttribute("SquadId") ~= nil
			and from:GetAttribute("SquadId") == player:GetAttribute("SquadId") then
			return
		end
		amount *= Cliques.For(from).damageMult
	end
	-- your crew gets in the way: five percent off per student walking with you
	local guard = player:GetAttribute("EscortCount")
	if typeof(guard) == "number" and guard > 0 then
		amount *= 1 - math.min(guard, 5) * 0.05
	end
	if amount <= 0 or (knockedOut[player] or 0) > os.clock() then
		return
	end
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	lastHit[player] = os.clock()
	humanoid.Health = math.max(0, humanoid.Health - amount)
	Signals.Damaged:Fire(player, from)
	Remotes.Get("ScreenFx"):FireClient(player, "hurt", math.clamp(amount / 30, 0.3, 1))
	if humanoid.Health > 0 then
		ActionAnim.Hurt(player.Character)
	end
	if humanoid.Health <= 0 then
		knockOut(player, from)
	end
end

function VitalsService.IsKnockedOut(player: Player): boolean
	return (knockedOut[player] or 0) > os.clock()
end

function VitalsService.Energy(player: Player): number
	local value = player:GetAttribute("Energy")
	return typeof(value) == "number" and value or Cliques.For(player).energyMax
end

-- Apply the player's role to their body. Called on spawn and again whenever
-- the role changes, so re-sorting at the courtyard board takes effect without
-- waiting for a respawn.
function VitalsService.ApplyRole(player: Player)
	local role = Cliques.For(player)
	local energyMax = role.energyMax
	local previous = player:GetAttribute("EnergyMax")
	local energy = player:GetAttribute("Energy")
	player:SetAttribute("EnergyMax", energyMax)
	-- keep the same proportion full rather than refilling on a switch
	if typeof(previous) == "number" and previous > 0 and typeof(energy) == "number" then
		player:SetAttribute("Energy", math.clamp(energy / previous, 0, 1) * energyMax)
	else
		player:SetAttribute("Energy", energyMax)
	end
	player:SetAttribute("HealthMax", role.maxHealth)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local fraction = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		humanoid.MaxHealth = role.maxHealth
		humanoid.Health = math.clamp(fraction, 0, 1) * role.maxHealth
	end
end

local function setup(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local role = Cliques.For(player)
	humanoid.MaxHealth = role.maxHealth
	humanoid.Health = role.maxHealth
	player:SetAttribute("Energy", role.energyMax)
	player:SetAttribute("EnergyMax", role.energyMax)
	player:SetAttribute("HealthMax", role.maxHealth)
end

function VitalsService.Init(map: any?)
	if map and map.infirmary then
		infirmary = map.infirmary
	end
	local function join(player: Player)
		VitalsService.ApplyRole(player)
		if player.Character then
			setup(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			setup(player, character)
		end)
	end
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		knockedOut[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local humanoid = humanoidOf(player)
			if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
				if now - (lastHit[player] or 0) > REGEN_DELAY then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + REGEN_RATE * dt)
				end
			end

			local role = Cliques.For(player)
			local cap = role.energyMax
			local energy = math.min(VitalsService.Energy(player), cap)
			if player:GetAttribute("Sprinting") == true then
				energy -= ENERGY_DRAIN * role.energyDrainMult * dt
				if energy <= 0 then
					energy = 0
					-- out of breath: drop the sprint rather than letting it run
					-- on an empty bar
					player:SetAttribute("Sprinting", false)
					player:SetAttribute("Winded", true)
				end
			else
				energy = math.min(cap, energy + ENERGY_REGEN * dt)
				if player:GetAttribute("Winded") == true and energy >= cap * 0.25 then
					player:SetAttribute("Winded", false)
				end
			end
			player:SetAttribute("Energy", energy)
		end
	end)
end

return VitalsService
