--!strict
-- The Principal's Office: game passes + cash packs. Buttons prompt real purchases
-- when ids are configured; anything still id=0 shows as SOON and does nothing.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Products = require(ReplicatedStorage.Config.Products)
local UIBuilder = require(script.Parent.UIBuilder)

local StoreController = {}

local player = Players.LocalPlayer

local function row(parent: Instance, order: number, title: string, desc: string, price: number, enabled: boolean, onBuy: () -> ())
	local frame = UIBuilder.Frame({
		Size = UDim2.new(1, -8, 0, 62),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.3,
		LayoutOrder = order,
		Parent = parent,
	})
	UIBuilder.Round(frame, 10)
	UIBuilder.Stroke(frame, enabled and Palette.CashGreen or Color3.fromRGB(85, 105, 79), 2)
	UIBuilder.Label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -140, 0, 28),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	UIBuilder.Label({
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -140, 0, 22),
		Text = desc,
		TextColor3 = Palette.Chalk,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 14,
		Parent = frame,
	})
	local buy = UIBuilder.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(110, 40),
		Text = enabled and ("R$ " .. price) or "SOON",
		BackgroundColor3 = enabled and Palette.BusYellow or Color3.fromRGB(85, 105, 79),
		TextColor3 = enabled and Palette.Blackboard or Palette.Chalk,
	}, function()
		if enabled then
			onBuy()
		end
	end)
	UIBuilder.Round(buy, 999)
	buy.Parent = frame
end

function StoreController.Init(gui: ScreenGui)
	local _, content = UIBuilder.Panel(gui, "Store", "PRINCIPAL'S OFFICE — THE STORE")
	local list = UIBuilder.List(content)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	for _, key in { "DoubleCash", "AutoCollect", "ExtraSlots", "ExtendedLock", "Speed" } do
		local pass = (Products.GamePasses :: any)[key]
		row(list, nextOrder(), pass.name, pass.desc, pass.price, pass.id ~= 0, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
	end

	UIBuilder.Label({
		Size = UDim2.new(1, -8, 0, 30),
		Text = "COSMETICS — PURE FLEX, ZERO GAMEPLAY EFFECT",
		TextColor3 = Palette.AuraPurple,
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	for _, key in { "GoldenHalo", "CashCrown", "AuraRing", "LegendCape" } do
		local pass = (Products.GamePasses :: any)[key]
		row(list, nextOrder(), pass.name, pass.desc, pass.price, pass.id ~= 0, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
	end

	for _, key in { "LegendaryCrate", "CashSmall", "CashMedium", "CashLarge", "CashHuge", "Spins5" } do
		local product = (Products.DevProducts :: any)[key]
		local desc = if product.cash
			then "$" .. tostring(product.cash) .. " x your grade multiplier"
			elseif product.spins then tostring(product.spins) .. " spins for the cafeteria wheel"
			else "guaranteed random " .. tostring(product.grantRarity) .. " student"
		row(list, nextOrder(), product.name, desc, product.price, product.id ~= 0, function()
			MarketplaceService:PromptProductPurchase(player, product.id)
		end)
	end
end

return StoreController
