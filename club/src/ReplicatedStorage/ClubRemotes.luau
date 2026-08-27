--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER = "ClubRemotes"
local EVENTS = {
	"Notify", -- (message, kind)
	"SetProfile", -- client -> server (interests: {string}, lookingFor: {string})
	"RequestJoin", -- client -> server (tierName?: string) prompt a purchase
}
local FUNCTIONS = {
	"GetDirectory", -- () -> { { userId, name, interests, lookingFor } }
	"GetMyProfile", -- () -> profile
}

local Remotes = {}

function Remotes.Init()
	assert(RunService:IsServer(), "server only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER) or Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = ReplicatedStorage
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
	end
end

function Remotes.Get(name: string): RemoteEvent
	return ReplicatedStorage:WaitForChild(FOLDER):WaitForChild(name) :: RemoteEvent
end

function Remotes.GetFunction(name: string): RemoteFunction
	return ReplicatedStorage:WaitForChild(FOLDER):WaitForChild(name) :: RemoteFunction
end

return Remotes
