--!strict
-- Build a building FROM THE DRAWING.
--
-- This is the step the whole plan was written around. Until now MapService has
-- been the author of the campus: every wall, every door, every stair was a
-- number typed into a seven-thousand-line file by whoever was adding that
-- feature, and CampusPlan could only be checked against the result afterwards.
--
-- Here the drawing is the input. Give this a building's name and it emits the
-- floors, the walls, the openings, the windows, the roof and the entrances that
-- CampusPlan says that building has -- and nothing else. A wall that is not
-- drawn cannot be built, which is the property the last several months of
-- whack-a-mole were missing.
--
-- It takes its part maker, its tagger and its prop placer from the caller
-- rather than requiring MapService back, so it stays a leaf module the way
-- CollegiateKit does.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampusPlan = require(ReplicatedStorage.Shared.CampusPlan)
local Kit = require(script.Parent.CollegiateKit)

local PlanBuilder = {}

export type Ctx = {
	parent: Instance,
	part: (props: { [string]: any }) -> BasePart,
	tag: (part: Instance, tag: string) -> (),
	prop: ((kind: string, cf: CFrame, options: any?) -> ())?,
}

local FLOOR = Color3.fromRGB(196, 194, 188)
local CEILING = Color3.fromRGB(238, 234, 224)
local STONE = Kit.STONE
local ASHLAR = Kit.ASHLAR
local GLASS_LIT = Kit.GLASS_LIT
local FRAME = Kit.FRAME
local TIMBER = Kit.TIMBER

-- The layer ladder, same as MapService's: a thing drawn ON a surface takes the
-- next rung up, never that surface's own height.
local FLOOR_THICK = 1.0
local CEIL_THICK = 0.6
local WINDOW_PITCH = 22.0
local WINDOW_W = 8.0
local WINDOW_H = 11.0
local SILL = 5.0

local function kit(ctx: Ctx): Kit.Ctx
	return { parent = ctx.parent, part = ctx.part :: any, tag = ctx.tag :: any }
end

-- ---------------------------------------------------------------------------
-- WALLS
-- ---------------------------------------------------------------------------
-- A wall run minus the openings drawn in it. The gaps are cut, not painted
-- over: the two stubs either side of a doorway are separate parts, and the head
-- above it is a third, so a door is a hole you can walk through rather than a
-- dark rectangle on a solid wall.
local function wallRun(
	ctx: Ctx,
	name: string,
	from: { number },
	to: { number },
	baseY: number,
	height: number,
	thickness: number,
	gaps: { { at: number, width: number, height: number } },
	tagName: string
)
	local dx, dz = to[1] - from[1], to[2] - from[2]
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.1 then
		return
	end
	local alongX = math.abs(dx) > math.abs(dz)
	local dir = if alongX then (if dx > 0 then 1 else -1) else (if dz > 0 then 1 else -1)
	local originAlong = if alongX then from[1] else from[2]
	local across = if alongX then from[2] else from[1]

	local function slab(nm: string, startAt: number, endAt: number, y0: number, y1: number)
		local span = endAt - startAt
		if span <= 0.05 or y1 - y0 <= 0.05 then
			return
		end
		local mid = (startAt + endAt) / 2
		local size = if alongX
			then Vector3.new(span, y1 - y0, thickness)
			else Vector3.new(thickness, y1 - y0, span)
		local cf = if alongX
			then CFrame.new(mid, (y0 + y1) / 2, across)
			else CFrame.new(across, (y0 + y1) / 2, mid)
		ctx.tag(ctx.part({ Name = nm, Size = size, CFrame = cf, Color = STONE, Material = Enum.Material.Slate, Parent = ctx.parent }), tagName)
	end

	-- put the gaps in order along the run
	local sorted = table.clone(gaps)
	table.sort(sorted, function(a, b)
		return a.at < b.at
	end)

	local lo = math.min(originAlong, originAlong + dir * length)
	local hi = math.max(originAlong, originAlong + dir * length)
	local cursor = lo
	for _, gap in sorted do
		local g0 = gap.at - gap.width / 2
		local g1 = gap.at + gap.width / 2
		if g1 <= lo or g0 >= hi then
			continue
		end
		g0 = math.max(g0, lo)
		g1 = math.min(g1, hi)
		slab(name, cursor, g0, baseY, baseY + height)
		-- the head over the opening
		slab(name .. "Head", g0, g1, baseY + gap.height, baseY + height)
		cursor = g1
	end
	slab(name, cursor, hi, baseY, baseY + height)
