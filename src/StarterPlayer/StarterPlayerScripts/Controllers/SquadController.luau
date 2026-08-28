--!strict
-- Crews of real people: the invite card and the left-edge roster strip.
--
-- Two pieces of UI, because a crew has two moments. The first is being asked
-- — a card that has to be answered, in front of everything, with the clock
-- visibly running out so nobody sits on an invite. The second is the rest of
-- the session: a small strip down the left edge naming who is with you and
-- greying out anyone who has wandered off, because the earn bonus is paid on
-- proximity and a bonus you cannot see is a bonus nobody chases.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local player = Players.LocalPlayer

local SquadController = {}

type Row = { name: string, userId: number, clique: string, color: Color3 }

local NEARBY = 70 -- must match SquadService.NEARBY

local rows: { Row } = {}
local strip: Frame
local stripRows: { [number]: { frame: Frame, dot: Frame, label: TextLabel } } = {}

local function rootOf(target: Player): BasePart?
	local character = target.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- ---------------- the roster strip ----------------

local function renderStrip()
	for _, child in strip:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	table.clear(stripRows)
	strip.Visible = #rows > 1
	if #rows <= 1 then
		return
	end

	local header = UIBuilder.Frame({
		Size = UDim2.fromScale(1, 0.14),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = strip,
	})
	UIBuilder.Label({
		Size = UDim2.fromScale(0.7, 1),
		Text = ("CREW  %d"):format(#rows),
		TextColor3 = Palette.BusYellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	-- a crew you cannot leave is a trap, not a crew
	local quit = UIBuilder.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(0.26, 0.86),
		Text = "LEAVE",
		BackgroundColor3 = Palette.DetentionRed,
	}, function()
		Remotes.Get("LeaveCrew"):FireServer()
	end)
	UIBuilder.Round(quit, 6)
	quit.Parent = header

	for index, row in rows do
		local frame = UIBuilder.Frame({
			Size = UDim2.fromScale(1, 0.14),
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.25,
			LayoutOrder = index,
			Parent = strip,
		})
		UIBuilder.Round(frame, 6)

		local dot = UIBuilder.Frame({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromScale(0.09, 0.5),
			BackgroundColor3 = row.color,
			Parent = frame,
		})
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1
		ratio.Parent = dot
		UIBuilder.Round(dot, 99)

		local label = UIBuilder.Label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromScale(0.76, 0.7),
			Text = row.userId == player.UserId and "YOU" or row.name,
			TextColor3 = Palette.White,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})

		stripRows[row.userId] = { frame = frame, dot = dot, label = label }
	end
end

-- Grey out anyone out of bonus range. This is the whole reason the strip is
-- on screen rather than in a menu.
local function refreshProximity()
	local myRoot = rootOf(player)
	for userId, entry in stripRows do
		local near = userId == player.UserId
		if not near and myRoot then
			local other = Players:GetPlayerByUserId(userId)
			local otherRoot = other and rootOf(other)
			near = otherRoot ~= nil
				and (otherRoot.Position - myRoot.Position).Magnitude <= NEARBY
		end
		entry.label.TextTransparency = near and 0 or 0.55
		entry.dot.BackgroundTransparency = near and 0 or 0.6
		entry.frame.BackgroundTransparency = near and 0.25 or 0.6
	end
end

-- ---------------- the invite card ----------------

local card: Frame
local cardName: TextLabel
local cardSub: TextLabel
local cardTimer: Frame
local cardOpenUntil = 0
local cardSeconds = 1

local function closeCard()
	cardOpenUntil = 0
	card.Visible = false
end

local function answer(accept: boolean)
	if not card.Visible then
		return
	end
	closeCard()
	Remotes.Get("CrewInviteAnswer"):FireServer(accept)
end

local function openCard(invite: {
	name: string,
	userId: number,
	clique: string,
	color: Color3,
	friend: boolean,
	seconds: number,
})
	cardName.Text = invite.name
	cardSub.Text = ("%s  ·  %s wants you in their crew"):format(
		invite.clique:upper(),
		invite.friend and "FRIEND" or "STRANGER"
	)
	cardSub.TextColor3 = invite.friend and Palette.CashGreen or Palette.Chalk
	cardTimer.BackgroundColor3 = invite.color
	cardTimer.Size = UDim2.fromScale(1, 1)
	cardSeconds = math.max(invite.seconds, 1)
	cardOpenUntil = os.clock() + cardSeconds
	card.Visible = true
	card.Size = UDim2.fromScale(0.40, 0.16)
	TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
		Size = UDim2.fromScale(0.46, 0.19),
	}):Play()
