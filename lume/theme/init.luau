--!strict

--[[
	@name theme
	@module lume/theme
]]

--// imports
local Imports = {
	Tokens = require("./tokens"),
}

local Types = require("../types")

--// types
export type Theme = Types.Theme

--// locals
local function deepMerge(base, overrides)
	local out = {}

	for key, value in base do
		if type(value) == "table" then
			out[key] = deepMerge(value, {})
		else
			out[key] = value
		end
	end

	for key, value in overrides or {} do
		if type(value) == "table" and type(out[key]) == "table" then
			out[key] = deepMerge(out[key], value)
		else
			out[key] = value
		end
	end

	return out
end

--// public api
local Theme = {}

local methods = {}

function methods.extend(self, overrides)
	return Theme.new(deepMerge(self, overrides))
end

function methods.spec(self, name)
	if type(name) == "table" then
		return name
	end

	return self.motion[name] or self.motion.enter
end

function Theme.new(overrides: { [string]: any }?): Theme
	local theme = deepMerge(Imports.Tokens, overrides)

	for name, fn in methods do
		theme[name] = fn
	end

	return (theme :: any) :: Theme
end

Theme.tokens = Imports.Tokens

return Theme
