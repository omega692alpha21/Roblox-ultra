--!strict
-- Lunch Money Legends — client bootstrap: one ScreenGui, all controllers.
-- Every controller Init is isolated: one crashing controller can never take
-- down the rest of the UI. Failures surface on the Diagnostics badge.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "LunchMoneyLegends"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local Controllers = script.Parent:FindFirstChild("Controllers")
if not Controllers then
	-- without this folder every controller require fails and the whole HUD
	-- silently disappears, which is exactly what happened
	local warnGui = Instance.new("ScreenGui")
	warnGui.Name = "ClientFatal"
	warnGui.DisplayOrder = 998
	warnGui.ResetOnSpawn = false
	warnGui.Parent = playerGui
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 620, 0, 40)
	label.Position = UDim2.fromOffset(10, 150)
	label.BackgroundColor3 = Color3.fromRGB(150, 24, 24)
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "FATAL: Controllers folder missing"
	label.Parent = warnGui
	return
end

local ORDER = {
	"NotifyController",
	"HudController",
	"CrewController",
	"RepController",
	"StoreController",
	"RebirthController",
	"RewardsController",
	"QuestController",
	"QuizController",
	"CliqueController",
	"LeaderboardController",
	"PunchController",
	"ScreenFxController",
	"SprintController",
	"TutorialController",
	"CharacterSelectController",
	"GraphicsHintController",
	"DialogueController",
	"JailController",
	"ToyController",
	"MinimapController",
}

local results: { { name: string, ok: boolean, err: string? } } = {}
for _, name in ORDER do
	local ok, err = pcall(function()
		(require(Controllers:FindFirstChild(name) :: ModuleScript) :: any).Init(gui)
	end)
	table.insert(results, { name = name, ok = ok, err = if ok then nil else tostring(err) })
	if not ok then
		warn(("[LML] %s.Init FAILED: %s"):format(name, tostring(err)))
		-- put the error where a screenshot can read it: silent client
		-- failures are how the toy HUD went missing for a whole build
		task.spawn(function()
			local found = playerGui:FindFirstChild("ClientErrors")
			local errGui: ScreenGui
			if found and found:IsA("ScreenGui") then
				errGui = found
			else
				local made = Instance.new("ScreenGui")
				made.Name = "ClientErrors"
				made.ResetOnSpawn = false
				made.DisplayOrder = 90
				made.Parent = playerGui
				local list = Instance.new("UIListLayout")
				list.Padding = UDim.new(0, 4)
				list.Parent = made
				errGui = made
			end
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(0, 620, 0, 30)
			label.Position = UDim2.fromOffset(10, 200)
			label.BackgroundColor3 = Color3.fromRGB(150, 26, 26)
			label.Font = Enum.Font.Code
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = ("%s: %s"):format(name, tostring(err):sub(1, 90))
			label.Parent = errGui
		end)
	end
end

local okDiag, diagErr = pcall(function()
	(require(Controllers:FindFirstChild("Diagnostics") :: ModuleScript) :: any).Report(playerGui, results)
end)
if not okDiag then
	warn("[LML] Diagnostics.Report failed: " .. tostring(diagErr))
end

print("[LunchMoneyLegends] client ready")
