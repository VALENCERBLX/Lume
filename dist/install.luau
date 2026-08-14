--!nocheck

--[[
	Lume installer
	Builds the engine into your place as ModuleScripts, ready to require().

	Studio command bar (one line):

	  loadstring(game:GetService("HttpService"):GetAsync("<RAW_URL>/dist/install.luau"))()

	Options (set before running, all optional):

	  _G.LumeInstall = {
	      parent    = game:GetService("ReplicatedStorage"),  --// where to build
	      name      = "lume",                                --// root instance name
	      overwrite = true,                                  --// replace an existing install
	      select    = true,                                  --// select the root when done
	      silent    = false,
	  }

	MIT. Original console UI by driftingAurora, dullflowerr, alias, kioukaii.
	Generated from the lume/ source tree - edit that, not this file.
]]

local Selection = nil

pcall(function()
	Selection = game:GetService("Selection")
end)

local Options = type(_G.LumeInstall) == "table" and _G.LumeInstall or {}

local parent = typeof(Options.parent) == "Instance" and Options.parent or game:GetService("ReplicatedStorage")
local rootName = tostring(Options.name or "lume")
local overwrite = Options.overwrite ~= false
local silent = Options.silent == true

local Version = "1.0.0"

local function say(...)
	if not silent then
		print("[lume]", ...)
	end
end

--// every module, parents before children
local Manifest = {
	{
		path = "lume",
		kind = "module",
		source = [=====[
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
	Components = require(script.components),
	Placement = require(script.layout.placement),
	AutoSize = require(script.layout.autosize),
	Measure = require(script.layout.measure),
	Virtual = require(script.layout.virtual),

	Create = require(script.core.create),
	Handle = require(script.core.handle),
	Signal = require(script.core.signal),
	Scope = require(script.core.scope),
	State = require(script.core.state),

	Motion = require(script.motion),
	Theme = require(script.theme),

	Focus = require(script.input.focus),
	Drag = require(script.input.drag),
	Keys = require(script.input.keys),

	Text = require(script.text),
	App = require(script.app),
}

local Types = require(script.types)

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
]=====],
	},
	{
		path = "lume/app",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name app
	@module lume/app

	An app is the one piece of shared state: its ScreenGui, theme, root scope,
	measurement cache, focus ring, and key binder. Layers are z-ordered
	full-screen frames so popovers, modals, and tooltips can never be clipped
	by the surface that spawned them.
]]

--// imports
local Imports = {
	Players = game:GetService("Players"),
	Workspace = game:GetService("Workspace"),

	Components = require(script.Parent.components),
	Measure = require(script.Parent.layout.measure),
	Signal = require(script.Parent.core.signal),
	Theme = require(script.Parent.theme),
	Scope = require(script.Parent.core.scope),
	Focus = require(script.Parent.input.focus),
	Keys = require(script.Parent.input.keys),
}

--// locals
local LayerOrder = {
	default = 1,
	popover = 10,
	modal = 100,
	tooltip = 1000,
}

local function hostGui(options, scope): LayerCollector
	if options.gui then
		return options.gui
	end

	local player = Imports.Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

	local gui = Instance.new("ScreenGui")

	gui.Name = options.name or "LumeApp"
	gui.IgnoreGuiInset = options.ignoreGuiInset ~= false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = options.displayOrder or 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	gui.Parent = playerGui or Imports.Workspace

	scope:add(gui)

	return gui
end

--// public api
local App = {}
App.__index = App

function App.new(options)
	options = options or {}

	local scope = Imports.Scope.new()

	local self = setmetatable({
		resized = Imports.Signal.new(),

		theme = Imports.Theme.new(options.theme),
		measure = Imports.Measure.new(),
		layers = {},
		scope = scope,
	}, App)

	self.gui = hostGui(options, scope)

	self.focus = Imports.Focus.new(self)
	self.keys = Imports.Keys.new(self)

	scope:add(self.resized)

	local camera = Imports.Workspace.CurrentCamera

	if camera then
		scope:add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self.resized:fire(camera.ViewportSize)
		end))
	end

	return self
end

--// surface: get or create a named layer
function App.surface(self, name: string): Frame
	local existing = self.layers[name]

	if existing then
		return existing
	end

	local layer = Instance.new("Frame")

	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = LayerOrder[name] or 1
	layer.Name = "Layer_" .. name
	layer.Parent = self.gui

	self.layers[name] = layer
	self.scope:add(layer)

	return layer
end

function App.restyle(self, overrides)
	self.theme = self.theme:extend(overrides)
	self.measure:flush()

	return self.theme
end

--// component sugar: app:button{...} instead of Button.new(app, {...})
for name, component in Imports.Components do
	local key = string.lower(string.sub(name, 1, 1)) .. string.sub(name, 2)

	if type(component) == "table" and type((component :: any).new) == "function" then
		App[key] = function(self, props)
			return (component :: any).new(self, props or {})
		end
	end
end

function App.destroy(self)
	self.scope:destroy()
	self.layers = {}
end

return App
]=====],
	},
	{
		path = "lume/components",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name components
	@module lume/components
]]

return table.freeze({
	Surface = require(script.surface),
	Window = require(script.window),
	Modal = require(script.modal),

	Button = require(script.button),
	Toggle = require(script.toggle),
	Slider = require(script.slider),
	Select = require(script.select),

	Field = require(script.field),
	Chips = require(script.chips),
	Suggest = require(script.suggest),

	Tabs = require(script.tabs),
	Tooltip = require(script.tooltip),
	List = require(script.list),
})
]=====],
	},
	{ path = "lume/core", kind = "folder" },
	{ path = "lume/input", kind = "folder" },
	{ path = "lume/layout", kind = "folder" },
	{
		path = "lume/motion",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name motion
	@module lume/motion

	One heartbeat driver for the whole app. Tracks are keyed by
	instance + property, so retargeting a property cancels only that property
	and inherits its current velocity: nothing ever restarts from a standstill.
]]

--// imports
local Imports = {
	RunService = game:GetService("RunService"),

	Easing = require(script.easing),
	Signal = require(script.Parent.core.signal),
	Spring = require(script.spring),
	Lerp = require(script.lerp),
}

--// locals
local tracks: { [Instance]: { [string]: any } } = {}
local connection: RBXScriptConnection? = nil
local activeCount = 0

local function readSpec(app, spec)
	if type(spec) == "string" then
		return app.theme:spec(spec)
	end

	if type(spec) == "table" then
		return spec
	end

	return app.theme.motion.enter
end

local function drop(instance: Instance, property: string)
	local bucket = tracks[instance]

	if not bucket or not bucket[property] then
		return
	end

	bucket[property] = nil
	activeCount -= 1

	if next(bucket) == nil then
		tracks[instance] = nil
	end
end

local function stepTrack(track, delta: number): boolean
	local instance = track.instance

	if not instance.Parent and not track.orphanOk then
		return true
	end

	if track.springs then
		local parts = {}
		local settled = true

		for index, spring in track.springs do
			parts[index] = spring:step(delta)

			if not spring:settled(track.epsilon) then
				settled = false
			end
		end

		if settled then
			(instance :: any)[track.property] = track.goal

			return true
		end

		(instance :: any)[track.property] = Imports.Lerp.rebuild(track.kind, parts)

		return false
	end

	track.elapsed += delta

	local alpha = track.duration <= 0 and 1 or math.clamp(track.elapsed / track.duration, 0, 1)

	;(instance :: any)[track.property] = Imports.Lerp.between(track.from, track.goal, track.easing(alpha))

	return alpha >= 1
end

local function pump(delta: number)
	for instance, bucket in table.clone(tracks) do
		for property, track in table.clone(bucket) do
			if stepTrack(track, delta) then
				drop(instance, property)

				track.done()
			end
		end
	end

	if activeCount == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function ensureDriver()
	if connection then
		return
	end

	connection = Imports.RunService.Heartbeat:Connect(pump)
end

--// animation handle
local Animation = {}
Animation.__index = Animation

function Animation.active(self)
	return self.remaining > 0
end

function Animation.cancel(self)
	for _, entry in self.entries do
		drop(entry.instance, entry.property)
	end

	self.remaining = 0
	self.completed:destroy()
end

function Animation.finish(self)
	for _, entry in self.entries do
		local bucket = tracks[entry.instance]
		local track = bucket and bucket[entry.property]

		if track then
			(entry.instance :: any)[entry.property] = track.goal

			drop(entry.instance, entry.property)
		end
	end

	self.remaining = 0
	self.completed:fire()
end

--// public api
local Motion = {}

Motion.Easing = Imports.Easing
Motion.Spring = Imports.Spring
Motion.Lerp = Imports.Lerp

function Motion.animate(app, instance: Instance, props: { [string]: any }, spec: any?)
	local resolved = readSpec(app, spec)

	local animation = setmetatable({
		completed = Imports.Signal.new(),
		entries = {},
		remaining = 0,
	}, Animation)

	local springy = resolved.stiffness ~= nil

	for property, goal in props do
		local from = (instance :: any)[property]

		if not Imports.Lerp.supports(goal) then
			(instance :: any)[property] = goal
			continue
		end

		local previous = tracks[instance] and tracks[instance][property]

		if previous then
			drop(instance, property)
			previous.done()
		end

		if not springy and (resolved.duration or 0) <= 0 then
			(instance :: any)[property] = goal
			continue
		end

		local track: { [string]: any } = {
			instance = instance,
			property = property,

			kind = typeof(goal),
			from = from,
			goal = goal,

			orphanOk = resolved.orphanOk == true,
			epsilon = resolved.epsilon,
			elapsed = 0,
		}

		if springy then
			local current = Imports.Lerp.components(from)
			local target = Imports.Lerp.components(goal)

			local springs = {}

			for index, value in current do
				local spring = Imports.Spring.new(value, resolved.stiffness, resolved.damping or 24)

				--// inherit velocity from the track we just replaced
				if previous and previous.springs and previous.springs[index] then
					spring.velocity = previous.springs[index].velocity
				end

				spring:retarget(target[index] or value)

				springs[index] = spring
			end

			track.springs = springs
		else
			track.easing = Imports.Easing.resolve(resolved.easing)
			track.duration = resolved.duration or 0.2
		end

		animation.remaining += 1

		track.done = function()
			animation.remaining -= 1

			if animation.remaining <= 0 then
				animation.completed:fire()
			end
		end

		tracks[instance] = tracks[instance] or {}
		tracks[instance][property] = track

		activeCount += 1

		table.insert(animation.entries, { instance = instance, property = property })
	end

	if animation.remaining > 0 then
		ensureDriver()
	else
		task.defer(function()
			animation.completed:fire()
		end)
	end

	return animation
end

function Motion.stop(instance: Instance, property: string?)
	local bucket = tracks[instance]

	if not bucket then
		return
	end

	for key in table.clone(bucket) do
		if property == nil or key == property then
			drop(instance, key)
		end
	end
end

--// sequence: run specs back to back, returns a cancel function
function Motion.sequence(app, steps)
	local cancelled = false
	local index = 0

	local function advance()
		index += 1

		local step = steps[index]

		if cancelled or not step then
			return
		end

		Motion.animate(app, step.instance, step.props, step.spec).completed:once(advance)
	end

	advance()

	return function()
		cancelled = true
	end
end

--// stagger: same props across many instances, offset in time
function Motion.stagger(app, instances: { Instance }, props: { [string]: any }, spec: any?, delay: number)
	for index, instance in instances do
		task.delay((index - 1) * delay, function()
			if instance.Parent then
				Motion.animate(app, instance, props, spec)
			end
		end)
	end
end

return Motion
]=====],
	},
	{
		path = "lume/text",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name text
	@module lume/text
	@credit driftingAurora, dullflowerr, alias; kioukaii (original console UI, MIT)
]]

--// locals
local escapes = {
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&quot;",
	["'"] = "&apos;",
}

--// public api
local Text = {}

function Text.callable(value: any): boolean
	if type(value) == "function" then
		return true
	end

	if type(value) == "table" then
		local meta = getmetatable(value :: any)

		return type(meta) == "table" and Text.callable(meta.__call)
	end

	return false
