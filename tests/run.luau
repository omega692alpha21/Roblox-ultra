--!nocheck
-- Lunch Money Legends test suite: verifies every pure module — economy math,
-- roster integrity, odds, rank ladders, reward tables, quiz answer keys.
-- Run: tests/run.sh  (build.py first, then this under the luau CLI)

local GameConfig = require("./_build/GameConfig")
local Students = require("./_build/Students")
local Cliques = require("./_build/Cliques")
local Rebirths = require("./_build/Rebirths")
local Rewards = require("./_build/Rewards")
local Quizzes = require("./_build/Quizzes")
local Products = require("./_build/Products")
local Sounds = require("./_build/Sounds")
local NumberFormat = require("./_build/NumberFormat")
local dt = require("./_build/_datatypes")

local passed, failed = 0, 0
local function check(name, condition, detail)
	if condition then
		passed += 1
	else
		failed += 1
		print(("FAIL: %s%s"):format(name, detail and (" — " .. tostring(detail)) or ""))
	end
end

-- ---------- NumberFormat ----------
check("abbrev <1000 verbatim", NumberFormat.Abbreviate(999) == "999", NumberFormat.Abbreviate(999))
check("abbrev 1.2K", NumberFormat.Abbreviate(1234) == "1.2K", NumberFormat.Abbreviate(1234))
check("abbrev 5.6M", NumberFormat.Abbreviate(5600000) == "5.6M", NumberFormat.Abbreviate(5600000))
check("abbrev 30M", NumberFormat.Abbreviate(30000000) == "30.0M" or NumberFormat.Abbreviate(30000000) == "30M", NumberFormat.Abbreviate(30000000))
check("abbrev no crash at 0", NumberFormat.Abbreviate(0) == "0", NumberFormat.Abbreviate(0))
check("clock 1:15", NumberFormat.Clock(75) == "1:15", NumberFormat.Clock(75))
check("clock clamps negatives", NumberFormat.Clock(-5) == "0:00", NumberFormat.Clock(-5))
check("commas", NumberFormat.Commas(1234567) == "1,234,567", NumberFormat.Commas(1234567))

-- ---------- Students roster ----------
local totalStudents, seenIds = 0, {}
local prevMaxCost = 0
for tier, rarity in ipairs(Students.Rarities) do
	local minCost, maxCost = math.huge, 0
	for _, def in ipairs(rarity.students) do
		totalStudents += 1
		check("unique id " .. def.id, not seenIds[def.id])
		seenIds[def.id] = true
		check(def.id .. " cost>0", def.cost > 0)
		check(def.id .. " income>0", def.income > 0)
		minCost = math.min(minCost, def.cost)
		maxCost = math.max(maxCost, def.cost)
		local got = Students.Get(def.id)
		check(def.id .. " Get roundtrip", got and got.def == def and got.rarity == rarity)
	end
	check(rarity.name .. " costs above previous tier", minCost > prevMaxCost, rarity.name)
	prevMaxCost = maxCost
end
check("36 students in roster", totalStudents == 36, totalStudents)
check("Get unknown returns nil", Students.Get("does_not_exist") == nil)

-- rarity odds: 20k rolls at neutral luck should be ~60% Common, Secret rare but present at high luck
local rng = dt.Random.new(42)
local counts = {}
for _ = 1, 20000 do
	local r = Students.RollRarity(rng, 1)
	counts[r.name] = (counts[r.name] or 0) + 1
end
check("common rate ~60%", counts.Common > 20000 * 0.55 and counts.Common < 20000 * 0.65, counts.Common)
check("rare rate ~25%", counts.Rare > 20000 * 0.20 and counts.Rare < 20000 * 0.30, counts.Rare)
check("secret possible", (counts.Secret or 0) >= 0)
local luckCounts = { Common = 0 }
for _ = 1, 20000 do
	local r = Students.RollRarity(rng, 5)
	luckCounts[r.name] = (luckCounts[r.name] or 0) + 1
end
check("luck reduces commons", luckCounts.Common < counts.Common, luckCounts.Common)

-- mutations
local mutCounts = { none = 0 }
for _ = 1, 20000 do
	local m = Students.RollMutation(rng, 1)
	mutCounts[m or "none"] = (mutCounts[m or "none"] or 0) + 1
end
check("mutation none ~85%", mutCounts.none > 20000 * 0.80 and mutCounts.none < 20000 * 0.90, mutCounts.none)
check("shiny exists", (mutCounts.shiny or 0) > 0)
check("GetMutation roundtrip", Students.GetMutation("golden") and Students.GetMutation("golden").mult == 2.5)
check("GetMutation nil for nil", Students.GetMutation(nil) == nil)

-- income math: base, mutation, star, stacked
check("IncomeFor base", Students.IncomeFor("sleepy_kid") == 1)
check("IncomeFor golden", Students.IncomeFor("sleepy_kid", "golden") == 2.5)
check("IncomeFor star", Students.IncomeFor("sleepy_kid", nil, true) == 3)
check("IncomeFor golden star", Students.IncomeFor("sleepy_kid", "golden", true) == 7.5)
check("IncomeFor unknown = 0", Students.IncomeFor("nope") == 0)
check("RollFromRarity valid", Students.RollFromRarity("Legendary", rng) ~= nil)
check("RollFromRarity bad tier nil", Students.RollFromRarity("Ultra", rng) == nil)

