--!strict
-- Starter characters: THE TROUBLEMAKER (navy D-crest sweater, spiky hair,
-- bandage, backpack) and THE REBEL (white shirt, plaid skirt + tie, bun,
-- bubblegum). Dresses the player's avatar from parts to match the key art.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)

local CharacterService = {}

local PLAID = "rbxassetid://71470471832661"
local TIE_STRIPE = "rbxassetid://105881903902095"

local NAVY = Color3.fromRGB(38, 50, 96)
local BLACK_PANTS = Color3.fromRGB(38, 38, 44)
local SHOE_NAVY = Color3.fromRGB(28, 36, 70)
local WHITE = Color3.fromRGB(242, 242, 240)
local HAIR_BROWN = Color3.fromRGB(74, 52, 34)
local HAIR_BLACK = Color3.fromRGB(24, 22, 24)
local GOLD = Color3.fromRGB(224, 178, 60)

local function weldTo(anchor: BasePart, p: BasePart)
	p.CanCollide = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = p
	weld.Parent = p
	p.Parent = anchor.Parent
end

local function mk(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function clearOutfit(character: Model)
	for _, child in character:GetDescendants() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("BasePart") and child.Name:sub(1, 7) == "Outfit_" then
			child:Destroy()
		end
	end
end

local function recolor(character: Model, matcher: (string) -> Color3?)
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") then
			local color = matcher(child.Name)
			if color then
				child.Color = color
			end
		end
	end
end

local function addTie(head: BasePart, torso: BasePart, texture: string)
	local collar = mk({ Name = "Outfit_Collar", Size = Vector3.new(1.35, 0.28, 1.1), Color = WHITE, CFrame = torso.CFrame * CFrame.new(0, 0.78, 0) })
	weldTo(torso, collar)
	local tie = mk({ Name = "Outfit_Tie", Size = Vector3.new(0.44, 1.4, 0.12), Color = NAVY, CFrame = torso.CFrame * CFrame.new(0, 0.05, -0.55) })
	local decal = Instance.new("Decal")
	decal.Texture = texture
	decal.Face = Enum.NormalId.Front
	decal.Parent = tie
	weldTo(torso, tie)
	local _ = head
end

local function addCrest(torso: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Outfit_Crest"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.Parent = torso
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.72, 0.42)
	label.Size = UDim2.fromScale(0.34, 0.34)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = "Ⓓ"
	label.Parent = gui
end

local function addBackpack(torso: BasePart)
	local pack = mk({ Name = "Outfit_Backpack", Size = Vector3.new(1.5, 1.8, 0.7), Color = NAVY, CFrame = torso.CFrame * CFrame.new(0, 0.1, 0.85) })
	weldTo(torso, pack)
	local pocket = mk({ Name = "Outfit_Pocket", Size = Vector3.new(1.0, 0.9, 0.2), Color = Color3.fromRGB(30, 40, 78), CFrame = torso.CFrame * CFrame.new(0, -0.15, 1.28) })
	weldTo(torso, pocket)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = pack
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = "Ⓓ"
	label.Parent = gui
end

local function addSpikyHair(head: BasePart)
	local base = mk({ Name = "Outfit_HairBase", Size = Vector3.new(1.3, 0.35, 1.2), Color = HAIR_BROWN, CFrame = head.CFrame * CFrame.new(0, 0.62, 0) })
	weldTo(head, base)
	for i = -2, 2 do
		local spike = mk({
			Name = "Outfit_HairSpike",
			Size = Vector3.new(0.28, 0.6, 0.3),
			Color = HAIR_BROWN,
			CFrame = head.CFrame * CFrame.new(i * 0.26, 0.9, (i % 2 == 0) and 0.1 or -0.15) * CFrame.Angles(math.rad((i % 2) * 14), 0, math.rad(i * 14)),
		})
		weldTo(head, spike)
	end
end

local function addBunHair(head: BasePart)
	local base = mk({ Name = "Outfit_HairBase", Size = Vector3.new(1.3, 0.4, 1.2), Color = HAIR_BLACK, CFrame = head.CFrame * CFrame.new(0, 0.62, 0) })
	weldTo(head, base)
	local bun = mk({ Name = "Outfit_HairBun", Size = Vector3.new(0.62, 0.5, 0.62), Color = HAIR_BLACK, CFrame = head.CFrame * CFrame.new(0, 0.98, 0.18) })
	weldTo(head, bun)
	local fringe = mk({ Name = "Outfit_HairFringe", Size = Vector3.new(1.28, 0.34, 0.2), Color = HAIR_BLACK, CFrame = head.CFrame * CFrame.new(0, 0.46, -0.54) * CFrame.Angles(math.rad(-8), 0, 0) })
	weldTo(head, fringe)
	for _, side in { -1, 1 } do
		local strand = mk({ Name = "Outfit_HairStrand", Size = Vector3.new(0.2, 0.9, 0.5), Color = HAIR_BLACK, CFrame = head.CFrame * CFrame.new(side * 0.6, 0.15, 0.1) })
		weldTo(head, strand)
	end
	local tail = mk({ Name = "Outfit_HairTail", Size = Vector3.new(0.4, 1.1, 0.35), Color = HAIR_BLACK, CFrame = head.CFrame * CFrame.new(0, -0.05, 0.66) * CFrame.Angles(math.rad(14), 0, 0) })
	weldTo(head, tail)
end

local function addBandage(head: BasePart)
	local bandage = mk({ Name = "Outfit_Bandage", Size = Vector3.new(0.42, 0.16, 0.06), Color = Color3.fromRGB(232, 202, 160), CFrame = head.CFrame * CFrame.new(-0.28, -0.12, -0.56) * CFrame.Angles(0, 0, math.rad(-18)) })
	weldTo(head, bandage)
end

local function addGum(head: BasePart)
	local gum = mk({ Name = "Outfit_Gum", Size = Vector3.new(0.4, 0.4, 0.4), Color = Color3.fromRGB(244, 178, 198) })
	gum.Shape = Enum.PartType.Ball
	gum.CFrame = head.CFrame * CFrame.new(0.1, -0.22, -0.62)
	weldTo(head, gum)
end

local function addSkirt(character: Model)
	local lower = character:FindFirstChild("LowerTorso") :: BasePart?
	if not lower then
		return
	end
	local skirt = mk({ Name = "Outfit_Skirt", Size = Vector3.new(2.3, 1.15, 1.5), Color = NAVY, CFrame = lower.CFrame * CFrame.new(0, -0.55, 0) })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local decal = Instance.new("Decal")
		decal.Texture = PLAID
		decal.Face = face
		decal.Parent = skirt
	end
	weldTo(lower, skirt)
end

local function dress(character: Model, outfit: string)
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	if not head or not torso then
		return
	end
	clearOutfit(character)
	if outfit == "boy" then
		recolor(character, function(name)
			if name:find("Torso") or name:find("Arm") then
				return NAVY
			elseif name:find("Leg") then
				return BLACK_PANTS
			elseif name:find("Foot") then
				return SHOE_NAVY
			end
			return nil
		end)
		addSpikyHair(head)
		addTie(head, torso, TIE_STRIPE)
		addCrest(torso)
		addBackpack(torso)
		addBandage(head)
	elseif outfit == "girl" then
		recolor(character, function(name)
			if name:find("Torso") or name:find("Arm") then
				return WHITE
			elseif name:find("UpperLeg") then
				return NAVY
			elseif name:find("Foot") then
				return SHOE_NAVY
			end
			return nil
		end)
		addBunHair(head)
		addTie(head, torso, PLAID)
		addSkirt(character)
		addGum(head)
	end
end

local function onChoose(player: Player, outfit: unknown)
	if outfit ~= "boy" and outfit ~= "girl" then
		return
	end
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.outfit = outfit :: string
	player:SetAttribute("Outfit", outfit)
	if player.Character then
		dress(player.Character, outfit :: string)
	end
end

-- Nobody walks Crumbworth in their own Roblox avatar: if a player never
-- picked a starter, they get one by default (userId parity) until they do.
local function outfitFor(player: Player): string
	local profile = DataService.Get(player)
	if profile and profile.outfit then
		return profile.outfit :: string
	end
	local attr = player:GetAttribute("Outfit")
	if attr == "boy" or attr == "girl" then
		return attr :: string
	end
	return (player.UserId % 2 == 0) and "boy" or "girl"
end

function CharacterService.Init()
	Remotes.Get("ChooseCharacter").OnServerEvent:Connect(onChoose)

	local function hook(player: Player)
		local function apply(character: Model)
			dress(character, outfitFor(player))
		end
		player.CharacterAppearanceLoaded:Connect(function(character)
			-- the avatar's real clothes/hats stream in AFTER CharacterAdded
			-- and would overwrite the outfit — dress again once they land
			task.wait(0.1)
			apply(character)
		end)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5)
			apply(character)
			character.ChildAdded:Connect(function(child)
				if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") then
					task.wait()
					child:Destroy()
				end
			end)
			task.delay(2.5, function()
				if character.Parent then
					apply(character)
				end
			end)
		end)
		if player.Character then
			task.spawn(function()
				task.wait(0.5)
				apply(player.Character :: Model)
			end)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	require(script.Parent.Parent.Signals).ProfileLoaded:Connect(function(player, profile)
		if profile.outfit then
			player:SetAttribute("Outfit", profile.outfit)
		end
		if player.Character then
			dress(player.Character, outfitFor(player))
		end
	end)
end

return CharacterService
