--!strict
-- Small UI toolkit: styled frames/labels/buttons + a one-at-a-time panel manager.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Sounds = require(ReplicatedStorage.Config.Sounds)

local UIBuilder = {}

local clickSound: Sound? = nil
local function playClick()
	if not clickSound then
		local sound = Instance.new("Sound")
		sound.SoundId = Sounds.UIClick.id
		sound.Volume = Sounds.UIClick.volume
		sound.PlaybackSpeed = Sounds.UIClick.speed
		sound.Parent = SoundService
		clickSound = sound
	end
	local s = clickSound
	if s then
		s:Play()
	end
end

local panels: { [string]: Frame } = {}

function UIBuilder.Round(instance: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
end

-- Subtle vertical sheen so surfaces read as lit, not flat.
function UIBuilder.Sheen(instance: Instance)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 205, 194)),
	})
	gradient.Parent = instance
end

function UIBuilder.Stroke(instance: Instance, color: Color3, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2.5
	stroke.Parent = instance
end

function UIBuilder.Frame(props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Palette.PanelBg
	for k, v in props do
		(frame :: any)[k] = v
	end
	return frame
end

function UIBuilder.Label(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Palette.White
	label.TextScaled = true
	label.BorderSizePixel = 0
	for k, v in props do
		(label :: any)[k] = v
	end
	return label
end

function UIBuilder.Button(props: { [string]: any }, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Font = Enum.Font.FredokaOne
	button.TextColor3 = Palette.White
	button.TextScaled = true
	button.BorderSizePixel = 0
	button.BackgroundColor3 = Palette.CashGreen
	button.AutoButtonColor = true
	for k, v in props do
		(button :: any)[k] = v
	end
	button.Activated:Connect(function()
		playClick()
		-- quick press pop
		local originalSize = button.Size
		local shrink = TweenService:Create(button, TweenInfo.new(0.06), {
			Size = UDim2.new(originalSize.X.Scale * 0.94, math.floor(originalSize.X.Offset * 0.94), originalSize.Y.Scale * 0.94, math.floor(originalSize.Y.Offset * 0.94)),
		})
		shrink:Play()
		shrink.Completed:Once(function()
			TweenService:Create(button, TweenInfo.new(0.1), { Size = originalSize }):Play()
		end)
		onClick()
	end)
	return button
end

-- A centered window with title bar + close button, hidden by default.
function UIBuilder.Panel(parent: Instance, name: string, title: string): (Frame, Frame)
	local panel = UIBuilder.Frame({
		Name = name .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 420),
		BackgroundColor3 = Palette.PanelBg,
		Visible = false,
		Parent = parent,
	})
	UIBuilder.Round(panel, 16)
	UIBuilder.Stroke(panel, Palette.CashGreen, 3)
	UIBuilder.Sheen(panel)

	UIBuilder.Label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -100, 0, 36),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.BusYellow,
		Parent = panel,
	})

	local close = UIBuilder.Button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(36, 36),
		Text = "X",
		BackgroundColor3 = Palette.DetentionRed,
	}, function()
		UIBuilder.CloseAll()
	end)
	close.Parent = panel
	UIBuilder.Round(close, 10)

	local content = UIBuilder.Frame({
		Name = "Content",
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 1, -64),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	panels[name] = panel
	return panel, content
end

function UIBuilder.HasPanel(name: string): boolean
	return (panels :: { [string]: Frame? })[name] ~= nil
end

function UIBuilder.CloseAll()
	for _, panel in panels do
		panel.Visible = false
	end
end

function UIBuilder.Toggle(name: string)
	local target = panels[name]
	if not target then
		return
	end
	local wasVisible = target.Visible
	UIBuilder.CloseAll()
	if not wasVisible then
		target.Visible = true
		-- pop-in
		local scale = target:FindFirstChildOfClass("UIScale")
		if not scale then
			local s = Instance.new("UIScale")
			s.Parent = target
			scale = s
		end
		local uiScale = scale :: UIScale
		uiScale.Scale = 0.85
		TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

-- Vertical scrolling list container.
function UIBuilder.List(parent: Instance): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	return scroll
end

return UIBuilder
