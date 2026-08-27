--!strict
-- Custom 3D meshes, authored in code and uploaded via Open Cloud. Replaces
-- the box-part trees with smooth stylized mesh trees at runtime; falls back
-- silently to the part trees if an asset can't load.

local InsertService = game:GetService("InsertService")

local MeshService = {}

local ASSETS = {
	-- painterly flora: hand-painted textures are baked INSIDE these .glb
	-- files, so Roblox's importer applies them at upload time (TextureID
	-- cannot be assigned at runtime). Do not recolour these.
	Tree = 96371665611572,
	Tree2 = 116687956743234,
	Conifer = 86623707243626,
	Rock1 = 119854923753216,
	Rock2 = 139159390912504,
	Tuft = 86994237989339,
	Hedge = 100949482507815,
	Bush = 93546111036418,
	BenchP = 115201833785687,
	LampP = 87843148536695,
	SmallTree = 116514552610924,
	Palm = 120929000216583,
	Arch = 76176860283975,
	LockerBank = 111684152621060,
	Bench = 80409319935408,
	Lamppost = 71751173797781,
}

local TEXTURED: { [number]: boolean } = {
	[ASSETS.Tree] = true, [ASSETS.Tree2] = true, [ASSETS.Conifer] = true,
	[ASSETS.Rock1] = true, [ASSETS.Rock2] = true, [ASSETS.Tuft] = true,
	[ASSETS.Hedge] = true, [ASSETS.Bush] = true, [ASSETS.BenchP] = true,
	[ASSETS.LampP] = true, [ASSETS.SmallTree] = true,
}

local rng = Random.new(17)

-- painterly pipeline: these meshes carry UVs; shading is baked into painted
-- textures assigned at runtime (import drops glTF materials, keeps UVs)
-- Roblox's GLB import ignores glTF material colors, so each asset carries a
-- node-name -> {color, material} style map applied after load.
type Style = { color: Color3, material: Enum.Material? }
local STYLES: { [number]: { [string]: Style } } = {
	[ASSETS.Palm] = {
		part0 = { color = Color3.fromRGB(122, 92, 61), material = Enum.Material.Wood },
		part1 = { color = Color3.fromRGB(61, 128, 56), material = Enum.Material.Grass },
		part2 = { color = Color3.fromRGB(89, 66, 41) },
	},
	[ASSETS.Arch] = {
		part0 = { color = Color3.fromRGB(224, 219, 204), material = Enum.Material.Concrete },
	},
	[ASSETS.LockerBank] = {
		part0 = { color = Color3.fromRGB(36, 64, 140) },
		part1 = { color = Color3.fromRGB(59, 102, 194) },
		part2 = { color = Color3.fromRGB(20, 38, 89) },
		part3 = { color = Color3.fromRGB(209, 212, 219), material = Enum.Material.Metal },
	},
	[ASSETS.Bench] = {
		part0 = { color = Color3.fromRGB(140, 102, 61), material = Enum.Material.Wood },
		part1 = { color = Color3.fromRGB(41, 43, 51), material = Enum.Material.Metal },
	},
	[ASSETS.Lamppost] = {
		part0 = { color = Color3.fromRGB(33, 36, 43), material = Enum.Material.Metal },
		part1 = { color = Color3.fromRGB(33, 36, 43), material = Enum.Material.Metal },
		part2 = { color = Color3.fromRGB(255, 237, 184), material = Enum.Material.Neon },
	},
}

