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

local Remotes = require(ReplicatedStorage.Remotes)

local VitalsService = {}

local MAX_HEALTH = 100
local REGEN_DELAY = 7 -- seconds after the last hit before health comes back
local REGEN_RATE = 5 -- health per second
local KNOCKOUT_SECONDS = 5 -- how long you walk it off

local ENERGY_MAX = 100
local ENERGY_DRAIN = 15 -- per second while sprinting
local ENERGY_REGEN = 22 -- per second while not
local ENERGY_RESUME = 25 -- energy needed before you can sprint again

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
		humanoid.Health = MAX_HEALTH
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
	Remotes.Get("ScreenFx"):FireClient(player, "shake", 1)
	if from then
		Remotes.Get("Notify"):FireClient(from, ("🥊 You knocked out %s."):format(player.DisplayName), "good")
	end
end

-- The one way anything in the game takes health off a player.
function VitalsService.Damage(player: Player, amount: number, from: Player?)
	if amount <= 0 or (knockedOut[player] or 0) > os.clock() then
		return
	end
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	lastHit[player] = os.clock()
	humanoid.Health = math.max(0, humanoid.Health - amount)
	Remotes.Get("ScreenFx"):FireClient(player, "hurt", math.clamp(amount / 30, 0.3, 1))
	if humanoid.Health <= 0 then
		knockOut(player, from)
	end
end

function VitalsService.IsKnockedOut(player: Player): boolean
	return (knockedOut[player] or 0) > os.clock()
end

function VitalsService.Energy(player: Player): number
	local value = player:GetAttribute("Energy")
	return typeof(value) == "number" and value or ENERGY_MAX
end

local function setup(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	player:SetAttribute("Energy", ENERGY_MAX)
	player:SetAttribute("EnergyMax", ENERGY_MAX)
	player:SetAttribute("HealthMax", MAX_HEALTH)
end

function VitalsService.Init()
	local function join(player: Player)
		player:SetAttribute("Energy", ENERGY_MAX)
		player:SetAttribute("EnergyMax", ENERGY_MAX)
		player:SetAttribute("HealthMax", MAX_HEALTH)
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

			local energy = VitalsService.Energy(player)
			if player:GetAttribute("Sprinting") == true then
				energy -= ENERGY_DRAIN * dt
				if energy <= 0 then
					energy = 0
					-- out of breath: drop the sprint rather than letting it run
					-- on an empty bar
					player:SetAttribute("Sprinting", false)
					player:SetAttribute("Winded", true)
				end
			else
				energy = math.min(ENERGY_MAX, energy + ENERGY_REGEN * dt)
				if player:GetAttribute("Winded") == true and energy >= ENERGY_RESUME then
					player:SetAttribute("Winded", false)
				end
			end
			player:SetAttribute("Energy", energy)
		end
	end)
end

return VitalsService
