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
	-- The grade the references actually have. The last pass read them as
	-- "desaturated with strong value contrast" and pulled saturation down to
	-- almost nothing. That is what a photograph of an overcast day looks like;
	-- the reference art is the opposite -- a hard blue sky, grass at a green
	-- no lawn has ever been, and shadows that go COOL rather than grey. Value
	-- contrast comes from the cool shadow and the warm sun, not from draining
	-- the colour out of everything.
	Lighting.ClockTime = 14.9
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.85
	Lighting.GlobalShadows = true
	-- crisper than 0.32: the reference shadows have a readable edge, which is
	-- most of what makes the light feel like sunlight
	Lighting.ShadowSoftness = 0.16
	Lighting.ExposureCompensation = 0.12
	-- shadow fill is BLUE, not grey. This one value does more for the painterly
	-- read than every post effect underneath it.
	Lighting.Ambient = Color3.fromRGB(92, 104, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(104, 124, 158)

	local atmosphere = Instance.new("Atmosphere")
	-- thinner and much less hazy: the reference horizon is CLEAR, with distant
	-- rock still reading as rock. At density 0.36 and haze 1.2 the far ridge
	-- dissolved into flat grey before you could see its shape.
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(206, 222, 240)
	atmosphere.Decay = Color3.fromRGB(84, 122, 172)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 0.55
	atmosphere.Parent = Lighting

	-- Effect order matters: colour first to set the mood, then bloom, then
	-- depth of field, then sun rays last.
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 28
	bloom.Threshold = 1.45
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.32
	color.Contrast = 0.12
	color.TintColor = Color3.fromRGB(255, 250, 242)
	color.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	-- Far intensity is nearly off. The reference art keeps the distant ridge
	-- SHARP -- that is what makes it read as illustration rather than as a
	-- photograph -- and blurring the horizon threw away the silhouette the rocks
	-- are there to provide.
	dof.FarIntensity = 0.07
	dof.FocusDistance = 90
	dof.InFocusRadius = 220
	dof.NearIntensity = 0
	dof.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.16
	rays.Spread = 0.72
	rays.Parent = Lighting

	-- A captured sky, GRADED until it is a painted one: a Poly Haven CC0 HDRI
	-- (kloofendal 48d partly cloudy) reprojected into six cube faces and then
	-- pushed through tools/polyhaven_sky.py --paint. The honest photograph was
	-- pale, and pale is the one thing the reference skies are not: they are a
	-- deep near-cyan blue with hard-edged cumulus piled on it. The grade is an
	-- S-curve on value, a strong hue-preserving saturation lift, a cool tint on
	-- the sky half, and an unsharp mask on luminance so the cloud edges harden
	-- without the colours fringing.
	--
	-- This is not only what you see overhead. Future lighting reads the skybox
	-- for ambient and for the environment map, so it is also the colour sitting
	-- on every surface in the school.
	local sky = Instance.new("Sky")
	sky.SkyboxFt = "rbxassetid://135895560098567"
	sky.SkyboxBk = "rbxassetid://120660575156931"
	sky.SkyboxLf = "rbxassetid://73978198707631"
	sky.SkyboxRt = "rbxassetid://128286468637605"
	sky.SkyboxUp = "rbxassetid://129589306570732"
	sky.SkyboxDn = "rbxassetid://87490931555372"
	sky.SunAngularSize = 13
	sky.Parent = Lighting

	-- soft dynamic clouds drift in front of the painted ones
	-- Big ones. The reference skies are half cumulus, piled up and bright
	-- against a hard blue; at 0.18 cover and 0.12 density they were a haze you
	-- had to look for.
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.62
	clouds.Density = 0.05
	clouds.Color = Color3.fromRGB(255, 253, 248)
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