end

function Text.trim(value: any): string
	return (string.gsub(tostring(value or ""), "^%s*(.-)%s*$", "%1"))
end

function Text.cleanStart(value: any): string
	return (string.gsub(tostring(value or ""), "^%s+", ""))
end

function Text.richEscape(value: any): string
	return (string.gsub(tostring(value or ""), "[&<>\"']", escapes))
end

function Text.linesOf(value: any): { string }
	local out: { string } = {}

	for line in string.gmatch(tostring(value or "") .. "\n", "(.-)\n") do
		table.insert(out, line)
	end

	if #out > 1 and out[#out] == "" then
		table.remove(out)
	end

	if #out == 0 then
		table.insert(out, "")
	end

	return out
end

function Text.truncate(value: any, limit: number, ellipsis: string?): string
	local text = tostring(value or "")

	if utf8.len(text) == nil or (utf8.len(text) :: number) <= limit then
		return text
	end

	local tail = ellipsis or "..."
	local offset = utf8.offset(text, math.max(1, limit - utf8.len(tail) :: number + 1))

	return string.sub(text, 1, (offset or 1) - 1) .. tail
end

function Text.tokenize(value: any): { string }
	local out: { string } = {}

	for token in string.gmatch(tostring(value or ""), "%S+") do
		table.insert(out, token)
	end

	return out
end

function Text.quoted(value: any): string
	local text = Text.trim(value)

	if text ~= "" and string.find(text, "%s") then
		return string.format("%q", text)
	end

	return text
end

function Text.slug(value: any): string
	return string.lower((string.gsub(tostring(value or ""), "%W+", "-")))
end

return table.freeze(Text)
]=====],
	},
	{
		path = "lume/theme",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name theme
	@module lume/theme
]]

--// imports
local Imports = {
	Tokens = require(script.tokens),
}

local Types = require(script.Parent.types)

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
]=====],
	},
	{
		path = "lume/types",
		kind = "module",
		source = [=====[
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
]=====],
	},
	{
		path = "lume/components/button",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name button
	@module lume/components/button
]]

--// imports
local Imports = {
	Surface = require(script.Parent.surface),
	Handle = require(script.Parent.Parent.core.handle),
	Motion = require(script.Parent.Parent.motion),
	Create = require(script.Parent.Parent.core.create),
	State = require(script.Parent.Parent.core.state),
}

--// locals
local function palette(theme, variant: string)
	if variant == "ghost" then
		return {
			background = theme.color.surfaceRaised,
			transparency = 1,
			hover = 0.85,
			text = theme.color.textMuted,
			border = false,
		}
	end

	if variant == "outline" then
		return {
			background = theme.color.surface,
			transparency = 1,
			hover = 0.88,
			text = theme.color.text,
			border = true,
		}
	end

	if variant == "accent" then
		return {
			background = theme.color.accent,
			transparency = 0.05,
			hover = 0,
			text = theme.color.surface,
			border = false,
		}
	end

	return {
		background = theme.color.surfaceRaised,
		transparency = theme.transparency.surface,
		hover = math.max(0, theme.transparency.surface - 0.06),
		text = theme.color.text,
		border = true,
	}
end

--// public api
local Button = {}

function Button.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local look = palette(theme, props.variant or "solid")
	local height = props.height or theme.size.control

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			class = "TextButton",
			name = props.name or "Button",
			ref = "root",

			color = look.background,
			transparency = look.transparency,
			border = look.border,
			radius = props.radius or theme.radius.sm,

			position = props.position,
			anchorPoint = props.anchorPoint,
			size = props.size or UDim2.fromOffset(props.width or 120, height),

			props = {
				AutoButtonColor = false,
				Text = "",

				FontFace = nil,
				TextTransparency = 1,
			},

			children = {
				Imports.Create.padding(props.paddingX or theme.space.md, 0),
				Imports.Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = props.align == "left" and Enum.HorizontalAlignment.Left
						or Enum.HorizontalAlignment.Center,
				}),
				{
					class = "TextLabel",
					ref = "label",
					props = {
						BackgroundTransparency = 1,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, height),

						Font = props.font or theme.font.medium,
						TextSize = props.textSize or theme.text.sm,
						TextColor3 = look.text,
						TextTransparency = theme.transparency.text,

						Text = Imports.State.unwrap(props.text) or "Button",
						Name = "Label",
					},
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	if Imports.State.is(props.text) then
		handle:set("Text", props.text)
		scope:add(Imports.State.observe(props.text, function(next)
			(refs.label :: TextLabel).Text = tostring(next)
		end))
	end

	local disabled = props.disabled

	local function isDisabled(): boolean
		return Imports.State.unwrap(disabled) == true
	end

	scope:add(Imports.State.observe(disabled, function(off)
		(refs.label :: TextLabel).TextTransparency = off and 0.55 or theme.transparency.text
		root.Active = not off
	end))

	scope:add(root.MouseEnter:Connect(function()
		if isDisabled() then
			return
		end

		handle:animate({ BackgroundTransparency = look.hover }, "hover")
	end))

	scope:add(root.MouseLeave:Connect(function()
		handle:animate({ BackgroundTransparency = look.transparency }, "hover")
	end))

	scope:add((root :: TextButton).MouseButton1Down:Connect(function()
		if isDisabled() then
			return
		end

		handle:animate({ Size = UDim2.fromOffset(root.AbsoluteSize.X, height - 2) }, "press")
	end))

	scope:add((root :: TextButton).MouseButton1Up:Connect(function()
		handle:animate({ Size = UDim2.fromOffset(root.AbsoluteSize.X, height) }, "layout")
	end))

	scope:add((root :: TextButton).Activated:Connect(function()
		if isDisabled() then
			return
		end

		handle:emit("activated")

		if props.onClick then
			props.onClick()
		end
	end))

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Button
]=====],
	},
	{
		path = "lume/components/chips",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name chips
	@module lume/components/chips

	Inline structured input: a row of "name: value" cells that behave like one
	field. Arrow keys and Tab walk cells, each cell auto-fits its own text,
	and a validator paints invalid cells without blocking typing.
]]

--// imports
local Imports = {
	Handle = require(script.Parent.Parent.core.handle),
	Create = require(script.Parent.Parent.core.create),
	Motion = require(script.Parent.Parent.motion),
	Text = require(script.Parent.Parent.text),
}

--// public api
local Chips = {}

function Chips.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local font = props.font or theme.font.mono
	local textSize = props.textSize or theme.text.xs
	local height = props.height or theme.size.hint

	local gap = app.measure:gap(textSize, font)

	local root, refs = Imports.Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,

			Name = props.name or "Chips",
			Position = props.position or UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(0, height),
		},
		children = {
			Imports.Create.list(Enum.FillDirection.Horizontal, gap, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		},
	})

	local handle = Imports.Handle.new(app, root, refs, scope)

	local cells: { any } = {}
	local active: number? = nil

	local function paint()
		for index, cell in cells do
			local valid = not props.validate or props.validate(cell.spec, cell.box.Text) ~= false

			cell.label.TextColor3 = active == index and theme.color.text or theme.color.textMuted
			cell.box.TextColor3 = valid and theme.color.text or theme.color.danger
		end
	end

	local function fit(cell)
		local source = cell.box.Text ~= "" and cell.box.Text or cell.placeholder

		cell.box.Size = UDim2.fromOffset(math.max(2, app.measure:exact(source, textSize, font)), height)
	end

	function handle.focusCell(self, index: number)
		if #cells == 0 then
			return
		end

		index = math.clamp(index, 1, #cells)
		active = index

		local box = cells[index].box

		if not box:IsFocused() then
			box:CaptureFocus()
		end

		box.CursorPosition = #box.Text + 1

		paint()

		self:emit("cell", index)
	end

	function handle.step(self, delta: number, force: boolean?)
		if not active then
			self:focusCell(delta > 0 and 1 or #cells)

			return true
		end

		local box = cells[active].box
		local cursor = box.CursorPosition

		if not force and delta < 0 and cursor > 1 then
			return false
		end

		if not force and delta > 0 and cursor <= #box.Text then
			return false
		end

		local target = active + delta

		if target < 1 or target > #cells then
			return false
		end

		self:focusCell(target)

		return true
	end

	function handle.setSchema(self, schema)
		for _, cell in cells do
			cell.frame:Destroy()
		end

		cells = {}
		active = nil

		for index, spec in schema or {} do
			local optional = spec.required == false or spec.default ~= nil
			local name = tostring(spec.name or ("arg" .. index))

			local cellRoot, cellRefs = Imports.Create.tree(scope, {
				class = "Frame",
				ref = "frame",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					LayoutOrder = index,
					Size = UDim2.fromOffset(0, height),
					Name = string.format("Cell_%02d", index),
				},
				children = {
					Imports.Create.list(Enum.FillDirection.Horizontal, math.max(2, gap // 2), {
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					{
						class = "TextLabel",
						ref = "label",
						props = {
							BackgroundTransparency = 1,
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromOffset(0, height),

							Font = font,
							TextSize = textSize,
							TextColor3 = theme.color.textMuted,
							TextTransparency = 1,

							Text = (optional and (name .. "?") or name) .. ":",
							LayoutOrder = 1,
							Name = "Label",
						},
					},
					{
						class = "TextBox",
						ref = "box",
						props = {
							BackgroundTransparency = 1,
							ClearTextOnFocus = false,
							MultiLine = false,

							Font = font,
							TextSize = textSize,
							TextColor3 = theme.color.text,
							TextTransparency = 1,

							PlaceholderColor3 = theme.color.textGhost,
							PlaceholderText = tostring(spec.type or "string"),
							TextXAlignment = Enum.TextXAlignment.Left,

							Size = UDim2.fromOffset(6, height),
							LayoutOrder = 2,
							Name = "Box",
							Text = "",
						},
					},
				},
			})

			local cell = {
				placeholder = tostring(spec.type or "string"),
				label = cellRefs.label :: TextLabel,
				box = cellRefs.box :: TextBox,
				frame = cellRoot,
				spec = spec,
			}

			fit(cell)

			scope:add(cell.box:GetPropertyChangedSignal("Text"):Connect(function()
				if string.find(cell.box.Text, "\t", 1, true) then
					cell.box.Text = (string.gsub(cell.box.Text, "\t", ""))

					return
				end

				fit(cell)
				paint()

				handle:emit("changed", handle:assemble())

				if props.onChange then
					props.onChange(handle:assemble())
				end
			end))

			scope:add(cell.box.Focused:Connect(function()
				active = index

				paint()
			end))

			scope:add(cell.box.FocusLost:Connect(function(submitted)
				if not submitted then
					return
				end

				if index < #cells then
					handle:focusCell(index + 1)
				else
					handle:emit("submitted", handle:assemble())

					if props.onSubmit then
						props.onSubmit(handle:assemble())
					end
				end
			end))

			cellRoot.Parent = root

			table.insert(cells, cell)
		end

		paint()

		return self:reveal()
	end

	function handle.reveal(_)
		local targets = {}

		for _, cell in cells do
			table.insert(targets, cell.label)
			table.insert(targets, cell.box)
		end

		Imports.Motion.stagger(app, targets, { TextTransparency = theme.transparency.text }, "enter", 0.012)

		return handle
	end

	function handle.values(_)
		local out = {}

		for index, cell in cells do
			out[index] = Imports.Text.trim(cell.box.Text)
		end

		return out
	end

	--// assemble: the row as one command-ish string, quoting where needed
	function handle.assemble(self, prefix: string?)
		local parts = {}

		if prefix and prefix ~= "" then
			table.insert(parts, prefix)
		end

		for _, value in self:values() do
			if value ~= "" then
				table.insert(parts, Imports.Text.quoted(value))
			end
		end

		return table.concat(parts, " ")
	end

	function handle.fill(self, values: { string })
		for index, cell in cells do
			if values[index] then
				cell.box.Text = tostring(values[index])
			end
		end

		return self
	end

	if props.schema then
		handle:setSchema(props.schema)
	end

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Chips
]=====],
	},
	{
		path = "lume/components/field",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name field
	@module lume/components/field

	Single-line text input. Owns its placeholder crossfade, an optional
	measured auto-width, and a sanitiser pass so pasted tabs and leading
	whitespace never reach the value.
]]

