--!strict
-- Builds student NPC models as real humanoid avatars (R15) from code — no art assets.
-- Look is deterministic per student id: same student always has the same skin tone,
-- outfit colors, build, and prop. Rarity shows as a glow + billboard; Mythic+ get particles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Students = require(ReplicatedStorage.Config.Students)
local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

local StudentGen = {}

local SKIN_TONES = {
	Color3.fromRGB(255, 204, 153),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 145, 100),
	Color3.fromRGB(151, 102, 66),
	Color3.fromRGB(114, 74, 47),
	Color3.fromRGB(255, 219, 172),
}

local SHIRT_COLORS = {
	Color3.fromRGB(46, 107, 214),
	Color3.fromRGB(217, 67, 47),
	Color3.fromRGB(63, 191, 74),
	Color3.fromRGB(245, 197, 49),
	Color3.fromRGB(180, 75, 217),
	Color3.fromRGB(64, 64, 72),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(255, 128, 174),
}

local PANTS_COLORS = {
	Color3.fromRGB(40, 52, 78),
	Color3.fromRGB(64, 64, 64),
	Color3.fromRGB(94, 66, 44),
	Color3.fromRGB(120, 130, 140),
	Color3.fromRGB(34, 48, 31),
}

local function seedFromString(s: string): number
	local seed = 0
	for i = 1, #s do
		seed = (seed * 31 + string.byte(s, i)) % 2 ^ 31
	end
	return seed
end

