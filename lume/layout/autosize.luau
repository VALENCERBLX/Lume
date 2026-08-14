--!strict

--[[
	@name autosize
	@module lume/layout/autosize

	Content-driven sizing: the widest measurable thing in a surface decides
	its width, clamped to the viewport. This is what lets a panel grow with
	its content instead of guessing a fixed width.
]]

--// imports
local Imports = {
	Workspace = game:GetService("Workspace"),
}

--// locals
local function viewport(): Vector2
	local camera = Imports.Workspace.CurrentCamera

	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

--// public api
local AutoSize = {}

AutoSize.viewport = viewport

--// widest: measure a list of { text, size, font } entries
function AutoSize.widest(measure, entries): number
	local widest = 0

	for _, entry in entries do
		if entry.text and entry.text ~= "" then
			widest = math.max(widest, measure:width(entry.text, entry.size, entry.font))
		end
	end

	return widest
end

--// resolve: clamp a desired width into min/max and inside the viewport
function AutoSize.resolve(desired: number, options): number
	local min = options.min or 0
	local max = options.max or math.huge

	local inset = options.inset or 24
	local limit = math.max(min, viewport().X - inset)

	return math.clamp(math.max(desired, min), min, math.min(max, limit))
end

--// available: vertical room from an edge, used to cap scroll regions
function AutoSize.available(anchorY: number, fromTop: boolean, inset: number): number
	local height = viewport().Y

	if fromTop then
		return math.max(0, height - anchorY - inset)
	end

	return math.max(0, anchorY - inset)
end

--// fit: how tall a content block should render, capped by room and a ceiling
function AutoSize.fit(contentHeight: number, room: number, ceiling: number?): number
	if contentHeight <= 0 then
		return 0
	end

	return math.min(contentHeight, math.min(room, ceiling or math.huge))
end

return table.freeze(AutoSize)
