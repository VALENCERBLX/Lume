--!strict

--[[
	@name suggest
	@module lume/components/suggest

	Autocomplete popover. Ranking is prefix-first, then substring, so the
	obvious completion is always the default selection. Reveal and dismissal
	are spring height changes, never visibility flips.
]]

--// imports
local Imports = {
	Placement = require("../layout/placement"),
	Surface = require("./surface"),
	Handle = require("../core/handle"),
	Create = require("../core/create"),
	Motion = require("../motion"),
	Text = require("../text"),
}

--// locals
local function rank(source: { string }, query: string, limit: number): { string }
	local needle = string.lower(Imports.Text.trim(query))

	local prefix: { string } = {}
	local infix: { string } = {}

	for _, candidate in source do
		local lower = string.lower(candidate)

		if needle == "" or string.sub(lower, 1, #needle) == needle then
			table.insert(prefix, candidate)
		elseif string.find(lower, needle, 1, true) then
			table.insert(infix, candidate)
		end
	end

	table.sort(prefix)
	table.sort(infix)

	local out: { string } = {}

	for _, value in prefix do
		table.insert(out, value)
	end

	for _, value in infix do
		table.insert(out, value)
	end

	while #out > limit do
		table.remove(out)
	end

	return out
end

--// public api
local Suggest = {}

Suggest.rank = rank

function Suggest.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local rowHeight = props.rowHeight or theme.size.row
	local limit = props.limit or 6
	local gap = props.gap or theme.space.xs

	local root, refs = Imports.Create.tree(
		scope,
		Imports.Surface.descriptor(app, {
			name = props.name or "Suggest",
			ref = "root",

			radius = theme.radius.md,
			color = theme.color.surfaceRaised,
			clip = true,
			visible = false,

			size = UDim2.fromOffset(props.width or 240, 0),

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

	local handle = Imports.Handle.new(app, root, refs, scope)

	local rows = refs.rows :: Frame
	local current: { string } = {}
	local selected = 0

	local function paint()
		for index, child in rows:GetChildren() do
			if child:IsA("TextButton") then
				local active = tonumber(child:GetAttribute("index")) == selected

				Imports.Motion.animate(app, child, {
					BackgroundTransparency = active and 0.9 or 1,
				}, "hover")

				;(child :: TextButton).TextColor3 = active and theme.color.text or theme.color.textMuted
			end
		end
	end

	local function accept(index: number)
		local value = current[index]

		if not value then
			return false
		end

		handle:emit("accepted", value)

		if props.onAccept then
			props.onAccept(value)
		end

		handle:hide()

		return true
	end

	local function build()
		for _, child in rows:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for index, value in current do
			local button = Instance.new("TextButton")

			button.BackgroundColor3 = theme.color.text
			button.BackgroundTransparency = 1
			button.AutoButtonColor = false
			button.BorderSizePixel = 0

			button.Font = props.font or theme.font.mono
			button.TextSize = props.textSize or theme.text.sm
			button.TextColor3 = theme.color.textMuted
			button.TextXAlignment = Enum.TextXAlignment.Left

			button.Size = UDim2.new(1, 0, 0, rowHeight)
			button.LayoutOrder = index
			button.Text = value
			button.Name = string.format("Row_%02d", index)

			button:SetAttribute("index", index)

			local padding = Instance.new("UIPadding")

			padding.PaddingLeft = UDim.new(0, theme.space.md)
			padding.Parent = button

			button.MouseEnter:Connect(function()
				selected = index

				paint()
			end)

			button.Activated:Connect(function()
				accept(index)
			end)

			button.Parent = rows
		end

		paint()
	end

	function handle.update(self, query: string, source: { string }?)
		local pool = source or props.source or {}

		if type(pool) == "function" then
			pool = pool(query)
		end

		current = rank(pool, query, limit)
		selected = #current > 0 and 1 or 0

		if #current == 0 then
			return self:hide()
		end

		build()

		if props.anchor then
			local size = Vector2.new(root.AbsoluteSize.X, #current * rowHeight)
			local edge = Imports.Placement.flip(props.anchor, size, props.edge or "bottom", gap)

			root.Position = Imports.Placement.beside(props.anchor, size, edge, gap)
		end

		root.Visible = true

		return Imports.Motion.animate(app, root, {
			Size = UDim2.fromOffset(props.width or root.AbsoluteSize.X, #current * rowHeight),
		}, "reveal")
	end

	function handle.move(self, delta: number)
		if #current == 0 then
			return false
		end

		selected = ((selected - 1 + delta) % #current) + 1

		paint()

		return true
	end

	function handle.accept(_)
		return accept(selected)
	end

	function handle.selection(_)
		return current[selected]
	end

	function handle.hide(self)
		if not root.Visible then
			return
		end

		local animation = Imports.Motion.animate(app, root, { Size = UDim2.fromOffset(root.AbsoluteSize.X, 0) }, "exit")

		animation.completed:once(function()
			if root.Parent then
				root.Visible = false
			end
		end)

		self:emit("hidden")

		return animation
	end

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Suggest
