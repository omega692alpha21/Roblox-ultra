--!strict
-- Rewards panel: playtime chest track, streak display, spin wheel, group reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Rewards = require(ReplicatedStorage.Config.Rewards)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local RewardsController = {}

local state: any = nil
local stateReceivedAt = 0

function RewardsController.Init(gui: ScreenGui)
	local panel, content = UIBuilder.Panel(gui, "Rewards", "CAFETERIA REWARDS")

	-- playtime track
	UIBuilder.Label({
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "PLAYTIME CHESTS",
		TextColor3 = Palette.BusYellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	local track = UIBuilder.Frame({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local trackLayout = Instance.new("UIListLayout")
	trackLayout.FillDirection = Enum.FillDirection.Horizontal
	trackLayout.Padding = UDim.new(0, 6)
	trackLayout.Parent = track

	local chestButtons: { TextButton } = {}
	for i, tier in Rewards.Playtime do
		local button = UIBuilder.Button({
			Size = UDim2.fromOffset(76, 74),
			Text = tostring(tier.minutes) .. "m",
			BackgroundColor3 = Color3.fromRGB(85, 105, 79),
			LayoutOrder = i,
		}, function()
			Remotes.Get("ClaimPlaytime"):FireServer(i)
		end)
		UIBuilder.Round(button, 10)
		button.Parent = track
		chestButtons[i] = button
	end

	-- streak
	local streakLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "LOGIN STREAK: day 1",
		TextColor3 = Palette.AuraPurple,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})

	-- wheel
	UIBuilder.Label({
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "SPIN WHEEL",
		TextColor3 = Palette.BusYellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	local prizeLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(0, 178),
		Size = UDim2.new(1, 0, 0, 60),
		Text = "Prizes: cash, luck boosts, free students up to MYTHIC",
		TextColor3 = Palette.Chalk,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		Parent = content,
	})
	local spinButton = UIBuilder.Button({
		Position = UDim2.fromOffset(0, 244),
		Size = UDim2.fromOffset(200, 48),
		Text = "SPIN!",
		BackgroundColor3 = Palette.AuraPurple,
	}, function()
		Remotes.Get("SpinWheel"):FireServer()
	end)
	UIBuilder.Round(spinButton, 12)
	spinButton.Parent = content

	-- group reward
	local groupButton = UIBuilder.Button({
		Position = UDim2.fromOffset(220, 244),
		Size = UDim2.fromOffset(230, 48),
		Text = "GROUP REWARD: $" .. NumberFormat.Abbreviate(Rewards.GroupJoinCash),
		BackgroundColor3 = Palette.CashGreen,
	}, function()
		Remotes.Get("ClaimSocial"):FireServer("group")
	end)
	UIBuilder.Round(groupButton, 12)
	groupButton.Parent = content

	-- state sync
	Remotes.Get("RewardState").OnClientEvent:Connect(function(newState)
		state = newState
		stateReceivedAt = os.clock()
	end)
	task.spawn(function()
		local fetched = Remotes.GetFunction("GetRewardState"):InvokeServer()
		if fetched and not state then
			state = fetched
			stateReceivedAt = os.clock()
		end
	end)

	Remotes.Get("SpinResult").OnClientEvent:Connect(function(_prizeIndex, label)
		-- simple reveal: flash the label through a few prizes then land
		task.spawn(function()
			for i = 1, 8 do
				local random = Rewards.Wheel[(i % #Rewards.Wheel) + 1]
				prizeLabel.Text = "Spinning... " .. random.label
				prizeLabel.TextColor3 = Palette.Chalk
				task.wait(0.2)
			end
			prizeLabel.Text = "YOU WON: " .. tostring(label) .. "!"
			prizeLabel.TextColor3 = Palette.BusYellow
		end)
	end)

	RunService.Heartbeat:Connect(function()
		if not panel.Visible or not state then
			return
		end
		local elapsed = (state.elapsed or 0) + (os.clock() - stateReceivedAt)
		for i, tier in Rewards.Playtime do
			local button = chestButtons[i]
			if state.playtimeClaimed and state.playtimeClaimed[i] then
				button.Text = "DONE"
				button.BackgroundColor3 = Color3.fromRGB(60, 72, 56)
			elseif elapsed >= tier.minutes * 60 then
				button.Text = "CLAIM\n" .. tier.minutes .. "m"
				button.BackgroundColor3 = Palette.BusYellow
				button.TextColor3 = Palette.Blackboard
			else
				button.Text = NumberFormat.Clock(tier.minutes * 60 - elapsed)
				button.BackgroundColor3 = Color3.fromRGB(85, 105, 79)
				button.TextColor3 = Palette.White
			end
		end
		streakLabel.Text = ("LOGIN STREAK: day %d of 7"):format(state.streakDay or 1)
		local spins = state.spinTokens or 0
		local freeSpin = state.freeSpin and 1 or 0
		spinButton.Text = ("SPIN! (%d left)"):format(spins + freeSpin)
	end)
end

return RewardsController
