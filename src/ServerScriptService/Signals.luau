--!strict
-- Tiny in-server event bus so services can react to each other without circular
-- requires. Pure Lua (NOT BindableEvents): arguments are passed by reference,
-- so subscribers can safely mutate shared tables like the player profile.

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> (),
	Fire: (self: Signal, ...any) -> (),
}

local function makeSignal(): Signal
	local handlers: { (...any) -> () } = {}
	local signal = {}
	function signal.Connect(_, fn)
		table.insert(handlers, fn)
	end
	function signal.Fire(_, ...)
		for _, fn in handlers do
			task.spawn(fn, ...)
		end
	end
	return signal :: any
end

return {
	Earned = makeSignal(), -- (player, amount) cash actually banked
	Collected = makeSignal(), -- (player) stepped on collect pad with a pile
	Recruited = makeSignal(), -- (player, defId)
	Stole = makeSignal(), -- (thief, victim, defId)
	CaughtStealing = makeSignal(), -- (thief)
	ThiefHit = makeSignal(), -- (puncher, thief)
	QuizWon = makeSignal(), -- (player)
	QuizWrong = makeSignal(), -- (player)
	AuraGained = makeSignal(), -- (player, amount)
	ProfileLoaded = makeSignal(), -- (player, profile)
	CrewChanged = makeSignal(), -- (player)
	RivalFoiled = makeSignal(), -- (puncher) Rico dropped his loot
	Fused = makeSignal(), -- (player, defId) fused 3 dupes into a star
	EventScore = makeSignal(), -- (player, eventId) scored during a live event
	Locked = makeSignal(), -- (player) locked their own homeroom
	ToyUsed = makeSignal(), -- (player, toyId) threw a toy
	ToyHit = makeSignal(), -- (player, toyId) landed one on somebody
	ClassAttended = makeSignal(), -- (player, subjectId) sat down in a lesson
	ChapterDone = makeSignal(), -- (player, chapterNumber) closed a story chapter
	FoundTheDoor = makeSignal(), -- (player) touched the bookshelf in the office
	Punched = makeSignal(), -- (player, targetModel) a punch landed on something
	Damaged = makeSignal(), -- (player, from) took health off, and who from
}
