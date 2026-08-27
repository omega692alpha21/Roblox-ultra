--!strict
-- UI self-check badge. Deliberately built with raw Instance.new (NOT UIBuilder)
-- so a broken UIBuilder can never take this down too. Shows a small dot
-- bottom-left: green = every controller initialized and every panel
-- registered; red = tap to expand a copyable failure list a phone tester
-- can screenshot and send back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Diagnostics = {}

local EXPECTED_PANELS = { "Rep", "Crew", "Store", "Rebirth", "Rewards", "Quests", "Cliques", "Top" }

type Result = { name: string, ok: boolean, err: string? }

function Diagnostics.Report(playerGui: Instance, results: { Result })
	local failures: { string } = {}
	for _, result in results do
		if not result.ok then
			table.insert(failures, result.name .. ": FAILED (" .. tostring(result.err) .. ")")
		end
	end

	-- panel-registration check catches silent no-ops, not just throws
	local okHas, UIBuilder = pcall(function()
		return require(script.Parent:FindFirstChild("UIBuilder") :: ModuleScript) :: any
	end)
	if okHas and typeof(UIBuilder.HasPanel) == "function" then
		for _, name in EXPECTED_PANELS do
			local okCheck, has = pcall(UIBuilder.HasPanel, name)
			if okCheck and not has then
				table.insert(failures, "panel '" .. name .. "': never registered")
			end
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LMLDiagnostics"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 900
	gui.Parent = playerGui

	local healthy = #failures == 0

	local badge = Instance.new("TextButton")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0, 1)
	badge.Position = UDim2.new(0, 10, 1, -10)
	badge.Size = UDim2.fromOffset(healthy and 64 or 120, 26)
	badge.BackgroundColor3 = healthy and Color3.fromRGB(46, 140, 70) or Color3.fromRGB(190, 46, 46)
	badge.Font = Enum.Font.SourceSansBold
	badge.TextSize = 14
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Text = healthy and "UI OK" or (#failures .. " UI FAILED — tap")
	badge.BorderSizePixel = 0
	badge.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badge

	-- report failures to the server so they land in a DataStore the dev can read
	if not healthy then
		task.spawn(function()
			local folder = ReplicatedStorage:WaitForChild("Remotes", 10)
			local remote = folder and folder:FindFirstChild("ClientDiagnostic")
			if remote and remote:IsA("RemoteEvent") then
				remote:FireServer(failures)
			end
		end)
	end

	-- live status line: build number, save state, error count — one glance/screenshot
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	task.spawn(function()
		while badge.Parent do
			local dataLoaded = localPlayer:GetAttribute("DataLoaded")
			local outfit = localPlayer:GetAttribute("Outfit")
			badge.Size = UDim2.fromOffset(190, 26)
			badge.Text = ("b%d · %s · %s%s"):format(
				game.PlaceVersion,
				dataLoaded == true and "save✓" or "save…",
				outfit ~= nil and "char✓" or "char–",
				#failures > 0 and (" · %d ERR"):format(#failures) or ""
			)
			badge.BackgroundColor3 = (#failures > 0 or dataLoaded ~= true)
				and Color3.fromRGB(190, 46, 46)
				or Color3.fromRGB(46, 140, 70)
			task.wait(3)
		end
	end)

	if healthy then
		return
	end

	local detail = Instance.new("TextBox") -- TextBox: phone testers can long-press to copy
	detail.Name = "Detail"
	detail.AnchorPoint = Vector2.new(0, 1)
	detail.Position = UDim2.new(0, 10, 1, -44)
	detail.Size = UDim2.new(0, 340, 0, math.min(30 + #failures * 34, 260))
	detail.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
	detail.BackgroundTransparency = 0.05
	detail.Font = Enum.Font.Code
	detail.TextSize = 13
	detail.TextColor3 = Color3.fromRGB(255, 190, 190)
	detail.TextWrapped = true
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.ClearTextOnFocus = false
	detail.TextEditable = false
	detail.MultiLine = true
	detail.Text = table.concat(failures, "\n")
	detail.Visible = false
	detail.Parent = gui
	local detailCorner = Instance.new("UICorner")
	detailCorner.CornerRadius = UDim.new(0, 8)
	detailCorner.Parent = detail

	badge.Activated:Connect(function()
		detail.Visible = not detail.Visible
	end)
end

return Diagnostics