end

-- ---------------------------------------------------------------------------
-- WINDOWS
-- ---------------------------------------------------------------------------
-- Bays down an exterior wall at a fixed pitch, skipping anywhere an opening is
-- already drawn. Each is a stone surround, a lit leaf and a mullion -- the same
-- vocabulary as the Academy, so the ring buildings read as the same school.
local function windowsAlong(
	ctx: Ctx,
	from: { number },
	to: { number },
	baseY: number,
	height: number,
	gaps: { { at: number, width: number, height: number } },
	outward: number,
	thickness: number
)
	local dx, dz = to[1] - from[1], to[2] - from[2]
	local length = math.sqrt(dx * dx + dz * dz)
	local alongX = math.abs(dx) > math.abs(dz)
	local lo = if alongX then math.min(from[1], to[1]) else math.min(from[2], to[2])
	local across = if alongX then from[2] else from[1]

	local count = math.max(1, math.floor((length - WINDOW_PITCH) / WINDOW_PITCH))
	local spacing = length / (count + 1)
	for i = 1, count do
		local at = lo + i * spacing
		local blocked = false
		for _, gap in gaps do
			if at > gap.at - gap.width / 2 - WINDOW_W and at < gap.at + gap.width / 2 + WINDOW_W then
				blocked = true
				break
			end
		end
		if blocked then
			continue
		end
		-- Size the window to the STOREY, not to a constant.
		--
		-- With a fixed 11-stud light on a 5-stud sill, a sixteen-stud storey
		-- fails the headroom guard for every opening, and the guard is a silent
		-- `continue` -- so the Secret Rooftop block came out with four blank
		-- elevations and the parts simply were not there. Nothing in the suite
		-- could tell that from a building that had no windows drawn.
		local wh = math.clamp(height * 0.44, 4.5, 13.0)
		local sill = math.max(3.0, height * 0.22)
		local y = baseY + sill + wh / 2
		if y + wh / 2 > baseY + height - 1.2 then
			continue
		end
		-- An exterior wall is eight studs thick and centred on the building
		-- line, so its outer face is four studs out from the centreline. The
		-- first version pushed windows out by one or two studs, which put every
		-- one of them INSIDE the masonry: twenty-one windows on the gymnasium,
		-- none of them visible from anywhere.
		local face = thickness / 2
		local function at3(w: number, h: number, d: number, push: number)
			local size = if alongX then Vector3.new(w, h, d) else Vector3.new(d, h, w)
			local cf = if alongX
				then CFrame.new(at, y, across + outward * (face + push))
				else CFrame.new(across + outward * (face + push), y, at)
			return size, cf
		end
		local sSize, sCf = at3(WINDOW_W + 3.0, wh + 3.0, 1.4, -0.5)
		ctx.tag(ctx.part({ Name = "PlanWindowSurround", Size = sSize, CFrame = sCf, Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
		local gSize, gCf = at3(WINDOW_W, wh, 0.6, 0.4)
		local pane = ctx.part({ Name = "PlanWindowGlass", Size = gSize, CFrame = gCf, Color = GLASS_LIT, Material = Enum.Material.Neon, Transparency = 0.34, Parent = ctx.parent })
		pane.CanCollide = false
		pane.CastShadow = false
		local mSize, mCf = at3(0.5, wh, 0.8, 0.7)
		ctx.part({ Name = "PlanWindowMullion", Size = mSize, CFrame = mCf, Color = FRAME, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		local silSize, silCf = at3(WINDOW_W + 4.0, 0.7, 2.2, 0.1)
		local sill = ctx.part({ Name = "PlanWindowSill", Size = silSize, CFrame = silCf, Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent })
		sill.CFrame = silCf - Vector3.new(0, wh / 2 + 0.4, 0)
		sill.CanCollide = false
		ctx.tag(sill, "TexAshlar")
		if i % 2 == 1 then
			local light = Instance.new("PointLight")
			light.Color = Kit.LANTERN
			light.Brightness = 0.8
			light.Range = 22
			light.Shadows = false
			light.Parent = pane
		end
	end
end

-- ---------------------------------------------------------------------------
-- BUILD
-- ---------------------------------------------------------------------------
function PlanBuilder.build(ctx: Ctx, name: string)
	local b = CampusPlan.building(name)
	if not b then
		warn("[PlanBuilder] no drawing for " .. name)
		return
	end
	local K = kit(ctx)
	local rect = b.rect
	local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
	local width, depth = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local top = b.storeys[#b.storeys]
	local eaves = top.y + top.height

	-- ---- doorways, gathered per storey so the walls can be cut for them ----
	local openings: { [number]: { { at: number, width: number, height: number, axis: string, across: number } } } = {}
	for i in b.storeys do
		openings[i] = {}
		for _, door in CampusPlan.doors(b, i) do
			if not door.orphan then
				table.insert(openings[i], {
					at = if door.axis == "z" then door.x else door.z,
					width = door.width,
					height = door.height,
					axis = door.axis,
					across = if door.axis == "z" then door.z else door.x,
				})
			end
		end
	end
	-- the ways in from outside are openings in the exterior wall
	for _, e in b.entrances or {} do
		local vertical = e.facing == "east" or e.facing == "west"
		table.insert(openings[1], {
			at = if vertical then e.at.z else e.at.x,
			width = e.width,
			height = CampusPlan.DOOR_HEIGHT + 2,
			axis = if vertical then "x" else "z",
			across = if vertical then e.at.x else e.at.z,
		})
	end

	for index, storey in b.storeys do
		local cells = CampusPlan.cells(b, index)
		if #cells == 0 then
			continue
		end

		-- ---- the stairwell holes this storey's floor has to be cut for ----
		-- A stair that arrives at this storey comes up THROUGH its floor. With
		-- the floor laid whole, the flight climbed into the underside of the
		-- slab it was climbing to: four studs of headroom on the last third of
		-- every run in the building.
		local wells = {}
		for _, st in b.stairs or {} do
			for _, flight in st.flights do
				local top = math.max(flight.from[2], flight.to[2])
				if math.abs(top - storey.y) < 1.0 then
					local half = st.width / 2
					local runAxis = math.abs(flight.to[1] - flight.from[1]) > math.abs(flight.to[3] - flight.from[3])
					local x0 = math.min(flight.from[1], flight.to[1]) - (if runAxis then 1.0 else half)
					local x1 = math.max(flight.from[1], flight.to[1]) + (if runAxis then 1.0 else half)
					local z0 = math.min(flight.from[3], flight.to[3]) - (if runAxis then half else 1.0)
					local z1 = math.max(flight.from[3], flight.to[3]) + (if runAxis then half else 1.0)
					table.insert(wells, { x0, z0, x1, z1 })
				end
			end
		end

		-- ---- floor under every cell, ceiling over it ----
		for _, cell in cells do
			local r = cell.rect
			local w, d = r[3] - r[1], r[4] - r[2]
			local mx, mz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
			-- band the cell along z at every well edge, split each band along x
			-- around the wells that reach into it, and lay a slab only where no
			-- well covers it
			local zEdges = { r[2], r[4] }
			for _, h in wells do
				if h[1] < r[3] and h[3] > r[1] then
					table.insert(zEdges, math.clamp(h[2], r[2], r[4]))
					table.insert(zEdges, math.clamp(h[4], r[2], r[4]))
				end
			end
			table.sort(zEdges)
			for zi = 1, #zEdges - 1 do
				local z0, z1 = zEdges[zi], zEdges[zi + 1]
				if z1 - z0 > 0.5 then
					local zm = (z0 + z1) / 2
					local xEdges = { r[1], r[3] }
					for _, h in wells do
						if zm > h[2] and zm < h[4] then
							table.insert(xEdges, math.clamp(h[1], r[1], r[3]))
							table.insert(xEdges, math.clamp(h[3], r[1], r[3]))
						end
					end
					table.sort(xEdges)
					for xi = 1, #xEdges - 1 do
						local x0, x1 = xEdges[xi], xEdges[xi + 1]
						local xm = (x0 + x1) / 2
						local covered = false
						for _, h in wells do
							if xm > h[1] and xm < h[3] and zm > h[2] and zm < h[4] then
								covered = true
							end
						end
						if not covered and x1 - x0 > 0.5 then
							ctx.tag(ctx.part({
								Name = "PlanFloor",
								Size = Vector3.new(x1 - x0, FLOOR_THICK, z1 - z0),
								CFrame = CFrame.new((x0 + x1) / 2, storey.y - FLOOR_THICK / 2, (z0 + z1) / 2),
								Color = FLOOR,
								Parent = ctx.parent,
							}), "TexFloorTile")
						end
					end
				end
			end
			local ceil = ctx.part({
				Name = "PlanCeiling",
				Size = Vector3.new(w, CEIL_THICK, d),
				-- bedded UP into the storey above rather than flush with it:
				-- flush is what put sixty thousand square studs of the Academy's
				-- ceiling in the same plane as its own floor
				CFrame = CFrame.new(mx, storey.y + storey.height - CEIL_THICK / 2 + 0.15, mz),
				Color = CEILING,
				Parent = ctx.parent,
			})
			ceil.CanCollide = false
			ctx.tag(ceil, "TexCeiling")

			-- a light in every room, so light_check has something to find
			if cell.kind == "room" or (cell.row == 2 and cell.col == 1) then
				local lamp = ctx.part({
					Name = "PlanRoomLight",
					Size = Vector3.new(math.min(w * 0.4, 10), 0.4, math.min(d * 0.3, 6)),
					CFrame = CFrame.new(mx, storey.y + storey.height - 1.6, mz),
					Color = Color3.fromRGB(255, 248, 230),
					Material = Enum.Material.Neon,
					Parent = ctx.parent,
				})
				lamp.CanCollide = false
				lamp.CastShadow = false
				local light = Instance.new("PointLight")
				light.Brightness = 1.3
				light.Range = math.max(w, d) * 0.9
				light.Color = Color3.fromRGB(255, 244, 218)
				light.Shadows = false
				light.Parent = lamp
			end
		end

		-- ---- the walls the drawing says exist, cut for the drawn openings ----
		for _, wall in CampusPlan.walls(b, index) do
			local vertical = math.abs(wall.to[1] - wall.from[1]) < 0.01
			local axis = if vertical then "x" else "z"
			local across = if vertical then wall.from[1] else wall.from[2]
			local gaps = {}
			for _, o in openings[index] do
				if o.axis == axis and math.abs(o.across - across) < wall.thickness / 2 + 0.6 then
					table.insert(gaps, { at = o.at, width = o.width, height = o.height })
				end
			end
			local nm = if wall.kind == "exterior" then "PlanWall" else "PlanPartition"
			local tagName = if wall.kind == "exterior" then "TexCoursedStone" else "TexPlaster"
			wallRun(ctx, nm, wall.from, wall.to, storey.y, storey.height, wall.thickness, gaps, tagName)

			if wall.kind == "exterior" then
				local outward = if vertical then (if across > cx then 1 else -1) else (if across > cz then 1 else -1)
				windowsAlong(ctx, wall.from, wall.to, storey.y, storey.height, gaps, outward, wall.thickness)
			end
		end
	end

	-- ---- the storey bands and the corners, so it is the same school ----
	for index, storey in b.storeys do
		if index == 1 then
			ctx.tag(ctx.part({ Name = "PlanPlinth", Size = Vector3.new(width + 3.0, 3.0, depth + 3.0), CFrame = CFrame.new(cx, 1.5, cz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
		else
			ctx.tag(ctx.part({ Name = "PlanStringCourse", Size = Vector3.new(width + 1.6, 1.5, depth + 1.6), CFrame = CFrame.new(cx, storey.y, cz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
		end
	end
	ctx.tag(ctx.part({ Name = "PlanCornice", Size = Vector3.new(width + 3.4, 2.2, depth + 3.4), CFrame = CFrame.new(cx, eaves + 1.1, cz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false

	-- ---- rainwater goods ----
	-- Ranking every roof on the campus by the kinds of part on it says the
	-- same thing about all eight buildings: no Gutter, no Downpipe anywhere.
	-- A collegiate stone building carries a gutter along every eave and a
	-- downpipe at the corners and the third points, and in the reference
	-- elevations those downpipes are the dark verticals that break up a long
	-- wall. Ours had eaves boards over nothing.
	local GOODS = Color3.fromRGB(58, 62, 68)
	local hw, hd = width / 2 + 2.3, depth / 2 + 2.3
	local gy = eaves - 0.4
	for _, run in
		{
			{ len = width + 4.6, sx = 0.0, sz = -hd, alongX = true },
			{ len = width + 4.6, sx = 0.0, sz = hd, alongX = true },
			{ len = depth + 4.6, sx = -hw, sz = 0.0, alongX = false },
			{ len = depth + 4.6, sx = hw, sz = 0.0, alongX = false },
		}
	do
		ctx.part({
			Name = "PlanGutter",
			Size = if run.alongX then Vector3.new(run.len, 1.2, 1.7) else Vector3.new(1.7, 1.2, run.len),
			CFrame = CFrame.new(cx + run.sx, gy, cz + run.sz),
			Color = GOODS,
			Material = Enum.Material.Metal,
			Parent = ctx.parent,
		}).CanCollide = false
		local n = math.max(3, math.round(run.len / 15))
		for i = 0, n do
			local t = -0.5 + i / n
			ctx.part({
				Name = "PlanGutterBracket",
				Size = Vector3.new(0.5, 0.7, 0.5),
				CFrame = CFrame.new(
					cx + (if run.alongX then run.len * t else run.sx),
					gy - 0.95,
					cz + (if run.alongX then run.sz else run.len * t)
				),
				Color = GOODS,
				Material = Enum.Material.Metal,
				Parent = ctx.parent,
			}).CanCollide = false
		end
	end
	for _, dp in
		{
			Vector2.new(-hw + 1.2, -hd + 1.2),
			Vector2.new(hw - 1.2, -hd + 1.2),
			Vector2.new(-hw + 1.2, hd - 1.2),
			Vector2.new(hw - 1.2, hd - 1.2),
			Vector2.new(-width / 6, -hd + 0.5),
			Vector2.new(width / 6, -hd + 0.5),
			Vector2.new(-width / 6, hd - 0.5),
			Vector2.new(width / 6, hd - 0.5),
		}
	do
		local px, pz = cx + dp.X, cz + dp.Y
		ctx.part({ Name = "PlanHopper", Size = Vector3.new(2.2, 2.4, 2.2), CFrame = CFrame.new(px, gy - 1.7, pz), Color = GOODS, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		local runLen = gy - 4.2
		-- A cylinder spins about its LOCAL X, so a vertical pipe is a length
		-- along X turned a quarter turn about Z.
		ctx.part({
			Name = "PlanDownpipe",
			Size = Vector3.new(runLen, 1.2, 1.2),
			CFrame = CFrame.new(px, 1.2 + runLen / 2, pz) * CFrame.Angles(0, 0, math.pi / 2),
			Shape = Enum.PartType.Cylinder,
			Color = GOODS,
			Material = Enum.Material.Metal,
			Parent = ctx.parent,
		}).CanCollide = false
		local clips = math.max(2, math.floor(runLen / 13))
		for i = 1, clips do
			ctx.part({ Name = "PlanPipeClip", Size = Vector3.new(1.9, 0.7, 1.9), CFrame = CFrame.new(px, 1.2 + runLen * i / (clips + 1), pz), Color = GOODS, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		end
		ctx.part({ Name = "PlanPipeShoe", Size = Vector3.new(1.6, 2.2, 1.6), CFrame = CFrame.new(px, 1.4, pz) * CFrame.Angles(math.rad(if dp.Y < 0 then -16 else 16), 0, 0), Color = GOODS, Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.part({ Name = "PlanPipeGully", Size = Vector3.new(3.0, 0.5, 3.0), CFrame = CFrame.new(px, 0.35, pz + (if dp.Y < 0 then -1.0 else 1.0)), Color = Color3.fromRGB(96, 96, 100), Material = Enum.Material.Concrete, Parent = ctx.parent }).CanCollide = false
	end

	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		ctx.tag(ctx.part({
			Name = "PlanQuoin",
			Size = Vector3.new(5.0, eaves - 1.0, 5.0),
			CFrame = CFrame.new(cx + corner.X * (width / 2 - 1.0), (eaves + 1.0) / 2, cz + corner.Z * (depth / 2 - 1.0)),
			Color = ASHLAR,
			Material = Enum.Material.Concrete,
			Parent = ctx.parent,
		}), "TexAshlar").CanCollide = false
	end

	-- ---- the roof, ridged along the long axis ----
	local runsX = width >= depth
	-- STEEP slate, which is what the reference art is: 35 degrees or so, with
	-- the dormers standing well up the slope. span * 0.30 put a 24-degree roof
	-- on a range 120 studs deep, and from the Dorm Court the boarding house
	-- read as a hundred studs of empty grey between the dormer heads and the
	-- ridge. Clamped at 44 so a wide building does not grow a roof taller than
	-- the building under it.
	local span = if runsX then depth else width
	local rise = math.clamp(span * 0.36, 12, 44)
	Kit.gableRoof(K, {
		x = cx,
		z = cz,
		width = if runsX then width + 4 else depth + 4,
		depth = if runsX then depth + 4 else width + 4,
		eaves = eaves + 2.2,
		rise = rise,
		runsX = runsX,
	})
	-- Gable walls closing the ends, or the roof is two planes over open air.
	--
	-- A gable is a TRIANGLE. Built as a rectangle -- which is what this was --
	-- it stands the full ridge height across the whole end of the building and
	-- reads as an enormous blank slab towering over its own roof, which is
	-- exactly what the first gymnasium looked like. Two mirrored wedges make
	-- the triangle: each is tall at the ridge and falls away to the eaves.
	local span = if runsX then depth + 4 else width + 4
	local endAt = if runsX then width / 2 + 1 else depth / 2 + 1
	for _, side in { -1, 1 } do
		for _, half in { -1, 1 } do
			local piece = Instance.new("WedgePart")
			piece.Name = "PlanGableEnd"
			piece.Anchored = true
			piece.CanCollide = false
			piece.Size = Vector3.new(2.0, rise, span / 2)
			-- yaw 180 puts the wedge's tall face at +Z, so the half on the -Z
			-- side of the ridge rises TOWARD the ridge instead of away from it
			local spin = if half > 0 then 0 else math.rad(180)
			local along = half * span / 4
			piece.CFrame = (if runsX
				then CFrame.new(cx + side * endAt, eaves + 2.2 + rise / 2, cz + along)
				else CFrame.new(cx + along, eaves + 2.2 + rise / 2, cz + side * endAt))
				* CFrame.Angles(0, spin + (if runsX then 0 else math.rad(90)), 0)
			piece.Color = STONE
			piece.Material = Enum.Material.Slate
			piece.Parent = ctx.parent
			ctx.tag(piece, "TexCoursedStone")
		end
		-- a verge board down each slope of the gable
		local vSize = if runsX then Vector3.new(3.2, 1.2, span + 1) else Vector3.new(span + 1, 1.2, 3.2)
		local vAt = if runsX
			then CFrame.new(cx + side * (endAt + 0.6), eaves + 2.6, cz)
			else CFrame.new(cx, eaves + 2.6, cz + side * (endAt + 0.6))
		ctx.tag(ctx.part({ Name = "PlanVerge", Size = vSize, CFrame = vAt, Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false

		-- A GABLE IS NOT A BLANK TRIANGLE. Steepening the roofs made these the
		-- least articulated surfaces on the campus: forty-three studs tall and
		-- up to sixty-seven across, with a verge board down each slope and
		-- nothing else on them -- and every one of them faces open ground. A
		-- gable end carries a window, a kneeler where it meets the eaves, and
		-- a coping block at the apex.
		--
		-- `out` is the outward normal in the axis the gable faces, so the same
		-- code serves a range running east-west and one running north-south.
		local function atGable(outward: number, up: number, across: number): CFrame
			return if runsX
				then CFrame.new(cx + side * (endAt + outward), eaves + 2.2 + up, cz + across)
				else CFrame.new(cx + across, eaves + 2.2 + up, cz + side * (endAt + outward))
		end
		local function facing(thick: number, height: number, wide: number): Vector3
			return if runsX
				then Vector3.new(thick, height, wide)
				else Vector3.new(wide, height, thick)
		end

		local gw = math.min(10.0, span * 0.16)
		local gh = math.min(14.0, rise * 0.42)
		local gy = rise * 0.26
		ctx.tag(ctx.part({ Name = "PlanGableSurround", Size = facing(1.6, gh + 3.4, gw + 3.4), CFrame = atGable(1.6, gy, 0), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
		-- PROUD of the surround, not inside it. The surround is 1.6 of opaque
		-- ashlar reaching to 2.4; a pane at 2.0 sits wholly behind its own
		-- frame, which from outside is a stone slab with a lit window nobody
		-- can see. tools/window_check.py calls that buried, and it is.
		local pane = ctx.part({ Name = "PlanGableWindow", Size = facing(0.7, gh, gw), CFrame = atGable(2.6, gy, 0), Color = Color3.fromRGB(255, 196, 107), Material = Enum.Material.Neon, Transparency = 0.34, Parent = ctx.parent })
		pane.CanCollide = false
		pane.CastShadow = false
		ctx.part({ Name = "PlanGableMullion", Size = facing(1.0, gh, 0.6), CFrame = atGable(2.9, gy, 0), Color = Color3.fromRGB(42, 42, 40), Material = Enum.Material.Metal, Parent = ctx.parent }).CanCollide = false
		ctx.tag(ctx.part({ Name = "PlanGableSill", Size = facing(2.4, 0.9, gw + 5.0), CFrame = atGable(1.4, gy - gh / 2 - 2.1, 0), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 220, 160)
		glow.Brightness = 0.8
		glow.Range = 22
		glow.Shadows = false
		glow.Parent = pane

		-- kneelers where the verge meets the eaves, and a coping at the apex
		for _, foot in { -1, 1 } do
			ctx.tag(ctx.part({ Name = "PlanGableKneeler", Size = facing(4.6, 2.8, 5.4), CFrame = atGable(0.6, 0.4, foot * (span / 2 - 0.4)), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
		end
		ctx.tag(ctx.part({ Name = "PlanGableCoping", Size = facing(4.4, 2.2, 4.4), CFrame = atGable(0.6, rise + 0.7, 0), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar").CanCollide = false
	end

	-- dormers down the long slopes, and a chimney on each gable end
	local slopeCount = math.max(2, math.floor((if runsX then width else depth) / 46))
	for i = 1, slopeCount do
		local t = (i - 0.5) / slopeCount
		local along = (if runsX then x0 else z0) + t * (if runsX then width else depth)
		local halfSpan = (if runsX then depth else width) / 2 + 2
		local dormerBase = eaves + 2.2 + rise * 0.34
		local set = halfSpan * 0.62
		-- both slopes. A pitched roof has two, and putting dormers on only one
		-- of them gives a building that looks finished from one side.
		for _, slope in { -1, 1 } do
			if runsX then
				Kit.dormer(K, { x = along, y = dormerBase, z = cz + slope * set, facing = if slope > 0 then 0 else 180, width = 7, height = 6 })
			else
				Kit.dormer(K, { x = cx + slope * set, y = dormerBase, z = along, facing = if slope > 0 then 90 else 270, width = 7, height = 6 })
			end
		end
	end
	-- Chimney stacks ALONG the ridge, not one at each gable end. A range three
	-- hundred studs long with two stacks reads as a shed with a fire at either
	-- end of it; a boarding house has one over every pair of rooms, and the
	-- stacks are half of what makes a collegiate roofline read as one.
	local ridgeRun = if runsX then width else depth
	local stacks = math.max(2, math.round(ridgeRun / 70))
	for i = 0, stacks - 1 do
		local t = i / (stacks - 1)
		local along = (if runsX then x0 else z0) + 8 + t * (ridgeRun - 16)
		local chx = if runsX then along else cx
		local chz = if runsX then cz else along
		Kit.chimney(K, { x = chx, z = chz, base = eaves, height = rise + 10, width = 6 })
	end

	-- ---- the way in ----
	for _, e in b.entrances or {} do
		local vertical = e.facing == "east" or e.facing == "west"
		local outward = if e.facing == "east" or e.facing == "north" then 1 else -1
		local ex = if vertical then e.at.x + outward * 1.6 else e.at.x
		local ez = if vertical then e.at.z else e.at.z + outward * 1.6
		local doorH = CampusPlan.DOOR_HEIGHT + 2

		local leafSize = if vertical
			then Vector3.new(1.2, doorH - 1, e.width / 2 - 0.4)
			else Vector3.new(e.width / 2 - 0.4, doorH - 1, 1.2)
		for _, half in { -1, 1 } do
			local lx = if vertical then ex else ex + half * e.width / 4
			local lz = if vertical then ez + half * e.width / 4 else ez
			ctx.part({ Name = "PlanDoorLeaf", Size = leafSize, CFrame = CFrame.new(lx, (doorH - 1) / 2, lz), Color = TIMBER, Material = Enum.Material.WoodPlanks, Parent = ctx.parent }).CanCollide = false
		end
		-- an arch over it, and a name board over that
		local span = e.width + 4
		-- Turned to face the wall it is in, not transposed. Swapping x and z
		-- does not rotate an arch; it puts it somewhere else on the map.
		Kit.pointedArch(K, {
			x = ex,
			y = doorH + 0.4,
			z = ez,
			yaw = if vertical then math.rad(90) else 0,
			span = span,
			rise = span * 0.75,
			depth = 3.0,
			ring = 2.2,
			segments = 8,
		})
		for _, step in { 0, 1, 2 } do
			local sw = e.width + 8 - step * 2
			local size = if vertical then Vector3.new(6 - step * 1.2, 1, sw) else Vector3.new(sw, 1, 6 - step * 1.2)
			local px = if vertical then ex + outward * (2.4 + step * 2.2) else ex
			local pz = if vertical then ez else ez + outward * (2.4 + step * 2.2)
			ctx.tag(ctx.part({ Name = "PlanStep", Size = size, CFrame = CFrame.new(px, 0.5 - step * 0.34, pz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar")
		end
		for _, half in { -1, 1 } do
			-- clear of the wall face. The entrance point is on the building line
			-- and the wall is eight studs thick, so a lantern half a stud out
			-- from there is inside the masonry.
			local lx = if vertical then ex + outward * 3.4 else ex + half * (e.width / 2 + 1.5)
			local lz = if vertical then ez + half * (e.width / 2 + 1.5) else ez + outward * 3.4
			local glow = ctx.part({ Name = "PlanPorchGlow", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(lx, 13, lz), Color = Kit.LANTERN, Material = Enum.Material.Neon, Transparency = 0.4, Parent = ctx.parent })
			glow.CanCollide = false
			glow.CastShadow = false
			local lamp = Instance.new("PointLight")
			lamp.Color = Kit.LANTERN
			lamp.Brightness = 1.1
			lamp.Range = 26
			lamp.Shadows = false
			lamp.Parent = glow
			if ctx.prop then
				(ctx.prop :: any)("WallLantern", CFrame.new(lx, 13, lz))
			end
		end
	end

	-- ---- the stairs, exactly as drawn ----
	for _, st in b.stairs or {} do
		for _, flight in st.flights do
			local a, c = flight.from, flight.to
			local rise2 = c[2] - a[2]
			local steps = math.max(2, math.floor(rise2 / CampusPlan.STAIR_RISE))
			for i = 1, steps do
				local t = i / steps
				local tx = a[1] + (c[1] - a[1]) * t
				local tz = a[3] + (c[3] - a[3]) * t
				local ty = a[2] + rise2 * t
				local runAxis = math.abs(c[1] - a[1]) > math.abs(c[3] - a[3])
				local tread = if runAxis
					then Vector3.new(math.abs(c[1] - a[1]) / steps + 0.2, 0.6, st.width)
					else Vector3.new(st.width, 0.6, math.abs(c[3] - a[3]) / steps + 0.2)
				ctx.tag(ctx.part({ Name = "PlanTread", Size = tread, CFrame = CFrame.new(tx, ty - 0.3, tz), Color = ASHLAR, Material = Enum.Material.Concrete, Parent = ctx.parent }), "TexAshlar")
			end
		end
		for _, pad in st.landings or {} do
			local r = pad.rect
			ctx.tag(ctx.part({
				Name = "PlanLanding",
				-- top at pad.y + 0.05, not pad.y: the tread at the head of the
				-- flight tops out at exactly pad.y and the two shared a plane
				Size = Vector3.new(r[3] - r[1], 0.9, r[4] - r[2]),
				CFrame = CFrame.new((r[1] + r[3]) / 2, pad.y - 0.4, (r[2] + r[4]) / 2),
				Color = ASHLAR,
				Material = Enum.Material.Concrete,
				Parent = ctx.parent,
			}), "TexAshlar")
		end
	end
end

return PlanBuilder
