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

local Controllers = script.Parent.Controllers

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
	"SurfaceArtController",
	"SprintController",
	"TutorialController",
	"DialogueController",
}

local results: { { name: string, ok: boolean, err: string? } } = {}
for _, name in ORDER do
	local ok, err = pcall(function()
		(require(Controllers:FindFirstChild(name) :: ModuleScript) :: any).Init(gui)
	end)
	table.insert(results, { name = name, ok = ok, err = if ok then nil else tostring(err) })
	if not ok then
		warn(("[LML] %s.Init FAILED: %s"):format(name, tostring(err)))
	end
end

local okDiag, diagErr = pcall(function()
	(require(Controllers:FindFirstChild("Diagnostics") :: ModuleScript) :: any).Report(playerGui, results)
end)
if not okDiag then
	warn("[LML] Diagnostics.Report failed: " .. tostring(diagErr))
end

print("[LunchMoneyLegends] client ready")
