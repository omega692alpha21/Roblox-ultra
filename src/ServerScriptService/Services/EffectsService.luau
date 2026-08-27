--!strict
-- Game feel: particles + sounds fired off the shared signals, plus world lighting.
-- All server-side so every player sees the same juice.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
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

-- A one-shot hit at a world point: particles plus a sound, on a throwaway
-- part that cleans itself up. Actions that produce nothing visible at the
-- point of contact are what made punching and throwing feel like nothing
-- happened.
function EffectsService.Hit(position: Vector3, color: Color3, soundKey: string, count: number?)
	local marker = Instance.new("Part")
	marker.Name = "HitFx"
	marker.Size = Vector3.new(0.2, 0.2, 0.2)
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.CFrame = CFrame.new(position)
	marker.Parent = workspace
	burst(marker, color, count or 14)
	EffectsService.PlaySound(marker, soundKey)
	task.delay(2.5, function()
		marker:Destroy()
	end)
end

-- Floating "+$X" that rises and fades at a world position.
function EffectsService.CashPopup(position: Vector3, amount: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(6, 2)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Palette.CashGreen
	label.TextStrokeTransparency = 0.3
	label.Text = "+$" .. NumberFormat.Abbreviate(amount)
	label.Parent = billboard

	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position + Vector3.new(0, 7, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Warm afternoon lighting + post effects, all from code.
local function setupLighting()
	-- Tuned for the PBR materials rather than for flat plastic. With real
	-- normal and roughness maps the surfaces carry their own shading, so the
	-- scene wants less brightness and far less saturation than it did — the
	-- painterly references read as desaturated with strong value contrast, not
	-- as bright colour.
	Lighting.ClockTime = 14.4
	Lighting.Brightness = 2.1
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.32
	Lighting.ExposureCompensation = 0.08
	Lighting.Ambient = Color3.fromRGB(118, 116, 112)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 138, 138)

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.28
	atmosphere.Color = Color3.fromRGB(202, 204, 196)
	atmosphere.Decay = Color3.fromRGB(98, 112, 128)
	atmosphere.Glare = 0.16
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	-- Effect order matters: colour first to set the mood, then bloom, then
	-- depth of field, then sun rays last.
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.34
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.09
	color.Contrast = 0.17
	color.TintColor = Color3.fromRGB(255, 250, 240)
	color.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.26
	dof.FocusDistance = 62
	dof.InFocusRadius = 120
	dof.NearIntensity = 0
	dof.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.11
	rays.Spread = 0.55
	rays.Parent = Lighting

	-- painted cumulus skybox (the anime sky is half the look)
	local sky = Instance.new("Sky")
	sky.SkyboxFt = "rbxassetid://121551770769255"
	sky.SkyboxBk = "rbxassetid://115007466005880"
	sky.SkyboxLf = "rbxassetid://140564987029974"
	sky.SkyboxRt = "rbxassetid://74714793037291"
	sky.SkyboxUp = "rbxassetid://112410446557476"
	sky.SkyboxDn = "rbxassetid://85988275555967"
	sky.SunAngularSize = 14
	sky.Parent = Lighting

	-- soft dynamic clouds drift in front of the painted ones
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.32
	clouds.Density = 0.18
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

	Signals.RivalFoiled:Connect(function(puncher)
		local root = characterRoot(puncher)
		if root then
			burst(root, Palette.BusYellow, 22)
			EffectsService.PlaySound(root, "Punch")
		end
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
