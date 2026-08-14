--!strict

--[[
	@name placement
	@module lume/layout/placement

	Anchor math for floating surfaces: stacking, attaching, flipping away
	from a viewport edge, and clamping back on screen.
]]

--// imports
local Imports = {
	AutoSize = require("./autosize"),
}

--// public api
local Placement = {}

--// isTop: which half of the screen an object lives in, from its anchor point
function Placement.isTop(object: GuiObject): boolean
	return object.AnchorPoint.Y < 0.5
end

function Placement.absoluteY(object: GuiObject): number
	local position = object.Position
	local height = Imports.AutoSize.viewport().Y

	return (height * position.Y.Scale) + position.Y.Offset
end

--// withStack / withoutStack: keep the visual top edge fixed while a surface
--// grows downward or shrinks, so stacked panels never jump
function Placement.withStack(position: UDim2, object: GuiObject, extra: number): UDim2
	if Placement.isTop(object) then
		return position
	end

	return UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + extra)
end

function Placement.withoutStack(position: UDim2, object: GuiObject, extra: number): UDim2
	if Placement.isTop(object) then
		return position
	end

	return UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset - extra)
end

--// stacked: position a sibling directly under (or over) an anchor surface
function Placement.stacked(position: UDim2, object: GuiObject, height: number, gap: number): UDim2
	local delta = Placement.isTop(object) and (height + gap) or -(height + gap)

	return UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + delta)
end

--// beside: attach to an edge of a target, in absolute pixels
function Placement.beside(target: GuiObject, size: Vector2, edge: string, gap: number): UDim2
	local origin = target.AbsolutePosition
	local bounds = target.AbsoluteSize

	local x, y = origin.X, origin.Y

	if edge == "right" then
		x = origin.X + bounds.X + gap
	elseif edge == "left" then
		x = origin.X - size.X - gap
	elseif edge == "top" then
		y = origin.Y - size.Y - gap
	else
		y = origin.Y + bounds.Y + gap
	end

	return Placement.clamp(UDim2.fromOffset(math.round(x), math.round(y)), size, 8)
end

--// flip: choose the edge with more room, so popovers never open off-screen
function Placement.flip(target: GuiObject, size: Vector2, preferred: string, gap: number): string
	local view = Imports.AutoSize.viewport()
	local origin = target.AbsolutePosition
	local bounds = target.AbsoluteSize

	if preferred == "bottom" and origin.Y + bounds.Y + gap + size.Y > view.Y then
		return "top"
	end

	if preferred == "top" and origin.Y - gap - size.Y < 0 then
		return "bottom"
	end

	if preferred == "right" and origin.X + bounds.X + gap + size.X > view.X then
		return "left"
	end

	if preferred == "left" and origin.X - gap - size.X < 0 then
		return "right"
	end

	return preferred
end

function Placement.clamp(position: UDim2, size: Vector2, inset: number): UDim2
	local view = Imports.AutoSize.viewport()

	local x = math.clamp(position.X.Offset, inset, math.max(inset, view.X - size.X - inset))
	local y = math.clamp(position.Y.Offset, inset, math.max(inset, view.Y - size.Y - inset))

	return UDim2.new(position.X.Scale, x, position.Y.Scale, y)
end

function Placement.center(size: Vector2): UDim2
	local view = Imports.AutoSize.viewport()

	return UDim2.fromOffset(math.round((view.X - size.X) / 2), math.round((view.Y - size.Y) / 2))
end

return table.freeze(Placement)
