--!strict
-- The four houses, and what earns them points.
--
-- Everything else in this game is something you do alone: your homeroom, your
-- report card, your cash. The House Cup is the one number on the server that
-- other people can move for you, which is the whole reason to be on a server
-- with other people rather than a private one.
--
-- A term is short on purpose -- twelve minutes, a couple of school periods.
-- Long enough that a good run matters, short enough that somebody joining now
-- is not joining halfway through nothing.

export type House = {
	id: string,
	name: string,
	motto: string,
	color: Color3,
	crest: string,
}

local Houses = {}

Houses.TermSeconds = 12 * 60

Houses.List = {
	{ id = "crumb", name = "CRUMB", motto = "Nothing goes to waste.", color = Color3.fromRGB(238, 186, 62), crest = "🍞" },
	{ id = "thorne", name = "THORNE", motto = "Hold the line.", color = Color3.fromRGB(214, 72, 64), crest = "🌹" },
	{ id = "vale", name = "VALE", motto = "Think first. Then act.", color = Color3.fromRGB(72, 128, 214), crest = "🌊" },
	{ id = "ashby", name = "ASHBY", motto = "Quietly, and well.", color = Color3.fromRGB(84, 178, 108), crest = "🌿" },
} :: { House }

-- What a thing is worth. These are deliberately small: the Cup should be won
-- by a house that did a lot of ordinary things, not by one player who found
-- the single richest action and repeated it.
Houses.Points = {
	classPass = 12, -- a lesson passed
	classPerfect = 8, -- and a bonus for a clean sheet
	recruit = 4,
	questClaim = 15,
	missionDone = 25,
	chapterDone = 60,
	rivalFoiled = 10,
	thiefCaught = 8,
	toyHit = 1,
	fused = 6,
	graduated = 40,
}

function Houses.Get(id: string?): House?
	if typeof(id) ~= "string" then
		return nil
	end
	for _, house in Houses.List do
		if house.id == id then
			return house
		end
	end
	return nil
end

-- Sorting is by user id, so the same person lands in the same house on every
-- server and a friend group can be told what they are. It can be overridden
-- once from the crest in the lobby.
function Houses.SortFor(userId: number): string
	return Houses.List[(userId % #Houses.List) + 1].id
end

return Houses
