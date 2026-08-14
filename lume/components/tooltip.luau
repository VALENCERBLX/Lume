--!strict

--[[
	@name tooltip
	@module lume/components/tooltip

	Hover popover on the tooltip layer. Delay in, no delay out, flipped away
	from viewport edges, and sized from measured text rather than guesses.
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
local Tooltip = {}

function Tooltip.attach(app, target: GuiObject, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local textSize = props.textSize or theme.text.xs
	local font = props.font or theme.font.body
	local padX = theme.space.sm
	local padY = theme.space.xs
	local gap = props.gap or theme.space.xs

	local text = props.text or ""

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			name = "Tooltip",
			ref = "root",

			radius = theme.radius.sm,
			color = theme.color.surfaceRaised,
			transparency = 0,
			visible = false,
			zIndex = 1000,

			size = UDim2.fromOffset(0, 0),

			children = {
				{
					class = "TextLabel",
					ref = "label",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0),

						Font = font,
						TextSize = textSize,
						TextColor3 = theme.color.text,
						TextTransparency = 1,

						Text = tostring(Imports.State.unwrap(text)),
						Name = "Label",
					},
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	root.Parent = app:surface("tooltip")
	scope:add(root)

	local token = 0

	local function sizeFor(body: string): Vector2
		local measured = app.measure:text(body, textSize, font)

		return Vector2.new(math.ceil(measured.X) + padX * 2, math.ceil(measured.Y) + padY * 2)
	end

	function handle.show(self)
		local body = tostring(Imports.State.unwrap(text))

		if body == "" then
			return
		end

		;(refs.label :: TextLabel).Text = body

		local size = sizeFor(body)
		local edge = Imports.Placement.flip(target, size, props.edge or "top", gap)

		root.Size = UDim2.fromOffset(size.X, size.Y)
		root.Position = Imports.Placement.beside(target, size, edge, gap)
		root.Visible = true

		Imports.Motion.animate(app, refs.label, { TextTransparency = 0 }, "enter")

		return Imports.Motion.animate(app, root, { BackgroundTransparency = 0 }, "enter")
	end

	function handle.hide(self)
		Imports.Motion.animate(app, refs.label, { TextTransparency = 1 }, "exit")

		local animation = Imports.Motion.animate(app, root, { BackgroundTransparency = 1 }, "exit")

		animation.completed:once(function()
			if root.Parent then
				root.Visible = false
			end
		end)

		return animation
	end

	function handle.setText(self, next)
		text = next

		return self
	end

	scope:add(target.MouseEnter:Connect(function()
		token += 1

		local mine = token

		task.delay(props.delay or 0.35, function()
			if scope:alive() and token == mine then
				handle:show()
			end
		end)
	end))

	scope:add(target.MouseLeave:Connect(function()
		token += 1

		handle:hide()
	end))

	return handle
end

Tooltip.new = Tooltip.attach

return Tooltip
