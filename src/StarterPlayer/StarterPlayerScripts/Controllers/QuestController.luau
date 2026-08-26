--!strict
-- Daily quests panel: three quest rows with progress + claim buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local QuestController = {}

function QuestController.Init(gui: ScreenGui)
	local _, content = UIBuilder.Panel(gui, "Quests", "DAILY QUESTS")
	local list = UIBuilder.List(content)

	local rows: { { frame: Frame, label: TextLabel, progress: TextLabel, claim: TextButton } } = {}
	for i = 1, 3 do
		local frame = UIBuilder.Frame({
			Size = UDim2.new(1, -8, 0, 78),
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.3,
			LayoutOrder = i,
			Parent = list,
		})
		UIBuilder.Round(frame, 10)
		UIBuilder.Stroke(frame, Palette.AuraPurple, 2)
		local label = UIBuilder.Label({
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -140, 0, 30),
			Text = "...",
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local progress = UIBuilder.Label({
			Position = UDim2.fromOffset(12, 42),
			Size = UDim2.new(1, -140, 0, 26),
			Text = "",
			TextColor3 = Palette.Chalk,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 15,
			Parent = frame,
		})
		local claim = UIBuilder.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 44),
			Text = "CLAIM",
			BackgroundColor3 = Color3.fromRGB(85, 105, 79),
		}, function()
			Remotes.Get("ClaimQuest"):FireServer(i)
		end)
		UIBuilder.Round(claim, 999)
		claim.Parent = frame
		rows[i] = { frame = frame, label = label, progress = progress, claim = claim }
	end

	UIBuilder.Label({
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Finish all 3 for a bonus wheel spin! Resets daily.",
		TextColor3 = Palette.BusYellow,
		TextScaled = false,
		TextSize = 15,
		Parent = content,
	})

	Remotes.Get("QuestState").OnClientEvent:Connect(function(quests)
		if typeof(quests) ~= "table" then
			return
		end
		for i = 1, 3 do
			local row = rows[i]
			local quest = (quests :: any)[i]
			if not quest then
				row.frame.Visible = false
				continue
			end
			row.frame.Visible = true
			row.label.Text = quest.label
			row.progress.Text = ("%s / %s   ·   +$%s%s"):format(
				NumberFormat.Abbreviate(quest.progress),
				NumberFormat.Abbreviate(quest.goal),
				NumberFormat.Abbreviate(quest.cash),
				quest.aura > 0 and "  +" .. quest.aura .. " aura" or ""
			)
			if quest.claimed then
				row.claim.Text = "DONE"
				row.claim.BackgroundColor3 = Color3.fromRGB(60, 72, 56)
			elseif quest.progress >= quest.goal then
				row.claim.Text = "CLAIM"
				row.claim.BackgroundColor3 = Palette.BusYellow
				row.claim.TextColor3 = Palette.Blackboard
			else
				row.claim.Text = "..."
				row.claim.BackgroundColor3 = Color3.fromRGB(85, 105, 79)
				row.claim.TextColor3 = Palette.White
			end
		end
	end)
end

return QuestController
