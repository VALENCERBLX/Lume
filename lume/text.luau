--!strict

--[[
	@name text
	@module lume/text
	@credit driftingAurora, dullflowerr, alias; kioukaii (original console UI, MIT)
]]

--// locals
local escapes = {
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&quot;",
	["'"] = "&apos;",
}

--// public api
local Text = {}

function Text.callable(value: any): boolean
	if type(value) == "function" then
		return true
	end

	if type(value) == "table" then
		local meta = getmetatable(value :: any)

		return type(meta) == "table" and Text.callable(meta.__call)
	end

	return false
end

function Text.trim(value: any): string
	return (string.gsub(tostring(value or ""), "^%s*(.-)%s*$", "%1"))
end

function Text.cleanStart(value: any): string
	return (string.gsub(tostring(value or ""), "^%s+", ""))
end

function Text.richEscape(value: any): string
	return (string.gsub(tostring(value or ""), "[&<>\"']", escapes))
end

function Text.linesOf(value: any): { string }
	local out: { string } = {}

	for line in string.gmatch(tostring(value or "") .. "\n", "(.-)\n") do
		table.insert(out, line)
	end

	if #out > 1 and out[#out] == "" then
		table.remove(out)
	end

	if #out == 0 then
		table.insert(out, "")
	end

	return out
end

function Text.truncate(value: any, limit: number, ellipsis: string?): string
	local text = tostring(value or "")

	if utf8.len(text) == nil or (utf8.len(text) :: number) <= limit then
		return text
	end

	local tail = ellipsis or "..."
	local offset = utf8.offset(text, math.max(1, limit - utf8.len(tail) :: number + 1))

	return string.sub(text, 1, (offset or 1) - 1) .. tail
end

function Text.tokenize(value: any): { string }
	local out: { string } = {}

	for token in string.gmatch(tostring(value or ""), "%S+") do
		table.insert(out, token)
	end

	return out
end

function Text.quoted(value: any): string
	local text = Text.trim(value)

	if text ~= "" and string.find(text, "%s") then
		return string.format("%q", text)
	end

	return text
end

function Text.slug(value: any): string
	return string.lower((string.gsub(tostring(value or ""), "%W+", "-")))
end

return table.freeze(Text)
