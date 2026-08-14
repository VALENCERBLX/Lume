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
	Motion = require("../motion"),
	Signal = require("./signal"),
	State = require("./state"),
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
