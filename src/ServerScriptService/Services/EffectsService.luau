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

-- The reference art is a NIGHT school. Every one of the four images is lit by
-- its own windows, its own lamp posts and a moon -- there is no daylight in any
-- of them, and no amount of grading a bright afternoon gets there. So the base
-- state of the world is 21:12, and the light that reads on a wall comes from
-- something the map placed rather than from the sun.
local function setupLighting()
	Lighting.ClockTime = 21.2
	Lighting.Brightness = 1.1
	-- At night the skybox IS the ambient source under Future lighting, so these
	-- come down with it. Left at daylight values the moon lit every wall as
	-- flatly as noon did and the whole point was lost.
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	-- softer than the daylight pass: moonlight and lantern light do not throw
	-- the hard edge a midday sun does
	Lighting.ShadowSoftness = 0.26
	-- lifted, because everything interesting is now in the bottom of the range
	Lighting.ExposureCompensation = 0.35
	Lighting.Ambient = Color3.fromRGB(20, 26, 42)
	Lighting.OutdoorAmbient = Color3.fromRGB(26, 34, 56)

	local atmosphere = Instance.new("Atmosphere")
	-- thicker than the day pass and with the glare off. Density is what turns
	-- each lamp into a pool of light instead of a bright dot, and glare at
	-- night only puts a daytime sun flare on a moon.
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(42, 53, 80)
	atmosphere.Decay = Color3.fromRGB(14, 20, 36)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.4
	atmosphere.Parent = Lighting

	-- Effect order matters: colour first to set the mood, then bloom, then
	-- depth of field, then sun rays last.
	local bloom = Instance.new("BloomEffect")
	-- The single most important effect in a night scene. Every lit window and
	-- every lantern has to bloom, so the threshold sits below the warm glass
	-- rather than above it the way it did for a daylit sky.
	bloom.Intensity = 1.1
	bloom.Size = 34
	bloom.Threshold = 0.85
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.22
	color.TintColor = Color3.fromRGB(255, 244, 228)
	color.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.07
	dof.FocusDistance = 90
	dof.InFocusRadius = 220
	dof.NearIntensity = 0
	dof.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	-- almost off: this is moonlight, not a sunburst
	rays.Intensity = 0.06
	rays.Spread = 0.9
	rays.Parent = Lighting

	-- Poly Haven's CC0 "kloppenheim_02_puresky", reprojected into six cube faces
	-- and graded back DOWN to night. Poly Haven ships a tonemapped JPEG of each
	-- HDRI lifted until a human can see what is in it, so the preview of a
	-- moonlit sky arrives looking like an overcast afternoon -- the sky body
	-- sits near 0.72 where it should sit near 0.09. tools/polyhaven_sky.py
	-- --night puts a steep curve on LUMINANCE (x^6.5 leaves 1.0 alone and drops
	-- 0.72 to 0.07) and then puts the colour back, so the moon and the stars
	-- survive while the sky goes dark. The HDRI was shot over water, so the
	-- bottom half of each side face is damped too, or a second moon shows up
	-- reflected under the campus.
	local sky = Instance.new("Sky")
	sky.SkyboxFt = "rbxassetid://79846493290175"
	sky.SkyboxBk = "rbxassetid://130398659137186"
	sky.SkyboxLf = "rbxassetid://116403753333857"
	sky.SkyboxRt = "rbxassetid://99678736704051"
	sky.SkyboxUp = "rbxassetid://86839626686018"
	sky.SkyboxDn = "rbxassetid://137547163500609"
	sky.SunAngularSize = 9
	sky.MoonAngularSize = 16
	sky.StarCount = 5200
	sky.Parent = Lighting

	local clouds = Instance.new("Clouds")
	-- thin, dark and slow: at night cloud is something the moon catches the
	-- edge of, not a bright mass
	clouds.Cover = 0.55
	clouds.Density = 0.035
	clouds.Color = Color3.fromRGB(58, 69, 96)
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
