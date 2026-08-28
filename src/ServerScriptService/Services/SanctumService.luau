--!strict
-- The bookshelf in the principal's office, and what is behind it.
--
-- Anyone can walk up to the shelf and pull a book. Only the principal gets a
-- keypad; everyone else is told it is a bookshelf, which it is. The code is a
-- constant in this file and never leaves the server -- the client sends four
-- characters and is told yes or no, so there is nothing to read out of the
-- place file or off the wire.
--
-- Opening it swings the shelf aside for a few seconds and then closes it
-- again, so the passage is not left standing open behind you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local SanctumMap = require(script.Parent.SanctumMap)
local Signals = require(script.Parent.Parent.Signals)

local SanctumService = {}

local PIN = "0713"
local OPEN_SECONDS = 8

local shelf: BasePart? = nil
local closedCFrame: CFrame? = nil
local openUntil = 0
local attempts: { [Player]: number } = {}

local function isPrincipal(player: Player): boolean
	return player.UserId == GameConfig.OwnerUserId
end

local function close()
	local door = shelf
	local home = closedCFrame
	if not door or not home then
		return
	end
	TweenService:Create(door, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		CFrame = home,
	}):Play()
	task.delay(0.85, function()
		if shelf and openUntil <= os.clock() then
			shelf.CanCollide = true
		end
	end)
end

local function open(player: Player)
	local door = shelf
	local home = closedCFrame
	if not door or not home then
		return
	end
	openUntil = os.clock() + OPEN_SECONDS
	door.CanCollide = false
	-- slides back into the wall and along it, the way a real one would
	TweenService:Create(door, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = home * CFrame.new(0, 0, -15),
	}):Play()
	Remotes.Get("Notify"):FireClient(player, "The shelf swings aside. Mind the steps.", "aura")
	task.delay(OPEN_SECONDS, function()
		if openUntil <= os.clock() then
			close()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Getting around down there.
--
-- The estate came from a game that sold membership: the pyramid's doors were
-- shut until you bought a seat, and each chamber was reached through a gate
-- that checked your tier and moved you up. None of that came across -- the
-- module opens every gate, because here the lock is the bookshelf and the four
-- digits -- but the doors themselves were still solid and the chambers still
-- had no stairs between them. So the reward at the bottom of a hundred and ten
-- steps was a sealed pyramid: you could walk round the boulevard and look at
-- it. This wires the movement back up.
-- A pad you stand on that puts you somewhere else. Used for both directions:
-- a gate carries you up into the next chamber, a descent pad drops you back.
local function linkPad(pad: BasePart, destination: Vector3, label: string)
	local recent: { [Player]: number } = {}
	pad.CanCollide = false
	pad.CanTouch = true
	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or not character then
			return
		end
		local now = os.clock()
		-- both ends of a link are pads, so without this you arrive on one and
		-- are sent straight back
		if (recent[player] or 0) > now then
			return
		end
		recent[player] = now + 1.5
		character:PivotTo(CFrame.new(destination))
		Remotes.Get("Notify"):FireClient(player, label, "aura")
	end)
	Players.PlayerRemoving:Connect(function(player)
		recent[player] = nil
	end)
end

local function wireEstate(estate: SanctumMap.Map)
	-- up: each gate stands at the near wall of a chamber and lands you in the
	-- next one. The gates are already non-collidable, so this is a step
	-- through a doorway rather than a wall you press against.
	for _, gate in estate.gates do
		linkPad(gate.door, gate.landing, "▲ " .. gate.tier)
	end
	-- down: the pad on the far side of each chamber floor
	local floors = { estate.hallPoint }
	for _, gate in estate.gates do
		table.insert(floors, gate.landing)
	end
	for index, pad in estate.descents do
		local below = floors[index]
		if below then
			linkPad(pad, below, "▼ down")
		end
	end
end

function SanctumService.Init(map: { secretDoor: BasePart? })
	-- the estate itself, built once and left alone
	task.spawn(function()
		local ok, result = pcall(SanctumMap.Build)
		if not ok then
			warn("[SanctumService] the estate failed to build: " .. tostring(result))
			return
		end
		local wired = pcall(wireEstate, result :: any)
		if not wired then
			warn("[SanctumService] the estate built but could not be wired")
		end
	end)

	shelf = map.secretDoor
	local door = shelf
	if not door then
		return
	end
	closedCFrame = door.CFrame

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pull a book"
	prompt.ObjectText = "Bookshelf"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = door

	prompt.Triggered:Connect(function(player)
		-- everyone who pulls a book has found the door, which is the last
		-- objective of the story's final chapter. Only the principal gets past
		-- it; knowing it is there is the ending for everyone else.
		Signals.FoundTheDoor:Fire(player)
		if not isPrincipal(player) then
			Remotes.Get("Notify"):FireClient(player, "Dust, and a copy of the school rules. Nothing else.", "info")
			return
		end
		if openUntil > os.clock() then
			open(player)
			return
		end
		Remotes.Get("SecretKeypad"):FireClient(player)
	end)

	Remotes.Get("SecretPin").OnServerEvent:Connect(function(player, code)
		if not isPrincipal(player) or typeof(code) ~= "string" then
			return
		end
		-- a slow lock: five tries a minute is plenty for four digits you know
		local now = os.clock()
		if now - (attempts[player] or 0) < 1.2 then
			return
		end
		attempts[player] = now
		if code == PIN then
			open(player)
		else
			Remotes.Get("Notify"):FireClient(player, "Nothing happens.", "bad")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		attempts[player] = nil
	end)
end

return SanctumService
