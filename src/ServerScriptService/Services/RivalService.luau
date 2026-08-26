--!strict
-- Rico the Bully: an NPC rival who raids homerooms. He walks to an unlocked,
-- occupied plot, grabs a student off their desk, and heads for the school gate.
-- Punch him to make him drop them (+aura). If he escapes, the student wanders
-- back on their own after a bit — Rico causes drama, never permanent loss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Students = require(ReplicatedStorage.Config.Students)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local LockService = require(script.Parent.LockService)
local StudentGen = require(script.Parent.StudentGen)
local EffectsService = require(script.Parent.EffectsService)
local Signals = require(script.Parent.Parent.Signals)

local RivalService = {}

local IDLE_SPOTS = {
	Vector3.new(120, 0, 8), Vector3.new(-120, 0, -8), Vector3.new(0, 0, 120),
	Vector3.new(180, 0, 60), Vector3.new(-60, 0, 130),
}
local EXIT = Vector3.new(0, 0, 214) -- the school gate

type State = "wander" | "approach" | "flee"

local model: Model? = nil
local position = Vector3.new(60, 0, 8)
local target = IDLE_SPOTS[1]
local state: State = "wander"
local idleUntil = 0
local nextRaidAt = 0
local victim: Player? = nil
local stolenUid: string? = nil
local stolenDefId: string? = nil
local carryVisual: Model? = nil
local rng = Random.new()

local function studentName(defId: string?): string
	local entry = defId and Students.Get(defId)
	return entry and entry.def.name or "student"
end

local function dropLoot(returnNow: boolean)
	if carryVisual then
		carryVisual:Destroy()
		carryVisual = nil
	end
	local v, uid = victim, stolenUid
	victim, stolenUid, stolenDefId = nil, nil, nil
	if v and uid and v.Parent then
		if returnNow then
			PlotService.SpawnPendingModel(v, uid)
		else
			local defId = nil
			task.delay(GameConfig.RivalEscapeReturnSeconds, function()
				if v.Parent then
					PlotService.SpawnPendingModel(v, uid)
					Remotes.Get("Notify"):FireClient(v, "Your student escaped Rico and wandered back!", "good")
				end
			end)
			local _ = defId
		end
	end
end

