--!strict
-- CULT — find us, solve it, enter, rise.
-- Access is never sold. The pass below buys a patron's colors, nothing more.

export type Rank = { name: string, rep: number, hours: number, trim: Color3, unlocks: string }

local Config = {
	-- the one account with full access, the 1/1 CULT LEADER robe, and the game's own cult
	OwnerUserId = 11578479542,

	-- cosmetic only: gold thread on the robe + a name on the donor plaque
	PatronPassId = 1962348330,
	-- found your own cult: name, sigil, colors, chapter house
	CultLeaderPassId = 1963224333,
	FoundingSeats = 100,

	-- the rank ladder. Rank is earned twice over: REP and hours served.
	-- Hours are "effective": live play counts in full, time away counts half.
	Ranks = {
		{ name = "INITIATE", rep = 0, hours = 0, trim = Color3.fromRGB(96, 92, 88), unlocks = "The grounds" },
		{ name = "MEMBER", rep = 100, hours = 50, trim = Color3.fromRGB(212, 175, 85), unlocks = "The pyramid" },
		{ name = "INSIDER", rep = 300, hours = 150, trim = Color3.fromRGB(150, 36, 42), unlocks = "The private corridor" },
		{ name = "OPERATOR", rep = 750, hours = 400, trim = Color3.fromRGB(196, 202, 214), unlocks = "The undercroft" },
		{ name = "ARCHITECT", rep = 1500, hours = 800, trim = Color3.fromRGB(238, 226, 178), unlocks = "The rooftop" },
		{ name = "INNER CIRCLE", rep = 3000, hours = 1500, trim = Color3.fromRGB(255, 244, 206), unlocks = "The unmarked door" },
	} :: { Rank },

	-- founding a cult of your own also takes time served, not just the pass
	CultJoinHours = 50,

	CultSigils = { "☽", "▲", "✕", "♦", "✦", "∞", "Ω", "☿" },
	CultColors = {
		Color3.fromRGB(120, 30, 34),
		Color3.fromRGB(34, 60, 120),
		Color3.fromRGB(30, 90, 60),
		Color3.fromRGB(110, 80, 30),
		Color3.fromRGB(80, 40, 110),
		Color3.fromRGB(40, 40, 46),
	},

	Rep = {
		Initiation = 25,
		Sigil = 10,
		Convocation = 25,
		Guide = 15,
		MissionEasy = 10,
		MissionHard = 100,
	},

	-- uploaded, approved, owned by the creator
	Textures = {
		Parquet = "rbxassetid://117806376265747",
		Damask = "rbxassetid://79785225422126",
		Wainscot = "rbxassetid://95675620520590",
		Rug = "rbxassetid://78350443825536",
		Coffer = "rbxassetid://123203311167714",
		Portrait1 = "rbxassetid://126283792708725",
		Portrait2 = "rbxassetid://115757452721657",
		Portrait3 = "rbxassetid://124667483231597",
	},
	Meshes = {
		Chandelier = 104671325601991,
		Wingback = 78958827728355,
		Candelabra = 113441049741419,
		Column = 139638345845432,
		Tree = 128757271025486,
	},

	KeypadLockoutSeconds = 30,
	KeypadStrikes = 3,
	ConvocationPeriod = 20 * 60,
	ConvocationDuration = 60,

	Interests = {
		"Game Development", "AI", "Fashion", "Cars", "Music", "Trading",
		"Art & Design", "Film", "Fitness", "Business", "Collecting", "Esports",
	},
	LookingFor = {
		"Co-founders", "Developers", "Creators", "Builders",
		"Collaborators", "Friends", "Mentors", "Mentees", "Event partners",
	},
}

function Config.RankFor(rep: number, hours: number?): Rank
	local best = Config.Ranks[1]
	local h = hours or math.huge
	for _, rank in Config.Ranks do
		if rep >= rank.rep and h >= rank.hours then
			best = rank
		end
	end
	return best
end

function Config.RankIndex(name: string): number
	for i, rank in Config.Ranks do
		if rank.name == name then
			return i
		end
	end
	return 0
end

return Config
