--!strict
-- Purely visual flex items (game passes with zero gameplay effect). Built from
-- parts/particles like everything else here — no imported meshes required.

local Players = game:GetService("Players")

local CosmeticsService = {}

local COSMETIC_ATTRS = { "CosmeticHalo", "CosmeticCrown", "CosmeticAuraRing", "CosmeticCape" }

local function weld(part: BasePart, toPart: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = toPart
	weld.Parent = part
end

local function addHalo(character: Model, head: BasePart)
	local ring = Instance.new("Part")
	ring.Name = "Cosmetic_Halo"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 2.4, 2.4)
	ring.Color = Color3.fromRGB(255, 221, 110)
	ring.Material = Enum.Material.Neon
	ring.CanCollide = false
	ring.Massless = true
	ring.CFrame = head.CFrame * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = character
	weld(ring, head)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 221, 110)
	light.Brightness = 1.4
	light.Range = 10
	light.Parent = ring
end

local function addCrown(character: Model, head: BasePart)
	local base = Instance.new("Part")
	base.Name = "Cosmetic_Crown"
	base.Size = Vector3.new(1.6, 0.7, 1.6)
	base.Color = Color3.fromRGB(255, 200, 40)
	base.Material = Enum.Material.Neon
	base.CanCollide = false
	base.Massless = true
	base.CFrame = head.CFrame * CFrame.new(0, 0.95, 0)
	base.Parent = character
	weld(base, head)
	for i = 0, 4 do
		local spike = Instance.new("Part")
		spike.Name = "CrownSpike"
		spike.Size = Vector3.new(0.22, 0.6, 0.22)
		spike.Color = base.Color
		spike.Material = Enum.Material.Neon
		spike.CanCollide = false
		spike.Massless = true
		local angle = (i / 5) * math.pi * 2
		spike.CFrame = base.CFrame * CFrame.new(math.cos(angle) * 0.65, 0.55, math.sin(angle) * 0.65)
		spike.Parent = character
		weld(spike, base)
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150))
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Rate = 6
	sparkle.Speed = NumberRange.new(0.5, 1)
	sparkle.Size = NumberSequence.new(0.4)
	sparkle.Parent = base
end

local function addAuraRing(character: Model, root: BasePart)
	local emitter = Instance.new("Attachment")
	emitter.Name = "Cosmetic_AuraRing"
	emitter.Position = Vector3.new(0, -2.9, 0)
	emitter.Parent = root
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(Color3.fromRGB(180, 110, 255))
	particles.Lifetime = NumberRange.new(0.5, 0.9)
	particles.Rate = 24
	particles.Speed = NumberRange.new(1, 2)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new(0.35)
	particles.Shape = Enum.ParticleEmitterShape.Disc
	particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	particles.Parent = emitter
end

local function addCape(character: Model, root: BasePart)
	local cape = Instance.new("Part")
	cape.Name = "Cosmetic_Cape"
	cape.Size = Vector3.new(2, 3, 0.2)
	cape.Color = Color3.fromRGB(160, 40, 200)
	cape.Material = Enum.Material.Fabric
	cape.CanCollide = false
	cape.Massless = true
	cape.CFrame = root.CFrame * CFrame.new(0, -0.6, 0.9)
	cape.Parent = character
	weld(cape, root)
end

local BUILDERS: { [string]: (Model, BasePart, BasePart) -> () } = {
	CosmeticHalo = function(character, head, _root)
		addHalo(character, head)
	end,
	CosmeticCrown = function(character, head, _root)
		addCrown(character, head)
	end,
	CosmeticAuraRing = function(character, _head, root)
		addAuraRing(character, root)
	end,
	CosmeticCape = function(character, _head, root)
		addCape(character, root)
	end,
}

local function applyCosmetics(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not head or not root then
		return
	end
	for _, attr in COSMETIC_ATTRS do
		if player:GetAttribute(attr) == true then
			local builder = BUILDERS[attr]
			if builder then
				builder(character, head, root)
			end
		end
	end
end

function CosmeticsService.Init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.4)
			applyCosmetics(player)
		end)
		for _, attr in COSMETIC_ATTRS do
			player:GetAttributeChangedSignal(attr):Connect(function()
				applyCosmetics(player)
			end)
		end
	end)
end

return CosmeticsService
