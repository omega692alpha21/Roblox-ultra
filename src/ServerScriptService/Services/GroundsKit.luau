--!strict
-- The vocabulary the grounds are assembled from.
--
-- Everything outdoors used to be written inline at its call site, so a fountain
-- was three cylinders on a stem, a parterre was a brown rectangle with a green
-- cross painted on it, and a bench was two boxes. That is the "basic shapes
-- that look like objects" problem: the shapes are right and the object is not
-- there. Each builder here puts down the parts a real one is made of --
-- coping, kerb, plinth, moulding, standard, jet -- and every one of them
-- clears tools/asset_audit.py's bar on its own.
--
-- Geometry comes from the caller as a rect or a centre and a radius, and the
-- caller gets its numbers from CampusPlan. Nothing here invents a coordinate.

local GroundsKit = {}

export type Ctx = {
	parent: Instance,
	part: (props: { [string]: any }) -> BasePart,
	tag: (p: BasePart, tagName: string) -> BasePart,
	prop: ((kind: string, cf: CFrame, options: any?) -> ())?,
}

GroundsKit.STONE = Color3.fromRGB(183, 174, 158)
GroundsKit.STONE_PALE = Color3.fromRGB(206, 200, 186)
GroundsKit.STONE_DEEP = Color3.fromRGB(150, 142, 128)
GroundsKit.WATER = Color3.fromRGB(120, 176, 200)
GroundsKit.HEDGE = Color3.fromRGB(47, 90, 52)
GroundsKit.HEDGE_DEEP = Color3.fromRGB(34, 68, 38)
GroundsKit.YEW = Color3.fromRGB(38, 74, 46)
GroundsKit.GRAVEL = Color3.fromRGB(176, 166, 148)
GroundsKit.IRON = Color3.fromRGB(28, 28, 32)
GroundsKit.TIMBER = Color3.fromRGB(107, 74, 46)
GroundsKit.LANTERN = Color3.fromRGB(255, 220, 160)

local TAU = math.pi * 2

-- ---------------------------------------------------------------- octagon --
-- A ring of eight straight runs is what a stone basin actually is: cut blocks
-- laid to a polygon. It also renders as a polygon rather than as the square a
-- Cylinder part collapses to when anything looks at it side on.
local function octagonRing(
	ctx: Ctx,
	name: string,
	cx: number,
	cz: number,
	radius: number,
	thickness: number,
	height: number,
	y: number,
	colour: Color3,
	material: Enum.Material
): { BasePart }
	local out = {}
	-- The flat-to-flat length of one side of a regular octagon at this radius,
	-- plus the mitre: two runs meeting at 45 degrees each need to reach
	-- (thickness / 2) * tan(22.5) past the flat to close the corner. Adding
	-- the whole thickness instead -- which is what this did -- overshoots by
	-- more than half the wall on a wide ring, and on the fountain's 11-stud
	-- apron that threw the octagon's south vertex 6 studs into the school's
	-- entrance terrace.
	local mitre = math.tan(math.pi / 8)
	local side = mitre * (2 * radius + thickness)
	for i = 0, 7 do
		local a = i * TAU / 8 + TAU / 16
		local piece = ctx.part({
			Name = name,
			Size = Vector3.new(side, height, thickness),
			CFrame = CFrame.new(cx + math.cos(a) * radius, y, cz + math.sin(a) * radius)
				* CFrame.Angles(0, -a, 0),
			Color = colour,
			Material = material,
			Parent = ctx.parent,
		})
		table.insert(out, piece)
	end
	return out
end

GroundsKit.octagonRing = octagonRing

-- A solid octagonal course. A regular octagon is exactly the union of a square
-- and the same square turned 45 degrees, so two parts do it -- and the second
-- is raised four hundredths of a stud so the two never share a face.
local function octagonSlab(
	ctx: Ctx,
	name: string,
	cx: number,
	cz: number,
	halfWidth: number,
	height: number,
	y: number,
	colour: Color3,
	material: Enum.Material
)
	for i, turn in { 0, math.pi / 4 } do
		ctx.part({
			Name = name,
			Size = Vector3.new(halfWidth * 2, height, halfWidth * 2),
			CFrame = CFrame.new(cx, y + (i - 1) * 0.04, cz) * CFrame.Angles(0, turn, 0),
			Color = colour,
			Material = material,
			Parent = ctx.parent,
		}).CanCollide = false
	end
end

GroundsKit.octagonSlab = octagonSlab

-- --------------------------------------------------------------- fountain --
-- rim, coping, water, a stepped pedestal, three dishes with their falls, a
-- ring of jets and a finial. `r` is the outside of the basin.
export type FountainSpec = {
	x: number,
	z: number,
	r: number,
	-- How many dishes to stack. Three is a court fountain, twenty-seven studs
	-- to the top of its plume. One is what fits under a roof: the dish heights
	-- are absolute, so shrinking r alone gives a thin spike rather than a
	-- smaller fountain.
	dishes: number?,
	upLight: ((parent: Instance, x: number, z: number, colour: Color3?) -> ())?,
}

