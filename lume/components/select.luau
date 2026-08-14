--!strict

--[[
	@name select
	@module lume/components/select

	Dropdown built on the same popover machinery as autocomplete: the trigger
	is a button, the menu is a flipped, spring-height surface on the popover
	layer, so it is never clipped by its parent.
]]

--// imports
local Imports = {
	Placement = require("../layout/placement"),
	Surface = require("./surface"),
	Handle = require("../core/handle"),
	Create = require("../core/create"),
	Motion = require("../motion"),
	State = require("../core/state"),
}

--// public api
local Select = {}

function Select.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local options: { string } = props.options or {}
	local rowHeight = props.rowHeight or theme.size.row
	local width = props.width or 180
	local height = props.height or theme.size.control

	local value = Imports.State.is(props.value) and props.value or Imports.State.value(props.value or options[1])

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			class = "TextButton",
			name = props.name or "Select",
			ref = "root",

			radius = theme.radius.sm,
			color = theme.color.surfaceRaised,
			size = UDim2.fromOffset(width, height),
			position = props.position,
			anchorPoint = props.anchorPoint,

			props = {
				AutoButtonColor = false,
				Text = "",
			},

			children = {
				Imports.Create.padding(theme.space.md, 0),
				{
					class = "TextLabel",
					ref = "label",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -14, 1, 0),

						Font = theme.font.body,
						TextSize = theme.text.sm,
						TextColor3 = theme.color.text,
						TextXAlignment = Enum.TextXAlignment.Left,

						Text = tostring(value:get() or props.placeholder or "Select"),
						Name = "Label",
					},
				},
				{
					class = "Frame",
					ref = "caret",
					props = {
						BackgroundColor3 = theme.color.textMuted,
						BorderSizePixel = 0,
						Rotation = 45,

						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, 0, 0.5, -1),
						Size = UDim2.fromOffset(5, 5),
						Name = "Caret",
					},
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.value = value

	local menuRoot, menuRefs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			name = "SelectMenu",
			ref = "menu",

			radius = theme.radius.md,
			color = theme.color.surfaceRaised,
			clip = true,
			visible = false,
			zIndex = 10,

			size = UDim2.fromOffset(width, 0),

			children = {
				{
					class = "Frame",
					ref = "rows",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),
						Name = "Rows",
					},
					children = { Imports.Create.list(Enum.FillDirection.Vertical, 0) },
				},
			},
		})
	)

	menuRoot.Parent = app:surface("popover")

	local rows = menuRefs.rows :: Frame
	local open = false

	for index, option in options do
		local row = Instance.new("TextButton")

		row.BackgroundColor3 = theme.color.text
		row.BackgroundTransparency = 1
		row.AutoButtonColor = false
		row.BorderSizePixel = 0

		row.Font = theme.font.body
		row.TextSize = theme.text.sm
		row.TextColor3 = theme.color.textMuted
		row.TextXAlignment = Enum.TextXAlignment.Left

		row.Size = UDim2.new(1, 0, 0, rowHeight)
		row.LayoutOrder = index
		row.Text = tostring(option)
		row.Name = string.format("Option_%02d", index)

		local padding = Instance.new("UIPadding")

		padding.PaddingLeft = UDim.new(0, theme.space.md)
		padding.Parent = row

		scope:add(row.MouseEnter:Connect(function()
			Imports.Motion.animate(app, row, { BackgroundTransparency = 0.9 }, "hover")
		end))

		scope:add(row.MouseLeave:Connect(function()
			Imports.Motion.animate(app, row, { BackgroundTransparency = 1 }, "hover")
		end))

		scope:add(row.Activated:Connect(function()
			value:set(option)

			handle:close()
		end))

		row.Parent = rows
	end

	function handle.open(self)
		if open or #options == 0 then
			return
		end

		open = true

		local size = Vector2.new(width, #options * rowHeight)
		local edge = Imports.Placement.flip(root, size, props.edge or "bottom", theme.space.xs)

		menuRoot.Position = Imports.Placement.beside(root, size, edge, theme.space.xs)
		menuRoot.Visible = true

		Imports.Motion.animate(app, refs.caret, { Rotation = 225 }, "hover")

		self:emit("opened")

		return Imports.Motion.animate(app, menuRoot, { Size = UDim2.fromOffset(width, size.Y) }, "reveal")
	end

	function handle.close(self)
		if not open then
			return
		end

		open = false

		Imports.Motion.animate(app, refs.caret, { Rotation = 45 }, "hover")

		local animation = Imports.Motion.animate(app, menuRoot, { Size = UDim2.fromOffset(width, 0) }, "exit")

		animation.completed:once(function()
			if menuRoot.Parent then
				menuRoot.Visible = false
			end
		end)

		self:emit("closed")

		return animation
	end

	scope:add((root :: TextButton).Activated:Connect(function()
		if open then
			handle:close()
		else
			handle:open()
		end
	end))

	scope:add(app.focus.outside:connect(function(point)
		if not open then
			return
		end

		local origin = menuRoot.AbsolutePosition
		local bounds = menuRoot.AbsoluteSize

		local inside = point.X >= origin.X
			and point.X <= origin.X + bounds.X
			and point.Y >= origin.Y
			and point.Y <= origin.Y + bounds.Y

		if not inside then
			handle:close()
		end
	end))

	scope:add(value:subscribe(function(next)
		(refs.label :: TextLabel).Text = tostring(next)

		handle:emit("changed", next)

		if props.onChange then
			props.onChange(next)
		end
	end))

	scope:add(menuRoot)

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Select
