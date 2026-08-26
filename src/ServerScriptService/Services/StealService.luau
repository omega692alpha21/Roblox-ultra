--!strict
-- The steal loop: grab a student from an unlocked enemy homeroom, carry it on your
-- back (slowed, marked), and reach your own plot to convert it. Owners recover it
-- by punching the thief. Every transition is validated server-side; the desk models
-- are visuals only — the data moves exactly once, at deposit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Students = require(ReplicatedStorage.Config.Students)
local Cliques = require(ReplicatedStorage.Config.Cliques)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local MapService = require(script.Parent.MapService)
local LockService = require(script.Parent.LockService)
local StudentGen = require(script.Parent.StudentGen)
local EffectsService = require(script.Parent.EffectsService)
local Signals = require(script.Parent.Parent.Signals)

local StealService = {}

type Carry = {
	victim: Player,
	uid: string,
	defId: string,
	carryModel: Model?,
	highlight: Highlight?,
}

local carrying: { [Player]: Carry } = {}

-- Centralized walkspeed: base + sneakers pass + clique bonus, x carry penalty.
function StealService.RefreshWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local speed = 16
	if player:GetAttribute("PassSpeed") then
		speed += GameConfig.SpeedPassBonus
	end
	local cliqueId = player:GetAttribute("Clique")
	local clique = typeof(cliqueId) == "string" and Cliques.Get(cliqueId) or nil
	if clique then
		speed += clique.walkSpeedBonus
	end
	if player:GetAttribute("Sprinting") == true then
		speed += GameConfig.SprintBonus
	end
	if carrying[player] then
		local mult = GameConfig.CarrySpeedMultiplier
		if clique and clique.carrySpeedMultOverride then
			mult = clique.carrySpeedMultOverride
		end
		speed *= mult
	end
	humanoid.WalkSpeed = speed
end

local function endCarry(player: Player)
	local carry = carrying[player]
	if not carry then
		return
	end
	carrying[player] = nil
	if carry.carryModel then
		carry.carryModel:Destroy()
	end
	if carry.highlight then
		carry.highlight:Destroy()
	end
	player:SetAttribute("Carrying", nil)
	StealService.RefreshWalkSpeed(player)
end

-- Cancel: the student stays with (returns to) the victim.
local function cancelCarry(player: Player, reason: string?)
	local carry = carrying[player]
	if not carry then
		return
	end
	local victim = carry.victim
	endCarry(player)
	if victim.Parent then
		PlotService.RebuildCrew(victim) -- respawn the desk model from data
		if reason then
			Remotes.Get("Notify"):FireClient(victim, reason, "good")
		end
	end
end

-- Called by FightService when a thief takes a punch.
function StealService.OnThiefPunched(thief: Player, puncher: Player)
	local carry = carrying[thief]
	if not carry then
		return
	end
	local victim = carry.victim
	local sameClique = victim:GetAttribute("Clique") ~= nil
		and victim:GetAttribute("Clique") == puncher:GetAttribute("Clique")
	if puncher ~= victim and not sameClique then
		return
	end
	local entry = Students.Get(carry.defId)
	local studentName = entry and entry.def.name or "student"
	cancelCarry(thief, "You saved your " .. studentName .. "!")
	Signals.CaughtStealing:Fire(thief)
	Remotes.Get("Notify"):FireClient(thief, "CAUGHT! The " .. studentName .. " went home. (-5 aura)", "bad")
end

local function completeSteal(thief: Player)
	local carry = carrying[thief]
	if not carry then
		return
	end
	local victim = carry.victim
	-- re-validate the transfer at the moment it happens
	if not DataService.IsLoaded(thief) or PlotService.CrewCount(thief) >= PlotService.MaxSlots(thief) then
		cancelCarry(thief)
		Remotes.Get("Notify"):FireClient(thief, "No free desk — the student went home!", "bad")
		return
	end
	local removed = victim.Parent and PlotService.RemoveStudent(victim, carry.uid) or nil
	if not removed then
		cancelCarry(thief)
		return
	end
	endCarry(thief)
	PlotService.AddStudent(thief, removed.id, removed.mut, removed.star)
	Signals.Stole:Fire(thief, victim, removed.id)
	local entry = Students.Get(removed.id)
	local studentName = entry and entry.def.name or "student"
	Remotes.Get("Notify"):FireClient(thief, "STOLEN! " .. studentName .. " joined your crew. (+10 aura)", "aura")
	if victim.Parent then
		Remotes.Get("Notify"):FireClient(victim, thief.DisplayName .. " stole your " .. studentName .. "!", "bad")
	end