local function paintCharacter(model: Model, rng: Random)
	local skin = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)]
	local shirt = SHIRT_COLORS[rng:NextInteger(1, #SHIRT_COLORS)]
	local pants = PANTS_COLORS[rng:NextInteger(1, #PANTS_COLORS)]
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local name = part.Name
			if name == "Head" or name:find("Hand") or name:find("Arm") then
				part.Color = skin
			elseif name:find("Torso") then
				part.Color = shirt
			elseif name:find("Leg") or name:find("Foot") then
				part.Color = pants
			end
		end
	end
end

-- Simple part-built props so students don't all look identical.
local function addProp(model: Model, rng: Random, rarityName: string)
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) :: BasePart?
	local kind = rng:NextInteger(1, 4)
	if kind == 1 and head then
		-- cap
		local brim = Instance.new("Part")
		brim.Size = Vector3.new(1.2, 0.15, 0.7)
		brim.Color = SHIRT_COLORS[rng:NextInteger(1, #SHIRT_COLORS)]
		brim.CanCollide = false
		brim.Massless = true
		brim.CFrame = head.CFrame * CFrame.new(0, 0.55, -0.75)
		local top = Instance.new("Part")
		top.Shape = Enum.PartType.Cylinder
		top.Size = Vector3.new(0.5, 1.25, 1.25)
		top.Color = brim.Color
		top.CanCollide = false
		top.Massless = true
		top.CFrame = head.CFrame * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
		for _, p in { brim, top } do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = p
			weld.Parent = p
			p.Parent = model
		end
	elseif kind == 2 and torso then
		-- backpack
		local pack = Instance.new("Part")
		pack.Size = Vector3.new(1.4, 1.7, 0.6)
		pack.Color = SHIRT_COLORS[rng:NextInteger(1, #SHIRT_COLORS)]
		pack.CanCollide = false
		pack.Massless = true
		pack.CFrame = torso.CFrame * CFrame.new(0, 0.1, 0.85)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = pack
		weld.Parent = pack
		pack.Parent = model
	elseif kind == 3 and head then
		-- glasses
		local glasses = Instance.new("Part")
		glasses.Size = Vector3.new(1.1, 0.25, 0.15)
		glasses.Color = Color3.fromRGB(20, 20, 20)
		glasses.CanCollide = false
		glasses.Massless = true
		glasses.CFrame = head.CFrame * CFrame.new(0, 0.12, -0.58)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = glasses
		weld.Parent = glasses
		glasses.Parent = model
	end
	-- Secret students get a golden crown regardless of roll
	if rarityName == "Secret" and head then
		local crown = Instance.new("Part")
		crown.Size = Vector3.new(1.1, 0.45, 1.1)
		crown.Color = Palette.BusYellow
		crown.Material = Enum.Material.Neon
		crown.CanCollide = false
		crown.Massless = true
		crown.CFrame = head.CFrame * CFrame.new(0, 0.85, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = crown
		weld.Parent = crown
		crown.Parent = model
	end
end

local function addBillboard(model: Model, defName: string, rarityName: string, income: number, color: Color3)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(190, 64)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 140
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.45)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = color
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Text = defName
	nameLabel.Parent = billboard

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Info"
	infoLabel.Position = UDim2.fromScale(0, 0.45)
	infoLabel.Size = UDim2.fromScale(1, 0.3)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.FredokaOne
	infoLabel.TextScaled = true
	infoLabel.TextColor3 = Palette.CashGreen
	infoLabel.TextStrokeTransparency = 0.2
	infoLabel.Text = "$" .. NumberFormat.Abbreviate(income) .. "/s"
	infoLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Position = UDim2.fromScale(0, 0.75)
	rarityLabel.Size = UDim2.fromScale(1, 0.25)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.FredokaOne
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = color
	rarityLabel.TextStrokeTransparency = 0.2
	rarityLabel.Text = rarityName:upper()
	rarityLabel.Parent = billboard
end

-- Creates an anchored, non-colliding student NPC model for the given student id.
function StudentGen.Create(defId: string): Model?
	local entry = Students.Get(defId)
	if not entry then
		return nil
	end
	local def, rarity = entry.def, entry.rarity
	local rng = Random.new(seedFromString(defId))

	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		-- deterministic proportions per student
		desc.HeightScale = 0.8 + rng:NextNumber() * 0.45
		desc.WidthScale = 0.85 + rng:NextNumber() * 0.4
		desc.HeadScale = 0.95 + rng:NextNumber() * 0.35
		desc.BodyTypeScale = rng:NextNumber() * 0.3
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		-- fallback: simple block figure (offline test places can't call avatar endpoints)
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "HumanoidRootPart"
		body.Size = Vector3.new(2, 3.2, 1.2)
		body.Color = SHIRT_COLORS[rng:NextInteger(1, #SHIRT_COLORS)]
		body.Parent = model
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1.6, 1.6, 1.6)
		head.Color = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)]
		head.CFrame = body.CFrame * CFrame.new(0, 2.4, 0)
		head.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = head
		weld.Parent = head
		model.PrimaryPart = body
	end

	model.Name = "Student_" .. defId
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = ""
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.EvaluateStateMachine = false
	end
	paintCharacter(model, rng)
	addProp(model, rng, rarity.name)
	addBillboard(model, def.name, rarity.name, def.income, rarity.color)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = true
		end
	end

	-- rarity glow for Epic and up
	local rarityIndex = table.find({ "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }, rarity.name) or 1
	if rarityIndex >= 3 then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = rarity.color
		highlight.OutlineTransparency = 0.1
		highlight.Parent = model
	end
	if rarityIndex >= 5 then
		local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if root then
			local particles = Instance.new("ParticleEmitter")
			particles.Color = ColorSequence.new(rarity.color)
			particles.Rate = 12
			particles.Lifetime = NumberRange.new(0.6, 1.2)
			particles.Speed = NumberRange.new(1, 2.5)
			particles.Size = NumberSequence.new(0.35)
			particles.LightEmission = 0.8
			particles.Parent = root
		end
	end

	-- attribute so other services can identify the def without parsing names
	model:SetAttribute("StudentId", defId)
	return model
end

-- Position an (anchored) student model so its feet sit on the given CFrame.
function StudentGen.Stand(model: Model, cf: CFrame)
	local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not root then
		return
	end
	model.PrimaryPart = root
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hipHeight = humanoid and humanoid.HipHeight > 0 and humanoid.HipHeight or 1.6
	model:PivotTo(cf * CFrame.new(0, hipHeight + root.Size.Y / 2, 0))
end

return StudentGen
