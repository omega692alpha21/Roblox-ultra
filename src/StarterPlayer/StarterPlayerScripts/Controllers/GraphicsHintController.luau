--!strict
-- One-time nudge: the game is lit for max graphics; players on Auto/low
-- quality never see it. Detect and tell them how to turn it up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local UIBuilder = require(script.Parent.UIBuilder)

local GraphicsHintController = {}

function GraphicsHintController.Init(gui: ScreenGui)
	task.delay(14, function()
		local ok, low = pcall(function()
			local settings = UserSettings():GetService("UserGameSettings")
			local quality = settings.SavedQualityLevel
			return quality == Enum.SavedQualitySetting.Automatic
				or (quality.Value ~= 0 and quality.Value <= 6)
		end)
		if not ok or not low then
			return
		end
		local card = UIBuilder.Frame({
			Name = "GraphicsHint",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 76),
			Size = UDim2.fromOffset(430, 64),
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.06,
			Parent = gui,
		})
		UIBuilder.Round(card, 12)
		UIBuilder.Stroke(card, Palette.BusYellow, 3)
		UIBuilder.Label({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 1, -12),
			Text = "🎨 This game looks WAY better on max graphics:\n☰ menu → Settings → Graphics Mode: Manual → slider to max",
			TextColor3 = Palette.Chalk,
			TextScaled = false,
			TextSize = 15,
			TextWrapped = true,
			Parent = card,
		})
		task.delay(12, function()
			if card.Parent then
				card:Destroy()
			end
		end)
	end)
end

return GraphicsHintController