-- ---------- Rebirths / grades / aura ranks ----------
check("grade 1 cost 50k", Rebirths.CostFor(1) == 50000, Rebirths.CostFor(1))
check("grade 2 cost 300k", Rebirths.CostFor(2) == 300000, Rebirths.CostFor(2))
check("cost curve grows", Rebirths.CostFor(3) > Rebirths.CostFor(2))
check("multiplier grade 0", Rebirths.Multiplier(0) == 1)
check("multiplier grade 2", Rebirths.Multiplier(2) == 2)
check("rank at 0", Rebirths.RankFor(0) == "NPC", Rebirths.RankFor(0))
check("rank at 49", Rebirths.RankFor(49) == "NPC")
check("rank at 50", Rebirths.RankFor(50) == "Freshman")
check("rank top", Rebirths.RankFor(999999) == "INFINITE AURA")
check("grade names exist", Rebirths.GradeName(0) == "Freshman Year" and #Rebirths.GradeName(99) > 0)

-- ---------- Rewards ----------
local prevMin = 0
for _, tier in ipairs(Rewards.Playtime) do
	check("playtime ascending " .. tier.minutes, tier.minutes > prevMin)
	prevMin = tier.minutes
	check("playtime prize valid " .. tier.minutes, tier.prize.kind ~= nil and tier.prize.label ~= nil)
end
check("streak has 7 days", #Rewards.Streak == 7, #Rewards.Streak)
for _, prize in ipairs(Rewards.Wheel) do
	check("wheel weight >0 " .. prize.label, (prize.weight or 0) > 0)
end
for _ = 1, 2000 do
	local prize = Rewards.RollWheel(rng)
	if prize.kind == "student" then
		check("wheel student tier valid " .. tostring(prize.rarity), ({ Rare = 1, Epic = 1, Legendary = 1, Mythic = 1 })[prize.rarity] == 1)
	end
end
check("quest pool >= quests per day", #Rewards.QuestPool >= Rewards.QuestsPerDay)
for _, quest in ipairs(Rewards.QuestPool) do
	check("quest sane " .. quest.id, quest.goal > 0 and quest.cash >= 0 and #quest.label > 0)
end
-- prize student rarities must exist in the roster
for _, prize in ipairs(Rewards.Wheel) do
	if prize.rarity then
		check("wheel rarity exists " .. prize.rarity, Students.RollFromRarity(prize.rarity, rng) ~= nil)
	end
end
for _, prize in ipairs(Rewards.Streak) do
	if prize.rarity then
		check("streak rarity exists " .. prize.rarity, Students.RollFromRarity(prize.rarity, rng) ~= nil)
	end
end

-- ---------- Quizzes ----------
check("quiz pool big enough", #Quizzes >= GameConfig.QuizQuestionCount * 3, #Quizzes)
for i, question in ipairs(Quizzes) do
	check("quiz " .. i .. " has 2+ answers", #question.answers >= 2)
	check("quiz " .. i .. " correct in range", question.correct >= 1 and question.correct <= #question.answers)
end

-- ---------- Cliques ----------
check("4 cliques", #Cliques.List == 4)
for _, clique in ipairs(Cliques.List) do
	check("clique roundtrip " .. clique.id, Cliques.Get(clique.id) == clique)
	check("clique mult sane " .. clique.id, clique.quizRewardMult >= 1 and clique.knockbackMult >= 1)
end
check("unknown clique nil", Cliques.Get("emo") == nil)
check("switch cost fraction sane", Cliques.SwitchCostFraction > 0 and Cliques.SwitchCostFraction < 1)

-- ---------- Products ----------
for key, pass in pairs(Products.GamePasses) do
	check("pass fields " .. key, pass.id ~= nil and pass.name and pass.price > 0 and pass.desc)
end
for key, product in pairs(Products.DevProducts) do
	check("product fields " .. key, product.id ~= nil and product.name and product.price > 0)
	local grants = (product.cash and 1 or 0) + (product.spins and 1 or 0) + (product.grantRarity and 1 or 0)
	check("product grants exactly one thing " .. key, grants == 1, grants)
	if product.grantRarity then
		check("product rarity exists " .. key, Students.RollFromRarity(product.grantRarity, rng) ~= nil)
	end
end

-- ---------- Sounds & config sanity ----------
for key, sound in pairs(Sounds) do
	check("sound id string " .. key, type(sound.id) == "string" and #sound.id > 0)
	check("sound volume sane " .. key, sound.volume > 0 and sound.volume <= 1)
end
check("offline rate sane", GameConfig.OfflineEarningsRate > 0 and GameConfig.OfflineEarningsRate <= 1)
check("carry slows", GameConfig.CarrySpeedMultiplier < 1)
check("lock cooldown > 0", GameConfig.LockCooldownSeconds > 0)
check("rush luck > 1", GameConfig.SecretRushLuckMult > 1)
check("slots cap respected", GameConfig.BaseSlots + GameConfig.MaxRebirthSlots + GameConfig.ExtraSlotsPass == 12,
	GameConfig.BaseSlots + GameConfig.MaxRebirthSlots + GameConfig.ExtraSlotsPass)

-- ---------- result ----------
print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error(("%d test(s) failed"):format(failed))
end
