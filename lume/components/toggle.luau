--!strict

--[[
	@name toggle
	@module lume/components/toggle
]]

--// imports
local Imports = {
	Surface = require("./surface"),
	Handle = require("../core/handle"),
	Motion = require("../motion"),
	Create = require("../core/create"),
	State = require("../core/state"),
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
