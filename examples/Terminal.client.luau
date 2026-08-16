--!strict

--- The original console command bar, rebuilt on Lume.
---
--- This is a 1:1 of the terminal the library was distilled from: a pill at the
--- bottom of the screen that morphs into a rounded panel as output arrives,
--- monospace green history with red errors, an inline ghost completion after
--- the caret, and a suggestion list that flips above the bar because there is
--- no room below it.
---
--- Every number below is the original's own, taken from the fallbacks in its
--- source (`panel.stackGap or 8`, `motion.outputSmoothTime or 0.24`,
--- `panel.historyMaxHeight or 420`, `panel.viewportTopInset or 24`, …) rather
--- than eyeballed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lume = require(ReplicatedStorage.Packages.Lume)

--// the console's metrics ------------------------------------------------------
local CONSOLE = {
	height = 36, --// panel.height, the pill
	collapsedWidth = 220, --// panel.collapsedWidth
	width = 520, --// panel.width
	maxWidth = 900, --// panel.maxWidth
	historyMaxHeight = 420, --// panel.historyMaxHeight
	viewportInset = 24, --// panel.viewportTopInset
	outputRadius = 12, --// panel.outputRadius
	suggestionRadius = 10, --// panel.suggestionRadius
	suggestionGap = 8, --// panel.suggestionGap
	stackGap = 8, --// panel.stackGap
	paddingX = 12, --// layout.paddingX
	paddingY = 6,
	textSize = 14, --// layout.textSize
	hintTextSize = 13, --// layout.hintTextSize
	lineHeight = 18, --// panel.historyLineHeight
	maxSuggestions = 6, --// panel.maxSuggestions
}

local COMMANDS = {
	{ id = "kick", text = "kick", description = "<player> [reason]" },
	{ id = "ban", text = "ban", description = "<player> [reason] [duration]" },
	{ id = "kill", text = "kill", description = "<player>" },
	{ id = "respawn", text = "respawn", description = "<player>" },
	{ id = "teleport", text = "teleport", description = "<player> <target>" },
	{ id = "give", text = "give", description = "<player> <item> [count]" },
	{ id = "speed", text = "speed", description = "<player> <number>" },
	{ id = "uptime", text = "uptime", description = "" },
	{ id = "announce", text = "announce", description = "<message> [colour]" },
	{ id = "commands", text = "commands", description = "" },
}

local app = Lume.app({ name = "Konsole", displayOrder = 100 })

--// the console's input row is 24 tall, not Lume's default 32, which is what
--// makes the collapsed pill exactly `paddingY * 2 + 24 = 36` and gives it a
--// radius of 18. Restyling the app rather than the element keeps it one line
local theme = app:restyle({
	size = {
		control = CONSOLE.height - CONSOLE.paddingY * 2,
		row = CONSOLE.height - CONSOLE.paddingY * 2,
	},
})

--// history -------------------------------------------------------------------
--// each entry carries its own tone; the renderer turns that into the rich
--// text the row displays, which is how the original coloured its output
local history = Lume.value({})

local function write(text: string, tone: string?)
	history:update(function(lines)
		local next = table.clone(lines)

		table.insert(next, { id = `{#next + 1}`, text = text, data = tone or "out" })

		return next
	end)
end

--// the bar -------------------------------------------------------------------
local bar = app:panel("bar")
	:setAnchor("bottom")
	:setInset(CONSOLE.viewportInset)
	:setPadding(CONSOLE.paddingX, CONSOLE.paddingY)
	:setGap(CONSOLE.paddingY)
	:setRadius("pill")
	:setWidth("auto")
	:setMinSize(CONSOLE.collapsedWidth, 0)
	:setMaxSize(CONSOLE.maxWidth, CONSOLE.historyMaxHeight + CONSOLE.height)
	:setDraggable(true)
	:setShadow(true)

--// output first, input second: the panel stacks children down its axis, and
--// it grows upward from the bottom edge, so this is the console's order
local output = bar:list()

output:setItems(history)
output:setFont(Enum.Font.Code)
output:setTextSize(CONSOLE.textSize)
output:setRowHeight(CONSOLE.lineHeight)
output:setSelectable(false)
output:setFill(false) --// let the widest line drive the panel's width
output:setMaxRows(math.floor(CONSOLE.historyMaxHeight / CONSOLE.lineHeight))
output:setRenderer(function(item)
	local tone = item.data

	local colour = if tone == "error"
		then theme.rich.danger
		elseif tone == "echo" then theme.rich.muted
		else theme.rich.terminal

	return Lume.Text.color(Lume.Text.escape(item.text or ""), colour)
end)

local input = bar:field("type a command...")

input:setPrefix(">")
input:setFont(Enum.Font.Code)
input:setTextSize(CONSOLE.textSize)
input:setClearOnSubmit(true)

--// suggestions ---------------------------------------------------------------
--// a separate panel on the popover layer, so it is never clipped by the bar.
--// Asking for it below the bar makes it flip above, since the bar is already
--// sitting on the bottom edge of the screen
local suggestions = app:panel("popover")
	:setRadius(CONSOLE.suggestionRadius)
	:setPadding(0, 4)
	:setMaxSize(CONSOLE.maxWidth, CONSOLE.maxSuggestions * theme.size.row + 8)
	:setBorder(false)

local suggest = suggestions:suggest()

suggest:setSource(COMMANDS)
suggest:setLimit(CONSOLE.maxSuggestions)
suggest:attach(input)

local function placeSuggestions()
	suggestions:setWidth(math.max(CONSOLE.collapsedWidth, bar.instance.AbsoluteSize.X))
	suggestions:attachTo(bar.instance, "top", CONSOLE.suggestionGap)
end

--// show the list only while there is something to show
input:onChanged(function(text)
	if text == "" or #(suggest :: any).matches == 0 then
		suggestions:close()

		return
	end

	placeSuggestions()
	suggestions:open()
end)

suggest:onAccepted(function()
	suggestions:close()
end)

--// running commands ----------------------------------------------------------
local function lookup(name: string)
	for _, command in COMMANDS do
		if command.id == name then
			return command
		end
	end

	return nil
end

local function run(line: string)
	write(`> {line}`, "echo")

	local name = string.split(line, " ")[1]
	local command = lookup(name)

	if not command then
		write("command failed", "error")
		write(`unknown command "{name}"`, "error")

		return
	end

	if name == "commands" then
		write("commands", "out")
		write(`{#COMMANDS} registered`, "out")

		for _, entry in COMMANDS do
			write(string.format("  %-10s %s", entry.text, entry.description), "out")
		end

		return
	end

	write(`ok: {command.text}`, "out")
end

input:onSubmitted(function(text)
	if text ~= "" then
		run(text)
	end

	suggestions:close()
end)

--// the bar keeps its own width, so the suggestion panel has to follow it
bar:on("resized", function()
	if suggestions:isOpen() then
		placeSuggestions()
	end
end)

--// activation ----------------------------------------------------------------
app:bind(Enum.KeyCode.Semicolon, function()
	if bar:isOpen() then
		bar:close()
		suggestions:close()
	else
		bar:open()
		input:focus()
	end
end)

app:bind(Enum.KeyCode.Escape, function()
	if suggestions:isOpen() then
		suggestions:close()
	elseif bar:isOpen() then
		bar:close()
	end
end)

bar:open()