local function loadTemplate(assetId: number): Model?
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not result then
		warn("[MeshService] failed to load asset " .. assetId .. ": " .. tostring(result))
		return nil
	end
	-- LoadAsset wraps content in a Model; find the inner model or wrap parts
	local inner = result:FindFirstChildOfClass("Model")
	local template = Instance.new("Model")
	local source = inner or result
	for _, child in source:GetChildren() do
		if child:IsA("BasePart") or child:IsA("Model") then
			child.Parent = template
		end
	end
	if TEXTURED[assetId] then
		template:SetAttribute("Painted", true)
	end
	local styles = STYLES[assetId]
	local unstyled: { BasePart } = {}
	for _, part in template:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = true
			local style = styles and (styles :: any)[part.Name]
			if style then
				part.Color = style.color
				if style.material then
					part.Material = style.material
				end
			else
				table.insert(unstyled, part)
			end
		end
	end
	-- fallback: importer renamed nodes — apply styles in name order
	if styles and #unstyled > 0 then
		local ordered: { Style } = {}
		for i = 0, 9 do
			local style = (styles :: any)["part" .. i]
			if style then
				table.insert(ordered, style)
			end
		end
		table.sort(unstyled, function(a, b)
			return a.Name < b.Name
		end)
		for i, part in unstyled do
			local style = ordered[math.min(i, #ordered)]
			if style then
				part.Color = style.color
				if style.material then
					part.Material = style.material
				end
			end
		end
	end
	-- NOTE: MeshPart.TextureID is not settable at runtime, so painterly
	-- textures cannot be applied here. Flora reads through per-part colours
	-- plus per-instance hue variation instead (see tintClone below).
	result:Destroy()
	if #template:GetChildren() == 0 then
		return nil
	end
	return template
end

-- Nudge each clone's greens so no two trees are identical — the thing that
-- makes stylised foliage read as painted rather than stamped.
local function tintClone(model: Model, seed: number)
	-- baked-texture meshes carry their own painted shading; leave them alone
	if model:GetAttribute("Painted") then
		return
	end
	local r = Random.new(seed)
	local warm = r:NextNumber(-0.06, 0.08)
	local light = r:NextNumber(-0.07, 0.09)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local h, sat, v = part.Color:ToHSV()
			if sat > 0.15 then
				part.Color = Color3.fromHSV(
					math.clamp(h + warm * 0.12, 0, 1),
					math.clamp(sat + warm, 0, 1),
					math.clamp(v + light, 0.05, 1)
				)
			end
		end
	end
end

function MeshService.Init(map: { folder: Folder })
	local treeTemplate = loadTemplate(ASSETS.Tree)
	local treeTemplate2 = loadTemplate(ASSETS.Tree2)
	if treeTemplate then
		-- collect the box trees first, then swap each for a mesh tree
		local trunks: { BasePart } = {}
		local leaves: { BasePart } = {}
		for _, child in map.folder:GetDescendants() do
			if child:IsA("BasePart") then
				if child.Name == "TreeTrunk" then
					table.insert(trunks, child)
				elseif child.Name == "TreeLeaves" then
					table.insert(leaves, child)
				end
			end
		end
		local flip = false
		for _, trunk in trunks do
			flip = not flip
			local scale = math.clamp(trunk.Size.Y / 7, 0.55, 2.6)
			local base = trunk.Position - Vector3.new(0, trunk.Size.Y / 2, 0)
			local clone = ((flip and treeTemplate2) and treeTemplate2 or treeTemplate):Clone()
			clone.Name = "MeshTree"
			tintClone(clone, math.floor(trunk.Position.X * 7 + trunk.Position.Z * 13))
			clone:ScaleTo(scale)
			local _, size = clone:GetBoundingBox()
			clone:PivotTo(CFrame.new(base + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			clone.Parent = map.folder
			-- remove the old box tree (trunk + its leaf blobs)
			for _, leaf in leaves do
				if leaf.Parent and (leaf.Position - trunk.Position).Magnitude < 12 * scale then
					leaf:Destroy()
				end
			end
			trunk:Destroy()
		end
		print(("[MeshService] replaced %d trees with mesh trees"):format(#trunks))
	end

	-- palms: swap the box palms in the courtyard for real fronds
	local palmTemplate = loadTemplate(ASSETS.Palm)
	if palmTemplate then
		local palmParts: { BasePart } = {}
		for _, child in map.folder:GetDescendants() do
			if child:IsA("BasePart") and (child.Name == "PalmTrunk" or child.Name == "PalmLeaf") then
				table.insert(palmParts, child)
			end
		end
		for _, spot in { Vector3.new(-14, 0, 176), Vector3.new(14, 0, 176) } do
			local clone = palmTemplate:Clone()
			clone.Name = "MeshPalm"
			clone:ScaleTo(1.35)
			local _, size = clone:GetBoundingBox()
			clone:PivotTo(CFrame.new(spot + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			clone.Parent = map.folder
		end
		for _, part in palmParts do
			part:Destroy()
		end
	end

	-- grand entrance arch over the doorway
	local archTemplate = loadTemplate(ASSETS.Arch)
	if archTemplate then
		local clone = archTemplate:Clone()
		clone.Name = "MeshEntranceArch"
		clone:PivotTo(CFrame.new(0, 13.2 + 8.5, 84))
		clone.Parent = map.folder
	end

	-- locker banks: swap flat textured banks for 3D beveled-door meshes
	local lockerTemplate = loadTemplate(ASSETS.LockerBank)
	if lockerTemplate then
		local banks: { BasePart } = {}
		for _, child in map.folder:GetDescendants() do
			if child:IsA("BasePart") and child.Name == "LockerBank" then
				table.insert(banks, child)
			end
		end
		for _, bank in banks do
			local clone = lockerTemplate:Clone()
			clone.Name = "MeshLockerBank"
			-- face the hallway center: banks sit at z = +/-13.2, doors face inward
			local inward = bank.Position.Z > 0 and -1 or 1
			clone:PivotTo(CFrame.new(bank.Position) * CFrame.Angles(0, inward > 0 and 0 or math.pi, 0))
			clone.Parent = map.folder
			bank:Destroy()
		end
		print(("[MeshService] replaced %d locker banks"):format(#banks))
	end

	-- benches: slatted mesh benches replace the box seats
	local benchTemplate = loadTemplate(ASSETS.Bench)
	if benchTemplate then
		local seats: { BasePart } = {}
		local legs: { BasePart } = {}
		for _, child in map.folder:GetDescendants() do
			if child:IsA("BasePart") then
				if child.Name == "BenchSeat" then
					table.insert(seats, child)
				elseif child.Name == "BenchLeg" then
					table.insert(legs, child)
				end
			end
		end
		for _, seat in seats do
			local clone = benchTemplate:Clone()
			clone.Name = "MeshBench"
			local backToWall = seat.Position.Z > 0 and 0 or math.pi
			clone:PivotTo(CFrame.new(seat.Position.X, 0, seat.Position.Z) * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, backToWall, 0))
			clone.Parent = map.folder
			seat:Destroy()
		end
		for _, leg in legs do
			leg:Destroy()
		end
	end

	-- lampposts: curved-arm mesh lamps with warm light, replacing post+cube
	local lampTemplate = loadTemplate(ASSETS.Lamppost)
	if lampTemplate then
		local posts: { BasePart } = {}
		local heads: { BasePart } = {}
		for _, child in map.folder:GetDescendants() do
			if child:IsA("BasePart") then
				if child.Name == "LampPost" then
					table.insert(posts, child)
				elseif child.Name == "LampHead" then
					table.insert(heads, child)
				end
			end
		end
		for _, post in posts do
			local clone = lampTemplate:Clone()
			clone.Name = "MeshLamppost"
			local base = post.Position - Vector3.new(0, post.Size.Y / 2, 0)
			clone:PivotTo(CFrame.new(base) * CFrame.new(0, 4.7, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			clone.Parent = map.folder
			-- re-add the light on the mesh head
			for _, meshPart in clone:GetDescendants() do
				if meshPart:IsA("BasePart") and meshPart.Color.R > 0.9 then
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 234, 190)
					light.Brightness = 1.2
					light.Range = 24
					light.Parent = meshPart
					meshPart.Material = Enum.Material.Neon
				end
			end
			post:Destroy()
		end
		for _, head in heads do
			head:Destroy()
		end
	end

	-- painterly scatter: rocks along the treeline, grass tufts on the lawns
	local rock1 = loadTemplate(ASSETS.Rock1)
	local rock2 = loadTemplate(ASSETS.Rock2)
	local tuft = loadTemplate(ASSETS.Tuft)
	local conifer = loadTemplate(ASSETS.Conifer)
	local scatterRng = Random.new(41)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local d = scatterRng:NextNumber(120, 165)
		local pos = Vector3.new(math.sin(a) * d, 0, math.cos(a) * d + 100)
		local template = (i % 2 == 0) and rock1 or rock2
		if template then
			local clone = template:Clone()
			clone.Name = "PaintRock"
			tintClone(clone, i * 31 + 5)
			clone:ScaleTo(scatterRng:NextNumber(0.8, 2.2))
			clone:PivotTo(CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, scatterRng:NextNumber(0, math.pi * 2), 0))
			clone.Parent = map.folder
		end
	end
	if tuft then
		for _ = 1, 90 do
			local x = scatterRng:NextNumber(-140, 140)
			local z = scatterRng:NextNumber(-30, 210)
			if math.abs(x) > 24 or z > 130 then -- keep walkways clean
				local clone = tuft:Clone()
				clone.Name = "PaintTuft"
				tintClone(clone, math.floor(x * 3 + z * 11))
				clone:ScaleTo(scatterRng:NextNumber(0.8, 1.6))
				clone:PivotTo(CFrame.new(x, 0.1, z) * CFrame.Angles(0, scatterRng:NextNumber(0, math.pi * 2), 0))
				clone.Parent = map.folder
			end
		end
	end
	if conifer then
		for _, spot in { Vector3.new(-30, 0, 96), Vector3.new(30, 0, 96), Vector3.new(-52, 0, 118), Vector3.new(52, 0, 118) } do
			local clone = conifer:Clone()
			clone.Name = "PaintConifer"
			tintClone(clone, math.floor(spot.X * 5 + spot.Z * 3))
			clone:ScaleTo(scatterRng:NextNumber(1.1, 1.5))
			local _, size = clone:GetBoundingBox()
			clone:PivotTo(CFrame.new(spot + Vector3.new(0, size.Y / 2, 0)))
			clone.Parent = map.folder
		end
	end

	-- ---- painted landscaping: the density that sells the reference look ----
	local bush = loadTemplate(ASSETS.Bush)
	local smallTree = loadTemplate(ASSETS.SmallTree)
	local benchP = loadTemplate(ASSETS.BenchP)
	local lampP = loadTemplate(ASSETS.LampP)
	local landRng = Random.new(613)

	local function place(template: Model?, name: string, cf: CFrame, scale: number)
		if not template then
			return
		end
		local clone = template:Clone()
		clone.Name = name
		clone:ScaleTo(scale)
		local _, size = clone:GetBoundingBox()
		clone:PivotTo(cf * CFrame.new(0, size.Y / 2, 0))
		clone.Parent = map.folder
	end

	-- keep-out volumes: the building footprint, the plaza and the parking
	local function clear(x: number, z: number): boolean
		if math.abs(x) < 236 and z > -160 and z < 136 then
			return false -- the school itself
		end
		if math.abs(x) < 74 and z > 130 and z < 210 then
			return false -- entrance walk
		end
		if math.abs(x) > 72 and math.abs(x) < 196 and z > 132 and z < 196 then
			return false -- parking aprons
		end
		return true
	end

	-- bushes and small trees ringing the lawns and lining the approach
	for i = 1, 120 do
		local a = landRng:NextNumber(0, math.pi * 2)
		local d = landRng:NextNumber(150, 300)
		local x, z = math.sin(a) * d, math.cos(a) * d + 20
		if clear(x, z) then
			local pick = landRng:NextNumber()
			if pick < 0.55 then
				place(bush, "PaintBush", CFrame.new(x, 0, z) * CFrame.Angles(0, landRng:NextNumber(0, 6.28), 0), landRng:NextNumber(0.7, 1.5))
			else
				place(smallTree, "PaintSmallTree", CFrame.new(x, 0, z) * CFrame.Angles(0, landRng:NextNumber(0, 6.28), 0), landRng:NextNumber(0.9, 1.6))
			end
		end
	end
	-- foundation planting hugging the facade
	for i = 0, 23 do
		local x = -220 + i * 19
		if math.abs(x) > 46 then
			place(bush, "PaintBush", CFrame.new(x, 0, 131) * CFrame.Angles(0, landRng:NextNumber(0, 6.28), 0), landRng:NextNumber(0.6, 0.95))
		end
	end
	-- courtyard planting
	for _, cx in { -116, 116 } do
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			place(bush, "PaintBush", CFrame.new(cx + math.sin(a) * 40, 0, math.cos(a) * 36) * CFrame.Angles(0, landRng:NextNumber(0, 6.28), 0), landRng:NextNumber(0.7, 1.2))
		end
		place(smallTree, "PaintSmallTree", CFrame.new(cx - 26, 0, 26), 1.3)
		place(smallTree, "PaintSmallTree", CFrame.new(cx + 28, 0, -22), 1.15)
	end
	-- painted benches and lamps replace the box versions along the walk
	for _, sgn in { -1, 1 } do
		for _, bz in { 154, 170 } do
			place(benchP, "PaintBench", CFrame.new(sgn * 40, 0, bz) * CFrame.Angles(0, sgn > 0 and math.pi / 2 or -math.pi / 2, 0), 1.0)
		end
		for _, lz in { 146, 168, 190 } do
			place(lampP, "PaintLamp", CFrame.new(sgn * 56, 0, lz) * CFrame.Angles(0, sgn > 0 and math.pi or 0, 0), 1.0)
		end
	end
	for _, part in map.folder:GetDescendants() do
		if part:IsA("BasePart") and (part.Name == "BenchSeat" or part.Name == "BenchBack" or part.Name == "BenchLeg"
			or part.Name == "WalkLampPost" or part.Name == "WalkLampHead" or part.Name == "WalkLampCap") then
			part:Destroy()
		end
	end

	local hedgeTemplate = loadTemplate(ASSETS.Hedge)
	if hedgeTemplate then
		-- rounded hedges dressing the entrance walk and parking edge
		for _, spot in {
			Vector3.new(-14, 0, 96), Vector3.new(14, 0, 96),
			Vector3.new(-14, 0, 110), Vector3.new(14, 0, 110),
			Vector3.new(76, 0, 92), Vector3.new(76, 0, 108),
		} do
			local clone = hedgeTemplate:Clone()
			clone.Name = "MeshHedge"
			local _, size = clone:GetBoundingBox()
			clone:PivotTo(CFrame.new(spot + Vector3.new(0, size.Y / 2 - 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			clone.Parent = map.folder
		end
	end
end

return MeshService
