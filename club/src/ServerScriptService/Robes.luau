--!strict
-- ROBES — you are your robe. Every player's avatar is replaced by an empty
-- hooded robe: no face, no body, darkness inside the hood. The cloth is the
-- tier, the hem is the trim, and the only identity is the tag above the hood.

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)

local Robes = {}

local robeTemplate: Model? = nil

local function loadTemplate(assetId: number): Model?
	if assetId == 0 then
		return nil
	end
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not asset then
		warn("[ROBES] mesh " .. assetId .. " failed to load")
		return nil
	end
	local inner = asset:FindFirstChildOfClass("Model")
	local template = Instance.new("Model")
	for _, child in (inner or asset):GetChildren() do
		if child:IsA("BasePart") or child:IsA("Model") then
			child.Parent = template
		end
	end
	for _, p in template:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
		end
	end
	asset:Destroy()
	if #template:GetChildren() == 0 then
		return nil
	end
	return template
end

local function strip(character: Model)
	for _, child in character:GetDescendants() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Decal") then
			child:Destroy()
		elseif child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			child.Transparency = 1
		end
	end
end

local function tierOf(player: Player): Config.Tier
	local name = player:GetAttribute("Tier")
	return Config.TierByName(typeof(name) == "string" and name :: string or "GUEST") or Config.Tiers[1]
end

-- fallback if the mesh can't load: a simple part-built robe
local function buildRobeFallback(root: BasePart, tier: Config.Tier): Model
	local robe = Instance.new("Model")
	robe.Name = "RobeForm"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = root.CFrame * offset
		p.Color = color
		p.Material = material or Enum.Material.Fabric
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		p.Parent = robe
		return p
	end
	piece("Robe_HoodBack", Vector3.new(2.0, 2.3, 0.4), CFrame.new(0, 3.5, 0.8), tier.robe)
	piece("Robe_HoodTop", Vector3.new(2.0, 0.45, 1.8), CFrame.new(0, 4.5, 0.15) * CFrame.Angles(math.rad(-14), 0, 0), tier.robe)
	piece("Robe_HoodL", Vector3.new(0.38, 2.1, 1.6), CFrame.new(-1.0, 3.4, 0.25), tier.robe)
	piece("Robe_HoodR", Vector3.new(0.38, 2.1, 1.6), CFrame.new(1.0, 3.4, 0.25), tier.robe)
	piece("Robe_Void", Vector3.new(1.6, 1.8, 0.16), CFrame.new(0, 3.35, 0.58), Color3.fromRGB(6, 6, 8), Enum.Material.SmoothPlastic)
	piece("Robe_Mantle", Vector3.new(3.1, 1.0, 2.0), CFrame.new(0, 2.35, 0.1), tier.robe)
	piece("Robe_Mantle2", Vector3.new(2.7, 0.9, 1.8), CFrame.new(0, 1.6, 0.1), tier.robe)
	piece("Robe_Cape", Vector3.new(2.7, 3.9, 0.3), CFrame.new(0, 0.55, 1.0), tier.robe)
	piece("Robe_Drape", Vector3.new(2.4, 3.0, 1.6), CFrame.new(0, 0.1, 0.1), tier.robe)
	piece("Robe_Flare", Vector3.new(2.9, 1.2, 1.95), CFrame.new(0, -1.5, 0.1), tier.robe)
	piece("Robe_Hem", Vector3.new(2.95, 0.14, 1.9), CFrame.new(0, -2.05, 0.1), tier.trim, Enum.Material.SmoothPlastic)
	return robe
end

