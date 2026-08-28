--!strict
-- THE CRUMBWORTH FILES — the reason any of this is happening.
--
-- The game had loops and no spine: you earned, you graduated, you earned
-- again, and nothing ever told you why. This is the why, in five chapters,
-- each one gated behind a school year so the story and the progression are the
-- same ladder rather than two ladders side by side.
--
-- Every objective is counted off a signal the game already fires, so the story
-- reads what you were doing anyway. Nothing here asks you to go and do a
-- special story activity; it notices.

export type Objective = {
	id: string,
	label: string,
	stat: string, -- a counter StoryService keeps, or a profile value
	goal: number,
	kind: string?, -- "count" (default) or "reach"
}

export type Chapter = {
	id: string,
	number: number,
	title: string,
	speaker: string,
	grade: number, -- the school year it opens in
	hook: { string }, -- said when the chapter opens
	reveal: { string }, -- said when it closes
	objectives: { Objective },
	cash: number,
	aura: number,
	unlock: string?, -- one line naming what it opened up
}

local Story = {}

Story.Chapters = {
	{
		id = "firstbell",
		number = 1,
		title = "FIRST BELL",
		speaker = "Principal Crumb",
		grade = 0,
		hook = {
			"Welcome to Crumbworth. Sit down, don't touch anything.",
			"Here's the situation. This school is broke. Not 'tighten the belt' broke — 'the vending machine is a cardboard box' broke.",
			"So you're going to build a homeroom that earns. Recruit students, put them at desks, collect. That's the job.",
		},
		reveal = {
			"Well. Look at that. An actual functioning homeroom.",
			"Keep the receipts. You're going to need them sooner than you think.",
		},
		objectives = {
			{ id = "recruit", label = "Recruit 5 students", stat = "recruit", goal = 5 },
			{ id = "earn", label = "Bank $25,000", stat = "totalEarned", goal = 25000, kind = "reach" },
			{ id = "class", label = "Pass 3 lessons", stat = "classpass", goal = 3 },
		},
		cash = 5000,
		aura = 15,
		unlock = "Hall pass: the corridor is yours during lessons.",
	},
	{
		id = "audit",
		number = 2,
		title = "THE AUDIT",
		speaker = "Ms. Fern",
		grade = 1,
		hook = {
			"Don't tell Crumb I told you. The district sent an auditor last week.",
			"Crumbworth is on the closure list. Bottom of the county for funding AND for grades.",
			"If this place is going to still be here at the end of the year, somebody has to fix both. Look around. It's you.",
		},
		reveal = {
			"The auditor's gone. We're off the list — for now.",
			"She said something odd on her way out. That Crumbworth 'should have money'. That the founder left an endowment.",
			"Nobody's ever seen a penny of it.",
		},
		objectives = {
			{ id = "earn", label = "Bank $250,000", stat = "totalEarned", goal = 250000, kind = "reach" },
			{ id = "gpa", label = "Get 3 subjects to a B or better", stat = "goodgrades", goal = 3, kind = "reach" },
			{ id = "recruit", label = "Recruit 15 students", stat = "recruit", goal = 15 },
		},
		cash = 30000,
		aura = 40,
		unlock = "Honors lessons: harder questions, better pay.",
	},
	{
		id = "rival",
		number = 3,
		title = "THE RIVAL",
		speaker = "Coach Bricker",
		grade = 2,
		hook = {
			"You've noticed Rico. Everyone's noticed Rico.",
			"What you haven't noticed is that he's not doing it for fun. Somebody is paying that kid to wreck this school.",
			"I can't prove it. You can. Go make his life difficult and see who complains.",
		},
		reveal = {
			"He talked. Took about four goes, but he talked.",
			"He's being paid in cash, in envelopes, left in the principal's office.",
			"Which is a problem, because that's the one room nobody else has a key to.",
		},
		objectives = {
			{ id = "foil", label = "Take Rico's loot off him 5 times", stat = "foil", goal = 5 },
			{ id = "toys", label = "Land 40 toys on somebody", stat = "toyhit", goal = 40 },
			{ id = "aura", label = "Reach 1,000 aura", stat = "aura", goal = 1000, kind = "reach" },
		},
		cash = 120000,
		aura = 80,
		unlock = "The toy cart stocks firecrackers for you now.",
	},
	{
		id = "ledger",
		number = 4,
		title = "THE LEDGER",
		speaker = "Dr. Fizzle",
		grade = 3,
		hook = {
			"I found it in a box of expired reagents, which tells you how hard anyone looked.",
			"The founder's ledger. Every penny of the endowment, accounted for, and then one line: 'PLACED BELOW'.",
			"Not spent. Not lost. Placed. Below what, it doesn't say.",
		},
		reveal = {
			"Below the school. It has to be below the school.",
			"And there is exactly one room in this building with a floor nobody has ever measured.",
			"You know the one. Everybody knows the one.",
		},
		objectives = {
			{ id = "earn", label = "Bank $2,000,000", stat = "totalEarned", goal = 2000000, kind = "reach" },
			{ id = "gpa", label = "Get all 5 subjects to a B or better", stat = "goodgrades", goal = 5, kind = "reach" },
			{ id = "class", label = "Pass 40 lessons", stat = "classpass", goal = 40 },
		},
		cash = 600000,
		aura = 200,
		unlock = "You know where the endowment is.",
	},
	{
		id = "vault",
		number = 5,
		title = "THE VAULT",
		speaker = "Principal Crumb",
		grade = 4,
		hook = {
			"I know what you've been asking about. Stop asking.",
			"Yes, there's a door in my office. Yes, it goes down. No, you're not going through it.",
			"Go and look at it if you must. Look is all you get.",
		},
		reveal = {
			"Now you've seen it you understand why nobody talks about it.",
			"Whatever the founder put down there, it isn't lunch money.",
			"One key. One person. And it isn't going to be a student.",
		},
		objectives = {
			{ id = "find", label = "Find the door in the principal's office", stat = "founddoor", goal = 1 },
			{ id = "aura", label = "Reach 6,000 aura", stat = "aura", goal = 6000, kind = "reach" },
		},
		cash = 2000000,
		aura = 500,
		unlock = "Title: KNOWS TOO MUCH.",
	},
} :: { Chapter }

function Story.Get(number: number): Chapter?
	for _, chapter in Story.Chapters do
		if chapter.number == number then
			return chapter
		end
	end
	return nil
end

function Story.Count(): number
	return #Story.Chapters
end

return Story
