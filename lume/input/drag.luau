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

	Placement = require("../layout/placement"),
	Signal = require("../core/signal"),
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
