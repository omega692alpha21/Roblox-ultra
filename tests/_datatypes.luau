--!nocheck
-- Roblox datatype stand-ins for running pure game modules under the luau CLI.
local Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255, __color = true }
	end,
	new = function(r, g, b)
		return { R = r or 0, G = g or 0, B = b or 0, __color = true }
	end,
}
local RandomClass = {}
RandomClass.__index = RandomClass
function RandomClass.new(seed)
	local self = setmetatable({}, RandomClass)
	self.state = math.floor(((seed or 12345) % 2147483646) + 1)
	return self
end
function RandomClass:_next()
	self.state = (self.state * 16807) % 2147483647
	return self.state / 2147483647
end
function RandomClass:NextNumber(min, max)
	local v = self:_next()
	if min then
		return min + v * (max - min)
	end
	return v
end
function RandomClass:NextInteger(min, max)
	return min + math.floor(self:_next() * (max - min + 1) * 0.9999999)
end
return { Color3 = Color3, Random = RandomClass }
