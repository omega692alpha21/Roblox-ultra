--!strict
-- Global top-50 boards (total earned + aura) on OrderedDataStores, rendered onto
-- the Trophy Hall boards and pushed to clients for the Top panel.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}

local function getStore(name: string): OrderedDataStore?
	if stores[name] then
		return stores[name]
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if ok then
		stores[name] = store
		return store
	end
	return nil
end

local function renderBoard(board: BasePart, title: string, rows: { { name: string, value: number } })
	local existing = board:FindFirstChildOfClass("SurfaceGui")
	local gui: SurfaceGui
	if existing then
		gui = existing
	else
		gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = board
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.fromScale(1, 0.12)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.FredokaOne
		titleLabel.TextScaled = true
		titleLabel.TextColor3 = Palette.BusYellow
		titleLabel.Parent = gui
		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Position = UDim2.fromScale(0.05, 0.14)
		list.Size = UDim2.fromScale(0.9, 0.84)
		list.BackgroundTransparency = 1
		list.Font = Enum.Font.FredokaOne
		list.TextColor3 = Palette.Chalk
		list.TextScaled = false
		list.TextSize = 22
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.Parent = gui
	end
	(gui:FindFirstChild("Title") :: TextLabel).Text = title
	local lines = {}
	for i, row in rows do
		if i > 12 then
			break
		end
		table.insert(lines, ("%2d. %s — %s"):format(i, row.name, NumberFormat.Abbreviate(row.value)))
	end
	(gui:FindFirstChild("List") :: TextLabel).Text = table.concat(lines, "\n")
end

local function cycle(map: { trophyCashBoard: BasePart, trophyAuraBoard: BasePart })
	-- push current players' stats
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile then
			local cashStore = getStore("GlobalTotalEarned_v1")
			local auraStore = getStore("GlobalAura_v1")
			if cashStore then
				pcall(function()
					cashStore:SetAsync(tostring(player.UserId), math.floor(profile.totalEarned))
				end)
			end
			if auraStore then
				pcall(function()
					auraStore:SetAsync(tostring(player.UserId), math.floor(profile.aura))
				end)
			end
		end
	end

	-- pull top lists
	for _, spec in {
		{ store = "GlobalTotalEarned_v1", kind = "cash", board = map.trophyCashBoard, title = "TOP EARNERS" },
		{ store = "GlobalAura_v1", kind = "aura", board = map.trophyAuraBoard, title = "MOST AURA" },
	} do
		local store = getStore(spec.store)
		if not store then
			continue
		end
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, GameConfig.LeaderboardSize)
		end)
		if not ok then
			continue
		end
		local rows: { { name: string, value: number } } = {}
		for _, entry in pages:GetCurrentPage() do
			local userId = tonumber(entry.key)
			local name = "???"
			if userId then
				local okName, fetched = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				if okName then
					name = fetched
				end
			end
			table.insert(rows, { name = name, value = entry.value })
		end
		renderBoard(spec.board, spec.title, rows)
		Remotes.Get("LeaderboardUpdate"):FireAllClients(spec.kind, rows)
	end
end

function LeaderboardService.Init(map: { trophyCashBoard: BasePart, trophyAuraBoard: BasePart })
	renderBoard(map.trophyCashBoard, "TOP EARNERS", {})
	renderBoard(map.trophyAuraBoard, "MOST AURA", {})
	task.spawn(function()
		task.wait(10)
		while true do
			cycle(map)
			task.wait(GameConfig.LeaderboardPushSeconds)
		end
	end)
end

return LeaderboardService
