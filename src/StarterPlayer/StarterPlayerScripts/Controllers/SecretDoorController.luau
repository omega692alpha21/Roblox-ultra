--!strict
-- The keypad behind the bookshelf. Four digits, checked on the server.
--
-- Nothing here knows the code. The panel collects characters and sends them;
-- a wrong code gets the same silence a wrong code should get. It only ever
-- opens for the principal, because the server only ever tells the principal
-- to open it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local SecretDoorController = {}

local KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK" }
local LENGTH = 4

local function show(gui: ScreenGui)
	local existing = gui:FindFirstChild("SecretKeypad")
	if existing then
		existing:Destroy()
	end

	local overlay = UIBuilder.Frame({
		Name = "SecretKeypad",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 8, 12),
		BackgroundTransparency = 0.35,
		ZIndex = 60,
		Parent = gui,
	})

	local panel = UIBuilder.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.26, 0.62),
		BackgroundColor3 = Color3.fromRGB(24, 22, 20),
		ZIndex = 61,
		Parent = overlay,
	})
	UIBuilder.Round(panel, 14)
	UIBuilder.Stroke(panel, Color3.fromRGB(198, 166, 92), 3)

	UIBuilder.Label({
		Position = UDim2.fromScale(0.06, 0.03),
		Size = UDim2.fromScale(0.88, 0.08),
		Text = "PRINCIPAL ONLY",
		TextColor3 = Color3.fromRGB(198, 166, 92),
		ZIndex = 62,
		Parent = panel,
	})

	local readout = UIBuilder.Label({
		Position = UDim2.fromScale(0.08, 0.12),
		Size = UDim2.fromScale(0.84, 0.12),
		Text = "----",
		TextColor3 = Palette.Chalk,
		ZIndex = 62,
		Parent = panel,
	})

	local entered = ""
	local function redraw()
		readout.Text = string.rep("●", #entered) .. string.rep("-", LENGTH - #entered)
	end

	local grid = UIBuilder.Frame({
		Position = UDim2.fromScale(0.08, 0.27),
		Size = UDim2.fromScale(0.84, 0.6),
		BackgroundTransparency = 1,
		ZIndex = 62,
		Parent = panel,
	})
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromScale(0.3, 0.22)
	layout.CellPadding = UDim2.fromScale(0.05, 0.04)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for index, key in KEYS do
		local button = UIBuilder.Button({
			Text = key,
			BackgroundColor3 = if key == "OK" then Color3.fromRGB(72, 128, 84) else Color3.fromRGB(44, 42, 40),
			LayoutOrder = index,
			ZIndex = 63,
		}, function()
			if key == "⌫" then
				entered = entered:sub(1, math.max(0, #entered - 1))
			elseif key == "OK" then
				Remotes.Get("SecretPin"):FireServer(entered)
				overlay:Destroy()
				return
			elseif #entered < LENGTH then
				entered ..= key
			end
			redraw()
			if #entered == LENGTH then
				Remotes.Get("SecretPin"):FireServer(entered)
				overlay:Destroy()
			end
		end)
		UIBuilder.Round(button, 8)
		button.Parent = grid
	end
	redraw()

	local close = UIBuilder.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromScale(0.5, 0.08),
		Text = "CLOSE",
		BackgroundColor3 = Color3.fromRGB(60, 42, 42),
		ZIndex = 63,
	}, function()
		overlay:Destroy()
	end)
	UIBuilder.Round(close, 999)
	close.Parent = panel
end

function SecretDoorController.Init(gui: ScreenGui)
	Remotes.Get("SecretKeypad").OnClientEvent:Connect(function()
		show(gui)
	end)
end

return SecretDoorController
