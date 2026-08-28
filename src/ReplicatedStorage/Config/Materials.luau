--!strict
-- MaterialVariants authored as data under MaterialService (see
-- src/MaterialService/*.model.json). Most now carry a scanned CC0 texture set
-- from Poly Haven -- colour with ambient occlusion multiplied in, the surface
-- normal, and roughness -- which is what lets Future lighting catch the
-- surface instead of flat-lighting a decal.
--
-- `owns_colour` marks the ones whose colour map is the real thing rather than
-- a greyscale pattern. Roblox multiplies BasePart.Color into the colour map,
-- so a red brick part over a red brick photograph comes out nearly black; the
-- part tint has to be lifted for those. The hand-painted carpet is still
-- neutral and keeps taking its colour from the part.
--
-- They have to be data, not script: MaterialVariant.ColorMap is Plugin
-- security, so no running script can ever set it. Rojo serialises them
-- into the place file, and the game only has to name them.
-- Exported so TextureService annotates its tables with the same type rather
-- than a structural guess: without it the entries that omit `ownsColour` infer
-- a different shape from the ones that set it, and the two never unify.
export type Surface = { variant: string, material: Enum.Material, ownsColour: boolean? }

local Materials: { [string]: Surface } = {
	SchoolBrick = { variant = "SchoolBrick", material = Enum.Material.Brick, ownsColour = true },
	SchoolStone = { variant = "SchoolStone", material = Enum.Material.Slate, ownsColour = true },
	SchoolPlaster = { variant = "SchoolPlaster", material = Enum.Material.Plaster, ownsColour = true },
	SchoolWood = { variant = "SchoolWood", material = Enum.Material.WoodPlanks, ownsColour = true },
	SchoolTile = { variant = "SchoolTile", material = Enum.Material.CeramicTiles, ownsColour = true },
	SchoolCarpet = { variant = "SchoolCarpet", material = Enum.Material.Fabric },
	SchoolCeiling = { variant = "SchoolCeiling", material = Enum.Material.Concrete, ownsColour = true },
	SchoolLocker = { variant = "SchoolLocker", material = Enum.Material.Metal, ownsColour = true },
	SchoolShingle = { variant = "SchoolShingle", material = Enum.Material.Cobblestone, ownsColour = true },
	SchoolLawn = { variant = "SchoolLawn", material = Enum.Material.Grass, ownsColour = true },
	SchoolGlass = { variant = "SchoolGlass", material = Enum.Material.Glass },
	-- The collegiate set. The references are a stone school under a slate roof
	-- standing on paving, and none of the surfaces above could carry that: the
	-- brick is brick, and the one "stone" is polished marble meant for a floor.
	SchoolCoursedStone = { variant = "SchoolCoursedStone", material = Enum.Material.Slate, ownsColour = true },
	SchoolAshlar = { variant = "SchoolAshlar", material = Enum.Material.Concrete, ownsColour = true },
	SchoolSlateRoof = { variant = "SchoolSlateRoof", material = Enum.Material.Slate, ownsColour = true },
	SchoolCourtPaving = { variant = "SchoolCourtPaving", material = Enum.Material.Slate, ownsColour = true },
	SchoolTarmac = { variant = "SchoolTarmac", material = Enum.Material.Asphalt, ownsColour = true },
}

return Materials
