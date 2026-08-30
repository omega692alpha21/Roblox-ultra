--!strict
-- The vocabulary every CREATURE in this game is assembled from.
--
-- Nothing here is a mesh. The campus was built out of parts because parts are
-- the one thing this project can see before it publishes -- the offline
-- renderer draws them, and it draws an uploaded mesh as a grey box -- so a
-- creature made of meshes cannot be looked at until it is already live. A
-- creature made of parts can be looked at, recoloured for a skin, and scaled
-- for a growth stage, all for nothing.
--
-- Like CollegiateKit this stays a leaf: it takes a `part` maker from the
-- caller and never requires MapService.

local CreatureKit = {}

export type Maker = (props: { [string]: any }) -> BasePart
export type Tagger = (part: Instance, tag: string) -> ()

export type Ctx = {
	parent: Instance,
	part: Maker,
	tag: Tagger,
}

-- A species' colours. One table per creature, one table per SKIN: the whole
-- rarity axis of the design is a swap of this and nothing else.
export type Plume = {
	back: Color3,      -- mantle, crown, the upper wing
	breast: Color3,    -- the front, and the underside of the wing
	face: Color3,      -- the disc
	rim: Color3,       -- the ring around the disc
	wing: Color3,      -- the flight feathers
	bar: Color3,       -- barring on wing and tail
	mark: Color3,      -- speckles and streaks
	iris: Color3,
	beak: Color3,
	foot: Color3,
}

-- ---------------------------------------------------------------------------
-- placement
-- ---------------------------------------------------------------------------
-- Everything below is written in STUDS AT SCALE ONE, with the origin between
-- the feet and the bird facing -Z, which is Roblox's forward. The scale factor
-- is the growth stage, the evolution step and the size roll all at once --
-- final size = species base * growth stage * individual roll -- so the whole
-- of the design's size system is this one multiply.

type Body = {
	ctx: Ctx,
	root: CFrame,
	s: number,
	plume: Plume,
	seed: number,
}