--// imports
local Imports = {
	Surface = require(script.Parent.surface),
	Handle = require(script.Parent.Parent.core.handle),
	Motion = require(script.Parent.Parent.motion),
	Create = require(script.Parent.Parent.core.create),
	State = require(script.Parent.Parent.core.state),
	Text = require(script.Parent.Parent.text),
}

--// public api
local Field = {}

function Field.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local height = props.height or theme.size.control
	local font = props.font or (props.mono and theme.font.mono or theme.font.body)
	local textSize = props.textSize or theme.text.sm

	local value = Imports.State.is(props.value) and props.value or Imports.State.value(tostring(props.value or ""))

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			name = props.name or "Field",
			ref = "root",

			radius = props.radius or theme.radius.sm,
			color = theme.color.surfaceSunken,
			border = props.border ~= false,
			clip = true,

			position = props.position,
			anchorPoint = props.anchorPoint,
			size = props.size or UDim2.fromOffset(props.width or 240, height),

			children = {
				Imports.Create.padding(props.paddingX or theme.space.md, 0),
				{
					class = "TextLabel",
					ref = "placeholder",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),

						Font = font,
						TextSize = textSize,
						TextColor3 = theme.color.textGhost,
						TextTransparency = 1,

						TextXAlignment = Enum.TextXAlignment.Left,
						Text = props.placeholder or "",
						Name = "Placeholder",
						ZIndex = 1,
					},
				},
				{
					class = "TextBox",
					ref = "input",
					props = {
						BackgroundTransparency = 1,
						ClearTextOnFocus = false,
						MultiLine = false,

						Font = font,
						TextSize = textSize,
						TextColor3 = props.textColor or theme.color.text,
						TextTransparency = theme.transparency.text,

						PlaceholderText = "",
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.new(1, 0, 1, 0),

						Text = value:get(),
						Name = "Input",
						ZIndex = 2,
					},
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	local input = refs.input :: TextBox
	local ghost = refs.placeholder :: TextLabel

	handle.value = value
	handle.input = input

	local function showPlaceholder(visible: boolean)
		if visible then
			ghost.Visible = true
		end

		local animation = Imports.Motion.animate(app, ghost, { TextTransparency = visible and 0.25 or 1 },
			visible and "enter" or "exit"
		)

		animation.completed:once(function()
			if not visible and ghost.Parent then
				ghost.Visible = false
			end
		end)
	end

	showPlaceholder(value:get() == "")

	local function fit()
		if not props.autoWidth then
			return
		end

		local text = input.Text ~= "" and input.Text or (props.placeholder or "")
		local width = app.measure:exact(text, textSize, font)

		handle:animate({
			Size = UDim2.fromOffset(
				math.max(props.width or 120, width + (props.paddingX or theme.space.md) * 2 + 4),
				height
			),
		}, "layout")
	end

	scope:add(input:GetPropertyChangedSignal("Text"):Connect(function()
		local sanitised = Imports.Text.cleanStart((string.gsub(input.Text, "\t", "")))

		if input.Text ~= sanitised then
			input.Text = sanitised

			return
		end

		showPlaceholder(sanitised == "")

		value:set(sanitised)
		fit()

		handle:emit("changed", sanitised)

		if props.onChange then
			props.onChange(sanitised)
		end
	end))

	scope:add(input.Focused:Connect(function()
		handle:emit("focused")

		Imports.Motion.animate(app, root, { BackgroundTransparency = math.max(0, theme.transparency.surface - 0.08) },
			"hover"
		)
	end))

	scope:add(input.FocusLost:Connect(function(submitted)
		Imports.Motion.animate(app, root, { BackgroundTransparency = theme.transparency.surface },
			"hover"
		)

		if submitted then
			handle:emit("submitted", input.Text)

			if props.onSubmit then
				props.onSubmit(input.Text)
			end
		end
	end))

	scope:add(value:subscribe(function(next)
		if input.Text ~= next then
			input.Text = next
		end
	end))

	scope:add(app.focus:register({
		region = root,
		focus = function()
			input:CaptureFocus()
			input.CursorPosition = #input.Text + 1
		end,
		blur = function()
			if input:IsFocused() then
				input:ReleaseFocus()
			end
		end,
	}))

	function handle.capture(self)
		input:CaptureFocus()
		input.CursorPosition = #input.Text + 1
	end

	function handle.clear(self)
		input.Text = ""
	end

	if props.parent then
		handle:mount(props.parent)
	end

	fit()

	return handle
end

return Field
]=====],
	},
	{
		path = "lume/components/list",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name list
	@module lume/components/list

	Virtualised scroller with two realisation modes:
	  text - lines batched into chunk labels (cheapest; rich text per line)
	  rows - one instance per visible item, built by a callback

	Both share the same windowing math, autoscroll pinning, and height cap.
]]

--// imports
local Imports = {
	Surface = require(script.Parent.surface),
	Virtual = require(script.Parent.Parent.layout.virtual),
	Handle = require(script.Parent.Parent.core.handle),
	Create = require(script.Parent.Parent.core.create),
	Motion = require(script.Parent.Parent.motion),
	Text = require(script.Parent.Parent.text),
}

--// public api
local List = {}

function List.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local mode = props.mode or "text"
	local font = props.font or theme.font.mono
	local textSize = props.textSize or theme.text.sm

	local itemHeight = props.itemHeight or app.measure:lineHeight(textSize, font)

	local virtual = Imports.Virtual.new({
		chunkSize = props.chunkSize or 64,
		itemHeight = itemHeight,
		buffer = props.buffer or 8,
	})

	local items: { any } = props.items or {}

	local root, refs = Imports.Create.tree(scope, {
		class = "ScrollingFrame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			ScrollBarThickness = props.scrollBarThickness or 3,
			ScrollBarImageTransparency = 0.6,
			ScrollBarImageColor3 = theme.color.borderStrong,

			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			CanvasSize = UDim2.fromOffset(0, 0),

			Name = props.name or "List",
			Position = props.position or UDim2.fromOffset(0, 0),
			Size = props.size or UDim2.new(1, 0, 1, 0),
		},
		children = {
			{
				class = "Frame",
				ref = "canvas",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -6, 0, 0),
					Name = "Canvas",
				},
			},
		},
	})

	local handle = Imports.Handle.new(app, root, refs, scope)

	local canvas = refs.canvas :: Frame
	local realised: { [string]: Instance } = {}

	local function viewportHeight(): number
		return root.AbsoluteSize.Y > 1 and root.AbsoluteSize.Y or (props.maxHeight or 320)
	end

	local function chunkText(first: number, last: number): string
		local out = {}

		for index = first, last do
			local item = items[index]

			if item ~= nil then
				table.insert(out, props.line and props.line(item, index) or Imports.Text.richEscape(item))
			end
		end

		return table.concat(out, "\n")
	end

	local function realiseText(first: number, last: number)
		local wanted: { [string]: boolean } = {}

		for _, chunk in virtual:chunks(first, last) do
			wanted[chunk.key] = true

			local existing = realised[chunk.key]
			local body = chunkText(chunk.first, chunk.last)

			if existing then
				(existing :: TextLabel).Text = body
				continue
			end

			local label = Instance.new("TextLabel")

			label.BackgroundTransparency = 1
			label.RichText = true
			label.TextWrapped = false

			label.Font = font
			label.TextSize = textSize
			label.TextColor3 = props.textColor or theme.color.text
			label.TextTransparency = theme.transparency.text

			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top

			label.Position = UDim2.fromOffset(0, virtual:offsetOf(chunk.first))
			label.Size = UDim2.new(1, 0, 0, (chunk.last - chunk.first + 1) * itemHeight)

			label.Name = chunk.key
			label.Text = body
			label.Parent = canvas

			realised[chunk.key] = label
		end

		for key, instance in realised do
			if not wanted[key] then
				instance:Destroy()

				realised[key] = nil
			end
		end
	end

	local function realiseRows(first: number, last: number)
		local wanted: { [string]: boolean } = {}

		for index = first, last do
			local key = string.format("Row_%05d", index)

			wanted[key] = true

			if realised[key] then
				continue
			end

			local row = props.row(items[index], index)

			if typeof(row) ~= "Instance" then
				continue
			end

			row.Name = key
			;(row :: GuiObject).Position = UDim2.fromOffset(0, virtual:offsetOf(index))
			;(row :: GuiObject).Size = UDim2.new(1, 0, 0, itemHeight)
			row.Parent = canvas

			realised[key] = row
		end

		for key, instance in realised do
			if not wanted[key] then
				instance:Destroy()

				realised[key] = nil
			end
		end
	end

	local function render()
		virtual:setCount(#items)

		local height = virtual:contentHeight()

		canvas.Size = UDim2.new(1, -6, 0, height)
		root.CanvasSize = UDim2.fromOffset(0, height)

		local first, last = virtual:range(viewportHeight())

		if mode == "rows" and props.row then
			realiseRows(first, last)
		else
			realiseText(first, last)
		end
	end

	--// height: what the parent should size itself to, capped by room
	function handle.contentHeight(_)
		return math.min(virtual:contentHeight(), props.maxHeight or 320)
	end

	function handle.setItems(self, next: { any })
		items = next or {}

		render()

		self:emit("changed", #items)

		return self
	end

	function handle.append(self, item: any)
		table.insert(items, item)

		virtual:setCount(#items)
		virtual:pin(viewportHeight())

		render()

		Imports.Motion.animate(app, root, {
			CanvasPosition = Vector2.new(0, math.max(0, virtual:contentHeight() - viewportHeight())),
		}, props.scrollSpec or "reveal")

		self:emit("appended", item)

		return self
	end

	function handle.clear(self)
		items = {}

		for key, instance in realised do
			instance:Destroy()

			realised[key] = nil
		end

		render()

		return self
	end

	function handle.pin(_)
		virtual:pin(viewportHeight())

		root.CanvasPosition = Vector2.new(0, virtual.offset)
	end

	scope:add(root:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		virtual:setOffset(root.CanvasPosition.Y, viewportHeight())

		render()
	end))

	scope:add(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(render))

	render()

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return List
]=====],
	},
	{
		path = "lume/components/modal",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name modal
	@module lume/components/modal

	Centred dialog on the modal layer, with a dimming scrim. Enter lifts the
	card a few pixels and fades the scrim; exit reverses it, and the scrim
	swallows clicks so the app underneath cannot be reached.
]]

--// imports
local Imports = {
	Placement = require(script.Parent.Parent.layout.placement),
	Surface = require(script.Parent.surface),
	Handle = require(script.Parent.Parent.core.handle),
	Create = require(script.Parent.Parent.core.create),
	Motion = require(script.Parent.Parent.motion),
	State = require(script.Parent.Parent.core.state),
}

--// public api
local Modal = {}

