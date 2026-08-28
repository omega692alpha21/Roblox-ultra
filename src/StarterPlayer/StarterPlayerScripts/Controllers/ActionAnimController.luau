--!strict
-- Plays the action poses the server dispatches, on this machine.
--
-- Every client runs this for every character, so a punch is animated on the
-- puncher's screen the instant they press the button and on everyone else's as
-- soon as the remote lands -- rather than being tweened once on the server and
-- replicated a joint at a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionPoses = require(ReplicatedStorage.Shared.ActionPoses)
local Remotes = require(ReplicatedStorage.Remotes)

local ActionAnimController = {}

function ActionAnimController.Init(_gui: ScreenGui)
	Remotes.Get("PlayAction").OnClientEvent:Connect(function(character, kind)
		if typeof(character) ~= "Instance" or not character:IsA("Model") then
			return
		end
		if typeof(kind) ~= "string" then
			return
		end
		-- our own punch already played locally the instant the button went
		-- down; replaying the echo would restart it a fifth of a second in
		if kind == "punch" and character == Players.LocalPlayer.Character then
			return
		end
		ActionPoses.Play(character, kind)
	end)
end

return ActionAnimController
