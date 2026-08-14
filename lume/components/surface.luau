--!strict

--[[
	@name surface
	@module lume/components/surface

	The shared shell every floating component sits on: background, corner,
	hairline border, and an optional 9-sliced shadow. Shadows are opt-in via
	theme.shadow.image so the library ships with no baked asset ids.
]]

--// imports
local Imports = {
	Create = require("../core/create"),
}

--// public api
local Surface = {}

function Surface.descriptor(app, options)
	local theme = app.theme
	options = options or {}

	local children = {
		Imports.Create.corner(options.radius or theme.radius.md),
	}

	if options.border ~= false then
		table.insert(children, Imports.Create.stroke(theme.color.border, theme.stroke.hairline, theme.transparency.border))
	end

	if options.padding then
		table.insert(children, Imports.Create.padding(options.padding, options.paddingY))
	end

	for _, child in options.children or {} do
		table.insert(children, child)
	end

	local props: { [string]: any } = {
		BackgroundColor3 = options.color or theme.color.surface,
		BackgroundTransparency = options.transparency or theme.transparency.surface,

		BorderSizePixel = 0,
		Name = options.name or "Surface",

		AnchorPoint = options.anchorPoint or Vector2.zero,
		Position = options.position or UDim2.fromOffset(0, 0),
		Size = options.size or UDim2.fromOffset(240, theme.size.control),

		ClipsDescendants = options.clip == true,
		Visible = options.visible ~= false,
		ZIndex = options.zIndex or 1,
	}

	for key, value in options.props or {} do
		props[key] = value
	end

	return {
		class = options.class or "Frame",
		ref = options.ref,
		props = props,
		events = options.events,
		children = children,
	}
end

--// shadow: sits behind a target and tracks its bounds
function Surface.shadow(app, options)
	local theme = app.theme
	local shadow = theme.shadow or {}

	if not shadow.image or shadow.image == "" then
		return nil
	end

	return {
		class = "ImageLabel",
		ref = options and options.ref or nil,
		props = {
			BackgroundTransparency = 1,
			Image = shadow.image,
			ImageColor3 = shadow.color or Color3.new(),
			ImageTransparency = shadow.transparency or theme.transparency.shadow,

			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = shadow.slice or Rect.new(64, 64, 64, 64),

			Name = "Shadow",
			ZIndex = 0,
		},
	}
end

--// track: keep a shadow glued to its target with a uniform spread
function Surface.track(shadowInstance: ImageLabel?, target: GuiObject, spread: number)
	if not shadowInstance then
		return
	end

	local function sync()
		shadowInstance.Position = UDim2.new(
			target.Position.X.Scale,
			target.Position.X.Offset - spread,
			target.Position.Y.Scale,
			target.Position.Y.Offset - spread
		)

		shadowInstance.Size = UDim2.fromOffset(
			target.AbsoluteSize.X + spread * 2,
			target.AbsoluteSize.Y + spread * 2
		)

		shadowInstance.AnchorPoint = target.AnchorPoint
	end

	sync()

	return sync
end

return table.freeze(Surface)
