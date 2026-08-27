--!strict
-- Found your own cult. The CULT LEADER pass buys the right; fifty hours served
-- buys the standing. A founder names it, picks a sigil and a color, and a
-- chapter house rises on the grounds with their banner on it. Their robe trim
-- turns their cult's color. CULT itself remains above all of them.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
local Rep = require(script.Parent.Rep)

local Cults = {}

type Cult = { founder: number, name: string, sigil: number, color: number, members: { number } }

local INDEX_KEY = "cult_index_v1"
local registry: { [number]: Cult } = {} -- by founder userId
local lodgeFolder: Folder? = nil

local function store(): DataStore?
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore("CultRegistry")
	end)
	return ok and ds or nil
end

local function ownsPass(player: Player): boolean
	if player.UserId == Config.OwnerUserId then
		return true
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.CultLeaderPassId)
	end)
	return ok and owns == true
end

local function filteredName(player: Player, raw: string): string?
	local trimmed = raw:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 24)
	if #trimmed < 3 then
		return nil
	end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(trimmed, player.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or typeof(result) ~= "string" then
		return nil
	end
	return result:upper()
end

-- each cult gets a chapter house on the ring around the grounds
local function lodgeSpot(founder: number): CFrame
	local slot = founder % 8
	local a = (slot / 8) * math.pi * 2 + math.pi -- south half, away from the approach
	local d = 132
	local pos = Vector3.new(math.sin(a) * d, 0, math.cos(a) * d - 36)
	return CFrame.lookAt(pos, Vector3.new(0, 0, -36))
end

local function buildLodge(cult: Cult)
	local folder = lodgeFolder
	if not folder then
		return
	end
	local existing = folder:FindFirstChild("Lodge_" .. cult.founder)
	if existing then
		existing:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Lodge_" .. cult.founder
	local color = Config.CultColors[cult.color] or Config.CultColors[1]
	local sigil = Config.CultSigils[cult.sigil] or Config.CultSigils[1]
	local cf = lodgeSpot(cult.founder)

	local function p(props: { [string]: any }): Part
		local prt = Instance.new("Part")
		prt.Anchored = true
		prt.Material = Enum.Material.Slate
		for k, v in props do
			(prt :: any)[k] = v
		end
		prt.Parent = model
		return prt
	end

	-- a small stone chapter house: walls, doorway, pitched cap, banner
	p({ Name = "LodgeBack", Size = Vector3.new(18, 12, 2), CFrame = cf * CFrame.new(0, 6, 8), Color = Color3.fromRGB(40, 39, 44) })
	p({ Name = "LodgeL", Size = Vector3.new(2, 12, 16), CFrame = cf * CFrame.new(-8, 6, 0), Color = Color3.fromRGB(40, 39, 44) })
	p({ Name = "LodgeR", Size = Vector3.new(2, 12, 16), CFrame = cf * CFrame.new(8, 6, 0), Color = Color3.fromRGB(40, 39, 44) })
	p({ Name = "LodgeFrontL", Size = Vector3.new(6, 12, 2), CFrame = cf * CFrame.new(-6, 6, -8), Color = Color3.fromRGB(40, 39, 44) })
	p({ Name = "LodgeFrontR", Size = Vector3.new(6, 12, 2), CFrame = cf * CFrame.new(6, 6, -8), Color = Color3.fromRGB(40, 39, 44) })
	p({ Name = "LodgeLintel", Size = Vector3.new(6, 4, 2), CFrame = cf * CFrame.new(0, 10, -8), Color = Color3.fromRGB(40, 39, 44) })
	p({ Name = "LodgeRoof", Size = Vector3.new(20, 2, 20), CFrame = cf * CFrame.new(0, 13, 0), Color = Color3.fromRGB(30, 29, 34) })
	p({ Name = "LodgeFloor", Size = Vector3.new(16, 1, 14), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(34, 33, 38) })

	-- their banner over the door, their color, their mark
	local banner = p({
		Name = "LodgeBanner",
		Size = Vector3.new(5, 8, 0.3),
		CFrame = cf * CFrame.new(0, 8.5, -9.2),
		Color = color,
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = banner
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 0.7)
	mark.BackgroundTransparency = 1
	mark.Font = Enum.Font.Michroma
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(232, 224, 200)
	mark.Text = sigil
	mark.Parent = gui
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.fromScale(0, 0.72)
	nameLabel.Size = UDim2.fromScale(1, 0.26)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Michroma
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(232, 224, 200)
	nameLabel.Text = cult.name
	nameLabel.Parent = gui

	-- braziers in their color
	for _, side in { -1, 1 } do
		local bowl = p({
			Name = "LodgeBrazier",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 2, 2),
			CFrame = cf * CFrame.new(side * 6, 1.4, -10.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(26, 25, 29),
			Material = Enum.Material.Metal,
		})
		local fl = Instance.new("Part")
		fl.Anchored = true
		fl.CanCollide = false
		fl.Shape = Enum.PartType.Ball
		fl.Size = Vector3.new(0.9, 1.3, 0.9)
		fl.CFrame = bowl.CFrame * CFrame.new(0, 0, 0) + Vector3.new(0, 1, 0)
		fl.Color = color:Lerp(Color3.new(1, 0.8, 0.4), 0.5)
		fl.Material = Enum.Material.Neon
		fl.Parent = model
		local light = Instance.new("PointLight")
		light.Color = fl.Color
		light.Brightness = 1.4
		light.Range = 14
		light.Parent = fl
	end

	-- pledge prompt on the banner
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pledge"
	prompt.ObjectText = cult.name
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = banner
	prompt.Triggered:Connect(function(player)
		if player.UserId == cult.founder then
			Remotes.Get("Notify"):FireClient(player, "It is yours already.", "info")
			return
		end
		local hours = Rep.HoursOf(player)
		if hours < Config.CultJoinHours then
			Remotes.Get("Notify"):FireClient(
				player,
				("%s takes only the proven: %d hours served (you have %.1f). Time away counts half."):format(cult.name, Config.CultJoinHours, hours),
				"bad"
			)
			return
		end
		for _, id in cult.members do
			if id == player.UserId then
				Remotes.Get("Notify"):FireClient(player, "You are already sworn to " .. cult.name .. ".", "info")
				return
			end
		end
		table.insert(cult.members, player.UserId)
		local ds = store()
		if ds then
			pcall(function()
				ds:SetAsync("cult_" .. cult.founder, cult)
			end)
		end
		player:SetAttribute("Pledged", cult.name)
		Remotes.Get("Notify"):FireAllClients(("A member has sworn to %s."):format(cult.name), "announce")
	end)

	model.Parent = folder
end

local function pushFounderAttributes(player: Player)
	local cult = registry[player.UserId]
	if cult then
		player:SetAttribute("CultName", cult.name)
		player:SetAttribute("CultColor", cult.color)
	end
end

local function loadRegistry()
	local ds = store()
	if not ds then
		return
	end
	local founders: { number } = {}
	pcall(function()
		local index = ds:GetAsync(INDEX_KEY)
		if typeof(index) == "table" then
			founders = index :: { number }
		end
	end)
	for _, founder in founders do
		pcall(function()
			local cult = ds:GetAsync("cult_" .. founder)
			if typeof(cult) == "table" then
				registry[founder] = cult :: Cult
				buildLodge(registry[founder])
			end
		end)
	end
end

function Cults.Init(map: any)
	local folder = Instance.new("Folder")
	folder.Name = "Lodges"
	folder.Parent = map.folder
	lodgeFolder = folder

	loadRegistry()

	-- the founders' stone, where a leader declares their cult
	local stone = Instance.new("Part")
	stone.Name = "FoundersStone"
	stone.Anchored = true
	stone.Size = Vector3.new(6, 5, 2)
	stone.CFrame = CFrame.new(-24, 2.5, 78) * CFrame.Angles(0, math.rad(24), 0)
	stone.Color = Color3.fromRGB(34, 33, 38)
	stone.Material = Enum.Material.Slate
	stone.Parent = map.folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = stone
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Michroma
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(140, 120, 80)
	text.Text = "SOME OF US\nWERE NOT MADE\nTO FOLLOW"
	text.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Declare"
	prompt.ObjectText = ""
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = stone
	prompt.Triggered:Connect(function(player)
		if registry[player.UserId] then
			Remotes.Get("Notify"):FireClient(player, "Your house already stands.", "info")
			return
		end
		if not ownsPass(player) then
			MarketplaceService:PromptGamePassPurchase(player, Config.CultLeaderPassId)
			return
		end
		if Rep.HoursOf(player) < Config.CultJoinHours and player.UserId ~= Config.OwnerUserId then
			Remotes.Get("Notify"):FireClient(
				player,
				("The stone takes only the proven: %d hours served first."):format(Config.CultJoinHours),
				"bad"
			)
			return
		end
		Remotes.Get("OpenFounding"):FireClient(player)
	end)

	Remotes.GetFunction("FoundCult").OnServerInvoke = function(player: Player, rawName: any, sigil: any, color: any): any
		if registry[player.UserId] then
			return { ok = false, message = "Your house already stands." }
		end
		if not ownsPass(player) then
			return { ok = false, message = "The stone does not know you." }
		end
		if Rep.HoursOf(player) < Config.CultJoinHours and player.UserId ~= Config.OwnerUserId then
			return { ok = false, message = "Not enough hours served." }
		end
		local sigilIndex = math.clamp(tonumber(sigil) or 1, 1, #Config.CultSigils)
		local colorIndex = math.clamp(tonumber(color) or 1, 1, #Config.CultColors)
		local name = filteredName(player, tostring(rawName))
		if not name then
			return { ok = false, message = "That name will not take." }
		end
		for _, cult in registry do
			if cult.name == name then
				return { ok = false, message = "That name is already carved." }
			end
		end
		local cult: Cult = { founder = player.UserId, name = name, sigil = sigilIndex, color = colorIndex, members = {} }
		registry[player.UserId] = cult
		local ds = store()
		if ds then
			pcall(function()
				ds:SetAsync("cult_" .. player.UserId, cult)
				ds:UpdateAsync(INDEX_KEY, function(old)
					local index: { number } = typeof(old) == "table" and old :: { number } or {}
					table.insert(index, player.UserId)
					return index
				end)
			end)
		end
		buildLodge(cult)
		pushFounderAttributes(player)
		Remotes.Get("Notify"):FireAllClients(
			("%s A new house has risen on the grounds: %s."):format(Config.CultSigils[sigilIndex], name),
			"announce"
		)
		return { ok = true, message = "" }
	end

	local function onAdded(player: Player)
		pushFounderAttributes(player)
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onAdded, player)
	end
end

return Cults
