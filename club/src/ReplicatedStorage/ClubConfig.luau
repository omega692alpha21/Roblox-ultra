--!strict
-- MILLIONS CLUB — a direct pay-for-status social club.
-- 100 memberships ever, price-laddered by batch. Tiers above membership climb
-- the pyramid, chamber by chamber, to a 1/1 capstone. Everything purchasable
-- is deterministic: no chance, no gambling mechanics, anywhere.

export type Tier = {
	name: string,
	passId: number,
	price: number, -- Robux, for display; real price lives on the pass
	robe: Color3, -- the cloth
	trim: Color3, -- the hem, and the tag color
	scale: number,
	chamber: string, -- chamber key this tier unlocks (and all below it)
}

export type SeatBatch = { from: number, to: number, passId: number, price: number }

local Config = {
	OwnerUserId = 11578479542,

	FoundingSeats = 100,

	-- membership seats, priced upward as the roster fills. Pass ids are wired
	-- in after creation via Open Cloud; 0 disables a batch.
	SeatBatches = {
		{ from = 1, to = 25, passId = 1962078432, price = 800_000 },
		{ from = 26, to = 50, passId = 1963458447, price = 1_200_000 },
		{ from = 51, to = 75, passId = 1964112424, price = 2_000_000 },
		{ from = 76, to = 100, passId = 1962648439, price = 4_000_000 },
	} :: { SeatBatch },

	-- tier ladder. GUEST and MEMBER are not sold here (guest is default,
	-- MEMBER comes from a seat); the rest are upgrade passes.
	Tiers = {
		{ name = "GUEST", passId = 0, price = 0, robe = Color3.fromRGB(88, 86, 90), trim = Color3.fromRGB(64, 62, 66), scale = 0.95, chamber = "" },
		{ name = "MEMBER", passId = 0, price = 0, robe = Color3.fromRGB(33, 31, 38), trim = Color3.fromRGB(224, 220, 232), scale = 1.0, chamber = "GrandHall" },
		{ name = "GOLD", passId = 1962120439, price = 2_000_000, robe = Color3.fromRGB(148, 112, 40), trim = Color3.fromRGB(255, 208, 110), scale = 1.02, chamber = "Gold" },
		{ name = "PLATINUM", passId = 1962030446, price = 5_000_000, robe = Color3.fromRGB(212, 216, 226), trim = Color3.fromRGB(246, 249, 255), scale = 1.05, chamber = "Platinum" },
		{ name = "BLACK", passId = 1963482428, price = 20_000_000, robe = Color3.fromRGB(12, 11, 14), trim = Color3.fromRGB(150, 120, 255), scale = 1.08, chamber = "Black" },
		{ name = "CROWN", passId = 1962798435, price = 100_000_000, robe = Color3.fromRGB(232, 190, 80), trim = Color3.fromRGB(255, 240, 180), scale = 1.14, chamber = "Crown" },
	} :: { Tier },

	-- uploaded, approved, owned by the creator
	Textures = {
		Parquet = "rbxassetid://117806376265747",
		Damask = "rbxassetid://79785225422126",
		Wainscot = "rbxassetid://95675620520590",
		Rug = "rbxassetid://78350443825536",
		Coffer = "rbxassetid://123203311167714",
		-- geometric art panels (no figures anywhere, by design)
		Geo1 = "rbxassetid://85762570200142",
		Geo2 = "rbxassetid://125084592316701",
		Geo3 = "rbxassetid://72182789931519",
	},
	Meshes = {
		Chandelier = 104671325601991,
		Wingback = 78958827728355,
		Candelabra = 113441049741419,
		Column = 139638345845432,
		Lamppost = 71751173797781,
		Gem = 137215970504108,
		Cloak = 87192563381111,
	},

	Interests = {
		"Game Development", "AI", "Fashion", "Cars", "Music", "Trading",
		"Art & Design", "Film", "Fitness", "Business", "Collecting", "Esports",
	},
	LookingFor = {
		"Co-founders", "Developers", "Creators", "Builders",
		"Collaborators", "Friends", "Mentors", "Mentees", "Event partners",
	},
}

function Config.TierIndex(name: string): number
	for i, tier in Config.Tiers do
		if tier.name == name then
			return i
		end
	end
	return 1
end

function Config.TierByName(name: string): Tier?
	for _, tier in Config.Tiers do
		if tier.name == name then
			return tier
		end
	end
	return nil
end

-- the batch the NEXT seat would come from, given the current count
function Config.ActiveBatch(count: number): SeatBatch?
	local nextSeat = count + 1
	for _, batch in Config.SeatBatches do
		if nextSeat >= batch.from and nextSeat <= batch.to then
			return batch
		end
	end
	return nil
end

return Config
