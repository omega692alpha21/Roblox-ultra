--!strict
-- Applies the uploaded texture assets to every part MapService tagged.
-- Server-side plain Texture instances: replicate to all clients on any
-- device, no client API requirements at all.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TextureIds = require(ReplicatedStorage.Config.TextureIds)

local TextureService = {}

local ALL_FACES = {
	Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left,
	Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom,
}

local function apply(part: BasePart, assetId: number, faces: { Enum.NormalId }, tileU: number, tileV: number)
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

function TextureService.Init()
	local applied = 0
	for _, part in CollectionService:GetTagged("TexBrick") do
		if part:IsA("BasePart") then
			apply(part, TextureIds.Brick, ALL_FACES, 10, 10)
			applied += 1
		end
	end
	for _, part in CollectionService:GetTagged("TexWindow") do
		if part:IsA("BasePart") then
			part.Transparency = 0
			apply(part, TextureIds.Windows, { Enum.NormalId.Front, Enum.NormalId.Back }, 9, 4.5)
			applied += 1
		end
	end
	for _, part in CollectionService:GetTagged("TexRoof") do
		if part:IsA("BasePart") then
			apply(part, TextureIds.Shingles, { Enum.NormalId.Top }, 8, 8)
			applied += 1
		end
	end
	for _, part in CollectionService:GetTagged("TexFloorTile") do
		if part:IsA("BasePart") then
			apply(part, TextureIds.FloorTile, { Enum.NormalId.Top }, 12, 12)
			applied += 1
		end
	end
	for _, part in CollectionService:GetTagged("TexCarpet") do
		if part:IsA("BasePart") then
			apply(part, TextureIds.Carpet, { Enum.NormalId.Top }, 16, 16)
			applied += 1
		end
	end
	print("[TextureService] textured " .. applied .. " parts")
end

return TextureService
