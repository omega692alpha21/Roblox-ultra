--!strict
-- The five roles. You pick one when you first walk in, along with who you are,
-- and it decides what you are good at for the rest of the game.
--
-- This used to be four "cliques" you joined at a board in the courtyard, with
-- one perk each. It is the character class now, because a school game where
-- everyone plays identically has nothing to choose. The board is still there
-- and still lets you re-sort, for a slice of your cash -- people change.
--
-- The shape of it:
--
--   NERD     wins in the classroom and loses in the corridor
--   JOCK     the bruiser: hits hard, takes hits, average everywhere else
--   ATHLETE  fastest, longest wind, best throw -- fragile in a brawl
--   BULLY    hurts most and lasts longest, and is hopeless at lessons
--   REGULAR  average at all of it, and paid a little better for the trouble
--
-- Every number is a multiplier on the baseline (or an offset where the field
-- name says bonus), so the "average" role is a row of ones and the others read
-- as what they trade away.
--
-- The old field names are kept exactly as they were -- walkSpeedBonus,
-- knockbackMult, quizRewardMult, offlineCapBonusHours, carrySpeedMultOverride
-- -- because StealService, FightService, ClassService and RewardService all
-- read them and none of that had to change.

export type CliqueDef = {
	id: string,
	name: string,
	motto: string,
	blurb: string, -- what the pick screen says this role is for
	icon: string,
	color: Color3,

	-- movement and the chase
	walkSpeedBonus: number,
	energyMax: number,
	energyDrainMult: number, -- below 1 means you sprint for longer

	-- taking and giving out punishment
	maxHealth: number,
	damageMult: number, -- punches and thrown toys
	knockbackMult: number,
	aimAssistMult: number, -- how forgiving the throw reticle is

	-- the classroom and the wallet
	quizRewardMult: number,
	classTimeBonus: number, -- extra seconds on a lesson's clock
	cashMult: number,
	offlineCapBonusHours: number,

	carrySpeedMultOverride: number?, -- replaces GameConfig.CarrySpeedMultiplier
}

local Cliques: { CliqueDef } = {
	{
		id = "nerds",
		name = "Nerd",
		motto = "Actually, it's pronounced GIF.",
		blurb = "Top of every class. Bottom of every fight.",
		icon = "🤓",
		color = Color3.fromRGB(46, 107, 214),
		walkSpeedBonus = -1,
		energyMax = 80,
		energyDrainMult = 1.15,
		maxHealth = 85,
		damageMult = 0.8,
		knockbackMult = 0.9,
		aimAssistMult = 0.9,
		quizRewardMult = 1.75,
		classTimeBonus = 4,
		cashMult = 1,
		offlineCapBonusHours = 1,
	},
	{
		id = "jocks",
		name = "Jock",
		motto = "Touch grass? We ARE the grass.",
		blurb = "Built for contact. Hits hard, shrugs it off.",
		icon = "🏈",
		color = Color3.fromRGB(217, 67, 47),
		walkSpeedBonus = 2,
		energyMax = 110,
		energyDrainMult = 0.95,
		maxHealth = 120,
		damageMult = 1.25,
		knockbackMult = 1.25,
		aimAssistMult = 1,
		quizRewardMult = 0.9,
		classTimeBonus = 0,
		cashMult = 1,
		offlineCapBonusHours = 0,
	},
	{
		id = "athletes",
		name = "Athlete",
		motto = "You will hear the whistle. You will not catch me.",
		blurb = "Fastest legs, longest wind, best throw.",
		icon = "🏃",
		color = Color3.fromRGB(64, 176, 132),
		walkSpeedBonus = 4,
		energyMax = 150,
		energyDrainMult = 0.65,
		maxHealth = 95,
		damageMult = 1,
		knockbackMult = 1,
		aimAssistMult = 1.7,
		quizRewardMult = 1,
		classTimeBonus = 0,
		cashMult = 1,
		offlineCapBonusHours = 0,
		carrySpeedMultOverride = 0.85, -- still quick with a student over the shoulder
	},
	{
		id = "bullies",
		name = "Bully",
		motto = "Lunch money is a participation fee.",
		blurb = "Hurts the most. Lasts the longest. Learns the least.",
		icon = "😤",
		color = Color3.fromRGB(180, 75, 217),
		walkSpeedBonus = 0,
		energyMax = 95,
		energyDrainMult = 1,
		maxHealth = 145,
		damageMult = 1.5,
		knockbackMult = 1.35,
		aimAssistMult = 0.95,
		quizRewardMult = 0.7,
		classTimeBonus = -2,
		cashMult = 1,
		offlineCapBonusHours = 0,
	},
	{
		id = "regulars",
		name = "Regular",
		motto = "Just here for the lunch, honestly.",
		blurb = "Average at everything, and paid better for it.",
		icon = "🙂",
		color = Color3.fromRGB(245, 197, 49),
		walkSpeedBonus = 0,
		energyMax = 100,
		energyDrainMult = 1,
		maxHealth = 100,
		damageMult = 1,
		knockbackMult = 1,
		aimAssistMult = 1,
		quizRewardMult = 1,
		classTimeBonus = 0,
		cashMult = 1.18,
		offlineCapBonusHours = 1,
	},
}

local module = {
	List = Cliques,
	SwitchCostFraction = 0.15, -- re-sorting costs this fraction of your cash
}

function module.Get(id: string): CliqueDef?
	for _, c in Cliques do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- The role a player is actually playing, falling back to Regular so nothing
-- downstream has to keep writing "or 1".
function module.For(player: Player): CliqueDef
	local id = player:GetAttribute("Clique")
	if typeof(id) == "string" then
		local found = module.Get(id)
		if found then
			return found
		end
	end
	return Cliques[5]
end

return module
