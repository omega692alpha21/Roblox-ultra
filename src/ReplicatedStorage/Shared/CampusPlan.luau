--!strict
-- THE DRAWING. Every wall, door, stair and room on the campus, as data.
--
-- Crumbworth High was never drawn before it was built. Every coordinate in
-- MapService was chosen in isolation, months apart, by whoever was adding that
-- feature, which is why the school grew stairs behind walls, lockers across the
-- principal's door, and two signs pointing at each other's rooms. Each of those
-- was found by playing, fixed by hand, and replaced by the next one.
--
-- This file ends that. It is the ONE place the layout lives. MapService is only
-- allowed to RENDER it -- walls from Plan.walls, stairs from Plan.stairs,
-- openings from Plan.doors -- so a wall or a staircase that is not drawn here
-- cannot be built. tools/plan_check.py validates the drawing on its own, in
-- under a second, before a single part exists.
--
-- Axes: +x east, +z north, y up. The Academy's front doors face +z, onto the
-- Great Court. Rects are {x0, z0, x1, z1} with x0 < x1 and z0 < z1, in studs.

local Plan = {}

-- ---------------------------------------------------------------------------
-- THE PLOT
-- ---------------------------------------------------------------------------
-- The core is the built campus. The plot is a little over twice its area, and
-- the difference is held as four cleared, drained, grassed reserves inside the
-- outer wall -- so the next building drops onto ready ground instead of forcing
-- another re-survey of everything already standing.

Plan.PLOT = { -800, -640, 840, 780 } -- 1640 x 1420 = 2,328,800
Plan.CORE = { -560, -420, 590, 560 } -- 1150 x  980 = 1,127,000

Plan.RESERVES = {
	{ name = "North Reserve", rect = { -800, 560, 840, 780 } },
	{ name = "South Reserve", rect = { -800, -640, 840, -420 } },
	{ name = "West Reserve", rect = { -800, -420, -560, 560 } },
	{ name = "East Reserve", rect = { 590, -420, 840, 560 } },
}

-- Nothing may be built in a reserve, and the reserves together must stay at or
-- above this multiple of the core's area, so expansion room cannot be quietly
-- eaten by the next thing somebody wants to put up.
Plan.RESERVE_RATIO = 0.9

-- ---------------------------------------------------------------------------
-- CONSTRUCTION CONSTANTS
-- ---------------------------------------------------------------------------

Plan.EXTERIOR_WALL = 8.0 -- coursed stone, load bearing
Plan.PARTITION = 3.0 -- interior division
Plan.DOOR_WIDTH = 12.0
Plan.DOOR_HEIGHT = 11.0
Plan.GRAND_DOOR_WIDTH = 20.0
Plan.CORRIDOR_CLEAR = 24.0 -- a corridor's middle must stay this clear
Plan.HEADROOM = 9.0 -- floor to the underside of anything above it
Plan.STAIR_RISE = 0.8
Plan.STAIR_TREAD = 1.6
Plan.LANDING = 14.0

-- ---------------------------------------------------------------------------
-- THE SITE
-- ---------------------------------------------------------------------------
-- Every structure on the campus and the ground it stands on. `link` names the
-- structures this one is allowed to touch; anything else that overlaps is a
-- collision the checker rejects.

