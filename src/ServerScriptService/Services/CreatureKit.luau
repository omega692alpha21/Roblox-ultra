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
	plume: any,     -- a Plume for a bird, a Coat for a griffin
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
-- the quadruped vocabulary
-- ---------------------------------------------------------------------------
-- An owl is a stack of spheres and everything on it is found by HEIGHT. A
-- griffin is a horizontal animal and nothing about it can be found that way:
-- its body is a barrel lying along Z, its limbs are segments between two
-- points in space, and its wing is a fan of feathers off a wrist. Those are
-- the three things this section adds, and every four-legged or winged creature
-- after the griffin is built from them too.

-- A body is a SPINE: stations along the creature's own Z, each with a height
-- and a radius. Between stations the barrel is interpolated, so an animal can
-- have a deep chest and a narrow waist instead of being one tube.
export type Rib = { z: number, y: number, r: number }

local function ribAt(spine: { Rib }, z: number): (number?, number?)
	if z < spine[1].z or z > spine[#spine].z then
		return nil, nil
	end
	for i = 1, #spine - 1 do
		local a, c = spine[i], spine[i + 1]
		if z >= a.z and z <= c.z then
			local t = if c.z == a.z then 0 else (z - a.z) / (c.z - a.z)
			-- smoothstep, so the barrel has no crease at a station
			t = t * t * (3 - 2 * t)
			return a.r + (c.r - a.r) * t, a.y + (c.y - a.y) * t
		end
	end
	return nil, nil
end

-- The barrel itself: overlapping spheres along the spine. Spheres rather than
-- one long box because the light has to fall away round the animal's sides,
-- and because everything plated onto it is placed against a known radius.
local function barrel(b: Body, spine: { Rib }, name: string, colour: Color3, step: number)
	local z = spine[1].z
	while z <= spine[#spine].z + 1e-6 do
		local r, cy = ribAt(spine, z)
		if r then
			ball(b, name, (r :: number) * 2, 0, cy :: number, z, colour)
		end
		z += step
	end
end

-- A plate lying tangent to the barrel: at station z, at angle theta round it
-- measured from the spine (0 is the top of the back, pi the belly, negative
-- the other flank), standing `out` proud of the surface. The plate's length
-- runs along Z, which is the way both feathers and fur lie on an animal.
local function onSpine(b: Body, spine: { Rib }, name: string, size: Vector3,
	z: number, theta: number, out: number, colour: Color3, tilt: CFrame?)
	local r, cy = ribAt(spine, z)
	if not r then
		return
	end
	local rr = (r :: number) + out
	local rot = CFrame.Angles(0, 0, -theta)
	if tilt then
		rot = rot * tilt
	end
	place(b, name, size, rr * math.sin(theta), (cy :: number) + rr * math.cos(theta), z,
		colour, rot)
end

-- Where a sphere's surface is in a given direction from its centre. This is
-- skullFront() generalised, and it exists because the one mistake that has
-- already cost this kit a whole round is a feature placed at a coordinate
-- picked by eye that turned out to be INSIDE the head. Roblox has a depth
-- buffer; a buried part is not a subtle part, it is an absent one.
local function onSphere(b: Body, name: string, size: Vector3,
	cx: number, cy: number, cz: number, r: number,
	dx: number, dy: number, dz: number, out: number, colour: Color3, rot: CFrame?,
	shape: string?): BasePart?
	local m = math.sqrt(dx * dx + dy * dy + dz * dz)
	if m < 1e-6 then
		return nil
	end
	local k = r + out
	return place(b, name, size, cx + dx / m * k, cy + dy / m * k, cz + dz / m * k,
		colour, rot, shape)
end

-- A plate lying FLAT on a curved surface: its thin axis, which is local Z, has
-- to point along the outward direction. Every rotation for this was derived by
-- hand, and three of them on the griffin's head were about ninety degrees out
-- at once -- the cheek, the brow and the eye stripe were all standing EDGE-ON
-- to the surface they were supposed to be lying on. Derive it once instead.
local function tangent(dx: number, dy: number, dz: number): CFrame
	local m = math.sqrt(dx * dx + dy * dy + dz * dz)
	if m < 1e-6 then
		return CFrame.new()
	end
	dx, dy, dz = dx / m, dy / m, dz / m
	return CFrame.Angles(0, math.atan2(dx, dz), 0)
		* CFrame.Angles(-math.asin(math.clamp(dy, -1, 1)), 0, 0)
end

-- A limb segment between two points, as a box whose local Z is the length.
-- Boxes rather than cylinders: a cylinder's axis is its local X, so aiming one
-- along an arbitrary direction costs a second rotation for no gain at this
-- fidelity. `roll` turns the box about its own axis, which is how a feather
-- gets its flat to lie in the plane of the wing.
local function bone(b: Body, name: string, ax: number, ay: number, az: number,
	bx: number, by: number, bz: number, w: number, t: number, colour: Color3,
	roll: number?, over: number?): (number, number, number)
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len < 1e-4 then
		return bx, by, bz
	end
	local rot = CFrame.Angles(0, math.atan2(dx, dz), 0)
		* CFrame.Angles(-math.asin(dy / len), 0, 0)
	if roll then
		rot = rot * CFrame.Angles(0, 0, roll)
	end
	place(b, name, v3(w, t, len + (over or 0)), (ax + bx) / 2, (ay + by) / 2, (az + bz) / 2,
		colour, rot)
	return bx, by, bz
end

-- One flight feather: a blade and a narrower tip, so a wing ends in POINTS.
-- The fingered tip of a raptor's wing is most of what a hundred-and-twenty-
-- eight pixel silhouette has to work with.
local function feather(b: Body, name: string, rx: number, ry: number, rz: number,
	azim: number, elev: number, len: number, w: number, t: number,
	colour: Color3, tip: Color3?)
	local dx = math.sin(azim) * math.cos(elev)
	local dy = math.sin(elev)
	local dz = math.cos(azim) * math.cos(elev)
	local cut = len * 0.66
	bone(b, name, rx, ry, rz, rx + dx * cut, ry + dy * cut, rz + dz * cut, w, t, colour)
	bone(b, name, rx + dx * cut, ry + dy * cut, rz + dz * cut,
		rx + dx * len, ry + dy * len, rz + dz * len, w * 0.55, t * 0.8, tip or colour)
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
						y, theta, 1, 0.055, b.plume.breast:Lerp(b.plume.rim, shade))
				end
			end
			for i = -2, 2 do
				local theta = math.pi + i * 0.34 + bond
				onBody(b, "OwlMantleCourse", v3(0.6, step * 1.22, 0.09),
					y, theta, 1, 0.055, b.plume.back:Lerp(b.plume.bar, 0.06 + shade * 0.5))
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
		onBody(b, "OwlMark", size, y, theta, side, 0.055, colour)
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
					0.07, colour)
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

