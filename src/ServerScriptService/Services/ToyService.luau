--!strict
-- Contraband: the slingshot, snowballs and firecrackers. Everything is a real
-- Tool so mobile gets the standard activate button, and every shot is
-- validated on the server — the client only ever asks to fire in a direction.
--
-- Nothing here does damage. Toys knock people around, slow them down and make
-- noise, which is what makes a school fight funny instead of lethal.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local AuraService = require(script.Parent.AuraService)
local ActionAnim = require(script.Parent.ActionAnim)
local EffectsService = require(script.Parent.EffectsService)
local VitalsService = require(script.Parent.VitalsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Signals = require(script.Parent.Parent.Signals)

local ToyService = {}

export type ToyDef = {
	id: string,
	name: string,
	price: number,
	ammoPerBuy: number, -- 0 = permanent, no ammo
	cooldown: number,
	speed: number, -- launch speed, studs/s — the ballistic solve works from this
	desc: string,
}

local TOYS: { ToyDef } = {
	{ id = "slingshot", name = "Slingshot", price = 500, ammoPerBuy = 0, cooldown = 0.75, speed = 160,
	  desc = "Pebbles. Unlimited. Flat and fast — knocks people off their feet." },
	{ id = "snowball", name = "Snowballs", price = 200, ammoPerBuy = 10, cooldown = 0.5, speed = 95,
	  desc = "Ten to a bundle. Lobs in an arc. A hit slows them to a waddle." },
	{ id = "firecracker", name = "Firecrackers", price = 800, ammoPerBuy = 5, cooldown = 1.4, speed = 78,
	  desc = "Five to a pack. Big bang, bigger blast — and prefects hear it." },
}

local lastFire: { [Player]: number } = {}

local function findDef(id: string): ToyDef?
	for _, def in TOYS do
		if def.id == id then
			return def
		end
	end
	return nil
end

function ToyService.Defs(): { ToyDef }
	return TOYS
end

local function ammoOf(player: Player, id: string): number
	return tonumber(player:GetAttribute("Ammo_" .. id)) or 0
end

local function setAmmo(player: Player, id: string, count: number)
	player:SetAttribute("Ammo_" .. id, count)
	local profile = DataService.Get(player)
	if profile then
		local toys = (profile :: any).toys
		if typeof(toys) ~= "table" then
			toys = {}
			(profile :: any).toys = toys
		end
		toys[id] = count
	end
end

-- ---------------------------------------------------------------- tools ---
local function buildTool(def: ToyDef): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("ToyId", def.id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1.6, 0.5)
	handle.CanCollide = false
	handle.Parent = tool

	if def.id == "slingshot" then
		handle.Color = Color3.fromRGB(122, 84, 50)
		handle.Material = Enum.Material.Wood
		local forkL = Instance.new("Part")
		forkL.Name = "Fork"
		forkL.Size = Vector3.new(0.22, 1.1, 0.22)
		forkL.Color = handle.Color
		forkL.Material = Enum.Material.Wood
		forkL.CanCollide = false
		forkL.CFrame = handle.CFrame * CFrame.new(-0.34, 1.2, 0) * CFrame.Angles(0, 0, math.rad(14))
		forkL.Parent = tool
		local weldL = Instance.new("WeldConstraint")
		weldL.Part0 = handle
		weldL.Part1 = forkL
		weldL.Parent = forkL
		local forkR = forkL:Clone()
		forkR.CFrame = handle.CFrame * CFrame.new(0.34, 1.2, 0) * CFrame.Angles(0, 0, math.rad(-14))
		forkR.Parent = tool
		local weldR = Instance.new("WeldConstraint")
		weldR.Part0 = handle
		weldR.Part1 = forkR
		weldR.Parent = forkR
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(0.9, 0.12, 0.12)
		band.Color = Color3.fromRGB(60, 52, 48)
		band.CanCollide = false
		band.CFrame = handle.CFrame * CFrame.new(0, 1.75, 0)
		band.Parent = tool
		local weldB = Instance.new("WeldConstraint")
		weldB.Part0 = handle
		weldB.Part1 = band
		weldB.Parent = band
	elseif def.id == "snowball" then
		handle.Shape = Enum.PartType.Ball
		handle.Size = Vector3.new(1.1, 1.1, 1.1)
		handle.Color = Color3.fromRGB(238, 246, 252)
		handle.Material = Enum.Material.Sand
	else
		handle.Size = Vector3.new(0.6, 1.5, 0.6)
		handle.Color = Color3.fromRGB(196, 58, 52)
		handle.Material = Enum.Material.SmoothPlastic
		local fuse = Instance.new("Part")
		fuse.Name = "Fuse"
		fuse.Size = Vector3.new(0.14, 0.5, 0.14)
		fuse.Color = Color3.fromRGB(224, 208, 160)
		fuse.CanCollide = false
		fuse.CFrame = handle.CFrame * CFrame.new(0, 1, 0)
		fuse.Parent = tool
		local weldF = Instance.new("WeldConstraint")
		weldF.Part0 = handle
		weldF.Part1 = fuse
		weldF.Parent = fuse
	end
	return tool
end

local TEMPLATES: { [string]: Tool } = {}

function ToyService.Give(player: Player, id: string)
	local def = findDef(id)
	local template = TEMPLATES[id]
	if not def or not template then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	if backpack:FindFirstChild(def.name) then
		return -- already in the bag
	end
	local character = player.Character
	if character and character:FindFirstChild(def.name) then
		return -- already in hand
	end
	player:SetAttribute("Owns_" .. def.id, true)
	local tool = template:Clone()
	tool.Parent = backpack
end

-- --------------------------------------------------------------- firing ---
local function knock(target: Model, from: Vector3, force: number)
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local dir = (root.Position - from)
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(0, 0, 1)
	end
	local push = Instance.new("BodyVelocity")
	push.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	push.Velocity = dir.Unit * force + Vector3.new(0, force * 0.35, 0)
	push.Parent = root
	Debris:AddItem(push, 0.18)
end

local function slowTarget(player: Player, seconds: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	player:SetAttribute("SlowUntil", os.clock() + seconds)
	humanoid.WalkSpeed = 8
	task.delay(seconds, function()
		local until_ = tonumber(player:GetAttribute("SlowUntil")) or 0
		if until_ <= os.clock() and humanoid.Parent then
			humanoid.WalkSpeed = 16
			player:SetAttribute("SlowUntil", nil)
		end
	end)
end

local function playerOf(part: BasePart): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model) or nil
end

-- Launch velocity that lands a projectile of the given speed on `target`.
--
-- Aiming used to send the camera's look direction straight through as the
-- velocity, so a shot fired from the chest of a player the camera looks *down*
-- at went wherever it liked. Solving the trajectory instead means the shot
-- lands where the crosshair is, which is what makes aiming a mechanic.
local function ballistic(origin: Vector3, target: Vector3, speed: number): Vector3
	local delta = target - origin
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local distance = flat.Magnitude
	local g = workspace.Gravity
	if distance < 0.1 or g <= 0 then
		return (delta.Magnitude > 0.01 and delta.Unit or Vector3.new(0, 1, 0)) * speed
	end
	local v2 = speed * speed
	local discriminant = v2 * v2 - g * (g * distance * distance + 2 * delta.Y * v2)
	if discriminant < 0 then
		-- out of range: throw as far as we can along the line to the target
		return delta.Unit * speed
	end
	-- the low arc: the flatter of the two solutions, which reads as a throw
	local tangent = (v2 - math.sqrt(discriminant)) / (g * distance)
	local horizontal = speed / math.sqrt(1 + tangent * tangent)
	return flat.Unit * horizontal + Vector3.new(0, horizontal * tangent, 0)
end

local function fireProjectile(shooter: Player, def: ToyDef, origin: Vector3, velocity: Vector3)
	local pellet = Instance.new("Part")
	pellet.Name = "ToyProjectile"
	pellet.Shape = Enum.PartType.Ball
	pellet.CanCollide = false
	pellet.Massless = true
	pellet.CFrame = CFrame.new(origin)

	if def.id == "slingshot" then
		pellet.Size = Vector3.new(0.45, 0.45, 0.45)
		pellet.Color = Color3.fromRGB(102, 96, 88)
		pellet.Material = Enum.Material.Slate
	elseif def.id == "snowball" then
		pellet.Size = Vector3.new(1, 1, 1)
		pellet.Color = Color3.fromRGB(240, 248, 255)
		pellet.Material = Enum.Material.Sand
	else
		pellet.Size = Vector3.new(0.7, 1.4, 0.7)
		pellet.Shape = Enum.PartType.Cylinder
		pellet.Color = Color3.fromRGB(196, 58, 52)
	end
	-- the ballistic solve owns the velocity now; gravity does the rest
	pellet.Massless = false
	pellet.CanQuery = false
	pellet.CastShadow = false
	-- a trail: a projectile you can actually follow is a projectile you can
	-- learn to lead
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.2, 0)
	a0.Parent = pellet
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.2, 0)
	a1.Parent = pellet
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.28
	trail.MinLength = 0.1
	trail.LightEmission = 0.4
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(pellet.Color)
	trail.Parent = pellet
	pellet.CFrame = CFrame.lookAt(origin, origin + velocity.Unit)
	pellet.AssemblyLinearVelocity = velocity
	pellet.Parent = workspace
	Debris:AddItem(pellet, 6)

	local spent = false
	local function detonate(at: Vector3, hitPlayer: Player?)
		if spent then
			return
		end
		spent = true
		if def.id == "firecracker" then
			-- bang: everyone nearby gets shoved, and the noise carries
			EffectsService.Hit(at, Color3.fromRGB(255, 168, 64), "Bang", 40)
			local flash = Instance.new("Explosion")
			flash.Position = at
			flash.BlastRadius = 14
			flash.BlastPressure = 0
			flash.DestroyJointRadiusPercent = 0
			flash.ExplosionType = Enum.ExplosionType.NoCraters
			flash.Parent = workspace
			for _, other in Players:GetPlayers() do
				local character = other.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (root.Position - at).Magnitude < 16 then
					knock(character :: Model, at, 62)
					Remotes.Get("ScreenFx"):FireClient(other, "shake", 1.2)
					if other ~= shooter then
						-- closer to the bang, more of it
						local falloff = 1 - (root.Position - at).Magnitude / 16
						VitalsService.Damage(other, 8 + 14 * falloff, shooter)
					end
				end
			end
			Remotes.Get("Notify"):FireAllClients(shooter.DisplayName .. " set off a FIRECRACKER!", "info")
			AuraService.Add(shooter, 3)
		elseif hitPlayer then
			local character = hitPlayer.Character
			if character then
				knock(character, at, def.id == "slingshot" and 46 or 34)
			end
			EffectsService.Hit(
				at,
				def.id == "snowball" and Color3.fromRGB(235, 245, 255) or Color3.fromRGB(190, 180, 165),
				"Impact",
				16
			)
			VitalsService.Damage(hitPlayer, def.id == "slingshot" and 14 or 7, shooter)
			if def.id == "snowball" then
				slowTarget(hitPlayer, 3)
				Remotes.Get("Notify"):FireClient(hitPlayer, "❄️ " .. shooter.DisplayName .. " got you with a snowball!", "info")
			else
				Remotes.Get("Notify"):FireClient(hitPlayer, "🪨 " .. shooter.DisplayName .. " pinged you with a slingshot!", "info")
			end
			AuraService.Add(shooter, 1)
		end
		pellet:Destroy()
	end

	pellet.Touched:Connect(function(hit)
		local hitPlayer = playerOf(hit)
		if hitPlayer == shooter then
			return
		end
		detonate(pellet.Position, hitPlayer)
	end)
	if def.id == "firecracker" then
		task.delay(1.5, function()
			if pellet.Parent then
				detonate(pellet.Position, nil)
			end
		end)
	end
