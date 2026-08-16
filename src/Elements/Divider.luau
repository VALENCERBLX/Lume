--!strict

--- A hairline rule, optionally with a caption sitting on it.
---
--- The caption is drawn over the line on an opaque chip rather than splitting
--- the line into two measured halves, which keeps it correct at any width
--- without a second layout pass.
--- @section Elements

local Types = require(script.Parent.Parent.Types)
local Create = require(script.Parent.Parent.Core.Create)
local Node = require(script.Parent.Parent.Core.Node)
local Element = require(script.Parent.Element)

local Divider = {}
Divider.__index = Divider

export type Fields = Types.NodeFields & Types.ElementFields & {
	thickness: number,
	labelled: boolean,
}

--- Creates a divider. Prefer `panel:divider()`.
function Divider.new(app: Types.App): Types.Divider
	local theme = app.theme
	local scope = app.scope:child()

	local root, refs = Create.tree(scope, {
		class = "Frame",
		ref = "root",
		props = {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, theme.stroke.hairline),
			Name = "Divider",
		},
		children = {
			{
				class = "Frame",
				ref = "line",
				props = {
					BackgroundColor3 = theme.color.border,
					BackgroundTransparency = theme.transparency.border,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(1, 0, 0, theme.stroke.hairline),

					Name = "Line",
				},
			},
			{
				class = "TextLabel",
				ref = "caption",
				props = {
					BackgroundColor3 = theme.color.surface,
					BackgroundTransparency = theme.transparency.surface,
					BorderSizePixel = 0,

					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, theme.size.hint),

					Font = theme.font.medium,
					TextSize = theme.text.xs,
					TextColor3 = theme.color.textGhost,
					TextTransparency = theme.transparency.ghost,
					TextXAlignment = Enum.TextXAlignment.Left,

					Visible = false,
					Name = "Caption",
					Text = "",
					ZIndex = 2,
				},
				children = {
					Create.padding(theme.space.xs, 0),
				},
			},
		},
	})

	local fields: Fields = {
		app = app,
		scope = scope,
		instance = root :: GuiObject,
		refs = refs,
		bindings = {},
		events = {},
		owner = nil,
		dead = false,

		kind = "divider",
		desired = Vector2.new(0, theme.stroke.hairline),
		margin = 0,
		fill = true,
		grow = false,
		enabled = true,
		measured = false,

		thickness = theme.stroke.hairline,
		labelled = false,
	}

	return setmetatable(fields, Divider) :: any
end

function Divider.setLabel(self: Fields & Types.Divider, label: Types.Bindable<string>): Types.Divider
	local caption = self.refs.caption :: TextLabel

	Node.bind(self, "label", label, function(next: string)
		local value = tostring(next)

		caption.Text = value
		caption.Visible = value ~= ""

		self.labelled = value ~= ""

		self:invalidate()
	end)

	return self
end

function Divider.setThickness(self: Fields & Types.Divider, thickness: number): Types.Divider
	self.thickness = thickness
	;(self.refs.line :: Frame).Size = UDim2.new(1, 0, 0, thickness)

	return self:invalidate()
end

function Divider.setColor(self: Fields & Types.Divider, color: Types.Bindable<Color3>): Types.Divider
	Node.bind(self, "color", color, function(next: Color3)
		(self.refs.line :: Frame).BackgroundColor3 = next
	end)

	return self
end

function Divider.measure(self: Fields & Types.Divider, available: Vector2): Vector2
	local height = if self.labelled then self.app.theme.size.hint else self.thickness

	--// a rule wants no width of its own; it takes whatever the panel settles
	--// on during commit, so it never drags a panel wider
	self.desired = Vector2.new(0, height)
	self.measured = true

	return self.desired
end

Element.install(Divider)

return Divider
