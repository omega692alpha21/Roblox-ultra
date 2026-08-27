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

-- The robe, built from parts: flared skirt, hanging sleeves, sloped
-- shoulders, and a deep pointed hood with darkness inside. Reads as cloth
-- because everything tapers: wide at the hem, narrow at the chest.
local function buildRobeParts(root: BasePart, tier: Config.Tier): Model
	local robe = Instance.new("Model")
	robe.Name = "RobeForm"
	local BLACK = Color3.fromRGB(16, 15, 18)
	local function piece(className: string, name: string, size: Vector3, offset: CFrame, color: Color3?, material: Enum.Material?): BasePart
		local p = Instance.new(className) :: BasePart
		p.Name = name
		p.Size = size
		p.CFrame = root.CFrame * offset
		p.Color = color or BLACK
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

	-- skirt: three tapering tiers, widest at the hem
	piece("Part", "Robe_Skirt1", Vector3.new(3.3, 1.1, 2.3), CFrame.new(0, -1.65, 0))
	piece("Part", "Robe_Skirt2", Vector3.new(2.8, 1.2, 2.0), CFrame.new(0, -0.55, 0))
	piece("Part", "Robe_Skirt3", Vector3.new(2.35, 1.4, 1.7), CFrame.new(0, 0.7, 0))
	-- skirt slopes so the taper reads at every angle
	for _, side in { -1, 1 } do
		piece("WedgePart", "Robe_SkirtSlope", Vector3.new(2.3, 2.4, 0.5),
			CFrame.new(side * 1.55, -0.9, 0) * CFrame.Angles(0, side * math.rad(90), 0) * CFrame.Angles(math.rad(180), 0, 0))
	end
	-- chest, narrower than everything below
	piece("Part", "Robe_Chest", Vector3.new(2.0, 1.4, 1.45), CFrame.new(0, 2.0, 0))
	-- sloped shoulders
	for _, side in { -1, 1 } do
		piece("WedgePart", "Robe_Shoulder", Vector3.new(1.4, 0.9, 1.0),
			CFrame.new(side * 1.25, 2.6, 0) * CFrame.Angles(0, side * math.rad(-90), 0))
	end
	-- hanging sleeves, tilted slightly outward, open at the bottom
	for _, side in { -1, 1 } do
		piece("Part", "Robe_Sleeve", Vector3.new(0.8, 2.3, 1.15),
			CFrame.new(side * 1.6, 1.25, 0) * CFrame.Angles(0, 0, side * math.rad(-7)))
		piece("Part", "Robe_Cuff", Vector3.new(0.9, 0.35, 1.25),
			CFrame.new(side * 1.78, 0.2, 0) * CFrame.Angles(0, 0, side * math.rad(-7)), Color3.fromRGB(34, 32, 38), Enum.Material.SmoothPlastic)
	end
	-- the hood: collar, deep sides, tilted back, pointed peak
	piece("Part", "Robe_Collar", Vector3.new(1.8, 0.55, 1.55), CFrame.new(0, 2.95, 0))
	piece("Part", "Robe_HoodL", Vector3.new(0.34, 1.45, 1.45), CFrame.new(-0.78, 3.75, 0.12))
	piece("Part", "Robe_HoodR", Vector3.new(0.34, 1.45, 1.45), CFrame.new(0.78, 3.75, 0.12))
	piece("Part", "Robe_HoodBack", Vector3.new(1.9, 1.7, 0.42), CFrame.new(0, 3.8, 0.72) * CFrame.Angles(math.rad(8), 0, 0))
	piece("Part", "Robe_HoodBrow", Vector3.new(1.9, 0.5, 1.0), CFrame.new(0, 4.4, -0.25) * CFrame.Angles(math.rad(-26), 0, 0))
	piece("WedgePart", "Robe_HoodPeak", Vector3.new(1.3, 1.0, 1.2), CFrame.new(0, 4.95, 0.35) * CFrame.Angles(0, math.rad(180), 0))
	-- darkness where a face would never be
	piece("Part", "Robe_Void", Vector3.new(1.35, 1.35, 0.2), CFrame.new(0, 3.7, 0.45), Color3.fromRGB(5, 5, 7), Enum.Material.SmoothPlastic)
	piece("Part", "Robe_Hem", Vector3.new(3.36, 0.16, 2.36), CFrame.new(0, -2.15, 0), Color3.fromRGB(34, 32, 38), Enum.Material.SmoothPlastic)
	local _ = tier

	robe.PrimaryPart = robe:FindFirstChild("Robe_Collar") :: BasePart
	return robe
end

local function buildRobe(root: BasePart, tier: Config.Tier): Model
	-- one robe. Black. For everyone — the Crown holder included. Status
	-- lives in the tag and the doors that open, not on the cloth.
	local robe = buildRobeParts(root, tier)
	local _ = robeTemplate -- mesh robe retired; kept loaded for map displays
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

	-- the tag above the hood — the only identity anyone sees
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TierTag"
	billboard.Size = UDim2.fromScale(6, 1.4)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
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
