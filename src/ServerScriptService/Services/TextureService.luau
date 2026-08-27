--!strict
-- Applies the uploaded texture assets to every part MapService tagged.
-- Server-side plain Texture instances: they replicate to every client on any
-- device with no client-side API requirements at all.
--
-- IMPORTANT: Texture.Texture needs an *Image* asset id. Uploading a PNG as
-- assetType "Decal" returns a Decal id, which silently renders as nothing —
-- that is why the whole school looked flat and untextured. Every id in
-- Config/TextureIds is an Image asset.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TextureIds = require(ReplicatedStorage.Config.TextureIds)

local TextureService = {}

local ALL_FACES = {
	Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left,
	Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom,
}
local SIDES = {
	Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right,
}
local TOP = { Enum.NormalId.Top }
local FRONT_BACK = { Enum.NormalId.Front, Enum.NormalId.Back }

local function apply(part: BasePart, assetId: number, faces: { Enum.NormalId }, tileU: number, tileV: number)
	if assetId == 0 then
		return
	end
	for _, face in faces do
		local texture = Instance.new("Texture")
		texture.Name = "SurfaceTex"
		texture.Texture = "rbxassetid://" .. assetId
		texture.Face = face
		texture.StudsPerTileU = tileU
		texture.StudsPerTileV = tileV
		texture.Parent = part
	end
end

-- tag -> { asset, faces, tileU, tileV }
type Rule = { id: number, faces: { Enum.NormalId }, u: number, v: number }

function TextureService.Init()
	local RULES: { [string]: Rule } = {
		TexBrick = { id = TextureIds.Brick, faces = ALL_FACES, u = 14, v = 14 },
		TexWindow = { id = TextureIds.Windows, faces = FRONT_BACK, u = 7.5, v = 6.6 },
		TexLocker = { id = TextureIds.Lockers, faces = FRONT_BACK, u = 16.8, v = 9 },
		TexRoof = { id = TextureIds.Shingles, faces = ALL_FACES, u = 16, v = 16 },
		TexFloorTile = { id = TextureIds.FloorTile, faces = TOP, u = 16, v = 16 },
		TexBlueStone = { id = TextureIds.BlueStone, faces = ALL_FACES, u = 18, v = 18 },
		TexGround = { id = TextureIds.Ground, faces = TOP, u = 22, v = 22 },
		TexCeiling = { id = TextureIds.Ceiling, faces = { Enum.NormalId.Bottom }, u = 12, v = 12 },
		TexCarpet = { id = TextureIds.Carpet, faces = TOP, u = 14, v = 14 },
		TexPlaster = { id = TextureIds.Plaster, faces = SIDES, u = 20, v = 20 },
		TexWood = { id = TextureIds.Wood, faces = ALL_FACES, u = 10, v = 10 },
	}

	local applied = 0
	for tagName, rule in RULES do
		for _, part in CollectionService:GetTagged(tagName) do
			if part:IsA("BasePart") then
				if tagName == "TexWindow" then
					part.Transparency = 0
				end
				apply(part, rule.id, rule.faces, rule.u, rule.v)
				applied += 1
			end
		end
	end

	-- Blanket pass: anything the map builders never tagged still gets the
	-- right material by name, so no surface in the school reads as flat
	-- plastic. Cheap: one Texture per matching face.
	local BY_NAME: { { match: string, rule: Rule } } = {
		{ match = "Brick", rule = { id = TextureIds.Brick, faces = ALL_FACES, u = 14, v = 14 } },
		{ match = "Wainscot", rule = { id = TextureIds.Wood, faces = SIDES, u = 10, v = 10 } },
		{ match = "InnerWallUpper", rule = { id = TextureIds.Plaster, faces = SIDES, u = 20, v = 20 } },
		{ match = "Facade", rule = { id = TextureIds.Plaster, faces = SIDES, u = 20, v = 20 } },
		{ match = "Trim", rule = { id = TextureIds.Plaster, faces = SIDES, u = 20, v = 20 } },
		{ match = "Column", rule = { id = TextureIds.Plaster, faces = SIDES, u = 20, v = 20 } },
		{ match = "PitchRoof", rule = { id = TextureIds.Shingles, faces = ALL_FACES, u = 16, v = 16 } },
		{ match = "DormerRoof", rule = { id = TextureIds.Shingles, faces = ALL_FACES, u = 12, v = 12 } },
		{ match = "RoofSlab", rule = { id = TextureIds.Shingles, faces = TOP, u = 18, v = 18 } },
		{ match = "Locker", rule = { id = TextureIds.Lockers, faces = FRONT_BACK, u = 4.2, v = 9 } },
		{ match = "Lawn", rule = { id = TextureIds.Ground, faces = TOP, u = 24, v = 24 } },
		{ match = "Hedge", rule = { id = TextureIds.Ground, faces = ALL_FACES, u = 8, v = 8 } },
		{ match = "Plaza", rule = { id = TextureIds.BlueStone, faces = TOP, u = 18, v = 18 } },
		{ match = "GrandStep", rule = { id = TextureIds.BlueStone, faces = ALL_FACES, u = 14, v = 14 } },
		{ match = "Floor", rule = { id = TextureIds.FloorTile, faces = TOP, u = 16, v = 16 } },
		{ match = "Desk", rule = { id = TextureIds.Wood, faces = ALL_FACES, u = 8, v = 8 } },
		{ match = "Bench", rule = { id = TextureIds.Wood, faces = ALL_FACES, u = 8, v = 8 } },
		{ match = "Door", rule = { id = TextureIds.Wood, faces = ALL_FACES, u = 9, v = 9 } },
		{ match = "Table", rule = { id = TextureIds.Wood, faces = ALL_FACES, u = 8, v = 8 } },
	}
	local map = workspace:FindFirstChild("CrumbworthHigh")
	if map then
		for _, part in map:GetDescendants() do
			if part:IsA("BasePart") and not part:FindFirstChild("SurfaceTex") then
				for _, entry in BY_NAME do
					if part.Name:find(entry.match) then
						apply(part, entry.rule.id, entry.rule.faces, entry.rule.u, entry.rule.v)
						applied += 1
						break
					end
				end
			end
		end
	end

	print("[TextureService] textured " .. applied .. " parts")
end

return TextureService
