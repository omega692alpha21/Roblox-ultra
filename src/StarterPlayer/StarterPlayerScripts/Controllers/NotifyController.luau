--!strict
-- Toast notifications + steal alarms + offline earnings popup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local NotifyController = {}

local KIND_COLORS: { [string]: Color3 } = {
	info = Palette.LockerBlue,
	good = Palette.CashGreen,
	bad = Palette.DetentionRed,
	aura = Palette.AuraPurple,
}

function NotifyController.Init(gui: ScreenGui)
	local stack = UIBuilder.Frame({
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 70),
		Size = UDim2.fromOffset(320, 400),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = stack

	local function toast(message: string, kind: string?)
		local color = KIND_COLORS[kind or "info"] or Palette.LockerBlue
		local frame = UIBuilder.Frame({
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.05,
			Parent = stack,
		})
		UIBuilder.Round(frame, 10)
		UIBuilder.Stroke(frame, color, 2.5)
		UIBuilder.Label({
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 1, -8),
			Text = message,
			TextWrapped = true,
			TextSize = 16,
			TextScaled = false,
			Font = Enum.Font.FredokaOne,
			Parent = frame,
		})
		task.delay(4, function()
			local tween = TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			frame:Destroy()
		end)
	end

	Remotes.Get("Notify").OnClientEvent:Connect(function(message, kind)
		if typeof(message) == "string" then
			toast(message, typeof(kind) == "string" and kind or "info")
		end
	end)

	Remotes.Get("StealAlert").OnClientEvent:Connect(function(thiefName, studentName)
		toast(("🚨 %s is stealing your %s! PUNCH THEM!"):format(tostring(thiefName), tostring(studentName)), "bad")
	end)

	Remotes.Get("OfflineEarnings").OnClientEvent:Connect(function(amount, awaySeconds)
		local hours = math.floor((tonumber(awaySeconds) or 0) / 3600)
		local popup = UIBuilder.Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(360, 150),
			BackgroundColor3 = Palette.PanelBg,
			Parent = gui,
		})
		UIBuilder.Round(popup, 16)
		UIBuilder.Stroke(popup, Palette.CashGreen, 3)
		UIBuilder.Label({
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.new(1, -24, 0, 30),
			Text = "While you were in class...",
			TextColor3 = Palette.BusYellow,
			Parent = popup,
		})
		UIBuilder.Label({
			Position = UDim2.fromOffset(12, 48),
			Size = UDim2.new(1, -24, 0, 46),
			Text = "+$" .. NumberFormat.Abbreviate(tonumber(amount) or 0),
			TextColor3 = Palette.CashGreen,
			Parent = popup,
		})
		UIBuilder.Label({
			Position = UDim2.fromOffset(12, 96),
			Size = UDim2.new(1, -24, 0, 22),
			Text = ("your crew kept grinding for %dh"):format(math.max(1, hours)),
			TextColor3 = Palette.Chalk,
			Parent = popup,
		})
		task.delay(6, function()
			popup:Destroy()
		end)
	end)
end

return NotifyController
