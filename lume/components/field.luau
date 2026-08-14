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
	Surface = require("./surface"),
	Handle = require("../core/handle"),
	Motion = require("../motion"),
	Create = require("../core/create"),
	State = require("../core/state"),
	Text = require("../text"),
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
