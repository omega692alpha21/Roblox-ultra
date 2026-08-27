--!strict
-- Runs moulding along the junctions MapService recorded.
--
-- Every junction in the school used to be a raw 90 degree corner between two
-- prisms. Nothing in the painterly references has one: real architecture runs
-- a profile along every wall/floor, wall/ceiling and opening edge, and the
-- highlight a profile catches is what makes a surface read as built rather
-- than extruded. This is the single biggest thing separating generated
-- geometry from hand-made environment art.
--
-- The profiles are one-stud extrusions (tools/make_trim.py), so they are only
-- ever scaled along their run and the cross-section stays exactly as drawn at
-- any length. A bevel baked into a cube would stretch into a wedge the moment
-- the wall was forty studs long.
--
-- They are placed here rather than in MapService because MeshPart.MeshId
-- cannot be assigned by a script. A template loaded through InsertService
-- carries its MeshId as data, and a clone of it keeps it — Size is ordinary
-- and can be set per run.

local InsertService = game:GetService("InsertService")

local MapService = require(script.Parent.MapService)

local TrimService = {}

type Profile = { id: number, height: number, depth: number, color: Color3 }

local PROFILES: { [string]: Profile } = {
	skirting = { id = 136604526133658, height = 1.6, depth = 0.34, color = Color3.fromRGB(238, 234, 224) },
	chairrail = { id = 76505556227119, height = 0.7, depth = 0.3, color = Color3.fromRGB(238, 234, 224) },
	cornice = { id = 80687333156758, height = 1.5, depth = 1.2, color = Color3.fromRGB(244, 241, 233) },
	architrave = { id = 83748020444014, height = 0.9, depth = 0.3, color = Color3.fromRGB(232, 226, 212) },
	sill = { id = 109240376079957, height = 0.5, depth = 0.92, color = Color3.fromRGB(226, 220, 208) },
	fascia = { id = 97678847761811, height = 1.4, depth = 0.62, color = Color3.fromRGB(206, 198, 188) },
}

local function loadProfile(kind: string, spec: Profile): MeshPart?
	local ok, result = pcall(function()
		return InsertService:LoadAsset(spec.id)
	end)
	if not ok or not result then
		warn(("[TrimService] %s failed to load (%d): %s"):format(kind, spec.id, tostring(result)))
		return nil
	end
	local mesh: MeshPart? = nil
	for _, item in result:GetDescendants() do
		if item:IsA("MeshPart") then
			mesh = item
			break
		end
	end
	if not mesh then
		warn("[TrimService] " .. kind .. " contained no MeshPart")
		return nil
	end
	local template = mesh :: MeshPart
	template.Anchored = true
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	-- a moulding casting its own shadow reads as a seam, not as relief
	template.CastShadow = false
	template.Material = Enum.Material.SmoothPlastic
	template.Color = spec.color
	template.CollisionFidelity = Enum.CollisionFidelity.Box
	template.Parent = nil
	return template
end

function TrimService.Init(map: MapService.Map)
	local runs = map.trim
	if not runs or #runs == 0 then
		return
	end

	local templates: { [string]: MeshPart } = {}
	for kind, spec in PROFILES do
		local template = loadProfile(kind, spec)
		if template then
			templates[kind] = template
		end
	end
	if next(templates) == nil then
		warn("[TrimService] no profiles loaded; the school keeps its bare corners")
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Mouldings"
	folder.Parent = map.folder

	local placed = 0
	for index, run in runs do
		local template = templates[run.kind]
		local spec = PROFILES[run.kind]
		if not template or not spec then
			continue
		end
		local piece = template:Clone()
		piece.Name = "Trim_" .. run.kind
		piece.Size = Vector3.new(run.length, spec.height, spec.depth)
		piece.CFrame = run.cframe * CFrame.new(run.length / 2, spec.height / 2, -spec.depth / 2)
		piece.Parent = folder
		placed += 1
		-- a few hundred meshes at once stalls the first frames of a join
		if index % 60 == 0 then
			task.wait()
		end
	end

	print(("[TrimService] ran %d mouldings along the school"):format(placed))
end

return TrimService
