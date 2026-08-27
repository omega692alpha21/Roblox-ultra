--!strict
-- The vitals block: health, energy, experience and level, in one place at the
-- bottom of the screen.
--
-- Everything the player watches while they are moving belongs together and
-- belongs low: the eye rests at the bottom centre between the thumbstick and
-- the jump button, and glancing there should answer "am I in trouble" without
-- taking the camera off the world. Status that was scattered around the edges
-- is gathered here.
--
--   ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔        experience toward the next level
--   82/100 ███████████      HP
--     46/100 ██████         ENR
--   MENU      LEVEL 4       740/1000
--
-- Health is the Humanoid's, because that is where Roblox keeps it. Energy is
-- a player attribute VitalsService owns. Level comes off reputation: every
-- track counts, so the number goes up whatever kind of student you are.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local VitalsController = {}

local player = Players.LocalPlayer

local TRACKS = { "RepPopular", "RepSmart", "RepAthletic", "RepCreative", "RepTroublemaker" }
local PER_LEVEL = 40 -- points for level N = 40 * N^2, same curve the server uses

local HEALTH = Color3.fromRGB(74, 214, 96)
local ENERGY = Color3.fromRGB(84, 168, 255)
local EXPERIENCE = Color3.fromRGB(248, 182, 62)
local TRACK_BG = Color3.fromRGB(16, 18, 24)

-- A bar is two frames: a dark track and a fill whose width is the fraction.
-- The fill is eased toward its target so a hit reads as a drop rather than a
-- teleport, which is most of why a health bar feels like anything at all.
local function bar(parent: Instance, y: number, height: number, x: number, width: number, color: Color3)
	local track = UIBuilder.Frame({
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(width, height),
		BackgroundColor3 = TRACK_BG,
		BackgroundTransparency = 0.25,
		Parent = parent,
	})
	track.ZIndex = 26
	UIBuilder.Round(track, 999)
	UIBuilder.Stroke(track, Color3.fromRGB(0, 0, 0), 1)

	local fill = UIBuilder.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		Parent = track,
	})
	fill.ZIndex = 27
	UIBuilder.Round(fill, 999)

	local gloss = UIBuilder.Frame({
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.45),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.78,
		Parent = fill,
	})
	gloss.ZIndex = 28
	UIBuilder.Round(gloss, 999)

	return track, fill
end

local function caption(parent: Instance, x: number, y: number, width: number, height: number, align: Enum.TextXAlignment, color: Color3?)
	local label = UIBuilder.Label({
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(width, height),
		Text = "",
		TextColor3 = color or Color3.fromRGB(236, 240, 246),
		TextXAlignment = align,
		Parent = parent,
	})
	label.ZIndex = 30
	label.TextStrokeTransparency = 0.35
	Layout.FitText(label, 20)
	return label
end

function VitalsController.Init(gui: ScreenGui)
	local block = UIBuilder.Frame({
		Name = "Vitals",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(Layout.VitalsX, Layout.VitalsBottom),
		Size = UDim2.fromScale(Layout.VitalsW, Layout.VitalsH),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	block.ZIndex = 25

	local _, expFill = bar(block, 0.0, 0.13, 0.0, 1.0, EXPERIENCE)
	local _, healthFill = bar(block, 0.20, 0.28, 0.0, 0.88, HEALTH)
	local _, energyFill = bar(block, 0.52, 0.22, 0.14, 0.74, ENERGY)

	local healthText = caption(block, 0.02, 0.20, 0.4, 0.28, Enum.TextXAlignment.Left)
	local energyText = caption(block, 0.16, 0.52, 0.4, 0.22, Enum.TextXAlignment.Left)
	caption(block, 0.89, 0.20, 0.11, 0.28, Enum.TextXAlignment.Right, HEALTH).Text = "HP"
	caption(block, 0.89, 0.52, 0.11, 0.22, Enum.TextXAlignment.Right, ENERGY).Text = "ENR"

	local levelText = caption(block, 0.3, 0.78, 0.4, 0.22, Enum.TextXAlignment.Center, Palette.White)
	local expText = caption(block, 0.7, 0.78, 0.3, 0.22, Enum.TextXAlignment.Right, EXPERIENCE)

	-- MENU sits in the block's own bottom-left corner, the way the reference
	-- does it: one way in to everything, and nothing else taking up an edge.
	local menu = UIBuilder.Button({
		Name = "MenuChip",
		Position = UDim2.fromScale(0, 0.76),
		Size = UDim2.fromScale(0.22, 0.24),
		Text = "MENU",
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.2,
	}, function()
		UIBuilder.Toggle("Menu")
	end)
	menu.ZIndex = 30
	Layout.FitText(menu, 18)
	UIBuilder.Round(menu, 6)
	UIBuilder.Stroke(menu, Palette.White, 1)
	menu.Parent = block

	-- eased display values, so every bar moves rather than jumps
	local shownHealth, shownEnergy, shownExp = 1, 1, 0
	local textClock = 0

	RunService.RenderStepped:Connect(function(dt: number)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local health = humanoid and humanoid.Health or 0
		local healthMax = humanoid and humanoid.MaxHealth or 100
		if healthMax <= 0 then
			healthMax = 100
		end

		local rawMax = player:GetAttribute("EnergyMax")
		local energyMax: number = if typeof(rawMax) == "number" then rawMax else 100
		local rawEnergy = player:GetAttribute("Energy")
		local energy: number = if typeof(rawEnergy) == "number" then rawEnergy else energyMax

		local total = 0
		for _, attribute in TRACKS do
			local value = player:GetAttribute(attribute)
			if typeof(value) == "number" then
				total += value
			end
		end
		local level = math.floor(math.sqrt(math.max(total, 0) / PER_LEVEL))
		local floorPoints = PER_LEVEL * level * level
		local nextPoints = PER_LEVEL * (level + 1) * (level + 1)
		local into = total - floorPoints
		local span = math.max(1, nextPoints - floorPoints)

		local blend = math.min(dt * 9, 1)
		shownHealth += (health / healthMax - shownHealth) * blend
		shownEnergy += (energy / energyMax - shownEnergy) * blend
		shownExp += (into / span - shownExp) * blend

		healthFill.Size = UDim2.fromScale(math.clamp(shownHealth, 0, 1), 1)
		energyFill.Size = UDim2.fromScale(math.clamp(shownEnergy, 0, 1), 1)
		expFill.Size = UDim2.fromScale(math.clamp(shownExp, 0, 1), 1)

		-- low health goes amber then red: colour carries the warning before
		-- anyone has read the number
		local fraction = math.clamp(shownHealth, 0, 1)
		if fraction < 0.3 then
			healthFill.BackgroundColor3 = Color3.fromRGB(226, 68, 58)
		elseif fraction < 0.6 then
			healthFill.BackgroundColor3 = Color3.fromRGB(238, 172, 56)
		else
			healthFill.BackgroundColor3 = HEALTH
		end
		energyFill.BackgroundColor3 = if player:GetAttribute("Winded") == true
			then Color3.fromRGB(150, 158, 176)
			else ENERGY

		textClock += dt
		if textClock < 0.12 then
			return
		end
		textClock = 0
		healthText.Text = ("%d/%d"):format(math.floor(health + 0.5), math.floor(healthMax))
		energyText.Text = ("%d/%d"):format(math.floor(energy), math.floor(energyMax))
		levelText.Text = "LEVEL " .. level
		expText.Text = ("%s/%s"):format(NumberFormat.Abbreviate(into), NumberFormat.Abbreviate(span))
	end)
end

return VitalsController
