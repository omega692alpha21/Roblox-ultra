--!strict
-- Retention systems: playtime chests, daily streak, spin wheel, quests, offline earnings.
-- Cash rewards are multiplied by the player's grade multiplier at grant time.

export type Prize = {
	kind: "cash" | "luck" | "spin" | "student",
	amount: number?, -- cash amount / luck duration seconds / spin count
	luckMult: number?,
	rarity: string?, -- for kind == "student"
	label: string,
	weight: number?, -- for wheel prizes
}

local Rewards = {}

-- Playtime chest track (per session). minutes -> prize
Rewards.Playtime = {
	{ minutes = 5, prize = { kind = "cash", amount = 1000, label = "$1K Lunch Money" } :: Prize },
	{ minutes = 10, prize = { kind = "cash", amount = 2500, label = "$2.5K Lunch Money" } :: Prize },
	{ minutes = 20, prize = { kind = "luck", amount = 600, luckMult = 1.5, label = "Luck Boost (10 min)" } :: Prize },
	{ minutes = 30, prize = { kind = "cash", amount = 10000, label = "$10K Lunch Money" } :: Prize },
	{ minutes = 45, prize = { kind = "spin", amount = 1, label = "Free Wheel Spin" } :: Prize },
	{ minutes = 60, prize = { kind = "student", rarity = "Epic", label = "Guaranteed EPIC Student" } :: Prize },
}

-- Daily streak (7-day cycle)
Rewards.Streak = {
	{ kind = "cash", amount = 1000, label = "$1K Lunch Money" } :: Prize,
	{ kind = "cash", amount = 2500, label = "$2.5K Lunch Money" } :: Prize,
	{ kind = "cash", amount = 5000, label = "$5K Lunch Money" } :: Prize,
	{ kind = "spin", amount = 1, label = "Free Wheel Spin" } :: Prize,
	{ kind = "cash", amount = 15000, label = "$15K Lunch Money" } :: Prize,
	{ kind = "luck", amount = 1800, luckMult = 1.5, label = "Luck Boost (30 min)" } :: Prize,
	{ kind = "student", rarity = "Legendary", label = "Guaranteed LEGENDARY Student" } :: Prize,
}

-- Spin wheel prizes (weighted)
Rewards.Wheel = {
	{ kind = "cash", amount = 2000, label = "$2K", weight = 40 } :: Prize,
	{ kind = "cash", amount = 5000, label = "$5K", weight = 25 } :: Prize,
	{ kind = "luck", amount = 600, luckMult = 1.5, label = "Luck 10m", weight = 15 } :: Prize,
	{ kind = "cash", amount = 15000, label = "$15K", weight = 10 } :: Prize,
	{ kind = "student", rarity = "Rare", label = "RARE Student", weight = 6 } :: Prize,
	{ kind = "student", rarity = "Epic", label = "EPIC Student", weight = 3 } :: Prize,
	{ kind = "student", rarity = "Legendary", label = "LEGENDARY Student", weight = 0.9 } :: Prize,
	{ kind = "student", rarity = "Mythic", label = "MYTHIC Student", weight = 0.1 } :: Prize,
}

-- Daily quest pool. Progress signals are wired in QuestService.
Rewards.QuestPool = {
	{ id = "recruit5", label = "Recruit 5 students", stat = "recruit", goal = 5, cash = 3000, aura = 10 },
	{ id = "steal1", label = "Steal 1 student", stat = "steal", goal = 1, cash = 5000, aura = 20 },
	{ id = "quiz1", label = "Pass 1 pop quiz", stat = "quiz", goal = 1, cash = 4000, aura = 15 },
	{ id = "earn25k", label = "Earn $25K lunch money", stat = "earn", goal = 25000, cash = 5000, aura = 10 },
	{ id = "punch3", label = "Punch 3 thieves", stat = "thiefhit", goal = 3, cash = 4000, aura = 15 },
	{ id = "collect10", label = "Collect your pile 10 times", stat = "collect", goal = 10, cash = 3000, aura = 10 },
	{ id = "aura50", label = "Farm 50 aura", stat = "aura", goal = 50, cash = 6000, aura = 0 },
}
Rewards.QuestsPerDay = 3
Rewards.QuestAllBonusSpins = 1

-- Social rewards
Rewards.GroupJoinCash = 5000
Rewards.FriendIncomeBonus = 0.05 -- per friend in server
Rewards.FriendIncomeBonusCap = 0.25

-- Weighted wheel roll
function Rewards.RollWheel(rng: Random): Prize
	local total = 0
	for _, p in Rewards.Wheel do
		total += p.weight :: number
	end
	local pick = rng:NextNumber() * total
	for _, p in Rewards.Wheel do
		pick -= p.weight :: number
		if pick <= 0 then
			return p
		end
	end
	return Rewards.Wheel[1]
end

return Rewards
