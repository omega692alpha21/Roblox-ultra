--!strict
-- Texture assets uploaded via Open Cloud as assetType "Image".
--
-- These MUST be Image ids, not Decal ids. A PNG uploaded as "Decal" returns a
-- Decal asset id, and Texture.Texture / MeshPart.TextureID silently render
-- nothing when given one — which is why every surface in the school used to
-- look like flat untextured plastic.
return {
	Brick = 73356099506020,
	Windows = 87924725359474,
	Lockers = 88071740077430,
	Shingles = 129625555224292,
	FloorTile = 120768377721330,
	Carpet = 114302929582775,
	BlueStone = 134841181088898,
	Ground = 76792612742592,
	Ceiling = 115930601236395,
	Plaster = 117467105887319,
	Wood = 130295372980893,
}
