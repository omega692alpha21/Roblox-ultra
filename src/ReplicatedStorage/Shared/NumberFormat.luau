--!strict
-- 1234 -> "1.2K", 5600000 -> "5.6M", etc.

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local NumberFormat = {}

function NumberFormat.Abbreviate(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local tier = math.floor(math.log10(n) / 3)
	tier = math.min(tier, #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	if scaled >= 100 then
		return string.format("%d%s", math.floor(scaled), SUFFIXES[tier + 1])
	end
	return string.format("%.1f%s", math.floor(scaled * 10) / 10, SUFFIXES[tier + 1])
end

function NumberFormat.Commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function NumberFormat.Clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return NumberFormat
