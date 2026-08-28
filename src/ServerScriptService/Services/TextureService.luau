--!strict
-- Gives every surface in the school a real material.
--
-- This used to hang plain `Texture` instances on each face: a decal stretched
-- over plastic. A decal is lit as if it were flat, so no matter how good the
-- painting was, brick read as a photograph of brick glued to a box.
--
-- Now each surface gets a MaterialVariant instead — a colour map, a normal map
-- derived from that painting's own relief, and a roughness map. Future
-- lighting then lights the surface rather than the box: mortar lines catch the
-- sun, plaster scatters it, glass does not, and the same wall changes through
-- the school day.
--
-- The variants have to be authored as data (src/MaterialService/*.model.json,
-- synced by Rojo) because MaterialVariant.ColorMap is Plugin security — no
-- running script can ever set it. All the game does is name them.
--
-- Falls back to a Texture for the few surfaces that want a decal rather than a
-- material: window glazing, where the panes are a picture and not a pattern.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Materials = require(ReplicatedStorage.Config.Materials)
local TextureIds = require(ReplicatedStorage.Config.TextureIds)

local TextureService = {}

type Surface = Materials.Surface

-- Roblox multiplies BasePart.Color into a variant's colour map. When the map
-- is a photograph of red brick, a red brick part multiplies red by red and the
-- wall comes out nearly black. Lift the part toward white, keeping a trace of
-- its hue so an accent wall is still an accent wall.
local WHITE = Color3.new(1, 1, 1)

local function lift(color: Color3): Color3
	local peak = math.max(color.R, color.G, color.B)
	if peak < 0.02 then
		return Color3.fromRGB(196, 196, 196)
	end
	local full = Color3.new(color.R / peak, color.G / peak, color.B / peak)
	return full:Lerp(WHITE, 0.62)
end

local function dress(part: BasePart, surface: Surface)
	part.Material = surface.material
	part.MaterialVariant = surface.variant
	if surface.ownsColour then
		part.Color = lift(part.Color)
	end
end

-- Windows keep a decal: the panes and mullions are a picture, and tiling them
-- as a material would repeat the frame across the glass.
local FRONT_BACK = { Enum.NormalId.Front, Enum.NormalId.Back }

local function decal(part: BasePart, assetId: number, faces: { Enum.NormalId }, u: number, v: number)
	if assetId == 0 then
		return
	end
	for _, face in faces do
		local texture = Instance.new("Texture")
		texture.Name = "SurfaceTex"
		texture.Texture = "rbxassetid://" .. assetId
		texture.Face = face
		texture.StudsPerTileU = u
		texture.StudsPerTileV = v
		texture.Parent = part
	end
end

function TextureService.Init()
	-- tags the map builders apply as they go
	local BY_TAG: { [string]: Surface } = {
		TexBrick = Materials.SchoolBrick,
		TexLocker = Materials.SchoolLocker,
		TexRoof = Materials.SchoolShingle,
		TexFloorTile = Materials.SchoolTile,
		TexBlueStone = Materials.SchoolStone,
		TexGround = Materials.SchoolLawn,
		TexCeiling = Materials.SchoolCeiling,
		TexCarpet = Materials.SchoolCarpet,
		TexPlaster = Materials.SchoolPlaster,
		TexWood = Materials.SchoolWood,
		TexPlaza = Materials.SchoolStone,
	}

	local dressed = 0
	for tagName, surface in BY_TAG do
		for _, part in CollectionService:GetTagged(tagName) do
			if part:IsA("BasePart") then
				dress(part, surface)
				dressed += 1
			end
		end
	end

	for _, part in CollectionService:GetTagged("TexWindow") do
		if part:IsA("BasePart") then
			part.Transparency = 0
			dress(part, Materials.SchoolGlass)
			decal(part, TextureIds.Windows, FRONT_BACK, 7.5, 6.6)
			dressed += 1
		end
	end

	-- Blanket pass by name, so a surface the builders never tagged still reads
	-- as something. Ordered: the first match wins, so put the specific names
	-- above the generic ones.
	local BY_NAME: { { match: string, surface: Surface } } = {
		{ match = "Brick", surface = Materials.SchoolBrick },
		{ match = "Wainscot", surface = Materials.SchoolWood },
		{ match = "InnerWallUpper", surface = Materials.SchoolPlaster },
		{ match = "Facade", surface = Materials.SchoolPlaster },
		{ match = "Trim", surface = Materials.SchoolPlaster },
		{ match = "Column", surface = Materials.SchoolPlaster },
		{ match = "Pediment", surface = Materials.SchoolPlaster },
		{ match = "PitchRoof", surface = Materials.SchoolShingle },
		{ match = "DormerRoof", surface = Materials.SchoolShingle },
		{ match = "RoofSlab", surface = Materials.SchoolShingle },
		{ match = "Locker", surface = Materials.SchoolLocker },
		{ match = "Lawn", surface = Materials.SchoolLawn },
		{ match = "Hedge", surface = Materials.SchoolLawn },
		{ match = "Plaza", surface = Materials.SchoolStone },
		{ match = "GrandStep", surface = Materials.SchoolStone },
		{ match = "CampusPath", surface = Materials.SchoolStone },
		{ match = "Bench", surface = Materials.SchoolWood },
		{ match = "Shelf", surface = Materials.SchoolWood },
		{ match = "Floor", surface = Materials.SchoolTile },
		{ match = "Deck", surface = Materials.SchoolTile },
		{ match = "Desk", surface = Materials.SchoolWood },
		{ match = "Door", surface = Materials.SchoolWood },
		{ match = "Table", surface = Materials.SchoolWood },
	}

	local map = workspace:FindFirstChild("CrumbworthHigh")
	if map then
		for _, part in map:GetDescendants() do
			if part:IsA("BasePart") and part.MaterialVariant == "" then
				for _, entry in BY_NAME do
					if part.Name:find(entry.match) then
						dress(part, entry.surface)
						dressed += 1
						break
					end
				end
			end
		end
	end

	print("[TextureService] dressed " .. dressed .. " surfaces with PBR materials")
end

return TextureService
