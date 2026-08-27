--!strict
-- Custom 3D meshes, authored in code and uploaded via Open Cloud. Replaces
-- the box-part trees with smooth stylized mesh trees at runtime; falls back
-- silently to the part trees if an asset can't load.

local InsertService = game:GetService("InsertService")

local MeshService = {}

local ASSETS = {
	Tree = 128757271025486,
	Hedge = 88569427739236,
}

local rng = Random.new(17)

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
	for _, part in template:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = true
		end
	end
	result:Destroy()
	if #template:GetChildren() == 0 then
		return nil
	end
	return template
end

function MeshService.Init(map: { folder: Folder })
	local treeTemplate = loadTemplate(ASSETS.Tree)
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
		for _, trunk in trunks do
			local scale = math.clamp(trunk.Size.Y / 7, 0.55, 2.6)
			local base = trunk.Position - Vector3.new(0, trunk.Size.Y / 2, 0)
			local clone = treeTemplate:Clone()
			clone.Name = "MeshTree"
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
