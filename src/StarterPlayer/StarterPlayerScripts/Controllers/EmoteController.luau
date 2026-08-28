--!strict
-- The emote wheel, and the guard button beside it.
--
-- A wheel rather than a row: eight slots around a circle is one thumb sweep,
-- and every slot is the same distance from where the thumb already is. A row
-- of eight on a phone is four you can reach and four you cannot.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ActionPoses = require(ReplicatedStorage.Shared.ActionPoses)
local Emotes = require(ReplicatedStorage.Config.Emotes)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local player = Players.LocalPlayer

local EmoteController = {}

local wheel: Frame
local open = false

local function setOpen(state: boolean)
	if open == state then
		return
	end
	open = state
	wheel.Visible = true
	local scale = wheel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = wheel
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = if state then 1 else 0.01,
	}):Play()
	if not state then
		task.delay(0.18, function()
			if not open then
				wheel.Visible = false
			end
		end)
	end
end

local function fire(id: string)
	setOpen(false)
	-- play it here immediately; the server broadcasts it to everyone else
	local character = player.Character
	if character then
		ActionPoses.Play(character, id)
	end
	Remotes.Get("Emote"):FireServer(id)
end

function EmoteController.Init(gui: ScreenGui)
	-- ---------------- the wheel ----------------
	wheel = UIBuilder.Frame({
		Name = "EmoteWheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.44, 0.44),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 40,
		Parent = gui,
	})
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = wheel

	local hub = UIBuilder.Frame({
		Name = "Hub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.15,
		ZIndex = 40,
		Parent = wheel,
	})
	UIBuilder.Round(hub, 999)
	UIBuilder.Stroke(hub, Palette.BusYellow, 3)
	UIBuilder.Label({
		Size = UDim2.fromScale(0.8, 0.5),
		Position = UDim2.fromScale(0.1, 0.25),
		Text = "EMOTE",
		TextColor3 = Palette.BusYellow,
		ZIndex = 41,
		Parent = hub,
	})

	for index, emote in Emotes.List do
		local angle = (index - 1) / #Emotes.List * math.pi * 2 - math.pi / 2
		local slot = UIBuilder.Button({
			Name = "Emote_" .. emote.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.36, 0.5 + math.sin(angle) * 0.36),
			Size = UDim2.fromScale(0.24, 0.24),
			Text = emote.icon,
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.1,
			ZIndex = 41,
		}, function()
			fire(emote.id)
		end)
		UIBuilder.Round(slot, 999)
		UIBuilder.Stroke(slot, Palette.Chalk, 2)
		slot.Parent = wheel
		local ring = Instance.new("UIAspectRatioConstraint")
		ring.AspectRatio = 1
		ring.Parent = slot
		local caption = UIBuilder.Label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 1.02),
			Size = UDim2.fromScale(1.6, 0.26),
			Text = emote.label,
			TextColor3 = Palette.Chalk,
			ZIndex = 41,
			Parent = slot,
		})
		caption.TextScaled = true
	end

	-- tapping the middle closes it
	local close = UIBuilder.Button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		Text = "",
		BackgroundTransparency = 1,
		ZIndex = 42,
	}, function()
		setOpen(false)
	end)
	close.Parent = wheel

	ContextActionService:BindAction("EmoteWheel", function(_, state)
		if state == Enum.UserInputState.Begin then
			setOpen(not open)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B)

	-- ---------------- the buttons ----------------
	if UserInputService.TouchEnabled then
		local button = UIBuilder.Button({
			Name = "EmoteButton",
			Text = "😀",
			BackgroundColor3 = Palette.AuraPurple,
			BackgroundTransparency = 0.15,
			LayoutOrder = Layout.Order.Emote,
		}, function()
			setOpen(not open)
		end)
		Layout.FitText(button, 34)
		UIBuilder.Round(button, 999)
		UIBuilder.Stroke(button, Palette.White, 3)
		Layout.ActionSlot(button, "Emote", gui)
	end
end

return EmoteController
