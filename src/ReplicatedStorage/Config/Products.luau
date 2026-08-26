--!strict
-- ============================================================================
-- PASTE YOUR REAL IDs HERE.
-- Create these on the Creator Dashboard (Monetization tab of the experience),
-- then replace every 0 below with the numeric id. Anything left at 0 is
-- disabled in-game automatically (buttons show "SOON", grants are skipped).
-- ============================================================================

local Products = {
	-- Game passes: id = 0 disables the pass everywhere.
	GamePasses = {
		DoubleCash = { id = 0, name = "2x Lunch Money", price = 199, desc = "Doubles ALL income + doubles offline cap" },
		AutoCollect = { id = 0, name = "Auto-Collect", price = 149, desc = "Lunch money banks instantly" },
		ExtraSlots = { id = 0, name = "+2 Crew Slots", price = 249, desc = "Two extra desks in your homeroom" },
		ExtendedLock = { id = 0, name = "Extended Lock", price = 179, desc = "+30s base lock duration" },
		Speed = { id = 0, name = "Speed Sneakers", price = 99, desc = "+6 walkspeed, always" },
	},

	-- Developer products (repeatable purchases).
	-- cash amounts are multiplied by the buyer's grade multiplier at grant time.
	DevProducts = {
		CashSmall = { id = 0, name = "Small Stack", price = 49, cash = 5000 },
		CashMedium = { id = 0, name = "Backpack of Cash", price = 149, cash = 20000 },
		CashLarge = { id = 0, name = "Locker of Cash", price = 399, cash = 65000 },
		CashHuge = { id = 0, name = "Vault of Cash", price = 999, cash = 200000 },
		Spins5 = { id = 0, name = "5 Wheel Spins", price = 75, spins = 5 },
		LegendaryCrate = { id = 0, name = "Legendary Crate", price = 299, grantRarity = "Legendary" },
	},

	-- Your Roblox group id (for the join-group reward). 0 disables it.
	GroupId = 0,
}

return Products