end

function SquadController.Init(gui: ScreenGui)
	-- the strip rides on the main HUD gui
	strip = UIBuilder.Frame({
		Name = "CrewStrip",
		Position = UDim2.fromScale(Layout.SquadX, Layout.SquadY),
		Size = UDim2.fromScale(Layout.SquadW, Layout.SquadH),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = strip

	-- the invite card gets its own ScreenGui: it has to be answerable even
	-- with a panel open, so it sits above panels (20) and under dialogue (60)
	local inviteGui = Instance.new("ScreenGui")
	inviteGui.Name = "LMLCrewInvite"
	inviteGui.ResetOnSpawn = false
	inviteGui.IgnoreGuiInset = false
	inviteGui.DisplayOrder = 55
	inviteGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	inviteGui.Parent = gui.Parent

	card = UIBuilder.Frame({
		Name = "InviteCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.46, 0.19),
		BackgroundColor3 = Palette.PanelBg,
		Visible = false,
		Parent = inviteGui,
	})
	UIBuilder.Round(card, 12)
	UIBuilder.Stroke(card, Palette.BusYellow, 3)
	UIBuilder.Sheen(card)

	cardName = UIBuilder.Label({
		Position = UDim2.fromScale(0.05, 0.06),
		Size = UDim2.fromScale(0.9, 0.26),
		Text = "",
		TextColor3 = Palette.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	cardSub = UIBuilder.Label({
		Position = UDim2.fromScale(0.05, 0.34),
		Size = UDim2.fromScale(0.9, 0.16),
		Text = "",
		TextColor3 = Palette.Chalk,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	local timerTrack = UIBuilder.Frame({
		Position = UDim2.fromScale(0.05, 0.53),
		Size = UDim2.fromScale(0.9, 0.035),
		BackgroundColor3 = Palette.Blackboard,
		Parent = card,
	})
	UIBuilder.Round(timerTrack, 99)
	cardTimer = UIBuilder.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.BusYellow,
		Parent = timerTrack,
	})
	UIBuilder.Round(cardTimer, 99)

	local yes = UIBuilder.Button({
		Position = UDim2.fromScale(0.05, 0.63),
		Size = UDim2.fromScale(0.43, 0.29),
		Text = "RUN WITH THEM",
		BackgroundColor3 = Palette.CashGreen,
	}, function()
		answer(true)
	end)
	UIBuilder.Round(yes, 10)
	yes.Parent = card

	local no = UIBuilder.Button({
		Position = UDim2.fromScale(0.52, 0.63),
		Size = UDim2.fromScale(0.43, 0.29),
		Text = "NO THANKS",
		BackgroundColor3 = Palette.DetentionRed,
	}, function()
		answer(false)
	end)
	UIBuilder.Round(no, 10)
	no.Parent = card

	-- The invite prompt is parented to every player's root, your own
	-- included, and Roblox shows you a prompt on your own character. Disabled
	-- locally: the server never sees it, and you stop being offered a crew
	-- with yourself every time you stand still.
	local function muteOwnPrompt(character: Model)
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", 10)
			local prompt = root and root:WaitForChild("CrewInvitePrompt", 10)
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = false
			end
		end)
	end
	if player.Character then
		muteOwnPrompt(player.Character)
	end
	player.CharacterAdded:Connect(muteOwnPrompt)

	Remotes.Get("CrewInvite").OnClientEvent:Connect(function(invite)
		if typeof(invite) == "table" then
			openCard(invite)
		end
	end)

	Remotes.Get("SquadState").OnClientEvent:Connect(function(list)
		rows = typeof(list) == "table" and list or {}
		renderStrip()
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		if cardOpenUntil > 0 then
			local left = cardOpenUntil - os.clock()
			if left <= 0 then
				closeCard()
			else
				cardTimer.Size = UDim2.fromScale(left / cardSeconds, 1)
			end
		end
		accumulator += dt
		if accumulator >= 0.35 then
			accumulator = 0
			if strip.Visible then
				refreshProximity()
			end
		end
	end)
end

return SquadController