Plan.SITE = {
	{ name = "Academy", rect = { -224, -124, 224, 124 }, kind = "building" },
	{ name = "Great Court", rect = { -150, 135, 150, 285 }, kind = "grounds" },
	{ name = "Student Dorms", rect = { -150, -370, 150, -250 }, kind = "building" },
	{ name = "Library", rect = { -420, -348, -220, -252 }, kind = "building" },
	{ name = "Cafeteria", rect = { 220, -348, 420, -252 }, kind = "building" },
	{ name = "Detention Hall", rect = { -485, -40, -315, 80 }, kind = "building" },
	{ name = "Parking Lot", rect = { 335, -35, 525, 115 }, kind = "grounds" },
	{ name = "Sports Field", rect = { 300, 150, 580, 320 }, kind = "grounds" },
	{ name = "Gymnasium", rect = { 165, 340, 355, 470 }, kind = "building", link = { "Hidden Alley" } },
	{ name = "Secret Rooftop", rect = { -295, 345, -125, 455 }, kind = "building", link = { "Hidden Alley" } },
	{ name = "Hidden Alley", rect = { -125, 390, 165, 410 }, kind = "grounds", link = { "Gymnasium", "Secret Rooftop" } },
	{ name = "Bike Track", rect = { -550, 230, -310, 430 }, kind = "grounds" },
	{ name = "Main Gate", rect = { -30, 540, 30, 560 }, kind = "grounds" },
}

-- The ceremonial approach: the axis from the gate to the front doors. Nothing
-- back-of-house (bins, sheds, courts, goalposts, skips) may stand on it.
Plan.APPROACH = { -150, 124, 150, 575 }

-- ---------------------------------------------------------------------------
-- THE ACADEMY
-- ---------------------------------------------------------------------------
-- Drawn as a grid rather than as a list of rooms, because a grid is the one
-- form in which "every room opens onto a corridor" is true BY CONSTRUCTION
-- instead of true by inspection. The bands below cut the interior into cells;
-- two columns and two rows are corridor, and every remaining cell touches at
-- least one of them on a full face. There is no way to draw a landlocked room.
--
--   columns  1 W0 | 2 corridor | 3 W1 | 4 CENTRE | 5 E1 | 6 corridor | 7 E0
--   rows     1 rear | 2 corridor | 3 middle | 4 corridor | 5 front
--
-- Row 5 is the front range, facing the Great Court. Row 1 backs onto the dorms.

local ACADEMY_X = { -216, -152, -120, -56, 56, 120, 152, 216 }
local ACADEMY_Z = { -116, -52, -20, 44, 76, 116 }

