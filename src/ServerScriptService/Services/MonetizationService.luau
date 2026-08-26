--!strict
-- Game pass cache (exposed as player attributes) + idempotent ProcessReceipt.
-- Every id ships as 0 in Config/Products; anything still 0 is skipped safely.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Config.Products)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local Students = require(ReplicatedStorage.Config.Students)

local MonetizationService = {}

local PASS_ATTRIBUTES: { [string]: string } = {
	DoubleCash = "Pass2x",
	AutoCollect = "PassAutoCollect",
	ExtraSlots = "PassSlots",
	ExtendedLock = "PassLock",
	Speed = "PassSpeed",
}

local rng = Random.new()

local function refreshPasses(player: Player)
	for key, attribute in PASS_ATTRIBUTES do
		local pass = (Products.GamePasses :: any)[key]
		if pass and pass.id ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
				end)
				if ok and owns then
					player:SetAttribute(attribute, true)
					if key == "Speed" then
						StealService.RefreshWalkSpeed(player)
					end
				end
			end)
		end
	end
end

local function grantProduct(player: Player, productKey: string): boolean
	local product = (Products.DevProducts :: any)[productKey]
	local profile = DataService.Get(player)
	if not product or not profile then
		return false
	end
	if product.cash then
		local mult = EconomyService.Multiplier(player)
		local amount = math.floor(product.cash * mult)
		EconomyService.AddCash(player, amount, false)
		Remotes.Get("Notify"):FireClient(player, "+$" .. NumberFormat.Abbreviate(amount) .. " lunch money!", "good")
	elseif product.spins then
		profile.spinTokens += product.spins
		Remotes.Get("Notify"):FireClient(player, "+" .. product.spins .. " wheel spins!", "good")
	elseif product.grantRarity then
		local def = Students.RollFromRarity(product.grantRarity, rng)
		if def then
			if PlotService.CrewCount(player) < PlotService.MaxSlots(player) then
				PlotService.AddStudent(player, def.id)
				Remotes.Get("Notify"):FireClient(player, product.grantRarity:upper() .. " " .. def.name .. " joined your crew!", "aura")
			else
				-- full crew: refund as cash at half the student's price
				EconomyService.AddCash(player, math.floor(def.cost / 2), false)
				Remotes.Get("Notify"):FireClient(player, "Crew full — converted to $" .. NumberFormat.Abbreviate(def.cost / 2), "info")
			end
		end
	end
	return true
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not DataService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if DataService.HasPurchase(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- find which product this is
	local matchedKey: string? = nil
	for key, product in Products.DevProducts :: any do
		if product.id ~= 0 and product.id == receiptInfo.ProductId then
			matchedKey = key
			break
		end
	end
	if not matchedKey then
		warn("[Monetization] receipt for unknown product id " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grantProduct(player, matchedKey) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.RecordPurchase(player, purchaseId)
	-- the purchase must survive a crash: save before telling Roblox it's granted
	if not DataService.ForceSave(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	Players.PlayerAdded:Connect(refreshPasses)
	for _, player in Players:GetPlayers() do
		refreshPasses(player)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if purchased then
			refreshPasses(player)
			Remotes.Get("Notify"):FireClient(player, "Game pass activated. W purchase.", "aura")
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
