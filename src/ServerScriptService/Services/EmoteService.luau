--!strict
-- Emotes: the client asks, the server tells everyone.
--
-- Broadcast rather than played locally, because the whole point of an emote is
-- that somebody else sees it. Rate limited per player: an emote is free, so
-- without a limit the wheel is a way to fill everyone's network with poses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Emotes = require(ReplicatedStorage.Config.Emotes)
local Remotes = require(ReplicatedStorage.Remotes)
local ActionAnim = require(script.Parent.ActionAnim)
local VitalsService = require(script.Parent.VitalsService)

local EmoteService = {}

local COOLDOWN = 0.9
local lastEmote: { [Player]: number } = {}

function EmoteService.Init()
	Remotes.Get("Emote").OnServerEvent:Connect(function(player, id)
		if typeof(id) ~= "string" or not Emotes.Get(id) then
			return
		end
		local now = os.clock()
		if now - (lastEmote[player] or 0) < COOLDOWN then
			return
		end
		lastEmote[player] = now
		-- not while you are on the floor at the nurse's
		if VitalsService.IsKnockedOut(player) then
			return
		end
		local character = player.Character
		if character then
			ActionAnim.Play(character, id)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastEmote[player] = nil
	end)
end

return EmoteService
