--!strict
-- The bookshelf in the principal's office, and what is behind it.
--
-- Anyone can walk up to the shelf and pull a book. Only the principal gets a
-- keypad; everyone else is told it is a bookshelf, which it is. The code is a
-- constant in this file and never leaves the server -- the client sends four
-- characters and is told yes or no, so there is nothing to read out of the
-- place file or off the wire.
--
-- Opening it swings the shelf aside and then closes it again, so the passage
-- is not left standing open behind you -- but it will not close ON you, and it
-- will not close while you are still walking towards it. Eight seconds and a
-- blind re-collide is what "the door opens with the code but it is blocked, I
-- cannot get in" turns out to be: you type four digits on a phone, the keypad
-- dismisses, you take two steps, and an anchored fourteen-stud shelf becomes
-- solid again in the doorway you are standing in and shoves you back into the
-- reading room.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local SanctumMap = require(script.Parent.SanctumMap)
local Signals = require(script.Parent.Parent.Signals)

local SanctumService = {}

local PIN = "0713"
-- Long enough to type a code on a phone, put the keypad away, and walk ten
-- studs. It was eight, which is not.
local OPEN_SECONDS = 30
-- and it will not shut while somebody is standing this close to the doorway
local DOORWAY_RADIUS = 16

-- Two doors now: the headmaster's, in his office at the top of the staff
-- lodge, and the library's, behind the stacks on its west wall. Both open on
-- the same four digits, and opening either opens only itself.
-- A door is the backing slab AND every board and book on it, each remembered
-- at its offset from the slab, so the whole shelf moves as one object.
type Piece = { part: BasePart, rel: CFrame }
type Door = { shelf: BasePart, home: CFrame, pieces: { Piece }, openUntil: number }

-- It SWINGS, on the hinge at its own left edge, rather than sliding fifteen
-- studs backwards down the corridor. A slide put the slab in the middle of the
-- passage you were trying to walk down, which reads as a second door rather
-- than as an open one; a swing reads as what it is.
local SWING = CFrame.new(-7, 0, 0) * CFrame.Angles(0, math.rad(104), 0) * CFrame.new(7, 0, 0)

local doors: { Door } = {}
local attempts: { [Player]: number } = {}
-- which shelf they pulled, so the code opens that one and not the other
local pendingDoor: { [Player]: Door } = {}
-- who has already entered the code this session
local knowsCode: { [Player]: boolean } = {}

local function isPrincipal(player: Player): boolean
	return player.UserId == GameConfig.OwnerUserId
end

-- Is anybody standing in the doorway, or close enough to be walking into it?
local function occupied(door: Door): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - door.home.Position).Magnitude < DOORWAY_RADIUS then
			return true
		end
	end
	return false
end

-- Move the slab and everything on it, keeping their offsets. Tweened rather
-- than set, because a secret door that snaps open is not worth the four digits.
local function swingTo(door: Door, target: CFrame, seconds: number, style: Enum.EasingStyle)
	local info = TweenInfo.new(seconds, style, Enum.EasingDirection.Out)
	TweenService:Create(door.shelf, info, { CFrame = target }):Play()
	for _, piece in door.pieces do
		if piece.part.Parent then
			TweenService:Create(piece.part, info, { CFrame = target * piece.rel }):Play()
		end
	end
end

local function close(door: Door)
	-- Somebody is in it. Wait rather than shutting a fourteen-stud slab of oak
	-- through them: an anchored part that becomes solid inside a character does
	-- not push the part, it pushes the player, and the player is standing in
	-- the doorway precisely because they are trying to use it.
	if occupied(door) then
		door.openUntil = os.clock() + 6
		task.delay(6, function()
			if door.openUntil <= os.clock() then
				close(door)
			end
		end)
		return
	end
	swingTo(door, door.home, 0.8, Enum.EasingStyle.Quad)
	task.delay(0.85, function()
		if door.openUntil <= os.clock() and not occupied(door) then
			door.shelf.CanCollide = true
		end
	end)
end

local function open(player: Player, door: Door)
	door.openUntil = os.clock() + OPEN_SECONDS
	door.shelf.CanCollide = false
	swingTo(door, door.home * SWING, 1.1, Enum.EasingStyle.Quad)
	Remotes.Get("Notify"):FireClient(player, "The shelf swings aside. Mind the steps.", "aura")
	task.delay(OPEN_SECONDS, function()
		if door.openUntil <= os.clock() then
			close(door)
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

function SanctumService.Init(map: { secretDoors: { BasePart }? })
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

	-- bound to a typed local: `for ... in map.secretDoors or NO_DOORS` types as
	-- the union {BasePart} | {BasePart}, which generalised iteration refuses
	local NO_DOORS: { BasePart } = {}
	local shelves: { BasePart } = map.secretDoors or NO_DOORS
	for _, shelf in shelves do
		local pieces: { Piece } = {}
		for _, piece in shelf:GetDescendants() do
			if piece:IsA("BasePart") then
				table.insert(pieces, { part = piece, rel = shelf.CFrame:ToObjectSpace(piece.CFrame) })
			end
		end
		local door: Door = { shelf = shelf, home = shelf.CFrame, pieces = pieces, openUntil = 0 }
		table.insert(doors, door)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Pull a book"
		prompt.ObjectText = "Bookshelf"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = shelf

		-- The prompt has to keep working while the door stands open, or a
		-- player who mistimed the walk is locked out for the whole cooldown
		-- staring at an open doorway.
		prompt.Triggered:Connect(function(player)
			-- everyone who pulls a book has found the door, which is the last
			-- objective of the story's final chapter. Only the principal gets
			-- past it; knowing it is there is the ending for everyone else.
			Signals.FoundTheDoor:Fire(player)
			if not isPrincipal(player) then
				Remotes.Get("Notify"):FireClient(player, "Dust, and a copy of the school rules. Nothing else.", "info")
				return
			end
			if door.openUntil > os.clock() or knowsCode[player] then
				open(player, door)
				return
			end
			pendingDoor[player] = door
			Remotes.Get("SecretKeypad"):FireClient(player)
		end)
	end

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
		local door = pendingDoor[player]
		if code == PIN and door then
			-- they know the code; remember it, so from here on the shelf opens
			-- on the prompt alone and a mistimed walk costs one tap
			knowsCode[player] = true
			open(player, door)
		else
			Remotes.Get("Notify"):FireClient(player, "Nothing happens.", "bad")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		attempts[player] = nil
		pendingDoor[player] = nil
		knowsCode[player] = nil
	end)
end

return SanctumService