function Modal.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local width = props.width or 380
	local height = props.height or 200

	local root, refs = Imports.Create.tree(scope, {
		class = "TextButton",
		ref = "root",
		props = {
			BackgroundColor3 = theme.color.overlay,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Modal = true,
			Text = "",

			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Name = props.name or "Modal",
			ZIndex = 100,
		},
		children = {
			Imports.Surface.descriptor(app, {
				ref = "card",
				name = "Card",

				radius = theme.radius.lg,
				color = theme.color.surface,
				transparency = 0,
				clip = true,

				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
				size = UDim2.fromOffset(width, height),

				props = { ZIndex = 101 },

				children = {
					{
						class = "TextLabel",
						ref = "title",
						props = {
							BackgroundTransparency = 1,
							Position = UDim2.fromOffset(theme.space.lg, theme.space.lg),
							Size = UDim2.new(1, -theme.space.lg * 2, 0, 20),

							Font = theme.font.medium,
							TextSize = theme.text.lg,
							TextColor3 = theme.color.text,
							TextXAlignment = Enum.TextXAlignment.Left,

							Text = Imports.State.unwrap(props.title) or "",
							Name = "Title",
						},
					},
					{
						class = "Frame",
						ref = "content",
						props = {
							BackgroundTransparency = 1,
							Position = UDim2.fromOffset(theme.space.lg, theme.space.lg + 32),
							Size = UDim2.new(1, -theme.space.lg * 2, 1, -(theme.space.lg * 2 + 32)),
							Name = "Content",
						},
					},
				},
			}),
		},
	})

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.content = refs.content

	local card = refs.card :: Frame

	root.Parent = app:surface("modal")
	scope:add(root)

	function handle.open(self)
		root.Visible = true
		root.BackgroundTransparency = 1

		card.Position = UDim2.new(0.5, 0, 0.5, 10)

		Imports.Motion.animate(app, root, { BackgroundTransparency = theme.transparency.overlay }, "enter")
		Imports.Motion.animate(app, card, { Position = UDim2.fromScale(0.5, 0.5) }, "reveal")

		self:emit("opened")

		return self
	end

	function handle.close(self)
		Imports.Motion.animate(app, card, { Position = UDim2.new(0.5, 0, 0.5, 8) }, "exit")

		local animation = Imports.Motion.animate(app, root, { BackgroundTransparency = 1 }, "exit")

		animation.completed:once(function()
			if root.Parent then
				root.Visible = false
			end

			self:emit("closed")
		end)

		return animation
	end

	if props.dismissable ~= false then
		scope:add((root :: TextButton).Activated:Connect(function()
			handle:close()
		end))

		app.keys:bind("modalDismiss", { Enum.KeyCode.Escape }, function()
			if root.Visible then
				handle:close()
			end
		end, { sink = false })
	end

	return handle
end

return Modal
]=====],
	},
	{
		path = "lume/components/select",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name select
	@module lume/components/select

	Dropdown built on the same popover machinery as autocomplete: the trigger
	is a button, the menu is a flipped, spring-height surface on the popover
	layer, so it is never clipped by its parent.
]]

--// imports
local Imports = {
	Placement = require(script.Parent.Parent.layout.placement),
	Surface = require(script.Parent.surface),
	Handle = require(script.Parent.Parent.core.handle),
	Create = require(script.Parent.Parent.core.create),
	Motion = require(script.Parent.Parent.motion),
	State = require(script.Parent.Parent.core.state),
}

--// public api
local Select = {}

function Select.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local options: { string } = props.options or {}
	local rowHeight = props.rowHeight or theme.size.row
	local width = props.width or 180
	local height = props.height or theme.size.control

	local value = Imports.State.is(props.value) and props.value or Imports.State.value(props.value or options[1])

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			class = "TextButton",
			name = props.name or "Select",
			ref = "root",

			radius = theme.radius.sm,
			color = theme.color.surfaceRaised,
			size = UDim2.fromOffset(width, height),
			position = props.position,
			anchorPoint = props.anchorPoint,

			props = {
				AutoButtonColor = false,
				Text = "",
			},

			children = {
				Imports.Create.padding(theme.space.md, 0),
				{
					class = "TextLabel",
					ref = "label",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -14, 1, 0),

						Font = theme.font.body,
						TextSize = theme.text.sm,
						TextColor3 = theme.color.text,
						TextXAlignment = Enum.TextXAlignment.Left,

						Text = tostring(value:get() or props.placeholder or "Select"),
						Name = "Label",
					},
				},
				{
					class = "Frame",
					ref = "caret",
					props = {
						BackgroundColor3 = theme.color.textMuted,
						BorderSizePixel = 0,
						Rotation = 45,

						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, 0, 0.5, -1),
						Size = UDim2.fromOffset(5, 5),
						Name = "Caret",
					},
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.value = value

	local menuRoot, menuRefs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			name = "SelectMenu",
			ref = "menu",

			radius = theme.radius.md,
			color = theme.color.surfaceRaised,
			clip = true,
			visible = false,
			zIndex = 10,

			size = UDim2.fromOffset(width, 0),

			children = {
				{
					class = "Frame",
					ref = "rows",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Name = "Rows",
					},
					children = { Imports.Create.list(Enum.FillDirection.Vertical, 0) },
				},
			},
		})
	)

	menuRoot.Parent = app:surface("popover")

	local rows = menuRefs.rows :: Frame
	local open = false

	for index, option in options do
		local row = Instance.new("TextButton")

		row.BackgroundColor3 = theme.color.text
		row.BackgroundTransparency = 1
		row.AutoButtonColor = false
		row.BorderSizePixel = 0

		row.Font = theme.font.body
		row.TextSize = theme.text.sm
		row.TextColor3 = theme.color.textMuted
		row.TextXAlignment = Enum.TextXAlignment.Left

		row.Size = UDim2.new(1, 0, 0, rowHeight)
		row.LayoutOrder = index
		row.Text = tostring(option)
		row.Name = string.format("Option_%02d", index)

		local padding = Instance.new("UIPadding")

		padding.PaddingLeft = UDim.new(0, theme.space.md)
		padding.Parent = row

		scope:add(row.MouseEnter:Connect(function()
			Imports.Motion.animate(app, row, { BackgroundTransparency = 0.9 }, "hover")
		end))

		scope:add(row.MouseLeave:Connect(function()
			Imports.Motion.animate(app, row, { BackgroundTransparency = 1 }, "hover")
		end))

		scope:add(row.Activated:Connect(function()
			value:set(option)

			handle:close()
		end))

		row.Parent = rows
	end

	function handle.open(self)
		if open or #options == 0 then
			return
		end

		open = true

		local size = Vector2.new(width, #options * rowHeight)
		local edge = Imports.Placement.flip(root, size, props.edge or "bottom", theme.space.xs)

		menuRoot.Position = Imports.Placement.beside(root, size, edge, theme.space.xs)
		menuRoot.Visible = true

		Imports.Motion.animate(app, refs.caret, { Rotation = 225 }, "hover")

		self:emit("opened")

		return Imports.Motion.animate(app, menuRoot, { Size = UDim2.fromOffset(width, size.Y) }, "reveal")
	end

	function handle.close(self)
		if not open then
			return
		end

		open = false

		Imports.Motion.animate(app, refs.caret, { Rotation = 45 }, "hover")

		local animation = Imports.Motion.animate(app, menuRoot, { Size = UDim2.fromOffset(width, 0) }, "exit")

		animation.completed:once(function()
			if menuRoot.Parent then
				menuRoot.Visible = false
			end
		end)

		self:emit("closed")

		return animation
	end

	scope:add((root :: TextButton).Activated:Connect(function()
		if open then
			handle:close()
		else
			handle:open()
		end
	end))

	scope:add(app.focus.outside:connect(function(point)
		if not open then
			return
		end

		local origin = menuRoot.AbsolutePosition
		local bounds = menuRoot.AbsoluteSize

		local inside = point.X >= origin.X
			and point.X <= origin.X + bounds.X
			and point.Y >= origin.Y
			and point.Y <= origin.Y + bounds.Y

		if not inside then
			handle:close()
		end
	end))

	scope:add(value:subscribe(function(next)
		(refs.label :: TextLabel).Text = tostring(next)

		handle:emit("changed", next)

		if props.onChange then
			props.onChange(next)
		end
	end))

	scope:add(menuRoot)

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Select
]=====],
	},
	{
		path = "lume/components/slider",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name slider
	@module lume/components/slider

	Drag-anywhere-on-the-track slider. The fill follows a spring so a coarse
	pointer still reads as continuous, and steps are quantised on commit.
]]

--// imports
local Imports = {
	UserInputService = game:GetService("UserInputService"),

	Surface = require(script.Parent.surface),
	Handle = require(script.Parent.Parent.core.handle),
	Motion = require(script.Parent.Parent.motion),
	Create = require(script.Parent.Parent.core.create),
	State = require(script.Parent.Parent.core.state),
}

--// public api
local Slider = {}

function Slider.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local min = props.min or 0
	local max = props.max or 1
	local step = props.step

	local width = props.width or 200
	local height = props.height or 20
	local trackHeight = props.trackHeight or 4
	local knob = props.knobSize or 12

	local value = Imports.State.is(props.value) and props.value or Imports.State.value(props.value or min)

	local function quantise(raw: number): number
		local clamped = math.clamp(raw, min, max)

		if not step or step <= 0 then
			return clamped
		end

		return math.clamp(min + math.round((clamped - min) / step) * step, min, max)
	end

	local function alphaOf(): number
		if max == min then
			return 0
		end

		return math.clamp((value:get() - min) / (max - min), 0, 1)
	end

	local root, refs = Imports.Create.tree(scope, {
		class = "TextButton",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",

			Name = props.name or "Slider",
			Position = props.position or UDim2.fromOffset(0, 0),
			AnchorPoint = props.anchorPoint or Vector2.zero,
			Size = UDim2.fromOffset(width, height),
		},
		children = {
			Imports.Surface.descriptor(app, {
				ref = "track",
				name = "Track",
				radius = theme.radius.pill,
				color = theme.color.surfaceSunken,
				transparency = 0,
				border = false,
				props = {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(1, 0, 0, trackHeight),
				},
				children = {
					{
						class = "Frame",
						ref = "fill",
						props = {
							BackgroundColor3 = theme.color.accent,
							BackgroundTransparency = 0,
							BorderSizePixel = 0,
							Size = UDim2.new(0, 0, 1, 0),
							Name = "Fill",
						},
						children = { Imports.Create.corner(theme.radius.pill) },
					},
				},
			}),
			{
				class = "Frame",
				ref = "knob",
				props = {
					BackgroundColor3 = theme.color.text,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(knob, knob),

					Name = "Knob",
					ZIndex = 3,
				},
				children = { Imports.Create.corner(theme.radius.pill) },
			},
		},
	})

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.value = value

	local track = refs.track :: Frame
	local fill = refs.fill :: Frame
	local knobFrame = refs.knob :: Frame

	local function render(animated: boolean)
		local alpha = alphaOf()
		local spec = animated and theme.motion.layout or theme.motion.instant

		Imports.Motion.animate(app, fill, {
			Size = UDim2.new(alpha, 0, 1, 0),
		}, spec)

		Imports.Motion.animate(app, knobFrame, {
			Position = UDim2.new(alpha, 0, 0.5, 0),
		}, spec)
	end

	render(false)

	scope:add(value:subscribe(function(next)
		render(true)

		handle:emit("changed", next)

		if props.onChange then
			props.onChange(next)
		end
	end))

	local dragging = false

	local function readPoint(x: number)
		local origin = track.AbsolutePosition.X
		local span = math.max(1, track.AbsoluteSize.X)

		value:set(quantise(min + ((x - origin) / span) * (max - min)))
	end

	scope:add(root.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		if Imports.State.unwrap(props.disabled) == true then
			return
		end

		dragging = true

		Imports.Motion.animate(app, knobFrame, {
			Size = UDim2.fromOffset(knob + 4, knob + 4),
		}, "press")

		readPoint(input.Position.X)
	end))

	scope:add(Imports.UserInputService.InputChanged:Connect(function(input)
		if not dragging or input.UserInputType == Enum.UserInputType.Keyboard then
			return
		end

		readPoint(input.Position.X)
	end))

	scope:add(Imports.UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end

		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		dragging = false

		Imports.Motion.animate(app, knobFrame, {
			Size = UDim2.fromOffset(knob, knob),
		}, "layout")

		handle:emit("committed", value:get())
	end))

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Slider
]=====],
	},
	{
		path = "lume/components/suggest",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name suggest
	@module lume/components/suggest

	Autocomplete popover. Ranking is prefix-first, then substring, so the
	obvious completion is always the default selection. Reveal and dismissal
	are spring height changes, never visibility flips.
]]

--// imports
local Imports = {
	Placement = require(script.Parent.Parent.layout.placement),
	Surface = require(script.Parent.surface),
	Handle = require(script.Parent.Parent.core.handle),
	Create = require(script.Parent.Parent.core.create),
	Motion = require(script.Parent.Parent.motion),
	Text = require(script.Parent.Parent.text),
}

