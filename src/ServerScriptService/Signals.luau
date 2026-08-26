--!strict
-- Tiny in-server event bus so services can react to each other without circular requires.

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> RBXScriptConnection,
	Fire: (self: Signal, ...any) -> (),
}

local function makeSignal(): Signal
	local bindable = Instance.new("BindableEvent")
	local signal = {}
	function signal.Connect(_, fn)
		return bindable.Event:Connect(fn)
	end
	function signal.Fire(_, ...)
		bindable:Fire(...)
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
}
