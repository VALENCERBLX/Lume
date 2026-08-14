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
