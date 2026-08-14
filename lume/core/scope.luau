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