function GroundsKit.fountain(ctx: Ctx, o: FountainSpec)
	local cx, cz, r = o.x, o.z, o.r

	-- The courses, bottom to top, each one clear of the last: apron -0.3..0.9,
	-- step 0.9..1.4, basin wall 1.4..3.4, coping 3.4..4.3 -- coping height, so
	-- the water is visible over it from standing eye level and the edge is
	-- something to sit on. No two of them meet
	-- on the same side of a plane, which is what makes a stack of stone read as
	-- stone instead of speckling.
	octagonRing(ctx, "FountainApron", cx, cz, r + 5.5, 11.0, 1.2, 0.3, GroundsKit.STONE_PALE, Enum.Material.Concrete)
	for _, piece in octagonRing(ctx, "FountainStep", cx, cz, r + 2.0, 4.0, 0.5, 1.15, GroundsKit.STONE_PALE, Enum.Material.Concrete) do
		piece.CanCollide = false
	end

	-- the basin wall, and the coping course over it
	octagonRing(ctx, "FountainRim", cx, cz, r, 3.0, 2.0, 2.4, GroundsKit.STONE, Enum.Material.Marble)
	for _, piece in octagonRing(ctx, "FountainCoping", cx, cz, r, 4.2, 0.9, 3.85, GroundsKit.STONE_PALE, Enum.Material.Marble) do
		piece.CanCollide = false
	end
	-- a moulded band low on the wall, so the basin has a base
	for _, piece in octagonRing(ctx, "FountainBase", cx, cz, r, 4.0, 1.1, 2.15, GroundsKit.STONE_DEEP, Enum.Material.Marble) do
		piece.CanCollide = false
	end

	-- the water, and the floor of the basin under it. Both are cylinders: an
	-- octagon of stone with a square of water in it is what the first one was.
	local floor = ctx.part({
		Name = "FountainFloor",
		Size = Vector3.new(0.9, (r - 1.5) * 2, (r - 1.5) * 2),
		CFrame = CFrame.new(cx, 1.85, cz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(52, 74, 84),
		Material = Enum.Material.Slate,
		Shape = Enum.PartType.Cylinder,
		Parent = ctx.parent,
	})
	floor.CanCollide = false
	local water = ctx.part({
		Name = "FountainWater",
		Size = Vector3.new(0.5, (r - 1.6) * 2, (r - 1.6) * 2),
		CFrame = CFrame.new(cx, 3.0, cz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GroundsKit.WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Shape = Enum.PartType.Cylinder,
		Parent = ctx.parent,
	})
	water.CanCollide = false
	water.Reflectance = 0.4

	-- the pedestal: three octagonal courses, smallest on top
	for i, course in { { w = 7.0, h = 1.8 }, { w = 5.2, h = 1.6 }, { w = 3.6, h = 1.4 } } do
		octagonSlab(ctx, "FountainPedestal", cx, cz, course.w, course.h,
			1.9 + (i - 1) * 1.7 + course.h / 2, GroundsKit.STONE_PALE, Enum.Material.Marble)
	end

	-- three dishes on a shaft, each with the sheet of water falling off it
	local dishes = { { r = r * 0.46, y = 10.6 }, { r = r * 0.30, y = 16.0 }, { r = r * 0.18, y = 20.4 } }
	for _ = 1, 3 - math.clamp(o.dishes or 3, 1, 3) do
		table.remove(dishes)
	end
	local top = dishes[#dishes].y
	local shaftFrom = 6.6
	for i, dish in dishes do
		ctx.part({
			Name = "FountainShaft",
			Size = Vector3.new(2.6, dish.y - shaftFrom + 1.2, 2.6),
			CFrame = CFrame.new(cx, (shaftFrom + dish.y) / 2, cz),
			Color = GroundsKit.STONE_PALE,
			Material = Enum.Material.Marble,
			Parent = ctx.parent,
		}).CanCollide = false
		-- the bowl under the lip: two courses, the lower one well in, so the
		-- dish tapers to its shaft instead of reading as a tray on a stick
		octagonSlab(ctx, "FountainDishBowl", cx, cz, dish.r * 0.86, 1.1, dish.y - 1.05, GroundsKit.STONE, Enum.Material.Marble)
		octagonSlab(ctx, "FountainDishBowl", cx, cz, dish.r * 0.52, 1.0, dish.y - 2.0, GroundsKit.STONE, Enum.Material.Marble)
		for _, piece in octagonRing(ctx, "FountainDishLip", cx, cz, dish.r, 2.0, 1.2, dish.y, GroundsKit.STONE_PALE, Enum.Material.Marble) do
			piece.CanCollide = false
		end
		-- the water standing in the dish
		octagonSlab(ctx, "FountainDishWater", cx, cz, dish.r * 0.94, 0.4, dish.y + 0.5, GroundsKit.WATER, Enum.Material.Glass)
		-- the fall: a curtain of water hanging off the lip all the way round,
		-- not a translucent block the width of the dish
		local drop = if i == 1 then 6.2 else 5.0
		for _, piece in octagonRing(ctx, "FountainFall", cx, cz, dish.r + 0.3, 0.5, drop, dish.y - 0.4 - drop / 2, Color3.fromRGB(214, 238, 248), Enum.Material.Glass) do
			piece.CanCollide = false
			piece.Transparency = 0.55
			piece.Reflectance = 0.2
			piece.CastShadow = false
		end
		shaftFrom = dish.y
	end

	-- the finial, and a jet standing over it
	ctx.part({
		Name = "FountainFinial",
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = CFrame.new(cx, top + 1.4, cz),
		Color = GroundsKit.STONE_PALE,
		Material = Enum.Material.Marble,
		Shape = Enum.PartType.Ball,
		Parent = ctx.parent,
	}).CanCollide = false
	-- the plume: a narrow column of water off the finial with a head on it,
	-- rather than a seven-stud white pillar standing in the middle of the court
	local plume = ctx.part({
		Name = "FountainPlume",
		Size = Vector3.new(0.5, 4.0, 0.5),
		CFrame = CFrame.new(cx, top + 4.4, cz),
		Color = Color3.fromRGB(226, 246, 252),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		Shape = Enum.PartType.Cylinder,
		Parent = ctx.parent,
	})
	plume.CFrame = CFrame.new(cx, top + 4.4, cz) * CFrame.Angles(0, 0, math.rad(90))
	plume.CanCollide = false
	plume.CastShadow = false
	local head = ctx.part({
		Name = "FountainPlumeHead",
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(cx, top + 6.8, cz),
		Color = Color3.fromRGB(232, 248, 252),
		Material = Enum.Material.Neon,
		Transparency = 0.62,
		Shape = Enum.PartType.Ball,
		Parent = ctx.parent,
	})
	head.CanCollide = false
	head.CastShadow = false

	-- eight jets round the basin, each arcing in towards the middle
	for i = 0, 7 do
		local a = i * TAU / 8
		local jx, jz = cx + math.cos(a) * (r - 5.0), cz + math.sin(a) * (r - 5.0)
		-- leaning IN towards the middle: yaw the jet to face the centre first,
		-- then tip it about its own X so the lean is inward whatever side of
		-- the basin it stands on
		local jet = ctx.part({
			Name = "FountainJet",
			Size = Vector3.new(0.45, 5.4, 0.45),
			CFrame = CFrame.new(jx, 6.4, jz)
				* CFrame.Angles(0, -a + math.pi / 2, 0)
				* CFrame.Angles(math.rad(-24), 0, 0),
			Color = Color3.fromRGB(226, 246, 252),
			Material = Enum.Material.Neon,
			Transparency = 0.5,
			Shape = Enum.PartType.Cylinder,
			Parent = ctx.parent,
		})
		jet.CFrame = jet.CFrame * CFrame.Angles(0, 0, math.rad(90))
		jet.CanCollide = false
		jet.CastShadow = false
		ctx.part({
			Name = "FountainSpout",
			Size = Vector3.new(1.4, 1.0, 1.4),
			CFrame = CFrame.new(jx, 3.1, jz),
			Color = GroundsKit.STONE_DEEP,
			Material = Enum.Material.Metal,
			Parent = ctx.parent,
		}).CanCollide = false
	end

	if o.upLight then
		for i = 0, 11 do
			local a = i * TAU / 12
			o.upLight(ctx.parent, cx + math.cos(a) * (r + 4.0), cz + math.sin(a) * (r + 4.0), Color3.fromRGB(190, 226, 255))
		end
	end
end

-- ----------------------------------------------------------------- hedges --
-- A run of clipped box: a bed of its own soil, the hedge over it, and a
-- lighter top face so it reads as clipped rather than as a green slab.
function GroundsKit.hedgeRun(ctx: Ctx, x0: number, z0: number, x1: number, z1: number, thickness: number, height: number)
	local w = math.max(math.abs(x1 - x0), thickness)
	local d = math.max(math.abs(z1 - z0), thickness)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	ctx.part({
		Name = "Hedge",
		Size = Vector3.new(w, height, d),
		CFrame = CFrame.new(cx, 0.4 + height / 2, cz),
		Color = GroundsKit.HEDGE_DEEP,
		Material = Enum.Material.Grass,
		Parent = ctx.parent,
	})
	ctx.part({
		Name = "HedgeClip",
		Size = Vector3.new(w - 0.4, 0.5, d - 0.4),
		CFrame = CFrame.new(cx, 0.4 + height - 0.1, cz),
		Color = GroundsKit.HEDGE,
		Material = Enum.Material.Grass,
		Parent = ctx.parent,
	}).CanCollide = false
end

-- A clipped yew cone: four stacked, shrinking courses on a short stem. Not a
-- cone, but read as one at any distance, and it is five named parts rather
-- than one green box.
function GroundsKit.yewCone(ctx: Ctx, x: number, z: number, height: number)
	ctx.part({
		Name = "YewStem",
		Size = Vector3.new(1.2, 1.6, 1.2),
		CFrame = CFrame.new(x, 1.2, z),
		Color = GroundsKit.TIMBER,
		Material = Enum.Material.Wood,
		Parent = ctx.parent,
	}).CanCollide = false
	local courses = 4
	for i = 0, courses - 1 do
		local t = i / courses
		local w = (height * 0.46) * (1 - t * 0.78)
		local h = height / courses
		ctx.part({
			Name = "YewCone",
			Size = Vector3.new(w, h, w),
			CFrame = CFrame.new(x, 2.0 + i * h + h / 2, z) * CFrame.Angles(0, math.rad(22 * i), 0),
			Color = GroundsKit.YEW:Lerp(GroundsKit.HEDGE, t * 0.4),
			Material = Enum.Material.Grass,
			Parent = ctx.parent,
		}).CanCollide = false
	end
end

-- A stone urn on a plinth: base, plinth, moulding, bowl, lip, and planting.
function GroundsKit.urn(ctx: Ctx, x: number, z: number, scale: number?)
	local s = scale or 1.0
	ctx.part({ Name = "UrnBase", Size = Vector3.new(4.4 * s, 1.0 * s, 4.4 * s), CFrame = CFrame.new(x, 0.9 + 0.5 * s, z), Color = GroundsKit.STONE, Material = Enum.Material.Concrete, Parent = ctx.parent })
	ctx.part({ Name = "UrnPlinth", Size = Vector3.new(3.0 * s, 4.0 * s, 3.0 * s), CFrame = CFrame.new(x, 1.4 + 2.5 * s, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent })
	ctx.part({ Name = "UrnMoulding", Size = Vector3.new(4.0 * s, 0.7 * s, 4.0 * s), CFrame = CFrame.new(x, 1.4 + 4.7 * s, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "UrnBowl", Size = Vector3.new(5.2 * s, 2.6 * s, 5.2 * s), CFrame = CFrame.new(x, 1.4 + 6.3 * s, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "UrnLip", Size = Vector3.new(6.0 * s, 0.6 * s, 6.0 * s), CFrame = CFrame.new(x, 1.4 + 7.7 * s, z), Color = GroundsKit.STONE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "UrnPlanting", Size = Vector3.new(5.0 * s, 2.2 * s, 5.0 * s), CFrame = CFrame.new(x, 1.4 + 8.9 * s, z), Color = GroundsKit.HEDGE, Material = Enum.Material.Grass, Parent = ctx.parent }).CanCollide = false
end

-- ------------------------------------------------------------- a parterre --
-- Gravel, a clipped box edge, a knot of box inside it, a yew at each corner,
-- an urn in the middle and flowers in the compartments. The old one was a
-- rectangle of bare soil with a green cross laid on it.
export type ParterreSpec = {
	x: number,
	z: number,
	hw: number,
	hd: number,
	flower: ((kind: string, cf: CFrame) -> ())?,
	upLight: ((parent: Instance, x: number, z: number, colour: Color3?) -> ())?,
}

function GroundsKit.parterre(ctx: Ctx, o: ParterreSpec)
	local x, z, hw, hd = o.x, o.z, o.hw, o.hd
	-- gravel, laid over the paving and inside its own kerb
	ctx.tag(ctx.part({
		Name = "ParterreGravel",
		Size = Vector3.new(hw * 2 - 2, 0.34, hd * 2 - 2),
		-- 0.55 .. 0.89: over the court's paving joints (0.47 .. 0.57), which
		-- run the full width of the court and pass under every bed
		CFrame = CFrame.new(x, 0.72, z),
		Color = GroundsKit.GRAVEL,
		Material = Enum.Material.Pebble,
		Parent = ctx.parent,
	}), "TexCourtPaving").CanCollide = false
	for _, run in {
		{ x - hw, z - hd, x + hw, z - hd },
		{ x - hw, z + hd, x + hw, z + hd },
		{ x - hw, z - hd, x - hw, z + hd },
		{ x + hw, z - hd, x + hw, z + hd },
	} do
		ctx.part({
			Name = "ParterreKerb",
			Size = Vector3.new(math.max(math.abs(run[3] - run[1]) + 1.4, 1.4), 0.9, math.max(math.abs(run[4] - run[2]) + 1.4, 1.4)),
			CFrame = CFrame.new((run[1] + run[3]) / 2, 0.75, (run[2] + run[4]) / 2),
			Color = GroundsKit.STONE_PALE,
			Material = Enum.Material.Concrete,
			Parent = ctx.parent,
		})
	end

	-- the clipped box edge, set in from the kerb
	local ex, ez = hw - 3.0, hd - 3.0
	GroundsKit.hedgeRun(ctx, x - ex, z - ez, x + ex, z - ez, 1.8, 2.4)
	GroundsKit.hedgeRun(ctx, x - ex, z + ez, x + ex, z + ez, 1.8, 2.4)
	GroundsKit.hedgeRun(ctx, x - ex, z - ez, x - ex, z + ez, 1.8, 2.4)
	GroundsKit.hedgeRun(ctx, x + ex, z - ez, x + ex, z + ez, 1.8, 2.4)

	-- a knot inside it: a diamond of box on the bed's own axes
	local kx, kz = ex - 5.0, ez - 5.0
	for _, seg in {
		{ x - kx, z, x, z - kz },
		{ x, z - kz, x + kx, z },
		{ x + kx, z, x, z + kz },
		{ x, z + kz, x - kx, z },
	} do
		local dx, dz = seg[3] - seg[1], seg[4] - seg[2]
		local length = math.sqrt(dx * dx + dz * dz)
		ctx.part({
			Name = "ParterreKnot",
			Size = Vector3.new(1.4, 1.7, length),
			CFrame = CFrame.new((seg[1] + seg[3]) / 2, 1.25, (seg[2] + seg[4]) / 2)
				* CFrame.Angles(0, math.atan2(dx, dz), 0),
			Color = GroundsKit.HEDGE,
			Material = Enum.Material.Grass,
			Parent = ctx.parent,
		}).CanCollide = false
	end

	-- a clipped yew at each inside corner, and an urn on the middle
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		GroundsKit.yewCone(ctx, x + corner[1] * (ex - 2.6), z + corner[2] * (ez - 2.6), 9.0)
	end
	GroundsKit.urn(ctx, x, z, 1.1)

	-- flowers in the four compartments the knot makes
	if o.flower then
		for _, corner in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do
			for i = -1, 1 do
				local fx = x + corner[1] * (kx * 0.62) + (if corner[1] == 0 then i * 4.4 else 0)
				local fz = z + corner[2] * (kz * 0.62) + (if corner[2] == 0 then 0 else i * 4.4)
				if corner[1] ~= 0 then
					fz = z + i * 4.4
				end
				o.flower(if (i + corner[1]) % 2 == 0 then "KFlowerRed" else "KFlowerYellow", CFrame.new(fx, 0.8, fz))
			end
		end
	end
	if o.upLight then
		o.upLight(ctx.parent, x, z - hd - 2.4, Color3.fromRGB(255, 224, 172))
		o.upLight(ctx.parent, x, z + hd + 2.4, Color3.fromRGB(255, 224, 172))
	end
end

-- --------------------------------------------------------------- a bench --
-- Cast-iron ends, five timber slats, a back of three, and an arm each side.
function GroundsKit.bench(ctx: Ctx, x: number, z: number, yaw: number)
	local at = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	for _, side in { -1, 1 } do
		ctx.part({ Name = "BenchEnd", Size = Vector3.new(0.6, 2.4, 4.4), CFrame = at * CFrame.new(side * 5.6, 1.6, 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent })
		ctx.part({ Name = "BenchFoot", Size = Vector3.new(1.2, 0.5, 5.2), CFrame = at * CFrame.new(side * 5.6, 0.65, 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "BenchArm", Size = Vector3.new(0.7, 0.7, 4.6), CFrame = at * CFrame.new(side * 5.6, 4.3, -0.2), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "BenchStay", Size = Vector3.new(0.5, 2.6, 0.5), CFrame = at * CFrame.new(side * 5.6, 3.4, 1.9), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	for i = -2, 2 do
		ctx.part({
			Name = "BenchSlat",
			Size = Vector3.new(11.6, 0.4, 0.85),
			CFrame = at * CFrame.new(0, 2.9, i * 1.0),
			Color = GroundsKit.TIMBER,
			Material = Enum.Material.WoodPlanks,
			Parent = ctx.parent,
		})
	end
	for i = 0, 2 do
		ctx.part({
			Name = "BenchBackSlat",
			Size = Vector3.new(11.6, 0.85, 0.4),
			CFrame = at * CFrame.new(0, 3.9 + i * 1.1, 2.1),
			Color = GroundsKit.TIMBER,
			Material = Enum.Material.WoodPlanks,
			Parent = ctx.parent,
		}).CanCollide = false
	end
end

-- ------------------------------------------------------------- iron fence --
-- Spear-topped railings between stone piers: the thing that encloses every
-- courtyard in the reference art.
function GroundsKit.railing(ctx: Ctx, x0: number, z0: number, x1: number, z1: number, height: number)
	local dx, dz = x1 - x0, z1 - z0
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1 then
		return
	end
	local yaw = math.atan2(dx, dz)
	local mid = CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2) * CFrame.Angles(0, yaw, 0)
	ctx.part({ Name = "RailingKerb", Size = Vector3.new(1.6, 1.0, length), CFrame = mid * CFrame.new(0, 0.7, 0), Color = GroundsKit.STONE, Material = Enum.Material.Concrete, Parent = ctx.parent })
	for _, band in { { y = height * 0.30, h = 0.4 }, { y = height * 0.88, h = 0.5 } } do
		ctx.part({ Name = "RailingRail", Size = Vector3.new(0.42, band.h, length), CFrame = mid * CFrame.new(0, 1.2 + band.y, 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	local bays = math.max(1, math.floor(length / 2.6))
	for i = 0, bays do
		local along = -length / 2 + i * (length / bays)
		ctx.part({ Name = "RailingBar", Size = Vector3.new(0.3, height, 0.3), CFrame = mid * CFrame.new(0, 1.2 + height / 2, along), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "RailingSpear", Size = Vector3.new(0.55, 1.1, 0.55), CFrame = mid * CFrame.new(0, 1.2 + height + 0.4, along) * CFrame.Angles(0, math.rad(45), 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
end

-- ------------------------------------------------------------- boundary --
-- The estate fence. Four thousand two hundred studs of it round the built
-- core, which is why it is not GroundsKit.railing: that one puts a bar every
-- 2.6 studs, and round the whole core that is sixteen hundred bars before a
-- single rail. This is the same fence written as bays -- a coursed dwarf wall
-- with an ashlar coping, two rails and a spear every nine studs standing on
-- it -- with a pier at every bay end.
--
-- The dwarf wall is the only part of it that collides. Railings are half a
-- stud thick and a player walks straight between them, so each bay also
-- carries one invisible guard slab: the fence keeps people in, which is the
-- whole reason a school has one.
function GroundsKit.boundaryPier(ctx: Ctx, x: number, z: number)
	ctx.part({ Name = "BoundaryPierPlinth", Size = Vector3.new(3.6, 2.4, 3.6), CFrame = CFrame.new(x, 0.7, z), Color = GroundsKit.STONE_DEEP, Material = Enum.Material.Concrete, Parent = ctx.parent })
	ctx.tag(ctx.part({ Name = "BoundaryPierShaft", Size = Vector3.new(2.8, 7.5, 2.8), CFrame = CFrame.new(x, 5.65, z), Color = GroundsKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.part({ Name = "BoundaryPierCornice", Size = Vector3.new(3.4, 0.9, 3.4), CFrame = CFrame.new(x, 9.85, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "BoundaryPierCap", Size = Vector3.new(2.4, 1.5, 2.4), CFrame = CFrame.new(x, 11.05, z) * CFrame.Angles(0, math.rad(45), 0), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "BoundaryPierFinial", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(x, 12.6, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Shape = Enum.PartType.Ball, Parent = ctx.parent }).CanCollide = false
end

-- One bay of it, pier centre to pier centre. Everything laid here is narrower
-- than the 2.8-stud pier shaft, so the wall, the coping and both rails run
-- straight through a pier and come out the other side as one continuous line
-- instead of stopping at every pier with a joint to hide.
function GroundsKit.boundaryRun(ctx: Ctx, x0: number, z0: number, x1: number, z1: number)
	local dx, dz = x1 - x0, z1 - z0
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 4 then
		return
	end
	local yaw = math.atan2(dx, dz)
	local mid = CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2) * CFrame.Angles(0, yaw, 0)
	-- founded at -0.6 rather than on grade: the gate apron's own underside is
	-- at y = 0 and the two runs of the fence pass over the ends of it
	ctx.tag(ctx.part({ Name = "BoundaryWall", Size = Vector3.new(1.6, 3.2, length), CFrame = mid * CFrame.new(0, 1.0, 0), Color = GroundsKit.STONE_DEEP, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.part({ Name = "BoundaryCoping", Size = Vector3.new(2.2, 0.5, length), CFrame = mid * CFrame.new(0, 2.85, 0), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({
		Name = "BoundaryGuard",
		Size = Vector3.new(1.0, 10.1, length),
		CFrame = mid * CFrame.new(0, 5.55, 0),
		Color = GroundsKit.IRON,
		Material = Enum.Material.Metal,
		Transparency = 1,
		Parent = ctx.parent,
	})
	for _, y in { 4.6, 8.7 } do
		ctx.part({ Name = "BoundaryRail", Size = Vector3.new(0.55, 0.45, length), CFrame = mid * CFrame.new(0, y, 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	local bars = math.max(2, math.floor(length / 9 + 0.5))
	for i = 0, bars - 1 do
		local along = -length / 2 + (i + 0.5) * (length / bars)
		ctx.part({ Name = "BoundaryBar", Size = Vector3.new(0.4, 6.0, 0.4), CFrame = mid * CFrame.new(0, 6.1, along), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "BoundarySpear", Size = Vector3.new(0.72, 1.3, 0.72), CFrame = mid * CFrame.new(0, 9.75, along) * CFrame.Angles(0, math.rad(45), 0), Color = GroundsKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
end

-- A gate pier: plinth, shaft, cornice and a ball finial.
function GroundsKit.gatePier(ctx: Ctx, x: number, z: number, height: number)
	ctx.part({ Name = "PierPlinth", Size = Vector3.new(7.0, 1.6, 7.0), CFrame = CFrame.new(x, 0.9, z), Color = GroundsKit.STONE, Material = Enum.Material.Concrete, Parent = ctx.parent })
	ctx.tag(ctx.part({ Name = "PierShaft", Size = Vector3.new(5.4, height, 5.4), CFrame = CFrame.new(x, 1.7 + height / 2, z), Color = GroundsKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.part({ Name = "PierCornice", Size = Vector3.new(6.8, 1.1, 6.8), CFrame = CFrame.new(x, 1.7 + height + 0.55, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "PierCap", Size = Vector3.new(5.0, 0.9, 5.0), CFrame = CFrame.new(x, 1.7 + height + 1.55, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "PierFinial", Size = Vector3.new(3.0, 3.0, 3.0), CFrame = CFrame.new(x, 1.7 + height + 3.4, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Shape = Enum.PartType.Ball, Parent = ctx.parent }).CanCollide = false
end

-- ----------------------------------------------------------- floodlight --
-- A mast with a head on it, not a glowing box in the air. Base, mast, ladder,
-- a bracket arm, a head frame, six lamp units in it and a service walkway.
function GroundsKit.floodMast(ctx: Ctx, x: number, z: number, height: number, aimYaw: number)
	local at = CFrame.new(x, 0, z) * CFrame.Angles(0, aimYaw, 0)
	ctx.part({ Name = "MastBase", Size = Vector3.new(6.0, 2.0, 6.0), CFrame = at * CFrame.new(0, 1.0, 0), Color = Color3.fromRGB(150, 150, 156), Material = Enum.Material.Concrete, Parent = ctx.parent })
	ctx.part({ Name = "MastPlinth", Size = Vector3.new(4.2, 1.2, 4.2), CFrame = at * CFrame.new(0, 2.6, 0), Color = Color3.fromRGB(168, 168, 174), Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "FloodMast", Size = Vector3.new(2.4, height, 2.4), CFrame = at * CFrame.new(0, 2.0 + height / 2, 0), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = ctx.parent })
	-- a ladder up the back of it
	for i = 0, math.floor(height / 4) do
		ctx.part({ Name = "MastRung", Size = Vector3.new(2.4, 0.28, 0.28), CFrame = at * CFrame.new(0, 5.0 + i * 4.0, -1.5), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	for _, side in { -1, 1 } do
		ctx.part({ Name = "MastLadderRail", Size = Vector3.new(0.3, height - 4, 0.3), CFrame = at * CFrame.new(side * 1.0, 4.0 + (height - 4) / 2, -1.5), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	local top = 2.0 + height
	-- the bracket the head hangs off, and the walkway under it
	ctx.part({ Name = "MastBracket", Size = Vector3.new(2.0, 1.0, 7.0), CFrame = at * CFrame.new(0, top - 1.4, 3.0), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "MastWalkway", Size = Vector3.new(11.0, 0.4, 3.4), CFrame = at * CFrame.new(0, top - 2.6, 2.4), Color = Color3.fromRGB(84, 88, 94), Material = Enum.Material.DiamondPlate, Parent = ctx.parent }).CanCollide = false
	for _, side in { -1, 1 } do
		ctx.part({ Name = "MastGuard", Size = Vector3.new(0.3, 2.4, 3.4), CFrame = at * CFrame.new(side * 5.4, top - 1.4, 2.4), Color = Color3.fromRGB(84, 88, 94), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	-- the head: a frame with six lamp units in it, each with its own cowl
	ctx.part({ Name = "FloodHead", Size = Vector3.new(13.0, 5.4, 1.4), CFrame = at * CFrame.new(0, top + 1.2, 4.4), Color = Color3.fromRGB(72, 76, 82), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	for i = 0, 5 do
		local lx = -5.0 + (i % 3) * 5.0
		local ly = top + (if i < 3 then 2.4 else 0.0)
		ctx.part({ Name = "FloodCowl", Size = Vector3.new(4.2, 2.2, 1.8), CFrame = at * CFrame.new(lx, ly, 5.2) * CFrame.Angles(math.rad(-18), 0, 0), Color = Color3.fromRGB(60, 64, 70), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		local lamp = ctx.part({
			Name = "FloodLamp",
			Size = Vector3.new(3.4, 1.6, 0.5),
			CFrame = at * CFrame.new(lx, ly - 0.2, 5.9) * CFrame.Angles(math.rad(-18), 0, 0),
			Color = Color3.fromRGB(255, 246, 214),
			Material = Enum.Material.Neon,
			Parent = ctx.parent,
		})
		lamp.CanCollide = false
		lamp.CastShadow = false
		if i == 1 or i == 4 then
			local light = Instance.new("SpotLight")
			light.Angle = 110
			light.Brightness = 2.2
			light.Range = 96
			light.Face = Enum.NormalId.Front
			light.Shadows = false
			light.Color = Color3.fromRGB(255, 248, 226)
			light.Parent = lamp
		end
	end
end

-- ----------------------------------------------------------------- goal --
-- Posts, crossbar, the two back stanchions, the stays between them, and a net
-- on three faces. A goal was two white sticks and a bar.
function GroundsKit.goal(ctx: Ctx, x: number, z: number, width: number, height: number, yaw: number)
	local at = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local hw, back = width / 2, 8.0
	for _, side in { -1, 1 } do
		ctx.part({ Name = "GoalPost", Size = Vector3.new(1.1, height, 1.1), CFrame = at * CFrame.new(side * hw, height / 2, 0), Color = Color3.fromRGB(238, 238, 240), Material = Enum.Material.Metal, Parent = ctx.parent })
		ctx.part({ Name = "GoalStanchion", Size = Vector3.new(0.8, height * 0.52, 0.8), CFrame = at * CFrame.new(side * hw, height * 0.26, -back), Color = Color3.fromRGB(226, 226, 230), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "GoalStay", Size = Vector3.new(0.7, 0.7, back + 1), CFrame = at * CFrame.new(side * hw, height * 0.52, -back / 2), Color = Color3.fromRGB(226, 226, 230), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "GoalNetSide", Size = Vector3.new(0.2, height * 0.7, back), CFrame = at * CFrame.new(side * (hw - 0.1), height * 0.35, -back / 2), Color = Color3.fromRGB(238, 240, 244), Material = Enum.Material.Fabric, Transparency = 0.45, Parent = ctx.parent }).CanCollide = false
	end
	ctx.part({ Name = "GoalBar", Size = Vector3.new(width + 1.1, 1.1, 1.1), CFrame = at * CFrame.new(0, height, 0), Color = Color3.fromRGB(238, 238, 240), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "GoalNetBack", Size = Vector3.new(width, height * 0.55, 0.2), CFrame = at * CFrame.new(0, height * 0.275, -back), Color = Color3.fromRGB(238, 240, 244), Material = Enum.Material.Fabric, Transparency = 0.45, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "GoalNetRoof", Size = Vector3.new(width, 0.2, back), CFrame = at * CFrame.new(0, height * 0.78, -back / 2) * CFrame.Angles(math.rad(18), 0, 0), Color = Color3.fromRGB(238, 240, 244), Material = Enum.Material.Fabric, Transparency = 0.45, Parent = ctx.parent }).CanCollide = false
	-- the ground bar the net is laced to, and the pegs holding it down
	ctx.part({ Name = "GoalGroundBar", Size = Vector3.new(width, 0.5, 0.5), CFrame = at * CFrame.new(0, 0.3, -back), Color = Color3.fromRGB(226, 226, 230), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	for i = -1, 1 do
		ctx.part({ Name = "GoalPeg", Size = Vector3.new(0.4, 0.9, 0.4), CFrame = at * CFrame.new(i * (width / 3), 0.45, -back - 0.6), Color = Color3.fromRGB(160, 164, 170), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
end

-- ------------------------------------------------------------ lawn panel --
-- A panel of mown grass inside a clipped box edge and a stone kerb, with the
-- mowing stripes a groundsman actually leaves. The thing a college court is
-- mostly made of, and what "an empty rectangle of terrain" is not.
function GroundsKit.lawnPanel(ctx: Ctx, x: number, z: number, hw: number, hd: number)
	ctx.tag(ctx.part({
		Name = "CourtLawn",
		Size = Vector3.new(hw * 2, 0.36, hd * 2),
		CFrame = CFrame.new(x, 0.72, z),
		Color = Color3.fromRGB(62, 107, 58),
		Material = Enum.Material.Grass,
		Parent = ctx.parent,
	}), "TexGrass").CanCollide = false
	-- the stripes: alternating cut, lighter where the mower ran towards you
	local stripes = math.max(3, math.floor(hw / 5))
	for i = 0, stripes - 1 do
		if i % 2 == 0 then
			ctx.part({
				Name = "LawnStripe",
				Size = Vector3.new((hw * 2 - 2) / stripes, 0.2, hd * 2 - 2),
				CFrame = CFrame.new(x - hw + 1 + (i + 0.5) * ((hw * 2 - 2) / stripes), 0.95, z),
				Color = Color3.fromRGB(76, 124, 68),
				Material = Enum.Material.Grass,
				Parent = ctx.parent,
			}).CanCollide = false
		end
	end
	-- a stone kerb round it, and a clipped box edge inside that
	for _, run in {
		{ x - hw, z - hd, x + hw, z - hd },
		{ x - hw, z + hd, x + hw, z + hd },
		{ x - hw, z - hd, x - hw, z + hd },
		{ x + hw, z - hd, x + hw, z + hd },
	} do
		ctx.part({
			Name = "LawnKerb",
			Size = Vector3.new(math.max(math.abs(run[3] - run[1]) + 1.6, 1.6), 1.0, math.max(math.abs(run[4] - run[2]) + 1.6, 1.6)),
			CFrame = CFrame.new((run[1] + run[3]) / 2, 0.7, (run[2] + run[4]) / 2),
			Color = GroundsKit.STONE_PALE,
			Material = Enum.Material.Concrete,
			Parent = ctx.parent,
		})
	end
	GroundsKit.hedgeRun(ctx, x - hw + 3, z - hd + 3, x + hw - 3, z - hd + 3, 1.6, 2.2)
	GroundsKit.hedgeRun(ctx, x - hw + 3, z + hd - 3, x + hw - 3, z + hd - 3, 1.6, 2.2)
	GroundsKit.hedgeRun(ctx, x - hw + 3, z - hd + 3, x - hw + 3, z + hd - 3, 1.6, 2.2)
	GroundsKit.hedgeRun(ctx, x + hw - 3, z - hd + 3, x + hw - 3, z + hd - 3, 1.6, 2.2)
end

-- ---------------------------------------------------------------- sundial --
-- A stone drinking fountain and dial on a plinth: something small to close a
-- vista on that is not another statue.
function GroundsKit.dial(ctx: Ctx, x: number, z: number, upLight: ((parent: Instance, x: number, z: number, colour: Color3?) -> ())?)
	-- radius 9 with a 5-thick ring reaches 11.5, which keeps it inside the
	-- thirteen-stud half-width of the axis walk it stands on
	octagonRing(ctx, "DialApron", x, z, 9.0, 5.0, 0.9, 0.45, GroundsKit.STONE_PALE, Enum.Material.Concrete)
	octagonSlab(ctx, "DialStep", x, z, 5.4, 0.6, 1.2, GroundsKit.STONE_PALE, Enum.Material.Concrete)
	ctx.part({ Name = "DialPlinth", Size = Vector3.new(6.4, 5.2, 6.4), CFrame = CFrame.new(x, 4.1, z), Color = GroundsKit.STONE, Material = Enum.Material.Marble, Parent = ctx.parent })
	ctx.part({ Name = "DialMoulding", Size = Vector3.new(7.4, 0.8, 7.4), CFrame = CFrame.new(x, 7.1, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "DialBowl", Size = Vector3.new(5.0, 1.4, 5.0), CFrame = CFrame.new(x, 8.2, z), Color = GroundsKit.STONE_PALE, Material = Enum.Material.Marble, Parent = ctx.parent }).CanCollide = false
	local water = ctx.part({ Name = "DialWater", Size = Vector3.new(3.6, 0.3, 3.6), CFrame = CFrame.new(x, 8.7, z), Color = GroundsKit.WATER, Material = Enum.Material.Glass, Transparency = 0.4, Parent = ctx.parent })
	water.CanCollide = false
	water.Reflectance = 0.4
	ctx.part({ Name = "DialFace", Size = Vector3.new(4.4, 0.3, 4.4), CFrame = CFrame.new(x, 9.1, z), Color = Color3.fromRGB(168, 132, 58), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "DialGnomon", Size = Vector3.new(0.35, 3.4, 0.35), CFrame = CFrame.new(x, 10.6, z) * CFrame.Angles(math.rad(38), 0, 0), Color = Color3.fromRGB(168, 132, 58), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		ctx.part({ Name = "DialSpout", Size = Vector3.new(0.9, 0.9, 1.6), CFrame = CFrame.new(x + math.cos(a) * 2.6, 8.5, z + math.sin(a) * 2.6) * CFrame.Angles(0, -a, 0), Color = Color3.fromRGB(168, 132, 58), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	end
	if upLight then
		for i = 0, 3 do
			local a = i * math.pi / 2
			upLight(ctx.parent, x + math.cos(a) * 8.0, z + math.sin(a) * 8.0, Color3.fromRGB(255, 224, 172))
		end
	end
end

return GroundsKit
