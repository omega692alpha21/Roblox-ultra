--!strict
-- Everyone wears the robe. Faces vanish into shadow under the hood — identity
-- here is membership, not avatar. Members wear black with gold trim; outsiders
-- wear rough undyed gray. Names are hidden; only rank shows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)

local Robes = {}

-- Three tiers of dress, none of them purchasable:
--   outsiders keep their own avatar — they are not one of us yet
--   INITIATES are stripped to a gray tank and shorts: you arrive with nothing
--   MEMBERS and above wear the shroud, trim colored by rank
-- And one robe that exists exactly once: the CULT LEADER's, in deep crimson.
local ROBE = Color3.fromRGB(13, 12, 15)
local LEADER_ROBE = Color3.fromRGB(52, 12, 16)
local LEADER_TRIM = Color3.fromRGB(255, 240, 200)
local PATRON_TRIM = Color3.fromRGB(226, 190, 108)
local VOID = Color3.fromRGB(2, 2, 3)
local TANK = Color3.fromRGB(200, 196, 188)
local SHORTS = Color3.fromRGB(52, 54, 60)

local function mk(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.Massless = true
	p.Material = Enum.Material.Fabric
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function weldTo(anchor: BasePart, p: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = p
	weld.Parent = p
	p.Parent = anchor.Parent
end

local function strip(character: Model, keepFace: boolean)
	for _, child in character:GetDescendants() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Decal") and child.Parent and child.Parent.Name == "Head" then
			if not keepFace then
				child:Destroy() -- the face disappears into the hood
			end
		elseif child:IsA("BasePart") and child.Name:sub(1, 5) == "Robe_" then
			child:Destroy()
		end
	end
end

-- tier: "outsider" | "initiate" | "robe" | "leader"
local function dress(character: Model, tier: string, rankName: string?, patron: boolean, trimOverride: Color3?)
	local head = character:FindFirstChild("Head") :: BasePart?
	-- rig-agnostic: R15 has UpperTorso/LowerTorso, R6 just Torso
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local lower = (character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not torso or not humanoid then
		return
	end
	if tier == "outsider" then
		-- not one of us: their own avatar, their own face, untouched
		for _, child in character:GetDescendants() do
			if child:IsA("BasePart") and child.Name:sub(1, 5) == "Robe_" then
				child:Destroy()
			end
		end
		local existing = head:FindFirstChild("Robe_Rank")
		if existing then
			existing:Destroy()
		end
		return
	end

	strip(character, tier == "initiate")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local robe = if tier == "leader" then LEADER_ROBE else ROBE
	local trim = Color3.fromRGB(96, 92, 88)
	if tier == "leader" then
		trim = LEADER_TRIM
	elseif trimOverride then
		trim = trimOverride
	elseif rankName then
		for _, r in Config.Ranks do
			if r.name == rankName then
				trim = r.trim
			end
		end
	end
	if patron and tier == "robe" then
		trim = PATRON_TRIM
	end

	if tier == "initiate" then
		-- a gray tank and shorts. face shown, name hidden. you came with nothing.
		for _, part in character:GetChildren() do
			if part:IsA("BasePart") then
				if part.Name:find("Torso") or part.Name == "Torso" then
					part.Color = TANK
					part.Material = Enum.Material.Fabric
				elseif part.Name:find("UpperLeg") or part.Name:find("LowerTorso") then
					part.Color = SHORTS
					part.Material = Enum.Material.Fabric
				end
			end
		end
		local existing = head:FindFirstChild("Robe_Rank")
		if existing then
			existing:Destroy()
		end
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Robe_Rank"
		billboard.Size = UDim2.fromScale(4, 1)
		billboard.StudsOffset = Vector3.new(0, 2.2, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 40
		billboard.Parent = head
		local rank = Instance.new("TextLabel")
		rank.Size = UDim2.fromScale(1, 1)
		rank.BackgroundTransparency = 1
		rank.Font = Enum.Font.Michroma
		rank.TextScaled = true
		rank.TextColor3 = trim
		rank.TextTransparency = 0.25
		rank.Text = "INITIATE"
		rank.Parent = billboard
		return
	end

	-- no skin anywhere: head becomes the hood's void, every limb vanishes
	-- under the shroud (the cloak parts below are the whole silhouette)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			if part.Name == "Head" then
				part.Color = VOID
				part.Material = Enum.Material.SmoothPlastic
			elseif part.Name:find("Arm") or part.Name:find("Hand") or part.Name:find("Leg") or part.Name:find("Foot") then
				part.Transparency = 1
			elseif part.Name ~= "HumanoidRootPart" then
				part.Color = robe
				part.Material = Enum.Material.Fabric
			end
		end
	end

	-- deep hood: heavy walls all around, brow hanging low over a pure-black
	-- opening — from the front there is only darkness where a face would be
	weldTo(head, mk({ Name = "Robe_HoodTop", Size = Vector3.new(1.75, 0.5, 1.85), Color = robe, CFrame = head.CFrame * CFrame.new(0, 0.66, 0.12) }))
	weldTo(head, mk({ Name = "Robe_HoodBack", Size = Vector3.new(1.75, 1.8, 0.45), Color = robe, CFrame = head.CFrame * CFrame.new(0, -0.05, 0.82) }))
	weldTo(head, mk({ Name = "Robe_HoodL", Size = Vector3.new(0.42, 1.8, 1.85), Color = robe, CFrame = head.CFrame * CFrame.new(-0.82, -0.05, 0.12) }))
	weldTo(head, mk({ Name = "Robe_HoodR", Size = Vector3.new(0.42, 1.8, 1.85), Color = robe, CFrame = head.CFrame * CFrame.new(0.82, -0.05, 0.12) }))
	weldTo(head, mk({ Name = "Robe_HoodBrow", Size = Vector3.new(1.75, 0.55, 0.7), Color = robe, CFrame = head.CFrame * CFrame.new(0, 0.52, -0.62) * CFrame.Angles(math.rad(-32), 0, 0) }))
	weldTo(head, mk({ Name = "Robe_HoodChin", Size = Vector3.new(1.75, 0.5, 0.4), Color = robe, CFrame = head.CFrame * CFrame.new(0, -0.78, -0.55) }))
	-- the empty face: a flat black panel recessed inside the hood opening
	weldTo(head, mk({ Name = "Robe_FaceVoid", Size = Vector3.new(1.3, 1.3, 0.1), Color = VOID, Material = Enum.Material.SmoothPlastic, CFrame = head.CFrame * CFrame.new(0, -0.05, -0.32) }))
	-- soft peak folding back over the crown
	weldTo(head, mk({ Name = "Robe_HoodPeak", Size = Vector3.new(1.1, 0.55, 1.1), Color = robe, CFrame = head.CFrame * CFrame.new(0, 1.0, 0.3) * CFrame.Angles(math.rad(12), math.rad(45), 0) }))

	-- layered shoulder mantle, broad and sloping like the reference
	weldTo(torso, mk({ Name = "Robe_Mantle1", Size = Vector3.new(3.6, 0.9, 2.3), Color = robe, CFrame = torso.CFrame * CFrame.new(0, 0.62, 0.05) }))
	weldTo(torso, mk({ Name = "Robe_Mantle2", Size = Vector3.new(3.2, 1.0, 2.05), Color = robe, CFrame = torso.CFrame * CFrame.new(0, -0.05, 0.05) }))
	weldTo(torso, mk({ Name = "Robe_MantleL", Size = Vector3.new(0.8, 1.5, 2.0), Color = robe, CFrame = torso.CFrame * CFrame.new(-1.55, 0.15, 0.05) * CFrame.Angles(0, 0, math.rad(14)) }))
	weldTo(torso, mk({ Name = "Robe_MantleR", Size = Vector3.new(0.8, 1.5, 2.0), Color = robe, CFrame = torso.CFrame * CFrame.new(1.55, 0.15, 0.05) * CFrame.Angles(0, 0, math.rad(-14)) }))
	-- thin trim seam at the mantle hem — the only mark of rank
	weldTo(torso, mk({ Name = "Robe_TrimHem", Size = Vector3.new(3.25, 0.09, 2.1), Color = trim, Material = Enum.Material.SmoothPlastic, CFrame = torso.CFrame * CFrame.new(0, -0.58, 0.05) }))
	weldTo(torso, mk({ Name = "Robe_Cape", Size = Vector3.new(2.9, 3.6, 0.25), Color = robe, CFrame = torso.CFrame * CFrame.new(0, -1.0, 0.95) }))
	if lower then
		-- floor-length body of the shroud, flaring as it falls
		weldTo(lower, mk({ Name = "Robe_Drape1", Size = Vector3.new(2.7, 1.6, 1.8), Color = robe, CFrame = lower.CFrame * CFrame.new(0, -0.55, 0) }))
		weldTo(lower, mk({ Name = "Robe_Drape2", Size = Vector3.new(3.05, 1.5, 2.05), Color = robe, CFrame = lower.CFrame * CFrame.new(0, -1.95, 0) }))
	end

	-- rank sigil floating faintly above the hood
	local existing = head:FindFirstChild("Robe_Rank")
	if existing then
		existing:Destroy()
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Robe_Rank"
	billboard.Size = UDim2.fromScale(4, 1)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 40
	billboard.Parent = head
	local rank = Instance.new("TextLabel")
	rank.Size = UDim2.fromScale(1, 1)
	rank.BackgroundTransparency = 1
	rank.Font = Enum.Font.Michroma
	rank.TextScaled = true
	rank.TextColor3 = trim
	rank.TextTransparency = 0.25
	rank.Text = if tier == "leader" then "☩ CULT LEADER" else (if rankName then ("◆ " .. rankName) else "")
	rank.Parent = billboard

	if tier == "leader" then
		-- the 1/1: a crown of gold thread around the hood, and a taller peak
		weldTo(head, mk({ Name = "Robe_LeaderBand", Size = Vector3.new(1.85, 0.14, 1.95), Color = LEADER_TRIM, Material = Enum.Material.Metal, CFrame = head.CFrame * CFrame.new(0, 0.45, 0.1) }))
		weldTo(head, mk({ Name = "Robe_LeaderPeak", Size = Vector3.new(0.8, 0.9, 0.8), Color = robe, CFrame = head.CFrame * CFrame.new(0, 1.5, 0.32) * CFrame.Angles(math.rad(16), math.rad(45), 0) }))
		weldTo(torso, mk({ Name = "Robe_LeaderChain", Size = Vector3.new(2.4, 0.16, 0.16), Color = LEADER_TRIM, Material = Enum.Material.Metal, CFrame = torso.CFrame * CFrame.new(0, 0.35, -1.06) * CFrame.Angles(0, 0, math.rad(4)) }))
	end
end

function Robes.Init()
	local function hook(player: Player)
		local function redress()
			local character = player.Character
			if not character then
				return
			end
			local initiated = player:GetAttribute("Initiated") == true
			local rankName = tostring(player:GetAttribute("Rank") or "INITIATE")
			local tier = "outsider"
			if player:GetAttribute("CultLeader") == true then
				tier = "leader"
			elseif initiated and rankName ~= "INITIATE" then
				tier = "robe"
			elseif initiated then
				tier = "initiate"
			end
			-- a founded cult colors its leader's trim
			local cultColor: Color3? = nil
			local colorIndex = tonumber(player:GetAttribute("CultColor"))
			if colorIndex and Config.CultColors[colorIndex] then
				cultColor = Config.CultColors[colorIndex]
			end
			dress(character, tier, rankName, player:GetAttribute("Patron") == true, cultColor)
		end
		local function onCharacter(character: Model)
			-- the avatar's real appearance (skin, clothes, hats) streams in
			-- AFTER CharacterAdded and would overwrite the shroud — so dress
			-- once now, again when appearance finishes, and once more late.
			task.wait(0.4)
			redress()
			character.ChildAdded:Connect(function(child)
				-- outsiders keep their own look; the dressed tiers stay stripped
				if player:GetAttribute("Initiated") ~= true then
					return
				end
				if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") then
					task.wait()
					child:Destroy()
				end
			end)
			task.delay(2.5, redress)
			task.delay(6, redress)
		end
		player.CharacterAppearanceLoaded:Connect(function()
			task.wait(0.1)
			redress()
		end)
		player.CharacterAdded:Connect(onCharacter)
		player:GetAttributeChangedSignal("Rank"):Connect(redress)
		player:GetAttributeChangedSignal("Initiated"):Connect(redress)
		player:GetAttributeChangedSignal("Patron"):Connect(redress)
		player:GetAttributeChangedSignal("CultLeader"):Connect(redress)
		player:GetAttributeChangedSignal("CultColor"):Connect(redress)
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
