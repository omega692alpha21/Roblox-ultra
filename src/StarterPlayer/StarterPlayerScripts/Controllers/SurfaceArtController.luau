--!strict
-- Procedural surface art via EditableImage: brick with mortar courses, lit
-- window panes, and slate shingles, painted client-side onto parts tagged by
-- MapService. Deterministic, generated once per client, zero uploads.
-- Everything is pcall-guarded: if EditableImage isn't available on this
-- device, the flat-color look simply remains.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")

local SurfaceArtController = {}

local OVERWRITE = Enum.ImageCombineType.Overwrite

type Rng = { state: number }
local function lcg(seed: number): Rng
	return { state = seed % 2147483647 }
end
local function nextf(rng: Rng): number
	rng.state = (rng.state * 48271) % 2147483647
	return rng.state / 2147483647
end

local function makeImage(size: number): any?
	local ok, image = pcall(function()
		return (AssetService :: any):CreateEditableImage({ Size = Vector2.new(size, size) })
	end)
	if ok and image then
		return image
	end
	return nil
end

local function drawBrick(): any?
	local image = makeImage(256)
	if not image then
		return nil
	end
	image:DrawRectangle(Vector2.new(0, 0), Vector2.new(256, 256), Color3.fromRGB(186, 178, 166), 0, OVERWRITE)
	local rng = lcg(7)
	local courseH, gap = 20, 4
	local row = 0
	local y = 0
	while y < 256 do
		local offset = (row % 2) * 32
		local x = -offset
		while x < 256 do
			local w = 58
			local shade = 0.88 + nextf(rng) * 0.24
			local base = Color3.fromRGB(150, 92, 70)
			local color = Color3.new(math.clamp(base.R * shade, 0, 1), math.clamp(base.G * shade, 0, 1), math.clamp(base.B * shade, 0, 1))
			image:DrawRectangle(Vector2.new(math.max(x, 0), y), Vector2.new(math.min(w, 256 - math.max(x, 0)), courseH), color, 0, OVERWRITE)
			x += w + gap
		end
		y += courseH + gap
		row += 1
	end
	return image
end

local function drawWindows(): any?
	local image = makeImage(256)
	if not image then
		return nil
	end
	-- frame
	image:DrawRectangle(Vector2.new(0, 0), Vector2.new(256, 256), Color3.fromRGB(228, 224, 214), 0, OVERWRITE)
	-- glass
	image:DrawRectangle(Vector2.new(10, 10), Vector2.new(236, 236), Color3.fromRGB(38, 50, 66), 0, OVERWRITE)
	-- mullions split the tile into 2x2 panes
	image:DrawRectangle(Vector2.new(124, 10), Vector2.new(8, 236), Color3.fromRGB(228, 224, 214), 0, OVERWRITE)
	image:DrawRectangle(Vector2.new(10, 124), Vector2.new(236, 8), Color3.fromRGB(228, 224, 214), 0, OVERWRITE)
	-- some panes glow from inside (classrooms at work)
	local lit = Color3.fromRGB(255, 224, 150)
	image:DrawRectangle(Vector2.new(16, 16), Vector2.new(104, 104), lit, 0.35, OVERWRITE)
	image:DrawRectangle(Vector2.new(136, 136), Vector2.new(104, 104), lit, 0.55, OVERWRITE)
	-- sky reflection streaks on the dark panes
	image:DrawRectangle(Vector2.new(140, 24), Vector2.new(20, 92), Color3.fromRGB(90, 116, 140), 0.3, OVERWRITE)
	image:DrawRectangle(Vector2.new(30, 140), Vector2.new(16, 92), Color3.fromRGB(90, 116, 140), 0.4, OVERWRITE)
	return image
end

local function drawShingles(): any?
	local image = makeImage(256)
	if not image then
		return nil
	end
	image:DrawRectangle(Vector2.new(0, 0), Vector2.new(256, 256), Color3.fromRGB(56, 68, 62), 0, OVERWRITE)
	local rng = lcg(23)
	local rowH = 32
	for row = 0, 7 do
		local y = row * rowH
		-- shadow line under each course
		image:DrawRectangle(Vector2.new(0, y + rowH - 5), Vector2.new(256, 5), Color3.fromRGB(38, 46, 42), 0, OVERWRITE)
		local offset = (row % 2) * 24
		local x = -offset
		while x < 256 do
			local shade = 0.85 + nextf(rng) * 0.3
			local base = Color3.fromRGB(62, 78, 70)
			local color = Color3.new(math.clamp(base.R * shade, 0, 1), math.clamp(base.G * shade, 0, 1), math.clamp(base.B * shade, 0, 1))
			image:DrawRectangle(Vector2.new(math.max(x, 0), y), Vector2.new(math.min(44, 256 - math.max(x, 0)), rowH - 5), color, 0, OVERWRITE)
			x += 48
		end
	end
	return image
