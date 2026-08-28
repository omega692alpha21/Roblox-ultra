--!strict
-- The vocabulary every building on this campus is assembled from.
--
-- The reference buildings look like each other because they ARE each other:
-- the same steep slate roof, the same gabled dormers, the same stone spire,
-- the same chimney, repeated at different sizes. Until now every building here
-- grew its own version of each of those inline, which is why the dorms, the
-- quarters and the school all read as different games.
--
-- Everything here takes a `part` maker and a `tag` function from the caller
-- rather than requiring MapService, so the kit stays a leaf: MapService owns
-- how a part gets made, the kit owns what shape the school is.

local CollegiateKit = {}

export type Maker = (props: { [string]: any }) -> BasePart
export type Tagger = (part: Instance, tag: string) -> ()

export type Ctx = {
	parent: Instance,
	part: Maker,
	tag: Tagger,
}

-- The palette, once. Nothing in the kit picks a colour inline.
CollegiateKit.SLATE = Color3.fromRGB(90, 100, 114)
CollegiateKit.RIDGE = Color3.fromRGB(74, 82, 94)
CollegiateKit.STONE = Color3.fromRGB(138, 128, 114)
CollegiateKit.ASHLAR = Color3.fromRGB(201, 191, 169)
CollegiateKit.FRAME = Color3.fromRGB(42, 42, 40)
CollegiateKit.GLASS_LIT = Color3.fromRGB(255, 196, 107)
CollegiateKit.TIMBER = Color3.fromRGB(107, 74, 46)
CollegiateKit.IRON = Color3.fromRGB(28, 28, 32)
CollegiateKit.LANTERN = Color3.fromRGB(255, 220, 160)

local function wedge(ctx: Ctx, name: string, size: Vector3, cf: CFrame, colour: Color3, tagName: string?)
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = colour
	w.Material = Enum.Material.Slate
	w.Parent = ctx.parent
	if tagName then
		ctx.tag(w, tagName)
	end
	return w
end

