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

	Signal = require("../core/signal"),
	Drag = require("./drag"),
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
