--!strict
-- The House Cup.
--
-- One number per house, per server, per term. Points come off the signals the
-- game already fires, so being good at the game is the same thing as being
-- good for your house -- there is no separate house activity to grind.
--
-- The term is twelve minutes. At the bell the leading house's members are paid
-- and everything resets, which means a player who joins at any moment is
-- always inside a race that is about to finish rather than one they missed.
-- The standings live on ReplicatedStorage attributes so the HUD can read them
-- without a remote in the loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Houses = require(ReplicatedStorage.Config.Houses)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AuraService = require(script.Parent.AuraService)
local Signals = require(script.Parent.Parent.Signals)

local HouseService = {}

local points: { [string]: number } = {}
local contributed: { [Player]: number } = {}
local termEndsAt = 0
local board: BasePart? = nil

local function reset()
	for _, house in Houses.List do
		points[house.id] = 0
	end
	for player in contributed do
		contributed[player] = 0
	end
	termEndsAt = os.time() + Houses.TermSeconds
end

local function publish()
	for _, house in Houses.List do
		ReplicatedStorage:SetAttribute("House_" .. house.id, points[house.id] or 0)
	end
	ReplicatedStorage:SetAttribute("HouseTermEndsAt", termEndsAt)

	local surface = board and board:FindFirstChildOfClass("SurfaceGui")
	if surface then
		local rows = {}
		local ordered: { Houses.House } = table.clone(Houses.List)
		table.sort(ordered, function(a, b)
			return (points[a.id] or 0) > (points[b.id] or 0)
		end)
		for index, house in ordered do
			table.insert(rows, ("%d. %s %s   %d"):format(index, house.crest, house.name, points[house.id] or 0))
		end
		local label = surface:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = "THE HOUSE CUP\n\n" .. table.concat(rows, "\n")
		end
	end
end

function HouseService.HouseOf(player: Player): string
	local profile = DataService.Get(player)
	local id = profile and profile.house
	if typeof(id) == "string" and Houses.Get(id) then
		return id
	end
	return Houses.SortFor(player.UserId)
end

function HouseService.Award(player: Player, kind: string, times: number?)
	local value = (Houses.Points :: any)[kind]
	if not value then
		return
	end
	local amount = value * (times or 1)
	local id = HouseService.HouseOf(player)
	points[id] = (points[id] or 0) + amount
	contributed[player] = (contributed[player] or 0) + amount
	player:SetAttribute("HouseContribution", contributed[player])
	publish()
end

local function endTerm()
	local best, bestPoints = nil, -1
	for _, house in Houses.List do
		local total = points[house.id] or 0
		if total > bestPoints then
			best, bestPoints = house, total
		end
	end
	if not best or bestPoints <= 0 then
		reset()
		publish()
		return
	end
	local winner = best :: Houses.House
	Remotes.Get("Notify"):FireAllClients(
		("🏆 %s %s TAKES THE CUP — %d points"):format(winner.crest, winner.name, bestPoints),
		"announce"
	)
	for _, player in Players:GetPlayers() do
		if HouseService.HouseOf(player) == winner.id then
			-- the prize scales with what you personally put in, so a member who
			-- was away from keyboard gets the badge and not the bank
			local share = 2500 + (contributed[player] or 0) * 90
			EconomyService.AddCash(player, share, true)
			AuraService.Add(player, 20)
			local line = ("🏆 Your house won. +$%s and 20 aura."):format(NumberFormat.Abbreviate(share))
			Remotes.Get("Notify"):FireClient(player, line, "aura")
		end
	end
	reset()
	publish()
end

function HouseService.Init(map: { houseBoard: BasePart? })
	board = map.houseBoard
	reset()
	publish()

	local function join(player: Player)
		local id = HouseService.HouseOf(player)
		player:SetAttribute("House", id)
		player:SetAttribute("HouseContribution", 0)
		contributed[player] = 0
		local house = Houses.Get(id)
		if house then
			task.delay(9, function()
				if player.Parent then
					Remotes.Get("Notify"):FireClient(
						player,
						("%s You're in %s. %s"):format(house.crest, house.name, house.motto),
						"info"
					)
				end
			end)
		end
	end
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player)
		contributed[player] = nil
	end)

	Signals.QuizWon:Connect(function(player)
		HouseService.Award(player, "classPass")
	end)
	Signals.Recruited:Connect(function(player)
		HouseService.Award(player, "recruit")
	end)
	Signals.RivalFoiled:Connect(function(player)
		HouseService.Award(player, "rivalFoiled")
	end)
	Signals.ThiefHit:Connect(function(player)
		HouseService.Award(player, "thiefCaught")
	end)
	Signals.Fused:Connect(function(player)
		HouseService.Award(player, "fused")
	end)
	Signals.ToyUsed:Connect(function(player)
		HouseService.Award(player, "toyHit")
	end)
	Signals.ChapterDone:Connect(function(player)
		HouseService.Award(player, "chapterDone")
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			if os.time() >= termEndsAt then
				endTerm()
			else
				publish()
			end
		end
	end)
end

return HouseService
