--!strict

--[[
	@name lume
	@module lume

	A UI engine for Roblox: declarative trees, imperative handles, one motion
	driver, content-driven layout.

	Derived from the console UI by driftingAurora, dullflowerr, alias and
	kioukaii (MIT); generalised into a component library.

	local Lume = require(path.to.lume)

	local app = Lume.app({ name = "Inspector" })

	local window = app:window({ title = "Inspector", width = 320 })
	local search = app:field({ placeholder = "Search", parent = window.content })

	search:on("submitted", print)
]]

--// imports
local Imports = {
	Components = require("./components"),
	Placement = require("./layout/placement"),
	AutoSize = require("./layout/autosize"),
	Measure = require("./layout/measure"),
	Virtual = require("./layout/virtual"),

	Create = require("./core/create"),
	Handle = require("./core/handle"),
	Signal = require("./core/signal"),
	Scope = require("./core/scope"),
	State = require("./core/state"),

	Motion = require("./motion"),
	Theme = require("./theme"),

	Focus = require("./input/focus"),
	Drag = require("./input/drag"),
	Keys = require("./input/keys"),

	Text = require("./text"),
	App = require("./app"),
}

local Types = require("./types")

--// types
export type App = Types.App
export type Handle = Types.Handle
export type Theme = Types.Theme
export type Scope = Types.Scope
export type Descriptor = Types.Descriptor
export type MotionSpec = Types.MotionSpec
export type Value<T> = Types.Value<T>
export type Computed<T> = Types.Computed<T>
export type Bindable<T> = Types.Bindable<T>

--// public api
local Lume = {
	version = "1.0.0",

	--// entry point
	app = function(options: { [string]: any }?)
		return Imports.App.new(options)
	end,

	--// reactivity
	value = Imports.State.value,
	computed = Imports.State.computed,
	observe = Imports.State.observe,
	batch = Imports.State.batch,

	--// construction
	create = Imports.Create.node,
	tree = Imports.Create.tree,
	scope = Imports.Scope.new,
	signal = Imports.Signal.new,

	--// systems
	State = Imports.State,
	Motion = Imports.Motion,
	Theme = Imports.Theme,
	Create = Imports.Create,
	Handle = Imports.Handle,
	Text = Imports.Text,

	Measure = Imports.Measure,
	Virtual = Imports.Virtual,
	Placement = Imports.Placement,
	AutoSize = Imports.AutoSize,

	Focus = Imports.Focus,
	Drag = Imports.Drag,
	Keys = Imports.Keys,

	--// components
	Components = Imports.Components,
}

for name, component in Imports.Components do
	Lume[name] = component
end

return table.freeze(Lume)
