--!strict
-- Every player is a floating cut gem. No human form is ever visible — the
-- avatar's parts go fully transparent and a faceted stone takes their place,
-- hovering with a slow bob and a glint. Tier decides the stone.

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Club.ClubConfig)

local Gems = {}

local gemTemplate: Model? = nil
local cloakTemplate: Model? = nil

local function loadTemplate(assetId: number): Model?
	if assetId == 0 then
		return nil
	end
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not asset then
		warn("[MC] mesh " .. assetId .. " failed to load")
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
			p.CastShadow = false
		end
	end
	asset:Destroy()
	if #template:GetChildren() == 0 then
		return nil
	end
	return template
end

local function loadGemTemplate()
	gemTemplate = loadTemplate(Config.Meshes.Gem)
	cloakTemplate = loadTemplate(Config.Meshes.Cloak)
end

-- fallback stone if the mesh is unavailable: a part-built octahedron
local function fallbackGem(): Model
	local model = Instance.new("Model")
	for _, ang in { 0, math.rad(45) } do
		local p = Instance.new("Part")
		p.Name = "GemFacet"
		p.Size = Vector3.new(2.2, 2.9, 2.2)
		p.CFrame = CFrame.Angles(0, ang, 0)
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		p.CastShadow = false
		p.Parent = model
	end
	return model
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

-- an empty hooded cloak wraps each stone: no body inside, just the drape,
-- the hood, and the gem floating where a face would never be
local CLOAK = Color3.fromRGB(26, 25, 30)
local CLOAK_GUEST = Color3.fromRGB(54, 53, 58)

