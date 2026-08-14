--!strict

--[[
	@name chips
	@module lume/components/chips

	Inline structured input: a row of "name: value" cells that behave like one
	field. Arrow keys and Tab walk cells, each cell auto-fits its own text,
	and a validator paints invalid cells without blocking typing.
]]

--// imports
local Imports = {
	Handle = require("../core/handle"),
	Create = require("../core/create"),
	Motion = require("../motion"),
	Text = require("../text"),
}

--// public api
local Chips = {}

function Chips.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local font = props.font or theme.font.mono
	local textSize = props.textSize or theme.text.xs
	local height = props.height or theme.size.hint

	local gap = app.measure:gap(textSize, font)

	local root, refs = Imports.Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,

			Name = props.name or "Chips",
			Position = props.position or UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(0, height),
		},
		children = {
			Imports.Create.list(Enum.FillDirection.Horizontal, gap, {
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		},
	})

	local handle = Imports.Handle.new(app, root, refs, scope)

	local cells: { any } = {}
	local active: number? = nil

	local function paint()
		for index, cell in cells do
			local valid = not props.validate or props.validate(cell.spec, cell.box.Text) ~= false

			cell.label.TextColor3 = active == index and theme.color.text or theme.color.textMuted
			cell.box.TextColor3 = valid and theme.color.text or theme.color.danger
		end
	end

	local function fit(cell)
		local source = cell.box.Text ~= "" and cell.box.Text or cell.placeholder

		cell.box.Size = UDim2.fromOffset(math.max(2, app.measure:exact(source, textSize, font)), height)
	end

	function handle.focusCell(self, index: number)
		if #cells == 0 then
			return
		end

		index = math.clamp(index, 1, #cells)
		active = index

		local box = cells[index].box

		if not box:IsFocused() then
			box:CaptureFocus()
		end

		box.CursorPosition = #box.Text + 1

		paint()

		self:emit("cell", index)
	end

	function handle.step(self, delta: number, force: boolean?)
		if not active then
			self:focusCell(delta > 0 and 1 or #cells)

			return true
		end

		local box = cells[active].box
		local cursor = box.CursorPosition

		if not force and delta < 0 and cursor > 1 then
			return false
		end

		if not force and delta > 0 and cursor <= #box.Text then
			return false
		end

		local target = active + delta

		if target < 1 or target > #cells then
			return false
		end

		self:focusCell(target)

		return true
	end

	function handle.setSchema(self, schema)
		for _, cell in cells do
			cell.frame:Destroy()
		end

		cells = {}
		active = nil

		for index, spec in schema or {} do
			local optional = spec.required == false or spec.default ~= nil
			local name = tostring(spec.name or ("arg" .. index))

			local cellRoot, cellRefs = Imports.Create.tree(scope, {
				class = "Frame",
				ref = "frame",
				props = {
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					LayoutOrder = index,
					Size = UDim2.fromOffset(0, height),
					Name = string.format("Cell_%02d", index),
				},
				children = {
					Imports.Create.list(Enum.FillDirection.Horizontal, math.max(2, gap // 2), {
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					{
						class = "TextLabel",
						ref = "label",
						props = {
							BackgroundTransparency = 1,
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromOffset(0, height),

							Font = font,
							TextSize = textSize,
							TextColor3 = theme.color.textMuted,
							TextTransparency = 1,

							Text = (optional and (name .. "?") or name) .. ":",
							LayoutOrder = 1,
							Name = "Label",
						},
					},
					{
						class = "TextBox",
						ref = "box",
						props = {
							BackgroundTransparency = 1,
							ClearTextOnFocus = false,
							MultiLine = false,

							Font = font,
							TextSize = textSize,
							TextColor3 = theme.color.text,
							TextTransparency = 1,

							PlaceholderColor3 = theme.color.textGhost,
							PlaceholderText = tostring(spec.type or "string"),
							TextXAlignment = Enum.TextXAlignment.Left,

							Size = UDim2.fromOffset(6, height),
							LayoutOrder = 2,
							Name = "Box",
							Text = "",
						},
					},
				},
			})

			local cell = {
				placeholder = tostring(spec.type or "string"),
				label = cellRefs.label :: TextLabel,
				box = cellRefs.box :: TextBox,
				frame = cellRoot,
				spec = spec,
			}

			fit(cell)

			scope:add(cell.box:GetPropertyChangedSignal("Text"):Connect(function()
				if string.find(cell.box.Text, "\t", 1, true) then
					cell.box.Text = (string.gsub(cell.box.Text, "\t", ""))

					return
				end

				fit(cell)
				paint()

				handle:emit("changed", handle:assemble())

				if props.onChange then
					props.onChange(handle:assemble())
				end
			end))

			scope:add(cell.box.Focused:Connect(function()
				active = index

				paint()
			end))

			scope:add(cell.box.FocusLost:Connect(function(submitted)
				if not submitted then
					return
				end

				if index < #cells then
					handle:focusCell(index + 1)
				else
					handle:emit("submitted", handle:assemble())

					if props.onSubmit then
						props.onSubmit(handle:assemble())
					end
				end
			end))

			cellRoot.Parent = root

			table.insert(cells, cell)
		end

		paint()

		return self:reveal()
	end

	function handle.reveal(_)
		local targets = {}

		for _, cell in cells do
			table.insert(targets, cell.label)
			table.insert(targets, cell.box)
		end

		Imports.Motion.stagger(app, targets, { TextTransparency = theme.transparency.text }, "enter", 0.012)

		return handle
	end

	function handle.values(_)
		local out = {}

		for index, cell in cells do
			out[index] = Imports.Text.trim(cell.box.Text)
		end

		return out
	end

	--// assemble: the row as one command-ish string, quoting where needed
	function handle.assemble(self, prefix: string?)
		local parts = {}

		if prefix and prefix ~= "" then
			table.insert(parts, prefix)
		end

		for _, value in self:values() do
			if value ~= "" then
				table.insert(parts, Imports.Text.quoted(value))
			end
		end

		return table.concat(parts, " ")
	end

	function handle.fill(self, values: { string })
		for index, cell in cells do
			if values[index] then
				cell.box.Text = tostring(values[index])
			end
		end

		return self
	end

	if props.schema then
		handle:setSchema(props.schema)
	end

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return Chips
