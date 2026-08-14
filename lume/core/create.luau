--!strict

--[[
	@name create
	@module lume/core/create

	Declarative tree construction. Descriptors are plain tables, so a component
	body reads as a tree; every reactive prop and event is registered on the
	owning scope and unwinds with it.
]]

--// imports
local Imports = {
	State = require("./state"),
}

local Types = require("../types")

--// types
type Descriptor = Types.Descriptor
type Refs = Types.Refs
type Scope = Types.Scope

--// locals
local function applyProps(scope, instance: Instance, props: { [string]: any }?)
	for key, value in props or {} do
		if Imports.State.is(value) then
			scope:add(Imports.State.observe(value, function(next)
				(instance :: any)[key] = next
			end))
		else
			(instance :: any)[key] = value
		end
	end
end

local function applyEvents(scope, instance: Instance, events: { [string]: (...any) -> () }?)
	for key, handler in events or {} do
		local event = (instance :: any)[key]

		if typeof(event) == "RBXScriptSignal" then
			scope:add(event:Connect(handler))
		end
	end
end

--// public api
local Create = {}

function Create.node(scope: Scope, descriptor: Descriptor, refs: Refs?): Instance
	local instance = Instance.new(descriptor.class)

	applyProps(scope, instance, descriptor.props)
	applyEvents(scope, instance, descriptor.events)

	for _, child in descriptor.children or {} do
		if typeof(child) == "Instance" then
			child.Parent = instance
		else
			Create.node(scope, child :: Descriptor, refs).Parent = instance
		end
	end

	if descriptor.ref and refs then
		refs[descriptor.ref] = instance
	end

	scope:add(instance)

	return instance
end

--// tree: builds a descriptor and returns the root plus every named ref
function Create.tree(scope: Scope, descriptor: Descriptor): (Instance, Refs)
	local refs: Refs = {}
	local root = Create.node(scope, descriptor, refs)

	return root, refs
end

--// bind: attach a reactive value to an already-created instance
function Create.bind(scope: Scope, instance: Instance, key: string, source: any)
	scope:add(Imports.State.observe(source, function(next)
		(instance :: any)[key] = next
	end))

	return instance
end

--// corner / stroke / padding helpers: the three things every surface needs
function Create.corner(radius: number): Descriptor
	return { class = "UICorner", props = { CornerRadius = UDim.new(0, radius) } }
end

function Create.stroke(color: Color3, thickness: number, transparency: number?): Descriptor
	return {
		class = "UIStroke",
		props = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = transparency or 0,
			Thickness = thickness,
			Color = color,
		},
	}
end

function Create.padding(x: number, y: number?): Descriptor
	local vertical = y or x

	return {
		class = "UIPadding",
		props = {
			PaddingLeft = UDim.new(0, x),
			PaddingRight = UDim.new(0, x),
			PaddingTop = UDim.new(0, vertical),
			PaddingBottom = UDim.new(0, vertical),
		},
	}
end

function Create.list(direction: Enum.FillDirection, gap: number, extra: { [string]: any }?): Descriptor
	local props: { [string]: any } = {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
		FillDirection = direction,
	}

	for key, value in extra or {} do
		props[key] = value
	end

	return { class = "UIListLayout", props = props }
end

return table.freeze(Create)