end

local function drawFloorTile(): any?
	local image = makeImage(256)
	if not image then
		return nil
	end
	-- grout base, then 2x2 large stone tiles with subtle variation
	image:DrawRectangle(Vector2.new(0, 0), Vector2.new(256, 256), Color3.fromRGB(148, 148, 144), 0, OVERWRITE)
	local rng = lcg(11)
	for ty = 0, 1 do
		for tx = 0, 1 do
			local shade = 0.94 + nextf(rng) * 0.12
			local base = Color3.fromRGB(196, 196, 190)
			image:DrawRectangle(
				Vector2.new(tx * 128 + 3, ty * 128 + 3),
				Vector2.new(122, 122),
				Color3.new(math.clamp(base.R * shade, 0, 1), math.clamp(base.G * shade, 0, 1), math.clamp(base.B * shade, 0, 1)),
				0,
				OVERWRITE
			)
			-- faint speckle
			for _ = 1, 6 do
				local sx = tx * 128 + 10 + math.floor(nextf(rng) * 100)
				local sy = ty * 128 + 10 + math.floor(nextf(rng) * 100)
				image:DrawRectangle(Vector2.new(sx, sy), Vector2.new(4, 4), Color3.fromRGB(170, 170, 164), 0.3, OVERWRITE)
			end
		end
	end
	return image
end

local function drawCarpet(): any?
	local image = makeImage(256)
	if not image then
		return nil
	end
	local rng = lcg(31)
	for ty = 0, 7 do
		for tx = 0, 7 do
			local dark = (tx + ty) % 2 == 0
			local shade = 0.9 + nextf(rng) * 0.2
			local base = dark and Color3.fromRGB(122, 96, 76) or Color3.fromRGB(150, 120, 96)
			image:DrawRectangle(
				Vector2.new(tx * 32, ty * 32),
				Vector2.new(32, 32),
				Color3.new(math.clamp(base.R * shade, 0, 1), math.clamp(base.G * shade, 0, 1), math.clamp(base.B * shade, 0, 1)),
				0,
				OVERWRITE
			)
		end
	end
	return image
end

local function applyTexture(part: BasePart, content: any, faces: { Enum.NormalId }, tileU: number, tileV: number)
	for _, face in faces do
		local texture = Instance.new("Texture")
		texture.Name = "SurfaceArt"
		texture.Face = face
		texture.StudsPerTileU = tileU
		texture.StudsPerTileV = tileV;
		(texture :: any).TextureContent = content
		texture.Parent = part
	end
end

local ALL_FACES = {
	Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left,
	Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom,
}

function SurfaceArtController.Init(_gui: ScreenGui)
	task.spawn(function()
		local body = function()
			local brick = drawBrick()
			local windows = drawWindows()
			local shingles = drawShingles()
			if not brick then
				return -- EditableImage unavailable: flat-color fallback stands
			end
			local brickContent = (Content :: any).fromObject(brick)
			local windowContent = windows and (Content :: any).fromObject(windows) or nil
			local shingleContent = shingles and (Content :: any).fromObject(shingles) or nil

			for _, part in CollectionService:GetTagged("TexBrick") do
				if part:IsA("BasePart") then
					applyTexture(part, brickContent, ALL_FACES, 10, 10)
				end
			end
			if windowContent then
				for _, part in CollectionService:GetTagged("TexWindow") do
					if part:IsA("BasePart") then
						part.Transparency = 0
						applyTexture(part, windowContent, { Enum.NormalId.Front, Enum.NormalId.Back }, 9, 4.2)
					end
				end
			end
			if shingleContent then
				for _, part in CollectionService:GetTagged("TexRoof") do
					if part:IsA("BasePart") then
						applyTexture(part, shingleContent, { Enum.NormalId.Top }, 8, 8)
					end
				end
			end
			local tile = drawFloorTile()
			if tile then
				local tileContent = (Content :: any).fromObject(tile)
				for _, part in CollectionService:GetTagged("TexFloorTile") do
					if part:IsA("BasePart") then
						applyTexture(part, tileContent, { Enum.NormalId.Top }, 12, 12)
					end
				end
			end
			local carpet = drawCarpet()
			if carpet then
				local carpetContent = (Content :: any).fromObject(carpet)
				for _, part in CollectionService:GetTagged("TexCarpet") do
					if part:IsA("BasePart") then
						applyTexture(part, carpetContent, { Enum.NormalId.Top }, 16, 16)
					end
				end
			end
		end
		local ok, err = pcall(body :: any)
		if not ok then
			warn("[SurfaceArt] skipped: " .. tostring(err))
		end
	end)
end

return SurfaceArtController