--// locals
local function rank(source: { string }, query: string, limit: number): { string }
	local needle = string.lower(Imports.Text.trim(query))

	local prefix: { string } = {}
	local infix: { string } = {}

	for _, candidate in source do
		local lower = string.lower(candidate)

		if needle == "" or string.sub(lower, 1, #needle) == needle then
			table.insert(prefix, candidate)
		elseif string.find(lower, needle, 1, true) then
			table.insert(infix, candidate)
		end
	end

	table.sort(prefix)
	table.sort(infix)

	local out: { string } = {}

	for _, value in prefix do
		table.insert(out, value)
	end

	for _, value in infix do
		table.insert(out, value)
	end

	while #out > limit do
		table.remove(out)
	end

	return out
end

--// public api
local Suggest = {}

Suggest.rank = rank

function Suggest.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local rowHeight = props.rowHeight or theme.size.row
	local limit = props.limit or 6
	local gap = props.gap or theme.space.xs

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			name = props.name or "Suggest",
			ref = "root",

			radius = theme.radius.md,
			color = theme.color.surfaceRaised,
			clip = true,
			visible = false,

			size = UDim2.fromOffset(props.width or 240, 0),

			children = {
				{
					class = "Frame",
					ref = "rows",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Name = "Rows",
					},
					children = { Imports.Create.list(Enum.FillDirection.Vertical, 0) },
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	local rows = refs.rows :: Frame
	local current: { string } = {}
	local selected = 0

	local function paint()
		for index, child in rows:GetChildren() do
			if child:IsA("TextButton") then
				local active = tonumber(child:GetAttribute("index")) == selected

				Imports.Motion.animate(app, child, {
					BackgroundTransparency = active and 0.9 or 1,
				}, "hover")

				;(child :: TextButton).TextColor3 = active and theme.color.text or theme.color.textMuted
			end
		end
	end

	local function accept(index: number)
		local value = current[index]

		if not value then
			return false
		end

		handle:emit("accepted", value)

		if props.onAccept then
			props.onAccept(value)
		end

		handle:hide()

		return true
	end

	local function build()
		for _, child in rows:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for index, value in current do
			local button = Instance.new("TextButton")

			button.BackgroundColor3 = theme.color.text
			button.BackgroundTransparency = 1
			button.AutoButtonColor = false
			button.BorderSizePixel = 0

			button.Font = props.font or theme.font.mono
			button.TextSize = props.textSize or theme.text.sm
			button.TextColor3 = theme.color.textMuted
			button.TextXAlignment = Enum.TextXAlignment.Left

			button.Size = UDim2.new(1, 0, 0, rowHeight)
			button.LayoutOrder = index
			button.Text = value
			button.Name = string.format("Row_%02d", index)

			button:SetAttribute("index", index)

			local padding = Instance.new("UIPadding")

			padding.PaddingLeft = UDim.new(0, theme.space.md)
			padding.Parent = button

			button.MouseEnter:Connect(function()
				selected = index

				paint()
			end)

			button.Activated:Connect(function()
				accept(index)
			end)

			button.Parent = rows
		end

		paint()
	end

	function handle.update(self, query: string, source: { string }?)
		local pool = source or props.source or {}

		if type(pool) == "function" then
			pool = pool(query)
		end

		current = rank(pool, query, limit)
		selected = #current > 0 and 1 or 0

		if #current == 0 then
			return self:hide()
		end

		build()

		if props.anchor then
			local size = Vector2.new(root.AbsoluteSize.X, #current * rowHeight)
			local edge = Imports.Placement.flip(props.anchor, size, props.edge or "bottom", gap)

			root.Position = Imports.Placement.beside(props.anchor, size, edge, gap)
		end

		root.Visible = true

		return Imports.Motion.animate(app, root, {
			Size = UDim2.fromOffset(props.width or root.AbsoluteSize.X, #current * rowHeight),
		}, "reveal")
	end

	function handle.move(self, delta: number)
		if #current == 0 then
			return false
		end

		selected = ((selected - 1 + delta) % #current) + 1

		paint()

		return true
	end

	function handle.accept(_)
		return accept(selected)
	end

	function handle.selection(_)
		return current[selected]
	end

	function handle.hide(self)
		if not root.Visible then
			return
		end

		local animation = Imports.Motion.animate(app, root, { Size = UDim2.fromOffset(root.AbsoluteSize.X, 0) }, "exit")

		animation.completed:once(function()
			if root.Parent then
				root.Visible = false
			end
		end)

		self:emit("hidden")

		return animation
	end

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Suggest
]=====],
	},
	{
		path = "lume/components/surface",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name surface
	@module lume/components/surface

	The shared shell every floating component sits on: background, corner,
	hairline border, and an optional 9-sliced shadow. Shadows are opt-in via
	theme.shadow.image so the library ships with no baked asset ids.
]]

--// imports
local Imports = {
	Create = require(script.Parent.Parent.core.create),
}

--// public api
local Surface = {}

function Surface.descriptor(app, options)
	local theme = app.theme
	options = options or {}

	local children = {
		Imports.Create.corner(options.radius or theme.radius.md),
	}

	if options.border ~= false then
		table.insert(children, Imports.Create.stroke(theme.color.border, theme.stroke.hairline, theme.transparency.border))
	end

	if options.padding then
		table.insert(children, Imports.Create.padding(options.padding, options.paddingY))
	end

	for _, child in options.children or {} do
		table.insert(children, child)
	end

	local props: { [string]: any } = {
		BackgroundColor3 = options.color or theme.color.surface,
		BackgroundTransparency = options.transparency or theme.transparency.surface,

		BorderSizePixel = 0,
		Name = options.name or "Surface",

		AnchorPoint = options.anchorPoint or Vector2.zero,
		Position = options.position or UDim2.fromOffset(0, 0),
		Size = options.size or UDim2.fromOffset(240, theme.size.control),

		ClipsDescendants = options.clip == true,
		Visible = options.visible ~= false,
		ZIndex = options.zIndex or 1,
	}

	for key, value in options.props or {} do
		props[key] = value
	end

	return {
		class = options.class or "Frame",
		ref = options.ref,
		props = props,
		events = options.events,
		children = children,
	}
end

--// shadow: sits behind a target and tracks its bounds
function Surface.shadow(app, options)
	local theme = app.theme
	local shadow = theme.shadow or {}

	if not shadow.image or shadow.image == "" then
		return nil
	end

	return {
		class = "ImageLabel",
		ref = options and options.ref or nil,
		props = {
			BackgroundTransparency = 1,
			Image = shadow.image,
			ImageColor3 = shadow.color or Color3.new(),
			ImageTransparency = shadow.transparency or theme.transparency.shadow,

			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = shadow.slice or Rect.new(64, 64, 64, 64),

			Name = "Shadow",
			ZIndex = 0,
		},
	}
end

--// track: keep a shadow glued to its target with a uniform spread
function Surface.track(shadowInstance: ImageLabel?, target: GuiObject, spread: number)
	if not shadowInstance then
		return
	end

	local function sync()
		shadowInstance.Position = UDim2.new(
			target.Position.X.Scale,
			target.Position.X.Offset - spread,
			target.Position.Y.Scale,
			target.Position.Y.Offset - spread
		)

		shadowInstance.Size = UDim2.fromOffset(
			target.AbsoluteSize.X + spread * 2,
			target.AbsoluteSize.Y + spread * 2
		)

		shadowInstance.AnchorPoint = target.AnchorPoint
	end

	sync()

	return sync
end

return table.freeze(Surface)
]=====],
	},
	{
		path = "lume/components/tabs",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name tabs
	@module lume/components/tabs

	Tab strip with a spring indicator. The indicator is a sibling of the tab
	buttons rather than a child, so it can travel across them continuously.
]]

--// imports
local Imports = {
	Handle = require(script.Parent.Parent.core.handle),
	Create = require(script.Parent.Parent.core.create),
	Motion = require(script.Parent.Parent.motion),
	State = require(script.Parent.Parent.core.state),
}

--// public api
local Tabs = {}

function Tabs.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local items = props.items or {}
	local height = props.height or theme.size.control
	local textSize = props.textSize or theme.text.sm
	local font = props.font or theme.font.medium
	local padding = props.paddingX or theme.space.md

	local active = Imports.State.is(props.active) and props.active
		or Imports.State.value(props.active or (items[1] and (items[1].key or items[1])))

	local root, refs = Imports.Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			Name = props.name or "Tabs",
			Position = props.position or UDim2.fromOffset(0, 0),
			Size = props.size or UDim2.new(1, 0, 0, height),
		},
		children = {
			{
				class = "Frame",
				ref = "indicator",
				props = {
					BackgroundColor3 = theme.color.accent,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.fromOffset(0, 2),

					Name = "Indicator",
					ZIndex = 3,
				},
				children = { Imports.Create.corner(theme.radius.pill) },
			},
			{
				class = "Frame",
				ref = "strip",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Name = "Strip",
				},
				children = { Imports.Create.list(Enum.FillDirection.Horizontal, props.gap or theme.space.xs) },
			},
		},
	})

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.active = active

	local strip = refs.strip :: Frame
	local indicator = refs.indicator :: Frame
	local buttons: { [string]: TextButton } = {}

	local function keyOf(item): string
		return tostring(type(item) == "table" and (item.key or item.label) or item)
	end

	local function labelOf(item): string
		return tostring(type(item) == "table" and (item.label or item.key) or item)
	end

	local function moveIndicator(animated: boolean)
		local button = buttons[tostring(active:get())]

		if not button then
			return
		end

		Imports.Motion.animate(app, indicator, {
			Position = UDim2.new(0, button.AbsolutePosition.X - strip.AbsolutePosition.X, 1, 0),
			Size = UDim2.fromOffset(button.AbsoluteSize.X, 2),
		}, animated and "layout" or "instant")
	end

	local function paint()
		local key = tostring(active:get())

		for name, button in buttons do
			Imports.Motion.animate(app, button, {
				TextColor3 = name == key and theme.color.text or theme.color.textMuted,
			}, "hover")
		end

		moveIndicator(true)
	end

	for index, item in items do
		local key = keyOf(item)

		local button = Instance.new("TextButton")

		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.BorderSizePixel = 0

		button.Font = font
		button.TextSize = textSize
		button.TextColor3 = theme.color.textMuted

		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.fromOffset(0, height)
		button.LayoutOrder = index
		button.Text = labelOf(item)
		button.Name = "Tab_" .. key

		local pad = Instance.new("UIPadding")

		pad.PaddingLeft = UDim.new(0, padding)
		pad.PaddingRight = UDim.new(0, padding)
		pad.Parent = button

		scope:add(button.Activated:Connect(function()
			active:set(key)
		end))

		button.Parent = strip
		buttons[key] = button
	end

	scope:add(active:subscribe(function(key)
		paint()

		handle:emit("changed", key)

		if props.onChange then
			props.onChange(key)
		end
	end))

	scope:add(strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		moveIndicator(false)
	end))

	task.defer(function()
		if scope:alive() then
			paint()
			moveIndicator(false)
		end
	end)

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Tabs
]=====],
	},
	{
		path = "lume/components/toggle",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name toggle
	@module lume/components/toggle
]]

--// imports
local Imports = {
	Surface = require(script.Parent.surface),
	Handle = require(script.Parent.Parent.core.handle),
	Motion = require(script.Parent.Parent.motion),
	Create = require(script.Parent.Parent.core.create),
	State = require(script.Parent.Parent.core.state),
}

--// public api
local Toggle = {}

