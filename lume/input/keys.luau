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
