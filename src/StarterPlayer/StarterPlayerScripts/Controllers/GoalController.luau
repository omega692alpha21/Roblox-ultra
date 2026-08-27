--!strict
-- The next-goal bar: one line under the status strip that always says what
-- the game wants from you, with a progress bar under it.
--
-- The reward systems were all there and all invisible. This is the thread
-- that ties them together — it reads the attributes GoalService writes, so it
-- costs no remote traffic and updates itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local GoalController = {}

local player = Players.LocalPlayer

-- what kind of goal it is decides the accent, so "go do it now" reads
-- differently from "keep going"
local ACCENTS: { [string]: Color3 } = {
	class = Palette.DetentionRed,
	tutorial = Palette.CashGreen,
	collect = Palette.CashGreen,
	claim = Palette.BusYellow,
	graduate = Palette.LockerBlue,
	quest = Palette.AuraPurple,
	recruit = Palette.BusYellow,
	save = Palette.Chalk,
}

function GoalController.Init(gui: ScreenGui)
	local card = UIBuilder.Frame({
		Name = "GoalBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, Layout.MarginScale + Layout.PillHeight + 0.014, 0),
		Size = UDim2.new(0.32, 0, 0.05, 0),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.4,
		Visible = false,
		Parent = gui,
	})
	UIBuilder.Round(card, 999)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.BusYellow
	stroke.Thickness = 2
	stroke.Parent = card

	local label = UIBuilder.Label({
		Position = UDim2.fromScale(0.04, 0.06),
		Size = UDim2.new(0.92, 0, 0.58, 0),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	Layout.FitText(label, 0.028)

	local barBg = UIBuilder.Frame({
		Position = UDim2.fromScale(0.04, 0.7),
		Size = UDim2.new(0.92, 0, 0.16, 0),
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BackgroundTransparency = 0.3,
		Parent = card,
	})
	UIBuilder.Round(barBg, 999)
	local fill = UIBuilder.Frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Palette.BusYellow,
		Parent = barBg,
	})
	UIBuilder.Round(fill, 999)

	-- a goal that is ready to act on pulses; one that is still filling sits
	-- still, so the eye is only pulled when there is something to do
	local pulse = TweenService:Create(
		stroke,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Thickness = 3.5 }
	)
	local pulsing = false

	local function refresh()
		local text = player:GetAttribute("Goal")
		if typeof(text) ~= "string" or text == "" then
			card.Visible = false
			return
		end
		card.Visible = true
		label.Text = text

		local kind = player:GetAttribute("GoalKind")
		local accent = ACCENTS[typeof(kind) == "string" and kind or ""] or Palette.BusYellow
		stroke.Color = accent
		fill.BackgroundColor3 = accent
		label.TextColor3 = accent

		local progress = player:GetAttribute("GoalProgress")
		local ratio = math.clamp(typeof(progress) == "number" and progress or 0, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(ratio, 1) }):Play()

		local ready = ratio >= 1
		if ready and not pulsing then
			pulsing = true
			pulse:Play()
		elseif not ready and pulsing then
			pulsing = false
			pulse:Cancel()
			stroke.Thickness = 2
		end
	end

	player:GetAttributeChangedSignal("Goal"):Connect(refresh)
	player:GetAttributeChangedSignal("GoalProgress"):Connect(refresh)
	refresh()
end

return GoalController
