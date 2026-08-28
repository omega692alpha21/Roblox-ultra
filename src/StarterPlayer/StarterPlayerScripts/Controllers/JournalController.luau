--!strict
-- The journal: everything the school currently wants from you, in one place.
--
-- TODAY is the three daily quests, with their claim buttons. THE CRUMBWORTH
-- FILES is the story -- every chapter listed, including the ones you cannot
-- reach yet, with the school year that opens them. Knowing what is coming is
-- most of the reason anyone graduates; a story that only shows the step you
-- are on is a quest log, not a story.
--
-- This is where a conversation lands. Principal Crumb tells you three things
-- to do and the last button in the dialogue says ADD TO JOURNAL, because a
-- character who hands you objectives and then vanishes has told you nothing
-- you can act on afterwards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local JournalController = {}

local player = Players.LocalPlayer

local STATE_COLOR = {
	done = Color3.fromRGB(96, 200, 120),
	open = Color3.fromRGB(245, 197, 49),
	waiting = Color3.fromRGB(150, 160, 178),
	locked = Color3.fromRGB(96, 100, 112),
}

function JournalController.Init(gui: ScreenGui)
	local _, content = UIBuilder.Panel(gui, "Journal", "JOURNAL")
	local list = UIBuilder.List(content)

	local questRows: { any } = {}
	local storyState: any = nil

	local function heading(text: string, order: number)
		local label = UIBuilder.Label({
			Size = UDim2.new(1, -8, 0, 26),
			Text = text,
			TextColor3 = Color3.fromRGB(150, 162, 178),
			TextScaled = false,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			Parent = list,
		})
		return label
	end

	local function renderQuests()
		for index, quest in questRows do
			local card = UIBuilder.Frame({
				Size = UDim2.new(1, -8, 0, 46),
				BackgroundColor3 = Palette.PanelBg,
				BackgroundTransparency = 0.3,
				LayoutOrder = 1 + index,
				Parent = list,
			})
			UIBuilder.Round(card, 10)
			local complete = quest.progress >= quest.goal
			UIBuilder.Stroke(card, complete and STATE_COLOR.done or STATE_COLOR.waiting, 2)
			UIBuilder.Label({
				Position = UDim2.fromOffset(12, 4),
				Size = UDim2.new(1, -130, 0, 22),
				Text = quest.label,
				TextColor3 = Palette.Chalk,
				TextScaled = false,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})
			UIBuilder.Label({
				Position = UDim2.fromOffset(12, 24),
				Size = UDim2.new(1, -130, 0, 18),
				Text = ("%d / %d"):format(math.min(quest.progress, quest.goal), quest.goal),
				TextColor3 = Color3.fromRGB(150, 162, 178),
				TextScaled = false,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})
			if quest.claimed then
				UIBuilder.Label({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(100, 24),
					Text = "CLAIMED",
					TextColor3 = STATE_COLOR.done,
					TextScaled = false,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = card,
				})
			elseif complete then
				local claim = UIBuilder.Button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(100, 30),
					Text = "CLAIM",
					BackgroundColor3 = Palette.CashGreen,
				}, function()
					Remotes.Get("ClaimQuest"):FireServer(index)
				end)
				UIBuilder.Round(claim, 999)
				claim.Parent = card
			end
		end
	end

	local function render()
		local state = storyState
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if #questRows > 0 then
			heading("TODAY", 0)
			renderQuests()
		end
		heading("THE CRUMBWORTH FILES", 20)
		if not state then
			return
		end
		for _, chapter in state.chapters do
			local accent = STATE_COLOR[chapter.state] or STATE_COLOR.locked
			local rows = #chapter.objectives
			local height = 54 + rows * 26 + (chapter.state == "done" and 20 or 0)
			local card = UIBuilder.Frame({
				Size = UDim2.new(1, -8, 0, height),
				BackgroundColor3 = Palette.PanelBg,
				BackgroundTransparency = chapter.state == "locked" and 0.6 or 0.25,
				LayoutOrder = 20 + chapter.number,
				Parent = list,
			})
			UIBuilder.Round(card, 10)
			UIBuilder.Stroke(card, accent, 2)

			UIBuilder.Label({
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -24, 0, 24),
				Text = ("%d. %s"):format(chapter.number, chapter.title),
				TextColor3 = accent,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})
			local subtitle = if chapter.state == "done"
				then "closed"
				elseif chapter.state == "open" then chapter.speaker
				elseif chapter.state == "waiting" then "opens in " .. Rebirths.GradeName(chapter.grade)
				else "opens in " .. Rebirths.GradeName(chapter.grade)
			UIBuilder.Label({
				Position = UDim2.fromOffset(12, 30),
				Size = UDim2.new(1, -24, 0, 18),
				Text = subtitle,
				TextColor3 = Color3.fromRGB(160, 172, 188),
				TextScaled = false,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})

			for index, objective in chapter.objectives do
				local y = 52 + (index - 1) * 26
				local complete = objective.have >= objective.goal
				UIBuilder.Label({
					Position = UDim2.fromOffset(18, y),
					Size = UDim2.new(1, -140, 0, 20),
					Text = (complete and "✔ " or "• ") .. objective.label,
					TextColor3 = complete and STATE_COLOR.done or Palette.Chalk,
					TextScaled = false,
					TextSize = 15,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = card,
				})
				local track = UIBuilder.Frame({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -14, 0, y + 6),
					Size = UDim2.fromOffset(96, 9),
					BackgroundColor3 = Color3.fromRGB(18, 20, 26),
					Parent = card,
				})
				UIBuilder.Round(track, 999)
				local fill = UIBuilder.Frame({
					Size = UDim2.fromScale(math.clamp(objective.have / math.max(1, objective.goal), 0, 1), 1),
					BackgroundColor3 = complete and STATE_COLOR.done or accent,
					Parent = track,
				})
				UIBuilder.Round(fill, 999)
			end

			if chapter.state == "done" and chapter.reveal then
				UIBuilder.Label({
					Position = UDim2.fromOffset(18, 52),
					Size = UDim2.new(1, -30, 0, 20),
					Text = "“" .. (chapter.reveal[#chapter.reveal] or "") .. "”",
					TextColor3 = Color3.fromRGB(150, 165, 150),
					TextScaled = false,
					TextSize = 13,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = card,
				})
			end
		end
	end

	Remotes.Get("StoryState").OnClientEvent:Connect(function(state)
		storyState = state
		render()
	end)
	Remotes.Get("QuestState").OnClientEvent:Connect(function(rows)
		questRows = typeof(rows) == "table" and rows or {}
		render()
	end)
	task.spawn(function()
		for _ = 1, 60 do
			if player:GetAttribute("DataLoaded") == true then
				break
			end
			task.wait(0.5)
		end
		pcall(function()
			Remotes.GetFunction("GetStory"):InvokeServer()
		end)
	end)
end

return JournalController