local function buildRobe(root: BasePart, tier: Config.Tier): Model
	-- the layered part-built robe won: better hood, better silhouette
	local partRobe = buildRobeFallback(root, tier)
	pcall(function()
		partRobe:ScaleTo(tier.scale)
	end)
	if partRobe then
		return partRobe
	end
	if not robeTemplate then
		return buildRobeFallback(root, tier)
	end
	local robe = robeTemplate:Clone()
	robe.Name = "RobeForm"
	pcall(function()
		robe:ScaleTo(tier.scale)
	end)
	local parts: { BasePart } = {}
	for _, p in robe:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	-- part0 = cloth, part1 = hem band (GLB import drops the glTF colors)
	for i, p in parts do
		if i == 1 then
			p.Color = tier.robe
			p.Material = Enum.Material.Fabric
		else
			p.Color = tier.trim
			p.Material = Enum.Material.SmoothPlastic
		end
	end
	local primary = parts[1]
	if not primary then
		return buildRobeFallback(root, tier)
	end
	robe.PrimaryPart = primary
	-- authored with the hem at root-2.1; bounding center sits 1.39 above root
	robe:PivotTo(root.CFrame * CFrame.new(0, 1.39 * tier.scale, 0))
	for _, p in parts do
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	-- the darkness inside the hood
	local void = Instance.new("Part")
	void.Name = "Robe_Void"
	void.Size = Vector3.new(1.5, 1.7, 0.18) * tier.scale
	void.CFrame = root.CFrame * CFrame.new(0, 3.55 * tier.scale, 0.45 * tier.scale)
	void.Color = Color3.fromRGB(6, 6, 8)
	void.Material = Enum.Material.SmoothPlastic
	void.Anchored = false
	void.CanCollide = false
	void.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = void
	w.Parent = void
	void.Parent = robe
	return robe
end

local function dress(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	strip(character)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	for _, oldName in { "RobeForm", "GemForm", "CloakForm" } do
		local old = character:FindFirstChild(oldName)
		if old then
			old:Destroy()
		end
	end

	local tier = tierOf(player)
	local robe = buildRobe(root, tier)
	robe.Parent = character
	local primary = robe.PrimaryPart or robe:FindFirstChildWhichIsA("BasePart")
	if not primary then
		return
	end

	-- the CROWN robe alone is luminous
	if tier.name == "CROWN" then
		local light = Instance.new("PointLight")
		light.Color = tier.trim
		light.Brightness = 1.0
		light.Range = 16
		light.Shadows = false
		light.Parent = primary
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = tier.trim
		sparkles.Parent = primary
	end

	-- the tag above the hood — the only identity anyone sees
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TierTag"
	billboard.Size = UDim2.fromScale(6, 1.4)
	billboard.StudsOffset = Vector3.new(0, 3.6 * tier.scale, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 90
	billboard.Parent = primary
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromScale(1, 0.55)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.Michroma
	tag.TextScaled = true
	tag.TextColor3 = tier.trim
	tag.TextStrokeTransparency = 0.6
	tag.Text = if tier.name == "GUEST" then "" else tier.name
	tag.Parent = billboard
	local seat = player:GetAttribute("Seat")
	if typeof(seat) == "number" then
		local seatLabel = Instance.new("TextLabel")
		seatLabel.Position = UDim2.fromScale(0, 0.55)
		seatLabel.Size = UDim2.fromScale(1, 0.45)
		seatLabel.BackgroundTransparency = 1
		seatLabel.Font = Enum.Font.Michroma
		seatLabel.TextScaled = true
		seatLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
		seatLabel.TextTransparency = 0.3
		seatLabel.Text = ("№ %d / %d"):format(seat, Config.FoundingSeats)
		seatLabel.Parent = billboard
	end
end

function Robes.Init()
	robeTemplate = loadTemplate(Config.Meshes.Cloak)
	local function hook(player: Player)
		local function redress()
			if player.Character then
				dress(player, player.Character)
			end
		end
		local function onCharacter(character: Model)
			task.wait(0.4)
			redress()
			character.ChildAdded:Connect(function(child)
				if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") then
					task.wait()
					child:Destroy()
				end
			end)
			task.delay(2.5, redress)
			-- late-loading appearance can un-hide limbs; keep forcing them off
			task.spawn(function()
				for _ = 1, 6 do
					task.wait(2)
					if character.Parent then
						for _, part in character:GetChildren() do
							if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
								part.Transparency = 1
							end
						end
					end
				end
			end)
		end
		player.CharacterAppearanceLoaded:Connect(function(character)
			task.wait(0.1)
			dress(player, character)
		end)
		player.CharacterAdded:Connect(onCharacter)
		player:GetAttributeChangedSignal("Tier"):Connect(redress)
		player:GetAttributeChangedSignal("Seat"):Connect(redress)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		task.spawn(hook, player)
	end
end

return Robes
