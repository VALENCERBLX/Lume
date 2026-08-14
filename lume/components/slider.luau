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

	Surface = require("./surface"),
	Handle = require("../core/handle"),
	Motion = require("../motion"),
	Create = require("../core/create"),
	State = require("../core/state"),
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
