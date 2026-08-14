--!strict

--[[
	@name measure
	@module lume/layout/measure

	Cached text metrics. Auto-sizing asks for the same strings constantly
	while typing; without the cache every keystroke costs a TextService call.
]]

--// imports
local Imports = {
	TextService = game:GetService("TextService"),
}

--// locals
local Unbounded = Vector2.new(100000, 100000)

--// public api
local Measure = {}
Measure.__index = Measure

function Measure.new()
	return setmetatable({ cache = {} }, Measure)
end

function Measure.text(self, text: string, size: number, font: Enum.Font, width: number?): Vector2
	local key = string.format("%d|%s|%d|%s", size, tostring(font), width or 0, text)
	local hit = self.cache[key]

	if hit then
		return hit
	end

	local bounds = width and Vector2.new(width, Unbounded.Y) or Unbounded
	local measured = Imports.TextService:GetTextSize(text, size, font, bounds)

	self.cache[key] = measured

	return measured
end

function Measure.width(self, text: string, size: number, font: Enum.Font): number
	return self:text(text, size, font).X
end

--// lineHeight: measured off a two-line sample so ascender/descender are real
function Measure.lineHeight(self, size: number, font: Enum.Font): number
	return math.ceil(self:text("Ag\nAg", size, font).Y / 2)
end

--// gap: width of a single space at this size, the unit inline hints advance by
function Measure.gap(self, size: number, font: Enum.Font): number
	return math.floor((self:width("a a", size, font) - self:width("aa", size, font)) * 0.5)
end

--// exact: trailing whitespace is trimmed by GetTextSize, so pad and subtract
function Measure.exact(self, text: string, size: number, font: Enum.Font): number
	if text == "" then
		return 0
	end

	return self:width(text .. ".", size, font) - self:width(".", size, font)
end

function Measure.flush(self)
	self.cache = {}
end

return Measure
