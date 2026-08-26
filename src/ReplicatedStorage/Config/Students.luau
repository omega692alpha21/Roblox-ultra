--!strict
-- The full collectible roster. Weights are relative spawn odds on the hallway conveyor.
-- Luck buffs multiply the weight of every rarity above Common.

export type StudentDef = {
	id: string,
	name: string,
	cost: number,
	income: number,
}

export type Rarity = {
	name: string,
	weight: number,
	color: Color3,
	students: { StudentDef },
}

local Rarities: { Rarity } = {
	{
		name = "Common",
		weight = 60,
		color = Color3.fromRGB(158, 158, 158),
		students = {
			{ id = "sleepy_kid", name = "Sleepy Kid", cost = 25, income = 1 },
			{ id = "gum_chewer", name = "Gum Chewer", cost = 40, income = 1 },
			{ id = "juice_box_kid", name = "Juice Box Kid", cost = 60, income = 2 },
			{ id = "pencil_borrower", name = "Pencil Borrower", cost = 85, income = 2 },
			{ id = "hall_wanderer", name = "Hall Wanderer", cost = 110, income = 3 },
			{ id = "homework_forgetter", name = "Homework Forgetter", cost = 150, income = 4 },
		},
	},
	{
		name = "Rare",
		weight = 25,
		color = Color3.fromRGB(75, 139, 217),
		students = {
			{ id = "class_clown", name = "Class Clown", cost = 600, income = 8 },
			{ id = "locker_lurker", name = "Locker Lurker", cost = 900, income = 11 },
			{ id = "hall_monitor", name = "Hall Monitor", cost = 1200, income = 14 },
			{ id = "teachers_pet", name = "Teacher's Pet", cost = 1600, income = 18 },
			{ id = "cafeteria_insider", name = "Cafeteria Insider", cost = 2000, income = 21 },
			{ id = "gum_dealer", name = "Gum Dealer", cost = 2500, income = 25 },
		},
	},
	{
		name = "Epic",
		weight = 10,
		color = Color3.fromRGB(180, 75, 217),
		students = {
			{ id = "group_project_carrier", name = "Group Project Carrier", cost = 6000, income = 60 },
			{ id = "detention_veteran", name = "Detention Veteran", cost = 9000, income = 80 },
			{ id = "mixtape_kid", name = "Mixtape Kid", cost = 12500, income = 105 },
			{ id = "science_fair_champ", name = "Science Fair Champ", cost = 16000, income = 130 },
			{ id = "vending_whisperer", name = "Vending Machine Whisperer", cost = 20000, income = 155 },
			{ id = "sweaty_tryhard", name = "Sweaty Tryhard", cost = 25000, income = 180 },
		},
	},
	{
		name = "Legendary",
		weight = 4,
		color = Color3.fromRGB(240, 138, 42),
		students = {
			{ id = "yearbook_editor", name = "Yearbook Editor", cost = 60000, income = 450 },
			{ id = "transfer_student", name = "The Transfer Student", cost = 100000, income = 650 },
			{ id = "prom_royalty", name = "Prom Royalty", cost = 150000, income = 850 },
			{ id = "gym_class_legend", name = "Gym Class Legend", cost = 200000, income = 1050 },
			{ id = "snack_kingpin", name = "Snack Kingpin", cost = 250000, income = 1250 },
			{ id = "valedictorian", name = "The Valedictorian", cost = 300000, income = 1400 },
		},
	},
	{
		name = "Mythic",
		weight = 0.9,
		color = Color3.fromRGB(217, 67, 47),
		students = {
			{ id = "principals_kid", name = "The Principal's Kid", cost = 1200000, income = 6000 },
			{ id = "dodgeball_god", name = "Dodgeball God", cost = 2000000, income = 8500 },
			{ id = "lunch_lady_supreme", name = "Lunch Lady Supreme", cost = 3000000, income = 11000 },
			{ id = "exchange_student", name = "The Exchange Student From Nowhere", cost = 4500000, income = 14500 },
			{ id = "the_janitor", name = "The Janitor (Knows Everything)", cost = 6000000, income = 18000 },
		},
	},
	{
		name = "Secret",
		weight = 0.1,
		color = Color3.fromRGB(245, 197, 49),
		students = {
			{ id = "substitute_who_stayed", name = "The Substitute Who Stayed", cost = 15000000, income = 45000 },
			{ id = "school_legend", name = "The School Legend", cost = 30000000, income = 90000 },
		},
	},
}

local Students = {
	Rarities = Rarities,
}

local byId: { [string]: { def: StudentDef, rarity: Rarity } } = {}
for _, rarity in Rarities do
	for _, def in rarity.students do
		byId[def.id] = { def = def, rarity = rarity }
	end
end

-- Look up a student definition and its rarity by id. Returns nil for unknown ids
-- (e.g. a student removed from the config after players saved one).
function Students.Get(id: string): ({ def: StudentDef, rarity: Rarity }?)
	return byId[id]
end

-- Weighted rarity roll. luckMult multiplies the weight of everything above Common.
function Students.RollRarity(rng: Random, luckMult: number): Rarity
	local total = 0
	local weights = table.create(#Rarities)
	for i, rarity in Rarities do
		local w = rarity.weight * (i > 1 and luckMult or 1)
		weights[i] = w
		total += w
	end
	local pick = rng:NextNumber() * total
	for i, rarity in Rarities do
		pick -= weights[i]
		if pick <= 0 then
			return rarity
		end
	end
	return Rarities[1]
end

function Students.RollFromRarity(rarityName: string, rng: Random): StudentDef?
	for _, rarity in Rarities do
		if rarity.name == rarityName then
			return rarity.students[rng:NextInteger(1, #rarity.students)]
		end
	end
	return nil
end

return Students
