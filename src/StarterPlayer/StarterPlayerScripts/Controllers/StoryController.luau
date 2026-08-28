--!strict
-- THE CRUMBWORTH FILES panel: where you are in the story and what closes the
-- current chapter.
--
-- Every chapter is listed, including the ones you cannot reach yet, with the
-- school year that opens them. Knowing what is coming is most of the reason
-- anyone graduates; a story that only shows you the step you are on is a quest
-- log, not a story.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local StoryController = {}

local player = Players.LocalPlayer

local STATE_COLOR = {
	done = Color3.fromRGB(96, 200, 120),
	open = Color3.fromRGB(245, 197, 49),
	waiting = Color3.fromRGB(150, 160, 178),
	locked = Color3.fromRGB(96, 100, 112),
}

function StoryController.Init(gui: ScreenGui)
	local _, content = UIBuilder.Panel(gui, "Story", "THE CRUMBWORTH FILES")
	local list = UIBuilder.List(content)

	local function render(state: any)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for _, chapter in state.chapters do
			local accent = STATE_COLOR[chapter.state] or STATE_COLOR.locked
			local rows = #chapter.objectives
			local height = 54 + rows * 26 + (chapter.state == "done" and 20 or 0)
			local card = UIBuilder.Frame({
				Size = UDim2.new(1, -8, 0, height),
				BackgroundColor3 = Palette.PanelBg,
				BackgroundTransparency = chapter.state == "locked" and 0.6 or 0.25,
				LayoutOrder = chapter.number,
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

	Remotes.Get("StoryState").OnClientEvent:Connect(render)
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

return StoryController
