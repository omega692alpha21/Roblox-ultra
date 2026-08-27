--!strict
-- First join: who you are, then what you are.
--
-- Two steps, shown once and then never again. The first picks the body -- the
-- server dresses the avatar from it. The second picks the role, which is the
-- one decision in the game that changes how you play: health, speed, wind,
-- how hard you hit, how well you throw and how much you get out of a lesson.
-- The numbers on the cards are read straight off Config/Cliques, so what the
-- screen promises is what the server applies.
--
-- It used to be a board in the courtyard you might never walk past. A role you
-- can miss entirely is not a role.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cliques = require(ReplicatedStorage.Config.Cliques)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local CharacterSelectController = {}

local player = Players.LocalPlayer

local BODIES = {
	{
		id = "boy",
		title = "MALE",
		line = "Navy crest sweater. Bandage.\nBackpack full of nothing.",
		accent = Color3.fromRGB(38, 50, 96),
		emoji = "🧑",
	},
	{
		id = "girl",
		title = "FEMALE",
		line = "Plaid skirt. Bubblegum.\nZero patience.",
		accent = Color3.fromRGB(120, 82, 168),
		emoji = "👧",
	},
}

-- The four bars on a role card, and where each one comes from. Every value is
-- normalised against the widest spread in the list, so the bars compare the
-- roles to each other rather than to an invented maximum.
type Bar = { label: string, read: (Cliques.CliqueDef) -> number }

local BARS: { Bar } = {
	{ label = "HEALTH", read = function(r) return r.maxHealth end },
	{ label = "SPEED", read = function(r) return 20 + r.walkSpeedBonus end },
	{ label = "DAMAGE", read = function(r) return r.damageMult end },
	{ label = "CLASS", read = function(r) return r.quizRewardMult end },
}

local function spread(read: (Cliques.CliqueDef) -> number): (number, number)
	local low, high = math.huge, -math.huge
	for _, role in Cliques.List do
		local value = read(role)
		low = math.min(low, value)
		high = math.max(high, value)
	end
	-- pad, so the weakest role still shows a sliver rather than an empty bar
	return low - (high - low) * 0.35, high
end

local function card(parent: Instance, x: number, width: number, accent: Color3): Frame
	local frame = UIBuilder.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, 0.54),
		Size = UDim2.fromScale(width, 0.62),
		BackgroundColor3 = Palette.PanelBg,
		ZIndex = 41,
		Parent = parent,
	})
	UIBuilder.Round(frame, 14)
	UIBuilder.Stroke(frame, accent, 3)
	return frame
end

local function heading(parent: Instance, text: string, sub: string)
	UIBuilder.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(0.7, 0.07),
		Text = text,
		TextColor3 = Color3.fromRGB(255, 196, 60),
		ZIndex = 42,
		Parent = parent,
	})
	UIBuilder.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.155),
		Size = UDim2.fromScale(0.7, 0.045),
		Text = sub,
		TextColor3 = Palette.Chalk,
		ZIndex = 42,
		Parent = parent,
	})
end

