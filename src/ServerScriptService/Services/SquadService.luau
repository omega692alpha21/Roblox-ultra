--!strict
-- Crews made of people, not only NPCs.
--
-- A hallway student in your clique joins because you paid for them. A real
-- player has to say yes. That is the whole difference, and it is the right
-- one: consent is what separates a crew from a collection.
--
-- What a squad gets you: your escorts defend anyone in it, not only you, and
-- a study-group bonus on everything you earn while a squad-mate is nearby.
-- Both are reasons to actually walk around together rather than to accept an
-- invite and then never see each other again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cliques = require(ReplicatedStorage.Config.Cliques)
local Remotes = require(ReplicatedStorage.Remotes)

local SquadService = {}

local INVITE_SECONDS = 30
local NEARBY = 70 -- how close a squad-mate counts as "with you"
local MAX_SQUAD = 6

-- squad id -> members. A squad is just a set; the inviter is not a rank.
local squads: { [string]: { Player } } = {}
local squadOf: { [Player]: string } = {}
local pending: { [Player]: { from: Player, expires: number } } = {}
local prompts: { [Player]: ProximityPrompt } = {}
local EMPTY: { Player } = {}

local function membersOf(player: Player): { Player }
	local id = squadOf[player]
	return id and squads[id] or { player }
end

SquadService.MembersOf = membersOf

local function publish(id: string)
	local list = squads[id]
	if not list then
		return
	end
	local rows = {}
	for _, member in list do
		local clique = Cliques.For(member)
		table.insert(rows, {
			name = member.DisplayName,
			userId = member.UserId,
			clique = clique.name,
			color = clique.color,
		})
	end
	for _, member in list do
		Remotes.Get("SquadState"):FireClient(member, rows)
	end
end

local function leave(player: Player, quiet: boolean?)
	local id = squadOf[player]
	if not id then
		return
	end
	squadOf[player] = nil
	player:SetAttribute("SquadId", nil)
	player:SetAttribute("SquadSize", 0)
	local list = squads[id]
	if not list then
		return
	end
	local index = table.find(list, player)
	if index then
		table.remove(list, index)
	end
	for _, member in list do
		member:SetAttribute("SquadSize", #list)
		if not quiet then
			Remotes.Get("Notify"):FireClient(member, player.DisplayName .. " left the crew.", "info")
		end
	end
	if #list <= 1 then
		for _, member in list do
			squadOf[member] = nil
			member:SetAttribute("SquadId", nil)
			member:SetAttribute("SquadSize", 0)
			Remotes.Get("SquadState"):FireClient(member, {})
		end
		squads[id] = nil
	else
		publish(id)
	end
	Remotes.Get("SquadState"):FireClient(player, {})
end

local function join(a: Player, b: Player)
	local id = squadOf[a] or squadOf[b] or ("squad_" .. tostring(a.UserId))
	local list = squads[id]
	if not list then
		list = {}
		squads[id] = list
	end
	for _, player in { a, b } do
		if squadOf[player] ~= id then
			if squadOf[player] then
				leave(player, true)
			end
			if #list >= MAX_SQUAD then
				Remotes.Get("Notify"):FireClient(player, "That crew is full.", "bad")
				continue
			end
			table.insert(list, player)
			squadOf[player] = id
			player:SetAttribute("SquadId", id)
		end
	end
	for _, member in list do
		member:SetAttribute("SquadSize", #list)
	end
	publish(id)
end

local function invite(from: Player, to: Player)
	if from == to then
		return
	end
	if squadOf[from] and squadOf[from] == squadOf[to] then
		Remotes.Get("Notify"):FireClient(from, to.DisplayName .. " is already in your crew.", "info")
		return
	end
	local live = pending[to]
	if live and live.expires > os.clock() then
		Remotes.Get("Notify"):FireClient(from, to.DisplayName .. " already has an invite open.", "info")
		return
	end
	pending[to] = { from = from, expires = os.clock() + INVITE_SECONDS }

	local friend = false
	pcall(function()
		friend = from:IsFriendsWithAsync(to.UserId)
	end)
	local clique = Cliques.For(from)
	Remotes.Get("CrewInvite"):FireClient(to, {
		name = from.DisplayName,
		userId = from.UserId,
		clique = clique.name,
		color = clique.color,
		friend = friend,
		seconds = INVITE_SECONDS,
	})
	Remotes.Get("Notify"):FireClient(from, "Asked " .. to.DisplayName .. " to join your crew.", "info")
end

local function attachPrompt(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CrewInvitePrompt"
	prompt.ActionText = "Ask to join your crew"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompts[player] = prompt
	prompt.Triggered:Connect(function(asker)
		invite(asker, player)
	end)
end

-- Everything a squad is worth, applied where the money is made.
function SquadService.EarnMultiplier(player: Player): number
	local id = squadOf[player]
	if not id then
		return 1
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return 1
	end
	local near = 0
	-- bound to a typed local: `for ... in squads[id] or EMPTY` types as the
	-- union {Player} | {Player}, which generalised iteration refuses to call
	local list: { Player } = squads[id] or EMPTY
	for _, member in list do
		if member ~= player then
			local otherRoot = member.Character and member.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= NEARBY then
				near += 1
			end
		end
	end
	-- eight percent each, so a full crew studying together is worth a third
	-- more and a crew scattered across the map is worth nothing extra
	return 1 + math.min(near, 5) * 0.08
end

-- Published as an attribute rather than read through a require, so the pay
-- path (EconomyService) and the HUD both get it without either one depending
-- on this module. An attribute of 1 is the same as no crew.
local function refreshBonuses()
	for _, player in Players:GetPlayers() do
		local bonus = SquadService.EarnMultiplier(player)
		if player:GetAttribute("SquadBonus") ~= bonus then
			player:SetAttribute("SquadBonus", bonus)
		end
	end
end

function SquadService.Init()
	local function hook(player: Player)
		if player.Character then
			attachPrompt(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			attachPrompt(player, character)
		end)
	end
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player)
		leave(player, true)
		pending[player] = nil
		prompts[player] = nil
	end)

	Remotes.Get("CrewInviteAnswer").OnServerEvent:Connect(function(player, accept)
		local live = pending[player]
		pending[player] = nil
		if not live or live.expires <= os.clock() or not live.from.Parent then
			return
		end
		if accept == true then
			join(live.from, player)
			Remotes.Get("Notify"):FireClient(live.from, player.DisplayName .. " joined your crew!", "good")
			Remotes.Get("Notify"):FireClient(player, "You're running with " .. live.from.DisplayName .. " now.", "good")
		else
			Remotes.Get("Notify"):FireClient(live.from, player.DisplayName .. " said no.", "bad")
		end
	end)

	Remotes.Get("LeaveCrew").OnServerEvent:Connect(function(player)
		leave(player)
	end)

	-- expire invites nobody answered, and keep the proximity bonus current
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for player, live in pending do
			if live.expires <= now then
				pending[player] = nil
			end
		end
		since += dt
		if since >= 0.5 then
			since = 0
			refreshBonuses()
		end
	end)
end

return SquadService