-- ---------------------------------------------------------------------------
-- GRIFFIN
-- ---------------------------------------------------------------------------
-- The flight mount, the top of the ladder, and the thumbnail. Eagle in front,
-- lion behind -- and the whole animal turns on the JOIN. A bird glued to a cat
-- reads as a toy; what makes a griffin is being able to SEE feathers become
-- fur, so the shoulder is where the most work goes.
--
-- It is a griffin and not a hippogriff on purpose. The design plan flags the
-- Harry Potter vocabulary as a platform-takedown risk and says to use original
-- names; a lion hindquarter is also further from anything anyone else in this
-- genre is shipping. Swapping to a horse rear is the hind legs, the tail and
-- the rump plating, and nothing else.

export type Coat = {
	hood: Color3,      -- the head's own field, paler than the neck
	crown: Color3,     -- the nape and the dark markings
	hackle: Color3,    -- the long neck feathers, and the name of the bird
	breast: Color3,
	covert: Color3,    -- the wing's shoulder
	primary: Color3,   -- the flight feathers
	quill: Color3,     -- feather edges and barring
	fur: Color3,       -- the lion half
	belly: Color3,
	tuft: Color3,      -- the tail
	beak: Color3,
	cere: Color3,      -- the soft skin at the base of the beak, and the feet
	iris: Color3,
	talon: Color3,
}

-- Built facing -Z, origin between the front feet on the ground, in studs at
-- scale one: shoulder 7.9, head 10.6, nose to tail tip 21, wingspan 27.
local GSPINE: { Rib } = {
	{ z = -2.7, y = 6.05, r = 1.2 },
	{ z = -1.5, y = 5.7, r = 1.95 },
	{ z = -0.3, y = 5.45, r = 2.35 },
	{ z = 1.3, y = 5.4, r = 2.45 },
	{ z = 3.1, y = 5.35, r = 2.2 },
	{ z = 4.9, y = 5.3, r = 1.95 },   -- a lion's waist, which is what makes
	{ z = 6.5, y = 5.3, r = 2.2 },    -- the haunch behind it read as a haunch
	{ z = 8.0, y = 5.35, r = 1.65 },
	{ z = 8.9, y = 5.4, r = 1.0 },
}

