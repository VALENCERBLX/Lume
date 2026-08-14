--!strict

--[[
	@name button
	@module lume/components/button
]]

--// imports
local Imports = {
	Surface = require("./surface"),
	Handle = require("../core/handle"),
	Motion = require("../motion"),
	Create = require("../core/create"),
	State = require("../core/state"),
}

--// locals
local function palette(theme, variant: string)
	if variant == "ghost" then
		return {
			background = theme.color.surfaceRaised,
			transparency = 1,
			hover = 0.85,
			text = theme.color.textMuted,
			border = false,
		}
	end

	if variant == "outline" then
		return {
			background = theme.color.surface,
			transparency = 1,
			hover = 0.88,
			text = theme.color.text,
			border = true,
		}
	end

	if variant == "accent" then
		return {
			background = theme.color.accent,
			transparency = 0.05,
			hover = 0,
			text = theme.color.surface,
			border = false,
		}
	end

	return {
		background = theme.color.surfaceRaised,
		transparency = theme.transparency.surface,
		hover = math.max(0, theme.transparency.surface - 0.06),
		text = theme.color.text,
		border = true,
	}
end

--// public api
local Button = {}

function Button.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local look = palette(theme, props.variant or "solid")
	local height = props.height or theme.size.control

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			class = "TextButton",
			name = props.name or "Button",
			ref = "root",

			color = look.background,
			transparency = look.transparency,
			border = look.border,
			radius = props.radius or theme.radius.sm,

			position = props.position,
			anchorPoint = props.anchorPoint,
			size = props.size or UDim2.fromOffset(props.width or 120, height),

			props = {
				AutoButtonColor = false,
				Text = "",

				FontFace = nil,
				TextTransparency = 1,
			},

			children = {
				Imports.Create.padding(props.paddingX or theme.space.md, 0),
				Imports.Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = props.align == "left" and Enum.HorizontalAlignment.Left
						or Enum.HorizontalAlignment.Center,
				}),
				{
					class = "TextLabel",
					ref = "label",
					props = {
						BackgroundTransparency = 1,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, height),

						Font = props.font or theme.font.medium,
						TextSize = props.textSize or theme.text.sm,
						TextColor3 = look.text,
						TextTransparency = theme.transparency.text,

						Text = Imports.State.unwrap(props.text) or "Button",
						Name = "Label",
					},
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	if Imports.State.is(props.text) then
		handle:set("Text", props.text)
		scope:add(Imports.State.observe(props.text, function(next)
			(refs.label :: TextLabel).Text = tostring(next)
		end))
	end

	local disabled = props.disabled

	local function isDisabled(): boolean
		return Imports.State.unwrap(disabled) == true
	end

	scope:add(Imports.State.observe(disabled, function(off)
		(refs.label :: TextLabel).TextTransparency = off and 0.55 or theme.transparency.text
		root.Active = not off
	end))

	scope:add(root.MouseEnter:Connect(function()
		if isDisabled() then
			return
		end

		handle:animate({ BackgroundTransparency = look.hover }, "hover")
	end))

	scope:add(root.MouseLeave:Connect(function()
		handle:animate({ BackgroundTransparency = look.transparency }, "hover")
	end))

	scope:add((root :: TextButton).MouseButton1Down:Connect(function()
		if isDisabled() then
			return
		end

		handle:animate({ Size = UDim2.fromOffset(root.AbsoluteSize.X, height - 2) }, "press")
	end))

	scope:add((root :: TextButton).MouseButton1Up:Connect(function()
		handle:animate({ Size = UDim2.fromOffset(root.AbsoluteSize.X, height) }, "layout")
	end))

	scope:add((root :: TextButton).Activated:Connect(function()
		if isDisabled() then
			return
		end

		handle:emit("activated")

		if props.onClick then
			props.onClick()
		end
	end))

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Button
