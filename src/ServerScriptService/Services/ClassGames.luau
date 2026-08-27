--!strict
-- Round generators, one per subject. Server-only: the answer never leaves here.
--
-- Each generator returns rounds in a single shape the client can lay out four
-- different ways, so adding a subject is a table entry rather than a new UI.

local ClassGames = {}

export type Round = {
	prompt: string,
	options: { string }, -- what the client shows on each button
	colors: { Color3 }?, -- for modes that are about colour, not text
	sequence: { number }?, -- for the memory mode: the pattern to replay
	correct: number, -- server-side only; stripped before sending
}

local rng = Random.new()

local function shuffled(list: { any }): { any }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- ------------------------------------------------------------- mathematics ---
-- Arithmetic that gets harder as the lesson goes on. The wrong answers are
-- near-misses, so it is a real calculation and not a glance.
local function mathRounds(count: number): { Round }
	local rounds: { Round } = {}
	for i = 1, count do
		local difficulty = math.min(i, 8)
		local a, b, answer, prompt
		local op = rng:NextInteger(1, difficulty >= 5 and 4 or 3)
		if op == 1 then
			a, b = rng:NextInteger(6, 12 + difficulty * 6), rng:NextInteger(6, 12 + difficulty * 6)
			answer = a + b
			prompt = ("%d + %d"):format(a, b)
		elseif op == 2 then
			a = rng:NextInteger(20, 40 + difficulty * 8)
			b = rng:NextInteger(5, a - 1)
			answer = a - b
			prompt = ("%d − %d"):format(a, b)
		elseif op == 3 then
			a, b = rng:NextInteger(3, 6 + difficulty), rng:NextInteger(3, 6 + difficulty)
			answer = a * b
			prompt = ("%d × %d"):format(a, b)
		else
			b = rng:NextInteger(3, 9)
			answer = rng:NextInteger(3, 12)
			a = b * answer
			prompt = ("%d ÷ %d"):format(a, b)
		end

		local wrongs: { number } = {}
		while #wrongs < 3 do
			local drift = rng:NextInteger(1, math.max(4, math.floor(answer * 0.25)))
			local candidate = answer + (rng:NextInteger(0, 1) == 0 and -drift or drift)
			if candidate > 0 and candidate ~= answer and not table.find(wrongs, candidate) then
				table.insert(wrongs, candidate)
			end
		end

		local options = { tostring(answer), tostring(wrongs[1]), tostring(wrongs[2]), tostring(wrongs[3]) }
		local order = shuffled({ 1, 2, 3, 4 })
		local shown: { string } = {}
		local correct = 1
		for slot, source in order do
			shown[slot] = options[source]
			if source == 1 then
				correct = slot
			end
		end
		table.insert(rounds, { prompt = prompt, options = shown, correct = correct })
	end
	return rounds
end

-- --------------------------------------------------------------- chemistry ---
-- Colour mixing: the board shows a target compound, you pick the two reagents
-- that make it. Visual, instant to read, nothing like the arithmetic drill.
local REAGENTS = {
	{ name = "Hydrogen", color = Color3.fromRGB(232, 86, 78) },
	{ name = "Cobalt", color = Color3.fromRGB(74, 122, 224) },
	{ name = "Sulphur", color = Color3.fromRGB(244, 206, 74) },
	{ name = "Chlorine", color = Color3.fromRGB(126, 216, 128) },
}

local MIXES = {
	{ a = 1, b = 2, name = "Violet Salt", color = Color3.fromRGB(160, 104, 156) },
	{ a = 1, b = 3, name = "Orange Oxide", color = Color3.fromRGB(240, 150, 76) },
	{ a = 2, b = 3, name = "Green Vitriol", color = Color3.fromRGB(158, 166, 150) },
	{ a = 2, b = 4, name = "Teal Bromide", color = Color3.fromRGB(100, 170, 178) },
	{ a = 3, b = 4, name = "Lime Nitrate", color = Color3.fromRGB(186, 212, 100) },
	{ a = 1, b = 4, name = "Coral Iodide", color = Color3.fromRGB(180, 152, 104) },
}