-- Called by FightService when a player's punch lands on Rico.
function RivalService.OnPunched(puncher: Player)
	if state ~= "flee" and state ~= "approach" then
		return
	end
	local name = studentName(stolenDefId)
	if stolenUid then
		Remotes.Get("Notify"):FireClient(puncher, "You decked RICO! " .. name .. " is safe. (+" .. GameConfig.RivalFoilAura .. " aura)", "aura")
		if victim and victim ~= puncher and victim.Parent then
			Remotes.Get("Notify"):FireClient(victim, puncher.DisplayName .. " saved your " .. name .. " from Rico!", "good")
		end
		Signals.RivalFoiled:Fire(puncher)
		dropLoot(true)
	end
	state = "wander"
	idleUntil = os.clock() + 6
	target = IDLE_SPOTS[rng:NextInteger(1, #IDLE_SPOTS)]
	nextRaidAt = os.clock() + rng:NextNumber(GameConfig.RivalRaidMinSeconds, GameConfig.RivalRaidMaxSeconds)
end

function RivalService.GetRoot(): BasePart?
	local m = model
	return m and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")) :: BasePart? or nil
end

local function pickVictim(): (Player?, string?, string?)
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		local plot = PlotService.GetPlot(player)
		if profile and plot and #profile.crew > 0 and not LockService.IsLocked(plot) then
			table.insert(candidates, player)
		end
	end
	if #candidates == 0 then
		return nil, nil, nil
	end
	local player = candidates[rng:NextInteger(1, #candidates)]
	local profile = DataService.Get(player)
	if not profile then
		return nil, nil, nil
	end
	local member = profile.crew[rng:NextInteger(1, #profile.crew)]
	return player, member.uid, member.id
end

local function beginRaid()
	local player, uid, defId = pickVictim()
	if not player or not uid then
		nextRaidAt = os.clock() + 30
		return
	end
	victim, stolenUid, stolenDefId = player, uid, defId
	state = "approach"
end

local function grabLoot()
	local v, uid, defId = victim, stolenUid, stolenDefId
	if not v or not uid or not v.Parent then
		state = "wander"
		return
	end
	-- if the desk model vanished (stolen by a player mid-approach), bail
	local deskModel = PlotService.GetStudentModel(v, uid)
	if not deskModel then
		victim, stolenUid, stolenDefId = nil, nil, nil
		state = "wander"
		nextRaidAt = os.clock() + 20
		return
	end
	local star = deskModel:GetAttribute("Star") == true
	local mutAttr = deskModel:GetAttribute("Mut")
	deskModel:Destroy()
	local models = nil -- desk model registry cleans itself on rebuild
	local _ = models
	if defId then
		carryVisual = StudentGen.Create(defId)
		if carryVisual then
			StudentGen.Decorate(carryVisual, defId, typeof(mutAttr) == "string" and mutAttr or nil, star)
			carryVisual.Parent = workspace
		end
	end
	state = "flee"
	Remotes.Get("StealAlert"):FireClient(v, "RICO THE BULLY", studentName(defId))
	Remotes.Get("Notify"):FireAllClients("RICO THE BULLY grabbed " .. v.DisplayName .. "'s " .. studentName(defId) .. " — PUNCH HIM!", "announce")
end

function RivalService.Init()
	local m = StudentGen.Create("detention_veteran", "_rico")
	if not m then
		return
	end
	model = m
	m.Name = "RicoTheBully"
	-- beef him up + red menace styling
	local head = m:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("NameTag")
	if tag then
		local nameLabel = tag:FindFirstChild("StudentName")
		local info = tag:FindFirstChild("Info")
		local rarityLabel = tag:FindFirstChild("Rarity")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = "RICO THE BULLY"
			nameLabel.TextColor3 = Palette.DetentionRed
		end
		if info and info:IsA("TextLabel") then
			info.Text = "hates your crew"
			info.TextColor3 = Palette.Chalk
		end
		if rarityLabel then
			rarityLabel:Destroy()
		end
	end
	local menace = Instance.new("Highlight")
	menace.FillTransparency = 1
	menace.OutlineColor = Palette.DetentionRed
	menace.OutlineTransparency = 0.25
	menace.Parent = m
	m.Parent = workspace
	StudentGen.Stand(m, CFrame.new(position))
	StudentGen.PlayAnim(m, "walk")

	nextRaidAt = os.clock() + 60 -- first raid a minute in

	RunService.Heartbeat:Connect(function(dt: number)
		local rig = model
		if not rig or not rig.Parent then
			return
		end
		local now = os.clock()

		-- pick destination by state
		if state == "wander" then
			if now >= nextRaidAt then
				beginRaid()
			elseif (target - position).Magnitude < 4 then
				if idleUntil == 0 then
					idleUntil = now + rng:NextNumber(2, 6)
				elseif now >= idleUntil then
					idleUntil = 0
					target = IDLE_SPOTS[rng:NextInteger(1, #IDLE_SPOTS)]
				end
				return
			end
		elseif state == "approach" then
			local v, uid = victim, stolenUid
			local slotCf = v and uid and v.Parent and PlotService.GetSlotWorldCFrame(v, uid) or nil
			local plot = v and PlotService.GetPlot(v) or nil
			if not slotCf or not plot or LockService.IsLocked(plot) then
				victim, stolenUid, stolenDefId = nil, nil, nil
				state = "wander"
				nextRaidAt = now + 30
				return
			end
			target = slotCf.Position
			if (Vector3.new(target.X, 0, target.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude < 3.5 then
				grabLoot()
				target = EXIT
				return
			end
		elseif state == "flee" then
			target = EXIT
			if (Vector3.new(EXIT.X, 0, EXIT.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude < 6 then
				-- escaped: the student wanders back later
				local v = victim
				if v and v.Parent then
					Remotes.Get("Notify"):FireClient(v, "Rico got away... your student will find their way back.", "bad")
				end
				dropLoot(false)
				state = "wander"
				nextRaidAt = now + rng:NextNumber(GameConfig.RivalRaidMinSeconds, GameConfig.RivalRaidMaxSeconds)
				target = IDLE_SPOTS[rng:NextInteger(1, #IDLE_SPOTS)]
				return
			end
		end

		-- move
		local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		if flat.Magnitude > 0.5 then
			local speed = state == "flee" and GameConfig.RivalWalkSpeed + 3 or GameConfig.RivalWalkSpeed
			position += flat.Unit * speed * dt
			rig:PivotTo(CFrame.lookAt(position + Vector3.new(0, 2.6, 0), position + flat.Unit * 10 + Vector3.new(0, 2.6, 0)))
			local carry = carryVisual
			if carry then
				carry:PivotTo(rig:GetPivot() * CFrame.new(0, 0.6, 2.1) * CFrame.Angles(math.rad(-14), math.rad(180), 0))
			end
		end
	end)

	-- if the victim leaves mid-raid, put everything back
	Players.PlayerRemoving:Connect(function(player)
		if player == victim then
			if carryVisual then
				carryVisual:Destroy()
				carryVisual = nil
			end
			victim, stolenUid, stolenDefId = nil, nil, nil
			if state ~= "wander" then
				state = "wander"
				target = IDLE_SPOTS[rng:NextInteger(1, #IDLE_SPOTS)]
			end
		end
	end)
end

local _ = EffectsService

return RivalService
