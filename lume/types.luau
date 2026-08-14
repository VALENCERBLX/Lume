--!strict

--[[
	@name types
	@module lume/types
	@credit driftingAurora, dullflowerr, alias; kioukaii (original console UI, MIT)
]]

--// reactive
export type Unsubscribe = () -> ()

export type Value<T> = {
	kind: "value",

	get: (self: Value<T>) -> T,
	set: (self: Value<T>, value: T) -> (),
	update: (self: Value<T>, fn: (T) -> T) -> (),
	subscribe: (self: Value<T>, fn: (T) -> ()) -> Unsubscribe,
}

export type Computed<T> = {
	kind: "computed",

	get: (self: Computed<T>) -> T,
	subscribe: (self: Computed<T>, fn: (T) -> ()) -> Unsubscribe,
	destroy: (self: Computed<T>) -> (),
}

export type Source<T> = Value<T> | Computed<T>
export type Bindable<T> = T | Source<T>

--// lifecycle
export type Cleanup = (() -> ()) | Instance | RBXScriptConnection | { destroy: (any) -> () }

export type Scope = {
	add: (self: Scope, item: Cleanup) -> Cleanup,
	child: (self: Scope) -> Scope,
	destroy: (self: Scope) -> (),
	alive: (self: Scope) -> boolean,
}

export type Signal<T...> = {
	connect: (self: Signal<T...>, fn: (T...) -> ()) -> Unsubscribe,
	once: (self: Signal<T...>, fn: (T...) -> ()) -> Unsubscribe,
	fire: (self: Signal<T...>, T...) -> (),
	destroy: (self: Signal<T...>) -> (),
}

--// construction
export type Descriptor = {
	class: string,
	ref: string?,

	props: { [string]: any }?,
	events: { [string]: (...any) -> () }?,
	children: { Descriptor | Instance }?,
}

export type Refs = { [string]: Instance }

--// theme
export type MotionSpec = {
	duration: number?,
	easing: string?,
	stiffness: number?,
	damping: number?,
}

export type Theme = {
	color: { [string]: Color3 },
	rich: { [string]: string },
	transparency: { [string]: number },

	font: { [string]: Enum.Font },
	text: { [string]: number },

	space: { [string]: number },
	radius: { [string]: number },
	stroke: { [string]: number },

	motion: { [string]: MotionSpec },

	extend: (self: Theme, overrides: { [string]: any }) -> Theme,
}

--// motion
export type Animation = {
	cancel: (self: Animation) -> (),
	finish: (self: Animation) -> (),
	completed: Signal<>,
	active: (self: Animation) -> boolean,
}

--// layout
export type Measurer = {
	text: (self: Measurer, text: string, size: number, font: Enum.Font, width: number?) -> Vector2,
	width: (self: Measurer, text: string, size: number, font: Enum.Font) -> number,
	lineHeight: (self: Measurer, size: number, font: Enum.Font) -> number,
	gap: (self: Measurer, size: number, font: Enum.Font) -> number,
	flush: (self: Measurer) -> (),
}

export type Edge = "top" | "bottom" | "left" | "right"

--// components
export type App = {
	gui: LayerCollector,
	theme: Theme,
	scope: Scope,
	measure: Measurer,

	focus: any,
	keys: any,

	surface: (self: App, name: string) -> Frame,
	destroy: (self: App) -> (),
}

export type Handle = {
	app: App,
	scope: Scope,
	refs: Refs,

	instance: (self: Handle) -> GuiObject,
	mount: (self: Handle, parent: Instance) -> Handle,

	animate: (self: Handle, props: { [string]: any }, spec: (MotionSpec | string)?) -> Animation,
	destroy: (self: Handle) -> (),
}

return {}