local GNECK = {
	{ y = 6.6, z = -2.8, r = 1.42 },
	{ y = 7.5, z = -3.3, r = 1.3 },
	{ y = 8.4, z = -3.75, r = 1.18 },
	{ y = 9.2, z = -4.15, r = 1.06 },
	{ y = 9.8, z = -4.5, r = 0.98 },
}

-- The head is TWO masses, not one. A single sphere with features stuck on it
-- has no muzzle, no cheek and no occiput, and the user's verdict on the first
-- griffin was "everything looks fine but the face".
local GHEAD = { y = 10.2, z = -4.9, r = 1.34 }      -- the braincase
local GMUZZLE = { y = 9.86, z = -5.95, r = 0.94 }   -- the rostrum in front of it

-- THE JOIN. Feathers in front of this station, fur behind it, and a standing
-- ruff of long plates sitting exactly on it.
local JOIN = 2.3

local function griffinBody(b: Body, c: Coat)
	barrel(b, GSPINE, "GriffinBarrel", c.fur, 0.55)
	-- the chest is a bird's, so its plating is feathers laid along the body
	for j = 0, 5 do
		local z = -2.2 + j * 0.92
		local bond = (j % 2) * 0.3
		for k = -3, 3 do
			local theta = k * 0.6 + bond
			if math.abs(theta) < 2.5 then
				local shade = if (j + k) % 2 == 0 then 0.0 else 0.1
				onSpine(b, GSPINE, "GriffinBreast", v3(1.7, 0.16, 1.15), z, theta, 0.07,
					c.breast:Lerp(c.quill, shade))
			end
		end
	end
	-- and the rear is a cat's, so its plating is broader, flatter and duller:
	-- fur does not catch an edge every inch the way a feather does
	for j = 0, 6 do
		local z = 2.9 + j * 0.95
		local bond = (j % 2) * 0.32
		for k = -3, 3 do
			local theta = k * 0.64 + bond
			if math.abs(theta) < 2.5 then
				local shade = if (j + k) % 2 == 0 then 0.0 else 0.06
				local coat = if math.abs(theta) > 2.0 then c.belly else c.fur
				onSpine(b, GSPINE, "GriffinPelt", v3(1.85, 0.13, 1.2), z, theta, 0.065,
					coat:Lerp(c.tuft, shade))
			end
		end
	end
	-- the join itself: a standing ruff of long feathers over the shoulder,
	-- lying back over the fur. This is the one detail that says chimera.
	for k = -5, 5 do
		local theta = k * 0.34
		onSpine(b, GSPINE, "GriffinRuff", v3(0.72, 0.22, 2.6), JOIN, theta, 0.1,
			if k % 2 == 0 then c.hackle else c.hackle:Lerp(c.quill, 0.3),
			CFrame.Angles(-0.16, 0, 0))
	end
end

local function griffinNeck(b: Body, c: Coat)
	for i, n in GNECK do
		ball(b, "GriffinNeck", n.r * 2, 0, n.y, n.z, c.crown)
		-- hackles: the long golden feathers of the nape, each one a blade
		-- lying DOWN the neck rather than a plate stuck on it
		local prev = GNECK[math.max(1, i - 1)]
		local dy, dz = n.y - prev.y, n.z - prev.z
		local m = math.sqrt(dy * dy + dz * dz)
		if m > 1e-4 then
			dy, dz = dy / m, dz / m
			for k = -4, 4 do
				local theta = k * 0.44
				-- a frame round the neck axis: x across, and the perpendicular
				-- in the neck's own plane
				local ux, uy, uz = math.cos(theta), math.sin(theta) * dz, -math.sin(theta) * dy
				local len = (2.45 - i * 0.3) + math.abs(theta) * 0.28
				local rx = ux * (n.r + 0.05)
				local ry = n.y + uy * (n.r + 0.05)
				local rz = n.z + uz * (n.r + 0.05)
				bone(b, "GriffinHackle", rx, ry, rz,
					rx + ux * 0.16 - dy * 0.0, ry - dy * len + uy * 0.16, rz - dz * len + uz * 0.16,
					0.42, 0.15,
					if k % 2 == 0 then c.hackle else c.hackle:Lerp(c.crown, 0.45), theta)
			end
		end
	end
end

