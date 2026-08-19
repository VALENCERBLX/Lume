--!strict

--- A window with a menu bar across the top.
---
--- The thing to try is crossing the strip: open File, then move the pointer
--- sideways without clicking. The menu follows. One popover is shared by every
--- title, which is what makes that possible — three separate dropdowns would
--- each have to be closed and opened.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lume = require(ReplicatedStorage.Packages.Lume)

local app = Lume.app({ name = "Editor" })

local status = Lume.value("Ready")

local window = app:panel("window")

window:setTitle("Editor")
window:setWidth(420)
window:setAnchor("center")

--// the bar --------------------------------------------------------------------
--- Items carry their own behaviour: `action` runs when the item is picked, and
--- `picked` fires afterwards with the id of the menu it came from — so one
--- handler can serve the whole bar rather than one per title.
local bar = window:menuBar({
	{
		text = "File",
		items = {
			{ id = "new", text = "New", shortcut = "Ctrl+N" },
			{ id = "open", text = "Open…", shortcut = "Ctrl+O" },
			{ divider = true, text = "" },
			{ id = "save", text = "Save", shortcut = "Ctrl+S" },
			{ id = "quit", text = "Quit", danger = true },
		},
	},
	{
		text = "Edit",
		items = {
			{ id = "undo", text = "Undo", shortcut = "Ctrl+Z" },
			{ id = "redo", text = "Redo", shortcut = "Ctrl+Y", disabled = true },
			{ divider = true, text = "" },
			{ id = "find", text = "Find…", icon = "rbxasset://textures/ui/common/search.png" },
		},
	},
	{
		text = "View",
		items = {
			{ id = "zoomIn", text = "Zoom in" },
			{ id = "zoomOut", text = "Zoom out" },
			{ id = "reset", text = "Reset zoom", action = function()
				status:set("Zoom reset")
			end },
		},
	},
	{ id = "help", text = "Help", items = { { id = "about", text = "About Editor" } } },
})

bar:onPicked(function(item, from)
	--// `action` has already run by the time this fires, which is why Reset
	--// zoom sets its own message and nothing here overwrites it
	if item.id ~= "reset" then
		status:set(`{from} → {item.text}`)
	end
end)

window:divider()

--// the body -------------------------------------------------------------------
local body = window:label("Pick something from the bar. Then open File and slide sideways.")

body:setMuted(true)

window:spacer(24)

local readout = window:label(status)

readout:setTextSize(18)

window:open()
