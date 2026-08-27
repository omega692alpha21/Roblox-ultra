--!strict
-- CULT — find us, solve it, enter, rise.
-- Access is never sold. The pass below buys a patron's colors, nothing more.

export type Rank = { name: string, rep: number, trim: Color3, unlocks: string }

local Config = {
	-- cosmetic only: gold thread on the robe + a name on the donor plaque
	PatronPassId = 1962348330,
	FoundingSeats = 100,

	-- the rank ladder. Rank is earned; it is the only status that exists here.
	Ranks = {
		{ name = "INITIATE", rep = 0, trim = Color3.fromRGB(96, 92, 88), unlocks = "The hall" },
		{ name = "MEMBER", rep = 100, trim = Color3.fromRGB(212, 175, 85), unlocks = "Convocations and the board" },
		{ name = "INSIDER", rep = 300, trim = Color3.fromRGB(150, 36, 42), unlocks = "The private corridor" },
		{ name = "OPERATOR", rep = 750, trim = Color3.fromRGB(196, 202, 214), unlocks = "The undercroft" },
		{ name = "ARCHITECT", rep = 1500, trim = Color3.fromRGB(238, 226, 178), unlocks = "The rooftop" },
		{ name = "INNER CIRCLE", rep = 3000, trim = Color3.fromRGB(255, 244, 206), unlocks = "The unmarked door" },
	} :: { Rank },

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

function Config.RankFor(rep: number): Rank
	local best = Config.Ranks[1]
	for _, rank in Config.Ranks do
		if rep >= rank.rep then
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
