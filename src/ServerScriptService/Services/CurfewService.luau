--!strict
-- Curfew: SchoolClock calls StartNight() on the Lights Out period. While it's
-- dark, every tick spent OUTDOORS farms aura (ramping the longer you stay out),
-- but the prefects roll to catch you — busted means detention and an aura fine.
-- Indoors (main building, dorms) is always safe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local AuraService = require(script.Parent.AuraService)
local StealService = require(script.Parent.StealService)
local JailService = require(script.Parent.JailService)

local CurfewService = {}

local detentionSpot = Vector3.new(-438, 0, -14)
local night = false
local streaks: { [Player]: number } = {}
local rng = Random.new()

-- Safe = inside the main school shell or either dorm footprint.
local function isIndoors(pos: Vector3): boolean
	-- the school footprint from the floor plan (the courtyards are open to
	-- the sky, so standing in one still counts as being outdoors at night)
	-- Every roofed building on the campus, not just the Academy. The ring
	-- buildings moved out to their drawn ground -- the library to (-320, -300),
	-- the cafeteria to (320, -300), the detention hall to (-400, 20) and the
	-- gymnasium to (425, 405) -- and standing inside any of them is indoors.
	-- Left as it was, a player sheltering in the new cafeteria at midnight was
	-- still counted as out after curfew and hunted by prefects.
	local function inside(cx: number, cz: number, hx: number, hz: number): boolean
		return math.abs(pos.X - cx) < hx and math.abs(pos.Z - cz) < hz
	end
	if inside(0, -12, 236, 148)
		or inside(-320, -300, 100, 48)   -- library
		or inside(320, -300, 100, 48)    -- cafeteria
		or inside(-400, 20, 85, 60)      -- detention hall
		or inside(425, 405, 95, 65)      -- gymnasium
		or inside(210, 400, 55, 55)      -- the rooftop block
		or inside(0, -310, 150, 60) then -- student dorms
		local inWestCourt = math.abs(pos.X + 116) < 56 and math.abs(pos.Z) < 52
		local inEastCourt = math.abs(pos.X - 116) < 56 and math.abs(pos.Z) < 52
		if not (inWestCourt or inEastCourt) then
			return true
		end
	end
	-- The two blocks at (+-176, -232) are gone: the boarding house is one range
	-- on the axis, and the `inside(0, -310, 150, 60)` test above is its drawn
	-- rectangle. This loop was keeping two patches of open lawn safe from
	-- curfew and the range itself was only safe by accident.
	return false
end

local function sendToDetention(player: Player)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local served = JailService.Jail(player)
	AuraService.Add(player, -GameConfig.DetentionAuraPenalty)
	if served <= 0 then
		Remotes.Get("Notify"):FireClient(player, ("A prefect caught you — but your Jail Pass got you out. -%d aura."):format(GameConfig.DetentionAuraPenalty), "bad")
		return
	end
	Remotes.Get("Notify"):FireClient(
		player,
		("BUSTED! A prefect caught you after dark. %ds in detention, -%d aura."):format(
			served,
			GameConfig.DetentionAuraPenalty
		),
		"bad"
	)
	Remotes.Get("Notify"):FireAllClients(player.DisplayName .. " got dragged to DETENTION for breaking curfew!", "info")
	task.delay(served, function()
		if player.Parent then
			player:SetAttribute("DetentionUntil", nil)
			StealService.RefreshWalkSpeed(player)
			Remotes.Get("Notify"):FireClient(player, "Detention's over. Walk it off.", "info")
		end
	end)
end

local function tickNight()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local detention = player:GetAttribute("DetentionUntil")
		if typeof(detention) == "number" and detention > now then
			continue
		end
		if isIndoors(root.Position) then
			streaks[player] = 0
			continue
		end
		local streak = (streaks[player] or 0) + 1
		streaks[player] = streak
		local gain = math.min(streak, GameConfig.CurfewAuraCap)
		AuraService.Add(player, gain)
		if streak % 4 == 1 then
			Remotes.Get("Notify"):FireClient(
				player,
				("Out after dark... +%d aura a tick and climbing. Don't get caught."):format(gain),
				"aura"
			)
		end
		local chance = math.min(
			GameConfig.CurfewCatchBase + streak * GameConfig.CurfewCatchRamp,
			GameConfig.CurfewCatchMax
		)
		if rng:NextNumber() < chance then
			streaks[player] = 0
			sendToDetention(player)
		end
	end
end

local function tweenClock(target: number, ambient: Color3)
	TweenService:Create(Lighting, TweenInfo.new(4, Enum.EasingStyle.Sine), {
		ClockTime = target,
		OutdoorAmbient = ambient,
	}):Play()
end

function CurfewService.StartNight()
	if night then
		return
	end
	night = true
	streaks = {}
	tweenClock(0.4, Color3.fromRGB(14, 19, 34))
	Remotes.Get("Notify"):FireAllClients(
		"LIGHTS OUT! Get inside — prefects patrol after dark. Or stay out and farm that aura... 😈",
		"announce"
	)
	task.spawn(function()
		while night do
			task.wait(GameConfig.CurfewTickSeconds)
			if night then
				tickNight()
			end
		end
	end)
	task.delay(GameConfig.CurfewNightSeconds, function()
		night = false
		streaks = {}
		tweenClock(21.2, Color3.fromRGB(26, 34, 56))
		Remotes.Get("Notify"):FireAllClients("Morning bell! Curfew's over — back to business.", "info")
	end)
end

function CurfewService.Init(map: { detentionSpot: Vector3 })
	detentionSpot = map.detentionSpot
	Players.PlayerRemoving:Connect(function(player)
		streaks[player] = nil
	end)
end

return CurfewService
