--!strict
-- Base locks: the lock switch arms the laser gate for a duration scaled by grade
-- and the Extended Lock pass. The gate bounces non-owners while locked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local MapService = require(script.Parent.MapService)
local Signals = require(script.Parent.Parent.Signals)

local LockService = {}

local lockedUntil: { [number]: number } = {} -- plot index -> os.clock deadline
local cooldownUntil: { [Player]: number } = {}

function LockService.IsLocked(plot: MapService.Plot): boolean
	return (lockedUntil[plot.index] or 0) > os.clock()
end

function LockService.LockDurationFor(player: Player): number
	local profile = DataService.Get(player)
	local grade = profile and profile.grade or 0
	local duration = GameConfig.BaseLockSeconds + grade * GameConfig.LockSecondsPerRebirth
	if player:GetAttribute("PassLock") then
		duration += GameConfig.ExtendedLockPassBonus
	end
	return duration
end

local function setGateVisual(plot: MapService.Plot, locked: boolean)
	if locked then
		plot.gate.Color = Palette.DetentionRed
		plot.gate.Transparency = 0.35
	else
		plot.gate.Color = Palette.CashGreen
		plot.gate.Transparency = 0.7
	end
end

local function lockPlot(plot: MapService.Plot, seconds: number, owner: Player?)
	lockedUntil[plot.index] = os.clock() + seconds
	setGateVisual(plot, true)
	if owner then
		owner:SetAttribute("LockUntil", workspace:GetServerTimeNow() + seconds)
	end
	task.delay(seconds, function()
		if not LockService.IsLocked(plot) then
			setGateVisual(plot, false)
		end
	end)
end

function LockService.Init(map: MapService.Map)
	for _, plot in map.plots do
		-- lock switch prompt (owner only)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Lock Base"
		prompt.ObjectText = "Lock Switch"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = plot.lockSwitch
		prompt.Triggered:Connect(function(player)
			if PlotService.GetPlot(player) ~= plot then
				Remotes.Get("Notify"):FireClient(player, "That's not your lock switch!", "bad")
				return
			end
			local now = os.clock()
			if LockService.IsLocked(plot) then
				return
			end
			if now < (cooldownUntil[player] or 0) then
				Remotes.Get("Notify"):FireClient(
					player,
					("Lock recharging (%ds left)"):format(math.ceil((cooldownUntil[player] or 0) - now)),
					"bad"
				)
				return
			end
			local duration = LockService.LockDurationFor(player)
			cooldownUntil[player] = now + duration + GameConfig.LockCooldownSeconds
			lockPlot(plot, duration, player)
			Signals.Locked:Fire(player)
			Remotes.Get("Notify"):FireClient(player, ("Base locked for %ds!"):format(duration), "good")
		end)

		-- the gate bounces intruders while locked
		plot.gate.Touched:Connect(function(hit)
			if not LockService.IsLocked(plot) then
				return
			end
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character :: any)
			if not player or PlotService.GetPlot(player) == plot then
				return
			end
			local root = (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				-- shove them back out along the plot's outward direction
				local outward = plot.cframe.LookVector
				root.AssemblyLinearVelocity = outward * 60 + Vector3.new(0, 30, 0)
			end
		end)
	end

	-- grace lock when a player claims a plot
	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			local plot = PlotService.GetPlot(player)
			if plot then
				lockPlot(plot, GameConfig.JoinGraceLockSeconds, player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldownUntil[player] = nil
	end)
end

return LockService
