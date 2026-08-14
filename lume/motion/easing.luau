--!strict

--[[
	@name easing
	@module lume/motion/easing
]]

--// locals
local function outQuad(t: number): number
	return 1 - (1 - t) * (1 - t)
end

--// public api
local Easing: { [string]: (number) -> number } = {}

Easing.linear = function(t)
	return t
end

Easing.outQuad = outQuad

Easing.inQuad = function(t)
	return t * t
end

Easing.inOutQuad = function(t)
	return t < 0.5 and 2 * t * t or 1 - ((-2 * t + 2) ^ 2) / 2
end

Easing.outCubic = function(t)
	return 1 - (1 - t) ^ 3
end

Easing.outQuart = function(t)
	return 1 - (1 - t) ^ 4
end

Easing.outQuint = function(t)
	return 1 - (1 - t) ^ 5
end

Easing.inOutQuint = function(t)
	return t < 0.5 and 16 * t ^ 5 or 1 - ((-2 * t + 2) ^ 5) / 2
end

Easing.outExpo = function(t)
	return t >= 1 and 1 or 1 - 2 ^ (-10 * t)
end

Easing.outBack = function(t)
	local c = 1.70158

	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

Easing.outElastic = function(t)
	if t <= 0 or t >= 1 then
		return t
	end

	return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * ((2 * math.pi) / 3)) + 1
end

function Easing.resolve(name: any): (number) -> number
	if type(name) == "function" then
		return name
	end

	return Easing[tostring(name)] or outQuad
end

return table.freeze(Easing)
