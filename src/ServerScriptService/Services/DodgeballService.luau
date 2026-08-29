--!strict
-- Dodgeball: during the tournament event, balls spawn in the Gym. Grab one,
-- then your punch key THROWS it — hits knock players flying and pay out
-- cash + Athletic reputation. Server-authoritative throws.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
local EconomyService = require(script.Parent.EconomyService)
local EffectsService = require(script.Parent.EffectsService)
local ReputationService = require(script.Parent.ReputationService)
local Signals = require(script.Parent.Parent.Signals)

local DodgeballService = {}

-- The gym is its own building now, at CampusPlan's Gymnasium rect
-- (330, 340)-(520, 470). This is the Sports hall cell's centre.
local GYM = Vector3.new(425, 0, 437)
local HIT_CASH = 120
local THROW_SPEED = 95

local rng = Random.new()
local activeUntil = 0
local held: { [Player]: BasePart } = {}
local pickups: { BasePart } = {}

local function isActive(): boolean
	return os.clock() < activeUntil
end

local function makeBall(anchored: boolean): Part
	local ball = Instance.new("Part")
	ball.Name = "Dodgeball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2.4, 2.4, 2.4)
	ball.Color = Color3.fromRGB(214, 52, 46)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = anchored
	ball.CanCollide = false
	return ball
end

local function spawnPickup()
	local ball = makeBall(true)
	ball.Position = GYM + Vector3.new(rng:NextNumber(-28, 28), 2.2, rng:NextNumber(-28, 28))
	ball.Parent = workspace
	table.insert(pickups, ball)

	local taken = false
	ball.Touched:Connect(function(hit)
		if taken or not isActive() then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character :: any)
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not player or not root or held[player] then
			return
		end
		taken = true
		ball:Destroy()
		-- held ball floats at the player's shoulder
		local carry = makeBall(false)
		carry.Massless = true
		carry.CFrame = root.CFrame * CFrame.new(1.6, 1.2, 0)
		carry.Parent = character
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = carry
		weld.Part1 = root
		weld.Parent = carry
		held[player] = carry
		player:SetAttribute("HasBall", true)
		Remotes.Get("Notify"):FireClient(player, "You've got a dodgeball! Press PUNCH to throw it!", "good")
	end)
end

-- Called by FightService before a normal punch: true = the input was a throw.
function DodgeballService.TryThrow(player: Player): boolean
	local carry = held[player]
	if not carry then
		return false
	end
	held[player] = nil
	player:SetAttribute("HasBall", nil)
	carry:Destroy()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return true
	end
	local direction = root.CFrame.LookVector
	local ball = makeBall(false)
	ball.CanCollide = true
	ball.CFrame = root.CFrame * CFrame.new(0, 1.5, -3)
	ball.AssemblyLinearVelocity = direction * THROW_SPEED + Vector3.new(0, 14, 0)
	ball.Parent = workspace

	local hitSomeone = false
	ball.Touched:Connect(function(hit)
		if hitSomeone then
			return
		end
		local victimCharacter = hit.Parent
		local victim = victimCharacter and Players:GetPlayerFromCharacter(victimCharacter :: any)
		if not victim or victim == player then
			return
		end
		local victimRoot = victimCharacter and victimCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not victimRoot then
			return
		end
		hitSomeone = true
		victimRoot.AssemblyLinearVelocity = direction * 55 + Vector3.new(0, 30, 0)
		EconomyService.AddCash(player, HIT_CASH, true)
		EffectsService.CashPopup(victimRoot.Position, HIT_CASH)
		ReputationService.Add(player, "athletic", 5)
		Signals.EventScore:Fire(player, "dodgeball")
		Remotes.Get("ScreenFx"):FireClient(victim, "shake", 1.4)
		Remotes.Get("ScreenFx"):FireClient(player, "shake", 0.5)
		Remotes.Get("Notify"):FireClient(player, "DIRECT HIT! +$" .. HIT_CASH, "good")
		Remotes.Get("Notify"):FireClient(victim, player.DisplayName .. " smoked you with a dodgeball!", "bad")
		ball:Destroy()
	end)
	task.delay(3, function()
		if ball.Parent then
			ball:Destroy()
		end
	end)
	return true
end

function DodgeballService.StartRound(duration: number)
	activeUntil = os.clock() + duration
	for _ = 1, 7 do
		spawnPickup()
	end
	task.delay(duration, function()
		for _, pickup in pickups do
			if pickup.Parent then
				pickup:Destroy()
			end
		end
		pickups = {}
		for player, carry in held do
			carry:Destroy()
			player:SetAttribute("HasBall", nil)
			held[player] = nil
		end
	end)
end

function DodgeballService.Init()
	Players.PlayerRemoving:Connect(function(player)
		held[player] = nil
	end)
end

return DodgeballService
