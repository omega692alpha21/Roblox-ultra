--!strict
-- MILLIONS CLUB — a direct pay-for-status social club.
-- 100 memberships ever, price-laddered by batch. Tiers above membership climb
-- the pyramid, chamber by chamber, to a 1/1 capstone. Everything purchasable
-- is deterministic: no chance, no gambling mechanics, anywhere.

export type Tier = {
	name: string,
	passId: number,
	price: number, -- Robux, for display; real price lives on the pass
	gem: Color3,
	glow: Color3,
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
		{ name = "GUEST", passId = 0, price = 0, gem = Color3.fromRGB(126, 132, 140), glow = Color3.fromRGB(150, 158, 170), scale = 0.85, chamber = "" },
		{ name = "MEMBER", passId = 0, price = 0, gem = Color3.fromRGB(214, 228, 238), glow = Color3.fromRGB(210, 230, 255), scale = 1.0, chamber = "GrandHall" },
		{ name = "GOLD", passId = 1962120439, price = 2_000_000, gem = Color3.fromRGB(230, 180, 60), glow = Color3.fromRGB(255, 206, 100), scale = 1.1, chamber = "Gold" },
		{ name = "PLATINUM", passId = 1962030446, price = 5_000_000, gem = Color3.fromRGB(226, 230, 236), glow = Color3.fromRGB(240, 245, 255), scale = 1.2, chamber = "Platinum" },
		{ name = "BLACK", passId = 1963482428, price = 20_000_000, gem = Color3.fromRGB(24, 22, 28), glow = Color3.fromRGB(150, 120, 255), scale = 1.3, chamber = "Black" },
		{ name = "CROWN", passId = 1962798435, price = 100_000_000, gem = Color3.fromRGB(255, 200, 60), glow = Color3.fromRGB(255, 220, 120), scale = 1.6, chamber = "Crown" },
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