local function griffinHead(b: Body, c: Coat)
	local hy, hz, r = GHEAD.y, GHEAD.z, GHEAD.r
	local my, mz, mr = GMUZZLE.y, GMUZZLE.z, GMUZZLE.r
	-- THE FACE FIELD. A barn owl's face works because it is a LIGHT field
	-- carrying dark marks, so the marks read as features. The griffin's head
	-- was a MID field carrying dark marks, so the marks were the only thing
	-- that drew and the head WAS the marks: a brown lump with a bar on it.
	-- The hood is the fix, and it is the biggest single change here.
	ball(b, "GriffinSkull", r * 2, 0, hy, hz, c.hood)
	ball(b, "GriffinMuzzle", mr * 2, 0, my, mz, c.hood)
	for _, side in { -1, 1 } do
		local cdx, cdy, cdz = side * 0.78, -0.42, -0.46
		onSphere(b, "GriffinCheek", v3(0.9, 0.72, 0.3), 0, hy, hz, r,
			cdx, cdy, cdz, -0.02, c.hood:Lerp(c.crown, 0.3), tangent(cdx, cdy, cdz))
	end

	-- CROWN feathering, two rings only. The third ran down to the brow line and
	-- terminated in a hard edge right above the eye, which is what a HELMET is.
	for ring = 0, 1 do
		local phi = 0.42 + ring * 0.46
		for i = 0, 7 do
			local th = math.pi + (i - 3.5) * 0.42 + (ring % 2) * 0.21
			local dx = math.sin(phi) * math.sin(th)
			local dy = math.cos(phi)
			local dz = -math.sin(phi) * math.cos(th)
			onSphere(b, "GriffinCrown", v3(0.5, 0.46, 0.1), 0, hy, hz, r, dx, dy, dz,
				0.02, if (i + ring) % 2 == 0 then c.hood:Lerp(c.crown, 0.28) else c.hood,
				tangent(dx, dy, dz))
		end
	end

	-- Nothing is blank between the eyes. The forehead comes down to a point and
	-- the beak's ridge carries on up between them, so the eyes are never a
	-- floating pair -- they are two things either side of a keel.
	place(b, "GriffinForehead", v3(0.46, 0.62, 1.0), 0, hy + 0.28, hz - 1.16,
		c.hood:Lerp(c.crown, 0.4), CFrame.Angles(0.34, 0, 0))
	place(b, "GriffinCulmen", v3(0.3, 0.34, 1.1), 0, hy - 0.1, hz - 1.62, c.cere,
		CFrame.Angles(0.3, 0, 0))

	for _, side in { -1, 1 } do
		local dx, dy, dz = side * 0.78, -0.05, -0.62
		-- THE EYE LADDER. Every layer is a real Ball now, and each one's outer
		-- surface clears the last by at least 0.08 studs MEASURED ALONG THE
		-- OPTIC AXIS -- which is the only direction that matters, and the thing
		-- that was not being measured when the pupil sat inside the iris.
		onSphere(b, "GriffinEyeRing", v3(0.8, 0.8, 0.8), 0, hy, hz, r, dx, dy, dz,
			-0.14, Color3.fromRGB(30, 24, 20), nil, "Ball")
		onSphere(b, "GriffinIris", v3(0.66, 0.66, 0.66), 0, hy, hz, r, dx, dy, dz,
			0.02, c.iris, nil, "Ball")
		onSphere(b, "GriffinPupil", v3(0.29, 0.29, 0.29), 0, hy, hz, r, dx, dy, dz,
			0.28, Color3.fromRGB(10, 9, 11), nil, "Ball")
		onSphere(b, "GriffinGlint", v3(0.13, 0.13, 0.13), 0, hy, hz, r,
			dx + side * 0.2, dy + 0.26, dz - 0.05, 0.38, Color3.fromRGB(255, 255, 255),
			nil, "Ball")
		-- THE SCOWL: a shelf whose outer edge tips down over the eye. The dark
		-- on this face is asymmetric on purpose -- a brow above and a stripe
		-- behind, never a ring around -- because anything concentric drawn once
		-- per eye is a spectacle rim.
		local bdx, bdy, bdz = side * 0.62, 0.64, -0.5
		onSphere(b, "GriffinBrow", v3(1.34, 0.86, 0.24), 0, hy, hz, r, bdx, bdy, bdz,
			0.05, c.crown:Lerp(c.quill, 0.55),
			tangent(bdx, bdy, bdz) * CFrame.Angles(-0.34, 0, -side * 0.26))
		local sdx, sdy, sdz = side * 0.9, 0.14, 0.34
		onSphere(b, "GriffinEyeStripe", v3(1.5, 0.36, 0.2), 0, hy, hz, r, sdx, sdy, sdz,
			0.01, c.crown:Lerp(Color3.fromRGB(40, 30, 22), 0.55), tangent(sdx, sdy, sdz))
	end

	-- The beak. On a PALE head the old buff beak had almost no separation from
	-- it, so the beak went ochre and the iris went amber: the eye is now the
	-- only saturated thing on the animal, which is the rule that was broken the
	-- first time round when the eye and the beak were the same gold.
	local front = mz - mr
	place(b, "GriffinCere", v3(0.64, 0.58, 0.5), 0, my + 0.06, front - 0.14, c.cere)
	for _, side in { -1, 1 } do
		place(b, "GriffinNostril", v3(0.12, 0.14, 0.12), side * 0.22, my + 0.1,
			front - 0.34, Color3.fromRGB(48, 40, 34))
	end
	local beak = {
		{ w = 0.56, h = 0.76, d = 0.58, y = my - 0.1, z = front - 0.44 },
		{ w = 0.48, h = 0.7, d = 0.5, y = my - 0.4, z = front - 0.76 },
		{ w = 0.4, h = 0.62, d = 0.4, y = my - 0.74, z = front - 0.96 },
		{ w = 0.3, h = 0.52, d = 0.3, y = my - 1.08, z = front - 1.0 },
		{ w = 0.19, h = 0.38, d = 0.2, y = my - 1.36, z = front - 0.94 },
	}
	for i, k in beak do
		place(b, "GriffinBeak", v3(k.w, k.h, k.d), 0, k.y, k.z,
			if i >= 3 then c.beak:Lerp(Color3.fromRGB(34, 30, 30), 0.2 + i * 0.17)
			else c.beak)
	end
	place(b, "GriffinMandible", v3(0.44, 0.34, 0.92), 0, my - 0.58, front - 0.56, c.beak)
	place(b, "GriffinGape", v3(0.52, 0.08, 0.8), 0, my - 0.38, front - 0.48,
		Color3.fromRGB(52, 42, 36))
