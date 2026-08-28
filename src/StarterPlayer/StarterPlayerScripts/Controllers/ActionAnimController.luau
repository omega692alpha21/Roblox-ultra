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

-- Kinds the local player plays for themselves the moment they press the
-- button, so the echo off the server has to be ignored for them.
local LOCAL_ALREADY: { [string]: boolean } = {
	punch = true,
	cross = true,
	kick = true,
	block = true,
}

function ActionAnimController.Init(_gui: ScreenGui)
	Remotes.Get("PlayAction").OnClientEvent:Connect(function(character, kind, release)
		if typeof(character) ~= "Instance" or not character:IsA("Model") then
			return
		end
		if typeof(kind) ~= "string" then
			return
		end
		-- a held pose being let go rather than started
		if release == true then
			ActionPoses.Stop(character, kind)
			return
		end
		-- our own punch already played locally the instant the button went
		-- down; replaying the echo would restart it a fifth of a second in
		-- our own swing and our own guard already played locally the instant
		-- the button moved; replaying the echo would restart them
		if character == Players.LocalPlayer.Character and LOCAL_ALREADY[kind] then
			return
		end
		ActionPoses.Play(character, kind)
	end)
end

return ActionAnimController
