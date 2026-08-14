--!strict

--[[
	@name lerp
	@module lume/motion/lerp

	Type-aware interpolation. Anything the engine can animate is interpolated
	here, so tween and spring share one numeric path.
]]

--// locals
local function number(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

local handlers: { [string]: (any, any, number) -> any } = {}

handlers.number = number

handlers.UDim = function(from: UDim, to: UDim, alpha: number)
	return UDim.new(number(from.Scale, to.Scale, alpha), number(from.Offset, to.Offset, alpha))
end

handlers.UDim2 = function(from: UDim2, to: UDim2, alpha: number)
	return from:Lerp(to, alpha)
end

handlers.Vector2 = function(from: Vector2, to: Vector2, alpha: number)
	return from:Lerp(to, alpha)
end

handlers.Vector3 = function(from: Vector3, to: Vector3, alpha: number)
	return from:Lerp(to, alpha)
end

handlers.Color3 = function(from: Color3, to: Color3, alpha: number)
	return from:Lerp(to, alpha)
end

handlers.Rect = function(from: Rect, to: Rect, alpha: number)
	return Rect.new(handlers.Vector2(from.Min, to.Min, alpha), handlers.Vector2(from.Max, to.Max, alpha))
end

--// public api
local Lerp = {}

function Lerp.supports(value: any): boolean
	return handlers[typeof(value)] ~= nil
end

function Lerp.between(from: any, to: any, alpha: number): any
	local handler = handlers[typeof(from)]

	if not handler or typeof(from) ~= typeof(to) then
		return alpha >= 1 and to or from
	end

	return handler(from, to, alpha)
end

--// scalars: springs solve per-component, so expose a flatten/rebuild pair
function Lerp.components(value: any): { number }
	local kind = typeof(value)

	if kind == "number" then
		return { value }
	elseif kind == "UDim" then
		return { value.Scale, value.Offset }
	elseif kind == "UDim2" then
		return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "Vector2" then
		return { value.X, value.Y }
	elseif kind == "Vector3" then
		return { value.X, value.Y, value.Z }
	elseif kind == "Color3" then
		return { value.R, value.G, value.B }
	end

	return {}
end

function Lerp.rebuild(kind: string, parts: { number }): any
	if kind == "number" then
		return parts[1]
	elseif kind == "UDim" then
		return UDim.new(parts[1], math.round(parts[2]))
	elseif kind == "UDim2" then
		return UDim2.new(parts[1], math.round(parts[2]), parts[3], math.round(parts[4]))
	elseif kind == "Vector2" then
		return Vector2.new(parts[1], parts[2])
	elseif kind == "Vector3" then
		return Vector3.new(parts[1], parts[2], parts[3])
	elseif kind == "Color3" then
		return Color3.new(math.clamp(parts[1], 0, 1), math.clamp(parts[2], 0, 1), math.clamp(parts[3], 0, 1))
	end

	return nil
end

return table.freeze(Lerp)
