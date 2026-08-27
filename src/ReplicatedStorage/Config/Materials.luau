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
return {
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
}