-- ---------------------------------------------------------------------------
-- SPIRE
-- ---------------------------------------------------------------------------
-- Four corner wedges, each filling one quadrant of the base with its apex over
-- the corner nearest the middle, so the four apexes meet at a single point.
--
-- A CornerWedgePart's apex stands over its own (-x, -z) corner. Under a yaw of
-- theta that corner direction (-1, -1) maps to (-cos + -sin, sin - cos), which
-- gives 0 degrees for the (+x, +z) quadrant and then ninety at a time round the
-- other three. Getting this wrong puts four apexes on the OUTSIDE corners and
-- builds a crown instead of a spire.
function CollegiateKit.spire(ctx: Ctx, o: { x: number, z: number, base: number, width: number, height: number, colour: Color3? })
	local half = o.width / 4
	local colour = o.colour or CollegiateKit.SLATE
	for _, q in {
		{ dx = 1, dz = 1, yaw = 0 },
		{ dx = 1, dz = -1, yaw = 90 },
		{ dx = -1, dz = -1, yaw = 180 },
		{ dx = -1, dz = 1, yaw = 270 },
	} do
		local c = Instance.new("CornerWedgePart")
		c.Name = "SpireFace"
		c.Anchored = true
		c.CanCollide = false
		c.Size = Vector3.new(o.width / 2, o.height, o.width / 2)
		c.CFrame = CFrame.new(o.x + q.dx * half, o.base + o.height / 2, o.z + q.dz * half)
			* CFrame.Angles(0, math.rad(q.yaw), 0)
		c.Color = colour
		c.Material = Enum.Material.Slate
		c.Parent = ctx.parent
		ctx.tag(c, "TexSlateRoof")
	end
	-- the finial: a stone ball on an iron rod, which is the thing that reads
	-- against the sky from the far side of the grounds
	ctx.part({ Name = "SpireRod", Size = Vector3.new(0.5, o.height * 0.16, 0.5), CFrame = CFrame.new(o.x, o.base + o.height + o.height * 0.08, o.z), Color = CollegiateKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "SpireFinial", Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(o.x, o.base + o.height + o.height * 0.18, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Shape = Enum.PartType.Ball, Parent = ctx.parent }).CanCollide = false
end

-- ---------------------------------------------------------------------------
-- GABLE ROOF
-- ---------------------------------------------------------------------------
-- Two slate planes, a ridge capping along the top, a verge board down each
-- gable end and an eaves board along each side. The boards are what stop a
-- pitched roof reading as two triangles leaning together.
function CollegiateKit.gableRoof(ctx: Ctx, o: { x: number, z: number, width: number, depth: number, eaves: number, rise: number, runsX: boolean? })
	local runsX = o.runsX ~= false -- the ridge runs along x by default
	local w = if runsX then o.width else o.depth
	local d = if runsX then o.depth else o.width
	for _, side in { -1, 1 } do
		local piece = Instance.new("WedgePart")
		piece.Name = "RoofPlane"
		piece.Anchored = true
		piece.CanCollide = true
		piece.Size = Vector3.new(w, o.rise, d / 2)
		piece.CFrame = CFrame.new(o.x, o.eaves + o.rise / 2, o.z + side * d / 4)
			* CFrame.Angles(0, if side > 0 then 0 else math.rad(180), 0)
		if not runsX then
			piece.CFrame = CFrame.new(o.x + side * d / 4, o.eaves + o.rise / 2, o.z)
				* CFrame.Angles(0, math.rad(if side > 0 then 90 else 270), 0)
		end
		piece.Color = CollegiateKit.SLATE
		piece.Material = Enum.Material.Slate
		piece.Parent = ctx.parent
		ctx.tag(piece, "TexSlateRoof")
	end
	-- ridge capping
	local ridgeSize = if runsX then Vector3.new(w + 1.2, 1.1, 1.6) else Vector3.new(1.6, 1.1, w + 1.2)
	ctx.part({ Name = "RoofRidge", Size = ridgeSize, CFrame = CFrame.new(o.x, o.eaves + o.rise + 0.4, o.z), Color = CollegiateKit.RIDGE, Material = Enum.Material.Slate, Parent = ctx.parent }).CanCollide = false
	-- eaves board along both long sides
	for _, side in { -1, 1 } do
		local size = if runsX then Vector3.new(w + 2.4, 1.3, 1.1) else Vector3.new(1.1, 1.3, w + 2.4)
		local at = if runsX then CFrame.new(o.x, o.eaves - 0.4, o.z + side * d / 2) else CFrame.new(o.x + side * d / 2, o.eaves - 0.4, o.z)
		ctx.tag(ctx.part({ Name = "RoofEaves", Size = size, CFrame = at, Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- DORMER
-- ---------------------------------------------------------------------------
-- A gabled window standing out of a roof slope: two cheeks, a face, a lit pane
-- in a stone surround, its own little roof and a finial on the point. Ten
-- pieces, because a dormer that is one box with a light in it is the exact
-- thing the asset audit exists to catch.
function CollegiateKit.dormer(ctx: Ctx, o: { x: number, y: number, z: number, facing: number, width: number?, height: number? })
	local w = o.width or 7
	local h = o.height or 8
	local yaw = CFrame.Angles(0, math.rad(o.facing), 0)
	local at = CFrame.new(o.x, o.y, o.z) * yaw

	for _, side in { -1, 1 } do
		ctx.tag(ctx.part({ Name = "DormerCheek", Size = Vector3.new(0.9, h, 6.5), CFrame = at * CFrame.new(side * (w / 2 - 0.45), h / 2, -0.6), Color = CollegiateKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	end
	ctx.tag(ctx.part({ Name = "DormerFace", Size = Vector3.new(w, h, 0.9), CFrame = at * CFrame.new(0, h / 2, 2.4), Color = CollegiateKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.tag(ctx.part({ Name = "DormerSurround", Size = Vector3.new(w - 1.4, h - 2.2, 1.2), CFrame = at * CFrame.new(0, h / 2 + 0.3, 2.5), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	local pane = ctx.part({ Name = "DormerGlass", Size = Vector3.new(w - 3, h - 4, 0.5), CFrame = at * CFrame.new(0, h / 2 + 0.3, 2.9), Color = CollegiateKit.GLASS_LIT, Material = Enum.Material.Neon, Transparency = 0.08, Parent = ctx.parent })
	pane.CanCollide = false
	pane.CastShadow = false
	ctx.part({ Name = "DormerMullion", Size = Vector3.new(0.35, h - 4, 0.6), CFrame = at * CFrame.new(0, h / 2 + 0.3, 3.05), Color = CollegiateKit.FRAME, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
	ctx.part({ Name = "DormerSill", Size = Vector3.new(w + 0.8, 0.6, 2.0), CFrame = at * CFrame.new(0, 2.2, 2.6), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = CollegiateKit.LANTERN
	light.Brightness = 1.2
	light.Range = 20
	light.Shadows = false
	light.Parent = pane

	-- its own gable, and the finial on the point
	for _, side in { -1, 1 } do
		local piece = Instance.new("WedgePart")
		piece.Name = "DormerRoof"
		piece.Anchored = true
		piece.CanCollide = false
		piece.Size = Vector3.new(w + 1.6, 3.4, 3.6)
		piece.CFrame = at * CFrame.new(side * (w + 1.6) / 2, h + 1.7, 0.6)
			* CFrame.Angles(0, math.rad(if side > 0 then 90 else 270), 0)
		piece.Color = CollegiateKit.SLATE
		piece.Material = Enum.Material.Slate
		piece.Parent = ctx.parent
		ctx.tag(piece, "TexSlateRoof")
	end
	ctx.part({ Name = "DormerFinial", Size = Vector3.new(0.4, 2.2, 0.4), CFrame = at * CFrame.new(0, h + 4.5, 0.6), Color = CollegiateKit.IRON, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
end

-- ---------------------------------------------------------------------------
-- CHIMNEY
-- ---------------------------------------------------------------------------
function CollegiateKit.chimney(ctx: Ctx, o: { x: number, z: number, base: number, height: number, width: number? })
	local w = o.width or 6
	ctx.tag(ctx.part({ Name = "ChimneyStack", Size = Vector3.new(w, o.height, w), CFrame = CFrame.new(o.x, o.base + o.height / 2, o.z), Color = CollegiateKit.STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), "TexCoursedStone")
	ctx.tag(ctx.part({ Name = "ChimneyBand", Size = Vector3.new(w + 1.0, 0.8, w + 1.0), CFrame = CFrame.new(o.x, o.base + o.height * 0.62, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	ctx.tag(ctx.part({ Name = "ChimneyCap", Size = Vector3.new(w + 1.8, 1.2, w + 1.8), CFrame = CFrame.new(o.x, o.base + o.height + 0.6, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	for _, dx in { -1, 1 } do
		ctx.part({ Name = "ChimneyPot", Size = Vector3.new(1.5, 3.0, 1.5), CFrame = CFrame.new(o.x + dx * w * 0.24, o.base + o.height + 2.7, o.z), Color = Color3.fromRGB(150, 96, 70), Material = Enum.Material.Brick, Shape = Enum.PartType.Cylinder, Parent = ctx.parent }).CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- PINNACLE
-- ---------------------------------------------------------------------------
-- The little stone spike on a corner or a buttress. Six pieces.
function CollegiateKit.pinnacle(ctx: Ctx, o: { x: number, z: number, base: number, height: number? })
	local h = o.height or 12
	ctx.tag(ctx.part({ Name = "PinnaclePlinth", Size = Vector3.new(3.4, 1.2, 3.4), CFrame = CFrame.new(o.x, o.base + 0.6, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	ctx.tag(ctx.part({ Name = "PinnacleShaft", Size = Vector3.new(2.4, h * 0.55, 2.4), CFrame = CFrame.new(o.x, o.base + 1.2 + h * 0.275, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	ctx.tag(ctx.part({ Name = "PinnacleCornice", Size = Vector3.new(3.2, 0.7, 3.2), CFrame = CFrame.new(o.x, o.base + 1.2 + h * 0.55 + 0.35, o.z), Color = CollegiateKit.ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	CollegiateKit.spire(ctx, { x = o.x, z = o.z, base = o.base + 1.2 + h * 0.55 + 0.7, width = 3.0, height = h * 0.42, colour = CollegiateKit.ASHLAR })
end

-- ---------------------------------------------------------------------------
-- POINTED ARCH
-- ---------------------------------------------------------------------------
-- A real two-centred gothic arch, cut into voussoirs, because the alternative
-- everywhere in this repo so far has been a rectangle with a triangle on top.
--
-- Each half is a circular arc springing horizontally and meeting its twin at a
-- point. For a span S and a rise R the centre sits c = (R^2 - S^2/4) / S to the
-- FAR side of the springing, which gives radius S/2 + c and puts the apex
-- exactly on both arcs. Set c to zero and you get a semicircle -- a Roman arch,
-- the wrong century.
function CollegiateKit.pointedArch(ctx: Ctx, o: { x: number, y: number, z: number, span: number, rise: number, depth: number, ring: number?, segments: number?, colour: Color3?, tagName: string? })
	local ring = o.ring or 2.2
	local n = o.segments or 9
	local colour = o.colour or CollegiateKit.ASHLAR
	local tagName = o.tagName or "TexAshlar"
	local halfSpan = o.span / 2
	local c = (o.rise * o.rise - halfSpan * halfSpan) / o.span
	local radius = halfSpan + c
	local sweep = math.atan2(o.rise, c)

	for _, side in { -1, 1 } do
		local cx = o.x - side * c
		for i = 0, n - 1 do
			local a0 = sweep * (i / n)
			local a1 = sweep * ((i + 1) / n)
			local mid = (a0 + a1) / 2
			local segLen = radius * (a1 - a0) * 1.08
			local px = cx + side * radius * math.cos(mid)
			local py = o.y + radius * math.sin(mid)
			local block = ctx.part({
				Name = "ArchVoussoir",
				Size = Vector3.new(ring, segLen, o.depth),
				CFrame = CFrame.new(px, py, o.z) * CFrame.Angles(0, 0, side * mid),
				Color = colour,
				Material = Enum.Material.Concrete,
				Parent = ctx.parent,
			})
			block.CanCollide = false
			ctx.tag(block, tagName)
		end
	end
	-- the springer each side and the apex block, which are the pieces that make
	-- an arch look built rather than drawn
	for _, side in { -1, 1 } do
		ctx.tag(ctx.part({ Name = "ArchSpringer", Size = Vector3.new(ring + 1.4, 1.6, o.depth + 0.6), CFrame = CFrame.new(o.x + side * halfSpan, o.y - 0.4, o.z), Color = colour, Material = Enum.Material.Concrete, Parent = ctx.parent }), tagName).CanCollide = false
	end
	ctx.tag(ctx.part({ Name = "ArchApex", Size = Vector3.new(2.6, 3.0, o.depth + 0.6), CFrame = CFrame.new(o.x, o.y + o.rise + 0.6, o.z), Color = colour, Material = Enum.Material.Concrete, Parent = ctx.parent }), tagName).CanCollide = false
end

-- ---------------------------------------------------------------------------
-- BUTTRESS
-- ---------------------------------------------------------------------------
-- A stepped pier standing off a wall, narrowing at each set-off and finished
-- with a weathering slope. This is what carries a gothic elevation; round
-- classical columns say a different building entirely.
function CollegiateKit.buttress(ctx: Ctx, o: { x: number, z: number, base: number, height: number, width: number?, depth: number?, stages: number? })
	local w = o.width or 6
	local d = o.depth or 7
	local stages = o.stages or 3
	local each = o.height / stages
	for i = 0, stages - 1 do
		local shrink = i * 0.9
		ctx.tag(ctx.part({
			Name = "ButtressStage",
			Size = Vector3.new(w - shrink, each, d - shrink),
			CFrame = CFrame.new(o.x, o.base + each * (i + 0.5), o.z),
			Color = CollegiateKit.STONE,
			Material = Enum.Material.Slate,
			Parent = ctx.parent,
		}), "TexCoursedStone")
		ctx.tag(ctx.part({
			Name = "ButtressSetOff",
			Size = Vector3.new(w - shrink + 1.0, 0.8, d - shrink + 1.0),
			CFrame = CFrame.new(o.x, o.base + each * (i + 1) - 0.4, o.z),
			Color = CollegiateKit.ASHLAR,
			Material = Enum.Material.Concrete,
			Parent = ctx.parent,
		}), "TexAshlar").CanCollide = false
	end
	-- the weathering: a wedge shedding water back to the wall
	local cap = Instance.new("WedgePart")
	cap.Name = "ButtressWeathering"
	cap.Anchored = true
	cap.CanCollide = false
	cap.Size = Vector3.new(w - (stages - 1) * 0.9 + 1.0, 3.4, d - (stages - 1) * 0.9 + 1.0)
	cap.CFrame = CFrame.new(o.x, o.base + o.height + 1.7, o.z) * CFrame.Angles(0, math.rad(180), 0)
	cap.Color = CollegiateKit.ASHLAR
	cap.Material = Enum.Material.Concrete
	cap.Parent = ctx.parent
	ctx.tag(cap, "TexAshlar")
end

return CollegiateKit
