--!strict

--- A settings window folded into sections.
---
--- Each section's body is a **group**, so it hosts what a panel hosts — a
--- toggle, a slider, a colour picker, another accordion if you like. The panel
--- around it is a spring, so folding a section is the same motion as any other
--- content change rather than a second animation system.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lume = require(ReplicatedStorage.Packages.Lume)

local app = Lume.app({ name = "Settings" })

local window = app:panel("window")

window:setTitle("Settings")
window:setAnchor("center")
window:setWidth(300)

local sections = window:accordion()

--// only one open at a time: a long settings list is easier to read when the
--// thing you are not looking at is folded away
sections:setExclusive(true)

local display = sections:section("Display")

display:toggle("Wireframe"):setDescription("Draw collision volumes")
display:slider("Opacity"):setRange(0, 100):setStep(1):setValue(80)
display:select("Render mode"):setOptions({ "Solid", "Wireframe", "Points" })

local colour = sections:section("Colour")

colour:colorPicker("Highlight"):setValue(Color3.fromRGB(126, 170, 255))

local advanced = sections:section("Advanced")

advanced:stepper("Grid size"):setRange(1, 16):setStep(1):setValue(4)
advanced:keybind("Toggle"):setValue(Enum.KeyCode.F2)
advanced:label("Nothing here is dangerous, despite the name."):setMuted(true):setWrapped(true)

sections:onToggled(function(id, open)
	print(id, if open then "opened" else "closed")
end)

sections:openSection("Display")

window:open()
