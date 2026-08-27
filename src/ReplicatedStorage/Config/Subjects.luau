--!strict
-- The timetable: five subjects, five professors, five rooms.
--
-- Rooms are real places you walk to. When a subject's period starts, that
-- professor's prompt goes live and the class runs as a minigame — a different
-- one per subject, because a school where every lesson is the same
-- multiple-choice quiz is not a school.

export type Subject = {
	id: string,
	name: string,
	icon: string,
	professor: string,
	baseId: string, -- roster id the professor's model is generated from
	room: string, -- where the class meets, in words
	position: Vector3, -- where the professor stands
	facing: Vector3, -- what they look at
	color: Color3,
	coat: Color3,
	mode: string, -- how the client lays the round out
	blurb: string, -- what the professor says while waiting
}

local Subjects = {}

Subjects.List = {
	{
		id = "math",
		name = "Mathematics",
		icon = "➗",
		professor = "Mr. Tangent",
		baseId = "valedictorian",
		room = "Room 101",
		position = Vector3.new(-74, 0, -108),
		facing = Vector3.new(-74, 0, -80),
		color = Color3.fromRGB(120, 176, 255),
		coat = Color3.fromRGB(64, 72, 96),
		mode = "numbers",
		blurb = "Mental arithmetic. No calculators, no excuses.",
	},
	{
		id = "chemistry",
		name = "Chemistry",
		icon = "⚗️",
		professor = "Dr. Fizzle",
		baseId = "the_janitor",
		room = "the East Lab",
		position = Vector3.new(116, 0, -34),
		facing = Vector3.new(116, 0, -10),
		color = Color3.fromRGB(150, 240, 190),
		coat = Color3.fromRGB(238, 240, 244),
		mode = "colors",
		blurb = "Mix what I ask for. Mix what I did not, and we evacuate.",
	},
	{
		id = "biology",
		name = "Biology",
		icon = "🧬",
		professor = "Ms. Fern",
		baseId = "lunch_lady_supreme",
		room = "the Greenhouse",
		position = Vector3.new(-116, 0, -34),
		facing = Vector3.new(-116, 0, -10),
		color = Color3.fromRGB(150, 220, 130),
		coat = Color3.fromRGB(226, 236, 224),
		mode = "emoji",
		blurb = "Name the living thing. Everything in here is watching you.",
	},
	{
		id = "music",
		name = "Music",
		icon = "🎵",
		professor = "Maestro Quill",
		baseId = "class_clown",
		room = "the Music Room",
		position = Vector3.new(74, 0, -108),
		facing = Vector3.new(74, 0, -80),
		color = Color3.fromRGB(212, 160, 240),
		coat = Color3.fromRGB(72, 54, 92),
		mode = "pads",
		blurb = "I play it once. You play it back. That is the whole art form.",
	},
	{
		id = "gym",
		name = "Gym",
		icon = "🏀",
		professor = "Coach Bricker",
		baseId = "hall_monitor",
		room = "the Gym",
		position = Vector3.new(0, 0, -78),
		facing = Vector3.new(0, 0, -100),
		color = Color3.fromRGB(255, 176, 88),
		coat = Color3.fromRGB(196, 88, 60),
		mode = "reflex",
		blurb = "Drop and give me... reflexes. Hit the target, not the floor.",
	},
} :: { Subject }

function Subjects.Get(id: string): Subject?
	for _, subject in Subjects.List do
		if subject.id == id then
			return subject
		end
	end
	return nil
end

-- A letter for a score, so a report card reads like a report card.
function Subjects.Letter(ratio: number): string
	if ratio >= 0.95 then
		return "A+"
	elseif ratio >= 0.85 then
		return "A"
	elseif ratio >= 0.7 then
		return "B"
	elseif ratio >= 0.55 then
		return "C"
	elseif ratio >= 0.4 then
		return "D"
	end
	return "F"
end

-- Every subject passed at B or better pays a small permanent income bonus.
-- Five subjects, so a full report card is +10% forever.
Subjects.IncomeBonusPerSubject = 0.02
Subjects.BonusMinRatio = 0.7

return Subjects
