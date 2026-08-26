--!strict
-- Lunch Money Legends — client bootstrap: one ScreenGui, all controllers.

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

require(Controllers.NotifyController).Init(gui)
require(Controllers.HudController).Init(gui)
require(Controllers.CrewController).Init(gui)
require(Controllers.StoreController).Init(gui)
require(Controllers.RebirthController).Init(gui)
require(Controllers.RewardsController).Init(gui)
require(Controllers.QuestController).Init(gui)
require(Controllers.QuizController).Init(gui)
require(Controllers.CliqueController).Init(gui)
require(Controllers.LeaderboardController).Init(gui)
require(Controllers.PunchController).Init(gui)
require(Controllers.TutorialController).Init(gui)

print("[LunchMoneyLegends] client ready")