end

-- The eagle foreleg: feathered to the ankle, then scaled, then four toes and
-- four black talons. At ground level this is the other half of the chimera and
-- a player standing next to the animal is looking straight at it.
local function griffinForeleg(b: Body, c: Coat, side: number)
	local x = side * 1.6
	ball(b, "GriffinShoulder", 2.3, x * 0.95, 4.95, -1.05, c.breast)
	bone(b, "GriffinUpperArm", x * 0.97, 4.7, -1.05, x, 3.0, -1.7, 1.35, 1.35, c.breast)
	bone(b, "GriffinForearm", x, 3.0, -1.7, x, 1.5, -1.32, 1.0, 1.0, c.breast)
	-- feathered trousers over the top two thirds
	for j = 0, 3 do
		for k = -2, 2 do
			local th = k * 0.62
			local yy = 4.3 - j * 0.62
			local rr = 0.78 - j * 0.07
			bone(b, "GriffinLegPlume",
				x + math.sin(th) * rr, yy + math.cos(th) * rr * 0.5, -1.2 - j * 0.1,
				x + math.sin(th) * rr, yy - 0.62 + math.cos(th) * rr * 0.5, -1.16 - j * 0.1,
				0.66, 0.18,
				if (j + k) % 2 == 0 then c.breast else c.breast:Lerp(c.quill, 0.22), th)
		end
	end
	bone(b, "GriffinTarsus", x, 1.5, -1.32, x, 0.44, -1.28, 0.54, 0.54, c.cere)
	for k = -1, 1 do
		local yaw = k * 0.44
		local tx = x + math.sin(yaw) * 0.9
		local tz = -1.3 - math.cos(yaw) * 0.9
		bone(b, "GriffinToe", x, 0.3, -1.3, tx, 0.24, tz, 0.34, 0.34, c.cere)
		local ex = x + math.sin(yaw) * 1.45
		local ez = -1.3 - math.cos(yaw) * 1.45
		bone(b, "GriffinToe", tx, 0.24, tz, ex, 0.2, ez, 0.28, 0.28, c.cere)
		bone(b, "GriffinTalon", ex, 0.2, ez,
			ex + math.sin(yaw) * 0.38, 0.04, ez - math.cos(yaw) * 0.38, 0.2, 0.2, c.talon)
	end
	bone(b, "GriffinToe", x, 0.3, -1.3, x, 0.24, -0.62, 0.3, 0.3, c.cere)
	bone(b, "GriffinTalon", x, 0.24, -0.62, x, 0.08, -0.3, 0.19, 0.19, c.talon)
end