Plan.BUILDINGS = {
	{
		name = "Academy",
		rect = { -224, -124, 224, 124 },
		facing = "north", -- +z
		grid = { x = ACADEMY_X, z = ACADEMY_Z, corridorCols = { 2, 6 }, corridorRows = { 2, 4 } },
		storeys = {
			{ y = 0.0, height = 16.0, name = "Ground" },
			{ y = 16.0, height = 16.0, name = "Upper" },
			{ y = 32.0, height = 15.0, name = "Top", inRoof = true },
		},
		-- cells[storey][row][col]. false = not a room on this storey (roof void,
		-- or the open well of a double-height space below).
		cells = {
			{ -- Ground
				{ "Art room", false, "Chemistry lab", "Assembly hall", "Computer lab", false, "History room" },
				{},
				{ "Science lab", false, "Music room", "Atrium", "Room 101", false, "Maths room" },
				{},
				{ "Infirmary", false, "Reception", "Entrance hall", "Trophy hall", false, "Principal's office" },
			},
			{ -- Upper
				{ "Homeroom 2C", false, "Homeroom 2D", "Assembly gallery", "Homeroom 2E", false, "Homeroom 2F" },
				{},
				{ "Physics lab", false, "Biology lab", "Great stair", "Homeroom 2A", false, "Homeroom 2B" },
				{},
				{ "Art studio", false, "Language room", false, "Staff room", false, "Geography room" },
			},
			{ -- Top: inside the roof, so only the front range and the stair head
				{ false, false, false, false, false, false, false },
				{},
				{ false, false, false, "Great stair head", false, false, false },
				{},
				{ "Records room", false, "Secretary's office", "Headmaster's office", "Waiting room", false, "Board room" },
			},
		},
		-- Which corridors exist on which storey. The top floor is under the roof
		-- slope, so only the front corridor runs up there.
		storeyCorridors = {
			{ cols = { 2, 6 }, rows = { 2, 4 } },
			{ cols = { 2, 6 }, rows = { 2, 4 } },
			{ cols = {}, rows = { 4 } },
		},
		-- Rooms that rise through more than one storey. The cell above one of
		-- these is false, and the checker knows that is deliberate rather than a
		-- floor with a hole in it.
		doubleHeight = {
			-- the entrance hall is two storeys tall, so the cell above it is
			-- deliberately empty rather than a floor with a hole in it
			{ storey = 1, row = 5, col = 4, storeys = 2 },
		},
		-- Every stair, drawn: where it starts, where it lands, how wide, and
		-- which cell it lives in. Nothing else may occupy the run.
		-- Every stair, drawn as flights. A flight's horizontal run has to cover
		-- its own rise at the going below, and consecutive flights have to meet
		-- on a landing -- which is checked, not assumed. Both stairs stand in
		-- the Atrium cell (112 x 64) side by side in x rather than stacked in z,
		-- because two U-flights and their landings need 46 studs of depth each
		-- and the cell only has 64.
		stairs = {
			{
				name = "Great stair",
				cell = { row = 3, col = 4 },
				width = 18.0,
				flights = {
					{ from = { -38, 0.0, 40 }, to = { -38, 8.0, 24 } },
					{ from = { -20, 8.0, 6 }, to = { -20, 16.0, -10 } },
				},
				landings = { { y = 8.0, rect = { -47, 6, -11, 24 } } },
			},
			{
				name = "Tower stair",
				cell = { row = 3, col = 4 },
				width = 18.0,
				flights = {
					{ from = { 20, 16.0, 40 }, to = { 20, 24.0, 24 } },
					{ from = { 38, 24.0, 6 }, to = { 38, 32.0, -10 } },
				},
				landings = { { y = 24.0, rect = { 11, 6, 47, 24 } } },
			},
		},
		-- The tower stands on the axis over the front range and carries the
		-- clock and the spire. It is not a room; it is a mass.
		tower = { x = 0, z = 96, width = 44, top = 118, spire = 44 },
		-- Ways in from outside, on the outer face of the named wall.
		entrances = {
			{ name = "Front doors", at = { x = 0, z = 124 }, facing = "north", width = 20.0, grand = true },
			{ name = "West door", at = { x = -224, z = -36 }, facing = "west", width = 12.0 },
			{ name = "East door", at = { x = 224, z = -36 }, facing = "east", width = 12.0 },
			{ name = "Rear doors", at = { x = 0, z = -124 }, facing = "south", width = 16.0 },
		},
	},
}

-- ---------------------------------------------------------------------------
-- DERIVATION
-- ---------------------------------------------------------------------------
-- The grid above is the authored drawing; everything below is read off it. A
-- room's rect, its corridor, and the door between them are all computed, so
-- they cannot disagree with each other the way hand-typed numbers do.

export type Rect = { number }

local function isIn(list: { number }, value: number): boolean
	for _, v in list do
		if v == value then
			return true
		end
	end
	return false
end

-- Every cell of a building's grid, as a rect with its row/col and what it is.
function Plan.cells(b, storey: number)
	local gx, gz = b.grid.x, b.grid.z
	local corridors = b.storeyCorridors[storey]
	local out = {}
	for row = 1, #gz - 1 do
		for col = 1, #gx - 1 do
			local isCorridor = isIn(corridors.cols, col) or isIn(corridors.rows, row)
			local named = b.cells[storey][row] and b.cells[storey][row][col]
			if isCorridor or named then
				table.insert(out, {
					row = row,
					col = col,
					rect = { gx[col], gz[row], gx[col + 1], gz[row + 1] },
					kind = if isCorridor then "corridor" else "room",
					name = if isCorridor then string.format("Corridor r%dc%d", row, col) else named,
				})
			end
		end
	end
	return out
end

-- Rooms only, in build order.
function Plan.rooms(b, storey: number)
	local out = {}
	for _, cell in Plan.cells(b, storey) do
		if cell.kind == "room" then
			table.insert(out, cell)
		end
	end
	return out
