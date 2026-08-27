--!strict
-- First day: the hint under the goal bar, and a marker in the world on the
-- thing you are supposed to walk to.
--
-- The goal bar already says what the step is. What a new player is actually
-- missing is *where*, so this puts a floating beacon on the target with a live
-- distance. Both are built locally off replicated attributes — the beacon is
-- client-side only, so it costs the server nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local OnboardingController = {}

local player = Players.LocalPlayer

function OnboardingController.Init(gui: ScreenGui)
	-- ---- the hint, directly under the goal bar ----
	local card = UIBuilder.Frame({
		Name = "TutorialHint",
		Position = UDim2.fromOffset(Layout.StatusX, Layout.Margin + Layout.px(126)),
		Size = UDim2.fromOffset(Layout.px(280), Layout.px(46)),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.35,
		Visible = false,
		Parent = gui,
	})
	UIBuilder.Round(card, Layout.px(9))
	UIBuilder.Stroke(card, Palette.CashGreen, 2)
	local hint = UIBuilder.Label({
		Position = UDim2.fromOffset(Layout.px(10), Layout.px(5)),
		Size = UDim2.new(1, -Layout.px(20), 1, -Layout.px(10)),
		Text = "",
		TextScaled = false,
		TextSize = Layout.px(14),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Palette.Chalk,
		Parent = card,
	})

	-- ---- the beacon, local to this client ----
	local beacon = Instance.new("Part")
	beacon.Name = "TutorialBeacon"
	beacon.Size = Vector3.new(3, 3, 3)
	beacon.Transparency = 1
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BeaconTag"
	billboard.Size = UDim2.fromOffset(150, 62)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 500
	billboard.Parent = beacon

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(1, 0, 0, 34)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.FredokaOne
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.TextColor3 = Palette.CashGreen
	arrow.TextStrokeTransparency = 0.3
	arrow.Parent = billboard

	local distance = Instance.new("TextLabel")
	distance.Position = UDim2.fromOffset(0, 34)
	distance.Size = UDim2.new(1, 0, 0, 24)
	distance.BackgroundTransparency = 1
	distance.Font = Enum.Font.FredokaOne
	distance.TextScaled = true
	distance.TextColor3 = Color3.fromRGB(255, 250, 235)
	distance.TextStrokeTransparency = 0.4
	distance.Text = ""
	distance.Parent = billboard

	local function refreshHint()
		local text = player:GetAttribute("TutorialHint")
		if typeof(text) == "string" and text ~= "" then
			card.Visible = true
			hint.Text = text
		else
			card.Visible = false
		end
	end
	player:GetAttributeChangedSignal("TutorialHint"):Connect(refreshHint)
	refreshHint()

	local bob = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local target = player:GetAttribute("TutorialTarget")
		if typeof(target) ~= "Vector3" then
			billboard.Enabled = false
			return
		end
		billboard.Enabled = true
		bob += dt * 3
		beacon.Position = target + Vector3.new(0, 4 + math.sin(bob) * 0.6, 0)

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		distance.Text = if root then ("%d studs"):format(math.floor((root.Position - target).Magnitude)) else ""
	end)
end

return OnboardingController
