--!strict
-- First-minute onboarding: a compact how-to card shown shortly after joining.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local UIBuilder = require(script.Parent.UIBuilder)

local TutorialController = {}

local STEPS = {
	{ n = "1", color = Palette.CashGreen, text = "RECRUIT students walking the MAIN HALLWAY — they earn lunch money every second" },
	{ n = "2", color = Palette.BusYellow, text = "COLLECT your pile on the green pad in YOUR homeroom" },
	{ n = "3", color = Palette.DetentionRed, text = "STEAL from unlocked homerooms... and LOCK yours before they rob you back" },
}

function TutorialController.Init(gui: ScreenGui)
	task.delay(2, function()
		-- centred with its own dim, so the welcome card reads as the one thing
		-- on screen instead of a fourth panel fighting the action bar
		local dim = UIBuilder.Frame({
			Name = "TutorialDim",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			ZIndex = 40,
			Parent = gui,
		})
		local card = UIBuilder.Frame({
			Name = "Tutorial",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(540, 190),
			ZIndex = 41,
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.05,
			Parent = gui,
		})
		UIBuilder.Round(card, 16)
		UIBuilder.Stroke(card, Palette.BusYellow, 3)
		UIBuilder.Label({
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -28, 0, 26),
			Text = "WELCOME TO CRUMBWORTH HIGH",
			TextColor3 = Palette.BusYellow,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		for i, step in STEPS do
			local badge = UIBuilder.Frame({
				Position = UDim2.fromOffset(14, 12 + i * 30),
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = step.color,
				Parent = card,
			})
			UIBuilder.Round(badge, 999)
			UIBuilder.Label({
				Size = UDim2.fromScale(1, 1),
				Text = step.n,
				TextColor3 = Palette.Blackboard,
				Parent = badge,
			})
			UIBuilder.Label({
				Position = UDim2.fromOffset(46, 12 + i * 30),
				Size = UDim2.new(1, -60, 0, 24),
				Text = step.text,
				TextScaled = false,
				TextSize = 15,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Palette.Chalk,
				Parent = card,
			})
		end
		local gotIt = UIBuilder.Button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -10),
			Size = UDim2.fromOffset(120, 34),
			Text = "GOT IT!",
			BackgroundColor3 = Palette.CashGreen,
		}, function()
			card:Destroy()
			dim:Destroy()
		end)
		UIBuilder.Round(gotIt, 10)
		gotIt.Parent = card
		-- auto-dismiss so it never nags
		task.delay(25, function()
			card:Destroy()
			dim:Destroy()
		end)
	end)
end

return TutorialController
