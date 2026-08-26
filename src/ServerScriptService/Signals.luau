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
}
