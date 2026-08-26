--!strict
-- Crew panel: your roster grouped by student, with fusion (3 dupes -> 1 Star).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Students = require(ReplicatedStorage.Config.Students)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local CrewController = {}

type Member = { uid: string, id: string, mut: string?, star: boolean? }

function CrewController.Init(gui: ScreenGui)
	local _, content = UIBuilder.Panel(gui, "Crew", "YOUR CREW")
	local list = UIBuilder.List(content)

	local function render(crew: { Member })
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		-- group by student id
		local groups: { [string]: { members: { Member }, fusable: number } } = {}
		local orderIds: { string } = {}
		for _, member in crew do
			local group = groups[member.id]
			if not group then
				group = { members = {}, fusable = 0 }
				groups[member.id] = group
				table.insert(orderIds, member.id)
			end
			table.insert(group.members, member)
			if not member.star then
				group.fusable += 1
			end
		end

		if #orderIds == 0 then
			UIBuilder.Label({
				Size = UDim2.new(1, -8, 0, 60),
				Text = "No crew yet — recruit students in the Main Hallway!",
				TextColor3 = Palette.Chalk,
				Parent = list,
			})
			return
		end

		for order, defId in orderIds do
			local group = groups[defId]
			local entry = Students.Get(defId)
			if not entry then
				continue
			end
			local totalIncome = 0
			local stars, muts = 0, 0
			for _, member in group.members do
				totalIncome += Students.IncomeFor(member.id, member.mut, member.star)
				if member.star then
					stars += 1
				end
				if member.mut then
					muts += 1
				end
			end

			local frame = UIBuilder.Frame({
				Size = UDim2.new(1, -8, 0, 66),
				BackgroundColor3 = Palette.PanelBg,
				BackgroundTransparency = 0.3,
				LayoutOrder = order,
				Parent = list,
			})
			UIBuilder.Round(frame, 10)
			UIBuilder.Stroke(frame, entry.rarity.color, 2)
			UIBuilder.Label({
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -150, 0, 28),
				Text = ("%s  x%d"):format(entry.def.name, #group.members),
				TextColor3 = entry.rarity.color,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = frame,
			})
			local detail = ("$%s/s total"):format(NumberFormat.Abbreviate(totalIncome))
			if stars > 0 then
				detail ..= ("  ·  %d star"):format(stars)
			end
			if muts > 0 then
				detail ..= ("  ·  %d mutated"):format(muts)
			end
			UIBuilder.Label({
				Position = UDim2.fromOffset(12, 38),
				Size = UDim2.new(1, -150, 0, 20),
				Text = detail,
				TextColor3 = Palette.Chalk,
				TextScaled = false,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = frame,
			})
			local canFuse = group.fusable >= Students.FuseCount
			local fuse = UIBuilder.Button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(120, 44),
				Text = canFuse and "FUSE 3 → ★" or ("%d/%d"):format(math.min(group.fusable, Students.FuseCount), Students.FuseCount),
				BackgroundColor3 = canFuse and Palette.AuraPurple or Color3.fromRGB(85, 105, 79),
			}, function()
				Remotes.Get("FuseStudent"):FireServer(defId)
			end)
			UIBuilder.Round(fuse, 999)
			fuse.Parent = frame
		end
	end

	Remotes.Get("CrewState").OnClientEvent:Connect(function(crew)
		if typeof(crew) == "table" then
			render(crew :: any)
		end
	end)
	task.spawn(function()
		local crew = Remotes.GetFunction("GetCrew"):InvokeServer()
		if typeof(crew) == "table" then
			render(crew :: any)
		end
	end)
end

return CrewController
