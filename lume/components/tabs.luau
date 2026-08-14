--!strict

--[[
	@name tabs
	@module lume/components/tabs

	Tab strip with a spring indicator. The indicator is a sibling of the tab
	buttons rather than a child, so it can travel across them continuously.
]]

--// imports
local Imports = {
	Handle = require("../core/handle"),
	Create = require("../core/create"),
	Motion = require("../motion"),
	State = require("../core/state"),
}

--// public api
local Tabs = {}

function Tabs.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local items = props.items or {}
	local height = props.height or theme.size.control
	local textSize = props.textSize or theme.text.sm
	local font = props.font or theme.font.medium
	local padding = props.paddingX or theme.space.md

	local active = Imports.State.is(props.active) and props.active
		or Imports.State.value(props.active or (items[1] and (items[1].key or items[1])))

	local root, refs = Imports.Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			Name = props.name or "Tabs",
			Position = props.position or UDim2.fromOffset(0, 0),
			Size = props.size or UDim2.new(1, 0, 0, height),
		},
		children = {
			{
				class = "Frame",
				ref = "indicator",
				props = {
					BackgroundColor3 = theme.color.accent,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.fromOffset(0, 2),

					Name = "Indicator",
					ZIndex = 3,
				},
				children = { Imports.Create.corner(theme.radius.pill) },
			},
			{
				class = "Frame",
				ref = "strip",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Name = "Strip",
				},
				children = { Imports.Create.list(Enum.FillDirection.Horizontal, props.gap or theme.space.xs) },
			},
		},
	})

	local handle = Imports.Handle.new(app, root, refs, scope)

	handle.active = active

	local strip = refs.strip :: Frame
	local indicator = refs.indicator :: Frame
	local buttons: { [string]: TextButton } = {}

	local function keyOf(item): string
		return tostring(type(item) == "table" and (item.key or item.label) or item)
	end

	local function labelOf(item): string
		return tostring(type(item) == "table" and (item.label or item.key) or item)
	end

	local function moveIndicator(animated: boolean)
		local button = buttons[tostring(active:get())]

		if not button then
			return
		end

		Imports.Motion.animate(app, indicator, {
			Position = UDim2.new(0, button.AbsolutePosition.X - strip.AbsolutePosition.X, 1, 0),
			Size = UDim2.fromOffset(button.AbsoluteSize.X, 2),
		}, animated and "layout" or "instant")
	end

	local function paint()
		local key = tostring(active:get())

		for name, button in buttons do
			Imports.Motion.animate(app, button, {
				TextColor3 = name == key and theme.color.text or theme.color.textMuted,
			}, "hover")
		end

		moveIndicator(true)
	end

	for index, item in items do
		local key = keyOf(item)

		local button = Instance.new("TextButton")

		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.BorderSizePixel = 0

		button.Font = font
		button.TextSize = textSize
		button.TextColor3 = theme.color.textMuted

		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.fromOffset(0, height)
		button.LayoutOrder = index
		button.Text = labelOf(item)
		button.Name = "Tab_" .. key

		local pad = Instance.new("UIPadding")

		pad.PaddingLeft = UDim.new(0, padding)
		pad.PaddingRight = UDim.new(0, padding)
		pad.Parent = button

		scope:add(button.Activated:Connect(function()
			active:set(key)
		end))

		button.Parent = strip
		buttons[key] = button
	end

	scope:add(active:subscribe(function(key)
		paint()

		handle:emit("changed", key)

		if props.onChange then
			props.onChange(key)
		end
	end))

	scope:add(strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		moveIndicator(false)
	end))

	task.defer(function()
		if scope:alive() then
			paint()
			moveIndicator(false)
		end
	end)

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Tabs
