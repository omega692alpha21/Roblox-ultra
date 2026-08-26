--!strict
-- The four cliques and their perks. Perk values are read by the services that apply them.

export type CliqueDef = {
	id: string,
	name: string,
	motto: string,
	color: Color3,
	-- perks (defaults apply when 0/1)
	walkSpeedBonus: number,
	knockbackMult: number,
	quizRewardMult: number,
	offlineCapBonusHours: number,
	carrySpeedMultOverride: number?, -- replaces GameConfig.CarrySpeedMultiplier
}

local Cliques: { CliqueDef } = {
	{
		id = "jocks",
		name = "Jocks",
		motto = "Touch grass? We ARE the grass.",
		color = Color3.fromRGB(217, 67, 47),
		walkSpeedBonus = 2,
		knockbackMult = 1.1,
		quizRewardMult = 1,
		offlineCapBonusHours = 0,
	},
	{
		id = "nerds",
		name = "Nerds",
		motto = "Actually, it's pronounced GIF.",
		color = Color3.fromRGB(46, 107, 214),
		walkSpeedBonus = 0,
		knockbackMult = 1,
		quizRewardMult = 1.5,
		offlineCapBonusHours = 0,
	},
	{
		id = "preps",
		name = "Preps",
		motto = "Old money. Well, old lunch money.",
		color = Color3.fromRGB(245, 197, 49),
		walkSpeedBonus = 0,
		knockbackMult = 1,
		quizRewardMult = 1,
		offlineCapBonusHours = 1,
	},
	{
		id = "rebels",
		name = "Rebels",
		motto = "Rules are more of a vibe anyway.",
		color = Color3.fromRGB(180, 75, 217),
		walkSpeedBonus = 0,
		knockbackMult = 1,
		quizRewardMult = 1,
		offlineCapBonusHours = 0,
		carrySpeedMultOverride = 0.75,
	},
}

local module = {
	List = Cliques,
	SwitchCostFraction = 0.1, -- switching cliques costs this fraction of current cash
}

function module.Get(id: string): CliqueDef?
	for _, c in Cliques do
		if c.id == id then
			return c
		end
	end
	return nil
end

return module