local function griffinHindleg(b: Body, c: Coat, side: number)
	local x = side * 1.5
	ball(b, "GriffinHaunch", 3.5, x * 0.94, 5.0, 6.5, c.fur)
	bone(b, "GriffinFemur", x * 0.96, 4.7, 6.35, x, 3.05, 5.5, 1.4, 1.4, c.fur)
	bone(b, "GriffinTibia", x, 3.05, 5.5, x * 1.05, 1.6, 6.85, 1.0, 1.0, c.fur)
	bone(b, "GriffinHock", x * 1.05, 1.6, 6.85, x * 1.05, 0.55, 6.1, 0.72, 0.72, c.fur)
	place(b, "GriffinPaw", v3(1.3, 0.6, 1.85), x * 1.05, 0.3, 5.55, c.fur)
	for k = -1, 1 do
		place(b, "GriffinPawToe", v3(0.38, 0.4, 0.52), x * 1.05 + k * 0.36, 0.24, 4.66, c.fur)
		bone(b, "GriffinClaw", x * 1.05 + k * 0.36, 0.22, 4.44,
			x * 1.05 + k * 0.36, 0.1, 4.16, 0.17, 0.17, c.talon)
	end
end

local function griffinTail(b: Body, c: Coat)
	local pts = {
		{ 0.0, 5.35, 8.9 }, { 0.0, 5.05, 10.3 }, { 0.0, 4.35, 11.4 },
		{ 0.0, 3.5, 12.15 }, { 0.0, 2.7, 12.55 },
	}
	local w = { 0.78, 0.64, 0.52, 0.42 }
	for i = 1, #pts - 1 do
		local a, d = pts[i], pts[i + 1]
		bone(b, "GriffinTail", a[1], a[2], a[3], d[1], d[2], d[3], w[i], w[i], c.fur, nil, 0.12)
	end
	-- the tuft. A lion's tail without one is a rope.
	for k = 0, 7 do
		local th = k * (math.pi * 2 / 8)
		bone(b, "GriffinTuft", 0, 2.75, 12.5,
			math.sin(th) * 0.55, 2.35 + math.cos(th) * 0.4, 13.35, 0.3, 0.24, c.tuft, th)
	end
end

-- THE WING. Two poses, because the animal has two jobs: folded when it is
-- standing beside you on the court, spread when it is the picture that sells
-- the game.
--
-- The first cut of this hung seven narrow feathers off a wrist and the result
-- read as a spiky CREST, not a wing. A wing is a SURFACE. So the feathers are
-- wide, they overlap at their roots, and three ranks of them - tertials off
-- the humerus, secondaries off the forearm, primaries off the hand - fill the
-- plane continuously from the body out to the fingers. Only the outer three
-- primaries are allowed to separate, because that separation is the whole
-- silhouette of a soaring raptor and it has to be legible at a hundred and
-- twenty-eight pixels.

local function spreadWing(b: Body, c: Coat, side: number)
	local rx, ry, rz = side * 1.5, 6.95, 0.5
	local ex, ey, ez = side * 6.2, 8.8, 2.6
	local wx, wy, wz = side * 11.6, 9.2, 0.2

	bone(b, "GriffinHumerus", rx, ry, rz, ex, ey, ez, 1.25, 0.85, c.covert)
	bone(b, "GriffinRadius", ex, ey, ez, wx, wy, wz, 0.95, 0.68, c.covert)
	-- the patagium: the skin in front of the arm. Without it the leading edge
	-- is two sticks with a notch at the elbow, which no bird has.
	bone(b, "GriffinPatagium", rx, ry - 0.1, rz - 0.5, wx, wy - 0.1, wz - 0.5,
		1.5, 0.34, c.covert)

	-- tertials, off the humerus, closing the gap between wing and body
	for i = 0, 3 do
		local u = i / 3
		feather(b, "GriffinTertial", rx + (ex - rx) * u, ry + (ey - ry) * u - 0.12,
			rz + (ez - rz) * u + 0.5, side * (0.16 + u * 0.1), -0.2,
			6.0 - u * 0.8, 1.45, 0.2, c.covert:Lerp(c.primary, 0.35), c.primary)
	end
	-- secondaries, off the forearm: nine of them, wide and overlapping, which
	-- is what makes the inner wing a sheet
	for i = 0, 10 do
		local u = i / 10
		feather(b, "GriffinSecondary", ex + (wx - ex) * u, ey + (wy - ey) * u - 0.1,
			ez + (wz - ez) * u + 0.55, side * (0.3 - u * 0.12), -0.16,
			6.4 - u * 1.5, 1.24, 0.2,
			if i % 2 == 0 then c.primary:Lerp(c.covert, 0.4) else c.primary:Lerp(c.covert, 0.22),
			c.primary)
	end
	-- primaries, off the hand. Wide and lapped at the root, narrow and long at
	-- the tip, so the wing ends in fingers.
	for i = 0, 7 do
		local u = i / 7
		feather(b, "GriffinPrimary",
			wx + side * 0.32 * i, wy - 0.05 * i, wz + 0.26 * i,
			side * (1.5 - u * 1.3), 0.04 - u * 0.16,
			7.2 - u * 2.0, 1.34 - u * 0.42, 0.2,
			c.primary, c.primary:Lerp(c.quill, 0.3))
	end
	-- coverts, in three ranks over the leading half, so the arm is a stack and
	-- not a plank
	for row = 0, 2 do
		for k = 0, 6 do
			local u = k / 6
			local ax = rx + (ex - rx) * math.min(1, u * 2) + (wx - ex) * math.max(0, u * 2 - 1)
			local ay = ry + (ey - ry) * math.min(1, u * 2) + (wy - ey) * math.max(0, u * 2 - 1)
			local az = rz + (ez - rz) * math.min(1, u * 2) + (wz - ez) * math.max(0, u * 2 - 1)
			bone(b, "GriffinCovert", ax, ay + 0.14 - row * 0.06, az + row * 0.95,
				ax + side * 0.12, ay + 0.1 - row * 0.08, az + row * 0.95 + 1.5,
				1.5, 0.2,
				if (row + k) % 2 == 0 then c.covert else c.covert:Lerp(c.quill, 0.28))
		end
	end
	-- the alula, the thumb feather at the wrist: the difference between a wing
	-- and a fan
	feather(b, "GriffinAlula", wx, wy + 0.3, wz - 0.5, side * 2.2, 0.14, 2.0, 0.6, 0.17,
		c.covert, c.primary)
