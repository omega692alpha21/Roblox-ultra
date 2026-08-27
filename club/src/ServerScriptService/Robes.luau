--!strict
-- Everyone wears the robe. Faces vanish into shadow under the hood — identity
-- here is membership, not avatar. Members wear black with gold trim; outsiders
-- wear rough undyed gray. Names are hidden; only rank shows.

local Players = game:GetService("Players")

local Robes = {}

local MEMBER_ROBE = Color3.fromRGB(22, 20, 26)
local MEMBER_TRIM = Color3.fromRGB(212, 175, 85)
local GUEST_ROBE = Color3.fromRGB(74, 71, 68)
local GUEST_TRIM = Color3.fromRGB(105, 100, 94)
local VOID = Color3.fromRGB(8, 8, 11)

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

local function strip(character: Model)
	for _, child in character:GetDescendants() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Decal") and child.Parent and child.Parent.Name == "Head" then
			child:Destroy() -- the face disappears into the hood
		elseif child:IsA("BasePart") and child.Name:sub(1, 5) == "Robe_" then
			child:Destroy()
		end
	end
end

local function dress(character: Model, isMember: boolean)
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local lower = character:FindFirstChild("LowerTorso") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not torso or not humanoid then
		return
	end
	strip(character)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local robe = isMember and MEMBER_ROBE or GUEST_ROBE
	local trim = isMember and MEMBER_TRIM or GUEST_TRIM

	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			if part.Name == "Head" then
				part.Color = VOID
				part.Material = Enum.Material.SmoothPlastic
			elseif part.Name:find("Hand") then
				part.Color = VOID
				part.Material = Enum.Material.SmoothPlastic
			elseif part.Name ~= "HumanoidRootPart" then
				part.Color = robe
				part.Material = Enum.Material.Fabric
			end
		end
	end

	-- hood: cowl slabs wrapping the head, brow overhanging the face
	weldTo(head, mk({ Name = "Robe_HoodTop", Size = Vector3.new(1.5, 0.42, 1.5), Color = robe, CFrame = head.CFrame * CFrame.new(0, 0.62, 0.06) }))
	weldTo(head, mk({ Name = "Robe_HoodBack", Size = Vector3.new(1.5, 1.5, 0.34), Color = robe, CFrame = head.CFrame * CFrame.new(0, 0.05, 0.72) }))
	weldTo(head, mk({ Name = "Robe_HoodL", Size = Vector3.new(0.32, 1.5, 1.5), Color = robe, CFrame = head.CFrame * CFrame.new(-0.72, 0.05, 0.06) }))
	weldTo(head, mk({ Name = "Robe_HoodR", Size = Vector3.new(0.32, 1.5, 1.5), Color = robe, CFrame = head.CFrame * CFrame.new(0.72, 0.05, 0.06) }))
	weldTo(head, mk({ Name = "Robe_HoodBrow", Size = Vector3.new(1.5, 0.5, 0.5), Color = robe, CFrame = head.CFrame * CFrame.new(0, 0.5, -0.6) * CFrame.Angles(math.rad(-24), 0, 0) }))
	-- pointed peak
	weldTo(head, mk({ Name = "Robe_HoodPeak", Size = Vector3.new(0.9, 0.6, 0.9), Color = robe, CFrame = head.CFrame * CFrame.new(0, 0.95, 0.18) * CFrame.Angles(0, math.rad(45), 0) }))

	-- shoulder cowl + chest trim + rope belt + back cape + skirt
	weldTo(torso, mk({ Name = "Robe_Cowl", Size = Vector3.new(2.9, 0.85, 1.7), Color = robe, CFrame = torso.CFrame * CFrame.new(0, 0.65, 0) }))
	weldTo(torso, mk({ Name = "Robe_TrimV", Size = Vector3.new(0.3, 1.7, 0.12), Color = trim, Material = Enum.Material.SmoothPlastic, CFrame = torso.CFrame * CFrame.new(-0.45, -0.1, -0.6) }))
	weldTo(torso, mk({ Name = "Robe_TrimV2", Size = Vector3.new(0.3, 1.7, 0.12), Color = trim, Material = Enum.Material.SmoothPlastic, CFrame = torso.CFrame * CFrame.new(0.45, -0.1, -0.6) }))
	weldTo(torso, mk({ Name = "Robe_Cape", Size = Vector3.new(2.3, 3.2, 0.22), Color = robe, CFrame = torso.CFrame * CFrame.new(0, -0.7, 0.75) }))
	if lower then
		weldTo(lower, mk({ Name = "Robe_Belt", Size = Vector3.new(2.15, 0.28, 1.35), Color = trim, Material = Enum.Material.SmoothPlastic, CFrame = lower.CFrame * CFrame.new(0, 0.32, 0) }))
		weldTo(lower, mk({ Name = "Robe_Skirt", Size = Vector3.new(2.35, 2.3, 1.55), Color = robe, CFrame = lower.CFrame * CFrame.new(0, -1.15, 0) }))
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
	rank.Text = isMember and "◆ MEMBER" or "OUTSIDER"
	rank.Parent = billboard
end

function Robes.Init()
	local function hook(player: Player)
		local function redress()
			if player.Character then
				dress(player.Character, player:GetAttribute("ClubMember") == true)
			end
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.6)
			redress()
		end)
		player:GetAttributeChangedSignal("ClubMember"):Connect(redress)
		if player.Character then
			task.wait(0.6)
			redress()
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		task.spawn(hook, player)
	end
end

return Robes