end

-- Which corridor cell a room opens onto, and the door between them. Preference
-- is a corridor ROW (a door in the room's front or back wall) before a corridor
-- COLUMN, because a corridor row is the spine and that is where a school's
-- classroom doors belong.
function Plan.doors(b, storey: number)
	local gx, gz = b.grid.x, b.grid.z
	local corridors = b.storeyCorridors[storey]
	local out = {}
	for _, room in Plan.rooms(b, storey) do
		local r, c = room.row, room.col
		local door = nil
		if isIn(corridors.rows, r + 1) then
			door = { x = (gx[c] + gx[c + 1]) / 2, z = gz[r + 1], axis = "z" }
		elseif isIn(corridors.rows, r - 1) then
			door = { x = (gx[c] + gx[c + 1]) / 2, z = gz[r], axis = "z" }
		elseif isIn(corridors.cols, c + 1) then
			door = { x = gx[c + 1], z = (gz[r] + gz[r + 1]) / 2, axis = "x" }
		elseif isIn(corridors.cols, c - 1) then
			door = { x = gx[c], z = (gz[r] + gz[r + 1]) / 2, axis = "x" }
		end
		if door then
			table.insert(out, {
				room = room.name,
				row = r,
				col = c,
				x = door.x,
				z = door.z,
				axis = door.axis,
				width = Plan.DOOR_WIDTH,
				height = Plan.DOOR_HEIGHT,
			})
		else
			-- left in deliberately: plan_check reports it as a landlocked room
			table.insert(out, { room = room.name, row = r, col = c, orphan = true })
		end
	end
	return out
end

-- Every wall the building needs on a storey: the exterior envelope, then one
-- partition on each internal grid line that actually divides two occupied
-- cells. A grid line with nothing on one side of it gets no wall, which is why
-- the top floor does not sprout partitions inside its own roof void.
function Plan.walls(b, storey: number)
	local gx, gz = b.grid.x, b.grid.z
	local out = {}
	local occupied = {}
	for _, cell in Plan.cells(b, storey) do
		occupied[cell.row * 100 + cell.col] = cell
	end
	local function at(row: number, col: number)
		return occupied[row * 100 + col]
	end

	local x0, z0, x1, z1 = b.rect[1], b.rect[2], b.rect[3], b.rect[4]
	local t = Plan.EXTERIOR_WALL
	table.insert(out, { from = { x0, z0 }, to = { x1, z0 }, thickness = t, kind = "exterior", storey = storey })
	table.insert(out, { from = { x0, z1 }, to = { x1, z1 }, thickness = t, kind = "exterior", storey = storey })
	table.insert(out, { from = { x0, z0 }, to = { x0, z1 }, thickness = t, kind = "exterior", storey = storey })
	table.insert(out, { from = { x1, z0 }, to = { x1, z1 }, thickness = t, kind = "exterior", storey = storey })

	for col = 2, #gx - 1 do
		for row = 1, #gz - 1 do
			local a, c = at(row, col - 1), at(row, col)
			if a and c and not (a.kind == "corridor" and c.kind == "corridor") then
				table.insert(out, {
					from = { gx[col], gz[row] },
					to = { gx[col], gz[row + 1] },
					thickness = Plan.PARTITION,
					kind = "partition",
					storey = storey,
				})
			end
		end
	end
	for row = 2, #gz - 1 do
		for col = 1, #gx - 1 do
			local a, c = at(row - 1, col), at(row, col)
			if a and c and not (a.kind == "corridor" and c.kind == "corridor") then
				table.insert(out, {
					from = { gx[col], gz[row] },
					to = { gx[col + 1], gz[row] },
					thickness = Plan.PARTITION,
					kind = "partition",
					storey = storey,
				})
			end
		end
	end
	return out
end

function Plan.building(name: string)
	for _, b in Plan.BUILDINGS do
		if b.name == name then
			return b
		end
	end
	return nil
end

return Plan
