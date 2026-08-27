--!strict
-- The report card: one row per subject, your best grade, and what the whole
-- card is worth. Grades ride player attributes, so this panel needs no remote
-- and updates itself the moment a lesson ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Subjects = require(ReplicatedStorage.Config.Subjects)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local ReportCardController = {}

local player = Players.LocalPlayer

local function letterColor(ratio: number?): Color3
	if not ratio then
		return Color3.fromRGB(120, 128, 136)
	elseif ratio >= Subjects.BonusMinRatio then
		return Palette.CashGreen
	elseif ratio >= 0.4 then
		return Palette.BusYellow
	end
	return Palette.DetentionRed
end

function ReportCardController.Init(gui: ScreenGui)
	local _, content = UIBuilder.Panel(gui, "Classes", "REPORT CARD")

	-- the difficulty picker: a setting the player owns, and a harder one pays
	-- more so it is a choice and not a penalty
	local picker = UIBuilder.Frame({
		Name = "LevelPicker",
		Size = UDim2.fromScale(1, 0.14),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local pickerLayout = Instance.new("UIListLayout")
	pickerLayout.FillDirection = Enum.FillDirection.Horizontal
	pickerLayout.Padding = UDim.new(0.02, 0)
	pickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pickerLayout.Parent = picker

	local levelButtons: { [number]: TextButton } = {}
	for _, level in Subjects.Levels do
		local button = UIBuilder.Button({
			Name = "Level" .. level.id,
			Size = UDim2.fromScale(0.31, 1),
			Text = level.name,
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.1,
			LayoutOrder = level.id,
		}, function()
			Remotes.Get("SetClassLevel"):FireServer(level.id)
		end)
		UIBuilder.Round(button, 9)
		UIBuilder.Stroke(button, level.color, 2)
		button.Parent = picker
		levelButtons[level.id] = button
	end

	local pickerNote = UIBuilder.Label({
		Position = UDim2.fromScale(0, 0.155),
		Size = UDim2.fromScale(1, 0.06),
		Text = "",
		TextColor3 = Palette.Chalk,
		Parent = content,
	})

	local listHolder = UIBuilder.Frame({
		Position = UDim2.fromScale(0, 0.23),
		Size = UDim2.fromScale(1, 0.68),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local list = UIBuilder.List(listHolder)

	local rows: { { subject: Subjects.Subject, grade: TextLabel, note: TextLabel, stroke: UIStroke } } = {}
	for index, subject in Subjects.List do
		local row = UIBuilder.Frame({
			Size = UDim2.new(1, -6, 0.24, 0),
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.3,
			LayoutOrder = index,
			Parent = list,
		})
		UIBuilder.Round(row, 9)
		local stroke = Instance.new("UIStroke")
		stroke.Color = subject.color
		stroke.Thickness = 2
		stroke.Parent = row

		UIBuilder.Label({
			Position = UDim2.fromScale(0.03, 0.08),
			Size = UDim2.fromScale(0.68, 0.4),
			Text = ("%s %s"):format(subject.icon, subject.name),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local note = UIBuilder.Label({
			Position = UDim2.fromScale(0.03, 0.52),
			Size = UDim2.fromScale(0.68, 0.36),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.Chalk,
			Parent = row,
		})
		local grade = UIBuilder.Label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.97, 0.5),
			Size = UDim2.fromScale(0.24, 0.6),
			Text = "—",
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		rows[index] = { subject = subject, grade = grade, note = note, stroke = stroke }
	end

	local summary = UIBuilder.Label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromScale(1, 0.07),
		Text = "",
		TextColor3 = Palette.BusYellow,
		Parent = content,
	})

	local function refresh()
		local chosen = Subjects.Level(player:GetAttribute("ClassLevel") :: number?)
		for id, button in levelButtons do
			local active = id == chosen.id
			local level = Subjects.Level(id)
			button.BackgroundColor3 = active and level.color or Palette.PanelBg
			button.TextColor3 = active and Color3.fromRGB(24, 26, 30) or Palette.White
			local buttonStroke = button:FindFirstChildOfClass("UIStroke")
			if buttonStroke then
				buttonStroke.Thickness = active and 3 or 2
			end
		end
		pickerNote.Text = ("%s — %s"):format(chosen.name, chosen.note)

		local passed = 0
		for _, row in rows do
			local raw = player:GetAttribute("Grade_" .. row.subject.id)
			local ratio = typeof(raw) == "number" and raw or nil
			row.grade.Text = ratio and Subjects.Letter(ratio) or "—"
			row.grade.TextColor3 = letterColor(ratio)
			if ratio and ratio >= Subjects.BonusMinRatio then
				passed += 1
				row.note.Text = ("%s · %s · +%d%% income"):format(
					row.subject.professor,
					row.subject.room,
					math.floor(Subjects.IncomeBonusPerSubject * 100)
				)
			elseif ratio then
				row.note.Text = ("%s · %s · pass at B to earn the bonus"):format(row.subject.professor, row.subject.room)
			else
				row.note.Text = ("%s · %s · not attended"):format(row.subject.professor, row.subject.room)
			end
		end
		summary.Text = ("%d / %d subjects passed  ·  +%d%% income forever"):format(
			passed,
			#Subjects.List,
			math.floor(passed * Subjects.IncomeBonusPerSubject * 100)
		)
	end

	for _, subject in Subjects.List do
		player:GetAttributeChangedSignal("Grade_" .. subject.id):Connect(refresh)
	end
	player:GetAttributeChangedSignal("ClassLevel"):Connect(refresh)
	refresh()
end

return ReportCardController
