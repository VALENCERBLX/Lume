--!strict

--[[
	@name list
	@module lume/components/list

	Virtualised scroller with two realisation modes:
	  text - lines batched into chunk labels (cheapest; rich text per line)
	  rows - one instance per visible item, built by a callback

	Both share the same windowing math, autoscroll pinning, and height cap.
]]

--// imports
local Imports = {
	Surface = require("./surface"),
	Virtual = require("../layout/virtual"),
	Handle = require("../core/handle"),
	Create = require("../core/create"),
	Motion = require("../motion"),
	Text = require("../text"),
}

--// public api
local List = {}

function List.new(app, props)
	local theme = app.theme
	local scope = (props.scope or app.scope):child()

	local mode = props.mode or "text"
	local font = props.font or theme.font.mono
	local textSize = props.textSize or theme.text.sm

	local itemHeight = props.itemHeight or app.measure:lineHeight(textSize, font)

	local virtual = Imports.Virtual.new({
		chunkSize = props.chunkSize or 64,
		itemHeight = itemHeight,
		buffer = props.buffer or 8,
	})

	local items: { any } = props.items or {}

	local root, refs = Imports.Create.tree(scope, {
		class = "ScrollingFrame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			ScrollBarThickness = props.scrollBarThickness or 3,
			ScrollBarImageTransparency = 0.6,
			ScrollBarImageColor3 = theme.color.borderStrong,

			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			CanvasSize = UDim2.fromOffset(0, 0),

			Name = props.name or "List",
			Position = props.position or UDim2.fromOffset(0, 0),
			Size = props.size or UDim2.new(1, 0, 1, 0),
		},
		children = {
			{
				class = "Frame",
				ref = "canvas",
				props = {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -6, 0, 0),
					Name = "Canvas",
				},
			},
		},
	})

	local handle = Imports.Handle.new(app, root, refs, scope)

	local canvas = refs.canvas :: Frame
	local realised: { [string]: Instance } = {}

	local function viewportHeight(): number
		return root.AbsoluteSize.Y > 1 and root.AbsoluteSize.Y or (props.maxHeight or 320)
	end

	local function chunkText(first: number, last: number): string
		local out = {}

		for index = first, last do
			local item = items[index]

			if item ~= nil then
				table.insert(out, props.line and props.line(item, index) or Imports.Text.richEscape(item))
			end
		end

		return table.concat(out, "\n")
	end

	local function realiseText(first: number, last: number)
		local wanted: { [string]: boolean } = {}

		for _, chunk in virtual:chunks(first, last) do
			wanted[chunk.key] = true

			local existing = realised[chunk.key]
			local body = chunkText(chunk.first, chunk.last)

			if existing then
				(existing :: TextLabel).Text = body
				continue
			end

			local label = Instance.new("TextLabel")

			label.BackgroundTransparency = 1
			label.RichText = true
			label.TextWrapped = false

			label.Font = font
			label.TextSize = textSize
			label.TextColor3 = props.textColor or theme.color.text
			label.TextTransparency = theme.transparency.text

			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top

			label.Position = UDim2.fromOffset(0, virtual:offsetOf(chunk.first))
			label.Size = UDim2.new(1, 0, 0, (chunk.last - chunk.first + 1) * itemHeight)

			label.Name = chunk.key
			label.Text = body
			label.Parent = canvas

			realised[chunk.key] = label
		end

		for key, instance in realised do
			if not wanted[key] then
				instance:Destroy()

				realised[key] = nil
			end
		end
	end

	local function realiseRows(first: number, last: number)
		local wanted: { [string]: boolean } = {}

		for index = first, last do
			local key = string.format("Row_%05d", index)

			wanted[key] = true

			if realised[key] then
				continue
			end

			local row = props.row(items[index], index)

			if typeof(row) ~= "Instance" then
				continue
			end

			row.Name = key
			;(row :: GuiObject).Position = UDim2.fromOffset(0, virtual:offsetOf(index))
			;(row :: GuiObject).Size = UDim2.new(1, 0, 0, itemHeight)
			row.Parent = canvas

			realised[key] = row
		end

		for key, instance in realised do
			if not wanted[key] then
				instance:Destroy()

				realised[key] = nil
			end
		end
	end

	local function render()
		virtual:setCount(#items)

		local height = virtual:contentHeight()

		canvas.Size = UDim2.new(1, -6, 0, height)
		root.CanvasSize = UDim2.fromOffset(0, height)

		local first, last = virtual:range(viewportHeight())

		if mode == "rows" and props.row then
			realiseRows(first, last)
		else
			realiseText(first, last)
		end
	end

	--// height: what the parent should size itself to, capped by room
	function handle.contentHeight(_)
		return math.min(virtual:contentHeight(), props.maxHeight or 320)
	end

	function handle.setItems(self, next: { any })
		items = next or {}

		render()

		self:emit("changed", #items)

		return self
	end

	function handle.append(self, item: any)
		table.insert(items, item)

		virtual:setCount(#items)
		virtual:pin(viewportHeight())

		render()

		Imports.Motion.animate(app, root, {
			CanvasPosition = Vector2.new(0, math.max(0, virtual:contentHeight() - viewportHeight())),
		}, props.scrollSpec or "reveal")

		self:emit("appended", item)

		return self
	end

	function handle.clear(self)
		items = {}

		for key, instance in realised do
			instance:Destroy()

			realised[key] = nil
		end

		render()

		return self
	end

	function handle.pin(_)
		virtual:pin(viewportHeight())

		root.CanvasPosition = Vector2.new(0, virtual.offset)
	end

	scope:add(root:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		virtual:setOffset(root.CanvasPosition.Y, viewportHeight())

		render()
	end))

	scope:add(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(render))

	render()

	if props.parent then
		handle:mount(props.parent)
	end

	return handle
end

return List