function Toggle.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local height = props.height or 22
	local width = props.width or 40
	local inset = 3
	local knob = height - inset * 2

	local value = Imports.State.is(props.value) and props.value or Imports.State.value(props.value == true)

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			class = "TextButton",
			name = props.name or "Toggle",
			ref = "root",

			radius = theme.radius.pill,
			color = theme.color.surfaceSunken,
			size = UDim2.fromOffset(width, height),
			position = props.position,
			anchorPoint = props.anchorPoint,

			props = {
				AutoButtonColor = false,
				Text = "",
			},

			children = {
				{
					class = "Frame",
					ref = "knob",
					props = {
						BackgroundColor3 = theme.color.textMuted,
						BackgroundTransparency = 0,
						BorderSizePixel = 0,

						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, inset, 0.5, 0),
						Size = UDim2.fromOffset(knob, knob),

						Name = "Knob",
						ZIndex = 2,
					},
					children = { Imports.Create.corner(theme.radius.pill) },
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.value = value

	local knobFrame = refs.knob :: Frame

	local function render(on: boolean, animated: boolean)
		local spec = animated and theme.motion.layout or theme.motion.instant

		Imports.Motion.animate(app, knobFrame, {
			Position = UDim2.new(0, on and (width - knob - inset) or inset, 0.5, 0),
			BackgroundColor3 = on and theme.color.surface or theme.color.textMuted,
		}, spec)

		Imports.Motion.animate(app, root, {
			BackgroundColor3 = on and theme.color.accent or theme.color.surfaceSunken,
			BackgroundTransparency = on and 0 or theme.transparency.surface,
		}, animated and theme.motion.hover or theme.motion.instant)
	end

	render(value:get(), false)

	scope:add(value:subscribe(function(on)
		render(on == true, true)

		handle:emit("changed", on == true)

		if props.onChange then
			props.onChange(on == true)
		end
	end))

	scope:add((root :: TextButton).Activated:Connect(function()
		if Imports.State.unwrap(props.disabled) == true then
			return
		end

		value:set(not value:get())
	end))

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Toggle
]=====],
	},
	{
		path = "lume/components/tooltip",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name tooltip
	@module lume/components/tooltip

	Hover popover on the tooltip layer. Delay in, no delay out, flipped away
	from viewport edges, and sized from measured text rather than guesses.
]]

--// imports
local Imports = {
	Placement = require(script.Parent.Parent.layout.placement),
	Surface = require(script.Parent.surface),
	Handle = require(script.Parent.Parent.core.handle),
	Create = require(script.Parent.Parent.core.create),
	Motion = require(script.Parent.Parent.motion),
	State = require(script.Parent.Parent.core.state),
}

--// public api
local Tooltip = {}

function Tooltip.attach(app, target: GuiObject, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local textSize = props.textSize or theme.text.xs
	local font = props.font or theme.font.body
	local padX = theme.space.sm
	local padY = theme.space.xs
	local gap = props.gap or theme.space.xs

	local text = props.text or ""

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			name = "Tooltip",
			ref = "root",

			radius = theme.radius.sm,
			color = theme.color.surfaceRaised,
			transparency = 0,
			visible = false,
			zIndex = 1000,

			size = UDim2.fromOffset(0, 0),

			children = {
				{
					class = "TextLabel",
					ref = "label",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),

						Font = font,
						TextSize = textSize,
						TextColor3 = theme.color.text,
						TextTransparency = 1,

						Text = tostring(Imports.State.unwrap(text)),
						Name = "Label",
					},
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	root.Parent = app:surface("tooltip")
	scope:add(root)

	local token = 0

	local function sizeFor(body: string): Vector2
		local measured = app.measure:text(body, textSize, font)

		return Vector2.new(math.ceil(measured.X) + padX * 2, math.ceil(measured.Y) + padY * 2)
	end

	function handle.show(self)
		local body = tostring(Imports.State.unwrap(text))

		if body == "" then
			return
		end

		;(refs.label :: TextLabel).Text = body

		local size = sizeFor(body)
		local edge = Imports.Placement.flip(target, size, props.edge or "top", gap)

		root.Size = UDim2.fromOffset(size.X, size.Y)
		root.Position = Imports.Placement.beside(target, size, edge, gap)
		root.Visible = true

		Imports.Motion.animate(app, refs.label, { TextTransparency = 0 }, "enter")

		return Imports.Motion.animate(app, root, { BackgroundTransparency = 0 }, "enter")
	end

	function handle.hide(self)
		Imports.Motion.animate(app, refs.label, { TextTransparency = 1 }, "exit")

		local animation = Imports.Motion.animate(app, root, { BackgroundTransparency = 1 }, "exit")

		animation.completed:once(function()
			if root.Parent then
				root.Visible = false
			end
		end)

		return animation
	end

	function handle.setText(self, next)
		text = next

		return self
	end

	scope:add(target.MouseEnter:Connect(function()
		token += 1

		local mine = token

		task.delay(props.delay or 0.35, function()
			if scope:alive() and token == mine then
				handle:show()
			end
		end)
	end))

	scope:add(target.MouseLeave:Connect(function()
		token += 1

		handle:hide()
	end))

	return handle
end

Tooltip.new = Tooltip.attach

return Tooltip
]=====],
	},
	{
		path = "lume/components/window",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name window
	@module lume/components/window

	A floating, draggable, content-sized surface. Height and width are driven
	by springs so growing content pushes the frame instead of snapping it,
	and the top edge stays put when a bottom-anchored window grows.
]]

--// imports
local Imports = {
	Placement = require(script.Parent.Parent.layout.placement),
	Surface = require(script.Parent.surface),
	Handle = require(script.Parent.Parent.core.handle),
	Create = require(script.Parent.Parent.core.create),
	Motion = require(script.Parent.Parent.motion),
	State = require(script.Parent.Parent.core.state),
	Drag = require(script.Parent.Parent.input.drag),
}

--// public api
local Window = {}

function Window.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local width = props.width or 360
	local titleHeight = props.titleHeight or theme.size.control

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			name = props.name or "Window",
			ref = "root",

			radius = props.radius or theme.radius.lg,
			color = theme.color.surface,
			clip = true,

			anchorPoint = props.anchorPoint or Vector2.zero,
			position = props.position or Imports.Placement.center(Vector2.new(width, 200)),
			size = UDim2.fromOffset(width, titleHeight),

			children = {
				{
					class = "Frame",
					ref = "titlebar",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, titleHeight),
						Name = "Titlebar",
						ZIndex = 3,
					},
					children = {
						Imports.Create.padding(theme.space.md, 0),
						Imports.Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						{
							class = "TextLabel",
							ref = "title",
							props = {
								BackgroundTransparency = 1,
								AutomaticSize = Enum.AutomaticSize.X,
								Size = UDim2.fromOffset(0, titleHeight),

								Font = theme.font.medium,
								TextSize = theme.text.sm,
								TextColor3 = theme.color.text,
								TextXAlignment = Enum.TextXAlignment.Left,

								Text = Imports.State.unwrap(props.title) or "Window",
								Name = "Title",
							},
						},
					},
				},
				{
					class = "Frame",
					ref = "content",
					props = {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(0, titleHeight),
						Size = UDim2.new(1, 0, 1, -titleHeight),
						Name = "Content",
						ZIndex = 2,
					},
					children = props.padded ~= false
							and { Imports.Create.padding(theme.space.md, theme.space.md) }
						or {},
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.content = refs.content
	handle.titlebar = refs.titlebar

	if Imports.State.is(props.title) then
		scope:add(Imports.State.observe(props.title, function(next)
			(refs.title :: TextLabel).Text = tostring(next)
		end))
	end

	--// drag: titlebar only, so content interaction never moves the window
	if props.draggable ~= false then
		handle.drag = Imports.Drag.attach(app, root, {
			handles = { refs.titlebar },
			scope = scope,
		})

		handle.drag.moved:connect(function(position)
			handle:emit("moved", position)
		end)
	end

	--// resize: the one call that keeps stacked windows visually anchored
	function handle.resize(self, contentHeight: number, spec)
		local extra = titleHeight + (props.padded ~= false and theme.space.md * 2 or 0)
		local target = math.max(titleHeight, contentHeight + extra)

		local grew = target - root.AbsoluteSize.Y

		if not Imports.Placement.isTop(root) and grew ~= 0 then
			Imports.Motion.animate(app, root, {
				Position = Imports.Placement.withStack(root.Position, root, grew),
			}, spec or "layout")
		end

		return Imports.Motion.animate(app, root, {
			Size = UDim2.fromOffset(self.width or width, target),
		}, spec or "layout")
	end

	function handle.setWidth(self, next: number, spec)
		self.width = next

		return Imports.Motion.animate(app, root, {
			Size = UDim2.fromOffset(next, root.AbsoluteSize.Y),
		}, spec or "layout")
	end

	function handle.open(self)
		root.Visible = true
		root.GroupTransparency = 1

		Imports.Motion.animate(app, root, { GroupTransparency = 0 }, "enter")

		local settled = root.Position

		root.Position = Imports.Placement.stacked(settled, root, 12, 0)

		self:emit("opened")

		return Imports.Motion.animate(app, root, { Position = settled }, "reveal")
	end

	function handle.close(self)
		local animation = Imports.Motion.animate(app, root, { GroupTransparency = 1 }, "exit")

		animation.completed:once(function()
			if root.Parent then
				root.Visible = false
			end

			self:emit("closed")
		end)

		return animation
	end

	root.GroupTransparency = 0

	if props.parent then
		handle:mount(props.parent)
	else
		handle:mount(app:surface(props.layer or "default"))
	end

	return handle
end

return Window
]=====],
	},
	{
		path = "lume/core/create",
		kind = "module",
		source = [=====[
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
	State = require(script.Parent.state),
}

local Types = require(script.Parent.Parent.types)

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
]=====],
	},
	{
		path = "lume/core/handle",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name handle
	@module lume/core/handle

	The imperative half of the hybrid API. Every component returns a handle:
	a stable object you can animate, mutate, mount, and destroy, with its
	refs exposed for escape hatches.
]]

--// imports
local Imports = {
	Motion = require(script.Parent.Parent.motion),
	Signal = require(script.Parent.signal),
	State = require(script.Parent.state),
}

--// public api
local Handle = {}
Handle.__index = Handle

function Handle.new(app, root, refs, scope)
	return setmetatable({
		signals = {},

		app = app,
		root = root,
		refs = refs,
		scope = scope,

		destroyed = false,
	}, Handle)
end

function Handle.instance(self)
	return self.root
end

function Handle.mount(self, parent)
	self.root.Parent = parent

	return self
end

function Handle.signal(self, name)
	local existing = self.signals[name]

	if existing then
		return existing
	end

	local signal = Imports.Signal.new()

	self.signals[name] = signal
	self.scope:add(signal)

	return signal
end

function Handle.on(self, name, fn)
	return self:signal(name):connect(fn)
end

function Handle.emit(self, name, ...)
	local signal = self.signals[name]

	if signal then
		signal:fire(...)
	end
end

function Handle.animate(self, props, spec)
	return Imports.Motion.animate(self.app, self.root, props, spec)
end

--// set: write a prop through, accepting a constant or a source
function Handle.set(self, key, value)
	self.scope:add(Imports.State.observe(value, function(next)
		(self.root :: any)[key] = next
	end))

	return self
end

function Handle.visible(self, visible, spec)
	local theme = self.app.theme

	if visible then
		self.root.Visible = true

		return self:animate({ GroupTransparency = 0 }, spec or theme.motion.enter)
	end

	local animation = self:animate({ GroupTransparency = 1 }, spec or theme.motion.exit)

	animation.completed:once(function()
		if not self.destroyed then
			self.root.Visible = false
		end
	end)

	return animation
end

function Handle.destroy(self)
	if self.destroyed then
		return
	end

	self.destroyed = true

	self:emit("destroyed")
	self.scope:destroy()
end

return Handle
]=====],
	},
	{
		path = "lume/core/scope",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name scope
	@module lume/core/scope

	Owns everything a component creates: instances, connections, animations,
	subscriptions, child scopes. Destroying a scope unwinds in reverse order,
	which is what keeps exit motion from racing teardown.
]]

--// locals
local function unwind(item: any)
	if type(item) == "function" then
		item()
		return
	end

	if typeof(item) == "Instance" then
		item:Destroy()
		return
	end

	if typeof(item) == "RBXScriptConnection" then
		if item.Connected then
			item:Disconnect()
		end

		return
	end

	if type(item) == "table" then
		local destroy = (item :: any).destroy or (item :: any).Destroy

		if type(destroy) == "function" then
			destroy(item)
		end
	end