local function buildCloakFallback(root: BasePart, tier: Config.Tier): Model
	local cloak = Instance.new("Model")
	cloak.Name = "CloakForm"
	local color = if tier.name == "GUEST" then CLOAK_GUEST else CLOAK
	local function piece(name: string, size: Vector3, offset: CFrame, pieceColor: Color3?, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = root.CFrame * offset
		p.Color = pieceColor or color
		p.Material = material or Enum.Material.Fabric
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		p.CastShadow = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		p.Parent = cloak
		return p
	end
	-- hood arching over the stone (gem hovers at ~3.2 above the root)
	piece("Cloak_HoodBack", Vector3.new(2.0, 2.3, 0.4), CFrame.new(0, 3.5, 0.8))
	piece("Cloak_HoodTop", Vector3.new(2.0, 0.45, 1.8), CFrame.new(0, 4.5, 0.15) * CFrame.Angles(math.rad(-14), 0, 0))
	piece("Cloak_HoodL", Vector3.new(0.38, 2.1, 1.6), CFrame.new(-1.0, 3.4, 0.25))
	piece("Cloak_HoodR", Vector3.new(0.38, 2.1, 1.6), CFrame.new(1.0, 3.4, 0.25))
	-- the dark inside of the hood, behind the stone
	piece("Cloak_HoodVoid", Vector3.new(1.6, 1.8, 0.16), CFrame.new(0, 3.35, 0.58), Color3.fromRGB(8, 8, 10), Enum.Material.SmoothPlastic)
	-- shoulder mantle and falling drape
	piece("Cloak_Mantle", Vector3.new(3.1, 1.0, 2.0), CFrame.new(0, 2.35, 0.1))
	piece("Cloak_Mantle2", Vector3.new(2.7, 0.9, 1.8), CFrame.new(0, 1.6, 0.1))
	piece("Cloak_Drape", Vector3.new(2.4, 3.0, 1.6), CFrame.new(0, 0.1, 0.1))
	piece("Cloak_Flare", Vector3.new(2.9, 1.2, 1.95), CFrame.new(0, -1.5, 0.1))
	piece("Cloak_Cape", Vector3.new(2.7, 3.9, 0.3), CFrame.new(0, 0.55, 1.0))
	-- the only mark of rank on the cloth: a hem in the tier's color
	if tier.name ~= "GUEST" then
		piece("Cloak_Hem", Vector3.new(2.95, 0.14, 1.9), CFrame.new(0, 1.14, 0.1), tier.glow, Enum.Material.SmoothPlastic)
	end
	return cloak
end

local function buildCloak(root: BasePart, tier: Config.Tier): Model
	if not cloakTemplate then
		return buildCloakFallback(root, tier)
	end
	local cloak = cloakTemplate:Clone()
	cloak.Name = "CloakForm"
	local parts: { BasePart } = {}
	for _, p in cloak:GetDescendants() do
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
			p.Color = if tier.name == "GUEST" then CLOAK_GUEST else CLOAK
			p.Material = Enum.Material.Fabric
		else
			p.Color = if tier.name == "GUEST" then Color3.fromRGB(74, 72, 78) else tier.glow
			p.Material = Enum.Material.SmoothPlastic
		end
	end
	local primary = parts[1]
	if not primary then
		return buildCloakFallback(root, tier)
	end
	cloak.PrimaryPart = primary
	-- authored with the hem at root-2.1; bounding center sits 1.39 above root
	cloak:PivotTo(root.CFrame * CFrame.new(0, 1.39, 0))
	for _, p in parts do
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	return cloak
end

local function tierOf(player: Player): Config.Tier
	local name = player:GetAttribute("Tier")
	return Config.TierByName(typeof(name) == "string" and name :: string or "GUEST") or Config.Tiers[1]
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

	local old = character:FindFirstChild("GemForm")
	if old then
		old:Destroy()
	end
	local oldCloak = character:FindFirstChild("CloakForm")
	if oldCloak then
		oldCloak:Destroy()
	end

	local tier = tierOf(player)
	local gem = (if gemTemplate then gemTemplate:Clone() else fallbackGem())
	gem.Name = "GemForm"
	local scaleOk = pcall(function()
		gem:ScaleTo(0.85 * tier.scale)
	end)
	if not scaleOk then
		warn("[MC] gem scale failed")
	end

	local primary: BasePart? = nil
	for _, p in gem:GetDescendants() do
		if p:IsA("BasePart") then
			primary = primary or p
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			p.Color = tier.gem
			p.Material = Enum.Material.Glass
			p.Transparency = if tier.name == "BLACK" then 0.02 else 0.12
			p.Reflectance = 0
		end
	end
	if not primary then
		return
	end
	gem.PrimaryPart = primary
	gem:PivotTo(root.CFrame * CFrame.new(0, 3.45, 0))
	-- welded to the rig: replicates for free with the character. The spin and
	-- hover bob are client-side (ClubClient animates GemWeld.C0 locally).
	local weld = Instance.new("Weld")
	weld.Name = "GemWeld"
	weld.Part0 = root
	weld.Part1 = primary
	weld.C0 = CFrame.new(0, 3.45, 0)
	weld.Parent = primary
	for _, p in gem:GetDescendants() do
		if p:IsA("BasePart") and p ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = p
			w.Parent = p
		end
	end
	gem.Parent = character
	buildCloak(root, tier).Parent = character

	-- the glow and the glint
	local light = Instance.new("PointLight")
	light.Color = tier.glow
	light.Brightness = if tier.name == "CROWN" then 1.0 else 0.35
	light.Range = if tier.name == "CROWN" then 16 else 8
	light.Shadows = false
	light.Parent = primary
	-- only the one Crown Jewel sparkles; everyone else is a quiet stone
	if tier.name == "CROWN" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = tier.glow
		sparkles.Parent = primary
	end

	-- tier title floating over the stone — the only identity anyone sees
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TierTag"
	billboard.Size = UDim2.fromScale(6, 1.4)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 90
	billboard.Parent = primary
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromScale(1, 0.55)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.Michroma
	tag.TextScaled = true
	tag.TextColor3 = tier.glow
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

	local _ = TweenService -- reserved for entrance flourish later
end

function Gems.Init()
	loadGemTemplate()
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

return Gems
