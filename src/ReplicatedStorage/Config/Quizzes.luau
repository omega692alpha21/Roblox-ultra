--!strict
-- Pop quiz question pool. `correct` is the 1-based index into `answers`.
-- The answer key never leaves the server (ClassService strips `correct` before sending).

export type Question = {
	q: string,
	answers: { string },
	correct: number,
}

local Questions: { Question } = {
	{ q = "What is 7 x 8?", answers = { "54", "56", "64", "48" }, correct = 2 },
	{ q = "H2O is better known as...", answers = { "Salt", "Air", "Water", "Homework fuel" }, correct = 3 },
	{ q = "How many sides does a hexagon have?", answers = { "5", "6", "7", "8" }, correct = 2 },
	{ q = "The powerhouse of the cell is the...", answers = { "Nucleus", "Ribosome", "Mitochondria", "Cafeteria" }, correct = 3 },
	{ q = "What planet is closest to the sun?", answers = { "Venus", "Mercury", "Mars", "Earth" }, correct = 2 },
	{ q = "12 squared equals...", answers = { "124", "144", "112", "148" }, correct = 2 },
	{ q = "Which of these is a primary color?", answers = { "Green", "Orange", "Blue", "Purple" }, correct = 3 },
	{ q = "A triangle's angles add up to...", answers = { "90", "180", "270", "360" }, correct = 2 },
	{ q = "What gas do plants breathe in?", answers = { "Oxygen", "Nitrogen", "CO2", "Helium" }, correct = 3 },
	{ q = "Which word is a noun?", answers = { "Run", "Quickly", "Sandwich", "Blue" }, correct = 3 },
	{ q = "What is 15% of 200?", answers = { "20", "25", "30", "35" }, correct = 3 },
	{ q = "The largest ocean on Earth is the...", answers = { "Atlantic", "Indian", "Arctic", "Pacific" }, correct = 4 },
	{ q = "How many continents are there?", answers = { "5", "6", "7", "8" }, correct = 3 },
	{ q = "Which is NOT a state of matter?", answers = { "Solid", "Liquid", "Vibe", "Gas" }, correct = 3 },
	{ q = "What does the school bell mean?", answers = { "Free food", "Class time", "Fire drill", "Nap time" }, correct = 2 },
	{ q = "9 + 10 equals...", answers = { "19", "21", "910", "20" }, correct = 1 },
	{ q = "The opposite of 'ancient' is...", answers = { "Old", "Modern", "Dusty", "Historic" }, correct = 2 },
	{ q = "Which one is a mammal?", answers = { "Shark", "Dolphin", "Salmon", "Jellyfish" }, correct = 2 },
	{ q = "What is the square root of 81?", answers = { "7", "8", "9", "11" }, correct = 3 },
	{ q = "Light travels faster than...", answers = { "Nothing", "Sound", "Wi-Fi", "Rumors" }, correct = 2 },
	{ q = "An octopus has how many arms?", answers = { "6", "8", "10", "12" }, correct = 2 },
	{ q = "Which fraction is biggest?", answers = { "1/2", "1/3", "1/4", "1/8" }, correct = 1 },
	{ q = "The first day of the school week is...", answers = { "Sunday", "Monday", "Friday", "Never" }, correct = 2 },
	{ q = "What do bees make?", answers = { "Milk", "Honey", "Butter", "Drama" }, correct = 2 },
	{ q = "Which of these is a verb?", answers = { "Yeet", "Chair", "Loud", "Green" }, correct = 1 },
	{ q = "100 divided by 4 is...", answers = { "20", "25", "40", "50" }, correct = 2 },
	{ q = "The library is for...", answers = { "Yelling", "Reading", "Parkour", "Trading" }, correct = 2 },
	{ q = "Which planet has rings?", answers = { "Mars", "Venus", "Saturn", "Mercury" }, correct = 3 },
	{ q = "A right angle is how many degrees?", answers = { "45", "60", "90", "180" }, correct = 3 },
	{ q = "What should you do with your lunch money?", answers = { "Lose it", "Invest in crew", "Eat it", "Forget it" }, correct = 2 },
}

return Questions
