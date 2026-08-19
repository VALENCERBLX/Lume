--!strict

--- A settings window: tabs, controls bound to reactive state, a confirmation
--- modal, and toasts stacked in the corner.
---
--- Note that no size is written down anywhere except the window's width and its
--- ceiling. Every row measures itself, and the window is exactly as tall as its
--- rows until it runs out of screen, at which point it scrolls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lume = require(ReplicatedStorage.Packages.Lume)

local app = Lume.app({ name = "Inspector" })

--// state ---------------------------------------------------------------------
local settings = {
	wireframe = Lume.value(false),
	compact = Lume.value(true),
	opacity = Lume.value(80),
	mode = Lume.value("solid"),
	selection = Lume.value(0),
	grid = Lume.value(4),
}

local summary = Lume.computed(function()
	local count = settings.selection:get()

	return if count == 1 then "1 object selected" else `{count} objects selected`
end)

--// window --------------------------------------------------------------------
local window = app:panel("window")
	:setTitle("Inspector")
	:setSubtitle("scene")
	:setAnchor("bottomRight")
	:setWidth(340)
	:setMaxSize(340, 560)

window:label(summary):setMuted(true)

local tabs = window:tabs()

tabs:setTabs({ "Display", "Advanced" })
tabs:setVariant("underline")
tabs:setFill(true)

window:divider()

--// controls ------------------------------------------------------------------
window:toggle("Wireframe")
	:setDescription("Draw collision volumes over the scene")
	:setValue(settings.wireframe)
	:onChanged(function(on)
		settings.wireframe:set(on)
	end)

window:toggle("Compact rows"):setStyle("checkbox"):setValue(settings.compact)

window:slider("Opacity")
	:setRange(0, 100)
	:setStep(1)
	:setValue(settings.opacity)
	:setFormat(function(value)
		return `{math.round(value)}%`
	end)
	:onCommitted(function(value)
		settings.opacity:set(value)
	end)

window:select("Render mode")
	:setOptions({
		{ id = "solid", text = "Solid" },
		{ id = "wireframe", text = "Wireframe" },
		{ id = "points", text = "Points" },
	})
	:setValue(settings.mode)
	:onChanged(function(id)
		if id then
			settings.mode:set(id)
		end
	end)

--// a slider is wrong for a short range where every value matters: dragging to
--// exactly 3 is fiddly, pressing plus three times is not
window:stepper("Grid size")
	:setRange(1, 16)
	:setStep(1)
	:setValue(settings.grid)
	:setFormat(function(value)
		return `{value} studs`
	end)
	:onCommitted(function(value)
		settings.grid:set(value)
	end)

window:keybind("Toggle inspector"):setValue(Enum.KeyCode.F2)

window:divider():setLabel("Danger")

--// a row: label on the left, actions pushed to the right by a flexible spacer
local actions = window:group("horizontal")

actions:setFill(true)
actions:label("Reset everything"):setMuted(true)
actions:spacer():setFlexible(true)

--// toasts --------------------------------------------------------------------
local toasts = app:stack("bottomLeft")

local function notify(message: string, tone: "success" | "danger")
	local toast = app:panel("toast")

	toast:label(message)
	toast:badge(if tone == "success" then "done" else "failed"):setTone(tone)

	toast:open()
	toasts:add(toast)

	task.delay(3, function()
		toast:close()

		task.delay(0.3, function()
			toasts:remove(toast)
			toast:destroy()
		end)
	end)
end

--// confirmation modal --------------------------------------------------------
actions:button("Reset")
	:setVariant("danger")
	:onClicked(function()
		local modal = app:panel("modal"):setTitle("Reset settings?")

		modal:label("Every setting returns to its default. This cannot be undone.")
			:setWrapped(true)
			:setMuted(true)

		local buttons = modal:group("horizontal")

		buttons:setFill(true)
		buttons:spacer():setFlexible(true)

		buttons:button("Cancel"):setVariant("ghost"):onClicked(function()
			modal:close()
		end)

		buttons:button("Reset"):setVariant("danger"):onClicked(function()
			Lume.batch(function()
				settings.wireframe:set(false)
				settings.compact:set(true)
				settings.opacity:set(80)
				settings.mode:set("solid")
			end)

			modal:close()
			notify("Settings reset", "success")
		end)

		modal:on("closed", function()
			task.delay(0.3, function()
				modal:destroy()
			end)
		end)

		modal:open()
	end)

window:open()

app:bind(Enum.KeyCode.F2, function()
	window:toggleOpen()
end)
