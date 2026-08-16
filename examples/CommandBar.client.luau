--!strict

--- A console command bar: a pill at the bottom of the screen that grows into a
--- rounded panel as output arrives, with inline autocomplete.
---
--- Everything characteristic here — the pill morphing, the bar widening to fit
--- its longest line, the ghost completion after the caret — falls out of the
--- preset and the layout pass. None of it is coded per-case.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lume = require(ReplicatedStorage.Packages.Lume)

local COMMANDS = {
	{ id = "teleport", text = "teleport", description = "<player> <place>" },
	{ id = "kill", text = "kill", description = "<player>" },
	{ id = "give", text = "give", description = "<player> <item> [count]" },
	{ id = "spawn", text = "spawn", description = "<model> [position]" },
	{ id = "kick", text = "kick", description = "<player> [reason]" },
	{ id = "fly", text = "fly", description = "[speed]" },
}

local app = Lume.app({ name = "Console" })

local history = Lume.value({})

local bar = app:panel("bar")
	:setAnchor("bottom")
	:setWidth("auto")
	:setMaxSize(900, 420)

--// output first, so it sits above the input in the column
local output = bar:list()

output:setItems(history)
output:setMaxRows(12)
output:setSelectable(false)
output:setEmptyText("")

local input = bar:field("Type a command…")

input:setPrefix(">")
input:setClearOnSubmit(true)

local suggest = bar:suggest()

suggest:setSource(COMMANDS)
suggest:setLimit(6)
suggest:attach(input)

local function log(line: string)
	history:update(function(lines)
		local next = table.clone(lines)

		table.insert(next, line)

		return next
	end)
end

input:onSubmitted(function(text)
	if text == "" then
		return
	end

	log(`> {text}`)
	log(`  no such command: {string.split(text, " ")[1]}`)
end)

--// the activation key: opens the bar and puts the caret in it
app:bind(Enum.KeyCode.Semicolon, function()
	if bar:isOpen() then
		bar:close()
	else
		bar:open()
		input:focus()
	end
end)

app:bind(Enum.KeyCode.Escape, function()
	if bar:isOpen() then
		bar:close()
	end
end)