end

-- A FOLDED wing is not the spread one with its joints moved. It is a shape
-- lying ON the flank -- so it is built on the barrel the way the body plating
-- is, but standing well proud of it, with the primaries crossing ABOVE the
-- rump the way a perched bird's do. The first cut laid them flush and rooted
-- them at the barrel's own radius, so the whole wing was inside the animal and
-- the ground render showed a feathered dinosaur.
local function foldedWing(b: Body, c: Coat, side: number)
	for row = 0, 3 do
		local theta = side * (0.44 + row * 0.26)
		for k = 0, 5 do
			local z = -0.7 + k * 1.15
			onSpine(b, GSPINE, "GriffinCovert", v3(1.05, 0.3, 1.6), z, theta,
				0.42 - row * 0.07 - math.abs(k - 2.5) * 0.05,
				if (row + k) % 2 == 0 then c.covert else c.covert:Lerp(c.quill, 0.3),
				CFrame.Angles(-0.1, 0, 0))
		end
	end
	for k = 0, 5 do
		onSpine(b, GSPINE, "GriffinWingEdge", v3(0.55, 0.42, 1.5), -0.8 + k * 1.15,
			side * 0.36, 0.5, c.covert:Lerp(c.crown, 0.35))
	end
	for i = 0, 4 do
		local u = i / 4
		feather(b, "GriffinSecondary", side * (1.55 - u * 0.12), 7.9 - u * 0.16, 2.2 + u * 0.3,
			side * (0.14 - u * 0.03), -0.09, 4.4 - u * 0.4, 1.05, 0.22,
			c.primary:Lerp(c.covert, 0.35), c.primary)
	end
	for i = 0, 5 do
		local u = i / 5
		feather(b, "GriffinPrimary", side * (1.45 - u * 0.2), 7.75 - u * 0.14, 3.3 + u * 0.3,
			side * (0.12 - u * 0.04), -0.1 - u * 0.02, 6.8 - u * 0.5, 1.0 - u * 0.1, 0.22,
			c.primary, c.primary:Lerp(c.quill, 0.28))
	end
end

