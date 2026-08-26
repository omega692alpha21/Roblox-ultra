--!strict
-- Receives client UI self-check failures and stores them in a DataStore the
-- developer can read via the Open Cloud API — the only way client-side errors
-- reach a dev who has no Studio access.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)

local DiagnosticsService = {}

local reported: { [Player]: boolean } = {}

function DiagnosticsService.Init()
	Remotes.Get("ClientDiagnostic").OnServerEvent:Connect(function(player, failures)
		if reported[player] or typeof(failures) ~= "table" then
			return
		end
		reported[player] = true
		local lines: { string } = {}
		for _, failure in failures :: { any } do
			if typeof(failure) == "string" and #lines < 40 then
				table.insert(lines, failure:sub(1, 300))
			end
		end
		if #lines == 0 then
			return
		end
		warn("[Diagnostics] client UI failures from " .. player.Name .. ":\n" .. table.concat(lines, "\n"))
		task.spawn(function()
			pcall(function()
				local store = DataStoreService:GetDataStore("ClientDiagnostics")
				store:SetAsync(("u%d_t%d"):format(player.UserId, os.time()), {
					userId = player.UserId,
					name = player.Name,
					time = os.time(),
					failures = lines,
				})
			end)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		reported[player] = nil
	end)
end

return DiagnosticsService