end

--// public api
local Scope = {}
Scope.__index = Scope

function Scope.new(parent)
	local self = setmetatable({
		items = {},
		children = {},
		parent = parent,
		dead = false,
	}, Scope)

	if parent then
		table.insert(parent.children, self)
	end

	return self
end

function Scope.add(self, item)
	if self.dead then
		unwind(item)

		return item
	end

	table.insert(self.items, item)

	return item
end

function Scope.child(self)
	return Scope.new(self)
end

function Scope.alive(self)
	return not self.dead
end

function Scope.destroy(self)
	if self.dead then
		return
	end

	self.dead = true

	for index = #self.children, 1, -1 do
		self.children[index]:destroy()
	end

	for index = #self.items, 1, -1 do
		unwind(self.items[index])
	end

	self.children = {}
	self.items = {}

	local parent = self.parent

	if parent then
		local position = table.find(parent.children, self)

		if position then
			table.remove(parent.children, position)
		end
	end
end

return Scope
]=====],
	},
	{
		path = "lume/core/signal",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name signal
	@module lume/core/signal
]]

--// public api
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		handlers = {},
		nextId = 0,
	}, Signal)
end

function Signal.connect(self, fn)
	if type(fn) ~= "function" then
		return function() end
	end

	self.nextId += 1

	local id = self.nextId
	self.handlers[id] = fn

	return function()
		self.handlers[id] = nil
	end
end

function Signal.once(self, fn)
	local disconnect

	disconnect = self:connect(function(...)
		disconnect()
		fn(...)
	end)

	return disconnect
end

function Signal.fire(self, ...)
	for _, handler in table.clone(self.handlers) do
		handler(...)
	end
end

function Signal.destroy(self)
	self.handlers = {}
end

return Signal
]=====],
	},
	{
		path = "lume/core/state",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name state
	@module lume/core/state

	Explicit-dependency reactive primitives. No global tracking: a computed
	declares what it reads, so the graph stays inspectable and strict-typeable.
]]

--// locals
local batchDepth = 0
local pending: { any } = {}

local function flush(source: any)
	if batchDepth > 0 then
		if not table.find(pending, source) then
			table.insert(pending, source)
		end

		return
	end

	local value = source:get()

	for _, handler in table.clone(source.subs) do
		handler(value)
	end
end

--// value
local Value = {}
Value.__index = Value

function Value.get(self)
	return self.current
end

function Value.set(self, next)
	if self.current == next then
		return
	end

	self.current = next

	flush(self)
end

function Value.update(self, fn)
	self:set(fn(self.current))
end

function Value.subscribe(self, fn)
	self.nextId += 1

	local id = self.nextId
	self.subs[id] = fn

	return function()
		self.subs[id] = nil
	end
end

--// computed
local Computed = {}
Computed.__index = Computed

function Computed.get(self)
	if self.stale then
		self.current = self.compute()
		self.stale = false
	end

	return self.current
end

function Computed.subscribe(self, fn)
	self.nextId += 1

	local id = self.nextId
	self.subs[id] = fn

	return function()
		self.subs[id] = nil
	end
end

function Computed.destroy(self)
	for _, unsubscribe in self.links do
		unsubscribe()
	end

	self.links = {}
	self.subs = {}
end

--// public api
local State = {}

State.Value = Value
State.Computed = Computed

function State.value(initial)
	return setmetatable({
		kind = "value",
		current = initial,

		subs = {},
		nextId = 0,
	}, Value)
end

function State.is(candidate): boolean
	if type(candidate) ~= "table" then
		return false
	end

	local kind = (candidate :: any).kind

	return kind == "value" or kind == "computed"
end

function State.unwrap(candidate)
	if State.is(candidate) then
		return (candidate :: any):get()
	end

	return candidate
end

function State.computed(sources, compute)
	local self = setmetatable({
		kind = "computed",

		current = nil,
		stale = true,

		links = {},
		subs = {},
		nextId = 0,
	}, Computed)

	self.compute = function()
		local values = {}

		for index, source in sources do
			values[index] = State.unwrap(source)
		end

		return compute(table.unpack(values, 1, #sources))
	end

	for _, source in sources do
		if State.is(source) then
			table.insert(
				self.links,
				(source :: any):subscribe(function()
					self.stale = true

					flush(self)
				end)
			)
		end
	end

	return self
end

--// observe: uniform reader for constants and sources alike
function State.observe(candidate, fn)
	fn(State.unwrap(candidate))

	if State.is(candidate) then
		return (candidate :: any):subscribe(fn)
	end

	return function() end
end

function State.batch(fn)
	batchDepth += 1

	local ok, err = pcall(fn)

	batchDepth -= 1

	if batchDepth == 0 then
		local queued = table.clone(pending)

		table.clear(pending)

		for _, source in queued do
			flush(source)
		end
	end

	if not ok then
		error(err, 2)
	end
end

return State
]=====],
	},
	{
		path = "lume/input/drag",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name drag
	@module lume/input/drag

	Pointer dragging with viewport clamping. Handles are opt-in regions;
	excluded regions (scroll bodies, inputs) never start a drag.
]]

--// imports
local Imports = {
	UserInputService = game:GetService("UserInputService"),

	Placement = require(script.Parent.Parent.layout.placement),
	Signal = require(script.Parent.Parent.core.signal),
}

--// locals
local function pointIn(object: GuiObject?, point: Vector2): boolean
	if not object or typeof(object) ~= "Instance" or not object.Visible then
		return false
	end

	local origin = object.AbsolutePosition
	local bounds = object.AbsoluteSize

	return point.X >= origin.X
		and point.X <= origin.X + bounds.X
		and point.Y >= origin.Y
		and point.Y <= origin.Y + bounds.Y
end

--// public api
local Drag = {}
Drag.__index = Drag

function Drag.attach(app, object: GuiObject, options)
	local self = setmetatable({
		moved = Imports.Signal.new(),
		began = Imports.Signal.new(),
		ended = Imports.Signal.new(),

		excludes = options.excludes or {},
		handles = options.handles or {},
		axis = options.axis or "both",
		inset = options.inset or 8,

		enabled = options.enabled ~= false,
		dragging = false,

		origin = Vector2.zero,
		start = object.Position,

		object = object,
		app = app,
	}, Drag)

	local scope = options.scope or app.scope

	local function allowed(point: Vector2): boolean
		for _, exclude in self.excludes do
			if pointIn(exclude, point) then
				return false
			end
		end

		if #self.handles == 0 then
			return pointIn(object, point)
		end

		for _, handle in self.handles do
			if pointIn(handle, point) then
				return true
			end
		end

		return false
	end

	scope:add(object.InputBegan:Connect(function(input)
		if not self.enabled or self.dragging then
			return
		end

		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local point = Vector2.new(input.Position.X, input.Position.Y)

		if not allowed(point) then
			return
		end

		self.dragging = true
		self.origin = point
		self.start = object.Position

		self.began:fire(object.Position)
	end))

	scope:add(Imports.UserInputService.InputChanged:Connect(function(input)
		if not self.dragging then
			return
		end

		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local point = Vector2.new(input.Position.X, input.Position.Y)
		local delta = point - self.origin

		local dx = self.axis == "y" and 0 or delta.X
		local dy = self.axis == "x" and 0 or delta.Y

		local target = UDim2.new(
			self.start.X.Scale,
			self.start.X.Offset + dx,
			self.start.Y.Scale,
			self.start.Y.Offset + dy
		)

		target = Imports.Placement.clamp(target, object.AbsoluteSize, self.inset)

		object.Position = target

		self.moved:fire(target)
	end))

	scope:add(Imports.UserInputService.InputEnded:Connect(function(input)
		if not self.dragging then
			return
		end

		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		self.dragging = false

		self.ended:fire(object.Position)
	end))

	scope:add(self)

	return self
end

function Drag.setEnabled(self, enabled: boolean)
	self.enabled = enabled == true

	if not self.enabled then
		self.dragging = false
	end
end

function Drag.setPosition(self, position: UDim2)
	self.object.Position = position
	self.start = position
end

function Drag.destroy(self)
	self.moved:destroy()
	self.began:destroy()
	self.ended:destroy()

	self.dragging = false
end

Drag.pointIn = pointIn

return Drag
]=====],
	},
	{
		path = "lume/input/focus",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name focus
	@module lume/input/focus

	One focus ring per app: registration order defines traversal order, and
	click-outside detection is resolved against registered regions instead
	of each component guessing.
]]

--// imports
local Imports = {
	UserInputService = game:GetService("UserInputService"),

	Signal = require(script.Parent.Parent.core.signal),
	Drag = require(script.Parent.drag),
}

--// public api
local Focus = {}
Focus.__index = Focus

function Focus.new(app)
	local self = setmetatable({
		changed = Imports.Signal.new(),
		outside = Imports.Signal.new(),

		entries = {},
		current = nil,
		app = app,
	}, Focus)

	app.scope:add(Imports.UserInputService.InputBegan:Connect(function(input, processed)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local point = Vector2.new(input.Position.X, input.Position.Y)

		for _, entry in self.entries do
			if entry.region and Imports.Drag.pointIn(entry.region, point) then
				return
			end
		end

		self.outside:fire(point, processed)
	end))

	app.scope:add(self)

	return self
end

function Focus.register(self, entry)
	table.insert(self.entries, entry)

	return function()
		local index = table.find(self.entries, entry)

		if index then
			table.remove(self.entries, index)
		end

		if self.current == entry then
			self.current = nil
		end
	end
end

function Focus.set(self, entry)
	if self.current == entry then
		return
	end

	local previous = self.current

	self.current = entry

	if previous and previous.blur then
		previous.blur()
	end

	if entry and entry.focus then
		entry.focus()
	end

	self.changed:fire(entry, previous)
end

function Focus.step(self, delta: number)
	local list = {}

	for _, entry in self.entries do
		if entry.focusable ~= false then
			table.insert(list, entry)
		end
	end

	if #list == 0 then
		return
	end

	local index = self.current and table.find(list, self.current) or 0
	local target = list[((index - 1 + delta) % #list) + 1]

	self:set(target)
end

function Focus.release(self)
	local focused = Imports.UserInputService:GetFocusedTextBox()

	if focused then
		focused:ReleaseFocus()
	end

	self:set(nil)
end

function Focus.destroy(self)
	self.changed:destroy()
	self.outside:destroy()

	self.entries = {}
	self.current = nil
end

return Focus
]=====],
	},
	{
		path = "lume/input/keys",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name keys
	@module lume/input/keys

	Named keybindings over ContextActionService, with the typing guard the
	original console needed: a bound letter must not fire while a text field
	has focus.
]]

--// imports
local Imports = {
	ContextActionService = game:GetService("ContextActionService"),
	UserInputService = game:GetService("UserInputService"),
}

--// locals
local serial = 0

local function isTypingKey(key: Enum.KeyCode): boolean
	return utf8.len(Imports.UserInputService:GetStringForKeyCode(key)) == 1
end

--// public api
local Keys = {}
Keys.__index = Keys

function Keys.new(app)
	serial += 1

	local self = setmetatable({
		prefix = string.format("Lume_%d", serial),
		bindings = {},
		app = app,
	}, Keys)

	app.scope:add(self)

	return self
end

function Keys.bind(self, name: string, keys: { Enum.KeyCode }, handler, options)
	options = options or {}

	local action = string.format("%s_%s", self.prefix, name)

	self:unbind(name)

	if #keys == 0 then
		return
	end

	local binding = {
		ignoreWhenTyping = options.ignoreWhenTyping ~= false,
		priority = options.priority or 2000,
		sink = options.sink ~= false,

		action = action,
		keys = keys,
	}

	Imports.ContextActionService:BindActionAtPriority(action, function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		if
			binding.ignoreWhenTyping
			and Imports.UserInputService:GetFocusedTextBox()
			and isTypingKey(input.KeyCode)
		then
			return Enum.ContextActionResult.Pass
		end

		handler(input)

		return binding.sink and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, false, binding.priority, table.unpack(keys))

	self.bindings[name] = binding
