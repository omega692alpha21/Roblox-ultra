--!strict
-- The lesson screen: one shell, laid out four ways.
--
-- Every subject sends the same shape — a prompt and four buttons — so the
-- difference between arithmetic, a colour mix, a specimen ID and a musical
-- phrase is how this renders them and what a press means, not four separate
-- screens to keep working.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local ClassController = {}

local player = Players.LocalPlayer

-- one tone per pad, so a musical phrase is something you hear and not just
-- four rectangles blinking
local PAD_PITCH = { 0.8, 1.0, 1.2, 1.5 }

local function tone(index: number)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.5
	sound.PlaybackSpeed = PAD_PITCH[index] or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(3, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function ClassController.Init(gui: ScreenGui)
	local panel = UIBuilder.Frame({
		Name = "ClassPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.66),
		BackgroundColor3 = Palette.PanelBg,
		Visible = false,
		ZIndex = 60,
		Parent = gui,
	})
	UIBuilder.Round(panel, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.BusYellow
	stroke.Thickness = 3
	stroke.Parent = panel

	local heading = UIBuilder.Label({
		Position = UDim2.fromScale(0.035, 0.03),
		Size = UDim2.fromScale(0.68, 0.09),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.BusYellow,
		Parent = panel,
	})
	local clock = UIBuilder.Label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.965, 0.03),
		Size = UDim2.fromScale(0.24, 0.09),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Palette.Chalk,
		Parent = panel,
	})
	local prompt = UIBuilder.Label({
		Position = UDim2.fromScale(0.035, 0.14),
		Size = UDim2.fromScale(0.93, 0.2),
		Text = "",
		TextWrapped = true,
		Parent = panel,
	})

	local grid = UIBuilder.Frame({
		Position = UDim2.fromScale(0.035, 0.36),
		Size = UDim2.fromScale(0.93, 0.46),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromScale(0.485, 0.47)
	gridLayout.CellPadding = UDim2.fromScale(0.03, 0.06)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local footer = UIBuilder.Label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(0.93, 0.09),
		Text = "",
		TextColor3 = Palette.Chalk,
		Parent = panel,
	})

	-- the four buttons are built once and re-labelled every round
	local buttons: { TextButton } = {}
	local onPress: (number) -> () = function() end
	for slot = 1, 4 do
		local button = UIBuilder.Button({
			Name = "Option" .. slot,
			Text = "",
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.05,
			LayoutOrder = slot,
			ZIndex = 61,
		}, function()
			onPress(slot)
		end)
		UIBuilder.Round(button, 10)
		UIBuilder.Stroke(button, Palette.Chalk, 2)
		button.Parent = grid
		buttons[slot] = button
	end

	local function flash(slot: number, color: Color3)
		local button = buttons[slot]
		local original = button.BackgroundColor3
		button.BackgroundColor3 = color
		TweenService:Create(button, TweenInfo.new(0.28), { BackgroundColor3 = original }):Play()
	end

	local session: any = nil
	local roundIndex = 0
	local entered: { number } = {}
	local accepting = false

	local function close()
		session = nil
		accepting = false
		panel.Visible = false
	end

	local function paint(round: any, mode: string)
		prompt.Text = round.prompt
		for slot = 1, 4 do
			local button = buttons[slot]
			local text = round.options and round.options[slot] or ""
			local color = round.colors and round.colors[slot]
			button.Text = text
			button.BackgroundColor3 = color or Palette.PanelBg
			button.TextColor3 = color and Color3.fromRGB(24, 26, 30) or Palette.White
			-- emoji and reflex targets want to be big; words want to fit
			local buttonStroke = button:FindFirstChildOfClass("UIStroke")
			if buttonStroke then
				buttonStroke.Color = color or Palette.Chalk
			end
		end
	end

	local function nextRound()
		roundIndex += 1
		local round = session and session.rounds[roundIndex]
		if not round then
			footer.Text = "Lesson over — waiting on your grade…"
			accepting = false
			return
		end
		paint(round, session.mode)

		if round.sequence then
			-- call and response: play the phrase, then take it back
			accepting = false
			entered = {}
			footer.Text = "Listen…"
			task.spawn(function()
				local mine = roundIndex
				task.wait(0.5)
				for _, note in round.sequence do
					if roundIndex ~= mine or not session then
						return
					end
					flash(note, Color3.fromRGB(255, 250, 235))
					tone(note)
					task.wait(0.45)
				end
				if roundIndex == mine and session then
					accepting = true
					footer.Text = ("Play it back — %d note%s"):format(
						#round.sequence,
						if #round.sequence == 1 then "" else "s"
					)
				end
			end)
		else
			accepting = true
			footer.Text = ("Question %d of %d"):format(roundIndex, #session.rounds)
		end
	end

	onPress = function(slot)
		if not session or not accepting then
			return
		end
		local round = session.rounds[roundIndex]
		if not round then
			return
		end
		if round.sequence then
			tone(slot)
			flash(slot, Color3.fromRGB(255, 250, 235))
			table.insert(entered, slot)
			footer.Text = ("%d / %d"):format(#entered, #round.sequence)
			if #entered >= #round.sequence then
				accepting = false
				Remotes.Get("ClassAnswer"):FireServer(roundIndex, table.clone(entered))
				task.delay(0.4, nextRound)
			end
			return
		end
		accepting = false
		flash(slot, Palette.BusYellow)
		Remotes.Get("ClassAnswer"):FireServer(roundIndex, slot)
		task.delay(0.22, nextRound)
	end

	Remotes.Get("ClassStart").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		session = payload
		roundIndex = 0
		entered = {}
		panel.Visible = true
		heading.Text = ("%s %s · %s · %s"):format(
			payload.icon,
			payload.name,
			payload.levelName or "Standard",
			payload.professor
		)
		local deadline = os.clock() + (payload.seconds or 45)
		task.spawn(function()
			while session == payload and os.clock() < deadline do
				clock.Text = ("%ds"):format(math.max(0, math.ceil(deadline - os.clock())))
				task.wait(0.25)
			end
		end)
		nextRound()
	end)

	Remotes.Get("ClassResult").OnClientEvent:Connect(function(correct, total, cash, _aura, letter)
		close()
		-- the grade card: brief, and the only thing on screen
		local card = UIBuilder.Frame({
			Name = "GradeCard",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.32, 0.3),
			BackgroundColor3 = Palette.PanelBg,
			ZIndex = 62,
			Parent = gui,
		})
		UIBuilder.Round(card, 14)
		local pass = typeof(letter) == "string" and letter ~= "F"
		UIBuilder.Stroke(card, pass and Palette.CashGreen or Palette.DetentionRed, 3)
		UIBuilder.Label({
			Position = UDim2.fromScale(0, 0.06),
			Size = UDim2.fromScale(1, 0.4),
			Text = tostring(letter),
			TextColor3 = pass and Palette.CashGreen or Palette.DetentionRed,
			Parent = card,
		})
		UIBuilder.Label({
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, 0.2),
			Text = ("%d / %d correct"):format(correct or 0, total or 0),
			Parent = card,
		})
		UIBuilder.Label({
			Position = UDim2.fromScale(0, 0.72),
			Size = UDim2.fromScale(1, 0.2),
			Text = if (cash or 0) > 0 then ("+$%d"):format(cash) else "No credit this time",
			TextColor3 = Palette.BusYellow,
			Parent = card,
		})
		task.delay(4, function()
			card:Destroy()
		end)
	end)

	-- if the lesson never resolves (left the room, server restart) do not
	-- leave a modal stuck over the game
	player.CharacterRemoving:Connect(close)
end

return ClassController