end

-- ----------------------------------------------------------------- init ---
local function initRestore()
	local function restore(player: Player)
		local profile = DataService.Get(player)
		local toys = profile and (profile :: any).toys
		if typeof(toys) == "table" then
			for id, count in toys :: any do
				player:SetAttribute("Ammo_" .. tostring(id), count)
				if tonumber(count) and tonumber(count) > 0 then
					ToyService.Give(player, tostring(id))
				end
			end
		end
		-- everybody starts with a slingshot: it is the toy the game is about
		ToyService.Give(player, "slingshot")
		-- the creator carries the full kit, stocked, for testing
		if player.UserId == 11578479542 then
			for _, def in TOYS do
				if def.ammoPerBuy > 0 then
					setAmmo(player, def.id, math.max(ammoOf(player, def.id), 99))
				end
				player:SetAttribute("Owns_" .. def.id, true)
				ToyService.Give(player, def.id)
			end
		end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			restore(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(restore, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastFire[player] = nil
	end)

	local _ = GameConfig
end


-- The toy cart: a stall in the west courtyard with a prompt per toy.
local function buildCart(parent: Instance)
	local function part(props: { [string]: any }): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		for k, v in props do
			(p :: any)[k] = v
		end
		p.Parent = parent
		return p
	end
	local base = Vector3.new(-116, 0, 34)
	part({ Name = "ToyCartBody", Size = Vector3.new(14, 6, 7), CFrame = CFrame.new(base + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(178, 60, 56) })
	part({ Name = "ToyCartCounter", Size = Vector3.new(15, 0.6, 8), CFrame = CFrame.new(base + Vector3.new(0, 6.3, 0)), Color = Color3.fromRGB(226, 220, 208) })
	part({ Name = "ToyCartPost", Size = Vector3.new(0.6, 8, 0.6), CFrame = CFrame.new(base + Vector3.new(-6.6, 4, -3.2)), Color = Color3.fromRGB(96, 62, 42), Material = Enum.Material.WoodPlanks })
	part({ Name = "ToyCartPost", Size = Vector3.new(0.6, 8, 0.6), CFrame = CFrame.new(base + Vector3.new(6.6, 4, -3.2)), Color = Color3.fromRGB(96, 62, 42), Material = Enum.Material.WoodPlanks })
	local awning = part({ Name = "ToyCartAwning", Size = Vector3.new(16, 0.5, 9), CFrame = CFrame.new(base + Vector3.new(0, 8.2, -0.6)) * CFrame.Angles(math.rad(-9), 0, 0), Color = Color3.fromRGB(240, 236, 226) })
	local sign = part({ Name = "ToyCartSign", Size = Vector3.new(11, 2.6, 0.4), CFrame = CFrame.new(base + Vector3.new(0, 10, -3.4)), Color = Color3.fromRGB(30, 34, 46) })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 200, 64)
	label.Text = "TOY CART"
	label.Parent = gui
	local _ = awning

	for i, def in TOYS do
		local shelf = part({
			Name = "ToySlot_" .. def.id,
			Size = Vector3.new(3.2, 3.2, 3.2),
			CFrame = CFrame.new(base + Vector3.new(-4.6 + (i - 1) * 4.6, 8.2, 0)),
			Color = Color3.fromRGB(250, 246, 236),
			Transparency = 1,
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = ("$%d"):format(def.price)
		prompt.ObjectText = def.name
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = shelf
		prompt.Triggered:Connect(function(player)
			ToyService.Buy(player, def.id)
		end)
	end
end

function ToyService.Init()
	for _, def in TOYS do
		TEMPLATES[def.id] = buildTool(def)
	end

	Remotes.Get("UseToy").OnServerEvent:Connect(function(player: Player, toyId, aimPoint)
		if typeof(toyId) ~= "string" or typeof(aimPoint) ~= "Vector3" then
			return
		end
		local def = findDef(toyId)
		if not def then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		-- ownership, not "currently equipped": the HUD action button is the
		-- control surface, and Roblox does not give tools a reliable fire
		-- button on phones
		if def.ammoPerBuy == 0 then
			local owned = player:GetAttribute("Owns_" .. def.id) == true
			if not owned then
				return
			end
		end
		local now = os.clock()
		if now - (lastFire[player] or 0) < def.cooldown then
			return
		end
		if def.ammoPerBuy > 0 then
			local have = ammoOf(player, def.id)
			if have <= 0 then
				Remotes.Get("Notify"):FireClient(player, "Out of " .. def.name:lower() .. ". Buy more at the toy cart.", "bad")
				return
			end
			setAmmo(player, def.id, have - 1)
		end
		lastFire[player] = now
		-- the client sends the world point under its crosshair; we re-solve the
		-- throw here so a spoofed point can only ever pick a legal target
		local muzzle = root.Position + Vector3.new(0, 1.6, 0)
		local aim: Vector3
		if typeof(aimPoint) == "Vector3" and (aimPoint - muzzle).Magnitude < 600 then
			aim = aimPoint
		else
			aim = muzzle + root.CFrame.LookVector * 60
		end
		local toAim = aim - muzzle
		local flat = Vector3.new(toAim.X, 0, toAim.Z)
		local facing = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
		local origin = muzzle + facing * 2.2
		local velocity = ballistic(origin, aim, def.speed)
		if character then
			ActionAnim.Throw(character)
		end
		EffectsService.PlaySound(root, "Throw")
		Signals.ToyUsed:Fire(player, def.id)
		-- let the arm come over the top before the projectile leaves the hand
		task.delay(0.15, function()
			fireProjectile(player, def, origin, velocity)
		end)
	end)

	-- the toy cart: buy with lunch money, no Robux anywhere near it
	Remotes.Get("BuyToy").OnServerEvent:Connect(function(player, toyId)
		if typeof(toyId) == "string" then
			ToyService.Buy(player, toyId)
		end
	end)

	buildCart(workspace:FindFirstChild("CrumbworthHigh") or workspace)
	initRestore()
end

function ToyService.Buy(player: Player, toyId: string)
	do
		local def = findDef(toyId)
		local profile = DataService.Get(player)
		if not def or not profile then
			return
		end
		if profile.cash < def.price then
			Remotes.Get("Notify"):FireClient(player, ("You need $%d for %s."):format(def.price, def.name), "bad")
			return
		end
		EconomyService.AddCash(player, -def.price, false)
		if def.ammoPerBuy > 0 then
			setAmmo(player, def.id, ammoOf(player, def.id) + def.ammoPerBuy)
			Remotes.Get("Notify"):FireClient(player, ("+%d %s!"):format(def.ammoPerBuy, def.name), "good")
		else
			Remotes.Get("Notify"):FireClient(player, def.name .. " acquired. Aim well.", "good")
		end
		ToyService.Give(player, def.id)
	end
end


return ToyService
