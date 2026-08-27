--!strict
-- Repainted school surfaces, uploaded as assetType "Image".
--
-- These MUST be Image ids, not Decal ids: a PNG uploaded as "Decal" returns a
-- Decal asset id, and Texture.Texture renders nothing when given one.
--
-- Painted by tools/paint_textures.py. Every one bakes its own ambient
-- occlusion into the joints, an edge catch along raised faces, metre-scale
-- weathering and per-element colour variation - the things a pattern
-- generator leaves out and a painter puts in.
return {
	Brick = 93972218650394,
	Windows = 102712434805537,
	Lockers = 117005259025974,
	Shingles = 89332027513408,
	FloorTile = 91812351321037,
	Carpet = 103221684831716,
	BlueStone = 71126166805305,
	Ground = 74288493229469,
	Ceiling = 140539176149433,
	Plaster = 131254278369766,
	Wood = 137439567160473,
}
