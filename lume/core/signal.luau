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
