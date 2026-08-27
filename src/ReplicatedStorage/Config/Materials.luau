--!strict
-- MaterialVariants authored as data under MaterialService (see
-- src/MaterialService/*.model.json). They carry a hand-painted colour map,
-- a normal map derived from its relief and a roughness map, which is what
-- lets Future lighting catch the surface instead of flat-lighting a decal.
--
-- They have to be data, not script: MaterialVariant.ColorMap is Plugin
-- security, so no running script can ever set it. Rojo serialises them
-- into the place file, and the game only has to name them.
return {
	SchoolBrick = { variant = "SchoolBrick", material = Enum.Material.Brick },
	SchoolStone = { variant = "SchoolStone", material = Enum.Material.Slate },
	SchoolPlaster = { variant = "SchoolPlaster", material = Enum.Material.Plaster },
	SchoolWood = { variant = "SchoolWood", material = Enum.Material.WoodPlanks },
	SchoolTile = { variant = "SchoolTile", material = Enum.Material.CeramicTiles },
	SchoolCarpet = { variant = "SchoolCarpet", material = Enum.Material.Fabric },
	SchoolCeiling = { variant = "SchoolCeiling", material = Enum.Material.Concrete },
	SchoolLocker = { variant = "SchoolLocker", material = Enum.Material.Metal },
	SchoolShingle = { variant = "SchoolShingle", material = Enum.Material.Cobblestone },
	SchoolLawn = { variant = "SchoolLawn", material = Enum.Material.Grass },
	SchoolGlass = { variant = "SchoolGlass", material = Enum.Material.Glass },
}
