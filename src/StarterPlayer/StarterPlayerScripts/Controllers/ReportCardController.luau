--!strict
-- The report card: one row per subject, your best grade, and what the whole
-- card is worth. Grades ride player attributes, so this panel needs no remote
-- and updates itself the moment a lesson ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Subjects = require(ReplicatedStorage.Config.Subjects)
local Layout = require(script.Parent.Layout)
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
	local list = UIBuilder.List(content)

	local rows: { { subject: Subjects.Subject, grade: TextLabel, note: TextLabel, stroke: UIStroke } } = {}
	for index, subject in Subjects.List do
		local row = UIBuilder.Frame({
			Size = UDim2.new(1, -Layout.px(8), 0, Layout.px(60)),
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.3,
			LayoutOrder = index,
			Parent = list,
		})
		UIBuilder.Round(row, Layout.px(9))
		local stroke = Instance.new("UIStroke")
		stroke.Color = subject.color
		stroke.Thickness = 2
		stroke.Parent = row

		UIBuilder.Label({
			Position = UDim2.fromOffset(Layout.px(12), Layout.px(6)),
			Size = UDim2.new(1, -Layout.px(110), 0, Layout.px(26)),
			Text = ("%s %s"):format(subject.icon, subject.name),
			TextScaled = false,
			TextSize = Layout.px(20),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local note = UIBuilder.Label({
			Position = UDim2.fromOffset(Layout.px(12), Layout.px(32)),
			Size = UDim2.new(1, -Layout.px(110), 0, Layout.px(22)),
			Text = "",
			TextScaled = false,
			TextSize = Layout.px(15),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.Chalk,
			Parent = row,
		})
		local grade = UIBuilder.Label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -Layout.px(14), 0.5, 0),
			Size = UDim2.fromOffset(Layout.px(78), Layout.px(40)),
			Text = "—",
			TextScaled = false,
			TextSize = Layout.px(32),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		rows[index] = { subject = subject, grade = grade, note = note, stroke = stroke }
	end

	local summary = UIBuilder.Label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, Layout.px(24)),
		Text = "",
		TextScaled = false,
		TextSize = Layout.px(17),
		TextColor3 = Palette.BusYellow,
		Parent = content,
	})

	local function refresh()
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
	refresh()
end

return ReportCardController
