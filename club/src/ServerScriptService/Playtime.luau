--!strict
-- Time served. Live play counts in full; time away counts half — being here
-- matters more than existing. Rank requires both REP and hours, so nobody
-- speedruns their way into the pyramid in an afternoon.

local Players = game:GetService("Players")

local Playtime = {}

-- effective seconds per player, credited into the Rep record
type Ledger = { live: number, offline: number, lastSeen: number? }

local session: { [number]: number } = {} -- os.clock() of last accrual tick

local getRecord: ((Player) -> any)? = nil
local markDirty: ((Player) -> ())? = nil

function Playtime.EffectiveHours(record: any): number
	local live = tonumber(record.liveSeconds) or 0
	local offline = tonumber(record.offlineSeconds) or 0
	return (live + offline * 0.5) / 3600
end

-- called by Rep when a record loads: credit the time away at half rate
function Playtime.OnLoad(player: Player, record: any)
	local now = os.time()
	local last = tonumber(record.lastSeen)
	if last and now > last then
		local away = math.min(now - last, 30 * 86400) -- cap a month of afk credit
		record.offlineSeconds = (tonumber(record.offlineSeconds) or 0) + away
	end
	record.lastSeen = now
	session[player.UserId] = os.clock()
end

function Playtime.OnSave(player: Player, record: any)
	Playtime.Accrue(player, record)
	record.lastSeen = os.time()
end

function Playtime.Accrue(player: Player, record: any)
	local started = session[player.UserId]
	if not started then
		return
	end
	local now = os.clock()
	record.liveSeconds = (tonumber(record.liveSeconds) or 0) + (now - started)
	session[player.UserId] = now
end

function Playtime.Init(hooks: { get: (Player) -> any, dirty: (Player) -> () })
	getRecord = hooks.get
	markDirty = hooks.dirty
	Players.PlayerRemoving:Connect(function(player)
		session[player.UserId] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local record = getRecord and getRecord(player)
				if record then
					Playtime.Accrue(player, record)
					player:SetAttribute("Hours", math.floor(Playtime.EffectiveHours(record) * 10) / 10)
					if markDirty then
						markDirty(player)
					end
				end
			end
		end
	end)
end

return Playtime
