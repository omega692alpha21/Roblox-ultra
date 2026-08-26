--!strict
-- Grade (rebirth) progression: cost curve, income multiplier, aura ranks.

local Rebirths = {
	BaseCost = 50000,
	CostGrowth = 6, -- cost = BaseCost * CostGrowth^grade
	MultiplierPerGrade = 0.5, -- income multiplier = 1 + grade * this

	GradeNames = {
		[0] = "Freshman Year",
		[1] = "Sophomore Year",
		[2] = "Junior Year",
		[3] = "Senior Year",
		[4] = "Super Senior",
		[5] = "Victory Lap",
	}, -- grades past the table just show "Year N"

	-- Aura rank ladder: title shown over the player's head.
	Ranks = {
		{ aura = 0, title = "NPC" },
		{ aura = 50, title = "Freshman" },
		{ aura = 150, title = "Sophomore" },
		{ aura = 400, title = "Junior" },
		{ aura = 1000, title = "Senior" },
		{ aura = 2500, title = "Hall Legend" },
		{ aura = 6000, title = "School Legend" },
		{ aura = 15000, title = "INFINITE AURA" },
	},
}

function Rebirths.CostFor(nextGrade: number): number
	return Rebirths.BaseCost * Rebirths.CostGrowth ^ (nextGrade - 1)
end

function Rebirths.Multiplier(grade: number): number
	return 1 + grade * Rebirths.MultiplierPerGrade
end

function Rebirths.RankFor(aura: number): string
	local title = Rebirths.Ranks[1].title
	for _, rank in Rebirths.Ranks do
		if aura >= rank.aura then
			title = rank.title
		end
	end
	return title
end

function Rebirths.GradeName(grade: number): string
	return Rebirths.GradeNames[grade] or ("Year " .. tostring(grade + 1))
end

return Rebirths
