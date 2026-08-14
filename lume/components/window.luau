--!strict

--[[
	@name window
	@module lume/components/window

	A floating, draggable, content-sized surface. Height and width are driven
	by springs so growing content pushes the frame instead of snapping it,
	and the top edge stays put when a bottom-anchored window grows.
]]

--// imports
local Imports = {
	Placement = require("../layout/placement"),
	Surface = require("./surface"),
	Handle = require("../core/handle"),
	Create = require("../core/create"),
	Motion = require("../motion"),
	State = require("../core/state"),
	Drag = require("../input/drag"),
}

--// public api
local Window = {}

function Window.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local width = props.width or 360
	local titleHeight = props.titleHeight or theme.size.control

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			name = props.name or "Window",
			ref = "root",

			radius = props.radius or theme.radius.lg,
			color = theme.color.surface,
			clip = true,

			anchorPoint = props.anchorPoint or Vector2.zero,
			position = props.position or Imports.Placement.center(Vector2.new(width, 200)),
			size = UDim2.fromOffset(width, titleHeight),

			children = {
				{
					class = "Frame",
					ref = "titlebar",
					props = {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, titleHeight),
						Name = "Titlebar",
						ZIndex = 3,
					},
					children = {
						Imports.Create.padding(theme.space.md, 0),
						Imports.Create.list(Enum.FillDirection.Horizontal, theme.space.sm, {
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						{
							class = "TextLabel",
							ref = "title",
							props = {
								BackgroundTransparency = 1,
								AutomaticSize = Enum.AutomaticSize.X,
								Size = UDim2.fromOffset(0, titleHeight),

								Font = theme.font.medium,
								TextSize = theme.text.sm,
								TextColor3 = theme.color.text,
								TextXAlignment = Enum.TextXAlignment.Left,

								Text = Imports.State.unwrap(props.title) or "Window",
								Name = "Title",
							},
						},
					},
				},
				{
					class = "Frame",
					ref = "content",
					props = {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(0, titleHeight),
						Size = UDim2.new(1, 0, 1, -titleHeight),
						Name = "Content",
						ZIndex = 2,
					},
					children = props.padded ~= false
							and { Imports.Create.padding(theme.space.md, theme.space.md) }
						or {},
				},
			},
		})
	)

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.content = refs.content
	handle.titlebar = refs.titlebar

	if Imports.State.is(props.title) then
		scope:add(Imports.State.observe(props.title, function(next)
			(refs.title :: TextLabel).Text = tostring(next)
		end))
	end

	--// drag: titlebar only, so content interaction never moves the window
	if props.draggable ~= false then
		handle.drag = Imports.Drag.attach(app, root, {
			handles = { refs.titlebar },
			scope = scope,
		})

		handle.drag.moved:connect(function(position)
			handle:emit("moved", position)
		end)
	end

	--// resize: the one call that keeps stacked windows visually anchored
	function handle.resize(self, contentHeight: number, spec)
		local extra = titleHeight + (props.padded ~= false and theme.space.md * 2 or 0)
		local target = math.max(titleHeight, contentHeight + extra)

		local grew = target - root.AbsoluteSize.Y

		if not Imports.Placement.isTop(root) and grew ~= 0 then
			Imports.Motion.animate(app, root, {
				Position = Imports.Placement.withStack(root.Position, root, grew),
			}, spec or "layout")
		end

		return Imports.Motion.animate(app, root, {
			Size = UDim2.fromOffset(self.width or width, target),
		}, spec or "layout")
	end

	function handle.setWidth(self, next: number, spec)
		self.width = next

		return Imports.Motion.animate(app, root, {
			Size = UDim2.fromOffset(next, root.AbsoluteSize.Y),
		}, spec or "layout")
	end

	function handle.open(self)
		root.Visible = true
		root.GroupTransparency = 1

		Imports.Motion.animate(app, root, { GroupTransparency = 0 }, "enter")

		local settled = root.Position

		root.Position = Imports.Placement.stacked(settled, root, 12, 0)

		self:emit("opened")

		return Imports.Motion.animate(app, root, { Position = settled }, "reveal")
	end

	function handle.close(self)
		local animation = Imports.Motion.animate(app, root, { GroupTransparency = 1 }, "exit")

		animation.completed:once(function()
			if root.Parent then
				root.Visible = false
			end

			self:emit("closed")
		end)

		return animation
	end

	root.GroupTransparency = 0

	if props.parent then
		handle:mount(props.parent)
	else
		handle:mount(app:surface(props.layer or "default"))
	end

	return handle
end

return Window