local function v3(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function place(b: Body, name: string, size: Vector3, x: number, y: number, z: number,
	colour: Color3, rot: CFrame?, shape: string?, material: Enum.Material?): BasePart
	local p = b.ctx.part({
		Name = name,
		Size = size * b.s,
		Color = colour,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = false,
		CastShadow = false,
	})
	if shape == "Ball" then
		(p :: any).Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		(p :: any).Shape = Enum.PartType.Cylinder
	end
	local cf = b.root * CFrame.new(x * b.s, y * b.s, z * b.s)
	if rot then
		cf = cf * rot
	end
	p.CFrame = cf
	p.Parent = b.ctx.parent
	return p
end

-- A ball in Roblox is always a SPHERE -- it takes its diameter from one number
-- and ignores the other two -- so every ball here is asked for uniformly, and
-- the offline renderer (which would happily draw an ellipsoid) agrees with the
-- running game.
local function ball(b: Body, name: string, d: number, x: number, y: number, z: number,
	colour: Color3, material: Enum.Material?): BasePart
	return place(b, name, v3(d, d, d), x, y, z, colour, nil, "Ball", material)
end

-- A cylinder spins about its LOCAL X, so a disc facing the bird's front is one
-- turned a quarter about Y. Length first, then the diameter twice.
local function disc(b: Body, name: string, thick: number, d: number,
	x: number, y: number, z: number, colour: Color3): BasePart
	return place(b, name, v3(thick, d, d), x, y, z, colour,
		CFrame.Angles(0, math.pi / 2, 0), "Cylinder")
end

-- Deterministic noise. Speckling wants to look scattered and to look the SAME
-- every render, or two pictures of one owl are two different owls and nothing
-- can be judged by comparing them.
local function rng(b: Body): () -> number
	local state = b.seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

-- ---------------------------------------------------------------------------
-- the parts of a bird
-- ---------------------------------------------------------------------------

-- The three stacked spheres the whole body is. Everything that has to sit ON
-- the bird -- a feather course, a speckle -- asks these where the surface is.
local TRUNK = {
	{ y = 2.2, z = 0.05, r = 1.5 },     -- belly
	{ y = 3.28, z = -0.1, r = 1.16 },   -- chest
	{ y = 3.86, z = 0.02, r = 0.96 },   -- shoulders
}

-- Where the front of the bird is at a given height, and how big around it is
-- there. Returns nil above the shoulders, where the head takes over.
local function girth(y: number): (number?, number?)
	local best, bestR = nil, 0
	for _, s in TRUNK do
		local dy = y - s.y
		if math.abs(dy) < s.r then
			local r = math.sqrt(s.r * s.r - dy * dy)
			if r > bestR then
				best, bestR = s, r
			end
		end
	end
	if not best then
		return nil
	end
	return bestR, (best :: any).z
end

-- Put a plate ON the trunk at a given height and a given angle round it, lying
-- tangent to the surface and standing `out` proud of it. Every feather on the
-- bird is placed with this, which is why the wings follow the body instead of
-- hanging off it as planks -- the first cut of this kit built the wing as one
-- box at a fixed x and it read as a rucksack.
local function onBody(b: Body, name: string, size: Vector3, y: number, theta: number,
	side: number, out: number, colour: Color3, tilt: CFrame?)
	local r, cz = girth(y)
	if not r then
		return
	end
	local k = ((r :: number) + out) / (r :: number)
	local px = side * (r :: number) * math.sin(theta) * k
	local pz = (cz :: number) - (r :: number) * math.cos(theta) * k
	local rot = CFrame.Angles(0, -side * theta, 0)
	if tilt then
		rot = rot * tilt
	end
	place(b, name, size, px, y, pz, colour, rot)
end

-- The feather coursing. This is the slate coursing off the roofs wrapped round
-- a sphere: a run of small plates bedded into the surface so the light catches
-- an edge every few inches instead of one bald curve.
--
-- Two things had to change from the first cut. The rows lined up, so the bird
-- read as a barrel with hoops on it; they are bonded now, every other row
-- offset by half a plate. And the two colours were a whole shade apart, which
-- made a wasp -- the contrast is a fifth of what it was.
local function coursing(b: Body, rows: number, top: number, step: number)
	for j = 0, rows - 1 do
		local y = top - j * step
		local r = girth(y)
		if r then
			local bond = (j % 2) * 0.16
			-- Plates are WIDER than their spacing and TALLER than the row
			-- step, so they lap each other the way feathers do. The cut before
			-- this one left a gap on all four sides of every plate and the
			-- bird's chest came out looking like a brick wall.
			local shade = if j % 2 == 0 then 0.0 else 0.09
			for i = -3, 3 do
				local theta = i * 0.32 + bond
				if math.abs(theta) < 1.16 then
					onBody(b, "OwlBreastCourse", v3(0.58, step * 1.22, 0.09),
						y, theta, 1, 0.02, b.plume.breast:Lerp(b.plume.rim, shade))
				end
			end
			for i = -2, 2 do
				local theta = math.pi + i * 0.34 + bond
				onBody(b, "OwlMantleCourse", v3(0.6, step * 1.22, 0.09),
					y, theta, 1, 0.02, b.plume.back:Lerp(b.plume.bar, 0.06 + shade * 0.5))
			end
		end
	end
end

-- Coursing over the crown and the nape. From behind, the first render showed a
-- smooth grey ball on top of a textured body, and the seam between them was the
-- most obvious thing on the bird.
local function crown(b: Body, colour: Color3)
	local cy, cz, r = 4.95, -0.05, 1.25
	for ring = 0, 2 do
		local phi = 0.52 + ring * 0.44
		local ry = cy + r * math.cos(phi)
		local rr = r * math.sin(phi)
		for i = 0, 6 do
			local theta = math.pi + (i - 3) * 0.44 + (ring % 2) * 0.22
			place(b, "OwlCrown", v3(0.48, 0.44, 0.09),
				rr * math.sin(theta) * 1.03, ry, cz - rr * math.cos(theta) * 1.03,
				if (i + ring) % 2 == 0 then colour else colour:Lerp(b.plume.bar, 0.16),
				CFrame.Angles(0, -theta, 0) * CFrame.Angles(math.pi / 2 - phi, 0, 0))
		end
	end
end

-- The ruff where the head meets the body. Without it the skull floats over the
-- shoulders with daylight between them, which the first render showed on all
-- three birds.
local function ruff(b: Body, y: number, radius: number, colour: Color3)
	for i = 0, 13 do
		local theta = i * (2 * math.pi / 14)
		place(b, "OwlRuff", v3(0.36, 0.34, 0.16),
			radius * math.sin(theta), y - math.abs(math.cos(theta)) * 0.06,
			-radius * math.cos(theta), colour, CFrame.Angles(0, -theta, 0))
	end
end

-- Speckles, bars and streaks: one routine, a different plate. This is the
-- cheapest interesting surface in the kit and it is what separates three owls
-- that are otherwise one shape at three sizes.
local function scatter(b: Body, count: number, size: Vector3, colour: Color3,
	yLow: number, yHigh: number, tLow: number, tHigh: number)
	local rand = rng(b)
	for _ = 1, count do
		local y = yLow + rand() * (yHigh - yLow)
		local theta = tLow + rand() * (tHigh - tLow)
		local side = if rand() < 0.5 then -1 else 1
		onBody(b, "OwlMark", size, y, theta, side, 0.035, colour)
	end
end

local function trunk(b: Body)
	ball(b, "OwlBelly", TRUNK[1].r * 2, 0, TRUNK[1].y, TRUNK[1].z, b.plume.back)
	ball(b, "OwlChest", TRUNK[2].r * 2, 0, TRUNK[2].y, TRUNK[2].z, b.plume.back)
	ball(b, "OwlMantle", TRUNK[3].r * 2, 0, TRUNK[3].y, TRUNK[3].z, b.plume.back)
end

local function legs(b: Body)
	for _, side in { -1, 1 } do
		local x = side * 0.48
		-- feathered trousers, which is why an owl's legs read as short
		ball(b, "OwlThigh", 1.1, x, 1.3, 0.02, b.plume.breast)
		place(b, "OwlShank", v3(0.62, 0.28, 0.28), x, 0.56, 0.0, b.plume.foot,
			CFrame.Angles(0, 0, math.pi / 2), "Cylinder")
		place(b, "OwlFoot", v3(0.46, 0.18, 0.38), x, 0.17, -0.06, b.plume.foot)
		for i = -1, 1 do
			local yaw = i * 0.36
			place(b, "OwlToe", v3(0.17, 0.17, 0.62), x + i * 0.2, 0.13, -0.34,
				b.plume.foot, CFrame.Angles(0, yaw, 0))
			place(b, "OwlTalon", v3(0.1, 0.1, 0.17),
				x + i * 0.2 + math.sin(yaw) * -0.33, 0.1, -0.34 - math.cos(yaw) * 0.33,
				Color3.fromRGB(38, 36, 38), CFrame.Angles(0.45, yaw, 0))
		end
		place(b, "OwlToe", v3(0.17, 0.17, 0.4), x, 0.13, 0.2, b.plume.foot)
	end
end

-- A FOLDED wing. Rows of coverts lying on the bird's side, tapering as they go
-- down, and then the primaries carrying on past the tail. Everything sits on
-- the trunk's own curve, so from the front the wing is a soft edge rather than
-- a slab, and from behind the flight feathers close over the tail.
local function wings(b: Body)
	local rows = {
		{ y = 3.56, t0 = 1.22, t1 = 1.8, w = 0.66 },
		{ y = 3.2, t0 = 1.16, t1 = 1.94, w = 0.74 },
		{ y = 2.82, t0 = 1.18, t1 = 2.0, w = 0.74 },
		{ y = 2.44, t0 = 1.26, t1 = 1.98, w = 0.7 },
		{ y = 2.06, t0 = 1.36, t1 = 1.9, w = 0.62 },
	}
	for _, side in { -1, 1 } do
		for i, row in rows do
			for k = 0, 3 do
				local theta = row.t0 + (row.t1 - row.t0) * (k / 3)
				local colour = if (i + k) % 3 == 0 then b.plume.wing:Lerp(b.plume.bar, 0.4)
					else b.plume.wing
				onBody(b, "OwlCovert", v3(row.w * 0.86, 0.5, 0.09), row.y, theta, side,
					0.035, colour)
			end
		end
		-- the primaries, tipped down and back so they cross behind the tail
		for i = 0, 3 do
			local t = i / 3
			local colour = if i % 2 == 0 then b.plume.wing
				else b.plume.wing:Lerp(b.plume.bar, 0.7)
			place(b, "OwlPrimary", v3(0.3, 0.3, 1.35 + t * 0.45),
				side * (0.84 - t * 0.4), 1.92 - t * 0.26, 0.92 + t * 0.16, colour,
				CFrame.Angles(0.26 + t * 0.08, side * (0.1 - t * 0.09), side * 0.05))
		end
	end
end

-- The tail, tucked and drooping. The first cut had it standing straight out
-- behind like a diving board.
local function tail(b: Body)
	place(b, "OwlRump", v3(1.3, 0.72, 0.9), 0, 2.1, 0.95, b.plume.back,
		CFrame.Angles(-0.14, 0, 0))
	for i = 0, 4 do
		local colour = if i % 2 == 0 then b.plume.wing else b.plume.bar
		place(b, "OwlTailFeather", v3(0.3, 0.22, 1.55), -0.48 + i * 0.24,
			1.74 - math.abs(i - 2) * 0.04, 1.5, colour,
			CFrame.Angles(0.3, (i - 2) * 0.07, 0))
	end
end

-- WHERE THE FRONT OF THE HEAD IS.
--
-- Every facial feature was first written at a z picked by eye, and a magenta
-- test skull proved that all three faces were BURIED: what read as a barn
-- owl's white heart was only the tan rim ring poking out past the curve of the
-- skull, and the white face itself never drew a pixel. Roblox has the same
-- depth buffer the offline renderer does, so it would have looked the same in
-- the game. Nothing on the face is placed by eye any more -- it is placed
-- relative to the sphere it has to stand in front of.
local SKULL = { y = 4.95, z = -0.05, r = 1.25 }

local function skullFront(x: number, y: number): number
	local dy = y - SKULL.y
	local d2 = SKULL.r * SKULL.r - x * x - dy * dy
	if d2 <= 0 then
		return SKULL.z
	end
	return SKULL.z - math.sqrt(d2)
end

local function beak(b: Body, y: number, front: number)
	place(b, "OwlBeak", v3(0.32, 0.36, 0.34), 0, y, front, b.plume.beak)
	place(b, "OwlBeak", v3(0.2, 0.28, 0.32), 0, y - 0.24, front - 0.04, b.plume.beak)
	place(b, "OwlBeak", v3(0.11, 0.2, 0.28), 0, y - 0.44, front - 0.04,
		b.plume.beak:Lerp(Color3.fromRGB(40, 38, 36), 0.35))
end

local function eyes(b: Body, y: number, front: number, size: number)
	for _, side in { -1, 1 } do
		local x = side * 0.46
		ball(b, "OwlEyeSocket", size * 1.3, x, y, front + 0.16, b.plume.rim)
		ball(b, "OwlEyeIris", size, x, y, front, b.plume.iris)
		ball(b, "OwlEyePupil", size * 0.52, x, y, front - 0.1, Color3.fromRGB(14, 12, 16))
		ball(b, "OwlEyeGlint", size * 0.2, x + side * 0.12, y + 0.14, front - 0.15,
			Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	end
end

-- ---------------------------------------------------------------------------
-- the three faces
-- ---------------------------------------------------------------------------
-- A barn owl, a snowy owl and a great grey are one bird at three sizes from
-- twenty studs away. Up close they are told apart almost entirely by the FACE,
-- so each gets its own disc rather than a recolour of one disc.

-- Barn owl: two lobes over a point. The heart is the whole silhouette of that
-- bird and it is the only owl anybody can name on sight.
local function heartFace(b: Body)
	local zf = skullFront(0, 5.08)
	for _, side in { -1, 1 } do
		local x = side * 0.45
		disc(b, "OwlDiscRim", 0.3, 1.82, x, 5.1, zf - 0.02, b.plume.rim)
		disc(b, "OwlDisc", 0.22, 1.56, x, 5.1, zf - 0.12, b.plume.face)
	end
	for i = 0, 2 do
		local w = 1.05 - i * 0.3
		place(b, "OwlDiscRim", v3(w + 0.24, 0.3, 0.3), 0, 4.44 - i * 0.26, zf - 0.02, b.plume.rim)
		place(b, "OwlDisc", v3(w, 0.28, 0.22), 0, 4.44 - i * 0.26, zf - 0.12, b.plume.face)
	end
	beak(b, 4.94, zf - 0.2)
	eyes(b, 5.2, zf - 0.2, 0.46)
end

-- Snowy owl: barely a disc at all. A round white head, a small dark beak
-- buried in feathers, and the yellow eye doing all the work.
local function plainFace(b: Body)
	local zf = skullFront(0, 5.02)
	disc(b, "OwlDisc", 0.34, 2.12, 0, 5.02, zf - 0.06, b.plume.face)
	for _, side in { -1, 1 } do
		place(b, "OwlBrow", v3(0.86, 0.18, 0.22), side * 0.46, 5.46,
			skullFront(0.46, 5.46) - 0.12, b.plume.rim, CFrame.Angles(0, 0, -side * 0.22))
	end
	beak(b, 4.86, zf - 0.24)
	eyes(b, 5.14, zf - 0.24, 0.44)
end

-- Great grey: the largest facial disc of any owl, ringed like a target, with a
-- small yellow eye lost in the middle of it and a white bowtie under the beak.
local function ringedFace(b: Body)
	local zf = skullFront(0, 5.02)
	local rings = { { 3.0, b.plume.rim }, { 2.42, b.plume.face }, { 1.86, b.plume.rim },
		{ 1.3, b.plume.face } }
	for i, ring in rings do
		disc(b, "OwlDisc", 0.24, ring[1] :: number, 0, 5.02, zf + 0.02 - i * 0.1,
			ring[2] :: Color3)
	end
	for _, side in { -1, 1 } do
		place(b, "OwlBowtie", v3(0.66, 0.34, 0.24), side * 0.32, 4.34,
			skullFront(0.32, 4.34) - 0.12, b.plume.breast, CFrame.Angles(0, 0, side * 0.5))
	end
	beak(b, 4.84, zf - 0.4)
	eyes(b, 5.12, zf - 0.42, 0.4)
end

-- ---------------------------------------------------------------------------
-- OWL
-- ---------------------------------------------------------------------------

export type OwlSpec = {
	x: number,
	y: number,
	z: number,
	yaw: number?,
	scale: number?,
	plume: Plume,
	face: string?,       -- "heart" | "plain" | "rings"
	markCount: number?,
	markSize: Vector3?,
	markArc: { number }?,   -- { low, high } angle round the body, 0 = front
	frontMarks: number?,
	frontMarkSize: Vector3?,
	seed: number?,
}

function CreatureKit.owl(ctx: Ctx, o: OwlSpec)
	local b: Body = {
		ctx = ctx,
		root = CFrame.new(o.x, o.y, o.z) * CFrame.Angles(0, o.yaw or 0, 0),
		s = o.scale or 1,
		plume = o.plume,
		seed = o.seed or 7,
	}

	trunk(b)
	legs(b)
	coursing(b, 7, 3.46, 0.34)
	wings(b)
	tail(b)

	-- the head, which on an owl is nearly as wide as the body
	ball(b, "OwlSkull", 2.5, 0, 4.95, -0.05, b.plume.back)
	ball(b, "OwlNape", 1.9, 0, 4.35, 0.25, b.plume.back)
	crown(b, b.plume.back)
	ruff(b, 4.08, 1.0, b.plume.back:Lerp(b.plume.breast, 0.3))

	local face = o.face or "plain"
	if face == "heart" then
		heartFace(b)
	elseif face == "rings" then
		ringedFace(b)
	else
		plainFace(b)
	end

	local arc = o.markArc or { 2.0, 4.3 }
	if o.markCount and o.markCount > 0 then
		scatter(b, o.markCount, o.markSize or v3(0.2, 0.16, 0.12), b.plume.mark,
			1.9, 4.0, arc[1], arc[2])
	end
	-- a barn owl's white front carries a scatter of fine dark flecks and
	-- almost nothing else; it is the one marking on the bird you see head-on
	if o.frontMarks and o.frontMarks > 0 then
		scatter(b, o.frontMarks, o.frontMarkSize or v3(0.13, 0.13, 0.09),
			b.plume.breast:Lerp(b.plume.bar, 0.55), 2.1, 3.6, -1.0, 1.0)
	end
end

-- ---------------------------------------------------------------------------
-- the owl line
-- ---------------------------------------------------------------------------
-- Barn owl -> snowy owl -> great grey. One family, three tiers, and each step
-- is a bigger animal than the one it came from -- which is the whole point:
-- progression the player reads off the creature beside them, with no label and
-- no number.

local function rgb(r: number, g: number, b_: number): Color3
	return Color3.fromRGB(r, g, b_)
end

CreatureKit.OWLS = {
	barn = {
		label = "Barn Owl",
		scale = 0.82,
		face = "heart",
		markCount = 22,
		markSize = v3(0.16, 0.14, 0.1),
		markArc = { 2.1, 4.2 },
		frontMarks = 18,
		frontMarkSize = v3(0.14, 0.13, 0.09),
		plume = {
			back = rgb(196, 156, 100),
			breast = rgb(243, 238, 228),
			face = rgb(250, 247, 240),
			rim = rgb(178, 134, 84),
			wing = rgb(180, 142, 92),
			bar = rgb(124, 96, 62),
			mark = rgb(246, 242, 232),
			iris = rgb(24, 20, 24),
			beak = rgb(226, 214, 192),
			foot = rgb(214, 198, 172),
		},
	},
	snowy = {
		label = "Snowy Owl",
		scale = 1.08,
		face = "plain",
		markCount = 26,
		markSize = v3(0.55, 0.12, 0.09),
		markArc = { 1.9, 4.4 },
		frontMarks = 10,
		frontMarkSize = v3(0.42, 0.11, 0.09),
		plume = {
			back = rgb(243, 244, 247),
			breast = rgb(252, 252, 253),
			face = rgb(253, 253, 254),
			rim = rgb(214, 218, 228),
			wing = rgb(236, 238, 243),
			bar = rgb(74, 78, 90),
			mark = rgb(104, 112, 128),
			iris = rgb(250, 200, 44),
			beak = rgb(46, 46, 52),
			foot = rgb(238, 238, 242),
		},
	},
	greatgrey = {
		label = "Great Grey",
		scale = 1.38,
		face = "rings",
		markCount = 22,
		markSize = v3(0.12, 0.62, 0.1),
		markArc = { 2.0, 4.3 },
		frontMarks = 14,
		frontMarkSize = v3(0.11, 0.5, 0.09),
		plume = {
			back = rgb(136, 122, 102),
			breast = rgb(196, 184, 160),
			face = rgb(172, 160, 140),
			rim = rgb(96, 86, 72),
			wing = rgb(116, 104, 88),
			bar = rgb(68, 60, 50),
			mark = rgb(64, 56, 46),
			iris = rgb(246, 208, 66),
			beak = rgb(232, 214, 152),
			foot = rgb(158, 146, 126),
		},
	},
}

-- Build one of the three by name, at a place, at a size. `grow` is the growth
-- stage and the individual roll multiplied together -- the species base is
-- already in the table.
function CreatureKit.buildOwl(ctx: Ctx, species: string, x: number, y: number, z: number,
	yaw: number?, grow: number?)
	local spec = (CreatureKit.OWLS :: any)[species]
	if not spec then
		return
	end
	CreatureKit.owl(ctx, {
		x = x, y = y, z = z,
		yaw = yaw,
		scale = spec.scale * (grow or 1),
		plume = spec.plume,
		face = spec.face,
		markCount = spec.markCount,
		markSize = spec.markSize,
		markArc = spec.markArc,
		frontMarks = spec.frontMarks,
		frontMarkSize = spec.frontMarkSize,
		seed = 11 + #species * 37,
	})
end

return CreatureKit
