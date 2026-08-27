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

local function loadGemTemplate()
	if Config.Meshes.Gem == 0 then
		return
	end
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(Config.Meshes.Gem)
	end)
	if not ok or not asset then
		warn("[MC] gem mesh failed to load")
		return
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
	if #template:GetChildren() > 0 then
		gemTemplate = template
	end
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

	local tier = tierOf(player)
	local gem = (if gemTemplate then gemTemplate:Clone() else fallbackGem())
	gem.Name = "GemForm"
	local scaleOk = pcall(function()
		gem:ScaleTo(1.5 * tier.scale)
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
			p.Reflectance = if tier.name == "BLACK" then 0.4 else 0.28
		end
	end
	if not primary then
		return
	end
	gem.PrimaryPart = primary
	gem:PivotTo(root.CFrame * CFrame.new(0, 0.6, 0))
	-- welded to the rig: replicates for free with the character. The spin and
	-- hover bob are client-side (ClubClient animates GemWeld.C0 locally).
	local weld = Instance.new("Weld")
	weld.Name = "GemWeld"
	weld.Part0 = root
	weld.Part1 = primary
	weld.C0 = CFrame.new(0, 0.6, 0)
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

	-- the glow and the glint
	local light = Instance.new("PointLight")
	light.Color = tier.glow
	light.Brightness = if tier.name == "GUEST" then 0.6 else 1.6
	light.Range = if tier.name == "CROWN" then 30 else 14
	light.Shadows = false
	light.Parent = primary
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = tier.glow
	sparkles.Enabled = tier.name ~= "GUEST"
	sparkles.Parent = primary

	-- tier title floating over the stone — the only identity anyone sees
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TierTag"
	billboard.Size = UDim2.fromScale(6, 1.4)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
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
