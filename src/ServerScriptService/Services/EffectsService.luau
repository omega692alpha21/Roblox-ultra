--!strict
-- Game feel: particles + sounds fired off the shared signals, plus world lighting.
-- All server-side so every player sees the same juice.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Sounds = require(ReplicatedStorage.Config.Sounds)
local PlotService = require(script.Parent.PlotService)
local Signals = require(script.Parent.Parent.Signals)

local EffectsService = {}

function EffectsService.PlaySound(parent: Instance, key: string)
	local spec = (Sounds :: any)[key]
	if not spec then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = spec.id
	sound.Volume = spec.volume or 0.6
	sound.PlaybackSpeed = spec.speed or 1
	sound.RollOffMaxDistance = 120
	sound.Parent = parent
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	-- safety cleanup for sounds that never fire Ended (bad ids)
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function burst(part: BasePart, color: Color3, count: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.LightEmission = 0.7
	emitter.Enabled = false
	emitter.Parent = part
	emitter:Emit(count)
	task.delay(1.5, function()
		emitter:Destroy()
	end)
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Warm afternoon lighting + post effects, all from code.
local function setupLighting()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(120, 118, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 135, 125)

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.4
	atmosphere.Color = Color3.fromRGB(199, 199, 189)
	atmosphere.Decay = Color3.fromRGB(92, 105, 120)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.2
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.TintColor = Color3.fromRGB(255, 250, 240)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.6
	rays.Parent = Lighting

	-- dynamic clouds (no assets needed)
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.22
	clouds.Color = Color3.fromRGB(255, 252, 245)
	clouds.Parent = workspace.Terrain
end

function EffectsService.Init()
	setupLighting()

	-- flag sway
	task.defer(function()
		local campus = workspace:FindFirstChild("CrumbworthHigh")
		local flag = campus and campus:FindFirstChild("Flag") :: BasePart?
		if flag then
			local base = flag.CFrame
			local tween = TweenService:Create(
				flag,
				TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ CFrame = base * CFrame.Angles(0, math.rad(9), math.rad(3)) }
			)
			tween:Play()
		end
	end)

	Signals.Collected:Connect(function(player)
		local plot = PlotService.GetPlot(player)
		if plot then
			burst(plot.collectPad, Palette.CashGreen, 24)
			EffectsService.PlaySound(plot.collectPad, "Collect")
		end
	end)

	Signals.Recruited:Connect(function(player)
		local plot = PlotService.GetPlot(player)
		if plot then
			burst(plot.collectPad, Palette.BusYellow, 18)
			EffectsService.PlaySound(plot.collectPad, "Recruit")
		end
	end)

	Signals.Stole:Connect(function(thief)
		local root = characterRoot(thief)
		if root then
			burst(root, Palette.AuraPurple, 26)
			EffectsService.PlaySound(root, "StealDone")
		end
	end)

	Signals.CaughtStealing:Connect(function(thief)
		local root = characterRoot(thief)
		if root then
			burst(root, Palette.DetentionRed, 20)
			EffectsService.PlaySound(root, "Caught")
		end
	end)

	Signals.ThiefHit:Connect(function(puncher, thief)
		local root = characterRoot(thief)
		if root then
			EffectsService.PlaySound(root, "Punch")
		end
		local _ = puncher
	end)

	Signals.QuizWon:Connect(function(player)
		local root = characterRoot(player)
		if root then
			burst(root, Palette.LockerBlue, 16)
			EffectsService.PlaySound(root, "QuizWin")
		end
	end)
end

return EffectsService