end

local function tryGrab(thief: Player, owner: Player, plot: MapService.Plot, uid: string, defId: string)
	if thief == owner then
		return
	end
	if carrying[thief] then
		Remotes.Get("Notify"):FireClient(thief, "You're already carrying someone!", "bad")
		return
	end
	if LockService.IsLocked(plot) then
		Remotes.Get("Notify"):FireClient(thief, "This base is locked!", "bad")
		return
	end
	if not DataService.IsLoaded(thief) then
		return
	end
	if PlotService.CrewCount(thief) >= PlotService.MaxSlots(thief) then
		Remotes.Get("Notify"):FireClient(thief, "Your homeroom is full — no room to steal!", "bad")
		return
	end
	-- the desk model disappears while carried; data stays with the victim until deposit
	local deskModel = PlotService.GetStudentModel(owner, uid)
	local carriedMut: string? = nil
	local carriedStar = false
	if deskModel then
		local mutAttr = deskModel:GetAttribute("Mut")
		carriedMut = typeof(mutAttr) == "string" and mutAttr or nil
		carriedStar = deskModel:GetAttribute("Star") == true
		deskModel:Destroy()
	end

	local carryModel = StudentGen.Create(defId)
	local character = thief.Character
	if carryModel and character then
		carryModel.Name = "Carried"
		StudentGen.Decorate(carryModel, defId, carriedMut, carriedStar)
		carryModel.Parent = character
	end

	local highlight: Highlight? = nil
	if character then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(217, 67, 47)
		h.FillTransparency = 0.7
		h.OutlineColor = Color3.fromRGB(255, 80, 60)
		h.Parent = character
		highlight = h
	end

	carrying[thief] = {
		victim = owner,
		uid = uid,
		defId = defId,
		carryModel = carryModel,
		highlight = highlight,
	}
	thief:SetAttribute("Carrying", true)
	StealService.RefreshWalkSpeed(thief)

	local entry = Students.Get(defId)
	local studentName = entry and entry.def.name or "student"
	Remotes.Get("StealAlert"):FireClient(owner, thief.DisplayName, studentName)
	Remotes.Get("Notify"):FireClient(thief, "Carrying " .. studentName .. " — get back to YOUR homeroom!", "info")
	local thiefRoot = character and character:FindFirstChild("HumanoidRootPart")
	if thiefRoot then
		EffectsService.PlaySound(thiefRoot, "StealGrab")
	end
end

function StealService.Init()
	Remotes.Get("Sprint").OnServerEvent:Connect(function(player, on)
		player:SetAttribute("Sprinting", on == true)
		StealService.RefreshWalkSpeed(player)
	end)

	PlotService.SetCarriedPredicate(function(uid)
		for _, carry in carrying do
			if carry.uid == uid then
				return true
			end
		end
		return false
	end)

	-- attach steal prompts to every crew model as it spawns
	PlotService.OnStudentModelAdded(function(owner, plot, model, uid, defId)
		local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if not root then
			return
		end
		local entry = Students.Get(defId)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Steal"
		prompt.ObjectText = entry and entry.def.name or "Student"
		prompt.HoldDuration = 1.2
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(thief)
			-- model may have been rebuilt; re-resolve everything from live state
			if model.Parent == nil then
				return
			end
			tryGrab(thief, owner, plot, uid, defId)
		end)
	end)

	-- carry visuals + deposit detection
	RunService.Heartbeat:Connect(function()
		for thief, carry in carrying do
			local character = thief.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			if carry.carryModel then
				carry.carryModel:PivotTo(root.CFrame * CFrame.new(0, 1.2, 2.2) * CFrame.Angles(math.rad(-15), math.rad(180), 0))
			end
			local myPlot = PlotService.GetPlot(thief)
			if myPlot and MapService.IsInsidePlot(myPlot, root.Position) then
				completeSteal(thief)
			end
		end
	end)

	-- cancellation cases
	Players.PlayerRemoving:Connect(function(player)
		cancelCarry(player) -- thief left
		for thief, carry in carrying do
			if carry.victim == player then
				-- victim left: their save keeps the student; the carry just ends
				endCarry(thief)
				Remotes.Get("Notify"):FireClient(thief, "They dipped — the student vanished!", "bad")
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			StealService.RefreshWalkSpeed(player)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					cancelCarry(player, "The thief got dropped — your student is back!")
				end)
			end
		end)
	end)
end

function StealService.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

return StealService
