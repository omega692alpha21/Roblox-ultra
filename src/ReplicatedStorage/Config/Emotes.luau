--!strict
-- The emote wheel.
--
-- In a school game the thing players do most is stand near each other, and
-- standing near each other is only worth doing if there is something to do
-- while you do it. Eight of them, so the wheel is one thumb-sweep and every
-- slot is reachable without looking.
--
-- `id` has to name a pose in Shared/ActionPoses; tools/wiring_check.py proves
-- every one of them does.

export type Emote = { id: string, label: string, icon: string }

local Emotes = {}

Emotes.List = {
	{ id = "wave", label = "WAVE", icon = "👋" },
	{ id = "cheer", label = "CHEER", icon = "🙌" },
	{ id = "dance", label = "DANCE", icon = "🕺" },
	{ id = "clap", label = "CLAP", icon = "👏" },
	{ id = "point", label = "POINT", icon = "👉" },
	{ id = "taunt", label = "TAUNT", icon = "😏" },
	{ id = "shrug", label = "SHRUG", icon = "🤷" },
	{ id = "facepalm", label = "FACEPALM", icon = "🤦" },
} :: { Emote }

function Emotes.Get(id: string): Emote?
	for _, emote in Emotes.List do
		if emote.id == id then
			return emote
		end
	end
	return nil
end

return Emotes
