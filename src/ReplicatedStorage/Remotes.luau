--!strict
-- Remote registry. The server calls Remotes.Init() once to create everything;
-- clients call Remotes.Get()/GetFunction() and yield until they exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	-- server -> client
	"Notify", -- (message: string, kind: "info"|"good"|"bad"|"aura")
	"StealAlert", -- (thiefName: string, studentName: string)
	"ClassStart", -- (session: {subject, name, icon, professor, mode, rounds, seconds})
	"ClassResult", -- (correct, total, cash, aura, letter: string, level: number)
	"RewardState", -- (state table for the Rewards panel)
	"QuestState", -- (quests table)
	"SpinResult", -- (prizeIndex: number, label: string)
	"LeaderboardUpdate", -- (kind: "cash"|"aura", rows: {{name, value}})
	"OfflineEarnings", -- (amount: number, awaySeconds: number)
	"CrewState", -- (crew: {{uid, id, mut, star}})
	"Dialogue", -- (speaker: string, lines: {string})
	"ScreenFx", -- (kind: "shake" | "hurt", intensity: number)
	"HitMarker", -- (position: Vector3, amount: number, knockout: boolean)
	"PlayAction", -- (character: Model, kind: "punch"|"throw"|"hurt"|"knockout"|"flex")
	"StoryState", -- (state table for the Story panel)
	"CrewInvite", -- (invite: {name, userId, clique, color, friend, seconds})
	"SquadState", -- (rows: {{name, userId, clique, color}})
	"SecretKeypad", -- server -> client: open the bookshelf keypad
	-- client -> server
	"FuseStudent", -- (defId: string)
	"DoRebirth",
	"ClaimPlaytime", -- (index: number)
	"SpinWheel",
	"ClaimQuest", -- (index: number)
	"ClaimSocial", -- (kind: "group")
	"JoinClique", -- (cliqueId: string)
	"ClassAnswer", -- (roundIndex: number, answer: number | {number})
	"SetClassLevel", -- (level: number) 1 remedial / 2 standard / 3 honors
	"Punch",
	"Emote", -- (id: string) client -> server, broadcast to everyone
	"Block", -- (down: boolean) client -> server, guard up or down
	"Sprint", -- (on: boolean)
	"ClientDiagnostic", -- (failures: {string}) UI self-check report
	"ChooseCharacter", -- (outfit: "boy" | "girl")
	"JailState", -- server -> client (secondsLeft: number, canSkip: boolean)
	"RequestJailSkip", -- client -> server: use the pass, or get the purchase prompt
	"UseToy", -- client -> server (toyId: string, direction: Vector3)
	"SecretPin", -- client -> server (code: string)
	"CrewInviteAnswer", -- client -> server (accept: boolean)
	"LeaveCrew", -- client -> server
}

local FUNCTIONS = {
	"GetRewardState", -- () -> state table
	"GetCrew", -- () -> crew list
	"GetStory", -- () -> pushes StoryState
}

local Remotes = {}

function Remotes.Init()
	assert(RunService:IsServer(), "Remotes.Init is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
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
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.GetFunction(name: string): RemoteFunction
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