local function chemistryRounds(count: number): { Round }
	local rounds: { Round } = {}
	for _ = 1, count do
		local mix = MIXES[rng:NextInteger(1, #MIXES)]
		-- the answer is one of the two reagents in the compound; the other
		-- three buttons are the reagents that are not
		local wanted = rng:NextInteger(0, 1) == 0 and mix.a or mix.b
		local options: { string } = {}
		local colors: { Color3 } = {}
		local correct = 1
		for slot, index in shuffled({ 1, 2, 3, 4 }) do
			options[slot] = REAGENTS[index].name
			colors[slot] = REAGENTS[index].color
			if index == wanted then
				correct = slot
			end
		end
		local other = wanted == mix.a and mix.b or mix.a
		table.insert(rounds, {
			prompt = ("%s = %s + ?"):format(mix.name, REAGENTS[other].name),
			options = options,
			colors = colors,
			correct = correct,
		})
	end
	return rounds
end

-- ----------------------------------------------------------------- biology ---
-- Identification: four creatures, one question. Reads at a glance on a phone.
local SPECIMENS = {
	{ q = "Which one is a MAMMAL?", right = { "🦇", "🐬", "🦊", "🦥" }, wrong = { "🐍", "🐟", "🦎", "🐛", "🐸", "🦂" } },
	{ q = "Which one is an INSECT?", right = { "🐜", "🐝", "🦗", "🪲" }, wrong = { "🕷️", "🦀", "🐌", "🪱", "🦎" } },
	{ q = "Which one is a REPTILE?", right = { "🐊", "🦎", "🐢", "🐍" }, wrong = { "🐸", "🦈", "🦇", "🐛", "🦉" } },
	{ q = "Which one is an AMPHIBIAN?", right = { "🐸", "🦎" }, wrong = { "🐍", "🐢", "🐟", "🦂", "🐀" } },
	{ q = "Which one is a BIRD?", right = { "🦉", "🦅", "🐧", "🦆" }, wrong = { "🦇", "🐿️", "🐝", "🦋", "🐊" } },
	{ q = "Which one is a PLANT?", right = { "🌻", "🌵", "🌲", "🍄" }, wrong = { "🐌", "🪸", "🦠", "🐛", "🦎" } },
	{ q = "Which one lives in the OCEAN?", right = { "🐙", "🦈", "🐠", "🦀" }, wrong = { "🦌", "🦉", "🐝", "🦔", "🐪" } },
	{ q = "Which one is NOT alive?", right = { "🪨", "💧", "🔥", "❄️" }, wrong = { "🌱", "🐜", "🦠", "🐟", "🌳" } },
}

local function biologyRounds(count: number): { Round }
	local rounds: { Round } = {}
	for _ = 1, count do
		local spec = SPECIMENS[rng:NextInteger(1, #SPECIMENS)]
		local answer = spec.right[rng:NextInteger(1, #spec.right)]
		local decoys = shuffled(spec.wrong)
		local pool = { answer, decoys[1], decoys[2], decoys[3] }
		local options: { string } = {}
		local correct = 1
		for slot, source in shuffled({ 1, 2, 3, 4 }) do
			options[slot] = pool[source]
			if source == 1 then
				correct = slot
			end
		end
		table.insert(rounds, { prompt = spec.q, options = options, correct = correct })
	end
	return rounds
end

-- ------------------------------------------------------------------- music ---
-- Call and response: the room plays a phrase, you play it back. The phrase
-- grows a note every round, so the lesson is memory rather than reaction.
local PADS = {
	{ name = "Do", color = Color3.fromRGB(226, 96, 88) },
	{ name = "Re", color = Color3.fromRGB(240, 190, 84) },
	{ name = "Mi", color = Color3.fromRGB(120, 200, 132) },
	{ name = "Fa", color = Color3.fromRGB(120, 158, 236) },
}

local function musicRounds(count: number): { Round }
	local rounds: { Round } = {}
	local sequence: { number } = {}
	for i = 1, count do
		table.insert(sequence, rng:NextInteger(1, #PADS))
		local options: { string } = {}
		local colors: { Color3 } = {}
		for slot, pad in PADS do
			options[slot] = pad.name
			colors[slot] = pad.color
		end
		table.insert(rounds, {
			prompt = ("Phrase %d — %d note%s"):format(i, #sequence, if #sequence == 1 then "" else "s"),
			options = options,
			colors = colors,
			sequence = table.clone(sequence),
			correct = 0, -- unused: the whole sequence is the answer
		})
	end
	return rounds
end

-- --------------------------------------------------------------------- gym ---
-- Reflex drill: one of four targets lights up and you have to hit that one
-- before the clock runs down. No knowledge, pure hands.
local function gymRounds(count: number): { Round }
	local rounds: { Round } = {}
	local TARGETS = { "🎯", "🏀", "🥏", "⚽" }
	for i = 1, count do
		local correct = rng:NextInteger(1, 4)
		local options: { string } = {}
		for slot = 1, 4 do
			options[slot] = TARGETS[slot]
		end
		table.insert(rounds, {
			prompt = ("Hit %s — drill %d"):format(TARGETS[correct], i),
			options = options,
			correct = correct,
		})
	end
	return rounds
end

local GENERATORS: { [string]: (number) -> { Round } } = {
	math = mathRounds,
	chemistry = chemistryRounds,
	biology = biologyRounds,
	music = musicRounds,
	gym = gymRounds,
}

function ClassGames.Build(subjectId: string, count: number): { Round }
	local generator = GENERATORS[subjectId]
	if not generator then
		return mathRounds(count)
	end
	return generator(count)
end

-- What the client is allowed to see: everything except which button is right.
function ClassGames.Public(rounds: { Round }): { any }
	local out = {}
	for _, round in rounds do
		table.insert(out, {
			prompt = round.prompt,
			options = round.options,
			colors = round.colors,
			sequence = round.sequence,
		})
	end
	return out
end

return ClassGames
