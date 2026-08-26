--!strict
-- Pop quiz modal: shows the bell's questions one at a time, sends answers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local QuizController = {}

function QuizController.Init(gui: ScreenGui)
	local modal = UIBuilder.Frame({
		Name = "QuizModal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 320),
		BackgroundColor3 = Palette.PanelBg,
		Visible = false,
		Parent = gui,
	})
	UIBuilder.Round(modal, 16)
	UIBuilder.Stroke(modal, Palette.LockerBlue, 3)

	local header = UIBuilder.Label({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 28),
		Text = "POP QUIZ!",
		TextColor3 = Palette.BusYellow,
		Parent = modal,
	})
	local questionLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 70),
		Text = "",
		TextWrapped = true,
		Parent = modal,
	})
	local answersFrame = UIBuilder.Frame({
		Position = UDim2.fromOffset(14, 120),
		Size = UDim2.new(1, -28, 0, 180),
		BackgroundTransparency = 1,
		Parent = modal,
	})
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -6, 0, 54)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.Parent = answersFrame

	local questions: { { q: string, answers: { string } } } = {}
	local currentIndex = 0

	local answerButtons: { TextButton } = {}
	for i = 1, 4 do
		local button = UIBuilder.Button({
			Text = "",
			BackgroundColor3 = Palette.LockerBlue,
			LayoutOrder = i,
		}, function()
			if currentIndex >= 1 and currentIndex <= #questions then
				Remotes.Get("QuizAnswer"):FireServer(currentIndex, i)
				currentIndex += 1
				if currentIndex > #questions then
					modal.Visible = false
				else
					QuizController.ShowQuestion(questionLabel, header, answerButtons, questions, currentIndex)
				end
			end
		end)
		UIBuilder.Round(button, 10)
		button.Parent = answersFrame
		answerButtons[i] = button
	end

	Remotes.Get("QuizStart").OnClientEvent:Connect(function(incoming, windowSeconds)
		if typeof(incoming) ~= "table" or #incoming == 0 then
			return
		end
		questions = incoming :: any
		currentIndex = 1
		modal.Visible = true
		QuizController.ShowQuestion(questionLabel, header, answerButtons, questions, currentIndex)
		-- auto-close when the window ends
		task.delay(tonumber(windowSeconds) or 60, function()
			modal.Visible = false
		end)
	end)

	Remotes.Get("QuizResult").OnClientEvent:Connect(function(correct, cash, aura)
		modal.Visible = false
		local cashNum = tonumber(cash) or 0
		if cashNum > 0 then
			header.Text = ("PASSED %d/3! +$%s"):format(tonumber(correct) or 0, NumberFormat.Abbreviate(cashNum))
		end
		local _ = aura
	end)
end

function QuizController.ShowQuestion(
	questionLabel: TextLabel,
	header: TextLabel,
	buttons: { TextButton },
	questions: { { q: string, answers: { string } } },
	index: number
)
	local question = questions[index]
	header.Text = ("POP QUIZ! Question %d of %d"):format(index, #questions)
	questionLabel.Text = question.q
	for i, button in buttons do
		local answer = question.answers[i]
		button.Visible = answer ~= nil
		button.Text = answer or ""
	end
end

return QuizController
