--!strict

--[[
	@name modal
	@module lume/components/modal

	Centred dialog on the modal layer, with a dimming scrim. Enter lifts the
	card a few pixels and fades the scrim; exit reverses it, and the scrim
	swallows clicks so the app underneath cannot be reached.
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
local Modal = {}

function Modal.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local width = props.width or 380
	local height = props.height or 200

	local root, refs = Imports.Create.tree(scope, {
		class = "TextButton",
		ref = "root",
		props = {
			BackgroundColor3 = theme.color.overlay,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Modal = true,
			Text = "",

			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Name = props.name or "Modal",
			ZIndex = 100,
		},
		children = {
			Imports.Surface.descriptor(app, {
				ref = "card",
				name = "Card",

				radius = theme.radius.lg,
				color = theme.color.surface,
				transparency = 0,
				clip = true,

				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
				size = UDim2.fromOffset(width, height),

				props = { ZIndex = 101 },

				children = {
					{
						class = "TextLabel",
						ref = "title",
						props = {
							BackgroundTransparency = 1,
							Position = UDim2.fromOffset(theme.space.lg, theme.space.lg),
							Size = UDim2.new(1, -theme.space.lg * 2, 0, 20),

							Font = theme.font.medium,
							TextSize = theme.text.lg,
							TextColor3 = theme.color.text,
							TextXAlignment = Enum.TextXAlignment.Left,

							Text = Imports.State.unwrap(props.title) or "",
							Name = "Title",
						},
					},
					{
						class = "Frame",
						ref = "content",
						props = {
							BackgroundTransparency = 1,
							Position = UDim2.fromOffset(theme.space.lg, theme.space.lg + 32),
							Size = UDim2.new(1, -theme.space.lg * 2, 1, -(theme.space.lg * 2 + 32)),
							Name = "Content",
						},
					},
				},
			}),
		},
	})

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.content = refs.content

	local card = refs.card :: Frame

	root.Parent = app:surface("modal")
	scope:add(root)

	function handle.open(self)
		root.Visible = true
		root.BackgroundTransparency = 1

		card.Position = UDim2.new(0.5, 0, 0.5, 10)

		Imports.Motion.animate(app, root, { BackgroundTransparency = theme.transparency.overlay }, "enter")
		Imports.Motion.animate(app, card, { Position = UDim2.fromScale(0.5, 0.5) }, "reveal")

		self:emit("opened")

		return self
	end

	function handle.close(self)
		Imports.Motion.animate(app, card, { Position = UDim2.new(0.5, 0, 0.5, 8) }, "exit")

		local animation = Imports.Motion.animate(app, root, { BackgroundTransparency = 1 }, "exit")

		animation.completed:once(function()
			if root.Parent then
				root.Visible = false
			end

			self:emit("closed")
		end)

		return animation
	end

	if props.dismissable ~= false then
		scope:add((root :: TextButton).Activated:Connect(function()
			handle:close()
		end))

		app.keys:bind("modalDismiss", { Enum.KeyCode.Escape }, function()
			if root.Visible then
				handle:close()
			end
		end, { sink = false })
	end

	return handle
end

return Modal
