--!strict
-- ============================================================================
-- LIVE product ids (created via Open Cloud on 2026-08-26). GroupId stays 0
-- until a group exists. Anything set to 0 is disabled in-game automatically.
-- ============================================================================

local Products = {
	-- Game passes: id = 0 disables the pass everywhere.
	GamePasses = {
		DoubleCash = { id = 1962822277, name = "2x Lunch Money", price = 199, desc = "Doubles ALL income + doubles offline cap" },
		AutoCollect = { id = 1962942271, name = "Auto-Collect", price = 149, desc = "Lunch money banks instantly" },
		ExtraSlots = { id = 1963374270, name = "+2 Crew Slots", price = 249, desc = "Two extra desks in your homeroom" },
		ExtendedLock = { id = 1962906271, name = "Extended Lock", price = 179, desc = "+30s base lock duration" },
		Speed = { id = 1961970283, name = "Speed Sneakers", price = 99, desc = "+6 walkspeed, always" },
		JailPass = { id = 1965384440, name = "Get Out of Detention", price = 149, desc = "Walk out of any detention sentence instantly" },

		-- Cosmetic-only passes: zero gameplay effect, pure flex. This is where
		-- the top-grossing Roblox games actually make their money.
		GoldenHalo = { id = 1963818558, name = "Golden Halo", price = 129, desc = "A glowing halo that follows you everywhere" },
		CashCrown = { id = 1965726324, name = "Cash Crown", price = 149, desc = "A sparkling crown — you ARE the bounty" },
		AuraRing = { id = 1962102540, name = "Aura Ring", price = 99, desc = "A swirling particle ring around your feet" },
		LegendCape = { id = 1962366531, name = "Legend Cape", price = 179, desc = "A billowing cape for certified legends" },
	},

	-- Developer products (repeatable purchases).
	-- cash amounts are multiplied by the buyer's grade multiplier at grant time.
	DevProducts = {
		HallPasses = { id = 3710112263, name = "3 Hall Passes", price = 75, hallPasses = 3 },
		CashSmall = { id = 3709990881, name = "Small Stack", price = 49, cash = 5000 },
		CashMedium = { id = 3709990901, name = "Backpack of Cash", price = 149, cash = 20000 },
		CashLarge = { id = 3709990905, name = "Locker of Cash", price = 399, cash = 65000 },
		CashHuge = { id = 3709990909, name = "Vault of Cash", price = 999, cash = 200000 },
		Spins5 = { id = 3709990912, name = "5 Wheel Spins", price = 75, spins = 5 },
		LegendaryCrate = { id = 3709990915, name = "Legendary Crate", price = 299, grantRarity = "Legendary" },
	},

	-- Your Roblox group id (for the join-group reward). 0 disables it.
	GroupId = 0,
}

return Products