local function showRoles(overlay: Frame, onPick: (string) -> ())
	for _, child in overlay:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	heading(overlay, "AND WHAT ARE YOU?", "This one decides how you play. You can re-sort later, for a price.")

	local count = #Cliques.List
	local ranges = {}
	for i, bar in BARS do
		local low, high = spread(bar.read)
		ranges[i] = { low = low, high = high }
	end

	for index, role in Cliques.List do
		local x = (index - 0.5) / count
		local frame = card(overlay, x, 1 / count - 0.02, role.color)

		UIBuilder.Label({
			Position = UDim2.fromScale(0, 0.03),
			Size = UDim2.fromScale(1, 0.16),
			Text = role.icon,
			ZIndex = 42,
			Parent = frame,
		})
		UIBuilder.Label({
			Position = UDim2.fromScale(0.04, 0.2),
			Size = UDim2.fromScale(0.92, 0.09),
			Text = role.name:upper(),
			TextColor3 = role.color,
			ZIndex = 42,
			Parent = frame,
		})
		local blurb = UIBuilder.Label({
			Position = UDim2.fromScale(0.06, 0.3),
			Size = UDim2.fromScale(0.88, 0.13),
			Text = role.blurb,
			TextColor3 = Palette.Chalk,
			TextScaled = false,
			TextSize = 13,
			TextWrapped = true,
			ZIndex = 42,
			Parent = frame,
		})
		local _ = blurb

		for i, bar in BARS do
			local y = 0.46 + (i - 1) * 0.09
			UIBuilder.Label({
				Position = UDim2.fromScale(0.06, y),
				Size = UDim2.fromScale(0.4, 0.07),
				Text = bar.label,
				TextColor3 = Color3.fromRGB(150, 160, 176),
				TextScaled = false,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 42,
				Parent = frame,
			})
			local track = UIBuilder.Frame({
				Position = UDim2.fromScale(0.44, y + 0.018),
				Size = UDim2.fromScale(0.5, 0.035),
				BackgroundColor3 = Color3.fromRGB(18, 20, 26),
				ZIndex = 42,
				Parent = frame,
			})
			UIBuilder.Round(track, 999)
			local range = ranges[i]
			local fraction = (bar.read(role) - range.low) / math.max(0.0001, range.high - range.low)
			local fill = UIBuilder.Frame({
				Size = UDim2.fromScale(math.clamp(fraction, 0.06, 1), 1),
				BackgroundColor3 = role.color,
				ZIndex = 43,
				Parent = track,
			})
			UIBuilder.Round(fill, 999)
		end

		local pick = UIBuilder.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromScale(0.8, 0.11),
			Text = "PICK",
			BackgroundColor3 = role.color,
			ZIndex = 43,
		}, function()
			onPick(role.id)
		end)
		UIBuilder.Round(pick, 999)
		pick.Parent = frame
	end
end

local function show(gui: ScreenGui)
	local overlay = UIBuilder.Frame({
		Name = "CharacterSelect",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 16, 26),
		BackgroundTransparency = 0.12,
		ZIndex = 40,
		Parent = gui,
	})
	heading(overlay, "WHO ARE YOU?", "Crumbworth High. First day. Try to keep up.")

	for index, body in BODIES do
		local frame = card(overlay, 0.5 + (index - 1.5) * 0.26, 0.2, body.accent)
		UIBuilder.Label({
			Position = UDim2.fromScale(0, 0.06),
			Size = UDim2.fromScale(1, 0.28),
			Text = body.emoji,
			ZIndex = 42,
			Parent = frame,
		})
		UIBuilder.Label({
			Position = UDim2.fromScale(0.04, 0.38),
			Size = UDim2.fromScale(0.92, 0.12),
			Text = body.title,
			TextColor3 = Color3.fromRGB(255, 196, 60),
			ZIndex = 42,
			Parent = frame,
		})
		UIBuilder.Label({
			Position = UDim2.fromScale(0.08, 0.52),
			Size = UDim2.fromScale(0.84, 0.2),
			Text = body.line,
			TextColor3 = Palette.Chalk,
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			ZIndex = 42,
			Parent = frame,
		})
		local pick = UIBuilder.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.fromScale(0.76, 0.14),
			Text = "THAT'S ME",
			BackgroundColor3 = body.accent,
			ZIndex = 43,
		}, function()
			Remotes.Get("ChooseCharacter"):FireServer(body.id)
			showRoles(overlay, function(roleId)
				Remotes.Get("JoinClique"):FireServer(roleId)
				overlay:Destroy()
			end)
		end)
		UIBuilder.Round(pick, 999)
		pick.Parent = frame
	end
end

function CharacterSelectController.Init(gui: ScreenGui)
	task.spawn(function()
		-- wait for the profile, then only prompt players who never picked
		for _ = 1, 360 do
			if player:GetAttribute("DataLoaded") == true then
				break
			end
			task.wait(0.5)
		end
		task.wait(1)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if player:GetAttribute("Outfit") == nil or player:GetAttribute("Clique") == nil then
			show(gui)
		end
	end)
end

return CharacterSelectController