end

function Keys.unbind(self, name: string)
	local binding = self.bindings[name]

	if not binding then
		return
	end

	Imports.ContextActionService:UnbindAction(binding.action)

	self.bindings[name] = nil
end

--// chords: read modifier state without binding it
function Keys.held(_, key: Enum.KeyCode): boolean
	return Imports.UserInputService:IsKeyDown(key)
end

function Keys.control(self): boolean
	return self:held(Enum.KeyCode.LeftControl) or self:held(Enum.KeyCode.RightControl)
end

function Keys.shift(self): boolean
	return self:held(Enum.KeyCode.LeftShift) or self:held(Enum.KeyCode.RightShift)
end

function Keys.destroy(self)
	for name in table.clone(self.bindings) do
		self:unbind(name)
	end
end

Keys.isTypingKey = isTypingKey

return Keys
]=====],
	},
	{
		path = "lume/layout/autosize",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name autosize
	@module lume/layout/autosize

	Content-driven sizing: the widest measurable thing in a surface decides
	its width, clamped to the viewport. This is what lets a panel grow with
	its content instead of guessing a fixed width.
]]

--// imports
local Imports = {
	Workspace = game:GetService("Workspace"),
}

--// locals
local function viewport(): Vector2
	local camera = Imports.Workspace.CurrentCamera

	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

--// public api
local AutoSize = {}

AutoSize.viewport = viewport

--// widest: measure a list of { text, size, font } entries
function AutoSize.widest(measure, entries): number
	local widest = 0

	for _, entry in entries do
		if entry.text and entry.text ~= "" then
			widest = math.max(widest, measure:width(entry.text, entry.size, entry.font))
		end
	end

	return widest
end

--// resolve: clamp a desired width into min/max and inside the viewport
function AutoSize.resolve(desired: number, options): number
	local min = options.min or 0
	local max = options.max or math.huge

	local inset = options.inset or 24
	local limit = math.max(min, viewport().X - inset)

	return math.clamp(math.max(desired, min), min, math.min(max, limit))
end

--// available: vertical room from an edge, used to cap scroll regions
function AutoSize.available(anchorY: number, fromTop: boolean, inset: number): number
	local height = viewport().Y

	if fromTop then
		return math.max(0, height - anchorY - inset)
	end

	return math.max(0, anchorY - inset)
end

--// fit: how tall a content block should render, capped by room and a ceiling
function AutoSize.fit(contentHeight: number, room: number, ceiling: number?): number
	if contentHeight <= 0 then
		return 0
	end

	return math.min(contentHeight, math.min(room, ceiling or math.huge))
end

return table.freeze(AutoSize)
]=====],
	},
	{
		path = "lume/layout/measure",
		kind = "module",
		source = [=====[
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
]=====],
	},
	{
		path = "lume/layout/placement",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name placement
	@module lume/layout/placement

	Anchor math for floating surfaces: stacking, attaching, flipping away
	from a viewport edge, and clamping back on screen.
]]

--// imports
local Imports = {
	AutoSize = require(script.Parent.autosize),
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
]=====],
	},
	{
		path = "lume/layout/virtual",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name virtual
	@module lume/layout/virtual

	Windowing math plus chunked realisation. Rows are rendered in blocks
	rather than one instance per row: a 5000-line log becomes a few dozen
	labels, which is the difference between smooth and unusable.
]]

--// public api
local Virtual = {}
Virtual.__index = Virtual

function Virtual.new(options)
	return setmetatable({
		itemHeight = options.itemHeight or 18,
		chunkSize = math.max(1, options.chunkSize or 64),
		buffer = options.buffer or 8,

		count = options.count or 0,
		pinned = true,
		offset = 0,
	}, Virtual)
end

function Virtual.setCount(self, count: number)
	self.count = math.max(0, count)
end

function Virtual.contentHeight(self): number
	return self.count * self.itemHeight
end

function Virtual.setOffset(self, offset: number, height: number)
	local limit = math.max(0, self:contentHeight() - height)

	self.offset = math.clamp(offset, 0, limit)
	self.pinned = self.offset >= limit - 1
end

function Virtual.pin(self, height: number)
	self.pinned = true
	self.offset = math.max(0, self:contentHeight() - height)
end

--// range: inclusive first and last index to realise for a viewport height
function Virtual.range(self, height: number): (number, number)
	if self.count == 0 or height <= 0 then
		return 1, 0
	end

	local top = self.pinned and math.max(0, self:contentHeight() - height) or self.offset

	local first = math.max(1, math.floor(top / self.itemHeight) + 1 - self.buffer)
	local last = math.min(self.count, math.ceil((top + height) / self.itemHeight) + self.buffer)

	return first, last
end

--// chunks: block boundaries covering a range, aligned to chunkSize so the
--// same block keys recur between frames and instances can be reused
function Virtual.chunks(self, first: number, last: number)
	local out = {}

	if last < first then
		return out
	end

	local size = self.chunkSize
	local startBlock = math.floor((first - 1) / size)
	local endBlock = math.floor((last - 1) / size)

	for block = startBlock, endBlock do
		local blockFirst = block * size + 1
		local blockLast = math.min(self.count, blockFirst + size - 1)

		table.insert(out, {
			first = blockFirst,
			last = blockLast,
			key = string.format("Chunk_%05d", block),
		})
	end

	return out
end

function Virtual.offsetOf(self, index: number): number
	return (index - 1) * self.itemHeight
end

return Virtual
]=====],
	},
	{
		path = "lume/motion/easing",
		kind = "module",
		source = [=====[
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
]=====],
	},
	{
		path = "lume/motion/lerp",
		kind = "module",
		source = [=====[
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
]=====],
	},
	{
		path = "lume/motion/spring",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name spring
	@module lume/motion/spring

	Semi-implicit Euler solver, substepped so a dropped frame cannot make a
	stiff spring explode. Springs are the default for anything retargetable
	(layout, drag release, reveal) because the target can change mid-flight
	without a visible restart.
]]

--// locals
local MaxStep = 1 / 240

--// public api
local Spring = {}
Spring.__index = Spring

function Spring.new(position: number, stiffness: number, damping: number)
	return setmetatable({
		stiffness = stiffness,
		damping = damping,

		position = position,
		velocity = 0,
		target = position,
	}, Spring)
end

function Spring.retarget(self, target: number)
	self.target = target
end

function Spring.tune(self, stiffness: number, damping: number)
	self.stiffness = stiffness
	self.damping = damping
end

function Spring.step(self, delta: number): number
	local remaining = math.min(delta, 0.1)

	while remaining > 0 do
		local step = math.min(remaining, MaxStep)

		local force = (self.target - self.position) * self.stiffness
		local drag = self.velocity * self.damping

		self.velocity += (force - drag) * step
		self.position += self.velocity * step

		remaining -= step
	end

	return self.position
end

function Spring.settled(self, epsilon: number?): boolean
	local tolerance = epsilon or 0.05

	return math.abs(self.target - self.position) < tolerance and math.abs(self.velocity) < tolerance * 4
end

function Spring.snap(self, position: number)
	self.position = position
	self.target = position
	self.velocity = 0
end

return Spring
]=====],
	},
	{
		path = "lume/theme/tokens",
		kind = "module",
		source = [=====[
--!strict

--[[
	@name tokens
	@module lume/theme/tokens

	The default token set. Every component reads from here, never from
	literals, so a single extend() call restyles the whole tree.
]]

return {
	color = {
		surface = Color3.fromRGB(18, 18, 20),
		surfaceRaised = Color3.fromRGB(26, 26, 29),
		surfaceSunken = Color3.fromRGB(13, 13, 15),
		overlay = Color3.fromRGB(0, 0, 0),

		border = Color3.fromRGB(48, 48, 54),
		borderStrong = Color3.fromRGB(72, 72, 80),

		text = Color3.fromRGB(238, 238, 242),
		textMuted = Color3.fromRGB(146, 146, 158),
		textGhost = Color3.fromRGB(96, 96, 106),

		accent = Color3.fromRGB(126, 170, 255),
		accentMuted = Color3.fromRGB(74, 102, 156),

		success = Color3.fromRGB(137, 255, 126),
		warn = Color3.fromRGB(255, 214, 126),
		danger = Color3.fromRGB(255, 126, 126),
	},

	rich = {
		text = "#EEEEF2",
		muted = "#9292A0",
		accent = "#7EAAFF",
		success = "#89FF7E",
		warn = "#FFD67E",
		danger = "#FF7E7E",
	},

	transparency = {
		surface = 0.08,
		overlay = 0.45,
		border = 0.35,
		text = 0,
		muted = 0.15,
		shadow = 0.55,
	},

	font = {
		body = Enum.Font.Gotham,
		medium = Enum.Font.GothamMedium,
		bold = Enum.Font.GothamBold,
		mono = Enum.Font.Code,
	},

	text = {
		xs = 11,
		sm = 13,
		md = 14,
		lg = 17,
		xl = 22,
	},

	space = {
		none = 0,
		xs = 4,
		sm = 8,
		md = 12,
		lg = 16,
		xl = 24,
	},

	radius = {
		sm = 6,
		md = 10,
		lg = 14,
		pill = 999,
	},

	stroke = {
		hairline = 1,
		thick = 2,
	},

	--// shadow: opt-in. point image at a 9-sliced soft shadow asset of your
	--// own and every surface picks it up; empty means no shadow instances.
	shadow = {
		image = "",
		slice = Rect.new(64, 64, 64, 64),
		color = Color3.new(),
		transparency = 0.55,
		spread = 24,
	},

	size = {
		control = 32,
		row = 26,
		hint = 20,
		touch = 44,
	},

	motion = {
		--// tween specs
		instant = { duration = 0 },
		enter = { duration = 0.22, easing = "outQuint" },
		exit = { duration = 0.16, easing = "outQuad" },
		hover = { duration = 0.12, easing = "outQuad" },
		press = { duration = 0.08, easing = "outQuad" },

		--// spring specs: used wherever the target can be retargeted mid-flight
		layout = { stiffness = 190, damping = 24 },
		drag = { stiffness = 320, damping = 30 },
		reveal = { stiffness = 150, damping = 20 },
	},
}
]=====],
	},
}

local function build()
	local existing = parent:FindFirstChild(rootName)

	if existing then
		if not overwrite then
			error("[lume] " .. rootName .. " already exists in " .. parent:GetFullName() .. " (set overwrite = true)")
		end

		existing:Destroy()

		say("replaced existing install")
	end

	local created = {}
	local modules = 0

	for _, entry in Manifest do
		local segments = string.split(entry.path, "/")
		local name = segments[#segments]

		local instance

		if entry.kind == "folder" then
			instance = Instance.new("Folder")
		else
			instance = Instance.new("ModuleScript")

			local ok, err = pcall(function()
				instance.Source = entry.source
			end)

			if not ok then
				instance:Destroy()

				error(
					"[lume] cannot write ModuleScript.Source here - run this from the Studio command bar or a plugin ("
						.. tostring(err)
						.. ")"
				)
			end

			modules += 1
		end

		instance.Name = if #segments == 1 then rootName else name

		if #segments == 1 then
			instance.Parent = parent
		else
			local holder = created[table.concat(segments, "/", 1, #segments - 1)]

			if not holder then
				instance:Destroy()

				error("[lume] manifest out of order at " .. entry.path)
			end

			instance.Parent = holder
		end

		created[entry.path] = instance
	end

	local root = created["lume"]

	root:SetAttribute("LumeVersion", Version)
	root:SetAttribute("LumeInstalledAt", os.time())

	say(string.format("built %d modules into %s", modules, root:GetFullName()))
	say('require it with: local Lume = require(' .. root:GetFullName() .. ')')

	if Selection and Options.select ~= false then
		pcall(function()
			Selection:Set({ root })
		end)
	end

	return root
end

return build()