-- MANTLING: the heraldic pose, wings half raised and arched forward. It is the
-- pose a griffin is drawn in on every coat of arms, it shows the whole wing
-- without needing a thirty-stud clearance, and it is what the animal should be
-- doing when it is standing on a paved court with people round it.
local function mantleWing(b: Body, c: Coat, side: number)
	local rx, ry, rz = side * 1.5, 7.0, 0.5
	local ex, ey, ez = side * 3.4, 10.6, 0.4
	local wx, wy, wz = side * 5.2, 9.0, 3.0

	bone(b, "GriffinHumerus", rx, ry, rz, ex, ey, ez, 1.25, 0.9, c.covert)
	bone(b, "GriffinRadius", ex, ey, ez, wx, wy, wz, 0.95, 0.7, c.covert)
	bone(b, "GriffinPatagium", rx, ry + 0.2, rz - 0.55, ex, ey, ez - 0.55, 1.4, 0.36, c.covert)

	for row = 0, 2 do
		for k = 0, 5 do
			local u = k / 5
			local ax = rx + (ex - rx) * math.min(1, u * 2) + (wx - ex) * math.max(0, u * 2 - 1)
			local ay = ry + (ey - ry) * math.min(1, u * 2) + (wy - ey) * math.max(0, u * 2 - 1)
			local az = rz + (ez - rz) * math.min(1, u * 2) + (wz - ez) * math.max(0, u * 2 - 1)
			bone(b, "GriffinCovert", ax - side * 0.1, ay - row * 0.5, az + row * 0.35,
				ax - side * 0.16, ay - row * 0.5 - 1.3, az + row * 0.35 + 0.5, 1.4, 0.2,
				if (row + k) % 2 == 0 then c.covert else c.covert:Lerp(c.quill, 0.28))
		end
	end
	for i = 0, 6 do
		local u = i / 6
		feather(b, "GriffinSecondary", ex + (wx - ex) * u - side * 0.15,
			ey + (wy - ey) * u - 0.4, ez + (wz - ez) * u + 0.35,
			side * (0.5 + u * 0.1), -1.02, 6.0 - u * 0.6, 1.3, 0.2,
			if i % 2 == 0 then c.primary:Lerp(c.covert, 0.4) else c.primary:Lerp(c.covert, 0.22),
			c.primary)
	end
	for i = 0, 6 do
		local u = i / 6
		feather(b, "GriffinPrimary", wx + side * 0.16 * i, wy - 0.1 * i, wz + 0.24 * i,
			side * (0.86 - u * 0.5), -0.62 - u * 0.24, 7.0 - u * 1.5, 1.28 - u * 0.3, 0.22,
			c.primary, c.primary:Lerp(c.quill, 0.3))
	end
	feather(b, "GriffinAlula", wx, wy + 0.3, wz - 0.7, side * 1.15, -0.3, 1.7, 0.55, 0.18,
		c.covert, c.primary)
end

local function griffinWing(b: Body, c: Coat, side: number, pose: string)
	ball(b, "GriffinWingShoulder", 2.8, side * 1.4, 7.1, 0.8, c.covert)
	if pose == "spread" then
		spreadWing(b, c, side)
	elseif pose == "mantle" then
		mantleWing(b, c, side)
	else
		foldedWing(b, c, side)
	end
end

function CreatureKit.griffin(ctx: Ctx, o: {
	x: number, y: number, z: number,
	yaw: number?, pitch: number?, roll: number?,
	scale: number?, coat: Coat, wings: string?, seed: number?,
})
	local root = CFrame.new(o.x, o.y, o.z)
		* CFrame.Angles(0, o.yaw or 0, 0)
		* CFrame.Angles(o.pitch or 0, 0, o.roll or 0)
	local b: Body = {
		ctx = ctx,
		root = root,
		s = o.scale or 1,
		plume = o.coat,
		seed = o.seed or 31,
	}
	local c = o.coat
	griffinBody(b, c)
	griffinNeck(b, c)
	griffinHead(b, c)
	griffinTail(b, c)
	for _, side in { -1, 1 } do
		griffinForeleg(b, c, side)
		griffinHindleg(b, c, side)
		griffinWing(b, c, side, o.wings or "folded")
	end
end

local function grgb(r: number, g: number, bb: number): Color3
	return Color3.fromRGB(r, g, bb)
end

-- A golden eagle in front and a lioness behind: one warm family of colours so
-- the two halves belong to one animal, with the gold of the beak and the eye
-- as the only saturated thing on it. At night that gold is the whole read.
CreatureKit.GRIFFIN = {
	label = "Griffin",
	scale = 0.85,
	coat = {
		hood = grgb(214, 197, 163),
		crown = grgb(150, 118, 66),
		hackle = grgb(196, 158, 84),
		breast = grgb(122, 92, 56),
		covert = grgb(100, 78, 52),
		primary = grgb(58, 48, 40),
		quill = grgb(148, 122, 88),
		fur = grgb(198, 160, 100),
		belly = grgb(224, 200, 154),
		tuft = grgb(74, 60, 44),
		beak = grgb(222, 186, 118),
		cere = grgb(214, 164, 60),
		iris = grgb(255, 176, 10),
		talon = grgb(32, 30, 32),
	},
}

function CreatureKit.buildGriffin(ctx: Ctx, x: number, y: number, z: number,
	yaw: number?, wings: string?, grow: number?, pitch: number?, roll: number?)
	CreatureKit.griffin(ctx, {
		x = x, y = y, z = z,
		yaw = yaw, pitch = pitch, roll = roll,
		scale = CreatureKit.GRIFFIN.scale * (grow or 1),
		coat = CreatureKit.GRIFFIN.coat,
		wings = wings,
	})
end


return CreatureKit
